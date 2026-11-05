-- Cosmetic scenery for themed runways: walls, decks, props, backdrops, section titles.
-- Every part is anchored with collision, touch, and query disabled, so nothing
-- here can affect ball flight, measured distance, rewards, or camera occlusion.
local ServerStorage = game:GetService("ServerStorage")
local Field = require(game:GetService("ReplicatedStorage"):WaitForChild("FieldConfig"))
local Portal = require(script.Parent:WaitForChild("WorldPortal"))
local RunwayDecor = {}

local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local CREAM = Color3.fromRGB(255, 246, 228)
local BARK = Color3.fromRGB(122, 82, 52)
local STONE = Color3.fromRGB(150, 145, 140)
-- World 2 materials of the ages.
local IVORY = Color3.fromRGB(238, 228, 200)
local SANDSTONE = Color3.fromRGB(222, 182, 118)
local GOLD = Color3.fromRGB(255, 198, 64)
local LAPIS = Color3.fromRGB(42, 82, 186)
local TURQUOISE = Color3.fromRGB(56, 170, 170)
local MARBLE = Color3.fromRGB(236, 236, 242)
local TERRACOTTA = Color3.fromRGB(204, 106, 60)
local STEEL = Color3.fromRGB(165, 172, 184)
local BRASS = Color3.fromRGB(222, 164, 72)
local COPPER = Color3.fromRGB(198, 108, 64)
-- World 3 materials of the future.
local COMPOSITE = Color3.fromRGB(240, 242, 246) -- white composite panels
local CHROME = Color3.fromRGB(196, 202, 214)
local GUNMETAL = Color3.fromRGB(62, 68, 80)
local CONCRETE = Color3.fromRGB(188, 190, 194)
local SOLAR = Color3.fromRGB(30, 52, 112) -- solar cells
local TINTED_GLASS = Color3.fromRGB(150, 214, 255)
local HAZARD_YELLOW = Color3.fromRGB(255, 200, 30)
local HAZARD_BLACK = Color3.fromRGB(28, 28, 32)
-- World 4 (Tiny Town): bright toy colours and everyday things.
local TOY_RED = Color3.fromRGB(232, 60, 54)
local TOY_YELLOW = Color3.fromRGB(255, 206, 44)
local TOY_BLUE = Color3.fromRGB(52, 122, 234)
local TOY_GREEN = Color3.fromRGB(66, 186, 90)
local TOY_ORANGE = Color3.fromRGB(255, 140, 40)
local TOYS = {TOY_RED, TOY_YELLOW, TOY_BLUE, TOY_GREEN}
local BEECH = Color3.fromRGB(228, 184, 128)
local BREAD = Color3.fromRGB(240, 198, 128)
local CRUST = Color3.fromRGB(172, 104, 52)
local WATER = Color3.fromRGB(150, 214, 255)
local INK = Color3.fromRGB(28, 24, 28)
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
local function buildSides(kit, config, runwayWidth, startDistance, length, c, deckMaterial, withTiles, tileOverride, deckColor)
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
   deckColor or c.base:Lerp(c.accent, 0.25), deckMaterial)
  local outerX = side * (runwayWidth / 2 + thickness + config.deckWidth + config.outerGroundWidth / 2)
  kit.box("OuterGround", Vector3.new(config.outerGroundWidth, 8, length), Vector3.new(outerX, height - 7, centerZ),
   (deckColor or c.base):Lerp(BLACK, 0.15), deckMaterial)
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
 if section.floorTiles then
  -- Thin grout lines in a square grid: tiles, flagstones, riveted plates.
  for d = 16, length - 1, 16 do
   kit.inlay("TileLine", Vector3.new(runwayWidth - 12, 0.03, 0.35), Vector3.new(0, 0.015, -(startDistance + d)), c.dark)
  end
  for x = -64, 64, 16 do
   kit.inlay("TileLine", Vector3.new(0.35, 0.03, length), Vector3.new(x, 0.015, centerZ), c.dark)
  end
 end
 if section.floorChecker then
  -- Big checks across the whole floor in the section's accent: a picnic blanket, a chessboard.
  local check = 20
  for row = 0, math.floor(length / check) - 1 do
   for column = 0, runwayWidth / check - 1 do
    if (row + column) % 2 == 1 then
     kit.inlay("Check", Vector3.new(check, 0.03, check),
      Vector3.new(-runwayWidth / 2 + (column + 0.5) * check, 0.012, -(startDistance + (row + 0.5) * check)), c.accent)
    end
   end
  end
 end
 if section.floorPlanks then
  for x = -72, 72, 6 do
   kit.inlay("PlankLine", Vector3.new(0.25, 0.03, length), Vector3.new(x, 0.015, centerZ), c.deep)
  end
 end
 if section.floorLanes then
  -- Road or launch-runway markings: a glowing centre line and dashed lane lines.
  kit.inlay("CenterLine", Vector3.new(1.2, 0.03, length), Vector3.new(0, 0.015, centerZ), c.accent, Enum.Material.Neon)
  for _, x in {-44, 44} do
   for d = 16, length - 14, 26 do
    kit.inlay("LaneDash", Vector3.new(0.9, 0.03, 12), Vector3.new(x, 0.015, -(startDistance + d + 6)), CREAM)
   end
  end
 end
 if section.floorHazard then
  -- Yellow and black warning bands along both edges.
  for _, side in {-1, 1} do
   local x = side * (runwayWidth / 2 - 11)
   kit.inlay("HazardBand", Vector3.new(6, 0.03, length), Vector3.new(x, 0.015, centerZ), HAZARD_YELLOW)
   for d = 3, length - 3, 5 do
    kit.box("HazardStripe", Vector3.new(1.1, 0.04, 6.4), Vector3.new(x, 0.02, -(startDistance + d)), HAZARD_BLACK, nil,
     CFrame.Angles(0, math.rad(45), 0)).CastShadow = false
   end
  end
 end
 if section.floorCraters then
  -- Crater rings scattered deterministically across the floor.
  for d = 30, length - 30, 46 do
   local index = math.floor(d / 46)
   local x = ((index * 53) % 112) - 56
   local size = 10 + (index % 3) * 7
   local z = -(startDistance + d)
   kit.cylinder("CraterRim", 0.03, size + 3.5, Vector3.new(x, 0.015, z), c.light).CastShadow = false
   kit.cylinder("Crater", 0.04, size, Vector3.new(x, 0.02, z), c.dark).CastShadow = false
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
--   transparency maps MeshPart names to a Transparency (e.g. glass you can see into).
--   fallback names the kind that stands in while this one's model is not imported yet (World 4's
--     props keep their placeholder look until then).
-- World 2's props come from tools/blender/runway_world2.py; Blender -Y faces downfield, so
-- props with a front use faceTee = "exact" with a half turn to face the tee.
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local FABRIC = Enum.Material.Fabric
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

 -- World 2: Prehistoric Valley.
 cycad = {template = "Cycad", colors = function(c)
  return {CycadTrunk = BARK, CycadFronds = c.base:Lerp(BLACK, 0.12), CycadFrondsLight = c.base:Lerp(c.accent, 0.35)}
 end},
 dinoNest = {template = "DinoNest", colors = function(c, v)
  local spots = ({Color3.fromRGB(80, 165, 135), Color3.fromRGB(105, 135, 220), Color3.fromRGB(220, 120, 90)})[v % 3 + 1]
  return {NestTwigs = BARK:Lerp(c.accent, 0.15), NestEggs = IVORY, NestSpots = spots}
 end},
 fossil = {template = "Fossil", colors = function()
  return {FossilRock = Color3.fromRGB(196, 160, 110), FossilBone = IVORY, FossilSockets = Color3.fromRGB(60, 44, 34)}
 end},
 -- Stone Age Camp.
 stoneHut = {template = "StoneHut", faceTee = "exact", yawOffset = math.pi, colors = function(c)
  return {HutStones = STONE:Lerp(c.base, 0.2), HutThatch = Color3.fromRGB(204, 162, 84), HutDoor = Color3.fromRGB(40, 28, 22),
   HutPoles = BARK}
 end},
 tuskArch = {template = "TuskArch", faceTee = true, colors = function(c)
  return {TuskIvory = IVORY, TuskBase = STONE:Lerp(c.dark, 0.3), TuskStrap = Color3.fromRGB(150, 80, 40)}
 end},
 campfire = {template = "Campfire", materials = {CampfireFlame = NEON}, colors = function(c)
  return {CampfireStones = STONE:Lerp(c.dark, 0.25), CampfireLogs = BARK, CampfireFlame = c.accent,
   CampfireMeat = Color3.fromRGB(150, 70, 40)}
 end},
 -- Pharaoh's Sands.
 obelisk = {template = "Obelisk", colors = function()
  return {ObeliskStone = SANDSTONE, ObeliskGold = GOLD, ObeliskGlyphs = LAPIS}
 end},
 sphinx = {template = "Sphinx", faceTee = "exact", yawOffset = math.pi, colors = function()
  return {SphinxStone = SANDSTONE, SphinxPlinth = SANDSTONE:Lerp(BLACK, 0.2), SphinxGold = GOLD, SphinxStripes = LAPIS}
 end},
 scarabPillar = {template = "ScarabPillar", faceTee = true, colors = function()
  return {PillarStone = SANDSTONE, PillarBands = TURQUOISE, PillarScarab = GOLD}
 end},
 -- Olympian Heights.
 greekColumn = {template = "GreekColumn", faceTee = true, colors = function()
  return {ColumnMarble = MARBLE, ColumnGold = GOLD, ColumnVine = Color3.fromRGB(90, 150, 80)}
 end},
 amphora = {template = "Amphora", colors = function()
  return {AmphoraClay = TERRACOTTA, AmphoraBands = Color3.fromRGB(35, 28, 26), AmphoraPlinth = MARBLE}
 end},
 heroStatue = {template = "HeroStatue", faceTee = "exact", yawOffset = math.pi, colors = function(c)
  return {StatueMarble = MARBLE, StatuePlinth = MARBLE:Lerp(c.accent, 0.2), StatueGold = GOLD}
 end},
 -- Viking Fjord.
 longship = {template = "Longship", colors = function(c)
  return {LongshipHull = BARK, LongshipSail = CREAM, LongshipStripes = c.accent, LongshipShieldsA = c.accent,
   LongshipShieldsB = GOLD, LongshipMetal = STEEL, LongshipTrim = GOLD}
 end},
 runeStone = {template = "RuneStone", faceTee = true, materials = {RuneStoneGlow = NEON}, colors = function(c)
  return {RuneStoneRock = STONE:Lerp(c.base, 0.25), RuneStoneGlow = Color3.fromRGB(110, 230, 255), RuneStoneMoss = Color3.fromRGB(110, 150, 90)}
 end},
 shieldRack = {template = "ShieldRack", faceTee = true, colors = function(c)
  return {RackWood = BARK, RackShieldsA = c.accent, RackShieldsB = CREAM, RackMetal = STEEL}
 end},
 -- Samurai Gardens.
 torii = {template = "Torii", faceTee = true, colors = function()
  return {ToriiRed = Color3.fromRGB(214, 52, 40), ToriiBlack = Color3.fromRGB(30, 28, 30), ToriiGold = GOLD}
 end},
 stoneLantern = {template = "StoneLantern", materials = {LanternGlow = NEON}, colors = function(c)
  return {LanternStone = STONE, LanternGlow = Color3.fromRGB(255, 214, 140), LanternMoss = c.base}
 end},
 cherryTree = {template = "CherryTree", colors = function(c)
  return {CherryTrunk = Color3.fromRGB(80, 52, 44), CherryBlossom = c.accent, CherryBlossomLight = c.accent:Lerp(WHITE, 0.5),
   CherryPetals = c.accent:Lerp(WHITE, 0.35)}
 end},
 -- Knight's Kingdom.
 banner = {template = "Banner", faceTee = true, colors = function(c, v)
  local cloth = ({c.accent, Color3.fromRGB(205, 45, 55), Color3.fromRGB(60, 150, 90)})[v % 3 + 1]
  return {BannerPole = BARK:Lerp(BLACK, 0.3), BannerCloth = cloth, BannerEmblem = GOLD, BannerTrim = GOLD}
 end},
 catapult = {template = "Catapult", colors = function()
  return {CatapultWood = BARK, CatapultMetal = STEEL:Lerp(BLACK, 0.3), CatapultRock = STONE}
 end},
 armorStand = {template = "ArmorStand", faceTee = "exact", yawOffset = math.pi, colors = function()
  return {ArmorWood = BARK, ArmorSteel = STEEL, ArmorPlume = Color3.fromRGB(210, 40, 50), ArmorGold = GOLD,
   ArmorVisor = Color3.fromRGB(25, 25, 30)}
 end},
 -- Frontier Town (with World 1's cactus).
 waterTower = {template = "WaterTower", colors = function()
  return {TowerWood = BARK:Lerp(BLACK, 0.15), TowerTank = Color3.fromRGB(170, 120, 75), TowerBands = Color3.fromRGB(70, 70, 75),
   TowerRoof = Color3.fromRGB(170, 70, 50)}
 end},
 wagon = {template = "Wagon", colors = function()
  return {WagonWood = BARK, WagonCanvas = CREAM, WagonWheels = BARK:Lerp(BLACK, 0.25), WagonIron = Color3.fromRGB(60, 60, 65)}
 end},
 barrels = {template = "Barrels", colors = function()
  return {BarrelWood = Color3.fromRGB(150, 98, 58), BarrelBands = Color3.fromRGB(70, 70, 75), BarrelCrate = Color3.fromRGB(200, 160, 100)}
 end},
 -- Clockwork Foundry.
 gearTower = {template = "GearTower", faceTee = true, colors = function()
  return {GearBrass = BRASS, GearCopper = COPPER, GearSteel = STEEL:Lerp(BLACK, 0.2)}
 end},
 pipeWorks = {template = "PipeWorks", colors = function()
  return {PipeCopper = COPPER, PipeBrass = BRASS, PipeSteel = STEEL:Lerp(BLACK, 0.25), PipeGauge = CREAM,
   PipeSteam = Color3.fromRGB(235, 235, 240)}
 end},
 -- Chrono Nexus.
 timeRing = {template = "TimeRing", faceTee = true, materials = {TimeRingGlow = NEON}, colors = function(c)
  return {TimeRingMetal = Color3.fromRGB(215, 222, 235), TimeRingGlow = c.accent, TimeRingBase = c.deep}
 end},
 hourglass = {template = "Hourglass", lift = 4, materials = {HourglassGlass = Enum.Material.Glass},
  transparency = {HourglassGlass = 0.55}, colors = function()
  return {HourglassFrame = GOLD, HourglassGlass = Color3.fromRGB(190, 240, 255), HourglassSand = Color3.fromRGB(255, 200, 110)}
 end},
 holoClock = {template = "HoloClock", faceTee = true, lift = 5,
  materials = {HoloClockRing = NEON, HoloClockHands = NEON, HoloClockCore = NEON}, colors = function(c)
  return {HoloClockRing = c.accent, HoloClockHands = Color3.fromRGB(255, 120, 230), HoloClockCore = WHITE}
 end},

 -- World 3 (Future World): props from tools/blender/runway_world3_city.py and
 -- runway_world3_space.py. Solar Suburbs.
 ecoHouse = {template = "EcoHouse", faceTee = "exact", yawOffset = math.pi,
  materials = {EcoHouseSolar = GLASS, EcoHouseGlass = GLASS}, transparency = {EcoHouseGlass = 0.15}, colors = function()
  return {EcoHouseWalls = COMPOSITE, EcoHouseRoof = Color3.fromRGB(74, 79, 88), EcoHouseSolar = SOLAR, EcoHouseGlass = TINTED_GLASS,
   EcoHouseTrim = Color3.fromRGB(196, 140, 92), EcoHouseLawn = Color3.fromRGB(112, 190, 92)}
 end},
 windTurbine = {template = "WindTurbine", faceTee = true, materials = {TurbineBase = Enum.Material.Concrete}, colors = function(c)
  return {TurbineTower = COMPOSITE, TurbineBlades = Color3.fromRGB(250, 251, 253), TurbineHub = c.accent, TurbineBase = CONCRETE}
 end},
 solarTree = {template = "SolarTree", materials = {SolarTreePanels = GLASS, SolarTreeGlow = NEON}, colors = function(c)
  return {SolarTreeStem = COMPOSITE, SolarTreePanels = SOLAR, SolarTreeGlow = c.accent:Lerp(WHITE, 0.35)}
 end},
 -- Fillers for the city sections.
 planter = {template = "Planter", materials = {PlanterGlow = NEON}, colors = function(c, v)
  return {PlanterBox = COMPOSITE, PlanterGlow = c.accent, PlanterLeaves = Color3.fromRGB(70, 160, 85):Lerp(c.accent, (v % 3) * 0.08)}
 end},
 -- Maglev Highway (and Skyline Metropolis's sky taxis, the same car floating high). Traffic runs
 -- along the runway both ways; the cars hover on glowing pads.
 hoverCar = {template = "HoverCar", faceTee = true, lift = 0.6, materials = {HoverCarGlow = NEON, HoverCarGlass = GLASS, HoverCarTrim = METAL},
  transparency = {HoverCarGlass = 0.25}, colors = function(c, v)
  local paint = ({Color3.fromRGB(255, 196, 40), Color3.fromRGB(235, 72, 84), Color3.fromRGB(80, 170, 255), COMPOSITE})[v % 4 + 1]
  return {HoverCarBody = paint, HoverCarGlass = Color3.fromRGB(140, 205, 240), HoverCarGlow = c.accent, HoverCarTrim = Color3.fromRGB(45, 48, 56)}
 end},
 skyTaxi = {template = "HoverCar", faceTee = true, lift = 12, materials = {HoverCarGlow = NEON, HoverCarGlass = GLASS, HoverCarTrim = METAL},
  transparency = {HoverCarGlass = 0.25}, colors = function(c)
  return {HoverCarBody = Color3.fromRGB(255, 200, 40), HoverCarGlass = Color3.fromRGB(140, 205, 240), HoverCarGlow = c.accent,
   HoverCarTrim = HAZARD_BLACK}
 end},
 maglevPylon = {template = "MaglevPylon", faceTee = true, materials = {PylonGlow = NEON, PylonRail = METAL}, colors = function(c)
  return {PylonBody = Color3.fromRGB(232, 236, 242), PylonRail = Color3.fromRGB(150, 158, 172), PylonGlow = c.accent}
 end},
 holoSign = {template = "HoloSign", faceTee = true, materials = {HoloSignPanel = NEON, HoloSignSymbols = NEON, HoloSignPosts = METAL},
  transparency = {HoloSignPanel = 0.55}, colors = function(c)
  return {HoloSignPosts = Color3.fromRGB(70, 76, 90), HoloSignPanel = c.accent, HoloSignSymbols = Color3.fromRGB(190, 250, 255)}
 end},
 -- Skyline Metropolis. Billboards show a glowing ad (a baseball and headline bars) on a dark screen.
 holoBillboard = {template = "HoloBillboard", faceTee = true, materials = {BillboardGlow = NEON, BillboardFrame = METAL},
  colors = function(c, v)
  local glow = ({c.accent, Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 200, 70)})[v % 3 + 1]
  return {BillboardFrame = Color3.fromRGB(52, 56, 66), BillboardScreen = Color3.fromRGB(30, 24, 72), BillboardGlow = glow}
 end},
 neoLamp = {template = "NeoLamp", materials = {NeoLampLight = NEON, NeoLampBase = METAL}, colors = function(c)
  return {NeoLampPole = COMPOSITE, NeoLampLight = c.accent:Lerp(WHITE, 0.3), NeoLampBase = Color3.fromRGB(50, 54, 64)}
 end},
 -- Robo Assembly Line. The arm shows its side to the batter.
 robotArm = {template = "RobotArm", faceTee = "exact", yawOffset = math.pi / 2,
  materials = {RobotArmLight = NEON, RobotArmJoints = METAL, RobotArmBase = METAL}, colors = function(c)
  return {RobotArmBody = c.accent, RobotArmJoints = Color3.fromRGB(48, 52, 60), RobotArmBase = Color3.fromRGB(150, 156, 166),
   RobotArmLight = Color3.fromRGB(90, 230, 255)}
 end},
 conveyor = {template = "Conveyor", faceTee = true, materials = {ConveyorFrame = METAL}, colors = function()
  return {ConveyorFrame = Color3.fromRGB(62, 66, 76), ConveyorBelt = Color3.fromRGB(30, 30, 34), ConveyorCrates = Color3.fromRGB(205, 152, 96),
   ConveyorStripes = HAZARD_YELLOW}
 end},
 robotUnit = {template = "RobotUnit", faceTee = "exact", yawOffset = math.pi,
  materials = {RobotVisor = NEON, RobotJoints = METAL, RobotStand = METAL}, colors = function(c)
  return {RobotShell = COMPOSITE, RobotJoints = Color3.fromRGB(46, 50, 58), RobotVisor = Color3.fromRGB(110, 235, 255),
   RobotStand = Color3.fromRGB(120, 126, 138), RobotAccent = c.accent}
 end},
 -- Fillers for the robotics and spaceport sections.
 cargoCrate = {template = "CargoCrate", materials = {CrateGlow = NEON, CrateTrim = METAL}, colors = function(c, v)
  local body = ({Color3.fromRGB(220, 224, 230), Color3.fromRGB(230, 130, 40), Color3.fromRGB(96, 110, 140)})[v % 3 + 1]
  return {CrateBody = body, CrateTrim = Color3.fromRGB(50, 54, 64), CrateGlow = c.accent}
 end},
 -- Biodome Gardens (with World 1's mushroom, glowing). The dome's entrance faces the batter.
 biodome = {template = "Biodome", faceTee = "exact", yawOffset = math.pi, materials = {BiodomeGlass = GLASS},
  transparency = {BiodomeGlass = 0.55}, colors = function(c)
  return {BiodomeFrame = Color3.fromRGB(240, 244, 248), BiodomeGlass = Color3.fromRGB(170, 230, 255), BiodomePlants = Color3.fromRGB(70, 170, 90),
   BiodomeFlowers = c.accent, BiodomeBase = Color3.fromRGB(185, 190, 198)}
 end},
 alienPlant = {template = "AlienPlant", materials = {AlienPlantBulbs = NEON}, colors = function(c, v)
  local bulbs = ({Color3.fromRGB(170, 255, 90), c.accent, Color3.fromRGB(255, 110, 200)})[v % 3 + 1]
  return {AlienPlantStalks = Color3.fromRGB(110, 60, 160), AlienPlantLeaves = Color3.fromRGB(40, 165, 140), AlienPlantBulbs = bulbs}
 end},
 glowShroom = {template = "Mushroom", materials = {MushroomCap = NEON, MushroomSpots = NEON}, colors = function(c, v)
  return {MushroomStem = Color3.fromRGB(226, 240, 232), MushroomGills = Color3.fromRGB(190, 220, 210),
   MushroomCap = ({c.accent, Color3.fromRGB(90, 240, 220)})[v % 2 + 1], MushroomSpots = WHITE, MushroomGrass = c.base}
 end},
 -- Virtual Grid.
 dataCube = {template = "DataCube", materials = {DataCubeEdges = NEON, DataCubeCore = NEON}, colors = function(c)
  return {DataCubeEdges = c.accent, DataCubeCore = Color3.fromRGB(255, 70, 190), DataCubeBase = Color3.fromRGB(28, 32, 48)}
 end},
 voxelTree = {template = "VoxelTree", colors = function(c)
  return {VoxelTrunk = Color3.fromRGB(70, 56, 110), VoxelLeaves = c.accent:Lerp(BLACK, 0.4), VoxelLeavesLight = c.accent:Lerp(WHITE, 0.1)}
 end},
 glitchPillar = {template = "GlitchPillar", materials = {GlitchGlow = NEON}, colors = function(c, v)
  return {GlitchBlocks = Color3.fromRGB(24, 26, 44), GlitchGlow = ({Color3.fromRGB(255, 60, 200), c.accent})[v % 2 + 1]}
 end},
 voxelBush = {template = "VoxelBush", materials = {VoxelBushGlow = NEON}, colors = function(c)
  return {VoxelBushLeaves = c.accent:Lerp(BLACK, 0.45), VoxelBushGlow = c.accent}
 end},
 -- Orbital Spaceport. Rockets, dishes and tanks show their fronts (portholes, ladders) to the batter.
 rocket = {template = "Rocket", faceTee = "exact", yawOffset = math.pi, materials = {RocketWindow = NEON, RocketPad = METAL},
  colors = function(c, v)
  local accent = ({Color3.fromRGB(220, 50, 50), c.accent})[v % 2 + 1]
  return {RocketBody = Color3.fromRGB(240, 240, 236), RocketAccent = accent, RocketFins = accent:Lerp(BLACK, 0.1),
   RocketPad = Color3.fromRGB(105, 110, 120), RocketWindow = Color3.fromRGB(150, 220, 255)}
 end},
 radarDish = {template = "RadarDish", faceTee = "exact", yawOffset = math.pi, materials = {DishMount = METAL}, colors = function()
  return {DishBowl = Color3.fromRGB(236, 238, 242), DishMount = Color3.fromRGB(150, 156, 168), DishFeed = Color3.fromRGB(255, 190, 60)}
 end},
 fuelTank = {template = "FuelTank", faceTee = "exact", yawOffset = math.pi, materials = {TankBands = METAL}, colors = function()
  return {TankBody = Color3.fromRGB(238, 238, 234), TankBands = Color3.fromRGB(140, 146, 158), TankPipes = Color3.fromRGB(255, 196, 40),
   TankBase = Color3.fromRGB(150, 150, 146)}
 end},
 -- Lunar Colony (the habitat also stands on Mars, dusted red). Airlocks, ladders and flags face the
 -- batter. PodWindows also holds the habitat's solar cells.
 habitatPod = {template = "HabitatPod", faceTee = "exact", yawOffset = math.pi,
  materials = {PodWindows = GLASS, PodTrim = METAL, PodLegs = METAL}, colors = function()
  return {PodShell = Color3.fromRGB(240, 240, 236), PodWindows = Color3.fromRGB(45, 90, 170), PodTrim = Color3.fromRGB(170, 176, 188),
   PodLegs = Color3.fromRGB(70, 74, 84)}
 end},
 marsHabitat = {template = "HabitatPod", faceTee = "exact", yawOffset = math.pi,
  materials = {PodWindows = GLASS, PodTrim = METAL, PodLegs = METAL}, colors = function()
  return {PodShell = Color3.fromRGB(236, 214, 196), PodWindows = Color3.fromRGB(45, 90, 170), PodTrim = Color3.fromRGB(205, 110, 60),
   PodLegs = Color3.fromRGB(70, 74, 84)}
 end},
 lunarLander = {template = "LunarLander", faceTee = "exact", yawOffset = math.pi,
  materials = {LanderFoil = Enum.Material.Foil, LanderModule = METAL, LanderLegs = METAL, LanderWindows = GLASS}, colors = function()
  return {LanderFoil = Color3.fromRGB(235, 180, 60), LanderModule = Color3.fromRGB(196, 200, 208), LanderLegs = Color3.fromRGB(90, 94, 104),
   LanderWindows = Color3.fromRGB(20, 26, 40)}
 end},
 astronautFlag = {template = "AstronautFlag", faceTee = true, materials = {FlagPole = METAL}, colors = function(c)
  return {FlagPole = Color3.fromRGB(210, 214, 222), FlagCloth = Color3.fromRGB(40, 90, 200), FlagEmblem = WHITE, FlagBase = c.base:Lerp(WHITE, 0.1)}
 end},
 -- Red Planet Outpost.
 marsRover = {template = "MarsRover", faceTee = "exact", yawOffset = math.pi,
  materials = {RoverDeck = GLASS, RoverMast = METAL, RoverAccent = Enum.Material.Foil}, colors = function()
  return {RoverBody = Color3.fromRGB(236, 236, 232), RoverWheels = Color3.fromRGB(45, 46, 52), RoverDeck = Color3.fromRGB(30, 60, 140),
   RoverMast = Color3.fromRGB(190, 194, 204), RoverAccent = Color3.fromRGB(230, 170, 60)}
 end},
 terraformer = {template = "Terraformer", materials = {TerraformerCore = NEON, TerraformerFins = METAL}, colors = function(c)
  return {TerraformerBody = Color3.fromRGB(214, 206, 196), TerraformerCore = Color3.fromRGB(255, 140, 50), TerraformerFins = Color3.fromRGB(70, 76, 88),
   TerraformerBase = Color3.fromRGB(96, 90, 86)}
 end},
 -- Quantum Singularity.
 energyRing = {template = "EnergyRing", faceTee = true, materials = {EnergyRingGlow = NEON, EnergyRingFrame = METAL}, colors = function()
  return {EnergyRingFrame = Color3.fromRGB(40, 44, 62), EnergyRingGlow = Color3.fromRGB(90, 230, 255), EnergyRingBase = Color3.fromRGB(22, 24, 38)}
 end},
 quantumShard = {template = "QuantumShard", lift = 5, materials = {ShardCrystal = GLASS, ShardRing = NEON, ShardRock = Enum.Material.Slate},
  transparency = {ShardCrystal = 0.1}, colors = function(c, v)
  return {ShardCrystal = ({Color3.fromRGB(160, 100, 255), c.accent})[v % 2 + 1], ShardRing = Color3.fromRGB(90, 240, 255),
   ShardRock = Color3.fromRGB(48, 44, 66)}
 end},
 riftRock = {template = "RiftRock", lift = 7, materials = {RiftRockGlow = NEON, RiftRockCrystals = NEON, RiftRockStone = Enum.Material.Slate},
  colors = function()
  return {RiftRockStone = Color3.fromRGB(70, 60, 92), RiftRockGlow = Color3.fromRGB(255, 80, 210), RiftRockCrystals = Color3.fromRGB(90, 240, 220)}
 end},
 -- The black hole behind World 3's end portal (WorldConfig runway.landmarks): placed by its centre,
 -- its photon ring toward the batter.
 blackHole = {template = "BlackHole", faceTee = "exact", yawOffset = math.pi, materials = {BlackHoleDisc = NEON, BlackHoleHalo = NEON},
  colors = function()
  return {BlackHoleCore = Color3.new(0, 0, 0), BlackHoleDisc = Color3.fromRGB(255, 150, 60), BlackHoleHalo = Color3.fromRGB(255, 245, 220)}
 end},

 -- World 4 (Tiny Town): props from tools/blender/runway_world4_home.py (sections 1-5). Giant Backyard.
 grassBlade = {template = "GrassBlade", fallback = "jungleTree", materials = {GrassDew = GLASS}, transparency = {GrassDew = 0.3},
  colors = function(c, v)
  local green = Color3.fromRGB(72, 172, 58):Lerp(c.base, 0.3):Lerp(BLACK, (v % 3) * 0.06)
  return {GrassBlades = green, GrassBladesLight = green:Lerp(Color3.fromRGB(196, 240, 110), 0.45), GrassDew = WATER}
 end},
 hoseReel = {template = "HoseReel", fallback = "fern", faceTee = true, colors = function()
  return {HoseReelFrame = TOY_RED, HoseReelDrum = TOY_YELLOW, HoseTube = TOY_GREEN, HoseNozzle = TOY_ORANGE}
 end},
 sprinkler = {template = "Sprinkler", fallback = "fern", materials = {SprinklerMetal = METAL, SprinklerWater = GLASS},
  transparency = {SprinklerWater = 0.35}, colors = function()
  return {SprinklerBody = TOY_YELLOW, SprinklerMetal = CHROME, SprinklerWater = WATER}
 end},
 ladybug = {template = "Ladybug", fallback = "mushroom", faceTee = "exact", yawOffset = math.pi, colors = function()
  return {LadybugShell = TOY_RED, LadybugSpots = INK, LadybugBody = INK, LadybugEyes = WHITE}
 end},
 -- Fillers for the backyard.
 pebble = {template = "Pebble", fallback = "rock", colors = function(c)
  return {PebbleStoneA = STONE:Lerp(c.dark, 0.15), PebbleStoneB = Color3.fromRGB(200, 188, 166)}
 end},
 -- Picnic Blanket. The ants march toward the batter.
 sandwich = {template = "Sandwich", fallback = "cake", colors = function(c, v)
  return {SandwichBread = BREAD, SandwichCrust = CRUST, SandwichLettuce = Color3.fromRGB(122, 212, 82), SandwichTomato = TOY_RED,
   SandwichCheese = Color3.fromRGB(255, 208, 66), SandwichPick = TOYS[v % #TOYS + 1]}
 end},
 antLine = {template = "AntLine", fallback = "gumdrops", faceTee = "exact", yawOffset = math.pi, colors = function()
  return {AntBodies = Color3.fromRGB(122, 32, 26), AntLegs = Color3.fromRGB(52, 22, 18), AntEyes = WHITE, AntCrumb = Color3.fromRGB(252, 248, 240)}
 end},
 picnicBasket = {template = "PicnicBasket", fallback = "flowers", faceTee = true,
  materials = {BasketWicker = WOOD, BasketWeave = WOOD, BasketLid = WOOD, BasketCloth = FABRIC}, colors = function()
  return {BasketWicker = Color3.fromRGB(214, 160, 90), BasketWeave = Color3.fromRGB(166, 110, 56), BasketLid = Color3.fromRGB(184, 126, 66),
   BasketHandle = Color3.fromRGB(140, 90, 46), BasketCloth = TOY_RED}
 end},
 crumbs = {template = "Crumbs", fallback = "rock", colors = function()
  return {CrumbBread = BREAD, CrumbCrust = CRUST}
 end},
 -- Kitchen Counter. The board shows its face to the batter, the faucet its side.
 cuttingBoard = {template = "CuttingBoard", fallback = "cake", faceTee = "exact", yawOffset = math.pi,
  materials = {BoardWood = WOOD, BoardWoodDark = WOOD}, colors = function()
  return {BoardWood = BEECH, BoardWoodDark = Color3.fromRGB(150, 102, 60), BoardCarrot = TOY_ORANGE, BoardGreens = Color3.fromRGB(70, 168, 56),
   BoardSlices = Color3.fromRGB(206, 240, 150)}
 end},
 toaster = {template = "Toaster", fallback = "lollipop", faceTee = true, materials = {ToasterChrome = METAL}, colors = function(c, v)
  local body = ({Color3.fromRGB(140, 216, 214), Color3.fromRGB(255, 170, 160), Color3.fromRGB(255, 226, 120)})[v % 3 + 1]
  return {ToasterBody = body, ToasterTrim = Color3.fromRGB(52, 52, 60), ToasterChrome = CHROME, ToasterToast = BREAD, ToasterCrust = CRUST}
 end},
 faucet = {template = "Faucet", fallback = "dunes", faceTee = "exact", yawOffset = math.pi / 2,
  materials = {FaucetChrome = METAL, FaucetWater = GLASS}, transparency = {FaucetWater = 0.3}, colors = function(c, v)
  return {FaucetChrome = CHROME, FaucetHandle = v % 2 == 0 and TOY_BLUE or TOY_RED, FaucetWater = WATER}
 end},
 cerealPiece = {template = "CerealPiece", fallback = "rock", colors = function()
  return {CerealLoopA = Color3.fromRGB(255, 158, 54), CerealLoopB = Color3.fromRGB(255, 104, 128), CerealLoopC = Color3.fromRGB(244, 222, 86)}
 end},
 -- Block Town.
 alphabetBlock = {template = "AlphabetBlock", fallback = "beacon", faceTee = "exact", yawOffset = math.pi, materials = {BlockWood = WOOD},
  colors = function()
  return {BlockWood = BEECH, BlockPanelA = TOY_RED, BlockPanelB = TOY_BLUE, BlockPanelC = TOY_GREEN, BlockLetters = WHITE}
 end},
 trainTrack = {template = "TrainTrack", fallback = "gumdrops", faceTee = true, materials = {TrackWood = WOOD}, colors = function(c, v)
  return {TrackWood = BEECH, TrainBody = TOYS[v % #TOYS + 1], TrainCab = TOYS[(v + 2) % #TOYS + 1], TrainWheels = TOY_YELLOW,
   TrainTrim = Color3.fromRGB(40, 40, 46)}
 end},
 brickTower = {template = "BrickTower", fallback = "crystals", colors = function(c, v)
  return {BrickRed = TOYS[v % 4 + 1], BrickYellow = TOYS[(v + 1) % 4 + 1], BrickBlue = TOYS[(v + 2) % 4 + 1], BrickGreen = TOYS[(v + 3) % 4 + 1]}
 end},
 toyBrick = {template = "ToyBrick", fallback = "rock", colors = function(c, v)
  return {ToyBrickA = TOYS[v % 4 + 1], ToyBrickB = TOYS[(v + 1) % 4 + 1]}
 end},
 -- Board Game Boulevard. The heart card and the player token face the batter.
 giantDie = {template = "GiantDie", fallback = "geode", colors = function(c, v)
  return {DieBody = Color3.fromRGB(250, 248, 242), DiePips = v % 2 == 0 and TOY_RED or INK}
 end},
 playingCard = {template = "PlayingCard", fallback = "neonArch", faceTee = "exact", yawOffset = math.pi, colors = function(c, v)
  return {CardFace = Color3.fromRGB(252, 250, 246), CardBack = v % 2 == 0 and TOY_RED or TOY_BLUE, CardSuitsRed = TOY_RED, CardSuitsBlack = INK}
 end},
 gamePiece = {template = "GamePiece", fallback = "beacon", faceTee = "exact", yawOffset = math.pi, materials = {MeepleBody = WOOD, MeepleBodyB = WOOD},
  colors = function(c, v)
  return {MeepleBody = TOYS[v % 4 + 1], MeepleBodyB = TOYS[(v + 1) % 4 + 1]}
 end},
 chessPawn = {template = "ChessPawn", fallback = "rock", colors = function(c, v)
  return {PawnBody = v % 2 == 0 and INK or Color3.fromRGB(246, 240, 226)}
 end},
 -- World 4, sections 6-10 (tools/blender/runway_world4_house.py). Craft Table; the paper plane glides.
 crayon = {template = "Crayon", fallback = "candyCane", colors = function(c, v)
  return {CrayonA = TOYS[v % 4 + 1], CrayonB = TOYS[(v + 1) % 4 + 1], CrayonC = TOYS[(v + 2) % 4 + 1], CrayonBands = INK}
 end},
 paperPlane = {template = "PaperPlane", fallback = "lollipop", faceTee = true, lift = 6, colors = function(c, v)
  return {PlaneWings = Color3.fromRGB(252, 252, 248), PlaneStripe = TOYS[v % 4 + 1]}
 end},
 gluePuddle = {template = "GluePuddle", fallback = "crystals", colors = function()
  return {GlueBottle = Color3.fromRGB(250, 250, 246), GlueCap = TOY_ORANGE, GlueLabel = TOY_BLUE, GluePuddle = Color3.fromRGB(246, 248, 255)}
 end},
 paperScrap = {template = "PaperScrap", fallback = "rock", colors = function(c, v)
  return {PaperBall = Color3.fromRGB(250, 250, 246), PaperScrapColor = ({c.accent, TOY_YELLOW, Color3.fromRGB(140, 200, 255)})[v % 3 + 1]}
 end},
 -- Bathtub Bay. The duck faces the batter.
 rubberDuck = {template = "RubberDuck", fallback = "cloud", faceTee = "exact", yawOffset = math.pi, colors = function()
  return {DuckBody = Color3.fromRGB(255, 214, 40), DuckBeak = TOY_ORANGE, DuckEyes = INK}
 end},
 soapBar = {template = "SoapBar", fallback = "iceShards", colors = function(c, v)
  local soap = ({Color3.fromRGB(255, 160, 190), Color3.fromRGB(170, 230, 200), Color3.fromRGB(200, 180, 255)})[v % 3 + 1]
  return {SoapBar = soap, SoapSuds = WHITE, SoapDish = Color3.fromRGB(140, 216, 220)}
 end},
 bubbleFoam = {template = "BubbleFoam", fallback = "gumdrops", materials = {BubbleShine = GLASS}, transparency = {BubbleShine = 0.45},
  colors = function()
  return {BubbleFoam = Color3.fromRGB(252, 252, 255), BubbleShine = Color3.fromRGB(200, 230, 255)}
 end},
 bubbles = {template = "Bubbles", fallback = "bush", lift = 2, materials = {Bubbles = GLASS}, transparency = {Bubbles = 0.45}, colors = function()
  return {Bubbles = Color3.fromRGB(200, 230, 255)}
 end},
 -- Bookshelf Cliffs. The lamp shows its side to the batter.
 pencil = {template = "Pencil", fallback = "pine", materials = {PencilFerrule = METAL}, colors = function(c, v)
  return {PencilBody = TOY_YELLOW, PencilWood = Color3.fromRGB(240, 206, 156), PencilLead = INK, PencilFerrule = CHROME,
   PencilEraser = Color3.fromRGB(255, 150, 170), PencilCup = TOYS[v % 4 + 1]}
 end},
 spinningGlobe = {template = "SpinningGlobe", fallback = "planet", materials = {GlobeStand = METAL}, colors = function()
  return {GlobeOcean = Color3.fromRGB(64, 140, 230), GlobeLand = Color3.fromRGB(110, 200, 90), GlobeStand = GOLD}
 end},
 readingLamp = {template = "ReadingLamp", fallback = "mesa", faceTee = "exact", yawOffset = math.pi / 2,
  materials = {LampBulb = NEON, LampJoints = METAL}, colors = function(c, v)
  return {LampMetal = TOYS[v % 4 + 1], LampJoints = Color3.fromRGB(52, 52, 60), LampBulb = Color3.fromRGB(255, 236, 170)}
 end},
 eraser = {template = "Eraser", fallback = "rock", colors = function()
  return {EraserPink = Color3.fromRGB(255, 150, 170), EraserBlue = TOY_BLUE}
 end},
 -- Attic Treasures. The trunk and the web face the batter, the rocking horse its side.
 oldTrunk = {template = "OldTrunk", fallback = "geode", faceTee = "exact", yawOffset = math.pi,
  materials = {TrunkBody = WOOD, TrunkLid = WOOD, TrunkBands = METAL}, colors = function()
  return {TrunkBody = Color3.fromRGB(120, 74, 44), TrunkLid = Color3.fromRGB(140, 88, 52), TrunkBands = GOLD}
 end},
 rockingHorse = {template = "RockingHorse", fallback = "moon", faceTee = "exact", yawOffset = math.pi / 2,
  materials = {HorseRockers = WOOD}, colors = function(c, v)
  return {HorseBody = Color3.fromRGB(250, 242, 226), HorseRockers = TOY_RED, HorseMane = Color3.fromRGB(150, 90, 46),
   HorseSaddle = v % 2 == 0 and TOY_BLUE or TOY_GREEN}
 end},
 cobweb = {template = "Cobweb", fallback = "star", faceTee = "exact", yawOffset = math.pi, materials = {CobwebPosts = WOOD},
  transparency = {CobwebSilk = 0.2}, colors = function()
  return {CobwebPosts = Color3.fromRGB(170, 124, 80), CobwebSilk = Color3.fromRGB(240, 242, 250), CobwebSpider = INK}
 end},
 dustBunny = {template = "DustBunny", fallback = "rock", faceTee = "exact", yawOffset = math.pi, materials = {DustFluff = FABRIC},
  colors = function()
  return {DustFluff = Color3.fromRGB(160, 156, 170), DustEyes = WHITE}
 end},
 -- Pillow Fort. The tunnel opens toward the batter; the night light glows.
 giantPillow = {template = "GiantPillow", fallback = "cloud", materials = {PillowClothA = FABRIC, PillowClothB = FABRIC}, colors = function(c, v)
  local pastel = {Color3.fromRGB(170, 160, 240), Color3.fromRGB(255, 190, 205), Color3.fromRGB(160, 214, 255), Color3.fromRGB(255, 226, 150)}
  return {PillowClothA = pastel[v % 4 + 1], PillowClothB = pastel[(v + 1) % 4 + 1], PillowSeam = Color3.fromRGB(255, 248, 230)}
 end},
 blanketTunnel = {template = "BlanketTunnel", fallback = "moon", faceTee = "exact", yawOffset = math.pi,
  materials = {TunnelBlanket = FABRIC, TunnelStripes = FABRIC, TunnelCushions = FABRIC}, colors = function(c)
  return {TunnelBlanket = Color3.fromRGB(96, 100, 200), TunnelStripes = c.accent, TunnelCushions = Color3.fromRGB(150, 196, 255)}
 end},
 nightLight = {template = "NightLight", fallback = "star", faceTee = "exact", yawOffset = math.pi, materials = {NightLightGlow = NEON},
  colors = function()
  return {NightLightBase = Color3.fromRGB(246, 246, 250), NightLightGlow = Color3.fromRGB(255, 226, 140), NightLightFace = Color3.fromRGB(150, 110, 50)}
 end},
 plushToy = {template = "PlushToy", fallback = "bush", faceTee = "exact", yawOffset = math.pi, materials = {PlushFur = FABRIC}, colors = function(c, v)
  local fur = ({Color3.fromRGB(176, 120, 72), Color3.fromRGB(240, 200, 150), Color3.fromRGB(200, 150, 210)})[v % 3 + 1]
  return {PlushFur = fur, PlushSnout = Color3.fromRGB(250, 228, 196), PlushEyes = INK}
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
 -- World 2.
 brontosaurus = {template = "Brontosaurus", scale = 4, colors = function(c, v)
  local skin = ({Color3.fromRGB(90, 140, 120), Color3.fromRGB(122, 132, 88), Color3.fromRGB(100, 120, 150)})[v % 3 + 1]
  return {BrontoBody = skin, BrontoBelly = skin:Lerp(CREAM, 0.45), BrontoEyes = Color3.fromRGB(25, 25, 30)}
 end},
 megaliths = {template = "Megalith", scale = 4, colors = function(c)
  return {MegalithStone = STONE:Lerp(c.dark, 0.2), MegalithMoss = Color3.fromRGB(110, 150, 80)}
 end},
 pyramids = {template = "Pyramid", scale = 4, colors = function()
  return {PyramidStone = SANDSTONE, PyramidCap = GOLD, PyramidSteps = SANDSTONE:Lerp(BLACK, 0.18)}
 end},
 temple = {template = "Temple", scale = 3.5, colors = function(c)
  return {TempleMarble = MARBLE, TempleRoof = TERRACOTTA, TempleGold = GOLD, TempleCella = MARBLE:Lerp(c.accent, 0.12)}
 end},
 fjordPeaks = {template = "Mountain", scale = 5, colors = function(c)
  return {MountainRock = c.base:Lerp(BLACK, 0.2), MountainSnow = WHITE}
 end},
 pagodas = {template = "Pagoda", scale = 3.5, colors = function()
  return {PagodaWalls = Color3.fromRGB(200, 60, 50), PagodaRoofs = Color3.fromRGB(40, 70, 72), PagodaGold = GOLD, PagodaStone = STONE}
 end},
 castle = {template = "Castle", scale = 3.5, colors = function(c)
  return {CastleStone = STONE:Lerp(c.base, 0.3), CastleRoofs = c.accent, CastleFlags = Color3.fromRGB(210, 45, 55),
   CastleDoor = Color3.fromRGB(40, 32, 30)}
 end},
 buttes = {template = "Mesa", scale = 3.5, colors = function(c)
  return {MesaRockA = Color3.fromRGB(176, 82, 52), MesaRockB = c.base}
 end},
 smokestacks = {template = "Smokestack", scale = 3.5, materials = {StackWindows = NEON}, colors = function()
  return {StackBrick = Color3.fromRGB(150, 70, 52), StackBands = BRASS, StackSmoke = Color3.fromRGB(150, 150, 155),
   StackRoof = Color3.fromRGB(60, 64, 70), StackWindows = Color3.fromRGB(255, 190, 90)}
 end},
 futureSpires = {template = "FutureSpire", scale = 4, materials = {FutureSpireGlow = NEON}, colors = function(c)
  return {FutureSpireBody = Color3.fromRGB(225, 230, 240), FutureSpireGlow = c.accent}
 end},
 -- World 3.
 windFarm = {template = "WindTurbine", scale = 4, faceTee = true, materials = MESH_PROPS.windTurbine.materials,
  colors = MESH_PROPS.windTurbine.colors},
 viaduct = {template = "Viaduct", scale = 4, faceTee = "exact", materials = {ViaductGlow = NEON, ViaductWindows = GLASS,
  ViaductPillars = Enum.Material.Concrete}, colors = function(c)
  return {ViaductPillars = Color3.fromRGB(200, 204, 212), ViaductTrack = Color3.fromRGB(226, 230, 237), ViaductGlow = c.accent,
   ViaductTrain = Color3.fromRGB(246, 248, 251), ViaductWindows = Color3.fromRGB(28, 38, 58)}
 end},
 skyscrapers = {template = "Skyscraper", scale = 7, materials = {SkyscraperGlass = GLASS, SkyscraperGlow = NEON}, colors = function(c, v)
  local glass = ({Color3.fromRGB(70, 130, 195), Color3.fromRGB(110, 165, 220), Color3.fromRGB(80, 110, 180)})[v % 3 + 1]
  return {SkyscraperGlass = glass, SkyscraperFrame = Color3.fromRGB(236, 239, 244), SkyscraperGlow = c.accent}
 end},
 megaFactory = {template = "MegaFactory", scale = 3.5, faceTee = "exact", yawOffset = math.pi,
  materials = {FactoryGlow = NEON, FactoryRoof = METAL, FactoryVents = METAL}, colors = function()
  return {FactoryWalls = Color3.fromRGB(206, 211, 219), FactoryRoof = Color3.fromRGB(70, 76, 88), FactoryVents = Color3.fromRGB(140, 148, 160),
   FactoryGlow = Color3.fromRGB(255, 196, 90)}
 end},
 domes = {template = "Biodome", scale = 4, faceTee = "exact", yawOffset = math.pi, materials = MESH_PROPS.biodome.materials,
  transparency = MESH_PROPS.biodome.transparency, colors = MESH_PROPS.biodome.colors},
 voxelPeaks = {template = "VoxelPeak", scale = 4, materials = {VoxelPeakGlow = NEON}, colors = function(c)
  return {VoxelPeakRock = Color3.fromRGB(40, 44, 70), VoxelPeakGlow = c.accent, VoxelPeakSnow = Color3.fromRGB(235, 245, 255)}
 end},
 launchTowers = {template = "LaunchTower", scale = 4, materials = {GantryLights = NEON, GantrySteel = METAL}, colors = function()
  return {GantrySteel = Color3.fromRGB(200, 70, 50), GantryRocket = Color3.fromRGB(240, 240, 236), GantryAccent = Color3.fromRGB(30, 32, 38),
   GantryPad = Color3.fromRGB(140, 140, 136), GantryLights = Color3.fromRGB(255, 60, 50)}
 end},
 moonRidges = {template = "MoonRidge", scale = 4.5, faceTee = "exact", yawOffset = math.pi, colors = function(c)
  return {MoonRidgeRock = c.base:Lerp(WHITE, 0.08), MoonRidgeCraters = c.base:Lerp(BLACK, 0.22)}
 end},
 marsButtes = {template = "Mesa", scale = 3.5, colors = function(c)
  return {MesaRockA = Color3.fromRGB(150, 62, 38), MesaRockB = c.base}
 end},
 voidShards = {template = "QuantumShard", scale = 4, lift = 12, materials = MESH_PROPS.quantumShard.materials,
  transparency = MESH_PROPS.quantumShard.transparency, colors = MESH_PROPS.quantumShard.colors},
 -- World 4 (fallback: the placeholder backdrop each replaced). The fence runs along the runway.
 giantFence = {template = "GiantFence", fallback = "canopy", scale = 4, faceTee = "exact", materials = {FencePickets = WOOD, FenceRails = WOOD},
  colors = function(c)
  return {FencePickets = Color3.fromRGB(250, 248, 240), FenceRails = Color3.fromRGB(226, 222, 210), FenceGrass = c.base}
 end},
 blanketFolds = {template = "BlanketFolds", fallback = "hills", scale = 4, materials = {BlanketRed = FABRIC, BlanketWhite = FABRIC},
  colors = function(c)
  return {BlanketRed = c.base, BlanketWhite = c.accent}
 end},
 cerealHills = {template = "CerealHills", fallback = "mesas", scale = 3.5, colors = function()
  return {CerealHeapBase = Color3.fromRGB(236, 186, 96), CerealHeapA = Color3.fromRGB(255, 158, 54), CerealHeapB = Color3.fromRGB(255, 104, 128),
   CerealHeapC = Color3.fromRGB(244, 222, 86)}
 end},
 blockSkyline = {template = "BrickTower", fallback = "towers", scale = 4, colors = MESH_PROPS.brickTower.colors},
 boardGameBox = {template = "BoardGameBox", fallback = "spires", scale = 4, faceTee = "exact", yawOffset = math.pi, colors = function(c, v)
  local base = TOYS[v % #TOYS + 1]
  return {GameBoxBase = base, GameBoxLid = TOYS[(v + 2) % #TOYS + 1], GameBoxArt = WHITE, GameBoxBoard = Color3.fromRGB(246, 236, 206)}
 end},
 paperHills = {template = "PaperHills", fallback = "candyHills", scale = 4, colors = function(c, v)
  local paper = {Color3.fromRGB(150, 206, 255), Color3.fromRGB(255, 190, 130), Color3.fromRGB(190, 240, 160), Color3.fromRGB(255, 170, 200)}
  return {PaperHillA = paper[v % 4 + 1], PaperHillB = paper[(v + 1) % 4 + 1]}
 end},
 tubWall = {template = "TubWall", fallback = "bigClouds", scale = 4, faceTee = "exact", materials = {TubFeet = METAL, TubWater = GLASS},
  transparency = {TubWater = 0.3}, colors = function()
  return {TubSide = Color3.fromRGB(250, 252, 255), TubRim = WHITE, TubFeet = GOLD, TubWater = Color3.fromRGB(140, 210, 255)}
 end},
 bookCliffs = {template = "BookCliffs", fallback = "mountains", scale = 4, colors = function(c, v)
  return {BookCoversA = TOYS[v % 4 + 1], BookCoversB = Color3.fromRGB(120, 70, 150), BookCoversC = TOYS[(v + 2) % 4 + 1],
   BookPages = Color3.fromRGB(252, 242, 220)}
 end},
 atticWindow = {template = "AtticWindow", fallback = "towers", scale = 4, faceTee = "exact", yawOffset = math.pi,
  materials = {WindowFrame = WOOD, WindowWall = WOOD, WindowGlass = NEON}, transparency = {WindowGlass = 0.25}, colors = function()
  return {WindowFrame = Color3.fromRGB(180, 130, 86), WindowWall = Color3.fromRGB(110, 80, 64), WindowGlass = Color3.fromRGB(196, 214, 255)}
 end},
 pillowHills = {template = "GiantPillow", fallback = "bigClouds", scale = 4, materials = MESH_PROPS.giantPillow.materials,
  colors = MESH_PROPS.giantPillow.colors},
}

local function getTemplate(definition)
 local folder = ServerStorage:FindFirstChild("RunwayAssets")
 local template = definition and folder and folder:FindFirstChild(definition.template)
 if template and template:IsA("Model") then return template end
 return nil
end

-- The kind actually placed for kind: itself when its model is imported (or it has no fallback),
-- else its fallback kind. Returns the kind, its definition and its template (nil if missing).
local function resolve(definitions, kind)
 local definition = definitions[kind]
 local template = getTemplate(definition)
 if not template and definition and definition.fallback then
  return resolve(definitions, definition.fallback)
 end
 return kind, definition, template
end

local function placeMesh(theme, frame, template, definition, c, position, scale, variant)
 local model = template:Clone()
 local colors = definition.colors(c, variant)
 local materials = definition.materials or {}
 local transparency = definition.transparency or {}
 for _, part in model:GetDescendants() do
  if part:IsA("BasePart") then
   part.Anchored = true
   part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
   part.Color = colors[part.Name] or part.Color
   part.Material = materials[part.Name] or part.Material
   part.Transparency = transparency[part.Name] or part.Transparency
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
   local kind, definition, template = resolve(MESH_PROPS, section.props[(variant - 1) % #section.props + 1])
   local position = Vector3.new(side * (deckInner + (index % 2 == 0 and 16 or 44)), deckTop, -d)
   if template then
    placeMesh(theme, frame, template, definition, c, position, config.propScale, variant)
   elseif Props[kind] then
    placeProp(theme, frame, kind, position, config.propScale, function(propKit)
     Props[kind](propKit, position, c, variant, side)
    end)
   end -- (A mesh-only prop whose model is not imported yet is skipped.)
   local fillerPosition = Vector3.new(side * (deckInner + 30), deckTop, -(d + length / count / 2))
   local fillers = section.fillers or DEFAULT_FILLERS
   local _, fillerDefinition, fillerTemplate = resolve(MESH_PROPS, fillers[variant % #fillers + 1])
   if fillerTemplate then
    placeMesh(theme, frame, fillerTemplate, fillerDefinition, c, fillerPosition, config.fillerScale, variant)
   else
    placeProp(theme, frame, "Filler", fillerPosition, config.fillerScale, function(propKit)
     filler(propKit, fillerPosition, c, variant)
    end)
   end
  end
  local backdrop, backdropDefinition, backdropTemplate = resolve(BACKDROP_MESHES, section.backdrop)
  for index = 1, backdropCount do
   local d = section.startDistance + (index - 0.5) * length / backdropCount + side * config.backdropSpacing / 3
   local position = Vector3.new(side * (deckInner + config.deckWidth + 50 + (index % 3) * 35), outerTop, -d)
   local variant = index + section.order
   if backdropTemplate then
    placeMesh(theme, frame, backdropTemplate, backdropDefinition, c, position, backdropDefinition.scale, variant)
   elseif Backdrops[backdrop] then
    Backdrops[backdrop](kit, position, c, variant, side)
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
  buildSides(kit, config, runwayWidth, section.startDistance, length, c, section.deckMaterial, true, section.wallTileColor,
   section.deckColor)
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
 if world.endPortal then
  -- The World's end: a giant time portal across the runway, facing the tee. BallLauncher pulls
  -- a ball that reaches it into the opening (GateCenter, saved on the field).
  local base = frame * CFrame.new(0, 0, -world.endDistance) * CFrame.Angles(0, math.pi, 0)
  local _, center, radius = Portal.BuildGate(finish, base, world.endPortal.height, world.portalModel)
  field:SetAttribute("GateCenter", center)
  field:SetAttribute("GateRadius", radius)
 else
  buildTitle(kit, world.endDistance, string.upper(world.displayName) .. " FINISH", last)
 end
 -- Landmarks: single giant meshes placed by their centre (skipped while the model is missing).
 for index, landmark in config.landmarks or {} do
  local definition = MESH_PROPS[landmark.kind] or BACKDROP_MESHES[landmark.kind]
  local template = getTemplate(definition)
  if template then
   placeMesh(finish, frame, template, definition, last, Vector3.new(landmark.x or 0, landmark.height, -landmark.distance),
    landmark.scale, index)
  end
 end
end

-- Places one mesh prop or backdrop by kind (MESH_PROPS / BACKDROP_MESHES) away from a runway,
-- e.g. around a hub (HubDecor). colors = {color, accent} like a section's palette; variant varies
-- heading and size. Returns false when the template is missing from RunwayAssets.
function RunwayDecor.PlaceMesh(parent, frame, kind, position, scale, variant, colors)
 local _, definition, template = resolve(MESH_PROPS[kind] and MESH_PROPS or BACKDROP_MESHES, kind)
 if not template then return false end
 local c = palette({color = colors.color, accent = colors.accent})
 placeMesh(parent, frame, template, definition, c, position, scale * (definition.scale or 1), variant)
 return true
end

return RunwayDecor
