local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateItemsPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)
    local dropdownWidth = 250

    local function CreateItemOption(sectionName, key, text, shortText)
        return {
            text = text,
            shortText = shortText,
            getter = function()
                return ns.GetItemOverlaySetting and ns:GetItemOverlaySetting(sectionName, key)
            end,
            setter = function(value)
                if ns.SetItemOverlaySetting then
                    ns:SetItemOverlaySetting(sectionName, key, value)
                end

                if frame.Refresh then
                    frame:Refresh()
                end
            end,
        }
    end

    local mainSection = UI.PlaceSection(frame, "General")

    local enabled = UI.CreateCheckbox(
        frame,
        "Enable item overlays",
        "Shows ZoidsTools item information on character slots, bags, bank, and warband bank item buttons.",
        function()
            return ns.GetItemOverlaysEnabled and ns:GetItemOverlaysEnabled()
        end,
        function(value)
            if ns.SetItemOverlaysEnabled then
                ns:SetItemOverlaysEnabled(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end
    )
    UI.PlaceFirst(enabled, mainSection)

    local displaySection = UI.PlaceSection(frame, "Display", enabled)

    local characterOptions = UI.CreateMultiSelectDropdown(
        frame,
        "Character frame",
        "Choose what ZoidsTools displays on equipped character-frame item slots.",
        {
            CreateItemOption("character", "itemLevel", "Equipped item level", "Ilvl"),
            CreateItemOption("character", "gems", "Gem sockets", "Gems"),
            CreateItemOption("character", "gemTooltips", "Gem tooltips", "Tips"),
            CreateItemOption("character", "enchants", "Enchant status", "Enchants"),
            CreateItemOption("character", "missingEnchant", "Missing enchant highlight", "Missing"),
            CreateItemOption("character", "statTargets", "Recommended stat comparison", "Stats"),
        },
        dropdownWidth
    )
    UI.PlaceFirst(characterOptions, displaySection)

    local bagBankOptions = UI.CreateMultiSelectDropdown(
        frame,
        "Bags and bank",
        "Choose what ZoidsTools displays on bag, bank, and warband bank item buttons.",
        {
            CreateItemOption("bags", "itemLevel", "Bag item levels", "Bag ilvl"),
            CreateItemOption("bags", "bindType", "Bag bind type", "Bag binds"),
            CreateItemOption("bank", "itemLevel", "Bank item levels", "Bank ilvl"),
            CreateItemOption("bank", "bindType", "Bank bind type", "Bank binds"),
            CreateItemOption("warbandBank", "itemLevel", "Warband bank item levels", "Warband ilvl"),
            CreateItemOption("warbandBank", "bindType", "Warband bank bind type", "Warband binds"),
        },
        dropdownWidth
    )
    bagBankOptions:SetPoint("TOPLEFT", characterOptions, "TOPRIGHT", UI.Layout.columnGap, 0)

    local statTargetContext = UI.CreateDropdown(
        frame,
        "Stat goal source",
        "Chooses which available per-spec recommended stat goal set to compare against.",
        {
            { value = "mythicplus", text = "Mythic+" },
            { value = "raid", text = "Raid" },
            { value = "pvp", text = "PvP" },
        },
        function()
            return ns.GetStatTargetContext and ns:GetStatTargetContext() or "mythicplus"
        end,
        function(value)
            if ns.SetStatTargetContext then
                ns:SetStatTargetContext(value)
            end

            if frame.Refresh then
                frame:Refresh()
            end
        end,
        dropdownWidth
    )
    UI.PlaceDropdown(statTargetContext, characterOptions)

    local status = UI.CreateStatusText(frame, 540)
    UI.PlaceBelow(status, statTargetContext, 0, 16)

    local styleSection = UI.PlaceSection(frame, "Style", status)

    local fontSize = UI.CreateSlider(
        frame,
        "Overlay text size",
        "Changes item level, bind, and enchant overlay text size.",
        8,
        20,
        1,
        function()
            return ns.GetItemOverlayFontSize and ns:GetItemOverlayFontSize() or 12
        end,
        function(value)
            if ns.SetItemOverlayFontSize then
                ns:SetItemOverlayFontSize(value)
            end
        end,
        220,
        function(value)
            return tostring(math.floor((value or 12) + 0.5))
        end
    )
    UI.PlaceSlider(fontSize, styleSection, UI.Layout.indent)

    local qualityColor = UI.CreateCheckbox(
        frame,
        "Use item quality color",
        "Colors item level text by item quality.",
        function()
            return ns.GetItemOverlayQualityColor and ns:GetItemOverlayQualityColor()
        end,
        function(value)
            if ns.SetItemOverlayQualityColor then
                ns:SetItemOverlayQualityColor(value)
            end
        end
    )
    qualityColor:SetPoint("TOPLEFT", fontSize, "BOTTOMLEFT", -UI.Layout.sliderIndent, -18)

    local refreshButton = UI.CreateButton(frame, "Refresh Item Info", 150)
    refreshButton:SetPoint("LEFT", qualityColor.Text, "RIGHT", 30, 0)
    refreshButton:SetScript("OnClick", function()
        if ns.RefreshItemOverlays then
            ns:RefreshItemOverlays()
        end
    end)

    function frame:Refresh()
        enabled:Refresh()
        characterOptions:Refresh()
        bagBankOptions:Refresh()
        statTargetContext:Refresh()
        fontSize:Refresh()
        qualityColor:Refresh()

        if ns.GetStatTargetStatusText then
            status:SetText(ns:GetStatTargetStatusText())
        else
            status:SetText("")
        end
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
