local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

local popupKey = "ZOIDSTOOLS_RESET_WINDOWS"

StaticPopupDialogs[popupKey] = StaticPopupDialogs[popupKey] or {
    text = "Reset saved ZoidsTools window positions?",
    button1 = YES or "Yes",
    button2 = CANCEL or "Cancel",
    OnAccept = function()
        if ns.ResetMovableWindowPositions then
            ns:ResetMovableWindowPositions()
        end

        if ns.UI and ns.UI.RefreshVisiblePage then
            ns.UI.RefreshVisiblePage()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns.UI.Pages.CreateWindowsPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local movementSection = UI.PlaceSection(frame, "Movement")

    local windowsEnabled = UI.CreateCheckbox(
        frame,
        "Make Blizzard windows movable",
        "Allows supported Blizzard interface panels to be repositioned.",
        function()
            return ns.db and ns.db.windows.enabled
        end,
        function(value)
            ns.db.windows.enabled = value

            if value and ns.InitializeMovableWindows then
                ns:InitializeMovableWindows()
            end

            if ns.RefreshMovableWindows then
                ns:RefreshMovableWindows()
            end
        end
    )
    UI.PlaceFirst(windowsEnabled, movementSection)

    local bagsEnabled = UI.CreateCheckbox(
        frame,
        "Move default bag windows",
        "Adds drag handles to default backpack, bag, bank, and reagent bank windows.",
        function()
            return ns.db and ns.db.windows.moveBags
        end,
        function(value)
            ns.db.windows.moveBags = value

            if ns.RefreshBagMovement then
                ns:RefreshBagMovement()
            end
        end
    )
    UI.PlaceBelow(bagsEnabled, windowsEnabled)

    local bagHandles = UI.CreateCheckbox(
        frame,
        "Show bag drag handles",
        "Shows the small movement handle across the top of movable bag windows.",
        function()
            return ns.db and ns.db.windows.showBagHandles
        end,
        function(value)
            ns.db.windows.showBagHandles = value

            if ns.RefreshBagMovement then
                ns:RefreshBagMovement()
            end
        end
    )
    UI.PlaceBelow(bagHandles, bagsEnabled)

    local savePositions = UI.CreateCheckbox(
        frame,
        "Remember moved positions",
        "Keeps moved windows at their saved positions after closing and reopening them.",
        function()
            return ns.db and ns.db.windows.savePositions
        end,
        function(value)
            ns.db.windows.savePositions = value
        end
    )
    UI.PlaceBelow(savePositions, bagHandles)

    local scaleEnabled = UI.CreateCheckbox(
        frame,
        "Ctrl-scroll scales windows",
        "Hold Ctrl and use the mouse wheel over a movable window or its move handle to adjust scale. Ctrl-right-click the move handle to reset that window position.",
        function()
            return ns.db and ns.db.windows.scaleEnabled
        end,
        function(value)
            ns.db.windows.scaleEnabled = value
        end
    )
    UI.PlaceBelow(scaleEnabled, savePositions)

    local actionsSection = UI.PlaceSection(frame, "Actions", scaleEnabled)

    local refreshButton = UI.CreateButton(frame, "Refresh", 108)
    UI.PlaceFirst(refreshButton, actionsSection)
    refreshButton:SetScript("OnClick", function()
        if ns.RefreshMovableWindows then
            ns:RefreshMovableWindows()
        end

        frame:Refresh()
    end)

    local resetButton = UI.CreateButton(frame, "Reset Positions", 144)
    resetButton:SetPoint("LEFT", refreshButton, "RIGHT", UI.Layout.buttonGap, 0)
    resetButton:SetScript("OnClick", function()
        StaticPopup_Show(popupKey)
    end)

    local resetScalesButton = UI.CreateButton(frame, "Reset Scales", 132)
    resetScalesButton:SetPoint("LEFT", resetButton, "RIGHT", UI.Layout.buttonGap, 0)
    resetScalesButton:SetScript("OnClick", function()
        if ns.ResetMovableWindowScales then
            ns:ResetMovableWindowScales()
        end

        frame:Refresh()
    end)

    local status = UI.CreateStatusText(frame)
    UI.PlaceBelow(status, refreshButton, 0, 18)

    function frame:Refresh()
        windowsEnabled:Refresh()
        bagsEnabled:Refresh()
        bagHandles:Refresh()
        savePositions:Refresh()
        scaleEnabled:Refresh()

        local windowCount, bagCount, scaleCount = 0, 0, 0

        if ns.GetMovableWindowStats then
            windowCount, bagCount, scaleCount = ns:GetMovableWindowStats()
        end

        status:SetText("Tracked windows: " .. windowCount .. "    Bag windows: " .. bagCount .. "    Saved scales: " .. scaleCount)
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
