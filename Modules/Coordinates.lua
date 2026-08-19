local _, ns = ...

local widget
local eventFrame
local elapsedSinceUpdate = 0
local RefreshCoordinates

local DEFAULT_POINT = "BOTTOM"
local DEFAULT_RELATIVE_POINT = "BOTTOM"
local DEFAULT_RELATIVE_TO = "Minimap"
local UI_PARENT_RELATIVE_TO = "UIParent"
local DEFAULT_X = 0
local DEFAULT_Y = 0
local OLD_CORE_DEFAULT_Y = 8
local OLD_DEFAULT_Y = 245
local DEFAULT_SCALE = 1
local DEFAULT_UPDATE_INTERVAL = 0.15

local function ClampScale(value)
    value = tonumber(value) or DEFAULT_SCALE

    if value < 0.65 then
        return 0.65
    elseif value > 1.8 then
        return 1.8
    end

    return value
end

local function GetRelativeFrame(key)
    if key == DEFAULT_RELATIVE_TO and Minimap then
        return Minimap
    end

    return UIParent
end

local function GetRelativeFrameKey(frame)
    if frame == Minimap then
        return DEFAULT_RELATIVE_TO
    end

    return UI_PARENT_RELATIVE_TO
end

local function IsDefaultPosition(db, y)
    return (db.point or DEFAULT_POINT) == DEFAULT_POINT
        and (db.relativePoint or DEFAULT_RELATIVE_POINT) == DEFAULT_RELATIVE_POINT
        and math.abs((db.x or DEFAULT_X) - DEFAULT_X) < 0.01
        and math.abs((db.y or DEFAULT_Y) - y) < 0.01
end

local function SetDefaultPosition(db)
    db.point = DEFAULT_POINT
    db.relativePoint = DEFAULT_RELATIVE_POINT
    db.relativeTo = DEFAULT_RELATIVE_TO
    db.x = DEFAULT_X
    db.y = DEFAULT_Y
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.coordinates = ns.db.coordinates or {}

    local db = ns.db.coordinates

    if db.enabled == nil then
        db.enabled = true
    end

    if db.updateInterval == nil then
        db.updateInterval = DEFAULT_UPDATE_INTERVAL
    end

    if db.scale == nil then
        db.scale = DEFAULT_SCALE
    end

    if db.relativeTo == nil then
        if IsDefaultPosition(db, DEFAULT_Y) or IsDefaultPosition(db, OLD_CORE_DEFAULT_Y) or IsDefaultPosition(db, OLD_DEFAULT_Y) then
            SetDefaultPosition(db)
        else
            db.relativeTo = UI_PARENT_RELATIVE_TO
        end
    elseif db.relativeTo ~= DEFAULT_RELATIVE_TO then
        db.relativeTo = UI_PARENT_RELATIVE_TO
    end

    return db
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

local function GetBestPlayerMapID()
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        return C_Map.GetBestMapForUnit("player")
    end

    return nil
end

local function GetMapPlayerPosition(mapID)
    if not mapID or not C_Map or type(C_Map.GetPlayerMapPosition) ~= "function" then
        return nil, nil
    end

    local position = C_Map.GetPlayerMapPosition(mapID, "player")

    if not position or type(position.GetXY) ~= "function" then
        return nil, nil
    end

    local x, y = position:GetXY()

    if not x or not y then
        return nil, nil
    end

    return x * 100, y * 100
end

local function FormatCoordinates(x, y)
    if not x or not y then
        return "--, --"
    end

    return string.format("%.1f, %.1f", x, y)
end

local function GetPlayerCoordinates()
    return GetMapPlayerPosition(GetBestPlayerMapID())
end

local function GetZoneName()
    local zone = GetRealZoneText and GetRealZoneText()

    if not zone or zone == "" then
        zone = GetZoneText and GetZoneText()
    end

    return zone or ""
end

local function InsertChatText(text)
    local editBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()

    if editBox then
        editBox:Insert(text)
    elseif ChatFrame_OpenChat then
        ChatFrame_OpenChat(text)
    end
end

local function SharePlayerCoordinates()
    local x, y = GetPlayerCoordinates()

    if not x or not y then
        ns:Print("Coordinates are not available here.")
        return
    end

    local zone = GetZoneName()
    local text = "Coordinates: " .. FormatCoordinates(x, y)

    if zone ~= "" then
        text = zone .. " - " .. FormatCoordinates(x, y)
    end

    InsertChatText(text)
end

local function SavePosition()
    local db = EnsureDB()

    if not db or not widget then
        return
    end

    local point, relativeFrame, relativePoint, x, y = widget:GetPoint(1)

    db.point = point or DEFAULT_POINT
    db.relativeTo = GetRelativeFrameKey(relativeFrame)
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
        GetRelativeFrame(db.relativeTo),
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

    SetDefaultPosition(db)

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

local function ApplyWidgetSize()
    if not widget then
        return
    end

    local db = EnsureDB()

    widget:SetSize(126, 28)
    widget:SetScale(ClampScale(db and db.scale))
end

local function UpdateWidgetText()
    if not widget then
        return
    end

    local x, y = GetPlayerCoordinates()

    widget.text:SetText(FormatCoordinates(x, y))
end

local function OnWidgetUpdate(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + (elapsed or 0)

    local db = EnsureDB()
    local updateInterval = db and db.updateInterval or DEFAULT_UPDATE_INTERVAL

    if elapsedSinceUpdate < updateInterval then
        return
    end

    elapsedSinceUpdate = 0
    UpdateWidgetText()
end

OnWidgetUpdate = ns:WrapDiagnosticFunction("Coordinates.Widget", OnWidgetUpdate)

local function CreateWidget()
    if widget then
        return widget
    end

    widget = CreateFrame("Frame", "ZoidsToolsCoordinatesWidget", UIParent, "BackdropTemplate")
    widget:SetSize(126, 28)
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
        if IsShiftKeyDown and IsShiftKeyDown() then
            return
        end

        self:StartMoving()
    end)

    widget:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    widget:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
            SharePlayerCoordinates()
        elseif button == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
            ResetPosition()
            ns:Print("Coordinates widget position reset.")
        end
    end)

    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("ZoidsTools Coordinates")
        GameTooltip:AddDoubleLine("Position", widget.text:GetText() or "", 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Drag to move.", 1, 1, 1, true)
        GameTooltip:AddLine("Shift + Left-click: Put coordinates in chat", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Shift + Right-click: Reset position", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    widget:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    RestorePosition()
    ApplyWidgetSize()
    ApplyClassColor()
    UpdateWidgetText()

    return widget
end

RefreshCoordinates = function()
    local db = EnsureDB()
    local frame = CreateWidget()

    if not db or not frame then
        return
    end

    ApplyClassColor()
    ApplyWidgetSize()
    UpdateWidgetText()

    if db.enabled then
        frame:SetScript("OnUpdate", OnWidgetUpdate)
        frame:Show()
    else
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end
end

function ns:SetCoordinatesWidgetShown(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.enabled = value == true
    RefreshCoordinates()
end

function ns:IsCoordinatesWidgetShown()
    local db = EnsureDB()

    return db and db.enabled == true
end

function ns:SetCoordinatesWidgetScale(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.scale = ClampScale(value)
    RefreshCoordinates()
end

function ns:GetCoordinatesWidgetScale()
    local db = EnsureDB()

    return ClampScale(db and db.scale)
end

function ns:ResetCoordinatesWidgetPosition()
    ResetPosition()
end

function ns:RefreshCoordinates()
    RefreshCoordinates()
end

function ns:InitializeCoordinates()
    RefreshCoordinates()

    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", function()
        RefreshCoordinates()
    end)

    if C_Timer and C_Timer.After then
        C_Timer.After(1, RefreshCoordinates)
    end
end
