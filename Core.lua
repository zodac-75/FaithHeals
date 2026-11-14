local ADDON, JH = ...
_G.FaithHeals = JH

JH.buttons = {}      -- unit frames created by the group header

---------------------------------------------------------------------------
-- Modifiers (HealBot style: Click, Shift, Ctrl, Alt, Ctrl+Shift, Alt+Shift, Alt+Ctrl)
--   key  = prefix used by secure button attributes
--   bind = prefix used by WoW key bindings
---------------------------------------------------------------------------
JH.MODS = {
  { key = "",           bind = "",           label = "Click"      },
  { key = "shift-",     bind = "SHIFT-",     label = "Shift"      },
  { key = "ctrl-",      bind = "CTRL-",      label = "Ctrl"       },
  { key = "alt-",       bind = "ALT-",       label = "Alt"        },
  { key = "ctrl-shift-",bind = "CTRL-SHIFT-",label = "Ctrl+Shift" },
  { key = "alt-shift-", bind = "ALT-SHIFT-", label = "Alt+Shift"  },
  { key = "alt-ctrl-",  bind = "ALT-CTRL-",  label = "Alt+Ctrl"   },
}

-- Every "button" a spell can be put on
JH.NUM_THUMB = 12
JH.SLOTS = {
  { id = "1",  label = "Left button",   kind = "click", n = 1 },
  { id = "2",  label = "Right button",  kind = "click", n = 2 },
  { id = "3",  label = "Middle button", kind = "click", n = 3 },
  { id = "4",  label = "Button 4",      kind = "click", n = 4 },
  { id = "5",  label = "Button 5",      kind = "click", n = 5 },
  { id = "wu", label = "Wheel up",      kind = "key",   fixedKey = "MOUSEWHEELUP"   },
  { id = "wd", label = "Wheel down",    kind = "key",   fixedKey = "MOUSEWHEELDOWN" },
}
for i = 1, JH.NUM_THUMB do
  JH.SLOTS[#JH.SLOTS + 1] = { id = "t" .. i, label = "Thumb " .. i, kind = "key", thumb = i }
end

-- Default restoration druid setup.
-- Special values: "target" (select), "focus", "menu" (right-click menu).
JH.defaults = {
  version = 2,
  scale  = 1,
  width  = 100,
  height = 24,
  theme  = "healbot",
  -- how the bars look (a theme is just a preset of these)
  look   = { bar = "health", name = "white", tex = "blizzard", pct = false, hots = true },
  -- how the bars are arranged
  layout = { grow = "down", per = 5, sort = "group", spacing = 2, solo = true, player = true },
  rangeAlpha = 0.4,
  pos    = { "TOPLEFT", "TOPLEFT", 40, -260 },
  locked = true,
  offFrameTarget = false,
  -- What each thumb button sends. Most 12-button MMO mice default to 1-0, -, =
  thumbKeys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" },
  binds = {
    ["1"]  = { [""] = "target",        ["shift-"] = "Regrowth",    ["ctrl-"] = "Lifebloom", ["alt-"] = "Nature's Cure" },
    ["2"]  = { [""] = "Rejuvenation",  ["shift-"] = "Wild Growth", ["ctrl-"] = "Swiftmend", ["alt-"] = "Ironbark" },
    ["3"]  = { [""] = "Cenarion Ward", ["shift-"] = "Rebirth",     ["ctrl-"] = "menu" },
    ["t1"] = { [""] = "Rejuvenation"  },
    ["t2"] = { [""] = "Regrowth"      },
    ["t3"] = { [""] = "Wild Growth"   },
    ["t4"] = { [""] = "Lifebloom"     },
    ["t5"] = { [""] = "Swiftmend"     },
    ["t6"] = { [""] = "Nature's Cure" },
    ["t7"] = { [""] = "Cenarion Ward" },
    ["t8"] = { [""] = "Ironbark"      },
    ["t9"] = { [""] = "Rebirth"       },
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

local function InitDB()
  FaithHealsDB = FaithHealsDB or {}
  local db = FaithHealsDB
  -- migrate version 1 (clicks table) to version 2 (binds per button)
  if db.clicks and not db.binds then
    db.binds = {}
    for k, v in pairs(db.clicks) do
      local mod, n = k:match("^(.-)(%d)$")
      if n then
        db.binds[n] = db.binds[n] or {}
        db.binds[n][mod] = v
      end
    end
    db.clicks, db.keys = nil, nil
  end
  if not db.look and db.theme and JH.THEMES and JH.THEMES[db.theme] then
    local t = JH.THEMES[db.theme]
    db.look = { bar = t.bar, name = t.name, tex = t.tex, pct = t.pct, hots = true }
  end
  for k, v in pairs(JH.defaults) do
    if db[k] == nil then db[k] = deepcopy(v) end
  end
  for k, v in pairs(JH.defaults.look) do if db.look[k] == nil then db.look[k] = v end end
  for k, v in pairs(JH.defaults.layout) do if db.layout[k] == nil then db.layout[k] = v end end
  db.version = 2
  JH.db = db
end

function JH.SlotKey(slot, thumbKeys)
  if slot.fixedKey then return slot.fixedKey end
  if slot.thumb then
    local k = (thumbKeys or JH.db.thumbKeys)[slot.thumb]
    if k and k ~= "" then return k end
  end
end

function JH.SlotName(slot)
  if slot.thumb then
    local k = JH.SlotKey(slot)
    return k and ("%s (%s)"):format(slot.label, k) or slot.label
  end
  return slot.label
end

-- Warn about spell names the game doesn't recognise (typos etc.)
local SPECIAL = { target = true, focus = true, menu = true }
function JH.CheckSpell(name)
  if not name or name == "" or SPECIAL[name:lower()] then return true end
  if C_Spell and C_Spell.GetSpellInfo then
    return C_Spell.GetSpellInfo(name) ~= nil
  end
  return true
end

-- value -> secure action type, spell
local function Action(v)
  local l = v:lower()
  if l == "target" then return "target"
  elseif l == "focus" then return "focus"
  elseif l == "menu" then return "togglemenu"
  else return "spell", v end
end

---------------------------------------------------------------------------
-- Build the attribute list for the unit frames
---------------------------------------------------------------------------
JH.lastCombos = 0

-- Keyboard / wheel combos: each one becomes a virtual button "jhN"
local function KeyCombos()
  local list = {}
  for _, slot in ipairs(JH.SLOTS) do
    if slot.kind == "key" then
      local key = JH.SlotKey(slot)
      local b = JH.db.binds[slot.id]
      if key and b then
        for _, m in ipairs(JH.MODS) do
          local v = b[m.key]
          if v and v ~= "" then
            list[#list + 1] = { bind = m.bind .. key, value = v }
          end
        end
      end
    end
  end
  return list
end

local function BuildAttributes()
  local attrs = {}
  local function add(k, v) attrs[#attrs + 1] = { k, v } end

  -- mouse clicks on the frames
  for _, slot in ipairs(JH.SLOTS) do
    if slot.kind == "click" then
      local b = JH.db.binds[slot.id] or {}
      for _, m in ipairs(JH.MODS) do
        local v = b[m.key]
        local tA, sA = m.key .. "type" .. slot.n, m.key .. "spell" .. slot.n
        if v and v ~= "" then
          local t, s = Action(v)
          add(tA, t); add(sA, s)
        else
          add(tA, nil); add(sA, nil)
        end
      end
    end
  end

  -- thumb keys / wheel while hovering a frame
  local combos = KeyCombos()
  for i, c in ipairs(combos) do
    local t, s = Action(c.value)
    add("*type-jh" .. i, t)
    add("*spell-jh" .. i, s)
  end
  for i = #combos + 1, math.max(JH.lastCombos, #combos) do
    add("*type-jh" .. i, nil); add("*spell-jh" .. i, nil)
  end
  JH.lastCombos = #combos
  return attrs, combos
end

-- The game acts on key-down or key-up depending on this setting; register to match
local function ClickType()
  return (GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")) and "AnyDown" or "AnyUp"
end

function JH.ApplyClicksTo(btn, attrs)
  for _, a in ipairs(attrs) do btn:SetAttribute(a[1], a[2]) end
  btn:SetSize(JH.db.width, JH.db.height)
  btn:RegisterForClicks(ClickType())
end

-- Snippet run (securely) for each new frame the header creates, even in combat
local function BuildInitSnippet(attrs)
  local lines = {
    ("self:SetWidth(%d) self:SetHeight(%d)"):format(JH.db.width, JH.db.height),
    ('self:RegisterForClicks(%q)'):format(ClickType()),
  }
  for _, a in ipairs(attrs) do
    if a[2] ~= nil then
      lines[#lines + 1] = ("self:SetAttribute(%q, %q)"):format(a[1], a[2])
    end
  end
  return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Hover bindings: while the mouse is over a frame, the thumb keys and wheel
-- click that frame (securely, works in combat). Same idea as HealBot/Clique.
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

function JH.WrapButton(b)
  if b.jhWrapped or InCombatLockdown() then return end
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
-- Optional: when NOT over a frame, thumb keys cast on your target
---------------------------------------------------------------------------
local keyOwner = CreateFrame("Frame", "FaithHealsKeyOwner", UIParent)
local fallback = {}

local function ApplyFallback(combos)
  ClearOverrideBindings(keyOwner)
  for _, b in ipairs(fallback) do b:SetAttribute("type", nil) end
  if not JH.db.offFrameTarget then return end
  for i, c in ipairs(combos) do
    local b = fallback[i]
    if not b then
      b = CreateFrame("Button", "FaithHealsKey" .. i, UIParent, "SecureActionButtonTemplate")
      b:RegisterForClicks("AnyUp", "AnyDown")
      b:Hide()
      fallback[i] = b
    end
    local t, s = Action(c.value)
    b:SetAttribute("type", "macro")
    if t == "spell" then
      b:SetAttribute("macrotext", ("/cast [@mouseover,help,nodead][] %s"):format(s))
    elseif t == "target" then
      b:SetAttribute("macrotext", "/target [@mouseover,exists]")
    elseif t == "focus" then
      b:SetAttribute("macrotext", "/focus [@mouseover,exists][]")
    else
      b:SetAttribute("type", nil)
    end
    if b:GetAttribute("type") then
      -- not priority: hovering a frame wins, action bars lose
      SetOverrideBindingClick(keyOwner, false, c.bind, b:GetName(), "LeftButton")
    end
  end
end

---------------------------------------------------------------------------
-- Apply everything (out of combat only)
---------------------------------------------------------------------------
function JH.ApplyAll(quiet)
  if InCombatLockdown() then
    JH.pending = true
    JH.Print("In combat - changes will apply when combat ends.")
    return
  end
  JH.pending = false

  local attrs, combos = BuildAttributes()
  local header = JH.header
  header:SetAttribute("initialConfigFunction", BuildInitSnippet(attrs))
  for btn in pairs(JH.buttons) do JH.ApplyClicksTo(btn, attrs) end
  header:SetScale(JH.db.scale or 1)
  JH.ApplyLayout()
  ApplyHoverKeys(combos)
  ApplyFallback(combos)
  JH.UpdateMover()
  JH.ApplyTheme()

  if not JH.precreated then
    -- create all 40 frames now, so they can be set up before any combat starts
    JH.precreated = true
    header:SetAttribute("startingIndex", -39)
    header:Show()
    header:SetAttribute("startingIndex", 1)
  end
  if not header:IsShown() then header:Show() end
  for btn in pairs(JH.buttons) do
    JH.ApplyClicksTo(btn, attrs)
    JH.WrapButton(btn)
  end

  if not quiet then
    local bad, seen = {}, {}
    for _, b in pairs(JH.db.binds) do
      for _, v in pairs(b) do
        if not JH.CheckSpell(v) and not seen[v] then seen[v] = true; bad[#bad + 1] = v end
      end
    end
    if #bad > 0 then JH.Print("Unknown spell(s): " .. table.concat(bad, ", ") .. " - check the spelling.") end
    JH.Print("Settings applied.")
  end
end

---------------------------------------------------------------------------
-- Tooltip: HealBot-style list of what each button does with the held modifier
---------------------------------------------------------------------------
function JH.CurrentMod()
  return (IsAltKeyDown() and "alt-" or "") .. (IsControlKeyDown() and "ctrl-" or "") .. (IsShiftKeyDown() and "shift-" or "")
end

function JH.AddBindingLines(tt)
  local mod, label = JH.CurrentMod(), nil
  for _, m in ipairs(JH.MODS) do if m.key == mod then label = m.label end end
  if not label then return end
  local first = true
  for _, slot in ipairs(JH.SLOTS) do
    local b = JH.db.binds[slot.id]
    local v = b and b[mod]
    if v and v ~= "" and (slot.kind == "click" or JH.SlotKey(slot)) then
      if first then
        tt:AddLine(" ")
        tt:AddLine("FaithHeals - " .. label, 0.2, 1, 0.6)
        first = false
      end
      tt:AddDoubleLine(JH.SlotName(slot), v, 1, 1, 1, 0.6, 1, 0.6)
    end
  end
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
    InitDB()
    JH.CreateHeader()
  elseif event == "PLAYER_LOGIN" then
    JH.ApplyAll(true)
    JH.Print("Loaded. Type /fh to set up spells and buttons.")
  elseif event == "PLAYER_REGEN_ENABLED" then
    if JH.pending then JH.ApplyAll(true) end
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
  if cmd == "" or cmd == "config" then
    JH.ToggleConfig()
  elseif cmd == "unlock" then
    JH.db.locked = false; JH.UpdateMover(); JH.Print("Unlocked - drag the green bar, resize with the corner handle. /fh lock when done.")
  elseif cmd == "lock" then
    JH.db.locked = true; JH.UpdateMover(); JH.Print("Locked.")
  elseif cmd == "scale" and tonumber(rest) then
    JH.SetScale(tonumber(rest))
  elseif cmd == "reset" then
    if InCombatLockdown() then return JH.Print("Not in combat.") end
    FaithHealsDB = nil; InitDB(); JH.PlaceHeader(); JH.ApplyAll()
  else
    JH.Print("/fh - settings | /fh unlock | /fh lock | /fh scale 1.2 | /fh reset")
  end
end
