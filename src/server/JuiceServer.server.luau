-- Juice use requests. The client names a juice; the server checks ownership and starts it.
local Players = game:GetService("Players")
local Storage = game:GetService("ReplicatedStorage")
local Data = require(script.Parent:WaitForChild("PlayerData"))
local Remote = Storage:FindFirstChild("JuiceRequest") or Instance.new("RemoteEvent")
Remote.Name, Remote.Parent = "JuiceRequest", Storage
local REQUEST_COOLDOWN = 0.3
local lastRequest = {}

Players.PlayerRemoving:Connect(function(player) lastRequest[player] = nil end)

Remote.OnServerEvent:Connect(function(player, action, id)
 if action ~= "Use" or type(id) ~= "string" or #id > 64 then return end
 local now = os.clock()
 if now - (lastRequest[player] or -math.huge) < REQUEST_COOLDOWN then
  Remote:FireClient(player, false, "Please wait before trying again.")
  return
 end
 lastRequest[player] = now
 Remote:FireClient(player, Data.UseJuice(player, id))
end)
