local _, ns = ...

local BANNER_FRAME_NAME = "ZoidsToolsCombatBanner"
local BANNER_WIDTH = 280
local BANNER_HEIGHT = 44
local PREVIEW_SECONDS = 4
local COMBAT_ALERT_SECONDS = 4
local COMBAT_ENDED_SECONDS = 4

local eventFrame
local bannerFrame
local previewToken = 0
local combatAlertToken = 0
local combatAlertVisible = false
local combatEndedToken = 0
local combatEndedVisible = false

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.combat = ns.db.combat or {}
    ns.db.combat.combatBanner = ns.db.combat.combatBanner or {}

    local db = ns.db.combat.combatBanner

    if db.enabled == nil then
        db.enabled = false
    end

    if db.persistent == nil then
        db.persistent = false
    end

    if db.locked == nil then
        db.locked = false
    end

    db.point = db.point or "CENTER"
    db.relativePoint = db.relativePoint or "CENTER"
    db.x = tonumber(db.x) or 0
    db.y = tonumber(db.y) or 220

    return db
end

local function IsPlayerInCombat()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end

    return UnitAffectingCombat and UnitAffectingCombat("player") == true
end

local function SaveBannerPosition(frame)
    local db = EnsureDB()

    if not db or not frame then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)

    if point then
        db.point = point
        db.relativePoint = relativePoint or point
        db.x = x or 0
        db.y = y or 0
    end
end

local function RestoreBannerPosition(frame)
    local db = EnsureDB()

    if not db or not frame then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or db.point or "CENTER", db.x or 0, db.y or 220)
end

local function ResetBannerPosition(frame)
    local db = EnsureDB()

    if not db then
        return
    end

    db.point = "CENTER"
    db.relativePoint = "CENTER"
    db.x = 0
    db.y = 220

    RestoreBannerPosition(frame or bannerFrame)
end

local function UpdateBannerInteractivity()
    local db = EnsureDB()
    local frame = bannerFrame

    if not db or not frame then
        return
    end

    frame:EnableMouse(db.locked ~= true)
end

local function ApplyBannerStyle(state)
    local frame = bannerFrame

    if not frame then
        return
    end

    if state == "ended" then
        frame:SetBackdropColor(0.015, 0.075, 0.035, 0.60)
        frame:SetBackdropBorderColor(0.30, 1, 0.45, 0.50)

        if frame.glow then
            frame.glow:SetColorTexture(0.10, 1, 0.28, 0.045)
        end

        if frame.title then
            frame.title:SetText("COMBAT ENDED")
            frame.title:SetTextColor(0.58, 1, 0.58)
        end
    else
        frame:SetBackdropColor(0.02, 0.018, 0.014, 0.58)
        frame:SetBackdropBorderColor(1, 0.72, 0.20, 0.48)

        if frame.glow then
            frame.glow:SetColorTexture(1, 0.62, 0.08, 0.035)
        end

        if frame.title then
            frame.title:SetText("IN COMBAT")
            frame.title:SetTextColor(1, 0.86, 0.24)
        end
    end
end

local function UpdateBannerVisibility()
    local db = EnsureDB()
    local frame = bannerFrame

    if not db or not frame or db.enabled ~= true then
        if frame then
            frame:Hide()
        end

        return
    end

    if previewToken > 0 then
        ApplyBannerStyle("combat")
        frame:Show()
    elseif IsPlayerInCombat() and (db.persistent == true or combatAlertVisible == true) then
        ApplyBannerStyle("combat")
        frame:Show()
    elseif combatEndedVisible == true then
        ApplyBannerStyle("ended")
        frame:Show()
    else
        frame:Hide()
    end
end

local function CreateBannerFrame()
    if bannerFrame then
        return bannerFrame
    end

    local frame = CreateFrame("Frame", BANNER_FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(BANNER_WIDTH, BANNER_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(30)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.02, 0.018, 0.014, 0.58)
    frame:SetBackdropBorderColor(1, 0.72, 0.20, 0.48)

    frame.glow = frame:CreateTexture(nil, "BORDER")
    frame.glow:SetPoint("TOPLEFT", 5, -5)
    frame.glow:SetPoint("BOTTOMRIGHT", -5, 5)
    frame.glow:SetColorTexture(1, 0.62, 0.08, 0.035)

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetPoint("CENTER", frame, "CENTER", 0, 1)
    frame.title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    frame.title:SetTextColor(1, 0.86, 0.24)
    frame.title:SetShadowColor(0, 0, 0, 0.95)
    frame.title:SetShadowOffset(1, -1)
    frame.title:SetText("IN COMBAT")

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveBannerPosition(self)
    end)

    frame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and IsControlKeyDown and IsControlKeyDown() then
            ResetBannerPosition(self)
        end
    end)

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("ZoidsTools Combat Banner")
        GameTooltip:AddLine("Shows briefly when combat starts and ends.", 1, 1, 1, true)
        GameTooltip:AddLine("Can be set to remain visible for the full combat.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Lock it from the Combat page to make it click-through.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Drag to move. Ctrl-right-click to reset position.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    RestoreBannerPosition(frame)
    frame:Hide()
    bannerFrame = frame
    UpdateBannerInteractivity()

    return frame
end

function ns:GetCombatBannerEnabled()
    local db = EnsureDB()

    return db and db.enabled == true
end

function ns:SetCombatBannerEnabled(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.enabled = value == true
    CreateBannerFrame()

    if db.enabled and not IsPlayerInCombat() then
        self:PreviewCombatBanner()
    else
        UpdateBannerVisibility()
    end
end

function ns:GetCombatBannerPersistent()
    local db = EnsureDB()

    return db and db.persistent == true
end

function ns:SetCombatBannerPersistent(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.persistent = value == true

    if db.enabled == true and not IsPlayerInCombat() then
        self:PreviewCombatBanner()
    else
        UpdateBannerVisibility()
    end
end

function ns:GetCombatBannerLocked()
    local db = EnsureDB()

    return db and db.locked == true
end

function ns:SetCombatBannerLocked(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.locked = value == true
    CreateBannerFrame()
    UpdateBannerInteractivity()
    UpdateBannerVisibility()
end

function ns:PreviewCombatBanner()
    if not EnsureDB() then
        return
    end

    CreateBannerFrame()
    previewToken = previewToken + 1

    local token = previewToken
    UpdateBannerVisibility()

    if C_Timer and C_Timer.After then
        C_Timer.After(PREVIEW_SECONDS, function()
            if previewToken == token then
                previewToken = 0
                UpdateBannerVisibility()
            end
        end)
    end
end

local function StartCombatAlert()
    local db = EnsureDB()

    combatAlertToken = combatAlertToken + 1
    combatEndedToken = combatEndedToken + 1
    combatEndedVisible = false

    if not db or db.enabled ~= true then
        combatAlertVisible = false
        UpdateBannerVisibility()
        return
    end

    if db.persistent == true then
        combatAlertVisible = false
        UpdateBannerVisibility()
        return
    end

    combatAlertVisible = true
    local token = combatAlertToken

    UpdateBannerVisibility()

    if C_Timer and C_Timer.After then
        C_Timer.After(COMBAT_ALERT_SECONDS, function()
            if combatAlertToken == token then
                combatAlertVisible = false
                UpdateBannerVisibility()
            end
        end)
    end
end

local function StartCombatEndedAlert()
    local db = EnsureDB()

    combatAlertToken = combatAlertToken + 1
    combatAlertVisible = false

    if not db or db.enabled ~= true then
        combatEndedVisible = false
        UpdateBannerVisibility()
        return
    end

    combatEndedToken = combatEndedToken + 1
    combatEndedVisible = true

    local token = combatEndedToken

    UpdateBannerVisibility()

    if C_Timer and C_Timer.After then
        C_Timer.After(COMBAT_ENDED_SECONDS, function()
            if combatEndedToken == token then
                combatEndedVisible = false
                UpdateBannerVisibility()
            end
        end)
    end
end

function ns:ResetCombatBannerPosition()
    ResetBannerPosition(CreateBannerFrame())
end

function ns:RefreshCombatBanner()
    CreateBannerFrame()
    UpdateBannerInteractivity()
    UpdateBannerVisibility()
end

function ns:InitializeCombatBanner()
    EnsureDB()
    CreateBannerFrame()
    UpdateBannerVisibility()

    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            StartCombatAlert()
        elseif event == "PLAYER_REGEN_ENABLED" then
            StartCombatEndedAlert()
        elseif IsPlayerInCombat() then
            StartCombatAlert()
        else
            UpdateBannerVisibility()
        end
    end)
end
