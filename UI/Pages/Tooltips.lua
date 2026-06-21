local _, ns = ...

ns.UI = ns.UI or {}
ns.UI.Pages = ns.UI.Pages or {}

function ns.UI.Pages.CreateTooltipsPage(parent)
    local UI = ns.UI
    local frame = UI.CreatePageFrame(parent)

    local appearanceSection = UI.PlaceSection(frame, "Appearance")

    local tooltipBackground = UI.CreateCheckbox(
        frame,
        "Faction background",
        "Adds a subtle Alliance blue or Horde red tint to player unit tooltips.",
        function()
            return ns.IsTooltipFactionBackgroundEnabled and ns:IsTooltipFactionBackgroundEnabled()
        end,
        function(value)
            if ns.SetTooltipFactionBackgroundEnabled then
                ns:SetTooltipFactionBackgroundEnabled(value)
            end
        end
    )
    UI.PlaceFirst(tooltipBackground, appearanceSection)

    local tooltipNames = UI.CreateCheckbox(
        frame,
        "Class-colored names",
        "Colors player names on unit tooltips by class.",
        function()
            return ns.IsTooltipClassColoredNamesEnabled and ns:IsTooltipClassColoredNamesEnabled()
        end,
        function(value)
            if ns.SetTooltipClassColoredNamesEnabled then
                ns:SetTooltipClassColoredNamesEnabled(value)
            end
        end
    )
    UI.PlaceBelow(tooltipNames, tooltipBackground)

    local playerDetailsSection = UI.PlaceSection(frame, "Player Details", tooltipNames)

    local tooltipScore = UI.CreateCheckbox(
        frame,
        "Show Mythic+ score",
        "Adds the player's current Mythic+ score to unit tooltips when available.",
        function()
            return ns.IsTooltipMythicScoreEnabled and ns:IsTooltipMythicScoreEnabled()
        end,
        function(value)
            if ns.SetTooltipMythicScoreEnabled then
                ns:SetTooltipMythicScoreEnabled(value)
            end
        end
    )
    UI.PlaceFirst(tooltipScore, playerDetailsSection)

    local tooltipScoreColor = UI.CreateCheckbox(
        frame,
        "Color Mythic+ score",
        "Colors Mythic+ score using percentile colors when available, otherwise Blizzard dungeon-score colors.",
        function()
            return ns.IsTooltipMythicScoreColorEnabled and ns:IsTooltipMythicScoreColorEnabled()
        end,
        function(value)
            if ns.SetTooltipMythicScoreColorEnabled then
                ns:SetTooltipMythicScoreColorEnabled(value)
            end
        end
    )
    UI.PlaceBelow(tooltipScoreColor, tooltipScore)

    local tooltipPercentile = UI.CreateCheckbox(
        frame,
        "Show M+ percentile",
        "Shows Raider.IO percentile next to Mythic+ score when another loaded addon exposes it.",
        function()
            return ns.IsTooltipMythicPercentileEnabled and ns:IsTooltipMythicPercentileEnabled()
        end,
        function(value)
            if ns.SetTooltipMythicPercentileEnabled then
                ns:SetTooltipMythicPercentileEnabled(value)
            end
        end
    )
    UI.PlaceBelow(tooltipPercentile, tooltipScoreColor)

    local tooltipItemLevel = UI.CreateCheckbox(
        frame,
        "Show item level",
        "Adds player item level to unit tooltips when inspect data is available.",
        function()
            return ns.IsTooltipItemLevelEnabled and ns:IsTooltipItemLevelEnabled()
        end,
        function(value)
            if ns.SetTooltipItemLevelEnabled then
                ns:SetTooltipItemLevelEnabled(value)
            end
        end
    )
    UI.PlaceBelow(tooltipItemLevel, tooltipPercentile)

    function frame:Refresh()
        tooltipBackground:Refresh()
        tooltipNames:Refresh()
        tooltipScore:Refresh()
        tooltipScoreColor:Refresh()
        tooltipPercentile:Refresh()
        tooltipItemLevel:Refresh()
    end

    frame:SetScript("OnShow", frame.Refresh)

    return frame
end
