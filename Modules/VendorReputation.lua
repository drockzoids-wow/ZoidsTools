local _, ns = ...

local events, bar
local merchantOpen = false
local generation = 0
local factionID
local factionNames = {}
local readingFactions = false
local namesRead = false

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end

local function CleanText(text)
    if (issecretvalue and issecretvalue(text)) or type(text) ~= "string" then return nil end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
end

local function RememberFaction(data)
    if not data or (data.isHeader and not data.isHeaderWithRep) then return end
    local name = CleanText(data.name)
    if name and name ~= "" then factionNames[name] = data.factionID end
end

local function ReadFactionNames()
    if namesRead or readingFactions or not C_Reputation then return end
    namesRead = true
    readingFactions = true
    local collapsed = {}
    -- The indexed list omits collapsed children. Restore every header afterwards,
    -- in reverse order so its original index is valid again.
    local index = 1
    while index <= (SafeCall(C_Reputation.GetNumFactions) or 0) do
        local data = SafeCall(C_Reputation.GetFactionDataByIndex, index)
        RememberFaction(data)
        if data and data.isHeader and data.isCollapsed
            and C_Reputation.ExpandFactionHeader and C_Reputation.CollapseFactionHeader then
            collapsed[#collapsed + 1] = index
            SafeCall(C_Reputation.ExpandFactionHeader, index)
        end
        index = index + 1
    end
    for i = #collapsed, 1, -1 do
        SafeCall(C_Reputation.CollapseFactionHeader, collapsed[i])
    end
    readingFactions = false
end

local function FindFactionInTooltip(data, exact)
    if not data or type(data.lines) ~= "table" then return nil end
    local bestID, bestLength = nil, 0
    for _, line in ipairs(data.lines) do
        local text = CleanText(line.leftText)
        if text then
            for name, id in pairs(factionNames) do
                local matches = exact and text == name
                if not exact then
                    -- Only reputation requirements, never an item's descriptive text.
                    local prefix = CleanText(ITEM_REQ_REPUTATION or "Requires %s - %s")
                    prefix = prefix:match("^(.-)%%") or "Requires "
                    matches = text:sub(1, #prefix) == prefix and text:find(name, #prefix + 1, true)
                end
                if matches and #name > bestLength then bestID, bestLength = id, #name end
            end
        end
    end
    return bestID
end

local function ResolveVendorFaction()
    -- Zero asks Blizzard for the friendship of the NPC being interacted with.
    local friendship = C_GossipInfo and SafeCall(C_GossipInfo.GetFriendshipReputation, 0)
    if friendship and friendship.friendshipFactionID and friendship.friendshipFactionID > 0 then
        return friendship.friendshipFactionID
    end
    ReadFactionNames()
    -- Quartermasters can belong to a different faction from the one their stock
    -- requires, so prefer the reputation requirements on their merchandise.
    if C_TooltipInfo and C_TooltipInfo.GetMerchantItem then
        local found
        for index = 1, (SafeCall(GetMerchantNumItems) or 0) do
            local id = FindFactionInTooltip(SafeCall(C_TooltipInfo.GetMerchantItem, index), false)
            if id then
                if found and found ~= id then return nil end -- Mixed-faction stock is ambiguous.
                found = id
            end
        end
        if found then return found end
    end
    return C_TooltipInfo and FindFactionInTooltip(SafeCall(C_TooltipInfo.GetUnit, "npc"), true)
end

local function GetProgress(id)
    local data = C_Reputation and SafeCall(C_Reputation.GetFactionDataByID, id)
    if not data then return nil end
    local result = { name = data.name, color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[data.reaction] }
    local friendship = C_GossipInfo and SafeCall(C_GossipInfo.GetFriendshipReputation, id)
    if friendship and friendship.friendshipFactionID and friendship.friendshipFactionID > 0 then
        result.label = friendship.reaction
        result.color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[5]
        result.minimum = friendship.reactionThreshold
        result.maximum = friendship.nextThreshold
        result.value = friendship.standing
        result.capped = not friendship.nextThreshold
    elseif C_Reputation.IsMajorFaction and SafeCall(C_Reputation.IsMajorFaction, id) then
        local major = C_MajorFactions and SafeCall(C_MajorFactions.GetMajorFactionData, id)
        if not major then return nil end
        result.label = (RENOWN_LEVEL_LABEL or "Renown %d"):format(major.renownLevel or 0)
        result.minimum, result.maximum, result.value = 0, major.renownLevelThreshold, major.renownReputationEarned
        result.capped = SafeCall(C_MajorFactions.HasMaximumRenown, id)
        result.color = BLUE_FONT_COLOR
    else
        result.label = SafeCall(GetText, "FACTION_STANDING_LABEL" .. data.reaction, SafeCall(UnitSex, "player"))
            or _G["FACTION_STANDING_LABEL" .. data.reaction]
        result.minimum, result.maximum, result.value = data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
        result.capped = data.reaction == (MAX_REPUTATION_REACTION or 8)
    end
    -- Match the reputation tab: capped reputations display a full bar.
    if result.capped then
        result.minimum, result.maximum, result.value = 0, 1, 1
    elseif type(result.minimum) ~= "number" or type(result.maximum) ~= "number" or type(result.value) ~= "number"
        or result.maximum <= result.minimum then
        return nil
    end
    result.value = math.max(0, math.min(result.maximum - result.minimum, result.value - result.minimum))
    result.maximum = result.maximum - result.minimum
    return result
end

local function HideTooltip()
    if bar and GameTooltip and GameTooltip:IsOwned(bar) then GameTooltip:Hide() end
end

local function ShowTooltip()
    if not bar or not bar.progress or not GameTooltip then return end
    local progress = bar.progress
    GameTooltip:SetOwner(bar, "ANCHOR_TOP")
    GameTooltip:SetText(progress.name, 1, 0.82, 0)
    GameTooltip:AddLine(progress.label, 1, 1, 1)
    if not progress.capped then
        local formatNumber = BreakUpLargeNumbers or tostring
        GameTooltip:AddLine(formatNumber(progress.value) .. " / " .. formatNumber(progress.maximum), 1, 1, 1)
    end
    GameTooltip:Show()
end

local function EnsureBar()
    if bar then return bar end
    if not MerchantFrame or not MerchantFrameTab2 then return nil end
    bar = CreateFrame("StatusBar", "ZoidsToolsVendorReputationBar", MerchantFrame, "ReputationBarTemplate")
    bar:SetHeight(13)
    bar:SetPoint("LEFT", MerchantFrameTab2, "RIGHT", 8, 0)
    bar:SetPoint("RIGHT", MerchantFrame, "RIGHT", -8, 0)
    -- Stretch the native reputation border to fill the space after Buyback.
    bar.LeftTexture:SetWidth(math.max(1, bar:GetWidth() - 39))
    bar:SetScript("OnSizeChanged", function(self, width)
        self.LeftTexture:SetWidth(math.max(1, width - 39))
        self.BarText:SetWidth(math.max(1, width - 8))
    end)
    bar.BarText:SetWidth(math.max(1, bar:GetWidth() - 8))
    bar.BarText:SetWordWrap(false)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", ShowTooltip)
    bar:SetScript("OnLeave", HideTooltip)
    bar:SetScript("OnHide", HideTooltip)
    bar:Hide()
    return bar
end

local function Refresh()
    if not merchantOpen or not MerchantFrame or not MerchantFrame:IsShown() then return end
    factionID = factionID or ResolveVendorFaction()
    local progress = factionID and GetProgress(factionID)
    if not progress then
        if bar then bar.progress = nil; bar:Hide() end
        return
    end
    local widget = EnsureBar()
    if not widget then return end
    widget.progress = progress
    widget:SetMinMaxValues(0, progress.maximum)
    widget:SetValue(progress.value)
    local color = progress.color
    if color and color.GetRGB then
        widget:SetStatusBarColor(color:GetRGB())
    elseif color then
        widget:SetStatusBarColor(color.r, color.g, color.b)
    else
        widget:SetStatusBarColor(0, 0.6, 0.1)
    end
    widget.BarText:SetText(progress.label)
    widget:Show()
    if GameTooltip and GameTooltip:IsOwned(widget) then ShowTooltip() end
end

function ns:InitializeVendorReputation()
    if events then return end
    events = CreateFrame("Frame")
    events:RegisterEvent("MERCHANT_SHOW")
    events:RegisterEvent("MERCHANT_CLOSED")
    events:SetScript("OnEvent", function(_, event)
        if readingFactions then return end
        if event == "MERCHANT_CLOSED" then
            merchantOpen, factionID = false, nil
            generation = generation + 1
            events:UnregisterEvent("UPDATE_FACTION")
            events:UnregisterEvent("MERCHANT_UPDATE")
            if bar then bar.progress = nil; bar:Hide() end
        elseif event == "MERCHANT_SHOW" then
            merchantOpen, factionID = true, nil
            namesRead = false
            if bar then bar.progress = nil; bar:Hide() end
            generation = generation + 1
            local token = generation
            events:RegisterEvent("UPDATE_FACTION")
            events:RegisterEvent("MERCHANT_UPDATE")
            Refresh()
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, function() if token == generation then Refresh() end end)
            end
        else
            Refresh()
        end
    end)
end
