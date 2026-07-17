local _, ns = ...

local MAX_COPY_LINES = 500
local CHAT_EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_GUILD_ACHIEVEMENT",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_COMMUNITIES_CHANNEL",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_SYSTEM",
    "CHAT_MSG_LOOT",
    "CHAT_MSG_MONEY",
    "CHAT_MSG_CURRENCY",
    "CHAT_MSG_ACHIEVEMENT",
}

local initialized = false
local copyWindow
local copySourceLines = {}
local copySourceFrame
local copySourceMode = "chat"
local trackedFrames = {}
local originalFonts = setmetatable({}, { __mode = "k" })
local originalAlphas = setmetatable({}, { __mode = "k" })
local originalBackgroundAlphas = setmetatable({}, { __mode = "k" })
local originalEditBoxPoints = setmetatable({}, { __mode = "k" })
local originalEditBoxFonts = setmetatable({}, { __mode = "k" })
local originalEditModeSelectionPoints = setmetatable({}, { __mode = "k" })
local originalArrowModes = setmetatable({}, { __mode = "k" })
local originalHeaderColors = setmetatable({}, { __mode = "k" })
local originalEditBoxRegionFonts = setmetatable({}, { __mode = "k" })
local originalEditBoxArtwork = setmetatable({}, { __mode = "k" })
local lastMentionKey
local lastMentionTime = 0
local copyScrollRestoreGeneration = 0
local copyRefreshPending = false

local EDIT_BOX_GAP = 6
local EDIT_BOX_HORIZONTAL_SHIFT = 2
local EDIT_MODE_SELECTION_PADDING = 2
local editBoxFontPaths = {
    friz = function() return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end,
    arial = function() return "Fonts\\ARIALN.TTF" end,
    morpheus = function() return "Fonts\\MORPHEUS.TTF" end,
    skurri = function() return "Fonts\\SKURRI.TTF" end,
    damage = function() return DAMAGE_TEXT_FONT or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end,
}

local OUTBOUND_EVENTS = {
    CHAT_MSG_WHISPER_INFORM = true,
    CHAT_MSG_BN_WHISPER_INFORM = true,
}

local function GetDB()
    return ns.db and ns.db.chat
end

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.max(minimum, math.min(maximum, value))
end

local function IsScrolledBack(frame)
    return frame and frame.GetScrollOffset and (tonumber(frame:GetScrollOffset()) or 0) > 0
end

local function MarkUnread(frame)
    if not frame then return end
    frame.ZTChatHasUnread = true
    if frame.ZTChatUnreadButton then frame.ZTChatUnreadButton:Show() end
end

local function StripFormatting(text)
    if IsSecretValue(text) then return "" end
    text = tostring(text or "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|A.-|a", "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|cn[%w_%-]+:", "")
    text = text:gsub("|r", "")
    text = text:gsub("||", "|")
    return text
end

ns.StripChatFormatting = StripFormatting

local function FormatCopyDisplayLine(text)
    if IsSecretValue(text) then return "" end
    text = tostring(text or "")
    -- EditBoxes can render color escapes but do not need the clickable-link
    -- wrapper. Preserve the colored link label while removing non-text art.
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|A.-|a", "")
    -- Reset both before and after every message so an incomplete color escape
    -- can never affect the neighboring lines.
    return "|r" .. text .. "|r"
end

local function ShowURLCopy(url)
    if not StaticPopupDialogs then return end

    StaticPopupDialogs.ZOIDSTOOLS_COPY_CHAT_URL = StaticPopupDialogs.ZOIDSTOOLS_COPY_CHAT_URL or {
        text = "Copy this address",
        button1 = CLOSE or "Close",
        hasEditBox = true,
        editBoxWidth = 420,
        OnShow = function(self, data)
            local editBox = self.EditBox or self.editBox
            if editBox then
                editBox:SetText(tostring(data or ""))
                editBox:SetFocus()
                editBox:HighlightText()
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            if parent then parent:Hide() end
        end,
        EditBoxOnEscapePressed = function(self)
            local parent = self:GetParent()
            if parent then parent:Hide() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show("ZOIDSTOOLS_COPY_CHAT_URL", nil, nil, url)
end

local function LinkifyToken(token)
    if token == "" or token:find("|", 1, true) then return token end

    local leading, core, trailing = token:match("^([%(%[%{<]*)(.-)([%)%]%}>%.,!%?;:]*)$")
    core = core or token
    leading = leading or ""
    trailing = trailing or ""

    local lower = core:lower()
    local isURL = lower:match("^https?://")
        or lower:match("^www%.")
        or lower:match("^discord%.gg/")

    if not isURL or #core < 5 then return token end

    return leading
        .. "|Hzturl:" .. core .. "|h|cff66cfff[" .. core .. "]|r|h"
        .. trailing
end

local function FormatURLs(message)
    if IsSecretValue(message) then return message end
    if type(message) ~= "string" or message:find("|Hzturl:", 1, true) then
        return message
    end

    return (message:gsub("%S+", LinkifyToken))
end

local function IsMention(message)
    local db = GetDB()
    if IsSecretValue(message)
        or not db
        or not db.mentionHighlight
        or type(message) ~= "string"
    then
        return false
    end

    local playerName = UnitName and UnitName("player")
    playerName = playerName and playerName:match("^[^-]+")
    if not playerName or playerName == "" then return false end

    local plain = StripFormatting(message):lower()
    local needle = playerName:lower()
    local startIndex = 1

    while true do
        local first, last = plain:find(needle, startIndex, true)
        if not first then return false end
        local before = first == 1 and "" or plain:sub(first - 1, first - 1)
        local after = last == #plain and "" or plain:sub(last + 1, last + 1)
        if not before:match("[%w_]") and not after:match("[%w_]") then return true end
        startIndex = last + 1
    end
end

local function URLMessageFilter(chatFrame, event, message, author, ...)
    local db = GetDB()
    if not db or not db.enabled then return false end

    -- Protected chat payloads must pass through byte-for-byte. Even comparing
    -- one with another string is forbidden by Blizzard's secret-value rules.
    if IsSecretValue(message) or IsSecretValue(author) then return false end

    if db.newMessageIndicator and IsScrolledBack(chatFrame) then
        MarkUnread(chatFrame)
    end

    local result = db.urlCopy and FormatURLs(message) or message
    if not OUTBOUND_EVENTS[event] and IsMention(message) then
        result = "|cffffd24a" .. tostring(result or "") .. "|r"

        if db.mentionSound and PlaySound then
            local key = tostring(event) .. "\031" .. tostring(author) .. "\031" .. StripFormatting(message)
            local now = GetTime and GetTime() or 0
            if key ~= lastMentionKey or (now - lastMentionTime) > 0.2 then
                lastMentionKey = key
                lastMentionTime = now
                PlaySound(SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081, "Master")
            end
        end
    end

    if result == message then return false end
    return false, result, author, ...
end

local function GetChatFrameName(frame)
    if frame and frame.GetName then return frame:GetName() end
end

local function ClearClosedItemRefState()
    local tooltip = ItemRefTooltip
    if not tooltip or (tooltip.IsShown and tooltip:IsShown()) then return end

    -- ItemRefTooltipMixin treats a hyperlink matching its cached primary info
    -- as a request to close the tooltip. If another addon or UI transition hid
    -- the window without clearing that cache, every later click on the same
    -- item merely hides an already-hidden tooltip. Clear only that stale cache.
    if tooltip.ClearHandlerInfo then
        tooltip:ClearHandlerInfo()
    end
end

local function InstallItemRefCleanup()
    local tooltip = ItemRefTooltip
    if not tooltip or tooltip.ZTChatCloseCleanupHooked then return end
    tooltip.ZTChatCloseCleanupHooked = true
    tooltip:HookScript("OnHide", ClearClosedItemRefState)
end

local function RestoreChatInteractivity(frame)
    if not frame then return end

    -- Blizzard disables every chat hyperlink (channels, player names, items,
    -- achievements, and more) when a frame is marked uninteractable. An early
    -- version of chat layout profiles could accidentally persist that state.
    -- Chat enhancements are intended to preserve normal Blizzard interaction.
    local hyperlinksDisabled = frame.GetHyperlinksEnabled
        and not frame:GetHyperlinksEnabled()

    if (frame.isUninteractable or hyperlinksDisabled) and FCF_SetUninteractable then
        pcall(FCF_SetUninteractable, frame, false)
    elseif (frame.isUninteractable or hyperlinksDisabled)
        and SetChatWindowUninteractable and frame.GetID then
        pcall(SetChatWindowUninteractable, frame:GetID(), false)
        frame.isUninteractable = false
    elseif hyperlinksDisabled and frame.SetHyperlinksEnabled then
        -- Fallback for nonstandard chat frames which do not participate in the
        -- floating-chat-frame interactable lifecycle.
        frame:SetHyperlinksEnabled(true)
    end

    -- Match Blizzard and Prat here: FCF_SetUninteractable owns the frame's
    -- hyperlink state. Do not independently force mouse-click flags on the
    -- ScrollingMessageFrame, since its internal FontStringContainer handles
    -- hit testing for rendered chat links.
end

local function ReadBooleanMethod(object, methodName)
    local method = object and object[methodName]
    if type(method) ~= "function" then return "n/a" end
    local ok, value = pcall(method, object)
    if not ok then return "error" end
    return value and "yes" or "no"
end

function ns:ReportChatDiagnostics()
    local frame = DEFAULT_CHAT_FRAME
    if FCFDock_GetSelectedWindow and GENERAL_CHAT_DOCK then
        frame = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) or frame
    end
    if not frame then
        self:Print("Chat diagnostics could not find an active Blizzard chat frame.")
        return
    end

    local name = GetChatFrameName(frame) or "unknown"
    local clickScript = frame.GetScript and frame:GetScript("OnHyperlinkClick")
    local enterScript = frame.GetScript and frame:GetScript("OnHyperlinkEnter")
    local container = frame.FontStringContainer
        or (frame.GetName and _G[(frame:GetName() or "") .. "FontStringContainer"])

    self:Print(string.format(
        "Chat diagnostics: %s uninteractable=%s hyperlinks=%s mouse=%s clicks=%s motion=%s clickHandler=%s hoverHandler=%s.",
        name,
        tostring(frame.isUninteractable == true),
        ReadBooleanMethod(frame, "GetHyperlinksEnabled"),
        ReadBooleanMethod(frame, "IsMouseEnabled"),
        ReadBooleanMethod(frame, "IsMouseClickEnabled"),
        ReadBooleanMethod(frame, "IsMouseMotionEnabled"),
        clickScript and "present" or "MISSING",
        enterScript and "present" or "MISSING"
    ))
    self:Print(string.format(
        "Chat diagnostics: FontStringContainer=%s mouse=%s clicks=%s propagateLinks=%s; nativeMixin=%s.",
        container and "present" or "missing",
        ReadBooleanMethod(container, "IsMouseEnabled"),
        ReadBooleanMethod(container, "IsMouseClickEnabled"),
        ReadBooleanMethod(container, "DoesHyperlinkPropagateToParent"),
        ChatFrameMixin and type(ChatFrameMixin.OnHyperlinkClick) == "function" and "present" or "missing"
    ))

    self:Print("Chat diagnostics are read-only; ZoidsTools does not hook Blizzard's normal chat hyperlink scripts.")
end

local function GetChatBackground(frame)
    if not frame then return nil end
    return frame.Background or _G[(GetChatFrameName(frame) or "") .. "Background"]
end

local function GetAttachedEditBoxOffsets(frame)
    if not frame then return 0, 0 end

    local frameLeft = frame.GetLeft and frame:GetLeft()
    local frameRight = frame.GetRight and frame:GetRight()
    local left, right = frameLeft, frameRight
    local name = GetChatFrameName(frame)
    local candidates = {}
    local function AddCandidate(region)
        if region then candidates[#candidates + 1] = region end
    end
    AddCandidate(GetChatBackground(frame))
    AddCandidate(frame.ScrollBar)
    AddCandidate(frame.scrollBar)
    AddCandidate(name and _G[name .. "ScrollBar"])

    -- The scrolling-message frame excludes parts of Blizzard's visible
    -- background and scrollbar gutter. Measure both nearby visual edges so the
    -- attached edit box lines up with what the player actually sees.
    if frameLeft and frameRight then
        for _, region in ipairs(candidates) do
            local regionLeft = region and region.GetLeft and region:GetLeft()
            local regionRight = region and region.GetRight and region:GetRight()
            if regionLeft and regionLeft < left and left - regionLeft <= 40 then
                left = regionLeft
            end
            if regionRight and regionRight > right and regionRight - right <= 40 then
                right = regionRight
            end
        end
        return left - frameLeft, right - frameRight
    end

    return 0, 0
end

local function RememberAlpha(region)
    if region and originalAlphas[region] == nil and region.GetAlpha then
        originalAlphas[region] = region:GetAlpha()
    end
end

local function SetRegionAlpha(region, alpha)
    if region and region.SetAlpha then
        RememberAlpha(region)
        region:SetAlpha(alpha)
    end
end

local function RestoreRegionAlpha(region)
    local alpha = region and originalAlphas[region]
    if alpha ~= nil and region.SetAlpha then region:SetAlpha(alpha) end
end

local function NormalizeFontFlags(flags)
    return tostring(flags or ""):upper()
end

local function ApplyFontIfChanged(frame, path, size, flags)
    if not frame or not frame.SetFont or not path then return false end
    size = tonumber(size)
    if not size then return false end

    if frame.GetFont then
        local currentPath, currentSize, currentFlags = frame:GetFont()
        if currentPath == path
            and math.abs((tonumber(currentSize) or 0) - size) < 0.01
            and NormalizeFontFlags(currentFlags) == NormalizeFontFlags(flags) then
            return false
        end
    end

    frame:SetFont(path, size, flags)
    return true
end

local function GetChatControls(frame)
    local controls = {}
    local name = GetChatFrameName(frame)
    local index = name and tonumber(name:match("ChatFrame(%d+)$"))

    local function Add(control)
        if control then controls[#controls + 1] = control end
    end

    Add(frame and frame.buttonFrame)
    Add(name and _G[name .. "ButtonFrame"])
    Add(name and _G[name .. "Tab"])

    if index == 1 then
        Add(_G.ChatFrameMenuButton)
        Add(_G.ChatFrameChannelButton)
        Add(_G.ChatFrameToggleVoiceDeafenButton)
        Add(_G.ChatFrameToggleVoiceMuteButton)
    end

    return controls
end

local function IsFrameHovered(frame)
    if frame and frame.IsMouseOver and frame:IsMouseOver() then return true end
    if frame and frame.ZTChatCopyButton and frame.ZTChatCopyButton:IsMouseOver() then return true end

    for _, control in ipairs(GetChatControls(frame)) do
        if control.IsMouseOver and control:IsMouseOver() then return true end
    end

    return false
end

local function RestoreFrameAppearance(frame)
    if not frame then return end

    local font = originalFonts[frame]
    if frame.ZTChatFontApplied and font and frame.SetFont then
        ApplyFontIfChanged(frame, font.path, font.size, font.flags)
    end
    frame.ZTChatFontApplied = nil

    local background = GetChatBackground(frame)
    local alpha = background and originalBackgroundAlphas[background]
    if frame.ZTChatBackgroundApplied and alpha ~= nil and background.SetAlpha then
        background:SetAlpha(alpha)
    end
    frame.ZTChatBackgroundApplied = nil

    if frame.ZTChatControlsApplied then
        for _, control in ipairs(GetChatControls(frame)) do
            RestoreRegionAlpha(control)
        end
    end
    frame.ZTChatControlsApplied = nil

    if frame.ZTChatFadingApplied then
        if frame.ZTChatOriginalFading ~= nil and frame.SetFading then
            frame:SetFading(frame.ZTChatOriginalFading)
        end
        if frame.ZTChatOriginalTimeVisible and frame.SetTimeVisible then
            frame:SetTimeVisible(frame.ZTChatOriginalTimeVisible)
        end
    end
    frame.ZTChatFadingApplied = nil
end

local function RefreshFrameAppearance(frame)
    local db = GetDB()
    if not frame or not db then return end

    if not db.enabled then
        RestoreFrameAppearance(frame)
        if frame.ZTChatCopyButton then frame.ZTChatCopyButton:Hide() end
        if frame.ZTChatUnreadButton then frame.ZTChatUnreadButton:Hide() end
        return
    end

    local hovered = IsFrameHovered(frame)
    local background = GetChatBackground(frame)

    if background and originalBackgroundAlphas[background] == nil and background.GetAlpha then
        originalBackgroundAlphas[background] = background:GetAlpha()
    end

    if db.backgroundEnabled and background and background.SetAlpha then
        local alpha = Clamp(db.backgroundOpacity, 0, 1)
        background:SetAlpha(db.backgroundMouseover and (hovered and alpha or 0) or alpha)
        frame.ZTChatBackgroundApplied = true
    elseif frame.ZTChatBackgroundApplied and background then
        local original = originalBackgroundAlphas[background]
        if original ~= nil then background:SetAlpha(original) end
        frame.ZTChatBackgroundApplied = nil
    end

    if db.customFont and frame.SetFont then
        local original = originalFonts[frame]
        local path = original and original.path
        if not path and frame.GetFont then path = frame:GetFont() end
        if path then
            ApplyFontIfChanged(frame, path, Clamp(db.fontSize, 9, 24), db.fontOutline and "OUTLINE" or "")
            frame.ZTChatFontApplied = true
        end
    elseif frame.ZTChatFontApplied then
        local original = originalFonts[frame]
        if original then ApplyFontIfChanged(frame, original.path, original.size, original.flags) end
        frame.ZTChatFontApplied = nil
    end

    if db.mouseoverControls then
        for _, control in ipairs(GetChatControls(frame)) do
            SetRegionAlpha(control, hovered and 1 or 0)
        end
        frame.ZTChatControlsApplied = true
    elseif frame.ZTChatControlsApplied then
        for _, control in ipairs(GetChatControls(frame)) do
            RestoreRegionAlpha(control)
        end
        frame.ZTChatControlsApplied = nil
    end

    local fadeDelay = Clamp(db.fadeDelay, 10, 600)
    if db.disableFading then
        if frame.SetFading then frame:SetFading(false) end
        frame.ZTChatFadingApplied = true
    elseif fadeDelay ~= 120 then
        if frame.SetFading then frame:SetFading(true) end
        if frame.SetTimeVisible then frame:SetTimeVisible(fadeDelay) end
        frame.ZTChatFadingApplied = true
    elseif frame.ZTChatFadingApplied then
        if frame.ZTChatOriginalFading ~= nil and frame.SetFading then
            frame:SetFading(frame.ZTChatOriginalFading)
        end
        if frame.ZTChatOriginalTimeVisible and frame.SetTimeVisible then
            frame:SetTimeVisible(frame.ZTChatOriginalTimeVisible)
        end
        frame.ZTChatFadingApplied = nil
    end

    if frame.ZTChatCopyButton then
        local copyIsOpen = copyWindow and copyWindow:IsShown() and copySourceFrame == frame
        local emphasized = hovered or copyIsOpen
        local button = frame.ZTChatCopyButton

        button:SetShown(db.copyButton == true)

        if db.copyButton and button.ZTChatEmphasized ~= emphasized then
            button.ZTChatEmphasized = emphasized
            local targetAlpha = emphasized and 1 or 0.20
            local duration = emphasized and 0.12 or 0.24

            if emphasized and UIFrameFadeIn then
                UIFrameFadeIn(button, duration, button:GetAlpha(), targetAlpha)
            elseif not emphasized and UIFrameFadeOut then
                UIFrameFadeOut(button, duration, button:GetAlpha(), targetAlpha)
            else
                button:SetAlpha(targetAlpha)
            end
        end
    end


    if frame.ZTChatUnreadButton then
        frame.ZTChatUnreadButton:SetShown(db.newMessageIndicator == true and frame.ZTChatHasUnread == true)
    end
end

local function ScheduleFrameRefresh(frame)
    if not C_Timer or not C_Timer.After then
        RefreshFrameAppearance(frame)
        return
    end

    C_Timer.After(0.08, function()
        if frame then RefreshFrameAppearance(frame) end
    end)
end

local function CollectMessages(frame)
    local lines = {}
    if not frame or not frame.GetNumMessages or not frame.GetMessageInfo then return lines end

    local count = frame:GetNumMessages() or 0
    local first = math.max(1, count - MAX_COPY_LINES + 1)

    for index = first, count do
        local message = frame:GetMessageInfo(index)
        if not IsSecretValue(message) and message and message ~= "" then
            lines[#lines + 1] = message
        end
    end

    return lines
end

local function LoadCopySource()
    if copySourceMode == "history" and ns.GetSavedChatHistoryLines then
        copySourceLines = ns:GetSavedChatHistoryLines()
    else
        copySourceMode = "chat"
        copySourceLines = CollectMessages(copySourceFrame)
    end
end

local function RefreshCopyWindow(preserveScroll)
    if not copyWindow then return end

    local previousScroll
    local previousScrollRange
    local wasAtBottom = false
    local previousHistoryOffset = 0
    if preserveScroll then
        if copySourceMode == "history" and copyWindow.historyOutput then
            previousHistoryOffset = tonumber(copyWindow.historyOutput:GetScrollOffset()) or 0
        elseif copyWindow.scroll then
            previousScroll = tonumber(copyWindow.scroll:GetVerticalScroll()) or 0
            previousScrollRange = tonumber(copyWindow.scroll:GetVerticalScrollRange()) or 0
            wasAtBottom = previousScrollRange > 0 and previousScroll >= (previousScrollRange - 2)
        end
    end

    local query = copyWindow.search:GetText():lower()
    local filtered = {}

    for _, line in ipairs(copySourceLines) do
        local searchable = StripFormatting(line):lower()
        if query == "" or searchable:find(query, 1, true) then
            filtered[#filtered + 1] = line
        end
    end

    local historyMode = copySourceMode == "history"
    copyWindow.scroll:SetShown(not historyMode)
    if copyWindow.historyOutput then
        copyWindow.historyOutput:SetShown(historyMode)
    end

    if historyMode and copyWindow.historyOutput then
        copyWindow.historyOutput:Clear()
        if #filtered == 0 then
            copyWindow.historyOutput:AddMessage("|cff8f949eNo saved chat messages yet. New messages shown in your active chat tab will appear here immediately.|r")
        else
            for _, line in ipairs(filtered) do
                -- Keep valid hyperlink/color markup in the interactive history,
                -- but prevent an incomplete source line from coloring the next.
                copyWindow.historyOutput:AddMessage("|r" .. tostring(line or "") .. "|r")
            end
        end
        copyWindow.historyOutput:ScrollToBottom()
        if preserveScroll and previousHistoryOffset > 0 then
            if copyWindow.historyOutput.SetScrollOffset then
                copyWindow.historyOutput:SetScrollOffset(previousHistoryOffset)
            else
                for _ = 1, previousHistoryOffset do
                    copyWindow.historyOutput:ScrollUp()
                end
            end
        end
    else
        local displayLines = {}
        for _, line in ipairs(filtered) do
            displayLines[#displayLines + 1] = FormatCopyDisplayLine(line)
        end
        local text = table.concat(displayLines, "\n")
        copyWindow.output.ZTRefreshing = true
        copyWindow.output:SetText(text)
        copyWindow.output:SetCursorPosition(0)
        copyWindow.output.ZTRefreshing = nil
        copyWindow:UpdateOutputSize(text)
        if preserveScroll and previousScroll ~= nil then
            copyScrollRestoreGeneration = copyScrollRestoreGeneration + 1
            local generation = copyScrollRestoreGeneration
            local function RestoreScrollPosition()
                if generation ~= copyScrollRestoreGeneration or not copyWindow then return end
                local newRange = tonumber(copyWindow.scroll:GetVerticalScrollRange()) or 0
                copyWindow.scroll:SetVerticalScroll(
                    wasAtBottom and newRange or math.min(previousScroll, newRange)
                )
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, RestoreScrollPosition)
            else
                RestoreScrollPosition()
            end
        else
            copyScrollRestoreGeneration = copyScrollRestoreGeneration + 1
            copyWindow.scroll:SetVerticalScroll(0)
        end
    end

    if copyWindow.selectAll then
        copyWindow.selectAll:SetEnabled(not historyMode)
        copyWindow.selectAll:SetAlpha(historyMode and 0.45 or 1)
    end
    copyWindow.status:SetFormattedText("Showing %d of %d messages", #filtered, #copySourceLines)
end

local function StyleSmallButton(button)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(0.025, 0.030, 0.040, 0.96)
    button:SetBackdropBorderColor(0.60, 0.48, 0.18, 0.88)
end

local function CreateCopyWindow()
    if copyWindow then return copyWindow end

    local frame = CreateFrame("Frame", "ZoidsToolsChatCopyWindow", UIParent, "BackdropTemplate")
    frame:SetSize(690, 455)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(480, 300, 1000, 760)
    elseif frame.SetMinResize then
        frame:SetMinResize(480, 300)
        frame:SetMaxResize(1000, 760)
    end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.012, 0.014, 0.020, 0.98)
    frame:SetBackdropBorderColor(0.72, 0.56, 0.20, 0.92)
    frame:Hide()

    if UISpecialFrames then
        local alreadyRegistered = false
        for _, name in ipairs(UISpecialFrames) do
            if name == "ZoidsToolsChatCopyWindow" then
                alreadyRegistered = true
                break
            end
        end
        if not alreadyRegistered then
            UISpecialFrames[#UISpecialFrames + 1] = "ZoidsToolsChatCopyWindow"
        end
    end

    frame.titleBar = CreateFrame("Frame", nil, frame)
    frame.titleBar:SetPoint("TOPLEFT", 5, -5)
    frame.titleBar:SetPoint("TOPRIGHT", -5, -5)
    frame.titleBar:SetHeight(34)
    frame.titleBar:EnableMouse(true)
    frame.titleBar:RegisterForDrag("LeftButton")
    frame.titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame.titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    frame.title = frame.titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("LEFT", 10, 0)
    frame.title:SetText("Chat Copy")
    frame.title:SetTextColor(1, 0.82, 0.26)

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", -2, -2)
    frame.close:SetScript("OnClick", function() frame:Hide() end)

    frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.search:SetPoint("TOPLEFT", 18, -46)
    frame.search:SetPoint("TOPRIGHT", -46, -46)
    frame.search:SetHeight(28)
    frame.search:SetAutoFocus(false)
    frame.search:SetMaxLetters(120)
    frame.search:SetScript("OnTextChanged", function(self)
        if not self.ZTRefreshing then RefreshCopyWindow() end
    end)
    frame.search:SetScript("OnEscapePressed", function() frame:Hide() end)

    frame.searchHint = frame.search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.searchHint:SetPoint("LEFT", 6, 0)
    frame.searchHint:SetText("Search messages...")
    frame.searchHint:SetTextColor(0.52, 0.54, 0.58)
    frame.search:HookScript("OnTextChanged", function(self)
        frame.searchHint:SetShown(self:GetText() == "" and not self:HasFocus())
    end)
    frame.search:HookScript("OnEditFocusGained", function() frame.searchHint:Hide() end)
    frame.search:HookScript("OnEditFocusLost", function(self)
        frame.searchHint:SetShown(self:GetText() == "")
    end)

    frame.outputViewport = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.outputViewport:SetPoint("TOPLEFT", 16, -82)
    frame.outputViewport:SetPoint("BOTTOMRIGHT", -34, 58)
    frame.outputViewport:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    frame.outputViewport:SetBackdropColor(0.004, 0.006, 0.010, 0.86)

    frame.scroll = CreateFrame("ScrollFrame", nil, frame.outputViewport, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 8, -8)
    frame.scroll:SetPoint("BOTTOMRIGHT", -26, 8)

    frame.output = CreateFrame("EditBox", nil, frame.scroll)
    frame.output:SetMultiLine(true)
    frame.output:SetAutoFocus(false)
    frame.output:SetFontObject(ChatFontNormal or "ChatFontNormal")
    frame.output:SetTextInsets(4, 4, 4, 4)
    frame.output:SetScript("OnEscapePressed", function() frame:Hide() end)
    frame.scroll:SetScrollChild(frame.output)

    frame.historyOutput = CreateFrame("ScrollingMessageFrame", nil, frame.outputViewport)
    frame.historyOutput:SetPoint("TOPLEFT", 12, -10)
    frame.historyOutput:SetPoint("BOTTOMRIGHT", -12, 10)
    frame.historyOutput:SetFontObject(ChatFontNormal or "ChatFontNormal")
    frame.historyOutput:SetJustifyH("LEFT")
    frame.historyOutput:SetIndentedWordWrap(true)
    frame.historyOutput:SetFading(false)
    frame.historyOutput:SetMaxLines(MAX_COPY_LINES)
    frame.historyOutput:SetHyperlinksEnabled(true)
    frame.historyOutput:EnableMouse(true)
    frame.historyOutput:EnableMouseWheel(true)
    frame.historyOutput:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    frame.historyOutput:SetScript("OnHyperlinkClick", function(self, link, text, button)
        -- This is a standalone ScrollingMessageFrame, not a Blizzard chat
        -- frame. Route the click exactly once through the same function used by
        -- Blizzard chat. This preserves ordinary clicks and modified clicks
        -- (including Ctrl-click dressing-room previews) on repeated use.
        if SetItemRef then
            InstallItemRefCleanup()
            ClearClosedItemRefState()
            SetItemRef(link, text, button, self)
        end
    end)
    frame.historyOutput:SetScript("OnHyperlinkEnter", function(self, link, text)
        if GameTooltip and GameTooltip.SetHyperlink then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, link)
        end
    end)
    frame.historyOutput:SetScript("OnHyperlinkLeave", function(self)
        if GameTooltip then GameTooltip:Hide() end
    end)
    frame.historyOutput:Hide()

    frame:SetScript("OnHide", function()
        frame.search:ClearFocus()
        frame.output:ClearFocus()

        local sourceFrame = copySourceFrame
        copySourceFrame = nil
        if sourceFrame then ScheduleFrameRefresh(sourceFrame) end
    end)

    function frame:UpdateOutputSize(text)
        local width = math.max(100, frame.scroll:GetWidth() - 10)
        local fontSize = select(2, frame.output:GetFont()) or 14
        local charactersPerLine = math.max(20, math.floor(width / math.max(5, fontSize * 0.54)))
        local visualLines = 0

        text = text or frame.output:GetText() or ""
        if text == "" then
            visualLines = 1
        else
            for line in (text .. "\n"):gmatch("(.-)\n") do
                visualLines = visualLines + math.max(1, math.ceil(#line / charactersPerLine))
            end
        end

        frame.output:SetWidth(width)
        frame.output:SetHeight(math.max(frame.outputViewport:GetHeight(), visualLines * (fontSize + 3) + 24))
    end
    frame:SetScript("OnSizeChanged", function() frame:UpdateOutputSize() end)
    frame:SetScript("OnShow", function() frame:UpdateOutputSize() end)

    local function CreateActionButton(text, width)
        local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
        button:SetSize(width, 28)
        StyleSmallButton(button)
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.label:SetPoint("CENTER")
        button.label:SetText(text)
        button:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.95, 0.72, 0.26, 1)
            self.label:SetTextColor(1, 0.84, 0.30)
        end)
        button:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.60, 0.48, 0.18, 0.88)
            self.label:SetTextColor(1, 1, 1)
        end)
        return button
    end

    frame.selectAll = CreateActionButton("Select All", 100)
    frame.selectAll:SetPoint("BOTTOMLEFT", 16, 18)
    frame.selectAll:SetScript("OnClick", function()
        frame.output:SetFocus()
        frame.output:HighlightText()
        frame.status:SetText("Selected. Press Ctrl+C to copy.")
    end)

    frame.clearSearch = CreateActionButton("Clear Search", 112)
    frame.clearSearch:SetPoint("LEFT", frame.selectAll, "RIGHT", 8, 0)
    frame.clearSearch:SetScript("OnClick", function()
        frame.search:SetText("")
        frame.search:SetFocus()
    end)

    frame.sourceToggle = CreateActionButton("Saved History", 112)
    frame.sourceToggle:SetPoint("LEFT", frame.clearSearch, "RIGHT", 8, 0)
    frame.sourceToggle:SetScript("OnClick", function(self)
        copySourceMode = copySourceMode == "history" and "chat" or "history"
        LoadCopySource()
        self.label:SetText(copySourceMode == "history" and "Current Tab" or "Saved History")
        frame.title:SetText(copySourceMode == "history" and "Chat Copy - Saved History" or "Chat Copy - Current Tab")
        RefreshCopyWindow()
    end)

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.status:SetPoint("LEFT", frame.sourceToggle, "RIGHT", 14, 0)
    frame.status:SetPoint("RIGHT", frame, "RIGHT", -42, 0)
    frame.status:SetJustifyH("LEFT")
    frame.status:SetTextColor(0.68, 0.72, 0.76)

    frame.resize = CreateFrame("Button", nil, frame)
    frame.resize:SetSize(22, 22)
    frame.resize:SetPoint("BOTTOMRIGHT", -3, 3)
    frame.resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    frame.resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    frame.resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    frame.resize:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
    end)
    frame.resize:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

    copyWindow = frame
    return frame
end

function ns:ShowChatCopy(frame)
    frame = frame or SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
    local window = CreateCopyWindow()
    if window:IsShown() and copySourceFrame == frame then
        window:Hide()
        return
    end
    local previousSource = copySourceFrame
    copySourceFrame = frame
    copySourceMode = "chat"
    LoadCopySource()
    window.title:SetText("Chat Copy - " .. (frame and frame.name or GetChatFrameName(frame) or "Chat"))
    window.sourceToggle.label:SetText("Saved History")
    window.search.ZTRefreshing = true
    window.search:SetText("")
    window.search.ZTRefreshing = nil
    window:Show()
    window:Raise()
    RefreshCopyWindow()
    RefreshFrameAppearance(frame)

    if previousSource and previousSource ~= frame then
        ScheduleFrameRefresh(previousSource)
    end
end

function ns:ShowSavedChatHistory()
    local window = CreateCopyWindow()
    copySourceFrame = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
    copySourceMode = "history"
    LoadCopySource()
    window.title:SetText("Chat Copy - Saved History")
    window.sourceToggle.label:SetText("Current Tab")
    window.search.ZTRefreshing = true
    window.search:SetText("")
    window.search.ZTRefreshing = nil
    window:Show()
    window:Raise()
    RefreshCopyWindow()
end

function ns:RefreshOpenChatCopy()
    if not copyWindow or not copyWindow:IsShown() then return end
    if copyRefreshPending then return end

    copyRefreshPending = true
    local function Refresh()
        copyRefreshPending = false
        if not copyWindow or not copyWindow:IsShown() then return end
        LoadCopySource()
        RefreshCopyWindow(true)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, Refresh)
    else
        Refresh()
    end
end

local function CreateCopyButton(frame)
    if frame.ZTChatCopyButton then return frame.ZTChatCopyButton end

    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetSize(26, 24)
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    button:SetFrameLevel(frame:GetFrameLevel() + 20)
    StyleSmallButton(button)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label:SetPoint("CENTER", 0, 0)
    button.label:SetText("C")
    button.label:SetTextColor(1, 0.80, 0.22)
    button:SetAlpha(0.20)
    button.ZTChatEmphasized = false

    button:SetScript("OnClick", function() ns:ShowChatCopy(frame) end)
    button:SetScript("OnEnter", function(self)
        self:Show()
        self:SetBackdropBorderColor(0.95, 0.72, 0.26, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText("Copy and search chat")
        GameTooltip:AddLine("Opens the recent messages from this chat tab.", 1, 1, 1, true)
        GameTooltip:Show()
        RefreshFrameAppearance(frame)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.60, 0.48, 0.18, 0.88)
        GameTooltip:Hide()
        ScheduleFrameRefresh(frame)
    end)

    frame.ZTChatCopyButton = button
    return button
end

local function ClearUnread(frame)
    if not frame then return end
    frame.ZTChatHasUnread = nil
    if frame.ZTChatUnreadButton then frame.ZTChatUnreadButton:Hide() end
end

local function CreateUnreadButton(frame)
    if frame.ZTChatUnreadButton then return frame.ZTChatUnreadButton end

    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetSize(126, 24)
    button:SetPoint("BOTTOM", frame, "BOTTOM", 0, 5)
    button:SetFrameLevel(frame:GetFrameLevel() + 21)
    StyleSmallButton(button)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText("New messages  |cffffd24av|r")
    button:SetScript("OnClick", function()
        if frame.ScrollToBottom then frame:ScrollToBottom() end
        ClearUnread(frame)
    end)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.95, 0.72, 0.26, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.60, 0.48, 0.18, 0.88)
    end)
    button:Hide()
    frame.ZTChatUnreadButton = button
    return button
end

local function RememberEditBoxPoints(editBox)
    if not editBox or originalEditBoxPoints[editBox] then return end
    local points = {}
    for index = 1, editBox:GetNumPoints() do
        points[index] = { editBox:GetPoint(index) }
    end
    points.height = editBox:GetHeight()
    originalEditBoxPoints[editBox] = points

    if editBox.GetFont and not originalEditBoxFonts[editBox] then
        local path, size, flags = editBox:GetFont()
        originalEditBoxFonts[editBox] = { path = path, size = size, flags = flags }
    end
end

local function RestoreEditBoxPoints(editBox)
    local points = editBox and originalEditBoxPoints[editBox]
    if not points then return end
    editBox:ClearAllPoints()
    for _, point in ipairs(points) do editBox:SetPoint(unpack(point)) end
    if points.height then editBox:SetHeight(points.height) end
end

local function RememberEditModeSelectionPoints(frame)
    local selection = frame and frame.Selection
    if not selection or originalEditModeSelectionPoints[frame] then return end

    local points = {}
    for index = 1, selection:GetNumPoints() do
        points[index] = { selection:GetPoint(index) }
    end
    if #points > 0 then originalEditModeSelectionPoints[frame] = points end
end

local function RefreshEditModeSelection(frame, editBox, db)
    local selection = frame and frame.Selection
    if not selection then return end

    RememberEditModeSelectionPoints(frame)
    local points = originalEditModeSelectionPoints[frame]
    if not points then return end

    local position = db and db.enabled and db.editBoxPosition or "blizzard"
    if position == "default" then position = "bottom" end

    -- Start from Blizzard's own selection bounds. Retail already reserves some
    -- space for its default edit box, so adding our full box height would count
    -- most of that area twice.
    selection:ClearAllPoints()
    for _, anchor in ipairs(points) do
        selection:SetPoint(unpack(anchor))
    end

    local extension = 0
    if editBox and (position == "bottom" or position == "top") then
        local selectionScale = selection.GetEffectiveScale and selection:GetEffectiveScale() or 1
        local editBoxScale = editBox.GetEffectiveScale and editBox:GetEffectiveScale() or selectionScale
        selectionScale = selectionScale > 0 and selectionScale or 1
        editBoxScale = editBoxScale > 0 and editBoxScale or selectionScale

        if position == "bottom" then
            local selectionBottom = selection:GetBottom()
            local editBoxBottom = editBox:GetBottom()
            if selectionBottom and editBoxBottom then
                local desiredBottom = (editBoxBottom * editBoxScale)
                    - (EDIT_MODE_SELECTION_PADDING * selectionScale)
                extension = math.max(0, ((selectionBottom * selectionScale) - desiredBottom) / selectionScale)
            end
        else
            local selectionTop = selection:GetTop()
            local editBoxTop = editBox:GetTop()
            if selectionTop and editBoxTop then
                local desiredTop = (editBoxTop * editBoxScale)
                    + (EDIT_MODE_SELECTION_PADDING * selectionScale)
                extension = math.max(0, (desiredTop - (selectionTop * selectionScale)) / selectionScale)
            end
        end
    end

    if extension > 0 then
        selection:ClearAllPoints()
        for _, anchor in ipairs(points) do
            local point, relativeTo, relativePoint, offsetX, offsetY = unpack(anchor)
            offsetY = tonumber(offsetY) or 0
            if position == "bottom" and tostring(point):find("BOTTOM", 1, true) then
                offsetY = offsetY - extension
            elseif position == "top" and tostring(point):find("TOP", 1, true) then
                offsetY = offsetY + extension
            end
            selection:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
        end
    end

    -- Edit Mode uses Selection for magnetism and screen clamping. Recalculate
    -- after extending it so the attached typing box remains inside the screen.
    if frame.UpdateClampOffsets then frame:UpdateClampOffsets() end
end

local function PratOwnsEditBox(editBox)
    local pratFrame = editBox and editBox.pratFrame
    -- If Prat created its edit-box wrapper, it owns this edit box for its
    -- entire lifetime. Switching ownership based on whether that wrapper is
    -- currently visible makes both addons alternately move and activate the
    -- same input frame as hyperlinks are clicked.
    return pratFrame ~= nil
end

local function GetEditBoxArtwork(editBox)
    if originalEditBoxArtwork[editBox] then return originalEditBoxArtwork[editBox] end

    local artwork, seen = {}, {}
    local name = editBox.GetName and editBox:GetName()
    local function IsSkinRegion(region)
        local skin = editBox.ZTChatSkin
        return skin and (region == skin.background
            or region == skin.borderMask
            or region == skin.top
            or region == skin.bottom
            or region == skin.left
            or region == skin.right)
    end

    local function Add(region, isFocus)
        if region and region.SetShown and not seen[region] then
            if IsSkinRegion(region) then return end
            seen[region] = true
            artwork[#artwork + 1] = {
                region = region,
                shown = region:IsShown(),
                height = region.GetHeight and region:GetHeight() or nil,
                isFocus = isFocus == true,
            }
        end
    end

    for _, key in ipairs({
        "Left", "Mid", "Middle", "Right", "FocusLeft", "FocusMid", "FocusMiddle", "FocusRight",
        "left", "mid", "middle", "right", "focusLeft", "focusMid", "focusMiddle", "focusRight",
    }) do
        local isFocus = key:lower():find("focus", 1, true) ~= nil
        Add(editBox[key], isFocus)
        if name then Add(_G[name .. key], isFocus) end
    end

    -- Include any anonymous native slices as a compatibility fallback. Named
    -- regions above are de-duplicated, and ZoidsTools' own skin is excluded.
    if editBox.GetRegions then
        local focusRegions = {}
        if editBox.focusLeft then focusRegions[editBox.focusLeft] = true end
        if editBox.focusMid then focusRegions[editBox.focusMid] = true end
        if editBox.focusMiddle then focusRegions[editBox.focusMiddle] = true end
        if editBox.focusRight then focusRegions[editBox.focusRight] = true end
        for _, region in ipairs({ editBox:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "Texture" then
                Add(region, focusRegions[region])
            end
        end
    end

    originalEditBoxArtwork[editBox] = artwork
    return artwork
end

local function UpdateBlizzardEditBoxArtwork(editBox, styled)
    for _, info in ipairs(GetEditBoxArtwork(editBox)) do
        local region = info.region
        if styled then
            region:SetShown(false)
        else
            if region.SetHeight and info.height and info.height > 0 then
                region:SetHeight(info.height)
            end
            region:SetShown(info.shown)
        end
    end
end

local function GetPlayerClassColor()
    local _, classFile = UnitClass("player")
    if classFile and C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local color = C_ClassColor.GetClassColor(classFile)
        if color and color.GetRGB then return color:GetRGB() end
    end

    local color = classFile
        and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
            or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))
    if color then return color.r or 1, color.g or 0.82, color.b or 0 end
    return 1, 0.82, 0
end

local function CreateEditBoxSkin(editBox)
    if editBox.ZTChatSkin then return editBox.ZTChatSkin end

    local skin = {}
    skin.background = editBox:CreateTexture(nil, "BACKGROUND", nil, 7)
    skin.background:SetAllPoints()
    skin.background:SetColorTexture(0.012, 0.014, 0.020, 0.96)

    -- Blizzard re-shows its focused input-border textures after chat
    -- activation. Cover the native BORDER layer from the inside while leaving
    -- ZoidsTools' class-colored two-pixel outline visible above it.
    skin.borderMask = editBox:CreateTexture(nil, "BORDER", nil, 6)
    skin.borderMask:SetPoint("TOPLEFT", 2, -2)
    skin.borderMask:SetPoint("BOTTOMRIGHT", -2, 2)
    skin.borderMask:SetColorTexture(0.012, 0.014, 0.020, 1)

    local function Border()
        local texture = editBox:CreateTexture(nil, "BORDER", nil, 7)
        local red, green, blue = GetPlayerClassColor()
        texture:SetColorTexture(red, green, blue, 0.95)
        return texture
    end

    skin.top = Border()
    skin.top:SetPoint("TOPLEFT")
    skin.top:SetPoint("TOPRIGHT")
    skin.top:SetHeight(2)
    skin.bottom = Border()
    skin.bottom:SetPoint("BOTTOMLEFT")
    skin.bottom:SetPoint("BOTTOMRIGHT")
    skin.bottom:SetHeight(2)
    skin.left = Border()
    skin.left:SetPoint("TOPLEFT")
    skin.left:SetPoint("BOTTOMLEFT")
    skin.left:SetWidth(2)
    skin.right = Border()
    skin.right:SetPoint("TOPRIGHT")
    skin.right:SetPoint("BOTTOMRIGHT")
    skin.right:SetWidth(2)

    function skin:SetShown(shown)
        self.shown = shown
        self.background:SetShown(shown)
        self.borderMask:SetShown(shown)
        self.top:SetShown(shown)
        self.bottom:SetShown(shown)
        self.left:SetShown(shown)
        self.right:SetShown(shown)
    end

    function skin:SetFocused(focused)
        local red, green, blue = GetPlayerClassColor()
        local alpha = 0.95
        if focused then
            red = math.min(1, red * 1.12 + 0.03)
            green = math.min(1, green * 1.12 + 0.03)
            blue = math.min(1, blue * 1.12 + 0.03)
            alpha = 1
        end
        self.top:SetColorTexture(red, green, blue, alpha)
        self.bottom:SetColorTexture(red, green, blue, alpha)
        self.left:SetColorTexture(red, green, blue, alpha)
        self.right:SetColorTexture(red, green, blue, alpha)
    end

    editBox:HookScript("OnEditFocusGained", function()
        skin:SetFocused(true)
        if skin.shown then UpdateBlizzardEditBoxArtwork(editBox, true) end
    end)
    editBox:HookScript("OnEditFocusLost", function() skin:SetFocused(false) end)
    editBox.ZTChatSkin = skin
    return skin
end

local function GetEditBoxTextRegions(editBox)
    local regions, seen = {}, {}
    local name = editBox and editBox.GetName and editBox:GetName()

    local function Add(region)
        if region and region.SetFont and not seen[region] then
            seen[region] = true
            regions[#regions + 1] = region
        end
    end

    for _, key in ipairs({
        "header", "Header",
        "headerSuffix", "HeaderSuffix",
        "languageHeader", "LanguageHeader",
        "prompt", "Prompt",
        "NewcomerHint", "newcomerHint",
    }) do
        Add(editBox and editBox[key])
        if name then Add(_G[name .. key]) end
    end

    return regions
end


local function ApplyEditBoxTextRegionFonts(editBox, enabled, fontPath, fontSize, fontFlags)
    local changed = false

    for _, region in ipairs(GetEditBoxTextRegions(editBox)) do
        local original = originalEditBoxRegionFonts[region]
        if not original and region.GetFont then
            local path, size, flags = region:GetFont()
            original = {
                path = path,
                size = size,
                flags = flags,
                height = region.GetHeight and region:GetHeight() or nil,
            }
            originalEditBoxRegionFonts[region] = original
        end

        if enabled and fontPath then
            changed = ApplyFontIfChanged(region, fontPath, fontSize, fontFlags) or changed
            if region.SetHeight then region:SetHeight(fontSize + 4) end
        elseif original and original.path then
            changed = ApplyFontIfChanged(region, original.path, original.size, original.flags) or changed
            if region.SetHeight and original.height then region:SetHeight(original.height) end
        end
    end

    return changed
end

local function RefreshEditBox(frame)
    local db = GetDB()
    local name = GetChatFrameName(frame)
    local editBox = frame and (frame.editBox or (name and _G[name .. "EditBox"]))
    if not editBox or not db then return end

    -- Prat's Editbox module owns the same frame and changes its anchors, alpha,
    -- and mouse state during chat activation. Let one addon own that lifecycle;
    -- otherwise a channel/player hyperlink can open an edit box that the other
    -- addon immediately moves or deactivates again.
    if PratOwnsEditBox(editBox) then
        if editBox.ZTChatSkin then editBox.ZTChatSkin:SetShown(false) end
        return
    end

    RememberEditBoxPoints(editBox)
    if editBox.SetAltArrowKeyMode then
        if db.enabled and db.arrowKeyHistory then
            if originalArrowModes[editBox] == nil and editBox.GetAltArrowKeyMode then
                originalArrowModes[editBox] = editBox:GetAltArrowKeyMode()
            end
            editBox:SetAltArrowKeyMode(false)
        elseif originalArrowModes[editBox] ~= nil then
            editBox:SetAltArrowKeyMode(originalArrowModes[editBox])
            originalArrowModes[editBox] = nil
        end
    end

    local position = db.enabled and db.editBoxPosition or "blizzard"
    local originalFont = originalEditBoxFonts[editBox]
    local typingFontSize = Clamp(db.editBoxFontSize or (originalFont and originalFont.size) or 14, 10, 20)
    local typingBoxHeight = math.max(24, typingFontSize + 14)
    local leftOffset, rightOffset = GetAttachedEditBoxOffsets(frame)
    leftOffset = leftOffset + EDIT_BOX_HORIZONTAL_SHIFT
    rightOffset = rightOffset + EDIT_BOX_HORIZONTAL_SHIFT
    if position == "default" then position = "bottom" end
    if position == "top" then
        editBox:ClearAllPoints()
        editBox:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", leftOffset, EDIT_BOX_GAP)
        editBox:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", rightOffset, EDIT_BOX_GAP)
        editBox:SetHeight(typingBoxHeight)
    elseif position == "bottom" then
        editBox:ClearAllPoints()
        editBox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", leftOffset, -EDIT_BOX_GAP)
        editBox:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", rightOffset, -EDIT_BOX_GAP)
        editBox:SetHeight(typingBoxHeight)
    else
        RestoreEditBoxPoints(editBox)
    end

    local fontPath = originalFont and originalFont.path
    local fontFlags = originalFont and originalFont.flags
    if db.enabled and originalFont then
        local fontChoice = db.editBoxFont or "default"
        local pathProvider = editBoxFontPaths[fontChoice]
        if pathProvider then fontPath = pathProvider() end
        if fontPath then
            ApplyFontIfChanged(editBox, fontPath, typingFontSize, originalFont.flags)
            editBox.ZTChatFontApplied = true
        end
    elseif editBox.ZTChatFontApplied and originalFont then
        ApplyFontIfChanged(editBox, originalFont.path, originalFont.size, originalFont.flags)
        editBox.ZTChatFontApplied = nil
    end

    local styled = db.enabled and db.styledEditBox == true
    local skin = CreateEditBoxSkin(editBox)
    skin:SetShown(styled)
    skin:SetFocused(styled and editBox.HasFocus and editBox:HasFocus())
    UpdateBlizzardEditBoxArtwork(editBox, styled)

    local textRegionsChanged = ApplyEditBoxTextRegionFonts(
        editBox,
        db.enabled == true,
        fontPath,
        typingFontSize,
        fontFlags
    )
    if textRegionsChanged and type(ChatEdit_UpdateHeader) == "function" then
        pcall(ChatEdit_UpdateHeader, editBox)
    end

    local header = editBox.header or (editBox.GetName and _G[(editBox:GetName() or "") .. "Header"])
    if header and header.GetTextColor and header.SetTextColor then
        if not originalHeaderColors[header] then
            originalHeaderColors[header] = { header:GetTextColor() }
        end
        if db.enabled and db.channelIndicator then
            header:SetTextColor(1, 0.82, 0.26)
        else
            header:SetTextColor(unpack(originalHeaderColors[header]))
        end
    end

    RefreshEditModeSelection(frame, editBox, db)
end

local function SetupChatFrame(frame)
    if not frame then return end
    RestoreChatInteractivity(frame)
    if trackedFrames[frame] then return end
    trackedFrames[frame] = true

    if frame.GetFont then
        local path, size, flags = frame:GetFont()
        originalFonts[frame] = { path = path, size = size, flags = flags }
    end
    if frame.GetFading then frame.ZTChatOriginalFading = frame:GetFading() end
    if frame.GetTimeVisible then frame.ZTChatOriginalTimeVisible = frame:GetTimeVisible() end

    CreateCopyButton(frame)
    CreateUnreadButton(frame)
    local name = GetChatFrameName(frame)
    local editBox = frame.editBox or (name and _G[name .. "EditBox"])
    if editBox and not PratOwnsEditBox(editBox) and not editBox.ZTChatLayoutHooked then
        editBox.ZTChatLayoutHooked = true
        editBox:HookScript("OnShow", function()
            -- Blizzard recalculates the edit box's traditional inset width while
            -- activating chat. Reapply our full-width layout after that update.
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function() RefreshEditBox(frame) end)
            else
                RefreshEditBox(frame)
            end
        end)
    end
    if hooksecurefunc and frame.Selection and frame.AnchorSelectionFrame and not frame.ZTChatSelectionHooked then
        frame.ZTChatSelectionHooked = true
        RememberEditModeSelectionPoints(frame)
        hooksecurefunc(frame, "AnchorSelectionFrame", function(self)
            local frameName = GetChatFrameName(self)
            local currentEditBox = self.editBox or (frameName and _G[frameName .. "EditBox"])
            RefreshEditModeSelection(self, currentEditBox, GetDB())
        end)
    end
    frame:EnableMouseWheel(true)
    frame:HookScript("OnEnter", function(self) RefreshFrameAppearance(self) end)
    frame:HookScript("OnLeave", function(self) ScheduleFrameRefresh(self) end)
    frame:HookScript("OnShow", function(self) RefreshFrameAppearance(self) end)
    frame:HookScript("OnSizeChanged", function(self) RefreshEditBox(self) end)
    frame:HookScript("OnMouseWheel", function(self, delta)
        local db = GetDB()
        if not db or not db.enabled then return end

        if db.enhancedScroll then
            if IsControlKeyDown and IsControlKeyDown() then
                if delta > 0 and self.ScrollToTop then self:ScrollToTop()
                elseif delta < 0 and self.ScrollToBottom then self:ScrollToBottom() end
            elseif IsShiftKeyDown and IsShiftKeyDown() then
                for _ = 1, 3 do
                    if delta > 0 and self.ScrollUp then self:ScrollUp()
                    elseif delta < 0 and self.ScrollDown then self:ScrollDown() end
                end
            end
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if not IsScrolledBack(self) then ClearUnread(self) end
            end)
        elseif not IsScrolledBack(self) then
            ClearUnread(self)
        end
    end)

    if hooksecurefunc and frame.AddMessage then
        hooksecurefunc(frame, "AddMessage", function(self)
            local db = GetDB()
            if db and db.enabled and db.newMessageIndicator and IsScrolledBack(self) then
                MarkUnread(self)
            end
        end)
    end

    RefreshEditBox(frame)
    RefreshFrameAppearance(frame)
end

local function SetupAllChatFrames()
    local count = tonumber(NUM_CHAT_WINDOWS) or 10
    for index = 1, count do
        SetupChatFrame(_G["ChatFrame" .. index])
    end
end

function ns:RefreshChatEnhancements()
    SetupAllChatFrames()
    for frame in pairs(trackedFrames) do
        RefreshEditBox(frame)
        RefreshFrameAppearance(frame)
    end
end

function ns:SetChatOption(key, value)
    local db = GetDB()
    if not db or db[key] == nil then return false end
    db[key] = value
    self:RefreshChatEnhancements()
    if key:match("^history") and self.RefreshChatHistory then self:RefreshChatHistory() end
    return true
end

function ns:InitializeChatEnhancements()
    if initialized then
        self:RefreshChatEnhancements()
        return
    end
    initialized = true

    InstallItemRefCleanup()

    for _, event in ipairs(CHAT_EVENTS) do
        if ChatFrame_AddMessageEventFilter then
            pcall(ChatFrame_AddMessageEventFilter, event, URLMessageFilter)
        end
    end

    local registeredLinkHandler = false
    if LinkUtil and LinkUtil.RegisterLinkHandler
        and (not LinkUtil.IsLinkHandlerRegistered or not LinkUtil.IsLinkHandlerRegistered("zturl")) then
        LinkUtil.RegisterLinkHandler("zturl", function(link, text, linkData)
            local url = linkData and linkData.options
                or (type(link) == "string" and link:match("^zturl:(.+)$"))
                or text
            if url then ShowURLCopy(url) end
        end)
        registeredLinkHandler = true
    end

    if not registeredLinkHandler and hooksecurefunc and SetItemRef then
        hooksecurefunc("SetItemRef", function(link)
            local url = type(link) == "string" and link:match("^zturl:(.+)$")
            if url then ShowURLCopy(url) end
        end)
    end

    if hooksecurefunc and FCF_OpenNewWindow then
        hooksecurefunc("FCF_OpenNewWindow", function()
            if C_Timer and C_Timer.After then C_Timer.After(0, SetupAllChatFrames) end
        end)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("UPDATE_CHAT_WINDOWS")
    events:SetScript("OnEvent", function()
        ns:RefreshChatEnhancements()
    end)

    SetupAllChatFrames()
end
