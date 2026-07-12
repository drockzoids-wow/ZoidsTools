local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateQuestsPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local automationSection = UI.PlaceSection(frame, "Automation")

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
    UI.PlaceFirst(autoAccept, automationSection)

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
    UI.PlaceBelow(autoTurnIn, autoAccept)

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
    UI.PlaceBelow(autoGossip, autoTurnIn)

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
    UI.PlaceDropdown(pauseModifier, autoGossip)

    local filtersSection = UI.PlaceSection(frame, "Filters", pauseModifier)

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
    UI.PlaceFirst(skipDaily, filtersSection)

    local skipWarband = UI.CreateCheckbox(
        frame,
        "Skip Warband-completed quests",
        "Prevents auto accept for quests already completed by your Warband. Allowed daily quests are an exception, and completed quests are still turned in.",
        function()
            return ns.GetQuestAutomationOption and ns:GetQuestAutomationOption("skipWarbandCompleted")
        end,
        function(value)
            if ns.SetQuestAutomationOption then
                ns:SetQuestAutomationOption("skipWarbandCompleted", value)
            end
        end
    )
    UI.PlaceBelow(skipWarband, skipDaily)

    local status = UI.CreateStatusText(frame)
    UI.PlaceBelow(status, skipWarband, 0, 20)
    status:SetText("Quest rewards with multiple choices are never selected automatically.")

    function frame:Refresh()
        autoAccept:Refresh()
        autoTurnIn:Refresh()
        autoGossip:Refresh()
        pauseModifier:Refresh()
        skipDaily:Refresh()
        skipWarband:Refresh()

        local automationActive = (ns.GetQuestAutoAccept and ns:GetQuestAutoAccept())
            or (ns.GetQuestAutoTurnIn and ns:GetQuestAutoTurnIn())
            or (ns.GetQuestAutoGossip and ns:GetQuestAutoGossip())
        UI.SetControlEnabled(pauseModifier, automationActive)
        UI.SetControlEnabled(skipDaily, ns.GetQuestAutoAccept and ns:GetQuestAutoAccept())
        UI.SetControlEnabled(skipWarband, ns.GetQuestAutoAccept and ns:GetQuestAutoAccept())
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
