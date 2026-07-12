local _, ns = ...

local eventFrame
local subtitleFrame
local active = false
local blizzardWasRegistered = false
local lineToken = 0
local voiceHandle
local dismissed = false
local ApplyAppearance

local function EnsureDB()
    if not ns.db then return nil end
    ns.db.ui = ns.db.ui or {}
    ns.db.ui.talkingHead = ns.db.ui.talkingHead or {}
    local db = ns.db.ui.talkingHead
    if db.enabled == nil then db.enabled = true end
    db.opacity = tonumber(db.opacity) or 0.72
    if db.background == nil then db.background = true end
    db.fontSize = tonumber(db.fontSize) or 14
    if db.bold == nil then db.bold = false end
    return db
end

local function CreateSubtitleFrame()
    if subtitleFrame then return subtitleFrame end
    local frame = CreateFrame("Frame", "ZoidsToolsTalkingHead", UIParent, "BackdropTemplate")
    frame:SetSize(560, 76)
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)
    frame:SetFrameStrata("FULLSCREEN")
    frame:SetFrameLevel(980)
    frame:EnableMouse(true)
    if frame.SetPropagateMouseMotion then frame:SetPropagateMouseMotion(true) end
    if frame.SetPropagateMouseClicks then frame:SetPropagateMouseClicks(true) end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.008, 0.010, 0.014, 0.78)
    frame:SetBackdropBorderColor(0.90, 0.68, 0.24, 0.28)

    frame.speaker = frame:CreateFontString(nil, "OVERLAY")
    frame.speaker:SetPoint("TOPLEFT", 22, -13)
    frame.speaker:SetPoint("TOPRIGHT", -22, -13)
    frame.speaker:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    frame.speaker:SetTextColor(1, 0.78, 0.22)
    frame.speaker:SetJustifyH("CENTER")

    frame.line = frame:CreateFontString(nil, "OVERLAY")
    frame.line:SetPoint("TOPLEFT", frame.speaker, "BOTTOMLEFT", 0, -7)
    frame.line:SetPoint("TOPRIGHT", frame.speaker, "BOTTOMRIGHT", 0, -7)
    frame.line:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
    frame.line:SetTextColor(0.94, 0.94, 0.92)
    frame.line:SetJustifyH("CENTER")
    frame.line:SetSpacing(2)
    frame.line:SetWordWrap(true)

    frame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and self.SetPropagateMouseClicks then
            -- Keep normal clicks click-through, but reserve this right-click
            -- for dismissing the current Talking Head sequence.
            self:SetPropagateMouseClicks(false)
        end
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if button ~= "RightButton" then return end
        dismissed = true
        lineToken = lineToken + 1
        if voiceHandle and StopSound then StopSound(voiceHandle) end
        voiceHandle = nil
        self:Hide()
        if self.SetPropagateMouseClicks then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function() self:SetPropagateMouseClicks(true) end)
            else
                self:SetPropagateMouseClicks(true)
            end
        end
    end)

    frame:Hide()
    subtitleFrame = frame
    return frame
end

ApplyAppearance = function()
    local db = EnsureDB()
    local frame = subtitleFrame
    if not db or not frame then return end
    local size = math.max(11, math.min(24, db.fontSize or 14))
    local flags = db.bold and "OUTLINE" or ""
    frame.speaker:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", math.max(11, size - 1), flags)
    frame.line:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, flags)
    if frame:IsShown() then
        frame:SetHeight(math.max(68, (frame.line:GetStringHeight() or 20) + 51))
    end
    if db.background then
        frame:SetBackdropColor(0.008, 0.010, 0.014, 0.78)
        frame:SetBackdropBorderColor(0.90, 0.68, 0.24, 0.28)
    else
        frame:SetBackdropColor(0, 0, 0, 0)
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

local function FadeOut(token)
    if token and token ~= lineToken then return end
    local frame = subtitleFrame
    if not frame or not frame:IsShown() then return end
    if UIFrameFadeOut then
        UIFrameFadeOut(frame, 0.35, frame:GetAlpha(), 0)
        if C_Timer and C_Timer.After then
            C_Timer.After(0.36, function()
                if not token or token == lineToken then frame:Hide() end
            end)
        end
    else
        frame:Hide()
    end
end

local function ShowLine(name, text, duration)
    if type(text) ~= "string" or text == "" then return end
    local db = EnsureDB()
    local frame = CreateSubtitleFrame()
    ApplyAppearance()
    lineToken = lineToken + 1
    local token = lineToken
    frame.speaker:SetText(type(name) == "string" and name or "")
    frame.speaker:SetShown(type(name) == "string" and name ~= "")
    frame.line:SetText(text)
    local lineHeight = frame.line:GetStringHeight() or 20
    frame:SetHeight(math.max(68, lineHeight + 51))
    frame:SetAlpha(db and db.opacity or 0.72)
    frame:Show()
    if UIFrameFadeIn then UIFrameFadeIn(frame, 0.18, 0, db and db.opacity or 0.72) end
    if C_Timer and C_Timer.After then
        C_Timer.After(math.max(2, tonumber(duration) or 5) + 0.5, function() FadeOut(token) end)
    end
end

local function OnTalkingHeadRequested()
    if not C_TalkingHead or not C_TalkingHead.GetCurrentLineInfo then return end
    local ok, displayInfo, cameraID, soundKit, duration, lineNumber, numLines, name, text, isNewTalkingHead = pcall(C_TalkingHead.GetCurrentLineInfo)
    if not ok then return end

    if isNewTalkingHead then dismissed = false end
    if dismissed then return end

    if voiceHandle and StopSound then StopSound(voiceHandle) end
    voiceHandle = nil
    if soundKit and PlaySound then
        local played, handle = PlaySound(soundKit, "Talking Head", true, true)
        if played then voiceHandle = handle end
    end
    ShowLine(name, text, duration)
end

local function PlumberOwnsTalkingHead()
    return type(_G.PlumberDB) == "table" and _G.PlumberDB.TalkingHead_MasterSwitch == true
end

local function Activate()
    if active or PlumberOwnsTalkingHead() then return end
    if not _G.TalkingHeadFrame and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_TalkingHeadUI")
    end
    local blizzard = _G.TalkingHeadFrame
    if not blizzard or not blizzard.IsEventRegistered then return end
    blizzardWasRegistered = blizzard:IsEventRegistered("TALKINGHEAD_REQUESTED") == true
    if not blizzardWasRegistered then return end
    blizzard:UnregisterEvent("TALKINGHEAD_REQUESTED")
    eventFrame:RegisterEvent("TALKINGHEAD_REQUESTED")
    eventFrame:RegisterEvent("TALKINGHEAD_CLOSE")
    active = true
end

local function Deactivate()
    if not active then return end
    eventFrame:UnregisterEvent("TALKINGHEAD_REQUESTED")
    eventFrame:UnregisterEvent("TALKINGHEAD_CLOSE")
    if blizzardWasRegistered and _G.TalkingHeadFrame then
        _G.TalkingHeadFrame:RegisterEvent("TALKINGHEAD_REQUESTED")
    end
    blizzardWasRegistered = false
    active = false
    lineToken = lineToken + 1
    dismissed = false
    if subtitleFrame then subtitleFrame:Hide() end
end

function ns:IsSubtleTalkingHeadEnabled()
    local db = EnsureDB()
    return db and db.enabled == true
end

function ns:SetSubtleTalkingHeadEnabled(value)
    local db = EnsureDB()
    if not db then return end
    db.enabled = value == true
    if db.enabled then Activate() else Deactivate() end
end

function ns:GetSubtleTalkingHeadOpacity()
    local db = EnsureDB()
    return db and db.opacity or 0.72
end

function ns:SetSubtleTalkingHeadOpacity(value)
    local db = EnsureDB()
    if not db then return end
    db.opacity = math.max(0.35, math.min(1, tonumber(value) or 0.72))
    if subtitleFrame and subtitleFrame:IsShown() then subtitleFrame:SetAlpha(db.opacity) end
end

function ns:GetSubtleTalkingHeadBackground()
    local db = EnsureDB()
    return db and db.background == true
end

function ns:SetSubtleTalkingHeadBackground(value)
    local db = EnsureDB()
    if not db then return end
    db.background = value == true
    ApplyAppearance()
end

function ns:GetSubtleTalkingHeadFontSize()
    local db = EnsureDB()
    return db and db.fontSize or 14
end

function ns:SetSubtleTalkingHeadFontSize(value)
    local db = EnsureDB()
    if not db then return end
    db.fontSize = math.max(11, math.min(24, tonumber(value) or 14))
    ApplyAppearance()
end

function ns:GetSubtleTalkingHeadBold()
    local db = EnsureDB()
    return db and db.bold == true
end

function ns:SetSubtleTalkingHeadBold(value)
    local db = EnsureDB()
    if not db then return end
    db.bold = value == true
    ApplyAppearance()
end

function ns:PreviewSubtleTalkingHead()
    ShowLine("ZoidsTools", "A quieter, click-through Talking Head preview.", 4)
end

function ns:InitializeSubtleTalkingHead()
    EnsureDB()
    CreateSubtitleFrame()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function(_, event)
            if event == "TALKINGHEAD_REQUESTED" then OnTalkingHeadRequested()
            elseif event == "TALKINGHEAD_CLOSE" then
                dismissed = false
                FadeOut()
            end
        end)
    end
    local db = EnsureDB()
    if db and db.enabled then Activate() end
end
