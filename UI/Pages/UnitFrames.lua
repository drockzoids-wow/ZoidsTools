local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

local frameColumns = {
    { key = "player", label = "Player" },
    { key = "target", label = "Target" },
    { key = "focus", label = "Focus" },
}

local function CreateColumnDivider(parent, anchor, xOffset, yOffset, height)
    local glow = parent:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset - 2, yOffset)
    glow:SetSize(5, height)
    glow:SetColorTexture(0.95, 0.72, 0.28, 0.035)

    local line = parent:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset, yOffset)
    line:SetSize(1, height)
    line:SetColorTexture(0.95, 0.72, 0.28, 0.16)

    return line
end

function ns.UI.Pages.CreateUnitFramesPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)
    local controls = {}
    local castbarDependencies = {}

    local healthSection = UI.PlaceSection(frame, "Health Bars")

    local classColorHealth = UI.CreateCheckbox(
        frame,
        "Class color health",
        "Colors only the health fill on player, target, target of target, and focus frames.",
        function()
            return ns.GetUnitFrameClassColorHealth and ns:GetUnitFrameClassColorHealth()
        end,
        function(value)
            if ns.SetUnitFrameClassColorHealth then
                ns:SetUnitFrameClassColorHealth(value)
            end
        end
    )
    UI.PlaceFirst(classColorHealth, healthSection)
    controls[#controls + 1] = classColorHealth

    local frameSection = UI.PlaceSection(frame, "Frame Controls", classColorHealth)
    local columnWidth = 188
    local columnGap = 42
    local dividerHeight = 238

    for index, info in ipairs(frameColumns) do
        local x = UI.Layout.indent + ((index - 1) * (columnWidth + columnGap))

        if index > 1 then
            CreateColumnDivider(frame, frameSection, x - math.floor(columnGap / 2), -UI.Layout.firstRowGap + 4, dividerHeight)
        end

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOPLEFT", frameSection, "BOTTOMLEFT", x, -UI.Layout.firstRowGap)
        title:SetText(info.label)
        title:SetTextColor(1, 0.82, 0)
        title:SetJustifyH("LEFT")

        local resizeCastbar = UI.CreateCheckbox(
            frame,
            "Resize castbar",
            "Uses custom width and height for this frame's Blizzard castbar.",
            function()
                return ns.GetUnitFrameCastbarResizeEnabled and ns:GetUnitFrameCastbarResizeEnabled(info.key)
            end,
            function(value)
                if ns.SetUnitFrameCastbarResizeEnabled then
                    ns:SetUnitFrameCastbarResizeEnabled(info.key, value)
                end

                if frame.Refresh then
                    frame:Refresh()
                end
            end
        )
        UI.PlaceBelow(resizeCastbar, title)
        controls[#controls + 1] = resizeCastbar

        local castbarWidth = UI.CreateSlider(
            frame,
            "Width",
            "Changes this castbar's width.",
            120,
            420,
            5,
            function()
                return ns.GetUnitFrameCastbarWidth and ns:GetUnitFrameCastbarWidth(info.key) or 195
            end,
            function(value)
                if ns.SetUnitFrameCastbarWidth then
                    ns:SetUnitFrameCastbarWidth(info.key, value)
                end
            end,
            176,
            function(value)
                return tostring(math.floor((value or 195) + 0.5))
            end
        )
        UI.PlaceSlider(castbarWidth, resizeCastbar, 14)
        controls[#controls + 1] = castbarWidth

        local castbarHeight = UI.CreateSlider(
            frame,
            "Height",
            "Changes this castbar's height while keeping the spell name anchored to the lower text area.",
            8,
            40,
            1,
            function()
                return ns.GetUnitFrameCastbarHeight and ns:GetUnitFrameCastbarHeight(info.key) or 16
            end,
            function(value)
                if ns.SetUnitFrameCastbarHeight then
                    ns:SetUnitFrameCastbarHeight(info.key, value)
                end
            end,
            176,
            function(value)
                return tostring(math.floor((value or 16) + 0.5))
            end
        )
        UI.PlaceBelow(castbarHeight, castbarWidth, 0, 26)
        controls[#controls + 1] = castbarHeight
        castbarDependencies[#castbarDependencies + 1] = {
            enabled = resizeCastbar,
            width = castbarWidth,
            height = castbarHeight,
        }

        if info.key ~= "player" then
            local hideBuffs = UI.CreateCheckbox(
                frame,
                "Hide buffs",
                "Hides helpful aura icons for this frame.",
                function()
                    return ns.GetUnitFrameAuraHidden and ns:GetUnitFrameAuraHidden(info.key, "buffs")
                end,
                function(value)
                    if ns.SetUnitFrameAuraHidden then
                        ns:SetUnitFrameAuraHidden(info.key, "buffs", value)
                    end
                end
            )
            hideBuffs:SetPoint("TOPLEFT", castbarHeight, "BOTTOMLEFT", -14, -24)
            controls[#controls + 1] = hideBuffs

            local hideDebuffs = UI.CreateCheckbox(
                frame,
                "Hide debuffs",
                "Hides harmful aura icons for this frame.",
                function()
                    return ns.GetUnitFrameAuraHidden and ns:GetUnitFrameAuraHidden(info.key, "debuffs")
                end,
                function(value)
                    if ns.SetUnitFrameAuraHidden then
                        ns:SetUnitFrameAuraHidden(info.key, "debuffs", value)
                    end
                end
            )
            UI.PlaceBelow(hideDebuffs, hideBuffs)
            controls[#controls + 1] = hideDebuffs
        end
    end

    local refreshButton = UI.CreateButton(frame, "Refresh Unit Frames", 160)
    refreshButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", UI.Layout.indent, 0)
    refreshButton:SetScript("OnClick", function()
        if ns.RefreshUnitFrames then
            ns:RefreshUnitFrames()
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    function frame:Refresh()
        for _, control in ipairs(controls) do
            if control.Refresh then
                control:Refresh()
            end
        end

        for _, dependency in ipairs(castbarDependencies) do
            local active = dependency.enabled:GetChecked() == true
            UI.SetControlEnabled(dependency.width, active)
            UI.SetControlEnabled(dependency.height, active)
        end
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
