local _, ns = ...

local initialized, bankOpen, queued, currentKey
local dirtyBags, dirtyBank = true, false
local itemIndex
local worldActive, loggingOut = true, false

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function Safe(value, kind)
    return not IsSecret(value) and type(value) == kind
end

local function DB()
    ns.db.warbandItems = ns.db.warbandItems or { characters = {}, account = {}, tooltips = true }
    return ns.db.warbandItems
end

local function Character()
    local key = UnitGUID("player")
    if not Safe(key, "string") then return end
    currentKey = key
    local db = DB()
    local name, realm = UnitFullName("player")
    local _, class = UnitClass("player")
    db.characters[key] = db.characters[key] or { containers = {} }
    local character = db.characters[key]
    character.name = name or "Unknown"
    character.realm = realm and realm ~= "" and realm or GetRealmName()
    character.class = class
    return character
end

-- Build a complete replacement first. Unavailable/restricted data must never
-- erase a previously readable bank snapshot.
local function ScanContainer(bag, label, requireSlots)
    local slots = C_Container.GetContainerNumSlots(bag)
    if not Safe(slots, "number") or slots < 0 or (requireSlots and slots == 0) then return end
    local snapshot = { label = label, items = {} }
    for slot = 1, slots do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if IsSecret(info) then return end
        if info then
            if not Safe(info.itemID, "number") or not Safe(info.stackCount, "number") then return end
            local id = info.itemID
            local item = snapshot.items[id] or { count = 0 }
            item.count = item.count + info.stackCount
            if Safe(info.hyperlink, "string") then
                item.name = info.hyperlink:match("%[(.-)%]") or item.name
            end
            snapshot.items[id] = item
        end
    end
    return snapshot
end

local function ScanBags(character)
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do
        local snapshot = ScanContainer(bag, "Bags")
        if snapshot then character.containers["bag" .. bag] = snapshot end
    end
    local equipped = { label = "Equipped", items = {} }
    for slot = 1, 19 do
        local id = GetInventoryItemID("player", slot)
        if IsSecret(id) then return end
        if Safe(id, "number") then
            local item = equipped.items[id] or { count = 0 }
            item.count = item.count + 1
            local link = GetInventoryItemLink("player", slot)
            if Safe(link, "string") then item.name = link:match("%[(.-)%]") end
            equipped.items[id] = item
        end
    end
    character.containers.equipped = equipped
end

local function ScanBank(target, bankType)
    if not bankOpen or not C_Bank.CanViewBank(bankType) then return end
    local reason = C_Bank.FetchBankLockedReason(bankType)
    if IsSecret(reason) or (reason ~= nil and reason ~= Enum.BankLockedReason.None) then return end
    local tabs = C_Bank.FetchPurchasedBankTabData(bankType)
    if not Safe(tabs, "table") then return end
    for index, tab in ipairs(tabs) do
        if Safe(tab.ID, "number") then
            local label = (bankType == Enum.BankType.Account and "Warband bank " or "Bank ") .. index
            if Safe(tab.name, "string") and tab.name ~= "" then label = label .. ": " .. tab.name end
            local snapshot = ScanContainer(tab.ID, label, true)
            if snapshot then target["bank" .. tab.ID] = snapshot end
        end
    end
end

local function Notify()
    itemIndex = nil
    if ns.UI2 and ns.UI2.RefreshWarbandItems then ns.UI2.RefreshWarbandItems() end
end

local function Capture()
    if loggingOut or not worldActive or InCombatLockdown() or (not dirtyBags and not dirtyBank) then return end
    local character = Character()
    if not character then return end
    if dirtyBags then
        dirtyBags = false
        ScanBags(character)
    end
    if dirtyBank then
        dirtyBank = false
        ScanBank(character.containers, Enum.BankType.Character)
        ScanBank(DB().account, Enum.BankType.Account)
    end
    Notify()
end

local function Queue()
    if queued or loggingOut or not worldActive then return end
    queued = true
    C_Timer.After(0.2, function()
        queued = false
        Capture()
    end)
end

local function GetIndex()
    if itemIndex then return itemIndex end
    itemIndex = {}
    local function Add(containers, key, owner, class)
        for containerKey, snapshot in pairs(containers) do
            for id, item in pairs(snapshot.items) do
                if item.count > 0 then
                    local entry = itemIndex[id] or { id = id, count = 0, locations = {} }
                    entry.name = entry.name or item.name
                    entry.count = entry.count + item.count
                    -- Merge bag counts for each character, retain distinct bank tabs.
                    local locationKey = key .. ":" .. snapshot.label
                    local location = entry.locations[locationKey] or {
                        key = key, owner = owner, class = class, label = snapshot.label,
                        count = 0, kind = containerKey == "equipped" and "Equipped"
                            or containerKey:match("^bag") and "Bags" or "Bank",
                    }
                    location.count = location.count + item.count
                    entry.locations[locationKey] = location
                    itemIndex[id] = entry
                end
            end
        end
    end
    for key, character in pairs(DB().characters) do
        Add(character.containers, key, character.name .. "-" .. character.realm, character.class)
    end
    Add(DB().account, "account", "Warband", nil)
    return itemIndex
end

function ns:GetWarbandItemLocations(id)
    local entry = GetIndex()[id]
    local locations = {}
    for _, location in pairs(entry and entry.locations or {}) do locations[#locations + 1] = location end
    table.sort(locations, function(a, b)
        if a.key ~= b.key then
            if a.key == currentKey then return true end
            if b.key == currentKey then return false end
            if a.owner ~= b.owner then return a.owner < b.owner end
            return a.key < b.key
        end
        return a.label < b.label
    end)
    return locations, entry and entry.count or 0
end

function ns:SearchWarbandItems(query, expansion)
    query = (query or ""):lower()
    local result = {}
    for id, entry in pairs(GetIndex()) do
        local name = entry.name or ("Item " .. id)
        local matches = name:lower():find(query, 1, true) or tostring(id) == query
        if matches and (not expansion or expansion == -1 or
            (ns.GetItemExpansionID and ns:GetItemExpansionID(id) == expansion)) then
            result[#result + 1] = { id = id, name = name, count = entry.count }
        end
    end
    table.sort(result, function(a, b)
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    return result
end

function ns:GetWarbandItemCharacters()
    local result = {}
    for key, character in pairs(DB().characters) do
        result[#result + 1] = { key = key, name = character.name .. "-" .. character.realm }
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function ns:ForgetWarbandItemCharacter(key)
    if key == currentKey then return false end
    DB().characters[key] = nil
    Notify()
    return true
end

function ns:GetWarbandItemTooltipsEnabled() return DB().tooltips ~= false end
function ns:SetWarbandItemTooltipsEnabled(value) DB().tooltips = value == true end

function ns:AddWarbandItemTooltip(tooltip, id)
    if not Safe(id, "number") then return end
    local locations, total = self:GetWarbandItemLocations(id)
    if total == 0 then return end
    tooltip:AddLine(" ")
    local function Count(label, count)
        return "|cff80bfff" .. label .. ":|r " .. count
    end
    tooltip:AddDoubleLine("Inventory", Count("Total", total), 1, 0.82, 0, 1, 1, 1)
    local owners, ordered, names = {}, {}, {}
    for _, location in ipairs(locations) do
        local owner = owners[location.key]
        if not owner then
            local character = DB().characters[location.key]
            owner = { key = location.key, name = character and character.name or "Warband",
                realm = character and character.realm, class = location.class, counts = {} }
            owners[location.key] = owner
            ordered[#ordered + 1] = owner
            names[owner.name] = (names[owner.name] or 0) + 1
        end
        owner.counts[location.kind] = (owner.counts[location.kind] or 0) + location.count
    end
    -- Keep the shared bank after the character rows.
    table.sort(ordered, function(a, b)
        if a.key == b.key then return false end
        if a.key == "account" then return false end
        if b.key == "account" then return true end
        if a.key == currentKey then return true end
        if b.key == currentKey then return false end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    for _, owner in ipairs(ordered) do
        local counts = {}
        for _, kind in ipairs({ "Bags", "Bank", "Equipped" }) do
            if owner.counts[kind] then counts[#counts + 1] = Count(kind, owner.counts[kind]) end
        end
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[owner.class]
        local label = owner.name
        if names[label] > 1 and owner.realm then label = label .. "-" .. owner.realm end
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[owner.class]
        if coords then
            label = string.format("|TInterface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes:16:16:0:0:256:256:%d:%d:%d:%d|t ",
                coords[1] * 256, coords[2] * 256, coords[3] * 256, coords[4] * 256) .. label
        elseif owner.key == "account" then
            label = "|TInterface\\Icons\\Spell_Fire_Fire:16:16|t " .. label
        end
        tooltip:AddDoubleLine(label, table.concat(counts, ", "), color and color.r or 1,
            color and color.g or 0.82, color and color.b or 0, 1, 1, 1)
    end
end

function ns:InitializeWarbandItems()
    if initialized then return end
    initialized = true
    local db = DB()
    -- Drop obsolete timestamps from previously recorded characters and banks.
    for _, character in pairs(db.characters) do
        for _, snapshot in pairs(character.containers) do snapshot.updated = nil end
    end
    for _, snapshot in pairs(db.account) do snapshot.updated = nil end
    local frame = CreateFrame("Frame")
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD",
        "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
        "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "BANK_TABS_CHANGED", "BANK_TAB_SETTINGS_UPDATED",
        "PLAYER_REGEN_ENABLED", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT" }) do frame:RegisterEvent(event) end
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGOUT" then
            -- Inventory APIs can already be empty during logout. SavedVariables
            -- retain the last event-driven scan without a final rescan.
            loggingOut = true
            return
        elseif loggingOut then
            return
        elseif event == "PLAYER_LEAVING_WORLD" then
            worldActive, bankOpen = false, false
            return
        elseif event == "PLAYER_ENTERING_WORLD" then
            worldActive, dirtyBags = true, true
            dirtyBank = bankOpen == true
        elseif event == "BANKFRAME_CLOSED" then
            -- Flush pending changes while bank data is still readable, if the
            -- client retains access during the close notification.
            if dirtyBank then Capture() end
            bankOpen = false
        elseif event == "BANKFRAME_OPENED" then
            bankOpen, dirtyBank = true, true
        elseif event == "PLAYER_REGEN_ENABLED" then
            if not dirtyBags and not dirtyBank then return end
        else
            dirtyBags = true
            dirtyBank = bankOpen == true
        end
        Queue()
    end)
    TooltipDataProcessor.AddTooltipPreCall(TooltipDataProcessor.AllTypes, function(tooltip)
        tooltip.ZTWarbandItemsApplied = nil
    end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip.ZTWarbandItemsApplied or not ns:GetWarbandItemTooltipsEnabled() then return end
        local id = data and data.id
        if not Safe(id, "number") then return end
        tooltip.ZTWarbandItemsApplied = true
        ns:AddWarbandItemTooltip(tooltip, id)
    end)
    Queue()
end
