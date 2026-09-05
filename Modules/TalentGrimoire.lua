local _, ns = ...

local panel
local eventFrame
local applyFrame
local QueueRefresh
local refreshQueued = false
local pendingCombatRefresh = false
local talentDataPruned = false
local talentDataCompacted = false
local talentFrameHooks = {}
local talentCheckRefreshQueued = false
local checkedTalentButtons = {}

local PANEL_HEIGHT = 52
local PANEL_WIDTH = 700
local PANEL_ANCHOR_X = 8
local PANEL_ANCHOR_Y = 8
local CONTROL_GAP = 6
local PANEL_FRAME_LEVEL_OFFSET = 10
local CONTROL_FRAME_LEVEL_OFFSET = 2
local ROTATION_PANEL_WIDTH = 430
local ROTATION_PANEL_HEIGHT = 420
local ROTATION_ROW_MIN_HEIGHT = 38
local SPEC_BUTTON_SIZE = 38
local SPEC_BUTTON_GAP = 8
local SPEC_BUTTON_OFFSET_X = 40
local MAX_CLASS_SPECIALIZATIONS = 4
local SOLID_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local ZOIDS_LOADOUT_NAME = "ZoidsTools"
local DUNGEON_PROMPT_DIALOG = "ZOIDSTOOLS_TALENT_GRIMOIRE_DUNGEON_PROMPT"
local BIT_WIDTH_HEADER_VERSION = 8
local BIT_WIDTH_SPEC_ID = 16
local BIT_WIDTH_RANKS_PURCHASED = 6
local PENDING_APPLY_WATCHDOG_SECS = 30
local pendingApply
local pendingApplySeq = 0
local applyToken = 0
local SecureTalentCall
local PrintTalentMessage
local RollbackTalentConfig
local ConfigHasStagedChanges
local talentApplyDiagnostics = {
    enabled = false,
    lines = {},
    attempt = 0,
}
local TALENT_DIAGNOSTIC_MAX_LINES = 240
local TALENT_DIAGNOSTIC_ROW_DELAY = 0.65
local dungeonPromptQueued = false
local lastDungeonZoneSignature
local lastDungeonPromptSignature
local ACTIVE_TARGET_TEXT_COLOR = "ff8fdc8f"
local PENDING_TARGET_TEXT_COLOR = "ffffd36a"
local ALTERNATE_SPEC_TARGET_PREFIX = "__alternate_spec__:"
local ACTIVE_TARGET_TEXT_RGBA = { 0.56, 0.86, 0.56, 1 }
local PENDING_TARGET_TEXT_RGBA = { 1, 0.83, 0.42, 1 }
local DEFAULT_DROPDOWN_TEXT_RGBA = { 1, 1, 1, 1 }
local TALENT_MATCH_COLOR = { 0.08, 1, 0.24, 1 }
local TALENT_PENDING_COLOR = { 1, 0.82, 0.12, 1 }

local function ResetTalentApplyDiagnosticLog()
    talentApplyDiagnostics.lines = {}
    talentApplyDiagnostics.attempt = talentApplyDiagnostics.attempt + 1
end

local function LogTalentApplyDiagnostic(message, ...)
    if not talentApplyDiagnostics.enabled then
        return
    end

    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, tostring(message), ...)
        message = ok and formatted or tostring(message)
    end

    local elapsed = GetTime and GetTime() or 0
    local lines = talentApplyDiagnostics.lines
    lines[#lines + 1] = string.format("[%0.3f] %s", elapsed, tostring(message))

    if #lines > TALENT_DIAGNOSTIC_MAX_LINES then
        table.remove(lines, 1)
    end
end


function ns:SetTalentApplyDiagnostics(enabled)
    talentApplyDiagnostics.enabled = enabled == true

    if talentApplyDiagnostics.enabled then
        ResetTalentApplyDiagnosticLog()
        LogTalentApplyDiagnostic("Diagnostic mode enabled; the next talent application will be slowed between rows.")
        PrintTalentMessage("Talent apply diagnostics enabled. Apply the build, then run /zt talentdiag report.")
    else
        PrintTalentMessage("Talent apply diagnostics disabled.")
    end
end

function ns:ResetTalentApplyDiagnostics()
    ResetTalentApplyDiagnosticLog()
    PrintTalentMessage("Talent apply diagnostic log cleared.")
end

function ns:ReportTalentApplyDiagnostics()
    local lines = talentApplyDiagnostics.lines

    if #lines == 0 then
        PrintTalentMessage("No talent apply diagnostic information has been captured yet.")
        return
    end

    PrintTalentMessage(string.format("Talent apply diagnostic report: %d line(s).", #lines))

    local startIndex = math.max(1, #lines - 79)

    if startIndex > 1 then
        PrintTalentMessage(lines[1])
        PrintTalentMessage(string.format("... %d earlier diagnostic line(s) omitted ...", startIndex - 2))
    end

    for index = startIndex, #lines do
        PrintTalentMessage(lines[index])
    end
end

local CONTENT_OPTIONS = {
    { value = "mythicplus", text = "Mythic+" },
    { value = "raid", text = "Raid" },
    { value = "pvp", text = "PvP" },
}

local DEFAULT_PROVIDER = "archon"
local PROVIDER_SORT_ORDER = {
    archon = 10,
    icyveins = 20,
    wowhead = 30,
    murlok = 40,
}

local MODE_OPTIONS_BY_CONTENT = {
    mythicplus = {
        { value = "lowkey", text = "Low Keys" },
        { value = "highkey", text = "High Keys" },
    },
    raid = {
        { value = "normal", text = "Normal" },
        { value = "heroic", text = "Heroic" },
        { value = "mythic", text = "Mythic" },
    },
    pvp = {
        { value = "popular", text = "Popular" },
    },
}

local DEFAULT_MODE_BY_CONTENT = {
    mythicplus = "highkey",
    raid = "mythic",
    pvp = "popular",
}

local DEFAULT_TARGET_BY_CONTENT = {
    mythicplus = "all-dungeons",
    raid = "all-bosses",
    pvp = "icy-veins",
}

local PVP_MODE_SORT_ORDER = {
    ["3v3"] = 10,
    ["2v2"] = 20,
    solo = 30,
    blitz = 40,
    battleground = 40,
    rbg = 50,
}

local TARGET_SORT_ORDER = {
    ["all-dungeons"] = 0,
    ["all-bosses"] = 0,
    ["icy-veins"] = 0,
    solo = 10,
    ["2v2"] = 20,
    ["3v3"] = 30,
    rbg = 40,
}

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

local SPEC_LABELS = {
    ["beast-mastery"] = "Beast Mastery",
}

local function TitleCase(value)
    value = tostring(value or "")
    value = value:gsub("-", " ")
    return (value:gsub("(%a)([%w_']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end))
end

local function NormalizeSpecName(value)
    value = string.lower(tostring(value or ""))
    value = value:gsub("&", "and")
    value = value:gsub("[^%w]+", "-")
    value = value:gsub("^%-+", "")
    value = value:gsub("%-+$", "")
    return value
end

local function GetOptionText(options, value)
    for _, option in ipairs(options or {}) do
        if option.value == value then
            return option.text or option.label or tostring(value or "")
        end
    end

    return tostring(value or "")
end

local function ColorizeText(text, color)
    if not color or color == "" then
        return tostring(text or "")
    end

    return "|c" .. color .. tostring(text or "") .. "|r"
end

local function GetOptionDisplayText(options, value)
    for _, option in ipairs(options or {}) do
        if option.value == value then
            return option.displayText or option.text or option.label or tostring(value or "")
        end
    end

    return tostring(value or "")
end

local function GetOptionTextColor(options, value)
    for _, option in ipairs(options or {}) do
        if option.value == value then
            return option.textColor
        end
    end

    return nil
end

local function SetFontStringColor(fontString, color)
    if not fontString or not fontString.SetTextColor then
        return false
    end

    color = color or DEFAULT_DROPDOWN_TEXT_RGBA
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    return true
end

local function SetDropdownTextColor(dropdown, color)
    local applied = false

    if dropdown.GetFontString then
        applied = SetFontStringColor(dropdown:GetFontString(), color) or applied
    end

    for _, key in ipairs({ "Text", "TextLeft", "TextMiddle", "text", "fontString", "FontString" }) do
        applied = SetFontStringColor(dropdown[key], color) or applied
    end

    if dropdown.GetRegions then
        for index = 1, select("#", dropdown:GetRegions()) do
            local region = select(index, dropdown:GetRegions())

            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                applied = SetFontStringColor(region, color) or applied
            end
        end
    end

    return applied
end

local function SetMenuDescriptionTextColor(description, color)
    if not description or not color then
        return
    end

    if description.SetTextColor then
        pcall(description.SetTextColor, description, color[1], color[2], color[3], color[4] or 1)
    end

    if description.SetColor then
        pcall(description.SetColor, description, color[1], color[2], color[3], color[4] or 1)
    end
end

local function NormalizeContentType(contentType)
    if contentType == "raid" or contentType == "pvp" then
        return contentType
    end

    return "mythicplus"
end

local function GetContentLabel(contentType)
    return GetOptionText(CONTENT_OPTIONS, NormalizeContentType(contentType))
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.talentGrimoire = ns.db.talentGrimoire or {}

    local db = ns.db.talentGrimoire

    if db.enabled == nil then
        db.enabled = true
    end

    db.contentType = NormalizeContentType(db.contentType)
    db.provider = db.provider or DEFAULT_PROVIDER
    db.rotationWindow = db.rotationWindow or {}

    db.mythicPlusTarget = db.mythicPlusTarget or DEFAULT_TARGET_BY_CONTENT.mythicplus
    db.raidTarget = db.raidTarget or DEFAULT_TARGET_BY_CONTENT.raid
    db.pvpTarget = db.pvpTarget or DEFAULT_TARGET_BY_CONTENT.pvp
    db.mythicPlusMode = db.mythicPlusMode or (db.mode == "lowkey" and "lowkey" or "highkey")
    db.raidMode = db.raidMode or ((db.mode == "normal" or db.mode == "heroic" or db.mode == "mythic") and db.mode or "mythic")
    db.pvpMode = db.pvpMode or "popular"

    if db.contentType == "raid" then
        db.mode = db.raidMode
    elseif db.contentType == "pvp" then
        db.mode = db.pvpMode
    else
        db.mode = db.mythicPlusMode
    end

    return db
end

local function GetRoot()
    return ns.TalentGrimoireData
end

local function PruneTalentGrimoireToPlayerClass()
    if talentDataPruned then
        return
    end

    if type(UnitClass) ~= "function" then
        return
    end

    local classOK, _, classToken = pcall(UnitClass, "player")
    if not classOK
        or (issecretvalue and issecretvalue(classToken))
        or type(classToken) ~= "string"
        or classToken == ""
    then
        return
    end

    local root = GetRoot()
    if type(root) ~= "table" then
        return
    end

    -- Generated talent data is split into per-class loader functions. This
    -- avoids constructing thousands of tables for classes the current
    -- character cannot use. Older generated files still follow the pruning
    -- path below, so an updater and addon can be rolled out independently.
    if type(root.dataLoaders) == "table" or type(root.rotationLoaders) == "table" then
        local dataLoader = type(root.dataLoaders) == "table" and root.dataLoaders[classToken] or nil
        local rotationLoader = type(root.rotationLoaders) == "table" and root.rotationLoaders[classToken] or nil
        root.data = {}
        root.rotations = {}

        if type(dataLoader) == "function" then
            local ok, classData = pcall(dataLoader)
            if ok and type(classData) == "table" then
                root.data[classToken] = classData
            elseif ns.Print then
                ns:Print("Talent build recommendations for " .. tostring(classToken) .. " could not be loaded.")
            end
        end
        if type(rotationLoader) == "function" then
            local ok, classRotations = pcall(rotationLoader)
            if ok and type(classRotations) == "table" then
                root.rotations[classToken] = classRotations
            elseif ns.Print then
                ns:Print("Talent rotation references for " .. tostring(classToken) .. " could not be loaded.")
            end
        end

        root.dataLoaders = nil
        root.rotationLoaders = nil
    elseif type(root.classLoaders) == "table" then
        local loader = root.classLoaders[classToken]
        root.data = {}
        root.rotations = {}

        if type(loader) == "function" then
            local ok, classData, classRotations = pcall(loader)
            if ok then
                if type(classData) == "table" then
                    root.data[classToken] = classData
                end
                if type(classRotations) == "table" then
                    root.rotations[classToken] = classRotations
                end
            elseif ns.Print then
                ns:Print("Talent recommendations for " .. tostring(classToken) .. " could not be loaded.")
            end
        end

        root.classLoaders = nil
    end

    -- A character can only use talent builds and rotation references for its
    -- own class. Keep every specialization for that class, including alternate
    -- specialization PvP recommendations, and release the other class tables.
    for _, branch in ipairs({ root.data, root.rotations }) do
        if type(branch) == "table" then
            for candidateClass in pairs(branch) do
                if candidateClass ~= classToken then
                    branch[candidateClass] = nil
                end
            end
        end
    end

    talentDataPruned = true
end

local function BuildEntriesEquivalent(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end

    return left.importString == right.importString
        and left.title == right.title
        and left.modeLabel == right.modeLabel
        and left.keyRange == right.keyRange
        and left.rankRange == right.rankRange
        and left.difficulty == right.difficulty
        and left.source == right.source
end

local function CompactTalentGrimoireData()
    if talentDataCompacted then
        return
    end

    talentDataCompacted = true

    local root = GetRoot()
    local data = root and root.data

    if type(data) ~= "table" then
        return
    end

    for _, classData in pairs(data) do
        if type(classData) == "table" then
            for _, specData in pairs(classData) do
                if type(specData) == "table" then
                    for contentType, contentData in pairs(specData) do
                        if type(contentData) == "table" then
                            for _, targetData in pairs(contentData) do
                                local builds = type(targetData) == "table" and targetData.builds

                                if type(builds) == "table" then
                                    for _, entry in pairs(builds) do
                                        if type(entry) == "table" then
                                            entry.notes = nil

                                            if entry.importString and entry.importString ~= "" then
                                                entry.sourceUrl = nil
                                            end
                                        end
                                    end

                                    if contentType == "mythicplus" and BuildEntriesEquivalent(builds.popular, builds.highkey) then
                                        builds.popular = builds.highkey
                                    elseif contentType == "raid" and BuildEntriesEquivalent(builds.popular, builds.mythic) then
                                        builds.popular = builds.mythic
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if collectgarbage then
        pcall(collectgarbage, "collect")
    end
end

local function GetClassAndSpec()
    local _, classToken = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    local specKey = classToken and specIndex and SPEC_KEYS[classToken] and SPEC_KEYS[classToken][specIndex]
    local root = GetRoot()

    if classToken and specIndex and GetSpecializationInfo and root and root.data and root.data[classToken] then
        local _, specName = GetSpecializationInfo(specIndex)
        local nameKey = NormalizeSpecName(specName)

        if root.data[classToken][nameKey] then
            specKey = nameKey
        end
    end

    return classToken, specKey
end

local function GetCurrentRotationData(context)
    local classToken, specKey

    if type(context) == "table" and context.classToken and context.specKey then
        classToken = context.classToken
        specKey = context.specKey
    else
        classToken, specKey = GetClassAndSpec()
    end
    local root = GetRoot()
    local rotation = root
        and root.rotations
        and classToken
        and specKey
        and root.rotations[classToken]
        and root.rotations[classToken][specKey]

    if type(rotation) ~= "table" then
        return nil, classToken, specKey
    end

    local hasSections = type(rotation.sections) == "table" and #rotation.sections > 0
    if not hasSections and type(rotation.conditionalSections) == "table" and #rotation.conditionalSections > 0 then
        hasSections = true
    end
    if not hasSections and type(rotation.variants) == "table" then
        for _, variant in ipairs(rotation.variants) do
            if type(variant.sections) == "table" and #variant.sections > 0 then
                hasSections = true
                break
            end
        end
    end

    if not hasSections then
        return nil, classToken, specKey
    end

    return rotation, classToken, specKey
end

local function GetSpecLabel(specKey)
    return SPEC_LABELS[specKey] or TitleCase(specKey)
end

local function EncodeAlternateSpecTarget(specKey, targetKey)
    return ALTERNATE_SPEC_TARGET_PREFIX .. tostring(specKey or "") .. ":" .. tostring(targetKey or "")
end

local function DecodeAlternateSpecTarget(value)
    value = tostring(value or "")

    if value:sub(1, #ALTERNATE_SPEC_TARGET_PREFIX) ~= ALTERNATE_SPEC_TARGET_PREFIX then
        return nil, value
    end

    local remainder = value:sub(#ALTERNATE_SPEC_TARGET_PREFIX + 1)
    local separator = remainder:find(":", 1, true)

    if not separator then
        return nil, value
    end

    return remainder:sub(1, separator - 1), remainder:sub(separator + 1)
end

local function GetSpecIndexForKey(classToken, specKey)
    for specIndex, candidateKey in ipairs(SPEC_KEYS[classToken] or {}) do
        if candidateKey == specKey then
            return specIndex
        end
    end

    return nil
end

local function GetCurrentSpecData()
    local root = GetRoot()
    local classToken, specKey = GetClassAndSpec()

    return root
        and root.data
        and classToken
        and specKey
        and root.data[classToken]
        and root.data[classToken][specKey],
        classToken,
        specKey
end

local TargetHasProvider
local GetProviderOptions
local GetProviderKey
local GetProviderBuilds
local GetContentOptions

local function GetPvpModeSortValue(option)
    local value = string.lower(tostring(option and option.value or ""))
    local text = string.lower(tostring(option and option.text or ""))

    for key, order in pairs(PVP_MODE_SORT_ORDER) do
        if string.find(value, key, 1, true) or string.find(text, key, 1, true) then
            return order
        end
    end

    return 100
end

local function FormatPvpModeLabel(label)
    local text = tostring(label or "")

    text = text:gsub("^Best%s+", "")
    text = text:gsub("%s+Talents$", "")

    if text == "" then
        return tostring(label or "")
    end

    return text
end

local function GetFirstBuildKey(builds)
    local firstKey

    if type(builds) ~= "table" then
        return nil
    end

    for buildKey in pairs(builds) do
        if not firstKey or tostring(buildKey) < tostring(firstKey) then
            firstKey = buildKey
        end
    end

    return firstKey
end

local function GetPvpBuildsForTarget(targetKey)
    local specData = GetCurrentSpecData()
    local pvpData = specData and specData.pvp
    local targetData = pvpData and pvpData[targetKey or ""]

    if (not targetData or not TargetHasProvider(targetData, GetProviderKey())) and pvpData then
        for fallbackTargetKey, fallbackTargetData in pairs(pvpData) do
            if TargetHasProvider(fallbackTargetData, GetProviderKey()) then
                targetKey = fallbackTargetKey
                targetData = fallbackTargetData
                break
            end
        end
    end

    local builds = GetProviderBuilds(targetData, GetProviderKey())
    return builds, targetKey, targetData
end

local function GetBuildModeLabel(buildKey, entry)
    if type(entry) == "table" then
        if entry.modeLabel and entry.modeLabel ~= "" then
            return entry.modeLabel
        end

        -- Archon's temporary PTR feed has one combined key range. Older
        -- generated data stores its identical build under both lowkey and
        -- highkey, but the player-facing mode is simply PTR M+.
        if entry.difficulty == "PTR M+" then
            return "PTR M+"
        end

        if entry.title and entry.title ~= "" then
            return entry.title
        end
    end

    return TitleCase(buildKey)
end

local function GetModeOptions(contentType, targetKey)
    contentType = NormalizeContentType(contentType)

    if not targetKey then
        local db = ns.db and ns.db.talentGrimoire
        if contentType == "raid" then
            targetKey = db and db.raidTarget or DEFAULT_TARGET_BY_CONTENT.raid
        elseif contentType == "pvp" then
            targetKey = db and db.pvpTarget or DEFAULT_TARGET_BY_CONTENT.pvp
        else
            targetKey = db and db.mythicPlusTarget or DEFAULT_TARGET_BY_CONTENT.mythicplus
        end
    end

    local specData = GetCurrentSpecData()
    local targetData = specData and specData[contentType] and specData[contentType][targetKey]
    local builds = GetProviderBuilds(targetData, GetProviderKey())
    local dynamicOptions = {}

    if type(builds) == "table" then
        local collapseCombinedModes = contentType == "mythicplus"
            and BuildEntriesEquivalent(builds.lowkey, builds.highkey)
            and (
                builds.highkey.difficulty == "PTR M+"
                or builds.highkey.modeLabel == "PTR M+"
                or (
                    type(builds.highkey.modeLabel) == "string"
                    and builds.highkey.modeLabel ~= ""
                    and builds.highkey.modeLabel == builds.lowkey.modeLabel
                )
            )

        if collapseCombinedModes then
            dynamicOptions[#dynamicOptions + 1] = {
                value = "highkey",
                text = GetBuildModeLabel("highkey", builds.highkey),
            }
        end

        for buildKey, entry in pairs(builds) do
            if not collapseCombinedModes or (buildKey ~= "lowkey" and buildKey ~= "highkey") then
                dynamicOptions[#dynamicOptions + 1] = {
                    value = buildKey,
                    text = FormatPvpModeLabel(GetBuildModeLabel(buildKey, entry)),
                }
            end
        end
    end

    -- Keep a requested PvP bracket visible when the active specialization has no
    -- build for it but another specialization of the same class does. The final
    -- dropdown will identify which specialization can supply the build.
    if contentType == "pvp" then
        local root = GetRoot()
        local classToken = select(1, GetClassAndSpec())
        local _, actualTargetKey = DecodeAlternateSpecTarget(targetKey)
        local seenModes = {}

        for _, option in ipairs(dynamicOptions) do
            seenModes[option.value] = true
        end

        local classData = root and root.data and classToken and root.data[classToken]
        if type(classData) == "table" then
            for _, alternateSpecData in pairs(classData) do
                local alternateTargetData = type(alternateSpecData) == "table"
                    and alternateSpecData.pvp
                    and alternateSpecData.pvp[actualTargetKey]
                local alternateBuilds = GetProviderBuilds(alternateTargetData, GetProviderKey())

                if type(alternateBuilds) == "table" then
                    for buildKey, entry in pairs(alternateBuilds) do
                        if not seenModes[buildKey] then
                            seenModes[buildKey] = true
                            dynamicOptions[#dynamicOptions + 1] = {
                                value = buildKey,
                                text = FormatPvpModeLabel(GetBuildModeLabel(buildKey, entry)),
                            }
                        end
                    end
                end
            end
        end
    end

    if #dynamicOptions > 0 then
        table.sort(dynamicOptions, function(left, right)
            if contentType == "pvp" then
                local leftOrder = GetPvpModeSortValue(left)
                local rightOrder = GetPvpModeSortValue(right)
                if leftOrder ~= rightOrder then return leftOrder < rightOrder end
            end
            return tostring(left.text) < tostring(right.text)
        end)
        return dynamicOptions
    end

    if contentType == "pvp" then
        builds = GetPvpBuildsForTarget(targetKey)
        local options = {}

        if type(builds) == "table" then
            for buildKey, entry in pairs(builds) do
                local label = GetBuildModeLabel(buildKey, entry)

                options[#options + 1] = {
                    value = buildKey,
                    text = FormatPvpModeLabel(label),
                }
            end
        end

        table.sort(options, function(left, right)
            local leftOrder = GetPvpModeSortValue(left)
            local rightOrder = GetPvpModeSortValue(right)

            if leftOrder ~= rightOrder then
                return leftOrder < rightOrder
            end

            return tostring(left.text) < tostring(right.text)
        end)

        if #options > 0 then
            return options
        end
    end

    return MODE_OPTIONS_BY_CONTENT[contentType] or MODE_OPTIONS_BY_CONTENT.mythicplus
end

local function GetModeKey(contentType)
    local db = EnsureDB()
    contentType = NormalizeContentType(contentType)

    if not db then
        return DEFAULT_MODE_BY_CONTENT[contentType]
    end

    local value = db.mythicPlusMode

    if contentType == "raid" then
        value = db.raidMode
    elseif contentType == "pvp" then
        value = db.pvpMode
    end

    local options = GetModeOptions(contentType)

    for _, option in ipairs(options) do
        if option.value == value then
            return value
        end
    end

    return options[1] and options[1].value or DEFAULT_MODE_BY_CONTENT[contentType]
end

local function SetModeKey(contentType, value)
    local db = EnsureDB()

    if not db then
        return
    end

    contentType = NormalizeContentType(contentType)

    for _, option in ipairs(GetModeOptions(contentType)) do
        if option.value == value then
            if contentType == "raid" then
                db.raidMode = value
            elseif contentType == "pvp" then
                db.pvpMode = value
            else
                db.mythicPlusMode = value
            end

            db.mode = value
            return
        end
    end
end

local function GetTargetKey(contentType)
    local db = EnsureDB()
    contentType = NormalizeContentType(contentType)

    if not db then
        if contentType == "raid" then
            return DEFAULT_TARGET_BY_CONTENT.raid
        elseif contentType == "pvp" then
            return DEFAULT_TARGET_BY_CONTENT.pvp
        end

        return DEFAULT_TARGET_BY_CONTENT.mythicplus
    end

    local value
    if contentType == "raid" then
        value = db.raidTarget or DEFAULT_TARGET_BY_CONTENT.raid
    elseif contentType == "pvp" then
        value = db.pvpTarget or DEFAULT_TARGET_BY_CONTENT.pvp
    else
        value = db.mythicPlusTarget or DEFAULT_TARGET_BY_CONTENT.mythicplus
    end

    local alternateSpecKey, actualTargetKey = DecodeAlternateSpecTarget(value)
    local _, activeSpecKey = GetClassAndSpec()

    -- Once the requested specialization switch has completed, restore the normal
    -- target key so the dropdown returns to its standard entries.
    if alternateSpecKey and alternateSpecKey == activeSpecKey then
        if contentType == "raid" then
            db.raidTarget = actualTargetKey
        elseif contentType == "pvp" then
            db.pvpTarget = actualTargetKey
        else
            db.mythicPlusTarget = actualTargetKey
        end
        return actualTargetKey
    end

    return value
end

local function SetTargetKey(contentType, value)
    local db = EnsureDB()

    if not db then
        return
    end

    contentType = NormalizeContentType(contentType)

    if contentType == "raid" then
        db.raidTarget = value or DEFAULT_TARGET_BY_CONTENT.raid
    elseif contentType == "pvp" then
        db.pvpTarget = value or DEFAULT_TARGET_BY_CONTENT.pvp
    else
        db.mythicPlusTarget = value or DEFAULT_TARGET_BY_CONTENT.mythicplus
    end
end

local function GetTargetOptions(contentType)
    local root = GetRoot()
    local specData = GetCurrentSpecData()
    local providerKey = GetProviderKey()
    local labels = {}
    local options = {}

    contentType = NormalizeContentType(contentType)

    if root and root.targets and root.targets[contentType] and (not root.providers) then
        for key, label in pairs(root.targets[contentType]) do
            labels[key] = label
        end
    end

    if specData and specData[contentType] then
        for key, targetData in pairs(specData[contentType]) do
            if TargetHasProvider(targetData, providerKey) then
                labels[key] = type(targetData) == "table" and targetData.label or labels[key] or key
            end
        end
    end

    if not next(labels) and contentType == "raid" then
        labels["all-bosses"] = labels["all-bosses"] or "All Bosses"
    elseif not next(labels) and contentType == "pvp" then
        labels[DEFAULT_TARGET_BY_CONTENT.pvp] = labels[DEFAULT_TARGET_BY_CONTENT.pvp] or "Icy Veins"
    elseif not next(labels) then
        labels["all-dungeons"] = labels["all-dungeons"] or "All Dungeons"
    end

    for key, label in pairs(labels) do
        options[#options + 1] = {
            value = key,
            text = label,
        }
    end

    table.sort(options, function(left, right)
        local leftOrder = TARGET_SORT_ORDER[left.value]
        local rightOrder = TARGET_SORT_ORDER[right.value]

        if leftOrder and rightOrder then
            return leftOrder < rightOrder
        elseif leftOrder then
            return true
        elseif rightOrder then
            return false
        end

        return tostring(left.text) < tostring(right.text)
    end)

    return options
end

local function GetTargetLabel(contentType, targetKey)
    for _, option in ipairs(GetTargetOptions(contentType)) do
        if option.value == targetKey then
            return option.text
        end
    end

    return tostring(targetKey or "")
end

local function GetBuildEntryForTarget(contentType, targetKey, mode)
    local specData, classToken, activeSpecKey = GetCurrentSpecData()

    contentType = NormalizeContentType(contentType)
    targetKey = targetKey or GetTargetKey(contentType)
    mode = mode or GetModeKey(contentType)

    local alternateSpecKey, actualTargetKey = DecodeAlternateSpecTarget(targetKey)
    local specKey = alternateSpecKey or activeSpecKey
    local root = GetRoot()

    if alternateSpecKey then
        specData = root
            and root.data
            and classToken
            and root.data[classToken]
            and root.data[classToken][alternateSpecKey]
    end

    local providerKey = GetProviderKey()
    local targetData = specData and specData[contentType] and specData[contentType][actualTargetKey]
    if not alternateSpecKey and (not targetData or not TargetHasProvider(targetData, providerKey)) and specData and specData[contentType] then
        for fallbackTargetKey, fallbackTargetData in pairs(specData[contentType]) do
            if TargetHasProvider(fallbackTargetData, providerKey) then
                actualTargetKey = fallbackTargetKey
                targetKey = fallbackTargetKey
                targetData = fallbackTargetData
                break
            end
        end
    end

    local builds, providerData = GetProviderBuilds(targetData, providerKey)
    local preferredFallbackMode

    if contentType == "mythicplus" then
        preferredFallbackMode = "highkey"
    elseif contentType == "raid" then
        preferredFallbackMode = "mythic"
    end

    local fallbackMode = GetFirstBuildKey(builds)
    local entry = builds and builds[mode]

    -- PvP brackets are distinct data sets. Never silently substitute Solo, 2v2,
    -- or another bracket when the selected one is missing.
    if not entry and contentType ~= "pvp" then
        entry = builds and (builds.popular or (preferredFallbackMode and builds[preferredFallbackMode]) or (fallbackMode and builds[fallbackMode]))
    end

    if entry and contentType ~= "pvp" and (not builds or not builds[mode]) then
        if builds and preferredFallbackMode and builds[preferredFallbackMode] == entry then
            mode = preferredFallbackMode
        elseif builds and builds.popular == entry then
            mode = "popular"
        else
            mode = fallbackMode or mode
        end
    end

    local targetLabel = type(targetData) == "table" and targetData.label or GetTargetLabel(contentType, actualTargetKey)
    if alternateSpecKey then
        targetLabel = GetSpecLabel(alternateSpecKey) .. " - " .. tostring(targetLabel or actualTargetKey)
    end

    return entry, {
        classToken = classToken,
        specKey = specKey,
        activeSpecKey = activeSpecKey,
        requiresSpecSwitch = alternateSpecKey ~= nil and alternateSpecKey ~= activeSpecKey,
        alternateSpecIndex = alternateSpecKey and GetSpecIndexForKey(classToken, alternateSpecKey) or nil,
        contentType = contentType,
        targetKey = targetKey,
        actualTargetKey = actualTargetKey,
        targetLabel = targetLabel,
        mode = mode,
        modeLabel = GetOptionText(GetModeOptions(contentType, targetKey), mode),
        generatedAt = GetRoot() and GetRoot().generatedAt,
        provider = providerKey,
        providerLabel = GetOptionText(GetProviderOptions(), providerKey),
        source = (entry and entry.source) or (providerData and providerData.label) or (GetRoot() and GetRoot().source),
        heroTree = entry and entry.heroTree,
        buildTitle = entry and entry.title,
    }
end

local function GetBuildEntry()
    local db = EnsureDB()
    local contentType = db and db.contentType or "mythicplus"
    local contentOptions = GetContentOptions()
    local contentAvailable = false

    for _, option in ipairs(contentOptions) do
        if option.value == contentType then
            contentAvailable = true
            break
        end
    end

    if not contentAvailable and contentOptions[1] then
        contentType = contentOptions[1].value
        if db then db.contentType = contentType end
    end

    return GetBuildEntryForTarget(contentType, GetTargetKey(contentType), GetModeKey(contentType))
end

local function FormatPercent(value)
    value = tonumber(value)

    if not value then
        return nil
    end

    if math.abs(value - math.floor(value + 0.5)) < 0.05 then
        return tostring(math.floor(value + 0.5)) .. "%"
    end

    return string.format("%.1f%%", value)
end

local function FormatTalentSummary(entry)
    local talents = entry and entry.talents and entry.talents.pvp

    if type(talents) ~= "table" then
        return nil
    end

    local names = {}

    for _, talent in ipairs(talents) do
        if talent and talent.name and tonumber(talent.count or 0) > 0 then
            names[#names + 1] = tostring(talent.name)

            if #names >= 3 then
                break
            end
        end
    end

    if #names == 0 then
        return nil
    end

    return "PvP talents: " .. table.concat(names, ", ")
end

local function FormatBuildUsage(entry)
    if not entry then
        return "No build data"
    end

    local parts = {}

    if entry.popularity then
        parts[#parts + 1] = FormatPercent(entry.popularity)
    end

    if entry.sampleSize then
        parts[#parts + 1] = tostring(entry.sampleSize) .. " " .. tostring(entry.sampleLabel or "logs")
    end

    if entry.keyRange then
        parts[#parts + 1] = tostring(entry.keyRange)
    end

    if entry.rankRange then
        parts[#parts + 1] = tostring(entry.rankRange)
    end

    if entry.difficulty then
        parts[#parts + 1] = tostring(entry.difficulty)
    end

    local talentSummary = FormatTalentSummary(entry)

    if talentSummary then
        parts[#parts + 1] = talentSummary
    end

    if #parts == 0 then
        return "Generated build"
    end

    return table.concat(parts, "  |  ")
end

local function RunNextFrame(callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, callback)
    else
        callback()
    end
end

TargetHasProvider = function(targetData, providerKey)
    if type(targetData) ~= "table" then
        return false
    end

    if type(targetData.providers) == "table" then
        local providerData = targetData.providers[providerKey]
        return type(providerData) == "table" and type(providerData.builds) == "table" and next(providerData.builds) ~= nil
    end

    return type(targetData.builds) == "table" and next(targetData.builds) ~= nil
end

GetProviderOptions = function()
    local root = GetRoot()
    local specData = GetCurrentSpecData()
    local available = {}
    local options = {}

    if type(specData) == "table" then
        for _, contentData in pairs(specData) do
            if type(contentData) == "table" then
                for _, targetData in pairs(contentData) do
                    if type(targetData) == "table" and type(targetData.providers) == "table" then
                        for providerKey, providerData in pairs(targetData.providers) do
                            if type(providerData) == "table" and type(providerData.builds) == "table" and next(providerData.builds) then
                                available[providerKey] = providerData.label
                            end
                        end
                    end
                end
            end
        end
    end

    if not next(available) then
        available[DEFAULT_PROVIDER] = "Generated"
    end

    for providerKey, fallbackLabel in pairs(available) do
        local metadata = root and root.providers and root.providers[providerKey]
        options[#options + 1] = {
            value = providerKey,
            text = (metadata and metadata.label) or fallbackLabel or TitleCase(providerKey),
        }
    end

    table.sort(options, function(left, right)
        local leftOrder = PROVIDER_SORT_ORDER[left.value] or 100
        local rightOrder = PROVIDER_SORT_ORDER[right.value] or 100
        if leftOrder ~= rightOrder then return leftOrder < rightOrder end
        return tostring(left.text) < tostring(right.text)
    end)

    return options
end

GetProviderKey = function()
    local db = EnsureDB()
    local requested = db and db.provider or DEFAULT_PROVIDER
    local options = GetProviderOptions()

    for _, option in ipairs(options) do
        if option.value == requested then
            return requested
        end
    end

    return options[1] and options[1].value or DEFAULT_PROVIDER
end

GetProviderBuilds = function(targetData, providerKey)
    if type(targetData) ~= "table" then
        return nil
    end

    if type(targetData.providers) == "table" then
        local providerData = targetData.providers[providerKey]
        return providerData and providerData.builds, providerData
    end

    return targetData.builds, targetData
end

GetContentOptions = function()
    local specData = GetCurrentSpecData()
    local providerKey = GetProviderKey()
    local options = {}

    for _, option in ipairs(CONTENT_OPTIONS) do
        local contentData = specData and specData[option.value]
        local available = false

        if type(contentData) == "table" then
            for _, targetData in pairs(contentData) do
                if TargetHasProvider(targetData, providerKey) then
                    available = true
                    break
                end
            end
        end

        if available then
            options[#options + 1] = option
        end
    end

    return #options > 0 and options or CONTENT_OPTIONS
end

function SecureTalentCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    if securecallfunction then
        return securecallfunction(func, ...)
    end

    return func(...)
end

PrintTalentMessage = function(message)
    if ns.Print then
        ns:Print(message)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffZoidsTools|r: " .. tostring(message))
    elseif print then
        print("ZoidsTools: " .. tostring(message))
    end
end

local function GetCurrentSpecID()
    if not GetSpecialization or not GetSpecializationInfo then
        return nil
    end

    local specIndex = GetSpecialization()

    if not specIndex then
        return nil
    end

    return (GetSpecializationInfo(specIndex))
end

local function GetActiveConfigID()
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        return C_ClassTalents.GetActiveConfigID()
    end

    return nil
end

local function GetConfigTreeID(configID)
    if not configID or not C_Traits or not C_Traits.GetConfigInfo then
        return nil
    end

    local configInfo = C_Traits.GetConfigInfo(configID)
    return configInfo and configInfo.treeIDs and configInfo.treeIDs[1]
end

local function GetTalentLoadoutDB()
    local db = EnsureDB()

    if db then
        db.loadouts = db.loadouts or {}
    end

    return db
end

local function ClearStoredConfigID(specID)
    local db = GetTalentLoadoutDB()

    if db and db.loadouts and specID then
        db.loadouts[specID] = nil
    end
end

local function GetStoredConfigID(specID)
    local db = GetTalentLoadoutDB()
    local stored = db and db.loadouts and db.loadouts[specID]

    if not stored then
        return nil
    end

    stored = tonumber(stored)

    if C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID then
        local validIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)

        if validIDs then
            for _, configID in ipairs(validIDs) do
                if configID == stored then
                    return stored
                end
            end

            ClearStoredConfigID(specID)
            return nil
        end
    end

    if C_Traits and C_Traits.GetConfigInfo then
        local ok, info = pcall(C_Traits.GetConfigInfo, stored)

        if ok and info then
            return stored
        end
    end

    ClearStoredConfigID(specID)
    return nil
end

local function StoreConfigID(specID, configID)
    local db = GetTalentLoadoutDB()

    if db and db.loadouts and specID and configID then
        db.loadouts[specID] = configID
    end
end

local function GetSelectedSavedConfigID(specID)
    if specID and C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID then
        return C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    end

    return nil
end

local function RememberSavedConfigID(specID, configID)
    if specID and C_ClassTalents and C_ClassTalents.UpdateLastSelectedSavedConfigID then
        SecureTalentCall(C_ClassTalents.UpdateLastSelectedSavedConfigID, specID, configID)
    end
end

local function BuildTalentLabel(context)
    if not context then
        return "Build"
    end

    local parts = {}

    if context.contentType then
        parts[#parts + 1] = GetContentLabel(context.contentType)
    end

    if context.modeLabel and context.modeLabel ~= "" then
        parts[#parts + 1] = context.modeLabel
    end

    local modeContainsTarget = context.modeLabel
        and context.modeLabel ~= ""
        and context.targetLabel
        and context.targetLabel ~= ""
        and string.find(string.lower(context.modeLabel), string.lower(context.targetLabel), 1, true) ~= nil

    if context.targetLabel and context.targetLabel ~= "" and not modeContainsTarget then
        parts[#parts + 1] = context.targetLabel
    end

    if #parts == 0 then
        return "Build"
    end

    return table.concat(parts, " / ")
end

local function BuildLoadoutName(buildLabel)
    local name = ZOIDS_LOADOUT_NAME

    if buildLabel and buildLabel ~= "" then
        name = name .. ": " .. tostring(buildLabel)
    end

    if #name > 48 then
        name = string.sub(name, 1, 45) .. "..."
    end

    return name
end

local function SetPendingApply(value)
    pendingApplySeq = pendingApplySeq + 1
    local sequence = pendingApplySeq
    pendingApply = value

    if C_Timer and C_Timer.After then
        C_Timer.After(PENDING_APPLY_WATCHDOG_SECS, function()
            if pendingApplySeq == sequence then
                local expiredApply = pendingApply
                pendingApply = nil
                ns._talentApplyInProgress = false
                applyToken = applyToken + 1

                if applyFrame then
                    applyFrame:UnregisterEvent("TRAIT_CONFIG_CREATED")
                    applyFrame:UnregisterEvent("TRAIT_CONFIG_UPDATED")
                end

                local configID = expiredApply and expiredApply.configID or GetActiveConfigID()
                if expiredApply and expiredApply.rollbackOnTimeout == true and configID and RollbackTalentConfig then
                    local rolledBack = RollbackTalentConfig(configID)

                    if not rolledBack and C_Timer and C_Timer.After then
                        C_Timer.After(1, function()
                            if pendingApplySeq == sequence and ConfigHasStagedChanges(configID) then
                                RollbackTalentConfig(configID)
                                if QueueRefresh then
                                    QueueRefresh(0)
                                end
                            end
                        end)
                    end
                end

                if PrintTalentMessage then
                    if expiredApply and expiredApply.rollbackOnTimeout == true then
                        PrintTalentMessage("Talent application timed out. Pending changes were discarded; please try Apply again.")
                    else
                        PrintTalentMessage("Talent application timed out; please try Apply again.")
                    end
                end

                if QueueRefresh then
                    QueueRefresh(0)
                end
            end
        end)
    end
end

local function ClearPendingApply()
    pendingApplySeq = pendingApplySeq + 1
    pendingApply = nil
end

local function FailTalentApply(message)
    ClearPendingApply()
    ns._talentApplyInProgress = false
    return nil, message
end

local function ContinuePendingApplyAfterLoad(applyState)
    if pendingApply ~= applyState or not applyState.waitingForLoad then
        return
    end

    applyState.waitingForLoad = false

    if applyFrame then
        applyFrame:UnregisterEvent("TRAIT_CONFIG_UPDATED")
    end

    RunNextFrame(function()
        if pendingApply == applyState then
            ns:ApplyTalentImportString(applyState.importString, applyState.buildLabel, true)
        end
    end)
end

ConfigHasStagedChanges = function(configID)
    return configID
        and C_Traits
        and C_Traits.ConfigHasStagedChanges
        and C_Traits.ConfigHasStagedChanges(configID)
end

RollbackTalentConfig = function(configID)
    if not ConfigHasStagedChanges(configID) then
        return true
    end

    if not C_Traits or not C_Traits.RollbackConfig then
        return false
    end

    local ok, result = pcall(SecureTalentCall, C_Traits.RollbackConfig, configID)

    return ok and result ~= false
end

local function IsZoidsTalentConfig(configID, specID)
    if not configID then
        return false
    end

    local storedConfigID = specID and GetStoredConfigID(specID) or nil

    if storedConfigID and tonumber(storedConfigID) == tonumber(configID) then
        return true
    end

    if C_Traits and C_Traits.GetConfigInfo then
        local ok, info = pcall(C_Traits.GetConfigInfo, configID)
        local name = ok and info and info.name

        if name == ZOIDS_LOADOUT_NAME or (type(name) == "string" and string.find(name, ZOIDS_LOADOUT_NAME .. ":", 1, true) == 1) then
            return true
        end
    end

    return false
end

local function ReadLoadoutHeader(importStream)
    local headerBitWidth = BIT_WIDTH_HEADER_VERSION + BIT_WIDTH_SPEC_ID + 128

    if importStream:GetNumberOfBits() < headerBitWidth then
        return false, 0, 0
    end

    local serializationVersion = importStream:ExtractValue(BIT_WIDTH_HEADER_VERSION)
    local specID = importStream:ExtractValue(BIT_WIDTH_SPEC_ID)

    for _ = 1, 16 do
        importStream:ExtractValue(8)
    end

    return true, serializationVersion, specID
end

local function GetSortedTreeNodes(treeID)
    local treeNodes = {}

    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        treeNodes[#treeNodes + 1] = nodeID
    end

    -- Blizzard serializes loadouts by numeric node ID, not by the order
    -- returned from GetTreeNodes.
    table.sort(treeNodes)
    return treeNodes
end

local function ReadLoadoutContent(importStream, treeID)
    local results = {}
    local treeNodes = GetSortedTreeNodes(treeID)

    for index, nodeID in ipairs(treeNodes) do
        local isNodeSelected = importStream:ExtractValue(1) == 1
        local isNodePurchased = false
        local isPartiallyRanked = false
        local partialRanksPurchased = 0
        local isChoiceNode = false
        local choiceNodeSelection = 0

        if isNodeSelected then
            isNodePurchased = importStream:ExtractValue(1) == 1

            if isNodePurchased then
                isPartiallyRanked = importStream:ExtractValue(1) == 1

                if isPartiallyRanked then
                    partialRanksPurchased = importStream:ExtractValue(BIT_WIDTH_RANKS_PURCHASED)
                end

                isChoiceNode = importStream:ExtractValue(1) == 1

                if isChoiceNode then
                    choiceNodeSelection = importStream:ExtractValue(2)
                end
            end
        end

        results[index] = {
            nodeID = nodeID,
            isNodePurchased = isNodePurchased,
            isPartiallyRanked = isPartiallyRanked,
            partialRanksPurchased = partialRanksPurchased,
            isChoiceNode = isChoiceNode,
            choiceNodeSelection = choiceNodeSelection + 1,
        }
    end

    return results
end

local function ConvertLoadoutToEntryInfo(configID, treeID, loadoutContent)
    local results = {}
    local treeNodes = GetSortedTreeNodes(treeID)

    for index, treeNodeID in ipairs(treeNodes) do
        local indexInfo = loadoutContent[index]

        if indexInfo and indexInfo.isNodePurchased then
            local nodeInfo = C_Traits.GetNodeInfo(configID, treeNodeID)

            if nodeInfo and nodeInfo.ID ~= 0 then
                local isSelectionNode = nodeInfo.type == Enum.TraitNodeType.Selection
                local isSubTreeSelection = nodeInfo.type == Enum.TraitNodeType.SubTreeSelection
                local isChoice = isSelectionNode or isSubTreeSelection
                local choiceIndex = indexInfo.isChoiceNode and indexInfo.choiceNodeSelection or nil

                if isChoice ~= indexInfo.isChoiceNode then
                    choiceIndex = 1
                end

                local selectionEntryID

                if isChoice and choiceIndex and nodeInfo.entryIDs then
                    selectionEntryID = nodeInfo.entryIDs[choiceIndex]
                elseif nodeInfo.activeEntry then
                    selectionEntryID = nodeInfo.activeEntry.entryID
                end

                local ranks = nodeInfo.maxRanks or 1

                if indexInfo.isPartiallyRanked then
                    ranks = indexInfo.partialRanksPurchased
                end

                results[treeNodeID] = {
                    nodeID = treeNodeID,
                    ranksPurchased = ranks,
                    selectionEntryID = selectionEntryID,
                    isChoiceNode = isChoice,
                    isSubTreeSelection = isSubTreeSelection,
                }
            end
        end
    end

    return results
end

local function ParseTalentImportString(importString, treeID, configID)
    if not ExportUtil or not ExportUtil.MakeImportDataStream or not C_Traits or not C_Traits.GetTreeNodes then
        return nil, "Required talent import APIs are not available."
    end

    local ok, importStream = pcall(ExportUtil.MakeImportDataStream, importString)

    if not ok or not importStream then
        return nil, "Could not decode this talent string."
    end

    local headerValid, serializationVersion, specID = ReadLoadoutHeader(importStream)

    if not headerValid then
        return nil, "This talent string is not valid."
    end

    if C_Traits.GetLoadoutSerializationVersion then
        local expectedVersion = C_Traits.GetLoadoutSerializationVersion()

        if expectedVersion and serializationVersion ~= expectedVersion then
            return nil, "This talent string uses a different game build format."
        end
    end

    local currentSpecID = GetCurrentSpecID()

    if currentSpecID and specID ~= currentSpecID then
        return nil, string.format("This build is for spec ID %d, but your active spec is %d.", specID, currentSpecID)
    end

    local contentOk, loadoutContent = pcall(ReadLoadoutContent, importStream, treeID)

    if not contentOk or not loadoutContent then
        return nil, "Could not read the talent build contents."
    end

    local convertOk, entryInfo = pcall(ConvertLoadoutToEntryInfo, configID, treeID, loadoutContent)

    if not convertOk or not entryInfo then
        return nil, "Could not match this talent build to the active tree."
    end

    return entryInfo
end

local function ExtractTalentBits(exportString)
    if not exportString or not ExportUtil or not ExportUtil.MakeImportDataStream then
        return nil
    end

    local ok, stream = pcall(ExportUtil.MakeImportDataStream, exportString)

    if not ok or not stream then
        return nil
    end

    for _ = 1, 19 do
        local headerOK = pcall(stream.ExtractValue, stream, 8)

        if not headerOK then
            return nil
        end
    end

    local bits = {}

    for _ = 1, 500 do
        local bitOK, value = pcall(stream.ExtractValue, stream, 1)

        if not bitOK then
            break
        end

        bits[#bits + 1] = value
    end

    return table.concat(bits)
end

local function GetActiveTalentSignature()
    if not C_Traits or not C_Traits.GenerateImportString then
        return nil
    end

    local configID = GetActiveConfigID()

    if not configID then
        return nil
    end

    local ok, exportString = pcall(C_Traits.GenerateImportString, configID)

    if not ok or not exportString then
        return nil
    end

    return ExtractTalentBits(exportString)
end

local function TalentImportMatchesActive(importString)
    local activeBits = GetActiveTalentSignature()
    local importBits = ExtractTalentBits(importString)

    return activeBits ~= nil and importBits ~= nil and activeBits == importBits
end

local function TalentImportMatchesSignature(importString, activeBits)
    local importBits = ExtractTalentBits(importString)

    return activeBits ~= nil and importBits ~= nil and activeBits == importBits
end

local function TalentEntryMatchesForTarget(leftEntry, rightEntry)
    if not leftEntry or not rightEntry then
        return false
    end

    if (leftEntry.ranksPurchased or 0) ~= (rightEntry.ranksPurchased or 0) then
        return false
    end

    if leftEntry.isChoiceNode or rightEntry.isChoiceNode then
        return leftEntry.selectionEntryID == rightEntry.selectionEntryID
    end

    return true
end

local function TalentEntryMapsMatch(leftEntries, rightEntries)
    if not leftEntries or not rightEntries then
        return false
    end

    for nodeID, leftEntry in pairs(leftEntries) do
        if not TalentEntryMatchesForTarget(leftEntry, rightEntries[nodeID]) then
            return false
        end
    end

    for nodeID, rightEntry in pairs(rightEntries) do
        if not TalentEntryMatchesForTarget(leftEntries[nodeID], rightEntry) then
            return false
        end
    end

    return true
end

local function GetActiveTargetKeys(contentType, mode)
    local activeTargetKeys = {}
    local hasActiveTarget = false
    local configID = GetActiveConfigID()
    local treeID = GetConfigTreeID(configID)
    local activeEntryInfo

    if not configID or not treeID or not C_Traits or not C_Traits.GenerateImportString then
        return activeTargetKeys, hasActiveTarget
    end

    local ok, activeImportString = pcall(C_Traits.GenerateImportString, configID)

    if ok and activeImportString then
        activeEntryInfo = ParseTalentImportString(activeImportString, treeID, configID)
    end

    local activeBits = not activeEntryInfo and GetActiveTalentSignature() or nil

    if not activeEntryInfo and not activeBits then
        return activeTargetKeys, hasActiveTarget
    end

    contentType = NormalizeContentType(contentType)
    mode = mode or GetModeKey(contentType)

    for _, option in ipairs(GetTargetOptions(contentType)) do
        local entry = GetBuildEntryForTarget(contentType, option.value, mode)
        local importString = entry and entry.importString or ""

        local matchesActive = false

        if importString ~= "" and activeEntryInfo then
            local targetEntryInfo = ParseTalentImportString(importString, treeID, configID)
            matchesActive = TalentEntryMapsMatch(activeEntryInfo, targetEntryInfo)
        elseif importString ~= "" then
            matchesActive = TalentImportMatchesSignature(importString, activeBits)
        end

        if matchesActive then
            activeTargetKeys[option.value] = true
            hasActiveTarget = true
        end
    end

    return activeTargetKeys, hasActiveTarget
end

local function GetTargetDropdownOptions(contentType, mode, selectedTargetKey)
    local alternateSpecKey, actualTargetKey = DecodeAlternateSpecTarget(selectedTargetKey)
    local currentEntry = GetBuildEntryForTarget(contentType, actualTargetKey, mode)

    if contentType == "pvp" and not currentEntry then
        local root = GetRoot()
        local _, classToken, activeSpecKey = GetCurrentSpecData()
        local classData = root and root.data and classToken and root.data[classToken]
        local providerKey = GetProviderKey()
        local modeLabel = GetOptionText(GetModeOptions(contentType, actualTargetKey), mode)
        local compactModeLabel = mode == "rbg" and "RBG" or modeLabel
        local options = {
            {
                value = actualTargetKey,
                text = GetSpecLabel(activeSpecKey) .. " - no " .. tostring(compactModeLabel) .. " build",
            },
        }

        if type(classData) == "table" then
            for specKey, specData in pairs(classData) do
                if specKey ~= activeSpecKey and type(specData) == "table" then
                    local targetData = specData.pvp and specData.pvp[actualTargetKey]
                    local builds = GetProviderBuilds(targetData, providerKey)
                    local entry = builds and builds[mode]

                    if entry then
                        options[#options + 1] = {
                            value = EncodeAlternateSpecTarget(specKey, actualTargetKey),
                            text = GetSpecLabel(specKey) .. " - " .. tostring(compactModeLabel),
                        }
                    end
                end
            end
        end

        table.sort(options, function(left, right)
            if left.value == actualTargetKey then return true end
            if right.value == actualTargetKey then return false end
            return tostring(left.text) < tostring(right.text)
        end)

        return options, {}, alternateSpecKey ~= nil
    end

    local options = GetTargetOptions(contentType)
    local activeTargetKeys, hasActiveTarget = GetActiveTargetKeys(contentType, mode)

    for _, option in ipairs(options) do
        if activeTargetKeys[option.value] then
            option.displayText = ColorizeText(option.text, ACTIVE_TARGET_TEXT_COLOR)
            option.textColor = ACTIVE_TARGET_TEXT_RGBA
        elseif hasActiveTarget and option.value == selectedTargetKey then
            option.displayText = ColorizeText(option.text, PENDING_TARGET_TEXT_COLOR)
            option.textColor = PENDING_TARGET_TEXT_RGBA
        end
    end

    return options, activeTargetKeys
end

local function ResetAndPurchaseDeferred(configID, treeID, entryInfo, onComplete)
    applyToken = applyToken + 1
    local token = applyToken
    local diagnosticStage = "setup"
    local diagnosticRow = 0
    local playerLevel = UnitLevel and UnitLevel("player") or 0
    local maxPlayerLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or playerLevel
    local isLevelingCharacter = playerLevel > 0 and maxPlayerLevel > playerLevel
    local levelDeferredNodes = 0

    LogTalentApplyDiagnostic("Resetting config=%s tree=%s applyToken=%d.", tostring(configID), tostring(treeID), token)

    SecureTalentCall(C_Traits.ResetTree, configID, treeID)

    local function EntryStateMatches(nodeInfo, entry)
        if not nodeInfo or not entry then
            return false
        end

        if entry.isChoiceNode and entry.selectionEntryID then
            local activeEntryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID

            if activeEntryID ~= entry.selectionEntryID then
                return false
            end

            if entry.isSubTreeSelection then
                return true
            end

            return ((nodeInfo.ranksPurchased or 0) >= (entry.ranksPurchased or 1))
        end

        return ((nodeInfo.ranksPurchased or 0) >= (entry.ranksPurchased or 0))
    end

    local function GetDiagnosticNodeLabel(nodeID, entry, nodeInfo)
        local entryID = entry and entry.selectionEntryID

        if not entryID and nodeInfo and nodeInfo.activeEntry then
            entryID = nodeInfo.activeEntry.entryID
        end

        if entryID and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo then
            local okEntry, traitEntry = pcall(C_Traits.GetEntryInfo, configID, entryID)

            if okEntry and traitEntry and traitEntry.definitionID then
                local okDefinition, definition = pcall(C_Traits.GetDefinitionInfo, traitEntry.definitionID)

                if okDefinition and definition and definition.spellID and C_Spell and C_Spell.GetSpellName then
                    local spellName = C_Spell.GetSpellName(definition.spellID)

                    if spellName and spellName ~= "" then
                        return string.format("%s (node %d)", spellName, nodeID)
                    end
                end
            end
        end

        return string.format("node %d", nodeID)
    end

    local function TryApplyEntry(nodeID, allowSubTreeSelection)
        local entry = entryInfo[nodeID]

        if not entry then
            return true, false
        end

        local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        local label = GetDiagnosticNodeLabel(nodeID, entry, nodeInfo)
        local beforeRanks = nodeInfo and nodeInfo.ranksPurchased or 0
        local beforeEntryID = nodeInfo and nodeInfo.activeEntry and nodeInfo.activeEntry.entryID or 0

        LogTalentApplyDiagnostic(
            "TRY stage=%s row=%d %s targetRanks=%s targetEntry=%s beforeRanks=%s beforeEntry=%s canPurchase=%s available=%s visible=%s edgeOK=%s subtree=%s.",
            diagnosticStage,
            diagnosticRow,
            label,
            tostring(entry.ranksPurchased),
            tostring(entry.selectionEntryID),
            tostring(beforeRanks),
            tostring(beforeEntryID),
            tostring(nodeInfo and nodeInfo.canPurchaseRank == true),
            tostring(nodeInfo and nodeInfo.isAvailable),
            tostring(nodeInfo and nodeInfo.isVisible),
            tostring(nodeInfo and nodeInfo.meetsEdgeRequirements),
            tostring(entry.isSubTreeSelection == true)
        )

        if EntryStateMatches(nodeInfo, entry) then
            entryInfo[nodeID] = nil
            LogTalentApplyDiagnostic("OK %s already matched.", label)
            return true, true
        end

        local madeProgress = false

        if entry.isChoiceNode and entry.selectionEntryID then
            local activeEntryID = nodeInfo and nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
            local canSetSelection = allowSubTreeSelection and entry.isSubTreeSelection
                or (nodeInfo and nodeInfo.canPurchaseRank == true)

            -- A choice node can already display the requested entry while still
            -- having zero purchased ranks. SetSelection does nothing in that
            -- state, so purchase the rank after confirming the correct choice.
            if activeEntryID ~= entry.selectionEntryID and canSetSelection then
                madeProgress = SecureTalentCall(
                    C_Traits.SetSelection,
                    configID,
                    entry.nodeID,
                    entry.selectionEntryID
                ) or false
                nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                activeEntryID = nodeInfo and nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
            end

            if not entry.isSubTreeSelection and activeEntryID == entry.selectionEntryID then
                local currentRanks = nodeInfo and nodeInfo.ranksPurchased or 0
                local neededRanks = math.max(0, (entry.ranksPurchased or 1) - currentRanks)

                for _ = 1, neededRanks do
                    nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)

                    if not nodeInfo or nodeInfo.canPurchaseRank ~= true then
                        break
                    end

                    local rankOK = SecureTalentCall(C_Traits.PurchaseRank, configID, entry.nodeID)

                    if not rankOK then
                        break
                    end

                    madeProgress = true
                end

                nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            end
        elseif entry.ranksPurchased and nodeInfo then
            local currentRanks = nodeInfo.ranksPurchased or 0
            local neededRanks = math.max(0, entry.ranksPurchased - currentRanks)

            for _ = 1, neededRanks do
                nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)

                if not nodeInfo or nodeInfo.canPurchaseRank ~= true then
                    break
                end

                local rankOK = SecureTalentCall(C_Traits.PurchaseRank, configID, entry.nodeID)

                if not rankOK then
                    break
                end

                madeProgress = true
            end

            nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        end

        if EntryStateMatches(nodeInfo, entry) then
            entryInfo[nodeID] = nil
            LogTalentApplyDiagnostic(
                "OK %s afterRanks=%s afterEntry=%s.",
                label,
                tostring(nodeInfo and nodeInfo.ranksPurchased or 0),
                tostring(nodeInfo and nodeInfo.activeEntry and nodeInfo.activeEntry.entryID or 0)
            )
            return true, true
        end

        LogTalentApplyDiagnostic(
            "BLOCKED %s afterRanks=%s afterEntry=%s canPurchase=%s available=%s visible=%s edgeOK=%s progress=%s.",
            label,
            tostring(nodeInfo and nodeInfo.ranksPurchased or 0),
            tostring(nodeInfo and nodeInfo.activeEntry and nodeInfo.activeEntry.entryID or 0),
            tostring(nodeInfo and nodeInfo.canPurchaseRank == true),
            tostring(nodeInfo and nodeInfo.isAvailable),
            tostring(nodeInfo and nodeInfo.isVisible),
            tostring(nodeInfo and nodeInfo.meetsEdgeRequirements),
            tostring(madeProgress)
        )

        return false, madeProgress
    end

    local heroSelectionNodeID
    local mainNodes = {}
    local heroNodes = {}

    for nodeID, entry in pairs(entryInfo) do
        if entry.isSubTreeSelection then
            heroSelectionNodeID = nodeID
        end
    end

    for nodeID, entry in pairs(entryInfo) do
        if nodeID ~= heroSelectionNodeID then
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)

            if nodeInfo and nodeInfo.subTreeID then
                heroNodes[#heroNodes + 1] = nodeID
            else
                mainNodes[#mainNodes + 1] = nodeID
            end
        end
    end

    local function BuildOrderedNodes(nodeIDs)
        table.sort(nodeIDs, function(leftNodeID, rightNodeID)
            local leftInfo = C_Traits.GetNodeInfo(configID, leftNodeID)
            local rightInfo = C_Traits.GetNodeInfo(configID, rightNodeID)
            local leftY = (leftInfo and leftInfo.posY) or 0
            local rightY = (rightInfo and rightInfo.posY) or 0

            if leftY ~= rightY then
                return leftY < rightY
            end

            local leftX = (leftInfo and leftInfo.posX) or 0
            local rightX = (rightInfo and rightInfo.posX) or 0

            if leftX ~= rightX then
                return leftX < rightX
            end

            return leftNodeID < rightNodeID
        end)

        return nodeIDs
    end

    local stages = {
        { name = "main", nodes = BuildOrderedNodes(mainNodes) },
        { name = "hero", nodes = BuildOrderedNodes(heroNodes) },
    }
    local mainTargetRanks = 0
    local heroTargetRanks = 0

    for _, nodeID in ipairs(mainNodes) do
        mainTargetRanks = mainTargetRanks + math.max(0, tonumber(entryInfo[nodeID] and entryInfo[nodeID].ranksPurchased) or 0)
    end

    for _, nodeID in ipairs(heroNodes) do
        heroTargetRanks = heroTargetRanks + math.max(0, tonumber(entryInfo[nodeID] and entryInfo[nodeID].ranksPurchased) or 0)
    end

    LogTalentApplyDiagnostic(
        "Parsed targets: mainNodes=%d mainRanks=%d heroSelector=%s heroNodes=%d heroRanks=%d.",
        #mainNodes,
        mainTargetRanks,
        tostring(heroSelectionNodeID),
        #heroNodes,
        heroTargetRanks
    )
    local stageIndex = 1
    local passIndex = 1
    local ProcessNext

    local function QueueProcessNext(delay)
        if talentApplyDiagnostics.enabled and C_Timer and C_Timer.After then
            C_Timer.After(delay or TALENT_DIAGNOSTIC_ROW_DELAY, ProcessNext)
        else
            RunNextFrame(ProcessNext)
        end
    end

    local function Finish()
        if token == applyToken and onComplete then
            local remaining = 0
            for _ in pairs(entryInfo) do remaining = remaining + 1 end
            LogTalentApplyDiagnostic("Finished staging loop with %d unresolved node(s).", remaining)
            onComplete({
                levelDeferredNodes = levelDeferredNodes,
                playerLevel = playerLevel,
                maxPlayerLevel = maxPlayerLevel,
            })
        end
    end

    local function ProcessHeroSelection()
        if not heroSelectionNodeID or not entryInfo[heroSelectionNodeID] then
            return true
        end

        local resolved = TryApplyEntry(heroSelectionNodeID, true)
        return resolved == true
    end

    ProcessNext = function()
        if token ~= applyToken then
            return
        end

        local stage = stages[stageIndex]

        if not stage then
            Finish()
            return
        end

        diagnosticStage = stage.name
        diagnosticRow = passIndex

        -- Select the requested hero tree only after every class and
        -- specialization row is completely finished.
        if stage.name == "hero" and not ProcessHeroSelection() then
            if isLevelingCharacter then
                if heroSelectionNodeID and entryInfo[heroSelectionNodeID] then
                    entryInfo[heroSelectionNodeID] = nil
                    levelDeferredNodes = levelDeferredNodes + 1
                end

                for _, heroNodeID in ipairs(heroNodes) do
                    if entryInfo[heroNodeID] then
                        entryInfo[heroNodeID] = nil
                        levelDeferredNodes = levelDeferredNodes + 1
                    end
                end

                LogTalentApplyDiagnostic(
                    "Deferred the hero tree at level %d/%d because its selector is not yet usable.",
                    playerLevel,
                    maxPlayerLevel
                )
                Finish()
                return
            end

            LogTalentApplyDiagnostic("Hero-tree selector could not be changed; stopping before hero talents.")
            Finish()
            return
        end

        LogTalentApplyDiagnostic("Starting %s dependency pass %d with %d target node(s).", stage.name, passIndex, #stage.nodes)
        local unresolved = 0
        local madeProgress = false

        -- Talent-tree visual rows are not dependency tiers. Paladin and other
        -- redesigned trees can place a prerequisite or point-gated node beside
        -- a talent that only becomes available later. Walk every desired node,
        -- then repeat until the dependency graph reaches a fixed point.
        for _, nodeID in ipairs(stage.nodes) do
            if entryInfo[nodeID] then
                local resolved, progressed = TryApplyEntry(nodeID, false)
                madeProgress = madeProgress or progressed

                if not resolved then
                    unresolved = unresolved + 1
                end
            end
        end

        if unresolved == 0 then
            LogTalentApplyDiagnostic("Completed %s stage after %d dependency pass(es).", stage.name, passIndex)
            stageIndex = stageIndex + 1
            passIndex = 1
            QueueProcessNext(TALENT_DIAGNOSTIC_ROW_DELAY)
        elseif madeProgress then
            passIndex = passIndex + 1
            QueueProcessNext(0.25)
        elseif isLevelingCharacter then
            local deferredThisStage = 0

            for _, nodeID in ipairs(stage.nodes) do
                if entryInfo[nodeID] then
                    entryInfo[nodeID] = nil
                    levelDeferredNodes = levelDeferredNodes + 1
                    deferredThisStage = deferredThisStage + 1
                end
            end

            LogTalentApplyDiagnostic(
                "Deferred %d unavailable target(s) from the %s stage for level %d/%d; continuing.",
                deferredThisStage,
                stage.name,
                playerLevel,
                maxPlayerLevel
            )
            stageIndex = stageIndex + 1
            passIndex = 1
            QueueProcessNext(TALENT_DIAGNOSTIC_ROW_DELAY)
        else
            LogTalentApplyDiagnostic("No progress was possible on the %s stage after %d dependency pass(es); stopping.", stage.name, passIndex)
            Finish()
        end
    end

    QueueProcessNext(0.25)
end

local function CompleteCommittedApply(applyState)
    if not applyState or not applyState.renameOnly or pendingApply ~= applyState then
        return false
    end

    local configID = applyState.configID or GetStoredConfigID(GetCurrentSpecID())

    if configID and ConfigHasStagedChanges(configID) then
        return false
    end

    if applyFrame then
        applyFrame:UnregisterEvent("TRAIT_CONFIG_UPDATED")
    end

    if configID and C_ClassTalents and C_ClassTalents.RenameConfig then
        SecureTalentCall(C_ClassTalents.RenameConfig, configID, BuildLoadoutName(applyState.buildLabel))
    end

    local appliedMessage = "Talents applied: " .. tostring(applyState.buildLabel or "Build")

    if (tonumber(applyState.levelDeferredNodes) or 0) > 0 then
        appliedMessage = appliedMessage .. string.format(
            " (level %d; %d max-level talent(s) deferred)",
            tonumber(applyState.playerLevel) or 0,
            tonumber(applyState.levelDeferredNodes) or 0
        )
    end

    PrintTalentMessage(appliedMessage)
    ClearPendingApply()
    ns._talentApplyInProgress = false
    QueueRefresh(0)
    return true
end

local function EnsureApplyFrame()
    if applyFrame then
        return
    end

    applyFrame = CreateFrame("Frame")
    applyFrame:SetScript("OnEvent", function(self, event, arg1)
        if not pendingApply then
            return
        end

        if event == "TRAIT_CONFIG_CREATED" then
            local configID = type(arg1) == "table" and arg1.ID or arg1
            local configName = type(arg1) == "table" and arg1.name or nil
            local configType = type(arg1) == "table" and arg1.type or nil

            if not configID then
                return
            end

            if not configName or not configType then
                local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID)
                configName = configName or (info and info.name)
                configType = configType or (info and info.type)
            end

            if configName and configName ~= ZOIDS_LOADOUT_NAME then
                return
            end

            if configType and Enum and Enum.TraitConfigType and configType ~= Enum.TraitConfigType.Combat then
                return
            end

            self:UnregisterEvent("TRAIT_CONFIG_CREATED")
            StoreConfigID(GetCurrentSpecID(), configID)

            local applyState = pendingApply

            RunNextFrame(function()
                ns:ApplyTalentImportString(applyState.importString, applyState.buildLabel, true)
            end)
        elseif event == "TRAIT_CONFIG_UPDATED" then
            local updatedConfigID = type(arg1) == "table" and arg1.ID or arg1
            local activeConfigID = GetActiveConfigID()
            local applyState = pendingApply

            if applyState and applyState.waitingForLoad then
                if updatedConfigID and activeConfigID and updatedConfigID ~= activeConfigID and updatedConfigID ~= applyState.loadedZoidsConfigID then
                    return
                end

                ContinuePendingApplyAfterLoad(applyState)
                return
            end

            if updatedConfigID and activeConfigID and updatedConfigID ~= activeConfigID then
                return
            end

            self:UnregisterEvent("TRAIT_CONFIG_UPDATED")

            if applyState.renameOnly then
                CompleteCommittedApply(applyState)
            else
                RunNextFrame(function()
                    ns:ApplyTalentImportString(applyState.importString, applyState.buildLabel, true)
                end)
            end
        end
    end)
end

function ns:ApplyTalentImportString(importString, buildLabel, isContinuation)
    if not importString or importString == "" then
        return FailTalentApply("This selection does not include an importable talent string.")
    end

    if pendingApply and not isContinuation then
        return nil, "Talent apply is already in progress. Wait for it to finish."
    end

    if not C_ClassTalents or not C_Traits or not ExportUtil then
        return FailTalentApply("Required talent import APIs are not available.")
    end

    local activeConfigID = GetActiveConfigID()

    if not activeConfigID then
        return FailTalentApply("No active talent loadout was found.")
    end

    if InCombatLockdown and InCombatLockdown() then
        return FailTalentApply("Cannot change talents in combat.")
    end

    local specID = GetCurrentSpecID()

    if not specID then
        return FailTalentApply("Could not determine your active specialization.")
    end

    local zoidsConfigID = GetStoredConfigID(specID)

    if not zoidsConfigID and IsZoidsTalentConfig(activeConfigID, specID) then
        StoreConfigID(specID, activeConfigID)
        zoidsConfigID = activeConfigID
    end

    if not zoidsConfigID then
        if C_ClassTalents.CanCreateNewConfig and not C_ClassTalents.CanCreateNewConfig() then
            return FailTalentApply("No free talent loadout slots. Delete one, then try again.")
        end

        if not C_ClassTalents.RequestNewConfig then
            return FailTalentApply("This game client does not support creating talent loadouts.")
        end

        EnsureApplyFrame()
        SetPendingApply({ importString = importString, buildLabel = buildLabel })
        applyFrame:RegisterEvent("TRAIT_CONFIG_CREATED")
        SecureTalentCall(C_ClassTalents.RequestNewConfig, ZOIDS_LOADOUT_NAME)
        PrintTalentMessage("Creating ZoidsTools talent loadout...")
        return true
    end

    local alreadyPreparedZoids = pendingApply and pendingApply.loadedZoidsConfigID == zoidsConfigID

    if not isContinuation and ConfigHasStagedChanges(activeConfigID) then
        local stagedChangesAreZoids = IsZoidsTalentConfig(activeConfigID, specID)
            or GetSelectedSavedConfigID(specID) == zoidsConfigID

        if stagedChangesAreZoids and RollbackTalentConfig(activeConfigID) then
            PrintTalentMessage("Discarded pending ZoidsTools talent changes.")
        else
            return FailTalentApply("You have unsaved talent changes. Apply or discard them first, then try again.")
        end
    end

    if not isContinuation and not alreadyPreparedZoids then
        EnsureApplyFrame()
        local applyState = { importString = importString, buildLabel = buildLabel, waitingForLoad = true, loadedZoidsConfigID = zoidsConfigID }
        SetPendingApply(applyState)
        applyFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")

        local result = SecureTalentCall(C_ClassTalents.LoadConfig, zoidsConfigID, true)

        if Enum and Enum.LoadConfigResult and result == Enum.LoadConfigResult.Error then
            ClearStoredConfigID(specID)
            return FailTalentApply("Could not load the ZoidsTools talent loadout. Apply or discard pending talent changes, then try again.")
        end

        if Enum and Enum.LoadConfigResult and result == Enum.LoadConfigResult.LoadInProgress then
            return true
        end

        ContinuePendingApplyAfterLoad(applyState)
        return true
    end

    activeConfigID = GetActiveConfigID()
    local treeID = GetConfigTreeID(activeConfigID)

    if not activeConfigID or not treeID then
        return FailTalentApply("Could not prepare the ZoidsTools talent loadout.")
    end

    local entryInfo, parseError = ParseTalentImportString(importString, treeID, activeConfigID)

    if not entryInfo then
        return FailTalentApply(parseError)
    end

    local originalNodeCount = 0

    for _ in pairs(entryInfo) do
        originalNodeCount = originalNodeCount + 1
    end

    if talentApplyDiagnostics.enabled then
        ResetTalentApplyDiagnosticLog()
        LogTalentApplyDiagnostic(
            "Starting build='%s' spec=%s config=%s tree=%s importLength=%d decodedNodes=%d.",
            tostring(buildLabel),
            tostring(specID),
            tostring(activeConfigID),
            tostring(treeID),
            #importString,
            originalNodeCount
        )
    end

    SetPendingApply({
        importString = importString,
        buildLabel = buildLabel,
        staging = true,
        configID = activeConfigID,
        rollbackOnTimeout = true,
    })
    ns._talentApplyInProgress = true

    ResetAndPurchaseDeferred(activeConfigID, treeID, entryInfo, function(applyResult)
        applyResult = applyResult or {}
        local levelDeferredNodes = tonumber(applyResult.levelDeferredNodes) or 0

        if not C_Traits.ConfigHasStagedChanges(activeConfigID) then
            if C_ClassTalents.RenameConfig and zoidsConfigID then
                SecureTalentCall(C_ClassTalents.RenameConfig, zoidsConfigID, BuildLoadoutName(buildLabel))
            end

            ns._talentApplyInProgress = false
            if levelDeferredNodes > 0 then
                PrintTalentMessage(string.format(
                    "Already using the available level-%d portion of this build; %d max-level talent(s) remain deferred.",
                    tonumber(applyResult.playerLevel) or 0,
                    levelDeferredNodes
                ))
            else
                PrintTalentMessage("Already using this talent build.")
            end
            ClearPendingApply()
            QueueRefresh(0)
            return
        end

        local remainingNodes = 0

        for _ in pairs(entryInfo) do
            remainingNodes = remainingNodes + 1
        end

        if remainingNodes > 0 then
            local appliedNodes = originalNodeCount - remainingNodes
            RollbackTalentConfig(activeConfigID)
            ns._talentApplyInProgress = false
            ClearPendingApply()
            PrintTalentMessage(string.format(
                "Could only stage %d of %d talent nodes. Discarded the partial build instead of saving it.",
                appliedNodes,
                originalNodeCount
            ))
            if talentApplyDiagnostics.enabled then
                PrintTalentMessage("Talent diagnostics captured. Run /zt talentdiag report.")
            end
            QueueRefresh(0)
            return
        end

        local appliedPlayerLevel = tonumber(applyResult.playerLevel) or 0
        local appliedMaxLevel = tonumber(applyResult.maxPlayerLevel) or appliedPlayerLevel
        local isMaxLevel = appliedPlayerLevel > 0 and appliedPlayerLevel >= appliedMaxLevel

        if isMaxLevel then
            local unspentParts = {}

            if C_ClassTalents.HasUnspentTalentPoints then
                local ok, hasUnspent, classPoints, specPoints = pcall(C_ClassTalents.HasUnspentTalentPoints)

                if ok and hasUnspent == true then
                    if (tonumber(classPoints) or 0) > 0 then
                        unspentParts[#unspentParts + 1] = tostring(classPoints) .. " class"
                    end
                    if (tonumber(specPoints) or 0) > 0 then
                        unspentParts[#unspentParts + 1] = tostring(specPoints) .. " specialization"
                    end
                end
            end

            if C_ClassTalents.HasUnspentHeroTalentPoints then
                local ok, hasUnspent, heroPoints = pcall(C_ClassTalents.HasUnspentHeroTalentPoints)

                if ok and hasUnspent == true and (tonumber(heroPoints) or 0) > 0 then
                    unspentParts[#unspentParts + 1] = tostring(heroPoints) .. " hero"
                end
            end

            if #unspentParts > 0 then
                RollbackTalentConfig(activeConfigID)
                ns._talentApplyInProgress = false
                ClearPendingApply()
                PrintTalentMessage(
                    "The selected build left unspent max-level points (" .. table.concat(unspentParts, ", ") .. "). " ..
                    "The partial build was discarded instead of being saved."
                )
                QueueRefresh(0)
                return
            end
        end

        if not C_ClassTalents.CommitConfig then
            RollbackTalentConfig(activeConfigID)
            ns._talentApplyInProgress = false
            ClearPendingApply()
            PrintTalentMessage("Commit failed. Discarded partial talent changes.")
            QueueRefresh(0)
            return
        end

        EnsureApplyFrame()
        local commitState = {
            buildLabel = buildLabel,
            renameOnly = true,
            levelDeferredNodes = levelDeferredNodes,
            playerLevel = applyResult.playerLevel,
            configID = zoidsConfigID,
            rollbackOnTimeout = true,
        }
        SetPendingApply(commitState)

        -- Arm the listener before committing. Some partial/level-limited builds
        -- can update immediately, and registering afterward can miss the event.
        applyFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")

        if not SecureTalentCall(C_ClassTalents.CommitConfig, zoidsConfigID) then
            applyFrame:UnregisterEvent("TRAIT_CONFIG_UPDATED")
            RollbackTalentConfig(activeConfigID)
            ns._talentApplyInProgress = false
            ClearPendingApply()
            PrintTalentMessage("Commit failed. Discarded partial talent changes.")
            QueueRefresh(0)
            return
        end

        if C_ClassTalents.UpdateLastSelectedSavedConfigID then
            RememberSavedConfigID(specID, zoidsConfigID)
        end

        -- If the update event was synchronous or omitted, poll the committed
        -- state briefly instead of leaving the talent UI locked indefinitely.
        if C_Timer and C_Timer.After then
            local checksRemaining = 20
            local function VerifyCommitCompleted()
                if pendingApply ~= commitState then
                    return
                end

                if not ConfigHasStagedChanges(zoidsConfigID) then
                    CompleteCommittedApply(commitState)
                    return
                end

                checksRemaining = checksRemaining - 1
                if checksRemaining > 0 then
                    C_Timer.After(0.25, VerifyCommitCompleted)
                end
            end

            C_Timer.After(0.25, VerifyCommitCompleted)
        end
    end)

    return true
end

local function RequestSpecializationSwitch(specIndex, specName)
    if InCombatLockdown and InCombatLockdown() then
        return nil, "Cannot switch specializations in combat."
    end

    if ns._talentApplyInProgress then
        return nil, "Wait for the current talent build to finish applying before switching specializations."
    end

    specIndex = tonumber(specIndex)
    specName = tostring(specName or "the selected specialization")

    local activeSpecIndex = C_SpecializationInfo
        and C_SpecializationInfo.GetSpecialization
        and C_SpecializationInfo.GetSpecialization()
        or (GetSpecialization and GetSpecialization())

    if specIndex and activeSpecIndex == specIndex then
        return true
    end

    local setter = C_SpecializationInfo and C_SpecializationInfo.SetSpecialization

    if not specIndex or type(setter) ~= "function" then
        return nil, "The game does not currently provide a specialization switch for " .. specName .. "."
    end

    local result = SecureTalentCall(setter, specIndex)
    if result == false then
        return nil, "The game could not switch to " .. specName .. " right now."
    end

    PrintTalentMessage("Switching to " .. specName .. ".")
    return true
end

local function RequestAlternateSpecialization(context)
    if not context or not context.requiresSpecSwitch then
        return nil, "No alternate specialization is selected."
    end

    return RequestSpecializationSwitch(context.alternateSpecIndex, GetSpecLabel(context.specKey))
end

function ns:ApplyTalentGrimoireCurrentBuild()
    local entry, context = GetBuildEntry()
    local importString = entry and entry.importString or ""

    if entry and context and context.requiresSpecSwitch then
        local switched, switchError = RequestAlternateSpecialization(context)
        if not switched and switchError then
            PrintTalentMessage(switchError)
        end
        return switched, switchError
    end

    if importString == "" then
        local sourceValue = entry and entry.sourceUrl or ""

        if sourceValue ~= "" then
            PrintTalentMessage("This selection only has a source link, not an importable talent string.")
        else
            PrintTalentMessage("No talent build is available for this selection.")
        end

        return nil
    end

    local ok, errorMessage = ns:ApplyTalentImportString(importString, BuildTalentLabel(context))

    if not ok and errorMessage then
        PrintTalentMessage(errorMessage)
    end

    return ok, errorMessage
end

local function NormalizeDungeonName(value)
    value = tostring(value or "")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
    value = value:gsub("|r", "")
    value = string.lower(value)
    value = value:gsub("&", "and")
    value = value:gsub("[^%w]+", "")
    return value
end

local function GetCurrentDungeonTarget()
    if not IsInInstance or not GetInstanceInfo then
        return nil
    end

    local inInstance, instanceType = IsInInstance()

    if not inInstance or instanceType ~= "party" then
        return nil
    end

    local instanceName, _, _, _, _, _, _, instanceID = GetInstanceInfo()

    if not instanceName or instanceName == "" then
        return nil
    end

    local root = GetRoot()
    local specData = GetCurrentSpecData()
    local labels = {}

    if root and root.targets and root.targets.mythicplus then
        for targetKey, label in pairs(root.targets.mythicplus) do
            labels[targetKey] = label
        end
    end

    if specData and specData.mythicplus then
        for targetKey, targetData in pairs(specData.mythicplus) do
            if type(targetData) == "table" then
                labels[targetKey] = targetData.label or labels[targetKey] or targetKey
            end
        end
    end

    local normalizedInstanceName = NormalizeDungeonName(instanceName)

    for targetKey, label in pairs(labels) do
        if targetKey ~= "all-dungeons" and NormalizeDungeonName(label) == normalizedInstanceName then
            return targetKey, label, instanceName, instanceID
        end
    end

    return nil
end

local function GetDungeonTalentRecommendation()
    local targetKey, targetLabel, instanceName, instanceID = GetCurrentDungeonTarget()

    if not targetKey then
        return nil
    end

    local mode = GetModeKey("mythicplus")
    local entry, context = GetBuildEntryForTarget("mythicplus", targetKey, mode)
    local importString = entry and entry.importString or ""

    if importString == "" then
        return nil
    end

    return {
        entry = entry,
        context = context,
        importString = importString,
        targetKey = targetKey,
        targetLabel = targetLabel or context.targetLabel or instanceName,
        instanceName = instanceName,
        instanceID = instanceID,
        mode = mode,
        modeLabel = context.modeLabel or GetOptionText(GetModeOptions("mythicplus"), mode),
        buildLabel = BuildTalentLabel(context),
    }
end

local function EnsureDungeonPromptDialog()
    if not StaticPopupDialogs or StaticPopupDialogs[DUNGEON_PROMPT_DIALOG] then
        return
    end

    StaticPopupDialogs[DUNGEON_PROMPT_DIALOG] = {
        text = "ZoidsTools recommends the %s build for %s. Apply it now?",
        button1 = "Apply",
        button2 = "Not now",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function(_, data)
            if not data or not data.importString then
                return
            end

            local db = EnsureDB()

            if db then
                db.contentType = "mythicplus"
                db.mythicPlusMode = data.mode
                db.mythicPlusTarget = data.targetKey
                db.mode = data.mode
            end

            QueueRefresh(0)

            local ok, errorMessage = ns:ApplyTalentImportString(data.importString, data.buildLabel)

            if not ok and errorMessage then
                PrintTalentMessage(errorMessage)
            end
        end,
    }
end

local function CheckDungeonTalentPrompt()
    local db = EnsureDB()

    if not db or db.enabled ~= true then
        return
    end

    local inInstance = IsInInstance and IsInInstance()

    if not inInstance then
        lastDungeonZoneSignature = nil
        lastDungeonPromptSignature = nil
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        return
    end

    local recommendation = GetDungeonTalentRecommendation()

    if not recommendation then
        return
    end

    if TalentImportMatchesActive(recommendation.importString) then
        return
    end

    local _, _, specKey = GetCurrentSpecData()
    local zoneSignature = table.concat({
        tostring(recommendation.instanceID or recommendation.instanceName or ""),
        tostring(specKey or ""),
        tostring(recommendation.targetKey or ""),
        tostring(recommendation.mode or ""),
    }, "|")

    if lastDungeonZoneSignature ~= zoneSignature then
        lastDungeonZoneSignature = zoneSignature
        lastDungeonPromptSignature = nil
    end

    local promptSignature = zoneSignature .. "|" .. tostring(recommendation.importString)

    if lastDungeonPromptSignature == promptSignature then
        return
    end

    lastDungeonPromptSignature = promptSignature
    EnsureDungeonPromptDialog()

    if StaticPopup_Show then
        StaticPopup_Show(
            DUNGEON_PROMPT_DIALOG,
            recommendation.modeLabel or "Mythic+",
            recommendation.targetLabel or recommendation.instanceName or "this dungeon",
            recommendation
        )
    end
end

local function QueueDungeonTalentPromptCheck(delay)
    if dungeonPromptQueued then
        return
    end

    dungeonPromptQueued = true

    local function Run()
        dungeonPromptQueued = false
        CheckDungeonTalentPrompt()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 1, Run)
    else
        Run()
    end
end

local function SelectNextOption(options, currentValue)
    if #options == 0 then
        return currentValue
    end

    for index, option in ipairs(options) do
        if option.value == currentValue then
            local nextOption = options[index + 1] or options[1]
            return nextOption.value
        end
    end

    return options[1].value
end

local function IsTalentsTabActive()
    local playerSpells = _G.PlayerSpellsFrame

    if not playerSpells then
        return true
    end

    if playerSpells.IsFrameTabActive and _G.PlayerSpellsUtil and _G.PlayerSpellsUtil.FrameTabs then
        local tab = _G.PlayerSpellsUtil.FrameTabs.ClassTalents

        if tab then
            local ok, active = pcall(playerSpells.IsFrameTabActive, playerSpells, tab)

            if ok then
                -- This has returned both a boolean and a truthy enum/value in
                -- different PlayerSpells revisions. Treat every truthy result
                -- as active instead of requiring the literal boolean true.
                return not not active
            end
        end
    end

    local talents = playerSpells.TalentsFrame or playerSpells.TalentFrame or playerSpells.ClassTalentFrame
    return not talents or not talents.IsShown or talents:IsShown()
end

local function FindTalentFrame()
    local playerSpells = _G.PlayerSpellsFrame

    if playerSpells and playerSpells.IsShown and playerSpells:IsShown() then
        local talents = playerSpells.TalentsFrame or playerSpells.TalentFrame or playerSpells.ClassTalentFrame

        -- The final saved loadout can be deleted while this window remains
        -- open. Blizzard then swaps to its special Default Loadout state and
        -- may briefly report no active tab/config even though the talent tree
        -- itself is still visible. Prefer the visible child frame as the
        -- authoritative signal so the ZoidsTools controls do not disappear.
        if talents and (not talents.IsShown or talents:IsShown()) then
            return talents
        end

        if IsTalentsTabActive() then
            return talents or playerSpells
        end
    end

    for _, frame in ipairs({
        _G.ClassTalentFrame,
        _G.PlayerTalentFrame,
        _G.TalentFrame,
    }) do
        if frame and frame.IsShown and frame:IsShown() then
            return frame
        end
    end

    return nil
end

local function GetTalentPanelHost(talentFrame)
    -- ButtonsParent ends at the top of Blizzard's bottom loadout bar, which is
    -- the intended baseline for the ZoidsTools controls. Fall back to the
    -- visible talent-content frame, never the outer PlayerSpells window whose
    -- bottom edge includes the loadout bar and page tabs.
    if talentFrame and talentFrame.ButtonsParent then
        return talentFrame.ButtonsParent
    end

    return talentFrame
end

local function ClearTalentChecks()
    for button in pairs(checkedTalentButtons) do
        if button and button._ztGrimoireCheck then
            button._ztGrimoireCheck:Hide()
        end

        if button and button._ztGrimoireRemoveMark then
            button._ztGrimoireRemoveMark:Hide()
        end

        checkedTalentButtons[button] = nil
    end
end

local function GetTalentButtonForNode(talentFrame, nodeID)
    if not talentFrame or not nodeID then
        return nil
    end

    if talentFrame.GetTalentButtonByNodeID then
        local ok, button = pcall(talentFrame.GetTalentButtonByNodeID, talentFrame, nodeID)

        if ok and button then
            return button
        end
    end

    return nil
end

local function GetOrCreateTalentCheck(button)
    if not button or not button.CreateTexture then
        return nil
    end

    local check = button._ztGrimoireCheck

    if check then
        return check
    end

    check = button:CreateTexture(nil, "OVERLAY", nil, 7)
    check:SetSize(18, 18)
    check:SetDrawLayer("OVERLAY", 7)

    local atlasOK = check.SetAtlas and pcall(check.SetAtlas, check, "common-icon-checkmark")

    if not atlasOK then
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end

    check:Hide()
    button._ztGrimoireCheck = check

    return check
end

local function GetOrCreateTalentRemoveMark(button)
    if not button or not button.CreateFontString then
        return nil
    end

    local mark = button._ztGrimoireRemoveMark

    if mark then
        return mark
    end

    mark = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    mark:SetText("X")
    mark:SetTextColor(1, 0.08, 0.08, 1)
    mark:SetShadowColor(0, 0, 0, 1)
    mark:SetShadowOffset(1, -1)
    mark:SetScale(1.45)
    mark:Hide()
    button._ztGrimoireRemoveMark = mark

    return mark
end

local function ShowTalentCheck(button, color)
    local check = GetOrCreateTalentCheck(button)

    if not check then
        return
    end

    color = color or TALENT_MATCH_COLOR
    check:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    check:ClearAllPoints()
    check:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2, 2)
    check:Show()
    checkedTalentButtons[button] = true
end

local function ShowTalentRemoveMark(button)
    local mark = GetOrCreateTalentRemoveMark(button)

    if not mark then
        return
    end

    mark:ClearAllPoints()
    mark:SetPoint("CENTER", button, "CENTER", 0, 0)
    mark:Show()
    checkedTalentButtons[button] = true
end

local function TalentEntriesMatch(activeEntry, desiredEntry)
    if not activeEntry or not desiredEntry then
        return false
    end

    if (activeEntry.ranksPurchased or 0) ~= (desiredEntry.ranksPurchased or 0) then
        return false
    end

    if activeEntry.isChoiceNode or desiredEntry.isChoiceNode then
        return activeEntry.selectionEntryID == desiredEntry.selectionEntryID
    end

    return true
end

local function TalentEntryChoiceMatches(activeEntry, desiredEntry)
    if not activeEntry or not desiredEntry then
        return false
    end

    if activeEntry.isChoiceNode or desiredEntry.isChoiceNode then
        return activeEntry.selectionEntryID == desiredEntry.selectionEntryID
    end

    return true
end

local function TalentEntryNeedsPendingCheck(activeEntry, desiredEntry)
    if not desiredEntry then
        return false
    end

    if not activeEntry then
        return true
    end

    if not TalentEntryChoiceMatches(activeEntry, desiredEntry) then
        return true
    end

    return (desiredEntry.ranksPurchased or 0) > (activeEntry.ranksPurchased or 0)
end

local function TalentEntryNeedsRemoveMark(activeEntry, desiredEntry)
    if not activeEntry then
        return false
    end

    if not desiredEntry then
        return true
    end

    if not TalentEntryChoiceMatches(activeEntry, desiredEntry) then
        return true
    end

    return (activeEntry.ranksPurchased or 0) > (desiredEntry.ranksPurchased or 0)
end

local function GetActiveTalentEntryInfo(configID, treeID)
    if not C_Traits or not C_Traits.GenerateImportString then
        return nil
    end

    local ok, importString = pcall(C_Traits.GenerateImportString, configID)

    if not ok or not importString then
        return nil
    end

    return ParseTalentImportString(importString, treeID, configID)
end

local function RefreshTalentCheckOverlays()
    ClearTalentChecks()

    local db = EnsureDB()

    if not db or db.enabled ~= true then
        return
    end

    local talentFrame = FindTalentFrame()

    if not talentFrame then
        return
    end

    local entry = GetBuildEntry()
    local importString = entry and entry.importString or ""

    if importString == "" then
        return
    end

    local configID = GetActiveConfigID()
    local treeID = GetConfigTreeID(configID)

    if not configID or not treeID then
        return
    end

    local entryInfo = ParseTalentImportString(importString, treeID, configID)

    if not entryInfo then
        return
    end

    local activeEntryInfo = GetActiveTalentEntryInfo(configID, treeID)

    if not activeEntryInfo then
        for nodeID in pairs(entryInfo) do
            ShowTalentCheck(GetTalentButtonForNode(talentFrame, nodeID), TALENT_MATCH_COLOR)
        end

        return
    end

    for nodeID, desiredEntry in pairs(entryInfo) do
        local activeEntry = activeEntryInfo[nodeID]
        local button = GetTalentButtonForNode(talentFrame, nodeID)

        if TalentEntriesMatch(activeEntry, desiredEntry) then
            ShowTalentCheck(button, TALENT_MATCH_COLOR)
        elseif TalentEntryNeedsPendingCheck(activeEntry, desiredEntry) then
            ShowTalentCheck(button, TALENT_PENDING_COLOR)
        end
    end

    for nodeID, activeEntry in pairs(activeEntryInfo) do
        if TalentEntryNeedsRemoveMark(activeEntry, entryInfo[nodeID]) then
            ShowTalentRemoveMark(GetTalentButtonForNode(talentFrame, nodeID))
        end
    end
end

local function QueueTalentCheckRefresh(delay)
    if talentCheckRefreshQueued then
        return
    end

    talentCheckRefreshQueued = true

    local function Run()
        if ns.RecordDiagnosticActivity then ns:RecordDiagnosticActivity("TalentGrimoire.OverlayRefresh") end
        talentCheckRefreshQueued = false
        RefreshTalentCheckOverlays()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.05, Run)
    else
        Run()
    end
end

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 100, 24)
    button:SetText(text)
    return button
end

local function CreateOptionDropdown(name, parent, width)
    local ok, dropdown = pcall(CreateFrame, "DropdownButton", name, parent, "WowStyle1DropdownTemplate")

    if ok and dropdown and dropdown.SetupMenu then
        dropdown:SetSize(width or 140, 26)
        dropdown._options = {}
        dropdown._current = nil
        dropdown._onSelect = nil
        dropdown:SetupMenu(function(_, rootDescription)
            for _, option in ipairs(dropdown._options or {}) do
                local label = option.displayText or option.text or option.label or tostring(option.value or "")
                local value = option.value
                local description = rootDescription:CreateRadio(
                    label,
                    function()
                        return value == dropdown._current
                    end,
                    function()
                        if dropdown._onSelect then
                            dropdown._onSelect(value)
                        end
                    end
                )

                SetMenuDescriptionTextColor(description, option.textColor)
            end
        end)

        function dropdown:SetOptions(options, currentValue, onSelect)
            self._options = options or {}
            self._current = currentValue
            self._onSelect = onSelect
            self:SetDefaultText(GetOptionDisplayText(self._options, currentValue))
            SetDropdownTextColor(self, GetOptionTextColor(self._options, currentValue))

            if self.GenerateMenu then
                self:GenerateMenu()
            end
        end

        return dropdown
    end

    dropdown = CreateButton(parent, "", width or 140)
    dropdown._options = {}
    dropdown._current = nil
    dropdown._onSelect = nil
    dropdown:SetScript("OnClick", function(self)
        if self._onSelect then
            self._onSelect(SelectNextOption(self._options or {}, self._current))
        end
    end)

    function dropdown:SetOptions(options, currentValue, onSelect)
        self._options = options or {}
        self._current = currentValue
        self._onSelect = onSelect
        self:SetText(GetOptionDisplayText(self._options, currentValue))
        SetDropdownTextColor(self, GetOptionTextColor(self._options, currentValue))
    end

    return dropdown
end

local function CreateImportPopup(parent)
    local popup = CreateFrame("Frame", "ZoidsToolsTalentGrimoireImportPopup", UIParent, "BackdropTemplate")
    popup:SetSize(520, 54)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    popup:SetBackdropColor(0.02, 0.02, 0.025, 0.98)
    popup:SetBackdropBorderColor(0.85, 0.7, 0.38, 0.65)
    popup:EnableMouse(true)
    popup:SetClampedToScreen(true)

    popup.editBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    popup.editBox:SetPoint("LEFT", popup, "LEFT", 12, 0)
    popup.editBox:SetPoint("RIGHT", popup, "RIGHT", -12, 0)
    popup.editBox:SetHeight(24)
    popup.editBox:SetAutoFocus(false)
    popup.editBox:SetFontObject("GameFontHighlightSmall")
    popup.editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        popup:Hide()
    end)

    popup:Hide()
    parent.importPopup = popup
end

local function ShowCopyPopup(copyValue, anchorFrame)
    if not panel or not panel.importPopup or copyValue == "" then
        return
    end

    panel.importPopup:ClearAllPoints()
    panel.importPopup:SetPoint("BOTTOM", anchorFrame or panel, "TOP", 0, 6)
    panel.importPopup.editBox:SetText(copyValue)
    panel.importPopup.editBox:SetCursorPosition(0)
    panel.importPopup:Show()
    panel.importPopup.editBox:SetFocus()
    panel.importPopup.editBox:HighlightText()
end

local function GetRotationSpellTexture(spellId)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellId)
        if ok and texture then
            return texture
        end
    end

    return 134400
end

local function GetPreferredRotationSectionIndex(sections, contentType)
    local preferredKinds

    if contentType == "mythicplus" then
        preferredKinds = { dungeon = 1, aoe = 2, priority = 3, single = 4, opener = 5 }
    elseif contentType == "raid" then
        preferredKinds = { raid = 1, single = 2, priority = 3, opener = 4, aoe = 5 }
    else
        preferredKinds = { single = 1, priority = 2, opener = 3, aoe = 4, dungeon = 5, raid = 6 }
    end

    local bestIndex = 1
    local bestOrder = math.huge

    for index, section in ipairs(sections or {}) do
        local order = preferredKinds[section.kind] or 50
        if order < bestOrder then
            bestIndex = index
            bestOrder = order
        end
    end

    return bestIndex
end

local function NormalizeRotationVariantText(value)
    return tostring(value or ""):lower():gsub("[^%w]+", "")
end

local function GetPreferredRotationVariant(rotation, context, contentType)
    local variants = type(rotation) == "table" and rotation.variants
    if type(variants) ~= "table" or #variants == 0 then
        return nil
    end

    local desiredHeroTree = type(context) == "table" and context.heroTree or nil
    local desiredHeroKey = NormalizeRotationVariantText(desiredHeroTree)
    local buildTitleKey = NormalizeRotationVariantText(type(context) == "table" and context.buildTitle or nil)

    if desiredHeroKey == "" and buildTitleKey ~= "" then
        for _, variant in ipairs(variants) do
            local heroKey = NormalizeRotationVariantText(variant.heroTree)
            if heroKey ~= "" and buildTitleKey:find(heroKey, 1, true) then
                desiredHeroKey = heroKey
                break
            end
        end
    end

    local scenarioOrder
    if contentType == "mythicplus" then
        scenarioOrder = { aoe = 100, dungeon = 90, priority = 70, single = 20 }
    elseif contentType == "raid" then
        scenarioOrder = { single = 100, raid = 90, priority = 70, aoe = 20 }
    else
        scenarioOrder = { single = 100, priority = 80, aoe = 60, dungeon = 50, raid = 50 }
    end

    local bestVariant
    local bestScore = -math.huge

    for _, variant in ipairs(variants) do
        local score = scenarioOrder[variant.scenario] or 0
        local heroKey = NormalizeRotationVariantText(variant.heroTree)

        if desiredHeroKey ~= "" then
            if heroKey == desiredHeroKey then
                score = score + 1000
            else
                score = score - 1000
            end
        end

        if variant.recommended == true then
            score = score + 10
        end
        if variant.selected == true then
            score = score + 1
        end

        local hasSections = type(variant.sections) == "table" and #variant.sections > 0
        local hasConditionalSections = type(rotation.conditionalSections) == "table" and #rotation.conditionalSections > 0
        if (hasSections or hasConditionalSections) and score > bestScore then
            bestVariant = variant
            bestScore = score
        end
    end

    return bestVariant
end

local function RotationStepMatchesVariant(step, enabledStates)
    local conditions = type(step) == "table" and step.conditions
    if type(conditions) ~= "table" or #conditions == 0 then
        return true
    end

    local matched = 0
    for _, condition in ipairs(conditions) do
        local key
        local expected
        if type(condition) == "string" then
            key, expected = condition:match("^(.*):(%a+)$")
        elseif type(condition) == "table" then
            key = condition.key
            expected = condition.state
        end

        local actual = enabledStates[key] and "on" or "off"
        if key and actual == expected then
            matched = matched + 1
        end
    end

    if step.logic == "OR" then
        return matched > 0
    end

    return matched == #conditions
end

local function GetRotationSectionsForVariant(rotation, variant)
    if type(variant) ~= "table" then
        return type(rotation) == "table" and rotation.sections or {}
    end

    if type(variant.sections) == "table" and #variant.sections > 0 then
        return variant.sections
    end

    if type(rotation.conditionalSections) ~= "table" or #rotation.conditionalSections == 0 then
        return rotation.sections or {}
    end

    local sections = {}
    local enabledStates = {}
    for _, token in ipairs(variant.stateTokens or {}) do
        enabledStates[token] = true
    end

    for _, rawSection in ipairs(rotation.conditionalSections) do
        local section = {
            key = rawSection.key,
            label = rawSection.label,
            kind = rawSection.kind,
            steps = {},
        }
        for _, step in ipairs(rawSection.steps or {}) do
            if RotationStepMatchesVariant(step, enabledStates) then
                section.steps[#section.steps + 1] = step
            end
        end

        if #section.steps > 0 then
            sections[#sections + 1] = section
        end
    end

    return sections
end

local function CreateRotationRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROTATION_ROW_MIN_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.08, 0.075, 0.065, index % 2 == 0 and 0.52 or 0.34)

    row.number = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.number:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.number:SetWidth(24)
    row.number:SetJustifyH("RIGHT")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26)
    row.icon:SetPoint("LEFT", row.number, "RIGHT", 7, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 9, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetJustifyV("MIDDLE")
    row.name:SetWordWrap(true)

    row:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local shown = false

        if self.spellId and GameTooltip.SetSpellByID then
            shown = pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellId)
        end

        if not shown then
            GameTooltip:SetText(self.spellName or "Rotation ability", 1, 0.82, 0.2)
        end

        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    return row
end

local RefreshRotationPopup

local function SaveRotationPopupPosition(popup)
    local db = EnsureDB()
    if not db or not popup then
        return
    end

    local point, _, relativePoint, x, y = popup:GetPoint(1)
    db.rotationWindow = db.rotationWindow or {}
    db.rotationWindow.point = point or "CENTER"
    db.rotationWindow.relativePoint = relativePoint or point or "CENTER"
    db.rotationWindow.x = x or 0
    db.rotationWindow.y = y or 0
end

local function RestoreRotationPopupPosition(popup)
    local db = EnsureDB()
    local position = db and db.rotationWindow or nil

    popup:ClearAllPoints()
    popup:SetPoint(
        position and position.point or "CENTER",
        UIParent,
        position and position.relativePoint or "CENTER",
        position and tonumber(position.x) or -360,
        position and tonumber(position.y) or 0
    )
end

local function CreateRotationPopup()
    local popup = CreateFrame("Frame", "ZoidsToolsTalentRotationPopup", UIParent, "BackdropTemplate")
    popup:SetSize(ROTATION_PANEL_WIDTH, ROTATION_PANEL_HEIGHT)
    popup:SetFrameStrata("DIALOG")
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    popup:SetBackdropColor(0.02, 0.018, 0.014, 0.98)
    popup:SetBackdropBorderColor(0.72, 0.57, 0.22, 0.9)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    popup:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveRotationPopupPosition(self)
    end)
    RestoreRotationPopupPosition(popup)

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.title:SetPoint("TOPLEFT", popup, "TOPLEFT", 14, -13)
    popup.title:SetTextColor(1, 0.82, 0.2)

    popup.closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    popup.closeButton:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -2)
    popup.closeButton:SetScript("OnClick", function()
        popup:Hide()
    end)

    popup.subtitle = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.subtitle:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -3)
    popup.subtitle:SetPoint("RIGHT", popup, "RIGHT", -38, 0)
    popup.subtitle:SetJustifyH("LEFT")
    popup.subtitle:SetTextColor(0.72, 0.76, 0.82)

    popup.sectionDropdown = CreateOptionDropdown("ZoidsToolsTalentRotationSectionDropdown", popup, 210)
    popup.sectionDropdown:SetPoint("TOPLEFT", popup.subtitle, "BOTTOMLEFT", -2, -10)

    popup.sourceButton = CreateButton(popup, "Source", 72)
    popup.sourceButton:SetPoint("LEFT", popup.sectionDropdown, "RIGHT", 8, 0)
    popup.sourceButton:SetScript("OnClick", function()
        if popup.sourceUrl and popup.sourceUrl ~= "" then
            ShowCopyPopup(popup.sourceUrl, popup)
        end
    end)

    popup.scroll = CreateFrame("ScrollFrame", "ZoidsToolsTalentRotationScrollFrame", popup, "UIPanelScrollFrameTemplate")
    popup.scroll:SetPoint("TOPLEFT", popup.sectionDropdown, "BOTTOMLEFT", 2, -10)
    popup.scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -30, 42)

    popup.content = CreateFrame("Frame", nil, popup.scroll)
    popup.content:SetSize(ROTATION_PANEL_WIDTH - 50, 1)
    popup.scroll:SetScrollChild(popup.content)
    popup.rows = {}

    popup.footer = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popup.footer:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 14, 14)
    popup.footer:SetPoint("RIGHT", popup, "RIGHT", -14, 0)
    popup.footer:SetJustifyH("LEFT")
    popup.footer:SetText("Drag the window to move it. Static priority reference; it does not recommend abilities live.")

    popup:Hide()
    if UISpecialFrames then
        local alreadyRegistered = false
        for _, frameName in ipairs(UISpecialFrames) do
            if frameName == "ZoidsToolsTalentRotationPopup" then
                alreadyRegistered = true
                break
            end
        end
        if not alreadyRegistered then
            UISpecialFrames[#UISpecialFrames + 1] = "ZoidsToolsTalentRotationPopup"
        end
    end
    return popup
end

local function RefreshRotationRows(popup, section)
    for _, row in ipairs(popup.rows) do
        row:Hide()
    end

    local steps = type(section) == "table" and section.steps or {}

    local visibleCount = 0
    local yOffset = 0

    for _, step in ipairs(steps) do
        local spellId = tonumber(step.spellId)
        visibleCount = visibleCount + 1

        local row = popup.rows[visibleCount]
        if not row then
            row = CreateRotationRow(popup.content, visibleCount)
            row:SetPoint("RIGHT", popup.content, "RIGHT", 0, 0)
            popup.rows[visibleCount] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", popup.content, "TOPLEFT", 0, -yOffset)
        row:SetPoint("RIGHT", popup.content, "RIGHT", 0, 0)
        row.spellId = spellId
        row.spellName = step.name
        row.number:SetText(visibleCount .. ".")
        row.icon:SetTexture(GetRotationSpellTexture(row.spellId))
        row.name:SetText(step.text or step.name or ("Spell " .. tostring(row.spellId or "")))

        local textHeight = tonumber(row.name:GetStringHeight()) or 0
        local rowHeight = math.max(ROTATION_ROW_MIN_HEIGHT, math.ceil(textHeight) + 12)
        row:SetHeight(rowHeight)
        row:Show()
        yOffset = yOffset + rowHeight
    end

    popup.content:SetHeight(math.max(1, yOffset))
    popup.scroll:SetVerticalScroll(0)
end

RefreshRotationPopup = function(resetSection)
    if not panel or not panel.rotationPopup then
        return
    end

    local popup = panel.rotationPopup
    local rotation, classToken, specKey = GetCurrentRotationData(panel.rotationContext)

    if not rotation then
        popup:Hide()
        return
    end

    local db = EnsureDB()
    local contentType = db and db.contentType or "mythicplus"
    local variant = GetPreferredRotationVariant(rotation, panel.rotationContext, contentType)
    local sections = GetRotationSectionsForVariant(rotation, variant)
    local signature = table.concat({
        tostring(classToken),
        tostring(specKey),
        tostring(contentType),
        tostring(variant and variant.key or "default"),
    }, ":")

    if resetSection or popup.rotationSignature ~= signature or not sections[popup.sectionIndex or 0] then
        popup.sectionIndex = GetPreferredRotationSectionIndex(sections, contentType)
    end

    popup.rotationSignature = signature
    popup.sourceUrl = rotation.sourceUrl
    popup.title:SetText(GetSpecLabel(specKey) .. " Rotation")
    local subtitleParts = {
        rotation.source or "Rotation reference",
        GetOptionText(CONTENT_OPTIONS, contentType),
    }
    if variant and variant.heroTree and variant.heroTree ~= "" then
        subtitleParts[#subtitleParts + 1] = variant.heroTree
    end
    if variant and variant.scenarioLabel and variant.scenarioLabel ~= "" then
        subtitleParts[#subtitleParts + 1] = variant.scenarioLabel
    end
    popup.subtitle:SetText(table.concat(subtitleParts, "  |  "))
    if variant then
        popup.footer:SetText("Drag to move. Static reference for the selected build; the source may open on its default hero-tree selection.")
    else
        popup.footer:SetText("Drag to move. Static priority reference; it does not read combat or recommend abilities live.")
    end

    local options = {}
    for index, section in ipairs(sections) do
        options[#options + 1] = {
            value = index,
            text = section.label or ("Section " .. index),
        }
    end

    popup.sectionDropdown:SetOptions(options, popup.sectionIndex, function(value)
        popup.sectionIndex = value
        RefreshRotationPopup(false)
    end)
    popup.sourceButton:SetEnabled(type(rotation.sourceUrl) == "string" and rotation.sourceUrl ~= "")
    popup.sourceButton:SetAlpha(type(rotation.sourceUrl) == "string" and rotation.sourceUrl ~= "" and 1 or 0.45)
    RefreshRotationRows(popup, sections[popup.sectionIndex])
end

local function GetPlayerSpecializationInfo(specIndex)
    local getter = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo

    if type(getter) ~= "function" then
        return nil
    end

    local ok, specID, name, description, icon = pcall(getter, specIndex)

    if not ok or not specID then
        return nil
    end

    return specID, name, description, icon
end

local function GetPlayerSpecializationCount()
    local _, _, classID = UnitClass("player")
    local count

    if classID and C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
        local ok, value = pcall(C_SpecializationInfo.GetNumSpecializationsForClassID, classID)
        if ok then count = value end
    elseif GetNumSpecializations then
        local ok, value = pcall(GetNumSpecializations, false, false)
        if ok then count = value end
    end

    count = tonumber(count) or 0
    return math.min(MAX_CLASS_SPECIALIZATIONS, math.max(0, count))
end

local function GetActiveSpecializationIndex()
    local getter = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization

    if type(getter) ~= "function" then
        return nil
    end

    local ok, specIndex = pcall(getter)
    return ok and tonumber(specIndex) or nil
end

local function CreateSpecializationButton(parent, index)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(SPEC_BUTTON_SIZE, SPEC_BUTTON_SIZE)
    button:SetBackdrop({
        bgFile = SOLID_TEXTURE,
        edgeFile = SOLID_TEXTURE,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(0.025, 0.025, 0.025, 0.92)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.selection = button:CreateTexture(nil, "OVERLAY")
    button.selection:SetAllPoints(button.icon)
    button.selection:SetColorTexture(1, 0.82, 0.16, 0.22)
    button.selection:SetBlendMode("ADD")
    button.selection:Hide()

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints(button.icon)
    button.highlight:SetColorTexture(1, 1, 1, 0.16)

    if index == 1 then
        button:SetPoint("LEFT", parent, "RIGHT", SPEC_BUTTON_OFFSET_X, 0)
    else
        button:SetPoint("LEFT", parent.specButtons[index - 1], "RIGHT", SPEC_BUTTON_GAP, 0)
    end

    button:SetScript("OnClick", function(self)
        if self.isActive or not self.specIndex then
            return
        end

        local switched, switchError = RequestSpecializationSwitch(self.specIndex, self.specName)
        if not switched and switchError then
            PrintTalentMessage(switchError)
        end
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip or not self.specName then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.specName, 1, 0.82, 0.2)

        if self.isActive then
            GameTooltip:AddLine("Current specialization", 0.56, 0.86, 0.56)
        elseif InCombatLockdown and InCombatLockdown() then
            GameTooltip:AddLine("Specializations cannot be changed in combat.", 1, 0.35, 0.25, true)
        else
            GameTooltip:AddLine("Click to switch specialization without leaving the Talents page.", 1, 1, 1, true)
        end

        if self.specDescription and self.specDescription ~= "" then
            GameTooltip:AddLine(self.specDescription, 0.72, 0.76, 0.82, true)
        end

        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    return button
end

local function RefreshSpecializationButtons(readOnly)
    if not panel or not panel.specButtons then
        return
    end

    local activeSpecIndex = GetActiveSpecializationIndex()
    local specCount = GetPlayerSpecializationCount()

    for index, button in ipairs(panel.specButtons) do
        if index <= specCount then
            local specID, name, description, icon = GetPlayerSpecializationInfo(index)

            if specID then
                button.specIndex = index
                button.specID = specID
                button.specName = name or ("Specialization " .. index)
                button.specDescription = description
                button.isActive = index == activeSpecIndex
                button.icon:SetTexture(icon or 134400)
                button.selection:SetShown(button.isActive)
                button:SetBackdropBorderColor(
                    button.isActive and 1 or 0.35,
                    button.isActive and 0.82 or 0.35,
                    button.isActive and 0.16 or 0.35,
                    button.isActive and 1 or 0.9
                )
                button:SetEnabled(readOnly ~= true)
                button:SetAlpha(readOnly and 0.5 or (button.isActive and 1 or 0.88))
                button:Show()
            else
                button:Hide()
            end
        else
            button:Hide()
        end
    end
end

local function RefreshPanel()
    if not panel then
        return
    end

    for _, dropdown in ipairs({
        panel.providerDropdown,
        panel.contentDropdown,
        panel.modeDropdown,
        panel.targetDropdown,
    }) do
        if dropdown and dropdown.SetEnabled then
            dropdown:SetEnabled(true)
            dropdown:SetAlpha(1)
        end
    end

    local entry, context = GetBuildEntry()
    local contentType = context.contentType or "mythicplus"
    local mode = context.mode or GetModeKey(contentType)
    local targetKey = context.targetKey or GetTargetKey(contentType)
    local importString = entry and entry.importString or ""
    local copyValue = importString ~= "" and importString or (entry and entry.sourceUrl or "")
    local targetOptions = GetTargetDropdownOptions(contentType, mode, targetKey)
    local rotation = GetCurrentRotationData(context)
    panel.rotationContext = context
    RefreshSpecializationButtons(false)

    panel.providerDropdown:SetOptions(GetProviderOptions(), GetProviderKey(), function(value)
        ns:SetTalentGrimoireProvider(value)
    end)
    panel.contentDropdown:SetOptions(GetContentOptions(), contentType, function(value)
        ns:SetTalentGrimoireContentType(value)
    end)
    panel.modeDropdown:SetOptions(GetModeOptions(contentType, targetKey), mode, function(value)
        ns:SetTalentGrimoireMode(value)
    end)
    panel.targetDropdown:SetOptions(targetOptions, targetKey, function(value)
        ns:SetTalentGrimoireTarget(value)
    end)

    panel.copyButton:SetText(context.requiresSpecSwitch and "Switch Spec" or (importString ~= "" and "Apply" or "Source"))
    panel.copyButton:SetEnabled(copyValue ~= "")
    panel.copyButton:SetAlpha(copyValue ~= "" and 1 or 0.45)
    panel.helpButton:SetEnabled(rotation ~= nil)
    panel.helpButton:SetAlpha(rotation and 1 or 0.45)
    if context.requiresSpecSwitch then
        panel.statusText:SetText(GetSpecLabel(context.specKey) .. " build available. Switch specialization, then apply it.")
    else
        panel.statusText:SetText(FormatBuildUsage(entry))
    end

    if panel.importPopup then
        panel.importPopup.editBox:SetText(copyValue)
        panel.importPopup.editBox:SetCursorPosition(0)
    end

    if panel.rotationPopup and panel.rotationPopup:IsShown() then
        RefreshRotationPopup(false)
    end

    panel:Show()
    QueueTalentCheckRefresh(0.05)
end

local function CreatePanel()
    if panel then
        return panel
    end

    panel = CreateFrame("Frame", "ZoidsToolsTalentGrimoirePanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel:SetBackdropBorderColor(0.52, 0.43, 0.24, 0.9)

    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.bg:SetAllPoints()

    local atlasOk = panel.bg.SetAtlas and pcall(panel.bg.SetAtlas, panel.bg, "Toast-Background")

    if not atlasOk then
        panel.bg:SetColorTexture(0.035, 0.03, 0.025, 0.94)
    end

    panel.providerDropdown = CreateOptionDropdown("ZoidsToolsTalentProviderDropdown", panel, 112)
    panel.providerDropdown:SetPoint("LEFT", panel, "LEFT", 8, 0)

    panel.contentDropdown = CreateOptionDropdown("ZoidsToolsTalentContentDropdown", panel, 94)
    panel.contentDropdown:SetPoint("LEFT", panel.providerDropdown, "RIGHT", CONTROL_GAP, 0)

    panel.modeDropdown = CreateOptionDropdown("ZoidsToolsTalentModeDropdown", panel, 132)
    panel.modeDropdown:SetPoint("LEFT", panel.contentDropdown, "RIGHT", CONTROL_GAP, 0)

    panel.targetDropdown = CreateOptionDropdown("ZoidsToolsTalentTargetDropdown", panel, 190)
    panel.targetDropdown:SetPoint("LEFT", panel.modeDropdown, "RIGHT", CONTROL_GAP, 0)

    panel.helpButton = CreateButton(panel, "?", 28)
    panel.helpButton:SetPoint("LEFT", panel.targetDropdown, "RIGHT", 8, 0)
    panel.helpButton:SetScript("OnClick", function()
        local popup = panel.rotationPopup
        if not popup then
            return
        end

        if popup:IsShown() then
            popup:Hide()
        else
            RefreshRotationPopup(true)
            popup:Show()
        end
    end)
    panel.helpButton:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Suggested Rotation", 1, 0.82, 0.2)

        if GetCurrentRotationData(panel.rotationContext) then
            GameTooltip:AddLine("Show the sourced, static priority reference in its own movable window.", 1, 1, 1, true)
        else
            GameTooltip:AddLine("No rotation was imported for this specialization. Run the LocalTools talent updater to refresh it.", 0.75, 0.75, 0.75, true)
        end

        GameTooltip:Show()
    end)
    panel.helpButton:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    panel.copyButton = CreateButton(panel, "Apply", 88)
    panel.copyButton:SetPoint("LEFT", panel.helpButton, "RIGHT", 6, 0)
    panel.copyButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    panel.copyButton:SetScript("OnClick", function(_, button)
        local entry, context = ns:GetTalentGrimoireCurrentBuild()
        local importString = entry and entry.importString or ""
        local copyValue = importString ~= "" and importString or (entry and entry.sourceUrl or "")

        if copyValue == "" then
            return
        end

        if button == "RightButton" then
            ShowCopyPopup(copyValue)
        elseif context and context.requiresSpecSwitch then
            ns:ApplyTalentGrimoireCurrentBuild()
        elseif importString ~= "" then
            ns:ApplyTalentGrimoireCurrentBuild()
        else
            ShowCopyPopup(copyValue)
        end
    end)

    panel.specButtons = {}
    for index = 1, MAX_CLASS_SPECIALIZATIONS do
        panel.specButtons[index] = CreateSpecializationButton(panel, index)
    end

    panel.statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.statusText:SetPoint("TOPLEFT", panel.providerDropdown, "BOTTOMLEFT", 2, -1)
    panel.statusText:SetPoint("RIGHT", panel.copyButton, "RIGHT", 0, 0)
    panel.statusText:SetJustifyH("LEFT")
    panel.statusText:SetTextColor(0.75, 0.82, 0.9)

    CreateImportPopup(panel)
    panel.rotationPopup = CreateRotationPopup()
    panel:Hide()

    return panel
end

local function AnchorPanel(talentFrame)
    if not panel or not talentFrame then
        return
    end

    local hostFrame = GetTalentPanelHost(talentFrame)

    if not hostFrame then
        return
    end

    -- Keep the helper independent from Blizzard's protected talent hierarchy.
    -- It can then remain visible and be made read-only during combat without
    -- attempting to show, hide, or reparent protected descendants.
    if panel:GetParent() ~= UIParent then
        panel:SetParent(UIParent)
    end

    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT", hostFrame, "BOTTOMLEFT", PANEL_ANCHOR_X, PANEL_ANCHOR_Y)
    panel._ztTalentHost = hostFrame
    -- Sit above the talent window itself, but below Blizzard's
    -- FULLSCREEN_DIALOG loadout menus and third-party tooltip popups.
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel((hostFrame:GetFrameLevel() or 1) + PANEL_FRAME_LEVEL_OFFSET)

    if panel.rotationPopup then
        panel.rotationPopup:SetFrameStrata("DIALOG")
        panel.rotationPopup:SetFrameLevel((panel:GetFrameLevel() or 1) + 6)
    end

    local controlLevel = (panel:GetFrameLevel() or 1) + CONTROL_FRAME_LEVEL_OFFSET

    for _, control in ipairs({
        panel.contentDropdown,
        panel.providerDropdown,
        panel.modeDropdown,
        panel.targetDropdown,
        panel.helpButton,
        panel.copyButton,
    }) do
        if control and control.SetFrameLevel then
            control:SetFrameLevel(controlLevel)
        end
    end

    for _, specButton in ipairs(panel.specButtons or {}) do
        specButton:SetFrameLevel(controlLevel)
    end
end

local function RefreshPanelForCombat(talentFrame)
    pendingCombatRefresh = true

    if not panel then
        return
    end

    local db = EnsureDB()

    if not db or db.enabled ~= true then
        panel:Hide()
        if panel.rotationPopup then
            panel.rotationPopup:Hide()
        end
        return
    end

    if not talentFrame then
        panel:Hide()
        return
    end

    -- The panel itself is addon-owned and parented to UIParent, so positioning
    -- and displaying it is safe. Avoid querying or changing Blizzard frame
    -- levels here; talent buttons, import data, and the tree stay untouched.
    local hostFrame = GetTalentPanelHost(talentFrame)

    if not hostFrame then
        panel:Hide()
        return
    end

    if panel._ztTalentHost ~= hostFrame then
        panel:ClearAllPoints()
        panel:SetPoint("BOTTOMLEFT", hostFrame, "BOTTOMLEFT", PANEL_ANCHOR_X, PANEL_ANCHOR_Y)
        panel._ztTalentHost = hostFrame
    end

    for _, dropdown in ipairs({
        panel.providerDropdown,
        panel.contentDropdown,
        panel.modeDropdown,
        panel.targetDropdown,
    }) do
        if dropdown and dropdown.SetEnabled then
            dropdown:SetEnabled(false)
            dropdown:SetAlpha(0.65)
        end
    end

    panel.copyButton:SetText("In Combat")
    panel.copyButton:SetEnabled(false)
    panel.copyButton:SetAlpha(0.45)
    local rotation = GetCurrentRotationData(panel.rotationContext)
    panel.helpButton:SetEnabled(rotation ~= nil)
    panel.helpButton:SetAlpha(rotation and 1 or 0.45)
    RefreshSpecializationButtons(true)
    panel.statusText:SetText("Build helper is read-only during combat. Selection and Apply unlock automatically afterward.")

    if panel.importPopup then
        panel.importPopup:Hide()
    end

    panel:Show()
end

local function UpdatePanelVisibility()
    local db = EnsureDB()
    local talentFrame = FindTalentFrame()

    -- This frame is entirely addon-owned and safe to construct in combat.
    -- Blizzard talent-tree reads and edits remain in the out-of-combat path.
    CreatePanel()

    if InCombatLockdown and InCombatLockdown() then
        RefreshPanelForCombat(talentFrame)
        return
    end

    pendingCombatRefresh = false

    if not db or db.enabled ~= true then
        panel:Hide()
        ClearTalentChecks()
        if panel.rotationPopup then
            panel.rotationPopup:Hide()
        end

        if panel.importPopup then
            panel.importPopup:Hide()
        end

        return
    end

    if not talentFrame then
        panel:Hide()
        ClearTalentChecks()

        if panel.importPopup then
            panel.importPopup:Hide()
        end

        return
    end

    AnchorPanel(talentFrame)
    RefreshPanel()
end

function QueueRefresh(delay)
    if InCombatLockdown and InCombatLockdown() then
        pendingCombatRefresh = true
    else
        pendingCombatRefresh = false
    end

    if refreshQueued then
        return
    end

    refreshQueued = true

    local function Run()
        refreshQueued = false
        UpdatePanelVisibility()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.08, Run)
    else
        Run()
    end
end

local function HookTalentFrame(frame)
    if not frame or talentFrameHooks[frame] or not frame.HookScript then
        return
    end

    talentFrameHooks[frame] = true
    frame:HookScript("OnShow", function()
        QueueRefresh(0.05)
    end)
    frame:HookScript("OnHide", function()
        QueueRefresh(0)
    end)
end

local function InstallTalentFrameHooks()
    local playerSpells = _G.PlayerSpellsFrame

    for _, frame in ipairs({
        playerSpells,
        playerSpells and (playerSpells.TalentsFrame or playerSpells.TalentFrame or playerSpells.ClassTalentFrame),
        _G.ClassTalentFrame,
        _G.PlayerTalentFrame,
        _G.TalentFrame,
    }) do
        HookTalentFrame(frame)
    end

    if not talentFrameHooks.playerSpellsTabCallback
        and _G.EventRegistry
        and _G.EventRegistry.RegisterCallback
        and playerSpells
    then
        talentFrameHooks.playerSpellsTabCallback = true
        pcall(_G.EventRegistry.RegisterCallback, _G.EventRegistry, "PlayerSpellsFrame.TabSet", function()
            QueueRefresh(0.05)
        end, panel or playerSpells)
    end

    -- Saved loadouts can be deleted without closing PlayerSpellsFrame. In
    -- particular, deleting the final one transitions Blizzard to its special
    -- Default Loadout after the normal trait update has already fired. Secure
    -- post-hooks give that transition a second visibility pass without
    -- replacing or tainting Blizzard's loadout functions.
    if hooksecurefunc and C_ClassTalents then
        for _, apiName in ipairs({ "DeleteConfig", "LoadConfig" }) do
            local hookKey = "classTalents" .. apiName

            if not talentFrameHooks[hookKey] and type(C_ClassTalents[apiName]) == "function" then
                local ok = pcall(hooksecurefunc, C_ClassTalents, apiName, function()
                    QueueRefresh(0.05)

                    if C_Timer and C_Timer.After then
                        C_Timer.After(0.4, function()
                            InstallTalentFrameHooks()
                            QueueRefresh(0)
                        end)
                    end
                end)

                if ok then
                    talentFrameHooks[hookKey] = true
                end
            end
        end
    end
end

function ns:GetTalentGrimoireEnabled()
    local db = EnsureDB()
    return db and db.enabled == true
end

function ns:SetTalentGrimoireEnabled(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.enabled = value == true

    if db.enabled then
        InstallTalentFrameHooks()
        UpdatePanelVisibility()

        if C_Timer and C_Timer.After then
            C_Timer.After(0.2, function()
                InstallTalentFrameHooks()
                UpdatePanelVisibility()
            end)
        end
    else
        QueueRefresh(0)
    end
end

function ns:ReportTalentPanelDiagnostics()
    local db = EnsureDB()
    local playerSpells = _G.PlayerSpellsFrame
    local talents = playerSpells
        and (playerSpells.TalentsFrame or playerSpells.TalentFrame or playerSpells.ClassTalentFrame)
    local found = FindTalentFrame()

    CreatePanel()

    local function FrameState(frame)
        if not frame then
            return "missing"
        end

        local shown = frame.IsShown and frame:IsShown() or false
        local visible = frame.IsVisible and frame:IsVisible() or false
        return string.format("present shown=%s visible=%s", tostring(shown), tostring(visible))
    end

    PrintTalentMessage(string.format(
        "Talent panel: enabled=%s combat=%s playerSpells=%s talents=%s found=%s panel=%s alpha=%s strata=%s level=%s.",
        tostring(db and db.enabled == true),
        tostring(InCombatLockdown and InCombatLockdown() or false),
        FrameState(playerSpells),
        FrameState(talents),
        FrameState(found),
        FrameState(panel),
        tostring(panel and panel.GetAlpha and panel:GetAlpha() or "n/a"),
        tostring(panel and panel.GetFrameStrata and panel:GetFrameStrata() or "n/a"),
        tostring(panel and panel.GetFrameLevel and panel:GetFrameLevel() or "n/a")
    ))

    UpdatePanelVisibility()
end

function ns:GetTalentGrimoireContentType()
    local db = EnsureDB()
    return db and db.contentType or "mythicplus"
end

function ns:GetTalentGrimoireProvider()
    return GetProviderKey()
end

function ns:SetTalentGrimoireProvider(value)
    local db = EnsureDB()
    if not db then return end

    for _, option in ipairs(GetProviderOptions()) do
        if option.value == value then
            db.provider = value
            break
        end
    end

    local contentOptions = GetContentOptions()
    local found = false
    for _, option in ipairs(contentOptions) do
        if option.value == db.contentType then found = true break end
    end
    if not found and contentOptions[1] then db.contentType = contentOptions[1].value end

    QueueRefresh(0)
    if ns.UI and ns.UI.RefreshVisiblePage then ns.UI.RefreshVisiblePage() end
end

function ns:SetTalentGrimoireContentType(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.contentType = NormalizeContentType(value)
    db.mode = GetModeKey(db.contentType)
    QueueRefresh(0)

    if ns.UI and ns.UI.RefreshVisiblePage then
        ns.UI.RefreshVisiblePage()
    end
end

function ns:GetTalentGrimoireMode()
    return GetModeKey(ns:GetTalentGrimoireContentType())
end

function ns:SetTalentGrimoireMode(value)
    SetModeKey(ns:GetTalentGrimoireContentType(), value)
    QueueRefresh(0)

    if ns.UI and ns.UI.RefreshVisiblePage then
        ns.UI.RefreshVisiblePage()
    end
end

function ns:GetTalentGrimoireTarget()
    return GetTargetKey(ns:GetTalentGrimoireContentType())
end

function ns:SetTalentGrimoireTarget(value)
    SetTargetKey(ns:GetTalentGrimoireContentType(), value)
    QueueRefresh(0)

    if ns.UI and ns.UI.RefreshVisiblePage then
        ns.UI.RefreshVisiblePage()
    end
end

function ns:GetTalentGrimoireTargetLabel()
    local contentType = ns:GetTalentGrimoireContentType()
    return GetTargetLabel(contentType, GetTargetKey(contentType))
end

function ns:GetTalentGrimoireModeLabel()
    local contentType = ns:GetTalentGrimoireContentType()
    return GetOptionText(GetModeOptions(contentType, GetTargetKey(contentType)), GetModeKey(contentType))
end

function ns:CycleTalentGrimoireContent()
    local db = EnsureDB()

    if not db then
        return
    end

    ns:SetTalentGrimoireContentType(SelectNextOption(GetContentOptions(), db.contentType))
end

function ns:CycleTalentGrimoireTarget()
    local contentType = ns:GetTalentGrimoireContentType()
    ns:SetTalentGrimoireTarget(SelectNextOption(GetTargetOptions(contentType), GetTargetKey(contentType)))
end

function ns:CycleTalentGrimoireMode()
    local contentType = ns:GetTalentGrimoireContentType()
    ns:SetTalentGrimoireMode(SelectNextOption(GetModeOptions(contentType, GetTargetKey(contentType)), GetModeKey(contentType)))
end

function ns:GetTalentGrimoireCurrentBuild()
    return GetBuildEntry()
end

function ns:GetTalentGrimoireStatusText()
    if not ns:GetTalentGrimoireEnabled() then
        return "Talent controls are disabled."
    end

    local entry, context = GetBuildEntry()

    if entry then
        if context.requiresSpecSwitch then
            return string.format(
                "%s has a %s %s build from %s. Switch specialization to use it.",
                tostring(GetSpecLabel(context.specKey)),
                tostring(GetContentLabel(context.contentType)),
                tostring(context.modeLabel or "selected"),
                tostring(context.providerLabel or context.source or "generated data")
            )
        end

        return string.format(
            "Showing %s %s for %s from %s. Updated: %s.",
            tostring(GetContentLabel(context.contentType)),
            tostring(context.modeLabel or "build"),
            tostring(context.targetLabel or "selection"),
            tostring(context.providerLabel or context.source or "generated data"),
            tostring(context.generatedAt or "unknown")
        )
    end

    return "No talent build data found for your current spec and selection. Run the external updater to refresh Data/TalentGrimoire.lua."
end

function ns:RefreshTalentGrimoire()
    QueueRefresh(0)
end

function ns:InitializeTalentGrimoire()
    EnsureDB()
    PruneTalentGrimoireToPlayerClass()
    CompactTalentGrimoireData()
    InstallTalentFrameHooks()

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("ADDON_LOADED")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
        eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")

        -- These events are present in current clients, but keep registration
        -- guarded so the addon remains loadable on a build where one is absent.
        pcall(eventFrame.RegisterEvent, eventFrame, "TRAIT_CONFIG_CREATED")
        pcall(eventFrame.RegisterEvent, eventFrame, "TRAIT_CONFIG_DELETED")
        eventFrame:SetScript("OnEvent", function(_, event)
            if not (InCombatLockdown and InCombatLockdown()) then
                InstallTalentFrameHooks()
            end

            QueueRefresh(0.12)

            if (event == "TRAIT_CONFIG_CREATED" or event == "TRAIT_CONFIG_DELETED")
                and C_Timer and C_Timer.After
            then
                C_Timer.After(0.4, function()
                    InstallTalentFrameHooks()
                    QueueRefresh(0)
                end)
            end

            if event == "PLAYER_REGEN_ENABLED" and pendingCombatRefresh then
                QueueRefresh(0.12)
            end

            if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
                QueueDungeonTalentPromptCheck(1.5)
            elseif event == "PLAYER_REGEN_ENABLED"
                or event == "PLAYER_SPECIALIZATION_CHANGED"
                or event == "ACTIVE_TALENT_GROUP_CHANGED"
                or event == "TRAIT_CONFIG_UPDATED"
            then
                QueueDungeonTalentPromptCheck(0.8)
            end
        end)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            InstallTalentFrameHooks()
            QueueRefresh(0)
            QueueDungeonTalentPromptCheck(1)
        end)
    end

    QueueRefresh(0)
end
