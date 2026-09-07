local _, ns = ...

local TRACKER_FRAME_NAME = "ZoidsToolsProfessionWeeklyTracker"
local DEFAULT_POINT = "CENTER"
local DEFAULT_RELATIVE_POINT = "CENTER"
local DEFAULT_X = 330
local DEFAULT_Y = 40
local TRACKER_WIDTH = 340 -- Initial size; refreshed to fit the visible content.

local tracker
local eventFrame
local darkmoonStatusTicker
local refreshQueued = false

local GOAL_ORDER = { "trainer", "treatise", "field", "darkmoon", "catchup", "onetime" }
local GOAL_INFO = {
    trainer = { text = "Trainer weekly quest", shortText = "Trainer" },
    treatise = { text = "Profession treatise", shortText = "Treatise" },
    field = { text = "Weekly knowledge drops", shortText = "Drops" },
    darkmoon = { text = "Darkmoon Faire quest", shortText = "Darkmoon" },
    catchup = { text = "Catch-up knowledge", shortText = "Catch-up" },
    onetime = { text = "One-time Midnight knowledge", shortText = "One-time" },
}

-- Midnight 12.1 profession objectives. Quest flags are checked read-only so the
-- tracker never interacts with Blizzard's protected profession-order controls.
local PROFESSIONS = {
    {
        key = "alchemy", name = "Alchemy", skillLineID = 171, variantID = 2906,
        catchUpCurrencyID = 3189,
        trainer = { quests = { 93690 }, points = 1 },
        treatise = { quest = 95127, itemID = 245755, points = 1 },
        fieldLabel = "World treasures",
        field = {
            { quest = 93528, itemID = 259188, name = "Lightbloomed Spore Sample", points = 1 },
            { quest = 93529, itemID = 259189, name = "Aged Cruor", points = 1 },
        },
        darkmoonQuest = 29506,
        uniqueTreasures = { 89111, 89112, 89113, 89114, 89115, 89116, 89117, 89118 },
        zuljarraQuest = 96459,
    },
    {
        key = "blacksmithing", name = "Blacksmithing", skillLineID = 164, variantID = 2907,
        catchUpCurrencyID = 3199,
        trainer = { quests = { 93691 }, points = 2 },
        treatise = { quest = 95128, itemID = 245763, points = 1 },
        fieldLabel = "World treasures",
        field = {
            { quest = 93530, itemID = 259190, name = "Thalassian Whetstone", points = 2 },
            { quest = 93531, itemID = 259191, name = "Infused Quenching Oil", points = 2 },
        },
        darkmoonQuest = 29508,
        uniqueTreasures = { 89177, 89178, 89179, 89180, 89181, 89182, 89183, 89184 },
        zuljarraQuest = 96511,
    },
    {
        key = "enchanting", name = "Enchanting", skillLineID = 333, variantID = 2909,
        catchUpCurrencyID = 3198,
        trainer = { quests = { 93697, 93698, 93699 }, points = 3 },
        treatise = { quest = 95129, itemID = 245759, points = 1 },
        fieldLabel = "Treasures + disenchanting",
        field = {
            { quest = 93532, itemID = 259192, name = "Voidstorm Ashes", points = 2 },
            { quest = 93533, itemID = 259193, name = "Lost Thalassian Vellum", points = 2 },
            { quest = 95048, itemID = 267654, name = "Disenchanting knowledge", points = 1 },
            { quest = 95049, itemID = 267654, name = "Disenchanting knowledge", points = 1 },
            { quest = 95050, itemID = 267654, name = "Disenchanting knowledge", points = 1 },
            { quest = 95051, itemID = 267654, name = "Disenchanting knowledge", points = 1 },
            { quest = 95052, itemID = 267654, name = "Disenchanting knowledge", points = 1 },
            { quest = 95053, itemID = 267655, name = "Rare disenchanting knowledge", points = 4 },
        },
        darkmoonQuest = 29510,
        uniqueTreasures = { 89100, 89101, 89102, 89103, 89104, 89105, 89106, 89107 },
        zuljarraQuest = 96512,
    },
    {
        key = "engineering", name = "Engineering", skillLineID = 202, variantID = 2910,
        catchUpCurrencyID = 3197,
        trainer = { quests = { 93692 }, points = 1 },
        treatise = { quest = 95138, itemID = 245809, points = 1 },
        fieldLabel = "World treasures",
        field = {
            { quest = 93534, itemID = 259194, name = "Dance Gear", points = 1 },
            { quest = 93535, itemID = 259195, name = "Dawn Capacitor", points = 1 },
        },
        darkmoonQuest = 29511,
        uniqueTreasures = { 89133, 89134, 89135, 89136, 89137, 89138, 89139, 89140 },
        zuljarraQuest = 96513,
    },
    {
        key = "herbalism", name = "Herbalism", skillLineID = 182, variantID = 2912,
        catchUpCurrencyID = 3196,
        trainer = { quests = { 93700, 93701, 93702, 93703, 93704 }, points = 3 },
        treatise = { quest = 95130, itemID = 245761, points = 1 },
        fieldLabel = "Herbalism knowledge",
        field = {
            { quest = 81425, itemID = 238465, name = "Herbalism knowledge", points = 1 },
            { quest = 81426, itemID = 238465, name = "Herbalism knowledge", points = 1 },
            { quest = 81427, itemID = 238465, name = "Herbalism knowledge", points = 1 },
            { quest = 81428, itemID = 238465, name = "Herbalism knowledge", points = 1 },
            { quest = 81429, itemID = 238465, name = "Herbalism knowledge", points = 1 },
            { quest = 81430, itemID = 238466, name = "Rare herbalism knowledge", points = 4 },
        },
        darkmoonQuest = 29514,
        uniqueTreasures = { 89155, 89156, 89157, 89158, 89159, 89160, 89161, 89162 },
        zuljarraQuest = 96514,
    },
    {
        key = "inscription", name = "Inscription", skillLineID = 773, variantID = 2913,
        catchUpCurrencyID = 3195,
        trainer = { quests = { 93693 }, points = 4 },
        treatise = { quest = 95131, itemID = 245757, points = 1 },
        fieldLabel = "World treasures",
        field = {
            { quest = 93536, itemID = 259196, name = "Brilliant Phoenix Ink", points = 2 },
            { quest = 93537, itemID = 259197, name = "Loa-Blessed Rune", points = 2 },
        },
        darkmoonQuest = 29515,
        uniqueTreasures = { 89067, 89068, 89069, 89070, 89071, 89072, 89073, 89074 },
        zuljarraQuest = 96515,
    },
    {
        key = "jewelcrafting", name = "Jewelcrafting", skillLineID = 755, variantID = 2914,
        catchUpCurrencyID = 3194,
        trainer = { quests = { 93694 }, points = 3 },
        treatise = { quest = 95133, itemID = 245760, points = 1 },
        fieldLabel = "World treasures",
        field = {
            { quest = 93538, itemID = 259198, name = "Void-Touched Eversong Diamond Fragments", points = 2 },
            { quest = 93539, itemID = 259199, name = "Harandar Stone Sample", points = 2 },
        },
        darkmoonQuest = 29516,
        uniqueTreasures = { 89122, 89123, 89124, 89125, 89126, 89127, 89128, 89129 },
        zuljarraQuest = 96516,
    },
    {
        key = "leatherworking", name = "Leatherworking", skillLineID = 165, variantID = 2915,
        catchUpCurrencyID = 3193,
        trainer = { quests = { 93695 }, points = 2 },
        treatise = { quest = 95134, itemID = 245758, points = 1 },
        fieldLabel = "World treasures",
        field = {
            { quest = 93540, itemID = 259200, name = "Amani Tanning Oil", points = 2 },
            { quest = 93541, itemID = 259201, name = "Thalassian Mana Oil", points = 2 },
        },
        darkmoonQuest = 29517,
        uniqueTreasures = { 89089, 89090, 89091, 89092, 89093, 89094, 89095, 89096 },
        zuljarraQuest = 96517,
    },
    {
        key = "mining", name = "Mining", skillLineID = 186, variantID = 2916,
        catchUpCurrencyID = 3192,
        trainer = { quests = { 93705, 93706, 93707, 93708, 93709 }, points = 3 },
        treatise = { quest = 95135, itemID = 245762, points = 1 },
        fieldLabel = "Mining knowledge",
        field = {
            { quest = 88673, itemID = 237496, name = "Mining knowledge", points = 1 },
            { quest = 88674, itemID = 237496, name = "Mining knowledge", points = 1 },
            { quest = 88675, itemID = 237496, name = "Mining knowledge", points = 1 },
            { quest = 88676, itemID = 237496, name = "Mining knowledge", points = 1 },
            { quest = 88677, itemID = 237496, name = "Mining knowledge", points = 1 },
            { quest = 88678, itemID = 237506, name = "Rare mining knowledge", points = 3 },
        },
        darkmoonQuest = 29518,
        uniqueTreasures = { 89144, 89145, 89146, 89147, 89148, 89149, 89150, 89151 },
        zuljarraQuest = 96518,
    },
    {
        key = "skinning", name = "Skinning", skillLineID = 393, variantID = 2917,
        catchUpCurrencyID = 3191,
        trainer = { quests = { 93710, 93711, 93712, 93713, 93714 }, points = 3 },
        treatise = { quest = 95136, itemID = 245828, points = 1 },
        fieldLabel = "Skinning knowledge",
        field = {
            { quest = 88534, itemID = 238625, name = "Skinning knowledge", points = 1 },
            { quest = 88549, itemID = 238625, name = "Skinning knowledge", points = 1 },
            { quest = 88537, itemID = 238625, name = "Skinning knowledge", points = 1 },
            { quest = 88536, itemID = 238625, name = "Skinning knowledge", points = 1 },
            { quest = 88530, itemID = 238625, name = "Skinning knowledge", points = 1 },
            { quest = 88529, itemID = 238626, name = "Rare skinning knowledge", points = 3 },
        },
        darkmoonQuest = 29519,
        uniqueTreasures = { 89166, 89167, 89168, 89169, 89170, 89171, 89172, 89173 },
        zuljarraQuest = 96519,
    },
    {
        key = "tailoring", name = "Tailoring", skillLineID = 197, variantID = 2918,
        catchUpCurrencyID = 3190,
        trainer = { quests = { 93696 }, points = 2 },
        treatise = { quest = 95137, itemID = 245756, points = 1 },
        fieldLabel = "World treasures",
        field = {
            { quest = 93542, itemID = 259202, name = "Embroidered Memento", points = 2 },
            { quest = 93543, itemID = 259203, name = "Finely Woven Lynx Collar", points = 2 },
        },
        darkmoonQuest = 29520,
        uniqueTreasures = { 89078, 89079, 89080, 89081, 89082, 89083, 89084, 89085 },
        zuljarraQuest = 96520,
    },
}

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function SafeNumber(value)
    return not IsSecretValue(value) and type(value) == "number" and value or nil
end

local function SafeString(value)
    return not IsSecretValue(value) and type(value) == "string" and value ~= "" and value or nil
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.professionWeekly = ns.db.professionWeekly or {}
    local db = ns.db.professionWeekly
    db.tracker = type(db.tracker) == "table" and db.tracker or {}
    local trackerDB = db.tracker

    if trackerDB.shown == nil then trackerDB.shown = false end
    if trackerDB.locked == nil then trackerDB.locked = false end
    if trackerDB.minimized == nil then trackerDB.minimized = false end
    trackerDB.point = trackerDB.point or DEFAULT_POINT
    trackerDB.relativePoint = trackerDB.relativePoint or DEFAULT_RELATIVE_POINT
    trackerDB.x = SafeNumber(trackerDB.x) or DEFAULT_X
    trackerDB.y = SafeNumber(trackerDB.y) or DEFAULT_Y
    trackerDB.goals = type(trackerDB.goals) == "table" and trackerDB.goals or {}

    if trackerDB.goals.trainer == nil then trackerDB.goals.trainer = true end
    if trackerDB.goals.treatise == nil then trackerDB.goals.treatise = true end
    if trackerDB.goals.field == nil then trackerDB.goals.field = true end
    if trackerDB.goals.darkmoon == nil then trackerDB.goals.darkmoon = false end
    if trackerDB.goals.catchup == nil then trackerDB.goals.catchup = false end
    if trackerDB.goals.onetime == nil then trackerDB.goals.onetime = false end

    return db
end

local function IsQuestComplete(questID)
    if not questID or not C_QuestLog or type(C_QuestLog.IsQuestFlaggedCompleted) ~= "function" then
        return false
    end

    local ok, complete = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    return ok and not IsSecretValue(complete) and complete == true
end

local function GetItemCount(itemID)
    if not itemID or not C_Item or type(C_Item.GetItemCount) ~= "function" then
        return 0
    end

    local ok, count = pcall(C_Item.GetItemCount, itemID)
    return ok and SafeNumber(count) and math.max(0, math.floor(count)) or 0
end

local function CountCompleted(questIDs)
    local complete = 0
    for _, questID in ipairs(questIDs or {}) do
        if IsQuestComplete(questID) then
            complete = complete + 1
        end
    end
    return complete
end

local function EvaluateTrainer(definition)
    local complete = CountCompleted(definition.quests) > 0
    return {
        id = "trainer",
        label = "Trainer weekly",
        current = complete and 1 or 0,
        total = 1,
        points = complete and definition.points or 0,
        pointsTotal = definition.points,
        complete = complete,
    }
end

local function EvaluateTreatise(definition)
    local complete = IsQuestComplete(definition.quest)
    local ready = not complete and GetItemCount(definition.itemID) > 0
    return {
        id = "treatise",
        label = "Treatise",
        current = complete and 1 or 0,
        total = 1,
        points = complete and definition.points or 0,
        pointsTotal = definition.points,
        complete = complete,
        ready = ready,
    }
end

local function EvaluateField(definition)
    local current = 0
    local points = 0
    local ready = 0
    local entries = {}
    local availableItems = {}

    for _, objective in ipairs(definition.field or {}) do
        local complete = IsQuestComplete(objective.quest)
        if availableItems[objective.itemID] == nil then
            availableItems[objective.itemID] = GetItemCount(objective.itemID)
        end
        local owned = not complete and (availableItems[objective.itemID] or 0) > 0
        if complete then
            current = current + 1
            points = points + (objective.points or 0)
        elseif owned then
            ready = ready + 1
            availableItems[objective.itemID] = availableItems[objective.itemID] - 1
        end
        entries[#entries + 1] = {
            name = objective.name,
            complete = complete,
            ready = owned,
            points = objective.points or 0,
        }
    end

    local totalPoints = 0
    for _, objective in ipairs(definition.field or {}) do
        totalPoints = totalPoints + (objective.points or 0)
    end

    return {
        id = "field",
        label = definition.fieldLabel or "Weekly drops",
        current = current,
        total = #(definition.field or {}),
        points = points,
        pointsTotal = totalPoints,
        complete = current >= #(definition.field or {}),
        ready = ready > 0,
        readyCount = ready,
        entries = entries,
    }
end

local function GetDarkmoonFaireStatus()
    local status = {
        active = false,
        location = "SW",
    }

    -- Retail uses both staging grounds while the Faire is active. Alliance
    -- characters enter near Goldshire (SW); Horde characters enter near
    -- Thunder Bluff (TB).
    if type(UnitFactionGroup) == "function" then
        local factionOK, faction = pcall(UnitFactionGroup, "player")
        if factionOK and not IsSecretValue(faction) and faction == "Horde" then
            status.location = "TB"
        end
    end

    if not C_DateAndTime or type(C_DateAndTime.GetCurrentCalendarTime) ~= "function" then
        return status
    end

    local timeOK, calendarTime = pcall(C_DateAndTime.GetCurrentCalendarTime)
    if not timeOK or IsSecretValue(calendarTime) or type(calendarTime) ~= "table" then
        return status
    end

    local monthDay = SafeNumber(calendarTime.monthDay)
    local weekday = SafeNumber(calendarTime.weekday)
    local hour = SafeNumber(calendarTime.hour)
    local minute = SafeNumber(calendarTime.minute)
    if not monthDay or not weekday or not hour or not minute then
        return status
    end

    monthDay = math.floor(monthDay)
    weekday = math.floor(weekday)
    hour = math.floor(hour)
    minute = math.floor(minute)
    if monthDay < 1 or weekday < 1 or weekday > 7 or hour < 0 or hour > 23 or minute < 0 or minute > 59 then
        return status
    end

    -- The Faire opens at 03:00 realm time on the first Sunday of each month
    -- and remains open for seven days. Calendar weekdays are 1=Sunday.
    local firstWeekday = ((weekday - ((monthDay - 1) % 7) - 1) % 7) + 1
    local firstSunday = 1 + ((8 - firstWeekday) % 7)
    local nowMinutes = (monthDay * 24 * 60) + (hour * 60) + minute
    local startMinutes = (firstSunday * 24 * 60) + (3 * 60)
    status.active = nowMinutes >= startMinutes and nowMinutes < (startMinutes + (7 * 24 * 60))
    return status
end

local function EvaluateDarkmoon(definition)
    local complete = IsQuestComplete(definition.darkmoonQuest)
    local faire = GetDarkmoonFaireStatus()
    return {
        id = "darkmoon",
        label = "Darkmoon Faire",
        current = complete and 1 or 0,
        total = 1,
        points = complete and 3 or 0,
        pointsTotal = 3,
        complete = complete,
        active = faire.active,
        location = faire.location,
    }
end

local function GetCatchUpMethod(professionKey)
    if professionKey == "herbalism" or professionKey == "mining" or professionKey == "skinning" then
        return "gathering"
    elseif professionKey == "enchanting" then
        return "disenchanting"
    end
    return "patron orders"
end

local function EvaluateCatchUp(definition)
    local result = {
        id = "catchup",
        label = "Catch-up backlog",
        known = false,
        complete = false,
        method = GetCatchUpMethod(definition.key),
    }

    if not C_CurrencyInfo or type(C_CurrencyInfo.GetCurrencyInfo) ~= "function" then
        return result
    end

    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, definition.catchUpCurrencyID)
    if not ok or IsSecretValue(info) or type(info) ~= "table" then
        return result
    end

    local maximum = SafeNumber(info.maxQuantity)
    local earned = info.useTotalEarnedForMaxQty and SafeNumber(info.totalEarned) or SafeNumber(info.quantity)
    if maximum == nil or earned == nil then
        return result
    end

    result.known = true
    result.current = math.max(0, math.floor(earned))
    result.total = math.max(0, math.floor(maximum))
    result.remaining = math.max(0, result.total - result.current)
    result.complete = result.remaining == 0
    return result
end

local function EvaluateOneTime(definition)
    local treasureCount = CountCompleted(definition.uniqueTreasures)
    local bookComplete = IsQuestComplete(definition.zuljarraQuest)
    return {
        id = "onetime",
        label = "One-time Midnight",
        current = treasureCount + (bookComplete and 1 or 0),
        total = #(definition.uniqueTreasures or {}) + 1,
        points = (treasureCount * 3) + (bookComplete and 10 or 0),
        pointsTotal = (#(definition.uniqueTreasures or {}) * 3) + 10,
        complete = treasureCount >= #(definition.uniqueTreasures or {}) and bookComplete,
        treasureCurrent = treasureCount,
        treasureTotal = #(definition.uniqueTreasures or {}),
        bookComplete = bookComplete,
    }
end

local function GetOwnedProfessionInfo()
    local owned = {}
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return owned
    end

    local ok, profession1, profession2 = pcall(GetProfessions)
    if not ok then
        return owned
    end

    for _, professionIndex in ipairs({ profession1, profession2 }) do
        if professionIndex then
            local infoOK, name, icon, skillLevel, maxSkillLevel, _, _, skillLineID, skillModifier, _, _, professionName = pcall(GetProfessionInfo, professionIndex)
            skillLineID = infoOK and SafeNumber(skillLineID) or nil
            if skillLineID then
                owned[skillLineID] = {
                    name = SafeString(name),
                    icon = not IsSecretValue(icon) and icon or nil,
                    skillLevel = SafeNumber(skillLevel),
                    maxSkillLevel = SafeNumber(maxSkillLevel),
                    skillModifier = SafeNumber(skillModifier),
                    professionName = SafeString(professionName),
                }
            end
        end
    end
    return owned
end

local function GetVariantInfo(definition, baseInfo)
    local result = {}
    if C_TradeSkillUI and type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function" then
        local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, definition.variantID)
        if ok and not IsSecretValue(info) and type(info) == "table" then
            result.skillLevel = SafeNumber(info.skillLevel)
            result.maxSkillLevel = SafeNumber(info.maxSkillLevel)
            result.skillModifier = SafeNumber(info.skillModifier)
            result.professionName = SafeString(info.professionName)
        end
    end

    if not result.skillLevel then result.skillLevel = baseInfo.skillLevel end
    if not result.maxSkillLevel then result.maxSkillLevel = baseInfo.maxSkillLevel end
    if not result.skillModifier then result.skillModifier = baseInfo.skillModifier end
    if not result.professionName then result.professionName = baseInfo.professionName end

    if C_TradeSkillUI and type(C_TradeSkillUI.GetTradeSkillTexture) == "function" then
        local ok, icon = pcall(C_TradeSkillUI.GetTradeSkillTexture, definition.variantID)
        if ok and not IsSecretValue(icon) then
            result.icon = icon
        end
    end
    result.icon = result.icon or baseInfo.icon
    return result
end

local function GetUnspentKnowledge(variantID)
    if not C_ProfSpecs or type(C_ProfSpecs.GetCurrencyInfoForSkillLine) ~= "function" then
        return 0
    end

    local ok, info = pcall(C_ProfSpecs.GetCurrencyInfoForSkillLine, variantID)
    if not ok or IsSecretValue(info) or type(info) ~= "table" then
        return 0
    end
    return math.max(0, math.floor(SafeNumber(info.numAvailable) or 0))
end

local function BuildProfessionSnapshot(definition, baseInfo)
    local variantInfo = GetVariantInfo(definition, baseInfo)
    local trainerGoal = EvaluateTrainer(definition.trainer)
    local treatiseGoal = EvaluateTreatise(definition.treatise)
    local fieldGoal = EvaluateField(definition)
    local weeklyPoints = trainerGoal.points + treatiseGoal.points + fieldGoal.points
    local weeklyTotal = trainerGoal.pointsTotal + treatiseGoal.pointsTotal + fieldGoal.pointsTotal

    return {
        key = definition.key,
        name = definition.name,
        icon = variantInfo.icon,
        skillLevel = math.max(0, math.floor(variantInfo.skillLevel or 0)),
        maxSkillLevel = math.max(0, math.floor(variantInfo.maxSkillLevel or 0)),
        skillModifier = math.max(0, math.floor(variantInfo.skillModifier or 0)),
        unspentKnowledge = GetUnspentKnowledge(definition.variantID),
        weeklyPoints = weeklyPoints,
        weeklyTotal = weeklyTotal,
        weeklyComplete = weeklyPoints >= weeklyTotal,
        goals = {
            trainer = trainerGoal,
            treatise = treatiseGoal,
            field = fieldGoal,
            darkmoon = EvaluateDarkmoon(definition),
            catchup = EvaluateCatchUp(definition),
            onetime = EvaluateOneTime(definition),
        },
    }
end

local function GetDashboard()
    local owned = GetOwnedProfessionInfo()
    local professions = {}
    local weeklyPoints = 0
    local weeklyTotal = 0

    for _, definition in ipairs(PROFESSIONS) do
        local baseInfo = owned[definition.skillLineID]
        if baseInfo then
            local snapshot = BuildProfessionSnapshot(definition, baseInfo)
            professions[#professions + 1] = snapshot
            weeklyPoints = weeklyPoints + snapshot.weeklyPoints
            weeklyTotal = weeklyTotal + snapshot.weeklyTotal
        end
    end

    table.sort(professions, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)

    return {
        professions = professions,
        weeklyPoints = weeklyPoints,
        weeklyTotal = weeklyTotal,
        weeklyComplete = weeklyTotal > 0 and weeklyPoints >= weeklyTotal,
    }
end

local function GetWeeklyResetAt()
    if not C_DateAndTime or type(C_DateAndTime.GetSecondsUntilWeeklyReset) ~= "function" then
        return nil
    end
    local ok, seconds = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
    seconds = ok and SafeNumber(seconds) or nil
    if not seconds or seconds < 0 or seconds > 8 * 86400 then
        return nil
    end

    local now
    if type(GetServerTime) == "function" then
        local nowOK, value = pcall(GetServerTime)
        now = nowOK and SafeNumber(value) or nil
    end
    return now and math.floor(now + seconds) or nil
end

local function GoalStatusText(goal)
    if goal.id == "catchup" then
        if not goal.known then
            return "Unavailable"
        end
        return goal.complete
            and "Caught up"
            or string.format("%d KP via %s", goal.remaining or 0, goal.method or "profession activities")
    elseif goal.id == "trainer" then
        return string.format("%s (%d KP)", goal.complete and "Done" or "Not done", goal.pointsTotal or 0)
    elseif goal.id == "treatise" then
        if goal.ready and not goal.complete then
            return string.format("Ready to use (%d KP)", goal.pointsTotal or 0)
        end
        return string.format("%d/%d used (%d KP)", goal.current or 0, goal.total or 0, goal.pointsTotal or 0)
    elseif goal.id == "field" then
        local text = string.format(
            "%d/%d items (%d/%d KP)",
            goal.current or 0,
            goal.total or 0,
            goal.points or 0,
            goal.pointsTotal or 0
        )
        if goal.ready and not goal.complete then
            return string.format("%s; %d ready", text, goal.readyCount or 1)
        end
        return text
    elseif goal.id == "onetime" then
        return string.format(
            "%d/%d goals (%d/%d KP)",
            goal.current or 0,
            goal.total or 0,
            goal.points or 0,
            goal.pointsTotal or 0
        )
    elseif goal.id == "darkmoon" then
        return string.format("%d/%d quest (%d KP)", goal.current or 0, goal.total or 0, goal.pointsTotal or 0)
    end

    if goal.ready and not goal.complete then
        return string.format("%d/%d (%s ready)", goal.current or 0, goal.total or 0, goal.readyCount or 1)
    end
    return string.format("%d/%d", goal.current or 0, goal.total or 0)
end

local function GoalColor(goal)
    if goal.id == "catchup" and not goal.known then
        return "|cff888888"
    elseif goal.complete then
        return "|cff59dd7a"
    elseif goal.ready then
        return "|cffffc857"
    end
    return "|cffc9c9c9"
end

local function GetTrackerGoalTooltip(profession, goal)
    if goal.id == "trainer" then
        return "Weekly trainer quest", {
            string.format("Complete your profession trainer's weekly quest for %d Knowledge.", goal.pointsTotal or 0),
            "This resets with the weekly reset.",
        }
    elseif goal.id == "treatise" then
        return "Weekly profession treatise", {
            string.format("Use one Thalassian Treatise for this profession for %d Knowledge.", goal.pointsTotal or 0),
            "Treatises are made by Inscription and can be requested through a crafting order.",
        }
    elseif goal.id == "field" then
        local detail
        if profession.key == "herbalism" or profession.key == "mining" or profession.key == "skinning" then
            detail = "Knowledge items earned while gathering. Finish every listed item each week."
        elseif profession.key == "enchanting" then
            detail = "Weekly Knowledge items earned from world treasures and disenchanting."
        else
            detail = "Weekly Knowledge items found in Midnight world treasures."
        end
        return goal.label or "Weekly Knowledge items", {
            detail,
            string.format("The tracker shows item progress separately from the %d total Knowledge they award.", goal.pointsTotal or 0),
        }
    elseif goal.id == "darkmoon" then
        local availability = goal.active
            and string.format("The Faire is active; use the %s entrance.", goal.location or "SW")
            or "The Faire is currently inactive."
        return "Darkmoon Faire profession quest", {
            string.format("A monthly profession quest worth %d Knowledge and separate from the weekly total.", goal.pointsTotal or 0),
            availability,
        }
    elseif goal.id == "catchup" then
        local methodText
        if goal.method == "gathering" then
            methodText = "Earn bonus 1-Knowledge items while gathering after finishing the normal weekly gathering goals."
        elseif goal.method == "disenchanting" then
            methodText = "Earn bonus 1-Knowledge items from disenchanting after finishing the normal weekly goals."
        else
            methodText = "Earn catch-up Knowledge gradually from eligible patron crafting orders."
        end
        return "Catch-up Knowledge backlog", {
            methodText,
            "This is Blizzard's accumulated catch-up allowance, not a weekly requirement or a number of treatises.",
        }
    elseif goal.id == "onetime" then
        return "One-time Midnight Knowledge", {
            "Eight permanent profession treasures plus the Zul'jarra rank 6 Knowledge book.",
            "These goals do not reset each week.",
        }
    end
    return goal.label or "Profession goal", { "A tracked profession Knowledge objective." }
end

local function SaveTrackerPosition()
    local db = EnsureDB()
    if not db or not tracker then return end

    local point, _, relativePoint, x, y = tracker:GetPoint(1)
    if point then
        db.tracker.point = point
        db.tracker.relativePoint = relativePoint or point
        db.tracker.x = x or 0
        db.tracker.y = y or 0
    end
end

local function RestoreTrackerPosition()
    local db = EnsureDB()
    if not db or not tracker then return end

    tracker:ClearAllPoints()
    tracker:SetPoint(
        db.tracker.point or DEFAULT_POINT,
        UIParent,
        db.tracker.relativePoint or DEFAULT_RELATIVE_POINT,
        db.tracker.x or DEFAULT_X,
        db.tracker.y or DEFAULT_Y
    )
end

local function UpdateTrackerHeaderControls()
    local db = EnsureDB()
    if not db or not tracker or not tracker.hint or not tracker.lockButton then return end

    local locked = db.tracker.locked == true
    tracker.hint:SetText(locked and "Locked" or "Drag to move")
    tracker.lockButton:SetText(locked and "Unlock" or "Lock")
    tracker.lockButton:SetWidth(locked and 48 or 36)
    if tracker.minimizeButton then
        tracker.minimizeButton:SetText(db.tracker.minimized == true and "+" or "-")
    end
end

local function UpdateTrackerWidth(lineCount)
    -- Match the header anchors, with a small gap between the title and hint.
    local width = 12 + tracker.title:GetStringWidth() + 16
        + tracker.hint:GetStringWidth() + 5 + tracker.lockButton:GetWidth()
        + 4 + tracker.minimizeButton:GetWidth() + 8
    for index = 1, lineCount do
        -- Include the 12-pixel left inset and matching right padding.
        width = math.max(width, tracker.lines[index].text:GetStringWidth() + 24)
    end
    tracker:SetWidth(math.ceil(width))
end

local function ApplyTrackerMouseBehavior()
    local db = EnsureDB()
    if not db or not tracker then return end

    local locked = db.tracker.locked == true
    local supportsSplitMouse = type(tracker.SetMouseMotionEnabled) == "function" and type(tracker.SetMouseClickEnabled) == "function"
    if supportsSplitMouse then
        tracker:EnableMouse(true)
        tracker:SetMouseMotionEnabled(true)
        tracker:SetMouseClickEnabled(not locked)
    else
        tracker:EnableMouse(not locked)
    end

    for _, line in ipairs(tracker.lines or {}) do
        if supportsSplitMouse and type(line.SetMouseMotionEnabled) == "function" and type(line.SetMouseClickEnabled) == "function" then
            line:EnableMouse(true)
            line:SetMouseMotionEnabled(true)
            line:SetMouseClickEnabled(not locked)
        else
            line:EnableMouse(not locked)
        end
    end

    -- Keep the small header controls clickable while the rest of a locked
    -- tracker remains click-through.
    for _, button in ipairs({ tracker.lockButton, tracker.minimizeButton }) do
        if button then
            button:EnableMouse(true)
            if type(button.SetMouseMotionEnabled) == "function"
                and type(button.SetMouseClickEnabled) == "function" then
                button:SetMouseMotionEnabled(true)
                button:SetMouseClickEnabled(true)
            end
        end
    end
    UpdateTrackerHeaderControls()
end

local function GetOrCreateTrackerLine(index)
    local line = tracker.lines[index]
    if line then return line end

    line = CreateFrame("Frame", nil, tracker)
    line:SetPoint("TOPLEFT", tracker, "TOPLEFT", 10, -29 - ((index - 1) * 17))
    line:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", -10, -29 - ((index - 1) * 17))
    line:SetHeight(17)
    line:EnableMouse(true)
    line:RegisterForDrag("LeftButton")

    line.text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.text:SetPoint("LEFT", line, "LEFT", 2, 0)
    line.text:SetJustifyH("LEFT")
    line.text:SetWordWrap(false)

    line:SetScript("OnEnter", function(self)
        if not self.tooltipTitle or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipTitle, 1, 0.82, 0.18)
        for _, tooltipLine in ipairs(self.tooltipLines or {}) do
            GameTooltip:AddLine(tooltipLine, 0.82, 0.82, 0.82, true)
        end
        GameTooltip:Show()
    end)
    line:SetScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)
    line:SetScript("OnDragStart", function()
        local db = EnsureDB()
        if db and db.tracker.locked ~= true then
            tracker:StartMoving()
        end
    end)
    line:SetScript("OnDragStop", function()
        tracker:StopMovingOrSizing()
        SaveTrackerPosition()
    end)

    tracker.lines[index] = line
    ApplyTrackerMouseBehavior()
    return line
end

local function UpdateTracker()
    local db = EnsureDB()
    if not db then return end

    if not tracker then
        return
    end

    if db.tracker.shown ~= true then
        tracker:Hide()
        return
    end

    if db.tracker.minimized == true then
        local tooltipOwner = GameTooltip and GameTooltip:GetOwner()
        local hideTrackerTooltip = tooltipOwner == tracker
            or tooltipOwner == tracker.lockButton
            or tooltipOwner == tracker.minimizeButton
        for _, line in ipairs(tracker.lines or {}) do
            if tooltipOwner == line then
                hideTrackerTooltip = true
            end
            line.tooltipTitle = nil
            line.tooltipLines = nil
            line:Hide()
        end
        if hideTrackerTooltip then
            GameTooltip:Hide()
        end
        tracker:SetHeight(36)
        UpdateTrackerHeaderControls()
        UpdateTrackerWidth(0)
        tracker:Show()
        return
    end

    local dashboard = GetDashboard()
    local lines = {}
    if type(ns.GetWeeklyGoalTrackerLines) == "function" then
        local ok, generalLines = pcall(ns.GetWeeklyGoalTrackerLines, ns)
        if ok and type(generalLines) == "table" then
            for _, lineInfo in ipairs(generalLines) do
                lines[#lines + 1] = lineInfo
            end
        end
    end

    local showProfessions = type(ns.GetWeeklyGoalEnabled) ~= "function" or ns:GetWeeklyGoalEnabled("professions")
    local hideCompleted = type(ns.GetWeeklyGoalsHideCompleted) == "function" and ns:GetWeeklyGoalsHideCompleted() or false
    if showProfessions then
        for _, profession in ipairs(dashboard.professions) do
            local professionLines = {}
            for _, goalID in ipairs(GOAL_ORDER) do
                if db.tracker.goals[goalID] == true then
                    local goal = profession.goals[goalID]
                    if goal and not (hideCompleted and goal.complete) then
                        local tooltipTitle, tooltipLines = GetTrackerGoalTooltip(profession, goal)
                        local text
                        if goal.id == "darkmoon" then
                            local activity = goal.active
                                and string.format("|cff59dd7a(Active %s)|r", goal.location or "SW")
                                or "|cffff4d4d(Inactive)|r"
                            text = string.format(
                                "   |cffc9c9c9%s|r %s: %s%s|r",
                                goal.label,
                                activity,
                                GoalColor(goal),
                                GoalStatusText(goal)
                            )
                        else
                            text = string.format("   %s%s: %s|r", GoalColor(goal), goal.label, GoalStatusText(goal))
                        end
                        professionLines[#professionLines + 1] = {
                            text = text,
                            tooltipTitle = tooltipTitle,
                            tooltipLines = tooltipLines,
                        }
                    end
                end
            end

            if not hideCompleted or not profession.weeklyComplete or #professionLines > 0 then
                local weeklyColor = profession.weeklyComplete and "|cff59dd7a" or "|cffffc857"
                lines[#lines + 1] = {
                    text = string.format("|cffffd34e%s weekly|r  %s%d/%d KP|r", profession.name, weeklyColor, profession.weeklyPoints, profession.weeklyTotal),
                    tooltipTitle = profession.name .. " weekly Knowledge",
                    tooltipLines = {
                        "Progress from recurring trainer, treatise, and weekly item goals.",
                        "Darkmoon, catch-up, and one-time Knowledge are tracked separately and do not increase this total.",
                    },
                }
                for _, lineInfo in ipairs(professionLines) do
                    lines[#lines + 1] = lineInfo
                end
            end
        end

        if #dashboard.professions == 0 then
            lines[#lines + 1] = {
                text = "|cffb8b8b8No Midnight professions learned.|r",
                tooltipTitle = "Profession Knowledge",
                tooltipLines = { "Learn a Midnight primary profession to begin tracking Knowledge goals." },
            }
        end
    end

    if #lines == 0 then
        lines[1] = {
            text = "|cff59dd7aAll selected weekly goals complete.|r",
            tooltipTitle = "Weekly Goals",
            tooltipLines = { "Completed entries are currently hidden in the Weekly Goals settings." },
        }
    end

    for index, lineInfo in ipairs(lines) do
        local line = GetOrCreateTrackerLine(index)
        line.text:SetText(lineInfo.text)
        line.tooltipTitle = lineInfo.tooltipTitle
        line.tooltipLines = lineInfo.tooltipLines
        line:Show()
    end
    for index = #lines + 1, #tracker.lines do
        tracker.lines[index].tooltipTitle = nil
        tracker.lines[index].tooltipLines = nil
        tracker.lines[index]:Hide()
    end

    tracker:SetHeight(math.max(50, 39 + (#lines * 17)))
    UpdateTrackerHeaderControls()
    UpdateTrackerWidth(#lines)
    tracker:Show()
end

local function CreateTracker()
    if tracker then return tracker end

    tracker = CreateFrame("Frame", TRACKER_FRAME_NAME, UIParent, "BackdropTemplate")
    tracker:SetSize(TRACKER_WIDTH, 90)
    tracker:SetFrameStrata("MEDIUM")
    tracker:SetFrameLevel(25)
    tracker:SetMovable(true)
    tracker:SetClampedToScreen(true)
    tracker:EnableMouse(true)
    tracker:RegisterForDrag("LeftButton")
    tracker:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 11,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    tracker:SetBackdropColor(0.015, 0.014, 0.012, 0.90)
    tracker:SetBackdropBorderColor(0.88, 0.66, 0.18, 0.68)

    tracker.title = tracker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tracker.title:SetPoint("TOPLEFT", tracker, "TOPLEFT", 12, -10)
    tracker.title:SetTextColor(1, 0.82, 0.18)
    tracker.title:SetText("Weekly Goals")

    tracker.lockButton = CreateFrame("Button", nil, tracker, "UIPanelButtonTemplate")
    tracker.lockButton:SetSize(36, 18)
    tracker.lockButton:SetText("Lock")
    tracker.lockButton:SetNormalFontObject("GameFontNormalSmall")
    tracker.lockButton:SetHighlightFontObject("GameFontHighlightSmall")
    tracker.lockButton:SetDisabledFontObject("GameFontDisableSmall")
    tracker.lockButton:SetScript("OnClick", function()
        local db = EnsureDB()
        if db and ns.SetProfessionWeeklyTrackerLocked then
            ns:SetProfessionWeeklyTrackerLocked(db.tracker.locked ~= true)
        end
    end)

    tracker.minimizeButton = CreateFrame("Button", nil, tracker, "UIPanelButtonTemplate")
    tracker.minimizeButton:SetSize(22, 18)
    tracker.minimizeButton:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", -8, -6)
    tracker.minimizeButton:SetText("-")
    tracker.minimizeButton:SetNormalFontObject("GameFontNormalSmall")
    tracker.minimizeButton:SetHighlightFontObject("GameFontHighlightSmall")
    tracker.minimizeButton:SetDisabledFontObject("GameFontDisableSmall")
    tracker.minimizeButton:SetScript("OnClick", function()
        local db = EnsureDB()
        if db and ns.SetProfessionWeeklyTrackerMinimized then
            ns:SetProfessionWeeklyTrackerMinimized(db.tracker.minimized ~= true)
        end
    end)
    tracker.minimizeButton:SetScript("OnEnter", function(self)
        local db = EnsureDB()
        if not db or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(db.tracker.minimized == true and "Expand Weekly Goals" or "Minimize Weekly Goals")
        GameTooltip:Show()
    end)
    tracker.minimizeButton:SetScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)

    tracker.lockButton:SetPoint("RIGHT", tracker.minimizeButton, "LEFT", -4, 0)

    tracker.hint = tracker:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tracker.hint:SetPoint("RIGHT", tracker.lockButton, "LEFT", -5, 0)
    tracker.hint:SetText("Drag to move")

    tracker.divider = tracker:CreateTexture(nil, "ARTWORK")
    tracker.divider:SetPoint("TOPLEFT", tracker, "TOPLEFT", 10, -27)
    tracker.divider:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", -10, -27)
    tracker.divider:SetHeight(1)
    tracker.divider:SetColorTexture(0.65, 0.52, 0.24, 0.42)
    tracker.lines = {}

    tracker:SetScript("OnDragStart", function(self)
        local db = EnsureDB()
        if db and db.tracker.locked ~= true then
            self:StartMoving()
        end
    end)
    tracker:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveTrackerPosition()
    end)
    tracker:SetScript("OnEnter", function(self)
        local db = EnsureDB()
        if not db or db.tracker.locked == true then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("ZoidsTools Weekly Goals")
        GameTooltip:AddLine("Drag to move. Choose goals, lock, or hide it from /zt > Weekly.", 0.82, 0.82, 0.82, true)
        GameTooltip:Show()
    end)
    tracker:SetScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)

    RestoreTrackerPosition()
    ApplyTrackerMouseBehavior()
    return tracker
end

local function NotifyUI()
    if ns.UI2 and type(ns.UI2.RefreshProfessionWeeklyDashboard) == "function" then
        ns.UI2.RefreshProfessionWeeklyDashboard()
    end
end

local function RefreshAll()
    CreateTracker()
    ApplyTrackerMouseBehavior()
    UpdateTracker()
    NotifyUI()
end

local function ScheduleRefresh(delay)
    if refreshQueued then return end
    refreshQueued = true

    local function Run()
        refreshQueued = false
        RefreshAll()
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(tonumber(delay) or 0.15, Run)
    else
        Run()
    end
end

function ns:GetProfessionWeeklyDashboard()
    return GetDashboard()
end

function ns:GetProfessionWeeklyResetAt()
    return GetWeeklyResetAt()
end

function ns:RequestProfessionWeeklyRefresh()
    ScheduleRefresh(0)
end

function ns:GetProfessionWeeklyGoalOptions()
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

function ns:GetProfessionWeeklyGoalEnabled(goalID)
    local db = EnsureDB()
    return db and db.tracker.goals[goalID] == true
end

function ns:SetProfessionWeeklyGoalEnabled(goalID, value)
    local db = EnsureDB()
    if not db or not GOAL_INFO[goalID] then return end
    db.tracker.goals[goalID] = value == true
    RefreshAll()
end

function ns:IsProfessionWeeklyTrackerShown()
    local db = EnsureDB()
    return db and db.tracker.shown == true
end

function ns:SetProfessionWeeklyTrackerShown(value)
    local db = EnsureDB()
    if not db then return end
    db.tracker.shown = value == true
    RefreshAll()
end

function ns:IsProfessionWeeklyTrackerLocked()
    local db = EnsureDB()
    return db and db.tracker.locked == true
end

function ns:SetProfessionWeeklyTrackerLocked(value)
    local db = EnsureDB()
    if not db then return end
    db.tracker.locked = value == true
    RefreshAll()
end

function ns:IsProfessionWeeklyTrackerMinimized()
    local db = EnsureDB()
    return db and db.tracker.minimized == true
end

function ns:SetProfessionWeeklyTrackerMinimized(value)
    local db = EnsureDB()
    if not db then return end
    db.tracker.minimized = value == true
    RefreshAll()
end

function ns:MoveProfessionWeeklyTracker()
    local db = EnsureDB()
    if not db then return end
    db.tracker.shown = true
    db.tracker.locked = false
    RefreshAll()
end

function ns:ResetProfessionWeeklyTrackerPosition()
    local db = EnsureDB()
    if not db then return end
    db.tracker.point = DEFAULT_POINT
    db.tracker.relativePoint = DEFAULT_RELATIVE_POINT
    db.tracker.x = DEFAULT_X
    db.tracker.y = DEFAULT_Y
    CreateTracker()
    RestoreTrackerPosition()
    RefreshAll()
end

function ns:InitializeProfessionWeekly()
    EnsureDB()
    RefreshAll()

    if eventFrame then return end
    eventFrame = CreateFrame("Frame")
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD",
        "SKILL_LINES_CHANGED",
        "QUEST_TURNED_IN",
        "QUEST_LOG_UPDATE",
        "BAG_UPDATE_DELAYED",
        "CURRENCY_DISPLAY_UPDATE",
        "TRADE_SKILL_LIST_UPDATE",
    }) do
        eventFrame:RegisterEvent(event)
    end
    eventFrame:SetScript("OnEvent", function(_, event)
        ScheduleRefresh(event == "PLAYER_ENTERING_WORLD" and 1 or 0.20)
    end)

    -- Keep a visible tracker current if the Faire opens or closes during a
    -- long play session without requiring a reload.
    if not darkmoonStatusTicker and C_Timer and type(C_Timer.NewTicker) == "function" then
        darkmoonStatusTicker = C_Timer.NewTicker(300, function()
            local db = EnsureDB()
            if db and db.tracker.shown == true then
                ScheduleRefresh(0)
            end
        end)
    end
end
