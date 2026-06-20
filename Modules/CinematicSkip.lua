local _, ns = ...

local initialized = false
local hooksInstalled = false
local skipQueued = false

local CINEMATIC_POPUPS = {
    CANCEL_CINEMATIC = true,
    CINEMATIC_CONFIRMATION = true,
    CONFIRM_CANCEL_CINEMATIC = true,
    MOVIE_CONFIRM = true,
    MOVIE_CONFIRMATION = true,
    SKIP_CINEMATIC = true,
}

local function EnsureCinematicDB()
    if not ns.db then
        return nil
    end

    ns.db.cinematics = ns.db.cinematics or {}

    if ns.db.cinematics.fastSkip == nil then
        ns.db.cinematics.fastSkip = false
    end

    if ns.db.cinematics.autoSkip == nil then
        ns.db.cinematics.autoSkip = false
    end

    return ns.db.cinematics
end

local function IsFastSkipEnabled()
    local db = EnsureCinematicDB()
    return db and db.fastSkip == true
end

local function IsAutoSkipEnabled()
    local db = EnsureCinematicDB()
    return db and db.autoSkip == true
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return false
    end

    local ok = pcall(func, ...)
    return ok == true
end

local function HideCinematicPopups()
    if type(StaticPopup_Hide) ~= "function" then
        return
    end

    for popupName in pairs(CINEMATIC_POPUPS) do
        StaticPopup_Hide(popupName)
    end
end

local function StopMovieFrame()
    if not MovieFrame then
        return
    end

    if MovieFrame.StopMovie then
        SafeCall(MovieFrame.StopMovie, MovieFrame)
    end

    if MovieFrame.Hide then
        SafeCall(MovieFrame.Hide, MovieFrame)
    end
end

local function SkipActiveCinematic()
    HideCinematicPopups()
    StopMovieFrame()

    SafeCall(CinematicFrame_CancelCinematic)
    SafeCall(StopCinematic)

    HideCinematicPopups()
end

local function QueueSkip()
    if skipQueued then
        return
    end

    skipQueued = true

    local function Run()
        skipQueued = false
        SkipActiveCinematic()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, Run)
    else
        Run()
    end
end

local function HookFrame(frame)
    if not frame or frame.ZoidsToolsCinematicSkipHooked then
        return
    end

    frame.ZoidsToolsCinematicSkipHooked = true

    if frame.HookScript then
        frame:HookScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" and IsFastSkipEnabled() then
                QueueSkip()
            end
        end)

        frame:HookScript("OnShow", function()
            if IsAutoSkipEnabled() then
                QueueSkip()
            end
        end)
    end
end

local function InstallHooks()
    HookFrame(_G.CinematicFrame)
    HookFrame(_G.MovieFrame)

    if hooksInstalled then
        return
    end

    hooksInstalled = true

    if type(StaticPopup_Show) == "function" and type(hooksecurefunc) == "function" then
        hooksecurefunc("StaticPopup_Show", function(which)
            if CINEMATIC_POPUPS[which] and IsFastSkipEnabled() then
                QueueSkip()
            end
        end)
    end
end

function ns:SetCinematicFastSkipEnabled(value)
    local db = EnsureCinematicDB()

    if not db then
        return
    end

    db.fastSkip = value == true
    InstallHooks()
end

function ns:IsCinematicFastSkipEnabled()
    return IsFastSkipEnabled()
end

function ns:SetCinematicAutoSkipEnabled(value)
    local db = EnsureCinematicDB()

    if not db then
        return
    end

    db.autoSkip = value == true

    InstallHooks()
end

function ns:IsCinematicAutoSkipEnabled()
    return IsAutoSkipEnabled()
end

function ns:InitializeCinematicSkip()
    EnsureCinematicDB()
    InstallHooks()

    if initialized then
        return
    end

    initialized = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CINEMATIC_START")
    frame:RegisterEvent("PLAY_MOVIE")
    frame:SetScript("OnEvent", function()
        InstallHooks()

        if IsAutoSkipEnabled() then
            QueueSkip()
        end
    end)
end
