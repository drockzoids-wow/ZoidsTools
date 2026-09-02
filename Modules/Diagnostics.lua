local ADDON_NAME, ns = ...

local SAMPLE_INTERVAL = 5
local MAX_MEMORY_SAMPLES = 720
local MAX_ACTIVITY_KEYS = 192
local MAX_REPORT_ACTIVITIES = 24
local MAX_REPORT_SPIKES = 18
local MAX_REPORT_DROPS = 8

local diagnostic = {
    active = false,
    startedAt = 0,
    stoppedAt = 0,
    activity = {},
    intervalActivity = {},
    activityKeyCount = 0,
    memorySamples = {},
    memorySampleCount = 0,
    memoryWriteIndex = 1,
    memoryFirstKB = nil,
    memoryLastKB = nil,
    memoryMinKB = nil,
    memoryMaxKB = nil,
    luaFirstKB = nil,
    luaLastKB = nil,
    luaMinKB = nil,
    luaMaxKB = nil,
    profilerBaseline = {},
    frameCount = 0,
    hitch25 = 0,
    hitch50 = 0,
    hitch100 = 0,
    maxFrameMS = 0,
    sampleElapsed = 0,
    lastReport = nil,
}

local frame
local reportWindow
local GetBlizzardMetric
local RecordActivity

local function NowMS()
    return debugprofilestop and debugprofilestop() or ((GetTime and GetTime() or 0) * 1000)
end

local function Print(message)
    if ns.Print then
        ns:Print(message)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("ZoidsTools: " .. tostring(message))
    end
end

local function SafeNumber(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return value
end

GetBlizzardMetric = function(metricName)
    local metric = Enum and Enum.AddOnProfilerMetric and Enum.AddOnProfilerMetric[metricName]
    if not C_AddOnProfiler or type(C_AddOnProfiler.GetAddOnMetric) ~= "function" or metric == nil then
        return nil
    end

    local ok, value = pcall(C_AddOnProfiler.GetAddOnMetric, ADDON_NAME, metric)
    return ok and SafeNumber(value) or nil
end

local function GetAddonMemoryKB()
    if type(UpdateAddOnMemoryUsage) == "function" and type(GetAddOnMemoryUsage) == "function" then
        local started = NowMS()
        pcall(UpdateAddOnMemoryUsage)
        RecordActivity("Diagnostics.MemoryScan", NowMS() - started)
        local ok, value = pcall(GetAddOnMemoryUsage, ADDON_NAME)
        value = ok and SafeNumber(value) or nil
        if value then
            return value
        end
    end

    for _, metricName in ipairs({ "MemoryUsage", "AllocatedMemory" }) do
        local value = GetBlizzardMetric(metricName)
        if value then
            return value / 1024
        end
    end

    return nil
end

local function GetLuaMemoryKB()
    if type(collectgarbage) ~= "function" then
        return nil
    end

    local ok, value = pcall(collectgarbage, "count")
    return ok and SafeNumber(value) or nil
end

local function Reset()
    diagnostic.startedAt = GetTime and GetTime() or 0
    diagnostic.stoppedAt = 0
    diagnostic.activity = {}
    diagnostic.intervalActivity = {}
    diagnostic.activityKeyCount = 0
    diagnostic.memorySamples = {}
    diagnostic.memorySampleCount = 0
    diagnostic.memoryWriteIndex = 1
    diagnostic.memoryFirstKB = nil
    diagnostic.memoryLastKB = nil
    diagnostic.memoryMinKB = nil
    diagnostic.memoryMaxKB = nil
    diagnostic.luaFirstKB = nil
    diagnostic.luaLastKB = nil
    diagnostic.luaMinKB = nil
    diagnostic.luaMaxKB = nil
    diagnostic.profilerBaseline = {}
    diagnostic.frameCount = 0
    diagnostic.hitch25 = 0
    diagnostic.hitch50 = 0
    diagnostic.hitch100 = 0
    diagnostic.maxFrameMS = 0
    diagnostic.sampleElapsed = 0
    diagnostic.lastReport = nil
end

local function GetActivityBucket(label)
    label = tostring(label or "Unknown")
    local sample = diagnostic.activity[label]
    if sample then
        return label, sample
    end

    if diagnostic.activityKeyCount >= MAX_ACTIVITY_KEYS then
        label = "Other activity"
        sample = diagnostic.activity[label]
        if sample then
            return label, sample
        end
    else
        diagnostic.activityKeyCount = diagnostic.activityKeyCount + 1
    end

    sample = { calls = 0, totalMS = 0, maxMS = 0, over1 = 0, over5 = 0, over10 = 0 }
    diagnostic.activity[label] = sample
    return label, sample
end

RecordActivity = function(label, elapsedMS)
    if not diagnostic.active then
        return
    end

    local normalizedLabel, sample = GetActivityBucket(label)
    local elapsed = SafeNumber(elapsedMS) or 0
    sample.calls = sample.calls + 1
    sample.totalMS = sample.totalMS + elapsed
    sample.maxMS = math.max(sample.maxMS, elapsed)
    sample.over1 = sample.over1 + (elapsed >= 1 and 1 or 0)
    sample.over5 = sample.over5 + (elapsed >= 5 and 1 or 0)
    sample.over10 = sample.over10 + (elapsed >= 10 and 1 or 0)
    diagnostic.intervalActivity[normalizedLabel] = (diagnostic.intervalActivity[normalizedLabel] or 0) + 1
end

function ns:RecordDiagnosticActivity(label)
    RecordActivity(label, 0)
end

function ns:IsDiagnosticsActive()
    return diagnostic.active == true
end

function ns:HasDiagnosticReport()
    return type(diagnostic.lastReport) == "string" and diagnostic.lastReport ~= ""
end

local function ReturnDiagnosticResults(label, started, ...)
    RecordActivity(label, NowMS() - started)
    return ...
end

function ns:WrapDiagnosticFunction(label, func)
    if type(func) ~= "function" then
        return func
    end

    return function(...)
        if not diagnostic.active then
            return func(...)
        end

        local started = NowMS()
        return ReturnDiagnosticResults(label, started, func(...))
    end
end

local function TopIntervalActivity()
    local rows = {}
    for label, calls in pairs(diagnostic.intervalActivity) do
        rows[#rows + 1] = { label = label, calls = calls }
    end
    table.sort(rows, function(left, right)
        if left.calls == right.calls then
            return left.label < right.label
        end
        return left.calls > right.calls
    end)

    local parts = {}
    for index = 1, math.min(3, #rows) do
        parts[#parts + 1] = rows[index].label .. " x" .. rows[index].calls
    end
    wipe(diagnostic.intervalActivity)
    return #parts > 0 and table.concat(parts, ", ") or "idle"
end

local function StoreMemorySample(force)
    if not diagnostic.active and not force then
        return
    end

    local addonKB = GetAddonMemoryKB()
    local luaKB = GetLuaMemoryKB()
    local previousKB = diagnostic.memoryLastKB
    local now = GetTime and GetTime() or 0
    local sample = {
        elapsed = math.max(0, now - (diagnostic.startedAt or now)),
        addonKB = addonKB,
        luaKB = luaKB,
        deltaKB = addonKB and previousKB and (addonKB - previousKB) or 0,
        activity = TopIntervalActivity(),
    }

    diagnostic.memorySamples[diagnostic.memoryWriteIndex] = sample
    diagnostic.memoryWriteIndex = (diagnostic.memoryWriteIndex % MAX_MEMORY_SAMPLES) + 1
    diagnostic.memorySampleCount = diagnostic.memorySampleCount + 1

    if addonKB then
        diagnostic.memoryFirstKB = diagnostic.memoryFirstKB or addonKB
        diagnostic.memoryLastKB = addonKB
        diagnostic.memoryMinKB = diagnostic.memoryMinKB and math.min(diagnostic.memoryMinKB, addonKB) or addonKB
        diagnostic.memoryMaxKB = diagnostic.memoryMaxKB and math.max(diagnostic.memoryMaxKB, addonKB) or addonKB
    end
    if luaKB then
        diagnostic.luaFirstKB = diagnostic.luaFirstKB or luaKB
        diagnostic.luaLastKB = luaKB
        diagnostic.luaMinKB = diagnostic.luaMinKB and math.min(diagnostic.luaMinKB, luaKB) or luaKB
        diagnostic.luaMaxKB = diagnostic.luaMaxKB and math.max(diagnostic.luaMaxKB, luaKB) or luaKB
    end
end

local function OrderedMemorySamples()
    local rows = {}
    local retained = math.min(diagnostic.memorySampleCount, MAX_MEMORY_SAMPLES)
    if retained <= 0 then
        return rows
    end

    local startIndex = diagnostic.memorySampleCount > MAX_MEMORY_SAMPLES and diagnostic.memoryWriteIndex or 1
    for offset = 0, retained - 1 do
        local index = ((startIndex + offset - 1) % MAX_MEMORY_SAMPLES) + 1
        local sample = diagnostic.memorySamples[index]
        if sample then
            rows[#rows + 1] = sample
        end
    end
    return rows
end

local function SortedActivities()
    local rows = {}
    for label, sample in pairs(diagnostic.activity) do
        rows[#rows + 1] = { label = label, sample = sample }
    end
    table.sort(rows, function(left, right)
        if left.sample.totalMS == right.sample.totalMS then
            if left.sample.calls == right.sample.calls then
                return left.label < right.label
            end
            return left.sample.calls > right.sample.calls
        end
        return left.sample.totalMS > right.sample.totalMS
    end)
    return rows
end

local function FormatKB(value)
    return value and string.format("%.1f MB", value / 1024) or "unavailable"
end

local function BuildReport()
    if not diagnostic.startedAt or diagnostic.startedAt <= 0 then
        return nil
    end

    local endedAt = diagnostic.active and (GetTime and GetTime() or 0) or diagnostic.stoppedAt
    local duration = math.max(0, (endedAt or diagnostic.startedAt) - diagnostic.startedAt)
    local classToken
    if UnitClass then
        _, classToken = UnitClass("player")
    end
    local specIndex = GetSpecialization and GetSpecialization()
    local specName = specIndex and GetSpecializationInfo and select(2, GetSpecializationInfo(specIndex)) or "No specialization"
    local lines = {
        "ZoidsTools activity and memory report",
        string.format("Addon: %s | Character: %s %s", tostring(ns.version or "Development"), tostring(specName or "Unknown"), tostring(classToken or "Unknown")),
        string.format("State: %s | Duration: %.1fs", diagnostic.active and "running" or "stopped", duration),
        string.format("Frames: %d | hitches >=25/50/100ms: %d/%d/%d | worst frame: %.1fms", diagnostic.frameCount, diagnostic.hitch25, diagnostic.hitch50, diagnostic.hitch100, diagnostic.maxFrameMS),
        string.format("ZoidsTools memory: start %s | end %s | low %s | high %s | range %s",
            FormatKB(diagnostic.memoryFirstKB),
            FormatKB(diagnostic.memoryLastKB),
            FormatKB(diagnostic.memoryMinKB),
            FormatKB(diagnostic.memoryMaxKB),
            diagnostic.memoryMinKB and diagnostic.memoryMaxKB and FormatKB(diagnostic.memoryMaxKB - diagnostic.memoryMinKB) or "unavailable"),
        string.format("Total Lua memory: start %s | end %s | low %s | high %s",
            FormatKB(diagnostic.luaFirstKB),
            FormatKB(diagnostic.luaLastKB),
            FormatKB(diagnostic.luaMinKB),
            FormatKB(diagnostic.luaMaxKB)),
    }

    local recent = GetBlizzardMetric("RecentAverageTime")
    local peak = GetBlizzardMetric("PeakTime")
    local over5 = math.max(0, (GetBlizzardMetric("CountTimeOver5Ms") or 0) - (diagnostic.profilerBaseline.over5 or 0))
    local over10 = math.max(0, (GetBlizzardMetric("CountTimeOver10Ms") or 0) - (diagnostic.profilerBaseline.over10 or 0))
    if recent or peak then
        lines[#lines + 1] = string.format("Blizzard profiler: recent %.3fms | peak %.3fms | ticks over 5/10ms: %d/%d", recent or 0, peak or 0, over5, over10)
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Measured activity (total time | calls | maximum | >=5ms):"
    local activities = SortedActivities()
    if #activities == 0 then
        lines[#lines + 1] = "No instrumented activity was recorded."
    else
        for index = 1, math.min(#activities, MAX_REPORT_ACTIVITIES) do
            local row = activities[index]
            local sample = row.sample
            lines[#lines + 1] = string.format("%d. %s: %.2fms | %d | %.2fms | %d", index, row.label, sample.totalMS, sample.calls, sample.maxMS, sample.over5)
        end
    end

    local rises = {}
    local drops = {}
    for _, sample in ipairs(OrderedMemorySamples()) do
        if sample.addonKB and sample.deltaKB > 0 then
            rises[#rises + 1] = sample
        elseif sample.addonKB and sample.deltaKB < 0 then
            drops[#drops + 1] = sample
        end
    end
    table.sort(rises, function(left, right) return left.deltaKB > right.deltaKB end)
    table.sort(drops, function(left, right) return left.deltaKB < right.deltaKB end)

    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Largest sampled memory increases (%d-second samples; retaining the latest %d minutes):", SAMPLE_INTERVAL, math.floor((MAX_MEMORY_SAMPLES * SAMPLE_INTERVAL) / 60))
    if #rises == 0 then
        lines[#lines + 1] = "No positive ZoidsTools memory change was captured."
    else
        for index = 1, math.min(#rises, MAX_REPORT_SPIKES) do
            local sample = rises[index]
            lines[#lines + 1] = string.format("%d. +%.1f MB at %.1fs -> %s | nearby: %s", index, sample.deltaKB / 1024, sample.elapsed, FormatKB(sample.addonKB), sample.activity)
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Largest sampled memory decreases (usually garbage collection):"
    if #drops == 0 then
        lines[#lines + 1] = "No negative ZoidsTools memory change was captured."
    else
        for index = 1, math.min(#drops, MAX_REPORT_DROPS) do
            local sample = drops[index]
            lines[#lines + 1] = string.format("%d. %.1f MB at %.1fs -> %s | nearby: %s", index, sample.deltaKB / 1024, sample.elapsed, FormatKB(sample.addonKB), sample.activity)
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Notes: the recorder is bounded and stores counts instead of payloads. It does not force garbage collection or subscribe to Blizzard gameplay events. Memory scans add a small amount of temporary diagnostic overhead while recording."
    return table.concat(lines, "\n")
end

local function CreateReportWindow()
    if reportWindow then
        return reportWindow
    end

    local window = CreateFrame("Frame", "ZoidsToolsDiagnosticsReport", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(760, 520)
    window:SetPoint("CENTER")
    window:SetFrameStrata("FULLSCREEN_DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window.TitleText:SetText("ZoidsTools Diagnostic Report")

    local instruction = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instruction:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -34)
    instruction:SetText("The report is selected for copying. Press Ctrl+C, then paste it into the Codex task.")

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -56)
    scroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -34, 18)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    editBox:SetWidth(690)
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetScript("OnEscapePressed", function() window:Hide() end)
    scroll:SetScrollChild(editBox)

    window.editBox = editBox
    window:Hide()
    if UISpecialFrames then
        table.insert(UISpecialFrames, "ZoidsToolsDiagnosticsReport")
    end
    reportWindow = window
    return window
end

function ns:GetDiagnosticsStatusText()
    if diagnostic.active then
        local duration = math.max(0, (GetTime and GetTime() or 0) - diagnostic.startedAt)
        return string.format("Recording for %.0fs | memory %s", duration, FormatKB(diagnostic.memoryLastKB))
    end
    if diagnostic.startedAt and diagnostic.startedAt > 0 then
        return "Stopped | report ready"
    end
    return "Ready | recorder is off"
end

function ns:GetDiagnosticsReportText()
    diagnostic.lastReport = BuildReport() or diagnostic.lastReport
    return diagnostic.lastReport
end

function ns:ShowDiagnosticsReport()
    local report = self:GetDiagnosticsReportText()
    if not report then
        Print("No diagnostic run is available. Start recording first, reproduce the memory swing, then stop it.")
        return
    end

    local window = CreateReportWindow()
    local lineCount = 1
    for _ in report:gmatch("\n") do
        lineCount = lineCount + 1
    end
    window.editBox:SetHeight(math.max(430, lineCount * 15))
    window.editBox:SetText(report)
    window:Show()
    window:Raise()
    window.editBox:SetFocus()
    window.editBox:HighlightText()
end

function ns:ReportDiagnostics(showCopyWindow)
    local report = self:GetDiagnosticsReportText()
    if not report then
        Print("No diagnostic run is available. Run /zt diag start, reproduce the issue without reloading, then run /zt diag stop.")
        return
    end

    local duration = math.max(0, ((diagnostic.active and (GetTime and GetTime() or 0) or diagnostic.stoppedAt) or diagnostic.startedAt) - diagnostic.startedAt)
    Print(string.format("Diagnostics %s after %.1fs; memory %s to %s (range %s); hitches >=25/50/100ms: %d/%d/%d.",
        diagnostic.active and "running" or "stopped",
        duration,
        FormatKB(diagnostic.memoryFirstKB),
        FormatKB(diagnostic.memoryLastKB),
        diagnostic.memoryMinKB and diagnostic.memoryMaxKB and FormatKB(diagnostic.memoryMaxKB - diagnostic.memoryMinKB) or "unavailable",
        diagnostic.hitch25,
        diagnostic.hitch50,
        diagnostic.hitch100))
    if showCopyWindow ~= false then
        self:ShowDiagnosticsReport()
    end
end

function ns:StartDiagnostics()
    if diagnostic.active then
        Print("The activity recorder is already running. Use /zt diag stop when you are finished.")
        return
    end

    Reset()
    diagnostic.profilerBaseline.over5 = GetBlizzardMetric("CountTimeOver5Ms") or 0
    diagnostic.profilerBaseline.over10 = GetBlizzardMetric("CountTimeOver10Ms") or 0
    diagnostic.active = true
    if frame then
        frame:Show()
    end
    StoreMemorySample(false)
    Print("Activity recorder started. Use WoW normally until the memory rises and falls a few times, then run /zt diag stop. Do not /reload during the recording.")
end

function ns:StopDiagnostics()
    if not diagnostic.active then
        Print("The activity recorder is not running. Run /zt diag start first.")
        return
    end

    StoreMemorySample(true)
    diagnostic.stoppedAt = GetTime and GetTime() or diagnostic.startedAt
    diagnostic.active = false
    if frame then
        frame:Hide()
    end
    diagnostic.lastReport = BuildReport()
    self:ReportDiagnostics(true)
end

function ns:ResetDiagnostics()
    diagnostic.active = false
    if frame then
        frame:Hide()
    end
    Reset()
    diagnostic.startedAt = 0
    Print("Activity recorder and its report were cleared.")
end

function ns:InitializeDiagnostics()
    if frame then
        return
    end

    frame = CreateFrame("Frame")
    frame:Hide()
    frame:SetScript("OnUpdate", function(_, elapsed)
        if not diagnostic.active then
            return
        end

        local frameMS = (elapsed or 0) * 1000
        diagnostic.frameCount = diagnostic.frameCount + 1
        diagnostic.maxFrameMS = math.max(diagnostic.maxFrameMS, frameMS)
        diagnostic.hitch25 = diagnostic.hitch25 + (frameMS >= 25 and 1 or 0)
        diagnostic.hitch50 = diagnostic.hitch50 + (frameMS >= 50 and 1 or 0)
        diagnostic.hitch100 = diagnostic.hitch100 + (frameMS >= 100 and 1 or 0)
        diagnostic.sampleElapsed = diagnostic.sampleElapsed + (elapsed or 0)

        if diagnostic.sampleElapsed >= SAMPLE_INTERVAL then
            diagnostic.sampleElapsed = diagnostic.sampleElapsed - SAMPLE_INTERVAL
            StoreMemorySample(false)
        end
    end)
end
