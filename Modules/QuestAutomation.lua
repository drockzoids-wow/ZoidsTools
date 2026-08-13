local _, ns = ...

local eventFrame
local questFilterPrompt
local pendingQuestFilterPrompt = false
local pendingAcceptQuests = {}
local clickedGossipOptions = {}
local tableUnpack = table.unpack or unpack
local QUEST_ACTION_ACCEPT = "accept"
local QUEST_ACTION_TURN_IN = "turnIn"

local pauseModifiers = {
    none = true,
    shift = true,
    ctrl = true,
    alt = true,
}

local characterFilterKeys = {
    skipDaily = true,
    skipWarbandCompleted = true,
}

local function PackResults(...)
    return { n = select("#", ...), ... }
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local results = PackResults(pcall(func, ...))

    if results[1] then
        return tableUnpack(results, 2, results.n)
    end

    return nil
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.quests = ns.db.quests or {}

    local db = ns.db.quests

    if db.autoAccept == nil then
        db.autoAccept = false
    end

    if db.autoTurnIn == nil then
        db.autoTurnIn = false
    end

    if db.autoGossip == nil then
        db.autoGossip = false
    end

    if not pauseModifiers[db.pauseModifier] then
        db.pauseModifier = "shift"
    end

    -- These two filters used to be stored account-wide. They now live only in
    -- SavedVariablesPerCharacter, so stale account values must not leak into a
    -- character that has not made its own choices yet.
    db.skipDaily = nil
    db.skipWarbandCompleted = nil

    return db
end

local function EnsureCharacterQuestDB()
    if type(_G.ZoidsToolsCharDB) ~= "table" then
        _G.ZoidsToolsCharDB = {}
    end

    ns.charDB = _G.ZoidsToolsCharDB
    ns.charDB.quests = type(ns.charDB.quests) == "table" and ns.charDB.quests or {}

    local db = ns.charDB.quests

    if db.skipDaily == nil then
        db.skipDaily = false
    end

    if db.skipWarbandCompleted == nil then
        db.skipWarbandCompleted = false
    end

    return db
end

local function IsPauseModifierHeld()
    local db = EnsureDB()
    local modifier = db and db.pauseModifier or "shift"

    if modifier == "shift" then
        return IsShiftKeyDown and IsShiftKeyDown()
    elseif modifier == "ctrl" then
        return IsControlKeyDown and IsControlKeyDown()
    elseif modifier == "alt" then
        return IsAltKeyDown and IsAltKeyDown()
    end

    return false
end

local function IsAutomationPaused()
    return IsPauseModifierHeld() == true
end

local function IsRepeatableQuest(questID, frequency)
    if tonumber(frequency or 0) and tonumber(frequency or 0) > 0 then
        return true
    end

    if type(GetQuestFrequency) == "function" then
        local questFrequency = SafeCall(GetQuestFrequency)

        if tonumber(questFrequency or 0) and tonumber(questFrequency or 0) > 0 then
            return true
        end
    end

    if questID and C_QuestInfoSystem and type(C_QuestInfoSystem.GetQuestClassification) == "function" then
        local classification = SafeCall(C_QuestInfoSystem.GetQuestClassification, questID)

        if Enum and Enum.QuestClassification then
            return classification == Enum.QuestClassification.Recurring
                or classification == Enum.QuestClassification.Calling
        end
    end

    return false
end

local function IsDailyQuest(frequency)
    local dailyFrequency = LE_QUEST_FREQUENCY_DAILY or 1

    if Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily then
        dailyFrequency = Enum.QuestFrequency.Daily
    end

    local questFrequency = tonumber(frequency)

    if not questFrequency and type(GetQuestFrequency) == "function" then
        questFrequency = tonumber(SafeCall(GetQuestFrequency))
    end

    return questFrequency == tonumber(dailyFrequency)
end

local function IsWarbandCompletedQuest(questID)
    if not questID or not C_QuestLog or type(C_QuestLog.IsQuestFlaggedCompletedOnAccount) ~= "function" then
        return false
    end

    return SafeCall(C_QuestLog.IsQuestFlaggedCompletedOnAccount, questID) == true
end

local function ShouldSkipQuest(questID, frequency, action)
    local db = EnsureDB()
    local filters = EnsureCharacterQuestDB()

    if not db or not filters then
        return true
    end

    if action == QUEST_ACTION_TURN_IN and IsWarbandCompletedQuest(questID) then
        return false
    end

    if filters.skipDaily and IsRepeatableQuest(questID, frequency) then
        return true
    end

    if action ~= QUEST_ACTION_TURN_IN and filters.skipWarbandCompleted and IsWarbandCompletedQuest(questID) then
        -- When dailies are allowed, that explicit choice takes precedence over
        -- the account-completion filter for daily quests.
        return filters.skipDaily == true or not IsDailyQuest(frequency)
    end

    return false
end

local function CanAutoAccept()
    local db = EnsureDB()

    return db and db.autoAccept == true and not IsAutomationPaused()
end

local function CanAutoTurnIn()
    local db = EnsureDB()

    return db and db.autoTurnIn == true and not IsAutomationPaused()
end

local function CanAutoGossip()
    local db = EnsureDB()

    return db and db.autoGossip == true and not IsAutomationPaused()
end

local function SelectGossipOption(option)
    if not option or not C_GossipInfo then
        return false
    end

    if option.orderIndex and type(C_GossipInfo.SelectOptionByIndex) == "function" then
        SafeCall(C_GossipInfo.SelectOptionByIndex, option.orderIndex)
        return true
    elseif option.gossipOptionID and type(C_GossipInfo.SelectOption) == "function" then
        SafeCall(C_GossipInfo.SelectOption, option.gossipOptionID)
        return true
    end

    return false
end

local function GetGossipClickKey(option)
    if not option then
        return nil
    end

    if option.gossipOptionID then
        return "id:" .. tostring(option.gossipOptionID)
    end

    if option.orderIndex then
        return "order:" .. tostring(option.orderIndex) .. ":" .. tostring(option.name or "")
    end

    return nil
end

local function HandleGossipQuests()
    if not C_GossipInfo then
        return
    end

    if CanAutoTurnIn() and type(C_GossipInfo.GetActiveQuests) == "function" then
        local activeQuests = SafeCall(C_GossipInfo.GetActiveQuests)

        if type(activeQuests) == "table" then
            for _, quest in ipairs(activeQuests) do
                if quest and quest.isComplete and not ShouldSkipQuest(quest.questID, quest.frequency, QUEST_ACTION_TURN_IN) and type(C_GossipInfo.SelectActiveQuest) == "function" then
                    SafeCall(C_GossipInfo.SelectActiveQuest, quest.questID)
                    return true
                end
            end
        end
    end

    if CanAutoAccept() and type(C_GossipInfo.GetAvailableQuests) == "function" then
        local availableQuests = SafeCall(C_GossipInfo.GetAvailableQuests)

        if type(availableQuests) == "table" then
            for _, quest in ipairs(availableQuests) do
                if quest and not ShouldSkipQuest(quest.questID, quest.frequency, QUEST_ACTION_ACCEPT) and type(C_GossipInfo.SelectAvailableQuest) == "function" then
                    SafeCall(C_GossipInfo.SelectAvailableQuest, quest.questID)
                    return true
                end
            end
        end
    end

    return false
end

local function HandleAutoGossip()
    if not CanAutoGossip() or not C_GossipInfo or type(C_GossipInfo.GetOptions) ~= "function" then
        return
    end

    local options = SafeCall(C_GossipInfo.GetOptions)

    if type(options) ~= "table" or #options == 0 then
        return
    end

    local optionToSelect

    if #options == 1 then
        optionToSelect = options[1]
    else
        for _, option in ipairs(options) do
            if option and option.flags == 1 then
                optionToSelect = option
                break
            end
        end
    end

    local clickKey = GetGossipClickKey(optionToSelect)

    if optionToSelect and clickKey and not clickedGossipOptions[clickKey] then
        clickedGossipOptions[clickKey] = true
        SelectGossipOption(optionToSelect)
    end
end

local function HandleGossipShow()
    if HandleGossipQuests() then
        return
    end

    HandleAutoGossip()
end

local function HandleQuestDetail()
    if not CanAutoAccept() then
        return
    end

    local questID = GetQuestID and GetQuestID() or nil

    if not questID then
        if not ShouldSkipQuest(nil, nil, QUEST_ACTION_ACCEPT) then
            SafeCall(AcceptQuest)
        end

        return
    end

    pendingAcceptQuests[questID] = true

    if C_QuestLog and type(C_QuestLog.RequestLoadQuestByID) == "function" then
        C_QuestLog.RequestLoadQuestByID(questID)
    else
        if not ShouldSkipQuest(questID, nil, QUEST_ACTION_ACCEPT) then
            SafeCall(AcceptQuest)
        end

        pendingAcceptQuests[questID] = nil
    end
end

local function HandleQuestDataLoadResult(questID)
    if not questID or not pendingAcceptQuests[questID] then
        return
    end

    pendingAcceptQuests[questID] = nil

    if CanAutoAccept() and not ShouldSkipQuest(questID, nil, QUEST_ACTION_ACCEPT) then
        SafeCall(AcceptQuest)
    end
end

local function HandleQuestGreeting()
    if CanAutoAccept() then
        local availableCount = GetNumAvailableQuests and GetNumAvailableQuests() or 0

        for index = 1, availableCount do
            if SelectAvailableQuest then
                SafeCall(SelectAvailableQuest, index)
                return
            end
        end
    end

    if CanAutoTurnIn() then
        local activeCount = GetNumActiveQuests and GetNumActiveQuests() or 0

        for index = 1, activeCount do
            local _, isComplete = SafeCall(GetActiveTitle, index)

            if isComplete and SelectActiveQuest then
                SafeCall(SelectActiveQuest, index)
                return
            end
        end
    end
end

local function HandleQuestProgress()
    if CanAutoTurnIn() and IsQuestCompletable and IsQuestCompletable() then
        SafeCall(CompleteQuest)
    end
end

local function HandleQuestComplete()
    if not CanAutoTurnIn() then
        return
    end

    local choices = GetNumQuestChoices and GetNumQuestChoices() or 0

    if choices > 1 then
        return
    elseif choices == 1 then
        SafeCall(GetQuestReward, 1)
    else
        SafeCall(GetQuestReward)
    end
end

function ns:SetQuestAutomationOption(key, value)
    if characterFilterKeys[key] then
        local characterDB = EnsureCharacterQuestDB()

        characterDB[key] = value == true
        characterDB.filterPromptCompleted = true
        return
    end

    local db = EnsureDB()

    if not db or db[key] == nil then
        return
    end

    db[key] = value == true
end

function ns:GetQuestAutomationOption(key)
    if characterFilterKeys[key] then
        local characterDB = EnsureCharacterQuestDB()

        return characterDB and characterDB[key] == true
    end

    local db = EnsureDB()

    return db and db[key] == true
end

local function SaveQuestFilterChoices(skipDaily, skipWarbandCompleted)
    local db = EnsureCharacterQuestDB()

    db.skipDaily = skipDaily == true
    db.skipWarbandCompleted = skipWarbandCompleted == true
    db.filterPromptCompleted = true
    pendingQuestFilterPrompt = false

    if eventFrame then
        eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end

    if questFilterPrompt then
        questFilterPrompt:Hide()
    end
end

local function CreateQuestFilterPrompt()
    if questFilterPrompt then
        return questFilterPrompt
    end

    local frame = CreateFrame("Frame", "ZoidsToolsQuestFilterPrompt", UIParent, "BackdropTemplate")
    frame:SetSize(500, 270)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(500)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -24)
    title:SetText("ZoidsTools Quest Filters")

    local description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", 32, -58)
    description:SetPoint("TOPRIGHT", -32, -58)
    description:SetJustifyH("LEFT")
    description:SetText("Choose which quests this character should ignore during automatic quest acceptance. These choices can be changed later in ZoidsTools > Automation > Quests.")

    local daily = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    daily:SetPoint("TOPLEFT", 34, -112)
    daily:SetSize(26, 26)
    daily.label = daily:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    daily.label:SetPoint("LEFT", daily, "RIGHT", 6, 0)
    daily.label:SetText("Skip daily and weekly quests")
    frame.skipDaily = daily

    local warband = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    warband:SetPoint("TOPLEFT", daily, "BOTTOMLEFT", 0, -14)
    warband:SetSize(26, 26)
    warband.label = warband:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    warband.label:SetPoint("LEFT", warband, "RIGHT", 6, 0)
    warband.label:SetText("Skip Warband-completed quests")
    frame.skipWarbandCompleted = warband

    local save = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    save:SetSize(150, 28)
    save:SetPoint("BOTTOMRIGHT", -28, 24)
    save:SetText("Save Choices")
    save:SetScript("OnClick", function()
        SaveQuestFilterChoices(daily:GetChecked(), warband:GetChecked())
    end)

    local keepOff = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    keepOff:SetSize(150, 28)
    keepOff:SetPoint("RIGHT", save, "LEFT", -12, 0)
    keepOff:SetText("Keep Both Off")
    keepOff:SetScript("OnClick", function()
        SaveQuestFilterChoices(false, false)
    end)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function()
        SaveQuestFilterChoices(false, false)
    end)

    questFilterPrompt = frame
    return frame
end

local function ShowQuestFilterPromptIfNeeded()
    local db = EnsureCharacterQuestDB()

    if db.filterPromptCompleted == true then
        pendingQuestFilterPrompt = false
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingQuestFilterPrompt = true

        if eventFrame then
            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end

        return
    end

    pendingQuestFilterPrompt = false

    if eventFrame then
        eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end

    local frame = CreateQuestFilterPrompt()
    frame.skipDaily:SetChecked(db.skipDaily == true)
    frame.skipWarbandCompleted:SetChecked(db.skipWarbandCompleted == true)
    frame:Show()
    frame:Raise()
end

function ns:SetQuestAutomationPauseModifier(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.pauseModifier = pauseModifiers[value] and value or "shift"
end

function ns:GetQuestAutomationPauseModifier()
    local db = EnsureDB()

    return db and db.pauseModifier or "shift"
end

function ns:GetQuestAutomationPauseModifierOptions()
    return {
        { value = "shift", text = "Shift" },
        { value = "ctrl", text = "Ctrl" },
        { value = "alt", text = "Alt" },
        { value = "none", text = "None" },
    }
end

function ns:InitializeQuestAutomation()
    EnsureDB()
    EnsureCharacterQuestDB()

    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GOSSIP_SHOW")
    eventFrame:RegisterEvent("GOSSIP_CLOSED")
    eventFrame:RegisterEvent("QUEST_DETAIL")
    eventFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
    eventFrame:RegisterEvent("QUEST_GREETING")
    eventFrame:RegisterEvent("QUEST_PROGRESS")
    eventFrame:RegisterEvent("QUEST_COMPLETE")

    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "GOSSIP_SHOW" then
            HandleGossipShow()
        elseif event == "GOSSIP_CLOSED" then
            clickedGossipOptions = {}
        elseif event == "QUEST_DETAIL" then
            HandleQuestDetail()
        elseif event == "QUEST_DATA_LOAD_RESULT" then
            HandleQuestDataLoadResult(arg1)
        elseif event == "QUEST_GREETING" then
            HandleQuestGreeting()
        elseif event == "QUEST_PROGRESS" then
            HandleQuestProgress()
        elseif event == "QUEST_COMPLETE" then
            HandleQuestComplete()
        elseif event == "PLAYER_REGEN_ENABLED" and pendingQuestFilterPrompt then
            ShowQuestFilterPromptIfNeeded()
        end
    end)

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(1.5, ShowQuestFilterPromptIfNeeded)
    else
        ShowQuestFilterPromptIfNeeded()
    end
end
