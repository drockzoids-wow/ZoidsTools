local _, ns = ...

local hooked = false
local pending = {}

local BUTTON_ONLY_OPTIONS = {
    CONFIRM_DISENCHANT_ROLL = "disenchantRolls",
    CONFIRM_LOOT_ROLL = "bindPrompts",
    CONFIRM_BINDER = "bindPrompts",
    EQUIP_BIND = "bindPrompts",
    AUTOEQUIP_BIND = "bindPrompts",
    USE_BIND = "bindPrompts",
    REPLACE_ENCHANT = "replaceEnchant",
    TRADE_REPLACE_ENCHANT = "replaceEnchant",
    CONFIRM_ACCEPT_SOCKETS = "replaceSockets",
    CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL = "merchantTradeTimers",
    CONFIRM_PURCHASE_TOKEN_ITEM = "tokenPurchases",
    CONFIRM_HIGH_COST_ITEM = "highCostPurchases",
}

local TYPED_DELETE_OPTIONS = {
    DELETE_ITEM = "deleteItems",
    DELETE_QUEST_ITEM = "deleteItems",
    DELETE_GOOD_ITEM = "deleteGoodItems",
    DELETE_GOOD_QUEST_ITEM = "deleteGoodItems",
}

local function GetDB()
    if not ns.db then return nil end
    ns.db.autoConfirm = ns.db.autoConfirm or {}
    return ns.db.autoConfirm
end

local function IsOptionEnabled(key)
    local db = GetDB()
    return db and db.enabled == true and db[key] == true
end

local function GetPopupButton(popup, index)
    if not popup then return nil end
    if popup.GetButton then
        local button = popup:GetButton(index)
        if button then return button end
    end
    if popup.Buttons and popup.Buttons[index] then
        return popup.Buttons[index]
    end
    if popup["button" .. tostring(index)] then
        return popup["button" .. tostring(index)]
    end
    local name = popup.GetName and popup:GetName()
    return name and _G[name .. "Button" .. tostring(index)] or nil
end

local function GetPopupEditBox(popup)
    if not popup then return nil end
    if popup.GetEditBox then
        local editBox = popup:GetEditBox()
        if editBox then return editBox end
    end
    return popup.EditBox or popup.editBox or (popup.GetName and _G[popup:GetName() .. "EditBox"])
end

local function FillDeleteText(popup)
    local editBox = GetPopupEditBox(popup)
    if not editBox then
        return true
    end

    local text = DELETE_ITEM_CONFIRM_STRING or DELETE or "DELETE"
    editBox:SetText(text)
    if editBox.ClearFocus then editBox:ClearFocus() end
    if editBox.SetAutoFocus then editBox:SetAutoFocus(false) end

    return true
end

local function ClickPrimaryButton(popup)
    local button = GetPopupButton(popup, 1)
    if not button or (button.IsEnabled and not button:IsEnabled()) then
        return false
    end

    button:Click()
    return true
end

local function ConfirmPopup(popup)
    if not popup or not popup:IsShown() then return end

    local which = popup.which
    if not which then return end

    local typedOption = TYPED_DELETE_OPTIONS[which]
    local buttonOption = BUTTON_ONLY_OPTIONS[which]

    if typedOption then
        if not IsOptionEnabled(typedOption) then return end
        FillDeleteText(popup)
    elseif buttonOption then
        if not IsOptionEnabled(buttonOption) then return end
    else
        return
    end

    if ClickPrimaryButton(popup) then
        return
    end

    if typedOption and C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if popup and popup:IsShown() and popup.which == which then
                ClickPrimaryButton(popup)
            end
        end)
    end
end

local function ScheduleConfirm(popup)
    if not popup or not popup.which then return end
    if pending[popup] == popup.which then return end

    pending[popup] = popup.which

    local function run()
        if pending[popup] ~= popup.which then
            return
        end
        pending[popup] = nil
        ConfirmPopup(popup)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, run)
    else
        run()
    end
end

function ns:GetAutoConfirmOption(key)
    local db = GetDB()
    return db and db[key] == true
end

function ns:SetAutoConfirmOption(key, value)
    local db = GetDB()
    if not db then return end
    db[key] = value == true
end

function ns:GetAutoConfirmHandledDialogs()
    return BUTTON_ONLY_OPTIONS, TYPED_DELETE_OPTIONS
end

function ns:InitializeAutoConfirm()
    if hooked then return end
    hooked = true

    for index = 1, 5 do
        local popup = _G["StaticPopup" .. index]
        if popup and popup.HookScript then
            popup:HookScript("OnShow", ScheduleConfirm)
            popup:HookScript("OnHide", function(self)
                pending[self] = nil
            end)
        end
    end
end
