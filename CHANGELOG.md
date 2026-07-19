# Changelog

## Unreleased

- Isolated unit-tooltip styling from Blizzard's shared quest-reward and map-POI construction, preventing secret-value sizing taint in embedded reward and widget tooltips.
- Added source-ordered secondary-stat priorities to generated stat goals and displayed them in a taller, better-aligned Character Stats Goals header.
- Normalized Scenario and Dungeon tracker header widths so their titles, bars, and collapse buttons align with Campaign and Quest sections.
- Recalculated objective-tracker module line and block heights after text scaling so enlarged outlined multiline objectives no longer overlap the following quest.
- Applied unit-tooltip appearance before display and updated inspected item level in place, eliminating the visible default-to-custom tooltip redraw.
- Inset Dungeon, Scenario, and other objective-tracker section collapse buttons so they remain inside the customized tracker border.
- Shifted attached chat typing boxes two pixels right for cleaner alignment with Blizzard's visible chat edge.
- Prevented stopped or reload-cleared diagnostic sessions from reporting WoW's client uptime as a zero-frame test result.
- Shifted Blizzard's Objective Tracker Edit Mode selection outline to match the customized tracker's visible horizontal bounds.
- Reduced UI overhead by coalescing objective-tracker, action-bar, and open Chat Copy refresh bursts, avoiding unchanged tracker font and layout writes, and replacing quest-item per-frame polling with a short active-only timer.
- Added an optional outline style for Blizzard objective-tracker text.
- Added a persistent Blizzard Edit button beside the settings search field for opening Blizzard's interface layout editor directly from ZoidsTools.
- Added an optional objective-tracker setting that reduces the minimized tracker to only Blizzard's restore (+) button.
- Enlarged the Missing Buffs popup icons and made unavailable buff buttons announce the missing spell to instance, raid, or party chat when clicked.
- Excluded Blizzard's protected Flight Map canvas from movable-window handling to prevent quest-pin SetPassThroughButtons taint.
- Made chat history, URL conversion, and mention detection ignore Blizzard secret-string payloads without interfering with their normal display.
- Preserved the Chat Copy window's scroll position as new messages arrive, while continuing to follow new messages when already at the bottom.
- Added a movable, key-bindable smart quest-item button that follows Blizzard's area rules and prioritizes the current quest area, the super-tracked quest, then the nearest tracked quest.
- Added optional Blizzard objective-tracker appearance controls for account-wide scale, responsive width, text size, a content-fitted background, background opacity, class-colored borders, mouseover header buttons, and a safe icon inset without replacing the native tracker.
- Stopped fitted tracker backgrounds from changing Blizzard's managed tracker height, eliminating position oscillation in the default objective-tracker location.
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
- Corrected settings-page clipping so scrolled controls and dividers stay inside the inner content panel instead of overlapping the fixed title and search header.
- Inset the settings-page clipping viewport beneath the inner top border and debounced objective-tracker text scaling to prevent managed-position flicker during slider movement.
- Routed unread detection through Blizzard's chat-message filters, with the message-frame hook retained as a fallback, so new-message alerts work reliably on Retail.
- Added a responsive ZoidsTools skin for chat typing boxes and attached them to the full width of their chat frame by default.
- Separated attached typing boxes from the chat frame, included them in Edit Mode screen bounds, and added independent typing-font and font-size controls with responsive box height.
- Made the typing-box channel prompt scale with the selected typing font size and fully masked Blizzard's redundant inset borders.
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
