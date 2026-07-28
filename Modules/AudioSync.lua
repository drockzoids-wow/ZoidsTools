local _, ns = ...

local eventFrame
local pendingSync = false
local lastSync = 0

local OUTPUT_DRIVER_INDEX_CVAR = "Sound_OutputDriverIndex"
local SYNC_EVENT = "VOICE_CHAT_OUTPUT_DEVICES_UPDATED"
local MIN_SYNC_INTERVAL = 2

local function EnsureDB()
    if not ns.db then return nil end
    ns.db.ui = ns.db.ui or {}
    ns.db.ui.audioSync = ns.db.ui.audioSync or {}
    local db = ns.db.ui.audioSync
    if db.enabled == nil then db.enabled = false end
    return db
end

local function SafeSetCVar(name, value)
    if C_CVar and type(C_CVar.SetCVar) == "function" then
        return pcall(C_CVar.SetCVar, name, value)
    elseif type(SetCVar) == "function" then
        return pcall(SetCVar, name, value)
    end

    return false
end

local function IsFrameShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function IsCinematicPlaying()
    return IsFrameShown(_G.CinematicFrame) or IsFrameShown(_G.MovieFrame)
end

local function ApplyAudioSync()
    local now = GetTime and GetTime() or 0
    if now > 0 and (now - lastSync) < MIN_SYNC_INTERVAL then
        return
    end

    lastSync = now
    SafeSetCVar(OUTPUT_DRIVER_INDEX_CVAR, "0")

    if not IsCinematicPlaying() and type(Sound_GameSystem_RestartSoundSystem) == "function" then
        pcall(Sound_GameSystem_RestartSoundSystem)
    end
end

local function ScheduleAudioSync(delay)
    if pendingSync then return end
    pendingSync = true

    local function Run()
        pendingSync = false
        local db = EnsureDB()
        if db and db.enabled then
            ApplyAudioSync()
        end
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delay or 0.2, Run)
    else
        Run()
    end
end

local function UpdateEventRegistration()
    if not eventFrame then return end
    eventFrame:UnregisterAllEvents()

    local db = EnsureDB()
    if db and db.enabled then
        pcall(eventFrame.RegisterEvent, eventFrame, SYNC_EVENT)
    end
end

function ns:IsAudioSyncEnabled()
    local db = EnsureDB()
    return db and db.enabled == true
end

function ns:SetAudioSyncEnabled(value)
    local db = EnsureDB()
    if not db then return end

    db.enabled = value == true
    UpdateEventRegistration()
end

function ns:SyncAudioDevice()
    ScheduleAudioSync(0)
end

function ns:InitializeAudioSync()
    EnsureDB()

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function()
            ScheduleAudioSync(0.2)
        end)
    end

    UpdateEventRegistration()
end
