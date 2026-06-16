# ZoidsTools

A personal World of Warcraft toolkit by Drockzoids.

## Current Features

- Opens a custom ZoidsTools control window with `/zt`, `/zoids`, or `/zoidstools`.
- Makes supported Blizzard UI windows movable.
- Adds movement handles to default bag windows, including the combined bag frame.
- Saves moved window positions between sessions.
- Saves per-window scale changes made with Ctrl + mouse wheel.
- Adds a combat option to cast action bar keybinds on key down.
- Adds configurable action bar keybind text with shorter labels, font sizing, color, bold, and outline options.
- Adds a draggable class-colored FPS and latency widget with click-through locking.
- Adds lightweight fast auto-loot behavior that enables WoW auto-loot when turned on.
- Adds vendor automation for grey item selling and repairs.
- Includes a LibDBIcon minimap launcher.

## Commands

- `/zt` opens the ZoidsTools window.
- `/zt windows` opens the Window Tools page.
- `/zt combat` opens the Combat page.
- `/zt loot` opens the Loot page.
- `/zt windows on` enables movable Blizzard windows.
- `/zt windows off` disables movable Blizzard windows.
- `/zt bags on` enables default bag movement.
- `/zt bags off` disables default bag movement.
- `/zt fastloot on` enables fast auto loot.
- `/zt fastloot off` disables fast auto loot.
- `/zt autosell on` enables auto-sell grey items at vendors.
- `/zt autosell off` disables auto-sell grey items at vendors.
- `/zt autorepair personal` repairs with your own gold.
- `/zt autorepair guild` repairs with guild bank funds when available.
- `/zt autorepair off` disables auto repair.
- `/zt keydown on` makes action keybinds cast on key down.
- `/zt keydown off` makes action keybinds cast on key up.
- `/zt perf on` shows the FPS and latency widget with both values.
- `/zt perf off` hides the FPS and latency widget.
- `/zt perf unlock` unlocks the click-through performance widget.
- `/zt resetwindows` clears saved window positions.
- `/zt resetscales` clears saved window scales.
- `/zt minimap on` shows the minimap button.
- `/zt minimap off` hides the minimap button.

## Window Scaling

- Hold `Ctrl` and mouse-wheel over a movable window or its `Move` handle to scale it.
- Hold `Ctrl` and right-click a `Move` handle to reset that window to its default position.
- Use `Windows > Reset Scales` in `/zt` to reset all saved window scales.

## Loot

- `Fast auto loot` performs one quick sweep when loot is ready.
- Turning `Fast auto loot` on enables WoW's auto-loot setting if needed.
- Turning `Fast auto loot` off only disables ZoidsTools fast looting; it does not turn WoW auto-loot off.
- `Careful second pass` adds one delayed follow-up sweep for unusual loot delays.
- `Auto-sell grey items` uses the merchant junk-sell behavior when a vendor opens.
- `Auto repair` can be Disabled, Use My Gold, or Use Guild Bank.
- `Use Guild Bank` repair skips instead of spending your own gold when guild repair is unavailable.

## Combat

- `Cast action keybinds on key down` uses WoW's action button key-down setting.
- `Customize action keybind text` changes action bar keybind font, size, color, bold, and outline.
- `Shorten keybind labels` condenses labels such as `s-C` to `SC` and `Mouse4` to `M4`.
- `Use custom color` is off by default so Blizzard's normal keybind color is preserved.

## Performance

- `Performance widget` chooses Disabled, FPS, Latency, or Both.
- `Widget size` adjusts the size of the draggable class-colored readout.
- Mouse over the widget to see FPS, Home latency, and World latency, even while locked on supported clients.
- Hold `Ctrl` and right-click the widget to lock it click-through.
- Hold `Shift` and right-click the widget to reset its position.
- Use `/zt perf unlock` or the unlock button in `/zt` to unlock the widget after it is click-through.

## Install

Copy or link the `ZoidsTools` folder into:

`World of Warcraft/_retail_/Interface/AddOns/`

## Release

CurseForge uploads are handled by GitHub Actions when a version tag is pushed.

1. Update `## Version` in `ZoidsTools.toc`.
2. Update `CHANGELOG.md`.
3. Commit and push the changes.
4. Create and push a tag like `v0.1.0`.
