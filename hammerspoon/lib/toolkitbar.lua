-- ===========================================================
-- toolkitbar: menu bar items that fold into the 🧰 menu on small
-- screens
--
-- Scripts create their menu bar items with toolkitbar.new() instead
-- of hs.menubar.new(). On wide screens each item is a normal menu
-- bar icon. When any connected screen is narrower than
-- `compactBelowWidth`, macOS would start hiding icons that don't
-- fit (it can't tell apps which ones it hid), so the items leave
-- the menu bar and show up as rows in the 🧰 menu instead. It
-- switches by itself when displays are plugged in or unplugged.
-- ===========================================================

local M = {}

local compactBelowWidth = 1600
local compact = false
local items = {}      -- every live item, in creation order
local onChange = nil  -- called when the 🧰 title should be redrawn

local function changed() if onChange then onChange() end end


-- ---------- One menu bar item ----------
-- Same methods as hs.menubar (the ones the scripts use), plus
-- setCompactTitle and setBadge for how it looks inside the 🧰 menu.
local Item = {}
Item.__index = Item

-- Add or remove the real menu bar icon to match the current mode
function Item:render()
  if compact then
    if self.real then self.real:delete(); self.real = nil end
    return
  end
  if self.real then return end
  -- The autosave name lets macOS remember where you Cmd+drag it
  -- (hs.menubar.new rejects a nil name, so only pass one if given)
  if self.autosave then
    self.real = hs.menubar.new(true, self.autosave)
  else
    self.real = hs.menubar.new(true)
  end
  if not self.real then return end
  if self.icon then self.real:setIcon(self.icon, self.iconTemplate) end
  if self.title then self.real:setTitle(self.title) end
  if self.tooltip then self.real:setTooltip(self.tooltip) end
  if self.menu then self.real:setMenu(self.menu) end
  if self.click then self.real:setClickCallback(self.click) end
end

function Item:setTitle(text)
  self.title = text
  if self.real then self.real:setTitle(text) end
  return self
end

function Item:setIcon(image, template)
  self.icon, self.iconTemplate = image, template
  if self.real then self.real:setIcon(image, template) end
  return self
end

function Item:setTooltip(text)
  self.tooltip = text
  if self.real then self.real:setTooltip(text) end
  return self
end

-- A table of menu items, or a function that builds them on open
function Item:setMenu(menu)
  self.menu = menu
  if self.real then self.real:setMenu(menu) end
  return self
end

function Item:setClickCallback(fn)
  self.click = fn
  if self.real then self.real:setClickCallback(fn) end
  return self
end

-- Text for this item's row in the 🧰 menu (defaults to the title)
function Item:setCompactTitle(text)
  self.compactTitle = text
  return self
end

-- Short text added to the 🧰 icon in compact mode, so you still see
-- it at a glance: numbers are added up ("3" + "2" = "5"), anything
-- else ("☕", "•") is shown as is. nil = nothing.
function Item:setBadge(text)
  if self.badge ~= text then
    self.badge = text
    changed()
  end
  return self
end

function Item:delete()
  if self.real then self.real:delete(); self.real = nil end
  for i, it in ipairs(items) do
    if it == self then table.remove(items, i); break end
  end
  if self.badge then changed() end
end


-- ---------- Used by the scripts ----------
-- autosaveName: optional, so a Cmd+dragged position is remembered
function M.new(autosaveName)
  local item = setmetatable({ autosave = autosaveName }, Item)
  table.insert(items, item)
  item:render()
  return item
end


-- ---------- Used by init.lua for the 🧰 menu ----------
function M.isCompact() return compact end
function M.compactBelowWidth() return compactBelowWidth end
function M.onChange(fn) onChange = fn end

-- Rows for the 🧰 menu: one per item, with its icon, click action
-- and menu (as a submenu)
function M.compactRows()
  local rows = {}
  for _, it in ipairs(items) do
    local menu = it.menu
    if type(menu) == "function" then menu = menu() end
    table.insert(rows, {
      title = it.compactTitle or it.title or "",
      image = it.icon,
      fn = it.click and function() it.click() end,
      menu = menu,
    })
  end
  return rows
end

-- e.g. "5 ☕": unread counts added up, then other badges
function M.badgeText()
  local total, others, seen = 0, {}, {}
  for _, it in ipairs(items) do
    local b = it.badge
    if b then
      if tonumber(b) then
        total = total + tonumber(b)
      elseif not seen[b] then
        seen[b] = true
        table.insert(others, b)
      end
    end
  end
  if total > 0 then table.insert(others, 1, tostring(total)) end
  return table.concat(others, " ")
end


-- ---------- Switch modes when the screens change ----------
local function narrowestScreenWidth()
  local w = math.huge
  for _, s in ipairs(hs.screen.allScreens()) do
    w = math.min(w, s:fullFrame().w)
  end
  return w
end

local function update()
  local now = narrowestScreenWidth() < compactBelowWidth
  if now == compact then return end
  compact = now
  for _, it in ipairs(items) do it:render() end
  changed()
end

function M.setup(opts)
  compactBelowWidth = opts.compactBelowWidth or compactBelowWidth
  compact = narrowestScreenWidth() < compactBelowWidth
  -- (Stored in a global so macOS doesn't clean it up.)
  toolkitbarScreenWatcher = hs.screen.watcher.new(update):start()
end

return M
