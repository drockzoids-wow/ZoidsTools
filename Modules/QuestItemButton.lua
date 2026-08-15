local _, ns = ...

local BUTTON_NAME = "ZoidsToolsQuestItemButton"
local BUTTON_SIZE = 46
local ICON_INSET = 4
local DEFAULT_ICON = 134400
local UPDATE_DELAY = 0.08
local PROXIMITY_UPDATE_INTERVAL = 1
local NEARBY_QUEST_DISTANCE = 250
local NEARBY_QUEST_DISTANCE_SQ = NEARBY_QUEST_DISTANCE * NEARBY_QUEST_DISTANCE

-- Blizzard exposes most usable quest items through the quest log. A smaller
-- group only exists in the player's bags; Data/QuestItems.lua holds verified
-- quest-to-item associations for those exceptions.
local INVENTORY_QUEST_ITEMS = ns.QuestItemData or {}

local button
local eventFrame
local updateQueued = false
local moveMode = false
local pendingCombatUpdate = false
local cachedBagItemIndex
local cachedUsableQuestItems
local bagItemIndexDirty = true
local proximityUpdateElapsed = 0

local function IsInCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
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

local function BuildBagItemIndex()
    local index = {}
    local usableQuestItems = {}
    if not C_Container then
        return index, usableQuestItems
    end

    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, lastBag do
        local numSlots = C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local itemID = C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
                local entry = index[itemID]
                if not entry then
                    entry = {
                        itemID = itemID,
                        itemLink = (info and info.hyperlink) or ("item:" .. itemID),
                        itemTexture = (info and info.iconFileID)
                            or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)),
                        charges = 0,
                        bag = bag,
                        slot = slot,
                    }
                    index[itemID] = entry
                end
                entry.charges = entry.charges + (info and tonumber(info.stackCount) or 1)

                local questInfo
                if C_Container.GetContainerItemQuestInfo then
                    local ok, result = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
                    if ok then
                        questInfo = result
                    end
                end

                if questInfo and questInfo.isQuestItem == true and not entry.usableQuestItem then
                    local spellName
                    if C_Item and C_Item.GetItemSpell then
                        local ok, result = pcall(C_Item.GetItemSpell, itemID)
                        if ok then
                            spellName = result
                        end
                    end

                    if spellName then
                        entry.usableQuestItem = true
                        usableQuestItems[#usableQuestItems + 1] = entry
                    end
                end
            end
        end
    end

    return index, usableQuestItems
end

local function GetBagItemIndex()
    if bagItemIndexDirty or not cachedBagItemIndex or not cachedUsableQuestItems then
        cachedBagItemIndex, cachedUsableQuestItems = BuildBagItemIndex()
        bagItemIndexDirty = false
    end
    return cachedBagItemIndex, cachedUsableQuestItems
end

local function GetMappedItemIDs(questID)
    local mapped = INVENTORY_QUEST_ITEMS[questID]
    if type(mapped) == "number" then
        return { mapped }
    end
    if type(mapped) == "table" then
        return mapped
    end
    return nil
end

local function GetInventoryQuestItemInfo(questID, bagItemIndex)
    local itemIDs = GetMappedItemIDs(questID)
    if not itemIDs then
        return nil
    end

    for _, itemID in ipairs(itemIDs) do
        local entry = bagItemIndex[itemID]
        if entry then
            return entry.itemLink, entry.itemTexture, entry.charges, itemID, entry.bag, entry.slot
        end
    end

    return nil
end

local function IsQuestActive(questID)
    if C_TaskQuest and C_TaskQuest.IsActive then
        local ok, active = pcall(C_TaskQuest.IsActive, questID)
        if ok and active == true then
            return true
        end
    end

    if C_QuestLog and C_QuestLog.IsOnQuest then
        local ok, active = pcall(C_QuestLog.IsOnQuest, questID)
        if ok and active == true then
            return true
        end
    end

    return false
end

local function GetQuestRelevance(questID, watchOrder, superTrackedQuestID)
    questID = tonumber(questID)
    if not questID or questID <= 0 or not C_QuestLog then
        return nil
    end

    local questLogIndex = tonumber(C_QuestLog.GetLogIndexForQuestID(questID)) or 0
    if questLogIndex <= 0 and not IsQuestActive(questID) then
        return nil
    end

    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
    if not title and C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
        local ok, taskTitle = pcall(C_TaskQuest.GetQuestInfoByQuestID, questID)
        if ok then
            title = taskTitle
        end
    end

    local insideQuestArea = false
    if C_Minimap and type(C_Minimap.IsInsideQuestBlob) == "function" then
        local ok, inside = pcall(C_Minimap.IsInsideQuestBlob, questID)
        insideQuestArea = ok and not IsSecretValue(inside) and inside == true
    end

    local distanceSq
    local onContinent = false
    if type(C_QuestLog.GetDistanceSqToQuest) == "function" then
        local ok, distance, sameContinent = pcall(C_QuestLog.GetDistanceSqToQuest, questID)
        if ok and not IsSecretValue(distance) and not IsSecretValue(sameContinent)
            and type(distance) == "number" then
            distanceSq = distance
            onContinent = sameContinent == true
        end
    end

    return {
        questID = questID,
        questLogIndex = questLogIndex,
        title = title or ("Quest " .. questID),
        insideQuestArea = insideQuestArea,
        superTracked = superTrackedQuestID == questID,
        distanceSq = distanceSq,
        onContinent = onContinent,
        watchOrder = watchOrder or math.huge,
    }
end

local function IsQuestNearby(candidate)
    if not candidate then
        return false
    end

    if candidate.insideQuestArea then
        return true
    end

    return candidate.onContinent == true
        and candidate.distanceSq ~= nil
        and candidate.distanceSq <= NEARBY_QUEST_DISTANCE_SQ
end

local function GetQuestCandidate(candidate, bagItemIndex)
    if not candidate then
        return nil
    end

    local isComplete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(candidate.questID) == true
    local itemLink, itemTexture, charges, itemID, bag, slot
    local inventoryItem = false

    if candidate.questLogIndex > 0 and QuestShowsItem(candidate.questLogIndex, isComplete) then
        itemLink, itemTexture, charges = GetQuestLogSpecialItemInfo(candidate.questLogIndex)
    elseif not isComplete then
        itemLink, itemTexture, charges, itemID, bag, slot = GetInventoryQuestItemInfo(candidate.questID, bagItemIndex)
        inventoryItem = itemLink ~= nil
    end

    if not itemLink then
        return nil
    end

    candidate.itemLink = itemLink
    candidate.itemTexture = itemTexture
    candidate.charges = charges
    candidate.itemID = itemID
    candidate.bag = bag
    candidate.slot = slot
    candidate.inventoryItem = inventoryItem
    return candidate
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
    local bestRelevantQuest
    local seen = {}
    local order = 0
    local bagItemIndex, usableQuestItems = GetBagItemIndex()
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
        local relevance = GetQuestRelevance(questID, order, superTrackedQuestID)
        if relevance and IsQuestNearby(relevance) and CandidateIsBetter(relevance, bestRelevantQuest) then
            bestRelevantQuest = relevance
        end

        local candidate = IsQuestNearby(relevance) and GetQuestCandidate(relevance, bagItemIndex) or nil
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

    -- Also consider active but untracked quests. This lets an item follow the
    -- player's actual quest area without requiring the quest to be pinned.
    local numQuestLogEntries = C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() or 0
    for index = 1, numQuestLogEntries do
        local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(index)
        if info and not info.isHeader and not info.isHidden then
            Consider(info.questID)
        end
    end

    -- Task/world quests can be active without a normal quest-log index. Check
    -- the small verified exception catalog directly so those items still work
    -- even when the quest is not pinned in Blizzard's tracker.
    for questID in pairs(INVENTORY_QUEST_ITEMS) do
        if IsQuestActive(questID) then
            Consider(questID)
        end
    end

    -- Some bag-only quest items have no quest ID in Blizzard's API and are not
    -- present in the offline exception catalog. When there is exactly one
    -- usable quest item and one clearly relevant quest, selecting it is safe.
    if not best and #usableQuestItems == 1 and bestRelevantQuest then
        local entry = usableQuestItems[1]
        best = bestRelevantQuest
        best.itemLink = entry.itemLink
        best.itemTexture = entry.itemTexture
        best.charges = entry.charges
        best.itemID = entry.itemID
        best.bag = entry.bag
        best.slot = entry.slot
        best.inventoryItem = true
        best.inferredInventoryItem = true
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

local function UpdateCooldown()
    if not button or not button:IsShown() or not button.candidate then
        return
    end

    local candidate = button.candidate
    local questLogIndex = candidate.questLogIndex
    local start, duration, enabled
    if candidate.inventoryItem and C_Container and C_Container.GetItemCooldown then
        start, duration, enabled = C_Container.GetItemCooldown(candidate.bag, candidate.slot)
    else
        start, duration, enabled = GetQuestLogSpecialItemCooldown(questLogIndex)
    end
    if start then
        CooldownFrame_Set(button.cooldown, start, duration, enabled)

        local desaturated = false
        if not IsSecretValue(duration) and not IsSecretValue(enabled) then
            desaturated = (tonumber(duration) or 0) > 0 and tonumber(enabled) == 0
        end

        button.icon:SetDesaturated(desaturated)
    else
        button.cooldown:Clear()
        button.icon:SetDesaturated(false)
    end

    -- Item and quest-special-item range queries can be protected/secret in
    -- 12.1. Keep the secure item action available and let Blizzard reject an
    -- out-of-range use normally instead of tainting the protected UI path.
    button.icon:SetVertexColor(1, 1, 1)
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
        -- Keep right-click free for moving, and disable the left-click action
        -- while unlocked so finishing a drag cannot also use the item.
        button:SetAttribute("type", nil)
        button:SetAttribute("item", nil)
        button:SetAttribute("type1", moveMode and nil or "item")
        button:SetAttribute("item1", moveMode and nil or candidate.itemLink)
        button.icon:SetTexture(candidate.itemTexture or DEFAULT_ICON)
        button.count:SetText((candidate.charges and candidate.charges > 1) and candidate.charges or "")
        button:Show()
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
    end

    UpdateCooldown()
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
    button:RegisterForDrag("LeftButton", "RightButton")
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

    button:SetScript("OnDragStart", function(self, mouseButton)
        if not IsInCombat() and (moveMode or mouseButton == "RightButton") then
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
            if self.candidate.inventoryItem and self.candidate.bag and self.candidate.slot then
                GameTooltip:SetBagItem(self.candidate.bag, self.candidate.slot)
            else
                GameTooltip:SetQuestLogSpecialItem(self.candidate.questLogIndex)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(self.candidate.title or "Tracked quest item", 1, 0.82, 0.28, true)
            GameTooltip:AddLine("ZoidsTools selected the most relevant tracked quest item.", 0.78, 0.78, 0.78, true)
        else
            GameTooltip:SetText("Smart Quest Item")
            GameTooltip:AddLine("A usable quest item will appear here when one is relevant to your current area.", 1, 1, 1, true)
        end
        if moveMode then
            GameTooltip:AddLine("Left- or right-drag to move this button.", 0.65, 0.85, 1, true)
        else
            GameTooltip:AddLine("Right-drag to move this button.", 0.65, 0.85, 1, true)
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
            UpdateCooldown()
            return
        end

        if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_ENTERING_WORLD" then
            bagItemIndexDirty = true
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

    eventFrame:SetScript("OnUpdate", function(_, elapsed)
        local db = EnsureDB()
        if not db or db.questItemButtonEnabled ~= true or IsInCombat() then
            proximityUpdateElapsed = 0
            return
        end

        proximityUpdateElapsed = proximityUpdateElapsed + elapsed
        if proximityUpdateElapsed >= PROXIMITY_UPDATE_INTERVAL then
            proximityUpdateElapsed = 0
            ScheduleRefresh(0)
        end
    end)

    RefreshButton()
end
