local _, ns = ...

local ACTION_BUTTON_USE_KEY_DOWN = "ActionButtonUseKeyDown"

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

local function GetCurrentKeyDownSetting()
    return IsTruthyCVar(GetCVarValue(ACTION_BUTTON_USE_KEY_DOWN))
end

local function EnsureCombatDB()
    if not ns.db then
        return nil
    end

    ns.db.combat = ns.db.combat or {}

    if ns.db.combat.castOnKeyDown == nil then
        ns.db.combat.castOnKeyDown = GetCurrentKeyDownSetting()
    end

    return ns.db.combat
end

function ns:ApplyCombatSettings()
    local db = EnsureCombatDB()

    if not db then
        return false
    end

    if GetCurrentKeyDownSetting() == (db.castOnKeyDown == true) then
        return true
    end

    return SetCVarValue(ACTION_BUTTON_USE_KEY_DOWN, db.castOnKeyDown and "1" or "0")
end

function ns:SetCastOnKeyDown(value)
    local db = EnsureCombatDB()

    if not db then
        return false
    end

    db.castOnKeyDown = value == true

    return self:ApplyCombatSettings()
end

function ns:GetCastOnKeyDown()
    local db = EnsureCombatDB()

    if db and db.castOnKeyDown ~= nil then
        return db.castOnKeyDown == true
    end

    return GetCurrentKeyDownSetting()
end

function ns:GetCurrentCastOnKeyDownCVar()
    return GetCurrentKeyDownSetting()
end

function ns:InitializeCombatSettings()
    self:ApplyCombatSettings()
end
