-- The HUD's Robux buttons (MonetizationConfig): three Power purchases under the Level bar, and
-- the Auto Bat pass at the top centre, which becomes its ON / OFF switch once owned. This script
-- only opens Roblox's purchase prompts, asks the server to switch Auto Bat, and shows what the
-- server confirms (AutoBatOwned / AutoBatEnabled attributes, granted Power).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Storage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Monetization = require(Storage:WaitForChild("MonetizationConfig"))
local GameAudio = require(Storage:WaitForChild("GameAudio"))
local UI = require(script.Parent:WaitForChild("UICommon"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))
local Remote = Storage:WaitForChild("Monetization")
GameAudio.Preload({"Purchase"})

local AUTO_BAT = Monetization.AutoBat
local PRICE_GREEN = Color3.fromRGB(120, 255, 70)
-- Each Power button's face, as gradient keypoints (left to right): yellow, red, rainbow.
local FACES = {
 Power10K = {Color3.fromRGB(255, 230, 80), Color3.fromRGB(245, 168, 20)},
 Power100K = {Color3.fromRGB(255, 100, 100), Color3.fromRGB(212, 28, 48)},
 Power1M = {Color3.fromRGB(255, 50, 60), Color3.fromRGB(255, 150, 30), Color3.fromRGB(255, 225, 40),
  Color3.fromRGB(90, 220, 80), Color3.fromRGB(50, 170, 255), Color3.fromRGB(170, 70, 255)},
}
local AUTO_FACES = {
 buy = {Color3.fromRGB(255, 90, 95), Color3.fromRGB(205, 25, 45)},
 off = {Color3.fromRGB(165, 168, 178), Color3.fromRGB(108, 110, 122)},
 on = {Color3.fromRGB(125, 232, 75), Color3.fromRGB(48, 172, 40)},
}
-- The prices shown: the config's until Roblox's live price loads (only for real ids).
local prices = {}

local function loadPrice(id, infoType, onLoaded)
 if id <= 0 then return end
 task.spawn(function()
  local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
  if ok and typeof(info) == "table" and type(info.PriceInRobux) == "number" then
   prices[id] = info.PriceInRobux
   onLoaded()
  end
 end)
end

-- Paints a UICommon button's face with these colours (a vertical gradient for two, left to
-- right for more).
local function paint(button, colors)
 local gradient = button.Visual:FindFirstChildOfClass("UIGradient")
 local keypoints = {}
 for index, color in colors do
  table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
 end
 gradient.Color, gradient.Rotation = ColorSequence.new(keypoints), #colors > 2 and 0 or 90
end

-- Big outlined text over the button (not inside its face, so the icons can sit behind it).
local function text(parent, name, value, size, color)
 local label = UI.Label(parent, name, value, size, color)
 label.TextXAlignment, label.ZIndex, label.TextScaled = Enum.TextXAlignment.Center, 4, true
 local limit = Instance.new("UITextSizeConstraint")
 limit.MaxTextSize, limit.MinTextSize, limit.Parent = size, 8, label
 return label
end

-- A price tag: an optional word ("ONLY"), the Robux icon and the amount, in green, in a row.
local function priceTag(parent, size, lead)
 local tag = Instance.new("Frame")
 tag.Name, tag.BackgroundTransparency, tag.ZIndex = "Price", 1, 4
 tag.AutomaticSize = Enum.AutomaticSize.X
 local layout = Instance.new("UIListLayout")
 layout.FillDirection, layout.SortOrder = Enum.FillDirection.Horizontal, Enum.SortOrder.LayoutOrder
 layout.VerticalAlignment, layout.Padding = Enum.VerticalAlignment.Center, UDim.new(0, 3)
 layout.Parent = tag
 local function piece(name, order)
  local label = UI.Label(tag, name, "", size, PRICE_GREEN)
  label.AutomaticSize, label.Size, label.LayoutOrder, label.ZIndex = Enum.AutomaticSize.X, UDim2.new(0, 0, 1, 0), order, 4
  return label
 end
 local word = lead and piece("Lead", 1)
 if word then word.Text = lead end
 -- The icon has no outline of its own, so it sits on a slightly larger dark copy.
 local icon = UI.Icon(tag, "RobuxIcon", UI.Icons.Robux)
 icon.Size, icon.LayoutOrder, icon.ZIndex, icon.ImageColor3 = UDim2.fromOffset(size, size), 2, 4, UI.Colors.Border
 local fill = UI.Icon(icon, "Fill", UI.Icons.Robux)
 fill.AnchorPoint, fill.Position, fill.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.new(1, -5, 1, -5)
 fill.ZIndex, fill.ImageColor3 = 5, PRICE_GREEN
 local amount = piece("Amount", 3)
 tag.Parent = parent
 -- Sets the shown price: a number, or just SOON while the id is 0.
 return tag, function(id, price)
  icon.Visible = id > 0
  if word then word.Visible = id > 0 end
  amount.Text = id > 0 and UI.Number(prices[id] or price) or "SOON"
 end
end

-- Power purchases --------------------------------------------------------------------
-- A row under the Level bar, as wide as the bar; it is the bar's child, so it shows and hides
-- with it and follows its size on every screen (HUDClient leaves room for it).
local progression = Player:WaitForChild("PlayerGui"):WaitForChild("GameHUD"):WaitForChild("Root"):WaitForChild("Progression")
local ROW_GAP, ROW_HEIGHT, BUTTON_GAP = 10, 76, 10 -- HUDClient's PURCHASE_ROW_GAP / _HEIGHT
local row = Instance.new("Frame")
row.Name, row.BackgroundTransparency = "PowerPurchases", 1
row.Position, row.Size = UDim2.new(0, 0, 1, ROW_GAP), UDim2.new(1, 0, 0, ROW_HEIGHT)
row.Parent = progression
local setPrices = {}
local count = #Monetization.PowerProducts
for index, product in Monetization.PowerProducts do
 local button = UI.Button(row, product.id, "")
 button.Size = UDim2.new(1 / count, -BUTTON_GAP * (count - 1) / count, 1, 0)
 button.Position = UDim2.new((index - 1) / count, (index - 1) * BUTTON_GAP / count, 0, 0)
 paint(button, FACES[product.id] or FACES.Power10K)
 -- The Power bolt leans out behind the amount, over the button's top edge.
 local bolt = UI.Icon(button, "PowerIcon", UI.Icons.Power)
 bolt.AnchorPoint, bolt.Position, bolt.Size = Vector2.new(.5, .5), UDim2.new(.3, 0, .34, 0), UDim2.fromOffset(78, 78)
 bolt.Rotation, bolt.ZIndex = 16, 3
 local amount = text(button, "Amount", "+" .. UI.Compact(product.powerAmount), 42, UI.Colors.Text)
 amount.AnchorPoint, amount.Position, amount.Size = Vector2.new(.5, .5), UDim2.new(.5, 0, .44, 0), UDim2.new(1, -16, .66, 0)
 local tag, setPrice = priceTag(button, 26)
 tag.AnchorPoint, tag.Position, tag.Size = Vector2.new(1, 1), UDim2.new(1, -10, 1, -4), UDim2.fromOffset(0, 28)
 setPrices[product] = setPrice
 button.Activated:Connect(function()
  if product.developerProductId <= 0 then
   UI.Notify("Power purchases are coming soon!")
   return
  end
  MarketplaceService:PromptProductPurchase(Player, product.developerProductId)
 end)
end
local function refreshPrices()
 for product, setPrice in setPrices do setPrice(product.developerProductId, product.robuxPrice) end
end
refreshPrices()
for _, product in Monetization.PowerProducts do loadPrice(product.developerProductId, Enum.InfoType.Product, refreshPrices) end

-- The server confirms each purchase once it has added the Power.
Remote.OnClientEvent:Connect(function(kind, value)
 if kind == "PowerGranted" and type(value) == "number" then
  GameAudio.Play("Purchase")
  UI.Notify("+" .. UI.Compact(value) .. " POWER", "success")
 elseif kind == "AutoBatRefused" and type(value) == "string" then
  UI.Notify(value, "error")
 end
end)

-- Auto Bat ---------------------------------------------------------------------------
-- Red with "ONLY [R$] 25" until owned; then grey OFF / green ON.
local gui = UI.Screen("MonetizationGui", 13)
local autoBat = UI.Button(gui, "AutoBat", "")
autoBat.AnchorPoint, autoBat.Size = Vector2.new(.5, 0), UDim2.fromOffset(240, 70)
UI.Shrink(autoBat)
-- A bat leans across the button's left edge, behind the title.
local batIcon = UI.Icon(autoBat, "BatIcon", UI.Icons.Bat)
batIcon.AnchorPoint, batIcon.Position, batIcon.Size = Vector2.new(.5, .5), UDim2.new(0, 14, .45, 0), UDim2.fromOffset(84, 84)
batIcon.ZIndex = 3
local autoTitle = text(autoBat, "Title", "AUTO BAT", 34, UI.Colors.Text)
autoTitle.AnchorPoint, autoTitle.Position, autoTitle.Size = Vector2.new(.5, .5), UDim2.new(.5, 0, .38, 0), UDim2.new(1, -16, .52, 0)
local autoState = text(autoBat, "State", "", 24, UI.Colors.Text)
autoState.AnchorPoint, autoState.Position, autoState.Size = Vector2.new(.5, .5), UDim2.new(.5, 0, .78, 0), UDim2.new(1, -16, .36, 0)
local autoPrice, setAutoPrice = priceTag(autoBat, 22, "ONLY")
autoPrice.AnchorPoint, autoPrice.Position, autoPrice.Size = Vector2.new(.5, .5), UDim2.new(.5, 0, .79, 0), UDim2.fromOffset(0, 24)
local pending = false

local function refreshAutoBat()
 local owned = Player:GetAttribute("AutoBatOwned") == true
 local on = owned and Player:GetAttribute("AutoBatEnabled") == true
 paint(autoBat, AUTO_FACES[not owned and "buy" or on and "on" or "off"])
 autoPrice.Visible, autoState.Visible = not owned, owned
 setAutoPrice(AUTO_BAT.gamePassId, AUTO_BAT.robuxPrice)
 autoState.Text = on and "ON" or "OFF"
end

autoBat.Activated:Connect(function()
 if Player:GetAttribute("AutoBatOwned") ~= true then
  if AUTO_BAT.gamePassId <= 0 then
   UI.Notify("Auto Bat is coming soon!")
   return
  end
  MarketplaceService:PromptGamePassPurchase(Player, AUTO_BAT.gamePassId)
  return
 end
 -- One request at a time; the server's answer (AutoBatEnabled) clears it.
 if pending then return end
 pending = true
 Remote:FireServer("AutoBat", Player:GetAttribute("AutoBatEnabled") ~= true)
 task.delay(1, function() pending = false end)
end)

-- At the very top centre (the HUD's flight distance shows just under it). On phones it sits a
-- little left of centre, clear of the counters in the top-right corner. While the tutorial
-- banner shows (also top centre), it moves under the banner.
local function placeAutoBat()
 local narrow = gui.AbsoluteSize.X < 600
 local top = 6
 local tutorial = Player.PlayerGui:FindFirstChild("TutorialGui")
 local banner = tutorial and tutorial.Enabled and tutorial:FindFirstChild("Banner")
 if banner and banner.Visible then
  top = math.max(top, banner.AbsolutePosition.Y + banner.AbsoluteSize.Y + 6)
 end
 autoBat.Position = UDim2.new(.5, narrow and -60 or 0, 0, top)
end

local function refreshVisibility()
 local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
 -- None of these show during the tutorial (Interfaces.TutorialFocus).
 local focus = Interfaces.TutorialFocus()
 row.Visible = not focus
 autoBat.Visible = not focus and Player:GetAttribute("DataLoaded") == true and humanoid ~= nil and humanoid.Health > 0
  and not Interfaces.IsOpen() and Player:GetAttribute("WorldTraveling") ~= true
  and Player:GetAttribute("CinematicCamera") == nil and Player:GetAttribute("PortalJourney") == nil
  and Player:GetAttribute("GameFinale") == nil
 placeAutoBat()
end

for _, name in {"AutoBatOwned", "AutoBatEnabled"} do
 Player:GetAttributeChangedSignal(name):Connect(function()
  pending = false
  refreshAutoBat()
 end)
end
for _, name in {"DataLoaded", "WorldTraveling", "CinematicCamera", "PortalJourney", "GameFinale", "TutorialStep"} do
 Player:GetAttributeChangedSignal(name):Connect(refreshVisibility)
end
Interfaces.Changed:Connect(refreshVisibility)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeAutoBat)
local function characterAdded(character)
 refreshVisibility()
 local humanoid = character:WaitForChild("Humanoid", 10)
 if humanoid then humanoid.Died:Connect(refreshVisibility) end
end
Player.CharacterAdded:Connect(characterAdded)
Player.CharacterRemoving:Connect(function() task.defer(refreshVisibility) end)
if Player.Character then task.spawn(characterAdded, Player.Character) end
-- The tutorial banner moves under notifications and goes away when the tutorial ends.
task.spawn(function()
 while gui.Parent do
  placeAutoBat()
  task.wait(0.25)
 end
end)
loadPrice(AUTO_BAT.gamePassId, Enum.InfoType.GamePass, refreshAutoBat)
refreshAutoBat()
refreshVisibility()
