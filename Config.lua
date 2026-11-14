local _, JH = ...

local cfg
local E          -- working copy being edited until Save & Apply
local selected = 1
local RefreshLook

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
-- Key capture for "what does this thumb button send"
---------------------------------------------------------------------------
local IGNORE = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, UNKNOWN = 1,
                 LMETA = 1, RMETA = 1 }

local function NewKeyButton(parent, onChange)
  local b = NewButton(parent, 130)
  b.key = ""
  function b:SetKey(k)
    self.key = k or ""
    self:SetText(self.key == "" and "|cff888888(not set)|r" or self.key)
  end
  local function finish(self, k, changed)
    self.capturing = false
    self:EnableKeyboard(false)
    self:SetKey(k)
    if changed then onChange(self.key) end
  end
  b:SetScript("OnClick", function(self)
    self.capturing = true
    self:SetText("|cffffff00Press the button...|r")
    self:EnableKeyboard(true)
  end)
  b:SetScript("OnKeyDown", function(self, key)
    if not self.capturing or IGNORE[key] then return end
    if key == "ESCAPE" then return finish(self, self.key) end
    if key == "BACKSPACE" or key == "DELETE" then return finish(self, "", true) end
    finish(self, key, true)
  end)
  b:SetScript("OnHide", function(self) if self.capturing then finish(self, self.key) end end)
  return b
end

---------------------------------------------------------------------------
-- Refresh helpers
---------------------------------------------------------------------------
local function ListText(slot)
  local name = slot.label
  if slot.thumb then
    local k = E.thumbKeys[slot.thumb]
    name = ("%s |cff888888[%s]|r"):format(name, (k and k ~= "") and k or "-")
  end
  local b = E.binds[slot.id]
  local n = 0
  if b then for _, v in pairs(b) do if v ~= "" then n = n + 1 end end end
  local click = b and b[""]
  if click and click ~= "" then
    return ("%s  |cff66ff99%s|r%s"):format(name, click, n > 1 and (" |cff888888+" .. (n - 1) .. "|r") or "")
  elseif n > 0 then
    return ("%s  |cff888888+%d|r"):format(name, n)
  end
  return name
end

local function RefreshList()
  for i, slot in ipairs(JH.SLOTS) do
    local lb = cfg.list[i]
    lb.text:SetText(ListText(slot))
    lb.sel:SetShown(i == selected)
  end
end

local function RefreshPanel()
  local slot = JH.SLOTS[selected]
  cfg.slotTitle:SetText(slot.label)
  local b = E.binds[slot.id] or {}
  for i, m in ipairs(JH.MODS) do
    cfg.modBoxes[i]:SetText(b[m.key] or "")
    cfg.modBoxes[i]:SetCursorPosition(0)
  end
  if slot.thumb then
    cfg.keyLabel:Show(); cfg.keyBtn:Show()
    cfg.keyBtn:SetKey(E.thumbKeys[slot.thumb])
    cfg.slotHint:SetText("Click the button on the right, then press this thumb button on the mouse.")
  else
    cfg.keyLabel:Hide(); cfg.keyBtn:Hide()
    if slot.kind == "click" then
      cfg.slotHint:SetText("Clicking a frame with this mouse button.")
    else
      cfg.slotHint:SetText("Scrolling the wheel while the mouse is over a frame.")
    end
  end
end

RefreshLook = function()
  for _, w in ipairs(cfg.refresh) do w:Refresh() end
  cfg.unlock:SetText(JH.db.locked and "Unlock frames (move / resize)" or "Lock frames")
end

local function LoadFromDB()
  local db = JH.db
  E = {
    binds = JH.deepcopy(db.binds),
    thumbKeys = JH.deepcopy(db.thumbKeys),
    theme = db.theme,
    look = JH.deepcopy(db.look),
    layout = JH.deepcopy(db.layout),
    offFrameTarget = db.offFrameTarget,
    showBindTips = db.showBindTips ~= false,
  }
  cfg.w:SetText(db.width); cfg.h:SetText(db.height); cfg.s:SetText(db.scale)
  cfg.per:SetText(E.layout.per); cfg.sp:SetText(E.layout.spacing)
  cfg.fade:SetText(math.floor((db.rangeAlpha or 0.4) * 100 + 0.5))
  RefreshList(); RefreshPanel(); RefreshLook()
end

local function Num(box, lo, hi, fallback)
  return math.max(lo, math.min(hi, tonumber(box:GetText()) or fallback))
end

local function Save()
  local db = JH.db
  local binds = {}
  for id, b in pairs(E.binds) do
    for mod, v in pairs(b) do
      v = strtrim(v or "")
      if v ~= "" then
        binds[id] = binds[id] or {}
        binds[id][mod] = v
      end
    end
  end
  db.binds = binds
  db.thumbKeys = JH.deepcopy(E.thumbKeys)
  db.theme = E.theme
  db.look = JH.deepcopy(E.look)
  db.layout = JH.deepcopy(E.layout)
  db.layout.per = math.floor(Num(cfg.per, 1, 40, db.layout.per))
  db.layout.spacing = math.floor(Num(cfg.sp, 0, 20, db.layout.spacing))
  db.offFrameTarget = E.offFrameTarget and true or false
  db.showBindTips = E.showBindTips and true or false
  db.width  = Num(cfg.w, 30, 300, db.width)
  db.height = Num(cfg.h, 12, 150, db.height)
  db.scale  = Num(cfg.s, 0.5, 2, db.scale)
  db.rangeAlpha = Num(cfg.fade, 10, 100, 40) / 100
  JH.ApplyAll()
  if not InCombatLockdown() then LoadFromDB() end
end

local function ShowPage(n)
  cfg.pSpells:SetShown(n == 1)
  cfg.pLook:SetShown(n == 2)
  cfg.tab1:SetEnabled(n ~= 1)
  cfg.tab2:SetEnabled(n ~= 2)
end

---------------------------------------------------------------------------
-- Page 1: spells
---------------------------------------------------------------------------
local function BuildSpells(p)
  local t1 = Label(p, "Button")
  t1:SetPoint("TOPLEFT", 18, -62)

  cfg.list = {}
  for i, slot in ipairs(JH.SLOTS) do
    local lb = CreateFrame("Button", nil, p)
    lb:SetSize(290, 20)
    lb:SetPoint("TOPLEFT", 14, -80 - (i - 1) * 21 - ((i > 5) and 6 or 0) - ((i > 7) and 6 or 0))
    lb.sel = lb:CreateTexture(nil, "BACKGROUND")
    lb.sel:SetAllPoints(); lb.sel:SetColorTexture(0.1, 0.6, 0.3, 0.45)
    local hl = lb:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.1)
    lb.text = lb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lb.text:SetPoint("LEFT", 6, 0); lb.text:SetPoint("RIGHT", -4, 0)
    lb.text:SetJustifyH("LEFT"); lb.text:SetWordWrap(false)
    lb:SetScript("OnClick", function()
      selected = i
      RefreshList(); RefreshPanel()
    end)
    cfg.list[i] = lb
  end

  local px = 330
  cfg.slotTitle = Label(p, "", "GameFontNormalLarge")
  cfg.slotTitle:SetPoint("TOPLEFT", px, -64)
  cfg.slotHint = Label(p, "", "GameFontDisableSmall")
  cfg.slotHint:SetPoint("TOPLEFT", px, -86)
  cfg.slotHint:SetWidth(350); cfg.slotHint:SetJustifyH("LEFT")

  cfg.keyLabel = Label(p, "This button sends:", "GameFontHighlightSmall")
  cfg.keyLabel:SetPoint("TOPLEFT", px, -114)
  cfg.keyBtn = NewKeyButton(p, function(key)
    local slot = JH.SLOTS[selected]
    if slot.thumb then E.thumbKeys[slot.thumb] = key; RefreshList() end
  end)
  cfg.keyBtn:SetPoint("LEFT", cfg.keyLabel, "RIGHT", 10, 0)

  cfg.modBoxes = {}
  for i, m in ipairs(JH.MODS) do
    local y = -150 - (i - 1) * 28
    local l = Label(p, m.label, "GameFontHighlightSmall")
    l:SetPoint("TOPLEFT", px, y - 4)
    local box = NewBox(p, 250)
    box:SetPoint("TOPLEFT", px + 90, y)
    box:SetScript("OnTextChanged", function(self, user)
      if not user then return end
      local slot = JH.SLOTS[selected]
      E.binds[slot.id] = E.binds[slot.id] or {}
      E.binds[slot.id][m.key] = self:GetText()
      RefreshList()
    end)
    cfg.modBoxes[i] = box
  end

  local help = Label(p,
    "Type the spell name exactly as in the spellbook.\n" ..
    "Special words: |cffffffff target|r, |cffffffff focus|r, |cffffffff menu|r.\n" ..
    "Thumb buttons and the wheel only cast while the mouse is over a frame,\n" ..
    "so they keep doing their normal job everywhere else.",
    "GameFontDisableSmall")
  help:SetPoint("TOPLEFT", px, -354)
  help:SetJustifyH("LEFT"); help:SetWidth(350)

  local tips = NewCheck(p, "Show the spell list when hovering a frame",
    function() return E.showBindTips end, function(v) E.showBindTips = v end)
  tips:SetPoint("TOPLEFT", px - 4, -420)
  local off = NewCheck(p, "Thumb buttons cast on my target when not over a frame",
    function() return E.offFrameTarget end, function(v) E.offFrameTarget = v end)
  off:SetPoint("TOPLEFT", px - 4, -444)
  tinsert(cfg.refresh, tips); tinsert(cfg.refresh, off)
end

---------------------------------------------------------------------------
-- Page 2: look and layout
---------------------------------------------------------------------------
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
      cfg.w:SetText(t.w); cfg.h:SetText(t.h)   -- each theme suggests a bar size
    end))
  theme:SetPoint("TOPLEFT", lx, y - 24)
  local th = Label(p, "A theme sets everything below. Change any part afterwards.", "GameFontDisableSmall")
  th:SetPoint("TOPLEFT", lx, y - 52)

  local bar = add(NewCycle(p, 260, "Bar colour",
    { { "health", "By health (green > red)" }, { "class", "Class colour" }, { "dark", "Dark" } },
    function() return E.look.bar end, function(v) E.look.bar = v; custom() end))
  bar:SetPoint("TOPLEFT", lx, y - 76)

  local name = add(NewCycle(p, 260, "Name colour",
    { { "white", "White" }, { "class", "Class colour" } },
    function() return E.look.name end, function(v) E.look.name = v; custom() end))
  name:SetPoint("TOPLEFT", lx, y - 104)

  local tex = add(NewCycle(p, 260, "Bar texture",
    { { "blizzard", "Classic" }, { "raid", "Raid frame" }, { "flat", "Flat" } },
    function() return E.look.tex end, function(v) E.look.tex = v; custom() end))
  tex:SetPoint("TOPLEFT", lx, y - 132)

  local pct = add(NewCheck(p, "Show health %  (bars 30 or higher)",
    function() return E.look.pct end, function(v) E.look.pct = v; custom(); RefreshLook() end))
  pct:SetPoint("TOPLEFT", lx - 4, y - 162)
  local hots = add(NewCheck(p, "Show my HoT icons on the bars",
    function() return E.look.hots ~= false end, function(v) E.look.hots = v end))
  hots:SetPoint("TOPLEFT", lx - 4, y - 186)

  local y2 = y - 224
  Label(p, "Bar size"):SetPoint("TOPLEFT", lx, y2)
  local lw = Label(p, "Width", "GameFontHighlightSmall"); lw:SetPoint("TOPLEFT", lx, y2 - 28)
  cfg.w = NewBox(p, 40); cfg.w:SetPoint("TOPLEFT", lx + 44, y2 - 24)
  local lh = Label(p, "Height", "GameFontHighlightSmall"); lh:SetPoint("TOPLEFT", lx + 100, y2 - 28)
  cfg.h = NewBox(p, 40); cfg.h:SetPoint("TOPLEFT", lx + 146, y2 - 24)
  local ls = Label(p, "Scale", "GameFontHighlightSmall"); ls:SetPoint("TOPLEFT", lx + 202, y2 - 28)
  cfg.s = NewBox(p, 40); cfg.s:SetPoint("TOPLEFT", lx + 240, y2 - 24)

  local lf = Label(p, "Out of range: show at", "GameFontHighlightSmall"); lf:SetPoint("TOPLEFT", lx, y2 - 60)
  cfg.fade = NewBox(p, 40); cfg.fade:SetPoint("TOPLEFT", lx + 146, y2 - 56)
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

  local lp = Label(p, "Bars per column / row", "GameFontHighlightSmall"); lp:SetPoint("TOPLEFT", rx, y - 88)
  cfg.per = NewBox(p, 40); cfg.per:SetPoint("TOPLEFT", rx + 150, y - 84)
  local lp2 = Label(p, "5 = one per group", "GameFontDisableSmall"); lp2:SetPoint("LEFT", cfg.per, "RIGHT", 8, 0)

  local lsp = Label(p, "Space between bars", "GameFontHighlightSmall"); lsp:SetPoint("TOPLEFT", rx, y - 116)
  cfg.sp = NewBox(p, 40); cfg.sp:SetPoint("TOPLEFT", rx + 150, y - 112)

  local solo = add(NewCheck(p, "Show when I'm not in a group",
    function() return E.layout.solo ~= false end, function(v) E.layout.solo = v end))
  solo:SetPoint("TOPLEFT", rx - 4, y - 142)
  local me = add(NewCheck(p, "Show myself in the party",
    function() return E.layout.player ~= false end, function(v) E.layout.player = v end))
  me:SetPoint("TOPLEFT", rx - 4, y - 166)

  cfg.unlock = NewButton(p, 280)
  cfg.unlock:SetPoint("TOPLEFT", rx, y - 204)
  cfg.unlock:SetScript("OnClick", function()
    JH.db.locked = not JH.db.locked; JH.UpdateMover(); RefreshLook()
  end)
  local uh = Label(p, "Unlocked: drag the green bar to move, drag the corner\nhandle to resize, mouse wheel on either to scale.", "GameFontDisableSmall")
  uh:SetPoint("TOPLEFT", rx, y - 232); uh:SetJustifyH("LEFT")
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function Build()
  cfg = CreateFrame("Frame", "FaithHealsConfig", UIParent, "BasicFrameTemplateWithInset")
  cfg:SetSize(700, 600)
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

  cfg.pSpells = CreateFrame("Frame", nil, cfg); cfg.pSpells:SetAllPoints()
  cfg.pLook   = CreateFrame("Frame", nil, cfg); cfg.pLook:SetAllPoints()
  BuildSpells(cfg.pSpells)
  BuildLook(cfg.pLook)

  local save = NewButton(cfg, 120, "Save & Apply")
  save:SetHeight(24); save:SetPoint("BOTTOMRIGHT", -16, 14)
  save:SetScript("OnClick", Save)

  local revert = NewButton(cfg, 100, "Revert")
  revert:SetHeight(24); revert:SetPoint("RIGHT", save, "LEFT", -8, 0)
  revert:SetScript("OnClick", LoadFromDB)

  local note = Label(cfg, "Nothing changes until Save & Apply. Not possible during combat.", "GameFontDisableSmall")
  note:SetPoint("BOTTOMLEFT", 18, 20)

  cfg:SetScript("OnShow", LoadFromDB)
  ShowPage(1)
  cfg:Hide()
end

function JH.RefreshConfig()
  if cfg and cfg:IsShown() and not cfg.w:HasFocus() and not cfg.h:HasFocus() and not cfg.s:HasFocus() then
    cfg.w:SetText(JH.db.width); cfg.h:SetText(JH.db.height); cfg.s:SetText(JH.db.scale)
  end
end

function JH.ToggleConfig()
  if not cfg then Build() end
  if cfg:IsShown() then cfg:Hide() else cfg:Show() end
end
