-- Presentation for the physical item displays built by ItemDisplay: a floating label per
-- pedestal (status, name, boost, price) and a title over each stage, prompt text that
-- matches this player's ownership, and slowly spinning items. Triggering a prompt only
-- requests the purchase/equip; the server validates it through the same EquipmentUpgrade
-- remote as the Equipment menu (whose listener shows the result as a notification).
local Player = game.Players.LocalPlayer
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local Remote = ReplicatedStorage:WaitForChild("EquipmentUpgrade")
local UI = require(script.Parent:WaitForChild("UICommon"))

local PEDESTAL_TAG = "ItemPedestal" -- matches ItemDisplay.PedestalTag
local LABEL_SIZE = UDim2.fromScale(6, 3.2) -- studs; fits the 6.4-stud pedestal spacing
local TITLE_SIZE = UDim2.fromScale(22, 5.2)
local LABEL_DISTANCE = 120
local SPIN_SPEED = math.rad(45) -- per second
local BOB_HEIGHT, BOB_SPEED = 0.25, 1.6

local bound = {} -- pedestal -> {item, labels, prompt, model, base, phase}
local cash

local function billboard(adornee, name, size)
 local gui = Instance.new("BillboardGui")
 gui.Name, gui.Size, gui.Adornee = name, size, adornee
 gui.LightInfluence, gui.MaxDistance, gui.ResetOnSpawn = 0, LABEL_DISTANCE, false
 gui.Parent = adornee
 local layout = Instance.new("UIListLayout")
 layout.SortOrder, layout.HorizontalAlignment = Enum.SortOrder.LayoutOrder, Enum.HorizontalAlignment.Center
 layout.VerticalAlignment, layout.Parent = Enum.VerticalAlignment.Bottom, gui
 return gui
end

local function line(gui, name, order, height, color)
 local label = UI.Label(gui, name, "", 40, color)
 label.Size, label.LayoutOrder = UDim2.fromScale(1, height), order
 label.TextXAlignment, label.TextScaled = Enum.TextXAlignment.Center, true
 return label
end

-- "×1.3", not "×1.30".
local function multiplier(value)
 return "×" .. (UI.Number(value, 2):gsub("0+$", ""):gsub("%.$", ""))
end

local function boostText(item)
 if item.category == "Bat" then return multiplier(item.powerGainMultiplier) .. " POWER" end
 return multiplier(item.rewardMultiplier) .. " CASH"
end

local function ownership(category)
 local folder = Player:FindFirstChild(Equipment.Categories[category].ownedField)
 return folder and folder:GetAttributes() or {}
end

-- equipped / owned / next / locked, plus whether the player can afford it.
local function itemState(item)
 local owned = ownership(item.category)
 if Player:GetAttribute("Equipped" .. item.category) == item.id then return "equipped" end
 if owned[item.id] then return "owned" end
 local nextItem = Equipment.GetNextPurchase(item.category, owned)
 if nextItem and nextItem.id == item.id then return "next" end
 return "locked"
end

local function refresh()
 local ready = Player:GetAttribute("DataLoaded") == true and cash ~= nil
 for _, entry in bound do
  local item, labels, prompt = entry.item, entry.labels, entry.prompt
  local state = ready and itemState(item) or "loading"
  local affordable = ready and cash.Value >= item.price
  local status, statusColor, price, priceColor, action
  if state == "equipped" then
   status, statusColor, price, priceColor, action = "EQUIPPED", UI.Colors.Accent, "OWNED", UI.Colors.Text, "Equipped"
  elseif state == "owned" then
   status, statusColor, price, priceColor, action = "OWNED", UI.Colors.Text, "OWNED", UI.Colors.Text, "Equip"
  elseif state == "next" then
   status, statusColor = "FOR SALE", UI.Colors.Gold
   price, priceColor, action = UI.Number(item.price) .. " Cash", affordable and UI.Colors.Gold or UI.Colors.Error, "Buy"
  else
   status, statusColor = state == "loading" and "" or "LOCKED", UI.Colors.Error
   price, priceColor, action = UI.Number(item.price) .. " Cash", UI.Colors.Muted, "Locked"
  end
  labels.status.Text, labels.status.TextColor3 = status, statusColor
  labels.price.Text, labels.price.TextColor3 = price, priceColor
  prompt.ActionText = action
  prompt.Enabled = ready and state ~= "equipped"
 end
end

local function request(entry)
 local item = entry.item
 if Player:GetAttribute("DataLoaded") ~= true or not cash then return end
 local state = itemState(item)
 if state == "owned" then
  Remote:FireServer("Equip", item.category, item.id)
 elseif state == "next" then
  if cash.Value < item.price then
   UI.Notify("You need " .. UI.Number(item.price - cash.Value) .. " more Cash.", "error")
   return
  end
  local token = Player:GetAttribute("EquipmentPurchaseToken_" .. item.category)
  if token then Remote:FireServer("Purchase", item.category, token) end
 elseif state == "locked" then
  -- Older saves may own a later item without this one; purchases only move forward.
  local owned = ownership(item.category)
  local skipped = false
  for _, other in Equipment.GetItems(item.category) do
   if owned[other.id] and other.order > item.order then skipped = true end
  end
  if skipped then
   UI.Notify("You already own a better one, so this one is no longer for sale.", "error")
   return
  end
  local previous
  for _, other in Equipment.GetItems(item.category) do
   if other.nextId == item.id then previous = other end
  end
  UI.Notify("Buy the " .. (previous and previous.displayName or "previous item") .. " first.", "error")
 end
end

local function bindTitle(display)
 local anchor = display:FindFirstChild("TitleAnchor")
 local attachment = anchor and anchor:FindFirstChild("Title")
 if not attachment or attachment:FindFirstChild("TitleLabel") then return end
 local gui = billboard(attachment, "TitleLabel", TITLE_SIZE)
 line(gui, "Title", 1, .66, UI.Colors.Gold).Text = display:GetAttribute("Title") or ""
 line(gui, "Subtitle", 2, .34, UI.Colors.Text).Text = display:GetAttribute("Subtitle") or ""
end

local function bind(pedestal)
 if bound[pedestal] then return end
 local item = Equipment.Get(pedestal:GetAttribute("Category"), pedestal:GetAttribute("ItemId"))
 local slab = pedestal:WaitForChild("Pedestal", 10)
 local model = pedestal:WaitForChild("Item", 10)
 local attachment = slab and slab:WaitForChild("Label", 10)
 local prompt = slab and slab:WaitForChild("Prompt", 10)
 if not item or not model or not attachment or not prompt or not pedestal.Parent then return end
 local gui = billboard(attachment, "ItemLabel", LABEL_SIZE)
 local labels = {
  status = line(gui, "Status", 1, .2, UI.Colors.Text),
  name = line(gui, "ItemName", 2, .22, UI.Colors.Text),
  boost = line(gui, "Boost", 3, .34, UI.Colors.Gold),
  price = line(gui, "Price", 4, .24, UI.Colors.Gold),
 }
 labels.name.Text, labels.boost.Text = item.displayName, boostText(item)
 local entry = {item = item, labels = labels, prompt = prompt, model = model,
  base = model:GetPivot(), phase = item.order * 1.3}
 bound[pedestal] = entry
 prompt.Triggered:Connect(function() request(entry) end)
 if pedestal.Parent then bindTitle(pedestal.Parent) end
 refresh()
end

local function unbind(pedestal)
 local entry = bound[pedestal]
 if not entry then return end
 bound[pedestal] = nil
 -- Restore the streamed copy's resting pose in case it comes back without being rebuilt.
 if entry.model.Parent then entry.model:PivotTo(entry.base) end
end

CollectionService:GetInstanceAddedSignal(PEDESTAL_TAG):Connect(function(pedestal) task.spawn(bind, pedestal) end)
CollectionService:GetInstanceRemovedSignal(PEDESTAL_TAG):Connect(unbind)
for _, pedestal in CollectionService:GetTagged(PEDESTAL_TAG) do task.spawn(bind, pedestal) end

RunService.RenderStepped:Connect(function()
 local now = os.clock()
 for _, entry in bound do
  local angle = now * SPIN_SPEED + entry.phase
  local bob = math.sin(now * BOB_SPEED + entry.phase) * BOB_HEIGHT
  entry.model:PivotTo(entry.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, angle, 0))
 end
end)

Player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh)
task.spawn(function()
 while Player:GetAttribute("DataLoaded") ~= true do Player:GetAttributeChangedSignal("DataLoaded"):Wait() end
 cash = Player:WaitForChild("leaderstats"):WaitForChild("Cash")
 cash:GetPropertyChangedSignal("Value"):Connect(refresh)
 for _, category in Equipment.CategoryOrder do
  Player:WaitForChild(Equipment.Categories[category].ownedField).AttributeChanged:Connect(refresh)
  Player:GetAttributeChangedSignal("Equipped" .. category):Connect(refresh)
 end
 refresh()
end)
