local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

local createLayoutPopup = "ZOIDSTOOLS_CREATE_CHAT_LAYOUT"
local deleteLayoutPopup = "ZOIDSTOOLS_DELETE_CHAT_LAYOUT"

if StaticPopupDialogs then
    StaticPopupDialogs[createLayoutPopup] = StaticPopupDialogs[createLayoutPopup] or {
        text = "Name this chat layout:",
        button1 = SAVE or "Save",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        maxLetters = 40,
        OnShow = function(self)
            local editBox = self.EditBox or self.editBox
            if editBox then editBox:SetText(""); editBox:SetFocus() end
        end,
        OnAccept = function(self, data)
            local editBox = self.EditBox or self.editBox
            local ok, message = ns:CreateChatLayoutProfile(editBox and editBox:GetText() or "")
            if ok then ns:Print("Chat layout saved.") elseif message then ns:Print(message) end
            if data and data.page and data.page.Refresh then data.page:Refresh() end
        end,
        EditBoxOnEnterPressed = function(self)
            local popup = self:GetParent()
            if popup and popup.button1 then popup.button1:Click() end
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs[deleteLayoutPopup] = StaticPopupDialogs[deleteLayoutPopup] or {
        text = "Delete the chat layout |cffffd24a%s|r?",
        button1 = DELETE or "Delete",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            local ok, message = ns:DeleteChatLayoutProfile(data and data.key)
            if ok then ns:Print("Chat layout deleted.") elseif message then ns:Print(message) end
            if data and data.page and data.page.Refresh then data.page:Refresh() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function ns.UI.Pages.CreateChatPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local function Get(key)
        return ns.db and ns.db.chat and ns.db.chat[key]
    end

    local function Set(key, value)
        if ns.SetChatOption then
            ns:SetChatOption(key, value)
        elseif ns.db and ns.db.chat then
            ns.db.chat[key] = value
        end
    end

    local essentials = UI.PlaceSection(frame, "Essentials")

    local enabled = UI.CreateCheckbox(
        frame,
        "Enable chat enhancements",
        "Enhances Blizzard chat without replacing its message renderer or changing player-name interactions.",
        function() return Get("enabled") end,
        function(value) Set("enabled", value) end
    )
    UI.PlaceFirst(enabled, essentials)

    local copyButton = UI.CreateCheckbox(
        frame,
        "Show chat copy button",
        "Shows a subtle C button on each chat frame. It brightens on mouseover and while its searchable copy window is open.",
        function() return Get("copyButton") end,
        function(value) Set("copyButton", value) end
    )
    UI.PlaceBelow(copyButton, enabled)

    local urlCopy = UI.CreateCheckbox(
        frame,
        "Make web addresses copyable",
        "Turns web and Discord addresses into links that open a selected copy field. ZoidsTools never attempts to open a browser from the game.",
        function() return Get("urlCopy") end,
        function(value) Set("urlCopy", value) end
    )
    UI.PlaceBelow(urlCopy, copyButton)

    local enhancedScroll = UI.CreateCheckbox(
        frame,
        "Use enhanced chat scrolling",
        "Shift-wheel scrolls several lines. Ctrl-wheel jumps to the oldest or newest retained message.",
        function() return Get("enhancedScroll") end,
        function(value) Set("enhancedScroll", value) end
    )
    UI.PlaceBelow(enhancedScroll, urlCopy)

    local copyNow = UI.CreateButton(frame, "Open Chat Copy", 154)
    UI.PlaceBelow(copyNow, enhancedScroll, 0, 14)
    copyNow:SetScript("OnClick", function()
        if ns.ShowChatCopy then ns:ShowChatCopy(SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME) end
    end)
    UI.RegisterSearchControl(frame, copyNow, "Open Chat Copy", "Opens the searchable chat copy window for the active chat tab.")

    local activity = UI.PlaceSection(frame, "Message Awareness", copyNow)

    local newMessageIndicator = UI.CreateCheckbox(
        frame,
        "Show new-message button while scrolled up",
        "Shows a small button when new chat arrives while you are reading older messages. Clicking it jumps to the newest message.",
        function() return Get("newMessageIndicator") end,
        function(value) Set("newMessageIndicator", value) end
    )
    UI.PlaceFirst(newMessageIndicator, activity)

    local mentionHighlight = UI.CreateCheckbox(
        frame,
        "Highlight messages that mention my name",
        "Highlights full-word mentions of your current character name without changing normal player links.",
        function() return Get("mentionHighlight") end,
        function(value) Set("mentionHighlight", value) end
    )
    UI.PlaceBelow(mentionHighlight, newMessageIndicator)

    local mentionSound = UI.CreateCheckbox(
        frame,
        "Play a sound for mentions",
        "Plays one alert sound when a highlighted mention arrives.",
        function() return Get("mentionSound") end,
        function(value) Set("mentionSound", value) end
    )
    UI.PlaceBelow(mentionSound, mentionHighlight)

    local appearance = UI.PlaceSection(frame, "Appearance", mentionSound)

    local mouseoverControls = UI.CreateCheckbox(
        frame,
        "Show chat controls only on mouseover",
        "Hides Blizzard chat tabs and navigation controls until the related chat frame is hovered.",
        function() return Get("mouseoverControls") end,
        function(value) Set("mouseoverControls", value) end
    )
    UI.PlaceFirst(mouseoverControls, appearance)

    local backgroundEnabled = UI.CreateCheckbox(
        frame,
        "Customize chat background",
        "Allows ZoidsTools to control the background opacity of Blizzard chat frames.",
        function() return Get("backgroundEnabled") end,
        function(value) Set("backgroundEnabled", value) end
    )
    UI.PlaceBelow(backgroundEnabled, mouseoverControls)

    local backgroundMouseover = UI.CreateCheckbox(
        frame,
        "Show background only on mouseover",
        "Keeps the chat background transparent until the chat frame is hovered.",
        function() return Get("backgroundMouseover") end,
        function(value) Set("backgroundMouseover", value) end
    )
    UI.PlaceBelow(backgroundMouseover, backgroundEnabled)

    local backgroundOpacity = UI.CreateSlider(
        frame,
        "Background opacity",
        "Controls the visible chat background opacity.",
        0,
        1,
        0.05,
        function() return tonumber(Get("backgroundOpacity")) or 0.28 end,
        function(value) Set("backgroundOpacity", value) end,
        250,
        function(value) return string.format("%d%%", math.floor((value * 100) + 0.5)) end
    )
    UI.PlaceSlider(backgroundOpacity, backgroundMouseover)

    local typography = UI.PlaceSection(frame, "Text and Fading", backgroundOpacity)

    local customFont = UI.CreateCheckbox(
        frame,
        "Use shared chat font size",
        "Applies one account-wide font size to Blizzard chat frames. Disable this to restore each frame's original font.",
        function() return Get("customFont") end,
        function(value) Set("customFont", value) end
    )
    UI.PlaceFirst(customFont, typography)

    local fontSize = UI.CreateSlider(
        frame,
        "Chat font size",
        "Sets the account-wide chat font size when shared sizing is enabled.",
        9,
        24,
        1,
        function() return tonumber(Get("fontSize")) or 14 end,
        function(value) Set("fontSize", value) end,
        250,
        function(value) return tostring(math.floor(value + 0.5)) end
    )
    UI.PlaceSlider(fontSize, customFont)

    local fontOutline = UI.CreateCheckbox(
        frame,
        "Outline chat text",
        "Adds a thin outline when the shared chat font size is enabled.",
        function() return Get("fontOutline") end,
        function(value) Set("fontOutline", value) end
    )
    UI.PlaceBelow(fontOutline, fontSize, -UI.Layout.sliderIndent, 18)

    local disableFading = UI.CreateCheckbox(
        frame,
        "Keep chat messages visible",
        "Disables Blizzard's automatic message fading.",
        function() return Get("disableFading") end,
        function(value) Set("disableFading", value) end
    )
    UI.PlaceBelow(disableFading, fontOutline)

    local fadeDelay = UI.CreateSlider(
        frame,
        "Fade delay",
        "Sets how long messages remain visible before Blizzard begins fading them.",
        10,
        600,
        10,
        function() return tonumber(Get("fadeDelay")) or 120 end,
        function(value) Set("fadeDelay", value) end,
        250,
        function(value) return string.format("%ds", math.floor(value + 0.5)) end
    )
    UI.PlaceSlider(fadeDelay, disableFading)

    local historySection = UI.PlaceSection(frame, "Saved History", fadeDelay)

    local historyEnabled = UI.CreateCheckbox(
        frame,
        "Save recent chat between sessions",
        "Stores rendered messages from the chat tab visible when you log out or reload. This is off by default and never uploads or shares chat text.",
        function() return Get("historyEnabled") end,
        function(value) Set("historyEnabled", value) end
    )
    UI.PlaceFirst(historyEnabled, historySection)

    local historyRestore = UI.CreateCheckbox(
        frame,
        "Restore recent messages at login",
        "Adds up to the 50 most recent saved lines to the General tab when you log in.",
        function() return Get("historyRestore") end,
        function(value) Set("historyRestore", value) end
    )
    UI.PlaceBelow(historyRestore, historyEnabled)

    local historyLimit = UI.CreateSlider(
        frame,
        "Saved message limit",
        "Limits saved history for each character.",
        100,
        500,
        50,
        function() return tonumber(Get("historyLimit")) or 250 end,
        function(value) Set("historyLimit", value) end,
        250,
        function(value) return tostring(math.floor(value + 0.5)) end
    )
    UI.PlaceSlider(historyLimit, historyRestore)

    local viewHistory = UI.CreateButton(frame, "View Saved History", 154)
    UI.PlaceBelow(viewHistory, historyLimit, 0, 14)
    viewHistory:SetScript("OnClick", function()
        if ns.ShowSavedChatHistory then ns:ShowSavedChatHistory() end
    end)

    local clearHistory = UI.CreateButton(frame, "Clear Saved History", 154)
    clearHistory:SetPoint("LEFT", viewHistory, "RIGHT", UI.Layout.buttonGap, 0)
    clearHistory:SetScript("OnClick", function()
        if ns.ClearSavedChatHistory and ns:ClearSavedChatHistory() then
            ns:Print("Saved chat history cleared for this character.")
        end
    end)

    local inputSection = UI.PlaceSection(frame, "Chat Input", viewHistory)

    local styledEditBox = UI.CreateCheckbox(
        frame,
        "Style the chat typing box",
        "Applies a subtle ZoidsTools background and border while preserving Blizzard's chat behavior.",
        function() return Get("styledEditBox") end,
        function(value) Set("styledEditBox", value) end
    )
    UI.PlaceFirst(styledEditBox, inputSection)

    local editBoxPosition = UI.CreateDropdown(
        frame,
        "Typing box position",
        "Attaches the typing box to the full width of its chat frame, or restores Blizzard's original placement.",
        {
            { value = "bottom", text = "Attached Below" },
            { value = "top", text = "Attached Above" },
            { value = "blizzard", text = "Blizzard Default" },
        },
        function()
            local value = Get("editBoxPosition") or "bottom"
            return value == "default" and "bottom" or value
        end,
        function(value) Set("editBoxPosition", value) end,
        260
    )
    UI.PlaceDropdown(editBoxPosition, styledEditBox, 0)

    local editBoxFont = UI.CreateDropdown(
        frame,
        "Typing font",
        "Changes the font used for text entered into Blizzard's chat typing box.",
        {
            { value = "default", text = "Blizzard Default" },
            { value = "friz", text = "Friz Quadrata" },
            { value = "arial", text = "Arial Narrow" },
            { value = "morpheus", text = "Morpheus" },
            { value = "skurri", text = "Skurri" },
            { value = "damage", text = "Damage" },
        },
        function() return Get("editBoxFont") or "default" end,
        function(value) Set("editBoxFont", value) end,
        260
    )
    UI.PlaceDropdown(editBoxFont, editBoxPosition, 0)

    local editBoxFontSize = UI.CreateSlider(
        frame,
        "Typing font size",
        "Changes the typed-text size and adjusts the attached typing box height to fit.",
        10,
        20,
        1,
        function() return tonumber(Get("editBoxFontSize")) or 14 end,
        function(value) Set("editBoxFontSize", value) end,
        250,
        function(value) return tostring(math.floor((value or 14) + 0.5)) end
    )
    UI.PlaceSlider(editBoxFontSize, editBoxFont)

    local arrowKeyHistory = UI.CreateCheckbox(
        frame,
        "Use Up and Down for sent-message history",
        "Lets the arrow keys recall messages without holding Alt while the typing box is focused.",
        function() return Get("arrowKeyHistory") end,
        function(value) Set("arrowKeyHistory", value) end
    )
    UI.PlaceBelow(arrowKeyHistory, editBoxFontSize, -UI.Layout.sliderIndent, 18)

    local channelIndicator = UI.CreateCheckbox(
        frame,
        "Emphasize the active chat channel",
        "Uses ZoidsTools gold on Blizzard's channel label in the typing box.",
        function() return Get("channelIndicator") end,
        function(value) Set("channelIndicator", value) end
    )
    UI.PlaceBelow(channelIndicator, arrowKeyHistory)

    local profilesSection = UI.PlaceSection(frame, "Account-Wide Chat Layouts", channelIndicator)

    local profileDropdown = UI.CreateDropdown(
        frame,
        "Selected Layout",
        "Saves Blizzard chat tabs, message filters, channels, font sizes, docking, window sizes, and undocked positions for reuse on other characters.",
        ns.GetChatLayoutProfileOptions and ns:GetChatLayoutProfileOptions() or {},
        function() return ns.GetSelectedChatLayoutProfile and ns:GetSelectedChatLayoutProfile() end,
        function(value)
            if ns.SetSelectedChatLayoutProfile then ns:SetSelectedChatLayoutProfile(value) end
            if frame.Refresh then frame:Refresh() end
        end,
        300
    )
    UI.PlaceFirst(profileDropdown, profilesSection)

    local saveNewProfile = UI.CreateButton(frame, "Save New Layout", 144)
    UI.PlaceBelow(saveNewProfile, profileDropdown, 0, 12)
    saveNewProfile:SetScript("OnClick", function()
        if StaticPopup_Show then StaticPopup_Show(createLayoutPopup, nil, nil, { page = frame }) end
    end)

    local updateProfile = UI.CreateButton(frame, "Update Selected", 144)
    updateProfile:SetPoint("LEFT", saveNewProfile, "RIGHT", UI.Layout.buttonGap, 0)
    updateProfile:SetScript("OnClick", function()
        local key = ns.GetSelectedChatLayoutProfile and ns:GetSelectedChatLayoutProfile()
        local ok, message = ns.SaveChatLayoutProfile and ns:SaveChatLayoutProfile(key)
        if ok then ns:Print("Chat layout updated.") elseif message then ns:Print(message) end
        frame:Refresh()
    end)

    local applyProfile = UI.CreateButton(frame, "Apply Selected", 144)
    UI.PlaceBelow(applyProfile, saveNewProfile, 0, 10)
    applyProfile:SetScript("OnClick", function()
        local key = ns.GetSelectedChatLayoutProfile and ns:GetSelectedChatLayoutProfile()
        local ok, message = ns.ApplyChatLayoutProfile and ns:ApplyChatLayoutProfile(key)
        if ok then ns:Print("Chat layout applied.") elseif message then ns:Print(message) end
        frame:Refresh()
    end)

    local deleteProfile = UI.CreateButton(frame, "Delete Selected", 144)
    deleteProfile:SetPoint("LEFT", applyProfile, "RIGHT", UI.Layout.buttonGap, 0)
    deleteProfile:SetScript("OnClick", function()
        local key = ns.GetSelectedChatLayoutProfile and ns:GetSelectedChatLayoutProfile()
        if not key then return end
        local name = ns.GetChatLayoutProfileName and ns:GetChatLayoutProfileName(key) or key
        if StaticPopup_Show then StaticPopup_Show(deleteLayoutPopup, name, nil, { key = key, page = frame }) end
    end)

    local profileStatus = UI.CreateStatusText(frame, 620)
    UI.PlaceBelow(profileStatus, applyProfile, 0, 14)

    local generalTab = UI.CreateButton(frame, "General", 126)
    generalTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    local historyTab = UI.CreateButton(frame, "History & Input", 146)
    historyTab:SetPoint("LEFT", generalTab, "RIGHT", UI.Layout.buttonGap, 0)
    local layoutsTab = UI.CreateButton(frame, "Chat Layouts", 136)
    layoutsTab:SetPoint("LEFT", historyTab, "RIGHT", UI.Layout.buttonGap, 0)

    local function AnchorSection(section, x, y, width)
        section:ClearAllPoints()
        section:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        section:SetWidth(width)
    end

    AnchorSection(essentials, 0, -48, 360)
    activity:ClearAllPoints()
    activity:SetPoint("TOPLEFT", copyNow, "BOTTOMLEFT", -UI.Layout.indent, -UI.Layout.sectionGap)
    activity:SetWidth(360)
    AnchorSection(appearance, 400, -48, 330)
    typography:ClearAllPoints()
    typography:SetPoint("TOPLEFT", backgroundOpacity, "BOTTOMLEFT", -UI.Layout.indent - UI.Layout.sliderIndent, -UI.Layout.sectionGap)
    typography:SetWidth(330)

    AnchorSection(historySection, 0, -48, 360)
    AnchorSection(inputSection, 400, -48, 330)
    AnchorSection(profilesSection, 0, -48, 700)

    local generalControls = {
        essentials, enabled, copyButton, urlCopy, enhancedScroll, copyNow,
        activity, newMessageIndicator, mentionHighlight, mentionSound,
        appearance, mouseoverControls, backgroundEnabled, backgroundMouseover, backgroundOpacity,
        typography, customFont, fontSize, fontOutline, disableFading, fadeDelay,
    }
    local historyControls = {
        historySection, historyEnabled, historyRestore, historyLimit, viewHistory, clearHistory,
        inputSection, styledEditBox, editBoxPosition, editBoxFont, editBoxFontSize, arrowKeyHistory, channelIndicator,
    }
    local layoutControls = {
        profilesSection, profileDropdown, saveNewProfile, updateProfile, applyProfile, deleteProfile, profileStatus,
    }
    local activePanel = "general"

    local function SetGroupShown(group, shown)
        for _, control in ipairs(group) do control:SetShown(shown) end
    end

    local function ShowPanel(panel)
        activePanel = panel
        SetGroupShown(generalControls, panel == "general")
        SetGroupShown(historyControls, panel == "history")
        SetGroupShown(layoutControls, panel == "layouts")
        generalTab:SetStyledSelected(panel == "general")
        historyTab:SetStyledSelected(panel == "history")
        layoutsTab:SetStyledSelected(panel == "layouts")
        if frame.SetCompactScrollOffset then frame:SetCompactScrollOffset(0) end
    end

    generalTab:SetScript("OnClick", function() ShowPanel("general") end)
    historyTab:SetScript("OnClick", function() ShowPanel("history") end)
    layoutsTab:SetScript("OnClick", function() ShowPanel("layouts") end)

    for _, control in ipairs(generalControls) do
        control.ZTRevealForSearch = function() ShowPanel("general") end
    end
    for _, control in ipairs(historyControls) do
        control.ZTRevealForSearch = function() ShowPanel("history") end
    end
    for _, control in ipairs(layoutControls) do
        control.ZTRevealForSearch = function() ShowPanel("layouts") end
    end

    function frame:Refresh()
        enabled:Refresh()
        copyButton:Refresh()
        urlCopy:Refresh()
        enhancedScroll:Refresh()
        newMessageIndicator:Refresh()
        mentionHighlight:Refresh()
        mentionSound:Refresh()
        mouseoverControls:Refresh()
        backgroundEnabled:Refresh()
        backgroundMouseover:Refresh()
        backgroundOpacity:Refresh()
        customFont:Refresh()
        fontSize:Refresh()
        fontOutline:Refresh()
        disableFading:Refresh()
        fadeDelay:Refresh()
        historyEnabled:Refresh()
        historyRestore:Refresh()
        historyLimit:Refresh()
        styledEditBox:Refresh()
        editBoxPosition:Refresh()
        editBoxFont:Refresh()
        editBoxFontSize:Refresh()
        arrowKeyHistory:Refresh()
        channelIndicator:Refresh()

        local profileOptions = ns.GetChatLayoutProfileOptions and ns:GetChatLayoutProfileOptions() or {}
        if profileDropdown.SetOptions then profileDropdown:SetOptions(profileOptions) end
        profileDropdown:Refresh()

        local active = enabled:GetChecked() == true
        local backgroundActive = active and backgroundEnabled:GetChecked() == true
        local fontActive = active and customFont:GetChecked() == true

        UI.SetControlEnabled(copyButton, active)
        UI.SetControlEnabled(urlCopy, active)
        UI.SetControlEnabled(enhancedScroll, active)
        UI.SetControlEnabled(copyNow, active)
        UI.SetControlEnabled(newMessageIndicator, active)
        UI.SetControlEnabled(mentionHighlight, active)
        UI.SetControlEnabled(mentionSound, active and mentionHighlight:GetChecked() == true)
        UI.SetControlEnabled(mouseoverControls, active)
        UI.SetControlEnabled(backgroundEnabled, active)
        UI.SetControlEnabled(backgroundMouseover, backgroundActive)
        UI.SetControlEnabled(backgroundOpacity, backgroundActive)
        UI.SetControlEnabled(customFont, active)
        UI.SetControlEnabled(fontSize, fontActive)
        UI.SetControlEnabled(fontOutline, fontActive)
        UI.SetControlEnabled(disableFading, active)
        UI.SetControlEnabled(fadeDelay, active and not disableFading:GetChecked())
        local historyActive = active and historyEnabled:GetChecked() == true
        UI.SetControlEnabled(historyEnabled, active)
        UI.SetControlEnabled(historyRestore, historyActive)
        UI.SetControlEnabled(historyLimit, historyActive)
        UI.SetControlEnabled(viewHistory, active)
        UI.SetControlEnabled(clearHistory, active)
        UI.SetControlEnabled(styledEditBox, active)
        UI.SetControlEnabled(editBoxPosition, active)
        UI.SetControlEnabled(editBoxFont, active)
        UI.SetControlEnabled(editBoxFontSize, active)
        UI.SetControlEnabled(arrowKeyHistory, active)
        UI.SetControlEnabled(channelIndicator, active)

        local selectedProfile = ns.GetSelectedChatLayoutProfile and ns:GetSelectedChatLayoutProfile()
        UI.SetControlEnabled(updateProfile, selectedProfile ~= nil)
        UI.SetControlEnabled(applyProfile, selectedProfile ~= nil)
        UI.SetControlEnabled(deleteProfile, selectedProfile ~= nil)
        profileStatus:SetFormattedText("%d saved layout%s. Profiles are shared across all characters.", #profileOptions, #profileOptions == 1 and "" or "s")
        ShowPanel(activePanel)
    end

    ShowPanel("general")
    frame:SetScript("OnShow", frame.Refresh)
    return frame
end
