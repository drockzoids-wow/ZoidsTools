local _, ns = ...

local API = _G.ZoidsToolsMounts or {}
_G.ZoidsToolsMounts = API

local eventFrame
local initialized = false
local mountTypeIDByMountID = {}
local mountIDByAuraName
local targetMatchButton
local targetMatchUpdateQueued = false
local lastDryTime = 0
local lastCombatEndedAt = 0

local TARGET_MATCH_BUTTON_NAME = "ZoidsToolsTargetMountMatchButton"
local TARGET_MATCH_BUTTON_SIZE = 56
local TARGET_MATCH_ICON_INSET = 4
local TARGET_MATCH_DEFAULT_ICON = "Interface\\AddOns\\ZoidsTools\\Media\\ZoidToolsIcon.png"
local POST_COMBAT_MOUNT_USABILITY_GRACE = 5

local DRUID_TRAVEL_FORM_SPELL_ID = 783
local DRUID_CAT_FORM_SPELL_ID = 768
local DRACTHYR_SOAR_SPELL_ID = 369536

local FALLING_RESCUE_BY_CLASS = {
    PRIEST = {
        { spellID = 1706, name = "Levitate", unit = "player" },
    },
    MAGE = {
        { spellID = 130, name = "Slow Fall", unit = "player" },
    },
    EVOKER = {
        { spellID = 358733, name = "Glide" },
    },
    DEMONHUNTER = {
        { spellID = 131347, name = "Glide" },
    },
    DRUID = {
        { spellID = 164862, name = "Flap" },
    },
    MONK = {
        { spellID = 125883, name = "Zen Flight" },
    },
}

local FLYING_MOUNT_TYPES = {
    [247] = true,
    [248] = true,
    [254] = true,
    [269] = true,
    [398] = true,
    [402] = true,
    [407] = true,
    [412] = true,
    [424] = true,
    [426] = true,
    [436] = true,
}

local WATER_MOUNT_TYPES = {
    [231] = true,
    [232] = true,
    [254] = true,
    [407] = true,
}

local RIDE_ALONG_MOUNT_POOLS = {
    flying = {
        "renewed proto-drake",
        "windborne velocidrake",
        "highland drake",
        "cliffside wylderdrake",
        "winding slitherdrake",
        "grotto netherwing drake",
        "flourishing whimsydrake",
        "sandstone drake",
        "vial of the sands",
        "x-53 touring rocket",
        "heart of the nightwing",
        "obsidian nightwing",
        "stormwind skychaser",
        "orgrimmar interceptor",
        "the hivemind",
    },
    ground = {
        "mechano-hog",
        "mekgineer's chopper",
    },
    lowLevelGround = {
        "chauffeured mechano-hog",
        "chauffeured mekgineer's chopper",
    },
}

local SERVICE_MOUNT_PRIORITY = {
    repair = {
        "mighty caravan brutosaur",
        "grand expedition yak",
        "grizzly hills packmaster",
        "traveler's tundra mammoth",
        "traveller's tundra mammoth",
    },
    auctionHouse = {
        "mighty caravan brutosaur",
        "trader's gilded brutosaur",
    },
    rideAlong = {},
}

for _, poolKey in ipairs({ "flying", "ground", "lowLevelGround" }) do
    for _, mountName in ipairs(RIDE_ALONG_MOUNT_POOLS[poolKey]) do
        SERVICE_MOUNT_PRIORITY.rideAlong[#SERVICE_MOUNT_PRIORITY.rideAlong + 1] = mountName
    end
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.mounts = ns.db.mounts or {}

    local db = ns.db.mounts

    if db.enabled == nil then
        db.enabled = true
    end

    if db.preferGroundWhenNotFlyable == nil then
        db.preferGroundWhenNotFlyable = true
    end

    if db.useWaterMountsOnSurface == nil then
        db.useWaterMountsOnSurface = true
    end

    if db.excludeServiceMountsFromRandom == nil then
        db.excludeServiceMountsFromRandom = true
    end

    if db.useDruidTravelForm == nil then
        db.useDruidTravelForm = true
    end

    if db.useDruidCatForm == nil then
        db.useDruidCatForm = true
    end

    if db.useDracthyrSoar == nil then
        db.useDracthyrSoar = true
    end

    if db.useFallingRescue == nil then
        db.useFallingRescue = true
    end

    if db.targetMatchEnabled == nil then
        db.targetMatchEnabled = true
    end

    db.targetMatchButton = db.targetMatchButton or {}

    if db.targetMatchButton.shown == nil then
        db.targetMatchButton.shown = true
    end

    db.targetMatchButton.point = db.targetMatchButton.point or "CENTER"
    db.targetMatchButton.relativePoint = db.targetMatchButton.relativePoint or "CENTER"
    db.targetMatchButton.x = tonumber(db.targetMatchButton.x) or 220
    db.targetMatchButton.y = tonumber(db.targetMatchButton.y) or 0

    db.recentAvoidCount = tonumber(db.recentAvoidCount) or 3

    if db.recentAvoidCount < 0 then
        db.recentAvoidCount = 0
    elseif db.recentAvoidCount > 10 then
        db.recentAvoidCount = 10
    end

    db.preferredMount = db.preferredMount or nil
    db.preferredServiceMounts = db.preferredServiceMounts or {}
    db.recentMounts = db.recentMounts or {}
    db.mountUsage = db.mountUsage or {}

    return db
end

local function Print(message)
    if ns.Print then
        ns:Print(message)
    end
end

local function EnsureMountJournalLoaded()
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_Collections")
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_Collections")
    end
end

local function NormalizeMountName(name)
    local ok, normalized = pcall(function()
        if not name then
            return ""
        end

        local text = string.lower(tostring(name))
        text = text:gsub("\226\128\153", "'")
        text = text:gsub("reins of the ", "")
        text = text:gsub("reins of ", "")

        return text
    end)

    if ok and normalized then
        return normalized
    end

    return ""
end

local function IsPlayerInCombat()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end

    return UnitAffectingCombat and UnitAffectingCombat("player") == true
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

local function RegisterTargetAuraEvent(frame)
    RegisterUnitEventSafe(frame, "UNIT_AURA", "target")
end

local function UnregisterTargetAuraEvent(frame)
    if frame and type(frame.UnregisterEvent) == "function" then
        frame:UnregisterEvent("UNIT_AURA")
    end
end

local function IsRecentlyOutOfCombat()
    if not GetTime or lastCombatEndedAt <= 0 then
        return false
    end

    return (GetTime() - lastCombatEndedAt) <= POST_COMBAT_MOUNT_USABILITY_GRACE
end

local function GetTargetMatchBlockReason()
    if IsPlayerInCombat() then
        return "Target matching pauses in combat."
    end

    if not UnitExists or not UnitExists("target") then
        return "No target selected."
    end

    if UnitCanAttack and UnitCanAttack("player", "target") then
        return "Target matching ignores hostile targets."
    end

    if UnitIsPlayer and not UnitIsPlayer("target") then
        return "Target matching only checks player targets."
    end

    return nil
end

local function BlockedTargetMatch(status)
    return {
        available = false,
        status = status or "Target has no matchable mount.",
    }
end

local function HideTargetMatchButtonForCombat()
    if not targetMatchButton then
        return
    end

    targetMatchButton.match = BlockedTargetMatch("Target matching pauses in combat.")
    targetMatchButton:Hide()
end

local function GetSpellName(spellID)
    spellID = tonumber(spellID)

    if not spellID then
        return nil
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name
    end

    return GetSpellInfo and GetSpellInfo(spellID)
end

local function IsSpellKnownByPlayer(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    elseif IsPlayerSpell then
        return IsPlayerSpell(spellID)
    elseif IsSpellKnown then
        return IsSpellKnown(spellID)
    end

    return GetSpellName(spellID) ~= nil
end

local function SpellUsable(spellID)
    local spellName = GetSpellName(spellID)

    if not spellName then
        return false
    end

    local usable, noMana

    if C_Spell and C_Spell.IsSpellUsable then
        usable, noMana = C_Spell.IsSpellUsable(spellID)
    elseif IsUsableSpell then
        usable, noMana = IsUsableSpell(spellName)
    else
        usable = true
    end

    if not usable or noMana then
        return false
    end

    if C_Spell and C_Spell.GetSpellCooldown then
        local cooldown = C_Spell.GetSpellCooldown(spellID)

        if cooldown and cooldown.startTime and cooldown.duration and cooldown.duration > 0 then
            return false
        end
    elseif GetSpellCooldown then
        local start, duration = GetSpellCooldown(spellName)

        if start and duration and duration > 0 then
            return false
        end
    end

    return true
end

local function PlayerClass()
    if UnitClass then
        local _, classFile = UnitClass("player")
        return classFile
    end

    return nil
end

local function PlayerRace()
    if UnitRace then
        local _, raceFile = UnitRace("player")
        return raceFile
    end

    return nil
end

local function NormalizeFactionToken(value)
    if type(value) == "string" then
        local token = string.lower(value)

        if token == "horde" then
            return "Horde"
        elseif token == "alliance" then
            return "Alliance"
        end
    elseif type(value) == "number" then
        if LE_MOUNT_FACTION_HORDE ~= nil and value == LE_MOUNT_FACTION_HORDE then
            return "Horde"
        elseif LE_MOUNT_FACTION_ALLIANCE ~= nil and value == LE_MOUNT_FACTION_ALLIANCE then
            return "Alliance"
        end

        if Enum and Enum.PlayerFaction then
            if Enum.PlayerFaction.Horde ~= nil and value == Enum.PlayerFaction.Horde then
                return "Horde"
            elseif Enum.PlayerFaction.Alliance ~= nil and value == Enum.PlayerFaction.Alliance then
                return "Alliance"
            end
        end

        if value == 0 then
            return "Horde"
        elseif value == 1 then
            return "Alliance"
        end
    end

    return nil
end

local function GetPlayerFactionToken()
    if not UnitFactionGroup then
        return nil
    end

    local factionGroup, factionName = UnitFactionGroup("player")
    return NormalizeFactionToken(factionGroup) or NormalizeFactionToken(factionName)
end

local function GetMountName(mountID)
    if not mountID or not C_MountJournal or not C_MountJournal.GetMountInfoByID then
        return nil
    end

    local name = C_MountJournal.GetMountInfoByID(mountID)
    return name
end

local function GetMountDetails(mountID)
    mountID = tonumber(mountID)

    if not mountID or not C_MountJournal or not C_MountJournal.GetMountInfoByID then
        return nil
    end

    local name, spellID, icon, isActive, isUsable, _, _, isFactionSpecific, faction, shouldHideOnChar, isCollected =
        C_MountJournal.GetMountInfoByID(mountID)

    return {
        mountID = mountID,
        name = name,
        spellID = spellID,
        icon = icon,
        isActive = isActive,
        isUsable = isUsable,
        isFactionSpecific = isFactionSpecific,
        faction = faction,
        shouldHideOnChar = shouldHideOnChar,
        isCollected = isCollected,
    }
end

local function IsMountAllowedForCharacter(details)
    if not details then
        return false
    end

    if details.shouldHideOnChar == true then
        return false
    end

    if details.isFactionSpecific ~= true then
        return true
    end

    local mountFaction = NormalizeFactionToken(details.faction)
    local playerFaction = GetPlayerFactionToken()

    if not mountFaction or not playerFaction then
        return false
    end

    return mountFaction == playerFaction
end

local function GetMountSpellName(mountID)
    local details = GetMountDetails(mountID)

    if not details then
        return nil
    end

    return GetSpellName(details.spellID) or details.name
end

local function StoreMountNameLookup(name, mountID)
    local key = NormalizeMountName(name)

    if key == "" or not mountID then
        return
    end

    if not mountIDByAuraName[key] then
        mountIDByAuraName[key] = mountID
    end
end

local function RebuildMountAuraLookup()
    EnsureMountJournalLoaded()
    mountIDByAuraName = {}

    if not C_MountJournal or not C_MountJournal.GetMountIDs or not C_MountJournal.GetMountInfoByID then
        return
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local plainMountID = tonumber(mountID)

        if plainMountID then
            local mountName, mountSpellID = C_MountJournal.GetMountInfoByID(plainMountID)

            StoreMountNameLookup(mountName, plainMountID)
            StoreMountNameLookup(GetSpellName(mountSpellID), plainMountID)
        end
    end
end

local function GetMountIDByAuraName(name)
    local key = NormalizeMountName(name)

    if key == "" then
        return nil
    end

    if not mountIDByAuraName then
        RebuildMountAuraLookup()
    end

    return mountIDByAuraName and mountIDByAuraName[key]
end

local function GetHelpfulAura(unit, index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")

        if ok and aura then
            local readOk, name, icon, spellID = pcall(function()
                return aura.name, aura.icon, aura.spellId or aura.spellID
            end)

            if readOk then
                return name, icon, spellID
            end
        end
    end

    if UnitAura then
        local ok, name, icon, _, _, _, _, _, _, _, spellID = pcall(UnitAura, unit, index, "HELPFUL")

        if ok and name then
            return name, icon, spellID
        end
    end

    return nil, nil, nil
end

local function GetActiveMountID()
    EnsureMountJournalLoaded()

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return nil
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local details = GetMountDetails(mountID)

        if details and details.isActive then
            return mountID
        end
    end

    return nil
end

local function GetMountTypeID(mountID)
    mountID = tonumber(mountID)

    if not mountID then
        return nil
    end

    local cached = mountTypeIDByMountID[mountID]

    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    if not C_MountJournal or not C_MountJournal.GetMountInfoExtraByID then
        return nil
    end

    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    mountTypeIDByMountID[mountID] = mountTypeID or false

    return mountTypeID
end

local function GetTargetMountMatch()
    local db = EnsureDB()

    if not db or db.targetMatchEnabled == false then
        return BlockedTargetMatch("Target matching is disabled.")
    end

    local blockedReason = GetTargetMatchBlockReason()

    if blockedReason then
        return BlockedTargetMatch(blockedReason)
    end

    local foundMountName
    local foundUnavailableStatus

    for index = 1, 40 do
        local auraName, auraIcon = GetHelpfulAura("target", index)

        if not auraName then
            break
        end

        local mountID = GetMountIDByAuraName(auraName)

        if mountID then
            local details = GetMountDetails(mountID)
            local mountName = details and details.name or auraName or ("Mount " .. tostring(mountID))

            foundMountName = foundMountName or mountName

            if details and details.isCollected and details.isUsable and IsMountAllowedForCharacter(details) then
                return {
                    available = true,
                    mountID = mountID,
                    mountName = mountName,
                    icon = details.icon or auraIcon,
                    status = "Match: " .. tostring(mountName),
                }
            end

            if details and details.isCollected and not IsMountAllowedForCharacter(details) then
                foundUnavailableStatus = "Not available to your faction: " .. tostring(mountName)
            elseif details and details.isCollected then
                foundUnavailableStatus = "Owned, but unusable here: " .. tostring(mountName)
            else
                foundUnavailableStatus = "Not collected: " .. tostring(mountName)
            end
        end
    end

    return {
        available = false,
        mountName = foundMountName,
        status = foundUnavailableStatus or "Target has no matchable mount.",
    }
end

local function SaveTargetMatchButtonPosition(button)
    local db = EnsureDB()

    if not db or not db.targetMatchButton then
        return
    end

    local point, _, relativePoint, x, y = button:GetPoint(1)

    if point then
        db.targetMatchButton.point = point
        db.targetMatchButton.relativePoint = relativePoint or point
        db.targetMatchButton.x = x or 0
        db.targetMatchButton.y = y or 0
    end
end

local function RestoreTargetMatchButtonPosition(button)
    local db = EnsureDB()
    local position = db and db.targetMatchButton

    button:ClearAllPoints()

    if position and position.point then
        button:SetPoint(
            position.point,
            UIParent,
            position.relativePoint or position.point,
            position.x or 0,
            position.y or 0
        )
    else
        button:SetPoint("CENTER", UIParent, "CENTER", 220, 0)
    end
end

local function UpdateTargetMatchButton()
    local button = targetMatchButton

    if not button then
        return
    end

    local db = EnsureDB()

    if not db or db.targetMatchEnabled == false or not db.targetMatchButton or db.targetMatchButton.shown == false then
        button:Hide()
        return
    end

    if IsPlayerInCombat() then
        HideTargetMatchButtonForCombat()
        return
    end

    local match = GetTargetMountMatch()

    button.match = match
    button.icon:SetTexture((match and match.icon) or TARGET_MATCH_DEFAULT_ICON)
    button.icon:SetDesaturated(not (match and match.available))
    button:SetAlpha((match and match.available) and 1 or 0.58)
    button:Show()
end

local function ScheduleTargetMatchButtonUpdate(delay)
    if targetMatchUpdateQueued then
        return
    end

    targetMatchUpdateQueued = true
    delay = tonumber(delay) or 0.08

    local function Run()
        targetMatchUpdateQueued = false
        UpdateTargetMatchButton()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay, Run)
    else
        Run()
    end
end

local function CreateTargetMatchButton()
    if targetMatchButton then
        return targetMatchButton
    end

    local button = CreateFrame("Button", TARGET_MATCH_BUTTON_NAME, UIParent, "BackdropTemplate")
    button:SetSize(TARGET_MATCH_BUTTON_SIZE, TARGET_MATCH_BUTTON_SIZE)
    button:SetFrameStrata("LOW")
    button:SetFrameLevel(8)
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    button:SetBackdropColor(0.015, 0.014, 0.012, 0.78)
    button:SetBackdropBorderColor(0.85, 0.7, 0.38, 0.78)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", TARGET_MATCH_ICON_INSET, -TARGET_MATCH_ICON_INSET)
    button.icon:SetPoint("BOTTOMRIGHT", -TARGET_MATCH_ICON_INSET, TARGET_MATCH_ICON_INSET)
    button.icon:SetTexture(TARGET_MATCH_DEFAULT_ICON)

    button:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveTargetMatchButtonPosition(self)
    end)

    button:SetScript("OnClick", function()
        if API.MatchTargetMount then
            API.MatchTargetMount()
        end

        ScheduleTargetMatchButtonUpdate(0.08)
    end)

    button:SetScript("OnEnter", function(self)
        local match = self.match

        if not match and not IsPlayerInCombat() then
            match = GetTargetMountMatch()
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Match Target Mount")
        GameTooltip:AddLine((match and match.status) or "Select a mounted target.", 1, 1, 1, true)
        GameTooltip:AddLine("Click to summon the target's mount if you own it.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Drag to move this button.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnEvent", function(self, event, unit)
        if event == "UNIT_AURA" and unit ~= "target" then
            return
        end

        if event == "PLAYER_REGEN_DISABLED" then
            UnregisterTargetAuraEvent(self)
            HideTargetMatchButtonForCombat()
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            RegisterTargetAuraEvent(self)
            UpdateTargetMatchButton()
        elseif IsPlayerInCombat() then
            return
        else
            ScheduleTargetMatchButtonUpdate(0.08)
        end
    end)

    button:RegisterEvent("PLAYER_TARGET_CHANGED")
    RegisterTargetAuraEvent(button)
    button:RegisterEvent("PLAYER_ENTERING_WORLD")
    button:RegisterEvent("ZONE_CHANGED")
    button:RegisterEvent("ZONE_CHANGED_INDOORS")
    button:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    button:RegisterEvent("PLAYER_REGEN_DISABLED")
    button:RegisterEvent("PLAYER_REGEN_ENABLED")

    RestoreTargetMatchButtonPosition(button)
    targetMatchButton = button

    return button
end

local function IsFlyingMount(mountID)
    return FLYING_MOUNT_TYPES[GetMountTypeID(mountID)] == true
end

local function IsWaterMount(mountID)
    return WATER_MOUNT_TYPES[GetMountTypeID(mountID)] == true
end

local function GetBreathTimerState()
    if not GetMirrorTimerInfo then
        return nil, nil, nil
    end

    for index = 1, MIRRORTIMER_NUMTIMERS or 3 do
        local timer, value, maxValue, scale = GetMirrorTimerInfo(index)

        if timer == "BREATH" then
            return value, maxValue, scale
        end
    end

    return nil, nil, nil
end

local function HasActiveUnderwaterBreathTimer()
    local _, _, scale = GetBreathTimerState()
    return scale ~= nil and scale < 0
end

local function UpdateWaterSurfaceState()
    if not IsSubmerged or not GetTime then
        return
    end

    if not IsSubmerged() then
        lastDryTime = GetTime()
    end
end

local function IsPlayerFloatingAtSurface()
    if not IsSubmerged or not GetTime or not IsSubmerged() then
        return false
    end

    return not HasActiveUnderwaterBreathTimer() and GetTime() - (lastDryTime or 0) < 1.0
end

local function IsPlayerSwimmingAtSurface()
    if not IsSwimming or not IsSwimming() then
        return false
    end

    if IsSubmerged then
        return IsSubmerged() ~= true or IsPlayerFloatingAtSurface()
    end

    return not HasActiveUnderwaterBreathTimer()
end

local function IsPlayerSubmergedForMounts()
    if IsSubmerged then
        return IsSubmerged() == true and not IsPlayerFloatingAtSurface()
    end

    if HasActiveUnderwaterBreathTimer() then
        return true
    end

    return false
end

local function IsPlayerUnderwaterForMounts()
    return IsSwimming and IsSwimming() and IsPlayerSubmergedForMounts()
end

local function CanFlyHere()
    return IsFlyableArea and IsFlyableArea()
end

local function IsFlyableWaterContext()
    return IsSwimming and IsSwimming() and CanFlyHere() and IsPlayerSwimmingAtSurface()
end

local function RandomIndex(maxValue)
    if math and math.random then
        return math.random(maxValue)
    end

    return random(maxValue)
end

local serviceMountNameLookup

local function GetServiceMountNameLookup()
    if serviceMountNameLookup then
        return serviceMountNameLookup
    end

    serviceMountNameLookup = {}

    for _, priorityList in pairs(SERVICE_MOUNT_PRIORITY) do
        for _, mountName in ipairs(priorityList) do
            serviceMountNameLookup[NormalizeMountName(mountName)] = true
        end
    end

    return serviceMountNameLookup
end

local function IsServiceMountName(name)
    return name and GetServiceMountNameLookup()[NormalizeMountName(name)] == true
end

local rideAlongMountPoolLookup

local function GetRideAlongMountPoolLookup()
    if rideAlongMountPoolLookup then
        return rideAlongMountPoolLookup
    end

    rideAlongMountPoolLookup = {}

    for poolKey, mountNames in pairs(RIDE_ALONG_MOUNT_POOLS) do
        for _, mountName in ipairs(mountNames) do
            rideAlongMountPoolLookup[NormalizeMountName(mountName)] = poolKey
        end
    end

    return rideAlongMountPoolLookup
end

local function GetRideAlongMountPool(name)
    return name and GetRideAlongMountPoolLookup()[NormalizeMountName(name)] or nil
end

local function GetPlayerLevel()
    if UnitLevel then
        return UnitLevel("player")
    end

    return 70
end

local function IsBelowNormalMountLevel()
    local level = GetPlayerLevel()
    return level and level < 10
end

local function PreferFlyingRideAlongMount()
    return CanFlyHere() and not IsBelowNormalMountLevel()
end

local function IsRideAlongMountAllowed(name)
    local poolKey = GetRideAlongMountPool(name)

    if poolKey == "flying" then
        return PreferFlyingRideAlongMount()
    elseif poolKey == "ground" then
        return not PreferFlyingRideAlongMount() and not IsBelowNormalMountLevel()
    elseif poolKey == "lowLevelGround" then
        return IsBelowNormalMountLevel()
    end

    return false
end

local function GetMountUsage(mountID)
    local db = EnsureDB()
    db.mountUsage = db.mountUsage or {}

    return db.mountUsage[mountID] or db.mountUsage[tostring(mountID)] or 0
end

local cachedSmartSelectionPool
local cachedSmartSelectionMountID

local function RecordMountUsage(mountID)
    local db = EnsureDB()
    mountID = tonumber(mountID)

    if not db or not mountID then
        return
    end

    db.mountUsage[mountID] = GetMountUsage(mountID) + 1
    db.mountUsage[tostring(mountID)] = nil
end

local function RecordRecentMount(mountID)
    local db = EnsureDB()
    mountID = tonumber(mountID)

    if not db or not mountID then
        return
    end

    db.recentMounts = db.recentMounts or {}

    for index = #db.recentMounts, 1, -1 do
        if tonumber(db.recentMounts[index]) == mountID then
            table.remove(db.recentMounts, index)
        end
    end

    table.insert(db.recentMounts, 1, mountID)

    while #db.recentMounts > 20 do
        table.remove(db.recentMounts)
    end
end

local function TrackSelectedMount(mountID)
    local db = EnsureDB()
    mountID = tonumber(mountID)

    if not db or not mountID then
        return
    end

    db.lastMountID = mountID
    RecordMountUsage(mountID)
    RecordRecentMount(mountID)
    cachedSmartSelectionPool = nil
    cachedSmartSelectionMountID = nil
end

local function BuildRecentMountSet()
    local db = EnsureDB()
    local recentSet = {}
    local avoidCount = db and tonumber(db.recentAvoidCount) or 0

    if not db or avoidCount <= 0 then
        return recentSet
    end

    for index, mountID in ipairs(db.recentMounts or {}) do
        if index > avoidCount then
            break
        end

        mountID = tonumber(mountID)

        if mountID then
            recentSet[mountID] = true
        end
    end

    return recentSet
end

local function ApplyRecentAvoidance(mountIDs)
    if not mountIDs or #mountIDs == 0 then
        return mountIDs or {}
    end

    local recentSet = BuildRecentMountSet()
    local filtered = {}

    for _, mountID in ipairs(mountIDs) do
        if not recentSet[mountID] then
            filtered[#filtered + 1] = mountID
        end
    end

    if #filtered == 0 then
        return mountIDs
    end

    return filtered
end

local function PickLeastUsedMount(mountIDs)
    if not mountIDs or #mountIDs == 0 then
        return nil
    end

    local totalWeight = 0

    for _, mountID in ipairs(mountIDs) do
        local weight = 1 / math.sqrt(GetMountUsage(mountID) + 1)
        totalWeight = totalWeight + weight
    end

    local roll = math.random() * totalWeight
    local running = 0

    for _, mountID in ipairs(mountIDs) do
        running = running + (1 / math.sqrt(GetMountUsage(mountID) + 1))

        if roll <= running then
            return mountID
        end
    end

    return mountIDs[RandomIndex(#mountIDs)]
end

local function PickMountFromPool(mountIDs)
    return PickLeastUsedMount(ApplyRecentAvoidance(mountIDs))
end

local function GetFallingRescueAction()
    local db = EnsureDB()

    if not db or db.useFallingRescue == false or not IsFalling or not IsFalling() then
        return nil
    end

    local rescues = FALLING_RESCUE_BY_CLASS[PlayerClass()]

    if not rescues then
        return nil
    end

    for _, rescue in ipairs(rescues) do
        if IsSpellKnownByPlayer(rescue.spellID) then
            local spellName = GetSpellName(rescue.spellID)

            if spellName then
                if rescue.spellID == 131347 or rescue.spellID == 358733 or SpellUsable(rescue.spellID) then
                    return {
                        type = "spell",
                        spell = spellName,
                        unit = rescue.unit,
                    }
                end
            end
        end
    end

    return nil
end

local function SummonTrackedMount(mountID)
    mountID = tonumber(mountID)

    if not mountID then
        return
    end

    EnsureMountJournalLoaded()

    local details = GetMountDetails(mountID)

    if details and not IsMountAllowedForCharacter(details) then
        Print("That mount is not available to your faction.")
        return
    end

    TrackSelectedMount(mountID)

    if C_MountJournal and C_MountJournal.SummonByID then
        C_MountJournal.SummonByID(mountID)
    end
end

local function FindUsableMountByName(wantedName)
    if not wantedName or wantedName == "" then
        return nil
    end

    EnsureMountJournalLoaded()

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return nil
    end

    local normalizedWanted = NormalizeMountName(wantedName)

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local details = GetMountDetails(mountID)
        local name = details and details.name

        if name
            and details.isCollected
            and IsMountAllowedForCharacter(details)
            and (details.isUsable or IsRecentlyOutOfCombat())
            and NormalizeMountName(name) == normalizedWanted then
            return details.mountID, name
        end
    end

    return nil
end

local function ShouldSkipWaterMountForSurfaceFlying(mountID)
    if not mountID or not IsWaterMount(mountID) then
        return false
    end

    if not (IsPlayerSwimmingAtSurface() or IsFlyableWaterContext()) then
        return false
    end

    return CanFlyHere() == true
end

local function FindServiceMountByName(wantedName)
    if not wantedName or wantedName == "" then
        return nil
    end

    return FindUsableMountByName(wantedName)
end

local function GetRideAlongMountCandidates()
    EnsureMountJournalLoaded()

    local candidates = {}

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return candidates
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local details = GetMountDetails(mountID)
        local name = details and details.name

        if name and details.isCollected and details.isUsable and IsMountAllowedForCharacter(details) and IsRideAlongMountAllowed(name) then
            candidates[#candidates + 1] = details.mountID
        end
    end

    return candidates
end

local function GetRideAlongMountID()
    local db = EnsureDB()
    local preferredName = db and db.preferredServiceMounts and db.preferredServiceMounts.rideAlong

    if preferredName and preferredName ~= "" and IsRideAlongMountAllowed(preferredName) then
        local mountID, mountName = FindServiceMountByName(preferredName)

        if mountID then
            return mountID, mountName
        end
    end

    local mountID = PickMountFromPool(GetRideAlongMountCandidates())
    return mountID, GetMountName(mountID)
end

local function GetPriorityServiceMountID(serviceType)
    local db = EnsureDB()

    if not db then
        return nil
    end

    if serviceType == "rideAlong" then
        return GetRideAlongMountID()
    end

    local preferredName = db.preferredServiceMounts and db.preferredServiceMounts[serviceType]

    if preferredName and preferredName ~= "" then
        local mountID, mountName = FindServiceMountByName(preferredName)

        if mountID then
            return mountID, mountName
        end
    end

    for _, wantedName in ipairs(SERVICE_MOUNT_PRIORITY[serviceType] or {}) do
        local mountID, mountName = FindServiceMountByName(wantedName)

        if mountID then
            return mountID, mountName
        end
    end

    return nil
end

local function AddMountToPools(pools, mountID)
    local isFlying = IsFlyingMount(mountID)
    local isWater = IsWaterMount(mountID)

    pools.all[#pools.all + 1] = mountID

    if isWater then
        pools.water[#pools.water + 1] = mountID
    end

    if not isWater then
        pools.nonWater[#pools.nonWater + 1] = mountID
    end

    if isFlying then
        pools.flying[#pools.flying + 1] = mountID

        if pools.canFly and (pools.isSurface or pools.isFlyableWater) then
            pools.surfaceFlying[#pools.surfaceFlying + 1] = mountID
        end
    elseif not isWater then
        pools.ground[#pools.ground + 1] = mountID
    end
end

local cachedMountPools
local cachedMountPoolsKey

local function InvalidateMountPoolCache()
    cachedMountPools = nil
    cachedMountPoolsKey = nil
    cachedSmartSelectionPool = nil
    cachedSmartSelectionMountID = nil
end

local function GetMountPoolCacheKey(db, canFly, isSurface, isUnderwater, isFlyableWater)
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or 0
    return table.concat({
        tostring(mapID or 0), tostring(canFly == true), tostring(isSurface == true),
        tostring(isUnderwater == true), tostring(isFlyableWater == true),
        tostring(db and db.excludeServiceMountsFromRandom == true),
    }, ":")
end

local function BuildRandomMountPools()
    local db = EnsureDB()

    EnsureMountJournalLoaded()
    UpdateWaterSurfaceState()

    local canFly = CanFlyHere()
    local isSurface = IsPlayerSwimmingAtSurface()
    local isUnderwater = IsPlayerUnderwaterForMounts()
    local isFlyableWater = IsFlyableWaterContext()
    local cacheKey = GetMountPoolCacheKey(db, canFly, isSurface, isUnderwater, isFlyableWater)

    if cachedMountPools and cachedMountPoolsKey == cacheKey then
        return cachedMountPools
    end

    local pools = {
        all = {},
        nonWater = {},
        ground = {},
        flying = {},
        surfaceFlying = {},
        water = {},
        canFly = canFly,
        isSurface = isSurface,
        isUnderwater = isUnderwater,
        isFlyableWater = isFlyableWater,
    }

    if not db or not C_MountJournal or not C_MountJournal.GetMountIDs then
        pools.unavailable = true
        return pools
    end

    local function AddCollectedMounts(requireUsable)
        for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
            local details = GetMountDetails(mountID)

            local allowUnusableWaterMount = pools.isUnderwater and IsWaterMount(details and details.mountID)
            if details
                and details.name
                and details.isCollected
                and IsMountAllowedForCharacter(details)
                and (not requireUsable or details.isUsable or allowUnusableWaterMount)
                and (db.excludeServiceMountsFromRandom ~= true or not IsServiceMountName(details.name)) then
                AddMountToPools(pools, details.mountID)
            end
        end
    end

    AddCollectedMounts(true)

    if #pools.all == 0 then
        AddCollectedMounts(false)
    end

    cachedMountPools = pools
    cachedMountPoolsKey = cacheKey
    return pools
end

BuildRandomMountPools = ns:WrapDiagnosticFunction("Mounts.BuildPools", BuildRandomMountPools)

local function GetPreferredRandomPool(pools)
    local db = EnsureDB()

    if pools.isFlyableWater and pools.canFly and #pools.surfaceFlying > 0 then
        return pools.surfaceFlying
    end

    if pools.isUnderwater and #pools.water > 0 then
        return pools.water
    end

    if pools.isSurface and pools.canFly and #pools.surfaceFlying > 0 then
        return pools.surfaceFlying
    end

    if pools.isSurface and not pools.canFly and db.useWaterMountsOnSurface and #pools.water > 0 then
        return pools.water
    end

    if pools.canFly and #pools.flying > 0 then
        return pools.flying
    end

    if db.preferGroundWhenNotFlyable and #pools.ground > 0 then
        return pools.ground
    end

    if #pools.nonWater > 0 then
        return pools.nonWater
    end

    return {}
end

local function PickStableSmartMount(pool)
    if pool and cachedSmartSelectionPool == pool and cachedSmartSelectionMountID then
        return cachedSmartSelectionMountID
    end

    local mountID = PickMountFromPool(pool)
    cachedSmartSelectionPool = pool
    cachedSmartSelectionMountID = mountID
    return mountID
end

local function PickSmartMountID()
    local db = EnsureDB()

    if not db or db.enabled == false then
        return nil, "Smart mounting is disabled."
    end

    if not IsOutdoors or not IsOutdoors() then
        return nil, "You are indoors."
    end

    local pools = BuildRandomMountPools()

    if pools.unavailable then
        return nil, "Mount journal is unavailable."
    end

    if pools.isFlyableWater and pools.canFly and #pools.surfaceFlying > 0 then
        return PickStableSmartMount(pools.surfaceFlying)
    end

    if pools.isUnderwater and #pools.water > 0 then
        return PickStableSmartMount(pools.water)
    end

    if db.preferredMount and db.preferredMount ~= "" then
        local preferredID = FindUsableMountByName(db.preferredMount)

        if preferredID and not ShouldSkipWaterMountForSurfaceFlying(preferredID) then
            return preferredID
        end
    end

    local pool = GetPreferredRandomPool(pools)

    if not pool or #pool == 0 then
        return nil, "No eligible mounts found."
    end

    return PickStableSmartMount(pool)
end

local SMART_MOUNT_MACRO_PREFIX = "/dismount [mounted]\n/stopmacro [mounted]\n/stopmacro [combat]\n"
local DISMOUNT_MACRO = "/dismount [mounted]\n/stopmacro [mounted]"
local smartButton
local lastSmartUpdateAt = 0
local SMART_UPDATE_MIN_INTERVAL = 0.15

local function BuildChatMessageMacro(message)
    return SMART_MOUNT_MACRO_PREFIX
        .. "/run if ZoidsToolsMounts and ZoidsToolsMounts.Print then ZoidsToolsMounts.Print("
        .. string.format("%q", tostring(message or ""))
        .. ") end"
end

local function ClearSmartButtonAttributes()
    smartButton._ztSmartMountID = nil
    smartButton:SetAttribute("type", nil)
    smartButton:SetAttribute("spell", nil)
    smartButton:SetAttribute("unit", nil)
    smartButton:SetAttribute("macrotext", nil)
end

local function SetSmartButtonMacro(macroText)
    local signature = "macro:" .. tostring(macroText or "")
    if smartButton._ztActionSignature == signature then
        return
    end

    ClearSmartButtonAttributes()
    smartButton._ztSmartMountID = nil
    smartButton:SetAttribute("type", "macro")
    smartButton:SetAttribute("macrotext", macroText)
    smartButton._ztActionSignature = signature
end

local function SetSmartButtonSpell(spellName, unit, mountID)
    local signature = table.concat({ "spell", tostring(spellName or ""), tostring(unit or ""), tostring(mountID or "") }, ":")
    if smartButton._ztActionSignature == signature then
        return
    end

    ClearSmartButtonAttributes()
    smartButton._ztSmartMountID = mountID and tonumber(mountID) or nil
    smartButton:SetAttribute("type", "spell")
    smartButton:SetAttribute("spell", spellName)

    if unit then
        smartButton:SetAttribute("unit", unit)
    end
    smartButton._ztActionSignature = signature
end

local function ApplySmartMountAction()
    local db = EnsureDB()

    if IsMounted and IsMounted() then
        SetSmartButtonMacro(DISMOUNT_MACRO)
        return
    end

    if not db or db.enabled == false then
        SetSmartButtonMacro(BuildChatMessageMacro("Smart mounting is disabled."))
        return
    end

    local class = PlayerClass()

    if not IsOutdoors or not IsOutdoors() then
        if db.useDruidCatForm and class == "DRUID" then
            local catFormName = GetSpellName(DRUID_CAT_FORM_SPELL_ID)

            if catFormName and IsSpellKnownByPlayer(DRUID_CAT_FORM_SPELL_ID) and SpellUsable(DRUID_CAT_FORM_SPELL_ID) then
                SetSmartButtonSpell(catFormName)
                return
            end
        end

        SetSmartButtonMacro(BuildChatMessageMacro("You are indoors."))
        return
    end

    if db.useDruidTravelForm and class == "DRUID" and not IsPlayerUnderwaterForMounts() then
        local travelFormName = GetSpellName(DRUID_TRAVEL_FORM_SPELL_ID)

        if travelFormName and IsSpellKnownByPlayer(DRUID_TRAVEL_FORM_SPELL_ID) and SpellUsable(DRUID_TRAVEL_FORM_SPELL_ID) then
            SetSmartButtonSpell(travelFormName)
            return
        end
    end

    if db.useDracthyrSoar and PlayerRace() == "Dracthyr" and (not IsPlayerUnderwaterForMounts() or IsFlyableWaterContext()) then
        local soarName = GetSpellName(DRACTHYR_SOAR_SPELL_ID)

        if CanFlyHere() and soarName and IsSpellKnownByPlayer(DRACTHYR_SOAR_SPELL_ID) and SpellUsable(DRACTHYR_SOAR_SPELL_ID) then
            SetSmartButtonSpell(soarName)
            return
        end
    end

    local mountID, message = PickSmartMountID()

    if mountID then
        local mountSpellName = GetMountSpellName(mountID)

        if mountSpellName then
            SetSmartButtonSpell(mountSpellName, nil, mountID)
            return
        end
    end

    SetSmartButtonMacro(BuildChatMessageMacro(message or "No usable mount found."))
end

smartButton = CreateFrame("Button", "ZoidsToolsSmartMountButton", UIParent, "SecureActionButtonTemplate")
smartButton:RegisterForClicks("AnyDown", "AnyUp")
smartButton:SetAttribute("type", nil)

local function UpdateSmartButton(force)
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local now = GetTime and GetTime() or 0
    if force ~= true and now > 0 and (now - lastSmartUpdateAt) < SMART_UPDATE_MIN_INTERVAL then
        return
    end
    lastSmartUpdateAt = now

    local fallingAction = GetFallingRescueAction()

    if fallingAction then
        SetSmartButtonSpell(fallingAction.spell, fallingAction.unit)
        return
    end

    ApplySmartMountAction()
end

UpdateSmartButton = ns:WrapDiagnosticFunction("Mounts.UpdateSmartButton", UpdateSmartButton)

local function QueueSmartButtonUpdate(delay)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, UpdateSmartButton)
    else
        UpdateSmartButton()
    end
end

smartButton:SetScript("PreClick", function()
    if IsFalling and IsFalling() then
        UpdateSmartButton(true)
    end
end)

smartButton:SetScript("PostClick", function(self)
    if self._ztSmartMountID then
        TrackSelectedMount(self._ztSmartMountID)
    end

    QueueSmartButtonUpdate(0.1)
end)

local function SummonServiceMount(serviceType)
    if InCombatLockdown and InCombatLockdown() then
        Print("Cannot summon a mount while in combat.")
        return
    end

    local mountID, mountName = GetPriorityServiceMountID(serviceType)

    if mountID then
        SummonTrackedMount(mountID)
        return
    end

    if serviceType == "auctionHouse" then
        Print("No usable auction house mount found.")
    elseif serviceType == "rideAlong" then
        Print("No usable ride-along mount found.")
    else
        Print("No usable repair mount found.")
    end
end

local repairButton = CreateFrame("Button", "ZoidsToolsRepairMountButton", UIParent, "SecureActionButtonTemplate")
repairButton:RegisterForClicks("AnyDown")
repairButton:HookScript("OnClick", function()
    SummonServiceMount("repair")
end)

local auctionHouseButton = CreateFrame("Button", "ZoidsToolsAuctionHouseMountButton", UIParent, "SecureActionButtonTemplate")
auctionHouseButton:RegisterForClicks("AnyDown")
auctionHouseButton:HookScript("OnClick", function()
    SummonServiceMount("auctionHouse")
end)

local rideAlongButton = CreateFrame("Button", "ZoidsToolsRideAlongMountButton", UIParent, "SecureActionButtonTemplate")
rideAlongButton:RegisterForClicks("AnyDown")
rideAlongButton:HookScript("OnClick", function()
    SummonServiceMount("rideAlong")
end)

function ns:GetMountsEnabled()
    local db = EnsureDB()
    return db and db.enabled == true
end

function ns:SetMountsEnabled(value)
    local db = EnsureDB()

    if db then
        db.enabled = value == true
        UpdateSmartButton()
    end
end

function ns:GetPreferredMountName()
    local db = EnsureDB()
    return db and db.preferredMount or nil
end

function ns:SetPreferredMountName(name)
    local db = EnsureDB()

    if db then
        db.preferredMount = name ~= "" and name or nil
        UpdateSmartButton()
    end
end

function ns:GetPreferredServiceMount(serviceType)
    local db = EnsureDB()
    return db and db.preferredServiceMounts and db.preferredServiceMounts[serviceType] or nil
end

function ns:SetPreferredServiceMount(serviceType, name)
    local db = EnsureDB()

    if db and db.preferredServiceMounts then
        db.preferredServiceMounts[serviceType] = name ~= "" and name or nil
        UpdateSmartButton()
    end
end

function ns:GetMountRecentAvoidCount()
    local db = EnsureDB()
    return db and db.recentAvoidCount or 0
end

function ns:SetMountRecentAvoidCount(value)
    local db = EnsureDB()

    if db then
        value = tonumber(value) or 0
        db.recentAvoidCount = math.max(0, math.min(10, math.floor(value + 0.5)))
        UpdateSmartButton()
    end
end

function ns:GetMountOption(key)
    local db = EnsureDB()
    return db and db[key] == true
end

function ns:SetMountOption(key, value)
    local db = EnsureDB()

    if db then
        db[key] = value == true
        UpdateSmartButton()
    end
end

function ns:GetMountClassOption(key)
    local db = EnsureDB()
    return db and db[key] == true
end

function ns:SetMountClassOption(key, value)
    local db = EnsureDB()

    if db then
        db[key] = value == true
        UpdateSmartButton()
    end
end

function ns:GetMountMatchEnabled()
    local db = EnsureDB()
    return db and db.targetMatchEnabled == true
end

function ns:SetMountMatchEnabled(value)
    local db = EnsureDB()

    if db then
        db.targetMatchEnabled = value == true
        UpdateTargetMatchButton()
    end
end

function ns:GetTargetMountMatch()
    return GetTargetMountMatch()
end

function ns:GetTargetMatchButtonShown()
    local db = EnsureDB()
    return db and db.targetMatchButton and db.targetMatchButton.shown == true
end

function ns:SetTargetMatchButtonShown(value)
    local db = EnsureDB()

    if db and db.targetMatchButton then
        db.targetMatchButton.shown = value == true
        CreateTargetMatchButton()
        UpdateTargetMatchButton()
    end
end

function ns:ClearMountRecentHistory()
    local db = EnsureDB()

    if db then
        db.recentMounts = {}
        Print("Recent mount history cleared.")
        UpdateSmartButton()
    end
end

function ns:GetCollectedMountSearch(query, limit)
    EnsureMountJournalLoaded()

    local mounts = {}
    query = NormalizeMountName(query)
    limit = limit or 5

    if query == "" or not C_MountJournal or not C_MountJournal.GetMountIDs then
        return mounts
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local details = GetMountDetails(mountID)
        local name = details and details.name

        if name and details.isCollected and IsMountAllowedForCharacter(details) and string.find(NormalizeMountName(name), query, 1, true) then
            mounts[#mounts + 1] = {
                id = details.mountID,
                name = name,
            }
        end
    end

    table.sort(mounts, function(a, b)
        return a.name < b.name
    end)

    while #mounts > limit do
        table.remove(mounts)
    end

    return mounts
end

function ns:GetMountServiceOptions(serviceType)
    EnsureMountJournalLoaded()

    local options = {
        { value = "", text = "Default Priority" },
    }
    local seen = {}

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return options
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local details = GetMountDetails(mountID)
        local name = details and details.name

        if name and details.isCollected and details.isUsable and IsMountAllowedForCharacter(details) then
            local normalized = NormalizeMountName(name)
            local matchesService = false

            if serviceType == "rideAlong" then
                matchesService = GetRideAlongMountPool(name) ~= nil
            else
                for _, wantedName in ipairs(SERVICE_MOUNT_PRIORITY[serviceType] or {}) do
                    if normalized == NormalizeMountName(wantedName) then
                        matchesService = true
                        break
                    end
                end
            end

            if matchesService and not seen[normalized] then
                seen[normalized] = true
                options[#options + 1] = {
                    value = name,
                    text = name,
                }
            end
        end
    end

    table.sort(options, function(a, b)
        if a.value == "" then
            return true
        elseif b.value == "" then
            return false
        end

        return a.text < b.text
    end)

    return options
end

function ns:GetMountStatusText()
    local db = EnsureDB()
    local recentCount = db and db.recentMounts and #db.recentMounts or 0
    local lastName = db and db.lastMountID and GetMountName(db.lastMountID) or nil

    if lastName then
        return "Last: " .. lastName .. "\nRecent: " .. tostring(recentCount)
    end

    return "Recent: " .. tostring(recentCount)
end

function API.SummonMount(mountID)
    SummonTrackedMount(mountID)
end

function API.Print(message)
    Print(message)
end

function API.SummonSmartMount()
    local mountID, message = PickSmartMountID()

    if mountID then
        SummonTrackedMount(mountID)
    else
        Print(message or "No usable mount found.")
    end
end

function API.SummonServiceMount(serviceType)
    SummonServiceMount(serviceType)
end

function API.GetTargetMountMatch()
    return GetTargetMountMatch()
end

function API.MatchTargetMount()
    local db = EnsureDB()

    if not db or db.targetMatchEnabled == false then
        Print("Target mount matching is disabled.")
        return false
    end

    if IsPlayerInCombat() then
        Print("Cannot match target mount while in combat.")
        return false
    end

    local match = GetTargetMountMatch()

    if not match or not match.available or not match.mountID then
        Print(match and match.status or "No target mount match found.")
        return false
    end

    local activeMountID = GetActiveMountID()

    if activeMountID and tonumber(activeMountID) == tonumber(match.mountID) then
        Print("Already using target mount: " .. tostring(match.mountName or match.mountID) .. ".")
        return true
    end

    SummonTrackedMount(match.mountID)
    Print("Matching target mount: " .. tostring(match.mountName or match.mountID) .. ".")
    UpdateTargetMatchButton()
    return true
end

function ns:RefreshMountButtons()
    UpdateSmartButton()
    UpdateTargetMatchButton()
end

function ns:InitializeMounts()
    EnsureDB()
    RebuildMountAuraLookup()
    UpdateSmartButton()
    CreateTargetMatchButton()
    UpdateTargetMatchButton()

    if initialized then
        return
    end

    initialized = true

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
    eventFrame:RegisterEvent("NEW_MOUNT_ADDED")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:RegisterEvent("PLAYER_STARTED_MOVING")
    eventFrame:RegisterEvent("PLAYER_STOPPED_MOVING")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        EnsureDB()

        if event == "PLAYER_ENTERING_WORLD"
            or event == "NEW_MOUNT_ADDED"
        then
            InvalidateMountPoolCache()
        end

        if event == "PLAYER_REGEN_DISABLED" then
            lastCombatEndedAt = 0
            HideTargetMatchButtonForCombat()
            return
        end

        if IsPlayerInCombat() then
            return
        end

        UpdateWaterSurfaceState()

        if event == "PLAYER_REGEN_ENABLED" then
            lastCombatEndedAt = GetTime and GetTime() or 0
            QueueSmartButtonUpdate(0.05)
            QueueSmartButtonUpdate(0.25)
            QueueSmartButtonUpdate(0.75)
        elseif event == "NEW_MOUNT_ADDED" then
            RebuildMountAuraLookup()
        elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
            QueueSmartButtonUpdate(0.05)
        end

        UpdateSmartButton()
    end)
end
