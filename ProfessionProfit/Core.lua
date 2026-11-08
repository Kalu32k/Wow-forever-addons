-- Profession Profit: kärna, sparad data, events och slash-kommandon.
local ADDON, PP = ...
_G.ProfessionProfit = PP

PP.AH_CUT = 0.05 -- AH tar 5% av försäljningen

local defaults = {
  source = "auto",     -- auto | forever | auctionator | own
  minProfit = 0,       -- i koppar
  maxPriceAge = 7 * 24 * 3600, -- egen skanning: ignorera priser äldre än så här
  prices = {},         -- [realm-faktion][itemID] = { p = koppar, t = tid }
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

-- Formaterar koppar som 12g 34s 56c (negativa värden får minustecken)
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

-- Parsar "5g", "1g50s", "75s", "200" (koppar) till koppar
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
    -- Okända events (olika klientversioner) ger fel i nyare klienter, så pcall
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
  ProfessionProfitCharDB.professions = ProfessionProfitCharDB.professions or {}
  self.db = ProfessionProfitDB
  self.char = ProfessionProfitCharDB
end)

PP:On("PLAYER_LOGIN", function(self)
  self:Print("laddat. Skriv |cffffff00/pp|r för att visa listan, |cffffff00/pp help|r för kommandon.")
end)

local function help()
  PP:Print("Kommandon:")
  print("  /pp                 - visa/dölj profit-listan")
  print("  /pp scan            - skanna AH själv (måste stå vid auktionären)")
  print("  /pp source <auto|forever|auctionator|own> - välj priskälla")
  print("  /pp min <belopp>    - lägsta profit som visas, t.ex. /pp min 1g50s")
  print("  /pp status          - visa vilka priskällor som hittats och kända recept")
  print("  /pp fgdump          - visa hur Forever Guides data ser ut (felsökning)")
  print("  /pp reset           - glöm sparade recept för den här karaktären")
  print("Öppna varje yrkesfönster en gång så sparas dina recept.")
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
  elseif cmd == "scan" then
    PP:StartScan()
  elseif cmd == "source" then
    local s = rest:lower()
    if s == "auto" or s == "forever" or s == "auctionator" or s == "own" then
      PP.db.source = s
      PP:Print("Priskälla:", s)
      PP:RefreshUI()
    else
      PP:Print("Okänd källa. Använd auto, forever, auctionator eller own.")
    end
  elseif cmd == "min" then
    local v = PP:ParseMoney(rest)
    if v then
      PP.db.minProfit = v
      PP:Print("Lägsta profit:", PP:Money(v))
      PP:RefreshUI()
    else
      PP:Print("Ange ett belopp, t.ex. /pp min 2g")
    end
  elseif cmd == "status" then
    PP:PrintStatus()
  elseif cmd == "fgdump" then
    PP:DumpForeverGuide()
  elseif cmd == "reset" then
    wipe(PP.char.professions)
    PP:Print("Sparade recept rensade. Öppna dina yrkesfönster igen.")
    PP:RefreshUI()
  else
    help()
  end
end

function PP:PrintStatus()
  self:Print("Forever Guide:", self:ForeverGuideStatus())
  self:Print("Auctionator:", self:HasAuctionator() and "|cff00ff00hittad|r" or "|cffff0000saknas|r")
  local own = self.db.prices[self:RealmKey()]
  local n = 0
  if own then for _ in pairs(own) do n = n + 1 end end
  self:Print("Egen skanning:", n, "föremål sparade för", self:RealmKey())
  self:Print("Vald källa:", self.db.source)
  for prof, data in pairs(self.char.professions) do
    local c = 0
    for _ in pairs(data.recipes) do c = c + 1 end
    self:Print(string.format("  %s: %d recept (sparat %s)", prof, c, date("%Y-%m-%d %H:%M", data.updated or 0)))
  end
end
