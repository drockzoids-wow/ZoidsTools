local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateItemsPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

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

    local mainSection = UI.CreateSection(frame, "General", nil, 0)

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
    enabled:SetPoint("TOPLEFT", mainSection, "BOTTOMLEFT", 18, -6)

    local displaySection = UI.CreateSection(frame, "Display", enabled, -26)

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
        },
        300
    )
    characterOptions:SetPoint("TOPLEFT", displaySection, "BOTTOMLEFT", 2, -10)

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
        300
    )
    bagBankOptions:SetPoint("TOPLEFT", characterOptions, "BOTTOMLEFT", 0, -14)

    local styleSection = UI.CreateSection(frame, "Style", bagBankOptions, -28)

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
    fontSize:SetPoint("TOPLEFT", styleSection, "BOTTOMLEFT", 16, -18)

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
    qualityColor:SetPoint("TOPLEFT", fontSize, "BOTTOMLEFT", -16, -16)

    local refreshButton = UI.CreateButton(frame, "Refresh Item Info", 150)
    refreshButton:SetPoint("LEFT", qualityColor.Text, "RIGHT", 24, 0)
    refreshButton:SetScript("OnClick", function()
        if ns.RefreshItemOverlays then
            ns:RefreshItemOverlays()
        end
    end)

    function frame:Refresh()
        enabled:Refresh()
        characterOptions:Refresh()
        bagBankOptions:Refresh()
        fontSize:Refresh()
        qualityColor:Refresh()
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
