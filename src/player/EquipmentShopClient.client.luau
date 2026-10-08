local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local Remote = ReplicatedStorage:WaitForChild("EquipmentUpgrade")
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))
while Player:GetAttribute("DataLoaded") ~= true do
 Player:GetAttributeChangedSignal("DataLoaded"):Wait()
end
local cash = Player:WaitForChild("leaderstats"):WaitForChild("Cash")
local ownership = {}
for _, category in Equipment.CategoryOrder do
 ownership[category] = Player:WaitForChild(Equipment.Categories[category].ownedField)
end

local gui = Instance.new("ScreenGui")
gui.Name = "EquipmentShopGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Enabled = Player:GetAttribute("DataLoaded") == true
Player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
 gui.Enabled = Player:GetAttribute("DataLoaded") == true
end)
gui.Parent = Player:WaitForChild("PlayerGui")

local openButton = Instance.new("TextButton")
openButton.Name = "OpenShop"
openButton.AnchorPoint = Vector2.new(1, 0)
openButton.Position = UDim2.new(1, -20, 0, 80)
openButton.Size = UDim2.fromOffset(190, 40)
openButton.BackgroundColor3 = Color3.fromRGB(47, 99, 133)
openButton.Text = "EQUIPMENT SHOP"
openButton.Font = Enum.Font.GothamBold
openButton.TextSize = 14
openButton.TextColor3 = Color3.new(1, 1, 1)
openButton.Parent = gui
Instance.new("UICorner", openButton).CornerRadius = UDim.new(0, 8)

local panel = Instance.new("Frame")
panel.Name = "ShopPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.53)
panel.Size = UDim2.fromOffset(620, 450)
panel.BackgroundColor3 = Color3.fromRGB(25, 29, 38)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Active = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local scale = Instance.new("UIScale", panel)

local function label(parent, name, text, x, y, width, height, size)
 local item = Instance.new("TextLabel")
 item.Name = name
 item.Text = text
 item.Position = UDim2.fromOffset(x, y)
 item.Size = UDim2.fromOffset(width, height)
 item.BackgroundTransparency = 1
 item.TextColor3 = Color3.fromRGB(235, 240, 246)
 item.TextXAlignment = Enum.TextXAlignment.Left
 item.Font = Enum.Font.GothamMedium
 item.TextSize = size
 item.Parent = parent
 return item
end
label(panel, "Title", "EQUIPMENT", 20, 12, 280, 28, 21)
local balance = label(panel, "Balance", "", 310, 12, 235, 28, 17)
balance.TextXAlignment = Enum.TextXAlignment.Right
balance.TextColor3 = Color3.fromRGB(255, 220, 95)
local close = Instance.new("TextButton")
close.Name = "Close"
close.Position = UDim2.fromOffset(566, 12)
close.Size = UDim2.fromOffset(34, 28)
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextSize = 18
close.TextColor3 = Color3.new(1, 1, 1)
close.BackgroundColor3 = Color3.fromRGB(63, 70, 84)
close.Parent = panel
Instance.new("UICorner", close)
label(panel, "Hint", "Own equipment permanently. Equip any owned item for your next hit.", 20, 45, 580, 24, 13)
local feedback = label(panel, "Feedback", "", 20, 404, 580, 36, 14)
feedback.TextWrapped = true

local rows = {}
local tabs = {}
local selectedCategory = Equipment.CategoryOrder[1]
local pending = false
local list = Instance.new("ScrollingFrame")
list.Name = "EquipmentList"
list.Position = UDim2.fromOffset(20, 112)
list.Size = UDim2.fromOffset(580, 280)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.Parent = panel
local function effect(category, item)
 if category == "Bat" then return string.format("%.2fx launch power", item.powerMultiplier) end
 if category == "Ball" then return string.format("%.2fx Cash rewards", item.rewardMultiplier) end
 return string.format("%.2fx timing window width", item.timingScale)
end

local function refresh()
 balance.Text = string.format("%d Cash", cash.Value)
 local owned = ownership[selectedCategory]:GetAttributes()
 local equippedId = Player:GetAttribute("Equipped" .. selectedCategory)
 local nextItem = Equipment.GetNextPurchase(selectedCategory, owned)
 for category, tab in tabs do
  local name = Equipment.Categories[category].displayName
  tab.Text = category == selectedCategory and ("[ " .. name .. " ]") or name
 end
 for id, row in rows do
  local item = Equipment.Get(selectedCategory, id)
  local equipped = id == equippedId
  local isOwned = owned[id] == true
  local isNext = nextItem and nextItem.id == id
  row.title.Text = item.displayName
  row.current.Text = effect(selectedCategory, item)
  row.next.Text = equipped and "Equipped" or isOwned and "Owned"
   or isNext and "Next in progression" or "Not owned"
  row.button.Text = equipped and "EQUIPPED" or isOwned and "EQUIP"
   or isNext and string.format("PURCHASE\n%d Cash", item.price) or "LOCKED"
  row.button.Active = not equipped and (isOwned or isNext == true) and not pending
   and Interfaces.CanOpen()
  row.button.AutoButtonColor = row.button.Active
  row.button.BackgroundColor3 = row.button.Active and (isOwned or cash.Value >= item.price)
   and Color3.fromRGB(44, 118, 83) or Color3.fromRGB(67, 73, 87)
 end
end

local function showCategory(category)
 selectedCategory = category
 for _, child in list:GetChildren() do child:Destroy() end
 table.clear(rows)
 list.CanvasPosition = Vector2.zero
 local items = Equipment.GetItems(category)
 list.CanvasSize = UDim2.fromOffset(0, #items * 80)
 for index, item in items do
  local row = Instance.new("Frame")
  row.Name = item.id
  row.Position = UDim2.fromOffset(0, (index - 1) * 80)
  row.Size = UDim2.fromOffset(570, 72)
  row.BackgroundColor3 = Color3.fromRGB(36, 42, 53)
  row.BorderSizePixel = 0
  row.Parent = list
  Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
  local title = label(row, "Equipment", "", 12, 4, 380, 23, 15)
  local current = label(row, "Current", "", 12, 28, 380, 18, 13)
  local nextEffect = label(row, "Next", "", 12, 48, 380, 18, 13)
  nextEffect.TextColor3 = Color3.fromRGB(134, 217, 167)
  local button = Instance.new("TextButton")
  button.Name = "Upgrade"
  button.Position = UDim2.fromOffset(414, 10)
  button.Size = UDim2.fromOffset(144, 52)
  button.Font = Enum.Font.GothamBold
  button.TextSize = 14
  button.TextColor3 = Color3.new(1, 1, 1)
  button.Parent = row
  Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
  rows[item.id] = {title = title, current = current, next = nextEffect, button = button}
  button.Activated:Connect(function()
   if pending or not button.Active or not Interfaces.CanOpen() then return end
   local owned = ownership[category]:GetAttributes()
   local nextItem = Equipment.GetNextPurchase(category, owned)
   local action, value
   if owned[item.id] == true then
    action, value = "Equip", item.id
   elseif nextItem and nextItem.id == item.id then
    action, value = "Purchase", Player:GetAttribute("EquipmentPurchaseToken_" .. category)
   else return end
   if not value then return end
   pending = true
   feedback.Text = action == "Purchase" and "Purchasing..." or "Equipping..."
   refresh()
   Remote:FireServer(action, category, value)
  end)
 end
 refresh()
end

for index, category in Equipment.CategoryOrder do
 local tab = Instance.new("TextButton")
 tab.Name = category .. "Tab"
 tab.Position = UDim2.fromOffset(20 + (index - 1) * 196, 76)
 tab.Size = UDim2.fromOffset(188, 28)
 tab.Parent = panel
 tabs[category] = tab
 tab.Activated:Connect(function() showCategory(category) end)
 ownership[category].AttributeChanged:Connect(refresh)
 Player:GetAttributeChangedSignal("Equipped" .. category):Connect(refresh)
 Player:GetAttributeChangedSignal("EquipmentPurchaseToken_" .. category):Connect(refresh)
end

Remote.OnClientEvent:Connect(function(success, message)
 pending = false
 feedback.Text = message
 feedback.TextColor3 = success and Color3.fromRGB(134, 217, 167) or Color3.fromRGB(255, 184, 126)
 refresh()
end)
cash:GetPropertyChangedSignal("Value"):Connect(refresh)
openButton.Activated:Connect(function()
 if panel.Visible then panel.Visible = false else Interfaces.Open("Shop") end
end)
Interfaces.Register("Shop", function(visible)
 panel.Visible = visible
 if visible then feedback.Text = "" refresh() end
end)
close.Activated:Connect(function() panel.Visible = false end)
local function battingChanged()
 openButton.Visible = Interfaces.CanOpen() and not Interfaces.HasPhysicalHub()
 if not Interfaces.CanOpen() then panel.Visible = false end
 refresh()
end
Player:GetAttributeChangedSignal("BattingActive"):Connect(battingChanged)
Player:GetAttributeChangedSignal("HitActive"):Connect(battingChanged)
Player:GetAttributeChangedSignal("CurrentWorldId"):Connect(battingChanged)
Player.CharacterAdded:Connect(function(character)
 character:WaitForChild("Humanoid", 10)
 battingChanged()
end)
local function resize()
 local camera = workspace.CurrentCamera
 if camera then
  scale.Scale = math.min(1, (camera.ViewportSize.X - 24) / 620, (camera.ViewportSize.Y - 100) / 450)
 end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
resize()
battingChanged()
showCategory(selectedCategory)
