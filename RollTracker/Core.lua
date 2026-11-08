-- Roll Tracker: håller koll på vad alla i gruppen väljer på varje drop.
--
-- Spelet skriver ut alla val i loot-chatten ("X has selected Need for: [föremål]").
-- Vi läser de meddelandena med spelets egna, översatta formatsträngar,
-- så det fungerar på alla språk och oberoende av vilket UI (Blizzard/ElvUI)
-- som visar själva roll-fönstren.
local ADDON, RT = ...
_G.RollTracker = RT

RT.MAX_DROPS = 15

RT.CHOICES = {
  need     = { label = "Need",     color = "ff33ff33", order = 1 },
  greed    = { label = "Greed",    color = "ffffd100", order = 2 },
  de       = { label = "Disenchant", color = "ffb37fff", order = 3 },
  transmog = { label = "Transmog", color = "ff66ccff", order = 4 },
  pass     = { label = "Pass",     color = "ff999999", order = 5 },
}

RT.drops = {}   -- nyaste först: { link, rollID, time, players = { [namn] = { choice, roll } }, winner, done }

function RT:Print(...)
  print("|cffff9933Roll Tracker|r:", ...)
end

---------------------------------------------------------------------------
-- Formatsträng -> Lua-mönster (hanterar även "%1$s"-positioner)
---------------------------------------------------------------------------
local function fmtToPattern(fmt)
  local out, order, i, n = { "^" }, {}, 1, 0
  while i <= #fmt do
    local c = fmt:sub(i, i)
    if c == "%" then
      local s, e, pos, conv = fmt:find("^%%(%d)%$([sd])", i)
      if not s then
        s, e, conv = fmt:find("^%%([sd])", i)
      end
      if s then
        n = n + 1
        order[n] = pos and tonumber(pos) or n
        table.insert(out, conv == "d" and "(%d+)" or "(.-)")
        i = e + 1
      else
        table.insert(out, "%%")
        i = i + 1
        if fmt:sub(i, i) == "%" then i = i + 1 end
      end
    elseif c:find("[%^%$%(%)%.%[%]%*%+%-%?]") then
      table.insert(out, "%" .. c)
      i = i + 1
    else
      table.insert(out, c)
      i = i + 1
    end
  end
  table.insert(out, "$")
  return table.concat(out), order
end

-- Returnerar argumenten i formatsträngens ordning
local function matchFmt(msg, compiled)
  local caps = { msg:match(compiled.pattern) }
  if #caps == 0 then return nil end
  local args = {}
  for idx, argPos in ipairs(compiled.order) do args[argPos] = caps[idx] end
  return args
end

-- kind: "choice" (namn, länk), "self" (länk), "rolled" (tal, länk, namn),
--       "won" (namn, länk), "youwon" (länk), "allpassed" (länk)
local PATTERNS = {
  { g = "LOOT_ROLL_NEED",          kind = "choice", choice = "need" },
  { g = "LOOT_ROLL_GREED",         kind = "choice", choice = "greed" },
  { g = "LOOT_ROLL_DISENCHANT",    kind = "choice", choice = "de" },
  { g = "LOOT_ROLL_TRANSMOG",      kind = "choice", choice = "transmog" },
  { g = "LOOT_ROLL_PASSED",        kind = "choice", choice = "pass" },
  { g = "LOOT_ROLL_PASSED_AUTO",   kind = "choice", choice = "pass" },
  { g = "LOOT_ROLL_PASSED_AUTO_FEMALE", kind = "choice", choice = "pass" },
  { g = "LOOT_ROLL_NEED_SELF",     kind = "self",   choice = "need" },
  { g = "LOOT_ROLL_GREED_SELF",    kind = "self",   choice = "greed" },
  { g = "LOOT_ROLL_DISENCHANT_SELF", kind = "self", choice = "de" },
  { g = "LOOT_ROLL_TRANSMOG_SELF", kind = "self",   choice = "transmog" },
  { g = "LOOT_ROLL_PASSED_SELF",   kind = "self",   choice = "pass" },
  { g = "LOOT_ROLL_PASSED_SELF_AUTO", kind = "self", choice = "pass" },
  { g = "LOOT_ROLL_ROLLED_NEED",   kind = "rolled", choice = "need" },
  { g = "LOOT_ROLL_ROLLED_GREED",  kind = "rolled", choice = "greed" },
  { g = "LOOT_ROLL_ROLLED_DE",     kind = "rolled", choice = "de" },
  { g = "LOOT_ROLL_ROLLED_TRANSMOG", kind = "rolled", choice = "transmog" },
  { g = "LOOT_ROLL_YOU_WON",       kind = "youwon" },
  { g = "LOOT_ROLL_WON",           kind = "won" },
  { g = "LOOT_ROLL_ALL_PASSED",    kind = "allpassed" },
}

local compiled = {}
local function compilePatterns()
  wipe(compiled)
  for _, p in ipairs(PATTERNS) do
    local fmt = _G[p.g]
    if type(fmt) == "string" and fmt ~= "" then
      local pattern, order = fmtToPattern(fmt)
      table.insert(compiled, { pattern = pattern, order = order, kind = p.kind, choice = p.choice, fmt = fmt })
    end
  end
  -- Längre/mer specifika mönster först så att t.ex. "_SELF_AUTO" inte tas av ett kortare
  table.sort(compiled, function(a, b) return #a.fmt > #b.fmt end)
end
RT._fmtToPattern = fmtToPattern

---------------------------------------------------------------------------
-- Drops
---------------------------------------------------------------------------
local function itemKey(link)
  -- Jämför på själva item-strängen så att färgkoder inte spelar roll
  return link and (link:match("|H(item:[^|]+)|h") or link) or "?"
end

function RT:FindDrop(link, playerName)
  local key = itemKey(link)
  local fallback
  for _, d in ipairs(self.drops) do
    if itemKey(d.link) == key and not d.done then
      if not playerName or not d.players[playerName] or not d.players[playerName].choice then
        return d
      end
      fallback = fallback or d
    end
  end
  return fallback
end

function RT:NewDrop(link, rollID)
  local d = { link = link, rollID = rollID, time = time(), players = {} }
  table.insert(self.drops, 1, d)
  while #self.drops > self.MAX_DROPS do table.remove(self.drops) end
  return d
end

function RT:GetDrop(link, playerName)
  return self:FindDrop(link, playerName) or self:NewDrop(link)
end

local function shortName(name)
  if not name then return nil end
  name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  -- Ta bort realm om det är samma realm som vår
  local base, realm = name:match("^(.-)%-(.+)$")
  if base and realm == (GetRealmName() or ""):gsub("%s", "") then return base end
  return name
end

local function playerName() return UnitName("player") end

function RT:HandleLootMessage(msg)
  for _, c in ipairs(compiled) do
    local a = matchFmt(msg, c)
    if a then
      if c.kind == "choice" then
        local name, link = shortName(a[1]), a[2]
        local d = self:GetDrop(link, name)
        d.players[name] = d.players[name] or {}
        d.players[name].choice = c.choice
      elseif c.kind == "self" then
        local name, link = playerName(), a[1]
        local d = self:GetDrop(link, name)
        d.players[name] = d.players[name] or {}
        d.players[name].choice = c.choice
      elseif c.kind == "rolled" then
        local roll, link, name = tonumber(a[1]), a[2], shortName(a[3])
        local d = self:FindDrop(link) or self:NewDrop(link)
        d.players[name] = d.players[name] or {}
        d.players[name].choice = d.players[name].choice or c.choice
        d.players[name].roll = roll
      elseif c.kind == "won" or c.kind == "youwon" then
        local name, link
        if c.kind == "won" then name, link = shortName(a[1]), a[2] else name, link = playerName(), a[1] end
        local d = self:FindDrop(link) or self:NewDrop(link)
        d.winner = name
        d.done = true
      elseif c.kind == "allpassed" then
        local d = self:FindDrop(a[1]) or self:NewDrop(a[1])
        d.allPassed = true
        d.done = true
      end
      self:Changed()
      return
    end
  end
end

-- Gruppmedlemmar (för att visa vilka som inte valt än)
function RT:GroupMembers()
  local list = {}
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  if n == 0 then
    table.insert(list, playerName())
    return list
  end
  local isRaid = IsInRaid and IsInRaid()
  for i = 1, n do
    local unit = isRaid and ("raid" .. i) or (i == n and "player" or ("party" .. i))
    local name, realm = UnitName(unit)
    if name then
      if realm and realm ~= "" then name = name .. "-" .. realm end
      table.insert(list, name)
    end
  end
  return list
end

-- Klassfärg för en spelare i gruppen
function RT:ClassColor(name)
  local unit
  if name == playerName() then unit = "player" end
  if not unit then
    local isRaid = IsInRaid and IsInRaid()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, n do
      local u = isRaid and ("raid" .. i) or ("party" .. i)
      local un, ur = UnitName(u)
      if un and (un == name or (ur and ur ~= "" and un .. "-" .. ur == name)) then unit = u break end
    end
  end
  local _, class = unit and UnitClass(unit)
  local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
  if c then
    return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name)
  end
  return name
end

-- Räknar val för en drop: { need = n, greed = n, ... , waiting = n }
function RT:Counts(d)
  local counts = { need = 0, greed = 0, de = 0, transmog = 0, pass = 0, waiting = 0 }
  for _, p in pairs(d.players) do
    if p.choice then counts[p.choice] = counts[p.choice] + 1 end
  end
  if not d.done then
    for _, name in ipairs(self:GroupMembers()) do
      local s = shortName(name)
      if not (d.players[s] and d.players[s].choice) then counts.waiting = counts.waiting + 1 end
    end
  end
  return counts
end

function RT:Waiting(d)
  local out = {}
  if d.done then return out end
  for _, name in ipairs(self:GroupMembers()) do
    local s = shortName(name)
    if not (d.players[s] and d.players[s].choice) then table.insert(out, s) end
  end
  return out
end

function RT:Changed()
  if self.RefreshUI then self:RefreshUI() end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
local function reg(e) pcall(f.RegisterEvent, f, e) end
reg("ADDON_LOADED")
reg("PLAYER_LOGIN")
reg("CHAT_MSG_LOOT")
reg("START_LOOT_ROLL")
reg("CANCEL_LOOT_ROLL")
reg("GROUP_ROSTER_UPDATE")

f:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    RollTrackerDB = RollTrackerDB or {}
    if RollTrackerDB.autoShow == nil then RollTrackerDB.autoShow = true end
    RT.db = RollTrackerDB
    compilePatterns()
  elseif event == "PLAYER_LOGIN" then
    compilePatterns() -- om ett språkpaket har ändrat strängarna
    RT:Print("laddat" .. (RT:HasElvUI() and " (ElvUI hittat)" or "") .. ". Skriv |cffffff00/rt|r för att visa fönstret.")
  elseif event == "CHAT_MSG_LOOT" then
    RT:HandleLootMessage((...))
  elseif event == "START_LOOT_ROLL" then
    local rollID = ...
    local link = GetLootRollItemLink and GetLootRollItemLink(rollID)
    if link then
      local d = RT:FindDrop(link)
      if not (d and not next(d.players) and not d.rollID) then d = RT:NewDrop(link, rollID) end
      d.rollID = rollID
      d.active = true
      if RT.db.autoShow and RT.ShowUI then RT:ShowUI() end
      RT:Changed()
    end
  elseif event == "CANCEL_LOOT_ROLL" then
    local rollID = ...
    for _, d in ipairs(RT.drops) do
      if d.rollID == rollID then d.active = false end
    end
    RT:Changed()
  elseif event == "GROUP_ROSTER_UPDATE" then
    RT:Changed()
  end
end)

function RT:HasElvUI()
  return type(_G.ElvUI) == "table"
end

SLASH_ROLLTRACKER1 = "/rt"
SLASH_ROLLTRACKER2 = "/rolltracker"
SlashCmdList.ROLLTRACKER = function(msg)
  local cmd = (msg or ""):match("^%s*(%S*)"):lower()
  if cmd == "" then
    RT:ToggleUI()
  elseif cmd == "auto" then
    RT.db.autoShow = not RT.db.autoShow
    RT:Print("Visa automatiskt vid roll:", RT.db.autoShow and "på" or "av")
  elseif cmd == "clear" then
    wipe(RT.drops)
    RT:Changed()
    RT:Print("Historiken rensad.")
  else
    RT:Print("Kommandon:")
    print("  /rt        - visa/dölj fönstret")
    print("  /rt auto   - slå på/av att fönstret öppnas när något ska rollas")
    print("  /rt clear  - rensa historiken")
  end
end
