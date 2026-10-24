-- Client-side audio for a hit in progress, played from the ball itself (so the batter hears it
-- with the flight camera and nearby players hear each other's hits):
--   * BallFlightSound: a wind whoosh that swells with the ball's speed while it is in the air
--   * a landing sound on each bounce, louder for harder landings, chosen by the surface
--     under the ball (soft ground, hard floor, or ice/crystal/glass)
--   * BallRollingSound over BallRollingBedSound: a soft, leafy grass roll over a smooth hush
--     while it runs along the grass, both fading and lowering as it slows
--   * the fancier Balls' own sound layered on top (BallStyles.FlightSounds)
-- HitCinematicClient calls Start when the ball leaves the tee, Update every frame, and Stop
-- once the hit ends for any reason (the ball reset, the hit was cancelled, the ball is gone).
-- Presentation only: nothing here touches physics, distance or rewards.
--
-- Speeds come from the ball's movement as drawn on screen, not its replicated velocity, so the
-- sounds follow what the player sees: the client draws the server's ball smoothed between
-- network updates, which can be a little behind the velocity values and rounds off bounces.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Styles = require(ReplicatedStorage:WaitForChild("BallStyles"))
local Field = require(ReplicatedStorage:WaitForChild("FieldConfig"))
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local GameAudio = require(ReplicatedStorage:WaitForChild("GameAudio"))

local BallSounds = {}

-- Sound assets. Swap an id here to change a sound. Each entry is {id, volume, playbackSpeed}:
-- volume is the loudest it plays (balancing each file's own loudness), playbackSpeed its base
-- pitch. Optional: eq = {low, mid, high} gains in dB; region = loop only this stretch of the
-- file (seconds); start = play from this point (seconds).
local SOUNDS = {
 -- Pro Sound Effects "Plasma Trails": airy whooshing loop.
 BallFlightSound = {"rbxassetid://9125742262", 0.8, 1},
 -- Landings, one per surface family (see SURFACES). Pro Sound Effects soccer chip shot: a
 -- hollow thud, with its grassy crunch cut back. Its impact comes 0.16 s in.
 BallBounceSound = {"rbxassetid://9119332979", 0.8, 1, start = 0.15, eq = {0, 0, -9}},
 -- PSE "Wood Hit Cast Iron Weight Knocks Against Wood": a solid, clean "tok".
 BallBounceHardSound = {"rbxassetid://9126266458", 0.6, 1, eq = {0, 0, -3}},
 -- PSE "Glass Clinks 11": a small clean clink, layered over the knock on ice and crystal.
 BallBounceGlassySound = {"rbxassetid://9114596112", 0.5, 1.1, start = 0.16},
 -- The roll is mostly the smooth bed, with only a faint hint of grass texture on top, so it
 -- sits under the whoosh and thuds (at full speed the two together are about half as loud as
 -- the loudest whoosh).
 -- Pro Sound Effects "Leaves Slide, Auto Tire Roll, Leafy Brush" (a wheel rolling through
 -- foliage), mids softened and scratchy highs cut hard, looping only its steady stretch (it
 -- fades in and out elsewhere). Swap this id for a cleaner grass roll if one turns up.
 BallRollingSound = {"rbxassetid://9116258239", 0.4, 1, eq = {0, -6, -30}, region = {5, 10}},
 -- Seamless brown noise (DistroKid "Brown Noise for Concentration"), sped up a little, deep
 -- lows and hiss cut: a smooth, warm rolling body.
 BallRollingBedSound = {"rbxassetid://98631380084935", 0.12, 2.2, eq = {-12, 0, -20}},
}

-- Tuning. Speeds are in studs per second; pitch ranges multiply a sound's playbackSpeed from
-- its slowest to its fastest.
local FLIGHT_MIN_SPEED = 10 -- the whoosh is silent below this
local FLIGHT_MAX_SPEED = 220 -- the loudest whoosh
local FLIGHT_PITCH = {0.85, 1.18}
local ROLL_MIN_SPEED = 1 -- the roll is silent below this
local ROLL_MAX_SPEED = 45 -- the loudest roll
local ROLL_PITCH = {0.95, 1.05}
local ROLL_BED_PITCH = {0.95, 1.05}
-- Roll loudness = (speed share) ^ this: above 1 keeps medium speeds quiet and slow rolls barely
-- there, fading naturally toward silence.
local ROLL_VOLUME_CURVE = 1.3
local BOUNCE_MIN_SPEED = 8 -- coming down at least this fast makes a thud
local BOUNCE_SOFTEST_SPEED = 4 -- the volume curve starts from silence here...
local BOUNCE_MAX_SPEED = 60 -- ...up to the loudest thud here
local BOUNCE_VOLUME_CURVE = 1.4 -- above 1: little hops fall away quickly
-- The Ball's own themed sound: its share of full volume in slow flight (full in fast flight),
-- and once it is on the ground.
local THEME_SLOWEST = 0.35
local THEME_GROUNDED = 0.4
local BOUNCE_COOLDOWN = 0.15 -- seconds between thuds
local FADE_SPEED = 8 -- how quickly loop volumes follow their targets
local GROUND_FADE_IN_SPEED = 30 -- the roll comes in quickly on contact, so it lines up
local GROUNDED_HOLD_SECONDS = 0.25 -- stays "on the ground" this long after the last contact
local STOP_FADE_SECONDS = 0.3
-- Ground contact, as drawn: the ball's bottom this close to the grass counts as touching it.
local GROUND_GAP = 0.6
-- The drawn ball can turn around a stud or two above the grass on a fast bounce without ever
-- touching it, so a bounce is the drawn ball turning from falling to rising anywhere this low.
local BOUNCE_HEIGHT = 3
-- How far ahead of the drawn contact a landing sound starts, covering a new Sound's start-up,
-- and the height (studs) within which an arriving ball is judged.
local IMPACT_LEAD_SECONDS = 0.02
local ARRIVE_HEIGHT = 2
local TELEPORT_STUDS = 20 -- a one-frame jump at least this far, and well beyond the ball's speed, is a reset

-- Surface families: the runway section under the ball picks how its landings and roll sound.
-- A light touch: soft ground keeps the muted thud and the faint grass texture; hard floors
-- knock and roll a little firmer; ice, crystal and glass tap brightly and roll glassy-smooth.
--   bounce: which landing sound; accent: a lighter layer on top; grass: share of the grass
--   texture in the roll; bedPitch: multiplies the smooth roll's pitch; bedHigh: its treble
--   (dB, lower = duller)
local SURFACES = {
 soft = {bounce = "BallBounceSound", grass = 1, bedPitch = 1, bedHigh = -20},
 hard = {bounce = "BallBounceHardSound", grass = 0, bedPitch = 1.15, bedHigh = -15},
 glassy = {bounce = "BallBounceHardSound", accent = "BallBounceGlassySound", grass = 0, bedPitch = 1.3, bedHigh = -11},
}
-- The themed runway sections of both Worlds (WorldConfig); anything else goes by the floor's material,
-- then falls back to soft.
local SECTION_SURFACES = {
 grass = "soft", jungle = "soft", desert = "soft",
 snow = "glassy", stone = "glassy", neon = "glassy", cosmic = "glassy",
 candy = "hard", lava = "hard", sky = "hard",
 -- World 2.
 prehistoric = "soft", stoneage = "soft", samurai = "soft", frontier = "soft",
 egypt = "hard", greek = "hard", viking = "hard", knight = "hard", foundry = "hard",
 chrono = "glassy",
 -- World 3.
 biodome = "soft", lunar = "soft", mars = "soft",
 solar = "hard", maglev = "hard", metropolis = "hard", robotics = "hard", spaceport = "hard",
 virtual = "glassy", singularity = "glassy",
}
local MATERIAL_SURFACES = {
 [Enum.Material.Glass] = "glassy", [Enum.Material.Ice] = "glassy", [Enum.Material.Glacier] = "glassy",
 [Enum.Material.Marble] = "hard", [Enum.Material.Slate] = "hard", [Enum.Material.Concrete] = "hard",
 [Enum.Material.Basalt] = "hard", [Enum.Material.CrackedLava] = "hard", [Enum.Material.SmoothPlastic] = "hard",
 [Enum.Material.Plastic] = "hard", [Enum.Material.Wood] = "hard", [Enum.Material.WoodPlanks] = "hard",
}
local SURFACE_RAY = Vector3.new(0, -(BOUNCE_HEIGHT + 3), 0)

-- Load every sound up front so the first hit of a session isn't late or silent.
task.spawn(function()
 local preload = {}
 local specs = {}
 for _, spec in SOUNDS do table.insert(specs, spec) end
 for _, spec in Styles.FlightSounds do table.insert(specs, spec) end
 for _, spec in specs do
  if spec[1] then
   local s = Instance.new("Sound")
   s.SoundId = spec[1]
   table.insert(preload, s)
  end
 end
 pcall(function() game:GetService("ContentProvider"):PreloadAsync(preload) end)
end)

-- The surface family under a position, from the field's ground parts (nil if none below).
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local function groundFolders()
 local folders = {}
 for _, world in Worlds.Worlds do
  local field = workspace:FindFirstChild(world.fieldName or "")
  local ground = field and field:FindFirstChild("Ground")
  if ground then table.insert(folders, ground) end
 end
 return folders
end
local function surfaceAt(position)
 rayParams.FilterDescendantsInstances = groundFolders()
 local hit = workspace:Raycast(position, SURFACE_RAY, rayParams)
 if not hit then return nil end
 return SECTION_SURFACES[hit.Instance:GetAttribute("SectionId")] or MATERIAL_SURFACES[hit.Material] or "soft"
end

local function sound(name, spec, parent, looped)
 local s = Instance.new("Sound")
 s.Name, s.SoundId, s.PlaybackSpeed, s.Looped = name, spec[1], spec[3] or 1, looped
 s.SoundGroup = GameAudio.Group("Gameplay")
 s.Volume = looped and 0 or spec[2]
 s.RollOffMode, s.RollOffMinDistance, s.RollOffMaxDistance = Enum.RollOffMode.InverseTapered, 15, 250
 if spec.eq then
  local eq = Instance.new("EqualizerSoundEffect")
  eq.LowGain, eq.MidGain, eq.HighGain = spec.eq[1], spec.eq[2], spec.eq[3]
  eq.Parent = s
 end
 if spec.region then
  local region = NumberRange.new(spec.region[1], spec.region[2])
  s.PlaybackRegionsEnabled, s.PlaybackRegion, s.LoopRegion = true, region, region
 end
 if spec.start then s.TimePosition = spec.start end
 s.Parent = parent
 if looped then
  -- Start somewhere random in the loop so repeated hits don't sound identical.
  local function start()
   if spec.region then
    s.TimePosition = spec.region[1] + math.random() * (spec.region[2] - spec.region[1])
   elseif s.TimeLength > 0 then
    s.TimePosition = math.random() * s.TimeLength
   end
  end
  if s.IsLoaded then start() else s.Loaded:Once(start) end
 end
 s:Play()
 return s
end

-- Starts a hit's sounds on the ball at launch; returns a handle for Update/Stop. Each hit makes
-- its own looping Sounds once and only changes their volume and pitch after that.
function BallSounds.Start(ball, itemId)
 local handle = {last = ball.Position, lastSpeed = 0, fall = 0, armed = true, lastHeight = math.huge, radius = ball.Size.Y / 2,
  nextBounce = 0, loops = {}}
 local function loop(name, spec)
  local s = sound(name, spec, ball, true)
  table.insert(handle.loops, s)
  return s
 end
 handle.flight = loop("BallFlightSound", SOUNDS.BallFlightSound)
 handle.rolling = loop("BallRollingSound", SOUNDS.BallRollingSound)
 handle.rollingBed = loop("BallRollingBedSound", SOUNDS.BallRollingBedSound)
 handle.bedEq = handle.rollingBed:FindFirstChildOfClass("EqualizerSoundEffect")
 handle.surface = "soft"
 local theme = Styles.FlightSounds[itemId]
 if theme then handle.theme, handle.themeVolume = loop("BallThemeSound", theme), theme[2] end
 return handle
end

-- Moves a loop's volume toward target; fadeIn (if given) is used while it is getting louder.
local function fade(s, target, dt, fadeIn)
 local speed = fadeIn and target > s.Volume and fadeIn or FADE_SPEED
 s.Volume += (target - s.Volume) * math.min(1, dt * speed)
end

-- 0 at min, 1 at max.
local function amount(speed, min, max)
 return math.clamp((speed - min) / (max - min), 0, 1)
end

local function pitch(spec, range, t)
 return (spec[3] or 1) * (range[1] + (range[2] - range[1]) * t)
end

function BallSounds.Update(handle, ball, dt)
 if dt <= 0 then return end
 local position = ball.Position
 -- A sudden jump far beyond the ball's own motion is it being reset to the tee (its position
 -- can arrive a frame before its state): skip that frame rather than hear it as a bounce.
 local moved = (position - handle.last).Magnitude
 if moved > TELEPORT_STUDS and moved > 3 * handle.lastSpeed * dt then
  -- (Remembered as its speed, so genuinely fast motion carries on from the next frame.)
  handle.last, handle.lastHeight, handle.lastSpeed = position, math.huge, moved / dt
  return
 end
 local velocity = (position - handle.last) / dt
 handle.last = position
 local speed = velocity.Magnitude
 handle.lastSpeed = speed
 local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
 local height = position.Y - handle.radius - Field.GroundTop
 local touching = height <= GROUND_GAP
 local now = os.clock()
 if height < BOUNCE_HEIGHT then handle.surface = surfaceAt(position) or handle.surface end
 local surface = SURFACES[handle.surface]

 -- Landing, timed to the frame the drawn ball meets the ground: it fires when the ball, at its
 -- current downward speed, will reach the ground within the next frame (plus the moment a new
 -- Sound takes to start), not once it has already turned back up. If the drawn ball turns
 -- around higher than that (it smooths fast bounces), the turn itself still counts. One
 -- landing per fall: it re-arms once the ball rises again. fall is the fastest it came down
 -- since then (frame-to-frame speeds are uneven).
 handle.fall = math.min(handle.fall, velocity.Y)
 -- Both only count low down: an uneven frame high in the air can briefly read as a huge
 -- downward speed, and the smoothed drawn ball slows over its last stud or two, so arriving
 -- is judged only in the last ARRIVE_HEIGHT studs (a sound slightly early is more noticeable
 -- than one a frame late).
 local arriving = height < ARRIVE_HEIGHT and velocity.Y < -BOUNCE_MIN_SPEED
  and height <= -velocity.Y * (dt + IMPACT_LEAD_SECONDS)
 -- The turn is judged by where it turned (last frame's height): a fast bounce is already well
 -- back up by the frame that shows it rising. It must be clearly rising, because the drawn
 -- ball can pause for a frame mid-fall at low frame rates. At low frame rates the smoothing
 -- also turns fast bounces higher, so the window grows by one frame of its fall.
 local turned = handle.lastHeight < BOUNCE_HEIGHT - handle.fall * dt and velocity.Y > 2
 handle.lastHeight = height
 local bounced = handle.armed and (arriving or turned) and handle.fall < -BOUNCE_MIN_SPEED
 if bounced then
  handle.armed = false
 elseif not handle.armed and velocity.Y > 2 then
  handle.armed, handle.fall = true, 0
 end
 if bounced then
  -- A curve, so a hard first landing is clearly heard, a medium bounce moderately, and the
  -- last little hops barely at all.
  local hardness = amount(-handle.fall, BOUNCE_SOFTEST_SPEED, BOUNCE_MAX_SPEED) ^ BOUNCE_VOLUME_CURVE
  handle.fall = 0
  if now >= handle.nextBounce then
   handle.nextBounce = now + BOUNCE_COOLDOWN
   for _, name in {surface.bounce, surface.accent} do
    local spec = SOUNDS[name]
    if spec and spec[1] then
     local thud = sound(name, spec, ball, false)
     -- Harder landings sit a touch lower (heavier); a little variety so repeats differ.
     thud.Volume = spec[2] * hardness
     thud.PlaybackSpeed = spec[3] * (1.04 - 0.08 * hardness) * (0.96 + 0.08 * math.random())
     Debris:AddItem(thud, 2)
    end
   end
  end
 end

 -- Grounded: from the first bounce, and while it runs along the grass. It stays grounded
 -- through brief skips between contacts, so the whoosh and roll don't flicker during bounces.
 if bounced or (touching and horizontal > ROLL_MIN_SPEED) then handle.groundedAt = now end
 local grounded = handle.groundedAt ~= nil and now - handle.groundedAt < GROUNDED_HOLD_SECONDS

 -- Flight: only while airborne; a gentle curve so slower hits still whoosh a little.
 local rush = amount(speed, FLIGHT_MIN_SPEED, FLIGHT_MAX_SPEED) ^ 0.6
 fade(handle.flight, grounded and 0 or SOUNDS.BallFlightSound[2] * rush, dt)
 handle.flight.PlaybackSpeed = pitch(SOUNDS.BallFlightSound, FLIGHT_PITCH, rush)

 -- Rolling: only while grounded, fading and lowering as it slows.
 local roll = amount(horizontal, ROLL_MIN_SPEED, ROLL_MAX_SPEED)
 local rollLevel = grounded and roll ^ ROLL_VOLUME_CURVE or 0
 fade(handle.rolling, SOUNDS.BallRollingSound[2] * surface.grass * rollLevel, dt, GROUND_FADE_IN_SPEED)
 handle.rolling.PlaybackSpeed = pitch(SOUNDS.BallRollingSound, ROLL_PITCH, roll)
 fade(handle.rollingBed, SOUNDS.BallRollingBedSound[2] * rollLevel, dt, GROUND_FADE_IN_SPEED)
 handle.rollingBed.PlaybackSpeed = pitch(SOUNDS.BallRollingBedSound, ROLL_BED_PITCH, roll) * surface.bedPitch
 if handle.bedEq then handle.bedEq.HighGain = surface.bedHigh end

 -- The Ball's own sound, layered over the whoosh: strongest in fast flight, softer once it
 -- is on the ground, fading as it comes to rest.
 if handle.theme then
  local level = (THEME_SLOWEST + (1 - THEME_SLOWEST) * rush) * (grounded and THEME_GROUNDED or 1)
  fade(handle.theme, handle.themeVolume * level * math.clamp(speed / 6, 0, 1), dt)
 end
end

-- Fades the hit's sounds out and removes them. Safe to call more than once, and after the
-- ball itself is gone (its Sounds go with it).
function BallSounds.Stop(handle)
 for _, s in handle.loops do
  if s.Parent then TweenService:Create(s, TweenInfo.new(STOP_FADE_SECONDS), {Volume = 0}):Play() end
  Debris:AddItem(s, STOP_FADE_SECONDS + 0.05)
 end
 handle.loops = {}
end

return BallSounds
