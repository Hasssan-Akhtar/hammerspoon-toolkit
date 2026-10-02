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
--
-- On small screens, the scripts' menu bar icons fold into the 🧰
-- menu so macOS doesn't hide them (see lib/toolkitbar.lua).
-- ===========================================================


-- ---------- Scripts and their defaults ----------
local scripts = {
  { name = "menubar-unread",          title = "Unread counts in menu bar", default = true },
  { name = "menubar-clock",           title = "Second clock",              default = true },
  { name = "clipboard-history",       title = "Clipboard history (⌃⌘V)",   default = true },
  { name = "caffeine",                title = "Keep Mac awake (caffeine)", default = false },
  { name = "action-button",           title = "Floating action button",    default = false },
  { name = "floating-unread-buttons", title = "Floating unread buttons",   default = false },
}

local menuIcon = "🧰" -- text shown in the menu bar for the settings menu

-- When any connected screen is narrower than this (in points), all
-- the toolkit's menu bar icons fold into the 🧰 menu. A 14" MacBook
-- screen is about 1512 wide. Set to 0 to never fold them.
local compactBelowWidth = 1600


-- ~/.hammerspoon/init.lua is a symlink into the repo, so follow it
-- to find the repo's scripts/ and lib/ folders.
local here = hs.fs.pathToAbsolute(hs.configdir .. "/init.lua"):match("(.*)/")
local scriptsDir = here .. "/scripts"
package.path = scriptsDir .. "/?.lua;" .. here .. "/lib/?.lua;" .. package.path

local toolkitbar = require("toolkitbar")
toolkitbar.setup({ compactBelowWidth = compactBelowWidth })

-- Created before the scripts' icons so it sits to their right, where
-- macOS hides it last. (Stored in a global so macOS doesn't clean it
-- up. The name lets macOS remember where you Cmd+drag it.)
toolkitMenu = hs.menubar.new(true, "toolkitMenu")
toolkitMenu:setTitle(menuIcon)


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
local function scriptItems()
  local items = {}
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
  return items
end

local function buildMenu()
  local items = {}

  if toolkitbar.isCompact() then
    -- Small screen: the scripts' icons live here instead
    for _, row in ipairs(toolkitbar.compactRows()) do table.insert(items, row) end
    table.insert(items, { title = "-" })
    table.insert(items, { title = "Scripts", menu = scriptItems() })
    table.insert(items, {
      title = "Compact menu bar: a screen is under " .. compactBelowWidth .. " pt wide",
      disabled = true,
    })
  else
    table.insert(items, { title = "Scripts", disabled = true })
    for _, item in ipairs(scriptItems()) do table.insert(items, item) end
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

-- In compact mode, show unread counts etc. next to the icon
local function updateTitle()
  local badge = toolkitbar.isCompact() and toolkitbar.badgeText() or ""
  toolkitMenu:setTitle(badge ~= "" and (menuIcon .. " " .. badge) or menuIcon)
end

toolkitMenu:setTooltip("Hammerspoon toolkit")
toolkitMenu:setMenu(buildMenu)
toolkitbar.onChange(updateTitle)
updateTitle()
