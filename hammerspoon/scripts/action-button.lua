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

-- Colors (macOS dark style)
local colors = {
  accent    = { red = 0.04, green = 0.52, blue = 1.00, alpha = 1 },    -- center button
  branch    = { red = 0.11, green = 0.11, blue = 0.12, alpha = 0.94 }, -- branch buttons
  hover     = { red = 0.20, green = 0.20, blue = 0.22, alpha = 0.97 },
  on        = { red = 1.00, green = 0.27, blue = 0.23, alpha = 1 },    -- e.g. mic muted
  border    = { white = 1, alpha = 0.12 },
  glyph     = { white = 1, alpha = 0.95 },
  shadow    = { white = 0, alpha = 0.45 },
}


local settingsKey = "actionButton.position"
local position = hs.settings.get(settingsKey) -- top-left of the button

local types = hs.eventtap.event.types
local level = hs.canvas.windowLevels.floating
local font  = ".AppleSystemUIFont" -- the macOS system font
local pad   = 8 -- room around each circle for its shadow
local isOpen = false
local branches = {}  -- open branches: { canvas = ..., dx = ..., dy = ... }
local label          -- the hover label
local anim           -- { timer = ..., done = ... } while animating
local outsideTap     -- closes the flower on a click elsewhere
local drag, dragTap  -- for dragging the center button
local savedInputVolume


-- ---------- Icons ----------
-- Line icons drawn on a 24×24 grid (like most icon sets) and scaled
-- to fit, so they stay sharp and look the same on every Mac.
-- Arc angles: 0 = 12 o'clock, going clockwise.
local function iconElements(name, size, ox, oy)
  local k = size / 24
  local function P(x, y) return { x = ox + x * k, y = oy + y * k } end
  local function style(e)
    e.action = e.action or "stroke"
    e.strokeColor, e.fillColor = colors.glyph, colors.glyph
    e.strokeWidth = 2 * k
    e.strokeCapStyle, e.strokeJoinStyle = "round", "round"
    return e
  end
  local function line(...)
    local n, pts = { ... }, {}
    for i = 1, #n, 2 do table.insert(pts, P(n[i], n[i + 1])) end
    return style({ type = "segments", coordinates = pts })
  end
  local function box(x, y, w, h, r, action)
    return style({
      type = "rectangle", action = action,
      frame = { x = ox + x * k, y = oy + y * k, w = w * k, h = h * k },
      roundedRectRadii = { xRadius = r * k, yRadius = r * k },
    })
  end
  local function arc(cx, cy, r, from, to)
    return style({ type = "arc", center = P(cx, cy), radius = r * k,
                   startAngle = from, endAngle = to, arcRadii = false })
  end
  local function dot(cx, cy, r)
    return style({ type = "circle", action = "fill", center = P(cx, cy), radius = r * k })
  end

  local icons = {
    mic = function() return {
      box(9, 2, 6, 12, 3),
      line(5, 10, 5, 11), arc(12, 11, 7, 90, 270), line(19, 10, 19, 11),
      line(12, 18, 12, 22), line(8.5, 22, 15.5, 22),
    } end,
    micOff = function() return {
      box(9, 2, 6, 12, 3),
      line(5, 10, 5, 11), arc(12, 11, 7, 90, 270), line(19, 10, 19, 11),
      line(12, 18, 12, 22), line(8.5, 22, 15.5, 22),
      line(3, 3, 21, 21),
    } end,
    headphones = function() return {
      line(3, 18, 3, 12), arc(12, 12, 9, 270, 450), line(21, 12, 21, 18),
      box(2.5, 13.5, 5, 8, 2, "strokeAndFill"), box(16.5, 13.5, 5, 8, 2, "strokeAndFill"),
    } end,
    lock = function() return {
      box(4, 11, 16, 11, 2.5),
      line(8, 11, 8, 7), arc(12, 7, 4, 270, 450), line(16, 7, 16, 11),
      dot(12, 16.5, 1.4),
    } end,
    globe = function() return {
      style({ type = "circle", center = P(12, 12), radius = 10 * k }),
      style({ type = "oval", frame = { x = ox + 8 * k, y = oy + 2 * k, w = 8 * k, h = 20 * k } }),
      line(2, 12, 22, 12),
    } end,
  }
  return icons[name]()
end


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
  hs.alert.show(mute and "Microphone muted" or "Microphone on")
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
        hs.alert.show("Sound output: " .. d:name())
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
-- icon: a name from the Icons section (or a function returning one);
-- image: an app icon used instead when found; isOn: shows the button
-- red (e.g. mic muted); label: shown on hover
local actions = {
  mic = {
    icon  = function() return micMuted() and "micOff" or "mic" end,
    label = function() return micMuted() and "Unmute microphone" or "Mute microphone" end,
    isOn  = micMuted,
    run   = toggleMic,
  },
  audioOutput = {
    icon  = "headphones",
    label = "Sound output",
    run   = chooseOutput,
  },
  browser = {
    icon  = "globe",
    image = function() return hs.image.imageFromAppBundle(config.browserID) end,
    label = "New " .. config.browser .. " window",
    run   = newBrowserWindow,
  },
  lock = {
    icon  = "lock",
    label = "Lock screen",
    run   = function() hs.caffeinate.lockScreen() end,
  },
}

local function value(v) if type(v) == "function" then return v() end return v end


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

-- A round button with a soft shadow and a thin border, in a canvas
-- with `pad` room around it for the shadow
local function roundButton(c, diameter, fill)
  local mid = pad + diameter / 2
  c[1] = {
    type = "circle", action = "fill", fillColor = fill,
    center = { x = mid, y = mid }, radius = diameter / 2,
    withShadow = true,
    shadow = { blurRadius = 6, color = colors.shadow, offset = { h = -2, w = 0 } },
  }
  c[2] = {
    type = "circle", action = "stroke", strokeColor = colors.border, strokeWidth = 1,
    center = { x = mid, y = mid }, radius = diameter / 2 - 0.5,
  }
end


-- ---------- Center button ----------
local centerSide = config.size + 2 * pad
local center = newCanvas({ x = 0, y = 0, w = centerSide, h = centerSide })
roundButton(center, config.size, colors.accent)

-- The "+" is two lines, rotated toward "×" as the flower opens
local function drawPlus(degrees)
  local mid, len = centerSide / 2, config.size * 0.2
  local a = math.rad(degrees)
  local cos, sin = math.cos(a) * len, math.sin(a) * len
  for i, d in ipairs({ { cos, sin }, { -sin, cos } }) do
    center[2 + i] = {
      type = "segments", action = "stroke",
      strokeColor = { white = 1 }, strokeWidth = 2.5, strokeCapStyle = "round",
      coordinates = { { x = mid - d[1], y = mid - d[2] }, { x = mid + d[1], y = mid + d[2] } },
    }
  end
end
drawPlus(0)

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
  local size = hs.drawing.getTextDrawingSize(text, { font = font, size = 12 })
  local w, h = math.ceil(size.w) + 20, 24
  local f = canvas:frame()
  label = newCanvas({ x = f.x + f.w / 2 - w / 2, y = f.y + pad - h - 6, w = w, h = h })
  label[1] = {
    type = "rectangle", action = "fill", fillColor = colors.branch,
    roundedRectRadii = { xRadius = 7, yRadius = 7 },
  }
  label[2] = {
    type = "rectangle", action = "stroke", strokeColor = colors.border, strokeWidth = 1,
    frame = { x = 0.5, y = 0.5, w = w - 1, h = h - 1 },
    roundedRectRadii = { xRadius = 6.5, yRadius = 6.5 },
  }
  label[3] = {
    type = "text", text = text,
    textFont = font, textSize = 12, textColor = colors.glyph, textAlignment = "center",
    frame = { x = 0, y = (h - 15) / 2, w = w, h = 16 },
  }
  label:show()
end


-- ---------- Open / close animation ----------
-- Moves the branches between the center (0) and their spot (1),
-- and turns the "+" into a "×"
local function animate(list, opening, done)
  if anim then
    -- Finish the previous animation straight away
    anim.timer:stop()
    if anim.done then anim.done() end
  end
  local cp, half = centerPoint(), config.branchSize / 2 + pad
  local steps, k = 9, 0
  local current = { done = done }
  anim = current
  current.timer = hs.timer.doEvery(0.016, function()
    k = k + 1
    local t = k / steps
    local ease = 1 - (1 - t) ^ 3
    local p = opening and ease or (1 - ease)
    for _, b in ipairs(list) do
      b.canvas:topLeft({ x = cp.x + b.dx * p - half, y = cp.y + b.dy * p - half })
      b.canvas:alpha(p)
    end
    drawPlus(45 * p)
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
  local side = s + 2 * pad
  local c = newCanvas({ x = 0, y = 0, w = side, h = side })
  local fill = (action.isOn and action.isOn()) and colors.on or colors.branch
  roundButton(c, s, fill)

  local image = action.image and action.image()
  if image then
    local inset = s * 0.2
    c[3] = { type = "image", image = image,
             frame = { x = pad + inset, y = pad + inset, w = s - 2 * inset, h = s - 2 * inset } }
  else
    local g = s * 0.45 -- icon size
    for _, e in ipairs(iconElements(value(action.icon), g, pad + (s - g) / 2, pad + (s - g) / 2)) do
      c[#c + 1] = e
    end
  end

  c:canvasMouseEvents(true, true, true) -- down, up, enter/exit
  c:mouseCallback(function(_, message)
    if message == "mouseEnter" then
      if fill ~= colors.on then c[1].fillColor = colors.hover end
      showLabel(c, value(action.label))
    elseif message == "mouseExit" then
      c[1].fillColor = fill
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

  -- Fan out toward the middle of the screen the button is on
  local cp = centerPoint()
  local screen = (screenAt(cp) or hs.screen.primaryScreen()):fullFrame()
  local base = math.atan(screen.y + screen.h / 2 - cp.y, screen.x + screen.w / 2 - cp.x)
  local step = math.rad(config.spread)

  local ids = {}
  for _, id in ipairs(config.branches) do
    if actions[id] then table.insert(ids, id) end
  end
  local half = config.branchSize / 2 + pad
  for i, id in ipairs(ids) do
    local angle = base + (i - (#ids + 1) / 2) * step
    local c = makeBranch(actions[id])
    c:alpha(0)
    c:topLeft({ x = cp.x - half, y = cp.y - half })
    c:show()
    table.insert(branches, {
      canvas = c,
      dx = config.radius * math.cos(angle),
      dy = config.radius * math.sin(angle),
    })
  end
  center:orderAbove() -- keep the center on top while branches slide out
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
  if p and not screenAt({ x = p.x + centerSide / 2, y = p.y + centerSide / 2 }) then
    p = nil
  end
  if not p then
    local f = hs.screen.primaryScreen():frame()
    p = { x = f.x + f.w - centerSide - config.margin, y = f.y + f.h * 0.6 }
  end
  center:topLeft(p)
end


-- ---------- Start everything ----------
-- (Stored in globals so macOS doesn't clean them up.)
actionButton = center
actionButtonScreenWatcher = hs.screen.watcher.new(place):start()
place()
center:show()
