-- Profession Profit: reads which recipes the character knows.
-- The game only provides the recipe list while the profession window is
-- open, so we save it per character every time the window opens/updates.
local _, PP = ...

local function itemIDFromLink(link)
  if not link then return nil end
  local id = link:match("item:(%d+)")
  return id and tonumber(id) or nil
end

local function store(profName, recipes)
  if not profName or profName == "" or profName == "UNKNOWN" then return end
  if not next(recipes) then return end
  PP.char.professions[profName] = { updated = time(), recipes = recipes }
  PP:RefreshUI()
end

---------------------------------------------------------------------------
-- Classic API (Classic Era / TBC / Wrath): GetTradeSkill*
---------------------------------------------------------------------------
local function scanClassicTradeSkill()
  if not GetNumTradeSkills then return end
  local profName = GetTradeSkillLine and GetTradeSkillLine()
  -- Do not treat someone else's linked profession window as "yours"
  if IsTradeSkillLinked and IsTradeSkillLinked() then return end

  -- Expand all headers so we see every recipe
  if ExpandTradeSkillSubClass then pcall(ExpandTradeSkillSubClass, 0) end

  local recipes = {}
  for i = 1, GetNumTradeSkills() do
    local name, skillType = GetTradeSkillInfo(i)
    if name and skillType ~= "header" and skillType ~= "subheader" then
      local itemID = itemIDFromLink(GetTradeSkillItemLink(i))
      if itemID then
        local minMade, maxMade = GetTradeSkillNumMade(i)
        local r = {
          name = name,
          itemID = itemID,
          numMade = ((minMade or 1) + (maxMade or minMade or 1)) / 2,
          reagents = {},
        }
        local complete = true
        for j = 1, GetTradeSkillNumReagents(i) do
          local _, _, count = GetTradeSkillReagentInfo(i, j)
          local rid = itemIDFromLink(GetTradeSkillReagentItemLink(i, j))
          if rid and count then
            table.insert(r.reagents, { ids = { rid }, count = count })
          else
            complete = false -- data not loaded yet
          end
        end
        if complete then recipes[name] = r end
      end
    end
  end
  store(profName, recipes)
end

-- Classic Enchanting etc. use the "Craft" window
local function scanClassicCraft()
  if not GetNumCrafts then return end
  local profName = GetCraftDisplaySkillLine and GetCraftDisplaySkillLine()
  if not profName and GetCraftSkillLine then profName = GetCraftSkillLine(1) end
  local recipes = {}
  for i = 1, GetNumCrafts() do
    local name, _, craftType = GetCraftInfo(i)
    if name and craftType ~= "header" then
      -- Gear enchants produce no item and cannot be sold on the AH
      local itemID = itemIDFromLink(GetCraftItemLink and GetCraftItemLink(i))
      if itemID then
        local r = { name = name, itemID = itemID, numMade = 1, reagents = {} }
        local complete = true
        for j = 1, GetCraftNumReagents(i) do
          local _, _, count = GetCraftReagentInfo(i, j)
          local rid = itemIDFromLink(GetCraftReagentItemLink(i, j))
          if rid and count then
            table.insert(r.reagents, { ids = { rid }, count = count })
          else
            complete = false
          end
        end
        if complete then recipes[name] = r end
      end
    end
  end
  store(profName, recipes)
end

---------------------------------------------------------------------------
-- Modern API: C_TradeSkillUI
---------------------------------------------------------------------------
local function scanModern()
  local T = C_TradeSkillUI
  if not (T and T.GetAllRecipeIDs and T.GetRecipeSchematic) then return false end
  if T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return true end
  if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return true end
  if T.IsNPCCrafting and T.IsNPCCrafting() then return true end

  local profName
  local info = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
  if info then profName = info.professionName end
  if (not profName or profName == "") and T.GetChildProfessionInfo then
    local child = T.GetChildProfessionInfo()
    profName = child and (child.parentProfessionName or child.professionName)
  end
  if (not profName or profName == "") and GetTradeSkillLine then
    profName = GetTradeSkillLine()
  end

  local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
  local recipes = {}
  for _, recipeID in ipairs(T.GetAllRecipeIDs() or {}) do
    local rinfo = T.GetRecipeInfo(recipeID)
    if rinfo and rinfo.learned then
      local s = T.GetRecipeSchematic(recipeID, false)
      if s and s.outputItemID then
        local r = {
          name = rinfo.name or s.name,
          itemID = s.outputItemID,
          numMade = ((s.quantityMin or 1) + (s.quantityMax or s.quantityMin or 1)) / 2,
          reagents = {},
        }
        for _, slot in ipairs(s.reagentSlotSchematics or {}) do
          local required = slot.required
          if required == nil then required = (basic == nil or slot.reagentType == basic) end
          if required and slot.reagents and #slot.reagents > 0 then
            local ids = {}
            for _, rg in ipairs(slot.reagents) do
              if rg.itemID then table.insert(ids, rg.itemID) end
            end
            if #ids > 0 then
              table.insert(r.reagents, { ids = ids, count = slot.quantityRequired or 1 })
            end
          end
        end
        recipes[recipeID] = r
      end
    end
  end
  store(profName, recipes)
  return true
end

local pending = false
local function scheduleScan(kind)
  if pending then return end
  pending = true
  -- Wait a moment so the game can fill in the recipe list
  C_Timer.After(0.5, function()
    pending = false
    local ok, err = pcall(function()
      if kind == "craft" then
        scanClassicCraft()
      elseif not scanModern() then
        scanClassicTradeSkill()
      end
    end)
    if not ok then geterrorhandler()(err) end
  end)
end

PP:On("TRADE_SKILL_SHOW", function() scheduleScan("trade") end)
PP:On("TRADE_SKILL_UPDATE", function() scheduleScan("trade") end)
PP:On("TRADE_SKILL_LIST_UPDATE", function() scheduleScan("trade") end)
PP:On("CRAFT_SHOW", function() scheduleScan("craft") end)
PP:On("CRAFT_UPDATE", function() scheduleScan("craft") end)
