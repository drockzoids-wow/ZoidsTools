local _, ns = ...

local MAX_PROFILE_WINDOWS = 2
local RESET_BUTTON_MAX_WINDOWS = 3
local RESET_BUTTON_SIZE = 18
local AUTO_APPLY_DELAYS = { 0.4, 1.2, 2.5, 5.0 }
local SETTLE_APPLY_DELAYS = { 0.1, 0.6, 1.6, 3.0 }
local resetButtonTicker
local resetButtonWatcherAttempts = 0
local RESET_BUTTON_WATCH_MAX_ATTEMPTS = 15
local autoApplyEventFrame
local pendingAutoApply
local autoApplyScheduled = false
local autoApplyGeneration = 0
local settleApplyGeneration = 0
local damageMeterHooksInstalled = false
local applyingProfileDepth = 0
local hookedDamageMeterFrames = {}

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

    db.profiles = db.profiles or {}

    if db.namedProfilesMigrated ~= true then
        for _, key in ipairs({ "profile1", "profile2" }) do
            local profile = db.profiles[key]
            local hasSavedLayout = type(profile) == "table"
                and profile.savedAt ~= nil
                and type(profile.windows) == "table"
                and type(profile.windows[1]) == "table"
                and type(profile.windows[1].geometry) == "table"

            if not hasSavedLayout then
                db.profiles[key] = nil
                if db.activeProfile == key then db.activeProfile = nil end
                if db.lastAppliedProfile == key then db.lastAppliedProfile = nil end
            end
        end
        db.namedProfilesMigrated = true
    end

    if db.activeProfile and not db.profiles[db.activeProfile] then
        db.activeProfile = nil
    end

    if db.lastAppliedProfile and not db.profiles[db.lastAppliedProfile] then
        db.lastAppliedProfile = nil
    end

    for key, profile in pairs(db.profiles) do
        if type(profile) ~= "table" then
            db.profiles[key] = nil
        else
            profile.name = type(profile.name) == "string" and profile.name or tostring(key)
            profile.windows = type(profile.windows) == "table" and profile.windows or {}
        end
    end

    db.nextProfileID = math.max(1, tonumber(db.nextProfileID) or 1)

    return db
end

local function GetProfile(key)
    local db = EnsureDB()

    if not db then
        return nil
    end

    key = key or db.activeProfile
    if not key or not db.profiles[key] then return nil end

    db.profiles[key].windows = db.profiles[key].windows or {}

    return db.profiles[key], key
end

local function ProfileHasSavedLayout(profile)
    if type(profile) ~= "table" then return false end

    if type(profile.customLayout) == "table"
        and type(profile.customLayout.windows) == "table"
        and type(profile.customLayout.windows[1]) == "table" then
        return true
    end

    if type(profile.windows) ~= "table" then return false end

    for index = 1, MAX_PROFILE_WINDOWS do
        if type(profile.windows[index]) == "table" and type(profile.windows[index].geometry) == "table" then
            return true
        end
    end

    return false
end

local function GetLastAppliedProfileKey()
    local db = EnsureDB()

    if not db then return nil end

    return db.lastAppliedProfile
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

    local window = DamageMeter and DamageMeter.GetSessionWindow and SafeCall(DamageMeter.GetSessionWindow, DamageMeter, index)
    if window then return window end

    window = _G["DamageMeterSessionWindow" .. tostring(index)]
    if window then return window end

    for _, collectionName in ipairs({ "sessionWindows", "SessionWindows", "windows", "Windows" }) do
        local collection = DamageMeter and DamageMeter[collectionName]
        if type(collection) == "table" and collection[index] then
            return collection[index]
        end
    end

    return nil
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

AttachResetButtonsToDamageMeters = ns:WrapDiagnosticFunction("DamageMeters.Watcher", AttachResetButtonsToDamageMeters)

local function StartResetButtonWatcher()
    AttachResetButtonsToDamageMeters()

    if resetButtonTicker or not C_Timer or not C_Timer.NewTicker then
        return
    end

    resetButtonWatcherAttempts = 0
    resetButtonTicker = C_Timer.NewTicker(2, function()
        resetButtonWatcherAttempts = resetButtonWatcherAttempts + 1
        AttachResetButtonsToDamageMeters()

        if resetButtonWatcherAttempts >= RESET_BUTTON_WATCH_MAX_ATTEMPTS then
            if resetButtonTicker and resetButtonTicker.Cancel then
                resetButtonTicker:Cancel()
            end
            resetButtonTicker = nil
        end
    end)
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
                    skipCustomLayout = true,
                })
            end
        end)
    end
end

local function TryAutoApplyLastProfile(generation)
    if generation and generation ~= autoApplyGeneration then
        return false
    end

    if not GetLastAppliedProfileKey() then
        pendingAutoApply = nil
        return false
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingAutoApply = true
        return false
    end

    local profile = GetProfile(GetLastAppliedProfileKey())
    local hasCustomLayout = profile and type(profile.customLayout) == "table"
    if not hasCustomLayout and not TryLoadBlizzardDamageMeter() then
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
    if not GetLastAppliedProfileKey() then
        pendingAutoApply = nil
        return
    end

    pendingAutoApply = true

    if InCombatLockdown and InCombatLockdown() then
        BumpAutoApplyGeneration()
        return
    end

    if autoApplyScheduled then
        return
    end

    autoApplyScheduled = true
    local generation = BumpAutoApplyGeneration()

    if not C_Timer or not C_Timer.After then
        autoApplyScheduled = false
        TryAutoApplyLastProfile(generation)
        return
    end

    local remaining = #AUTO_APPLY_DELAYS

    for _, delay in ipairs(AUTO_APPLY_DELAYS) do
        C_Timer.After(delay, function()
            TryAutoApplyLastProfile(generation)
            remaining = remaining - 1

            if remaining <= 0 then
                autoApplyScheduled = false
            end
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
    local db = EnsureDB()
    local options = {}

    if not db then return options end

    for key, profile in pairs(db.profiles) do
        options[#options + 1] = {
            value = key,
            text = profile.name,
            createdAt = tonumber(profile.createdAt) or 0,
        }
    end

    table.sort(options, function(left, right)
        local leftName = string.lower(left.text or "")
        local rightName = string.lower(right.text or "")
        if leftName == rightName then return left.createdAt < right.createdAt end
        return leftName < rightName
    end)

    return options
end

function ns:GetActiveDamageMeterProfileKey()
    local db = EnsureDB()

    return db and db.activeProfile or nil
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

local function NormalizeProfileName(name)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return nil end
    return name:sub(1, 40)
end

function ns:CreateDamageMeterProfile(name)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Damage meter profiles cannot be created during combat."
    end

    name = NormalizeProfileName(name)
    if not name then return false, "Enter a profile name first." end

    local db = EnsureDB()
    if not db then return false, "Could not access damage meter profiles." end

    for _, profile in pairs(db.profiles) do
        if string.lower(profile.name or "") == string.lower(name) then
            return false, "A damage meter profile with that name already exists."
        end
    end

    local key
    repeat
        key = "layout" .. tostring(db.nextProfileID)
        db.nextProfileID = db.nextProfileID + 1
    until not db.profiles[key]

    local previousActiveProfile = db.activeProfile
    db.profiles[key] = {
        name = name,
        windows = {},
        createdAt = time and time() or db.nextProfileID,
    }
    db.activeProfile = key

    local ok, message = ns:SaveDamageMeterProfile(key)
    if not ok then
        db.profiles[key] = nil
        db.activeProfile = previousActiveProfile
        return false, message
    end

    db.lastAppliedProfile = key
    return true, key
end

function ns:DeleteDamageMeterProfile(key)
    local db = EnsureDB()
    key = key or (db and db.activeProfile)
    if not db or not key or not db.profiles[key] then
        return false, "Select a profile to delete."
    end

    db.profiles[key] = nil
    if db.activeProfile == key then db.activeProfile = nil end
    if db.lastAppliedProfile == key then db.lastAppliedProfile = nil end
    BumpAutoApplyGeneration()
    pendingAutoApply = nil
    return true
end

function ns:GetDamageMeterProfileSummary(key)
    local profile = GetProfile(key)

    if not profile then
        return "No profile selected. Create one to save the current meter layout."
    end

    if not profile or not profile.savedAt then
        return "No saved layout yet."
    end

    local customWindowCount = 0
    local blizzardWindowCount = 0

    if profile.customLayout and profile.customLayout.windows then
        for index = 1, MAX_PROFILE_WINDOWS do
            if type(profile.customLayout.windows[index]) == "table"
                and profile.customLayout.windows[index].enabled ~= false then
                customWindowCount = customWindowCount + 1
            end
        end
    end

    for index = 1, MAX_PROFILE_WINDOWS do
        if profile.windows and profile.windows[index] and profile.windows[index].geometry then
            blizzardWindowCount = blizzardWindowCount + 1
        end
    end

    local parts = {}
    if customWindowCount > 0 then
        parts[#parts + 1] = string.format("%d ZoidsTools window%s", customWindowCount, customWindowCount == 1 and "" or "s")
    end
    if blizzardWindowCount > 0 then
        parts[#parts + 1] = string.format("%d Blizzard window%s", blizzardWindowCount, blizzardWindowCount == 1 and "" or "s")
    end

    return table.concat(parts, " and ") .. " saved. Shared across all characters."
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
    local enabled = value == true
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    if type(setter) ~= "function" then
        return false
    end

    local ok, result = pcall(setter, "damageMeterEnabled", enabled and "1" or "0")
    if not ok or result == false then return false end

    if DamageMeter and DamageMeter.UpdateShownState then
        SafeCall(DamageMeter.UpdateShownState, DamageMeter)
    end

    if enabled and ns.GetCustomDamageMeterEnabled and ns:GetCustomDamageMeterEnabled() and ns.SetCustomDamageMeterEnabled then
        ns:SetCustomDamageMeterEnabled(false)
    end

    return true
end

function ns:GetBlizzardDamageMeterEnabled()
    return GetCVarBool and GetCVarBool("damageMeterEnabled") == true
end

function ns:SaveDamageMeterProfile(key)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Damage meter profiles cannot be saved during combat."
    end

    local profile, resolvedKey = GetProfile(key)

    if not profile then
        return false, "Select or create a profile first."
    end

    local previousWindows = profile.windows
    local previousCustomLayout = profile.customLayout
    profile.sharedSettings = nil
    profile.windows = {}
    profile.customLayout = ns.CaptureCustomDamageMeterLayout and ns:CaptureCustomDamageMeterLayout() or nil

    if TryLoadBlizzardDamageMeter() then
        for index = 1, MAX_PROFILE_WINDOWS do
            profile.windows[index] = SaveWindowState(index)
        end
    end

    if not ProfileHasSavedLayout(profile) then
        profile.windows = previousWindows or {}
        profile.customLayout = previousCustomLayout
        return false, "No damage meter windows were found to save."
    end

    profile.savedAt = time and time() or true

    local db = EnsureDB()

    if db then
        db.activeProfile = resolvedKey
        db.lastAppliedProfile = resolvedKey
    end

    return true
end

function ns:ApplyDamageMeterProfile(key, silent, options)
    options = options or {}

    if not options.keepAutoApplyGeneration then
        BumpAutoApplyGeneration()
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

    local appliedCustomLayout = false
    if not options.skipCustomLayout and type(profile.customLayout) == "table" and ns.ApplyCustomDamageMeterLayout then
        appliedCustomLayout = ns:ApplyCustomDamageMeterLayout(profile.customLayout) == true
    end

    local appliedBlizzardLayout = false
    if TryLoadBlizzardDamageMeter() and type(profile.windows) == "table" then
        for index = 1, MAX_PROFILE_WINDOWS do
            if profile.windows[index] and profile.windows[index].geometry then
                ApplyWindowState(index, profile.windows[index])
                appliedBlizzardLayout = true
            end
        end
    end

    applyingProfileDepth = applyingProfileDepth - 1

    if not appliedCustomLayout and not appliedBlizzardLayout then
        return false, "The saved meter windows are not currently available."
    end

    local db = EnsureDB()

    if db then
        db.activeProfile = resolvedKey
        db.lastAppliedProfile = resolvedKey
    end

    if appliedBlizzardLayout and not options.skipSettleApply then
        QueueDamageMeterProfileSettleApply(resolvedKey)
    end

    return true
end

function ns:ApplyActiveDamageMeterProfile(silent, options)
    local db = EnsureDB()

    if not db then
        return false
    end

    if not db.activeProfile then return false end
    local profile = GetProfile(db.activeProfile)

    if not ProfileHasSavedLayout(profile) then
        return false
    end

    return ns:ApplyDamageMeterProfile(db.activeProfile, silent, options)
end

function ns:ApplyLastDamageMeterProfile(silent, options)
    local key = GetLastAppliedProfileKey()
    if not key then return false end
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
        return "Blizzard window " .. tostring(index) .. ": not created."
    end

    local damageMeterType = window.GetDamageMeterType and window:GetDamageMeterType()
    local sessionType = window.GetSessionType and window:GetSessionType()
    local typeName = GetEnumName(Enum and Enum.DamageMeterType, damageMeterType)
    local sessionName = GetEnumName(Enum and Enum.DamageMeterSessionType, sessionType)

    return string.format(
        "Blizzard window %d: %s, %s, %s.",
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
