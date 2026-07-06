local _, ns = ...

local eventFrame
local characterHooksInstalled = false
local bankHooksInstalled = false
local hookedContainerFrames = {}
local pendingCharacterRefresh = false
local pendingCharacterForceRefresh = false
local pendingCharacterSettleRefresh = false
local pendingBagRefresh = false
local pendingBankRefresh = false
local pendingBagForceClear = false
local pendingBankForceClear = false
local pendingCombatCharacterRefresh = false
local pendingCombatCharacterForceRefresh = false
local pendingCombatBagRefresh = false
local pendingCombatBankRefresh = false
local pendingCombatBagForceClear = false
local pendingCombatBankForceClear = false
local qualityColorCache = {}
local qualityColorCacheCount = 0

local tableUnpack = unpack or table.unpack
local DEFAULT_FONT_SIZE = 12
local QUALITY_COLOR_CACHE_MAX = 250
local CHARACTER_GEM_SIZE = 13
local CHARACTER_GEM_SPACING = 1
local CHARACTER_REFRESH_DELAY = 0.05
local CHARACTER_SETTLE_REFRESH_DELAY = 0.45
local EMPTY_SOCKET_TEXTURE = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic"

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local equippableLocations = {
    INVTYPE_HEAD = true,
    INVTYPE_NECK = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_BODY = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
    INVTYPE_FINGER = true,
    INVTYPE_TRINKET = true,
    INVTYPE_CLOAK = true,
    INVTYPE_WEAPON = true,
    INVTYPE_SHIELD = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_HOLDABLE = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
}

local characterSlots = {
    { slot = 1, frameName = "CharacterHeadSlot", side = "left" },
    { slot = 2, frameName = "CharacterNeckSlot", side = "left" },
    { slot = 3, frameName = "CharacterShoulderSlot", side = "left" },
    { slot = 15, frameName = "CharacterBackSlot", side = "left" },
    { slot = 5, frameName = "CharacterChestSlot", side = "left" },
    { slot = 9, frameName = "CharacterWristSlot", side = "left" },
    { slot = 10, frameName = "CharacterHandsSlot", side = "right" },
    { slot = 6, frameName = "CharacterWaistSlot", side = "right" },
    { slot = 7, frameName = "CharacterLegsSlot", side = "right" },
    { slot = 8, frameName = "CharacterFeetSlot", side = "right" },
    { slot = 11, frameName = "CharacterFinger0Slot", side = "right" },
    { slot = 12, frameName = "CharacterFinger1Slot", side = "right" },
    { slot = 13, frameName = "CharacterTrinket0Slot", side = "right" },
    { slot = 14, frameName = "CharacterTrinket1Slot", side = "right" },
    { slot = 16, frameName = "CharacterMainHandSlot", side = "bottom" },
    { slot = 17, frameName = "CharacterSecondaryHandSlot", side = "bottom" },
}

local function PackResults(...)
    return { n = select("#", ...), ... }
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local results = PackResults(pcall(func, ...))

    if results[1] then
        return tableUnpack(results, 2, results.n)
    end

    return nil
end

local function CallMethod(object, methodName, ...)
    if not object or type(object[methodName]) ~= "function" then
        return nil
    end

    return SafeCall(object[methodName], object, ...)
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.items = ns.db.items or {}

    local db = ns.db.items

    if db.enabled == nil then
        db.enabled = true
    end

    if db.fontSize == nil then
        db.fontSize = DEFAULT_FONT_SIZE
    end

    if db.useQualityColor == nil then
        db.useQualityColor = true
    end

    db.character = db.character or {}

    if db.character.itemLevel == nil then
        db.character.itemLevel = true
    end

    if db.character.gems == nil then
        db.character.gems = true
    end

    if db.character.enchants == nil then
        db.character.enchants = true
    end

    if db.character.missingEnchant == nil then
        db.character.missingEnchant = true
    end

    if db.character.gemTooltips == nil then
        db.character.gemTooltips = true
    end

    db.bags = db.bags or {}

    if db.bags.itemLevel == nil then
        db.bags.itemLevel = true
    end

    if db.bags.bindType == nil then
        db.bags.bindType = true
    end

    db.bank = db.bank or {}

    if db.bank.itemLevel == nil then
        db.bank.itemLevel = true
    end

    if db.bank.bindType == nil then
        db.bank.bindType = true
    end

    db.warbandBank = db.warbandBank or {}

    if db.warbandBank.itemLevel == nil then
        db.warbandBank.itemLevel = true
    end

    if db.warbandBank.bindType == nil then
        db.warbandBank.bindType = true
    end

    return db
end

local function ClampFontSize(value)
    value = tonumber(value) or DEFAULT_FONT_SIZE

    if value < 8 then
        return 8
    elseif value > 20 then
        return 20
    end

    return math.floor(value + 0.5)
end

local function StyleFont(fontString, sizeOffset)
    if not fontString then
        return
    end

    local db = EnsureDB()
    local size = ClampFontSize(db and db.fontSize or DEFAULT_FONT_SIZE) + (sizeOffset or 0)

    fontString:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
end

local function CleanTooltipText(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")

    return text
end

local function TextMatches(text, constant)
    return constant and CleanTooltipText(text) == CleanTooltipText(constant)
end

local function SetQualityColor(fontString, itemLink, fallbackR, fallbackG, fallbackB)
    local db = EnsureDB()

    if db and db.useQualityColor and itemLink then
        local color = qualityColorCache[itemLink]

        if color == nil then
            if qualityColorCacheCount >= QUALITY_COLOR_CACHE_MAX then
                wipe(qualityColorCache)
                qualityColorCacheCount = 0
            end

            local quality

            if C_Item and C_Item.GetItemInfo then
                quality = select(3, SafeCall(C_Item.GetItemInfo, itemLink))
            end

            if not quality and GetItemInfo then
                quality = select(3, SafeCall(GetItemInfo, itemLink))
            end

            if quality then
                local r, g, b

                if C_Item and C_Item.GetItemQualityColor then
                    r, g, b = C_Item.GetItemQualityColor(quality)
                elseif GetItemQualityColor then
                    r, g, b = GetItemQualityColor(quality)
                end

                if r and g and b then
                    color = { r = r, g = g, b = b }
                else
                    color = false
                end
            else
                color = false
            end

            qualityColorCache[itemLink] = color
            qualityColorCacheCount = qualityColorCacheCount + 1
        end

        if color then
            fontString:SetTextColor(color.r, color.g, color.b)
            return
        end
    end

    fontString:SetTextColor(fallbackR or 1, fallbackG or 0.82, fallbackB or 0)
end

local function GetItemInfoInstantEquipLoc(itemLink)
    if C_Item and C_Item.GetItemInfoInstant then
        return select(4, SafeCall(C_Item.GetItemInfoInstant, itemLink))
    elseif GetItemInfoInstant then
        return select(4, SafeCall(GetItemInfoInstant, itemLink))
    end

    return nil
end

local function FetchContainerItemLink(bag, slot)
    if bag == nil or slot == nil then
        return nil
    end

    if C_Container and C_Container.GetContainerItemLink then
        return SafeCall(C_Container.GetContainerItemLink, bag, slot)
    elseif _G.GetContainerItemLink then
        return SafeCall(_G.GetContainerItemLink, bag, slot)
    end

    return nil
end

local function CreateBagLocation(bag, slot)
    if not ItemLocation or not ItemLocation.CreateFromBagAndSlot then
        return nil
    end

    return SafeCall(function()
        return ItemLocation:CreateFromBagAndSlot(bag, slot)
    end)
end

local function CreateEquipmentLocation(slot)
    if not ItemLocation or not ItemLocation.CreateFromEquipmentSlot then
        return nil
    end

    return SafeCall(function()
        return ItemLocation:CreateFromEquipmentSlot(slot)
    end)
end

local function GetBagItemLevel(bag, slot, itemLink)
    local itemLevel
    local location = CreateBagLocation(bag, slot)

    if location and C_Item and C_Item.GetCurrentItemLevel then
        itemLevel = SafeCall(C_Item.GetCurrentItemLevel, location)
    end

    if not itemLevel and C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = SafeCall(C_Item.GetDetailedItemLevelInfo, itemLink)
    end

    if not itemLevel and GetDetailedItemLevelInfo then
        itemLevel = SafeCall(GetDetailedItemLevelInfo, itemLink)
    end

    if not itemLevel and GetItemInfo then
        itemLevel = select(4, SafeCall(GetItemInfo, itemLink))
    end

    return itemLevel
end

local function GetEquipmentItemLevel(slot, itemObject)
    local itemLevel
    local location = CreateEquipmentLocation(slot)

    if location and C_Item and C_Item.GetCurrentItemLevel then
        itemLevel = SafeCall(C_Item.GetCurrentItemLevel, location)
    end

    if not itemLevel and itemObject and type(itemObject.GetCurrentItemLevel) == "function" then
        itemLevel = SafeCall(itemObject.GetCurrentItemLevel, itemObject)
    end

    return itemLevel
end

local function ExtractEnchantID(itemLink)
    local enchantID = itemLink and itemLink:match("item:%d+:(%d*)")

    enchantID = tonumber(enchantID)

    if enchantID and enchantID > 0 then
        return enchantID
    end

    return nil
end

local function GetEnchantRules()
    local playerLevel = UnitLevel and UnitLevel("player") or 0

    if playerLevel >= 81 then
        return {
            [1] = true,
            [3] = true,
            [5] = true,
            [7] = true,
            [8] = true,
            [11] = true,
            [12] = true,
            [16] = true,
            [17] = true,
        }
    end

    return {
        [5] = true,
        [7] = true,
        [8] = true,
        [9] = true,
        [11] = true,
        [12] = true,
        [15] = true,
        [16] = true,
        [17] = true,
    }
end

local function IsMaxLevelCharacter()
    if not UnitLevel then
        return true
    end

    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 0

    if maxLevel <= 0 then
        return true
    end

    return (UnitLevel("player") or 0) >= maxLevel
end

local function SlotShouldHaveEnchant(slot)
    if not IsMaxLevelCharacter() then
        return false
    end

    return GetEnchantRules()[slot] == true
end

local function CountSockets(itemLink)
    if not itemLink or not C_Item or not C_Item.GetItemStats then
        return 0
    end

    local stats = SafeCall(C_Item.GetItemStats, itemLink)
    local count = 0

    if type(stats) ~= "table" then
        return 0
    end

    for statName, statValue in pairs(stats) do
        if tostring(statName):find("EMPTY_SOCKET") then
            count = count + (tonumber(statValue) or 0)
        end
    end

    return count
end

local function GetGemLink(itemLink, index)
    if not itemLink or not C_Item or not C_Item.GetItemGem then
        return nil
    end

    local _, gemLink = SafeCall(C_Item.GetItemGem, itemLink, index)

    return gemLink
end

local function GetGemIcon(gemLink)
    if not gemLink then
        return nil
    end

    if C_Item and C_Item.GetItemIconByID then
        return SafeCall(C_Item.GetItemIconByID, gemLink)
    end

    if GetItemInfo then
        return select(10, SafeCall(GetItemInfo, gemLink))
    end

    return nil
end

local function EnsureCharacterOverlays(button)
    if not button.ZTItemLevelText then
        button.ZTItemLevelText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.ZTItemLevelText:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
        button.ZTItemLevelText:SetJustifyH("RIGHT")
    end

    if not button.ZTEnchantText then
        button.ZTEnchantText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end

    if not button.ZTEnchantWarning then
        button.ZTEnchantWarning = button:CreateTexture(nil, "OVERLAY")
        button.ZTEnchantWarning:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        button.ZTEnchantWarning:SetBlendMode("ADD")
        button.ZTEnchantWarning:SetAlpha(0.75)
        button.ZTEnchantWarning:SetVertexColor(1, 0.05, 0.05)
        button.ZTEnchantWarning:SetPoint("CENTER", button, "CENTER")
        button.ZTEnchantWarning:Hide()
    end

    local width, height = button:GetSize()
    button.ZTEnchantWarning:SetSize((width or 36) + 18, (height or 36) + 18)

    StyleFont(button.ZTItemLevelText, 0)
    StyleFont(button.ZTEnchantText, -2)
end

local function EnsureGemFrames(button, count)
    button.ZTGemFrames = button.ZTGemFrames or {}

    for index = 1, count do
        if not button.ZTGemFrames[index] then
            local frame = CreateFrame("Frame", nil, button)

            frame:SetSize(CHARACTER_GEM_SIZE, CHARACTER_GEM_SIZE)
            frame.icon = frame:CreateTexture(nil, "OVERLAY")
            frame.icon:SetAllPoints()
            frame.icon:SetTexture(EMPTY_SOCKET_TEXTURE)
            frame:Hide()

            frame:SetScript("OnEnter", function(self)
                local db = EnsureDB()

                if db and db.character.gemTooltips and self.ZTGemLink then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(self.ZTGemLink)
                    GameTooltip:Show()
                elseif db and db.character.gemTooltips and self.ZTEmptySocket then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Empty socket")
                    GameTooltip:Show()
                end
            end)

            frame:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            button.ZTGemFrames[index] = frame
        end
    end
end

local function PositionGemFrames(button, displayCount, side)
    if not button.ZTGemFrames then
        return
    end

    local gemSize = CHARACTER_GEM_SIZE
    local spacing = CHARACTER_GEM_SPACING
    local totalWidth = (displayCount * gemSize) + math.max(displayCount - 1, 0) * spacing
    local startX = -(totalWidth / 2) + (gemSize / 2)

    for index, frame in ipairs(button.ZTGemFrames) do
        frame:ClearAllPoints()

        if index <= displayCount then
            local offset = startX + ((index - 1) * (gemSize + spacing))

            if side == "left" then
                frame:SetPoint("TOP", button, "RIGHT", 12 + offset, -2)
            elseif side == "right" then
                frame:SetPoint("TOP", button, "LEFT", -12 + offset, -2)
            else
                frame:SetPoint("TOP", button, "BOTTOM", offset, -15)
            end
        end
    end
end

local function HideGemFrames(button)
    if not button.ZTGemFrames then
        return
    end

    for _, frame in ipairs(button.ZTGemFrames) do
        frame.ZTGemLink = nil
        frame.ZTEmptySocket = nil
        frame:Hide()
    end
end

local function PositionEnchantText(button, side)
    button.ZTEnchantText:ClearAllPoints()

    if side == "left" then
        button.ZTEnchantText:SetPoint("LEFT", button, "RIGHT", 3, 8)
        button.ZTEnchantText:SetJustifyH("LEFT")
    elseif side == "right" then
        button.ZTEnchantText:SetPoint("RIGHT", button, "LEFT", -3, 8)
        button.ZTEnchantText:SetJustifyH("RIGHT")
    else
        button.ZTEnchantText:SetPoint("TOP", button, "BOTTOM", 0, -1)
        button.ZTEnchantText:SetJustifyH("CENTER")
    end
end

local function ClearCharacterButton(button)
    if not button then
        return
    end

    if button.ZTItemLevelText then
        button.ZTItemLevelText:SetText("")
        button.ZTItemLevelText:Hide()
    end

    if button.ZTEnchantText then
        button.ZTEnchantText:SetText("")
        button.ZTEnchantText:Hide()
    end

    if button.ZTEnchantWarning then
        button.ZTEnchantWarning:Hide()
    end

    HideGemFrames(button)
end

local function UpdateCharacterGems(button, itemLink, slot, side)
    local db = EnsureDB()

    if not db or not db.enabled or not db.character.gems then
        HideGemFrames(button)
        return
    end

    local socketCount = CountSockets(itemLink)
    local displayCount = socketCount

    if displayCount <= 0 then
        HideGemFrames(button)
        return
    end

    EnsureGemFrames(button, displayCount)
    PositionGemFrames(button, displayCount, side)

    for index, frame in ipairs(button.ZTGemFrames) do
        if index <= displayCount then
            local gemLink = index <= socketCount and GetGemLink(itemLink, index) or nil
            local icon = GetGemIcon(gemLink)

            frame.ZTGemLink = gemLink
            frame.ZTEmptySocket = not gemLink
            frame.icon:SetTexture(icon or EMPTY_SOCKET_TEXTURE)

            if gemLink then
                frame.icon:SetVertexColor(1, 1, 1, 1)
            else
                frame.icon:SetVertexColor(0.85, 0.85, 0.85, 1)
            end

            frame:Show()
        else
            frame.ZTGemLink = nil
            frame.ZTEmptySocket = nil
            frame:Hide()
        end
    end
end

local function UpdateCharacterEnchant(button, itemLink, slot, side)
    local db = EnsureDB()

    if not db or not db.enabled or not db.character.enchants then
        if button.ZTEnchantText then
            button.ZTEnchantText:SetText("")
            button.ZTEnchantText:Hide()
        end

        if button.ZTEnchantWarning then
            button.ZTEnchantWarning:Hide()
        end

        return
    end

    PositionEnchantText(button, side)

    local hasEnchant = ExtractEnchantID(itemLink) ~= nil
    local missingEnchant = not hasEnchant and SlotShouldHaveEnchant(slot)

    if hasEnchant then
        button.ZTEnchantText:SetText("Ench")
        button.ZTEnchantText:SetTextColor(0.35, 1, 0.35)
        button.ZTEnchantText:Show()
    elseif missingEnchant then
        button.ZTEnchantText:SetText("Ench")
        button.ZTEnchantText:SetTextColor(1, 0.18, 0.18)
        button.ZTEnchantText:Show()
    else
        button.ZTEnchantText:SetText("")
        button.ZTEnchantText:Hide()
    end

    if button.ZTEnchantWarning then
        button.ZTEnchantWarning:SetShown(missingEnchant == true and db.character.missingEnchant == true)
    end
end

local function UpdateCharacterSlot(slotInfo)
    local db = EnsureDB()
    local button = _G[slotInfo.frameName]

    if not button then
        return
    end

    EnsureCharacterOverlays(button)

    if not db or not db.enabled then
        ClearCharacterButton(button)
        return
    end

    local itemLink = GetInventoryItemLink and GetInventoryItemLink("player", slotInfo.slot) or nil

    if not itemLink then
        ClearCharacterButton(button)
        return
    end

    button.ZTItemOverlayLink = itemLink

    local function ApplyLoadedItem(itemObject)
        if button.ZTItemOverlayLink ~= itemLink then
            return
        end

        if GetInventoryItemLink and GetInventoryItemLink("player", slotInfo.slot) ~= itemLink then
            return
        end

        if db.character.itemLevel then
            local itemLevel = GetEquipmentItemLevel(slotInfo.slot, itemObject)

            if itemLevel and itemLevel > 0 then
                button.ZTItemLevelText:SetText(math.floor(itemLevel + 0.5))
                SetQualityColor(button.ZTItemLevelText, itemLink, 1, 0.82, 0)
                button.ZTItemLevelText:Show()
            else
                button.ZTItemLevelText:SetText("")
                button.ZTItemLevelText:Hide()
            end
        else
            button.ZTItemLevelText:SetText("")
            button.ZTItemLevelText:Hide()
        end

        UpdateCharacterEnchant(button, itemLink, slotInfo.slot, slotInfo.side)
        UpdateCharacterGems(button, itemLink, slotInfo.slot, slotInfo.side)
    end

    if Item and Item.CreateFromEquipmentSlot then
        local itemObject = SafeCall(Item.CreateFromEquipmentSlot, Item, slotInfo.slot)

        if itemObject and type(itemObject.ContinueOnItemLoad) == "function" then
            itemObject:ContinueOnItemLoad(function()
                ApplyLoadedItem(itemObject)
            end)
        else
            ApplyLoadedItem(itemObject)
        end
    else
        ApplyLoadedItem(nil)
    end
end

local function RefreshCharacterSlots()
    for _, slotInfo in ipairs(characterSlots) do
        UpdateCharacterSlot(slotInfo)
    end
end

local function IsCharacterFrameVisible()
    if CharacterFrame and type(CharacterFrame.IsShown) == "function" and CharacterFrame:IsShown() then
        return true
    end

    if PaperDollFrame and type(PaperDollFrame.IsShown) == "function" and PaperDollFrame:IsShown() then
        return true
    end

    return false
end

local function EnsureBagOverlays(button)
    if not button.ZTBagItemLevelText then
        button.ZTBagItemLevelText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.ZTBagItemLevelText:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
        button.ZTBagItemLevelText:SetJustifyH("RIGHT")
    end

    if not button.ZTBagBindText then
        button.ZTBagBindText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.ZTBagBindText:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
        button.ZTBagBindText:SetJustifyH("LEFT")
    end

    StyleFont(button.ZTBagItemLevelText, -1)
    StyleFont(button.ZTBagBindText, -3)
end

local function ClearBagButton(button)
    if not button then
        return
    end

    button.ZTBagItemLink = nil
    button.ZTBagCacheKey = nil
    button.ZTBagCacheReady = nil

    if button.ZTBagItemLevelText then
        button.ZTBagItemLevelText:SetText("")
        button.ZTBagItemLevelText:Hide()
    end

    if button.ZTBagBindText then
        button.ZTBagBindText:SetText("")
        button.ZTBagBindText:Hide()
    end
end

local function GetButtonBagSlot(button, bankFrame)
    local bag
    local slot

    if bankFrame then
        bag = CallMethod(button, "GetBankTabID")
        slot = CallMethod(button, "GetContainerSlotID")
    end

    if bag == nil then
        bag = CallMethod(button, "GetBagID")
    end

    if slot == nil then
        slot = CallMethod(button, "GetID")
    end

    if bag == nil then
        bag = button.bagID or button.BagID or button.bag or button.Bag
    end

    if slot == nil then
        slot = button.slotID or button.SlotID or button.slot or button.Slot
    end

    if bankFrame and bag == nil and BANK_CONTAINER then
        bag = BANK_CONTAINER
    end

    return bag, slot
end

local function MapBindText(text)
    if TextMatches(text, ITEM_BIND_ON_EQUIP) then
        return "BoE"
    elseif TextMatches(text, ITEM_BIND_ON_PICKUP) then
        return "BoP"
    elseif TextMatches(text, ITEM_SOULBOUND) then
        return "SB"
    elseif TextMatches(text, ITEM_ACCOUNTBOUND) or TextMatches(text, ITEM_BIND_TO_BNETACCOUNT) then
        return "WB"
    elseif TextMatches(text, ITEM_ACCOUNTBOUND_UNTIL_EQUIP) or TextMatches(text, ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP) or TextMatches(text, ITEM_BIND_TO_BNETACCOUNT_UNTIL_EQUIP) then
        return "WuE"
    end

    return nil
end

local function GetBindLabel(bag, slot)
    if not C_TooltipInfo or not C_TooltipInfo.GetBagItem then
        return nil
    end

    local data = SafeCall(C_TooltipInfo.GetBagItem, bag, slot)

    if not data or type(data.lines) ~= "table" then
        return nil
    end

    for _, line in ipairs(data.lines) do
        local label = line and MapBindText(line.leftText)

        if label then
            return label
        end
    end

    return nil
end

local function SetBindColor(fontString, bindLabel)
    if bindLabel == "BoE" then
        fontString:SetTextColor(0.25, 0.7, 1)
    elseif bindLabel == "WuE" or bindLabel == "WB" then
        fontString:SetTextColor(1, 0.82, 0.18)
    elseif bindLabel == "BoP" then
        fontString:SetTextColor(0.85, 0.85, 0.85)
    else
        fontString:SetTextColor(0.7, 0.9, 1)
    end
end

local function IsFrameShown(frame)
    return frame and (not frame.IsShown or frame:IsShown())
end

local function IsBankVisible()
    return IsFrameShown(_G.BankPanel) or IsFrameShown(_G.BankFrame)
end

local function HasBagOverlaySettings(db)
    return db
        and db.enabled == true
        and type(db.bags) == "table"
        and (db.bags.itemLevel == true or db.bags.bindType == true)
end

local function HasBankOverlaySettings(db)
    return db
        and db.enabled == true
        and (
            (type(db.bank) == "table" and (db.bank.itemLevel == true or db.bank.bindType == true))
            or (type(db.warbandBank) == "table" and (db.warbandBank.itemLevel == true or db.warbandBank.bindType == true))
        )
end

local function GuessBankKind(button, frame)
    local bankType = CallMethod(button, "GetBankType") or CallMethod(frame, "GetBankType")

    if Enum and Enum.BankType then
        if Enum.BankType.Account and bankType == Enum.BankType.Account then
            return "warbandBank"
        elseif Enum.BankType.Character and bankType == Enum.BankType.Character then
            return "bank"
        end
    end

    local text = string.lower(tostring(bankType or ""))
    local frameName = string.lower((frame and frame.GetName and frame:GetName()) or "")
    local buttonName = string.lower((button and button.GetName and button:GetName()) or "")

    if text:find("account") or text:find("warband") or frameName:find("account") or frameName:find("warband") or buttonName:find("account") or buttonName:find("warband") then
        return "warbandBank"
    end

    return "bank"
end

local function UpdateBagButton(button, kind, frame)
    local db = EnsureDB()

    if not button then
        return
    end

    if not db or not db.enabled then
        ClearBagButton(button)
        return
    end

    if kind == "bank" then
        kind = GuessBankKind(button, frame)
    end

    local section = db[kind] or db.bags

    if type(section) ~= "table" or (not section.itemLevel and not section.bindType) then
        ClearBagButton(button)
        return
    end

    local bag, slot = GetButtonBagSlot(button, kind == "bank" or kind == "warbandBank")
    local itemLink = FetchContainerItemLink(bag, slot)

    if not itemLink then
        ClearBagButton(button)
        return
    end

    local cacheKey = table.concat({
        kind or "bags",
        tostring(bag or ""),
        tostring(slot or ""),
        itemLink,
        tostring(section.itemLevel == true),
        tostring(section.bindType == true),
        tostring(db.fontSize or DEFAULT_FONT_SIZE),
        tostring(db.useQualityColor == true),
    }, "|")

    if button.ZTBagCacheKey == cacheKey and button.ZTBagCacheReady == true then
        return
    end

    EnsureBagOverlays(button)

    button.ZTBagCacheKey = nil
    button.ZTBagCacheReady = nil
    button.ZTBagItemLink = itemLink

    local cacheReady = true
    local equipLoc = GetItemInfoInstantEquipLoc(itemLink)

    if section.itemLevel and equippableLocations[equipLoc] then
        local itemLevel = GetBagItemLevel(bag, slot, itemLink)

        if itemLevel and itemLevel > 0 then
            button.ZTBagItemLevelText:SetText(math.floor(itemLevel + 0.5))
            SetQualityColor(button.ZTBagItemLevelText, itemLink, 1, 0.82, 0)
            button.ZTBagItemLevelText:Show()
        else
            button.ZTBagItemLevelText:SetText("")
            button.ZTBagItemLevelText:Hide()
            cacheReady = false
        end
    else
        button.ZTBagItemLevelText:SetText("")
        button.ZTBagItemLevelText:Hide()
    end

    if section.bindType then
        local bindLabel = GetBindLabel(bag, slot)

        if bindLabel then
            button.ZTBagBindText:SetText(bindLabel)
            SetBindColor(button.ZTBagBindText, bindLabel)
            button.ZTBagBindText:Show()
        else
            button.ZTBagBindText:SetText("")
            button.ZTBagBindText:Hide()
        end
    else
        button.ZTBagBindText:SetText("")
        button.ZTBagBindText:Hide()
    end

    button.ZTBagCacheKey = cacheKey
    button.ZTBagCacheReady = cacheReady
end

local function IterateValidItems(frame, callback)
    if not frame or type(callback) ~= "function" then
        return false
    end

    if type(frame.EnumerateValidItems) == "function" then
        local ok = pcall(function()
            for first, second in frame:EnumerateValidItems() do
                callback(second or first)
            end
        end)

        if ok then
            return true
        end
    end

    if type(frame.Items) == "table" then
        for _, itemButton in pairs(frame.Items) do
            callback(itemButton)
        end

        return true
    end

    if type(frame.GetNumChildren) == "function" and type(frame.GetChildren) == "function" then
        for index = 1, frame:GetNumChildren() do
            local child = select(index, frame:GetChildren())

            if child and (type(child.GetBagID) == "function" or child.bagID or child.slotID or child.Icon or child.icon or child.IconTexture) then
                callback(child)
            end
        end
    end

    return true
end

local function RefreshContainerFrame(frame, kind)
    if not frame then
        return
    end

    if type(frame.IsShown) == "function" and not frame:IsShown() then
        return
    end

    IterateValidItems(frame, function(itemButton)
        UpdateBagButton(itemButton, kind, frame)
    end)
end

local function RefreshBagFrames(forceClear)
    local db = EnsureDB()

    if not forceClear and not HasBagOverlaySettings(db) then
        return
    end

    if ContainerFrameCombinedBags then
        RefreshContainerFrame(ContainerFrameCombinedBags, "bags")
    end

    if ContainerFrameContainer and type(ContainerFrameContainer.ContainerFrames) == "table" then
        for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do
            RefreshContainerFrame(frame, "bags")
        end
    end
end

local function RefreshBankFrames(forceClear)
    local db = EnsureDB()

    if not IsBankVisible() then
        return
    end

    if not forceClear and not HasBankOverlaySettings(db) then
        return
    end

    if _G.BankPanel then
        RefreshContainerFrame(_G.BankPanel, "bank")
    end

    local bankSlots = NUM_BANKGENERIC_SLOTS or 28

    for index = 1, bankSlots do
        local button = _G["BankFrameItem" .. index]

        if button and (not button.IsShown or button:IsShown()) then
            UpdateBagButton(button, "bank", _G.BankFrame)
        end
    end
end

local function QueueCharacterRefresh(delay, force)
    if type(delay) ~= "number" then
        delay = CHARACTER_REFRESH_DELAY
    end

    if IsCombatLocked() then
        pendingCombatCharacterRefresh = true
        pendingCombatCharacterForceRefresh = pendingCombatCharacterForceRefresh or force == true
        return
    end

    pendingCharacterForceRefresh = pendingCharacterForceRefresh or force == true

    if pendingCharacterRefresh then
        return
    end

    pendingCharacterRefresh = true

    local function Run()
        local shouldForce = pendingCharacterForceRefresh

        pendingCharacterRefresh = false
        pendingCharacterForceRefresh = false

        if shouldForce or IsCharacterFrameVisible() then
            RefreshCharacterSlots()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay, Run)
    else
        Run()
    end
end

local function QueueCharacterSettleRefresh()
    if IsCombatLocked() then
        pendingCombatCharacterRefresh = true
        return
    end

    QueueCharacterRefresh(0.08)

    if pendingCharacterSettleRefresh then
        return
    end

    pendingCharacterSettleRefresh = true

    local function Run()
        pendingCharacterSettleRefresh = false
        QueueCharacterRefresh(0.02)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(CHARACTER_SETTLE_REFRESH_DELAY, Run)
    else
        Run()
    end
end

local function QueueBagRefresh(forceClear)
    if IsCombatLocked() then
        pendingCombatBagRefresh = true
        pendingCombatBagForceClear = pendingCombatBagForceClear or forceClear == true
        return
    end

    pendingBagForceClear = pendingBagForceClear or forceClear == true

    if pendingBagRefresh then
        return
    end

    pendingBagRefresh = true

    local function Run()
        local shouldForceClear = pendingBagForceClear

        pendingBagRefresh = false
        pendingBagForceClear = false
        RefreshBagFrames(shouldForceClear)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.10, Run)
    else
        Run()
    end
end

local function QueueBankRefresh(forceClear)
    if IsCombatLocked() then
        pendingCombatBankRefresh = true
        pendingCombatBankForceClear = pendingCombatBankForceClear or forceClear == true
        return
    end

    pendingBankForceClear = pendingBankForceClear or forceClear == true

    if pendingBankRefresh then
        return
    end

    pendingBankRefresh = true

    local function Run()
        local shouldForceClear = pendingBankForceClear

        pendingBankRefresh = false
        pendingBankForceClear = false
        RefreshBankFrames(shouldForceClear)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.12, Run)
    else
        Run()
    end
end

local function HookContainerFrames()
    if not ContainerFrameContainer or type(ContainerFrameContainer.ContainerFrames) ~= "table" then
        return
    end

    if ContainerFrameCombinedBags and not hookedContainerFrames[ContainerFrameCombinedBags] and type(ContainerFrameCombinedBags.UpdateItems) == "function" then
        hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", function()
            QueueBagRefresh()
        end)
        hookedContainerFrames[ContainerFrameCombinedBags] = true
    end

    for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do
        if frame and not hookedContainerFrames[frame] and type(frame.UpdateItems) == "function" then
            hooksecurefunc(frame, "UpdateItems", function()
                QueueBagRefresh()
            end)
            hookedContainerFrames[frame] = true
        end
    end
end

local function HookBankPanel()
    if bankHooksInstalled or not _G.BankPanel then
        return
    end

    local methods = {
        "GenerateItemSlotsForSelectedTab",
        "RefreshAllItemsForSelectedTab",
        "UpdateSearchResults",
    }

    for _, methodName in ipairs(methods) do
        if type(_G.BankPanel[methodName]) == "function" then
            hooksecurefunc(_G.BankPanel, methodName, function()
                QueueBankRefresh()
            end)
        end
    end

    bankHooksInstalled = true
end

local function HookCharacterFrame()
    if characterHooksInstalled then
        return
    end

    local installed = false

    if CharacterFrame and type(CharacterFrame.HookScript) == "function" then
        CharacterFrame:HookScript("OnShow", QueueCharacterRefresh)
        installed = true
    end

    if PaperDollFrame and type(PaperDollFrame.HookScript) == "function" then
        PaperDollFrame:HookScript("OnShow", QueueCharacterRefresh)
        installed = true
    end

    if installed then
        characterHooksInstalled = true
    end
end

local function InstallHooks()
    HookCharacterFrame()
    HookContainerFrames()
    HookBankPanel()
end

local function RegisterEventSafe(frame, event)
    if frame and event then
        SafeCall(frame.RegisterEvent, frame, event)
    end
end

local function RegisterUnitEventSafe(frame, event, ...)
    if frame and type(frame.RegisterUnitEvent) == "function" then
        local ok, registered = pcall(frame.RegisterUnitEvent, frame, event, ...)

        if ok and registered ~= false then
            return
        end
    end

    RegisterEventSafe(frame, event)
end

local function RegisterItemOverlayWorkEvents()
    if not eventFrame then
        return
    end

    RegisterEventSafe(eventFrame, "PLAYER_EQUIPMENT_CHANGED")
    RegisterUnitEventSafe(eventFrame, "UNIT_INVENTORY_CHANGED", "player")
    RegisterEventSafe(eventFrame, "BAG_UPDATE_DELAYED")
    RegisterEventSafe(eventFrame, "PLAYERBANKSLOTS_CHANGED")
    RegisterEventSafe(eventFrame, "BANKFRAME_OPENED")
    RegisterEventSafe(eventFrame, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    RegisterEventSafe(eventFrame, "SOCKET_INFO_UPDATE")
    RegisterEventSafe(eventFrame, "SOCKET_INFO_SUCCESS")
    RegisterEventSafe(eventFrame, "SOCKET_INFO_CLOSE")
end

local function UnregisterItemOverlayWorkEvents()
    if not eventFrame or type(eventFrame.UnregisterEvent) ~= "function" then
        return
    end

    eventFrame:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:UnregisterEvent("UNIT_INVENTORY_CHANGED")
    eventFrame:UnregisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:UnregisterEvent("PLAYERBANKSLOTS_CHANGED")
    eventFrame:UnregisterEvent("BANKFRAME_OPENED")
    eventFrame:UnregisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    eventFrame:UnregisterEvent("SOCKET_INFO_UPDATE")
    eventFrame:UnregisterEvent("SOCKET_INFO_SUCCESS")
    eventFrame:UnregisterEvent("SOCKET_INFO_CLOSE")
end

function ns:SetItemOverlaysEnabled(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.enabled = value == true
    ns:RefreshItemOverlays()

    if ns.RefreshStatTargets then
        ns:RefreshStatTargets()
    end
end

function ns:GetItemOverlaysEnabled()
    local db = EnsureDB()

    return db and db.enabled == true
end

function ns:SetItemOverlaySetting(sectionName, key, value)
    local db = EnsureDB()
    local section = db and db[sectionName]

    if type(section) ~= "table" then
        return
    end

    section[key] = value == true
    ns:RefreshItemOverlays()

    if ns.RefreshStatTargets then
        ns:RefreshStatTargets()
    end
end

function ns:GetItemOverlaySetting(sectionName, key)
    local db = EnsureDB()
    local section = db and db[sectionName]

    return type(section) == "table" and section[key] == true
end

function ns:SetItemOverlayFontSize(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.fontSize = ClampFontSize(value)
    ns:RefreshItemOverlays()
end

function ns:GetItemOverlayFontSize()
    local db = EnsureDB()

    return ClampFontSize(db and db.fontSize)
end

function ns:SetItemOverlayQualityColor(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.useQualityColor = value == true
    ns:RefreshItemOverlays()
end

function ns:GetItemOverlayQualityColor()
    local db = EnsureDB()

    return db and db.useQualityColor == true
end

function ns:RefreshItemOverlays()
    InstallHooks()
    QueueCharacterRefresh()
    QueueBagRefresh(true)
    QueueBankRefresh(true)
end

function ns:InitializeItemOverlays()
    EnsureDB()
    InstallHooks()
    ns:RefreshItemOverlays()

    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    RegisterEventSafe(eventFrame, "PLAYER_ENTERING_WORLD")
    RegisterItemOverlayWorkEvents()
    RegisterEventSafe(eventFrame, "PLAYER_REGEN_DISABLED")
    RegisterEventSafe(eventFrame, "PLAYER_REGEN_ENABLED")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            InstallHooks()
            QueueCharacterRefresh()
            QueueBagRefresh()
            QueueBankRefresh()
        elseif event == "PLAYER_REGEN_DISABLED" then
            pendingCombatCharacterRefresh = true
            pendingCombatBagRefresh = true
            UnregisterItemOverlayWorkEvents()
        elseif event == "PLAYER_REGEN_ENABLED" then
            RegisterItemOverlayWorkEvents()

            if pendingCombatCharacterRefresh then
                local force = pendingCombatCharacterForceRefresh
                pendingCombatCharacterRefresh = false
                pendingCombatCharacterForceRefresh = false
                QueueCharacterRefresh(0.12, force)
            else
                QueueCharacterSettleRefresh()
            end

            if pendingCombatBagRefresh then
                local force = pendingCombatBagForceClear
                pendingCombatBagRefresh = false
                pendingCombatBagForceClear = false
                QueueBagRefresh(force)
            end

            if pendingCombatBankRefresh then
                local force = pendingCombatBankForceClear
                pendingCombatBankRefresh = false
                pendingCombatBankForceClear = false
                QueueBankRefresh(force)
            end
        elseif IsCombatLocked() then
            if event == "PLAYER_EQUIPMENT_CHANGED"
                or event == "UNIT_INVENTORY_CHANGED"
                or event == "SOCKET_INFO_UPDATE"
                or event == "SOCKET_INFO_SUCCESS"
                or event == "SOCKET_INFO_CLOSE"
            then
                pendingCombatCharacterRefresh = true
            elseif event == "BAG_UPDATE_DELAYED" then
                pendingCombatBagRefresh = true
                pendingCombatCharacterRefresh = true
            elseif event == "PLAYERBANKSLOTS_CHANGED"
                or event == "BANKFRAME_OPENED"
                or event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW"
            then
                pendingCombatBankRefresh = true
            end

            return
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            QueueCharacterSettleRefresh()
        elseif event == "UNIT_INVENTORY_CHANGED" then
            local unit = ...

            if unit == "player" then
                QueueCharacterSettleRefresh()
            end
        elseif event == "SOCKET_INFO_UPDATE" or event == "SOCKET_INFO_SUCCESS" or event == "SOCKET_INFO_CLOSE" then
            QueueCharacterSettleRefresh()
        elseif event == "BAG_UPDATE_DELAYED" then
            HookContainerFrames()
            QueueBagRefresh()
            QueueCharacterSettleRefresh()
        elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "BANKFRAME_OPENED" or event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            HookBankPanel()
            QueueBankRefresh()
        end
    end)
end
