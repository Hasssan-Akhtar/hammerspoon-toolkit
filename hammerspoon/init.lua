-- ===========================================================
-- Hammerspoon entry point
--
-- Each feature lives in its own file in the scripts/ folder.
-- To add one: create scripts/<name>.lua and add "<name>" to the
-- list below. To turn one off, comment out its line.
-- ===========================================================


-- ---------- Scripts to load ----------
local scripts = {
  -- "floating-unread-buttons", -- Slack/WhatsApp floating unread buttons
  "menubar-unread",             -- Slack/WhatsApp unread counts in the menu bar
  "menubar-clock",              -- New York time in the menu bar
  "clipboard-history",          -- ⌃⌘V: search & paste recent copies
}


-- ~/.hammerspoon/init.lua is a symlink into the repo, so follow it
-- to find the repo's scripts/ folder.
local here = hs.fs.pathToAbsolute(hs.configdir .. "/init.lua"):match("(.*)/")
package.path = here .. "/scripts/?.lua;" .. package.path

-- Load each script on its own, so one broken script doesn't stop
-- the others. Errors show in an alert and in the Hammerspoon Console.
for _, name in ipairs(scripts) do
  local ok, err = pcall(require, name)
  if not ok then
    print("Failed to load " .. name .. ": " .. tostring(err))
    hs.alert.show("Failed to load " .. name .. " (see Console)")
  end
end