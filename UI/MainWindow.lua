local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

local UI = ns.UI
local Theme = UI.Theme
local pages = {}
local buttons = {}
local RefreshHeaderStatus

local WINDOW_WIDTH = 980
local WINDOW_HEIGHT = 600
local OUTER_MARGIN = 14
local SIDEBAR_WIDTH = 174
local SIDEBAR_TOP = -46
local SIDEBAR_BUTTON_HEIGHT = 25
local SIDEBAR_BUTTON_SPACING = 27
local CONTENT_LEFT = OUTER_MARGIN + SIDEBAR_WIDTH + 14
local HEADER_TOP = -46
local CONTENT_TOP = -116
local CONTENT_RIGHT = -14
local CONTENT_BOTTOM = 18
local TITLE_BADGE_SIZE = 40
local TITLE_BADGE_ICON_SIZE = 32

local pageOrder = {
    { key = "general", label = "General", group = "Core", icon = "G", description = "Core ZoidsTools settings." },
    { key = "tooltips", label = "Tooltips", group = "Core", icon = "T", description = "Unit tooltip appearance and player detail settings." },
    { key = "windows", label = "Windows", group = "Core", icon = "W", description = "Move Blizzard UI windows and default bags." },
    { key = "items", label = "Items", group = "Character", icon = "I", description = "Item level, gem, enchant, and binding overlays." },
    { key = "professions", label = "Professions", group = "Character", icon = "P", description = "Molinari-style profession actions for hovered bag items." },
    { key = "builds", label = "Talents", group = "Character", icon = "B", description = "Talent build suggestions from generated local data." },
    { key = "meters", label = "Meters", group = "Combat", icon = "M", description = "Profiles for Blizzard's built-in damage meter windows." },
    { key = "combat", label = "Combat", group = "Combat", icon = "C", description = "Combat quality-of-life settings." },
    { key = "unitframes", label = "Unit Frames", group = "Combat", icon = "U", description = "Blizzard unit frame health, castbar, and aura settings." },
    { key = "macros", label = "Macros", group = "Combat", icon = "A", description = "Health, mana, and consumable macro settings." },
    { key = "mounts", label = "Mounts", group = "Combat", icon = "R", description = "Smart random mount and service mount settings." },
    { key = "loot", label = "Loot", group = "Automation", icon = "L", description = "Looting quality-of-life settings." },
    { key = "quests", label = "Quests", group = "Automation", icon = "Q", description = "Quest and gossip automation settings." },
    { key = "about", label = "About", group = "Info", icon = "?", description = "Version and command information." },
}
local pageInfoByKey = {}

for _, info in ipairs(pageOrder) do
    pageInfoByKey[info.key] = info
end

function UI.CreatePageFrame(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame.ZTPageKey = UI.BuildingPageKey
    frame.ZTWindow = parent
    frame.ZTScrollOffset = 0
    frame:SetPoint("TOPLEFT", parent.contentPanel, "TOPLEFT", 18, -16)
    frame:SetPoint("TOPRIGHT", parent.contentPanel, "TOPRIGHT", -18, -16)
    frame:SetHeight(620)
    frame:Hide()
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        UI.ScrollCurrentPage(delta)
    end)

    function frame:SetCompactScrollOffset(offset)
        self.ZTScrollOffset = math.max(0, tonumber(offset) or 0)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", parent.contentPanel, "TOPLEFT", 18, -16 + self.ZTScrollOffset)
        self:SetPoint("TOPRIGHT", parent.contentPanel, "TOPRIGHT", -18, -16 + self.ZTScrollOffset)
        self:SetHeight(620)
    end

    return frame
end

local function FindLowestVisiblePoint(frame, lowest, depth)
    if not frame or depth <= 0 then return lowest end

    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region and region.IsShown and region:IsShown() and region.GetBottom then
                local bottom = region:GetBottom()
                if bottom and (not lowest or bottom < lowest) then lowest = bottom end
            end
        end
    end

    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            if child and child:IsShown() then
                local bottom = child.GetBottom and child:GetBottom()
                if bottom and (not lowest or bottom < lowest) then lowest = bottom end
                lowest = FindLowestVisiblePoint(child, lowest, depth - 1)
            end
        end
    end

    return lowest
end

local function GetPageScrollMaximum(page)
    if not page or not page.ZTWindow or not page.ZTWindow.contentPanel then
        return 0
    end

    local pageTop = page:GetTop()
    local lowest = FindLowestVisiblePoint(page, nil, 6)
    local viewport = page.ZTWindow.contentPanel:GetHeight() - 32
    local contentHeight = pageTop and lowest and (pageTop - lowest + 18) or viewport
    return math.max(0, contentHeight - viewport)
end

local function RefreshScrollIndicator(frame, page)
    if not frame or not frame.scrollIndicator or not page then return end
    local maximum = GetPageScrollMaximum(page)

    if maximum <= 0 then
        frame.scrollIndicator:Hide()
        return
    end

    local trackHeight = math.max(80, frame.contentPanel:GetHeight() - 28)
    local thumbHeight = math.max(42, trackHeight * (trackHeight / page:GetHeight()))
    local progress = math.min(1, (page.ZTScrollOffset or 0) / maximum)
    local travel = math.max(0, trackHeight - thumbHeight)
    frame.scrollIndicator:SetHeight(thumbHeight)
    frame.scrollIndicator:ClearAllPoints()
    frame.scrollIndicator:SetPoint("TOPRIGHT", frame.contentPanel, "TOPRIGHT", -5, -14 - (travel * progress))
    frame.scrollIndicator:Show()
end

function UI.ScrollCurrentPage(delta)
    local page = UI.currentPage and pages[UI.currentPage]
    if not page or not page.SetCompactScrollOffset then return end

    local maximum = GetPageScrollMaximum(page)
    local offset = math.max(0, math.min(maximum, (page.ZTScrollOffset or 0) - ((delta or 0) * 38)))
    page:SetCompactScrollOffset(offset)
    RefreshScrollIndicator(UI.frame, page)
end

function UI.ScrollControlIntoView(control)
    local page = UI.currentPage and pages[UI.currentPage]
    if not page or not control or not control.GetTop or not control.GetBottom then return end

    local controlTop, controlBottom = control:GetTop(), control:GetBottom()
    local panelTop, panelBottom = UI.frame.contentPanel:GetTop(), UI.frame.contentPanel:GetBottom()
    if not controlTop or not controlBottom or not panelTop or not panelBottom then return end

    local offset = page.ZTScrollOffset or 0
    if controlTop > panelTop - 12 then
        offset = offset - (controlTop - panelTop + 18)
    elseif controlBottom < panelBottom + 12 then
        offset = offset + (panelBottom - controlBottom + 18)
    end

    page:SetCompactScrollOffset(math.max(0, math.min(GetPageScrollMaximum(page), offset)))
    RefreshScrollIndicator(UI.frame, page)
end

local function SaveMainWindowPosition(frame)
    if not ns.db or not ns.db.ui or not ns.db.ui.mainWindow then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)

    if point then
        ns.db.ui.mainWindow.point = point
        ns.db.ui.mainWindow.relativePoint = relativePoint
        ns.db.ui.mainWindow.x = x
        ns.db.ui.mainWindow.y = y
    end
end

local function RestoreMainWindowPosition(frame)
    local saved = ns.db and ns.db.ui and ns.db.ui.mainWindow

    frame:ClearAllPoints()

    if saved and saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    else
        frame:SetPoint("CENTER")
    end
end

local function CreatePage(parent, key)
    if key == "general" and UI.Pages.CreateGeneralPage then
        return UI.Pages.CreateGeneralPage(parent)
    elseif key == "tooltips" and UI.Pages.CreateTooltipsPage then
        return UI.Pages.CreateTooltipsPage(parent)
    elseif key == "windows" and UI.Pages.CreateWindowsPage then
        return UI.Pages.CreateWindowsPage(parent)
    elseif key == "items" and UI.Pages.CreateItemsPage then
        return UI.Pages.CreateItemsPage(parent)
    elseif key == "professions" and UI.Pages.CreateProfessionsPage then
        return UI.Pages.CreateProfessionsPage(parent)
    elseif key == "builds" and UI.Pages.CreateBuildsPage then
        return UI.Pages.CreateBuildsPage(parent)
    elseif key == "meters" and UI.Pages.CreateMetersPage then
        return UI.Pages.CreateMetersPage(parent)
    elseif key == "combat" and UI.Pages.CreateCombatPage then
        return UI.Pages.CreateCombatPage(parent)
    elseif key == "unitframes" and UI.Pages.CreateUnitFramesPage then
        return UI.Pages.CreateUnitFramesPage(parent)
    elseif key == "macros" and UI.Pages.CreateMacrosPage then
        return UI.Pages.CreateMacrosPage(parent)
    elseif key == "mounts" and UI.Pages.CreateMountsPage then
        return UI.Pages.CreateMountsPage(parent)
    elseif key == "loot" and UI.Pages.CreateLootPage then
        return UI.Pages.CreateLootPage(parent)
    elseif key == "quests" and UI.Pages.CreateQuestsPage then
        return UI.Pages.CreateQuestsPage(parent)
    elseif key == "about" and UI.Pages.CreateAboutPage then
        return UI.Pages.CreateAboutPage(parent)
    end

    local page = UI.CreatePageFrame(parent)
    return page
end

local function SetButtonSelected(button, selected)
    if button.SetStyledSelected then
        button:SetStyledSelected(selected)
    end

    if button.selectionBar then
        button.selectionBar:SetShown(selected == true)
    end

    if button.iconBack then
        if selected then
            button.iconBack:SetBackdropColor(0.30, 0.22, 0.08, 0.95)
            button.iconBack:SetBackdropBorderColor(1, 0.82, 0.25, 0.78)
        else
            button.iconBack:SetBackdropColor(0.045, 0.050, 0.060, 0.85)
            button.iconBack:SetBackdropBorderColor(0.70, 0.56, 0.30, 0.36)
        end
    end
end

local function ShowPage(pageKey)
    UI.currentPage = pageKey
    local pageInfo = pageInfoByKey[pageKey]

    if UI.frame and pageInfo then
        UI.frame.pageTitle:SetText(pageInfo.label)
        UI.frame.pageDescription:SetText(pageInfo.description or "")
        RefreshHeaderStatus(UI.frame)
    end

    for key, page in pairs(pages) do
        page:SetShown(key == pageKey)

        if key == pageKey and page.Refresh then
            page:Refresh()
        end
    end

    for key, button in pairs(buttons) do
        SetButtonSelected(button, key == pageKey)
    end
end

function UI.RefreshVisiblePage()
    local page = UI.currentPage and pages[UI.currentPage]

    if page and page.Refresh then
        page:Refresh()
    end
end

local function CreateSidebarButton(parent, info, yOffset)
    local label = info.label
    local key = info.key
    local button = UI.CreateButton(parent.sidebar, label, SIDEBAR_WIDTH - 18, SIDEBAR_BUTTON_HEIGHT)
    button:SetPoint("TOPLEFT", parent.sidebar, "TOPLEFT", 9, yOffset)
    button:SetStyledTextAlign("LEFT")
    button:SetStyledTextInset(35)

    button.selectionBar = button:CreateTexture(nil, "OVERLAY")
    button.selectionBar:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -4)
    button.selectionBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 4)
    button.selectionBar:SetWidth(2)
    button.selectionBar:SetColorTexture(1, 0.76, 0.18, 0.92)
    button.selectionBar:Hide()

    button.iconBack = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.iconBack:SetPoint("LEFT", button, "LEFT", 9, 0)
    button.iconBack:SetSize(18, 18)
    Theme.ApplySoftBackdrop(button.iconBack, 0.9)

    button.iconText = button.iconBack:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.iconText:SetPoint("CENTER", button.iconBack, "CENTER", 0, 0)
    button.iconText:SetText(info.icon or string.sub(label, 1, 1))
    button.iconText:SetTextColor(0.95, 0.72, 0.28)

    button:SetScript("OnClick", function()
        ShowPage(key)
    end)

    buttons[key] = button
    SetButtonSelected(button, false)

    return button
end

local function CreateSidebarGroupLabel(parent, text, yOffset)
    local label = parent.sidebar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", parent.sidebar, "TOPLEFT", 11, yOffset)
    label:SetText(text)
    label:SetTextColor(0.66, 0.62, 0.52)
    label:SetJustifyH("LEFT")

    local line = parent.sidebar:CreateTexture(nil, "ARTWORK")
    line:SetPoint("LEFT", label, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", parent.sidebar, "RIGHT", -11, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.95, 0.72, 0.28, 0.13)

    return label
end

local function BuildPages(frame)
    for _, page in pairs(pages) do
        page:Hide()
        page:SetParent(nil)
    end

    wipe(pages)
    wipe(UI.SearchEntries)

    for _, info in ipairs(pageOrder) do
        UI.BuildingPageKey = info.key
        pages[info.key] = CreatePage(frame, info.key)
        UI.BuildingPageKey = nil
        UI.SearchEntries[#UI.SearchEntries + 1] = {
            pageKey = info.key,
            control = pages[info.key],
            label = info.label .. " settings",
            tooltip = info.description or "",
            pageEntry = true,
        }
    end

    RefreshScrollIndicator(UI.frame, pages[pageKey])
end

local function CreateTitleBadge(frame)
    local badge = CreateFrame("Frame", nil, frame)
    badge:SetSize(TITLE_BADGE_SIZE, TITLE_BADGE_SIZE)
    badge:SetPoint("CENTER", frame, "TOPLEFT", 8, -8)
    badge:SetFrameLevel(frame:GetFrameLevel() + 8)

    badge.shadow = badge:CreateTexture(nil, "BACKGROUND")
    badge.shadow:SetPoint("CENTER", 1, -1)
    badge.shadow:SetSize(TITLE_BADGE_ICON_SIZE + 4, TITLE_BADGE_ICON_SIZE + 4)
    badge.shadow:SetTexture("Interface\\Buttons\\WHITE8x8")
    badge.shadow:SetVertexColor(0, 0, 0, 0.34)

    badge.backing = badge:CreateTexture(nil, "BORDER")
    badge.backing:SetPoint("CENTER")
    badge.backing:SetSize(TITLE_BADGE_ICON_SIZE + 7, TITLE_BADGE_ICON_SIZE + 7)
    badge.backing:SetTexture("Interface\\Buttons\\WHITE8x8")
    badge.backing:SetVertexColor(0.82, 0.60, 0.16, 1)

    badge.innerBacking = badge:CreateTexture(nil, "BORDER", nil, 1)
    badge.innerBacking:SetPoint("CENTER")
    badge.innerBacking:SetSize(TITLE_BADGE_ICON_SIZE + 3, TITLE_BADGE_ICON_SIZE + 3)
    badge.innerBacking:SetTexture("Interface\\Buttons\\WHITE8x8")
    badge.innerBacking:SetVertexColor(0.025, 0.028, 0.034, 1)

    badge.icon = badge:CreateTexture(nil, "ARTWORK")
    badge.icon:SetPoint("CENTER")
    badge.icon:SetSize(TITLE_BADGE_ICON_SIZE, TITLE_BADGE_ICON_SIZE)
    badge.icon:SetTexture(Theme.icon)
    badge.icon:SetTexCoord(0.20, 0.80, 0.16, 0.74)

    if type(badge.icon.AddMaskTexture) == "function" and type(badge.CreateMaskTexture) == "function" then
        badge.mask = badge:CreateMaskTexture()
        badge.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        badge.mask:SetAllPoints(badge.icon)
        badge.icon:AddMaskTexture(badge.mask)

        badge.backingMask = badge:CreateMaskTexture()
        badge.backingMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        badge.backingMask:SetAllPoints(badge.backing)

        if type(badge.backing.AddMaskTexture) == "function" then
            badge.backing:AddMaskTexture(badge.backingMask)
        end

        badge.innerBackingMask = badge:CreateMaskTexture()
        badge.innerBackingMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        badge.innerBackingMask:SetAllPoints(badge.innerBacking)

        if type(badge.innerBacking.AddMaskTexture) == "function" then
            badge.innerBacking:AddMaskTexture(badge.innerBackingMask)
        end

        badge.shadowMask = badge:CreateMaskTexture()
        badge.shadowMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        badge.shadowMask:SetAllPoints(badge.shadow)

        if type(badge.shadow.AddMaskTexture) == "function" then
            badge.shadow:AddMaskTexture(badge.shadowMask)
        end
    end

    frame.titleBadge = badge
end

local function CreateBrandPlate(frame)
    local plate = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    plate:SetPoint("TOPLEFT", frame, "TOPLEFT", OUTER_MARGIN, -56)
    plate:SetSize(SIDEBAR_WIDTH, 48)
    plate:SetBackdrop({
        bgFile = Theme.panelBg,
        edgeFile = Theme.panelBorder,
        tile = true,
        tileSize = 16,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    plate:SetBackdropColor(0.025, 0.022, 0.016, 0.96)
    plate:SetBackdropBorderColor(0.92, 0.74, 0.24, 0.48)

    plate.topLine = plate:CreateTexture(nil, "ARTWORK")
    plate.topLine:SetPoint("TOPLEFT", 18, -7)
    plate.topLine:SetPoint("TOPRIGHT", -18, -7)
    plate.topLine:SetHeight(1)
    plate.topLine:SetColorTexture(1, 0.82, 0.22, 0.28)

    plate.bottomLine = plate:CreateTexture(nil, "ARTWORK")
    plate.bottomLine:SetPoint("BOTTOMLEFT", 18, 7)
    plate.bottomLine:SetPoint("BOTTOMRIGHT", -18, 7)
    plate.bottomLine:SetHeight(1)
    plate.bottomLine:SetColorTexture(1, 0.82, 0.22, 0.22)

    plate.title = plate:CreateFontString(nil, "OVERLAY")
    plate.title:SetPoint("CENTER", 0, 0)
    plate.title:SetFont("Fonts\\MORPHEUS.TTF", 24, "OUTLINE")
    plate.title:SetTextColor(1, 0.82, 0.08)
    plate.title:SetShadowColor(0, 0, 0, 0.95)
    plate.title:SetShadowOffset(1, -1)
    plate.title:SetText("ZoidsTools")

    frame.logoPlate = plate
end

local function CreateStatusPill(parent, width)
    local pill = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pill:SetSize(width or 132, 24)
    Theme.ApplySoftBackdrop(pill, 0.68)

    pill.text = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pill.text:SetPoint("LEFT", pill, "LEFT", 10, 0)
    pill.text:SetPoint("RIGHT", pill, "RIGHT", -10, 0)
    pill.text:SetJustifyH("CENTER")
    pill.text:SetTextColor(0.86, 0.84, 0.76)

    return pill
end

local function GetPlayerDisplayText()
    local playerName = UnitName and UnitName("player") or "Player"
    local classFile

    if UnitClass then
        _, classFile = UnitClass("player")
    end

    return tostring(playerName or "Player"), classFile
end

local function GetSpecDisplayText()
    if not GetSpecialization or not GetSpecializationInfo then
        return "No Spec"
    end

    local specIndex = GetSpecialization()

    if not specIndex then
        return "No Spec"
    end

    local _, specName = GetSpecializationInfo(specIndex)

    return specName or "No Spec"
end

RefreshHeaderStatus = function(frame)
    if not frame or not frame.statusPlayer then
        return
    end

    local playerName, classFile = GetPlayerDisplayText()
    local classColor = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]

    frame.statusPlayer.text:SetText(playerName)

    if classColor then
        frame.statusPlayer.text:SetTextColor(classColor.r or 1, classColor.g or 1, classColor.b or 1)
    else
        frame.statusPlayer.text:SetTextColor(0.86, 0.84, 0.76)
    end

    frame.statusSpec.text:SetText(GetSpecDisplayText())

    if InCombatLockdown and InCombatLockdown() then
        frame.statusCombat.text:SetText("Combat Locked")
        frame.statusCombat.text:SetTextColor(0.95, 0.34, 0.26)
        frame.statusCombat:SetBackdropBorderColor(0.95, 0.30, 0.24, 0.45)
    else
        frame.statusCombat.text:SetText("Ready")
        frame.statusCombat.text:SetTextColor(0.42, 0.95, 0.52)
        frame.statusCombat:SetBackdropBorderColor(0.42, 0.95, 0.52, 0.30)
    end
end

local function CreateHeaderStatus(frame)
    frame.statusStrip = CreateFrame("Frame", nil, frame.pageHeader)
    frame.statusStrip:SetPoint("TOPRIGHT", frame.pageHeader, "TOPRIGHT", 0, -1)
    frame.statusStrip:SetSize(420, 24)

    frame.statusCombat = CreateStatusPill(frame.statusStrip, 116)
    frame.statusCombat:SetPoint("RIGHT", frame.statusStrip, "RIGHT", 0, 0)

    frame.statusSpec = CreateStatusPill(frame.statusStrip, 126)
    frame.statusSpec:SetPoint("RIGHT", frame.statusCombat, "LEFT", -8, 0)

    frame.statusPlayer = CreateStatusPill(frame.statusStrip, 152)
    frame.statusPlayer:SetPoint("RIGHT", frame.statusSpec, "LEFT", -8, 0)

    RefreshHeaderStatus(frame)
end

local function RegisterHeaderStatusEvents(frame)
    if frame.statusEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function()
        RefreshHeaderStatus(frame)
    end)

    frame.statusEventFrame = eventFrame
end

local function NormalizeSearchText(value)
    return string.lower(tostring(value or "")):gsub("[%p%s]+", " "):match("^%s*(.-)%s*$")
end

local function ScoreSearchEntry(entry, query)
    local label = NormalizeSearchText(entry.label)
    local tooltip = NormalizeSearchText(entry.tooltip)
    local pageInfo = pageInfoByKey[entry.pageKey]
    local page = NormalizeSearchText(pageInfo and (pageInfo.label .. " " .. (pageInfo.description or "")) or "")

    if label == query then return 100 end
    if label:sub(1, #query) == query then return 80 end
    if label:find(query, 1, true) then return 60 end
    if tooltip:find(query, 1, true) then return 35 end
    if page:find(query, 1, true) then return 20 end
    return 0
end

local searchHighlightToken = 0

local function HighlightSearchControl(frame, control)
    if not frame or not control then return end
    if not frame.searchHighlight then
        local highlight = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        highlight:SetFrameStrata("DIALOG")
        highlight:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        highlight:SetBackdropBorderColor(1, 0.78, 0.18, 0.95)
        highlight:Hide()
        frame.searchHighlight = highlight
    end

    local highlight = frame.searchHighlight
    highlight:ClearAllPoints()
    highlight:SetPoint("TOPLEFT", control, "TOPLEFT", -8, 7)
    highlight:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", 8, -7)
    highlight:SetFrameLevel((control:GetFrameLevel() or 1) + 20)
    highlight:Show()
    searchHighlightToken = searchHighlightToken + 1
    local token = searchHighlightToken
    if C_Timer and C_Timer.After then
        C_Timer.After(1.8, function()
            if token == searchHighlightToken then highlight:Hide() end
        end)
    end
end

local function CreateSettingsSearch(frame)
    local search = CreateFrame("EditBox", nil, frame.pageHeader, "BackdropTemplate")
    search:SetSize(360, 30)
    search:SetPoint("TOPRIGHT", frame.pageHeader, "TOPRIGHT", 0, -31)
    search:SetAutoFocus(false)
    search:SetMaxLetters(80)
    search:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
    search:SetTextInsets(30, 34, 0, 0)
    search:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme.panelBorder,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    search:SetBackdropColor(0.008, 0.010, 0.014, 0.98)
    search:SetBackdropBorderColor(0.90, 0.68, 0.24, 0.66)

    search.icon = search:CreateTexture(nil, "OVERLAY")
    search.icon:SetPoint("LEFT", search, "LEFT", 9, 0)
    search.icon:SetSize(16, 16)
    search.icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    search.icon:SetVertexColor(0.95, 0.72, 0.28)

    search.placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    search.placeholder:SetPoint("LEFT", search, "LEFT", 31, 0)
    search.placeholder:SetText("Search all ZoidsTools settings...")

    search.clear = CreateFrame("Button", nil, search)
    search.clear:SetSize(26, 26)
    search.clear:SetPoint("RIGHT", search, "RIGHT", -4, 0)
    search.clear.text = search.clear:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    search.clear.text:SetPoint("CENTER", 0, 0)
    search.clear.text:SetText("x")
    search.clear.text:SetTextColor(0.78, 0.74, 0.66)
    search.clear:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.82, 0.18) end)
    search.clear:SetScript("OnLeave", function(self) self.text:SetTextColor(0.78, 0.74, 0.66) end)
    search.clear:SetScript("OnClick", function()
        search:SetText("")
        search:SetFocus()
    end)
    search.clear:Hide()

    local results = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    results:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 0, -3)
    results:SetSize(360, 40)
    results:SetFrameStrata("FULLSCREEN_DIALOG")
    results:SetFrameLevel(250)
    results:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = Theme.panelBorder,
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    results:SetBackdropColor(0.008, 0.010, 0.014, 0.99)
    results:SetBackdropBorderColor(0.85, 0.66, 0.28, 0.72)
    results:Hide()
    results.rows = {}
    results.matches = {}

    for index = 1, 8 do
        local row = CreateFrame("Button", nil, results)
        row:SetPoint("TOPLEFT", 7, -7 - ((index - 1) * 34))
        row:SetPoint("RIGHT", -7, 0)
        row:SetHeight(34)
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 0.78, 0.18, 0.09)
        row.highlight:Hide()
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", 10, 5)
        row.label:SetPoint("RIGHT", -10, 5)
        row.label:SetJustifyH("LEFT")
        row.page = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.page:SetPoint("LEFT", 10, -9)
        row.page:SetPoint("RIGHT", -10, -9)
        row.page:SetJustifyH("LEFT")
        row:SetScript("OnEnter", function(self) self.highlight:Show() end)
        row:SetScript("OnLeave", function(self) self.highlight:Hide() end)
        row:SetScript("OnClick", function()
            local entry = results.matches[index]
            if not entry then return end
            ShowPage(entry.pageKey)
            results:Hide()
            search:ClearFocus()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    UI.ScrollControlIntoView(entry.control)
                    HighlightSearchControl(frame, entry.control)
                end)
            else
                UI.ScrollControlIntoView(entry.control)
                HighlightSearchControl(frame, entry.control)
            end
        end)
        results.rows[index] = row
    end

    local function RefreshResults()
        local query = NormalizeSearchText(search:GetText())
        search.placeholder:SetShown(query == "")
        search.clear:SetShown(query ~= "")
        wipe(results.matches)
        if #query < 2 then results:Hide() return end

        local scored = {}
        for _, entry in ipairs(UI.SearchEntries) do
            local score = ScoreSearchEntry(entry, query)
            if score > 0 then scored[#scored + 1] = { entry = entry, score = score } end
        end
        table.sort(scored, function(a, b)
            if a.score == b.score then return a.entry.label < b.entry.label end
            return a.score > b.score
        end)

        local count = math.min(8, #scored)
        for index, row in ipairs(results.rows) do
            local match = scored[index] and scored[index].entry
            results.matches[index] = match
            row:SetShown(match ~= nil)
            if match then
                row.label:SetText(match.label)
                row.page:SetText((pageInfoByKey[match.pageKey] and pageInfoByKey[match.pageKey].label or match.pageKey) .. "  >  setting")
            end
        end
        if count > 0 then
            results:SetHeight((count * 34) + 14)
            results:Show()
        else
            results:Hide()
        end
    end

    search:SetScript("OnTextChanged", RefreshResults)
    search:SetScript("OnEnterPressed", function()
        if results.rows[1]:IsShown() then results.rows[1]:Click() else search:ClearFocus() end
    end)
    search:SetScript("OnEscapePressed", function()
        if search:GetText() ~= "" then search:SetText("") else search:ClearFocus() end
        results:Hide()
    end)
    search:SetScript("OnEditFocusGained", function()
        search:SetBackdropBorderColor(1, 0.80, 0.20, 0.95)
        RefreshResults()
    end)
    search:SetScript("OnEditFocusLost", function()
        search:SetBackdropBorderColor(0.90, 0.68, 0.24, 0.66)
    end)
    frame.settingsSearch = search
    frame.searchResults = results
end

local function CreateMainWindow()
    if UI.frame then
        return UI.frame
    end

    local frame = CreateFrame("Frame", "ZoidsToolsMainWindow", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveMainWindowPosition(self)
    end)
    frame:Hide()

    table.insert(UISpecialFrames, "ZoidsToolsMainWindow")

    frame.TitleText:SetText("ZoidsTools")
    frame.TitleText:SetFontObject(GameFontNormal)
    frame.TitleText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    frame.TitleText:SetTextColor(1, 0.82, 0)

    frame.TitleText:ClearAllPoints()
    frame.TitleText:SetPoint("TOP", frame, "TOP", 0, -5)
    frame.TitleText:SetWidth(WINDOW_WIDTH - 160)
    frame.TitleText:SetJustifyH("CENTER")

    CreateTitleBadge(frame)
    frame.sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", OUTER_MARGIN, SIDEBAR_TOP)
    frame.sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", OUTER_MARGIN, CONTENT_BOTTOM)
    frame.sidebar:SetWidth(SIDEBAR_WIDTH)
    Theme.ApplySurfaceBackdrop(frame.sidebar, 0.88)

    frame.pageHeader = CreateFrame("Frame", nil, frame)
    frame.pageHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT, HEADER_TOP)
    frame.pageHeader:SetPoint("TOPRIGHT", frame, "TOPRIGHT", CONTENT_RIGHT, HEADER_TOP)
    frame.pageHeader:SetHeight(62)

    frame.pageTitle = frame.pageHeader:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.pageTitle:SetPoint("TOPLEFT", 0, 0)
    frame.pageTitle:SetPoint("RIGHT", frame.pageHeader, "RIGHT", -378, 0)
    frame.pageTitle:SetTextColor(1, 0.82, 0)
    frame.pageTitle:SetJustifyH("LEFT")
    frame.pageTitle:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 18, "OUTLINE")

    frame.pageDescription = frame.pageHeader:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.pageDescription:SetPoint("TOPLEFT", frame.pageTitle, "BOTTOMLEFT", 0, -5)
    frame.pageDescription:SetPoint("RIGHT", frame.pageHeader, "RIGHT", -378, 0)
    frame.pageDescription:SetJustifyH("LEFT")
    frame.pageDescription:SetTextColor(0.86, 0.82, 0.72)

    frame.pageHeader.divider = frame.pageHeader:CreateTexture(nil, "ARTWORK")
    frame.pageHeader.divider:SetPoint("BOTTOMLEFT", frame.pageHeader, "BOTTOMLEFT", 0, 0)
    frame.pageHeader.divider:SetPoint("BOTTOMRIGHT", frame.pageHeader, "BOTTOMRIGHT", 0, 0)
    frame.pageHeader.divider:SetHeight(1)
    frame.pageHeader.divider:SetColorTexture(0.95, 0.72, 0.28, 0.16)

    CreateSettingsSearch(frame)

    frame.contentPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.contentPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT, CONTENT_TOP)
    frame.contentPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", CONTENT_RIGHT, CONTENT_BOTTOM)
    Theme.ApplySurfaceBackdrop(frame.contentPanel, 0.90)
    if frame.contentPanel.SetClipsChildren then
        frame.contentPanel:SetClipsChildren(true)
    end
    frame.contentPanel:EnableMouseWheel(true)
    frame.contentPanel:SetScript("OnMouseWheel", function(_, delta)
        UI.ScrollCurrentPage(delta)
    end)

    frame.scrollIndicator = frame.contentPanel:CreateTexture(nil, "OVERLAY")
    frame.scrollIndicator:SetWidth(3)
    frame.scrollIndicator:SetColorTexture(0.82, 0.62, 0.22, 0.72)
    frame.scrollIndicator:Hide()

    frame.contentPanel.topLine = frame.contentPanel:CreateTexture(nil, "ARTWORK")
    frame.contentPanel.topLine:SetPoint("TOPLEFT", frame.contentPanel, "TOPLEFT", 18, -6)
    frame.contentPanel.topLine:SetPoint("TOPRIGHT", frame.contentPanel, "TOPRIGHT", -18, -6)
    frame.contentPanel.topLine:SetHeight(1)
    frame.contentPanel.topLine:SetColorTexture(0.95, 0.72, 0.28, 0.18)

    UI.frame = frame

    local currentGroup
    local yOffset = -16

    for _, info in ipairs(pageOrder) do
        if info.group ~= currentGroup then
            currentGroup = info.group
            CreateSidebarGroupLabel(frame, currentGroup, yOffset)
            yOffset = yOffset - 17
        end

        CreateSidebarButton(frame, info, yOffset)
        yOffset = yOffset - SIDEBAR_BUTTON_SPACING
    end

    BuildPages(frame)
    RestoreMainWindowPosition(frame)
    ShowPage(UI.currentPage or "general")

    return frame
end

function UI.Show(pageKey)
    local frame = CreateMainWindow()
    frame:Raise()
    frame:Show()
    ShowPage(pageKey or UI.currentPage or "general")
end

function UI.Toggle(pageKey)
    local frame = CreateMainWindow()

    if frame:IsShown() and (not pageKey or UI.currentPage == pageKey) then
        frame:Hide()
    else
        frame:Raise()
        frame:Show()
        ShowPage(pageKey or UI.currentPage or "general")
    end
end

function UI.Initialize()
    -- Build the settings window only when the player opens /zt.
end
