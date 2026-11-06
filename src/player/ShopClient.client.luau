-- The Shop (the HUD's Shop tile): one scrolling window of Robux offers, in five sections: the
-- Starter Pack, Multipliers (the next tier of the permanent Power and Cash multipliers), Cash
-- packs, Boosts (juices) and Training Grounds (Dragon's Lair, plus the premium ground in the
-- player's World). Everything shown comes from config (MonetizationConfig,
-- TrainingConfig) and server-set attributes; this only opens Roblox's purchase prompts (or the
-- Training Ground "Buy" request) and shows what the server confirms. Ids still 0 read SOON.
-- (Bats and Balls are bought with Cash only at their hub display pedestals.)
--
-- Look: a dark Showcase window of bold colour cards (UICommon's colour cards). Each section opens
-- with a full-width hero card for its best item, then smaller cards in columns.
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
local CASH_GOLD = Color3.fromRGB(255, 220, 70)
local WHITE = Color3.new(1, 1, 1)
-- Each card's colour (a UICommon CardPalettes key).
local PALETTES = {
 starter = "Rainbow", Power = "Gold", Cash = "Teal", cash = "Green", bundle = "Pink",
 power_punch = "Crimson", cash_splash = "Blue", ground = "Orange", worldGround = "Purple",
}
-- Sizes in menu units: the purchase row, the price button on hero cards, pack tiles, card gaps.
local BUTTON, SMALL_BUTTON, PRICE_WIDTH = 54, 48, 176
local TILE, SMALL_TILE, GAP = 70, 60, 10
local NARROW = 560 -- below this list width, cards stack and grids use one column

local _, panel, show, window = UI.ShowcaseMenu("StoreGui", "Shop", Interfaces.CloseAll,
 {maxWidth = 900, maxHeight = 640, theme = "Grey"})
local visible = false
local titleIcon = UI.Icon(window.titleIcon, "Icon", UI.Icons.Shop)
titleIcon.Size, titleIcon.Rotation = UDim2.fromScale(1, 1), -10

local well = UI.ShowcaseFrame(window.box, "Offers", window.theme.well, 16)
well.Position, well.Size = UDim2.fromOffset(12, 46), UDim2.new(1, -24, 1, -58)
local scroll = Instance.new("ScrollingFrame")
scroll.Name, scroll.BackgroundTransparency, scroll.BorderSizePixel = "List", 1, 0
scroll.Position, scroll.Size = UDim2.fromOffset(4, 4), UDim2.new(1, -8, 1, -8)
scroll.ScrollBarThickness, scroll.ScrollBarImageColor3 = 8, UI.Showcase.CardLight
scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
scroll.CanvasSize, scroll.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.Parent = well
local list = Instance.new("UIListLayout")
list.Padding, list.SortOrder, list.HorizontalAlignment = UDim.new(0, GAP), Enum.SortOrder.LayoutOrder, Enum.HorizontalAlignment.Center
list.Parent = scroll
local padding = Instance.new("UIPadding")
padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 6), UDim.new(0, 14)
padding.PaddingLeft, padding.PaddingRight = UDim.new(0, GAP), UDim.new(0, GAP)
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
 limit.MaxTextSize, limit.MinTextSize, limit.Parent = size, 12, object
 return object
end

local function heading(order, text)
 local title = label(scroll, "Heading", "~ " .. text .. " ~", 36, Color3.fromRGB(255, 225, 120))
 title.LayoutOrder, title.Size, title.TextXAlignment = order, UDim2.new(1, 0, 0, 40), Enum.TextXAlignment.Center
 return title
end

-- A grid holder for small cards; its columns follow the list's width (see layout()). columns:
-- the count at full width, at a medium width, and on narrow screens.
local grids = {}
local function grid(order, name, height, columns)
 local holder = Instance.new("Frame")
 holder.Name, holder.BackgroundTransparency, holder.LayoutOrder = name, 1, order
 holder.Size, holder.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
 holder.Parent = scroll
 local cells = Instance.new("UIGridLayout")
 cells.CellPadding, cells.SortOrder = UDim2.fromOffset(GAP, GAP + 4), Enum.SortOrder.LayoutOrder
 cells.HorizontalAlignment, cells.Parent = Enum.HorizontalAlignment.Center, holder
 -- Room above the first row for pictures and stickers overlapping the cards' top edge.
 local room = Instance.new("UIPadding")
 room.PaddingTop, room.Parent = UDim.new(0, 4), holder
 local entry = {holder = holder, layout = cells, height = height, columns = columns, cards = {}}
 table.insert(grids, entry)
 return entry
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

local function juicePicture(parent, id, turn)
 return viewport(parent, JuiceModels.Build(Juice.Get(id)), CFrame.Angles(0, math.rad(turn or -28), 0), Vector3.new(0, .15, -1))
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

-- An item's big picture: its uploaded shopImage when there is one (tilted a little), otherwise
-- the built-in one (build(holder)).
local function itemArt(holder, image, build, tilt)
 if type(image) == "string" and image ~= "" then
  local picture = UI.Icon(holder, "Picture", image)
  picture.Size, picture.Rotation, picture.ZIndex = UDim2.fromScale(1, 1), tilt or -6, 3
  return picture
 end
 return build(holder)
end

-- An icon filling the art holder, tilted.
local function tiltedIcon(image, tilt)
 return function(holder)
  local icon = UI.Icon(holder, "Picture", image)
  icon.AnchorPoint, icon.Position, icon.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.92, .92)
  icon.Rotation, icon.ZIndex = tilt, 3
  return icon
 end
end

-- A pile of `count` Cash stacks (more for bigger packs).
local PILES = {
 {{.5, .52, -8}},
 {{.38, .58, -10}, {.62, .44, 8}},
 {{.32, .62, -10}, {.68, .6, 10}, {.5, .38, -4}},
 {{.3, .64, -12}, {.7, .64, 12}, {.4, .4, -6}, {.62, .34, 6}},
}
local function cashPile(count)
 return function(holder)
  local pile = PILES[math.clamp(count, 1, #PILES)]
  for index, spot in pile do
   local icon = UI.Icon(holder, "Cash" .. index, UI.Icons.Cash)
   icon.AnchorPoint, icon.Position = Vector2.new(.5, .5), UDim2.fromScale(spot[1], spot[2])
   icon.Size, icon.Rotation, icon.ZIndex = UDim2.fromScale(#pile == 1 and .9 or .66, #pile == 1 and .9 or .66), spot[3], 3
  end
  return holder
 end
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

-- Cards ---------------------------------------------------------------------------------
-- A card is a table: frame, kind ("hero", "small" or "ground"), art (the picture holder), name,
-- lines (labels under the name), tiles (pack contents), buy / setPrice, gift, strike / setStrike,
-- setStatus (the top-right sticker: SOON / OWNED / MAXED) and setDeal (the top-left sticker).
-- layout() places everything from the card's width.
local heroes = {}

-- A square Gift button for a Shop item; it opens the player picker. It shows SOON while the gift
-- product's id is 0 (in Studio the picker still opens, to try the flow; the server refuses such a
-- gift). itemName is what the confirmation calls the item.
local openPicker -- (the picker, below)
local function giftButton(parent, giftId, itemName)
 local gift = Monetization.GetGiftById(giftId)
 local soon = gift.developerProductId <= 0
 local button = UI.GiftButton(parent, "Gift", soon)
 button.ZIndex = 6
 -- A small "Gift" tip above it while the mouse is over it.
 local tip = label(button, "Tip", "Gift", 20)
 tip.AnchorPoint, tip.Position, tip.Size, tip.ZIndex = Vector2.new(.5, 1), UDim2.new(.5, 0, 0, -2), UDim2.fromOffset(70, 22), 7
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

local function makeCard(parent, id, paletteName, kind, order, title)
 local frame, palette = UI.ColorCard(parent, id, paletteName)
 frame.LayoutOrder = order
 local card = {frame = frame, kind = kind, lines = {}, line = {}, tiles = {}}
 local art = Instance.new("Frame")
 art.Name, art.BackgroundTransparency, art.ZIndex = "Art", 1, 4
 art.Parent = frame
 card.art = art
 card.name = UI.CardTitle(frame, "Name", string.upper(title), kind == "small" and 34 or 52, palette)
 card.name.ZIndex = 5
 -- Small cards carry the SOON / OWNED sticker over their picture, clear of the name.
 local _, setStatus = UI.CardBadge(frame, "Status", kind == "small" and "left" or "right")
 local _, setDeal = UI.CardBadge(frame, "Deal", kind == "small" and "right" or "left")
 card.setStatus, card.setDeal = setStatus, setDeal
 setStatus(nil)
 setDeal(nil)
 if kind == "hero" then table.insert(heroes, card) end
 return card
end

-- A line of text under the card's name (its height is size + 4).
local function addLine(card, key, text, size, color)
 local line = label(card.frame, key, text, size, color or WHITE)
 line.ZIndex = 5
 line:SetAttribute("Height", size + 4)
 table.insert(card.lines, line)
 card.line[key] = line
 return line
end

-- A slowly turning sunburst behind a featured card's picture.
local function addSunburst(card)
 local glow = Instance.new("Frame")
 glow.Name, glow.BackgroundTransparency, glow.ClipsDescendants, glow.ZIndex = "Glow", 1, true, 2
 glow.Parent = card.frame
 UI.Sunburst(glow).Size = UDim2.fromScale(1.6, 1.6)
 card.glow = glow
end

-- The pack's contents as white tiles: {name, quantity, picture}.
local function addTiles(card, items)
 local row = Instance.new("Frame")
 row.Name, row.BackgroundTransparency, row.ZIndex = "Contents", 1, 5
 row.AutomaticSize = Enum.AutomaticSize.X
 row.Parent = card.frame
 local layout = Instance.new("UIListLayout")
 layout.FillDirection, layout.Padding, layout.SortOrder = Enum.FillDirection.Horizontal, UDim.new(0, 8), Enum.SortOrder.LayoutOrder
 layout.Parent = row
 for index, item in items do
  local tile = UI.ItemTile(row, item[1], item[2], item[3])
  tile.LayoutOrder, tile.ZIndex = index, 5
  table.insert(card.tiles, tile)
 end
 card.tileRow = row
end

-- The purchase row: the price button (and a Gift button where gifting applies). Pressing a SOON
-- button says so; an owned one does nothing.
local function addPurchase(card, onBuy, giftId, itemName)
 local button, set = UI.PriceButton(card.frame, "Buy", card.kind == "small" and 26 or 30)
 button.ZIndex = 6
 card.buy, card.setPrice = button, set
 button.Activated:Connect(function()
  if card.owned then return end
  if not card.productId or card.productId <= 0 then
   UI.Notify("This is coming soon!")
   return
  end
  onBuy()
 end)
 if giftId then card.gift = giftButton(card.frame, giftId, itemName) end
end

-- Shows the price (or OWNED / MAXED) and the matching sticker. Cards keep their colour in every
-- state: SOON is a blue button with a sticker, owned a gold button with a green sticker.
local function setPrice(card, id, robux, owned, ownedText)
 card.productId, card.owned = id, owned
 if owned then
  card.setPrice("owned", ownedText or "OWNED")
  card.setStatus(ownedText or "OWNED", ownedText == "MAXED" and "Maxed" or "Owned")
 elseif id <= 0 then
  card.setPrice("soon", UI.Number(robux))
  card.setStatus("SOON", "Soon")
 else
  card.setPrice("buy", UI.Number(robux))
  card.setStatus(nil)
 end
end

-- Starter Pack ------------------------------------------------------------------------
-- (No crossed-out price: its Rebirth and Bat are not sold on their own, so there is no real
-- "bought separately" total to compare with.)
heading(1, "PACK")
local starter = makeCard(scroll, "StarterPack", PALETTES.starter, "hero", 2, "Starter Pack")
addSunburst(starter)
local bat = Equipment.Get("Bat", PACK.batId)
local juiceId = next(PACK.juices)
addTiles(starter, {
 {"Power", "+" .. UI.Compact(PACK.power), UI.Icons.Power},
 {"Rebirth", "+" .. PACK.rebirths, UI.Icons.Rebirth},
 {"Juice", "x" .. PACK.juices[juiceId], function(parent) return juicePicture(parent, juiceId) end},
 {"Bat", "x1", function(parent) return batPicture(parent, true) or UI.Icon(parent, "Icon", UI.Icons.Bat) end},
})
-- The tiles' names, for players who don't know the icons.
addLine(starter, "Contents", string.format("%s POWER • %d REBIRTH • %s • %s", UI.Compact(PACK.power), PACK.rebirths,
 string.upper(Juice.Get(juiceId).displayName), string.upper(bat.displayName)), 18, UI.Colors.Muted):SetAttribute("NarrowHidden", true)
itemArt(starter.art, PACK.shopImage, function(holder)
 -- The Cat Bat picture needs the published models (the server publishes them at start).
 task.spawn(function()
  local folder = Storage:WaitForChild("BatModels", 30)
  local model = folder and folder:WaitForChild(PACK.batId, 30)
  if model and not holder:FindFirstChild("Picture") then
   local picture = batPicture(holder)
   if picture then picture.Size = UDim2.fromScale(1, 1) end
  end
 end)
 return holder
end, -8)
addPurchase(starter, function()
 MarketplaceService:PromptGamePassPurchase(Player, PACK.gamePassId)
end, "GiftStarterPack", "Starter Pack")
table.insert(refreshers, function()
 setPrice(starter, PACK.gamePassId, price(PACK.gamePassId, PACK.robuxPrice), Player:GetAttribute("StarterPackOwned") == true)
end)
loadPrice(PACK.gamePassId, Enum.InfoType.GamePass)

-- Multipliers -------------------------------------------------------------------------
-- One card per permanent multiplier, showing the next tier as the change it makes ("2x → 2.5x")
-- from the server-set tier count (PowerMultiplierTier / CashMultiplierTier). Buy only asks the
-- server for the next tier; the server picks it and opens the prompt. Not giftable. (Two equal
-- cards side by side: neither is the section's "best" item.)
local function multiplierText(value) return string.format("%gx", value) end
local MULTIPLIER_CARDS = {
 {kind = "Power", title = "Power Multiplier", icon = UI.Icons.Power, tilt = -12, effect = "Training, hit & offline Power"},
 {kind = "Cash", title = "Cash Multiplier", icon = UI.Icons.Cash, tilt = 8, effect = "Cash from every hit & Cash Pack"},
}
heading(3, "MULTIPLIERS")
local multiplierGrid = grid(4, "Multipliers", 180, {2, 2, 1})
for index, info in MULTIPLIER_CARDS do
 local ladder = Monetization.Multipliers[info.kind]
 local card = makeCard(multiplierGrid.holder, info.kind .. "Multiplier", PALETTES[info.kind], "small", index, info.title)
 table.insert(multiplierGrid.cards, card)
 itemArt(card.art, Monetization.MultiplierShopImages[info.kind], tiltedIcon(info.icon, info.tilt))
 local change = addLine(card, "Change", "", 30)
 local tierLine = addLine(card, "Tier", "", 17, CASH_GOLD)
 addLine(card, "Effect", info.effect, 16, UI.Colors.Muted)
 addPurchase(card, function()
  Remote:FireServer("BuyMultiplier", info.kind)
 end)
 table.insert(refreshers, function()
  local owned = Player:GetAttribute(info.kind .. "MultiplierTier") or 0
  local current = Monetization.GetMultiplier(info.kind, owned)
  local number, nextTier = Monetization.GetNextMultiplierTier(info.kind, owned)
  if nextTier then
   change.Text = string.upper(info.kind) .. " " .. multiplierText(current) .. " → " .. multiplierText(nextTier.multiplier)
   tierLine.Text = string.format("TIER %d OF %d • PERMANENT", number, #ladder)
   setPrice(card, nextTier.developerProductId, price(nextTier.developerProductId, nextTier.robuxPrice), false)
  else
   change.Text = string.upper(info.kind) .. " " .. multiplierText(current)
   tierLine.Text = string.format("ALL %d TIERS OWNED", #ladder)
   setPrice(card, 0, 0, true, "MAXED")
  end
 end)
 for _, tier in ladder do loadPrice(tier.developerProductId, Enum.InfoType.Product) end
end

-- Cash Packs --------------------------------------------------------------------------
-- The biggest pack leads as the hero; the rest follow in a row. BEST VALUE marks the pack with
-- the most hits per Robux at the prices shown (a real comparison).
heading(5, "CASH PACKS")
local cashGrid = grid(7, "CashPacks", 160, {3, 2, 1})
local cashCards = {}
for index, product in Monetization.CashProducts do
 local hero = index == #Monetization.CashProducts
 local card = makeCard(hero and scroll or cashGrid.holder, product.id, PALETTES.cash, hero and "hero" or "small",
  hero and 6 or index, product.displayName)
 if hero then addSunburst(card) else table.insert(cashGrid.cards, card) end
 itemArt(card.art, product.shopImage, cashPile(hero and 4 or index))
 local amount = addLine(card, "Amount", "", hero and 42 or 30, CASH_GOLD)
 addLine(card, "Hits", hero and string.format("WORTH ABOUT %d OF YOUR HITS", product.hits)
  or string.format("ABOUT %d HITS", product.hits), hero and 20 or 17, UI.Colors.Muted)
 addPurchase(card, function()
  -- The server fixes the pack's Cash for this purchase, then opens the prompt.
  Remote:FireServer("BuyCash", product.id)
 end, "Gift" .. product.id, product.displayName)
 table.insert(cashCards, {card = card, product = product})
 table.insert(refreshers, function()
  -- The same formula the server pays with, from the server's display copies.
  local level = Player:GetAttribute("Level") or 1
  amount.Text = "+$" .. UI.Compact(Monetization.GetCashPackReward(product, level, Player:GetAttribute("CurrentWorldId"),
   Player:GetAttribute("EquippedBat"), Monetization.GetMultiplier("Cash", Player:GetAttribute("CashMultiplierTier") or 0)))
  setPrice(card, product.developerProductId, price(product.developerProductId, product.robuxPrice), false)
 end)
 loadPrice(product.developerProductId, Enum.InfoType.Product)
end
table.insert(refreshers, function()
 local best, bestValue = nil, 0
 for _, entry in cashCards do
  local value = entry.product.hits / price(entry.product.developerProductId, entry.product.robuxPrice)
  if value > bestValue then best, bestValue = entry, value end
 end
 for _, entry in cashCards do entry.card.setDeal(entry == best and "BEST VALUE" or nil, "Deal") end
end)

-- Boosts --------------------------------------------------------------------------------
-- The Boost Bundle leads; its crossed-out price is what the same juices cost one at a time.
heading(8, "BOOSTS")
local bundleProduct, singles = nil, {}
for _, product in Monetization.JuiceProducts do
 local kinds = 0
 for _ in product.juices do kinds += 1 end
 if kinds > 1 then bundleProduct = product else table.insert(singles, product) end
end

-- What a bundle's juices cost bought one at a time (live prices where loaded), or nil when one
-- of them is not sold on its own.
local function separatePrice(juices)
 local total = 0
 for id, count in juices do
  local single
  for _, product in singles do
   if product.juices[id] then single = product end
  end
  if not single then return nil end
  total += count / single.juices[id] * price(single.developerProductId, single.robuxPrice)
 end
 return math.floor(total + .5)
end

if bundleProduct then
 local bundle = makeCard(scroll, bundleProduct.id, PALETTES.bundle, "hero", 9, bundleProduct.displayName)
 addSunburst(bundle)
 itemArt(bundle.art, bundleProduct.shopImage, function(holder)
  local index = 0
  for id in bundleProduct.juices do
   index += 1
   local picture = juicePicture(holder, id, index == 1 and -36 or -18)
   picture.Position, picture.Size = UDim2.fromScale(index == 1 and -.04 or .4, index == 1 and 0 or .14), UDim2.fromScale(.64, .86)
  end
  return holder
 end)
 local tiles, effects = {}, {}
 for id, count in bundleProduct.juices do
  local definition = Juice.Get(id)
  table.insert(tiles, {id, "x" .. count, function(parent) return juicePicture(parent, id) end})
  table.insert(effects, string.format("%gx %s", definition.multiplier, string.upper(Juice.Effects[definition.effect].displayName)))
 end
 addTiles(bundle, tiles)
 local minutes = math.floor(Juice.Get(next(bundleProduct.juices)).durationSeconds / 60)
 addLine(bundle, "Effects", table.concat(effects, " + ") .. " • " .. minutes .. " MIN EACH", 22):SetAttribute("Wrap", true)
 addPurchase(bundle, function()
  MarketplaceService:PromptProductPurchase(Player, bundleProduct.developerProductId)
 end, "Gift" .. bundleProduct.id, bundleProduct.displayName)
 local strike, setStrike = UI.StrikePrice(bundle.frame, "Separately", 30)
 strike.ZIndex, bundle.strike = 6, strike
 table.insert(refreshers, function()
  local robux = price(bundleProduct.developerProductId, bundleProduct.robuxPrice)
  setPrice(bundle, bundleProduct.developerProductId, robux, false)
  local separate = separatePrice(bundleProduct.juices)
  local saving = separate and separate > robux
  setStrike(saving and UI.Number(separate) or nil)
  bundle.setDeal(saving and string.format("SAVE %d%%", math.floor((1 - robux / separate) * 100 + .5)) or nil, "Deal")
 end)
 loadPrice(bundleProduct.developerProductId, Enum.InfoType.Product)
end
local juiceGrid = grid(10, "Juices", 160, {2, 2, 1})
for index, product in singles do
 local id = next(product.juices)
 local definition = Juice.Get(id)
 local card = makeCard(juiceGrid.holder, product.id, PALETTES[id] or "Blue", "small", index, definition.displayName)
 table.insert(juiceGrid.cards, card)
 itemArt(card.art, product.shopImage, function(holder)
  local picture = juicePicture(holder, id)
  picture.Size = UDim2.fromScale(1, 1)
  return picture
 end)
 addLine(card, "Effect", string.format("%gx %s", definition.multiplier, string.upper(Juice.Effects[definition.effect].displayName)), 30)
 addLine(card, "Duration", math.floor(definition.durationSeconds / 60) .. " MINUTES", 17, CASH_GOLD)
 addPurchase(card, function()
  MarketplaceService:PromptProductPurchase(Player, product.developerProductId)
 end, "Gift" .. product.id, product.displayName)
 table.insert(refreshers, function()
  setPrice(card, product.developerProductId, price(product.developerProductId, product.robuxPrice), false)
 end)
 loadPrice(product.developerProductId, Enum.InfoType.Product)
end

-- Training Grounds ------------------------------------------------------------------------
-- Dragon's Lair (every World) leads, then this World's premium ground: both full width, since
-- their pictures are wide.
heading(11, "TRAINING GROUNDS")
local groundCards, groundRefreshers = {}, {}
local trainingRemote
table.insert(refreshers, function()
 for _, update in groundRefreshers do update() end
end)

-- Ground previews: the ground's screenshot (TrainingConfig shopImage) when one is uploaded,
-- otherwise its own cage (ReplicatedStorage.TrainingGroundModels, published by the server, pivoted
-- at its plate) live in a ViewportFrame on a themed platform, over an opaque backdrop in the
-- card's colours. The camera sways slowly round a three-quarter view from behind the batter
-- (the plate is at the origin, the pitcher down -Z) while the Shop is open.
local PREVIEW_THEMES = {
 ground = {top = Color3.fromRGB(255, 176, 92), bottom = Color3.fromRGB(176, 52, 38),
  floor = Color3.fromRGB(92, 40, 34), rim = Color3.fromRGB(255, 196, 90)},
 worldGround = {top = Color3.fromRGB(132, 104, 255), bottom = Color3.fromRGB(42, 26, 120),
  floor = Color3.fromRGB(46, 34, 104), rim = Color3.fromRGB(150, 220, 255)},
}
-- Mostly side-on (the wide card suits the long cage), from the door side and the batter's end,
-- a little above, so the pitcher and the inside show through the open side.
local PREVIEW_VIEW = Vector3.new(-1.2, .42, .75)
local PREVIEW_SWAY, PREVIEW_SWAY_SECONDS = math.rad(14), 14
local PREVIEW_FOV, PREVIEW_PADDING = 34, 1.06
local previews = {} -- live ViewportFrame previews: {frame, camera, center, corners}

local function swayView(angle)
 return CFrame.Angles(0, angle, 0):VectorToWorldSpace(PREVIEW_VIEW.Unit)
end

-- The camera distance at which every corner fits the frame (aspect = width / height) when
-- looking at target along view, with PREVIEW_PADDING to spare.
local function fitDistance(corners, target, view, aspect)
 local look = CFrame.lookAt(target + view, target)
 local tanV = math.tan(math.rad(PREVIEW_FOV / 2)) / PREVIEW_PADDING
 local tanH = tanV * aspect
 local distance = 0
 for _, point in corners do
  local p = look:VectorToObjectSpace(point - target)
  -- Camera space: x right, y up, -z forward; the point's depth is distance - z.
  distance = math.max(distance, math.abs(p.X) / tanH + p.Z, math.abs(p.Y) / tanV + p.Z)
 end
 return distance
end

-- Moves the target so the cage's picture is centred in the frame (perspective makes the near end
-- look bigger, so the bounding box centre sits off-centre), then fits the distance.
local function centredFit(corners, center, view, aspect)
 local target, distance = center, 0
 local tanV = math.tan(math.rad(PREVIEW_FOV / 2))
 local tanH = tanV * aspect
 for _ = 1, 3 do
  distance = fitDistance(corners, target, view, aspect)
  local camera = CFrame.lookAt(target + view * distance, target)
  local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
  for _, point in corners do
   local p = camera:PointToObjectSpace(point)
   local x, y = p.X / (-p.Z * tanH), p.Y / (-p.Z * tanV)
   minX, maxX, minY, maxY = math.min(minX, x), math.max(maxX, x), math.min(minY, y), math.max(maxY, y)
  end
  target += camera.RightVector * ((minX + maxX) / 2 * distance * tanH) + camera.UpVector * ((minY + maxY) / 2 * distance * tanV)
 end
 return target, fitDistance(corners, target, view, aspect)
end

local function placePreviewCamera(preview, now)
 local size = preview.frame.AbsoluteSize
 if size.X < 1 or size.Y < 1 then return end
 local aspect = size.X / size.Y
 if preview.aspect ~= aspect then
  -- Centre on the middle view, then fit the widest view of the sway once per size, so the cage
  -- never zooms while it turns.
  preview.aspect = aspect
  preview.target, preview.distance = centredFit(preview.corners, preview.center, swayView(0), aspect)
  for _, angle in {-PREVIEW_SWAY, PREVIEW_SWAY} do
   preview.distance = math.max(preview.distance, fitDistance(preview.corners, preview.target, swayView(angle), aspect))
  end
 end
 local view = swayView(math.sin(now * 2 * math.pi / PREVIEW_SWAY_SECONDS) * PREVIEW_SWAY)
 preview.camera.CFrame = CFrame.lookAt(preview.target + view * preview.distance, preview.target)
end

-- The picture sits in a framed window (thick outline, white inner rim) on the card.
local function groundPicture(parent, ground, themeName)
 local theme = PREVIEW_THEMES[themeName]
 local holder = Instance.new("Frame")
 holder.Name, holder.BorderSizePixel, holder.ZIndex = "Preview", 0, 4
 holder.BackgroundColor3 = Color3.new(1, 1, 1)
 UI.Gradient(holder, theme.top, theme.bottom)
 corner(holder, 12)
 local outline = Instance.new("UIStroke")
 outline.Color, outline.Thickness, outline.ApplyStrokeMode = UI.Showcase.Outline, 4, Enum.ApplyStrokeMode.Border
 outline.Parent = holder
 holder.Parent = parent
 local frameRim = Instance.new("Frame")
 frameRim.Name, frameRim.BackgroundTransparency, frameRim.ZIndex = "Rim", 1, 6
 frameRim.AnchorPoint, frameRim.Position, frameRim.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.new(1, -6, 1, -6)
 corner(frameRim, 9)
 local rimStroke = Instance.new("UIStroke")
 rimStroke.Color, rimStroke.Thickness, rimStroke.Transparency = Color3.new(1, 1, 1), 2, .35
 rimStroke.Parent = frameRim
 frameRim.Parent = holder
 if type(ground.shopImage) == "string" and ground.shopImage ~= "" then
  local image = Instance.new("ImageLabel")
  image.Name, image.BackgroundTransparency, image.Image, image.ZIndex = "Screenshot", 1, ground.shopImage, 3
  image.Size, image.ScaleType = UDim2.fromScale(1, 1), Enum.ScaleType.Crop
  corner(image, 12)
  image.Parent = holder
  return holder
 end
 local folder = Storage:FindFirstChild("TrainingGroundModels")
 local template = folder and folder:FindFirstChild(ground.id)
 if not template then
  local fallback = UI.Icon(holder, "Icon", UI.Icons.Training)
  fallback.AnchorPoint, fallback.Position, fallback.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.6, .6)
  fallback.ZIndex = 3
  return holder
 end
 local frame = Instance.new("ViewportFrame")
 frame.Name, frame.BackgroundTransparency, frame.ZIndex, frame.Size = "Cage", 1, 3, UDim2.fromScale(1, 1)
 -- Low ambient and a strong key light from the front left, so the cage has real shading.
 frame.Ambient, frame.LightColor, frame.LightDirection = Color3.fromRGB(118, 112, 134), Color3.fromRGB(255, 250, 240), Vector3.new(.7, -1, -.45)
 corner(frame, 12)
 frame.Parent = holder
 local model = template:Clone()
 model:PivotTo(CFrame.identity)
 model.Parent = frame
 local box, size = model:GetBoundingBox()
 -- A low platform in the theme's colours under the cage, with a lighter rim, so it stands on
 -- something.
 local floorTop = box.Position.Y - size.Y / 2
 for _, slab in {{"PlatformRim", theme.rim, 4, 1.6}, {"Platform", theme.floor, 2, 1.2}} do
  local part = Instance.new("Part")
  part.Name, part.Anchored, part.Material, part.Color = slab[1], true, Enum.Material.SmoothPlastic, slab[2]
  part.Size = Vector3.new(size.X + slab[3] * 2, slab[4], size.Z + slab[3] * 2)
  part.CFrame = CFrame.new(box.Position.X, floorTop - slab[4] / 2 + (slab[1] == "Platform" and .05 or 0), box.Position.Z)
  part.Parent = model
 end
 box = model:GetBoundingBox()
 -- Every part's own corners, so the fit hugs the cage's real shape rather than its bounding box.
 local corners = {}
 for _, part in model:GetDescendants() do
  if part:IsA("BasePart") then
   for _, x in {-1, 1} do for _, y in {-1, 1} do for _, z in {-1, 1} do
    table.insert(corners, part.CFrame:PointToWorldSpace(part.Size / 2 * Vector3.new(x, y, z)))
   end end end
  end
 end
 local camera = Instance.new("Camera")
 camera.FieldOfView = PREVIEW_FOV
 camera.Parent, frame.CurrentCamera = frame, camera
 local preview = {frame = frame, camera = camera, center = box.Position, corners = corners}
 previews[frame] = preview
 frame.Destroying:Connect(function() previews[frame] = nil end)
 frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() placePreviewCamera(preview, os.clock()) end)
 placePreviewCamera(preview, os.clock())
 return holder
end

-- The sway only runs while the Shop is open.
RunService.RenderStepped:Connect(function()
 if not visible or next(previews) == nil then return end
 local now = os.clock()
 for _, preview in previews do placePreviewCamera(preview, now) end
end)

local layout -- (below)
local function buildGrounds()
 for _, card in groundCards do card.frame:Destroy() end
 table.clear(groundCards)
 table.clear(groundRefreshers)
 local grounds = Monetization.GetShopGrounds(Player:GetAttribute("CurrentWorldId"))
 -- Dragon's Lair (the best ground) first.
 table.sort(grounds, function(a, b)
  return (a.id == Monetization.EveryWorldGround and 0 or 1) < (b.id == Monetization.EveryWorldGround and 0 or 1)
 end)
 for index, ground in grounds do
  local pass = Training.GetPassGround(ground)
  local everyWorld = ground.id == Monetization.EveryWorldGround
  local theme = everyWorld and "ground" or "worldGround"
  local card = makeCard(scroll, ground.id, PALETTES[theme], "ground", 11 + index, ground.displayName)
  table.insert(groundCards, card)
  card.picture = groundPicture(card.frame, ground, theme)
  addLine(card, "Multiplier", UI.Number(ground.powerMultiplier) .. "x POWER", 34)
  addLine(card, "Where", everyWorld and "TRAINING IN EVERY WORLD" or "THIS WORLD'S PREMIUM GROUND", 19, UI.Colors.Muted)
  addPurchase(card, function()
   -- The server checks the pass and opens Roblox's prompt (TrainingService).
   if trainingRemote then trainingRemote:FireServer("Buy", ground.id) end
  end, Monetization.GetGroundGift(ground).id, ground.displayName) -- owning it never stops you gifting it
  local function update()
   setPrice(card, pass.gamePassId, price(pass.gamePassId, pass.robuxPrice), Player:GetAttribute("TrainingPass_" .. pass.id) == true)
  end
  table.insert(groundRefreshers, update)
  update()
  loadPrice(pass.gamePassId, Enum.InfoType.GamePass)
 end
 if layout then layout() end
end

-- A copied MeshPart only draws in a ViewportFrame once its mesh has loaded, so the cages' meshes
-- are loaded first, and the ground cards are rebuilt when they arrive.
task.spawn(function()
 local folder = Storage:WaitForChild("TrainingGroundModels", 60)
 if not folder then return end
 game:GetService("ContentProvider"):PreloadAsync({folder})
 if visible then buildGrounds() end
end)

-- Gift player picker -------------------------------------------------------------------
-- Over the Shop: the other players in this server (headshot, display name, @username), then a
-- confirmation. GIFT sends only the gift id and the recipient's UserId; the server checks both
-- players and the item, saves who receives it, then opens the BUYER's Roblox prompt.
local picker = Instance.new("Frame")
picker.Name, picker.BackgroundColor3, picker.BackgroundTransparency = "GiftPicker", Color3.new(0, 0, 0), .45
picker.Size, picker.ZIndex, picker.Visible, picker.Active = UDim2.fromScale(1, 1), 50, false, true
picker.Parent = panel
local pickerWindow = UI.ColorCard(picker, "Window", "Purple")
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
-- Every card is placed in menu units from its width: heroes and grounds from the list's width,
-- small cards from their grid cell. Below NARROW (phones held upright) cards stack and grids use
-- one column.

-- Stacks the card's lines from y; returns the bottom. When narrow, long lines (Wrap) take two
-- rows and lines the tiles already say (NarrowHidden) are hidden.
local function placeLines(card, x, y, width, align, narrow)
 for _, line in card.lines do
  line.Visible = not (narrow and line:GetAttribute("NarrowHidden"))
  if not line.Visible then continue end
  local wrap = narrow == true and line:GetAttribute("Wrap") == true
  local height = line:GetAttribute("Height") * (wrap and 2 or 1)
  line.TextWrapped = wrap
  line.Position, line.Size, line.TextXAlignment = UDim2.fromOffset(x, y), UDim2.fromOffset(width, height), align
  y += height
 end
 return y
end

-- The purchase row along bottom, ending at right: [crossed-out price] [Gift] [price]. With fill
-- the price button stretches back to left; otherwise it is PRICE_WIDTH wide.
local function placePurchase(card, left, right, bottom, height, fill)
 local giftWidth = card.gift and height + 8 or 0
 local priceWidth = fill and right - left - giftWidth or PRICE_WIDTH
 card.buy.AnchorPoint, card.buy.Position, card.buy.Size = Vector2.new(1, 1), UDim2.fromOffset(right, bottom), UDim2.fromOffset(priceWidth, height)
 local x = right - priceWidth - 8
 if card.gift then
  card.gift.AnchorPoint, card.gift.Position, card.gift.Size = Vector2.new(1, 1), UDim2.fromOffset(x, bottom), UDim2.fromOffset(height, height)
  x -= height + 10
 end
 if card.strike and not fill then
  card.strike.AnchorPoint, card.strike.Position = Vector2.new(1, .5), UDim2.fromOffset(x, bottom - height / 2)
 end
end

local function purchaseWidth(card)
 return PRICE_WIDTH + (card.gift and BUTTON + 8 or 0) + (card.strike and card.strike.Visible and 100 or 0)
end

local function placeTiles(card, x, y, size)
 card.tileRow.Position, card.tileRow.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(0, size)
 for _, tile in card.tiles do tile.Size = UDim2.fromOffset(size, size) end
end

-- A hero card: a big picture (over a sunburst) on the left overlapping the top edge, the name,
-- lines and tiles to its right, the purchase row at the bottom right. Returns its height.
local function placeHero(card, width)
 local narrow = width < NARROW
 local art = narrow and 120 or 196
 local left = art + (narrow and 16 or 24)
 local right = width - 16
 local align = narrow and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
 card.name.Position, card.name.Size, card.name.TextXAlignment = UDim2.fromOffset(left, 8), UDim2.fromOffset(right - left, narrow and 40 or 50), align
 local y = placeLines(card, left, narrow and 50 or 60, right - left, align, narrow)
 local tileSize = narrow and SMALL_TILE or TILE
 local tilesWidth = #card.tiles * (tileSize + 8) - 8
 local height
 if narrow then
  y = math.max(y + 6, art - 4)
  if card.tileRow then
   placeTiles(card, 12, y, tileSize)
   -- The purchase row fills the width, so a crossed-out price sits beside the tiles.
   if card.strike then
    card.strike.AnchorPoint, card.strike.Position = Vector2.new(0, .5), UDim2.fromOffset(12 + tilesWidth + 16, y + tileSize / 2)
   end
   y += tileSize + 10
  end
  height = y + BUTTON + 12
  placePurchase(card, 12, right + 4, height - 12, BUTTON, true)
 else
  -- The tiles sit beside the purchase row when they fit, otherwise on a row of their own.
  local beside = card.tileRow and tilesWidth + purchaseWidth(card) + 16 <= right - left
  local row = beside and math.max(BUTTON, tileSize) or BUTTON
  if card.tileRow and not beside then
   placeTiles(card, right - tilesWidth, y + 6, tileSize)
   y += tileSize + 10
  end
  height = math.max(y + 8 + row + 12, 150)
  placePurchase(card, left, right, height - 12, BUTTON, false)
  if beside then placeTiles(card, left, height - 12 - tileSize, tileSize) end
 end
 card.art.Position = UDim2.fromOffset(8, -12)
 card.art.Size = UDim2.fromOffset(art, narrow and art or height + 4)
 if card.glow then
  card.glow.Position, card.glow.Size = UDim2.fromOffset(8, 8), UDim2.fromOffset(art, (narrow and art - 12 or height - 16))
 end
 return height
end

-- A small card (a grid cell): the picture top left overlapping the edge, the name and lines to
-- its right, the purchase row along the bottom.
local function placeSmall(card, width, height)
 local art = math.clamp(math.floor(width * .28), 76, 108)
 card.art.Position, card.art.Size = UDim2.fromOffset(4, -10), UDim2.fromOffset(art, art)
 local left, right = art + 12, width - 10
 card.name.Position, card.name.Size, card.name.TextXAlignment = UDim2.fromOffset(left, 8), UDim2.fromOffset(right - left, 34), Enum.TextXAlignment.Left
 placeLines(card, left, 44, right - left, Enum.TextXAlignment.Left)
 placePurchase(card, 10, right, height - 10, SMALL_BUTTON, true)
end

-- A Training Ground card: its wide picture on the left (on top when narrow), the name, lines and
-- purchase row beside it. Returns its height.
local function placeGround(card, width)
 local narrow = width < NARROW
 local right = width - 16
 if narrow then
  local pictureWidth = width - 20
  card.picture.Position, card.picture.Size = UDim2.fromOffset(10, 10), UDim2.fromOffset(pictureWidth, math.floor(pictureWidth / 2.2))
  local top = math.floor(pictureWidth / 2.2) + 18
  card.name.Position, card.name.Size, card.name.TextXAlignment = UDim2.fromOffset(12, top), UDim2.fromOffset(right - 12, 40), Enum.TextXAlignment.Left
  local y = placeLines(card, 12, top + 42, right - 12, Enum.TextXAlignment.Left)
  local height = y + 8 + BUTTON + 12
  placePurchase(card, 12, right + 4, height - 12, BUTTON, true)
  return height
 end
 local pictureWidth = math.clamp(math.floor(width * .48), 280, 400)
 local pictureHeight = math.floor(pictureWidth / 2.2)
 local left = pictureWidth + 26
 card.name.Position, card.name.Size, card.name.TextXAlignment = UDim2.fromOffset(left, 10), UDim2.fromOffset(right - left, 50), Enum.TextXAlignment.Right
 local y = placeLines(card, left, 62, right - left, Enum.TextXAlignment.Right)
 local height = math.max(pictureHeight + 20, y + 8 + BUTTON + 12)
 card.picture.Position, card.picture.Size = UDim2.fromOffset(10, math.floor((height - pictureHeight) / 2)), UDim2.fromOffset(pictureWidth, pictureHeight)
 placePurchase(card, left, right, height - 12, BUTTON, false)
 return height
end

layout = function()
 local scale = math.max(panel.WindowScale.Scale, .01)
 local width = math.floor(scroll.AbsoluteWindowSize.X / scale) - GAP * 2
 if width < 200 then return end
 for _, entry in grids do
  local columns = width >= 700 and entry.columns[1] or width >= NARROW and entry.columns[2] or entry.columns[3]
  local cell = math.floor((width - GAP * (columns - 1)) / columns)
  entry.layout.CellSize = UDim2.fromOffset(cell, entry.height)
  for _, card in entry.cards do placeSmall(card, cell, entry.height) end
 end
 for _, card in heroes do card.frame.Size = UDim2.fromOffset(width, placeHero(card, width)) end
 for _, card in groundCards do card.frame.Size = UDim2.fromOffset(width, placeGround(card, width)) end
end
scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(layout)
panel.WindowScale:GetPropertyChangedSignal("Scale"):Connect(layout)

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
