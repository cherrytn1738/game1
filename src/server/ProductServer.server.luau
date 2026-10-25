-- The game's one developer-product receipt handler (Roblox allows only one ProcessReceipt).
-- Roblox calls it after a player pays, and again until it answers PurchaseGranted, so each
-- product's grant must be safe to repeat (PlayerData remembers receipts it has granted).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Training = require(game.ReplicatedStorage:WaitForChild("TrainingConfig"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

MarketplaceService.ProcessReceipt = function(receipt)
 local player = Players:GetPlayerByUserId(receipt.PlayerId)
 -- Not in this server: Roblox tries again when they next join.
 if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
 local triple = Training.OfflineTriple
 if triple.productId > 0 and receipt.ProductId == triple.productId then
  return PlayerData.ClaimOfflineTriple(player, receipt)
 end
 warn("[ProductServer] Unknown developer product " .. tostring(receipt.ProductId))
 return Enum.ProductPurchaseDecision.NotProcessedYet
end
