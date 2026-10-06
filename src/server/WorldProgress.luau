local Worlds = require(game.ReplicatedStorage:WaitForChild("WorldConfig"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Progress = {}
-- Called only with a finalized, server-measured hit from BallLauncher.
function Progress.Complete(player, world, distance)
 if not PlayerData.IsReady(player) or player:GetAttribute("CurrentWorldId") ~= world.id
  or player:GetAttribute("WorldUnlocked_" .. world.id) ~= true
  or distance < world.endDistance or distance ~= distance or distance == math.huge then return nil end
 if player:GetAttribute("WorldCompleted_" .. world.id) then return nil end
 player:SetAttribute("WorldCompleted_" .. world.id, true)
 local message = world.displayName .. " Complete!"
 if world.nextWorldId then
  local nextWorld = Worlds.Get(world.nextWorldId)
  if nextWorld then
   player:SetAttribute("WorldUnlocked_" .. nextWorld.id, true)
   message ..= "\n" .. nextWorld.displayName .. " Unlocked!"
  end
 end
 print("[WorldProgress] " .. player.Name .. ": " .. message:gsub("\n", " "))
 return message
end
return Progress
