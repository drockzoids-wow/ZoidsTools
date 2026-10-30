local _, ns = ...

local eventFrame
local showHooksInstalled = false
local pendingRefresh = false
local pendingCombatRefresh = false
local sourceDropdown
local statPanel
local statToggleButton

local STAT_ORDER = { "crit", "haste", "mastery", "versatility" }
local PRIORITY_STAT_LABELS = {
    crit = "Crit",
    haste = "Haste",
    mastery = "Mastery",
    versatility = "Vers",
}
local SOURCE_OPTIONS = {
    { value = "mythicplus", text = "M+" },
    { value = "raid", text = "Raid" },
    { value = "pvp", text = "PvP" },
}

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function RegisterUnitEventSafe(frame, event, ...)
    if frame and type(frame.RegisterUnitEvent) == "function" then
        local ok, registered = pcall(frame.RegisterUnitEvent, frame, event, ...)

        if ok and registered ~= false then
            return
        end
    end

    frame:RegisterEvent(event)
end

local function RegisterStatUnitEvents()
    if not eventFrame then
        return
    end

    RegisterUnitEventSafe(eventFrame, "UNIT_STATS", "player")
    RegisterUnitEventSafe(eventFrame, "UNIT_AURA", "player")
end

local function UnregisterStatUnitEvents()
    if not eventFrame or type(eventFrame.UnregisterEvent) ~= "function" then
        return
    end

    eventFrame:UnregisterEvent("UNIT_STATS")
    eventFrame:UnregisterEvent("UNIT_AURA")
end

local SPEC_KEYS = {
    DEATHKNIGHT = { "blood", "frost", "unholy" },
    DEMONHUNTER = { "havoc", "vengeance", "devourer" },
    DRUID = { "balance", "feral", "guardian", "restoration" },
    EVOKER = { "devastation", "preservation", "augmentation" },
    HUNTER = { "beast-mastery", "marksmanship", "survival" },
    MAGE = { "arcane", "fire", "frost" },
    MONK = { "brewmaster", "mistweaver", "windwalker" },
    PALADIN = { "holy", "protection", "retribution" },
    PRIEST = { "discipline", "holy", "shadow" },
    ROGUE = { "assassination", "outlaw", "subtlety" },
    SHAMAN = { "elemental", "enhancement", "restoration" },
    WARLOCK = { "affliction", "demonology", "destruction" },
    WARRIOR = { "arms", "fury", "protection" },
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

local function SafeNumber(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    if value == nil then
        return nil
    end

    local ok, number = pcall(function()
        local converted = tonumber(value)

        if converted == nil then
            return nil
        end

        return converted + 0
    end)

    if ok and type(number) == "number" then
        return number
    end

    return nil
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.items = ns.db.items or {}
    ns.db.items.character = ns.db.items.character or {}

    if ns.db.items.character.statTargets == nil then
        ns.db.items.character.statTargets = true
    end

    if ns.db.items.statTargetContext == nil then
        ns.db.items.statTargetContext = "mythicplus"
    end

    if ns.db.items.statGoalsPanelShown == nil then
        ns.db.items.statGoalsPanelShown = true
    end

    return ns.db.items
end

local function IsEnabled()
    local db = EnsureDB()
    return db
        and db.enabled == true
        and db.character
        and db.character.statTargets == true
end

local function GetContextLabel()
    local db = EnsureDB()
    local context = db and db.statTargetContext or "mythicplus"

    if context == "pvp" then
        return "PvP"
    end

    if context == "raid" then
        return "Raid"
    end

    return "Mythic+"
end

local function GetContextButtonText()
    local db = EnsureDB()
    local context = db and db.statTargetContext or "mythicplus"

    for _, option in ipairs(SOURCE_OPTIONS) do
        if option.value == context then
            return option.text
        end
    end

    return "M+"
end

local function NormalizeSpecName(value)
    value = string.lower(tostring(value or ""))
    value = value:gsub("&", "and")
    value = value:gsub("[^%w]+", "-")
    value = value:gsub("^%-+", "")
    value = value:gsub("%-+$", "")
    return value
end

local function GetClassAndSpec()
    local _, classToken = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    local specKey = classToken and specIndex and SPEC_KEYS[classToken] and SPEC_KEYS[classToken][specIndex]
    local root = ns.StatGoalsData and ns.StatGoalsData.data

    if classToken and specIndex and GetSpecializationInfo and root and root[classToken] then
        local _, specName = GetSpecializationInfo(specIndex)
        local nameKey = NormalizeSpecName(specName)

        if root[classToken][nameKey] then
            specKey = nameKey
        end
    end

    return classToken, specKey
end

local function GetSnapshot()
    local classToken, specKey = GetClassAndSpec()

    if not classToken or not specKey then
        return nil
    end

    local context = GetContextLabel()
    local roots = {
        ns.StatGoalsData and ns.StatGoalsData.data,
    }

    for _, root in ipairs(roots) do
        local snapshot = root
            and root[classToken]
            and root[classToken][specKey]
            and root[classToken][specKey][context]

        if snapshot and type(snapshot.targets) == "table" then
            return snapshot, classToken, specKey, context
        end
    end

    return nil, classToken, specKey, context
end

local function FormatStatPriority(snapshot)
    if not snapshot or type(snapshot.priority) ~= "table" then
        return "Priority: --"
    end

    local labels = {}
    local seen = {}

    for _, statKey in ipairs(snapshot.priority) do
        local label = PRIORITY_STAT_LABELS[statKey]

        if label and not seen[statKey] then
            seen[statKey] = true
            labels[#labels + 1] = label
        end
    end

    if #labels == 0 then
        return "Priority: --"
    end

    return "Priority: " .. table.concat(labels, " > ")
end

local function GetRating(statKey)
    if statKey == "crit" then
        return SafeNumber(SafeCall(GetCombatRating, CR_CRIT_MELEE))
    elseif statKey == "haste" then
        return SafeNumber(SafeCall(GetCombatRating, CR_HASTE_MELEE))
    elseif statKey == "mastery" then
        return SafeNumber(SafeCall(GetCombatRating, CR_MASTERY))
    elseif statKey == "versatility" then
        return SafeNumber(SafeCall(GetCombatRating, CR_VERSATILITY_DAMAGE_DONE))
    end

    return nil
end

local function GetPercent(statKey)
    if statKey == "crit" then
        return SafeNumber(SafeCall(GetCritChance)) or 0
    elseif statKey == "haste" then
        return SafeNumber(SafeCall(GetHaste)) or 0
    elseif statKey == "mastery" then
        return SafeNumber(SafeCall(GetMasteryEffect)) or 0
    elseif statKey == "versatility" then
        return SafeNumber(SafeCall(GetCombatRatingBonus, CR_VERSATILITY_DAMAGE_DONE)) or 0
    end

    return 0
end

local function FormatDefaultPercent(statKey)
    local value = GetPercent(statKey)

    if value <= 0 then
        return nil
    end

    if math.abs(value - math.floor(value + 0.5)) < 0.05 then
        return string.format("%d%%", math.floor(value + 0.5))
    end

    return string.format("%.1f%%", value)
end

local function FormatRating(value)
    value = math.floor((value or 0) + 0.5)

    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(value)
    end

    return tostring(value)
end

local function RoundRating(value)
    return math.floor((value or 0) + 0.5)
end

local function FormatDelta(current, target)
    local diff = RoundRating(current) - RoundRating(target)
    local color = diff >= 0 and "ff40ff60" or "ffff5050"

    if diff == 0 then
        return string.format("|c%s+0|r", color), diff
    end

    local sign = diff > 0 and "+" or "-"
    return string.format("|c%s%s%d|r", color, sign, math.abs(diff)), diff
end

local function PositionStatPanel(panel)
    local characterFrame = _G.CharacterFrame

    if not panel or not characterFrame then
        return
    end

    panel:ClearAllPoints()

    local frameRight = characterFrame.GetRight and characterFrame:GetRight()
    local screenRight = UIParent and UIParent.GetRight and UIParent:GetRight()

    if frameRight and screenRight and (screenRight - frameRight) >= 282 then
        panel:SetPoint("BOTTOMLEFT", characterFrame, "BOTTOMRIGHT", 6, 0)
    else
        panel:SetPoint("BOTTOMRIGHT", characterFrame, "BOTTOMLEFT", -6, 0)
    end
end

local function RefreshStatToggleButton()
    if not statToggleButton then return end

    local db = EnsureDB()
    local shown = db and db.statGoalsPanelShown == true
    statToggleButton:SetBackdropColor(shown and 0.14 or 0.035, shown and 0.10 or 0.038, shown and 0.035 or 0.045, 0.97)
    statToggleButton:SetBackdropBorderColor(shown and 0.92 or 0.35, shown and 0.68 or 0.38, shown and 0.20 or 0.42, shown and 0.86 or 0.72)
    statToggleButton.text:SetTextColor(shown and 1 or 0.72, shown and 0.82 or 0.74, shown and 0.24 or 0.78)
end

local function EnsureStatToggleButton()
    if statToggleButton then
        RefreshStatToggleButton()
        return statToggleButton
    end

    local characterFrame = _G.CharacterFrame

    if not characterFrame then
        return nil
    end

    local button = CreateFrame("Button", "ZoidsToolsStatGoalsToggle", characterFrame, "BackdropTemplate")
    button:SetSize(50, 22)
    button:SetPoint("BOTTOMRIGHT", characterFrame, "BOTTOMRIGHT", -10, 10)
    button:RegisterForClicks("LeftButtonUp")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("CENTER")
    button.text:SetText("Goals")

    button:SetScript("OnClick", function()
        local db = EnsureDB()
        if not db then return end
        db.statGoalsPanelShown = not (db.statGoalsPanelShown == true)
        RefreshStatToggleButton()

        if ns.RefreshStatTargets then
            ns:RefreshStatTargets()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Stat Goals")
        GameTooltip:AddLine("Show or hide the ZoidsTools stat-goal panel.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    statToggleButton = button
    RefreshStatToggleButton()
    return button
end

local function EnsureStatPanel()
    if statPanel then
        PositionStatPanel(statPanel)
        return statPanel
    end

    local characterFrame = _G.CharacterFrame

    if not characterFrame then
        return nil
    end

    -- Inherit the Character window's strata and stacking order so the entire
    -- panel, including its controls, stays behind windows covering Character.
    local panel = CreateFrame("Frame", "ZoidsToolsStatGoalsPanel", characterFrame, "BackdropTemplate")
    panel:SetSize(276, 190)
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.018, 0.021, 0.028, 0.97)
    panel:SetBackdropBorderColor(0.65, 0.50, 0.20, 0.78)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", 12, -11)
    panel.title:SetText("Stat Goals")
    panel.title:SetTextColor(1, 0.82, 0.20)

    panel.priority = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.priority:SetPoint("TOPLEFT", 12, -31)
    panel.priority:SetPoint("TOPRIGHT", -12, -31)
    panel.priority:SetJustifyH("LEFT")
    panel.priority:SetWordWrap(false)
    panel.priority:SetText("Priority: --")
    panel.priority:SetTextColor(0.72, 0.74, 0.78)

    panel.divider = panel:CreateTexture(nil, "ARTWORK")
    panel.divider:SetPoint("TOPLEFT", 10, -54)
    panel.divider:SetPoint("TOPRIGHT", -10, -54)
    panel.divider:SetHeight(1)
    panel.divider:SetColorTexture(0.50, 0.42, 0.26, 0.40)

    local headers = {
        { text = "Stat", x = 12, width = 62, justify = "LEFT" },
        { text = "%", x = 74, width = 38 },
        { text = "Now", x = 112, width = 45 },
        { text = "Goal", x = 157, width = 45 },
        { text = "+/-", x = 202, width = 58 },
    }

    for _, info in ipairs(headers) do
        local header = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        header:SetPoint("TOPLEFT", info.x, -61)
        header:SetWidth(info.width)
        header:SetJustifyH(info.justify or "RIGHT")
        header:SetText(info.text)
    end

    panel.rows = {}
    local rowLabels = {
        crit = "Critical",
        haste = "Haste",
        mastery = "Mastery",
        versatility = "Versatility",
    }

    for index, statKey in ipairs(STAT_ORDER) do
        local y = -81 - ((index - 1) * 25)
        local row = {}

        row.background = panel:CreateTexture(nil, "BACKGROUND")
        row.background:SetPoint("TOPLEFT", 8, y + 4)
        row.background:SetPoint("TOPRIGHT", -8, y + 4)
        row.background:SetHeight(23)
        row.background:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.025 or 0.045)

        row.label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("TOPLEFT", 12, y)
        row.label:SetWidth(62)
        row.label:SetJustifyH("LEFT")
        row.label:SetText(rowLabels[statKey])
        row.label:SetTextColor(0.96, 0.76, 0.24)

        local function CreateValue(x, width)
            local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("TOPLEFT", x, y)
            text:SetWidth(width)
            text:SetJustifyH("RIGHT")
            return text
        end

        row.percent = CreateValue(74, 38)
        row.current = CreateValue(112, 45)
        row.target = CreateValue(157, 45)
        row.delta = CreateValue(202, 58)
        panel.rows[statKey] = row
    end

    panel:Hide()
    statPanel = panel
    PositionStatPanel(panel)
    return panel
end

local function GetCharacterSourceDropdownParent()
    return statPanel
end

local function AnchorCharacterSourceDropdown(control, parent)
    if not control or not parent then
        return
    end

    control:ClearAllPoints()

    control:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -9)
end

local function PositionSourceDropdownMenu(control)
    if not control or not control.menu or not control.button then
        return
    end

    control.menu:ClearAllPoints()

    local screenBottom = 0
    local buttonBottom = control.button.GetBottom and control.button:GetBottom()
    local menuHeight = control.menu.GetHeight and control.menu:GetHeight() or 0
    local openDown = true

    if buttonBottom and (buttonBottom - menuHeight - 4) < screenBottom then
        openDown = false
    end

    if openDown then
        control.menu:SetPoint("TOPLEFT", control.button, "BOTTOMLEFT", 0, -2)
        control.button.arrow:SetText("v")
    else
        control.menu:SetPoint("BOTTOMLEFT", control.button, "TOPLEFT", 0, 2)
        control.button.arrow:SetText("^")
    end
end

local function RefreshCharacterSourceDropdown()
    if not sourceDropdown then
        return
    end

    local shouldShow = IsEnabled()
    local parent = GetCharacterSourceDropdownParent()

    if parent and type(parent.IsShown) == "function" and not parent:IsShown() then
        shouldShow = false
    end

    if not shouldShow then
        if sourceDropdown.menu then
            sourceDropdown.menu:Hide()
        end

        sourceDropdown:Hide()
        return
    end

    sourceDropdown.button.text:SetText(GetContextButtonText())

    for index, option in ipairs(SOURCE_OPTIONS) do
        local row = sourceDropdown.rows and sourceDropdown.rows[index]

        if row and row.check then
            row.check:SetShown(ns:GetStatTargetContext() == option.value)
        end
    end

    sourceDropdown:Show()
end

local function EnsureCharacterSourceDropdown()
    if InCombatLockdown and InCombatLockdown() then
        return nil
    end

    local parent = GetCharacterSourceDropdownParent()

    if not parent then
        return nil
    end

    if sourceDropdown and sourceDropdown:GetParent() ~= parent then
        sourceDropdown:SetParent(parent)
        AnchorCharacterSourceDropdown(sourceDropdown, parent)
    end

    if sourceDropdown then
        RefreshCharacterSourceDropdown()
        return sourceDropdown
    end

    local control = CreateFrame("Frame", nil, parent)
    control:SetSize(112, 22)
    AnchorCharacterSourceDropdown(control, parent)

    control.label = control:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    control.label:SetPoint("RIGHT", control, "RIGHT", -64, 0)
    control.label:SetText("Goals")

    control.button = CreateFrame("Button", nil, control, "BackdropTemplate")
    control.button:SetPoint("RIGHT", control, "RIGHT", 0, 0)
    control.button:SetSize(58, 20)
    control.button:RegisterForClicks("LeftButtonUp")
    control.button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    control.button:SetBackdropColor(0.02, 0.018, 0.014, 0.92)
    control.button:SetBackdropBorderColor(0.85, 0.68, 0.25, 0.7)

    control.button.text = control.button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    control.button.text:SetPoint("LEFT", control.button, "LEFT", 7, 0)
    control.button.text:SetPoint("RIGHT", control.button, "RIGHT", -16, 0)
    control.button.text:SetJustifyH("LEFT")

    control.button.arrow = control.button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    control.button.arrow:SetPoint("RIGHT", control.button, "RIGHT", -6, 0)
    control.button.arrow:SetText("v")

    control.menu = CreateFrame("Frame", nil, control, "BackdropTemplate")
    control.menu:SetSize(58, (#SOURCE_OPTIONS * 20) + 8)
    control.menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    control.menu:SetBackdropColor(0.015, 0.014, 0.012, 1)
    control.menu:SetBackdropBorderColor(0.85, 0.68, 0.25, 0.75)
    control.menu:Hide()

    control.rows = {}

    local function HideMenu()
        control.menu:Hide()
        control.button.arrow:SetText("v")
    end

    for index, option in ipairs(SOURCE_OPTIONS) do
        local row = CreateFrame("Button", nil, control.menu)
        row:SetPoint("TOPLEFT", control.menu, "TOPLEFT", 4, -4 - ((index - 1) * 20))
        row:SetSize(50, 20)
        row:RegisterForClicks("LeftButtonUp")

        row.check = row:CreateTexture(nil, "OVERLAY")
        row.check:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.check:SetSize(12, 12)
        row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        row.check:SetVertexColor(1, 0.86, 0.12, 1)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 16, 0)
        row.text:SetText(option.text)

        row:SetScript("OnClick", function()
            ns:SetStatTargetContext(option.value)
            RefreshCharacterSourceDropdown()
            HideMenu()
        end)

        control.rows[index] = row
    end

    control.button:SetScript("OnClick", function()
        if control.menu:IsShown() then
            HideMenu()
        else
            RefreshCharacterSourceDropdown()
            PositionSourceDropdownMenu(control)
            control.menu:Show()
        end
    end)

    control.button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Stat goal source")
        GameTooltip:AddLine("Changes the target set used by ZoidsTools stat comparisons.", 1, 1, 1, true)
        GameTooltip:Show()
    end)

    control.button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    sourceDropdown = control
    RefreshCharacterSourceDropdown()

    return control
end

local function RefreshStatPanel()
    local panel = EnsureStatPanel()
    local toggle = EnsureStatToggleButton()
    local characterFrame = _G.CharacterFrame
    local db = EnsureDB()

    if not panel
        or not IsEnabled()
        or not characterFrame
        or (characterFrame.IsShown and not characterFrame:IsShown()) then
        if panel then panel:Hide() end
        if sourceDropdown then sourceDropdown:Hide() end
        if toggle then toggle:Hide() end
        return
    end

    if not toggle then
        return
    end

    toggle:Show()
    RefreshStatToggleButton()

    if not db or db.statGoalsPanelShown ~= true then
        panel:Hide()
        if sourceDropdown then sourceDropdown:Hide() end
        return
    end

    PositionStatPanel(panel)
    panel:Show()
    EnsureCharacterSourceDropdown()
    RefreshCharacterSourceDropdown()

    local snapshot = GetSnapshot()
    local targets = snapshot and snapshot.targets

    if panel.priority then
        panel.priority:SetText(FormatStatPriority(snapshot))
    end

    for _, statKey in ipairs(STAT_ORDER) do
        local row = panel.rows and panel.rows[statKey]

        if row then
            local percent = FormatDefaultPercent(statKey)
            local current = GetRating(statKey)
            local target = targets and SafeNumber(targets[statKey])

            row.percent:SetText(percent or "--")
            row.current:SetText(current and FormatRating(current) or "--")
            row.target:SetText(target and FormatRating(target) or "--")

            if current and target then
                local deltaText = FormatDelta(current, target)
                row.delta:SetText(deltaText)
            else
                row.delta:SetText("--")
                row.delta:SetTextColor(0.58, 0.60, 0.64)
            end
        end
    end
end

local function QueueRefresh(delay)
    if IsCombatLocked() then
        pendingCombatRefresh = true
        return
    end

    pendingCombatRefresh = false

    if pendingRefresh then
        return
    end

    pendingRefresh = true

    local function Run()
        pendingRefresh = false
        if IsCombatLocked() then
            pendingCombatRefresh = true
            return
        end

        if ns.RecordDiagnosticActivity then ns:RecordDiagnosticActivity("StatTargets.RefreshQueue") end
        RefreshStatPanel()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.08, Run)
    else
        Run()
    end
end

local function InstallShowHooks()
    if showHooksInstalled then
        return
    end

    local installed = false

    if CharacterFrame and type(CharacterFrame.HookScript) == "function" then
        CharacterFrame:HookScript("OnShow", function()
            QueueRefresh(0.12)
        end)
        CharacterFrame:HookScript("OnHide", function()
            if statPanel then statPanel:Hide() end
            if sourceDropdown then sourceDropdown:Hide() end
        end)
        installed = true
    end

    if PaperDollFrame and type(PaperDollFrame.HookScript) == "function" then
        PaperDollFrame:HookScript("OnShow", function()
            QueueRefresh(0.12)
        end)
        installed = true
    end

    if CharacterStatsPane and type(CharacterStatsPane.HookScript) == "function" then
        CharacterStatsPane:HookScript("OnShow", function()
            QueueRefresh(0.12)
        end)
        installed = true
    end

    showHooksInstalled = installed == true
end

function ns:SetStatTargetContext(value)
    local db = EnsureDB()

    if not db then
        return
    end

    if value ~= "raid" and value ~= "pvp" then
        value = "mythicplus"
    end

    db.statTargetContext = value
    RefreshCharacterSourceDropdown()
    ns:RefreshStatTargets()
end

function ns:GetStatTargetContext()
    local db = EnsureDB()
    return db and db.statTargetContext or "mythicplus"
end

function ns:GetStatTargetStatusText()
    if not IsEnabled() then
        return "Recommended stat comparisons are disabled."
    end

    local snapshot, classToken, specKey, context = GetSnapshot()

    if snapshot then
        local readable = 0
        local source = snapshot.source or (context == "PvP" and "Murlok" or "Archon")

        for _, statKey in ipairs(STAT_ORDER) do
            if GetRating(statKey) ~= nil then
                readable = readable + 1
            end
        end

        if readable == 0 then
            return string.format("Found %s stat goals for %s %s, but your live ratings are not readable right now.", context or "selected", tostring(specKey or "current"), tostring(classToken or "class"))
        end

        return string.format("Comparing your stats to %s %s goals for %s %s.", tostring(source), context or "selected", tostring(specKey or "current"), tostring(classToken or "class"))
    end

    return "No recommended stat goals found for your current class, spec, and context."
end

function ns:RefreshStatTargets()
    QueueRefresh(0.02)
end

function ns:InitializeStatTargets()
    EnsureDB()
    InstallShowHooks()

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("ADDON_LOADED")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
        eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        RegisterStatUnitEvents()
        eventFrame:SetScript("OnEvent", function(_, event, unitOrAddon)
            if event == "PLAYER_REGEN_DISABLED" then
                pendingCombatRefresh = true
                UnregisterStatUnitEvents()
                return
            end

            if event == "PLAYER_REGEN_ENABLED" then
                RegisterStatUnitEvents()

                if pendingCombatRefresh then
                    pendingCombatRefresh = false
                    QueueRefresh(0.12)
                end

                return
            end

            if IsCombatLocked() then
                pendingCombatRefresh = true
                return
            end

            if event == "ADDON_LOADED" then
                InstallShowHooks()
                QueueRefresh(0.12)
                return
            end

            if event == "UNIT_STATS" and unitOrAddon ~= "player" then
                return
            end

            if event == "UNIT_AURA" then
                QueueRefresh(0.08)
                return
            end

            if not showHooksInstalled then
                InstallShowHooks()
            end

            QueueRefresh(event == "PLAYER_EQUIPMENT_CHANGED" and 0.18 or 0.08)
        end)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            QueueRefresh(0.02)
        end)
    end
end
