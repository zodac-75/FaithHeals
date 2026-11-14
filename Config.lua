local _, JH = ...

local cfg
local E          -- working copy being edited: { binds, thumbKeys, theme, offFrameTarget }
local selected = 1

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

local function NewCheck(parent, text)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  local fs = c.Text or c.text
  if not fs then
    fs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", c, "RIGHT", 2, 0)
  end
  fs:SetFontObject("GameFontHighlightSmall")
  fs:SetText(text)
  return c
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

local function RefreshOptions()
  local db = JH.db
  cfg.w:SetText(db.width); cfg.h:SetText(db.height); cfg.s:SetText(db.scale)
  cfg.themeBtn:SetText("Theme: " .. (JH.THEMES[E.theme] or JH.THEMES.healbot).label)
  cfg.offFrame:SetChecked(E.offFrameTarget and true or false)
  cfg.tips:SetChecked(E.showBindTips ~= false)
  cfg.unlock:SetText(db.locked and "Unlock frames" or "Lock frames")
end

local function LoadFromDB()
  local db = JH.db
  E = {
    binds = JH.deepcopy(db.binds),
    thumbKeys = JH.deepcopy(db.thumbKeys),
    theme = db.theme,
    offFrameTarget = db.offFrameTarget,
    showBindTips = db.showBindTips,
  }
  RefreshList(); RefreshPanel(); RefreshOptions()
end

local function Save()
  local db = JH.db
  -- drop empty entries
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
  db.offFrameTarget = E.offFrameTarget and true or false
  db.showBindTips = E.showBindTips ~= false
  db.width  = math.max(30, math.min(300, tonumber(cfg.w:GetText()) or db.width))
  db.height = math.max(12, math.min(150, tonumber(cfg.h:GetText()) or db.height))
  db.scale  = math.max(0.5, math.min(2, tonumber(cfg.s:GetText()) or db.scale))
  JH.ApplyAll()
  LoadFromDB()
end

---------------------------------------------------------------------------
-- Build the window
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
  if cfg.TitleText then cfg.TitleText:SetText("FaithHeals - Spells") end
  tinsert(UISpecialFrames, "FaithHealsConfig")

  -- Left: list of buttons ------------------------------------------------
  local t1 = Label(cfg, "Button")
  t1:SetPoint("TOPLEFT", 18, -34)

  cfg.list = {}
  for i, slot in ipairs(JH.SLOTS) do
    local lb = CreateFrame("Button", nil, cfg)
    lb:SetSize(290, 20)
    lb:SetPoint("TOPLEFT", 14, -52 - (i - 1) * 21 - ((i > 5) and 6 or 0) - ((i > 7) and 6 or 0))
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

  -- Right: spells for the selected button ---------------------------------
  local px = 330
  cfg.slotTitle = Label(cfg, "", "GameFontNormalLarge")
  cfg.slotTitle:SetPoint("TOPLEFT", px, -36)
  cfg.slotHint = Label(cfg, "", "GameFontDisableSmall")
  cfg.slotHint:SetPoint("TOPLEFT", px, -58)
  cfg.slotHint:SetWidth(350); cfg.slotHint:SetJustifyH("LEFT")

  cfg.keyLabel = Label(cfg, "This button sends:", "GameFontHighlightSmall")
  cfg.keyLabel:SetPoint("TOPLEFT", px, -86)
  cfg.keyBtn = NewKeyButton(cfg, function(key)
    local slot = JH.SLOTS[selected]
    if slot.thumb then E.thumbKeys[slot.thumb] = key; RefreshList() end
  end)
  cfg.keyBtn:SetPoint("LEFT", cfg.keyLabel, "RIGHT", 10, 0)

  cfg.modBoxes = {}
  for i, m in ipairs(JH.MODS) do
    local y = -122 - (i - 1) * 28
    local l = Label(cfg, m.label, "GameFontHighlightSmall")
    l:SetPoint("TOPLEFT", px, y - 4)
    local box = NewBox(cfg, 250)
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

  local help = Label(cfg,
    "Type the spell name exactly as in the spellbook.\n" ..
    "Special words: |cffffffff target|r, |cffffffff focus|r, |cffffffff menu|r.\n" ..
    "Thumb buttons and the wheel only cast while the mouse is over a frame,\n" ..
    "so they keep doing their normal job everywhere else.",
    "GameFontDisableSmall")
  help:SetPoint("TOPLEFT", px, -326)
  help:SetJustifyH("LEFT"); help:SetWidth(350)

  -- Options ---------------------------------------------------------------
  local oy = -400
  cfg.themeBtn = NewButton(cfg, 200)
  cfg.themeBtn:SetPoint("TOPLEFT", px, oy)
  cfg.themeBtn:SetScript("OnClick", function()
    local idx = 1
    for i, k in ipairs(JH.THEME_ORDER) do if k == E.theme then idx = i end end
    E.theme = JH.THEME_ORDER[idx % #JH.THEME_ORDER + 1]
    local th = JH.THEMES[E.theme]
    cfg.w:SetText(th.w); cfg.h:SetText(th.h)   -- each theme suggests a bar size
    cfg.themeBtn:SetText("Theme: " .. th.label)
  end)
  local thHint = Label(cfg, "(click to change, then Save)", "GameFontDisableSmall")
  thHint:SetPoint("LEFT", cfg.themeBtn, "RIGHT", 8, 0)

  local y2 = oy - 32
  local lw = Label(cfg, "Width", "GameFontHighlightSmall"); lw:SetPoint("TOPLEFT", px, y2 - 4)
  cfg.w = NewBox(cfg, 40); cfg.w:SetPoint("TOPLEFT", px + 42, y2)
  local lh = Label(cfg, "Height", "GameFontHighlightSmall"); lh:SetPoint("TOPLEFT", px + 96, y2 - 4)
  cfg.h = NewBox(cfg, 40); cfg.h:SetPoint("TOPLEFT", px + 140, y2)
  local ls = Label(cfg, "Scale", "GameFontHighlightSmall"); ls:SetPoint("TOPLEFT", px + 194, y2 - 4)
  cfg.s = NewBox(cfg, 40); cfg.s:SetPoint("TOPLEFT", px + 232, y2)

  cfg.unlock = NewButton(cfg, 120)
  cfg.unlock:SetPoint("TOPLEFT", px, y2 - 30)
  cfg.unlock:SetScript("OnClick", function()
    JH.db.locked = not JH.db.locked; JH.UpdateMover()
    cfg.unlock:SetText(JH.db.locked and "Unlock frames" or "Lock frames")
  end)

  cfg.tips = NewCheck(cfg, "Show the spell list when hovering a frame")
  cfg.tips:SetPoint("TOPLEFT", px - 4, y2 - 58)
  cfg.tips:SetScript("OnClick", function(self) E.showBindTips = self:GetChecked() and true or false end)

  cfg.offFrame = NewCheck(cfg, "Thumb buttons cast on my target when not over a frame")
  cfg.offFrame:SetPoint("TOPLEFT", px - 4, y2 - 80)
  cfg.offFrame:SetScript("OnClick", function(self) E.offFrameTarget = self:GetChecked() and true or false end)

  local save = NewButton(cfg, 120, "Save & Apply")
  save:SetHeight(24); save:SetPoint("BOTTOMRIGHT", -16, 14)
  save:SetScript("OnClick", Save)

  local revert = NewButton(cfg, 100, "Revert")
  revert:SetHeight(24); revert:SetPoint("RIGHT", save, "LEFT", -8, 0)
  revert:SetScript("OnClick", LoadFromDB)

  local note = Label(cfg, "Changes can't be applied during combat.", "GameFontDisableSmall")
  note:SetPoint("BOTTOMLEFT", 18, 20)

  cfg:SetScript("OnShow", LoadFromDB)
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
