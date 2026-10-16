-- Client-side Ball cosmetics (BallStyles). Nothing here touches physics, distance or rewards:
--   * a visual copy of the batter's Ball model follows each station's physics ball (which is
--     hidden locally while the copy is shown), on the tee and in flight
--   * while a hit is in the air: trails, particles and glow on an invisible anchor that
--     follows the ball, plus one-shot bursts at launch and on the first landing
-- Models are the styled copies the server publishes to ReplicatedStorage.BallModels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Styles = require(ReplicatedStorage:WaitForChild("BallStyles"))
local Field = require(ReplicatedStorage:WaitForChild("FieldConfig"))
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))

local BallEffects = {}

local LAND_HEIGHT = 0.6 -- the ball's bottom this close to the ground counts as landing
local FULL_EFFECT_SPEED = 60 -- particles thin out below this speed (studs per second)
local MODEL_RETRY_SECONDS = 1

local container = Instance.new("Folder")
container.Name = "BallEffects"
container.Parent = workspace

local function invisiblePart(name, cframe)
 local part = Instance.new("Part")
 part.Name, part.Size, part.CFrame, part.Transparency = name, Vector3.one * 0.2, cframe, 1
 part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
 part.Parent = container
 return part
end

local function rainbow()
 local points = {}
 for i = 0, 6 do table.insert(points, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 * 0.85, 0.9, 1))) end
 return ColorSequence.new(points)
end

local function glow(parent, light, rangeScale)
 if not light then return nil end
 local point = Instance.new("PointLight")
 point.Color, point.Brightness, point.Range = light[1], light[2], light[3] * (rangeScale or 1)
 point.Parent = parent
 return point
end

-- ---------- the visual ball model ----------

local visuals = {} -- physics ball -> {itemId, model, retryAt}

local function clearVisual(ball)
 local entry = visuals[ball]
 if entry and entry.model then entry.model:Destroy() end
 visuals[ball] = nil
 if ball.Parent then ball.LocalTransparencyModifier = 0 end
end

-- Call every frame for each station ball; returns the visual model, if one is shown.
function BallEffects.UpdateVisual(ball)
 local itemId = ball:GetAttribute("EquipmentId")
 local entry = visuals[ball]
 if entry and entry.itemId ~= itemId then clearVisual(ball) entry = nil end
 if not entry or (not entry.model and os.clock() >= entry.retryAt) then
  local folder = ReplicatedStorage:FindFirstChild("BallModels")
  local template = folder and itemId and folder:FindFirstChild(itemId)
  local model
  if template then
   model = template:Clone()
   local diameter = template:GetAttribute("BallDiameter") or 1
   model:ScaleTo(model:GetScale() * ball.Size.X / diameter)
   local style = Styles.Get(itemId)
   glow(model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"), style and style.light, 0.6)
   model.Parent = container
  end
  entry = {itemId = itemId, model = model, retryAt = os.clock() + MODEL_RETRY_SECONDS}
  visuals[ball] = entry
 end
 if entry.model then
  entry.model:PivotTo(ball.CFrame)
  ball.LocalTransparencyModifier = 1
 else
  ball.LocalTransparencyModifier = 0
 end
 return entry.model
end

BallEffects.ClearVisual = clearVisual

-- ---------- bursts ----------

-- A flat shockwave ring expanding outward (built-in texture, laid flat by emitting it upward
-- with VelocityPerpendicular orientation).
local SHOCKWAVE_TEXTURE = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
local function ring(position, color, size)
 local holder = invisiblePart("ShockwaveRing", CFrame.new(position))
 local wave = Instance.new("ParticleEmitter")
 wave.Texture, wave.Orientation = SHOCKWAVE_TEXTURE, Enum.ParticleOrientation.VelocityPerpendicular
 wave.EmissionDirection, wave.Speed, wave.Enabled = Enum.NormalId.Top, NumberRange.new(0.01), false
 wave.Color, wave.LightEmission, wave.LightInfluence = ColorSequence.new(color), 1, 0
 wave.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, size or 26)})
 wave.Transparency = NumberSequence.new(0.05, 1)
 wave.Lifetime = NumberRange.new(0.55)
 wave.Parent = holder
 wave:Emit(1)
 Debris:AddItem(holder, 1)
end

local function bolts(position, color)
 local rng = Random.new()
 for _ = 1, 5 do
  local point = position
  local heading = rng:NextUnitVector()
  for _ = 1, 4 do
   local nextPoint = point + (heading + rng:NextUnitVector() * 0.6).Unit * rng:NextNumber(0.8, 1.6)
   local segment = invisiblePart("Bolt", CFrame.lookAt((point + nextPoint) / 2, nextPoint))
   segment.Size = Vector3.new(0.08, 0.08, (nextPoint - point).Magnitude)
   segment.Material, segment.Color, segment.Transparency = Enum.Material.Neon, color, 0
   Debris:AddItem(segment, 0.18)
   point = nextPoint
  end
 end
end

function BallEffects.Burst(name, position)
 local spec = name and Styles.Bursts[name]
 if not spec then return end
 local holder = invisiblePart("Burst", CFrame.new(position))
 for _, entry in spec.emit or {} do
  local emitter = Styles.MakeEmitter(entry[1], holder, 1.6)
  if emitter then
   emitter.Enabled = false
   emitter:Emit(entry[2])
  end
 end
 if spec.flash then
  local light = glow(holder, {spec.flash, 8, 18})
  TweenService:Create(light, TweenInfo.new(0.45), {Brightness = 0}):Play()
 end
 if spec.ring then ring(position, spec.ring) end
 if spec.bolts then bolts(position, spec.bolts) end
 Debris:AddItem(holder, 3)
end

-- ---------- flight effects ----------
-- Layered so they read as flashy without clutter, and build up with the ball's price (tier):
--   outer colour trail (true colour) + a thin white-hot core (additive glow)
--   a sparkle ribbon (from the Bubblegum Ball up), a glow halo around the ball, theme
--   particles, backspin on the model, and a flash + ring at launch and landing.

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SPARKLE_TIER = 0.2 -- tiers at or above this get the sparkle ribbon

-- How far up the Ball lineup an item is: 0 for the first, 1 for the last.
local function tierOf(itemId)
 local item = Equipment.GetById(itemId)
 local count = #Equipment.GetItems("Ball")
 return item and count > 1 and (item.order - 1) / (count - 1) or 0
end

local function trailColors(spec)
 return spec.rainbow and rainbow() or ColorSequence.new(spec.colors[1], spec.colors[2])
end

local function headColor(spec)
 return spec.rainbow and Color3.fromRGB(255, 235, 170) or spec.colors[1]
end

local function trailLayer(anchor, side, width, properties)
 local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
 top.Position, bottom.Position = Vector3.new(side, width / 2, 0), Vector3.new(side, -width / 2, 0)
 top.Parent, bottom.Parent = anchor, anchor
 local trail = Instance.new("Trail")
 trail.Attachment0, trail.Attachment1 = top, bottom
 trail.MinLength, trail.FaceCamera, trail.LightInfluence = 0.05, true, 0
 for property, value in properties do trail[property] = value end
 trail.Parent = anchor
 return trail
end

-- The trail layers for one side (twin trails call this twice). Returns {trail, kind} pairs.
local function makeTrails(anchor, spec, side, tier)
 local layers = {}
 -- Outer colour: unlit, normal blending (additive light washed colours to white).
 table.insert(layers, {kind = "outer", trail = trailLayer(anchor, side, spec.width, {
  Lifetime = spec.lifetime, LightEmission = 0, Brightness = 1.6, Color = trailColors(spec),
  Transparency = NumberSequence.new(0.3, 1), WidthScale = NumberSequence.new(1, 0.1)})})
 -- White-hot core: thin, short and additive, so the centre of the streak glows.
 table.insert(layers, {kind = "core", trail = trailLayer(anchor, side, spec.width * 0.3, {
  Lifetime = spec.lifetime * 0.5, LightEmission = 1, Brightness = 2,
  Color = ColorSequence.new(Color3.new(1, 1, 1), headColor(spec)),
  Transparency = NumberSequence.new(0, 1), WidthScale = NumberSequence.new(1, 0.2)})})
 -- Sparkle ribbon: glitter that widens as it fades, for the fancier balls.
 if tier >= SPARKLE_TIER then
  table.insert(layers, {kind = "sparkle", trail = trailLayer(anchor, side, spec.width * 1.7, {
   Lifetime = spec.lifetime * 0.8, LightEmission = 1, Brightness = 1.5, Color = trailColors(spec),
   Texture = SPARKLE_TEXTURE, TextureMode = Enum.TextureMode.Wrap, TextureLength = 1.6,
   Transparency = NumberSequence.new(0.25 - tier * 0.15, 1), WidthScale = NumberSequence.new(0.5, 1.4)})})
 end
 return layers
end

-- A soft glow halo that rides on the ball.
local function makeAura(anchor, color, ballSize, tier)
 local aura = Instance.new("ParticleEmitter")
 aura.Name, aura.Texture, aura.LockedToPart = "Aura", SPARKLE_TEXTURE, true
 aura.Color, aura.LightEmission, aura.LightInfluence = ColorSequence.new(color), 1, 0
 aura.Size = NumberSequence.new(ballSize * (2 + tier), ballSize * (2.6 + tier))
 aura.Transparency = NumberSequence.new(0.55 - tier * 0.3, 1)
 aura.Lifetime, aura.Rate, aura.Speed = NumberRange.new(0.12, 0.2), 30, NumberRange.new(0)
 aura.RotSpeed, aura.Rotation = NumberRange.new(-180, 180), NumberRange.new(0, 360)
 aura.Parent = anchor
 return aura
end

-- A quick flash and a ring in the ball's colour (launch and landing, bigger for fancier balls).
local function impact(position, color, tier, ringSize)
 local holder = invisiblePart("Impact", CFrame.new(position))
 local light = glow(holder, {color, 6 + 6 * tier, 14 + 10 * tier})
 TweenService:Create(light, TweenInfo.new(0.35), {Brightness = 0}):Play()
 Debris:AddItem(holder, 0.5)
 ring(position, color, ringSize * (0.6 + 0.8 * tier))
end

-- Starts a hit's flight effects; returns a handle for Update/Stop, or nil for plain balls.
function BallEffects.Launch(ball, itemId, restPosition)
 local style = Styles.Get(itemId)
 local flight = style and style.flight
 if not flight then return nil end
 local tier = tierOf(itemId)
 local anchor = invisiblePart("FlightEffects", CFrame.new(ball.Position))
 local handle = {anchor = anchor, flight = flight, trails = {}, emitters = {}, last = ball.Position,
  started = os.clock(), landed = false, radius = ball.Size.Y / 2, tier = tier, spin = 0}
 local color = flight.trail and headColor(flight.trail) or Color3.new(1, 1, 1)
 handle.color = color
 if flight.trail then
  local sides = flight.trail.twin and {-flight.trail.twin, flight.trail.twin} or {0}
  for _, side in sides do
   for _, layer in makeTrails(anchor, flight.trail, side, tier) do table.insert(handle.trails, layer) end
  end
 end
 handle.emitters[makeAura(anchor, color, ball.Size.X, tier)] = 30
 if flight.particles then
  local emitter = Styles.MakeEmitter(flight.particles.preset, anchor, 1 + tier * 0.4, flight.particles.rate)
  if emitter then
   emitter.Rate *= 0.8 + tier * 0.8
   handle.emitters[emitter] = emitter.Rate
  end
 end
 local light = style.light and {style.light[1], style.light[2] * (1 + tier), style.light[3]} or nil
 glow(anchor, light)
 impact(restPosition, color, tier, 16)
 BallEffects.Burst(flight.launch, restPosition)
 return handle
end

function BallEffects.Update(handle, ball, dt)
 local position = ball.Position
 local velocity = dt > 0 and (position - handle.last) / dt or Vector3.zero
 handle.last = position
 local speed = velocity.Magnitude
 if speed > 1 then handle.direction = velocity.Unit end
 local direction = handle.direction or Vector3.zAxis
 local up = math.abs(direction.Y) > 0.98 and Vector3.xAxis or Vector3.yAxis
 local frame = CFrame.lookAt(position, position + direction, up)
 handle.anchor.CFrame = frame
 local amount = math.clamp(speed / FULL_EFFECT_SPEED, 0, 1)
 -- Backspin on the visual model (cosmetic; the physics ball does not spin).
 handle.spin += dt * (14 + 18 * handle.tier) * amount
 local entry = visuals[ball]
 if entry and entry.model then entry.model:PivotTo(frame * CFrame.Angles(-handle.spin, 0, 0)) end
 local trail = handle.flight.trail
 local elapsed = os.clock() - handle.started
 for _, layer in handle.trails do
  if trail.hueShift and layer.kind ~= "core" then
   local hue = (elapsed * 0.35) % 1
   layer.trail.Color = ColorSequence.new(Color3.fromHSV(hue, 0.85, 1), Color3.fromHSV((hue + 0.3) % 1, 0.9, 1))
  end
  if trail.flicker and layer.kind ~= "core" then
   layer.trail.Transparency = NumberSequence.new(0.25 + math.random() * 0.5, 1)
  end
 end
 for emitter, rate in handle.emitters do emitter.Rate = rate * amount end
 if not handle.landed and velocity.Y < 0 and position.Y - handle.radius <= Field.GroundTop + LAND_HEIGHT then
  handle.landed = true
  impact(Vector3.new(position.X, Field.GroundTop + 0.1, position.Z), handle.color, handle.tier, 20)
  BallEffects.Burst(handle.flight.land, Vector3.new(position.X, Field.GroundTop + handle.radius, position.Z))
 end
end

function BallEffects.Stop(handle)
 for _, layer in handle.trails do layer.trail.Enabled = false end
 for emitter in handle.emitters do emitter.Enabled = false end
 local light = handle.anchor:FindFirstChildOfClass("PointLight")
 if light then light.Enabled = false end
 Debris:AddItem(handle.anchor, 2)
end

return BallEffects
