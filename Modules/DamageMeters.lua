local _, ns = ...

local eventFrame
local windows = {}
local liveSessions = {}
local unitClasses = {}
local refreshPending = false
local lastRefresh = 0
local elapsedSinceRefresh = 0
local combatStartTime
local ApplyWindowStyle

local MAX_WINDOWS = 2
local DEFAULT_WIDTH = 280
local DEFAULT_ROWS = 5
local DEFAULT_ROW_HEIGHT = 18
local DEFAULT_ROW_GAP = 3
local DEFAULT_UPDATE_RATE = 0.2
local DEFAULT_BOTTOM = 110
local DEFAULT_RIGHT = 24
local DEFAULT_WINDOW_GAP = 6
local SNAP_DISTANCE = 18
local STATUSBAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

local typeInfo = {
    DamageDone = { text = "Damage Done", dataType = "DamageDone" },
    Dps = { text = "DPS", dataType = "DamageDone" },
    DamageTaken = { text = "Damage Taken", dataType = "DamageTaken" },
    HealingDone = { text = "Healing Done", dataType = "HealingDone" },
    Hps = { text = "HPS", dataType = "HealingDone" },
    Absorbs = { text = "Absorbs", dataType = "Absorbs" },
    Interrupts = { text = "Interrupts", dataType = "Interrupts" },
    Dispels = { text = "Dispels", dataType = "Dispels" },
    Deaths = { text = "Deaths", dataType = "Deaths" },
}

local typeOrder = {
    "DamageDone",
    "Dps",
    "DamageTaken",
    "HealingDone",
    "Hps",
    "Interrupts",
    "Dispels",
    "Deaths",
}

local damageEvents = {
    SWING_DAMAGE = true,
    RANGE_DAMAGE = true,
    SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
    SPELL_BUILDING_DAMAGE = true,
    SPELL_PERIODIC_BUILDING_DAMAGE = true,
    DAMAGE_SHIELD = true,
    ENVIRONMENTAL_DAMAGE = true,
}

local styleKeys = {
    width = true,
    rows = true,
    rowHeight = true,
    rowGap = true,
}

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result = pcall(func, ...)

    if ok then
        return result
    end

    return nil
end

local function ClampNumber(value, minValue, maxValue, fallback)
    value = tonumber(value) or fallback or minValue

    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end

    return value
end

local function ClampInteger(value, minValue, maxValue, fallback)
    return math.floor(ClampNumber(value, minValue, maxValue, fallback) + 0.5)
end

local function EnsureWindowDB(db, index)
    db.windows = db.windows or {}
    db.windows[index] = db.windows[index] or {}

    local window = db.windows[index]

    if not typeInfo[window.type] then
        window.type = index == 2 and "HealingDone" or "DamageDone"
    end

    window.width = ClampInteger(window.width, 180, 520, DEFAULT_WIDTH)
    window.rows = ClampInteger(window.rows, 1, 14, DEFAULT_ROWS)
    window.rowHeight = ClampInteger(window.rowHeight, 14, 34, DEFAULT_ROW_HEIGHT)
    window.rowGap = ClampInteger(window.rowGap, 0, 12, DEFAULT_ROW_GAP)

    return window
end

local function SyncWindowStyleFrom(db, sourceIndex)
    if not db or db.syncSettings ~= true then
        return
    end

    local source = EnsureWindowDB(db, sourceIndex or 1)

    for index = 1, MAX_WINDOWS do
        if index ~= sourceIndex then
            local target = EnsureWindowDB(db, index)

            for key in pairs(styleKeys) do
                target[key] = source[key]
            end
        end
    end
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.damageMeters = ns.db.damageMeters or {}

    local db = ns.db.damageMeters

    if db.enabled == nil then
        db.enabled = false
    end

    if db.secondWindow == nil then
        db.secondWindow = true
    end

    if db.syncSettings == nil then
        db.syncSettings = true
    end

    if db.shortNumbers == nil then
        db.shortNumbers = true
    end

    if db.nameClassColor == nil then
        db.nameClassColor = false
    end

    if db.nameOutline == nil then
        db.nameOutline = true
    end

    db.updateRate = ClampNumber(db.updateRate, 0.1, 2, DEFAULT_UPDATE_RATE)

    EnsureWindowDB(db, 1)
    EnsureWindowDB(db, 2)

    return db
end

local function IsInCombat()
    return UnitAffectingCombat and UnitAffectingCombat("player") == true
end

local function ClearLiveSessions()
    liveSessions = {}
    combatStartTime = GetTime and GetTime() or 0
end

local function UpdateUnitClassMap()
    wipe(unitClasses)

    local function AddUnit(unit)
        if not UnitExists or not UnitExists(unit) then
            return
        end

        local guid = UnitGUID and UnitGUID(unit)
        local classFilename = select(2, UnitClass(unit))

        if guid and classFilename then
            unitClasses[guid] = classFilename
        end
    end

    AddUnit("player")
    AddUnit("pet")

    if IsInRaid and IsInRaid() then
        for index = 1, 40 do
            AddUnit("raid" .. index)
            AddUnit("raidpet" .. index)
        end
    else
        for index = 1, 4 do
            AddUnit("party" .. index)
            AddUnit("partypet" .. index)
        end
    end
end

local function IsFriendly(flags)
    if CombatLog_Object_IsA and COMBATLOG_FILTER_FRIENDLY_UNITS then
        return CombatLog_Object_IsA(flags or 0, COMBATLOG_FILTER_FRIENDLY_UNITS) == true
    end

    return true
end

local function HasAnyFlag(flags, mask)
    if not flags or not mask or mask == 0 then
        return false
    end

    if bit and bit.band then
        return bit.band(flags, mask) ~= 0
    elseif bit32 and bit32.band then
        return bit32.band(flags, mask) ~= 0
    end

    return false
end

local function IsTrackedCombatant(guid, flags)
    if guid and UnitGUID then
        if guid == UnitGUID("player") or guid == UnitGUID("pet") then
            return true
        end
    end

    local affiliationMask = (COMBATLOG_OBJECT_AFFILIATION_MINE or 0)
        + (COMBATLOG_OBJECT_AFFILIATION_PARTY or 0)
        + (COMBATLOG_OBJECT_AFFILIATION_RAID or 0)

    if HasAnyFlag(flags, affiliationMask) then
        return true
    end

    return IsFriendly(flags)
end

local function GetClassColor(classFilename)
    if classFilename and C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local color = SafeCall(C_ClassColor.GetClassColor, classFilename)

        if color and color.GetRGB then
            local r, g, b = color:GetRGB()
            return r or 0.35, g or 0.65, b or 1
        end
    end

    local color = classFilename
        and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFilename]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename]))

    if color then
        return color.r or 0.35, color.g or 0.65, color.b or 1
    end

    return 0.35, 0.65, 1
end

local function SafeAmount(value)
    return tonumber(value) or 0
end

local function GetLiveSession(dataType)
    local session = liveSessions[dataType]

    if not session then
        session = {
            byKey = {},
            startTime = combatStartTime or (GetTime and GetTime() or 0),
        }
        liveSessions[dataType] = session
    end

    return session
end

local function AddLiveAmount(dataType, guid, name, flags, amount)
    amount = SafeAmount(amount)

    if amount <= 0 or not name or name == "" then
        return
    end

    local session = GetLiveSession(dataType)
    local key = guid or name
    local source = session.byKey[key]

    if not source then
        source = {
            guid = guid,
            name = name,
            classFilename = guid and unitClasses[guid] or nil,
            totalAmount = 0,
            isLocalPlayer = guid and UnitGUID and guid == UnitGUID("player") or false,
        }
        session.byKey[key] = source
    elseif not source.classFilename and guid then
        source.classFilename = unitClasses[guid]
    end

    source.totalAmount = source.totalAmount + amount
    session.totalAmount = (session.totalAmount or 0) + amount
    session.maxAmount = math.max(session.maxAmount or 0, source.totalAmount)
    session.lastUpdate = GetTime and GetTime() or 0
end

local function BuildLiveSession(dataType)
    local session = liveSessions[dataType]

    if not session then
        return nil
    end

    local sources = {}
    local duration = math.max(((GetTime and GetTime() or 0) - (session.startTime or combatStartTime or 0)), 1)

    for _, source in pairs(session.byKey) do
        local copy = {}

        for key, value in pairs(source) do
            copy[key] = value
        end

        copy.amountPerSecond = SafeAmount(copy.totalAmount) / duration
        sources[#sources + 1] = copy
    end

    table.sort(sources, function(left, right)
        return SafeAmount(left and left.totalAmount) > SafeAmount(right and right.totalAmount)
    end)

    return {
        combatSources = sources,
        totalAmount = session.totalAmount or 0,
        maxAmount = session.maxAmount or 0,
        duration = duration,
        lastUpdate = session.lastUpdate,
    }
end

local function GetDisplaySession(typeKey)
    local info = typeInfo[typeKey]
    local dataType = info and info.dataType or typeKey

    return BuildLiveSession(dataType)
end

local function GetDamageAmount(subevent, ...)
    if subevent == "SWING_DAMAGE" then
        return ...
    elseif subevent == "ENVIRONMENTAL_DAMAGE" then
        local _, amount = ...
        return amount
    end

    local _, _, _, amount = ...
    return amount
end

local function GetHealAmount(...)
    local _, _, _, amount, overhealing = ...

    amount = SafeAmount(amount)
    overhealing = SafeAmount(overhealing)

    return math.max(amount - overhealing, 0)
end

local function HandleCombatLogEvent()
    if not CombatLogGetCurrentEventInfo then
        return
    end

    local _, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, arg1, arg2, arg3, arg4, arg5 = CombatLogGetCurrentEventInfo()

    if not combatStartTime then
        combatStartTime = GetTime and GetTime() or 0
    end

    if damageEvents[subevent] then
        local amount = GetDamageAmount(subevent, arg1, arg2, arg3, arg4, arg5)

        if IsTrackedCombatant(sourceGUID, sourceFlags) then
            AddLiveAmount("DamageDone", sourceGUID, sourceName, sourceFlags, amount)
        end

        if IsTrackedCombatant(destGUID, destFlags) then
            AddLiveAmount("DamageTaken", destGUID, destName, destFlags, amount)
        end
    elseif subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
        if IsTrackedCombatant(sourceGUID, sourceFlags) then
            AddLiveAmount("HealingDone", sourceGUID, sourceName, sourceFlags, GetHealAmount(arg1, arg2, arg3, arg4, arg5))
        end
    elseif subevent == "SPELL_INTERRUPT" then
        if IsTrackedCombatant(sourceGUID, sourceFlags) then
            AddLiveAmount("Interrupts", sourceGUID, sourceName, sourceFlags, 1)
        end
    elseif subevent == "SPELL_DISPEL" or subevent == "SPELL_STOLEN" then
        if IsTrackedCombatant(sourceGUID, sourceFlags) then
            AddLiveAmount("Dispels", sourceGUID, sourceName, sourceFlags, 1)
        end
    elseif subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" or subevent == "PARTY_KILL" then
        AddLiveAmount("Deaths", destGUID, destName, destFlags, 1)
    end
end

local function FormatNumber(value)
    local db = EnsureDB()

    value = SafeAmount(value)

    if not db or db.shortNumbers ~= true then
        return BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(value + 0.5)) or tostring(math.floor(value + 0.5))
    end

    if value >= 1000000000 then
        return string.format("%.1fB", value / 1000000000)
    elseif value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fK", value / 1000)
    end

    return tostring(math.floor(value + 0.5))
end

local function BuildValueText(source, typeKey)
    if typeKey == "Dps" or typeKey == "Hps" then
        return FormatNumber(source and source.amountPerSecond)
    elseif typeKey == "Deaths" or typeKey == "Interrupts" or typeKey == "Dispels" then
        return FormatNumber(source and source.totalAmount)
    end

    local total = FormatNumber(source and source.totalAmount)
    local perSecond = SafeAmount(source and source.amountPerSecond)

    if perSecond > 0 then
        return total .. " (" .. FormatNumber(perSecond) .. ")"
    end

    return total
end

local function GetOrderedSources(session)
    local sources = {}
    local combatSources = session and session.combatSources

    if type(combatSources) ~= "table" then
        return sources
    end

    for _, source in ipairs(combatSources) do
        if type(source) == "table" then
            sources[#sources + 1] = source
        end
    end

    table.sort(sources, function(left, right)
        return SafeAmount(left and left.totalAmount) > SafeAmount(right and right.totalAmount)
    end)

    return sources
end

local function GetSourceClass(source)
    local classFilename = type(source) == "table" and source.classFilename or nil
    local guid = source and source.guid

    if (not classFilename or classFilename == "") and guid then
        classFilename = unitClasses[guid]
    end

    if (not classFilename or classFilename == "") and source and source.isLocalPlayer and UnitClass then
        classFilename = select(2, UnitClass("player"))
    end

    return classFilename
end

local function GetSourceName(source)
    local name = type(source) == "table" and source.name or nil

    if type(name) ~= "string" or name == "" then
        if source and source.isLocalPlayer and UnitName then
            name = UnitName("player")
        end
    end

    if type(name) ~= "string" or name == "" then
        name = "Unknown"
    end

    if Ambiguate then
        name = Ambiguate(name, "short")
    end

    return name
end

local function GetWindowHeight(config)
    local headerHeight = 24
    local padding = 7

    return headerHeight + padding + (config.rows * config.rowHeight) + math.max(config.rows - 1, 0) * config.rowGap + padding
end

local function GetDefaultWindowPoint(index)
    local db = EnsureDB()
    local first = db and EnsureWindowDB(db, 1) or {}
    local width = first.width or DEFAULT_WIDTH

    if index == 2 then
        return "BOTTOMRIGHT", "BOTTOMRIGHT", -DEFAULT_RIGHT, DEFAULT_BOTTOM
    end

    return "BOTTOMRIGHT", "BOTTOMRIGHT", -(DEFAULT_RIGHT + width + DEFAULT_WINDOW_GAP), DEFAULT_BOTTOM
end

local function SaveWindowPosition(index)
    local db = EnsureDB()
    local frame = windows[index]

    if not db or not frame then
        return
    end

    local config = EnsureWindowDB(db, index)
    local point, _, relativePoint, x, y = frame:GetPoint(1)

    config.point = point or "CENTER"
    config.relativePoint = relativePoint or config.point
    config.x = x or 0
    config.y = y or 0
end

local function RestoreWindowPosition(index)
    local db = EnsureDB()
    local frame = windows[index]
    local config = db and EnsureWindowDB(db, index)

    if not frame then
        return
    end

    frame:ClearAllPoints()

    if config and config.point then
        frame:SetPoint(config.point, UIParent, config.relativePoint or config.point, config.x or 0, config.y or 0)
    else
        local point, relativePoint, x, y = GetDefaultWindowPoint(index)
        frame:SetPoint(point, UIParent, relativePoint, x, y)
    end
end

local function SetTopLeft(frame, left, top)
    local parentHeight = UIParent and UIParent:GetHeight() or 0

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top - parentHeight)
end

local function SnapWindow(index)
    local frame = windows[index]
    local other = windows[index == 1 and 2 or 1]

    if not frame or not other or not other:IsShown() then
        return
    end

    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local otherLeft, otherRight, otherTop, otherBottom = other:GetLeft(), other:GetRight(), other:GetTop(), other:GetBottom()

    if not left or not right or not top or not bottom or not otherLeft or not otherRight or not otherTop or not otherBottom then
        return
    end

    local width = right - left
    local height = top - bottom
    local newLeft = left
    local newTop = top
    local snapped = false
    local verticallyNear = top >= otherBottom - SNAP_DISTANCE and bottom <= otherTop + SNAP_DISTANCE
    local horizontallyNear = right >= otherLeft - SNAP_DISTANCE and left <= otherRight + SNAP_DISTANCE

    if verticallyNear and math.abs(left - otherRight - DEFAULT_WINDOW_GAP) <= SNAP_DISTANCE then
        newLeft = otherRight + DEFAULT_WINDOW_GAP
        snapped = true
    elseif verticallyNear and math.abs(right - otherLeft + DEFAULT_WINDOW_GAP) <= SNAP_DISTANCE then
        newLeft = otherLeft - width - DEFAULT_WINDOW_GAP
        snapped = true
    end

    if snapped and math.abs(top - otherTop) <= SNAP_DISTANCE then
        newTop = otherTop
    elseif snapped and math.abs(bottom - otherBottom) <= SNAP_DISTANCE then
        newTop = otherBottom + height
    elseif horizontallyNear and math.abs(top - otherBottom + DEFAULT_WINDOW_GAP) <= SNAP_DISTANCE then
        newTop = otherBottom - DEFAULT_WINDOW_GAP
        snapped = true
    elseif horizontallyNear and math.abs(bottom - otherTop - DEFAULT_WINDOW_GAP) <= SNAP_DISTANCE then
        newTop = otherTop + height + DEFAULT_WINDOW_GAP
        snapped = true
    end

    if snapped then
        SetTopLeft(frame, newLeft, newTop)
    end
end

local function SaveWindowSize(index)
    local db = EnsureDB()
    local frame = windows[index]
    local config = db and EnsureWindowDB(db, index)

    if not frame or not config then
        return
    end

    local width = ClampInteger(frame:GetWidth(), 180, 520, DEFAULT_WIDTH)
    local height = ClampNumber(frame:GetHeight(), 48, 600, GetWindowHeight(config))
    local headerHeight = 24
    local padding = 14
    local rowUnit = math.max((config.rowHeight or DEFAULT_ROW_HEIGHT) + (config.rowGap or DEFAULT_ROW_GAP), 1)
    local rows = math.floor(((height - headerHeight - padding + (config.rowGap or DEFAULT_ROW_GAP)) / rowUnit) + 0.5)

    config.width = width
    config.rows = ClampInteger(rows, 1, 14, DEFAULT_ROWS)
    SyncWindowStyleFrom(db, index)

    for windowIndex = 1, MAX_WINDOWS do
        if windows[windowIndex] then
            ApplyWindowStyle(windowIndex)
        end
    end
end

function ApplyWindowStyle(index)
    local db = EnsureDB()
    local frame = windows[index]
    local config = db and EnsureWindowDB(db, index)

    if not frame or not config then
        return
    end

    local width = config.width or DEFAULT_WIDTH
    local height = GetWindowHeight(config)
    local headerHeight = 24
    local padding = 7

    frame:SetSize(width, height)

    if frame.SetResizeBounds then
        frame:SetResizeBounds(180, 48, 520, 600)
    elseif frame.SetMinResize and frame.SetMaxResize then
        frame:SetMinResize(180, 48)
        frame:SetMaxResize(520, 600)
    end

    frame.header:ClearAllPoints()
    frame.header:SetHeight(headerHeight)
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.titleButton:ClearAllPoints()
    frame.titleButton:SetPoint("TOPLEFT", frame.header, "TOPLEFT", 8, 0)
    frame.titleButton:SetPoint("BOTTOMRIGHT", frame.settingsButton, "BOTTOMLEFT", -4, 0)

    for rowIndex = 1, math.max(config.rows, #frame.rows) do
        local row = frame.rows[rowIndex]

        if row then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -(headerHeight + padding + ((rowIndex - 1) * (config.rowHeight + config.rowGap))))
            row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -(headerHeight + padding + ((rowIndex - 1) * (config.rowHeight + config.rowGap))))
            row:SetHeight(config.rowHeight)
        end
    end

    frame.empty:ClearAllPoints()
    frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -(headerHeight + padding))
    frame.empty:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
end

local function ResetWindowLayout()
    local db = EnsureDB()

    if not db then
        return
    end

    for index = 1, MAX_WINDOWS do
        local config = EnsureWindowDB(db, index)
        local point, relativePoint, x, y = GetDefaultWindowPoint(index)

        config.point = point
        config.relativePoint = relativePoint
        config.x = x
        config.y = y

        RestoreWindowPosition(index)
    end
end

local function CreateRow(frame, rowIndex)
    local row = CreateFrame("Frame", nil, frame)
    row:SetHeight(DEFAULT_ROW_HEIGHT)

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetColorTexture(0, 0, 0, 0.62)

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetAllPoints()
    row.bar:SetStatusBarTexture(STATUSBAR_TEXTURE)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)
    row.bar:SetAlpha(0.62)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -122, 0)
    row.name:SetJustifyH("LEFT")

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.value:SetWidth(112)
    row.value:SetJustifyH("RIGHT")

    frame.rows[rowIndex] = row

    return row
end

local function HideMenus()
    for _, frame in pairs(windows) do
        if frame.typeMenu then
            frame.typeMenu:Hide()
        end

        if frame.settingsMenu then
            frame.settingsMenu:Hide()
        end
    end
end

local function CreateMenuFrame(parent, width)
    local menu = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetToplevel(true)
    menu:SetWidth(width)
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    menu:SetBackdropColor(0.015, 0.014, 0.012, 1)
    menu:SetBackdropBorderColor(0.85, 0.7, 0.38, 0.65)
    menu:Hide()

    return menu
end

local function CreateMenuRow(menu, index, text, onClick)
    local rowHeight = 24
    local row = CreateFrame("Button", nil, menu)

    row:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -6 - ((index - 1) * rowHeight))
    row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -8, -6 - ((index - 1) * rowHeight))
    row:SetHeight(rowHeight)
    row:RegisterForClicks("LeftButtonUp")

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 0.82, 0.18, 0.08)
    row.highlight:Hide()

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetText(text)

    row:SetScript("OnClick", function()
        if onClick then
            onClick()
        end

        menu:Hide()
    end)
    row:SetScript("OnEnter", function(self)
        self.highlight:Show()
        self.text:SetTextColor(1, 0.86, 0.18)
    end)
    row:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        self.text:SetTextColor(1, 1, 1)
    end)

    return row
end

local function EnsureTypeMenu(index)
    local frame = windows[index]

    if not frame then
        return nil
    end

    if frame.typeMenu then
        return frame.typeMenu
    end

    local menu = CreateMenuFrame(frame, 180)
    menu:SetPoint("TOPLEFT", frame.titleButton, "BOTTOMLEFT", -2, -2)
    menu:SetHeight((#typeOrder * 24) + 12)

    for rowIndex, typeKey in ipairs(typeOrder) do
        CreateMenuRow(menu, rowIndex, typeInfo[typeKey].text, function()
            ns:SetDamageMeterWindowType(index, typeKey)
        end)
    end

    frame.typeMenu = menu

    return menu
end

local function EnsureSettingsMenu(index)
    local frame = windows[index]

    if not frame then
        return nil
    end

    if frame.settingsMenu then
        return frame.settingsMenu
    end

    local rowCount = 11
    local menu = CreateMenuFrame(frame, 210)
    menu:SetPoint("TOPRIGHT", frame.settingsButton, "BOTTOMRIGHT", 2, -2)
    menu:SetHeight((rowCount * 24) + 12)
    menu.rows = {}

    for rowIndex = 1, rowCount do
        menu.rows[rowIndex] = CreateMenuRow(menu, rowIndex, "", nil)
    end

    frame.settingsMenu = menu

    return menu
end

local function SetSettingRow(row, checked, text, onClick)
    row.text:SetText((checked == nil and "" or (checked and "[x] " or "[ ] ")) .. text)
    row:SetScript("OnClick", function()
        if onClick then
            onClick()
        end
    end)
end

local function RefreshSettingsMenu(index)
    local db = EnsureDB()
    local menu = EnsureSettingsMenu(index)
    local config = db and EnsureWindowDB(db, index)

    if not db or not menu or not config then
        return
    end

    SetSettingRow(menu.rows[1], db.secondWindow == true, "Show second window", function()
        ns:SetDamageMetersSecondWindow(not db.secondWindow)
        RefreshSettingsMenu(index)
    end)
    SetSettingRow(menu.rows[2], db.syncSettings == true, "Sync window layout", function()
        ns:SetDamageMetersSyncSettings(not db.syncSettings)
        RefreshSettingsMenu(index)
    end)
    SetSettingRow(menu.rows[3], db.nameClassColor == true, "Class color names", function()
        ns:SetDamageMetersNameClassColor(not db.nameClassColor)
        RefreshSettingsMenu(index)
    end)
    SetSettingRow(menu.rows[4], db.nameOutline == true, "Outline names", function()
        ns:SetDamageMetersNameOutline(not db.nameOutline)
        RefreshSettingsMenu(index)
    end)
    SetSettingRow(menu.rows[5], db.shortNumbers == true, "Short numbers", function()
        ns:SetDamageMetersShortNumbers(not db.shortNumbers)
        RefreshSettingsMenu(index)
    end)
    SetSettingRow(menu.rows[6], nil, "Add row", function()
        ns:SetDamageMeterWindowSetting(index, "rows", config.rows + 1)
        RefreshSettingsMenu(index)
    end)
    SetSettingRow(menu.rows[7], nil, "Remove row", function()
        ns:SetDamageMeterWindowSetting(index, "rows", config.rows - 1)
        RefreshSettingsMenu(index)
    end)
    SetSettingRow(menu.rows[8], nil, "Taller rows", function()
        ns:SetDamageMeterWindowSetting(index, "rowHeight", config.rowHeight + 1)
        RefreshSettingsMenu(index)
    end)
    SetSettingRow(menu.rows[9], nil, "Shorter rows", function()
        ns:SetDamageMeterWindowSetting(index, "rowHeight", config.rowHeight - 1)
        RefreshSettingsMenu(index)
    end)
    SetSettingRow(menu.rows[10], nil, "Reset data", function()
        ns:ResetDamageMeterData()
    end)
    SetSettingRow(menu.rows[11], nil, "Refresh", function()
        ns:RefreshDamageMeters()
    end)
end

local function CreateHeaderButton(parent, text, tooltip)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")

    button:SetSize(20, 18)
    button:RegisterForClicks("LeftButtonUp")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(0.03, 0.025, 0.018, 0.95)
    button:SetBackdropBorderColor(0.75, 0.62, 0.25, 0.5)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("CENTER")
    button.text:SetText(text)

    if tooltip then
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return button
end

local function GetScaledCursorPosition()
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local x, y = GetCursorPosition()

    return (x or 0) / scale, (y or 0) / scale
end

local function BeginWindowDrag(frame, index, fromTitle)
    local left = frame:GetLeft()
    local top = frame:GetTop()

    if not left or not top then
        return
    end

    HideMenus()

    local cursorX, cursorY = GetScaledCursorPosition()

    frame.ZTMoving = {
        index = index,
        offsetX = cursorX - left,
        offsetY = top - cursorY,
        startX = cursorX,
        startY = cursorY,
        fromTitle = fromTitle == true,
    }
    frame.ZTDragMoved = false

    frame:SetScript("OnUpdate", function(self)
        local moving = self.ZTMoving

        if not moving then
            return
        end

        local x, y = GetScaledCursorPosition()

        if math.abs(x - moving.startX) > 2 or math.abs(y - moving.startY) > 2 then
            self.ZTDragMoved = true
        end

        SetTopLeft(self, x - moving.offsetX, y + moving.offsetY)
    end)
end

local function EndWindowDrag(frame, index)
    local moving = frame and frame.ZTMoving

    if not moving then
        return
    end

    frame.ZTMoving = nil
    frame:SetScript("OnUpdate", nil)
    SnapWindow(index)
    SaveWindowPosition(index)

    if not moving.fromTitle then
        frame.ZTDragMoved = false
    end
end

local function BeginWindowResize(frame, index)
    local left = frame:GetLeft()
    local top = frame:GetTop()

    if not left or not top then
        return
    end

    HideMenus()

    frame.ZTResizing = {
        index = index,
        left = left,
        top = top,
    }

    frame:SetScript("OnUpdate", function(self)
        local resizing = self.ZTResizing

        if not resizing then
            return
        end

        local x, y = GetScaledCursorPosition()
        local db = EnsureDB()
        local config = db and EnsureWindowDB(db, index)
        local fallbackHeight = config and GetWindowHeight(config) or 140
        local width = ClampInteger(x - resizing.left, 180, 520, DEFAULT_WIDTH)
        local height = ClampNumber(resizing.top - y, 48, 600, fallbackHeight)

        SetTopLeft(self, resizing.left, resizing.top)
        self:SetSize(width, height)
    end)
end

local function EndWindowResize(frame, index)
    if not frame or not frame.ZTResizing then
        return
    end

    frame.ZTResizing = nil
    frame:SetScript("OnUpdate", nil)
    SaveWindowSize(index)
    SaveWindowPosition(index)
    ns:RefreshDamageMeters()
end

local function CreateWindow(index)
    if windows[index] then
        return windows[index]
    end

    local frame = CreateFrame("Frame", "ZoidsToolsDamageMeterWindow" .. index, UIParent, "BackdropTemplate")

    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(20 + index)
    frame:SetMovable(true)

    if frame.SetResizable then
        frame:SetResizable(true)
    end

    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            BeginWindowDrag(self, index, false)
        end
    end)
    frame:SetScript("OnMouseUp", function(self)
        EndWindowDrag(self, index)
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.02, 0.018, 0.014, 0.72)
    frame:SetBackdropBorderColor(0.85, 0.7, 0.38, 0.45)

    frame.header = CreateFrame("Button", nil, frame)
    frame.header:EnableMouse(true)
    frame.header:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            BeginWindowDrag(frame, index, false)
        end
    end)
    frame.header:SetScript("OnMouseUp", function()
        EndWindowDrag(frame, index)
    end)

    frame.headerBackground = frame.header:CreateTexture(nil, "BACKGROUND")
    frame.headerBackground:SetAllPoints()
    frame.headerBackground:SetColorTexture(0.04, 0.035, 0.025, 0.95)

    frame.headerLine = frame.header:CreateTexture(nil, "ARTWORK")
    frame.headerLine:SetPoint("BOTTOMLEFT", frame.header, "BOTTOMLEFT", 5, 0)
    frame.headerLine:SetPoint("BOTTOMRIGHT", frame.header, "BOTTOMRIGHT", -5, 0)
    frame.headerLine:SetHeight(1)
    frame.headerLine:SetColorTexture(1, 0.82, 0.18, 0.22)

    frame.settingsButton = CreateHeaderButton(frame.header, "S", "Meter settings")
    frame.settingsButton:SetPoint("RIGHT", frame.header, "RIGHT", -29, 0)
    frame.settingsButton:SetScript("OnClick", function()
        local menu = EnsureSettingsMenu(index)

        if menu:IsShown() then
            menu:Hide()
        else
            HideMenus()
            RefreshSettingsMenu(index)
            menu:Show()
        end
    end)

    frame.resetButton = CreateHeaderButton(frame.header, "R", "Reset meter results")
    frame.resetButton:SetPoint("RIGHT", frame.header, "RIGHT", -6, 0)
    frame.resetButton:SetScript("OnClick", function()
        ns:ResetDamageMeterData()
        ns:Print("Damage meter results reset.")
    end)

    frame.titleButton = CreateFrame("Button", nil, frame.header)
    frame.titleButton:RegisterForClicks("LeftButtonUp")
    frame.titleButton:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            BeginWindowDrag(frame, index, true)
        end
    end)
    frame.titleButton:SetScript("OnMouseUp", function()
        EndWindowDrag(frame, index)
    end)
    frame.titleButton.text = frame.titleButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.titleButton.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    frame.titleButton.text:SetPoint("LEFT", frame.titleButton, "LEFT", 0, 0)
    frame.titleButton.text:SetPoint("RIGHT", frame.titleButton, "RIGHT", 0, 0)
    frame.titleButton.text:SetJustifyH("LEFT")
    frame.titleButton.text:SetTextColor(1, 0.82, 0)
    frame.titleButton.text:SetShadowColor(0, 0, 0, 1)
    frame.titleButton.text:SetShadowOffset(1, -1)
    frame.titleButton:SetScript("OnClick", function()
        if frame.ZTDragMoved then
            frame.ZTDragMoved = false
            return
        end

        local menu = EnsureTypeMenu(index)

        if menu:IsShown() then
            menu:Hide()
        else
            HideMenus()
            menu:Show()
        end
    end)
    frame.titleButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Click to change this meter.")
        GameTooltip:Show()
    end)
    frame.titleButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame.rows = {}

    for rowIndex = 1, 14 do
        CreateRow(frame, rowIndex)
    end

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.empty:SetJustifyH("CENTER")
    frame.empty:SetJustifyV("MIDDLE")
    frame.empty:SetText("No combat data")

    frame.resize = CreateFrame("Button", nil, frame)
    frame.resize:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    frame.resize:SetSize(16, 16)
    frame.resize:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    frame.resize.texture = frame.resize:CreateTexture(nil, "OVERLAY")
    frame.resize.texture:SetPoint("BOTTOMRIGHT", frame.resize, "BOTTOMRIGHT", 0, 0)
    frame.resize.texture:SetSize(12, 12)
    frame.resize.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    frame.resize:SetScript("OnMouseDown", function()
        BeginWindowResize(frame, index)
    end)
    frame.resize:SetScript("OnMouseUp", function()
        EndWindowResize(frame, index)
    end)
    frame.resize:SetScript("OnEnter", function(self)
        self.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    end)
    frame.resize:SetScript("OnLeave", function(self)
        self.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    end)

    windows[index] = frame
    if not frame.ZTResizing then
        ApplyWindowStyle(index)
    end
    RestoreWindowPosition(index)

    return frame
end

local function HideWindowRows(frame)
    if not frame or not frame.rows then
        return
    end

    for _, row in ipairs(frame.rows) do
        row:Hide()
    end
end

local function ApplyNameFont(row, db)
    local flags = db and db.nameOutline and "OUTLINE" or ""

    row.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, flags)
    row.name:SetShadowOffset(1, -1)
    row.name:SetShadowColor(0, 0, 0, 1)
    row.value:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    row.value:SetShadowOffset(1, -1)
    row.value:SetShadowColor(0, 0, 0, 1)
end

local function RefreshWindow(index)
    local db = EnsureDB()
    local frame = CreateWindow(index)
    local config = db and EnsureWindowDB(db, index)

    if not db or not config or not db.enabled or (index == 2 and not db.secondWindow) then
        HideWindowRows(frame)
        frame:Hide()
        return
    end

    if not frame.ZTResizing then
        ApplyWindowStyle(index)
    end

    local label = typeInfo[config.type] and typeInfo[config.type].text or config.type
    local session = GetDisplaySession(config.type)
    local sources = GetOrderedSources(session)
    local rows = config.rows or DEFAULT_ROWS
    local maxAmount = SafeAmount(session and session.maxAmount)

    if maxAmount <= 0 then
        for _, source in ipairs(sources) do
            maxAmount = math.max(maxAmount, SafeAmount(source.totalAmount))
        end
    end

    if maxAmount <= 0 then
        maxAmount = 1
    end

    frame.titleButton.text:SetText(label)

    local shown = 0

    for rowIndex = 1, #frame.rows do
        local row = frame.rows[rowIndex]
        local source = rowIndex <= rows and sources[rowIndex] or nil

        if source then
            local classFilename = GetSourceClass(source)
            local r, g, b = GetClassColor(classFilename)
            local amount = SafeAmount(source.totalAmount)
            local name = tostring(rowIndex) .. ". " .. GetSourceName(source)

            ApplyNameFont(row, db)
            row.name:SetText(name)

            if db.nameClassColor == true then
                row.name:SetTextColor(r, g, b)
            else
                row.name:SetTextColor(1, 1, 1)
            end

            row.value:SetText(BuildValueText(source, config.type))
            row.value:SetTextColor(1, 1, 1)
            row.bar:SetMinMaxValues(0, maxAmount)
            row.bar:SetValue(amount)
            row.bar:SetStatusBarColor(r, g, b, 0.72)
            row:Show()
            shown = shown + 1
        else
            row:Hide()
        end
    end

    frame.empty:SetShown(shown == 0)
    frame:Show()
end

local function RefreshAll()
    refreshPending = false
    lastRefresh = GetTime and GetTime() or 0
    UpdateUnitClassMap()

    for index = 1, MAX_WINDOWS do
        RefreshWindow(index)
    end
end

local function ScheduleRefresh(immediate)
    if immediate then
        RefreshAll()
        return
    end

    if refreshPending then
        return
    end

    local db = EnsureDB()
    local rate = db and db.updateRate or DEFAULT_UPDATE_RATE
    local now = GetTime and GetTime() or 0
    local delay = math.max(rate - (now - lastRefresh), 0.03)

    refreshPending = true

    if C_Timer and C_Timer.After then
        C_Timer.After(delay, RefreshAll)
    else
        RefreshAll()
    end
end

local function OnUpdate(_, elapsed)
    local db = EnsureDB()

    if not db or not db.enabled then
        return
    end

    elapsedSinceRefresh = elapsedSinceRefresh + (elapsed or 0)

    if elapsedSinceRefresh < (db.updateRate or DEFAULT_UPDATE_RATE) then
        return
    end

    elapsedSinceRefresh = 0
    RefreshAll()
end

local function UpdateEventRegistration()
    if not eventFrame then
        return
    end

    local db = EnsureDB()
    local enabled = db and db.enabled == true

    eventFrame:UnregisterAllEvents()
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

    if enabled then
        eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end

    eventFrame:SetScript("OnUpdate", enabled and OnUpdate or nil)
end

function ns:SetDamageMetersEnabled(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.enabled = value == true

    UpdateEventRegistration()
    RefreshAll()
end

function ns:GetDamageMetersEnabled()
    local db = EnsureDB()

    return db and db.enabled == true
end

function ns:SetDamageMetersSecondWindow(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.secondWindow = value == true
    RefreshAll()
end

function ns:GetDamageMetersSecondWindow()
    local db = EnsureDB()

    return db and db.secondWindow == true
end

function ns:SetDamageMetersSyncSettings(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.syncSettings = value == true
    SyncWindowStyleFrom(db, 1)
    RefreshAll()
end

function ns:GetDamageMetersSyncSettings()
    local db = EnsureDB()

    return db and db.syncSettings == true
end

function ns:SetDamageMetersShortNumbers(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.shortNumbers = value == true
    RefreshAll()
end

function ns:GetDamageMetersShortNumbers()
    local db = EnsureDB()

    return db and db.shortNumbers == true
end

function ns:SetDamageMetersNameClassColor(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.nameClassColor = value == true
    RefreshAll()
end

function ns:GetDamageMetersNameClassColor()
    local db = EnsureDB()

    return db and db.nameClassColor == true
end

function ns:SetDamageMetersNameOutline(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.nameOutline = value == true
    RefreshAll()
end

function ns:GetDamageMetersNameOutline()
    local db = EnsureDB()

    return db and db.nameOutline == true
end

function ns:SetDamageMetersUpdateRate(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.updateRate = ClampNumber(value, 0.1, 2, DEFAULT_UPDATE_RATE)
end

function ns:GetDamageMetersUpdateRate()
    local db = EnsureDB()

    return db and db.updateRate or DEFAULT_UPDATE_RATE
end

function ns:SetDamageMeterWindowType(index, typeKey)
    local db = EnsureDB()
    local config = db and EnsureWindowDB(db, index)

    if not config then
        return
    end

    config.type = typeInfo[typeKey] and typeKey or config.type
    RefreshAll()
end

function ns:GetDamageMeterWindowType(index)
    local db = EnsureDB()
    local config = db and EnsureWindowDB(db, index)

    return config and config.type or (index == 2 and "HealingDone" or "DamageDone")
end

function ns:SetDamageMeterWindowSetting(index, key, value)
    local db = EnsureDB()
    local config = db and EnsureWindowDB(db, index)

    if not config or not styleKeys[key] then
        return
    end

    if key == "width" then
        config[key] = ClampInteger(value, 180, 520, DEFAULT_WIDTH)
    elseif key == "rows" then
        config[key] = ClampInteger(value, 1, 14, DEFAULT_ROWS)
    elseif key == "rowHeight" then
        config[key] = ClampInteger(value, 14, 34, DEFAULT_ROW_HEIGHT)
    elseif key == "rowGap" then
        config[key] = ClampInteger(value, 0, 12, DEFAULT_ROW_GAP)
    end

    SyncWindowStyleFrom(db, index)
    RefreshAll()
end

function ns:GetDamageMeterWindowSetting(index, key)
    local db = EnsureDB()
    local config = db and EnsureWindowDB(db, index)

    return config and config[key]
end

function ns:GetDamageMeterTypeOptions()
    local options = {}

    for _, typeKey in ipairs(typeOrder) do
        options[#options + 1] = {
            value = typeKey,
            text = typeInfo[typeKey].text,
        }
    end

    return options
end

function ns:GetDamageMetersStatusText()
    local db = EnsureDB()

    if not db or not db.enabled then
        return "ZoidsTools damage meters are disabled."
    end

    return "Live combat-log updates are active. Meter results can be cleared from the window header."
end

function ns:ResetDamageMeterLayout()
    ResetWindowLayout()
    RefreshAll()
end

function ns:ResetDamageMeterData()
    ClearLiveSessions()
    RefreshAll()
end

function ns:RefreshDamageMeters()
    RefreshAll()
end

function ns:InitializeDamageMeters()
    EnsureDB()
    UpdateUnitClassMap()

    for index = 1, MAX_WINDOWS do
        CreateWindow(index)
    end

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function(_, event)
            local db = EnsureDB()

            if event == "PLAYER_ENTERING_WORLD" then
                UpdateUnitClassMap()
            elseif event == "GROUP_ROSTER_UPDATE" then
                UpdateUnitClassMap()
            elseif event == "PLAYER_REGEN_DISABLED" then
                ClearLiveSessions()
                UpdateUnitClassMap()
            elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
                HandleCombatLogEvent()
            end

            ScheduleRefresh(event ~= "COMBAT_LOG_EVENT_UNFILTERED")
        end)
    end

    UpdateEventRegistration()

    RefreshAll()
end
