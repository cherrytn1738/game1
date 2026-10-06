local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Travel = ReplicatedStorage:WaitForChild("WorldTravel")

local gui = Instance.new("ScreenGui")
gui.Name = "WorldTravelGui"
gui.ResetOnSpawn = false
gui.Parent = Player:WaitForChild("PlayerGui")
local buttons = {}
for index, world in Worlds.Worlds do
 local button = Instance.new("TextButton")
 button.Name = world.id
 button.Size = UDim2.fromOffset(190, 32)
 button.Position = UDim2.new(0, 12, 1, -120 - (#Worlds.Worlds - index) * 36)
 button.Parent = gui
 buttons[world.id] = button
 button.Activated:Connect(function()
  if Player:GetAttribute("WorldUnlocked_" .. world.id) == true then Travel:FireServer(world.id) end
 end)
end
local status = Instance.new("TextLabel")
status.Name = "WorldStatus"
status.Size = UDim2.fromOffset(260, 60)
status.Position = UDim2.new(0, 12, 1, -80)
status.TextWrapped = true
status.Text = ""
status.Parent = gui

local function refresh()
 gui.Enabled = Player:GetAttribute("DataLoaded") == true
 for _, world in Worlds.Worlds do
  local unlocked = Player:GetAttribute("WorldUnlocked_" .. world.id) == true
  local current = Player:GetAttribute("CurrentWorldId") == world.id
  buttons[world.id].Text = world.displayName .. (unlocked and (current and " — Return to tee" or " — Travel") or " — Locked")
  buttons[world.id].Active = unlocked
 end
end
Player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh)
Player:GetAttributeChangedSignal("CurrentWorldId"):Connect(refresh)
for _, world in Worlds.Worlds do Player:GetAttributeChangedSignal("WorldUnlocked_" .. world.id):Connect(refresh) end
Travel.OnClientEvent:Connect(function(message) status.Text = message end)
ReplicatedStorage:WaitForChild("BattingTiming").OnClientEvent:Connect(function(_, result)
 local final = result.kind == "Distance" and result.distanceResult
 if final and final.worldCompletionMessage then status.Text = final.worldCompletionMessage end
end)
refresh()
