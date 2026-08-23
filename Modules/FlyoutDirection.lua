local _, ns = ...

local DEFAULT_DIRECTION = "AUTO"
local INHERIT_DIRECTION = "INHERIT"

local validDirections = {
    AUTO = true,
    UP = true,
    DOWN = true,
    LEFT = true,
    RIGHT = true,
}

local directionOptions = {
    { value = "AUTO", text = "Blizzard automatic" },
    { value = "UP", text = "Up" },
    { value = "DOWN", text = "Down" },
    { value = "LEFT", text = "Left" },
    { value = "RIGHT", text = "Right" },
}

local overrideDirectionOptions = {
    { value = "INHERIT", text = "Use default" },
    { value = "AUTO", text = "Blizzard automatic" },
    { value = "UP", text = "Up" },
    { value = "DOWN", text = "Down" },
    { value = "LEFT", text = "Left" },
    { value = "RIGHT", text = "Right" },
}

local actionButtonPrefixes = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarLeftButton",
    "MultiBarRightButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button",
}

local eventFrame
local refreshQueued = false
local refreshAfterCombat = false
local originalDirections = setmetatable({}, { __mode = "k" })
local controlledButtons = setmetatable({}, { __mode = "k" })

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function NormalizeDirection(value, fallback)
    if type(value) == "string" then
        value = string.upper(value)
    end

    if validDirections[value] then
        return value
    end

    return fallback
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.combat = ns.db.combat or {}
    ns.db.combat.flyoutDirections = ns.db.combat.flyoutDirections or {}

    local db = ns.db.combat.flyoutDirections
    db.defaultDirection = NormalizeDirection(db.defaultDirection, DEFAULT_DIRECTION)

    local normalizedOverrides = {}

    if type(db.overrides) == "table" then
        for flyoutID, direction in pairs(db.overrides) do
            local numericID = tonumber(flyoutID)
            local normalizedDirection = NormalizeDirection(direction)

            if numericID and numericID > 0 and normalizedDirection then
                normalizedOverrides[tostring(math.floor(numericID))] = normalizedDirection
            end
        end
    end

    db.overrides = normalizedOverrides
    return db
end

local function GetDesiredDirection(db, flyoutID)
    local override = db.overrides[tostring(flyoutID)]
    local direction = override or db.defaultDirection

    if direction == DEFAULT_DIRECTION then
        return nil
    end

    return direction
end

local function SetButtonDirection(button, direction)
    if not button or not button.SetAttribute or IsCombatLocked() then
        return
    end

    local currentDirection = button:GetAttribute("flyoutDirection")

    if currentDirection == direction then
        return
    end

    if not controlledButtons[button] then
        originalDirections[button] = { value = currentDirection }
    end

    local ok = pcall(button.SetAttribute, button, "flyoutDirection", direction)

    if ok then
        controlledButtons[button] = true
    elseif not controlledButtons[button] then
        originalDirections[button] = nil
    end
end

local function RestoreButtonDirection(button)
    if not controlledButtons[button] or IsCombatLocked() then
        return
    end

    local original = originalDirections[button]
    local originalDirection = original and original.value or nil
    local ok = pcall(button.SetAttribute, button, "flyoutDirection", originalDirection)

    if ok then
        controlledButtons[button] = nil
        originalDirections[button] = nil
    end
end

local function GetButtonFlyoutID(button)
    if not button or not button.action or not GetActionInfo then
        return nil, false
    end

    local ok, actionType, actionID = pcall(GetActionInfo, button.action)

    if not ok or IsSecret(actionType) or IsSecret(actionID) then
        return nil, false
    end

    if actionType ~= "flyout" then
        return nil, true
    end

    actionID = tonumber(actionID)

    if not actionID or actionID <= 0 then
        return nil, true
    end

    return math.floor(actionID), true
end

local function ApplyDirections()
    refreshQueued = false

    if IsCombatLocked() then
        refreshAfterCombat = true
        return
    end

    refreshAfterCombat = false

    local db = EnsureDB()
    if not db then
        return
    end

    for _, prefix in ipairs(actionButtonPrefixes) do
        for index = 1, 12 do
            local button = _G[prefix .. index]

            if button then
                local flyoutID, resolved = GetButtonFlyoutID(button)

                if resolved then
                    local direction = flyoutID and GetDesiredDirection(db, flyoutID) or nil

                    if direction then
                        SetButtonDirection(button, direction)
                    else
                        RestoreButtonDirection(button)
                    end
                end
            end
        end
    end
end

local function QueueRefresh(delay)
    if IsCombatLocked() then
        refreshAfterCombat = true
        return
    end

    if refreshQueued then
        return
    end

    refreshQueued = true

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, ApplyDirections)
    else
        ApplyDirections()
    end
end

local function GetKnownFlyoutOptions()
    local options = {}

    if not GetNumFlyouts or not GetFlyoutID or not GetFlyoutInfo then
        return options
    end

    local ok, count = pcall(GetNumFlyouts)

    if not ok or IsSecret(count) then
        return options
    end

    count = tonumber(count) or 0

    for index = 1, count do
        local idOK, flyoutID = pcall(GetFlyoutID, index)

        if idOK and not IsSecret(flyoutID) then
            flyoutID = tonumber(flyoutID)

            if flyoutID and flyoutID > 0 then
                local infoOK, name, _, _, isKnown = pcall(GetFlyoutInfo, flyoutID)

                if infoOK and not IsSecret(name) and not IsSecret(isKnown) and isKnown == true then
                    options[#options + 1] = {
                        value = math.floor(flyoutID),
                        text = (type(name) == "string" and name ~= "") and name or ("Flyout " .. flyoutID),
                    }
                end
            end
        end
    end

    table.sort(options, function(left, right)
        local leftName = string.lower(left.text)
        local rightName = string.lower(right.text)

        if leftName == rightName then
            return left.value < right.value
        end

        return leftName < rightName
    end)

    local nameCounts = {}

    for _, option in ipairs(options) do
        nameCounts[option.text] = (nameCounts[option.text] or 0) + 1
    end

    for _, option in ipairs(options) do
        if nameCounts[option.text] > 1 then
            option.text = option.text .. " (" .. option.value .. ")"
        end
    end

    return options
end

function ns:GetSkillFlyoutDirectionOptions(includeInherit)
    return includeInherit and overrideDirectionOptions or directionOptions
end

function ns:GetSkillFlyoutDefaultDirection()
    local db = EnsureDB()
    return db and db.defaultDirection or DEFAULT_DIRECTION
end

function ns:SetSkillFlyoutDefaultDirection(direction)
    local db = EnsureDB()
    direction = NormalizeDirection(direction)

    if not db or not direction then
        return
    end

    db.defaultDirection = direction
    QueueRefresh()
end

function ns:GetKnownSkillFlyoutOptions()
    return GetKnownFlyoutOptions()
end

function ns:GetPreferredSkillFlyoutID()
    local db = EnsureDB()
    local options = GetKnownFlyoutOptions()

    if db then
        for _, option in ipairs(options) do
            if db.overrides[tostring(option.value)] ~= nil then
                return option.value
            end
        end
    end

    return options[1] and options[1].value or nil
end

function ns:GetSkillFlyoutOverrideDirection(flyoutID)
    local db = EnsureDB()
    flyoutID = tonumber(flyoutID)

    if not db or not flyoutID then
        return INHERIT_DIRECTION
    end

    return db.overrides[tostring(math.floor(flyoutID))] or INHERIT_DIRECTION
end

function ns:SetSkillFlyoutOverrideDirections(flyoutIDs, direction)
    local db = EnsureDB()

    if not db or type(flyoutIDs) ~= "table" then
        return 0
    end

    local overrideDirection
    if direction ~= INHERIT_DIRECTION then
        direction = NormalizeDirection(direction)

        if not direction then
            return 0
        end
        overrideDirection = direction
    end

    local changed = 0

    for _, flyoutID in ipairs(flyoutIDs) do
        flyoutID = tonumber(flyoutID)

        if flyoutID and flyoutID > 0 then
            local key = tostring(math.floor(flyoutID))

            if db.overrides[key] ~= overrideDirection then
                db.overrides[key] = overrideDirection
                changed = changed + 1
            end
        end
    end

    if changed > 0 then
        QueueRefresh()
    end
    return changed
end

function ns:SetSkillFlyoutOverrideDirection(flyoutID, direction)
    return self:SetSkillFlyoutOverrideDirections({ flyoutID }, direction)
end

function ns:RefreshSkillFlyoutDirections()
    QueueRefresh()
end

function ns:InitializeFlyoutDirections()
    EnsureDB()

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
        eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
        eventFrame:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
        eventFrame:RegisterEvent("SPELLS_CHANGED")
        eventFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_ENABLED" and not refreshAfterCombat then
                return
            end

            QueueRefresh(0.05)
        end)
    end

    QueueRefresh()
end
