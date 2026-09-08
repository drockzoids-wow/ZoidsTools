local _, ns = ...

ns.UI2 = ns.UI2 or {}

local UI2 = ns.UI2
local Theme = ns.UI and ns.UI.Theme

local WINDOW_WIDTH = 1060
local WINDOW_HEIGHT = 650
local SIDEBAR_WIDTH = 220
local PADDING = 18
local TOP_HEIGHT = 86
local ROW_HEIGHT = 44

local pages = {
    inventory = { key = "inventory", label = "Item Search", icon = "I", page = "inventory", sectionKey = "warband", description = "Search saved item counts and locations across character bags, equipment, banks, and the Warband bank." },
    overview = { key = "overview", label = "Overview", icon = "ZT", page = nil, sectionKey = "overview", description = "Status, quick actions, and common ZoidsTools areas." },
    warband = { key = "warband", label = "Warband Weekly", icon = "WB", page = "warband", sectionKey = "warband", description = "Account-wide Mythic+, Great Vault, keystone, and current-expansion lockout snapshots." },
    professionweekly = { key = "professionweekly", label = "Weekly Goals", icon = "WK", page = "professionweekly", sectionKey = "profession_area", description = "Popular weekly goals, Great Vault progress, and Midnight profession Knowledge." },
    minimap = { key = "minimap", label = "Minimap", icon = "N", page = "general", sectionKey = "core", description = "Minimap shape, title bar, addon buttons, and expansion button tools." },
    general = { key = "general", label = "Interface", icon = "G", page = "general", sectionKey = "core", description = "Widgets, mailbox recipients, audio sync, Talking Head, and general interface tools." },
    tooltips = { key = "tooltips", label = "Tooltips", icon = "T", page = "tooltips", sectionKey = "core", description = "Class-colored player names, Mythic+ rating, and equipped item level." },
    windows = { key = "windows", label = "Windows", icon = "W", page = "windows", sectionKey = "core", description = "Move and scale Blizzard windows and default bag frames." },
    chat = { key = "chat", label = "Chat", icon = "H", page = "chat", sectionKey = "chat", description = "Chat copy, saved history, input styling, scrolling, and message awareness." },
    items = { key = "items", label = "Items", icon = "I", page = "items", sectionKey = "character", description = "Item level, gems, enchants, bind text, stat goals, and offline BiS rankings." },
    professions = { key = "professions", label = "Tools", icon = "P", page = "professions", sectionKey = "profession_area", description = "Molinari-style disenchant, mill, prospect, and lockbox helpers." },
    talents = { key = "talents", label = "Talents", icon = "B", page = "builds", sectionKey = "character", description = "Talent recommendations, source selection, and application helpers." },
    meters = { key = "meters", label = "Meters", icon = "M", page = "meters", sectionKey = "combat_area", description = "Custom damage meters and Blizzard meter profile tools." },
    combat = { key = "combat", label = "Combat", icon = "C", page = "combat", sectionKey = "combat_area", description = "Keybind text, skill flyouts, range tinting, missing buffs, and combat notifications." },
    unitframes = { key = "unitframes", label = "Unit Frames", icon = "U", page = "unitframes", sectionKey = "combat_area", description = "Blizzard unit frame health, castbar, and aura settings." },
    macros = { key = "macros", label = "Macros", icon = "A", page = "macros", sectionKey = "combat_area", description = "Health, mana, hearthstone, and consumable macro tools." },
    mounts = { key = "mounts", label = "Mounts", icon = "R", page = "mounts", sectionKey = "mounts", description = "Smart mount pools, class utilities, target matching, and rotation history." },
    loot = { key = "loot", label = "Loot", icon = "L", page = "loot", sectionKey = "automation", description = "Fast loot, safe sweep behavior, selling, repair, and vendor tools." },
    quests = { key = "quests", label = "Quests", icon = "Q", page = "quests", sectionKey = "automation", description = "Quest automation, filters, and smart quest item button." },
    tracker = { key = "tracker", label = "Tracker", icon = "T", page = "quests", sectionKey = "automation", description = "Objective tracker sizing, background, borders, text, and minimize behavior." },
    dialogs = { key = "dialogs", label = "Dialogs", icon = "D", page = "dialogs", sectionKey = "automation", description = "Auto-confirm selected Blizzard dialog prompts." },
}

local sections = {
    { key = "overview", label = "Overview", icon = "ZT", iconTexture = "Interface\\Icons\\INV_Misc_Map_01", defaultPageKey = "overview", tabs = { pages.overview } },
    { key = "warband", label = "Warband", icon = "WB", iconTexture = "Interface\\Icons\\INV_Misc_GroupLooking", defaultPageKey = "warband", tabs = { pages.warband, pages.inventory } },
    { key = "profession_area", label = "Weekly", icon = "WK", iconTexture = "Interface\\Icons\\INV_Misc_Note_06", defaultPageKey = "professionweekly", tabs = { pages.professionweekly, pages.professions } },
    { key = "core", label = "Core", icon = "UI", iconTexture = "Interface\\Icons\\INV_Misc_Gear_01", defaultPageKey = "minimap", tabs = { pages.minimap, pages.general, pages.tooltips, pages.windows } },
    { key = "character", label = "Character", icon = "CHAR", iconTexture = "Interface\\Icons\\INV_Misc_GroupLooking", defaultPageKey = "items", tabs = { pages.items, pages.talents } },
    { key = "chat", label = "Chat", icon = "CHAT", iconTexture = "Interface\\Icons\\INV_Letter_15", defaultPageKey = "chat", tabs = { pages.chat } },
    { key = "combat_area", label = "Combat", icon = "CBT", iconTexture = "Interface\\Icons\\Ability_DualWield", defaultPageKey = "meters", tabs = { pages.meters, pages.combat, pages.unitframes, pages.macros } },
    { key = "mounts", label = "Mounts", icon = "MNT", iconTexture = "Interface\\Icons\\Ability_Mount_RidingHorse", defaultPageKey = "mounts", tabs = { pages.mounts } },
    { key = "automation", label = "Automation", icon = "AUTO", iconTexture = "Interface\\Icons\\INV_Misc_Note_01", defaultPageKey = "loot", tabs = { pages.loot, pages.quests, pages.tracker, pages.dialogs } },
}

local pageByKey = pages
local pageAliases = {
    builds = "talents",
    build = "talents",
    tooltip = "tooltips",
    profession = "professionweekly",
    knowledge = "professionweekly",
    professiontracker = "professionweekly",
    goals = "professionweekly",
    ["weekly goals"] = "professionweekly",
    weeklygoals = "professionweekly",
    unitframe = "unitframes",
    frames = "unitframes",
    mount = "mounts",
    quest = "quests",
    dialog = "dialogs",
    meter = "meters",
    weekly = "warband",
    dashboard = "warband",
}

local sectionByKey = {}
for _, section in ipairs(sections) do
    sectionByKey[section.key] = section
end

local function ApplyBackdrop(frame, alpha)
    if Theme and Theme.ApplySoftBackdrop then
        Theme.ApplySoftBackdrop(frame, alpha)
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 7,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.02, 0.024, 0.032, alpha or 0.92)
    frame:SetBackdropBorderColor(0.25, 0.28, 0.33, 0.72)
end

local function GetClassColor()
    local classFile
    if UnitClass then
        _, classFile = UnitClass("player")
    end

    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then
        return color.r or 1, color.g or 0.82, color.b or 0
    end

    return 0.96, 0.72, 0.20
end

local function ReadDB(path, fallback)
    local value = ns.db
    for index = 1, #path do
        value = value and value[path[index]]
    end
    return value == nil and fallback or value
end

local function SavePosition(frame)
    if not ns.db or not ns.db.ui then return end
    ns.db.ui.modernWindow = ns.db.ui.modernWindow or {}
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then
        ns.db.ui.modernWindow.point = point
        ns.db.ui.modernWindow.relativePoint = relativePoint or point
        ns.db.ui.modernWindow.x = x or 0
        ns.db.ui.modernWindow.y = y or 0
    end
end

local function RestorePosition(frame)
    local saved = ns.db and ns.db.ui and ns.db.ui.modernWindow
    frame:ClearAllPoints()
    if saved and saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    else
        frame:SetPoint("CENTER")
    end
end

local function CreateButton(parent, text, width, height)
    if ns.UI and ns.UI.CreateButton then
        return ns.UI.CreateButton(parent, text, width, height)
    end

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, height or 26)
    button:SetText(text)
    return button
end

local function SetButtonSelected(button, selected)
    button.selected = selected == true
    if button.SetStyledSelected then
        button:SetStyledSelected(button.selected)
    elseif button.backdrop then
        button.backdrop:SetColorTexture(button.selected and 0.18 or 0.05, button.selected and 0.13 or 0.055, button.selected and 0.05 or 0.065, 0.95)
    end
end

local function CreateNavButton(parent, info)
    local button = CreateButton(parent, info.label, SIDEBAR_WIDTH - 28, 48)
    button:SetStyledTextAlign("LEFT")
    button:SetStyledTextInset(68)

    local fontString = button:GetFontString()
    if fontString then
        fontString:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 17, "OUTLINE")
    end

    button.iconBox = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.iconBox:SetPoint("LEFT", button, "LEFT", 11, 0)
    button.iconBox:SetSize(44, 34)
    ApplyBackdrop(button.iconBox, 0.70)

    button.iconTexture = button.iconBox:CreateTexture(nil, "ARTWORK")
    button.iconTexture:SetPoint("CENTER")
    button.iconTexture:SetSize(24, 24)
    button.iconTexture:SetTexture(info.iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    button.iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.iconTexture:SetDesaturated(true)
    button.iconTexture:SetVertexColor(1, 0.78, 0.24, 0.92)

    return button
end

local function CreateStatusTile(parent, label, getter)
    local tile = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    tile:SetSize(186, 54)
    ApplyBackdrop(tile, 0.58)

    tile.label = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tile.label:SetPoint("TOPLEFT", tile, "TOPLEFT", 12, -10)
    tile.label:SetTextColor(0.66, 0.68, 0.70)
    tile.label:SetText(label)

    tile.value = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tile.value:SetPoint("TOPLEFT", tile.label, "BOTTOMLEFT", 0, -5)
    tile.value:SetPoint("RIGHT", tile, "RIGHT", -10, 0)
    tile.value:SetJustifyH("LEFT")

    function tile:Refresh()
        local text, enabled = getter()
        self.value:SetText(text)
        self.value:SetTextColor(enabled and 0.42 or 0.90, enabled and 0.92 or 0.68, enabled and 0.52 or 0.28)
    end

    return tile
end

local function CreateAreaRow(parent, title, description, pageKey)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(760, ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")
    ApplyBackdrop(row, 0.50)

    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -7)
    row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 7)
    row.accent:SetWidth(2)
    row.accent:SetColorTexture(0.96, 0.72, 0.20, 0.78)

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.title:SetPoint("LEFT", row, "LEFT", 20, 8)
    row.title:SetTextColor(1, 0.82, 0.18)
    row.title:SetText(title)

    row.description = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.description:SetPoint("LEFT", row, "LEFT", 20, -9)
    row.description:SetPoint("RIGHT", row, "RIGHT", -90, -9)
    row.description:SetJustifyH("LEFT")
    row.description:SetTextColor(0.76, 0.78, 0.76)
    row.description:SetText(description)

    row.open = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.open:SetPoint("RIGHT", row, "RIGHT", -18, 0)
    row.open:SetTextColor(0.96, 0.72, 0.20)
    row.open:SetText("Open ›")

    row:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.84, 0.64, 0.22, 0.82)
        self.accent:SetColorTexture(1, 0.82, 0.26, 1)
    end)

    row:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.28, 0.33, 0.58)
        self.accent:SetColorTexture(0.96, 0.72, 0.20, 0.78)
    end)

    row:SetScript("OnClick", function()
        if UI2 and UI2.Show then
            UI2.Show(pageKey)
        end
    end)

    return row
end

local function CreateSectionCard(parent, title, width, height)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width, height)
    ApplyBackdrop(card, 0.46)

    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
    card.title:SetTextColor(1, 0.82, 0.18)
    card.title:SetText(title)

    card.line = card:CreateTexture(nil, "ARTWORK")
    card.line:SetPoint("LEFT", card.title, "RIGHT", 10, 0)
    card.line:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    card.line:SetHeight(1)
    card.line:SetColorTexture(0.40, 0.42, 0.46, 0.34)

    return card
end

local function PlaceFirst(control, section, x, y)
    control:SetPoint("TOPLEFT", section, "TOPLEFT", x or 18, y or -42)
end

local function PlaceBelow(control, anchor, xOffset, gap)
    control:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset or 0, -(gap or 8))
end

local function NormalizeSearchText(value)
    return string.lower(tostring(value or "")):gsub("[%p%s]+", " "):match("^%s*(.-)%s*$")
end

local function ScoreSearchEntry(entry, query)
    local label = NormalizeSearchText(entry.label)
    local tooltip = NormalizeSearchText(entry.tooltip)
    local pageInfo = pageByKey[entry._modernPageKey or entry.pageKey]
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

local function CreateModernPage(parent, key, creator)
    local previous = ns.UI and ns.UI.BuildingPageKey
    local searchStart = ns.UI and ns.UI.SearchEntries and #ns.UI.SearchEntries or 0
    if ns.UI then
        ns.UI.BuildingPageKey = key
    end

    local page = creator(parent)

    if ns.UI then
        ns.UI.BuildingPageKey = previous
    end
    if page then
        page.ZTPageKey = key
    end
    if ns.UI and ns.UI.SearchEntries then
        for index = searchStart + 1, #ns.UI.SearchEntries do
            local entry = ns.UI.SearchEntries[index]
            if entry then
                entry.ZTModernSearch = true
                entry._modernPageKey = key
            end
        end
    end

    return page
end

local ShowPage

local function IsDescendantOf(frame, ancestor)
    local current = frame
    while current do
        if current == ancestor then
            return true
        end
        current = current.GetParent and current:GetParent() or nil
    end
    return false
end

local WARBAND_COLUMNS = {
    { key = "character", label = "CHARACTER", width = 186, align = "LEFT" },
    { key = "itemLevel", label = "ILVL", width = 52, align = "CENTER" },
    { key = "rating", label = "M+", width = 58, align = "CENTER" },
    { key = "best", label = "BEST", width = 55, align = "CENTER" },
    { key = "keystone", label = "KEYSTONE", width = 122, align = "CENTER" },
    { key = "vault", label = "VAULT", width = 66, align = "CENTER" },
    { key = "saves", label = "SAVES", width = 58, align = "CENTER" },
    { key = "updated", label = "UPDATED", width = 94, align = "RIGHT" },
}

local PROFESSION_WEEKLY_COLUMNS = {
    { key = "profession", label = "PROFESSION", width = 190, align = "LEFT" },
    { key = "trainer", label = "TRAINER", width = 76, align = "CENTER" },
    { key = "treatise", label = "TREATISE", width = 76, align = "CENTER" },
    { key = "field", label = "DROPS", width = 92, align = "CENTER" },
    { key = "weekly", label = "WEEKLY KP", width = 92, align = "CENTER" },
    { key = "onetime", label = "ONE-TIME", width = 104, align = "CENTER" },
    { key = "catchup", label = "CATCH-UP", width = 112, align = "CENTER" },
}

local function WarbandNow()
    if type(GetServerTime) == "function" then
        local ok, value = pcall(GetServerTime)
        if ok and type(value) == "number" then
            return value
        end
    end
    if type(time) == "function" then
        local ok, value = pcall(time)
        if ok and type(value) == "number" then
            return value
        end
    end
    return 0
end

local function FormatWarbandDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end
    return string.format("%dm", math.max(1, minutes))
end

local function FormatWarbandAge(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp then
        return "Unknown"
    end

    local elapsed = math.max(0, WarbandNow() - timestamp)
    if elapsed < 60 then
        return "Now"
    elseif elapsed < 3600 then
        return string.format("%dm ago", math.floor(elapsed / 60))
    elseif elapsed < 86400 then
        return string.format("%dh ago", math.floor(elapsed / 3600))
    end
    return string.format("%dd ago", math.floor(elapsed / 86400))
end

local function FormatWarbandBest(level)
    level = tonumber(level)
    if not level then
        return "—"
    elseif level >= 2 then
        return "+" .. math.floor(level)
    elseif level == 0 then
        return "+0"
    elseif level == -1 then
        return "Heroic"
    end
    return "—"
end

local function GetWarbandClassColor(classFile)
    local colors = rawget(_G, "CUSTOM_CLASS_COLORS") or RAID_CLASS_COLORS
    local color = colors and classFile and colors[classFile]
    if color then
        return color.r or 1, color.g or 1, color.b or 1
    end
    return 0.92, 0.92, 0.92
end

local function GetVaultCategoryText(category)
    if type(category) ~= "table" or (tonumber(category.total) or 0) <= 0 then
        return "Not available"
    end

    local detail = string.format("%d/%d slots", tonumber(category.unlocked) or 0, tonumber(category.total) or 0)
    for _, slot in ipairs(category.slots or {}) do
        if not slot.unlocked then
            detail = detail .. string.format("  •  Next %d/%d", tonumber(slot.progress) or 0, tonumber(slot.threshold) or 0)
            break
        end
    end
    return detail
end

local function ShowWarbandCharacterTooltip(row)
    local info = row and row.info
    if not info or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local r, g, b = GetWarbandClassColor(info.classFile)
    GameTooltip:SetText(tostring(info.name or "Unknown"), r, g, b)
    GameTooltip:AddLine(string.format("%s  •  Level %d %s", tostring(info.realm or "Unknown Realm"), tonumber(info.level) or 0, tostring(info.specialization or info.className or "")), 0.72, 0.72, 0.75)
    GameTooltip:AddDoubleLine("Equipped item level", tostring(tonumber(info.itemLevel) or 0), 0.82, 0.82, 0.82, 1, 1, 1)
    GameTooltip:AddDoubleLine("Mythic+ rating", tostring(tonumber(info.mythicPlusRating) or 0), 0.82, 0.82, 0.82, 1, 0.72, 0.18)

    if info.weeklyExpired then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("This character's weekly snapshot expired at reset.", 1, 0.55, 0.24, true)
        GameTooltip:AddLine("Log into the character to refresh its weekly progress.", 0.72, 0.72, 0.75, true)
    else
        GameTooltip:AddDoubleLine("Best run this week", FormatWarbandBest(info.weeklyBestLevel), 0.82, 0.82, 0.82, 1, 0.82, 0.22)
        local keystone = info.keystone
        local keystoneText = "None"
        if type(keystone) == "table" and tonumber(keystone.level) then
            keystoneText = string.format("+%d %s", keystone.level, tostring(keystone.name or "Unknown dungeon"))
        end
        GameTooltip:AddDoubleLine("Owned keystone", keystoneText, 0.82, 0.82, 0.82, 0.72, 0.82, 1)

        local vault = info.vault
        if type(vault) == "table" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Great Vault", 1, 0.82, 0.18)
            GameTooltip:AddDoubleLine("Dungeons", GetVaultCategoryText(vault.dungeons), 0.82, 0.82, 0.82, 1, 1, 1)
            GameTooltip:AddDoubleLine("Raids", GetVaultCategoryText(vault.raid), 0.82, 0.82, 0.82, 1, 1, 1)
            GameTooltip:AddDoubleLine("World", GetVaultCategoryText(vault.world), 0.82, 0.82, 0.82, 1, 1, 1)
            if type(vault.pvp) == "table" and (tonumber(vault.pvp.total) or 0) > 0 then
                GameTooltip:AddDoubleLine("Rated PvP", GetVaultCategoryText(vault.pvp), 0.82, 0.82, 0.82, 1, 1, 1)
            end
            if vault.rewardAvailable then
                GameTooltip:AddLine("A previous Great Vault reward is available.", 0.36, 0.95, 0.52)
            end
        end

        local lockouts = info.lockouts
        if type(lockouts) == "table" then
            local dungeonCount = type(lockouts.dungeons) == "table" and #lockouts.dungeons or 0
            local raidCount = type(lockouts.raids) == "table" and #lockouts.raids or 0
            if dungeonCount + raidCount > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Current-expansion saves", 1, 0.82, 0.18)
                for _, lockout in ipairs(lockouts.dungeons or {}) do
                    GameTooltip:AddDoubleLine(lockout.name or "Mythic dungeon", lockout.resetAt and FormatWarbandDuration(lockout.resetAt - WarbandNow()) or "Saved", 0.82, 0.82, 0.82, 0.58, 0.72, 0.95)
                end
                for _, lockout in ipairs(lockouts.raids or {}) do
                    local progress = tonumber(lockout.numEncounters) and lockout.numEncounters > 0
                        and string.format("%d/%d", tonumber(lockout.progress) or 0, lockout.numEncounters)
                        or (lockout.difficultyName or "Saved")
                    GameTooltip:AddDoubleLine(lockout.name or "Raid", progress, 0.82, 0.82, 0.82, 0.58, 0.72, 0.95)
                end
            end
        end
    end

    local updatedText = FormatWarbandAge(info.lastSeen)
    if type(date) == "function" and tonumber(info.lastSeen) then
        local ok, formatted = pcall(date, "%b %d, %Y %I:%M %p", info.lastSeen)
        if ok and formatted then
            updatedText = formatted
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Last updated", tostring(updatedText or "Unknown"), 0.55, 0.55, 0.58, 0.75, 0.75, 0.78)
    GameTooltip:Show()
end

local function CreateWarbandPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local summary = CreateSectionCard(page, "Current Week", 760, 68)
    summary:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    summary.reset = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary.reset:SetPoint("TOPLEFT", summary, "TOPLEFT", 18, -40)
    summary.reset:SetWidth(220)
    summary.reset:SetJustifyH("LEFT")

    summary.characters = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary.characters:SetPoint("LEFT", summary.reset, "RIGHT", 12, 0)
    summary.characters:SetWidth(170)
    summary.characters:SetJustifyH("LEFT")

    summary.vault = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary.vault:SetPoint("LEFT", summary.characters, "RIGHT", 12, 0)
    summary.vault:SetWidth(170)
    summary.vault:SetJustifyH("LEFT")

    local refreshButton = CreateButton(summary, "Refresh Current", 144, 24)
    refreshButton:SetPoint("RIGHT", summary, "RIGHT", -12, -8)
    refreshButton:SetScript("OnClick", function()
        if ns.RequestWarbandWeeklyRefresh then
            ns:RequestWarbandWeeklyRefresh()
        end
    end)

    local showLeveling = ns.UI.CreateCheckbox(
        page,
        "Include leveling characters",
        "Shows saved characters below the current expansion's maximum level.",
        function() return ns.GetWarbandWeeklyShowLevelingCharacters and ns:GetWarbandWeeklyShowLevelingCharacters() end,
        function(value) if ns.SetWarbandWeeklyShowLevelingCharacters then ns:SetWarbandWeeklyShowLevelingCharacters(value) end end
    )
    showLeveling:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -6)

    page.freshness = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.freshness:SetPoint("RIGHT", summary, "BOTTOMRIGHT", 0, -23)
    page.freshness:SetText("Offline characters use their last-login snapshot.")

    page.header = CreateFrame("Frame", nil, page, "BackdropTemplate")
    page.header:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -39)
    page.header:SetSize(760, 24)
    ApplyBackdrop(page.header, 0.56)

    local x = 10
    for _, column in ipairs(WARBAND_COLUMNS) do
        local label = page.header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:SetPoint("LEFT", page.header, "LEFT", x, 0)
        label:SetWidth(column.width)
        label:SetJustifyH(column.align)
        label:SetTextColor(0.68, 0.69, 0.72)
        label:SetText(column.label)
        x = x + column.width
    end

    page.scroll = CreateFrame("ScrollFrame", nil, page)
    page.scroll:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT", 0, -5)
    page.scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -28, 24)
    page.scroll:SetClipsChildren(true)
    page.scroll:EnableMouseWheel(true)

    page.content = CreateFrame("Frame", nil, page.scroll)
    page.content:SetSize(760, 1)
    page.scroll:SetScrollChild(page.content)
    page.rows = {}

    local function CreateRow()
        local row = CreateFrame("Button", nil, page.content, "BackdropTemplate")
        row:SetSize(760, 50)
        ApplyBackdrop(row, 0.42)

        row.accent = row:CreateTexture(nil, "ARTWORK")
        row.accent:SetPoint("TOPLEFT", 4, -5)
        row.accent:SetPoint("BOTTOMLEFT", 4, 5)
        row.accent:SetWidth(3)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -8)
        row.name:SetWidth(WARBAND_COLUMNS[1].width - 16)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
        row.detail:SetWidth(WARBAND_COLUMNS[1].width - 16)
        row.detail:SetJustifyH("LEFT")
        row.detail:SetWordWrap(false)

        row.values = {}
        local valueX = 10 + WARBAND_COLUMNS[1].width
        for index = 2, #WARBAND_COLUMNS do
            local column = WARBAND_COLUMNS[index]
            local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            value:SetPoint("CENTER", row, "LEFT", valueX + column.width / 2, 0)
            value:SetWidth(column.width - 4)
            value:SetJustifyH(column.align)
            value:SetWordWrap(false)
            row.values[column.key] = value
            valueX = valueX + column.width
        end

        row:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.84, 0.64, 0.22, 0.82)
            ShowWarbandCharacterTooltip(self)
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.25, 0.28, 0.33, 0.58)
            GameTooltip:Hide()
        end)
        return row
    end

    page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.empty:SetPoint("TOP", page.header, "BOTTOM", 0, -64)
    page.empty:SetWidth(700)
    page.empty:SetJustifyH("CENTER")
    page.empty:SetTextColor(0.72, 0.72, 0.74)
    page.empty:SetText("No character snapshots yet. Log into a character to add it to the dashboard.")

    page.scroll:SetScript("OnSizeChanged", function(self, width)
        width = tonumber(width)
        if width then
            page.content:SetWidth(math.max(1, width))
            for _, row in ipairs(page.rows) do
                row:SetWidth(math.max(1, width))
            end
        end
    end)
    page.scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = tonumber(self:GetVerticalScroll()) or 0
        local range = tonumber(self:GetVerticalScrollRange()) or 0
        self:SetVerticalScroll(math.max(0, math.min(range, current - (tonumber(delta) or 0) * 52)))
    end)

    function page:Refresh()
        showLeveling:Refresh()
        local characters = ns.GetWarbandWeeklyCharacters and ns:GetWarbandWeeklyCharacters() or {}
        local unlocked = 0
        local total = 0
        for _, info in ipairs(characters) do
            if not info.weeklyExpired and type(info.vault) == "table" then
                unlocked = unlocked + (tonumber(info.vault.unlocked) or 0)
                total = total + (tonumber(info.vault.total) or 0)
            end
        end

        local resetAt = ns.GetWarbandWeeklyResetAt and ns:GetWarbandWeeklyResetAt()
        summary.reset:SetText("RESET  |cffffffff" .. (resetAt and FormatWarbandDuration(resetAt - WarbandNow()) or "Unavailable") .. "|r")
        summary.characters:SetText(string.format("CHARACTERS  |cffffffff%d|r", #characters))
        summary.vault:SetText(string.format("VAULT SLOTS  |cffffffff%d/%d|r", unlocked, total))

        for index, info in ipairs(characters) do
            local row = page.rows[index]
            if not row then
                row = CreateRow()
                page.rows[index] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", page.content, "TOPLEFT", 0, -((index - 1) * 53))
            row:SetWidth(page.content:GetWidth() or 760)
            row.info = info

            local r, g, b = GetWarbandClassColor(info.classFile)
            row.accent:SetColorTexture(r, g, b, 0.95)
            row.name:SetText((info.isCurrent and "• " or "") .. tostring(info.name or "Unknown"))
            row.name:SetTextColor(r, g, b)
            row.detail:SetText(string.format("%s  •  %s", tostring(info.specialization or info.className or "Unknown"), tostring(info.realm or "Unknown Realm")))

            row.values.itemLevel:SetText((tonumber(info.itemLevel) or 0) > 0 and tostring(math.floor(info.itemLevel)) or "—")
            row.values.rating:SetText(tostring(math.floor(tonumber(info.mythicPlusRating) or 0)))

            if info.weeklyExpired then
                row.values.best:SetText("Reset")
                row.values.keystone:SetText("Refresh")
                row.values.vault:SetText("Reset")
                row.values.saves:SetText("—")
                row.values.best:SetTextColor(0.52, 0.52, 0.55)
                row.values.keystone:SetTextColor(0.52, 0.52, 0.55)
                row.values.vault:SetTextColor(0.52, 0.52, 0.55)
            else
                row.values.best:SetText(FormatWarbandBest(info.weeklyBestLevel))
                row.values.best:SetTextColor(1, 0.78, 0.20)
                local keystone = info.keystone
                row.values.keystone:SetText(type(keystone) == "table" and string.format("+%d %s", tonumber(keystone.level) or 0, tostring(keystone.name or "")) or "—")
                row.values.keystone:SetTextColor(0.82, 0.86, 0.95)
                local vault = type(info.vault) == "table" and info.vault or {}
                row.values.vault:SetText((tonumber(vault.total) or 0) > 0 and string.format("%d/%d%s", tonumber(vault.unlocked) or 0, tonumber(vault.total) or 0, vault.rewardAvailable and " !" or "") or "—")
                row.values.vault:SetTextColor(vault.rewardAvailable and 0.42 or 0.92, vault.rewardAvailable and 0.95 or 0.92, vault.rewardAvailable and 0.52 or 0.92)
                local lockouts = type(info.lockouts) == "table" and info.lockouts or {}
                local saves = (type(lockouts.dungeons) == "table" and #lockouts.dungeons or 0) + (type(lockouts.raids) == "table" and #lockouts.raids or 0)
                row.values.saves:SetText(tostring(saves))
            end
            row.values.updated:SetText(FormatWarbandAge(info.lastSeen))
            row:Show()
        end

        for index = #characters + 1, #page.rows do
            page.rows[index].info = nil
            page.rows[index]:Hide()
        end
        page.empty:SetShown(#characters == 0)
        page.content:SetHeight(math.max(1, #characters * 53))
    end

    page:SetScript("OnShow", function(self)
        self:Refresh()
        if ns.RequestWarbandWeeklyRefresh then
            ns:RequestWarbandWeeklyRefresh()
        end
    end)
    local updateElapsed = 0
    page:SetScript("OnUpdate", function(self, elapsed)
        updateElapsed = updateElapsed + (tonumber(elapsed) or 0)
        if updateElapsed >= 60 then
            updateElapsed = 0
            self:Refresh()
        end
    end)
    return page
end

local function CreateProfessionWeeklyPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    -- Scroll the complete page rather than confining scrolling to the short
    -- profession-row viewport at the bottom. The extra breathing room lets
    -- the profession header move naturally toward the middle of the page.
    page.scroll = CreateFrame("ScrollFrame", nil, page)
    page.scroll:SetAllPoints()
    page.scroll:SetClipsChildren(true)
    page.scroll:EnableMouseWheel(true)

    page.content = CreateFrame("Frame", nil, page.scroll)
    page.content:SetSize(760, 1)
    page.scroll:SetScrollChild(page.content)
    page.rows = {}

    local function FormatGoal(goal, usePoints)
        if type(goal) ~= "table" then
            return "—"
        end
        if goal.id == "catchup" then
            if not goal.known then return "—" end
            return goal.complete and "Caught up" or string.format("%d KP backlog", tonumber(goal.remaining) or 0)
        end
        if goal.complete then
            return "Done"
        elseif goal.ready then
            return "Ready"
        elseif usePoints then
            return string.format("%d/%d", tonumber(goal.points) or 0, tonumber(goal.pointsTotal) or 0)
        end
        return string.format("%d/%d", tonumber(goal.current) or 0, tonumber(goal.total) or 0)
    end

    local function SetGoalColor(fontString, goal)
        if type(goal) ~= "table" or (goal.id == "catchup" and not goal.known) then
            fontString:SetTextColor(0.55, 0.55, 0.58)
        elseif goal.complete then
            fontString:SetTextColor(0.36, 0.92, 0.52)
        elseif goal.ready then
            fontString:SetTextColor(1, 0.76, 0.24)
        else
            fontString:SetTextColor(0.84, 0.84, 0.82)
        end
    end

    local summary = CreateSectionCard(page.content, "Current Week", 760, 68)
    summary:SetPoint("TOPLEFT", page.content, "TOPLEFT", 0, 0)

    summary.reset = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary.reset:SetPoint("TOPLEFT", summary, "TOPLEFT", 18, -40)
    summary.reset:SetWidth(210)
    summary.reset:SetJustifyH("LEFT")

    summary.professions = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary.professions:SetPoint("LEFT", summary.reset, "RIGHT", 12, 0)
    summary.professions:SetWidth(170)
    summary.professions:SetJustifyH("LEFT")

    summary.knowledge = summary:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary.knowledge:SetPoint("LEFT", summary.professions, "RIGHT", 12, 0)
    summary.knowledge:SetWidth(160)
    summary.knowledge:SetJustifyH("LEFT")

    local refreshButton = CreateButton(summary, "Refresh", 96, 24)
    refreshButton:SetPoint("RIGHT", summary, "RIGHT", -12, -8)
    refreshButton:SetScript("OnClick", function()
        if ns.RequestWeeklyGoalsRefresh then
            ns:RequestWeeklyGoalsRefresh()
        elseif ns.RequestProfessionWeeklyRefresh then
            ns:RequestProfessionWeeklyRefresh()
        end
    end)

    local trackerCard = CreateSectionCard(page.content, "Weekly Goals Tracker", 760, 210)
    trackerCard:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -12)

    local trackerShown = UI.CreateCheckbox(
        trackerCard,
        "Show Weekly Goals tracker",
        "Shows the compact selected-goal tracker outside the settings window.",
        function() return ns.IsProfessionWeeklyTrackerShown and ns:IsProfessionWeeklyTrackerShown() end,
        function(value) if ns.SetProfessionWeeklyTrackerShown then ns:SetProfessionWeeklyTrackerShown(value) end end
    )
    trackerShown:SetPoint("TOPLEFT", trackerCard, "TOPLEFT", 18, -40)

    local trackerLocked = UI.CreateCheckbox(
        trackerCard,
        "Lock tracker click-through",
        "Locks the Weekly Goals tracker in place and lets mouse clicks pass through it.",
        function() return ns.IsProfessionWeeklyTrackerLocked and ns:IsProfessionWeeklyTrackerLocked() end,
        function(value) if ns.SetProfessionWeeklyTrackerLocked then ns:SetProfessionWeeklyTrackerLocked(value) end end
    )
    trackerLocked:SetPoint("TOPLEFT", trackerShown, "BOTTOMLEFT", 0, -4)

    local hideCompleted = UI.CreateCheckbox(
        trackerCard,
        "Hide completed goals",
        "Keeps the tracker focused by hiding individual goals after they are completed.",
        function() return ns.GetWeeklyGoalsHideCompleted and ns:GetWeeklyGoalsHideCompleted() end,
        function(value) if ns.SetWeeklyGoalsHideCompleted then ns:SetWeeklyGoalsHideCompleted(value) end end
    )
    hideCompleted:SetPoint("TOPLEFT", trackerLocked, "BOTTOMLEFT", 0, -4)

    local moveTracker = CreateButton(trackerCard, "Show & Move", 120, 25)
    moveTracker:SetPoint("TOPLEFT", trackerCard, "TOPLEFT", 18, -169)
    moveTracker:SetScript("OnClick", function()
        if ns.MoveProfessionWeeklyTracker then
            ns:MoveProfessionWeeklyTracker()
        end
        if page.Refresh then page:Refresh() end
    end)

    local resetTracker = CreateButton(trackerCard, "Reset Position", 126, 25)
    resetTracker:SetPoint("LEFT", moveTracker, "RIGHT", 10, 0)
    resetTracker:SetScript("OnClick", function()
        if ns.ResetProfessionWeeklyTrackerPosition then
            ns:ResetProfessionWeeklyTrackerPosition()
        end
    end)

    local weeklyOptions = {}
    for _, option in ipairs(ns.GetWeeklyGoalOptions and ns:GetWeeklyGoalOptions() or {}) do
        local goalID = option.value
        weeklyOptions[#weeklyOptions + 1] = {
            value = goalID,
            text = option.text,
            shortText = option.shortText,
            getter = function()
                return ns.GetWeeklyGoalEnabled and ns:GetWeeklyGoalEnabled(goalID)
            end,
            setter = function(value)
                if ns.SetWeeklyGoalEnabled then
                    ns:SetWeeklyGoalEnabled(goalID, value)
                end
            end,
        }
    end

    local weeklySelector = UI.CreateMultiSelectDropdown(
        trackerCard,
        "Weekly sections shown",
        "Choose the popular weekly activities and profession section displayed by the tracker.",
        weeklyOptions,
        350
    )
    weeklySelector:SetPoint("TOPLEFT", trackerCard, "TOPLEFT", 392, -40)

    local professionGoalOptions = {}
    for _, option in ipairs(ns.GetProfessionWeeklyGoalOptions and ns:GetProfessionWeeklyGoalOptions() or {}) do
        local goalID = option.value
        professionGoalOptions[#professionGoalOptions + 1] = {
            value = goalID,
            text = option.text,
            shortText = option.shortText,
            getter = function()
                return ns.GetProfessionWeeklyGoalEnabled and ns:GetProfessionWeeklyGoalEnabled(goalID)
            end,
            setter = function(value)
                if ns.SetProfessionWeeklyGoalEnabled then
                    ns:SetProfessionWeeklyGoalEnabled(goalID, value)
                end
            end,
        }
    end

    local professionGoalSelector = UI.CreateMultiSelectDropdown(
        trackerCard,
        "Profession details shown",
        "Choose the profession goals displayed beneath each learned profession.",
        professionGoalOptions,
        350
    )
    professionGoalSelector:SetPoint("TOPLEFT", trackerCard, "TOPLEFT", 392, -103)

    trackerCard.note = trackerCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    trackerCard.note:SetPoint("TOPLEFT", trackerCard, "TOPLEFT", 392, -166)
    trackerCard.note:SetWidth(340)
    trackerCard.note:SetJustifyH("LEFT")
    trackerCard.note:SetText("General goals use Blizzard's weekly APIs; profession catch-up and one-time goals remain optional.")

    page.header = CreateFrame("Frame", nil, page.content, "BackdropTemplate")
    page.header:SetPoint("TOPLEFT", trackerCard, "BOTTOMLEFT", 0, -12)
    page.header:SetSize(760, 24)
    ApplyBackdrop(page.header, 0.56)

    local columnX = 10
    for _, column in ipairs(PROFESSION_WEEKLY_COLUMNS) do
        local label = page.header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:SetPoint("LEFT", page.header, "LEFT", columnX, 0)
        label:SetWidth(column.width)
        label:SetJustifyH(column.align)
        label:SetTextColor(0.68, 0.69, 0.72)
        label:SetText(column.label)
        columnX = columnX + column.width
    end

    local function ShowProfessionTooltip(row)
        local info = row and row.info
        if not info or not GameTooltip then return end

        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(tostring(info.name or "Profession"), 1, 0.82, 0.18)
        local skillText = (tonumber(info.maxSkillLevel) or 0) > 0
            and string.format("%d/%d", tonumber(info.skillLevel) or 0, tonumber(info.maxSkillLevel) or 0)
            or "Unavailable"
        GameTooltip:AddDoubleLine("Midnight skill", skillText, 0.82, 0.82, 0.82, 1, 1, 1)
        GameTooltip:AddDoubleLine("Unspent Knowledge", tostring(tonumber(info.unspentKnowledge) or 0), 0.82, 0.82, 0.82, 1, 0.82, 0.18)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Fixed weekly Knowledge", string.format("%d/%d", tonumber(info.weeklyPoints) or 0, tonumber(info.weeklyTotal) or 0), 1, 0.82, 0.18, 1, 1, 1)
        for _, goalID in ipairs({ "trainer", "treatise", "field" }) do
            local goal = info.goals and info.goals[goalID]
            if goal then
                GameTooltip:AddDoubleLine(goal.label or goalID, string.format("%s  •  %d/%d KP", FormatGoal(goal, false), tonumber(goal.points) or 0, tonumber(goal.pointsTotal) or 0), 0.82, 0.82, 0.82, goal.complete and 0.36 or 0.92, goal.complete and 0.92 or 0.82, goal.complete and 0.52 or 0.72)
            end
        end

        local darkmoon = info.goals and info.goals.darkmoon
        if darkmoon then
            local activity = darkmoon.active
                and string.format("Active %s", darkmoon.location or "SW")
                or "Inactive"
            GameTooltip:AddDoubleLine(
                "Darkmoon Faire (monthly)",
                string.format("%s  •  %s", activity, darkmoon.complete and "Complete" or "0/1"),
                0.82, 0.82, 0.82,
                darkmoon.active and 0.36 or 1,
                darkmoon.active and 0.92 or 0.30,
                darkmoon.active and 0.52 or 0.30
            )
        end

        local onetime = info.goals and info.goals.onetime
        if onetime then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("One-time Midnight Knowledge", 1, 0.82, 0.18)
            GameTooltip:AddDoubleLine("Midnight world treasures", string.format("%d/%d", tonumber(onetime.treasureCurrent) or 0, tonumber(onetime.treasureTotal) or 0), 0.82, 0.82, 0.82, 1, 1, 1)
            GameTooltip:AddDoubleLine("Zul'jarra rank 6 book", onetime.bookComplete and "Collected" or "Not collected", 0.82, 0.82, 0.82, onetime.bookComplete and 0.36 or 1, onetime.bookComplete and 0.92 or 0.64, onetime.bookComplete and 0.52 or 0.32)
        end

        local catchup = info.goals and info.goals.catchup
        if catchup then
            local catchupText = catchup.known
                and (catchup.complete
                    and "Caught up"
                    or string.format("%d KP via %s", tonumber(catchup.remaining) or 0, catchup.method or "profession activities"))
                or "Unavailable"
            GameTooltip:AddDoubleLine("Catch-up backlog", catchupText, 0.82, 0.82, 0.82, 0.72, 0.84, 1)
            GameTooltip:AddLine("Blizzard's catch-up allowance is separate from weekly goals and treatises.", 0.65, 0.67, 0.72, true)
            if catchup.method == "gathering" then
                GameTooltip:AddLine("Finish the normal weekly gathering goals first; bonus 1-KP items can then appear while gathering.", 0.65, 0.67, 0.72, true)
            elseif catchup.method == "disenchanting" then
                GameTooltip:AddLine("After the normal weekly goals, bonus 1-KP items can appear while disenchanting.", 0.65, 0.67, 0.72, true)
            elseif catchup.method == "patron orders" then
                GameTooltip:AddLine("Catch-up Knowledge is offered through eligible patron crafting orders over time.", 0.65, 0.67, 0.72, true)
            end
        end
        GameTooltip:Show()
    end

    local function CreateRow()
        local row = CreateFrame("Button", nil, page.content, "BackdropTemplate")
        row:SetSize(760, 58)
        ApplyBackdrop(row, 0.42)

        row.accent = row:CreateTexture(nil, "ARTWORK")
        row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -5)
        row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 5)
        row.accent:SetWidth(3)
        row.accent:SetColorTexture(0.96, 0.72, 0.20, 0.95)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetPoint("LEFT", row, "LEFT", 13, 0)
        row.icon:SetSize(28, 28)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 48, -9)
        row.name:SetWidth(PROFESSION_WEEKLY_COLUMNS[1].width - 48)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
        row.detail:SetWidth(PROFESSION_WEEKLY_COLUMNS[1].width - 48)
        row.detail:SetJustifyH("LEFT")
        row.detail:SetWordWrap(false)

        row.values = {}
        local valueX = 10 + PROFESSION_WEEKLY_COLUMNS[1].width
        for index = 2, #PROFESSION_WEEKLY_COLUMNS do
            local column = PROFESSION_WEEKLY_COLUMNS[index]
            local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            value:SetPoint("CENTER", row, "LEFT", valueX + column.width / 2, 0)
            value:SetWidth(column.width - 4)
            value:SetJustifyH(column.align)
            value:SetWordWrap(false)
            row.values[column.key] = value
            valueX = valueX + column.width
        end

        row:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.84, 0.64, 0.22, 0.82)
            ShowProfessionTooltip(self)
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.25, 0.28, 0.33, 0.58)
            GameTooltip:Hide()
        end)
        return row
    end

    page.empty = page.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.empty:SetPoint("TOP", page.header, "BOTTOM", 0, -55)
    page.empty:SetWidth(700)
    page.empty:SetJustifyH("CENTER")
    page.empty:SetTextColor(0.72, 0.72, 0.74)
    page.empty:SetText("No Midnight primary professions were found on this character.")

    local function RefreshScrollGeometry()
        local width = tonumber(page.scroll:GetWidth()) or 0
        local viewportHeight = tonumber(page.scroll:GetHeight()) or 0
        width = width >= 100 and width or 760
        viewportHeight = viewportHeight >= 100 and viewportHeight or 400
        local professionCount = math.max(1, tonumber(page.visibleProfessionCount) or 0)
        local naturalHeight = 340 + (professionCount * 61)

        page.content:SetWidth(width)
        page.content:SetHeight(math.max(naturalHeight, viewportHeight + 132))
        summary:SetWidth(width)
        trackerCard:SetWidth(width)
        page.header:SetWidth(width)
        for _, row in ipairs(page.rows) do
            row:SetWidth(width)
        end

        local current = tonumber(page.scroll:GetVerticalScroll()) or 0
        local range = tonumber(page.scroll:GetVerticalScrollRange()) or 0
        if current > range then
            page.scroll:SetVerticalScroll(range)
        end
    end

    page.scroll:SetScript("OnSizeChanged", RefreshScrollGeometry)
    page.scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = tonumber(self:GetVerticalScroll()) or 0
        local range = tonumber(self:GetVerticalScrollRange()) or 0
        self:SetVerticalScroll(math.max(0, math.min(range, current - (tonumber(delta) or 0) * 61)))
    end)

    function page:Refresh()
        trackerShown:Refresh()
        trackerLocked:Refresh()
        hideCompleted:Refresh()
        weeklySelector:Refresh()
        professionGoalSelector:Refresh()

        local dashboard = ns.GetProfessionWeeklyDashboard and ns:GetProfessionWeeklyDashboard() or {}
        local professions = type(dashboard.professions) == "table" and dashboard.professions or {}
        local weekly = ns.GetWeeklyGoalsSnapshot and ns:GetWeeklyGoalsSnapshot() or {}
        local vault = type(weekly.vault) == "table" and weekly.vault or {}
        local spark = type(weekly.spark) == "table" and weekly.spark or {}
        local resetAt = ns.GetProfessionWeeklyResetAt and ns:GetProfessionWeeklyResetAt()
        summary.reset:SetText("RESET  |cffffffff" .. (resetAt and FormatWarbandDuration(resetAt - WarbandNow()) or "Unavailable") .. "|r")
        summary.professions:SetText((tonumber(vault.total) or 0) > 0
            and string.format("VAULT  |cffffffff%d/%d%s|r", tonumber(vault.unlocked) or 0, tonumber(vault.total) or 0, vault.rewardAvailable and " !" or "")
            or "VAULT  |cff888888—|r")
        summary.knowledge:SetText(spark.known
            and string.format("SPARK CAP  |cffffffff%d/%d|r", tonumber(spark.current) or 0, tonumber(spark.total) or 0)
            or "SPARK CAP  |cff888888—|r")

        for index, info in ipairs(professions) do
            local row = page.rows[index]
            if not row then
                row = CreateRow()
                page.rows[index] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", page.header, "BOTTOMLEFT", 0, -5 - ((index - 1) * 61))
            row:SetWidth(page.content:GetWidth() or 760)
            row.info = info
            row.name:SetText(tostring(info.name or "Profession"))
            row.name:SetTextColor(1, 0.82, 0.18)
            row.icon:SetTexture(info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            local skillText = (tonumber(info.maxSkillLevel) or 0) > 0
                and string.format("Skill %d/%d", tonumber(info.skillLevel) or 0, tonumber(info.maxSkillLevel) or 0)
                or "Midnight skill"
            row.detail:SetText(string.format("%s  •  %d unspent", skillText, tonumber(info.unspentKnowledge) or 0))

            local goals = info.goals or {}
            row.values.trainer:SetText(FormatGoal(goals.trainer, false))
            SetGoalColor(row.values.trainer, goals.trainer)
            row.values.treatise:SetText(FormatGoal(goals.treatise, false))
            SetGoalColor(row.values.treatise, goals.treatise)
            row.values.field:SetText(FormatGoal(goals.field, false))
            SetGoalColor(row.values.field, goals.field)
            row.values.weekly:SetText(string.format("%d/%d", tonumber(info.weeklyPoints) or 0, tonumber(info.weeklyTotal) or 0))
            row.values.weekly:SetTextColor(info.weeklyComplete and 0.36 or 1, info.weeklyComplete and 0.92 or 0.78, info.weeklyComplete and 0.52 or 0.20)
            row.values.onetime:SetText(FormatGoal(goals.onetime, false))
            SetGoalColor(row.values.onetime, goals.onetime)
            row.values.catchup:SetText(FormatGoal(goals.catchup, false))
            SetGoalColor(row.values.catchup, goals.catchup)
            row:Show()
        end

        for index = #professions + 1, #page.rows do
            page.rows[index].info = nil
            page.rows[index]:Hide()
        end
        page.empty:SetShown(#professions == 0)
        page.visibleProfessionCount = #professions
        RefreshScrollGeometry()
    end

    page:SetScript("OnShow", function(self)
        self:Refresh()
        if ns.RequestWeeklyGoalsRefresh then
            ns:RequestWeeklyGoalsRefresh()
        elseif ns.RequestProfessionWeeklyRefresh then
            ns:RequestProfessionWeeklyRefresh()
        end
    end)
    local updateElapsed = 0
    page:SetScript("OnUpdate", function(self, elapsed)
        updateElapsed = updateElapsed + (tonumber(elapsed) or 0)
        if updateElapsed >= 60 then
            updateElapsed = 0
            self:Refresh()
        end
    end)
    return page
end

local function CreateMinimapPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374

    local minimapCard = CreateSectionCard(page, "Minimap", cardW, 248)
    minimapCard:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    local showMinimap = ns.UI.CreateCheckbox(
        minimapCard,
        "Show minimap button",
        "Shows the ZoidsTools minimap launcher.",
        function() return ns.db and ns.db.ui and ns.db.ui.minimap and ns.db.ui.minimap.show end,
        function(value) if ns.SetMinimapShown then ns:SetMinimapShown(value) end end
    )
    PlaceFirst(showMinimap, minimapCard)

    local squareMinimap = ns.UI.CreateCheckbox(
        minimapCard,
        "Square minimap",
        "Uses ZoidsTools' square minimap border and mask.",
        function() return ns.IsSquareMinimapEnabled and ns:IsSquareMinimapEnabled() end,
        function(value) if ns.SetSquareMinimapEnabled then ns:SetSquareMinimapEnabled(value) end end
    )
    PlaceBelow(squareMinimap, showMinimap)

    local minimapHeader = ns.UI.CreateCheckbox(
        minimapCard,
        "Compact title and clock",
        "Moves the map title, time, and tracking display into a cleaner title bar.",
        function() return ns.IsMinimapHeaderBarEnabled and ns:IsMinimapHeaderBarEnabled() end,
        function(value) if ns.SetMinimapHeaderBarEnabled then ns:SetMinimapHeaderBarEnabled(value) end end
    )
    PlaceBelow(minimapHeader, squareMinimap)

    local hideAddonCompartment = ns.UI.CreateCheckbox(
        minimapCard,
        "Hide addon compartment",
        "Hides Blizzard's addon-compartment button from the minimap.",
        function() return ns.IsAddonCompartmentHidden and ns:IsAddonCompartmentHidden() end,
        function(value) if ns.SetAddonCompartmentHidden then ns:SetAddonCompartmentHidden(value) end end
    )
    PlaceBelow(hideAddonCompartment, minimapHeader)

    local mouseoverButtons = ns.UI.CreateCheckbox(
        minimapCard,
        "Fade addon buttons until mouseover",
        "Keeps addon buttons tucked away until your mouse is over the minimap.",
        function() return ns.IsMinimapButtonsMouseoverEnabled and ns:IsMinimapButtonsMouseoverEnabled() end,
        function(value) if ns.SetMinimapButtonsMouseoverEnabled then ns:SetMinimapButtonsMouseoverEnabled(value) end end
    )
    PlaceBelow(mouseoverButtons, hideAddonCompartment)

    local collectButtons = ns.UI.CreateCheckbox(
        minimapCard,
        "Collect addon buttons",
        "Stores addon minimap buttons inside one expandable ZoidsTools button.",
        function() return ns.IsMinimapButtonCollectorEnabled and ns:IsMinimapButtonCollectorEnabled() end,
        function(value) if ns.SetMinimapButtonCollectorEnabled then ns:SetMinimapButtonCollectorEnabled(value) end end
    )
    PlaceBelow(collectButtons, mouseoverButtons)

    local expansionButtonSize = ns.UI.CreateSlider(
        minimapCard,
        "Expansion button size",
        "Adjusts Blizzard's expansion landing-page minimap button.",
        20,
        48,
        1,
        function() return ns.GetExpansionButtonSize and ns:GetExpansionButtonSize() or 32 end,
        function(value) if ns.SetExpansionButtonSize then ns:SetExpansionButtonSize(value) end end,
        220,
        function(value) return string.format("%d px", value or 32) end
    )
    expansionButtonSize:SetPoint("TOPLEFT", collectButtons, "BOTTOMLEFT", 0, -14)

    function page:Refresh()
        showMinimap:Refresh()
        squareMinimap:Refresh()
        minimapHeader:Refresh()
        hideAddonCompartment:Refresh()
        mouseoverButtons:Refresh()
        collectButtons:Refresh()
        expansionButtonSize:Refresh()
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateInterfacePage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local rightX = cardW + 14

    local widgetsCard = CreateSectionCard(page, "Widgets", cardW, 237)
    widgetsCard:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local performanceDisplay = ns.UI.CreateDropdown(
        widgetsCard,
        "Performance widget",
        "Controls what the draggable FPS/MS widget displays.",
        {
            { value = "disabled", text = "Disabled" },
            { value = "fps", text = "FPS" },
            { value = "latency", text = "Latency" },
            { value = "both", text = "Both" },
        },
        function() return ns.GetPerformanceWidgetDisplayMode and ns:GetPerformanceWidgetDisplayMode() or "both" end,
        function(value) if ns.SetPerformanceWidgetDisplayMode then ns:SetPerformanceWidgetDisplayMode(value) end end,
        230
    )
    PlaceFirst(performanceDisplay, widgetsCard, 18, -42)

    local performanceScale = ns.UI.CreateSlider(
        widgetsCard,
        "Widget size",
        "Adjusts the FPS/MS widget size.",
        0.65,
        1.8,
        0.05,
        function() return ns.GetPerformanceWidgetScale and ns:GetPerformanceWidgetScale() or 1 end,
        function(value) if ns.SetPerformanceWidgetScale then ns:SetPerformanceWidgetScale(value) end end,
        230,
        function(value) return string.format("%d%%", (value or 1) * 100) end
    )
    performanceScale:SetPoint("TOPLEFT", performanceDisplay, "BOTTOMLEFT", 10, -14)

    local unlockPerformance = CreateButton(widgetsCard, "Unlock Widget", 132, 27)
    unlockPerformance:SetPoint("TOPLEFT", performanceScale, "BOTTOMLEFT", -10, -14)
    unlockPerformance:SetScript("OnClick", function()
        if ns.SetPerformanceWidgetLocked then
            local locked = ns.IsPerformanceWidgetLocked and ns:IsPerformanceWidgetLocked()
            ns:SetPerformanceWidgetLocked(not locked)
        end
        if page.Refresh then page:Refresh() end
    end)

    local coordinatesWidget = ns.UI.CreateCheckbox(
        widgetsCard,
        "Show coordinates widget",
        "Shows a standalone coordinate widget.",
        function() return ns.IsCoordinatesWidgetShown and ns:IsCoordinatesWidgetShown() end,
        function(value) if ns.SetCoordinatesWidgetShown then ns:SetCoordinatesWidgetShown(value) end end
    )
    coordinatesWidget:SetPoint("TOPLEFT", unlockPerformance, "BOTTOMLEFT", 0, -10)

    local resetCoordinates = CreateButton(widgetsCard, "Reset Coords", 132, 27)
    resetCoordinates:SetPoint("TOPLEFT", coordinatesWidget, "BOTTOMLEFT", 0, -10)
    resetCoordinates:SetScript("OnClick", function()
        if ns.ResetCoordinatesWidgetPosition then
            ns:ResetCoordinatesWidgetPosition()
        end
    end)

    local queueCard = CreateSectionCard(page, "Queue Alerts", cardW, 158)
    queueCard:SetPoint("TOPLEFT", widgetsCard, "BOTTOMLEFT", 0, -10)

    local queueSound = ns.UI.CreateCheckbox(
        queueCard,
        "Sound while in background",
        "Plays the dungeon-ready alert on the Master channel, including while WoW is in the background.",
        function() return ns.IsQueueBackgroundSoundEnabled and ns:IsQueueBackgroundSoundEnabled() end,
        function(value) if ns.SetQueueBackgroundSoundEnabled then ns:SetQueueBackgroundSoundEnabled(value) end end
    )
    PlaceFirst(queueSound, queueCard)

    local queueCountdown = ns.UI.CreateCheckbox(
        queueCard,
        "Show queue countdown",
        "Shows a countdown on both the response dialog and the waiting-for-party status.",
        function() return ns.IsQueueCountdownEnabled and ns:IsQueueCountdownEnabled() end,
        function(value) if ns.SetQueueCountdownEnabled then ns:SetQueueCountdownEnabled(value) end end
    )
    PlaceBelow(queueCountdown, queueSound)

    local safeQueue = ns.UI.CreateCheckbox(
        queueCard,
        "Safe PvP queues (hide Leave Queue)",
        "Hides Leave Queue on battleground and arena ready dialogs. ZoidsTools never accepts automatically.",
        function() return ns.IsSafeQueueEnabled and ns:IsSafeQueueEnabled() end,
        function(value) if ns.SetSafeQueueEnabled then ns:SetSafeQueueEnabled(value) end end
    )
    PlaceBelow(safeQueue, queueCountdown)

    local safeDungeonQueue = ns.UI.CreateCheckbox(
        queueCard,
        "Safe dungeon queues (hide Decline)",
        "Also hides Decline on dungeon-ready dialogs. This is separate and disabled by default.",
        function() return ns.IsDungeonSafeQueueEnabled and ns:IsDungeonSafeQueueEnabled() end,
        function(value) if ns.SetDungeonSafeQueueEnabled then ns:SetDungeonSafeQueueEnabled(value) end end
    )
    PlaceBelow(safeDungeonQueue, safeQueue)

    local diagnosticsCard = CreateSectionCard(page, "Activity Recorder", cardW, 132)
    diagnosticsCard:SetPoint("TOPLEFT", queueCard, "BOTTOMLEFT", 0, -10)

    local diagnosticsStatus = diagnosticsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    diagnosticsStatus:SetPoint("TOPLEFT", diagnosticsCard, "TOPLEFT", 18, -42)
    diagnosticsStatus:SetPoint("RIGHT", diagnosticsCard, "RIGHT", -18, 0)
    diagnosticsStatus:SetJustifyH("LEFT")
    diagnosticsStatus:SetTextColor(0.76, 0.77, 0.78)

    local toggleDiagnostics = CreateButton(diagnosticsCard, "Start", 96, 27)
    toggleDiagnostics:SetPoint("TOPLEFT", diagnosticsStatus, "BOTTOMLEFT", 0, -12)
    toggleDiagnostics:SetScript("OnClick", function()
        if ns.IsDiagnosticsActive and ns:IsDiagnosticsActive() then
            if ns.StopDiagnostics then ns:StopDiagnostics() end
        elseif ns.StartDiagnostics then
            ns:StartDiagnostics()
        end
        if page.Refresh then page:Refresh() end
    end)

    local copyDiagnostics = CreateButton(diagnosticsCard, "Copy Report", 112, 27)
    copyDiagnostics:SetPoint("LEFT", toggleDiagnostics, "RIGHT", 8, 0)
    copyDiagnostics:SetScript("OnClick", function()
        if ns.ShowDiagnosticsReport then ns:ShowDiagnosticsReport() end
    end)

    local resetDiagnostics = CreateButton(diagnosticsCard, "Clear", 86, 27)
    resetDiagnostics:SetPoint("LEFT", copyDiagnostics, "RIGHT", 8, 0)
    resetDiagnostics:SetScript("OnClick", function()
        if ns.ResetDiagnostics then ns:ResetDiagnostics() end
        if page.Refresh then page:Refresh() end
    end)

    if ns.UI and ns.UI.RegisterSearchControl then
        ns.UI.RegisterSearchControl(
            diagnosticsCard,
            toggleDiagnostics,
            "Activity and memory recorder",
            "Temporarily records bounded memory samples, measured ZoidsTools subsystem calls, recurring refreshes, and frame hitches until stopped."
        )
    end

    local qualityCard = CreateSectionCard(page, "Quality of Life", cardW, 224)
    qualityCard:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    local inviteBanner = ns.UI.CreateCheckbox(
        qualityCard,
        "Mythic+ invitation banner",
        "Shows the invited dungeon and teleport action when available.",
        function() return ns.IsMythicInviteBannerEnabled and ns:IsMythicInviteBannerEnabled() end,
        function(value) if ns.SetMythicInviteBannerEnabled then ns:SetMythicInviteBannerEnabled(value) end end
    )
    PlaceFirst(inviteBanner, qualityCard)

    local instanceLockouts = ns.UI.CreateCheckbox(
        qualityCard,
        "Show instance lockout panel",
        "Shows every active seasonal Mythic+ dungeon with weekly and season bests, base-Mythic loot locks, current raid saves, and collapsed legacy lockouts.",
        function() return ns.IsInstanceLockoutPanelEnabled and ns:IsInstanceLockoutPanelEnabled() end,
        function(value) if ns.SetInstanceLockoutPanelEnabled then ns:SetInstanceLockoutPanelEnabled(value) end end
    )
    PlaceBelow(instanceLockouts, inviteBanner)

    local audioSync = ns.UI.CreateCheckbox(
        qualityCard,
        "Keep audio device synced",
        "Keeps WoW on the Windows default audio device when it changes.",
        function() return ns.IsAudioSyncEnabled and ns:IsAudioSyncEnabled() end,
        function(value) if ns.SetAudioSyncEnabled then ns:SetAudioSyncEnabled(value) end end
    )
    PlaceBelow(audioSync, instanceLockouts)

    local cinematicFastSkip = ns.UI.CreateCheckbox(
        qualityCard,
        "Skip confirm with Escape",
        "Pressing Escape skips cinematics without a confirmation popup.",
        function() return ns.IsCinematicFastSkipEnabled and ns:IsCinematicFastSkipEnabled() end,
        function(value) if ns.SetCinematicFastSkipEnabled then ns:SetCinematicFastSkipEnabled(value) end end
    )
    PlaceBelow(cinematicFastSkip, audioSync)

    local cinematicAutoSkip = ns.UI.CreateCheckbox(
        qualityCard,
        "Auto skip cinematics",
        "Automatically skips cinematics and movies when they start.",
        function() return ns.IsCinematicAutoSkipEnabled and ns:IsCinematicAutoSkipEnabled() end,
        function(value) if ns.SetCinematicAutoSkipEnabled then ns:SetCinematicAutoSkipEnabled(value) end end
    )
    PlaceBelow(cinematicAutoSkip, cinematicFastSkip)

    local mailRolodex = ns.UI.CreateCheckbox(
        qualityCard,
        "Mailbox Rolodex",
        "Adds a character picker to Blizzard's recipient field using characters recorded by the Warband dashboard.",
        function() return ns.IsMailRecipientRolodexEnabled and ns:IsMailRecipientRolodexEnabled() end,
        function(value) if ns.SetMailRecipientRolodexEnabled then ns:SetMailRecipientRolodexEnabled(value) end end
    )
    PlaceBelow(mailRolodex, cinematicAutoSkip)

    local rememberMailRecipient = ns.UI.CreateCheckbox(
        qualityCard,
        "Remember last recipient",
        "After Blizzard confirms a mail was sent, restores that recipient for the next message and lists it at the top of the picker.",
        function() return ns.IsMailLastRecipientEnabled and ns:IsMailLastRecipientEnabled() end,
        function(value) if ns.SetMailLastRecipientEnabled then ns:SetMailLastRecipientEnabled(value) end end
    )
    rememberMailRecipient:SetPoint("TOPLEFT", mailRolodex, "TOPLEFT", 170, 0)

    local talkingHeadCard = CreateSectionCard(page, "Talking Head", cardW, 190)
    talkingHeadCard:SetPoint("TOPLEFT", qualityCard, "BOTTOMLEFT", 0, -10)

    local subtleTalkingHead = ns.UI.CreateCheckbox(
        talkingHeadCard,
        "Use subtle Talking Head",
        "Replaces Blizzard's large Talking Head window with compact subtitles.",
        function() return ns.IsSubtleTalkingHeadEnabled and ns:IsSubtleTalkingHeadEnabled() end,
        function(value) if ns.SetSubtleTalkingHeadEnabled then ns:SetSubtleTalkingHeadEnabled(value) end end
    )
    PlaceFirst(subtleTalkingHead, talkingHeadCard)

    local talkingHeadBackground = ns.UI.CreateCheckbox(
        talkingHeadCard,
        "Show background",
        "Shows the dark subtitle backing panel.",
        function() return ns.GetSubtleTalkingHeadBackground and ns:GetSubtleTalkingHeadBackground() end,
        function(value) if ns.SetSubtleTalkingHeadBackground then ns:SetSubtleTalkingHeadBackground(value) end end
    )
    PlaceBelow(talkingHeadBackground, subtleTalkingHead)

    local talkingHeadBold = ns.UI.CreateCheckbox(
        talkingHeadCard,
        "Bold text",
        "Uses stronger outlined subtitle text.",
        function() return ns.GetSubtleTalkingHeadBold and ns:GetSubtleTalkingHeadBold() end,
        function(value) if ns.SetSubtleTalkingHeadBold then ns:SetSubtleTalkingHeadBold(value) end end
    )
    talkingHeadBold:SetPoint("TOPLEFT", talkingHeadBackground, "TOPLEFT", 155, 0)

    local talkingHeadOpacity = ns.UI.CreateSlider(
        talkingHeadCard,
        "Subtitle opacity",
        "Controls subtitle panel visibility.",
        0.35,
        1,
        0.05,
        function() return ns.GetSubtleTalkingHeadOpacity and ns:GetSubtleTalkingHeadOpacity() or 0.72 end,
        function(value) if ns.SetSubtleTalkingHeadOpacity then ns:SetSubtleTalkingHeadOpacity(value) end end,
        145,
        function(value) return string.format("%d%%", (value or 0.72) * 100) end
    )
    talkingHeadOpacity:SetPoint("TOPLEFT", talkingHeadBackground, "BOTTOMLEFT", 10, -14)

    local talkingHeadFontSize = ns.UI.CreateSlider(
        talkingHeadCard,
        "Font size",
        "Adjusts subtitle text size.",
        11,
        24,
        1,
        function() return ns.GetSubtleTalkingHeadFontSize and ns:GetSubtleTalkingHeadFontSize() or 14 end,
        function(value) if ns.SetSubtleTalkingHeadFontSize then ns:SetSubtleTalkingHeadFontSize(value) end end,
        145,
        function(value) return tostring(math.floor((value or 14) + 0.5)) end
    )
    talkingHeadFontSize:SetPoint("TOPLEFT", talkingHeadOpacity, "TOPRIGHT", 26, 0)

    local previewTalkingHead = CreateButton(talkingHeadCard, "Preview", 104, 27)
    previewTalkingHead:SetPoint("TOPLEFT", talkingHeadOpacity, "BOTTOMLEFT", -10, -12)
    previewTalkingHead:SetScript("OnClick", function()
        if ns.PreviewSubtleTalkingHead then ns:PreviewSubtleTalkingHead() end
    end)

    local moveTalkingHead = CreateButton(talkingHeadCard, "Move", 104, 27)
    moveTalkingHead:SetPoint("LEFT", previewTalkingHead, "RIGHT", 10, 0)
    moveTalkingHead:SetScript("OnClick", function()
        if ns.ToggleSubtleTalkingHeadMoveMode then
            ns:ToggleSubtleTalkingHeadMoveMode()
        end
        if page.Refresh then page:Refresh() end
    end)

    function page:Refresh()
        performanceDisplay:Refresh()
        performanceScale:Refresh()
        coordinatesWidget:Refresh()
        subtleTalkingHead:Refresh()
        talkingHeadBackground:Refresh()
        talkingHeadBold:Refresh()
        talkingHeadOpacity:Refresh()
        talkingHeadFontSize:Refresh()
        inviteBanner:Refresh()
        instanceLockouts:Refresh()
        audioSync:Refresh()
        cinematicFastSkip:Refresh()
        cinematicAutoSkip:Refresh()
        queueSound:Refresh()
        queueCountdown:Refresh()
        safeQueue:Refresh()
        safeDungeonQueue:Refresh()
        mailRolodex:Refresh()
        rememberMailRecipient:Refresh()

        local diagnosticsActive = ns.IsDiagnosticsActive and ns:IsDiagnosticsActive()
        diagnosticsStatus:SetText(ns.GetDiagnosticsStatusText and ns:GetDiagnosticsStatusText() or "Ready | recorder is off")
        toggleDiagnostics:SetText(diagnosticsActive and "Stop" or "Start")
        if ns.UI and ns.UI.SetControlEnabled then
            ns.UI.SetControlEnabled(copyDiagnostics, ns.HasDiagnosticReport and ns:HasDiagnosticReport())
        end

        if ns.UI and ns.UI.SetControlEnabled then
            local talkingHeadActive = subtleTalkingHead:GetChecked() == true
            ns.UI.SetControlEnabled(talkingHeadBackground, talkingHeadActive)
            ns.UI.SetControlEnabled(talkingHeadBold, talkingHeadActive)
            ns.UI.SetControlEnabled(talkingHeadOpacity, talkingHeadActive)
            ns.UI.SetControlEnabled(talkingHeadFontSize, talkingHeadActive)
            ns.UI.SetControlEnabled(previewTalkingHead, talkingHeadActive)
            ns.UI.SetControlEnabled(moveTalkingHead, talkingHeadActive)
        end

        moveTalkingHead:SetText(ns.IsSubtleTalkingHeadMoveMode and ns:IsSubtleTalkingHeadMoveMode() and "Lock" or "Move")

        unlockPerformance:Show()
        if ns.IsPerformanceWidgetLocked and ns:IsPerformanceWidgetLocked() then
            unlockPerformance:SetText("Unlock Widget")
        else
            unlockPerformance:SetText("Lock Widget")
        end
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateChatPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local function Get(key, fallback)
        local value = ns.db and ns.db.chat and ns.db.chat[key]
        return value == nil and fallback or value
    end

    local function Set(key, value)
        if ns.SetChatOption then
            ns:SetChatOption(key, value)
        elseif ns.db and ns.db.chat then
            ns.db.chat[key] = value
        end
        if page.Refresh then page:Refresh() end
    end

    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

    local generalTab = CreateButton(page, "General", 126, 27)
    generalTab:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    local historyTab = CreateButton(page, "History & Input", 150, 27)
    historyTab:SetPoint("LEFT", generalTab, "RIGHT", 10, 0)

    local essentialsCard = CreateSectionCard(page, "Essentials", cardW, 208)
    essentialsCard:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, -42)

    local enabled = UI.CreateCheckbox(
        essentialsCard,
        "Enable chat enhancements",
        "Enables ZoidsTools chat polish while preserving Blizzard chat links and interactions.",
        function() return Get("enabled", true) end,
        function(value) Set("enabled", value) end
    )
    PlaceFirst(enabled, essentialsCard)

    local copyButton = UI.CreateCheckbox(
        essentialsCard,
        "Show chat copy button",
        "Shows the small copy/search button on chat frames.",
        function() return Get("copyButton", true) end,
        function(value) Set("copyButton", value) end
    )
    PlaceBelow(copyButton, enabled)

    local urlCopy = UI.CreateCheckbox(
        essentialsCard,
        "Make web addresses copyable",
        "Turns web and Discord addresses into copyable chat links.",
        function() return Get("urlCopy", true) end,
        function(value) Set("urlCopy", value) end
    )
    PlaceBelow(urlCopy, copyButton)

    local enhancedScroll = UI.CreateCheckbox(
        essentialsCard,
        "Use enhanced chat scrolling",
        "Adds faster Shift-wheel scrolling and Ctrl-wheel jump behavior.",
        function() return Get("enhancedScroll", true) end,
        function(value) Set("enhancedScroll", value) end
    )
    PlaceBelow(enhancedScroll, urlCopy)

    local openCopy = CreateButton(essentialsCard, "Open Chat Copy", 150, 27)
    PlaceBelow(openCopy, enhancedScroll, 0, 10)
    openCopy:SetScript("OnClick", function()
        if ns.ShowChatCopy then
            ns:ShowChatCopy(SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME)
        end
    end)

    local awarenessCard = CreateSectionCard(page, "Message Awareness", cardW, 138)
    awarenessCard:SetPoint("TOPLEFT", essentialsCard, "BOTTOMLEFT", 0, -10)

    local newMessageIndicator = UI.CreateCheckbox(
        awarenessCard,
        "Show new-message button while scrolled up",
        "Shows a jump button when new messages arrive while reading older chat.",
        function() return Get("newMessageIndicator", true) end,
        function(value) Set("newMessageIndicator", value) end
    )
    PlaceFirst(newMessageIndicator, awarenessCard)

    local mentionHighlight = UI.CreateCheckbox(
        awarenessCard,
        "Highlight messages that mention my name",
        "Highlights messages containing your character name.",
        function() return Get("mentionHighlight", true) end,
        function(value) Set("mentionHighlight", value) end
    )
    PlaceBelow(mentionHighlight, newMessageIndicator)

    local mentionSound = UI.CreateCheckbox(
        awarenessCard,
        "Play a sound for mentions",
        "Plays a subtle alert for highlighted mentions.",
        function() return Get("mentionSound", true) end,
        function(value) Set("mentionSound", value) end
    )
    PlaceBelow(mentionSound, mentionHighlight)

    local appearanceCard = CreateSectionCard(page, "Appearance", cardW, 208)
    appearanceCard:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, -42)

    local mouseoverControls = UI.CreateCheckbox(
        appearanceCard,
        "Show chat controls only on mouseover",
        "Fades tabs and chat buttons until the chat frame is hovered.",
        function() return Get("mouseoverControls", false) end,
        function(value) Set("mouseoverControls", value) end
    )
    PlaceFirst(mouseoverControls, appearanceCard)

    local backgroundEnabled = UI.CreateCheckbox(
        appearanceCard,
        "Customize chat background",
        "Lets ZoidsTools control chat background opacity.",
        function() return Get("backgroundEnabled", true) end,
        function(value) Set("backgroundEnabled", value) end
    )
    PlaceBelow(backgroundEnabled, mouseoverControls)

    local backgroundMouseover = UI.CreateCheckbox(
        appearanceCard,
        "Show background only on mouseover",
        "Keeps the background mostly hidden until hover.",
        function() return Get("backgroundMouseover", false) end,
        function(value) Set("backgroundMouseover", value) end
    )
    PlaceBelow(backgroundMouseover, backgroundEnabled)

    local backgroundOpacity = UI.CreateSlider(
        appearanceCard,
        "Background opacity",
        "Controls the chat background opacity.",
        0,
        1,
        0.05,
        function() return tonumber(Get("backgroundOpacity", 0.35)) or 0.35 end,
        function(value) Set("backgroundOpacity", value) end,
        230,
        function(value) return string.format("%d%%", math.floor(((value or 0) * 100) + 0.5)) end
    )
    backgroundOpacity:SetPoint("TOPLEFT", backgroundMouseover, "BOTTOMLEFT", 10, -16)

    local textCard = CreateSectionCard(page, "Text and Fading", cardW, 208)
    textCard:SetPoint("TOPLEFT", appearanceCard, "BOTTOMLEFT", 0, -10)

    local customFont = UI.CreateCheckbox(
        textCard,
        "Use shared chat font size",
        "Applies one font size to Blizzard chat frames.",
        function() return Get("customFont", true) end,
        function(value) Set("customFont", value) end
    )
    PlaceFirst(customFont, textCard)

    local fontSize = UI.CreateSlider(
        textCard,
        "Chat font size",
        "Sets the shared chat font size.",
        9,
        24,
        1,
        function() return tonumber(Get("fontSize", 14)) or 14 end,
        function(value) Set("fontSize", value) end,
        230,
        function(value) return tostring(math.floor((value or 14) + 0.5)) end
    )
    fontSize:SetPoint("TOPLEFT", customFont, "BOTTOMLEFT", 10, -16)

    local fontOutline = UI.CreateCheckbox(
        textCard,
        "Outline chat text",
        "Adds a thin outline to shared chat text.",
        function() return Get("fontOutline", false) end,
        function(value) Set("fontOutline", value) end
    )
    fontOutline:SetPoint("TOPLEFT", fontSize, "BOTTOMLEFT", -10, -16)

    local disableFading = UI.CreateCheckbox(
        textCard,
        "Keep chat messages visible",
        "Disables Blizzard's normal message fade.",
        function() return Get("disableFading", false) end,
        function(value) Set("disableFading", value) end
    )
    PlaceBelow(disableFading, fontOutline)

    local fadeDelay = UI.CreateSlider(
        textCard,
        "Fade delay",
        "Sets how long messages remain visible before fading.",
        10,
        600,
        10,
        function() return tonumber(Get("fadeDelay", 120)) or 120 end,
        function(value) Set("fadeDelay", value) end,
        230,
        function(value) return string.format("%ds", math.floor((value or 120) + 0.5)) end
    )
    fadeDelay:SetPoint("TOPLEFT", disableFading, "BOTTOMLEFT", 10, -16)

    local historyCard = CreateSectionCard(page, "Saved History", cardW, 230)
    historyCard:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, -42)

    local historyEnabled = UI.CreateCheckbox(
        historyCard,
        "Save recent chat between sessions",
        "Stores recent rendered chat lines locally between reloads.",
        function() return Get("historyEnabled", false) end,
        function(value) Set("historyEnabled", value) end
    )
    PlaceFirst(historyEnabled, historyCard)

    local historyRestore = UI.CreateCheckbox(
        historyCard,
        "Restore recent messages at login",
        "Adds recent saved chat back to General on login.",
        function() return Get("historyRestore", false) end,
        function(value) Set("historyRestore", value) end
    )
    PlaceBelow(historyRestore, historyEnabled)

    local historyLimit = UI.CreateSlider(
        historyCard,
        "Saved message limit",
        "Limits saved chat history per character.",
        100,
        500,
        50,
        function() return tonumber(Get("historyLimit", 250)) or 250 end,
        function(value) Set("historyLimit", value) end,
        230,
        function(value) return tostring(math.floor((value or 250) + 0.5)) end
    )
    historyLimit:SetPoint("TOPLEFT", historyRestore, "BOTTOMLEFT", 10, -18)

    local viewHistory = CreateButton(historyCard, "View History", 116, 27)
    viewHistory:SetPoint("TOPLEFT", historyLimit, "BOTTOMLEFT", -10, -16)
    viewHistory:SetScript("OnClick", function()
        if ns.ShowSavedChatHistory then ns:ShowSavedChatHistory() end
    end)

    local clearHistory = CreateButton(historyCard, "Clear History", 116, 27)
    clearHistory:SetPoint("LEFT", viewHistory, "RIGHT", 10, 0)
    clearHistory:SetScript("OnClick", function()
        if ns.ClearSavedChatHistory and ns:ClearSavedChatHistory() then
            ns:Print("Saved chat history cleared for this character.")
        end
    end)

    local inputCard = CreateSectionCard(page, "Typing Box", cardW, 350)
    inputCard:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, -42)

    local styledEditBox = UI.CreateCheckbox(
        inputCard,
        "Style the chat typing box",
        "Uses the ZoidsTools border, spacing, and font controls for the typing box.",
        function() return Get("styledEditBox", true) end,
        function(value) Set("styledEditBox", value) end
    )
    PlaceFirst(styledEditBox, inputCard)

    local editBoxPosition = UI.CreateDropdown(
        inputCard,
        "Typing box position",
        "Controls where the chat typing box attaches.",
        {
            { value = "bottom", text = "Attached Below" },
            { value = "top", text = "Attached Above" },
            { value = "blizzard", text = "Blizzard Default" },
        },
        function()
            local value = Get("editBoxPosition", "bottom")
            return value == "default" and "bottom" or value
        end,
        function(value) Set("editBoxPosition", value) end,
        230
    )
    editBoxPosition:SetPoint("TOPLEFT", styledEditBox, "BOTTOMLEFT", 0, -10)

    local editBoxFont = UI.CreateDropdown(
        inputCard,
        "Typing font",
        "Changes the chat typing-box font.",
        {
            { value = "default", text = "Blizzard Default" },
            { value = "friz", text = "Friz Quadrata" },
            { value = "arial", text = "Arial Narrow" },
            { value = "morpheus", text = "Morpheus" },
            { value = "skurri", text = "Skurri" },
            { value = "damage", text = "Damage" },
        },
        function() return Get("editBoxFont", "default") end,
        function(value) Set("editBoxFont", value) end,
        230
    )
    editBoxFont:SetPoint("TOPLEFT", editBoxPosition, "BOTTOMLEFT", 0, -10)

    local editBoxFontSize = UI.CreateSlider(
        inputCard,
        "Typing font size",
        "Scales typed text and the channel label.",
        10,
        20,
        1,
        function() return tonumber(Get("editBoxFontSize", 14)) or 14 end,
        function(value) Set("editBoxFontSize", value) end,
        230,
        function(value) return tostring(math.floor((value or 14) + 0.5)) end
    )
    editBoxFontSize:SetPoint("TOPLEFT", editBoxFont, "BOTTOMLEFT", 10, -18)

    local arrowKeyHistory = UI.CreateCheckbox(
        inputCard,
        "Use Up and Down for sent-message history",
        "Lets arrow keys recall sent messages while the typing box is focused.",
        function() return Get("arrowKeyHistory", true) end,
        function(value) Set("arrowKeyHistory", value) end
    )
    arrowKeyHistory:SetPoint("TOPLEFT", editBoxFontSize, "BOTTOMLEFT", -10, -18)

    local channelIndicator = UI.CreateCheckbox(
        inputCard,
        "Emphasize the active chat channel",
        "Uses ZoidsTools styling on the Say, Party, Guild, and channel label.",
        function() return Get("channelIndicator", true) end,
        function(value) Set("channelIndicator", value) end
    )
    PlaceBelow(channelIndicator, arrowKeyHistory)

    local generalControls = {
        essentialsCard, enabled, copyButton, urlCopy, enhancedScroll, openCopy,
        awarenessCard, newMessageIndicator, mentionHighlight, mentionSound,
        appearanceCard, mouseoverControls, backgroundEnabled, backgroundMouseover, backgroundOpacity,
        textCard, customFont, fontSize, fontOutline, disableFading, fadeDelay,
    }

    local historyControls = {
        historyCard, historyEnabled, historyRestore, historyLimit, viewHistory, clearHistory,
        inputCard, styledEditBox, editBoxPosition, editBoxFont, editBoxFontSize, arrowKeyHistory, channelIndicator,
    }

    local activePanel = "general"

    local function SetControlsShown(controls, shown)
        for _, control in ipairs(controls) do
            control:SetShown(shown)
        end
    end

    local function ShowPanel(panel)
        activePanel = panel or "general"
        SetControlsShown(generalControls, activePanel == "general")
        SetControlsShown(historyControls, activePanel == "history")
        SetButtonSelected(generalTab, activePanel == "general")
        SetButtonSelected(historyTab, activePanel == "history")
    end

    generalTab:SetScript("OnClick", function() ShowPanel("general") end)
    historyTab:SetScript("OnClick", function() ShowPanel("history") end)

    function page:Refresh()
        enabled:Refresh()
        copyButton:Refresh()
        urlCopy:Refresh()
        enhancedScroll:Refresh()
        newMessageIndicator:Refresh()
        mentionHighlight:Refresh()
        mentionSound:Refresh()
        mouseoverControls:Refresh()
        backgroundEnabled:Refresh()
        backgroundMouseover:Refresh()
        backgroundOpacity:Refresh()
        customFont:Refresh()
        fontSize:Refresh()
        fontOutline:Refresh()
        disableFading:Refresh()
        fadeDelay:Refresh()
        historyEnabled:Refresh()
        historyRestore:Refresh()
        historyLimit:Refresh()
        styledEditBox:Refresh()
        editBoxPosition:Refresh()
        editBoxFont:Refresh()
        editBoxFontSize:Refresh()
        arrowKeyHistory:Refresh()
        channelIndicator:Refresh()

        if UI.SetControlEnabled then
            local active = enabled:GetChecked() == true
            local backgroundActive = active and backgroundEnabled:GetChecked() == true
            local fontActive = active and customFont:GetChecked() == true
            local historyActive = active and historyEnabled:GetChecked() == true
            local inputActive = active and styledEditBox:GetChecked() == true

            UI.SetControlEnabled(copyButton, active)
            UI.SetControlEnabled(urlCopy, active)
            UI.SetControlEnabled(enhancedScroll, active)
            UI.SetControlEnabled(openCopy, active)
            UI.SetControlEnabled(newMessageIndicator, active)
            UI.SetControlEnabled(mentionHighlight, active)
            UI.SetControlEnabled(mentionSound, active and mentionHighlight:GetChecked() == true)
            UI.SetControlEnabled(mouseoverControls, active)
            UI.SetControlEnabled(backgroundEnabled, active)
            UI.SetControlEnabled(backgroundMouseover, backgroundActive)
            UI.SetControlEnabled(backgroundOpacity, backgroundActive)
            UI.SetControlEnabled(customFont, active)
            UI.SetControlEnabled(fontSize, fontActive)
            UI.SetControlEnabled(fontOutline, fontActive)
            UI.SetControlEnabled(disableFading, active)
            UI.SetControlEnabled(fadeDelay, active and not disableFading:GetChecked())
            UI.SetControlEnabled(historyEnabled, active)
            UI.SetControlEnabled(historyRestore, historyActive)
            UI.SetControlEnabled(historyLimit, historyActive)
            UI.SetControlEnabled(viewHistory, active)
            UI.SetControlEnabled(clearHistory, active)
            UI.SetControlEnabled(styledEditBox, active)
            UI.SetControlEnabled(editBoxPosition, inputActive)
            UI.SetControlEnabled(editBoxFont, inputActive)
            UI.SetControlEnabled(editBoxFontSize, inputActive)
            UI.SetControlEnabled(arrowKeyHistory, active)
            UI.SetControlEnabled(channelIndicator, active)
        end

        ShowPanel(activePanel)
    end

    ShowPanel("general")
    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateMountsPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

    local function RefreshDropdownOptions(control, getter)
        if control and control.SetOptions then
            control:SetOptions(getter and getter() or {})
        end
        if control and control.Refresh then
            control:Refresh()
        end
    end

    local smartCard = CreateSectionCard(page, "Smart Mount", cardW, 390)
    smartCard:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, 0)

    local enabled = UI.CreateCheckbox(
        smartCard,
        "Enable smart mount",
        "Enables the ZoidsTools smart mount keybind and macro support.",
        function() return ns.GetMountsEnabled and ns:GetMountsEnabled() end,
        function(value) if ns.SetMountsEnabled then ns:SetMountsEnabled(value) end end
    )
    PlaceFirst(enabled, smartCard)

    local preferredStatus = smartCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    preferredStatus:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 4, -12)
    preferredStatus:SetWidth(cardW - 40)
    preferredStatus:SetJustifyH("LEFT")
    preferredStatus:SetTextColor(0.78, 0.78, 0.72)

    local resetRotation = CreateButton(smartCard, "Reset Rotation", 132, 27)
    resetRotation:SetPoint("TOPLEFT", preferredStatus, "BOTTOMLEFT", -4, -14)
    resetRotation:SetScript("OnClick", function()
        if ns.ClearMountRecentHistory then
            ns:ClearMountRecentHistory()
        end
        if page.Refresh then page:Refresh() end
    end)

    local recentAvoid = UI.CreateSlider(
        smartCard,
        "Avoid recent mounts",
        "Avoids recently used random mounts when possible.",
        0,
        10,
        1,
        function() return ns.GetMountRecentAvoidCount and ns:GetMountRecentAvoidCount() or 0 end,
        function(value) if ns.SetMountRecentAvoidCount then ns:SetMountRecentAvoidCount(value) end end,
        230,
        function(value) return tostring(math.floor((value or 0) + 0.5)) end
    )
    recentAvoid:SetPoint("TOPLEFT", resetRotation, "BOTTOMLEFT", 10, -16)

    local preferGround = UI.CreateCheckbox(
        smartCard,
        "Prefer ground in no-fly areas",
        "Uses ground mounts in no-fly areas when possible.",
        function() return ns.GetMountOption and ns:GetMountOption("preferGroundWhenNotFlyable") end,
        function(value) if ns.SetMountOption then ns:SetMountOption("preferGroundWhenNotFlyable", value) end end
    )
    preferGround:SetPoint("TOPLEFT", recentAvoid, "BOTTOMLEFT", -10, -18)

    local surfaceWater = UI.CreateCheckbox(
        smartCard,
        "Water mounts at surface",
        "Uses water mounts at the water surface when flying is unavailable.",
        function() return ns.GetMountOption and ns:GetMountOption("useWaterMountsOnSurface") end,
        function(value) if ns.SetMountOption then ns:SetMountOption("useWaterMountsOnSurface", value) end end
    )
    PlaceBelow(surfaceWater, preferGround)

    local excludeService = UI.CreateCheckbox(
        smartCard,
        "Skip service mounts in random",
        "Keeps repair, auction house, and ride-along mounts out of normal smart random picks.",
        function() return ns.GetMountOption and ns:GetMountOption("excludeServiceMountsFromRandom") end,
        function(value) if ns.SetMountOption then ns:SetMountOption("excludeServiceMountsFromRandom", value) end end
    )
    PlaceBelow(excludeService, surfaceWater)

    local classOptions = UI.CreateMultiSelectDropdown(
        smartCard,
        "Class utilities",
        "Adds class and race utility spells to the smart mount keybind.",
        {
            {
                text = "Druid Travel Form",
                shortText = "Travel",
                tooltip = "Uses Travel Form outdoors when available.",
                getter = function() return ns.GetMountClassOption and ns:GetMountClassOption("useDruidTravelForm") end,
                setter = function(value) if ns.SetMountClassOption then ns:SetMountClassOption("useDruidTravelForm", value) end end,
            },
            {
                text = "Druid Cat Form indoors",
                shortText = "Cat",
                tooltip = "Uses Cat Form indoors when mount behavior cannot run.",
                getter = function() return ns.GetMountClassOption and ns:GetMountClassOption("useDruidCatForm") end,
                setter = function(value) if ns.SetMountClassOption then ns:SetMountClassOption("useDruidCatForm", value) end end,
            },
            {
                text = "Dracthyr Soar",
                shortText = "Soar",
                tooltip = "Uses Soar in flyable outdoor areas when available.",
                getter = function() return ns.GetMountClassOption and ns:GetMountClassOption("useDracthyrSoar") end,
                setter = function(value) if ns.SetMountClassOption then ns:SetMountClassOption("useDracthyrSoar", value) end end,
            },
            {
                text = "Falling rescue",
                shortText = "Rescue",
                tooltip = "Uses fall-safety spells such as Slow Fall, Levitate, Glide, Flap, or Zen Flight.",
                getter = function() return ns.GetMountClassOption and ns:GetMountClassOption("useFallingRescue") end,
                setter = function(value) if ns.SetMountClassOption then ns:SetMountClassOption("useFallingRescue", value) end end,
            },
        },
        302
    )
    classOptions:SetPoint("TOPLEFT", excludeService, "BOTTOMLEFT", 0, -18)

    local serviceCard = CreateSectionCard(page, "Service Mounts", cardW, 390)
    serviceCard:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local repairOptions = function() return ns.GetMountServiceOptions and ns:GetMountServiceOptions("repair") or {} end
    local repair = UI.CreateDropdown(
        serviceCard,
        "Repair mount",
        "Preferred repair/vendor mount. Default Priority uses the built-in service order.",
        repairOptions(),
        function() return ns.GetPreferredServiceMount and ns:GetPreferredServiceMount("repair") or "" end,
        function(value) if ns.SetPreferredServiceMount then ns:SetPreferredServiceMount("repair", value) end end,
        250
    )
    PlaceFirst(repair, serviceCard)

    local auctionOptions = function() return ns.GetMountServiceOptions and ns:GetMountServiceOptions("auctionHouse") or {} end
    local auctionHouse = UI.CreateDropdown(
        serviceCard,
        "Auction house mount",
        "Preferred auction house mount. Default Priority uses the built-in AH mount order.",
        auctionOptions(),
        function() return ns.GetPreferredServiceMount and ns:GetPreferredServiceMount("auctionHouse") or "" end,
        function(value) if ns.SetPreferredServiceMount then ns:SetPreferredServiceMount("auctionHouse", value) end end,
        250
    )
    auctionHouse:SetPoint("TOPLEFT", repair, "BOTTOMLEFT", 0, -10)

    local rideAlongOptions = function() return ns.GetMountServiceOptions and ns:GetMountServiceOptions("rideAlong") or {} end
    local rideAlong = UI.CreateDropdown(
        serviceCard,
        "Ride-along mount",
        "Preferred passenger mount. Default Priority chooses from eligible ride-along mounts.",
        rideAlongOptions(),
        function() return ns.GetPreferredServiceMount and ns:GetPreferredServiceMount("rideAlong") or "" end,
        function(value) if ns.SetPreferredServiceMount then ns:SetPreferredServiceMount("rideAlong", value) end end,
        250
    )
    rideAlong:SetPoint("TOPLEFT", auctionHouse, "BOTTOMLEFT", 0, -10)

    local matchLabel = serviceCard:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    matchLabel:SetPoint("TOPLEFT", rideAlong, "BOTTOMLEFT", 0, -16)
    matchLabel:SetText("Target Match")
    matchLabel:SetTextColor(1, 0.82, 0.18)

    local matchEnabled = UI.CreateCheckbox(
        serviceCard,
        "Enable matching",
        "Allows the keybind or button to summon your target's mount when you own it.",
        function() return ns.GetMountMatchEnabled and ns:GetMountMatchEnabled() end,
        function(value) if ns.SetMountMatchEnabled then ns:SetMountMatchEnabled(value) end end
    )
    matchEnabled:SetPoint("TOPLEFT", matchLabel, "BOTTOMLEFT", 0, -12)

    local showMatchButton = UI.CreateCheckbox(
        serviceCard,
        "Show floating button",
        "Shows a movable button for matching your target's mount.",
        function() return ns.GetTargetMatchButtonShown and ns:GetTargetMatchButtonShown() end,
        function(value) if ns.SetTargetMatchButtonShown then ns:SetTargetMatchButtonShown(value) end end
    )
    PlaceBelow(showMatchButton, matchEnabled)

    local matchButton = CreateButton(serviceCard, "Match Target", 126, 27)
    matchButton:SetPoint("TOPLEFT", showMatchButton, "BOTTOMLEFT", 0, -14)
    matchButton:SetScript("OnClick", function()
        if ZoidsToolsMounts and ZoidsToolsMounts.MatchTargetMount then
            ZoidsToolsMounts.MatchTargetMount()
        end
        if page.Refresh then page:Refresh() end
    end)

    local matchStatus = serviceCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    matchStatus:SetPoint("TOPLEFT", matchButton, "BOTTOMLEFT", 0, -12)
    matchStatus:SetWidth(cardW - 36)
    matchStatus:SetJustifyH("LEFT")
    matchStatus:SetTextColor(0.78, 0.78, 0.72)

    function page:Refresh()
        enabled:Refresh()
        recentAvoid:Refresh()
        preferGround:Refresh()
        surfaceWater:Refresh()
        excludeService:Refresh()
        classOptions:Refresh()
        RefreshDropdownOptions(repair, repairOptions)
        RefreshDropdownOptions(auctionHouse, auctionOptions)
        RefreshDropdownOptions(rideAlong, rideAlongOptions)
        matchEnabled:Refresh()
        showMatchButton:Refresh()

        local preferredName = ns.GetPreferredMountName and ns:GetPreferredMountName()
        preferredStatus:SetText("Preferred: " .. (preferredName or "Default Random Behavior"))
        local match = ns.GetTargetMountMatch and ns:GetTargetMountMatch()
        matchStatus:SetText(match and match.status or "Select a mounted target.")

        if UI.SetControlEnabled then
            local active = enabled:GetChecked() == true
            UI.SetControlEnabled(resetRotation, active)
            UI.SetControlEnabled(recentAvoid, active)
            UI.SetControlEnabled(preferGround, active)
            UI.SetControlEnabled(surfaceWater, active)
            UI.SetControlEnabled(excludeService, active)
            UI.SetControlEnabled(classOptions, active)
            UI.SetControlEnabled(repair, active)
            UI.SetControlEnabled(auctionHouse, active)
            UI.SetControlEnabled(rideAlong, active)
            UI.SetControlEnabled(matchEnabled, active)
            UI.SetControlEnabled(showMatchButton, active and matchEnabled:GetChecked() == true)
            UI.SetControlEnabled(matchButton, active and matchEnabled:GetChecked() == true)
        end
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local WINDOWS_RESET_POPUP_KEY = "ZOIDSTOOLS_RESET_WINDOWS"

StaticPopupDialogs[WINDOWS_RESET_POPUP_KEY] = StaticPopupDialogs[WINDOWS_RESET_POPUP_KEY] or {
    text = "Reset saved ZoidsTools window positions?",
    button1 = YES or "Yes",
    button2 = CANCEL or "Cancel",
    OnAccept = function()
        if ns.ResetMovableWindowPositions then
            ns:ResetMovableWindowPositions()
        end

        if ns.UI and ns.UI.RefreshVisiblePage then
            ns.UI.RefreshVisiblePage()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CreateTooltipsPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local rightX = cardW + 14

    local appearance = CreateSectionCard(page, "Appearance", cardW, 150)
    appearance:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    local classColoredNames = UI.CreateCheckbox(
        appearance,
        "Class-colored names",
        "Colors player names on mouseover tooltips using their class color.",
        function() return ns.IsTooltipClassColoredNamesEnabled and ns:IsTooltipClassColoredNamesEnabled() end,
        function(value) if ns.SetTooltipClassColoredNamesEnabled then ns:SetTooltipClassColoredNamesEnabled(value) end end
    )
    PlaceFirst(classColoredNames, appearance)

    local playerDetails = CreateSectionCard(page, "Player Details", cardW, 150)
    playerDetails:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local mythicRating = UI.CreateCheckbox(
        playerDetails,
        "Show Mythic+ rating",
        "Shows the player's current Mythic+ rating with Blizzard's rating color.",
        function() return ns.IsTooltipMythicScoreEnabled and ns:IsTooltipMythicScoreEnabled() end,
        function(value) if ns.SetTooltipMythicScoreEnabled then ns:SetTooltipMythicScoreEnabled(value) end end
    )
    PlaceFirst(mythicRating, playerDetails)

    local itemLevel = UI.CreateCheckbox(
        playerDetails,
        "Show item level",
        "Shows equipped item level when player inspection data is available.",
        function() return ns.IsTooltipItemLevelEnabled and ns:IsTooltipItemLevelEnabled() end,
        function(value) if ns.SetTooltipItemLevelEnabled then ns:SetTooltipItemLevelEnabled(value) end end
    )
    PlaceBelow(itemLevel, mythicRating)

    function page:Refresh()
        classColoredNames:Refresh()
        mythicRating:Refresh()
        itemLevel:Refresh()
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateWindowsPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

    local movement = CreateSectionCard(page, "Movement", cardW, 260)
    movement:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, 0)

    local windowsEnabled = UI.CreateCheckbox(
        movement,
        "Make Blizzard windows movable",
        "Allows supported Blizzard interface panels to be repositioned. Drag the minimized World Map by its title bar.",
        function() return ns.db and ns.db.windows and ns.db.windows.enabled end,
        function(value)
            ns.db.windows.enabled = value

            if value and ns.InitializeMovableWindows then
                ns:InitializeMovableWindows()
            end

            if ns.RefreshMovableWindows then
                ns:RefreshMovableWindows()
            end
        end
    )
    PlaceFirst(windowsEnabled, movement)

    local bagsEnabled = UI.CreateCheckbox(
        movement,
        "Move default bag windows",
        "Adds drag handles to default backpack, bag, bank, and reagent bank windows.",
        function() return ns.db and ns.db.windows and ns.db.windows.moveBags end,
        function(value)
            ns.db.windows.moveBags = value

            if ns.RefreshBagMovement then
                ns:RefreshBagMovement()
            end
        end
    )
    PlaceBelow(bagsEnabled, windowsEnabled)

    local bagHandles = UI.CreateCheckbox(
        movement,
        "Show bag drag handles",
        "Shows the small movement handle across the top of movable bag windows.",
        function() return ns.db and ns.db.windows and ns.db.windows.showBagHandles end,
        function(value)
            ns.db.windows.showBagHandles = value

            if ns.RefreshBagMovement then
                ns:RefreshBagMovement()
            end
        end
    )
    PlaceBelow(bagHandles, bagsEnabled)

    local savePositions = UI.CreateCheckbox(
        movement,
        "Remember moved positions",
        "Keeps moved windows at their saved positions after closing and reopening them.",
        function() return ns.db and ns.db.windows and ns.db.windows.savePositions end,
        function(value) ns.db.windows.savePositions = value end
    )
    PlaceBelow(savePositions, bagHandles)

    local scaleEnabled = UI.CreateCheckbox(
        movement,
        "Ctrl-scroll scales windows",
        "Hold Ctrl and use the mouse wheel over a movable window or its move handle to adjust scale. The World Map is position-only.",
        function() return ns.db and ns.db.windows and ns.db.windows.scaleEnabled end,
        function(value) ns.db.windows.scaleEnabled = value end
    )
    PlaceBelow(scaleEnabled, savePositions)

    local actions = CreateSectionCard(page, "Actions", cardW, 190)
    actions:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local refreshButton = CreateButton(actions, "Refresh", 108, 27)
    PlaceFirst(refreshButton, actions)
    refreshButton:SetScript("OnClick", function()
        if ns.RefreshMovableWindows then
            ns:RefreshMovableWindows()
        end

        if page.Refresh then
            page:Refresh()
        end
    end)

    local resetButton = CreateButton(actions, "Reset Positions", 144, 27)
    resetButton:SetPoint("LEFT", refreshButton, "RIGHT", 10, 0)
    resetButton:SetScript("OnClick", function()
        StaticPopup_Show(WINDOWS_RESET_POPUP_KEY)
    end)

    local resetScalesButton = CreateButton(actions, "Reset Scales", 132, 27)
    resetScalesButton:SetPoint("TOPLEFT", refreshButton, "BOTTOMLEFT", 0, -12)
    resetScalesButton:SetScript("OnClick", function()
        if ns.ResetMovableWindowScales then
            ns:ResetMovableWindowScales()
        end

        if page.Refresh then
            page:Refresh()
        end
    end)

    local status = actions:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", resetScalesButton, "BOTTOMLEFT", 0, -18)
    status:SetWidth(cardW - 36)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.78, 0.78, 0.72)

    function page:Refresh()
        windowsEnabled:Refresh()
        bagsEnabled:Refresh()
        bagHandles:Refresh()
        savePositions:Refresh()
        scaleEnabled:Refresh()

        local active = windowsEnabled:GetChecked() == true
        if UI.SetControlEnabled then
            UI.SetControlEnabled(bagsEnabled, active)
            UI.SetControlEnabled(bagHandles, active and bagsEnabled:GetChecked() == true)
            UI.SetControlEnabled(savePositions, active)
            UI.SetControlEnabled(scaleEnabled, active)
            UI.SetControlEnabled(refreshButton, active)
            UI.SetControlEnabled(resetButton, active)
            UI.SetControlEnabled(resetScalesButton, active)
        end

        local windowCount, bagCount, scaleCount = 0, 0, 0
        if ns.GetMovableWindowStats then
            windowCount, bagCount, scaleCount = ns:GetMovableWindowStats()
        end

        status:SetText("Tracked windows: " .. windowCount .. "\nBag windows: " .. bagCount .. "\nSaved scales: " .. scaleCount)
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateItemsPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local dropdownWidth = 300
    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

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

                if page.Refresh then
                    page:Refresh()
                end
            end,
        }
    end

    local general = CreateSectionCard(page, "General", cardW, 240)
    general:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, 0)

    local enabled = UI.CreateCheckbox(
        general,
        "Enable item overlays",
        "Shows ZoidsTools item information on character slots, bags, bank, and warband bank item buttons.",
        function() return ns.GetItemOverlaysEnabled and ns:GetItemOverlaysEnabled() end,
        function(value)
            if ns.SetItemOverlaysEnabled then
                ns:SetItemOverlaysEnabled(value)
            end

            if page.Refresh then
                page:Refresh()
            end
        end
    )
    PlaceFirst(enabled, general)

    local statTargetContext = UI.CreateDropdown(
        general,
        "Stat goal source",
        "Chooses which available per-spec recommended stat goal set to compare against.",
        {
            { value = "mythicplus", text = "Mythic+" },
            { value = "raid", text = "Raid" },
            { value = "pvp", text = "PvP" },
        },
        function() return ns.GetStatTargetContext and ns:GetStatTargetContext() or "mythicplus" end,
        function(value)
            if ns.SetStatTargetContext then
                ns:SetStatTargetContext(value)
            end

            if page.Refresh then
                page:Refresh()
            end
        end,
        dropdownWidth
    )
    statTargetContext:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -16)

    local bisEnabled = UI.CreateCheckbox(
        general,
        "Show BiS rankings in item tooltips",
        "Adds the current spec's top-three offline GearInsight recommendations to equippable item tooltips.",
        function() return ns.GetBiSTooltipsEnabled and ns:GetBiSTooltipsEnabled() end,
        function(value)
            if ns.SetBiSTooltipsEnabled then
                ns:SetBiSTooltipsEnabled(value)
            end

            if page.Refresh then
                page:Refresh()
            end
        end
    )
    bisEnabled:SetPoint("TOPLEFT", statTargetContext, "BOTTOMLEFT", 0, -16)

    local bisContext = UI.CreateDropdown(
        general,
        "BiS content",
        "Chooses whether item tooltips show Raid or Mythic+ top-three gear rankings.",
        {
            { value = "raid", text = "Raid" },
            { value = "mythicplus", text = "Mythic+" },
        },
        function() return ns.GetBiSContext and ns:GetBiSContext() or "mythicplus" end,
        function(value)
            if ns.SetBiSContext then
                ns:SetBiSContext(value)
            end
        end,
        dropdownWidth
    )
    bisContext:SetPoint("TOPLEFT", bisEnabled, "BOTTOMLEFT", 0, -16)

    local display = CreateSectionCard(page, "Display", cardW, 170)
    display:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local characterOptions = UI.CreateMultiSelectDropdown(
        display,
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
    PlaceFirst(characterOptions, display)

    local bagBankOptions = UI.CreateMultiSelectDropdown(
        display,
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
    bagBankOptions:SetPoint("TOPLEFT", characterOptions, "BOTTOMLEFT", 0, -16)

    local style = CreateSectionCard(page, "Style", cardW, 164)
    style:SetPoint("TOPLEFT", general, "BOTTOMLEFT", 0, -14)

    local fontSize = UI.CreateSlider(
        style,
        "Overlay text size",
        "Changes item level, bind, and enchant overlay text size.",
        8,
        20,
        1,
        function() return ns.GetItemOverlayFontSize and ns:GetItemOverlayFontSize() or 12 end,
        function(value) if ns.SetItemOverlayFontSize then ns:SetItemOverlayFontSize(value) end end,
        260,
        function(value) return tostring(math.floor((value or 12) + 0.5)) end
    )
    PlaceFirst(fontSize, style, 24, -46)

    local qualityColor = UI.CreateCheckbox(
        style,
        "Use item quality color",
        "Colors item level text by item quality.",
        function() return ns.GetItemOverlayQualityColor and ns:GetItemOverlayQualityColor() end,
        function(value) if ns.SetItemOverlayQualityColor then ns:SetItemOverlayQualityColor(value) end end
    )
    qualityColor:SetPoint("TOPLEFT", fontSize, "BOTTOMLEFT", -8, -18)

    local refreshButton = CreateButton(style, "Refresh Item Info", 150, 27)
    refreshButton:SetPoint("TOPLEFT", qualityColor, "BOTTOMLEFT", 0, -14)
    refreshButton:SetScript("OnClick", function()
        if ns.RefreshItemOverlays then
            ns:RefreshItemOverlays()
        end
    end)

    local statusCard = CreateSectionCard(page, "Generated Data Status", cardW, 240)
    statusCard:SetPoint("TOPLEFT", display, "BOTTOMLEFT", 0, -14)

    local status = statusCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", statusCard, "TOPLEFT", 18, -42)
    status:SetWidth(cardW - 36)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.78, 0.78, 0.72)

    function page:Refresh()
        enabled:Refresh()
        characterOptions:Refresh()
        bagBankOptions:Refresh()
        statTargetContext:Refresh()
        bisEnabled:Refresh()
        bisContext:Refresh()
        fontSize:Refresh()
        qualityColor:Refresh()

        local active = enabled:GetChecked() == true
        if UI.SetControlEnabled then
            UI.SetControlEnabled(characterOptions, active)
            UI.SetControlEnabled(bagBankOptions, active)
            UI.SetControlEnabled(statTargetContext, active)
            UI.SetControlEnabled(bisEnabled, active)
            UI.SetControlEnabled(bisContext, active and bisEnabled:GetChecked() == true)
            UI.SetControlEnabled(fontSize, active)
            UI.SetControlEnabled(qualityColor, active)
            UI.SetControlEnabled(refreshButton, active)
        end

        local statusLines = {}
        if ns.GetStatTargetStatusText then
            statusLines[#statusLines + 1] = ns:GetStatTargetStatusText()
        end
        if ns.GetBiSDataStatusText then
            statusLines[#statusLines + 1] = ns:GetBiSDataStatusText()
        end
        status:SetText(table.concat(statusLines, "\n\n"))
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateProfessionsPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

    local main = CreateSectionCard(page, "Profession Action", cardW, 190)
    main:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, 0)

    local enabled = UI.CreateCheckbox(
        main,
        "Enable profession helper",
        "Shows a Molinari-style action glow on profession items that can be disenchanted, milled, prospected, or opened.",
        function() return ns.GetProfessionHelperEnabled and ns:GetProfessionHelperEnabled() end,
        function(value)
            if ns.SetProfessionHelperEnabled then
                ns:SetProfessionHelperEnabled(value)
            end

            if page.Refresh then
                page:Refresh()
            end
        end
    )
    PlaceFirst(enabled, main)

    local activation = UI.CreateDropdown(
        main,
        "Modifier",
        "Choose which modifier you hold while clicking the item.",
        ns.GetProfessionHelperActivationOptions and ns:GetProfessionHelperActivationOptions() or {
            { value = "alt", text = "Alt" },
            { value = "altctrl", text = "Alt + Ctrl" },
            { value = "altshift", text = "Alt + Shift" },
        },
        function() return ns.GetProfessionHelperActivation and ns:GetProfessionHelperActivation() or "alt" end,
        function(value)
            if ns.SetProfessionHelperActivation then
                ns:SetProfessionHelperActivation(value)
            end

            if page.Refresh then
                page:Refresh()
            end
        end,
        280
    )
    activation:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -16)

    local actions = CreateSectionCard(page, "Actions", cardW, 190)
    actions:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local disenchant = UI.CreateCheckbox(
        actions,
        "Disenchant gear",
        "Prepares Disenchant for eligible uncommon, rare, and epic equipment.",
        function() return ns.GetProfessionHelperActionEnabled and ns:GetProfessionHelperActionEnabled("disenchant") end,
        function(value) if ns.SetProfessionHelperActionEnabled then ns:SetProfessionHelperActionEnabled("disenchant", value) end end
    )
    PlaceFirst(disenchant, actions)

    local mill = UI.CreateCheckbox(
        actions,
        "Mill herbs",
        "Prepares the matching Milling recipe for supported herb stacks.",
        function() return ns.GetProfessionHelperActionEnabled and ns:GetProfessionHelperActionEnabled("mill") end,
        function(value) if ns.SetProfessionHelperActionEnabled then ns:SetProfessionHelperActionEnabled("mill", value) end end
    )
    PlaceBelow(mill, disenchant)

    local prospect = UI.CreateCheckbox(
        actions,
        "Prospect ore",
        "Prepares the matching Prospecting recipe for supported ore stacks.",
        function() return ns.GetProfessionHelperActionEnabled and ns:GetProfessionHelperActionEnabled("prospect") end,
        function(value) if ns.SetProfessionHelperActionEnabled then ns:SetProfessionHelperActionEnabled("prospect", value) end end
    )
    PlaceBelow(prospect, mill)

    local open = UI.CreateCheckbox(
        actions,
        "Open lockboxes",
        "Prepares Pick Lock, compatible racial unlocks, or usable skeleton keys for supported lockboxes.",
        function() return ns.GetProfessionHelperActionEnabled and ns:GetProfessionHelperActionEnabled("open") end,
        function(value) if ns.SetProfessionHelperActionEnabled then ns:SetProfessionHelperActionEnabled("open", value) end end
    )
    PlaceBelow(open, prospect)

    local statusCard = CreateSectionCard(page, "Status", (cardW * 2) + 14, 120)
    statusCard:SetPoint("TOPLEFT", main, "BOTTOMLEFT", 0, -14)

    local status = statusCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", statusCard, "TOPLEFT", 18, -42)
    status:SetWidth((cardW * 2) - 22)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.78, 0.78, 0.72)

    function page:Refresh()
        enabled:Refresh()
        activation:Refresh()
        disenchant:Refresh()
        mill:Refresh()
        prospect:Refresh()
        open:Refresh()

        local active = enabled:GetChecked() == true
        if UI.SetControlEnabled then
            UI.SetControlEnabled(activation, active)
            UI.SetControlEnabled(disenchant, active)
            UI.SetControlEnabled(mill, active)
            UI.SetControlEnabled(prospect, active)
            UI.SetControlEnabled(open, active)
        end

        if ns.GetProfessionHelperStatusText then
            status:SetText(ns:GetProfessionHelperStatusText())
        else
            status:SetText("")
        end
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateTalentsPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

    local main = CreateSectionCard(page, "Talent Panel", cardW, 170)
    main:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, 0)

    local enabled = UI.CreateCheckbox(
        main,
        "Show talent frame controls",
        "Shows the ZoidsTools talent controls on the Blizzard talents pane.",
        function() return ns.GetTalentGrimoireEnabled and ns:GetTalentGrimoireEnabled() end,
        function(value)
            if ns.SetTalentGrimoireEnabled then
                ns:SetTalentGrimoireEnabled(value)
            end

            if page.Refresh then
                page:Refresh()
            end
        end
    )
    PlaceFirst(enabled, main)

    local status = main:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 4, -14)
    status:SetWidth(cardW - 40)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.78, 0.78, 0.72)

    local selection = CreateSectionCard(page, "Selection", cardW, 170)
    selection:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local contentButton = CreateButton(selection, "Content", 160, 27)
    PlaceFirst(contentButton, selection)
    contentButton:SetScript("OnClick", function()
        if ns.CycleTalentGrimoireContent then
            ns:CycleTalentGrimoireContent()
        end

        if page.Refresh then
            page:Refresh()
        end
    end)

    local targetButton = CreateButton(selection, "Target", 180, 27)
    targetButton:SetPoint("LEFT", contentButton, "RIGHT", 10, 0)
    targetButton:SetScript("OnClick", function()
        if ns.CycleTalentGrimoireTarget then
            ns:CycleTalentGrimoireTarget()
        end

        if page.Refresh then
            page:Refresh()
        end
    end)

    local modeButton = CreateButton(selection, "Mode", 160, 27)
    modeButton:SetPoint("TOPLEFT", contentButton, "BOTTOMLEFT", 0, -12)
    modeButton:SetScript("OnClick", function()
        if ns.CycleTalentGrimoireMode then
            ns:CycleTalentGrimoireMode()
        end

        if page.Refresh then
            page:Refresh()
        end
    end)

    local refreshButton = CreateButton(selection, "Refresh Panel", 180, 27)
    refreshButton:SetPoint("LEFT", modeButton, "RIGHT", 10, 0)
    refreshButton:SetScript("OnClick", function()
        if ns.RefreshTalentGrimoire then
            ns:RefreshTalentGrimoire()
        end

        if page.Refresh then
            page:Refresh()
        end
    end)

    local help = CreateSectionCard(page, "How It Works", (cardW * 2) + 14, 135)
    help:SetPoint("TOPLEFT", main, "BOTTOMLEFT", 0, -14)

    local helpText = help:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    helpText:SetPoint("TOPLEFT", help, "TOPLEFT", 18, -42)
    helpText:SetWidth((cardW * 2) - 22)
    helpText:SetJustifyH("LEFT")
    helpText:SetTextColor(0.78, 0.78, 0.72)
    helpText:SetText("These controls appear inside Blizzard's talent window. Use the selectors here or directly on the talent panel, then apply the suggested build from the Blizzard talent UI.")

    function page:Refresh()
        enabled:Refresh()
        local active = enabled:GetChecked() == true

        if UI.SetControlEnabled then
            UI.SetControlEnabled(contentButton, active)
            UI.SetControlEnabled(targetButton, active)
            UI.SetControlEnabled(modeButton, active)
            UI.SetControlEnabled(refreshButton, active)
        end

        if ns.GetTalentGrimoireStatusText then
            status:SetText(ns:GetTalentGrimoireStatusText())
        else
            status:SetText("")
        end

        if ns.GetTalentGrimoireContentType then
            local contentType = ns:GetTalentGrimoireContentType()
            local label = "Mythic+"

            if contentType == "raid" then
                label = "Raid"
            elseif contentType == "pvp" then
                label = "PvP"
            end

            contentButton:SetText("Content: " .. label)
        end

        if ns.GetTalentGrimoireTargetLabel then
            targetButton:SetText("Target: " .. tostring(ns:GetTalentGrimoireTargetLabel()))
        end

        if ns.GetTalentGrimoireModeLabel then
            modeButton:SetText("Mode: " .. tostring(ns:GetTalentGrimoireModeLabel()))
        end
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local METER_PROFILE_CREATE_POPUP = "ZOIDSTOOLS_CREATE_DAMAGE_METER_PROFILE"
local METER_PROFILE_DELETE_POPUP = "ZOIDSTOOLS_DELETE_DAMAGE_METER_PROFILE"

if StaticPopupDialogs then
    StaticPopupDialogs[METER_PROFILE_CREATE_POPUP] = StaticPopupDialogs[METER_PROFILE_CREATE_POPUP] or {
        text = "Name this damage meter layout:",
        button1 = SAVE or "Save",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        maxLetters = 40,
        OnShow = function(self)
            local editBox = self.EditBox or self.editBox
            if editBox then
                editBox:SetText("")
                editBox:SetFocus()
            end
        end,
        OnAccept = function(self, data)
            local editBox = self.EditBox or self.editBox
            local ok, message = ns:CreateDamageMeterProfile(editBox and editBox:GetText() or "")
            if ok then
                ns:Print("Damage meter profile created and saved.")
            elseif message then
                ns:Print(message)
            end
            if data and data.page and data.page.Refresh then data.page:Refresh() end
        end,
        EditBoxOnEnterPressed = function(self)
            local popup = self:GetParent()
            if popup and popup.button1 then popup.button1:Click() end
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs[METER_PROFILE_DELETE_POPUP] = StaticPopupDialogs[METER_PROFILE_DELETE_POPUP] or {
        text = "Delete the damage meter profile |cffffd24a%s|r?",
        button1 = DELETE or "Delete",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            local ok, message = ns:DeleteDamageMeterProfile(data and data.key)
            if ok then
                ns:Print("Damage meter profile deleted.")
            elseif message then
                ns:Print(message)
            end
            if data and data.page and data.page.Refresh then data.page:Refresh() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

local function CreateMetersPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

    local custom = CreateSectionCard(page, "ZoidsTools Damage Meter", cardW, 330)
    custom:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, 0)

    local customEnabled = UI.CreateCheckbox(
        custom,
        "Enable basic ZoidsTools damage meter",
        "Shows a lightweight custom window using Blizzard's built-in damage meter data.",
        function() return ns.GetCustomDamageMeterEnabled and ns:GetCustomDamageMeterEnabled() or false end,
        function(value)
            if ns.SetCustomDamageMeterEnabled then ns:SetCustomDamageMeterEnabled(value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceFirst(customEnabled, custom)

    local secondWindowEnabled = UI.CreateCheckbox(
        custom,
        "Enable second meter window",
        "Creates another independently selectable meter. Its initial size matches window 1.",
        function() return ns.GetCustomDamageMeterSecondWindowEnabled and ns:GetCustomDamageMeterSecondWindowEnabled() or false end,
        function(value)
            if ns.SetCustomDamageMeterSecondWindowEnabled then ns:SetCustomDamageMeterSecondWindowEnabled(value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceBelow(secondWindowEnabled, customEnabled)

    local snapGap = UI.CreateSlider(
        custom,
        "Snapped window gap",
        "Controls the space between the two custom meters while snapped together.",
        0, 24, 1,
        function() return ns.GetCustomDamageMeterSnapGap and ns:GetCustomDamageMeterSnapGap() or 0 end,
        function(value) if ns.SetCustomDamageMeterSnapGap then ns:SetCustomDamageMeterSnapGap(value) end end,
        260,
        function(value)
            local pixels = math.floor((value or 0) + 0.5)
            return pixels == 0 and "Touching" or (pixels .. " px")
        end
    )
    snapGap:SetPoint("TOPLEFT", secondWindowEnabled, "BOTTOMLEFT", 10, -16)

    local backgroundOpacity = UI.CreateSlider(
        custom,
        "Meter background opacity",
        "Changes the opacity of the meter body and header background.",
        0, 1, 0.05,
        function() return ns.GetCustomDamageMeterBackgroundOpacity and ns:GetCustomDamageMeterBackgroundOpacity() or 0.94 end,
        function(value) if ns.SetCustomDamageMeterBackgroundOpacity then ns:SetCustomDamageMeterBackgroundOpacity(value) end end,
        260,
        function(value) return tostring(math.floor(((value or 0) * 100) + 0.5)) .. "%" end
    )
    backgroundOpacity:SetPoint("TOPLEFT", snapGap, "BOTTOMLEFT", 0, -20)

    local classColoredBorder = UI.CreateCheckbox(
        custom,
        "Class-color meter borders",
        "Uses your character's class color for both custom meter borders.",
        function() return ns.GetCustomDamageMeterClassColoredBorder and ns:GetCustomDamageMeterClassColoredBorder() or false end,
        function(value) if ns.SetCustomDamageMeterClassColoredBorder then ns:SetCustomDamageMeterClassColoredBorder(value) end end
    )
    classColoredBorder:SetPoint("TOPLEFT", backgroundOpacity, "BOTTOMLEFT", -10, -18)

    local textScale = UI.CreateSlider(
        custom,
        "Bar text scale",
        "Changes the size of player names, ranks, totals, and DPS.",
        0.8, 1.5, 0.05,
        function() return ns.GetCustomDamageMeterTextScale and ns:GetCustomDamageMeterTextScale() or 1 end,
        function(value) if ns.SetCustomDamageMeterTextScale then ns:SetCustomDamageMeterTextScale(value) end end,
        260,
        function(value) return tostring(math.floor(((value or 1) * 100) + 0.5)) .. "%" end
    )
    textScale:SetPoint("TOPLEFT", classColoredBorder, "BOTTOMLEFT", 10, -16)

    local customStatus = custom:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    customStatus:SetPoint("TOPLEFT", textScale, "BOTTOMLEFT", 0, -18)
    customStatus:SetWidth(cardW - 36)
    customStatus:SetJustifyH("LEFT")
    customStatus:SetTextColor(0.78, 0.78, 0.72)

    local previewButton = CreateButton(custom, "Preview / Move", 132, 27)
    previewButton:SetPoint("BOTTOMLEFT", custom, "BOTTOMLEFT", 18, 16)
    previewButton:SetScript("OnClick", function()
        if ns.ToggleCustomDamageMeterMoveMode then
            ns:ToggleCustomDamageMeterMoveMode()
        end
        if page.Refresh then page:Refresh() end
    end)

    local resetPositionButton = CreateButton(custom, "Reset Positions", 132, 27)
    resetPositionButton:SetPoint("LEFT", previewButton, "RIGHT", 10, 0)
    resetPositionButton:SetScript("OnClick", function()
        if ns.ResetCustomDamageMeterPosition then
            ns:ResetCustomDamageMeterPosition()
        end
    end)

    local profiles = CreateSectionCard(page, "Profiles", cardW, 250)
    profiles:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local status = profiles:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", profiles, "TOPLEFT", 18, -42)
    status:SetWidth(cardW - 36)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.78, 0.78, 0.72)

    local profileDropdown = UI.CreateDropdown(
        profiles,
        "Active Profile",
        "Choose which account-wide ZoidsTools and Blizzard damage meter layout to save or apply.",
        ns.GetDamageMeterProfileOptions and ns:GetDamageMeterProfileOptions() or {},
        function() return ns.GetActiveDamageMeterProfileKey and ns:GetActiveDamageMeterProfileKey() or nil end,
        function(value)
            if ns.SetActiveDamageMeterProfileKey then
                ns:SetActiveDamageMeterProfileKey(value)
            end
            if page.Refresh then page:Refresh() end
        end,
        300
    )
    profileDropdown:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -14)

    local createButton = CreateButton(profiles, "Save New", 100, 27)
    createButton:SetPoint("TOPLEFT", profileDropdown, "BOTTOMLEFT", 0, -14)
    createButton:SetScript("OnClick", function()
        if StaticPopup_Show then
            StaticPopup_Show(METER_PROFILE_CREATE_POPUP, nil, nil, { page = page })
        end
    end)

    local saveButton = CreateButton(profiles, "Update", 88, 27)
    saveButton:SetPoint("LEFT", createButton, "RIGHT", 8, 0)
    saveButton:SetScript("OnClick", function()
        local ok, message
        if ns.SaveDamageMeterProfile and ns.GetActiveDamageMeterProfileKey then
            ok, message = ns:SaveDamageMeterProfile(ns:GetActiveDamageMeterProfileKey())
        end
        if ok then ns:Print("Damage meter profile updated.") elseif message then ns:Print(message) end
        if page.Refresh then page:Refresh() end
    end)

    local applyButton = CreateButton(profiles, "Apply", 82, 27)
    applyButton:SetPoint("LEFT", saveButton, "RIGHT", 8, 0)
    applyButton:SetScript("OnClick", function()
        local ok, message
        if ns.ApplyDamageMeterProfile and ns.GetActiveDamageMeterProfileKey then
            ok, message = ns:ApplyDamageMeterProfile(ns:GetActiveDamageMeterProfileKey())
        end
        if ok then ns:Print("Damage meter profile applied.") elseif message then ns:Print(message) end
        if page.Refresh then page:Refresh() end
    end)

    local deleteButton = CreateButton(profiles, "Delete", 82, 27)
    deleteButton:SetPoint("TOPLEFT", createButton, "BOTTOMLEFT", 0, -10)
    deleteButton:SetScript("OnClick", function()
        local key = ns.GetActiveDamageMeterProfileKey and ns:GetActiveDamageMeterProfileKey()
        if not key then return end
        local name = ns.GetDamageMeterProfileName and ns:GetDamageMeterProfileName(key) or key
        if StaticPopup_Show then
            StaticPopup_Show(METER_PROFILE_DELETE_POPUP, name, nil, { key = key, page = page })
        end
    end)

    local profileStatus = profiles:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    profileStatus:SetPoint("TOPLEFT", deleteButton, "BOTTOMLEFT", 0, -12)
    profileStatus:SetWidth(cardW - 36)
    profileStatus:SetJustifyH("LEFT")
    profileStatus:SetTextColor(0.78, 0.78, 0.72)

    local windows = CreateSectionCard(page, "Blizzard Windows", cardW, 150)
    windows:SetPoint("TOPLEFT", profiles, "BOTTOMLEFT", 0, -14)

    local currentWindow1 = windows:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    currentWindow1:SetPoint("TOPLEFT", windows, "TOPLEFT", 18, -42)
    currentWindow1:SetWidth(cardW - 36)
    currentWindow1:SetJustifyH("LEFT")
    currentWindow1:SetTextColor(0.78, 0.78, 0.72)

    local currentWindow2 = windows:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    currentWindow2:SetPoint("TOPLEFT", currentWindow1, "BOTTOMLEFT", 0, -8)
    currentWindow2:SetWidth(cardW - 36)
    currentWindow2:SetJustifyH("LEFT")
    currentWindow2:SetTextColor(0.78, 0.78, 0.72)

    function page:Refresh()
        customEnabled:Refresh()
        secondWindowEnabled:Refresh()
        snapGap:Refresh()
        backgroundOpacity:Refresh()
        classColoredBorder:Refresh()
        textScale:Refresh()

        local customActive = customEnabled:GetChecked() == true
        UI.SetControlEnabled(secondWindowEnabled, customActive)
        UI.SetControlEnabled(snapGap, customActive)
        UI.SetControlEnabled(backgroundOpacity, customActive)
        UI.SetControlEnabled(classColoredBorder, customActive)
        UI.SetControlEnabled(textScale, customActive)

        customStatus:SetText(ns.GetCustomDamageMeterStatusText and ns:GetCustomDamageMeterStatusText() or "")
        previewButton:SetText(ns.IsCustomDamageMeterMoveMode and ns:IsCustomDamageMeterMoveMode() and "Lock Meter" or "Preview / Move")

        local profileOptions = ns.GetDamageMeterProfileOptions and ns:GetDamageMeterProfileOptions() or {}
        if profileDropdown.SetOptions then profileDropdown:SetOptions(profileOptions) end
        profileDropdown:Refresh()

        local activeProfile = ns.GetActiveDamageMeterProfileKey and ns:GetActiveDamageMeterProfileKey()
        UI.SetControlEnabled(profileDropdown, #profileOptions > 0)
        UI.SetControlEnabled(applyButton, activeProfile ~= nil)
        UI.SetControlEnabled(saveButton, activeProfile ~= nil)
        UI.SetControlEnabled(deleteButton, activeProfile ~= nil)

        status:SetText(ns.GetBlizzardDamageMeterStatusText and ns:GetBlizzardDamageMeterStatusText() or "")
        if ns.GetDamageMeterProfileSummary and activeProfile then
            profileStatus:SetText(ns:GetDamageMeterProfileSummary(activeProfile))
        else
            profileStatus:SetText("")
        end

        if ns.GetBlizzardDamageMeterWindowSummary then
            currentWindow1:SetText(ns:GetBlizzardDamageMeterWindowSummary(1))
            currentWindow2:SetText(ns:GetBlizzardDamageMeterWindowSummary(2))
        else
            currentWindow1:SetText("")
            currentWindow2:SetText("")
        end
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateCombatPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

    local input = CreateSectionCard(page, "Input and Alerts", cardW, 224)
    input:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, 0)

    local castOnKeyDown = UI.CreateCheckbox(
        input,
        "Cast action keybinds on key down",
        "Makes action bar keybinds fire when the key is pressed instead of released.",
        function() return ns.GetCastOnKeyDown and ns:GetCastOnKeyDown() end,
        function(value)
            if ns.SetCastOnKeyDown then ns:SetCastOnKeyDown(value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceFirst(castOnKeyDown, input)

    local rangeTint = UI.CreateCheckbox(
        input,
        "Tint full button when out of range",
        "Turns the full action button red when Blizzard marks the action as out of range.",
        function() return ns.GetActionButtonRangeTintEnabled and ns:GetActionButtonRangeTintEnabled() end,
        function(value) if ns.SetActionButtonRangeTintEnabled then ns:SetActionButtonRangeTintEnabled(value) end end
    )
    PlaceBelow(rangeTint, castOnKeyDown)

    local buffWarnings = UI.CreateCheckbox(
        input,
        "Warn missing group buffs",
        "Shows a movable popup when a group-provided buff is missing.",
        function() return ns.GetBuffWarningsEnabled and ns:GetBuffWarningsEnabled() end,
        function(value) if ns.SetBuffWarningsEnabled then ns:SetBuffWarningsEnabled(value) end end
    )
    PlaceBelow(buffWarnings, rangeTint)

    local combatBanner = UI.CreateCheckbox(
        input,
        "Show in-combat banner",
        "Shows a movable IN COMBAT banner briefly when combat starts.",
        function() return ns.GetCombatBannerEnabled and ns:GetCombatBannerEnabled() end,
        function(value)
            if ns.SetCombatBannerEnabled then ns:SetCombatBannerEnabled(value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceBelow(combatBanner, buffWarnings)

    local combatBannerPersistent = UI.CreateCheckbox(
        input,
        "Keep banner visible in combat",
        "Keeps the IN COMBAT banner visible until combat ends.",
        function() return ns.GetCombatBannerPersistent and ns:GetCombatBannerPersistent() end,
        function(value) if ns.SetCombatBannerPersistent then ns:SetCombatBannerPersistent(value) end end
    )
    PlaceBelow(combatBannerPersistent, combatBanner)

    local combatBannerLocked = UI.CreateCheckbox(
        input,
        "Lock banner click-through",
        "Prevents the IN COMBAT banner from catching clicks.",
        function() return ns.GetCombatBannerLocked and ns:GetCombatBannerLocked() end,
        function(value) if ns.SetCombatBannerLocked then ns:SetCombatBannerLocked(value) end end
    )
    PlaceBelow(combatBannerLocked, combatBannerPersistent)

    local status = input:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", input, "BOTTOMLEFT", 18, 14)
    status:SetWidth(cardW - 36)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.78, 0.78, 0.72)

    local flyouts = CreateSectionCard(page, "Skill Flyouts", cardW, 184)
    flyouts:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -10)

    local defaultFlyoutDirection = UI.CreateDropdown(
        flyouts,
        "Default direction",
        "Chooses where skill flyouts such as Summon Demon expand. Blizzard automatic follows the action bar's position.",
        ns.GetSkillFlyoutDirectionOptions and ns:GetSkillFlyoutDirectionOptions(false) or {
            { value = "AUTO", text = "Blizzard automatic" },
            { value = "UP", text = "Up" },
            { value = "DOWN", text = "Down" },
            { value = "LEFT", text = "Left" },
            { value = "RIGHT", text = "Right" },
        },
        function() return ns.GetSkillFlyoutDefaultDirection and ns:GetSkillFlyoutDefaultDirection() or "AUTO" end,
        function(value) if ns.SetSkillFlyoutDefaultDirection then ns:SetSkillFlyoutDefaultDirection(value) end end,
        330
    )
    PlaceFirst(defaultFlyoutDirection, flyouts)

    local knownFlyoutOptions = ns.GetKnownSkillFlyoutOptions and ns:GetKnownSkillFlyoutOptions() or {}
    local selectedFlyoutIDs = {}
    local selectedFlyoutDirection
    local noFlyoutsDetected = #knownFlyoutOptions == 0

    local function EnsureFlyoutSelection(options)
        local available = {}

        for _, option in ipairs(options or {}) do
            local flyoutID = tonumber(option.value)
            if flyoutID and flyoutID > 0 then
                available[math.floor(flyoutID)] = true
            end
        end

        for flyoutID in pairs(selectedFlyoutIDs) do
            if not available[flyoutID] then
                selectedFlyoutIDs[flyoutID] = nil
            end
        end

        if next(selectedFlyoutIDs) == nil and next(available) ~= nil then
            local preferred = ns.GetPreferredSkillFlyoutID and tonumber(ns:GetPreferredSkillFlyoutID()) or nil
            preferred = preferred and math.floor(preferred) or nil

            if preferred and available[preferred] then
                selectedFlyoutIDs[preferred] = true
            else
                local firstID = options[1] and tonumber(options[1].value)
                if firstID then
                    selectedFlyoutIDs[math.floor(firstID)] = true
                end
            end
        end
    end

    local function BuildFlyoutSelectionOptions(options)
        local result = {}

        for _, source in ipairs(options or {}) do
            local flyoutID = tonumber(source.value)
            if flyoutID and flyoutID > 0 then
                flyoutID = math.floor(flyoutID)
                result[#result + 1] = {
                    value = flyoutID,
                    text = source.text or ("Flyout " .. flyoutID),
                    shortText = source.shortText or source.text,
                    tooltip = source.tooltip,
                    getter = function()
                        return selectedFlyoutIDs[flyoutID] == true
                    end,
                    setter = function(value)
                        selectedFlyoutIDs[flyoutID] = value == true or nil
                        if selectedFlyoutDirection then
                            selectedFlyoutDirection:Refresh()
                            UI.SetControlEnabled(selectedFlyoutDirection, next(selectedFlyoutIDs) ~= nil)
                        end
                    end,
                }
            end
        end
        return result
    end

    local function GetSelectedFlyoutIDs()
        local result = {}

        for _, option in ipairs(knownFlyoutOptions) do
            local flyoutID = tonumber(option.value)
            flyoutID = flyoutID and math.floor(flyoutID) or nil
            if flyoutID and selectedFlyoutIDs[flyoutID] then
                result[#result + 1] = flyoutID
            end
        end
        return result
    end

    local function GetSelectedFlyoutDirection()
        local commonDirection

        for _, flyoutID in ipairs(GetSelectedFlyoutIDs()) do
            local direction = ns.GetSkillFlyoutOverrideDirection
                and ns:GetSkillFlyoutOverrideDirection(flyoutID)
                or "INHERIT"

            if commonDirection and commonDirection ~= direction then
                return "MIXED"
            end
            commonDirection = direction
        end
        return commonDirection or "INHERIT"
    end

    local bulkDirectionOptions = {}
    for _, option in ipairs(ns.GetSkillFlyoutDirectionOptions and ns:GetSkillFlyoutDirectionOptions(true) or {
        { value = "INHERIT", text = "Use default" },
        { value = "AUTO", text = "Blizzard automatic" },
        { value = "UP", text = "Up" },
        { value = "DOWN", text = "Down" },
        { value = "LEFT", text = "Left" },
        { value = "RIGHT", text = "Right" },
    }) do
        bulkDirectionOptions[#bulkDirectionOptions + 1] = option
    end
    bulkDirectionOptions[#bulkDirectionOptions + 1] = { value = "MIXED", text = "Mixed directions" }

    EnsureFlyoutSelection(knownFlyoutOptions)

    local flyoutSelector = UI.CreateMultiSelectDropdown(
        flyouts,
        "Select flyouts",
        "Select one or more known skill flyouts. Overrides follow each named flyout if it is moved to another action-bar slot.",
        BuildFlyoutSelectionOptions(knownFlyoutOptions),
        200
    )
    flyoutSelector:SetPoint("TOPLEFT", defaultFlyoutDirection, "BOTTOMLEFT", 0, -12)

    selectedFlyoutDirection = UI.CreateDropdown(
        flyouts,
        "Set selected to",
        "Applies one direction to every selected flyout. Use default removes their individual overrides.",
        bulkDirectionOptions,
        GetSelectedFlyoutDirection,
        function(value)
            if value == "MIXED" then
                selectedFlyoutDirection:Refresh()
                return
            end

            local selected = GetSelectedFlyoutIDs()
            if ns.SetSkillFlyoutOverrideDirections then
                ns:SetSkillFlyoutOverrideDirections(selected, value)
            elseif ns.SetSkillFlyoutOverrideDirection then
                for _, flyoutID in ipairs(selected) do
                    ns:SetSkillFlyoutOverrideDirection(flyoutID, value)
                end
            end
            selectedFlyoutDirection:Refresh()
        end,
        126
    )
    selectedFlyoutDirection:SetPoint("TOPLEFT", flyoutSelector, "TOPRIGHT", 12, 0)

    local flyoutNote = flyouts:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    flyoutNote:SetPoint("BOTTOMLEFT", flyouts, "BOTTOMLEFT", 18, 10)
    flyoutNote:SetPoint("RIGHT", flyouts, "RIGHT", -18, 0)
    flyoutNote:SetJustifyH("LEFT")
    flyoutNote:SetText("Select one or more flyouts; changes apply outside combat and remain active during combat.")

    local keybinds = CreateSectionCard(page, "Action Keybind Text", cardW, 390)
    keybinds:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local keybindTextEnabled = UI.CreateCheckbox(
        keybinds,
        "Customize action keybind text",
        "Applies ZoidsTools font and label formatting to action bar keybind text.",
        function() return ns.GetKeybindTextEnabled and ns:GetKeybindTextEnabled() end,
        function(value)
            if ns.SetKeybindTextEnabled then ns:SetKeybindTextEnabled(value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceFirst(keybindTextEnabled, keybinds)

    local shortenKeybindText = UI.CreateCheckbox(
        keybinds,
        "Shorten keybind labels",
        "Condenses keybind labels, such as s-C to SC and Mouse4 to M4.",
        function() return ns.GetKeybindTextShortened and ns:GetKeybindTextShortened() end,
        function(value) if ns.SetKeybindTextShortened then ns:SetKeybindTextShortened(value) end end
    )
    PlaceBelow(shortenKeybindText, keybindTextEnabled)

    local keybindFont = UI.CreateDropdown(
        keybinds,
        "Keybind font",
        "Changes the font used by action bar keybind text.",
        ns.GetKeybindTextFontOptions and ns:GetKeybindTextFontOptions() or { { value = "default", text = "Default" } },
        function() return ns.GetKeybindTextFont and ns:GetKeybindTextFont() or "default" end,
        function(value) if ns.SetKeybindTextFont then ns:SetKeybindTextFont(value) end end,
        260
    )
    keybindFont:SetPoint("TOPLEFT", shortenKeybindText, "BOTTOMLEFT", 0, -12)

    local keybindFontSize = UI.CreateSlider(
        keybinds,
        "Keybind size",
        "Changes the action bar keybind text size.",
        8, 24, 1,
        function() return ns.GetKeybindTextFontSize and ns:GetKeybindTextFontSize() or 12 end,
        function(value) if ns.SetKeybindTextFontSize then ns:SetKeybindTextFontSize(value) end end,
        240,
        function(value) return tostring(math.floor((value or 12) + 0.5)) end
    )
    keybindFontSize:SetPoint("TOPLEFT", keybindFont, "BOTTOMLEFT", 10, -18)

    local useCustomColor = UI.CreateCheckbox(
        keybinds,
        "Use custom color",
        "Uses your selected keybind color instead of Blizzard's default.",
        function() return ns.GetKeybindTextUseCustomColor and ns:GetKeybindTextUseCustomColor() end,
        function(value)
            if ns.SetKeybindTextUseCustomColor then ns:SetKeybindTextUseCustomColor(value) end
            if page.Refresh then page:Refresh() end
        end
    )
    useCustomColor:SetPoint("TOPLEFT", keybindFontSize, "BOTTOMLEFT", -10, -18)

    local keybindColor = UI.CreateColorPicker(
        keybinds,
        "Keybind color",
        "Pick a custom color for action bar keybind text.",
        function()
            if ns.GetKeybindTextColor then
                local r, g, b = ns:GetKeybindTextColor()
                local custom = ns.GetKeybindTextUseCustomColor and ns:GetKeybindTextUseCustomColor()
                return r, g, b, custom
            end
            return 1, 1, 1, false
        end,
        function(r, g, b, cancelled, previousCustom)
            if ns.SetKeybindTextColor then
                ns:SetKeybindTextColor(r, g, b, not cancelled or previousCustom == true)
            end
            if page.Refresh then page:Refresh() end
        end,
        240
    )
    PlaceBelow(keybindColor, useCustomColor, 0, 10)

    local boldKeybindText = UI.CreateCheckbox(
        keybinds,
        "Bold keybind text",
        "Adds a heavier keybind text treatment.",
        function() return ns.GetKeybindTextBold and ns:GetKeybindTextBold() end,
        function(value) if ns.SetKeybindTextBold then ns:SetKeybindTextBold(value) end end
    )
    boldKeybindText:SetPoint("TOPLEFT", keybindColor, "BOTTOMLEFT", 0, -12)

    local keybindOutline = UI.CreateDropdown(
        keybinds,
        "Keybind outline",
        "Changes the outline style used by action bar keybind text.",
        ns.GetKeybindTextOutlineOptions and ns:GetKeybindTextOutlineOptions() or {
            { value = "default", text = "Default" },
            { value = "none", text = "None" },
            { value = "outline", text = "Outline" },
            { value = "thick", text = "Thick Outline" },
        },
        function() return ns.GetKeybindTextOutline and ns:GetKeybindTextOutline() or "default" end,
        function(value) if ns.SetKeybindTextOutline then ns:SetKeybindTextOutline(value) end end,
        240
    )
    keybindOutline:SetPoint("TOPLEFT", boldKeybindText, "BOTTOMLEFT", 0, -12)

    function page:Refresh()
        castOnKeyDown:Refresh()
        rangeTint:Refresh()
        buffWarnings:Refresh()
        combatBanner:Refresh()
        combatBannerPersistent:Refresh()
        combatBannerLocked:Refresh()
        defaultFlyoutDirection:Refresh()

        local refreshedFlyoutOptions = ns.GetKnownSkillFlyoutOptions and ns:GetKnownSkillFlyoutOptions() or {}
        noFlyoutsDetected = #refreshedFlyoutOptions == 0

        knownFlyoutOptions = refreshedFlyoutOptions
        EnsureFlyoutSelection(knownFlyoutOptions)
        flyoutSelector:SetOptions(BuildFlyoutSelectionOptions(knownFlyoutOptions))
        selectedFlyoutDirection:Refresh()
        UI.SetControlEnabled(flyoutSelector, not noFlyoutsDetected)
        UI.SetControlEnabled(selectedFlyoutDirection, not noFlyoutsDetected and next(selectedFlyoutIDs) ~= nil)
        keybindTextEnabled:Refresh()
        shortenKeybindText:Refresh()
        keybindFont:Refresh()
        keybindFontSize:Refresh()
        useCustomColor:Refresh()
        keybindColor:Refresh()
        boldKeybindText:Refresh()
        keybindOutline:Refresh()

        local bannerActive = combatBanner:GetChecked() == true
        UI.SetControlEnabled(combatBannerPersistent, bannerActive)
        UI.SetControlEnabled(combatBannerLocked, bannerActive)

        local keybindActive = keybindTextEnabled:GetChecked() == true
        UI.SetControlEnabled(shortenKeybindText, keybindActive)
        UI.SetControlEnabled(keybindFont, keybindActive)
        UI.SetControlEnabled(keybindFontSize, keybindActive)
        UI.SetControlEnabled(useCustomColor, keybindActive)
        UI.SetControlEnabled(keybindColor, keybindActive and useCustomColor:GetChecked() == true)
        UI.SetControlEnabled(boldKeybindText, keybindActive)
        UI.SetControlEnabled(keybindOutline, keybindActive)

        status:SetText((ns.GetCurrentCastOnKeyDownCVar and ns:GetCurrentCastOnKeyDownCVar()) and "Current WoW setting: key down." or "Current WoW setting: key up.")
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateUnitFramesPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local controls = {}
    local castbarDependencies = {}
    local cardW = 246
    local gap = 14
    local frameColumns = {
        { key = "player", label = "Player" },
        { key = "target", label = "Target" },
        { key = "focus", label = "Focus" },
    }

    local health = CreateSectionCard(page, "Health Bars", (cardW * 3) + (gap * 2), 90)
    health:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    local classColorHealth = UI.CreateCheckbox(
        health,
        "Class color health",
        "Colors only the health fill on player, target, target of target, and focus frames.",
        function() return ns.GetUnitFrameClassColorHealth and ns:GetUnitFrameClassColorHealth() end,
        function(value) if ns.SetUnitFrameClassColorHealth then ns:SetUnitFrameClassColorHealth(value) end end
    )
    PlaceFirst(classColorHealth, health)
    controls[#controls + 1] = classColorHealth

    for index, info in ipairs(frameColumns) do
        local card = CreateSectionCard(page, info.label, cardW, 330)
        card:SetPoint("TOPLEFT", health, "BOTTOMLEFT", (index - 1) * (cardW + gap), -14)

        local resizeCastbar = UI.CreateCheckbox(
            card,
            "Resize castbar",
            "Uses custom width and height for this frame's Blizzard castbar.",
            function() return ns.GetUnitFrameCastbarResizeEnabled and ns:GetUnitFrameCastbarResizeEnabled(info.key) end,
            function(value)
                if ns.SetUnitFrameCastbarResizeEnabled then ns:SetUnitFrameCastbarResizeEnabled(info.key, value) end
                if page.Refresh then page:Refresh() end
            end
        )
        PlaceFirst(resizeCastbar, card)
        controls[#controls + 1] = resizeCastbar

        local castbarWidth = UI.CreateSlider(
            card,
            "Width",
            "Changes this castbar's width.",
            120, 420, 5,
            function() return ns.GetUnitFrameCastbarWidth and ns:GetUnitFrameCastbarWidth(info.key) or 195 end,
            function(value) if ns.SetUnitFrameCastbarWidth then ns:SetUnitFrameCastbarWidth(info.key, value) end end,
            185,
            function(value) return tostring(math.floor((value or 195) + 0.5)) end
        )
        castbarWidth:SetPoint("TOPLEFT", resizeCastbar, "BOTTOMLEFT", 10, -18)
        controls[#controls + 1] = castbarWidth

        local castbarHeight = UI.CreateSlider(
            card,
            "Height",
            "Changes this castbar's height.",
            8, 40, 1,
            function() return ns.GetUnitFrameCastbarHeight and ns:GetUnitFrameCastbarHeight(info.key) or 16 end,
            function(value) if ns.SetUnitFrameCastbarHeight then ns:SetUnitFrameCastbarHeight(info.key, value) end end,
            185,
            function(value) return tostring(math.floor((value or 16) + 0.5)) end
        )
        castbarHeight:SetPoint("TOPLEFT", castbarWidth, "BOTTOMLEFT", 0, -22)
        controls[#controls + 1] = castbarHeight

        local previewCastbar = CreateButton(card, "Preview Castbar", 130, 27)
        previewCastbar:SetPoint("TOPLEFT", castbarHeight, "BOTTOMLEFT", -10, -18)
        previewCastbar:SetScript("OnClick", function()
            if ns.PreviewUnitFrameCastbar then
                ns:PreviewUnitFrameCastbar(info.key, previewCastbar)
            end
        end)

        castbarDependencies[#castbarDependencies + 1] = { enabled = resizeCastbar, width = castbarWidth, height = castbarHeight, preview = previewCastbar }

        local anchor = previewCastbar
        if info.key ~= "player" then
            local hideBuffs = UI.CreateCheckbox(
                card,
                "Hide buffs",
                "Hides helpful aura icons for this frame.",
                function() return ns.GetUnitFrameAuraHidden and ns:GetUnitFrameAuraHidden(info.key, "buffs") end,
                function(value) if ns.SetUnitFrameAuraHidden then ns:SetUnitFrameAuraHidden(info.key, "buffs", value) end end
            )
            hideBuffs:SetPoint("TOPLEFT", previewCastbar, "BOTTOMLEFT", 0, -18)
            controls[#controls + 1] = hideBuffs
            anchor = hideBuffs

            local hideDebuffs = UI.CreateCheckbox(
                card,
                "Hide debuffs",
                "Hides harmful aura icons for this frame.",
                function() return ns.GetUnitFrameAuraHidden and ns:GetUnitFrameAuraHidden(info.key, "debuffs") end,
                function(value) if ns.SetUnitFrameAuraHidden then ns:SetUnitFrameAuraHidden(info.key, "debuffs", value) end end
            )
            PlaceBelow(hideDebuffs, hideBuffs)
            controls[#controls + 1] = hideDebuffs
            anchor = hideDebuffs
        end
    end

    local refreshButton = CreateButton(page, "Refresh Unit Frames", 160, 27)
    refreshButton:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    refreshButton:SetScript("OnClick", function()
        if ns.RefreshUnitFrames then ns:RefreshUnitFrames() end
        if page.Refresh then page:Refresh() end
    end)

    function page:Refresh()
        for _, control in ipairs(controls) do
            if control.Refresh then control:Refresh() end
        end

        for _, dependency in ipairs(castbarDependencies) do
            local active = dependency.enabled:GetChecked() == true
            UI.SetControlEnabled(dependency.width, active)
            UI.SetControlEnabled(dependency.height, active)
            UI.SetControlEnabled(dependency.preview, active)
        end
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:SetScript("OnHide", function()
        if ns.HideUnitFrameCastbarPreview then ns:HideUnitFrameCastbarPreview() end
    end)

    return page
end

local function CreateMacrosPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

    local health = CreateSectionCard(page, "Health Macro", cardW, 150)
    health:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, 0)

    local healthEnabled = UI.CreateCheckbox(
        health,
        "Create ZT Health macro",
        "Creates and updates a character macro named ZT Health outside combat.",
        function() return ns.GetConsumableMacroOption and ns:GetConsumableMacroOption("healthEnabled") end,
        function(value)
            if ns.SetConsumableMacroOption then ns:SetConsumableMacroOption("healthEnabled", value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceFirst(healthEnabled, health)

    local healthRecuperate = UI.CreateCheckbox(
        health,
        "Use Recuperate out of combat",
        "Uses Recuperate instead of bag food when pressed out of combat.",
        function() return ns.GetConsumableMacroOption and ns:GetConsumableMacroOption("healthUseRecuperate") end,
        function(value) if ns.SetConsumableMacroOption then ns:SetConsumableMacroOption("healthUseRecuperate", value) end end
    )
    PlaceBelow(healthRecuperate, healthEnabled)

    local healthCombat = UI.CreateCheckbox(
        health,
        "Use Healthstone then potion in combat",
        "Adds combat lines for Healthstone first, then your best healing potion.",
        function() return ns.GetConsumableMacroOption and ns:GetConsumableMacroOption("healthCombatItems") end,
        function(value) if ns.SetConsumableMacroOption then ns:SetConsumableMacroOption("healthCombatItems", value) end end
    )
    PlaceBelow(healthCombat, healthRecuperate)

    local mana = CreateSectionCard(page, "Mana Macro", cardW, 120)
    mana:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -14)

    local manaEnabled = UI.CreateCheckbox(
        mana,
        "Create ZT Mana macro",
        "Creates and updates a character macro named ZT Mana outside combat.",
        function() return ns.GetConsumableMacroOption and ns:GetConsumableMacroOption("manaEnabled") end,
        function(value)
            if ns.SetConsumableMacroOption then ns:SetConsumableMacroOption("manaEnabled", value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceFirst(manaEnabled, mana)

    local manaCombat = UI.CreateCheckbox(
        mana,
        "Use mana potion in combat",
        "Adds a combat line for your best mana potion.",
        function() return ns.GetConsumableMacroOption and ns:GetConsumableMacroOption("manaCombatPotion") end,
        function(value) if ns.SetConsumableMacroOption then ns:SetConsumableMacroOption("manaCombatPotion", value) end end
    )
    PlaceBelow(manaCombat, manaEnabled)

    local hearth = CreateSectionCard(page, "Random Hearthstone", cardW, 180)
    hearth:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local hearthstoneEnabled = UI.CreateCheckbox(
        hearth,
        "Create ZT Hearth macro",
        "Creates a macro that uses a random selected Hearthstone.",
        function() return ns.GetRandomHearthstoneEnabled and ns:GetRandomHearthstoneEnabled() end,
        function(value)
            if ns.SetRandomHearthstoneEnabled then ns:SetRandomHearthstoneEnabled(value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceFirst(hearthstoneEnabled, hearth)

    local selectHearthstones = CreateButton(hearth, "Select Hearthstones  v", 180, 27)
    selectHearthstones:SetPoint("TOPLEFT", hearthstoneEnabled, "BOTTOMLEFT", 0, -16)
    selectHearthstones:SetScript("OnClick", function()
        if ns.OpenRandomHearthstoneSelector then
            ns:OpenRandomHearthstoneSelector(selectHearthstones)
        end
    end)

    local hearthstoneStatus = hearth:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hearthstoneStatus:SetPoint("TOPLEFT", selectHearthstones, "BOTTOMLEFT", 0, -12)
    hearthstoneStatus:SetWidth(cardW - 36)
    hearthstoneStatus:SetJustifyH("LEFT")
    hearthstoneStatus:SetTextColor(0.78, 0.78, 0.72)

    local actions = CreateSectionCard(page, "Actions", cardW, 170)
    actions:SetPoint("TOPLEFT", hearth, "BOTTOMLEFT", 0, -14)

    local refreshButton = CreateButton(actions, "Refresh Macros", 140, 27)
    PlaceFirst(refreshButton, actions)
    refreshButton:SetScript("OnClick", function()
        if ns.RefreshConsumableMacros then ns:RefreshConsumableMacros(true) end
        if ns.RefreshRandomHearthstoneMacro then ns:RefreshRandomHearthstoneMacro() end
        if ns.Print then
            if InCombatLockdown and InCombatLockdown() then
                ns:Print("Macro refresh queued until combat ends.")
            else
                ns:Print("Enabled macros checked and refreshed where needed.")
            end
        end
        if page.Refresh then page:Refresh() end
    end)

    local status = actions:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", refreshButton, "BOTTOMLEFT", 0, -18)
    status:SetWidth(cardW - 36)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.78, 0.78, 0.72)

    function page:Refresh()
        healthEnabled:Refresh()
        healthRecuperate:Refresh()
        healthCombat:Refresh()
        manaEnabled:Refresh()
        manaCombat:Refresh()
        hearthstoneEnabled:Refresh()

        UI.SetControlEnabled(healthRecuperate, healthEnabled:GetChecked() == true)
        UI.SetControlEnabled(healthCombat, healthEnabled:GetChecked() == true)
        UI.SetControlEnabled(manaCombat, manaEnabled:GetChecked() == true)
        UI.SetControlEnabled(selectHearthstones, hearthstoneEnabled:GetChecked() == true)

        local healthStatus = "Health macro disabled."
        local manaStatus = "Mana macro disabled."
        if ns.GetConsumableMacroStatus then
            healthStatus, manaStatus = ns:GetConsumableMacroStatus()
        end
        status:SetText((healthStatus or "") .. "\n" .. (manaStatus or ""))
        hearthstoneStatus:SetText(ns.GetRandomHearthstoneStatus and ns:GetRandomHearthstoneStatus() or "")
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)
    page:SetScript("OnHide", function()
        if ns.CloseRandomHearthstoneSelector then
            ns:CloseRandomHearthstoneSelector()
        end
    end)

    return page
end

local function CreateLootPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

    local behavior = CreateSectionCard(page, "Behavior", cardW, 170)
    behavior:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, 0)

    local fastLoot = UI.CreateCheckbox(
        behavior,
        "Fast auto loot",
        "Enables WoW auto-loot if needed, then clicks loot slots quickly when auto-loot is active.",
        function() return ns.GetFastLootEnabled and ns:GetFastLootEnabled() end,
        function(value)
            if ns.SetFastLootEnabled then ns:SetFastLootEnabled(value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceFirst(fastLoot, behavior)

    local carefulMode = UI.CreateCheckbox(
        behavior,
        "Careful second pass",
        "Runs one delayed follow-up sweep for unusual loot delays. Leave this off unless items are missed.",
        function() return ns.db and ns.db.loot and ns.db.loot.carefulMode end,
        function(value) ns.db.loot.carefulMode = value end
    )
    PlaceBelow(carefulMode, fastLoot)

    local status = behavior:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", carefulMode, "BOTTOMLEFT", 4, -16)
    status:SetWidth(cardW - 40)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.78, 0.78, 0.72)

    local vendor = CreateSectionCard(page, "Vendor", cardW, 240)
    vendor:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local autoSellGrey = UI.CreateCheckbox(
        vendor,
        "Auto-sell grey items",
        "Automatically uses the vendor junk-sell behavior when a merchant window opens.",
        function() return ns.GetAutoSellGreyItems and ns:GetAutoSellGreyItems() end,
        function(value) if ns.SetAutoSellGreyItems then ns:SetAutoSellGreyItems(value) end end
    )
    PlaceFirst(autoSellGrey, vendor)

    local autoSellBoEGrey = UI.CreateCheckbox(
        vendor,
        "Include BoE grey items",
        "Includes bind-on-equip grey items when auto-selling junk.",
        function() return ns.GetAutoSellBoEGreyItems and ns:GetAutoSellBoEGreyItems() end,
        function(value) if ns.SetAutoSellBoEGreyItems then ns:SetAutoSellBoEGreyItems(value) end end
    )
    PlaceBelow(autoSellBoEGrey, autoSellGrey)

    local knownMerchantOverlay = UI.CreateCheckbox(
        vendor,
        "Mark already-known vendor items",
        "Marks merchant items and patterns you already know.",
        function() return ns.GetKnownMerchantItemOverlay and ns:GetKnownMerchantItemOverlay() end,
        function(value) if ns.SetKnownMerchantItemOverlay then ns:SetKnownMerchantItemOverlay(value) end end
    )
    PlaceBelow(knownMerchantOverlay, autoSellBoEGrey)

    local autoRepair = UI.CreateDropdown(
        vendor,
        "Auto repair",
        "Automatically repairs when a merchant can repair.",
        ns.GetAutoRepairModeOptions and ns:GetAutoRepairModeOptions() or {
            { value = "disabled", text = "Disabled" },
            { value = "personal", text = "Use My Gold" },
            { value = "guild", text = "Use Guild Bank" },
        },
        function() return ns.GetAutoRepairMode and ns:GetAutoRepairMode() or "disabled" end,
        function(value) if ns.SetAutoRepairMode then ns:SetAutoRepairMode(value) end end,
        240
    )
    autoRepair:SetPoint("TOPLEFT", knownMerchantOverlay, "BOTTOMLEFT", 0, -14)

    function page:Refresh()
        fastLoot:Refresh()
        carefulMode:Refresh()
        autoSellGrey:Refresh()
        autoSellBoEGrey:Refresh()
        knownMerchantOverlay:Refresh()
        autoRepair:Refresh()

        UI.SetControlEnabled(carefulMode, fastLoot:GetChecked() == true)

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

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateQuestsPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

    local automation = CreateSectionCard(page, "Automation", cardW, 245)
    automation:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, 0)

    local autoAccept = UI.CreateCheckbox(
        automation,
        "Auto accept quests",
        "Automatically accepts available quests unless the pause modifier is held.",
        function() return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("autoAccept") end,
        function(value)
            if ns.SetQuestAutomationOption then ns:SetQuestAutomationOption("autoAccept", value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceFirst(autoAccept, automation)

    local autoTurnIn = UI.CreateCheckbox(
        automation,
        "Auto turn in quests",
        "Automatically completes ready quests. Multiple reward choices are left for manual selection.",
        function() return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("autoTurnIn") end,
        function(value)
            if ns.SetQuestAutomationOption then ns:SetQuestAutomationOption("autoTurnIn", value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceBelow(autoTurnIn, autoAccept)

    local autoGossip = UI.CreateCheckbox(
        automation,
        "Auto gossip",
        "Automatically advances simple gossip windows unless the pause modifier is held.",
        function() return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("autoGossip") end,
        function(value)
            if ns.SetQuestAutomationOption then ns:SetQuestAutomationOption("autoGossip", value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceBelow(autoGossip, autoTurnIn)

    local pauseModifier = UI.CreateDropdown(
        automation,
        "Pause modifier",
        "Hold this key to temporarily pause auto questing and auto gossip.",
        ns.GetQuestAutomationPauseModifierOptions and ns:GetQuestAutomationPauseModifierOptions() or {
            { value = "shift", text = "Shift" },
            { value = "ctrl", text = "Ctrl" },
            { value = "alt", text = "Alt" },
            { value = "none", text = "None" },
        },
        function() return ns.GetQuestAutomationPauseModifier and ns:GetQuestAutomationPauseModifier() or "shift" end,
        function(value) if ns.SetQuestAutomationPauseModifier then ns:SetQuestAutomationPauseModifier(value) end end,
        220
    )
    pauseModifier:SetPoint("TOPLEFT", autoGossip, "BOTTOMLEFT", 0, -14)

    local filters = CreateSectionCard(page, "Filters", cardW, 150)
    filters:SetPoint("TOPLEFT", automation, "BOTTOMLEFT", 0, -14)

    local skipDaily = UI.CreateCheckbox(
        filters,
        "Skip daily and weekly quests",
        "Prevents automation for daily, weekly, recurring, and calling quests.",
        function() return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("skipDaily") end,
        function(value) if ns.SetQuestAutomationOption then ns:SetQuestAutomationOption("skipDaily", value) end end
    )
    PlaceFirst(skipDaily, filters)

    local skipWarband = UI.CreateCheckbox(
        filters,
        "Skip Warband-completed quests",
        "Prevents auto accept for quests already completed by your Warband.",
        function() return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("skipWarbandCompleted") end,
        function(value) if ns.SetQuestAutomationOption then ns:SetQuestAutomationOption("skipWarbandCompleted", value) end end
    )
    PlaceBelow(skipWarband, skipDaily)

    local filterNote = filters:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    filterNote:SetPoint("TOPLEFT", skipWarband, "BOTTOMLEFT", 4, -14)
    filterNote:SetWidth(cardW - 40)
    filterNote:SetJustifyH("LEFT")
    filterNote:SetTextColor(0.78, 0.78, 0.72)
    filterNote:SetText("Multiple-choice quest rewards are never selected automatically.")

    local questItem = CreateSectionCard(page, "Quest Item Button", cardW, 160)
    questItem:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local questItemButton = UI.CreateCheckbox(
        questItem,
        "Show smart quest item button",
        "Shows a usable, bindable button for the most relevant tracked quest item in your current area.",
        function() return ns.GetQuestItemButtonEnabled and ns:GetQuestItemButtonEnabled() end,
        function(value)
            if ns.SetQuestItemButtonEnabled then ns:SetQuestItemButtonEnabled(value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceFirst(questItemButton, questItem)

    local moveQuestItemButton = CreateButton(questItem, "Move Quest Item Button", 190, 27)
    moveQuestItemButton:SetPoint("TOPLEFT", questItemButton, "BOTTOMLEFT", 0, -14)
    moveQuestItemButton:SetScript("OnClick", function()
        if ns.ToggleQuestItemButtonMoveMode then
            ns:ToggleQuestItemButtonMoveMode()
        end
        if page.Refresh then page:Refresh() end
    end)

    local trackerStatus = questItem:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    trackerStatus:SetPoint("TOPLEFT", moveQuestItemButton, "BOTTOMLEFT", 0, -12)
    trackerStatus:SetWidth(cardW - 36)
    trackerStatus:SetJustifyH("LEFT")
    trackerStatus:SetTextColor(0.78, 0.78, 0.72)
    trackerStatus:SetText("Priority: current quest area, super-tracked quest, then nearest tracked quest.")

    function page:Refresh()
        autoAccept:Refresh()
        autoTurnIn:Refresh()
        autoGossip:Refresh()
        pauseModifier:Refresh()
        skipDaily:Refresh()
        skipWarband:Refresh()
        questItemButton:Refresh()

        local acceptActive = autoAccept:GetChecked() == true
        local turnInActive = autoTurnIn:GetChecked() == true
        local automationActive = acceptActive or turnInActive or autoGossip:GetChecked() == true
        UI.SetControlEnabled(pauseModifier, automationActive)
        UI.SetControlEnabled(skipDaily, acceptActive or turnInActive)
        UI.SetControlEnabled(skipWarband, acceptActive)
        UI.SetControlEnabled(moveQuestItemButton, questItemButton:GetChecked() == true)
        moveQuestItemButton:SetText(ns.IsQuestItemButtonMoveMode and ns:IsQuestItemButtonMoveMode() and "Lock Quest Item Button" or "Move Quest Item Button")
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateTrackerPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

    local sizing = CreateSectionCard(page, "Tracker", cardW, 130)
    sizing:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, 0)

    local trackerAppearanceEnabled = UI.CreateCheckbox(
        sizing,
        "Customize Blizzard objective tracker",
        "Keeps Blizzard's native tracker layout while applying taint-safe ZoidsTools appearance controls.",
        function() return ns.GetObjectiveTrackerAppearanceOption and ns:GetObjectiveTrackerAppearanceOption("enabled") end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then ns:SetObjectiveTrackerAppearanceOption("enabled", value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceFirst(trackerAppearanceEnabled, sizing)

    local trackerFitHeight = UI.CreateCheckbox(
        sizing,
        "Fit tracker background to tracked content",
        "Fits the ZoidsTools background and border to the final tracked objective.",
        function() return ns.GetObjectiveTrackerAppearanceOption and ns:GetObjectiveTrackerAppearanceOption("fitHeight") end,
        function(value) if ns.SetObjectiveTrackerAppearanceOption then ns:SetObjectiveTrackerAppearanceOption("fitHeight", value) end end
    )
    PlaceBelow(trackerFitHeight, trackerAppearanceEnabled)

    local appearance = CreateSectionCard(page, "Appearance", cardW, 255)
    appearance:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local trackerBackgroundOpacity = UI.CreateSlider(
        appearance,
        "Background opacity",
        "Adds a subtle dark background behind the objective tracker.",
        0, 0.70, 0.05,
        function() return ns.GetObjectiveTrackerAppearanceOption and ns:GetObjectiveTrackerAppearanceOption("backgroundOpacity") or 0 end,
        function(value) if ns.SetObjectiveTrackerAppearanceOption then ns:SetObjectiveTrackerAppearanceOption("backgroundOpacity", value) end end,
        260,
        function(value) return tostring(math.floor(((value or 0) * 100) + 0.5)) .. "%" end
    )
    PlaceFirst(trackerBackgroundOpacity, appearance, 28, -46)

    local trackerBorderEnabled = UI.CreateCheckbox(
        appearance,
        "Show tracker border",
        "Draws a subtle border around Blizzard's objective-tracker region.",
        function() return ns.GetObjectiveTrackerAppearanceOption and ns:GetObjectiveTrackerAppearanceOption("borderEnabled") end,
        function(value)
            if ns.SetObjectiveTrackerAppearanceOption then ns:SetObjectiveTrackerAppearanceOption("borderEnabled", value) end
            if page.Refresh then page:Refresh() end
        end
    )
    trackerBorderEnabled:SetPoint("TOPLEFT", trackerBackgroundOpacity, "BOTTOMLEFT", -10, -20)

    local trackerClassBorder = UI.CreateCheckbox(
        appearance,
        "Class-color tracker border",
        "Uses your character's class color for the subtle tracker border.",
        function() return ns.GetObjectiveTrackerAppearanceOption and ns:GetObjectiveTrackerAppearanceOption("classColoredBorder") end,
        function(value) if ns.SetObjectiveTrackerAppearanceOption then ns:SetObjectiveTrackerAppearanceOption("classColoredBorder", value) end end
    )
    PlaceBelow(trackerClassBorder, trackerBorderEnabled)

    local trackerMouseoverControls = UI.CreateCheckbox(
        appearance,
        "Fade tracker header buttons until mouseover",
        "Makes tracker buttons less prominent when the tracker is not being used.",
        function() return ns.GetObjectiveTrackerAppearanceOption and ns:GetObjectiveTrackerAppearanceOption("mouseoverControls") end,
        function(value) if ns.SetObjectiveTrackerAppearanceOption then ns:SetObjectiveTrackerAppearanceOption("mouseoverControls", value) end end
    )
    PlaceBelow(trackerMouseoverControls, trackerClassBorder)

    local trackerMinimizeToButton = UI.CreateCheckbox(
        appearance,
        "Minimize tracker to '+' only",
        "When minimized, hides title, background, and border so only the restore button remains.",
        function() return ns.GetObjectiveTrackerAppearanceOption and ns:GetObjectiveTrackerAppearanceOption("minimizeToButton") end,
        function(value) if ns.SetObjectiveTrackerAppearanceOption then ns:SetObjectiveTrackerAppearanceOption("minimizeToButton", value) end end
    )
    PlaceBelow(trackerMinimizeToButton, trackerMouseoverControls)

    local note = CreateSectionCard(page, "Note", cardW, 120)
    note:SetPoint("TOPLEFT", appearance, "BOTTOMLEFT", 0, -14)

    local noteText = note:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    noteText:SetPoint("TOPLEFT", note, "TOPLEFT", 18, -42)
    noteText:SetWidth(cardW - 36)
    noteText:SetJustifyH("LEFT")
    noteText:SetTextColor(0.78, 0.78, 0.72)
    noteText:SetText("ZoidsTools leaves Blizzard's native tracker size, fonts, and objective layout untouched so scenario aura updates remain untainted.")

    function page:Refresh()
        trackerAppearanceEnabled:Refresh()
        trackerFitHeight:Refresh()
        trackerBackgroundOpacity:Refresh()
        trackerBorderEnabled:Refresh()
        trackerClassBorder:Refresh()
        trackerMouseoverControls:Refresh()
        trackerMinimizeToButton:Refresh()

        local appearanceActive = trackerAppearanceEnabled:GetChecked() == true
        UI.SetControlEnabled(trackerFitHeight, appearanceActive)
        UI.SetControlEnabled(trackerBackgroundOpacity, appearanceActive)
        UI.SetControlEnabled(trackerBorderEnabled, appearanceActive)
        UI.SetControlEnabled(trackerClassBorder, appearanceActive and trackerBorderEnabled:GetChecked() == true)
        UI.SetControlEnabled(trackerMouseoverControls, appearanceActive)
        UI.SetControlEnabled(trackerMinimizeToButton, appearanceActive)
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateDialogsPage(parent)
    local UI = ns.UI
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local cardW = 374
    local leftX = 0
    local rightX = cardW + 14

    local main = CreateSectionCard(page, "Auto Confirm", cardW, 278)
    main:SetPoint("TOPLEFT", page, "TOPLEFT", leftX, 0)

    local enabled = UI.CreateCheckbox(
        main,
        "Enable auto-confirm dialogs",
        "Allows ZoidsTools to approve only the dialog types enabled below.",
        function() return ns.GetAutoConfirmOption and ns:GetAutoConfirmOption("enabled") end,
        function(value)
            if ns.SetAutoConfirmOption then ns:SetAutoConfirmOption("enabled", value) end
            if page.Refresh then page:Refresh() end
        end
    )
    PlaceFirst(enabled, main)

    local deleteGoodItems = UI.CreateCheckbox(
        main,
        "Fill DELETE for protected items",
        "Types DELETE for high-quality item and quest-item deletion prompts. You must click the confirmation button yourself.",
        function() return ns.GetAutoConfirmOption and ns:GetAutoConfirmOption("deleteGoodItems") end,
        function(value) if ns.SetAutoConfirmOption then ns:SetAutoConfirmOption("deleteGoodItems", value) end end
    )
    PlaceBelow(deleteGoodItems, enabled)

    local disenchantRolls = UI.CreateCheckbox(
        main,
        "Confirm disenchant loot rolls",
        "Automatically accepts Blizzard disenchant-roll confirmation prompts.",
        function() return ns.GetAutoConfirmOption and ns:GetAutoConfirmOption("disenchantRolls") end,
        function(value) if ns.SetAutoConfirmOption then ns:SetAutoConfirmOption("disenchantRolls", value) end end
    )
    PlaceBelow(disenchantRolls, deleteGoodItems)

    local bindPrompts = UI.CreateCheckbox(
        main,
        "Confirm bind-on-pickup rolls",
        "Automatically confirms bind-on-pickup loot rolls. Equipping or using an item is never confirmed automatically.",
        function() return ns.GetAutoConfirmOption and ns:GetAutoConfirmOption("bindPrompts") end,
        function(value) if ns.SetAutoConfirmOption then ns:SetAutoConfirmOption("bindPrompts", value) end end
    )
    PlaceBelow(bindPrompts, disenchantRolls)

    local craftingOrderReagents = UI.CreateCheckbox(
        main,
        "Confirm crafting-order reagents",
        "Automatically accepts the warning when filling a crafting order with some of your own reagents.",
        function() return ns.GetAutoConfirmOption and ns:GetAutoConfirmOption("craftingOrderReagents") end,
        function(value) if ns.SetAutoConfirmOption then ns:SetAutoConfirmOption("craftingOrderReagents", value) end end
    )
    PlaceBelow(craftingOrderReagents, bindPrompts)

    local note = main:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", craftingOrderReagents, "BOTTOMLEFT", 4, -16)
    note:SetWidth(cardW - 40)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.90, 0.72, 0.34)
    note:SetText("This is intentionally opt-in. Only checked dialog families are touched.")

    local modification = CreateSectionCard(page, "Item Changes", cardW, 220)
    modification:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, 0)

    local replaceEnchant = UI.CreateCheckbox(
        modification,
        "Confirm enchant replacement",
        "Automatically approves replacing an existing enchant.",
        function() return ns.GetAutoConfirmOption and ns:GetAutoConfirmOption("replaceEnchant") end,
        function(value) if ns.SetAutoConfirmOption then ns:SetAutoConfirmOption("replaceEnchant", value) end end
    )
    PlaceFirst(replaceEnchant, modification)

    local replaceSockets = UI.CreateCheckbox(
        modification,
        "Confirm socket replacement",
        "Automatically approves replacing socketed gems.",
        function() return ns.GetAutoConfirmOption and ns:GetAutoConfirmOption("replaceSockets") end,
        function(value) if ns.SetAutoConfirmOption then ns:SetAutoConfirmOption("replaceSockets", value) end end
    )
    PlaceBelow(replaceSockets, replaceEnchant)

    local merchantTradeTimers = UI.CreateCheckbox(
        modification,
        "Confirm trade-timer removal",
        "Automatically approves actions that remove an item's refund or trade timer.",
        function() return ns.GetAutoConfirmOption and ns:GetAutoConfirmOption("merchantTradeTimers") end,
        function(value) if ns.SetAutoConfirmOption then ns:SetAutoConfirmOption("merchantTradeTimers", value) end end
    )
    PlaceBelow(merchantTradeTimers, replaceSockets)

    local purchases = CreateSectionCard(page, "Purchases", cardW, 166)
    purchases:SetPoint("TOPLEFT", modification, "BOTTOMLEFT", 0, -14)

    local tokenPurchases = UI.CreateCheckbox(
        purchases,
        "Confirm token purchases",
        "Automatically confirms purchase prompts for token or currency items.",
        function() return ns.GetAutoConfirmOption and ns:GetAutoConfirmOption("tokenPurchases") end,
        function(value) if ns.SetAutoConfirmOption then ns:SetAutoConfirmOption("tokenPurchases", value) end end
    )
    PlaceFirst(tokenPurchases, purchases)

    local highCostPurchases = UI.CreateCheckbox(
        purchases,
        "Confirm high-cost purchases",
        "Automatically confirms Blizzard's high-cost purchase warning.",
        function() return ns.GetAutoConfirmOption and ns:GetAutoConfirmOption("highCostPurchases") end,
        function(value) if ns.SetAutoConfirmOption then ns:SetAutoConfirmOption("highCostPurchases", value) end end
    )
    PlaceBelow(highCostPurchases, tokenPurchases)

    local purchaseNote = purchases:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    purchaseNote:SetPoint("TOPLEFT", highCostPurchases, "BOTTOMLEFT", 4, -14)
    purchaseNote:SetWidth(cardW - 40)
    purchaseNote:SetJustifyH("LEFT")
    purchaseNote:SetTextColor(0.78, 0.78, 0.72)
    purchaseNote:SetText("Leave purchase confirmations off if you prefer one last manual check before spending currency.")

    function page:Refresh()
        enabled:Refresh()
        deleteGoodItems:Refresh()
        disenchantRolls:Refresh()
        bindPrompts:Refresh()
        craftingOrderReagents:Refresh()
        replaceEnchant:Refresh()
        replaceSockets:Refresh()
        merchantTradeTimers:Refresh()
        tokenPurchases:Refresh()
        highCostPurchases:Refresh()

        local active = enabled:GetChecked() == true
        UI.SetControlEnabled(deleteGoodItems, active)
        UI.SetControlEnabled(disenchantRolls, active)
        UI.SetControlEnabled(bindPrompts, active)
        UI.SetControlEnabled(craftingOrderReagents, active)
        UI.SetControlEnabled(replaceEnchant, active)
        UI.SetControlEnabled(replaceSockets, active)
        UI.SetControlEnabled(merchantTradeTimers, active)
        UI.SetControlEnabled(tokenPurchases, active)
        UI.SetControlEnabled(highCostPurchases, active)
    end

    page:SetScript("OnShow", function(self) self:Refresh() end)

    return page
end

local function CreateModernSearch(frame)
    local search = CreateFrame("EditBox", nil, frame.top, "BackdropTemplate")
    search:SetSize(200, 27)
    search:SetPoint("BOTTOMRIGHT", frame.top, "BOTTOMRIGHT", -18, 7)
    search:SetAutoFocus(false)
    search:SetMaxLetters(80)
    search:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
    search:SetTextInsets(28, 34, 0, 0)
    search:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = (Theme and Theme.panelBorder) or "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    search:SetBackdropColor(0.008, 0.010, 0.014, 0.98)
    search:SetBackdropBorderColor(0.90, 0.68, 0.24, 0.66)

    search.icon = search:CreateTexture(nil, "OVERLAY")
    search.icon:SetPoint("LEFT", search, "LEFT", 8, 0)
    search.icon:SetSize(15, 15)
    search.icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    search.icon:SetVertexColor(0.95, 0.72, 0.28)

    search.placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    search.placeholder:SetPoint("LEFT", search, "LEFT", 29, 0)
    search.placeholder:SetText("Search settings...")
    search.placeholder:SetTextColor(0.55, 0.56, 0.58)

    local clear = CreateFrame("Button", nil, search, "BackdropTemplate")
    clear:SetSize(24, 21)
    clear:SetPoint("RIGHT", search, "RIGHT", -3, 0)
    clear:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    clear:SetBackdropColor(0.02, 0.02, 0.025, 0.88)
    clear:SetBackdropBorderColor(0.72, 0.55, 0.20, 0.72)
    clear.text = clear:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clear.text:SetPoint("CENTER", 0, 1)
    clear.text:SetText("X")
    clear.text:SetTextColor(0.95, 0.78, 0.30)
    clear:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.16, 0.11, 0.04, 0.95)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Clear search", 1, 0.82, 0.18)
        GameTooltip:Show()
    end)
    clear:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.02, 0.02, 0.025, 0.88)
        GameTooltip:Hide()
    end)
    clear:SetScript("OnClick", function()
        search:SetText("")
        search:SetFocus()
    end)
    clear:Hide()

    local results = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    results:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 0, -4)
    results:SetSize(310, 40)
    results:SetFrameStrata("FULLSCREEN_DIALOG")
    results:SetFrameLevel(250)
    results:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = (Theme and Theme.panelBorder) or "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    results:SetBackdropColor(0.008, 0.010, 0.014, 0.99)
    results:SetBackdropBorderColor(0.85, 0.66, 0.28, 0.72)
    results:Hide()
    results.rows = {}
    results.matches = {}

    for index = 1, 7 do
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

            if ShowPage then
                ShowPage(entry._modernPageKey or entry.pageKey)
            end
            results:Hide()
            search:SetFocus()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    HighlightSearchControl(frame, entry.control)
                end)
            else
                HighlightSearchControl(frame, entry.control)
            end
        end)
        results.rows[index] = row
    end

    local function RefreshResults()
        local query = NormalizeSearchText(search:GetText())
        search.placeholder:SetShown(query == "")
        clear:SetShown(query ~= "")
        wipe(results.matches)
        if #query < 2 then results:Hide() return end

        local scored = {}
        local used = {}
        for _, entry in ipairs(ns.UI and ns.UI.SearchEntries or {}) do
            local pageKey = entry.pageKey == "builds" and "talents" or entry.pageKey
            local modernEntry = entry.ZTModernSearch == true or (entry.control and frame.pageHost and IsDescendantOf(entry.control, frame.pageHost))
            if pageKey and pageByKey[pageKey] and entry.control and modernEntry and not used[entry] then
                entry._modernPageKey = pageKey
                local score = ScoreSearchEntry(entry, query)
                if score > 0 then
                    scored[#scored + 1] = { entry = entry, score = score }
                    used[entry] = true
                end
            end
        end

        table.sort(scored, function(a, b)
            if a.score == b.score then return a.entry.label < b.entry.label end
            return a.score > b.score
        end)

        local count = math.min(7, #scored)
        for index, row in ipairs(results.rows) do
            local match = scored[index] and scored[index].entry
            results.matches[index] = match
            row:SetShown(match ~= nil)
            if match then
                row.label:SetText(match.label)
                local pageKey = match._modernPageKey or match.pageKey
                row.page:SetText((pageByKey[pageKey] and pageByKey[pageKey].label or pageKey) .. "  >  setting")
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
        if results.rows[1]:IsShown() then
            results.rows[1]:Click()
        else
            search:SetFocus()
        end
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
        if C_Timer and C_Timer.After then
            C_Timer.After(0.08, function()
                if search:HasFocus() then
                    return
                end
                if results:IsMouseOver() then
                    return
                end
                results:Hide()
            end)
        elseif not results:IsMouseOver() then
            results:Hide()
        end
    end)

    frame.settingsSearch = search
    frame.searchClear = clear
    frame.searchResults = results
end

local modernPageCreators = {
    inventory = function(parent) return ns:CreateWarbandItemsPage(parent) end,
    warband = CreateWarbandPage,
    professionweekly = CreateProfessionWeeklyPage,
    minimap = CreateMinimapPage,
    general = CreateInterfacePage,
    tooltips = CreateTooltipsPage,
    windows = CreateWindowsPage,
    chat = CreateChatPage,
    items = CreateItemsPage,
    professions = CreateProfessionsPage,
    talents = CreateTalentsPage,
    meters = CreateMetersPage,
    combat = CreateCombatPage,
    unitframes = CreateUnitFramesPage,
    macros = CreateMacrosPage,
    mounts = CreateMountsPage,
    loot = CreateLootPage,
    quests = CreateQuestsPage,
    tracker = CreateTrackerPage,
    dialogs = CreateDialogsPage,
}

local function EnsureModernPage(frame, pageKey)
    if not frame or not pageKey or pageKey == "overview" then
        return frame and frame.overview or nil
    end

    frame.modernPages = frame.modernPages or {}
    if frame.modernPages[pageKey] then
        return frame.modernPages[pageKey]
    end

    local creator = modernPageCreators[pageKey]
    if type(creator) ~= "function" then
        return nil
    end

    if ns.RecordDiagnosticActivity then
        ns:RecordDiagnosticActivity("Settings.CreatePage." .. tostring(pageKey))
    end
    local page = CreateModernPage(frame.pageHost, pageKey, creator)
    frame.modernPages[pageKey] = page

    local searchEntry = frame.modernPageSearchEntries and frame.modernPageSearchEntries[pageKey]
    if searchEntry and page then
        searchEntry.control = page
    end
    return page
end


local function CreateModernWindow()
    if UI2.frame then
        return UI2.frame
    end

    local frame = CreateFrame("Frame", "ZoidsToolsModernWindow", UIParent, "BasicFrameTemplateWithInset")
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
        SavePosition(self)
    end)
    frame:Hide()
    table.insert(UISpecialFrames, "ZoidsToolsModernWindow")

    frame.TitleText:SetText("ZoidsTools Next")
    frame.TitleText:SetTextColor(1, 0.82, 0)

    frame.sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -42)
    frame.sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PADDING, PADDING)
    frame.sidebar:SetWidth(SIDEBAR_WIDTH)
    ApplyBackdrop(frame.sidebar, 0.72)

    frame.brand = frame.sidebar:CreateFontString(nil, "OVERLAY")
    frame.brand:SetPoint("TOPLEFT", frame.sidebar, "TOPLEFT", 14, -16)
    frame.brand:SetFont("Fonts\\MORPHEUS.TTF", 30, "OUTLINE")
    frame.brand:SetTextColor(1, 0.82, 0.10)
    frame.brand:SetText("ZoidsTools")

    frame.brandSub = frame.sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.brandSub:SetPoint("TOPLEFT", frame.brand, "BOTTOMLEFT", 1, -5)
    frame.brandSub:SetText("Experimental UI")

    frame.content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.content:SetPoint("TOPLEFT", frame.sidebar, "TOPRIGHT", 14, 0)
    frame.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING)
    ApplyBackdrop(frame.content, 0.62)

    local r, g, b = GetClassColor()
    frame.top = CreateFrame("Frame", nil, frame.content, "BackdropTemplate")
    frame.top:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 14, -14)
    frame.top:SetPoint("TOPRIGHT", frame.content, "TOPRIGHT", -14, -14)
    frame.top:SetHeight(TOP_HEIGHT)
    ApplyBackdrop(frame.top, 0.50)

    frame.topGlow = frame.top:CreateTexture(nil, "BACKGROUND")
    frame.topGlow:SetPoint("TOPLEFT", 2, -2)
    frame.topGlow:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.topGlow:SetColorTexture(r, g, b, 0.055)

    frame.pageTitle = frame.top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.pageTitle:SetPoint("TOPLEFT", frame.top, "TOPLEFT", 18, -14)
    frame.pageTitle:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    frame.pageTitle:SetTextColor(1, 0.82, 0)

    frame.pageDescription = frame.top:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.pageDescription:SetPoint("TOPLEFT", frame.pageTitle, "BOTTOMLEFT", 0, -6)
    frame.pageDescription:SetPoint("RIGHT", frame.top, "RIGHT", -220, 0)
    frame.pageDescription:SetJustifyH("LEFT")
    frame.pageDescription:SetTextColor(0.84, 0.82, 0.74)

    frame.character = frame.top:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.character:SetPoint("TOPRIGHT", frame.top, "TOPRIGHT", -18, -18)
    frame.character:SetTextColor(r, g, b)

    frame.version = frame.top:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.version:SetPoint("TOPRIGHT", frame.character, "BOTTOMRIGHT", 0, -6)

    CreateModernSearch(frame)

    frame.body = CreateFrame("Frame", nil, frame.content)
    frame.body:SetPoint("TOPLEFT", frame.top, "BOTTOMLEFT", 0, -14)
    frame.body:SetPoint("BOTTOMRIGHT", frame.content, "BOTTOMRIGHT", -14, 14)

    frame.subnav = CreateFrame("Frame", nil, frame.body)
    frame.subnav:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, 0)
    frame.subnav:SetPoint("TOPRIGHT", frame.body, "TOPRIGHT", 0, 0)
    frame.subnav:SetHeight(31)
    frame.subnav:Hide()

    frame.pageHost = CreateFrame("Frame", nil, frame.body)
    frame.pageHost:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, 0)
    frame.pageHost:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", 0, 0)

    frame.navButtons = {}
    local y = -120
    for _, section in ipairs(sections) do
        local button = CreateNavButton(frame.sidebar, section)
        button:SetPoint("TOPLEFT", frame.sidebar, "TOPLEFT", 14, y)
        button:SetScript("OnClick", function()
            UI2.Show(section.defaultPageKey)
        end)
        frame.navButtons[section.key] = button
        y = y - 52
    end

    frame.subnavButtons = {}
    for _, section in ipairs(sections) do
        frame.subnavButtons[section.key] = {}
        local previous
        for index, tabInfo in ipairs(section.tabs or {}) do
            local width = tabInfo.label == "Weekly Goals" and 142 or (tabInfo.label == "Unit Frames" and 128 or 118)
            local button = CreateButton(frame.subnav, tabInfo.label, width, 27)
            if index == 1 then
                button:SetPoint("TOPLEFT", frame.subnav, "TOPLEFT", 0, 0)
            else
                button:SetPoint("LEFT", previous, "RIGHT", 10, 0)
            end
            button:SetScript("OnClick", function()
                UI2.Show(tabInfo.key)
            end)
            button:Hide()
            frame.subnavButtons[section.key][tabInfo.key] = button
            previous = button
        end
    end

    frame.overview = CreateFrame("Frame", nil, frame.pageHost)
    frame.overview:SetAllPoints()
    frame.overview.ZTPageKey = "overview"
    frame.modernPages = {}
    frame.modernPageSearchEntries = {}

    if ns.UI and ns.UI.SearchEntries then
        ns.UI.SearchEntries[#ns.UI.SearchEntries + 1] = {
            pageKey = "overview",
            control = frame.overview,
            label = "Overview",
            tooltip = "Status, quick actions, and common ZoidsTools areas.",
            ZTModernSearch = true,
            _modernPageKey = "overview",
        }
        for key in pairs(modernPageCreators) do
            local info = pageByKey[key]
            if info then
                local entry = {
                    pageKey = key,
                    control = frame.overview,
                    label = info.label,
                    tooltip = info.description or "",
                    ZTModernSearch = true,
                    _modernPageKey = key,
                }
                ns.UI.SearchEntries[#ns.UI.SearchEntries + 1] = entry
                frame.modernPageSearchEntries[key] = entry
            end
        end
    end

    frame.statusTiles = {
        CreateStatusTile(frame.overview, "Diagnostics", function()
            local active = ns.IsDiagnosticsActive and ns:IsDiagnosticsActive()
            return active and "Running" or "Ready", active
        end),
        CreateStatusTile(frame.overview, "Damage Meter", function()
            local enabled = ns.GetCustomDamageMeterEnabled and ns:GetCustomDamageMeterEnabled()
            return enabled and "ZoidsTools" or "Blizzard/default", enabled
        end),
        CreateStatusTile(frame.overview, "Smart Mounts", function()
            local enabled = ReadDB({ "mounts", "enabled" }, false) == true
            return enabled and "Enabled" or "Disabled", enabled
        end),
        CreateStatusTile(frame.overview, "Quest Tracker", function()
            local enabled = ReadDB({ "quests", "trackerAppearance", "enabled" }, false) == true
            return enabled and "Customized" or "Blizzard style", enabled
        end),
    }

    frame.statusTiles[1]:SetPoint("TOPLEFT", frame.overview, "TOPLEFT", 0, 0)
    for index = 2, #frame.statusTiles do
        frame.statusTiles[index]:SetPoint("LEFT", frame.statusTiles[index - 1], "RIGHT", 10, 0)
    end

    frame.quickTitle = frame.overview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.quickTitle:SetPoint("TOPLEFT", frame.statusTiles[1], "BOTTOMLEFT", 0, -22)
    frame.quickTitle:SetTextColor(1, 0.82, 0.18)
    frame.quickTitle:SetText("Feature Areas")

    frame.areaRows = {
        CreateAreaRow(frame.overview, "Warband Weekly", "Mythic+, Great Vault, keystones, and current-expansion saves across your characters.", "warband"),
        CreateAreaRow(frame.overview, "Weekly Goals", "Great Vault, Sparks, popular weekly activities, and Midnight profession Knowledge.", "professionweekly"),
        CreateAreaRow(frame.overview, "Core", "Minimap, player tooltips, window movement, audio sync, and Talking Head.", "minimap"),
        CreateAreaRow(frame.overview, "Character", "Items, stat goals, talents, and recommendations.", "items"),
        CreateAreaRow(frame.overview, "Combat", "Meters, keybind text, range tint, missing buffs, unit frames, and macros.", "meters"),
        CreateAreaRow(frame.overview, "Automation", "Fast loot, vendor tools, quest automation, tracker styling, and quest item button.", "loot"),
    }

    frame.areaRows[1]:SetPoint("TOPLEFT", frame.quickTitle, "BOTTOMLEFT", 0, -10)
    for index = 2, #frame.areaRows do
        frame.areaRows[index]:SetPoint("TOPLEFT", frame.areaRows[index - 1], "BOTTOMLEFT", 0, -9)
    end

    frame.note = frame.overview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.note:SetPoint("TOPLEFT", frame.areaRows[#frame.areaRows], "BOTTOMLEFT", 0, -18)
    frame.note:SetWidth(760)
    frame.note:SetJustifyH("LEFT")
    frame.note:SetTextColor(0.72, 0.74, 0.72)
    frame.note:SetText("ZoidsTools settings are organized into focused areas. Use the sidebar, page tabs, or search to jump straight to what you need.")

    frame.placeholder = CreateFrame("Frame", nil, frame.pageHost, "BackdropTemplate")
    frame.placeholder:SetAllPoints()
    frame.placeholder:Hide()

    frame.placeholderTitle = frame.placeholder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.placeholderTitle:SetPoint("TOPLEFT", frame.placeholder, "TOPLEFT", 0, -2)
    frame.placeholderTitle:SetTextColor(1, 0.82, 0.18)

    frame.placeholderBody = frame.placeholder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.placeholderBody:SetPoint("TOPLEFT", frame.placeholderTitle, "BOTTOMLEFT", 0, -10)
    frame.placeholderBody:SetWidth(690)
    frame.placeholderBody:SetJustifyH("LEFT")
    frame.placeholderBody:SetTextColor(0.82, 0.82, 0.78)

    UI2.frame = frame
    UI2.RefreshWarbandDashboard = function()
        local warbandPage = frame.modernPages and frame.modernPages.warband
        if warbandPage and warbandPage:IsShown() and warbandPage.Refresh then
            warbandPage:Refresh()
        end
    end
    UI2.RefreshProfessionWeeklyDashboard = function()
        local professionPage = frame.modernPages and frame.modernPages.professionweekly
        if professionPage and professionPage:IsShown() and professionPage.Refresh then
            professionPage:Refresh()
        end
    end
    RestorePosition(frame)

    return frame
end

function ShowPage(pageKey)
    local frame = CreateModernWindow()
    local requestedKey = pageAliases[pageKey or ""] or pageKey or "overview"
    local requestedSection = sectionByKey[requestedKey]
    local info = pageByKey[requestedKey]
    if requestedSection and requestedSection.defaultPageKey then
        info = pageByKey[requestedSection.defaultPageKey] or info
    end
    info = info or pageByKey.overview
    local section = sectionByKey[info.sectionKey or info.key] or sectionByKey.overview
    local r, g, b = GetClassColor()

    if ns.RecordDiagnosticActivity then
        ns:RecordDiagnosticActivity("Settings.ShowPage." .. tostring(info.key))
    end

    if info.key ~= "overview" then
        EnsureModernPage(frame, info.key)
    end

    frame.pageKey = info.key
    frame.pageTitle:SetText(info.label)
    frame.pageDescription:SetText(info.description or "")
    frame.character:SetTextColor(r, g, b)
    frame.character:SetText(((UnitName and UnitName("player")) or "Player") .. "  •  " .. ((GetSpecialization and GetSpecializationInfo and GetSpecialization() and select(2, GetSpecializationInfo(GetSpecialization()))) or "No Spec"))
    frame.version:SetText("ZoidsTools " .. tostring(ns.version or "Development"))
    frame.topGlow:SetColorTexture(r, g, b, 0.055)

    for key, button in pairs(frame.navButtons) do
        SetButtonSelected(button, key == section.key)
    end

    for sectionKey, buttons in pairs(frame.subnavButtons) do
        for tabKey, button in pairs(buttons) do
            button:SetShown(sectionKey == section.key and #(section.tabs or {}) > 1)
            SetButtonSelected(button, tabKey == info.key)
        end
    end

    if #(section.tabs or {}) > 1 then
        frame.subnav:Show()
        frame.pageHost:ClearAllPoints()
        frame.pageHost:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, -42)
        frame.pageHost:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", 0, 0)
    else
        frame.subnav:Hide()
        frame.pageHost:ClearAllPoints()
        frame.pageHost:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, 0)
        frame.pageHost:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", 0, 0)
    end

    for key, page in pairs(frame.modernPages) do
        page:SetShown(key == info.key)
        if key == info.key and page.Refresh then
            page:Refresh()
        end
    end

    if info.key == "overview" then
        frame.placeholder:Hide()
        frame.overview:Show()
        for _, tile in ipairs(frame.statusTiles) do
            tile:Refresh()
        end
    elseif frame.modernPages[info.key] then
        frame.overview:Hide()
        frame.placeholder:Hide()
    else
        frame.overview:Hide()
        frame.placeholder:Show()
        frame.placeholderTitle:SetText(info.label)
        frame.placeholderBody:SetText((info.description or "") .. "\n\nThis page is not available in the current ZoidsTools UI.")
    end
end

-- Module callbacks still use the shared UI namespace. Refresh only an existing
-- visible page so background updates do not construct the settings window.
function UI2.RefreshVisiblePage()
    local frame = UI2.frame
    if not frame or not frame:IsShown() then return end
    local page = frame.modernPages and frame.modernPages[frame.pageKey]
    if page and page.Refresh then
        page:Refresh()
    elseif frame.pageKey == "overview" then
        for _, tile in ipairs(frame.statusTiles or {}) do tile:Refresh() end
    end
end

ns.UI.RefreshVisiblePage = UI2.RefreshVisiblePage

function UI2.Show(pageKey)
    local frame = CreateModernWindow()
    frame:Raise()
    frame:Show()
    ShowPage(pageKey or "overview")
end

function UI2.Toggle(pageKey)
    local frame = CreateModernWindow()
    if frame:IsShown() then
        frame:Hide()
    else
        UI2.Show(pageKey)
    end
end
