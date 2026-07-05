local _, ns = ...

local initialized = false
local eventFrame
local itemLevelCache = {}
local mythicScoreCache = {}
local pendingInspects = {}
local activeInspectGuid
local lastInspectRequest = 0
local RefreshCurrentTooltipForGUID

local DEFAULT_BG = { 0.02, 0.018, 0.014, 0.92 }
local DEFAULT_BORDER = { 0.35, 0.35, 0.35, 0.85 }
local INSPECT_THROTTLE = 1.25
local INSPECT_RETRY_DELAY = 3
local INSPECT_PENDING_TIMEOUT = 2
local INSPECT_RESULT_RETRY_STEP = 0.25
local INSPECT_RESULT_RETRIES = 8
local ITEM_LEVEL_CACHE_TIME = 30
local PLAYER_ITEM_LEVEL_CACHE_TIME = 2
local MYTHIC_SCORE_CACHE_TIME = 30
local ITEM_LEVEL_CACHE_MAX_ENTRIES = 80
local MYTHIC_SCORE_CACHE_MAX_ENTRIES = 120
local MIN_FALLBACK_EQUIPPED_ITEMS = 12
local playerItemLevelCache

local EQUIPMENT_SLOTS = {
    1,
    2,
    3,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
}

local FACTION_COLORS = {
    Alliance = {
        bg = { 0.025, 0.075, 0.16, 0.88 },
        tint = { 0.10, 0.32, 0.75, 0.18 },
        border = { 0.18, 0.38, 0.85, 0.58 },
    },
    Horde = {
        bg = { 0.14, 0.025, 0.018, 0.88 },
        tint = { 0.55, 0.05, 0.035, 0.18 },
        border = { 0.82, 0.16, 0.10, 0.58 },
    },
}

local PERCENTILE_COLORS = {
    common = { 1, 1, 1 },
    uncommon = { 0.12, 1, 0 },
    superior = { 0, 0.44, 0.87 },
    legendary = { 1, 0.5, 0 },
}

local function EnsureTintTexture(tooltip)
    if not tooltip or type(tooltip.CreateTexture) ~= "function" then
        return nil
    end

    if tooltip.ZoidsToolsFactionTint then
        return tooltip.ZoidsToolsFactionTint
    end

    local tint = tooltip:CreateTexture(nil, "BORDER", nil, -7)
    tint:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 4, -4)
    tint:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -4, 4)
    tint:SetColorTexture(0, 0, 0, 0)
    tint:Hide()

    tooltip.ZoidsToolsFactionTint = tint

    return tint
end

local function SetFactionTint(tooltip, color)
    local tint = EnsureTintTexture(tooltip)

    if not tint then
        return
    end

    if color then
        tint:SetColorTexture(color[1], color[2], color[3], color[4])
        tint:Show()
    else
        tint:Hide()
    end
end

local function SetBackdropColors(tooltip, bg, border)
    if not tooltip then
        return
    end

    if bg and tooltip.SetBackdropColor then
        tooltip:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    end

    if border and tooltip.SetBackdropBorderColor then
        tooltip:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
    end
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.tooltips = ns.db.tooltips or {}

    if ns.db.tooltips.factionBackground == nil then
        ns.db.tooltips.factionBackground = true
    end

    if ns.db.tooltips.classColoredNames == nil then
        ns.db.tooltips.classColoredNames = true
    end

    if ns.db.tooltips.showMythicScore == nil then
        ns.db.tooltips.showMythicScore = true
    end

    if ns.db.tooltips.colorMythicScore == nil then
        ns.db.tooltips.colorMythicScore = true
    end

    if ns.db.tooltips.showMythicPercentile == nil then
        ns.db.tooltips.showMythicPercentile = true
    end

    if ns.db.tooltips.showItemLevel == nil then
        ns.db.tooltips.showItemLevel = true
    end

    return ns.db.tooltips
end

local function IsTooltipItemLevelEnabled()
    local db = EnsureDB()

    return db and db.showItemLevel == true
end

local function ResetTooltipBackdrop(tooltip)
    if tooltip ~= GameTooltip then
        return
    end

    SetBackdropColors(tooltip, DEFAULT_BG, DEFAULT_BORDER)
    SetFactionTint(tooltip)
end

local function ResetTooltipState(tooltip)
    ResetTooltipBackdrop(tooltip)

    if tooltip ~= GameTooltip then
        return
    end

    tooltip.ZoidsToolsUnitGuid = nil
    tooltip.ZoidsToolsDetailsKey = nil
end

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value)
end

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function PruneTimedCache(cache, maxEntries, maxAge)
    if type(cache) ~= "table" or not maxEntries then
        return
    end

    local now = GetTime and GetTime() or 0
    local count = 0

    for key, value in pairs(cache) do
        local timestamp = type(value) == "table" and (value.time or value.lastRequest)

        if maxAge and timestamp and now > 0 and (now - timestamp) > maxAge then
            cache[key] = nil
        else
            count = count + 1
        end
    end

    if count > maxEntries then
        wipe(cache)
    end
end

local function GetDisplayedUnit(tooltip)
    if TooltipUtil and type(TooltipUtil.GetDisplayedUnit) == "function" then
        local ok, first, second = pcall(TooltipUtil.GetDisplayedUnit, tooltip)
        local unit = second or first

        if ok and not IsSecretValue(unit) and type(unit) == "string" and unit ~= "" then
            return unit
        end
    end

    if tooltip and type(tooltip.GetUnit) == "function" then
        local ok, _, unit = pcall(tooltip.GetUnit, tooltip)

        if ok and not IsSecretValue(unit) and type(unit) == "string" and unit ~= "" then
            return unit
        end
    end

    return nil
end

local function UnitIsPlayerSafe(unit)
    if not unit or not UnitIsPlayer then
        return false
    end

    local ok, isPlayer = pcall(UnitIsPlayer, unit)

    return ok and not IsSecretValue(isPlayer) and isPlayer == true
end

local function UnitIsUnitSafe(unit, otherUnit)
    if not unit or not otherUnit or not UnitIsUnit then
        return false
    end

    local ok, isUnit = pcall(UnitIsUnit, unit, otherUnit)

    return ok and not IsSecretValue(isUnit) and isUnit == true
end

local function GetFaction(unit)
    if not unit or not UnitFactionGroup then
        return nil
    end

    local ok, faction = pcall(UnitFactionGroup, unit)

    if ok and not IsSecretValue(faction) then
        return faction
    end

    return nil
end

local function GetUnitClassFile(unit)
    if not unit or not UnitClass then
        return nil
    end

    local ok, _, classFile = pcall(UnitClass, unit)

    if ok and not IsSecretValue(classFile) then
        return classFile
    end

    return nil
end

local function GetUnitGUIDSafe(unit)
    if not unit or not UnitGUID then
        return nil
    end

    local ok, guid = pcall(UnitGUID, unit)

    if ok and not IsSecretValue(guid) then
        return guid
    end

    return nil
end

local function GetClassColor(classFile)
    if classFile and C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local ok, color = pcall(C_ClassColor.GetClassColor, classFile)

        if ok and color and type(color.GetRGB) == "function" then
            local rgbOk, r, g, b = pcall(color.GetRGB, color)

            if rgbOk and r and g and b then
                return r, g, b
            end
        end
    end

    local color = classFile
        and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))

    if color then
        return color.r or 1, color.g or 0.82, color.b or 0
    end

    return nil, nil, nil
end

local function ColorTooltipName(tooltip, unit)
    local db = EnsureDB()

    if not db or not db.classColoredNames then
        return
    end

    if not UnitIsPlayerSafe(unit) then
        return
    end

    local classFile = GetUnitClassFile(unit)
    local r, g, b = GetClassColor(classFile)

    if not r or not g or not b then
        return
    end

    local tooltipName = tooltip and tooltip.GetName and tooltip:GetName()
    local nameLine = tooltipName and _G[tooltipName .. "TextLeft1"]

    if nameLine and nameLine.SetTextColor then
        nameLine:SetTextColor(r, g, b)
    end
end

local function FormatScore(value)
    if IsSecretValue(value) then
        return nil
    end

    value = tonumber(value)

    if not value then
        return nil
    end

    value = math.floor(value + 0.5)

    if value <= 0 then
        return nil
    end

    return tostring(value)
end

local function NormalizePercentile(value)
    if value == nil or IsSecretValue(value) then
        return nil
    end

    value = tonumber(value)

    if not value then
        return nil
    end

    if value > 0 and value <= 1 then
        value = value * 100
    end

    if value < 0 or value > 100 then
        return nil
    end

    return value
end

local function FormatPercentile(value)
    value = NormalizePercentile(value)

    if not value then
        return nil
    end

    if value >= 99.95 then
        return "100%"
    end

    return string.format("%.1f%%", value)
end

local function GetPercentileColor(percentile)
    percentile = NormalizePercentile(percentile)

    if not percentile then
        return nil
    end

    local color

    if percentile >= 90 then
        color = PERCENTILE_COLORS.legendary
    elseif percentile >= 75 then
        color = PERCENTILE_COLORS.superior
    elseif percentile >= 40 then
        color = PERCENTILE_COLORS.uncommon
    else
        color = PERCENTILE_COLORS.common
    end

    return color[1], color[2], color[3]
end

local function GetRaiderIOProfile(unit)
    if not unit or not RaiderIO or type(RaiderIO.GetProfile) ~= "function" then
        return nil
    end

    local ok, profile = pcall(RaiderIO.GetProfile, unit)

    if ok and type(profile) == "table" then
        return profile
    end

    return nil
end

local function ExtractNumericField(source, keys)
    if type(source) ~= "table" then
        return nil
    end

    for _, key in ipairs(keys) do
        local value = source[key]

        if value ~= nil and not IsSecretValue(value) then
            local number = tonumber(value)

            if number then
                return number
            end
        end
    end

    return nil
end

local function FindPercentileValue(source, depth, visited)
    if type(source) ~= "table" or depth <= 0 then
        return nil
    end

    visited = visited or {}

    if visited[source] then
        return nil
    end

    visited[source] = true

    local percentile = ExtractNumericField(source, {
        "percentile",
        "scorePercentile",
        "currentPercentile",
        "currentScorePercentile",
        "rankPercentile",
        "overallPercentile",
        "overallScorePercentile",
        "mythicPlusPercentile",
        "mythicKeystonePercentile",
    })

    if NormalizePercentile(percentile) then
        return percentile
    end

    for _, key in ipairs({
        "mythicKeystoneProfile",
        "mythicPlusProfile",
        "mplusProfile",
        "current",
        "season",
        "seasonData",
    }) do
        percentile = FindPercentileValue(source[key], depth - 1, visited)

        if percentile then
            return percentile
        end
    end

    return nil
end

local function FindRaiderIOScoreValue(profile, depth, visited)
    if type(profile) ~= "table" or depth <= 0 then
        return nil
    end

    visited = visited or {}

    if visited[profile] then
        return nil
    end

    visited[profile] = true

    local score = ExtractNumericField(profile, {
        "currentScore",
        "mythicPlusScore",
        "mythicKeystoneScore",
        "score",
        "rating",
    })

    if score and score > 0 then
        return score
    end

    for _, key in ipairs({
        "mythicKeystoneProfile",
        "mythicPlusProfile",
        "mplusProfile",
        "current",
        "season",
        "seasonData",
    }) do
        score = FindRaiderIOScoreValue(profile[key], depth - 1, visited)

        if score and score > 0 then
            return score
        end
    end

    return nil
end

local function GetRaiderIOScoreColor(score)
    if not score or not RaiderIO or type(RaiderIO.GetScoreColor) ~= "function" then
        return nil
    end

    local ok, r, g, b = pcall(RaiderIO.GetScoreColor, score)

    if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
        return r, g, b
    end

    return nil
end

local function GetBlizzardScoreColor(score)
    if not score or not C_ChallengeMode or type(C_ChallengeMode.GetDungeonScoreRarityColor) ~= "function" then
        return nil
    end

    local ok, color = pcall(C_ChallengeMode.GetDungeonScoreRarityColor, score)

    if not ok or not color then
        return nil
    end

    if type(color.GetRGB) == "function" then
        local rgbOk, r, g, b = pcall(color.GetRGB, color)

        if rgbOk and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b
        end
    end

    if type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number" then
        return color.r, color.g, color.b
    end

    return nil
end

local function GetBlizzardMythicScore(unit)
    if not unit or not C_PlayerInfo or type(C_PlayerInfo.GetPlayerMythicPlusRatingSummary) ~= "function" then
        return nil
    end

    local ok, score = pcall(function()
        local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)

        if type(summary) ~= "table" then
            return nil
        end

        return summary.currentSeasonScore
            or summary.mythicPlusScore
            or summary.seasonScore
            or summary.score
            or summary.rating
    end)

    if ok and not IsSecretValue(score) then
        return tonumber(score)
    end

    return nil
end

local function GetMythicScoreDetails(unit)
    local profile = GetRaiderIOProfile(unit)
    local score = FindRaiderIOScoreValue(profile, 3) or GetBlizzardMythicScore(unit)

    if not score or score <= 0 then
        return nil
    end

    local percentile = FindPercentileValue(profile, 3)
    local scoreText = FormatScore(score)
    local percentileText = FormatPercentile(percentile)

    if not scoreText then
        return nil
    end

    local r, g, b

    if percentile then
        r, g, b = GetPercentileColor(percentile)
    end

    if not r then
        r, g, b = GetBlizzardScoreColor(score)
    end

    if not r then
        r, g, b = GetRaiderIOScoreColor(score)
    end

    return {
        score = scoreText,
        percentile = percentileText,
        r = r,
        g = g,
        b = b,
    }
end

local function GetCachedMythicScore(guid)
    if not guid or IsSecretValue(guid) then
        return nil, false
    end

    local cache = mythicScoreCache[guid]

    if not cache then
        return nil, false
    end

    if GetTime and cache.time and (GetTime() - cache.time) > MYTHIC_SCORE_CACHE_TIME then
        mythicScoreCache[guid] = nil
        return nil, false
    end

    if cache.details == false then
        return nil, true
    end

    return cache.details, true
end

local function CacheMythicScore(guid, details)
    if not guid or IsSecretValue(guid) then
        return
    end

    mythicScoreCache[guid] = {
        details = details or false,
        time = GetTime and GetTime() or 0,
    }

    PruneTimedCache(mythicScoreCache, MYTHIC_SCORE_CACHE_MAX_ENTRIES, MYTHIC_SCORE_CACHE_TIME)
end

local function GetTooltipMythicScore(unit, guid)
    if not unit then
        return nil
    end

    local cached, hasCache = GetCachedMythicScore(guid)

    if hasCache then
        return cached
    end

    if IsCombatLocked() then
        return nil
    end

    local details = GetMythicScoreDetails(unit)
    CacheMythicScore(guid, details)

    return details
end

local function GetItemLevelFromLink(itemLink)
    if not itemLink or IsSecretValue(itemLink) then
        return nil
    end

    local ok, itemLevel = pcall(function()
        if C_Item and type(C_Item.GetDetailedItemLevelInfo) == "function" then
            return C_Item.GetDetailedItemLevelInfo(itemLink)
        end

        if type(GetDetailedItemLevelInfo) == "function" then
            return GetDetailedItemLevelInfo(itemLink)
        end

        return nil
    end)

    if ok and not IsSecretValue(itemLevel) and type(itemLevel) == "number" and itemLevel > 0 then
        return itemLevel
    end

    return nil
end

local function RunNextFrame(callback)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, callback)
    else
        callback()
    end
end

local function IsInspectUIBusy()
    if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then
        return true
    end

    if PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting() then
        return true
    end

    return false
end

local function GetCachedPlayerItemLevel()
    local now = GetTime and GetTime() or 0

    if playerItemLevelCache
        and playerItemLevelCache.time
        and (now - playerItemLevelCache.time) <= PLAYER_ITEM_LEVEL_CACHE_TIME
    then
        return playerItemLevelCache.itemLevel
    end

    local ok, overall, equipped = pcall(GetAverageItemLevel)
    local itemLevel = equipped or overall

    if ok and not IsSecretValue(itemLevel) and type(itemLevel) == "number" and itemLevel > 0 then
        playerItemLevelCache = {
            itemLevel = itemLevel,
            time = now,
        }

        return itemLevel
    end

    return nil
end

local function CalculateEquippedItemLevel(unit)
    if not unit then
        return nil
    end

    if UnitIsUnitSafe(unit, "player") then
        return GetCachedPlayerItemLevel()
    end

    local ok, inspectLevel = pcall(function()
        if C_PaperDollInfo and type(C_PaperDollInfo.GetInspectItemLevel) == "function" then
            return C_PaperDollInfo.GetInspectItemLevel(unit)
        end

        return nil
    end)

    if ok and not IsSecretValue(inspectLevel) and type(inspectLevel) == "number" and inspectLevel > 0 then
        return inspectLevel
    end

    if not GetInventoryItemLink then
        return nil
    end

    local total = 0
    local count = 0

    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local linkOk, itemLink = pcall(GetInventoryItemLink, unit, slot)
        local itemLevel = linkOk and not IsSecretValue(itemLink) and GetItemLevelFromLink(itemLink) or nil

        if itemLevel then
            total = total + itemLevel
            count = count + 1
        end
    end

    if count >= MIN_FALLBACK_EQUIPPED_ITEMS then
        return total / count
    end

    return nil
end

local function GetCachedItemLevel(guid)
    if not guid or IsSecretValue(guid) then
        return nil
    end

    local cache = itemLevelCache[guid]

    if not cache then
        return nil
    end

    if GetTime and cache.time and (GetTime() - cache.time) > ITEM_LEVEL_CACHE_TIME then
        itemLevelCache[guid] = nil
        return nil
    end

    return cache.itemLevel
end

local function CacheItemLevel(guid, itemLevel)
    if not guid or IsSecretValue(guid) or not itemLevel or IsSecretValue(itemLevel) then
        return
    end

    itemLevelCache[guid] = {
        itemLevel = itemLevel,
        time = GetTime and GetTime() or 0,
    }

    PruneTimedCache(itemLevelCache, ITEM_LEVEL_CACHE_MAX_ENTRIES, ITEM_LEVEL_CACHE_TIME)
end

local function FinishPendingInspect(guid)
    if not guid or IsSecretValue(guid) then
        return
    end

    pendingInspects[guid] = nil

    if activeInspectGuid == guid then
        activeInspectGuid = nil
    end

    if IsCombatLocked() then
        return
    end

    if ClearInspectPlayer and not IsInspectUIBusy() then
        RunNextFrame(function()
            if not activeInspectGuid and ClearInspectPlayer and not IsInspectUIBusy() then
                pcall(ClearInspectPlayer)
            end
        end)
    end
end

local function TryCacheItemLevel(unit, guid)
    if not unit or not guid or IsSecretValue(guid) then
        return nil
    end

    if GetUnitGUIDSafe(unit) ~= guid then
        return nil
    end

    local itemLevel = CalculateEquippedItemLevel(unit)

    if itemLevel then
        CacheItemLevel(guid, itemLevel)
        return itemLevel
    end

    return nil
end

local function RetryInspectResult(guid, attempt)
    if not guid or IsSecretValue(guid) then
        return
    end

    local pending = guid and pendingInspects[guid]

    if not pending then
        return
    end

    if IsCombatLocked() then
        FinishPendingInspect(guid)
        return
    end

    local unit = pending.unit

    if GetUnitGUIDSafe(unit) ~= guid then
        FinishPendingInspect(guid)
        return
    end

    local itemLevel = TryCacheItemLevel(unit, guid)

    if itemLevel then
        FinishPendingInspect(guid)

        if RefreshCurrentTooltipForGUID then
            RefreshCurrentTooltipForGUID(guid)
        end

        return
    end

    if attempt < INSPECT_RESULT_RETRIES and C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(INSPECT_RESULT_RETRY_STEP, function()
            RetryInspectResult(guid, attempt + 1)
        end)
    else
        FinishPendingInspect(guid)
    end
end

local function RequestInspectIfNeeded(unit, guid, priority)
    if not IsTooltipItemLevelEnabled() or not unit or not guid or IsSecretValue(guid) or pendingInspects[guid] then
        return
    end

    if not CanInspect or not NotifyInspect or IsCombatLocked() or IsInspectUIBusy() then
        return
    end

    local now = GetTime and GetTime() or 0
    local cache = itemLevelCache[guid]

    if cache and cache.lastRequest and (now - cache.lastRequest) < INSPECT_RETRY_DELAY then
        return
    end

    if activeInspectGuid and activeInspectGuid ~= guid then
        local active = pendingInspects[activeInspectGuid]

        if not priority and active and active.requestedAt and (now - active.requestedAt) < INSPECT_PENDING_TIMEOUT then
            return
        end

        FinishPendingInspect(activeInspectGuid)
    end

    if not priority and (now - lastInspectRequest) < INSPECT_THROTTLE then
        return
    end

    local ok, canInspect = pcall(CanInspect, unit)

    if not ok or not canInspect then
        return
    end

    pendingInspects[guid] = {
        unit = unit,
        requestedAt = now,
    }
    activeInspectGuid = guid
    lastInspectRequest = now
    itemLevelCache[guid] = itemLevelCache[guid] or {}
    itemLevelCache[guid].lastRequest = now
    PruneTimedCache(itemLevelCache, ITEM_LEVEL_CACHE_MAX_ENTRIES, ITEM_LEVEL_CACHE_TIME)

    local inspectOk = pcall(NotifyInspect, unit)

    if not inspectOk then
        FinishPendingInspect(guid)
        return
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(INSPECT_PENDING_TIMEOUT, function()
            local pending = pendingInspects[guid]

            if pending and pending.requestedAt == now then
                RetryInspectResult(guid, INSPECT_RESULT_RETRIES)
            end
        end)
    end
end

local function PrefetchUnitItemLevel(unit)
    if IsCombatLocked() then
        return
    end

    if not IsTooltipItemLevelEnabled() or not UnitIsPlayerSafe(unit) or UnitIsUnitSafe(unit, "player") then
        return
    end

    local guid = GetUnitGUIDSafe(unit)

    if not guid or GetCachedItemLevel(guid) then
        return
    end

    if TryCacheItemLevel(unit, guid) then
        return
    end

    RequestInspectIfNeeded(unit, guid, false)
end

local function GetTooltipItemLevel(unit, guid)
    if not unit then
        return nil
    end

    if UnitIsUnitSafe(unit, "player") then
        return CalculateEquippedItemLevel(unit)
    end

    local cached = GetCachedItemLevel(guid)

    if cached then
        return cached
    end

    if IsCombatLocked() then
        return nil
    end

    local immediate = TryCacheItemLevel(unit, guid)

    if immediate then
        return immediate
    end

    RequestInspectIfNeeded(unit, guid, true)

    return nil
end

local function FormatItemLevel(itemLevel)
    if IsSecretValue(itemLevel) then
        return nil
    end

    itemLevel = tonumber(itemLevel)

    if not itemLevel or itemLevel <= 0 then
        return nil
    end

    return tostring(math.floor(itemLevel + 0.5))
end

local function AddTooltipDetails(tooltip, unit, guid)
    local db = EnsureDB()

    if not db or IsCombatLocked() or not UnitIsPlayerSafe(unit) then
        return
    end

    local mythicScore = db.showMythicScore and GetTooltipMythicScore(unit, guid) or nil
    local mythicScoreText = mythicScore and mythicScore.score or nil

    if mythicScoreText and db.showMythicPercentile and mythicScore.percentile then
        mythicScoreText = mythicScoreText .. " (" .. mythicScore.percentile .. ")"
    end

    local itemLevelValue = db.showItemLevel and GetTooltipItemLevel(unit, guid) or nil
    local itemLevel = FormatItemLevel(itemLevelValue)
    local itemLevelPending = db.showItemLevel
        and not itemLevel
        and guid
        and not IsSecretValue(guid)
        and pendingInspects[guid] ~= nil
    local detailsKey = (guid or "unknown")
        .. ":"
        .. (mythicScoreText or "")
        .. ":"
        .. (itemLevel or "")
        .. ":"
        .. (itemLevelPending and "pending" or "")

    if tooltip.ZoidsToolsDetailsKey == detailsKey then
        return
    end

    tooltip.ZoidsToolsDetailsKey = detailsKey

    local addedDetails = false

    if mythicScoreText then
        local r, g, b = 1, 1, 1

        if db.colorMythicScore and mythicScore and mythicScore.r and mythicScore.g and mythicScore.b then
            r, g, b = mythicScore.r, mythicScore.g, mythicScore.b
        end

        tooltip:AddDoubleLine("Mythic+ Score", mythicScoreText, 0.75, 0.85, 1, r, g, b)
        addedDetails = true
    end

    if itemLevel then
        tooltip:AddDoubleLine("Item Level", itemLevel, 1, 0.82, 0, 1, 1, 1)
        addedDetails = true
    elseif itemLevelPending then
        tooltip:AddDoubleLine("Item Level", "Inspecting...", 1, 0.82, 0, 0.65, 0.65, 0.65)
        addedDetails = true
    end

    if addedDetails and tooltip.Show then
        tooltip:Show()
    end
end

local function ApplyUnitTooltipStyleUnsafe(tooltip)
    if tooltip ~= GameTooltip then
        return
    end

    local unit = GetDisplayedUnit(tooltip)

    if not unit then
        ResetTooltipBackdrop(tooltip)
        return
    end

    local db = EnsureDB()
    local guid = GetUnitGUIDSafe(unit)

    if guid ~= tooltip.ZoidsToolsUnitGuid then
        tooltip.ZoidsToolsUnitGuid = guid
        tooltip.ZoidsToolsDetailsKey = nil
    end

    local faction = UnitIsPlayerSafe(unit) and GetFaction(unit) or GetFaction("player")
    local color = db and db.factionBackground and faction and FACTION_COLORS[faction]

    if color then
        SetBackdropColors(tooltip, color.bg, color.border)
        SetFactionTint(tooltip, color.tint)
    else
        ResetTooltipBackdrop(tooltip)
    end

    ColorTooltipName(tooltip, unit)
    AddTooltipDetails(tooltip, unit, guid)
end

local function ApplyUnitTooltipStyle(tooltip)
    pcall(ApplyUnitTooltipStyleUnsafe, tooltip)
end

RefreshCurrentTooltipForGUID = function(guid)
    if not guid or IsSecretValue(guid) or not GameTooltip or not GameTooltip:IsShown() or not UnitGUID then
        return
    end

    if IsCombatLocked() then
        return
    end

    local ok, mouseoverGuid = pcall(UnitGUID, "mouseover")

    if not ok or IsSecretValue(mouseoverGuid) or mouseoverGuid ~= guid then
        return
    end

    GameTooltip.ZoidsToolsDetailsKey = nil

    if type(GameTooltip.SetUnit) == "function" then
        pcall(GameTooltip.SetUnit, GameTooltip, "mouseover")
    else
        ApplyUnitTooltipStyle(GameTooltip)
    end
end

local function OnInspectReady(guid)
    if not guid or IsSecretValue(guid) or not pendingInspects[guid] then
        return
    end

    if IsCombatLocked() then
        FinishPendingInspect(guid)
        return
    end

    RetryInspectResult(guid, 0)
end

local function HookTooltipScript(scriptName, handler)
    if not GameTooltip or type(GameTooltip.HookScript) ~= "function" then
        return false
    end

    if type(GameTooltip.HasScript) == "function" then
        local ok, hasScript = pcall(GameTooltip.HasScript, GameTooltip, scriptName)

        if ok and not hasScript then
            return false
        end
    end

    local ok = pcall(GameTooltip.HookScript, GameTooltip, scriptName, handler)

    return ok
end

local function RefreshCurrentTooltip()
    if IsCombatLocked() then
        return
    end

    if GameTooltip and GameTooltip:IsShown() then
        local unit = GetDisplayedUnit(GameTooltip)

        GameTooltip.ZoidsToolsDetailsKey = nil

        if unit and type(GameTooltip.SetUnit) == "function" then
            pcall(GameTooltip.SetUnit, GameTooltip, unit)
        else
            ApplyUnitTooltipStyle(GameTooltip)
        end
    end
end

function ns:IsTooltipFactionBackgroundEnabled()
    local db = EnsureDB()
    return db and db.factionBackground == true
end

function ns:SetTooltipFactionBackgroundEnabled(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.factionBackground = value == true
    RefreshCurrentTooltip()
end

function ns:IsTooltipClassColoredNamesEnabled()
    local db = EnsureDB()
    return db and db.classColoredNames == true
end

function ns:SetTooltipClassColoredNamesEnabled(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.classColoredNames = value == true
    RefreshCurrentTooltip()
end

function ns:IsTooltipMythicScoreEnabled()
    local db = EnsureDB()
    return db and db.showMythicScore == true
end

function ns:SetTooltipMythicScoreEnabled(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.showMythicScore = value == true
    RefreshCurrentTooltip()
end

function ns:IsTooltipMythicScoreColorEnabled()
    local db = EnsureDB()
    return db and db.colorMythicScore == true
end

function ns:SetTooltipMythicScoreColorEnabled(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.colorMythicScore = value == true
    RefreshCurrentTooltip()
end

function ns:IsTooltipMythicPercentileEnabled()
    local db = EnsureDB()
    return db and db.showMythicPercentile == true
end

function ns:SetTooltipMythicPercentileEnabled(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.showMythicPercentile = value == true
    RefreshCurrentTooltip()
end

function ns:IsTooltipItemLevelEnabled()
    local db = EnsureDB()
    return db and db.showItemLevel == true
end

function ns:SetTooltipItemLevelEnabled(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.showItemLevel = value == true
    RefreshCurrentTooltip()
end

function ns:InitializeTooltips()
    if initialized then
        return
    end

    initialized = true

    if not GameTooltip then
        return
    end

    ResetTooltipState(GameTooltip)

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("INSPECT_READY")
    eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    eventFrame:SetScript("OnEvent", function(_, event, guid)
        if event == "INSPECT_READY" then
            OnInspectReady(guid)
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            if not IsCombatLocked() then
                PrefetchUnitItemLevel("mouseover")
            end
        end
    end)

    local hasUnitPostCall = false

    if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        hasUnitPostCall = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tooltip)
            ApplyUnitTooltipStyle(tooltip)
        end)
    end

    if not hasUnitPostCall then
        HookTooltipScript("OnShow", ApplyUnitTooltipStyle)
        HookTooltipScript("OnTooltipSetUnit", ApplyUnitTooltipStyle)
    end

    HookTooltipScript("OnTooltipCleared", ResetTooltipState)
    HookTooltipScript("OnHide", ResetTooltipState)
end
