local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateLootPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local behaviorSection = UI.CreateSection(frame, "Behavior", nil, 0)

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
    fastLoot:SetPoint("TOPLEFT", behaviorSection, "BOTTOMLEFT", 18, -6)

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
    carefulMode:SetPoint("TOPLEFT", fastLoot, "BOTTOMLEFT", 0, -8)

    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", carefulMode, "BOTTOMLEFT", 0, -18)
    status:SetWidth(520)
    status:SetJustifyH("LEFT")

    local vendorSection = UI.CreateSection(frame, "Vendor", status, -34)

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
    autoSellGrey:SetPoint("TOPLEFT", vendorSection, "BOTTOMLEFT", 18, -6)

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
    autoRepair:SetPoint("TOPLEFT", autoSellGrey, "BOTTOMLEFT", 0, -12)

    function frame:Refresh()
        fastLoot:Refresh()
        carefulMode:Refresh()
        autoSellGrey:Refresh()
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
