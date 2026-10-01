-- ===========================================================
-- Unread counts for Slack & WhatsApp in the menu bar (top bar)
--
-- What it does:
--   * Every few seconds, checks the red badge on the Slack and
--     WhatsApp Dock icons (using macOS's built-in `lsappinfo`).
--   * If an app has unread messages, its icon appears in the menu
--     bar with the unread count next to it, e.g. [Slack icon] 3.
--   * Click the icon to open that app.
--   * The icons always stay in the menu bar; the count shows only
--     when there are unread messages. (Set `showWhenRead` to false
--     to hide an icon when there's nothing unread.)
--   * Counts only work while the app is open (it can be in the
--     background). If the app is quit, macOS has no badge to read.
--
-- What it does NOT do:
--   * It does not read your messages or connect to the internet.
--   * It only sees the badge number, nothing else.
-- ===========================================================


-- ---------- Settings you can change ----------
local config = {
  -- App names as shown in the Dock, plus bundle IDs used to find the
  -- icon when the app isn't running.
  apps = {
    { name = "Slack",    bundleIDs = { "com.tinyspeck.slackmacgap" } },
    { name = "WhatsApp", bundleIDs = { "net.whatsapp.WhatsApp", "desktop.WhatsApp" } },
  },
  checkEvery   = 3,     -- seconds between checks
  iconSize     = 18,    -- icon size in the menu bar (points)
  ignoreDots   = false, -- true = ignore Slack's "•" badge (activity
                        -- in channels without direct mentions)
  showWhenRead = true,  -- true = keep the icon in the menu bar even
                        -- when there are no unread messages
}


-- Keeps track of the menu bar items currently showing
local items = {} -- appName -> { menubar = ..., label = ..., hasIcon = ... }
local icons = {} -- appName -> icon image (cached)


-- ---------- Read an app's Dock badge ----------
-- Returns the badge text (e.g. "3" or "•"), or nil if there's no badge.
local function getBadge(appName)
  local output = hs.execute(
    '/usr/bin/lsappinfo info -only StatusLabel "' .. appName .. '"'
  )
  if not output then return nil end

  local label = output:match('"label"="([^"]*)"')
  if label == nil or label == "" then return nil end
  if config.ignoreDots and label == "•" then return nil end
  return label
end


-- ---------- Find an app's icon (nil if not found) ----------
local function getIcon(app)
  if icons[app.name] then return icons[app.name] end

  local ids = {}
  local running = hs.application.get(app.name)
  if running and running:bundleID() then table.insert(ids, running:bundleID()) end
  for _, id in ipairs(app.bundleIDs) do table.insert(ids, id) end

  for _, id in ipairs(ids) do
    local img = hs.image.imageFromAppBundle(id)
    if img then
      icons[app.name] = img:setSize({ w = config.iconSize, h = config.iconSize })
      return icons[app.name]
    end
  end
  return nil
end


-- ---------- Check badges and show/hide menu bar items ----------
local function update()
  for _, app in ipairs(config.apps) do
    local label = getBadge(app.name)
    local visible = label or config.showWhenRead
    local item = items[app.name]

    if visible and not item then
      -- Create the menu bar item: colored app icon, click opens the app
      local icon = getIcon(app)
      item = { menubar = hs.menubar.new(), label = false, hasIcon = icon ~= nil }
      if icon then item.menubar:setIcon(icon, false) end
      item.menubar:setClickCallback(function()
        hs.application.launchOrFocus(app.name)
      end)
      items[app.name] = item
    elseif not visible and item then
      -- Badge is gone: remove the item
      item.menubar:delete()
      items[app.name] = nil
      item = nil
    end

    -- Update the count text only when it changed
    if item and item.label ~= label then
      local text = label or ""
      if not item.hasIcon then
        -- No icon found: show the app name instead
        text = app.name .. (label and (" " .. label) or "")
      end
      item.menubar:setTitle(text)
      item.label = label
    end
  end
end


-- ---------- Start everything ----------
-- (Stored in a global so macOS doesn't clean it up.)
menubarUnreadTimer = hs.timer.doEvery(config.checkEvery, update)
update()
