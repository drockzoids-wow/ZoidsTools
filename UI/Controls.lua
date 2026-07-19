local _, ns = ...

ns.UI = ns.UI or {}

local UI = ns.UI
local Theme = UI.Theme
local controlCounter = 0

UI.SearchEntries = UI.SearchEntries or {}

function UI.SetControlEnabled(control, enabled)
    if not control then return end

    enabled = enabled == true
    control:SetAlpha(enabled and 1 or 0.42)

    if enabled and control.Enable then
        control:Enable()
    elseif not enabled and control.Disable then
        control:Disable()
    end

    if control.button then
        if enabled and control.button.Enable then
            control.button:Enable()
        elseif not enabled and control.button.Disable then
            control.button:Disable()
        end
    end
end

function UI.RegisterSearchControl(parent, control, label, tooltip)
    local pageKey = (parent and parent.ZTPageKey) or UI.BuildingPageKey
    if not pageKey or not control or not label then return end

    UI.SearchEntries[#UI.SearchEntries + 1] = {
        pageKey = pageKey,
        control = control,
        label = tostring(label),
        tooltip = tostring(tooltip or ""),
    }
end

UI.Layout = UI.Layout or {
    indent = 12,
    rowGap = 7,
    firstRowGap = 9,
    controlGap = 12,
    sectionGap = 24,
    sliderIndent = 10,
    sliderGap = 18,
    buttonGap = 8,
    columnGap = 24,
}

function UI.CreateCheckbox(parent, label, tooltip, getter, setter)
    local checkbox = CreateFrame("CheckButton", nil, parent)
    checkbox:SetSize(30, 20)
    checkbox.tooltip = tooltip

    checkbox.track = checkbox:CreateTexture(nil, "BACKGROUND")
    checkbox.track:SetPoint("CENTER")
    checkbox.track:SetSize(28, 14)

    checkbox.knob = checkbox:CreateTexture(nil, "ARTWORK")
    checkbox.knob:SetSize(10, 10)

    checkbox.Text = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 7, 0)
    checkbox.Text:SetText(label)
    checkbox.Text:SetTextColor(0.86, 0.87, 0.89)
    checkbox:SetHitRectInsets(0, -math.min(230, checkbox.Text:GetStringWidth() + 9), 0, 0)

    checkbox:SetScript("OnEnter", function(self)
        if not self.tooltip then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label)
        GameTooltip:AddLine(self.tooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    checkbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    checkbox:SetScript("OnClick", function(self)
        setter(self:GetChecked() == true)

        if self.Refresh then
            self:Refresh()
        end

        if parent and parent.Refresh then
            parent:Refresh()
        end
    end)

    function checkbox:Refresh()
        local checked = getter() == true
        self:SetChecked(checked)
        self.knob:ClearAllPoints()

        if checked then
            self.track:SetColorTexture(0.76, 0.55, 0.12, 0.94)
            self.knob:SetColorTexture(1, 0.90, 0.56, 1)
            self.knob:SetPoint("RIGHT", self.track, "RIGHT", -2, 0)
        else
            self.track:SetColorTexture(0.18, 0.20, 0.24, 0.96)
            self.knob:SetColorTexture(0.60, 0.62, 0.66, 1)
            self.knob:SetPoint("LEFT", self.track, "LEFT", 2, 0)
        end
    end

    checkbox:Refresh()

    UI.RegisterSearchControl(parent, checkbox, label, tooltip)

    return checkbox
end

local function SetStyledButtonState(button)
    local selected = button.ZTSelected == true
    local hovered = button.ZTHovered == true
    local pushed = button.ZTPushed == true

    if pushed then
        button.bg:SetColorTexture(0.14, 0.11, 0.055, 0.98)
        button.highlight:SetAlpha(0.12)
    elseif selected then
        button.bg:SetColorTexture(0.13, 0.105, 0.052, 0.98)
        button.highlight:SetAlpha(0.14)
    elseif hovered then
        button.bg:SetColorTexture(0.075, 0.080, 0.092, 0.98)
        button.highlight:SetAlpha(0.08)
    else
        button.bg:SetColorTexture(0.030, 0.034, 0.042, 0.98)
        button.highlight:SetAlpha(0)
    end

    button.text:ClearAllPoints()

    if button.ZTTextAlign == "LEFT" then
        button.text:SetPoint("LEFT", button, "LEFT", (button.ZTTextInset or 16) + (pushed and 1 or 0), pushed and -1 or 0)
        button.text:SetPoint("RIGHT", button, "RIGHT", -12 + (pushed and 1 or 0), pushed and -1 or 0)
        button.text:SetJustifyH("LEFT")
    else
        button.text:SetPoint("LEFT", button, "LEFT", 12 + (pushed and 1 or 0), pushed and -1 or 0)
        button.text:SetPoint("RIGHT", button, "RIGHT", -12 + (pushed and 1 or 0), pushed and -1 or 0)
        button.text:SetJustifyH("CENTER")
    end

    if selected or hovered or pushed then
        button:SetBackdropBorderColor(0.72, 0.54, 0.18, 0.68)
        button.topLine:SetVertexColor(0.95, 0.72, 0.28, 0.18)
        button.bottomLine:SetVertexColor(0.95, 0.72, 0.28, 0.10)
        button.text:SetTextColor(1, 0.84, 0.32)
    else
        button:SetBackdropBorderColor(0.25, 0.28, 0.33, 0.78)
        button.topLine:SetVertexColor(0.55, 0.58, 0.63, 0.08)
        button.bottomLine:SetVertexColor(0.55, 0.58, 0.63, 0.05)
        button.text:SetTextColor(0.84, 0.85, 0.87)
    end
end

function UI.CreateButton(parent, text, width, height)
    local buttonHeight = height or 27
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 132, buttonHeight)
    button:RegisterForClicks("AnyUp")
    button:SetBackdrop({
        bgFile = Theme and Theme.panelBg or "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 7,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetPoint("TOPLEFT", 2, -2)
    button.bg:SetPoint("BOTTOMRIGHT", -2, 2)

    button.highlight = button:CreateTexture(nil, "BORDER")
    button.highlight:SetPoint("TOPLEFT", 2, -2)
    button.highlight:SetPoint("BOTTOMRIGHT", -2, 2)
    button.highlight:SetColorTexture(1, 0.82, 0.25, 1)

    button.topLine = button:CreateTexture(nil, "ARTWORK")
    button.topLine:SetPoint("TOPLEFT", 8, -2)
    button.topLine:SetPoint("TOPRIGHT", -8, -2)
    button.topLine:SetHeight(1)
    button.topLine:SetColorTexture(1, 1, 1, 1)

    button.bottomLine = button:CreateTexture(nil, "ARTWORK")
    button.bottomLine:SetPoint("BOTTOMLEFT", 8, 2)
    button.bottomLine:SetPoint("BOTTOMRIGHT", -8, 2)
    button.bottomLine:SetHeight(1)
    button.bottomLine:SetColorTexture(1, 1, 1, 1)

    button.leftCap = button:CreateTexture(nil, "ARTWORK")
    button.leftCap:SetSize(1, 1)
    button.leftCap:SetAlpha(0)

    button.rightCap = button:CreateTexture(nil, "ARTWORK")
    button.rightCap:SetSize(1, 1)
    button.rightCap:SetAlpha(0)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("CENTER")
    button.text:SetText(text)

    if button.text.SetWordWrap then
        button.text:SetWordWrap(false)
    end

    function button:SetText(value)
        self.text:SetText(value)
    end

    function button:GetText()
        return self.text:GetText()
    end

    function button:SetStyledSelected(value)
        self.ZTSelected = value == true
        SetStyledButtonState(self)
    end

    function button:SetStyledHover(value)
        self.ZTHovered = value == true
        SetStyledButtonState(self)
    end

    function button:SetStyledTextAlign(value)
        self.ZTTextAlign = value
        SetStyledButtonState(self)
    end

    function button:SetStyledTextInset(value)
        self.ZTTextInset = value
        SetStyledButtonState(self)
    end

    button:SetScript("OnEnter", function(self)
        self:SetStyledHover(true)
    end)

    button:SetScript("OnLeave", function(self)
        self:SetStyledHover(false)
    end)

    button:SetScript("OnMouseDown", function(self)
        self.ZTPushed = true
        SetStyledButtonState(self)
    end)

    button:SetScript("OnMouseUp", function(self)
        self.ZTPushed = nil
        SetStyledButtonState(self)
    end)

    SetStyledButtonState(button)

    return button
end

function UI.CreateSection(parent, text, anchor, offsetY, width)
    local section = CreateFrame("Frame", nil, parent)
    section:SetHeight(22)

    if anchor then
        section:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -20)
    else
        section:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, offsetY or 0)
    end

    if width then
        section:SetWidth(width)
    else
        section:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    end

    section.label = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    section.label:SetPoint("LEFT", 0, 0)
    section.label:SetTextColor(0.94, 0.73, 0.30)
    section.label:SetText(text)

    section.divider = section:CreateTexture(nil, "ARTWORK")
    section.divider:SetColorTexture(0.38, 0.40, 0.44, 0.38)
    section.divider:SetPoint("LEFT", section.label, "RIGHT", 9, 0)
    section.divider:SetPoint("RIGHT", section, "RIGHT", 0, 0)
    section.divider:SetHeight(1)

    return section
end

function UI.CreateBodyText(parent, text, width)
    local body = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    body:SetWidth(width or 760)
    body:SetJustifyH("LEFT")
    body:SetTextColor(0.88, 0.86, 0.78)
    body:SetText(text)
    return body
end

function UI.CreateStatusText(parent, width)
    local status = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetWidth(width or 760)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.78, 0.82, 0.78)
    return status
end

function UI.PlaceFirst(control, section, xOffset)
    control:SetPoint("TOPLEFT", section, "BOTTOMLEFT", xOffset or UI.Layout.indent, -UI.Layout.firstRowGap)
end

function UI.PlaceBelow(control, anchor, xOffset, gap)
    control:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset or 0, -(gap or UI.Layout.rowGap))
end

function UI.PlaceDropdown(control, anchor, xOffset)
    UI.PlaceBelow(control, anchor, xOffset or 0, UI.Layout.controlGap)
end

function UI.PlaceSlider(control, anchor, xOffset)
    UI.PlaceBelow(control, anchor, xOffset or UI.Layout.sliderIndent, UI.Layout.sliderGap)
end

function UI.PlaceSection(parent, text, anchor, width)
    local section = UI.CreateSection(parent, text, nil, 0, width)

    if anchor then
        section:ClearAllPoints()
        section:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -UI.Layout.indent, -UI.Layout.sectionGap)

        if not width then
            section:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
        end
    end

    return section
end

function UI.CreateDropdown(parent, label, tooltip, options, getter, setter, width)
    local control = CreateFrame("Frame", nil, parent)
    local dropdownWidth = width or 240
    local rowHeight = 26
    options = type(options) == "table" and options or {}

    control:SetSize(dropdownWidth, 48)

    control.label = control:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    control.label:SetPoint("TOPLEFT", 0, 0)
    control.label:SetTextColor(0.95, 0.72, 0.28)
    control.label:SetText(label)

    control.button = CreateFrame("Button", nil, control, "BackdropTemplate")
    control.button:SetPoint("TOPLEFT", control.label, "BOTTOMLEFT", 0, -4)
    control.button:SetSize(dropdownWidth, 27)
    control.button:RegisterForClicks("LeftButtonUp")
    control.button:SetBackdrop({
        bgFile = Theme and Theme.panelBg or "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 7,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    control.button:SetBackdropColor(0.012, 0.014, 0.018, 0.95)
    control.button:SetBackdropBorderColor(0.25, 0.28, 0.33, 0.82)

    control.button.text = control.button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    control.button.text:SetPoint("LEFT", control.button, "LEFT", 10, 0)
    control.button.text:SetPoint("RIGHT", control.button, "RIGHT", -30, 0)
    control.button.text:SetJustifyH("LEFT")
    control.button.text:SetTextColor(0.94, 0.92, 0.86)

    if control.button.text.SetWordWrap then
        control.button.text:SetWordWrap(false)
    end

    control.button.arrow = control.button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    control.button.arrow:SetPoint("RIGHT", control.button, "RIGHT", -10, 0)
    control.button.arrow:SetText("v")

    -- Parent popup menus to the main window rather than the scrolling page.
    -- The content viewport deliberately clips its children, which otherwise
    -- cuts off dropdown rows near the bottom of a settings page.
    local menuParent = UI.frame or UIParent or parent
    control.menu = CreateFrame("Frame", nil, menuParent, "BackdropTemplate")
    control.menu:SetSize(dropdownWidth, (#options * rowHeight) + 12)
    control.menu:SetFrameStrata("TOOLTIP")
    control.menu:SetFrameLevel(math.max(100, ((menuParent.GetFrameLevel and menuParent:GetFrameLevel()) or 0) + 50))
    control.menu:SetToplevel(true)
    control.menu:SetClampedToScreen(true)
    control.menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    control.menu:SetBackdropColor(0.012, 0.014, 0.018, 1)
    control.menu:SetBackdropBorderColor(0.75, 0.60, 0.30, 0.58)
    control.menu:Hide()

    local function PositionMenu()
        control.menu:ClearAllPoints()

        local buttonBottom = control.button:GetBottom()
        local menuHeight = control.menu:GetHeight() or 0

        if buttonBottom and buttonBottom < (menuHeight + 12) then
            control.menu:SetPoint("BOTTOMLEFT", control.button, "TOPLEFT", 0, 2)
        else
            control.menu:SetPoint("TOPLEFT", control.button, "BOTTOMLEFT", 0, -2)
        end
    end

    if tooltip then
        control.button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)

        control.button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    local function GetSelectedText(value)
        for _, option in ipairs(options) do
            if option.value == value then
                return option.text
            end
        end

        return "None"
    end

    local function HideIfMouseAway()
        if not control.button:IsMouseOver() and not control.menu:IsMouseOver() then
            control.menu:Hide()
            control.button.arrow:SetText("v")
        end
    end

    local function ScheduleMouseAwayHide()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.8, HideIfMouseAway)
        end
    end

    control.rows = {}

    local function GetOrCreateRow(index)
        local row = control.rows[index]
        if row then return row end

        row = CreateFrame("Button", nil, control.menu, "BackdropTemplate")
        row:SetPoint("TOPLEFT", control.menu, "TOPLEFT", 8, -6 - ((index - 1) * rowHeight))
        row:SetSize(dropdownWidth - 16, rowHeight)
        row:RegisterForClicks("LeftButtonUp")

        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetPoint("TOPLEFT", 2, -1)
        row.highlight:SetPoint("BOTTOMRIGHT", -2, 1)
        row.highlight:SetColorTexture(1, 0.82, 0.18, 0.08)
        row.highlight:Hide()

        row.check = row:CreateTexture(nil, "OVERLAY")
        row.check:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.check:SetSize(16, 16)
        row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        row.check:SetVertexColor(1, 0.86, 0.12, 1)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 28, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.text:SetJustifyH("LEFT")

        row:SetScript("OnClick", function(self)
            if self.option then setter(self.option.value) end
            if control.Refresh then control:Refresh() end
            control.menu:Hide()
            control.button.arrow:SetText("v")
        end)

        row:SetScript("OnEnter", function(self)
            self.highlight:Show()
            self.text:SetTextColor(1, 0.86, 0.18)
        end)

        row:SetScript("OnLeave", function(self)
            self.highlight:Hide()
            self.text:SetTextColor(1, 1, 1)

            ScheduleMouseAwayHide()
        end)

        control.rows[index] = row
        return row
    end

    function control:SetOptions(newOptions)
        options = type(newOptions) == "table" and newOptions or {}
        self.menu:SetHeight(math.max(12, (#options * rowHeight) + 12))

        for index, option in ipairs(options) do
            local row = GetOrCreateRow(index)
            row.option = option
            row.text:SetText(option.text or tostring(option.value or ""))
            row:Show()
        end

        for index = #options + 1, #self.rows do
            self.rows[index].option = nil
            self.rows[index]:Hide()
        end

        if self.Refresh then self:Refresh() end
    end

    control.button:SetScript("OnClick", function()
        if control.menu:IsShown() then
            control.menu:Hide()
            control.button.arrow:SetText("v")
        else
            control:Refresh()
            PositionMenu()
            control.menu:Show()
            control.button.arrow:SetText("^")
        end
    end)

    control.button:HookScript("OnLeave", function()
        ScheduleMouseAwayHide()
    end)

    control.menu:SetScript("OnLeave", function()
        ScheduleMouseAwayHide()
    end)

    local function CloseMenu()
        control.menu:Hide()
        control.button.arrow:SetText("v")
    end

    control:HookScript("OnHide", CloseMenu)
    if parent and parent.HookScript then
        parent:HookScript("OnHide", CloseMenu)
    end

    function control:Refresh()
        local value = getter()

        self.button.text:SetText(GetSelectedText(value))

        for index, option in ipairs(options) do
            local row = self.rows[index]

            if row then
                row.check:SetShown(option.value == value)
            end
        end
    end

    control:SetOptions(options)

    UI.RegisterSearchControl(parent, control, label, tooltip)

    return control
end

function UI.CreateMultiSelectDropdown(parent, label, tooltip, options, width)
    local control = CreateFrame("Frame", nil, parent)
    local dropdownWidth = width or 320
    local rowHeight = 26

    control:SetSize(dropdownWidth, 48)

    control.label = control:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    control.label:SetPoint("TOPLEFT", 0, 0)
    control.label:SetTextColor(0.95, 0.72, 0.28)
    control.label:SetText(label)

    control.button = CreateFrame("Button", nil, control, "BackdropTemplate")
    control.button:SetPoint("TOPLEFT", control.label, "BOTTOMLEFT", 0, -4)
    control.button:SetSize(dropdownWidth, 27)
    control.button:RegisterForClicks("LeftButtonUp")
    control.button:SetBackdrop({
        bgFile = Theme and Theme.panelBg or "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 7,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    control.button:SetBackdropColor(0.012, 0.014, 0.018, 0.95)
    control.button:SetBackdropBorderColor(0.25, 0.28, 0.33, 0.82)

    control.button.text = control.button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    control.button.text:SetPoint("LEFT", control.button, "LEFT", 10, 0)
    control.button.text:SetPoint("RIGHT", control.button, "RIGHT", -30, 0)
    control.button.text:SetJustifyH("LEFT")
    control.button.text:SetTextColor(0.94, 0.92, 0.86)

    if control.button.text.SetWordWrap then
        control.button.text:SetWordWrap(false)
    end

    control.button.arrow = control.button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    control.button.arrow:SetPoint("RIGHT", control.button, "RIGHT", -10, 0)
    control.button.arrow:SetText("v")

    -- Keep the popup outside the clipped scrolling viewport so every option
    -- remains visible even when this control sits near the page boundary.
    local menuParent = UI.frame or UIParent or parent
    control.menu = CreateFrame("Frame", nil, menuParent, "BackdropTemplate")
    control.menu:SetSize(dropdownWidth, (#options * rowHeight) + 12)
    control.menu:SetFrameStrata("TOOLTIP")
    control.menu:SetFrameLevel(math.max(100, ((menuParent.GetFrameLevel and menuParent:GetFrameLevel()) or 0) + 50))
    control.menu:SetToplevel(true)
    control.menu:SetClampedToScreen(true)
    control.menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    control.menu:SetBackdropColor(0.012, 0.014, 0.018, 1)
    control.menu:SetBackdropBorderColor(0.75, 0.60, 0.30, 0.58)
    control.menu:Hide()

    local function PositionMenu()
        control.menu:ClearAllPoints()

        local buttonBottom = control.button:GetBottom()
        local menuHeight = control.menu:GetHeight() or 0

        if buttonBottom and buttonBottom < (menuHeight + 12) then
            control.menu:SetPoint("BOTTOMLEFT", control.button, "TOPLEFT", 0, 2)
        else
            control.menu:SetPoint("TOPLEFT", control.button, "BOTTOMLEFT", 0, -2)
        end
    end

    if tooltip then
        control.button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)

        control.button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    local function GetSummaryText()
        local selected = {}

        for _, option in ipairs(options) do
            if option.getter and option.getter() == true then
                selected[#selected + 1] = option.shortText or option.text
            end
        end

        if #selected == 0 then
            return "None"
        elseif #selected == #options then
            return "All selected"
        elseif #selected <= 2 then
            return table.concat(selected, ", ")
        end

        return tostring(#selected) .. " selected"
    end

    local function HideIfMouseAway()
        if not control.button:IsMouseOver() and not control.menu:IsMouseOver() then
            control.menu:Hide()
            control.button.arrow:SetText("v")
        end
    end

    local function ScheduleMouseAwayHide()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.8, HideIfMouseAway)
        end
    end

    control.rows = {}

    for index, option in ipairs(options) do
        local row = CreateFrame("Button", nil, control.menu, "BackdropTemplate")
        row:SetPoint("TOPLEFT", control.menu, "TOPLEFT", 8, -6 - ((index - 1) * rowHeight))
        row:SetSize(dropdownWidth - 16, rowHeight)
        row:RegisterForClicks("LeftButtonUp")
        row.tooltip = option.tooltip

        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetPoint("TOPLEFT", 2, -1)
        row.highlight:SetPoint("BOTTOMRIGHT", -2, 1)
        row.highlight:SetColorTexture(1, 0.82, 0.18, 0.08)
        row.highlight:Hide()

        row.box = CreateFrame("Frame", nil, row, "BackdropTemplate")
        row.box:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.box:SetSize(14, 14)
        row.box:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        row.box:SetBackdropColor(0.015, 0.014, 0.012, 0.95)
        row.box:SetBackdropBorderColor(0.75, 0.62, 0.25, 0.65)

        row.check = row.box:CreateTexture(nil, "OVERLAY")
        row.check:SetPoint("CENTER", row.box, "CENTER", 0, 0)
        row.check:SetSize(18, 18)
        row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        row.check:SetVertexColor(1, 0.86, 0.12, 1)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.box, "RIGHT", 8, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetText(option.text)

        row:SetScript("OnClick", function(self)
            local nextValue = not (option.getter and option.getter() == true)

            if option.setter then
                option.setter(nextValue)
            end

            if control.Refresh then
                control:Refresh()
            end
        end)

        row:SetScript("OnEnter", function(self)
            self.highlight:Show()
            self.text:SetTextColor(1, 0.86, 0.18)

            if not self.tooltip then
                return
            end

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(option.text)
            GameTooltip:AddLine(self.tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)

        row:SetScript("OnLeave", function(self)
            self.highlight:Hide()
            self.text:SetTextColor(1, 1, 1)
            GameTooltip:Hide()

            ScheduleMouseAwayHide()
        end)

        control.rows[index] = row
    end

    control.button:SetScript("OnClick", function()
        if control.menu:IsShown() then
            control.menu:Hide()
            control.button.arrow:SetText("v")
        else
            control:Refresh()
            PositionMenu()
            control.menu:Show()
            control.button.arrow:SetText("^")
        end
    end)

    control.button:HookScript("OnLeave", function()
        ScheduleMouseAwayHide()
    end)

    control.menu:SetScript("OnLeave", function()
        ScheduleMouseAwayHide()
    end)

    local function CloseMenu()
        control.menu:Hide()
        control.button.arrow:SetText("v")
    end

    control:HookScript("OnHide", CloseMenu)
    if parent and parent.HookScript then
        parent:HookScript("OnHide", CloseMenu)
    end

    function control:Refresh()
        self.button.text:SetText(GetSummaryText())

        for index, option in ipairs(options) do
            local row = self.rows[index]

            if row then
                row.check:SetShown(option.getter and option.getter() == true)
            end
        end
    end

    control:Refresh()

    UI.RegisterSearchControl(parent, control, label, tooltip)

    return control
end

function UI.CreateColorPicker(parent, label, tooltip, getter, setter, width)
    local control = CreateFrame("Frame", nil, parent)
    control:SetSize(width or 220, 28)

    control.swatch = CreateFrame("Button", nil, control, "BackdropTemplate")
    control.swatch:SetPoint("LEFT", 0, 0)
    control.swatch:SetSize(24, 24)
    control.swatch:RegisterForClicks("LeftButtonUp")
    control.swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    control.swatch:SetBackdropColor(0, 0, 0, 1)
    control.swatch:SetBackdropBorderColor(0.65, 0.52, 0.25, 0.62)

    control.color = control.swatch:CreateTexture(nil, "ARTWORK")
    control.color:SetPoint("TOPLEFT", 4, -4)
    control.color:SetPoint("BOTTOMRIGHT", -4, 4)
    control.color:SetColorTexture(1, 1, 1, 1)

    control.label = control:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    control.label:SetPoint("LEFT", control.swatch, "RIGHT", 10, 0)
    control.label:SetTextColor(0.95, 0.72, 0.28)
    control.label:SetText(label)

    local function RefreshTooltip(owner)
        if not tooltip then
            return
        end

        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(label)
        GameTooltip:AddLine(tooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end

    local function ApplyPickerColor()
        local r, g, b = ColorPickerFrame:GetColorRGB()

        setter(r, g, b, false, control.previousValues and control.previousValues.extra)

        if control.Refresh then
            control:Refresh()
        end
    end

    local function CancelPicker(previousValues)
        previousValues = previousValues or control.previousValues or {}

        local r = previousValues.r or previousValues[1] or 1
        local g = previousValues.g or previousValues[2] or 1
        local b = previousValues.b or previousValues[3] or 1

        setter(r, g, b, true, previousValues.extra)

        if control.Refresh then
            control:Refresh()
        end
    end

    local function OpenPicker()
        if not ColorPickerFrame then
            return
        end

        local r, g, b, extra = getter()
        r = r or 1
        g = g or 1
        b = b or 1

        control.previousValues = { r = r, g = g, b = b, extra = extra }

        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r,
                g = g,
                b = b,
                previousValues = control.previousValues,
                hasOpacity = false,
                swatchFunc = ApplyPickerColor,
                cancelFunc = CancelPicker,
            })
        else
            ColorPickerFrame:Hide()
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame.previousValues = control.previousValues
            ColorPickerFrame.func = ApplyPickerColor
            ColorPickerFrame.cancelFunc = CancelPicker
            ColorPickerFrame:Show()
        end
    end

    control.swatch:SetScript("OnClick", OpenPicker)

    control.swatch:SetScript("OnEnter", function(self)
        RefreshTooltip(self)
    end)

    control.swatch:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    control:SetScript("OnEnter", function(self)
        RefreshTooltip(self)
    end)

    control:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    function control:Refresh()
        local r, g, b = getter()

        self.color:SetColorTexture(r or 1, g or 1, b or 1, 1)
    end

    control:Refresh()

    UI.RegisterSearchControl(parent, control, label, tooltip)

    return control
end

function UI.CreateSlider(parent, label, tooltip, minValue, maxValue, step, getter, setter, width, valueFormatter)
    controlCounter = controlCounter + 1

    local name = "ZoidsToolsSlider" .. controlCounter
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetSize(width or 220, 18)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step or 1)

    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    slider.tooltip = tooltip
    slider.ZTLabel = label
    slider.ZTGetter = getter
    slider.ZTSetter = setter
    slider.ZTFormatter = valueFormatter

    local text = _G[name .. "Text"]
    local low = _G[name .. "Low"]
    local high = _G[name .. "High"]

    if low then
        low:Hide()
    end

    if high then
        high:Hide()
    end

    local function FormatValue(value)
        if valueFormatter then
            return valueFormatter(value)
        end

        return tostring(value)
    end

    function slider:Refresh()
        local value = getter()

        self.ZTRefreshing = true
        self:SetValue(value)
        self.ZTRefreshing = nil

        if text then
            text:SetText(label .. ": " .. FormatValue(value))
        end
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if self.ZTRefreshing then
            return
        end

        local stepped = math.floor((value / (step or 1)) + 0.5) * (step or 1)

        setter(stepped)

        if text then
            text:SetText(label .. ": " .. FormatValue(stepped))
        end
    end)

    if tooltip then
        slider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)

        slider:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    slider:Refresh()

    UI.RegisterSearchControl(parent, slider, label, tooltip)

    return slider
end
