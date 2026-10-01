# hammerspoon-toolkit

A small collection of macOS productivity scripts for [Hammerspoon](https://www.hammerspoon.org/). Each feature is its own file, so you can turn on only the ones you want.

## Scripts

| Script | What it does | On by default |
|---|---|---|
| `menubar-unread` | Slack and WhatsApp icons in the menu bar with their unread count | ✅ |
| `menubar-clock` | A second clock with date for another time zone (default: New York) | ✅ |
| `clipboard-history` | Press ⌃⌘V to search recently copied text and paste it | ✅ |
| `floating-unread-buttons` | Floating, draggable unread buttons for Slack and WhatsApp (an alternative to `menubar-unread`) | ❌ |

All settings live in a `config` table at the top of each script.

### menubar-unread
- Shows the Slack and WhatsApp icons in the menu bar, with the unread count next to them when there are new messages. Click an icon to open the app.
- Reads only the red badge number on the app's Dock icon (via macOS's `lsappinfo`). It never reads your messages or connects to the internet.
- Counts appear only while the app is open (it can be in the background). Set `showWhenRead = false` to hide icons when nothing is unread.
- Add other apps by editing the `apps` list.

### menubar-clock
- Shows another time zone's date and time like the macOS clock, e.g. `NY Thu Oct 1  7:03 PM`. Click it for the full date and the hour difference from your local time.
- Change the city with `timezone` (any name from `/usr/share/zoneinfo`, e.g. `Europe/London`) and the text with `label`. `hour24` and `showDate` control the format.
- Cmd+drag it to move it in the menu bar; the position is remembered. (macOS doesn't let apps sit between Apple's own icons and the system clock.)

### clipboard-history
- Remembers the last 25 pieces of text you copied. Press **⌃⌘V** (Ctrl+Cmd+V), type to filter, and press Enter to paste.
- Skips items that password managers mark as secret.
- History is kept in memory only. Nothing is written to disk, and it's cleared when Hammerspoon reloads.
- ⌃⌘V is used instead of ⌘⇧V because many apps already use ⌘⇧V for "paste as plain text". Change it with `hotkey`.

### floating-unread-buttons (off by default)
- Same unread check as `menubar-unread`, but shown as floating buttons in the bottom-right corner of the screen. Click to open the app, drag to move.

## Setup

1. Install Hammerspoon, open it once, and grant **Accessibility** permission when asked:
   ```sh
   brew install --cask hammerspoon
   ```
2. Clone this repo anywhere you like:
   ```sh
   git clone <this-repo-url> ~/hammerspoon-toolkit
   cd ~/hammerspoon-toolkit
   ```
3. Point Hammerspoon at the repo with a symlink. Run this from inside the cloned folder. It backs up an existing config to `init.lua.bak` first:
   ```sh
   REPO="$(pwd)"
   mkdir -p ~/.hammerspoon
   [ -e ~/.hammerspoon/init.lua ] && [ ! -L ~/.hammerspoon/init.lua ] && mv ~/.hammerspoon/init.lua ~/.hammerspoon/init.lua.bak
   ln -sf "$REPO/hammerspoon/init.lua" ~/.hammerspoon/init.lua
   ls -la ~/.hammerspoon   # init.lua -> .../hammerspoon/init.lua
   ```
4. Reload Hammerspoon (menu bar icon → **Reload Config**).

### How the symlink works

Hammerspoon always loads `~/.hammerspoon/init.lua`. That file is a symlink into this repo, and `init.lua` follows the link to find the `scripts/` folder. Edit files in the repo and reload; there's nothing to copy.

## Turning scripts on and off

`hammerspoon/init.lua` holds the list of scripts to load:

```lua
local scripts = {
  -- "floating-unread-buttons",
  "menubar-unread",
  "menubar-clock",
  "clipboard-history",
}
```

Comment a line out with `--` to turn a script off. If one script has an error, the others still load, and the error appears in an alert and in the Hammerspoon Console.

## Adding your own script

1. Create `hammerspoon/scripts/my-script.lua`.
2. Add `"my-script",` to the list in `hammerspoon/init.lua`.
3. Reload Hammerspoon.

Tip: keep timers, watchers and hotkeys in global variables so Lua's garbage collector doesn't stop them.

## Requirements

- macOS with [Hammerspoon](https://www.hammerspoon.org/) installed
- Accessibility permission for Hammerspoon (needed for hotkeys, pasting and dragging)

## License

[MIT](LICENSE)
