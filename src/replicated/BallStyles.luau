-- Looks and flight effects for each Ball (cosmetic only: nothing here changes launch,
-- physics, distance or rewards). Models come from tools/blender/balls.py; each mesh is named
-- "<item id>__<Part>" and is coloured here by its Part name.
--   parts: Part -> {color, material, transparency}
--   light: {color, brightness, range} glow on the display and in flight
--   flight: trail (colors, width, lifetime, plus rainbow / hueShift / flicker / twin),
--     particles (an Emitters preset and optional rate), launch and land (Bursts presets)
--   idle: an Emitters preset shown around the ball on its display pedestal
local M = Enum.Material
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function look(color, material, transparency)
 return {color = color, material = material or M.SmoothPlastic, transparency = transparency or 0}
end

local Styles = {}

Styles.Balls = {
 baseball = {
  parts = {Shell = look(rgb(245, 244, 236), M.Leather), Stitches = look(rgb(205, 30, 36))},
 },
 practice_ball = { -- Sandlot Ball
  parts = {Shell = look(rgb(214, 178, 128), M.Leather), Stitches = look(rgb(160, 60, 48)),
   Scuffs = look(rgb(150, 112, 74), M.Leather)},
  flight = {trail = {colors = {rgb(255, 255, 255), rgb(235, 225, 205)}, width = 0.35, lifetime = 0.2},
   land = "Dust"},
 },
 bubblegum_ball = {
  parts = {Shell = look(rgb(255, 120, 190)), Icing = look(rgb(255, 246, 250)),
   Sprinkles1 = look(rgb(255, 220, 50)), Sprinkles2 = look(rgb(90, 215, 255)), Sprinkles3 = look(rgb(150, 255, 140))},
  flight = {trail = {colors = {rgb(255, 80, 175), rgb(255, 150, 215)}, width = 0.45, lifetime = 0.25},
   particles = {preset = "Bubbles"}, land = "Sprinkles"},
  idle = "Bubbles",
 },
 crystal_ball = {
  parts = {Shell = look(rgb(160, 92, 235), M.Glass, 0.25), Core = look(rgb(215, 150, 255), M.Neon),
   Points = look(rgb(205, 160, 255), M.Glass, 0.15)},
  light = {rgb(200, 130, 255), 1.5, 8},
  flight = {trail = {colors = {rgb(205, 120, 255), rgb(125, 55, 225)}, width = 0.5, lifetime = 0.3},
   particles = {preset = "Glitter"}, land = "Gems"},
  idle = "Glitter",
 },
 frost_comet = {
  parts = {Shell = look(rgb(140, 210, 255), M.Glass, 0.3), Core = look(rgb(225, 245, 255), M.Neon),
   Shards = look(rgb(220, 240, 255), M.Ice), Seam = look(rgb(255, 255, 255), M.Neon)},
  light = {rgb(160, 220, 255), 2, 10},
  flight = {trail = {colors = {rgb(170, 230, 255), rgb(40, 140, 255)}, width = 0.7, lifetime = 0.55},
   particles = {preset = "Snow"}, land = "Frost"},
  idle = "Snow",
 },
 inferno_ball = {
  parts = {Shell = look(rgb(34, 28, 28), M.Basalt), Lava = look(rgb(255, 115, 25), M.Neon)},
  light = {rgb(255, 120, 40), 2, 10},
  flight = {trail = {colors = {rgb(255, 210, 90), rgb(255, 60, 15)}, width = 0.7, lifetime = 0.4},
   particles = {preset = "Flame"}, land = "Fire"},
  idle = "Embers",
 },
 thunder_ball = {
  parts = {Shell = look(rgb(92, 42, 165)), Bolts = look(rgb(255, 235, 70), M.Neon)},
  light = {rgb(255, 235, 120), 2, 10},
  flight = {trail = {colors = {rgb(255, 235, 60), rgb(150, 70, 255)}, width = 0.6, lifetime = 0.35, flicker = true},
   particles = {preset = "Sparks"}, launch = "Zap", land = "Zap"},
  idle = "Sparks",
 },
 galaxy_ball = {
  parts = {Shell = look(rgb(18, 12, 52)), NebulaPink = look(rgb(255, 100, 205), M.Neon, 0.15),
   NebulaBlue = look(rgb(90, 160, 255), M.Neon, 0.15), Stars = look(rgb(255, 255, 255), M.Neon)},
  light = {rgb(170, 130, 255), 1.5, 9},
  flight = {trail = {colors = {rgb(255, 120, 220), rgb(90, 140, 255)}, width = 0.75, lifetime = 0.5, hueShift = true},
   particles = {preset = "Stardust"}, land = "Stardust"},
  idle = "Stardust",
 },
 dragonfire_ball = {
  parts = {Shell = look(rgb(52, 10, 12)), Scales = look(rgb(135, 22, 22), M.Slate),
   EyeSlit = look(rgb(255, 175, 35), M.Neon), Spines = look(rgb(28, 22, 22))},
  light = {rgb(255, 130, 40), 2.5, 12},
  flight = {trail = {colors = {rgb(255, 200, 70), rgb(220, 30, 10)}, width = 0.55, lifetime = 0.45, twin = 0.55},
   particles = {preset = "Flame", rate = 50}, launch = "Fire", land = "Fire"},
  idle = "Embers",
 },
 supernova_ball = {
  parts = {Core = look(rgb(255, 246, 210), M.Neon), Halo = look(rgb(255, 220, 120), M.Neon, 0.65),
   Flares = look(rgb(255, 205, 80), M.Neon),
   Ring1 = look(rgb(255, 70, 80), M.Neon), Ring2 = look(rgb(255, 155, 40), M.Neon), Ring3 = look(rgb(255, 240, 70), M.Neon),
   Ring4 = look(rgb(90, 255, 120), M.Neon), Ring5 = look(rgb(80, 155, 255), M.Neon), Ring6 = look(rgb(180, 90, 255), M.Neon)},
  light = {rgb(255, 240, 200), 3, 14},
  flight = {trail = {width = 0.9, lifetime = 0.6, rainbow = true},
   particles = {preset = "Stars"}, launch = "Shockwave", land = "Supernova"},
  idle = "Stars",
 },
}

-- Particle presets on built-in Roblox textures (no uploads needed). Sizes suit the
-- 0.8-stud ball in flight; the display scales them with the item.
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/fire_sparks_main.dds"
local function range(a, z) return NumberRange.new(a, z) end
local function grow(a, z) return NumberSequence.new(a, z) end
local function pop(size) return NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, size), NumberSequenceKeypoint.new(1, 0)}) end
local function fadeOut(start) return NumberSequence.new(start or 0, 1) end

Styles.Emitters = {
 Bubbles = {Texture = SPARKLE, Color = ColorSequence.new(rgb(255, 210, 240), rgb(210, 245, 255)), LightEmission = 0.3,
  Size = pop(0.35), Transparency = NumberSequence.new(0.35), Rate = 30, Lifetime = range(0.8, 1.4), Speed = range(0.5, 1.5),
  SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 2, 0)},
 Glitter = {Texture = SPARKLE, Color = ColorSequence.new(rgb(240, 210, 255), rgb(170, 110, 255)), LightEmission = 1,
  Size = pop(0.3), Rate = 40, Lifetime = range(0.4, 0.8), Speed = range(0.5, 2), SpreadAngle = Vector2.new(180, 180),
  RotSpeed = range(-180, 180)},
 Snow = {Texture = SPARKLE, Color = ColorSequence.new(rgb(255, 255, 255), rgb(170, 225, 255)), LightEmission = 0.8,
  Size = pop(0.3), Rate = 50, Lifetime = range(0.6, 1.2), Speed = range(0.5, 2), SpreadAngle = Vector2.new(180, 180),
  Acceleration = Vector3.new(0, -3, 0), RotSpeed = range(-90, 90)},
 Flame = {Texture = FIRE, Color = ColorSequence.new(rgb(255, 200, 80), rgb(255, 60, 15)), LightEmission = 1,
  Size = grow(0.9, 0.1), Rate = 35, Lifetime = range(0.25, 0.5), Speed = range(0.5, 1.5), SpreadAngle = Vector2.new(25, 25)},
 Embers = {Texture = SPARKLE, Color = ColorSequence.new(rgb(255, 160, 50), rgb(255, 60, 10)), LightEmission = 1,
  Size = pop(0.25), Rate = 12, Lifetime = range(1, 2), Speed = range(0.3, 1), Acceleration = Vector3.new(0, 1.5, 0),
  SpreadAngle = Vector2.new(180, 180)},
 Sparks = {Texture = SPARK, Color = ColorSequence.new(rgb(255, 250, 170), rgb(190, 140, 255)), LightEmission = 1,
  Size = pop(0.4), Rate = 45, Lifetime = range(0.15, 0.35), Speed = range(3, 6), SpreadAngle = Vector2.new(180, 180)},
 Stardust = {Texture = SPARKLE, Color = ColorSequence.new(rgb(255, 140, 225), rgb(120, 170, 255)), LightEmission = 1,
  Size = pop(0.35), Rate = 45, Lifetime = range(0.8, 1.5), Speed = range(0.2, 1), SpreadAngle = Vector2.new(180, 180),
  RotSpeed = range(-120, 120)},
 Stars = {Texture = SPARKLE, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, rgb(255, 120, 120)),
  ColorSequenceKeypoint.new(0.33, rgb(255, 240, 120)), ColorSequenceKeypoint.new(0.66, rgb(120, 220, 255)),
  ColorSequenceKeypoint.new(1, rgb(220, 140, 255))}), LightEmission = 1, Size = pop(0.5), Rate = 50,
  Lifetime = range(0.6, 1.2), Speed = range(1, 3), SpreadAngle = Vector2.new(180, 180), RotSpeed = range(-200, 200)},
 Dust = {Texture = SMOKE, Color = ColorSequence.new(rgb(225, 205, 170)), Size = grow(0.6, 2.2), Transparency = fadeOut(0.3),
  Lifetime = range(0.6, 1), Speed = range(2, 5), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -2, 0)},
 Leaves = {Texture = SPARKLE, Color = ColorSequence.new(rgb(140, 220, 90), rgb(60, 150, 50)), LightEmission = 0.2,
  Size = pop(0.4), Lifetime = range(0.8, 1.4), Speed = range(2, 5), SpreadAngle = Vector2.new(180, 180),
  Acceleration = Vector3.new(0, -4, 0), RotSpeed = range(-200, 200)},
 FireBurst = {Texture = FIRE, Color = ColorSequence.new(rgb(255, 220, 100), rgb(255, 60, 15)), LightEmission = 1,
  Size = grow(2, 0.2), Lifetime = range(0.4, 0.8), Speed = range(6, 14), SpreadAngle = Vector2.new(180, 180)},
}

-- One-shot bursts at launch or landing: Emitters presets to emit, plus optional extras.
Styles.Bursts = {
 Dust = {emit = {{"Dust", 14}}},
 Leaves = {emit = {{"Leaves", 30}}},
 Sprinkles = {emit = {{"Bubbles", 25}, {"Glitter", 20}}},
 Gems = {emit = {{"Glitter", 45}}, flash = rgb(200, 130, 255)},
 Frost = {emit = {{"Snow", 60}}, ring = rgb(190, 235, 255), flash = rgb(170, 225, 255)},
 Fire = {emit = {{"FireBurst", 30}, {"Embers", 30}}, flash = rgb(255, 130, 40)},
 Zap = {emit = {{"Sparks", 40}}, bolts = rgb(255, 245, 140), flash = rgb(255, 240, 150)},
 Stardust = {emit = {{"Stardust", 60}}, flash = rgb(170, 130, 255)},
 Shockwave = {ring = rgb(255, 240, 200), flash = rgb(255, 240, 200)},
 Supernova = {emit = {{"Stars", 80}}, ring = rgb(255, 240, 200), flash = rgb(255, 245, 210)},
}

function Styles.Get(itemId)
 return Styles.Balls[itemId]
end

-- The Part name of an imported mesh ("crystal_ball__Core" -> "Core").
function Styles.PartName(name)
 return name:match("__(.+)$") or name
end

-- Colours a model's parts by name from a style's parts table (shared with BatStyles).
function Styles.ApplyParts(model, style)
 if not style then return model end
 for _, part in model:GetDescendants() do
  if part:IsA("BasePart") then
   local partLook = style.parts and style.parts[Styles.PartName(part.Name)]
   if partLook then
    part.Color, part.Material, part.Transparency = partLook.color, partLook.material, partLook.transparency
    if part:IsA("MeshPart") then part.TextureID = "" end
   end
   part.CastShadow = false
  end
 end
 return model
end

function Styles.ApplyLook(model, itemId)
 return Styles.ApplyParts(model, Styles.Balls[itemId])
end

-- A ParticleEmitter from a preset (scaled by sizeScale, rate optionally overridden).
function Styles.MakeEmitter(presetName, parent, sizeScale, rate)
 local preset = Styles.Emitters[presetName]
 if not preset then return nil end
 local emitter = Instance.new("ParticleEmitter")
 emitter.Name = presetName
 for property, value in preset do
  if property == "Size" and sizeScale and sizeScale ~= 1 then
   local points = {}
   for _, keypoint in value.Keypoints do
    table.insert(points, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * sizeScale))
   end
   value = NumberSequence.new(points)
  end
  emitter[property] = value
 end
 if rate then emitter.Rate = rate end
 emitter.Parent = parent
 return emitter
end

return Styles
