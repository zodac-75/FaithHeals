local _, JH = ...

local cfg
local E          -- working copy being edited until Save & Apply
local RefreshLook
local Snapshot   -- defined further down, used by LoadFromDB

local function NewBox(parent, w)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(w, 20)
  e:SetAutoFocus(false)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  e:SetScript("OnEnterPressed", e.ClearFocus)
  return e
end

local function Label(parent, text, font)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
  fs:SetText(text)
  return fs
end

local function NewButton(parent, w, text)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(text or "")
  return b
end

local function NewCheck(parent, text, get, set)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  local fs = c.Text or c.text
  if not fs then
    fs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", c, "RIGHT", 2, 0)
  end
  fs:SetFontObject("GameFontHighlightSmall")
  fs:SetText(text)
  c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  function c:Refresh() self:SetChecked(get() and true or false) end
  return c
end

-- A button that steps through a list of choices each time it is clicked
local function NewCycle(parent, w, prefix, opts, get, set)
  local b = NewButton(parent, w)
  function b:Refresh()
    local cur, text = get(), "Custom"
    for _, o in ipairs(opts) do if o[1] == cur then text = o[2] end end
    self:SetText(prefix .. ": " .. text)
  end
  b:SetScript("OnClick", function()
    local cur, idx = get(), 0
    for i, o in ipairs(opts) do if o[1] == cur then idx = i end end
    set(opts[idx % #opts + 1][1])
    RefreshLook()
  end)
  return b
end

---------------------------------------------------------------------------
-- Scrolling lists
---------------------------------------------------------------------------
local ROWH = 20

local function NewList(parent, w, h)
  local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  sf:SetSize(w, h)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(w, h)
  sf:SetScrollChild(child)
  local bg = sf:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", -3, 3); bg:SetPoint("BOTTOMRIGHT", 3, -3)
  bg:SetColorTexture(0, 0, 0, 0.35)
  sf.child, sf.rows, sf.w = child, {}, w
  return sf
end

local function ListRow(sf, i)
  local r = sf.rows[i]
  if not r then
    r = CreateFrame("Button", nil, sf.child)
    r:SetSize(sf.w, ROWH)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROWH)
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetAllPoints(); r.sel:SetColorTexture(0.1, 0.6, 0.3, 0.45)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 1, 1, 0.1)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT", 3, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", 23, 0); r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
    sf.rows[i] = r
  end
  r:Show()
  return r
end

local function FinishList(sf, n)
  for i = n + 1, #sf.rows do sf.rows[i]:Hide() end
  sf.child:SetHeight(math.max(n * ROWH, 1))
end

---------------------------------------------------------------------------
-- Capture: press any key or mouse button (with Alt/Ctrl/Shift held) to bind it
---------------------------------------------------------------------------
local IGNORE = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, UNKNOWN = 1,
                 LMETA = 1, RMETA = 1 }
local MOUSE = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3",
                Button4 = "BUTTON4", Button5 = "BUTTON5" }
local capture

local function EndCapture(key)
  local done = capture.onDone
  capture.onDone = nil
  capture:Hide()
  if key and done then done(key) end
end

local function Mods()
  return IsAltKeyDown(), IsControlKeyDown(), IsShiftKeyDown()
end

local function BeginCapture(onDone)
  if not capture then
    capture = CreateFrame("Frame", "FaithHealsCapture", UIParent)
    capture:SetAllPoints(UIParent)
    capture:SetFrameStrata("FULLSCREEN_DIALOG")
    capture:EnableMouse(true)
    capture:EnableMouseWheel(true)
    capture:EnableKeyboard(true)
    local bg = capture:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.55)
    local t = capture:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    t:SetPoint("CENTER", 0, 20)
    t:SetText("Press the mouse button or key to bind")
    local t2 = capture:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t2:SetPoint("TOP", t, "BOTTOM", 0, -10)
    t2:SetText("Hold Alt, Ctrl or Shift first to bind a combination.  Esc cancels.")
    capture:SetScript("OnKeyDown", function(_, key)
      if IGNORE[key] then return end
      if key == "ESCAPE" then return EndCapture(nil) end
      local a, c, s = Mods()
      EndCapture(JH.MakeKey(a, c, s, key))
    end)
    capture:SetScript("OnMouseDown", function(_, button)
      local input = MOUSE[button]
      if not input then return end
      local a, c, s = Mods()
      EndCapture(JH.MakeKey(a, c, s, input))
    end)
    capture:SetScript("OnMouseWheel", function(_, delta)
      local a, c, s = Mods()
      EndCapture(JH.MakeKey(a, c, s, delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
    end)
  end
  capture.onDone = onDone
  capture:Show()
end

---------------------------------------------------------------------------
-- Spells page
---------------------------------------------------------------------------
local cur = 0                 -- index of the selected binding in E.bindings
local filter, friendlyOnly = "", true
local RefreshSpells

local function Cur() return E.bindings[cur] end

local function NewBinding()
  E.bindings[#E.bindings + 1] = {}
  cur = #E.bindings
  return E.bindings[cur]
end

local function IconOf(b)
  if b.action == "spell" and b.spell and JH.spellByName and JH.spellByName[b.spell] then
    return JH.spellByName[b.spell].icon
  end
  return nil
end

local function RefreshBindings()
  local list = cfg.bindList
  for i, b in ipairs(E.bindings) do
    local r = ListRow(list, i)
    r.sel:SetShown(i == cur)
    r.icon:SetTexture(IconOf(b))
    r.text:SetText(JH.KeyText(b.key) .. "  |cff66ff99" .. JH.ActionText(b) .. "|r")
    r:SetScript("OnClick", function() cur = i; RefreshSpells() end)
  end
  FinishList(list, #E.bindings)
end

local function RankChoices(b)
  local out = { { label = "Max (always your highest)" } }
  if b and b.action == "spell" and b.spell then
    for _, r in ipairs(JH.RanksOf(b.spell)) do
      out[#out + 1] = { id = r.id, rank = r.rank, label = "Rank " .. r.rank }
    end
  end
  return out
end

local function RefreshEditor()
  local b = Cur()
  if not b then
    cfg.edAction:SetText("|cff888888Pick a binding in the list above, or press New.|r")
    cfg.rankBtn:SetText("Rank: -"); cfg.rankBtn:Disable()
    cfg.bindBtn:SetText("Bind a button"); cfg.bindBtn:Disable()
    return
  end
  cfg.edAction:SetText("Casts: " .. JH.ActionText(b))
  cfg.bindBtn:Enable()
  cfg.bindBtn:SetText(b.key and ("Button: " .. JH.KeyText(b.key) .. "  (click to change)")
    or "Bind a button (click, then press it)")
  if b.action == "spell" then
    cfg.rankBtn:SetText("Rank: " .. (b.rank and ("Rank " .. b.rank) or "Max (always your highest)"))
    if #RankChoices(b) > 1 then cfg.rankBtn:Enable() else cfg.rankBtn:Disable() end
  else
    cfg.rankBtn:SetText("Rank: -"); cfg.rankBtn:Disable()
  end
end

local function SelectAction(entry)
  local b = Cur() or NewBinding()
  if entry.kind == "action" then
    b.action, b.spell, b.id, b.rank = entry.id, nil, nil, nil
  else
    b.action, b.spell, b.id, b.rank = "spell", entry.e.name, nil, nil
  end
  RefreshSpells()
end

local function SpellRows()
  local rows, f = {}, filter:lower()
  local function match(text) return f == "" or text:lower():find(f, 1, true) end
  rows[#rows + 1] = { kind = "header", text = "Actions" }
  for _, a in ipairs(JH.ACTIONS) do
    if match(a.label) then rows[#rows + 1] = { kind = "action", id = a.id, text = a.label } end
  end
  rows[#rows + 1] = { kind = "header", text = "Spells" }
  local n = 0
  for _, e in ipairs(JH.spellList or {}) do
    if match(e.name) and not (friendlyOnly and e.helpful == false) then
      n = n + 1
      local ranks = #e.ranks > 1 and ("  |cff888888%d ranks|r"):format(#e.ranks) or ""
      rows[#rows + 1] = { kind = "spell", e = e, text = e.name .. ranks }
    end
  end
  if n == 0 then
    rows[#rows + 1] = { kind = "header", text = "|cff888888No spells found. Type a name below.|r" }
  end
  return rows
end

RefreshSpells = function()
  local list, b = cfg.spellList, Cur()
  local rows = SpellRows()
  for i, d in ipairs(rows) do
    local r = ListRow(list, i)
    if d.kind == "header" then
      r.text:SetText("|cffffd100" .. d.text .. "|r")
      r.icon:SetTexture(nil)
      r.sel:Hide(); r.hl:Hide()
      r:SetScript("OnClick", nil)
    else
      r.text:SetText(d.text)
      r.icon:SetTexture(d.kind == "spell" and d.e.icon or nil)
      r.hl:Show()
      local on = b and ((d.kind == "action" and b.action == d.id) or
                        (d.kind == "spell" and b.action == "spell" and b.spell == d.e.name))
      r.sel:SetShown(on and true or false)
      r:SetScript("OnClick", function() SelectAction(d) end)
    end
  end
  FinishList(list, #rows)
  RefreshBindings()
  RefreshEditor()
end

RefreshLook = function()
  for _, w in ipairs(cfg.refresh) do w:Refresh() end
  cfg.unlock:SetText(JH.db.locked and "Unlock frames (move / resize)" or "Lock frames")
end

local function LoadFromDB()
  local db = JH.db
  E = {
    bindings = JH.deepcopy(db.bindings),
    theme = db.theme,
    look = JH.deepcopy(db.look),
    layout = JH.deepcopy(db.layout),
    offFrameTarget = db.offFrameTarget,
    showBindTips = db.showBindTips ~= false,
  }
  if cur > #E.bindings then cur = 0 end
  JH.ScanSpells()
  E.sizes = JH.deepcopy(db.sizes)
  E.sizeSel = JH.active or JH.GroupLayout()
  cfg.LoadSizeBoxes()
  cfg.s:SetText(db.scale)
  cfg.sp:SetText(E.layout.spacing)
  cfg.fade:SetText(math.floor((db.rangeAlpha or 0.4) * 100 + 0.5))
  RefreshSpells(); RefreshLook()
  cfg.loaded = Snapshot()
end

local function Num(box, lo, hi, fallback)
  return math.max(lo, math.min(hi, tonumber(box:GetText()) or fallback))
end

-- A string with everything the window can change, to see if anything did
Snapshot = function()
  if not E then return "" end
  local parts = {}
  local function add(v) parts[#parts + 1] = tostring(v) end
  for _, b in ipairs(E.bindings) do add(b.key); add(b.action); add(b.spell); add(b.id) end
  for _, t in ipairs({ E.look, E.layout }) do
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do add(k); add(t[k]) end
  end
  for _, l in ipairs(JH.LAYOUTS) do
    local s = E.sizes and E.sizes[l.id]
    if s then add(s.w); add(s.h); add(s.cols) end
  end
  add(E.theme); add(E.offFrameTarget); add(E.showBindTips)
  if cfg then
    add(cfg.w:GetText()); add(cfg.h:GetText()); add(cfg.cols:GetText())
    add(cfg.s:GetText()); add(cfg.sp:GetText()); add(cfg.fade:GetText())
  end
  return table.concat(parts, "|")
end

local Save

-- Closing the window keeps your changes (same as Save & Apply)
local function SaveIfChanged()
  if E and cfg.loaded and Snapshot() ~= cfg.loaded then
    Save()
  end
end

function Save()
  local db = JH.db
  local keep = {}
  for _, b in ipairs(E.bindings) do
    if b.key and b.action and (b.action ~= "spell" or (b.spell and b.spell ~= "")) then
      keep[#keep + 1] = b
    end
  end
  db.bindings = JH.deepcopy(keep)
  db.theme = E.theme
  db.look = JH.deepcopy(E.look)
  db.layout = JH.deepcopy(E.layout)
  cfg.StoreSizeBoxes()
  db.sizes = JH.deepcopy(E.sizes)
  db.layout.spacing = math.floor(Num(cfg.sp, 0, 20, db.layout.spacing))
  db.offFrameTarget = E.offFrameTarget and true or false
  db.showBindTips = E.showBindTips and true or false
  db.scale  = Num(cfg.s, 0.5, 2, db.scale)
  db.rangeAlpha = Num(cfg.fade, 10, 100, 40) / 100
  if #keep < #E.bindings then
    JH.Print(("%d unfinished binding(s) left out: each needs both a button and a spell."):format(#E.bindings - #keep))
  end
  cur = 0
  JH.ApplyAll()
  if not InCombatLockdown() then LoadFromDB() end
end

local function ShowPage(n)
  cfg.pSpells:SetShown(n == 1)
  cfg.pLook:SetShown(n == 2)
  cfg.pBars:SetShown(n == 3)
  cfg.tab1:SetEnabled(n ~= 1)
  cfg.tab2:SetEnabled(n ~= 2)
  cfg.tab3:SetEnabled(n ~= 3)
end

local function BuildSpells(p)
  -- Left: spells and actions ---------------------------------------------
  Label(p, "1. Pick a spell or action"):SetPoint("TOPLEFT", 18, -64)
  local ls = Label(p, "Search", "GameFontHighlightSmall"); ls:SetPoint("TOPLEFT", 18, -90)
  local search = NewBox(p, 130)
  search:SetPoint("TOPLEFT", 64, -86)
  search:SetScript("OnTextChanged", function(self) filter = self:GetText() or ""; RefreshSpells() end)
  local friendly = NewCheck(p, "Friendly only",
    function() return friendlyOnly end, function(v) friendlyOnly = v; RefreshSpells() end)
  friendly:SetPoint("TOPLEFT", 204, -84)
  tinsert(cfg.refresh, friendly)

  cfg.spellList = NewList(p, 290, 350)
  cfg.spellList:SetPoint("TOPLEFT", 18, -116)

  local lt = Label(p, "Or type a name, spell ID or Name(Rank 2), then Enter:", "GameFontDisableSmall")
  lt:SetPoint("TOPLEFT", 18, -478)
  local typed = NewBox(p, 286)
  typed:SetPoint("TOPLEFT", 24, -494)
  typed:SetScript("OnEnterPressed", function(self)
    local t = strtrim(self:GetText() or "")
    self:ClearFocus()
    if t == "" then return end
    local b = Cur() or NewBinding()
    b.action, b.spell, b.id, b.rank = "spell", t, nil, nil
    self:SetText("")
    RefreshSpells()
  end)

  -- Right: the binding list and the selected binding ---------------------
  local rx = 350
  Label(p, "Your bindings"):SetPoint("TOPLEFT", rx, -64)
  local new = NewButton(p, 70, "New")
  new:SetPoint("TOPLEFT", rx + 176, -60)
  new:SetScript("OnClick", function() NewBinding(); RefreshSpells() end)
  local del = NewButton(p, 70, "Delete")
  del:SetPoint("LEFT", new, "RIGHT", 6, 0)
  del:SetScript("OnClick", function()
    if Cur() then table.remove(E.bindings, cur); cur = math.min(cur, #E.bindings); RefreshSpells() end
  end)

  cfg.bindList = NewList(p, 320, 230)
  cfg.bindList:SetPoint("TOPLEFT", rx, -88)

  Label(p, "2. Rank and button"):SetPoint("TOPLEFT", rx, -334)
  cfg.edAction = Label(p, "", "GameFontHighlight")
  cfg.edAction:SetPoint("TOPLEFT", rx, -356)
  cfg.edAction:SetWidth(330); cfg.edAction:SetJustifyH("LEFT"); cfg.edAction:SetWordWrap(false)

  cfg.rankBtn = NewButton(p, 330)
  cfg.rankBtn:SetPoint("TOPLEFT", rx, -376)
  cfg.rankBtn:SetScript("OnClick", function()
    local b = Cur()
    if not b or b.action ~= "spell" then return end
    local choices, idx = RankChoices(b), 1
    for i, c in ipairs(choices) do if c.id == b.id then idx = i end end
    local nextc = choices[idx % #choices + 1]
    b.id, b.rank = nextc.id, nextc.rank
    RefreshSpells()
  end)

  cfg.bindBtn = NewButton(p, 330)
  cfg.bindBtn:SetHeight(28)
  cfg.bindBtn:SetPoint("TOPLEFT", rx, -406)
  cfg.bindBtn:SetScript("OnClick", function()
    if not Cur() then return end
    local index = cur
    BeginCapture(function(key)
      if not E.bindings[index] then return end
      -- one action per button: drop any other binding on the same button
      for i = #E.bindings, 1, -1 do
        if i ~= index and E.bindings[i].key == key then
          table.remove(E.bindings, i)
          if i < index then index = index - 1 end
        end
      end
      E.bindings[index].key = key
      cur = index
      RefreshSpells()
    end)
  end)

  local hint = Label(p,
    "Click the button above, then press the mouse button or key you want.\n" ..
    "Hold Alt, Ctrl or Shift while you press it to bind that combination.\n" ..
    "Mouse buttons cast when you click a bar. Keys, MMO thumb buttons and the\n" ..
    "wheel cast on the bar under the mouse, and work as usual everywhere else.\n" ..
    "If Alt+click casts on yourself, set Self Cast to None in the game options.",
    "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", rx, -442)
  hint:SetJustifyH("LEFT"); hint:SetWidth(340)

  local tips = NewCheck(p, "Show my bindings when hovering a bar",
    function() return E.showBindTips end, function(v) E.showBindTips = v end)
  tips:SetPoint("TOPLEFT", rx - 4, -508)
  local off = NewCheck(p, "Keys cast on my target when not over a bar",
    function() return E.offFrameTarget end, function(v) E.offFrameTarget = v end)
  off:SetPoint("TOPLEFT", rx - 4, -530)
  tinsert(cfg.refresh, tips); tinsert(cfg.refresh, off)
end

local function BuildLook(p)
  local function custom() E.theme = "custom" end
  local function add(w) tinsert(cfg.refresh, w); return w end
  local lx, rx, y = 24, 370, -66

  -- Look -------------------------------------------------------------------
  Label(p, "Look"):SetPoint("TOPLEFT", lx, y)

  local themeOpts = {}
  for _, k in ipairs(JH.THEME_ORDER) do themeOpts[#themeOpts + 1] = { k, JH.THEMES[k].label } end
  local theme = add(NewCycle(p, 260, "Theme", themeOpts,
    function() return E.theme end,
    function(k)
      local t = JH.THEMES[k]
      E.theme = k
      E.look.bar, E.look.name, E.look.tex, E.look.pct = t.bar, t.name, t.tex, t.pct
    end))
  theme:SetPoint("TOPLEFT", lx, y - 24)
  local th = Label(p, "A theme sets everything below. Change any part afterwards.", "GameFontDisableSmall")
  th:SetPoint("TOPLEFT", lx, y - 52)

  local bar = add(NewCycle(p, 260, "Bar colour",
    { { "health", "By health (green > red)" }, { "class", "Class colour" }, { "dark", "Dark" } },
    function() return E.look.bar end, function(v) E.look.bar = v; custom() end))
  bar:SetPoint("TOPLEFT", lx, y - 76)

  local name = add(NewCycle(p, 260, "Name colour", JH.NAME_COLORS,
    function() return E.look.name end, function(v) E.look.name = v; custom() end))
  name:SetPoint("TOPLEFT", lx, y - 104)

  local tex = add(NewCycle(p, 260, "Bar texture",
    { { "blizzard", "Classic" }, { "raid", "Raid frame" }, { "flat", "Flat" } },
    function() return E.look.tex end, function(v) E.look.tex = v; custom() end))
  tex:SetPoint("TOPLEFT", lx, y - 132)

  local pct = add(NewCheck(p, "Show health % on the bars",
    function() return E.look.pct end, function(v) E.look.pct = v; custom(); RefreshLook() end))
  pct:SetPoint("TOPLEFT", lx - 4, y - 162)
  local inc = add(NewCheck(p, "Show incoming heals",
    function() return E.look.inc ~= false end, function(v) E.look.inc = v end))
  inc:SetPoint("TOPLEFT", lx - 4, y - 186)
  local ih = Label(p, "HoTs, buffs and debuffs: Bars & text tab", "GameFontDisableSmall")
  ih:SetPoint("TOPLEFT", lx + 22, y - 212)

  local lf = Label(p, "Out of range: show at", "GameFontHighlightSmall"); lf:SetPoint("TOPLEFT", lx, y - 236)
  cfg.fade = NewBox(p, 40); cfg.fade:SetPoint("TOPLEFT", lx + 146, y - 232)

  -- Size per group size ----------------------------------------------------
  local y2 = y - 262
  Label(p, "Bar size for each group size"):SetPoint("TOPLEFT", lx, y2)
  local sizeOpts = {}
  for _, l in ipairs(JH.LAYOUTS) do
    sizeOpts[#sizeOpts + 1] = { l.id, ("%s (%d)"):format(l.label, l.units) }
  end
  local sel = add(NewCycle(p, 260, "Group size", sizeOpts,
    function() return E.sizeSel end,
    function(v)
      cfg.StoreSizeBoxes()
      E.sizeSel = v
      cfg.LoadSizeBoxes()
      if JH.testCount then JH.SetTest(JH.LAYOUT_BY_ID[v].units) end
    end))
  sel:SetPoint("TOPLEFT", lx, y2 - 24)

  local lw = Label(p, "Width", "GameFontHighlightSmall"); lw:SetPoint("TOPLEFT", lx, y2 - 60)
  cfg.w = NewBox(p, 40); cfg.w:SetPoint("TOPLEFT", lx + 44, y2 - 56)
  local lh = Label(p, "Height", "GameFontHighlightSmall"); lh:SetPoint("TOPLEFT", lx + 100, y2 - 60)
  cfg.h = NewBox(p, 40); cfg.h:SetPoint("TOPLEFT", lx + 146, y2 - 56)
  local lc = Label(p, "Columns", "GameFontHighlightSmall"); lc:SetPoint("TOPLEFT", lx, y2 - 88)
  cfg.cols = NewBox(p, 40); cfg.cols:SetPoint("TOPLEFT", lx + 60, y2 - 56 - 28)
  cfg.colsHint = Label(p, "", "GameFontDisableSmall"); cfg.colsHint:SetPoint("LEFT", cfg.cols, "RIGHT", 8, 0)
  local ls = Label(p, "Scale (all)", "GameFontHighlightSmall"); ls:SetPoint("TOPLEFT", lx, y2 - 116)
  cfg.s = NewBox(p, 40); cfg.s:SetPoint("TOPLEFT", lx + 76, y2 - 112)

  local sh = Label(p, "The bars switch size by themselves when you join a party\nor a raid, and when the raid grows past 10, 20 or 25.", "GameFontDisableSmall")
  sh:SetPoint("TOPLEFT", lx, y2 - 140); sh:SetJustifyH("LEFT")

  function cfg.LoadSizeBoxes()
    local s = E.sizes[E.sizeSel]
    local l = JH.LAYOUT_BY_ID[E.sizeSel]
    cfg.w:SetText(s.w); cfg.h:SetText(s.h); cfg.cols:SetText(s.cols)
    local cols = math.max(1, math.min(l.units, s.cols))
    cfg.colsHint:SetText(("%d bars per column (or row)"):format(math.ceil(l.units / cols)))
  end
  function cfg.StoreSizeBoxes()
    local s = E.sizes[E.sizeSel]
    local l = JH.LAYOUT_BY_ID[E.sizeSel]
    s.w = math.floor(Num(cfg.w, 30, 300, s.w))
    s.h = math.floor(Num(cfg.h, 12, 150, s.h))
    s.cols = math.floor(Num(cfg.cols, 1, l.units, s.cols))
  end
  local lf2 = Label(p, "%  (100 = never fade)", "GameFontHighlightSmall"); lf2:SetPoint("LEFT", cfg.fade, "RIGHT", 6, 0)

  -- Layout -----------------------------------------------------------------
  Label(p, "Layout"):SetPoint("TOPLEFT", rx, y)

  local grow = add(NewCycle(p, 280, "Direction",
    { { "down", "Columns (top to bottom)" }, { "right", "Rows (left to right)" } },
    function() return E.layout.grow end, function(v) E.layout.grow = v end))
  grow:SetPoint("TOPLEFT", rx, y - 24)

  local sort = add(NewCycle(p, 280, "Sort by",
    { { "group", "Raid group" }, { "role", "Role (tank, healer, dps)" }, { "name", "Name" } },
    function() return E.layout.sort end, function(v) E.layout.sort = v end))
  sort:SetPoint("TOPLEFT", rx, y - 52)

  local lsp = Label(p, "Space between bars", "GameFontHighlightSmall"); lsp:SetPoint("TOPLEFT", rx, y - 88)
  cfg.sp = NewBox(p, 40); cfg.sp:SetPoint("TOPLEFT", rx + 150, y - 84)

  local solo = add(NewCheck(p, "Show when I'm not in a group",
    function() return E.layout.solo ~= false end, function(v) E.layout.solo = v end))
  solo:SetPoint("TOPLEFT", rx - 4, y - 118)
  local me = add(NewCheck(p, "Show myself in the party",
    function() return E.layout.player ~= false end, function(v) E.layout.player = v end))
  me:SetPoint("TOPLEFT", rx - 4, y - 142)

  cfg.unlock = NewButton(p, 280)
  cfg.unlock:SetPoint("TOPLEFT", rx, y - 204)
  cfg.unlock:SetScript("OnClick", function()
    JH.db.locked = not JH.db.locked; JH.UpdateMover(); RefreshLook()
  end)
  local uh = Label(p, "Unlocked: drag the green bar to move, drag the corner\nhandle to resize, mouse wheel on either to scale.", "GameFontDisableSmall")
  uh:SetPoint("TOPLEFT", rx, y - 232); uh:SetJustifyH("LEFT")

  local test = NewButton(p, 280)
  function test:Refresh()
    self:SetText(JH.testCount and "Test bars: On (click to hide)" or "Test bars: Off (click to show)")
  end
  test:SetScript("OnClick", function()
    if JH.testCount then JH.SetTest(0)
    else JH.SetTest(JH.LAYOUT_BY_ID[E.sizeSel].units) end
    RefreshLook()
  end)
  add(test)
  test:SetPoint("TOPLEFT", rx, y - 276)
  local thh = Label(p, "Shows fake group members in the group size picked\non the left. They update when you press Save & Apply,\nand hide themselves when combat starts.", "GameFontDisableSmall")
  thh:SetPoint("TOPLEFT", rx, y - 304); thh:SetJustifyH("LEFT")
end

---------------------------------------------------------------------------
-- Bars & text page: font, text size, name, background, fill direction, icons
---------------------------------------------------------------------------
local function BuildBars(p)
  local function add(w) tinsert(cfg.refresh, w); return w end
  local lx, rx, y = 24, 370, -66
  local function look(key) return function() return E.look[key] end end
  local function setLook(key) return function(v) E.look[key] = v end end

  -- Text -------------------------------------------------------------------
  Label(p, "Text"):SetPoint("TOPLEFT", lx, y)

  local fontOpts = {}
  for _, f in ipairs(JH.FONTS) do fontOpts[#fontOpts + 1] = { f[1], f[2] } end
  add(NewCycle(p, 300, "Font", fontOpts, look("font"), setLook("font")))
    :SetPoint("TOPLEFT", lx, y - 24)

  local sizeOpts = { { 0, "Auto (follows bar height)" } }
  for _, n in ipairs({ 8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 24 }) do sizeOpts[#sizeOpts + 1] = { n, tostring(n) } end
  add(NewCycle(p, 300, "Text size", sizeOpts, look("fontSize"), setLook("fontSize")))
    :SetPoint("TOPLEFT", lx, y - 52)

  add(NewCycle(p, 300, "Outline",
    { { "OUTLINE", "Thin" }, { "THICKOUTLINE", "Thick" }, { "NONE", "None" } },
    look("outline"), setLook("outline"))):SetPoint("TOPLEFT", lx, y - 80)

  local lenOpts = { { 0, "Whole name" } }
  for _, n in ipairs({ 3, 4, 5, 6, 8, 10 }) do lenOpts[#lenOpts + 1] = { n, n .. " letters" } end
  add(NewCycle(p, 300, "Name length", lenOpts, look("nameLen"), setLook("nameLen")))
    :SetPoint("TOPLEFT", lx, y - 108)

  add(NewCycle(p, 300, "Name position", { { "center", "Centre" }, { "left", "Left" } },
    look("nameAlign"), setLook("nameAlign"))):SetPoint("TOPLEFT", lx, y - 136)

  add(NewCycle(p, 300, "Name colour", JH.NAME_COLORS,
    look("name"), function(v) E.look.name = v; E.theme = "custom" end)):SetPoint("TOPLEFT", lx, y - 164)

  add(NewCycle(p, 300, "Health % colour", JH.PCT_COLORS, look("pctColor"), setLook("pctColor")))
    :SetPoint("TOPLEFT", lx, y - 192)

  add(NewCheck(p, "Shadow behind the text (easier to read)",
    function() return E.look.shadow ~= false end, function(v) E.look.shadow = v end))
    :SetPoint("TOPLEFT", lx - 4, y - 222)

  local nh = Label(p, "Health % on/off: Look & layout tab.", "GameFontDisableSmall")
  nh:SetPoint("TOPLEFT", lx, y - 248)

  -- Bars -------------------------------------------------------------------
  Label(p, "Bars"):SetPoint("TOPLEFT", rx, y)

  add(NewCycle(p, 300, "Background",
    { { "auto", "Auto (from bar colour)" }, { "dark", "Dark" }, { "red", "Red" }, { "class", "Dark class colour" } },
    look("bg"), setLook("bg"))):SetPoint("TOPLEFT", rx, y - 24)

  add(NewCycle(p, 300, "Health fills",
    { { "h", "Left to right (like Blizzard)" }, { "v", "Bottom to top" } },
    look("fill"), setLook("fill"))):SetPoint("TOPLEFT", rx, y - 52)

  add(NewCheck(p, "Show raid markers (skull, star ...)",
    function() return E.look.marker ~= false end, function(v) E.look.marker = v end))
    :SetPoint("TOPLEFT", rx - 4, y - 82)

  local bh = Label(p,
    "Bar colour (health / class / dark), texture and incoming\n" ..
    "heals are on the Look & layout tab.", "GameFontDisableSmall")
  bh:SetPoint("TOPLEFT", rx, y - 116); bh:SetJustifyH("LEFT")

  -- Icons on the bars ------------------------------------------------------
  local y2 = y - 276
  Label(p, "Icons on the bars"):SetPoint("TOPLEFT", lx, y2)
  local counts = { { 1, "1" }, { 2, "2" }, { 3, "3" }, { 4, "4" } }

  -- one toggle per kind; "Max" (and for debuffs which ones) next to it
  local function Toggle(text, key, row)
    add(NewCheck(p, text, function() return E.look[key] ~= false and E.look[key] ~= nil end,
      function(v) E.look[key] = v end)):SetPoint("TOPLEFT", lx - 4, y2 - 24 - row * 28)
  end
  local function Max(key, row)
    add(NewCycle(p, 110, "Max", counts, look(key), setLook(key)))
      :SetPoint("TOPLEFT", lx + 170, y2 - 24 - row * 28)
  end
  local sizes = { { 0.5, "50%" }, { 0.75, "75%" }, { 1, "100%" }, { 1.25, "125%" },
                  { 1.5, "150%" }, { 1.75, "175%" }, { 2, "200%" } }
  local function Size(key, row)
    add(NewCycle(p, 130, "Size", sizes, look(key), setLook(key)))
      :SetPoint("TOPLEFT", lx + 290, y2 - 24 - row * 28)
  end

  Toggle("My HoTs", "hots", 0);      Max("hotMax", 0);    Size("hotSize", 0)
  Toggle("Buffs", "showBuffs", 1);        Max("buffMax", 1);   Size("buffSize", 1)
  Toggle("Debuffs", "showDebuffs", 2);    Max("debuffMax", 2); Size("debuffSize", 2)
  add(NewCycle(p, 250, "Which", { { "all", "All debuffs" }, { "dispel", "Only ones I can dispel" } },
    look("debuffs"), setLook("debuffs"))):SetPoint("TOPLEFT", lx + 170, y2 - 24 - 3 * 28)

  add(NewCheck(p, "Purple border when I can dispel a debuff",
    function() return E.look.dispel ~= false end, function(v) E.look.dispel = v end))
    :SetPoint("TOPLEFT", lx - 4, y2 - 24 - 4 * 28)

  local ih = Label(p,
    "Shown on every bar in the group, your own too. Buffs = all buffs that aren't your HoTs.\n" ..
    "Try it with Test bars (Look & layout tab), then press Save & Apply.",
    "GameFontDisableSmall")
  ih:SetPoint("TOPLEFT", lx, y2 - 168); ih:SetJustifyH("LEFT")
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function Build()
  cfg = CreateFrame("Frame", "FaithHealsConfig", UIParent, "BasicFrameTemplateWithInset")
  cfg:SetSize(720, 620)
  cfg:SetPoint("CENTER")
  cfg:SetFrameStrata("DIALOG")
  cfg:SetMovable(true); cfg:EnableMouse(true); cfg:RegisterForDrag("LeftButton")
  cfg:SetClampedToScreen(true)
  cfg:SetScript("OnDragStart", cfg.StartMoving)
  cfg:SetScript("OnDragStop", cfg.StopMovingOrSizing)
  if cfg.TitleText then cfg.TitleText:SetText("FaithHeals") end
  tinsert(UISpecialFrames, "FaithHealsConfig")
  cfg.refresh = {}

  cfg.tab1 = NewButton(cfg, 130, "Spells")
  cfg.tab1:SetPoint("TOPLEFT", 14, -30)
  cfg.tab1:SetScript("OnClick", function() ShowPage(1) end)
  cfg.tab2 = NewButton(cfg, 130, "Look & layout")
  cfg.tab2:SetPoint("LEFT", cfg.tab1, "RIGHT", 6, 0)
  cfg.tab2:SetScript("OnClick", function() ShowPage(2) end)
  cfg.tab3 = NewButton(cfg, 130, "Bars & text")
  cfg.tab3:SetPoint("LEFT", cfg.tab2, "RIGHT", 6, 0)
  cfg.tab3:SetScript("OnClick", function() ShowPage(3) end)

  cfg.pSpells = CreateFrame("Frame", nil, cfg); cfg.pSpells:SetAllPoints()
  cfg.pLook   = CreateFrame("Frame", nil, cfg); cfg.pLook:SetAllPoints()
  cfg.pBars   = CreateFrame("Frame", nil, cfg); cfg.pBars:SetAllPoints()
  BuildSpells(cfg.pSpells)
  BuildLook(cfg.pLook)
  BuildBars(cfg.pBars)

  local save = NewButton(cfg, 120, "Save & Apply")
  save:SetHeight(24); save:SetPoint("BOTTOMRIGHT", -16, 14)
  save:SetScript("OnClick", Save)

  local revert = NewButton(cfg, 100, "Revert")
  revert:SetHeight(24); revert:SetPoint("RIGHT", save, "LEFT", -8, 0)
  revert:SetScript("OnClick", LoadFromDB)

  local note = Label(cfg, "Changes are saved when you press Save & Apply or close the window.", "GameFontDisableSmall")
  note:SetPoint("BOTTOMLEFT", 18, 20)

  cfg:SetScript("OnShow", LoadFromDB)
  cfg:HookScript("OnHide", function()
    if capture then capture:Hide() end
    JH.Safe("saving the settings", SaveIfChanged)
  end)
  ShowPage(1)
  cfg:Hide()
end

function JH.RefreshConfig()
  if cfg and cfg:IsShown() and E and not cfg.w:HasFocus() and not cfg.h:HasFocus() and not cfg.s:HasFocus() then
    -- the corner handle resized the bars: show that group size and its new numbers
    local id = JH.active
    if id and JH.db.sizes[id] then
      E.sizes[id] = JH.deepcopy(JH.db.sizes[id])
      E.sizeSel = id
      cfg.LoadSizeBoxes()
    end
    cfg.s:SetText(JH.db.scale)
  end
  if cfg and cfg:IsShown() then RefreshLook() end
end

function JH.ToggleConfig()
  if not cfg then Build() end
  if cfg:IsShown() then cfg:Hide() else cfg:Show() end
end

---------------------------------------------------------------------------
-- Minimap button: left-click opens the settings, right-click locks/unlocks the
-- bars, drag moves it around the minimap. Lives on UIParent, anchored to the minimap.
---------------------------------------------------------------------------
local mini

local function PlaceMini()
  local a = math.rad(JH.db.minimap.angle or 225)
  local r = (Minimap:GetWidth() / 2) + 6
  mini:ClearAllPoints()
  mini:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function JH.UpdateMinimapButton()
  if not JH.db or not Minimap then return end
  JH.db.minimap = JH.db.minimap or { angle = 225 }
  if not mini then
    mini = CreateFrame("Button", "FaithHealsMinimapButton", UIParent)
    mini:SetSize(31, 31)
    mini:SetFrameStrata("MEDIUM")
    mini:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mini:RegisterForDrag("LeftButton")
    local icon = mini:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\AddOns\\FaithHeals\\Media\\Icon")
    local ring = mini:CreateTexture(nil, "OVERLAY")
    ring:SetSize(53, 53)
    ring:SetPoint("TOPLEFT")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    mini:SetScript("OnClick", function(_, button)
      if button == "RightButton" then
        JH.db.locked = not JH.db.locked
        JH.UpdateMover()
        JH.Print(JH.db.locked and "Locked." or "Unlocked - drag the green bar, resize with the corner handle.")
      else
        JH.Safe("opening the settings", JH.ToggleConfig)
      end
    end)
    mini:SetScript("OnDragStart", function(self)
      self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local s = Minimap:GetEffectiveScale()
        JH.db.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
        PlaceMini()
      end)
    end)
    mini:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mini:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine("FaithHeals")
      GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
      GameTooltip:AddLine("Right-click: lock / unlock the bars", 1, 1, 1)
      GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
      GameTooltip:Show()
    end)
    mini:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  PlaceMini()
  mini:SetShown(not JH.db.minimap.hide)
end

local mev = CreateFrame("Frame")
mev:RegisterEvent("PLAYER_LOGIN")
mev:SetScript("OnEvent", function() JH.Safe("making the minimap button", JH.UpdateMinimapButton) end)
