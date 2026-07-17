local _, ns = ...

local TRACKER_NAME = "ObjectiveTrackerFrame"
local MIN_WIDTH = 220
local MAX_WIDTH = 420
local MIN_SCALE = 0.70
local MAX_SCALE = 1.30
local MIN_TEXT_SCALE = 0.80
local MAX_TEXT_SCALE = 1.30
local MODULE_LEFT_PADDING = 8
local TRACKER_LEFT_EXTENSION = -24
local TRACKER_RIGHT_EXTENSION = 8
local TRACKER_TOP_EXTENSION = 3
local TRACKER_BOTTOM_PADDING = 6
local EDIT_MODE_SELECTION_X_OFFSET = 10

local tracker
local skin
local originalWidth
local originalScale
local originalFonts = setmetatable({}, { __mode = "k" })
local originalModuleWidths = setmetatable({}, { __mode = "k" })
local originalElementWidths = setmetatable({}, { __mode = "k" })
local originalModuleMargins = setmetatable({}, { __mode = "k" })
local appliedTextScale
local appliedTextEnabled
local appliedTextOutline
local appliedTrackerScale
local appliedTrackerWidth
local textScaleRefreshGeneration = 0
local refreshPending = false
local layoutRefreshRequested = true
local fontRefreshRequested = true
local deferredForCombat = false
local applyingLayout = false
local initialized = false
local mouseoverTicker
local appearanceWasEnabled = false
local preAppearanceWidth
local preAppearanceScale
local previousSavedScale
local originalBottomModulePadding
local originalNineSliceTopLeft
local originalNineSliceTopRight
local originalHeaderBackgroundAlpha
local originalHeaderTextAlpha
local collapseHooked = false
local headerCollapseHooked = false
local selectionAnchorHooked = false
local knownCollapsed
local lastHeaderControlsAlpha
local originalSelectionPoints
local selectionShiftApplied = false

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function GetSettings()
    local quests = ns.db and ns.db.quests
    if not quests then return nil end

    quests.trackerAppearance = quests.trackerAppearance or {}
    local db = quests.trackerAppearance
    if db.enabled == nil then db.enabled = false end
    db.scale = Clamp(db.scale or 1, MIN_SCALE, MAX_SCALE)
    db.width = Clamp(db.width or 280, MIN_WIDTH, MAX_WIDTH)
    db.textScale = Clamp(db.textScale or 1, MIN_TEXT_SCALE, MAX_TEXT_SCALE)
    if db.outlineText == nil then db.outlineText = false end
    if db.fitHeight == nil then db.fitHeight = true end
    db.backgroundOpacity = Clamp(db.backgroundOpacity or 0, 0, 0.70)
    if db.borderEnabled == nil then db.borderEnabled = false end
    if db.classColoredBorder == nil then db.classColoredBorder = true end
    if db.mouseoverControls == nil then db.mouseoverControls = false end
    if db.minimizeToButton == nil then db.minimizeToButton = false end
    return db
end

local function GetClassColor()
    local _, classFile = UnitClass("player")
    local color = classFile
        and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
            or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))
    if color then return color.r or 1, color.g or 0.82, color.b or 0 end
    return 0.72, 0.50, 0.08
end

local function FindTracker()
    tracker = tracker or _G[TRACKER_NAME]
    if tracker and not originalWidth then
        originalWidth = tracker.GetWidth and tracker:GetWidth() or 280
        originalScale = tracker.GetScale and tracker:GetScale() or 1
    end
    return tracker
end

local function CreateSkin()
    local frame = FindTracker()
    if not frame or skin then return skin end

    skin = CreateFrame("Frame", "ZoidsToolsObjectiveTrackerSkin", frame, "BackdropTemplate")
    -- Blizzard's tracker background extends beyond the internal container
    -- frame (notably 30 px to the left), and Edit Mode uses those visible
    -- background bounds for its selection outline. Anchor to that same native
    -- NineSlice so the ZoidsTools border and Edit Mode highlight coincide.
    skin:SetFrameLevel(math.max(0, (frame:GetFrameLevel() or 1) - 1))
    skin:EnableMouse(false)
    skin:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    return skin
end

local function ApplySkinBounds(appearance, frame, fitToContent)
    if not appearance or not frame then return end

    local contentBounds = frame.NineSlice or frame
    appearance:ClearAllPoints()
    appearance:SetPoint("TOPLEFT", contentBounds, "TOPLEFT", 0, 0)
    if fitToContent and frame.NineSlice then
        appearance:SetPoint("BOTTOMRIGHT", frame.NineSlice, "BOTTOMRIGHT", 0, 0)
    else
        -- Keep the customized horizontal extensions while allowing users who
        -- disable fitting to retain Blizzard's full tracker-height backdrop.
        appearance:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", TRACKER_RIGHT_EXTENSION, 0)
    end
end

local function CaptureAnchor(frame, targetPoint)
    if not frame or not frame.GetNumPoints then return nil end
    for index = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(index)
        if point == targetPoint then
            return {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                offsetX = offsetX,
                offsetY = offsetY,
            }
        end
    end
    return nil
end

local function RestoreAnchor(frame, anchor)
    if not frame or not anchor then return end
    frame:SetPoint(
        anchor.point,
        anchor.relativeTo,
        anchor.relativePoint,
        anchor.offsetX,
        anchor.offsetY
    )
end

local function CapturePoints(frame)
    if not frame or not frame.GetNumPoints then return nil end
    local points = {}
    for index = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(index)
        points[#points + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            offsetX = offsetX or 0,
            offsetY = offsetY or 0,
        }
    end
    return #points > 0 and points or nil
end

local function SetPoints(frame, points, offsetX)
    if not frame or not points then return end
    frame:ClearAllPoints()
    for _, anchor in ipairs(points) do
        frame:SetPoint(
            anchor.point,
            anchor.relativeTo,
            anchor.relativePoint,
            anchor.offsetX + (offsetX or 0),
            anchor.offsetY
        )
    end
end

local function ApplyEditModeSelectionBounds(frame, enabled, force)
    local selection = frame and frame.Selection
    if not selection then return end

    if not originalSelectionPoints then
        originalSelectionPoints = CapturePoints(selection)
    end
    if not originalSelectionPoints then return end

    if enabled then
        if selectionShiftApplied and not force then return end
        SetPoints(selection, originalSelectionPoints, EDIT_MODE_SELECTION_X_OFFSET)
        selectionShiftApplied = true
    elseif selectionShiftApplied then
        SetPoints(selection, originalSelectionPoints, 0)
        selectionShiftApplied = false
    end
end

local function ApplyTrackerBackgroundBounds(frame, enabled)
    if not frame then return end

    if originalBottomModulePadding == nil then
        originalBottomModulePadding = tonumber(frame.bottomModulePadding) or 10
    end

    local nineSlice = frame.NineSlice
    if nineSlice then
        originalNineSliceTopLeft = originalNineSliceTopLeft or CaptureAnchor(nineSlice, "TOPLEFT")
        originalNineSliceTopRight = originalNineSliceTopRight or CaptureAnchor(nineSlice, "TOPRIGHT")

        if enabled then
            nineSlice:SetPoint("TOPLEFT", frame, "TOPLEFT", TRACKER_LEFT_EXTENSION, TRACKER_TOP_EXTENSION)
            nineSlice:SetPoint("TOPRIGHT", frame, "TOPRIGHT", TRACKER_RIGHT_EXTENSION, TRACKER_TOP_EXTENSION)
        else
            RestoreAnchor(nineSlice, originalNineSliceTopLeft)
            RestoreAnchor(nineSlice, originalNineSliceTopRight)
        end
    end

    frame.bottomModulePadding = enabled and TRACKER_BOTTOM_PADDING or originalBottomModulePadding
end

local function VisitFontStrings(root, callback, visited)
    if not root or not callback then return end
    visited = visited or {}
    if visited[root] then return end
    visited[root] = true

    if root.GetRegions then
        for _, region in ipairs({ root:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                callback(region)
            end
        end
    end

    if root.GetChildren then
        for _, child in ipairs({ root:GetChildren() }) do
            VisitFontStrings(child, callback, visited)
        end
    end
end

local function AddOutlineFlag(flags)
    flags = flags or ""
    if flags:find("OUTLINE", 1, true) then return flags end
    return flags == "" and "OUTLINE" or (flags .. ",OUTLINE")
end

local function ApplyTextScale(enabled, scale, outlineText, force)
    local frame = FindTracker()
    if not frame then return end
    if not force
        and appliedTextEnabled == enabled
        and appliedTextScale == scale
        and appliedTextOutline == outlineText then
        return
    end

    appliedTextEnabled = enabled
    appliedTextScale = scale
    appliedTextOutline = outlineText

    local changed = false
    VisitFontStrings(frame, function(fontString)
        local original = originalFonts[fontString]
        if not original and fontString.GetFont then
            local path, size, flags = fontString:GetFont()
            if path and size then
                original = { path = path, size = size, flags = flags }
                originalFonts[fontString] = original
            end
        end

        if original and fontString.SetFont then
            local size = enabled and (original.size * scale) or original.size
            local flags = original.flags
            if enabled and outlineText then
                flags = AddOutlineFlag(flags)
            end

            local currentPath, currentSize, currentFlags = fontString:GetFont()
            local sameSize = type(currentSize) == "number"
                and math.abs(currentSize - size) < 0.01
            if currentPath ~= original.path
                or not sameSize
                or (currentFlags or "") ~= (flags or "") then
                local ok = pcall(fontString.SetFont, fontString, original.path, size, flags)
                changed = changed or ok
            end
        end
    end)

    -- Blizzard measures line and block heights during its native layout pass.
    -- Marking the container dirty lets it recalculate those heights using the
    -- adjusted fonts instead of leaving enlarged text inside old row bounds.
    if changed and frame.MarkDirty then pcall(frame.MarkDirty, frame) end
end

local function ApplyModuleWidths(frame, enabled, width)
    if not frame then return end

    local function ResizeElement(element, targetWidth)
        if not element or not element.GetWidth or not element.SetWidth then return end
        if originalElementWidths[element] == nil then
            originalElementWidths[element] = element:GetWidth()
        end
        pcall(element.SetWidth, element, enabled and targetWidth or originalElementWidths[element])
    end

    local function ResizeHeader(header, targetWidth)
        if not header then return end

        if originalElementWidths[header] == nil and header.GetWidth then
            originalElementWidths[header] = header:GetWidth()
        end
        local originalHeaderWidth = originalElementWidths[header] or targetWidth
        ResizeElement(header, targetWidth)

        -- These regions have their own fixed template sizes and do not inherit
        -- the Header frame's new width.  Preserve their original right-side
        -- spacing while allowing the visible header treatment to expand.
        if header.Background then
            ResizeElement(header.Background, targetWidth)
        end
        if header.Text and header.Text.GetWidth then
            if originalElementWidths[header.Text] == nil then
                originalElementWidths[header.Text] = header.Text:GetWidth()
            end
            local originalTextWidth = originalElementWidths[header.Text] or targetWidth
            local rightSideSpacing = math.max(0, originalHeaderWidth - originalTextWidth)
            ResizeElement(header.Text, math.max(1, targetWidth - rightSideSpacing))
        end
    end

    local function ResizeModule(module)
        if not module or not module.GetWidth or not module.SetWidth then return end

        if originalModuleWidths[module] == nil then
            originalModuleWidths[module] = module:GetWidth()
        end
        if originalModuleMargins[module] == nil then
            originalModuleMargins[module] = tonumber(module.leftMargin) or 0
        end

        local originalMargin = originalModuleMargins[module] or 0
        module.leftMargin = enabled and (originalMargin + MODULE_LEFT_PADDING) or originalMargin

        local targetWidth = originalModuleWidths[module]
        if enabled then
            -- Blizzard anchors each objective module from its own left margin,
            -- but leaves the module at its template's fixed width.  Subtracting
            -- that margin keeps the module's right edge flush with the resized
            -- container instead of extending beyond it.
            targetWidth = math.max(1, width - (tonumber(module.leftMargin) or 0))
        end

        pcall(module.SetWidth, module, targetWidth)
        ResizeHeader(module.Header, targetWidth)
    end

    ResizeHeader(frame.Header, width)

    if frame.ForEachModule then
        pcall(frame.ForEachModule, frame, ResizeModule)
    elseif type(frame.modules) == "table" then
        for _, module in ipairs(frame.modules) do
            ResizeModule(module)
        end
    end
end

local function VisitButtons(root, callback, visited)
    if not root or not callback then return end
    visited = visited or {}
    if visited[root] then return end
    visited[root] = true

    if root.GetObjectType and root:GetObjectType() == "Button" then callback(root) end
    if root.GetChildren then
        for _, child in ipairs({ root:GetChildren() }) do
            VisitButtons(child, callback, visited)
        end
    end
end

local function SetHeaderControlsAlpha(alpha)
    if lastHeaderControlsAlpha == alpha then return end
    lastHeaderControlsAlpha = alpha
    local frame = FindTracker()
    if not frame then return end
    local header = frame.Header or frame.HeaderMenu
    if not header then return end
    VisitButtons(header, function(button)
        if button.SetAlpha then button:SetAlpha(alpha) end
    end)
end

local function ShouldShowOnlyMinimizeButton(db, frame)
    local collapsed = knownCollapsed
    if collapsed == nil and frame and frame.IsCollapsed then
        collapsed = frame:IsCollapsed() and true or false
    end
    return db
        and db.enabled
        and db.minimizeToButton
        and frame
        and collapsed == true
end

local function ApplyMinimizedHeaderStyle(db, frame)
    local header = frame and frame.Header
    if not header then return false end

    local background = header.Background
    local text = header.Text
    if background and originalHeaderBackgroundAlpha == nil and background.GetAlpha then
        originalHeaderBackgroundAlpha = background:GetAlpha()
    end
    if text and originalHeaderTextAlpha == nil and text.GetAlpha then
        originalHeaderTextAlpha = text:GetAlpha()
    end

    local minimizeOnly = ShouldShowOnlyMinimizeButton(db, frame)
    if background and background.SetAlpha then
        background:SetAlpha(minimizeOnly and 0 or (originalHeaderBackgroundAlpha or 1))
    end
    if text and text.SetAlpha then
        text:SetAlpha(minimizeOnly and 0 or (originalHeaderTextAlpha or 1))
    end
    return minimizeOnly
end

local function UpdateMouseoverControls()
    local db = GetSettings()
    local frame = FindTracker()
    if not db or not frame then return end

    if ShouldShowOnlyMinimizeButton(db, frame) then
        -- A fully collapsed tracker has no other visual affordance, so keep
        -- Blizzard's restore button readable even when mouseover fading is on.
        SetHeaderControlsAlpha(1)
    elseif db.enabled and db.mouseoverControls then
        local hovered = frame.IsMouseOver and frame:IsMouseOver()
        SetHeaderControlsAlpha(hovered and 1 or 0.12)
    else
        SetHeaderControlsAlpha(1)
    end
end

local function RefreshMouseoverTicker()
    local db = GetSettings()
    local shouldRun = db and db.enabled and db.mouseoverControls
    if shouldRun and not mouseoverTicker and C_Timer and C_Timer.NewTicker then
        mouseoverTicker = C_Timer.NewTicker(0.20, UpdateMouseoverControls)
    elseif not shouldRun and mouseoverTicker then
        mouseoverTicker:Cancel()
        mouseoverTicker = nil
    end
end

local function ApplyAppearance()
    refreshPending = false
    if applyingLayout then return end

    local db = GetSettings()
    local frame = FindTracker()
    if not db or not frame then return end

    if InCombatLockdown and InCombatLockdown() then
        deferredForCombat = true
        return
    end
    deferredForCombat = false
    local forceLayoutRefresh = layoutRefreshRequested
    layoutRefreshRequested = false

    applyingLayout = true
    if db.enabled then
        local enabling = not appearanceWasEnabled
        local scaleChanged = enabling
            or forceLayoutRefresh
            or appliedTrackerScale ~= db.scale
        local widthChanged = enabling
            or forceLayoutRefresh
            or appliedTrackerWidth ~= db.width
        if enabling then
            preAppearanceWidth = frame.GetWidth and frame:GetWidth() or originalWidth
            preAppearanceScale = frame.GetScale and frame:GetScale() or originalScale
            previousSavedScale = ns.db.windows
                and ns.db.windows.scales
                and ns.db.windows.scales[TRACKER_NAME]
            appearanceWasEnabled = true
        end

        if scaleChanged then
            frame.ZTApplyingScale = true
            pcall(frame.SetScale, frame, db.scale)
            frame.ZTApplyingScale = nil
            appliedTrackerScale = db.scale
        end
        if widthChanged then
            pcall(frame.SetWidth, frame, db.width)
            ApplyModuleWidths(frame, true, db.width)
            appliedTrackerWidth = db.width
        end
        if enabling or forceLayoutRefresh then
            ApplyTrackerBackgroundBounds(frame, true)
        end

        if scaleChanged then
            ns.db.windows = ns.db.windows or {}
            ns.db.windows.scales = ns.db.windows.scales or {}
            ns.db.windows.scales[TRACKER_NAME] = db.scale
        end
    elseif appearanceWasEnabled then
        ApplyModuleWidths(frame, false, preAppearanceWidth or originalWidth)
        ApplyTrackerBackgroundBounds(frame, false)
        if preAppearanceWidth then pcall(frame.SetWidth, frame, preAppearanceWidth) end
        if preAppearanceScale then
            frame.ZTApplyingScale = true
            pcall(frame.SetScale, frame, preAppearanceScale)
            frame.ZTApplyingScale = nil
        end
        ns.db.windows = ns.db.windows or {}
        ns.db.windows.scales = ns.db.windows.scales or {}
        ns.db.windows.scales[TRACKER_NAME] = previousSavedScale
        appearanceWasEnabled = false
        appliedTrackerScale = nil
        appliedTrackerWidth = nil
    end
    applyingLayout = false

    ApplyTextScale(
        db.enabled,
        db.textScale,
        db.outlineText,
        forceLayoutRefresh or fontRefreshRequested
    )
    fontRefreshRequested = false
    ApplyEditModeSelectionBounds(frame, db.enabled, forceLayoutRefresh)

    local minimizeOnly = ApplyMinimizedHeaderStyle(db, frame)
    local appearance = CreateSkin()
    if appearance then
        if forceLayoutRefresh then
            ApplySkinBounds(appearance, frame, db.enabled and db.fitHeight)
        end
        appearance:SetShown(
            db.enabled
            and not minimizeOnly
            and (db.backgroundOpacity > 0 or db.borderEnabled)
        )
        if db.enabled then
            local red, green, blue = 0.72, 0.50, 0.08
            if db.classColoredBorder then red, green, blue = GetClassColor() end
            appearance:SetBackdropColor(0.008, 0.010, 0.016, db.backgroundOpacity)
            appearance:SetBackdropBorderColor(red, green, blue, db.borderEnabled and 0.92 or 0)
        end
    end

    UpdateMouseoverControls()
    RefreshMouseoverTicker()
end

ApplyAppearance = ns:WrapDiagnosticFunction("ObjectiveTracker.Refresh", ApplyAppearance)

local function ScheduleRefresh(delay, refreshLayout, refreshFonts)
    if refreshLayout then layoutRefreshRequested = true end
    if refreshFonts then fontRefreshRequested = true end
    if refreshPending then return end
    refreshPending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, ApplyAppearance)
    else
        ApplyAppearance()
    end
end

local function SetOption(key, value)
    local db = GetSettings()
    if not db or db[key] == nil then return false end
    db[key] = value

    if key == "textScale" then
        -- Blizzard recalculates every objective line and then runs its managed
        -- frame positioning after a font change. Debounce slider motion so it
        -- performs that expensive layout once after the user pauses instead
        -- of moving between managed positions for every intermediate value.
        textScaleRefreshGeneration = textScaleRefreshGeneration + 1
        local generation = textScaleRefreshGeneration
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, function()
                if generation == textScaleRefreshGeneration then
                    ScheduleRefresh(0, false, true)
                end
            end)
        else
            ScheduleRefresh(0, false, true)
        end
        return true
    end

    local needsLayoutRefresh = key == "enabled"
        or key == "scale"
        or key == "width"
        or key == "fitHeight"
    ScheduleRefresh(0, needsLayoutRefresh)
    return true
end

function ns:GetObjectiveTrackerAppearanceOption(key)
    local db = GetSettings()
    return db and db[key]
end

function ns:SetObjectiveTrackerAppearanceOption(key, value)
    if key == "enabled" or key == "fitHeight" or key == "outlineText" or key == "borderEnabled" or key == "classColoredBorder" or key == "mouseoverControls" or key == "minimizeToButton" then
        value = value == true
    elseif key == "scale" then
        value = Clamp(value, MIN_SCALE, MAX_SCALE)
    elseif key == "width" then
        value = Clamp(value, MIN_WIDTH, MAX_WIDTH)
    elseif key == "textScale" then
        value = Clamp(value, MIN_TEXT_SCALE, MAX_TEXT_SCALE)
    elseif key == "backgroundOpacity" then
        value = Clamp(value, 0, 0.70)
    else
        return false
    end
    return SetOption(key, value)
end

function ns:RefreshObjectiveTrackerAppearance()
    ScheduleRefresh(0, true, true)
end

function ns:InitializeObjectiveTrackerAppearance()
    if initialized then return end
    initialized = true

    local frame = FindTracker()
    if frame then
        if frame.IsCollapsed then
            knownCollapsed = frame:IsCollapsed() and true or false
        end
        frame:HookScript("OnShow", function() ScheduleRefresh(0, true, true) end)
        if hooksecurefunc and frame.SetCollapsed and not collapseHooked then
            collapseHooked = true
            hooksecurefunc(frame, "SetCollapsed", function(_, collapsed)
                knownCollapsed = collapsed and true or false
                ScheduleRefresh(0, false)
            end)
        end
        local header = frame.Header
        if hooksecurefunc and header and header.SetCollapsed and not headerCollapseHooked then
            headerCollapseHooked = true
            hooksecurefunc(header, "SetCollapsed", function(_, collapsed)
                knownCollapsed = collapsed and true or false
                ScheduleRefresh(0, false)
            end)
        end
        if hooksecurefunc and frame.AddModule then
            hooksecurefunc(frame, "AddModule", function()
                ScheduleRefresh(0, true, true)
            end)
        end
        if hooksecurefunc and frame.AnchorSelectionFrame and not selectionAnchorHooked then
            selectionAnchorHooked = true
            hooksecurefunc(frame, "AnchorSelectionFrame", function(self)
                local db = GetSettings()
                if db and db.enabled then
                    ApplyEditModeSelectionBounds(self, true, true)
                end
            end)
        end
    end

    local events = CreateFrame("Frame")
    for _, eventName in ipairs({
        "PLAYER_ENTERING_WORLD",
        "PLAYER_REGEN_ENABLED",
        "QUEST_LOG_UPDATE",
        "TRACKED_ACHIEVEMENT_UPDATE",
        "SCENARIO_UPDATE",
        "UI_SCALE_CHANGED",
        "EDIT_MODE_LAYOUTS_UPDATED",
    }) do
        pcall(events.RegisterEvent, events, eventName)
    end
    events:SetScript("OnEvent", function(_, eventName)
        if eventName == "PLAYER_REGEN_ENABLED" then
            if not deferredForCombat then return end
            deferredForCombat = false
            ScheduleRefresh(0, false, false)
            return
        end

        if eventName == "QUEST_LOG_UPDATE"
            or eventName == "TRACKED_ACHIEVEMENT_UPDATE"
            or eventName == "SCENARIO_UPDATE" then
            local db = GetSettings()
            if not db or not db.enabled then return end
            ScheduleRefresh(0.08, false, true)
            return
        end

        ScheduleRefresh(0, true, true)
    end)

    ScheduleRefresh(0, true, true)
end
