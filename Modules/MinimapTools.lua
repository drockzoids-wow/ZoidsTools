local _, ns = ...

local initialized = false
local eventFrame
local squareBorder
local infoBar
local collectorButton
local collectorPanel
local collectorContent
local collectorDragAngle
local pendingRefresh = false
local mouseHooksInstalled = false
local originalGetMinimapShape = GetMinimapShape
local shapeOverrideApplied = false
local squareApplied = false

local trackedButtons = {}
local originalButtonPoints = {}
local collectionRestorePoints = {}
local originalWidgetPoints = {}
local originalShown = {}
local collectedButtonClickHooks = {}

local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local DEFAULT_MASK = "Textures\\MinimapMask"
local COLLECTOR_SIZE = 22
local COLLECTED_BUTTON_SIZE = 30
local COLLECTED_BUTTON_GAP = 6
local DEFAULT_COLLECTOR_ANGLE = -45
local COLLECTOR_RADIUS = COLLECTOR_SIZE / 2

local minimapShapes = {
    ROUND = { true, true, true, true },
    SQUARE = { false, false, false, false },
    CORNER_TOPLEFT = { false, false, false, true },
    CORNER_TOPRIGHT = { false, false, true, false },
    CORNER_BOTTOMLEFT = { false, true, false, false },
    CORNER_BOTTOMRIGHT = { true, false, false, false },
    SIDE_LEFT = { false, true, false, true },
    SIDE_RIGHT = { true, false, true, false },
    SIDE_TOP = { false, false, true, true },
    SIDE_BOTTOM = { true, true, false, false },
    TRICORNER_TOPLEFT = { false, true, true, true },
    TRICORNER_TOPRIGHT = { true, false, true, true },
    TRICORNER_BOTTOMLEFT = { true, true, false, true },
    TRICORNER_BOTTOMRIGHT = { true, true, true, false },
}

local function Atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end

    return 0
end

local ignoredButtonNames = {
    AddonCompartmentFrame = true,
    GameTimeFrame = true,
    GarrisonLandingPageMinimapButton = true,
    GuildInstanceDifficulty = true,
    InstanceDifficultyFrame = true,
    MiniMapBattlefieldFrame = true,
    MiniMapInstanceDifficulty = true,
    MiniMapMailFrame = true,
    MiniMapTracking = true,
    MiniMapTrackingButton = true,
    MiniMapWorldMapButton = true,
    MinimapBackdrop = true,
    MinimapBorder = true,
    MinimapBorderTop = true,
    MinimapCluster = true,
    MinimapCompassTexture = true,
    MinimapNorthTag = true,
    MinimapZoomIn = true,
    MinimapZoomOut = true,
    QueueStatusMinimapButton = true,
    TimeManagerClockButton = true,
    ZoidsToolsMinimapButtonCollector = true,
}

local ignoredButtonPatterns = {
    "^GatherMatePin",
    "^HandyNotesPin",
    "^MinimapPin",
    "^Quest",
    "^Vignette",
}

local function EnsureMinimapDB()
    if not ns.db then
        return nil
    end

    ns.db.ui = ns.db.ui or {}
    ns.db.ui.minimap = ns.db.ui.minimap or {}

    local db = ns.db.ui.minimap

    if db.square == nil then
        db.square = false
    end

    if db.moveHeader == nil then
        db.moveHeader = false
    end

    if db.hideAddonButtons == nil then
        db.hideAddonButtons = false
    end

    if db.collectAddonButtons == nil then
        db.collectAddonButtons = false
    end

    if db.collectorMoved == nil then
        db.collectorMoved = false
    end

    return db
end

local function SetShown(frame, shown)
    if not frame or not frame.Show or not frame.Hide then
        return
    end

    if shown then
        frame:Show()
    else
        frame:Hide()
    end
end

local function SaveOriginalShown(frame)
    if frame and frame.IsShown and originalShown[frame] == nil then
        originalShown[frame] = frame:IsShown()
    end
end

local function RestoreOriginalShown(frame)
    if not frame or not frame.IsShown then
        return
    end

    local shown = originalShown[frame]

    if shown == nil then
        return
    end

    SetShown(frame, shown)
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

local function StyleClassBorder(frame, alpha)
    if not frame or not frame.SetBackdropBorderColor then
        return
    end

    local r, g, b = GetClassColor()

    frame:SetBackdropBorderColor(r, g, b, alpha or 0.78)
end

local function EnsureSquareBorder()
    if squareBorder or not Minimap then
        return squareBorder
    end

    squareBorder = CreateFrame("Frame", "ZoidsToolsSquareMinimapBorder", Minimap, "BackdropTemplate")
    squareBorder:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 6)
    squareBorder:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    squareBorder:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 0, 0)
    squareBorder:SetBackdrop({
        edgeFile = SQUARE_MASK,
        edgeSize = 2,
    })
    StyleClassBorder(squareBorder)
    squareBorder:Hide()

    return squareBorder
end

local function ApplySquareMinimap(enabled)
    if not Minimap then
        return
    end

    local border = EnsureSquareBorder()
    local compass = _G.MinimapCompassTexture

    if enabled then
        StyleClassBorder(border)

        if compass then
            SaveOriginalShown(compass)
            compass:Hide()
        end

        if Minimap.SetMaskTexture then
            Minimap:SetMaskTexture(SQUARE_MASK)
        end

        squareApplied = true

        GetMinimapShape = function()
            return "SQUARE"
        end
        shapeOverrideApplied = true

        for _, name in ipairs({ "MinimapBorder", "MinimapBorderTop" }) do
            local frame = _G[name]

            if frame then
                SaveOriginalShown(frame)
                frame:Hide()
            end
        end

        if border then
            border:Show()
        end
    else
        if not squareApplied then
            if border then
                border:Hide()
            end

            return
        end

        if Minimap.SetMaskTexture then
            Minimap:SetMaskTexture(DEFAULT_MASK)
        end

        if shapeOverrideApplied then
            GetMinimapShape = originalGetMinimapShape
            shapeOverrideApplied = false
        end

        RestoreOriginalShown(compass)

        for _, name in ipairs({ "MinimapBorder", "MinimapBorderTop" }) do
            RestoreOriginalShown(_G[name])
        end

        if border then
            border:Hide()
        end

        squareApplied = false
    end
end

local function SaveFramePoints(frame, store)
    if not frame or store.points then
        return
    end

    store.parent = frame:GetParent()
    store.strata = frame:GetFrameStrata()
    store.level = frame:GetFrameLevel()
    store.width = frame:GetWidth()
    store.height = frame:GetHeight()
    store.points = {}

    for index = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)

        store.points[index] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
end

local function RestoreFramePoints(frame, store)
    if not frame or not store or not store.points then
        return
    end

    frame:SetParent(store.parent or UIParent)
    frame:ClearAllPoints()

    for _, point in ipairs(store.points) do
        frame:SetPoint(point.point, point.relativeTo, point.relativePoint, point.x or 0, point.y or 0)
    end

    if store.width and store.height and frame.SetSize then
        frame:SetSize(store.width, store.height)
    end

    if store.strata then
        frame:SetFrameStrata(store.strata)
    end

    if store.level then
        frame:SetFrameLevel(store.level)
    end
end

local function GetZoneTextButton()
    return _G.MinimapZoneTextButton or (MinimapCluster and MinimapCluster.ZoneTextButton)
end

local function GetClockButton()
    return _G.TimeManagerClockButton
end

local function GetTrackingButton()
    return _G.MiniMapTracking
        or _G.MiniMapTrackingButton
        or (MinimapCluster and (MinimapCluster.Tracking or MinimapCluster.TrackingFrame or MinimapCluster.TrackingButton))
end

local function GetCalendarButton()
    return _G.GameTimeFrame or (MinimapCluster and MinimapCluster.CalendarButton)
end

local function GetAddonCompartmentButton()
    return _G.AddonCompartmentFrame or (MinimapCluster and MinimapCluster.AddonCompartmentFrame)
end

local function StyleInfoBar(bar)
    if not bar then
        return
    end

    bar:SetBackdropColor(0.03, 0.035, 0.045, 0.44)
    StyleClassBorder(bar)
end

local function SetHeaderDecorShown(shown)
    local cluster = _G.MinimapCluster
    local zoneButton = GetZoneTextButton()
    local candidates = {
        _G.MinimapBorderTop,
        cluster and cluster.BorderTop,
        cluster and cluster.TopBorder,
        zoneButton and zoneButton.Background,
        zoneButton and zoneButton.Left,
        zoneButton and zoneButton.Middle,
        zoneButton and zoneButton.Right,
        _G.MinimapZoneTextButtonBackground,
        _G.MinimapZoneTextButtonLeft,
        _G.MinimapZoneTextButtonMiddle,
        _G.MinimapZoneTextButtonRight,
    }
    local seen = {}

    for _, frame in pairs(candidates) do
        if frame and not seen[frame] and frame.Show and frame.Hide and frame.IsShown then
            seen[frame] = true

            if shown then
                RestoreOriginalShown(frame)
            else
                SaveOriginalShown(frame)
                SetShown(frame, false)
            end
        end
    end
end

local function MoveHeaderWidget(key, frame, bar)
    if not frame then
        return false
    end

    originalWidgetPoints[key] = originalWidgetPoints[key] or {}
    SaveFramePoints(frame, originalWidgetPoints[key])
    frame:SetParent(bar)
    frame:ClearAllPoints()
    frame:SetFrameLevel(bar:GetFrameLevel() + 1)
    frame:Show()

    return true
end

local function MoveMinimapCornerWidget(key, frame)
    if not frame or not Minimap then
        return false
    end

    originalWidgetPoints[key] = originalWidgetPoints[key] or {}
    SaveFramePoints(frame, originalWidgetPoints[key])
    frame:SetParent(Minimap)
    frame:ClearAllPoints()
    frame:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 12)
    frame:Show()

    return true
end

local function AnchorHeaderRightWidget(frame, rightAnchor, bar)
    if rightAnchor == bar then
        frame:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    else
        frame:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0)
    end
end

local function GetZoneTextRegion(zoneButton)
    if not zoneButton then
        return nil
    end

    if zoneButton.Text then
        return zoneButton.Text
    end

    if zoneButton.text then
        return zoneButton.text
    end

    if _G.MinimapZoneText then
        return _G.MinimapZoneText
    end

    for _, region in ipairs({ zoneButton:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            return region
        end
    end

    return nil
end

local function EnsureInfoBar()
    if infoBar or not Minimap then
        return infoBar
    end

    infoBar = CreateFrame("Frame", "ZoidsToolsMinimapInfoBar", MinimapCluster or UIParent, "BackdropTemplate")
    infoBar:SetHeight(22)
    infoBar:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", 0, 2)
    infoBar:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", 0, 2)
    infoBar:SetFrameStrata("MEDIUM")
    infoBar:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 7)
    infoBar:SetBackdrop({
        bgFile = SQUARE_MASK,
        edgeFile = SQUARE_MASK,
        edgeSize = 1,
    })
    StyleInfoBar(infoBar)
    infoBar:Hide()

    return infoBar
end

local function ApplyInfoBar(enabled)
    local bar = EnsureInfoBar()

    if not bar then
        return
    end

    local zoneButton = GetZoneTextButton()
    local clockButton = GetClockButton()
    local trackingButton = GetTrackingButton()
    local calendarButton = GetCalendarButton()
    local addonButton = GetAddonCompartmentButton()
    local db = EnsureMinimapDB()

    if enabled then
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", 0, 2)
        bar:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", 0, 2)
        StyleInfoBar(bar)
        bar:Show()
        SetHeaderDecorShown(false)

        local rightAnchor = bar

        if trackingButton and MoveMinimapCornerWidget("tracking", trackingButton) then
            trackingButton:SetSize(22, 22)
            trackingButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 5, -5)
        end

        if clockButton and MoveHeaderWidget("clock", clockButton, bar) then
            clockButton:SetSize(58, 20)
            clockButton:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
            clockButton:SetFrameLevel(bar:GetFrameLevel() + 3)
            rightAnchor = clockButton
        end

        if addonButton and MoveHeaderWidget("addon", addonButton, bar) then
            addonButton:SetSize(22, 22)
            addonButton:SetPoint("LEFT", bar, "LEFT", 4, 0)
            addonButton:SetFrameLevel(bar:GetFrameLevel() + 3)
        end

        if calendarButton and MoveMinimapCornerWidget("calendar", calendarButton) then
            calendarButton:SetSize(22, 22)
            calendarButton:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -5, -5)
        end

        if zoneButton then
            MoveHeaderWidget("zone", zoneButton, bar)
            zoneButton:SetPoint("LEFT", bar, "LEFT", 0, 0)
            zoneButton:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
            zoneButton:SetHeight(bar:GetHeight() or 22)
            zoneButton:SetFrameLevel(bar:GetFrameLevel() + 1)

            local zoneText = GetZoneTextRegion(zoneButton)

            if zoneText then
                zoneText:ClearAllPoints()
                zoneText:SetPoint("LEFT", zoneButton, "LEFT", 58, 0)
                zoneText:SetPoint("RIGHT", zoneButton, "RIGHT", -58, 0)
                zoneText:SetHeight(bar:GetHeight() or 22)
            end

            if zoneText and zoneText.SetJustifyH then
                zoneText:SetJustifyH("CENTER")
            end

            if zoneText and zoneText.SetJustifyV then
                zoneText:SetJustifyV("MIDDLE")
            end
        end
    else
        bar:Hide()
        RestoreFramePoints(zoneButton, originalWidgetPoints.zone)
        RestoreFramePoints(clockButton, originalWidgetPoints.clock)
        RestoreFramePoints(trackingButton, originalWidgetPoints.tracking)
        RestoreFramePoints(calendarButton, originalWidgetPoints.calendar)
        RestoreFramePoints(addonButton, originalWidgetPoints.addon)

        if not db or not db.square then
            SetHeaderDecorShown(true)
        end
    end
end

local function GetButtonKey(button)
    local name = button and button.GetName and button:GetName()

    if not name then
        return nil
    end

    return name:gsub("^LibDBIcon10_", ""):gsub(".*_LibDBIcon_", "")
end

local function IsIgnoredButtonName(name, key)
    if not name then
        return true
    end

    if ignoredButtonNames[name] or ignoredButtonNames[key] then
        return true
    end

    for _, pattern in ipairs(ignoredButtonPatterns) do
        if name:match(pattern) or (key and key:match(pattern)) then
            return true
        end
    end

    return false
end

local function IsAddonMinimapButton(button)
    if not button or button == collectorButton then
        return false
    end

    if not button.IsObjectType or not button:IsObjectType("Button") then
        return false
    end

    local name = button:GetName()
    local key = GetButtonKey(button)

    if IsIgnoredButtonName(name, key) then
        return false
    end

    local width = button:GetWidth() or 0
    local height = button:GetHeight() or 0

    if width < 12 or height < 12 or width > 70 or height > 70 then
        return false
    end

    return true
end

local function IsButtonInCollector(button)
    local parent = button and button:GetParent()

    return parent == collectorPanel or parent == collectorContent
end

local function StoreButtonOriginalPoint(button, force)
    local name = button and button:GetName()

    if not name or (originalButtonPoints[name] and not force) then
        return
    end

    local previous = originalButtonPoints[name]
    local db = EnsureMinimapDB()
    local alpha = button:GetAlpha()
    local shown = button:IsShown()

    if force and previous and db and db.hideAddonButtons and (alpha == 0 or shown == false) then
        alpha = previous.alpha or 1
        shown = previous.shown ~= false
    end

    local store = {}
    SaveFramePoints(button, store)
    store.alpha = alpha
    store.shown = shown
    originalButtonPoints[name] = store
end

local function CaptureButtonRestorePoint(button)
    local name = button and button:GetName()

    if not name or IsButtonInCollector(button) then
        return
    end

    local previous = collectionRestorePoints[name] or originalButtonPoints[name]
    local db = EnsureMinimapDB()
    local alpha = button:GetAlpha()
    local shown = button:IsShown()

    if previous and db and db.hideAddonButtons and (alpha == 0 or shown == false) then
        alpha = previous.alpha or 1
        shown = previous.shown ~= false
    end

    local store = {}
    SaveFramePoints(button, store)
    store.alpha = alpha
    store.shown = shown
    collectionRestorePoints[name] = store
end

local function CaptureCollectionRestorePositions()
    for _, button in pairs(trackedButtons) do
        if button and button:GetName() and not IsButtonInCollector(button) then
            CaptureButtonRestorePoint(button)
            StoreButtonOriginalPoint(button, true)
        end
    end
end

local function RestoreButton(button, store)
    local name = button and button:GetName()
    store = store or (name and originalButtonPoints[name])

    if not button or not store then
        return
    end

    RestoreFramePoints(button, store)
    button:SetAlpha(store.alpha or 1)
    SetShown(button, store.shown ~= false)
end

local function GetCollectorAngle()
    local db = EnsureMinimapDB()

    return db and db.collectorAngle or DEFAULT_COLLECTOR_ANGLE
end

local function SetCollectorAngleFromCursor()
    if not collectorButton or not Minimap or not GetCursorPosition then
        return
    end

    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale() or 1

    if not mx or not my or not px or not py then
        return
    end

    px, py = px / scale, py / scale
    collectorDragAngle = math.deg(Atan2(py - my, px - mx)) % 360
end

local function PositionCollectorButton()
    if not collectorButton or not Minimap then
        return
    end

    local db = EnsureMinimapDB()
    local angle = math.rad((collectorDragAngle or (db and db.collectorAngle) or DEFAULT_COLLECTOR_ANGLE) % 360)
    local x, y = math.cos(angle), math.sin(angle)
    local quadrant = 1

    if x < 0 then
        quadrant = quadrant + 1
    end

    if y > 0 then
        quadrant = quadrant + 2
    end

    collectorButton:ClearAllPoints()

    local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local shape = minimapShapes[minimapShape] or minimapShapes.ROUND
    local width = (Minimap:GetWidth() / 2) + COLLECTOR_RADIUS
    local height = (Minimap:GetHeight() / 2) + COLLECTOR_RADIUS

    if shape[quadrant] then
        x, y = x * width, y * height
    else
        local diagWidth = math.sqrt(2 * (width ^ 2)) - 10
        local diagHeight = math.sqrt(2 * (height ^ 2)) - 10

        x = math.max(-width, math.min(x * diagWidth, width))
        y = math.max(-height, math.min(y * diagHeight, height))
    end

    collectorButton:SetParent(Minimap)
    collectorButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    collectorButton:SetFrameStrata("MEDIUM")
    collectorButton:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 14)
end

local function SaveCollectorPosition()
    local db = EnsureMinimapDB()

    if not db or not collectorButton then
        return
    end

    db.collectorMoved = true
    db.collectorAngle = collectorDragAngle or db.collectorAngle or DEFAULT_COLLECTOR_ANGLE
end

local function GatherAddonButtons()
    if not Minimap then
        return
    end

    local function ScanContainer(container)
        if not container or not container.GetChildren then
            return
        end

        for _, child in ipairs({ container:GetChildren() }) do
            if IsAddonMinimapButton(child) then
                local name = child:GetName()
                trackedButtons[name] = child
                StoreButtonOriginalPoint(child)
            end
        end
    end

    ScanContainer(Minimap)
    ScanContainer(_G.MinimapCluster)
end

local LayoutCollectorButtons
local CloseCollectorPanel

local function CloseCollectorPanelAfterClick(_, mouseButton)
    if mouseButton ~= "LeftButton" then
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, CloseCollectorPanel)
    elseif CloseCollectorPanel then
        CloseCollectorPanel()
    end
end

local function IsMouseOverCollectedButton()
    for _, button in pairs(trackedButtons) do
        if button and button.IsMouseOver and button:IsMouseOver() then
            return true
        end
    end

    return false
end

local function ShouldCloseCollectorFromOutsideClick()
    if not collectorPanel or not collectorPanel:IsShown() then
        return false
    end

    if collectorButton and collectorButton:IsMouseOver() then
        return false
    end

    if collectorPanel:IsMouseOver() then
        return false
    end

    if IsMouseOverCollectedButton() then
        return false
    end

    return true
end

local function EnsureCollectorFrames()
    if not collectorButton and Minimap then
        collectorButton = CreateFrame("Button", "ZoidsToolsMinimapButtonCollector", Minimap, "BackdropTemplate")
        collectorButton:SetSize(COLLECTOR_SIZE, COLLECTOR_SIZE)
        PositionCollectorButton()
        collectorButton:SetBackdrop({
            bgFile = SQUARE_MASK,
            edgeFile = SQUARE_MASK,
            edgeSize = 1,
        })
        collectorButton:SetBackdropColor(0.02, 0.018, 0.014, 0.92)
        collectorButton:SetBackdropBorderColor(0.85, 0.68, 0.25, 0.75)
        collectorButton:SetMovable(true)
        collectorButton:RegisterForDrag("LeftButton")
        collectorButton:RegisterForClicks("LeftButtonUp")

        collectorButton.icon = collectorButton:CreateTexture(nil, "ARTWORK")
        collectorButton.icon:SetPoint("TOPLEFT", 3, -3)
        collectorButton.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        collectorButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
        collectorButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        collectorButton:SetScript("OnClick", function()
            if collectorButton.justDragged then
                collectorButton.justDragged = false
                return
            end

            if not collectorPanel then
                return
            end

            SetShown(collectorPanel, not collectorPanel:IsShown())
            ns:RefreshMinimapTools()
        end)

        collectorButton:SetScript("OnDragStart", function(self)
            collectorDragAngle = GetCollectorAngle()
            self.dragging = true
            self:LockHighlight()
        end)

        collectorButton:SetScript("OnDragStop", function(self)
            self.dragging = false
            self:UnlockHighlight()
            SetCollectorAngleFromCursor()
            PositionCollectorButton()
            self.justDragged = true
            SaveCollectorPosition()

            if C_Timer and C_Timer.After then
                C_Timer.After(0.1, function()
                    self.justDragged = false
                end)
            end

            if collectorPanel and collectorPanel:IsShown() then
                LayoutCollectorButtons()
            end
        end)

        collectorButton:SetScript("OnUpdate", function(self)
            if not self.dragging then
                return
            end

            SetCollectorAngleFromCursor()
            PositionCollectorButton()

            if collectorPanel and collectorPanel:IsShown() then
                LayoutCollectorButtons()
            end
        end)

        collectorButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("Addon Buttons")
            GameTooltip:AddLine("Click to expand or collapse collected minimap buttons.", 1, 1, 1, true)
            GameTooltip:AddLine("Drag to move this collector.", 0.75, 0.85, 1, true)
            GameTooltip:Show()
        end)

        collectorButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        collectorButton:Hide()
    end

    if not collectorPanel then
        collectorPanel = CreateFrame("Frame", "ZoidsToolsMinimapButtonCollectorPanel", UIParent, "BackdropTemplate")
        collectorPanel:SetFrameStrata("DIALOG")
        collectorPanel:SetClampedToScreen(true)
        collectorPanel:EnableMouse(false)
        collectorPanel:SetBackdrop({
            bgFile = SQUARE_MASK,
            edgeFile = SQUARE_MASK,
            edgeSize = 1,
        })
        collectorPanel:SetBackdropColor(0.025, 0.022, 0.018, 0.32)
        collectorPanel:SetBackdropBorderColor(0.85, 0.68, 0.25, 0.75)
        collectorPanel:SetScript("OnUpdate", function()
            if not IsMouseButtonDown then
                return
            end

            if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) and ShouldCloseCollectorFromOutsideClick() and CloseCollectorPanel then
                CloseCollectorPanel()
            end
        end)
        collectorPanel:Hide()

        collectorContent = CreateFrame("Frame", nil, collectorPanel)
        collectorContent:SetAllPoints(collectorPanel)
        collectorContent:EnableMouse(false)

        if UISpecialFrames then
            table.insert(UISpecialFrames, "ZoidsToolsMinimapButtonCollectorPanel")
        end
    end
end

function CloseCollectorPanel()
    if collectorPanel then
        collectorPanel:Hide()
    end
end

function LayoutCollectorButtons()
    EnsureCollectorFrames()

    if not collectorPanel or not collectorContent then
        return
    end

    local buttons = {}

    for _, button in pairs(trackedButtons) do
        if button and button:GetName() and originalButtonPoints[button:GetName()] then
            buttons[#buttons + 1] = button
        end
    end

    table.sort(buttons, function(left, right)
        return (GetButtonKey(left) or left:GetName() or "") < (GetButtonKey(right) or right:GetName() or "")
    end)

    local columns = math.min(math.max(#buttons, 1), 4)
    local rows = math.max(math.ceil(#buttons / columns), 1)
    local width = (columns * COLLECTED_BUTTON_SIZE) + ((columns + 1) * COLLECTED_BUTTON_GAP)
    local height = (rows * COLLECTED_BUTTON_SIZE) + ((rows + 1) * COLLECTED_BUTTON_GAP)

    collectorPanel:SetSize(width, height)
    collectorPanel:SetFrameLevel((collectorButton:GetFrameLevel() or 10) + 18)
    collectorPanel:ClearAllPoints()
    collectorPanel:SetPoint("RIGHT", collectorButton, "LEFT", -6, 0)
    collectorContent:SetFrameLevel((collectorPanel:GetFrameLevel() or 20) + 6)

    for index, button in ipairs(buttons) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)

        button:SetParent(collectorContent)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", collectorContent, "TOPLEFT", COLLECTED_BUTTON_GAP + (column * (COLLECTED_BUTTON_SIZE + COLLECTED_BUTTON_GAP)), -COLLECTED_BUTTON_GAP - (row * (COLLECTED_BUTTON_SIZE + COLLECTED_BUTTON_GAP)))
        button:SetFrameStrata("DIALOG")
        button:SetFrameLevel(collectorContent:GetFrameLevel() + index)
        button:SetAlpha(1)
        SetShown(button, collectorPanel:IsShown())

        if not collectedButtonClickHooks[button] and button.HookScript then
            collectedButtonClickHooks[button] = true
            button:HookScript("OnClick", CloseCollectorPanelAfterClick)
        end
    end
end

local function ApplyMouseoverButtonVisibility()
    local db = EnsureMinimapDB()
    local show = db and (not db.hideAddonButtons or (Minimap and Minimap:IsMouseOver()))

    for _, button in pairs(trackedButtons) do
        if button and button:GetName() and originalButtonPoints[button:GetName()] then
            local store = originalButtonPoints[button:GetName()]

            button:SetAlpha(show and (store.alpha or 1) or 0)
            SetShown(button, show and store.shown ~= false)
        end
    end
end

local function RestoreCollectedButtons()
    for _, button in pairs(trackedButtons) do
        local name = button and button:GetName()
        local store = name and collectionRestorePoints[name]

        if store or IsButtonInCollector(button) then
            RestoreButton(button, store)
        end
    end

    collectionRestorePoints = {}

    if collectorPanel then
        collectorPanel:Hide()
    end
end

local function ApplyAddonButtons()
    local db = EnsureMinimapDB()

    if not db then
        return
    end

    GatherAddonButtons()
    EnsureCollectorFrames()

    if db.collectAddonButtons then
        CaptureCollectionRestorePositions()

        if collectorButton then
            PositionCollectorButton()
            collectorButton:Show()
        end

        LayoutCollectorButtons()
    else
        if collectorButton then
            collectorButton:Hide()
        end

        RestoreCollectedButtons()

        if db.hideAddonButtons then
            ApplyMouseoverButtonVisibility()
        else
            for _, button in pairs(trackedButtons) do
                if button and button:GetName() and originalButtonPoints[button:GetName()] then
                    local store = originalButtonPoints[button:GetName()]

                    button:SetAlpha(store.alpha or 1)
                    SetShown(button, store.shown ~= false)
                end
            end
        end
    end
end

local function EnsureMouseHooks()
    if mouseHooksInstalled or not Minimap then
        return
    end

    mouseHooksInstalled = true

    Minimap:HookScript("OnEnter", function()
        local db = EnsureMinimapDB()

        if db and db.hideAddonButtons and not db.collectAddonButtons then
            ApplyMouseoverButtonVisibility()
        end
    end)

    Minimap:HookScript("OnLeave", function()
        local db = EnsureMinimapDB()

        if not db or not db.hideAddonButtons or db.collectAddonButtons then
            return
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0.18, ApplyMouseoverButtonVisibility)
        else
            ApplyMouseoverButtonVisibility()
        end
    end)
end

local function ApplyMinimapUnclamp()
    for _, frame in ipairs({ _G.MinimapCluster, _G.Minimap, _G.MinimapBackdrop }) do
        if frame and frame.SetClampedToScreen then
            frame:SetClampedToScreen(false)
        end

        if frame and frame.SetClampRectInsets then
            frame:SetClampRectInsets(0, 0, 0, 0)
        end
    end
end

local function ScheduleMinimapUnclamp()
    ApplyMinimapUnclamp()

    if C_Timer and C_Timer.After then
        C_Timer.After(0, ApplyMinimapUnclamp)
        C_Timer.After(0.5, ApplyMinimapUnclamp)
    end
end

local function ApplyMinimapTools()
    local db = EnsureMinimapDB()

    if not db then
        return
    end

    ScheduleMinimapUnclamp()
    ApplySquareMinimap(db.square == true)
    ApplyInfoBar(db.moveHeader == true)
    ApplyAddonButtons()
end

local function ScheduleRefresh(delay)
    if pendingRefresh then
        return
    end

    pendingRefresh = true

    local function RunRefresh()
        pendingRefresh = false
        ApplyMinimapTools()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.25, RunRefresh)
    else
        RunRefresh()
    end
end

function ns:RefreshMinimapTools()
    ApplyMinimapTools()
end

function ns:SetSquareMinimapEnabled(value)
    local db = EnsureMinimapDB()

    if not db then
        return
    end

    db.square = value == true
    ApplyMinimapTools()
end

function ns:IsSquareMinimapEnabled()
    local db = EnsureMinimapDB()

    return db and db.square == true
end

function ns:SetMinimapHeaderBarEnabled(value)
    local db = EnsureMinimapDB()

    if not db then
        return
    end

    db.moveHeader = value == true
    ApplyMinimapTools()
end

function ns:IsMinimapHeaderBarEnabled()
    local db = EnsureMinimapDB()

    return db and db.moveHeader == true
end

function ns:SetMinimapButtonsMouseoverEnabled(value)
    local db = EnsureMinimapDB()

    if not db then
        return
    end

    db.hideAddonButtons = value == true
    ApplyMinimapTools()
end

function ns:IsMinimapButtonsMouseoverEnabled()
    local db = EnsureMinimapDB()

    return db and db.hideAddonButtons == true
end

function ns:SetMinimapButtonCollectorEnabled(value)
    local db = EnsureMinimapDB()

    if not db then
        return
    end

    db.collectAddonButtons = value == true
    ApplyMinimapTools()
end

function ns:IsMinimapButtonCollectorEnabled()
    local db = EnsureMinimapDB()

    return db and db.collectAddonButtons == true
end

function ns:InitializeMinimapTools()
    EnsureMinimapDB()
    EnsureMouseHooks()
    ApplyMinimapTools()

    if initialized then
        return
    end

    initialized = true
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function()
        ScheduleRefresh(0.35)
    end)

    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            ScheduleRefresh(0)
        end)

        C_Timer.After(4, function()
            ScheduleRefresh(0)
        end)
    end
end
