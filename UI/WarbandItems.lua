local _, ns = ...

function ns:CreateWarbandItemsPage(parent)
    local host = CreateFrame("Frame", nil, parent)
    host:SetAllPoints()
    host:Hide()
    local scroll = CreateFrame("ScrollFrame", nil, host, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local page = CreateFrame("Frame", nil, scroll)
    page:SetSize(math.max(1, parent:GetWidth() - 24), 525)
    scroll:SetScrollChild(page)
    scroll:SetScript("OnSizeChanged", function(self, width) page:SetWidth(math.max(1, width)) end)
    local query, expansion, offset, selectedCharacter = "", -1, 0, nil
    local rows, results = {}, {}
    local PAGE_SIZE = 7
    local function Label(parentFrame, text, font)
        local label = parentFrame:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
        label:SetText(text)
        label:SetJustifyH("LEFT")
        return label
    end
    local function Button(text, width)
        local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        button:SetSize(width, 24)
        button:SetText(text)
        return button
    end
    local note = Label(page, "Search saved bags, equipped items, and banks. Log into alts and visit banks to record their contents.")
    note:SetPoint("TOPLEFT", 0, -4)
    note:SetPoint("RIGHT", page, "RIGHT", -8, 0)
    note:SetHeight(28)
    note:SetWordWrap(true)
    local search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    search:SetSize(300, 26)
    search:SetPoint("TOPLEFT", 8, -42)
    search:SetAutoFocus(false)
    search:SetMaxLetters(100)
    local hint = Label(page, "Item name or ID")
    hint:SetPoint("LEFT", search, "LEFT", 5, 0)
    hint:SetTextColor(0.5, 0.5, 0.5)
    local filter = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    filter:SetWidth(210)
    filter:SetPoint("LEFT", search, "RIGHT", 14, 0)
    filter:SetDefaultText("All expansions")
    local toggle = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    toggle:SetSize(24, 24)
    toggle:SetPoint("TOPLEFT", 0, -79)
    local toggleText = Label(page, "Show item locations in tooltips")
    toggleText:SetPoint("LEFT", toggle, "RIGHT", 3, 0)
    toggle:SetChecked(ns:GetWarbandItemTooltipsEnabled())
    toggle:SetScript("OnClick", function(self) ns:SetWarbandItemTooltipsEnabled(self:GetChecked()) end)

    local status = Label(page, "")
    status:SetPoint("TOPRIGHT", -8, -86)
    for index = 1, PAGE_SIZE do
        local row = CreateFrame("Button", nil, page)
        row:SetPoint("TOPLEFT", 0, -111 - (index - 1) * 44)
        row:SetPoint("RIGHT", page, "RIGHT", -8, 0)
        row:SetHeight(42)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.title = Label(row, "", "GameFontHighlight")
        row.title:SetPoint("TOPLEFT", 6, -4)
        row.title:SetPoint("RIGHT", row, "RIGHT", -85, 0)
        row.title:SetWordWrap(false)
        row.detail = Label(row, "")
        row.detail:SetPoint("TOPLEFT", 6, -23)
        row.detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.detail:SetWordWrap(false)
        row.count = Label(row, "")
        row.count:SetPoint("TOPRIGHT", -6, -4)
        row:SetScript("OnEnter", function(self)
            if not self.item then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.item.id)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self)
            if self.item and IsModifiedClick("CHATLINK") then
                local _, link = C_Item.GetItemInfo(self.item.id)
                if link then ChatEdit_InsertLink(link) end
            end
        end)
        rows[index] = row
    end
    local previous = Button("Previous", 85)
    previous:SetPoint("TOPLEFT", 0, -427)
    local nextButton = Button("Next", 85)
    nextButton:SetPoint("LEFT", previous, "RIGHT", 8, 0)
    local pagination = Label(page, "")
    pagination:SetPoint("LEFT", nextButton, "RIGHT", 12, 0)
    local empty = Label(page, "No matching items recorded. Try another search, or visit your bank.")
    empty:SetPoint("TOPLEFT", 6, -125)
    empty:SetPoint("RIGHT", page, "RIGHT", -8, 0)
    empty:SetWordWrap(true)

    local forget = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    forget:SetWidth(255)
    forget:SetPoint("TOPLEFT", 0, -465)
    forget:SetDefaultText("Remove an offline character...")
    local remove = Button("Forget items", 110)
    remove:SetPoint("LEFT", forget, "RIGHT", 8, 0)
    remove:Disable()
    local forgetNote = Label(page, "Only removes saved item locations; logging into that character records them again.")
    forgetNote:SetPoint("TOPLEFT", 0, -496)
    forgetNote:SetPoint("RIGHT", page, "RIGHT", -8, 0)
    forgetNote:SetWordWrap(true)

    local function Refresh()
        local items = ns:SearchWarbandItems(query, expansion)
        results = {}
        for _, item in ipairs(items) do
            local locations = ns:GetWarbandItemLocations(item.id)
            for _, location in ipairs(locations) do
                results[#results + 1] = { item = item, location = location }
            end
        end
        offset = math.min(offset, math.max(0, math.floor((#results - 1) / PAGE_SIZE) * PAGE_SIZE))
        for index, row in ipairs(rows) do
            local result = results[offset + index]
            row.item = result and result.item
            row:SetShown(result ~= nil)
            if result then
                local location = result.location
                row.title:SetText(result.item.name)
                row.count:SetText(tostring(location.count))
                row.detail:SetText(location.owner .. "  |  " .. location.label)
                local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[location.class]
                row.detail:SetTextColor(color and color.r or 0.7, color and color.g or 0.7, color and color.b or 0.7)
            end
        end
        status:SetText(#items .. " items / " .. #results .. " locations")
        pagination:SetText(#results > 0 and string.format("%d-%d of %d", offset + 1, math.min(offset + PAGE_SIZE, #results), #results) or "")
        empty:SetShown(#results == 0)
        previous:SetEnabled(offset > 0)
        nextButton:SetEnabled(offset + PAGE_SIZE < #results)
    end
    previous:SetScript("OnClick", function() offset = math.max(0, offset - PAGE_SIZE); Refresh() end)
    nextButton:SetScript("OnClick", function() offset = offset + PAGE_SIZE; Refresh() end)
    search:SetScript("OnTextChanged", function(self)
        query, offset = self:GetText(), 0
        hint:SetShown(query == "")
        Refresh()
    end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    filter:SetupMenu(function(_, root)
        local function Add(id, name)
            root:CreateRadio(name, function() return expansion == id end, function()
                expansion, offset = id, 0
                filter:SetDefaultText(name)
                Refresh()
            end)
        end
        Add(-1, "All expansions")
        for id = LE_EXPANSION_LEVEL_CURRENT or 11, 0, -1 do
            Add(id, _G["EXPANSION_NAME" .. id] or ("Expansion " .. id))
        end
    end)
    forget:SetupMenu(function(_, root)
        for _, character in ipairs(ns:GetWarbandItemCharacters()) do
            if character.key ~= UnitGUID("player") then
                root:CreateRadio(character.name, function() return selectedCharacter == character.key end, function()
                    selectedCharacter = character.key
                    forget:SetDefaultText(character.name)
                    remove:Enable()
                end)
            end
        end
    end)
    remove:SetScript("OnClick", function()
        if selectedCharacter then ns:ForgetWarbandItemCharacter(selectedCharacter) end
        selectedCharacter = nil
        forget:SetDefaultText("Remove an offline character...")
        remove:Disable()
    end)
    host.Refresh = Refresh
    host:SetScript("OnShow", Refresh)
    ns.UI2.RefreshWarbandItems = function() if host:IsShown() then Refresh() end end
    Refresh()
    return host
end
