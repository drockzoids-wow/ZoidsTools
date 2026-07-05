local _, ns = ...

local eventFrame
local hooksInstalled = false

local DEFAULT_ENABLED = true
local DEFAULT_SHORTEN = true
local DEFAULT_FONT = "default"
local DEFAULT_SIZE = 12
local DEFAULT_OUTLINE = "default"
local DEFAULT_BOLD = false
local DEFAULT_USE_CUSTOM_COLOR = false
local DEFAULT_COLOR_R = 1
local DEFAULT_COLOR_G = 1
local DEFAULT_COLOR_B = 1
local DEFAULT_RANGE_TINT_ENABLED = true
local RANGE_TINT_R = 1
local RANGE_TINT_G = 0.05
local RANGE_TINT_B = 0.05
local RANGE_TINT_A = 0.42

local buttonPrefixes = {
    { prefix = "ActionButton", count = 12 },
    { prefix = "MultiBarBottomLeftButton", count = 12 },
    { prefix = "MultiBarBottomRightButton", count = 12 },
    { prefix = "MultiBarRightButton", count = 12 },
    { prefix = "MultiBarLeftButton", count = 12 },
    { prefix = "MultiBar5Button", count = 12 },
    { prefix = "MultiBar6Button", count = 12 },
    { prefix = "MultiBar7Button", count = 12 },
    { prefix = "OverrideActionBarButton", count = 6 },
    { prefix = "VehicleMenuBarActionButton", count = 6 },
    { prefix = "ExtraActionButton", count = 1 },
    { prefix = "PetActionButton", count = 10 },
    { prefix = "StanceButton", count = 10 },
    { prefix = "PossessButton", count = 2 },
}

local fontChoices = {
    default = {
        label = "Default",
    },
    friz = {
        label = "Friz Quadrata",
        path = function()
            return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        end,
    },
    arial = {
        label = "Arial Narrow",
        path = function()
            return "Fonts\\ARIALN.TTF"
        end,
    },
    morpheus = {
        label = "Morpheus",
        path = function()
            return "Fonts\\MORPHEUS.TTF"
        end,
    },
    skurri = {
        label = "Skurri",
        path = function()
            return "Fonts\\SKURRI.TTF"
        end,
    },
    damage = {
        label = "Damage",
        path = function()
            return DAMAGE_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        end,
    },
}

local outlineChoices = {
    default = {
        label = "Default",
    },
    none = {
        label = "None",
    },
    outline = {
        label = "Outline",
    },
    thick = {
        label = "Thick Outline",
    },
}

local function NormalizeOutline(value)
    if value == "OUTLINE" or value == "outline" then
        return "outline"
    elseif value == "THICKOUTLINE" or value == "thick" then
        return "thick"
    elseif value == "" or value == "none" then
        return "none"
    end

    return DEFAULT_OUTLINE
end

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function EnsureCombatDB()
    if not ns.db then
        return nil
    end

    ns.db.combat = ns.db.combat or {}
    ns.db.combat.keybindText = ns.db.combat.keybindText or {}

    if ns.db.combat.actionButtonRangeTint == nil then
        ns.db.combat.actionButtonRangeTint = DEFAULT_RANGE_TINT_ENABLED
    end

    local db = ns.db.combat.keybindText

    if db.enabled == nil then
        db.enabled = DEFAULT_ENABLED
    end

    if db.shorten == nil then
        db.shorten = DEFAULT_SHORTEN
    end

    if not fontChoices[db.font] then
        db.font = DEFAULT_FONT
    end

    if db.fontSize == nil then
        db.fontSize = DEFAULT_SIZE
    end

    if db.outline == nil then
        db.outline = DEFAULT_OUTLINE
    else
        db.outline = NormalizeOutline(db.outline)
    end

    if db.bold == nil then
        db.bold = DEFAULT_BOLD
    end

    if db.useCustomColor == nil then
        db.useCustomColor = DEFAULT_USE_CUSTOM_COLOR
    end

    if type(db.color) ~= "table" then
        db.color = {
            r = DEFAULT_COLOR_R,
            g = DEFAULT_COLOR_G,
            b = DEFAULT_COLOR_B,
        }
    end

    return db
end

local function IsRangeTintEnabled()
    EnsureCombatDB()

    return ns.db and ns.db.combat and ns.db.combat.actionButtonRangeTint == true
end

local function IsOutOfRangeValue(inRange)
    return inRange == false or inRange == 0
end

local function ClampColor(value)
    value = tonumber(value) or 1

    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end

    return value
end

local function ClampFontSize(value)
    value = tonumber(value) or DEFAULT_SIZE

    if value < 8 then
        return 8
    elseif value > 24 then
        return 24
    end

    return math.floor(value + 0.5)
end

local function Trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

local function SplitKeybind(text)
    local parts = {}

    for part in string.gmatch(text, "[^-]+") do
        parts[#parts + 1] = Trim(part)
    end

    return parts
end

local function ShortenKeyPart(part)
    local compact = Trim(part):gsub("%s+", "")
    local upper = string.upper(compact)

    if upper == "" then
        return ""
    elseif upper == "SHIFT" or upper == "S" then
        return "S"
    elseif upper == "CTRL" or upper == "CONTROL" or upper == "C" then
        return "C"
    elseif upper == "ALT" or upper == "A" then
        return "A"
    elseif upper == "META" or upper == "COMMAND" or upper == "CMD" then
        return "M"
    end

    local mouseNumber = upper:match("^MOUSEBUTTON(%d+)$")
        or upper:match("^MOUSE(%d+)$")
        or upper:match("^BUTTON(%d+)$")

    if mouseNumber then
        return "M" .. mouseNumber
    elseif upper == "LEFTMOUSE" or upper == "LEFTBUTTON" then
        return "M1"
    elseif upper == "RIGHTMOUSE" or upper == "RIGHTBUTTON" then
        return "M2"
    elseif upper == "MIDDLEMOUSE" or upper == "MIDDLEBUTTON" then
        return "M3"
    elseif upper == "MOUSEWHEELUP" or upper == "MWHEELUP" or upper == "WHEELUP" then
        return "MWU"
    elseif upper == "MOUSEWHEELDOWN" or upper == "MWHEELDOWN" or upper == "WHEELDOWN" then
        return "MWD"
    elseif upper == "SPACE" or upper == "SPACEBAR" then
        return "SP"
    elseif upper == "PAGEUP" then
        return "PU"
    elseif upper == "PAGEDOWN" then
        return "PD"
    elseif upper == "INSERT" then
        return "INS"
    elseif upper == "DELETE" or upper == "DEL" then
        return "DEL"
    elseif upper == "BACKSPACE" then
        return "BS"
    elseif upper == "ENTER" or upper == "RETURN" then
        return "ENT"
    elseif upper == "ESCAPE" then
        return "ESC"
    elseif upper == "UP" or upper == "UPARROW" then
        return "UP"
    elseif upper == "DOWN" or upper == "DOWNARROW" then
        return "DN"
    elseif upper == "LEFT" or upper == "LEFTARROW" then
        return "LT"
    elseif upper == "RIGHT" or upper == "RIGHTARROW" then
        return "RT"
    end

    local numPadKey = upper:match("^NUMPAD(.+)$")

    if numPadKey then
        return "N" .. numPadKey
    end

    return upper
end

local function ShortenKeybind(text)
    text = Trim(text)

    if text == "" then
        return text
    end

    text = text:gsub("^KEY_", "")
    text = text:gsub("%s*%-%s*", "-")

    local parts = SplitKeybind(text)
    local result = ""

    for _, part in ipairs(parts) do
        result = result .. ShortenKeyPart(part)
    end

    return result ~= "" and result or text
end

local function GetHotkey(button)
    if not button then
        return nil
    end

    if button.HotKey then
        return button.HotKey
    end

    local name = button.GetName and button:GetName()

    if name then
        return _G[name .. "HotKey"]
    end

    return nil
end

local function GetButtonIcon(button)
    if not button then
        return nil
    end

    if button.icon then
        return button.icon
    elseif button.Icon then
        return button.Icon
    end

    local name = button.GetName and button:GetName()

    if name then
        return _G[name .. "Icon"]
    end

    return nil
end

local function EnsureRangeOverlay(button)
    if not button then
        return nil
    end

    if button.ZTRangeOverlay then
        return button.ZTRangeOverlay
    end

    if InCombatLockdown and InCombatLockdown() then
        return nil
    end

    local icon = GetButtonIcon(button)

    if not icon then
        return nil
    end

    local overlay = button:CreateTexture(nil, "OVERLAY", nil, 7)
    overlay:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    overlay:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    overlay:SetColorTexture(RANGE_TINT_R, RANGE_TINT_G, RANGE_TINT_B, RANGE_TINT_A)
    overlay:SetBlendMode("BLEND")
    overlay:Hide()

    button.ZTRangeOverlay = overlay

    return overlay
end

local function SetRangeOverlay(button, show)
    local overlay = EnsureRangeOverlay(button)

    if not overlay then
        return
    end

    local shouldShow = show == true and IsRangeTintEnabled()

    if overlay.ZTVisible == shouldShow then
        return
    end

    overlay.ZTVisible = shouldShow

    if shouldShow then
        if overlay.ZTColorApplied ~= true then
            overlay:SetColorTexture(RANGE_TINT_R, RANGE_TINT_G, RANGE_TINT_B, RANGE_TINT_A)
            overlay.ZTColorApplied = true
        end

        overlay:Show()
    else
        overlay:Hide()
    end
end

local function GetActionSlot(button)
    if not button then
        return nil
    end

    if button.action then
        return button.action
    end

    if type(button.GetAttribute) == "function" then
        return button:GetAttribute("action")
    end

    return nil
end

local function IsActionButtonOutOfRange(button)
    local action = GetActionSlot(button)

    if not action or not HasAction or not HasAction(action) then
        return false
    end

    if ActionHasRange and not ActionHasRange(action) then
        return false
    end

    if not IsActionInRange then
        return false
    end

    local inRange = IsActionInRange(action)

    return IsOutOfRangeValue(inRange)
end

local function RefreshRangeOverlay(button)
    if not button then
        return
    end

    if not IsRangeTintEnabled() then
        SetRangeOverlay(button, false)
        return
    end

    SetRangeOverlay(button, IsActionButtonOutOfRange(button))
end

local function CaptureOriginalFont(hotkey)
    if hotkey.ZTOriginalFont then
        return hotkey.ZTOriginalFont
    end

    local font, size, outline = hotkey:GetFont()

    hotkey.ZTOriginalFont = {
        font = font,
        size = size,
        outline = outline,
    }

    return hotkey.ZTOriginalFont
end

local function CaptureOriginalColor(hotkey)
    if hotkey.ZTOriginalColor then
        return hotkey.ZTOriginalColor
    end

    local r, g, b, a = hotkey:GetTextColor()

    hotkey.ZTOriginalColor = {
        r = r or 1,
        g = g or 1,
        b = b or 1,
        a = a or 1,
    }

    if type(hotkey.GetShadowColor) == "function" then
        local shadowR, shadowG, shadowB, shadowA = hotkey:GetShadowColor()

        hotkey.ZTOriginalShadowColor = {
            r = shadowR or 0,
            g = shadowG or 0,
            b = shadowB or 0,
            a = shadowA or 1,
        }
    end

    if type(hotkey.GetShadowOffset) == "function" then
        local x, y = hotkey:GetShadowOffset()

        hotkey.ZTOriginalShadowOffset = {
            x = x or 0,
            y = y or 0,
        }
    end

    return hotkey.ZTOriginalColor
end

local function CaptureOriginalText(hotkey, forceCapture)
    local text = hotkey:GetText() or ""

    if forceCapture == true or text ~= hotkey.ZTStyledText then
        hotkey.ZTOriginalText = text
    end

    return hotkey.ZTOriginalText or text
end

local function ResolveFontPath(db, originalFont)
    local choice = fontChoices[db.font or DEFAULT_FONT]

    if choice and choice.path then
        return choice.path()
    end

    return originalFont and originalFont.font
end

local function ResolveOutlineFlag(db, originalFont)
    local outline = NormalizeOutline(db.outline)

    if outline == "outline" then
        return "OUTLINE"
    elseif outline == "thick" then
        return "THICKOUTLINE"
    elseif outline == "none" then
        return ""
    end

    return originalFont and originalFont.outline or ""
end

local function RestoreOriginalColor(hotkey, originalColor)
    if originalColor then
        hotkey:SetTextColor(originalColor.r, originalColor.g, originalColor.b, originalColor.a or 1)
    end

    if type(hotkey.SetShadowColor) == "function" and hotkey.ZTOriginalShadowColor then
        local color = hotkey.ZTOriginalShadowColor
        hotkey:SetShadowColor(color.r, color.g, color.b, color.a or 1)
    end

    if type(hotkey.SetShadowOffset) == "function" and hotkey.ZTOriginalShadowOffset then
        local offset = hotkey.ZTOriginalShadowOffset
        hotkey:SetShadowOffset(offset.x or 0, offset.y or 0)
    end
end

local function ApplyConfiguredColor(hotkey, db, originalColor)
    RestoreOriginalColor(hotkey, originalColor)

    if db.useCustomColor == true and db.color then
        hotkey:SetTextColor(
            ClampColor(db.color.r),
            ClampColor(db.color.g),
            ClampColor(db.color.b),
            1
        )
    end

    if db.bold == true and type(hotkey.SetShadowColor) == "function" and type(hotkey.SetShadowOffset) == "function" then
        hotkey:SetShadowColor(0, 0, 0, 0.95)
        hotkey:SetShadowOffset(1, -1)
    end
end

local function ApplyHotkey(button, forceCapture)
    local hotkey = GetHotkey(button)
    local db = EnsureCombatDB()

    if not hotkey or not db then
        return
    end

    local originalFont = CaptureOriginalFont(hotkey)
    local originalColor = CaptureOriginalColor(hotkey)
    local originalText = CaptureOriginalText(hotkey, forceCapture)

    if db.enabled ~= true then
        if originalFont and originalFont.font then
            hotkey:SetFont(originalFont.font, originalFont.size or DEFAULT_SIZE, originalFont.outline or "")
        end

        RestoreOriginalColor(hotkey, originalColor)
        hotkey:SetText(originalText or "")
        hotkey.ZTStyledText = nil

        return
    end

    local fontPath = ResolveFontPath(db, originalFont)
    local size = ClampFontSize(db.fontSize) + (db.bold == true and 1 or 0)
    local outline = ResolveOutlineFlag(db, originalFont)

    if fontPath then
        hotkey:SetFont(fontPath, size, outline)
    end

    ApplyConfiguredColor(hotkey, db, originalColor)

    local displayText = originalText

    if db.shorten == true then
        displayText = ShortenKeybind(originalText)
    end

    hotkey.ZTStyledText = displayText
    hotkey:SetText(displayText)
end

local function RefreshAllActionButtons()
    local inCombat = IsCombatLocked()

    for _, group in ipairs(buttonPrefixes) do
        for index = 1, group.count do
            local button = _G[group.prefix .. index]

            if not inCombat then
                ApplyHotkey(button)
            end

            EnsureRangeOverlay(button)
            RefreshRangeOverlay(button)
        end
    end
end

local function ScheduleRefresh()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, RefreshAllActionButtons)
    else
        RefreshAllActionButtons()
    end
end

local function SafeRegisterEvent(frame, event)
    pcall(frame.RegisterEvent, frame, event)
end

local function InstallHooks()
    if hooksInstalled then
        return
    end

    hooksInstalled = true

    if type(hooksecurefunc) == "function" then
        if type(ActionButton_UpdateHotkeys) == "function" then
            hooksecurefunc("ActionButton_UpdateHotkeys", function(button)
                if IsCombatLocked() then
                    return
                end

                ApplyHotkey(button, true)
            end)
        end

        if type(ActionButton_Update) == "function" then
            hooksecurefunc("ActionButton_Update", function(button)
                if not IsCombatLocked() then
                    ApplyHotkey(button, true)
                end

                RefreshRangeOverlay(button)
            end)
        end

        if type(ActionButton_UpdateRangeIndicator) == "function" then
            hooksecurefunc("ActionButton_UpdateRangeIndicator", function(button, checksRange, inRange)
                if not button then
                    return
                end

                button.ZTRangeOutOfRange = checksRange and IsOutOfRangeValue(inRange)
                SetRangeOverlay(button, button.ZTRangeOutOfRange)
            end)
        end
    end
end

function ns:SetKeybindTextEnabled(value)
    local db = EnsureCombatDB()

    if not db then
        return
    end

    db.enabled = value == true
    ScheduleRefresh()
end

function ns:GetKeybindTextEnabled()
    local db = EnsureCombatDB()

    return db and db.enabled == true
end

function ns:SetKeybindTextShortened(value)
    local db = EnsureCombatDB()

    if not db then
        return
    end

    db.shorten = value == true
    ScheduleRefresh()
end

function ns:GetKeybindTextShortened()
    local db = EnsureCombatDB()

    return db and db.shorten == true
end

function ns:SetKeybindTextFont(value)
    local db = EnsureCombatDB()

    if not db then
        return
    end

    db.font = fontChoices[value] and value or DEFAULT_FONT
    ScheduleRefresh()
end

function ns:GetKeybindTextFont()
    local db = EnsureCombatDB()

    return db and db.font or DEFAULT_FONT
end

function ns:GetKeybindTextFontOptions()
    return {
        { value = "default", text = fontChoices.default.label },
        { value = "friz", text = fontChoices.friz.label },
        { value = "arial", text = fontChoices.arial.label },
        { value = "morpheus", text = fontChoices.morpheus.label },
        { value = "skurri", text = fontChoices.skurri.label },
        { value = "damage", text = fontChoices.damage.label },
    }
end

function ns:SetKeybindTextOutline(value)
    local db = EnsureCombatDB()

    if not db then
        return
    end

    db.outline = outlineChoices[NormalizeOutline(value)] and NormalizeOutline(value) or DEFAULT_OUTLINE
    ScheduleRefresh()
end

function ns:GetKeybindTextOutline()
    local db = EnsureCombatDB()

    return db and NormalizeOutline(db.outline) or DEFAULT_OUTLINE
end

function ns:GetKeybindTextOutlineOptions()
    return {
        { value = "default", text = outlineChoices.default.label },
        { value = "none", text = outlineChoices.none.label },
        { value = "outline", text = outlineChoices.outline.label },
        { value = "thick", text = outlineChoices.thick.label },
    }
end

function ns:SetKeybindTextBold(value)
    local db = EnsureCombatDB()

    if not db then
        return
    end

    db.bold = value == true
    ScheduleRefresh()
end

function ns:GetKeybindTextBold()
    local db = EnsureCombatDB()

    return db and db.bold == true
end

function ns:SetKeybindTextUseCustomColor(value)
    local db = EnsureCombatDB()

    if not db then
        return
    end

    db.useCustomColor = value == true
    ScheduleRefresh()
end

function ns:GetKeybindTextUseCustomColor()
    local db = EnsureCombatDB()

    return db and db.useCustomColor == true
end

function ns:SetKeybindTextColor(r, g, b, useCustom)
    local db = EnsureCombatDB()

    if not db then
        return
    end

    db.color = db.color or {}
    db.color.r = ClampColor(r)
    db.color.g = ClampColor(g)
    db.color.b = ClampColor(b)

    if useCustom == nil then
        db.useCustomColor = true
    else
        db.useCustomColor = useCustom == true
    end

    ScheduleRefresh()
end

function ns:GetKeybindTextColor()
    local db = EnsureCombatDB()
    local color = db and db.color

    return ClampColor(color and color.r or DEFAULT_COLOR_R),
        ClampColor(color and color.g or DEFAULT_COLOR_G),
        ClampColor(color and color.b or DEFAULT_COLOR_B)
end

function ns:SetKeybindTextFontSize(value)
    local db = EnsureCombatDB()

    if not db then
        return
    end

    db.fontSize = ClampFontSize(value)
    ScheduleRefresh()
end

function ns:GetKeybindTextFontSize()
    local db = EnsureCombatDB()

    return ClampFontSize(db and db.fontSize)
end

function ns:SetActionButtonRangeTintEnabled(value)
    EnsureCombatDB()

    if not ns.db or not ns.db.combat then
        return
    end

    ns.db.combat.actionButtonRangeTint = value == true
    ScheduleRefresh()
end

function ns:GetActionButtonRangeTintEnabled()
    return IsRangeTintEnabled()
end

function ns:RefreshActionButtonRangeTint()
    ScheduleRefresh()
end

function ns:RefreshKeybindText()
    ScheduleRefresh()
end

function ns:InitializeKeybindText()
    EnsureCombatDB()
    InstallHooks()
    ScheduleRefresh()

    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    SafeRegisterEvent(eventFrame, "PLAYER_ENTERING_WORLD")
    SafeRegisterEvent(eventFrame, "UPDATE_BINDINGS")
    SafeRegisterEvent(eventFrame, "ACTIONBAR_PAGE_CHANGED")
    SafeRegisterEvent(eventFrame, "UPDATE_SHAPESHIFT_FORM")
    SafeRegisterEvent(eventFrame, "PET_BAR_UPDATE")
    SafeRegisterEvent(eventFrame, "UPDATE_OVERRIDE_ACTIONBAR")
    SafeRegisterEvent(eventFrame, "UPDATE_POSSESS_BAR")
    eventFrame:SetScript("OnEvent", ScheduleRefresh)
end
