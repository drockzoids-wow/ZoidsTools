local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateCombatPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)
    local rightX = 300

    local inputSection = UI.PlaceSection(frame, "Input")

    local castOnKeyDown = UI.CreateCheckbox(
        frame,
        "Cast action keybinds on key down",
        "Makes action bar keybinds fire when the key is pressed instead of when it is released.",
        function()
            return ns.GetCastOnKeyDown and ns:GetCastOnKeyDown()
        end,
        function(value)
            if ns.SetCastOnKeyDown then
                ns:SetCastOnKeyDown(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    )
    UI.PlaceFirst(castOnKeyDown, inputSection)

    local rangeTint = UI.CreateCheckbox(
        frame,
        "Tint full button when out of range",
        "Turns the full action button red when Blizzard marks the action as out of range.",
        function()
            return ns.GetActionButtonRangeTintEnabled and ns:GetActionButtonRangeTintEnabled()
        end,
        function(value)
            if ns.SetActionButtonRangeTintEnabled then
                ns:SetActionButtonRangeTintEnabled(value)
            end
        end
    )
    rangeTint:SetPoint("TOPLEFT", inputSection, "BOTTOMLEFT", rightX, -UI.Layout.firstRowGap)

    local status = UI.CreateStatusText(frame, 280)
    UI.PlaceBelow(status, castOnKeyDown, 0, 18)

    local alertsSection = UI.PlaceSection(frame, "Alerts", status)

    local buffWarnings = UI.CreateCheckbox(
        frame,
        "Warn missing group buffs",
        "While grouped and out of combat, shows a movable popup when a group-provided buff is missing.",
        function()
            return ns.GetBuffWarningsEnabled and ns:GetBuffWarningsEnabled()
        end,
        function(value)
            if ns.SetBuffWarningsEnabled then
                ns:SetBuffWarningsEnabled(value)
            end
        end
    )
    UI.PlaceFirst(buffWarnings, alertsSection)

    local combatBanner = UI.CreateCheckbox(
        frame,
        "Show in-combat banner",
        "Shows a movable IN COMBAT banner briefly when combat starts. Drag the banner to move it, or Ctrl-right-click it to reset position.",
        function()
            return ns.GetCombatBannerEnabled and ns:GetCombatBannerEnabled()
        end,
        function(value)
            if ns.SetCombatBannerEnabled then
                ns:SetCombatBannerEnabled(value)
            end
        end
    )
    combatBanner:SetPoint("TOPLEFT", alertsSection, "BOTTOMLEFT", rightX, -UI.Layout.firstRowGap)

    local combatBannerPersistent = UI.CreateCheckbox(
        frame,
        "Keep banner visible in combat",
        "Keeps the IN COMBAT banner visible until combat ends instead of hiding after a few seconds.",
        function()
            return ns.GetCombatBannerPersistent and ns:GetCombatBannerPersistent()
        end,
        function(value)
            if ns.SetCombatBannerPersistent then
                ns:SetCombatBannerPersistent(value)
            end
        end
    )
    UI.PlaceBelow(combatBannerPersistent, combatBanner)

    local combatBannerLocked = UI.CreateCheckbox(
        frame,
        "Lock banner click-through",
        "Prevents the IN COMBAT banner from catching clicks. Turn this off when you want to move it.",
        function()
            return ns.GetCombatBannerLocked and ns:GetCombatBannerLocked()
        end,
        function(value)
            if ns.SetCombatBannerLocked then
                ns:SetCombatBannerLocked(value)
            end
        end
    )
    UI.PlaceBelow(combatBannerLocked, combatBannerPersistent)

    local alertsBottom = CreateFrame("Frame", nil, frame)
    alertsBottom:SetSize(1, 1)
    alertsBottom:SetPoint("TOPLEFT", alertsSection, "BOTTOMLEFT", UI.Layout.indent, -92)

    local keybindSection = UI.PlaceSection(frame, "Action Keybind Text", alertsBottom)

    local keybindTextEnabled = UI.CreateCheckbox(
        frame,
        "Customize action keybind text",
        "Applies ZoidsTools font and label formatting to action bar keybind text.",
        function()
            return ns.GetKeybindTextEnabled and ns:GetKeybindTextEnabled()
        end,
        function(value)
            if ns.SetKeybindTextEnabled then
                ns:SetKeybindTextEnabled(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    )
    UI.PlaceFirst(keybindTextEnabled, keybindSection)

    local shortenKeybindText = UI.CreateCheckbox(
        frame,
        "Shorten keybind labels",
        "Condenses keybind labels, such as s-C to SC and Mouse4 to M4.",
        function()
            return ns.GetKeybindTextShortened and ns:GetKeybindTextShortened()
        end,
        function(value)
            if ns.SetKeybindTextShortened then
                ns:SetKeybindTextShortened(value)
            end
        end
    )
    UI.PlaceBelow(shortenKeybindText, keybindTextEnabled)

    local fontOptions = ns.GetKeybindTextFontOptions and ns:GetKeybindTextFontOptions() or {
        { value = "default", text = "Default" },
    }

    local keybindFont = UI.CreateDropdown(
        frame,
        "Keybind font",
        "Changes the font used by action bar keybind text.",
        fontOptions,
        function()
            return ns.GetKeybindTextFont and ns:GetKeybindTextFont() or "default"
        end,
        function(value)
            if ns.SetKeybindTextFont then
                ns:SetKeybindTextFont(value)
            end
        end,
        220
    )
    UI.PlaceDropdown(keybindFont, shortenKeybindText)

    local keybindFontSize = UI.CreateSlider(
        frame,
        "Keybind size",
        "Changes the action bar keybind text size.",
        8,
        24,
        1,
        function()
            return ns.GetKeybindTextFontSize and ns:GetKeybindTextFontSize() or 12
        end,
        function(value)
            if ns.SetKeybindTextFontSize then
                ns:SetKeybindTextFontSize(value)
            end
        end,
        220,
        function(value)
            return tostring(math.floor((value or 12) + 0.5))
        end
    )
    UI.PlaceSlider(keybindFontSize, keybindFont)

    local useCustomColor = UI.CreateCheckbox(
        frame,
        "Use custom color",
        "Uses your selected keybind color instead of Blizzard's default action bar keybind color.",
        function()
            return ns.GetKeybindTextUseCustomColor and ns:GetKeybindTextUseCustomColor()
        end,
        function(value)
            if ns.SetKeybindTextUseCustomColor then
                ns:SetKeybindTextUseCustomColor(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    )
    useCustomColor:SetPoint("TOPLEFT", keybindSection, "BOTTOMLEFT", rightX, -UI.Layout.firstRowGap)

    local keybindColor = UI.CreateColorPicker(
        frame,
        "Keybind color",
        "Pick a custom color for action bar keybind text. Selecting a color enables custom color.",
        function()
            if ns.GetKeybindTextColor then
                local r, g, b = ns:GetKeybindTextColor()
                local custom = ns.GetKeybindTextUseCustomColor and ns:GetKeybindTextUseCustomColor()

                return r, g, b, custom
            end

            return 1, 1, 1, false
        end,
        function(r, g, b, cancelled, previousCustom)
            if ns.SetKeybindTextColor then
                if cancelled then
                    ns:SetKeybindTextColor(r, g, b, previousCustom == true)
                else
                    ns:SetKeybindTextColor(r, g, b, true)
                end
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end,
        200
    )
    UI.PlaceBelow(keybindColor, useCustomColor, 0, 12)

    local boldKeybindText = UI.CreateCheckbox(
        frame,
        "Bold keybind text",
        "Adds a heavier keybind text treatment.",
        function()
            return ns.GetKeybindTextBold and ns:GetKeybindTextBold()
        end,
        function(value)
            if ns.SetKeybindTextBold then
                ns:SetKeybindTextBold(value)
            end
        end
    )
    UI.PlaceDropdown(boldKeybindText, keybindColor, 0)

    local outlineOptions = ns.GetKeybindTextOutlineOptions and ns:GetKeybindTextOutlineOptions() or {
        { value = "default", text = "Default" },
        { value = "none", text = "None" },
        { value = "outline", text = "Outline" },
        { value = "thick", text = "Thick Outline" },
    }

    local keybindOutline = UI.CreateDropdown(
        frame,
        "Keybind outline",
        "Changes the outline style used by action bar keybind text.",
        outlineOptions,
        function()
            return ns.GetKeybindTextOutline and ns:GetKeybindTextOutline() or "default"
        end,
        function(value)
            if ns.SetKeybindTextOutline then
                ns:SetKeybindTextOutline(value)
            end
        end,
        200
    )
    UI.PlaceDropdown(keybindOutline, boldKeybindText)

    function frame:Refresh()
        castOnKeyDown:Refresh()
        rangeTint:Refresh()
        buffWarnings:Refresh()
        combatBanner:Refresh()
        combatBannerPersistent:Refresh()
        combatBannerLocked:Refresh()
        keybindTextEnabled:Refresh()
        shortenKeybindText:Refresh()
        keybindFont:Refresh()
        keybindFontSize:Refresh()
        useCustomColor:Refresh()
        keybindColor:Refresh()
        boldKeybindText:Refresh()
        keybindOutline:Refresh()

        if ns.GetCurrentCastOnKeyDownCVar and ns:GetCurrentCastOnKeyDownCVar() then
            status:SetText("Current WoW setting: key down.")
        else
            status:SetText("Current WoW setting: key up.")
        end
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
