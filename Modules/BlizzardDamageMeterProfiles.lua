local _, ns = ...

local MAX_PROFILE_WINDOWS = 2
local RESET_BUTTON_MAX_WINDOWS = 3
local RESET_BUTTON_SIZE = 18
local DEFAULT_PROFILE_KEY = "profile1"
local AUTO_APPLY_DELAYS = { 0.4, 1.2, 2.5, 5.0 }
local SETTLE_APPLY_DELAYS = { 0.1, 0.6, 1.6, 3.0 }
local resetButtonTicker
local autoApplyEventFrame
local pendingAutoApply
local autoApplyGeneration = 0
local settleApplyGeneration = 0
local damageMeterHooksInstalled = false
local applyingProfileDepth = 0
local hookedDamageMeterFrames = {}
local PROFILE_OPTIONS = {
    { value = "profile1", text = "Profile 1" },
    { value = "profile2", text = "Profile 2" },
}

local TYPE_LABELS = {
    DamageDone = "Damage Done",
    Dps = "DPS",
    HealingDone = "Healing Done",
    Hps = "HPS",
    Absorbs = "Absorbs",
    Interrupts = "Interrupts",
    Dispels = "Dispels",
    DamageTaken = "Damage Taken",
    AvoidableDamageTaken = "Avoidable Damage",
    Deaths = "Deaths",
    EnemyDamageTaken = "Enemy Damage Taken",
}

local SESSION_LABELS = {
    Overall = "Overall",
    Current = "Current",
    Expired = "Expired",
}

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result = pcall(func, ...)

    if ok then
        return result
    end

    return nil
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.damageMeterProfiles = ns.db.damageMeterProfiles or {}

    local db = ns.db.damageMeterProfiles

    db.activeProfile = db.activeProfile or DEFAULT_PROFILE_KEY
    db.lastAppliedProfile = db.lastAppliedProfile or db.activeProfile or DEFAULT_PROFILE_KEY
    db.profiles = db.profiles or {}

    for _, option in ipairs(PROFILE_OPTIONS) do
        db.profiles[option.value] = db.profiles[option.value] or {
            name = option.text,
            windows = {},
        }
        db.profiles[option.value].name = db.profiles[option.value].name or option.text
        db.profiles[option.value].windows = db.profiles[option.value].windows or {}
    end

    return db
end

local function GetProfile(key)
    local db = EnsureDB()

    if not db then
        return nil
    end

    key = key or db.activeProfile or DEFAULT_PROFILE_KEY

    if not db.profiles[key] then
        db.profiles[key] = { name = key, windows = {} }
    end

    db.profiles[key].windows = db.profiles[key].windows or {}

    return db.profiles[key], key
end

local function ProfileHasSavedLayout(profile)
    return type(profile) == "table"
        and type(profile.windows) == "table"
        and type(profile.windows[1]) == "table"
        and type(profile.windows[1].geometry) == "table"
end

local function GetLastAppliedProfileKey()
    local db = EnsureDB()

    if not db then
        return DEFAULT_PROFILE_KEY
    end

    return db.lastAppliedProfile or db.activeProfile or DEFAULT_PROFILE_KEY
end

local function BumpAutoApplyGeneration()
    autoApplyGeneration = autoApplyGeneration + 1
    return autoApplyGeneration
end

local function TryLoadBlizzardDamageMeter()
    return DamageMeter ~= nil
end

local function IsBlizzardDamageMeterAvailable()
    if not TryLoadBlizzardDamageMeter() then
        return false, "Open Blizzard's damage meter first, then save or apply positions."
    end

    return true
end

local function GetEnumName(enumTable, value)
    if type(enumTable) ~= "table" or value == nil then
        return nil
    end

    for name, enumValue in pairs(enumTable) do
        if enumValue == value then
            return name
        end
    end

    return nil
end

local function SaveFrameGeometry(frame)
    if not frame then
        return nil
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)

    return {
        point = point,
        relativeTo = relativeTo and relativeTo.GetName and relativeTo:GetName() or nil,
        relativePoint = relativePoint,
        x = x or 0,
        y = y or 0,
        width = frame:GetWidth(),
        height = frame:GetHeight(),
    }
end

local function ApplyFrameGeometry(frame, geometry)
    if not frame or type(geometry) ~= "table" then
        return
    end

    frame:ClearAllPoints()

    local relativeTo = UIParent

    if geometry.relativeTo and _G[geometry.relativeTo] then
        relativeTo = _G[geometry.relativeTo]
    end

    frame:SetPoint(geometry.point or "CENTER", relativeTo, geometry.relativePoint or geometry.point or "CENTER", geometry.x or 0, geometry.y or 0)

    if geometry.width and geometry.height and frame.SetSize then
        frame:SetSize(geometry.width, geometry.height)
    end
end

local function PersistSecondaryWindowPosition(frame)
    if not frame or not frame.SetUserPlaced then
        return
    end

    local isMovable = frame.IsMovable and SafeCall(frame.IsMovable, frame) == true
    local isResizable = frame.IsResizable and SafeCall(frame.IsResizable, frame) == true

    if not isMovable and not isResizable then
        return
    end

    SafeCall(frame.SetUserPlaced, frame, true)
end

local function GetDamageMeterWindow(index)
    if not TryLoadBlizzardDamageMeter() then
        return nil
    end

    return DamageMeter and DamageMeter.GetSessionWindow and DamageMeter:GetSessionWindow(index)
end

local function GetFrameForWindow(index, window)
    if index == 1 then
        return DamageMeter
    end

    return window
end

local function SaveWindowState(index)
    local window = GetDamageMeterWindow(index)

    if not window then
        return {
            shown = false,
        }
    end

    return {
        shown = window:IsShown() == true,
        geometry = SaveFrameGeometry(GetFrameForWindow(index, window)),
    }
end

local function ApplyWindowState(index, state)
    if type(state) ~= "table" or type(state.geometry) ~= "table" then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local window = GetDamageMeterWindow(index)

    if not window then
        return
    end

    local frame = GetFrameForWindow(index, window)

    ApplyFrameGeometry(frame, state.geometry)

    if index > 1 then
        PersistSecondaryWindowPosition(frame)
    end
end

local function ResetBlizzardDamageMeterData()
    if InCombatLockdown and InCombatLockdown() then
        ns:Print("Damage meter data can be reset after combat.")
        return
    end

    if not C_DamageMeter or not C_DamageMeter.ResetAllCombatSessions then
        ns:Print("Blizzard damage meter reset is not available.")
        return
    end

    if not securecallfunction then
        ns:Print("Blizzard damage meter reset is not available.")
        return
    end

    securecallfunction(C_DamageMeter.ResetAllCombatSessions)
end

local function SetResetButtonTooltip(button)
    if not GameTooltip then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText("Reset Meter Data")
    GameTooltip:AddLine("Clears Blizzard's damage meter sessions.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Available outside combat.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

local function PositionResetButton(window, button)
    if not window or not button then
        return
    end

    button:ClearAllPoints()

    local sessionDropdown = window.SessionDropdown

    if sessionDropdown then
        button:SetPoint("RIGHT", sessionDropdown, "LEFT", -6, 0)
    else
        button:SetPoint("TOPRIGHT", window, "TOPRIGHT", -78, -6)
    end
end

local function AttachResetButton(window)
    if not window or window.ZoidsToolsResetButton then
        return
    end

    local button = CreateFrame("Button", nil, window)
    button:SetSize(RESET_BUTTON_SIZE, RESET_BUTTON_SIZE)
    button:SetFrameLevel((window:GetFrameLevel() or 1) + 8)
    button:RegisterForClicks("LeftButtonUp")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(14, 14)

    if icon.SetAtlas then
        icon:SetAtlas("common-icon-undo")
    else
        icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    end

    button.icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetColorTexture(1, 0.82, 0, 0.18)
    highlight:SetAllPoints(button)

    button:SetScript("OnClick", ResetBlizzardDamageMeterData)
    button:SetScript("OnEnter", SetResetButtonTooltip)
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    window.ZoidsToolsResetButton = button
    PositionResetButton(window, button)
    button:Show()
end

local function AttachResetButtonsToDamageMeters()
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    for index = 1, RESET_BUTTON_MAX_WINDOWS do
        AttachResetButton(_G["DamageMeterSessionWindow" .. index])
    end
end

local function StartResetButtonWatcher()
    AttachResetButtonsToDamageMeters()

    if resetButtonTicker or not C_Timer or not C_Timer.NewTicker then
        return
    end

    resetButtonTicker = C_Timer.NewTicker(2, AttachResetButtonsToDamageMeters)
end

local function QueueDamageMeterProfileSettleApply(profileKey)
    if not profileKey or not C_Timer or not C_Timer.After then
        return
    end

    settleApplyGeneration = settleApplyGeneration + 1
    local generation = settleApplyGeneration

    for _, delay in ipairs(SETTLE_APPLY_DELAYS) do
        C_Timer.After(delay, function()
            if generation ~= settleApplyGeneration then
                return
            end

            if GetLastAppliedProfileKey() ~= profileKey then
                return
            end

            if ns.ApplyDamageMeterProfile then
                ns:ApplyDamageMeterProfile(profileKey, true, {
                    keepAutoApplyGeneration = true,
                    skipSettleApply = true,
                })
            end
        end)
    end
end

local function TryAutoApplyLastProfile(generation)
    if generation and generation ~= autoApplyGeneration then
        return false
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingAutoApply = true
        return false
    end

    if not TryLoadBlizzardDamageMeter() then
        pendingAutoApply = true
        return false
    end

    local ok = ns.ApplyLastDamageMeterProfile and ns:ApplyLastDamageMeterProfile(true, {
        keepAutoApplyGeneration = true,
    })

    if ok then
        pendingAutoApply = nil
    end

    return ok
end

local function QueueDamageMeterProfileAutoApply()
    pendingAutoApply = true
    local generation = BumpAutoApplyGeneration()

    if not C_Timer or not C_Timer.After then
        TryAutoApplyLastProfile(generation)
        return
    end

    for _, delay in ipairs(AUTO_APPLY_DELAYS) do
        C_Timer.After(delay, function()
            TryAutoApplyLastProfile(generation)
        end)
    end
end

local function IsEditModeActive()
    if DamageMeter and DamageMeter.IsEditing and SafeCall(DamageMeter.IsEditing, DamageMeter) == true then
        return true
    end

    if EditModeManagerFrame and EditModeManagerFrame.IsShown and SafeCall(EditModeManagerFrame.IsShown, EditModeManagerFrame) == true then
        return true
    end

    return false
end

local function QueueAfterBlizzardDamageMeterMove()
    if applyingProfileDepth > 0 or IsEditModeActive() then
        return
    end

    QueueDamageMeterProfileAutoApply()
end

local function InstallDamageMeterFrameHooks(frame)
    if not frame or hookedDamageMeterFrames[frame] or not hooksecurefunc then
        return
    end

    SafeCall(hooksecurefunc, frame, "ClearAllPoints", QueueAfterBlizzardDamageMeterMove)
    SafeCall(hooksecurefunc, frame, "SetPoint", QueueAfterBlizzardDamageMeterMove)
    SafeCall(hooksecurefunc, frame, "SetSize", QueueAfterBlizzardDamageMeterMove)

    hookedDamageMeterFrames[frame] = true
end

local function InstallDamageMeterHooks()
    if damageMeterHooksInstalled or not TryLoadBlizzardDamageMeter() or not hooksecurefunc then
        return
    end

    local function QueueAfterBlizzardLayout()
        if applyingProfileDepth > 0 or IsEditModeActive() then
            return
        end

        QueueDamageMeterProfileAutoApply()
    end

    InstallDamageMeterFrameHooks(DamageMeter)
    SafeCall(hooksecurefunc, DamageMeter, "SetupSessionWindow", QueueAfterBlizzardLayout)
    SafeCall(hooksecurefunc, DamageMeter, "RefreshLayout", QueueAfterBlizzardLayout)
    SafeCall(hooksecurefunc, DamageMeter, "UpdateShownState", QueueAfterBlizzardLayout)

    damageMeterHooksInstalled = true
end

local function StartProfileAutoApplyWatcher()
    InstallDamageMeterHooks()
    QueueDamageMeterProfileAutoApply()

    if autoApplyEventFrame then
        return
    end

    autoApplyEventFrame = CreateFrame("Frame")
    SafeCall(autoApplyEventFrame.RegisterEvent, autoApplyEventFrame, "ADDON_LOADED")
    SafeCall(autoApplyEventFrame.RegisterEvent, autoApplyEventFrame, "PLAYER_ENTERING_WORLD")
    SafeCall(autoApplyEventFrame.RegisterEvent, autoApplyEventFrame, "LOADING_SCREEN_DISABLED")
    SafeCall(autoApplyEventFrame.RegisterEvent, autoApplyEventFrame, "PLAYER_REGEN_ENABLED")
    autoApplyEventFrame:SetScript("OnEvent", function(_, event, addonName)
        if event == "ADDON_LOADED" then
            if addonName == "Blizzard_DamageMeter" then
                InstallDamageMeterHooks()
                QueueDamageMeterProfileAutoApply()
            end
        elseif event == "PLAYER_ENTERING_WORLD" or event == "LOADING_SCREEN_DISABLED" then
            InstallDamageMeterHooks()
            QueueDamageMeterProfileAutoApply()
        elseif event == "PLAYER_REGEN_ENABLED" and pendingAutoApply then
            QueueDamageMeterProfileAutoApply()
        end
    end)
end

function ns:GetDamageMeterProfileOptions()
    return PROFILE_OPTIONS
end

function ns:GetActiveDamageMeterProfileKey()
    local db = EnsureDB()

    return db and db.activeProfile or DEFAULT_PROFILE_KEY
end

function ns:SetActiveDamageMeterProfileKey(key)
    local db = EnsureDB()

    if not db or not db.profiles[key] then
        return
    end

    db.activeProfile = key
end

function ns:GetDamageMeterProfileName(key)
    local profile = GetProfile(key)

    return profile and profile.name or key or ""
end

function ns:GetDamageMeterProfileSummary(key)
    local profile = GetProfile(key)

    if not profile or not profile.savedAt then
        return "No saved layout yet."
    end

    local windowCount = 0

    for index = 1, MAX_PROFILE_WINDOWS do
        if profile.windows and profile.windows[index] and profile.windows[index].geometry then
            windowCount = windowCount + 1
        end
    end

    return string.format("%d saved window position%s. Shared across all characters.", windowCount, windowCount == 1 and "" or "s")
end

function ns:GetBlizzardDamageMeterStatusText()
    local isAvailable, reason = IsBlizzardDamageMeterAvailable()

    if not isAvailable then
        return reason
    end

    local enabled = GetCVarBool and GetCVarBool("damageMeterEnabled") == true

    if enabled then
        return "Blizzard damage meter is available and enabled."
    end

    return "Blizzard damage meter is available but disabled."
end

function ns:SetBlizzardDamageMeterEnabled(value)
    if value == true then
        ns:Print("Enable Blizzard's damage meter from Blizzard's Options. ZoidsTools only saves positions.")
    end
end

function ns:GetBlizzardDamageMeterEnabled()
    return GetCVarBool and GetCVarBool("damageMeterEnabled") == true
end

function ns:SaveDamageMeterProfile(key)
    local isAvailable, reason = IsBlizzardDamageMeterAvailable()

    if not isAvailable then
        return false, reason
    end

    if InCombatLockdown and InCombatLockdown() then
        return false, "Damage meter profiles cannot be saved during combat."
    end

    local profile, resolvedKey = GetProfile(key)

    if not profile then
        return false, "Could not access the selected profile."
    end

    profile.sharedSettings = nil
    profile.windows = {}

    for index = 1, MAX_PROFILE_WINDOWS do
        profile.windows[index] = SaveWindowState(index)
    end

    profile.savedAt = time and time() or true

    local db = EnsureDB()

    if db then
        db.activeProfile = resolvedKey
    end

    return true
end

function ns:ApplyDamageMeterProfile(key, silent, options)
    options = options or {}

    if not options.keepAutoApplyGeneration then
        BumpAutoApplyGeneration()
    end

    local isAvailable, reason = IsBlizzardDamageMeterAvailable()

    if not isAvailable then
        if not silent then
            ns:Print(reason)
        end

        return false, reason
    end

    if InCombatLockdown and InCombatLockdown() then
        if not silent then
            ns:Print("Damage meter profiles cannot be applied during combat.")
        end

        return false, "Damage meter profiles cannot be applied during combat."
    end

    local profile, resolvedKey = GetProfile(key)

    if not ProfileHasSavedLayout(profile) then
        return false, "This profile does not have a saved layout yet."
    end

    applyingProfileDepth = applyingProfileDepth + 1

    for index = 1, MAX_PROFILE_WINDOWS do
        ApplyWindowState(index, profile.windows[index])
    end

    applyingProfileDepth = applyingProfileDepth - 1

    local db = EnsureDB()

    if db then
        db.activeProfile = resolvedKey
        db.lastAppliedProfile = resolvedKey
    end

    if not options.skipSettleApply then
        QueueDamageMeterProfileSettleApply(resolvedKey)
    end

    return true
end

function ns:ApplyActiveDamageMeterProfile(silent, options)
    local db = EnsureDB()

    if not db then
        return false
    end

    local profile = GetProfile(db.activeProfile)

    if not ProfileHasSavedLayout(profile) then
        return false
    end

    return ns:ApplyDamageMeterProfile(db.activeProfile, silent, options)
end

function ns:ApplyLastDamageMeterProfile(silent, options)
    local key = GetLastAppliedProfileKey()
    local profile = GetProfile(key)

    if not ProfileHasSavedLayout(profile) then
        return false
    end

    return ns:ApplyDamageMeterProfile(key, silent, options)
end

function ns:ShowSecondBlizzardDamageMeterWindow()
    return false, "Use Blizzard's damage meter cog menu to create the second window. ZoidsTools only saves positions."
end

function ns:GetBlizzardDamageMeterWindowSummary(index)
    local window = GetDamageMeterWindow(index)

    if not window then
        return "Window " .. tostring(index) .. ": not created."
    end

    local damageMeterType = window.GetDamageMeterType and window:GetDamageMeterType()
    local sessionType = window.GetSessionType and window:GetSessionType()
    local typeName = GetEnumName(Enum and Enum.DamageMeterType, damageMeterType)
    local sessionName = GetEnumName(Enum and Enum.DamageMeterSessionType, sessionType)

    return string.format(
        "Window %d: %s, %s, %s.",
        index,
        TYPE_LABELS[typeName] or typeName or "Blizzard type",
        SESSION_LABELS[sessionName] or sessionName or "Blizzard session",
        window:IsShown() and "shown" or "hidden"
    )
end

function ns:InitializeBlizzardDamageMeterProfiles()
    EnsureDB()
    StartResetButtonWatcher()
    StartProfileAutoApplyWatcher()
end
