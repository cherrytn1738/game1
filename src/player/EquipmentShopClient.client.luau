local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local Remote = ReplicatedStorage:WaitForChild("EquipmentUpgrade")
while Player:GetAttribute("DataLoaded") ~= true do
 Player:GetAttributeChangedSignal("DataLoaded"):Wait()
end
local cash = Player:WaitForChild("leaderstats"):WaitForChild("Cash")

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
panel.Size = UDim2.fromOffset(620, 360)
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
label(panel, "Hint", "Your equipped gear. Equipment effects apply to your next hit.", 20, 45, 580, 24, 13)
local feedback = label(panel, "Feedback", "", 20, 319, 580, 30, 14)
feedback.TextWrapped = true

local rows = {}
local pending = false
local function effect(category, item)
 if category == "Bat" then return string.format("%.2fx launch power", item.powerMultiplier) end
 if category == "Ball" then return string.format("%.2fx Cash rewards", item.rewardMultiplier) end
 return string.format("%.2fx timing window width", item.timingScale)
end

local function refresh()
 balance.Text = string.format("%d Cash", cash.Value)
 for category, row in rows do
  local currentId = Player:GetAttribute("Equipped" .. category)
  local current = Equipment.Get(category, currentId)
  local nextItem = Equipment.GetNext(category, currentId)
  row.title.Text = string.upper(category) .. "  |  " .. current.displayName
  row.current.Text = "Current: " .. effect(category, current)
  row.next.Text = nextItem and ("Next: " .. nextItem.displayName .. " - " .. effect(category, nextItem))
   or "Maximum currently available equipment"
  row.button.Text = nextItem and string.format("PURCHASE\n%d Cash", nextItem.price) or "MAX EQUIPMENT"
  row.button.Active = nextItem ~= nil and not pending
  row.button.AutoButtonColor = row.button.Active
  row.button.BackgroundColor3 = nextItem and cash.Value >= nextItem.price
   and Color3.fromRGB(44, 118, 83) or Color3.fromRGB(67, 73, 87)
 end
end

for index, category in {"Bat", "Ball", "Tee"} do
 local row = Instance.new("Frame")
 row.Name = category
 row.Position = UDim2.fromOffset(20, 78 + (index - 1) * 80)
 row.Size = UDim2.fromOffset(580, 72)
 row.BackgroundColor3 = Color3.fromRGB(36, 42, 53)
 row.BorderSizePixel = 0
 row.Parent = panel
 Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
 local title = label(row, "Equipment", "", 12, 4, 380, 23, 15)
 local current = label(row, "Current", "", 12, 28, 380, 18, 13)
 local nextEffect = label(row, "Next", "", 12, 48, 380, 18, 13)
 nextEffect.TextColor3 = Color3.fromRGB(134, 217, 167)
 local button = Instance.new("TextButton")
 button.Name = "Upgrade"
 button.Position = UDim2.fromOffset(424, 10)
 button.Size = UDim2.fromOffset(144, 52)
 button.Font = Enum.Font.GothamBold
 button.TextSize = 14
 button.TextColor3 = Color3.new(1, 1, 1)
 button.Parent = row
 Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
 rows[category] = {title = title, current = current, next = nextEffect, button = button}
 button.Activated:Connect(function()
  if pending or Player:GetAttribute("BattingActive") then return end
  local currentId = Player:GetAttribute("Equipped" .. category)
  if not Equipment.GetNext(category, currentId) then return end
  pending = true
  feedback.Text = "Purchasing..."
  refresh()
  Remote:FireServer(category)
 end)
 Player:GetAttributeChangedSignal("Equipped" .. category):Connect(refresh)
end

Remote.OnClientEvent:Connect(function(success, message)
 pending = false
 feedback.Text = message
 feedback.TextColor3 = success and Color3.fromRGB(134, 217, 167) or Color3.fromRGB(255, 184, 126)
 refresh()
end)
cash:GetPropertyChangedSignal("Value"):Connect(refresh)
openButton.Activated:Connect(function()
 if Player:GetAttribute("BattingActive") then return end
 panel.Visible = not panel.Visible
 if panel.Visible then feedback.Text = "" refresh() end
end)
close.Activated:Connect(function() panel.Visible = false end)
local function battingChanged()
 local active = Player:GetAttribute("BattingActive") == true
 openButton.Visible = not active
 if active then panel.Visible = false end
end
Player:GetAttributeChangedSignal("BattingActive"):Connect(battingChanged)
local function resize()
 local camera = workspace.CurrentCamera
 if camera then
  scale.Scale = math.min(1, (camera.ViewportSize.X - 24) / 620, (camera.ViewportSize.Y - 100) / 360)
 end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
resize()
battingChanged()
refresh()
