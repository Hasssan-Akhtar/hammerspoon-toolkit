-- ===========================================================
-- Caffeine: keep your Mac awake from the menu bar
--
-- What it does:
--   * Adds a menu bar icon: ☕ while your Mac is kept awake,
--     💤 when it's allowed to sleep as normal.
--   * Click it to keep the Mac awake for 15 minutes, 1 hour,
--     2 hours, or until you turn it off.
--   * Shows the time left next to the icon, e.g. "☕ 42m".
--   * Survives a Hammerspoon reload: if it was on, it comes back on
--     with the same end time.
--
-- What it does NOT do:
--   * It doesn't change your Energy/Battery settings. It only asks
--     macOS not to sleep while it's on, and everything goes back
--     to normal when it's turned off or Hammerspoon quits.
-- ===========================================================


-- ---------- Settings you can change ----------
local config = {
  keepDisplayOn = true, -- true = screen stays on too; false = only
                        -- the Mac stays awake (screen may turn off)
  durations     = { 15, 60, 120 }, -- menu choices, in minutes
  showTimeLeft  = true, -- show "42m" / "1h 30m" next to the icon
  iconOn        = "☕",
  iconOff       = "💤",
}


-- When to turn off: a time from os.time(), "forever", or nil (off).
-- Saved so a reload doesn't switch it off.
local settingsKey = "caffeine.until"
local untilTime = nil


-- ---------- Keep awake on/off ----------
local function applyAwake(on)
  -- "displayIdle" keeps the screen and Mac awake; "systemIdle" only
  -- keeps the Mac awake. Clear both so switching modes is clean.
  hs.caffeinate.set("displayIdle", on and config.keepDisplayOn)
  hs.caffeinate.set("systemIdle", on and not config.keepDisplayOn, true)
end

-- "42m", "1h 30m"
local function timeLeftText()
  if type(untilTime) ~= "number" then return nil end
  local mins = math.max(1, math.ceil((untilTime - os.time()) / 60))
  if mins < 60 then return mins .. "m" end
  local h, m = math.floor(mins / 60), mins % 60
  return m == 0 and (h .. "h") or (h .. "h " .. m .. "m")
end

local function durationText(mins)
  if mins < 60 then return mins .. " minutes" end
  local h = mins / 60
  return (h == math.floor(h)) and string.format("%d hour%s", h, h == 1 and "" or "s")
    or (mins .. " minutes")
end


-- ---------- Menu bar item ----------
-- The name lets macOS remember where you Cmd+drag it.
local item = hs.menubar.new(true, "caffeine")

local function updateTitle()
  if not untilTime then
    item:setTitle(config.iconOff)
    item:setTooltip("Caffeine: off (Mac sleeps as normal)")
    return
  end
  local left = config.showTimeLeft and timeLeftText()
  item:setTitle(left and (config.iconOn .. " " .. left) or config.iconOn)
  item:setTooltip("Caffeine: keeping your Mac awake")
end

-- minutes = number, or nil for "until turned off"
local function turnOn(minutes)
  untilTime = minutes and (os.time() + minutes * 60) or "forever"
  hs.settings.set(settingsKey, untilTime)
  applyAwake(true)
  updateTitle()
end

local function turnOff()
  untilTime = nil
  hs.settings.clear(settingsKey)
  applyAwake(false)
  updateTitle()
end

-- Built fresh each time the menu opens, so it's always current
item:setMenu(function()
  local status
  if untilTime == "forever" then
    status = "Keeping awake until turned off"
  elseif untilTime then
    status = "Keeping awake until " .. os.date("%l:%M %p", untilTime):gsub("^%s+", "")
      .. " (" .. timeLeftText() .. " left)"
  else
    status = "Off: Mac sleeps as normal"
  end

  local items = {
    { title = status, disabled = true },
    { title = "-" },
  }
  for _, mins in ipairs(config.durations) do
    table.insert(items, { title = "Keep awake for " .. durationText(mins), fn = function() turnOn(mins) end })
  end
  table.insert(items, {
    title = "Keep awake until turned off",
    checked = untilTime == "forever",
    fn = function() turnOn(nil) end,
  })
  table.insert(items, { title = "-" })
  table.insert(items, { title = "Turn off", disabled = not untilTime, fn = turnOff })
  return items
end)


-- ---------- Start everything ----------
-- Every 30 seconds: refresh the time left, and turn off when it's up.
-- (Stored in globals so macOS doesn't clean them up.)
caffeineItem = item
caffeineTimer = hs.timer.doEvery(30, function()
  if type(untilTime) == "number" and os.time() >= untilTime then
    turnOff()
    hs.alert.show(config.iconOff .. " Caffeine off: your Mac can sleep again")
  else
    updateTitle()
  end
end)

-- Pick up where we left off before a reload
local saved = hs.settings.get(settingsKey)
if saved == "forever" or (type(saved) == "number" and saved > os.time()) then
  untilTime = saved
  applyAwake(true)
else
  hs.settings.clear(settingsKey)
  applyAwake(false)
end
updateTitle()
