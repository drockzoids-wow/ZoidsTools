local _, ns = ...

local selections = { bags = -1, bank = -1, warbandBank = -1 }
local hookedFrames, dropdowns, pendingItems = {}, {}, {}
local queued, initialized = false, false
local Refresh
local names = {
    [0] = "Classic", "The Burning Crusade", "Wrath of the Lich King", "Cataclysm",
    "Mists of Pandaria", "Warlords of Draenor", "Legion", "Battle for Azeroth",
    "Shadowlands", "Dragonflight", "The War Within", "Midnight",
}

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function ExpansionName(id)
    if id == -1 then return "All expansions" end
    if id == -2 then return "Unknown expansion" end
    local name = _G["EXPANSION_NAME" .. id] or names[id] or ("Expansion " .. id)
    return id == 9 and ("Dragon Isles (" .. name .. ")") or name
end

-- Use the item's own expansion metadata, never its scaled item level.
function ns:GetItemExpansionID(item)
    if IsSecret(item) or not item or not C_Item or not C_Item.GetItemInfo then return nil end
    local result = { pcall(C_Item.GetItemInfo, item) }
    if not result[1] then return nil end
    local id = result[16] -- pcall status + the fifteenth GetItemInfo return value
    if IsSecret(id) then return nil end
    if type(id) == "number" and id >= 0 and id < 254 then return id end
    if not result[2] and C_Item.RequestLoadItemDataByID then
        local itemID = type(item) == "number" and item or tonumber(item:match("item:(%d+)"))
        if itemID and not pendingItems[itemID] then
            pendingItems[itemID] = true
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end
    return nil
end

function ns:AddItemExpansionTooltip(tooltip, item)
    if not ns.db or (ns.db.items and ns.db.items.enabled == false) then return end
    local id = self:GetItemExpansionID(item)
    if id == nil then id = -2 end
    local icon = ""
    if id >= 0 and GetExpansionDisplayInfo then
        local ok, info = pcall(GetExpansionDisplayInfo, id)
        if ok and info and info.logo then
            icon = "|T" .. info.logo .. ":16:32:0:0|t "
        end
    end
    tooltip:AddLine(icon .. "From: " .. ExpansionName(id), 0.65, 0.8, 0.9, true)
end

local function QueueRefresh()
    if queued then return end
    queued = true
    C_Timer.After(0.05, function()
        queued = false
        Refresh()
    end)
end

local function BankKind(frame)
    return Enum and Enum.BankType and frame.bankType == Enum.BankType.Account and "warbandBank" or "bank"
end

local function ApplyButton(button, kind)
    local bag = button.GetBankTabID and button:GetBankTabID() or (button.GetBagID and button:GetBagID())
    local slot = button.GetContainerSlotID and button:GetContainerSlotID() or (button.GetID and button:GetID())
    if IsSecret(bag) or IsSecret(slot) or bag == nil or slot == nil then return end
    local item = C_Container.GetContainerItemLink(bag, slot)
    local selected = selections[kind]
    local dim = false
    if not IsSecret(item) and item and selected ~= -1 then
        local id = ns:GetItemExpansionID(item)
        dim = selected == -2 and id ~= nil or selected ~= -2 and id ~= selected
    end
    if not button.ZTExpansionShade then
        if not dim or (InCombatLockdown and InCombatLockdown()) then return end
        -- A separate overlay composes with Blizzard search without changing its
        -- match flag, icon tint, alpha, or the protected item's mouse handling.
        local shade = button:CreateTexture(nil, "OVERLAY", nil, 7)
        shade:SetAllPoints(button)
        shade:SetColorTexture(0, 0, 0, 0.78)
        button.ZTExpansionShade = shade
    end
    button.ZTExpansionShade:SetShown(dim)
end

local function EnsureDropdown(parent, key, anchor, compact)
    local dropdown = dropdowns[key]
    if not dropdown then
        if InCombatLockdown and InCombatLockdown() then return end
        dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        dropdown:SetWidth(compact and 145 or 190)
        dropdown:SetupMenu(function(_, root)
            root:CreateTitle("Filter by expansion")
            local kind = key == "bank" and BankKind(BankPanel) or "bags"
            local function Add(id)
                root:CreateRadio(ExpansionName(id), function() return selections[kind] == id end, function()
                    selections[kind] = id
                    QueueRefresh()
                end)
            end
            Add(-1)
            for id = math.max(11, LE_EXPANSION_LEVEL_CURRENT or 0), 0, -1 do Add(id) end
            Add(-2)
        end)
        dropdowns[key] = dropdown
    end
    if not (InCombatLockdown and InCombatLockdown()) then
        dropdown:SetWidth(compact and 145 or 190)
        dropdown:SetParent(parent)
        dropdown:ClearAllPoints()
        if key == "bank" then
            -- Keep both bank views clear of the centered tab name.
            dropdown:SetPoint("LEFT", parent, "TOPLEFT", 64, -43)
        elseif compact then
            -- Individual bags have no spare search-row width.
            dropdown:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 10, 2)
        else
            dropdown:SetPoint("LEFT", parent, "TOPLEFT", 8, -46)
            anchor:ClearAllPoints()
            anchor:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -40, -37)
            anchor:SetWidth(math.max(80, parent:GetWidth() - 300))
        end
    end
    local kind = key == "bank" and BankKind(BankPanel) or "bags"
    if dropdown.ZTKind ~= kind or dropdown.ZTSelection ~= selections[kind] then
        dropdown.ZTKind, dropdown.ZTSelection = kind, selections[kind]
        dropdown:SetDefaultText(ExpansionName(selections[kind]))
        dropdown:GenerateMenu()
    end
    dropdown:Show()
end

local function Visit(frame, kind)
    if not frame or not frame:IsShown() then return end
    if frame.EnumerateValidItems then
        for first, second in frame:EnumerateValidItems() do
            -- Bags return index/button; bank pools return button/true.
            local button = type(first) == "number" and second or first
            ApplyButton(button, kind)
        end
    end
end

local function HookFrame(frame)
    if not frame or hookedFrames[frame] then return end
    hookedFrames[frame] = true
    frame:HookScript("OnShow", QueueRefresh)
    for _, method in ipairs({ "UpdateItems", "UpdateSearchBox", "GenerateItemSlotsForSelectedTab", "RefreshAllItemsForSelectedTab", "UpdateSearchResults" }) do
        if type(frame[method]) == "function" then hooksecurefunc(frame, method, QueueRefresh) end
    end
end

Refresh = function()
    HookFrame(ContainerFrameCombinedBags)
    Visit(ContainerFrameCombinedBags, "bags")
    if ContainerFrameContainer and ContainerFrameContainer.ContainerFrames then
        for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do
            HookFrame(frame)
            Visit(frame, "bags")
        end
    end
    HookFrame(BankPanel)
    if BankPanel then Visit(BankPanel, BankKind(BankPanel)) end
    if InCombatLockdown and InCombatLockdown() then return end
    local search = BagItemSearchBox
    if search and search:IsShown() then
        local parent = search:GetParent()
        EnsureDropdown(parent, "bags", search, parent ~= ContainerFrameCombinedBags)
    elseif dropdowns.bags then
        dropdowns.bags:Hide()
    end
    if BankPanel and BankPanel:IsShown() and BankItemSearchBox then
        EnsureDropdown(BankFrame or BankPanel, "bank", BankItemSearchBox)
    elseif dropdowns.bank then
        dropdowns.bank:Hide()
    end
end

function ns:InitializeItemExpansions()
    if initialized then return end
    initialized = true
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED", "PLAYER_REGEN_ENABLED", "ITEM_DATA_LOAD_RESULT" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function(_, event, itemID)
        if event == "ITEM_DATA_LOAD_RESULT" then
            if pendingItems[itemID] ~= true then return end
            -- Keep the request marker even on failure: don't retry forever.
            pendingItems[itemID] = "complete"
        end
        QueueRefresh()
    end)
    QueueRefresh()
end
