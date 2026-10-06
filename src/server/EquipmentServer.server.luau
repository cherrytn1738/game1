local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local Remote = ReplicatedStorage:WaitForChild("EquipmentUpgrade")
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PURCHASE_COOLDOWN = 0.4
local lastRequest = {}

Players.PlayerRemoving:Connect(function(player) lastRequest[player] = nil end)

Remote.OnServerEvent:Connect(function(player, category)
 if not PlayerData.IsReady(player) then
  Remote:FireClient(player, false, "Your data is not ready. Please wait.")
  return
 end
 if typeof(category) ~= "string"
  or (category ~= "Bat" and category ~= "Ball" and category ~= "Tee") then return end
 local now = os.clock()
 if now - (lastRequest[player] or -math.huge) < PURCHASE_COOLDOWN then
  Remote:FireClient(player, false, "Please wait before buying again.")
  return
 end
 lastRequest[player] = now
 if player:GetAttribute("BattingActive") then
  Remote:FireClient(player, false, "Press Space to leave batting before shopping.")
  return
 end
 local currentId = player:GetAttribute("Equipped" .. category)
 if typeof(currentId) ~= "string" or not Equipment.Get(category, currentId) then return end
 local nextItem = Equipment.GetNext(category, currentId)
 if not nextItem then
  Remote:FireClient(player, false, "No additional " .. string.lower(category) .. " equipment is available.")
  return
 end
 -- A configured next item is the only allowed destination.
 local price = nextItem.price
 if nextItem.id == currentId or typeof(price) ~= "number"
  or price ~= price or price < 0 or price == math.huge or price % 1 ~= 0 then
  Remote:FireClient(player, false, "This equipment is not available for purchase.")
  return
 end
 local stats = player:FindFirstChild("leaderstats")
 local cash = stats and stats:FindFirstChild("Cash")
 if not cash then
  Remote:FireClient(player, false, "Cash is still loading.")
  return
 end
 if cash.Value < price then
  Remote:FireClient(player, false, string.format("Not enough Cash. Need %d more.", price - cash.Value))
  return
 end
 -- No yields between validation, deduction, and equipping.
 cash.Value -= price
 player:SetAttribute("Equipped" .. category, nextItem.id)
 Remote:FireClient(player, true, "Purchased and equipped " .. nextItem.displayName .. "!")
end)
