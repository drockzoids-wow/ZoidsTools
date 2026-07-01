local _, ns = ...

local helperButton
local eventFrame
local tooltipHooked = false
local lastActionText = ""
local lastTooltipOwner
local lastTooltipBagID
local lastTooltipSlotID
local clickRegistrationPending = false

local BUTTON_NAME = "ZoidsToolsProfessionActionButton"
local ACTION_BUTTON_USE_KEY_DOWN_CVAR = "ActionButtonUseKeyDown"
local MACRO_SALVAGE = "/run C_TradeSkillUI.CraftSalvage(%d, 1, ItemLocation:CreateFromBagAndSlot(%d, %d))"

local ACTION_COLORS = {
    disenchant = { 0.50, 0.50, 1.00, 1 },
    mill = { 0.50, 1.00, 0.50, 1 },
    prospect = { 1.00, 0.34, 0.34, 1 },
    open = { 1.00, 1.00, 1.00, 1 },
}

local ACTIVATION_OPTIONS = {
    { value = "alt", text = ALT_KEY or "Alt" },
    { value = "altctrl", text = (ALT_KEY_TEXT or "Alt") .. " + " .. (CTRL_KEY or "Ctrl") },
    { value = "altshift", text = (ALT_KEY_TEXT or "Alt") .. " + " .. (SHIFT_KEY or "Shift") },
}

-- Profession item mappings are local to ZoidsTools. Molinari's MIT-licensed
-- implementation was reviewed for behavior, but ZoidsTools does not call it.
local MILLABLE = {
    [765] = { 382994, 5 }, [785] = { 382994, 5 }, [2447] = { 382994, 5 },
    [2449] = { 382994, 5 }, [2450] = { 382994, 5 }, [2452] = { 382994, 5 },
    [2453] = { 382994, 5 }, [3355] = { 382994, 5 }, [3356] = { 382994, 5 },
    [3357] = { 382994, 5 }, [3358] = { 382994, 5 }, [3369] = { 382994, 5 },
    [3818] = { 382994, 5 }, [3819] = { 382994, 5 }, [3820] = { 382994, 5 },
    [3821] = { 382994, 5 }, [4625] = { 382994, 5 }, [8831] = { 382994, 5 },
    [8838] = { 382994, 5 }, [8839] = { 382994, 5 }, [8845] = { 382994, 5 },
    [8846] = { 382994, 5 }, [13463] = { 382994, 5 }, [13464] = { 382994, 5 },
    [13465] = { 382994, 5 }, [13466] = { 382994, 5 }, [13467] = { 382994, 5 },
    [22785] = { 382991, 5 }, [22786] = { 382991, 5 }, [22787] = { 382991, 5 },
    [22789] = { 382991, 5 }, [22790] = { 382991, 5 }, [22791] = { 382991, 5 },
    [22792] = { 382991, 5 }, [22793] = { 382991, 5 }, [36901] = { 382990, 5 },
    [36903] = { 382990, 5 }, [36904] = { 382990, 5 }, [36905] = { 382990, 5 },
    [36906] = { 382990, 5 }, [36907] = { 382990, 5 }, [37921] = { 382990, 5 },
    [39970] = { 382990, 5 }, [52983] = { 382989, 5 }, [52984] = { 382989, 5 },
    [52985] = { 382989, 5 }, [52986] = { 382989, 5 }, [52987] = { 382989, 5 },
    [52988] = { 382989, 5 }, [72234] = { 382988, 5 }, [72235] = { 382988, 5 },
    [72237] = { 382988, 5 }, [79010] = { 382988, 5 }, [79011] = { 382988, 5 },
    [87821] = { 382988, 5 }, [89639] = { 382988, 5 }, [109124] = { 382987, 5 },
    [109125] = { 382987, 5 }, [109126] = { 382987, 5 }, [109127] = { 382987, 5 },
    [109128] = { 382987, 5 }, [109129] = { 382987, 5 }, [109130] = { 382987, 5 },
    [124101] = { 382986, 5 }, [124102] = { 382986, 5 }, [124103] = { 382986, 5 },
    [124104] = { 382986, 5 }, [124105] = { 382986, 5 }, [124106] = { 382986, 5 },
    [128304] = { 382986, 5 }, [151565] = { 382986, 5 }, [152505] = { 382984, 5 },
    [152506] = { 382984, 5 }, [152507] = { 382984, 5 }, [152508] = { 382984, 5 },
    [152509] = { 382984, 5 }, [152510] = { 382984, 5 }, [152511] = { 382984, 5 },
    [168487] = { 382984, 5 }, [168583] = { 382982, 5 }, [168586] = { 382982, 5 },
    [168589] = { 382982, 5 }, [169701] = { 382982, 5 }, [170554] = { 382982, 5 },
    [171315] = { 382982, 5 }, [187699] = { 382982, 5 }, [191460] = { 382981, 5 },
    [191461] = { 382981, 5 }, [191462] = { 382981, 5 }, [191464] = { 382981, 5 },
    [191465] = { 382981, 5 }, [191466] = { 382981, 5 }, [191467] = { 382981, 5 },
    [191468] = { 382981, 5 }, [191469] = { 382981, 5 }, [191470] = { 382981, 5 },
    [191471] = { 382981, 5 }, [191472] = { 382981, 5 }, [200061] = { 382981, 5 },
    [210796] = { 444181, 10 }, [210797] = { 444181, 10 }, [210798] = { 444181, 10 },
    [210799] = { 444181, 10 }, [210800] = { 444181, 10 }, [210801] = { 444181, 10 },
    [210802] = { 444181, 10 }, [210803] = { 444181, 10 }, [210804] = { 444181, 10 },
    [210805] = { 444181, 10 }, [210806] = { 444181, 10 }, [210807] = { 444181, 10 },
    [220141] = { 444181, 10 }, [236761] = { 1269575, 10 }, [236767] = { 1269575, 10 },
    [236770] = { 1269575, 10 }, [236771] = { 1269575, 10 }, [236776] = { 1269575, 10 },
    [236777] = { 1269575, 10 }, [236778] = { 1269575, 10 }, [236779] = { 1269575, 10 },
}

local PROSPECTABLE = {
    [2770] = { 382995, 5 }, [2771] = { 382995, 5 }, [2772] = { 382995, 5 },
    [3858] = { 382995, 5 }, [10620] = { 382995, 5 }, [23424] = { 382980, 5 },
    [23425] = { 382980, 5 }, [36909] = { 382979, 5 }, [36910] = { 382979, 5 },
    [36912] = { 382979, 5 }, [52183] = { 382978, 5 }, [52185] = { 382978, 5 },
    [53038] = { 382978, 5 }, [72092] = { 382977, 5 }, [72093] = { 382977, 5 },
    [72094] = { 382977, 5 }, [72103] = { 382977, 5 }, [123918] = { 382975, 5 },
    [123919] = { 382975, 5 }, [151564] = { 382975, 5 }, [152512] = { 382973, 5 },
    [152513] = { 382973, 5 }, [152579] = { 382973, 5 }, [168185] = { 382973, 5 },
    [171828] = { 325248, 5 }, [171829] = { 325248, 5 }, [171830] = { 325248, 5 },
    [171831] = { 325248, 5 }, [171832] = { 325248, 5 }, [171833] = { 325248, 5 },
    [187700] = { 325248, 5 }, [188658] = { 374627, 5 }, [189143] = { 374627, 5 },
    [190311] = { 374627, 5 }, [190312] = { 374627, 5 }, [190313] = { 374627, 5 },
    [190314] = { 374627, 5 }, [190394] = { 374627, 5 }, [190395] = { 374627, 5 },
    [190396] = { 374627, 5 }, [192880] = { 374627, 5 }, [194545] = { 374627, 5 },
    [199344] = { 374627, 5 }, [210930] = { 434018, 5 }, [210931] = { 434018, 5 },
    [210932] = { 434018, 5 }, [210933] = { 434018, 5 }, [210934] = { 434018, 5 },
    [210935] = { 434018, 5 }, [210936] = { 434018, 5 }, [210937] = { 434018, 5 },
    [210938] = { 434018, 5 }, [210939] = { 434018, 5 }, [213398] = { 434018, 5 },
    [237359] = { 1231127, 5 }, [237361] = { 1231127, 5 }, [237362] = { 1231127, 5 },
    [237363] = { 1231127, 5 }, [237364] = { 1231127, 5 }, [237365] = { 1231127, 5 },
    [237366] = { 1231127, 5 }, [240216] = { 434018, 5 }, [249218] = { 434018, 5 },
}

local SPECIAL_DISENCHANTABLE = {
    [137195] = true, [137221] = true, [137286] = true, [181991] = true,
    [182021] = true, [182043] = true, [182067] = true, [190336] = true,
    [198675] = true, [198689] = true, [198694] = true, [198798] = true,
    [198799] = true, [198800] = true, [200479] = true, [200939] = true,
    [200940] = true, [200941] = true, [200942] = true, [200943] = true,
    [200945] = true, [200946] = true, [200947] = true, [201356] = true,
    [201357] = true, [201358] = true, [201359] = true, [201360] = true,
    [204990] = true, [204999] = true, [205001] = true, [210228] = true,
    [210231] = true, [210234] = true,
}

local OPENABLE = {
    [4632] = 15, [4633] = 15, [4634] = 15, [4636] = 15, [4637] = 15,
    [4638] = 15, [5758] = 15, [5759] = 15, [5760] = 15, [6354] = 15,
    [6355] = 15, [7209] = 1, [12033] = 15, [13875] = 15, [13918] = 15,
    [16882] = 15, [16883] = 15, [16884] = 15, [16885] = 15, [29569] = 30,
    [31952] = 30, [43575] = 30, [43622] = 30, [43624] = 30, [45986] = 30,
    [63349] = 30, [68729] = 30, [88165] = 35, [88567] = 35, [106895] = 40,
    [116920] = 40, [121331] = 45, [169475] = 50, [179311] = 60,
    [180522] = 60, [180532] = 60, [180533] = 60, [186160] = 60,
    [186161] = 60, [188787] = 60, [190954] = 65, [198657] = 65,
    [203743] = 15, [204307] = 15, [220376] = 75, [264475] = 85,
}

local OPENING_KEYS = {
    [4367] = { 15, 0 }, [4398] = { 20, 0 }, [7208] = { 1, 0 },
    [15869] = { 15, 0 }, [15870] = { 15, 0 }, [15871] = { 20, 0 },
    [15872] = { 30, 0 }, [18594] = { 30, 0 }, [23819] = { 30, 0 },
    [43853] = { 30, 0 }, [43854] = { 30, 0 }, [55053] = { 35, 0 },
    [60853] = { 35, 0 }, [77532] = { 35, 0 }, [82960] = { 35, 0 },
    [130250] = { 550, 0 }, [132172] = { 550, 0 }, [159825] = { 50, 0 },
    [159826] = { 50, 0 }, [171441] = { 60, 51 }, [173065] = { 60, 51 },
    [191256] = { 70, 61 }, [222523] = { 80, 1 }, [260232] = { 90, 1 },
}

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.professions = ns.db.professions or {}

    local db = ns.db.professions

    if db.enabled == nil then
        db.enabled = true
    end

    if db.activation ~= "altctrl" and db.activation ~= "altshift" then
        db.activation = "alt"
    end

    db.actions = db.actions or {}

    if db.actions.disenchant == nil then
        db.actions.disenchant = true
    end

    if db.actions.mill == nil then
        db.actions.mill = true
    end

    if db.actions.prospect == nil then
        db.actions.prospect = true
    end

    if db.actions.open == nil then
        db.actions.open = true
    end

    return db
end

local function IsSpellKnown(spellID)
    if not spellID then
        return false
    end

    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then
        return true
    end

    if C_SpellBook and C_SpellBook.IsSpellKnownOrOverridesKnown and C_SpellBook.IsSpellKnownOrOverridesKnown(spellID) then
        return true
    end

    return IsPlayerSpell and IsPlayerSpell(spellID)
end

local function GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end

    return GetSpellInfo and GetSpellInfo(spellID)
end

local function GetItemName(itemID)
    return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID) or ("item:" .. tostring(itemID))
end

local function GetStackCount(location)
    if location and C_Item and C_Item.GetStackCount then
        return C_Item.GetStackCount(location) or 0
    end

    return 0
end

local function IsKeyUsable(itemID)
    if not C_TooltipInfo or not C_TooltipInfo.GetItemByID or not Enum or not Enum.TooltipDataLineType then
        return true
    end

    local data = C_TooltipInfo.GetItemByID(itemID)

    if not data or not data.lines then
        return true
    end

    for index = 3, #data.lines do
        local line = data.lines[index]

        if line and line.type == Enum.TooltipDataLineType.RestrictedSkill then
            return line.leftColor and line.leftColor:IsRGBEqualTo(CreateColor(1, 1, 1))
        end
    end

    return true
end

local function GetBestOpeningKey(requiredLevel)
    local playerLevel = UnitLevel and UnitLevel("player") or 0

    for keyItemID, info in pairs(OPENING_KEYS) do
        if info[1] >= requiredLevel
            and info[2] <= playerLevel
            and C_Item.GetItemCount(keyItemID) > 0
            and IsKeyUsable(keyItemID)
        then
            return keyItemID
        end
    end

    return nil
end

local function CreateSalvageAction(actionType, item, itemID, info)
    if not C_TradeSkillUI or not C_TradeSkillUI.CraftSalvage then
        return nil
    end

    local recipeID = info and info[1]
    local requiredCount = info and info[2] or 1

    if not IsSpellKnown(recipeID) then
        return nil
    end

    local location = item:GetItemLocation()

    if not location or not location:IsBagAndSlot() or GetStackCount(location) < requiredCount then
        return nil
    end

    local bagID, slotID = location:GetBagAndSlot()

    return {
        kind = "macrotext",
        actionType = actionType,
        macrotext = MACRO_SALVAGE:format(recipeID, bagID, slotID),
        bagID = bagID,
        slotID = slotID,
        color = ACTION_COLORS[actionType],
        label = GetSpellName(recipeID) or actionType,
        itemID = itemID,
    }
end

local function CreateTargetSpellAction(actionType, spellID, itemID, bagID, slotID, color, label)
    if not spellID or not bagID or not slotID then
        return nil
    end

    if FindSpellBookSlotBySpellID and FindSpellBookSlotBySpellID(spellID) then
        return {
            kind = "spell",
            actionType = actionType,
            spellID = spellID,
            bagID = bagID,
            slotID = slotID,
            color = color,
            label = label or GetSpellName(spellID) or actionType,
            itemID = itemID,
        }
    end

    if actionType == "disenchant" and C_TradeSkillUI and C_TradeSkillUI.CraftSalvage then
        return {
            kind = "macrotext",
            actionType = actionType,
            macrotext = MACRO_SALVAGE:format(spellID, bagID, slotID),
            bagID = bagID,
            slotID = slotID,
            color = color,
            label = label or GetSpellName(spellID) or actionType,
            itemID = itemID,
        }
    end

    return {
        kind = "spell",
        actionType = actionType,
        spellID = spellID,
        bagID = bagID,
        slotID = slotID,
        color = color,
        label = label or GetSpellName(spellID) or actionType,
        itemID = itemID,
    }
end

local function IsDisenchantable(itemID)
    if not IsSpellKnown(13262) then
        return false
    end

    if SPECIAL_DISENCHANTABLE[itemID] then
        return true
    end

    local _, _, quality, _, _, _, _, _, _, _, _, classID, subClassID = C_Item.GetItemInfo(itemID)

    if not quality or quality < Enum.ItemQuality.Uncommon or quality > Enum.ItemQuality.Epic then
        return false
    end

    if classID ~= Enum.ItemClass.Weapon
        and classID ~= Enum.ItemClass.Armor
        and classID ~= Enum.ItemClass.Profession
        and not (classID == Enum.ItemClass.Gem and subClassID == Enum.ItemGemSubclass.Artifactrelic)
    then
        return false
    end

    if C_Item.GetItemInventoryTypeByID(itemID) == Enum.InventoryType.IndexBodyType then
        return false
    end

    if C_Item.IsCosmeticItem and C_Item.IsCosmeticItem(itemID) then
        return false
    end

    return true
end

local function CreateDisenchantAction(item, itemID)
    local location = item:GetItemLocation()

    if not location or not location:IsBagAndSlot() or not IsDisenchantable(itemID) then
        return nil
    end

    local bagID, slotID = location:GetBagAndSlot()

    return CreateTargetSpellAction("disenchant", 13262, itemID, bagID, slotID, ACTION_COLORS.disenchant, GetSpellName(13262) or "Disenchant")
end

local function CreateOpenAction(item, itemID)
    local requiredLevel = OPENABLE[itemID]

    if not requiredLevel then
        return nil
    end

    local location = item:GetItemLocation()

    if not location or not location:IsBagAndSlot() then
        return nil
    end

    local bagID, slotID = location:GetBagAndSlot()
    local spellID

    if IsSpellKnown(1804) and requiredLevel <= ((UnitLevel and UnitLevel("player") or 0) * 1) then
        spellID = 1804
    elseif IsSpellKnown(312890) and requiredLevel <= (UnitLevel and UnitLevel("player") or 0) then
        spellID = 312890
    elseif IsSpellKnown(323427) and requiredLevel <= 60 then
        spellID = 323427
    end

    if spellID then
        return CreateTargetSpellAction("open", spellID, itemID, bagID, slotID, ACTION_COLORS.open, GetSpellName(spellID) or "Open")
    end

    local keyItemID = GetBestOpeningKey(requiredLevel)

    if keyItemID then
        return {
            kind = "item",
            actionType = "open",
            item = "item:" .. tostring(keyItemID),
            keyItemID = keyItemID,
            bagID = bagID,
            slotID = slotID,
            color = ACTION_COLORS.open,
            label = GetItemName(keyItemID) or "Open",
            itemID = itemID,
        }
    end

    return nil
end

local function GetProfessionAction(item)
    local db = EnsureDB()

    if not db or db.enabled ~= true or not item or not item.GetItemID then
        return nil
    end

    local itemID = item:GetItemID()

    if not itemID then
        return nil
    end

    if db.actions.prospect and PROSPECTABLE[itemID] then
        local action = CreateSalvageAction("prospect", item, itemID, PROSPECTABLE[itemID])

        if action then
            return action
        end
    end

    if db.actions.mill and MILLABLE[itemID] then
        local action = CreateSalvageAction("mill", item, itemID, MILLABLE[itemID])

        if action then
            return action
        end
    end

    if db.actions.disenchant then
        local action = CreateDisenchantAction(item, itemID)

        if action then
            return action
        end
    end

    if db.actions.open then
        return CreateOpenAction(item, itemID)
    end

    return nil
end

local function GetActivationMode()
    local db = EnsureDB()
    local value = db and db.activation or "alt"

    if value == "alt" or value == "altctrl" or value == "altshift" then
        return value
    end

    return "alt"
end

local function IsActivationModifierHeld()
    local mode = GetActivationMode()

    if mode == "altctrl" then
        return IsAltKeyDown() and IsControlKeyDown() and not IsShiftKeyDown()
    elseif mode == "altshift" then
        return IsAltKeyDown() and IsShiftKeyDown() and not IsControlKeyDown()
    end

    return IsAltKeyDown() and not IsControlKeyDown() and not IsShiftKeyDown()
end

local function GetActivationText()
    local mode = GetActivationMode()

    if mode == "altctrl" then
        return (ALT_KEY_TEXT or "Alt") .. "+" .. (CTRL_KEY or "Ctrl") .. "-click"
    elseif mode == "altshift" then
        return (ALT_KEY_TEXT or "Alt") .. "+" .. (SHIFT_KEY or "Shift") .. "-click"
    elseif mode == "alt" then
        return (ALT_KEY or "Alt") .. "-click"
    end

    return (ALT_KEY or "Alt") .. "-click"
end

local function ClearSecureActionAttributes(button)
    for _, attr in ipairs({
        "type1",
        "alt-type1",
        "alt-ctrl-type1",
        "alt-shift-type1",
        "spell",
        "spell1",
        "alt-spell1",
        "alt-ctrl-spell1",
        "alt-shift-spell1",
        "item",
        "item1",
        "alt-item1",
        "alt-ctrl-item1",
        "alt-shift-item1",
        "macrotext",
        "macrotext1",
        "alt-macrotext1",
        "alt-ctrl-macrotext1",
        "alt-shift-macrotext1",
    }) do
        button:SetAttribute(attr, nil)
    end
end

local function SetModifiedClickType(button, clickType)
    local mode = GetActivationMode()

    if mode == "altctrl" then
        button:SetAttribute("alt-ctrl-type1", clickType)
    elseif mode == "altshift" then
        button:SetAttribute("alt-shift-type1", clickType)
    else
        button:SetAttribute("alt-type1", clickType)
    end
end

local function RegisterButtonForPreferredClickDirection(button)
    if not button then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        clickRegistrationPending = true
        return false
    end

    clickRegistrationPending = false

    if C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool(ACTION_BUTTON_USE_KEY_DOWN_CVAR) then
        button:RegisterForClicks("AnyDown")
    else
        button:RegisterForClicks("AnyUp")
    end

    return true
end

local function ConfigureButtonForAction(button, action)
    if not button or InCombatLockdown and InCombatLockdown() then
        return false
    end

    ClearSecureActionAttributes(button)
    button:SetAttribute("target-bag", action.bagID)
    button:SetAttribute("target-slot", action.slotID)

    if action.kind == "spell" then
        button:SetAttribute("spell", action.spellID)
        SetModifiedClickType(button, "spell")
    elseif action.kind == "item" then
        button:SetAttribute("item", action.item)
        SetModifiedClickType(button, "item")
    elseif action.kind == "macrotext" then
        button:SetAttribute("macrotext", action.macrotext)
        SetModifiedClickType(button, "macro")
    else
        return false
    end

    button:SetAttribute("zt-ready", true)
    button.action = action
    button:SetGlowColor(action.color)

    return true
end

local function IsPlayerBagSlot(bagID, slotID)
    return bagID and slotID and bagID >= 0 and bagID <= 5
end

local function CreateBagSlotItem(bagID, slotID)
    if Item and Item.CreateFromBagAndSlot then
        return Item:CreateFromBagAndSlot(bagID, slotID)
    end

    if Item and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        return Item:CreateFromItemLocation(ItemLocation:CreateFromBagAndSlot(bagID, slotID))
    end

    return nil
end

local ShowActionForItem

local function ShowActionForBagSlot(tooltip, bagID, slotID)
    if not IsPlayerBagSlot(bagID, slotID) then
        return false
    end

    local item = CreateBagSlotItem(bagID, slotID)

    if not item then
        return false
    end

    lastTooltipOwner = tooltip and tooltip:GetOwner()
    lastTooltipBagID = bagID
    lastTooltipSlotID = slotID
    ShowActionForItem(tooltip, item)

    return true
end

local function AnchorButtonToTooltipOwner(button)
    local owner = GameTooltip and GameTooltip:GetOwner()

    if not owner then
        return false
    end

    local left, bottom, width, height

    if owner.GetScaledRect then
        left, bottom, width, height = owner:GetScaledRect()
    else
        left = owner:GetLeft()
        bottom = owner:GetBottom()
        width = owner:GetWidth()
        height = owner:GetHeight()
    end

    if not left or not bottom or not width or not height then
        return false
    end

    local scaleMultiplier = 1 / UIParent:GetScale()
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scaleMultiplier, bottom * scaleMultiplier)
    button:SetSize(width * scaleMultiplier, height * scaleMultiplier)

    return true
end

local function HideButton()
    if helperButton and not (InCombatLockdown and InCombatLockdown()) then
        helperButton:ClearAllPoints()
        helperButton:Hide()
    end
end

function ShowActionForItem(tooltip, item)
    local db = EnsureDB()

    if not db or db.enabled ~= true or not tooltip or tooltip ~= GameTooltip then
        HideButton()
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        HideButton()
        return
    end

    local action = GetProfessionAction(item)

    if not action then
        HideButton()
        return
    end

    if not IsActivationModifierHeld() then
        HideButton()
        return
    end

    local button = helperButton

    if not button or not ConfigureButtonForAction(button, action) or not AnchorButtonToTooltipOwner(button) then
        return
    end

    button:EnableMouse(true)
    button:Show()
    lastActionText = string.format("%s ready for %s.", tostring(action.label or "Action"), tostring(GetItemName(action.itemID) or "item"))
end

local function HookTooltip()
    if tooltipHooked then
        return
    end

    tooltipHooked = true

    if TooltipDataProcessor and C_TooltipInfo and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if not tooltip or tooltip ~= GameTooltip or tooltip:IsForbidden() then
                return
            end

            local owner = tooltip:GetOwner()

            if not owner or owner == helperButton then
                return
            end

            if data and data.guid and C_Item and C_Item.GetItemLocation then
                local location = C_Item.GetItemLocation(data.guid)

                if location and location:IsBagAndSlot() then
                    local bagID, slotID = location:GetBagAndSlot()

                    if IsPlayerBagSlot(bagID, slotID) then
                        lastTooltipOwner = owner
                        lastTooltipBagID = bagID
                        lastTooltipSlotID = slotID
                        ShowActionForItem(tooltip, Item:CreateFromItemLocation(location))
                    end
                end
            end
        end)
    else
        hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, bagID, slotID)
            if tooltip and tooltip:GetOwner() == helperButton then
                return
            end

            if IsPlayerBagSlot(bagID, slotID) then
                ShowActionForBagSlot(tooltip, bagID, slotID)
            end
        end)
    end
end

local function RecheckCurrentTooltip()
    if not GameTooltip or not GameTooltip:IsShown() or not GameTooltip:GetOwner() then
        return
    end

    local owner = GameTooltip:GetOwner()

    if not owner or not owner.IsMouseOver or not owner:IsMouseOver() then
        return
    end

    if owner.GetSlotAndBagID then
        local slotID, bagID = owner:GetSlotAndBagID()

        if bagID and slotID then
            ShowActionForBagSlot(GameTooltip, bagID, slotID)
            return
        end
    end

    if owner == lastTooltipOwner and IsPlayerBagSlot(lastTooltipBagID, lastTooltipSlotID) then
        ShowActionForBagSlot(GameTooltip, lastTooltipBagID, lastTooltipSlotID)
    end
end

local function UpdateAttributeDriver()
    if not helperButton or InCombatLockdown and InCombatLockdown() then
        return
    end

    if UnregisterAttributeDriver then
        UnregisterAttributeDriver(helperButton, "visibility")
    end

    local mode = GetActivationMode()

    if mode == "altctrl" then
        RegisterAttributeDriver(helperButton, "visibility", "[mod:alt,mod:ctrl] show; hide")
    elseif mode == "altshift" then
        RegisterAttributeDriver(helperButton, "visibility", "[mod:alt,mod:shift] show; hide")
    else
        RegisterAttributeDriver(helperButton, "visibility", "[mod:alt] show; hide")
    end

    helperButton:EnableMouse(true)
end

local function CreateHelperButton()
    if helperButton then
        return helperButton
    end

    local button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate,SecureHandlerAttributeTemplate,SecureHandlerEnterLeaveTemplate")
    button:SetFrameStrata("TOOLTIP")
    RegisterButtonForPreferredClickDirection(button)
    button:Hide()

    button:SetAttribute("_onleave", "self:ClearAllPoints(); self:Hide()")
    button:SetAttribute("_onattributechanged", [[
        if name == "visibility" and value == "show" and not self:GetAttribute("zt-ready") then
            self:ClearAllPoints()
            self:Hide()
        elseif name == "visibility" and value == "hide" and self:IsShown() then
            self:ClearAllPoints()
            self:Hide()
        end
    ]])

    button:HookScript("OnAttributeChanged", function(self, name, value)
        if value ~= nil and (name == "spell" or name == "item" or name == "macrotext") then
            SetModifiedClickType(self, name == "macrotext" and "macro" or name)
        end
    end)

    button:SetScript("OnEnter", function(self)
        if self.action and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(self:GetAttribute("target-bag"), self:GetAttribute("target-slot"))
        end
    end)

    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    button:SetScript("OnHide", function(self)
        self.action = nil

        if InCombatLockdown and InCombatLockdown() then
            return
        end

        self:ClearAllPoints()
        self:SetAttribute("_entered", false)
        self:SetAttribute("zt-ready", false)
        self:SetAttribute("target-bag", nil)
        self:SetAttribute("target-slot", nil)
        ClearSecureActionAttributes(self)
    end)

    local glow = button:CreateTexture(nil, "ARTWORK")
    glow:SetPoint("CENTER")

    if glow.SetAtlas then
        local atlasOK = pcall(glow.SetAtlas, glow, "UI-HUD-ActionBar-Proc-Loop-Flipbook")

        if not atlasOK then
            glow:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        end
    else
        glow:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    end

    glow:SetDesaturated(true)
    button.glow = glow

    local animation = button:CreateAnimationGroup()
    animation:SetLooping("REPEAT")

    local flipBook = animation:CreateAnimation("FlipBook")
    flipBook:SetTarget(glow)
    flipBook:SetDuration(1)
    flipBook:SetFlipBookColumns(5)
    flipBook:SetFlipBookRows(6)
    flipBook:SetFlipBookFrames(30)

    button:SetScript("OnShow", function(self)
        self:SetAttribute("_entered", true)

        if self.glow then
            local width, height = self:GetSize()
            self.glow:SetSize(width * 1.4, height * 1.4)
        end

        animation:Play()
    end)

    button:HookScript("OnHide", function()
        animation:Stop()
    end)

    function button:SetGlowColor(color)
        color = color or ACTION_COLORS.open

        if self.glow and self.glow.SetVertexColor then
            self.glow:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        end
    end

    helperButton = button
    UpdateAttributeDriver()

    return button
end

function ns:GetProfessionHelperEnabled()
    local db = EnsureDB()
    return db and db.enabled == true
end

function ns:SetProfessionHelperEnabled(value)
    local db = EnsureDB()

    if db then
        db.enabled = value == true
    end

    if not value then
        HideButton()
    end
end

function ns:GetProfessionHelperActivationOptions()
    return ACTIVATION_OPTIONS
end

function ns:GetProfessionHelperActivation()
    return GetActivationMode()
end

function ns:SetProfessionHelperActivation(value)
    local db = EnsureDB()

    if db then
        if value == "altctrl" or value == "altshift" then
            db.activation = value
        else
            db.activation = "alt"
        end
    end

    UpdateAttributeDriver()
    RecheckCurrentTooltip()
end

function ns:GetProfessionHelperActionEnabled(actionType)
    local db = EnsureDB()
    return db and db.actions and db.actions[actionType] == true
end

function ns:SetProfessionHelperActionEnabled(actionType, value)
    local db = EnsureDB()

    if db and db.actions and db.actions[actionType] ~= nil then
        db.actions[actionType] = value == true
        RecheckCurrentTooltip()
    end
end

function ns:GetProfessionHelperStatusText()
    local db = EnsureDB()

    if not db or db.enabled ~= true then
        return "Profession Helper is disabled."
    end

    return "Hold " .. GetActivationText() .. " over a profession item, then click it. " .. (lastActionText or "")
end

function ns:InitializeProfessionHelper()
    EnsureDB()
    CreateHelperButton()
    HookTooltip()

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
        eventFrame:RegisterEvent("CVAR_UPDATE")
        eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:SetScript("OnEvent", function(_, event, arg1)
            if event == "BAG_UPDATE_DELAYED" then
                HideButton()
            elseif event == "CVAR_UPDATE" then
                if arg1 == ACTION_BUTTON_USE_KEY_DOWN_CVAR then
                    RegisterButtonForPreferredClickDirection(helperButton)
                end
            elseif event == "MODIFIER_STATE_CHANGED" then
                if not IsActivationModifierHeld() then
                    HideButton()
                end

                RecheckCurrentTooltip()
            elseif event == "PLAYER_REGEN_ENABLED" then
                if clickRegistrationPending then
                    RegisterButtonForPreferredClickDirection(helperButton)
                end

                UpdateAttributeDriver()
                RecheckCurrentTooltip()
            end
        end)
    end
end
