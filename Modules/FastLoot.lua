local _, ns = ...

local frame = CreateFrame("Frame")
local initialized = false
local activeLoot = false
local sweepQueued = false
local lootCycle = 0
local AUTO_LOOT_DEFAULT = "autoLootDefault"

local function GetCVarValue(name)
    if C_CVar and type(C_CVar.GetCVar) == "function" then
        return C_CVar.GetCVar(name)
    elseif type(GetCVar) == "function" then
        return GetCVar(name)
    end
end

local function SetCVarValue(name, value)
    if C_CVar and type(C_CVar.SetCVar) == "function" then
        local ok = pcall(C_CVar.SetCVar, name, value)
        return ok == true
    elseif type(SetCVar) == "function" then
        local ok = pcall(SetCVar, name, value)
        return ok == true
    end

    return false
end

local function IsTruthyCVar(value)
    return value == "1" or value == 1 or value == true or value == "true"
end

local function GetBlizzardAutoLootEnabled()
    if type(GetCVarBool) == "function" then
        return GetCVarBool(AUTO_LOOT_DEFAULT) == true
    end

    return IsTruthyCVar(GetCVarValue(AUTO_LOOT_DEFAULT))
end

local function EnableBlizzardAutoLoot()
    if not GetBlizzardAutoLootEnabled() then
        SetCVarValue(AUTO_LOOT_DEFAULT, "1")
    end
end

local function GetLootDB()
    ns.db.loot = ns.db.loot or {}

    if ns.db.loot.fastLoot == nil then
        ns.db.loot.fastLoot = true
    end

    if ns.db.loot.carefulMode == nil then
        ns.db.loot.carefulMode = false
    end

    if ns.db.loot.carefulDelay == nil then
        ns.db.loot.carefulDelay = 0.12
    end

    return ns.db.loot
end

local function GetAutoLootIntent(eventAutoLoot)
    if type(eventAutoLoot) == "boolean" then
        return eventAutoLoot
    end

    local autoLootDefault = GetBlizzardAutoLootEnabled()
    local autoLootToggle = IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") or false

    return autoLootDefault ~= autoLootToggle
end

local function LootSlotSafely(slot)
    if type(slot) ~= "number" or not LootSlot then
        return
    end

    local locked

    if GetLootSlotInfo then
        local _
        _, _, _, _, _, locked = GetLootSlotInfo(slot)
    end

    if locked then
        return
    end

    LootSlot(slot)
end

local function FastLootSlots(cycle)
    if cycle ~= lootCycle then
        return
    end

    sweepQueued = false

    if not activeLoot or not ns.db or not ns.db.loot.fastLoot or not GetNumLootItems then
        return
    end

    local numLootItems = GetNumLootItems() or 0

    for slot = numLootItems, 1, -1 do
        LootSlotSafely(slot)
    end
end

local function QueueSweep(delay, cycle)
    if sweepQueued and delay == 0 then
        return
    end

    if delay == 0 then
        sweepQueued = true
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay, function()
            FastLootSlots(cycle)
        end)
    else
        FastLootSlots(cycle)
    end
end

local function QueueFastLoot(eventAutoLoot)
    local db = GetLootDB()

    if not db.fastLoot or not GetAutoLootIntent(eventAutoLoot) then
        activeLoot = false
        return
    end

    activeLoot = true
    local cycle = lootCycle

    QueueSweep(0, cycle)

    if db.carefulMode then
        QueueSweep(math.max(0.05, tonumber(db.carefulDelay) or 0.12), cycle)
    end
end

function ns:SetFastLootEnabled(value)
    local db = GetLootDB()

    db.fastLoot = value == true

    if db.fastLoot then
        EnableBlizzardAutoLoot()
    end
end

function ns:GetFastLootEnabled()
    local db = GetLootDB()

    return db and db.fastLoot == true
end

function ns:GetBlizzardAutoLootEnabled()
    return GetBlizzardAutoLootEnabled()
end

function ns:InitializeFastLoot()
    local db = GetLootDB()

    if db.fastLoot then
        EnableBlizzardAutoLoot()
    end

    if initialized then
        return
    end

    initialized = true

    frame:RegisterEvent("LOOT_READY")
    frame:RegisterEvent("LOOT_CLOSED")
    frame:SetScript("OnEvent", function(_, event, eventAutoLoot)
        if event == "LOOT_CLOSED" then
            lootCycle = lootCycle + 1
            activeLoot = false
            sweepQueued = false
        else
            QueueFastLoot(eventAutoLoot)
        end
    end)
end
