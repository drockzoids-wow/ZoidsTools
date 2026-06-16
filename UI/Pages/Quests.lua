local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateQuestsPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local automationSection = UI.CreateSection(frame, "Automation", nil, 0)

    local autoAccept = UI.CreateCheckbox(
        frame,
        "Auto accept quests",
        "Automatically accepts available quests unless the pause modifier is held.",
        function()
            return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("autoAccept")
        end,
        function(value)
            if ns.SetQuestAutomationOption then
                ns:SetQuestAutomationOption("autoAccept", value)
            end
        end
    )
    autoAccept:SetPoint("TOPLEFT", automationSection, "BOTTOMLEFT", 18, -6)

    local autoTurnIn = UI.CreateCheckbox(
        frame,
        "Auto turn in quests",
        "Automatically completes ready quests. Multiple reward choices are left for manual selection.",
        function()
            return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("autoTurnIn")
        end,
        function(value)
            if ns.SetQuestAutomationOption then
                ns:SetQuestAutomationOption("autoTurnIn", value)
            end
        end
    )
    autoTurnIn:SetPoint("TOPLEFT", autoAccept, "BOTTOMLEFT", 0, -8)

    local autoGossip = UI.CreateCheckbox(
        frame,
        "Auto gossip",
        "Automatically advances simple gossip windows unless the pause modifier is held.",
        function()
            return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("autoGossip")
        end,
        function(value)
            if ns.SetQuestAutomationOption then
                ns:SetQuestAutomationOption("autoGossip", value)
            end
        end
    )
    autoGossip:SetPoint("TOPLEFT", autoTurnIn, "BOTTOMLEFT", 0, -8)

    local pauseModifier = UI.CreateDropdown(
        frame,
        "Pause modifier",
        "Hold this key to temporarily pause auto questing and auto gossip.",
        ns.GetQuestAutomationPauseModifierOptions and ns:GetQuestAutomationPauseModifierOptions() or {
            { value = "shift", text = "Shift" },
            { value = "ctrl", text = "Ctrl" },
            { value = "alt", text = "Alt" },
            { value = "none", text = "None" },
        },
        function()
            return ns.GetQuestAutomationPauseModifier and ns:GetQuestAutomationPauseModifier() or "shift"
        end,
        function(value)
            if ns.SetQuestAutomationPauseModifier then
                ns:SetQuestAutomationPauseModifier(value)
            end
        end,
        220
    )
    pauseModifier:SetPoint("TOPLEFT", autoGossip, "BOTTOMLEFT", 0, -14)

    local filtersSection = UI.CreateSection(frame, "Filters", pauseModifier, -30)

    local skipDaily = UI.CreateCheckbox(
        frame,
        "Skip daily and weekly quests",
        "Prevents auto accept and auto turn-in for daily, weekly, recurring, and calling quests.",
        function()
            return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("skipDaily")
        end,
        function(value)
            if ns.SetQuestAutomationOption then
                ns:SetQuestAutomationOption("skipDaily", value)
            end
        end
    )
    skipDaily:SetPoint("TOPLEFT", filtersSection, "BOTTOMLEFT", 18, -6)

    local skipWarband = UI.CreateCheckbox(
        frame,
        "Skip Warband-completed quests",
        "Prevents auto accept and auto turn-in for quests already completed by your Warband.",
        function()
            return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("skipWarbandCompleted")
        end,
        function(value)
            if ns.SetQuestAutomationOption then
                ns:SetQuestAutomationOption("skipWarbandCompleted", value)
            end
        end
    )
    skipWarband:SetPoint("TOPLEFT", skipDaily, "BOTTOMLEFT", 0, -8)

    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", skipWarband, "BOTTOMLEFT", 0, -20)
    status:SetWidth(540)
    status:SetJustifyH("LEFT")
    status:SetText("Quest rewards with multiple choices are never selected automatically.")

    function frame:Refresh()
        autoAccept:Refresh()
        autoTurnIn:Refresh()
        autoGossip:Refresh()
        pauseModifier:Refresh()
        skipDaily:Refresh()
        skipWarband:Refresh()
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
