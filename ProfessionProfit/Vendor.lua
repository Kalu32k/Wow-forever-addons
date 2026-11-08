-- Profession Profit: learns vendor prices for reagents.
local _, PP = ...

-- Learn what vendors charge, so that e.g. thread and vials are costed at
-- the vendor price instead of the AH price.
PP:On("MERCHANT_SHOW", function(self)
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
    -- Only unlimited goods that cost gold (not tokens/honor)
    if id and price and price > 0 and numAvailable == -1 and not extendedCost then
      self.db.vendor[id] = price / math.max(quantity or 1, 1)
    end
  end
end)
