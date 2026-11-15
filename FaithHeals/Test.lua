local _, JH = ...

---------------------------------------------------------------------------
-- Test bars: fake group members so the look and layout can be set up
-- without being in a party or raid. They are plain pictures - they can't be
-- clicked or healed - and they go away by themselves when combat starts.
---------------------------------------------------------------------------
local CLASSES = { "WARRIOR", "PRIEST", "DRUID", "MAGE", "PALADIN", "HUNTER", "ROGUE",
                  "SHAMAN", "WARLOCK", "MONK", "DEATHKNIGHT", "DEMONHUNTER", "EVOKER" }
local NAMES = { "Faith", "Bjorn", "Astrid", "Tova", "Sigge", "Ylva", "Runa", "Loke", "Embla", "Vidar",
                "Saga", "Odd", "Freja", "Hakonsdottir", "Liv", "Torstensson", "Idun", "Gorm", "Alva", "Sten",
                "Maja", "Ragnar", "Signe", "Ivar", "Elsa", "Knut", "Hilda", "Arvid", "Tyra", "Folke",
                "Greta", "Halvar", "Inga", "Jorund", "Kaja", "Leif", "Moa", "Njal", "Disa", "Ulf" }
local HOTS = { "Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Nature_ResistNature",
               "Interface\\Icons\\INV_Misc_Herb_Felblossom", "Interface\\Icons\\Ability_Druid_Flourish" }
local BUFFS = { "Interface\\Icons\\Spell_Holy_WordFortitude", "Interface\\Icons\\Spell_Nature_Regeneration",
                "Interface\\Icons\\Spell_Holy_MagicalSentry", "Interface\\Icons\\Spell_Holy_SealOfWisdom" }
local DEBUFFS = { "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Spell_Nature_Slow",
                  "Interface\\Icons\\Spell_Shadow_CurseOfTounges" }
local HEALTH = { 1, 0.85, 0.6, 1, 0.35, 1, 0.95, 0.15, 1, 0.7 }
local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3 }

local frames, container = {}, nil

local function MakeData(n)
  local list = {}
  for i = 1, n do
    local g, pos = math.ceil(i / 5), (i - 1) % 5
    list[i] = {
      index = i,
      name  = NAMES[(i - 1) % #NAMES + 1],
      class = CLASSES[(i * 3) % #CLASSES + 1],
      role  = (pos == 0 and g <= 2) and "TANK" or (pos == 1 and "HEALER") or "DAMAGER",
      hp    = HEALTH[(i - 1) % #HEALTH + 1],
      state = (i == 13 and "Dead") or (i == 19 and "Offline") or nil,
      hots  = (i == 1) and 3 or (i * 7) % 4,
      dispel = (i == 3 or i == 17),
      oor    = (i == 5 or i % 11 == 0),
      target = (i == 2),
      inc    = (i % 3 == 0) and 0.2 or ((i % 4 == 2) and 0.1 or 0), -- incoming heals
      marker = (i == 1 and 8) or (i == 4 and 1) or (i == 7 and 2) or nil, -- skull, star, circle
      buffs  = (i % 2 == 0) and 3 or 1,                 -- buffs from other players
      debuffs = (i % 6 == 4) and 2 or 0,                -- debuffs you can't dispel (plus the dispel one)
    }
  end
  local sort = JH.db.layout.sort
  if sort == "role" then
    table.sort(list, function(a, b)
      if a.role ~= b.role then return ROLE_ORDER[a.role] < ROLE_ORDER[b.role] end
      return a.name < b.name
    end)
  elseif sort == "name" then
    table.sort(list, function(a, b) return a.name < b.name end)
  end
  return list
end

local function Fill(b, d)
  local look = JH.db.look
  local c = RAID_CLASS_COLORS[d.class]
  b.name:SetText(JH.ShortName(d.name, look.nameLen))
  b.name:SetTextColor(JH.NameRGB(look, c))
  if look.pctColor == "health" then
    local p = d.hp
    if p > 0.5 then b.pct:SetTextColor((1 - p) * 2, 1, 0) else b.pct:SetTextColor(1, p * 2, 0) end
  else
    b.pct:SetTextColor(JH.PctRGB(look, c))
  end
  JH.ApplyBg(b, c)

  local mark = d.marker and look.marker ~= false
  if mark then SetRaidTargetIconTexture(b.marker, d.marker) end
  b.marker:SetShown(mark and true or false)
  b.markerShown = mark and true or false

  local healer = d.role == "HEALER" and look.healerIcon ~= false
  if healer then JH.SetHealerTexture(b.role) end
  b.role:SetShown(healer)
  b.roleShown = healer

  b.hp:SetMinMaxValues(0, 1)
  if d.state then
    b.hp:SetValue(0); b.status:SetText(d.state); b.pct:SetText("")
  else
    b.hp:SetValue(d.hp); b.status:SetText("")
    if b.showPct then b.pct:SetFormattedText("%d%%", d.hp * 100) else b.pct:SetText("") end
  end
  if b.inc then
    if look.inc ~= false and not d.state and d.inc > 0 then
      b.inc:SetMinMaxValues(0, 1); b.inc:SetValue(d.inc); b.inc:Show()
    else
      b.inc:Hide()
    end
  end

  local tex = b.barTex
  if look.bar == "class" and c then
    tex:SetVertexColor(c.r, c.g, c.b)
  elseif look.bar == "dark" then
    tex:SetVertexColor(0.16, 0.16, 0.16)
  elseif d.hp > 0.5 then
    tex:SetVertexColor((1 - d.hp) * 2, 0.8, 0)
  else
    tex:SetVertexColor(1, d.hp * 1.8, 0)
  end

  -- icons, the same three kinds (and caps) as on the real bars
  local function Cap(v, def) return math.max(0, math.min(4, tonumber(v) or def)) end
  local function Put(icons, n, textures)
    for i, ic in ipairs(icons) do
      if i <= n then
        ic.tex:SetTexture(textures[(i - 1) % #textures + 1])
        ic.cd:SetCooldown(GetTime() - 3 * i, 12 + i * 2)
        ic:Show()
      else
        ic:Hide()
      end
    end
    return n
  end
  local alive = not d.state
  local hotMax = look.hots ~= false and Cap(look.hotMax, 4) or 0
  local nDeb = 0
  if look.showDebuffs then
    if look.debuffs == "dispel" then nDeb = d.dispel and 1 or 0
    else nDeb = (d.dispel and 1 or 0) + d.debuffs end
  end
  b.nHots    = Put(b.icons, alive and math.min(d.hots, hotMax) or 0, HOTS)
  b.nBuffs   = Put(b.buffIcons, alive and math.min(d.buffs, (look.showBuffs and Cap(look.buffMax, 3) or 0)) or 0, BUFFS)
  b.nDebuffs = Put(b.debuffIcons, alive and math.min(nDeb, Cap(look.debuffMax, 3)) or 0, DEBUFFS)
  b.placedKey = nil
  JH.PlaceIcons(b)

  b.dispel:SetShown(d.dispel and look.dispel ~= false)
  b.sel:SetShown(d.target)
  b:SetAlpha(d.oor and (JH.db.rangeAlpha or 0.4) or 1)
end

-- Redraw the test bars with the current saved look, size and layout
function JH.RefreshTest()
  local n = JH.testCount
  if not n or not container then return end
  local db, L = JH.db, JH.db.layout
  local id = JH.LayoutForCount(n)
  local s = JH.Size(id)
  local w, h = s.w, s.h
  local sp  = math.max(0, math.min(20, tonumber(L.spacing) or 2))
  local per = JH.PerColumn(id)
  local right = (L.grow == "right")
  local data = MakeData(n)

  -- tanks on top (like the real bars): their own block with "Main tank" / "Off tank"
  local tanks, rest = {}, {}
  if L.tanksTop ~= false then
    for _, d in ipairs(data) do
      if d.role == "TANK" then tanks[#tanks + 1] = d else rest[#rest + 1] = d end
    end
  else
    rest = data
  end
  local LH = JH.TANK_LABEL_H or 12
  local nT = #tanks
  local tankH = 0
  if nT > 0 then
    tankH = right and (LH + h + sp) or (nT * (LH + h + sp))
  end

  container:SetScale(db.scale or 1)
  local function Bar(i)
    local b = frames[i]
    if not b then
      b = CreateFrame("Frame", nil, container)
      JH.BuildVisuals(b)
      frames[i] = b
    end
    b:ClearAllPoints()
    b:SetSize(w, h)
    return b
  end
  for i, d in ipairs(tanks) do
    local b = Bar(i)
    if right then
      b:SetPoint("TOPLEFT", (i - 1) * (w + sp), -LH)
    else
      b:SetPoint("TOPLEFT", 0, -LH - (i - 1) * (h + sp + LH))
    end
    JH.StyleButton(b)
    Fill(b, d)
    b.tankLabel:SetText(i == 1 and "Main tank" or "Off tank")
    b.tankLabel:Show()
    b:Show()
  end
  for k, d in ipairs(rest) do
    local b = Bar(nT + k)
    local along, across = (k - 1) % per, math.floor((k - 1) / per)
    if right then
      b:SetPoint("TOPLEFT", along * (w + sp), -tankH - across * (h + sp + 1))
    else
      b:SetPoint("TOPLEFT", across * (w + sp + 1), -tankH - along * (h + sp))
    end
    JH.StyleButton(b)
    Fill(b, d)
    b.tankLabel:Hide()
    b:Show()
  end
  for i = n + 1, #frames do frames[i]:Hide() end

  local m = math.max(1, #rest)
  local along, across = math.min(m, per), math.ceil(m / per)
  local tw = right and (nT * (w + sp) - sp) or w
  if right then
    container:SetSize(math.max(tw, along * (w + sp) - sp), tankH + across * (h + sp + 1) - sp - 1)
  else
    container:SetSize(across * (w + sp + 1) - sp - 1, tankH + along * (h + sp) - sp)
  end
end

-- n = number of test bars, 0 or nil = off
function JH.SetTest(n)
  n = tonumber(n) or 0
  n = math.floor(math.max(0, math.min(40, n)))
  if n > 0 then
    if InCombatLockdown() then return JH.Print("Test bars can't be shown in combat.") end
    if not container then
      container = CreateFrame("Frame", "FaithHealsTest", UIParent)
      container:SetPoint("TOPLEFT", JH.mover, "BOTTOMLEFT", 0, -2)
      container:SetFrameStrata("MEDIUM")
      container:SetFrameLevel(50)
      container:EnableMouse(true) -- so clicks don't reach the hidden real bars underneath
    end
    JH.testCount = n
    JH.ChooseLayout()           -- resizing now changes the test bars' group size
    for _, hdr in ipairs(JH.headers) do hdr:SetAlpha(0) end -- real bars stay, just invisible
    container:Show()
    JH.RefreshTest()
    JH.AnchorGrip(container)
  else
    if not JH.testCount then return end
    JH.testCount = nil
    if container then container:Hide() end
    for _, hdr in ipairs(JH.headers) do hdr:SetAlpha(1) end
    JH.ApplyAll(true)           -- back to the size for the group you are in
  end
  if JH.RefreshConfig then JH.RefreshConfig() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function()
  if JH.testCount then
    JH.SetTest(0)
    JH.Print("Combat started - test bars hidden.")
  end
end)
