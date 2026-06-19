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

    local healthSection = UI.CreateSection(frame, "Health Bars", nil, 0)

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
    classColorHealth:SetPoint("TOPLEFT", healthSection, "BOTTOMLEFT", 18, -6)
    controls[#controls + 1] = classColorHealth

    local frameSection = UI.CreateSection(frame, "Frame Controls", classColorHealth, -30)
    local columnWidth = 176
    local columnGap = 18

    for index, info in ipairs(frameColumns) do
        local x = 18 + ((index - 1) * (columnWidth + columnGap))

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOPLEFT", frameSection, "BOTTOMLEFT", x, -8)
        title:SetText(info.label)
        title:SetTextColor(1, 0.82, 0)
        title:SetJustifyH("LEFT")

        local controlAnchor = title
        local controlOffset = -8

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
            hideBuffs:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
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
            hideDebuffs:SetPoint("TOPLEFT", hideBuffs, "BOTTOMLEFT", 0, -8)
            controls[#controls + 1] = hideDebuffs

            controlAnchor = hideDebuffs
            controlOffset = -12
        end

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
        resizeCastbar:SetPoint("TOPLEFT", controlAnchor, "BOTTOMLEFT", 0, controlOffset)
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
        castbarWidth:SetPoint("TOPLEFT", resizeCastbar, "BOTTOMLEFT", 14, -18)
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
        castbarHeight:SetPoint("TOPLEFT", castbarWidth, "BOTTOMLEFT", 0, -26)
        controls[#controls + 1] = castbarHeight
    end

    local refreshButton = UI.CreateButton(frame, "Refresh Unit Frames", 160)
    refreshButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 0)
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
