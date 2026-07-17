local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateQuestsPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)
    local leftWidth = 330
    local rightWidth = 330
    local rightX = 370

    local automationSection = UI.PlaceSection(frame, "Automation", nil, leftWidth)

    local autoAccept = UI.CreateCheckbox(
        frame,
        "Auto accept quests",
        "Automatically accepts available quests unless the pause modifier is held.",
        function()
            return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("autoAccept")
        end,
        function(value)
            if ns.SetQuestAutomationOption then
                ns:SetQuestAutomationOption("autoAccept", value)
            end
        end
    )
    UI.PlaceFirst(autoAccept, automationSection)

    local autoTurnIn = UI.CreateCheckbox(
        frame,
        "Auto turn in quests",
        "Automatically completes ready quests. Multiple reward choices are left for manual selection.",
        function()
            return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("autoTurnIn")
        end,
        function(value)
            if ns.SetQuestAutomationOption then
                ns:SetQuestAutomationOption("autoTurnIn", value)
            end
        end
    )
    UI.PlaceBelow(autoTurnIn, autoAccept)

    local autoGossip = UI.CreateCheckbox(
        frame,
        "Auto gossip",
        "Automatically advances simple gossip windows unless the pause modifier is held.",
        function()
            return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("autoGossip")
        end,
        function(value)
            if ns.SetQuestAutomationOption then
                ns:SetQuestAutomationOption("autoGossip", value)
            end
        end
    )
    UI.PlaceBelow(autoGossip, autoTurnIn)

    local pauseModifier = UI.CreateDropdown(
        frame,
        "Pause modifier",
        "Hold this key to temporarily pause auto questing and auto gossip.",
        ns.GetQuestAutomationPauseModifierOptions and ns:GetQuestAutomationPauseModifierOptions() or {
            { value = "shift", text = "Shift" },
            { value = "ctrl", text = "Ctrl" },
            { value = "alt", text = "Alt" },
            { value = "none", text = "None" },
        },
        function()
            return ns.GetQuestAutomationPauseModifier and ns:GetQuestAutomationPauseModifier() or "shift"
        end,
        function(value)
            if ns.SetQuestAutomationPauseModifier then
                ns:SetQuestAutomationPauseModifier(value)
            end
        end,
        220
    )
    UI.PlaceDropdown(pauseModifier, autoGossip)

    local filtersSection = UI.PlaceSection(frame, "Filters", pauseModifier, leftWidth)

    local skipDaily = UI.CreateCheckbox(
        frame,
        "Skip daily and weekly quests",
        "Prevents auto accept and auto turn-in for daily, weekly, recurring, and calling quests.",
        function()
            return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("skipDaily")
        end,
        function(value)
            if ns.SetQuestAutomationOption then
                ns:SetQuestAutomationOption("skipDaily", value)
            end
        end
    )
    UI.PlaceFirst(skipDaily, filtersSection)

    local skipWarband = UI.CreateCheckbox(
        frame,
        "Skip Warband-completed quests",
        "Prevents auto accept for quests already completed by your Warband. Allowed daily quests are an exception, and completed quests are still turned in.",
        function()
            return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("skipWarbandCompleted")
        end,
        function(value)
            if ns.SetQuestAutomationOption then
                ns:SetQuestAutomationOption("skipWarbandCompleted", value)
            end
        end
    )
    UI.PlaceBelow(skipWarband, skipDaily)

    local status = UI.CreateStatusText(frame)
    UI.PlaceBelow(status, skipWarband, 0, 20)
    status:SetText("Quest rewards with multiple choices are never selected automatically.")

    local trackerSection = UI.PlaceSection(frame, "Quest Tracker", nil, rightWidth)
    trackerSection:ClearAllPoints()
    trackerSection:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, 0)

    local questItemButton = UI.CreateCheckbox(
        frame,
        "Show smart quest item button",
        "Shows a usable, bindable button for the most relevant tracked quest item in your current area.",
        function()
            return ns.GetQuestItemButtonEnabled and ns:GetQuestItemButtonEnabled()
        end,
        function(value)
            if ns.SetQuestItemButtonEnabled then
                ns:SetQuestItemButtonEnabled(value)
            end
        end
    )
    UI.PlaceFirst(questItemButton, trackerSection)

    local moveQuestItemButton = UI.CreateButton(frame, "Move Quest Item Button", 190)
    moveQuestItemButton:SetPoint("TOPLEFT", questItemButton, "BOTTOMLEFT", 0, -14)
    moveQuestItemButton:SetScript("OnClick", function()
        if ns.ToggleQuestItemButtonMoveMode then
            ns:ToggleQuestItemButtonMoveMode()
        end
        if frame.Refresh then
            frame:Refresh()
        end
    end)

    local trackerStatus = UI.CreateStatusText(frame, rightWidth - 20)
    trackerStatus:SetPoint("TOPLEFT", moveQuestItemButton, "BOTTOMLEFT", 0, -18)
    trackerStatus:SetText("Priority: current quest area, super-tracked quest, then nearest tracked quest. Set its key in WoW's Keybindings > ZoidsTools.")

    local appearanceSection = UI.PlaceSection(frame, "Tracker Appearance", trackerStatus, rightWidth)

    local trackerAppearanceEnabled = UI.CreateCheckbox(
        frame,
        "Customize Blizzard objective tracker",
        "Keeps Blizzard's tracker structure and behavior while applying ZoidsTools sizing and appearance controls.",
        function()
            return ns.GetObjectiveTrackerAppearanceOption
                and ns:GetObjectiveTrackerAppearanceOption("enabled")
        end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then
                ns:SetObjectiveTrackerAppearanceOption("enabled", value)
            end
        end
    )
    UI.PlaceFirst(trackerAppearanceEnabled, appearanceSection)

    local trackerScale = UI.CreateSlider(
        frame,
        "Tracker scale",
        "Scales Blizzard's entire objective tracker. This uses the same account-wide saved scale as ZoidsTools movable windows.",
        0.70,
        1.30,
        0.05,
        function()
            return ns.GetObjectiveTrackerAppearanceOption
                and ns:GetObjectiveTrackerAppearanceOption("scale") or 1
        end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then
                ns:SetObjectiveTrackerAppearanceOption("scale", value)
            end
        end,
        260,
        function(value)
            return tostring(math.floor(((value or 1) * 100) + 0.5)) .. "%"
        end
    )
    UI.PlaceSlider(trackerScale, trackerAppearanceEnabled)

    local trackerWidth = UI.CreateSlider(
        frame,
        "Tracker width",
        "Changes the native tracker width and lets Blizzard reflow long quest and objective text normally.",
        220,
        420,
        10,
        function()
            return ns.GetObjectiveTrackerAppearanceOption
                and ns:GetObjectiveTrackerAppearanceOption("width") or 280
        end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then
                ns:SetObjectiveTrackerAppearanceOption("width", value)
            end
        end,
        260,
        function(value)
            return tostring(math.floor((value or 280) + 0.5)) .. " px"
        end
    )
    UI.PlaceSlider(trackerWidth, trackerScale)

    local trackerFitHeight = UI.CreateCheckbox(
        frame,
        "Fit tracker background to tracked content",
        "Fits the ZoidsTools background and border to the final tracked objective without competing with Blizzard's managed tracker height or position.",
        function()
            return ns.GetObjectiveTrackerAppearanceOption
                and ns:GetObjectiveTrackerAppearanceOption("fitHeight")
        end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then
                ns:SetObjectiveTrackerAppearanceOption("fitHeight", value)
            end
        end
    )
    UI.PlaceBelow(trackerFitHeight, trackerWidth, -UI.Layout.sliderIndent, 12)

    local trackerTextScale = UI.CreateSlider(
        frame,
        "Tracker text scale",
        "Scales text inside Blizzard's tracker without replacing its fonts, rows, progress bars, or objective types.",
        0.80,
        1.30,
        0.05,
        function()
            return ns.GetObjectiveTrackerAppearanceOption
                and ns:GetObjectiveTrackerAppearanceOption("textScale") or 1
        end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then
                ns:SetObjectiveTrackerAppearanceOption("textScale", value)
            end
        end,
        260,
        function(value)
            return tostring(math.floor(((value or 1) * 100) + 0.5)) .. "%"
        end
    )
    UI.PlaceSlider(trackerTextScale, trackerFitHeight)

    local trackerTextOutline = UI.CreateCheckbox(
        frame,
        "Outline tracker text",
        "Adds an outline to Blizzard's objective-tracker text while preserving its existing fonts and styles.",
        function()
            return ns.GetObjectiveTrackerAppearanceOption
                and ns:GetObjectiveTrackerAppearanceOption("outlineText")
        end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then
                ns:SetObjectiveTrackerAppearanceOption("outlineText", value)
            end
        end
    )
    UI.PlaceBelow(trackerTextOutline, trackerTextScale, -UI.Layout.sliderIndent, 12)

    local trackerBackgroundOpacity = UI.CreateSlider(
        frame,
        "Background opacity",
        "Adds a subtle dark background behind the objective tracker. Set it to zero for a border-only appearance.",
        0,
        0.70,
        0.05,
        function()
            return ns.GetObjectiveTrackerAppearanceOption
                and ns:GetObjectiveTrackerAppearanceOption("backgroundOpacity") or 0
        end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then
                ns:SetObjectiveTrackerAppearanceOption("backgroundOpacity", value)
            end
        end,
        260,
        function(value)
            return tostring(math.floor(((value or 0) * 100) + 0.5)) .. "%"
        end
    )
    UI.PlaceSlider(trackerBackgroundOpacity, trackerTextOutline)

    local trackerBorderEnabled = UI.CreateCheckbox(
        frame,
        "Show tracker border",
        "Draws a subtle border around Blizzard's objective-tracker region without changing any tracked content.",
        function()
            return ns.GetObjectiveTrackerAppearanceOption
                and ns:GetObjectiveTrackerAppearanceOption("borderEnabled")
        end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then
                ns:SetObjectiveTrackerAppearanceOption("borderEnabled", value)
            end
        end
    )
    UI.PlaceBelow(trackerBorderEnabled, trackerBackgroundOpacity, -UI.Layout.sliderIndent, 12)

    local trackerClassBorder = UI.CreateCheckbox(
        frame,
        "Class-color tracker border",
        "Uses your character's class color for the subtle tracker border. Disable it to use dark ZoidsTools gold.",
        function()
            return ns.GetObjectiveTrackerAppearanceOption
                and ns:GetObjectiveTrackerAppearanceOption("classColoredBorder")
        end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then
                ns:SetObjectiveTrackerAppearanceOption("classColoredBorder", value)
            end
        end
    )
    UI.PlaceBelow(trackerClassBorder, trackerBorderEnabled)

    local trackerMouseoverControls = UI.CreateCheckbox(
        frame,
        "Fade tracker header buttons until mouseover",
        "Keeps Blizzard's tracker buttons available while making them less visually prominent when the tracker is not being used.",
        function()
            return ns.GetObjectiveTrackerAppearanceOption
                and ns:GetObjectiveTrackerAppearanceOption("mouseoverControls")
        end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then
                ns:SetObjectiveTrackerAppearanceOption("mouseoverControls", value)
            end
        end
    )
    UI.PlaceBelow(trackerMouseoverControls, trackerClassBorder)

    local trackerMinimizeToButton = UI.CreateCheckbox(
        frame,
        "Minimize tracker to '+' only",
        "When Blizzard's objective tracker is minimized, hides its title, background, and border so only the restore (+) button remains.",
        function()
            return ns.GetObjectiveTrackerAppearanceOption
                and ns:GetObjectiveTrackerAppearanceOption("minimizeToButton")
        end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then
                ns:SetObjectiveTrackerAppearanceOption("minimizeToButton", value)
            end
        end
    )
    UI.PlaceBelow(trackerMinimizeToButton, trackerMouseoverControls)

    function frame:Refresh()
        autoAccept:Refresh()
        autoTurnIn:Refresh()
        autoGossip:Refresh()
        pauseModifier:Refresh()
        skipDaily:Refresh()
        skipWarband:Refresh()
        questItemButton:Refresh()
        trackerAppearanceEnabled:Refresh()
        trackerScale:Refresh()
        trackerWidth:Refresh()
        trackerFitHeight:Refresh()
        trackerTextScale:Refresh()
        trackerTextOutline:Refresh()
        trackerBackgroundOpacity:Refresh()
        trackerBorderEnabled:Refresh()
        trackerClassBorder:Refresh()
        trackerMouseoverControls:Refresh()
        trackerMinimizeToButton:Refresh()

        local acceptActive = autoAccept:GetChecked() == true
        local turnInActive = autoTurnIn:GetChecked() == true
        local automationActive = acceptActive or turnInActive or autoGossip:GetChecked() == true
        UI.SetControlEnabled(pauseModifier, automationActive)
        UI.SetControlEnabled(skipDaily, acceptActive or turnInActive)
        UI.SetControlEnabled(skipWarband, acceptActive)
        UI.SetControlEnabled(moveQuestItemButton, questItemButton:GetChecked() == true)
        moveQuestItemButton:SetText(ns.IsQuestItemButtonMoveMode and ns:IsQuestItemButtonMoveMode() and "Lock Quest Item Button" or "Move Quest Item Button")

        local appearanceActive = trackerAppearanceEnabled:GetChecked() == true
        UI.SetControlEnabled(trackerScale, appearanceActive)
        UI.SetControlEnabled(trackerWidth, appearanceActive)
        UI.SetControlEnabled(trackerFitHeight, appearanceActive)
        UI.SetControlEnabled(trackerTextScale, appearanceActive)
        UI.SetControlEnabled(trackerTextOutline, appearanceActive)
        UI.SetControlEnabled(trackerBackgroundOpacity, appearanceActive)
        UI.SetControlEnabled(trackerBorderEnabled, appearanceActive)
        UI.SetControlEnabled(trackerClassBorder, appearanceActive and trackerBorderEnabled:GetChecked() == true)
        UI.SetControlEnabled(trackerMouseoverControls, appearanceActive)
        UI.SetControlEnabled(trackerMinimizeToButton, appearanceActive)

    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
