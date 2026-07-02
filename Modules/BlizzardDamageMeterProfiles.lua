local _, ns = ...

local MAX_PROFILE_WINDOWS = 2
local DEFAULT_PROFILE_KEY = "profile1"
local DEFAULT_WINDOW_TYPE = "DamageDone"
local DEFAULT_SECOND_WINDOW_TYPE = "HealingDone"
local DEFAULT_SESSION_TYPE = "Overall"
local eventFrame

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

local function TryLoadBlizzardDamageMeter()
    if DamageMeter then
        return true
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        SafeCall(C_AddOns.LoadAddOn, "Blizzard_DamageMeter")
    elseif UIParentLoadAddOn then
        SafeCall(UIParentLoadAddOn, "Blizzard_DamageMeter")
    elseif LoadAddOn then
        SafeCall(LoadAddOn, "Blizzard_DamageMeter")
    end

    return DamageMeter ~= nil
end

local function IsBlizzardDamageMeterAvailable()
    TryLoadBlizzardDamageMeter()

    if not DamageMeter or not C_DamageMeter then
        return false, "Blizzard's built-in damage meter is not loaded by this client."
    end

    if C_DamageMeter.IsDamageMeterAvailable then
        local isAvailable, failureReason = SafeCall(C_DamageMeter.IsDamageMeterAvailable)

        if isAvailable == false then
            return false, failureReason or "Blizzard's built-in damage meter is not available."
        end
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

local function GetEnumValue(enumTable, name)
    if type(enumTable) ~= "table" or type(name) ~= "string" then
        return nil
    end

    return enumTable[name]
end

local function GetDefaultDamageMeterTypeName(index)
    if index == 2 then
        return DEFAULT_SECOND_WINDOW_TYPE
    end

    return DEFAULT_WINDOW_TYPE
end

local function WindowStateHasSavedData(state)
    return type(state) == "table"
        and (
            state.shown == true
            or state.geometry ~= nil
            or state.damageMeterType ~= nil
            or state.sessionType ~= nil
            or state.locked == true
            or state.nonInteractive == true
        )
end

local function CopyWindowStateWithDefaults(index, state)
    local copy = {}

    if type(state) == "table" then
        for key, value in pairs(state) do
            copy[key] = value
        end
    end

    copy.shown = copy.shown ~= false
    copy.damageMeterType = copy.damageMeterType or GetDefaultDamageMeterTypeName(index)
    copy.sessionType = copy.sessionType or DEFAULT_SESSION_TYPE

    return copy
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

local function CanSetUserPlaced(frame)
    if not frame or not frame.SetUserPlaced then
        return false
    end

    local isMovable = frame.IsMovable and SafeCall(frame.IsMovable, frame) == true
    local isResizable = frame.IsResizable and SafeCall(frame.IsResizable, frame) == true

    return isMovable or isResizable
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

    if CanSetUserPlaced(frame) then
        SafeCall(frame.SetUserPlaced, frame, false)
    end
end

local function GetDamageMeterWindow(index)
    if not TryLoadBlizzardDamageMeter() then
        return nil
    end

    if index == 1 then
        return DamageMeter and DamageMeter.GetSessionWindow and DamageMeter:GetSessionWindow(1)
    end

    return DamageMeter and DamageMeter.GetSessionWindow and DamageMeter:GetSessionWindow(index)
end

local function GetDamageMeterOwner()
    local primaryWindow = GetDamageMeterWindow(1)

    if primaryWindow and primaryWindow.GetDamageMeterOwner then
        return primaryWindow:GetDamageMeterOwner()
    end

    return DamageMeter
end

local function GetMaxDamageMeterWindowCount(owner)
    owner = owner or GetDamageMeterOwner()

    if owner and owner.GetMaxSessionWindowCount then
        return SafeCall(owner.GetMaxSessionWindowCount, owner) or MAX_PROFILE_WINDOWS
    end

    return MAX_PROFILE_WINDOWS
end

local function GetWindowDataList(owner)
    owner = owner or GetDamageMeterOwner()

    if owner and owner.GetWindowDataList then
        return SafeCall(owner.GetWindowDataList, owner)
    end

    return owner and owner.windowDataList or nil
end

local function GetStateTypeValue(index, state)
    local stateType = type(state) == "table" and state.damageMeterType or nil

    return GetEnumValue(Enum and Enum.DamageMeterType, stateType)
        or GetEnumValue(Enum and Enum.DamageMeterType, GetDefaultDamageMeterTypeName(index))
end

local function GetStateSessionTypeValue(state)
    local stateSession = type(state) == "table" and state.sessionType or nil

    return GetEnumValue(Enum and Enum.DamageMeterSessionType, stateSession)
        or GetEnumValue(Enum and Enum.DamageMeterSessionType, DEFAULT_SESSION_TYPE)
end

local function SeedBlizzardSavedWindowData(index, state)
    if index <= 1 then
        return
    end

    DamageMeterPerCharacterSettings = DamageMeterPerCharacterSettings or {}
    DamageMeterPerCharacterSettings.windowDataList = DamageMeterPerCharacterSettings.windowDataList or {}
    DamageMeterPerCharacterSettings.windowDataList[index] = DamageMeterPerCharacterSettings.windowDataList[index] or {}

    local savedWindowData = DamageMeterPerCharacterSettings.windowDataList[index]
    savedWindowData.damageMeterType = GetStateTypeValue(index, state)
    savedWindowData.sessionType = GetStateSessionTypeValue(state)
    savedWindowData.shown = true

    if type(state) == "table" then
        savedWindowData.locked = state.locked == true
        savedWindowData.nonInteractive = state.nonInteractive == true
    end
end

local function CreateDamageMeterWindowAtIndex(index, state)
    local owner = GetDamageMeterOwner()

    if not owner or not owner.SetupSessionWindow or index <= 1 or index > GetMaxDamageMeterWindowCount(owner) then
        return nil
    end

    local windowDataList = GetWindowDataList(owner)

    if type(windowDataList) ~= "table" then
        return nil
    end

    local windowData = windowDataList[index]

    if type(windowData) ~= "table" then
        windowData = owner.GetDefaultWindowData and SafeCall(owner.GetDefaultWindowData, owner) or {}
        windowDataList[index] = windowData
    end

    windowData.damageMeterType = GetStateTypeValue(index, state)
    windowData.sessionType = GetStateSessionTypeValue(state)
    windowData.locked = type(state) == "table" and state.locked == true or windowData.locked
    windowData.nonInteractive = type(state) == "table" and state.nonInteractive == true or windowData.nonInteractive

    SafeCall(owner.SetupSessionWindow, owner, windowData, index)

    return GetDamageMeterWindow(index)
end

local function EnsureDamageMeterWindow(index, state)
    local window = GetDamageMeterWindow(index)

    if window or not DamageMeter or index <= 1 then
        return window
    end

    local owner = GetDamageMeterOwner()
    local maxAttempts = GetMaxDamageMeterWindowCount(owner)

    SeedBlizzardSavedWindowData(index, state)

    if owner and owner.LoadSavedWindowDataList then
        SafeCall(owner.LoadSavedWindowDataList, owner)
        window = GetDamageMeterWindow(index)

        if window then
            return window
        end
    end

    for _ = 1, maxAttempts do
        if not owner or not owner.CanShowNewSessionWindow or SafeCall(owner.CanShowNewSessionWindow, owner) ~= true then
            break
        end

        SafeCall(owner.ShowNewSessionWindow, owner)
        window = GetDamageMeterWindow(index)

        if window then
            break
        end
    end

    return window or CreateDamageMeterWindowAtIndex(index, state)
end

local function SaveWindowState(index)
    local window = GetDamageMeterWindow(index)

    if not window then
        return {
            shown = false,
        }
    end

    local damageMeterType = window.GetDamageMeterType and window:GetDamageMeterType() or nil
    local sessionType = window.GetSessionType and window:GetSessionType() or nil

    return {
        shown = window:IsShown() == true,
        geometry = SaveFrameGeometry(index == 1 and DamageMeter or window),
        damageMeterType = GetEnumName(Enum and Enum.DamageMeterType, damageMeterType),
        sessionType = GetEnumName(Enum and Enum.DamageMeterSessionType, sessionType or Enum.DamageMeterSessionType.Overall),
        locked = window.IsLocked and window:IsLocked() == true or false,
        nonInteractive = window.IsNonInteractive and window:IsNonInteractive() == true or false,
    }
end

local function ApplyWindowState(index, state)
    if type(state) ~= "table" then
        return
    end

    if index > 1 and not WindowStateHasSavedData(state) then
        return
    end

    state = CopyWindowStateWithDefaults(index, state)

    local window = EnsureDamageMeterWindow(index, state)

    if not window then
        return
    end

    local owner = window.GetDamageMeterOwner and window:GetDamageMeterOwner() or DamageMeter
    local damageMeterType = GetEnumValue(Enum and Enum.DamageMeterType, state.damageMeterType)
    local sessionType = GetEnumValue(Enum and Enum.DamageMeterSessionType, state.sessionType)

    if owner and owner.SetSessionWindowDamageMeterType and damageMeterType ~= nil then
        SafeCall(owner.SetSessionWindowDamageMeterType, owner, window, damageMeterType)
    end

    if owner and owner.SetSessionWindowSessionID and sessionType ~= nil then
        SafeCall(owner.SetSessionWindowSessionID, owner, window, sessionType, nil)
    end

    if owner and owner.SetSessionWindowLocked then
        SafeCall(owner.SetSessionWindowLocked, owner, window, state.locked == true)
    end

    if owner and owner.SetSessionWindowNonInteractive then
        SafeCall(owner.SetSessionWindowNonInteractive, owner, window, state.nonInteractive == true)
    end

    ApplyFrameGeometry(index == 1 and DamageMeter or window, state.geometry)

    if state.shown == false and index > 1 and owner and owner.HideSessionWindow then
        SafeCall(owner.HideSessionWindow, owner, window)
    elseif window.Show then
        window:Show()
    end
end

local function SaveSharedSettings()
    if not DamageMeter then
        return nil
    end

    return {
        style = GetEnumName(Enum and Enum.DamageMeterStyle, DamageMeter.GetStyle and DamageMeter:GetStyle()),
        numberDisplayType = GetEnumName(Enum and Enum.DamageMeterNumbers, DamageMeter.GetNumberDisplayType and DamageMeter:GetNumberDisplayType()),
        visibility = GetEnumName(Enum and Enum.DamageMeterVisibility, DamageMeter.visibility),
        barHeight = DamageMeter.GetBarHeight and DamageMeter:GetBarHeight() or nil,
        barSpacing = DamageMeter.GetBarSpacing and DamageMeter:GetBarSpacing() or nil,
        textSize = DamageMeter.GetTextSize and DamageMeter:GetTextSize() or nil,
        windowTransparency = DamageMeter.GetWindowTransparency and DamageMeter:GetWindowTransparency() or nil,
        backgroundTransparency = DamageMeter.GetBackgroundTransparency and DamageMeter:GetBackgroundTransparency() or nil,
        showBarIcons = DamageMeter.ShouldShowBarIcons and DamageMeter:ShouldShowBarIcons() == true or false,
        useClassColor = DamageMeter.ShouldUseClassColor and DamageMeter:ShouldUseClassColor() == true or false,
    }
end

local function ApplySharedSettings(settings)
    if not DamageMeter or type(settings) ~= "table" then
        return
    end

    local style = GetEnumValue(Enum and Enum.DamageMeterStyle, settings.style)
    local numberDisplayType = GetEnumValue(Enum and Enum.DamageMeterNumbers, settings.numberDisplayType)
    local visibility = GetEnumValue(Enum and Enum.DamageMeterVisibility, settings.visibility)

    if style ~= nil and DamageMeter.SetStyle then
        SafeCall(DamageMeter.SetStyle, DamageMeter, style)
    end

    if numberDisplayType ~= nil and DamageMeter.SetNumberDisplayType then
        SafeCall(DamageMeter.SetNumberDisplayType, DamageMeter, numberDisplayType)
    end

    if visibility ~= nil then
        DamageMeter.visibility = visibility

        if DamageMeter.UpdateShownState then
            SafeCall(DamageMeter.UpdateShownState, DamageMeter)
        end
    end

    if settings.barHeight and DamageMeter.SetBarHeight then
        SafeCall(DamageMeter.SetBarHeight, DamageMeter, settings.barHeight)
    end

    if settings.barSpacing and DamageMeter.SetBarSpacing then
        SafeCall(DamageMeter.SetBarSpacing, DamageMeter, settings.barSpacing)
    end

    if settings.textSize and DamageMeter.SetTextSize then
        SafeCall(DamageMeter.SetTextSize, DamageMeter, settings.textSize)
    end

    if settings.windowTransparency and DamageMeter.SetWindowTransparency then
        SafeCall(DamageMeter.SetWindowTransparency, DamageMeter, settings.windowTransparency)
    end

    if settings.backgroundTransparency and DamageMeter.SetBackgroundTransparency then
        SafeCall(DamageMeter.SetBackgroundTransparency, DamageMeter, settings.backgroundTransparency)
    end

    if settings.showBarIcons ~= nil and DamageMeter.SetShowBarIcons then
        SafeCall(DamageMeter.SetShowBarIcons, DamageMeter, settings.showBarIcons == true)
    end

    if settings.useClassColor ~= nil and DamageMeter.SetUseClassColor then
        SafeCall(DamageMeter.SetUseClassColor, DamageMeter, settings.useClassColor == true)
    end
end

local function SetDamageMeterEnabled(enabled)
    if SetCVar then
        SafeCall(SetCVar, "damageMeterEnabled", enabled and "1" or "0")
    end

    if DamageMeter and DamageMeter.UpdateShownState then
        SafeCall(DamageMeter.UpdateShownState, DamageMeter)
    end
end

local function HookDamageMeterWindows()
    if not DamageMeter or DamageMeter.ZTProfileHooked then
        return
    end

    DamageMeter.ZTProfileHooked = true

    if hooksecurefunc and DamageMeter.SetupSessionWindow then
        hooksecurefunc(DamageMeter, "SetupSessionWindow", function()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if ns.ApplyActiveDamageMeterProfile then
                        ns:ApplyActiveDamageMeterProfile(true)
                    end
                end)
            end
        end)
    end
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
        if profile.windows and profile.windows[index] and profile.windows[index].shown ~= false then
            windowCount = windowCount + 1
        end
    end

    return string.format("%d saved window%s. Shared across all characters.", windowCount, windowCount == 1 and "" or "s")
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
    TryLoadBlizzardDamageMeter()
    SetDamageMeterEnabled(value == true)
end

function ns:GetBlizzardDamageMeterEnabled()
    return GetCVarBool and GetCVarBool("damageMeterEnabled") == true
end

function ns:SaveDamageMeterProfile(key)
    local isAvailable, reason = IsBlizzardDamageMeterAvailable()

    if not isAvailable then
        return false, reason
    end

    local profile, resolvedKey = GetProfile(key)

    if not profile then
        return false, "Could not access the selected profile."
    end

    profile.sharedSettings = SaveSharedSettings()
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

function ns:ApplyDamageMeterProfile(key, silent)
    local isAvailable, reason = IsBlizzardDamageMeterAvailable()

    if not isAvailable then
        if not silent then
            ns:Print(reason)
        end

        return false, reason
    end

    local profile, resolvedKey = GetProfile(key)

    if not profile or not profile.windows or not profile.windows[1] then
        return false, "This profile does not have a saved layout yet."
    end

    SetDamageMeterEnabled(true)
    HookDamageMeterWindows()
    ApplySharedSettings(profile.sharedSettings)

    for index = 1, MAX_PROFILE_WINDOWS do
        ApplyWindowState(index, profile.windows[index])
    end

    local db = EnsureDB()

    if db then
        db.activeProfile = resolvedKey
    end

    if DamageMeter and DamageMeter.RefreshLayout then
        SafeCall(DamageMeter.RefreshLayout, DamageMeter)
    end

    return true
end

function ns:ApplyActiveDamageMeterProfile(silent)
    local db = EnsureDB()

    if not db then
        return false
    end

    local profile = GetProfile(db.activeProfile)

    if not profile or not profile.windows or not profile.windows[1] then
        return false
    end

    return ns:ApplyDamageMeterProfile(db.activeProfile, silent)
end

function ns:ShowSecondBlizzardDamageMeterWindow()
    local isAvailable, reason = IsBlizzardDamageMeterAvailable()

    if not isAvailable then
        return false, reason
    end

    SetDamageMeterEnabled(true)
    HookDamageMeterWindows()

    local profile = GetProfile()
    local state = profile and profile.windows and profile.windows[2]
    local stateToApply = WindowStateHasSavedData(state) and CopyWindowStateWithDefaults(2, state) or {
        shown = true,
        damageMeterType = DEFAULT_SECOND_WINDOW_TYPE,
        sessionType = DEFAULT_SESSION_TYPE,
    }

    stateToApply.shown = true

    local window = EnsureDamageMeterWindow(2, stateToApply)

    if window then
        ApplyWindowState(2, stateToApply)
        return true
    end

    return false, "Could not create the second Blizzard damage meter window."
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
        TYPE_LABELS[typeName] or typeName or "Unknown type",
        SESSION_LABELS[sessionName] or sessionName or "Saved session",
        window:IsShown() and "shown" or "hidden"
    )
end

function ns:InitializeBlizzardDamageMeterProfiles()
    EnsureDB()
    TryLoadBlizzardDamageMeter()
    HookDamageMeterWindows()

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("ADDON_LOADED")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:SetScript("OnEvent", function(_, event, addonName)
            if event == "ADDON_LOADED" and addonName ~= "Blizzard_DamageMeter" then
                return
            end

            TryLoadBlizzardDamageMeter()
            HookDamageMeterWindows()

            if C_Timer and C_Timer.After then
                C_Timer.After(0.5, function()
                    ns:ApplyActiveDamageMeterProfile(true)
                end)
            end
        end)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            ns:ApplyActiveDamageMeterProfile(true)
        end)
    end
end
