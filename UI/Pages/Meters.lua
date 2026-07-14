local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateMetersPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)
    local leftWidth = 340
    local rightX = 410
    local rightWidth = 300
    local textInset = UI.Layout.indent

    local customSection = UI.PlaceSection(frame, "ZoidsTools Damage Meter", nil, leftWidth)

    local customEnabled = UI.CreateCheckbox(
        frame,
        "Enable basic ZoidsTools damage meter",
        "Shows a lightweight custom window using Blizzard's built-in damage meter data.",
        function()
            return ns.GetCustomDamageMeterEnabled and ns:GetCustomDamageMeterEnabled() or false
        end,
        function(value)
            if ns.SetCustomDamageMeterEnabled then
                ns:SetCustomDamageMeterEnabled(value)
            end
        end
    )
    UI.PlaceFirst(customEnabled, customSection)

    local secondWindowEnabled = UI.CreateCheckbox(
        frame,
        "Enable second meter window",
        "Creates another independently selectable meter. Its initial width and height exactly match window 1.",
        function()
            return ns.GetCustomDamageMeterSecondWindowEnabled and ns:GetCustomDamageMeterSecondWindowEnabled() or false
        end,
        function(value)
            if ns.SetCustomDamageMeterSecondWindowEnabled then
                ns:SetCustomDamageMeterSecondWindowEnabled(value)
            end
        end
    )
    UI.PlaceBelow(secondWindowEnabled, customEnabled)

    local snapGap = UI.CreateSlider(
        frame,
        "Snapped window gap",
        "Controls the space between the two custom meters while they are snapped together.",
        0,
        24,
        1,
        function()
            return ns.GetCustomDamageMeterSnapGap and ns:GetCustomDamageMeterSnapGap() or 0
        end,
        function(value)
            if ns.SetCustomDamageMeterSnapGap then
                ns:SetCustomDamageMeterSnapGap(value)
            end
        end,
        280,
        function(value)
            local pixels = math.floor((value or 0) + 0.5)
            return pixels == 0 and "Touching" or (pixels .. " px")
        end
    )
    UI.PlaceSlider(snapGap, secondWindowEnabled)

    local backgroundOpacity = UI.CreateSlider(
        frame,
        "Meter background opacity",
        "Changes the opacity of the meter body, header background, and unfilled row backgrounds without fading text or bars.",
        0,
        1,
        0.05,
        function()
            return ns.GetCustomDamageMeterBackgroundOpacity and ns:GetCustomDamageMeterBackgroundOpacity() or 0.94
        end,
        function(value)
            if ns.SetCustomDamageMeterBackgroundOpacity then
                ns:SetCustomDamageMeterBackgroundOpacity(value)
            end
        end,
        280,
        function(value)
            return tostring(math.floor(((value or 0) * 100) + 0.5)) .. "%"
        end
    )
    UI.PlaceSlider(backgroundOpacity, snapGap)

    local classColoredBorder = UI.CreateCheckbox(
        frame,
        "Class-color meter borders",
        "Uses your character's class color for both custom meter borders. Turn this off to use the darker ZoidsTools gold.",
        function()
            return ns.GetCustomDamageMeterClassColoredBorder and ns:GetCustomDamageMeterClassColoredBorder() or false
        end,
        function(value)
            if ns.SetCustomDamageMeterClassColoredBorder then
                ns:SetCustomDamageMeterClassColoredBorder(value)
            end
        end
    )
    UI.PlaceBelow(classColoredBorder, backgroundOpacity, -UI.Layout.sliderIndent, 12)

    local textScale = UI.CreateSlider(
        frame,
        "Bar text scale",
        "Changes the size of player names, ranks, totals, and DPS in the ZoidsTools meter.",
        0.8,
        1.5,
        0.05,
        function()
            return ns.GetCustomDamageMeterTextScale and ns:GetCustomDamageMeterTextScale() or 1
        end,
        function(value)
            if ns.SetCustomDamageMeterTextScale then
                ns:SetCustomDamageMeterTextScale(value)
            end
        end,
        280,
        function(value)
            return tostring(math.floor(((value or 1) * 100) + 0.5)) .. "%"
        end
    )
    UI.PlaceSlider(textScale, classColoredBorder)

    local customStatus = UI.CreateStatusText(frame, leftWidth - textInset)
    UI.PlaceBelow(customStatus, textScale, -UI.Layout.sliderIndent, 18)

    local previewButton = UI.CreateButton(frame, "Preview / Move", 140)
    UI.PlaceBelow(previewButton, customStatus, 0, 14)
    previewButton:SetScript("OnClick", function()
        if ns.ToggleCustomDamageMeterMoveMode then
            ns:ToggleCustomDamageMeterMoveMode()
        end
        if frame.Refresh then frame:Refresh() end
    end)

    local resetPositionButton = UI.CreateButton(frame, "Reset Positions", 140)
    resetPositionButton:SetPoint("LEFT", previewButton, "RIGHT", UI.Layout.buttonGap, 0)
    resetPositionButton:SetScript("OnClick", function()
        if ns.ResetCustomDamageMeterPosition then
            ns:ResetCustomDamageMeterPosition()
        end
    end)

    local customNoteSection = UI.PlaceSection(frame, "Current Features", previewButton, leftWidth)

    local customNote = UI.CreateStatusText(frame, leftWidth - textInset)
    UI.PlaceFirst(customNote, customNoteSection)
    customNote:SetText("Each window has its own title and C/O session. Unlock to move or resize; bring any edge near the other meter to snap them together.")

    local columnDivider = frame:CreateTexture(nil, "ARTWORK")
    columnDivider:SetColorTexture(0.38, 0.40, 0.44, 0.22)
    columnDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX - 24, -2)
    columnDivider:SetSize(1, 360)

    local generalSection = UI.CreateSection(frame, "Blizzard Damage Meter", nil, 0, rightWidth)
    generalSection:ClearAllPoints()
    generalSection:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, 0)

    local status = UI.CreateStatusText(frame, rightWidth - textInset)
    UI.PlaceFirst(status, generalSection)

    local profileSection = UI.PlaceSection(frame, "Profiles", status, rightWidth)

    local profileDropdown = UI.CreateDropdown(
        frame,
        "Active Profile",
        "Choose which account-wide Blizzard damage meter layout ZoidsTools should save or apply.",
        ns.GetDamageMeterProfileOptions and ns:GetDamageMeterProfileOptions() or {},
        function()
            return ns.GetActiveDamageMeterProfileKey and ns:GetActiveDamageMeterProfileKey() or "profile1"
        end,
        function(value)
            if ns.SetActiveDamageMeterProfileKey then
                ns:SetActiveDamageMeterProfileKey(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end,
        220
    )
    UI.PlaceFirst(profileDropdown, profileSection)

    local applyButton = UI.CreateButton(frame, "Apply Profile", 140)
    applyButton:SetPoint("TOPLEFT", profileDropdown, "BOTTOMLEFT", 0, -14)
    applyButton:SetScript("OnClick", function()
        local ok, message

        if ns.ApplyDamageMeterProfile and ns.GetActiveDamageMeterProfileKey then
            ok, message = ns:ApplyDamageMeterProfile(ns:GetActiveDamageMeterProfileKey())
        end

        if ok then
            ns:Print("Damage meter profile applied.")
        elseif message then
            ns:Print(message)
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    local saveButton = UI.CreateButton(frame, "Save Current", 140)
    saveButton:SetPoint("LEFT", applyButton, "RIGHT", UI.Layout.buttonGap, 0)
    saveButton:SetScript("OnClick", function()
        local ok, message

        if ns.SaveDamageMeterProfile and ns.GetActiveDamageMeterProfileKey then
            ok, message = ns:SaveDamageMeterProfile(ns:GetActiveDamageMeterProfileKey())
        end

        if ok then
            ns:Print("Damage meter profile saved.")
        elseif message then
            ns:Print(message)
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    local profileStatus = UI.CreateStatusText(frame, rightWidth - textInset)
    UI.PlaceBelow(profileStatus, applyButton, 0, 14)

    local currentSection = UI.PlaceSection(frame, "Current Windows", profileStatus, rightWidth)

    local currentWindow1 = UI.CreateStatusText(frame, rightWidth - textInset)
    UI.PlaceFirst(currentWindow1, currentSection)

    local currentWindow2 = UI.CreateStatusText(frame, rightWidth - textInset)
    UI.PlaceBelow(currentWindow2, currentWindow1, 0, 8)

    local note = UI.CreateStatusText(frame, rightWidth - textInset)
    UI.PlaceBelow(note, currentWindow2, 0, 14)
    note:SetText("Use Blizzard's controls for meter setup. ZoidsTools saves and applies window positions outside combat.")

    function frame:Refresh()
        customEnabled:Refresh()
        secondWindowEnabled:Refresh()
        snapGap:Refresh()
        backgroundOpacity:Refresh()
        classColoredBorder:Refresh()
        textScale:Refresh()
        UI.SetControlEnabled(secondWindowEnabled, customEnabled:GetChecked() == true)
        UI.SetControlEnabled(snapGap, customEnabled:GetChecked() == true and secondWindowEnabled:GetChecked() == true)
        UI.SetControlEnabled(backgroundOpacity, customEnabled:GetChecked() == true)
        UI.SetControlEnabled(classColoredBorder, customEnabled:GetChecked() == true)
        customStatus:SetText(ns.GetCustomDamageMeterStatusText and ns:GetCustomDamageMeterStatusText() or "")
        previewButton:SetText(ns.IsCustomDamageMeterMoveMode and ns:IsCustomDamageMeterMoveMode() and "Lock Meter" or "Preview / Move")
        profileDropdown:Refresh()

        if ns.GetBlizzardDamageMeterStatusText then
            status:SetText(ns:GetBlizzardDamageMeterStatusText())
        else
            status:SetText("")
        end

        if ns.GetDamageMeterProfileSummary and ns.GetActiveDamageMeterProfileKey then
            profileStatus:SetText(ns:GetDamageMeterProfileSummary(ns:GetActiveDamageMeterProfileKey()))
        else
            profileStatus:SetText("")
        end

        if ns.GetBlizzardDamageMeterWindowSummary then
            currentWindow1:SetText(ns:GetBlizzardDamageMeterWindowSummary(1))
            currentWindow2:SetText(ns:GetBlizzardDamageMeterWindowSummary(2))
        else
            currentWindow1:SetText("")
            currentWindow2:SetText("")
        end
    end

    frame:SetScript("OnShow", function(self)
        self:SetCompactScrollOffset(0)
        self:Refresh()
    end)

    return frame
end
