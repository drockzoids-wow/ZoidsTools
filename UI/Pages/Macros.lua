local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateMacrosPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local healthSection = UI.PlaceSection(frame, "Health Macro")

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
    UI.PlaceFirst(healthEnabled, healthSection)

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
    UI.PlaceBelow(healthRecuperate, healthEnabled)

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
    UI.PlaceBelow(healthCombat, healthRecuperate)

    local manaSection = UI.PlaceSection(frame, "Mana Macro", healthCombat)

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
    UI.PlaceFirst(manaEnabled, manaSection)

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
    UI.PlaceBelow(manaCombat, manaEnabled)

    local hearthstoneSection = UI.PlaceSection(frame, "Random Hearthstone", manaCombat)

    local hearthstoneEnabled = UI.CreateCheckbox(
        frame,
        "Create ZT Hearth macro",
        "Creates a macro that uses a random selected Hearthstone. The ZoidsTools keybind is always available.",
        function()
            return ns.GetRandomHearthstoneEnabled and ns:GetRandomHearthstoneEnabled()
        end,
        function(value)
            if ns.SetRandomHearthstoneEnabled then
                ns:SetRandomHearthstoneEnabled(value)
            end
        end
    )
    UI.PlaceFirst(hearthstoneEnabled, hearthstoneSection)

    local selectHearthstones = UI.CreateButton(frame, "Select Hearthstones  v", 180)
    UI.PlaceBelow(selectHearthstones, hearthstoneEnabled, 0, 16)
    selectHearthstones:SetScript("OnClick", function()
        if ns.OpenRandomHearthstoneSelector then
            ns:OpenRandomHearthstoneSelector(selectHearthstones)
        end
    end)

    local hearthstoneStatus = UI.CreateStatusText(frame, 420)
    hearthstoneStatus:SetPoint("LEFT", selectHearthstones, "RIGHT", 18, 0)

    local actionsSection = UI.PlaceSection(frame, "Actions", selectHearthstones)

    local refreshButton = UI.CreateButton(frame, "Refresh Macros", 140)
    UI.PlaceFirst(refreshButton, actionsSection)
    refreshButton:SetScript("OnClick", function()
        if ns.RefreshConsumableMacros then
            ns:RefreshConsumableMacros(true)
        end

        if ns.RefreshRandomHearthstoneMacro then
            ns:RefreshRandomHearthstoneMacro()
        end

        if ns.Print then
            if InCombatLockdown and InCombatLockdown() then
                ns:Print("Macro refresh queued until combat ends.")
            else
                ns:Print("Enabled macros checked and refreshed where needed.")
            end
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    local status = UI.CreateStatusText(frame, 680)
    UI.PlaceBelow(status, refreshButton, 0, 18)

    function frame:Refresh()
        healthEnabled:Refresh()
        healthRecuperate:Refresh()
        healthCombat:Refresh()
        manaEnabled:Refresh()
        manaCombat:Refresh()
        hearthstoneEnabled:Refresh()

        local healthStatus = "Health macro disabled."
        local manaStatus = "Mana macro disabled."

        if ns.GetConsumableMacroStatus then
            healthStatus, manaStatus = ns:GetConsumableMacroStatus()
        end

        status:SetText((healthStatus or "") .. "\n" .. (manaStatus or ""))
        hearthstoneStatus:SetText(ns.GetRandomHearthstoneStatus and ns:GetRandomHearthstoneStatus() or "")
    end

    frame:SetScript("OnShow", frame.Refresh)
    frame:SetScript("OnHide", function()
        if ns.CloseRandomHearthstoneSelector then
            ns:CloseRandomHearthstoneSelector()
        end
    end)

    return frame
end
