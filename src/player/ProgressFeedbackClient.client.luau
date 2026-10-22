-- Progress feedback, presentation only:
--   * a small "+Power" popup and a barely-there tick each time Training grants Power (like the
--     Cash popup after a hit), from the server's TrainingPowerGained / TrainingPowerTick
--     display attributes
--   * a sparkling chime and a slight screen shake when the player levels up (from any source;
--     the offline catch-up at login is shown by the Welcome Back screen instead), and a
--     distinct brighter cue when that reaches the Level Cap (Rebirth available)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UI = require(script.Parent:WaitForChild("UICommon"))
local GameAudio = require(game:GetService("ReplicatedStorage"):WaitForChild("GameAudio"))
local Player = Players.LocalPlayer

local SHAKE_SECONDS, SHAKE_RADIANS = 0.45, 0.012
local POPUP_SECONDS, POPUP_RISE = 1.2, 46

GameAudio.Preload({"LevelUp", "MaxLevel", "PowerTick"})

local gui = Instance.new("ScreenGui")
gui.Name, gui.DisplayOrder, gui.ResetOnSpawn, gui.IgnoreGuiInset = "ProgressFeedback", 12, false, true
gui.Parent = Player:WaitForChild("PlayerGui")

-- ---------- +Power popups ----------

local function powerPopup(amount)
 local popup = Instance.new("CanvasGroup")
 popup.Name, popup.BackgroundTransparency = "PowerPopup", 1
 popup.AnchorPoint, popup.Size = Vector2.new(0.5, 0.5), UDim2.fromOffset(200, 52)
 -- A little sideways jitter so quick repeats don't stack exactly.
 local x = 0.5 + (math.random() - 0.5) * 0.06
 popup.Position = UDim2.fromScale(x, 0.4)
 local scale = Instance.new("UIScale")
 scale.Scale = 0.8 * UI.SizeScale
 scale.Parent = popup
 local icon = UI.Icon(popup, "PowerIcon", UI.Icons.Power)
 icon.Position, icon.Size = UDim2.fromOffset(6, 6), UDim2.fromOffset(40, 40)
 local label = UI.Label(popup, "Amount", "+" .. UI.Compact(amount), 28)
 label.Position, label.Size = UDim2.fromOffset(52, 6), UDim2.new(1, -58, 1, -12)
 label.TextScaled = true
 label.TextXAlignment = Enum.TextXAlignment.Left
 local limit = Instance.new("UITextSizeConstraint")
 limit.MinTextSize, limit.MaxTextSize = 18, 28
 limit.Parent = label
 popup.Parent = gui
 TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = UI.SizeScale}):Play()
 TweenService:Create(popup, TweenInfo.new(POPUP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
  {Position = UDim2.new(x, 0, 0.4, -POPUP_RISE)}):Play()
 TweenService:Create(popup, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, POPUP_SECONDS - 0.45),
  {GroupTransparency = 1}):Play()
 Debris:AddItem(popup, POPUP_SECONDS + 0.1)
end

Player:GetAttributeChangedSignal("TrainingPowerTick"):Connect(function()
 local amount = Player:GetAttribute("TrainingPowerGained")
 if Player:GetAttribute("TrainingActive") and type(amount) == "number" and amount > 0 then
  powerPopup(amount)
  GameAudio.Play("PowerTick")
 end
end)

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
