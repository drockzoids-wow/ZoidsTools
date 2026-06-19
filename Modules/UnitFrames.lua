local _, ns = ...

local eventFrame
local initialized = false
local healthHooks = {}
local castbarHooks = {}
local auraHooks = {}
local originalHealthColors = {}
local originalCastbarState = {}
local originalAuraState = {}
local pendingProtectedRefresh = false

local DEFAULT_CASTBAR_WIDTH = 195
local DEFAULT_CASTBAR_HEIGHT = 16
local CLASS_HEALTH_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

local frameOrder = { "player", "target", "focus" }
local auraFrameOrder = { "target", "focus" }

local fallbackClassColors = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE = { r = 1, g = 0.96, b = 0.41 },
    PRIEST = { r = 1, g = 1, b = 1 },
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
    SHAMAN = { r = 0, g = 0.44, b = 0.87 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
    MONK = { r = 0, g = 1, b = 0.6 },
    DRUID = { r = 1, g = 0.49, b = 0.04 },
    DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },
    EVOKER = { r = 0.2, g = 0.58, b = 0.5 },
}

local healthBars = {
    player = {
        unit = "player",
        paths = {
            "PlayerFrameHealthBar",
            "PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar",
            "PlayerFrame.healthbar",
            "PlayerFrame.HealthBar",
        },
    },
    target = {
        unit = "target",
        paths = {
            "TargetFrameHealthBar",
            "TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar",
            "TargetFrame.healthbar",
            "TargetFrame.HealthBar",
        },
    },
    targettarget = {
        unit = "targettarget",
        paths = {
            "TargetFrameToTHealthBar",
            "TargetFrameToT.HealthBar",
            "TargetFrameToT.healthbar",
        },
    },
    focus = {
        unit = "focus",
        paths = {
            "FocusFrameHealthBar",
            "FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar",
            "FocusFrame.healthbar",
            "FocusFrame.HealthBar",
        },
    },
}

local castbars = {
    player = {
        paths = {
            "PlayerCastingBarFrame",
        },
    },
    target = {
        paths = {
            "TargetFrameSpellBar",
            "TargetFrame.spellbar",
            "TargetFrame.SpellBar",
        },
    },
    focus = {
        paths = {
            "FocusFrameSpellBar",
            "FocusFrame.spellbar",
            "FocusFrame.SpellBar",
        },
    },
}

local auraTargets = {
    target = {
        roots = {
            "TargetFrame",
        },
        buffs = {
            paths = {
                "TargetFrame.BuffFrame",
                "TargetFrame.Buffs",
                "TargetFrame.TargetFrameContent.TargetFrameContentMain.BuffFrame",
            },
            prefixes = {
                "TargetFrameBuff",
            },
            patterns = {
                "Buff",
            },
        },
        debuffs = {
            paths = {
                "TargetFrame.DebuffFrame",
                "TargetFrame.Debuffs",
                "TargetFrame.TargetFrameContent.TargetFrameContentMain.DebuffFrame",
            },
            prefixes = {
                "TargetFrameDebuff",
            },
            patterns = {
                "Debuff",
            },
        },
    },
    focus = {
        roots = {
            "FocusFrame",
        },
        buffs = {
            paths = {
                "FocusFrame.BuffFrame",
                "FocusFrame.Buffs",
                "FocusFrame.TargetFrameContent.TargetFrameContentMain.BuffFrame",
            },
            prefixes = {
                "FocusFrameBuff",
            },
            patterns = {
                "Buff",
            },
        },
        debuffs = {
            paths = {
                "FocusFrame.DebuffFrame",
                "FocusFrame.Debuffs",
                "FocusFrame.TargetFrameContent.TargetFrameContentMain.DebuffFrame",
            },
            prefixes = {
                "FocusFrameDebuff",
            },
            patterns = {
                "Debuff",
            },
        },
    },
}

local function Clamp(value, minValue, maxValue, fallback)
    value = tonumber(value) or fallback

    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end

    return value
end

local function EnsureFrameDB(db, key)
    db.frames = db.frames or {}
    db.frames[key] = db.frames[key] or {}

    local frameDB = db.frames[key]

    if frameDB.hideBuffs == nil then
        frameDB.hideBuffs = false
    end

    if frameDB.hideDebuffs == nil then
        frameDB.hideDebuffs = false
    end

    frameDB.castbar = frameDB.castbar or {}

    if frameDB.castbar.enabled == nil then
        frameDB.castbar.enabled = false
    end

    frameDB.castbar.width = Clamp(frameDB.castbar.width, 120, 420, DEFAULT_CASTBAR_WIDTH)
    frameDB.castbar.height = Clamp(frameDB.castbar.height, 8, 40, DEFAULT_CASTBAR_HEIGHT)

    return frameDB
end

local function EnsureDB()
    if not ns.db then
        return nil
    end

    ns.db.unitFrames = ns.db.unitFrames or {}

    local db = ns.db.unitFrames

    if db.classColorHealth == nil then
        db.classColorHealth = false
    end

    for _, key in ipairs(frameOrder) do
        EnsureFrameDB(db, key)
    end

    if db.castbar then
        for _, key in ipairs(frameOrder) do
            local frameDB = EnsureFrameDB(db, key)

            if frameDB.castbar.enabled == false and db.castbar.enabled ~= nil then
                frameDB.castbar.enabled = db.castbar.enabled == true
            end

            if frameDB.castbar.width == DEFAULT_CASTBAR_WIDTH and db.castbar.width then
                frameDB.castbar.width = Clamp(db.castbar.width, 120, 420, DEFAULT_CASTBAR_WIDTH)
            end

            if frameDB.castbar.height == DEFAULT_CASTBAR_HEIGHT and db.castbar.height then
                frameDB.castbar.height = Clamp(db.castbar.height, 8, 40, DEFAULT_CASTBAR_HEIGHT)
            end
        end

        db.castbar = nil
    end

    if db.hideAuras then
        for key, value in pairs(db.hideAuras) do
            local frameKey = key

            if frameKey == "targettarget" then
                frameKey = "target"
            end

            if auraTargets[frameKey] then
                local frameDB = EnsureFrameDB(db, frameKey)

                if frameDB.hideBuffs == false then
                    frameDB.hideBuffs = value == true
                end

                if frameDB.hideDebuffs == false then
                    frameDB.hideDebuffs = value == true
                end
            end
        end

        db.hideAuras = nil
    end

    return db
end

local function ResolvePath(path)
    local current = _G

    for part in string.gmatch(path, "[^%.]+") do
        current = current and current[part]

        if not current then
            return nil
        end
    end

    return current
end

local function ResolveFirst(paths)
    for _, path in ipairs(paths or {}) do
        local frame = ResolvePath(path)

        if frame then
            return frame
        end
    end

    return nil
end

local function AddUniqueFrame(list, seen, frame)
    if not frame or seen[frame] then
        return
    end

    seen[frame] = true
    list[#list + 1] = frame
end

local function CanChangeFrame(frame)
    if InCombatLockdown and InCombatLockdown() and frame and frame.IsProtected and frame:IsProtected() then
        pendingProtectedRefresh = true
        return false
    end

    return true
end

local function ReadColor(color)
    if not color then
        return nil
    end

    if type(color) == "table" then
        if color.GetRGB then
            local ok, r, g, b = pcall(color.GetRGB, color)

            if ok and r and g and b then
                return r, g, b
            end
        end

        return color.r or color[1], color.g or color[2], color.b or color[3]
    end

    return nil
end

local function GetClassColor(unit)
    if not UnitExists(unit) then
        return nil
    end

    local _, classFile = UnitClass(unit)

    if classFile and C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local ok, color = pcall(C_ClassColor.GetClassColor, classFile)

        local r, g, b

        if ok then
            r, g, b = ReadColor(color)
        end

        if r and g and b then
            return r, g, b
        end
    end

    local color = classFile
        and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))
    local r, g, b = ReadColor(color)

    if r and g and b then
        return r, g, b
    end

    color = classFile and fallbackClassColors[classFile]
    r, g, b = ReadColor(color)

    if r and g and b then
        return r, g, b
    end

    if UnitSelectionColor then
        return UnitSelectionColor(unit)
    end

    return 0, 1, 0
end

local function GetHealthFillTexture(bar)
    if not bar then
        return nil
    end

    if bar.GetStatusBarTexture then
        local texture = bar:GetStatusBarTexture()

        if texture then
            return texture
        end
    end

    return bar.HealthBarTexture or bar.StatusBarTexture or bar.Texture or bar.texture or bar.Fill or bar.FillTexture
end

local function SaveHealthColor(bar)
    if not bar or originalHealthColors[bar] then
        return
    end

    local state = {}

    if bar.GetStatusBarColor then
        local r, g, b, a = bar:GetStatusBarColor()

        state.r = r
        state.g = g
        state.b = b
        state.a = a
    end

    local texture = GetHealthFillTexture(bar)

    if bar.GetStatusBarTexture then
        local statusbarTexture = bar:GetStatusBarTexture()

        if statusbarTexture and statusbarTexture.GetTexture then
            state.statusbarTexture = statusbarTexture:GetTexture()
        end
    end

    if texture and texture.GetVertexColor then
        local r, g, b, a = texture:GetVertexColor()

        state.textureR = r
        state.textureG = g
        state.textureB = b
        state.textureA = a
    end

    originalHealthColors[bar] = state
end

local function RestoreHealthColor(bar)
    local color = bar and originalHealthColors[bar]

    if color and color.statusbarTexture and bar.SetStatusBarTexture then
        bar:SetStatusBarTexture(color.statusbarTexture)
    end

    if color and bar.SetStatusBarColor and color.r and color.g and color.b then
        bar:SetStatusBarColor(color.r or 0, color.g or 1, color.b or 0, color.a or 1)
    end

    local texture = GetHealthFillTexture(bar)

    if color and texture and texture.SetVertexColor and color.textureR and color.textureG and color.textureB then
        texture:SetVertexColor(color.textureR, color.textureG, color.textureB, color.textureA or 1)
    end
end

local function ApplyHealthColor(bar, r, g, b)
    if not bar then
        return
    end

    if bar.SetStatusBarTexture then
        bar:SetStatusBarTexture(CLASS_HEALTH_TEXTURE)
    end

    if bar.SetStatusBarColor then
        bar:SetStatusBarColor(r, g, b, 1)
    end

    local texture = GetHealthFillTexture(bar)

    if texture and texture.SetVertexColor then
        texture:SetVertexColor(r, g, b, 1)
    end
end

local function GetHealthBarFrames(info)
    local frames = {}
    local seen = {}

    for _, path in ipairs(info and info.paths or {}) do
        local bar = ResolvePath(path)

        if bar and (bar.SetStatusBarColor or GetHealthFillTexture(bar)) then
            AddUniqueFrame(frames, seen, bar)
        end
    end

    return frames
end

local function ApplyHealthBar(info)
    local db = EnsureDB()

    if not db or not info then
        return
    end

    if db.classColorHealth then
        local r, g, b = GetClassColor(info.unit)

        for _, bar in ipairs(GetHealthBarFrames(info)) do
            SaveHealthColor(bar)

            if r and g and b then
                ApplyHealthColor(bar, r, g, b)
            end
        end
    else
        for _, bar in ipairs(GetHealthBarFrames(info)) do
            RestoreHealthColor(bar)
        end
    end
end

local function ApplyHealthBars()
    for _, info in pairs(healthBars) do
        ApplyHealthBar(info)
    end
end

local function HookHealthBar(info)
    for _, bar in ipairs(GetHealthBarFrames(info)) do
        if not healthHooks[bar] then
            healthHooks[bar] = true

            if bar.HookScript then
                bar:HookScript("OnShow", ApplyHealthBars)
                bar:HookScript("OnValueChanged", ApplyHealthBars)
            end
        end
    end
end

local function GetCastbarText(bar)
    if not bar then
        return nil
    end

    if bar.Text and bar.Text.SetPoint then
        return bar.Text
    end

    if bar.text and bar.text.SetPoint then
        return bar.text
    end

    if bar.GetName then
        local name = bar:GetName()
        local text = name and (_G[name .. "Text"] or _G[name .. "TextString"])

        if text and text.SetPoint then
            return text
        end
    end

    return nil
end

local function SaveFramePoints(frame)
    if not frame or not frame.GetNumPoints then
        return nil
    end

    local points = {}

    for index = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)

        points[index] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end

    return points
end

local function RestoreFramePoints(frame, points)
    if not frame or not points or not frame.ClearAllPoints or not frame.SetPoint then
        return
    end

    frame:ClearAllPoints()

    for _, point in ipairs(points) do
        frame:SetPoint(point.point, point.relativeTo, point.relativePoint, point.x or 0, point.y or 0)
    end
end

local function SaveCastbarState(bar)
    if not bar or originalCastbarState[bar] then
        return
    end

    local width, height = bar:GetSize()
    local text = GetCastbarText(bar)

    originalCastbarState[bar] = {
        width = width,
        height = height,
        text = text,
        textHeight = text and text.GetHeight and text:GetHeight() or nil,
        textPoints = SaveFramePoints(text),
        textJustifyH = text and text.GetJustifyH and text:GetJustifyH() or nil,
        textJustifyV = text and text.GetJustifyV and text:GetJustifyV() or nil,
    }
end

local function PositionCastbarText(bar)
    local text = GetCastbarText(bar)

    if not text or not text.ClearAllPoints then
        return
    end

    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 8, -1)
    text:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -8, -1)

    if text.SetHeight then
        text:SetHeight(12)
    end

    if text.SetJustifyH then
        text:SetJustifyH("CENTER")
    end

    if text.SetJustifyV then
        text:SetJustifyV("MIDDLE")
    end
end

local function RestoreCastbarState(bar)
    local state = bar and originalCastbarState[bar]

    if not state then
        return
    end

    if bar.SetSize then
        bar:SetSize(state.width or DEFAULT_CASTBAR_WIDTH, state.height or DEFAULT_CASTBAR_HEIGHT)
    end

    if state.text then
        RestoreFramePoints(state.text, state.textPoints)

        if state.textHeight and state.text.SetHeight then
            state.text:SetHeight(state.textHeight)
        end

        if state.textJustifyH and state.text.SetJustifyH then
            state.text:SetJustifyH(state.textJustifyH)
        end

        if state.textJustifyV and state.text.SetJustifyV then
            state.text:SetJustifyV(state.textJustifyV)
        end
    end
end

local function ApplyCastbar(key)
    local db = EnsureDB()
    local info = key and castbars[key]
    local bar = info and ResolveFirst(info.paths)

    if not db or not bar or not bar.SetSize then
        return
    end

    if not CanChangeFrame(bar) then
        return
    end

    local frameDB = EnsureFrameDB(db, key)

    if frameDB.castbar.enabled then
        SaveCastbarState(bar)
        bar:SetSize(frameDB.castbar.width, frameDB.castbar.height)
        PositionCastbarText(bar)
    else
        RestoreCastbarState(bar)
    end
end

local function ApplyCastbars()
    for _, key in ipairs(frameOrder) do
        ApplyCastbar(key)
    end
end

local function HookCastbar(key)
    local info = key and castbars[key]
    local bar = info and ResolveFirst(info.paths)

    if not bar or castbarHooks[bar] then
        return
    end

    castbarHooks[bar] = true

    if bar.HookScript then
        bar:HookScript("OnShow", function()
            ApplyCastbar(key)
        end)
    end
end

local function SaveAuraState(frame)
    if not frame or originalAuraState[frame] then
        return
    end

    originalAuraState[frame] = {
        alpha = frame.GetAlpha and frame:GetAlpha() or 1,
        shown = frame.IsShown and frame:IsShown() or false,
        mouse = frame.IsMouseEnabled and frame:IsMouseEnabled() or false,
    }
end

local function HideAuraFrame(frame)
    if not frame then
        return
    end

    if not CanChangeFrame(frame) then
        return
    end

    SaveAuraState(frame)

    if frame.EnableMouse then
        frame:EnableMouse(false)
    end

    if frame.SetAlpha then
        frame:SetAlpha(0)
    end

end

local function RestoreAuraFrame(frame)
    local state = frame and originalAuraState[frame]

    if not frame or not state then
        return
    end

    if not CanChangeFrame(frame) then
        return
    end

    if frame.EnableMouse then
        frame:EnableMouse(state.mouse == true)
    end

    if frame.SetAlpha then
        frame:SetAlpha(state.alpha or 1)
    end

end

local function GetAuraKindFromName(name)
    if type(name) ~= "string" then
        return nil
    end

    local lowerName = string.lower(name)

    if lowerName:find("debuff") then
        return "debuffs"
    elseif lowerName:find("buff") then
        return "buffs"
    end

    return nil
end

local function GetAuraKindFromAuraData(unit, auraInstanceID)
    if not unit or not auraInstanceID or not C_UnitAuras or not C_UnitAuras.GetAuraDataByAuraInstanceID then
        return nil
    end

    local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)

    if auraData and auraData.isHelpful == true then
        return "buffs"
    elseif auraData and auraData.isHarmful == true then
        return "debuffs"
    end

    return nil
end

local function GetAuraKindFromAuraInfo(info)
    if type(info) ~= "table" then
        return nil
    end

    if info.isHelpful == true or info.isBuff == true then
        return "buffs"
    elseif info.isHarmful == true or info.isDebuff == true then
        return "debuffs"
    end

    return nil
end

local function GetAuraKindFromFields(child, unit)
    if not child then
        return nil
    end

    local dataKind = GetAuraKindFromAuraData(unit, child.auraInstanceID)

    if dataKind then
        return dataKind
    end

    dataKind = GetAuraKindFromAuraInfo(child.auraInfo or child.auraData)

    if dataKind then
        return dataKind
    end

    if child.auraInstanceID or child.auraInfo or child.auraData then
        return nil
    end

    local namedKind = GetAuraKindFromName(child.GetName and child:GetName())

    if namedKind then
        return namedKind
    end

    if child.isBuff == true or child.isHelpful == true then
        return "buffs"
    elseif child.isDebuff == true or child.isHarmful == true then
        return "debuffs"
    end

    local filter = child.filter or child.auraFilter

    if type(filter) == "string" then
        local lowerFilter = string.lower(filter)

        if lowerFilter:find("harmful") then
            return "debuffs"
        elseif lowerFilter:find("helpful") then
            return "buffs"
        end
    end

    return nil
end

local function IsSmallFrame(frame)
    if not frame or not frame.GetSize then
        return false
    end

    local width, height = frame:GetSize()

    return width and height and width > 0 and height > 0 and width <= 72 and height <= 72
end

local function LooksLikeAuraButton(child)
    if not child then
        return false
    end

    local name = child.GetName and child:GetName()

    if GetAuraKindFromName(name) then
        return IsSmallFrame(child)
    end

    if child.auraInstanceID or child.auraInfo or child.spellID or child.spellId then
        return IsSmallFrame(child)
    end

    local hasIcon = child.Icon or child.icon or child.IconFrame or child.texture
    local hasAuraRegions = child.Cooldown or child.cooldown or child.Count or child.count or child.Border or child.border

    return hasIcon and hasAuraRegions and IsSmallFrame(child)
end

local function ChildNameMatches(child, patterns, auraType, unit)
    local name = child and child.GetName and child:GetName()
    local lowerName = type(name) == "string" and string.lower(name) or nil
    local kind = GetAuraKindFromFields(child, unit)

    if not LooksLikeAuraButton(child) then
        return false
    end

    if kind and kind ~= auraType then
        return false
    end

    if lowerName then
        for _, pattern in ipairs(patterns or {}) do
            if lowerName:find(string.lower(pattern)) then
                return true
            end
        end
    end

    if LooksLikeAuraButton(child) then
        if kind then
            return kind == auraType
        end

        return false
    end

    return false
end

local function AddPrefixFrames(list, seen, prefixes, auraType, unit)
    for _, prefix in ipairs(prefixes or {}) do
        for index = 1, 60 do
            local frame = _G[prefix .. index]

            if ChildNameMatches(frame, nil, auraType, unit) then
                AddUniqueFrame(list, seen, frame)
            end
        end
    end
end

local function ScanChildrenForAuraFrames(root, list, seen, patterns, auraType, unit, depth)
    if not root or not root.GetChildren or depth <= 0 then
        return
    end

    for _, child in ipairs({ root:GetChildren() }) do
        if ChildNameMatches(child, patterns, auraType, unit) then
            AddUniqueFrame(list, seen, child)
        end

        ScanChildrenForAuraFrames(child, list, seen, patterns, auraType, unit, depth - 1)
    end
end

local function GetAuraFrames(info, auraType, unit)
    local config = info and info[auraType]
    local frames = {}
    local seen = {}

    if not config then
        return frames
    end

    for _, path in ipairs(config.paths or {}) do
        local frame = ResolvePath(path)

        if ChildNameMatches(frame, config.patterns, auraType, unit) then
            AddUniqueFrame(frames, seen, frame)
        end
    end

    AddPrefixFrames(frames, seen, config.prefixes, auraType, unit)

    for _, rootPath in ipairs(info.roots or {}) do
        ScanChildrenForAuraFrames(ResolvePath(rootPath), frames, seen, config.patterns, auraType, unit, 6)
    end

    return frames
end

local function ShouldHideAuraType(key, auraType)
    local db = EnsureDB()
    local frameDB = db and db.frames and db.frames[key]

    if not frameDB then
        return false
    end

    if auraType == "buffs" then
        return frameDB.hideBuffs == true
    end

    if auraType == "debuffs" then
        return frameDB.hideDebuffs == true
    end

    return false
end

local function ApplyAuraVisibilityFor(key, auraType)
    local info = auraTargets[key]

    if not info then
        return
    end

    for _, frame in ipairs(GetAuraFrames(info, auraType, key)) do
        if ShouldHideAuraType(key, auraType) then
            HideAuraFrame(frame)
        else
            RestoreAuraFrame(frame)
        end
    end
end

local function ApplyAuraVisibility()
    for _, key in ipairs(auraFrameOrder) do
        ApplyAuraVisibilityFor(key, "buffs")
        ApplyAuraVisibilityFor(key, "debuffs")
    end
end

local function HookAuraFramesFor(key, auraType)
    local info = auraTargets[key]

    if not info then
        return
    end

    for _, frame in ipairs(GetAuraFrames(info, auraType, key)) do
        if not auraHooks[frame] and frame.HookScript then
            auraHooks[frame] = true
            frame:HookScript("OnShow", ApplyAuraVisibility)
        end
    end
end

local function RefreshUnitFrames()
    EnsureDB()

    for _, info in pairs(healthBars) do
        HookHealthBar(info)
    end

    for _, key in ipairs(frameOrder) do
        HookCastbar(key)
    end

    for _, key in ipairs(auraFrameOrder) do
        HookAuraFramesFor(key, "buffs")
        HookAuraFramesFor(key, "debuffs")
    end

    ApplyHealthBars()
    ApplyCastbars()
    ApplyAuraVisibility()
end

local function ScheduleRefresh(delay)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, RefreshUnitFrames)
    else
        RefreshUnitFrames()
    end
end

function ns:SetUnitFrameClassColorHealth(value)
    local db = EnsureDB()

    if not db then
        return
    end

    db.classColorHealth = value == true
    RefreshUnitFrames()
end

function ns:GetUnitFrameClassColorHealth()
    local db = EnsureDB()

    return db and db.classColorHealth == true
end

function ns:SetUnitFrameCastbarResizeEnabled(key, value)
    local db = EnsureDB()

    if type(key) == "boolean" then
        value = key
        key = "player"
    end

    if not db or not castbars[key] then
        return
    end

    EnsureFrameDB(db, key).castbar.enabled = value == true
    RefreshUnitFrames()
end

function ns:GetUnitFrameCastbarResizeEnabled(key)
    local db = EnsureDB()
    key = key or "player"

    return db and db.frames and db.frames[key] and db.frames[key].castbar and db.frames[key].castbar.enabled == true
end

function ns:SetUnitFrameCastbarWidth(key, value)
    local db = EnsureDB()

    if type(key) == "number" then
        value = key
        key = "player"
    end

    if not db or not castbars[key] then
        return
    end

    EnsureFrameDB(db, key).castbar.width = Clamp(value, 120, 420, DEFAULT_CASTBAR_WIDTH)
    RefreshUnitFrames()
end

function ns:GetUnitFrameCastbarWidth(key)
    local db = EnsureDB()
    key = key or "player"

    return db and db.frames and db.frames[key] and db.frames[key].castbar and db.frames[key].castbar.width or DEFAULT_CASTBAR_WIDTH
end

function ns:SetUnitFrameCastbarHeight(key, value)
    local db = EnsureDB()

    if type(key) == "number" then
        value = key
        key = "player"
    end

    if not db or not castbars[key] then
        return
    end

    EnsureFrameDB(db, key).castbar.height = Clamp(value, 8, 40, DEFAULT_CASTBAR_HEIGHT)
    RefreshUnitFrames()
end

function ns:GetUnitFrameCastbarHeight(key)
    local db = EnsureDB()
    key = key or "player"

    return db and db.frames and db.frames[key] and db.frames[key].castbar and db.frames[key].castbar.height or DEFAULT_CASTBAR_HEIGHT
end

function ns:SetUnitFrameAuraHidden(key, auraType, value)
    local db = EnsureDB()

    if type(auraType) == "boolean" then
        value = auraType
        auraType = "both"
    end

    if not db or not auraTargets[key] then
        return
    end

    local frameDB = EnsureFrameDB(db, key)

    if auraType == "buffs" or auraType == "both" then
        frameDB.hideBuffs = value == true
    end

    if auraType == "debuffs" or auraType == "both" then
        frameDB.hideDebuffs = value == true
    end

    RefreshUnitFrames()
end

function ns:GetUnitFrameAuraHidden(key, auraType)
    local db = EnsureDB()
    local frameDB = db and db.frames and db.frames[key]

    if not frameDB then
        return false
    end

    if auraType == "buffs" then
        return frameDB.hideBuffs == true
    elseif auraType == "debuffs" then
        return frameDB.hideDebuffs == true
    end

    return frameDB.hideBuffs == true and frameDB.hideDebuffs == true
end

function ns:RefreshUnitFrames()
    RefreshUnitFrames()
end

function ns:InitializeUnitFrames()
    EnsureDB()
    RefreshUnitFrames()
    ScheduleRefresh(1)
    ScheduleRefresh(3)

    if initialized then
        return
    end

    initialized = true

    if type(UnitFrameHealthBar_Update) == "function" then
        hooksecurefunc("UnitFrameHealthBar_Update", ApplyHealthBars)
    end

    if type(TargetFrame_UpdateAuras) == "function" then
        hooksecurefunc("TargetFrame_UpdateAuras", ApplyAuraVisibility)
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    eventFrame:RegisterEvent("UNIT_TARGET")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
    eventFrame:RegisterEvent("UNIT_FACTION")
    eventFrame:RegisterEvent("UNIT_CONNECTION")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingProtectedRefresh then
                pendingProtectedRefresh = false
                RefreshUnitFrames()
            end

            return
        end

        if event == "UNIT_TARGET" and unit ~= "player" and unit ~= "target" then
            return
        end

        if unit and unit ~= "player" and unit ~= "target" and unit ~= "targettarget" and unit ~= "focus" then
            return
        end

        RefreshUnitFrames()
    end)
end
