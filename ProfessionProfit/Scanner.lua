-- Profession Profit: egen AH-skanning (reserv om Forever Guide inte hittas)
-- och inlärning av försäljarpriser för reagenser.
local _, PP = ...

local atAH = false
local scanning = false

PP:On("AUCTION_HOUSE_SHOW", function() atAH = true end)
PP:On("AUCTION_HOUSE_CLOSED", function() atAH = false; scanning = false end)

local function saveResults(prices, count)
  local key = PP:RealmKey()
  PP.db.prices[key] = PP.db.prices[key] or {}
  local dst, now, n = PP.db.prices[key], time(), 0
  for id, p in pairs(prices) do
    dst[id] = { p = p, t = now }
    n = n + 1
  end
  scanning = false
  PP:Print(string.format("Skanning klar: %d auktioner, %d olika föremål.", count, n))
  PP:RefreshUI()
end

local function addPrice(prices, itemID, buyout, count)
  if itemID and buyout and buyout > 0 and count and count > 0 then
    local unit = buyout / count
    if not prices[itemID] or unit < prices[itemID] then prices[itemID] = unit end
  end
end

-- Modernt AH-fönster: C_AuctionHouse.ReplicateItems
local function scanModern()
  local AH = C_AuctionHouse
  local function collect()
    local prices, total = {}, AH.GetNumReplicateItems()
    for i = 0, total - 1 do
      local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = AH.GetReplicateItemInfo(i)
      addPrice(prices, itemID, buyout, count)
    end
    saveResults(prices, total)
  end
  PP:OnceEvent("REPLICATE_ITEM_LIST_UPDATE", function()
    -- Vänta en stund så att all objektdata hinner laddas
    C_Timer.After(2, collect)
  end)
  AH.ReplicateItems()
end

-- Klassiskt AH-fönster: QueryAuctionItems med getAll
local function scanClassic()
  local _, canQueryAll = CanSendAuctionQuery()
  if not canQueryAll then
    scanning = false
    PP:Print("Full skanning är inte tillgänglig ännu (går bara var 15:e minut).")
    return
  end
  PP:OnceEvent("AUCTION_ITEM_LIST_UPDATE", function()
    C_Timer.After(1, function()
      local prices, total = {}, GetNumAuctionItems("list")
      for i = 1, total do
        local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
        addPrice(prices, itemID, buyout, count)
      end
      saveResults(prices, total)
    end)
  end)
  QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)
end

-- Kör en handler en gång för ett event
function PP:OnceEvent(event, fn)
  local f = CreateFrame("Frame")
  if not pcall(f.RegisterEvent, f, event) then return end
  f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    fn()
  end)
end

function PP:StartScan()
  if not atAH then
    self:Print("Du måste ha auktionshuset öppet för att skanna.")
    return
  end
  if scanning then
    self:Print("Skanning pågår redan...")
    return
  end
  scanning = true
  self:Print("Skannar auktionshuset, det kan ta en liten stund...")
  if C_AuctionHouse and C_AuctionHouse.ReplicateItems then
    scanModern()
  elseif QueryAuctionItems then
    scanClassic()
  else
    scanning = false
    self:Print("Hittar inget AH-API att skanna med.")
  end
end

-- Lär oss vad försäljare tar betalt, så att t.ex. tråd och flaskor
-- räknas med försäljarpris i stället för AH-pris.
PP:On("MERCHANT_SHOW", function(self)
  self.db.vendor = self.db.vendor or {}
  for i = 1, GetMerchantNumItems() do
    local price, quantity, numAvailable, extendedCost
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
      local info = C_MerchantFrame.GetItemInfo(i)
      if info then
        price, quantity, numAvailable, extendedCost = info.price, info.stackCount, info.numAvailable, info.hasExtendedCost
      end
    else
      local _
      _, _, price, quantity, numAvailable, _, extendedCost = GetMerchantItemInfo(i)
    end
    local link = GetMerchantItemLink(i)
    local id = link and tonumber(link:match("item:(%d+)"))
    -- Bara obegränsade varor som kostar guld (inte tokens/honor)
    if id and price and price > 0 and numAvailable == -1 and not extendedCost then
      self.db.vendor[id] = price / math.max(quantity or 1, 1)
    end
  end
end)
