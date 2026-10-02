-- ===========================================================
-- Second clock in the menu bar (New York time)
--
-- What it does:
--   * Shows the date and time in another city in the menu bar, e.g.
--     "NY Thu Oct 1  7:03 PM", updated at the start of every minute.
--   * Click it to see the full date, time zone, and how many hours
--     ahead/behind it is compared to your Mac's time.
--   * Daylight saving is handled automatically by macOS.
--   * Cmd+drag it to move it; the position is remembered.
-- ===========================================================


-- ---------- Settings you can change ----------
local config = {
  label    = "NY",               -- text before the time
  timezone = "America/New_York", -- any name from /usr/share/zoneinfo
  hour24   = false,              -- true = "19:03", false = "7:03 PM"
  showDate = true,               -- true = "NY Thu Oct 1  7:03 PM",
                                 -- like the Mac's own clock
}


-- ---------- Read the time in that time zone ----------
-- Lua can only show local time, so ask macOS's `date` command.
-- Returns time, full date, zone name (e.g. "EDT"), UTC offset ("-0400"),
-- short date ("Thu Oct 1")
local function readTime()
  local timeFormat = config.hour24 and "%H:%M" or "%l:%M %p"
  local output = hs.execute(
    "TZ='" .. config.timezone .. "' /bin/date '+"
      .. timeFormat .. "|%a, %b %e|%Z|%z|%a %b %e'"
  )
  if not output then return nil end
  local time, date, zone, offset, short =
    output:match("^%s*(.-)|(.-)|(.-)|(.-)|(.-)%s*$")
  if not time then return nil end
  -- %e pads single-digit days with a space ("Oct  1"); tidy that up
  date = date:gsub("%s+", " ")
  short = short:gsub("%s+", " ")
  return time, date, zone, offset, short
end

-- "+0530" -> 5.5 hours
local function offsetHours(offset)
  local sign, h, m = offset:match("([+-])(%d%d)(%d%d)")
  if not sign then return 0 end
  local hours = tonumber(h) + tonumber(m) / 60
  return sign == "-" and -hours or hours
end

-- e.g. "3 hours ahead of you", "same time as you"
local function differenceText(offset)
  local diff = offsetHours(offset) - offsetHours(os.date("%z"))
  if diff == 0 then return "Same time as you" end
  local n = math.abs(diff)
  local amount = (n == math.floor(n)) and string.format("%d", n) or string.format("%.1f", n)
  return amount .. (n == 1 and " hour " or " hours ")
    .. (diff > 0 and "ahead of you" or "behind you")
end


-- ---------- Menu bar item ----------
-- macOS doesn't let apps pick their menu bar position. Hold Cmd and
-- drag the clock where you want it (as far right as macOS allows is
-- just left of Apple's own icons); the name below makes macOS
-- remember that spot across reloads.
local item = hs.menubar.new(true, "menubarClock")

local function update()
  local time, _, _, _, short = readTime()
  if not time then return end
  if config.showDate then
    item:setTitle(config.label .. " " .. short .. "  " .. time)
  else
    item:setTitle(config.label .. " " .. time)
  end
end

-- Built fresh each time the menu opens, so it's always current
item:setMenu(function()
  local time, date, zone, offset = readTime()
  if not time then return { { title = "Couldn't read the time", disabled = true } } end
  return {
    { title = config.label .. ": " .. time .. " " .. zone, disabled = true },
    { title = date, disabled = true },
    { title = "-" },
    { title = differenceText(offset), disabled = true },
  }
end)


-- ---------- Start everything ----------
-- Update now, then exactly at the start of every minute.
-- (Stored in globals so macOS doesn't clean them up.)
menubarClockItem = item
update()
menubarClockStart = hs.timer.doAfter(60 - os.date("*t").sec, function()
  update()
  menubarClockTimer = hs.timer.doEvery(60, update)
end)
