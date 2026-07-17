# Changelog

## Unreleased

- Added lightweight Blizzard chat enhancements with searchable chat copying, clickable URL copying, modifier-key scrolling, and optional appearance controls.
- Made Escape consistently close the Chat Copy window, including while its search or text field has focus.
- Kept the Chat Copy button subtly visible and brightened it on mouseover or while its copy window is open.
- Preserved original chat and item-quality colors in Chat Copy while preventing Retail's named colors from leaking into later lines.
- Added a new-message jump button for chat frames that are scrolled away from the newest message.
- Added optional character-name mention highlighting with a deduplicated alert sound.
- Added opt-in per-character saved chat history with channel filters, a 100-500 message limit, login restoration, clearing, and copy/search integration.
- Added named account-wide Blizzard chat layouts for tabs, filters, channels, font sizes, docking, window sizes, and undocked positions.
- Added typing-box placement, arrow-key sent-message history, and a clearer active-channel label.
- Removed a retired Battle.net conversation event and made optional chat-event registration resilient to future API removals.
- Reorganized Chat settings into compact General, History & Input, and Chat Layouts panels so every control remains inside the settings window.
- Tightened Chat page column widths so section dividers remain within the inner panel at larger interface scales.
- Routed unread detection through Blizzard's chat-message filters, with the message-frame hook retained as a fallback, so new-message alerts work reliably on Retail.
- Added a responsive ZoidsTools skin for chat typing boxes and attached them to the full width of their chat frame by default.
- Separated attached typing boxes from the chat frame, included them in Edit Mode screen bounds, and added independent typing-font and font-size controls with responsive box height.
- Corrected Retail texture creation arguments for the chat typing-box skin and covered Blizzard's lowercase focus artwork fields.
- Prevented player class-color health overrides from interfering while Blizzard's player frame is displaying vehicle health.
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
