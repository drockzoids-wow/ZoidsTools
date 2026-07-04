local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateBuildsPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local mainSection = UI.PlaceSection(frame, "Talents")

    local enabled = UI.CreateCheckbox(
        frame,
        "Show talent frame controls",
        "Shows the ZoidsTools talent controls on the Blizzard talents pane.",
        function()
            return ns.GetTalentGrimoireEnabled and ns:GetTalentGrimoireEnabled()
        end,
        function(value)
            if ns.SetTalentGrimoireEnabled then
                ns:SetTalentGrimoireEnabled(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    )
    UI.PlaceFirst(enabled, mainSection)

    local status = UI.CreateStatusText(frame, 680)
    UI.PlaceBelow(status, enabled, 0, 14)

    local selectionSection = UI.PlaceSection(frame, "Selection", status)

    local contentButton = UI.CreateButton(frame, "Content", 190)
    UI.PlaceFirst(contentButton, selectionSection)
    contentButton:SetScript("OnClick", function()
        if ns.CycleTalentGrimoireContent then
            ns:CycleTalentGrimoireContent()
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    local targetButton = UI.CreateButton(frame, "Target", 300)
    targetButton:SetPoint("LEFT", contentButton, "RIGHT", UI.Layout.buttonGap, 0)
    targetButton:SetScript("OnClick", function()
        if ns.CycleTalentGrimoireTarget then
            ns:CycleTalentGrimoireTarget()
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    local modeButton = UI.CreateButton(frame, "Mode", 190)
    UI.PlaceBelow(modeButton, contentButton, 0, 12)
    modeButton:SetScript("OnClick", function()
        if ns.CycleTalentGrimoireMode then
            ns:CycleTalentGrimoireMode()
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    local refreshButton = UI.CreateButton(frame, "Refresh Panel", 190)
    refreshButton:SetPoint("LEFT", modeButton, "RIGHT", UI.Layout.buttonGap, 0)
    refreshButton:SetScript("OnClick", function()
        if ns.RefreshTalentGrimoire then
            ns:RefreshTalentGrimoire()
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    function frame:Refresh()
        enabled:Refresh()

        if ns.GetTalentGrimoireStatusText then
            status:SetText(ns:GetTalentGrimoireStatusText())
        else
            status:SetText("")
        end

        if ns.GetTalentGrimoireContentType then
            local contentType = ns:GetTalentGrimoireContentType()
            local label = "Mythic+"

            if contentType == "raid" then
                label = "Raid"
            elseif contentType == "pvp" then
                label = "PvP"
            end

            contentButton:SetText("Content: " .. label)
        end

        if ns.GetTalentGrimoireTargetLabel then
            targetButton:SetText("Target: " .. tostring(ns:GetTalentGrimoireTargetLabel()))
        end

        if ns.GetTalentGrimoireModeLabel then
            modeButton:SetText("Mode: " .. tostring(ns:GetTalentGrimoireModeLabel()))
        end
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
