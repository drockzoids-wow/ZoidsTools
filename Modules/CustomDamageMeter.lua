local _, ns = ...

local FRAME_NAME = "ZoidsToolsCustomDamageMeter"
local DEFAULT_ROW_COUNT = 5
local MAX_ROW_COUNT = 20
local ROW_HEIGHT = 20
local ROW_SPACING = 2
local REFRESH_INTERVAL = 0.15
local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local MIN_WIDTH = 260
local MAX_WIDTH = 620
local SNAP_THRESHOLD = 24
local MAX_SNAP_GAP = 24
local DEFAULT_WIDTH = 300
local DEFAULT_HEIGHT = 35 + (DEFAULT_ROW_COUNT * ROW_HEIGHT) + ((DEFAULT_ROW_COUNT - 1) * ROW_SPACING)
local MAX_HEIGHT = 35 + (MAX_ROW_COUNT * ROW_HEIGHT) + ((MAX_ROW_COUNT - 1) * ROW_SPACING)

local METER_CATEGORIES = {
    {
        label = DAMAGE or "Damage",
        types = {
            { key = "DamageDone", enum = "DamageDone", global = "DAMAGE_METER_TYPE_DAMAGE_DONE", label = "Damage Done" },
            { key = "Dps", enum = "Dps", global = "DAMAGE_METER_TYPE_DPS", label = "DPS" },
            { key = "DamageTaken", enum = "DamageTaken", global = "DAMAGE_METER_TYPE_DAMAGE_TAKEN", label = "Damage Taken" },
            { key = "AvoidableDamageTaken", enum = "AvoidableDamageTaken", global = "DAMAGE_METER_TYPE_AVOIDABLE_DAMAGE_TAKEN", label = "Avoidable Damage Taken" },
            { key = "EnemyDamageTaken", enum = "EnemyDamageTaken", global = "DAMAGE_METER_TYPE_ENEMY_DAMAGE_TAKEN", label = "Enemy Damage Taken" },
        },
    },
    {
        label = HEALING or "Healing",
        types = {
            { key = "HealingDone", enum = "HealingDone", global = "DAMAGE_METER_TYPE_HEALING_DONE", label = "Healing Done" },
            { key = "Hps", enum = "Hps", global = "DAMAGE_METER_TYPE_HPS", label = "HPS" },
            { key = "Absorbs", enum = "Absorbs", global = "DAMAGE_METER_TYPE_ABSORBS", label = "Absorbs" },
        },
    },
    {
        label = ACTIONS or "Actions",
        types = {
            { key = "Interrupts", enum = "Interrupts", global = "DAMAGE_METER_TYPE_INTERRUPTS", label = "Interrupts" },
            { key = "Dispels", enum = "Dispels", global = "DAMAGE_METER_TYPE_DISPELS", label = "Dispels" },
            { key = "Deaths", enum = "Deaths", global = "DAMAGE_METER_TYPE_DEATHS", label = "Deaths" },
        },
    },
}

local METER_TYPES = {}
for _, category in ipairs(METER_CATEGORIES) do
    for _, info in ipairs(category.types) do
        METER_TYPES[info.key] = info
    end
end

local meterFrames = {}
local eventFrame
local moveMode = false
local refreshPending = false
local lastRefresh = 0
local RefreshMeter
local ScheduleRefresh

local sampleSources = {
    { name = "Dottindrock", classFilename = "WARLOCK", totalAmount = 128400000, amountPerSecond = 2140000, isLocalPlayer = true },
    { name = "Party Member", classFilename = "PALADIN", totalAmount = 106800000, amountPerSecond = 1780000 },
    { name = "Party Member", classFilename = "SHAMAN", totalAmount = 94500000, amountPerSecond = 1575000 },
    { name = "Party Member", classFilename = "WARRIOR", totalAmount = 81300000, amountPerSecond = 1355000 },
    { name = "Party Member", classFilename = "DRUID", totalAmount = 69700000, amountPerSecond = 1162000 },
}

local sampleClasses = { "MAGE", "ROGUE", "HUNTER", "PRIEST", "DEMONHUNTER", "MONK", "EVOKER" }
for index = #sampleSources + 1, MAX_ROW_COUNT do
    sampleSources[index] = {
        name = "Preview Player " .. index,
        classFilename = sampleClasses[((index - 1) % #sampleClasses) + 1],
        totalAmount = math.max(1000000, 69700000 - ((index - 5) * 4300000)),
        amountPerSecond = math.max(25000, 1162000 - ((index - 5) * 72000)),
    }
end
for index, source in ipairs(sampleSources) do
    source.previewActionCount = math.max(1, 9 - index)
    source.deathTimeSeconds = 35 + (index * 14)
end

local function GetDB(windowIndex)
    if not ns.db then return nil end
    ns.db.customDamageMeter = ns.db.customDamageMeter or {}
    local root = ns.db.customDamageMeter
    if windowIndex == 2 then
        root.secondWindow = root.secondWindow or {}
        return root.secondWindow
    end
    return root
end

local function NormalizeSessionType(value)
    return value == "overall" and "overall" or "current"
end

local function GetSessionType(windowIndex)
    local db = GetDB(windowIndex)
    return NormalizeSessionType(db and db.sessionType)
end

local function GetSessionLabel(value)
    return NormalizeSessionType(value) == "overall" and "Overall" or "Current Segment"
end

local function NormalizeMeterType(value)
    return METER_TYPES[value] and value or "DamageDone"
end

local function GetMeterType(windowIndex)
    local db = GetDB(windowIndex)
    return NormalizeMeterType(db and db.damageMeterType)
end

local function GetMeterTypeInfo(value)
    return METER_TYPES[NormalizeMeterType(value)]
end

local function GetMeterLabel(value)
    local info = GetMeterTypeInfo(value)
    return (info.global and _G[info.global]) or info.label
end

local function GetMeterEnum(value)
    local info = GetMeterTypeInfo(value)
    return Enum and Enum.DamageMeterType and Enum.DamageMeterType[info.enum]
end

local function IsMeterTypeAvailable(info)
    return info and Enum and Enum.DamageMeterType and Enum.DamageMeterType[info.enum] ~= nil
end

local function GetTextScale()
    local db = GetDB()
    local value = tonumber(db and db.textScale) or 1
    return math.max(0.8, math.min(1.5, value))
end

local function GetBackgroundOpacity()
    local db = GetDB(1) or {}
    return math.max(0, math.min(1, tonumber(db.backgroundOpacity) or 0.94))
end

local function GetClassColoredBorder()
    local db = GetDB(1) or {}
    return db.classColoredBorder ~= false
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) == true
end

local function FormatNumber(value)
    if value == nil then return "0" end

    if IsSecret(value) then
        if AbbreviateNumbers then return AbbreviateNumbers(value) end
        if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(value) end
        return ""
    end

    local number = tonumber(value) or 0
    if number < 1000 then
        return tostring(math.floor(number + 0.5))
    end
    if AbbreviateNumbers then return AbbreviateNumbers(number) end
    if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(number) end
    if number >= 1000000000 then return string.format("%.1fB", number / 1000000000) end
    if number >= 1000000 then return string.format("%.1fM", number / 1000000) end
    return string.format("%.1fK", number / 1000)
end

local function FormatRowValue(source, windowIndex)
    local meterType = GetMeterType(windowIndex)
    if meterType == "Dps" or meterType == "Hps" then
        return FormatNumber(source.amountPerSecond)
    end
    if meterType == "Interrupts" or meterType == "Dispels" then
        return FormatNumber(moveMode and source.previewActionCount or source.totalAmount)
    end
    if meterType == "Deaths" then
        local deathTime = source.deathTimeSeconds
        if deathTime ~= nil then
            if IsSecret(deathTime) then return tostring(deathTime) end
            deathTime = tonumber(deathTime)
            if deathTime == -1 then return "" end
            if deathTime and deathTime >= 0 and SecondsToClock then return SecondsToClock(deathTime) end
        end
        return FormatNumber(source.totalAmount)
    end
    return FormatNumber(source.totalAmount) .. " (" .. FormatNumber(source.amountPerSecond) .. ")"
end

local function GetSourceBarValue(source, windowIndex)
    local meterType = GetMeterType(windowIndex)
    if moveMode and (meterType == "Interrupts" or meterType == "Dispels" or meterType == "Deaths") then
        return source and source.previewActionCount
    end
    if meterType == "Dps" or meterType == "Hps" then
        return source and source.amountPerSecond
    end
    return source and source.totalAmount
end

local function SetClassIcon(texture, source)
    local specIconID = source and source.specIconID
    if specIconID ~= nil and not IsSecret(specIconID) then
        texture:SetTexture(specIconID)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return
    end

    local classFilename = source and source.classFilename
    local coords = type(classFilename) == "string" and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFilename]
    if coords then
        texture:SetTexture(CLASS_ICON_TEXTURE)
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        return
    end

    texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function GetClassColor(classFilename)
    local color = type(classFilename) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename]
    if color then return color.r or 0.55, color.g or 0.55, color.b or 0.55 end
    return 0.30, 0.52, 0.72
end

local function GetPlayerClassColor()
    local _, classFilename = UnitClass("player")
    local color = classFilename and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename]
    if color then return color.r or 0.76, color.g or 0.55, color.b or 0.12 end
    return 0.76, 0.55, 0.12
end

local function ApplyFrameAppearance(frame)
    if not frame then return end
    local opacity = GetBackgroundOpacity()
    local r, g, b
    if GetClassColoredBorder() then
        r, g, b = GetPlayerClassColor()
    else
        r, g, b = 0.62, 0.46, 0.16
    end
    frame:SetBackdropColor(0.008, 0.010, 0.014, opacity)
    frame:SetBackdropBorderColor(r, g, b, moveMode and 1 or 0.90)
    if frame.headerBackground then frame.headerBackground:SetAlpha(opacity) end
    if frame.rows then
        for _, row in ipairs(frame.rows) do
            if row.background then
                row.background:SetColorTexture(0.018, 0.021, 0.027, math.min(0.92, opacity))
            end
        end
    end
end

local function GetDamageSession(windowIndex)
    if not C_DamageMeter or not C_DamageMeter.GetCombatSessionFromType then return nil end
    if not Enum or not Enum.DamageMeterSessionType or not Enum.DamageMeterType then return nil end

    local sessionType = GetSessionType(windowIndex) == "overall" and Enum.DamageMeterSessionType.Overall or Enum.DamageMeterSessionType.Current
    local meterType = GetMeterEnum(GetMeterType(windowIndex))
    if sessionType == nil or meterType == nil then return nil end

    return C_DamageMeter.GetCombatSessionFromType(sessionType, meterType)
end

local function IsDamageMeterAvailable()
    if not C_DamageMeter or not C_DamageMeter.GetCombatSessionFromType then return false end
    if C_DamageMeter.IsDamageMeterAvailable then
        return C_DamageMeter.IsDamageMeterAvailable() == true
    end
    return true
end

local function SavePosition(frame)
    local db = GetDB(frame.windowIndex)
    if not db then return end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    db.point = point or "BOTTOMRIGHT"
    db.relativePoint = relativePoint or db.point
    db.x = tonumber(x) or -18
    db.y = tonumber(y) or 210
end

local function SaveSize(frame)
    local db = GetDB(frame.windowIndex)
    if not db then return end
    db.width = math.max(MIN_WIDTH, math.min(MAX_WIDTH, tonumber(frame:GetWidth()) or DEFAULT_WIDTH))
    db.height = math.max(DEFAULT_HEIGHT, math.min(MAX_HEIGHT, tonumber(frame:GetHeight()) or DEFAULT_HEIGHT))
end

local function RestorePosition(frame)
    local db = GetDB(frame.windowIndex) or {}
    local defaultX = frame.windowIndex == 2 and -328 or -18
    frame:ClearAllPoints()
    frame:SetPoint(db.point or "BOTTOMRIGHT", UIParent, db.relativePoint or "BOTTOMRIGHT", tonumber(db.x) or defaultX, tonumber(db.y) or 210)
end

local function RestoreSize(frame)
    local db = GetDB(frame.windowIndex) or {}
    local width = math.max(MIN_WIDTH, math.min(MAX_WIDTH, tonumber(db.width) or DEFAULT_WIDTH))
    local height = math.max(DEFAULT_HEIGHT, math.min(MAX_HEIGHT, tonumber(db.height) or DEFAULT_HEIGHT))
    frame:SetSize(width, height)
end

local function GetVisibleRowCount(frame)
    local height = frame and frame:GetHeight()
    if not height then
        local db = GetDB(frame and frame.windowIndex) or {}
        height = tonumber(db.height) or DEFAULT_HEIGHT
    end
    local available = math.max(ROW_HEIGHT, height - 35)
    local count = math.floor((available + ROW_SPACING) / (ROW_HEIGHT + ROW_SPACING))
    return math.max(DEFAULT_ROW_COUNT, math.min(MAX_ROW_COUNT, count))
end

local function ShowTooltip(owner, title, description)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:SetText(title)
    if description then GameTooltip:AddLine(description, 0.82, 0.82, 0.82, true) end
    GameTooltip:Show()
end

local function CreateResetButton(frame, rightAnchor)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(18, 18)
    button:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0)
    button:RegisterForClicks("LeftButtonUp")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    if button.icon.SetAtlas then
        button.icon:SetAtlas("GM-raidMarker-reset")
    else
        button.icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    end

    button:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 0.82, 0.28)
        ShowTooltip(self, "Reset Meter Data", "Clears all Blizzard damage meter sessions.")
    end)
    button:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.86, 0.86, 0.86)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then
            ns:Print("Damage meter data cannot be reset during combat.")
            return
        end
        if not C_DamageMeter or not C_DamageMeter.ResetAllCombatSessions then
            ns:Print("Blizzard damage meter reset is not available.")
            return
        end
        if securecallfunction then
            securecallfunction(C_DamageMeter.ResetAllCombatSessions)
        else
            C_DamageMeter.ResetAllCombatSessions()
        end
    end)
    button.icon:SetVertexColor(0.86, 0.86, 0.86)
    return button
end

local function CreateSettingsButton(frame)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(18, 18)
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -6)
    button:RegisterForClicks("LeftButtonUp")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER")
    button.icon:SetSize(16, 16)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("common-icon-settingsgear") then
        button.icon:SetAtlas("common-icon-settingsgear")
    else
        button.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    end
    button.icon:SetVertexColor(0.62, 0.46, 0.16)

    button:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(0.86, 0.66, 0.24)
        ShowTooltip(self, "ZoidsTools Meter Settings", "Open ZoidsTools directly to the Meters page.")
    end)
    button:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.62, 0.46, 0.16)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function()
        if ns.OpenConfig then ns:OpenConfig("meters") end
    end)

    return button
end

local function UpdateSessionButton(frame)
    if not frame or not frame.sessionButton then return end
    local overall = GetSessionType(frame.windowIndex) == "overall"
    frame.sessionButton.text:SetText(overall and "O" or "C")
    frame.sessionButton.text:SetTextColor(0.96, 0.76, 0.22)
end

local function CreateSessionButton(frame, resetButton)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(18, 18)
    button:SetPoint("RIGHT", resetButton, "LEFT", -7, 0)
    button:RegisterForClicks("LeftButtonUp")

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetAllPoints()
    button.text:SetJustifyH("CENTER")
    button.text:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    button.text:SetShadowColor(0, 0, 0, 1)
    button.text:SetShadowOffset(1, -1)

    local function RefreshTooltip(self)
        ShowTooltip(self, "Session: " .. GetSessionLabel(GetSessionType(frame.windowIndex)), "Click to switch between Current Segment and Overall data.")
    end

    button:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1, 0.92, 0.52)
        RefreshTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        UpdateSessionButton(frame)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function()
        local nextType = GetSessionType(frame.windowIndex) == "overall" and "current" or "overall"
        if ns.SetCustomDamageMeterSessionType then
            ns:SetCustomDamageMeterSessionType(nextType, frame.windowIndex)
        end
        if button:IsMouseOver() then RefreshTooltip(button) end
    end)

    return button
end

local function UpdateMeterTitle(frame)
    if not frame or not frame.title then return end
    local label = GetMeterLabel(GetMeterType(frame.windowIndex))
    frame.title:SetText(moveMode and (label .. "  •  Preview") or label)
    if frame.titleButton then
        local textWidth = frame.title:GetStringWidth() or 0
        local availableWidth = math.max(40, (frame:GetWidth() or DEFAULT_WIDTH) - 85)
        frame.titleButton:SetWidth(math.min(availableWidth, math.ceil(textWidth + 10)))
    end
end

local function OpenMeterTypeMenu(owner)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        ns:Print("The damage meter type menu is not available.")
        return
    end

    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        for _, category in ipairs(METER_CATEGORIES) do
            local categoryMenu = rootDescription:CreateButton(category.label)
            for _, info in ipairs(category.types) do
                if IsMeterTypeAvailable(info) then
                    categoryMenu:CreateRadio(
                        GetMeterLabel(info.key),
                        function(value) return GetMeterType(owner.windowIndex) == value end,
                        function(value) ns:SetCustomDamageMeterType(value, owner.windowIndex) end,
                        info.key
                    )
                end
            end
        end
    end)
end

local function CreateMeterTitleButton(frame)
    local button = CreateFrame("Button", nil, frame)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -3)
    button:SetWidth(110)
    button:SetHeight(22)
    button.windowIndex = frame.windowIndex
    button:RegisterForClicks("LeftButtonUp")

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints()
    button.highlight:SetColorTexture(0.72, 0.53, 0.12, 0.12)

    button.title = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.title:SetPoint("LEFT", button, "LEFT", 5, 0)
    button.title:SetPoint("RIGHT", button, "RIGHT", -3, 0)
    button.title:SetJustifyH("LEFT")
    button.title:SetWordWrap(false)

    button:SetScript("OnClick", function(self)
        OpenMeterTypeMenu(self)
    end)
    button:SetScript("OnEnter", function(self)
        ShowTooltip(self, "Change Meter", "Choose a Damage, Healing, or Actions view.")
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return button
end

local function ApplyRowTextScale(row)
    if not row then return end
    local scale = GetTextScale()
    local baseSize = (tonumber(row.baseFontSize) or 10) * 1.2
    local size = math.max(8, math.floor((baseSize * scale) + 0.5))
    local fontPath = row.fontPath or "Fonts\\FRIZQT__.TTF"
    local fontFlags = row.fontFlags or ""

    row.rank:SetFont(fontPath, size, fontFlags)
    row.name:SetFont(fontPath, size, fontFlags)
    row.value:SetFont(fontPath, size, fontFlags)
end

local function CreateRow(frame, index)
    local row = CreateFrame("Frame", nil, frame)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -30 - ((index - 1) * (ROW_HEIGHT + ROW_SPACING)))
    row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -30 - ((index - 1) * (ROW_HEIGHT + ROW_SPACING)))
    row:SetHeight(ROW_HEIGHT)

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetColorTexture(0.018, 0.021, 0.027, math.min(0.92, GetBackgroundOpacity()))

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetAllPoints()
    row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)

    row.barShade = row.bar:CreateTexture(nil, "ARTWORK")
    row.barShade:SetAllPoints()
    row.barShade:SetColorTexture(0, 0, 0, 0.28)

    row.content = CreateFrame("Frame", nil, row)
    row.content:SetAllPoints()
    row.content:SetFrameLevel(row.bar:GetFrameLevel() + 3)
    row.content:EnableMouse(false)

    row.icon = row.content:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2)
    row.icon:SetPoint("LEFT", row.content, "LEFT", 1, 0)

    row.rank = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.rank:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.rank:SetWidth(14)
    row.rank:SetJustifyH("RIGHT")
    row.rank:SetTextColor(1, 0.82, 0.30)
    row.rank:SetShadowColor(0, 0, 0, 1)
    row.rank:SetShadowOffset(1, -1)

    row.name = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.rank, "RIGHT", 5, 0)
    row.name:SetPoint("RIGHT", row.content, "RIGHT", -108, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetTextColor(1, 1, 1)
    row.name:SetShadowColor(0, 0, 0, 1)
    row.name:SetShadowOffset(1, -1)
    if row.name.SetMaxLines then row.name:SetMaxLines(1) end

    row.value = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("RIGHT", row.content, "RIGHT", -5, 0)
    row.value:SetWidth(98)
    row.value:SetJustifyH("RIGHT")
    row.value:SetTextColor(1, 1, 1)
    row.value:SetShadowColor(0, 0, 0, 1)
    row.value:SetShadowOffset(1, -1)

    row.fontPath, row.baseFontSize, row.fontFlags = row.name:GetFont()
    ApplyRowTextScale(row)

    frame.rows[index] = row
    return row
end

local function EnsureRows(frame, count)
    for index = #frame.rows + 1, count do
        CreateRow(frame, index)
    end
end

local function CreateResizeHandle(frame)
    local handle = CreateFrame("Button", nil, frame)
    handle:SetSize(18, 18)
    handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    handle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    handle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    handle:Hide()

    local normal = handle:GetNormalTexture()
    if normal then normal:SetVertexColor(0.62, 0.46, 0.16) end
    local highlight = handle:GetHighlightTexture()
    if highlight then highlight:SetVertexColor(0.86, 0.66, 0.24) end
    local pushed = handle:GetPushedTexture()
    if pushed then pushed:SetVertexColor(0.86, 0.66, 0.24) end

    handle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and moveMode then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    handle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SaveSize(frame)
        SavePosition(frame)
        if ScheduleRefresh then ScheduleRefresh(true) end
    end)
    handle:SetScript("OnEnter", function(self)
        ShowTooltip(self, "Resize Damage Meter", "Drag to change the width and the number of visible player rows.")
    end)
    handle:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return handle
end

local function GetSnapGap()
    local db = GetDB(1) or {}
    return math.max(0, math.min(MAX_SNAP_GAP, tonumber(db.snapGap) or 0))
end

local function ApplySecondWindowSnap()
    local primary = meterFrames[1]
    local secondary = meterFrames[2]
    local secondDB = GetDB(2) or {}
    local side = secondDB.snapSide
    if not primary or not secondary or not side then return false end

    local gap = GetSnapGap()
    local sizeChanged = false
    if side == "LEFT" or side == "RIGHT" then
        local targetHeight = primary:GetHeight()
        if targetHeight and math.abs((secondary:GetHeight() or 0) - targetHeight) > 0.5 then
            secondary:SetHeight(targetHeight)
            sizeChanged = true
        end
    elseif side == "TOP" or side == "BOTTOM" then
        local targetWidth = primary:GetWidth()
        if targetWidth and math.abs((secondary:GetWidth() or 0) - targetWidth) > 0.5 then
            secondary:SetWidth(targetWidth)
            sizeChanged = true
        end
    end
    if sizeChanged then SaveSize(secondary) end

    secondary:ClearAllPoints()
    if side == "LEFT" then
        secondary:SetPoint("TOPRIGHT", primary, "TOPLEFT", -gap, 0)
    elseif side == "RIGHT" then
        secondary:SetPoint("TOPLEFT", primary, "TOPRIGHT", gap, 0)
    elseif side == "TOP" then
        secondary:SetPoint("BOTTOMLEFT", primary, "TOPLEFT", 0, gap)
    elseif side == "BOTTOM" then
        secondary:SetPoint("TOPLEFT", primary, "BOTTOMLEFT", 0, -gap)
    else
        secondDB.snapSide = nil
        return false
    end
    return true
end

local function DetachSecondWindow()
    local secondary = meterFrames[2]
    local secondDB = GetDB(2)
    if not secondary or not secondDB or not secondDB.snapSide then return end

    local left = secondary:GetLeft()
    local bottom = secondary:GetBottom()
    secondDB.snapSide = nil
    if left and bottom then
        secondary:ClearAllPoints()
        secondary:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        SavePosition(secondary)
    end
end

local function TrySnapWindows(movedFrame)
    local primary = meterFrames[1]
    local secondary = meterFrames[2]
    local secondDB = GetDB(2) or {}
    if not primary or not secondary or secondDB.enabled ~= true then return false end

    local pLeft, pRight, pTop, pBottom = primary:GetLeft(), primary:GetRight(), primary:GetTop(), primary:GetBottom()
    local sLeft, sRight, sTop, sBottom = secondary:GetLeft(), secondary:GetRight(), secondary:GetTop(), secondary:GetBottom()
    if not pLeft or not pRight or not pTop or not pBottom or not sLeft or not sRight or not sTop or not sBottom then return false end

    local gap = GetSnapGap()
    local verticalNear = math.min(pTop, sTop) - math.max(pBottom, sBottom) >= -SNAP_THRESHOLD
    local horizontalNear = math.min(pRight, sRight) - math.max(pLeft, sLeft) >= -SNAP_THRESHOLD
    local bestSide
    local bestDistance = SNAP_THRESHOLD + 1

    local function Consider(side, distance, eligible)
        if eligible and distance < bestDistance then
            bestSide = side
            bestDistance = distance
        end
    end

    Consider("LEFT", math.abs((pLeft - sRight) - gap), verticalNear)
    Consider("RIGHT", math.abs((sLeft - pRight) - gap), verticalNear)
    Consider("TOP", math.abs((sBottom - pTop) - gap), horizontalNear)
    Consider("BOTTOM", math.abs((pBottom - sTop) - gap), horizontalNear)

    if bestSide and bestDistance <= SNAP_THRESHOLD then
        if movedFrame and movedFrame.windowIndex == 1 then
            if bestSide == "LEFT" or bestSide == "RIGHT" then
                primary:SetHeight(secondary:GetHeight())
            else
                primary:SetWidth(secondary:GetWidth())
            end
            SaveSize(primary)
        end
        secondDB.snapSide = bestSide
        return ApplySecondWindowSnap()
    end
    return false
end

local function CreateMeterFrame(windowIndex)
    windowIndex = windowIndex == 2 and 2 or 1
    if meterFrames[windowIndex] then return meterFrames[windowIndex] end

    local frameName = windowIndex == 1 and FRAME_NAME or (FRAME_NAME .. "2")
    local frame = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    frame.windowIndex = windowIndex
    RestoreSize(frame)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_WIDTH, DEFAULT_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    else
        if frame.SetMinResize then frame:SetMinResize(MIN_WIDTH, DEFAULT_HEIGHT) end
        if frame.SetMaxResize then frame:SetMaxResize(MAX_WIDTH, MAX_HEIGHT) end
    end
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.008, 0.010, 0.014, 0.94)
    frame:SetBackdropBorderColor(0.26, 0.28, 0.32, 0.94)

    frame.headerBackground = frame:CreateTexture(nil, "BACKGROUND")
    frame.headerBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.headerBackground:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.headerBackground:SetHeight(27)
    if frame.headerBackground.SetAtlas then
        frame.headerBackground:SetAtlas("ui-damagemeters-header-bar")
    else
        frame.headerBackground:SetColorTexture(0.10, 0.10, 0.11, 0.96)
    end

    frame.titleButton = CreateMeterTitleButton(frame)
    frame.title = frame.titleButton.title
    UpdateMeterTitle(frame)

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("CENTER", frame, "CENTER", 0, -8)
    frame.empty:SetText("No current combat data")

    frame.moveHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.moveHint:SetPoint("BOTTOM", frame, "TOP", 0, 5)
    frame.moveHint:SetText("Drag to move • resize from the bottom-right corner • lock when finished")
    frame.moveHint:SetTextColor(1, 0.78, 0.22)
    frame.moveHint:Hide()

    frame.rows = {}
    EnsureRows(frame, GetVisibleRowCount(frame))
    ApplyFrameAppearance(frame)

    frame.settingsButton = CreateSettingsButton(frame)
    frame.resetButton = CreateResetButton(frame, frame.settingsButton)
    frame.sessionButton = CreateSessionButton(frame, frame.resetButton)
    frame.resizeHandle = CreateResizeHandle(frame)
    UpdateSessionButton(frame)
    frame:SetScript("OnDragStart", function(self)
        if moveMode then
            if self.windowIndex == 2 then DetachSecondWindow() end
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
        TrySnapWindows(self)
    end)

    frame:SetScript("OnSizeChanged", function(self)
        local secondDB = GetDB(2) or {}
        if secondDB.snapSide and meterFrames[2] then
            ApplySecondWindowSnap()
        end
        UpdateMeterTitle(self)
        if moveMode and ScheduleRefresh then ScheduleRefresh(false) end
    end)

    RestorePosition(frame)
    frame:Hide()
    meterFrames[windowIndex] = frame
    return frame
end

local function InitializeSecondWindowLayout()
    local secondDB = GetDB(2)
    if not secondDB or secondDB.layoutInitialized == true then return end

    local primary = CreateMeterFrame(1)
    local primaryDB = GetDB(1) or {}
    local width = primary:GetWidth() or DEFAULT_WIDTH
    local height = primary:GetHeight() or DEFAULT_HEIGHT
    local point = primaryDB.point or "BOTTOMRIGHT"
    local x = tonumber(primaryDB.x) or -18

    secondDB.width = width
    secondDB.height = height
    secondDB.point = point
    secondDB.relativePoint = primaryDB.relativePoint or point
    secondDB.y = tonumber(primaryDB.y) or 210
    if point:find("RIGHT", 1, true) then
        secondDB.x = x - width - 10
    else
        secondDB.x = x + width + 10
    end
    secondDB.snapSide = "LEFT"
    secondDB.layoutInitialized = true
end

local function UpdateInteractionState()
    for windowIndex = 1, 2 do
        local db = GetDB(windowIndex) or {}
        if windowIndex == 1 or db.enabled == true or meterFrames[windowIndex] then
            local frame = CreateMeterFrame(windowIndex)
            frame.moveHint:SetShown(moveMode and (windowIndex == 1 or db.enabled == true))
            frame.resizeHandle:SetShown(moveMode and (windowIndex == 1 or db.enabled == true))
            frame:SetResizable(moveMode and (windowIndex == 1 or db.enabled == true))
            ApplyFrameAppearance(frame)
            UpdateMeterTitle(frame)
        end
    end
end

local function UpdateRow(frame, row, source, index, maxAmount)
    if not source then
        row:Hide()
        return
    end

    local amount = GetSourceBarValue(source, frame.windowIndex)
    if amount == nil then amount = 0 end
    if maxAmount == nil then maxAmount = 1 end

    local r, g, b = GetClassColor(source.classFilename)
    row.bar:SetStatusBarColor(r, g, b, source.isLocalPlayer == true and 0.92 or 0.76)
    row.bar:SetMinMaxValues(0, maxAmount)
    row.bar:SetValue(amount)
    SetClassIcon(row.icon, source)
    row.rank:SetText(index)
    row.name:SetText(source.name or UNKNOWN or "Unknown")
    row.value:SetText(FormatRowValue(source, frame.windowIndex))
    row:Show()
end

local function RefreshMeterWindow(windowIndex)
    local rootDB = GetDB(1) or {}
    local db = GetDB(windowIndex) or {}
    local enabled = rootDB.enabled == true and (windowIndex == 1 or db.enabled == true)
    local preview = moveMode and (windowIndex == 1 or db.enabled == true)
    if not enabled and not preview then
        if meterFrames[windowIndex] then meterFrames[windowIndex]:Hide() end
        return
    end

    local frame = CreateMeterFrame(windowIndex)

    UpdateSessionButton(frame)
    UpdateMeterTitle(frame)
    frame.empty:SetText((GetSessionType(windowIndex) == "overall" and "No overall " or "No current ") .. GetMeterLabel(GetMeterType(windowIndex)) .. " data")

    local sources
    local maxAmount
    if preview then
        sources = sampleSources
        maxAmount = GetSourceBarValue(sampleSources[1], windowIndex)
    elseif IsDamageMeterAvailable() then
        local session = GetDamageSession(windowIndex)
        sources = session and type(session.combatSources) == "table" and session.combatSources or nil
        maxAmount = session and session.maxAmount or nil
    end
    if maxAmount == nil and sources and sources[1] then
        maxAmount = GetSourceBarValue(sources[1], windowIndex)
    end

    local rowCount = GetVisibleRowCount(frame)
    EnsureRows(frame, rowCount)
    local shown = 0
    for index = 1, rowCount do
        local source = sources and sources[index]
        UpdateRow(frame, frame.rows[index], source, index, maxAmount)
        if source then shown = shown + 1 end
    end
    for index = rowCount + 1, #frame.rows do
        frame.rows[index]:Hide()
    end

    frame.empty:SetShown(shown == 0)
    frame:Show()
end


RefreshMeter = function()
    RefreshMeterWindow(1)
    local secondDB = GetDB(2) or {}
    if secondDB.enabled == true or meterFrames[2] then
        RefreshMeterWindow(2)
    end
end

if ns.WrapDiagnosticFunction then
    RefreshMeter = ns:WrapDiagnosticFunction("CustomDamageMeter.Refresh", RefreshMeter)
end

ScheduleRefresh = function(immediate)
    if immediate then
        refreshPending = false
        lastRefresh = GetTime and GetTime() or 0
        RefreshMeter()
        return
    end

    local now = GetTime and GetTime() or 0
    local remaining = REFRESH_INTERVAL - (now - lastRefresh)
    if remaining <= 0 then
        lastRefresh = now
        RefreshMeter()
        return
    end
    if refreshPending then return end

    refreshPending = true
    C_Timer.After(math.max(0.01, remaining), function()
        refreshPending = false
        lastRefresh = GetTime and GetTime() or 0
        RefreshMeter()
    end)
end

local function UpdateEventRegistration()
    if not eventFrame then return end
    eventFrame:UnregisterAllEvents()

    local db = GetDB()
    if not db or db.enabled ~= true then return end

    eventFrame:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
    eventFrame:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
    eventFrame:RegisterEvent("DAMAGE_METER_RESET")
    eventFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function ns:GetCustomDamageMeterEnabled()
    local db = GetDB()
    return db and db.enabled == true
end

function ns:SetCustomDamageMeterEnabled(value)
    local db = GetDB()
    if not db then return end
    db.enabled = value == true
    UpdateEventRegistration()
    ScheduleRefresh(true)
end

function ns:GetCustomDamageMeterSecondWindowEnabled()
    local db = GetDB(2)
    return db and db.enabled == true
end

function ns:SetCustomDamageMeterSecondWindowEnabled(value)
    local db = GetDB(2)
    if not db then return end
    if value == true then InitializeSecondWindowLayout() end
    db.enabled = value == true
    if db.enabled then
        CreateMeterFrame(2)
        ApplySecondWindowSnap()
    end
    UpdateInteractionState()
    ScheduleRefresh(true)
end

function ns:GetCustomDamageMeterSessionType(windowIndex)
    return GetSessionType(windowIndex)
end

function ns:SetCustomDamageMeterSessionType(value, windowIndex)
    windowIndex = windowIndex == 2 and 2 or 1
    local db = GetDB(windowIndex)
    if not db then return end
    db.sessionType = NormalizeSessionType(value)
    if meterFrames[windowIndex] then UpdateSessionButton(meterFrames[windowIndex]) end
    ScheduleRefresh(true)
end

function ns:GetCustomDamageMeterType(windowIndex)
    return GetMeterType(windowIndex)
end

function ns:SetCustomDamageMeterType(value, windowIndex)
    windowIndex = windowIndex == 2 and 2 or 1
    local normalized = NormalizeMeterType(value)
    local info = GetMeterTypeInfo(normalized)
    if not IsMeterTypeAvailable(info) then return end

    local db = GetDB(windowIndex)
    if not db then return end
    db.damageMeterType = normalized
    if meterFrames[windowIndex] then UpdateMeterTitle(meterFrames[windowIndex]) end
    ScheduleRefresh(true)
end

function ns:GetCustomDamageMeterTextScale()
    return GetTextScale()
end

function ns:GetCustomDamageMeterSnapGap()
    return GetSnapGap()
end

function ns:SetCustomDamageMeterSnapGap(value)
    local db = GetDB(1)
    if not db then return end
    db.snapGap = math.max(0, math.min(MAX_SNAP_GAP, tonumber(value) or 0))
    ApplySecondWindowSnap()
end

function ns:GetCustomDamageMeterBackgroundOpacity()
    return GetBackgroundOpacity()
end

function ns:SetCustomDamageMeterBackgroundOpacity(value)
    local db = GetDB(1)
    if not db then return end
    db.backgroundOpacity = math.max(0, math.min(1, tonumber(value) or 0.94))
    for _, frame in pairs(meterFrames) do
        ApplyFrameAppearance(frame)
    end
end

function ns:GetCustomDamageMeterClassColoredBorder()
    return GetClassColoredBorder()
end

function ns:SetCustomDamageMeterClassColoredBorder(value)
    local db = GetDB(1)
    if not db then return end
    db.classColoredBorder = value == true
    for _, frame in pairs(meterFrames) do
        ApplyFrameAppearance(frame)
    end
end

function ns:SetCustomDamageMeterTextScale(value)
    local db = GetDB()
    if not db then return end
    db.textScale = math.max(0.8, math.min(1.5, tonumber(value) or 1))
    for _, frame in pairs(meterFrames) do
        if frame.rows then
            for _, row in ipairs(frame.rows) do
                ApplyRowTextScale(row)
            end
        end
    end
    ScheduleRefresh(true)
end

function ns:IsCustomDamageMeterMoveMode()
    return moveMode
end

function ns:ToggleCustomDamageMeterMoveMode()
    moveMode = not moveMode
    UpdateInteractionState()
    ScheduleRefresh(true)
    return moveMode
end

function ns:ResetCustomDamageMeterPosition()
    local primaryDB = GetDB(1)
    if not primaryDB then return end
    primaryDB.point = "BOTTOMRIGHT"
    primaryDB.relativePoint = "BOTTOMRIGHT"
    primaryDB.x = -18
    primaryDB.y = 210
    RestorePosition(CreateMeterFrame(1))

    local secondDB = GetDB(2)
    if secondDB and (secondDB.enabled == true or meterFrames[2]) then
        secondDB.point = "BOTTOMRIGHT"
        secondDB.relativePoint = "BOTTOMRIGHT"
        secondDB.x = -18 - (tonumber(secondDB.width) or DEFAULT_WIDTH) - 10
        secondDB.y = 210
        RestorePosition(CreateMeterFrame(2))
        ApplySecondWindowSnap()
    end
end

function ns:GetCustomDamageMeterStatusText()
    local db = GetDB()
    if not db or db.enabled ~= true then
        return "Disabled. Preview and position it before enabling if desired."
    end
    if not IsDamageMeterAvailable() then
        return "Enabled, but Blizzard damage meter data is not currently available."
    end
    local summary = "Window 1: " .. GetSessionLabel(GetSessionType(1)) .. " " .. GetMeterLabel(GetMeterType(1)) .. " • " .. GetVisibleRowCount(meterFrames[1]) .. " rows"
    local secondDB = GetDB(2) or {}
    if secondDB.enabled == true then
        summary = summary .. "\nWindow 2: " .. GetSessionLabel(GetSessionType(2)) .. " " .. GetMeterLabel(GetMeterType(2)) .. " • " .. GetVisibleRowCount(meterFrames[2]) .. " rows"
    end
    return summary .. " • 0.15-second refresh limit."
end

function ns:InitializeCustomDamageMeter()
    if eventFrame then return end
    CreateMeterFrame(1)
    local secondDB = GetDB(2) or {}
    if secondDB.enabled == true then
        InitializeSecondWindowLayout()
        CreateMeterFrame(2)
        ApplySecondWindowSnap()
    end
    UpdateInteractionState()

    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(_, event)
        ScheduleRefresh(event == "DAMAGE_METER_RESET" or event == "PLAYER_ENTERING_WORLD")
    end)

    UpdateEventRegistration()
    ScheduleRefresh(true)
end
