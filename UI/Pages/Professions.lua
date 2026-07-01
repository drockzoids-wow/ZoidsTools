local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateProfessionsPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local mainSection = UI.PlaceSection(frame, "Profession Action")

    local enabled = UI.CreateCheckbox(
        frame,
        "Enable profession helper",
        "Shows a Molinari-style action glow on profession items that can be disenchanted, milled, prospected, or opened.",
        function()
            return ns.GetProfessionHelperEnabled and ns:GetProfessionHelperEnabled()
        end,
        function(value)
            if ns.SetProfessionHelperEnabled then
                ns:SetProfessionHelperEnabled(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    )
    UI.PlaceFirst(enabled, mainSection)

    local activation = UI.CreateDropdown(
        frame,
        "Modifier",
        "Choose which modifier you hold while clicking the item.",
        ns.GetProfessionHelperActivationOptions and ns:GetProfessionHelperActivationOptions() or {
            { value = "alt", text = "Alt" },
            { value = "altctrl", text = "Alt + Ctrl" },
            { value = "altshift", text = "Alt + Shift" },
        },
        function()
            return ns.GetProfessionHelperActivation and ns:GetProfessionHelperActivation() or "alt"
        end,
        function(value)
            if ns.SetProfessionHelperActivation then
                ns:SetProfessionHelperActivation(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end,
        280
    )
    UI.PlaceDropdown(activation, enabled)

    local actionSection = UI.PlaceSection(frame, "Actions", activation)

    local disenchant = UI.CreateCheckbox(
        frame,
        "Disenchant gear",
        "Prepares Disenchant for eligible uncommon, rare, and epic equipment.",
        function()
            return ns.GetProfessionHelperActionEnabled and ns:GetProfessionHelperActionEnabled("disenchant")
        end,
        function(value)
            if ns.SetProfessionHelperActionEnabled then
                ns:SetProfessionHelperActionEnabled("disenchant", value)
            end
        end
    )
    UI.PlaceFirst(disenchant, actionSection)

    local mill = UI.CreateCheckbox(
        frame,
        "Mill herbs",
        "Prepares the matching Milling recipe for supported herb stacks.",
        function()
            return ns.GetProfessionHelperActionEnabled and ns:GetProfessionHelperActionEnabled("mill")
        end,
        function(value)
            if ns.SetProfessionHelperActionEnabled then
                ns:SetProfessionHelperActionEnabled("mill", value)
            end
        end
    )
    UI.PlaceBelow(mill, disenchant)

    local prospect = UI.CreateCheckbox(
        frame,
        "Prospect ore",
        "Prepares the matching Prospecting recipe for supported ore stacks.",
        function()
            return ns.GetProfessionHelperActionEnabled and ns:GetProfessionHelperActionEnabled("prospect")
        end,
        function(value)
            if ns.SetProfessionHelperActionEnabled then
                ns:SetProfessionHelperActionEnabled("prospect", value)
            end
        end
    )
    UI.PlaceBelow(prospect, mill)

    local open = UI.CreateCheckbox(
        frame,
        "Open lockboxes",
        "Prepares Pick Lock, compatible racial unlocks, or usable skeleton keys for supported lockboxes.",
        function()
            return ns.GetProfessionHelperActionEnabled and ns:GetProfessionHelperActionEnabled("open")
        end,
        function(value)
            if ns.SetProfessionHelperActionEnabled then
                ns:SetProfessionHelperActionEnabled("open", value)
            end
        end
    )
    UI.PlaceBelow(open, prospect)

    local statusSection = UI.PlaceSection(frame, "Status", open)

    local status = UI.CreateStatusText(frame, 680)
    UI.PlaceFirst(status, statusSection)

    function frame:Refresh()
        enabled:Refresh()
        activation:Refresh()
        disenchant:Refresh()
        mill:Refresh()
        prospect:Refresh()
        open:Refresh()

        if ns.GetProfessionHelperStatusText then
            status:SetText(ns:GetProfessionHelperStatusText())
        else
            status:SetText("")
        end
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
