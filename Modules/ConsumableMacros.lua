local _, ns = ...

local HEALTH_MACRO_NAME = "ZT Health"
local MANA_MACRO_NAME = "ZT Mana"
local MACRO_ICON = "INV_Misc_QuestionMark"
local RECUPERATE_SPELL_ID = 1231411
local HEALTHSTONE_ITEM_ID = 5512
local DEMONIC_HEALTHSTONE_ITEM_ID = 224464
local CONSUMABLE_CLASS_ID = 0
local POTION_SUBCLASS_ID = 1
local FOOD_DRINK_SUBCLASS_ID = 5

local frame
local initialized = false
local updateScheduled = false
local pendingCombatUpdate = false
local pendingItemInfo = false
local bagHooksInstalled = false
local hookedBagFrames = {}
local lastBagSignature
local lastConsumableScan
local lastScanHadPendingItems = false

local lastStatus = {
    health = "Health macro disabled.",
    mana = "Mana macro disabled.",
}

local function EnsureMacroDB()
    if not ns.db then
        return nil
    end

    ns.db.macros = ns.db.macros or {}

    if ns.db.macros.healthEnabled == nil then
        ns.db.macros.healthEnabled = false
    end

    if ns.db.macros.healthUseRecuperate == nil then
        ns.db.macros.healthUseRecuperate = false
    end

    if ns.db.macros.healthCombatItems == nil then
        ns.db.macros.healthCombatItems = true
    end

    if ns.db.macros.manaEnabled == nil then
        ns.db.macros.manaEnabled = false
    end

    if ns.db.macros.manaCombatPotion == nil then
        ns.db.macros.manaCombatPotion = true
    end

    return ns.db.macros
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

local function GetContainerItemIDSafe(bag, slot)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bag, slot)
    elseif GetContainerItemID then
        return GetContainerItemID(bag, slot)
    end
end

local function GetContainerItemCountSafe(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)

        return info and info.stackCount or 0
    elseif GetContainerItemInfo then
        local _, count = GetContainerItemInfo(bag, slot)

        return count or 0
    end

    return 0
end

local function GetItemCountSafe(itemID)
    if not itemID then
        return 0
    end

    if C_Item and C_Item.GetItemCount then
        local ok, count = pcall(C_Item.GetItemCount, itemID, false, false)

        if ok then
            return count or 0
        end
    elseif GetItemCount then
        local ok, count = pcall(GetItemCount, itemID, false, false)

        if ok then
            return count or 0
        end
    end

    return 0
end

local function BuildBagSignature()
    local parts = {}

    for _, bag in ipairs(GetBagIds()) do
        local slots = GetContainerNumSlotsSafe(bag)

        parts[#parts + 1] = tostring(bag) .. ":" .. tostring(slots)

        for slot = 1, slots do
            local itemID = GetContainerItemIDSafe(bag, slot)

            if itemID then
                parts[#parts + 1] = tostring(itemID) .. "x" .. tostring(GetContainerItemCountSafe(bag, slot))
            else
                parts[#parts + 1] = "-"
            end
        end
    end

    return table.concat(parts, "|")
end

local tooltipScanner

local function ReadTooltipViaScanner(bag, slot)
    if not CreateFrame or not UIParent then
        return ""
    end

    if not tooltipScanner then
        tooltipScanner = CreateFrame("GameTooltip", "ZoidsToolsConsumableScannerTooltip", UIParent, "GameTooltipTemplate")
        tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    end

    tooltipScanner:ClearLines()

    if tooltipScanner.SetBagItem then
        tooltipScanner:SetBagItem(bag, slot)
    end

    local lines = {}
    local count = tooltipScanner:NumLines() or 0

    for index = 1, count do
        local left = _G["ZoidsToolsConsumableScannerTooltipTextLeft" .. index]
        local right = _G["ZoidsToolsConsumableScannerTooltipTextRight" .. index]

        if left and left.GetText then
            local text = left:GetText()

            if text and text ~= "" then
                lines[#lines + 1] = text
            end
        end

        if right and right.GetText then
            local text = right:GetText()

            if text and text ~= "" then
                lines[#lines + 1] = text
            end
        end
    end

    return table.concat(lines, "\n")
end

local function ReadTooltipText(bag, slot)
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local data = C_TooltipInfo.GetBagItem(bag, slot)

        if data and data.lines then
            local lines = {}

            for _, line in ipairs(data.lines) do
                if line.leftText and line.leftText ~= "" then
                    lines[#lines + 1] = line.leftText
                end

                if line.rightText and line.rightText ~= "" then
                    lines[#lines + 1] = line.rightText
                end
            end

            if #lines > 0 then
                return table.concat(lines, "\n")
            end
        end
    end

    return ReadTooltipViaScanner(bag, slot)
end

local function ParseNumber(value)
    value = tostring(value or ""):gsub(",", "")
    return tonumber(value) or 0
end

local function GetPercentBase(kind)
    if kind == "mana" and UnitPowerMax and Enum and Enum.PowerType then
        return UnitPowerMax("player", Enum.PowerType.Mana) or 0
    elseif kind == "mana" and UnitPowerMax then
        return UnitPowerMax("player", 0) or 0
    elseif UnitHealthMax then
        return UnitHealthMax("player") or 0
    end

    return 0
end

local function FindRestoreAmount(text, kind)
    local best = 0

    local function AddAmount(amount, percent)
        local value = ParseNumber(amount)

        if percent == "%" then
            value = GetPercentBase(kind) * (value / 100)
        end

        if value > best then
            best = value
        end
    end

    for amount, percent in text:gmatch("restores?%s+([%d,%.]+)(%%?)%s+" .. kind) do
        AddAmount(amount, percent)
    end

    for amount, percent in text:gmatch("restores?%s+([%d,%.]+)(%%?)%s+of%s+your%s+" .. kind) do
        AddAmount(amount, percent)
    end

    for amount, percent in text:gmatch("restoring%s+([%d,%.]+)(%%?)%s+" .. kind) do
        AddAmount(amount, percent)
    end

    for amount, percent in text:gmatch("restoring%s+([%d,%.]+)(%%?)%s+of%s+your%s+" .. kind) do
        AddAmount(amount, percent)
    end

    for amount, percent in text:gmatch("and%s+([%d,%.]+)(%%?)%s+" .. kind) do
        AddAmount(amount, percent)
    end

    for amount, percent in text:gmatch("and%s+([%d,%.]+)(%%?)%s+of%s+your%s+" .. kind) do
        AddAmount(amount, percent)
    end

    return best
end

local function LooksLikeBuffFood(text)
    return text:find("well fed", 1, true)
        or text:find("increase your", 1, true)
        or text:find("increases your", 1, true)
        or text:find("gain ", 1, true) and text:find(" for ", 1, true)
end

local function ContainsAny(text, values)
    for _, value in ipairs(values) do
        if text:find(value, 1, true) then
            return true
        end
    end

    return false
end

local function LooksLikePotion(name, text, itemSubType, classID, subclassID)
    return name:find("potion", 1, true)
        or text:find("potion", 1, true)
        or name:find("serum", 1, true)
        or text:find("serum", 1, true)
        or (classID == CONSUMABLE_CLASS_ID and subclassID == POTION_SUBCLASS_ID)
        or string.lower(itemSubType or ""):find("potion", 1, true)
end

local function LooksLikeNonFoodConsumable(name, text)
    return LooksLikePotion(name, text)
        or name:find("flask", 1, true)
        or text:find("flask", 1, true)
        or name:find("phial", 1, true)
        or text:find("phial", 1, true)
        or name:find("elixir", 1, true)
        or text:find("elixir", 1, true)
        or name:find("healthstone", 1, true)
        or text:find("healthstone", 1, true)
end

local function LooksLikeFoodDrinkSubtype(itemSubType, classID, subclassID)
    local subtype = string.lower(itemSubType or "")

    return subtype:find("food", 1, true)
        or subtype:find("drink", 1, true)
        or (classID == CONSUMABLE_CLASS_ID and subclassID == FOOD_DRINK_SUBCLASS_ID)
end

local function LooksLikeMageFood(name, text)
    return name:find("conjured", 1, true)
        or text:find("conjured", 1, true)
        or name:find("mana bun", 1, true)
        or name:find("mana biscuit", 1, true)
        or name:find("mana strudel", 1, true)
        or name:find("mana pudding", 1, true)
        or name:find("conjured tea", 1, true)
end

local drinkNameHints = {
    "water",
    "drink",
    "tea",
    "juice",
    "milk",
    "wine",
    "mead",
    "brew",
    "coffee",
    "nectar",
    "cola",
    "cider",
    "punch",
    "draft",
    "draught",
    "latte",
    "mosa",
    "refreshment",
}

local foodNameHints = {
    "food",
    "bread",
    "bun",
    "biscuit",
    "strudel",
    "cake",
    "pie",
    "cookie",
    "rations",
    "meal",
    "stew",
    "soup",
    "jerky",
    "cheese",
    "fruit",
    "apple",
    "fish",
    "meat",
    "sandwich",
    "snack",
    "pudding",
}

local function ScoreCandidate(candidate)
    return (candidate.isMageFood and 1000000000000 or 0)
        + ((candidate.restore or 0) * 10000)
        + ((candidate.itemLevel or 0) * 100)
        + ((candidate.quality or 0) * 10)
        + (candidate.itemID or 0) / 1000000
end

local function BetterCandidate(current, candidate)
    if not candidate then
        return current
    end

    if not current or ScoreCandidate(candidate) > ScoreCandidate(current) then
        return candidate
    end

    return current
end

local function GetItemInfoSafe(itemID)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(itemID)
    elseif GetItemInfo then
        return GetItemInfo(itemID)
    end
end

local function GetItemInfoInstantSafe(itemID)
    if C_Item and C_Item.GetItemInfoInstant then
        return C_Item.GetItemInfoInstant(itemID)
    elseif GetItemInfoInstant then
        return GetItemInfoInstant(itemID)
    end
end

local function GetFallbackRestore(candidate)
    local level = tonumber(candidate.itemLevel) or 0

    if level <= 0 then
        level = tonumber(candidate.requiredLevel) or 0
    end

    if level <= 0 then
        level = tonumber(candidate.itemID) or 0
    end

    return level
end

local function RequestItemInfo(itemID)
    pendingItemInfo = true

    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
end

local function BuildCandidate(itemID, bag, slot)
    local name, _, quality, itemLevel, requiredLevel, itemType, itemSubType, _, _, _, _, classID, subclassID = GetItemInfoSafe(itemID)
    local _, instantItemType, instantItemSubType, _, _, instantClassID, instantSubclassID = GetItemInfoInstantSafe(itemID)

    if not name then
        RequestItemInfo(itemID)
        return nil
    end

    itemType = itemType or instantItemType
    itemSubType = itemSubType or instantItemSubType
    classID = classID or instantClassID
    subclassID = subclassID or instantSubclassID

    local tooltip = ReadTooltipText(bag, slot)
    local lowerName = string.lower(name or "")
    local lowerTooltip = string.lower(tooltip or "")
    local healthRestore = FindRestoreAmount(lowerTooltip, "health")
    local manaRestore = FindRestoreAmount(lowerTooltip, "mana")
    local foodDrinkSubtype = LooksLikeFoodDrinkSubtype(itemSubType, classID, subclassID)
    local likelyDrinkName = ContainsAny(lowerName, drinkNameHints) or ContainsAny(lowerTooltip, drinkNameHints)
    local likelyFoodName = ContainsAny(lowerName, foodNameHints) or ContainsAny(lowerTooltip, foodNameHints)
    local candidate = {
        itemID = itemID,
        name = name,
        quality = quality or 0,
        itemLevel = itemLevel or 0,
        requiredLevel = requiredLevel or 0,
        itemType = itemType,
        itemSubType = itemSubType,
        classID = classID,
        subclassID = subclassID,
        tooltip = lowerTooltip,
        lowerName = lowerName,
        healthRestore = healthRestore,
        manaRestore = manaRestore,
    }

    if LooksLikeBuffFood(lowerTooltip) then
        candidate.isBuffFood = true
    end

    if LooksLikeMageFood(lowerName, lowerTooltip) then
        candidate.isMageFood = true
    end

    if LooksLikePotion(lowerName, lowerTooltip, itemSubType, classID, subclassID) then
        candidate.isPotion = true
    end

    local fallbackRestore = GetFallbackRestore(candidate)
    local validFoodDrink = foodDrinkSubtype and not candidate.isBuffFood and not LooksLikeNonFoodConsumable(lowerName, lowerTooltip)

    if healthRestore > 0 and not candidate.isBuffFood and not LooksLikeNonFoodConsumable(lowerName, lowerTooltip) then
        candidate.isFood = true
        candidate.restore = math.max(candidate.restore or 0, healthRestore)
    elseif validFoodDrink and (likelyFoodName or candidate.isMageFood or not likelyDrinkName) then
        candidate.isFood = true
        candidate.restore = math.max(candidate.restore or 0, fallbackRestore)
    end

    if manaRestore > 0 and not candidate.isBuffFood and not LooksLikeNonFoodConsumable(lowerName, lowerTooltip) then
        candidate.isDrink = true
        candidate.restore = math.max(candidate.restore or 0, manaRestore)
    elseif validFoodDrink and (likelyDrinkName or candidate.isMageFood) then
        candidate.isDrink = true
        candidate.restore = math.max(candidate.restore or 0, fallbackRestore)
    end

    if candidate.isPotion and (healthRestore > 0 or lowerName:find("healing", 1, true) or lowerName:find("health", 1, true)) and not lowerName:find("mana", 1, true) then
        candidate.isHealthPotion = true
        candidate.restore = math.max(candidate.restore or 0, healthRestore, fallbackRestore)
    end

    if candidate.isPotion and (manaRestore > 0 or lowerName:find("mana", 1, true)) then
        candidate.isManaPotion = true
        candidate.restore = math.max(candidate.restore or 0, manaRestore, fallbackRestore)
    end

    return candidate
end

local function ScanConsumables()
    local signature = BuildBagSignature()

    if signature == lastBagSignature and lastConsumableScan and not lastScanHadPendingItems then
        pendingItemInfo = false
        return lastConsumableScan
    end

    local best = {}

    pendingItemInfo = false

    for _, bag in ipairs(GetBagIds()) do
        local slots = GetContainerNumSlotsSafe(bag)

        for slot = 1, slots do
            local itemID = GetContainerItemIDSafe(bag, slot)

            if itemID then
                local candidate = BuildCandidate(itemID, bag, slot)

                if candidate then
                    if candidate.isFood then
                        best.food = BetterCandidate(best.food, candidate)
                    end

                    if candidate.isDrink then
                        best.drink = BetterCandidate(best.drink, candidate)
                    end

                    if candidate.isHealthPotion then
                        best.healthPotion = BetterCandidate(best.healthPotion, candidate)
                    end

                    if candidate.isManaPotion then
                        best.manaPotion = BetterCandidate(best.manaPotion, candidate)
                    end
                end
            end
        end
    end

    lastBagSignature = signature
    lastConsumableScan = best
    lastScanHadPendingItems = pendingItemInfo == true

    return best
end

local function GetRecuperateName()
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(RECUPERATE_SPELL_ID)

        if info and info.name then
            return info.name
        end
    elseif GetSpellInfo then
        return GetSpellInfo(RECUPERATE_SPELL_ID)
    end

    return "Recuperate"
end

local function IsRecuperateKnown()
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        return C_SpellBook.IsSpellInSpellBook(RECUPERATE_SPELL_ID) == true
    end

    return true
end

local function FindGeneralMacroIndex(name)
    if not GetMacroInfo then
        return nil
    end

    local maxAccountMacros = MAX_ACCOUNT_MACROS or 120

    for index = 1, maxAccountMacros do
        local macroName = GetMacroInfo(index)

        if macroName == name then
            return index
        end
    end

    return nil
end

local function FindCharacterMacroIndex(name)
    if not GetMacroInfo then
        return nil
    end

    local firstCharacterMacro = (MAX_ACCOUNT_MACROS or 120) + 1
    local lastCharacterMacro = (MAX_ACCOUNT_MACROS or 120) + (MAX_CHARACTER_MACROS or 18)

    for index = firstCharacterMacro, lastCharacterMacro do
        local macroName = GetMacroInfo(index)

        if macroName == name then
            return index
        end
    end

    return nil
end

local function CreateMacroIfMissing(name, body)
    local index = FindGeneralMacroIndex(name)

    if index then
        return index
    end

    local characterIndex = FindCharacterMacroIndex(name)

    if characterIndex and DeleteMacro then
        pcall(DeleteMacro, characterIndex)
        index = FindGeneralMacroIndex(name)

        if index then
            return index
        end
    end

    if not CreateMacro then
        return nil
    end

    local ok = pcall(CreateMacro, name, MACRO_ICON, body or "#showtooltip", false)

    if not ok then
        pcall(CreateMacro, name, MACRO_ICON, body or "#showtooltip")
    end

    return FindGeneralMacroIndex(name)
end

local function WriteMacro(name, body)
    if not body or body == "" then
        return false
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingCombatUpdate = true
        return false
    end

    local index = CreateMacroIfMissing(name, body)

    if not index then
        return false
    end

    if GetMacroInfo then
        local _, _, existingBody = GetMacroInfo(index)

        if existingBody == body then
            return false
        end
    end

    if EditMacro then
        local ok = pcall(EditMacro, index, name, MACRO_ICON, body)
        return ok == true
    end

    return true
end

local function BuildHealthMacro(db, consumables)
    local lines = {}
    local tooltipParts = {}

    if db.healthCombatItems then
        if GetItemCountSafe(DEMONIC_HEALTHSTONE_ITEM_ID) > 0 then
            tooltipParts[#tooltipParts + 1] = "[combat] item:" .. DEMONIC_HEALTHSTONE_ITEM_ID
        elseif GetItemCountSafe(HEALTHSTONE_ITEM_ID) > 0 then
            tooltipParts[#tooltipParts + 1] = "[combat] item:" .. HEALTHSTONE_ITEM_ID
        elseif consumables.healthPotion then
            tooltipParts[#tooltipParts + 1] = "[combat] item:" .. consumables.healthPotion.itemID
        else
            tooltipParts[#tooltipParts + 1] = "[combat] item:" .. HEALTHSTONE_ITEM_ID
        end
    end

    if db.healthUseRecuperate and IsRecuperateKnown() then
        tooltipParts[#tooltipParts + 1] = "[nocombat] " .. GetRecuperateName()
    elseif consumables.food then
        tooltipParts[#tooltipParts + 1] = "[nocombat] item:" .. consumables.food.itemID
    end

    local tooltip = #tooltipParts > 0 and ("#showtooltip " .. table.concat(tooltipParts, "; ")) or "#showtooltip"

    lines[#lines + 1] = tooltip

    if db.healthCombatItems then
        lines[#lines + 1] = "/use [combat] item:" .. DEMONIC_HEALTHSTONE_ITEM_ID
        lines[#lines + 1] = "/use [combat] item:" .. HEALTHSTONE_ITEM_ID

        if consumables.healthPotion then
            lines[#lines + 1] = "/use [combat] item:" .. consumables.healthPotion.itemID
        end
    end

    if db.healthUseRecuperate and IsRecuperateKnown() then
        lines[#lines + 1] = "/cast [nocombat] " .. GetRecuperateName()
        lastStatus.health = "Health macro uses Recuperate out of combat."
    elseif consumables.food then
        lines[#lines + 1] = "/use [nocombat] item:" .. consumables.food.itemID
        lastStatus.health = "Health macro food: " .. consumables.food.name
    else
        lastStatus.health = "Health macro created, but no non-buff food was found."
    end

    if db.healthCombatItems then
        if consumables.healthPotion then
            lastStatus.health = lastStatus.health .. " Combat: Healthstone, then " .. consumables.healthPotion.name .. "."
        else
            lastStatus.health = lastStatus.health .. " Combat: Healthstone."
        end
    end

    return table.concat(lines, "\n")
end

local function BuildManaMacro(db, consumables)
    local lines = {}
    local tooltipParts = {}

    if db.manaCombatPotion and consumables.manaPotion then
        tooltipParts[#tooltipParts + 1] = "[combat] item:" .. consumables.manaPotion.itemID
    end

    if consumables.drink then
        tooltipParts[#tooltipParts + 1] = "[nocombat] item:" .. consumables.drink.itemID
    elseif consumables.manaPotion and db.manaCombatPotion then
        tooltipParts[#tooltipParts + 1] = "[combat] item:" .. consumables.manaPotion.itemID
    end

    local tooltip = #tooltipParts > 0 and ("#showtooltip " .. table.concat(tooltipParts, "; ")) or "#showtooltip"

    lines[#lines + 1] = tooltip

    if db.manaCombatPotion and consumables.manaPotion then
        lines[#lines + 1] = "/use [combat] item:" .. consumables.manaPotion.itemID
    end

    if consumables.drink then
        lines[#lines + 1] = "/use [nocombat] item:" .. consumables.drink.itemID
        lastStatus.mana = "Mana macro drink: " .. consumables.drink.name
    else
        lastStatus.mana = "Mana macro created, but no non-buff drink was found."
    end

    if db.manaCombatPotion and consumables.manaPotion then
        lastStatus.mana = lastStatus.mana .. " Combat: " .. consumables.manaPotion.name .. "."
    end

    return table.concat(lines, "\n")
end

local function UpdateMacros(manual)
    updateScheduled = false

    local db = EnsureMacroDB()

    if not db then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingCombatUpdate = true
        return
    end

    local consumables = ScanConsumables()
    local updated = false

    if db.healthEnabled then
        updated = WriteMacro(HEALTH_MACRO_NAME, BuildHealthMacro(db, consumables)) or updated
    else
        lastStatus.health = "Health macro disabled."
    end

    if db.manaEnabled then
        updated = WriteMacro(MANA_MACRO_NAME, BuildManaMacro(db, consumables)) or updated
    else
        lastStatus.mana = "Mana macro disabled."
    end

    if pendingItemInfo and C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            if db.healthEnabled or db.manaEnabled then
                ns:RefreshConsumableMacros(true)
            end
        end)
    end

    if manual and ns.Print then
        if updated then
            ns:Print("Consumable macros refreshed.")
        else
            ns:Print("Consumable macro refresh is pending or no macro changed.")
        end
    end

    if ns.UI and ns.UI.RefreshVisiblePage then
        ns.UI.RefreshVisiblePage()
    end
end

local function ScheduleMacroUpdate(delay, manual)
    local db = EnsureMacroDB()

    if not db or (not db.healthEnabled and not db.manaEnabled and not manual) then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingCombatUpdate = true
        return
    end

    if updateScheduled then
        return
    end

    updateScheduled = true
    delay = delay or 0.15

    if C_Timer and C_Timer.After then
        C_Timer.After(delay, function()
            UpdateMacros(manual == true)
        end)
    else
        UpdateMacros(manual == true)
    end
end

local function RequestBagOpenMacroUpdate()
    ScheduleMacroUpdate(0.1, false)
end

local function HookBagOpenRefresh()
    if hooksecurefunc and not bagHooksInstalled then
        bagHooksInstalled = true

        if ToggleAllBags then
            hooksecurefunc("ToggleAllBags", RequestBagOpenMacroUpdate)
        end

        if OpenAllBags then
            hooksecurefunc("OpenAllBags", RequestBagOpenMacroUpdate)
        end

        if ToggleBag then
            hooksecurefunc("ToggleBag", RequestBagOpenMacroUpdate)
        end

        if OpenBag then
            hooksecurefunc("OpenBag", RequestBagOpenMacroUpdate)
        end
    end

    local function HookBagFrame(bagFrame)
        if bagFrame and bagFrame.HookScript and not hookedBagFrames[bagFrame] then
            hookedBagFrames[bagFrame] = true
            bagFrame:HookScript("OnShow", RequestBagOpenMacroUpdate)
        end
    end

    HookBagFrame(ContainerFrameCombinedBags)

    for index = 1, NUM_CONTAINER_FRAMES or 13 do
        HookBagFrame(_G["ContainerFrame" .. index])
    end
end

function ns:GetConsumableMacroOption(key)
    local db = EnsureMacroDB()

    return db and db[key]
end

function ns:SetConsumableMacroOption(key, value)
    local db = EnsureMacroDB()

    if not db then
        return
    end

    db[key] = value == true
    ScheduleMacroUpdate(0.05, true)
end

function ns:GetConsumableMacroStatus()
    return lastStatus.health or "", lastStatus.mana or ""
end

function ns:GetConsumableMacroNames()
    return HEALTH_MACRO_NAME, MANA_MACRO_NAME
end

function ns:RefreshConsumableMacros(quiet)
    ScheduleMacroUpdate(0.05, quiet ~= true)
end

function ns:InitializeConsumableMacros()
    EnsureMacroDB()

    if initialized then
        return
    end

    initialized = true
    frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingCombatUpdate then
                pendingCombatUpdate = false
                ScheduleMacroUpdate(0.05, false)
            end
        elseif InCombatLockdown and InCombatLockdown() then
            pendingCombatUpdate = true
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            if pendingItemInfo then
                ScheduleMacroUpdate(0.15, false)
            end
        elseif event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" or event == "PLAYER_LOGIN" then
            ScheduleMacroUpdate(0.25, false)
        else
            ScheduleMacroUpdate(0.25, false)
        end
    end)

    HookBagOpenRefresh()

    if C_Timer and C_Timer.After then
        C_Timer.After(1, HookBagOpenRefresh)
    end

    ScheduleMacroUpdate(0.5, false)
end
