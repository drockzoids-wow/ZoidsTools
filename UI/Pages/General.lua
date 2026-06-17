local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateGeneralPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local interfaceSection = UI.CreateSection(frame, "Interface", nil, 0)

    local minimap = UI.CreateCheckbox(
        frame,
        "Show minimap button",
        "Shows a minimap launcher for the ZoidsTools control window.",
        function()
            return ns.db and ns.db.ui.minimap.show
        end,
        function(value)
            ns:SetMinimapShown(value)
        end
    )
    minimap:SetPoint("TOPLEFT", interfaceSection, "BOTTOMLEFT", 18, -6)

    local squareMinimap = UI.CreateCheckbox(
        frame,
        "Square minimap",
        "Uses a simple square mask and thin border for the minimap.",
        function()
            return ns.IsSquareMinimapEnabled and ns:IsSquareMinimapEnabled()
        end,
        function(value)
            if ns.SetSquareMinimapEnabled then
                ns:SetSquareMinimapEnabled(value)
            end
        end
    )
    squareMinimap:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 0, -6)

    local minimapHeader = UI.CreateCheckbox(
        frame,
        "Move map title and time",
        "Moves the minimap title, clock, and Blizzard addon button into a compact top bar, with tracking and calendar inside the map corners.",
        function()
            return ns.IsMinimapHeaderBarEnabled and ns:IsMinimapHeaderBarEnabled()
        end,
        function(value)
            if ns.SetMinimapHeaderBarEnabled then
                ns:SetMinimapHeaderBarEnabled(value)
            end
        end
    )
    minimapHeader:SetPoint("TOPLEFT", squareMinimap, "BOTTOMLEFT", 0, -6)

    local mouseoverButtons = UI.CreateCheckbox(
        frame,
        "Hide addon buttons until mouseover",
        "Hides addon minimap buttons until your mouse is over the minimap.",
        function()
            return ns.IsMinimapButtonsMouseoverEnabled and ns:IsMinimapButtonsMouseoverEnabled()
        end,
        function(value)
            if ns.SetMinimapButtonsMouseoverEnabled then
                ns:SetMinimapButtonsMouseoverEnabled(value)
            end
        end
    )
    mouseoverButtons:SetPoint("TOPLEFT", minimapHeader, "BOTTOMLEFT", 0, -6)

    local collectButtons = UI.CreateCheckbox(
        frame,
        "Collect addon buttons",
        "Stores addon minimap buttons inside one expandable ZoidsTools button.",
        function()
            return ns.IsMinimapButtonCollectorEnabled and ns:IsMinimapButtonCollectorEnabled()
        end,
        function(value)
            if ns.SetMinimapButtonCollectorEnabled then
                ns:SetMinimapButtonCollectorEnabled(value)
            end
        end
    )
    collectButtons:SetPoint("TOPLEFT", mouseoverButtons, "BOTTOMLEFT", 0, -6)

    local performanceDisplay = UI.CreateDropdown(
        frame,
        "Performance widget",
        "Controls what the draggable performance widget displays.",
        {
            { value = "disabled", text = "Disabled" },
            { value = "fps", text = "FPS" },
            { value = "latency", text = "Latency" },
            { value = "both", text = "Both" },
        },
        function()
            return ns.GetPerformanceWidgetDisplayMode and ns:GetPerformanceWidgetDisplayMode() or "both"
        end,
        function(value)
            if ns.SetPerformanceWidgetDisplayMode then
                ns:SetPerformanceWidgetDisplayMode(value)
            end
        end,
        220
    )
    performanceDisplay:SetPoint("TOPLEFT", collectButtons, "BOTTOMLEFT", 0, -16)

    local performanceScale = UI.CreateSlider(
        frame,
        "Widget size",
        "Adjusts the size of the FPS and latency widget.",
        0.65,
        1.8,
        0.05,
        function()
            return ns.GetPerformanceWidgetScale and ns:GetPerformanceWidgetScale() or 1
        end,
        function(value)
            if ns.SetPerformanceWidgetScale then
                ns:SetPerformanceWidgetScale(value)
            end
        end,
        220,
        function(value)
            return string.format("%d%%", (value or 1) * 100)
        end
    )
    performanceScale:SetPoint("TOPLEFT", performanceDisplay, "BOTTOMLEFT", 16, -18)

    local coordinatesSection = UI.CreateSection(frame, "Coordinates", performanceScale, -42)
    coordinatesSection:ClearAllPoints()
    coordinatesSection:SetPoint("TOPLEFT", performanceDisplay, "TOPRIGHT", 48, 0)
    coordinatesSection:SetPoint("RIGHT", frame, "RIGHT", -12, 0)

    local coordinatesWidget = UI.CreateCheckbox(
        frame,
        "Show coordinates widget",
        "Shows a separate draggable coordinate box. Shift-left-click the box to put your current coordinates in chat.",
        function()
            return ns.IsCoordinatesWidgetShown and ns:IsCoordinatesWidgetShown()
        end,
        function(value)
            if ns.SetCoordinatesWidgetShown then
                ns:SetCoordinatesWidgetShown(value)
            end
        end
    )
    coordinatesWidget:SetPoint("TOPLEFT", coordinatesSection, "BOTTOMLEFT", 18, -6)

    local mapCoordinates = UI.CreateCheckbox(
        frame,
        "Show map coordinates",
        "Shows player coordinates on the map and mouse coordinates while your cursor is over the map.",
        function()
            return ns.IsMapCoordinatesShown and ns:IsMapCoordinatesShown()
        end,
        function(value)
            if ns.SetMapCoordinatesShown then
                ns:SetMapCoordinatesShown(value)
            end
        end
    )
    mapCoordinates:SetPoint("TOPLEFT", coordinatesWidget, "BOTTOMLEFT", 0, -6)

    local coordinatesScale = UI.CreateSlider(
        frame,
        "Coordinates size",
        "Adjusts the size of the standalone coordinates widget.",
        0.65,
        1.8,
        0.05,
        function()
            return ns.GetCoordinatesWidgetScale and ns:GetCoordinatesWidgetScale() or 1
        end,
        function(value)
            if ns.SetCoordinatesWidgetScale then
                ns:SetCoordinatesWidgetScale(value)
            end
        end,
        220,
        function(value)
            return string.format("%d%%", (value or 1) * 100)
        end
    )
    coordinatesScale:SetPoint("TOPLEFT", mapCoordinates, "BOTTOMLEFT", 16, -18)

    local resetCoordinates = UI.CreateButton(frame, "Reset Coords", 132)
    resetCoordinates:SetScript("OnClick", function()
        if ns.ResetCoordinatesWidgetPosition then
            ns:ResetCoordinatesWidgetPosition()
        end
    end)

    local unlockPerformance = UI.CreateButton(frame, "Unlock Widget", 132)
    unlockPerformance:SetScript("OnClick", function()
        if ns.SetPerformanceWidgetLocked then
            ns:SetPerformanceWidgetLocked(false)
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    local openWindows = UI.CreateButton(frame, "Window Tools", 132)
    openWindows:SetScript("OnClick", function()
        UI.Show("windows")
    end)

    function frame:Refresh()
        minimap:Refresh()
        squareMinimap:Refresh()
        minimapHeader:Refresh()
        mouseoverButtons:Refresh()
        collectButtons:Refresh()
        performanceDisplay:Refresh()
        performanceScale:Refresh()
        coordinatesWidget:Refresh()
        mapCoordinates:Refresh()
        coordinatesScale:Refresh()

        resetCoordinates:ClearAllPoints()
        unlockPerformance:ClearAllPoints()
        openWindows:ClearAllPoints()

        resetCoordinates:SetPoint("TOPLEFT", coordinatesScale, "BOTTOMLEFT", -16, -24)

        if ns.IsPerformanceWidgetLocked and ns:IsPerformanceWidgetLocked() then
            unlockPerformance:Show()
            unlockPerformance:SetPoint("TOPLEFT", performanceScale, "BOTTOMLEFT", -16, -24)
            openWindows:SetPoint("TOPLEFT", unlockPerformance, "BOTTOMLEFT", 0, -12)
        else
            unlockPerformance:Hide()
            openWindows:SetPoint("TOPLEFT", performanceScale, "BOTTOMLEFT", -16, -24)
        end
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
