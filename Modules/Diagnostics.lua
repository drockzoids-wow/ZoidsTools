local ADDON_NAME, ns = ...

local diagnostic = { active = false, startedAt = 0, samples = {}, profilerBaseline = {}, frameCount = 0, hitch25 = 0, hitch50 = 0, hitch100 = 0, maxFrameMS = 0 }
local frame
local unpack = unpack or table.unpack
local GetBlizzardMetric

local function NowMS()
    return debugprofilestop and debugprofilestop() or ((GetTime and GetTime() or 0) * 1000)
end

local function Print(message)
    if ns.Print then ns:Print(message) elseif DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("ZoidsTools: " .. tostring(message)) end
end

local function Reset()
    diagnostic.startedAt = GetTime and GetTime() or 0
    diagnostic.samples = {}
    diagnostic.profilerBaseline = {}
    diagnostic.frameCount, diagnostic.hitch25, diagnostic.hitch50, diagnostic.hitch100, diagnostic.maxFrameMS = 0, 0, 0, 0, 0
end

function ns:IsDiagnosticsActive()
    return diagnostic.active == true
end

function ns:WrapDiagnosticFunction(label, func)
    if type(func) ~= "function" then return func end
    return function(...)
        if not diagnostic.active then return func(...) end
        local started = NowMS()
        local results = { func(...) }
        local elapsed = NowMS() - started
        local sample = diagnostic.samples[label]
        if not sample then
            sample = { calls = 0, totalMS = 0, maxMS = 0, over1 = 0, over5 = 0, over10 = 0 }
            diagnostic.samples[label] = sample
        end
        sample.calls = sample.calls + 1
        sample.totalMS = sample.totalMS + elapsed
        sample.maxMS = math.max(sample.maxMS, elapsed)
        sample.over1 = sample.over1 + (elapsed >= 1 and 1 or 0)
        sample.over5 = sample.over5 + (elapsed >= 5 and 1 or 0)
        sample.over10 = sample.over10 + (elapsed >= 10 and 1 or 0)
        return unpack(results)
    end
end

GetBlizzardMetric = function(metricName)
    local metric = Enum and Enum.AddOnProfilerMetric and Enum.AddOnProfilerMetric[metricName]
    if not C_AddOnProfiler or type(C_AddOnProfiler.GetAddOnMetric) ~= "function" or metric == nil then return nil end
    local ok, value = pcall(C_AddOnProfiler.GetAddOnMetric, ADDON_NAME, metric)
    return ok and tonumber(value) or nil
end

local function SortedSamples()
    local rows = {}
    for label, sample in pairs(diagnostic.samples) do rows[#rows + 1] = { label = label, sample = sample } end
    table.sort(rows, function(left, right) return left.sample.totalMS > right.sample.totalMS end)
    return rows
end

function ns:ReportDiagnostics()
    local duration = math.max(0, (GetTime and GetTime() or 0) - diagnostic.startedAt)
    Print(string.format("Diagnostics %s after %.1fs; frames %d; hitches >=25/50/100ms: %d/%d/%d; worst %.1fms.", diagnostic.active and "running" or "stopped", duration, diagnostic.frameCount, diagnostic.hitch25, diagnostic.hitch50, diagnostic.hitch100, diagnostic.maxFrameMS))
    local recent, peak = GetBlizzardMetric("RecentAverageTime"), GetBlizzardMetric("PeakTime")
    local over5 = math.max(0, (GetBlizzardMetric("CountTimeOver5Ms") or 0) - (diagnostic.profilerBaseline.over5 or 0))
    local over10 = math.max(0, (GetBlizzardMetric("CountTimeOver10Ms") or 0) - (diagnostic.profilerBaseline.over10 or 0))
    if recent or peak then Print(string.format("Blizzard profiler: recent %.3fms, peak %.3fms, ticks over 5/10ms: %d/%d.", recent or 0, peak or 0, over5 or 0, over10 or 0)) end
    local rows = SortedSamples()
    if #rows == 0 then Print("No subsystem samples recorded yet.") return end
    Print("Top measured subsystems (total / calls / max / >=5ms):")
    for index = 1, math.min(#rows, 12) do
        local row, sample = rows[index], rows[index].sample
        Print(string.format("%d. %s: %.2fms / %d / %.2fms / %d", index, row.label, sample.totalMS, sample.calls, sample.maxMS, sample.over5))
    end
end

function ns:StartDiagnostics()
    Reset()
    diagnostic.profilerBaseline.over5 = GetBlizzardMetric("CountTimeOver5Ms") or 0
    diagnostic.profilerBaseline.over10 = GetBlizzardMetric("CountTimeOver10Ms") or 0
    diagnostic.active = true
    if frame then frame:Show() end
    Print("Diagnostics started. Reproduce the FPS drop, then run /zt diag report.")
end

function ns:StopDiagnostics()
    diagnostic.active = false
    if frame then frame:Hide() end
    self:ReportDiagnostics()
end

function ns:ResetDiagnostics()
    Reset()
    Print("Diagnostics reset.")
end

function ns:InitializeDiagnostics()
    if frame then return end
    frame = CreateFrame("Frame")
    frame:Hide()
    frame:SetScript("OnUpdate", function(_, elapsed)
        if not diagnostic.active then return end
        local frameMS = (elapsed or 0) * 1000
        diagnostic.frameCount = diagnostic.frameCount + 1
        diagnostic.maxFrameMS = math.max(diagnostic.maxFrameMS, frameMS)
        diagnostic.hitch25 = diagnostic.hitch25 + (frameMS >= 25 and 1 or 0)
        diagnostic.hitch50 = diagnostic.hitch50 + (frameMS >= 50 and 1 or 0)
        diagnostic.hitch100 = diagnostic.hitch100 + (frameMS >= 100 and 1 or 0)
    end)
end
