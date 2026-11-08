-- Profession Profit: core, saved data, events and slash commands.
local ADDON, PP = ...
_G.ProfessionProfit = PP

PP.AH_CUT = 0.05 -- the AH takes 5% of the sale

local defaults = {
  minProfit = 0,       -- in copper
  vendor = {},         -- [itemID] = vendor price per unit (learned)
}

local function applyDefaults(dst, src)
  for k, v in pairs(src) do
    if dst[k] == nil then
      dst[k] = type(v) == "table" and {} or v
    end
  end
end

function PP:Print(...)
  print("|cff33ff99Profession Profit|r:", ...)
end

function PP:RealmKey()
  local faction = UnitFactionGroup("player") or "Neutral"
  return (GetRealmName() or "?") .. "-" .. faction
end

-- Formats copper as 12g 34s 56c (negative values get a minus sign)
function PP:Money(copper)
  if not copper then return "|cff888888?|r" end
  local neg = copper < 0
  copper = math.floor(math.abs(copper) + 0.5)
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  local str
  if g > 0 then
    str = string.format("%d|cffffd700g|r %02d|cffc7c7cfs|r %02d|cffeda55fc|r", g, s, c)
  elseif s > 0 then
    str = string.format("%d|cffc7c7cfs|r %02d|cffeda55fc|r", s, c)
  else
    str = string.format("%d|cffeda55fc|r", c)
  end
  return neg and ("-" .. str) or str
end

-- Parses "5g", "1g50s", "75s", "200" (copper) into copper
function PP:ParseMoney(text)
  if not text or text == "" then return nil end
  text = text:lower()
  if text:match("^%-?%d+$") then return tonumber(text) end
  local total, found = 0, false
  for digits, unit in text:gmatch("(%d+)%s*([gsc])") do
    found = true
    local num = tonumber(digits)
    if unit == "g" then total = total + num * 10000
    elseif unit == "s" then total = total + num * 100
    else total = total + num end
  end
  return found and total or nil
end

local frame = CreateFrame("Frame")
PP.eventFrame = frame
PP.handlers = {}

function PP:On(event, fn)
  if not self.handlers[event] then
    -- Unknown events (different client versions) error on newer clients, so pcall
    if not pcall(frame.RegisterEvent, frame, event) then return end
    self.handlers[event] = {}
  end
  table.insert(self.handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
  local list = PP.handlers[event]
  if not list then return end
  for _, fn in ipairs(list) do
    local ok, err = pcall(fn, PP, ...)
    if not ok then geterrorhandler()(err) end
  end
end)

PP:On("ADDON_LOADED", function(self, name)
  if name ~= ADDON then return end
  ProfessionProfitDB = ProfessionProfitDB or {}
  ProfessionProfitCharDB = ProfessionProfitCharDB or {}
  applyDefaults(ProfessionProfitDB, defaults)
  -- Clear data from older versions that had other price sources
  ProfessionProfitDB.source, ProfessionProfitDB.prices, ProfessionProfitDB.maxPriceAge = nil, nil, nil
  ProfessionProfitCharDB.professions = ProfessionProfitCharDB.professions or {}
  self.db = ProfessionProfitDB
  self.char = ProfessionProfitCharDB
end)

PP:On("PLAYER_LOGIN", function(self)
  self:Print("loaded. Type |cffffff00/pp|r to show the list, |cffffff00/pp help|r for commands.")
end)

local function help()
  PP:Print("Commands:")
  print("  /pp                 - show/hide the profit list")
  print("  /pp min <amount>    - minimum profit to show, e.g. /pp min 1g50s")
  print("  /pp status          - show whether Forever Guide prices were found and known recipes")
  print("  /pp fgdump          - show what Forever Guide's data looks like (troubleshooting)")
  print("  /pp reset           - forget saved recipes for this character")
  print("Open each profession window once so your recipes are saved.")
  print("Prices come from Forever Guide - scan the AH with Forever Guide first.")
end

SLASH_PROFESSIONPROFIT1 = "/pp"
SLASH_PROFESSIONPROFIT2 = "/profprofit"
SlashCmdList.PROFESSIONPROFIT = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    PP:ToggleUI()
  elseif cmd == "help" then
    help()
  elseif cmd == "min" then
    local v = PP:ParseMoney(rest)
    if v then
      PP.db.minProfit = v
      PP:Print("Minimum profit:", PP:Money(v))
      PP:RefreshUI()
    else
      PP:Print("Enter an amount, e.g. /pp min 2g")
    end
  elseif cmd == "status" then
    PP:PrintStatus()
  elseif cmd == "fgdump" then
    PP:DumpForeverGuide()
  elseif cmd == "reset" then
    wipe(PP.char.professions)
    PP:Print("Saved recipes cleared. Open your profession windows again.")
    PP:RefreshUI()
  else
    help()
  end
end

function PP:PrintStatus()
  self:Print("Forever Guide:", self:ForeverGuideStatus())
  local n = 0
  for _ in pairs(self.db.vendor) do n = n + 1 end
  self:Print("Learned vendor prices:", n)
  for prof, data in pairs(self.char.professions) do
    local c = 0
    for _ in pairs(data.recipes) do c = c + 1 end
    self:Print(string.format("  %s: %d recipes (saved %s)", prof, c, date("%Y-%m-%d %H:%M", data.updated or 0)))
  end
end
