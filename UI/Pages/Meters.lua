local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateMetersPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local generalSection = UI.PlaceSection(frame, "Blizzard Damage Meter")

    local enabled = UI.CreateCheckbox(
        frame,
        "Enable Blizzard damage meter",
        "Uses Blizzard's built-in damage meter instead of the old ZoidsTools combat-log experiment.",
        function()
            return ns.GetBlizzardDamageMeterEnabled and ns:GetBlizzardDamageMeterEnabled()
        end,
        function(value)
            if ns.SetBlizzardDamageMeterEnabled then
                ns:SetBlizzardDamageMeterEnabled(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    )
    UI.PlaceFirst(enabled, generalSection)

    local status = UI.CreateStatusText(frame)
    UI.PlaceBelow(status, enabled, 0, 16)
    status:SetPoint("RIGHT", frame, "RIGHT", -16, 0)

    local profileSection = UI.PlaceSection(frame, "Profiles", status)

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
    applyButton:SetPoint("TOPLEFT", profileDropdown, "BOTTOMLEFT", 0, -18)
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

    local secondWindowButton = UI.CreateButton(frame, "Show Second Window", 170)
    secondWindowButton:SetPoint("LEFT", saveButton, "RIGHT", UI.Layout.buttonGap, 0)
    secondWindowButton:SetScript("OnClick", function()
        local ok, message

        if ns.ShowSecondBlizzardDamageMeterWindow then
            ok, message = ns:ShowSecondBlizzardDamageMeterWindow()
        end

        if not ok and message then
            ns:Print(message)
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    local profileStatus = UI.CreateStatusText(frame)
    UI.PlaceBelow(profileStatus, applyButton, 0, 16)
    profileStatus:SetPoint("RIGHT", frame, "RIGHT", -16, 0)

    local currentSection = UI.PlaceSection(frame, "Current Windows", profileStatus)

    local currentWindow1 = UI.CreateStatusText(frame)
    UI.PlaceFirst(currentWindow1, currentSection)
    currentWindow1:SetPoint("RIGHT", frame, "RIGHT", -16, 0)

    local currentWindow2 = UI.CreateStatusText(frame)
    UI.PlaceBelow(currentWindow2, currentWindow1, 0, 10)
    currentWindow2:SetPoint("RIGHT", frame, "RIGHT", -16, 0)

    local note = UI.CreateStatusText(frame)
    UI.PlaceBelow(note, currentWindow2, 0, 18)
    note:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    note:SetText("Use Blizzard's meter dropdowns and Edit Mode for style/type changes, then save them into the selected account-wide profile.")

    function frame:Refresh()
        enabled:Refresh()
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

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
