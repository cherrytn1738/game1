-- The Shop (the HUD's Shop tile): one scrolling window of Robux offers, in five sections: the
-- Starter Pack, Multipliers (the next tier of the permanent Power and Cash multipliers), Cash
-- packs, Boosts (juices) and Training Grounds (Dragon's Lair, plus the premium ground in the
-- player's World). Everything shown comes from config (MonetizationConfig,
-- TrainingConfig) and server-set attributes; this only opens Roblox's purchase prompts (or the
-- Training Ground "Buy" request) and shows what the server confirms. Ids still 0 read SOON.
-- (Bats and Balls are bought with Cash only at their hub display pedestals.)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local Storage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Monetization = require(Storage:WaitForChild("MonetizationConfig"))
local Training = require(Storage:WaitForChild("TrainingConfig"))
local Juice = require(Storage:WaitForChild("JuiceConfig"))
local JuiceModels = require(Storage:WaitForChild("JuiceModels"))
local Equipment = require(Storage:WaitForChild("EquipmentConfig"))
local GameAudio = require(Storage:WaitForChild("GameAudio"))
local UI = require(script.Parent:WaitForChild("UICommon"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))
local Remote = Storage:WaitForChild("Monetization")
GameAudio.Preload({"Purchase"})

local PACK = Monetization.StarterPack
local PRICE_GREEN = Color3.fromRGB(120, 255, 70)
local CASH_GOLD = Color3.fromRGB(255, 214, 60)
local CARD_FACES = {
 starter = {Color3.fromRGB(255, 120, 200), Color3.fromRGB(130, 70, 230)},
 cash = {Color3.fromRGB(90, 210, 110), Color3.fromRGB(30, 140, 70)},
 powerMultiplier = {Color3.fromRGB(255, 190, 60), Color3.fromRGB(225, 100, 30)},
 cashMultiplier = {Color3.fromRGB(60, 200, 175), Color3.fromRGB(25, 115, 140)},
 bundle = {Color3.fromRGB(110, 120, 255), Color3.fromRGB(60, 170, 90)},
 juice = {Color3.fromRGB(80, 130, 230), Color3.fromRGB(40, 70, 170)},
 ground = {Color3.fromRGB(255, 150, 60), Color3.fromRGB(200, 50, 50)},
 worldGround = {Color3.fromRGB(150, 110, 255), Color3.fromRGB(70, 50, 190)},
}

local _, panel, show, window = UI.ShowcaseMenu("StoreGui", "Shop", Interfaces.CloseAll,
 {maxWidth = 900, maxHeight = 640, theme = "Purple"})
local visible = false

local well = UI.ShowcaseFrame(window.box, "Offers", window.theme.well, 18)
well.Position, well.Size = UDim2.fromOffset(18, 58), UDim2.new(1, -36, 1, -76)
local scroll = Instance.new("ScrollingFrame")
scroll.Name, scroll.BackgroundTransparency, scroll.BorderSizePixel = "List", 1, 0
scroll.Position, scroll.Size = UDim2.fromOffset(6, 6), UDim2.new(1, -12, 1, -12)
scroll.ScrollBarThickness, scroll.ScrollBarImageColor3 = 8, UI.Showcase.CardLight
scroll.CanvasSize, scroll.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.Parent = well
local list = Instance.new("UIListLayout")
list.Padding, list.SortOrder, list.HorizontalAlignment = UDim.new(0, 12), Enum.SortOrder.LayoutOrder, Enum.HorizontalAlignment.Center
list.Parent = scroll
local padding = Instance.new("UIPadding")
for _, side in {"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight"} do padding[side] = UDim.new(0, 14) end
padding.Parent = scroll

-- Building blocks -------------------------------------------------------------------
local function corner(parent, radius)
 local object = Instance.new("UICorner")
 object.CornerRadius, object.Parent = UDim.new(0, radius), parent
end

local function label(parent, name, text, size, color)
 local object = UI.ShowcaseLabel(parent, name, text, size, color)
 object.TextScaled = true
 local limit = Instance.new("UITextSizeConstraint")
 limit.MaxTextSize, limit.MinTextSize, limit.Parent = size, 10, object
 return object
end

local function heading(order, text)
 local title = label(scroll, "Heading", "~ " .. text .. " ~", 40, Color3.fromRGB(255, 225, 120))
 title.LayoutOrder, title.Size, title.TextXAlignment = order, UDim2.new(1, 0, 0, 46), Enum.TextXAlignment.Center
 return title
end

-- A coloured card with the thick outline and a faint checker.
local function card(parent, name, colors)
 local frame = UI.ShowcaseFrame(parent, name, Color3.new(1, 1, 1), 16)
 UI.Gradient(frame, colors[1], colors[2])
 UI.Damier(frame, Color3.new(1, 1, 1), 26, NumberSequence.new(.93, .86)).ZIndex = 1
 return frame
end

-- A grid holder whose columns follow the list's width (see layout()).
local grids = {}
local function grid(order, name, height, columns)
 local holder = Instance.new("Frame")
 holder.Name, holder.BackgroundTransparency, holder.LayoutOrder = name, 1, order
 holder.Size, holder.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
 holder.Parent = scroll
 local cells = Instance.new("UIGridLayout")
 cells.CellPadding, cells.SortOrder = UDim2.fromOffset(12, 12), Enum.SortOrder.LayoutOrder
 cells.HorizontalAlignment, cells.Parent = Enum.HorizontalAlignment.Center, holder
 table.insert(grids, {layout = cells, height = height, columns = columns})
 return holder
end

-- A model in a ViewportFrame, turned by `turn` and seen from `from` (a direction).
local function viewport(parent, model, turn, from)
 local frame = Instance.new("ViewportFrame")
 frame.Name, frame.BackgroundTransparency, frame.ZIndex = "Picture", 1, 3
 frame.Ambient, frame.LightColor, frame.LightDirection = Color3.fromRGB(205, 205, 205), Color3.new(1, 1, 1), Vector3.new(-1, -1.5, -1)
 model:PivotTo(turn)
 model.Parent = frame
 local box, size = model:GetBoundingBox()
 local camera = Instance.new("Camera")
 camera.FieldOfView = 30
 local reach = math.max(size.X, size.Y, size.Z) / 2 / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05 + math.max(size.X, size.Z) / 2
 camera.CFrame = CFrame.lookAt(box.Position + from.Unit * reach, box.Position)
 camera.Parent, frame.CurrentCamera = frame, camera
 frame.Parent = parent
 return frame
end

local function juicePicture(parent, id)
 return viewport(parent, JuiceModels.Build(Juice.Get(id)), CFrame.Angles(0, math.rad(-28), 0), Vector3.new(0, .15, -1))
end

-- The Catastrophe Bat leaning, its cat face and ears toward the camera: the barrel's upper half
-- (or, closeUp, just the cat head), since the whole thin bat would be too small to read.
local function batPicture(parent, closeUp)
 local folder = Storage:FindFirstChild("BatModels")
 local template = folder and folder:FindFirstChild(PACK.batId)
 if not template then return nil end
 local frame = Instance.new("ViewportFrame")
 frame.Name, frame.BackgroundTransparency, frame.ZIndex = "Picture", 1, 3
 frame.Ambient, frame.LightColor, frame.LightDirection = Color3.fromRGB(215, 215, 215), Color3.new(1, 1, 1), Vector3.new(-.6, -1, -1)
 local model = template:Clone()
 model:PivotTo(CFrame.Angles(0, 0, math.rad(closeUp and -12 or -28)))
 model.Parent = frame
 local camera = Instance.new("Camera")
 camera.FieldOfView = 30
 -- Framed on the model's own parts (its published pivot is not at the hand): the eyes for the
 -- head, or from the grip up to the head for the bat.
 local eyes = model:FindFirstChild(PACK.batId .. "__Eyes", true)
 local grip = model:FindFirstChild(PACK.batId .. "__Grip", true)
 local box, size = model:GetBoundingBox()
 local tip, base = eyes and eyes.Position or box.Position, grip and grip.Position or box.Position
 local focus = closeUp and tip + (tip - base).Unit * .12 or base:Lerp(tip, .6)
 local span = closeUp and .5 or math.max((tip - base).Magnitude * .55, size.Y * .3)
 local reach = span / math.tan(math.rad(camera.FieldOfView / 2))
 camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, reach), focus)
 camera.Parent, frame.CurrentCamera = frame, camera
 frame.Parent = parent
 return frame
end

-- A Robux buy button: green with the Robux icon and price, grey SOON while the id is 0, grey
-- OWNED (or ownedText) once bought. set(id, price, owned, ownedText).
local buttons = {}
local function robuxButton(parent, name, onBuy)
 local button = UI.ShowcaseButton(parent, name)
 button.ZIndex = 4
 local icon = UI.Icon(button.Visual, "RobuxIcon", UI.Icons.Robux)
 icon.AnchorPoint, icon.Size, icon.ZIndex = Vector2.new(1, .5), UDim2.fromOffset(30, 30), 4
 local caption = button.Visual.Caption
 local function placeIcon()
  icon.Position = UDim2.new(.5, -caption.TextBounds.X / 2 - 4 + 17, .5, -3)
  caption.Position = UDim2.fromOffset(icon.Visible and 25 or 8, 0)
 end
 caption:GetPropertyChangedSignal("TextBounds"):Connect(placeIcon)
 local state = {}
 local function set(id, price, owned, ownedText)
  state.id, state.owned = id, owned
  icon.Visible = not owned and id > 0
  if owned then
   UI.SetShowcaseButton(button, ownedText or "OWNED", "Grey", false)
  elseif id <= 0 then
   UI.SetShowcaseButton(button, "SOON", "Grey", true)
  else
   UI.SetShowcaseButton(button, UI.Number(price), "Green", true)
  end
  placeIcon()
 end
 button.Activated:Connect(function()
  if state.owned then return end
  if not state.id or state.id <= 0 then
   UI.Notify("This is coming soon!")
   return
  end
  onBuy()
 end)
 table.insert(buttons, button)
 return button, set
end

-- A square Gift button (a wrapped present) for a Shop item; it opens the player picker. Grey with
-- SOON while the gift product's id is 0 (in Studio the picker still opens, to try the flow; the
-- server refuses such a gift). itemName is what the confirmation calls the item.
local openPicker -- (the picker, below)
local function giftButton(parent, giftId, itemName)
 local gift = Monetization.GetGiftById(giftId)
 local button = UI.ShowcaseButton(parent, "Gift")
 button.ZIndex = 4
 local soon = gift.developerProductId <= 0
 UI.SetShowcaseButton(button, "", soon and "Grey" or "Blue", true)
 local present = UI.Icon(button.Visual, "GiftIcon", UI.Icons.Rewards)
 present.AnchorPoint, present.Position, present.ZIndex = Vector2.new(.5, .5), UDim2.fromScale(.5, soon and .4 or .46), 4
 present.Size = UDim2.fromScale(soon and .6 or .74, soon and .6 or .74)
 if soon then
  local note = label(button.Visual, "Soon", "SOON", 16)
  note.AnchorPoint, note.Position, note.Size, note.ZIndex = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -6), UDim2.new(1, -4, 0, 16), 5
  note.TextXAlignment = Enum.TextXAlignment.Center
 end
 -- A small "Gift" tip above it while the mouse is over it.
 local tip = label(button, "Tip", "Gift", 20)
 tip.AnchorPoint, tip.Position, tip.Size, tip.ZIndex = Vector2.new(.5, 1), UDim2.new(.5, 0, 0, -2), UDim2.fromOffset(70, 22), 6
 tip.TextXAlignment, tip.Visible = Enum.TextXAlignment.Center, false
 button.MouseEnter:Connect(function() tip.Visible = true end)
 button.MouseLeave:Connect(function() tip.Visible = false end)
 button.Activated:Connect(function()
  if soon and not RunService:IsStudio() then
   UI.Notify("Gifting this is coming soon!")
   return
  end
  openPicker(gift, itemName)
 end)
 return button
end

-- Prices the buttons show: the config's, until Roblox's live price loads.
local livePrices = {}
local refreshers = {}
local function refresh()
 for _, update in refreshers do update() end
end
local function loadPrice(id, infoType)
 if id <= 0 or livePrices[id] then return end
 livePrices[id] = false
 task.spawn(function()
  local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
  if ok and typeof(info) == "table" and type(info.PriceInRobux) == "number" then
   livePrices[id] = info.PriceInRobux
   refresh()
  end
 end)
end
local function price(id, fallback)
 return livePrices[id] or fallback
end

-- A reward line on the Starter Pack: an icon (or picture) and its text.
local function reward(parent, order, text, picture)
 local chip = Instance.new("Frame")
 chip.Name, chip.BackgroundColor3, chip.BackgroundTransparency, chip.LayoutOrder = "Reward", Color3.new(0, 0, 0), .65, order
 corner(chip, 12)
 chip.Parent = parent
 local art = picture(chip)
 art.AnchorPoint, art.Position, art.Size, art.ZIndex = Vector2.new(0, .5), UDim2.new(0, 6, .5, 0), UDim2.fromOffset(44, 44), 3
 local line = label(chip, "Text", text, 24)
 line.Position, line.Size, line.ZIndex = UDim2.fromOffset(56, 0), UDim2.new(1, -62, 1, 0), 3
 return chip
end

-- Starter Pack ------------------------------------------------------------------------
heading(1, "PACK")
local starter = card(scroll, "StarterPack", CARD_FACES.starter)
starter.LayoutOrder = 2
local starterArt = Instance.new("Frame")
starterArt.Name, starterArt.BackgroundTransparency = "BatArt", 1
starterArt.Parent = starter
local starterTitle = label(starter, "Title", "STARTER PACK", 46, Color3.fromRGB(255, 240, 150))
starterTitle.ZIndex = 3
local rewards = Instance.new("Frame")
rewards.Name, rewards.BackgroundTransparency = "Rewards", 1
rewards.Parent = starter
local rewardGrid = Instance.new("UIGridLayout")
rewardGrid.CellPadding, rewardGrid.SortOrder, rewardGrid.Parent = UDim2.fromOffset(8, 8), Enum.SortOrder.LayoutOrder, rewards
local bat = Equipment.Get("Bat", PACK.batId)
local function icon(image) return function(parent) return UI.Icon(parent, "Icon", image) end end
local juiceId = next(PACK.juices)
reward(rewards, 1, "+" .. UI.Compact(PACK.power) .. " POWER", icon(UI.Icons.Power))
reward(rewards, 2, "+" .. PACK.rebirths .. " REBIRTH", icon(UI.Icons.Rebirth))
reward(rewards, 3, string.upper(Juice.Get(juiceId).displayName) .. " x" .. PACK.juices[juiceId], function(parent) return juicePicture(parent, juiceId) end)
reward(rewards, 4, string.upper(bat.displayName), function(parent)
 return batPicture(parent, true) or UI.Icon(parent, "Icon", UI.Icons.Bat)
end)
local starterButton, setStarter = robuxButton(starter, "Buy", function()
 MarketplaceService:PromptGamePassPurchase(Player, PACK.gamePassId)
end)
local starterGift = giftButton(starter, "GiftStarterPack", "Starter Pack")
table.insert(refreshers, function()
 setStarter(PACK.gamePassId, price(PACK.gamePassId, PACK.robuxPrice), Player:GetAttribute("StarterPackOwned") == true)
end)
loadPrice(PACK.gamePassId, Enum.InfoType.GamePass)

-- Multipliers -------------------------------------------------------------------------
-- One card per permanent multiplier, showing the next tier as the change it makes ("1.5x → 1.6x")
-- from the server-set tier count (PowerMultiplierTier / CashMultiplierTier). Buy only asks the
-- server for the next tier; the server picks it and opens the prompt. Not giftable.
local function multiplierText(value) return string.format("%gx", value) end
local MULTIPLIER_CARDS = {
 {kind = "Power", title = "POWER MULTIPLIER", icon = UI.Icons.Power, faces = CARD_FACES.powerMultiplier,
  effect = "Training, hit & offline Power"},
 {kind = "Cash", title = "CASH MULTIPLIER", icon = UI.Icons.Cash, faces = CARD_FACES.cashMultiplier,
  effect = "Cash from every hit & Cash Pack"},
}
heading(3, "MULTIPLIERS")
local multiplierGrid = grid(4, "Multipliers", 200, {2, 2, 1})
for index, info in MULTIPLIER_CARDS do
 local ladder = Monetization.Multipliers[info.kind]
 local frame = card(multiplierGrid, info.kind .. "Multiplier", info.faces)
 frame.LayoutOrder = index
 local art = UI.Icon(frame, "Icon", info.icon)
 art.AnchorPoint, art.Position, art.Size, art.ZIndex = Vector2.zero, UDim2.fromOffset(12, 14), UDim2.fromOffset(78, 78), 3
 local name = label(frame, "Name", info.title, 28)
 name.Position, name.Size, name.ZIndex = UDim2.fromOffset(102, 10), UDim2.new(1, -112, 0, 32), 3
 local change = label(frame, "Change", "", 34, PRICE_GREEN)
 change.Position, change.Size, change.ZIndex = UDim2.fromOffset(102, 44), UDim2.new(1, -112, 0, 36), 3
 local tierLine = label(frame, "Tier", "", 18, CASH_GOLD)
 tierLine.Position, tierLine.Size, tierLine.ZIndex = UDim2.fromOffset(102, 82), UDim2.new(1, -112, 0, 22), 3
 local effect = label(frame, "Effect", info.effect, 16, UI.Colors.Muted)
 effect.Position, effect.Size, effect.ZIndex = UDim2.fromOffset(12, 106), UDim2.new(1, -24, 0, 20), 3
 local button, set = robuxButton(frame, "Buy", function()
  Remote:FireServer("BuyMultiplier", info.kind)
 end)
 button.AnchorPoint, button.Position, button.Size = Vector2.new(1, 1), UDim2.new(1, -10, 1, -10), UDim2.new(1, -20, 0, 54)
 table.insert(refreshers, function()
  local owned = Player:GetAttribute(info.kind .. "MultiplierTier") or 0
  local current = Monetization.GetMultiplier(info.kind, owned)
  local number, nextTier = Monetization.GetNextMultiplierTier(info.kind, owned)
  if nextTier then
   change.Text = multiplierText(current) .. " → " .. multiplierText(nextTier.multiplier)
   tierLine.Text = string.format("TIER %d OF %d • PERMANENT", number, #ladder)
   set(nextTier.developerProductId, price(nextTier.developerProductId, nextTier.robuxPrice), false)
  else
   change.Text = "MAX " .. multiplierText(current)
   tierLine.Text = string.format("ALL %d TIERS OWNED", #ladder)
   set(0, 0, true, "MAXED")
  end
 end)
 for _, tier in ladder do loadPrice(tier.developerProductId, Enum.InfoType.Product) end
end

-- Cash Packs --------------------------------------------------------------------------
heading(5, "CASH PACKS")
local cashGrid = grid(6, "CashPacks", 214, {4, 2, 1})
for index, product in Monetization.CashProducts do
 local frame = card(cashGrid, product.id, CARD_FACES.cash)
 frame.LayoutOrder = index
 local name = label(frame, "Name", string.upper(product.displayName), 24)
 name.Position, name.Size, name.ZIndex, name.TextXAlignment = UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 28), 3, Enum.TextXAlignment.Center
 local cashIcon = UI.Icon(frame, "CashIcon", UI.Icons.Cash)
 cashIcon.AnchorPoint, cashIcon.Position, cashIcon.Size, cashIcon.ZIndex = Vector2.new(.5, 0), UDim2.new(.5, 0, 0, 38), UDim2.fromOffset(58, 58), 3
 local amount = label(frame, "Amount", "", 32, CASH_GOLD)
 amount.Position, amount.Size, amount.ZIndex, amount.TextXAlignment = UDim2.fromOffset(8, 98), UDim2.new(1, -16, 0, 34), 3, Enum.TextXAlignment.Center
 local hits = label(frame, "Hits", "about " .. product.hits .. " hits", 18, UI.Colors.Muted)
 hits.Position, hits.Size, hits.ZIndex, hits.TextXAlignment = UDim2.fromOffset(8, 130), UDim2.new(1, -16, 0, 20), 3, Enum.TextXAlignment.Center
 local button, set = robuxButton(frame, "Buy", function()
  -- The server fixes the pack's Cash for this purchase, then opens the prompt.
  Remote:FireServer("BuyCash", product.id)
 end)
 button.AnchorPoint, button.Position, button.Size = Vector2.new(1, 1), UDim2.new(1, -10, 1, -8), UDim2.new(1, -78, 0, 48)
 local gift = giftButton(frame, "Gift" .. product.id, product.displayName)
 gift.AnchorPoint, gift.Position, gift.Size = Vector2.new(0, 1), UDim2.new(0, 10, 1, -8), UDim2.fromOffset(48, 48)
 table.insert(refreshers, function()
  -- The same formula the server pays with, from the server's display copies.
  local level = Player:GetAttribute("Level") or 1
  amount.Text = "+$" .. UI.Compact(Monetization.GetCashPackReward(product, level, Player:GetAttribute("CurrentWorldId"),
   Player:GetAttribute("EquippedBat"), Monetization.GetMultiplier("Cash", Player:GetAttribute("CashMultiplierTier") or 0)))
  set(product.developerProductId, price(product.developerProductId, product.robuxPrice), false)
 end)
 loadPrice(product.developerProductId, Enum.InfoType.Product)
end

-- Boosts --------------------------------------------------------------------------------
heading(7, "BOOSTS")
local bundleProduct, singles = nil, {}
for _, product in Monetization.JuiceProducts do
 local kinds = 0
 for _ in product.juices do kinds += 1 end
 if kinds > 1 then bundleProduct = product else table.insert(singles, product) end
end
local bundle
if bundleProduct then
 bundle = card(scroll, bundleProduct.id, CARD_FACES.bundle)
 bundle.LayoutOrder = 8
 local art = Instance.new("Frame")
 art.Name, art.BackgroundTransparency, art.Position, art.Size = "Art", 1, UDim2.fromOffset(10, 8), UDim2.new(0, 190, 1, -16)
 art.Parent = bundle
 local index, contents = 0, {}
 for id, count in bundleProduct.juices do
  index += 1
  local picture = juicePicture(art, id)
  picture.Position, picture.Size = UDim2.fromScale((index - 1) * .5, 0), UDim2.fromScale(.5, 1)
  table.insert(contents, count .. "x " .. string.upper(Juice.Get(id).displayName))
 end
 local title = label(bundle, "Title", string.upper(bundleProduct.displayName), 36, Color3.fromRGB(255, 240, 150))
 title.Position, title.Size, title.ZIndex = UDim2.fromOffset(210, 14), UDim2.new(1, -440, 0, 40), 3
 local body = label(bundle, "Contents", table.concat(contents, "\n"), 22)
 body.Position, body.Size, body.ZIndex = UDim2.fromOffset(210, 58), UDim2.new(1, -440, 0, 60), 3
 local button, set = robuxButton(bundle, "Buy", function()
  MarketplaceService:PromptProductPurchase(Player, bundleProduct.developerProductId)
 end)
 button.AnchorPoint, button.Position, button.Size = Vector2.new(1, .5), UDim2.new(1, -16, .5, 0), UDim2.fromOffset(200, 66)
 giftButton(bundle, "Gift" .. bundleProduct.id, bundleProduct.displayName)
 table.insert(refreshers, function()
  set(bundleProduct.developerProductId, price(bundleProduct.developerProductId, bundleProduct.robuxPrice), false)
 end)
 loadPrice(bundleProduct.developerProductId, Enum.InfoType.Product)
end
local juiceGrid = grid(9, "Juices", 170, {2, 2, 1})
for index, product in singles do
 local id = next(product.juices)
 local definition = Juice.Get(id)
 local frame = card(juiceGrid, product.id, {definition.appearance.roof, definition.appearance.body})
 frame.LayoutOrder = index
 local picture = juicePicture(frame, id)
 picture.Position, picture.Size = UDim2.fromOffset(6, 8), UDim2.new(0, 110, 1, -16)
 local name = label(frame, "Name", string.upper(definition.displayName), 30)
 name.Position, name.Size, name.ZIndex = UDim2.fromOffset(122, 10), UDim2.new(1, -132, 0, 34), 3
 local effect = label(frame, "Effect", string.format("%gx %s", definition.multiplier,
  string.upper(Juice.Effects[definition.effect].displayName)), 26, PRICE_GREEN)
 effect.Position, effect.Size, effect.ZIndex = UDim2.fromOffset(122, 46), UDim2.new(1, -132, 0, 28), 3
 local duration = label(frame, "Duration", math.floor(definition.durationSeconds / 60) .. " MIN", 22, CASH_GOLD)
 duration.Position, duration.Size, duration.ZIndex = UDim2.fromOffset(122, 76), UDim2.new(1, -132, 0, 24), 3
 local button, set = robuxButton(frame, "Buy", function()
  MarketplaceService:PromptProductPurchase(Player, product.developerProductId)
 end)
 button.AnchorPoint, button.Position, button.Size = Vector2.new(1, 1), UDim2.new(1, -10, 1, -10), UDim2.new(1, -192, 0, 50)
 local gift = giftButton(frame, "Gift" .. product.id, product.displayName)
 gift.AnchorPoint, gift.Position, gift.Size = Vector2.new(0, 1), UDim2.new(0, 122, 1, -10), UDim2.fromOffset(50, 50)
 table.insert(refreshers, function()
  set(product.developerProductId, price(product.developerProductId, product.robuxPrice), false)
 end)
 loadPrice(product.developerProductId, Enum.InfoType.Product)
end

-- Training Grounds ------------------------------------------------------------------------
heading(10, "TRAINING GROUNDS")
local PREVIEW_HEIGHT = 176
local groundGrid = grid(11, "TrainingGrounds", PREVIEW_HEIGHT + 184, {2, 2, 1})
local groundCards, groundRefreshers = {}, {}
local trainingRemote
table.insert(refreshers, function()
 for _, update in groundRefreshers do update() end
end)

-- The ground's own cage (ReplicatedStorage.TrainingGroundModels, published by the server, pivoted
-- at its plate), seen from above one front corner like a postcard. Only that copy is in the frame.
local function groundPicture(parent, ground)
 local frame = Instance.new("ViewportFrame")
 frame.Name, frame.BackgroundColor3, frame.BackgroundTransparency, frame.ZIndex = "Preview", Color3.fromRGB(150, 200, 255), .35, 3
 frame.Ambient, frame.LightColor, frame.LightDirection = Color3.fromRGB(190, 190, 200), Color3.new(1, 1, 1), Vector3.new(-.4, -1, -.6)
 corner(frame, 12)
 frame.Parent = parent
 local folder = Storage:FindFirstChild("TrainingGroundModels")
 local template = folder and folder:FindFirstChild(ground.id)
 if not template then
  local fallback = UI.Icon(frame, "Icon", UI.Icons.Training)
  fallback.AnchorPoint, fallback.Position, fallback.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.6, .6)
  return frame
 end
 local model = template:Clone()
 model:PivotTo(CFrame.identity)
 model.Parent = frame
 local box, size = model:GetBoundingBox()
 local camera = Instance.new("Camera")
 camera.FieldOfView = 40
 -- From the side and a little above, near enough that the cage fills the wide frame.
 local direction = Vector3.new(1, .55, .55).Unit
 local reach = math.max(size.X, size.Y, size.Z) * .86
 camera.CFrame = CFrame.lookAt(box.Position + direction * reach, box.Position)
 camera.Parent, frame.CurrentCamera = frame, camera
 return frame
end

local function buildGrounds()
 for _, frame in groundCards do frame:Destroy() end
 table.clear(groundCards)
 table.clear(groundRefreshers)
 for index, ground in Monetization.GetShopGrounds(Player:GetAttribute("CurrentWorldId")) do
  local pass = Training.GetPassGround(ground)
  local everyWorld = ground.id == Monetization.EveryWorldGround
  local frame = card(groundGrid, ground.id, everyWorld and CARD_FACES.ground or CARD_FACES.worldGround)
  frame.LayoutOrder = index
  table.insert(groundCards, frame)
  local preview = groundPicture(frame, ground)
  preview.Position, preview.Size = UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, PREVIEW_HEIGHT)
  local top = PREVIEW_HEIGHT + 14
  local name = label(frame, "Name", string.upper(ground.displayName), 32)
  name.Position, name.Size, name.ZIndex = UDim2.fromOffset(12, top), UDim2.new(1, -24, 0, 36), 3
  local multiplier = label(frame, "Multiplier", UI.Number(ground.powerMultiplier) .. "x POWER", 28, PRICE_GREEN)
  multiplier.Position, multiplier.Size, multiplier.ZIndex = UDim2.fromOffset(12, top + 38), UDim2.new(1, -24, 0, 30), 3
  local note = label(frame, "Where", everyWorld and "In every World" or "This World's premium ground", 18, UI.Colors.Muted)
  note.Position, note.Size, note.ZIndex = UDim2.fromOffset(12, top + 70), UDim2.new(1, -24, 0, 22), 3
  local button, set = robuxButton(frame, "Buy", function()
   -- The server checks the pass and opens Roblox's prompt (TrainingService).
   if trainingRemote then trainingRemote:FireServer("Buy", ground.id) end
  end)
  button.AnchorPoint, button.Position, button.Size = Vector2.new(1, 1), UDim2.new(1, -10, 1, -10), UDim2.new(1, -86, 0, 54)
  -- Owning it yourself never stops you gifting it.
  local gift = giftButton(frame, Monetization.GetGroundGift(ground).id, ground.displayName)
  gift.AnchorPoint, gift.Position, gift.Size = Vector2.new(0, 1), UDim2.new(0, 10, 1, -10), UDim2.fromOffset(54, 54)
  local function update()
   set(pass.gamePassId, price(pass.gamePassId, pass.robuxPrice), Player:GetAttribute("TrainingPass_" .. pass.id) == true)
  end
  table.insert(groundRefreshers, update)
  update()
  loadPrice(pass.gamePassId, Enum.InfoType.GamePass)
 end
end

-- Gift player picker -------------------------------------------------------------------
-- Over the Shop: the other players in this server (headshot, display name, @username), then a
-- confirmation. GIFT sends only the gift id and the recipient's UserId; the server checks both
-- players and the item, saves who receives it, then opens the BUYER's Roblox prompt.
local picker = Instance.new("Frame")
picker.Name, picker.BackgroundColor3, picker.BackgroundTransparency = "GiftPicker", Color3.new(0, 0, 0), .45
picker.Size, picker.ZIndex, picker.Visible, picker.Active = UDim2.fromScale(1, 1), 50, false, true
picker.Parent = panel
local pickerWindow = card(picker, "Window", {window.theme.top, window.theme.bottom})
pickerWindow.AnchorPoint, pickerWindow.Position, pickerWindow.Size = Vector2.new(.5, .5), UDim2.new(.5, 0, .5, 22), UDim2.new(1, -36, 1, -100)
local pickerLimit = Instance.new("UISizeConstraint")
pickerLimit.MaxSize, pickerLimit.Parent = Vector2.new(500, 470), pickerWindow
local pickerTitle = label(pickerWindow, "Title", "GIFT TO A PLAYER", 36, Color3.fromRGB(255, 240, 150))
pickerTitle.Position, pickerTitle.Size, pickerTitle.ZIndex = UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 40), 3
pickerTitle.TextXAlignment = Enum.TextXAlignment.Center
local pickerItem = label(pickerWindow, "Item", "", 22, UI.Colors.Muted)
pickerItem.Position, pickerItem.Size, pickerItem.ZIndex = UDim2.fromOffset(16, 50), UDim2.new(1, -32, 0, 24), 3
pickerItem.TextXAlignment = Enum.TextXAlignment.Center
local playerList = Instance.new("ScrollingFrame")
playerList.Name, playerList.BackgroundTransparency, playerList.BorderSizePixel, playerList.ZIndex = "Players", 1, 0, 3
playerList.Position, playerList.Size = UDim2.fromOffset(14, 84), UDim2.new(1, -28, 1, -170)
playerList.ScrollBarThickness, playerList.CanvasSize, playerList.AutomaticCanvasSize = 8, UDim2.new(), Enum.AutomaticSize.Y
playerList.Parent = pickerWindow
local rowLayout = Instance.new("UIListLayout")
rowLayout.Padding, rowLayout.SortOrder, rowLayout.Parent = UDim.new(0, 8), Enum.SortOrder.Name, playerList
local emptyNote = label(pickerWindow, "Empty", "NO OTHER PLAYERS IN THIS SERVER", 26, UI.Colors.Muted)
emptyNote.AnchorPoint, emptyNote.Position, emptyNote.Size, emptyNote.ZIndex = Vector2.new(.5, .5), UDim2.fromScale(.5, .48), UDim2.new(1, -40, 0, 60), 3
emptyNote.TextXAlignment, emptyNote.TextWrapped = Enum.TextXAlignment.Center, true
local confirmView = Instance.new("Frame")
confirmView.Name, confirmView.BackgroundTransparency, confirmView.ZIndex = "Confirm", 1, 3
confirmView.Position, confirmView.Size = UDim2.fromOffset(14, 84), UDim2.new(1, -28, 1, -170)
confirmView.Parent = pickerWindow
local confirmHead = Instance.new("ImageLabel")
confirmHead.Name, confirmHead.BackgroundColor3, confirmHead.BackgroundTransparency, confirmHead.ZIndex = "Headshot", Color3.new(0, 0, 0), .6, 3
confirmHead.AnchorPoint, confirmHead.Position, confirmHead.Size = Vector2.new(.5, 0), UDim2.new(.5, 0, 0, 0), UDim2.fromOffset(96, 96)
corner(confirmHead, 48)
confirmHead.Parent = confirmView
local confirmText = label(confirmView, "Question", "", 30)
confirmText.Position, confirmText.Size, confirmText.ZIndex = UDim2.fromOffset(0, 104), UDim2.new(1, 0, 0, 70), 3
confirmText.TextXAlignment, confirmText.TextWrapped = Enum.TextXAlignment.Center, true
local confirmPrice = label(confirmView, "Price", "", 28, PRICE_GREEN)
confirmPrice.Position, confirmPrice.Size, confirmPrice.ZIndex = UDim2.fromOffset(0, 178), UDim2.new(1, 0, 0, 32), 3
confirmPrice.TextXAlignment = Enum.TextXAlignment.Center
local closeButton = UI.ShowcaseButton(pickerWindow, "Close")
UI.SetShowcaseButton(closeButton, "CLOSE", "Red", true)
local confirmButton = UI.ShowcaseButton(pickerWindow, "Send")
local cancelButton = UI.ShowcaseButton(pickerWindow, "Cancel")
UI.SetShowcaseButton(cancelButton, "CANCEL", "Grey", true)
for _, button in {closeButton, confirmButton, cancelButton} do
 button.AnchorPoint, button.ZIndex = Vector2.new(.5, 1), 4
end
closeButton.Position, closeButton.Size = UDim2.new(.5, 0, 1, -12), UDim2.new(.6, 0, 0, 62)
confirmButton.Position, confirmButton.Size = UDim2.new(.27, 0, 1, -12), UDim2.new(.44, 0, 0, 62)
cancelButton.Position, cancelButton.Size = UDim2.new(.73, 0, 1, -12), UDim2.new(.44, 0, 0, 62)

local pickGift, pickName, target, targetOwns

-- Whether another player already has a gift's permanent item (from their server-set attributes;
-- the server checks again).
local function recipientOwns(gift, other)
 if gift.item.starterPack then return other:GetAttribute("StarterPackOwned") == true end
 if gift.item.entitlement then
  return other:GetAttribute("TrainingPass_" .. Monetization.GiftEntitlements[gift.item.entitlement]) == true
 end
 return false
end

local function headshot(image, userId)
 task.spawn(function()
  local ok, content = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
  if ok and image.Parent then image.Image = content end
 end)
end

local showList
local function showConfirm(other)
 if other.Parent ~= Players then showList() return end
 target = other
 targetOwns = recipientOwns(pickGift, other)
 playerList.Visible, emptyNote.Visible, closeButton.Visible = false, false, false
 confirmView.Visible, confirmButton.Visible, cancelButton.Visible = true, true, true
 pickerTitle.Text = "CONFIRM GIFT"
 confirmHead.Image = ""
 headshot(confirmHead, other.UserId)
 confirmText.Text = string.format("Gift %s to %s?", pickName, other.DisplayName)
 confirmPrice.Text = targetOwns and "ALREADY OWNED" or (UI.Number(price(pickGift.developerProductId, pickGift.robuxPrice)) .. " ROBUX")
 confirmPrice.TextColor3 = targetOwns and UI.Colors.Error or PRICE_GREEN
 UI.SetShowcaseButton(confirmButton, targetOwns and "OWNED" or "GIFT", targetOwns and "Grey" or "Green", not targetOwns)
end

showList = function()
 target = nil
 confirmView.Visible, confirmButton.Visible, cancelButton.Visible = false, false, false
 playerList.Visible, closeButton.Visible = true, true
 pickerTitle.Text = "GIFT TO A PLAYER"
 for _, child in playerList:GetChildren() do
  if child:IsA("GuiObject") then child:Destroy() end
 end
 local count = 0
 for _, other in Players:GetPlayers() do
  if other ~= Player and other.Parent == Players then
   count += 1
   local row = Instance.new("TextButton")
   row.Name, row.Text, row.AutoButtonColor = other.Name, "", false
   row.BackgroundColor3, row.BackgroundTransparency, row.Size, row.ZIndex = Color3.new(0, 0, 0), .55, UDim2.new(1, -10, 0, 66), 3
   corner(row, 12)
   row.Parent = playerList
   local head = Instance.new("ImageLabel")
   head.Name, head.BackgroundColor3, head.BackgroundTransparency, head.ZIndex = "Headshot", Color3.fromRGB(60, 90, 150), 0, 4
   head.AnchorPoint, head.Position, head.Size = Vector2.new(0, .5), UDim2.new(0, 8, .5, 0), UDim2.fromOffset(52, 52)
   corner(head, 26)
   head.Parent = row
   headshot(head, other.UserId)
   local display = label(row, "DisplayName", other.DisplayName, 24)
   display.Position, display.Size, display.ZIndex = UDim2.fromOffset(70, 6), UDim2.new(1, -190, 0, 28), 4
   local user = label(row, "Username", "@" .. other.Name, 18, UI.Colors.Muted)
   user.Position, user.Size, user.ZIndex = UDim2.fromOffset(70, 36), UDim2.new(1, -190, 0, 22), 4
   local select = UI.ShowcaseButton(row, "Select")
   UI.SetShowcaseButton(select, "SELECT", "Blue", true)
   select.AnchorPoint, select.Position, select.Size, select.ZIndex = Vector2.new(1, .5), UDim2.new(1, -8, .5, 0), UDim2.fromOffset(108, 48), 4
   select.Activated:Connect(function() showConfirm(other) end)
   row.Activated:Connect(function() showConfirm(other) end)
  end
 end
 emptyNote.Visible = count == 0
end

openPicker = function(gift, itemName)
 pickGift, pickName = gift, itemName
 pickerItem.Text = string.upper(itemName)
 picker.Visible = true
 showList()
end

local function closePicker()
 picker.Visible, pickGift, target = false, nil, nil
end
closeButton.Activated:Connect(closePicker)
cancelButton.Activated:Connect(showList)
confirmButton.Activated:Connect(function()
 if not target or targetOwns then return end
 if target.Parent ~= Players then
  UI.Notify("That player has left the server.", "error")
  showList()
  return
 end
 Remote:FireServer("Gift", pickGift.id, target.UserId)
 closePicker()
end)
-- Players joining or leaving while the picker is open.
local function playersChanged(changed)
 if not picker.Visible then return end
 -- A leaving player is still listed while PlayerRemoving runs, so look again just after.
 task.delay(.1, function()
  if not picker.Visible then return end
  if target then
   if target == changed and target.Parent ~= Players then
    UI.Notify("That player has left the server.", "error")
    showList()
   end
  else
   showList()
  end
 end)
end
Players.PlayerAdded:Connect(playersChanged)
Players.PlayerRemoving:Connect(playersChanged)

-- Layout ------------------------------------------------------------------------------
-- Columns and the Starter Pack's arrangement follow the list's width (in menu units).
local function layout()
 local scale = math.max(panel.WindowScale.Scale, .01)
 local width = scroll.AbsoluteSize.X / scale - 28
 local narrow = width < 560
 for _, entry in grids do
  local columns = width >= 760 and entry.columns[1] or width >= 420 and entry.columns[2] or entry.columns[3]
  entry.layout.CellSize = UDim2.new(1 / columns, -12 * (columns - 1) / columns, 0, entry.height)
 end
 if narrow then
  starter.Size = UDim2.new(1, 0, 0, 420)
  starterArt.Position, starterArt.Size = UDim2.fromOffset(0, 50), UDim2.new(0, 120, 0, 150)
  starterTitle.Position, starterTitle.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 44)
  rewards.Position, rewards.Size = UDim2.fromOffset(124, 56), UDim2.new(1, -134, 0, 236)
  rewardGrid.CellSize = UDim2.new(1, 0, 0, 52)
  starterButton.AnchorPoint, starterButton.Position, starterButton.Size = Vector2.new(1, 1), UDim2.new(1, -12, 1, -12), UDim2.new(1, -104, 0, 70)
  starterGift.AnchorPoint, starterGift.Position, starterGift.Size = Vector2.new(0, 1), UDim2.new(0, 12, 1, -12), UDim2.fromOffset(70, 70)
 else
  starter.Size = UDim2.new(1, 0, 0, 250)
  starterArt.Position, starterArt.Size = UDim2.fromOffset(4, 6), UDim2.new(0, 170, 1, -12)
  starterTitle.Position, starterTitle.Size = UDim2.fromOffset(180, 12), UDim2.new(1, -460, 0, 50)
  rewards.Position, rewards.Size = UDim2.fromOffset(180, 68), UDim2.new(1, -460, 0, 168)
  rewardGrid.CellSize = UDim2.new(.5, -4, 0, 52)
  starterButton.AnchorPoint, starterButton.Position, starterButton.Size = Vector2.new(1, .5), UDim2.new(1, -16, .5, 0), UDim2.fromOffset(176, 80)
  starterGift.AnchorPoint, starterGift.Position, starterGift.Size = Vector2.new(1, .5), UDim2.new(1, -200, .5, 0), UDim2.fromOffset(72, 72)
 end
 if bundle then
  bundle.Size = UDim2.new(1, 0, 0, narrow and 240 or 150)
  local title, body, button, gift = bundle.Title, bundle.Contents, bundle.Buy, bundle.Gift
  -- On narrow screens the buttons run along the bottom, so the boxes stay above them.
  bundle.Art.Size = UDim2.new(0, 190, 1, narrow and -96 or -16)
  title.Size = UDim2.new(1, narrow and -220 or -520, 0, 40)
  body.Size = UDim2.new(1, narrow and -220 or -520, 0, 60)
  if narrow then
   button.AnchorPoint, button.Position, button.Size = Vector2.new(1, 1), UDim2.new(1, -10, 1, -10), UDim2.new(1, -90, 0, 60)
   gift.AnchorPoint, gift.Position, gift.Size = Vector2.new(0, 1), UDim2.new(0, 10, 1, -10), UDim2.fromOffset(60, 60)
  else
   button.AnchorPoint, button.Position, button.Size = Vector2.new(1, .5), UDim2.new(1, -16, .5, 0), UDim2.fromOffset(200, 66)
   gift.AnchorPoint, gift.Position, gift.Size = Vector2.new(1, .5), UDim2.new(1, -226, .5, 0), UDim2.fromOffset(66, 66)
  end
 end
end
scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
panel.WindowScale:GetPropertyChangedSignal("Scale"):Connect(layout)

-- The Cat Bat picture needs the published models (the server publishes them at start).
task.spawn(function()
 local folder = Storage:WaitForChild("BatModels", 30)
 local model = folder and folder:WaitForChild(PACK.batId, 30)
 if model and not starterArt:FindFirstChild("Picture") then
  local picture = batPicture(starterArt)
  if picture then picture.Size = UDim2.fromScale(1, 1) end
 end
end)

Interfaces.Register("Store", function(open)
 visible = open
 show(open)
 if not open then closePicker() end
 if open then
  buildGrounds()
  refresh()
  layout()
  -- Back to the top once the rebuilt list has its size.
  task.defer(function() scroll.CanvasPosition = Vector2.zero end)
 end
end)

-- Live updates while open: the World's ground, Cash pack amounts, and owned passes.
Player:GetAttributeChangedSignal("CurrentWorldId"):Connect(function() if visible then buildGrounds() end end)
Player.AttributeChanged:Connect(function(name)
 if visible and (name == "Level" or name == "EquippedBat" or name == "CurrentWorldId" or name == "StarterPackOwned"
  or name == "PowerMultiplierTier" or name == "CashMultiplierTier" or name:sub(1, 14) == "TrainingPass_") then
  refresh()
 end
end)

-- Purchase confirmations from the server (ProductServer).
Remote.OnClientEvent:Connect(function(kind, name, granted)
 if kind == "StarterPack" then
  GameAudio.Play("Purchase")
  UI.Notify(string.format("STARTER PACK UNLOCKED!\n+%s POWER • +%d REBIRTH • %s +%d • %s", UI.Compact(PACK.power), PACK.rebirths,
   string.upper(Juice.Get(juiceId).displayName), PACK.juices[juiceId], string.upper(bat.displayName)), "success")
 elseif kind == "Granted" and type(granted) == "table" then
  GameAudio.Play("Purchase")
  if type(granted.cash) == "number" then
   UI.Notify("+$" .. UI.Compact(granted.cash) .. " CASH", "success")
  elseif type(granted.juices) == "table" then
   local parts = {}
   for id, count in granted.juices do
    local definition = Juice.Get(id)
    if definition then table.insert(parts, string.upper(definition.displayName) .. " +" .. count) end
   end
   UI.Notify(table.concat(parts, " • ") .. "\nUse it from your Inventory.", "success")
  end
 elseif kind == "MultiplierGranted" and Monetization.Multipliers[name] and type(granted) == "number" then
  GameAudio.Play("Purchase")
  UI.Notify(string.format("%s MULTIPLIER %s!\nPermanent • Tier %d of %d", string.upper(name),
   multiplierText(Monetization.GetMultiplier(name, granted)), granted, #Monetization.Multipliers[name]), "success")
 elseif kind == "GiftRefused" and type(name) == "string" then
  UI.Notify(name, "error")
 elseif kind == "GiftSent" then
  local gift = Monetization.GetGiftById(name)
  if not gift then return end
  GameAudio.Play("Purchase")
  local person = type(granted) == "string" and granted or ""
  UI.Notify("GIFT SENT!\n" .. string.upper(gift.displayName) .. " → " .. string.upper(person), "success")
 end
end)

-- What a received gift gave, for its notice ("GIFT FROM JOSH! POWER PUNCH +1").
local function giftContents(gift, amount)
 local item = gift.item
 if item.starterPack then return "STARTER PACK RECEIVED!" end
 if item.cashPack then return "+$" .. UI.Compact(amount or 0) .. " CASH" end
 if item.entitlement then return string.upper(gift.displayName) .. " UNLOCKED!" end
 local parts = {}
 for id, count in Monetization.GetJuiceProductById(item.juiceProduct).juices do
  table.insert(parts, string.upper(Juice.Get(id).displayName) .. " +" .. count)
 end
 return table.concat(parts, " • ")
end
Remote.OnClientEvent:Connect(function(kind, giftId, sender, amount)
 local gift = kind == "GiftReceived" and Monetization.GetGiftById(giftId)
 if not gift then return end
 local from = type(sender) == "string" and sender ~= "" and string.upper(sender) or "A FRIEND"
 GameAudio.Play("Purchase")
 UI.Notify("GIFT FROM " .. from .. "!\n" .. giftContents(gift, type(amount) == "number" and amount or nil), "success")
end)
task.spawn(function()
 trainingRemote = Storage:WaitForChild("TrainingRequest")
end)
