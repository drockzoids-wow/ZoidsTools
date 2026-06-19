local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

local SERVICE_LABELS = {
    repair = "Repair",
    auctionHouse = "AH",
    rideAlong = "Ride-along",
}

local function AddPlaceholder(editBox, text)
    local placeholder = editBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", editBox, "LEFT", 6, 0)
    placeholder:SetPoint("RIGHT", editBox, "RIGHT", -6, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetText(text)

    local function Refresh(self)
        local value = self:GetText() or ""
        placeholder:SetShown(value == "" and not self:HasFocus())
    end

    editBox:HookScript("OnTextChanged", Refresh)
    editBox:HookScript("OnEditFocusGained", Refresh)
    editBox:HookScript("OnEditFocusLost", Refresh)
    Refresh(editBox)
end

local function CreateSearchBox(parent, width)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width or 240, 24)
    box:SetAutoFocus(false)
    return box
end

local function SetCheckboxTextWidth(checkbox, width)
    if checkbox and checkbox.Text then
        checkbox.Text:SetWidth(width)
        checkbox.Text:SetJustifyH("LEFT")
    end
end

local function CreateDynamicDropdown(parent, label, tooltip, width, getOptions, getter, setter)
    local UI = ns.UI
    local Theme = UI.Theme
    local control = CreateFrame("Frame", nil, parent)
    local rowHeight = 24
    local dropdownWidth = width or 240

    control:SetSize(dropdownWidth, 52)

    control.label = control:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    control.label:SetPoint("TOPLEFT", 0, 0)
    control.label:SetText(label)

    control.button = CreateFrame("Button", nil, control, "BackdropTemplate")
    control.button:SetPoint("TOPLEFT", control.label, "BOTTOMLEFT", 0, -6)
    control.button:SetSize(dropdownWidth, 28)
    control.button:RegisterForClicks("LeftButtonUp")
    control.button:SetBackdrop({
        bgFile = Theme and Theme.panelBg or "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    control.button:SetBackdropColor(0.02, 0.018, 0.014, 0.95)
    control.button:SetBackdropBorderColor(0.65, 0.52, 0.25, 0.45)

    control.button.text = control.button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    control.button.text:SetPoint("LEFT", control.button, "LEFT", 10, 0)
    control.button.text:SetPoint("RIGHT", control.button, "RIGHT", -30, 0)
    control.button.text:SetJustifyH("LEFT")

    control.button.arrow = control.button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    control.button.arrow:SetPoint("RIGHT", control.button, "RIGHT", -10, 0)
    control.button.arrow:SetText("v")

    control.menu = CreateFrame("Frame", nil, control, "BackdropTemplate")
    control.menu:SetPoint("TOPLEFT", control.button, "BOTTOMLEFT", 0, -2)
    control.menu:SetFrameStrata("DIALOG")
    control.menu:SetToplevel(true)
    control.menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    control.menu:SetBackdropColor(0.015, 0.014, 0.012, 1)
    control.menu:SetBackdropBorderColor(0.85, 0.7, 0.38, 0.65)
    control.menu:Hide()
    control.rows = {}

    if tooltip then
        control.button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)

        control.button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    local function HideIfMouseAway()
        if not control.button:IsMouseOver() and not control.menu:IsMouseOver() then
            control.menu:Hide()
            control.button.arrow:SetText("v")
        end
    end

    local function SetSelectedText(value, options)
        for _, option in ipairs(options) do
            if option.value == value then
                control.button.text:SetText(option.text)
                return
            end
        end

        control.button.text:SetText("Default Priority")
    end

    function control:Refresh()
        local options = getOptions() or {}
        local value = getter() or ""

        SetSelectedText(value, options)

        for _, row in ipairs(self.rows) do
            row:Hide()
        end

        self.menu:SetSize(dropdownWidth, math.max(1, (#options * rowHeight) + 12))

        for index, option in ipairs(options) do
            local row = self.rows[index]

            if not row then
                row = CreateFrame("Button", nil, self.menu, "BackdropTemplate")
                row:SetSize(dropdownWidth - 16, rowHeight)
                row:RegisterForClicks("LeftButtonUp")

                row.highlight = row:CreateTexture(nil, "BACKGROUND")
                row.highlight:SetPoint("TOPLEFT", 2, -1)
                row.highlight:SetPoint("BOTTOMRIGHT", -2, 1)
                row.highlight:SetColorTexture(1, 0.82, 0.18, 0.08)
                row.highlight:Hide()

                row.check = row:CreateTexture(nil, "OVERLAY")
                row.check:SetPoint("LEFT", row, "LEFT", 6, 0)
                row.check:SetSize(16, 16)
                row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                row.check:SetVertexColor(1, 0.86, 0.12, 1)

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", row, "LEFT", 28, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                row.text:SetJustifyH("LEFT")

                row:SetScript("OnEnter", function(self)
                    self.highlight:Show()
                    self.text:SetTextColor(1, 0.86, 0.18)
                end)

                row:SetScript("OnLeave", function(self)
                    self.highlight:Hide()
                    self.text:SetTextColor(1, 1, 1)

                    if C_Timer and C_Timer.After then
                        C_Timer.After(0.12, HideIfMouseAway)
                    end
                end)

                self.rows[index] = row
            end

            row:SetPoint("TOPLEFT", self.menu, "TOPLEFT", 8, -6 - ((index - 1) * rowHeight))
            row.text:SetText(option.text)
            row.check:SetShown(option.value == value)
            row:SetScript("OnClick", function()
                setter(option.value)
                control:Refresh()
                control.menu:Hide()
                control.button.arrow:SetText("v")
            end)
            row:Show()
        end
    end

    control.button:SetScript("OnClick", function()
        if control.menu:IsShown() then
            control.menu:Hide()
            control.button.arrow:SetText("v")
        else
            control:Refresh()
            control.menu:Show()
            control.button.arrow:SetText("^")
        end
    end)

    control.button:HookScript("OnLeave", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.12, HideIfMouseAway)
        end
    end)

    control.menu:SetScript("OnLeave", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.12, HideIfMouseAway)
        end
    end)

    control:Refresh()

    return control
end

function ns.UI.Pages.CreateMountsPage(parent)
    local UI = ns.UI
    local Theme = UI.Theme
    local frame = UI.CreatePageFrame(parent)
    local controls = {}
    local leftWidth = 270
    local rightX = 326
    local rightWidth = 220

    local smartSection = UI.PlaceSection(frame, "Smart Mount", nil, leftWidth)

    local enabled = UI.CreateCheckbox(
        frame,
        "Enable smart mount",
        "Enables the ZoidsTools smart mount keybind.",
        function()
            return ns.GetMountsEnabled and ns:GetMountsEnabled()
        end,
        function(value)
            if ns.SetMountsEnabled then
                ns:SetMountsEnabled(value)
            end
        end
    )
    UI.PlaceFirst(enabled, smartSection)
    controls[#controls + 1] = enabled

    local currentPreferred = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    currentPreferred:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 4, -12)
    currentPreferred:SetWidth(leftWidth - 20)
    currentPreferred:SetJustifyH("LEFT")

    local searchBox = CreateSearchBox(frame, 190)
    searchBox:SetPoint("TOPLEFT", currentPreferred, "BOTTOMLEFT", 4, -8)
    AddPlaceholder(searchBox, "Type a mount name...")

    local resetPreferred = UI.CreateButton(frame, "Reset", 76, 26)
    resetPreferred:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)

    local results = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    results:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -4, -8)
    results:SetSize(278, 40)
    results:SetFrameStrata("DIALOG")
    results:SetToplevel(true)
    results:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme and Theme.panelBorder or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    results:SetBackdropColor(0.015, 0.014, 0.012, 1)
    results:SetBackdropBorderColor(0.85, 0.7, 0.38, 0.65)
    results:Hide()
    results.rows = {}

    results.emptyText = results:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    results.emptyText:SetPoint("TOPLEFT", results, "TOPLEFT", 10, -10)
    results.emptyText:SetWidth(250)
    results.emptyText:SetJustifyH("LEFT")
    results.emptyText:SetText("No collected mounts match.")
    results.emptyText:Hide()

    local behaviorSection = UI.PlaceSection(frame, "Behavior", searchBox, leftWidth)

    local recentAvoid = UI.CreateSlider(
        frame,
        "Avoid recent mounts",
        "Avoids recently used random mounts when possible.",
        0,
        10,
        1,
        function()
            return ns.GetMountRecentAvoidCount and ns:GetMountRecentAvoidCount() or 0
        end,
        function(value)
            if ns.SetMountRecentAvoidCount then
                ns:SetMountRecentAvoidCount(value)
            end
        end,
        230,
        function(value)
            return tostring(math.floor((value or 0) + 0.5))
        end
    )
    UI.PlaceFirst(recentAvoid, behaviorSection)
    controls[#controls + 1] = recentAvoid

    local preferGround = UI.CreateCheckbox(
        frame,
        "Prefer ground in no-fly areas",
        "Uses ground mounts in no-fly areas when possible.",
        function()
            return ns.GetMountOption and ns:GetMountOption("preferGroundWhenNotFlyable")
        end,
        function(value)
            if ns.SetMountOption then
                ns:SetMountOption("preferGroundWhenNotFlyable", value)
            end
        end
    )
    UI.PlaceBelow(preferGround, recentAvoid, -UI.Layout.sliderIndent, 22)
    SetCheckboxTextWidth(preferGround, leftWidth - 32)
    controls[#controls + 1] = preferGround

    local surfaceWater = UI.CreateCheckbox(
        frame,
        "Water mounts at surface",
        "Uses water mounts at the water surface if the area does not allow flying.",
        function()
            return ns.GetMountOption and ns:GetMountOption("useWaterMountsOnSurface")
        end,
        function(value)
            if ns.SetMountOption then
                ns:SetMountOption("useWaterMountsOnSurface", value)
            end
        end
    )
    UI.PlaceBelow(surfaceWater, preferGround)
    SetCheckboxTextWidth(surfaceWater, leftWidth - 32)
    controls[#controls + 1] = surfaceWater

    local excludeService = UI.CreateCheckbox(
        frame,
        "Skip service mounts in random",
        "Keeps repair, auction house, and ride-along mounts out of normal smart random picks.",
        function()
            return ns.GetMountOption and ns:GetMountOption("excludeServiceMountsFromRandom")
        end,
        function(value)
            if ns.SetMountOption then
                ns:SetMountOption("excludeServiceMountsFromRandom", value)
            end
        end
    )
    UI.PlaceBelow(excludeService, surfaceWater)
    SetCheckboxTextWidth(excludeService, leftWidth - 32)
    controls[#controls + 1] = excludeService

    local classSection = UI.PlaceSection(frame, "Class Options", excludeService, leftWidth)

    local classOptions = UI.CreateMultiSelectDropdown(
        frame,
        "Class utilities",
        "Adds class and race utility spells to the smart mount keybind.",
        {
            {
                text = "Druid Travel Form",
                shortText = "Travel",
                tooltip = "Uses Travel Form outdoors when available.",
                getter = function()
                    return ns.GetMountClassOption and ns:GetMountClassOption("useDruidTravelForm")
                end,
                setter = function(value)
                    if ns.SetMountClassOption then
                        ns:SetMountClassOption("useDruidTravelForm", value)
                    end
                end,
            },
            {
                text = "Druid Cat Form indoors",
                shortText = "Cat",
                tooltip = "Uses Cat Form indoors when mount behavior cannot run.",
                getter = function()
                    return ns.GetMountClassOption and ns:GetMountClassOption("useDruidCatForm")
                end,
                setter = function(value)
                    if ns.SetMountClassOption then
                        ns:SetMountClassOption("useDruidCatForm", value)
                    end
                end,
            },
            {
                text = "Dracthyr Soar",
                shortText = "Soar",
                tooltip = "Uses Soar in flyable outdoor areas when available.",
                getter = function()
                    return ns.GetMountClassOption and ns:GetMountClassOption("useDracthyrSoar")
                end,
                setter = function(value)
                    if ns.SetMountClassOption then
                        ns:SetMountClassOption("useDracthyrSoar", value)
                    end
                end,
            },
            {
                text = "Falling rescue",
                shortText = "Rescue",
                tooltip = "Uses class fall-safety spells such as Slow Fall, Levitate, Glide, Flap, or Zen Flight.",
                getter = function()
                    return ns.GetMountClassOption and ns:GetMountClassOption("useFallingRescue")
                end,
                setter = function(value)
                    if ns.SetMountClassOption then
                        ns:SetMountClassOption("useFallingRescue", value)
                    end
                end,
            },
        },
        leftWidth - UI.Layout.indent
    )
    UI.PlaceFirst(classOptions, classSection)
    controls[#controls + 1] = classOptions

    local resetRecent = UI.CreateButton(frame, "Reset Recent", 128)
    resetRecent:SetPoint("TOPLEFT", classOptions, "BOTTOMLEFT", 0, -16)
    resetRecent:SetScript("OnClick", function()
        if ns.ClearMountRecentHistory then
            ns:ClearMountRecentHistory()
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    local historyStatus = UI.CreateStatusText(frame, 190)
    historyStatus:SetPoint("LEFT", resetRecent, "RIGHT", 14, 0)

    local serviceSection = UI.PlaceSection(frame, "Service Mounts", nil, rightWidth)
    serviceSection:ClearAllPoints()
    serviceSection:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, 0)

    local repair = CreateDynamicDropdown(
        frame,
        SERVICE_LABELS.repair,
        "Preferred repair/vendor mount. Default Priority uses the built-in service mount order.",
        rightWidth,
        function()
            return ns.GetMountServiceOptions and ns:GetMountServiceOptions("repair") or {}
        end,
        function()
            return ns.GetPreferredServiceMount and ns:GetPreferredServiceMount("repair") or ""
        end,
        function(value)
            if ns.SetPreferredServiceMount then
                ns:SetPreferredServiceMount("repair", value)
            end
        end
    )
    UI.PlaceFirst(repair, serviceSection)
    controls[#controls + 1] = repair

    local auctionHouse = CreateDynamicDropdown(
        frame,
        SERVICE_LABELS.auctionHouse,
        "Preferred auction house mount. Default Priority uses the built-in AH mount order.",
        rightWidth,
        function()
            return ns.GetMountServiceOptions and ns:GetMountServiceOptions("auctionHouse") or {}
        end,
        function()
            return ns.GetPreferredServiceMount and ns:GetPreferredServiceMount("auctionHouse") or ""
        end,
        function(value)
            if ns.SetPreferredServiceMount then
                ns:SetPreferredServiceMount("auctionHouse", value)
            end
        end
    )
    UI.PlaceDropdown(auctionHouse, repair)
    controls[#controls + 1] = auctionHouse

    local rideAlong = CreateDynamicDropdown(
        frame,
        SERVICE_LABELS.rideAlong,
        "Preferred passenger mount. Default Priority chooses from eligible ride-along mounts.",
        rightWidth,
        function()
            return ns.GetMountServiceOptions and ns:GetMountServiceOptions("rideAlong") or {}
        end,
        function()
            return ns.GetPreferredServiceMount and ns:GetPreferredServiceMount("rideAlong") or ""
        end,
        function(value)
            if ns.SetPreferredServiceMount then
                ns:SetPreferredServiceMount("rideAlong", value)
            end
        end
    )
    UI.PlaceDropdown(rideAlong, auctionHouse)
    controls[#controls + 1] = rideAlong

    local matchSection = UI.CreateSection(frame, "Target Match", nil, 0, rightWidth)
    matchSection:ClearAllPoints()
    matchSection:SetPoint("TOPLEFT", rideAlong, "BOTTOMLEFT", 0, -24)

    local matchEnabled = UI.CreateCheckbox(
        frame,
        "Enable matching",
        "Allows the keybind or button to summon your target's mount when you own it.",
        function()
            return ns.GetMountMatchEnabled and ns:GetMountMatchEnabled()
        end,
        function(value)
            if ns.SetMountMatchEnabled then
                ns:SetMountMatchEnabled(value)
            end
        end
    )
    UI.PlaceFirst(matchEnabled, matchSection)
    SetCheckboxTextWidth(matchEnabled, rightWidth - 32)
    controls[#controls + 1] = matchEnabled

    local showMatchButton = UI.CreateCheckbox(
        frame,
        "Show floating button",
        "Shows a movable button for matching your target's mount.",
        function()
            return ns.GetTargetMatchButtonShown and ns:GetTargetMatchButtonShown()
        end,
        function(value)
            if ns.SetTargetMatchButtonShown then
                ns:SetTargetMatchButtonShown(value)
            end
        end
    )
    UI.PlaceBelow(showMatchButton, matchEnabled)
    SetCheckboxTextWidth(showMatchButton, rightWidth - 32)
    controls[#controls + 1] = showMatchButton

    local matchButton = UI.CreateButton(frame, "Match Target", 126)
    matchButton:SetPoint("TOPLEFT", showMatchButton, "BOTTOMLEFT", 0, -12)
    matchButton:SetScript("OnClick", function()
        if ZoidsToolsMounts and ZoidsToolsMounts.MatchTargetMount then
            ZoidsToolsMounts.MatchTargetMount()
        end

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    local matchStatus = UI.CreateStatusText(frame, rightWidth)
    matchStatus:SetPoint("TOPLEFT", matchButton, "BOTTOMLEFT", 0, -12)

    local function RefreshSearchResults()
        local query = searchBox:GetText() or ""
        local matches = ns.GetCollectedMountSearch and ns:GetCollectedMountSearch(query, 5) or {}

        for _, row in ipairs(results.rows) do
            row:Hide()
        end

        results.emptyText:Hide()

        if query == "" then
            results:Hide()
            return
        end

        results:SetHeight(math.max(40, (#matches * 28) + 18))
        results:Show()

        if #matches == 0 then
            results.emptyText:Show()
            return
        end

        for index, mount in ipairs(matches) do
            local row = results.rows[index]

            if not row then
                row = CreateFrame("Frame", nil, results)
                row:SetSize(260, 26)

                row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.text:SetWidth(188)
                row.text:SetJustifyH("LEFT")

                row.use = UI.CreateButton(row, "Use", 58, 24)
                row.use:SetPoint("LEFT", row.text, "RIGHT", 8, 0)

                results.rows[index] = row
            end

            row:SetPoint("TOPLEFT", results, "TOPLEFT", 10, -8 - ((index - 1) * 28))
            row.text:SetText(mount.name)
            row.use:SetScript("OnClick", function()
                if ns.SetPreferredMountName then
                    ns:SetPreferredMountName(mount.name)
                end

                searchBox:SetText("")
                searchBox:ClearFocus()
                results:Hide()

                if frame.Refresh then
                    frame:Refresh()
                end

                ns:Print("Preferred smart mount set to " .. mount.name .. ".")
            end)
            row:Show()
        end
    end

    searchBox:SetScript("OnTextChanged", RefreshSearchResults)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        results:Hide()
    end)

    resetPreferred:SetScript("OnClick", function()
        if ns.SetPreferredMountName then
            ns:SetPreferredMountName(nil)
        end

        searchBox:SetText("")
        searchBox:ClearFocus()
        results:Hide()

        if frame.Refresh then
            frame:Refresh()
        end
    end)

    function frame:Refresh()
        for _, control in ipairs(controls) do
            if control.Refresh then
                control:Refresh()
            end
        end

        local preferredName = ns.GetPreferredMountName and ns:GetPreferredMountName()
        currentPreferred:SetText("Preferred: " .. (preferredName or "Default Random Behavior"))
        historyStatus:SetText(ns.GetMountStatusText and ns:GetMountStatusText() or "")

        local match = ns.GetTargetMountMatch and ns:GetTargetMountMatch()
        matchStatus:SetText(match and match.status or "Select a mounted target.")
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
