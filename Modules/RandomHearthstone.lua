local _, ns = ...

local BUTTON_NAME = "ZoidsToolsRandomHearthstoneButton"
local MACRO_NAME = "ZT Hearth"
local MACRO_ICON = 134414
local lastChoice
local macroChoice
local selector
local eventFrame

-- Curated genuine Hearthstone replacements only. Similar-looking teleport
-- toys (notably Tome of Town Portal) are intentionally not included.
local HEARTHSTONES = {
    { id = 6948, spell = 8690, item = true, name = "Hearthstone" },
    { id = 263933, spell = 1270814, name = "Preyseeker's Hearthstone" },
    { id = 264367, spell = 1299014, name = "Mycomancer's Hearthspore" },
    { id = 265100, spell = 1273401, name = "Corewarden's Hearthstone" },
    { id = 245970, spell = 1240219, name = "P.O.S.T. Master's Express Hearthstone" },
    { id = 246565, spell = 1242509, name = "Cosmic Hearthstone" },
    { id = 257736, spell = 1261979, name = "Lightcalled Hearthstone" },
    { id = 235016, spell = 1217281, name = "Redeployment Module" },
    { id = 54452, spell = 75136, name = "Ethereal Portal" },
    { id = 64488, spell = 94719, name = "The Innkeeper's Daughter" },
    { id = 93672, spell = 136508, name = "Dark Portal" },
    { id = 162973, spell = 278244, name = "Greatfather Winter's Hearthstone" },
    { id = 163045, spell = 278559, name = "Headless Horseman's Hearthstone" },
    { id = 165669, spell = 285362, name = "Lunar Elder's Hearthstone" },
    { id = 165670, spell = 285424, name = "Peddlefeet's Lovely Hearthstone" },
    { id = 165802, spell = 286031, name = "Noble Gardener's Hearthstone" },
    { id = 166746, spell = 286331, name = "Fire Eater's Hearthstone" },
    { id = 166747, spell = 286353, name = "Brewfest Reveler's Hearthstone" },
    { id = 168907, spell = 298068, name = "Holographic Digitalization Hearthstone" },
    { id = 172179, spell = 308742, name = "Eternal Traveler's Hearthstone" },
    { id = 188952, spell = 363799, name = "Dominated Hearthstone" },
    { id = 190196, spell = 366945, name = "Enlightened Hearthstone" },
    { id = 190237, spell = 367013, name = "Broker Translocation Matrix" },
    { id = 193588, spell = 375357, name = "Timewalker's Hearthstone" },
    { id = 200630, spell = 391042, name = "Ohn'ir Windsage's Hearthstone" },
    { id = 206195, spell = 412555, name = "Path of the Naaru" },
    { id = 208704, spell = 420418, name = "Deepdweller's Earthen Hearthstone" },
    { id = 209035, spell = 422284, name = "Hearthstone of the Flame" },
    { id = 212337, spell = 401802, name = "Stone of the Hearth" },
    { id = 228940, spell = 463481, name = "Notorious Thread's Hearthstone" },
    { id = 236687, spell = 1220729, name = "Explosive Hearthstone" },
    { id = 263489, spell = 1270583, name = "Naaru's Enfold" },
    { id = 210455, spell = 438606, name = "Draenic Hologem", races = { Draenei = true, LightforgedDraenei = true } },
    { id = 184353, spell = 345393, name = "Kyrian Hearthstone", achievement = 15242 },
    { id = 183716, spell = 342122, name = "Venthyr Sinstone", achievement = 15245 },
    { id = 180290, spell = 326064, name = "Night Fae Hearthstone", achievement = 15244 },
    { id = 182773, spell = 340200, name = "Necrolord Hearthstone", achievement = 15243 },
}

local function EnsureDB()
    if not ns.db then return nil end
    ns.db.macros = ns.db.macros or {}
    local db = ns.db.macros
    if db.hearthstoneEnabled == nil then db.hearthstoneEnabled = true end
    if type(db.hearthstoneExcluded) ~= "table" then db.hearthstoneExcluded = {} end
    return db
end

local function IsOwned(entry)
    if entry.item then
        if C_Item and C_Item.GetItemCount then
            return (C_Item.GetItemCount(entry.id) or 0) > 0
        end
        return GetItemCount and (GetItemCount(entry.id) or 0) > 0
    end
    if not PlayerHasToy or not PlayerHasToy(entry.id) then return false end
    if entry.races then
        local _, race = UnitRace("player")
        if not entry.races[race] then return false end
    end
    if entry.achievement then
        local _, _, _, completed = GetAchievementInfo(entry.achievement)
        if not completed then return false end
    end
    return true
end

local function GetDisplayName(entry)
    if entry.item and C_Item and C_Item.GetItemNameByID then
        return C_Item.GetItemNameByID(entry.id) or entry.name
    elseif C_ToyBox and C_ToyBox.GetToyInfo then
        local name = C_ToyBox.GetToyInfo(entry.id)
        return type(name) == "string" and name or entry.name
    end
    return entry.name
end

local function GetPool()
    local db = EnsureDB()
    local pool = {}
    if not db then return pool end
    for _, entry in ipairs(HEARTHSTONES) do
        if IsOwned(entry) and db.hearthstoneExcluded[tostring(entry.id)] ~= true then
            pool[#pool + 1] = entry
        end
    end
    return pool
end

local function ChooseRandom()
    local pool = GetPool()
    if #pool == 0 then return nil end
    local choices = pool
    if #pool > 1 and lastChoice then
        choices = {}
        for _, entry in ipairs(pool) do
            if entry.id ~= lastChoice then choices[#choices + 1] = entry end
        end
    end
    local choice = choices[math.random(1, #choices)]
    lastChoice = choice.id
    return choice
end

local function EnsureButton()
    local button = _G[BUTTON_NAME]
    if button then return button end
    button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    -- Accept both forms: keybindings fire on button-down, while existing or
    -- user-written /click macros commonly simulate a button release.
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("type", "macro")
    button:SetAttribute("pressAndHoldAction", true)
    button:SetAttribute("macrotext1", "/stopmacro")
    button:SetAttribute("macrotext", "/stopmacro")
    button:SetScript("PreClick", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        local entry = ChooseRandom()
        local macro = entry and ("/use item:" .. entry.id) or "/stopmacro"
        self:SetAttribute("macrotext1", macro)
        self:SetAttribute("macrotext", macro)
    end)
    return button
end

local function FindMacro()
    if not GetMacroInfo then return nil end
    if GetMacroIndexByName then
        local index = GetMacroIndexByName(MACRO_NAME)
        if index and index > 0 then return index end
    end
    local lastMacro = (MAX_ACCOUNT_MACROS or 120) + (MAX_CHARACTER_MACROS or 18)
    for index = 1, lastMacro do
        if GetMacroInfo(index) == MACRO_NAME then return index end
    end
end

local function RefreshMacro()
    local db = EnsureDB()
    if not db or not db.hearthstoneEnabled or (InCombatLockdown and InCombatLockdown()) then return end
    -- Modern WoW blocks macros from chaining into this addon's protected
    -- randomizer. Keep the generated macro fully secure with a direct item
    -- action, then choose a new item after the resulting loading transition.
    local entry = ChooseRandom()
    macroChoice = entry
    local body
    if entry then
        body = "#showtooltip item:" .. entry.id .. "\n/use item:" .. entry.id
    else
        body = "#showtooltip\n/stopmacro"
    end
    local index = FindMacro()
    if index and EditMacro then
        local _, _, oldBody = GetMacroInfo(index)
        if oldBody ~= body then pcall(EditMacro, index, MACRO_NAME, MACRO_ICON, body) end
    elseif CreateMacro then
        pcall(CreateMacro, MACRO_NAME, MACRO_ICON, body, false)
    end
end

function ns:GetRandomHearthstoneEnabled()
    local db = EnsureDB()
    return db and db.hearthstoneEnabled == true
end

function ns:SetRandomHearthstoneEnabled(value)
    local db = EnsureDB()
    if not db then return end
    db.hearthstoneEnabled = value == true
    if db.hearthstoneEnabled then RefreshMacro() end
end

function ns:RefreshRandomHearthstoneMacro()
    RefreshMacro()
end

local function CreateSelector()
    if selector then return selector end
    local frame = CreateFrame("Frame", "ZoidsToolsHearthstoneSelector", UIParent, "BackdropTemplate")
    frame:SetSize(440, 450)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(200)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    frame:SetBackdropColor(0.015, 0.018, 0.025, 0.98)
    frame:SetBackdropBorderColor(0.88, 0.66, 0.24, 0.9)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Selected Hearthstones")
    local help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    help:SetPoint("RIGHT", -42, 0)
    help:SetJustifyH("LEFT")
    help:SetText("Only owned, genuine Hearthstones are shown. Uncheck any appearance you do not want selected.")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -62)
    scroll:SetPoint("BOTTOMRIGHT", -36, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(450, 1)
    scroll:SetScrollChild(content)
    frame.content = content
    frame.rows = {}
    frame:Hide()
    selector = frame
    return frame
end

local function RefreshSelector()
    local frame = CreateSelector()
    for _, row in ipairs(frame.rows) do row:Hide() end
    wipe(frame.rows)
    local owned = {}
    for _, entry in ipairs(HEARTHSTONES) do
        if IsOwned(entry) then owned[#owned + 1] = entry end
    end
    table.sort(owned, function(a, b) return GetDisplayName(a) < GetDisplayName(b) end)
    local db = EnsureDB()
    for index, entry in ipairs(owned) do
        local rowEntry = entry
        local row = CreateFrame("CheckButton", nil, frame.content, "ChatConfigCheckButtonTemplate")
        row:SetPoint("TOPLEFT", 4, -((index - 1) * 30))
        row.Text:SetText(GetDisplayName(rowEntry))
        row:SetChecked(db.hearthstoneExcluded[tostring(rowEntry.id)] ~= true)
        row:SetScript("OnClick", function(self)
            db.hearthstoneExcluded[tostring(rowEntry.id)] = self:GetChecked() ~= true or nil
            if ns.UI and ns.UI.RefreshVisiblePage then ns.UI.RefreshVisiblePage() end
        end)
        frame.rows[#frame.rows + 1] = row
    end
    if #owned == 0 then
        local row = frame.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row:SetPoint("TOPLEFT", 8, -8)
        row:SetText("No eligible Hearthstones were found on this character.")
        frame.rows[#frame.rows + 1] = row
    end
    frame.content:SetHeight(math.max(480, #owned * 30 + 10))
end

function ns:OpenRandomHearthstoneSelector(anchor)
    if selector and selector:IsShown() then
        selector:Hide()
        return
    end

    local ok, errorMessage = pcall(RefreshSelector)
    if not ok then
        self:Print("Could not open the Hearthstone selector: " .. tostring(errorMessage))
        return
    end
    selector:SetFrameStrata("FULLSCREEN_DIALOG")
    selector:SetFrameLevel(200)
    selector:ClearAllPoints()
    if anchor then
        selector:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    else
        selector:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    selector:Show()
    selector:Raise()
end

function ns:CloseRandomHearthstoneSelector()
    if selector then selector:Hide() end
end

function ns:GetRandomHearthstoneStatus()
    local count = #GetPool()
    return count == 1 and "1 owned Hearthstone selected." or (count .. " owned Hearthstones selected.")
end

function ns:InitializeRandomHearthstone()
    EnsureDB()
    EnsureButton()
    RefreshMacro()
    if eventFrame then return end
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("NEW_TOY_ADDED")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
    eventFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then RefreshMacro() end
        if (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET")
            and unit == "player" and macroChoice and spellID == macroChoice.spell then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, RefreshMacro)
            else
                RefreshMacro()
            end
        end
        if selector and selector:IsShown() then RefreshSelector() end
    end)
end
