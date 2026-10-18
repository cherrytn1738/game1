-- Legendary Hit: a rare (Swing.LegendaryHit.Chance) cinematic hit, about 7 seconds long.
-- The server rolls it and holds the launch while time "freezes" at contact:
--   contact   the swing stops exactly as the bat meets the ball (Swing.BallContactTime); flash
--             and boom; the world drains of colour; sparks, dust and a shockwave hang in the air
--   orbit     the camera circles the batter and the ball while energy and lightning gather
--   charge    a cut to behind the ball; a pillar of light rises, colour floods back gold, the
--             title slams in
--   launch    the real launch: shockwaves, lightning from the sky, the frozen debris blasts
--             outward, the crowd roars, the swing follows through
--   chase     the camera rides behind the ball, then blends back into the normal flight view
-- Everyone sees the world effects at that station and gets a short announcement; only the
-- batter gets the camera, the title and the screen effects. Presentation only.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Swing = require(ReplicatedStorage:WaitForChild("SwingConfig"))
local BallEffects = require(script.Parent:WaitForChild("BallEffects"))
local FX = require(script.Parent:WaitForChild("CinematicFX"))
local Player = Players.LocalPlayer
local lerp, clamp01, easeOut, smooth, rng = FX.lerp, FX.clamp01, FX.easeOut, FX.smooth, FX.rng

-- Roblox-licensed audio (Pro Sound Effects and APM Music libraries): {id, volume,
-- playbackSpeed, startAt} (startAt skips a quiet lead-in).
local SOUNDS = {
 Crack = {"rbxassetid://9125380872", 1, 1, 0.58}, -- bat crack, started at the crack (0.61 s in)
 ContactBoom = {"rbxassetid://9125484526", 0.9}, -- deep boom, rumbling tail
 Heartbeat = {"rbxassetid://9043365842", 1},
 Riser = {"rbxassetid://9043343295", 0.7}, -- reverse swell with a hard end, timed to the launch
 Sting = {"rbxassetid://1837950801", 0.5}, -- "For The Glory" brass sting, with the title
 LaunchBoom = {"rbxassetid://9125484511", 1},
 Crowd = {"rbxassetid://9120975204", 0.55}, -- crowd cheer with pyro
}

local GOLD = Color3.fromRGB(255, 200, 50)
local GOLD_LIGHT = Color3.fromRGB(255, 240, 170)
local ELECTRIC = Color3.fromRGB(190, 225, 255)
local THEME = {
 edge = GOLD, title = "LEGENDARY HIT!", subtitle = "1 IN 1,000", stroke = Color3.fromRGB(70, 32, 0),
 subtitleColor = GOLD_LIGHT, speedLineColor = Color3.new(1, 1, 1),
 titleColors = ColorSequence.new({
  ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 20)), ColorSequenceKeypoint.new(0.42, Color3.fromRGB(255, 215, 60)),
  ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.58, Color3.fromRGB(255, 215, 60)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 20))}),
}

-- Timeline (seconds). The hold before launch comes from the server; the charge fills its last
-- CHARGE_SECONDS and the orbit the time before that.
local IMPACT_SECONDS = 0.3 -- freeze frame before the camera starts to move
local CHARGE_SECONDS = 1.15
local TITLE_LEAD = 1.0 -- the title slams in this long before the launch...
local TITLE_HOLD = 2.3 -- ...and leaves this long after it
local CHASE_SECONDS = 3.2 -- the chase camera, before the normal flight camera takes back over
local SOUND_FADE_SECONDS = 1 -- the audio fades out over the end of the chase
local STOP_FADE_SECONDS = 0.4 -- or this fast if the hit ends first
local CONTACT_WAIT_LIMIT = 1 -- batter: start anyway if the swing never reports reaching contact
local OTHER_CONTACT_DELAY = 0.3 -- other players: roughly when the batter's bat meets the ball

local FROZEN_PARTICLE_SPEED = 0.025
local FREEZE_GRADE = {Saturation = -0.8, Contrast = 0.3, Brightness = -0.04, TintColor = Color3.fromRGB(205, 220, 255)}
local CHARGE_GRADE = {Saturation = 0.2, Contrast = 0.15, Brightness = 0.02, TintColor = Color3.fromRGB(255, 236, 196)}
local NEUTRAL_GRADE = {Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1)}

-- Camera shots. Angles go round the ball: 0 is behind it (looking downfield).
local ORBIT_RADIUS, ORBIT_HEIGHT, ORBIT_TURN, ORBIT_FOV = 7, 1.3, math.rad(200), 50
local CHARGE_START_RADIUS, CHARGE_START_HEIGHT, CHARGE_START_FOV = 10, 2.6, 46
local CHARGE_RADIUS, CHARGE_HEIGHT, CHARGE_FOV = 5.5, 1, 38
local CHARGE_SIDE_ANGLE = math.rad(22) -- the charge shot sits a little to the side away from the batter
local LAUNCH_FOV, CHASE_FOV = 88, 72
local BAR_HEIGHT = 0.15

local function start(world, area, ball, mine)
 local stem = area.Tee.Stem
 local rest = FX.RestPosition(area, ball)
 local difference = area.HitDirection.Position - rest
 local forward = Vector3.new(difference.X, 0, difference.Z).Unit
 local back, right = -forward, forward:Cross(Vector3.yAxis)
 local center = rest + Vector3.yAxis * 0.3
 local pad = area:FindFirstChild("BatterPosition")
 local sideSign = pad and (pad.Position - center):Dot(right) < 0 and -1 or 1
 local now = os.clock()

 local c = {ball = ball, rest = rest, center = center, forward = forward, back = back, right = right,
  startedAt = now, objects = {}, direction = forward,
  side = -sideSign, -- orbit and chase on the side away from the batter, never through them
  nextBolt = now + 0.2}
 -- When the ball is expected to visibly leave the tee, relative to startedAt: for the batter,
 -- normal contact plus the hold (the launch is timed to their swing); otherwise server time.
 if mine and FX.Swing.startedAt then
  c.launchT = FX.Swing.startedAt + Swing.ContactTime + Swing.LegendaryHit.HoldSeconds - now
 else
  c.launchT = (ball:GetAttribute("LegendaryLaunchAt") or 0) - workspace:GetServerTimeNow() + FX.RenderLag
 end
 c.launchT = math.max(CHARGE_SECONDS, c.launchT)
 local function keep(object) table.insert(c.objects, object) return object end

 -- World effects, for everyone.
 c.core = keep(FX.Part("LegendaryCore", CFrame.new(center)))
 c.gather = keep(FX.Part("LegendaryGather", CFrame.new(center), Vector3.one * 18))
 c.energy = FX.Emitter(c.gather, {Texture = FX.Textures.Sparkle, Shape = Enum.ParticleEmitterShape.Sphere,
  ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
  Speed = NumberRange.new(14), Lifetime = NumberRange.new(0.6), Rate = 40,
  Color = ColorSequence.new(GOLD_LIGHT, GOLD), Size = NumberSequence.new(0.7, 0.1), Transparency = NumberSequence.new(0.1, 0.6)})
 -- Debris and a shockwave from the contact, left hanging in the frozen air.
 c.frozen = {
  FX.Emitter(c.core, {Texture = FX.Textures.Spark, Enabled = false, Speed = NumberRange.new(25, 55), SpreadAngle = Vector2.new(180, 180),
   Drag = 1.2, Lifetime = NumberRange.new(5, 6), Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD),
   Size = NumberSequence.new(0.45, 0.1), Rotation = NumberRange.new(0, 360)}),
  FX.Emitter(c.core, {Texture = FX.Textures.Smoke, Enabled = false, Speed = NumberRange.new(8, 18), SpreadAngle = Vector2.new(70, 180),
   Drag = 2, Lifetime = NumberRange.new(4, 5), Color = ColorSequence.new(Color3.fromRGB(215, 190, 150)), LightEmission = 0,
   Size = NumberSequence.new(0.6, 2.2), Transparency = NumberSequence.new(0.35, 1), Rotation = NumberRange.new(0, 360)}),
  -- A ring facing downfield, like the air rippling off the bat.
  FX.Emitter(keep(FX.Part("FrozenWave", CFrame.lookAt(center, center + forward))), {Texture = FX.Textures.Shockwave,
   Enabled = false, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
   EmissionDirection = Enum.NormalId.Front, Speed = NumberRange.new(0.01), Lifetime = NumberRange.new(1.2),
   Color = ColorSequence.new(GOLD_LIGHT), Size = NumberSequence.new(0.5, 30), Transparency = NumberSequence.new(0, 1)}),
 }
 c.frozen[1]:Emit(70)
 c.frozen[2]:Emit(25)
 c.frozen[3]:Emit(1)
 task.delay(0.07, function()
  for _, emitter in c.frozen do if emitter.Parent and not c.left then emitter.TimeScale = FROZEN_PARTICLE_SPEED end end
 end)
 -- An energy shell around the ball, with a light.
 c.shell = keep(FX.Part("LegendaryShell", CFrame.new(rest), Vector3.one * 1.6))
 c.shell.Shape, c.shell.Material, c.shell.Color, c.shell.Transparency = Enum.PartType.Ball, Enum.Material.ForceField, GOLD, 0
 c.light = Instance.new("PointLight")
 c.light.Color, c.light.Brightness, c.light.Range = GOLD_LIGHT, 3, 14
 c.light.Parent = c.core
 -- Three ribbons of energy orbiting the ball.
 c.orbiters = {}
 for i, color in {GOLD, Color3.new(1, 1, 1), ELECTRIC} do
  local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
  a0.Parent, a1.Parent = c.core, c.core
  local trail = Instance.new("Trail")
  trail.Attachment0, trail.Attachment1, trail.FaceCamera = a0, a1, true
  trail.Lifetime, trail.LightEmission, trail.LightInfluence = 0.35, 1, 0
  trail.Color, trail.Transparency = ColorSequence.new(color), NumberSequence.new(0, 1)
  trail.WidthScale = NumberSequence.new(1, 0)
  trail.Parent = c.core
  table.insert(c.orbiters, {a0 = a0, a1 = a1, tilt = CFrame.Angles(rng:NextNumber(0, math.pi), 0, i * math.pi / 3), speed = 7 + i * 2})
 end
 -- A glow on the ground under the tee.
 c.groundY = stem.Position.Y - stem.Size.Y / 2 + 0.05
 c.groundGlow = keep(FX.Neon("GroundGlow", CFrame.new(rest.X, c.groundY, rest.Z) * FX.FLAT, Vector3.new(0.1, 2, 2),
  GOLD, 0.6, Enum.PartType.Cylinder))

 FX.PlayFor(c, SOUNDS.ContactBoom, mine and SoundService or c.core)
 if mine then
  FX.PlayFor(c, SOUNDS.Crack, SoundService)
  c.heartbeat = FX.PlayFor(c, SOUNDS.Heartbeat, SoundService, {Looped = true})
  local riser = FX.PlayFor(c, SOUNDS.Riser, SoundService)
  -- End the riser's hard stop on the launch.
  local function align()
   if riser.TimeLength > 0 then riser.TimePosition = math.max(0, riser.TimeLength - c.launchT) end
  end
  if riser.IsLoaded then align() else riser.Loaded:Once(align) end

  -- Freeze the swing exactly at contact, take the camera, and drain the colour.
  c.tool = FX.BatterTool() -- remembered: it may be unequipped (in the Backpack) by cleanup time
  FX.SetSwingClock(c.tool, Swing.BallContactTime)
  Player:SetAttribute("CinematicCamera", true)
  local camera = workspace.CurrentCamera
  c.startCFrame, c.startFov = camera.CFrame, camera.FieldOfView
  local offset = c.startCFrame.Position - center
  local flat = Vector3.new(offset.X, 0, offset.Z)
  c.startRadius, c.startHeight = flat.Magnitude, offset.Y
  c.startAngle = math.atan2(flat:Dot(right), flat:Dot(back))
  c.startLook = c.startCFrame.Position + c.startCFrame.LookVector * offset.Magnitude
  c.grade = keep(Instance.new("ColorCorrectionEffect"))
  c.grade.Name, c.grade.Parent = "LegendaryHitGrade", Lighting
  FX.Tween(c.grade, 0.15, FREEZE_GRADE)
  c.blur = keep(Instance.new("BlurEffect"))
  c.blur.Name, c.blur.Size, c.blur.Parent = "LegendaryHitBlur", 18, Lighting
  FX.Tween(c.blur, 0.5, {Size = 0})
  FX.ShowScreen(THEME)
  FX.Flash(Color3.new(1, 1, 1), 0, 0.6)
  FX.SetBars(BAR_HEIGHT, 0.3)
 else
  FX.Announce("⭐ " .. FX.DisplayNameOf(ball:GetAttribute("LegendaryHitUserId")) .. " hit a LEGENDARY HIT! ⭐",
   GOLD_LIGHT, Color3.fromRGB(70, 32, 0))
 end
 return c
end

local function orbiterUpdate(c, t, radius)
 c.core.CFrame = CFrame.new(c.left and c.ballPosition or c.rest)
 for _, orbiter in c.orbiters do
  local spin = orbiter.tilt * CFrame.Angles(0, t * orbiter.speed, 0)
  local point, normal = spin.LookVector * radius, spin.UpVector * 0.12
  orbiter.a0.Position, orbiter.a1.Position = point + normal, point - normal
 end
end

-- Start of the charge: a pillar of light, the colour turns gold, the riser builds.
local function beginCharge(c)
 c.charging = true
 local base = Vector3.new(c.rest.X, c.groundY, c.rest.Z)
 c.pillar = FX.Neon("LightPillar", CFrame.new(base + Vector3.yAxis * 300) * FX.FLAT,
  Vector3.new(600, 0.1, 0.1), GOLD, 0.65, Enum.PartType.Cylinder)
 c.pillarCore = FX.Neon("LightPillarCore", c.pillar.CFrame, Vector3.new(600, 0.05, 0.05), Color3.new(1, 1, 1), 0.45, Enum.PartType.Cylinder)
 table.insert(c.objects, c.pillar)
 table.insert(c.objects, c.pillarCore)
 FX.Tween(c.pillar, CHARGE_SECONDS, {Size = Vector3.new(600, 1.2, 1.2)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
 FX.Tween(c.pillarCore, CHARGE_SECONDS, {Size = Vector3.new(600, 0.35, 0.35)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
 FX.Tween(c.groundGlow, CHARGE_SECONDS, {Size = Vector3.new(0.1, 16, 16), Transparency = 0.45})
 FX.Tween(c.shell, CHARGE_SECONDS, {Size = Vector3.one * 3.2})
 FX.Tween(c.light, CHARGE_SECONDS, {Brightness = 6, Range = 24})
 if c.mine then
  FX.Flash(Color3.new(1, 1, 1), 0.25, 0.35) -- covers the camera cut
  FX.Tween(c.grade, CHARGE_SECONDS, CHARGE_GRADE, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
  if c.heartbeat then FX.Tween(c.heartbeat, 0.6, {Volume = 0}) end
 end
end

local function showTitle(c)
 c.titleShown = true
 if not c.mine then return end
 FX.PlayFor(c, SOUNDS.Sting, SoundService)
 FX.ShowTitle()
 FX.Flash(Color3.new(1, 1, 1), 0.55, 0.3)
end

-- The ball leaves the tee: release time and blow everything outward.
local function onLaunch(c)
 c.left, c.leftAt = true, os.clock()
 c.ballPosition = c.ball.Position
 local base = Vector3.new(c.rest.X, c.groundY + 0.1, c.rest.Z)
 for _, emitter in c.frozen do emitter.TimeScale = 1 end
 for i, size in {70, 110, 160} do
  task.delay((i - 1) * 0.08, FX.Shockwave, base, i == 2 and Color3.new(1, 1, 1) or GOLD, 2, size, 0.7 + i * 0.15)
 end
 BallEffects.Burst("Supernova", c.rest)
 BallEffects.Burst("Zap", c.rest)
 for _ = 1, 6 do
  local sky = c.rest + Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(120, 180), rng:NextNumber(-25, 25))
  FX.Bolt(sky, c.rest, rng:NextNumber() < 0.5 and GOLD_LIGHT or ELECTRIC, 0.5, 0.4)
 end
 local blast = FX.Neon("LaunchBlast", CFrame.new(c.rest), Vector3.one * 2, GOLD_LIGHT, 0, Enum.PartType.Ball)
 FX.Tween(blast, 0.45, {Size = Vector3.one * 34, Transparency = 1})
 Debris:AddItem(blast, 0.5)
 if c.pillar then
  FX.Tween(c.pillar, 0.7, {Size = Vector3.new(600, 12, 12), Transparency = 1})
  FX.Tween(c.pillarCore, 0.5, {Size = Vector3.new(600, 4, 4), Transparency = 1})
 end
 FX.Tween(c.groundGlow, 0.8, {Size = Vector3.new(0.1, 40, 40), Transparency = 1})
 FX.Tween(c.shell, 0.3, {Size = Vector3.one * 12, Transparency = 1})
 c.energy.Enabled = false
 FX.PlayFor(c, SOUNDS.LaunchBoom, c.mine and SoundService or c.core)

 -- A comet tail that rides with the ball for the rest of its flight.
 local rainbow = {}
 for i = 0, 6 do table.insert(rainbow, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 * 0.85, 0.85, 1))) end
 c.comet = FX.Comet(c.ballPosition, {
  {2.6, {Lifetime = 0.7, LightEmission = 1, Brightness = 2, Color = ColorSequence.new(GOLD_LIGHT, GOLD),
   Transparency = NumberSequence.new(0.1, 1), WidthScale = NumberSequence.new(1, 0.15)}},
  {4.5, {Lifetime = 1.1, LightEmission = 1, Brightness = 1.5, Color = ColorSequence.new(rainbow),
   Texture = FX.Textures.Sparkle, TextureMode = Enum.TextureMode.Wrap, TextureLength = 3,
   Transparency = NumberSequence.new(0.3, 1), WidthScale = NumberSequence.new(0.6, 1.4)}},
 }, {
  {Texture = FX.Textures.Sparkle, Rate = 90, Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(180, 180),
   Lifetime = NumberRange.new(0.5, 0.9), Color = ColorSequence.new(GOLD_LIGHT, GOLD), Size = NumberSequence.new(0.9, 0),
   Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200)},
 }, {GOLD_LIGHT, 6, 24})
 table.insert(c.objects, c.comet)
 if not c.mine then return end

 FX.PlayFor(c, SOUNDS.Crowd, SoundService)
 FX.ReleaseSwing(c.tool) -- the swing follows through at full speed
 FX.Flash(Color3.new(1, 1, 1), 0, 0.5)
 c.grade.Brightness = 0.45
 FX.Tween(c.grade, 0.6, CHARGE_GRADE)
 c.blur.Size = 20
 FX.Tween(c.blur, 0.45, {Size = 0})
 local camera = workspace.CurrentCamera
 c.chaseFrom, c.launchFov = camera.CFrame.Position - c.rest, camera.FieldOfView
end

-- Hand the camera and the swing back (the normal flight camera blends in from here).
local function release(c)
 if c.released then return end
 c.released = true
 if not c.mine then return end
 Player:SetAttribute("CinematicCamera", nil)
 FX.ReleaseSwing(c.tool or FX.BatterTool())
 FX.SpeedLines(nil)
 FX.SetBars(0, 0.6)
 if not c.titleHidden then
  c.titleHidden = true
  FX.HideTitle()
 end
 if c.grade then FX.Tween(c.grade, 1, NEUTRAL_GRADE) end
end

local function cameraUpdate(c, t)
 local camera = workspace.CurrentCamera
 local orbitStart, orbitEnd = IMPACT_SECONDS, math.max(IMPACT_SECONDS + 0.5, c.launchT - CHARGE_SECONDS)
 local function around(angle, radius, height)
  return c.center + (c.back * math.cos(angle) + c.right * math.sin(angle)) * radius + Vector3.yAxis * height
 end
 if c.left then
  FX.ChaseCamera(c, os.clock() - c.leftAt, CHASE_SECONDS, LAUNCH_FOV, CHASE_FOV)
  return
 end
 if t < orbitStart then
  -- Freeze frame: hold the batting view with a small punch in.
  camera.FieldOfView = lerp(c.startFov, c.startFov - 6, easeOut(t / orbitStart))
  camera.CFrame = c.startCFrame * FX.shakeAngles(0.01 * (1 - t / orbitStart), t)
  return
 end
 local position, lookAt, fov, shake
 if t < orbitEnd then
  local u = clamp01((t - orbitStart) / (orbitEnd - orbitStart))
  local settle = easeOut(u * 2.5)
  local height = lerp(c.startHeight, ORBIT_HEIGHT, settle) + math.sin(u * math.pi) * 1.2
  position = around(c.startAngle + c.side * ORBIT_TURN * smooth(u), lerp(c.startRadius, ORBIT_RADIUS, settle), height)
  lookAt = c.startLook:Lerp(c.center, settle)
  fov = lerp(c.startFov - 6, ORBIT_FOV, settle)
  shake = 0.003
 else
  -- Charge: a hard cut (under the charge flash) to behind the ball, a little to the side away
  -- from the batter, pushing in low while looking downfield.
  local v = clamp01((t - orbitEnd) / CHARGE_SECONDS)
  local e = easeOut(v)
  position = around(c.side * CHARGE_SIDE_ANGLE, lerp(CHARGE_START_RADIUS, CHARGE_RADIUS, e), lerp(CHARGE_START_HEIGHT, CHARGE_HEIGHT, e))
  lookAt = (c.center + c.forward * 12):Lerp(c.center + c.forward * 30, e)
  fov = lerp(CHARGE_START_FOV, CHARGE_FOV, e)
  shake = 0.004 + 0.018 * v + (t > c.launchT and 0.01 or 0)
 end
 camera.FieldOfView = fov
 camera.CFrame = CFrame.lookAt(position, lookAt) * FX.shakeAngles(shake, t)
end

local function update(c, dt)
 local now = os.clock()
 local t = now - c.startedAt
 if not c.left and FX.HasLeftTee(c) then onLaunch(c) end
 if c.left then
  FX.TrackBall(c, c.ball, dt)
  if c.comet and c.ball:GetAttribute("BallState") == "InFlight" then c.comet.CFrame = CFrame.new(c.ballPosition) end
 end
 if not c.charging and t >= c.launchT - CHARGE_SECONDS then beginCharge(c) end
 if not c.titleShown and t >= c.launchT - TITLE_LEAD then showTitle(c) end
 if c.mine and c.titleShown and not c.titleHidden and c.left and now - c.leftAt >= TITLE_HOLD then
  c.titleHidden = true
  FX.HideTitle()
 end

 -- Energy and lightning build until the launch.
 if not c.left then
  local build = clamp01(t / c.launchT)
  c.energy.Rate = lerp(40, 220, build)
  if not c.charging then c.light.Brightness = 3 + math.sin(t * 9) * 1.5 end
  c.shell.Transparency = 0.15 + math.sin(t * 12) * 0.1
  if now >= c.nextBolt then
   local to = c.center + (rng:NextUnitVector() + Vector3.yAxis * 0.4).Unit * rng:NextNumber(3, 7) * (1 + build)
   FX.Bolt(c.center, to, rng:NextNumber() < 0.6 and GOLD_LIGHT or ELECTRIC, 0.12 + 0.12 * build, 0.16)
   c.nextBolt = now + (c.charging and rng:NextNumber(0.04, 0.12) or rng:NextNumber(0.15, 0.4))
  end
 end
 orbiterUpdate(c, t, c.left and 2.4 or lerp(1.4, 2.4, clamp01(t / c.launchT)))
 -- The audio fades out as the chase ends, so it finishes with the pictures.
 local chaseLeft = c.left and FX.ChaseTimeLeft(c, CHASE_SECONDS)
 if chaseLeft and not c.soundsFading and chaseLeft <= SOUND_FADE_SECONDS then
  c.soundsFading = true
  FX.FadeSounds(c, math.max(0.3, chaseLeft))
 end

 if c.mine and not c.released then
  if chaseLeft and chaseLeft <= 0 then
   release(c)
  else
   cameraUpdate(c, t)
   FX.SpeedLines(c.left and 1 - clamp01((now - c.leftAt) / CHASE_SECONDS) or nil)
  end
 end
end

local function stop(c)
 release(c)
 FX.FadeSounds(c, STOP_FADE_SECONDS) -- a short hit can end before the cinematic does
 for _, object in c.objects or {} do
  if object:IsA("ColorCorrectionEffect") then
   FX.Tween(object, 0.6, NEUTRAL_GRADE)
   Debris:AddItem(object, 0.7)
  elseif object == c.comet then
   FX.FadeOut(object)
  else
   Debris:AddItem(object, 0)
  end
 end
 if c.mine then FX.HideScreen() end
end

FX.Preload(SOUNDS)
FX.WatchStations("Legendary", {
 ready = function(info)
  if not info.mine then return info.waited >= OTHER_CONTACT_DELAY end
  -- Stop the swing exactly where the bat meets the ball (BatClient fires "Hold" there).
  local tool = FX.BatterTool()
  if tool and not tool:GetAttribute("SwingClockOverride") then tool:SetAttribute("SwingHoldAt", Swing.BallContactTime) end
  return FX.Swing.held or info.waited >= CONTACT_WAIT_LIMIT
 end,
 start = start,
 update = update,
 stop = stop,
 release = release,
})
