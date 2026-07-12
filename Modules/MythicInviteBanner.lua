local _, ns = ...

local FRAME_NAME = "ZoidsToolsMythicInviteBanner"
local DEFAULT_DUNGEON = "Mythic+ Dungeon"

-- Challenge-mode map IDs are stable identifiers; spell IDs are the matching
-- account-wide dungeon teleports. New dungeons can be added here without
-- changing the invitation or UI code.
local PORTAL_SPELLS = {
    [2] = 131204, [56] = 131205, [57] = 131225, [58] = 131206,
    [59] = 131228, [60] = 131222, [76] = 131232, [77] = 131231, [78] = 131229,
    [161] = 159898, [163] = 159895, [164] = 159897, [165] = 159899,
    [166] = 159900, [167] = 159902, [168] = 159901, [169] = 159896,
    [198] = 424163, [199] = 424153, [200] = 393764, [206] = 410078,
    [210] = 393766, [227] = 373262, [234] = 373262, [239] = 1254551,
    [244] = 424187, [245] = 410071, [248] = 424167, [249] = 1286831,
    [250] = 1286828, [251] = 410074, [353] = 445418, [369] = 373274,
    [370] = 373274, [375] = 354464, [376] = 354462, [377] = 354468,
    [378] = 354465, [379] = 354463, [380] = 354469, [381] = 354466,
    [382] = 354467, [399] = 393256, [400] = 393262, [401] = 393279,
    [402] = 393273, [403] = 393222, [404] = 393276, [405] = 393267,
    [406] = 393283, [438] = 410080, [456] = 424142, [499] = 445444,
    [500] = 445443, [501] = 445269, [502] = 445416, [503] = 445417,
    [504] = 445441, [505] = 445414, [506] = 445440, [507] = 445424,
    [525] = 1216786, [542] = 1237215, [556] = 1254555, [557] = 1254400,
    [558] = 1254572, [559] = 1254563, [560] = 1254559, [584] = 1286801,
    [585] = 1286804, [586] = 1286807, [587] = 1286809, [588] = 1286812,
}

local eventFrame
local banner
local pendingPortalSpell
local lastInvite

local function EnsureDB()
    if not ns.db then return nil end
    ns.db.mythicInviteBanner = ns.db.mythicInviteBanner or {}
    if ns.db.mythicInviteBanner.enabled == nil then
        ns.db.mythicInviteBanner.enabled = true
    end
    return ns.db.mythicInviteBanner
end

local function SafeValue(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function NormalizeName(value)
    value = SafeValue(value)
    if type(value) ~= "string" then return nil end
    return value:lower():gsub("[%s%p]", "")
end

local function SpellIsKnown(spellID)
    if not spellID then return false end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    end
    if IsPlayerSpell then return IsPlayerSpell(spellID) end
    if IsSpellKnown then return IsSpellKnown(spellID) end
    return false
end

local function ReadSpellInfo(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        return C_Spell.GetSpellInfo(spellID)
    end
    local name, _, icon = _G.GetSpellInfo and _G.GetSpellInfo(spellID)
    return name and { name = name, iconID = icon } or nil
end

local function FindPortalSpell(activityName)
    if not C_ChallengeMode or not C_ChallengeMode.GetMapTable then return nil end
    local wanted = NormalizeName(activityName)
    if not wanted then return nil end

    local mapIDs = C_ChallengeMode.GetMapTable() or {}
    for _, mapID in ipairs(mapIDs) do
        local spellID = PORTAL_SPELLS[mapID]
        if spellID then
            local mapName = C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(mapID)
            local normalized = NormalizeName(mapName)
            if normalized and (normalized == wanted or normalized:find(wanted, 1, true) or wanted:find(normalized, 1, true)) then
                return spellID
            end
        end
    end
end

local function StyleButton(button, r, g, b)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(r * 0.18, g * 0.18, b * 0.18, 0.96)
    button:SetBackdropBorderColor(r, g, b, 0.82)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(r * 0.32, g * 0.32, b * 0.32, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(r * 0.18, g * 0.18, b * 0.18, 0.96)
    end)
end

local function CreateBanner()
    if banner then return banner end

    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(420, 142)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -4)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(80)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 11,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.018, 0.022, 0.032, 0.96)
    frame:SetBackdropBorderColor(0.92, 0.68, 0.20, 0.94)

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 9, -7)
    accent:SetPoint("TOPRIGHT", -9, -7)
    accent:SetHeight(2)
    accent:SetColorTexture(0.95, 0.58, 0.12, 0.9)

    local eyebrow = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    eyebrow:SetPoint("TOP", 0, -17)
    eyebrow:SetText("MYTHIC+ GROUP INVITATION")
    eyebrow:SetTextColor(0.95, 0.69, 0.24)

    frame.dungeonName = frame:CreateFontString(nil, "OVERLAY")
    frame.dungeonName:SetPoint("TOPLEFT", 20, -37)
    frame.dungeonName:SetPoint("TOPRIGHT", -20, -37)
    frame.dungeonName:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    frame.dungeonName:SetTextColor(1, 1, 1)
    frame.dungeonName:SetJustifyH("CENTER")
    frame.dungeonName:SetWordWrap(false)

    local teleport = CreateFrame("Button", FRAME_NAME .. "Teleport", frame, "InsecureActionButtonTemplate,BackdropTemplate")
    teleport:SetSize(244, 42)
    -- Protected frames may only be anchored to other frames, not FontStrings.
    teleport:SetPoint("TOP", frame, "TOP", 0, -67)
    teleport:RegisterForClicks("AnyDown", "AnyUp")
    StyleButton(teleport, 0.24, 0.78, 1)
    teleport.icon = teleport:CreateTexture(nil, "ARTWORK")
    teleport.icon:SetSize(30, 30)
    teleport.icon:SetPoint("LEFT", 8, 0)
    teleport.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    teleport.text = teleport:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    teleport.text:SetPoint("LEFT", teleport.icon, "RIGHT", 8, 0)
    teleport.text:SetPoint("RIGHT", -8, 0)
    teleport.text:SetText("TELEPORT TO DUNGEON")
    teleport.text:SetTextColor(0.90, 0.97, 1)
    frame.teleport = teleport

    frame.unavailable = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.unavailable:SetPoint("CENTER", teleport, "CENTER", 0, 0)
    frame.unavailable:SetTextColor(0.65, 0.68, 0.74)

    local close = CreateFrame("Button", nil, frame, "BackdropTemplate")
    close:SetSize(62, 23)
    close:SetPoint("BOTTOMRIGHT", -10, 8)
    StyleButton(close, 0.54, 0.56, 0.62)
    close.text = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    close.text:SetPoint("CENTER", 0, 0)
    close.text:SetText("Close")
    close.text:SetTextColor(0.92, 0.92, 0.94)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:Hide()
    banner = frame
    return frame
end

local function ConfigurePortalButton(spellID)
    local frame = CreateBanner()
    local button = frame.teleport
    button:Hide()
    frame.unavailable:Hide()
    pendingPortalSpell = nil

    if not spellID or not SpellIsKnown(spellID) then
        frame.unavailable:SetText("Dungeon teleport not learned")
        frame.unavailable:Show()
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingPortalSpell = spellID
        frame.unavailable:SetText("Teleport available after combat")
        frame.unavailable:Show()
        return
    end

    local info = ReadSpellInfo(spellID)

    if not info then
        frame.unavailable:SetText("Dungeon teleport unavailable")
        frame.unavailable:Show()
        return
    end

    -- Match Blizzard's action-button behavior on both press and release. The
    -- player/self-cast attributes are required by the current teleport-button
    -- pattern used by Blizzard-compatible portal addons.
    button:SetAttribute("type1", "spell")
    button:SetAttribute("spell1", spellID)
    button:SetAttribute("unit", "player")
    button:SetAttribute("checkselfcast", true)
    button.icon:SetTexture(info and info.iconID or 237509)
    button:Show()
end

local function ShowInvite(dungeonName, spellID)
    local db = EnsureDB()
    if not db or db.enabled ~= true then return end

    local frame = CreateBanner()
    lastInvite = { dungeonName = dungeonName or DEFAULT_DUNGEON, spellID = spellID }
    frame.dungeonName:SetText(lastInvite.dungeonName)
    ConfigurePortalButton(spellID)
    frame:Show()
end

local function ReadInvite(searchResultID, groupName)
    if not C_LFGList or not C_LFGList.GetSearchResultInfo then return end
    local ok, result = pcall(C_LFGList.GetSearchResultInfo, searchResultID)
    if not ok or type(result) ~= "table" then return end

    local activityIDs = SafeValue(result.activityIDs)
    local activityID = type(activityIDs) == "table" and SafeValue(activityIDs[1]) or SafeValue(result.activityID)
    if not activityID or not C_LFGList.GetActivityInfoTable then return end

    local activityOK, activity = pcall(C_LFGList.GetActivityInfoTable, activityID)
    if not activityOK or type(activity) ~= "table" then return end

    local dungeonName = SafeValue(activity.fullName) or SafeValue(activity.shortName) or SafeValue(groupName)
    if type(dungeonName) ~= "string" or dungeonName == "" then return end

    -- A portal match is also our guard against showing this for raids, delves,
    -- ordinary quest groups, or unrelated Premade Groups invitations.
    local spellID = FindPortalSpell(dungeonName)
    if spellID then ShowInvite(dungeonName, spellID) end
end

function ns:IsMythicInviteBannerEnabled()
    local db = EnsureDB()
    return db and db.enabled == true
end

function ns:SetMythicInviteBannerEnabled(value)
    local db = EnsureDB()
    if not db then return end
    db.enabled = value == true
    if not db.enabled and banner then banner:Hide() end
end

function ns:PreviewMythicInviteBanner()
    if C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo then
        for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
            local spellID = PORTAL_SPELLS[mapID]
            if spellID and SpellIsKnown(spellID) then
                local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
                if type(mapName) == "string" then
                    ShowInvite(mapName, spellID)
                    return
                end
            end
        end
    end
    ShowInvite("Algeth'ar Academy", nil)
end

function ns:InitializeMythicInviteBanner()
    EnsureDB()
    CreateBanner()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:SetScript("OnEvent", function(_, event, searchResultID, newStatus, oldStatus, groupName)
        if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" and SafeValue(newStatus) == "invited" then
            ReadInvite(searchResultID, groupName)
        elseif event == "PLAYER_REGEN_ENABLED" and pendingPortalSpell then
            ConfigurePortalButton(pendingPortalSpell)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit = searchResultID
            local spellID = oldStatus

            if unit == "player" and lastInvite and spellID == lastInvite.spellID and banner then
                banner:Hide()
            end
        end
    end)
end
