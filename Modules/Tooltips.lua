local _, ns = ...

local initialized = false
local eventFrame
local itemLevelCache = {}
local mythicScoreCache = {}
local pendingInspects = {}
local activeInspectGuid
local lastInspectRequest = 0
local unitDetailsPanel
local RefreshCurrentTooltipForGUID
local RefreshCurrentTooltip
local PositionUnitDetailsPanel
local UpdateUnitDetailsPanel

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

local function GetNativeFactionTint(tooltip)
    if not tooltip or type(tooltip.CreateTexture) ~= "function" then
        return nil
    end

    if tooltip.ZoidsToolsFactionTint then
        return tooltip.ZoidsToolsFactionTint
    end

    -- Blizzard's current tooltip background is textured artwork rather than a
    -- plain backdrop. A translucent layer above that artwork provides the
    -- faction color while preserving Blizzard's texture, shape, and border.
    local tint = tooltip:CreateTexture(nil, "BORDER", nil, -7)
    tint:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 4, -4)
    tint:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -4, 4)
    tint:SetColorTexture(0, 0, 0, 0)
    tint:Hide()
    tooltip.ZoidsToolsFactionTint = tint

    if type(tooltip.HookScript) == "function" then
        tooltip:HookScript("OnTooltipCleared", function(self)
            local currentTint = self.ZoidsToolsFactionTint

            if currentTint then
                currentTint:Hide()
            end
        end)
    end

    return tint
end

local function SetNativeFactionTint(tooltip, color)
    local tint = GetNativeFactionTint(tooltip)

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

local function ApplyNativeUnitTooltipAppearance(tooltip, unit)
    local db = EnsureDB()

    if not db or tooltip ~= GameTooltip or IsCombatLocked() or not UnitIsPlayerSafe(unit) then
        return
    end

    if db.factionBackground then
        local faction = GetFaction(unit)
        local color = faction and FACTION_COLORS[faction]

        if color then
            if type(tooltip.SetBackdropColor) == "function" then
                tooltip:SetBackdropColor(color.bg[1], color.bg[2], color.bg[3], color.bg[4])
            end

            if type(tooltip.SetBackdropBorderColor) == "function" then
                tooltip:SetBackdropBorderColor(color.border[1], color.border[2], color.border[3], color.border[4])
            end

            SetNativeFactionTint(tooltip, color.tint)
        else
            SetNativeFactionTint(tooltip, nil)
        end
    else
        SetNativeFactionTint(tooltip, nil)
    end

    if db.classColoredNames then
        local r, g, b = GetClassColor(GetUnitClassFile(unit))
        local tooltipName = tooltip.GetName and tooltip:GetName()
        local nameLine = tooltipName and _G[tooltipName .. "TextLeft1"]

        if r and g and b and nameLine and type(nameLine.SetTextColor) == "function" then
            nameLine:SetTextColor(r, g, b)
        end
    end
end

-- Keep unit tooltips native. Blizzard rebuilds the shared GameTooltip several
-- times while a unit is hovered, so hiding it and drawing a synchronized copy
-- causes visible flicker and can expose stale geometry. Extra information is
-- appended through Blizzard's normal tooltip layout instead.
local function AddNativeUnitTooltipDetails(tooltip, unit, guid)
    local db = EnsureDB()

    if not db or tooltip ~= GameTooltip or IsCombatLocked() or not UnitIsPlayerSafe(unit) then
        return
    end

    ApplyNativeUnitTooltipAppearance(tooltip, unit)

    guid = guid or GetUnitGUIDSafe(unit)

    if not guid then
        return
    end

    local mythicScore = db.showMythicScore and GetTooltipMythicScore(unit, guid) or nil
    local mythicScoreText = mythicScore and mythicScore.score or nil

    if mythicScoreText and db.showMythicPercentile and mythicScore.percentile then
        mythicScoreText = mythicScoreText .. " (" .. mythicScore.percentile .. ")"
    end

    if mythicScoreText then
        local r, g, b = 1, 1, 1

        if db.colorMythicScore and mythicScore.r and mythicScore.g and mythicScore.b then
            r, g, b = mythicScore.r, mythicScore.g, mythicScore.b
        end

        tooltip:AddDoubleLine("Mythic+ Score", mythicScoreText, 0.75, 0.85, 1, r, g, b)
    end

    local itemLevel = db.showItemLevel and FormatItemLevel(GetTooltipItemLevel(unit, guid)) or nil

    if itemLevel then
        tooltip:AddDoubleLine("Item Level", itemLevel, 1, 0.82, 0, 1, 1, 1)
    end
end

local function GetTooltipStatusBar(tooltip)
    if not tooltip then
        return nil
    end

    if tooltip.StatusBar then
        return tooltip.StatusBar
    end

    local tooltipName = tooltip.GetName and tooltip:GetName()

    return tooltipName and _G[tooltipName .. "StatusBar"] or nil
end

local function SetFrameAlphaSafe(frame, alpha)
    if frame and type(frame.SetAlpha) == "function" then
        pcall(frame.SetAlpha, frame, alpha)
    end
end

local function SuppressBlizzardUnitTooltip(panel)
    local tooltip = panel and panel.tooltip

    if not tooltip then
        return
    end

    local statusBar = GetTooltipStatusBar(tooltip)

    if panel.originalTooltipAlpha == nil and type(tooltip.GetAlpha) == "function" then
        local ok, alpha = pcall(tooltip.GetAlpha, tooltip)

        if ok and not IsSecretValue(alpha) then
            panel.originalTooltipAlpha = tonumber(alpha) or 1
        end
    end

    if statusBar and panel.originalStatusBarAlpha == nil and type(statusBar.GetAlpha) == "function" then
        local ok, alpha = pcall(statusBar.GetAlpha, statusBar)

        if ok and not IsSecretValue(alpha) then
            panel.originalStatusBarAlpha = tonumber(alpha) or 1
        end
    end

    SetFrameAlphaSafe(tooltip, 0)
    SetFrameAlphaSafe(statusBar, 0)
end

local function RestoreBlizzardUnitTooltip(panel)
    if not panel then
        return
    end

    local tooltip = panel.tooltip
    local statusBar = GetTooltipStatusBar(tooltip)

    SetFrameAlphaSafe(tooltip, panel.originalTooltipAlpha or 1)
    SetFrameAlphaSafe(statusBar, panel.originalStatusBarAlpha or 1)
    panel.originalTooltipAlpha = nil
    panel.originalStatusBarAlpha = nil
end

local function HideUnitDetailsPanel()
    if unitDetailsPanel then
        RestoreBlizzardUnitTooltip(unitDetailsPanel)
        unitDetailsPanel.guid = nil
        unitDetailsPanel.detailsKey = nil
        unitDetailsPanel.sourceLineCount = nil
        unitDetailsPanel.tooltip = nil
        unitDetailsPanel:Hide()
    end
end

local function GetSafeText(fontString)
    if not fontString or type(fontString.GetText) ~= "function" then
        return nil
    end

    local ok, text = pcall(fontString.GetText, fontString)

    if not ok or IsSecretValue(text) or type(text) ~= "string" or text == "" then
        return nil
    end

    return text
end


local function GetSafeTextColor(fontString, defaultR, defaultG, defaultB)
    if not fontString or type(fontString.GetTextColor) ~= "function" then
        return defaultR, defaultG, defaultB
    end

    local ok, r, g, b = pcall(fontString.GetTextColor, fontString)

    if not ok or IsSecretValue(r) or IsSecretValue(g) or IsSecretValue(b) then
        return defaultR, defaultG, defaultB
    end

    r, g, b = tonumber(r), tonumber(g), tonumber(b)

    if not r or not g or not b then
        return defaultR, defaultG, defaultB
    end

    return r, g, b
end


local function EnsurePanelLine(panel, index)
    local line = panel.lines[index]

    if line then
        return line
    end

    line = {
        left = panel:CreateFontString(nil, "OVERLAY", "GameTooltipText"),
        right = panel:CreateFontString(nil, "OVERLAY", "GameTooltipText"),
    }
    line.left:SetJustifyH("LEFT")
    line.left:SetJustifyV("TOP")
    line.left:SetWordWrap(true)
    line.right:SetJustifyH("RIGHT")
    line.right:SetJustifyV("TOP")
    line.right:SetWordWrap(false)
    panel.lines[index] = line

    return line
end


local function HideUnusedPanelLines(panel, firstUnused)
    for index = firstUnused, #panel.lines do
        panel.lines[index].left:Hide()
        panel.lines[index].right:Hide()
    end
end

local function EnsureUnitDetailsPanel()
    if unitDetailsPanel then
        return unitDetailsPanel
    end

    local panel = CreateFrame("Frame", "ZoidsToolsUnitTooltipDetails", UIParent, "BackdropTemplate")
    panel:SetSize(230, 34)
    panel:SetFrameStrata("TOOLTIP")
    panel:SetFrameLevel(1000)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(false)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(unpack(DEFAULT_BG))
    panel:SetBackdropBorderColor(unpack(DEFAULT_BORDER))

    panel.lines = {}

    panel:SetScript("OnUpdate", function(self, elapsed)
        local tooltip = self.tooltip
        local unit = tooltip and GetDisplayedUnit(tooltip)
        local guid = unit and GetUnitGUIDSafe(unit)

        if not tooltip or not tooltip:IsShown() or not unit or not guid or guid ~= self.guid or not UnitIsPlayerSafe(unit) then
            HideUnitDetailsPanel()
            return
        end

        -- Blizzard may restore the shared tooltip and its separately-owned
        -- status bar after the unit post-call. Maintain suppression for the
        -- entire lifetime of this addon-owned replacement.
        SuppressBlizzardUnitTooltip(self)

        self.watchElapsed = (self.watchElapsed or 0) + elapsed

        if self.watchElapsed < 0.05 then
            return
        end

        self.watchElapsed = 0

        local ok, sourceLineCount = pcall(tooltip.NumLines, tooltip)

        if ok and not IsSecretValue(sourceLineCount) then
            sourceLineCount = tonumber(sourceLineCount) or 0

            -- Unit-frame instructions are appended after the unit post-call.
            -- Rebuild when Blizzard adds them so they become part of the one
            -- visible replacement rather than showing beneath it.
            if sourceLineCount > 0 and sourceLineCount ~= self.sourceLineCount then
                UpdateUnitDetailsPanel(tooltip, unit, guid)
                return
            end
        end

        PositionUnitDetailsPanel(self)
    end)

    panel:Hide()
    unitDetailsPanel = panel

    return panel
end

PositionUnitDetailsPanel = function(panel)
    local tooltip = panel and panel.tooltip

    if not panel or not tooltip or not UIParent or not tooltip.IsShown or not tooltip:IsShown() then
        HideUnitDetailsPanel()
        return false
    end

    -- Never anchor the addon frame to GameTooltip. Blizzard reuses that
    -- tooltip for map widgets whose geometry becomes secret in 12.1. Read
    -- ordinary unit-tooltip geometry and place this UIParent-owned overlay
    -- at the same absolute screen position instead.
    local left = tooltip.GetLeft and tooltip:GetLeft()
    local bottom = tooltip.GetBottom and tooltip:GetBottom()
    local top = tooltip.GetTop and tooltip:GetTop()
    local width = tooltip.GetWidth and tooltip:GetWidth()
    local tooltipScale = tooltip.GetEffectiveScale and tooltip:GetEffectiveScale()
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()

    if IsSecretValue(left)
        or IsSecretValue(bottom)
        or IsSecretValue(top)
        or IsSecretValue(width)
        or IsSecretValue(tooltipScale)
        or IsSecretValue(parentScale)
    then
        HideUnitDetailsPanel()
        return false
    end

    left = tonumber(left)
    bottom = tonumber(bottom)
    top = tonumber(top)
    width = tonumber(width)
    tooltipScale = tonumber(tooltipScale)
    parentScale = tonumber(parentScale)

    if not left or not bottom or not top or not width or not tooltipScale or not parentScale or parentScale <= 0 then
        HideUnitDetailsPanel()
        return false
    end

    local ratio = tooltipScale / parentScale
    local panelLeft = left * ratio
    local panelBottom = bottom * ratio
    local panelTop = top * ratio
    local panelWidth = math.max(190, width * ratio)
    local panelHeight = panel.GetHeight and panel:GetHeight() or 34

    if IsSecretValue(panelHeight) then
        HideUnitDetailsPanel()
        return false
    end

    panelHeight = tonumber(panelHeight) or 34
    panel:SetWidth(panelWidth)
    panel:ClearAllPoints()

    if panelTop >= panelHeight then
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", panelLeft, panelTop)
    else
        panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", panelLeft, panelBottom)
    end

    return true
end

local function AddPanelLine(panel, index, topOffset, leftText, rightText, leftR, leftG, leftB, rightR, rightG, rightB, isHeader)
    local line = EnsurePanelLine(panel, index)
    local left = line.left
    local right = line.right
    local contentWidth = math.max(150, panel:GetWidth() - 16)
    local rightWidth = rightText and math.min(contentWidth * 0.42, math.max(42, (#rightText * 7) + 4)) or 0

    left:ClearAllPoints()
    right:ClearAllPoints()
    left:SetFontObject(isHeader and GameTooltipHeaderText or GameTooltipText)
    right:SetFontObject(GameTooltipText)
    left:SetText(leftText or "")
    left:SetTextColor(leftR or 1, leftG or 1, leftB or 1)
    left:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -topOffset)

    if rightText then
        right:SetText(rightText)
        right:SetTextColor(rightR or 1, rightG or 1, rightB or 1)
        right:SetWidth(rightWidth)
        right:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -topOffset)
        right:Show()
        left:SetWidth(math.max(40, contentWidth - rightWidth - 8))
    else
        right:SetText("")
        right:Hide()
        left:SetWidth(contentWidth)
    end

    left:Show()

    local leftHeight = left:GetStringHeight()
    local rightHeight = rightText and right:GetStringHeight() or 0

    if IsSecretValue(leftHeight) or IsSecretValue(rightHeight) then
        return isHeader and 16 or 14
    end

    return math.max(2, tonumber(leftHeight) or 0, tonumber(rightHeight) or 0)
end


local function CopyBlizzardUnitTooltipLines(panel, tooltip, classR, classG, classB)
    local tooltipName = tooltip and tooltip.GetName and tooltip:GetName()
    local lineCount = tooltip and tooltip.NumLines and tooltip:NumLines()

    if not tooltipName or IsSecretValue(lineCount) then
        return 0, 8
    end

    lineCount = tonumber(lineCount) or 0
    local outputIndex = 0
    local topOffset = 7
    local deferredInstruction

    for sourceIndex = 1, lineCount do
        local sourceLeft = _G[tooltipName .. "TextLeft" .. sourceIndex]
        local sourceRight = _G[tooltipName .. "TextRight" .. sourceIndex]
        local leftText = GetSafeText(sourceLeft)
        local rightText = GetSafeText(sourceRight)

        if leftText or rightText then
            local leftR, leftG, leftB = GetSafeTextColor(sourceLeft, 1, 1, 1)
            local rightR, rightG, rightB = GetSafeTextColor(sourceRight, 1, 1, 1)
            local isFinalGreenInstruction = sourceIndex == lineCount
                and leftText
                and not rightText
                and leftG > 0.7
                and leftR < 0.45
                and leftB < 0.45

            if isFinalGreenInstruction then
                deferredInstruction = {
                    text = leftText,
                    r = leftR,
                    g = leftG,
                    b = leftB,
                }
            else
                outputIndex = outputIndex + 1

                if outputIndex == 1 and classR and classG and classB then
                    leftR, leftG, leftB = classR, classG, classB
                end

                local rowHeight = AddPanelLine(
                    panel,
                    outputIndex,
                    topOffset,
                    leftText or "",
                    rightText,
                    leftR,
                    leftG,
                    leftB,
                    rightR,
                    rightG,
                    rightB,
                    outputIndex == 1
                )
                topOffset = topOffset + rowHeight + 1
            end
        end
    end

    return outputIndex, topOffset, deferredInstruction
end


UpdateUnitDetailsPanel = function(tooltip, unit, guid)
    local db = EnsureDB()

    if not db or tooltip ~= GameTooltip or IsCombatLocked() or not UnitIsPlayerSafe(unit) then
        HideUnitDetailsPanel()
        return
    end

    guid = guid or GetUnitGUIDSafe(unit)

    if not guid then
        HideUnitDetailsPanel()
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
    local detailsKey = guid
        .. ":"
        .. (mythicScoreText or "")
        .. ":"
        .. (itemLevel or "")
        .. ":"
        .. (itemLevelPending and "pending" or "")
        .. ":"
        .. tostring(db.factionBackground == true)
        .. ":"
        .. tostring(db.classColoredNames == true)

    local panel = EnsureUnitDetailsPanel()

    panel.guid = guid
    panel.tooltip = tooltip
    panel.detailsKey = detailsKey

    local classR, classG, classB

    if db.classColoredNames then
        classR, classG, classB = GetClassColor(GetUnitClassFile(unit))
    end

    local factionColor = db.factionBackground and FACTION_COLORS[GetFaction(unit)] or nil

    if factionColor then
        panel:SetBackdropColor(factionColor.bg[1], factionColor.bg[2], factionColor.bg[3], 0.98)
        panel:SetBackdropBorderColor(unpack(factionColor.border))
    else
        panel:SetBackdropColor(DEFAULT_BG[1], DEFAULT_BG[2], DEFAULT_BG[3], 0.98)
        panel:SetBackdropBorderColor(unpack(DEFAULT_BORDER))
    end

    local tooltipWidth = tooltip.GetWidth and tooltip:GetWidth()
    local tooltipScale = tooltip.GetEffectiveScale and tooltip:GetEffectiveScale()
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()

    if IsSecretValue(tooltipWidth) or IsSecretValue(tooltipScale) or IsSecretValue(parentScale) then
        HideUnitDetailsPanel()
        return
    end

    tooltipWidth = tonumber(tooltipWidth)
    tooltipScale = tonumber(tooltipScale)
    parentScale = tonumber(parentScale)

    if not tooltipWidth or not tooltipScale or not parentScale or parentScale <= 0 then
        HideUnitDetailsPanel()
        return
    end

    panel:SetWidth(math.max(190, tooltipWidth * tooltipScale / parentScale))

    local lineIndex, topOffset, deferredInstruction = CopyBlizzardUnitTooltipLines(panel, tooltip, classR, classG, classB)
    local lineCountOK, sourceLineCount = pcall(tooltip.NumLines, tooltip)

    if lineCountOK and not IsSecretValue(sourceLineCount) then
        panel.sourceLineCount = tonumber(sourceLineCount) or lineIndex
    else
        panel.sourceLineCount = lineIndex
    end

    if mythicScoreText then
        local r, g, b = 1, 1, 1

        if db.colorMythicScore and mythicScore and mythicScore.r and mythicScore.g and mythicScore.b then
            r, g, b = mythicScore.r, mythicScore.g, mythicScore.b
        end

        lineIndex = lineIndex + 1
        topOffset = topOffset + AddPanelLine(panel, lineIndex, topOffset, "Mythic+ Score", mythicScoreText, 0.75, 0.85, 1, r, g, b, false) + 2
    end

    if itemLevel then
        lineIndex = lineIndex + 1
        topOffset = topOffset + AddPanelLine(panel, lineIndex, topOffset, "Item Level", itemLevel, 1, 0.82, 0, 1, 1, 1, false) + 2
    elseif itemLevelPending then
        lineIndex = lineIndex + 1
        topOffset = topOffset + AddPanelLine(panel, lineIndex, topOffset, "Item Level", "Inspecting...", 1, 0.82, 0, 0.65, 0.65, 0.65, false) + 2
    end

    if deferredInstruction then
        lineIndex = lineIndex + 1
        topOffset = topOffset + AddPanelLine(
            panel,
            lineIndex,
            topOffset,
            deferredInstruction.text,
            nil,
            deferredInstruction.r,
            deferredInstruction.g,
            deferredInstruction.b,
            1,
            1,
            1,
            false
        ) + 1
    end

    if lineIndex == 0 then
        HideUnitDetailsPanel()
        return
    end

    HideUnusedPanelLines(panel, lineIndex + 1)
    -- Extra lower padding fully masks Blizzard's separate unit status bar if
    -- it is briefly restored between frame updates.
    panel:SetHeight(math.max(24, topOffset + 11))

    if PositionUnitDetailsPanel(panel) then
        panel:Show()

        -- The addon-owned player tooltip is a complete visual replacement.
        -- Hide Blizzard's rendering while it is active so its status bar and
        -- borders cannot peek out around the replacement. OnUpdate restores
        -- the shared tooltip immediately when its unit changes or it closes.
        SuppressBlizzardUnitTooltip(panel)
    end
end

RefreshCurrentTooltipForGUID = function(guid)
    -- Inspect results are cached for the next native tooltip build. Mutating a
    -- currently visible shared GameTooltip here makes Blizzard immediately
    -- rebuild it and is the source of the previous hover flicker.
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

RefreshCurrentTooltip = function()
    -- Settings are reflected the next time Blizzard builds a unit tooltip.
    -- Deliberately do not repaint or replace the tooltip while it is visible.
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

    if TooltipDataProcessor
        and TooltipDataProcessor.AddTooltipPostCall
        and Enum
        and Enum.TooltipDataType
        and Enum.TooltipDataType.Unit
    then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            if tooltip ~= GameTooltip then
                return
            end

            local unit = GetDisplayedUnit(tooltip)

            if not UnitIsPlayerSafe(unit) then
                return
            end

            if not IsCombatLocked() then
                PrefetchUnitItemLevel(unit)
            end

            pcall(AddNativeUnitTooltipDetails, tooltip, unit, GetUnitGUIDSafe(unit))
        end)
    end

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
end
