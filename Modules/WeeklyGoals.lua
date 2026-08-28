local _, ns = ...

local TIDAL_SPARK_DUST_CURRENCY_ID = 3509

local eventFrame
local refreshQueued = false

local GOAL_ORDER = { "vault", "spark", "lair", "seasonal", "housing", "timewalking", "professions" }
local GOAL_INFO = {
    vault = { text = "Great Vault progress", shortText = "Great Vault", default = true },
    spark = { text = "Spark of Tides catch-up", shortText = "Spark", default = true },
    lair = { text = "Current Lair boss", shortText = "Lair boss", default = true },
    seasonal = { text = "Patch 12.1 weekly quests", shortText = "12.1 weeklies", default = true },
    housing = { text = "Player Housing weekly", shortText = "Housing", default = true },
    timewalking = { text = "Timewalking weekly event", shortText = "Timewalking", default = true },
    professions = { text = "Profession Knowledge goals", shortText = "Professions", default = true },
}

local SEASONAL_QUESTS = {
    { id = 93744, name = "Unity Against the Void" },
    { id = 98172, name = "Trailing Xal'atath" },
    { id = 96995, name = "Turn Back the Surge" },
}

local HOUSING_QUESTS = {
    { id = 95440, name = "Housewarming" },
    { id = 95413, name = "Community Engagement" },
    { id = 95416, name = "Going Postal" },
}

-- Current Midnight versions of the recurring Timewalking cache quests.
local TIMEWALKING_QUESTS = {
    { id = 93608, name = "A Burning Path Through Time" },
    { id = 93610, name = "A Frozen Path Through Time" },
    { id = 93611, name = "A Shattered Path Through Time" },
    { id = 93612, name = "A Shrouded Path Through Time" },
    { id = 93613, name = "A Savage Path Through Time" },
    { id = 93614, name = "A Fel Path Through Time" },
    { id = 93627, name = "A Scarred Path Through Time" },
}

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function SafeNumber(value)
    return not IsSecretValue(value) and type(value) == "number" and value or nil
end

local function SafeBoolean(value)
    return not IsSecretValue(value) and type(value) == "boolean" and value or nil
end

local function SafeString(value)
    return not IsSecretValue(value) and type(value) == "string" and value ~= "" and value or nil
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.weeklyGoals = type(ns.db.weeklyGoals) == "table" and ns.db.weeklyGoals or {}
    local db = ns.db.weeklyGoals
    db.goals = type(db.goals) == "table" and db.goals or {}
    if db.hideCompleted == nil then
        db.hideCompleted = false
    end

    for _, goalID in ipairs(GOAL_ORDER) do
        if db.goals[goalID] == nil then
            db.goals[goalID] = GOAL_INFO[goalID].default == true
        end
    end
    return db
end

local function IsQuestComplete(questID)
    if not questID or not C_QuestLog or type(C_QuestLog.IsQuestFlaggedCompleted) ~= "function" then
        return false
    end

    local ok, complete = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    return ok and SafeBoolean(complete) == true
end

local function IsQuestOnLog(questID)
    if not questID or not C_QuestLog or type(C_QuestLog.IsOnQuest) ~= "function" then
        return false
    end

    local ok, onQuest = pcall(C_QuestLog.IsOnQuest, questID)
    return ok and SafeBoolean(onQuest) == true
end

local function GetQuestObjectiveProgress(questID)
    if not C_QuestLog or type(C_QuestLog.GetQuestObjectives) ~= "function" then
        return nil, nil
    end

    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or IsSecretValue(objectives) or type(objectives) ~= "table" then
        return nil, nil
    end

    local current = 0
    local total = 0
    for _, objective in ipairs(objectives) do
        if not IsSecretValue(objective) and type(objective) == "table" then
            local required = SafeNumber(objective.numRequired)
            local fulfilled = SafeNumber(objective.numFulfilled)
            if required and required > 0 and fulfilled then
                total = total + math.max(0, math.floor(required))
                current = current + math.max(0, math.min(math.floor(required), math.floor(fulfilled)))
            end
        end
    end

    if total <= 0 then
        return nil, nil
    end
    return current, total
end

local function EvaluateQuest(quest)
    local complete = IsQuestComplete(quest.id)
    local onQuest = not complete and IsQuestOnLog(quest.id)
    local current, total
    if onQuest then
        current, total = GetQuestObjectiveProgress(quest.id)
    end

    return {
        id = quest.id,
        name = quest.name,
        complete = complete,
        onQuest = onQuest,
        current = current,
        total = total,
    }
end

local function FormatQuestStatus(status)
    if status.complete then
        return "Done"
    elseif status.current and status.total then
        return string.format("%d/%d", status.current, status.total)
    elseif status.onQuest then
        return "In progress"
    end
    return "Not started"
end

local function EvaluateQuestGroup(definitions, requireAll)
    local result = {
        entries = {},
        completed = 0,
        total = #definitions,
        active = nil,
    }

    for _, definition in ipairs(definitions) do
        local status = EvaluateQuest(definition)
        result.entries[#result.entries + 1] = status
        if status.complete then
            result.completed = result.completed + 1
        elseif status.onQuest and not result.active then
            result.active = status
        end
    end

    if requireAll then
        result.complete = result.total > 0 and result.completed >= result.total
    else
        result.complete = result.completed > 0
    end
    return result
end

local function GetCurrentWarbandSnapshot()
    if type(ns.GetWarbandWeeklyCharacters) ~= "function" then
        return nil
    end

    local ok, characters = pcall(ns.GetWarbandWeeklyCharacters, ns)
    if not ok or type(characters) ~= "table" then
        return nil
    end

    for _, snapshot in ipairs(characters) do
        if type(snapshot) == "table" and snapshot.isCurrent == true then
            return snapshot
        end
    end
    return nil
end

local function GetVaultCategoryProgress(category)
    if type(category) ~= "table" or type(category.slots) ~= "table" then
        return 0, 0, 0, 0
    end

    local progress = 0
    local threshold = 0
    for _, slot in ipairs(category.slots) do
        if type(slot) == "table" then
            progress = math.max(progress, math.floor(SafeNumber(slot.progress) or 0))
            threshold = math.max(threshold, math.floor(SafeNumber(slot.threshold) or 0))
        end
    end
    return progress, threshold, math.floor(SafeNumber(category.unlocked) or 0), math.floor(SafeNumber(category.total) or 0)
end

local function EvaluateVault(snapshot)
    local vault = snapshot and type(snapshot.vault) == "table" and snapshot.vault or nil
    local result = {
        available = vault and vault.hasData == true or false,
        rewardAvailable = vault and vault.rewardAvailable == true or false,
        categories = {},
        unlocked = 0,
        total = 0,
    }

    for _, categoryInfo in ipairs({
        { key = "raid", label = "Raid" },
        { key = "dungeons", label = "Dungeons" },
        { key = "world", label = "World" },
    }) do
        local progress, threshold, unlocked, total = GetVaultCategoryProgress(vault and vault[categoryInfo.key])
        local category = {
            key = categoryInfo.key,
            label = categoryInfo.label,
            progress = progress,
            threshold = threshold,
            unlocked = unlocked,
            total = total,
            complete = total > 0 and unlocked >= total,
        }
        result.categories[#result.categories + 1] = category
        result.unlocked = result.unlocked + unlocked
        result.total = result.total + total
    end

    result.complete = result.available and result.total > 0 and result.unlocked >= result.total and not result.rewardAvailable
    return result
end

local function EvaluateSpark()
    local result = { known = false, current = 0, total = 0, complete = false }
    if not C_CurrencyInfo or type(C_CurrencyInfo.GetCurrencyInfo) ~= "function" then
        return result
    end

    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, TIDAL_SPARK_DUST_CURRENCY_ID)
    if not ok or IsSecretValue(info) or type(info) ~= "table" then
        return result
    end

    local quantity = SafeNumber(info.quantity)
    local maximum = SafeNumber(info.maxQuantity)
    if quantity == nil or maximum == nil or maximum <= 0 then
        return result
    end

    result.known = true
    result.current = math.max(0, math.floor(quantity))
    result.total = math.max(0, math.floor(maximum))
    result.complete = result.current >= result.total
    return result
end

local function EvaluateLair(snapshot)
    local complete = IsQuestComplete(97128)
    local savedDifficulty
    local lockouts = snapshot and type(snapshot.lockouts) == "table" and snapshot.lockouts or nil
    for _, lockout in ipairs(lockouts and lockouts.raids or {}) do
        if type(lockout) == "table" then
            local name = SafeString(lockout.name)
            local progress = SafeNumber(lockout.progress) or 0
            if name and string.find(string.lower(name), "tidebound grotto", 1, true) and progress > 0 then
                complete = true
                savedDifficulty = SafeString(lockout.difficultyName)
                break
            end
        end
    end

    return {
        complete = complete,
        onQuest = not complete and IsQuestOnLog(97128),
        savedDifficulty = savedDifficulty,
    }
end

local function GetActiveTimewalkingTitle()
    if not C_DateAndTime or type(C_DateAndTime.GetCurrentCalendarTime) ~= "function"
        or not C_Calendar or type(C_Calendar.GetNumDayEvents) ~= "function"
        or type(C_Calendar.GetDayEvent) ~= "function" then
        return nil
    end

    local timeOK, calendarTime = pcall(C_DateAndTime.GetCurrentCalendarTime)
    if not timeOK or IsSecretValue(calendarTime) or type(calendarTime) ~= "table" then
        return nil
    end
    local monthDay = SafeNumber(calendarTime.monthDay)
    if not monthDay then
        return nil
    end

    local countOK, count = pcall(C_Calendar.GetNumDayEvents, 0, math.floor(monthDay))
    count = countOK and SafeNumber(count) or nil
    if not count then
        return nil
    end

    for index = 1, math.floor(count) do
        local eventOK, event = pcall(C_Calendar.GetDayEvent, 0, math.floor(monthDay), index)
        if eventOK and not IsSecretValue(event) and type(event) == "table" then
            local title = SafeString(event.title)
            local calendarType = SafeString(event.calendarType)
            if title and calendarType == "HOLIDAY" and string.find(string.lower(title), "timewalking", 1, true) then
                return title
            end
        end
    end
    return nil
end

local function EvaluateTimewalking()
    local group = EvaluateQuestGroup(TIMEWALKING_QUESTS, false)
    group.eventTitle = GetActiveTimewalkingTitle()
    group.available = group.eventTitle ~= nil or group.active ~= nil or group.complete
    return group
end

local function GetSnapshot()
    local currentCharacter = GetCurrentWarbandSnapshot()
    return {
        currentCharacter = currentCharacter,
        vault = EvaluateVault(currentCharacter),
        spark = EvaluateSpark(),
        lair = EvaluateLair(currentCharacter),
        seasonal = EvaluateQuestGroup(SEASONAL_QUESTS, true),
        housing = EvaluateQuestGroup(HOUSING_QUESTS, false),
        timewalking = EvaluateTimewalking(),
    }
end

local function StatusColor(complete, ready, unavailable)
    if unavailable then
        return "|cff888888"
    elseif complete then
        return "|cff59dd7a"
    elseif ready then
        return "|cffffc857"
    end
    return "|cffc9c9c9"
end

local function AddLine(lines, hideCompleted, info)
    if hideCompleted and info.complete and info.canHide ~= false then
        return
    end
    lines[#lines + 1] = info
end

local function BuildVaultLines(lines, hideCompleted, vault)
    if not vault.available then
        AddLine(lines, hideCompleted, {
            text = "|cff888888Great Vault: Data unavailable|r",
            complete = false,
            tooltipTitle = "Great Vault",
            tooltipLines = { "Great Vault progress will appear after Blizzard returns weekly activity data." },
        })
        return
    end

    if not (hideCompleted and vault.complete) then
        local headerColor = StatusColor(vault.complete, vault.unlocked > 0, false)
        lines[#lines + 1] = {
            text = string.format("|cffffd34eGreat Vault|r  %s%d/%d slots|r", headerColor, vault.unlocked, vault.total),
            complete = vault.complete,
            tooltipTitle = "Great Vault",
            tooltipLines = {
                "Unlock choices by completing current raid, dungeon, and world activities.",
                "Only one reward can be selected after the weekly reset.",
            },
        }

        for _, category in ipairs(vault.categories) do
            if category.total > 0 and not (hideCompleted and category.complete) then
                local color = StatusColor(category.complete, category.unlocked > 0, false)
                lines[#lines + 1] = {
                    text = string.format("   %s%s: %d/%d slots  (%d/%d)|r", color, category.label, category.unlocked, category.total, category.progress, category.threshold),
                    complete = category.complete,
                    tooltipTitle = category.label .. " Great Vault",
                    tooltipLines = {
                        string.format("%d of %d reward choices unlocked.", category.unlocked, category.total),
                        string.format("Current activity progress: %d/%d for the final choice.", category.progress, category.threshold),
                    },
                }
            end
        end
    end

    if vault.rewardAvailable then
        lines[#lines + 1] = {
            text = "   |cffff6b6bPrevious Vault reward: Unclaimed|r",
            complete = false,
            canHide = false,
            tooltipTitle = "Unclaimed Great Vault reward",
            tooltipLines = { "A reward from the previous week is waiting in the Great Vault." },
        }
    end
end

local function BuildQuestGroupTooltip(title, group, description)
    local tooltipLines = { description }
    for _, status in ipairs(group.entries or {}) do
        local color = status.complete and "|cff59dd7a" or (status.onQuest and "|cffffc857" or "|cffc9c9c9")
        tooltipLines[#tooltipLines + 1] = string.format("%s%s: %s|r", color, status.name, FormatQuestStatus(status))
    end
    return title, tooltipLines
end

local function BuildTrackerLines()
    local db = EnsureDB()
    if not db then
        return {}
    end

    local snapshot = GetSnapshot()
    local hideCompleted = db.hideCompleted == true
    local lines = {}

    if db.goals.vault == true then
        BuildVaultLines(lines, hideCompleted, snapshot.vault)
    end

    if db.goals.spark == true then
        local spark = snapshot.spark
        AddLine(lines, hideCompleted, {
            text = spark.known
                and string.format("%sSpark of Tides cap: %d/%d|r", StatusColor(spark.complete, spark.current > 0, false), spark.current, spark.total)
                or "|cff888888Spark of Tides cap: Unavailable|r",
            complete = spark.complete,
            tooltipTitle = "Spark of Tides catch-up",
            tooltipLines = {
                "Tidal Spark Dust records how many Season 2 Sparks this character has earned against the current catch-up cap.",
                "The cap grows during the season; this is not the number of unspent Sparks in your bags.",
            },
        })
    end

    if db.goals.lair == true then
        local lair = snapshot.lair
        AddLine(lines, hideCompleted, {
            text = string.format(
                "%sNymrissa (Lair): %s|r",
                StatusColor(lair.complete, lair.onQuest, false),
                lair.complete and (lair.savedDifficulty and ("Done - " .. lair.savedDifficulty) or "Done") or (lair.onQuest and "In progress" or "Not done")
            ),
            complete = lair.complete,
            tooltipTitle = "Nymrissa Wavecaller",
            tooltipLines = {
                "Tracks the current Tidebound Grotto Lair boss for this character.",
                "A saved kill on any detected difficulty also counts as complete.",
            },
        })
    end

    if db.goals.seasonal == true then
        local seasonal = snapshot.seasonal
        local title, tooltipLines = BuildQuestGroupTooltip(
            "Patch 12.1 weekly quests",
            seasonal,
            "Tracks the recurring Silvermoon and Coiled Isle weekly objectives."
        )
        AddLine(lines, hideCompleted, {
            text = string.format("%sPatch 12.1 weeklies: %d/%d|r", StatusColor(seasonal.complete, seasonal.active ~= nil or seasonal.completed > 0, false), seasonal.completed, seasonal.total),
            complete = seasonal.complete,
            tooltipTitle = title,
            tooltipLines = tooltipLines,
        })
    end

    if db.goals.housing == true then
        local housing = snapshot.housing
        local statusText = housing.complete and "Done"
            or (housing.active and FormatQuestStatus(housing.active))
            or "Not done"
        local title, tooltipLines = BuildQuestGroupTooltip(
            "Player Housing weekly",
            housing,
            "The rotating Vaeli quest is Warband-limited and can be completed once per account each week."
        )
        AddLine(lines, hideCompleted, {
            text = string.format("%sHousing weekly: %s|r", StatusColor(housing.complete, housing.active ~= nil, false), statusText),
            complete = housing.complete,
            tooltipTitle = title,
            tooltipLines = tooltipLines,
        })
    end

    if db.goals.timewalking == true and snapshot.timewalking.available then
        local timewalking = snapshot.timewalking
        local statusText = timewalking.complete and "Done"
            or (timewalking.active and FormatQuestStatus(timewalking.active))
            or "Pick up weekly quest"
        local title, tooltipLines = BuildQuestGroupTooltip(
            timewalking.eventTitle or "Timewalking weekly event",
            timewalking,
            "Complete the current Timewalking cache quest from the Adventure Guide or event quest giver."
        )
        AddLine(lines, hideCompleted, {
            text = string.format("%sTimewalking weekly: %s|r", StatusColor(timewalking.complete, timewalking.active ~= nil, false), statusText),
            complete = timewalking.complete,
            tooltipTitle = title,
            tooltipLines = tooltipLines,
        })
    end

    return lines, snapshot
end

local function NotifyTracker()
    if type(ns.RequestProfessionWeeklyRefresh) == "function" then
        ns:RequestProfessionWeeklyRefresh()
    elseif ns.UI2 and type(ns.UI2.RefreshProfessionWeeklyDashboard) == "function" then
        ns.UI2.RefreshProfessionWeeklyDashboard()
    end
end

local function ScheduleRefresh(delay)
    if refreshQueued then
        return
    end
    refreshQueued = true

    local function Run()
        refreshQueued = false
        NotifyTracker()
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(tonumber(delay) or 0.20, Run)
    else
        Run()
    end
end

function ns:GetWeeklyGoalTrackerLines()
    local lines = BuildTrackerLines()
    return lines
end

function ns:GetWeeklyGoalsSnapshot()
    local _, snapshot = BuildTrackerLines()
    return snapshot
end

function ns:GetWeeklyGoalOptions()
    local options = {}
    for _, goalID in ipairs(GOAL_ORDER) do
        local info = GOAL_INFO[goalID]
        options[#options + 1] = {
            value = goalID,
            text = info.text,
            shortText = info.shortText,
        }
    end
    return options
end

function ns:GetWeeklyGoalEnabled(goalID)
    local db = EnsureDB()
    return db and db.goals[goalID] == true
end

function ns:SetWeeklyGoalEnabled(goalID, value)
    local db = EnsureDB()
    if not db or not GOAL_INFO[goalID] then
        return
    end
    db.goals[goalID] = value == true
    NotifyTracker()
end

function ns:GetWeeklyGoalsHideCompleted()
    local db = EnsureDB()
    return db and db.hideCompleted == true
end

function ns:SetWeeklyGoalsHideCompleted(value)
    local db = EnsureDB()
    if not db then
        return
    end
    db.hideCompleted = value == true
    NotifyTracker()
end

function ns:RequestWeeklyGoalsRefresh()
    if type(ns.RequestWarbandWeeklyRefresh) == "function" then
        ns:RequestWarbandWeeklyRefresh()
    end
    ScheduleRefresh(0.25)
end

function ns:InitializeWeeklyGoals()
    EnsureDB()

    if eventFrame then
        return
    end
    eventFrame = CreateFrame("Frame")
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD",
        "QUEST_LOG_UPDATE",
        "QUEST_TURNED_IN",
        "CURRENCY_DISPLAY_UPDATE",
        "WEEKLY_REWARDS_UPDATE",
        "UPDATE_INSTANCE_INFO",
        "BOSS_KILL",
    }) do
        eventFrame:RegisterEvent(event)
    end
    eventFrame:SetScript("OnEvent", function(_, event)
        ScheduleRefresh(event == "PLAYER_ENTERING_WORLD" and 1.25 or 0.25)
    end)
end
