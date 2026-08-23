local _, ns = ...

local SNAPSHOT_VERSION = 1
local eventFrame
local captureQueued = false
local currentCharacterKey

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

local function CallNumber(callback, ...)
    if type(callback) ~= "function" then
        return nil
    end

    local ok, value = pcall(callback, ...)
    return ok and SafeNumber(value) or nil
end

local function GetNow()
    local now = CallNumber(GetServerTime)
    if now then
        return math.floor(now)
    end

    if type(time) == "function" then
        now = CallNumber(time)
    end
    return now and math.floor(now) or 0
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.warbandWeekly = ns.db.warbandWeekly or {}
    local db = ns.db.warbandWeekly
    if db.showLevelingCharacters == nil then
        db.showLevelingCharacters = false
    end
    if type(db.characters) ~= "table" then
        db.characters = {}
    end
    db.snapshotVersion = SNAPSHOT_VERSION
    return db
end

local function GetCharacterIdentity()
    local name
    local realm
    if type(UnitFullName) == "function" then
        local ok
        ok, name, realm = pcall(UnitFullName, "player")
        name = ok and SafeString(name) or nil
        realm = ok and SafeString(realm) or nil
    end

    if not name and type(UnitName) == "function" then
        local ok, unitName = pcall(UnitName, "player")
        name = ok and SafeString(unitName) or nil
    end

    if not realm and type(GetNormalizedRealmName) == "function" then
        local ok, normalizedRealm = pcall(GetNormalizedRealmName)
        realm = ok and SafeString(normalizedRealm) or nil
    end
    if not realm and type(GetRealmName) == "function" then
        local ok, realmName = pcall(GetRealmName)
        realm = ok and SafeString(realmName) or nil
    end

    name = name or "Unknown"
    realm = realm or "Unknown Realm"

    local guid
    if type(UnitGUID) == "function" then
        local ok, unitGUID = pcall(UnitGUID, "player")
        guid = ok and SafeString(unitGUID) or nil
    end

    local key = guid or string.format("%s-%s", realm, name):lower()
    return key, guid, name, realm
end

local function GetWeeklyResetAt(now)
    if C_DateAndTime and type(C_DateAndTime.GetSecondsUntilWeeklyReset) == "function" then
        local seconds = CallNumber(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if seconds and seconds >= 0 and seconds <= 8 * 86400 then
            return now + math.floor(seconds)
        end
    end
    return nil
end

local function GetEquippedItemLevel()
    if type(GetAverageItemLevel) ~= "function" then
        return 0
    end

    local ok, overall, equipped = pcall(GetAverageItemLevel)
    if not ok then
        return 0
    end

    local itemLevel = SafeNumber(equipped) or SafeNumber(overall)
    return itemLevel and math.max(0, math.floor(itemLevel + 0.5)) or 0
end

local function GetMythicPlusRating()
    if not C_PlayerInfo or type(C_PlayerInfo.GetPlayerMythicPlusRatingSummary) ~= "function" then
        return 0
    end

    local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
    if not ok or IsSecretValue(summary) or type(summary) ~= "table" then
        return 0
    end

    local score = SafeNumber(summary.currentSeasonScore)
    return score and math.max(0, math.floor(score + 0.5)) or 0
end

local function GetWeeklyDungeonProgress()
    local counts = {
        heroic = 0,
        mythic = 0,
        mythicPlus = 0,
    }

    if C_WeeklyRewards and type(C_WeeklyRewards.GetNumCompletedDungeonRuns) == "function" then
        local ok, heroic, mythic, mythicPlus = pcall(C_WeeklyRewards.GetNumCompletedDungeonRuns)
        if ok then
            counts.heroic = math.max(0, math.floor(SafeNumber(heroic) or 0))
            counts.mythic = math.max(0, math.floor(SafeNumber(mythic) or 0))
            counts.mythicPlus = math.max(0, math.floor(SafeNumber(mythicPlus) or 0))
        end
    end

    local bestLevel
    if counts.mythicPlus > 0 and C_MythicPlus and type(C_MythicPlus.GetRunHistory) == "function" then
        local ok, runs = pcall(C_MythicPlus.GetRunHistory, false, false, true)
        if ok and not IsSecretValue(runs) and type(runs) == "table" then
            for _, run in ipairs(runs) do
                if not IsSecretValue(run) and type(run) == "table" then
                    local level = SafeNumber(run.level)
                    local thisWeek = SafeBoolean(run.thisWeek)
                    local completed = SafeBoolean(run.completed)
                    if level and level >= 2 and thisWeek ~= false and completed ~= false then
                        bestLevel = math.max(bestLevel or 0, math.floor(level))
                    end
                end
            end
        end
    elseif counts.mythic > 0 then
        bestLevel = 0
    elseif counts.heroic > 0 then
        bestLevel = -1
    end

    if not bestLevel and (counts.mythicPlus + counts.mythic + counts.heroic) > 0
        and C_MythicPlus and type(C_MythicPlus.GetWeeklyChestRewardLevel) == "function" then
        local ok, currentWeekBestLevel = pcall(C_MythicPlus.GetWeeklyChestRewardLevel)
        currentWeekBestLevel = ok and SafeNumber(currentWeekBestLevel) or nil
        if currentWeekBestLevel then
            bestLevel = math.floor(currentWeekBestLevel)
        end
    end

    return bestLevel, counts
end

local function GetWeeklyCategoryKey(activityType)
    activityType = SafeNumber(activityType)
    local types = Enum and Enum.WeeklyRewardChestThresholdType
    if not activityType or type(types) ~= "table" then
        return nil
    end

    if activityType == SafeNumber(types.Activities) then
        return "dungeons"
    elseif activityType == SafeNumber(types.Raid) then
        return "raid"
    elseif activityType == SafeNumber(types.World) then
        return "world"
    elseif activityType == SafeNumber(types.RankedPvP) then
        return "pvp"
    end
    return nil
end

local function CreateVaultCategory()
    return {
        unlocked = 0,
        total = 0,
        slots = {},
    }
end

local function ReadGreatVault()
    local vault = {
        hasData = false,
        rewardAvailable = false,
        unlocked = 0,
        total = 0,
        dungeons = CreateVaultCategory(),
        raid = CreateVaultCategory(),
        world = CreateVaultCategory(),
        pvp = CreateVaultCategory(),
    }

    if C_WeeklyRewards and type(C_WeeklyRewards.HasAvailableRewards) == "function" then
        local ok, available = pcall(C_WeeklyRewards.HasAvailableRewards)
        vault.rewardAvailable = ok and SafeBoolean(available) == true
    end

    if not C_WeeklyRewards or type(C_WeeklyRewards.GetActivities) ~= "function" then
        return vault
    end

    local ok, activities = pcall(C_WeeklyRewards.GetActivities)
    if not ok or IsSecretValue(activities) or type(activities) ~= "table" then
        return vault
    end

    for _, activity in ipairs(activities) do
        if not IsSecretValue(activity) and type(activity) == "table" then
            local categoryKey = GetWeeklyCategoryKey(activity.type)
            local category = categoryKey and vault[categoryKey]
            local progress = SafeNumber(activity.progress)
            local threshold = SafeNumber(activity.threshold)
            if category and progress and threshold and threshold > 0 then
                local unlocked = progress >= threshold
                local slot = {
                    progress = math.max(0, math.floor(progress)),
                    threshold = math.max(1, math.floor(threshold)),
                    level = SafeNumber(activity.level),
                    unlocked = unlocked,
                }
                category.slots[#category.slots + 1] = slot
                category.total = category.total + 1
                vault.total = vault.total + 1
                if unlocked then
                    category.unlocked = category.unlocked + 1
                    vault.unlocked = vault.unlocked + 1
                end
            end
        end
    end

    for _, categoryKey in ipairs({ "dungeons", "raid", "world", "pvp" }) do
        table.sort(vault[categoryKey].slots, function(left, right)
            return left.threshold < right.threshold
        end)
    end
    vault.hasData = vault.total > 0
    return vault
end

local function ReadOwnedKeystone()
    if not C_MythicPlus then
        return nil
    end

    local level = CallNumber(C_MythicPlus.GetOwnedKeystoneLevel)
    if not level or level < 2 then
        return nil
    end

    local challengeMapID = CallNumber(C_MythicPlus.GetOwnedKeystoneChallengeMapID)
    local name
    if challengeMapID and C_ChallengeMode and type(C_ChallengeMode.GetMapUIInfo) == "function" then
        local ok, mapName = pcall(C_ChallengeMode.GetMapUIInfo, challengeMapID)
        name = ok and SafeString(mapName) or nil
    end

    return {
        level = math.floor(level),
        challengeMapID = challengeMapID,
        name = name or "Unknown dungeon",
    }
end

local function CopyLockoutList(source, now)
    local result = {}
    if type(source) ~= "table" then
        return result
    end

    for _, info in ipairs(source) do
        if type(info) == "table" then
            local name = SafeString(info.name)
            local reset = SafeNumber(info.reset)
            if name then
                result[#result + 1] = {
                    name = name,
                    difficultyName = SafeString(info.difficultyName) or "Saved",
                    progress = math.max(0, math.floor(SafeNumber(info.progress) or 0)),
                    numEncounters = math.max(0, math.floor(SafeNumber(info.numEncounters) or 0)),
                    bestRunLevel = SafeNumber(info.bestRunLevel),
                    resetAt = reset and now + math.max(0, math.floor(reset)) or nil,
                }
            end
        end
    end
    return result
end

local function ReadCurrentExpansionLockouts(now)
    local result = {
        expansionName = "Current Expansion",
        dungeons = {},
        raids = {},
    }

    if type(ns.GetCurrentExpansionLockoutSnapshot) ~= "function" then
        return result
    end

    local ok, snapshot = pcall(ns.GetCurrentExpansionLockoutSnapshot, ns)
    if not ok or type(snapshot) ~= "table" then
        return result
    end

    result.expansionName = SafeString(snapshot.expansionName) or result.expansionName
    result.dungeons = CopyLockoutList(snapshot.dungeons, now)
    result.raids = CopyLockoutList(snapshot.raids, now)
    return result
end

local function GetSpecializationName()
    if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then
        return nil
    end

    local specialization = CallNumber(GetSpecialization)
    if not specialization then
        return nil
    end

    local ok, _, name = pcall(GetSpecializationInfo, specialization)
    return ok and SafeString(name) or nil
end

local function NotifyDashboard()
    if ns.UI2 and type(ns.UI2.RefreshWarbandDashboard) == "function" then
        ns.UI2.RefreshWarbandDashboard()
    end
end

local function CaptureCurrentCharacter()
    local db = EnsureDB()
    if not db then
        return nil
    end

    local now = GetNow()
    local key, guid, name, realm = GetCharacterIdentity()
    currentCharacterKey = key

    local className
    local classFile
    local classID
    if type(UnitClass) == "function" then
        local ok
        ok, className, classFile, classID = pcall(UnitClass, "player")
        className = ok and SafeString(className) or nil
        classFile = ok and SafeString(classFile) or nil
        classID = ok and SafeNumber(classID) or nil
    end

    local level = type(UnitLevel) == "function" and CallNumber(UnitLevel, "player") or nil
    local maxLevel = CallNumber(GetMaxLevelForPlayerExpansion)
    local faction
    if type(UnitFactionGroup) == "function" then
        local ok, unitFaction = pcall(UnitFactionGroup, "player")
        faction = ok and SafeString(unitFaction) or nil
    end
    local bestLevel, dungeonRuns = GetWeeklyDungeonProgress()

    local existing = db.characters[key]
    if type(existing) ~= "table" then
        existing = { firstSeen = now }
        db.characters[key] = existing
    end

    existing.snapshotVersion = SNAPSHOT_VERSION
    existing.key = key
    existing.guid = guid
    existing.name = name
    existing.realm = realm
    existing.className = className or "Unknown"
    existing.classFile = classFile
    existing.classID = classID
    existing.faction = faction
    existing.level = level and math.max(0, math.floor(level)) or 0
    existing.maxLevel = maxLevel and math.max(0, math.floor(maxLevel)) or nil
    existing.specialization = GetSpecializationName()
    existing.itemLevel = GetEquippedItemLevel()
    existing.mythicPlusRating = GetMythicPlusRating()
    local resetAt = GetWeeklyResetAt(now)
    existing.weeklyBestLevel = bestLevel
    existing.weeklyDungeonRuns = dungeonRuns
    existing.keystone = ReadOwnedKeystone()
    local vault = ReadGreatVault()
    local previousResetAt = SafeNumber(existing.resetAt)
    local resetChanged = resetAt and previousResetAt and math.abs(resetAt - previousResetAt) > 3600
    if vault.hasData or type(existing.vault) ~= "table"
        or resetChanged then
        existing.vault = vault
    end
    existing.lockouts = ReadCurrentExpansionLockouts(now)
    if resetAt then
        existing.resetAt = resetAt
    end
    existing.lastSeen = now

    NotifyDashboard()
    return existing
end

local function ScheduleCapture(delay)
    if captureQueued then
        return
    end

    captureQueued = true
    local function Run()
        captureQueued = false
        CaptureCurrentCharacter()
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(tonumber(delay) or 0.05, Run)
    else
        Run()
    end
end

local function RequestCurrentData()
    if type(RequestRaidInfo) == "function" then
        pcall(RequestRaidInfo)
    end
    if C_MythicPlus then
        if type(C_MythicPlus.RequestMapInfo) == "function" then
            pcall(C_MythicPlus.RequestMapInfo)
        end
        if type(C_MythicPlus.RequestRewards) == "function" then
            pcall(C_MythicPlus.RequestRewards)
        end
    end

    ScheduleCapture(0.10)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.90, function()
            ScheduleCapture(0)
        end)
    end
end

function ns:GetWarbandWeeklyCharacters()
    local db = EnsureDB()
    local result = {}
    if not db then
        return result
    end

    local now = GetNow()
    local currentMaxLevel = CallNumber(GetMaxLevelForPlayerExpansion)
    local showLevelingCharacters = db.showLevelingCharacters == true

    for key, snapshot in pairs(db.characters) do
        if type(snapshot) == "table" and SafeString(snapshot.name) then
            local level = SafeNumber(snapshot.level) or 0
            local isCurrent = key == currentCharacterKey
            local visible = showLevelingCharacters or isCurrent or not currentMaxLevel or level >= currentMaxLevel
            if visible then
                local view = {}
                for field, value in pairs(snapshot) do
                    view[field] = value
                end
                view.key = key
                view.isCurrent = isCurrent
                view.weeklyExpired = SafeNumber(snapshot.resetAt) ~= nil and now >= snapshot.resetAt
                result[#result + 1] = view
            end
        end
    end

    table.sort(result, function(left, right)
        if left.isCurrent ~= right.isCurrent then
            return left.isCurrent
        end
        local leftLevel = SafeNumber(left.level) or 0
        local rightLevel = SafeNumber(right.level) or 0
        if leftLevel ~= rightLevel then
            return leftLevel > rightLevel
        end
        local leftName = string.lower(SafeString(left.name) or "")
        local rightName = string.lower(SafeString(right.name) or "")
        if leftName ~= rightName then
            return leftName < rightName
        end
        return (SafeString(left.realm) or "") < (SafeString(right.realm) or "")
    end)
    return result
end

function ns:GetWarbandWeeklyShowLevelingCharacters()
    local db = EnsureDB()
    return db and db.showLevelingCharacters == true
end

function ns:SetWarbandWeeklyShowLevelingCharacters(value)
    local db = EnsureDB()
    if not db then
        return
    end
    db.showLevelingCharacters = value == true
    NotifyDashboard()
end

function ns:GetWarbandWeeklyResetAt()
    return GetWeeklyResetAt(GetNow())
end

function ns:RequestWarbandWeeklyRefresh()
    RequestCurrentData()
end

function ns:InitializeWarbandWeekly()
    EnsureDB()
    local key = GetCharacterIdentity()
    currentCharacterKey = key

    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD",
        "PLAYER_EQUIPMENT_CHANGED",
        "PLAYER_LEVEL_UP",
        "PLAYER_SPECIALIZATION_CHANGED",
        "UPDATE_INSTANCE_INFO",
        "WEEKLY_REWARDS_UPDATE",
        "MYTHIC_PLUS_NEW_WEEKLY_RECORD",
        "CHALLENGE_MODE_COMPLETED",
        "BOSS_KILL",
        "ENCOUNTER_END",
    }) do
        eventFrame:RegisterEvent(event)
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then
            return
        end

        if event == "PLAYER_ENTERING_WORLD" or event == "BOSS_KILL"
            or event == "ENCOUNTER_END" or event == "CHALLENGE_MODE_COMPLETED" then
            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(1, RequestCurrentData)
            else
                RequestCurrentData()
            end
        else
            ScheduleCapture(event == "PLAYER_EQUIPMENT_CHANGED" and 0.35 or 0.05)
        end
    end)

    RequestCurrentData()
end
