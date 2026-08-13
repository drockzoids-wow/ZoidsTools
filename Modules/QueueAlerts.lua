local _, ns = ...

local PROPOSAL_DURATION = 40
local BACKGROUND_SOUND_CVAR = "Sound_EnableSoundWhenGameIsInBG"

local eventFrame
local countdownFrame
local deadline
local lastDisplayedSecond
local restoreBackgroundSound
local updateGeneration = 0

local function CanAccessFrame(frame)
    if not frame then return false end

    if type(frame.CanBeAccessedInContext) == "function" then
        local ok, canAccess = pcall(frame.CanBeAccessedInContext, frame)
        return ok and canAccess == true
    end

    return true
end

local function EnsureDB()
    if not ns.db then return nil end
    ns.db.queueAlerts = ns.db.queueAlerts or {}
    local db = ns.db.queueAlerts

    if db.backgroundSound == nil then db.backgroundSound = true end
    if db.countdown == nil then db.countdown = true end
    if db.safeQueue == nil then db.safeQueue = false end

    return db
end

local function GetCVarValue(name)
    if C_CVar and type(C_CVar.GetCVar) == "function" then
        local ok, value = pcall(C_CVar.GetCVar, name)
        if ok then return value end
    elseif type(GetCVar) == "function" then
        local ok, value = pcall(GetCVar, name)
        if ok then return value end
    end
end

local function SetCVarValue(name, value)
    if C_CVar and type(C_CVar.SetCVar) == "function" then
        return pcall(C_CVar.SetCVar, name, value)
    elseif type(SetCVar) == "function" then
        return pcall(SetCVar, name, value)
    end

    return false
end

local function RestoreBackgroundSound()
    if restoreBackgroundSound ~= nil then
        SetCVarValue(BACKGROUND_SOUND_CVAR, restoreBackgroundSound)
        restoreBackgroundSound = nil
    end
end

local function PlayBackgroundQueueAlert()
    local db = EnsureDB()
    if not db or not db.backgroundSound then return end

    local current = GetCVarValue(BACKGROUND_SOUND_CVAR)
    if current ~= nil and tostring(current) ~= "1" then
        restoreBackgroundSound = tostring(current)
        SetCVarValue(BACKGROUND_SOUND_CVAR, "1")
    end

    local sound = SOUNDKIT and (SOUNDKIT.READY_CHECK or SOUNDKIT.ALARM_CLOCK_WARNING_3)
    if sound and type(PlaySound) == "function" then
        pcall(PlaySound, sound, "Master", true)
    end
end

local function ProposalIsVisible()
    if type(GetLFGProposal) ~= "function" then return false end

    local ok, proposalExists, _, _, _, _, _, _, _, _, _, _, _, _, _, isSilent = pcall(GetLFGProposal)
    return ok and proposalExists == true and isSilent ~= true
end

local function CreateCountdownFrame()
    if countdownFrame then return countdownFrame end

    local popup = _G.LFGDungeonReadyPopup
    if not popup then return nil end

    local frame = CreateFrame("Frame", "ZoidsToolsQueueCountdown", UIParent, "BackdropTemplate")
    frame:SetSize(116, 22)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(1000)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.015, 0.02, 0.03, 0.94)
    frame:SetBackdropBorderColor(0.72, 0.50, 0.10, 0.95)
    local anchored = CanAccessFrame(popup)
        and pcall(frame.SetPoint, frame, "TOP", popup, "BOTTOM", 0, -4)

    if not anchored then
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    end

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetPoint("CENTER", 0, 0)
    frame.text:SetTextColor(1, 0.82, 0.18)
    frame.text:SetText("Expires in 0:40")

    frame.updateElapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.updateElapsed = self.updateElapsed + elapsed
        if self.updateElapsed < 0.1 then return end
        self.updateElapsed = 0

        if not deadline then
            self:Hide()
            return
        end

        local now = type(GetTime) == "function" and GetTime() or 0
        local remaining = math.max(0, math.ceil(deadline - now))
        if remaining ~= lastDisplayedSecond then
            lastDisplayedSecond = remaining
            self.text:SetFormattedText("Expires in %d:%02d", math.floor(remaining / 60), remaining % 60)
        end

        if remaining <= 0 then self:Hide() end
    end)

    frame:Hide()
    countdownFrame = frame
    return frame
end

local function UpdateCountdownVisibility()
    local db = EnsureDB()
    local frame = CreateCountdownFrame()
    if not frame then return end

    if db and db.countdown and deadline and ProposalIsVisible() then
        frame.updateElapsed = 0
        frame:Show()
    else
        frame:Hide()
    end
end

local function ApplySafeQueue()
    local button = _G.LFGDungeonReadyDialog and _G.LFGDungeonReadyDialog.leaveButton
    if not CanAccessFrame(button) or (InCombatLockdown and InCombatLockdown()) then return end

    local db = EnsureDB()
    if db and db.safeQueue and ProposalIsVisible() then
        pcall(button.Hide, button)
    else
        pcall(button.Show, button)
    end
end

local function ScheduleStateRefresh()
    updateGeneration = updateGeneration + 1
    local generation = updateGeneration

    local function Refresh()
        if generation ~= updateGeneration then return end
        ApplySafeQueue()
        UpdateCountdownVisibility()
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, Refresh)
    else
        Refresh()
    end
end

local function StartProposal()
    local now = type(GetTime) == "function" and GetTime() or 0
    deadline = now + PROPOSAL_DURATION
    lastDisplayedSecond = nil

    PlayBackgroundQueueAlert()
    ScheduleStateRefresh()
end

local function StopProposal()
    deadline = nil
    lastDisplayedSecond = nil
    updateGeneration = updateGeneration + 1

    if countdownFrame then countdownFrame:Hide() end
    RestoreBackgroundSound()

    local button = _G.LFGDungeonReadyDialog and _G.LFGDungeonReadyDialog.leaveButton
    if CanAccessFrame(button) and not (InCombatLockdown and InCombatLockdown()) then
        pcall(button.Show, button)
    end
end

function ns:IsQueueBackgroundSoundEnabled()
    local db = EnsureDB()
    return db and db.backgroundSound == true
end

function ns:SetQueueBackgroundSoundEnabled(value)
    local db = EnsureDB()
    if not db then return end
    db.backgroundSound = value == true
    if not db.backgroundSound then RestoreBackgroundSound() end
end

function ns:IsQueueCountdownEnabled()
    local db = EnsureDB()
    return db and db.countdown == true
end

function ns:SetQueueCountdownEnabled(value)
    local db = EnsureDB()
    if not db then return end
    db.countdown = value == true
    UpdateCountdownVisibility()
end

function ns:IsSafeQueueEnabled()
    local db = EnsureDB()
    return db and db.safeQueue == true
end

function ns:SetSafeQueueEnabled(value)
    local db = EnsureDB()
    if not db then return end
    db.safeQueue = value == true
    ScheduleStateRefresh()
end

function ns:InitializeQueueAlerts()
    EnsureDB()

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
        eventFrame:RegisterEvent("LFG_PROPOSAL_UPDATE")
        eventFrame:RegisterEvent("LFG_PROPOSAL_DONE")
        eventFrame:RegisterEvent("LFG_PROPOSAL_FAILED")
        eventFrame:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
        eventFrame:SetScript("OnEvent", function(_, event)
            if event == "LFG_PROPOSAL_SHOW" then
                StartProposal()
            elseif event == "LFG_PROPOSAL_UPDATE" then
                ScheduleStateRefresh()
            else
                StopProposal()
            end
        end)
    end

    if ProposalIsVisible() then
        StartProposal()
    else
        ScheduleStateRefresh()
    end
end
