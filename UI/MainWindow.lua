local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

local UI = ns.UI
local Theme = UI.Theme
local pages = {}
local buttons = {}

local WINDOW_WIDTH = 1020
local WINDOW_HEIGHT = 720
local OUTER_MARGIN = 16
local SIDEBAR_WIDTH = 206
local SIDEBAR_TOP = -104
local SIDEBAR_BUTTON_HEIGHT = 31
local SIDEBAR_BUTTON_SPACING = 34
local SIDEBAR_BUTTON_TOP = -42
local CONTENT_LEFT = OUTER_MARGIN + SIDEBAR_WIDTH + 18
local HEADER_TOP = -52
local CONTENT_TOP = SIDEBAR_TOP
local CONTENT_RIGHT = -16
local CONTENT_BOTTOM = 24
local TITLE_BADGE_SIZE = 68
local TITLE_BADGE_ICON_SIZE = 54

local pageOrder = {
    { key = "general", label = "General", description = "Core ZoidsTools settings." },
    { key = "tooltips", label = "Tooltips", description = "Unit tooltip appearance and player detail settings." },
    { key = "windows", label = "Windows", description = "Move Blizzard UI windows and default bags." },
    { key = "items", label = "Items", description = "Item level, gem, enchant, and binding overlays." },
    { key = "professions", label = "Professions", description = "Molinari-style profession actions for hovered bag items." },
    { key = "builds", label = "Grimoire", description = "Talent build suggestions from generated local data." },
    { key = "combat", label = "Combat", description = "Combat quality-of-life settings." },
    { key = "unitframes", label = "Unit Frames", description = "Blizzard unit frame health, castbar, and aura settings." },
    { key = "macros", label = "Macros", description = "Health, mana, and consumable macro settings." },
    { key = "mounts", label = "Mounts", description = "Smart random mount and service mount settings." },
    { key = "loot", label = "Loot", description = "Looting quality-of-life settings." },
    { key = "quests", label = "Quests", description = "Quest and gossip automation settings." },
    { key = "about", label = "About", description = "Version and command information." },
}
local pageInfoByKey = {}

for _, info in ipairs(pageOrder) do
    pageInfoByKey[info.key] = info
end

function UI.CreatePageFrame(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent.contentPanel, "TOPLEFT", 20, -18)
    frame:SetPoint("BOTTOMRIGHT", parent.contentPanel, "BOTTOMRIGHT", -20, 18)
    frame:Hide()
    return frame
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
end

local function ShowPage(pageKey)
    UI.currentPage = pageKey
    local pageInfo = pageInfoByKey[pageKey]

    if UI.frame and pageInfo then
        UI.frame.pageTitle:SetText(pageInfo.label)
        UI.frame.pageDescription:SetText(pageInfo.description or "")
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

local function CreateSidebarButton(parent, label, key, index)
    local button = UI.CreateButton(parent.sidebar, label, SIDEBAR_WIDTH - 28, SIDEBAR_BUTTON_HEIGHT)
    button:SetPoint("TOPLEFT", parent.sidebar, "TOPLEFT", 14, SIDEBAR_BUTTON_TOP - ((index - 1) * SIDEBAR_BUTTON_SPACING))
    button:SetStyledTextAlign("LEFT")

    button:SetScript("OnClick", function()
        ShowPage(key)
    end)

    buttons[key] = button
    SetButtonSelected(button, false)

    return button
end

local function BuildPages(frame)
    for _, page in pairs(pages) do
        page:Hide()
        page:SetParent(nil)
    end

    wipe(pages)

    for _, info in ipairs(pageOrder) do
        pages[info.key] = CreatePage(frame, info.key)
    end
end

local function CreateTitleBadge(frame)
    local badge = CreateFrame("Frame", nil, frame)
    badge:SetSize(TITLE_BADGE_SIZE, TITLE_BADGE_SIZE)
    badge:SetPoint("CENTER", frame, "TOPLEFT", 25, -19)
    badge:SetFrameLevel(frame:GetFrameLevel() + 8)

    badge.shadow = badge:CreateTexture(nil, "BACKGROUND")
    badge.shadow:SetPoint("CENTER", 1, -1)
    badge.shadow:SetSize(TITLE_BADGE_ICON_SIZE + 4, TITLE_BADGE_ICON_SIZE + 4)
    badge.shadow:SetTexture("Interface\\Buttons\\WHITE8x8")
    badge.shadow:SetVertexColor(0, 0, 0, 0.34)

    badge.backing = badge:CreateTexture(nil, "BORDER")
    badge.backing:SetPoint("CENTER")
    badge.backing:SetSize(TITLE_BADGE_ICON_SIZE + 2, TITLE_BADGE_ICON_SIZE + 2)
    badge.backing:SetTexture("Interface\\Buttons\\WHITE8x8")
    badge.backing:SetVertexColor(0.075, 0.068, 0.052, 1)

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

local function CreateMainWindow()
    if UI.frame then
        return UI.frame
    end

    local frame = CreateFrame("Frame", "ZoidsToolsMainWindow", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
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
    frame.TitleText:SetWidth(WINDOW_WIDTH - 140)
    frame.TitleText:SetJustifyH("CENTER")

    CreateTitleBadge(frame)
    CreateBrandPlate(frame)

    frame.sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", OUTER_MARGIN, SIDEBAR_TOP)
    frame.sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", OUTER_MARGIN, CONTENT_BOTTOM)
    frame.sidebar:SetWidth(SIDEBAR_WIDTH)
    frame.sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame.sidebar:SetBackdropColor(0.02, 0.025, 0.035, 0.62)
    frame.sidebar:SetBackdropBorderColor(0.85, 0.7, 0.38, 0.38)

    local navTitle = frame.sidebar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    navTitle:SetPoint("TOPLEFT", frame.sidebar, "TOPLEFT", 16, -18)
    navTitle:SetText("Tools")

    frame.pageHeader = CreateFrame("Frame", nil, frame)
    frame.pageHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT, HEADER_TOP)
    frame.pageHeader:SetPoint("TOPRIGHT", frame, "TOPRIGHT", CONTENT_RIGHT, HEADER_TOP)
    frame.pageHeader:SetHeight(48)

    frame.pageTitle = frame.pageHeader:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.pageTitle:SetPoint("TOPLEFT", 0, 0)
    frame.pageTitle:SetTextColor(1, 0.82, 0)
    frame.pageTitle:SetJustifyH("LEFT")

    frame.pageDescription = frame.pageHeader:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.pageDescription:SetPoint("TOPLEFT", frame.pageTitle, "BOTTOMLEFT", 0, -8)
    frame.pageDescription:SetPoint("RIGHT", frame.pageHeader, "RIGHT", 0, 0)
    frame.pageDescription:SetJustifyH("LEFT")
    frame.pageDescription:SetTextColor(0.86, 0.82, 0.72)

    frame.contentPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.contentPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT, CONTENT_TOP)
    frame.contentPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", CONTENT_RIGHT, CONTENT_BOTTOM)
    Theme.ApplyPanelBackdrop(frame.contentPanel, 0.9)

    UI.frame = frame

    for index, info in ipairs(pageOrder) do
        CreateSidebarButton(frame, info.label, info.key, index)
    end

    BuildPages(frame)
    RestoreMainWindowPosition(frame)
    ShowPage(UI.currentPage or "general")

    return frame
end

function UI.Show(pageKey)
    local frame = CreateMainWindow()
    frame:Show()
    ShowPage(pageKey or UI.currentPage or "general")
end

function UI.Toggle(pageKey)
    local frame = CreateMainWindow()

    if frame:IsShown() and (not pageKey or UI.currentPage == pageKey) then
        frame:Hide()
    else
        frame:Show()
        ShowPage(pageKey or UI.currentPage or "general")
    end
end

function UI.Initialize()
    CreateMainWindow()
end
