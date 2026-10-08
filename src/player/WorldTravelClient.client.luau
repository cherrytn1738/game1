local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Travel = ReplicatedStorage:WaitForChild("WorldTravel")
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))

local gui = Instance.new("ScreenGui")
gui.Name = "WorldTravelGui"
gui.ResetOnSpawn = false
gui.Parent = Player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Name = "TravelPanel"
panel.Size = UDim2.fromScale(1, 1)
panel.BackgroundTransparency = 1
panel.Visible = false
panel.Parent = gui
Interfaces.Register("Travel", function(visible) panel.Visible = visible end)
local close = Instance.new("TextButton")
close.Name, close.Text = "Close", "Close"
close.Size = UDim2.fromOffset(190, 28)
close.Position = UDim2.new(0, 12, 1, -112)
close.Parent = panel
close.Activated:Connect(function() panel.Visible = false end)
local open = Instance.new("TextButton")
open.Name, open.Text = "OpenTravel", "WORLD TRAVEL"
open.Size = UDim2.fromOffset(190, 32)
open.Position = UDim2.new(0, 12, 1, -120)
open.Parent = gui
open.Activated:Connect(function() Interfaces.Open("Travel") end)
local buttons = {}
for index, world in Worlds.Worlds do
 local button = Instance.new("TextButton")
 button.Name = world.id
 button.Size = UDim2.fromOffset(190, 32)
 button.Position = UDim2.new(0, 12, 1, -152 - (#Worlds.Worlds - index) * 36)
 button.Parent = panel
 buttons[world.id] = button
 button.Activated:Connect(function()
  if Interfaces.CanOpen() and Player:GetAttribute("WorldUnlocked_" .. world.id) == true then
   Interfaces.CloseAll()
   Travel:FireServer(world.id)
  end
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
 open.Visible = Interfaces.CanOpen() and not Interfaces.HasPhysicalHub() and not panel.Visible
 for _, world in Worlds.Worlds do
  local unlocked = Player:GetAttribute("WorldUnlocked_" .. world.id) == true
  local current = Player:GetAttribute("CurrentWorldId") == world.id
  buttons[world.id].Text = world.displayName .. (unlocked and (current and " — Return to arrival" or " — Travel") or " — Locked")
  buttons[world.id].Active = unlocked
 end
end
Player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh)
Player:GetAttributeChangedSignal("CurrentWorldId"):Connect(refresh)
Player:GetAttributeChangedSignal("BattingActive"):Connect(refresh)
Player:GetAttributeChangedSignal("HitActive"):Connect(refresh)
panel:GetPropertyChangedSignal("Visible"):Connect(refresh)
Player.CharacterAdded:Connect(function(character)
 character:WaitForChild("Humanoid", 10)
 refresh()
end)
for _, world in Worlds.Worlds do Player:GetAttributeChangedSignal("WorldUnlocked_" .. world.id):Connect(refresh) end
status:GetPropertyChangedSignal("Text"):Connect(function() status.Visible = status.Text ~= "" end)
status.Visible = false
Player:GetAttributeChangedSignal("CurrentWorldId"):Connect(function() status.Text = "" end)
Player.CharacterRemoving:Connect(function() status.Text = "" end)
Travel.OnClientEvent:Connect(function(message) status.Text = message end)
ReplicatedStorage:WaitForChild("BattingTiming").OnClientEvent:Connect(function(_, result)
 local final = result.kind == "Distance" and result.distanceResult
 if final and final.worldCompletionMessage then status.Text = final.worldCompletionMessage end
end)
refresh()
