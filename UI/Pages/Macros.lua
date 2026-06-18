local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateMacrosPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)
    local checkboxX = 18

    local healthSection = UI.CreateSection(frame, "Health Macro", nil, 0)

    local healthEnabled = UI.CreateCheckbox(
        frame,
        "Create ZT Health macro",
        "Creates and updates a character macro named ZT Health outside combat.",
        function()
            return ns.GetConsumableMacroOption and ns:GetConsumableMacroOption("healthEnabled")
        end,
        function(value)
            if ns.SetConsumableMacroOption then
                ns:SetConsumableMacroOption("healthEnabled", value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    )
    healthEnabled:SetPoint("TOPLEFT", healthSection, "BOTTOMLEFT", checkboxX, -6)

    local healthRecuperate = UI.CreateCheckbox(
        frame,
        "Use Recuperate out of combat",
        "Uses Recuperate instead of bag food when the health macro is pressed out of combat.",
        function()
            return ns.GetConsumableMacroOption and ns:GetConsumableMacroOption("healthUseRecuperate")
        end,
        function(value)
            if ns.SetConsumableMacroOption then
                ns:SetConsumableMacroOption("healthUseRecuperate", value)
            end
        end
    )
    healthRecuperate:SetPoint("TOPLEFT", healthEnabled, "BOTTOMLEFT", 0, -8)

    local healthCombat = UI.CreateCheckbox(
        frame,
        "Use Healthstone then potion in combat",
        "Adds combat lines for Healthstone first, then your best healing potion.",
        function()
            return ns.GetConsumableMacroOption and ns:GetConsumableMacroOption("healthCombatItems")
        end,
        function(value)
            if ns.SetConsumableMacroOption then
                ns:SetConsumableMacroOption("healthCombatItems", value)
            end
        end
    )
    healthCombat:SetPoint("TOPLEFT", healthRecuperate, "BOTTOMLEFT", 0, -8)

    local manaSection = UI.CreateSection(frame, "Mana Macro", healthCombat, -28)
    manaSection:ClearAllPoints()
    manaSection:SetPoint("TOPLEFT", healthCombat, "BOTTOMLEFT", -checkboxX, -28)
    manaSection:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

    local manaEnabled = UI.CreateCheckbox(
        frame,
        "Create ZT Mana macro",
        "Creates and updates a character macro named ZT Mana outside combat.",
        function()
            return ns.GetConsumableMacroOption and ns:GetConsumableMacroOption("manaEnabled")
        end,
        function(value)
            if ns.SetConsumableMacroOption then
                ns:SetConsumableMacroOption("manaEnabled", value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    )
    manaEnabled:SetPoint("TOPLEFT", manaSection, "BOTTOMLEFT", checkboxX, -6)

    local manaCombat = UI.CreateCheckbox(
        frame,
        "Use mana potion in combat",
        "Adds a combat line for your best mana potion.",
        function()
            return ns.GetConsumableMacroOption and ns:GetConsumableMacroOption("manaCombatPotion")
        end,
        function(value)
            if ns.SetConsumableMacroOption then
                ns:SetConsumableMacroOption("manaCombatPotion", value)
            end
        end
    )
    manaCombat:SetPoint("TOPLEFT", manaEnabled, "BOTTOMLEFT", 0, -8)

    local actionsSection = UI.CreateSection(frame, "Actions", manaCombat, -28)
    actionsSection:ClearAllPoints()
    actionsSection:SetPoint("TOPLEFT", manaCombat, "BOTTOMLEFT", -checkboxX, -28)
    actionsSection:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

    local refreshButton = UI.CreateButton(frame, "Refresh Macros", 140)
    refreshButton:SetPoint("TOPLEFT", actionsSection, "BOTTOMLEFT", checkboxX, -6)
    refreshButton:SetScript("OnClick", function()
        if ns.RefreshConsumableMacros then
            ns:RefreshConsumableMacros()
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", refreshButton, "BOTTOMLEFT", 0, -18)
    status:SetWidth(600)
    status:SetJustifyH("LEFT")

    function frame:Refresh()
        healthEnabled:Refresh()
        healthRecuperate:Refresh()
        healthCombat:Refresh()
        manaEnabled:Refresh()
        manaCombat:Refresh()

        local healthStatus = "Health macro disabled."
        local manaStatus = "Mana macro disabled."

        if ns.GetConsumableMacroStatus then
            healthStatus, manaStatus = ns:GetConsumableMacroStatus()
        end

        status:SetText((healthStatus or "") .. "\n" .. (manaStatus or ""))
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
