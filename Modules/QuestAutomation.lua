local _, ns = ...

local eventFrame
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

    if db.skipDaily == nil then
        db.skipDaily = true
    end

    if db.skipWarbandCompleted == nil then
        db.skipWarbandCompleted = true
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

local function IsWarbandCompletedQuest(questID)
    if not questID or not C_QuestLog or type(C_QuestLog.IsQuestFlaggedCompletedOnAccount) ~= "function" then
        return false
    end

    return SafeCall(C_QuestLog.IsQuestFlaggedCompletedOnAccount, questID) == true
end

local function ShouldSkipQuest(questID, frequency, action)
    local db = EnsureDB()

    if not db then
        return true
    end

    if action == QUEST_ACTION_TURN_IN and IsWarbandCompletedQuest(questID) then
        return false
    end

    if db.skipDaily and IsRepeatableQuest(questID, frequency) then
        return true
    end

    if action ~= QUEST_ACTION_TURN_IN and db.skipWarbandCompleted and IsWarbandCompletedQuest(questID) then
        return true
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
    local db = EnsureDB()

    if not db or db[key] == nil then
        return
    end

    db[key] = value == true
end

function ns:GetQuestAutomationOption(key)
    local db = EnsureDB()

    return db and db[key] == true
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
        end
    end)
end
