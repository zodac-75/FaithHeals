local _, JH = ...

local MAX_HOTS = 4
local WHITE    = "Interface\\Buttons\\WHITE8X8"
local TEX = {
  blizzard = "Interface\\TargetingFrame\\UI-StatusBar",
  raid     = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
  flat     = WHITE,
}

---------------------------------------------------------------------------
-- Themes
--   bar:  "health" = green > yellow > red by health, "class" = class colour,
--         "dark" = dark bar
--   name: "white" or "class"
--   pct:  show health % (needs a taller bar)
---------------------------------------------------------------------------
JH.THEMES = {
  healbot = { label = "Classic HealBot", bar = "health", name = "white", pct = false, tex = "blizzard",
              w = 100, h = 24, bg = { 0.05, 0.05, 0.05, 0.85 } },
  class   = { label = "Class colours",   bar = "class",  name = "white", pct = true,  tex = "raid",
              w = 90,  h = 38, bg = { 0.05, 0.05, 0.05, 0.85 } },
  slim    = { label = "Slim class",      bar = "class",  name = "white", pct = false, tex = "blizzard",
              w = 100, h = 22, bg = { 0.05, 0.05, 0.05, 0.85 } },
  dark    = { label = "Dark",            bar = "dark",   name = "class", pct = true,  tex = "flat",
              w = 90,  h = 38, bg = { 0.45, 0.05, 0.05, 0.9 } },
}
JH.THEME_ORDER = { "healbot", "class", "slim", "dark" }

local function Theme()
  return JH.THEMES[JH.db and JH.db.theme] or JH.THEMES.healbot
end

-- Midnight/Forever can hand addons "secret" values in combat. These helpers
-- keep a secret value from breaking our logic.
local function IsSecret(v) return issecretvalue and issecretvalue(v) end

local function MakeBorder(parent, size, r, g, b)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetPoint("TOPLEFT", -size, size)
  f:SetPoint("BOTTOMRIGHT", size, -size)
  f:SetBackdrop({ edgeFile = WHITE, edgeSize = size })
  f:SetBackdropBorderColor(r, g, b, 1)
  f:SetFrameLevel(parent:GetFrameLevel() + 5)
  f:Hide()
  return f
end

-- Colour curve for the health-coloured theme (works with secret health values)
local healthCurve
local function HealthCurve()
  if healthCurve ~= nil then return healthCurve end
  healthCurve = false
  if C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor then
    pcall(function()
      local c = C_CurveUtil.CreateColorCurve()
      c:AddPoint(0,   CreateColor(1, 0, 0, 1))
      c:AddPoint(0.5, CreateColor(1, 0.9, 0, 1))
      c:AddPoint(1,   CreateColor(0, 0.8, 0, 1))
      healthCurve = c
    end)
  end
  return healthCurve
end

local function SetBarColor(b, r, g, bl)
  b.hp:GetStatusBarTexture():SetVertexColor(r, g, bl)
end

---------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------
local function UpdateName(b)
  local u = b.unit
  if not u or not UnitExists(u) then return end
  local th = Theme()
  b.name:SetText(UnitName(u) or "")
  local _, class = UnitClass(u)
  local c = class and RAID_CLASS_COLORS[class]
  if th.name == "class" and c then
    b.name:SetTextColor(c.r, c.g, c.b)
  else
    b.name:SetTextColor(1, 1, 1)
  end
  if th.bar == "class" then
    if c then SetBarColor(b, c.r, c.g, c.b) else SetBarColor(b, 0.2, 0.8, 0.2) end
  elseif th.bar == "dark" then
    SetBarColor(b, 0.16, 0.16, 0.16)
  end
end

local function UpdateHealthColor(b, u)
  local cv = HealthCurve()
  if cv and UnitHealthPercent then
    local ok, col = pcall(UnitHealthPercent, u, true, cv)
    if ok and col and col.GetRGB and pcall(function() SetBarColor(b, col:GetRGB()) end) then return end
  end
  local cur, max = UnitHealth(u), UnitHealthMax(u)
  if not IsSecret(cur) and not IsSecret(max) and max and max > 0 then
    local p = cur / max
    if p > 0.5 then SetBarColor(b, (1 - p) * 2, 0.8, 0) else SetBarColor(b, 1, p * 1.8, 0) end
  else
    SetBarColor(b, 0, 0.8, 0)
  end
end

local function UpdateHealth(b)
  local u = b.unit
  if not u or not UnitExists(u) then return end

  if not UnitIsConnected(u) then
    b.hp:SetMinMaxValues(0, 1); b.hp:SetValue(0)
    b.status:SetText("Offline"); b.pct:SetText("")
    return
  elseif UnitIsDeadOrGhost(u) then
    b.hp:SetMinMaxValues(0, 1); b.hp:SetValue(0)
    b.status:SetText("Dead"); b.pct:SetText("")
    return
  end
  b.status:SetText("")

  -- StatusBars accept secret values, so this works in combat too
  b.hp:SetMinMaxValues(0, UnitHealthMax(u))
  local cur = UnitHealth(u)
  local interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
  if not (interp and pcall(b.hp.SetValue, b.hp, cur, interp)) then
    b.hp:SetValue(cur)
  end

  if Theme().bar == "health" then UpdateHealthColor(b, u) end

  -- Health % text (guarded: API differs between builds)
  local ok = false
  if b.showPct and UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
    ok = pcall(function()
      b.pct:SetFormattedText("%.0f%%", UnitHealthPercent(u, true, CurveConstants.ScaleTo100))
    end)
  end
  if not ok then b.pct:SetText("") end
end

-- In slim bars the HoT icons sit on the right, so keep the name clear of them
local function FitName(b, shown)
  if not b.slim then return end
  local inset = 3 + (shown or 0) * ((b.iconSize or 10) + 1)
  b.name:ClearAllPoints()
  b.name:SetPoint("LEFT", 3, 0)
  b.name:SetPoint("RIGHT", -inset, 0)
end

local function UpdateAuras(b)
  local u = b.unit
  local shown = 0
  if u and UnitExists(u) and C_UnitAuras and C_UnitAuras.GetUnitAuras then
    -- Your own HoTs on this unit
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, u, "HELPFUL|PLAYER", MAX_HOTS)
    if ok and type(list) == "table" then
      for i = 1, math.min(#list, MAX_HOTS) do
        local aura, ic = list[i], b.icons[i]
        pcall(ic.tex.SetTexture, ic.tex, aura.icon)
        local cdOk = false
        if C_UnitAuras.GetAuraDuration and ic.cd.SetCooldownFromDurationObject then
          local okD, dur = pcall(C_UnitAuras.GetAuraDuration, u, aura.auraInstanceID)
          if okD and dur then cdOk = pcall(ic.cd.SetCooldownFromDurationObject, ic.cd, dur) end
        end
        if not cdOk then
          local exp, d = aura.expirationTime, aura.duration
          if exp and d and not IsSecret(exp) and not IsSecret(d) and d > 0 then
            ic.cd:SetCooldown(exp - d, d)
          else
            ic.cd:Clear()
          end
        end
        ic:Show()
        shown = i
      end
    end
    -- Debuff you can dispel -> coloured border
    local okD, dl = pcall(C_UnitAuras.GetUnitAuras, u, "HARMFUL|RAID_PLAYER_DISPELLABLE", 1)
    b.dispel:SetShown(okD and type(dl) == "table" and #dl > 0)
  else
    b.dispel:Hide()
  end
  for i = shown + 1, MAX_HOTS do b.icons[i]:Hide() end
  FitName(b, shown)
end

local function UpdateTarget(b)
  b.sel:SetShown(b.unit and UnitExists(b.unit) and UnitIsUnit(b.unit, "target") or false)
end

function JH.UpdateButton(b)
  if not b.unit or not UnitExists(b.unit) then return end
  UpdateName(b); UpdateHealth(b); UpdateAuras(b); UpdateTarget(b)
end

---------------------------------------------------------------------------
-- Theme + layout: text and icons scale with the frame size
---------------------------------------------------------------------------
local FONT = (GameFontHighlightSmall and GameFontHighlightSmall:GetFont()) or "Fonts\\FRIZQT__.TTF"

function JH.LayoutButton(b)
  local w, h = b:GetSize()
  if not w or not h or h <= 0 or w <= 0 then return end
  local th = Theme()
  local tall = h >= 30
  b.slim = not tall
  b.showPct = th.pct and tall

  local fs = math.max(7, math.min(18, math.floor((tall and h * 0.27 or h * 0.5) + 0.5)))
  b.name:SetFont(FONT, fs, "OUTLINE")
  b.pct:SetFont(FONT, math.max(7, fs - 1), "OUTLINE")
  b.status:SetFont(FONT, fs, "OUTLINE")
  b.name:SetJustifyH("CENTER")

  local size
  b.name:ClearAllPoints(); b.pct:ClearAllPoints(); b.status:ClearAllPoints()
  if tall then
    -- name on top, % under it, HoT icons along the bottom
    b.name:SetPoint("TOPLEFT", 3, -math.max(2, h * 0.08))
    b.name:SetPoint("TOPRIGHT", -3, -math.max(2, h * 0.08))
    b.pct:SetPoint("TOP", b.name, "BOTTOM", 0, -1)
    b.status:SetPoint("TOP", b.name, "BOTTOM", 0, -1)
    size = math.max(8, math.floor(math.min(h * 0.32, (w - 6) / MAX_HOTS - 1)))
    for i, ic in ipairs(b.icons) do
      ic:SetSize(size, size); ic:ClearAllPoints()
      ic:SetPoint("BOTTOMLEFT", 2 + (i - 1) * (size + 1), 2)
    end
  else
    -- slim bar: name in the middle, HoT icons stacked from the right edge
    b.name:SetPoint("LEFT", 3, 0); b.name:SetPoint("RIGHT", -3, 0)
    b.pct:SetPoint("RIGHT", -3, 0)
    b.status:SetPoint("RIGHT", -3, 0)
    size = math.max(6, math.floor(math.min(h - 6, w * 0.13)))
    for i, ic in ipairs(b.icons) do
      ic:SetSize(size, size); ic:ClearAllPoints()
      ic:SetPoint("RIGHT", -2 - (i - 1) * (size + 1), 0)
    end
  end
  b.iconSize = size
  if not b.showPct then b.pct:SetText("") end
end

function JH.StyleButton(b)
  local th = Theme()
  b.hp:SetStatusBarTexture(TEX[th.tex] or TEX.blizzard)
  b.hpbg:SetColorTexture(th.bg[1], th.bg[2], th.bg[3], th.bg[4])
  JH.LayoutButton(b)
  if b.unit and UnitExists(b.unit) then JH.UpdateButton(b) else SetBarColor(b, 0, 0.8, 0) end
end

function JH.ApplyTheme()
  for b in pairs(JH.buttons) do JH.StyleButton(b) end
end

---------------------------------------------------------------------------
-- Tooltip (unit + what each button casts with the modifier held right now)
---------------------------------------------------------------------------
function JH.ShowTooltip(b)
  if not b.unit then return end
  GameTooltip_SetDefaultAnchor(GameTooltip, b)
  GameTooltip:SetUnit(b.unit)
  if JH.db.showBindTips ~= false then JH.AddBindingLines(GameTooltip) end
  GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Unit button setup (called from the XML template's OnLoad)
---------------------------------------------------------------------------
function FaithHeals_UnitOnLoad(self)
  JH.buttons[self] = true

  local bg = self:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.9)

  local hp = CreateFrame("StatusBar", nil, self)
  hp:SetPoint("TOPLEFT", 1, -1)
  hp:SetPoint("BOTTOMRIGHT", -1, 1)
  hp:SetStatusBarTexture(TEX.blizzard)
  hp:SetMinMaxValues(0, 1); hp:SetValue(1)
  local hpbg = hp:CreateTexture(nil, "BACKGROUND")
  hpbg:SetAllPoints(); hpbg:SetColorTexture(0.05, 0.05, 0.05, 0.85)
  self.hp, self.hpbg = hp, hpbg

  local name = hp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  name:SetPoint("LEFT", 3, 0); name:SetPoint("RIGHT", -3, 0)
  name:SetWordWrap(false)
  self.name = name

  local pct = hp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pct:SetPoint("RIGHT", -3, 0)
  self.pct = pct

  local status = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  status:SetPoint("RIGHT", -3, 0)
  status:SetTextColor(1, 0.3, 0.3)
  self.status = status

  self.icons = {}
  for i = 1, MAX_HOTS do
    local ic = CreateFrame("Frame", nil, hp)
    ic:SetSize(10, 10)
    ic:SetPoint("RIGHT", -2 - (i - 1) * 11, 0)
    ic.tex = ic:CreateTexture(nil, "ARTWORK"); ic.tex:SetAllPoints()
    ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ic.cd = CreateFrame("Cooldown", nil, ic, "CooldownFrameTemplate")
    ic.cd:SetAllPoints(); ic.cd:SetReverse(true)
    if ic.cd.SetHideCountdownNumbers then ic.cd:SetHideCountdownNumbers(true) end
    ic:Hide()
    self.icons[i] = ic
  end

  self.sel    = MakeBorder(self, 1, 1, 1, 1)          -- your current target
  self.dispel = MakeBorder(self, 2, 0.9, 0.2, 0.9)    -- dispellable debuff
  self.hl = self:CreateTexture(nil, "HIGHLIGHT")
  self.hl:SetAllPoints(); self.hl:SetColorTexture(1, 1, 1, 0.15)

  self:SetScript("OnAttributeChanged", function(s, attr, value)
    if attr == "unit" then
      s.unit = value
      if value then JH.UpdateButton(s) end
    end
  end)
  self:SetScript("OnEnter", function(s) JH.ShowTooltip(s) end)
  self:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self:SetScript("OnShow", function(s) JH.LayoutButton(s); JH.UpdateButton(s) end)
  self:SetScript("OnSizeChanged", function(s) JH.LayoutButton(s) end)
  if JH.db then JH.StyleButton(self) end
end

---------------------------------------------------------------------------
-- Mover, resize handle, scale
---------------------------------------------------------------------------
function JH.PlaceHeader()
  local p = JH.db.pos
  JH.mover:ClearAllPoints()
  JH.mover:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

function JH.UpdateMover()
  local show = not JH.db.locked
  JH.mover:SetShown(show)
  JH.grip:SetShown(show)
end

-- Resize every frame live (out of combat). The saved size is applied to new
-- frames through ApplyAll when the drag ends.
function JH.SetButtonSize(w, h)
  if InCombatLockdown() then return end
  JH.db.width  = math.floor(math.max(30, math.min(300, w)) + 0.5)
  JH.db.height = math.floor(math.max(12, math.min(150, h)) + 0.5)
  for b in pairs(JH.buttons) do b:SetSize(JH.db.width, JH.db.height) end
  JH.header:SetAttribute("yOffset", -2) -- poke the header so it re-lays out
  if JH.RefreshConfig then JH.RefreshConfig() end
end

function JH.SetScale(s)
  if InCombatLockdown() then return end
  JH.db.scale = math.floor(math.max(0.5, math.min(2, s)) * 100 + 0.5) / 100
  JH.header:SetScale(JH.db.scale)
  if JH.RefreshConfig then JH.RefreshConfig() end
end

local function CountLayout()
  local n = 0
  for b in pairs(JH.buttons) do if b:IsVisible() then n = n + 1 end end
  n = math.max(1, n)
  return math.ceil(n / 5), math.min(n, 5)
end

local function CreateGrip(header)
  local g = CreateFrame("Button", "FaithHealsResizeGrip", UIParent)
  g:SetSize(16, 16)
  g:SetPoint("TOPLEFT", header, "BOTTOMRIGHT", -4, 4)
  g:SetFrameStrata("HIGH")
  g:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  g:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  g:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  g:EnableMouseWheel(true)
  g:Hide()

  g:SetScript("OnMouseDown", function(self)
    if InCombatLockdown() then return end
    local x, y = GetCursorPosition()
    local cols, rows = CountLayout()
    self.drag = { x = x, y = y, w = JH.db.width, h = JH.db.height, cols = cols, rows = rows,
                  es = JH.header:GetEffectiveScale() }
    self:SetScript("OnUpdate", function(s)
      local d = s.drag
      local cx, cy = GetCursorPosition()
      local dx, dy = (cx - d.x) / d.es, (d.y - cy) / d.es
      JH.SetButtonSize(d.w + dx / d.cols, d.h + dy / d.rows)
    end)
  end)
  g:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil)
    if self.drag then self.drag = nil; JH.ApplyAll(true) end
  end)
  g:SetScript("OnMouseWheel", function(_, delta) JH.SetScale((JH.db.scale or 1) + delta * 0.05) end)
  g:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("FaithHeals")
    GameTooltip:AddLine("Drag: resize frames", 1, 1, 1)
    GameTooltip:AddLine("Mouse wheel: scale everything", 1, 1, 1)
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return g
end

---------------------------------------------------------------------------
-- Group header (party + raid, handled securely by Blizzard's template)
---------------------------------------------------------------------------
function JH.CreateHeader()
  local mover = CreateFrame("Frame", "FaithHealsMover", UIParent)
  mover:SetSize(150, 14)
  mover:SetMovable(true); mover:EnableMouse(true); mover:RegisterForDrag("LeftButton")
  mover:SetClampedToScreen(true)
  local t = mover:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(0.1, 0.6, 0.2, 0.9)
  local fs = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("CENTER"); fs:SetText("FaithHeals - drag / wheel")
  mover:EnableMouseWheel(true)
  mover:SetScript("OnMouseWheel", function(_, delta) JH.SetScale((JH.db.scale or 1) + delta * 0.05) end)
  mover:SetScript("OnDragStart", function(s) if not InCombatLockdown() then s:StartMoving() end end)
  mover:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local p, _, rp, x, y = s:GetPoint()
    JH.db.pos = { p, rp, x, y }
  end)
  JH.mover = mover
  JH.PlaceHeader()

  local h = CreateFrame("Frame", "FaithHealsHeader", UIParent, "SecureGroupHeaderTemplate")
  h:SetPoint("TOPLEFT", mover, "BOTTOMLEFT", 0, -2)
  h:SetAttribute("template", "FaithHealsUnitTemplate")
  h:SetAttribute("templateType", "Button")
  h:SetAttribute("showPlayer", true)
  h:SetAttribute("showSolo", true)
  h:SetAttribute("showParty", true)
  h:SetAttribute("showRaid", true)
  h:SetAttribute("point", "TOP")
  h:SetAttribute("yOffset", -2)
  h:SetAttribute("xOffset", 0)
  h:SetAttribute("groupBy", "GROUP")
  h:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
  h:SetAttribute("sortMethod", "INDEX")
  h:SetAttribute("unitsPerColumn", 5)
  h:SetAttribute("maxColumns", 8)
  h:SetAttribute("columnSpacing", 3)
  h:SetAttribute("columnAnchorPoint", "LEFT")
  h:Hide() -- shown at PLAYER_LOGIN once click attributes are in place
  JH.header = h
  JH.grip = CreateGrip(h)
end

---------------------------------------------------------------------------
-- Event dispatch
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA", "UNIT_CONNECTION",
                     "UNIT_NAME_UPDATE", "UNIT_FLAGS", "PLAYER_TARGET_CHANGED",
                     "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
  ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_TARGET_CHANGED" then
    for b in pairs(JH.buttons) do UpdateTarget(b) end
  elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    for b in pairs(JH.buttons) do if b:IsVisible() then JH.UpdateButton(b) end end
  else
    for b in pairs(JH.buttons) do
      if b.unit == unit and b:IsVisible() then
        if event == "UNIT_AURA" then UpdateAuras(b)
        elseif event == "UNIT_NAME_UPDATE" then UpdateName(b)
        else UpdateHealth(b) end
      end
    end
  end
end)

-- Range fade, 4x per second
local elapsed = 0
ev:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if elapsed < 0.25 then return end
  elapsed = 0
  for b in pairs(JH.buttons) do
    local u = b.unit
    if u and b:IsVisible() then
      local alpha = 1
      if not UnitIsUnit(u, "player") then
        local ok, inRange, checked = pcall(UnitInRange, u)
        if ok and not IsSecret(inRange) and not IsSecret(checked) and checked and not inRange then
          alpha = 0.4
        end
      end
      b:SetAlpha(alpha)
    end
  end
end)
