-- Shared pieces for the rare-hit cinematics (LegendaryHitClient, MythicHitClient):
--   * effect parts, lightning, shockwaves, emitters, sounds and easing helpers
--   * the batter's screen overlay: flash, letterbox bars, speed lines and a themed title
--   * a short announcement for other players
--   * swing control through the Bat's client-local attributes (read by BatClient)
--   * the chase camera that rides behind the launched ball
--   * a station watcher that starts, updates and cleans up one cinematic per station
-- Presentation only: nothing here touches launch, distance or rewards.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Swing = require(ReplicatedStorage:WaitForChild("SwingConfig"))
local Player = Players.LocalPlayer

local FX = {}

FX.Textures = {
 Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
 Spark = "rbxasset://textures/particles/fire_sparks_main.dds",
 Smoke = "rbxasset://textures/particles/smoke_main.dds",
 Fire = "rbxasset://textures/particles/fire_main.dds",
 Shockwave = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
}
-- A Cylinder's axis is its X axis: this turns it into a flat disc (or a vertical column).
FX.FLAT = CFrame.Angles(0, 0, math.pi / 2)
FX.LeaveDistance = 0.5 -- studs the rendered ball must move off the tee to count as launched
FX.RenderLag = Swing.LaunchVisualLead -- server-moved parts are drawn about this far behind

FX.rng = Random.new()
function FX.lerp(a, b, t) return a + (b - a) * t end
function FX.clamp01(t) return math.clamp(t, 0, 1) end
function FX.easeOut(t) t = math.clamp(t, 0, 1) return 1 - (1 - t)^3 end
function FX.smooth(t) t = math.clamp(t, 0, 1) return t * t * (3 - 2 * t) end
function FX.shakeAngles(amount, t)
 return CFrame.Angles(math.noise(t * 25, 0.3) * amount, math.noise(0.7, t * 25) * amount, math.noise(t * 25, 1.9) * amount * 0.5)
end

local container = Instance.new("Folder")
container.Name = "HitCinematicEffects"
container.Parent = workspace
FX.Container = container

function FX.Tween(object, seconds, goal, style, direction)
 local tween = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad,
  direction or Enum.EasingDirection.Out), goal)
 tween:Play()
 return tween
end

function FX.Part(name, cframe, size)
 local part = Instance.new("Part")
 part.Name, part.CFrame, part.Size, part.Transparency = name, cframe, size or Vector3.one * 0.2, 1
 part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
 part.Parent = container
 return part
end

function FX.Neon(name, cframe, size, color, transparency, shape)
 local part = FX.Part(name, cframe, size)
 part.Material, part.Color, part.Transparency = Enum.Material.Neon, color, transparency or 0
 if shape then part.Shape = shape end
 return part
end

function FX.Emitter(parent, properties)
 local emitter = Instance.new("ParticleEmitter")
 emitter.LightInfluence, emitter.LightEmission = 0, 1
 for property, value in properties do emitter[property] = value end
 emitter.Parent = parent
 return emitter
end

-- spec = {id, volume, playbackSpeed?, startAt?}. startAt skips a recording's quiet lead-in so
-- its hit lands on cue. Parented to a part it is heard from there; anywhere else
-- (SoundService) it plays flat for the local player only.
function FX.Sound(spec, parent, properties)
 local sound = Instance.new("Sound")
 sound.SoundId, sound.Volume, sound.PlaybackSpeed = spec[1], spec[2], spec[3] or 1
 sound.TimePosition = spec[4] or 0
 if parent:IsA("BasePart") then
  sound.RollOffMode, sound.RollOffMinDistance, sound.RollOffMaxDistance = Enum.RollOffMode.InverseTapered, 30, 600
 end
 for property, value in properties or {} do sound[property] = value end
 sound.Parent = parent
 sound:Play()
 if not sound.Looped then Debris:AddItem(sound, 14) end
 return sound
end

-- Loads sounds ahead of time (specs = a table of {id, ...} or ids), so the first one played in a
-- session starts on cue instead of after a download delay.
local preloadFolder = Instance.new("Folder")
preloadFolder.Name = "PreloadedSounds"
preloadFolder.Parent = game:GetService("SoundService")
function FX.Preload(specs)
 local sounds = {}
 for _, spec in specs do
  local sound = Instance.new("Sound")
  sound.SoundId = type(spec) == "table" and spec[1] or spec
  sound.Parent = preloadFolder
  table.insert(sounds, sound)
 end
 task.spawn(function()
  pcall(function() game:GetService("ContentProvider"):PreloadAsync(sounds) end)
 end)
end

-- Plays a sound that belongs to cinematic c (kept in c.sounds), so it can be faded out with it.
function FX.PlayFor(c, spec, parent, properties)
 local sound = FX.Sound(spec, parent, properties)
 c.sounds = c.sounds or {}
 table.insert(c.sounds, sound)
 return sound
end

-- Fades all of c's sounds out over `seconds` and removes them: a cinematic's audio ends with
-- its pictures (or sooner, when a short hit ends first) rather than playing on past them.
function FX.FadeSounds(c, seconds)
 for _, sound in c.sounds or {} do
  if sound.Parent then
   FX.Tween(sound, seconds, {Volume = 0}, Enum.EasingStyle.Linear)
   Debris:AddItem(sound, seconds + 0.05)
  end
 end
 c.sounds = {}
end

-- A jagged lightning bolt between two points that flickers out.
function FX.Bolt(from, to, color, width, life)
 local length = (to - from).Magnitude
 local segments = math.clamp(math.floor(length / 2.5), 3, 14)
 local jitter = math.clamp(length * 0.08, 0.3, 6)
 local previous = from
 for i = 1, segments do
  local point = from:Lerp(to, i / segments)
  if i < segments then point += FX.rng:NextUnitVector() * jitter * FX.rng:NextNumber(0.4, 1) end
  local segment = FX.Neon("Bolt", CFrame.lookAt((previous + point) / 2, point),
   Vector3.new(width, width, (point - previous).Magnitude), color)
  FX.Tween(segment, life, {Transparency = 1}, Enum.EasingStyle.Linear)
  Debris:AddItem(segment, life)
  previous = point
 end
end

-- A flat glowing ring racing outward along the ground.
function FX.Shockwave(position, color, fromSize, toSize, seconds)
 local disc = FX.Neon("Shockwave", CFrame.new(position) * FX.FLAT, Vector3.new(0.15, fromSize, fromSize),
  color, 0.2, Enum.PartType.Cylinder)
 FX.Tween(disc, seconds, {Size = Vector3.new(0.15, toSize, toSize), Transparency = 1})
 Debris:AddItem(disc, seconds)
 local holder = FX.Part("ShockwaveRing", CFrame.new(position))
 local wave = FX.Emitter(holder, {Texture = FX.Textures.Shockwave, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
  EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01), Enabled = false,
  Color = ColorSequence.new(color), Lifetime = NumberRange.new(seconds),
  Size = NumberSequence.new(fromSize / 2, toSize / 2), Transparency = NumberSequence.new(0, 1)})
 wave:Emit(1)
 Debris:AddItem(holder, seconds + 0.2)
end

-- A tail that rides with the launched ball: ribbons = {{width, trail properties}},
-- emitters = {emitter properties}, light = {color, brightness, range}.
function FX.Comet(position, ribbons, emitters, light)
 local comet = FX.Part("CometTail", CFrame.new(position))
 for _, ribbon in ribbons do
  local width, properties = ribbon[1], ribbon[2]
  local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
  a0.Position, a1.Position = Vector3.new(0, width / 2, 0), Vector3.new(0, -width / 2, 0)
  a0.Parent, a1.Parent = comet, comet
  local trail = Instance.new("Trail")
  trail.Attachment0, trail.Attachment1, trail.FaceCamera, trail.LightInfluence = a0, a1, true, 0
  for property, value in properties do trail[property] = value end
  trail.Parent = comet
 end
 for _, properties in emitters do FX.Emitter(comet, properties) end
 local point = Instance.new("PointLight")
 point.Color, point.Brightness, point.Range = light[1], light[2], light[3]
 point.Parent = comet
 return comet
end

-- Turns a comet's trails and particles off and lets them fade before removing it.
function FX.FadeOut(part, seconds)
 for _, child in part:GetDescendants() do
  if child:IsA("Trail") or child:IsA("ParticleEmitter") then child.Enabled = false end
 end
 Debris:AddItem(part, seconds or 1.5)
end

-- ---------- the batter's screen overlay ----------

local gui = Instance.new("ScreenGui")
gui.Name, gui.DisplayOrder, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.Enabled = "HitCinematicOverlay", 13, false, true, false

local flash = Instance.new("Frame")
flash.Name, flash.Size, flash.BackgroundColor3, flash.BackgroundTransparency, flash.BorderSizePixel, flash.ZIndex =
 "Flash", UDim2.fromScale(1, 1), Color3.new(1, 1, 1), 1, 0, 10
flash.Parent = gui

local bars, barEdges = {}, {}
for _, edge in {0, 1} do
 local bar = Instance.new("Frame")
 bar.Name = edge == 0 and "TopBar" or "BottomBar"
 bar.AnchorPoint, bar.Position, bar.Size = Vector2.new(0, edge), UDim2.fromScale(0, edge), UDim2.fromScale(1, 0)
 bar.BackgroundColor3, bar.BorderSizePixel, bar.ZIndex = Color3.new(0, 0, 0), 0, 3 -- above the speed lines
 local line = Instance.new("Frame")
 line.Name, line.BorderSizePixel = "Edge", 0
 line.AnchorPoint, line.Position, line.Size = Vector2.new(0, 1 - edge), UDim2.fromScale(0, 1 - edge), UDim2.new(1, 0, 0, 3)
 line.Parent = bar
 bar.Parent = gui
 table.insert(bars, bar)
 table.insert(barEdges, line)
end

-- Speed lines streaking in from the screen edges.
local speedLines = Instance.new("Frame")
speedLines.Name, speedLines.Size, speedLines.BackgroundTransparency, speedLines.Visible = "SpeedLines", UDim2.fromScale(1, 1), 1, false
speedLines.Parent = gui
local lines = {}
for i = 1, 30 do
 local spoke = Instance.new("Frame")
 spoke.AnchorPoint, spoke.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
 spoke.Size, spoke.SizeConstraint = UDim2.fromScale(1.3, 1.3), Enum.SizeConstraint.RelativeXX
 spoke.BackgroundTransparency, spoke.Rotation = 1, (i - 1) * 12 + FX.rng:NextNumber(-4, 4)
 local line = Instance.new("Frame")
 line.AnchorPoint, line.BorderSizePixel, line.Position = Vector2.new(1, 0.5), 0, UDim2.fromScale(1, 0.5)
 line.Parent = spoke
 spoke.Parent = speedLines
 table.insert(lines, line)
end

local function label(name, position, height, maxSize)
 local textLabel = Instance.new("TextLabel")
 textLabel.Name, textLabel.Font, textLabel.TextScaled = name, Enum.Font.GothamBlack, true
 textLabel.AnchorPoint, textLabel.Position, textLabel.Size = Vector2.new(0.5, 0.5), position, UDim2.fromScale(0.9, height)
 textLabel.BackgroundTransparency, textLabel.TextColor3, textLabel.Visible = 1, Color3.new(1, 1, 1), false
 local limit = Instance.new("UITextSizeConstraint")
 limit.MaxTextSize = maxSize
 limit.Parent = textLabel
 local stroke = Instance.new("UIStroke")
 stroke.Thickness = 4
 stroke.Parent = textLabel
 local scale = Instance.new("UIScale")
 scale.Parent = textLabel
 textLabel.Parent = gui
 return {label = textLabel, stroke = stroke, scale = scale}
end
local title = label("Title", UDim2.fromScale(0.5, 0.35), 0.15, 120)
local titleGradient = Instance.new("UIGradient")
titleGradient.Rotation = 18
titleGradient.Parent = title.label
local subtitle = label("Subtitle", UDim2.fromScale(0.5, 0.455), 0.06, 46)

local playerGui = Player:WaitForChild("PlayerGui")
gui.Parent = playerGui

-- theme = {edge = Color3, title = text, subtitle = text, titleColors = ColorSequence,
--   subtitleColor = Color3, stroke = Color3, speedLineColor = Color3}
local theme
function FX.ShowScreen(newTheme)
 theme = newTheme
 for _, line in barEdges do line.BackgroundColor3 = theme.edge end
 for _, line in lines do line.BackgroundColor3 = theme.speedLineColor or Color3.new(1, 1, 1) end
 title.label.Text, subtitle.label.Text = theme.title, theme.subtitle
 titleGradient.Color = theme.titleColors
 subtitle.label.TextColor3 = theme.subtitleColor
 title.stroke.Color, subtitle.stroke.Color = theme.stroke, theme.stroke
 title.label.Visible, subtitle.label.Visible, speedLines.Visible = false, false, false
 gui.Enabled = true
end

function FX.HideScreen()
 gui.Enabled = false
 title.label.Visible, subtitle.label.Visible, speedLines.Visible = false, false, false
 for _, bar in bars do bar.Size = UDim2.fromScale(1, 0) end
 flash.BackgroundTransparency = 1
end

function FX.Flash(color, transparency, seconds)
 flash.BackgroundColor3, flash.BackgroundTransparency = color, transparency
 FX.Tween(flash, seconds, {BackgroundTransparency = 1})
end

function FX.SetBars(height, seconds)
 for _, bar in bars do FX.Tween(bar, seconds, {Size = UDim2.fromScale(1, height)}) end
end

-- Slams the title in (giant to normal size with a tilt), then the subtitle.
function FX.ShowTitle()
 title.label.Visible, title.label.TextTransparency, title.label.Rotation = true, 0, -10
 title.stroke.Transparency, title.scale.Scale = 0, 3
 FX.Tween(title.scale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
 FX.Tween(title.label, 0.45, {Rotation = 0}, Enum.EasingStyle.Back)
 subtitle.label.Visible, subtitle.label.TextTransparency, subtitle.stroke.Transparency = true, 1, 1
 task.delay(0.3, function()
  subtitle.scale.Scale = 1.6
  FX.Tween(subtitle.label, 0.35, {TextTransparency = 0})
  FX.Tween(subtitle.stroke, 0.35, {Transparency = 0})
  FX.Tween(subtitle.scale, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
 end)
end

function FX.HideTitle()
 FX.Tween(title.scale, 0.5, {Scale = 1.4}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
 for _, part in {title, subtitle} do
  FX.Tween(part.label, 0.5, {TextTransparency = 1})
  FX.Tween(part.stroke, 0.5, {Transparency = 1})
 end
end

-- Strength 0..1 shows flickering speed lines; nil hides them.
function FX.SpeedLines(strength)
 speedLines.Visible = strength ~= nil and strength > 0
 if not speedLines.Visible then return end
 for _, line in lines do
  line.Size = UDim2.new(FX.rng:NextNumber(0.2, 0.36), 0, 0, FX.rng:NextInteger(2, 4))
  line.BackgroundTransparency = 1 - strength * FX.rng:NextNumber(0.15, 0.6)
 end
end

-- Title shimmer: a bright band sweeping across the title's gradient.
RunService.RenderStepped:Connect(function()
 if gui.Enabled and title.label.Visible then titleGradient.Offset = Vector2.new((os.clock() * 0.6) % 2 - 1, 0) end
end)

-- ---------- announcement for other players ----------

local announceGui = Instance.new("ScreenGui")
announceGui.Name, announceGui.DisplayOrder, announceGui.ResetOnSpawn = "HitCinematicAnnouncement", 13, false
local announce = Instance.new("TextLabel")
announce.Name, announce.Font, announce.TextScaled, announce.Visible = "Announcement", Enum.Font.GothamBlack, true, false
announce.AnchorPoint, announce.Position, announce.Size = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.7, 0.05)
announce.BackgroundTransparency = 1
local announceLimit = Instance.new("UITextSizeConstraint")
announceLimit.MaxTextSize = 34
announceLimit.Parent = announce
local announceStroke = Instance.new("UIStroke")
announceStroke.Thickness = 3
announceStroke.Parent = announce
announce.Parent = announceGui
announceGui.Parent = playerGui

local announceToken = 0
function FX.Announce(text, color, strokeColor)
 announceToken += 1
 local token = announceToken
 announce.Text, announce.TextColor3, announceStroke.Color = text, color, strokeColor
 announce.TextTransparency, announceStroke.Transparency, announce.Visible = 1, 1, true
 FX.Tween(announce, 0.4, {TextTransparency = 0})
 FX.Tween(announceStroke, 0.4, {Transparency = 0})
 task.delay(4.5, function()
  if token ~= announceToken then return end
  FX.Tween(announce, 0.6, {TextTransparency = 1})
  FX.Tween(announceStroke, 0.6, {Transparency = 1})
 end)
end

function FX.DisplayNameOf(userId)
 local batter = Players:GetPlayerByUserId(userId)
 return batter and batter.DisplayName or "Someone"
end

-- ---------- swing control ----------
-- BatClient reads two client-local attributes on the Bat: SwingHoldAt stops the swing at that
-- time (it fires a "Hold" marker), SwingClockOverride sets the swing time directly.

function FX.BatterTool()
 return Player.Character and Player.Character:FindFirstChild("Bat")
end

-- The local player's current swing, from the Bat's markers: startedAt (os.clock of the click)
-- and held (the swing has reached SwingHoldAt).
FX.Swing = {startedAt = nil, held = false}
local markerTool, markerConnection
RunService.RenderStepped:Connect(function()
 local tool = FX.BatterTool()
 if tool == markerTool then return end
 if markerConnection then markerConnection:Disconnect() markerConnection = nil end
 local marker = tool and tool:FindFirstChild("SwingMarkerReached")
 markerTool = marker and tool or nil
 if marker then
  markerConnection = marker.Event:Connect(function(name)
   if name == "SwingStart" then FX.Swing.startedAt, FX.Swing.held = os.clock(), false
   elseif name == "Hold" then FX.Swing.held = true end
  end)
 end
end)

-- Seconds into the current swing (nil with no swing).
function FX.SwingTime()
 return FX.Swing.startedAt and os.clock() - FX.Swing.startedAt
end

function FX.SetSwingClock(tool, seconds)
 if tool then
  tool:SetAttribute("SwingHoldAt", nil)
  tool:SetAttribute("SwingClockOverride", seconds)
 end
end

function FX.ReleaseSwing(tool)
 if tool then
  tool:SetAttribute("SwingHoldAt", nil)
  tool:SetAttribute("SwingClockOverride", nil)
 end
end

-- ---------- chase camera ----------
-- Rides behind and beside the launched ball, drifting wider as it climbs. c needs ballPosition,
-- direction (smoothed flight direction), side (+1/-1: which side to ride on), chaseFrom (the
-- camera offset from the ball at launch) and launchFov; s is seconds since the launch.
function FX.ChaseCamera(c, s, seconds, launchFov, chaseFov)
 local camera = workspace.CurrentCamera
 local back = -Vector3.new(c.direction.X, 0, c.direction.Z).Unit
 local side = back:Cross(Vector3.yAxis) * -c.side
 local near = back * 10 + Vector3.yAxis * 3.2 + side * 3
 local far = back * 15 + Vector3.yAxis * 6.5 + side * 7
 local target = near:Lerp(far, FX.smooth(s / seconds))
 local offset = c.chaseFrom:Lerp(target, FX.easeOut(s / 0.9))
 local roll = math.sin(s * 1.6) * math.rad(7) * (1 - FX.smooth(s / seconds))
 camera.FieldOfView = s < 0.25 and FX.lerp(c.launchFov, launchFov, FX.easeOut(s / 0.25))
  or FX.lerp(launchFov, chaseFov, FX.smooth((s - 0.25) / 1.4))
 camera.CFrame = CFrame.lookAt(c.ballPosition + offset, c.ballPosition + c.direction * 20) * CFrame.Angles(0, 0, roll)
  * FX.shakeAngles(0.035 * math.max(0, 1 - s / 0.7), s)
end

-- Tracks the rendered ball's position, smoothed flight direction and smoothed speed on c.
function FX.TrackBall(c, ball, dt)
 local position = ball.Position
 local velocity = dt > 0 and (position - (c.lastBall or position)) / dt or Vector3.zero
 if velocity.Magnitude > 2 then c.direction = c.direction:Lerp(velocity.Unit, math.min(1, dt * 8)).Unit end
 c.speed = c.speed and FX.lerp(c.speed, velocity.Magnitude, math.min(1, dt * 6)) or velocity.Magnitude
 c.lastBall, c.ballPosition = position, position
end

-- The end of a cinematic's chase: chaseSeconds after the launch, or sooner when the ball is
-- already slowing to a stop (a short hit from a low Level), so the pictures and audio end with
-- the hit instead of lingering over a rolling ball.
local SLOW_BALL_SPEED = 12 -- studs per second
local SLOW_CHECK_AFTER = 1 -- seconds after the launch
function FX.ChaseTimeLeft(c, chaseSeconds)
 local now = os.clock()
 c.chaseEndAt = c.chaseEndAt or c.leftAt + chaseSeconds
 if not c.slowEnd and now - c.leftAt >= SLOW_CHECK_AFTER and (c.speed or math.huge) < SLOW_BALL_SPEED then
  c.slowEnd = true
  c.chaseEndAt = math.min(c.chaseEndAt, now + 0.6)
 end
 return c.chaseEndAt - now
end

function FX.RestPosition(area, ball)
 return (area.Tee.Stem.BallPosition.WorldCFrame * CFrame.new(0, ball.Size.Y / 2, 0)).Position
end

function FX.HasLeftTee(c)
 return c.ball:GetAttribute("BallState") == "InFlight" and (c.ball.Position - c.rest).Magnitude >= FX.LeaveDistance
end

-- ---------- station watcher ----------
-- Watches every station's ball for `<kind>HitUserId` and runs one cinematic per station:
--   handlers.ready(info) -> true when it should start; info = {mine, waited, ball, area}
--   handlers.start(world, area, ball, mine) -> c (a table; the watcher sets c.ball and c.mine)
--   handlers.update(c, dt), handlers.stop(c), handlers.release(c) (hand back camera/swing)
-- It stops the batter's cinematic as soon as they leave the box, and contains errors so a
-- broken cinematic can never keep the camera.
function FX.WatchStations(kind, handlers)
 local attribute = kind .. "HitUserId"
 local running, seen = {}, {}
 local function halt(c)
  if c.stopped then return end
  c.stopped = true
  local ok, message = pcall(handlers.stop, c)
  if not ok then warn(kind .. " Hit cleanup failed: " .. tostring(message)) end
 end
 RunService.RenderStepped:Connect(function(dt)
  for _, world in Worlds.Worlds do
   local area = workspace:FindFirstChild(world.stationName)
   local ball = area and area:FindFirstChild("Baseball")
   local userId = ball and ball:GetAttribute(attribute)
   local c = running[world.id]
   if c and (not userId or c.ball ~= ball) then
    halt(c)
    running[world.id], c = nil, nil
   elseif c and c.mine and not Player:GetAttribute("BattingActive") then
    halt(c) -- the batter left the box: the server cancels the hit when the hold ends
   end
   if not userId then
    seen[world.id] = nil
   elseif c then
    if not c.stopped then
     local ok, message = pcall(handlers.update, c, dt)
     if not ok then
      warn(kind .. " Hit cinematic stopped: " .. tostring(message))
      halt(c)
     end
    end
   else
    seen[world.id] = seen[world.id] or os.clock()
    local mine = userId == Player.UserId
    local info = {mine = mine, waited = os.clock() - seen[world.id], ball = ball, area = area}
    local ready = handlers.ready(info)
    if ready then
     local ok, result = pcall(handlers.start, world, area, ball, mine)
     if ok then
      result.ball, result.mine = ball, mine
      running[world.id] = result
     else
      warn(kind .. " Hit cinematic unavailable: " .. tostring(result))
      local dead = {ball = ball, mine = mine, stopped = true}
      pcall(handlers.release, dead)
      running[world.id] = dead
     end
    end
   end
  end
 end)
end

return FX
