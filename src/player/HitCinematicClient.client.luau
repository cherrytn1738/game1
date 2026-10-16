-- Hit presentation, started the moment the ball visibly leaves the tee:
--   * the bat crack, at every batting station, so nearby players hear each other's hits
--   * for the local player's own swing and hit: black letterbox bars and a punchier colour
--     grade, from the click that starts the swing until the hit ends
--   * each ball's model and flight effects (BallEffects), for every station
--   * the batter's Bat contact burst, and swing trails on every held Bat (BatEffects)
-- The BallState attribute reaches the client before the ball's physics movement (which is
-- drawn slightly behind for smoothness), so effects wait for the rendered ball to move.
-- Presentation only. The camera kick lives with the batting camera (BatTimingClient).
local Player = game.Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local BallEffects = require(script.Parent:WaitForChild("BallEffects"))
local BatEffects = require(script.Parent:WaitForChild("BatEffects"))

-- Bat crack (Roblox-licensed Pro Sound Effects audio), heard from the tee.
local HIT_SOUND_ID = "rbxassetid://9125380872"
local HIT_SOUND_VOLUME = 1
local LEAVE_DISTANCE = 0.5 -- studs the rendered ball must move off its tee spot
local BAR_HEIGHT = 0.11 -- share of the screen height covered by each bar
local IN_SECONDS, OUT_SECONDS = 0.35, 0.5
local GRADE = {Contrast = 0.12, Saturation = 0.2}
-- After the click, the bars stay this long waiting for the server to accept the swing
-- (HitActive); a refused swing lets them slide back out.
local SWING_GRACE_SECONDS = 1.2

-- Below GameHUD (12) so the distance counter and 2x button stay readable on the bars.
local gui = Instance.new("ScreenGui")
gui.Name, gui.DisplayOrder, gui.ResetOnSpawn, gui.IgnoreGuiInset = "HitCinematic", 11, false, true
local bars = {}
for _, edge in {0, 1} do
 local bar = Instance.new("Frame")
 bar.Name = edge == 0 and "TopBar" or "BottomBar"
 bar.AnchorPoint, bar.Position, bar.Size = Vector2.new(0, edge), UDim2.fromScale(0, edge), UDim2.fromScale(1, 0)
 bar.BackgroundColor3, bar.BorderSizePixel = Color3.new(0, 0, 0), 0
 bar.Parent = gui
 table.insert(bars, bar)
end
gui.Parent = Player:WaitForChild("PlayerGui")

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "HitCinematicGrade"
grade.Parent = Lighting

local tweens = {}
local function playCinematic(on)
 for _, tween in tweens do tween:Cancel() end
 table.clear(tweens)
 local info = TweenInfo.new(on and IN_SECONDS or OUT_SECONDS, Enum.EasingStyle.Quad,
  on and Enum.EasingDirection.Out or Enum.EasingDirection.In)
 for _, bar in bars do
  table.insert(tweens, TweenService:Create(bar, info, {Size = UDim2.fromScale(1, on and BAR_HEIGHT or 0)}))
 end
 table.insert(tweens, TweenService:Create(grade, info,
  {Contrast = on and GRADE.Contrast or 0, Saturation = on and GRADE.Saturation or 0}))
 for _, tween in tweens do tween:Play() end
end

-- A client-local Sound on the tee, created on first use.
local function playCrack(stem)
 local sound = stem:FindFirstChild("BatCrack")
 if not sound then
  sound = Instance.new("Sound")
  sound.Name, sound.SoundId, sound.Volume = "BatCrack", HIT_SOUND_ID, HIT_SOUND_VOLUME
  sound.RollOffMode, sound.RollOffMinDistance, sound.RollOffMaxDistance = Enum.RollOffMode.InverseTapered, 20, 300
  sound.Parent = stem
 end
 sound:Play()
end

-- Has this station's ball visibly left the tee for the current hit? Also keeps the ball's
-- model on it and runs its flight effects.
local launched, effects = {}, {}
local function stopEffects(worldId)
 if effects[worldId] then BallEffects.Stop(effects[worldId]) end
 effects[worldId] = nil
end

local function updateStation(world, dt)
 local area = workspace:FindFirstChild(world.stationName)
 local ball = area and area:FindFirstChild("Baseball")
 local tee = area and area:FindFirstChild("Tee")
 local stem = tee and tee:FindFirstChild("Stem")
 local spot = stem and stem:FindFirstChild("BallPosition")
 if not ball or not spot then launched[world.id] = nil stopEffects(world.id) return false end
 BallEffects.UpdateVisual(ball)
 if ball:GetAttribute("BallState") ~= "InFlight" then launched[world.id] = nil stopEffects(world.id) return false end
 if not launched[world.id] then
  local rest = (spot.WorldCFrame * CFrame.new(0, ball.Size.Y / 2, 0)).Position
  if (ball.Position - rest).Magnitude < LEAVE_DISTANCE then return false end
  launched[world.id] = true
  playCrack(stem)
  effects[world.id] = BallEffects.Launch(ball, ball:GetAttribute("EquipmentId"), rest)
  local pad = area:FindFirstChild("BatterPosition")
  BallEffects.Burst(BatEffects.ContactBurstFor(pad and pad:GetAttribute("OccupantUserId")), rest)
 end
 if effects[world.id] then BallEffects.Update(effects[world.id], ball, dt) end
 return true
end

local active = false
local swingStartedAt

-- Listens for "SwingStart" on the local player's bat marker (fired by BatClient on a real swing).
local markerTool, markerConnection
local function watchSwingMarker()
 local tool = Player.Character and Player.Character:FindFirstChild("Bat")
 if tool == markerTool then return end
 if markerConnection then markerConnection:Disconnect() markerConnection = nil end
 local marker = tool and tool:FindFirstChild("SwingMarkerReached")
 markerTool = marker and tool or nil
 if marker then
  markerConnection = marker.Event:Connect(function(name)
   if name == "SwingStart" then swingStartedAt = os.clock() end
  end)
 end
end

-- RenderStepped: after the ball's rendered position updates, before the frame is drawn.
RunService.RenderStepped:Connect(function(dt)
 BatEffects.Update(dt)
 watchSwingMarker()
 for _, world in Worlds.Worlds do updateStation(world, dt) end
 local swinging = swingStartedAt ~= nil and os.clock() - swingStartedAt < SWING_GRACE_SECONDS
 local cinematic = swinging or Player:GetAttribute("HitActive") == true
 if cinematic ~= active then
  active = cinematic
  playCinematic(cinematic)
 end
end)
