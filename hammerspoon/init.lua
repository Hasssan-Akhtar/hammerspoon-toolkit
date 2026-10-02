-- ===========================================================
-- Hammerspoon entry point
--
-- Each feature lives in its own file in the scripts/ folder.
-- Turn scripts on and off from the 🧰 menu bar item; your choices
-- are saved in Hammerspoon's preferences, not in this repo.
--
-- The list below sets each script's menu name and whether it's on
-- by default. Any other .lua file in scripts/ also shows up in the
-- menu (off by default), so to add a script just drop it in there.
-- ===========================================================


-- ---------- Scripts and their defaults ----------
local scripts = {
  { name = "menubar-unread",          title = "Unread counts in menu bar", default = true },
  { name = "menubar-clock",           title = "Second clock",              default = true },
  { name = "clipboard-history",       title = "Clipboard history (⌃⌘V)",   default = true },
  { name = "floating-unread-buttons", title = "Floating unread buttons",   default = false },
}

local menuIcon = "🧰" -- text shown in the menu bar for the settings menu


-- ~/.hammerspoon/init.lua is a symlink into the repo, so follow it
-- to find the repo's scripts/ folder.
local here = hs.fs.pathToAbsolute(hs.configdir .. "/init.lua"):match("(.*)/")
local scriptsDir = here .. "/scripts"
package.path = scriptsDir .. "/?.lua;" .. package.path


-- ---------- Find scripts that aren't in the list above ----------
local known = {}
for _, s in ipairs(scripts) do known[s.name] = true end

local extra = {}
for file in hs.fs.dir(scriptsDir) do
  local name = file:match("^(.+)%.lua$")
  if name and not known[name] then table.insert(extra, name) end
end
table.sort(extra)
for _, name in ipairs(extra) do
  table.insert(scripts, { name = name, title = name, default = false })
end


-- ---------- On/off state (saved in Hammerspoon's preferences) ----------
local function settingKey(name) return "toolkit.enabled." .. name end

local function isEnabled(s)
  local saved = hs.settings.get(settingKey(s.name))
  if saved == nil then return s.default end
  return saved
end


-- ---------- Load the enabled scripts ----------
-- Each one loads on its own, so one broken script doesn't stop the
-- others. Errors show in an alert, the Console, and the 🧰 menu.
local failed = {} -- name -> error message

for _, s in ipairs(scripts) do
  if isEnabled(s) then
    local ok, err = pcall(require, s.name)
    if not ok then
      failed[s.name] = tostring(err)
      print("Failed to load " .. s.name .. ": " .. tostring(err))
      hs.alert.show("Failed to load " .. s.name .. " (see Console)")
    end
  end
end


-- ---------- 🧰 settings menu ----------
local function buildMenu()
  local items = { { title = "Scripts", disabled = true } }

  for _, s in ipairs(scripts) do
    local title = s.title
    if failed[s.name] then title = title .. "  ⚠️ failed to load" end
    table.insert(items, {
      title = title,
      checked = isEnabled(s),
      fn = function()
        -- Scripts can't be cleanly stopped while running, so save the
        -- choice and reload everything
        hs.settings.set(settingKey(s.name), not isEnabled(s))
        hs.reload()
      end,
    })
  end

  table.insert(items, { title = "-" })
  table.insert(items, { title = "Reload Hammerspoon", fn = hs.reload })
  table.insert(items, { title = "Open Console", fn = hs.openConsole })
  table.insert(items, { title = "Open scripts folder", fn = function() hs.open(scriptsDir) end })
  table.insert(items, { title = "Reset to defaults", fn = function()
    for _, s in ipairs(scripts) do hs.settings.clear(settingKey(s.name)) end
    hs.reload()
  end })
  return items
end

-- (Stored in a global so macOS doesn't clean it up. The name lets
-- macOS remember where you Cmd+drag it in the menu bar.)
toolkitMenu = hs.menubar.new(true, "toolkitMenu")
toolkitMenu:setTitle(menuIcon)
toolkitMenu:setTooltip("Hammerspoon toolkit: turn scripts on/off")
toolkitMenu:setMenu(buildMenu)
