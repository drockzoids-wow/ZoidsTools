local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

local frameColumns = {
    { key = "player", label = "Player" },
    { key = "target", label = "Target" },
    { key = "focus", label = "Focus" },
}

function ns.UI.Pages.CreateUnitFramesPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)
    local controls = {}

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
    local columnWidth = 150
    local columnGap = 34

    for index, info in ipairs(frameColumns) do
        local x = UI.Layout.indent + ((index - 1) * (columnWidth + columnGap))

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
            138,
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
            138,
            function(value)
                return tostring(math.floor((value or 16) + 0.5))
            end
        )
        UI.PlaceBelow(castbarHeight, castbarWidth, 0, 26)
        controls[#controls + 1] = castbarHeight

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
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
