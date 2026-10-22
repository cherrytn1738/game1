-- Mythic Hit: the rarest cinematic hit (Swing.MythicHit.Chance, 1 in 10,000), about 9 seconds.
-- The server rolls it and holds the launch while this plays:
--   power-up   the batter freezes at the top of the backswing and powers up: the world darkens,
--              a red aura of flames and black smoke, red lightning, rocks lifting off the
--              ground, pulses of red light, a growl and a dark drone
--   3 swings   the swing hits the ball three times, each from a different camera angle (over
--              the shoulder, facing the batter, close on the ball), each impact bigger
--   launch     the real launch: a red explosion, lightning from the sky, the rocks blast away,
--              a roar; then the camera chases the ball's red and black comet tail
-- Everyone sees the world effects and gets an announcement; only the batter gets the camera,
-- the title and the screen effects. Presentation only: launch, distance and rewards are the
-- same as any other hit.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Swing = require(ReplicatedStorage:WaitForChild("SwingConfig"))
local FX = require(script.Parent:WaitForChild("CinematicFX"))
local Player = Players.LocalPlayer
local lerp, clamp01, easeOut, smooth, rng = FX.lerp, FX.clamp01, FX.easeOut, FX.smooth, FX.rng

-- Roblox-licensed audio (Pro Sound Effects and APM Music libraries), pitched down for a
-- sinister feel: {id, volume, playbackSpeed, startAt}. startAt skips a quiet lead-in (measured
-- with PlaybackLoudness) so the impact sounds land exactly on each contact.
-- Volumes are balanced so the stacked moments stay under clipping (measured: the third impact
-- over the bed and the launch trio), with the big low end saved for the impacts and launch.
local SOUNDS = {
 Growl = {"rbxassetid://9113980512", 0.7, 0.7}, -- creature roar and growl, slowed down
 Drone = {"rbxassetid://9039933377", 0.75, 1}, -- "Arise From The Dead" airy drone
 Swell = {"rbxassetid://9039691266", 0.5, 1}, -- "Ice Wave": shivering strings, ominous brass
 Heartbeat = {"rbxassetid://9043365842", 0.8, 0.8},
 Impact = {"rbxassetid://9043367738", 0.85, 0.85, 0.09}, -- distorted kick (hits 0.10 s in)
 ImpactBoom = {"rbxassetid://9125484526", 0.65, 0.7},
 Crack = {"rbxassetid://9125380872", 0.8, 0.8, 0.58}, -- bat crack (the crack is 0.61 s in)
 LaunchBoom = {"rbxassetid://9125484511", 0.85, 0.7},
 Roar = {"rbxassetid://9113980319", 0.7, 0.65},
 Braam = {"rbxassetid://9039689949", 0.7, 1}, -- "Wounded Symphony": deep haunting brass
}
-- The three impacts build: each plays at this share of full volume, and only the third adds
-- the deep boom (two booming low ends on every hit turned to mud).
local IMPACT_LEVELS = {0.6, 0.78, 0.85}
-- At each impact the bed (growl, drone, swell, heartbeat) ducks to this share for a moment, so
-- the hit punches through instead of piling on top of it.
local BED_DIP, BED_DIP_HOLD, BED_DIP_RETURN = 0.35, 0.15, 0.5

local RED = Color3.fromRGB(255, 30, 30)
local BLOOD = Color3.fromRGB(150, 0, 0)
local EMBER = Color3.fromRGB(255, 110, 60)
local SMOKE = Color3.fromRGB(25, 0, 0)
local THEME = {
 edge = RED, title = "MYTHIC HIT!", subtitle = "1 IN 10,000", stroke = Color3.fromRGB(10, 0, 0),
 subtitleColor = Color3.fromRGB(255, 120, 120), speedLineColor = Color3.fromRGB(255, 80, 80),
 titleColors = ColorSequence.new({
  ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 0, 0)), ColorSequenceKeypoint.new(0.42, Color3.fromRGB(255, 30, 30)),
  ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 200)), ColorSequenceKeypoint.new(0.58, Color3.fromRGB(255, 30, 30)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 0, 0))}),
}

-- The swing: held at the top of the backswing (end of Windup) for the power-up, then each of
-- the three swings plays from there to contact in slow motion.
local WINDUP_END = 0
for _, phase in Swing.Phases do
 WINDUP_END += phase.duration
 if phase.name == "Windup" then break end
end
local REPLAY_RATE = 0.4 -- swing speed during the three swings
local SWING_IN = (Swing.BallContactTime - WINDUP_END) / REPLAY_RATE -- seconds from windup to contact
local REPLAY_GAP = 1.05 -- seconds between the three contacts; the third is the launch
local LAUNCH_MARGIN = 0.1 -- the third contact lands this much before the ball is expected to move
local MIN_POWER_SECONDS = 0.3
local CHASE_SECONDS = 3.2
local SOUND_FADE_SECONDS = 1 -- the audio fades out over the end of the chase
local STOP_FADE_SECONDS = 0.4 -- or this fast if the hit ends first
local TITLE_HOLD = 2.4 -- the title leaves this long after the launch
local START_WAIT_LIMIT = 0.6 -- batter: start anyway if the swing never reports reaching the windup

local DARK_GRADE = {Saturation = -0.35, Contrast = 0.4, Brightness = -0.2, TintColor = Color3.fromRGB(255, 140, 140)}
local NEUTRAL_GRADE = {Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1)}
local LAUNCH_FOV, CHASE_FOV = 90, 72
local ROCK_COUNT = 14

local function start(world, area, ball, mine)
 local rest = FX.RestPosition(area, ball)
 local stem = area.Tee.Stem
 local difference = area.HitDirection.Position - rest
 local forward = Vector3.new(difference.X, 0, difference.Z).Unit
 local userId = ball:GetAttribute("MythicHitUserId")
 local batter = Players:GetPlayerByUserId(userId)
 local character = batter and batter.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local pad = area:FindFirstChild("BatterPosition")
 local rootPosition = root and root.Position or (pad and pad.Position + Vector3.yAxis * 3) or rest
 local toBall = Vector3.new(rest.X - rootPosition.X, 0, rest.Z - rootPosition.Z)
 local facing = toBall.Magnitude > 0.1 and toBall.Unit or forward:Cross(Vector3.yAxis)
 local now = os.clock()

 local c = {ball = ball, rest = rest, forward = forward, facing = facing, root = root, rootPosition = rootPosition,
  startedAt = now, objects = {}, impacts = {}, direction = forward, nextBolt = now + 0.3, nextPulse = now + 0.2,
  side = (rest - rootPosition):Dot(forward:Cross(Vector3.yAxis)) > 0 and 1 or -1}
 -- When the ball is expected to visibly leave the tee (the third contact), relative to startedAt.
 if mine and FX.Swing.startedAt then
  c.launchT = FX.Swing.startedAt + Swing.ContactTime + Swing.MythicHit.HoldSeconds - now
 else
  c.launchT = (ball:GetAttribute("MythicLaunchAt") or 0) - workspace:GetServerTimeNow() + FX.RenderLag
 end
 c.launchT = math.max(MIN_POWER_SECONDS + SWING_IN + 2 * REPLAY_GAP + LAUNCH_MARGIN, c.launchT)
 c.contactT, c.swingT = {}, {}
 for k = 1, 3 do
  c.contactT[k] = c.launchT - LAUNCH_MARGIN - (3 - k) * REPLAY_GAP
  c.swingT[k] = c.contactT[k] - SWING_IN
 end
 local function keep(object) table.insert(c.objects, object) return object end
 c.groundY = stem.Position.Y - stem.Size.Y / 2 + 0.05

 -- The batter glows red, wrapped in flames, smoke and sparks.
 if character then
  c.highlight = keep(Instance.new("Highlight"))
  c.highlight.Adornee, c.highlight.DepthMode = character, Enum.HighlightDepthMode.Occluded
  c.highlight.FillColor, c.highlight.OutlineColor = BLOOD, RED
  c.highlight.FillTransparency, c.highlight.OutlineTransparency = 1, 1
  c.highlight.Parent = FX.Container
  FX.Tween(c.highlight, 1.2, {FillTransparency = 0.6, OutlineTransparency = 0})
 end
 c.aura = keep(FX.Part("MythicAura", CFrame.new(rootPosition), Vector3.new(4.5, 6, 4.5)))
 c.auraEmitters = {
  FX.Emitter(c.aura, {Texture = FX.Textures.Fire, EmissionDirection = Enum.NormalId.Top, Rate = 70,
   Speed = NumberRange.new(2, 5), Acceleration = Vector3.new(0, 7, 0), Lifetime = NumberRange.new(0.6, 1),
   Color = ColorSequence.new(EMBER, BLOOD), Size = NumberSequence.new(1.3, 0), Transparency = NumberSequence.new(0.2, 1),
   Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90)}),
  FX.Emitter(c.aura, {Texture = FX.Textures.Smoke, EmissionDirection = Enum.NormalId.Top, Rate = 22, LightEmission = 0,
   Speed = NumberRange.new(1.5, 4), Acceleration = Vector3.new(0, 3, 0), Lifetime = NumberRange.new(1.2, 1.8),
   Color = ColorSequence.new(SMOKE), Size = NumberSequence.new(1.2, 3.5), Transparency = NumberSequence.new(0.35, 1),
   Rotation = NumberRange.new(0, 360)}),
  FX.Emitter(c.aura, {Texture = FX.Textures.Spark, EmissionDirection = Enum.NormalId.Top, Rate = 35,
   Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(25, 25), Lifetime = NumberRange.new(0.6, 1.1),
   Color = ColorSequence.new(RED), Size = NumberSequence.new(0.3, 0)}),
 }
 -- Red energy streaming into the batter.
 c.gather = keep(FX.Part("MythicGather", CFrame.new(rootPosition + Vector3.yAxis), Vector3.one * 20))
 c.energy = FX.Emitter(c.gather, {Texture = FX.Textures.Sparkle, Shape = Enum.ParticleEmitterShape.Sphere,
  ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
  Speed = NumberRange.new(16), Lifetime = NumberRange.new(0.6), Rate = 30,
  Color = ColorSequence.new(RED, BLOOD), Size = NumberSequence.new(0.8, 0.1), Transparency = NumberSequence.new(0.1, 0.5)})
 c.light = Instance.new("PointLight")
 c.light.Color, c.light.Brightness, c.light.Range = RED, 2, 16
 c.light.Parent = c.aura
 -- A dark red glow spreading on the ground, and rocks lifting into the air.
 local feet = Vector3.new(rootPosition.X, c.groundY, rootPosition.Z)
 c.feet = feet
 c.groundGlow = keep(FX.Neon("MythicGround", CFrame.new(feet) * FX.FLAT, Vector3.new(0.1, 3, 3), BLOOD, 0.55, Enum.PartType.Cylinder))
 FX.Tween(c.groundGlow, 2.5, {Size = Vector3.new(0.1, 16, 16)})
 c.rocks = {}
 for i = 1, ROCK_COUNT do
  local angle = (i / ROCK_COUNT) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
  local radius = rng:NextNumber(3, 8)
  local size = rng:NextNumber(0.35, 1.1)
  local base = feet + Vector3.new(math.cos(angle) * radius, size / 2, math.sin(angle) * radius)
  local rock = keep(FX.Part("MythicRock", CFrame.new(base), Vector3.new(size, size * rng:NextNumber(0.6, 1), size)))
  rock.Transparency, rock.Material, rock.Color = 0, Enum.Material.Basalt, Color3.fromRGB(40, 32, 30)
  table.insert(c.rocks, {part = rock, base = base, rise = rng:NextNumber(1.5, 6), spin = rng:NextUnitVector() * rng:NextNumber(0.5, 2),
   phase = rng:NextNumber(0, math.pi * 2)})
 end

 local soundParent = mine and SoundService or c.aura
 c.growl = FX.PlayFor(c, SOUNDS.Growl, soundParent)
 c.drone = FX.PlayFor(c, SOUNDS.Drone, soundParent)
 c.swell = FX.PlayFor(c, SOUNDS.Swell, soundParent)
 if mine then
  c.heartbeat = FX.PlayFor(c, SOUNDS.Heartbeat, SoundService, {Looped = true})
  -- Hold the swing at the top of the backswing, take the camera, darken the world.
  c.tool = FX.BatterTool()
  FX.SetSwingClock(c.tool, WINDUP_END)
  Player:SetAttribute("CinematicCamera", true)
  c.grade = keep(Instance.new("ColorCorrectionEffect"))
  c.grade.Name, c.grade.Parent = "MythicHitGrade", Lighting
  FX.Tween(c.grade, 1.5, DARK_GRADE)
  c.blur = keep(Instance.new("BlurEffect"))
  c.blur.Name, c.blur.Size, c.blur.Parent = "MythicHitBlur", 0, Lighting
  FX.ShowScreen(THEME)
  FX.Flash(BLOOD, 0.3, 0.8)
  FX.SetBars(0.13, 0.6)
 else
  FX.Announce("☠ " .. FX.DisplayNameOf(userId) .. " hit a MYTHIC HIT! ☠", Color3.fromRGB(255, 90, 90), Color3.fromRGB(20, 0, 0))
 end
 return c
end

-- Each of the three swings meeting the ball; k = 1..3, each bigger than the last.
local function impact(c, k)
 c.impacts[k] = true
 local base = Vector3.new(c.rest.X, c.groundY + 0.1, c.rest.Z)
 FX.Shockwave(base, k == 3 and RED or BLOOD, 2, 25 + 20 * k, 0.6)
 for _ = 1, 3 * k do
  FX.Bolt(c.rest, c.rest + (rng:NextUnitVector() + Vector3.yAxis * 0.3).Unit * rng:NextNumber(4, 6 + 3 * k), RED, 0.12 + 0.05 * k, 0.2)
 end
 local puff = FX.Part("MythicImpact", CFrame.new(c.rest))
 local smoke = FX.Emitter(puff, {Texture = FX.Textures.Smoke, Enabled = false, LightEmission = 0, Speed = NumberRange.new(6, 14),
  SpreadAngle = Vector2.new(180, 180), Drag = 3, Lifetime = NumberRange.new(0.8, 1.3), Color = ColorSequence.new(SMOKE),
  Size = NumberSequence.new(1, 3), Transparency = NumberSequence.new(0.3, 1)})
 smoke:Emit(8 * k)
 Debris:AddItem(puff, 1.5)
 local soundParent = c.mine and SoundService or c.aura
 local level = IMPACT_LEVELS[k] or 1
 FX.PlayFor(c, SOUNDS.Impact, soundParent, {Volume = SOUNDS.Impact[2] * level})
 if k == 3 then FX.PlayFor(c, SOUNDS.ImpactBoom, soundParent, {PlaybackSpeed = SOUNDS.ImpactBoom[3] + 0.15}) end
 FX.PlayFor(c, SOUNDS.Crack, soundParent, {Volume = SOUNDS.Crack[2] * level})
 for _, entry in {{c.growl, SOUNDS.Growl}, {c.drone, SOUNDS.Drone}, {c.swell, SOUNDS.Swell}, {k < 3 and c.heartbeat, SOUNDS.Heartbeat}} do
  local bed, spec = entry[1], entry[2]
  if bed and bed.Parent then
   FX.Tween(bed, 0.04, {Volume = spec[2] * BED_DIP})
   task.delay(BED_DIP_HOLD, function()
    if bed.Parent and not c.left and not c.stopped then FX.Tween(bed, BED_DIP_RETURN, {Volume = spec[2]}) end
   end)
  end
 end
 if not c.mine then return end
 -- An "impact frame": a black flash snapping to red, the bars closing in a little more each hit.
 FX.Flash(Color3.new(0, 0, 0), 0, 0.08)
 task.delay(0.06, FX.Flash, RED, 0.35 - 0.08 * k, 0.45)
 FX.SetBars(0.13 + 0.015 * k, 0.15)
 c.blur.Size = 10 + 4 * k
 FX.Tween(c.blur, 0.35, {Size = 0})
 c.shakeUntil, c.shakeAmount = os.clock() + 0.35, 0.02 + 0.01 * k
 if k == 3 then
  FX.ShowTitle()
  if c.heartbeat then FX.Tween(c.heartbeat, 0.1, {Volume = 0}) end
 end
end

-- The ball leaves the tee: the explosion, then the chase.
local function onLaunch(c)
 c.left, c.leftAt = true, os.clock()
 c.ballPosition = c.ball.Position
 local base = Vector3.new(c.rest.X, c.groundY + 0.1, c.rest.Z)
 for i, size in {80, 120, 170} do
  task.delay((i - 1) * 0.08, FX.Shockwave, base, i == 2 and Color3.fromRGB(60, 0, 0) or RED, 2, size, 0.7 + i * 0.15)
 end
 for _ = 1, 8 do
  local sky = c.rest + Vector3.new(rng:NextNumber(-30, 30), rng:NextNumber(120, 180), rng:NextNumber(-30, 30))
  FX.Bolt(sky, c.rest, rng:NextNumber() < 0.6 and RED or Color3.fromRGB(255, 160, 160), 0.55, 0.45)
 end
 local blast = FX.Neon("MythicBlast", CFrame.new(c.rest), Vector3.one * 2, RED, 0, Enum.PartType.Ball)
 FX.Tween(blast, 0.5, {Size = Vector3.one * 40, Transparency = 1})
 Debris:AddItem(blast, 0.55)
 local column = FX.Neon("MythicColumn", CFrame.new(base + Vector3.yAxis * 300) * FX.FLAT, Vector3.new(600, 5, 5), RED, 0.3, Enum.PartType.Cylinder)
 FX.Tween(column, 0.8, {Size = Vector3.new(600, 0.5, 0.5), Transparency = 1})
 Debris:AddItem(column, 0.85)
 local burst = FX.Part("MythicSmokeBurst", CFrame.new(c.rest))
 local smoke = FX.Emitter(burst, {Texture = FX.Textures.Smoke, Enabled = false, LightEmission = 0, Speed = NumberRange.new(15, 35),
  SpreadAngle = Vector2.new(180, 180), Drag = 2.5, Lifetime = NumberRange.new(1.2, 2), Color = ColorSequence.new(SMOKE),
  Size = NumberSequence.new(2, 7), Transparency = NumberSequence.new(0.2, 1), Rotation = NumberRange.new(0, 360)})
 smoke:Emit(45)
 Debris:AddItem(burst, 2.5)
 for _, rock in c.rocks do
  local away = Vector3.new(rock.part.Position.X - c.feet.X, 0, rock.part.Position.Z - c.feet.Z)
  away = away.Magnitude > 0.1 and away.Unit or rng:NextUnitVector()
  FX.Tween(rock.part, 0.9, {Position = rock.part.Position + away * rng:NextNumber(18, 35) + Vector3.yAxis * rng:NextNumber(4, 12),
   Transparency = 1})
 end
 for _, emitter in c.auraEmitters do emitter.Enabled = false end
 c.energy.Enabled = false
 if c.highlight then FX.Tween(c.highlight, 1.5, {FillTransparency = 1, OutlineTransparency = 1}) end
 FX.Tween(c.groundGlow, 0.9, {Size = Vector3.new(0.1, 45, 45), Transparency = 1})
 FX.Tween(c.light, 1, {Brightness = 0})
 local soundParent = c.mine and SoundService or c.aura
 FX.PlayFor(c, SOUNDS.LaunchBoom, soundParent)
 FX.PlayFor(c, SOUNDS.Roar, soundParent)
 FX.PlayFor(c, SOUNDS.Braam, soundParent)
 if c.drone then FX.Tween(c.drone, 1.5, {Volume = 0}) end
 if c.swell then FX.Tween(c.swell, 1.5, {Volume = 0}) end

 -- A red and black comet tail that rides with the ball for the rest of its flight.
 c.comet = FX.Comet(c.ballPosition, {
  {2.8, {Lifetime = 0.8, LightEmission = 1, Brightness = 2, Color = ColorSequence.new(Color3.fromRGB(255, 120, 100), RED),
   Transparency = NumberSequence.new(0.05, 1), WidthScale = NumberSequence.new(1, 0.15)}},
  {5, {Lifetime = 1.3, LightEmission = 0, Brightness = 1, Color = ColorSequence.new(Color3.fromRGB(60, 0, 0), Color3.new(0, 0, 0)),
   Transparency = NumberSequence.new(0.25, 1), WidthScale = NumberSequence.new(0.7, 1.5)}},
 }, {
  {Texture = FX.Textures.Smoke, Rate = 35, LightEmission = 0, Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180),
   Lifetime = NumberRange.new(0.8, 1.2), Color = ColorSequence.new(SMOKE), Size = NumberSequence.new(1.5, 4),
   Transparency = NumberSequence.new(0.3, 1), Rotation = NumberRange.new(0, 360)},
  {Texture = FX.Textures.Spark, Rate = 80, Speed = NumberRange.new(3, 8), SpreadAngle = Vector2.new(180, 180),
   Lifetime = NumberRange.new(0.4, 0.8), Color = ColorSequence.new(RED, EMBER), Size = NumberSequence.new(0.5, 0)},
 }, {RED, 6, 24})
 table.insert(c.objects, c.comet)
 if not c.mine then return end

 FX.ReleaseSwing(c.tool) -- the swing follows through at full speed
 FX.Flash(RED, 0, 0.6)
 c.grade.Brightness = 0.3
 FX.Tween(c.grade, 0.8, {Saturation = 0.1, Contrast = 0.25, Brightness = -0.05, TintColor = Color3.fromRGB(255, 205, 205)})
 c.blur.Size = 22
 FX.Tween(c.blur, 0.5, {Size = 0})
 -- Cut straight to riding behind the ball.
 local back = -c.forward
 local side = back:Cross(Vector3.yAxis) * -c.side
 c.chaseFrom = back * 10 + Vector3.yAxis * 3.2 + side * 3
 c.launchFov = 60
end

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

-- Which part of the timeline t is in: "power", or swing k (1..3) with seconds into it.
local function phaseAt(c, t)
 for k = 3, 1, -1 do
  if t >= c.swingT[k] then return k, t - c.swingT[k] end
 end
 return nil
end

local function cameraUpdate(c, t)
 local camera = workspace.CurrentCamera
 if c.left then
  FX.ChaseCamera(c, os.clock() - c.leftAt, CHASE_SECONDS, LAUNCH_FOV, CHASE_FOV)
  return
 end
 local P, f, fwd, up = c.rootPosition, c.facing, c.forward, Vector3.yAxis
 local k, into = phaseAt(c, t)
 local position, lookAt, fov
 local shake = 0
 if not k then
  -- Power-up: low in front of the batter and off to the downfield side (so the ball on the
  -- tee doesn't block them), looking up at them, slowly circling in.
  local u = clamp01(t / c.swingT[1])
  local angle = math.rad(lerp(55, 30, smooth(u)))
  position = P + (f * math.cos(angle) + fwd * math.sin(angle)) * lerp(9, 6, easeOut(u)) + up * lerp(-1.6, -0.6, u)
  lookAt = P + up * 1.2
  fov = lerp(55, 42, smooth(u))
  shake = 0.002 + 0.012 * u
 else
  local drift = clamp01(into / REPLAY_GAP)
  if k == 1 then
   -- Over the batter's shoulder (from the catcher's side), toward the ball.
   position = P - f * 4.5 + up * 2.4 - fwd * 3.5 + fwd * 0.5 * drift
   lookAt, fov = c.rest + up * 0.3, 52
  elseif k == 2 then
   -- Facing the batter from beyond the tee, low and wide.
   position = c.rest + f * 3.6 + fwd * 1.0 + up * 0.3 - fwd * 0.6 * drift
   lookAt, fov = (c.rest + P + up * 0.8) / 2, 64
  else
   -- Close on the ball from downfield, the bat coming straight at it.
   position = c.rest + fwd * 4 + up * 0.7 + f * 1.0 - fwd * 0.4 * drift
   lookAt, fov = c.rest - f * 0.4, 44
  end
 end
 if c.shakeUntil and os.clock() < c.shakeUntil then shake += c.shakeAmount * (c.shakeUntil - os.clock()) / 0.35 end
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
 if c.root and c.root.Parent then c.aura.CFrame = c.root.CFrame end

 local k, into = phaseAt(c, t)
 if not c.left then
  -- Power builds: more energy, lightning and pulses; the rocks rise and tumble.
  local build = clamp01(t / c.swingT[1])
  c.energy.Rate = lerp(30, 160, build)
  c.light.Brightness = 2 + build * 4 + math.sin(t * 10) * 1
  for _, rock in c.rocks do
   local lift = rock.rise * easeOut(t / c.swingT[1]) + math.sin(t * 2 + rock.phase) * 0.15
   rock.part.CFrame = CFrame.new(rock.base + Vector3.yAxis * lift)
    * CFrame.fromAxisAngle(rock.spin.Unit, rock.spin.Magnitude * t)
  end
  if now >= c.nextBolt then
   local center = c.aura.Position
   FX.Bolt(center + rng:NextUnitVector() * 2.5, center + rng:NextUnitVector() * rng:NextNumber(3, 5 + 3 * build), RED, 0.1 + 0.1 * build, 0.15)
   c.nextBolt = now + rng:NextNumber(0.08, 0.35) * (1 - 0.6 * build)
  end
  if not k and now >= c.nextPulse then
   FX.Shockwave(c.feet + Vector3.yAxis * 0.05, BLOOD, 2, 14 + 10 * build, 0.7)
   c.nextPulse = now + 0.8
  end
  if c.mine then
   -- The swing: held at the windup, then windup-to-contact in slow motion for each of the
   -- three swings, holding at contact after each impact.
   local clock = WINDUP_END
   if k then clock = math.min(Swing.BallContactTime, WINDUP_END + into * REPLAY_RATE) end
   FX.SetSwingClock(c.tool, clock)
   if k and k ~= c.shot then
    c.shot = k
    FX.Flash(Color3.new(0, 0, 0), 0.2, 0.2) -- a quick dip at each cut
   end
  end
 end
 for i = 1, 3 do
  if not c.impacts[i] and t >= c.contactT[i] then impact(c, i) end
 end
 if c.mine and c.left and not c.titleHidden and now - c.leftAt >= TITLE_HOLD then
  c.titleHidden = true
  FX.HideTitle()
 end
 -- The growl gives way to the swings; all audio fades out as the chase ends, so it finishes
 -- with the pictures.
 if k and c.growl then
  FX.Tween(c.growl, 0.5, {Volume = 0})
  c.growl = nil
 end
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
FX.WatchStations("Mythic", {
 ready = function(info)
  if not info.mine then return true end
  -- Stop the swing at the top of the backswing (BatClient fires "Hold" there).
  local tool = FX.BatterTool()
  if tool and not tool:GetAttribute("SwingClockOverride") then tool:SetAttribute("SwingHoldAt", WINDUP_END) end
  return FX.Swing.held or info.waited >= START_WAIT_LIMIT
 end,
 start = start,
 update = update,
 stop = stop,
 release = release,
})
