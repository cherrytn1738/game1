-- Apply configured appearances on the server so everyone sees the same equipment.
local Players = game:GetService("Players")
local Equipment = require(game:GetService("ReplicatedStorage"):WaitForChild("EquipmentConfig"))
local Worlds = require(game.ReplicatedStorage:WaitForChild("WorldConfig"))
local BatStyles = require(game.ReplicatedStorage:WaitForChild("BatStyles"))
local ServerStorage = game:GetService("ServerStorage")
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

-- The designed bat model (RunwayAssets.DisplayItems.<bat id>, its pivot at the hand) welded
-- to the Tool's Handle. It is massless and never collides, so it cannot change the swing or
-- physics. The plain BatBody/BatGrip/BatKnob are hidden while a model is shown. The two
-- attachments mark the span clients draw the swing trail across.
local PLAIN_PARTS = {"BatBody", "BatGrip", "BatKnob"}
local function attachBatModel(tool, item)
 local handle = tool:FindFirstChild("Handle")
 if not handle then return end
 for name, height in {SwingTrailBase = BatStyles.TrailBase, SwingTrailTip = BatStyles.TrailTip} do
  local attachment = handle:FindFirstChild(name) or Instance.new("Attachment")
  attachment.Name, attachment.Position, attachment.Parent = name, Vector3.new(0, height, 0), handle
 end
 local old = tool:FindFirstChild("BatModel")
 if old then old:Destroy() end
 local assets = ServerStorage:FindFirstChild("RunwayAssets")
 local folder = assets and assets:FindFirstChild("DisplayItems")
 local template = folder and folder:FindFirstChild(item.id)
 local shown = template ~= nil and template:IsA("Model")
 for _, name in PLAIN_PARTS do
  local plain = tool:FindFirstChild(name)
  if plain then plain.Transparency = shown and 1 or 0 end
 end
 if not shown then return end
 local model = BatStyles.ApplyLook(template:Clone(), item.id)
 model.Name = "BatModel"
 model:PivotTo(handle.CFrame)
 for _, part in model:GetDescendants() do
  if part:IsA("BasePart") then
   part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, false, true
   local weld = Instance.new("WeldConstraint")
   weld.Part0, weld.Part1, weld.Parent = handle, part, part
  end
 end
 local style = BatStyles.Get(item.id)
 local barrel = model:FindFirstChild(item.id .. "__Barrel", true)
 if style and style.light and barrel then
  local light = Instance.new("PointLight")
  light.Color, light.Brightness, light.Range = style.light[1], style.light[2], style.light[3] * 0.6
  light.Parent = barrel
 end
 model.Parent = tool
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
    if tool:GetAttribute("EquipmentId") ~= item.id or not tool:FindFirstChild("BatModel") then attachBatModel(tool, item) end
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
