# hammerspoon-toolkit

A small collection of macOS productivity scripts for [Hammerspoon](https://www.hammerspoon.org/). Each feature is its own file, so you can turn on only the ones you want.

## Scripts

| Script | What it does | On by default |
|---|---|---|
| `menubar-unread` | Slack and WhatsApp icons in the menu bar with their unread count | ✅ |
| `menubar-clock` | A second clock with date for another time zone (default: New York) | ✅ |
| `clipboard-history` | Press ⌃⌘V to search recently copied text and paste it | ✅ |
| `caffeine` | A ☕ menu bar icon that keeps your Mac awake for a set time or until you turn it off | ❌ |
| `floating-unread-buttons` | Floating, draggable unread buttons for Slack and WhatsApp (an alternative to `menubar-unread`) | ❌ |

Turn scripts on and off from the **🧰** menu bar icon (see [below](#turning-scripts-on-and-off)). All other settings live in a `config` table at the top of each script.

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

### caffeine (off by default)
- Click the menu bar icon to keep your Mac awake for 15 minutes, 1 hour, 2 hours, or until you turn it off. It shows ☕ and the time left while on, 💤 while off.
- Stays on through Hammerspoon reloads. It doesn't change your Energy settings; macOS goes back to normal when it's turned off or Hammerspoon quits.
- Set `keepDisplayOn = false` to let the screen turn off while the Mac stays awake (useful for downloads). Change the menu choices with `durations`.

### floating-unread-buttons (off by default)
- Same unread check as `menubar-unread`, but shown as floating buttons in the bottom-right corner of the screen. Click to open the app, drag to move.

## Setup

1. Install Hammerspoon, open it once, and grant **Accessibility** permission when asked (needed for hotkeys, pasting and dragging):
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

Click the **🧰** icon in the menu bar. It lists every script with a ✓ next to the ones that are on. Click a script to switch it on or off, and Hammerspoon reloads automatically.

The menu also has **Reload Hammerspoon**, **Open Console**, **Open scripts folder**, and **Reset to defaults**. A script that fails to load is marked ⚠️ (details in the Console); the other scripts keep working.

Your choices are saved in Hammerspoon's own preferences on your Mac, not in the repo. The defaults (and the names shown in the menu) are set in the `scripts` list at the top of `hammerspoon/init.lua`.

## Small screens

macOS hides menu bar icons that don't fit (for example behind a MacBook's notch) and doesn't tell apps which ones it hid. So when any connected screen is narrower than 1600 points, the toolkit's icons fold into the **🧰** menu instead:

- 🧰 shows the total unread count and ☕ if caffeine is on, e.g. `🧰 5 ☕`.
- Its menu lists Slack and WhatsApp (click to open), the second clock, and caffeine, each with its usual menu.

It switches by itself when you plug in or unplug a display. Change the width (or set it to `0` to turn this off) with `compactBelowWidth` at the top of `hammerspoon/init.lua`. If 🧰 itself gets hidden, Cmd+drag it further right.

## Adding your own script

1. Create `hammerspoon/scripts/my-script.lua`.
2. Reload Hammerspoon. The script appears in the 🧰 menu, turned off; click it to turn it on.
3. Optional: add it to the `scripts` list in `hammerspoon/init.lua` to give it a nicer menu name or turn it on by default.

Tips:
- Keep timers, watchers and hotkeys in global variables so Lua's garbage collector doesn't stop them.
- For a menu bar icon, use `require("toolkitbar").new()` instead of `hs.menubar.new()` so it folds into 🧰 on small screens. It has the same methods (`setTitle`, `setIcon`, `setMenu`, …).

## License

[MIT](LICENSE)
