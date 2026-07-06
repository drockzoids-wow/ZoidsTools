local _, ns = ...

local WARNING_FRAME_NAME = "ZoidsToolsMissingBuffWarningFrame"
local WARNING_FRAME_MIN_WIDTH = 150
local WARNING_FRAME_HEIGHT = 74
local WARNING_ICON_SIZE = 32
local WARNING_ICON_GAP = 6
local MISSING_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

local GROUP_BUFFS_BY_CLASS = {
    DRUID = {
        { spellID = 1126, fallbackName = "Mark of the Wild" },
    },
    EVOKER = {
        { spellID = 381748, fallbackName = "Blessing of the Bronze" },
    },
    MAGE = {
        { spellID = 1459, fallbackName = "Arcane Intellect" },
    },
    PRIEST = {
        { spellID = 21562, fallbackName = "Power Word: Fortitude" },
    },
    WARRIOR = {
        { spellID = 6673, fallbackName = "Battle Shout" },
    },
}

local eventFrame
local warningFrame
local checkQueued = false
local refreshAfterCombat = false

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.combat = ns.db.combat or {}
    ns.db.combat.buffWarnings = ns.db.combat.buffWarnings or {}

    if ns.db.combat.buffWarnings.enabled == nil then
        ns.db.combat.buffWarnings.enabled = true
    end

    ns.db.combat.buffWarnings.popup = ns.db.combat.buffWarnings.popup or {}
    ns.db.combat.buffWarnings.popup.point = ns.db.combat.buffWarnings.popup.point or "CENTER"
    ns.db.combat.buffWarnings.popup.relativePoint = ns.db.combat.buffWarnings.popup.relativePoint or "CENTER"
    ns.db.combat.buffWarnings.popup.x = tonumber(ns.db.combat.buffWarnings.popup.x) or 0
    ns.db.combat.buffWarnings.popup.y = tonumber(ns.db.combat.buffWarnings.popup.y) or 150

    return ns.db.combat.buffWarnings
end

local function SaveWarningFramePosition(frame)
    local db = EnsureDB()

    if not db or not db.popup then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)

    if point then
        db.popup.point = point
        db.popup.relativePoint = relativePoint or point
        db.popup.x = x or 0
        db.popup.y = y or 0
    end
end

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

local function RegisterBuffUnitEvents()
    if eventFrame then
        RegisterUnitEventSafe(eventFrame, "UNIT_AURA", "player")
    end
end

local function UnregisterBuffUnitEvents()
    if eventFrame and type(eventFrame.UnregisterEvent) == "function" then
        eventFrame:UnregisterEvent("UNIT_AURA")
    end
end

local function HideWarningFrame()
    if not warningFrame then
        return true
    end

    if IsCombatLocked() then
        refreshAfterCombat = true
        return false
    end

    warningFrame:Hide()
    warningFrame:SetAlpha(1)
    warningFrame.ZTConcealedForCombat = nil
    return true
end

local function ConcealWarningFrameForCombat()
    if not warningFrame then
        return
    end

    refreshAfterCombat = true

    if GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end

    if not IsCombatLocked() then
        warningFrame:Hide()
        warningFrame:SetAlpha(1)
        warningFrame.ZTConcealedForCombat = nil
        return
    end

    warningFrame.ZTConcealedForCombat = true
    warningFrame:SetAlpha(0)
end

local function RestoreWarningFrameAfterCombat()
    if warningFrame and warningFrame.ZTConcealedForCombat then
        warningFrame:SetAlpha(1)
        warningFrame.ZTConcealedForCombat = nil
    end
end

local function RestoreWarningFramePosition(frame)
    local db = EnsureDB()
    local position = db and db.popup

    frame:ClearAllPoints()

    if position and position.point then
        frame:SetPoint(
            position.point,
            UIParent,
            position.relativePoint or position.point,
            position.x or 0,
            position.y or 150
        )
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    end
end

local function CreateWarningFrame()
    if warningFrame then
        return warningFrame
    end

    local frame = CreateFrame("Frame", WARNING_FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(WARNING_FRAME_MIN_WIDTH, WARNING_FRAME_HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(12)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.015, 0.014, 0.012, 0.86)
    frame:SetBackdropBorderColor(0.85, 0.7, 0.38, 0.78)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    frame.title:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    frame.title:SetJustifyH("CENTER")
    frame.title:SetText("Missing Buffs")

    frame.buffIcons = {}

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWarningFramePosition(self)
    end)

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Missing Group Buffs")
        GameTooltip:AddLine("Shows while grouped, out of combat, and missing a group buff.", 1, 1, 1, true)
        GameTooltip:AddLine("Drag to move this popup.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    RestoreWarningFramePosition(frame)
    frame:Hide()
    warningFrame = frame

    return frame
end

local function SafeAPICall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result = pcall(func, ...)

    if ok then
        return result
    end

    return nil
end

local function GetSpellName(spellID, fallbackName)
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)

        if name then
            return name
        end
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)

        if info and info.name then
            return info.name
        end
    end

    if GetSpellInfo then
        local name = GetSpellInfo(spellID)

        if name then
            return name
        end
    end

    return fallbackName
end

local function GetSpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local icon = C_Spell.GetSpellTexture(spellID)

        if icon then
            return icon
        end
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)

        if info and info.iconID then
            return info.iconID
        end
    end

    if GetSpellTexture then
        local icon = GetSpellTexture(spellID)

        if icon then
            return icon
        end
    end

    return MISSING_ICON_FALLBACK
end

local function PlayerCanCastBuff(spellID)
    if not spellID then
        return false
    end

    if IsPlayerSpell and SafeAPICall(IsPlayerSpell, spellID) == true then
        return true
    end

    if IsSpellKnown and SafeAPICall(IsSpellKnown, spellID) == true then
        return true
    end

    if C_SpellBook and C_SpellBook.IsSpellKnown and SafeAPICall(C_SpellBook.IsSpellKnown, spellID) == true then
        return true
    end

    return false
end

local function SafeEquals(left, right)
    local ok, matches = pcall(function()
        return left ~= nil and right ~= nil and left == right
    end)

    return ok and matches == true
end

local function SafeAuraNameEquals(aura, spellName)
    local ok, matches = pcall(function()
        return aura and aura.name ~= nil and spellName ~= nil and aura.name == spellName
    end)

    return ok and matches == true
end

local function IsWarningAllowed()
    local db = EnsureDB()

    if not db or db.enabled ~= true then
        return false
    end

    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return false
    end

    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
        return false
    end

    if IsInGroup and IsInGroup() then
        return true
    end

    return IsInRaid and IsInRaid()
end

local function PlayerHasAura(spellID, fallbackName)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)

        if ok and aura then
            return true
        end
    end

    local spellName = GetSpellName(spellID, fallbackName)

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for index = 1, 80 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")

            if not ok or not aura then
                break
            end

            if SafeAuraNameEquals(aura, spellName) then
                return true
            end
        end
    end

    if AuraUtil and AuraUtil.FindAuraByName and spellName then
        local ok, aura = pcall(AuraUtil.FindAuraByName, spellName, "player", "HELPFUL")

        if ok and aura then
            return true
        end
    end

    if UnitAura then
        for index = 1, 80 do
            local ok, name = pcall(UnitAura, "player", index, "HELPFUL")

            if not ok or not name then
                break
            end

            if SafeEquals(name, spellName) then
                return true
            end
        end
    end

    return false
end

local function AddExpectedBuffsFromUnit(expectedBuffs, unit)
    if not UnitExists or not UnitExists(unit) then
        return
    end

    local _, classFile = UnitClass(unit)
    local classBuffs = classFile and GROUP_BUFFS_BY_CLASS[classFile]

    if not classBuffs then
        return
    end

    for _, buff in ipairs(classBuffs) do
        expectedBuffs[buff.spellID] = buff
    end
end

local function GetExpectedBuffs()
    local expectedBuffs = {}

    AddExpectedBuffsFromUnit(expectedBuffs, "player")

    if IsInRaid and IsInRaid() then
        local members = GetNumGroupMembers and GetNumGroupMembers() or 0

        for index = 1, members do
            AddExpectedBuffsFromUnit(expectedBuffs, "raid" .. index)
        end
    else
        local members = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0

        for index = 1, members do
            AddExpectedBuffsFromUnit(expectedBuffs, "party" .. index)
        end
    end

    return expectedBuffs
end

local function BuildMissingBuffList()
    local expectedBuffs = GetExpectedBuffs()
    local missing = {}

    for spellID, buff in pairs(expectedBuffs) do
        if not PlayerHasAura(spellID, buff.fallbackName) then
            table.insert(missing, {
                spellID = spellID,
                name = GetSpellName(spellID, buff.fallbackName) or buff.fallbackName,
                icon = GetSpellIcon(spellID),
                canCast = PlayerCanCastBuff(spellID),
            })
        end
    end

    table.sort(missing, function(a, b)
        return tostring(a.name or "") < tostring(b.name or "")
    end)

    return missing
end

local function GetWarningIconButton(frame, index)
    frame.buffIcons = frame.buffIcons or {}

    local button = frame.buffIcons[index]

    if button then
        return button
    end

    button = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate,BackdropTemplate")
    button:SetSize(WARNING_ICON_SIZE, WARNING_ICON_SIZE)
    button:SetMovable(false)
    button:RegisterForClicks("LeftButtonUp")
    button:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button:SetBackdropBorderColor(0.85, 0.7, 0.38, 0.82)
    button.owner = frame

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.buffName or "Missing buff")
        GameTooltip:AddLine("Missing group buff.", 1, 1, 1, true)

        if self.canCastBuff then
            GameTooltip:AddLine("Left-click to cast.", 0.8, 1, 0.8, true)
        else
            GameTooltip:AddLine("Someone in your group can provide this buff.", 1, 0.85, 0.55, true)
        end

        GameTooltip:AddLine("Drag the popup by the empty space.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame.buffIcons[index] = button

    return button
end

local function UpdateWarningIcons(frame, missing)
    if IsCombatLocked() then
        refreshAfterCombat = true
        return false
    end

    local count = #missing
    local rowWidth = count * WARNING_ICON_SIZE + math.max(0, count - 1) * WARNING_ICON_GAP
    local frameWidth = math.max(WARNING_FRAME_MIN_WIDTH, rowWidth + 24)
    local rowLeft = math.floor(((frameWidth - rowWidth) / 2) + 0.5)

    frame:SetSize(frameWidth, WARNING_FRAME_HEIGHT)

    for index, buff in ipairs(missing) do
        local button = GetWarningIconButton(frame, index)

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", rowLeft + (index - 1) * (WARNING_ICON_SIZE + WARNING_ICON_GAP), -34)
        button.buffName = buff.name
        button.spellID = buff.spellID
        button.canCastBuff = buff.canCast == true
        button.icon:SetTexture(buff.icon or MISSING_ICON_FALLBACK)

        if button.canCastBuff then
            button:SetAttribute("type1", "spell")
            button:SetAttribute("spell1", buff.name or buff.spellID)
            button:SetAttribute("unit1", "player")
        else
            button:SetAttribute("type1", nil)
            button:SetAttribute("spell1", nil)
            button:SetAttribute("unit1", nil)
        end

        button:SetAttribute("macrotext1", nil)
        button:SetAttribute("type2", nil)
        button:SetAttribute("spell2", nil)
        button:SetAttribute("unit2", nil)
        button:SetAttribute("macrotext2", nil)
        button:Show()
    end

    for index = count + 1, #(frame.buffIcons or {}) do
        frame.buffIcons[index]:Hide()
    end

    return true
end

local function WarnMissingBuffs()
    if not IsWarningAllowed() then
        HideWarningFrame()
        return
    end

    local missing = BuildMissingBuffList()

    if #missing == 0 then
        HideWarningFrame()
        return
    end

    local frame = CreateWarningFrame()

    if not UpdateWarningIcons(frame, missing) then
        return
    end

    if IsCombatLocked() then
        refreshAfterCombat = true
        return
    end

    frame:Show()
end

local function ScheduleCheck(delay)
    if checkQueued then
        return
    end

    if IsCombatLocked() then
        refreshAfterCombat = true
        return
    end

    checkQueued = true

    local function RunCheck()
        checkQueued = false
        WarnMissingBuffs()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.75, RunCheck)
    else
        RunCheck()
    end
end

function ns:GetBuffWarningsEnabled()
    local db = EnsureDB()

    return db and db.enabled == true
end

function ns:SetBuffWarningsEnabled(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.enabled = value == true

    if db.enabled then
        CreateWarningFrame()
        ScheduleCheck(0.2)
    else
        HideWarningFrame()
    end
end

function ns:RefreshBuffWarnings()
    CreateWarningFrame()
    ScheduleCheck(0.1)
end

function ns:InitializeBuffWarnings()
    EnsureDB()
    CreateWarningFrame()

    if eventFrame then
        ScheduleCheck(1)
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    RegisterBuffUnitEvents()
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" and unit ~= "player" then
            return
        end

        if event == "PLAYER_REGEN_DISABLED" then
            UnregisterBuffUnitEvents()
            ConcealWarningFrameForCombat()
        elseif event == "PLAYER_REGEN_ENABLED" then
            RegisterBuffUnitEvents()
            RestoreWarningFrameAfterCombat()
            refreshAfterCombat = false
            ScheduleCheck(0.3)
        elseif IsCombatLocked() then
            refreshAfterCombat = true
        else
            ScheduleCheck(0.75)
        end
    end)

    ScheduleCheck(1)
end
