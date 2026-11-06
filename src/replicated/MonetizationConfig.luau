-- Robux purchases, granted by the server (ProductServer, PlayerData): the HUD's three Power
-- products and Auto Bat pass (MonetizationClient), and the Shop's Starter Pack, Power and Cash
-- multipliers, Cash packs and juices (ShopClient).
--
-- PASTE THE REAL IDS HERE from the Creator Dashboard (developerProductId / gamePassId). While an
-- id is 0 its button reads SOON and never opens a purchase prompt.
--
-- robuxPrice is only what the buttons show until Roblox's live price has loaded; Roblox always
-- charges the price set on the Dashboard. (The Training Ground passes and the Welcome Back 3x
-- product keep their ids in TrainingConfig.)
--
-- shopImage: optional uploaded picture (rbxassetid) for the item's Shop card, a 512 x 512 PNG
-- with a transparent background; empty shows the built-in picture (icons or 3D models). See
-- .vscode/MONETIZATION.md ("Shop images").
local Storage = game:GetService("ReplicatedStorage")
local Progression = require(Storage:WaitForChild("ProgressionConfig"))
local Worlds = require(Storage:WaitForChild("WorldConfig"))
local Field = require(Storage:WaitForChild("FieldConfig"))
local Equipment = require(Storage:WaitForChild("EquipmentConfig"))
local Training = require(Storage:WaitForChild("TrainingConfig"))

local Monetization = {}

-- Game pass, bought once: granted once per player when Roblox says they own it (PlayerData).
-- power is added exactly (no multiplier); the Rebirth is a bonus one (Level and Power are kept).
Monetization.StarterPack = {
 gamePassId = 0,
 robuxPrice = 39,
 power = 10000,
 rebirths = 1,
 juices = {power_punch = 1},
 batId = "catastrophe_bat",
 shopImage = "",
}

-- Developer products paying Cash worth `hits` normal hits for the player right now
-- (GetCashPackReward), so a pack stays worth the same share of progress at every stage.
Monetization.CashProducts = {
 {id = "CashTiny", displayName = "Tiny Cash Pack", developerProductId = 0, robuxPrice = 25, hits = 15, shopImage = ""},
 {id = "CashSmall", displayName = "Small Cash Pack", developerProductId = 0, robuxPrice = 59, hits = 50, shopImage = ""},
 {id = "CashMedium", displayName = "Medium Cash Pack", developerProductId = 0, robuxPrice = 115, hits = 125, shopImage = ""},
 {id = "CashLarge", displayName = "Large Cash Pack", developerProductId = 0, robuxPrice = 229, hits = 300, shopImage = ""},
}

-- Developer products adding juices to the player's Inventory (never started for them).
Monetization.JuiceProducts = {
 {id = "BoostBundle", displayName = "Boost Bundle", developerProductId = 0, robuxPrice = 95,
  juices = {power_punch = 2, cash_splash = 2}, shopImage = ""},
 {id = "PowerPunch", displayName = "Power Punch", developerProductId = 0, robuxPrice = 39, juices = {power_punch = 1},
  shopImage = ""},
 {id = "CashSplash", displayName = "Cash Splash", developerProductId = 0, robuxPrice = 39, juices = {cash_splash = 1},
  shopImage = ""},
}

-- The Shop always lists Dragon's Lair, plus the premium ground in the player's World (Cosmic
-- Rift, Time Machine Lab or Quantum Lab: one shared pass). Their passes stay in TrainingConfig.
Monetization.EveryWorldGround = "dragons_lair"

-- Gifts: buying a Shop item for another player in the server. Every gift is a developer product
-- (a game pass always belongs to whoever buys it), so a gifted Training Ground is a saved
-- entitlement (GiftedEntitlements) that opens the same grounds as its pass. Each entitlement id
-- names the pass ground it stands for (premium_training: Cosmic Rift's pass, which also opens
-- Time Machine Lab and Quantum Lab).
Monetization.GiftEntitlements = {premium_training = "cosmic_rift", dragons_lair = "dragons_lair"}

-- One gift product per Shop item; `item` says what the recipient gets (resolved on the server).
-- Each costs the same as buying the item for yourself (robuxPrice is filled in below).
Monetization.GiftProducts = {
 {id = "GiftStarterPack", item = {starterPack = true}, developerProductId = 0},
 {id = "GiftCashTiny", item = {cashPack = "CashTiny"}, developerProductId = 0},
 {id = "GiftCashSmall", item = {cashPack = "CashSmall"}, developerProductId = 0},
 {id = "GiftCashMedium", item = {cashPack = "CashMedium"}, developerProductId = 0},
 {id = "GiftCashLarge", item = {cashPack = "CashLarge"}, developerProductId = 0},
 {id = "GiftBoostBundle", item = {juiceProduct = "BoostBundle"}, developerProductId = 0},
 {id = "GiftPowerPunch", item = {juiceProduct = "PowerPunch"}, developerProductId = 0},
 {id = "GiftCashSplash", item = {juiceProduct = "CashSplash"}, developerProductId = 0},
 {id = "GiftPremiumTraining", item = {entitlement = "premium_training"}, developerProductId = 0},
 {id = "GiftDragonsLair", item = {entitlement = "dragons_lair"}, developerProductId = 0},
}

-- Developer products (consumable, buyable again and again). powerAmount is added exactly as
-- listed: no Ball, Rebirth or juice multiplier.
Monetization.PowerProducts = {
 {id = "Power10K", developerProductId = 0, robuxPrice = 11, powerAmount = 10000},
 {id = "Power100K", developerProductId = 0, robuxPrice = 45, powerAmount = 100000},
 {id = "Power1M", developerProductId = 0, robuxPrice = 95, powerAmount = 1000000},
}

-- Permanent multipliers, bought one tier at a time: each tier is its own developer product,
-- bought in order (the server only offers the next one), and the saved tier count
-- (PowerMultiplierTier / CashMultiplierTier) picks the multiplier: 1x with none, tier 1's with
-- one, and so on. Power multiplies Training, real-hit and offline Power (never the Power products
-- or the Starter Pack's Power); Cash multiplies batting Cash (and a Cash pack's "normal hit").
-- Both stack with juices; neither changes launch strength or distance. Kept through Rebirths.
-- Tiers and prices are balance values (tools/balance; .vscode/ECONOMY.md). The ladders are
-- intentionally stronger than the spender targets: World 4's balance should account for them.
Monetization.MultiplierKinds = {"Power", "Cash"}
Monetization.Multipliers = {
 Power = {
  {developerProductId = 0, robuxPrice = 129, multiplier = 2},
  {developerProductId = 0, robuxPrice = 169, multiplier = 2.5},
  {developerProductId = 0, robuxPrice = 219, multiplier = 3},
  {developerProductId = 0, robuxPrice = 279, multiplier = 3.5},
  {developerProductId = 0, robuxPrice = 359, multiplier = 4},
 },
 Cash = {
  {developerProductId = 0, robuxPrice = 129, multiplier = 2},
  {developerProductId = 0, robuxPrice = 159, multiplier = 2.5},
  {developerProductId = 0, robuxPrice = 199, multiplier = 3},
  {developerProductId = 0, robuxPrice = 249, multiplier = 3.5},
  {developerProductId = 0, robuxPrice = 309, multiplier = 4},
  {developerProductId = 0, robuxPrice = 389, multiplier = 4.5},
  {developerProductId = 0, robuxPrice = 489, multiplier = 5},
 },
}
-- The multiplier cards' optional Shop pictures (shopImage, above).
Monetization.MultiplierShopImages = {Power = "", Cash = ""}
for _, kind in Monetization.MultiplierKinds do
 local previous = 1
 for number, tier in Monetization.Multipliers[kind] do
  assert(tier.multiplier > previous, kind .. " multiplier tier " .. number .. " must beat the one before")
  previous = tier.multiplier
 end
end

-- Game pass (a permanent unlock; Roblox's ownership record is the source of truth).
Monetization.AutoBat = {
 gamePassId = 0,
 robuxPrice = 25,
 checkSeconds = 0.25, -- how often an owner's client looks for its next automatic swing
 settleSeconds = 1, -- after a hit ends (ball back on the tee) or batting starts, before the next one
}

-- The Power product sold under this developer product id, or nil.
function Monetization.GetPowerProduct(developerProductId)
 if type(developerProductId) ~= "number" or developerProductId <= 0 then return nil end
 for _, product in Monetization.PowerProducts do
  if product.developerProductId == developerProductId then return product end
 end
 return nil
end

local function findProduct(list, developerProductId)
 if type(developerProductId) ~= "number" or developerProductId <= 0 then return nil end
 for _, product in list do
  if product.developerProductId == developerProductId then return product end
 end
 return nil
end

-- The multiplier for owning `tiers` tiers of a kind ("Power" or "Cash"): 1 with none.
function Monetization.GetMultiplier(kind, tiers)
 local ladder = Monetization.Multipliers[kind]
 if not ladder or type(tiers) ~= "number" or tiers < 1 then return 1 end
 local tier = ladder[math.min(math.floor(tiers), #ladder)]
 return tier and tier.multiplier or 1
end

-- The next tier on sale for a player owning `tiers` tiers: its number and entry, or nil at the top.
function Monetization.GetNextMultiplierTier(kind, tiers)
 local ladder = Monetization.Multipliers[kind]
 local number = (type(tiers) == "number" and math.max(0, math.floor(tiers)) or 0) + 1
 if not ladder or not ladder[number] then return nil end
 return number, ladder[number]
end

-- The multiplier tier sold under this developer product id: its kind and tier number, or nil.
function Monetization.GetMultiplierProduct(developerProductId)
 if type(developerProductId) ~= "number" or developerProductId <= 0 then return nil end
 for _, kind in Monetization.MultiplierKinds do
  for number, tier in Monetization.Multipliers[kind] do
   if tier.developerProductId == developerProductId then return kind, number end
  end
 end
 return nil
end

function Monetization.GetCashProduct(developerProductId)
 return findProduct(Monetization.CashProducts, developerProductId)
end

-- The Cash pack with this config id ("CashTiny", ...), or nil.
function Monetization.GetCashProductById(id)
 for _, product in Monetization.CashProducts do
  if product.id == id then return product end
 end
 return nil
end

function Monetization.GetJuiceProductById(id)
 for _, product in Monetization.JuiceProducts do
  if product.id == id then return product end
 end
 return nil
end

function Monetization.GetGiftProduct(developerProductId)
 return findProduct(Monetization.GiftProducts, developerProductId)
end

function Monetization.GetGiftById(id)
 for _, gift in Monetization.GiftProducts do
  if gift.id == id then return gift end
 end
 return nil
end

-- The gift for a Training Ground on sale (the one for its pass), or nil.
function Monetization.GetGroundGift(ground)
 local pass = ground and Training.GetPassGround(ground)
 for _, gift in Monetization.GiftProducts do
  if gift.item.entitlement and pass and Monetization.GiftEntitlements[gift.item.entitlement] == pass.id then return gift end
 end
 return nil
end

-- Each gift's display name and Robux price, from the item it stands for.
for _, gift in Monetization.GiftProducts do
 local item = gift.item
 if item.starterPack then
  gift.displayName, gift.robuxPrice = "Starter Pack", Monetization.StarterPack.robuxPrice
 elseif item.cashPack then
  local product = Monetization.GetCashProductById(item.cashPack)
  gift.displayName, gift.robuxPrice = product.displayName, product.robuxPrice
 elseif item.juiceProduct then
  local product = Monetization.GetJuiceProductById(item.juiceProduct)
  gift.displayName, gift.robuxPrice = product.displayName, product.robuxPrice
 else
  local pass = Training.Get(Monetization.GiftEntitlements[item.entitlement])
  gift.displayName, gift.robuxPrice = pass.id == "dragons_lair" and pass.displayName or "Premium Training Ground", pass.robuxPrice
 end
end

function Monetization.GetJuiceProduct(developerProductId)
 return findProduct(Monetization.JuiceProducts, developerProductId)
end

-- The Cash of one normal hit for a player at this Level, in this World, with this Bat and Cash
-- multiplier (GetMultiplier("Cash", tiers); 1 when omitted): a hit landing at the Level's usual
-- distance in this World (Progression.GetExpectedHitDistance of its launch Level, at most the
-- World's end) in the section there, before any juice. Server state only (the client previews
-- the same).
function Monetization.GetCashPerHit(level, worldId, batId, cashMultiplier)
 local world = Worlds.Get(worldId) or Worlds.Get(Worlds.StartingWorldId)
 local bat = Equipment.Get("Bat", batId) or Equipment.Get("Bat")
 local distance = math.min(Progression.GetExpectedHitDistance(Progression.GetWorldLaunchLevel(level, world)), world.endDistance)
 local section = Field.GetRewardSection(distance, world)
 return Progression.GetHitCash(distance, world.cashMultiplier, section and section.rewardMultiplier or 1, bat.cashMultiplier,
  cashMultiplier, world.cashBase)
end

-- The whole Cash a Cash pack pays (at least 1).
function Monetization.GetCashPackReward(product, level, worldId, batId, cashMultiplier)
 return math.max(1, math.floor(product.hits * Monetization.GetCashPerHit(level, worldId, batId, cashMultiplier) + 0.5))
end

-- The Training Grounds the Shop lists in a World: the World's own premium ground first (the paid
-- ground standing there other than Dragon's Lair), then Dragon's Lair.
function Monetization.GetShopGrounds(worldId)
 local grounds = {}
 for _, ground in Training.Grounds do
  if ground.id ~= Monetization.EveryWorldGround and Training.IsPaid(ground) and table.find(ground.worlds, worldId) then
   table.insert(grounds, ground)
   break
  end
 end
 table.insert(grounds, Training.Get(Monetization.EveryWorldGround))
 return grounds
end

-- Whether Auto Bat presses Swing now: only when the player could press it themselves (at the
-- plate, no hit in play, the ball back on the tee, past the swing cooldown) and the last hit has
-- settled. The press then goes through the normal swing request, which the server still checks.
-- state: enabled, batting, training, hitActive, exitPending, cinematic, traveling (booleans),
-- ballState, serverNow, nextSwingTime, settledSeconds (seconds since the last hit ended or
-- batting started).
function Monetization.ShouldAutoSwing(state)
 return state.enabled == true and state.batting == true and not state.training and not state.hitActive
  and not state.exitPending and not state.cinematic and not state.traveling
  and state.ballState == "Ready" and state.serverNow >= (state.nextSwingTime or 0)
  and state.settledSeconds >= Monetization.AutoBat.settleSeconds
end

return Monetization
