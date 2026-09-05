local _, ns = ...

local initialized = false
local loadedClassToken

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

local EQUIP_LOCATION_SLOTS = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17, 16 },
    INVTYPE_HOLDABLE = { 17 },
    INVTYPE_SHIELD = { 17 },
    INVTYPE_RANGED = { 16 },
    INVTYPE_RANGEDRIGHT = { 16 },
}

local RANK_COLORS = {
    [1] = { 1.00, 0.55, 0.10 },
    [2] = { 1.00, 0.92, 0.10 },
    [3] = { 0.35, 1.00, 0.45 },
}

local function NormalizeBiSContext(value)
    return value == "raid" and "raid" or "mythicplus"
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.items = ns.db.items or {}

    if ns.db.items.bisEnabled == nil then
        ns.db.items.bisEnabled = true
    end

    ns.db.items.bisContext = NormalizeBiSContext(ns.db.items.bisContext)

    return ns.db.items
end

local function GetConfiguredBiSContext()
    local db = EnsureDB()
    return db and NormalizeBiSContext(db.bisContext) or "mythicplus"
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
    if type(UnitClass) ~= "function" then
        return nil, nil, nil
    end

    local _, classToken = UnitClass("player")
    local specIndex = type(GetSpecialization) == "function" and GetSpecialization() or nil
    local specKey = classToken and specIndex and SPEC_KEYS[classToken] and SPEC_KEYS[classToken][specIndex]
    local specName

    if specIndex and type(GetSpecializationInfo) == "function" then
        local _, localizedName = GetSpecializationInfo(specIndex)
        specName = localizedName

        local normalized = NormalizeSpecName(localizedName)
        local root = ns.BiSData
        if root and root.data and root.data[classToken] and root.data[classToken][normalized] then
            specKey = normalized
        end
    end

    return classToken, specKey, specName or specKey
end

local function RetainPlayerClassData()
    local root = ns.BiSData
    if type(root) ~= "table" or type(root.data) ~= "table" or type(UnitClass) ~= "function" then
        return
    end

    local _, classToken = UnitClass("player")
    if not classToken then
        return
    end

    loadedClassToken = classToken

    -- Generated files keep each class behind a loader function. Lua creates the
    -- small set of functions when the file loads, but it only constructs the
    -- nested item tables for the class this character can actually use.
    if type(root.classLoaders) == "table" then
        local loader = root.classLoaders[classToken]
        root.data = {}
        if type(loader) == "function" then
            local ok, classData = pcall(loader)
            if ok and type(classData) == "table" then
                root.data[classToken] = classData
            elseif ns.Print then
                ns:Print("BiS data for " .. tostring(classToken) .. " could not be loaded.")
            end
        end
        root.classLoaders = nil
        return
    end

    for candidateToken in pairs(root.data) do
        if candidateToken ~= classToken then
            root.data[candidateToken] = nil
        end
    end
end

local function GetItemEquipLocation(itemLink)
    if not itemLink or (issecretvalue and issecretvalue(itemLink)) then
        return nil
    end

    local getter = C_Item and C_Item.GetItemInfoInstant
    if type(getter) ~= "function" then
        return nil
    end

    local ok, _, _, _, equipLocation = pcall(getter, itemLink)
    if ok
        and type(equipLocation) == "string"
        and not (issecretvalue and issecretvalue(equipLocation))
    then
        return equipLocation
    end

    return nil
end

local function GetRecommendations(itemLink)
    local db = EnsureDB()
    if not db or db.enabled == false or db.bisEnabled ~= true then
        return nil
    end

    local root = ns.BiSData
    if type(root) ~= "table" or type(root.data) ~= "table" then
        return nil
    end

    local classToken, specKey, specName = GetClassAndSpec()
    -- Use the same normalized SavedVariables value displayed by the settings
    -- dropdown. There is no separate tooltip default or cached context.
    local context = GetConfiguredBiSContext()
    local contextData = classToken
        and specKey
        and root.data[classToken]
        and root.data[classToken][specKey]
        and root.data[classToken][specKey][context]

    if type(contextData) ~= "table" then
        return nil
    end

    local slots = EQUIP_LOCATION_SLOTS[GetItemEquipLocation(itemLink)]
    if type(slots) ~= "table" then
        return nil
    end

    for _, slotID in ipairs(slots) do
        if type(contextData[slotID]) == "table" and #contextData[slotID] > 0 then
            return contextData[slotID], context, specName
        end
    end

    return nil
end

local function ResetTooltipState(tooltip)
    if tooltip then
        tooltip.ZoidsToolsBiSApplied = nil
    end
end

local function ApplyBiSTooltip(tooltip)
    if not tooltip or tooltip.ZoidsToolsBiSApplied or type(tooltip.GetItem) ~= "function" then
        return
    end

    local ok, _, itemLink = pcall(tooltip.GetItem, tooltip)
    if not ok then
        return
    end

    local recommendations, context, specName = GetRecommendations(itemLink)
    if type(recommendations) ~= "table" then
        return
    end

    tooltip.ZoidsToolsBiSApplied = true
    tooltip:AddLine(" ")
    tooltip:AddLine(
        string.format("ZoidsTools BiS - %s - %s", tostring(specName or "Current Spec"), context == "raid" and "Raid" or "Mythic+"),
        1.00,
        0.82,
        0.00
    )

    for index, item in ipairs(recommendations) do
        if index > 3 then
            break
        end

        local rank = tonumber(item.rank) or index
        local itemName = item.name or item[2]
        local itemSource = item.source or item[3]
        local prefix = rank == 1 and "BiS" or ("#" .. rank)
        local color = RANK_COLORS[rank] or { 1, 1, 1 }
        tooltip:AddLine(prefix .. " - " .. tostring(itemName or "Unknown Item"), color[1], color[2], color[3])

        if type(itemSource) == "string" and itemSource ~= "" then
            tooltip:AddLine("    Source: " .. itemSource, 0.68, 0.68, 0.68, true)
        end
    end
end

function ns:GetBiSTooltipsEnabled()
    local db = EnsureDB()
    return db and db.bisEnabled == true
end

function ns:SetBiSTooltipsEnabled(value)
    local db = EnsureDB()
    if db then
        db.bisEnabled = value == true
    end
end

function ns:GetBiSContext()
    return GetConfiguredBiSContext()
end

function ns:SetBiSContext(value)
    local db = EnsureDB()
    if db then
        db.bisContext = NormalizeBiSContext(value)
    end
end

function ns:GetBiSDataStatusText()
    local root = ns.BiSData
    if type(root) ~= "table" or type(root.data) ~= "table" or not next(root.data) then
        return "BiS rankings: no generated data yet.\nRun UpdateAll.cmd, then reload WoW."
    end

    local specCount = 0
    for _, classData in pairs(root.data) do
        if type(classData) == "table" then
            for _, specData in pairs(classData) do
                if type(specData) == "table" then
                    specCount = specCount + 1
                end
            end
        end
    end

    local updated = type(root.generatedAt) == "string" and root.generatedAt ~= "" and root.generatedAt or "unknown"
    local contextLabel = GetConfiguredBiSContext() == "raid" and "Raid" or "Mythic+"
    return string.format(
        "BiS rankings loaded: %d %s specs\nBiS tooltip selection: %s\nGearInsight last updated: %s",
        specCount,
        tostring(loadedClassToken or "current-class"),
        contextLabel,
        updated
    )
end

function ns:InitializeBiSTooltips()
    if initialized then
        return
    end

    EnsureDB()
    RetainPlayerClassData()

    if not TooltipDataProcessor
        or type(TooltipDataProcessor.AddTooltipPostCall) ~= "function"
        or not Enum
        or not Enum.TooltipDataType
        or not Enum.TooltipDataType.Item
    then
        return
    end

    initialized = true

    if type(TooltipDataProcessor.AddTooltipPreCall) == "function" then
        TooltipDataProcessor.AddTooltipPreCall(TooltipDataProcessor.AllTypes, ResetTooltipState)
    end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ApplyBiSTooltip)
end
