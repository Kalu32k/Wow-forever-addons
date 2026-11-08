-- Profession Profit: AH-priser från Forever Guide och profitberäkning.
-- Alla AH-priser kommer från Forever Guides egen AH-skanning. Reagenser
-- jämförs också mot försäljarpriser som addonet lär sig när du öppnar
-- en försäljare (t.ex. tråd och flaskor som inte säljs på AH).
local _, PP = ...

---------------------------------------------------------------------------
-- Forever Guide
---------------------------------------------------------------------------
-- Forever Guide har inget dokumenterat API för andra addons, så vi letar
-- upp det: först efter en funktion som ger ett pris för ett itemID, och
-- annars efter tabellen där det sparar sina skannade AH-priser.

local FG = {
  addonName = nil,  -- mappnamn för Forever Guide, om det hittas
  loaded = false,
  fn = nil,         -- function(itemID) -> koppar
  fnPath = nil,
  table = nil,      -- [itemID] = pris eller { ...pris... }
  tablePath = nil,
  detected = false,
}
PP.FG = FG

local GetNumAddOns = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
local GetAddOnInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
local IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

local function stripColors(s)
  return (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function findForeverGuideAddon()
  if not GetNumAddOns then return nil end
  for i = 1, GetNumAddOns() do
    local name, title = GetAddOnInfo(i)
    local hay = (stripColors(title) .. " " .. (name or "")):lower()
    if hay:find("forever") and hay:find("guide") then
      return name
    end
  end
end

local FUNC_NAMES = {
  "GetAuctionPrice", "GetAuctionPriceByItemID", "GetAHPrice", "GetPrice",
  "GetItemPrice", "GetLowestPrice", "GetLowestBuyout", "GetMinBuyout",
  "GetMarketPrice", "GetPriceByItemID", "GetItemValue", "GetValue",
}
local SUBTABLES = { "API", "Api", "api", "AH", "Auction", "Auctions", "AuctionHouse", "Prices", "Price", "Market" }
local PRICE_FIELDS = {
  "price", "minBuyout", "minbuyout", "buyout", "lowest", "lowestPrice", "low",
  "min", "minPrice", "unitPrice", "unit", "p", "value", "market", "marketValue",
}

local function priceFromValue(v)
  if type(v) == "number" then return v > 0 and v or nil end
  if type(v) == "table" then
    for _, f in ipairs(PRICE_FIELDS) do
      local n = v[f]
      if type(n) == "number" and n > 0 then return n end
    end
    if type(v[1]) == "number" and v[1] > 0 then return v[1] end
  end
end

local function keyToItemID(k)
  if type(k) == "number" then
    return (k > 0 and k == math.floor(k)) and k or nil
  elseif type(k) == "string" then
    local id = k:match("^item:(%d+)") or k:match("^i:(%d+)") or k:match("^(%d+)$")
    return id and tonumber(id) or nil
  end
end

-- Kandidater: globala tabeller vars namn liknar Forever Guide
local function candidateGlobals()
  local out, seen = {}, {}
  local function add(name)
    local v = _G[name]
    if type(v) == "table" and not seen[v] then
      seen[v] = true
      table.insert(out, { name = name, t = v })
    end
  end
  for _, n in ipairs({ "ForeverGuide", "ForeverGuideDB", "ForeverGuide_DB", "ForeverGuideData",
                       "ForeverGuideSaved", "ForeverGuideAH", "ForeverGuideAuction",
                       "FG", "FGDB", "FG_DB", "FGuide" }) do
    add(n)
  end
  if FG.addonName then
    add(FG.addonName)
    add(FG.addonName .. "DB")
    add(FG.addonName .. "_DB")
  end
  for k, v in pairs(_G) do
    if type(k) == "string" and type(v) == "table" then
      local lk = k:lower()
      if lk:find("^forever") or lk:find("^fg_") or lk:find("^fguide") then add(k) end
    end
  end
  return out
end

local function testFunction(fn, owner)
  -- Testa med några vanliga föremål (Linen Cloth, Copper Ore, Peacebloom m.fl.)
  local probes = { 2589, 2770, 2447, 2318, 765, 2592, 4306, 2835 }
  for _, id in ipairs(probes) do
    local ok, v = pcall(fn, id)
    if ok and type(v) == "number" and v > 0 then return function(i) return fn(i) end end
    if owner then
      ok, v = pcall(fn, owner, id)
      if ok and type(v) == "number" and v > 0 then return function(i) return fn(owner, i) end end
    end
  end
end

local function findFunction(cands)
  for _, c in ipairs(cands) do
    local tables = { { c.t, c.name } }
    for _, sub in ipairs(SUBTABLES) do
      local ok, st = pcall(function() return c.t[sub] end)
      if ok and type(st) == "table" then table.insert(tables, { st, c.name .. "." .. sub }) end
    end
    for _, pair in ipairs(tables) do
      local t, path = pair[1], pair[2]
      for _, fname in ipairs(FUNC_NAMES) do
        local f = rawget(t, fname)
        if type(f) == "function" then
          local wrapped = testFunction(f, t)
          if wrapped then return wrapped, path .. "." .. fname end
        end
      end
    end
  end
end

-- Letar rekursivt efter den största tabellen som ser ut som [itemID] = pris.
-- Sökvägar som innehåller nuvarande realm/faktion får företräde.
local function findPriceTable(cands)
  local realm = (GetRealmName() or ""):lower()
  local faction = (UnitFactionGroup("player") or ""):lower()
  local best, bestPath, bestScore = nil, nil, 0
  local visited, budget = {}, 300000

  local function walk(t, path, depth, bonus)
    if visited[t] or depth > 6 or budget <= 0 then return end
    visited[t] = true
    local items, total = 0, 0
    local children = {}
    for k, v in pairs(t) do
      budget = budget - 1
      if budget <= 0 then break end
      total = total + 1
      if keyToItemID(k) and priceFromValue(v) then items = items + 1 end
      if type(v) == "table" then table.insert(children, { k, v }) end
    end
    if items >= 10 and items >= total * 0.6 then
      local score = items * bonus
      if score > bestScore then best, bestPath, bestScore = t, path, score end
      return -- tabellen är själv en pristabell, gå inte djupare
    end
    for _, kv in ipairs(children) do
      local k, v = kv[1], kv[2]
      local lk = tostring(k):lower()
      local b = bonus
      if realm ~= "" and lk:find(realm, 1, true) then b = b * 4 end
      if faction ~= "" and lk:find(faction, 1, true) then b = b * 2 end
      if lk:find("auction") or lk:find("price") or lk:find("ah") or lk:find("scan") then b = b * 1.5 end
      walk(v, path .. "." .. tostring(k), depth + 1, b)
    end
  end

  for _, c in ipairs(cands) do walk(c.t, c.name, 0, 1) end
  return best, bestPath
end

function PP:DetectForeverGuide()
  FG.addonName = findForeverGuideAddon()
  FG.loaded = FG.addonName and IsAddOnLoaded and IsAddOnLoaded(FG.addonName) or false
  FG.fn, FG.fnPath, FG.table, FG.tablePath = nil, nil, nil, nil
  local cands = candidateGlobals()
  FG.fn, FG.fnPath = findFunction(cands)
  if not FG.fn then FG.table, FG.tablePath = findPriceTable(cands) end
  FG.detected = true
  FG.candidates = cands
end

function PP:ForeverGuideStatus()
  if not FG.detected then self:DetectForeverGuide() end
  if not FG.addonName then return "|cffff0000addonet hittades inte|r" end
  local s = FG.addonName .. (FG.loaded and " (laddat)" or " (|cffff0000ej laddat|r)")
  if FG.fn then
    return s .. ", pris-API: |cff00ff00" .. FG.fnPath .. "|r"
  elseif FG.table then
    return s .. ", pristabell: |cff00ff00" .. FG.tablePath .. "|r"
  end
  return s .. ", |cffffaa00inga priser hittade än – skanna AH med Forever Guide, sedan /pp fgdump|r"
end

local function foreverPrice(itemID)
  if not FG.detected then PP:DetectForeverGuide() end
  if FG.fn then
    local ok, v = pcall(FG.fn, itemID)
    if ok and type(v) == "number" and v > 0 then return v end
    return nil
  end
  if FG.table then
    return priceFromValue(FG.table[itemID]) or priceFromValue(FG.table[tostring(itemID)])
        or priceFromValue(FG.table["item:" .. itemID])
  end
end

-- Felsökning: visa strukturen så att det går att anpassa addonet
function PP:DumpForeverGuide()
  self:DetectForeverGuide()
  self:Print("Forever Guide:", self:ForeverGuideStatus())
  local dump = { time = date("%Y-%m-%d %H:%M"), addon = FG.addonName, globals = {} }
  for _, c in ipairs(FG.candidates or {}) do
    local keys = {}
    local n = 0
    for k, v in pairs(c.t) do
      n = n + 1
      if n <= 25 then table.insert(keys, tostring(k) .. "=" .. type(v)) end
    end
    local line = string.format("%s (%d nycklar): %s", c.name, n, table.concat(keys, ", "))
    print("  " .. line)
    table.insert(dump.globals, line)
  end
  if FG.table then
    local n = 0
    for k, v in pairs(FG.table) do
      n = n + 1
      if n > 5 then break end
      local id = keyToItemID(k)
      print(string.format("  exempel: %s -> %s (%s)", tostring(k), self:Money(priceFromValue(v)),
        id and (GetItemInfo(id) or "?") or "?"))
    end
  end
  self.db.fgdump = dump
  self:Print("Sparat i ProfessionProfitDB.fgdump (WTF/Account/<konto>/SavedVariables/ProfessionProfit.lua efter /reload).")
end

---------------------------------------------------------------------------
-- Gemensamt
---------------------------------------------------------------------------
-- AH-pris per styck i koppar enligt Forever Guide, eller nil
function PP:GetAuctionPrice(itemID)
  return foreverPrice(itemID)
end

-- Billigaste sättet att få tag på en reagens: AH eller försäljare
function PP:GetReagentPrice(itemID)
  local ah = self:GetAuctionPrice(itemID)
  local vendor = self.db.vendor and self.db.vendor[itemID]
  if ah and vendor then return math.min(ah, vendor) end
  return ah or vendor
end

-- Räknar ut profit för ett recept. Returnerar en tabell eller nil om
-- föremålet inte har något AH-pris (t.ex. soulbound saker).
function PP:CalcRecipe(r)
  local sale = self:GetAuctionPrice(r.itemID)
  if not sale then return nil end
  local cost, missing = 0, {}
  for _, rg in ipairs(r.reagents) do
    local best
    for _, id in ipairs(rg.ids) do
      local p = self:GetReagentPrice(id)
      if p and (not best or p < best) then best = p end
    end
    if best then
      cost = cost + best * rg.count
    else
      table.insert(missing, rg.ids[1])
    end
  end
  local revenue = sale * (r.numMade or 1) * (1 - self.AH_CUT)
  return {
    sale = sale,
    cost = cost,
    revenue = revenue,
    profit = revenue - cost,
    margin = cost > 0 and (revenue - cost) / cost or nil,
    missing = missing,
  }
end

-- Bygger listan över alla kända recept sorterade efter profit
function PP:BuildProfitList()
  local list = {}
  for prof, data in pairs(self.char.professions or {}) do
    for _, r in pairs(data.recipes) do
      local c = self:CalcRecipe(r)
      if c and #c.missing == 0 and c.profit >= (self.db.minProfit or 0) then
        c.recipe = r
        c.profession = prof
        table.insert(list, c)
      end
    end
  end
  table.sort(list, function(a, b) return a.profit > b.profit end)
  return list
end

-- Forever Guides data kan ha ändrats efter en skanning hos auktionären
PP:On("AUCTION_HOUSE_CLOSED", function(self)
  FG.detected = false
  C_Timer.After(1, function() self:RefreshUI() end)
end)
