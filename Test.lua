local _, JH = ...

---------------------------------------------------------------------------
-- Test bars: fake group members so the look and layout can be set up
-- without being in a party or raid. They are plain pictures - they can't be
-- clicked or healed - and they go away by themselves when combat starts.
---------------------------------------------------------------------------
local CLASSES = { "WARRIOR", "PRIEST", "DRUID", "MAGE", "PALADIN", "HUNTER", "ROGUE",
                  "SHAMAN", "WARLOCK", "MONK", "DEATHKNIGHT", "DEMONHUNTER", "EVOKER" }
local NAMES = { "Faith", "Bjorn", "Astrid", "Tova", "Sigge", "Ylva", "Runa", "Loke", "Embla", "Vidar",
                "Saga", "Odd", "Freja", "Hakon", "Liv", "Torsten", "Idun", "Gorm", "Alva", "Sten",
                "Maja", "Ragnar", "Signe", "Ivar", "Elsa", "Knut", "Hilda", "Arvid", "Tyra", "Folke",
                "Greta", "Halvar", "Inga", "Jorund", "Kaja", "Leif", "Moa", "Njal", "Disa", "Ulf" }
local HOTS = { "Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Nature_ResistNature",
               "Interface\\Icons\\INV_Misc_Herb_Felblossom", "Interface\\Icons\\Ability_Druid_Flourish" }
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
  b.name:SetText(d.name)
  if look.name == "class" and c then b.name:SetTextColor(c.r, c.g, c.b) else b.name:SetTextColor(1, 1, 1) end

  b.hp:SetMinMaxValues(0, 1)
  if d.state then
    b.hp:SetValue(0); b.status:SetText(d.state); b.pct:SetText("")
  else
    b.hp:SetValue(d.hp); b.status:SetText("")
    if b.showPct then b.pct:SetFormattedText("%d%%", d.hp * 100) else b.pct:SetText("") end
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

  local shown = 0
  for i, ic in ipairs(b.icons) do
    if look.hots ~= false and not d.state and i <= d.hots then
      ic.tex:SetTexture(HOTS[i])
      ic.cd:SetCooldown(GetTime() - 3 * i, 12 + i * 2)
      ic:Show(); shown = i
    else
      ic:Hide()
    end
  end
  if b.slim then
    b.name:ClearAllPoints()
    b.name:SetPoint("LEFT", 3, 0)
    b.name:SetPoint("RIGHT", -(3 + shown * ((b.iconSize or 10) + 1)), 0)
  end

  b.dispel:SetShown(d.dispel)
  b.sel:SetShown(d.target)
  b:SetAlpha(d.oor and (JH.db.rangeAlpha or 0.4) or 1)
end

-- Redraw the test bars with the current saved look, size and layout
function JH.RefreshTest()
  local n = JH.testCount
  if not n or not container then return end
  local db, L = JH.db, JH.db.layout
  local w, h = db.width, db.height
  local sp  = math.max(0, math.min(20, tonumber(L.spacing) or 2))
  local per = math.max(1, math.min(40, tonumber(L.per) or 5))
  local right = (L.grow == "right")
  local data = MakeData(n)

  container:SetScale(db.scale or 1)
  for i = 1, n do
    local b = frames[i]
    if not b then
      b = CreateFrame("Frame", nil, container)
      JH.BuildVisuals(b)
      frames[i] = b
    end
    local along, across = (i - 1) % per, math.floor((i - 1) / per)
    b:ClearAllPoints()
    b:SetSize(w, h)
    if right then
      b:SetPoint("TOPLEFT", along * (w + sp), -across * (h + sp + 1))
    else
      b:SetPoint("TOPLEFT", across * (w + sp + 1), -along * (h + sp))
    end
    JH.StyleButton(b)
    Fill(b, data[i])
    b:Show()
  end
  for i = n + 1, #frames do frames[i]:Hide() end

  local along, across = math.min(n, per), math.ceil(n / per)
  if right then
    container:SetSize(along * (w + sp) - sp, across * (h + sp + 1) - sp - 1)
  else
    container:SetSize(across * (w + sp + 1) - sp - 1, along * (h + sp) - sp)
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
    JH.header:SetAlpha(0)       -- real bars stay in place, just invisible
    container:Show()
    JH.RefreshTest()
    JH.grip:ClearAllPoints()
    JH.grip:SetPoint("TOPLEFT", container, "BOTTOMRIGHT", -4, 4)
  else
    if not JH.testCount then return end
    JH.testCount = nil
    if container then container:Hide() end
    JH.header:SetAlpha(1)
    JH.grip:ClearAllPoints()
    JH.grip:SetPoint("TOPLEFT", JH.header, "BOTTOMRIGHT", -4, 4)
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
