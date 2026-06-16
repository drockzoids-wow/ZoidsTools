local _, ns = ...

local widget
local eventFrame
local elapsedSinceUpdate = 0

local DEFAULT_POINT = "BOTTOM"
local DEFAULT_RELATIVE_POINT = "BOTTOM"
local DEFAULT_X = 0
local DEFAULT_Y = 205
local DEFAULT_SCALE = 1

local displayModes = {
    disabled = true,
    fps = true,
    latency = true,
    both = true,
}

local function SafeCall(method, object, ...)
    if type(method) ~= "function" then
        return false
    end

    return pcall(method, object, ...)
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.performance = ns.db.performance or {}

    if ns.db.performance.enabled == nil then
        ns.db.performance.enabled = true
    end

    if not displayModes[ns.db.performance.displayMode] then
        ns.db.performance.displayMode = ns.db.performance.enabled and "both" or "disabled"
    end

    ns.db.performance.enabled = ns.db.performance.displayMode ~= "disabled"

    if ns.db.performance.scale == nil then
        ns.db.performance.scale = DEFAULT_SCALE
    end

    if ns.db.performance.locked == nil then
        ns.db.performance.locked = false
    end

    if ns.db.performance.updateInterval == nil then
        ns.db.performance.updateInterval = 1
    end

    return ns.db.performance
end

local function GetClassColor()
    local _, classFile = UnitClass("player")

    if classFile and C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local color = C_ClassColor.GetClassColor(classFile)

        if color and color.GetRGB then
            return color:GetRGB()
        end
    end

    local color = classFile
        and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))

    if color then
        return color.r or 1, color.g or 0.82, color.b or 0
    end

    return 1, 0.82, 0
end

local function SavePosition()
    local db = EnsureDB()

    if not db or not widget then
        return
    end

    local point, _, relativePoint, x, y = widget:GetPoint(1)

    db.point = point or DEFAULT_POINT
    db.relativePoint = relativePoint or DEFAULT_RELATIVE_POINT
    db.x = x or DEFAULT_X
    db.y = y or DEFAULT_Y
end

local function RestorePosition()
    local db = EnsureDB()

    if not db or not widget then
        return
    end

    widget:ClearAllPoints()
    widget:SetPoint(
        db.point or DEFAULT_POINT,
        UIParent,
        db.relativePoint or DEFAULT_RELATIVE_POINT,
        db.x or DEFAULT_X,
        db.y or DEFAULT_Y
    )
end

local function ResetPosition()
    local db = EnsureDB()

    if not db or not widget then
        return
    end

    db.point = DEFAULT_POINT
    db.relativePoint = DEFAULT_RELATIVE_POINT
    db.x = DEFAULT_X
    db.y = DEFAULT_Y

    RestorePosition()
end

local function ApplyClassColor()
    if not widget then
        return
    end

    local r, g, b = GetClassColor()

    widget.text:SetTextColor(r, g, b)
    widget:SetBackdropBorderColor(r, g, b, 0.62)
    widget.topLine:SetVertexColor(r, g, b, 0.45)
    widget.bottomLine:SetVertexColor(r, g, b, 0.25)
end

local function GetDisplayMode()
    local db = EnsureDB()

    if not db or not displayModes[db.displayMode] then
        return "both"
    end

    return db.displayMode
end

local function ClampScale(value)
    value = tonumber(value) or DEFAULT_SCALE

    if value < 0.65 then
        return 0.65
    elseif value > 1.8 then
        return 1.8
    end

    return value
end

local function GetPerformanceValues()
    local fps = GetFramerate and math.floor((GetFramerate() or 0) + 0.5) or 0
    local homeLatency, worldLatency = 0, 0

    if GetNetStats then
        local _, _, home, world = GetNetStats()
        homeLatency = home or 0
        worldLatency = world or homeLatency
    end

    return fps, homeLatency, worldLatency
end

local function IsLocked()
    local db = EnsureDB()

    return db and db.locked == true
end

local function ApplyMouseBehavior()
    if not widget then
        return
    end

    local locked = IsLocked()
    local supportsSplitMouse = type(widget.SetMouseMotionEnabled) == "function"
        and type(widget.SetMouseClickEnabled) == "function"

    if locked and supportsSplitMouse then
        widget:EnableMouse(true)
        widget:SetMouseMotionEnabled(true)
        widget:SetMouseClickEnabled(false)
    elseif locked then
        widget:EnableMouse(false)
    else
        widget:EnableMouse(true)

        if type(widget.SetMouseMotionEnabled) == "function" then
            widget:SetMouseMotionEnabled(true)
        end

        if type(widget.SetMouseClickEnabled) == "function" then
            widget:SetMouseClickEnabled(true)
        end

        widget:RegisterForDrag("LeftButton")
    end
end

local function ApplyWidgetSize()
    if not widget then
        return
    end

    local db = EnsureDB()
    local mode = GetDisplayMode()
    local width = mode == "both" and 148 or 88

    widget:SetSize(width, 28)
    widget:SetScale(ClampScale(db and db.scale))
end

local function UpdatePerformanceText()
    if not widget then
        return
    end

    local fps, homeLatency, worldLatency = GetPerformanceValues()
    local latency = worldLatency or homeLatency or 0
    local mode = GetDisplayMode()

    if mode == "fps" then
        widget.text:SetFormattedText("FPS %d", fps)
    elseif mode == "latency" then
        widget.text:SetFormattedText("MS %d", latency)
    elseif mode == "both" then
        widget.text:SetFormattedText("FPS %d   MS %d", fps, latency)
    else
        widget.text:SetText("")
    end
end

local function OnUpdate(self, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed

    local db = EnsureDB()
    local updateInterval = db and db.updateInterval or 1

    if elapsedSinceUpdate < updateInterval then
        return
    end

    elapsedSinceUpdate = 0
    UpdatePerformanceText()
end

local function CreateWidget()
    if widget then
        return widget
    end

    widget = CreateFrame("Frame", "ZoidsToolsPerformanceWidget", UIParent, "BackdropTemplate")
    widget:SetSize(148, 28)
    widget:SetFrameStrata("MEDIUM")
    widget:SetMovable(true)
    widget:SetClampedToScreen(true)
    widget:EnableMouse(true)
    widget:RegisterForDrag("LeftButton")
    widget:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    widget:SetBackdropColor(0.02, 0.018, 0.014, 0.86)

    widget.topLine = widget:CreateTexture(nil, "ARTWORK")
    widget.topLine:SetPoint("TOPLEFT", 10, -4)
    widget.topLine:SetPoint("TOPRIGHT", -10, -4)
    widget.topLine:SetHeight(1)
    widget.topLine:SetColorTexture(1, 1, 1, 1)

    widget.bottomLine = widget:CreateTexture(nil, "ARTWORK")
    widget.bottomLine:SetPoint("BOTTOMLEFT", 10, 4)
    widget.bottomLine:SetPoint("BOTTOMRIGHT", -10, 4)
    widget.bottomLine:SetHeight(1)
    widget.bottomLine:SetColorTexture(1, 1, 1, 1)

    widget.text = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    widget.text:SetPoint("CENTER")

    widget:SetScript("OnDragStart", function(self)
        if IsLocked() then
            return
        end

        SafeCall(self.StartMoving, self)
    end)

    widget:SetScript("OnDragStop", function(self)
        SafeCall(self.StopMovingOrSizing, self)
        SavePosition()
    end)

    widget:SetScript("OnMouseUp", function(_, button)
        if button ~= "RightButton" then
            return
        end

        if IsControlKeyDown and IsControlKeyDown() then
            local db = EnsureDB()

            if db then
                db.locked = true
                ApplyMouseBehavior()
                GameTooltip:Hide()
                ns:Print("Performance widget locked click-through. Open /zt to unlock it.")
            end
        elseif IsShiftKeyDown and IsShiftKeyDown() then
            ResetPosition()
            ns:Print("Performance widget position reset.")
        end
    end)

    widget:SetScript("OnEnter", function(self)
        local fps, homeLatency, worldLatency = GetPerformanceValues()

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("ZoidsTools Performance")
        GameTooltip:AddDoubleLine("FPS", tostring(fps), 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("Home", tostring(homeLatency) .. " ms", 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine("World", tostring(worldLatency) .. " ms", 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddLine(" ")

        if IsLocked() then
            GameTooltip:AddLine("Locked click-through.", 1, 1, 1, true)
            GameTooltip:AddLine("Unlock from /zt or /zt perf unlock.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine("Drag to move.", 1, 1, 1, true)
            GameTooltip:AddLine("Ctrl + Right-click: Lock click-through", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Shift + Right-click: Reset position", 0.8, 0.8, 0.8, true)
        end

        GameTooltip:Show()
    end)

    widget:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    RestorePosition()
    ApplyWidgetSize()
    ApplyClassColor()
    ApplyMouseBehavior()
    UpdatePerformanceText()

    return widget
end

local function RefreshWidget()
    local db = EnsureDB()
    local frame = CreateWidget()

    if not db or not frame then
        return
    end

    ApplyClassColor()
    ApplyWidgetSize()
    ApplyMouseBehavior()
    UpdatePerformanceText()

    if db.displayMode ~= "disabled" then
        frame:SetScript("OnUpdate", OnUpdate)
        frame:Show()
    else
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end
end

function ns:SetPerformanceWidgetShown(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.displayMode = value == true and "both" or "disabled"
    db.enabled = db.displayMode ~= "disabled"
    RefreshWidget()
end

function ns:IsPerformanceWidgetShown()
    local db = EnsureDB()

    return db and db.displayMode ~= "disabled"
end

function ns:SetPerformanceWidgetDisplayMode(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.displayMode = displayModes[value] and value or "both"
    db.enabled = db.displayMode ~= "disabled"
    RefreshWidget()
end

function ns:GetPerformanceWidgetDisplayMode()
    return GetDisplayMode()
end

function ns:SetPerformanceWidgetScale(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.scale = ClampScale(value)
    RefreshWidget()
end

function ns:GetPerformanceWidgetScale()
    local db = EnsureDB()

    return ClampScale(db and db.scale)
end

function ns:SetPerformanceWidgetLocked(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.locked = value == true
    ApplyMouseBehavior()
end

function ns:IsPerformanceWidgetLocked()
    return IsLocked()
end

function ns:RefreshPerformanceWidget()
    RefreshWidget()
end

function ns:InitializePerformanceWidget()
    RefreshWidget()

    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
        ApplyClassColor()
        RefreshWidget()
    end)
end
