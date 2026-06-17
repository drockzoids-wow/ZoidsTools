local _, ns = ...

local frame
local initialized = false
local sellQueue
local sellQueueIndex = 1

local REPAIR_DISABLED = "disabled"
local REPAIR_PERSONAL = "personal"
local REPAIR_GUILD = "guild"
local BIND_ON_EQUIP = 2
local SELL_INTERVAL = 0.1

local repairModes = {
    [REPAIR_DISABLED] = true,
    [REPAIR_PERSONAL] = true,
    [REPAIR_GUILD] = true,
}

local function EnsureVendorDB()
    if not ns.db then
        return nil
    end

    ns.db.vendor = ns.db.vendor or {}

    if ns.db.vendor.autoSellGrey == nil then
        ns.db.vendor.autoSellGrey = false
    end

    if ns.db.vendor.autoSellBoEGrey == nil then
        ns.db.vendor.autoSellBoEGrey = false
    end

    if not repairModes[ns.db.vendor.autoRepairMode] then
        ns.db.vendor.autoRepairMode = REPAIR_DISABLED
    end

    return ns.db.vendor
end

local function FormatMoney(amount)
    amount = tonumber(amount) or 0

    if GetCoinTextureString then
        return GetCoinTextureString(amount)
    end

    return tostring(amount) .. " copper"
end

local function GetBagIds()
    local bags = {}
    local maxBag = NUM_BAG_SLOTS or 4

    for bag = 0, maxBag do
        bags[#bags + 1] = bag
    end

    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        bags[#bags + 1] = Enum.BagIndex.ReagentBag
    end

    return bags
end

local function GetContainerNumSlotsSafe(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    elseif GetContainerNumSlots then
        return GetContainerNumSlots(bag) or 0
    end

    return 0
end

local function GetContainerItemLinkSafe(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    elseif GetContainerItemLink then
        return GetContainerItemLink(bag, slot)
    end
end

local function GetContainerItemInfoSafe(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)

        if info then
            return info.quality, info.isLocked, info.hasNoValue, info.hyperlink or GetContainerItemLinkSafe(bag, slot), info.isBound
        end
    elseif GetContainerItemInfo then
        local _, _, locked, quality, _, _, link, _, noValue, _, isBound = GetContainerItemInfo(bag, slot)

        return quality, locked, noValue, link, isBound
    end
end

local function UseContainerItemSafe(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        return pcall(C_Container.UseContainerItem, bag, slot)
    elseif UseContainerItem then
        return pcall(UseContainerItem, bag, slot)
    end

    return false
end

local function GetItemBindType(link)
    if not link then
        return nil
    end

    if C_Item and C_Item.GetItemInfo then
        local info = { C_Item.GetItemInfo(link) }

        if info[14] then
            return info[14]
        end
    elseif GetItemInfo then
        local info = { GetItemInfo(link) }

        if info[14] then
            return info[14]
        end
    end

    return nil
end

local function IsBindOnEquip(link)
    return GetItemBindType(link) == BIND_ON_EQUIP
end

local function IsEquippableItemLink(link)
    if not link then
        return false
    end

    local equipLocation

    if C_Item and C_Item.GetItemInfoInstant then
        equipLocation = select(4, C_Item.GetItemInfoInstant(link))
    elseif GetItemInfoInstant then
        equipLocation = select(4, GetItemInfoInstant(link))
    end

    return type(equipLocation) == "string" and equipLocation ~= ""
end

local function ShouldSellGreyItem(includeBoE, link, isBound)
    if includeBoE or isBound then
        return true
    end

    if IsBindOnEquip(link) then
        return false
    end

    if GetItemBindType(link) == nil and IsEquippableItemLink(link) then
        return false
    end

    return true
end

local function ShouldSellGreySlot(bag, slot, includeBoE)
    local quality, locked, noValue, link, isBound = GetContainerItemInfoSafe(bag, slot)

    return quality == 0 and not locked and not noValue and ShouldSellGreyItem(includeBoE, link, isBound)
end

local function BuildGreySellQueue(includeBoE)
    local items = {}

    for _, bag in ipairs(GetBagIds()) do
        local slots = GetContainerNumSlotsSafe(bag)

        for slot = 1, slots do
            if ShouldSellGreySlot(bag, slot, includeBoE) then
                items[#items + 1] = {
                    bag = bag,
                    slot = slot,
                }
            end
        end
    end

    return items
end

local function IsMerchantOpen()
    return MerchantFrame and MerchantFrame:IsShown()
end

local function ProcessSellQueue()
    if not sellQueue then
        return
    end

    if not IsMerchantOpen() then
        sellQueue = nil
        sellQueueIndex = 1
        return
    end

    while sellQueue and sellQueueIndex <= #sellQueue do
        local item = sellQueue[sellQueueIndex]
        sellQueueIndex = sellQueueIndex + 1

        if item and ShouldSellGreySlot(item.bag, item.slot, sellQueue.includeBoE == true) then
            UseContainerItemSafe(item.bag, item.slot)
            break
        end
    end

    if not sellQueue or sellQueueIndex > #sellQueue then
        sellQueue = nil
        sellQueueIndex = 1
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(SELL_INTERVAL, ProcessSellQueue)
    else
        ProcessSellQueue()
    end
end

local function StartSellQueue(items, includeBoE)
    if not items or #items == 0 then
        return 0
    end

    sellQueue = items
    sellQueue.includeBoE = includeBoE == true
    sellQueueIndex = 1
    ProcessSellQueue()

    return #items
end

local function SellGreyItems()
    local db = EnsureVendorDB()

    if not db or db.autoSellGrey ~= true then
        return
    end

    local includeBoE = db.autoSellBoEGrey == true

    return StartSellQueue(BuildGreySellQueue(includeBoE), includeBoE)
end

local function RepairWithPersonalGold(cost)
    if GetMoney and GetMoney() < cost then
        ns:Print("Auto repair skipped. Not enough gold for " .. FormatMoney(cost) .. ".")
        return
    end

    if RepairAllItems and pcall(RepairAllItems, false) then
        ns:Print("Repaired for " .. FormatMoney(cost) .. ".")
    end
end

local function RepairWithGuildBank(cost)
    if IsInGuild and not IsInGuild() then
        ns:Print("Guild repair skipped. You are not in a guild.")
        return
    end

    if not CanGuildBankRepair or not CanGuildBankRepair() then
        ns:Print("Guild repair skipped. Guild bank repair is not available.")
        return
    end

    if RepairAllItems and pcall(RepairAllItems, true) then
        ns:Print("Repaired for " .. FormatMoney(cost) .. " from the guild bank.")
    end
end

local function AutoRepair()
    local db = EnsureVendorDB()

    if not db or db.autoRepairMode == REPAIR_DISABLED then
        return
    end

    if not CanMerchantRepair or not CanMerchantRepair() then
        return
    end

    if not GetRepairAllCost then
        return
    end

    local cost, canRepair = GetRepairAllCost()

    if not canRepair or not cost or cost <= 0 then
        return
    end

    if db.autoRepairMode == REPAIR_GUILD then
        RepairWithGuildBank(cost)
    elseif db.autoRepairMode == REPAIR_PERSONAL then
        RepairWithPersonalGold(cost)
    end
end

local function RunVendorAutomation()
    local sellCount = SellGreyItems() or 0
    local repairDelay = sellCount > 0 and ((sellCount * SELL_INTERVAL) + 0.15) or 0.1

    if C_Timer and C_Timer.After then
        C_Timer.After(repairDelay, AutoRepair)
    else
        AutoRepair()
    end
end

function ns:SetAutoSellGreyItems(value)
    local db = EnsureVendorDB()

    if not db then
        return
    end

    db.autoSellGrey = value == true
end

function ns:GetAutoSellGreyItems()
    local db = EnsureVendorDB()

    return db and db.autoSellGrey == true
end

function ns:SetAutoSellBoEGreyItems(value)
    local db = EnsureVendorDB()

    if not db then
        return
    end

    db.autoSellBoEGrey = value == true
end

function ns:GetAutoSellBoEGreyItems()
    local db = EnsureVendorDB()

    return db and db.autoSellBoEGrey == true
end

function ns:SetAutoRepairMode(value)
    local db = EnsureVendorDB()

    if not db then
        return
    end

    db.autoRepairMode = repairModes[value] and value or REPAIR_DISABLED
end

function ns:GetAutoRepairMode()
    local db = EnsureVendorDB()

    return db and db.autoRepairMode or REPAIR_DISABLED
end

function ns:GetAutoRepairModeOptions()
    return {
        { value = REPAIR_DISABLED, text = "Disabled" },
        { value = REPAIR_PERSONAL, text = "Use My Gold" },
        { value = REPAIR_GUILD, text = "Use Guild Bank" },
    }
end

function ns:InitializeVendorAutomation()
    EnsureVendorDB()

    if initialized then
        return
    end

    initialized = true
    frame = CreateFrame("Frame")
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:SetScript("OnEvent", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, RunVendorAutomation)
        else
            RunVendorAutomation()
        end
    end)
end
