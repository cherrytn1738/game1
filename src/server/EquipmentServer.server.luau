local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local Remote = ReplicatedStorage:WaitForChild("EquipmentUpgrade")
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local REQUEST_COOLDOWN = 0.4
local lastRequest = {}

Players.PlayerRemoving:Connect(function(player) lastRequest[player] = nil end)

-- Purchase: action, category, server-issued offer token. Equip: action, category, owned ID.
Remote.OnServerEvent:Connect(function(player, action, category, value)
 if type(action) ~= "string" or (action ~= "Purchase" and action ~= "Equip")
  or type(category) ~= "string" or not Equipment.Categories[category]
  or type(value) ~= "string" or #value > 128 then return end
 local now = os.clock()
 if now - (lastRequest[player] or -math.huge) < REQUEST_COOLDOWN then
  Remote:FireClient(player, false, "Please wait before trying again.")
  return
 end
 lastRequest[player] = now
 local success, message
 if action == "Purchase" then
  success, message = PlayerData.PurchaseNextEquipment(player, category, value)
 else
  success, message = PlayerData.EquipEquipment(player, category, value)
 end
 Remote:FireClient(player, success, message)
end)
