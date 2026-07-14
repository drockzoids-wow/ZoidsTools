local ADDON_NAME, ns = ...

ns.addonName = ADDON_NAME
ns.title = "ZoidsTools"
local metadataVersion
if C_AddOns and C_AddOns.GetAddOnMetadata then
    metadataVersion = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
elseif GetAddOnMetadata then
    metadataVersion = GetAddOnMetadata(ADDON_NAME, "Version")
end
ns.version = metadataVersion and not metadataVersion:find("@", 1, true) and metadataVersion or "Development"
local CURRENT_MIGRATION_VERSION = 3

local defaults = {
    migrationVersion = 3,
    windows = {
        enabled = true,
        moveBags = true,
        savePositions = true,
        scaleEnabled = true,
        scaleStep = 0.05,
        minScale = 0.6,
        maxScale = 1.8,
        showBagHandles = true,
        points = {},
        scales = {},
    },
    loot = {
        fastLoot = true,
        carefulMode = false,
        carefulDelay = 0.12,
    },
    vendor = {
        autoSellGrey = false,
        autoSellBoEGrey = false,
        autoRepairMode = "disabled",
        knownItemOverlay = false,
    },
    quests = {
        autoAccept = false,
        autoTurnIn = false,
        autoGossip = false,
        pauseModifier = "shift",
        skipDaily = true,
        skipWarbandCompleted = true,
    },
    cinematics = {
        fastSkip = false,
        autoSkip = false,
    },
    mythicInviteBanner = {
        enabled = true,
    },
    tooltips = {
        factionBackground = true,
        classColoredNames = true,
        showMythicScore = true,
        colorMythicScore = true,
        showMythicPercentile = true,
        showItemLevel = true,
    },
    combat = {
        actionButtonRangeTint = true,
        combatBanner = {
            enabled = false,
            persistent = false,
            locked = false,
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 220,
        },
        buffWarnings = {
            enabled = true,
            popup = {
                point = "CENTER",
                relativePoint = "CENTER",
                x = 0,
                y = 150,
            },
        },
        keybindText = {
            enabled = true,
            shorten = true,
            font = "default",
            fontSize = 12,
            outline = "default",
            bold = false,
            useCustomColor = false,
            color = {
                r = 1,
                g = 1,
                b = 1,
            },
        },
    },
    macros = {
        healthEnabled = false,
        healthUseRecuperate = false,
        healthCombatItems = true,
        manaEnabled = false,
        manaCombatPotion = true,
        hearthstoneEnabled = true,
        hearthstoneExcluded = {},
    },
    unitFrames = {
        classColorHealth = false,
        frames = {
            player = {
                hideBuffs = false,
                hideDebuffs = false,
                castbar = {
                    enabled = false,
                    width = 195,
                    height = 16,
                },
            },
            target = {
                hideBuffs = false,
                hideDebuffs = false,
                castbar = {
                    enabled = false,
                    width = 195,
                    height = 16,
                },
            },
            focus = {
                hideBuffs = false,
                hideDebuffs = false,
                castbar = {
                    enabled = false,
                    width = 195,
                    height = 16,
                },
            },
        },
    },
    mounts = {
        enabled = true,
        preferGroundWhenNotFlyable = true,
        useWaterMountsOnSurface = true,
        excludeServiceMountsFromRandom = true,
        useDruidTravelForm = true,
        useDruidCatForm = true,
        useDracthyrSoar = true,
        useFallingRescue = true,
        targetMatchEnabled = true,
        targetMatchButton = {
            shown = true,
            point = "CENTER",
            relativePoint = "CENTER",
            x = 220,
            y = 0,
        },
        recentAvoidCount = 3,
        preferredMount = nil,
        preferredServiceMounts = {},
        recentMounts = {},
        mountUsage = {},
    },
    items = {
        enabled = true,
        fontSize = 12,
        useQualityColor = true,
        statTargetContext = "mythicplus",
        statGoalsPanelShown = true,
        character = {
            itemLevel = true,
            gems = true,
            enchants = true,
            missingEnchant = true,
            gemTooltips = true,
            statTargets = true,
        },
        bags = {
            itemLevel = true,
            bindType = true,
        },
        bank = {
            itemLevel = true,
            bindType = true,
        },
        warbandBank = {
            itemLevel = true,
            bindType = true,
        },
    },
    talentGrimoire = {
        enabled = true,
        contentType = "mythicplus",
        mythicPlusTarget = "all-dungeons",
        raidTarget = "all-bosses",
        pvpTarget = "3v3",
        pvpMode = "popular",
        mode = "popular",
    },
    damageMeterProfiles = {
        activeProfile = "profile1",
        lastAppliedProfile = "profile1",
        profiles = {
            profile1 = {
                name = "Profile 1",
                windows = {},
            },
            profile2 = {
                name = "Profile 2",
                windows = {},
            },
        },
    },
    customDamageMeter = {
        enabled = false,
        sessionType = "current",
        damageMeterType = "DamageDone",
        textScale = 1,
        snapGap = 0,
        backgroundOpacity = 0.94,
        classColoredBorder = true,
        point = "BOTTOMRIGHT",
        relativePoint = "BOTTOMRIGHT",
        x = -18,
        y = 210,
        width = 300,
        height = 143,
        secondWindow = {
            enabled = false,
            sessionType = "current",
            damageMeterType = "DamageDone",
        },
    },
    professions = {
        enabled = true,
        activation = "alt",
        actions = {
            disenchant = true,
            mill = true,
            prospect = true,
            open = true,
        },
    },
    performance = {
        enabled = true,
        updateInterval = 1,
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = -15,
        y = 205,
        locked = false,
    },
    coordinates = {
        enabled = true,
        mapEnabled = true,
        updateInterval = 0.15,
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        relativeTo = "Minimap",
        x = 0,
        y = 0,
        scale = 1,
    },
    ui = {
        talkingHead = {
            enabled = true,
            opacity = 0.72,
            background = true,
            fontSize = 14,
            bold = false,
        },
        minimap = {
            show = true,
            hide = false,
            minimapPos = 225,
            square = false,
            moveHeader = false,
            hideAddonCompartment = false,
            expansionButtonSize = 32,
            hideAddonButtons = false,
            collectAddonButtons = false,
        },
        mainWindow = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        },
    },
}

local function CopyDefaults(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end

            CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function RunMigrations(db)
    local version = tonumber(db and db.migrationVersion) or 0

    if version < 1 then
        if db.performance and db.performance.displayMode == nil and db.performance.enabled ~= nil then
            db.performance.displayMode = db.performance.enabled and "both" or "disabled"
        end

        if db.ui and db.ui.minimap then
            if db.ui.minimap.show == nil and db.ui.minimap.hide ~= nil then
                db.ui.minimap.show = db.ui.minimap.hide ~= true
            end
            db.ui.minimap.hide = db.ui.minimap.show == false
        end
    end

    if version < 2 then
        db.customDamageMeter = db.customDamageMeter or {}
        if db.customDamageMeter.textScale == nil or db.customDamageMeter.textScale == 1 then
            db.customDamageMeter.textScale = 1.2
        end
    end

    if version < 3 then
        db.customDamageMeter = db.customDamageMeter or {}
        local oldScale = tonumber(db.customDamageMeter.textScale) or 1.2
        db.customDamageMeter.textScale = math.max(0.8, math.min(1.5, oldScale / 1.2))
    end

    db.migrationVersion = CURRENT_MIGRATION_VERSION
end

local function Trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

function ns:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffZoidsTools|r: " .. tostring(message))
end

function ns:GetDB()
    return self.db
end

function ns:OpenConfig(pageKey)
    if self.UI and self.UI.Show then
        self.UI.Show(pageKey)
    else
        self:Print("The control window is not ready yet.")
    end
end

function ns:SetMinimapShown(value)
    if not self.db then
        return
    end

    self.db.ui.minimap.show = value == true
    self.db.ui.minimap.hide = value ~= true

    if self.UpdateMinimapButton then
        self:UpdateMinimapButton()
    end
end

local function PrintHelp()
    ns:Print("/zt opens ZoidsTools.")
    ns:Print("/zt windows on/off toggles movable Blizzard windows.")
    ns:Print("/zt tooltips opens tooltip options.")
    ns:Print("/zt bags on/off toggles default bag movement.")
    ns:Print("/zt combat opens combat options.")
    ns:Print("/zt unitframes opens unit frame options.")
    ns:Print("/zt macros opens health and mana macro options.")
    ns:Print("/zt refreshmacros updates the ZoidsTools consumable macros.")
    ns:Print("/zt mounts opens smart mount options.")
    ns:Print("/zt smartmount on/off toggles the smart mount keybind.")
    ns:Print("/zt matchmount matches your target's mount when possible.")
    ns:Print("/zt mountrecent reset clears recent smart mount history.")
    ns:Print("/zt keydown on/off toggles action keybinds on key down.")
    ns:Print("/zt rangetint on/off toggles full-button out-of-range tint.")
    ns:Print("/zt perf on/off toggles the FPS and latency widget.")
    ns:Print("/zt perf unlock unlocks the click-through performance widget.")
    ns:Print("/zt coords on/off toggles the coordinates widget.")
    ns:Print("/zt coords reset resets the coordinates widget position.")
    ns:Print("/zt diag start/stop/report/reset controls performance diagnostics.")
    ns:Print("/zt invitebanner previews the Mythic+ invitation banner.")
    ns:Print("/zt items opens item overlay options.")
    ns:Print("/zt iteminfo on/off toggles item overlays.")
    ns:Print("/zt talents opens talent build options.")
    ns:Print("/zt talents on/off toggles talent build controls.")
    ns:Print("/zt meters opens Blizzard damage meter profile options.")
    ns:Print("/zt professions opens profession helper options.")
    ns:Print("/zt loot opens loot options.")
    ns:Print("/zt fastloot on/off toggles fast auto loot.")
    ns:Print("/zt autosell on/off toggles auto-sell grey items at vendors.")
    ns:Print("/zt sellboe on/off includes BoE grey items in auto-sell.")
    ns:Print("/zt autorepair off/personal/guild changes auto repair.")
    ns:Print("/zt quests opens quest automation options.")
    ns:Print("/zt autoquest on/off toggles auto accept and auto turn-in.")
    ns:Print("/zt resetwindows clears saved window positions.")
    ns:Print("/zt resetscales clears saved window scales.")
    ns:Print("Hold Ctrl and mouse-wheel over a movable window to scale it.")
end

local function HandleSlash(input)
    input = string.lower(Trim(input))

    if input == "" or input == "config" or input == "options" or input == "open" then
        ns:OpenConfig()
    elseif input == "windows" then
        ns:OpenConfig("windows")
    elseif input == "tooltips" or input == "tooltip" then
        ns:OpenConfig("tooltips")
    elseif input == "loot" then
        ns:OpenConfig("loot")
    elseif input == "combat" then
        ns:OpenConfig("combat")
    elseif input == "unitframes" or input == "unitframe" or input == "frames" then
        ns:OpenConfig("unitframes")
    elseif input == "macros" or input == "macro" or input == "food" or input == "drink" then
        ns:OpenConfig("macros")
    elseif input == "mounts" or input == "mount" or input == "smartmount" then
        ns:OpenConfig("mounts")
    elseif input == "items" or input == "item" or input == "gear" then
        ns:OpenConfig("items")
    elseif input == "grimoire" or input == "tome" or input == "builds" or input == "build" or input == "talents" then
        ns:OpenConfig("builds")
    elseif input == "meters" or input == "meter" or input == "damagemeter" or input == "damage meters" then
        ns:OpenConfig("meters")
    elseif input == "professions" or input == "profession" or input == "molinari" then
        ns:OpenConfig("professions")
    elseif input == "quests" or input == "quest" then
        ns:OpenConfig("quests")
    elseif input == "windows on" then
        ns.db.windows.enabled = true

        if ns.InitializeMovableWindows then
            ns:InitializeMovableWindows()
        end

        if ns.RefreshMovableWindows then
            ns:RefreshMovableWindows()
        end

        ns:Print("Movable Blizzard windows enabled.")
    elseif input == "windows off" then
        ns.db.windows.enabled = false

        if ns.RefreshMovableWindows then
            ns:RefreshMovableWindows()
        end

        ns:Print("Movable Blizzard windows disabled.")
    elseif input == "bags on" then
        ns.db.windows.moveBags = true

        if ns.RefreshBagMovement then
            ns:RefreshBagMovement()
        end

        ns:Print("Default bag movement enabled.")
    elseif input == "bags off" then
        ns.db.windows.moveBags = false

        if ns.RefreshBagMovement then
            ns:RefreshBagMovement()
        end

        ns:Print("Default bag movement disabled.")
    elseif input == "fastloot on" then
        if ns.SetFastLootEnabled then
            ns:SetFastLootEnabled(true)
        else
            ns.db.loot.fastLoot = true
        end

        ns:Print("Fast auto loot enabled.")
    elseif input == "fastloot off" then
        if ns.SetFastLootEnabled then
            ns:SetFastLootEnabled(false)
        else
            ns.db.loot.fastLoot = false
        end

        ns:Print("Fast auto loot disabled.")
    elseif input == "autosell on" or input == "sellgrey on" then
        if ns.SetAutoSellGreyItems then
            ns:SetAutoSellGreyItems(true)
            ns:Print("Auto-sell grey items enabled.")
        end
    elseif input == "autosell off" or input == "sellgrey off" then
        if ns.SetAutoSellGreyItems then
            ns:SetAutoSellGreyItems(false)
            ns:Print("Auto-sell grey items disabled.")
        end
    elseif input == "sellboe on" or input == "autosellboe on" or input == "boejunk on" then
        if ns.SetAutoSellBoEGreyItems then
            ns:SetAutoSellBoEGreyItems(true)
            ns:Print("BoE grey items will be included in auto-sell.")
        end
    elseif input == "sellboe off" or input == "autosellboe off" or input == "boejunk off" then
        if ns.SetAutoSellBoEGreyItems then
            ns:SetAutoSellBoEGreyItems(false)
            ns:Print("BoE grey items will be skipped by auto-sell.")
        end
    elseif input == "autorepair off" or input == "repair off" then
        if ns.SetAutoRepairMode then
            ns:SetAutoRepairMode("disabled")
            ns:Print("Auto repair disabled.")
        end
    elseif input == "autorepair personal" or input == "repair personal" or input == "autorepair own" then
        if ns.SetAutoRepairMode then
            ns:SetAutoRepairMode("personal")
            ns:Print("Auto repair will use your own gold.")
        end
    elseif input == "autorepair guild" or input == "repair guild" then
        if ns.SetAutoRepairMode then
            ns:SetAutoRepairMode("guild")
            ns:Print("Auto repair will use guild bank funds when available.")
        end
    elseif input == "autoquest on" or input == "quests on" then
        if ns.SetQuestAutomationOption then
            ns:SetQuestAutomationOption("autoAccept", true)
            ns:SetQuestAutomationOption("autoTurnIn", true)
            ns:Print("Quest auto accept and turn-in enabled.")
        end
    elseif input == "autoquest off" or input == "quests off" then
        if ns.SetQuestAutomationOption then
            ns:SetQuestAutomationOption("autoAccept", false)
            ns:SetQuestAutomationOption("autoTurnIn", false)
            ns:Print("Quest auto accept and turn-in disabled.")
        end
    elseif input == "perf on" or input == "performance on" then
        if ns.SetPerformanceWidgetShown then
            ns:SetPerformanceWidgetShown(true)
            ns:Print("Performance widget shown with FPS and latency.")
        end
    elseif input == "perf off" or input == "performance off" then
        if ns.SetPerformanceWidgetShown then
            ns:SetPerformanceWidgetShown(false)
            ns:Print("Performance widget hidden.")
        end
    elseif input == "perf unlock" or input == "performance unlock" then
        if ns.SetPerformanceWidgetLocked then
            ns:SetPerformanceWidgetLocked(false)
            ns:Print("Performance widget unlocked.")
        end
    elseif input == "coords on" or input == "coordinates on" then
        if ns.SetCoordinatesWidgetShown then
            ns:SetCoordinatesWidgetShown(true)
            ns:Print("Coordinates widget shown.")
        end
    elseif input == "coords off" or input == "coordinates off" then
        if ns.SetCoordinatesWidgetShown then
            ns:SetCoordinatesWidgetShown(false)
            ns:Print("Coordinates widget hidden.")
        end
    elseif input == "coords reset" or input == "coordinates reset" then
        if ns.ResetCoordinatesWidgetPosition then
            ns:ResetCoordinatesWidgetPosition()
            ns:Print("Coordinates widget position reset.")
        end
    elseif input == "mapcoords on" or input == "map coordinates on" then
        if ns.SetMapCoordinatesShown then
            ns:SetMapCoordinatesShown(true)
            ns:Print("Map coordinates shown.")
        end
    elseif input == "mapcoords off" or input == "map coordinates off" then
        if ns.SetMapCoordinatesShown then
            ns:SetMapCoordinatesShown(false)
            ns:Print("Map coordinates hidden.")
        end
    elseif input == "iteminfo on" or input == "items on" then
        if ns.SetItemOverlaysEnabled then
            ns:SetItemOverlaysEnabled(true)
            ns:Print("Item overlays enabled.")
        end
    elseif input == "iteminfo off" or input == "items off" then
        if ns.SetItemOverlaysEnabled then
            ns:SetItemOverlaysEnabled(false)
            ns:Print("Item overlays disabled.")
        end
    elseif input == "grimoire on" or input == "builds on" or input == "talents on" then
        if ns.SetTalentGrimoireEnabled then
            ns:SetTalentGrimoireEnabled(true)
            ns:Print("Talent controls enabled.")
        end
    elseif input == "grimoire off" or input == "builds off" or input == "talents off" then
        if ns.SetTalentGrimoireEnabled then
            ns:SetTalentGrimoireEnabled(false)
            ns:Print("Talent controls disabled.")
        end
    elseif input == "keydown on" or input == "castkeydown on" then
        if ns.SetCastOnKeyDown and ns:SetCastOnKeyDown(true) then
            ns:Print("Action keybinds now cast on key down.")
        else
            ns:Print("Could not update the key-down cast setting.")
        end
    elseif input == "keydown off" or input == "castkeydown off" then
        if ns.SetCastOnKeyDown and ns:SetCastOnKeyDown(false) then
            ns:Print("Action keybinds now cast on key up.")
        else
            ns:Print("Could not update the key-down cast setting.")
        end
    elseif input == "rangetint on" or input == "range tint on" then
        if ns.SetActionButtonRangeTintEnabled then
            ns:SetActionButtonRangeTintEnabled(true)
            ns:Print("Full-button out-of-range tint enabled.")
        end
    elseif input == "rangetint off" or input == "range tint off" then
        if ns.SetActionButtonRangeTintEnabled then
            ns:SetActionButtonRangeTintEnabled(false)
            ns:Print("Full-button out-of-range tint disabled.")
        end
    elseif input == "refreshmacros" or input == "macros refresh" or input == "macro refresh" then
        if ns.RefreshConsumableMacros then
            ns:RefreshConsumableMacros(true)
        end
        if ns.RefreshRandomHearthstoneMacro then
            ns:RefreshRandomHearthstoneMacro()
        end
        if InCombatLockdown and InCombatLockdown() then
            ns:Print("Macro refresh queued until combat ends.")
        else
            ns:Print("Enabled macros checked and refreshed where needed.")
        end
    elseif input == "smartmount on" or input == "mounts on" then
        if ns.SetMountsEnabled then
            ns:SetMountsEnabled(true)
            ns:Print("Smart mount keybind enabled.")
        end
    elseif input == "smartmount off" or input == "mounts off" then
        if ns.SetMountsEnabled then
            ns:SetMountsEnabled(false)
            ns:Print("Smart mount keybind disabled.")
        end
    elseif input == "matchmount" or input == "mountmatch" or input == "targetmount" then
        if ZoidsToolsMounts and ZoidsToolsMounts.MatchTargetMount then
            ZoidsToolsMounts.MatchTargetMount()
        end
    elseif input == "mountrecent reset" or input == "mounts resetrecent" or input == "smartmount resetrecent" then
        if ns.ClearMountRecentHistory then
            ns:ClearMountRecentHistory()
        end
    elseif input == "reset" or input == "resetwindows" then
        if ns.ResetMovableWindowPositions then
            ns:ResetMovableWindowPositions()
        end
    elseif input == "resetscales" then
        if ns.ResetMovableWindowScales then
            ns:ResetMovableWindowScales()
        end
    elseif input == "minimap on" then
        ns:SetMinimapShown(true)
        ns:Print("Minimap button shown.")
    elseif input == "minimap off" then
        ns:SetMinimapShown(false)
        ns:Print("Minimap button hidden.")
    elseif input == "diag" or input == "diag status" or input == "diag report" then
        if ns.ReportDiagnostics then
            ns:ReportDiagnostics()
        end
    elseif input == "diag start" then
        if ns.StartDiagnostics then
            ns:StartDiagnostics()
        end
    elseif input == "diag stop" then
        if ns.StopDiagnostics then
            ns:StopDiagnostics()
        end
    elseif input == "diag reset" then
        if ns.ResetDiagnostics then
            ns:ResetDiagnostics()
        end
    elseif input == "invitebanner" or input == "invite banner" or input == "mythicinvite" then
        if ns.PreviewMythicInviteBanner then
            ns:PreviewMythicInviteBanner()
        end
    elseif input == "help" then
        PrintHelp()
    else
        PrintHelp()
    end
end

SLASH_ZOIDSTOOLS1 = "/zt"
SLASH_ZOIDSTOOLS2 = "/zoids"
SLASH_ZOIDSTOOLS3 = "/zoidstools"
SlashCmdList.ZOIDSTOOLS = HandleSlash

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        ZoidsToolsDB = ZoidsToolsDB or {}
        RunMigrations(ZoidsToolsDB)
        CopyDefaults(defaults, ZoidsToolsDB)
        ns.db = ZoidsToolsDB
    elseif event == "PLAYER_LOGIN" then
        if ns.InitializeDiagnostics then
            ns:InitializeDiagnostics()
        end

        if ns.InitializeMovableWindows then
            ns:InitializeMovableWindows()
        end

        if ns.InitializeFastLoot then
            ns:InitializeFastLoot()
        end

        if ns.InitializeVendorAutomation then
            ns:InitializeVendorAutomation()
        end

        if ns.InitializeCombatSettings then
            ns:InitializeCombatSettings()
        end

        if ns.InitializeCinematicSkip then
            ns:InitializeCinematicSkip()
        end

        if ns.InitializeSubtleTalkingHead then
            ns:InitializeSubtleTalkingHead()
        end

        if ns.InitializeCombatBanner then
            ns:InitializeCombatBanner()
        end

        if ns.InitializeMythicInviteBanner then
            ns:InitializeMythicInviteBanner()
        end

        if ns.InitializeBuffWarnings then
            ns:InitializeBuffWarnings()
        end

        if ns.InitializeUnitFrames then
            ns:InitializeUnitFrames()
        end

        if ns.InitializeConsumableMacros then
            ns:InitializeConsumableMacros()
        end

        if ns.InitializeRandomHearthstone then
            ns:InitializeRandomHearthstone()
        end

        if ns.InitializeMounts then
            ns:InitializeMounts()
        end

        if ns.InitializeKeybindText then
            ns:InitializeKeybindText()
        end

        if ns.InitializePerformanceWidget then
            ns:InitializePerformanceWidget()
        end

        if ns.InitializeCoordinates then
            ns:InitializeCoordinates()
        end

        if ns.InitializeItemOverlays then
            ns:InitializeItemOverlays()
        end

        if ns.InitializeStatTargets then
            ns:InitializeStatTargets()
        end

        if ns.InitializeTalentGrimoire then
            ns:InitializeTalentGrimoire()
        end

        if ns.InitializeBlizzardDamageMeterProfiles then
            ns:InitializeBlizzardDamageMeterProfiles()
        end

        if ns.InitializeCustomDamageMeter then
            ns:InitializeCustomDamageMeter()
        end

        if ns.InitializeProfessionHelper then
            ns:InitializeProfessionHelper()
        end

        if ns.InitializeQuestAutomation then
            ns:InitializeQuestAutomation()
        end

        if ns.UI and ns.UI.Initialize then
            ns.UI.Initialize()
        end

        if ns.InitializeMinimapButton then
            ns:InitializeMinimapButton()
        end

        if ns.InitializeMinimapTools then
            ns:InitializeMinimapTools()
        end

        if ns.InitializeTooltips then
            ns:InitializeTooltips()
        end
    end
end)
