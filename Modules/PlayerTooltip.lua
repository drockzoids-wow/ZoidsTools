local _, ns = ...

local initialized = false
local eventFrame
local pendingInspect
local lastInspectRequest = 0
local itemLevelCache = {}
local activeTooltipGUID
local activeTooltipUnit

local ITEM_LEVEL_CACHE_LIFETIME = 60
local INSPECT_REQUEST_COOLDOWN = 1.5
local INSPECT_REQUEST_TIMEOUT = 3
local ITEM_LEVEL_CACHE_LIMIT = 80

local function IsTooltipOptionEnabled(key)
    local settings = ns.db and ns.db.tooltips

    return type(settings) ~= "table" or settings[key] ~= false
end

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

local function GetNow()
    return GetTime and GetTime() or 0
end

local function IsCombatLocked()
    if not InCombatLockdown then
        return false
    end

    local ok, locked = pcall(InCombatLockdown)

    return ok and not IsSecretValue(locked) and locked == true
end

local function UnitIsPlayerSafe(unit)
    if not unit or not UnitIsPlayer then
        return false
    end

    local ok, isPlayer = pcall(UnitIsPlayer, unit)

    return ok and not IsSecretValue(isPlayer) and isPlayer == true
end

local function UnitIsUnitSafe(unit, otherUnit)
    if not unit or not otherUnit or not UnitIsUnit then
        return false
    end

    local ok, isUnit = pcall(UnitIsUnit, unit, otherUnit)

    return ok and not IsSecretValue(isUnit) and isUnit == true
end

local function GetUnitGUIDSafe(unit)
    if not unit or not UnitGUID then
        return nil
    end

    local ok, guid = pcall(UnitGUID, unit)

    if not ok or IsSecretValue(guid) or type(guid) ~= "string" or guid == "" then
        return nil
    end

    return guid
end

local function GetUnitClassColor(unit)
    if not unit or not UnitClass or not CreateColor then
        return nil
    end

    local ok, _, classFile = pcall(UnitClass, unit)

    if not ok or IsSecretValue(classFile) or type(classFile) ~= "string" then
        return nil
    end

    local color = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])

    if not color then
        return nil
    end

    local r, g, b

    if type(color.GetRGB) == "function" then
        local colorOK
        colorOK, r, g, b = pcall(color.GetRGB, color)

        if not colorOK then
            return nil
        end
    else
        r, g, b = color.r, color.g, color.b
    end

    if IsSecretValue(r)
        or IsSecretValue(g)
        or IsSecretValue(b)
        or type(r) ~= "number"
        or type(g) ~= "number"
        or type(b) ~= "number"
    then
        return nil
    end

    return CreateColor(r, g, b)
end

local function FormatWholeNumber(value)
    if IsSecretValue(value) or type(value) ~= "number" or value <= 0 then
        return nil
    end

    return tostring(math.floor(value + 0.5))
end

local function GetMythicPlusScore(unit)
    if not unit
        or not C_PlayerInfo
        or type(C_PlayerInfo.GetPlayerMythicPlusRatingSummary) ~= "function"
    then
        return nil
    end

    local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)

    if not ok or IsSecretValue(summary) or type(summary) ~= "table" then
        return nil
    end

    local score = summary.currentSeasonScore

    if IsSecretValue(score) or type(score) ~= "number" or score <= 0 then
        return nil
    end

    return score
end

local function GetMythicPlusScoreColor(score)
    if not score
        or not C_ChallengeMode
        or type(C_ChallengeMode.GetDungeonScoreRarityColor) ~= "function"
    then
        return nil
    end

    local ok, color = pcall(C_ChallengeMode.GetDungeonScoreRarityColor, score)

    if not ok or not color or type(color.WrapTextInColorCode) ~= "function" then
        return nil
    end

    return color
end

local function ColorText(text, color)
    if not text or not color or type(color.WrapTextInColorCode) ~= "function" then
        return text
    end

    local ok, coloredText = pcall(color.WrapTextInColorCode, color, text)

    if ok and not IsSecretValue(coloredText) and type(coloredText) == "string" then
        return coloredText
    end

    return text
end

local function PruneItemLevelCache()
    local now = GetNow()
    local count = 0

    for guid, cached in pairs(itemLevelCache) do
        if type(cached) ~= "table"
            or type(cached.time) ~= "number"
            or (now > 0 and (now - cached.time) > ITEM_LEVEL_CACHE_LIFETIME)
        then
            itemLevelCache[guid] = nil
        else
            count = count + 1
        end
    end

    if count > ITEM_LEVEL_CACHE_LIMIT then
        wipe(itemLevelCache)
    end
end

local function CacheItemLevel(guid, itemLevel)
    if not guid
        or IsSecretValue(guid)
        or IsSecretValue(itemLevel)
        or type(itemLevel) ~= "number"
        or itemLevel <= 0
    then
        return
    end

    itemLevelCache[guid] = {
        itemLevel = itemLevel,
        time = GetNow(),
    }

    PruneItemLevelCache()
end

local function GetCachedItemLevel(guid)
    if not guid or IsSecretValue(guid) then
        return nil
    end

    local cached = itemLevelCache[guid]

    if type(cached) ~= "table"
        or type(cached.itemLevel) ~= "number"
        or type(cached.time) ~= "number"
    then
        return nil
    end

    local now = GetNow()

    if now > 0 and (now - cached.time) > ITEM_LEVEL_CACHE_LIFETIME then
        itemLevelCache[guid] = nil
        return nil
    end

    return cached.itemLevel
end

local function GetPlayerItemLevel()
    if not GetAverageItemLevel then
        return nil
    end

    local ok, overall, equipped = pcall(GetAverageItemLevel)

    if not ok or IsSecretValue(overall) or IsSecretValue(equipped) then
        return nil
    end

    if type(equipped) == "number" and equipped > 0 then
        return equipped
    end

    if type(overall) == "number" and overall > 0 then
        return overall
    end

    return nil
end

local function GetInspectedItemLevel(unit)
    if not unit
        or not C_PaperDollInfo
        or type(C_PaperDollInfo.GetInspectItemLevel) ~= "function"
    then
        return nil
    end

    local ok, itemLevel = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)

    if not ok
        or IsSecretValue(itemLevel)
        or type(itemLevel) ~= "number"
        or itemLevel <= 0
    then
        return nil
    end

    return itemLevel
end

local function IsInspectUIBusy()
    if InspectFrame and type(InspectFrame.IsShown) == "function" then
        local ok, shown = pcall(InspectFrame.IsShown, InspectFrame)

        if ok and not IsSecretValue(shown) and shown == true then
            return true
        end
    end

    if PlayerSpellsFrame and type(PlayerSpellsFrame.IsInspecting) == "function" then
        local ok, inspecting = pcall(PlayerSpellsFrame.IsInspecting, PlayerSpellsFrame)

        if ok and not IsSecretValue(inspecting) and inspecting == true then
            return true
        end
    end

    return false
end

local function RequestItemLevelInspect(unit, guid)
    if not unit
        or not guid
        or IsSecretValue(guid)
        or UnitIsUnitSafe(unit, "player")
        or IsCombatLocked()
        or IsInspectUIBusy()
        or not CanInspect
        or not NotifyInspect
    then
        return false
    end

    local now = GetNow()

    if pendingInspect then
        if pendingInspect.guid == guid then
            return true
        end

        if type(pendingInspect.time) == "number"
            and (now - pendingInspect.time) < INSPECT_REQUEST_TIMEOUT
        then
            return false
        end

        pendingInspect = nil
    end

    if (now - lastInspectRequest) < INSPECT_REQUEST_COOLDOWN then
        return false
    end

    local canInspectOK, canInspect = pcall(CanInspect, unit)

    if not canInspectOK or IsSecretValue(canInspect) or canInspect ~= true then
        return false
    end

    local inspectOK = pcall(NotifyInspect, unit)

    if not inspectOK then
        return false
    end

    pendingInspect = {
        guid = guid,
        unit = unit,
        time = now,
    }
    lastInspectRequest = now

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(INSPECT_REQUEST_TIMEOUT, function()
            if pendingInspect
                and pendingInspect.guid == guid
                and pendingInspect.time == now
            then
                pendingInspect = nil
            end
        end)
    end

    return true
end

local function GetUnitItemLevel(unit, guid)
    if UnitIsUnitSafe(unit, "player") then
        return GetPlayerItemLevel(), false
    end

    local cached = GetCachedItemLevel(guid)

    if cached then
        return cached, false
    end

    local itemLevel = GetInspectedItemLevel(unit)

    if itemLevel then
        CacheItemLevel(guid, itemLevel)
        return itemLevel, false
    end

    return nil, RequestItemLevelInspect(unit, guid)
end

local function BuildPlayerDetails(unit, guid)
    local leftRows = {}
    local rightRows = {}

    if IsTooltipOptionEnabled("showMythicScore") then
        local score = GetMythicPlusScore(unit)
        local scoreText = FormatWholeNumber(score)

        if scoreText then
            table.insert(leftRows, "M+ Rating")
            table.insert(
                rightRows,
                ColorText(scoreText, GetMythicPlusScoreColor(score))
            )
        end
    end

    if IsTooltipOptionEnabled("showItemLevel") then
        local itemLevel, inspecting = GetUnitItemLevel(unit, guid)
        local itemLevelText = FormatWholeNumber(itemLevel)
        local itemLevelValue

        if itemLevelText then
            itemLevelValue = "|cffffffff" .. itemLevelText .. "|r"
        elseif inspecting then
            itemLevelValue = "|cff888888...|r"
        end

        if itemLevelValue then
            table.insert(leftRows, "|cffffd100Item Level|r")
            table.insert(rightRows, itemLevelValue)
        end
    end

    if #leftRows == 0 then
        return nil, nil
    end

    return table.concat(leftRows, "\n"), table.concat(rightRows, "\n")
end

local function FindPlayerNameLine(lines)
    for _, lineData in ipairs(lines) do
        if type(lineData) == "table" then
            local lineType = lineData.type

            if not IsSecretValue(lineType)
                and lineType == Enum.TooltipDataLineType.UnitName
            then
                return lineData
            end
        end
    end

    return nil
end

local function FindDetailsTargetLine(lines, nameLine)
    local lastTextLine

    for index = #lines, 1, -1 do
        local lineData = lines[index]

        if type(lineData) == "table" and lineData ~= nameLine then
            local lineType = lineData.type
            local leftText = lineData.leftText
            local rightText = lineData.rightText

            if IsSecretValue(lineType)
                or IsSecretValue(leftText)
                or IsSecretValue(rightText)
            then
                return nil, false
            end

            if lineType == Enum.TooltipDataLineType.Blank then
                return lineData, true
            end

            if type(leftText) == "string" and leftText ~= "" then
                lastTextLine = lineData
                break
            end
        end
    end

    return lastTextLine, false
end

local function PlacePlayerDetailsBelow(lines, nameLine, leftDetails, rightDetails)
    if not leftDetails then
        return
    end

    local targetLine, isBlankLine = FindDetailsTargetLine(lines, nameLine)

    if not targetLine then
        return
    end

    local existingLeftText = targetLine.leftText
    local existingRightText = targetLine.rightText

    if IsSecretValue(existingLeftText) or IsSecretValue(existingRightText) then
        return
    end

    if isBlankLine then
        targetLine.leftText = "\n" .. leftDetails

        if rightDetails then
            targetLine.rightText = "\n" .. rightDetails
        end
    else
        targetLine.leftText = existingLeftText .. "\n\n" .. leftDetails

        if rightDetails then
            local rightPrefix = type(existingRightText) == "string" and existingRightText or ""
            targetLine.rightText = rightPrefix .. "\n\n" .. rightDetails
        end
    end
end

local function ApplyPlayerTooltipData(tooltip, tooltipData)
    if tooltip ~= GameTooltip
        or IsSecretValue(tooltipData)
        or type(tooltipData) ~= "table"
        or IsSecretValue(tooltipData.lines)
        or type(tooltipData.lines) ~= "table"
    then
        return
    end

    local lines = tooltipData.lines
    local nameLine = FindPlayerNameLine(lines)
    local unit = nameLine and nameLine.unitToken

    if IsSecretValue(unit) or type(unit) ~= "string" or not UnitIsPlayerSafe(unit) then
        return
    end

    local guid = GetUnitGUIDSafe(unit)

    if not guid then
        return
    end

    activeTooltipGUID = guid
    activeTooltipUnit = unit

    local leftDetails, rightDetails = BuildPlayerDetails(unit, guid)
    PlacePlayerDetailsBelow(lines, nameLine, leftDetails, rightDetails)
end

local function ClearActivePlayerTooltip(tooltip)
    if tooltip == GameTooltip then
        activeTooltipGUID = nil
        activeTooltipUnit = nil
    end
end

local function RefreshActivePlayerTooltip(guid, unit)
    local tooltipUnit = activeTooltipUnit

    if activeTooltipGUID ~= guid
        or not tooltipUnit
        or GetUnitGUIDSafe(tooltipUnit) ~= guid
        or GetUnitGUIDSafe(unit) ~= guid
        or IsCombatLocked()
        or not GameTooltip
        or type(GameTooltip.IsShown) ~= "function"
        or type(GameTooltip.IsTooltipType) ~= "function"
        or type(GameTooltip.SetUnit) ~= "function"
        or not Enum
        or not Enum.TooltipDataType
        or not Enum.TooltipDataType.Unit
    then
        return
    end

    local shownOK, shown = pcall(GameTooltip.IsShown, GameTooltip)
    local typeOK, isUnitTooltip = pcall(
        GameTooltip.IsTooltipType,
        GameTooltip,
        Enum.TooltipDataType.Unit
    )

    if not shownOK
        or IsSecretValue(shown)
        or shown ~= true
        or not typeOK
        or IsSecretValue(isUnitTooltip)
        or isUnitTooltip ~= true
    then
        return
    end

    -- SetUnit is Blizzard's secure tooltip-data delegate for addon callers. It
    -- rebuilds this same tooltip from the current unit without editing its lines.
    pcall(GameTooltip.SetUnit, GameTooltip, tooltipUnit)
end

local function CachePendingInspect(guid)
    if not pendingInspect
        or not guid
        or IsSecretValue(guid)
        or pendingInspect.guid ~= guid
    then
        return
    end

    local unit = pendingInspect.unit

    local itemLevelCached = false

    if GetUnitGUIDSafe(unit) == guid then
        local itemLevel = GetInspectedItemLevel(unit)

        if itemLevel then
            CacheItemLevel(guid, itemLevel)
            itemLevelCached = true
        end
    end

    pendingInspect = nil

    if itemLevelCached then
        RefreshActivePlayerTooltip(guid, unit)
    end
end

local function PrefetchMouseoverItemLevel()
    local unit = "mouseover"

    if not IsTooltipOptionEnabled("showItemLevel")
        or not UnitIsPlayerSafe(unit)
        or UnitIsUnitSafe(unit, "player")
    then
        return
    end

    local guid = GetUnitGUIDSafe(unit)

    if not guid or GetCachedItemLevel(guid) then
        return
    end

    local itemLevel = GetInspectedItemLevel(unit)

    if itemLevel then
        CacheItemLevel(guid, itemLevel)
        RefreshActivePlayerTooltip(guid, unit)
    else
        RequestItemLevelInspect(unit, guid)
    end
end

local function ApplyPlayerNameColor(tooltip, lineData)
    if tooltip ~= GameTooltip
        or type(lineData) ~= "table"
        or not IsTooltipOptionEnabled("classColoredNames")
    then
        return
    end

    local unit = lineData.unitToken

    if IsSecretValue(unit) or type(unit) ~= "string" or not UnitIsPlayerSafe(unit) then
        return
    end

    local classColor = GetUnitClassColor(unit)

    if classColor then
        -- Blizzard assigns the default name color through this same field.
        -- Replace only that value before Blizzard creates the tooltip line.
        lineData.leftColor = classColor
    end

end

local function SetTooltipOption(key, value)
    local settings = ns.db and ns.db.tooltips

    if type(settings) ~= "table" then
        return
    end

    settings[key] = value == true

    if activeTooltipGUID and activeTooltipUnit then
        RefreshActivePlayerTooltip(activeTooltipGUID, activeTooltipUnit)
    end
end

function ns:IsTooltipClassColoredNamesEnabled()
    return IsTooltipOptionEnabled("classColoredNames")
end

function ns:SetTooltipClassColoredNamesEnabled(value)
    SetTooltipOption("classColoredNames", value)
end

function ns:IsTooltipMythicScoreEnabled()
    return IsTooltipOptionEnabled("showMythicScore")
end

function ns:SetTooltipMythicScoreEnabled(value)
    SetTooltipOption("showMythicScore", value)
end

function ns:IsTooltipItemLevelEnabled()
    return IsTooltipOptionEnabled("showItemLevel")
end

function ns:SetTooltipItemLevelEnabled(value)
    SetTooltipOption("showItemLevel", value)
end

function ns:InitializePlayerTooltip()
    if initialized then
        return
    end

    if not TooltipDataProcessor
        or type(TooltipDataProcessor.AddLinePreCall) ~= "function"
        or not Enum
        or not Enum.TooltipDataLineType
        or not Enum.TooltipDataLineType.UnitName
    then
        return
    end

    initialized = true

    if type(TooltipDataProcessor.AddTooltipPreCall) == "function"
        and Enum.TooltipDataType
        and Enum.TooltipDataType.Unit
    then
        TooltipDataProcessor.AddTooltipPreCall(
            TooltipDataProcessor.AllTypes,
            ClearActivePlayerTooltip
        )
        TooltipDataProcessor.AddTooltipPreCall(
            Enum.TooltipDataType.Unit,
            ApplyPlayerTooltipData
        )
    end

    TooltipDataProcessor.AddLinePreCall(
        Enum.TooltipDataLineType.UnitName,
        ApplyPlayerNameColor
    )

    if CreateFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("INSPECT_READY")
        eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        eventFrame:SetScript("OnEvent", function(_, event, guid)
            if event == "INSPECT_READY" then
                CachePendingInspect(guid)
            elseif event == "UPDATE_MOUSEOVER_UNIT" then
                PrefetchMouseoverItemLevel()
            end
        end)
    end
end
