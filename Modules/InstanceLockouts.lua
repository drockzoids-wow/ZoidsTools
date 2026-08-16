local _, ns = ...

local PANEL_NAME = "ZoidsToolsInstanceLockoutPanel"
local PANEL_WIDTH = 304
local PANEL_MINIMIZED_WIDTH = 184
local PANEL_MINIMIZED_HEIGHT = 42
local PANEL_MIN_HEIGHT = 360
local PANEL_GAP = 8
local RATING_SUMMARY_WIDTH = 128
local BEST_RUN_COLUMN_WIDTH = 58
local RESET_COLUMN_WIDTH = 66
local COLUMN_GAP = 4
local ROW_RIGHT_INSET = 7
local MYTHIC_DUNGEON_DIFFICULTY_ID = 23
local GROUP_FINDER_CATEGORY_ID_DUNGEONS = 2

local panel
local eventFrame
local updateQueued = false
local catalogReady = false
local pveWasShown = false
local pveHooksInstalled = false
local lfgListHooksInstalled = false
local currentExpansionName = "Current Expansion"
local currentCatalog = {
    instanceIDs = {},
    journalInstanceIDs = {},
    names = {},
}

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function SafeNumber(value)
    if not IsSecretValue(value) and type(value) == "number" then
        return value
    end
    return nil
end

local function SafeBoolean(value)
    if not IsSecretValue(value) and type(value) == "boolean" then
        return value
    end
    return nil
end

local function SafeString(value)
    if not IsSecretValue(value) and type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function NormalizeName(value)
    value = SafeString(value)
    if not value then
        return nil
    end

    return value:lower():gsub("[%s%p]", "")
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.instanceLockouts = ns.db.instanceLockouts or {}
    local db = ns.db.instanceLockouts
    if db.enabled == nil then
        db.enabled = true
    end
    if db.legacyExpanded == nil then
        db.legacyExpanded = false
    end
    if db.minimized == nil then
        db.minimized = false
    end
    if db.excludeLockedDungeons == nil then
        db.excludeLockedDungeons = false
    end
    if type(db.autoExcludedDungeonGroups) ~= "table" then
        db.autoExcludedDungeonGroups = {}
    end
    return db
end

local function EmptyCatalog()
    currentCatalog.instanceIDs = {}
    currentCatalog.journalInstanceIDs = {}
    currentCatalog.names = {}
    catalogReady = false
end

local function RebuildCurrentExpansionCatalog()
    EmptyCatalog()

    if type(EJ_GetNumTiers) ~= "function"
        or type(EJ_GetCurrentTier) ~= "function"
        or type(EJ_GetTierInfo) ~= "function"
        or type(EJ_SelectTier) ~= "function"
        or type(EJ_GetInstanceByIndex) ~= "function" then
        return false
    end

    local ok, numTiers = pcall(EJ_GetNumTiers)
    numTiers = ok and SafeNumber(numTiers) or nil
    if not numTiers or numTiers < 1 then
        return false
    end
    numTiers = math.floor(numTiers)

    local previousTier
    ok, previousTier = pcall(EJ_GetCurrentTier)
    previousTier = ok and SafeNumber(previousTier) or nil

    local tierName
    ok, tierName = pcall(EJ_GetTierInfo, numTiers)
    tierName = ok and SafeString(tierName) or nil
    if tierName then
        currentExpansionName = tierName
    else
        local expansionLevel
        if type(GetExpansionLevel) == "function" then
            ok, expansionLevel = pcall(GetExpansionLevel)
            expansionLevel = ok and SafeNumber(expansionLevel) or nil
        end
        local expansionName = expansionLevel and SafeString(_G["EXPANSION_NAME" .. expansionLevel])
        currentExpansionName = expansionName or "Current Expansion"
    end

    ok = pcall(EJ_SelectTier, numTiers)
    if not ok then
        return false
    end

    local found = 0
    for _, isRaid in ipairs({ false, true }) do
        for index = 1, 200 do
            local callOK, journalInstanceID, instanceName, _, _, _, _, _, _,
                _, _, gameMapID = pcall(EJ_GetInstanceByIndex, index, isRaid)
            if not callOK then
                break
            end

            journalInstanceID = SafeNumber(journalInstanceID)
            if not journalInstanceID then
                break
            end

            currentCatalog.journalInstanceIDs[journalInstanceID] = true
            found = found + 1

            gameMapID = SafeNumber(gameMapID)
            if gameMapID then
                currentCatalog.instanceIDs[gameMapID] = true
            end

            local normalizedName = NormalizeName(instanceName)
            if normalizedName then
                currentCatalog.names[normalizedName] = true
            end
        end
    end

    if previousTier and previousTier >= 1 and previousTier <= numTiers and previousTier ~= numTiers then
        pcall(EJ_SelectTier, previousTier)
    end

    catalogReady = found > 0
    return catalogReady
end

local function IsCurrentExpansionInstance(info)
    if not info then
        return false
    end

    if info.instanceID and currentCatalog.instanceIDs[info.instanceID] then
        return true
    end

    if info.instanceID and C_EncounterJournal
        and type(C_EncounterJournal.GetInstanceForGameMap) == "function" then
        local ok, journalInstanceID = pcall(C_EncounterJournal.GetInstanceForGameMap, info.instanceID)
        journalInstanceID = ok and SafeNumber(journalInstanceID) or nil
        if journalInstanceID and currentCatalog.journalInstanceIDs[journalInstanceID] then
            return true
        end
    end

    -- The saved-instance API supplies a game-map InstanceID on modern
    -- clients. When that authoritative ID is present but does not match the
    -- current journal tier, do not let a reused localized name misclassify an
    -- older version of the instance.
    if info.instanceID then
        return false
    end

    local normalizedName = NormalizeName(info.name)
    return normalizedName and currentCatalog.names[normalizedName] == true or false
end

local function FormatResetTime(seconds)
    seconds = SafeNumber(seconds)
    if not seconds or seconds <= 0 then
        return "Resetting"
    end

    seconds = math.floor(seconds)
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end
    return string.format("%dm", math.max(1, minutes))
end

local function GetCurrentMythicPlusRating()
    if not C_PlayerInfo
        or type(C_PlayerInfo.GetPlayerMythicPlusRatingSummary) ~= "function" then
        return 0
    end

    local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
    if not ok or IsSecretValue(summary) or type(summary) ~= "table" then
        return 0
    end

    local score = SafeNumber(summary.currentSeasonScore)
    return score and math.max(0, math.floor(score + 0.5)) or 0
end

local function RecordBestRun(bestByMapID, bestByName, mapID, level)
    mapID = SafeNumber(mapID)
    level = SafeNumber(level)
    if not mapID or not level or level < 2 or level > 40 then
        return
    end

    level = math.floor(level)
    bestByMapID[mapID] = math.max(bestByMapID[mapID] or 0, level)

    if C_ChallengeMode and type(C_ChallengeMode.GetMapUIInfo) == "function" then
        local ok, mapName = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
        local normalizedName = ok and NormalizeName(mapName) or nil
        if normalizedName then
            bestByName[normalizedName] = math.max(bestByName[normalizedName] or 0, level)
        end
    end
end

local function GetCurrentSeasonBestRuns()
    local bestByMapID = {}
    local bestByName = {}

    if not C_MythicPlus or type(C_MythicPlus.GetRunHistory) ~= "function" then
        return bestByMapID, bestByName
    end

    local ok, runs = pcall(C_MythicPlus.GetRunHistory, true, false, true)
    if not ok or IsSecretValue(runs) or type(runs) ~= "table" then
        return bestByMapID, bestByName
    end

    for _, run in ipairs(runs) do
        if not IsSecretValue(run) and type(run) == "table" then
            local completed = SafeBoolean(run.completed)
            if completed ~= false then
                RecordBestRun(bestByMapID, bestByName, run.mapChallengeModeID, run.level)
            end
        end
    end
    return bestByMapID, bestByName
end

local function AddMythicPlusProgress(lockouts)
    if not lockouts then
        return
    end

    local _, bestByName = GetCurrentSeasonBestRuns()
    for _, info in ipairs(lockouts.currentDungeons or {}) do
        local normalizedName = NormalizeName(info.name)
        info.bestRunLevel = normalizedName and bestByName[normalizedName] or nil
    end
end

local function GetDifficultyName(difficultyID, providedName)
    providedName = SafeString(providedName)
    if providedName then
        return providedName
    end

    if difficultyID and type(GetDifficultyInfo) == "function" then
        local ok, name = pcall(GetDifficultyInfo, difficultyID)
        name = ok and SafeString(name) or nil
        if name then
            return name
        end
    end
    return "Unknown difficulty"
end

local function GetSavedEncounters(instanceIndex, numEncounters)
    local encounters = {}
    local killedCount = 0

    if type(GetSavedInstanceEncounterInfo) ~= "function" then
        return encounters, nil
    end

    numEncounters = SafeNumber(numEncounters)
    if not numEncounters then
        return encounters, nil
    end
    numEncounters = math.min(100, math.max(0, math.floor(numEncounters)))

    for encounterIndex = 1, numEncounters do
        local ok, bossName, iconFileID, isKilled = pcall(
            GetSavedInstanceEncounterInfo,
            instanceIndex,
            encounterIndex
        )
        bossName = ok and SafeString(bossName) or nil
        isKilled = ok and SafeBoolean(isKilled) or nil
        if bossName then
            encounters[#encounters + 1] = {
                name = bossName,
                iconFileID = SafeNumber(iconFileID),
                killed = isKilled == true,
            }
            if isKilled == true then
                killedCount = killedCount + 1
            end
        end
    end

    return encounters, #encounters > 0 and killedCount or nil
end

local function SortLockouts(left, right)
    if left.name ~= right.name then
        return left.name < right.name
    end
    if left.difficultyID ~= right.difficultyID then
        return left.difficultyID < right.difficultyID
    end
    return left.reset < right.reset
end

local function ReadSavedLockouts()
    if not catalogReady then
        RebuildCurrentExpansionCatalog()
    end

    local result = {
        currentDungeons = {},
        currentRaids = {},
        legacyDungeons = {},
        legacyRaids = {},
    }

    if type(GetNumSavedInstances) ~= "function" or type(GetSavedInstanceInfo) ~= "function" then
        return result
    end

    local ok, count = pcall(GetNumSavedInstances)
    count = ok and SafeNumber(count) or nil
    if not count then
        return result
    end
    count = math.min(500, math.max(0, math.floor(count)))

    for index = 1, count do
        local callOK, name, lockoutID, reset, difficultyID, locked, extended,
            _, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress,
            extendDisabled, instanceID = pcall(GetSavedInstanceInfo, index)

        name = callOK and SafeString(name) or nil
        reset = callOK and SafeNumber(reset) or nil
        difficultyID = callOK and SafeNumber(difficultyID) or nil
        locked = callOK and SafeBoolean(locked) or nil
        isRaid = callOK and SafeBoolean(isRaid) or nil

        if name and reset and reset > 0 and locked == true and difficultyID
            and (isRaid == true or difficultyID == MYTHIC_DUNGEON_DIFFICULTY_ID) then
            local encounters, killedCount = GetSavedEncounters(index, numEncounters)
            local totalEncounters = SafeNumber(numEncounters) or #encounters
            local progress = killedCount
                or SafeNumber(encounterProgress)
                or 0

            local info = {
                index = index,
                name = name,
                lockoutID = SafeNumber(lockoutID),
                reset = reset,
                difficultyID = difficultyID,
                difficultyName = GetDifficultyName(difficultyID, difficultyName),
                extended = SafeBoolean(extended) == true,
                extendDisabled = SafeBoolean(extendDisabled) == true,
                isRaid = isRaid == true,
                maxPlayers = SafeNumber(maxPlayers),
                numEncounters = math.max(0, math.floor(totalEncounters)),
                progress = math.max(0, math.floor(progress)),
                instanceID = SafeNumber(instanceID),
                encounters = encounters,
            }

            local current = IsCurrentExpansionInstance(info)
            local destination
            if info.isRaid then
                destination = current and result.currentRaids or result.legacyRaids
            else
                destination = current and result.currentDungeons or result.legacyDungeons
            end
            destination[#destination + 1] = info
        end
    end

    for _, list in pairs(result) do
        table.sort(list, SortLockouts)
    end
    return result
end

local function GetAvailableDungeonGroupIDs()
    if not C_LFGList or type(C_LFGList.GetAvailableActivityGroups) ~= "function"
        or not Enum or not Enum.LFGListFilter or not bit or type(bit.bor) ~= "function" then
        return {}, {}
    end

    local filterValues = Enum.LFGListFilter
    local ordered = {}
    local available = {}

    local function AddGroups(...)
        local mask = 0
        for index = 1, select("#", ...) do
            local value = SafeNumber(select(index, ...))
            if not value then
                return
            end
            mask = bit.bor(mask, value)
        end

        local ok, groups = pcall(
            C_LFGList.GetAvailableActivityGroups,
            GROUP_FINDER_CATEGORY_ID_DUNGEONS,
            mask
        )
        if not ok or type(groups) ~= "table" then
            return
        end

        for _, value in ipairs(groups) do
            local groupID = SafeNumber(value)
            if groupID and not available[groupID] then
                available[groupID] = true
                ordered[#ordered + 1] = groupID
            end
        end
    end

    AddGroups(filterValues.CurrentSeason, filterValues.PvE)
    AddGroups(filterValues.CurrentExpansion, filterValues.NotCurrentSeason, filterValues.PvE)

    local timerunning = false
    if type(PlayerIsTimerunning) == "function" then
        local ok, result = pcall(PlayerIsTimerunning)
        timerunning = ok and SafeBoolean(result) == true
    end
    if timerunning then
        AddGroups(filterValues.Timerunning, filterValues.PvE)
    end

    return ordered, available
end

local function GetLockedDungeonGroupIDs(lockouts, availableGroupIDs)
    local lockedNames = {}
    for _, listName in ipairs({ "currentDungeons", "legacyDungeons" }) do
        for _, info in ipairs(lockouts[listName] or {}) do
            local normalizedName = NormalizeName(info.name)
            if normalizedName then
                lockedNames[normalizedName] = true
            end
        end
    end

    local lockedGroups = {}
    if not next(lockedNames) or not C_LFGList
        or type(C_LFGList.GetActivityGroupInfo) ~= "function" then
        return lockedGroups
    end

    for _, groupID in ipairs(availableGroupIDs) do
        local ok, groupName = pcall(C_LFGList.GetActivityGroupInfo, groupID)
        local normalizedName = ok and NormalizeName(groupName) or nil
        if normalizedName and lockedNames[normalizedName] then
            lockedGroups[groupID] = true
        end
    end
    return lockedGroups
end

local function SyncLockedDungeonFilters(lockouts)
    local db = EnsureDB()
    if not db or not C_LFGList or type(C_LFGList.GetAdvancedFilter) ~= "function"
        or type(C_LFGList.SaveAdvancedFilter) ~= "function" then
        return false
    end

    local availableGroupIDs, availableGroups = GetAvailableDungeonGroupIDs()
    if #availableGroupIDs == 0 then
        return false
    end

    lockouts = lockouts or ReadSavedLockouts()
    local lockedGroups = db.excludeLockedDungeons == true
        and GetLockedDungeonGroupIDs(lockouts, availableGroupIDs)
        or {}

    local ok, advancedFilter = pcall(C_LFGList.GetAdvancedFilter)
    if not ok or type(advancedFilter) ~= "table" then
        return false
    end

    local activities = type(advancedFilter.activities) == "table"
        and advancedFilter.activities
        or {}
    local selected = {}
    local defaultAll = #activities == 0
    if defaultAll then
        for _, groupID in ipairs(availableGroupIDs) do
            selected[groupID] = true
        end
    else
        for _, value in ipairs(activities) do
            local groupID = SafeNumber(value)
            if groupID then
                selected[groupID] = true
            end
        end
    end

    local tracked = {}
    for key, value in pairs(db.autoExcludedDungeonGroups) do
        if value == true then
            tracked[tostring(key)] = true
        end
    end

    local filterChanged = false
    for key in pairs(tracked) do
        local groupID = tonumber(key)
        if not groupID or not availableGroups[groupID] then
            tracked[key] = nil
        elseif db.excludeLockedDungeons ~= true or not lockedGroups[groupID] then
            if not selected[groupID] then
                selected[groupID] = true
                filterChanged = true
            end
            tracked[key] = nil
        end
    end

    if db.excludeLockedDungeons == true then
        for groupID in pairs(lockedGroups) do
            if selected[groupID] then
                selected[groupID] = nil
                tracked[tostring(groupID)] = true
                filterChanged = true
            end
        end
    end

    local newActivities = {}
    local emitted = {}
    for _, groupID in ipairs(availableGroupIDs) do
        if selected[groupID] then
            newActivities[#newActivities + 1] = groupID
            emitted[groupID] = true
        end
    end
    for _, value in ipairs(activities) do
        local groupID = SafeNumber(value)
        if groupID and selected[groupID] and not emitted[groupID] then
            newActivities[#newActivities + 1] = groupID
            emitted[groupID] = true
        end
    end

    if filterChanged and #newActivities == 0 then
        -- Blizzard treats an empty activity list as "all checked." If every
        -- available dungeon is locked, retain one entry instead of silently
        -- turning every dungeon back on.
        local fallbackGroupID = availableGroupIDs[1]
        newActivities[1] = fallbackGroupID
        tracked[tostring(fallbackGroupID)] = nil
    end

    if filterChanged then
        advancedFilter.activities = newActivities
        local saved = pcall(C_LFGList.SaveAdvancedFilter, advancedFilter)
        if not saved then
            return false
        end
    end

    db.autoExcludedDungeonGroups = tracked
    return filterChanged
end

local function SetTextStyle(fontString, size, r, g, b, justify)
    fontString:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
    fontString:SetTextColor(r, g, b)
    fontString:SetJustifyH(justify or "LEFT")
    fontString:SetJustifyV("MIDDLE")
    fontString:SetWordWrap(false)
end

local function ShowLockoutTooltip(row)
    local info = row and row.info
    if not info or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(info.name, 1, 0.82, 0.18)
    GameTooltip:AddDoubleLine(info.difficultyName, FormatResetTime(info.reset), 1, 1, 1, 0.75, 0.82, 1)

    if info.numEncounters > 0 then
        GameTooltip:AddLine(string.format("Bosses defeated: %d/%d", info.progress, info.numEncounters), 0.85, 0.85, 0.85)
    else
        GameTooltip:AddLine("Weekly Mythic lockout active", 0.85, 0.85, 0.85)
    end

    if info.extended then
        GameTooltip:AddLine("Extended lockout", 1, 0.55, 0.20)
    end

    if #info.encounters > 0 then
        GameTooltip:AddLine(" ")
        for _, encounter in ipairs(info.encounters) do
            local marker = encounter.killed and "|cff55dd88- Defeated|r" or "|cff888888- Available|r"
            GameTooltip:AddDoubleLine(encounter.name, marker, 1, 1, 1, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function CreateLockoutRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(40)
    row:EnableMouse(true)

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetColorTexture(1, 1, 1, 0.035)

    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT", 0, -3)
    row.accent:SetPoint("BOTTOMLEFT", 0, 3)
    row.accent:SetWidth(3)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetHeight(17)
    SetTextStyle(row.name, 12, 0.95, 0.95, 0.95, "LEFT")

    row.bestRun = row:CreateFontString(nil, "OVERLAY")
    row.bestRun:SetSize(BEST_RUN_COLUMN_WIDTH, 17)
    SetTextStyle(row.bestRun, 10, 0.95, 0.72, 0.18, "CENTER")

    row.reset = row:CreateFontString(nil, "OVERLAY")
    row.reset:SetPoint("TOPRIGHT", -ROW_RIGHT_INSET, -4)
    row.reset:SetSize(RESET_COLUMN_WIDTH, 17)
    SetTextStyle(row.reset, 10, 0.58, 0.72, 0.95, "RIGHT")

    row.detail = row:CreateFontString(nil, "OVERLAY")
    row.detail:SetHeight(15)
    SetTextStyle(row.detail, 10, 0.62, 0.62, 0.65, "LEFT")

    row:SetScript("OnEnter", function(self)
        self.background:SetColorTexture(0.90, 0.68, 0.16, 0.10)
        ShowLockoutTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        self.background:SetColorTexture(1, 1, 1, 0.035)
        GameTooltip:Hide()
    end)
    return row
end

local function AcquireLabel(style)
    panel.labelPool[style] = panel.labelPool[style] or {}
    local pool = panel.labelPool[style]
    local index = (panel.labelUse[style] or 0) + 1
    panel.labelUse[style] = index

    local label = pool[index]
    if not label then
        label = panel.content:CreateFontString(nil, "OVERLAY")
        pool[index] = label
    end
    label:Show()
    label:ClearAllPoints()
    return label
end

local function AddLabel(style, text, y, height)
    local label = AcquireLabel(style)
    label:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 4, y)
    label:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -4, y)
    label:SetHeight(height)

    if style == "expansion" then
        SetTextStyle(label, 12, 0.95, 0.72, 0.18, "LEFT")
    elseif style == "section" then
        SetTextStyle(label, 11, 0.95, 0.72, 0.18, "LEFT")
    elseif style == "empty" then
        SetTextStyle(label, 11, 0.52, 0.52, 0.56, "LEFT")
    else
        SetTextStyle(label, 11, 0.75, 0.75, 0.78, "LEFT")
    end
    label:SetText(text)
    return y - height, label
end

local function AddSectionHeader(text, y, showBestRun)
    local label = AcquireLabel("section")
    local rightReserve = RESET_COLUMN_WIDTH + ROW_RIGHT_INSET
    if showBestRun then
        rightReserve = rightReserve + BEST_RUN_COLUMN_WIDTH + COLUMN_GAP
    end
    label:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 4, y)
    label:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -rightReserve, y)
    label:SetHeight(20)
    SetTextStyle(label, 11, 0.95, 0.72, 0.18, "LEFT")
    label:SetText(text)

    if showBestRun then
        local bestHeader = AcquireLabel("bestRunHeader")
        bestHeader:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -(RESET_COLUMN_WIDTH + ROW_RIGHT_INSET + COLUMN_GAP), y)
        bestHeader:SetSize(BEST_RUN_COLUMN_WIDTH, 20)
        SetTextStyle(bestHeader, 9, 0.95, 0.72, 0.18, "CENTER")
        bestHeader:SetText("BEST RUN")
    end

    local resetHeader = AcquireLabel("resetHeader")
    resetHeader:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -ROW_RIGHT_INSET, y)
    resetHeader:SetSize(RESET_COLUMN_WIDTH, 20)
    SetTextStyle(resetHeader, 9, 0.58, 0.72, 0.95, "RIGHT")
    resetHeader:SetText("RESET")
    return y - 20
end

local function AcquireRow()
    panel.rowUse = panel.rowUse + 1
    local row = panel.rowPool[panel.rowUse]
    if not row then
        row = CreateLockoutRow(panel.content)
        panel.rowPool[panel.rowUse] = row
    end
    row:Show()
    row:ClearAllPoints()
    return row
end

local function AddLockoutRows(list, emptyText, y, legacy, showBestRun)
    if #list == 0 then
        return AddLabel("empty", emptyText, y, 22) - 2
    end

    for _, info in ipairs(list) do
        local row = AcquireRow()
        row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 2, y)
        row:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -2, y)
        row.info = info
        row.name:SetText(info.name)
        row.reset:SetText(FormatResetTime(info.reset))

        local rightReserve = RESET_COLUMN_WIDTH + ROW_RIGHT_INSET
        if showBestRun then
            rightReserve = rightReserve + BEST_RUN_COLUMN_WIDTH + COLUMN_GAP
            row.bestRun:ClearAllPoints()
            row.bestRun:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(RESET_COLUMN_WIDTH + ROW_RIGHT_INSET + COLUMN_GAP), -4)
            row.bestRun:SetText(string.format("+%d", info.bestRunLevel or 0))
            row.bestRun:Show()
        else
            row.bestRun:Hide()
        end

        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", 10, -4)
        row.name:SetPoint("TOPRIGHT", -rightReserve, -4)
        row.detail:ClearAllPoints()
        row.detail:SetPoint("BOTTOMLEFT", 10, 4)
        row.detail:SetPoint("BOTTOMRIGHT", -rightReserve, 4)

        local detail
        if info.numEncounters > 0 then
            detail = string.format("%s  |  %d/%d bosses", info.difficultyName, info.progress, info.numEncounters)
        else
            detail = string.format("%s  |  Weekly lockout", info.difficultyName)
        end
        if info.extended then
            detail = detail .. "  |cffff8a42Extended|r"
        end
        row.detail:SetText(detail)

        if legacy then
            row.accent:SetColorTexture(0.48, 0.48, 0.52, 0.9)
        elseif info.isRaid then
            row.accent:SetColorTexture(0.94, 0.60, 0.14, 0.95)
        else
            row.accent:SetColorTexture(0.20, 0.62, 0.92, 0.95)
        end
        y = y - 43
    end
    return y
end

local function HideUnusedElements()
    for style, pool in pairs(panel.labelPool) do
        local used = panel.labelUse[style] or 0
        for index = used + 1, #pool do
            pool[index]:Hide()
        end
    end
    for index = panel.rowUse + 1, #panel.rowPool do
        panel.rowPool[index].info = nil
        panel.rowPool[index]:Hide()
    end
end

local function RenderLockouts(lockouts)
    if not panel then
        return
    end

    panel.lockouts = lockouts or ReadSavedLockouts()
    lockouts = panel.lockouts
    panel.labelUse = {}
    panel.rowUse = 0

    local y = -5
    local expansionY = y
    local expansionLabel
    y, expansionLabel = AddLabel("expansion", currentExpansionName, y, 24)
    expansionLabel:ClearAllPoints()
    expansionLabel:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 4, expansionY)
    expansionLabel:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -(RATING_SUMMARY_WIDTH + 8), expansionY)

    panel.ratingSummary:ClearAllPoints()
    panel.ratingSummary:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -4, expansionY)
    panel.ratingSummary:SetSize(RATING_SUMMARY_WIDTH, 24)
    panel.ratingSummary:SetText(string.format("M+ RATING  |cffffffff%d|r", GetCurrentMythicPlusRating()))
    panel.ratingSummary:Show()

    y = AddSectionHeader("MYTHIC DUNGEONS", y, true)
    y = AddLockoutRows(lockouts.currentDungeons, "No current Mythic dungeon lockouts.", y, false, true)
    y = y - 6
    y = AddSectionHeader("RAIDS", y, false)
    y = AddLockoutRows(lockouts.currentRaids, "No current raid lockouts.", y, false)
    y = y - 9

    local db = EnsureDB()
    local legacyExpanded = db and db.legacyExpanded == true
    local legacyCount = #lockouts.legacyDungeons + #lockouts.legacyRaids
    panel.legacyToggle:ClearAllPoints()
    panel.legacyToggle:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 2, y)
    panel.legacyToggle:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -2, y)
    panel.legacyToggle.text:SetText(string.format(
        "%s LEGACY EXPANSIONS  (%d)",
        legacyExpanded and "-" or "+",
        legacyCount
    ))
    panel.legacyToggle:Show()
    y = y - 31

    if legacyExpanded then
        y = AddSectionHeader("MYTHIC DUNGEONS", y, false)
        y = AddLockoutRows(lockouts.legacyDungeons, "No legacy Mythic dungeon lockouts.", y, true)
        y = y - 6
        y = AddSectionHeader("RAIDS", y, false)
        y = AddLockoutRows(lockouts.legacyRaids, "No legacy raid lockouts.", y, true)
    end

    HideUnusedElements()
    panel.content:SetHeight(math.max(1, -y + 10))
end

local function RefreshLockouts()
    if not panel then
        return
    end

    local lockouts = ReadSavedLockouts()
    AddMythicPlusProgress(lockouts)
    RenderLockouts(lockouts)
    SyncLockedDungeonFilters(lockouts)
end

local function ScheduleRefresh(delay)
    if updateQueued then
        return
    end

    updateQueued = true
    local function Run()
        updateQueued = false
        RefreshLockouts()
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(tonumber(delay) or 0.05, Run)
    else
        Run()
    end
end

local function RequestLockoutData()
    if type(RequestRaidInfo) == "function" then
        pcall(RequestRaidInfo)
    end
    if C_MythicPlus and type(C_MythicPlus.RequestMapInfo) == "function" then
        pcall(C_MythicPlus.RequestMapInfo)
    end
    ScheduleRefresh(0.10)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.75, function()
            ScheduleRefresh(0)
        end)
    end
end

local ApplyPanelDisplayState

local function CreatePanel()
    if panel then
        return panel
    end

    panel = CreateFrame("Frame", PANEL_NAME, UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, 510)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 13,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.018, 0.020, 0.026, 0.97)
    panel:SetBackdropBorderColor(0.78, 0.58, 0.18, 0.95)

    panel.header = panel:CreateTexture(nil, "BACKGROUND")
    panel.header:SetPoint("TOPLEFT", 4, -4)
    panel.header:SetPoint("TOPRIGHT", -4, -4)
    panel.header:SetHeight(42)
    panel.header:SetColorTexture(0.10, 0.105, 0.12, 0.98)

    panel.title = panel:CreateFontString(nil, "OVERLAY")
    panel.title:SetPoint("TOPLEFT", 14, -8)
    panel.title:SetPoint("TOPRIGHT", -100, -8)
    panel.title:SetHeight(18)
    SetTextStyle(panel.title, 14, 1, 0.80, 0.22, "LEFT")
    panel.title:SetText("INSTANCE LOCKOUTS")

    panel.subtitle = panel:CreateFontString(nil, "OVERLAY")
    panel.subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -1)
    panel.subtitle:SetPoint("TOPRIGHT", panel.title, "BOTTOMRIGHT", 0, -1)
    panel.subtitle:SetHeight(14)
    SetTextStyle(panel.subtitle, 9, 0.56, 0.56, 0.60, "LEFT")
    panel.subtitle:SetText("Mythic dungeons and saved raids")

    panel.refreshButton = CreateFrame("Button", nil, panel)
    panel.refreshButton:SetPoint("TOPRIGHT", -38, -11)
    panel.refreshButton:SetSize(56, 22)
    panel.refreshButton.background = panel.refreshButton:CreateTexture(nil, "BACKGROUND")
    panel.refreshButton.background:SetAllPoints()
    panel.refreshButton.background:SetColorTexture(0.16, 0.16, 0.18, 0.95)
    panel.refreshButton.text = panel.refreshButton:CreateFontString(nil, "OVERLAY")
    panel.refreshButton.text:SetAllPoints()
    SetTextStyle(panel.refreshButton.text, 10, 0.92, 0.92, 0.92, "CENTER")
    panel.refreshButton.text:SetText("Refresh")
    panel.refreshButton:SetScript("OnEnter", function(self)
        self.background:SetColorTexture(0.30, 0.24, 0.10, 0.95)
    end)
    panel.refreshButton:SetScript("OnLeave", function(self)
        self.background:SetColorTexture(0.16, 0.16, 0.18, 0.95)
    end)
    panel.refreshButton:SetScript("OnClick", RequestLockoutData)

    panel.minimizeButton = CreateFrame("Button", nil, panel)
    panel.minimizeButton:SetPoint("TOPRIGHT", -10, -11)
    panel.minimizeButton:SetSize(22, 22)
    panel.minimizeButton.background = panel.minimizeButton:CreateTexture(nil, "BACKGROUND")
    panel.minimizeButton.background:SetAllPoints()
    panel.minimizeButton.background:SetColorTexture(0.16, 0.16, 0.18, 0.95)
    panel.minimizeButton.text = panel.minimizeButton:CreateFontString(nil, "OVERLAY")
    panel.minimizeButton.text:SetAllPoints()
    SetTextStyle(panel.minimizeButton.text, 13, 0.92, 0.92, 0.92, "CENTER")
    panel.minimizeButton.text:SetText("-")
    panel.minimizeButton:SetScript("OnEnter", function(self)
        self.background:SetColorTexture(0.30, 0.24, 0.10, 0.95)
    end)
    panel.minimizeButton:SetScript("OnLeave", function(self)
        self.background:SetColorTexture(0.16, 0.16, 0.18, 0.95)
    end)
    panel.minimizeButton:SetScript("OnClick", function()
        local db = EnsureDB()
        if not db then
            return
        end
        db.minimized = not db.minimized
        ApplyPanelDisplayState()
    end)

    panel.scroll = CreateFrame("ScrollFrame", nil, panel)
    panel.scroll:SetPoint("TOPLEFT", 12, -53)
    panel.scroll:SetPoint("BOTTOMRIGHT", -12, 12)
    panel.scroll:SetClipsChildren(true)
    panel.scroll:EnableMouseWheel(true)

    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.content:SetSize(PANEL_WIDTH - 24, 1)
    panel.scroll:SetScrollChild(panel.content)

    panel.ratingSummary = panel.content:CreateFontString(nil, "OVERLAY")
    SetTextStyle(panel.ratingSummary, 10, 0.95, 0.72, 0.18, "RIGHT")
    panel.scroll:SetScript("OnSizeChanged", function(self, width)
        width = SafeNumber(width)
        if width then
            panel.content:SetWidth(math.max(1, width))
        end
    end)
    panel.scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = SafeNumber(self:GetVerticalScroll()) or 0
        local range = SafeNumber(self:GetVerticalScrollRange()) or 0
        delta = SafeNumber(delta) or 0
        self:SetVerticalScroll(math.max(0, math.min(range, current - delta * 36)))
    end)

    panel.labelPool = {}
    panel.labelUse = {}
    panel.rowPool = {}
    panel.rowUse = 0

    panel.legacyToggle = CreateFrame("Button", nil, panel.content)
    panel.legacyToggle:SetHeight(27)
    panel.legacyToggle.background = panel.legacyToggle:CreateTexture(nil, "BACKGROUND")
    panel.legacyToggle.background:SetAllPoints()
    panel.legacyToggle.background:SetColorTexture(0.12, 0.12, 0.14, 0.96)
    panel.legacyToggle.text = panel.legacyToggle:CreateFontString(nil, "OVERLAY")
    panel.legacyToggle.text:SetPoint("LEFT", 9, 0)
    panel.legacyToggle.text:SetPoint("RIGHT", -9, 0)
    panel.legacyToggle.text:SetHeight(20)
    SetTextStyle(panel.legacyToggle.text, 10, 0.72, 0.72, 0.76, "LEFT")
    panel.legacyToggle:SetScript("OnEnter", function(self)
        self.background:SetColorTexture(0.22, 0.18, 0.08, 0.96)
    end)
    panel.legacyToggle:SetScript("OnLeave", function(self)
        self.background:SetColorTexture(0.12, 0.12, 0.14, 0.96)
    end)
    panel.legacyToggle:SetScript("OnClick", function()
        local db = EnsureDB()
        if not db then
            return
        end
        db.legacyExpanded = not db.legacyExpanded
        panel.scroll:SetVerticalScroll(0)
        RenderLockouts(panel.lockouts)
    end)

    ApplyPanelDisplayState()
    panel:Hide()
    return panel
end

ApplyPanelDisplayState = function()
    local db = EnsureDB()
    if not panel or not db then
        return
    end

    local minimized = db.minimized == true
    panel.title:ClearAllPoints()
    panel.title:SetPoint("TOPLEFT", 14, minimized and -11 or -8)
    panel.title:SetPoint("TOPRIGHT", minimized and -40 or -100, minimized and -11 or -8)
    panel.header:SetHeight(minimized and 34 or 42)

    if minimized then
        panel:SetSize(PANEL_MINIMIZED_WIDTH, PANEL_MINIMIZED_HEIGHT)
        panel.title:SetText("LOCKOUTS")
        panel.subtitle:Hide()
        panel.refreshButton:Hide()
        panel.scroll:Hide()
        panel.minimizeButton.text:SetText("+")
    else
        panel:SetSize(PANEL_WIDTH, panel.expandedHeight or 510)
        panel.title:SetText("INSTANCE LOCKOUTS")
        panel.subtitle:Show()
        panel.refreshButton:Show()
        panel.scroll:Show()
        panel.minimizeButton.text:SetText("-")
    end
end

local function PositionPanel()
    local pveFrame = _G.PVEFrame
    if not panel or not pveFrame or not pveFrame.GetRight or not pveFrame.GetHeight then
        return false
    end

    local right = SafeNumber(pveFrame:GetRight())
    local pveHeight = SafeNumber(pveFrame:GetHeight())
    local pveScale = pveFrame.GetEffectiveScale and SafeNumber(pveFrame:GetEffectiveScale())
    local panelScale = panel.GetEffectiveScale and SafeNumber(panel:GetEffectiveScale())
    local screenRight = UIParent and UIParent.GetRight and SafeNumber(UIParent:GetRight())
    if not pveHeight then
        return false
    end

    -- PVEFrame and this UIParent-level panel can use different effective
    -- scales. Convert Blizzard's height into the panel's coordinate space so
    -- both frames have the same visible height on screen.
    if pveScale and panelScale and panelScale > 0 then
        pveHeight = pveHeight * pveScale / panelScale
    end
    panel.expandedHeight = math.max(PANEL_MIN_HEIGHT, pveHeight)
    panel:ClearAllPoints()
    if right and screenRight and right + PANEL_GAP + PANEL_WIDTH <= screenRight - 4 then
        panel.anchorSide = "RIGHT"
        panel:SetPoint("TOPLEFT", pveFrame, "TOPRIGHT", PANEL_GAP, 0)
    else
        panel.anchorSide = "LEFT"
        panel:SetPoint("TOPRIGHT", pveFrame, "TOPLEFT", -PANEL_GAP, 0)
    end
    ApplyPanelDisplayState()
    return true
end

local function IsPVEFrameShown()
    local pveFrame = _G.PVEFrame
    if not pveFrame or type(pveFrame.IsShown) ~= "function" then
        return false
    end

    local ok, shown = pcall(pveFrame.IsShown, pveFrame)
    if not ok or SafeBoolean(shown) ~= true then
        return false
    end

    -- PVEFrame's second top-level tab is Player vs. Player. Keep the lockout
    -- panel on the Dungeons & Raids and Mythic+ views where it is relevant.
    local activeTabIndex = SafeNumber(pveFrame.activeTabIndex)
    return activeTabIndex == nil or activeTabIndex ~= 2
end

local function SyncPanelVisibility()
    local db = EnsureDB()
    if not db or db.enabled ~= true then
        if panel and panel:IsShown() then
            panel:Hide()
        end
        pveWasShown = false
        return
    end

    local shown = IsPVEFrameShown()
    if shown then
        CreatePanel()
        PositionPanel()
        if not pveWasShown then
            panel:Show()
            RebuildCurrentExpansionCatalog()
            RequestLockoutData()
        elseif not panel:IsShown() then
            panel:Show()
        end
    elseif panel and panel:IsShown() then
        panel:Hide()
    end
    pveWasShown = shown
end

local function InstallPVEHooks()
    if pveHooksInstalled then
        return true
    end

    local pveFrame = _G.PVEFrame
    if not pveFrame then
        return false
    end

    local function SyncAfterBlizzardUpdate()
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0, SyncPanelVisibility)
        else
            SyncPanelVisibility()
        end
    end

    if type(pveFrame.HookScript) == "function" then
        pveFrame:HookScript("OnShow", SyncAfterBlizzardUpdate)
        pveFrame:HookScript("OnSizeChanged", SyncAfterBlizzardUpdate)
        pveFrame:HookScript("OnHide", function()
            pveWasShown = false
            if panel and panel:IsShown() then
                panel:Hide()
            end
        end)
    end

    if type(hooksecurefunc) == "function" and type(_G.PVEFrame_ShowFrame) == "function" then
        hooksecurefunc("PVEFrame_ShowFrame", SyncPanelVisibility)
    end

    pveHooksInstalled = true
    return true
end

local function InstallLFGListHooks()
    if lfgListHooksInstalled then
        return true
    end
    if type(hooksecurefunc) ~= "function"
        or type(_G.LFGListSearchPanel_SetCategory) ~= "function" then
        return false
    end

    hooksecurefunc("LFGListSearchPanel_SetCategory", function(_, categoryID)
        if SafeNumber(categoryID) == GROUP_FINDER_CATEGORY_ID_DUNGEONS then
            SyncLockedDungeonFilters()
        end
    end)
    lfgListHooksInstalled = true
    return true
end

function ns:IsInstanceLockoutPanelEnabled()
    local db = EnsureDB()
    return db and db.enabled == true
end

function ns:SetInstanceLockoutPanelEnabled(value)
    local db = EnsureDB()
    if not db then
        return
    end

    db.enabled = value == true
    CreatePanel()
    SyncPanelVisibility()
end

function ns:IsLockedDungeonFilterEnabled()
    local db = EnsureDB()
    return db and db.excludeLockedDungeons == true
end

function ns:SetLockedDungeonFilterEnabled(value)
    local db = EnsureDB()
    if not db then
        return
    end

    db.excludeLockedDungeons = value == true
    SyncLockedDungeonFilters()
end

function ns:RefreshInstanceLockouts()
    if not catalogReady then
        RebuildCurrentExpansionCatalog()
    end
    RequestLockoutData()
end

function ns:InitializeInstanceLockouts()
    EnsureDB()
    CreatePanel()
    RebuildCurrentExpansionCatalog()

    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UPDATE_EXPANSION_LEVEL")
    eventFrame:RegisterEvent("UPDATE_INSTANCE_INFO")
    eventFrame:RegisterEvent("BOSS_KILL")
    eventFrame:RegisterEvent("ENCOUNTER_END")
    eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    eventFrame:SetScript("OnEvent", function(_, event, addonName)
        if event == "ADDON_LOADED" then
            if addonName == "Blizzard_EncounterJournal" then
                RebuildCurrentExpansionCatalog()
                ScheduleRefresh(0)
            elseif addonName == "Blizzard_GroupFinder" then
                InstallPVEHooks()
                InstallLFGListHooks()
                SyncPanelVisibility()
            end
            return
        end

        if event == "UPDATE_EXPANSION_LEVEL" then
            RebuildCurrentExpansionCatalog()
            ScheduleRefresh(0)
        end

        if event == "PLAYER_ENTERING_WORLD" or event == "BOSS_KILL"
            or event == "ENCOUNTER_END" or event == "PLAYER_DIFFICULTY_CHANGED" then
            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(1, RequestLockoutData)
            else
                RequestLockoutData()
            end
        elseif event == "UPDATE_INSTANCE_INFO" then
            ScheduleRefresh(0)
        end
    end)

    InstallPVEHooks()
    InstallLFGListHooks()
    SyncPanelVisibility()
end
