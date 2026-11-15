local _, JH = ...

local MAX_HOTS = 4
local WHITE    = "Interface\\Buttons\\WHITE8X8"
local TEX = {
  blizzard = "Interface\\TargetingFrame\\UI-StatusBar",
  raid     = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
  flat     = WHITE,
}

---------------------------------------------------------------------------
-- Look
--   bar:  "health" = green > yellow > red by health, "class" = class colour,
--         "dark" = dark bar with red where health is missing
--   name: "white" or "class"
--   tex:  "blizzard", "raid", "flat"
--   pct:  show health % (under the name on tall bars, on the right on slim bars)
--   hots: show your own HoT icons
--   inc:  show incoming heals as a lighter bar after the health
-- A theme is a preset of these plus a suggested bar size.
---------------------------------------------------------------------------
JH.THEMES = {
  healbot = { label = "Classic HealBot", bar = "health", name = "white", pct = false, tex = "blizzard", w = 100, h = 24 },
  class   = { label = "Class colours",   bar = "class",  name = "white", pct = true,  tex = "raid",     w = 90,  h = 38 },
  slim    = { label = "Slim class",      bar = "class",  name = "white", pct = false, tex = "blizzard", w = 100, h = 22 },
  dark    = { label = "Dark",            bar = "dark",   name = "class", pct = true,  tex = "flat",     w = 90,  h = 38 },
}
JH.THEME_ORDER = { "healbot", "class", "slim", "dark" }

local DEFAULT_LOOK = { bar = "health", name = "white", tex = "blizzard", pct = false, hots = true, inc = true,
                       font = "game", fontSize = 0, outline = "OUTLINE", nameLen = 0, nameAlign = "center",
                       bg = "auto", fill = "h", hotSize = 1, buffSize = 1, debuffSize = 1, marker = true, pctColor = "white", shadow = true,
                       healerIcon = true,
                       hotMax = 4, showBuffs = false, buffMax = 3,
                       showDebuffs = false, debuffs = "all", debuffMax = 3, dispel = true }
local function Look()
  return (JH.db and JH.db.look) or DEFAULT_LOOK
end

-- Midnight/Forever can hand addons "secret" values in combat. Never compare
-- or do maths on one; only pass it to widget functions that accept it.
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

-- Colour curve for health-coloured bars (works with secret health values)
local healthCurve
local function BuildCurve()
  local c = C_CurveUtil.CreateColorCurve()
  c:AddPoint(0,   CreateColor(1, 0, 0, 1))
  c:AddPoint(0.5, CreateColor(1, 0.9, 0, 1))
  c:AddPoint(1,   CreateColor(0, 0.8, 0, 1))
  return c
end
local function HealthCurve()
  if healthCurve == nil then
    healthCurve = false
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor and UnitHealthPercent then
      local ok, c = pcall(BuildCurve)
      if ok and c then healthCurve = c end
    end
  end
  return healthCurve
end
local function CurveRGB(u, curve)
  return UnitHealthPercent(u, true, curve):GetRGB()
end
local SCALE100 = CurveConstants and CurveConstants.ScaleTo100
local EASE = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

local function SetBarColor(b, r, g, bl)
  b.barTex:SetVertexColor(r, g, bl)
end

---------------------------------------------------------------------------
-- Updates. Each one is small and only runs when the game says that thing
-- changed for that unit.
---------------------------------------------------------------------------
-- Name cut to max letters (0 = whole name). Counts letters, not bytes, so å ä ö work.
local function ShortName(n, max)
  if IsSecret(n) or type(n) ~= "string" or not max or max <= 0 then return n end
  local out, count = {}, 0
  for ch in n:gmatch("[^\128-\191][\128-\191]*") do
    count = count + 1
    if count > max then return table.concat(out) end
    out[count] = ch
  end
  return n
end
JH.ShortName = ShortName

-- Colour behind the bar (the missing health)
--   auto: dark, or red with the Dark bar colour   dark / red / class (dimmed class colour)
local function ApplyBg(b, c)
  local look = Look()
  local mode = look.bg or "auto"
  if mode == "auto" then mode = (look.bar == "dark") and "red" or "dark" end
  if mode == "red" then
    b.hpbg:SetColorTexture(0.45, 0.05, 0.05, 0.9)
  elseif mode == "class" and c then
    b.hpbg:SetColorTexture(c.r * 0.3, c.g * 0.3, c.b * 0.3, 0.9)
  else
    b.hpbg:SetColorTexture(0.05, 0.05, 0.05, 0.85)
  end
end
JH.ApplyBg = ApplyBg

-- Text colours. name: white / class / yellow / grey / black
-- pctColor: white / name (same as the name) / health (green > red) / yellow
JH.NAME_COLORS = {
  { "white", "White" }, { "class", "Class colour" }, { "yellow", "Yellow" },
  { "grey", "Light grey" }, { "black", "Black" },
}
JH.PCT_COLORS = {
  { "white", "White" }, { "name", "Same as the name" }, { "health", "By health (green > red)" },
  { "yellow", "Yellow" },
}
local TEXT_RGB = { white = { 1, 1, 1 }, yellow = { 1, 0.82, 0 }, grey = { 0.75, 0.75, 0.75 }, black = { 0, 0, 0 } }

function JH.NameRGB(look, c)
  if look.name == "class" and c then return c.r, c.g, c.b end
  local t = TEXT_RGB[look.name] or TEXT_RGB.white
  return t[1], t[2], t[3]
end

-- health % colour that doesn't depend on the health (the "health" one is set in UpdateHealth)
function JH.PctRGB(look, c)
  if look.pctColor == "name" then return JH.NameRGB(look, c) end
  local t = TEXT_RGB[look.pctColor] or TEXT_RGB.white
  return t[1], t[2], t[3]
end

local function UpdateName(b)
  local u = b.unit
  if not u or not UnitExists(u) then return end
  local look = Look()
  b.name:SetText(ShortName(UnitName(u) or "", look.nameLen))
  local _, class = UnitClass(u)
  local c = class and RAID_CLASS_COLORS[class]
  b.name:SetTextColor(JH.NameRGB(look, c))
  if look.pctColor ~= "health" then b.pct:SetTextColor(JH.PctRGB(look, c)) end
  ApplyBg(b, c)
  if look.bar == "class" then
    if c then SetBarColor(b, c.r, c.g, c.b) else SetBarColor(b, 0.2, 0.8, 0.2) end
  elseif look.bar == "dark" then
    SetBarColor(b, 0.16, 0.16, 0.16)
  end
end

local function UpdateHealthColor(b, u)
  local cv = HealthCurve()
  if cv then
    local ok, r, g, bl = pcall(CurveRGB, u, cv)
    if ok and pcall(b.barTex.SetVertexColor, b.barTex, r, g, bl) then return end
  end
  local cur, max = UnitHealth(u), UnitHealthMax(u)
  if not IsSecret(cur) and not IsSecret(max) and max and max > 0 then
    local p = cur / max
    if p > 0.5 then SetBarColor(b, (1 - p) * 2, 0.8, 0) else SetBarColor(b, 1, p * 1.8, 0) end
  else
    SetBarColor(b, 0, 0.8, 0)
  end
end

-- Incoming heals: a second bar that starts where the health fill ends. It uses the
-- same 0..max health scale, so no maths is needed (works with secret values too).
local function UpdateIncoming(b, u)
  local inc = b.inc
  if not inc then return end
  if Look().inc == false or not UnitGetIncomingHeals then return inc:Hide() end
  local ok, v = pcall(UnitGetIncomingHeals, u)
  if not ok or (not IsSecret(v) and type(v) ~= "number") then return inc:Hide() end
  inc:SetMinMaxValues(0, UnitHealthMax(u))
  inc:SetValue(v)
  inc:Show()
end

local function UpdateHealth(b)
  local u = b.unit
  if not u or not UnitExists(u) then return end

  if not UnitIsConnected(u) then
    b.hp:SetMinMaxValues(0, 1); b.hp:SetValue(0)
    b.status:SetText("Offline"); b.pct:SetText("")
    if b.inc then b.inc:Hide() end
    return
  elseif UnitIsDeadOrGhost(u) then
    b.hp:SetMinMaxValues(0, 1); b.hp:SetValue(0)
    b.status:SetText("Dead"); b.pct:SetText("")
    if b.inc then b.inc:Hide() end
    return
  end
  b.status:SetText("")

  -- StatusBars accept secret values, so this works in combat too
  b.hp:SetMinMaxValues(0, UnitHealthMax(u))
  local cur = UnitHealth(u)
  if not (EASE and pcall(b.hp.SetValue, b.hp, cur, EASE)) then
    b.hp:SetValue(cur)
  end

  if Look().bar == "health" then UpdateHealthColor(b, u) end
  UpdateIncoming(b, u)

  if b.showPct then
    local ok = false
    -- Midnight: the game formats the (possibly secret) percent for us
    if UnitHealthPercent and SCALE100 then
      local ok1, v = pcall(UnitHealthPercent, u, true, SCALE100)
      if ok1 then ok = pcall(b.pct.SetFormattedText, b.pct, "%.0f%%", v) end
    end
    -- older clients: work it out ourselves when the numbers aren't secret
    if not ok then
      local c, m = UnitHealth(u), UnitHealthMax(u)
      if not IsSecret(c) and not IsSecret(m) and m and m > 0 then
        b.pct:SetFormattedText("%d%%", math.floor(c / m * 100 + 0.5))
        ok = true
      end
    end
    if not ok then b.pct:SetText("") end
    if ok and Look().pctColor == "health" then
      local cv = HealthCurve()
      local done = false
      if cv then
        local okC, r, g, bl = pcall(CurveRGB, u, cv)
        if okC then done = pcall(b.pct.SetTextColor, b.pct, r, g, bl) end
      end
      if not done then
        local c, m = UnitHealth(u), UnitHealthMax(u)
        if not IsSecret(c) and not IsSecret(m) and m and m > 0 then
          local p = c / m
          if p > 0.5 then b.pct:SetTextColor((1 - p) * 2, 1, 0) else b.pct:SetTextColor(1, p * 2, 0) end
        else
          b.pct:SetTextColor(1, 1, 1)
        end
      end
    end
  end
end

-- Icons on the bars. Three kinds, each can be turned off (and capped) in the options:
--   b.icons       your own HoTs     tall: bottom left   slim: from the right edge
--   b.buffIcons   buffs (not HoTs)  tall: bottom right  slim: right, after the HoTs
--   b.debuffIcons debuffs           tall: top right     slim: left, after the raid marker
-- b.nHots / b.nBuffs / b.nDebuffs say how many of each are showing.

-- Where the text and the buff/debuff icons go, given what is showing.
local function PlaceText(b)
  local hstep = (b.iconSize or 10) + 1          -- HoT icons
  local bstep = (b.buffSize or b.iconSize or 10) + 1
  local dstep = (b.debuffSize or b.iconSize or 10) + 1
  local ms = b.markerShown and ((b.markerSize or 10) + 1) or 0
  -- healer icon right after the raid marker; both count as "left side" space
  if b.role then
    b.role:ClearAllPoints()
    if b.slim then b.role:SetPoint("LEFT", 2 + ms, 0) else b.role:SetPoint("TOPLEFT", 2 + ms, -2) end
    if b.roleShown then ms = ms + (b.markerSize or 10) + 1 end
  end
  if b.tankTag then
    b.tankTag:ClearAllPoints()
    if b.slim then b.tankTag:SetPoint("LEFT", 3 + ms, 0) else b.tankTag:SetPoint("TOPLEFT", 3 + ms, -2) end
    if b.tagShown then ms = ms + math.ceil(b.tankTag:GetStringWidth() or 12) + 3 end
  end
  local nh, nb, nd = b.nHots or 0, b.nBuffs or 0, b.nDebuffs or 0
  b.name:ClearAllPoints()
  if b.slim then
    for i, ic in ipairs(b.buffIcons) do
      ic:ClearAllPoints(); ic:SetPoint("RIGHT", -2 - nh * hstep - (i - 1) * bstep, 0)
    end
    for i, ic in ipairs(b.debuffIcons) do
      ic:ClearAllPoints(); ic:SetPoint("LEFT", 2 + ms + (i - 1) * dstep, 0)
    end
    local right = nh * hstep + nb * bstep
    b.pct:ClearAllPoints();    b.pct:SetPoint("RIGHT", -(3 + right), 0)
    b.status:ClearAllPoints(); b.status:SetPoint("RIGHT", -(3 + right), 0)
    local text = b.showPct and (b.pctWidth or 24) or 0
    b.name:SetPoint("LEFT", 3 + ms + nd * dstep, 0)
    b.name:SetPoint("RIGHT", -(3 + right + text), 0)
  else
    for i, ic in ipairs(b.buffIcons) do
      ic:ClearAllPoints(); ic:SetPoint("BOTTOMRIGHT", -2 - (i - 1) * bstep, 2)
    end
    for i, ic in ipairs(b.debuffIcons) do
      ic:ClearAllPoints(); ic:SetPoint("TOPRIGHT", -2 - (i - 1) * dstep, -2)
    end
    local y = -math.max(2, (b:GetHeight() or 30) * 0.08)
    b.name:SetPoint("TOPLEFT", 3 + ms, y)
    b.name:SetPoint("TOPRIGHT", -(3 + nd * dstep), y)
  end
end
JH.PlaceText = PlaceText

-- Re-place only when what is showing changed (aura updates come often)
local function PlaceIcons(b)
  local key = (b.nHots or 0) * 100 + (b.nBuffs or 0) * 10 + (b.nDebuffs or 0) + (b.markerShown and 1000 or 0)
              + (b.roleShown and 2000 or 0) + (b.tagShown and 4000 or 0)
  if b.placedKey == key then return end
  b.placedKey = key
  PlaceText(b)
end
JH.PlaceIcons = PlaceIcons

-- Raid target marker (skull, star ...) on the left of the bar
local function UpdateMarker(b)
  local m = b.marker
  if not m then return end
  local idx = Look().marker ~= false and b.unit and GetRaidTargetIndex and GetRaidTargetIndex(b.unit)
  local show = idx and not IsSecret(idx) and SetRaidTargetIconTexture and true or false
  if show then SetRaidTargetIconTexture(m, idx) end
  m:SetShown(show)
  b.markerShown = show
  PlaceIcons(b)
end

-- Small healer icon (role chosen in the group), when in a group. Toggle: look.healerIcon.
local function SetHealerTexture(t)
  if t.jhSet then return end
  t.jhSet = true
  if t.SetAtlas and pcall(t.SetAtlas, t, "roleicon-tiny-healer") then return end
  t:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
  if GetTexCoordsForRoleSmallCircle then
    pcall(function() t:SetTexCoord(GetTexCoordsForRoleSmallCircle("HEALER")) end)
  else
    t:SetTexCoord(20 / 64, 39 / 64, 1 / 64, 20 / 64)
  end
end
JH.SetHealerTexture = SetHealerTexture

local function UpdateRole(b)
  local r = b.role
  if not r then return end
  local show = false
  if Look().healerIcon ~= false and b.unit and IsInGroup() and UnitGroupRolesAssigned then
    local ok, role = pcall(UnitGroupRolesAssigned, b.unit)
    show = ok and not IsSecret(role) and role == "HEALER"
  end
  if show then SetHealerTexture(r) end
  r:SetShown(show)
  b.roleShown = show
  PlaceIcons(b)
end

local function SetAuraIcon(ic, u, aura)
  pcall(ic.tex.SetTexture, ic.tex, aura.icon)
  local cdOk = false
  if C_UnitAuras.GetAuraDuration and ic.cd.SetCooldownFromDurationObject then
    local okD, dur = pcall(C_UnitAuras.GetAuraDuration, u, aura.auraInstanceID)
    if okD and dur then cdOk = pcall(ic.cd.SetCooldownFromDurationObject, ic.cd, dur) end
  end
  if not cdOk then
    local exp, d = aura.expirationTime, aura.duration
    -- check for secret values BEFORE any test: even "if d then" fails on a secret in combat
    if not IsSecret(exp) and not IsSecret(d) and type(exp) == "number" and type(d) == "number" and d > 0 then
      ic.cd:SetCooldown(exp - d, d)
    else
      ic.cd:Clear()
    end
  end
  ic:Show()
end

-- Put up to max auras from list on the icons (skip = auraInstanceIDs to leave out)
local function FillIcons(list, icons, max, u, skip)
  local n = 0
  if type(list) ~= "table" then return 0 end
  max = math.min(max or 0, #icons)
  for i = 1, #list do
    if n >= max then break end
    local a = list[i]
    if type(a) == "table" then
      local id = a.auraInstanceID
      local skipIt = skip and not IsSecret(id) and id ~= nil and skip[id]
      if not skipIt then
        n = n + 1
        SetAuraIcon(icons[n], u, a)
      end
    end
  end
  return n
end
-- Is this one of your auras a HoT (or a short helpful effect like Ironbark)?
-- Known HoT names first; else anything that lasts 60 seconds or less. In combat the
-- name and duration can be secret: then the answer from before is reused (by aura
-- instance), and a brand new unreadable aura counts as a HoT (that's what you cast in combat).
local HOT_NAMES = {}
for _, n in ipairs({
  "Rejuvenation", "Rejuvenation (Germination)", "Germination", "Regrowth", "Lifebloom", "Wild Growth",
  "Cenarion Ward", "Spring Blossoms", "Tranquility", "Adaptive Swarm", "Grove Tending",
  "Renew", "Prayer of Mending", "Power Word: Shield", "Echo of Light", "Atonement", "Holy Word: Salvation",
  "Riptide", "Earth Shield", "Healing Rain", "Unleash Life",
  "Renewing Mist", "Enveloping Mist", "Soothing Mist", "Essence Font", "Zen Pulse",
  "Reversion", "Echo", "Dream Breath", "Lifebind", "Verdant Embrace", "Time Dilation",
  "Beacon of Light", "Beacon of Faith", "Beacon of Virtue", "Glimmer of Light", "Blessing of Sacrifice",
  "Ironbark", "Pain Suppression", "Guardian Spirit", "Life Cocoon", "Blessing of Protection",
}) do HOT_NAMES[n] = true end
local hotCache = {}

function JH.IsHot(a)
  -- every value is checked with IsSecret BEFORE it is tested or used as a table key
  local id = a.auraInstanceID
  local idOk = not IsSecret(id) and id ~= nil
  if idOk and hotCache[id] ~= nil then return hotCache[id] end
  local res
  local n, d = a.name, a.duration
  local nOk = not IsSecret(n) and type(n) == "string"
  local dOk = not IsSecret(d) and type(d) == "number"
  if nOk and HOT_NAMES[n] then
    res = true
  elseif dOk then
    res = d > 0 and d <= 60
  elseif nOk then
    res = false            -- readable name, not a known HoT
  else
    return true            -- nothing readable: show it (don't cache)
  end
  if idOk then hotCache[id] = res end
  return res
end

-- Auras on a unit for a filter. C_UnitAuras.GetUnitAuras first; if that fails or comes back
-- empty (it can in combat), ask aura by aura with GetAuraDataByIndex.
local function GetAuras(u, filter, max)
  local out
  if C_UnitAuras.GetUnitAuras then
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, u, filter, max)
    if ok and type(list) == "table" then out = list end
  end
  if (not out or #out == 0) and C_UnitAuras.GetAuraDataByIndex then
    local list = {}
    for i = 1, max do
      local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, u, i, filter)
      if not ok or type(a) ~= "table" then break end
      list[#list + 1] = a
    end
    if #list > 0 then out = list end
  end
  return out or {}
end
JH.GetAuras = GetAuras

local function Count(v, default)
  v = tonumber(v)
  if not v then return default end
  return math.max(0, math.min(MAX_HOTS, math.floor(v)))
end

local function UpdateAuras(b)
  local u = b.unit
  local look = Look()
  local nh, nb, nd = 0, 0, 0
  if u and UnitExists(u) and C_UnitAuras and (C_UnitAuras.GetUnitAuras or C_UnitAuras.GetAuraDataByIndex) then
    local hotMax = look.hots ~= false and Count(look.hotMax, MAX_HOTS) or 0
    local buffMax = look.showBuffs and Count(look.buffMax, 3) or 0
    local debuffMax = look.showDebuffs and Count(look.debuffMax, 3) or 0

    -- your own auras: HoTs go on the HoT icons, the rest (Arcane Intellect, armour ...)
    -- count as buffs and only show when Buffs is on
    local hotIDs = {}
    if hotMax > 0 or buffMax > 0 then
      local list = GetAuras(u, "HELPFUL|PLAYER", 40)
      local hots = {}
      for _, a in ipairs(list) do
        if JH.IsHot(a) then
          hots[#hots + 1] = a
          local id = a.auraInstanceID
          if not IsSecret(id) and id ~= nil then hotIDs[id] = true end
        end
      end
      if hotMax > 0 then nh = FillIcons(hots, b.icons, hotMax, u) end
    end
    -- buffs: everything helpful that isn't one of your HoTs (yours and other players')
    if buffMax > 0 then
      nb = FillIcons(GetAuras(u, "HELPFUL", 40), b.buffIcons, buffMax, u, hotIDs)
    end
    -- debuffs: all of them, or only the ones you can dispel
    if debuffMax > 0 then
      local filter = look.debuffs == "all" and "HARMFUL" or "HARMFUL|RAID_PLAYER_DISPELLABLE"
      nd = FillIcons(GetAuras(u, filter, debuffMax), b.debuffIcons, debuffMax, u)
    end
    -- debuff you can dispel -> coloured border
    if look.dispel ~= false then
      b.dispel:SetShown(#GetAuras(u, "HARMFUL|RAID_PLAYER_DISPELLABLE", 1) > 0)
    else
      b.dispel:Hide()
    end
  else
    b.dispel:Hide()
  end
  for i = nh + 1, MAX_HOTS do b.icons[i]:Hide() end
  for i = nb + 1, MAX_HOTS do b.buffIcons[i]:Hide() end
  for i = nd + 1, MAX_HOTS do b.debuffIcons[i]:Hide() end
  b.nHots, b.nBuffs, b.nDebuffs = nh, nb, nd
  PlaceIcons(b)
end

local function UpdateTarget(b)
  b.sel:SetShown(b.unit and UnitExists(b.unit) and UnitIsUnit(b.unit, "target") or false)
end

---------------------------------------------------------------------------
-- Range. The game tells us when someone goes in or out of range
-- (UNIT_IN_RANGE_UPDATE); a slow check twice a second is only a safety net.
-- Alpha is only touched when it actually changes.
---------------------------------------------------------------------------
local function ApplyRange(b, inRange, checked)
  local fade = (JH.db and JH.db.rangeAlpha) or 0.4
  if IsSecret(inRange) or IsSecret(checked) then
    -- can't look at the value in combat, but the game can apply it for us
    if b.SetAlphaFromBoolean then pcall(b.SetAlphaFromBoolean, b, inRange, 1, fade) end
    b.alphaState = nil
    return
  end
  local a = (checked and not inRange) and fade or 1
  if b.alphaState ~= a then
    b.alphaState = a
    b:SetAlpha(a)
  end
end

local function UpdateRange(b)
  local u = b.unit
  if not u then return end
  if UnitIsUnit(u, "player") then return ApplyRange(b, true, true) end
  local ok, inRange, checked = pcall(UnitInRange, u)
  if ok then ApplyRange(b, inRange, checked) end
end

function JH.UpdateButton(b)
  if not b.unit or not UnitExists(b.unit) then return end
  UpdateName(b); UpdateHealth(b); UpdateAuras(b); UpdateTarget(b); UpdateRange(b); UpdateMarker(b); UpdateRole(b)
end
JH.UpdateMarker = UpdateMarker

---------------------------------------------------------------------------
-- Per-frame events: every bar only listens to its own unit, so nothing runs
-- for nameplates, enemies or people outside the group.
---------------------------------------------------------------------------
local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA", "UNIT_CONNECTION",
                      "UNIT_NAME_UPDATE", "UNIT_IN_RANGE_UPDATE", "UNIT_HEAL_PREDICTION" }
local auraDirty = {}

local function Button_OnEvent(b, event, _, arg2)
  if not b:IsVisible() then return end
  if event == "UNIT_AURA" then
    auraDirty[b] = true            -- many aura events in a row become one update
  elseif event == "UNIT_IN_RANGE_UPDATE" then
    ApplyRange(b, arg2, true)
  elseif event == "UNIT_NAME_UPDATE" then
    UpdateName(b)
  else
    UpdateHealth(b)
  end
end

local function SetUnit(b, unit)
  if b.unit ~= unit then
    b.unit = unit
    b:UnregisterAllEvents()
    if unit then
      for _, e in ipairs(UNIT_EVENTS) do pcall(b.RegisterUnitEvent, b, e, unit) end
    end
  end
  b.alphaState = nil
  if unit then JH.UpdateButton(b) end
end

---------------------------------------------------------------------------
-- Look + layout inside a bar: text and icons scale with the bar size
---------------------------------------------------------------------------
local FONT = (GameFontHighlightSmall and GameFontHighlightSmall:GetFont()) or "Fonts\\FRIZQT__.TTF"

-- Fonts that come with the game. "game" = the normal UI font (right for every language).
JH.FONTS = {
  { "game",     "Game font" },
  { "friz",     "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
  { "arial",    "Arial Narrow",  "Fonts\\ARIALN.TTF" },
  { "skurri",   "Skurri",        "Fonts\\skurri.ttf" },
  { "morpheus", "Morpheus",      "Fonts\\MORPHEUS.TTF" },
}
local FONT_PATH = {}
for _, f in ipairs(JH.FONTS) do FONT_PATH[f[1]] = f[3] end

local function FontFlags(look)
  local o = look.outline or "OUTLINE"
  if o == "NONE" then return "" end
  return o
end

function JH.LayoutButton(b)
  local w, h = b:GetSize()
  if not w or not h or h <= 0 or w <= 0 then return end
  local look = Look()
  local tall = h >= 30
  local vert = look.fill == "v"
  b.slim = not tall
  b.showPct = look.pct and true or false
  b.placedKey = nil
  if b.inc then
    if vert then b.inc:SetHeight(math.max(1, h - 2)) else b.inc:SetWidth(math.max(1, w - 2)) end
  end

  -- text size: automatic from the bar height, or the size picked in the options
  local fs = math.max(7, math.min(18, math.floor((tall and h * 0.27 or h * 0.5) + 0.5)))
  if (tonumber(look.fontSize) or 0) > 0 then fs = math.max(6, math.min(30, look.fontSize)) end
  local font, flags = FONT_PATH[look.font] or FONT, FontFlags(look)
  if not b.name:SetFont(font, fs, flags) then b.name:SetFont(FONT, fs, flags); font = FONT end
  b.pct:SetFont(font, math.max(6, fs - 1), flags)
  if b.tankTag then b.tankTag:SetFont(font, math.max(6, fs - 1), flags) end
  b.status:SetFont(font, fs, flags)
  b.name:SetJustifyH(look.nameAlign == "left" and "LEFT" or "CENTER")
  -- a dark shadow behind the text makes it readable on any bar colour
  for _, f in ipairs({ b.name, b.pct, b.status }) do
    if look.shadow ~= false then
      f:SetShadowColor(0, 0, 0, 1); f:SetShadowOffset(1, -1)
    else
      f:SetShadowOffset(0, 0)
    end
  end
  b.pctWidth = math.floor(math.max(6, fs - 1) * 2.4 + 2) -- room for "100%"

  b.markerSize = math.max(8, math.min(fs + 2, h - 4))
  if b.role then b.role:SetSize(b.markerSize, b.markerSize) end
  if b.marker then
    b.marker:SetSize(b.markerSize, b.markerSize); b.marker:ClearAllPoints()
    if tall then b.marker:SetPoint("TOPLEFT", 2, -2) else b.marker:SetPoint("LEFT", 2, 0) end
  end

  -- icon sizes: a base size from the bar, times the size picked for each kind
  local function Mult(v) return math.max(0.5, math.min(2, tonumber(v) or 1)) end
  local base = tall and math.min(h * 0.32, h - 4) or math.min(h - 6, w * 0.13)
  local maxSize = tall and (h - 4) or (h - 2)
  local function Size(mult) return math.max(6, math.floor(math.min(base * mult, maxSize))) end
  local hs, bs, ds = Size(Mult(look.hotSize)), Size(Mult(look.buffSize)), Size(Mult(look.debuffSize))
  if tall then
    -- HoTs and buffs share the bottom row: shrink both if they wouldn't fit side by side
    local nh = look.hots ~= false and (tonumber(look.hotMax) or MAX_HOTS) or 0
    local nb = look.showBuffs and (tonumber(look.buffMax) or 3) or 0
    local need = nh * (hs + 1) + nb * (bs + 1)
    if need > w - 6 and need > 0 then
      local f = (w - 6) / need
      hs = math.max(6, math.floor(hs * f)); bs = math.max(6, math.floor(bs * f))
    end
  end

  b.pct:ClearAllPoints(); b.status:ClearAllPoints()
  if tall then
    -- name on top, % under it, HoT icons along the bottom
    b.pct:SetPoint("TOP", b.name, "BOTTOM", 0, -1)
    b.status:SetPoint("TOP", b.name, "BOTTOM", 0, -1)
    for i, ic in ipairs(b.icons) do
      ic:SetSize(hs, hs); ic:ClearAllPoints()
      ic:SetPoint("BOTTOMLEFT", 2 + (i - 1) * (hs + 1), 2)
    end
  else
    -- slim bar: name in the middle, HoT icons stacked from the right edge
    b.pct:SetPoint("RIGHT", -3, 0)
    b.status:SetPoint("RIGHT", -3, 0)
    for i, ic in ipairs(b.icons) do
      ic:SetSize(hs, hs); ic:ClearAllPoints()
      ic:SetPoint("RIGHT", -2 - (i - 1) * (hs + 1), 0)
    end
  end
  b.iconSize, b.buffSize, b.debuffSize = hs, bs, ds
  for _, ic in ipairs(b.buffIcons) do ic:SetSize(bs, bs) end
  for _, ic in ipairs(b.debuffIcons) do ic:SetSize(ds, ds) end
  PlaceText(b)
  if not b.showPct then b.pct:SetText("") end
end

function JH.StyleButton(b)
  local look = Look()
  local vert = look.fill == "v"
  local orient = vert and "VERTICAL" or "HORIZONTAL"
  b.hp:SetStatusBarTexture(TEX[look.tex] or TEX.blizzard)
  b.hp:SetOrientation(orient)
  b.barTex = b.hp:GetStatusBarTexture()
  if b.inc then
    b.inc:SetStatusBarTexture(TEX[look.tex] or TEX.blizzard)
    b.inc:SetStatusBarColor(0.3, 1, 0.5, 0.55)
    b.inc:SetOrientation(orient)
    b.inc:ClearAllPoints()
    if vert then
      -- fills upwards: incoming heals sit on top of the health
      b.inc:SetPoint("BOTTOMLEFT", b.barTex, "TOPLEFT")
      b.inc:SetPoint("BOTTOMRIGHT", b.barTex, "TOPRIGHT")
      b.inc:SetHeight(math.max(1, (b:GetHeight() or 2) - 2))
    else
      b.inc:SetPoint("TOPLEFT", b.barTex, "TOPRIGHT")
      b.inc:SetPoint("BOTTOMLEFT", b.barTex, "BOTTOMRIGHT")
      b.inc:SetWidth(math.max(1, (b:GetWidth() or 2) - 2))
    end
    if look.inc == false then b.inc:Hide() end
  end
  ApplyBg(b, nil)
  JH.LayoutButton(b)
  if b.unit and UnitExists(b.unit) then JH.UpdateButton(b) else SetBarColor(b, 0, 0.8, 0) end
end

function JH.ApplyTheme()
  for b in pairs(JH.buttons) do JH.StyleButton(b) end
  if JH.RefreshTest then JH.RefreshTest() end
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
-- Bar visuals (shared by the real bars and the test bars)
---------------------------------------------------------------------------
function JH.BuildVisuals(self)
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
  self.barTex = hp:GetStatusBarTexture()
  if hp.SetClipsChildren then pcall(hp.SetClipsChildren, hp, true) end -- incoming bar stops at the edge

  -- incoming heals: starts where the health fill ends (anchored in StyleButton)
  local inc = CreateFrame("StatusBar", nil, hp)
  inc:SetFrameLevel(hp:GetFrameLevel() + 1)
  inc:SetStatusBarTexture(TEX.blizzard)
  inc:SetStatusBarColor(0.3, 1, 0.5, 0.55)
  inc:SetMinMaxValues(0, 1); inc:SetValue(0)
  inc:Hide()
  self.inc = inc

  -- text sits on its own layer above the incoming-heal bar
  local text = CreateFrame("Frame", nil, hp)
  text:SetAllPoints()
  text:SetFrameLevel(hp:GetFrameLevel() + 3)
  self.textLayer = text

  local marker = text:CreateTexture(nil, "OVERLAY")
  marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  marker:SetSize(10, 10); marker:SetPoint("LEFT", 2, 0)
  marker:Hide()
  self.marker = marker

  local role = text:CreateTexture(nil, "OVERLAY")
  role:SetSize(10, 10); role:SetPoint("LEFT", 2, 0)
  role:Hide()
  self.role = role

  -- "MT" / "OT" on tank bars, left of the name (gold, like Blizzard's raid frames)
  local tag = text:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  tag:SetTextColor(1, 0.82, 0)
  tag:Hide()
  self.tankTag = tag

  local name = text:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  name:SetPoint("LEFT", 3, 0); name:SetPoint("RIGHT", -3, 0)
  name:SetWordWrap(false)
  self.name = name

  local pct = text:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pct:SetPoint("RIGHT", -3, 0)
  self.pct = pct

  local status = text:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  status:SetPoint("RIGHT", -3, 0)
  status:SetTextColor(1, 0.3, 0.3)
  self.status = status

  -- icon pools: your HoTs, other buffs, debuffs (debuffs get a red edge)
  local function Icon(edge)
    local ic = CreateFrame("Frame", nil, hp)
    ic:SetFrameLevel(hp:GetFrameLevel() + 4)
    ic:SetSize(10, 10)
    if edge then
      ic.edge = ic:CreateTexture(nil, "BACKGROUND")
      ic.edge:SetPoint("TOPLEFT", -1, 1); ic.edge:SetPoint("BOTTOMRIGHT", 1, -1)
      ic.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
    end
    ic.tex = ic:CreateTexture(nil, "ARTWORK"); ic.tex:SetAllPoints()
    ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ic.cd = CreateFrame("Cooldown", nil, ic, "CooldownFrameTemplate")
    ic.cd:SetAllPoints(); ic.cd:SetReverse(true)
    if ic.cd.SetHideCountdownNumbers then ic.cd:SetHideCountdownNumbers(true) end
    ic:Hide()
    return ic
  end
  self.icons, self.buffIcons, self.debuffIcons = {}, {}, {}
  for i = 1, MAX_HOTS do
    self.icons[i] = Icon()
    self.icons[i]:SetPoint("RIGHT", -2 - (i - 1) * 11, 0)
    self.buffIcons[i] = Icon()
    self.debuffIcons[i] = Icon({ 0.8, 0.1, 0.1 })
  end

  self.sel    = MakeBorder(self, 1, 1, 1, 1)          -- your current target
  self.dispel = MakeBorder(self, 2, 0.9, 0.2, 0.9)    -- dispellable debuff
  self.hl = self:CreateTexture(nil, "HIGHLIGHT")
  self.hl:SetAllPoints(); self.hl:SetColorTexture(1, 1, 1, 0.15)

end

-- Errors inside a bar are caught here: the first one is printed in chat and kept
-- for /fh debug, instead of silently leaving an empty, invisible bar.
local function BarError(what, err)
  if JH.barError then return end
  JH.barError = what .. ": " .. tostring(err)
  JH.lastError = JH.barError
  if JH.Print then JH.Print("|cffff5555Error|r in a bar (" .. JH.barError .. "). Please report it.") end
end

function FaithHeals_UnitOnLoad(self)
  JH.buttons[self] = true
  local ok, err = pcall(JH.BuildVisuals, self)
  if not ok then return BarError("making a bar", err) end
  pcall(self.RegisterForClicks, self, "AnyUp", "AnyDown") -- both: see ClickType in Core.lua

  self:SetScript("OnAttributeChanged", function(s, attr, value)
    if attr == "unit" then
      JH.tankDirty = true
      local okU, errU = pcall(SetUnit, s, value)
      if not okU then BarError("showing " .. tostring(value), errU) end
    end
  end)
  self:SetScript("OnEvent", Button_OnEvent)
  self:HookScript("OnClick", function(s, button, down) JH.BarPostClick(s, button, down) end)
  self:SetScript("OnEnter", function(s) JH.ShowTooltip(s) end)
  self:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self:SetScript("OnShow", function(s) JH.LayoutButton(s); JH.UpdateButton(s) end)
  self:SetScript("OnHide", function(s) auraDirty[s] = nil end)
  self:SetScript("OnSizeChanged", function(s) JH.LayoutButton(s) end)
  if JH.db then
    local okS, errS = pcall(JH.StyleButton, self)
    if not okS then BarError("styling a bar", errS) end
  end
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

---------------------------------------------------------------------------
-- Layouts: each group size has its own bar size and number of columns.
-- Party and raid each get their own secure header (the player always shows
-- in the party one, and raids are grouped by raid group).
---------------------------------------------------------------------------
JH.LAYOUTS = {
  { id = "solo",   label = "Solo",    units = 1 },
  { id = "party",  label = "Party",   units = 5 },
  { id = "raid10", label = "Raid 10", units = 10 },
  { id = "raid20", label = "Raid 20", units = 20 },
  { id = "raid25", label = "Raid 25", units = 25 },
  { id = "raid40", label = "Raid 40", units = 40 },
}
local LAYOUT_BY_ID = {}
for _, l in ipairs(JH.LAYOUTS) do LAYOUT_BY_ID[l.id] = l end
JH.LAYOUT_BY_ID = LAYOUT_BY_ID

-- The layout for n players (also used for test bars)
function JH.LayoutForCount(n)
  if n <= 1 then return "solo" elseif n <= 5 then return "party"
  elseif n <= 10 then return "raid10" elseif n <= 20 then return "raid20"
  elseif n <= 25 then return "raid25" end
  return "raid40"
end

-- The layout for the group you are in now
function JH.GroupLayout()
  if IsInRaid() then return JH.LayoutForCount(math.max(6, GetNumGroupMembers())) end
  if IsInGroup() then return "party" end
  return "solo"
end

-- Pick the layout to use now (the test bars' size while they are shown)
function JH.ChooseLayout()
  JH.active = JH.testCount and JH.LayoutForCount(JH.testCount) or JH.GroupLayout()
  return JH.active
end

function JH.Size(id)
  return JH.db.sizes[id or JH.active or "party"] or JH.defaults.sizes.party
end

function JH.BarSize()
  local s = JH.Size()
  return s.w, s.h
end

-- Bars per column (or per row), and the number of columns, for a layout
function JH.PerColumn(id)
  local l = LAYOUT_BY_ID[id or JH.active or "party"] or LAYOUT_BY_ID.party
  local cols = math.max(1, math.min(l.units, tonumber(JH.Size(l.id).cols) or 1))
  return math.ceil(l.units / cols), cols
end

function JH.ActiveHeader()
  return IsInRaid() and JH.raidHeader or JH.partyHeader
end

-- Resize every frame live (out of combat). The saved size is applied to new
-- frames through ApplyAll when the drag ends.
function JH.SetButtonSize(w, h)
  if InCombatLockdown() then return end
  local s = JH.Size()
  s.w = math.floor(math.max(30, math.min(300, w)) + 0.5)
  s.h = math.floor(math.max(12, math.min(150, h)) + 0.5)
  for b in pairs(JH.buttons) do b:SetSize(s.w, s.h) end
  local hdr = JH.ActiveHeader()
  hdr:SetAttribute("unitsPerColumn", hdr:GetAttribute("unitsPerColumn")) -- re-layout
  if JH.RefreshTest then JH.RefreshTest() end
  if JH.RefreshConfig then JH.RefreshConfig() end
end

function JH.SetScale(s)
  if InCombatLockdown() then return end
  JH.db.scale = math.floor(math.max(0.5, math.min(2, s)) * 100 + 0.5) / 100
  for _, h in ipairs(JH.headers) do h:SetScale(JH.db.scale) end
  if JH.RefreshTest then JH.RefreshTest() end
  if JH.RefreshConfig then JH.RefreshConfig() end
end

-- columns, rows currently on screen (used so the resize handle follows the mouse)
local function CountLayout()
  local n = JH.testCount or 0
  if n == 0 then
    for b in pairs(JH.buttons) do if b:IsVisible() then n = n + 1 end end
  end
  n = math.max(1, n)
  local per = JH.PerColumn()
  local along, across = math.min(n, per), math.ceil(n / per)
  if JH.db.layout.grow == "right" then return along, across end
  return across, along
end

function JH.AnchorGrip(frame)
  JH.grip:ClearAllPoints()
  JH.grip:SetPoint("TOPLEFT", frame, "BOTTOMRIGHT", -4, 4)
end

local function CreateGrip()
  local g = CreateFrame("Button", "FaithHealsResizeGrip", UIParent)
  g:SetSize(16, 16)
  g:SetFrameStrata("HIGH")
  g:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  g:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  g:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  g:EnableMouseWheel(true)
  g:Hide()

  local function Drag(s)
    local d = s.drag
    local cx, cy = GetCursorPosition()
    JH.SetButtonSize(d.w + (cx - d.x) / d.es / d.cols, d.h + (d.y - cy) / d.es / d.rows)
  end
  g:SetScript("OnMouseDown", function(self)
    if InCombatLockdown() then return end
    local x, y = GetCursorPosition()
    local cols, rows = CountLayout()
    local w, h = JH.BarSize()
    self.drag = { x = x, y = y, w = w, h = h, cols = cols, rows = rows,
                  es = JH.partyHeader:GetEffectiveScale() }
    self:SetScript("OnUpdate", Drag)
  end)
  g:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil)
    if self.drag then self.drag = nil; JH.ApplyAll(true) end  -- ApplyAll waits for combat to end
  end)
  g:SetScript("OnMouseWheel", function(_, delta) JH.SetScale((JH.db.scale or 1) + delta * 0.05) end)
  g:SetScript("OnEnter", function(self)
    local l = LAYOUT_BY_ID[JH.active or "party"]
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("FaithHeals - " .. (l and l.label or ""))
    GameTooltip:AddLine("Drag: resize the bars for this group size", 1, 1, 1)
    GameTooltip:AddLine("Mouse wheel: scale everything", 1, 1, 1)
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return g
end

---------------------------------------------------------------------------
-- Group headers (handled securely by Blizzard's template)
---------------------------------------------------------------------------
local function NewHeader(name, maxUnits)
  local h = CreateFrame("Frame", name, UIParent, "SecureGroupHeaderTemplate")
  h:SetPoint("TOPLEFT", JH.mover, "BOTTOMLEFT", 0, -2)
  h:SetAttribute("template", "FaithHealsUnitTemplate")
  h:SetAttribute("templateType", "Button")
  h.maxUnits = maxUnits
  h:Hide() -- shown from ApplyAll once click attributes and layout are in place
  return h
end

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
  -- The bars hang on the mover, so it is protected in combat: StopMovingOrSizing there is
  -- blocked. A drag still going when combat starts is finished on PLAYER_REGEN_DISABLED
  -- (just before the lockdown), and a mouse-up in combat then does nothing.
  local function StopMove(s)
    if not s.moving then return end
    s.moving = false
    s:StopMovingOrSizing()
    local p, _, rp, x, y = s:GetPoint()
    JH.db.pos = { p, rp, x, y }
  end
  mover:SetScript("OnDragStart", function(s)
    if InCombatLockdown() then return end
    s.moving = true
    s:StartMoving()
  end)
  mover:SetScript("OnDragStop", function(s)
    if InCombatLockdown() then return end
    StopMove(s)
  end)
  mover:RegisterEvent("PLAYER_REGEN_DISABLED")
  mover:SetScript("OnEvent", function(s)
    StopMove(s)
    if JH.grip and JH.grip.drag then  -- a resize still going: stop it too
      JH.grip:SetScript("OnUpdate", nil)
      JH.grip.drag = nil
    end
  end)
  JH.mover = mover
  JH.PlaceHeader()

  -- Solo and party: you + party1-4. Raid: raid1-40 by raid group.
  JH.partyHeader = NewHeader("FaithHealsParty", 5)
  JH.partyHeader:SetAttribute("showParty", true)
  JH.partyHeader:SetAttribute("showRaid", false)
  JH.raidHeader = NewHeader("FaithHealsRaid", 40)
  JH.raidHeader:SetAttribute("showRaid", true)
  JH.raidHeader:SetAttribute("showParty", false)
  JH.raidHeader:SetAttribute("showSolo", false)
  JH.raidHeader:SetAttribute("showPlayer", true)
  JH.headers = { JH.partyHeader, JH.raidHeader }
  JH.grip = CreateGrip()
  JH.AnchorGrip(JH.partyHeader)
end

local function Arrange(h, per, cols, sp, grow)
  h:SetAttribute("columnSpacing", sp + 1)
  h:SetAttribute("maxColumns", cols)
  if grow == "right" then
    -- rows: bars go left to right, new rows below
    h:SetAttribute("xOffset", sp)
    h:SetAttribute("yOffset", 0)
    h:SetAttribute("columnAnchorPoint", "TOP")
    h:SetAttribute("point", "LEFT")
  else
    -- columns: bars go top to bottom, new columns to the right
    h:SetAttribute("xOffset", 0)
    h:SetAttribute("yOffset", -sp)
    h:SetAttribute("columnAnchorPoint", "LEFT")
    h:SetAttribute("point", "TOP")
  end
  h:SetAttribute("unitsPerColumn", per) -- last: triggers the final re-layout
end

local function Sorting(h, sort, raid, tanksTop)
  -- Every SetAttribute makes the header re-sort at once, so the order matters:
  -- groupingOrder BEFORE groupBy when grouping (Blizzard's code reads it as soon as
  -- groupBy is set and errors on nil), and groupBy cleared BEFORE groupingOrder.
  local by, order, method
  if tanksTop then
    -- players with the tank role first, then everyone else (by role if sorting by role)
    by, order = "ASSIGNEDROLE", (sort == "role") and "TANK,HEALER,DAMAGER,NONE" or "TANK"
    method = (sort == "name" or sort == "role") and "NAME" or "INDEX"
  elseif sort == "role" then
    by, order, method = "ASSIGNEDROLE", "TANK,HEALER,DAMAGER,NONE", "NAME"
  elseif sort == "group" and raid then
    by, order, method = "GROUP", "1,2,3,4,5,6,7,8", "INDEX"
  else
    by, order, method = nil, nil, (sort == "name") and "NAME" or "INDEX"
  end
  if by then
    h:SetAttribute("groupingOrder", order)
    h:SetAttribute("groupBy", by)
  else
    h:SetAttribute("groupBy", nil)
    h:SetAttribute("groupingOrder", nil)
  end
  h:SetAttribute("sortMethod", method)
end

-- Tanks on top: in the same frame as everyone else, players with the tank role come
-- first. "MT" / "OT" on their bars: Main Tank / Main Assist set by the raid leader win,
-- otherwise the first tank is MT and the others OT.
local function Assigned(u, what)
  return GetPartyAssignment and GetPartyAssignment(what, u) and true or false
end

local function IsTank(u)
  if Assigned(u, "MAINTANK") or Assigned(u, "MAINASSIST") then return true end
  local ok, role = pcall(UnitGroupRolesAssigned, u)
  return ok and not IsSecret(role) and role == "TANK"
end

function JH.UpdateTankLabels()
  JH.tankDirty = false
  local on = JH.db and JH.db.layout.tanksTop ~= false
  local hdr = JH.ActiveHeader and JH.ActiveHeader()
  local tags, tanks, hasMT = {}, {}, false
  if on and hdr and IsInGroup() then
    for i = 1, hdr.maxUnits or 40 do
      local b = hdr:GetAttribute("child" .. i)
      if not b then break end
      if b.unit and b:IsShown() and UnitExists(b.unit) and IsTank(b.unit) then
        tanks[#tanks + 1] = b
        if Assigned(b.unit, "MAINTANK") then hasMT = true end
      end
    end
    for i, b in ipairs(tanks) do
      if Assigned(b.unit, "MAINTANK") then tags[b] = "MT"
      elseif Assigned(b.unit, "MAINASSIST") then tags[b] = "OT"
      elseif i == 1 and not hasMT then tags[b] = "MT"
      else tags[b] = "OT" end
    end
  end
  for b in pairs(JH.buttons) do
    if b.tankTag then
      local t = tags[b]
      if t then b.tankTag:SetText(t) end
      b.tankTag:SetShown(t ~= nil)
      if b.tagShown ~= (t ~= nil) then
        b.tagShown = (t ~= nil); b.placedKey = nil
        if JH.PlaceIcons then JH.PlaceIcons(b) end
      end
    end
  end
end

-- Arrange the bars for the current group size. Out of combat only (ApplyAll waits).
function JH.ApplyLayout()
  if InCombatLockdown() then return end
  local L = JH.db.layout
  local sp = math.max(0, math.min(20, tonumber(L.spacing) or 2))
  local per, cols = JH.PerColumn()
  local w, h = JH.BarSize()

  for b in pairs(JH.buttons) do b:ClearAllPoints(); b:SetSize(w, h) end

  local p, r = JH.partyHeader, JH.raidHeader
  p:SetAttribute("showSolo", L.solo ~= false)
  p:SetAttribute("showPlayer", L.player ~= false)
  p:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
  r:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
  local tanks = L.tanksTop ~= false
  Sorting(p, L.sort, false, tanks)
  Sorting(r, L.sort, true, tanks)
  JH.tankDirty = true
  Arrange(p, per, cols, sp, L.grow)
  Arrange(r, per, cols, sp, L.grow)
  if not JH.testCount then JH.AnchorGrip(JH.ActiveHeader()) end
end

---------------------------------------------------------------------------
-- Shared events and one light timer for everything
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- /fh heals: what the game reports about incoming heals (to find why none show)
---------------------------------------------------------------------------
JH.healEvents = 0
local hev = CreateFrame("Frame")
JH.healEventOK = pcall(hev.RegisterEvent, hev, "UNIT_HEAL_PREDICTION")
local function HealValue(u)
  if not UnitGetIncomingHeals then return "no function" end
  local ok, v = pcall(UnitGetIncomingHeals, u)
  if not ok then return "error: " .. tostring(v) end
  if IsSecret(v) then return "secret (hidden in combat)" end
  return tostring(v)
end
hev:SetScript("OnEvent", function(_, _, unit)
  JH.healEvents = JH.healEvents + 1
  if JH.debugHeals and type(unit) == "string" and (unit == "player" or unit:match("^party%d") or unit:match("^raid%d")) then
    JH.Print(("heal event: %s [%s] incoming=%s"):format(unit, tostring(UnitName(unit)), HealValue(unit)))
  end
end)

function JH.HealsReport()
  local P = JH.Print
  P("--- incoming heals ---")
  P(("UnitGetIncomingHeals: %s | UNIT_HEAL_PREDICTION: %s | heal events seen: %d"):format(
    UnitGetIncomingHeals and "yes" or "MISSING", JH.healEventOK and "ok" or "NOT AVAILABLE", JH.healEvents))
  P(("newer API: UnitGetDetailedHealPrediction=%s CreateUnitHealPredictionCalculator=%s | setting: %s"):format(
    tostring(UnitGetDetailedHealPrediction ~= nil), tostring(CreateUnitHealPredictionCalculator ~= nil),
    (JH.db and JH.db.look.inc == false) and "OFF" or "on"))
  for b in pairs(JH.buttons) do
    if b:IsVisible() and b.unit then
      P(("%s [%s]: incoming=%s, green bar %s"):format(b.unit, tostring(UnitName(b.unit)), HealValue(b.unit),
        (b.inc and b.inc:IsShown()) and "shown" or "hidden"))
    end
  end
  P(JH.debugHeals and "Watching heal events: heal someone (or get healed) and watch the chat. /fh heals again to stop."
    or "Stopped watching heal events.")
end

-- /fh auras: what the game gives us about auras (to find why icons don't show in combat)
function JH.AurasReport()
  local P = JH.Print
  local u = (UnitExists("target") and UnitIsFriend("player", "target") and UnitInParty("target")) and "target" or "player"
  local function S(v) if IsSecret(v) then return "secret" end return tostring(v) end
  P(("--- auras on %s [%s], in combat: %s ---"):format(u, tostring(UnitName(u)), tostring(InCombatLockdown())))
  P(("GetUnitAuras: %s, GetAuraDataByIndex: %s"):format(
    tostring(C_UnitAuras and C_UnitAuras.GetUnitAuras ~= nil), tostring(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex ~= nil)))
  for _, f in ipairs({ "HELPFUL|PLAYER", "HELPFUL", "HARMFUL" }) do
    local direct = "-"
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
      local ok, list = pcall(C_UnitAuras.GetUnitAuras, u, f, 40)
      direct = ok and (type(list) == "table" and tostring(#list) or type(list)) or ("error: " .. tostring(list))
    end
    local list = GetAuras(u, f, 40)
    P(("%s: GetUnitAuras=%s, used=%d"):format(f, direct, #list))
    local a = list[1]
    if type(a) == "table" then
      local okH, hot = pcall(JH.IsHot, a)
      P(("  first: name=%s id=%s duration=%s icon=%s -> HoT=%s"):format(S(a.name), S(a.auraInstanceID),
        S(a.duration), IsSecret(a.icon) and "secret" or (a.icon and "yes" or "no"), okH and tostring(hot) or ("error: " .. tostring(hot))))
    end
  end
  P("icon error: " .. tostring(JH.auraError or "none"))
  P("Run it once out of combat and once in combat (e.g. on a training dummy) and compare.")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("RAID_TARGET_UPDATE")
pcall(ev.RegisterEvent, ev, "PLAYER_ROLES_ASSIGNED")
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_TARGET_CHANGED" then
    for b in pairs(JH.buttons) do if b:IsVisible() then UpdateTarget(b) end end
  elseif event == "RAID_TARGET_UPDATE" then
    for b in pairs(JH.buttons) do if b:IsVisible() then UpdateMarker(b) end end
  else
    -- joined a party or a raid, or the raid grew past 10/20/25: use that layout
    if JH.headers and JH.active and not JH.testCount and JH.GroupLayout() ~= JH.active then
      JH.Safe("switching layout", JH.ApplyAll, true)
    end
    -- the same "raid3" can now be a different person (or have a new role)
    for b in pairs(JH.buttons) do if b:IsVisible() then JH.UpdateButton(b) end end
    JH.tankDirty = true
  end
end)

local auraT, rangeT = 0, 0
ev:SetScript("OnUpdate", function(_, dt)
  auraT = auraT + dt
  if auraT >= 0.1 then
    auraT = 0
    if next(auraDirty) then
      for b in pairs(auraDirty) do
        auraDirty[b] = nil
        if b:IsVisible() then
          local ok, err = pcall(UpdateAuras, b)
          if not ok and JH.auraError ~= tostring(err) then
            JH.auraError = tostring(err)
            JH.lastError = "updating icons: " .. JH.auraError
          end
        end
      end
    end
  end
  if JH.tankDirty then pcall(JH.UpdateTankLabels) end
  rangeT = rangeT + dt
  if rangeT >= 0.5 then
    rangeT = 0
    for b in pairs(JH.buttons) do
      if b.unit and b:IsVisible() then UpdateRange(b) end
    end
  end
end)
