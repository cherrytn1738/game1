-- Cosmetic scenery for themed runways: walls, decks, props, backdrops, section titles.
-- Every part is anchored with collision, touch, and query disabled, so nothing
-- here can affect ball flight, measured distance, rewards, or camera occlusion.
local ServerStorage = game:GetService("ServerStorage")
local Field = require(game:GetService("ReplicatedStorage"):WaitForChild("FieldConfig"))
local RunwayDecor = {}

local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local CREAM = Color3.fromRGB(255, 246, 228)
local BARK = Color3.fromRGB(122, 82, 52)
local STONE = Color3.fromRGB(150, 145, 140)
local CANDY = {Color3.fromRGB(247, 83, 155), Color3.fromRGB(255, 160, 60), Color3.fromRGB(150, 110, 245)}
local FROSTING = {Color3.fromRGB(255, 150, 190), Color3.fromRGB(150, 105, 70), Color3.fromRGB(170, 230, 255)}
-- Filler kinds used when a section does not list its own `fillers`.
local DEFAULT_FILLERS = {"bush", "rock"}
local TITLE_HEIGHT = 40
-- Same texture UICommon already uses; tiled large on the floor it reads as soft caustics.
local FLOOR_PATTERN = "rbxassetid://385956923"
-- Turns a cylinder to run along the runway, so its round face looks back at the tee.
local FACE_TEE = CFrame.Angles(0, math.pi / 2, 0)

local function newPart(className, parent, name, size, cframe, color, material)
 local part = Instance.new(className)
 part.Name, part.Size, part.CFrame = name, size, cframe
 part.Color, part.Material = color, material or Enum.Material.SmoothPlastic
 part.Anchored = true
 part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
 part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
 part.Parent = parent
 return part
end

-- Builders work in runway space: +X is right of the lane, +Y is up from the
-- ground top, and -Z is downfield, so a point at distance d has z = -d.
local function newKit(parent, frame)
 local kit = {}
 local function place(position, rotation)
  return frame * CFrame.new(position) * (rotation or CFrame.identity)
 end
 function kit.box(name, size, position, color, material, rotation)
  return newPart("Part", parent, name, size, place(position, rotation), color, material)
 end
 function kit.wedge(name, size, position, color, material, rotation)
  return newPart("WedgePart", parent, name, size, place(position, rotation), color, material)
 end
 function kit.ball(name, diameter, position, color, material)
  local part = kit.box(name, Vector3.one * diameter, position, color, material)
  part.Shape = Enum.PartType.Ball
  return part
 end
 -- Ellipsoid: a sphere mesh stretched to the part's size.
 function kit.blob(name, size, position, color, material, rotation)
  local part = kit.box(name, size, position, color, material, rotation)
  local mesh = Instance.new("SpecialMesh")
  mesh.MeshType = Enum.MeshType.Sphere
  mesh.Parent = part
  return part
 end
 -- Cylinders run along their local X axis; the default rotation stands them upright.
 function kit.cylinder(name, length, diameter, position, color, material, rotation)
  local part = newPart("Part", parent, name, Vector3.new(length, diameter, diameter),
   place(position, rotation or CFrame.Angles(0, 0, math.pi / 2)), color, material)
  part.Shape = Enum.PartType.Cylinder
  return part
 end
 -- A box stretched between two points; width is across, thickness is up.
 function kit.span(name, from, to, width, thickness, color, material)
  return newPart("Part", parent, name, Vector3.new(width, thickness, (to - from).Magnitude),
   frame * CFrame.lookAt((from + to) / 2, to), color, material)
 end
 -- Floor inlays sit just above the ground top and never cast shadows.
 function kit.inlay(name, size, position, color, material)
  local part = kit.box(name, size, position, color, material)
  part.CastShadow = false
  return part
 end
 return kit
end

local function palette(section)
 local base, accent = section.color, section.accent
 return {
  base = base, accent = accent,
  light = base:Lerp(WHITE, 0.45), dark = base:Lerp(BLACK, 0.3), deep = base:Lerp(BLACK, 0.55),
  cream = accent:Lerp(WHITE, 0.6),
 }
end

-- Props stand on the deck at p. v varies size/color deterministically; side is
-- -1 (left) or 1 (right), so "toward the lane" is -side on the X axis.
local Props = {}

function Props.tree(kit, p, c, v)
 local s = 0.9 + (v % 3) * 0.15
 kit.cylinder("Trunk", 16 * s, 3.2 * s, p + Vector3.new(0, 8 * s, 0), Color3.fromRGB(122, 82, 52), Enum.Material.Wood)
 kit.blob("Crown", Vector3.new(20, 16, 20) * s, p + Vector3.new(0, 20 * s, 0), c.base)
 kit.blob("Crown", Vector3.new(14, 12, 14) * s, p + Vector3.new(4 * s, 26 * s, 2 * s), c.base:Lerp(c.accent, 0.35))
 kit.blob("Crown", Vector3.new(12, 10, 12) * s, p + Vector3.new(-5 * s, 24 * s, -3 * s), c.base:Lerp(c.accent, 0.6))
 kit.blob("Bush", Vector3.new(10, 6, 9) * s, p + Vector3.new(7 * s, 2.5 * s, -6 * s), c.dark)
end

function Props.flowers(kit, p, c, v)
 local petals = {Color3.fromRGB(255, 138, 178), Color3.fromRGB(255, 224, 102), WHITE, Color3.fromRGB(176, 150, 255)}
 kit.blob("FlowerBed", Vector3.new(18, 3, 14), p + Vector3.new(0, 0.6, 0), c.dark)
 for i = 1, 4 do
  local angle = i * 1.57 + v
  local base = p + Vector3.new(math.cos(angle) * 5, 0, math.sin(angle) * 4)
  local height = 3 + (i % 3)
  kit.box("Stem", Vector3.new(0.5, height, 0.5), base + Vector3.new(0, height / 2, 0), c.dark)
  kit.blob("Petals", Vector3.new(3.4, 1.2, 3.4), base + Vector3.new(0, height + 0.3, 0), petals[(i + v) % #petals + 1])
  kit.ball("FlowerCenter", 1.2, base + Vector3.new(0, height + 0.7, 0), Color3.fromRGB(255, 196, 60))
 end
end

function Props.mushroom(kit, p, c, v)
 local s = 0.9 + (v % 2) * 0.35
 kit.cylinder("Stem", 7 * s, 3 * s, p + Vector3.new(0, 3.5 * s, 0), CREAM)
 kit.blob("Cap", Vector3.new(11, 6, 11) * s, p + Vector3.new(0, 7.5 * s, 0), Color3.fromRGB(240, 84, 96))
 for i = 1, 3 do
  local angle = i * 2.1
  kit.ball("Spot", 1.6 * s, p + Vector3.new(math.cos(angle) * 3, 9.8, math.sin(angle) * 3) * Vector3.new(s, s, s), WHITE)
 end
end

function Props.pine(kit, p, c, v)
 local s = 0.9 + (v % 3) * 0.15
 local needles = Color3.fromRGB(46, 120, 104)
 kit.cylinder("Trunk", 6 * s, 2.4 * s, p + Vector3.new(0, 3 * s, 0), Color3.fromRGB(110, 76, 54), Enum.Material.Wood)
 for tier = 0, 2 do
  local width = (16 - tier * 4) * s
  local y = (8 + tier * 7) * s
  kit.blob("Needles", Vector3.new(width, 8 * s, width), p + Vector3.new(0, y, 0), needles)
  kit.blob("Snow", Vector3.new(width * 0.7, 4 * s, width * 0.7), p + Vector3.new(0, y + 3 * s, 0), WHITE, Enum.Material.Snow)
 end
end

function Props.snowman(kit, p, c, v, side)
 local hat = Color3.fromRGB(40, 44, 60)
 kit.ball("Body", 9, p + Vector3.new(0, 4.5, 0), WHITE, Enum.Material.Snow)
 kit.ball("Body", 6.5, p + Vector3.new(0, 11, 0), WHITE, Enum.Material.Snow)
 kit.ball("Head", 4.6, p + Vector3.new(0, 16, 0), WHITE, Enum.Material.Snow)
 kit.cylinder("Scarf", 1.2, 5.2, p + Vector3.new(0, 13.8, 0), c.dark)
 kit.cylinder("HatBrim", 0.6, 5, p + Vector3.new(0, 18.1, 0), hat)
 kit.cylinder("Hat", 3.2, 3.2, p + Vector3.new(0, 19.9, 0), hat)
 kit.cylinder("Nose", 2.4, 0.7, p + Vector3.new(0, 16, 2.8), Color3.fromRGB(255, 140, 50), nil, FACE_TEE)
end

function Props.iceShards(kit, p, c, v)
 kit.blob("SnowDrift", Vector3.new(16, 4, 12), p + Vector3.new(0, 1, 0), WHITE, Enum.Material.Snow)
 for i = 1, 3 do
  local height = 10 + i * 4 + (v % 2) * 3
  kit.box("IceShard", Vector3.new(3.5, height, 3.5), p + Vector3.new((i - 2) * 4, height / 2, (i % 2) * 2),
   c.base:Lerp(WHITE, 0.3), Enum.Material.Ice, CFrame.Angles(math.rad((i - 2) * 14), math.pi / 4, math.rad((2 - i) * 10)))
 end
end

-- A crystal shaft with a ridged tip made from two back-to-back wedges.
local function crystal(kit, base, height, width, color, tiltX, tiltZ)
 local rotation = CFrame.Angles(tiltX, math.pi / 4, tiltZ)
 local shaft = kit.box("CrystalShaft", Vector3.new(width, height, width), base + Vector3.new(0, height / 2, 0), color, Enum.Material.Glass, rotation)
 for _, half in {-1, 1} do
  local tip = kit.wedge("CrystalTip", Vector3.new(width, width * 1.2, width / 2), Vector3.zero, color:Lerp(WHITE, 0.3), Enum.Material.Glass)
  tip.CFrame = shaft.CFrame * CFrame.new(0, height / 2 + width * 0.6, half * width / 4) * CFrame.Angles(0, half == -1 and 0 or math.pi, 0)
 end
end

function Props.crystals(kit, p, c, v)
 kit.blob("RockBed", Vector3.new(22, 7, 18), p + Vector3.new(0, 1.5, 0), c.deep, Enum.Material.Slate)
 for i = 1, 3 do
  crystal(kit, p + Vector3.new((i - 2) * 6, 1, (i % 2) * 3), 14 + i * 5 + (v % 2) * 4, 5,
   i == 2 and c.accent or c.base:Lerp(c.accent, 0.5), math.rad((i - 2) * 12), math.rad((2 - i) * 9))
 end
end

function Props.geode(kit, p, c, v, side)
 kit.blob("GeodeShell", Vector3.new(16, 10, 14), p + Vector3.new(0, 3, 0), c.deep, Enum.Material.Slate)
 kit.blob("GeodeGlow", Vector3.new(9, 6, 8), p + Vector3.new(-side * 3.5, 5, 0), c.base, Enum.Material.Neon)
 crystal(kit, p + Vector3.new(side * 4, 4, -3), 9, 3.5, c.accent, 0.2, -0.3)
 crystal(kit, p + Vector3.new(side * 2, 4, 4), 7, 3, c.light, -0.25, 0.2)
end

function Props.cactus(kit, p, c, v, side)
 local green = Color3.fromRGB(78, 158, 104)
 local height = 20 + (v % 3) * 4
 kit.blob("SandMound", Vector3.new(12, 3, 12), p + Vector3.new(0, 0.5, 0), c.base:Lerp(WHITE, 0.2), Enum.Material.Sand)
 kit.cylinder("Cactus", height, 5, p + Vector3.new(0, height / 2, 0), green)
 kit.ball("CactusTop", 5, p + Vector3.new(0, height, 0), green)
 for _, arm in {{side, 0.5, 8}, {-side, 0.35, 6}} do
  local direction, at, length = arm[1], arm[2], arm[3]
  kit.cylinder("Arm", 6, 3.4, p + Vector3.new(direction * 4, height * at, 0), green, nil, CFrame.identity)
  kit.cylinder("ArmUp", length, 3.4, p + Vector3.new(direction * 7, height * at + length / 2, 0), green)
  kit.ball("ArmTop", 3.4, p + Vector3.new(direction * 7, height * at + length, 0), green)
 end
 kit.blob("CactusFlower", Vector3.new(4, 2, 4), p + Vector3.new(0, height + 2.4, 0), Color3.fromRGB(255, 120, 170))
end

function Props.mesa(kit, p, c, v)
 for layer = 1, 3 do
  local width = 24 - layer * 5
  kit.box("Sandstone", Vector3.new(width, 6, width * 0.8), p + Vector3.new(0, layer * 6 - 3, 0),
   c.base:Lerp(c.dark, (layer % 2) * 0.35), Enum.Material.Sandstone, CFrame.Angles(0, v * 0.4 + layer * 0.2, 0))
 end
end

function Props.dunes(kit, p, c, v)
 kit.blob("Dune", Vector3.new(30, 7, 18), p + Vector3.new(0, 1, 0), c.base:Lerp(WHITE, 0.15), Enum.Material.Sand)
 kit.blob("Dune", Vector3.new(18, 5, 14), p + Vector3.new(8, 1, 8), c.accent, Enum.Material.Sand)
 kit.box("Rock", Vector3.new(4, 3, 4), p + Vector3.new(-9, 1.5, -6), c.dark, Enum.Material.Slate, CFrame.Angles(0.3, v, 0.2))
end

function Props.lollipop(kit, p, c, v)
 local swirl = ({Color3.fromRGB(247, 83, 155), Color3.fromRGB(255, 160, 60), Color3.fromRGB(150, 110, 245)})[v % 3 + 1]
 local height = 20 + (v % 2) * 6
 kit.cylinder("Stick", height, 1.6, p + Vector3.new(0, height / 2, 0), WHITE)
 -- Concentric rings on a disc that faces the tee; inner rings stand proud on both faces.
 for ring, diameter in {16, 12, 8, 4} do
  kit.cylinder("Candy", 2.4 + ring * 0.08, diameter, p + Vector3.new(0, height + 7, 0), ring % 2 == 1 and swirl or WHITE, nil, FACE_TEE)
 end
end

function Props.cake(kit, p, c, v, side)
 local sponge = Color3.fromRGB(246, 196, 120)
 local frosting = ({Color3.fromRGB(255, 150, 190), Color3.fromRGB(150, 110, 70), Color3.fromRGB(170, 230, 255)})[v % 3 + 1]
 -- Wedges laid flat (rotated about Z) stack into a layered slice.
 local yaw = CFrame.Angles(0, side == 1 and 0 or math.pi, 0)
 local flat = yaw * CFrame.Angles(0, 0, math.pi / 2)
 local y = 0
 for _, layer in {{3.5, sponge}, {1.2, CREAM}, {3.5, sponge}, {1.4, frosting}} do
  kit.wedge("CakeLayer", Vector3.new(layer[1], 14, 16), p + Vector3.new(0, y + layer[1] / 2, 0), layer[2], nil, flat)
  y += layer[1]
 end
 kit.ball("Cherry", 3, p + yaw:VectorToWorldSpace(Vector3.new(2.3, 0, 2.7)) + Vector3.new(0, y + 1.3, 0), Color3.fromRGB(220, 30, 60))
end

function Props.gumdrops(kit, p, c, v)
 local colors = {Color3.fromRGB(255, 120, 170), Color3.fromRGB(140, 225, 255), Color3.fromRGB(190, 150, 255), Color3.fromRGB(255, 215, 100)}
 for i = 1, 3 do
  local angle = i * 2.1 + v
  local size = 5 + (i % 2) * 2
  kit.blob("Gumdrop", Vector3.new(size, size * 1.15, size), p + Vector3.new(math.cos(angle) * 5, size * 0.45, math.sin(angle) * 5), colors[(i + v) % 4 + 1])
 end
end

function Props.candyCane(kit, p, c, v, side)
 local red = Color3.fromRGB(235, 50, 80)
 for band = 0, 5 do
  kit.cylinder("CaneStripe", 3, 2.6, p + Vector3.new(0, band * 3 + 1.5, 0), band % 2 == 0 and red or WHITE)
 end
 -- The hook curls toward the runway along a half circle.
 local top = p + Vector3.new(0, 18, 0)
 local center = top + Vector3.new(-side * 3, 0, 0)
 local previous = top
 for step = 1, 5 do
  local angle = step / 5 * math.pi
  local point = center + Vector3.new(side * 3 * math.cos(angle), 3.2 * math.sin(angle), 0)
  kit.span("CaneHook", previous, point, 2.6, 2.6, step % 2 == 0 and red or WHITE)
  previous = point
 end
end

function Props.jungleTree(kit, p, c, v, side)
 local s = 1 + (v % 3) * 0.15
 kit.cylinder("Trunk", 26 * s, 3.6 * s, p + Vector3.new(0, 13 * s, 0), Color3.fromRGB(96, 70, 50), Enum.Material.Wood)
 kit.blob("Canopy", Vector3.new(26, 12, 24) * s, p + Vector3.new(0, 27 * s, 0), c.base)
 kit.blob("Canopy", Vector3.new(18, 10, 18) * s, p + Vector3.new(-side * 6 * s, 31 * s, 4 * s), c.base:Lerp(c.accent, 0.4))
 kit.blob("Canopy", Vector3.new(16, 9, 16) * s, p + Vector3.new(side * 5 * s, 30 * s, -6 * s), c.dark)
 for i = 1, 3 do
  kit.box("Vine", Vector3.new(0.5, 9 * s, 0.5), p + Vector3.new(((i - 2) * 6 - side * 4) * s, 19 * s, (i % 2) * 5 * s), c.accent:Lerp(c.base, 0.4))
 end
end

function Props.fern(kit, p, c, v)
 local root = p + Vector3.new(0, 0.5, 0)
 for i = 1, 6 do
  local angle = i / 6 * math.pi * 2 + v
  local tip = p + Vector3.new(math.cos(angle) * 7, 5 + (i % 2) * 1.5, math.sin(angle) * 7)
  kit.span("Frond", root, tip, 2.6, 0.4, i % 2 == 0 and c.base or c.base:Lerp(c.accent, 0.4))
 end
end

function Props.emberSpire(kit, p, c, v)
 kit.blob("RockBase", Vector3.new(18, 6, 16), p + Vector3.new(0, 1.5, 0), c.deep, Enum.Material.Basalt)
 for i = 1, 3 do
  local height = 12 + i * 6 + (v % 2) * 4
  local position = p + Vector3.new((i - 2) * 5, height / 2, (i % 2) * 3)
  local rotation = CFrame.Angles(math.rad((i - 2) * 8), i, math.rad((2 - i) * 8))
  kit.box("Spire", Vector3.new(5, height, 5), position, c.dark, Enum.Material.Basalt, rotation)
  kit.box("EmberVein", Vector3.new(5.1, height * 0.7, 0.6), position, c.accent, Enum.Material.Neon, rotation)
 end
end

function Props.lavaRock(kit, p, c, v)
 kit.blob("LavaPool", Vector3.new(18, 0.6, 14), p + Vector3.new(0, 0.2, 0), c.accent, Enum.Material.Neon)
 kit.blob("Rock", Vector3.new(9, 7, 8), p + Vector3.new(6, 2.5, -4), c.deep, Enum.Material.Basalt)
 kit.blob("Rock", Vector3.new(6, 5, 6), p + Vector3.new(-6, 2, 5), c.dark, Enum.Material.Basalt)
end

function Props.beacon(kit, p, c, v)
 kit.box("TowerFoot", Vector3.new(14, 3, 14), p + Vector3.new(0, 1.5, 0), c.deep)
 kit.box("Tower", Vector3.new(7, 26, 7), p + Vector3.new(0, 16, 0), c.dark)
 for level = 1, 3 do
  kit.box("NeonBand", Vector3.new(7.6, 1, 7.6), p + Vector3.new(0, 6 + level * 6, 0), c.accent, Enum.Material.Neon)
 end
 kit.box("FloatingCore", Vector3.new(7, 7, 7), p + Vector3.new(0, 36, 0), c.accent, Enum.Material.Neon, CFrame.Angles(0.6, 0.8 + v, 0.6))
end

function Props.neonArch(kit, p, c, v)
 for _, z in {-7, 7} do
  kit.box("ArchPost", Vector3.new(3, 20, 3), p + Vector3.new(0, 10, z), c.dark)
  kit.box("ArchGlow", Vector3.new(3.3, 18, 0.6), p + Vector3.new(0, 10, z), c.accent, Enum.Material.Neon)
 end
 kit.box("ArchTop", Vector3.new(3, 3, 17), p + Vector3.new(0, 21.5, 0), c.dark)
 kit.box("ArchTopGlow", Vector3.new(3.3, 0.6, 17), p + Vector3.new(0, 21.5, 0), c.accent, Enum.Material.Neon)
end

function Props.cloud(kit, p, c, v)
 local y = 14 + (v % 3) * 5
 kit.blob("CloudBase", Vector3.new(14, 6, 28), p + Vector3.new(0, y - 2, 0), c.accent)
 for i = 1, 4 do
  kit.blob("Cloud", Vector3.new(12 + (i % 2) * 4, 9 + (i % 2) * 3, 11), p + Vector3.new(0, y + (i % 2) * 2, (i - 2.5) * 6), WHITE)
 end
end

function Props.rainbow(kit, p, c, v)
 -- Concentric discs half-buried in the deck read as a rainbow facing the tee.
 local colors = {Color3.fromRGB(255, 96, 110), Color3.fromRGB(255, 170, 70), Color3.fromRGB(255, 230, 90),
  Color3.fromRGB(110, 220, 120), Color3.fromRGB(90, 170, 255), Color3.fromRGB(170, 120, 255)}
 for band, color in colors do
  kit.cylinder("RainbowBand", 1.6 + band * 0.06, 40 - band * 4, p, color, nil, FACE_TEE)
 end
 kit.cylinder("RainbowInner", 2.1, 15, p, WHITE, nil, FACE_TEE)
 for _, z in {-14, 14} do
  kit.blob("RainbowCloud", Vector3.new(10, 7, 12), p + Vector3.new(0, 2, z), WHITE)
 end
end

function Props.island(kit, p, c, v)
 local center = p + Vector3.new(0, 18 + (v % 2) * 6, 0)
 kit.blob("IslandRock", Vector3.new(16, 12, 16), center - Vector3.new(0, 4, 0), Color3.fromRGB(150, 120, 100))
 kit.blob("IslandGrass", Vector3.new(17, 3, 17), center + Vector3.new(0, 1.5, 0), Color3.fromRGB(110, 205, 120), Enum.Material.Grass)
 kit.cylinder("IslandTrunk", 5, 1.2, center + Vector3.new(2, 5, 1), Color3.fromRGB(122, 82, 52))
 kit.blob("IslandTree", Vector3.new(6, 5, 6), center + Vector3.new(2, 9, 1), Color3.fromRGB(90, 190, 110))
end

function Props.planet(kit, p, c, v)
 local colors = {c.accent, Color3.fromRGB(255, 190, 120), Color3.fromRGB(130, 220, 255)}
 local center = p + Vector3.new(0, 20 + (v % 3) * 4, 0)
 local diameter = 12 + (v % 2) * 4
 kit.ball("Planet", diameter, center, colors[v % 3 + 1])
 kit.cylinder("PlanetRing", 0.4, diameter * 1.9, center, CREAM, nil, CFrame.Angles(0.35, v, 0) * CFrame.Angles(0, 0, math.pi / 2))
end

function Props.star(kit, p, c, v)
 local center = p + Vector3.new(0, 16 + (v % 3) * 6, 0)
 local gold = Color3.fromRGB(255, 226, 120)
 for ray = 0, 3 do
  kit.box("StarRay", Vector3.new(1.4, 12, 1.4), center, gold, Enum.Material.Neon, CFrame.Angles(0, 0, ray * math.pi / 4))
 end
 kit.ball("StarCore", 4, center, gold:Lerp(WHITE, 0.5), Enum.Material.Neon)
end

function Props.moon(kit, p, c, v, side)
 local center = p + Vector3.new(0, 14 + (v % 2) * 5, 0)
 local surface = Color3.fromRGB(226, 222, 240)
 kit.ball("Moon", 12, center, surface, Enum.Material.Slate)
 for i = 1, 3 do
  local angle = i * 2.3
  kit.ball("Crater", 2.5 + i * 0.5, center + Vector3.new(math.cos(angle) * 3, math.sin(angle) * 3, 5.2), surface:Lerp(BLACK, 0.2), Enum.Material.Slate)
 end
end

-- Small cheap clusters between hero props keep the decks from looking empty.
local function filler(kit, p, c, v)
 kit.blob("Shrub", Vector3.new(7, 4, 6), p + Vector3.new(0, 1.2, 0), v % 2 == 0 and c.light or c.dark)
 kit.blob("Shrub", Vector3.new(4, 3, 4), p + Vector3.new(3.5, 1, 2.5), c.accent)
end

-- Large, simple shapes on the outer ground give each theme a horizon.
local Backdrops = {}

function Backdrops.hills(kit, p, c, v)
 kit.blob("Hill", Vector3.new(70 + (v % 3) * 15, 26 + (v % 2) * 12, 80), p, c.base:Lerp(c.dark, (v % 3) * 0.2), Enum.Material.Grass)
end

function Backdrops.mountains(kit, p, c, v)
 local height = 60 + (v % 3) * 20
 kit.blob("Mountain", Vector3.new(80, height, 80), p, c.dark:Lerp(WHITE, 0.2))
 kit.blob("SnowCap", Vector3.new(44, height * 0.45, 44), p + Vector3.new(0, height * 0.3, 0), WHITE, Enum.Material.Snow)
end

function Backdrops.spires(kit, p, c, v)
 for i = 1, 2 do
  local height = 40 + ((v + i) % 3) * 22
  kit.box("CrystalSpire", Vector3.new(12, height, 12), p + Vector3.new((i - 1.5) * 18, height / 2, (i % 2) * 10),
   i == 1 and c.base or c.accent, Enum.Material.Glass, CFrame.Angles(0, math.pi / 4, math.rad((i - 1.5) * 10)))
 end
end

function Backdrops.mesas(kit, p, c, v)
 local height = 26 + (v % 3) * 10
 kit.box("Mesa", Vector3.new(60, height, 44), p + Vector3.new(0, height / 2, 0), c.base:Lerp(c.dark, 0.3), Enum.Material.Sandstone, CFrame.Angles(0, v * 0.5, 0))
 kit.box("MesaBand", Vector3.new(61, 4, 45), p + Vector3.new(0, height * 0.6, 0), c.accent, Enum.Material.Sandstone, CFrame.Angles(0, v * 0.5, 0))
end

function Backdrops.candyHills(kit, p, c, v)
 local colors = {Color3.fromRGB(255, 175, 210), Color3.fromRGB(175, 235, 225), Color3.fromRGB(205, 185, 250)}
 kit.blob("CandyHill", Vector3.new(70, 34 + (v % 2) * 14, 70), p, colors[v % 3 + 1])
 kit.blob("Frosting", Vector3.new(40, 12, 40), p + Vector3.new(0, 14 + (v % 2) * 7, 0), WHITE)
end

function Backdrops.canopy(kit, p, c, v)
 kit.blob("Canopy", Vector3.new(60, 40 + (v % 3) * 10, 60), p + Vector3.new(0, 14, 0), c.dark:Lerp(c.base, (v % 2) * 0.5), Enum.Material.LeafyGrass)
end

function Backdrops.volcanoes(kit, p, c, v)
 local height = 50 + (v % 2) * 20
 kit.blob("Volcano", Vector3.new(90, height, 90), p, c.deep, Enum.Material.Basalt)
 kit.blob("VolcanoGlow", Vector3.new(22, 10, 22), p + Vector3.new(0, height / 2 - 3, 0), c.accent, Enum.Material.Neon)
end

function Backdrops.towers(kit, p, c, v)
 local height = 60 + (v % 3) * 25
 kit.box("Tower", Vector3.new(16, height, 16), p + Vector3.new(0, height / 2, 0), c.deep)
 for band = 1, 2 do
  kit.box("TowerBand", Vector3.new(16.6, 1.5, 16.6), p + Vector3.new(0, height * band / 3, 0), c.accent, Enum.Material.Neon)
 end
end

function Backdrops.bigClouds(kit, p, c, v)
 local center = p + Vector3.new(0, 20 + (v % 3) * 12, 0)
 kit.blob("BigCloud", Vector3.new(60, 24, 50), center, WHITE)
 kit.blob("BigCloud", Vector3.new(36, 20, 34), center + Vector3.new(14, 10, 8), WHITE)
end

function Backdrops.planets(kit, p, c, v)
 local diameter = 36 + (v % 3) * 12
 local center = p + Vector3.new(0, 50 + (v % 2) * 30, 0)
 kit.ball("BigPlanet", diameter, center, ({c.accent, c.base, Color3.fromRGB(255, 190, 140)})[v % 3 + 1])
 if v % 2 == 0 then
  kit.cylinder("BigPlanetRing", 0.6, diameter * 1.8, center, CREAM, nil, CFrame.Angles(0.3, 0, 0) * CFrame.Angles(0, 0, math.pi / 2))
 end
end

-- Walls, raised decks, and outer ground along one stretch of runway.
local function buildSides(kit, config, runwayWidth, startDistance, length, c, deckMaterial, withTiles, tileOverride)
 local centerZ = -(startDistance + length / 2)
 local height, thickness = config.wallHeight, config.wallThickness
 local tileColor = tileOverride or c.base:Lerp(WHITE, 0.45)
 for _, side in {-1, 1} do
  local innerX = side * runwayWidth / 2
  local wallX = side * (runwayWidth / 2 + thickness / 2)
  kit.box("Wall", Vector3.new(thickness, height + 8, length), Vector3.new(wallX, (height - 8) / 2, centerZ), c.base)
  if withTiles then
   -- Two rows of offset tiles make the checkerboard on the lane-facing side.
   for row = 0, 1 do
    local tile = 0
    for d = 0, length - 0.01, config.wallTileLength do
     if (tile + row) % 2 == 0 then
      local tileLength = math.min(config.wallTileLength, length - d)
      kit.box("WallTile", Vector3.new(0.3, height / 2, tileLength),
       Vector3.new(innerX - side * 0.15, (row + 0.5) * height / 2, -(startDistance + d + tileLength / 2)), tileColor)
     end
     tile += 1
    end
   end
  end
  kit.cylinder("WallCap", length, thickness + 1.2, Vector3.new(wallX, height, centerZ), CREAM, nil, CFrame.Angles(0, math.pi / 2, 0))
  kit.box("Skirting", Vector3.new(0.5, 0.8, length), Vector3.new(innerX - side * 0.25, 0.4, centerZ), c.dark)
  local deckX = side * (runwayWidth / 2 + thickness + config.deckWidth / 2)
  kit.box("Deck", Vector3.new(config.deckWidth, height + 8, length), Vector3.new(deckX, (height - 8) / 2, centerZ),
   c.base:Lerp(c.accent, 0.25), deckMaterial)
  local outerX = side * (runwayWidth / 2 + thickness + config.deckWidth + config.outerGroundWidth / 2)
  kit.box("OuterGround", Vector3.new(config.outerGroundWidth, 8, length), Vector3.new(outerX, height - 7, centerZ),
   c.base:Lerp(BLACK, 0.15), deckMaterial)
 end
end

local function buildFloor(kit, section, runwayWidth, length, c)
 local startDistance = section.startDistance
 local centerZ = -(startDistance + length / 2)
 for _, side in {-1, 1} do
  kit.inlay("EdgeStripe", Vector3.new(4, 0.03, length), Vector3.new(side * (runwayWidth / 2 - 2), 0.015, centerZ), c.accent)
  kit.inlay("EdgeLine", Vector3.new(0.8, 0.03, length), Vector3.new(side * (runwayWidth / 2 - 6), 0.015, centerZ), CREAM)
 end
 -- A checkered band marks where each theme begins.
 local cell = 8
 for row = 0, 1 do
  for column = 0, runwayWidth / cell - 1 do
   if (row + column) % 2 == 0 then
    kit.inlay("Threshold", Vector3.new(cell, 0.04, cell),
     Vector3.new(-runwayWidth / 2 + (column + 0.5) * cell, 0.02, -(startDistance + (row + 0.5) * cell)), CREAM)
   end
  end
 end
 if section.floorGrid then
  for d = 20, length - 1, 20 do
   kit.inlay("GridLine", Vector3.new(runwayWidth - 12, 0.03, 0.4), Vector3.new(0, 0.015, -(startDistance + d)), c.accent, Enum.Material.Neon)
  end
  for _, x in {-40, 0, 40} do
   kit.inlay("GridLine", Vector3.new(0.4, 0.03, length), Vector3.new(x, 0.015, centerZ), c.accent, Enum.Material.Neon)
  end
 end
 if section.floorCracks then
  -- Short zigzag cracks of glowing lava, spread deterministically across the floor.
  for d = 18, length - 18, 26 do
   local index = math.floor(d / 26)
   local x = ((index * 37) % 120) - 60
   local z = -(startDistance + d)
   local a = Vector3.new(x - 12, 0.02, z + 8)
   local b = Vector3.new(x + ((index % 2) * 2 - 1) * 4, 0.02, z)
   local e = Vector3.new(x + 14, 0.02, z - 10)
   kit.span("LavaCrack", a, b, 1.3, 0.03, c.accent, Enum.Material.Neon).CastShadow = false
   kit.span("LavaCrack", b, e, 0.9, 0.03, c.accent, Enum.Material.Neon).CastShadow = false
  end
 end
end

-- Each prop is built at its authored size in its own Model, then scaled about its
-- base so props read clearly over the walls.
local function placeProp(theme, frame, name, position, scale, build)
 local model = Instance.new("Model")
 model.Name = name
 model.Parent = theme
 build(newKit(model, frame))
 model.WorldPivot = frame * CFrame.new(position)
 model:ScaleTo(scale)
end

-- Imported mesh props (Blender models in ServerStorage.RunwayAssets, managed in Studio,
-- not Rojo). A prop with a template uses it; otherwise its primitive builder is the fallback.
--   colors(c, variant) maps each MeshPart name to its tint for the section's palette.
--   materials maps MeshPart names to a material (e.g. Neon for glowing parts).
--   faceTee: true lets the prop face the tee or turn a half turn (symmetric fronts);
--     "exact" keeps its authored front toward the tee (yawOffset corrects it if needed).
--   lift raises a floating prop above the deck, in authored studs before scaling.
local NEON = Enum.Material.Neon
local MESH_PROPS = {
 tree = {template = "MeadowTree", colors = function(c)
  return {TreeTrunk = BARK, TreeLeaves = c.base, TreeLeavesTop = c.base:Lerp(c.accent, 0.55)}
 end},
 jungleTree = {template = "MeadowTree", colors = function(c)
  return {TreeTrunk = BARK:Lerp(BLACK, 0.2), TreeLeaves = c.base, TreeLeavesTop = c.base:Lerp(c.accent, 0.45)}
 end},
 mushroom = {template = "Mushroom", colors = function(c)
  return {MushroomStem = CREAM, MushroomGills = CREAM:Lerp(BARK, 0.25), MushroomCap = Color3.fromRGB(235, 70, 85),
   MushroomSpots = WHITE, MushroomGrass = c.base:Lerp(c.dark, 0.3)}
 end},
 flowers = {template = "FlowerPatch", colors = function(c)
  return {FlowerBush = c.dark, FlowerStems = c.base:Lerp(c.dark, 0.4), FlowerPetalsA = Color3.fromRGB(255, 138, 178),
   FlowerPetalsB = Color3.fromRGB(255, 248, 232), FlowerCenters = Color3.fromRGB(255, 196, 60)}
 end},
 fern = {template = "Fern", colors = function(c)
  return {FernFronds = c.base, FernFrondsLight = c.base:Lerp(c.accent, 0.4)}
 end},
 -- Fillers: small clusters between hero props in every section.
 bush = {template = "Bush", colors = function(c, v)
  local leaves = v % 2 == 0 and c.base or c.base:Lerp(c.dark, 0.35)
  return {BushLeaves = leaves, BushLeavesTop = leaves:Lerp(c.accent, 0.5)}
 end},
 rock = {template = "Rock", colors = function(c)
  return {RockStone = STONE:Lerp(c.dark, 0.3), RockMoss = c.base:Lerp(c.accent, 0.35)}
 end},
 -- Candy Crossing.
 lollipop = {template = "Lollipop", faceTee = true, colors = function(c, v)
  return {LollipopStick = WHITE, LollipopCandy = CANDY[v % #CANDY + 1], LollipopSwirl = WHITE,
   LollipopBow = CANDY[(v + 1) % #CANDY + 1]:Lerp(WHITE, 0.35)}
 end},
 cake = {template = "Cake", colors = function(c, v)
  return {CakeSponge = Color3.fromRGB(246, 200, 125), CakeCream = CREAM,
   CakeFrosting = FROSTING[v % #FROSTING + 1], CakeCherry = Color3.fromRGB(220, 30, 60)}
 end},
 gumdrops = {template = "Gumdrops", colors = function(c, v)
  return {GumdropA = CANDY[v % #CANDY + 1], GumdropB = Color3.fromRGB(140, 225, 205), GumdropC = Color3.fromRGB(190, 150, 255)}
 end},
 candyCane = {template = "CandyCane", colors = function()
  return {CandyCaneBody = WHITE, CandyCaneStripe = Color3.fromRGB(235, 50, 80)}
 end},
 -- Frost Pass.
 pine = {template = "Pine", colors = function(c)
  return {PineTrunk = BARK, PineNeedles = Color3.fromRGB(35, 105, 90):Lerp(c.base, 0.15), PineSnow = WHITE}
 end},
 -- Authored facing Blender -Y, which imports facing downfield; a half turn faces the tee.
 snowman = {template = "Snowman", faceTee = "exact", yawOffset = math.pi, colors = function()
  return {SnowmanBody = Color3.fromRGB(240, 248, 255), SnowmanCoal = Color3.fromRGB(30, 30, 35),
   SnowmanNose = Color3.fromRGB(255, 140, 50), SnowmanArms = Color3.fromRGB(90, 60, 35),
   SnowmanHat = Color3.fromRGB(40, 40, 55), SnowmanScarf = Color3.fromRGB(220, 45, 65)}
 end},
 iceShards = {template = "Ice", colors = function(c)
  return {IceCrystals = c.base:Lerp(WHITE, 0.35), IceSnow = WHITE}
 end},
 -- Crystal Ridge.
 crystals = {template = "Crystal", colors = function(c)
  return {CrystalRock = c.deep, CrystalGemsA = c.base:Lerp(c.accent, 0.3), CrystalGemsB = c.accent}
 end},
 geode = {template = "Geode", materials = {GeodeCrystals = NEON}, colors = function(c)
  return {GeodeShell = STONE:Lerp(c.dark, 0.4), GeodeCrystals = c.base}
 end},
 -- Golden Dunes.
 cactus = {template = "Cactus", colors = function(c)
  return {CactusBody = Color3.fromRGB(78, 158, 104), CactusFlower = Color3.fromRGB(255, 120, 170), CactusSand = c.base:Lerp(WHITE, 0.2)}
 end},
 mesa = {template = "Mesa", colors = function(c)
  return {MesaRockA = Color3.fromRGB(205, 120, 75), MesaRockB = c.base}
 end},
 dunes = {template = "Dune", colors = function(c)
  return {DuneSand = c.base:Lerp(WHITE, 0.15), DuneRock = c.dark}
 end},
 -- Ember Canyon.
 emberSpire = {template = "Spire", materials = {SpireGlow = NEON}, colors = function(c)
  return {SpireRock = c.deep, SpireGlow = c.accent}
 end},
 lavaRock = {template = "LavaRock", materials = {LavaRockGlow = NEON}, colors = function(c)
  return {LavaRockStone = c.deep, LavaRockGlow = c.accent}
 end},
 -- Neon Circuit.
 beacon = {template = "Beacon", materials = {BeaconGlow = NEON}, colors = function(c)
  return {BeaconBody = c.deep, BeaconGlow = c.accent}
 end},
 neonArch = {template = "Arch", faceTee = true, materials = {ArchGlow = NEON}, colors = function(c)
  return {ArchBody = c.deep, ArchBase = c.dark, ArchGlow = c.accent}
 end},
 -- Skyway.
 cloud = {template = "Cloud", lift = 8, colors = function(c)
  return {CloudPuff = WHITE, CloudShade = c.base:Lerp(WHITE, 0.45)}
 end},
 rainbow = {template = "Rainbow", faceTee = true, colors = function()
  return {RainbowBand1 = Color3.fromRGB(255, 96, 110), RainbowBand2 = Color3.fromRGB(255, 170, 70),
   RainbowBand3 = Color3.fromRGB(255, 230, 90), RainbowBand4 = Color3.fromRGB(110, 220, 120),
   RainbowBand5 = Color3.fromRGB(90, 170, 255), RainbowBand6 = Color3.fromRGB(170, 120, 255), RainbowCloud = WHITE}
 end},
 island = {template = "Island", lift = 9, colors = function()
  return {IslandRock = Color3.fromRGB(150, 120, 100), IslandGrass = Color3.fromRGB(110, 205, 120),
   IslandTrunk = BARK, IslandLeaves = Color3.fromRGB(90, 190, 110)}
 end},
 -- Starlight Finish.
 planet = {template = "Planet", lift = 9, colors = function(c, v)
  local body = ({c.accent, Color3.fromRGB(255, 190, 120), Color3.fromRGB(130, 220, 255)})[v % 3 + 1]
  return {PlanetBody = body, PlanetBands = body:Lerp(BLACK, 0.2), PlanetRing = CREAM}
 end},
 star = {template = "Star", faceTee = true, lift = 8, materials = {StarBody = NEON}, colors = function()
  return {StarBody = Color3.fromRGB(255, 214, 90)}
 end},
 moon = {template = "Moon", lift = 7, colors = function()
  return {MoonSurface = Color3.fromRGB(226, 222, 240)}
 end},
}

-- Backdrops: large shapes on the outer ground, mostly prop meshes at a much bigger scale.
local BACKDROP_MESHES = {
 hills = {template = "Hill", scale = 4, colors = function(c, v)
  local grass = c.base:Lerp(c.dark, (v % 3) * 0.2)
  return {HillGrass = grass, HillGrassTop = grass:Lerp(c.accent, 0.4)}
 end},
 mountains = {template = "Mountain", scale = 5, colors = function(c)
  return {MountainRock = c.dark:Lerp(WHITE, 0.2), MountainSnow = WHITE}
 end},
 spires = {template = "Crystal", scale = 3.5, colors = MESH_PROPS.crystals.colors},
 mesas = {template = "Mesa", scale = 3.5, colors = MESH_PROPS.mesa.colors},
 candyHills = {template = "Hill", scale = 4, colors = function(c, v)
  local hill = ({Color3.fromRGB(255, 175, 210), Color3.fromRGB(175, 235, 225), Color3.fromRGB(205, 185, 250)})[v % 3 + 1]
  return {HillGrass = hill, HillGrassTop = WHITE}
 end},
 canopy = {template = "MeadowTree", scale = 2.6, colors = MESH_PROPS.jungleTree.colors},
 volcanoes = {template = "Volcano", scale = 5, materials = {VolcanoGlow = NEON}, colors = function(c)
  return {VolcanoRock = c.deep, VolcanoGlow = c.accent}
 end},
 towers = {template = "Beacon", scale = 3.5, materials = MESH_PROPS.beacon.materials, colors = MESH_PROPS.beacon.colors},
 bigClouds = {template = "Cloud", scale = 3.5, lift = 6, colors = MESH_PROPS.cloud.colors},
 planets = {template = "Planet", scale = 3, lift = 14, colors = MESH_PROPS.planet.colors},
}

local function getTemplate(definition)
 local folder = ServerStorage:FindFirstChild("RunwayAssets")
 local template = definition and folder and folder:FindFirstChild(definition.template)
 if template and template:IsA("Model") then return template end
 return nil
end

local function placeMesh(theme, frame, template, definition, c, position, scale, variant)
 local model = template:Clone()
 local colors = definition.colors(c, variant)
 local materials = definition.materials or {}
 for _, part in model:GetDescendants() do
  if part:IsA("BasePart") then
   part.Anchored = true
   part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
   part.Color = colors[part.Name] or part.Color
   part.Material = materials[part.Name] or part.Material
  end
 end
 -- Vary heading and size so repeated meshes do not look stamped. Props that must face
 -- the tee (e.g. a lollipop's swirl) only turn slightly, or a half turn.
 local jitter = ((variant % 3) - 1) * 0.2
 local yaw = variant * 1.9
 if definition.faceTee == "exact" then
  yaw = (definition.yawOffset or 0) + jitter
 elseif definition.faceTee then
  yaw = (variant % 2) * math.pi + jitter
 end
 local finalScale = scale * (0.9 + (variant % 3) * 0.1)
 local lift = (definition.lift or 0) * finalScale
 model:PivotTo(frame * CFrame.new(position + Vector3.new(0, lift, 0)) * CFrame.Angles(0, yaw, 0))
 model:ScaleTo(model:GetScale() * finalScale)
 model.Parent = theme
end

local function buildScenery(theme, frame, kit, config, section, runwayWidth, length, c)
 local deckInner = runwayWidth / 2 + config.wallThickness
 local deckTop = config.wallHeight
 local outerTop = config.wallHeight - 3
 local count = math.max(1, math.floor(length / config.propSpacing))
 local backdropCount = math.max(1, math.floor(length / config.backdropSpacing))
 for _, side in {-1, 1} do
  for index = 1, count do
   -- Stagger the two sides so props alternate rather than mirror each other.
   local d = section.startDistance + (index - 0.5) * length / count + side * config.propSpacing / 4
   local variant = index + (side == 1 and 1 or 0) + section.order
   local kind = section.props[(variant - 1) % #section.props + 1]
   local position = Vector3.new(side * (deckInner + (index % 2 == 0 and 16 or 44)), deckTop, -d)
   local definition = MESH_PROPS[kind]
   local template = getTemplate(definition)
   if template then
    placeMesh(theme, frame, template, definition, c, position, config.propScale, variant)
   else
    placeProp(theme, frame, kind, position, config.propScale, function(propKit)
     Props[kind](propKit, position, c, variant, side)
    end)
   end
   local fillerPosition = Vector3.new(side * (deckInner + 30), deckTop, -(d + length / count / 2))
   local fillers = section.fillers or DEFAULT_FILLERS
   local fillerDefinition = MESH_PROPS[fillers[variant % #fillers + 1]]
   local fillerTemplate = getTemplate(fillerDefinition)
   if fillerTemplate then
    placeMesh(theme, frame, fillerTemplate, fillerDefinition, c, fillerPosition, config.fillerScale, variant)
   else
    placeProp(theme, frame, "Filler", fillerPosition, config.fillerScale, function(propKit)
     filler(propKit, fillerPosition, c, variant)
    end)
   end
  end
  local backdropDefinition = BACKDROP_MESHES[section.backdrop]
  local backdropTemplate = getTemplate(backdropDefinition)
  for index = 1, backdropCount do
   local d = section.startDistance + (index - 0.5) * length / backdropCount + side * config.backdropSpacing / 3
   local position = Vector3.new(side * (deckInner + config.deckWidth + 50 + (index % 3) * 35), outerTop, -d)
   local variant = index + section.order
   if backdropTemplate then
    placeMesh(theme, frame, backdropTemplate, backdropDefinition, c, position, backdropDefinition.scale, variant)
   else
    Backdrops[section.backdrop](kit, position, c, variant, side)
   end
  end
 end
end

-- Floating section title: text only, on a fully transparent anchor with no collision,
-- so there is no physical sign for the ball to pass through. It faces the batting tee.
local function buildTitle(kit, distance, title, c)
 local anchor = kit.box("SectionTitle", Vector3.new(140, 14, 0.2), Vector3.new(0, TITLE_HEIGHT, -distance), WHITE)
 anchor.Transparency = 1
 anchor.CastShadow = false
 local gui = Instance.new("SurfaceGui")
 gui.Name = "Title"
 gui.Face = Enum.NormalId.Back -- Local +Z points back toward the tee.
 gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
 gui.PixelsPerStud = 12
 gui.LightInfluence = 0
 gui.Parent = anchor
 local label = Instance.new("TextLabel")
 label.Name = "Text"
 label.Size = UDim2.fromScale(1, 1)
 label.BackgroundTransparency = 1
 label.Font = Enum.Font.GothamBlack
 label.TextScaled = true
 label.TextColor3 = WHITE
 label.Text = title
 label.Parent = gui
 local stroke = Instance.new("UIStroke")
 stroke.Thickness, stroke.Color = 6, c.deep:Lerp(BLACK, 0.35)
 stroke.Parent = label
end

-- A faint caustic-style overlay on the floor's top face. The ground parts keep
-- their fixed physics; a Texture is visual only.
local function addFloorPattern(groundPart)
 local texture = Instance.new("Texture")
 texture.Name = "FloorPattern"
 texture.Texture = FLOOR_PATTERN
 texture.Face = Enum.NormalId.Top
 texture.StudsPerTileU, texture.StudsPerTileV = 40, 40
 texture.Color3 = WHITE
 texture.Transparency = 0.85
 texture.Parent = groundPart
end

function RunwayDecor.Build(field, world, frame)
 local config = world.runway
 local runwayWidth = config.width
 local decor = Instance.new("Folder")
 decor.Name = "RunwayThemes"
 decor.Parent = field
 for _, groundPart in field.Ground:GetChildren() do
  local section = groundPart:IsA("BasePart") and Field.GetById(groundPart:GetAttribute("SectionId"), world)
  if section and section.floorPattern then addFloorPattern(groundPart) end
 end
 for _, section in world.sections do
  local theme = Instance.new("Model")
  theme.Name = section.id
  theme:SetAttribute("SectionId", section.id)
  theme.Parent = decor
  local kit = newKit(theme, frame)
  local c = palette(section)
  local length = section.endDistance - section.startDistance
  buildSides(kit, config, runwayWidth, section.startDistance, length, c, section.deckMaterial, true, section.wallTileColor)
  buildFloor(kit, section, runwayWidth, length, c)
  buildScenery(theme, frame, kit, config, section, runwayWidth, length, c)
  -- The first title floats a little downfield so it is not directly over the batter.
  local titleDistance = section.order == 1 and 60 or section.startDistance
  buildTitle(kit, titleDistance, string.upper(section.displayName), c)
 end
 -- Runout: plain walls beyond the endpoint, plus a checkered finish line and title.
 local finish = Instance.new("Model")
 finish.Name = "Finish"
 finish.Parent = decor
 local kit = newKit(finish, frame)
 local last = palette(world.sections[#world.sections])
 local runout = {base = last.dark, accent = last.accent, dark = last.deep, deep = last.deep:Lerp(BLACK, 0.4), light = last.base, cream = last.cream}
 buildSides(kit, config, runwayWidth, world.endDistance, world.runoutDistance, runout, world.sections[#world.sections].deckMaterial, false)
 local cell = 8
 for row = 0, 2 do
  for column = 0, runwayWidth / cell - 1 do
   kit.inlay("FinishLine", Vector3.new(cell, 0.04, cell),
    Vector3.new(-runwayWidth / 2 + (column + 0.5) * cell, 0.02, -(world.endDistance + (row + 0.5) * cell)),
    (row + column) % 2 == 0 and WHITE or Color3.fromRGB(30, 30, 40))
  end
 end
 buildTitle(kit, world.endDistance, string.upper(world.displayName) .. " FINISH", last)
end

-- Places one mesh prop or backdrop by kind (MESH_PROPS / BACKDROP_MESHES) away from a runway,
-- e.g. around a hub (HubDecor). colors = {color, accent} like a section's palette; variant varies
-- heading and size. Returns false when the template is missing from RunwayAssets.
function RunwayDecor.PlaceMesh(parent, frame, kind, position, scale, variant, colors)
 local definition = MESH_PROPS[kind] or BACKDROP_MESHES[kind]
 local template = getTemplate(definition)
 if not template then return false end
 local c = palette({color = colors.color, accent = colors.accent})
 placeMesh(parent, frame, template, definition, c, position, scale * (definition.scale or 1), variant)
 return true
end

return RunwayDecor
