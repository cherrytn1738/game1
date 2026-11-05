-- Client-side Ball cosmetics (BallStyles). Nothing here touches physics, distance or rewards:
--   * a visual copy of the batter's Ball model follows each station's physics ball (which is
--     hidden locally while the copy is shown), on the tee and in flight
--   * while a hit is in the air: each ball's own stack of flight layers (ribbons, particles,
--     orbiters, debris, arcs, pulses, echoes) around the ball, plus one-shot bursts at launch
--     and on the first landing
-- Models are the styled copies the server publishes to ReplicatedStorage.BallModels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Styles = require(ReplicatedStorage:WaitForChild("BallStyles"))
local Field = require(ReplicatedStorage:WaitForChild("FieldConfig"))
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))

local BallEffects = {}

local LAND_HEIGHT = 0.6 -- the ball's bottom this close to the ground counts as landing
-- The visible ball, and every flight effect around it, is drawn this many times the size of
-- the physics ball, so it is easy to follow. The physics ball itself never changes size, and the
-- visible one is raised so its bottom still rests where the physics ball's does.
local VISUAL_SCALE = 2
local function visualLift(ball)
 return Vector3.new(0, ball.Size.Y / 2 * (VISUAL_SCALE - 1), 0)
end
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
   model:ScaleTo(model:GetScale() * ball.Size.X * VISUAL_SCALE / diameter)
   local style = Styles.Get(itemId)
   glow(model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"), style and style.light, 0.6)
   model.Parent = container
  end
  entry = {itemId = itemId, model = model, retryAt = os.clock() + MODEL_RETRY_SECONDS}
  visuals[ball] = entry
 end
 if entry.model then
  entry.model:PivotTo(ball.CFrame + visualLift(ball))
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

-- A die face rolled on landing (the Lucky Dice): a number from 1 to 6 that pops up and fades.
-- Picked here on each client, so it is cosmetic only and never changes a result.
local function rolledNumber(holder, color)
 local gui = Instance.new("BillboardGui")
 gui.Name, gui.Size, gui.StudsOffset, gui.LightInfluence = "DiceRoll", UDim2.fromScale(5, 5), Vector3.new(0, 3, 0), 0
 local label = Instance.new("TextLabel")
 label.BackgroundTransparency, label.Size, label.Font, label.TextScaled = 1, UDim2.fromScale(1, 1), Enum.Font.FredokaOne, true
 label.Text, label.TextColor3 = tostring(math.random(1, 6)), color
 local stroke = Instance.new("UIStroke")
 stroke.Thickness, stroke.Color = 4, Color3.fromRGB(255, 255, 255)
 stroke.Parent = label
 label.Parent = gui
 gui.Parent = holder
 local fade = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1)
 TweenService:Create(gui, TweenInfo.new(1.6, Enum.EasingStyle.Quad), {StudsOffset = Vector3.new(0, 8, 0)}):Play()
 TweenService:Create(label, fade, {TextTransparency = 1}):Play()
 TweenService:Create(stroke, fade, {Transparency = 1}):Play()
end

function BallEffects.Burst(name, position)
 local spec = name and Styles.Bursts[name]
 if not spec then return end
 local holder = invisiblePart("Burst", CFrame.new(position))
 if spec.number then rolledNumber(holder, spec.number) end
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
-- Each Ball's flight is a stack of layers from its style (BallStyles flight.layers), so every
-- ball has its own signature look:
--   ribbon   a Trail: colour gradient, a shaped silhouette (taper), glowing bands, optional
--            texture; can spiral round the ball (orbit), sway (wobble) or crackle (jitter /
--            flicker / hueShift)
--   streak   a soft, round glowing trail of overlapping particles (volumetric, not flat)
--   emitter  a particle preset riding on the ball (optionally offset, or emitted backwards)
--   orbiters small parts circling the ball (crystals, gears, rune stones, stars...)
--   debris   bits shed behind the ball that tumble down and fade (leaves, petals, rocks...)
--   arcs     crackling lightning bolts around and behind the ball
--   pulse    rings that ripple out from the ball along its path
--   echoes   fading ghost copies of the ball model
-- Plus a soft glow halo, backspin on the model, and a flash + ring at launch and landing.
-- Positions are in the ball's flight frame: -Z ahead, +Z behind, X/Y across the path. Sizes
-- in styles are for the physics ball; everything is drawn VISUAL_SCALE times bigger.

local TEXTURES = {
 sparkle = "rbxasset://textures/particles/sparkles_main.dds",
 fire = "rbxasset://textures/particles/fire_main.dds",
 smoke = "rbxasset://textures/particles/smoke_main.dds",
 sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
 glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
 vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
 core = "rbxasset://textures/particles/explosion01_core_main.dds",
 shockwave = SHOCKWAVE_TEXTURE,
}
local SPAWN_MIN_AMOUNT = 0.25 -- spawned layers (debris, arcs, pulses, echoes) pause when this slow
local GLOW_EMISSION = 0.35 -- how much light a glow ribbon or streak adds

-- How far up the main Ball lineup an item is: 0 for the first, 1 for the last. Later series
-- (World 2's balls) come after it, so they all get the top tier.
local function tierOf(itemId)
 local item = Equipment.GetById(itemId)
 local count = #Equipment.GetSeriesItems("Ball")
 return item and count > 1 and math.min(1, (item.order - 1) / (count - 1)) or 0
end

-- A colour list (head to tail) as a ColorSequence.
local function gradient(colors)
 if #colors == 1 then return ColorSequence.new(colors[1]) end
 local points = {}
 for index, color in colors do table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color)) end
 return ColorSequence.new(points)
end

-- Ribbon silhouettes (WidthScale from the ball to the tail), so trails aren't plain strips.
local function curve(points)
 local keypoints = {}
 for _, point in points do table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2])) end
 return NumberSequence.new(keypoints)
end
local SHAPES = {
 comet = curve({{0, 1}, {1, 0.05}}), -- widest at the ball, thinning away
 teardrop = curve({{0, 0.2}, {0.12, 1}, {1, 0}}), -- swells just behind the ball, then a long point
 needle = curve({{0, 1}, {0.06, 0.55}, {1, 0}}), -- a bright head on a long thin tail
 swell = curve({{0, 0.35}, {0.45, 1}, {1, 0.15}}), -- billows out as it trails (smoke, sand)
 scallop = curve({{0, 0.9}, {0.15, 0.35}, {0.3, 1}, {0.45, 0.3}, {0.6, 0.85}, {0.75, 0.25}, {1, 0}}), -- wavy edges
 flame = curve({{0, 0.5}, {0.1, 1}, {0.3, 0.6}, {0.5, 0.95}, {0.75, 0.35}, {1, 0}}), -- licking tongues
}

-- Transparency from the ball to the tail; bands > 0 splits it into that many glowing segments.
local function fadeCurve(fade, bands)
 if not bands then return NumberSequence.new(fade[1], fade[2]) end
 local points = {{0, fade[1]}}
 for band = 1, bands do
  local t = band / (bands + 1)
  local base = fade[1] + (fade[2] - fade[1]) * t
  table.insert(points, {t - 0.5 / (bands + 1), math.min(1, base + 0.55)})
  table.insert(points, {t, base})
 end
 table.insert(points, {1, fade[2]})
 return curve(points)
end

local function makeRibbon(anchor, spec)
 local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
 top.Parent, bottom.Parent = anchor, anchor
 local trail = Instance.new("Trail")
 trail.Attachment0, trail.Attachment1 = top, bottom
 trail.MinLength, trail.FaceCamera, trail.LightInfluence = 0.05, true, 0
 trail.Lifetime = spec.lifetime or 0.4
 -- Glowing ribbons add only some light: fully additive light washes colours out to white
 -- against the bright sky, so the rest of the colour comes from normal blending.
 trail.LightEmission, trail.Brightness = spec.glow and GLOW_EMISSION or 0, spec.glow and 2.2 or 1.6
 trail.Color = spec.rainbow and rainbow() or gradient(spec.colors or {Color3.new(1, 1, 1)})
 local fade, taper = spec.fade or {0.2, 1}, spec.taper or "comet"
 trail.Transparency = fadeCurve(fade, spec.bands)
 trail.WidthScale = type(taper) == "string" and SHAPES[taper] or NumberSequence.new(taper[1], taper[2])
 if spec.texture then
  trail.Texture = TEXTURES[spec.texture] or spec.texture
  trail.TextureMode = spec.stretch and Enum.TextureMode.Stretch or Enum.TextureMode.Wrap
  trail.TextureLength = spec.textureLength or 2
 end
 trail.Parent = anchor
 return {spec = spec, trail = trail, top = top, bottom = bottom}
end

-- Moves a ribbon's attachments for orbit / wobble / jitter (and sets its width).
local function placeRibbon(ribbon, elapsed)
 local spec = ribbon.spec
 local offset = spec.offset or Vector3.zero
 if spec.orbit then
  local angle = 2 * math.pi * (elapsed * spec.orbit.speed + (spec.orbit.phase or 0))
  offset += Vector3.new(math.cos(angle), math.sin(angle), 0) * spec.orbit.radius
 end
 if spec.wobble then
  offset += Vector3.new(math.sin(2 * math.pi * (elapsed * spec.wobble.freq + (spec.wobble.phase or 0))) * spec.wobble.amp, 0, 0)
 end
 if spec.jitter then
  offset += Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 2, 0) * spec.jitter
 end
 offset *= VISUAL_SCALE
 local half = Vector3.new(0, (spec.width or 0.5) * VISUAL_SCALE / 2, 0)
 ribbon.top.Position, ribbon.bottom.Position = offset + half, offset - half
 if spec.hueShift then
  local hue = (elapsed * spec.hueShift) % 1
  ribbon.trail.Color = ColorSequence.new(Color3.fromHSV(hue, 0.8, 1), Color3.fromHSV((hue + 0.3) % 1, 0.9, 1))
 end
 if spec.flicker then
  local fade = spec.fade or {0.2, 1}
  ribbon.trail.Transparency = fadeCurve({math.min(0.95, fade[1] + math.random() * 0.5), fade[2]}, spec.bands)
 end
end

-- A soft, round glowing streak made of overlapping particles left in the ball's wake: a
-- volumetric trail instead of a flat ribbon.
local function makeStreak(anchor, spec)
 local streak = Instance.new("ParticleEmitter")
 streak.Name, streak.Texture = "Streak", TEXTURES[spec.texture or "glow"] or spec.texture
 streak.Rate, streak.Speed = spec.rate or 120, NumberRange.new(0)
 streak.Lifetime = NumberRange.new(spec.lifetime or 0.4)
 streak.LightEmission, streak.LightInfluence = spec.glow and GLOW_EMISSION or 0, 0
 streak.Brightness = spec.glow and 1.8 or 1.2
 streak.Color = gradient(spec.colors or {Color3.new(1, 1, 1)})
 local size = (spec.size or 1) * VISUAL_SCALE
 streak.Size = NumberSequence.new(size, size * (spec.endSize or 0))
 streak.Transparency = NumberSequence.new(spec.transparency or 0.2, 1)
 streak.Rotation, streak.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-(spec.rotSpeed or 60), spec.rotSpeed or 60)
 streak.Parent = anchor
 return streak
end

local function makeEmitter(anchor, spec, tier)
 local parent = anchor
 if spec.offset then
  parent = Instance.new("Attachment")
  parent.Position, parent.Parent = spec.offset * VISUAL_SCALE, anchor
 end
 local emitter = Styles.MakeEmitter(spec.preset, parent, (spec.size or 1) * (1 + tier * 0.3) * VISUAL_SCALE * 0.8, spec.rate)
 if emitter and spec.back then emitter.EmissionDirection = Enum.NormalId.Back end
 return emitter
end

local function makeOrbiters(spec)
 local parts = {}
 for index = 1, spec.count or 3 do
  local part = invisiblePart("Orbiter", CFrame.identity)
  part.Transparency, part.CastShadow = spec.transparency or 0, false
  part.Size = (spec.size or Vector3.one * 0.2) * VISUAL_SCALE
  part.Shape = spec.shape and Enum.PartType[spec.shape] or Enum.PartType.Block
  local colors = spec.colors or {spec.color or Color3.new(1, 1, 1)}
  part.Color = colors[(index - 1) % #colors + 1]
  part.Material = spec.material or Enum.Material.Neon
  if spec.trail then
   local a, b = Instance.new("Attachment"), Instance.new("Attachment")
   local half = spec.trail.width * VISUAL_SCALE / 2
   a.Position, b.Position = Vector3.new(0, half, 0), Vector3.new(0, -half, 0)
   a.Parent, b.Parent = part, part
   local trail = Instance.new("Trail")
   trail.Attachment0, trail.Attachment1, trail.FaceCamera = a, b, true
   trail.Lifetime, trail.LightEmission, trail.LightInfluence = spec.trail.lifetime, 1, 0
   trail.Color, trail.Transparency = ColorSequence.new(part.Color), NumberSequence.new(0.2, 1)
   trail.WidthScale = NumberSequence.new(1, 0)
   trail.Parent = part
  end
  table.insert(parts, {part = part, phase = (index - 1) / (spec.count or 3)})
 end
 return parts
end

local function placeOrbiters(layer, frame, elapsed)
 local spec = layer.spec
 for _, entry in layer.parts do
  local angle = 2 * math.pi * (elapsed * spec.speed + entry.phase)
  local spin = CFrame.Angles(elapsed * (spec.spin or 0), elapsed * (spec.spin or 0) * 0.7, 0)
  entry.part.CFrame = frame * CFrame.Angles(0, 0, angle) * CFrame.new(spec.radius * VISUAL_SCALE, 0, (spec.lag or 0) * VISUAL_SCALE) * spin
 end
end

local function spawnDebris(spec, frame)
 local rng = Random.new()
 local size = (spec.size or Vector3.new(0.2, 0.2, 0.2)) * VISUAL_SCALE
 local scale = rng:NextNumber(0.6, 1.2)
 local start = frame * CFrame.new(Vector3.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5), rng:NextNumber(0.2, 0.8)) * VISUAL_SCALE)
  * CFrame.Angles(rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3), 0)
 local bit = invisiblePart("Debris", start)
 bit.Size, bit.Transparency, bit.CastShadow = size * scale, spec.transparency or 0, false
 bit.Shape = spec.shape and Enum.PartType[spec.shape] or Enum.PartType.Block
 local colors = spec.colors or {spec.color or Color3.new(1, 1, 1)}
 bit.Color, bit.Material = colors[rng:NextInteger(1, #colors)], spec.material or Enum.Material.SmoothPlastic
 local life = spec.life or 0.8
 local drift = rng:NextUnitVector() * (spec.spread or 1.5) * life
 local goal = (start + drift - Vector3.new(0, (spec.fall or 4) * life, 0)) * CFrame.Angles(rng:NextNumber(-4, 4), rng:NextNumber(-4, 4), 0)
 TweenService:Create(bit, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
  {CFrame = goal, Size = bit.Size * 0.3, Transparency = 1}):Play()
 Debris:AddItem(bit, life)
end

local function spawnArc(spec, frame)
 local rng = Random.new()
 local point = frame.Position
 local heading = (frame.LookVector * -1 + rng:NextUnitVector() * 1.2).Unit
 local length = (spec.length or 1.8) * VISUAL_SCALE
 for _ = 1, spec.segments or 4 do
  local nextPoint = point + (heading + rng:NextUnitVector() * 0.7).Unit * length / (spec.segments or 4) * rng:NextNumber(0.7, 1.3)
  local segment = invisiblePart("Arc", CFrame.lookAt((point + nextPoint) / 2, nextPoint))
  local thickness = (spec.thickness or 0.06) * VISUAL_SCALE
  segment.Size = Vector3.new(thickness, thickness, (nextPoint - point).Magnitude)
  segment.Material, segment.Color, segment.Transparency, segment.CastShadow = Enum.Material.Neon, spec.color, 0, false
  Debris:AddItem(segment, spec.life or 0.09)
  point = nextPoint
 end
end

-- A ring that faces along the flight path and ripples outward from the ball.
local function spawnPulse(spec, frame)
 local holder = invisiblePart("Pulse", frame)
 local wave = Instance.new("ParticleEmitter")
 wave.Texture = TEXTURES[spec.texture or "shockwave"]
 wave.Orientation, wave.EmissionDirection = Enum.ParticleOrientation.VelocityPerpendicular, Enum.NormalId.Front
 wave.Speed, wave.Enabled, wave.LockedToPart = NumberRange.new(0.01), false, false
 wave.Color, wave.LightEmission, wave.LightInfluence = ColorSequence.new(spec.color), 1, 0
 wave.Size = NumberSequence.new((spec.from or 0.6) * VISUAL_SCALE, (spec.size or 5) * VISUAL_SCALE)
 wave.Transparency = NumberSequence.new(spec.transparency or 0.2, 1)
 wave.Lifetime = NumberRange.new(spec.life or 0.4)
 wave.Rotation, wave.RotSpeed = NumberRange.new(0, 360), NumberRange.new(spec.rotSpeed or 0)
 wave.Parent = holder
 wave:Emit(1)
 Debris:AddItem(holder, (spec.life or 0.4) + 0.2)
end

-- A see-through copy of the ball model left behind that fades out.
local function spawnEcho(spec, model)
 if not model then return end
 local echo = model:Clone()
 for _, item in echo:GetDescendants() do
  if item:IsA("BasePart") then
   item.Material, item.Color, item.Transparency, item.CastShadow = Enum.Material.ForceField, spec.color, 0.1, false
   TweenService:Create(item, TweenInfo.new(spec.life or 0.35), {Transparency = 1, Size = item.Size * (spec.grow or 1.4)}):Play()
  elseif item:IsA("Light") or item:IsA("ParticleEmitter") or item:IsA("Trail") then
   item:Destroy()
  end
 end
 echo.Parent = container
 Debris:AddItem(echo, spec.life or 0.35)
end

local SPAWNERS = {debris = true, arcs = true, pulse = true, echoes = true}

-- A soft glow halo that rides on the ball.
local function makeAura(anchor, color, ballSize, tier)
 local aura = Instance.new("ParticleEmitter")
 aura.Name, aura.Texture, aura.LockedToPart = "Aura", TEXTURES.sparkle, true
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
 local handle = {anchor = anchor, flight = flight, ribbons = {}, emitters = {}, orbiters = {}, spawners = {},
  last = ball.Position, started = os.clock(), landed = false, radius = ball.Size.Y / 2, tier = tier, spin = 0}
 handle.color = flight.color or (style.light and style.light[1]) or Color3.new(1, 1, 1)
 for _, layer in flight.layers or {} do
  if layer.type == "ribbon" then
   table.insert(handle.ribbons, makeRibbon(anchor, layer))
  elseif layer.type == "emitter" then
   local emitter = makeEmitter(anchor, layer, tier)
   if emitter then handle.emitters[emitter] = emitter.Rate end
  elseif layer.type == "streak" then
   local streak = makeStreak(anchor, layer)
   handle.emitters[streak] = streak.Rate
  elseif layer.type == "orbiters" then
   table.insert(handle.orbiters, {spec = layer, parts = makeOrbiters(layer)})
  elseif SPAWNERS[layer.type] then
   table.insert(handle.spawners, {spec = layer, next = 0})
  end
 end
 if flight.aura ~= false then handle.emitters[makeAura(anchor, handle.color, ball.Size.X * VISUAL_SCALE, tier)] = 30 end
 local light = style.light and {style.light[1], style.light[2] * (1 + tier), style.light[3]} or nil
 glow(anchor, light)
 impact(restPosition, handle.color, tier, 16)
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
 -- Effects centre on the visible ball, which sits a little above the physics ball.
 local center = position + visualLift(ball)
 local frame = CFrame.lookAt(center, center + direction, up)
 handle.anchor.CFrame = frame
 local amount = math.clamp(speed / FULL_EFFECT_SPEED, 0, 1)
 local elapsed = os.clock() - handle.started
 -- Backspin on the visual model (cosmetic; the physics ball does not spin).
 handle.spin += dt * (14 + 18 * handle.tier) * amount
 local entry = visuals[ball]
 local model = entry and entry.model
 if model then model:PivotTo(frame * CFrame.Angles(-handle.spin, 0, 0)) end
 for _, ribbon in handle.ribbons do placeRibbon(ribbon, elapsed) end
 for _, layer in handle.orbiters do placeOrbiters(layer, frame, elapsed) end
 for emitter, rate in handle.emitters do emitter.Rate = rate * amount end
 -- Spawned layers run on their own clocks (rate per second, or interval seconds apart).
 local now = os.clock()
 if amount >= SPAWN_MIN_AMOUNT then
  for _, spawner in handle.spawners do
   local spec = spawner.spec
   if now >= spawner.next then
    spawner.next = now + (spec.interval or 1 / (spec.rate or 10))
    if spec.type == "debris" then spawnDebris(spec, frame)
    elseif spec.type == "arcs" then spawnArc(spec, frame)
    elseif spec.type == "pulse" then spawnPulse(spec, frame)
    elseif spec.type == "echoes" then spawnEcho(spec, model) end
   end
  end
 end
 if not handle.landed and velocity.Y < 0 and position.Y - handle.radius <= Field.GroundTop + LAND_HEIGHT then
  handle.landed = true
  impact(Vector3.new(position.X, Field.GroundTop + 0.1, position.Z), handle.color, handle.tier, 20)
  BallEffects.Burst(handle.flight.land, Vector3.new(position.X, Field.GroundTop + handle.radius, position.Z))
 end
end

function BallEffects.Stop(handle)
 for _, ribbon in handle.ribbons do ribbon.trail.Enabled = false end
 for emitter in handle.emitters do emitter.Enabled = false end
 table.clear(handle.spawners)
 for _, layer in handle.orbiters do
  for _, entry in layer.parts do
   TweenService:Create(entry.part, TweenInfo.new(0.3), {Transparency = 1, Size = entry.part.Size * 0.2}):Play()
   Debris:AddItem(entry.part, 0.35)
  end
 end
 local light = handle.anchor:FindFirstChildOfClass("PointLight")
 if light then light.Enabled = false end
 Debris:AddItem(handle.anchor, 2)
end

return BallEffects
