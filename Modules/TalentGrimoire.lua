local _, ns = ...

local panel
local eventFrame
local applyFrame
local QueueRefresh
local refreshQueued = false
local talentFrameHooks = {}
local talentCheckRefreshQueued = false
local checkedTalentButtons = {}

local PANEL_HEIGHT = 52
local PANEL_WIDTH = 568
local PANEL_ANCHOR_X = 8
local PANEL_ANCHOR_Y = 8
local CONTROL_GAP = 6
local ZOIDS_LOADOUT_NAME = "ZoidsTools"
local DUNGEON_PROMPT_DIALOG = "ZOIDSTOOLS_TALENT_GRIMOIRE_DUNGEON_PROMPT"
local BIT_WIDTH_HEADER_VERSION = 8
local BIT_WIDTH_SPEC_ID = 16
local BIT_WIDTH_RANKS_PURCHASED = 6
local APPLY_BATCH_SIZE = 100
local PENDING_APPLY_WATCHDOG_SECS = 10
local pendingApply
local pendingApplySeq = 0
local applyToken = 0
local dungeonPromptQueued = false
local lastDungeonZoneSignature
local lastDungeonPromptSignature
local ACTIVE_TARGET_TEXT_COLOR = "ff8fdc8f"
local PENDING_TARGET_TEXT_COLOR = "ffffd36a"
local ACTIVE_TARGET_TEXT_RGBA = { 0.56, 0.86, 0.56, 1 }
local PENDING_TARGET_TEXT_RGBA = { 1, 0.83, 0.42, 1 }
local DEFAULT_DROPDOWN_TEXT_RGBA = { 1, 1, 1, 1 }
local TALENT_MATCH_COLOR = { 0.08, 1, 0.24, 1 }
local TALENT_PENDING_COLOR = { 1, 0.82, 0.12, 1 }

local CONTENT_OPTIONS = {
    { value = "mythicplus", text = "Mythic+" },
    { value = "raid", text = "Raid" },
    { value = "pvp", text = "PvP" },
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
    return _G.ZoidsToolsTalentGrimoire
end

local function GetClassAndSpec()
    local _, classToken = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    local specKey = classToken and specIndex and SPEC_KEYS[classToken] and SPEC_KEYS[classToken][specIndex]

    return classToken, specKey
end

local function GetSpecLabel(specKey)
    return SPEC_LABELS[specKey] or TitleCase(specKey)
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

    if not targetData and pvpData then
        for fallbackTargetKey, fallbackTargetData in pairs(pvpData) do
            targetKey = fallbackTargetKey
            targetData = fallbackTargetData
            break
        end
    end

    return targetData and targetData.builds, targetKey, targetData
end

local function GetModeOptions(contentType, targetKey)
    contentType = NormalizeContentType(contentType)

    if contentType == "pvp" then
        if not targetKey then
            local db = ns.db and ns.db.talentGrimoire
            targetKey = db and db.pvpTarget or DEFAULT_TARGET_BY_CONTENT.pvp
        end

        local builds = GetPvpBuildsForTarget(targetKey)
        local options = {}

        if type(builds) == "table" then
            for buildKey, entry in pairs(builds) do
                local label = type(entry) == "table" and (entry.modeLabel or entry.title) or TitleCase(buildKey)

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

    if contentType == "raid" then
        return db.raidTarget or DEFAULT_TARGET_BY_CONTENT.raid
    elseif contentType == "pvp" then
        return db.pvpTarget or DEFAULT_TARGET_BY_CONTENT.pvp
    end

    return db.mythicPlusTarget or DEFAULT_TARGET_BY_CONTENT.mythicplus
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
    local labels = {}
    local options = {}

    contentType = NormalizeContentType(contentType)

    if root and root.targets and root.targets[contentType] then
        for key, label in pairs(root.targets[contentType]) do
            labels[key] = label
        end
    end

    if specData and specData[contentType] then
        for key, targetData in pairs(specData[contentType]) do
            labels[key] = type(targetData) == "table" and targetData.label or labels[key] or key
        end
    end

    if contentType == "raid" then
        labels["all-bosses"] = labels["all-bosses"] or "All Bosses"
    elseif contentType == "pvp" then
        labels[DEFAULT_TARGET_BY_CONTENT.pvp] = labels[DEFAULT_TARGET_BY_CONTENT.pvp] or "Icy Veins"
    else
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
    local specData, classToken, specKey = GetCurrentSpecData()

    contentType = NormalizeContentType(contentType)
    targetKey = targetKey or GetTargetKey(contentType)
    mode = mode or GetModeKey(contentType)

    local targetData = specData and specData[contentType] and specData[contentType][targetKey]
    if not targetData and specData and specData[contentType] then
        for fallbackTargetKey, fallbackTargetData in pairs(specData[contentType]) do
            targetKey = fallbackTargetKey
            targetData = fallbackTargetData
            break
        end
    end

    local builds = targetData and targetData.builds
    local fallbackMode = GetFirstBuildKey(builds)
    local entry = builds and (builds[mode] or builds.popular or (fallbackMode and builds[fallbackMode]))
    if entry and (not builds or not builds[mode]) then
        mode = fallbackMode or mode
    end

    return entry, {
        classToken = classToken,
        specKey = specKey,
        contentType = contentType,
        targetKey = targetKey,
        targetLabel = GetTargetLabel(contentType, targetKey),
        mode = mode,
        modeLabel = GetOptionText(GetModeOptions(contentType, targetKey), mode),
        generatedAt = GetRoot() and GetRoot().generatedAt,
        source = (entry and entry.source) or (GetRoot() and GetRoot().source),
    }
end

local function GetBuildEntry()
    local db = EnsureDB()
    local contentType = db and db.contentType or "mythicplus"

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

local function PrintTalentMessage(message)
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

    if context.targetLabel and context.targetLabel ~= "" then
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
        name = string.sub(name, 1, 48)
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
                pendingApply = nil
                ns._talentApplyInProgress = false
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

local function ReadLoadoutContent(importStream, treeID)
    local results = {}
    local treeNodes = C_Traits.GetTreeNodes(treeID) or {}

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
    local treeNodes = C_Traits.GetTreeNodes(treeID) or {}

    for index, treeNodeID in ipairs(treeNodes) do
        local indexInfo = loadoutContent[index]

        if indexInfo and indexInfo.isNodePurchased then
            local nodeInfo = C_Traits.GetNodeInfo(configID, treeNodeID)

            if nodeInfo and nodeInfo.ID ~= 0 then
                local isChoice = nodeInfo.type == Enum.TraitNodeType.Selection
                    or nodeInfo.type == Enum.TraitNodeType.SubTreeSelection
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

    C_Traits.ResetTree(configID, treeID)

    local orderedNodes = {}

    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        orderedNodes[#orderedNodes + 1] = nodeID
    end

    table.sort(orderedNodes, function(leftNodeID, rightNodeID)
        local leftInfo = C_Traits.GetNodeInfo(configID, leftNodeID)
        local rightInfo = C_Traits.GetNodeInfo(configID, rightNodeID)
        local leftY = (leftInfo and leftInfo.posY) or 0
        local rightY = (rightInfo and rightInfo.posY) or 0

        if leftY ~= rightY then
            return leftY < rightY
        end

        return ((leftInfo and leftInfo.posX) or 0) < ((rightInfo and rightInfo.posX) or 0)
    end)

    local index = 1
    local passProgress = 0

    local function EntryStateMatches(nodeInfo, entry)
        if not nodeInfo or not entry then
            return false
        end

        if entry.isChoiceNode and entry.selectionEntryID then
            local activeEntryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID

            if activeEntryID ~= entry.selectionEntryID then
                return false
            end
        end

        return ((nodeInfo.ranksPurchased or 0) >= (entry.ranksPurchased or 0))
    end

    local function Step()
        if token ~= applyToken then
            return
        end

        local processed = 0

        while index <= #orderedNodes and processed < APPLY_BATCH_SIZE do
            local nodeID = orderedNodes[index]
            local entry = entryInfo[nodeID]

            if entry then
                local madeProgress = false
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)

                if entry.isChoiceNode and entry.selectionEntryID then
                    local activeEntryID = nodeInfo and nodeInfo.activeEntry and nodeInfo.activeEntry.entryID

                    if activeEntryID ~= entry.selectionEntryID then
                        madeProgress = C_Traits.SetSelection(configID, entry.nodeID, entry.selectionEntryID) or madeProgress
                        nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                    end
                end

                if entry.ranksPurchased then
                    local currentRanks = (nodeInfo and nodeInfo.ranksPurchased) or 0
                    local neededRanks = math.max(0, entry.ranksPurchased - currentRanks)

                    if neededRanks > 0 then
                        for _ = 1, neededRanks do
                            local rankOK = C_Traits.PurchaseRank(configID, entry.nodeID)
                            madeProgress = rankOK or madeProgress

                            if not rankOK then
                                break
                            end
                        end

                        nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                    end
                end

                if EntryStateMatches(nodeInfo, entry) then
                    entryInfo[nodeID] = nil
                    passProgress = passProgress + 1
                elseif madeProgress then
                    passProgress = passProgress + 1
                end
            end

            index = index + 1
            processed = processed + 1
        end

        if index <= #orderedNodes then
            RunNextFrame(Step)
        elseif passProgress > 0 then
            index = 1
            passProgress = 0
            RunNextFrame(Step)
        elseif onComplete then
            onComplete()
        end
    end

    Step()
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

            if updatedConfigID and activeConfigID and updatedConfigID ~= activeConfigID then
                return
            end

            self:UnregisterEvent("TRAIT_CONFIG_UPDATED")

            local applyState = pendingApply

            if applyState.renameOnly then
                local configID = GetStoredConfigID(GetCurrentSpecID())

                if configID and C_ClassTalents and C_ClassTalents.RenameConfig then
                    C_ClassTalents.RenameConfig(configID, BuildLoadoutName(applyState.buildLabel))
                end

                PrintTalentMessage("Talents applied: " .. tostring(applyState.buildLabel or "Build"))
                ClearPendingApply()

                RunNextFrame(function()
                    ns._talentApplyInProgress = false
                    QueueRefresh(0)
                end)
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

    if not isContinuation
        and C_Traits.ConfigHasStagedChanges
        and C_Traits.ConfigHasStagedChanges(activeConfigID)
    then
        return FailTalentApply("You have unsaved talent changes. Apply or discard them first, then try again.")
    end

    local specID = GetCurrentSpecID()

    if not specID then
        return FailTalentApply("Could not determine your active specialization.")
    end

    local treeID = GetConfigTreeID(activeConfigID)

    if not treeID then
        return FailTalentApply("Could not determine the active talent tree.")
    end

    local entryInfo, parseError = ParseTalentImportString(importString, treeID, activeConfigID)

    if not entryInfo then
        return FailTalentApply(parseError)
    end

    local zoidsConfigID = GetStoredConfigID(specID)

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
        C_ClassTalents.RequestNewConfig(ZOIDS_LOADOUT_NAME)
        PrintTalentMessage("Creating ZoidsTools talent loadout...")
        return true
    end

    local currentLoadoutID

    if C_ClassTalents.GetLastSelectedSavedConfigID then
        currentLoadoutID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    end

    currentLoadoutID = currentLoadoutID or activeConfigID

    if currentLoadoutID ~= zoidsConfigID then
        local result = C_ClassTalents.LoadConfig(zoidsConfigID, true)

        if Enum and Enum.LoadConfigResult and result == Enum.LoadConfigResult.LoadInProgress then
            EnsureApplyFrame()
            SetPendingApply({ importString = importString, buildLabel = buildLabel })
            applyFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
            return true
        elseif Enum and Enum.LoadConfigResult and result == Enum.LoadConfigResult.Error then
            ClearStoredConfigID(specID)
            return FailTalentApply("Could not load the ZoidsTools talent loadout. Apply or discard pending talent changes, then try again.")
        end
    end

    activeConfigID = GetActiveConfigID()
    treeID = GetConfigTreeID(activeConfigID)

    if not activeConfigID or not treeID then
        return FailTalentApply("Could not prepare the ZoidsTools talent loadout.")
    end

    entryInfo, parseError = ParseTalentImportString(importString, treeID, activeConfigID)

    if not entryInfo then
        return FailTalentApply(parseError)
    end

    local originalNodeCount = 0

    for _ in pairs(entryInfo) do
        originalNodeCount = originalNodeCount + 1
    end

    SetPendingApply({ importString = importString, buildLabel = buildLabel, staging = true })
    ns._talentApplyInProgress = true

    ResetAndPurchaseDeferred(activeConfigID, treeID, entryInfo, function()
        if not C_Traits.ConfigHasStagedChanges(activeConfigID) then
            if C_ClassTalents.RenameConfig and zoidsConfigID then
                C_ClassTalents.RenameConfig(zoidsConfigID, BuildLoadoutName(buildLabel))
            end

            ns._talentApplyInProgress = false
            PrintTalentMessage("Already using this talent build.")
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
            PrintTalentMessage(string.format(
                "Applying %d of %d talent nodes. Your current level or tree state could not fit the rest.",
                appliedNodes,
                originalNodeCount
            ))
        end

        if not C_ClassTalents.CommitConfig or not C_ClassTalents.CommitConfig(zoidsConfigID) then
            ns._talentApplyInProgress = false
            ClearPendingApply()
            PrintTalentMessage("Commit failed. Open the talents pane and click Apply Changes.")
            return
        end

        EnsureApplyFrame()
        SetPendingApply({ buildLabel = buildLabel, renameOnly = true })
        applyFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")

        if C_ClassTalents.UpdateLastSelectedSavedConfigID then
            C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, zoidsConfigID)
        end
    end)

    return true
end

function ns:ApplyTalentGrimoireCurrentBuild()
    local entry, context = GetBuildEntry()
    local importString = entry and entry.importString or ""

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
                return active == true
            end
        end
    end

    local talents = playerSpells.TalentsFrame or playerSpells.TalentFrame or playerSpells.ClassTalentFrame
    return not talents or not talents.IsShown or talents:IsShown()
end

local function FindTalentFrame()
    local playerSpells = _G.PlayerSpellsFrame

    if playerSpells and playerSpells.IsShown and playerSpells:IsShown() and IsTalentsTabActive() then
        local talents = playerSpells.TalentsFrame or playerSpells.TalentFrame or playerSpells.ClassTalentFrame

        if not talents or not talents.IsShown or talents:IsShown() then
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

local function ShowCopyPopup(copyValue)
    if not panel or not panel.importPopup or copyValue == "" then
        return
    end

    panel.importPopup:ClearAllPoints()
    panel.importPopup:SetPoint("BOTTOM", panel, "TOP", 0, 6)
    panel.importPopup.editBox:SetText(copyValue)
    panel.importPopup.editBox:SetCursorPosition(0)
    panel.importPopup:Show()
    panel.importPopup.editBox:SetFocus()
    panel.importPopup.editBox:HighlightText()
end

local function RefreshPanel()
    if not panel then
        return
    end

    local entry, context = GetBuildEntry()
    local contentType = context.contentType or "mythicplus"
    local mode = context.mode or GetModeKey(contentType)
    local targetKey = context.targetKey or GetTargetKey(contentType)
    local importString = entry and entry.importString or ""
    local copyValue = importString ~= "" and importString or (entry and entry.sourceUrl or "")
    local targetOptions = GetTargetDropdownOptions(contentType, mode, targetKey)

    panel.contentDropdown:SetOptions(CONTENT_OPTIONS, contentType, function(value)
        ns:SetTalentGrimoireContentType(value)
    end)
    panel.modeDropdown:SetOptions(GetModeOptions(contentType, targetKey), mode, function(value)
        ns:SetTalentGrimoireMode(value)
    end)
    panel.targetDropdown:SetOptions(targetOptions, targetKey, function(value)
        ns:SetTalentGrimoireTarget(value)
    end)

    panel.copyButton:SetText(importString ~= "" and "Apply" or "Source")
    panel.copyButton:SetEnabled(copyValue ~= "")
    panel.copyButton:SetAlpha(copyValue ~= "" and 1 or 0.45)
    panel.statusText:SetText(FormatBuildUsage(entry))

    if panel.importPopup then
        panel.importPopup.editBox:SetText(copyValue)
        panel.importPopup.editBox:SetCursorPosition(0)
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
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
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

    panel.contentDropdown = CreateOptionDropdown("ZoidsToolsTalentContentDropdown", panel, 104)
    panel.contentDropdown:SetPoint("LEFT", panel, "LEFT", 8, 0)

    panel.modeDropdown = CreateOptionDropdown("ZoidsToolsTalentModeDropdown", panel, 120)
    panel.modeDropdown:SetPoint("LEFT", panel.contentDropdown, "RIGHT", CONTROL_GAP, 0)

    panel.targetDropdown = CreateOptionDropdown("ZoidsToolsTalentTargetDropdown", panel, 220)
    panel.targetDropdown:SetPoint("LEFT", panel.modeDropdown, "RIGHT", CONTROL_GAP, 0)

    panel.copyButton = CreateButton(panel, "Apply", 74)
    panel.copyButton:SetPoint("LEFT", panel.targetDropdown, "RIGHT", 8, 0)
    panel.copyButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    panel.copyButton:SetScript("OnClick", function(_, button)
        local entry = ns:GetTalentGrimoireCurrentBuild()
        local importString = entry and entry.importString or ""
        local copyValue = importString ~= "" and importString or (entry and entry.sourceUrl or "")

        if copyValue == "" then
            return
        end

        if button == "RightButton" then
            ShowCopyPopup(copyValue)
        elseif importString ~= "" then
            ns:ApplyTalentGrimoireCurrentBuild()
        else
            ShowCopyPopup(copyValue)
        end
    end)

    panel.statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.statusText:SetPoint("TOPLEFT", panel.contentDropdown, "BOTTOMLEFT", 2, -1)
    panel.statusText:SetPoint("RIGHT", panel.copyButton, "RIGHT", 0, 0)
    panel.statusText:SetJustifyH("LEFT")
    panel.statusText:SetTextColor(0.75, 0.82, 0.9)

    CreateImportPopup(panel)
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

    if panel:GetParent() ~= hostFrame then
        panel:SetParent(hostFrame)
    end

    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT", hostFrame, "BOTTOMLEFT", PANEL_ANCHOR_X, PANEL_ANCHOR_Y)
    panel:SetFrameStrata(hostFrame:GetFrameStrata() or "HIGH")
    panel:SetFrameLevel((hostFrame:GetFrameLevel() or 1) + 500)
    panel:Raise()

    local controlLevel = (panel:GetFrameLevel() or 1) + 5

    for _, control in ipairs({
        panel.contentDropdown,
        panel.modeDropdown,
        panel.targetDropdown,
        panel.copyButton,
    }) do
        if control and control.SetFrameLevel then
            control:SetFrameLevel(controlLevel)
            control:Raise()
        end
    end
end

local function UpdatePanelVisibility()
    local db = EnsureDB()
    local talentFrame = FindTalentFrame()

    CreatePanel()

    if not db or db.enabled ~= true or not talentFrame then
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
    QueueRefresh(0)
end

function ns:GetTalentGrimoireContentType()
    local db = EnsureDB()
    return db and db.contentType or "mythicplus"
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

    ns:SetTalentGrimoireContentType(SelectNextOption(CONTENT_OPTIONS, db.contentType))
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
        return "Talent Grimoire controls are disabled."
    end

    local entry, context = GetBuildEntry()

    if entry then
        return string.format(
            "Showing %s %s for %s. Data source: %s. Updated: %s.",
            tostring(GetContentLabel(context.contentType)),
            tostring(context.modeLabel or "build"),
            tostring(context.targetLabel or "selection"),
            tostring(context.source or "generated data"),
            tostring(context.generatedAt or "unknown")
        )
    end

    return "No Talent Grimoire build data found for your current spec and selection. Run the external updater to refresh Data/TalentGrimoire.lua."
end

function ns:RefreshTalentGrimoire()
    QueueRefresh(0)
end

function ns:InitializeTalentGrimoire()
    EnsureDB()
    CreatePanel()
    InstallTalentFrameHooks()

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("ADDON_LOADED")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
        eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
        eventFrame:SetScript("OnEvent", function(_, event)
            InstallTalentFrameHooks()
            QueueRefresh(0.12)

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
