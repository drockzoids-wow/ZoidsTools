local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateMetersPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local generalSection = UI.CreateSection(frame, "General", nil, 0)

    local enabled = UI.CreateCheckbox(
        frame,
        "Enable ZoidsTools damage meters",
        "Shows lightweight ZoidsTools windows using live combat-log data.",
        function()
            return ns.GetDamageMetersEnabled and ns:GetDamageMetersEnabled()
        end,
        function(value)
            if ns.SetDamageMetersEnabled then
                ns:SetDamageMetersEnabled(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    )
    enabled:SetPoint("TOPLEFT", generalSection, "BOTTOMLEFT", 18, -6)

    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -18)
    status:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    status:SetJustifyH("LEFT")

    local note = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -14)
    note:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Meter window headers contain display, reset, style, and sizing controls.")

    function frame:Refresh()
        enabled:Refresh()

        if ns.GetDamageMetersStatusText then
            status:SetText(ns:GetDamageMetersStatusText())
        else
            status:SetText("")
        end
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
