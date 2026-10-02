-- ===========================================================
-- Floating unread buttons for Slack & WhatsApp (Hammerspoon)
--
-- What it does:
--   * Every few seconds, checks the red badge on the Slack and
--     WhatsApp Dock icons (using macOS's built-in `lsappinfo`).
--   * If an app has unread messages, a small floating button with
--     the app's icon and unread count appears in the bottom-right
--     corner of your screen, on top of other windows.
--   * Click the button to open that app.
--   * Drag the button to move it anywhere; the spot is remembered.
--     (To go back to the corner, run this in the Hammerspoon
--     Console: hs.settings.clear("unreadButtons.position") and
--     reload.)
--   * The button disappears once the badge is gone (messages read).
--
-- What it does NOT do:
--   * It does not read your messages or connect to the internet.
--   * It only sees the badge number, nothing else.
-- ===========================================================


-- ---------- Settings you can change ----------
local config = {
  apps       = { "Slack", "WhatsApp" }, -- app names as shown in the Dock
  checkEvery = 3,     -- seconds between checks
  size       = 56,    -- button size (points)
  margin     = 24,    -- distance from the screen edge
  gap        = 12,    -- space between buttons when both show
  ignoreDots = false, -- true = ignore Slack's "•" badge (activity
                      -- in channels without direct mentions)
  dragThreshold = 4,  -- pixels the mouse must move before a click
                      -- counts as a drag
}


-- Keeps track of the buttons currently on screen
local buttons = {} -- appName -> { canvas = ..., label = ... }

-- Where the user dragged the buttons to (top-left of the bottom
-- button), or nil to use the bottom-right corner. Saved across reloads.
local settingsKey = "unreadButtons.position"
local position = hs.settings.get(settingsKey)
local lastBase    -- where the bottom button was last placed
local drag        -- { moved = true/false } for the current mouse press
local dragTap     -- watches the mouse while dragging

local layout      -- defined below


-- ---------- Drag the buttons around ----------
local function startDrag()
  if dragTap then dragTap:stop() end
  local types = hs.eventtap.event.types
  local start = hs.mouse.absolutePosition()
  local origin = lastBase
  local current = { moved = false }
  drag = current

  dragTap = hs.eventtap.new({ types.leftMouseDragged, types.leftMouseUp },
    function(e)
      if e:getType() == types.leftMouseUp then
        dragTap:stop()
        if current.moved then hs.settings.set(settingsKey, position) end
        return false
      end

      local p = hs.mouse.absolutePosition()
      local dx, dy = p.x - start.x, p.y - start.y
      if not current.moved
          and math.abs(dx) + math.abs(dy) < config.dragThreshold then
        return false
      end
      current.moved = true
      position = { x = origin.x + dx, y = origin.y + dy }
      layout()
      return false
    end
  ):start()
end


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


-- ---------- Draw one floating button ----------
local function makeButton(appName, label)
  local s = config.size
  -- Canvas is slightly bigger than the button so the red badge
  -- can sit on the top-right corner.
  local c = hs.canvas.new({ x = 0, y = 0, w = s + 8, h = s + 8 })

  c:level(hs.canvas.windowLevels.floating)      -- stay above windows
  c:behavior({ "canJoinAllSpaces", "stationary" }) -- show on every desktop
  c:clickActivating(false)

  -- Dark rounded background
  c[1] = {
    type = "rectangle", action = "fill",
    fillColor = { white = 0.12, alpha = 0.9 },
    roundedRectRadii = { xRadius = 14, yRadius = 14 },
    frame = { x = 0, y = 8, w = s, h = s },
    withShadow = true,
  }

  -- App icon (falls back to the first letter of the app name)
  local app = hs.application.get(appName)
  local bundleID = app and app:bundleID()
  local icon = bundleID and hs.image.imageFromAppBundle(bundleID)

  if icon then
    c[2] = {
      type = "image", image = icon,
      frame = { x = 6, y = 14, w = s - 12, h = s - 12 },
    }
  else
    c[2] = {
      type = "text", text = appName:sub(1, 1),
      textSize = 26, textColor = { white = 1 },
      textAlignment = "center",
      frame = { x = 0, y = 8 + (s - 32) / 2, w = s, h = 32 },
    }
  end

  -- Red badge circle with the unread count
  c[3] = {
    type = "circle", action = "fill",
    fillColor = { red = 0.9, green = 0.2, blue = 0.2, alpha = 1 },
    center = { x = s - 6, y = 11 }, radius = 11,
  }
  c[4] = {
    type = "text", text = label,
    textSize = 12, textColor = { white = 1 },
    textAlignment = "center",
    frame = { x = s - 17, y = 3, w = 22, h = 16 },
  }

  -- Press starts a possible drag; a click without dragging opens the app
  c:canvasMouseEvents(true, true)
  c:mouseCallback(function(_, message)
    if message == "mouseDown" then
      startDrag()
    elseif message == "mouseUp" then
      if not (drag and drag.moved) then
        hs.application.launchOrFocus(appName)
      end
    end
  end)

  return c
end


-- ---------- Place buttons (saved spot, or bottom-right corner) ----------
-- True if the point is on any connected screen.
local function onSomeScreen(p)
  for _, scr in ipairs(hs.screen.allScreens()) do
    if hs.geometry.point(p.x, p.y):inside(scr:fullFrame()) then
      return true
    end
  end
  return false
end

function layout()
  local screen = hs.screen.mainScreen():frame()
  local index = 0

  -- Ignore a saved spot that's off-screen (e.g. monitor unplugged)
  local base = position
  if base and not onSomeScreen(base) then base = nil end

  for _, name in ipairs(config.apps) do
    local b = buttons[name]
    if b then
      local f = b.canvas:frame()
      if index == 0 then
        lastBase = base or {
          x = screen.x + screen.w - f.w - config.margin,
          y = screen.y + screen.h - config.margin - f.h,
        }
      end
      -- Extra buttons stack upward from the bottom one
      b.canvas:topLeft({
        x = lastBase.x,
        y = lastBase.y - index * (f.h + config.gap),
      })
      b.canvas:show()
      index = index + 1
    end
  end
end


-- ---------- Check badges and show/hide buttons ----------
local function update()
  for _, name in ipairs(config.apps) do
    local label = getBadge(name)
    local b = buttons[name]

    if label and (not b or b.label ~= label) then
      -- New unread messages, or the count changed: (re)draw button
      if b then b.canvas:delete() end
      buttons[name] = { canvas = makeButton(name, label), label = label }
    elseif not label and b then
      -- Badge is gone: remove the button
      b.canvas:delete()
      buttons[name] = nil
    end
  end
  layout()
end


-- ---------- Start everything ----------
-- (Stored in globals so macOS doesn't clean them up.)
unreadTimer = hs.timer.doEvery(config.checkEvery, update)
unreadScreenWatcher = hs.screen.watcher.new(layout):start()
update()
