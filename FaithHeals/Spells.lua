local _, JH = ...

---------------------------------------------------------------------------
-- Spells you know, read from the spellbook, for the binding list.
--
-- In WoW Forever the rank text ("Rank 3") is often empty, so ranks are put in
-- order by rank text when the game gives it, else by the level they are learned
-- at, else by spell ID (lower first). "Max rank" (casting by name) always works
-- and always casts your highest rank.
---------------------------------------------------------------------------

local function Call(fn, ...)
  if not fn then return nil end
  local ok, a, b, c, d, e, f, g = pcall(fn, ...)
  if ok then return a, b, c, d, e, f, g end
  return nil
end

local function Plain(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end

local function SpellName(id)
  local n = Plain(Call(C_Spell and C_Spell.GetSpellName, id))
  if type(n) == "string" and n ~= "" then return n end
  local info = Call(C_Spell and C_Spell.GetSpellInfo, id)
  if type(info) == "table" and type(Plain(info.name)) == "string" then return info.name end
  n = Plain(Call(GetSpellInfo, id))
  if type(n) == "string" and n ~= "" then return n end
  return nil
end

local function SpellIcon(id)
  local t = Plain(Call(C_Spell and C_Spell.GetSpellTexture, id))
  if t then return t end
  local _, _, icon = Call(GetSpellInfo, id)
  return Plain(icon)
end

-- true / false, or nil when the game doesn't say
local function Helpful(id)
  for _, fn in ipairs({ C_Spell and C_Spell.IsSpellHelpful or false, IsHelpfulSpell or false }) do
    if fn then
      local v = Plain(Call(fn, id))
      if v ~= nil then return v and true or false end
    end
  end
  return nil
end

local function RankNumber(id)
  for _, fn in pairs({ C_Spell and C_Spell.GetSpellSubtext or false, GetSpellSubtext or false }) do
    local s = fn and Plain(Call(fn, id))
    if type(s) == "string" then
      local n = tonumber(s:match("(%d+)"))
      if n then return n end
    end
  end
  return nil
end

local function LevelOf(id)
  local l = Plain(Call(C_Spell and C_Spell.GetSpellLevelLearned, id)) or Plain(Call(GetSpellLevelLearned, id))
  return type(l) == "number" and l or nil
end

-- Every spell ID in the player's spellbook (not passives, not future spells)
local function SpellbookIDs()
  local ids = {}
  local SB = C_SpellBook
  if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo then
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    for line = 1, Plain(Call(SB.GetNumSpellBookSkillLines)) or 0 do
      local li = Call(SB.GetSpellBookSkillLineInfo, line)
      if type(li) == "table" and not li.isGuild then
        local first = Plain(li.itemIndexOffset) or 0
        for i = first + 1, first + (Plain(li.numSpellBookItems) or 0) do
          local info = Call(SB.GetSpellBookItemInfo, i, bank)
          if type(info) == "table" and Plain(info.spellID) and not info.isPassive
             and (not spellType or info.itemType == spellType) then
            ids[#ids + 1] = info.spellID
          end
        end
      end
    end
  end
  if #ids == 0 and GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
    -- older spellbook functions
    for tab = 1, Call(GetNumSpellTabs) or 0 do
      local _, _, offset, num = Call(GetSpellTabInfo, tab)
      for slot = (offset or 0) + 1, (offset or 0) + (num or 0) do
        local kind, id = Call(GetSpellBookItemInfo, slot, "spell")
        local passive = IsPassiveSpell and Call(IsPassiveSpell, slot, "spell")
        if kind == "SPELL" and id and not passive then ids[#ids + 1] = id end
      end
    end
  end
  return ids
end

-- Returns a list sorted by name: { name, icon, helpful, ranks = { {id, rank}, ... } }
-- ranks are lowest first; rank is the game's rank number when it gives one.
function JH.ScanSpells()
  local byName, list = {}, {}
  for _, id in ipairs(SpellbookIDs()) do
    local name = SpellName(id)
    if name then
      local e = byName[name]
      if not e then
        e = { name = name, icon = SpellIcon(id), helpful = Helpful(id), ids = {} }
        byName[name] = e
        list[#list + 1] = e
      end
      local dup = false
      for _, v in ipairs(e.ids) do if v == id then dup = true end end
      if not dup then e.ids[#e.ids + 1] = id end
    end
  end
  for _, e in ipairs(list) do
    local r = {}
    for _, id in ipairs(e.ids) do r[#r + 1] = { id = id, rn = RankNumber(id), lvl = LevelOf(id) } end
    table.sort(r, function(a, b)
      if a.rn and b.rn and a.rn ~= b.rn then return a.rn < b.rn end
      if a.lvl and b.lvl and a.lvl ~= b.lvl then return a.lvl < b.lvl end
      return a.id < b.id
    end)
    e.ranks = {}
    for i, x in ipairs(r) do e.ranks[i] = { id = x.id, rank = x.rn or i } end
    e.ids = nil
  end
  table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
  JH.spellList, JH.spellByName = list, byName
  return list
end

function JH.RanksOf(name)
  local e = JH.spellByName and JH.spellByName[name]
  return e and e.ranks or {}
end
