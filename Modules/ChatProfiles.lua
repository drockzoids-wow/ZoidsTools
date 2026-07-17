local _, ns = ...

local initialized = false
local INTERACTIVITY_FIX_VERSION = 4

local function GetWindowInfo(index)
    if GetChatWindowInfo then return GetChatWindowInfo(index) end
    if FCF_GetChatWindowInfo then return FCF_GetChatWindowInfo(index) end
end

local function GetDB()
    local chat = ns.db and ns.db.chat
    if not chat then return nil end
    if type(chat.layoutProfiles) ~= "table" then
        chat.layoutProfiles = { profiles = {}, nextProfileID = 1, selected = nil }
    end
    local db = chat.layoutProfiles
    if type(db.profiles) ~= "table" then db.profiles = {} end
    db.nextProfileID = math.max(1, tonumber(db.nextProfileID) or 1)
    return db
end

local function CopyList(...)
    local values = { ... }
    if type(values[1]) == "table" then values = values[1] end
    local result = {}
    for _, value in ipairs(values) do
        if value ~= nil then result[#result + 1] = value end
    end
    return result
end

local function UniqueStrings(values)
    local result, seen = {}, {}
    for _, value in ipairs(values or {}) do
        if type(value) == "string" and value ~= "" and not seen[value] then
            seen[value] = true
            result[#result + 1] = value
        end
    end
    return result
end

local function IsEnabledValue(value)
    return value == true or (type(value) == "number" and value ~= 0)
end

local function CaptureWindow(index)
    local frame = _G["ChatFrame" .. index]
    if not frame then return nil end

    local name, fontSize, red, green, blue, alpha, shown, locked, docked
    name, fontSize, red, green, blue, alpha, shown, locked, docked = GetWindowInfo(index)
    if index ~= 1 and (not name or name == "") then return nil end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    local messages = GetChatWindowMessages and CopyList(GetChatWindowMessages(index)) or {}
    local channels = GetChatWindowChannels and UniqueStrings(CopyList(GetChatWindowChannels(index))) or {}

    return {
        index = index,
        name = name or (index == 1 and GENERAL or ("Chat " .. index)),
        fontSize = tonumber(fontSize),
        color = { tonumber(red), tonumber(green), tonumber(blue), tonumber(alpha) },
        shown = IsEnabledValue(shown),
        locked = IsEnabledValue(locked),
        docked = IsEnabledValue(docked),
        dockOrder = tonumber(docked),
        point = point,
        relativePoint = relativePoint,
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
        width = frame:GetWidth(),
        height = frame:GetHeight(),
        messages = messages,
        channels = channels,
    }
end

local function CaptureLayout()
    local layout = { windows = {} }
    for index = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
        local window = CaptureWindow(index)
        if window then layout.windows[#layout.windows + 1] = window end
    end
    return layout
end

local function FindFrame(window)
    local frame = _G["ChatFrame" .. tostring(window.index or "")]
    local indexedName = window.index and GetWindowInfo(window.index)
    if frame and (window.index == 1 or (indexedName and indexedName ~= "")) then return frame, window.index end

    for index = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
        local candidate = _G["ChatFrame" .. index]
        local name = GetWindowInfo(index)
        if candidate and name == window.name then return candidate, index end
    end

    if FCF_OpenNewWindow then
        local created = FCF_OpenNewWindow(window.name)
        if type(created) == "table" then
            local index = tonumber((created:GetName() or ""):match("ChatFrame(%d+)$"))
            return created, index
        end
        for index = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
            local candidate = _G["ChatFrame" .. index]
            local name = GetWindowInfo(index)
            if candidate and name == window.name then return candidate, index end
        end
    end
end

local function ReplaceMessages(index, saved)
    if not index or not GetChatWindowMessages then return end
    local current = CopyList(GetChatWindowMessages(index))
    for _, group in ipairs(current) do
        if RemoveChatWindowMessages then pcall(RemoveChatWindowMessages, index, group) end
    end
    for _, group in ipairs(saved or {}) do
        if AddChatWindowMessages then pcall(AddChatWindowMessages, index, group) end
    end
end

local function ReplaceChannels(index, saved)
    if not index or not GetChatWindowChannels then return end
    local current = UniqueStrings(CopyList(GetChatWindowChannels(index)))
    for _, channel in ipairs(current) do
        if RemoveChatWindowChannel then pcall(RemoveChatWindowChannel, index, channel) end
    end
    for _, channel in ipairs(saved or {}) do
        if AddChatWindowChannel then pcall(AddChatWindowChannel, index, channel) end
    end
end

local function ApplyWindow(window)
    local frame, index = FindFrame(window)
    if not frame or not index then return false end

    if SetChatWindowName and window.name then
        pcall(SetChatWindowName, index, window.name)
    elseif FCF_SetWindowName and window.name then
        pcall(FCF_SetWindowName, frame, window.name)
    end
    if SetChatWindowSize and window.fontSize then
        pcall(SetChatWindowSize, index, window.fontSize)
    elseif FCF_SetChatWindowFontSize and window.fontSize then
        pcall(FCF_SetChatWindowFontSize, nil, frame, window.fontSize)
    end
    if window.color then
        if FCF_SetWindowColor then
            pcall(FCF_SetWindowColor, frame, window.color[1] or 0, window.color[2] or 0, window.color[3] or 0)
        elseif SetChatWindowColor then
            pcall(SetChatWindowColor, index, window.color[1] or 0, window.color[2] or 0, window.color[3] or 0)
        end
        if FCF_SetWindowAlpha then
            pcall(FCF_SetWindowAlpha, frame, window.color[4] or 0)
        elseif SetChatWindowAlpha then
            pcall(SetChatWindowAlpha, index, window.color[4] or 0)
        end
    end
    ReplaceMessages(index, window.messages)
    ReplaceChannels(index, window.channels)

    if window.docked and FCF_DockFrame then
        pcall(FCF_DockFrame, frame, window.dockOrder or index, true)
    elseif not window.docked and FCF_UnDockFrame then
        pcall(FCF_UnDockFrame, frame)
    end
    if SetChatWindowDocked then pcall(SetChatWindowDocked, index, window.docked == true) end
    if SetChatWindowLocked then
        pcall(SetChatWindowLocked, index, window.locked == true)
    elseif FCF_SetLocked then
        pcall(FCF_SetLocked, frame, window.locked == true)
    end
    if not window.docked then
        frame:ClearAllPoints()
        frame:SetPoint(window.point or "BOTTOMLEFT", UIParent, window.relativePoint or "BOTTOMLEFT", window.x or 0, window.y or 0)
        if window.width and window.height then frame:SetSize(window.width, window.height) end
    end
    if SetChatWindowShown then pcall(SetChatWindowShown, index, window.shown == true) end
    if window.shown then frame:Show() elseif index ~= 1 then frame:Hide() end
    if FCF_SavePositionAndDimensions then pcall(FCF_SavePositionAndDimensions, frame) end
    return true
end

function ns:GetChatLayoutProfileOptions()
    local db = GetDB()
    local options = {}
    for key, profile in pairs(db and db.profiles or {}) do
        options[#options + 1] = { value = key, text = profile.name or key }
    end
    table.sort(options, function(a, b) return a.text:lower() < b.text:lower() end)
    return options
end

function ns:GetSelectedChatLayoutProfile()
    local db = GetDB()
    return db and db.selected
end

function ns:SetSelectedChatLayoutProfile(key)
    local db = GetDB()
    if not db or not db.profiles[key] then return false end
    db.selected = key
    return true
end

function ns:GetChatLayoutProfileName(key)
    local db = GetDB()
    return db and db.profiles[key] and db.profiles[key].name
end

function ns:CreateChatLayoutProfile(name)
    local db = GetDB()
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if not db or name == "" then return false, "Enter a profile name." end
    for _, profile in pairs(db.profiles) do
        if (profile.name or ""):lower() == name:lower() then return false, "A chat layout with that name already exists." end
    end

    local key = "profile" .. db.nextProfileID
    db.nextProfileID = db.nextProfileID + 1
    db.profiles[key] = { name = name, layout = CaptureLayout() }
    db.selected = key
    return true
end

function ns:SaveChatLayoutProfile(key)
    local db = GetDB()
    local profile = db and db.profiles[key]
    if not profile then return false, "Select a chat layout first." end
    profile.layout = CaptureLayout()
    return true
end

function ns:ApplyChatLayoutProfile(key)
    if InCombatLockdown and InCombatLockdown() then return false, "Chat layouts cannot be applied during combat." end
    local db = GetDB()
    local profile = db and db.profiles[key]
    if not profile then return false, "Select a chat layout first." end

    local applied = 0
    for _, window in ipairs(profile.layout and profile.layout.windows or {}) do
        if ApplyWindow(window) then applied = applied + 1 end
    end
    if applied == 0 then return false, "No saved chat windows could be applied." end
    if ns.RefreshChatEnhancements then ns:RefreshChatEnhancements() end
    return true
end

function ns:DeleteChatLayoutProfile(key)
    local db = GetDB()
    if not db or not db.profiles[key] then return false, "Select a chat layout first." end
    db.profiles[key] = nil
    db.selected = next(db.profiles)
    return true
end

function ns:InitializeChatProfiles()
    if initialized then return end
    initialized = true
    local db = GetDB()

    -- Older profile versions captured Blizzard's click-through state. Layout
    -- profiles should never change whether chat links can be clicked, so remove
    -- that field and leave interactivity under Blizzard's control.
    if db and db.interactivityFixVersion ~= INTERACTIVITY_FIX_VERSION then
        for _, profile in pairs(db.profiles) do
            for _, window in ipairs(profile and profile.layout and profile.layout.windows or {}) do
                window.uninteractable = nil
            end
        end
        db.interactivityFixVersion = INTERACTIVITY_FIX_VERSION
    end
end
