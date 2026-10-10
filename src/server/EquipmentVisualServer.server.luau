-- Apply configured appearances on the server so everyone sees the same equipment.
local Players = game:GetService("Players")
local Equipment = require(game:GetService("ReplicatedStorage"):WaitForChild("EquipmentConfig"))
local Worlds = require(game.ReplicatedStorage:WaitForChild("WorldConfig"))
local connections = {}

local function paint(part, appearance)
 if not part or not part:IsA("BasePart") then return end
 -- Materials must not change mass, friction, or bounce of existing equipment.
 if not part.CustomPhysicalProperties then
  part.CustomPhysicalProperties = part.CurrentPhysicalProperties
 end
 part.Color = appearance.color
 part.Material = appearance.material
end

local function paintParts(model, appearance)
 for name, style in appearance do paint(model:FindFirstChild(name), style) end
end

local function applyBat(player)
 local item = Equipment.Get("Bat", player:GetAttribute("EquippedBat"))
 if not item then return end
 local backpack = player:FindFirstChildOfClass("Backpack")
 for _, container in {backpack or false, player.Character or false} do
  if container then
   local tool = container:FindFirstChild("Bat")
   if tool and tool:IsA("Tool") then
    paintParts(tool, item.appearance)
    tool:SetAttribute("EquipmentId", item.id)
    tool.ToolTip = item.displayName
   end
  end
 end
end

local function refreshStation(world)
 local area = workspace:FindFirstChild(world.stationName)
 if not area then return end
 local ball, pad = area.Baseball, area.BatterPosition
 -- Retain the hitter's ball throughout windup/flight, even if they leave the tee.
 if ball:GetAttribute("BallState") ~= "Ready" then return end
 local userId = pad:GetAttribute("OccupantUserId")
 local player = userId and Players:GetPlayerByUserId(userId)
 local ballItem = Equipment.Get("Ball", player and player:GetAttribute("EquippedBall"))
 paint(ball, ballItem.appearance)
 ball:SetAttribute("EquipmentId", ballItem.id)
end

local function refreshStations()
 for _, world in Worlds.Worlds do refreshStation(world) end
end

local function watch(player)
 connections[player] = {
  player:GetAttributeChangedSignal("EquippedBat"):Connect(function() applyBat(player) end),
  player:GetAttributeChangedSignal("EquippedBall"):Connect(refreshStations),
  player.DescendantAdded:Connect(function(child)
   if child:IsA("Tool") and child.Name == "Bat" then
    task.defer(applyBat, player)
   end
  end),
  player.CharacterAdded:Connect(function(character)
   -- Characters live in Workspace, not beneath Player.
   character.ChildAdded:Connect(function(child)
    if child:IsA("Tool") and child.Name == "Bat" then applyBat(player) end
   end)
   task.defer(applyBat, player)
  end),
 }
 applyBat(player)
end

Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player)
 for _, connection in connections[player] or {} do connection:Disconnect() end
 connections[player] = nil
end)
for _, player in Players:GetPlayers() do watch(player) end
for _, world in Worlds.Worlds do
 local area = workspace:WaitForChild(world.stationName)
 area.BatterPosition:GetAttributeChangedSignal("OccupantUserId"):Connect(function() refreshStation(world) end)
 area.Baseball:GetAttributeChangedSignal("BallState"):Connect(function() refreshStation(world) end)
 refreshStation(world)
end
