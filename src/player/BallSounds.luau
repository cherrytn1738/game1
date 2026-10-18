-- Client-side audio for a hit in progress, heard from the ball itself (so the batter hears it
-- with the flight camera and nearby players hear each other's hits):
--   * a wind whoosh that swells with the ball's speed while it is in the air
--   * a thud on each bounce, louder for harder landings
--   * a soft rolling rustle while it rolls, fading as it slows
--   * the fancier Balls' own sound layered on top (BallStyles.FlightSounds)
-- Speeds come from the rendered ball's movement. Presentation only: nothing here touches
-- physics, distance or rewards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Styles = require(ReplicatedStorage:WaitForChild("BallStyles"))
local Field = require(ReplicatedStorage:WaitForChild("FieldConfig"))

local BallSounds = {}

-- Roblox-licensed Pro Sound Effects audio: {id, volume, playbackSpeed}.
local WHOOSH = {"rbxassetid://9125742262", 0.8, 1} -- "Plasma Trails": airy whooshing loop
local BOUNCE = {"rbxassetid://9119332979", 0.8, 1} -- soccer chip shot: hollow thud, grass crunch
local ROLL = {"rbxassetid://9117898818", 0.35, 1.35} -- foliage roll and light rustling

local WHOOSH_FULL_SPEED = 220 -- studs per second for the loudest whoosh
local ROLL_FULL_SPEED = 45
local BOUNCE_MIN_SPEED = 8 -- downward speed needed for a thud
local BOUNCE_FULL_SPEED = 60
local BOUNCE_COOLDOWN = 0.15
local GROUND_GAP = 0.6 -- the ball's bottom this close to the ground counts as touching it
local VOLUME_RESPONSE = 8 -- how quickly loop volumes follow their targets
local STOP_FADE_SECONDS = 0.3

local container = Instance.new("Folder")
container.Name = "BallSounds"
container.Parent = workspace

-- Load every sound up front so the first hit of a session isn't late or silent.
task.spawn(function()
 local preload = {}
 local ids = {WHOOSH[1], BOUNCE[1], ROLL[1]}
 for _, spec in Styles.FlightSounds do table.insert(ids, spec[1]) end
 for _, id in ids do
  local s = Instance.new("Sound")
  s.SoundId = id
  table.insert(preload, s)
 end
 pcall(function() game:GetService("ContentProvider"):PreloadAsync(preload) end)
end)

local function anchorPart(position)
 local part = Instance.new("Part")
 part.Name, part.Size, part.CFrame, part.Transparency = "BallSoundAnchor", Vector3.one * 0.2, CFrame.new(position), 1
 part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
 part.Parent = container
 return part
end

local function sound(spec, parent, looped)
 local s = Instance.new("Sound")
 s.SoundId, s.PlaybackSpeed, s.Looped = spec[1], spec[3] or 1, looped
 s.Volume = looped and 0 or spec[2]
 s.RollOffMode, s.RollOffMinDistance, s.RollOffMaxDistance = Enum.RollOffMode.InverseTapered, 15, 250
 s.Parent = parent
 if looped then
  -- Start somewhere random in the loop so repeated hits don't sound identical.
  local function start() if s.TimeLength > 0 then s.TimePosition = math.random() * s.TimeLength end end
  if s.IsLoaded then start() else s.Loaded:Once(start) end
 end
 s:Play()
 return s
end

-- Starts a hit's sounds at launch; returns a handle for Update/Stop.
function BallSounds.Start(ball, itemId)
 local anchor = anchorPart(ball.Position)
 local handle = {anchor = anchor, last = ball.Position, lastVelocity = Vector3.zero, radius = ball.Size.Y / 2,
  nextBounce = 0, whoosh = sound(WHOOSH, anchor, true), roll = sound(ROLL, anchor, true)}
 local theme = Styles.FlightSounds[itemId]
 if theme then
  handle.theme, handle.themeVolume = sound(theme, anchor, true), theme[2]
 end
 return handle
end

local function approach(s, target, dt)
 s.Volume += (target - s.Volume) * math.min(1, dt * VOLUME_RESPONSE)
end

function BallSounds.Update(handle, ball, dt)
 if dt <= 0 then return end
 local position = ball.Position
 local velocity = (position - handle.last) / dt
 local previous = handle.lastVelocity
 handle.last, handle.lastVelocity = position, velocity
 handle.anchor.CFrame = CFrame.new(position)
 local speed = velocity.Magnitude
 local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
 local touching = position.Y - handle.radius <= Field.GroundTop + GROUND_GAP

 -- Whoosh: only in the air; a gentle curve so slower hits still whoosh a little.
 local rush = math.clamp(speed / WHOOSH_FULL_SPEED, 0, 1) ^ 0.6
 approach(handle.whoosh, touching and 0 or WHOOSH[2] * rush, dt)
 handle.whoosh.PlaybackSpeed = WHOOSH[3] * (0.8 + 0.45 * rush)

 -- Bounce: coming down fast near the ground, then no longer coming down as fast.
 local now = os.clock()
 if touching and previous.Y < -BOUNCE_MIN_SPEED and velocity.Y > previous.Y * 0.4 and now >= handle.nextBounce then
  handle.nextBounce = now + BOUNCE_COOLDOWN
  local hardness = math.clamp(-previous.Y / BOUNCE_FULL_SPEED, 0.2, 1)
  local thud = sound(BOUNCE, handle.anchor, false)
  thud.Volume, thud.PlaybackSpeed = BOUNCE[2] * hardness, BOUNCE[3] * (0.85 + 0.25 * math.random())
  Debris:AddItem(thud, 2)
 end

 -- Roll: on the ground and moving along it, quieter and lower as it slows.
 local rolling = touching and math.abs(velocity.Y) < 4 and horizontal > 1
 local roll = math.clamp(horizontal / ROLL_FULL_SPEED, 0, 1)
 approach(handle.roll, rolling and ROLL[2] * roll or 0, dt)
 handle.roll.PlaybackSpeed = ROLL[3] * (0.75 + 0.35 * roll)

 -- The Ball's own sound: strongest in fast flight, fading as the ball comes to rest.
 if handle.theme then
  approach(handle.theme, handle.themeVolume * (0.35 + 0.65 * rush) * math.clamp(speed / 6, 0, 1), dt)
 end
end

-- Fades everything out and removes it.
function BallSounds.Stop(handle)
 for _, child in handle.anchor:GetChildren() do
  if child:IsA("Sound") then TweenService:Create(child, TweenInfo.new(STOP_FADE_SECONDS), {Volume = 0}):Play() end
 end
 Debris:AddItem(handle.anchor, STOP_FADE_SECONDS + 0.05)
end

return BallSounds
