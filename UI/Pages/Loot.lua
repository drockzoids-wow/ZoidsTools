local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateLootPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local behaviorSection = UI.PlaceSection(frame, "Behavior")

    local fastLoot = UI.CreateCheckbox(
        frame,
        "Fast auto loot",
        "Enables WoW auto-loot if needed, then clicks loot slots quickly when auto-loot is active.",
        function()
            return ns.GetFastLootEnabled and ns:GetFastLootEnabled()
        end,
        function(value)
            if ns.SetFastLootEnabled then
                ns:SetFastLootEnabled(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    )
    UI.PlaceFirst(fastLoot, behaviorSection)

    local carefulMode = UI.CreateCheckbox(
        frame,
        "Careful second pass",
        "Runs one delayed follow-up sweep for unusual loot delays. Leave this off unless items are missed.",
        function()
            return ns.db and ns.db.loot.carefulMode
        end,
        function(value)
            ns.db.loot.carefulMode = value
        end
    )
    UI.PlaceBelow(carefulMode, fastLoot)

    local status = UI.CreateStatusText(frame)
    UI.PlaceBelow(status, carefulMode, 0, 18)

    local vendorSection = UI.PlaceSection(frame, "Vendor", status)

    local autoSellGrey = UI.CreateCheckbox(
        frame,
        "Auto-sell grey items",
        "Automatically uses the vendor junk-sell behavior when a merchant window opens.",
        function()
            return ns.GetAutoSellGreyItems and ns:GetAutoSellGreyItems()
        end,
        function(value)
            if ns.SetAutoSellGreyItems then
                ns:SetAutoSellGreyItems(value)
            end
        end
    )
    UI.PlaceFirst(autoSellGrey, vendorSection)

    local autoSellBoEGrey = UI.CreateCheckbox(
        frame,
        "Include BoE grey items",
        "Includes bind-on-equip grey items when auto-selling junk. When off, unbound grey equipment is skipped.",
        function()
            return ns.GetAutoSellBoEGreyItems and ns:GetAutoSellBoEGreyItems()
        end,
        function(value)
            if ns.SetAutoSellBoEGreyItems then
                ns:SetAutoSellBoEGreyItems(value)
            end
        end
    )
    UI.PlaceBelow(autoSellBoEGrey, autoSellGrey)

    local repairOptions = ns.GetAutoRepairModeOptions and ns:GetAutoRepairModeOptions() or {
        { value = "disabled", text = "Disabled" },
        { value = "personal", text = "Use My Gold" },
        { value = "guild", text = "Use Guild Bank" },
    }

    local autoRepair = UI.CreateDropdown(
        frame,
        "Auto repair",
        "Automatically repairs when a merchant can repair. Guild Bank will not spend your own gold if guild repair is unavailable.",
        repairOptions,
        function()
            return ns.GetAutoRepairMode and ns:GetAutoRepairMode() or "disabled"
        end,
        function(value)
            if ns.SetAutoRepairMode then
                ns:SetAutoRepairMode(value)
            end
        end,
        220
    )
    UI.PlaceDropdown(autoRepair, autoSellBoEGrey)

    function frame:Refresh()
        fastLoot:Refresh()
        carefulMode:Refresh()
        autoSellGrey:Refresh()
        autoSellBoEGrey:Refresh()
        autoRepair:Refresh()

        if ns.GetFastLootEnabled and ns:GetFastLootEnabled() then
            if ns.GetBlizzardAutoLootEnabled and ns:GetBlizzardAutoLootEnabled() then
                status:SetText("Fast loot is active. WoW auto-loot is enabled.")
            else
                status:SetText("Fast loot is active and will enable WoW auto-loot.")
            end
        else
            status:SetText("Fast loot is disabled. Your WoW auto-loot setting is left unchanged.")
        end
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
