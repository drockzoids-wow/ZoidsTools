local _, ns = ...

local TRACKER_NAME = "ObjectiveTrackerFrame"
local TRACKER_RIGHT_EXTENSION = 8

local tracker
local skin
local refreshPending = false
local layoutRefreshRequested = true
local applyingLayout = false
local initialized = false
local appearanceWatcher
local originalHeaderBackgroundAlpha
local originalHeaderTextAlpha
local minimizedBackdropAlpha
local knownCollapsed
local lastHeaderControlsAlpha
local ScheduleRefresh

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
    local customClassColors = rawget(_G, "CUSTOM_CLASS_COLORS")
    local color = classFile
        and ((customClassColors and customClassColors[classFile])
            or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))
    if color then return color.r or 1, color.g or 0.82, color.b or 0 end
    return 0.72, 0.50, 0.08
end

local function FindTracker()
    tracker = tracker or _G[TRACKER_NAME]
    return tracker
end

local function CreateSkin()
    local frame = FindTracker()
    if not frame or skin then return skin end

    -- Keep addon-owned decoration out of Blizzard's live objective-tracker
    -- hierarchy. A foreign child can taint the quest-header click that opens
    -- protected MapCanvas providers, where Retail configures pin mouse
    -- passthrough. Anchoring an independent UIParent frame preserves the same
    -- visual bounds without modifying the protected tracker tree.
    skin = CreateFrame("Frame", "ZoidsToolsObjectiveTrackerSkin", UIParent, "BackdropTemplate")
    skin:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
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
    if frame and frame.IsCollapsed then
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
    -- Blizzard keeps its NineSlice visible when all modules collapse. Hide it
    -- cosmetically as well as our independent skin, without triggering layout.
    local backdrop = frame.NineSlice
    if backdrop and backdrop.GetAlpha and backdrop.SetAlpha then
        if minimizeOnly then
            if minimizedBackdropAlpha == nil then
                minimizedBackdropAlpha = backdrop:GetAlpha()
            end
            backdrop:SetAlpha(0)
        elseif minimizedBackdropAlpha ~= nil then
            backdrop:SetAlpha(minimizedBackdropAlpha)
            minimizedBackdropAlpha = nil
        end
    end
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

local function RefreshAppearanceWatcher()
    local db = GetSettings()
    if db and db.enabled then
        if not appearanceWatcher then
            -- Observe from our own frame instead of hooking Blizzard's protected
            -- collapse methods. Only state changes write cosmetic properties.
            appearanceWatcher = CreateFrame("Frame")
        end
        local mouseoverElapsed = 0
        appearanceWatcher:SetScript("OnUpdate", function(_, elapsed)
            local frame = FindTracker()
            local settings = ns.db and ns.db.quests and ns.db.quests.trackerAppearance
            if not frame or not settings or not settings.enabled then return end

            if frame.IsCollapsed then
                local collapsed = frame:IsCollapsed() and true or false
                if collapsed ~= knownCollapsed then
                    knownCollapsed = collapsed
                    ApplyMinimizedHeaderStyle(settings, frame)
                    UpdateMouseoverControls()
                end
            end

            if skin then
                local minimizeOnly = ShouldShowOnlyMinimizeButton(settings, frame)
                local shown = frame:IsShown()
                    and not minimizeOnly
                    and (settings.backgroundOpacity > 0 or settings.borderEnabled)
                if skin:IsShown() ~= shown then skin:SetShown(shown) end
            end
            mouseoverElapsed = mouseoverElapsed + elapsed
            if mouseoverElapsed >= 0.20 then
                mouseoverElapsed = 0
                if ns.RecordDiagnosticActivity then ns:RecordDiagnosticActivity("ObjectiveTracker.MouseoverPoll") end
                UpdateMouseoverControls()
            end
        end)
    elseif appearanceWatcher then
        appearanceWatcher:SetScript("OnUpdate", nil)
    end
end

local function ApplyAppearance()
    refreshPending = false
    if applyingLayout then return end

    local db = GetSettings()
    local frame = FindTracker()
    if not db or not frame then return end

    local refreshBounds = layoutRefreshRequested
    layoutRefreshRequested = false
    applyingLayout = true
    -- Do not resize, scale, re-anchor, or change fonts anywhere in Blizzard's
    -- objective-tracker hierarchy. Its OnSizeChanged handler schedules a
    -- deferred layout; when that layout originates in addon execution, the
    -- scenario module cannot inspect secret aura data in 12.1. Keep all
    -- decoration on the independent UIParent-owned skin below.

    local minimizeOnly = ApplyMinimizedHeaderStyle(db, frame)
    local appearance = CreateSkin()
    if appearance then
        if refreshBounds or db.enabled then
            ApplySkinBounds(appearance, frame, db.enabled and db.fitHeight)
        end
        appearance:SetShown(
            db.enabled
            and frame:IsShown()
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

    applyingLayout = false

    UpdateMouseoverControls()
    RefreshAppearanceWatcher()
end

ApplyAppearance = ns:WrapDiagnosticFunction("ObjectiveTracker.Refresh", ApplyAppearance)

ScheduleRefresh = function(delay, refreshLayout)
    if refreshLayout then layoutRefreshRequested = true end
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
    local needsLayoutRefresh = key == "enabled"
        or key == "fitHeight"
    ScheduleRefresh(0, needsLayoutRefresh)
    return true
end

function ns:GetObjectiveTrackerAppearanceOption(key)
    local db = GetSettings()
    return db and db[key]
end

function ns:SetObjectiveTrackerAppearanceOption(key, value)
    if key == "enabled" or key == "fitHeight" or key == "borderEnabled" or key == "classColoredBorder" or key == "mouseoverControls" or key == "minimizeToButton" then
        value = value == true
    elseif key == "backgroundOpacity" then
        value = Clamp(value, 0, 0.70)
    else
        return false
    end
    return SetOption(key, value)
end

function ns:InitializeObjectiveTrackerAppearance()
    if initialized then return end
    initialized = true

    local frame = FindTracker()
    if frame then
        if frame.IsCollapsed then
            knownCollapsed = frame:IsCollapsed() and true or false
        end
    end

    local events = CreateFrame("Frame")
    for _, eventName in ipairs({
        "PLAYER_ENTERING_WORLD",
        "UI_SCALE_CHANGED",
        "EDIT_MODE_LAYOUTS_UPDATED",
    }) do
        pcall(events.RegisterEvent, events, eventName)
    end
    events:SetScript("OnEvent", function()
        ScheduleRefresh(0, true)
    end)

    ScheduleRefresh(0, true)
end
