-- Roll Tracker: window with all choices + small counts on the roll frames.
-- Works with Blizzard's roll frames and with ElvUI's (ElvUI_LootRollFrameN).
local _, RT = ...

local WIDTH, HEIGHT = 360, 300
local frame, scroll, content, text

local function choiceText(key, count)
  local c = RT.CHOICES[key]
  return string.format("|c%s%s: %d|r", c.color, c.label, count)
end

-- Builds the text for a drop
local function describeDrop(d)
  local lines = {}
  local status = ""
  if d.winner then
    status = "  |cff00ff00Winner: " .. RT:ClassColor(d.winner) .. "|r"
  elseif d.allPassed then
    status = "  |cff999999Everyone passed|r"
  elseif d.active then
    status = "  |cffffff00(in progress)|r"
  end
  table.insert(lines, (d.link or "?") .. status)

  local byChoice = {}
  for name, p in pairs(d.players) do
    if p.choice then
      byChoice[p.choice] = byChoice[p.choice] or {}
      table.insert(byChoice[p.choice], { name = name, roll = p.roll })
    end
  end
  local keys = {}
  for k in pairs(byChoice) do table.insert(keys, k) end
  table.sort(keys, function(a, b) return RT.CHOICES[a].order < RT.CHOICES[b].order end)
  for _, k in ipairs(keys) do
    local list = byChoice[k]
    table.sort(list, function(a, b) return (a.roll or 0) > (b.roll or 0) end)
    local names = {}
    for _, e in ipairs(list) do
      table.insert(names, RT:ClassColor(e.name) .. (e.roll and (" |cffffffff(" .. e.roll .. ")|r") or ""))
    end
    local c = RT.CHOICES[k]
    table.insert(lines, string.format("   |c%s%s (%d):|r %s", c.color, c.label, #list, table.concat(names, ", ")))
  end
  local waiting = RT:Waiting(d)
  if #waiting > 0 and not d.done then
    for i, n in ipairs(waiting) do waiting[i] = RT:ClassColor(n) end
    table.insert(lines, "   |cffff6666Waiting (" .. #waiting .. "):|r " .. table.concat(waiting, ", "))
  end
  return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Look: ElvUI if present, otherwise a regular Blizzard frame
---------------------------------------------------------------------------
local function skin(f)
  if RT:HasElvUI() and f.SetTemplate then
    if pcall(f.SetTemplate, f, "Transparent") then return true end
  end
  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.85)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  end
end

local function elvFont(fs, size)
  if not RT:HasElvUI() then return end
  local E = unpack(_G.ElvUI)
  if E and E.media and E.media.normFont then
    pcall(fs.SetFont, fs, E.media.normFont, size or 12, "OUTLINE")
  end
end

local function createUI()
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  frame = CreateFrame("Frame", "RollTrackerFrame", UIParent, template)
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  if frame.SetResizeBounds then frame:SetResizeBounds(250, 150, 800, 800)
  elseif frame.SetMinResize then frame:SetMinResize(250, 150) end
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    RT.db.pos = { point, relPoint, x, y, self:GetWidth(), self:GetHeight() }
  end)
  local pos = RT.db.pos
  if pos then
    frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    if pos[5] then frame:SetSize(pos[5], pos[6]) end
  else
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -250, 100)
  end
  skin(frame)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 10, -8)
  title:SetText("Roll Tracker")
  elvFont(title, 13)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScale(0.8)
  if RT:HasElvUI() then
    local E = unpack(_G.ElvUI)
    local S = E and E.GetModule and select(2, pcall(E.GetModule, E, "Skins"))
    if type(S) == "table" and S.HandleCloseButton then pcall(S.HandleCloseButton, S, close) end
  end

  local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  clear:SetSize(60, 18)
  clear:SetPoint("RIGHT", close, "LEFT", -2, 0)
  clear:SetText("Clear")
  clear:SetScript("OnClick", function() wipe(RT.drops); RT:RefreshUI() end)
  if RT:HasElvUI() then
    local E = unpack(_G.ElvUI)
    local S = E and E.GetModule and select(2, pcall(E.GetModule, E, "Skins"))
    if type(S) == "table" and S.HandleButton then pcall(S.HandleButton, S, clear) end
  end

  scroll = CreateFrame("ScrollFrame", "RollTrackerScroll", frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -28)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)

  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(WIDTH - 40, 10)
  scroll:SetScrollChild(content)

  text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("TOPLEFT")
  text:SetJustifyH("LEFT")
  text:SetJustifyV("TOP")
  text:SetSpacing(2)
  elvFont(text, 11)

  -- Drag the bottom-right corner to resize
  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(14, 14)
  grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    local point, _, relPoint, x, y = frame:GetPoint()
    RT.db.pos = { point, relPoint, x, y, frame:GetWidth(), frame:GetHeight() }
    RT:RefreshUI()
  end)

  frame:SetScript("OnShow", function() RT:RefreshUI() end)
  frame:Hide()
end

function RT:RefreshUI()
  self:UpdateBadges()
  if not frame or not frame:IsShown() then return end
  local w = frame:GetWidth() - 40
  content:SetWidth(w)
  text:SetWidth(w)
  if #self.drops == 0 then
    text:SetText("|cff999999No drops yet. When something is rolled on, everyone's choices show up here.|r")
  else
    local parts = {}
    for _, d in ipairs(self.drops) do table.insert(parts, describeDrop(d)) end
    text:SetText(table.concat(parts, "\n\n"))
  end
  content:SetHeight(text:GetStringHeight() + 10)
end

function RT:ShowUI()
  if not frame then createUI() end
  frame:Show()
end

function RT:ToggleUI()
  if not frame then createUI() end
  frame:SetShown(not frame:IsShown())
end

---------------------------------------------------------------------------
-- Counts directly on the roll frames (Blizzard or ElvUI)
---------------------------------------------------------------------------
local function rollFrames()
  local out = {}
  for i = 1, 8 do
    for _, name in ipairs({ "GroupLootFrame" .. i, "ElvUI_LootRollFrame" .. i }) do
      local f = _G[name]
      if f then table.insert(out, f) end
    end
  end
  local container = _G.GroupLootContainer
  if container and type(container.rollFrames) == "table" then
    for _, f in pairs(container.rollFrames) do
      if type(f) == "table" then table.insert(out, f) end
    end
  end
  return out
end

local function dropForRollID(rollID)
  for _, d in ipairs(RT.drops) do
    if d.rollID == rollID then return d end
  end
end

local function badgeTooltip(self)
  local d = self.drop
  if not d then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText("Roll Tracker")
  for line in describeDrop(d):gmatch("[^\n]+") do
    GameTooltip:AddLine(line, 1, 1, 1, true)
  end
  GameTooltip:Show()
end

function RT:UpdateBadges()
  for _, f in ipairs(rollFrames()) do
    local rollID = f.rollID
    local d = rollID and f:IsShown() and dropForRollID(rollID)
    if d then
      if not f.RollTrackerBadge then
        local b = CreateFrame("Frame", nil, f)
        b:SetSize(200, 14)
        b:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 2, 2)
        b:EnableMouse(true)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("LEFT")
        elvFont(b.text, 11)
        b:SetScript("OnEnter", badgeTooltip)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.RollTrackerBadge = b
      end
      local b = f.RollTrackerBadge
      local c = self:Counts(d)
      local parts = {}
      for _, k in ipairs({ "need", "greed", "de", "transmog", "pass" }) do
        if c[k] > 0 or k == "need" or k == "greed" or k == "pass" then
          table.insert(parts, choiceText(k, c[k]))
        end
      end
      if c.waiting > 0 then table.insert(parts, "|cffff6666Waiting: " .. c.waiting .. "|r") end
      b.text:SetText(table.concat(parts, "  "))
      b:SetWidth(b.text:GetStringWidth() + 4)
      b.drop = d
      b:Show()
    elseif f.RollTrackerBadge then
      f.RollTrackerBadge:Hide()
    end
  end
end

-- Roll frames are sometimes rebuilt after the event fires; update again a bit later
local ticker
local origChanged = RT.Changed
function RT:Changed()
  origChanged(self)
  if not ticker then
    ticker = C_Timer.NewTicker(0.5, function()
      RT:UpdateBadges()
      local anyActive = false
      for _, d in ipairs(RT.drops) do if d.active then anyActive = true break end end
      if not anyActive then ticker:Cancel(); ticker = nil end
    end)
  end
end
