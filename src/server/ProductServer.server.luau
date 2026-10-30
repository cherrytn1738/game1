-- The game's one developer-product receipt handler (Roblox allows only one ProcessReceipt).
-- Roblox calls it after a player pays, and again until it answers PurchaseGranted, so each
-- product's grant must be safe to repeat (PlayerData remembers receipts it has granted).
-- It also turns Auto Bat on and off for owners of its game pass (MonetizationConfig).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Training = require(game.ReplicatedStorage:WaitForChild("TrainingConfig"))
local Monetization = require(game.ReplicatedStorage:WaitForChild("MonetizationConfig"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

-- Client to server: ("AutoBat", on) asks to turn Auto Bat on or off; ("BuyCash", pack id) asks to
-- buy a Cash pack (the server fixes its reward, then prompts). Server to client:
-- ("PowerGranted", amount) after a Power purchase is added; ("Granted", product name, {cash} or
-- {juices}) after a Shop product; ("StarterPack") once its rewards are given;
-- ("AutoBatRefused", message). Gifts: ("Gift", gift id, recipient UserId) from the client;
-- ("GiftRefused", message), ("GiftSent", gift id, recipient name) and ("GiftReceived", gift id,
-- sender name, Cash amount) back.
local Remote = ReplicatedStorage:FindFirstChild("Monetization") or Instance.new("RemoteEvent")
Remote.Name, Remote.Parent = "Monetization", ReplicatedStorage
local TOGGLE_SECONDS = 0.3 -- requests closer together than this are ignored
local lastToggle = {}

MarketplaceService.ProcessReceipt = function(receipt)
 local player = Players:GetPlayerByUserId(receipt.PlayerId)
 -- Not in this server: Roblox tries again when they next join.
 if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
 local triple = Training.OfflineTriple
 if triple.productId > 0 and receipt.ProductId == triple.productId then
  return PlayerData.ClaimOfflineTriple(player, receipt)
 end
 -- The amount comes from the server's own config for this product id, never from the client.
 local power = Monetization.GetPowerProduct(receipt.ProductId)
 if power then
  local decision, added = PlayerData.ClaimPowerProduct(player, receipt, power.powerAmount)
  if added and player.Parent == Players then Remote:FireClient(player, "PowerGranted", added) end
  return decision
 end
 local cashPack = Monetization.GetCashProduct(receipt.ProductId)
 local juicePack = Monetization.GetJuiceProduct(receipt.ProductId)
 if cashPack or juicePack then
  local decision, granted = PlayerData.ClaimProduct(player, receipt,
   cashPack and {cashPack = cashPack.id, cashHits = cashPack.hits} or {juices = juicePack.juices})
  if granted and player.Parent == Players then
   Remote:FireClient(player, "Granted", (cashPack or juicePack).displayName, granted)
  end
  return decision
 end
 -- A gift: the recipient and any Cash amount come from the intent the server saved before the
 -- prompt (PlayerData.PrepareGift), never from the receipt or the client.
 local gift = Monetization.GetGiftProduct(receipt.ProductId)
 if gift then return (PlayerData.ClaimGift(player, receipt, gift)) end
 warn("[ProductServer] Unknown developer product " .. tostring(receipt.ProductId))
 return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ("Gift", gift id, recipient UserId): the server checks the gift and saves who receives it,
-- then opens the BUYER's prompt for the gift product. Refusals come back as ("GiftRefused", text).
local GIFT_SECONDS = 1
local lastGift = {}
local function startGift(player, giftId, recipientId)
 if type(giftId) ~= "string" or #giftId > 64 or type(recipientId) ~= "number" then return end
 local now = os.clock()
 if now - (lastGift[player] or -math.huge) < GIFT_SECONDS then return end
 lastGift[player] = now
 local recipient = Players:GetPlayerByUserId(recipientId)
 local ok, message = PlayerData.PrepareGift(player, giftId, recipient)
 if not ok then
  Remote:FireClient(player, "GiftRefused", message)
  return
 end
 MarketplaceService:PromptProductPurchase(player, Monetization.GetGiftById(giftId).developerProductId)
end

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
 local gift = Monetization.GetGiftProduct(productId)
 local player = gift and Players:GetPlayerByUserId(userId)
 if player then PlayerData.GiftPromptFinished(player, gift, purchased == true) end
end)

-- "GIFT SENT!" for the buyer, "YOU RECEIVED A GIFT!" for the recipient (names are the server's).
PlayerData.OnGift(function(kind, player, info)
 if player.Parent ~= Players then return end
 if kind == "Sent" then
  Remote:FireClient(player, "GiftSent", info.gift.id, info.recipientName)
 else
  Remote:FireClient(player, "GiftReceived", info.gift.id, info.entry.fromName, info.entry.amount)
 end
end)

-- ("BuyCash", pack id): the server fixes what this Cash pack will pay (PlayerData.QuoteCashPack),
-- then opens Roblox's prompt itself, so the quote always exists before any receipt.
local BUY_SECONDS = 0.5
local lastBuy = {}
local function buyCashPack(player, id)
 local product = type(id) == "string" and Monetization.GetCashProductById(id)
 if not product or product.developerProductId <= 0 then return end
 local now = os.clock()
 if now - (lastBuy[player] or -math.huge) < BUY_SECONDS then return end
 lastBuy[player] = now
 if PlayerData.QuoteCashPack(player, product.id) then
  MarketplaceService:PromptProductPurchase(player, product.developerProductId)
 end
end

Remote.OnServerEvent:Connect(function(player, action, on, extra)
 if action == "BuyCash" then buyCashPack(player, on) return end
 if action == "Gift" then startGift(player, on, extra) return end
 if action ~= "AutoBat" or type(on) ~= "boolean" then return end
 local now = os.clock()
 if now - (lastToggle[player] or -math.huge) < TOGGLE_SECONDS then return end
 lastToggle[player] = now
 if on and not PlayerData.OwnsAutoBat(player) then
  player:SetAttribute("AutoBatEnabled", false)
  Remote:FireClient(player, "AutoBatRefused", "Get the Auto Bat pass to bat automatically.")
  return
 end
 player:SetAttribute("AutoBatEnabled", on)
end)

Players.PlayerRemoving:Connect(function(player)
 lastToggle[player], lastBuy[player], lastGift[player] = nil, nil, nil
end)

-- The Starter Pack is a game pass; PlayerData gives its rewards. Tell the player once it has.
PlayerData.OnStarterPackGranted(function(player)
 if player.Parent == Players then Remote:FireClient(player, "StarterPack") end
end)
