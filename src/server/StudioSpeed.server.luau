-- Studio-only test helper: the Workspace attribute StudioWalkSpeed (a number) sets every
-- character's walk speed in playtests, e.g. to run down a runway. Live servers ignore it.
-- Batting and Training still lock the character; they restore this speed when they end.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local function speed()
 local value = workspace:GetAttribute("StudioWalkSpeed")
 return type(value) == "number" and value > 0 and value or nil
end

local function apply(character)
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local value = speed()
 -- A speed of 0 means Batting or Training has the character locked; leave it alone.
 if humanoid and value and humanoid.WalkSpeed > 0 then humanoid.WalkSpeed = value end
end

local function watch(player)
 player.CharacterAdded:Connect(function(character)
  character:WaitForChild("Humanoid", 10)
  apply(character)
 end)
 if player.Character then apply(player.Character) end
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do watch(player) end

workspace:GetAttributeChangedSignal("StudioWalkSpeed"):Connect(function()
 for _, player in Players:GetPlayers() do apply(player.Character) end
end)
