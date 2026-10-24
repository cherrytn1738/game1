-- Hit presentation, started the moment the ball visibly leaves the tee:
--   * the bat crack, at every batting station, so nearby players hear each other's hits
--   * for the local player's own swing and hit: black letterbox bars and a punchier colour
--     grade, from the click that starts the swing until the hit ends
--   * each ball's model and flight effects (BallEffects), for every station
--   * the batter's Bat contact burst, and swing trails on every held Bat (BatEffects)
--   * white speed lines rushing out across the local player's screen while their own ball flies
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
local BallSounds = require(script.Parent:WaitForChild("BallSounds"))
local GameAudio = require(ReplicatedStorage:WaitForChild("GameAudio"))

local LEAVE_DISTANCE = 0.5 -- studs the rendered ball must move off its tee spot
local BAR_HEIGHT = 0.11 -- share of the screen height covered by each bar
local IN_SECONDS, OUT_SECONDS = 0.35, 0.5
local GRADE = {Contrast = 0.12, Saturation = 0.2}
-- After the click, the bars stay this long waiting for the server to accept the swing
-- (HitActive); a refused swing lets them slide back out.
local SWING_GRACE_SECONDS = 1.2
-- Speed lines: thin white streaks rushing outward from around the ball (the flight camera rides
-- behind it), busier, longer and brighter the faster it goes, so they thin out as it slows.
-- They start a little way out from the middle so the ball itself stays clear. Legendary and
-- Mythic Hits draw their own (while CinematicCamera is set).
local SPEED_LINE_COUNT = 28
local SPEED_LINE_MIN_SPEED, SPEED_LINE_FULL_SPEED = 25, 160 -- studs per second: none / full strength
local SPEED_LINE_START = 0.3 -- where a streak appears, as a share of half the screen diagonal
local SPEED_LINE_SECONDS = {0.22, 0.4} -- time to fly out past the edge at full strength
local SPEED_LINE_OPACITY = 0.85 -- at full strength
local SPEED_LINE_COLOR = Color3.new(1, 1, 1)

-- Below GameHUD (12) so the distance counter and 2x button stay readable on the bars.
local gui = Instance.new("ScreenGui")
gui.Name, gui.DisplayOrder, gui.ResetOnSpawn, gui.IgnoreGuiInset = "HitCinematic", 11, false, true
local bars = {}
for _, edge in {0, 1} do
 local bar = Instance.new("Frame")
 bar.Name = edge == 0 and "TopBar" or "BottomBar"
 bar.AnchorPoint, bar.Position, bar.Size = Vector2.new(0, edge), UDim2.fromScale(0, edge), UDim2.fromScale(1, 0)
 bar.BackgroundColor3, bar.BorderSizePixel, bar.ZIndex = Color3.new(0, 0, 0), 0, 2 -- above the speed lines
 bar.Parent = gui
 table.insert(bars, bar)
end
local speedLineFrame = Instance.new("Frame")
speedLineFrame.Name, speedLineFrame.Size, speedLineFrame.BackgroundTransparency = "SpeedLines", UDim2.fromScale(1, 1), 1
speedLineFrame.Parent = gui
gui.Parent = Player:WaitForChild("PlayerGui")

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "HitCinematicGrade"
grade.Parent = Lighting

-- Each streak flies from SPEED_LINE_START out past the screen edge along its own angle, then
-- waits to be relaunched; how often it relaunches depends on the ball's speed.
local rng = Random.new()
local streaks = {}
for i = 1, SPEED_LINE_COUNT do
 local line = Instance.new("Frame")
 line.Name, line.AnchorPoint, line.BorderSizePixel = "Streak" .. i, Vector2.new(0.5, 0.5), 0
 line.BackgroundColor3, line.Visible = SPEED_LINE_COLOR, false
 line.Parent = speedLineFrame
 table.insert(streaks, {line = line, progress = 1, waiting = rng:NextNumber(0, 0.3)})
end

local function launchStreak(streak, strength)
 streak.angle = rng:NextNumber(0, math.pi * 2)
 streak.progress = 0
 streak.seconds = rng:NextNumber(SPEED_LINE_SECONDS[1], SPEED_LINE_SECONDS[2]) / (0.5 + 0.5 * strength)
 streak.length = rng:NextNumber(0.1, 0.22) * (0.5 + 0.5 * strength) -- share of half the diagonal
 streak.thickness = rng:NextInteger(2, 3)
 streak.opacity = SPEED_LINE_OPACITY * strength * rng:NextNumber(0.6, 1)
end

local function updateSpeedLines(speed, dt)
 local strength = math.clamp((speed - SPEED_LINE_MIN_SPEED) / (SPEED_LINE_FULL_SPEED - SPEED_LINE_MIN_SPEED), 0, 1)
 local camera = workspace.CurrentCamera
 local viewport = camera and camera.ViewportSize or Vector2.one
 local center, reach = viewport / 2, viewport.Magnitude / 2
 for _, streak in streaks do
  if streak.progress >= 1 then
   streak.line.Visible = false
   streak.waiting -= dt
   -- A slow ball relaunches few streaks (and a stopped one none), so the lines thin out.
   if strength > 0 and streak.waiting <= 0 then
    if rng:NextNumber() < strength then launchStreak(streak, strength) end
    streak.waiting = rng:NextNumber(0.02, 0.12)
   end
  end
  if streak.progress < 1 then
   streak.progress = math.min(1, streak.progress + dt / streak.seconds)
   -- Speeds up on the way out, like scenery rushing past the edge of view.
   local t = streak.progress * streak.progress
   local length = streak.length * reach
   local radius = (SPEED_LINE_START + (1.05 - SPEED_LINE_START) * t) * reach + length / 2
   local position = center + Vector2.new(math.cos(streak.angle), math.sin(streak.angle)) * radius
   streak.line.Position = UDim2.fromOffset(position.X, position.Y)
   streak.line.Size = UDim2.fromOffset(length, streak.thickness)
   streak.line.Rotation = math.deg(streak.angle)
   streak.line.BackgroundTransparency = 1 - streak.opacity * math.clamp(streak.progress * 4, 0, 1)
   streak.line.Visible = true
  end
 end
end

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

-- Load the crack up front so the session's first hit isn't late. The cue (GameAudio.BatCrack)
-- starts just before the crack in the recording, so it lands as the ball leaves the tee.
GameAudio.Preload({"BatCrack"})

-- Has this station's ball visibly left the tee for the current hit? Also keeps the ball's
-- model on it and runs its flight effects.
local launched, effects, sounds = {}, {}, {}
local ownBall -- the local player's own ball this frame while it is flying, for the speed lines
local function stopEffects(worldId)
 if effects[worldId] then BallEffects.Stop(effects[worldId]) end
 if sounds[worldId] then BallSounds.Stop(sounds[worldId]) end
 effects[worldId], sounds[worldId] = nil, nil
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
 local pad = area:FindFirstChild("BatterPosition")
 if not launched[world.id] then
  local rest = (spot.WorldCFrame * CFrame.new(0, ball.Size.Y / 2, 0)).Position
  if (ball.Position - rest).Magnitude < LEAVE_DISTANCE then return false end
  launched[world.id] = true
  -- A Mythic Hit's third swing already cracked at its contact (MythicHitClient), and so did the
  -- batter's own Legendary Hit (LegendaryHitClient); a second crack as the ball moves off
  -- would land just after the bat and blur the cinematic's launch boom.
  local ownLegendary = ball:GetAttribute("LegendaryHitUserId") == Player.UserId
  if not ball:GetAttribute("MythicHitUserId") and not ownLegendary then GameAudio.Play("BatCrack", stem) end
  effects[world.id] = BallEffects.Launch(ball, ball:GetAttribute("EquipmentId"), rest)
  sounds[world.id] = BallSounds.Start(ball, ball:GetAttribute("EquipmentId"))
  BallEffects.Burst(BatEffects.ContactBurstFor(pad and pad:GetAttribute("OccupantUserId")), rest)
 end
 if pad and pad:GetAttribute("OccupantUserId") == Player.UserId then ownBall = ball end
 if effects[world.id] then BallEffects.Update(effects[world.id], ball, dt) end
 if sounds[world.id] then BallSounds.Update(sounds[world.id], ball, dt) end
 return true
end

local active = false
local ballSpeed = 0 -- smoothed, so the lines ease in and out
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
 ownBall = nil
 for _, world in Worlds.Worlds do updateStation(world, dt) end
 local cinematicCamera = Player:GetAttribute("CinematicCamera")
 local speed = ownBall and not cinematicCamera and ownBall.AssemblyLinearVelocity.Magnitude or 0
 ballSpeed += (speed - ballSpeed) * math.min(1, dt * 8)
 updateSpeedLines(ballSpeed, dt)
 local swinging = swingStartedAt ~= nil and os.clock() - swingStartedAt < SWING_GRACE_SECONDS
 local cinematic = swinging or Player:GetAttribute("HitActive") == true
 if cinematic ~= active then
  active = cinematic
  playCinematic(cinematic)
 end
end)
