local ADDON, JH = ...
_G.FaithHeals = JH

JH.buttons = {}      -- unit frames created by the group header

---------------------------------------------------------------------------
-- Bindings
--
-- A binding is { key = "ALT-BUTTON2", action = "spell", spell = "Rejuvenation",
--                id = 774 (only for a fixed rank), rank = 2 (only for a fixed rank) }
--
-- key: modifiers in the order ALT- CTRL- SHIFT-, then the input:
--   BUTTON1..BUTTON5          a mouse click on a bar
--   anything else             a key (or the wheel) pressed while the mouse is over a bar,
--                             e.g. "1" from an MMO mouse thumb button, "MOUSEWHEELUP"
-- action: "spell", "target", "focus", "assist", "menu", "trade"
-- A spell without id casts your highest rank.
---------------------------------------------------------------------------
JH.ACTIONS = {
  { id = "target", label = "Target" },
  { id = "focus",  label = "Set focus" },
  { id = "assist", label = "Assist" },
  { id = "menu",   label = "Unit menu" },
  { id = "trade",  label = "Trade" },
}
local ACTION_LABEL = {}
for _, a in ipairs(JH.ACTIONS) do ACTION_LABEL[a.id] = a.label end

local function B(key, action, spell) return { key = key, action = action, spell = spell } end

-- Default restoration druid setup.
JH.defaults = {
  version = 6,
  scale  = 1,
  theme  = "healbot",
  -- bar size and number of columns for each group size (see JH.LAYOUTS in Frames.lua)
  sizes  = {
    solo   = { w = 120, h = 40, cols = 1 },
    party  = { w = 120, h = 40, cols = 1 },
    raid10 = { w = 96,  h = 36, cols = 2 },
    raid20 = { w = 84,  h = 34, cols = 4 },
    raid25 = { w = 76,  h = 32, cols = 5 },
    raid40 = { w = 68,  h = 28, cols = 8 },
  },
  -- how the bars look (a theme is just a preset of these)
  look   = { bar = "health", name = "white", tex = "blizzard", pct = false, hots = true, inc = true,
             -- Bars & text tab (fontSize 0 = automatic, nameLen 0 = whole name)
             font = "game", fontSize = 0, outline = "OUTLINE", nameLen = 0, nameAlign = "center",
             bg = "auto", fill = "h", marker = true,
             -- icon size per kind (0.5 - 2 = 50% - 200%)
             hotSize = 1, buffSize = 1, debuffSize = 1,
             -- text colours (name: white/class/yellow/grey/black, pctColor: white/name/health/yellow)
             pctColor = "white", shadow = true,
             -- icons on the bars, one toggle each (on every bar in the group, yours too):
             -- hots / showBuffs / showDebuffs, how many (1-4), debuffs = "all" or "dispel"
             hotMax = 4, showBuffs = false, buffMax = 3,
             showDebuffs = false, debuffs = "all", debuffMax = 3, dispel = true },
  -- how the bars are arranged
  layout = { grow = "down", sort = "group", spacing = 2, solo = true, player = true },
  rangeAlpha = 0.4,
  pos    = { "TOPLEFT", "TOPLEFT", 40, -260 },
  locked = true,
  offFrameTarget = false,
  bindings = {
    B("BUTTON1", "target"),
    B("BUTTON2", "spell", "Rejuvenation"),
    B("BUTTON3", "spell", "Cenarion Ward"),
    B("SHIFT-BUTTON1", "spell", "Regrowth"),
    B("SHIFT-BUTTON2", "spell", "Wild Growth"),
    B("SHIFT-BUTTON3", "spell", "Rebirth"),
    B("CTRL-BUTTON1", "spell", "Lifebloom"),
    B("CTRL-BUTTON2", "spell", "Swiftmend"),
    B("CTRL-BUTTON3", "menu"),
    B("ALT-BUTTON1", "spell", "Nature's Cure"),
    B("ALT-BUTTON2", "spell", "Ironbark"),
    -- most 12-button MMO mice send 1 2 3 ... 0 - = from the thumb buttons
    B("1", "spell", "Rejuvenation"),
    B("2", "spell", "Regrowth"),
    B("3", "spell", "Wild Growth"),
    B("4", "spell", "Lifebloom"),
    B("5", "spell", "Swiftmend"),
    B("6", "spell", "Nature's Cure"),
    B("7", "spell", "Cenarion Ward"),
    B("8", "spell", "Ironbark"),
    B("9", "spell", "Rebirth"),
  },
}

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = deepcopy(v) end
  return c
end
JH.deepcopy = deepcopy

function JH.Print(msg)
  print("|cff33ff99FaithHeals|r: " .. tostring(msg))
end

---------------------------------------------------------------------------
-- Keys
---------------------------------------------------------------------------
-- "ALT-CTRL-SHIFT-X" -> alt, ctrl, shift, "X"
function JH.ParseKey(key)
  local alt, ctrl, shift = false, false, false
  local rest = key or ""
  while true do
    local m, r = rest:match("^(%u+)%-(.+)$")
    if m == "ALT" then alt, rest = true, r
    elseif m == "CTRL" then ctrl, rest = true, r
    elseif m == "SHIFT" then shift, rest = true, r
    else break end
  end
  return alt, ctrl, shift, rest
end

function JH.MakeKey(alt, ctrl, shift, input)
  return (alt and "ALT-" or "") .. (ctrl and "CTRL-" or "") .. (shift and "SHIFT-" or "") .. input
end

-- Secure-attribute prefix for the modifiers: "alt-ctrl-shift-"
local function AttrPrefix(alt, ctrl, shift)
  return (alt and "alt-" or "") .. (ctrl and "ctrl-" or "") .. (shift and "shift-" or "")
end

function JH.MouseButtonOf(input)
  return tonumber((input or ""):match("^BUTTON([1-5])$"))
end

local INPUT_NAME = {
  BUTTON1 = "Left button", BUTTON2 = "Right button", BUTTON3 = "Middle button",
  BUTTON4 = "Button 4", BUTTON5 = "Button 5",
  MOUSEWHEELUP = "Wheel up", MOUSEWHEELDOWN = "Wheel down",
}

function JH.InputName(input)
  if INPUT_NAME[input] then return INPUT_NAME[input] end
  return "Key " .. input
end

function JH.KeyText(key)
  if not key or key == "" then return "|cff888888(no button)|r" end
  local alt, ctrl, shift, input = JH.ParseKey(key)
  return (alt and "Alt+" or "") .. (ctrl and "Ctrl+" or "") .. (shift and "Shift+" or "") .. JH.InputName(input)
end

function JH.ActionText(b)
  if not b.action then return "|cff888888(nothing)|r" end
  if b.action == "spell" then
    if not b.spell or b.spell == "" then return "|cff888888(nothing)|r" end
    if b.rank then return ("%s |cffaaaaaa(rank %d)|r"):format(b.spell, b.rank) end
    return b.spell
  end
  return ACTION_LABEL[b.action] or b.action
end

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------
-- Settings from 0.1.0-alpha (one table per button and a thumb-key list) -> binding list
local OLD_MODS = { [""] = { false, false, false }, ["shift-"] = { false, false, true },
                   ["ctrl-"] = { false, true, false }, ["alt-"] = { true, false, false },
                   ["ctrl-shift-"] = { false, true, true }, ["alt-shift-"] = { true, false, true },
                   ["alt-ctrl-"] = { true, true, false } }

local function Migrate(db)
  if not db.binds or db.bindings then return end
  local out = {}
  for id, b in pairs(db.binds) do
    local input
    if id:match("^%d$") then input = "BUTTON" .. id
    elseif id == "wu" then input = "MOUSEWHEELUP"
    elseif id == "wd" then input = "MOUSEWHEELDOWN"
    else
      local t = tonumber(id:match("^t(%d+)$"))
      input = t and db.thumbKeys and db.thumbKeys[t]
    end
    if input and input ~= "" and type(b) == "table" then
      for mod, v in pairs(b) do
        local m = OLD_MODS[mod]
        if m and type(v) == "string" and v ~= "" then
          local l = v:lower()
          local nb = { key = JH.MakeKey(m[1], m[2], m[3], input) }
          if l == "target" or l == "focus" or l == "menu" then nb.action = l
          else nb.action, nb.spell = "spell", v end
          out[#out + 1] = nb
        end
      end
    end
  end
  table.sort(out, function(a, c) return a.key < c.key end)
  db.bindings = out
  db.binds, db.thumbKeys = nil, nil
end

local function InitDB()
  FaithHealsDB = FaithHealsDB or {}
  local db = FaithHealsDB
  Migrate(db)
  if not db.look and db.theme and JH.THEMES and JH.THEMES[db.theme] then
    local t = JH.THEMES[db.theme]
    db.look = { bar = t.bar, name = t.name, tex = t.tex, pct = t.pct, hots = true, inc = true }
  end
  for k, v in pairs(JH.defaults) do
    if db[k] == nil then db[k] = deepcopy(v) end
  end
  for k, v in pairs(JH.defaults.look) do if db.look[k] == nil then db.look[k] = v end end
  for k, v in pairs(JH.defaults.layout) do if db.layout[k] == nil then db.layout[k] = v end end
  for k, v in pairs(JH.defaults.sizes) do
    if type(db.sizes[k]) ~= "table" then db.sizes[k] = deepcopy(v) end
  end
  db.width, db.height, db.layout.per = nil, nil, nil -- one size for everything (0.1.0) is gone
  -- 4: health fills left to right by default (like Blizzard's bars). Settings saved
  -- before this are put back to that once; bottom to top can still be picked again.
  if (db.version or 0) < 4 then db.look.fill = "h" end
  -- 5: buffs / debuffs became on/off toggles (with a max next to them)
  if (db.version or 0) < 5 then
    local L = db.look
    if type(L.buffs) == "number" then
      L.showBuffs = L.buffs > 0
      if L.buffs > 0 then L.buffMax = L.buffs end
    end
    L.buffs = nil
    if L.debuffs == "off" then L.showDebuffs = false; L.debuffs = "all"
    elseif L.debuffs == "dispel" or L.debuffs == "all" then L.showDebuffs = true end
  end
  -- 6: one icon size became a size per kind: start buffs/debuffs at the old size
  if (db.version or 0) < 6 then
    db.look.buffSize = db.look.hotSize or 1
    db.look.debuffSize = db.look.hotSize or 1
  end
  db.version = 6
  JH.db = db
end

-- Warn about spell names the game doesn't recognise (typos etc.)
function JH.CheckSpell(name)
  if not name or name == "" or tonumber(name) then return true end
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    return ok and info ~= nil
  end
  return true
end

-- What the secure button does for a binding: type, and the attribute that goes with it
-- ("spell" or "macrotext") and its value.
-- A fixed rank is cast by its spell ID (the secure "spell" action accepts an ID).
-- Target / focus / assist are macros on the mouseover (the bar under the mouse sets
-- the mouseover through its tooltip). The plain "target" type did nothing in Forever
-- (seen in-game: the click arrived with type=target, but the target didn't change).
local MACRO = {
  target = "/target [@mouseover,exists]",
  focus  = "/focus [@mouseover,exists]",
  assist = "/assist [@mouseover,exists]",
}
-- The command itself. Right before each click the bar writes "<command> <its unit>"
-- (e.g. "/target party1") into the macro, see ON_CLICK below. The mouseover macro
-- above is only the fallback.
local COMMAND = { target = "/target", focus = "/focus", assist = "/assist" }
local function SecureAction(b)
  if b.action == "spell" then
    if b.id then return "spell", "spell", tostring(b.id) end
    return "spell", "spell", b.spell
  elseif MACRO[b.action] then return "macro", "macrotext", MACRO[b.action]
  elseif b.action == "menu" then return "togglemenu"
  end
  return nil -- trade: done after the click (BarPostClick)
end

local function Complete(b)
  return b.key and b.key ~= "" and b.action and (b.action ~= "spell" or (b.spell and b.spell ~= ""))
end

---------------------------------------------------------------------------
-- Build the attribute list for the unit frames
---------------------------------------------------------------------------
JH.lastCombos = 0
JH.clickInsecure, JH.hoverInsecure = {}, {}

local function BuildAttributes()
  local attrs, combos = {}, {}
  local function add(k, v) attrs[#attrs + 1] = { k, v } end
  JH.clickInsecure, JH.hoverInsecure = {}, {}

  -- clear every mouse combination first, so removed bindings stop working
  for a = 0, 1 do for c = 0, 1 do for s = 0, 1 do
    local p = AttrPrefix(a == 1, c == 1, s == 1)
    for n = 1, 5 do
      add(p .. "type" .. n, nil); add(p .. "spell" .. n, nil); add(p .. "macrotext" .. n, nil)
      add("jhcmd-" .. p .. n, nil)
    end
  end end end

  local seen = {}
  for _, b in ipairs(JH.db.bindings) do
    if Complete(b) and not seen[b.key] then
      seen[b.key] = true
      local alt, ctrl, shift, input = JH.ParseKey(b.key)
      local n = JH.MouseButtonOf(input)
      local t, an, av = SecureAction(b)
      if n then
        local p = AttrPrefix(alt, ctrl, shift)
        if t then add(p .. "type" .. n, t) end
        if an then add(p .. an .. n, av) end
        if COMMAND[b.action] then add("jhcmd-" .. p .. n, COMMAND[b.action]) end
        if b.action == "trade" then JH.clickInsecure[p .. n] = b end
      else
        combos[#combos + 1] = { bind = b.key, b = b }
        local i = #combos
        if t then add("*type-jh" .. i, t) end
        add("*spell-jh" .. i, nil); add("*macrotext-jh" .. i, nil)
        if an then add("*" .. an .. "-jh" .. i, av) end
        add("jhcmd-jh" .. i, COMMAND[b.action])
        if b.action == "trade" then JH.hoverInsecure["jh" .. i] = b end
      end
    end
  end
  for i = 1, math.max(JH.lastCombos, #combos) do
    if not combos[i] or not SecureAction(combos[i].b) then
      add("*type-jh" .. i, nil); add("*spell-jh" .. i, nil); add("*macrotext-jh" .. i, nil)
      add("jhcmd-jh" .. i, nil)
    end
  end
  JH.lastCombos = #combos
  return attrs, combos
end

-- Register for BOTH down and up. The game's secure button template picks the one it
-- acts on itself (ActionButtonUseKeyDown, mouse vs key), and runs the action once.
-- Registering only one direction breaks clicks: in Forever a mouse click is only acted
-- on at "up", so "AnyDown" alone = nothing happens (seen in-game, test12).
local function ClickType()
  return "AnyUp", "AnyDown"
end

local function KeyDownSetting()
  return (GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")) and "key down" or "key up"
end

JH.ClickType = ClickType

function JH.ApplyClicksTo(btn, attrs)
  for _, a in ipairs(attrs) do btn:SetAttribute(a[1], a[2]) end
  local w, h = JH.BarSize()
  btn:SetSize(w, h)
  btn:RegisterForClicks(ClickType())
end

-- Snippet run (securely) for each new frame the header creates, even in combat
local function BuildInitSnippet(attrs)
  local w, h = JH.BarSize()
  local lines = {
    ("self:SetWidth(%d) self:SetHeight(%d)"):format(w, h),
  }
  for _, a in ipairs(attrs) do
    if a[2] ~= nil then
      lines[#lines + 1] = ("self:SetAttribute(%q, %q)"):format(a[1], a[2])
    end
  end
  -- Only methods the restricted environment allows go here (SetWidth, SetHeight,
  -- SetAttribute ...). RegisterForClicks is NOT one of them: the bar's OnLoad does it.
  return table.concat(lines, "\n")
end

-- Actions that can't be done by the secure button (trade) run right after the click.
local MOUSE_N = { LeftButton = 1, RightButton = 2, MiddleButton = 3, Button4 = 4, Button5 = 5 }
function JH.BarPostClick(bar, button, down)
  if JH.debugClicks then
    -- /fh clicks: show what the secure button was told to do for this click
    local GMA = SecureButton_GetModifiedAttribute
    local t = GMA and GMA(bar, "type", button)
    local s = GMA and (GMA(bar, "spell", button) or GMA(bar, "macrotext", button))
    JH.Print(("click: %s%s (%s) on %s [%s] -> type=%s%s"):format(
      JH.CurrentMod(), tostring(button), down and "down" or "up", tostring(bar.unit),
      tostring(bar.unit and UnitName(bar.unit)), tostring(t), s and (" spell=" .. tostring(s)) or ""))
    if not t then JH.Print("  nothing is bound to that - check /fh binds") end
    -- which unit the game really acts on (Self Cast can turn it into "player"),
    -- and who is targeted once the click is done
    local GMU = SecureButton_GetModifiedUnit
    local okU, mu = pcall(GMU or error, bar, button)
    if okU and mu then
      JH.Print(("  game acts on: %s [%s]%s"):format(tostring(mu), tostring(UnitName(mu)),
        (IsModifiedClick and IsModifiedClick("SELFCAST")) and "  (Self Cast key is held!)" or ""))
    end
    if not down and C_Timer and C_Timer.After then
      C_Timer.After(0.1, function()
        JH.Print("  target now: " .. tostring(UnitExists("target") and UnitName("target") or "nobody"))
      end)
    end
  end
  local b
  if button and button:match("^jh%d+$") then
    b = JH.hoverInsecure[button]
  elseif MOUSE_N[button] then
    b = JH.clickInsecure[AttrPrefix(IsAltKeyDown(), IsControlKeyDown(), IsShiftKeyDown()) .. MOUSE_N[button]]
  end
  -- clicks come twice now (down + up): trade only on the up
  if b and b.action == "trade" and bar.unit and not down then
    if not (InitiateTrade and pcall(InitiateTrade, bar.unit)) then
      JH.Print("Couldn't open a trade with " .. (UnitName(bar.unit) or "them") .. ".")
    end
  end
end

---------------------------------------------------------------------------
-- Hover bindings: while the mouse is over a frame, keys (MMO thumb buttons) and the
-- wheel click that frame (securely, works in combat). Same idea as HealBot/Clique.
---------------------------------------------------------------------------
JH.binder = CreateFrame("Frame", "FaithHealsBinder", UIParent, "SecureHandlerBaseTemplate")

local ON_ENTER = [[
  local n = owner:GetAttribute("nkeys") or 0
  for i = 1, n do
    local k = owner:GetAttribute("key" .. i)
    if k then self:SetBindingClick(true, k, self, "jh" .. i) end
  end
]]
local ON_LEAVE = [[ self:ClearBindings() ]]

-- Runs securely right before every click (also in combat): for target / focus / assist
-- bindings it writes the command with this bar's own unit into the macro, e.g.
-- "/target party1", so it never depends on the mouseover.
local ON_CLICK = [[
  local unit = self:GetAttribute("unit")
  if not unit then return end
  local slot
  if button == "LeftButton" then slot = "1"
  elseif button == "RightButton" then slot = "2"
  elseif button == "MiddleButton" then slot = "3"
  elseif button == "Button4" then slot = "4"
  elseif button == "Button5" then slot = "5" end
  if slot then
    local p = (IsAltKeyDown() and "alt-" or "") .. (IsControlKeyDown() and "ctrl-" or "")
              .. (IsShiftKeyDown() and "shift-" or "")
    local cmd = self:GetAttribute("jhcmd-" .. p .. slot)
    if cmd then self:SetAttribute(p .. "macrotext" .. slot, cmd .. " " .. unit) end
  else
    local cmd = self:GetAttribute("jhcmd-" .. button)
    if cmd then self:SetAttribute("*macrotext-" .. button, cmd .. " " .. unit) end
  end
]]

function JH.WrapButton(b)
  if b.jhWrapped or InCombatLockdown() then return end
  SecureHandlerWrapScript(b, "OnClick", JH.binder, ON_CLICK)
  SecureHandlerWrapScript(b, "OnEnter", JH.binder, ON_ENTER)
  SecureHandlerWrapScript(b, "OnLeave", JH.binder, ON_LEAVE)
  SecureHandlerWrapScript(b, "OnHide",  JH.binder, ON_LEAVE)
  b.jhWrapped = true
end

local function ApplyHoverKeys(combos)
  local old = JH.binder:GetAttribute("nkeys") or 0
  for i, c in ipairs(combos) do JH.binder:SetAttribute("key" .. i, c.bind) end
  for i = #combos + 1, old do JH.binder:SetAttribute("key" .. i, nil) end
  JH.binder:SetAttribute("nkeys", #combos)
end

---------------------------------------------------------------------------
-- Optional: when NOT over a frame, key bindings cast on your target
---------------------------------------------------------------------------
local keyOwner = CreateFrame("Frame", "FaithHealsKeyOwner", UIParent)
local fallback = {}

local function MacroSpell(b)
  if b.id and b.rank then return ("%s(Rank %d)"):format(b.spell, b.rank) end
  return b.spell
end

local function ApplyFallback(combos)
  ClearOverrideBindings(keyOwner)
  for _, fb in ipairs(fallback) do fb:SetAttribute("type", nil) end
  if not JH.db.offFrameTarget then return end
  for i, c in ipairs(combos) do
    local fb = fallback[i]
    if not fb then
      fb = CreateFrame("Button", "FaithHealsKey" .. i, UIParent, "SecureActionButtonTemplate")
      fb:Hide()
      fallback[i] = fb
    end
    fb:RegisterForClicks(ClickType()) -- both directions, see ClickType
    local b, text = c.b, nil
    if b.action == "spell" then text = ("/cast [@mouseover,help,nodead][] %s"):format(MacroSpell(b))
    elseif b.action == "target" then text = "/target [@mouseover,exists]"
    elseif b.action == "focus" then text = "/focus [@mouseover,exists][]"
    elseif b.action == "assist" then text = "/assist [@mouseover,exists][]"
    end
    if text then
      fb:SetAttribute("type", "macro")
      fb:SetAttribute("macrotext", text)
      -- not priority: hovering a frame wins, action bars lose
      SetOverrideBindingClick(keyOwner, false, c.bind, fb:GetName(), "LeftButton")
    end
  end
end

---------------------------------------------------------------------------
-- Apply everything (out of combat only)
---------------------------------------------------------------------------
function JH.ApplyAll(quiet)
  if InCombatLockdown() then
    JH.pending = true
    if not quiet then JH.Print("In combat - changes will apply when combat ends.") end
    return
  end
  JH.pending = false

  JH.ChooseLayout()
  local attrs, combos = BuildAttributes()
  local snippet = BuildInitSnippet(attrs)
  for _, header in ipairs(JH.headers) do
    header:SetAttribute("initialConfigFunction", snippet)
    header:SetScale(JH.db.scale or 1)
  end
  if not JH.precreated then
    -- create every frame now (5 party, 40 raid), so they are set up before any combat starts
    JH.precreated = true
    for _, header in ipairs(JH.headers) do
      header:SetAttribute("showSolo", true)
      header:SetAttribute("unitsPerColumn", header.maxUnits)
      header:SetAttribute("maxColumns", 1)
      header:SetAttribute("startingIndex", 1 - header.maxUnits)
      header:Show()
      header:SetAttribute("startingIndex", 1)
    end
    JH.raidHeader:SetAttribute("showSolo", false)
  end
  JH.ApplyLayout()
  ApplyHoverKeys(combos)
  ApplyFallback(combos)
  JH.UpdateMover()
  JH.ApplyTheme()
  for _, header in ipairs(JH.headers) do
    if not header:IsShown() then header:Show() end
  end
  for btn in pairs(JH.buttons) do
    JH.ApplyClicksTo(btn, attrs)
    JH.WrapButton(btn)
  end

  if not quiet then
    local bad, seen = {}, {}
    for _, b in ipairs(JH.db.bindings) do
      if b.action == "spell" and not b.id and not JH.CheckSpell(b.spell) and not seen[b.spell] then
        seen[b.spell] = true; bad[#bad + 1] = b.spell
      end
    end
    if #bad > 0 then JH.Print("Unknown spell(s): " .. table.concat(bad, ", ") .. " - check the spelling.") end
    JH.Print("Settings applied.")
  end
end

---------------------------------------------------------------------------
-- Tooltip: HealBot-style list of what each button does with the held modifiers
---------------------------------------------------------------------------
function JH.CurrentMod()
  return AttrPrefix(IsAltKeyDown(), IsControlKeyDown(), IsShiftKeyDown())
end

local function SortInput(a, b)
  local na, nb = JH.MouseButtonOf(a.input), JH.MouseButtonOf(b.input)
  if na and nb then return na < nb end
  if na or nb then return na ~= nil end
  return a.input < b.input
end

function JH.AddBindingLines(tt)
  local alt, ctrl, shift = IsAltKeyDown(), IsControlKeyDown(), IsShiftKeyDown()
  local rows = {}
  for _, b in ipairs(JH.db.bindings) do
    if Complete(b) then
      local a, c, s, input = JH.ParseKey(b.key)
      if a == alt and c == ctrl and s == shift then rows[#rows + 1] = { input = input, b = b } end
    end
  end
  if #rows == 0 then return end
  table.sort(rows, SortInput)
  local label = (alt and "Alt+" or "") .. (ctrl and "Ctrl+" or "") .. (shift and "Shift+" or "")
  tt:AddLine(" ")
  tt:AddLine("FaithHeals" .. (label ~= "" and (" - " .. label:sub(1, -2)) or ""), 0.2, 1, 0.6)
  for _, r in ipairs(rows) do
    tt:AddDoubleLine(JH.InputName(r.input), JH.ActionText(r.b), 1, 1, 1, 0.6, 1, 0.6)
  end
end

---------------------------------------------------------------------------
-- Errors and /fh debug
---------------------------------------------------------------------------
-- Run fn; an error is shown in the chat (and kept for /fh debug) instead of
-- silently stopping the addon for people without an error addon.
function JH.Safe(what, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    JH.lastError = what .. ": " .. tostring(err)
    JH.Print("|cffff5555Error|r in " .. JH.lastError)
    JH.Print("Please report this (type /fh debug for more).")
  end
  return ok
end

function JH.Debug()
  local P = JH.Print
  local ver = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
  P(("--- debug, version %s ---"):format(tostring(ver)))
  P(("settings loaded: %s, headers: %s, set up: %s, waiting for combat to end: %s"):format(
    tostring(JH.db ~= nil), tostring(JH.headers ~= nil), tostring(JH.precreated == true), tostring(JH.pending == true)))
  P(("group: inGroup=%s inRaid=%s members=%s, layout=%s, in combat=%s, test bars=%s"):format(
    tostring(IsInGroup()), tostring(IsInRaid()), tostring(GetNumGroupMembers()), tostring(JH.active),
    tostring(InCombatLockdown()), tostring(JH.testCount)))
  if JH.db then
    local s, L = JH.Size(), JH.db.layout
    P(("size: %sx%s cols=%s scale=%s | solo=%s player=%s sort=%s grow=%s | bindings=%d"):format(
      tostring(s.w), tostring(s.h), tostring(s.cols), tostring(JH.db.scale), tostring(L.solo),
      tostring(L.player), tostring(L.sort), tostring(L.grow), #JH.db.bindings))
  end
  for _, h in ipairs(JH.headers or {}) do
    local made, shown, units = 0, 0, {}
    for b in pairs(JH.buttons) do
      if b:GetParent() == h then
        made = made + 1
        if b:IsShown() then shown = shown + 1; units[#units + 1] = tostring(b.unit) end
      end
    end
    local x, y = h:GetLeft(), h:GetTop()
    P(("%s: shown=%s alpha=%.1f bars made=%d visible=%d [%s] at %s,%s size %dx%d"):format(
      h:GetName(), tostring(h:IsShown()), h:GetAlpha(), made, shown, table.concat(units, " "),
      x and math.floor(x) or "?", y and math.floor(y) or "?", h:GetWidth(), h:GetHeight()))
  end
  P("last error: " .. tostring(JH.lastError or "none"))
  P("Type /fh binds to see what every button does on your own bar.")
end

-- What the game will do for each binding, read from your own bar
function JH.DebugBinds()
  local P = JH.Print
  local bar
  for b in pairs(JH.buttons) do
    if b.unit and UnitIsUnit(b.unit, "player") then bar = b end
  end
  P(("--- %d binding(s) ---"):format(#JH.db.bindings))
  for _, b in ipairs(JH.db.bindings) do
    local alt, ctrl, shift, input = JH.ParseKey(b.key or "")
    local n = JH.MouseButtonOf(input)
    local onBar = ""
    if bar and n then
      local p = AttrPrefix(alt, ctrl, shift)
      onBar = ("  -> bar: %s=%s %s"):format(p .. "type" .. n, tostring(bar:GetAttribute(p .. "type" .. n)),
        tostring(bar:GetAttribute(p .. "spell" .. n) or ""))
    end
    P(("%s = %s%s"):format(JH.KeyText(b.key), JH.ActionText(b), onBar))
  end
  if not bar then P("(your own bar isn't shown, so the bar's side can't be read)") end
  local selfKey = GetModifiedClick and GetModifiedClick("SELFCAST")
  if selfKey then P("Game's self-cast key: " .. tostring(selfKey)) end
end

---------------------------------------------------------------------------
-- Events & slash commands
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("MODIFIER_STATE_CHANGED")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    JH.Safe("loading settings", InitDB)
    if JH.db then JH.Safe("creating the bars", JH.CreateHeader) end
  elseif event == "PLAYER_LOGIN" then
    if JH.headers and JH.Safe("setting up the bars", JH.ApplyAll, true) then
      JH.Print("Loaded. Type /fh to set up spells and buttons.")
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if not JH.headers then return end
    if JH.pending then JH.Safe("setting up the bars", JH.ApplyAll, true) end
    for btn in pairs(JH.buttons) do JH.WrapButton(btn) end
  elseif event == "MODIFIER_STATE_CHANGED" then
    local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
    if owner and JH.buttons[owner] and JH.ShowTooltip then JH.ShowTooltip(owner) end
  end
end)

SLASH_FAITHHEALS1 = "/fh"
SLASH_FAITHHEALS2 = "/faithheals"
SlashCmdList.FAITHHEALS = function(msg)
  local cmd, rest = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  if cmd == "debug" then
    return JH.Debug()
  elseif cmd == "binds" then
    return JH.Safe("listing bindings", JH.DebugBinds)
  elseif cmd == "auras" then
    return JH.Safe("checking auras", JH.AurasReport)
  elseif cmd == "heals" then
    JH.debugHeals = not JH.debugHeals
    return JH.Safe("checking incoming heals", JH.HealsReport)
  elseif cmd == "clicks" then
    JH.debugClicks = not JH.debugClicks
    return JH.Print(JH.debugClicks and ("Click check on: click a bar and see what it does. Game click setting: "
      .. KeyDownSetting() .. ". /fh clicks again to stop.") or "Click check off.")
  elseif not JH.ToggleConfig then
    return JH.Print("The settings file didn't load. Type /fh debug and report what it says.")
  elseif not JH.headers then
    return JH.Print("The addon didn't start properly. Type /fh debug and report what it says.")
  elseif cmd == "" or cmd == "config" then
    JH.Safe("opening the settings", JH.ToggleConfig)
  elseif cmd == "minimap" then
    JH.db.minimap = JH.db.minimap or { angle = 225 }
    JH.db.minimap.hide = not JH.db.minimap.hide
    JH.UpdateMinimapButton()
  elseif cmd == "unlock" then
    JH.db.locked = false; JH.UpdateMover(); JH.Print("Unlocked - drag the green bar, resize with the corner handle. /fh lock when done.")
  elseif cmd == "lock" then
    JH.db.locked = true; JH.UpdateMover(); JH.Print("Locked.")
  elseif cmd == "scale" and tonumber(rest) then
    JH.SetScale(tonumber(rest))
  elseif cmd == "test" then
    JH.SetTest(tonumber(rest) or (JH.testCount and 0 or 20))
  elseif cmd == "reset" then
    if InCombatLockdown() then return JH.Print("Not in combat.") end
    FaithHealsDB = nil; InitDB(); JH.PlaceHeader(); JH.ApplyAll()
  else
    JH.Print("/fh - settings | /fh debug | /fh binds | /fh clicks | /fh heals | /fh auras | /fh minimap | /fh test 20 | /fh unlock | /fh lock | /fh scale 1.2 | /fh reset")
  end
end
