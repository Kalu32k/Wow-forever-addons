-- Profession Profit: the window that lists the most profitable recipes.
local _, PP = ...

local ROW_HEIGHT = 20
local NUM_ROWS = 18
local WIDTH = 640

local frame, rows, scroll, statusText
local data = {}

local function itemLink(itemID, fallback)
  local _, link = GetItemInfo(itemID)
  return link or fallback or ("item:" .. itemID)
end

local function createRow(parent, i)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(WIDTH - 50, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", 8, -((i - 1) * ROW_HEIGHT))
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

  local function col(x, w, justify)
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", x, 0)
    fs:SetWidth(w)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
  end
  row.rank = col(0, 24, "RIGHT")
  row.name = col(30, 220)
  row.prof = col(255, 90)
  row.cost = col(345, 85, "RIGHT")
  row.sale = col(430, 85, "RIGHT")
  row.profit = col(515, 75, "RIGHT")

  row:SetScript("OnEnter", function(self)
    local e = self.entry
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. e.recipe.itemID)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("AH price (Forever Guide)", PP:Money(e.sale), 1, 1, 1, 1, 1, 1)
    if (e.recipe.numMade or 1) ~= 1 then
      GameTooltip:AddDoubleLine("Made per craft", tostring(e.recipe.numMade), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine("Revenue after 5% AH cut", PP:Money(e.revenue), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine("Reagents:", 1, 0.82, 0)
    for _, rg in ipairs(e.recipe.reagents) do
      local id = rg.ids[1]
      local p = PP:GetReagentPrice(id)
      GameTooltip:AddDoubleLine(string.format("  %dx %s", rg.count, GetItemInfo(id) or ("#" .. id)),
        PP:Money(p and p * rg.count), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine("Total cost", PP:Money(e.cost), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Profit", PP:Money(e.profit), 1, 1, 1, 0, 1, 0)
    GameTooltip:AddLine("Shift-click: search the AH / link in chat", 0.5, 0.5, 0.5)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row:SetScript("OnClick", function(self)
    local e = self.entry
    if not e then return end
    local link = itemLink(e.recipe.itemID, e.recipe.name)
    if IsShiftKeyDown() then
      -- Search the AH if it is open, otherwise link in chat
      if AuctionHouseFrame and AuctionHouseFrame:IsShown() and AuctionHouseFrame.SearchBar then
        AuctionHouseFrame.SearchBar.SearchBox:SetText(e.recipe.name)
        AuctionHouseFrame.SearchBar:StartSearch()
      elseif BrowseName and AuctionFrame and AuctionFrame:IsShown() then
        BrowseName:SetText(GetItemInfo(e.recipe.itemID) or e.recipe.name)
        if AuctionFrameBrowse_Search then AuctionFrameBrowse_Search() end
      elseif ChatEdit_InsertLink then
        ChatEdit_InsertLink(link)
      end
    end
  end)
  return row
end

local function update()
  if not frame or not frame:IsShown() then return end
  local offset = FauxScrollFrame_GetOffset(scroll)
  for i = 1, NUM_ROWS do
    local row = rows[i]
    local e = data[i + offset]
    row.entry = e
    if e then
      local r = e.recipe
      local _, _, quality = GetItemInfo(r.itemID)
      local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
      local name = GetItemInfo(r.itemID) or r.name
      if color then name = color.hex .. name .. "|r" end
      if (r.numMade or 1) > 1 then name = name .. string.format(" |cffaaaaaax%g|r", r.numMade) end
      row.rank:SetText(i + offset .. ".")
      row.name:SetText(name)
      row.prof:SetText(e.profession)
      row.cost:SetText(PP:Money(e.cost))
      row.sale:SetText(PP:Money(e.revenue))
      row.profit:SetText((e.profit >= 0 and "|cff00ff00" or "|cffff4444") .. PP:Money(e.profit):gsub("|r", "|r" .. (e.profit >= 0 and "|cff00ff00" or "|cffff4444")) .. "|r")
      row:Show()
    else
      row:Hide()
    end
  end
  FauxScrollFrame_Update(scroll, #data, NUM_ROWS, ROW_HEIGHT)
end

local function createUI()
  frame = CreateFrame("Frame", "ProfessionProfitFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(WIDTH, NUM_ROWS * ROW_HEIGHT + 110)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)
  frame:SetFrameStrata("HIGH")
  tinsert(UISpecialFrames, "ProfessionProfitFrame") -- close with Escape

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.title:SetPoint("TOP", 0, -5)
  frame.title:SetText("Profession Profit - most profitable recipes you know")

  local header = CreateFrame("Frame", nil, frame)
  header:SetSize(WIDTH - 50, 16)
  header:SetPoint("TOPLEFT", 12, -32)
  local function h(x, w, text, justify)
    local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", x + 8, 0)
    fs:SetWidth(w)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(text)
  end
  h(0, 24, "#", "RIGHT")
  h(30, 220, "Item")
  h(255, 90, "Profession")
  h(345, 85, "Cost", "RIGHT")
  h(430, 85, "Revenue", "RIGHT")
  h(515, 75, "Profit", "RIGHT")

  scroll = CreateFrame("ScrollFrame", "ProfessionProfitScroll", frame, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -50)
  scroll:SetPoint("BOTTOMRIGHT", -32, 48)
  scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, update)
  end)

  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", scroll, "TOPLEFT")
  content:SetSize(WIDTH - 50, NUM_ROWS * ROW_HEIGHT)
  rows = {}
  for i = 1, NUM_ROWS do rows[i] = createRow(content, i) end

  local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  refresh:SetSize(100, 22)
  refresh:SetPoint("BOTTOMLEFT", 12, 12)
  refresh:SetText("Refresh")
  refresh:SetScript("OnClick", function()
    PP.FG.detected = false
    PP:RefreshUI()
  end)

  statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  statusText:SetPoint("LEFT", refresh, "RIGHT", 10, 0)
  statusText:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
  statusText:SetJustifyH("LEFT")
  statusText:SetWordWrap(true)

  frame:SetScript("OnShow", function() PP:RefreshUI() end)
end

function PP:RefreshUI()
  if not frame or not frame:IsShown() then return end
  data = self:BuildProfitList()
  local nRecipes = 0
  for _, p in pairs(self.char.professions) do
    for _ in pairs(p.recipes) do nRecipes = nRecipes + 1 end
  end
  local msg
  if not self.FG.detected then self:DetectForeverGuide() end
  if not (self.FG.fn or self.FG.table) then
    msg = "No prices found from Forever Guide. Scan the AH with Forever Guide and press Refresh."
  elseif nRecipes == 0 then
    msg = "No recipes saved. Open each of your profession windows once."
  elseif #data == 0 then
    msg = "No profitable recipes found. Scan the AH with Forever Guide and press Refresh."
  else
    msg = string.format("%d profitable of %d known recipes. Prices: Forever Guide. Min profit: %s",
      #data, nRecipes, self:Money(self.db.minProfit))
  end
  statusText:SetText(msg)
  update()
end

function PP:ToggleUI()
  if not frame then createUI() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end

-- Item names load asynchronously; redraw when they arrive
PP:On("GET_ITEM_INFO_RECEIVED", function()
  if frame and frame:IsShown() and not PP.redrawPending then
    PP.redrawPending = true
    C_Timer.After(0.3, function()
      PP.redrawPending = false
      update()
    end)
  end
end)
