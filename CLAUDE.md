# CLAUDE.md

Generic macOS automation scripts for Hammerspoon, intended to be shared publicly. Keep everything generic: no personal names, emails, usernames, absolute paths, or machine-specific details in tracked files.

## Layout

- `hammerspoon/init.lua`: the Hammerspoon entry point. `~/.hammerspoon/init.lua` is a **symlink** to this file, so edits here take effect on the next Hammerspoon reload. Do not replace the symlink with a copy. `init.lua` only holds the `scripts` list: it resolves the symlink to find `hammerspoon/scripts/`, adds that folder to `package.path`, and `require`s each script inside `pcall` so one failure doesn't block the rest.
- `hammerspoon/scripts/<name>.lua`: one feature per file. New features go here, plus one entry in the `scripts` list in `init.lua`.
- `README.md`: purpose, per-script docs table, and setup steps (keep in sync when scripts or setup change).
- `LICENSE`: MIT, copyright "hammerspoon-toolkit contributors" (no personal name).

## Current Hammerspoon features

- `menubar-unread` (enabled): Slack/WhatsApp icons with unread counts in the menu bar via `hs.menubar`, using the same `lsappinfo` badge check. Icons always show (`showWhenRead = true`); click opens the app. Badges only exist while the app is running, so a quit app shows no count.
- `menubar-clock` (enabled): New York date and time in the menu bar (`NY Thu Oct 1  7:03 PM`; `showDate` toggles the date), read via `TZ=America/New_York /bin/date` because Lua's `os.date` only knows local time; updated on each minute boundary. Click menu shows date, zone, and hour difference from local time. Created with autosaveName `menubarClock` so a Cmd+drag position survives reloads (apps cannot set menu bar position or go right of Apple's system icons).
- `clipboard-history` (enabled): `hs.pasteboard.watcher` records copied text (newest first, deduped, `maxItems` 25) in memory only, by design: no disk persistence, for privacy. Skips items whose pasteboard types mark them concealed/transient (password managers). ⌃⌘V opens an `hs.chooser`; picking sets the clipboard and sends ⌘V (`autoPaste`). ⌘⇧V was avoided because Slack/Chrome use it for paste-as-plain-text.
- `floating-unread-buttons` (disabled in `init.lua`, replaced by `menubar-unread`): floating unread-count buttons for Slack and WhatsApp, based on Dock badges read via `/usr/bin/lsappinfo`. Buttons are draggable; the dragged position is saved with `hs.settings` under `unreadButtons.position`. Settings are in the `config` table at the top of `scripts/floating-unread-buttons.lua`.

## Conventions

- Plain Lua with the `hs.*` APIs, no Spoons yet. Keep long-lived objects (timers, watchers) in globals so they aren't garbage-collected.
- Reload after changes: `killall Hammerspoon; open -a Hammerspoon` (or menu bar → Reload Config). Check the Hammerspoon Console for errors.
