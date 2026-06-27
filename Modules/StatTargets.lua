local _, ns = ...

local eventFrame
local showHooksInstalled = false
local pendingRefresh = false
local trackedRows = {}
local hookedFunctions = {}
local fallbackTexts = {}
local sourceDropdown

local STAT_ORDER = { "crit", "haste", "mastery", "versatility" }
local SOURCE_OPTIONS = {
    { value = "mythicplus", text = "M+" },
    { value = "raid", text = "Raid" },
    { value = "pvp", text = "PvP" },
}
local LABEL_COLUMN_WIDTH = 60
local DELTA_COLUMN_WIDTH = 34
local RAW_COLUMN_WIDTH = 30
local TARGET_COLUMN_WIDTH = 32
local PERCENT_COLUMN_WIDTH = 32
local STAT_COLUMN_GAP = 1
local STAT_RIGHT_PADDING = 2

local SPEC_KEYS = {
    DEATHKNIGHT = { "blood", "frost", "unholy" },
    DEMONHUNTER = { "havoc", "vengeance", "devourer" },
    DRUID = { "balance", "feral", "guardian", "restoration" },
    EVOKER = { "devastation", "preservation", "augmentation" },
    HUNTER = { "beast-mastery", "marksmanship", "survival" },
    MAGE = { "arcane", "fire", "frost" },
    MONK = { "brewmaster", "mistweaver", "windwalker" },
    PALADIN = { "holy", "protection", "retribution" },
    PRIEST = { "discipline", "holy", "shadow" },
    ROGUE = { "assassination", "outlaw", "subtlety" },
    SHAMAN = { "elemental", "enhancement", "restoration" },
    WARLOCK = { "affliction", "demonology", "destruction" },
    WARRIOR = { "arms", "fury", "protection" },
}

local STAT_LABELS = {
    crit = STAT_CRITICAL_STRIKE or CRIT_CHANCE or "Critical Strike",
    haste = STAT_HASTE or "Haste",
    mastery = STAT_MASTERY or "Mastery",
    versatility = STAT_VERSATILITY or "Versatility",
}

local SHORT_STAT_LABELS = {
    crit = "Crit:",
    haste = "Haste:",
    mastery = "Mast:",
    versatility = "Vers:",
}

local SECONDARY_STAT_LABELS = {
    ["avoid."] = "Avoid.:",
    avoidance = "Avoid.:",
    leech = "Leech:",
    speed = "Speed:",
}

local FRAME_STAT_KEYS = {
    CRITCHANCE = "crit",
    HASTE = "haste",
    MASTERY = "mastery",
    VERSATILITY = "versatility",
}

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result = pcall(func, ...)

    if ok then
        return result
    end

    return nil
end

local function SafeNumber(value)
    if value == nil then
        return nil
    end

    local ok, number = pcall(function()
        local converted = tonumber(value)

        if converted == nil then
            return nil
        end

        return converted + 0
    end)

    if ok and type(number) == "number" then
        return number
    end

    return nil
end

local function NormalizeText(text)
    local ok, normalized = pcall(function()
        text = tostring(text or "")
        text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
        text = text:gsub("|r", "")
        text = text:gsub(":", "")
        text = text:gsub("^%s+", "")
        text = text:gsub("%s+$", "")
        return string.lower(text)
    end)

    if ok and type(normalized) == "string" then
        return normalized
    end

    return nil
end

local LABEL_TO_KEY = {}
for key, label in pairs(STAT_LABELS) do
    LABEL_TO_KEY[NormalizeText(label)] = key
end
LABEL_TO_KEY["critical strike"] = "crit"
LABEL_TO_KEY["crit"] = "crit"
LABEL_TO_KEY["haste"] = "haste"
LABEL_TO_KEY["mast"] = "mastery"
LABEL_TO_KEY["mastery"] = "mastery"
LABEL_TO_KEY["vers"] = "versatility"
LABEL_TO_KEY["versatility"] = "versatility"

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.items = ns.db.items or {}
    ns.db.items.character = ns.db.items.character or {}

    if ns.db.items.character.statTargets == nil then
        ns.db.items.character.statTargets = true
    end

    if ns.db.items.statTargetContext == nil then
        ns.db.items.statTargetContext = "mythicplus"
    end

    return ns.db.items
end

local function IsEnabled()
    local db = EnsureDB()
    return db
        and db.enabled == true
        and db.character
        and db.character.statTargets == true
end

local function GetContextLabel()
    local db = EnsureDB()
    local context = db and db.statTargetContext or "mythicplus"

    if context == "pvp" then
        return "PvP"
    end

    if context == "raid" then
        return "Raid"
    end

    return "Mythic+"
end

local function GetContextButtonText()
    local db = EnsureDB()
    local context = db and db.statTargetContext or "mythicplus"

    for _, option in ipairs(SOURCE_OPTIONS) do
        if option.value == context then
            return option.text
        end
    end

    return "M+"
end

local function GetClassAndSpec()
    local _, classToken = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    local specKey = classToken and specIndex and SPEC_KEYS[classToken] and SPEC_KEYS[classToken][specIndex]

    return classToken, specKey
end

local function GetSnapshot()
    local classToken, specKey = GetClassAndSpec()

    if not classToken or not specKey then
        return nil
    end

    local context = GetContextLabel()
    local roots = {
        _G.ZoidsToolsStatTargets,
    }

    for _, root in ipairs(roots) do
        local snapshot = root
            and root[classToken]
            and root[classToken][specKey]
            and root[classToken][specKey][context]

        if snapshot and type(snapshot.targets) == "table" then
            return snapshot, classToken, specKey, context
        end
    end

    return nil, classToken, specKey, context
end

local function GetRating(statKey)
    if statKey == "crit" then
        return SafeNumber(SafeCall(GetCombatRating, CR_CRIT_MELEE))
    elseif statKey == "haste" then
        return SafeNumber(SafeCall(GetCombatRating, CR_HASTE_MELEE))
    elseif statKey == "mastery" then
        return SafeNumber(SafeCall(GetCombatRating, CR_MASTERY))
    elseif statKey == "versatility" then
        return SafeNumber(SafeCall(GetCombatRating, CR_VERSATILITY_DAMAGE_DONE))
    end

    return nil
end

local function GetPercent(statKey)
    if statKey == "crit" then
        return SafeNumber(SafeCall(GetCritChance)) or 0
    elseif statKey == "haste" then
        return SafeNumber(SafeCall(GetHaste)) or 0
    elseif statKey == "mastery" then
        return SafeNumber(SafeCall(GetMasteryEffect)) or 0
    elseif statKey == "versatility" then
        return SafeNumber(SafeCall(GetCombatRatingBonus, CR_VERSATILITY_DAMAGE_DONE)) or 0
    end

    return 0
end

local function FormatDefaultPercent(statKey)
    local value = GetPercent(statKey)

    if value <= 0 then
        return nil
    end

    if math.abs(value - math.floor(value + 0.5)) < 0.05 then
        return string.format("%d%%", math.floor(value + 0.5))
    end

    return string.format("%.1f%%", value)
end

local function GetFallbackParent()
    return _G.CharacterFrameInsetRight or _G.CharacterStatsPane or _G.PaperDollFrame or _G.CharacterFrame
end

local function HideFallbackRows()
    for _, fontString in pairs(fallbackTexts) do
        fontString:SetText("")
        fontString:Hide()
    end
end

local function EnsureFallbackText(statKey)
    if fallbackTexts[statKey] then
        return fallbackTexts[statKey]
    end

    if InCombatLockdown and InCombatLockdown() then
        return nil
    end

    local parent = GetFallbackParent()

    if not parent then
        return nil
    end

    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text.ZTStatTargetRegion = true
    text:SetJustifyH("RIGHT")
    text:SetWidth(100)
    text:SetTextColor(1, 1, 1, 1)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    fallbackTexts[statKey] = text

    return text
end

local function GetStatKeyFromLabel(label)
    return LABEL_TO_KEY[NormalizeText(label)]
end

local function IsStatTargetRegion(region)
    return region and region.ZTStatTargetRegion == true
end

local function GetSecondaryStatLabel(label)
    return SECONDARY_STAT_LABELS[NormalizeText(label)]
end

local function LooksLikeStatValue(text)
    text = NormalizeText(text)

    if not text then
        return false
    end

    return text == ""
        or text:find("%%", 1, true) ~= nil
        or text:match("^[%+%-]?[%d,%.]+$") ~= nil
end

local function FindRowLabelFont(row)
    if not row then
        return nil
    end

    local candidates = {
        row.Label,
        row.label,
        row.Name,
        row.name,
        row.Text,
        row.text,
    }

    for _, fontString in ipairs(candidates) do
        if fontString
            and not IsStatTargetRegion(fontString)
            and type(fontString.GetObjectType) == "function"
            and fontString:GetObjectType() == "FontString" then
            return fontString
        end
    end

    if type(row.GetRegions) == "function" then
        for index = 1, select("#", row:GetRegions()) do
            local region = select(index, row:GetRegions())

            if region
                and not IsStatTargetRegion(region)
                and type(region.GetObjectType) == "function"
                and region:GetObjectType() == "FontString"
                and not LooksLikeStatValue(region:GetText()) then
                return region
            end
        end
    end

    return nil
end

local function EnsureStatLabelOverride(row)
    if not row then
        return nil
    end

    if row.ZTStatTargetLabelText then
        return row.ZTStatTargetLabelText
    end

    if InCombatLockdown and InCombatLockdown() then
        return nil
    end

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text.ZTStatTargetRegion = true
    text:SetJustifyH("LEFT")
    text:SetWidth(LABEL_COLUMN_WIDTH)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.ZTStatTargetLabelText = text

    return text
end

local function HideStatLabelOverride(row)
    if row and row.ZTStatTargetLabelText then
        row.ZTStatTargetLabelText:SetText("")
        row.ZTStatTargetLabelText:Hide()
    end
end

local function RestoreStatLabelOverride(row)
    if not row then
        return
    end

    HideStatLabelOverride(row)

    if row.ZTStatTargetLabelFont then
        if row.ZTStatTargetOriginalLabelAlpha ~= nil and row.ZTStatTargetLabelFont.SetAlpha then
            row.ZTStatTargetLabelFont:SetAlpha(row.ZTStatTargetOriginalLabelAlpha)
        elseif row.ZTStatTargetLabelFont.SetAlpha then
            row.ZTStatTargetLabelFont:SetAlpha(1)
        end
    end
end

local function ReleaseStatLabelOverride(row)
    if not row then
        return
    end

    RestoreStatLabelOverride(row)

    row.ZTStatTargetLabelFont = nil
    row.ZTStatTargetOriginalLabelText = nil
    row.ZTStatTargetOriginalLabelAlpha = nil
end

local function ApplyStatLabelOverride(row, text, labelFont)
    if not row or not text then
        RestoreStatLabelOverride(row)
        return
    end

    labelFont = labelFont or row.ZTStatTargetLabelFont or FindRowLabelFont(row)

    local overlay = EnsureStatLabelOverride(row)

    if not overlay then
        return
    end

    overlay:ClearAllPoints()
    if labelFont then
        overlay:SetPoint("LEFT", labelFont, "LEFT", 0, 0)
    else
        overlay:SetPoint("LEFT", row, "LEFT", 0, 0)
    end
    overlay:SetText(text)
    overlay:Show()

    if labelFont then
        row.ZTStatTargetLabelFont = labelFont
        row.ZTStatTargetOriginalLabelText = (labelFont.GetText and labelFont:GetText()) or row.ZTStatTargetOriginalLabelText

        if row.ZTStatTargetOriginalLabelAlpha == nil and labelFont.GetAlpha then
            row.ZTStatTargetOriginalLabelAlpha = labelFont:GetAlpha()
        end

        if labelFont.SetAlpha then
            labelFont:SetAlpha(0)
        end
    end
end

local function ApplySecondaryStatLabel(row, label)
    local replacement = GetSecondaryStatLabel(label)

    if not replacement then
        ReleaseStatLabelOverride(row)
        return
    end

    ApplyStatLabelOverride(row, replacement, FindRowLabelFont(row))
end

local function FindValueFont(row)
    if not row then
        return nil
    end

    local candidates = {
        row.Value,
        row.value,
        row.StatValue,
        row.ValueText,
        row.Label2,
    }

    for _, fontString in ipairs(candidates) do
        if fontString
            and not IsStatTargetRegion(fontString)
            and type(fontString.GetObjectType) == "function"
            and fontString:GetObjectType() == "FontString" then
            return fontString
        end
    end

    if type(row.GetRegions) == "function" then
        local best
        local bestLeft = -math.huge

        for index = 1, select("#", row:GetRegions()) do
            local region = select(index, row:GetRegions())

            if region
                and not IsStatTargetRegion(region)
                and type(region.GetObjectType) == "function"
                and region:GetObjectType() == "FontString" then
                local text = region.GetText and region:GetText()
                local left = region.GetLeft and region:GetLeft()

                if text and left and left > bestLeft and not GetStatKeyFromLabel(text) then
                    best = region
                    bestLeft = left
                end
            end
        end

        return best
    end

    return nil
end

local function RestoreRow(row)
    if not row then
        return
    end

    RestoreStatLabelOverride(row)

    if row.ZTStatTargetOverlay then
        row.ZTStatTargetOverlay:SetText("")
        row.ZTStatTargetOverlay:Hide()
    end

    if row.ZTStatTargetDeltaText then
        row.ZTStatTargetDeltaText:SetText("")
        row.ZTStatTargetDeltaText:Hide()
    end

    if row.ZTStatTargetPercentText then
        row.ZTStatTargetPercentText:SetText("")
        row.ZTStatTargetPercentText:Hide()
    end

    if row.ZTStatTargetRawText then
        row.ZTStatTargetRawText:SetText("")
        row.ZTStatTargetRawText:Hide()
    end

    if row.ZTStatTargetTargetText then
        row.ZTStatTargetTargetText:SetText("")
        row.ZTStatTargetTargetText:Hide()
    end

    local valueFont = FindValueFont(row)

    if valueFont and row.ZTStatTargetDefaultText then
        valueFont:SetText(row.ZTStatTargetDefaultText)
    end

    if valueFont and row.ZTStatTargetOriginalValueWidth then
        valueFont:SetWidth(row.ZTStatTargetOriginalValueWidth)
    end

    row.ZTStatTargetRenderedText = nil
end

local function ClearRowTracking(row, restoreNativeText)
    if not row then
        return
    end

    if restoreNativeText then
        RestoreRow(row)
    else
        if row.ZTStatTargetOverlay then
            row.ZTStatTargetOverlay:SetText("")
            row.ZTStatTargetOverlay:Hide()
        end

        if row.ZTStatTargetDeltaText then
            row.ZTStatTargetDeltaText:SetText("")
            row.ZTStatTargetDeltaText:Hide()
        end

        if row.ZTStatTargetPercentText then
            row.ZTStatTargetPercentText:SetText("")
            row.ZTStatTargetPercentText:Hide()
        end

        if row.ZTStatTargetRawText then
            row.ZTStatTargetRawText:SetText("")
            row.ZTStatTargetRawText:Hide()
        end

        if row.ZTStatTargetTargetText then
            row.ZTStatTargetTargetText:SetText("")
            row.ZTStatTargetTargetText:Hide()
        end

    end

    row.ZTStatTargetKey = nil
    row.ZTStatTargetDefaultText = nil
    row.ZTStatTargetRenderedText = nil
    trackedRows[row] = nil
end

local function HideAllRows()
    local rows = {}

    for row in pairs(trackedRows) do
        rows[#rows + 1] = row
    end

    for _, row in ipairs(rows) do
        ClearRowTracking(row, true)
    end
end

local function FormatRating(value)
    value = math.floor((value or 0) + 0.5)

    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(value)
    end

    return tostring(value)
end

local function RoundRating(value)
    return math.floor((value or 0) + 0.5)
end

local function FormatDelta(current, target)
    local diff = RoundRating(current) - RoundRating(target)
    local color = diff >= 0 and "ff40ff60" or "ffff5050"

    if diff == 0 then
        return string.format("|c%s+0|r", color), diff
    end

    local sign = diff > 0 and "+" or "-"
    return string.format("|c%s%s%d|r", color, sign, math.abs(diff)), diff
end

local function BuildOverlayText(statKey, defaultText)
    local ok, percent, raw, targetText, delta = pcall(function()
        local snapshot = GetSnapshot()
        local targets = snapshot and snapshot.targets
        local target = targets and SafeNumber(targets[statKey])

        if not target or target <= 0 then
            return nil
        end

        local current = GetRating(statKey)

        if not current then
            return nil
        end

        local delta = FormatDelta(current, target)
        local percent = defaultText or FormatDefaultPercent(statKey) or ""
        local raw = string.format("|cffb8b8b8%s|r", FormatRating(current))
        local targetText = string.format("|cffb8b8b8%s|r", FormatRating(target))

        return percent, raw, targetText, delta
    end)

    if ok then
        return percent, raw, targetText, delta
    end

    return nil
end

local function CreateColumnText(row, width)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text.ZTStatTargetRegion = true
    text:SetJustifyH("RIGHT")
    text:SetWidth(width)
    text:SetTextColor(1, 1, 1, 1)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    return text
end

local function FindLabelFont(row, statKey)
    if not row then
        return nil
    end

    local candidates = {
        row.Label,
        row.label,
        row.Name,
        row.name,
        row.Text,
        row.text,
    }

    for _, fontString in ipairs(candidates) do
        if fontString
            and not IsStatTargetRegion(fontString)
            and type(fontString.GetObjectType) == "function"
            and fontString:GetObjectType() == "FontString"
            and GetStatKeyFromLabel(fontString:GetText()) == statKey then
            return fontString
        end
    end

    if type(row.GetRegions) == "function" then
        for index = 1, select("#", row:GetRegions()) do
            local region = select(index, row:GetRegions())

            if region
                and not IsStatTargetRegion(region)
                and type(region.GetObjectType) == "function"
                and region:GetObjectType() == "FontString"
                and GetStatKeyFromLabel(region:GetText()) == statKey then
                return region
            end
        end
    end

    return nil
end

local function EnsureOverlayColumns(row)
    if row.ZTStatTargetPercentText
        and row.ZTStatTargetRawText
        and row.ZTStatTargetTargetText
        and row.ZTStatTargetDeltaText then
        return row.ZTStatTargetPercentText,
            row.ZTStatTargetRawText,
            row.ZTStatTargetTargetText,
            row.ZTStatTargetDeltaText
    end

    if InCombatLockdown and InCombatLockdown() then
        return nil
    end

    row.ZTStatTargetPercentText = row.ZTStatTargetPercentText or CreateColumnText(row, PERCENT_COLUMN_WIDTH)
    row.ZTStatTargetDeltaText = row.ZTStatTargetDeltaText or CreateColumnText(row, DELTA_COLUMN_WIDTH)
    row.ZTStatTargetRawText = row.ZTStatTargetRawText or CreateColumnText(row, RAW_COLUMN_WIDTH)
    row.ZTStatTargetTargetText = row.ZTStatTargetTargetText or CreateColumnText(row, TARGET_COLUMN_WIDTH)

    return row.ZTStatTargetPercentText,
        row.ZTStatTargetRawText,
        row.ZTStatTargetTargetText,
        row.ZTStatTargetDeltaText
end

local function SetRowValueText(row, statKey, defaultText)
    if not row or not statKey then
        return false
    end

    local valueFont = FindValueFont(row)

    if not valueFont then
        return false
    end

    row.ZTStatTargetDefaultText = FormatDefaultPercent(statKey) or ""

    if not IsEnabled() then
        RestoreRow(row)
        return false
    end

    local percentText, rawText, targetText, deltaText = BuildOverlayText(statKey, row.ZTStatTargetDefaultText)

    if not percentText or not rawText or not targetText or not deltaText then
        RestoreRow(row)
        return false
    end

    local percentColumn, rawColumn, targetColumn, deltaColumn = EnsureOverlayColumns(row)

    if not percentColumn or not rawColumn or not targetColumn or not deltaColumn then
        return false
    end

    if not row.ZTStatTargetOriginalValueWidth and valueFont.GetWidth then
        row.ZTStatTargetOriginalValueWidth = valueFont:GetWidth()
    end

    local labelFont = FindLabelFont(row, statKey) or row.ZTStatTargetLabelFont or FindRowLabelFont(row)
    ApplyStatLabelOverride(row, SHORT_STAT_LABELS[statKey] or STAT_LABELS[statKey], labelFont)

    if valueFont.SetText then
        valueFont:SetText("")
    end

    percentColumn:ClearAllPoints()
    deltaColumn:ClearAllPoints()
    rawColumn:ClearAllPoints()
    targetColumn:ClearAllPoints()

    deltaColumn:SetPoint("RIGHT", row, "RIGHT", -STAT_RIGHT_PADDING, 0)

    targetColumn:SetPoint("RIGHT", deltaColumn, "LEFT", -STAT_COLUMN_GAP, 0)
    rawColumn:SetPoint("RIGHT", targetColumn, "LEFT", -STAT_COLUMN_GAP, 0)
    percentColumn:SetPoint("RIGHT", rawColumn, "LEFT", -STAT_COLUMN_GAP, 0)

    percentColumn:SetText(percentText)
    percentColumn:Show()
    deltaColumn:SetText(deltaText)
    rawColumn:SetText(rawText)
    targetColumn:SetText(targetText)
    deltaColumn:Show()
    rawColumn:Show()
    targetColumn:Show()
    row.ZTStatTargetRenderedText = percentText .. " " .. rawText .. " " .. targetText .. " " .. deltaText

    return true
end

local function UpdateStatRow(row)
    if not row or not row.ZTStatTargetKey then
        return false
    end

    if not IsEnabled() then
        RestoreRow(row)
        return false
    end

    return SetRowValueText(row, row.ZTStatTargetKey)
end

local function ShowFallbackRows()
    if not IsEnabled() then
        HideFallbackRows()
        return
    end

    local parent = GetFallbackParent()

    if not parent or (type(parent.IsShown) == "function" and not parent:IsShown()) then
        HideFallbackRows()
        return
    end

    local yOffsets = {
        crit = -258,
        haste = -280,
        mastery = -302,
        versatility = -324,
    }

    for _, statKey in ipairs(STAT_ORDER) do
        local text = EnsureFallbackText(statKey)
        local percent, raw, target, delta = BuildOverlayText(statKey)

        if text and percent and raw and target and delta then
            text:ClearAllPoints()
            text:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -58, yOffsets[statKey] or -258)
            text:SetText(percent .. " " .. raw .. " " .. target .. " " .. delta)
            text:Show()
        elseif text then
            text:SetText("")
            text:Hide()
        end
    end
end

local function GetCharacterSourceDropdownParent()
    return _G.CharacterFrame or _G.PaperDollFrame or _G.CharacterStatsPane or _G.CharacterFrameInsetRight
end

local function AnchorCharacterSourceDropdown(control, parent)
    if not control or not parent then
        return
    end

    control:ClearAllPoints()

    if parent == _G.CharacterFrame then
        control:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", -6, -2)
    else
        control:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)
    end
end

local function PositionSourceDropdownMenu(control)
    if not control or not control.menu or not control.button then
        return
    end

    control.menu:ClearAllPoints()

    local screenBottom = 0
    local buttonBottom = control.button.GetBottom and control.button:GetBottom()
    local menuHeight = control.menu.GetHeight and control.menu:GetHeight() or 0
    local openDown = true

    if buttonBottom and (buttonBottom - menuHeight - 4) < screenBottom then
        openDown = false
    end

    if openDown then
        control.menu:SetPoint("TOPLEFT", control.button, "BOTTOMLEFT", 0, -2)
        control.button.arrow:SetText("v")
    else
        control.menu:SetPoint("BOTTOMLEFT", control.button, "TOPLEFT", 0, 2)
        control.button.arrow:SetText("^")
    end
end

local function RefreshCharacterSourceDropdown()
    if not sourceDropdown then
        return
    end

    local shouldShow = IsEnabled()
    local parent = GetCharacterSourceDropdownParent()

    if parent and type(parent.IsShown) == "function" and not parent:IsShown() then
        shouldShow = false
    end

    if not shouldShow then
        if sourceDropdown.menu then
            sourceDropdown.menu:Hide()
        end

        sourceDropdown:Hide()
        return
    end

    sourceDropdown.button.text:SetText(GetContextButtonText())

    for index, option in ipairs(SOURCE_OPTIONS) do
        local row = sourceDropdown.rows and sourceDropdown.rows[index]

        if row and row.check then
            row.check:SetShown(ns:GetStatTargetContext() == option.value)
        end
    end

    sourceDropdown:Show()
end

local function EnsureCharacterSourceDropdown()
    if InCombatLockdown and InCombatLockdown() then
        return nil
    end

    local parent = GetCharacterSourceDropdownParent()

    if not parent then
        return nil
    end

    if sourceDropdown and sourceDropdown:GetParent() ~= parent then
        sourceDropdown:SetParent(parent)
        AnchorCharacterSourceDropdown(sourceDropdown, parent)
    end

    if sourceDropdown then
        RefreshCharacterSourceDropdown()
        return sourceDropdown
    end

    local control = CreateFrame("Frame", nil, parent)
    control:SetSize(112, 22)
    AnchorCharacterSourceDropdown(control, parent)
    control:SetFrameStrata("HIGH")
    control:SetFrameLevel((parent:GetFrameLevel() or 1) + 20)

    control.label = control:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    control.label:SetPoint("LEFT", control, "LEFT", 0, 0)
    control.label:SetText("Goals")

    control.button = CreateFrame("Button", nil, control, "BackdropTemplate")
    control.button:SetPoint("LEFT", control.label, "RIGHT", 6, 0)
    control.button:SetSize(58, 20)
    control.button:RegisterForClicks("LeftButtonUp")
    control.button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    control.button:SetBackdropColor(0.02, 0.018, 0.014, 0.92)
    control.button:SetBackdropBorderColor(0.85, 0.68, 0.25, 0.7)

    control.button.text = control.button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    control.button.text:SetPoint("LEFT", control.button, "LEFT", 7, 0)
    control.button.text:SetPoint("RIGHT", control.button, "RIGHT", -16, 0)
    control.button.text:SetJustifyH("LEFT")

    control.button.arrow = control.button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    control.button.arrow:SetPoint("RIGHT", control.button, "RIGHT", -6, 0)
    control.button.arrow:SetText("v")

    control.menu = CreateFrame("Frame", nil, control, "BackdropTemplate")
    control.menu:SetSize(58, (#SOURCE_OPTIONS * 20) + 8)
    control.menu:SetFrameStrata("DIALOG")
    control.menu:SetToplevel(true)
    control.menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    control.menu:SetBackdropColor(0.015, 0.014, 0.012, 1)
    control.menu:SetBackdropBorderColor(0.85, 0.68, 0.25, 0.75)
    control.menu:Hide()

    control.rows = {}

    local function HideMenu()
        control.menu:Hide()
        control.button.arrow:SetText("v")
    end

    for index, option in ipairs(SOURCE_OPTIONS) do
        local row = CreateFrame("Button", nil, control.menu)
        row:SetPoint("TOPLEFT", control.menu, "TOPLEFT", 4, -4 - ((index - 1) * 20))
        row:SetSize(50, 20)
        row:RegisterForClicks("LeftButtonUp")

        row.check = row:CreateTexture(nil, "OVERLAY")
        row.check:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.check:SetSize(12, 12)
        row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        row.check:SetVertexColor(1, 0.86, 0.12, 1)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 16, 0)
        row.text:SetText(option.text)

        row:SetScript("OnClick", function()
            ns:SetStatTargetContext(option.value)
            RefreshCharacterSourceDropdown()
            HideMenu()
        end)

        control.rows[index] = row
    end

    control.button:SetScript("OnClick", function()
        if control.menu:IsShown() then
            HideMenu()
        else
            RefreshCharacterSourceDropdown()
            PositionSourceDropdownMenu(control)
            control.menu:Show()
        end
    end)

    control.button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Stat goal source")
        GameTooltip:AddLine("Changes the target set used by ZoidsTools stat comparisons.", 1, 1, 1, true)
        GameTooltip:Show()
    end)

    control.button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    sourceDropdown = control
    RefreshCharacterSourceDropdown()

    return control
end

local function UpdateTrackedRows()
    if not IsEnabled() then
        HideAllRows()
        HideFallbackRows()
        RefreshCharacterSourceDropdown()
        return
    end

    EnsureCharacterSourceDropdown()

    local rendered = 0

    for row in pairs(trackedRows) do
        if UpdateStatRow(row) then
            rendered = rendered + 1
        end
    end

    if rendered == 0 then
        ShowFallbackRows()
    else
        HideFallbackRows()
    end
end

local function DetectStatKey(row)
    if not row then
        return nil
    end

    if row.statKey and FRAME_STAT_KEYS[row.statKey] then
        return FRAME_STAT_KEYS[row.statKey]
    end

    if type(row.GetRegions) ~= "function" then
        return nil
    end

    local candidates = {
        row.Label,
        row.label,
        row.Name,
        row.name,
        row.Text,
        row.text,
    }

    for _, fontString in ipairs(candidates) do
        if fontString
            and not IsStatTargetRegion(fontString)
            and type(fontString.GetObjectType) == "function"
            and fontString:GetObjectType() == "FontString" then
            local key = GetStatKeyFromLabel(fontString:GetText())

            if key then
                return key
            end
        end
    end

    for index = 1, select("#", row:GetRegions()) do
        local region = select(index, row:GetRegions())

        if region
            and not IsStatTargetRegion(region)
            and type(region.GetObjectType) == "function"
            and region:GetObjectType() == "FontString" then
            local key = GetStatKeyFromLabel(region:GetText())

            if key then
                return key
            end
        end
    end

    return nil
end

local function TrackStatRow(row)
    local statKey = DetectStatKey(row)

    if not statKey then
        ClearRowTracking(row, false)

        local labelFont = FindRowLabelFont(row)
        local label = labelFont and labelFont:GetText()

        if GetSecondaryStatLabel(label) then
            ApplySecondaryStatLabel(row, label)
        else
            ReleaseStatLabelOverride(row)
        end

        return
    end

    row.ZTStatTargetKey = statKey
    row.ZTStatTargetDefaultText = FormatDefaultPercent(statKey) or ""
    trackedRows[row] = true
    UpdateStatRow(row)
end

local function ScanFrameChildren(frame, depth)
    if not frame or depth > 8 or type(frame.GetChildren) ~= "function" then
        return
    end

    if type(frame.IsShown) == "function" and not frame:IsShown() then
        return
    end

    TrackStatRow(frame)

    for index = 1, select("#", frame:GetChildren()) do
        ScanFrameChildren(select(index, frame:GetChildren()), depth + 1)
    end
end

local function ScanCharacterStatsPane()
    local pane = _G.CharacterStatsPane

    if pane and (type(pane.IsShown) ~= "function" or pane:IsShown()) then
        local pool = pane.statsFramePool

        if pool and type(pool.EnumerateActive) == "function" then
            for row in pool:EnumerateActive() do
                TrackStatRow(row)
            end
        end

        ScanFrameChildren(pane, 0)
        return
    end

    ScanFrameChildren(_G.CharacterFrameInsetRight, 0)
    ScanFrameChildren(_G.PaperDollFrame, 0)
end

local function QueueRefresh(delay)
    if pendingRefresh then
        return
    end

    pendingRefresh = true

    local function Run()
        pendingRefresh = false

        ScanCharacterStatsPane()
        UpdateTrackedRows()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.08, Run)
    else
        Run()
    end
end

local function OnSetLabelAndText(row, label, text)
    local statKey = GetStatKeyFromLabel(label)

    if not statKey then
        ClearRowTracking(row, false)
        ApplySecondaryStatLabel(row, label)
        return
    end

    row.ZTStatTargetKey = statKey
    row.ZTStatTargetDefaultText = FormatDefaultPercent(statKey) or ""
    trackedRows[row] = true

    SetRowValueText(row, statKey, row.ZTStatTargetDefaultText)
end

local function OnStatSetter(statKey, row, unit)
    if unit and unit ~= "player" then
        return
    end

    if not row then
        return
    end

    row.ZTStatTargetKey = statKey
    row.ZTStatTargetDefaultText = FormatDefaultPercent(statKey)
    trackedRows[row] = true

    SetRowValueText(row, statKey, row.ZTStatTargetDefaultText)
end

local function HookGlobalFunction(name, callback)
    if not hooksecurefunc or type(_G[name]) ~= "function" then
        return false
    end

    if hookedFunctions[name] == _G[name] then
        return true
    end

    hooksecurefunc(name, callback)
    hookedFunctions[name] = _G[name]

    return true
end

local function InstallHook()
    local installed = false

    installed = HookGlobalFunction("PaperDollFrame_SetLabelAndText", OnSetLabelAndText) or installed
    installed = HookGlobalFunction("PaperDollFrame_SetCritChance", function(row, unit)
        OnStatSetter("crit", row, unit)
    end) or installed
    installed = HookGlobalFunction("PaperDollFrame_SetHaste", function(row, unit)
        OnStatSetter("haste", row, unit)
    end) or installed
    installed = HookGlobalFunction("PaperDollFrame_SetMastery", function(row, unit)
        OnStatSetter("mastery", row, unit)
    end) or installed
    installed = HookGlobalFunction("PaperDollFrame_SetVersatility", function(row, unit)
        OnStatSetter("versatility", row, unit)
    end) or installed

    if installed then
        QueueRefresh(0.05)
    end

    return installed
end

local function InstallShowHooks()
    if showHooksInstalled then
        return
    end

    local installed = false

    if CharacterFrame and type(CharacterFrame.HookScript) == "function" then
        CharacterFrame:HookScript("OnShow", function()
            QueueRefresh(0.12)
        end)
        installed = true
    end

    if PaperDollFrame and type(PaperDollFrame.HookScript) == "function" then
        PaperDollFrame:HookScript("OnShow", function()
            QueueRefresh(0.12)
        end)
        installed = true
    end

    if CharacterStatsPane and type(CharacterStatsPane.HookScript) == "function" then
        CharacterStatsPane:HookScript("OnShow", function()
            QueueRefresh(0.12)
        end)
        installed = true
    end

    showHooksInstalled = installed == true
end

function ns:SetStatTargetContext(value)
    local db = EnsureDB()

    if not db then
        return
    end

    if value ~= "raid" and value ~= "pvp" then
        value = "mythicplus"
    end

    db.statTargetContext = value
    RefreshCharacterSourceDropdown()
    ns:RefreshStatTargets()
end

function ns:GetStatTargetContext()
    local db = EnsureDB()
    return db and db.statTargetContext or "mythicplus"
end

function ns:GetStatTargetStatusText()
    if not IsEnabled() then
        return "Recommended stat comparisons are disabled."
    end

    local snapshot, classToken, specKey, context = GetSnapshot()

    if snapshot then
        local readable = 0
        local source = snapshot.source or (context == "PvP" and "Murlok" or "Archon")

        for _, statKey in ipairs(STAT_ORDER) do
            if GetRating(statKey) ~= nil then
                readable = readable + 1
            end
        end

        if readable == 0 then
            return string.format("Found %s stat goals for %s %s, but your live ratings are not readable right now.", context or "selected", tostring(specKey or "current"), tostring(classToken or "class"))
        end

        return string.format("Comparing your stats to %s %s goals for %s %s.", tostring(source), context or "selected", tostring(specKey or "current"), tostring(classToken or "class"))
    end

    return "No recommended stat goals found for your current class, spec, and context."
end

function ns:RefreshStatTargets()
    QueueRefresh(0.02)
end

function ns:InitializeStatTargets()
    EnsureDB()
    InstallHook()
    InstallShowHooks()

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("ADDON_LOADED")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("UNIT_STATS")
        eventFrame:RegisterEvent("UNIT_AURA")
        eventFrame:SetScript("OnEvent", function(_, event, unitOrAddon)
            if event == "ADDON_LOADED" then
                InstallHook()
                InstallShowHooks()
                QueueRefresh(0.12)
                return
            end

            if event == "UNIT_STATS" and unitOrAddon ~= "player" then
                return
            end

            if event == "UNIT_AURA" and unitOrAddon ~= "player" then
                return
            end

            if not showHooksInstalled then
                InstallShowHooks()
            end

            InstallHook()

            QueueRefresh(event == "PLAYER_EQUIPMENT_CHANGED" and 0.18 or 0.08)
        end)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            InstallHook()
            QueueRefresh(0.02)
        end)
    end
end
