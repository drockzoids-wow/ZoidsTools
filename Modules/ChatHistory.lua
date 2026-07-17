local _, ns = ...

local initialized = false
local restored = false
local restoring = false
local CAPTURE_VERSION = 5
local RESTORE_HEADER = "ZoidsTools saved chat (most recent messages):"
local hookedFrames = setmetatable({}, { __mode = "k" })

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function GetDB()
    return ns.db and ns.db.chat
end

local function CharacterKey()
    local name, realm = UnitFullName and UnitFullName("player")
    name = name or (UnitName and UnitName("player")) or "Unknown"
    realm = realm or (GetRealmName and GetRealmName()) or "Unknown"
    return name .. "-" .. realm
end

local function GetStore(create)
    local db = GetDB()
    if not db then return nil end
    if create and type(db.historyByCharacter) ~= "table" then db.historyByCharacter = {} end
    local stores = db.historyByCharacter
    if type(stores) ~= "table" then return nil end

    local key = CharacterKey()
    if create and type(stores[key]) ~= "table" then stores[key] = { lines = {} } end
    local store = stores[key]
    if create and type(store.lines) ~= "table" then store.lines = {} end
    if type(store) == "table" and (tonumber(store.captureVersion) or 0) < 4 then
        -- Older versions listened to global channel events and could retain
        -- messages that were never rendered in the selected chat tab.
        if type(store.lines) == "table" then wipe(store.lines) end
    end
    if type(store) == "table" then store.captureVersion = CAPTURE_VERSION end
    return store
end

local function TrimHistory(lines)
    local db = GetDB()
    local limit = math.max(100, math.min(500, tonumber(db and db.historyLimit) or 250))
    local excess = #lines - limit
    if excess <= 0 then return end
    for index = 1, #lines - excess do lines[index] = lines[index + excess] end
    for index = #lines, #lines - excess + 1, -1 do lines[index] = nil end
end

local function GetSelectedVisibleFrame()
    local frame = DEFAULT_CHAT_FRAME
    if FCFDock_GetSelectedWindow and GENERAL_CHAT_DOCK then
        frame = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) or frame
    end
    return frame
end

local function FormatRestoredLine(message)
    message = tostring(message or "")
    -- Preserve hyperlink markup but make every visible text span gray so the
    -- restored session is unmistakable. Reapply gray after resets embedded in
    -- Blizzard links and replace saved color spans without touching |H data.
    message = message:gsub("|c%x%x%x%x%x%x%x%x", "|cff858b94")
    message = message:gsub("|r", "|r|cff858b94")
    return "|cff858b94" .. message .. "|r"
end

local function SaveRenderedLine(frame, message)
    -- Some Blizzard chat events now render protected strings. They may be
    -- displayed by Blizzard but cannot be compared, converted, or persisted
    -- by addon code without causing a secret-value/taint error.
    if IsSecretValue(message) then return end

    local db = GetDB()
    if restoring or not db or not db.enabled or not db.historyEnabled then return end
    if frame ~= GetSelectedVisibleFrame() then return end

    message = type(message) == "string" and message or tostring(message or "")
    if message == "" or message:find(RESTORE_HEADER, 1, true) then return end

    local store = GetStore(true)
    if not store then return end
    store.lines[#store.lines + 1] = message
    TrimHistory(store.lines)
    if ns.RefreshOpenChatCopy then ns:RefreshOpenChatCopy() end
end

local function HookChatFrames()
    for index = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
        local frame = _G["ChatFrame" .. index]
        if frame and not hookedFrames[frame] and hooksecurefunc and frame.AddMessage then
            hookedFrames[frame] = true
            hooksecurefunc(frame, "AddMessage", SaveRenderedLine)
        end
    end
end

function ns:GetSavedChatHistoryLines()
    local store = GetStore(false)
    local result = {}
    for index, line in ipairs(store and store.lines or {}) do result[index] = line end
    return result
end

function ns:ClearSavedChatHistory()
    local store = GetStore(true)
    if not store then return false end
    wipe(store.lines)
    if self.RefreshOpenChatCopy then self:RefreshOpenChatCopy() end
    return true
end

function ns:RefreshChatHistory()
    local store = GetStore(false)
    if store and type(store.lines) == "table" then TrimHistory(store.lines) end
end

local function RestoreHistory()
    if restored then return end
    restored = true
    local db = GetDB()
    if not db or not db.enabled or not db.historyEnabled or not db.historyRestore then return end

    local lines = ns:GetSavedChatHistoryLines()
    if #lines == 0 or not DEFAULT_CHAT_FRAME then return end
    restoring = true
    DEFAULT_CHAT_FRAME:AddMessage("|cffb89232" .. RESTORE_HEADER .. "|r")
    local first = math.max(1, #lines - 49)
    for index = first, #lines do
        DEFAULT_CHAT_FRAME:AddMessage(FormatRestoredLine(lines[index]))
    end
    restoring = false
end

function ns:InitializeChatHistory()
    if initialized then
        self:RefreshChatHistory()
        return
    end
    initialized = true

    HookChatFrames()

    local events = CreateFrame("Frame")
    events:RegisterEvent("UPDATE_CHAT_WINDOWS")
    events:SetScript("OnEvent", HookChatFrames)

    if hooksecurefunc and FCF_OpenNewWindow then
        hooksecurefunc("FCF_OpenNewWindow", function()
            if C_Timer and C_Timer.After then C_Timer.After(0, HookChatFrames) else HookChatFrames() end
        end)
    end

    if C_Timer and C_Timer.After then C_Timer.After(1, RestoreHistory) else RestoreHistory() end
end
