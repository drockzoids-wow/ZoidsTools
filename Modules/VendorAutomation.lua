local _, ns = ...

local frame
local initialized = false
local sellQueue
local sellQueueIndex = 1
local knownTooltip
local knownMerchantTouched = false
local IsMerchantOpen

local REPAIR_DISABLED = "disabled"
local REPAIR_PERSONAL = "personal"
local REPAIR_GUILD = "guild"
local BIND_ON_EQUIP = 2
local SELL_INTERVAL = 0.1
local MERCHANT_REFRESH_DELAY = 0.05
local ITEM_CLASS_HOUSING = Enum and Enum.ItemClass and Enum.ItemClass.Housing or 20

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

    if ns.db.vendor.knownItemOverlay == nil then
        ns.db.vendor.knownItemOverlay = false
    end

    return ns.db.vendor
end

local function NormalizeTooltipText(text)
    local ok, result = pcall(function()
        text = tostring(text or "")
        text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
        text = text:gsub("|r", "")
        text = text:gsub("^%s+", "")
        text = text:gsub("%s+$", "")
        return string.lower(text)
    end)

    if ok then
        return result
    end

    return ""
end

local function EnsureKnownTooltip()
    if knownTooltip then
        return knownTooltip
    end

    knownTooltip = CreateFrame("GameTooltip", "ZoidsToolsKnownMerchantTooltip", UIParent, "GameTooltipTemplate")
    knownTooltip:SetOwner(UIParent, "ANCHOR_NONE")

    return knownTooltip
end

local function TooltipLineHasKnownText(text)
    local normalized = NormalizeTooltipText(text)

    if normalized == "" then
        return false
    end

    local knownText = NormalizeTooltipText(ITEM_SPELL_KNOWN or "Already Known")
    local cosmeticKnownText = NormalizeTooltipText(ERR_COSMETIC_KNOWN or "")

    return normalized == knownText
        or normalized:find("already known", 1, true) ~= nil
        or (cosmeticKnownText ~= "" and normalized:find(cosmeticKnownText, 1, true) ~= nil)
end

local function TooltipLineHasOwnedHousingText(text)
    local ownedFormat = HOUSING_DECOR_OWNED_COUNT_FORMAT

    if not text or not ownedFormat then
        return false
    end

    local prefix = ownedFormat:match("^(.-)%%[%d%$%.%-]*d")

    if not prefix or prefix == "" then
        return false
    end

    local normalized = NormalizeTooltipText(text)
    local normalizedPrefix = NormalizeTooltipText(prefix)

    if normalizedPrefix == "" or not normalized:find(normalizedPrefix, 1, true) then
        return false
    end

    local ownedCount = tonumber(normalized:match("(%d+)"))
    return ownedCount ~= nil and ownedCount > 0
end

local function TooltipDataHasKnownLine(data, isHousingItem)
    if not data then
        return false
    end

    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, data)
    end

    if type(data.lines) ~= "table" then
        return false
    end

    for _, line in ipairs(data.lines) do
        if TooltipUtil and TooltipUtil.SurfaceArgs then
            pcall(TooltipUtil.SurfaceArgs, line)
        end

        local leftText = line and line.leftText
        local rightText = line and line.rightText

        if TooltipLineHasKnownText(leftText) or TooltipLineHasKnownText(rightText) then
            return true
        end

        if isHousingItem and (TooltipLineHasOwnedHousingText(leftText) or TooltipLineHasOwnedHousingText(rightText)) then
            return true
        end
    end

    return false
end

local function TooltipHasKnownLine(merchantIndex)
    if not merchantIndex or merchantIndex <= 0 then
        return false
    end

    local itemLink = GetMerchantItemLink and GetMerchantItemLink(merchantIndex) or nil
    local itemClassID = itemLink and C_Item and C_Item.GetItemInfoInstant and select(6, C_Item.GetItemInfoInstant(itemLink)) or nil
    local isHousingItem = itemClassID == ITEM_CLASS_HOUSING

    if C_TooltipInfo then
        local ok, data

        if C_TooltipInfo.GetMerchantItem then
            ok, data = pcall(C_TooltipInfo.GetMerchantItem, merchantIndex)

            if ok and TooltipDataHasKnownLine(data, isHousingItem) then
                return true
            end
        end

        if C_TooltipInfo.GetHyperlink then
            if itemLink then
                ok, data = pcall(C_TooltipInfo.GetHyperlink, itemLink)

                if ok and TooltipDataHasKnownLine(data, isHousingItem) then
                    return true
                end
            end
        end
    end

    local tooltip = EnsureKnownTooltip()

    if not tooltip or not tooltip.SetMerchantItem then
        return false
    end

    tooltip:ClearLines()

    local ok = pcall(tooltip.SetMerchantItem, tooltip, merchantIndex)

    if not ok then
        return false
    end

    for lineIndex = 1, tooltip:NumLines() do
        for _, side in ipairs({ "Left", "Right" }) do
            local line = _G["ZoidsToolsKnownMerchantTooltipText" .. side .. lineIndex]
            local ok, text = pcall(function()
                return line and line.GetText and line:GetText()
            end)

            if ok and TooltipLineHasKnownText(text) then
                return true
            end
        end
    end

    return false
end

local function GetMerchantItemIndex(buttonIndex, itemButton)
    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    local page = MerchantFrame and MerchantFrame.page or 1
    local itemIndex = ((page - 1) * perPage) + buttonIndex

    if itemButton and itemButton.GetID then
        local ok, id = pcall(itemButton.GetID, itemButton)

        if ok and type(id) == "number" and id > 0 then
            itemIndex = id
        end
    end

    return itemIndex
end

local function SetMerchantKnownOverlay(itemButton, state)
    if not itemButton then
        return
    end

    local row = itemButton.GetParent and itemButton:GetParent() or nil

    if state ~= true
        and not itemButton.ZTKnownMerchantOverlay
        and not itemButton.ZTKnownMerchantCheck
        and (not row or not row.ZTKnownMerchantOverlay)
    then
        return
    end

    if state == true then
        knownMerchantTouched = true
    end

    if not itemButton.ZTKnownMerchantOverlay then
        local overlay = itemButton:CreateTexture(nil, "OVERLAY", nil, 6)
        overlay:SetAllPoints(itemButton)
        overlay:SetColorTexture(0, 0.75, 0.12, 0.34)
        itemButton.ZTKnownMerchantOverlay = overlay
    end

    if not itemButton.ZTKnownMerchantCheck then
        local check = itemButton:CreateTexture(nil, "OVERLAY", nil, 7)

        if check.SetAtlas and check:SetAtlas("common-icon-checkmark") then
            check:SetTexCoord(0, 1, 0, 1)
        else
            check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        end

        check:SetSize(22, 22)
        check:SetPoint("TOPLEFT", itemButton, "TOPLEFT", -2, 2)
        check:SetVertexColor(0.25, 1, 0.25, 0.98)
        itemButton.ZTKnownMerchantCheck = check
    end

    if row then
        if not row.ZTKnownMerchantOverlay then
            local rowOverlay = row:CreateTexture(nil, "OVERLAY", nil, 1)
            rowOverlay:SetAllPoints(row)
            rowOverlay:SetColorTexture(0, 0.55, 0.08, 0.22)
            row.ZTKnownMerchantOverlay = rowOverlay
        end
    end

    if itemButton.ZTKnownMerchantOverlay then
        itemButton.ZTKnownMerchantOverlay:SetShown(state == true)
    end

    if itemButton.ZTKnownMerchantCheck then
        itemButton.ZTKnownMerchantCheck:SetShown(state == true)
    end

    if row and row.ZTKnownMerchantOverlay then
        row.ZTKnownMerchantOverlay:SetShown(state == true)
    end

    if row and row.ZTKnownMerchantCheck then
        row.ZTKnownMerchantCheck:Hide()
    end
end

local function HideKnownMerchantOverlays()
    local perPage = MERCHANT_ITEMS_PER_PAGE or 10

    for index = 1, perPage do
        SetMerchantKnownOverlay(_G["MerchantItem" .. index .. "ItemButton"], false)
    end

    knownMerchantTouched = false
end

local function RefreshKnownMerchantOverlays()
    local db = EnsureVendorDB()

    if not db or db.knownItemOverlay ~= true then
        if knownMerchantTouched then
            HideKnownMerchantOverlays()
        end

        return
    end

    if not IsMerchantOpen() then
        return
    end

    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    local itemCount = GetMerchantNumItems and GetMerchantNumItems() or 0

    for buttonIndex = 1, perPage do
        local itemButton = _G["MerchantItem" .. buttonIndex .. "ItemButton"]
        local merchantIndex = GetMerchantItemIndex(buttonIndex, itemButton)
        local shouldShow = false

        if itemButton and itemButton:IsShown() and merchantIndex and merchantIndex <= itemCount then
            shouldShow = TooltipHasKnownLine(merchantIndex)
        end

        SetMerchantKnownOverlay(itemButton, shouldShow)
    end
end

local function QueueKnownMerchantOverlayRefresh(delay)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or MERCHANT_REFRESH_DELAY, RefreshKnownMerchantOverlays)
    else
        RefreshKnownMerchantOverlays()
    end
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

IsMerchantOpen = function()
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

    QueueKnownMerchantOverlayRefresh(0.15)
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

function ns:SetKnownMerchantItemOverlay(value)
    local db = EnsureVendorDB()

    if not db then
        return
    end

    db.knownItemOverlay = value == true
    QueueKnownMerchantOverlayRefresh()
    QueueKnownMerchantOverlayRefresh(0.3)
end

function ns:GetKnownMerchantItemOverlay()
    local db = EnsureVendorDB()

    return db and db.knownItemOverlay == true
end

function ns:InitializeVendorAutomation()
    EnsureVendorDB()

    if initialized then
        return
    end

    initialized = true
    frame = CreateFrame("Frame")
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:RegisterEvent("MERCHANT_UPDATE")
    frame:RegisterEvent("MERCHANT_CLOSED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_CLOSED" then
            HideKnownMerchantOverlays()
            return
        end

        if event == "MERCHANT_UPDATE" then
            QueueKnownMerchantOverlayRefresh()
            QueueKnownMerchantOverlayRefresh(0.3)
            return
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, RunVendorAutomation)
            C_Timer.After(0.45, RefreshKnownMerchantOverlays)
        else
            RunVendorAutomation()
        end
    end)

    if MerchantFrame_UpdateMerchantInfo then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
            QueueKnownMerchantOverlayRefresh()
            QueueKnownMerchantOverlayRefresh(0.25)
        end)
    end

    if MerchantFrame_UpdateBuybackInfo then
        hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
            if knownMerchantTouched then
                HideKnownMerchantOverlays()
            end
        end)
    end
end
