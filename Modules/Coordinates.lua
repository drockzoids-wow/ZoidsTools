local _, ns = ...

local widget
local mapOverlay
local eventFrame
local elapsedSinceUpdate = 0
local mapElapsedSinceUpdate = 0
local RefreshCoordinates

local DEFAULT_POINT = "BOTTOM"
local DEFAULT_RELATIVE_POINT = "BOTTOM"
local DEFAULT_X = 0
local DEFAULT_Y = 245
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

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.coordinates = ns.db.coordinates or {}

    local db = ns.db.coordinates

    if db.enabled == nil then
        db.enabled = true
    end

    if db.mapEnabled == nil then
        db.mapEnabled = true
    end

    if db.updateInterval == nil then
        db.updateInterval = DEFAULT_UPDATE_INTERVAL
    end

    if db.scale == nil then
        db.scale = DEFAULT_SCALE
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

    if WorldMapFrame and type(WorldMapFrame.GetMapID) == "function" then
        return WorldMapFrame:GetMapID()
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

    if mapOverlay then
        mapOverlay.playerText:SetTextColor(1, 1, 1)
        mapOverlay.mouseText:SetTextColor(1, 1, 1)
    end
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

local function GetWorldMapID()
    if WorldMapFrame and type(WorldMapFrame.GetMapID) == "function" then
        return WorldMapFrame:GetMapID()
    end

    return GetBestPlayerMapID()
end

local function GetMapMousePosition()
    if not WorldMapFrame then
        return nil, nil
    end

    local scrollContainer = WorldMapFrame.ScrollContainer

    if scrollContainer and type(scrollContainer.IsMouseOver) == "function" and not scrollContainer:IsMouseOver() then
        return nil, nil
    end

    if scrollContainer and type(scrollContainer.GetNormalizedCursorPosition) == "function" then
        local x, y = scrollContainer:GetNormalizedCursorPosition()

        if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            return x * 100, y * 100
        end
    end

    if not WorldMapFrame:IsMouseOver() then
        return nil, nil
    end

    local target = scrollContainer or WorldMapFrame
    local left, bottom, width, height = target:GetRect()

    if not left or not bottom or not width or not height or width <= 0 or height <= 0 then
        return nil, nil
    end

    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    cursorX = (cursorX or 0) / scale
    cursorY = (cursorY or 0) / scale

    local x = (cursorX - left) / width
    local y = ((bottom + height) - cursorY) / height

    if x < 0 or x > 1 or y < 0 or y > 1 then
        return nil, nil
    end

    return x * 100, y * 100
end

local function PositionMapOverlay()
    if not mapOverlay or not WorldMapFrame then
        return
    end

    local anchor = WorldMapFrame.ScrollContainer or WorldMapFrame

    mapOverlay:ClearAllPoints()
    mapOverlay:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -12, 48)
end

local function UpdateMapOverlay()
    local db = EnsureDB()

    if not mapOverlay or not db or db.mapEnabled ~= true or not WorldMapFrame or not WorldMapFrame:IsShown() then
        if mapOverlay then
            mapOverlay:Hide()
        end

        return
    end

    local mapID = GetWorldMapID()
    local playerX, playerY = GetMapPlayerPosition(mapID)
    local mouseX, mouseY = GetMapMousePosition()

    PositionMapOverlay()
    mapOverlay.playerText:SetText("Player: " .. FormatCoordinates(playerX, playerY))

    if mouseX and mouseY then
        mapOverlay.mouseText:SetText("Cursor: " .. FormatCoordinates(mouseX, mouseY))
        mapOverlay.mouseText:Show()
    else
        mapOverlay.mouseText:Hide()
    end

    mapOverlay:Show()
end

local function OnMapUpdate(_, elapsed)
    mapElapsedSinceUpdate = mapElapsedSinceUpdate + (elapsed or 0)

    if mapElapsedSinceUpdate < DEFAULT_UPDATE_INTERVAL then
        return
    end

    mapElapsedSinceUpdate = 0
    UpdateMapOverlay()
end

local function CreateMapOverlay()
    if mapOverlay or not WorldMapFrame then
        return mapOverlay
    end

    mapOverlay = CreateFrame("Frame", "ZoidsToolsMapCoordinates", WorldMapFrame, "BackdropTemplate")
    mapOverlay:SetFrameStrata("HIGH")
    mapOverlay:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 1) + 40)
    mapOverlay:SetSize(190, 42)
    mapOverlay:EnableMouse(false)
    PositionMapOverlay()

    mapOverlay.playerText = mapOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mapOverlay.playerText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    mapOverlay.playerText:SetPoint("BOTTOMRIGHT", mapOverlay, "BOTTOMRIGHT", 0, 0)
    mapOverlay.playerText:SetWidth(190)
    mapOverlay.playerText:SetJustifyH("RIGHT")
    mapOverlay.playerText:SetTextColor(1, 1, 1)
    mapOverlay.playerText:SetShadowOffset(1, -1)
    mapOverlay.playerText:SetShadowColor(0, 0, 0, 1)

    mapOverlay.mouseText = mapOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mapOverlay.mouseText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    mapOverlay.mouseText:SetPoint("BOTTOMRIGHT", mapOverlay.playerText, "TOPRIGHT", 0, 8)
    mapOverlay.mouseText:SetWidth(190)
    mapOverlay.mouseText:SetJustifyH("RIGHT")
    mapOverlay.mouseText:SetTextColor(1, 1, 1)
    mapOverlay.mouseText:SetShadowOffset(1, -1)
    mapOverlay.mouseText:SetShadowColor(0, 0, 0, 1)

    mapOverlay:SetScript("OnUpdate", OnMapUpdate)

    WorldMapFrame:HookScript("OnShow", UpdateMapOverlay)
    WorldMapFrame:HookScript("OnHide", UpdateMapOverlay)

    if type(ToggleWorldMap) == "function" then
        hooksecurefunc("ToggleWorldMap", RefreshCoordinates)
    end

    ApplyClassColor()
    UpdateMapOverlay()

    return mapOverlay
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

    CreateMapOverlay()
    UpdateMapOverlay()
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

function ns:SetMapCoordinatesShown(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.mapEnabled = value == true
    RefreshCoordinates()
end

function ns:IsMapCoordinatesShown()
    local db = EnsureDB()

    return db and db.mapEnabled == true
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
