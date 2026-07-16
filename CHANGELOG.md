# Changelog

## Unreleased

- Expanded talent recommendations with Archon, Icy Veins, Wowhead, and reconstructed Murlok.io PvP builds.
- Added alternate-specialization suggestions when the selected PvP bracket has no build for the active specialization.
- Improved talent application for leveling characters, including deferred max-level talents and recovery from stalled Blizzard commits.
- Refreshed generated talent and stat data across all 13 classes and 40 specializations.
- Isolated module initialization failures so one optional feature cannot prevent the remaining addon from loading.
- Preserved nil return values in diagnostic wrappers and stopped reseeding WoW's shared random-number generator.
- Removed an unused legacy ZoidsTools damage meter module that was no longer loaded.
- Refreshed project documentation to match the current addon features.
- Updated visible talent helper wording to use Talents instead of Grimoire.
- Deferred non-essential UI refresh work during combat to reduce busy-fight frame churn.
- Limited tooltip item-level and Mythic+ detail lookups during combat to cached data only.
- Reduced target-change stutter by avoiding full unit-frame refreshes and prebuilding target mount lookup data.

## 0.1.0

- Initial ZoidsTools release.
- Added movable Blizzard UI windows and default bag movement.
- Added saved positions and Ctrl-scroll window scaling.
- Added item overlays for character gear, bags, bank, and Warband bank.
- Added configurable action keybind text and full-button range tint.
- Added fast auto loot, auto-sell grey items, and auto repair.
- Added quest and gossip automation with filters and pause modifier.
- Added performance and coordinates widgets.
