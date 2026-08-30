local _, ns = ...

local PANEL_NAME = "ZoidsToolsInstanceLockoutPanel"
local PANEL_WIDTH = 396
local PANEL_MINIMIZED_WIDTH = 36
local PANEL_MINIMIZED_HEIGHT = 36
local PANEL_BORDER_BUTTON_X_OFFSET = -3
local PANEL_BORDER_BUTTON_TOP_OFFSET = -43
local PANEL_MIN_HEIGHT = 360
local PANEL_GAP = 8
local RATING_SUMMARY_WIDTH = 116
local AFFIX_ICON_SIZE = 26
local AFFIX_ICON_GAP = 3
local WEEKLY_RUN_COLUMN_WIDTH = 44
local SEASON_RUN_COLUMN_WIDTH = 48
local LOCK_COLUMN_WIDTH = 52
local RESET_COLUMN_WIDTH = 62
local COLUMN_GAP = 3
local ROW_RIGHT_INSET = 7
local MYTHIC_DUNGEON_DIFFICULTY_ID = 23
local GROUP_FINDER_DUNGEON_CATEGORY_ID = 2

local panel
local eventFrame
local updateQueued = false
local catalogReady = false
local pveWasShown = false
local pveHooksInstalled = false
local positionSyncQueued = false
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

local function SecureCallBlizzard(func, ...)
    if type(securecallfunction) ~= "function" or type(func) ~= "function" then
        return false
    end

    return pcall(securecallfunction, func, ...)
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
    if db.sortColumn ~= "week" and db.sortColumn ~= "season" then
        db.sortColumn = "name"
    end
    if db.sortDirection ~= "desc" then
        db.sortDirection = "asc"
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

local function FormatBestRunLevel(level)
    level = SafeNumber(level)
    if not level then
        return "—"
    elseif level >= 2 then
        return string.format("+%d", math.floor(level))
    elseif level == 0 then
        return "+0"
    end
    return "—"
end

local function GetCurrentMythicPlusRating()
    if C_ChallengeMode
        and type(C_ChallengeMode.GetOverallDungeonScore) == "function" then
        local ok, score = pcall(C_ChallengeMode.GetOverallDungeonScore)
        score = ok and SafeNumber(score) or nil
        if score then
            return math.max(0, math.floor(score + 0.5))
        end
    end

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

local function GetMythicPlusRatingColorCode(score)
    local r, g, b = 1, 1, 1
    if C_ChallengeMode
        and type(C_ChallengeMode.GetDungeonScoreRarityColor) == "function" then
        local ok, color = pcall(C_ChallengeMode.GetDungeonScoreRarityColor, score)
        if ok and not IsSecretValue(color) and type(color) == "table" then
            r = SafeNumber(color.r) or r
            g = SafeNumber(color.g) or g
            b = SafeNumber(color.b) or b
        end
    end

    local function ToByte(value)
        return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
    end
    return string.format("|cff%02x%02x%02x", ToByte(r), ToByte(g), ToByte(b))
end

local function AddTooltipTitle(tooltip, text)
    if type(GameTooltip_SetTitle) == "function" then
        GameTooltip_SetTitle(tooltip, text)
    else
        tooltip:SetText(text, 1, 1, 1)
    end
end

local function AddTooltipNormalLine(tooltip, text)
    if type(GameTooltip_AddNormalLine) == "function" then
        GameTooltip_AddNormalLine(tooltip, text)
    else
        tooltip:AddLine(text, 1, 0.82, 0, true)
    end
end

local function AddTooltipColoredLine(tooltip, text, color)
    if type(GameTooltip_AddColoredLine) == "function" and color then
        GameTooltip_AddColoredLine(tooltip, text, color)
    else
        tooltip:AddLine(text, color and color.r or 0.20, color and color.g or 1, color and color.b or 0.20, true)
    end
end

local function AddTooltipBlankLine(tooltip)
    if type(GameTooltip_AddBlankLineToTooltip) == "function" then
        GameTooltip_AddBlankLineToTooltip(tooltip)
    else
        tooltip:AddLine(" ")
    end
end

local function ShowMythicPlusRatingTooltip(owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", 0, 0)
    AddTooltipTitle(GameTooltip, DUNGEON_SCORE or "Mythic+ Rating")
    AddTooltipNormalLine(GameTooltip, DUNGEON_SCORE_DESC or "An overall score based on your best run for each dungeon.")
    GameTooltip:Show()
end

local function ShowGreatVaultTooltip(owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", 0, 0)
    AddTooltipTitle(GameTooltip, GREAT_VAULT_REWARDS or "Great Vault Rewards")

    local hasAvailableRewards = false
    if C_WeeklyRewards and type(C_WeeklyRewards.HasAvailableRewards) == "function" then
        local ok, available = pcall(C_WeeklyRewards.HasAvailableRewards)
        hasAvailableRewards = ok and SafeBoolean(available) == true
    end
    if hasAvailableRewards then
        AddTooltipColoredLine(GameTooltip, GREAT_VAULT_REWARDS_WAITING or "You have rewards waiting in the Great Vault.", GREEN_FONT_COLOR)
        AddTooltipBlankLine(GameTooltip)
    end

    local lastCompletedActivityInfo
    local nextActivityInfo
    if WeeklyRewardsUtil and type(WeeklyRewardsUtil.GetActivitiesProgress) == "function" then
        local ok, lastCompleted, nextActivity = pcall(WeeklyRewardsUtil.GetActivitiesProgress)
        if ok then
            lastCompletedActivityInfo = lastCompleted
            nextActivityInfo = nextActivity
        end
    end

    if not lastCompletedActivityInfo then
        AddTooltipNormalLine(GameTooltip, GREAT_VAULT_REWARDS_MYTHIC_INCOMPLETE or "Complete Mythic dungeons to unlock a Great Vault reward.")
    elseif nextActivityInfo then
        local lastIndex = SafeNumber(lastCompletedActivityInfo.index) or 1
        local threshold = SafeNumber(nextActivityInfo.threshold) or 0
        local progress = SafeNumber(nextActivityInfo.progress) or 0
        local formatText = lastIndex == 1 and GREAT_VAULT_REWARDS_MYTHIC_COMPLETED_FIRST or GREAT_VAULT_REWARDS_MYTHIC_COMPLETED_SECOND
        if type(formatText) == "string" then
            AddTooltipNormalLine(GameTooltip, formatText:format(math.max(0, threshold - progress)))
        end
    else
        AddTooltipNormalLine(GameTooltip, GREAT_VAULT_REWARDS_MYTHIC_COMPLETED_THIRD or "You've unlocked all available dungeon rewards for this week.")
        AddTooltipBlankLine(GameTooltip)
        AddTooltipColoredLine(GameTooltip, GREAT_VAULT_IMPROVE_REWARD or "Improve Your Reward", GREEN_FONT_COLOR)

        if type(WeeklyRewardsUtil.GetLowestLevelInTopDungeonRuns) == "function" then
            local threshold = SafeNumber(lastCompletedActivityInfo.threshold)
            local ok, level, count = false, nil, nil
            if threshold then
                ok, level, count = pcall(WeeklyRewardsUtil.GetLowestLevelInTopDungeonRuns, threshold)
            end
            level = ok and SafeNumber(level) or nil
            count = ok and SafeNumber(count) or nil
            if level and count then
                if level == WeeklyRewardsUtil.HeroicLevel and type(GREAT_VAULT_REWARDS_HEROIC_IMPROVE) == "string" then
                    AddTooltipNormalLine(GameTooltip, GREAT_VAULT_REWARDS_HEROIC_IMPROVE:format(count))
                elseif type(WeeklyRewardsUtil.GetNextMythicLevel) == "function"
                    and type(GREAT_VAULT_REWARDS_MYTHIC_IMPROVE) == "string" then
                    local nextLevel = WeeklyRewardsUtil.GetNextMythicLevel(level)
                    AddTooltipNormalLine(GameTooltip, GREAT_VAULT_REWARDS_MYTHIC_IMPROVE:format(count, nextLevel))
                end
            end
        end
    end

    local instruction = WEEKLY_REWARDS_CLICK_TO_PREVIEW_INSTRUCTIONS or "Click to preview the Great Vault."
    if type(GameTooltip_AddInstructionLine) == "function" then
        GameTooltip_AddInstructionLine(GameTooltip, instruction)
    else
        GameTooltip:AddLine(instruction, 0.20, 1, 0.20, true)
    end
    GameTooltip:Show()
end

local function OpenGreatVault()
    if GameTooltip then GameTooltip:Hide() end
    if type(WeeklyRewards_ShowUI) ~= "function" then return end
    if type(securecallfunction) == "function" then
        securecallfunction(WeeklyRewards_ShowUI)
    else
        WeeklyRewards_ShowUI()
    end
end

local function ShowWeeklyAffixTooltip(owner)
    if not GameTooltip or not owner or not owner.affixID or not C_ChallengeMode
        or type(C_ChallengeMode.GetAffixInfo) ~= "function" then
        return
    end

    local ok, name, description = pcall(C_ChallengeMode.GetAffixInfo, owner.affixID)
    name = ok and SafeString(name) or nil
    description = ok and SafeString(description) or nil
    if not name then return end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(name, 1, 1, 1, 1, true)
    if description then
        GameTooltip:AddLine(description, nil, nil, nil, true)
    end
    GameTooltip:Show()
end

local function GetCurrentWeeklyAffixes()
    if not C_MythicPlus or type(C_MythicPlus.GetCurrentAffixes) ~= "function" then
        return {}
    end

    local ok, affixes = pcall(C_MythicPlus.GetCurrentAffixes)
    if not ok or IsSecretValue(affixes) or type(affixes) ~= "table" then
        return {}
    end
    return affixes
end

local function UpdateWeeklyAffixes()
    if not panel or not panel.affixesContainer then return 0 end

    local affixes = GetCurrentWeeklyAffixes()
    local validAffixes = {}
    for _, affix in ipairs(affixes) do
        local affixID = not IsSecretValue(affix) and type(affix) == "table" and SafeNumber(affix.id) or nil
        if affixID then
            validAffixes[#validAffixes + 1] = affixID
        end
    end

    local width = #validAffixes > 0
        and (#validAffixes * AFFIX_ICON_SIZE + (#validAffixes - 1) * AFFIX_ICON_GAP)
        or 0
    panel.affixesContainer:SetSize(math.max(1, width), AFFIX_ICON_SIZE)
    panel.affixesContainer:ClearAllPoints()
    panel.affixesContainer:SetPoint("TOPRIGHT", panel.ratingButton, "TOPLEFT", 10, -1)

    panel.affixButtons = panel.affixButtons or {}
    for index, affixID in ipairs(validAffixes) do
        local button = panel.affixButtons[index]
        if not button then
            button = CreateFrame("Button", nil, panel.affixesContainer)
            button:SetSize(AFFIX_ICON_SIZE, AFFIX_ICON_SIZE)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetPoint("CENTER")
            button.icon:SetSize(AFFIX_ICON_SIZE - 2, AFFIX_ICON_SIZE - 2)
            button.border = button:CreateTexture(nil, "OVERLAY")
            if button.border.SetAtlas then
                button.border:SetAtlas("ChallengeMode-AffixRing-Lg", true)
            end
            button.border:SetAllPoints()
            button:SetScript("OnEnter", function(self)
                ShowWeeklyAffixTooltip(self)
            end)
            button:SetScript("OnLeave", function()
                if GameTooltip then GameTooltip:Hide() end
            end)
            panel.affixButtons[index] = button
        end

        button.affixID = affixID
        local fileID
        if C_ChallengeMode and type(C_ChallengeMode.GetAffixInfo) == "function" then
            local ok, _, _, texture = pcall(C_ChallengeMode.GetAffixInfo, affixID)
            fileID = ok and SafeNumber(texture) or nil
        end
        button.icon:SetTexture(fileID or "Interface\\Icons\\INV_Misc_QuestionMark")
        button:ClearAllPoints()
        if index == 1 then
            button:SetPoint("LEFT", panel.affixesContainer, "LEFT", 0, 0)
        else
            button:SetPoint("LEFT", panel.affixButtons[index - 1], "RIGHT", AFFIX_ICON_GAP, 0)
        end
        button:Show()
    end
    for index = #validAffixes + 1, #panel.affixButtons do
        panel.affixButtons[index]:Hide()
    end

    panel.affixesContainer:SetShown(#validAffixes > 0)
    return width
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

local function GetSeasonBestLevel(mapChallengeModeID)
    if not C_MythicPlus or type(C_MythicPlus.GetSeasonBestForMap) ~= "function" then
        return nil
    end

    local ok, inTimeInfo, overtimeInfo = pcall(C_MythicPlus.GetSeasonBestForMap, mapChallengeModeID)
    if not ok then
        return nil
    end

    local bestLevel
    local function Consider(info)
        if not IsSecretValue(info) and type(info) == "table" then
            local level = SafeNumber(info.level)
            if level then
                bestLevel = math.max(bestLevel or 0, math.floor(level))
            end
        end
    end
    Consider(inTimeInfo)
    Consider(overtimeInfo)
    return bestLevel
end

local function GetWeeklyBestLevel(mapChallengeModeID)
    if not C_MythicPlus or type(C_MythicPlus.GetWeeklyBestForMap) ~= "function" then
        return nil
    end

    local ok, _, level = pcall(C_MythicPlus.GetWeeklyBestForMap, mapChallengeModeID)
    level = ok and SafeNumber(level) or nil
    return level and math.floor(level) or nil
end

local function CopyTable(source)
    local result = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            result[key] = value
        end
    end
    return result
end

local function RemoveMatchedLockouts(list, matched)
    local result = {}
    for _, info in ipairs(list or {}) do
        if not matched[info] then
            result[#result + 1] = info
        end
    end
    return result
end

local function AddSeasonalMythicPlusDungeons(lockouts)
    lockouts.seasonalDungeons = {}
    if not C_ChallengeMode
        or type(C_ChallengeMode.GetMapTable) ~= "function"
        or type(C_ChallengeMode.GetMapUIInfo) ~= "function" then
        return
    end

    local ok, mapIDs = pcall(C_ChallengeMode.GetMapTable)
    if not ok or IsSecretValue(mapIDs) or type(mapIDs) ~= "table" then
        return
    end

    local savedByInstanceID = {}
    local savedByName = {}
    for _, list in ipairs({ lockouts.currentDungeons or {}, lockouts.legacyDungeons or {} }) do
        for _, info in ipairs(list) do
            if info.instanceID then
                savedByInstanceID[info.instanceID] = info
            end
            local normalizedName = NormalizeName(info.name)
            if normalizedName then
                savedByName[normalizedName] = info
            end
        end
    end

    local matched = {}
    for _, rawMapID in ipairs(mapIDs) do
        local mapChallengeModeID = SafeNumber(rawMapID)
        if mapChallengeModeID then
            local callOK, name, _, _, _, _, gameMapID = pcall(C_ChallengeMode.GetMapUIInfo, mapChallengeModeID)
            name = callOK and SafeString(name) or nil
            gameMapID = callOK and SafeNumber(gameMapID) or nil
            if name then
                local normalizedName = NormalizeName(name)
                local saved = (gameMapID and savedByInstanceID[gameMapID])
                    or (normalizedName and savedByName[normalizedName])
                if saved then
                    matched[saved] = true
                end

                local info = CopyTable(saved)
                info.name = name
                info.mapChallengeModeID = mapChallengeModeID
                info.instanceID = gameMapID or info.instanceID
                info.difficultyID = info.difficultyID or MYTHIC_DUNGEON_DIFFICULTY_ID
                info.difficultyName = info.difficultyName or "Mythic"
                info.isRaid = false
                info.isSeasonal = true
                info.locked = saved ~= nil
                info.reset = SafeNumber(info.reset) or 0
                info.numEncounters = SafeNumber(info.numEncounters) or 0
                info.progress = SafeNumber(info.progress) or 0
                info.encounters = type(info.encounters) == "table" and info.encounters or {}
                info.weeklyBestLevel = GetWeeklyBestLevel(mapChallengeModeID)
                info.seasonBestLevel = GetSeasonBestLevel(mapChallengeModeID)

                -- Base Mythic completion is the floor when the character has
                -- a saved M0 lock but no keystone run for this map yet.
                if info.locked then
                    info.weeklyBestLevel = info.weeklyBestLevel or 0
                    info.seasonBestLevel = info.seasonBestLevel or 0
                end
                lockouts.seasonalDungeons[#lockouts.seasonalDungeons + 1] = info
            end
        end
    end

    table.sort(lockouts.seasonalDungeons, SortLockouts)
    lockouts.currentDungeons = RemoveMatchedLockouts(lockouts.currentDungeons, matched)
    lockouts.legacyDungeons = RemoveMatchedLockouts(lockouts.legacyDungeons, matched)
end

local function SetTextStyle(fontString, size, r, g, b, justify)
    fontString:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
    fontString:SetTextColor(r, g, b)
    fontString:SetJustifyH(justify or "LEFT")
    fontString:SetJustifyV("MIDDLE")
    fontString:SetWordWrap(false)
end

local function PrintGroupFinderOpenError(dungeonName, detail)
    if type(ns.Print) ~= "function" then
        return
    end

    local message = string.format("Could not open Premade Groups for %s.", dungeonName or "that dungeon")
    if detail then
        message = message .. " " .. detail
    end
    ns:Print(message)
end

local function FindDungeonActivityGroupID(info, categoryID, baseFilters)
    if not C_LFGList
        or type(C_LFGList.GetAvailableActivities) ~= "function"
        or type(C_LFGList.GetActivityInfoTable) ~= "function" then
        return nil
    end

    local activityFilters = baseFilters
    local recommendedFilter = Enum and Enum.LFGListFilter and SafeNumber(Enum.LFGListFilter.Recommended)
    if recommendedFilter and bit and type(bit.bor) == "function" then
        activityFilters = bit.bor(activityFilters, recommendedFilter)
    elseif recommendedFilter then
        activityFilters = activityFilters + recommendedFilter
    end

    local activitiesOK, activityIDs = pcall(
        C_LFGList.GetAvailableActivities,
        categoryID,
        nil,
        activityFilters
    )
    if not activitiesOK or IsSecretValue(activityIDs) or type(activityIDs) ~= "table" then
        return nil
    end

    local wantedMapID = SafeNumber(info.instanceID)
    local wantedName = NormalizeName(info.name)
    local fallbackGroupID
    for _, rawActivityID in ipairs(activityIDs) do
        local activityID = SafeNumber(rawActivityID)
        if activityID then
            local activityOK, activityInfo = pcall(C_LFGList.GetActivityInfoTable, activityID)
            if activityOK and not IsSecretValue(activityInfo) and type(activityInfo) == "table" then
                local activityMapID = SafeNumber(activityInfo.mapID)
                local shortName = NormalizeName(activityInfo.shortName)
                local fullName = NormalizeName(activityInfo.fullName)
                local mapMatches = wantedMapID and activityMapID == wantedMapID
                local nameMatches = wantedName and (
                    shortName == wantedName
                    or fullName == wantedName
                    or (fullName and fullName:find(wantedName, 1, true) == 1)
                )
                if mapMatches or nameMatches then
                    local activityGroupID = SafeNumber(activityInfo.groupFinderActivityGroupID)
                    fallbackGroupID = fallbackGroupID or activityGroupID
                    if activityGroupID and SafeBoolean(activityInfo.isMythicPlusActivity) == true then
                        return activityGroupID
                    end
                end
            end
        end
    end

    return fallbackGroupID
end

local function SelectOnlyDungeonInAdvancedFilter(activityGroupID)
    if not activityGroupID
        or not C_LFGList
        or type(C_LFGList.GetAdvancedFilter) ~= "function"
        or type(C_LFGList.SaveAdvancedFilter) ~= "function" then
        return false
    end

    local filterOK, enabled = pcall(C_LFGList.GetAdvancedFilter)
    if not filterOK or IsSecretValue(enabled) or type(enabled) ~= "table" then
        return false
    end

    -- This is the same activity-group list Blizzard's dungeon checklist saves.
    -- Replace only that list so role, rating, difficulty, and playstyle choices
    -- remain exactly as the player configured them.
    enabled.activities = { activityGroupID }
    if not SecureCallBlizzard(C_LFGList.SaveAdvancedFilter, enabled) then
        return false
    end

    local verifyOK, saved = pcall(C_LFGList.GetAdvancedFilter)
    if not verifyOK or IsSecretValue(saved) or type(saved) ~= "table"
        or type(saved.activities) ~= "table" or #saved.activities ~= 1 then
        return false
    end

    return SafeNumber(saved.activities[1]) == activityGroupID
end

local function OpenPremadeGroupsForDungeon(info)
    if not info or info.isRaid == true then
        return
    end

    local dungeonName = SafeString(info.name)
    if not dungeonName then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        PrintGroupFinderOpenError(dungeonName, "Try again after combat.")
        return
    end

    if C_LFGList and type(C_LFGList.HasActiveEntryInfo) == "function" then
        local activeOK, hasActiveEntry = pcall(C_LFGList.HasActiveEntryInfo)
        if activeOK and SafeBoolean(hasActiveEntry) == true then
            PrintGroupFinderOpenError(dungeonName, "Leave your active listing first.")
            return
        end
    end

    if type(_G.PVEFrame_ShowFrame) ~= "function" or not _G.LFGListPVEStub then
        PrintGroupFinderOpenError(dungeonName, "Blizzard's Group Finder is not available yet.")
        return
    end

    if not SecureCallBlizzard(_G.PVEFrame_ShowFrame, "GroupFinderFrame", _G.LFGListPVEStub) then
        PrintGroupFinderOpenError(dungeonName, "Blizzard's Group Finder could not be opened.")
        return
    end

    local lfgFrame = _G.LFGListFrame
    local categoryPanel = lfgFrame and lfgFrame.CategorySelection
    local searchPanel = lfgFrame and lfgFrame.SearchPanel
    if not lfgFrame or not categoryPanel or not searchPanel then
        PrintGroupFinderOpenError(dungeonName, "The dungeon search panel is not available yet.")
        return
    end

    if type(_G.LFGListCategorySelectionButton_OnClick) ~= "function"
        or type(_G.LFGListCategorySelection_StartFindGroup) ~= "function" then
        PrintGroupFinderOpenError(dungeonName, "Blizzard's dungeon search controls are not available yet.")
        return
    end

    local categoryID = SafeNumber(_G.GROUP_FINDER_CATEGORY_ID_DUNGEONS) or GROUP_FINDER_DUNGEON_CATEGORY_ID
    local baseFilters = SafeNumber(lfgFrame.baseFilters) or 0
    local activityGroupID = FindDungeonActivityGroupID(info, categoryID, baseFilters)
    if not activityGroupID then
        PrintGroupFinderOpenError(dungeonName, "Blizzard did not return a matching dungeon filter.")
        return
    end

    if not SelectOnlyDungeonInAdvancedFilter(activityGroupID) then
        PrintGroupFinderOpenError(dungeonName, "Blizzard's dungeon checklist could not be updated.")
        return
    end

    if type(_G.LFGListCategorySelection_UpdateCategoryButtons) == "function" then
        SecureCallBlizzard(_G.LFGListCategorySelection_UpdateCategoryButtons, categoryPanel)
    end

    local dungeonCategoryButton
    if type(categoryPanel.CategoryButtons) == "table" then
        for _, button in ipairs(categoryPanel.CategoryButtons) do
            if SafeNumber(button and button.categoryID) == categoryID then
                local buttonFilters = SafeNumber(button.filters) or 0
                if buttonFilters == 0 or not dungeonCategoryButton then
                    dungeonCategoryButton = button
                end
                if buttonFilters == 0 then
                    break
                end
            end
        end
    end
    if not dungeonCategoryButton then
        PrintGroupFinderOpenError(dungeonName, "Blizzard's Dungeons category is not available yet.")
        return
    end

    -- Let Blizzard's own Dungeons button and Find Group handler populate every
    -- Lua-side panel field from Blizzard-owned values. Passing category values
    -- from addon code into those fields is what can taint the 12.1 result rows.
    if not SecureCallBlizzard(_G.LFGListCategorySelectionButton_OnClick, dungeonCategoryButton)
        or not SecureCallBlizzard(_G.LFGListCategorySelection_StartFindGroup, categoryPanel) then
        PrintGroupFinderOpenError(dungeonName, "Blizzard's dungeon results could not be opened.")
        return
    end

    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function ShowLockoutTooltip(row)
    local info = row and row.info
    if not info or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(info.name, 1, 0.82, 0.18)

    if info.isSeasonal then
        GameTooltip:AddDoubleLine("Best this week", FormatBestRunLevel(info.weeklyBestLevel), 0.85, 0.85, 0.85, 1, 0.82, 0.22)
        GameTooltip:AddDoubleLine("Best this season", FormatBestRunLevel(info.seasonBestLevel), 0.85, 0.85, 0.85, 1, 0.82, 0.22)
        if info.locked then
            GameTooltip:AddDoubleLine("Mythic (M0) loot", "Locked", 0.85, 0.85, 0.85, 1, 0.48, 0.24)
            GameTooltip:AddDoubleLine("Reset", FormatResetTime(info.reset), 0.85, 0.85, 0.85, 0.58, 0.72, 0.95)
        else
            GameTooltip:AddDoubleLine("Mythic (M0) loot", "Open", 0.85, 0.85, 0.85, 0.36, 0.90, 0.52)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Mythic+ remains repeatable. The lock only tracks base Mythic loot for this week.", 0.66, 0.66, 0.70, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to open Premade Groups with only this dungeon checked.", 0.35, 0.82, 1, true)
        GameTooltip:Show()
        return
    end

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
    if info.isRaid ~= true then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to open Premade Groups with only this dungeon checked.", 0.35, 0.82, 1, true)
    end
    GameTooltip:Show()
end

local function CreateLockoutRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(40)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")

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

    row.weeklyBest = row:CreateFontString(nil, "OVERLAY")
    row.weeklyBest:SetSize(WEEKLY_RUN_COLUMN_WIDTH, 17)
    SetTextStyle(row.weeklyBest, 10, 0.95, 0.72, 0.18, "CENTER")

    row.seasonBest = row:CreateFontString(nil, "OVERLAY")
    row.seasonBest:SetSize(SEASON_RUN_COLUMN_WIDTH, 17)
    SetTextStyle(row.seasonBest, 10, 0.95, 0.72, 0.18, "CENTER")

    row.lockStatus = row:CreateFontString(nil, "OVERLAY")
    row.lockStatus:SetSize(LOCK_COLUMN_WIDTH, 17)
    SetTextStyle(row.lockStatus, 9, 0.72, 0.72, 0.75, "CENTER")

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
    row:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            OpenPremadeGroupsForDungeon(self.info)
        end
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

local function GetSeasonalRightReserve()
    return RESET_COLUMN_WIDTH + LOCK_COLUMN_WIDTH + SEASON_RUN_COLUMN_WIDTH
        + WEEKLY_RUN_COLUMN_WIDTH + (COLUMN_GAP * 3) + ROW_RIGHT_INSET
end

local RenderLockouts

local function GetSeasonalSortHeaderText(column, label)
    local db = EnsureDB()
    if not db or db.sortColumn ~= column then
        return label
    end
    return label .. (db.sortDirection == "desc" and " v" or " ^")
end

local function SortSeasonalDungeons(list)
    local db = EnsureDB()
    local column = db and db.sortColumn
    if column ~= "week" and column ~= "season" then
        return list
    end

    local sorted = {}
    for index, info in ipairs(list or {}) do
        sorted[index] = info
    end

    local valueKey = column == "week" and "weeklyBestLevel" or "seasonBestLevel"
    local descending = db.sortDirection == "desc"
    table.sort(sorted, function(left, right)
        local leftValue = left and SafeNumber(left[valueKey]) or nil
        local rightValue = right and SafeNumber(right[valueKey]) or nil

        if leftValue ~= rightValue then
            if leftValue == nil then
                return not descending
            elseif rightValue == nil then
                return descending
            elseif descending then
                return leftValue > rightValue
            else
                return leftValue < rightValue
            end
        end

        return tostring(left and left.name or ""):lower() < tostring(right and right.name or ""):lower()
    end)
    return sorted
end

local function CreateSeasonalSortButton(parent, column, label)
    local button = CreateFrame("Button", nil, parent)
    button.column = column
    button.label = label
    button:RegisterForClicks("LeftButtonUp")

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints()
    button.background:SetColorTexture(0.90, 0.68, 0.16, 0)

    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetAllPoints()
    SetTextStyle(button.text, 8, 0.95, 0.72, 0.18, "CENTER")

    button:SetScript("OnEnter", function(self)
        self.background:SetColorTexture(0.90, 0.68, 0.16, 0.12)
        if not GameTooltip then
            return
        end
        local db = EnsureDB()
        local nextDirection = "asc"
        if db and db.sortColumn == self.column and db.sortDirection == "asc" then
            nextDirection = "desc"
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Sort by " .. (self.column == "week" and "weekly best" or "season best"))
        GameTooltip:AddLine(
            nextDirection == "desc" and "Click for highest to lowest." or "Click for lowest to highest.",
            1,
            1,
            1
        )
        GameTooltip:AddLine("No recorded run sorts below +0.", 0.68, 0.68, 0.72)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self.background:SetColorTexture(0.90, 0.68, 0.16, 0)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    button:SetScript("OnClick", function(self)
        local db = EnsureDB()
        if not db then
            return
        end
        if db.sortColumn == self.column then
            db.sortDirection = db.sortDirection == "asc" and "desc" or "asc"
        else
            db.sortColumn = self.column
            db.sortDirection = "asc"
        end
        if GameTooltip then
            GameTooltip:Hide()
        end
        if panel and panel.scroll then
            panel.scroll:SetVerticalScroll(0)
        end
        if RenderLockouts then
            RenderLockouts(panel and panel.lockouts)
        end
    end)
    return button
end

local function AddSectionHeader(text, y, seasonal)
    local label = AcquireLabel("section")
    local rightReserve = RESET_COLUMN_WIDTH + ROW_RIGHT_INSET
    if seasonal then
        rightReserve = GetSeasonalRightReserve()
    end
    label:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 4, y)
    label:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -rightReserve, y)
    label:SetHeight(20)
    SetTextStyle(label, 11, 0.95, 0.72, 0.18, "LEFT")
    label:SetText(text)

    if seasonal then
        local lockHeader = AcquireLabel("lockHeader")
        lockHeader:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -(RESET_COLUMN_WIDTH + ROW_RIGHT_INSET + COLUMN_GAP), y)
        lockHeader:SetSize(LOCK_COLUMN_WIDTH, 20)
        SetTextStyle(lockHeader, 8, 0.72, 0.72, 0.75, "CENTER")
        lockHeader:SetText("M0 LOCK")

        local seasonHeader = panel.seasonSortButton
        seasonHeader:ClearAllPoints()
        seasonHeader:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -(RESET_COLUMN_WIDTH + LOCK_COLUMN_WIDTH + ROW_RIGHT_INSET + (COLUMN_GAP * 2)), y)
        seasonHeader:SetSize(SEASON_RUN_COLUMN_WIDTH, 20)
        seasonHeader.text:SetText(GetSeasonalSortHeaderText("season", "SEASON"))
        seasonHeader:Show()

        local weeklyHeader = panel.weeklySortButton
        weeklyHeader:ClearAllPoints()
        weeklyHeader:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -(RESET_COLUMN_WIDTH + LOCK_COLUMN_WIDTH + SEASON_RUN_COLUMN_WIDTH + ROW_RIGHT_INSET + (COLUMN_GAP * 3)), y)
        weeklyHeader:SetSize(WEEKLY_RUN_COLUMN_WIDTH, 20)
        weeklyHeader.text:SetText(GetSeasonalSortHeaderText("week", "WEEK"))
        weeklyHeader:Show()
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

local function AddLockoutRows(list, emptyText, y, legacy, seasonal)
    if #list == 0 then
        return AddLabel("empty", emptyText, y, 22) - 2
    end

    for _, info in ipairs(list) do
        local row = AcquireRow()
        row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 2, y)
        row:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -2, y)
        row.info = info
        row.name:SetText(info.name)
        row.reset:ClearAllPoints()
        row.reset:SetPoint("TOPRIGHT", row, "TOPRIGHT", -ROW_RIGHT_INSET, -4)

        local rightReserve = RESET_COLUMN_WIDTH + ROW_RIGHT_INSET
        if seasonal then
            rightReserve = GetSeasonalRightReserve()
            row.lockStatus:ClearAllPoints()
            row.lockStatus:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(RESET_COLUMN_WIDTH + ROW_RIGHT_INSET + COLUMN_GAP), -4)
            row.lockStatus:SetText(info.locked and "Locked" or "Open")
            row.lockStatus:SetTextColor(info.locked and 1 or 0.36, info.locked and 0.48 or 0.90, info.locked and 0.24 or 0.52)
            row.lockStatus:Show()

            row.seasonBest:ClearAllPoints()
            row.seasonBest:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(RESET_COLUMN_WIDTH + LOCK_COLUMN_WIDTH + ROW_RIGHT_INSET + (COLUMN_GAP * 2)), -4)
            row.seasonBest:SetText(FormatBestRunLevel(info.seasonBestLevel))
            row.seasonBest:Show()

            row.weeklyBest:ClearAllPoints()
            row.weeklyBest:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(RESET_COLUMN_WIDTH + LOCK_COLUMN_WIDTH + SEASON_RUN_COLUMN_WIDTH + ROW_RIGHT_INSET + (COLUMN_GAP * 3)), -4)
            row.weeklyBest:SetText(FormatBestRunLevel(info.weeklyBestLevel))
            row.weeklyBest:Show()
            row.reset:SetText(info.locked and FormatResetTime(info.reset) or "—")
        else
            row.weeklyBest:Hide()
            row.seasonBest:Hide()
            row.lockStatus:Hide()
            row.reset:SetText(FormatResetTime(info.reset))
        end

        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", 10, -4)
        row.name:SetPoint("TOPRIGHT", -rightReserve, -4)
        row.detail:ClearAllPoints()
        row.detail:SetPoint("BOTTOMLEFT", 10, 4)
        row.detail:SetPoint("BOTTOMRIGHT", -rightReserve, 4)

        local detail
        if seasonal then
            detail = info.locked and "Mythic+  |  M0 loot locked" or "Mythic+  |  M0 loot open"
        elseif info.numEncounters > 0 then
            detail = string.format("%s  |  %d/%d bosses", info.difficultyName, info.progress, info.numEncounters)
        else
            detail = string.format("%s  |  Weekly lockout", info.difficultyName)
        end
        if info.extended then
            detail = detail .. "  |cffff8a42Extended|r"
        end
        row.detail:SetText(detail)

        if seasonal then
            if info.locked then
                row.accent:SetColorTexture(0.94, 0.45, 0.16, 0.95)
            else
                row.accent:SetColorTexture(0.20, 0.62, 0.92, 0.95)
            end
        elseif legacy then
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

RenderLockouts = function(lockouts)
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

    panel.ratingButton:ClearAllPoints()
    panel.ratingButton:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -4, expansionY)
    panel.ratingButton:SetSize(RATING_SUMMARY_WIDTH, 24)
    local rating = GetCurrentMythicPlusRating()
    panel.ratingSummary:SetText(string.format("M+ RATING  %s%d|r", GetMythicPlusRatingColorCode(rating), rating))
    panel.ratingButton:Show()
    local affixWidth = UpdateWeeklyAffixes()
    expansionLabel:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -(RATING_SUMMARY_WIDTH + 4 + affixWidth + (affixWidth > 0 and 2 or 0)), expansionY)

    y = AddSectionHeader("SEASONAL MYTHIC+", y, true)
    y = AddLockoutRows(SortSeasonalDungeons(lockouts.seasonalDungeons or {}), "Seasonal Mythic+ data is not available yet.", y, false, true)
    if #lockouts.currentDungeons > 0 then
        y = y - 6
        y = AddSectionHeader("OTHER MYTHIC DUNGEONS", y, false)
        y = AddLockoutRows(lockouts.currentDungeons, "", y, false, false)
    end
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
    AddSeasonalMythicPlusDungeons(lockouts)
    RenderLockouts(lockouts)
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
    if C_MythicPlus and type(C_MythicPlus.RequestRewards) == "function" then
        pcall(C_MythicPlus.RequestRewards)
    end
    ScheduleRefresh(0.10)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.75, function()
            ScheduleRefresh(0)
        end)
    end
end

local ApplyPanelDisplayState
local PositionPanel

local function CreatePanel()
    if panel then
        return panel
    end

    panel = CreateFrame("Frame", PANEL_NAME, UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, 510)
    panel:SetFrameStrata("HIGH")
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
    panel.title:SetPoint("TOPRIGHT", -154, -8)
    panel.title:SetHeight(18)
    SetTextStyle(panel.title, 14, 1, 0.80, 0.22, "LEFT")
    panel.title:SetText("INSTANCE LOCKOUTS")

    panel.subtitle = panel:CreateFontString(nil, "OVERLAY")
    panel.subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -1)
    panel.subtitle:SetPoint("TOPRIGHT", panel.title, "BOTTOMRIGHT", 0, -1)
    panel.subtitle:SetHeight(14)
    SetTextStyle(panel.subtitle, 9, 0.56, 0.56, 0.60, "LEFT")
    panel.subtitle:SetText("Seasonal Mythic+ bests and saved raids")

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

    panel.vaultButton = CreateFrame("Button", nil, panel)
    panel.vaultButton:SetPoint("RIGHT", panel.refreshButton, "LEFT", -6, 0)
    panel.vaultButton:SetSize(48, 22)
    panel.vaultButton.background = panel.vaultButton:CreateTexture(nil, "BACKGROUND")
    panel.vaultButton.background:SetAllPoints()
    panel.vaultButton.background:SetColorTexture(0.16, 0.16, 0.18, 0.95)
    panel.vaultButton.text = panel.vaultButton:CreateFontString(nil, "OVERLAY")
    panel.vaultButton.text:SetAllPoints()
    SetTextStyle(panel.vaultButton.text, 10, 0.92, 0.92, 0.92, "CENTER")
    panel.vaultButton.text:SetText("Vault")
    panel.vaultButton:SetScript("OnEnter", function(self)
        self.background:SetColorTexture(0.30, 0.24, 0.10, 0.95)
        ShowGreatVaultTooltip(self)
    end)
    panel.vaultButton:SetScript("OnLeave", function(self)
        self.background:SetColorTexture(0.16, 0.16, 0.18, 0.95)
        if GameTooltip then GameTooltip:Hide() end
    end)
    panel.vaultButton:SetScript("OnClick", OpenGreatVault)

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
    panel.minimizeButton.gear = panel.minimizeButton:CreateTexture(nil, "OVERLAY")
    panel.minimizeButton.gear:SetPoint("TOPLEFT", 5, -5)
    panel.minimizeButton.gear:SetPoint("BOTTOMRIGHT", -5, 5)
    panel.minimizeButton.gear:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    panel.minimizeButton.gear:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    panel.minimizeButton.gear:Hide()
    panel.minimizeButton:SetScript("OnEnter", function(self)
        if self.gear:IsShown() then
            self.gear:SetVertexColor(1, 0.84, 0.22, 1)
            self.background:SetColorTexture(0.30, 0.24, 0.10, 0.95)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Instance Lockouts")
            GameTooltip:AddLine("Click to expand.", 1, 1, 1)
            GameTooltip:Show()
        else
            self.background:SetColorTexture(0.30, 0.24, 0.10, 0.95)
        end
    end)
    panel.minimizeButton:SetScript("OnLeave", function(self)
        self.gear:SetVertexColor(1, 1, 1, 1)
        self.background:SetColorTexture(0.16, 0.16, 0.18, 0.95)
        GameTooltip:Hide()
    end)
    panel.minimizeButton:SetScript("OnClick", function()
        local db = EnsureDB()
        if not db then
            return
        end
        GameTooltip:Hide()
        db.minimized = not db.minimized
        if PositionPanel then
            PositionPanel()
        else
            ApplyPanelDisplayState()
        end
    end)

    panel.scroll = CreateFrame("ScrollFrame", nil, panel)
    panel.scroll:SetPoint("TOPLEFT", 12, -53)
    panel.scroll:SetPoint("BOTTOMRIGHT", -12, 12)
    panel.scroll:SetClipsChildren(true)
    panel.scroll:EnableMouseWheel(true)

    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.content:SetSize(PANEL_WIDTH - 24, 1)
    panel.scroll:SetScrollChild(panel.content)

    panel.ratingButton = CreateFrame("Button", nil, panel.content)
    panel.ratingButton:EnableMouse(true)
    panel.ratingSummary = panel.ratingButton:CreateFontString(nil, "OVERLAY")
    panel.ratingSummary:SetAllPoints()
    SetTextStyle(panel.ratingSummary, 10, 0.95, 0.72, 0.18, "RIGHT")
    panel.ratingButton:SetScript("OnEnter", function(self)
        ShowMythicPlusRatingTooltip(self)
    end)
    panel.ratingButton:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    panel.affixesContainer = CreateFrame("Frame", nil, panel.content)
    panel.affixesContainer:Hide()
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

    panel.weeklySortButton = CreateSeasonalSortButton(panel.content, "week", "WEEK")
    panel.seasonSortButton = CreateSeasonalSortButton(panel.content, "season", "SEASON")

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

    if minimized then
        panel:SetSize(PANEL_MINIMIZED_WIDTH, PANEL_MINIMIZED_HEIGHT)
        panel:SetBackdropColor(0.018, 0.020, 0.026, 0.97)
        panel:SetBackdropBorderColor(0.78, 0.58, 0.18, 0.95)
        panel.header:Hide()
        panel.title:Hide()
        panel.subtitle:Hide()
        panel.refreshButton:Hide()
        panel.vaultButton:Hide()
        panel.scroll:Hide()
        panel.minimizeButton:ClearAllPoints()
        panel.minimizeButton:SetAllPoints(panel)
        panel.minimizeButton.background:Show()
        panel.minimizeButton.text:Hide()
        panel.minimizeButton.gear:Show()
    else
        panel:SetSize(PANEL_WIDTH, panel.expandedHeight or 510)
        panel:SetBackdropColor(0.018, 0.020, 0.026, 0.97)
        panel:SetBackdropBorderColor(0.78, 0.58, 0.18, 0.95)
        panel.header:Show()
        panel.header:SetHeight(42)
        panel.title:ClearAllPoints()
        panel.title:SetPoint("TOPLEFT", 14, -8)
        panel.title:SetPoint("TOPRIGHT", -154, -8)
        panel.title:SetText("INSTANCE LOCKOUTS")
        panel.title:Show()
        panel.subtitle:Show()
        panel.refreshButton:Show()
        panel.vaultButton:Show()
        panel.scroll:Show()
        panel.minimizeButton:ClearAllPoints()
        panel.minimizeButton:SetPoint("TOPRIGHT", -10, -11)
        panel.minimizeButton:SetSize(22, 22)
        panel.minimizeButton.background:Show()
        panel.minimizeButton.text:Show()
        panel.minimizeButton.gear:Hide()
        panel.minimizeButton.text:SetText("-")
    end
end

PositionPanel = function()
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
    local db = EnsureDB()
    if db and db.minimized == true then
        panel.anchorSide = "BORDER"
        panel:SetPoint(
            "TOPLEFT",
            pveFrame,
            "TOPRIGHT",
            PANEL_BORDER_BUTTON_X_OFFSET,
            PANEL_BORDER_BUTTON_TOP_OFFSET
        )
    elseif right and screenRight and right + PANEL_GAP + PANEL_WIDTH <= screenRight - 4 then
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
        if positionSyncQueued then
            return
        end
        positionSyncQueued = true

        local function RunSync()
            positionSyncQueued = false
            SyncPanelVisibility()
        end

        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0, RunSync)
        else
            RunSync()
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

    -- Blizzard's panel manager reanchors PVEFrame when other large windows
    -- open or close without changing its size. Re-evaluate which side has room
    -- after every such move so the lockout panel does not remain on the side
    -- chosen for a temporary crowded layout.
    if type(hooksecurefunc) == "function" and type(pveFrame.SetPoint) == "function" then
        pcall(hooksecurefunc, pveFrame, "SetPoint", SyncAfterBlizzardUpdate)
    end

    if type(hooksecurefunc) == "function" and type(_G.PVEFrame_ShowFrame) == "function" then
        hooksecurefunc("PVEFrame_ShowFrame", SyncPanelVisibility)
    end

    pveHooksInstalled = true
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

function ns:RefreshInstanceLockouts()
    if not catalogReady then
        RebuildCurrentExpansionCatalog()
    end
    RequestLockoutData()
end

function ns:GetCurrentExpansionLockoutSnapshot()
    if not catalogReady then
        RebuildCurrentExpansionCatalog()
    end

    local lockouts = ReadSavedLockouts()
    AddMythicPlusProgress(lockouts)
    return {
        expansionName = currentExpansionName,
        dungeons = lockouts.currentDungeons,
        raids = lockouts.currentRaids,
    }
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
    eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    eventFrame:RegisterEvent("MYTHIC_PLUS_NEW_WEEKLY_RECORD")
    eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    eventFrame:SetScript("OnEvent", function(_, event, addonName)
        if event == "ADDON_LOADED" then
            if addonName == "Blizzard_EncounterJournal" then
                RebuildCurrentExpansionCatalog()
                ScheduleRefresh(0)
            elseif addonName == "Blizzard_GroupFinder" then
                InstallPVEHooks()
                SyncPanelVisibility()
            end
            return
        end

        if event == "UPDATE_EXPANSION_LEVEL" then
            RebuildCurrentExpansionCatalog()
            ScheduleRefresh(0)
        end

        if event == "PLAYER_ENTERING_WORLD" or event == "BOSS_KILL"
            or event == "ENCOUNTER_END" or event == "PLAYER_DIFFICULTY_CHANGED"
            or event == "MYTHIC_PLUS_NEW_WEEKLY_RECORD" or event == "CHALLENGE_MODE_COMPLETED" then
            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(1, RequestLockoutData)
            else
                RequestLockoutData()
            end
        elseif event == "UPDATE_INSTANCE_INFO" or event == "WEEKLY_REWARDS_UPDATE"
            or event == "CHALLENGE_MODE_MAPS_UPDATE" then
            ScheduleRefresh(0)
        end
    end)

    InstallPVEHooks()
    SyncPanelVisibility()
end
