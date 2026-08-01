local _, ns = ...

-- Verified bag-only quest items that Blizzard does not expose through
-- GetQuestLogSpecialItemInfo. Keep this compact: the runtime bag scan and
-- Blizzard quest APIs cover the normal cases without a large embedded DB.
ns.QuestItemData = {
    [92138] = { 250440 }, -- Mobilize! Enlist! Recruit! / Recruitment Fliers
}
