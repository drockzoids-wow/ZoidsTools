local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateGeneralPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)
    local leftWidth = 344
    local rightX = 402
    local rightWidth = 310
    local controlWidth = 260

    local interfaceSection = UI.PlaceSection(frame, "Interface", nil, leftWidth)

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
    UI.PlaceFirst(minimap, interfaceSection)

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
    UI.PlaceBelow(squareMinimap, minimap)

    local minimapHeader = UI.CreateCheckbox(
        frame,
        "Move map title and time",
        "Moves the minimap title, subzone, tracking, addon button, and clock into a larger top banner. Right-click the clock to open the calendar.",
        function()
            return ns.IsMinimapHeaderBarEnabled and ns:IsMinimapHeaderBarEnabled()
        end,
        function(value)
            if ns.SetMinimapHeaderBarEnabled then
                ns:SetMinimapHeaderBarEnabled(value)
            end
        end
    )
    UI.PlaceBelow(minimapHeader, squareMinimap)

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
    UI.PlaceBelow(mouseoverButtons, minimapHeader)

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
    UI.PlaceBelow(collectButtons, mouseoverButtons)

    local inviteBanner = UI.CreateCheckbox(
        frame,
        "Mythic+ invitation banner",
        "Keeps the invited dungeon name at the top of the screen and offers its teleport when you have learned it.",
        function()
            return ns.IsMythicInviteBannerEnabled and ns:IsMythicInviteBannerEnabled()
        end,
        function(value)
            if ns.SetMythicInviteBannerEnabled then
                ns:SetMythicInviteBannerEnabled(value)
            end
        end
    )
    UI.PlaceBelow(inviteBanner, collectButtons)

    local performanceSection = UI.PlaceSection(frame, "Performance", inviteBanner, leftWidth)

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
        controlWidth
    )
    UI.PlaceFirst(performanceDisplay, performanceSection)

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
        controlWidth,
        function(value)
            return string.format("%d%%", (value or 1) * 100)
        end
    )
    UI.PlaceSlider(performanceScale, performanceDisplay)

    local coordinatesSection = UI.PlaceSection(frame, "Coordinates", nil, rightWidth)
    coordinatesSection:ClearAllPoints()
    coordinatesSection:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, 0)

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
    UI.PlaceFirst(coordinatesWidget, coordinatesSection)

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
    UI.PlaceBelow(mapCoordinates, coordinatesWidget)

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
        controlWidth,
        function(value)
            return string.format("%d%%", (value or 1) * 100)
        end
    )
    UI.PlaceSlider(coordinatesScale, mapCoordinates)

    local resetCoordinates = UI.CreateButton(frame, "Reset Coords", 132)
    resetCoordinates:SetPoint("TOPLEFT", coordinatesScale, "BOTTOMLEFT", -UI.Layout.sliderIndent, -24)
    resetCoordinates:SetScript("OnClick", function()
        if ns.ResetCoordinatesWidgetPosition then
            ns:ResetCoordinatesWidgetPosition()
        end
    end)

    local cinematicsSection = UI.PlaceSection(frame, "Cinematics", resetCoordinates, rightWidth)

    local cinematicFastSkip = UI.CreateCheckbox(
        frame,
        "Skip confirm with Escape",
        "Pressing Escape during a cinematic or movie skips it immediately without clicking a confirmation popup.",
        function()
            return ns.IsCinematicFastSkipEnabled and ns:IsCinematicFastSkipEnabled()
        end,
        function(value)
            if ns.SetCinematicFastSkipEnabled then
                ns:SetCinematicFastSkipEnabled(value)
            end
        end
    )
    UI.PlaceFirst(cinematicFastSkip, cinematicsSection)

    local cinematicAutoSkip = UI.CreateCheckbox(
        frame,
        "Auto skip cinematics",
        "Automatically skips cinematics and movies as soon as they start.",
        function()
            return ns.IsCinematicAutoSkipEnabled and ns:IsCinematicAutoSkipEnabled()
        end,
        function(value)
            if ns.SetCinematicAutoSkipEnabled then
                ns:SetCinematicAutoSkipEnabled(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    )
    UI.PlaceBelow(cinematicAutoSkip, cinematicFastSkip)

    local talkingHeadSection = UI.PlaceSection(frame, "Talking Head", cinematicAutoSkip, rightWidth)

    local subtleTalkingHead = UI.CreateCheckbox(
        frame,
        "Use subtle Talking Head",
        "Replaces Blizzard's large portrait window with a compact subtitle panel. Normal clicks pass through it; right-click dismisses the current dialogue and voice. ZoidsTools yields automatically if Plumber's replacement is enabled.",
        function()
            return ns.IsSubtleTalkingHeadEnabled and ns:IsSubtleTalkingHeadEnabled()
        end,
        function(value)
            if ns.SetSubtleTalkingHeadEnabled then ns:SetSubtleTalkingHeadEnabled(value) end
        end
    )
    UI.PlaceFirst(subtleTalkingHead, talkingHeadSection)

    local talkingHeadBackground = UI.CreateCheckbox(
        frame,
        "Show background",
        "Shows the subtle dark subtitle panel. Disable this for text-only dialogue.",
        function()
            return ns.GetSubtleTalkingHeadBackground and ns:GetSubtleTalkingHeadBackground()
        end,
        function(value)
            if ns.SetSubtleTalkingHeadBackground then ns:SetSubtleTalkingHeadBackground(value) end
        end
    )
    UI.PlaceBelow(talkingHeadBackground, subtleTalkingHead)

    local talkingHeadBold = UI.CreateCheckbox(
        frame,
        "Bold text",
        "Adds a stronger outlined treatment to the speaker and subtitle text.",
        function()
            return ns.GetSubtleTalkingHeadBold and ns:GetSubtleTalkingHeadBold()
        end,
        function(value)
            if ns.SetSubtleTalkingHeadBold then ns:SetSubtleTalkingHeadBold(value) end
        end
    )
    talkingHeadBold:SetPoint("TOPLEFT", talkingHeadBackground, "TOPLEFT", 155, 0)

    local talkingHeadOpacity = UI.CreateSlider(
        frame,
        "Subtitle opacity",
        "Controls how prominent the click-through Talking Head subtitle appears.",
        0.35,
        1,
        0.05,
        function()
            return ns.GetSubtleTalkingHeadOpacity and ns:GetSubtleTalkingHeadOpacity() or 0.72
        end,
        function(value)
            if ns.SetSubtleTalkingHeadOpacity then ns:SetSubtleTalkingHeadOpacity(value) end
        end,
        125,
        function(value) return string.format("%d%%", (value or 0.72) * 100) end
    )
    UI.PlaceSlider(talkingHeadOpacity, talkingHeadBackground)

    local talkingHeadFontSize = UI.CreateSlider(
        frame,
        "Font size",
        "Adjusts the speaker and subtitle text size.",
        11,
        24,
        1,
        function()
            return ns.GetSubtleTalkingHeadFontSize and ns:GetSubtleTalkingHeadFontSize() or 14
        end,
        function(value)
            if ns.SetSubtleTalkingHeadFontSize then ns:SetSubtleTalkingHeadFontSize(value) end
        end,
        125,
        function(value) return tostring(math.floor((value or 14) + 0.5)) end
    )
    talkingHeadFontSize:SetPoint("TOPLEFT", talkingHeadOpacity, "TOPLEFT", 150, 0)

    local previewTalkingHead = UI.CreateButton(frame, "Preview Subtitle", 150)
    previewTalkingHead:SetPoint("TOPLEFT", talkingHeadOpacity, "BOTTOMLEFT", -UI.Layout.sliderIndent, -22)
    previewTalkingHead:SetScript("OnClick", function()
        if ns.PreviewSubtleTalkingHead then ns:PreviewSubtleTalkingHead() end
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

    function frame:Refresh()
        minimap:Refresh()
        squareMinimap:Refresh()
        minimapHeader:Refresh()
        mouseoverButtons:Refresh()
        collectButtons:Refresh()
        inviteBanner:Refresh()
        cinematicFastSkip:Refresh()
        cinematicAutoSkip:Refresh()
        subtleTalkingHead:Refresh()
        talkingHeadBackground:Refresh()
        talkingHeadBold:Refresh()
        talkingHeadOpacity:Refresh()
        talkingHeadFontSize:Refresh()
        performanceDisplay:Refresh()
        performanceScale:Refresh()
        coordinatesWidget:Refresh()
        mapCoordinates:Refresh()
        coordinatesScale:Refresh()

        resetCoordinates:ClearAllPoints()
        unlockPerformance:ClearAllPoints()

        resetCoordinates:SetPoint("TOPLEFT", coordinatesScale, "BOTTOMLEFT", -UI.Layout.sliderIndent, -24)

        if ns.IsPerformanceWidgetLocked and ns:IsPerformanceWidgetLocked() then
            unlockPerformance:Show()
            unlockPerformance:SetPoint("TOPLEFT", performanceScale, "BOTTOMLEFT", -UI.Layout.sliderIndent, -24)
        else
            unlockPerformance:Hide()
        end
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
