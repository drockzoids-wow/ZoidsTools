local _, ns = ...

local BUTTON_NAME = "ZoidsToolsQuestItemButton"
local BUTTON_SIZE = 46
local ICON_INSET = 4
local DEFAULT_ICON = 134400
local UPDATE_DELAY = 0.08

local button
local eventFrame
local updateQueued = false
local moveMode = false
local pendingCombatUpdate = false
local rangeTicker

local function IsInCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.quests = ns.db.quests or {}
    local db = ns.db.quests

    if db.questItemButtonEnabled == nil then
        db.questItemButtonEnabled = true
    end

    db.questItemButton = db.questItemButton or {}
    local position = db.questItemButton
    position.point = position.point or "CENTER"
    position.relativePoint = position.relativePoint or position.point
    position.x = tonumber(position.x) or 280
    position.y = tonumber(position.y) or -80

    return db
end

local function GetClassColor()
    local _, classFile = UnitClass("player")
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    return color and color.r or 0.85, color and color.g or 0.70, color and color.b or 0.38
end

local function SavePosition()
    local db = EnsureDB()
    local position = db and db.questItemButton

    if not position or not button then
        return
    end

    local point, _, relativePoint, x, y = button:GetPoint(1)
    if point then
        position.point = point
        position.relativePoint = relativePoint or point
        position.x = x or 0
        position.y = y or 0
    end
end

local function RestorePosition()
    local db = EnsureDB()
    local position = db and db.questItemButton

    if not button or not position then
        return
    end

    button:ClearAllPoints()
    button:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

local function QuestShowsItem(questLogIndex, isComplete)
    if QuestUtil and type(QuestUtil.QuestShowsItemByIndex) == "function" then
        local ok, showsItem = pcall(QuestUtil.QuestShowsItemByIndex, questLogIndex, isComplete)
        if ok then
            return showsItem == true
        end
    end

    local itemLink, _, _, showItemWhenComplete = GetQuestLogSpecialItemInfo(questLogIndex)
    return itemLink ~= nil and (not isComplete or showItemWhenComplete == true)
end

local function GetQuestCandidate(questID, watchOrder, superTrackedQuestID)
    questID = tonumber(questID)
    if not questID or questID <= 0 or not C_QuestLog then
        return nil
    end

    local questLogIndex = tonumber(C_QuestLog.GetLogIndexForQuestID(questID))
    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    local isComplete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) == true
    if not QuestShowsItem(questLogIndex, isComplete) then
        return nil
    end

    local itemLink, itemTexture, charges = GetQuestLogSpecialItemInfo(questLogIndex)
    if not itemLink then
        return nil
    end

    local insideQuestArea = false
    if C_Minimap and type(C_Minimap.IsInsideQuestBlob) == "function" then
        local ok, inside = pcall(C_Minimap.IsInsideQuestBlob, questID)
        insideQuestArea = ok and inside == true
    end

    local distanceSq
    local onContinent = false
    if type(C_QuestLog.GetDistanceSqToQuest) == "function" then
        local ok, distance, sameContinent = pcall(C_QuestLog.GetDistanceSqToQuest, questID)
        if ok and type(distance) == "number" then
            distanceSq = distance
            onContinent = sameContinent ~= false
        end
    end

    return {
        questID = questID,
        questLogIndex = questLogIndex,
        title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or ("Quest " .. questID),
        itemLink = itemLink,
        itemTexture = itemTexture,
        charges = charges,
        insideQuestArea = insideQuestArea,
        superTracked = superTrackedQuestID == questID,
        distanceSq = distanceSq,
        onContinent = onContinent,
        watchOrder = watchOrder or math.huge,
    }
end

local function CandidateIsBetter(candidate, current)
    if not current then
        return true
    end

    if candidate.insideQuestArea ~= current.insideQuestArea then
        return candidate.insideQuestArea
    end

    if candidate.superTracked ~= current.superTracked then
        return candidate.superTracked
    end

    local candidateHasDistance = candidate.onContinent and candidate.distanceSq ~= nil
    local currentHasDistance = current.onContinent and current.distanceSq ~= nil
    if candidateHasDistance ~= currentHasDistance then
        return candidateHasDistance
    end

    if candidateHasDistance and candidate.distanceSq ~= current.distanceSq then
        return candidate.distanceSq < current.distanceSq
    end

    return candidate.watchOrder < current.watchOrder
end

local function FindBestQuestItem()
    if not C_QuestLog then
        return nil
    end

    local best
    local seen = {}
    local order = 0
    local superTrackedQuestID = C_SuperTrack
        and C_SuperTrack.GetSuperTrackedQuestID
        and C_SuperTrack.GetSuperTrackedQuestID()

    local function Consider(questID)
        questID = tonumber(questID)
        if not questID or seen[questID] then
            return
        end

        seen[questID] = true
        order = order + 1
        local candidate = GetQuestCandidate(questID, order, superTrackedQuestID)
        if candidate and CandidateIsBetter(candidate, best) then
            best = candidate
        end
    end

    Consider(superTrackedQuestID)

    local numQuestWatches = C_QuestLog.GetNumQuestWatches and C_QuestLog.GetNumQuestWatches() or 0
    for index = 1, numQuestWatches do
        Consider(C_QuestLog.GetQuestIDForQuestWatchIndex(index))
    end

    local numWorldQuestWatches = C_QuestLog.GetNumWorldQuestWatches and C_QuestLog.GetNumWorldQuestWatches() or 0
    for index = 1, numWorldQuestWatches do
        Consider(C_QuestLog.GetQuestIDForWorldQuestWatchIndex(index))
    end

    return best
end

local function UpdateHotkey()
    if not button then
        return
    end

    local key = GetBindingKey and GetBindingKey("CLICK " .. BUTTON_NAME .. ":LeftButton")
    if key then
        key = key:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-")
        button.hotkey:SetText(key)
        button.hotkey:Show()
    else
        button.hotkey:Hide()
    end
end

local function UpdateCooldownAndRange()
    if not button or not button:IsShown() or not button.candidate then
        return
    end

    local questLogIndex = button.candidate.questLogIndex
    local start, duration, enabled = GetQuestLogSpecialItemCooldown(questLogIndex)
    if start then
        CooldownFrame_Set(button.cooldown, start, duration, enabled)
        button.icon:SetDesaturated(duration and duration > 0 and enabled == 0)
    else
        button.cooldown:Clear()
        button.icon:SetDesaturated(false)
    end

    local inRange = IsQuestLogSpecialItemInRange and IsQuestLogSpecialItemInRange(questLogIndex)
    if inRange == 0 then
        button.icon:SetVertexColor(1, 0.30, 0.30)
    else
        button.icon:SetVertexColor(1, 1, 1)
    end
end

local function RefreshRangeTicker(shouldRun)
    if shouldRun and not rangeTicker and C_Timer and C_Timer.NewTicker then
        rangeTicker = C_Timer.NewTicker(0.20, UpdateCooldownAndRange)
    elseif not shouldRun and rangeTicker then
        rangeTicker:Cancel()
        rangeTicker = nil
    end
end

local function ApplyCandidate(candidate)
    if not button then
        return
    end

    if IsInCombat() then
        pendingCombatUpdate = true
        return
    end

    pendingCombatUpdate = false
    button.candidate = candidate

    if candidate then
        button:SetAttribute("type", "item")
        button:SetAttribute("type1", "item")
        button:SetAttribute("item", candidate.itemLink)
        button:SetAttribute("item1", candidate.itemLink)
        button.icon:SetTexture(candidate.itemTexture or DEFAULT_ICON)
        button.count:SetText((candidate.charges and candidate.charges > 1) and candidate.charges or "")
        button:Show()
        RefreshRangeTicker(true)
    else
        button:SetAttribute("type", nil)
        button:SetAttribute("type1", nil)
        button:SetAttribute("item", nil)
        button:SetAttribute("item1", nil)
        button.icon:SetTexture(DEFAULT_ICON)
        button.count:SetText("")
        if moveMode then
            button:Show()
        else
            button:Hide()
        end
        RefreshRangeTicker(false)
    end

    UpdateCooldownAndRange()
end

local function RefreshButton()
    local db = EnsureDB()
    if not db then
        return
    end

    if IsInCombat() then
        pendingCombatUpdate = true
        return
    end

    if db.questItemButtonEnabled ~= true then
        ApplyCandidate(nil)
        if button then
            button:Hide()
        end
        return
    end

    ApplyCandidate(FindBestQuestItem())
end

RefreshButton = ns:WrapDiagnosticFunction("QuestItemButton.Refresh", RefreshButton)

local function ScheduleRefresh(delay)
    if updateQueued then
        return
    end

    updateQueued = true
    local function Run()
        updateQueued = false
        RefreshButton()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(tonumber(delay) or UPDATE_DELAY, Run)
    else
        Run()
    end
end

local function CreateButton()
    if button then
        return button
    end

    button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate,BackdropTemplate")
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetAttribute("pressAndHoldAction", true)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 11,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    button:SetBackdropColor(0.012, 0.014, 0.018, 0.92)
    button:SetBackdropBorderColor(GetClassColor())

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", ICON_INSET, -ICON_INSET)
    button.icon:SetPoint("BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
    button.icon:SetTexture(DEFAULT_ICON)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)

    button.hotkey = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    button.hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -3)

    button:SetScript("OnDragStart", function(self)
        if moveMode and not IsInCombat() then
            self:StartMoving()
        end
    end)

    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.candidate then
            GameTooltip:SetQuestLogSpecialItem(self.candidate.questLogIndex)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(self.candidate.title or "Tracked quest item", 1, 0.82, 0.28, true)
            GameTooltip:AddLine("ZoidsTools selected the most relevant tracked quest item.", 0.78, 0.78, 0.78, true)
        else
            GameTooltip:SetText("Smart Quest Item")
            GameTooltip:AddLine("A usable quest item will appear here when one is relevant to your current area.", 1, 1, 1, true)
        end
        if moveMode then
            GameTooltip:AddLine("Drag to move this button.", 0.65, 0.85, 1, true)
        end
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("PostClick", function()
        ScheduleRefresh(0.15)
    end)

    RestorePosition()
    UpdateHotkey()
    button:Hide()
    return button
end

function ns:GetQuestItemButtonEnabled()
    local db = EnsureDB()
    return db and db.questItemButtonEnabled == true
end

function ns:SetQuestItemButtonEnabled(value)
    local db = EnsureDB()
    if not db then
        return
    end

    db.questItemButtonEnabled = value == true
    CreateButton()
    ScheduleRefresh(0)
end

function ns:IsQuestItemButtonMoveMode()
    return moveMode == true
end

function ns:ToggleQuestItemButtonMoveMode()
    if IsInCombat() then
        ns:Print("The quest item button cannot be moved during combat.")
        return moveMode
    end

    moveMode = not moveMode
    CreateButton()
    RefreshButton()
    ns:Print(moveMode and "Quest item button unlocked. Drag it into position, then lock it from Quest settings." or "Quest item button locked.")
    return moveMode
end

function ns:RefreshQuestItemButton()
    ScheduleRefresh(0)
end

function ns:InitializeQuestItemButton()
    EnsureDB()
    CreateButton()

    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    eventFrame:RegisterEvent("QUEST_POI_UPDATE")
    eventFrame:RegisterEvent("SUPER_TRACKING_CHANGED")
    eventFrame:RegisterEvent("PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("UPDATE_BINDINGS")

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_BINDINGS" then
            UpdateHotkey()
            return
        end

        if event == "BAG_UPDATE_COOLDOWN" then
            UpdateCooldownAndRange()
            return
        end

        if event == "PLAYER_REGEN_DISABLED" then
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            if pendingCombatUpdate then
                RefreshButton()
            else
                ScheduleRefresh(0)
            end
            return
        end

        ScheduleRefresh()
    end)

    RefreshButton()
end
