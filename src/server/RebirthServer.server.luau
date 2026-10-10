local Players = game:GetService("Players")
local Storage = game:GetService("ReplicatedStorage")
local Data = require(script.Parent:WaitForChild("PlayerData"))
local Remote = Storage:FindFirstChild("RebirthRequest") or Instance.new("RemoteEvent")
Remote.Name, Remote.Parent = "RebirthRequest", Storage
local REQUEST_COOLDOWN = 2
local requests, processing = {}, {}

Players.PlayerRemoving:Connect(function(player)
 requests[player], processing[player] = nil, nil
end)

Remote.OnServerEvent:Connect(function(player, ...)
 -- Only intent is accepted. Counts, levels, multipliers, and confirmation values are not inputs.
 if select("#", ...) ~= 0 or player.Parent ~= Players then return end
 local now = os.clock()
 if processing[player] or now - (requests[player] or -math.huge) < REQUEST_COOLDOWN then
  Remote:FireClient(player, false, "Please wait before trying again.")
  return
 end
 requests[player], processing[player] = now, true
 local success, message = Data.TryRebirth(player)
 processing[player] = nil
 Remote:FireClient(player, success, message)
end)
