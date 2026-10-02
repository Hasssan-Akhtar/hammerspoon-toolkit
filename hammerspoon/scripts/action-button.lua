-- ===========================================================
-- Action button: a floating button that opens like a flower
--
-- What it does:
--   * Shows a round floating button on top of your windows.
--   * Click it and smaller buttons (branches) fan out around it.
--     Click a branch to run it; click the center or anywhere else
--     to close.
--   * Branches (pick and order them in `branches` below):
--       mic          mute/unmute your microphone (red when muted)
--       audioOutput  choose where sound plays (headphones, speakers…)
--       browser      open a new Google Chrome window
--       lock         lock the screen
--   * Hover a branch to see what it does.
--   * Drag the button to move it; the spot is remembered. Branches
--     always open toward the middle of the screen so they stay
--     visible.
-- ===========================================================


-- ---------- Settings you can change ----------
local config = {
  branches      = { "mic", "audioOutput", "browser", "lock" },
  browser       = "Google Chrome",     -- app name for the browser branch
  browserID     = "com.google.Chrome", -- its bundle ID (for the icon)
  size          = 52,   -- center button size (points)
  branchSize    = 44,   -- branch button size
  radius        = 80,   -- distance from center to each branch
  spread        = 50,   -- degrees between neighbouring branches
  margin        = 24,   -- distance from the screen edge (default spot)
  dragThreshold = 4,    -- pixels the mouse must move before a click
                        -- counts as a drag
}


local settingsKey = "actionButton.position"
local position = hs.settings.get(settingsKey) -- top-left of the button

local types = hs.eventtap.event.types
local level = hs.canvas.windowLevels.floating
local isOpen = false
local branches = {}  -- open branches: { canvas = ..., dx = ..., dy = ... }
local label          -- the hover label
local anim           -- { timer = ..., done = ... } while animating
local outsideTap     -- closes the flower on a click elsewhere
local drag, dragTap  -- for dragging the center button
local savedInputVolume


-- ---------- Branch: microphone ----------
local function micMuted()
  local d = hs.audiodevice.defaultInputDevice()
  if not d then return false end
  return d:inputMuted() or d:inputVolume() == 0
end

local function toggleMic()
  local d = hs.audiodevice.defaultInputDevice()
  if not d then hs.alert.show("No microphone found"); return end
  local mute = not micMuted()
  if mute then
    -- Some mics can't be muted; turn their volume down instead
    if not d:setInputMuted(true) then
      savedInputVolume = d:inputVolume()
      d:setInputVolume(0)
    end
  else
    d:setInputMuted(false)
    if d:inputVolume() == 0 then d:setInputVolume(savedInputVolume or 75) end
  end
  hs.alert.show(mute and "🎙 Mic muted" or "🎙 Mic on")
end


-- ---------- Branch: sound output ----------
-- A small menu of output devices, opened where the branch was
local function chooseOutput(point)
  local current = hs.audiodevice.defaultOutputDevice()
  local items = {}
  for _, d in ipairs(hs.audiodevice.allOutputDevices()) do
    table.insert(items, {
      title = d:name(),
      checked = current ~= nil and d:uid() == current:uid(),
      fn = function()
        d:setDefaultOutputDevice()
        hs.alert.show("🎧 " .. d:name())
      end,
    })
  end
  -- (Stored in a global so macOS doesn't clean it up.)
  actionButtonPopup = actionButtonPopup or hs.menubar.new(false)
  actionButtonPopup:setMenu(items)
  actionButtonPopup:popupMenu(point)
end


-- ---------- Branch: browser ----------
local function newBrowserWindow()
  -- `open -na` asks the browser for a new window without needing
  -- extra macOS permissions
  local _, ok = hs.execute('/usr/bin/open -na "' .. config.browser .. '" --args --new-window')
  if not ok then hs.alert.show("Couldn't open " .. config.browser) end
end


-- ---------- All branches ----------
-- text: emoji shown on the button; image: used instead when found;
-- isOn: shows the button red with a slash (e.g. mic muted)
local actions = {
  mic = {
    text  = "🎙",
    label = function() return micMuted() and "Unmute microphone" or "Mute microphone" end,
    isOn  = micMuted,
    run   = toggleMic,
  },
  audioOutput = {
    text  = "🎧",
    label = "Sound output",
    run   = chooseOutput,
  },
  browser = {
    text  = "🌐",
    image = function() return hs.image.imageFromAppBundle(config.browserID) end,
    label = "New " .. config.browser .. " window",
    run   = newBrowserWindow,
  },
  lock = {
    text  = "🔒",
    label = "Lock screen",
    run   = function() hs.caffeinate.lockScreen() end,
  },
}


-- ---------- Small helpers ----------
local function inside(frame, p)
  return p.x >= frame.x and p.x <= frame.x + frame.w
     and p.y >= frame.y and p.y <= frame.y + frame.h
end

local function screenAt(p)
  for _, s in ipairs(hs.screen.allScreens()) do
    if inside(s:fullFrame(), p) then return s end
  end
  return nil
end

local function newCanvas(frame)
  local c = hs.canvas.new(frame)
  c:level(level)                                   -- stay above windows
  c:behavior({ "canJoinAllSpaces", "stationary" }) -- show on every desktop
  c:clickActivating(false)
  return c
end


-- ---------- Center button ----------
local center = newCanvas({ x = 0, y = 0, w = config.size, h = config.size })
center[1] = {
  type = "circle", action = "fill",
  fillColor = { red = 0.25, green = 0.45, blue = 0.95, alpha = 0.95 },
  center = { x = config.size / 2, y = config.size / 2 },
  radius = config.size / 2 - 2,
  withShadow = true,
}
center[2] = {
  type = "text", text = "+",
  textSize = 30, textColor = { white = 1 }, textAlignment = "center",
  frame = { x = 0, y = (config.size - 38) / 2, w = config.size, h = 38 },
}

local function centerPoint()
  local f = center:frame()
  return { x = f.x + f.w / 2, y = f.y + f.h / 2 }
end


-- ---------- Hover label ----------
local function hideLabel()
  if label then label:delete(); label = nil end
end

local function showLabel(canvas, text)
  hideLabel()
  local size = hs.drawing.getTextDrawingSize(text, { size = 12 })
  local w, h = math.ceil(size.w) + 16, 22
  local f = canvas:frame()
  label = newCanvas({ x = f.x + f.w / 2 - w / 2, y = f.y - h - 4, w = w, h = h })
  label[1] = {
    type = "rectangle", action = "fill",
    fillColor = { white = 0.1, alpha = 0.9 },
    roundedRectRadii = { xRadius = 6, yRadius = 6 },
  }
  label[2] = {
    type = "text", text = text,
    textSize = 12, textColor = { white = 1 }, textAlignment = "center",
    frame = { x = 0, y = (h - 16) / 2, w = w, h = 16 },
  }
  label:show()
end


-- ---------- Open / close animation ----------
-- Moves the branches between the center (0) and their spot (1)
local function animate(list, opening, done)
  if anim then
    -- Finish the previous animation straight away
    anim.timer:stop()
    if anim.done then anim.done() end
  end
  local cp, half = centerPoint(), config.branchSize / 2
  local steps, k = 7, 0
  local current = { done = done }
  anim = current
  current.timer = hs.timer.doEvery(0.016, function()
    k = k + 1
    local t = k / steps
    local ease = 1 - (1 - t) ^ 2
    local p = opening and ease or (1 - ease)
    for _, b in ipairs(list) do
      b.canvas:topLeft({ x = cp.x + b.dx * p - half, y = cp.y + b.dy * p - half })
      b.canvas:alpha(p)
    end
    if k >= steps then
      current.timer:stop()
      if anim == current then anim = nil end
      if done then done() end
    end
  end)
end


-- ---------- Branch buttons ----------
local closeFlower

local function makeBranch(action)
  local s = config.branchSize
  local c = newCanvas({ x = 0, y = 0, w = s, h = s })
  local on = action.isOn and action.isOn()

  c[1] = {
    type = "circle", action = "fill",
    fillColor = on and { red = 0.85, green = 0.2, blue = 0.2, alpha = 0.95 }
                    or { white = 0.15, alpha = 0.92 },
    center = { x = s / 2, y = s / 2 }, radius = s / 2 - 2,
    withShadow = true,
  }
  local image = action.image and action.image()
  if image then
    c[2] = { type = "image", image = image, frame = { x = 8, y = 8, w = s - 16, h = s - 16 } }
  else
    c[2] = {
      type = "text", text = action.text,
      textSize = 20, textAlignment = "center",
      frame = { x = 0, y = (s - 26) / 2, w = s, h = 26 },
    }
  end
  if on then
    -- Slash across the icon, e.g. mic muted
    c[3] = {
      type = "segments", action = "stroke",
      strokeColor = { white = 1 }, strokeWidth = 2.5,
      coordinates = { { x = 12, y = 12 }, { x = s - 12, y = s - 12 } },
    }
  end

  c:canvasMouseEvents(true, true, true) -- down, up, enter/exit
  c:mouseCallback(function(_, message)
    if message == "mouseEnter" then
      showLabel(c, type(action.label) == "function" and action.label() or action.label)
    elseif message == "mouseExit" then
      hideLabel()
    elseif message == "mouseUp" then
      local f = c:frame()
      closeFlower()
      action.run({ x = f.x + f.w / 2, y = f.y + f.h / 2 })
    end
  end)
  return c
end


-- ---------- Open / close the flower ----------
local function openFlower()
  isOpen = true
  center[2].text = "×"

  -- Fan out toward the middle of the screen the button is on
  local cp = centerPoint()
  local screen = (screenAt(cp) or hs.screen.primaryScreen()):fullFrame()
  local base = math.atan(screen.y + screen.h / 2 - cp.y, screen.x + screen.w / 2 - cp.x)
  local step = math.rad(config.spread)

  local ids = {}
  for _, id in ipairs(config.branches) do
    if actions[id] then table.insert(ids, id) end
  end
  for i, id in ipairs(ids) do
    local angle = base + (i - (#ids + 1) / 2) * step
    local c = makeBranch(actions[id])
    c:alpha(0)
    c:topLeft({ x = cp.x - config.branchSize / 2, y = cp.y - config.branchSize / 2 })
    c:show()
    table.insert(branches, {
      canvas = c,
      dx = config.radius * math.cos(angle),
      dy = config.radius * math.sin(angle),
    })
  end
  animate(branches, true)

  -- A click anywhere else closes the flower
  outsideTap = hs.eventtap.new({ types.leftMouseDown, types.rightMouseDown }, function()
    local p = hs.mouse.absolutePosition()
    if inside(center:frame(), p) then return false end
    for _, b in ipairs(branches) do
      if inside(b.canvas:frame(), p) then return false end
    end
    closeFlower()
    return false
  end):start()
end

function closeFlower()
  if not isOpen then return end
  isOpen = false
  center[2].text = "+"
  if outsideTap then outsideTap:stop(); outsideTap = nil end
  hideLabel()
  local closing = branches
  branches = {}
  animate(closing, false, function()
    for _, b in ipairs(closing) do b.canvas:delete() end
  end)
end


-- ---------- Drag the center button around ----------
local function startDrag()
  if dragTap then dragTap:stop() end
  local start = hs.mouse.absolutePosition()
  local origin = center:topLeft()
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
      if not current.moved then closeFlower() end
      current.moved = true
      position = { x = origin.x + dx, y = origin.y + dy }
      center:topLeft(position)
      return false
    end
  ):start()
end

-- Press starts a possible drag; a click without dragging opens/closes
center:canvasMouseEvents(true, true)
center:mouseCallback(function(_, message)
  if message == "mouseDown" then
    startDrag()
  elseif message == "mouseUp" then
    if not (drag and drag.moved) then
      if isOpen then closeFlower() else openFlower() end
    end
  end
end)


-- ---------- Place the button (saved spot, or right edge) ----------
local function place()
  closeFlower()
  local p = position
  -- Ignore a saved spot that's off-screen (e.g. monitor unplugged)
  if p and not screenAt({ x = p.x + config.size / 2, y = p.y + config.size / 2 }) then
    p = nil
  end
  if not p then
    local f = hs.screen.primaryScreen():frame()
    p = { x = f.x + f.w - config.size - config.margin, y = f.y + f.h * 0.6 }
  end
  center:topLeft(p)
end


-- ---------- Start everything ----------
-- (Stored in globals so macOS doesn't clean them up.)
actionButton = center
actionButtonScreenWatcher = hs.screen.watcher.new(place):start()
place()
center:show()
