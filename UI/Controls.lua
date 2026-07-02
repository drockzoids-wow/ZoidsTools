local _, ns = ...

ns.UI = ns.UI or {}

local UI = ns.UI
local Theme = UI.Theme
local controlCounter = 0

UI.Layout = UI.Layout or {
    indent = 20,
    rowGap = 12,
    firstRowGap = 13,
    controlGap = 18,
    sectionGap = 38,
    sliderIndent = 16,
    sliderGap = 24,
    buttonGap = 14,
    columnGap = 44,
}

function UI.CreateCheckbox(parent, label, tooltip, getter, setter)
    local checkbox = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    checkbox.Text:SetText(label)
    checkbox.tooltip = tooltip

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
    end)

    function checkbox:Refresh()
        self:SetChecked(getter() == true)
    end

    checkbox:Refresh()

    return checkbox
end

local function SetStyledButtonState(button)
    local selected = button.ZTSelected == true
    local hovered = button.ZTHovered == true
    local pushed = button.ZTPushed == true

    if pushed then
        button.bg:SetColorTexture(0.18, 0.13, 0.06, 0.96)
        button.highlight:SetAlpha(0.18)
    elseif selected then
        button.bg:SetColorTexture(0.15, 0.105, 0.035, 0.96)
        button.highlight:SetAlpha(0.28)
    elseif hovered then
        button.bg:SetColorTexture(0.10, 0.075, 0.035, 0.95)
        button.highlight:SetAlpha(0.18)
    else
        button.bg:SetColorTexture(0.025, 0.020, 0.015, 0.94)
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
        button:SetBackdropBorderColor(0.95, 0.72, 0.28, 0.54)
        button.topLine:SetVertexColor(0.95, 0.72, 0.28, 0.38)
        button.bottomLine:SetVertexColor(0.95, 0.72, 0.28, 0.26)
        button.text:SetTextColor(1, 0.86, 0.18)
    else
        button:SetBackdropBorderColor(0.55, 0.45, 0.26, 0.34)
        button.topLine:SetVertexColor(0.72, 0.58, 0.30, 0.20)
        button.bottomLine:SetVertexColor(0.72, 0.58, 0.30, 0.14)
        button.text:SetTextColor(0.92, 0.84, 0.68)
    end
end

function UI.CreateButton(parent, text, width, height)
    local buttonHeight = height or 32
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 132, buttonHeight)
    button:RegisterForClicks("AnyUp")
    button:SetBackdrop({
        bgFile = Theme and Theme.panelBg or "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetPoint("TOPLEFT", 4, -4)
    button.bg:SetPoint("BOTTOMRIGHT", -4, 4)

    button.highlight = button:CreateTexture(nil, "BORDER")
    button.highlight:SetPoint("TOPLEFT", 5, -5)
    button.highlight:SetPoint("BOTTOMRIGHT", -5, 5)
    button.highlight:SetColorTexture(1, 0.82, 0.25, 1)

    button.topLine = button:CreateTexture(nil, "ARTWORK")
    button.topLine:SetPoint("TOPLEFT", 12, -5)
    button.topLine:SetPoint("TOPRIGHT", -12, -5)
    button.topLine:SetHeight(1)
    button.topLine:SetColorTexture(1, 1, 1, 1)

    button.bottomLine = button:CreateTexture(nil, "ARTWORK")
    button.bottomLine:SetPoint("BOTTOMLEFT", 12, 5)
    button.bottomLine:SetPoint("BOTTOMRIGHT", -12, 5)
    button.bottomLine:SetHeight(1)
    button.bottomLine:SetColorTexture(1, 1, 1, 1)

    button.leftCap = button:CreateTexture(nil, "ARTWORK")
    button.leftCap:SetPoint("LEFT", 6, 0)
    button.leftCap:SetSize(2, math.max(buttonHeight - 12, 8))
    button.leftCap:SetColorTexture(1, 0.82, 0.25, 0.26)

    button.rightCap = button:CreateTexture(nil, "ARTWORK")
    button.rightCap:SetPoint("RIGHT", -6, 0)
    button.rightCap:SetSize(2, math.max(buttonHeight - 12, 8))
    button.rightCap:SetColorTexture(1, 0.82, 0.25, 0.26)

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
    section:SetHeight(26)

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
    section.label:SetTextColor(0.95, 0.72, 0.28)
    section.label:SetText(text)

    section.divider = section:CreateTexture(nil, "ARTWORK")
    section.divider:SetColorTexture(0.95, 0.72, 0.28, 0.18)
    section.divider:SetPoint("LEFT", section.label, "RIGHT", 12, 0)
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

    control:SetSize(dropdownWidth, 54)

    control.label = control:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    control.label:SetPoint("TOPLEFT", 0, 0)
    control.label:SetTextColor(0.95, 0.72, 0.28)
    control.label:SetText(label)

    control.button = CreateFrame("Button", nil, control, "BackdropTemplate")
    control.button:SetPoint("TOPLEFT", control.label, "BOTTOMLEFT", 0, -6)
    control.button:SetSize(dropdownWidth, 30)
    control.button:RegisterForClicks("LeftButtonUp")
    control.button:SetBackdrop({
        bgFile = Theme and Theme.panelBg or "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    control.button:SetBackdropColor(0.012, 0.014, 0.018, 0.95)
    control.button:SetBackdropBorderColor(0.55, 0.45, 0.26, 0.38)

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

    control.menu = CreateFrame("Frame", nil, control, "BackdropTemplate")
    control.menu:SetPoint("TOPLEFT", control.button, "BOTTOMLEFT", 0, -2)
    control.menu:SetSize(dropdownWidth, (#options * rowHeight) + 12)
    control.menu:SetFrameStrata("DIALOG")
    control.menu:SetToplevel(true)
    control.menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    control.menu:SetBackdropColor(0.012, 0.014, 0.018, 0.98)
    control.menu:SetBackdropBorderColor(0.75, 0.60, 0.30, 0.58)
    control.menu:Hide()

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

    control.rows = {}

    for index, option in ipairs(options) do
        local row = CreateFrame("Button", nil, control.menu, "BackdropTemplate")
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
        row.text:SetText(option.text)

        row:SetScript("OnClick", function()
            setter(option.value)

            if control.Refresh then
                control:Refresh()
            end

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

            if C_Timer and C_Timer.After then
                C_Timer.After(0.12, HideIfMouseAway)
            end
        end)

        control.rows[index] = row
    end

    control.button:SetScript("OnClick", function()
        if control.menu:IsShown() then
            control.menu:Hide()
            control.button.arrow:SetText("v")
        else
            control:Refresh()
            control.menu:Show()
            control.button.arrow:SetText("^")
        end
    end)

    control.button:HookScript("OnLeave", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.12, HideIfMouseAway)
        end
    end)

    control.menu:SetScript("OnLeave", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.12, HideIfMouseAway)
        end
    end)

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

    control:Refresh()

    return control
end

function UI.CreateMultiSelectDropdown(parent, label, tooltip, options, width)
    local control = CreateFrame("Frame", nil, parent)
    local dropdownWidth = width or 320
    local rowHeight = 26

    control:SetSize(dropdownWidth, 54)

    control.label = control:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    control.label:SetPoint("TOPLEFT", 0, 0)
    control.label:SetTextColor(0.95, 0.72, 0.28)
    control.label:SetText(label)

    control.button = CreateFrame("Button", nil, control, "BackdropTemplate")
    control.button:SetPoint("TOPLEFT", control.label, "BOTTOMLEFT", 0, -6)
    control.button:SetSize(dropdownWidth, 30)
    control.button:RegisterForClicks("LeftButtonUp")
    control.button:SetBackdrop({
        bgFile = Theme and Theme.panelBg or "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    control.button:SetBackdropColor(0.012, 0.014, 0.018, 0.95)
    control.button:SetBackdropBorderColor(0.55, 0.45, 0.26, 0.38)

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

    control.menu = CreateFrame("Frame", nil, control, "BackdropTemplate")
    control.menu:SetPoint("TOPLEFT", control.button, "BOTTOMLEFT", 0, -2)
    control.menu:SetSize(dropdownWidth, (#options * rowHeight) + 12)
    control.menu:SetFrameStrata("DIALOG")
    control.menu:SetToplevel(true)
    control.menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    control.menu:SetBackdropColor(0.012, 0.014, 0.018, 0.98)
    control.menu:SetBackdropBorderColor(0.75, 0.60, 0.30, 0.58)
    control.menu:Hide()

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

            if C_Timer and C_Timer.After then
                C_Timer.After(0.12, HideIfMouseAway)
            end
        end)

        control.rows[index] = row
    end

    control.button:SetScript("OnClick", function()
        if control.menu:IsShown() then
            control.menu:Hide()
            control.button.arrow:SetText("v")
        else
            control:Refresh()
            control.menu:Show()
            control.button.arrow:SetText("^")
        end
    end)

    control.button:HookScript("OnLeave", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.12, HideIfMouseAway)
        end
    end)

    control.menu:SetScript("OnLeave", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.12, HideIfMouseAway)
        end
    end)

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
        low:SetText(valueFormatter and valueFormatter(minValue) or tostring(minValue))
    end

    if high then
        high:SetText(valueFormatter and valueFormatter(maxValue) or tostring(maxValue))
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

    return slider
end
