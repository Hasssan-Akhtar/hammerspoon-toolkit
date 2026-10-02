# CLAUDE.md

Guidance for Claude Code (and other AI assistants) helping someone use, customize, or extend this repo: a set of macOS productivity scripts for [Hammerspoon](https://www.hammerspoon.org/), written in plain Lua with the `hs.*` APIs (no Spoons).

## Layout

- `hammerspoon/init.lua`: the entry point. The user's `~/.hammerspoon/init.lua` should be a **symlink** to this file (see Setup in `README.md`). Never replace the symlink with a copy, or the repo and the live config drift apart. `init.lua` resolves the symlink to find `hammerspoon/scripts/`, adds it to `package.path`, and `require`s each enabled script inside `pcall` so one failure doesn't stop the rest.
- `hammerspoon/lib/toolkitbar.lua`: shared helper, not a script (not auto-discovered). Scripts create menu bar items with `toolkitbar.new(autosaveName)`, which mirrors the `hs.menubar` methods the scripts use (`setTitle`, `setIcon`, `setTooltip`, `setMenu`, `setClickCallback`, `delete`) and adds `setCompactTitle` and `setBadge`. When any screen is narrower than `compactBelowWidth` (set in `init.lua`, default 1600 pt), items drop their real `hs.menubar` and appear as rows in the 🧰 menu instead; badges are summed (numbers) or listed (other text) on the 🧰 title. An `hs.screen.watcher` switches modes live, without a reload. This exists because macOS silently hides menu bar items that don't fit (notch, narrow displays) and apps can't detect it. Note `hs.menubar.new(true, nil)` errors, so only pass an autosave name when there is one.
- `hammerspoon/scripts/<name>.lua`: one feature per file. Each has a `config` table at the top with the settings users are meant to change.
- `README.md`: user-facing docs (per-script sections, setup, menu). Keep it in sync when scripts, settings, or setup change.
- `LICENSE`: MIT, copyright "hammerspoon-toolkit contributors".

## Turning scripts on and off

- The `scripts` list at the top of `init.lua` sets each script's menu `title` and its `default` on/off. Any other `.lua` file in `scripts/` is found automatically and is off by default.
- Each user's on/off choices are saved in `hs.settings` under `toolkit.enabled.<name>`, never in the repo. To change what's running, use the 🧰 menu bar item, not edits to `init.lua`. Edit `default` only to change what new users get.
- Toggling saves the choice and then calls `hs.reload()`, because scripts can't be unloaded cleanly. Scripts that fail to load are marked ⚠️ in the menu. The menu also has Reload, Open Console, Open scripts folder, and Reset to defaults.

## Scripts

- `menubar-unread` (on): Slack/WhatsApp icons in the menu bar with their unread count. Reads only the Dock badge text via `/usr/bin/lsappinfo info -only StatusLabel`. Badges exist only while the app is running, so a quit app shows no count. `apps` takes Dock names plus bundle IDs for finding icons; `showWhenRead` keeps icons visible with no unread.
- `menubar-clock` (on): date and time for another time zone (default `America/New_York`, label `NY`). Uses `TZ=<zone> /bin/date` because Lua's `os.date` only knows local time. Updates on each minute boundary. The click menu shows the full date, the zone, and the hour difference from local time. Uses autosave name `menubarClock` so a Cmd+drag position survives reloads. Apps can't choose their menu bar position or sit right of Apple's system icons.
- `clipboard-history` (on): `hs.pasteboard.watcher` records copied text (newest first, deduped, `maxItems` 25). History is **in memory only by design** (privacy): don't add disk persistence unless the user explicitly asks. Skips pasteboard types that password managers use to mark items concealed/transient. ⌃⌘V opens an `hs.chooser`; picking an item sets the clipboard and sends ⌘V (`autoPaste`). ⌘⇧V was avoided because many apps use it for paste-as-plain-text.
- `caffeine` (off): ☕/💤 menu bar item (autosave `caffeine`) that keeps the Mac awake for a set time or until turned off, via `hs.caffeinate.set` (`displayIdle` by default, `systemIdle` if `keepDisplayOn = false`). The end time (`os.time()` value or `"forever"`) is saved in `hs.settings` under `caffeine.until`, so toggling other scripts (which reloads Hammerspoon) doesn't turn it off. A 30-second timer refreshes the time left and turns it off when time is up.
- `floating-unread-buttons` (off): an alternative to `menubar-unread` that shows floating, draggable buttons using the same badge check. The dragged position is saved in `hs.settings` under `unreadButtons.position`.

## Adding a script

1. Create `hammerspoon/scripts/<name>.lua` following the existing pattern: header comment explaining what it does (and doesn't do), a `config` table, then the code, then a "Start everything" section.
2. For a menu bar icon, use `require("toolkitbar").new()`, not `hs.menubar.new()`, so it folds into 🧰 on small screens. Set `setCompactTitle` if the menu bar title alone wouldn't make sense as a menu row, and `setBadge` for anything worth seeing at a glance.
3. Keep timers, watchers, hotkeys, menubar items, and chooser objects in **global variables** so Lua's garbage collector doesn't stop them. All scripts share one global namespace, so give globals a script-specific prefix (e.g. `clipboardWatcher`, `menubarClockTimer`).
4. Add an entry to the `scripts` list in `init.lua` for a menu title and default, plus a section and table row in `README.md`.

## Testing changes

- Reload with the 🧰 menu → Reload Hammerspoon, or `killall Hammerspoon; open -a Hammerspoon`, then check the Hammerspoon Console for errors.
- The `hs` command-line tool only works if `hs.ipc` is loaded, which this config doesn't do by default. Don't assume you can run Lua inside Hammerspoon from the shell.
- Hotkeys, pasting, and dragging need Accessibility permission for Hammerspoon.

## Keep the repo generic

This is a public, shareable repo. Tracked files must not contain personal names, emails, usernames, absolute home paths, or machine-specific details. Personal preferences belong in `hs.settings` or in the user's own copy of a `config` table, not in the defaults. Check `git diff` for these before committing.
