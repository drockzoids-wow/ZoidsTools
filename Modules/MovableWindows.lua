local _, ns = ...

local movableFrames = {}
local windowHandles = {}
local bagFrames = {}
local bagHandles = {}
local windowsRegistered = false
local bagWatcher
local panelRefreshQueued = false
local bagRefreshQueued = false
local RestoreOriginalPoint

local blockedFrames = {
    AlertFrame = true,
    BuffFrame = true,
    ChatFrame1 = true,
    CompactRaidFrameManager = true,
    ContainerFrameCombinedBags = true,
    HouseEditorFrame = true,
    LossOfControlFrame = true,
    MainMenuBar = true,
    MinimapCluster = true,
    ObjectiveTrackerFrame = true,
    PlayerFrame = true,
    TargetFrame = true,
    UIParent = true,
}

local bagHandleAllowedFrames = {
    ContainerFrameCombinedBags = true,
}

local commonFrames = {
    "AchievementFrame",
    "ArchaeologyFrame",
    "AuctionHouseFrame",
    "BankFrame",
    "CalendarFrame",
    "CharacterFrame",
    "CollectionsJournal",
    "CommunitiesFrame",
    "EncounterJournal",
    "FriendsFrame",
    "GameMenuFrame",
    "GossipFrame",
    "GuildFrame",
    "InspectFrame",
    "ItemTextFrame",
    "ItemUpgradeFrame",
    "LFGDungeonReadyPopup",
    "LootFrame",
    "MailFrame",
    "MerchantFrame",
    "OpenMailFrame",
    "PlayerSpellsFrame",
    "PlayerTalentFrame",
    "ProfessionsFrame",
    "ProfessionsBookFrame",
    "PVEFrame",
    "PVPQueueFrame",
    "QuestFrame",
    "QuestLogPopupDetailFrame",
    "ReforgingFrame",
    "ScrappingMachineFrame",
    "SpellBookFrame",
    "SubscriptionInterstitialFrame",
    "TimeManagerFrame",
    "TradeFrame",
    "TradeSkillFrame",
    "TransmogrifyFrame",
    "WardrobeFrame",
    "WeeklyRewardsFrame",
    "WorldMapFrame",
    "ClassTalentFrame",
    "MajorFactionRenownFrame",
    "GenericTraitFrame",
}

local knownBagFrames = {
    "ContainerFrameCombinedBags",
    "ContainerFrame1",
    "ContainerFrame2",
    "ContainerFrame3",
    "ContainerFrame4",
    "ContainerFrame5",
    "ContainerFrame6",
    "ContainerFrame7",
    "ContainerFrame8",
    "ContainerFrame9",
    "ContainerFrame10",
    "ContainerFrame11",
    "ContainerFrame12",
    "ContainerFrame13",
    "ContainerFrame14",
    "ContainerFrame15",
    "ContainerFrame16",
    "ContainerFrame17",
    "ContainerFrame18",
    "ContainerFrame19",
    "ContainerFrame20",
    "ReagentBankFrame",
    "AccountBankPanel",
    "WarbandBankFrame",
}

local function SafeCall(method, frame, ...)
    if type(method) ~= "function" then
        return false
    end

    return pcall(method, frame, ...)
end

local function SetManagedPlacement(frame, value)
    if frame.SetUserPlaced then
        SafeCall(frame.SetUserPlaced, frame, value == true)
    end

    if frame.SetDontSavePosition then
        SafeCall(frame.SetDontSavePosition, frame, value == true)
    end
end

local function GetFrameName(frame)
    return frame and frame.GetName and frame:GetName()
end

local function IsBlockedFrameName(name, isBagWindow)
    return name and blockedFrames[name] == true and not (isBagWindow and bagHandleAllowedFrames[name])
end

local function IsBlockedFrame(frame, isBagWindow)
    return IsBlockedFrameName(GetFrameName(frame), isBagWindow)
end

local function ClearSavedWindowState(name)
    if not name or not ns.db or not ns.db.windows then
        return
    end

    if ns.db.windows.points then
        ns.db.windows.points[name] = nil
    end

    if ns.db.windows.scales then
        ns.db.windows.scales[name] = nil
    end
end

local function ClearBlockedWindowState()
    for name in pairs(blockedFrames) do
        if not bagHandleAllowedFrames[name] then
            ClearSavedWindowState(name)
        end
    end
end

local function IsUsableFrame(frame)
    local name = GetFrameName(frame)

    return frame
        and name
        and not IsBlockedFrameName(name)
        and frame.SetMovable
        and frame.SetClampedToScreen
        and frame.EnableMouse
        and frame.RegisterForDrag
        and frame.HookScript
        and frame.GetNumPoints
        and frame.GetPoint
end

local function CaptureOriginalPoints(frame, isBagWindow)
    if IsBlockedFrame(frame, isBagWindow) then
        return
    end

    if not frame.ZTOriginalScale and frame.GetScale then
        frame.ZTOriginalScale = frame:GetScale() or 1
    end

    if frame.ZTOriginalPoints and #frame.ZTOriginalPoints > 0 then
        return
    end

    local pointCount = frame:GetNumPoints()

    if pointCount == 0 then
        return
    end

    frame.ZTOriginalPoints = {}

    for index = 1, pointCount do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
        frame.ZTOriginalPoints[index] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
end

local function SavePoint(frame, isBagWindow)
    if not ns.db or not ns.db.windows.savePositions or InCombatLockdown() then
        return
    end

    local name = GetFrameName(frame)
    if not name then
        return
    end

    if IsBlockedFrameName(name, isBagWindow) then
        ClearSavedWindowState(name)
        return
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then
        return
    end

    ns.db.windows.points[name] = {
        point = point,
        relativeTo = relativeTo and relativeTo.GetName and relativeTo:GetName() or "UIParent",
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function HasSavedPoint(frame, isBagWindow)
    local name = GetFrameName(frame)

    if IsBlockedFrameName(name, isBagWindow) then
        ClearSavedWindowState(name)
        return false
    end

    return ns.db
        and ns.db.windows.savePositions
        and ns.db.windows.points
        and name
        and ns.db.windows.points[name] ~= nil
end

local function ClampScale(value)
    local minScale = ns.db and ns.db.windows.minScale or 0.6
    local maxScale = ns.db and ns.db.windows.maxScale or 1.8

    value = tonumber(value) or 1

    if value < minScale then
        return minScale
    elseif value > maxScale then
        return maxScale
    end

    return value
end

local function GetFrameScale(frame)
    if not frame or not frame.GetScale then
        return 1
    end

    return frame:GetScale() or 1
end

local function GetOriginalScale(frame)
    return frame and frame.ZTOriginalScale or 1
end

local function ApplyScale(frame, scale, save, isBagWindow)
    if not frame or not frame.SetScale or InCombatLockdown() then
        return false
    end

    local name = GetFrameName(frame)

    if not name then
        return false
    end

    if IsBlockedFrameName(name, isBagWindow) then
        ClearSavedWindowState(name)
        return false
    end

    scale = ClampScale(scale)

    if save then
        ns.db.windows.scales = ns.db.windows.scales or {}
        ns.db.windows.scales[name] = scale
    end

    frame.ZTApplyingScale = true
    local ok = SafeCall(frame.SetScale, frame, scale)
    frame.ZTApplyingScale = nil

    if not ok then
        return false
    end

    return true
end

local function ApplySavedScale(frame, isBagWindow)
    if not ns.db or not frame or IsBlockedFrame(frame, isBagWindow) then
        return
    end

    local name = GetFrameName(frame)
    local saved = name and ns.db.windows.scales and ns.db.windows.scales[name]

    if saved then
        ApplyScale(frame, saved, false, isBagWindow)
    end
end

local function HasSavedScale(frame, isBagWindow)
    local name = GetFrameName(frame)

    if IsBlockedFrameName(name, isBagWindow) then
        ClearSavedWindowState(name)
        return false
    end

    return ns.db
        and ns.db.windows.scales
        and name
        and ns.db.windows.scales[name] ~= nil
end

local function ApplySavedScaleSoon(frame, isBagWindow)
    if not frame or IsBlockedFrame(frame, isBagWindow) then
        return
    end

    if not HasSavedScale(frame, isBagWindow) then
        return
    end

    ApplySavedScale(frame, isBagWindow)

    if not C_Timer or not C_Timer.After or frame.ZTScaleRestoreQueued then
        return
    end

    frame.ZTScaleRestoreQueued = true

    C_Timer.After(0, function()
        frame.ZTScaleRestoreQueued = nil
        ApplySavedScale(frame, isBagWindow)
    end)

    C_Timer.After(0.05, function()
        ApplySavedScale(frame, isBagWindow)
    end)

    C_Timer.After(0.2, function()
        ApplySavedScale(frame, isBagWindow)
    end)
end

local function HookFrameSetScale(frame, isBagWindow)
    if IsBlockedFrame(frame, isBagWindow) or frame.ZTSetScaleHooked or not frame.SetScale then
        return
    end

    local ok = pcall(hooksecurefunc, frame, "SetScale", function(self)
        if self.ZTApplyingScale then
            return
        end

        if IsBlockedFrame(self, isBagWindow) then
            return
        end

        local name = GetFrameName(self)
        local saved = name and ns.db and ns.db.windows.scales and ns.db.windows.scales[name]

        if saved then
            ApplySavedScaleSoon(self, isBagWindow)
        end
    end)

    if ok then
        frame.ZTSetScaleHooked = true
    end
end

local function ResetFrameScale(frame, notify, isBagWindow)
    if not ns.db or not frame then
        return
    end

    local name = GetFrameName(frame)

    if not name then
        return
    end

    if IsBlockedFrameName(name, isBagWindow) then
        ClearSavedWindowState(name)
        return
    end

    if ns.db.windows.scales then
        ns.db.windows.scales[name] = nil
    end

    frame.ZTApplyingScale = true
    local didReset = ApplyScale(frame, GetOriginalScale(frame), false, isBagWindow)
    frame.ZTApplyingScale = nil

    if didReset and notify then
        ns:Print(name .. " scale reset.")
    end
end

local function AdjustFrameScale(frame, delta, isBagWindow)
    if not ns.db
        or not ns.db.windows.enabled
        or not ns.db.windows.scaleEnabled
        or not frame
        or IsBlockedFrame(frame, isBagWindow)
        or InCombatLockdown()
    then
        return
    end

    local step = ns.db.windows.scaleStep or 0.05
    local scale = GetFrameScale(frame) + ((delta or 0) > 0 and step or -step)

    if ApplyScale(frame, scale, true, isBagWindow) then
        SavePoint(frame, isBagWindow)
    end
end

local function RelayoutContainerFrames()
    local layoutFunctions = {
        "UpdateContainerFrameAnchors",
        "ContainerFrame_UpdateContainerFrameAnchors",
        "ContainerFrame_UpdateAll",
    }

    for _, functionName in ipairs(layoutFunctions) do
        if type(_G[functionName]) == "function" then
            pcall(_G[functionName])
        end
    end
end

local function RelayoutUIPanelFrames(frame)
    local layoutFunctions = {
        "UpdateUIPanelPositions",
        "UIParent_ManageFramePositions",
    }

    if frame then
        frame.ZTRestoringPoint = true
    end

    for _, functionName in ipairs(layoutFunctions) do
        if type(_G[functionName]) == "function" then
            pcall(_G[functionName], frame)
        end
    end

    if frame then
        frame.ZTRestoringPoint = nil
    end
end

local function ShowPanelFrame(frame)
    if not frame or frame:IsShown() then
        return
    end

    if type(ShowUIPanel) == "function" then
        local ok = pcall(ShowUIPanel, frame)

        if ok and frame:IsShown() then
            return
        end
    end

    SafeCall(frame.Show, frame)
end

local function ResetPanelFramePosition(frame)
    if not frame or InCombatLockdown() then
        return false
    end

    local wasShown = frame:IsShown()
    local restored = false

    SetManagedPlacement(frame, false)

    if wasShown and RestoreOriginalPoint then
        restored = RestoreOriginalPoint(frame, false)
    end

    RelayoutUIPanelFrames(frame)

    if wasShown then
        ShowPanelFrame(frame)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            SetManagedPlacement(frame, false)
            RelayoutUIPanelFrames(frame)

            if wasShown then
                ShowPanelFrame(frame)
            end
        end)

        C_Timer.After(0.05, function()
            SetManagedPlacement(frame, false)
            RelayoutUIPanelFrames(frame)

            if wasShown then
                ShowPanelFrame(frame)
            end
        end)
    end

    return restored or true
end

local function ResetFramePosition(frame, notify, useOriginalPoint)
    if not ns.db or not frame then
        return
    end

    local name = GetFrameName(frame)
    local isBagWindow = useOriginalPoint == "bag"

    if not name then
        return
    end

    if IsBlockedFrameName(name, isBagWindow) then
        ClearSavedWindowState(name)
        return
    end

    local now = GetTime and GetTime() or 0

    if frame.ZTLastPositionReset and now > 0 and now - frame.ZTLastPositionReset < 0.25 then
        return
    end

    frame.ZTLastPositionReset = now

    if ns.db.windows.points then
        ns.db.windows.points[name] = nil
    end

    if useOriginalPoint == "bag" and not InCombatLockdown() then
        SetManagedPlacement(frame, false)
        RelayoutContainerFrames()

        if C_Timer and C_Timer.After then
            C_Timer.After(0, RelayoutContainerFrames)
            C_Timer.After(0.05, RelayoutContainerFrames)
        end
    elseif useOriginalPoint == "panel" then
        ResetPanelFramePosition(frame)
    elseif useOriginalPoint and RestoreOriginalPoint then
        RestoreOriginalPoint(frame, true)
    elseif frame:IsShown() and not InCombatLockdown() then
        frame.ZTRestoringPoint = true
        SafeCall(frame.ClearAllPoints, frame)
        SafeCall(frame.SetPoint, frame, "CENTER", UIParent, "CENTER", 0, 0)
        frame.ZTRestoringPoint = nil
        SetManagedPlacement(frame, true)
    end

    if notify then
        ns:Print(name .. " position reset.")
    end
end

local function EnableMouseWheel(frame)
    if not frame then
        return
    end

    if frame.SetMouseWheelEnabled then
        SafeCall(frame.SetMouseWheelEnabled, frame, true)
    elseif frame.EnableMouseWheel then
        SafeCall(frame.EnableMouseWheel, frame, true)
    end
end

local function AddScaleScripts(inputFrame, targetFrame, allowPositionReset, resetToOriginalPoint, isBagWindow)
    if not inputFrame or inputFrame.ZTScaleScriptsHooked or IsBlockedFrame(targetFrame, isBagWindow) then
        return
    end

    inputFrame.ZTScaleScriptsHooked = true
    EnableMouseWheel(inputFrame)

    inputFrame:HookScript("OnMouseWheel", function(_, delta)
        if IsControlKeyDown and IsControlKeyDown() then
            AdjustFrameScale(targetFrame, delta, isBagWindow)
        end
    end)

    inputFrame:HookScript("OnMouseUp", function(_, button)
        if allowPositionReset and button == "RightButton" and IsControlKeyDown and IsControlKeyDown() then
            ResetFramePosition(targetFrame, true, resetToOriginalPoint)
        end
    end)
end

local function RestoreSavedPoint(frame, isBagWindow)
    if not ns.db
        or not ns.db.windows.enabled
        or not ns.db.windows.savePositions
        or (isBagWindow and not ns.db.windows.moveBags)
        or IsBlockedFrame(frame, isBagWindow)
        or InCombatLockdown()
    then
        return
    end

    local name = GetFrameName(frame)
    local saved = name and ns.db.windows.points[name]

    if not saved then
        return
    end

    local relativeTo = _G[saved.relativeTo] or UIParent
    frame.ZTRestoringPoint = true
    SafeCall(frame.ClearAllPoints, frame)
    SafeCall(frame.SetPoint, frame, saved.point, relativeTo, saved.relativePoint, saved.x, saved.y)
    frame.ZTRestoringPoint = nil

    SetManagedPlacement(frame, true)

    return true
end

local function RestoreSavedPointSoon(frame, isBagWindow)
    if not frame or IsBlockedFrame(frame, isBagWindow) then
        return
    end

    if not HasSavedPoint(frame, isBagWindow) then
        return
    end

    RestoreSavedPoint(frame, isBagWindow)

    if not C_Timer or not C_Timer.After or frame.ZTRestoreQueued then
        return
    end

    frame.ZTRestoreQueued = true

    C_Timer.After(0, function()
        frame.ZTRestoreQueued = nil
        RestoreSavedPoint(frame, isBagWindow)
    end)

    C_Timer.After(0.05, function()
        RestoreSavedPoint(frame, isBagWindow)
    end)
end

function RestoreOriginalPoint(frame, keepManaged)
    if not frame or IsBlockedFrame(frame) or not frame.ZTOriginalPoints or #frame.ZTOriginalPoints == 0 or InCombatLockdown() then
        return false
    end

    frame.ZTRestoringPoint = true
    SafeCall(frame.ClearAllPoints, frame)

    for _, point in ipairs(frame.ZTOriginalPoints) do
        SafeCall(frame.SetPoint, frame, point.point, point.relativeTo or UIParent, point.relativePoint, point.x, point.y)
    end

    frame.ZTRestoringPoint = nil
    SetManagedPlacement(frame, keepManaged == true)

    return true
end

local function HookFrameSetPoint(frame, isBagWindow)
    if IsBlockedFrame(frame, isBagWindow) or frame.ZTSetPointHooked or not frame.SetPoint then
        return
    end

    local ok = pcall(hooksecurefunc, frame, "SetPoint", function(self)
        if IsBlockedFrame(self, isBagWindow) or self.ZTRestoringPoint or self.ZTMoving then
            return
        end

        RestoreSavedPointSoon(self, isBagWindow)
    end)

    if ok then
        frame.ZTSetPointHooked = true
    end
end

local function PositionWindowHandle(frame)
    local handle = windowHandles[frame]

    if not handle then
        return
    end

    local rightOffset = frame.CloseButton and -38 or -12

    handle:ClearAllPoints()
    handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -4)
    handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", rightOffset, -4)
    handle:SetHeight(28)
    handle:SetFrameStrata(frame:GetFrameStrata())
    handle:SetFrameLevel(math.min((frame:GetFrameLevel() or 1) + 100, 10000))
end

local function UpdateWindowHandle(frame)
    local handle = windowHandles[frame]

    if not handle then
        return
    end

    if ns.db and ns.db.windows.enabled and frame:IsShown() then
        PositionWindowHandle(frame)
        handle:Show()
    else
        handle:Hide()
    end
end

local function CreateWindowHandle(frame)
    if windowHandles[frame] then
        return
    end

    local name = frame:GetName()
    local handle = CreateFrame("Frame", name .. "ZoidsToolsWindowDragHandle", frame, "BackdropTemplate")
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    handle:SetBackdropColor(0.12, 0.16, 0.22, 0.08)
    handle:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.12)

    handle.label = handle:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    handle.label:SetPoint("CENTER")
    handle.label:SetText("Move")
    handle.label:SetAlpha(0.45)

    handle:SetScript("OnDragStart", function()
        if ns.db and ns.db.windows.enabled and not InCombatLockdown() then
            frame.ZTMoving = true
            if not SafeCall(frame.StartMoving, frame) then
                frame.ZTMoving = nil
            end
        end
    end)

    handle:SetScript("OnDragStop", function()
        SafeCall(frame.StopMovingOrSizing, frame)
        frame.ZTMoving = nil
        SetManagedPlacement(frame, true)
        SavePoint(frame)
        UpdateWindowHandle(frame)
    end)

    handle:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.12, 0.16, 0.22, 0.18)
        self:SetBackdropBorderColor(1, 0.82, 0, 0.35)
        self.label:SetAlpha(0.7)

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Move Window")
        GameTooltip:AddLine("Drag this handle to reposition the window.", 1, 1, 1, true)
        GameTooltip:AddLine("Ctrl + Mouse Wheel: Scale this window", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Ctrl + Right-click: Reset this position", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    handle:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.16, 0.22, 0.08)
        self:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.12)
        self.label:SetAlpha(0.45)
        GameTooltip:Hide()
    end)

    AddScaleScripts(handle, frame, true, "panel")

    handle:Hide()
    windowHandles[frame] = handle
    PositionWindowHandle(frame)
end

local function UpdateBagHandle(frame)
    local handle = bagHandles[frame]

    if not handle then
        return
    end

    local shouldShow = ns.db
        and ns.db.windows.enabled
        and ns.db.windows.moveBags
        and ns.db.windows.showBagHandles
        and frame:IsShown()

    handle:SetShown(shouldShow == true)
end

local function MakeMovable(frame)
    if not IsUsableFrame(frame) or movableFrames[frame] then
        return
    end

    if not SafeCall(frame.SetMovable, frame, true) then
        return
    end

    movableFrames[frame] = true
    CaptureOriginalPoints(frame)

    SafeCall(frame.SetClampedToScreen, frame, true)
    SafeCall(frame.EnableMouse, frame, true)
    SafeCall(frame.RegisterForDrag, frame, "LeftButton")
    SetManagedPlacement(frame, HasSavedPoint(frame))
    HookFrameSetScale(frame, false)
    ApplySavedScaleSoon(frame)
    AddScaleScripts(frame, frame, false)
    CreateWindowHandle(frame)
    HookFrameSetPoint(frame, false)

    frame:HookScript("OnDragStart", function(self)
        if ns.db and ns.db.windows.enabled and not InCombatLockdown() then
            self.ZTMoving = true
            if not SafeCall(self.StartMoving, self) then
                self.ZTMoving = nil
            end
        end
    end)

    frame:HookScript("OnDragStop", function(self)
        SafeCall(self.StopMovingOrSizing, self)
        self.ZTMoving = nil
        SetManagedPlacement(self, true)
        SavePoint(self, false)
        UpdateWindowHandle(self)
    end)

    frame:HookScript("OnShow", function(self)
        CaptureOriginalPoints(self)
        ApplySavedScaleSoon(self)
        RestoreSavedPointSoon(self, false)
        UpdateWindowHandle(self)
    end)

    frame:HookScript("OnHide", function(self)
        ApplySavedScaleSoon(self)

        if ns.db and not ns.db.windows.savePositions then
            SetManagedPlacement(self, false)
        elseif ns.db and ns.db.windows.savePositions then
            RestoreSavedPointSoon(self, false)
        end

        UpdateWindowHandle(self)
    end)

    frame:HookScript("OnSizeChanged", UpdateWindowHandle)

    RestoreSavedPointSoon(frame, false)
    UpdateWindowHandle(frame)
end

local function PositionBagHandle(frame, handle)
    local name = frame:GetName()
    local leftOffset = name == "ContainerFrameCombinedBags" and 22 or 8
    local rightOffset = name == "ContainerFrameCombinedBags" and -92 or -34
    local height = name == "ContainerFrameCombinedBags" and 32 or 24

    handle:ClearAllPoints()
    handle:SetPoint("TOPLEFT", frame, "TOPLEFT", leftOffset, -4)
    handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", rightOffset, -4)
    handle:SetHeight(height)
end

local function CreateBagHandle(frame)
    local name = frame:GetName()
    local handle = CreateFrame("Frame", name .. "ZoidsToolsDragHandle", frame, "BackdropTemplate")
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetFrameStrata(frame:GetFrameStrata())
    handle:SetFrameLevel(math.min((frame:GetFrameLevel() or 1) + 100, 10000))
    handle:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    handle:SetBackdropColor(0.12, 0.16, 0.22, 0.16)
    handle:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.18)

    handle.label = handle:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    handle.label:SetPoint("CENTER")
    handle.label:SetText("Move")
    handle.label:SetAlpha(0.65)

    handle:SetScript("OnDragStart", function()
        if ns.db and ns.db.windows.enabled and ns.db.windows.moveBags and not InCombatLockdown() then
            frame.ZTMoving = true
            if not SafeCall(frame.StartMoving, frame) then
                frame.ZTMoving = nil
            end
        end
    end)

    handle:SetScript("OnDragStop", function()
        SafeCall(frame.StopMovingOrSizing, frame)
        frame.ZTMoving = nil
        SetManagedPlacement(frame, true)
        SavePoint(frame, true)
        UpdateBagHandle(frame)
    end)

    handle:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.34, 0.46, 0.35)
        self:SetBackdropBorderColor(1, 0.82, 0, 0.55)

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Move Bag Window")
        GameTooltip:AddLine("Drag this handle to reposition the bag.", 1, 1, 1, true)
        GameTooltip:AddLine("Ctrl + Mouse Wheel: Scale this bag", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Ctrl + Right-click: Reset this position", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    handle:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.16, 0.22, 0.16)
        self:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.18)
        GameTooltip:Hide()
    end)

    PositionBagHandle(frame, handle)
    AddScaleScripts(handle, frame, true, "bag", true)
    handle:Hide()

    return handle
end

local function MakeBagMovable(frame)
    if not frame or not ns.db then
        return
    end

    local name = frame.GetName and frame:GetName()

    if not name
        or IsBlockedFrameName(name, true)
        or not frame.SetMovable
        or not frame.SetClampedToScreen
        or not frame.HookScript
    then
        return
    end

    if not bagFrames[frame] then
        if not SafeCall(frame.SetMovable, frame, true) then
            return
        end

        bagFrames[frame] = true
        CaptureOriginalPoints(frame, true)

        SafeCall(frame.SetClampedToScreen, frame, true)
        SetManagedPlacement(frame, HasSavedPoint(frame, true))
        HookFrameSetScale(frame, true)
        ApplySavedScaleSoon(frame, true)
        AddScaleScripts(frame, frame, false, nil, true)
        HookFrameSetPoint(frame, true)

        local handle = CreateBagHandle(frame)
        frame.ZoidsToolsBagDragHandle = handle
        bagHandles[frame] = handle

        frame:HookScript("OnShow", function(self)
            CaptureOriginalPoints(self, true)
            ApplySavedScaleSoon(self, true)
            RestoreSavedPointSoon(self, true)
            PositionBagHandle(self, bagHandles[self])
            UpdateBagHandle(self)
        end)

        frame:HookScript("OnHide", function(self)
            ApplySavedScaleSoon(self, true)

            if ns.db and not ns.db.windows.savePositions then
                SetManagedPlacement(self, false)
            elseif ns.db and ns.db.windows.savePositions then
                RestoreSavedPointSoon(self, true)
            end

            UpdateBagHandle(self)
        end)

        frame:HookScript("OnSizeChanged", function(self)
            PositionBagHandle(self, bagHandles[self])
            UpdateBagHandle(self)
        end)
    end

    RestoreSavedPointSoon(frame, true)
    PositionBagHandle(frame, bagHandles[frame])
    UpdateBagHandle(frame)
end

local function RegisterUIPanelWindows()
    if InCombatLockdown() then
        return
    end

    if UIPanelWindows then
        for name in pairs(UIPanelWindows) do
            MakeMovable(_G[name])
        end
    end

    for _, name in ipairs(commonFrames) do
        MakeMovable(_G[name])
    end

    if PlayerSpellsFrame then
        MakeMovable(PlayerSpellsFrame)
    end

    if ClassTalentFrame then
        MakeMovable(ClassTalentFrame)
    end

    if PlayerTalentFrame then
        MakeMovable(PlayerTalentFrame)
    end

    if SpellBookFrame then
        MakeMovable(SpellBookFrame)
    end
end

local function RefreshPanelWindowsSoon()
    if panelRefreshQueued or InCombatLockdown() then
        return
    end

    panelRefreshQueued = true

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            panelRefreshQueued = false
            RegisterUIPanelWindows()
        end)
    else
        panelRefreshQueued = false
        RegisterUIPanelWindows()
    end
end

local function RegisterBagWindows()
    if InCombatLockdown() then
        return
    end

    if not ns.db or not ns.db.windows.moveBags then
        return
    end

    for _, name in ipairs(knownBagFrames) do
        if _G[name] then
            MakeBagMovable(_G[name])
        end
    end
end

local function RefreshBagsSoon()
    if bagRefreshQueued or InCombatLockdown() then
        return
    end

    bagRefreshQueued = true

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            bagRefreshQueued = false
            RegisterBagWindows()
        end)
    else
        bagRefreshQueued = false
        RegisterBagWindows()
    end
end

local function RefreshFrameSoon(frame, isBagWindow)
    if not frame or InCombatLockdown() then
        return
    end

    MakeMovable(frame)
    RestoreSavedPointSoon(frame, isBagWindow)
    UpdateWindowHandle(frame)
end

local function InstallHooks()
    if windowsRegistered then
        return
    end

    windowsRegistered = true

    if type(ShowUIPanel) == "function" then
        hooksecurefunc("ShowUIPanel", function(frame)
            if not InCombatLockdown() then
                RefreshFrameSoon(frame, false)
            end
        end)
    end

    if type(HideUIPanel) == "function" then
        hooksecurefunc("HideUIPanel", function(frame)
            if frame and not InCombatLockdown() then
                RestoreSavedPointSoon(frame, false)
            end
        end)
    end

    local windowFunctions = {
        "ToggleSpellBook",
        "ToggleTalentFrame",
        "TogglePlayerSpellsFrame",
        "ToggleProfessionsBook",
    }

    for _, functionName in ipairs(windowFunctions) do
        if type(_G[functionName]) == "function" then
            hooksecurefunc(functionName, function()
                if not InCombatLockdown() then
                    RefreshPanelWindowsSoon()
                end
            end)
        end
    end

    if type(_G.ToggleGameMenu) == "function" then
        hooksecurefunc("ToggleGameMenu", function()
            RefreshFrameSoon(_G.GameMenuFrame, false)
        end)
    end

    local bagFunctions = {
        "OpenAllBags",
        "CloseAllBags",
        "ToggleAllBags",
        "OpenBag",
        "CloseBag",
        "ToggleBag",
        "ToggleBackpack",
        "ContainerFrame_GenerateFrame",
    }

    for _, functionName in ipairs(bagFunctions) do
        if type(_G[functionName]) == "function" then
            hooksecurefunc(functionName, RefreshBagsSoon)
        end
    end

    bagWatcher = CreateFrame("Frame")
    bagWatcher:RegisterEvent("ADDON_LOADED")
    bagWatcher:RegisterEvent("BAG_OPEN")
    bagWatcher:RegisterEvent("BAG_CLOSED")
    bagWatcher:RegisterEvent("BAG_UPDATE_DELAYED")
    bagWatcher:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    bagWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    bagWatcher:SetScript("OnEvent", function(_, event)
        if InCombatLockdown() and event ~= "PLAYER_REGEN_ENABLED" then
            return
        end

        if event == "ADDON_LOADED" or event == "PLAYER_REGEN_ENABLED" then
            RefreshPanelWindowsSoon()
        end

        RefreshBagsSoon()
    end)
end

function ns:InitializeMovableWindows()
    if not self.db then
        return
    end

    ClearBlockedWindowState()
    InstallHooks()

    if self.db.windows.enabled then
        RegisterUIPanelWindows()
    end

    if self.db.windows.moveBags then
        RegisterBagWindows()
    end
end

function ns:RefreshMovableWindows()
    ClearBlockedWindowState()
    RegisterUIPanelWindows()
    RegisterBagWindows()

    for frame in pairs(bagFrames) do
        UpdateBagHandle(frame)
    end
end

function ns:RefreshBagMovement()
    RegisterBagWindows()

    for frame in pairs(bagFrames) do
        UpdateBagHandle(frame)
    end
end

function ns:ResetMovableWindowPositions()
    if not self.db then
        return
    end

    wipe(self.db.windows.points)

    for frame in pairs(movableFrames) do
        ResetFramePosition(frame, false, "panel")
        UpdateWindowHandle(frame)
    end

    for frame in pairs(bagFrames) do
        ResetFramePosition(frame, false, "bag")
        UpdateBagHandle(frame)
    end

    self:Print("Saved window positions reset.")
end

function ns:ResetMovableWindowScales()
    if not self.db then
        return
    end

    self.db.windows.scales = self.db.windows.scales or {}
    wipe(self.db.windows.scales)

    for frame in pairs(movableFrames) do
        ResetFrameScale(frame, false)
        UpdateWindowHandle(frame)
    end

    for frame in pairs(bagFrames) do
        ResetFrameScale(frame, false, true)
        UpdateBagHandle(frame)
    end

    self:Print("Saved window scales reset.")
end

function ns:GetSavedWindowScaleCount()
    local count = 0

    if not self.db or not self.db.windows.scales then
        return count
    end

    for _ in pairs(self.db.windows.scales) do
        count = count + 1
    end

    return count
end

function ns:GetMovableWindowStats()
    local windowCount = 0
    local bagCount = 0
    local scaleCount = self.GetSavedWindowScaleCount and self:GetSavedWindowScaleCount() or 0

    for _ in pairs(movableFrames) do
        windowCount = windowCount + 1
    end

    for _ in pairs(bagFrames) do
        bagCount = bagCount + 1
    end

    return windowCount, bagCount, scaleCount
end
