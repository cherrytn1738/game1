-- Progress feedback, presentation only: a sparkling chime and a slight screen shake when the
-- player levels up (from any source; the offline catch-up at login is shown by the Welcome Back
-- screen instead), and a distinct brighter cue when that reaches the Level Cap (Rebirth
-- available). Training's "+Power" popups are TrainingClient's, timed to each practice hit.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GameAudio = require(game:GetService("ReplicatedStorage"):WaitForChild("GameAudio"))
local Player = Players.LocalPlayer

local SHAKE_SECONDS, SHAKE_RADIANS = 0.45, 0.012

GameAudio.Preload({"LevelUp", "MaxLevel"})

-- ---------- level up ----------

-- A short decaying shake, applied after the camera scripts each frame (it never accumulates:
-- every camera script sets a fresh CFrame each frame).
local shakeUntil = 0
RunService:BindToRenderStep("LevelUpShake", Enum.RenderPriority.Last.Value, function()
 local left = shakeUntil - os.clock()
 if left <= 0 then return end
 local strength = SHAKE_RADIANS * (left / SHAKE_SECONDS)
 local t = os.clock() * 30
 local camera = workspace.CurrentCamera
 camera.CFrame *= CFrame.Angles(math.noise(t, 0.4) * strength, math.noise(0.8, t) * strength, math.noise(t, 1.7) * strength * 0.5)
end)

local function levelUp(level)
 local cap = Player:GetAttribute("LevelCap")
 GameAudio.Play(type(cap) == "number" and level >= cap and "MaxLevel" or "LevelUp")
 shakeUntil = os.clock() + SHAKE_SECONDS
end

-- Only a rise while data is loaded counts (Rebirth lowers Level; login sets it before DataLoaded).
local lastLevel = Player:GetAttribute("DataLoaded") and Player:GetAttribute("Level") or nil
Player:GetAttributeChangedSignal("Level"):Connect(function()
 local level = Player:GetAttribute("Level")
 if Player:GetAttribute("DataLoaded") and type(level) == "number" and lastLevel and level > lastLevel then levelUp(level) end
 lastLevel = Player:GetAttribute("DataLoaded") and level or nil
end)
Player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
 lastLevel = Player:GetAttribute("DataLoaded") and Player:GetAttribute("Level") or nil
end)
