-- Themed scenery for a World's hub (WorldConfig hub.theme), in FieldBuilder's hub frame:
-- origin at the tee on the hub floor, +Z back into the hub, +X to the right when facing down
-- the runway.
--   HomeField (World 1): a sunken ballpark. Striped grass with dirt paths to the cages and a
--     home plate at the spawn; a padded outfield wall with bunting; bleachers on three sides
--     climbing to a grassy berm level with the runway's outer ground; light towers, foul poles,
--     a scoreboard, and a treeline on the berm.
--   TimeTravel (World 2): a sunken clockwork plaza. Checkered tiles with brass walkways, a
--     giant clock face for events, glowing terraces up to the berm, a clock tower, chrono lamps,
--     floating gears and time crystals, and monuments from the eras ahead on the berm.
--   Future (World 3): a sunken spaceport plaza. White tiles with glowing seams and dark
--     walkways, a hologram stage for events with a globe and orbiting lights, white terraces,
--     a beacon tower with the World's sign, holo lamps, hovering drones, a glass skyline on the
--     berm, and World 3's runway models (rockets, domes, turbines) once they are imported.
-- Cosmetic only. A themed hub's floor is its walkable floor (FieldBuilder skips the plain one).
-- Parts with Spin/SpinPivot/Bob/Pulse attributes are animated on each client
-- (TrainingStadiumClient).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Field = require(ReplicatedStorage:WaitForChild("FieldConfig"))
local Training = require(ReplicatedStorage:WaitForChild("TrainingConfig"))
local RunwayDecor = require(script.Parent:WaitForChild("RunwayDecor"))

local HubDecor = {}
local M = Enum.Material

local function kit(folder, frame)
 local k = {}
 function k.box(name, size, position, color, material, collide, rotation)
  local p = Instance.new("Part")
  p.Name, p.Size = name, size
  p.CFrame = frame * CFrame.new(position) * (rotation or CFrame.identity)
  p.Anchored, p.CanTouch = true, false
  p.CanCollide, p.CanQuery = collide ~= false, collide ~= false
  p.Material, p.Color = material or M.SmoothPlastic, color
  p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
  p.Parent = folder
  return p
 end
 -- A box spanning x0..x1, y0..y1, z0..z1.
 function k.block(name, x0, x1, y0, y1, z0, z1, color, material, collide)
  return k.box(name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
   color, material, collide)
 end
 -- A flush, non-colliding patch on the floor (layer lifts overlapping patches apart).
 function k.patch(name, x0, x1, z0, z1, color, material, layer)
  local lift = 0.02 * (layer or 1)
  return k.block(name, x0, x1, 0, lift + 0.02, z0, z1, color, material, false)
 end
 function k.disc(name, center, radius, color, material, layer)
  local lift = 0.02 * (layer or 1)
  local p = k.box(name, Vector3.new(lift + 0.02, radius * 2, radius * 2), center + Vector3.new(0, (lift + 0.02) / 2, 0),
   color, material, false, CFrame.Angles(0, 0, math.pi / 2))
  p.Shape = Enum.PartType.Cylinder
  return p
 end
 function k.wedge(name, size, position, color, material, rotation)
  local p = Instance.new("WedgePart")
  p.Name, p.Size = name, size
  p.CFrame = frame * CFrame.new(position) * (rotation or CFrame.identity)
  p.Anchored, p.CanTouch = true, false
  p.Material, p.Color = material or M.SmoothPlastic, color
  p.Parent = folder
  return p
 end
 -- An upright cylinder (column, tower) standing on y0.
 function k.column(name, center, radius, y0, y1, color, material, collide)
  local p = k.box(name, Vector3.new(y1 - y0, radius * 2, radius * 2), Vector3.new(center.X, (y0 + y1) / 2, center.Z),
   color, material, collide, CFrame.Angles(0, 0, math.pi / 2))
  p.Shape = Enum.PartType.Cylinder
  return p
 end
 return k
end

-- Footprints of hub contents, for laying paths up to them: a Training Ground's scenery reaches
-- about 21 studs from its plate toward its door and 16 either side; a display's front row is
-- about 35 studs wide.
local CAGE_DOOR_REACH, CAGE_HALF_WIDTH = 22, 16
local DISPLAY_HALF_WIDTH = 18

-- How far the hub floor reaches from the tee line on one side (sign -1 left, 1 right); the
-- hub can be wider on one side (WorldConfig hub.left / hub.right).
local function edge(config, sign)
 return sign == -1 and config.left or config.right
end

-- Where a hub's paths lead: the x of the lane along this World's Training Ground doors (left)
-- and how far back the cages reach, then the same for the item displays (right).
local function layoutExtents(config, worldId)
 local doorX, cagesEnd = -config.left, 0
 local layout = Training.GetHub(worldId)
 for _, id in layout and layout.grounds or {} do
  local plate = Training.GetPlatePosition(Training.Get(id), worldId)
  doorX = math.max(doorX, plate.X + CAGE_DOOR_REACH)
  cagesEnd = math.max(cagesEnd, plate.Z + CAGE_HALF_WIDTH)
 end
 local displayX, displaysEnd = config.right, 0
 for _, display in config.displays or {} do
  displayX = math.min(displayX, display.position.X)
  displaysEnd = math.max(displaysEnd, display.position.Z + DISPLAY_HALF_WIDTH)
 end
 return doorX, cagesEnd, displayX, displaysEnd
end

-- The runway's outer ground is 9 studs above the ground (RunwayDecor: wallHeight - 3, on a frame
-- at Field.GroundTop); the hub frame sits 0.1 higher.
local BERM_TOP = 8.9
local BERM_REACH = 418 -- matches the runway's outer ground (to x 418 either side)
local BERM_BACK = 520
local WALL_HEIGHT, BARRIER_HEIGHT = 4, 14 -- perimeter wall, then an invisible barrier above it
local BLEACHER_DEPTH, TIERS = 15, 5

-- Stepped stands between `inner` and `inner + depth` along one axis, rising away from the field.
-- axis "x": side stands (sign picks the side, span = z0..z1); axis "z": the back stand (span = x0..x1).
-- look: step color/material and alternating seat colors/materials.
local function bleachers(k, axis, sign, inner, span0, span1, look)
 local step = BLEACHER_DEPTH / TIERS
 local rise = BERM_TOP / TIERS
 for tier = 1, TIERS do
  local near, far = inner + (tier - 1) * step, inner + BLEACHER_DEPTH
  local top = tier * rise
  local seatColor, seatMaterial = look.seats[tier % 2 + 1], look.seatMaterials[tier % 2 + 1]
  if axis == "x" then
   local x0, x1 = math.min(sign * near, sign * far), math.max(sign * near, sign * far)
   k.block("StandStep", x0, x1, -Field.GroundThickness, top, span0, span1, look.step, look.stepMaterial)
   local seatX = sign * (near + 0.6)
   k.block("Seats", seatX - 0.5, seatX + 0.5, top, top + 0.45, span0 + 0.5, span1 - 0.5, seatColor, seatMaterial, false)
  else
   k.block("StandStep", span0, span1, -Field.GroundThickness, top, near, far, look.step, look.stepMaterial)
   k.block("Seats", span0 + 0.5, span1 - 0.5, top, top + 0.45, near + 0.1, near + 1.1, seatColor, seatMaterial, false)
  end
 end
end

-- The perimeter wall on both sides and across the back with a cap and an invisible barrier
-- above it, the stands behind it, and the berm level with the runway's outer ground, so the hub
-- sits in a bowl. Returns the stands' outer edge on each side ({[-1] = left, [1] = right}, as
-- distances from the tee line) and the back stand's far z.
local function bowl(k, config, look)
 local depth = config.depth
 local left, right = config.left, config.right
 for _, sign in {-1, 1} do
  local x = sign * (edge(config, sign) + 0.5)
  k.block("OutfieldWall", x - 0.5, x + 0.5, 0, WALL_HEIGHT, 0, depth + 1, look.wall, look.wallMaterial)
  k.block("WallCap", x - 0.6, x + 0.6, WALL_HEIGHT, WALL_HEIGHT + 0.3, 0, depth + 1, look.cap)
  k.block("Barrier", x - 0.5, x + 0.5, WALL_HEIGHT, BARRIER_HEIGHT, 0, depth + 1, look.wall).Transparency = 1
 end
 k.block("OutfieldWall", -left - 1, right + 1, 0, WALL_HEIGHT, depth, depth + 1, look.wall, look.wallMaterial)
 k.block("WallCap", -left - 1, right + 1, WALL_HEIGHT, WALL_HEIGHT + 0.3, depth - 0.1, depth + 1.1, look.cap)
 k.block("Barrier", -left - 1, right + 1, WALL_HEIGHT, BARRIER_HEIGHT, depth, depth + 1, look.wall).Transparency = 1
 for _, sign in {-1, 1} do bleachers(k, "x", sign, edge(config, sign) + 1, 4, depth - 4, look) end
 bleachers(k, "z", 1, depth + 1, -left - 1, right + 1, look)
 local outer, backFar = {}, depth + 1 + BLEACHER_DEPTH
 for _, sign in {-1, 1} do
  local inner = edge(config, sign) + 1
  outer[sign] = inner + BLEACHER_DEPTH
  local function sideBlock(x0, x1, z0, z1)
   k.block("Berm", math.min(sign * x0, sign * x1), math.max(sign * x0, sign * x1), -Field.GroundThickness, BERM_TOP, z0, z1,
    look.berm, look.bermMaterial)
  end
  sideBlock(outer[sign], BERM_REACH, 0, BERM_BACK) -- beyond the side stands
  sideBlock(inner, outer[sign], 0, 4) -- the corners the stands leave open
  sideBlock(inner, outer[sign], depth - 4, backFar)
 end
 k.block("Berm", -outer[-1], outer[1], -Field.GroundThickness, BERM_TOP, backFar, BERM_BACK, look.berm, look.bermMaterial)
 return outer, backFar
end

-- ---------- Home Field ----------

local GRASS_A, GRASS_B = Color3.fromRGB(96, 172, 80), Color3.fromRGB(82, 154, 68)
local DIRT = Color3.fromRGB(178, 126, 82)
local CHALK = Color3.fromRGB(248, 248, 244)
local WALL_PAD = Color3.fromRGB(30, 88, 54)
local WALL_CAP = Color3.fromRGB(255, 205, 50)
local BERM = Color3.fromRGB(88, 152, 72)
local BERM_ACCENT = Color3.fromRGB(215, 249, 112)
local ALUMINUM = Color3.fromRGB(198, 202, 208)
local STEEL = Color3.fromRGB(120, 126, 134)
local SEATS = {Color3.fromRGB(204, 52, 48), Color3.fromRGB(36, 66, 144)}
local BUNTING = {Color3.fromRGB(212, 40, 46), Color3.fromRGB(246, 246, 246), Color3.fromRGB(32, 72, 164)}
local FOUL_POLE = Color3.fromRGB(255, 214, 40)
local BOARD = Color3.fromRGB(24, 58, 40)
local HOME_FIELD_BOWL = {wall = WALL_PAD, wallMaterial = M.Fabric, cap = WALL_CAP,
 step = ALUMINUM, stepMaterial = M.Metal, seats = SEATS, seatMaterials = {M.SmoothPlastic, M.SmoothPlastic},
 berm = BERM, bermMaterial = M.Grass}

-- A row of diamond pennants hanging from a cord along a wall top, from a to b (frame space).
local function bunting(k, a, b)
 local length = (b - a).Magnitude
 local along = (b - a).Unit
 local cord = k.box("BuntingCord", Vector3.new(0.12, 0.12, length), (a + b) / 2, STEEL, M.SmoothPlastic, false,
  CFrame.lookAt(Vector3.zero, along).Rotation)
 cord.CastShadow = false
 local count = math.floor(length / 4)
 for i = 0, count - 1 do
  local point = a + along * ((i + 0.5) * length / count) - Vector3.new(0, 0.8, 0)
  local flag = k.box("Pennant", Vector3.new(1.1, 1.1, 0.08), point, BUNTING[i % #BUNTING + 1], M.Fabric, false,
   CFrame.lookAt(Vector3.zero, along:Cross(Vector3.yAxis)).Rotation * CFrame.Angles(0, 0, math.pi / 4))
  flag.CastShadow = false
 end
end

local function lightTower(k, position, target)
 local height = 46
 k.block("TowerFoot", position.X - 1.5, position.X + 1.5, position.Y - 1, position.Y + 1, position.Z - 1.5, position.Z + 1.5, STEEL, M.Concrete)
 k.box("TowerPole", Vector3.new(1.2, height, 1.2), position + Vector3.new(0, height / 2, 0), STEEL, M.Metal)
 local head = position + Vector3.new(0, height, 0)
 -- The light bank tilts down toward the field; its front face is the lit side.
 local aim = (target - head).Unit
 local rotation = CFrame.lookAt(Vector3.zero, aim).Rotation
 k.box("TowerFrame", Vector3.new(11, 6, 1), head + aim * 0.6, STEEL, M.Metal, false, rotation)
 local panel = k.box("TowerLights", Vector3.new(10, 5, 0.4), head + aim * 1.25, Color3.fromRGB(255, 250, 225), M.Neon, false, rotation)
 local light = Instance.new("SpotLight")
 light.Face, light.Angle, light.Range, light.Brightness = Enum.NormalId.Front, 70, 120, 2.5
 light.Color, light.Shadows = Color3.fromRGB(255, 248, 230), false
 light.Parent = panel
end

local function scoreboard(k, center)
 local legY0, legY1 = BERM_TOP, BERM_TOP + 10
 for _, x in {-18, 18} do
  k.block("ScoreboardLeg", center.X + x - 1, center.X + x + 1, legY0, legY1, center.Z - 1, center.Z + 1, STEEL, M.Metal)
 end
 local board = k.box("Scoreboard", Vector3.new(56, 22, 2), Vector3.new(center.X, legY1 + 11, center.Z), BOARD, M.SmoothPlastic)
 k.box("ScoreboardTrim", Vector3.new(58, 23.5, 1.6), Vector3.new(center.X, legY1 + 11, center.Z + 0.4), WALL_CAP, M.SmoothPlastic, false)
 local gui = Instance.new("SurfaceGui")
 gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 20, 0
 gui.Parent = board
 local function text(content, y, height, color)
  local label = Instance.new("TextLabel")
  label.BackgroundTransparency, label.Font, label.TextScaled = 1, Enum.Font.GothamBlack, true
  label.Text, label.TextColor3 = content, color
  label.Position, label.Size = UDim2.fromScale(0.05, y), UDim2.fromScale(0.9, height)
  label.Parent = gui
  return label
 end
 text("HOME FIELD", 0.06, 0.36, WALL_CAP)
 text("WORLD 1", 0.44, 0.14, CHALK)
 text("BALL ● ● ●     STRIKE ● ●     OUT ● ●", 0.66, 0.12, Color3.fromRGB(255, 150, 60))
 text("WELCOME, SLUGGERS!", 0.82, 0.11, CHALK)
end

local function homeField(k, folder, frame, config, worldId)
 local depth = config.depth

 -- The field: mowing stripes, the walkable floor.
 local stripes = 12
 for i = 1, stripes do
  k.block("Grass", -config.left, config.right, -Field.GroundThickness, 0, (i - 1) * depth / stripes, i * depth / stripes,
   i % 2 == 0 and GRASS_A or GRASS_B, M.Grass)
 end

 -- Dirt paths: a circle behind the batting area, a path across the front, a lane along the
 -- Training Ground doors (left) and one in front of the item displays (right), and a path up
 -- the middle to the event diamond. A home plate marks the spawn.
 k.disc("BatterCircle", Vector3.new(0, 0, 10), 10, DIRT, M.Ground, 1)
 local doorX, cagesEnd, displayX, displaysEnd = layoutExtents(config, worldId)
 k.patch("FrontPath", doorX, displayX - 2, 20, 28, DIRT, M.Ground, 1)
 k.patch("CageLane", doorX, doorX + 8, 20, cagesEnd, DIRT, M.Ground, 1)
 k.patch("DisplayLane", displayX - 10, displayX - 2, 20, displaysEnd, DIRT, M.Ground, 1)
 local spawnZ = 60
 k.patch("HomePlate", -2.5, 2.5, spawnZ, spawnZ + 2.5, CHALK, M.SmoothPlastic, 3)
 k.box("HomePlatePoint", Vector3.new(3.54, 0.06, 3.54), Vector3.new(0, 0.05, spawnZ), CHALK, M.SmoothPlastic, false,
  CFrame.Angles(0, math.pi / 4, 0))

 -- The open middle, kept clear: an infield diamond for events (dirt with an inner grass
 -- square, white bases and a pitcher's mound) and the World portal's pad, in line with the item displays.
 local event = config.eventArea
 if event then
  local center, reach = event.center, event.size / math.sqrt(2)
  k.patch("CenterPath", -4, 4, 18, center.Z - reach + 2, DIRT, M.Ground, 1)
  local diamond = CFrame.Angles(0, math.pi / 4, 0)
  k.box("EventDiamond", Vector3.new(event.size, 0.04, event.size), center + Vector3.new(0, 0.02, 0), DIRT, M.Ground, false, diamond)
  local grassSize = event.size * 0.62
  k.box("EventInfield", Vector3.new(grassSize, 0.08, grassSize), center + Vector3.new(0, 0.04, 0), GRASS_A, M.Grass, false, diamond)
  for _, corner in {Vector3.new(0, 0, -reach + 3), Vector3.new(reach - 3, 0, 0), Vector3.new(0, 0, reach - 3), Vector3.new(-reach + 3, 0, 0)} do
   k.box("Base", Vector3.new(2.2, 0.3, 2.2), center + corner + Vector3.new(0, 0.15, 0), CHALK, M.SmoothPlastic, false, diamond)
  end
  k.disc("PitchersMound", center, 5, DIRT, M.Ground, 5)
  k.box("PitchersRubber", Vector3.new(2.4, 0.16, 0.6), center + Vector3.new(0, 0.18, 0), CHALK, M.SmoothPlastic, false)
 end
 local portal = config.portalPad
 if portal then
  k.disc("PortalPadRing", portal.center, portal.radius + 0.8, WALL_CAP, M.SmoothPlastic, 3)
  k.disc("PortalPad", portal.center, portal.radius, Color3.fromRGB(196, 192, 184), M.Concrete, 4)
 end

 -- Padded outfield wall with a gold cap and bunting, bleachers on both sides and across the
 -- back, and the grassy berm.
 local outer, backFar = bowl(k, config, HOME_FIELD_BOWL)
 for _, sign in {-1, 1} do
  local x = sign * (edge(config, sign) + 0.5)
  bunting(k, Vector3.new(x - sign * 0.7, WALL_HEIGHT + 0.2, 2), Vector3.new(x - sign * 0.7, WALL_HEIGHT + 0.2, depth - 1))
 end
 bunting(k, Vector3.new(-config.left + 1, WALL_HEIGHT + 0.2, depth - 0.2), Vector3.new(config.right - 1, WALL_HEIGHT + 0.2, depth - 0.2))

 -- Foul poles where the runway walls begin, light towers on the berm corners, the scoreboard.
 for _, sign in {-1, 1} do
  local pole = k.box("FoulPole", Vector3.new(40, 1.2, 1.2), Vector3.new(sign * 90, 20, 1.5), FOUL_POLE, M.SmoothPlastic, true,
   CFrame.Angles(0, 0, math.pi / 2))
  pole.Shape = Enum.PartType.Cylinder
  k.box("FoulPoleWing", Vector3.new(0.2, 16, 2.4), Vector3.new(sign * (90 - 1.8), 30, 1.5), FOUL_POLE, M.SmoothPlastic, false)
  local target = Vector3.new(0, 0, depth / 2)
  lightTower(k, Vector3.new(sign * (outer[sign] + 8), BERM_TOP, 8), target)
  lightTower(k, Vector3.new(sign * (outer[sign] + 8), BERM_TOP, backFar + 6), target)
 end
 scoreboard(k, Vector3.new(0, 0, backFar + 18))

 -- A treeline and rolling hills on the berm.
 local rng = Random.new(1906)
 local colors = {color = BERM, accent = BERM_ACCENT}
 local placed = 0
 for i = 1, 70 do
  local sign = i % 2 == 0 and 1 or -1
  local position
  if i % 3 == 0 then
   position = Vector3.new(rng:NextNumber(-outer[-1] + 20, outer[1] - 20), BERM_TOP, rng:NextNumber(backFar + 45, 420))
  else
   position = Vector3.new(sign * rng:NextNumber(outer[sign] + 22, 380), BERM_TOP, rng:NextNumber(14, 440))
  end
  local kind = i % 5 == 0 and "bush" or "tree"
  if RunwayDecor.PlaceMesh(folder, frame, kind, position, kind == "tree" and rng:NextNumber(1.6, 2.4) or 1.6, i, colors) then
   placed += 1
  end
 end
 for i = 1, 10 do
  local sign = i % 2 == 0 and 1 or -1
  local position = i <= 6 and Vector3.new(sign * rng:NextNumber(300, 390), BERM_TOP, rng:NextNumber(60, 480))
   or Vector3.new(rng:NextNumber(-260, 260), BERM_TOP, rng:NextNumber(440, 500))
  RunwayDecor.PlaceMesh(folder, frame, "hills", position, 1, i, colors)
 end
 return placed
end

-- ---------- Time Travel ----------

local TILE_A, TILE_B = Color3.fromRGB(122, 106, 186), Color3.fromRGB(104, 88, 166)
local WALKWAY = Color3.fromRGB(236, 204, 136)
local BRASS = Color3.fromRGB(226, 176, 80)
local BRASS_DARK = Color3.fromRGB(170, 122, 54)
local CREAM = Color3.fromRGB(250, 244, 226)
local INK = Color3.fromRGB(44, 36, 70)
local CHRONO = Color3.fromRGB(90, 230, 255) -- the cyan glow of time energy
local TERRACE = Color3.fromRGB(80, 68, 124)
local TOWER = Color3.fromRGB(104, 88, 160)
local VOID = Color3.fromRGB(58, 48, 96)
local STONE = Color3.fromRGB(150, 146, 140)
local SANDSTONE = Color3.fromRGB(228, 196, 130)
local MARBLE = Color3.fromRGB(242, 240, 234)
local LACQUER = Color3.fromRGB(204, 44, 40)
local TIME_TRAVEL_BOWL = {wall = Color3.fromRGB(66, 54, 108), wallMaterial = M.Slate, cap = BRASS,
 step = TERRACE, stepMaterial = M.Slate, seats = {BRASS, CHRONO}, seatMaterials = {M.SmoothPlastic, M.Neon},
 berm = VOID, bermMaterial = M.Slate}
local ROMAN = {"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"}

-- Clock hands turn clockwise about the clock centre: Spin is in degrees per second about the
-- part's SpinAxis, around SpinPivot (part space).
local function hand(part, degreesPerSecond, axis, pivot)
 part:SetAttribute("Spin", degreesPerSecond)
 part:SetAttribute("SpinAxis", axis)
 part:SetAttribute("SpinPivot", pivot)
end

-- A clock face flat on the floor, 12 at +Z (read from the spawn side), with Roman numerals and
-- turning hands.
local function floorClock(k, center, radius)
 k.disc("ClockRim", center, radius + 2, BRASS, M.SmoothPlastic, 1)
 k.disc("ClockFace", center, radius, CREAM, M.SmoothPlastic, 2)
 -- Bands from the rim inward: hour marks, numerals, then a brass ring around the inner dial.
 k.disc("ClockRing", center, radius - 13, BRASS, M.SmoothPlastic, 3)
 k.disc("ClockInner", center, radius - 13.8, CREAM, M.SmoothPlastic, 4)
 local numerals = k.box("ClockNumerals", Vector3.new(radius * 2, 0.05, radius * 2), center + Vector3.new(0, 0.14, 0), CREAM,
  M.SmoothPlastic, false)
 numerals.Transparency = 1
 local gui = Instance.new("SurfaceGui")
 gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = Enum.NormalId.Top, Enum.SurfaceGuiSizingMode.PixelsPerStud, 10, 0.3
 gui.Parent = numerals
 for hour = 1, 12 do
  local angle = hour * math.pi / 6
  local direction = Vector3.new(-math.sin(angle), 0, math.cos(angle)) -- 12 at +Z, 3 at -X
  local long = hour % 3 == 0
  k.box("HourMark", Vector3.new(long and 2.2 or 1.2, 0.06, long and 4 or 2.6), center + direction * (radius - 2.6) + Vector3.new(0, 0.12, 0),
   INK, M.SmoothPlastic, false, CFrame.lookAt(Vector3.zero, direction).Rotation)
  -- The numeral sits between the marks and the inner ring. On a Top-face SurfaceGui the
  -- canvas's up is the part's -X; the part is turned a quarter turn so up is +Z and right is
  -- -X, reading upright from the spawn side.
  local label = Instance.new("TextLabel")
  local spot = direction * (radius - 8.5)
  label.AnchorPoint, label.Size = Vector2.new(0.5, 0.5), UDim2.fromOffset(52, 40)
  label.Position = UDim2.fromScale(0.5 - spot.X / (radius * 2), 0.5 - spot.Z / (radius * 2))
  label.BackgroundTransparency, label.Font, label.TextScaled = 1, Enum.Font.FredokaOne, true
  label.Text, label.TextColor3 = ROMAN[hour], INK
  label.Parent = gui
 end
 numerals.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
 -- Hands point along their local -Z from the centre, so the pivot is half a length behind.
 for _, spec in {{"MinuteHand", 1.6, radius - 4, -6, 0.2}, {"HourHand", 2.6, radius - 13, -0.5, 0.22}} do
  local length = spec[3]
  local back = 2.5
  local angle = spec[1] == "MinuteHand" and 2 * math.pi / 12 * 2 or 2 * math.pi / 12 * 10
  local direction = Vector3.new(-math.sin(angle), 0, math.cos(angle))
  local part = k.box(spec[1], Vector3.new(spec[2], 0.08, length + back), center + Vector3.new(0, spec[5], 0), INK, M.SmoothPlastic, false,
   CFrame.lookAt(Vector3.zero, direction).Rotation * CFrame.new(0, 0, -(length - back) / 2))
  hand(part, spec[4], Vector3.yAxis, Vector3.new(0, 0, (length - back) / 2))
 end
 k.disc("ClockCap", center, 2.4, BRASS, M.SmoothPlastic, 13)
end

-- A spinning gear: the imported RunwayAssets.HubGear (tools/blender/world_portal.py) when it
-- exists, otherwise a brass disc. rotation turns the gear's face from facing +Z.
local function gear(k, folder, frame, position, diameter, rotation, speed)
 local assets = ServerStorage:FindFirstChild("RunwayAssets")
 local template = assets and assets:FindFirstChild("HubGear")
 if template then
  local model = template:Clone()
  local _, size = model:GetBoundingBox()
  model:ScaleTo(model:GetScale() * diameter / math.max(size.X, size.Y))
  model:PivotTo(frame * CFrame.new(position) * rotation)
  for _, part in model:GetDescendants() do
   if part:IsA("BasePart") then
    part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
    part.Color, part.Material = BRASS, M.SmoothPlastic
    part:SetAttribute("Spin", speed)
    part:SetAttribute("SpinAxis", Vector3.zAxis)
   end
  end
  model.Parent = folder
  return
 end
 local disc = k.box("Gear", Vector3.new(1.2, diameter, diameter), position, BRASS, M.SmoothPlastic, false,
  rotation * CFrame.Angles(0, math.pi / 2, 0))
 disc.Shape = Enum.PartType.Cylinder
 disc:SetAttribute("Spin", speed)
 disc:SetAttribute("SpinAxis", Vector3.xAxis)
end

-- A lamp post on the berm: brass pole and a glowing chrono orb.
local function chronoLamp(k, position)
 k.column("LampBase", position, 2.2, position.Y, position.Y + 2, BRASS_DARK, M.SmoothPlastic, true)
 k.column("LampPost", position, 0.8, position.Y + 2, position.Y + 30, BRASS, M.Metal, true)
 k.column("LampCollar", position, 1.8, position.Y + 29.5, position.Y + 31, BRASS_DARK, M.SmoothPlastic, false)
 local orb = k.box("LampOrb", Vector3.new(5, 5, 5), position + Vector3.new(0, 33.5, 0), CHRONO, M.Neon, false)
 orb.Shape = Enum.PartType.Ball
 orb:SetAttribute("Pulse", 0.4)
 local light = Instance.new("PointLight")
 light.Color, light.Range, light.Brightness, light.Shadows = CHRONO, 40, 1.5, false
 light.Parent = orb
end

-- A floating time crystal that bobs and glows.
local function timeCrystal(k, position, height, phase)
 local crystal = k.box("TimeCrystal", Vector3.new(height * 0.35, height, height * 0.35), position, CHRONO, M.Neon, false,
  CFrame.Angles(0, phase, 0.35))
 crystal.Transparency = 0.15
 crystal:SetAttribute("Bob", 1.5)
 crystal:SetAttribute("BobSpeed", 1.2)
 crystal:SetAttribute("Phase", phase)
end

-- The clock tower behind the back terraces, facing the plaza (-Z), with a turning clock and the
-- World's sign.
local function clockTower(k, base)
 local x, y, z = base.X, base.Y, base.Z
 k.block("TowerFoot", x - 12, x + 12, y, y + 6, z - 12, z + 12, TERRACE, M.Slate)
 k.block("TowerShaft", x - 8, x + 8, y + 6, y + 50, z - 8, z + 8, TOWER, M.SmoothPlastic)
 for _, cx in {-1, 1} do
  for _, cz in {-1, 1} do
   k.block("TowerPillar", x + cx * 8 - 1.2, x + cx * 8 + 1.2, y + 6, y + 50, z + cz * 8 - 1.2, z + cz * 8 + 1.2, BRASS, M.SmoothPlastic)
  end
 end
 k.block("TowerCornice", x - 10, x + 10, y + 50, y + 52, z - 10, z + 10, BRASS, M.SmoothPlastic)
 k.block("TowerBelfry", x - 7, x + 7, y + 52, y + 61, z - 7, z + 7, TOWER, M.SmoothPlastic)
 k.block("BelfryGlow", x - 4.5, x + 4.5, y + 54, y + 59.5, z - 7.2, z + 7.2, CHRONO, M.Neon, false)
 k.block("BelfryGlowSide", x - 7.2, x + 7.2, y + 54, y + 59.5, z - 4.5, z + 4.5, CHRONO, M.Neon, false)
 for step = 0, 3 do
  local w = 9 - step * 2.2
  k.block("TowerSpire", x - w, x + w, y + 61 + step * 3, y + 64 + step * 3, z - w, z + w, step % 2 == 0 and BRASS or TOWER, M.SmoothPlastic)
 end
 local top = k.box("SpireOrb", Vector3.new(4, 4, 4), Vector3.new(x, y + 75.5, z), CHRONO, M.Neon, false)
 top.Shape = Enum.PartType.Ball

 -- The clock on the front face.
 local clock = Vector3.new(x, y + 38, z - 8)
 local face = CFrame.Angles(0, math.pi / 2, 0) -- cylinder axis along Z
 local rim = k.box("TowerClockRim", Vector3.new(0.8, 15.6, 15.6), clock + Vector3.new(0, 0, -0.3), BRASS, M.SmoothPlastic, false, face)
 rim.Shape = Enum.PartType.Cylinder
 local dial = k.box("TowerClockFace", Vector3.new(0.8, 13.6, 13.6), clock + Vector3.new(0, 0, -0.6), CREAM, M.SmoothPlastic, false, face)
 dial.Shape = Enum.PartType.Cylinder
 for hour = 1, 12 do
  local angle = hour * math.pi / 6
  -- Viewed from the plaza (looking +Z), 3 o'clock is toward -X.
  local direction = Vector3.new(-math.sin(angle), math.cos(angle), 0)
  local long = hour % 3 == 0
  k.box("TowerHourMark", Vector3.new(long and 0.9 or 0.5, long and 1.8 or 1.2, 0.2), clock + direction * 5.4 + Vector3.new(0, 0, -1.1),
   INK, M.SmoothPlastic, false, CFrame.fromAxisAngle(Vector3.zAxis, angle))
 end
 -- Hands point along their local +Y from the centre; positive Spin about +Z turns them
 -- clockwise as seen from the plaza.
 for _, spec in {{"TowerMinuteHand", 0.5, 5.4, 6, -1.45}, {"TowerHourHand", 0.8, 3.6, 0.5, -1.3}} do
  local length, back = spec[3], 1
  local part = k.box(spec[1], Vector3.new(spec[2], length + back, 0.2), clock + Vector3.new(0, (length - back) / 2, spec[5]), INK,
   M.SmoothPlastic, false)
  hand(part, spec[4], Vector3.zAxis, Vector3.new(0, -(length - back) / 2, 0))
 end
 local cap = k.box("TowerClockCap", Vector3.new(0.6, 1.4, 1.4), clock + Vector3.new(0, 0, -1.7), BRASS, M.SmoothPlastic, false, face)
 cap.Shape = Enum.PartType.Cylinder

 -- The World's sign on the shaft below the clock.
 local board = k.box("TowerSign", Vector3.new(14, 8, 0.6), Vector3.new(x, y + 20, z - 8.4), INK, M.SmoothPlastic, false)
 k.box("TowerSignTrim", Vector3.new(15, 9, 0.4), Vector3.new(x, y + 20, z - 8.2), BRASS, M.SmoothPlastic, false)
 local gui = Instance.new("SurfaceGui")
 gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 24, 0
 gui.Parent = board
 for _, line in {{"TIME TRAVEL", 0.08, 0.5, BRASS}, {"WORLD 2", 0.62, 0.3, CHRONO}} do
  local label = Instance.new("TextLabel")
  label.BackgroundTransparency, label.Font, label.TextScaled = 1, Enum.Font.FredokaOne, true
  label.Text, label.TextColor3 = line[1], line[4]
  label.Position, label.Size = UDim2.fromScale(0.05, line[2]), UDim2.fromScale(0.9, line[3])
  label.Parent = gui
 end
end

-- Monuments from the eras ahead, standing on the berm (base.Y). Each faces the plaza.
local MONUMENTS = {}
function MONUMENTS.stoneCircle(k, base)
 for i = 0, 5 do
  local angle = i * math.pi / 3
  local around = Vector3.new(math.cos(angle), 0, math.sin(angle))
  local center = base + around * 13
  local facing = CFrame.lookAt(Vector3.zero, around).Rotation
  for _, side in {-2.4, 2.4} do
   k.box("Megalith", Vector3.new(2.6, 12, 2.6), center + facing * Vector3.new(side, 0, 0) + Vector3.new(0, 6, 0), STONE, M.Slate, true, facing)
  end
  k.box("Lintel", Vector3.new(8, 2.2, 2.8), center + Vector3.new(0, 13.1, 0), STONE, M.Slate, true, facing)
 end
 k.box("AltarStone", Vector3.new(7, 2, 4), base + Vector3.new(0, 1, 0), STONE, M.Slate, true)
end
function MONUMENTS.pyramid(k, base)
 for tier = 0, 6 do
  local w = 22 - tier * 3.1
  k.block("PyramidTier", base.X - w, base.X + w, base.Y + tier * 4.4, base.Y + (tier + 1) * 4.4, base.Z - w, base.Z + w, SANDSTONE, M.Sandstone)
 end
 k.block("Capstone", base.X - 1.6, base.X + 1.6, base.Y + 30.8, base.Y + 34, base.Z - 1.6, base.Z + 1.6, BRASS, M.SmoothPlastic)
 for _, side in {-1, 1} do
  local p = base + Vector3.new(side * 30, 0, -10)
  k.block("Obelisk", p.X - 2, p.X + 2, p.Y, p.Y + 24, p.Z - 2, p.Z + 2, SANDSTONE, M.Sandstone)
  k.block("ObeliskTip", p.X - 1.2, p.X + 1.2, p.Y + 24, p.Y + 26.5, p.Z - 1.2, p.Z + 1.2, BRASS, M.SmoothPlastic)
 end
end
function MONUMENTS.temple(k, base, facing)
 local f = CFrame.new(base) * facing
 local function piece(name, size, offset, color, material)
  return k.box(name, size, (f * CFrame.new(offset)).Position, color, material, true, facing)
 end
 piece("TempleBase", Vector3.new(34, 2, 22), Vector3.new(0, 1, 0), MARBLE, M.Marble)
 piece("TempleStep", Vector3.new(36, 1, 24), Vector3.new(0, 0.5, 0), MARBLE, M.Marble)
 for row = -1, 1, 2 do
  for column = 0, 5 do
   local p = (f * CFrame.new(-14 + column * 5.6, 2, row * 8)).Position
   k.column("TempleColumn", p, 1.3, p.Y, p.Y + 16, MARBLE, M.Marble, true)
  end
 end
 piece("TempleBeam", Vector3.new(34, 2.4, 20), Vector3.new(0, 19.2, 0), MARBLE, M.Marble)
 piece("TempleFrieze", Vector3.new(34.4, 0.8, 20.4), Vector3.new(0, 18.4, 0), BRASS, M.SmoothPlastic)
 -- A gable roof: two wedges, each tall at the ridge (a wedge is tallest at its local +Z).
 for _, side in {-1, 1} do
  k.wedge("TempleRoof", Vector3.new(34, 4.5, 10.5), (f * CFrame.new(0, 22.6, side * 5.25)).Position, MARBLE, M.Marble,
   facing * CFrame.Angles(0, side == 1 and math.pi or 0, 0))
 end
end
function MONUMENTS.torii(k, base, facing)
 local f = CFrame.new(base) * facing
 for _, side in {-1, 1} do
  local p = (f * CFrame.new(side * 9, 0, 0)).Position
  k.column("ToriiPost", p, 1.3, p.Y, p.Y + 22, LACQUER, M.SmoothPlastic, true)
  k.column("ToriiFoot", p, 1.7, p.Y, p.Y + 2.5, INK, M.SmoothPlastic, true)
 end
 k.box("ToriiTie", Vector3.new(22, 1.8, 1.6), (f * CFrame.new(0, 16, 0)).Position, LACQUER, M.SmoothPlastic, true, facing)
 k.box("ToriiTop", Vector3.new(28, 2, 2.6), (f * CFrame.new(0, 22.6, 0)).Position, LACQUER, M.SmoothPlastic, true, facing)
 k.box("ToriiCap", Vector3.new(30, 1.2, 3), (f * CFrame.new(0, 24.2, 0)).Position, INK, M.SmoothPlastic, true, facing)
 k.box("ToriiPlaque", Vector3.new(3, 4, 0.6), (f * CFrame.new(0, 19.3, 0)).Position, INK, M.SmoothPlastic, true, facing)
end
function MONUMENTS.castle(k, base)
 k.column("CastleTower", base, 8, base.Y, base.Y + 28, STONE, M.Cobblestone, true)
 k.column("CastleRim", base, 9, base.Y + 28, base.Y + 30, STONE, M.Cobblestone, true)
 for i = 0, 9 do
  local angle = i * math.pi / 5
  local p = base + Vector3.new(math.cos(angle) * 8.2, 31.2, math.sin(angle) * 8.2)
  k.box("Merlon", Vector3.new(2.6, 2.4, 2.2), p, STONE, M.Cobblestone, true, CFrame.Angles(0, -angle, 0))
 end
 k.box("CastlePole", Vector3.new(0.5, 10, 0.5), base + Vector3.new(0, 35, 0), INK, M.Metal, false)
 k.box("CastleFlag", Vector3.new(0.15, 3.2, 5), base + Vector3.new(0, 38, 2.6), LACQUER, M.Fabric, false)
 -- The door faces the plaza (-X; the castle stands on the right side).
 k.block("CastleDoor", base.X - 8.3, base.X - 7.7, base.Y, base.Y + 7, base.Z - 2.5, base.Z + 2.5, Color3.fromRGB(96, 64, 40), M.WoodPlanks, false)
end

local function timeTravel(k, folder, frame, config, worldId)
 local depth = config.depth
 local width = config.left + config.right

 -- The plaza floor: checkered tiles with thin brass seams.
 local columns, rows = 9, 8
 for i = 0, columns - 1 do
  for j = 0, rows - 1 do
   k.block("Tile", -config.left + i * width / columns, -config.left + (i + 1) * width / columns, -Field.GroundThickness, 0,
    j * depth / rows, (j + 1) * depth / rows, (i + j) % 2 == 0 and TILE_A or TILE_B, M.SmoothPlastic)
  end
 end
 for i = 1, columns - 1 do
  local x = -config.left + i * width / columns
  k.patch("Seam", x - 0.3, x + 0.3, 0, depth, BRASS_DARK, M.SmoothPlastic, 1)
 end
 for j = 1, rows - 1 do
  local z = j * depth / rows
  k.patch("Seam", -config.left, config.right, z - 0.3, z + 0.3, BRASS_DARK, M.SmoothPlastic, 1)
 end

 -- Brass walkways to the cages, the displays and the clock, a glowing ring around the batting
 -- area, and a small clock rosette marking the spawn.
 k.disc("BatterRing", Vector3.new(0, 0, 10), 10.8, CHRONO, M.Neon, 2)
 k.disc("BatterCircle", Vector3.new(0, 0, 10), 10, WALKWAY, M.SmoothPlastic, 3)
 local doorX, cagesEnd, displayX, displaysEnd = layoutExtents(config, worldId)
 k.patch("FrontPath", doorX, displayX - 2, 20, 28, WALKWAY, M.SmoothPlastic, 2)
 k.patch("CageLane", doorX, doorX + 8, 20, cagesEnd, WALKWAY, M.SmoothPlastic, 2)
 k.patch("DisplayLane", displayX - 10, displayX - 2, 20, displaysEnd, WALKWAY, M.SmoothPlastic, 2)
 local spawnZ = 60
 k.disc("SpawnRosette", Vector3.new(0, 0, spawnZ), 3.4, BRASS, M.SmoothPlastic, 4)
 k.disc("SpawnDial", Vector3.new(0, 0, spawnZ), 2.7, CREAM, M.SmoothPlastic, 5)

 -- A giant clock face for events in the middle, and the World portal's pad.
 local event = config.eventArea
 if event then
  local radius = event.size / 2
  k.patch("CenterPath", -4, 4, 18, event.center.Z - radius - 1, WALKWAY, M.SmoothPlastic, 2)
  floorClock(k, event.center, radius)
 end
 local portal = config.portalPad
 if portal then
  k.disc("PortalPadGlow", portal.center, portal.radius + 1, CHRONO, M.Neon, 3)
  k.disc("PortalPadRing", portal.center, portal.radius, BRASS, M.SmoothPlastic, 4)
  k.disc("PortalPad", portal.center, portal.radius - 1.6, INK, M.SmoothPlastic, 5)
 end

 -- Slate wall with a brass cap and a glowing strip, terraces up to the berm.
 local outer, backFar = bowl(k, config, TIME_TRAVEL_BOWL)
 for _, sign in {-1, 1} do
  local x = sign * (edge(config, sign) - 0.1)
  k.block("WallGlow", x - 0.1, x + 0.1, 2.6, 3.1, 0, depth, CHRONO, M.Neon, false)
 end
 k.block("WallGlow", -config.left, config.right, 2.6, 3.1, depth - 0.1, depth + 0.1, CHRONO, M.Neon, false)

 -- The clock tower at the back, chrono lamps at the corners, monuments on the berm.
 clockTower(k, Vector3.new(0, BERM_TOP, backFar + 24))
 for _, sign in {-1, 1} do
  chronoLamp(k, Vector3.new(sign * (outer[sign] + 8), BERM_TOP, 8))
  chronoLamp(k, Vector3.new(sign * (outer[sign] + 8), BERM_TOP, backFar + 6))
 end
 local toPlazaLeft, toPlazaRight = CFrame.Angles(0, -math.pi / 2, 0), CFrame.Angles(0, math.pi / 2, 0)
 MONUMENTS.stoneCircle(k, Vector3.new(-(outer[-1] + 40), BERM_TOP, 40))
 MONUMENTS.pyramid(k, Vector3.new(-(outer[-1] + 52), BERM_TOP, 140))
 MONUMENTS.torii(k, Vector3.new(-(outer[-1] + 30), BERM_TOP, 226), toPlazaLeft)
 MONUMENTS.temple(k, Vector3.new(outer[1] + 42, BERM_TOP, 60), toPlazaRight)
 MONUMENTS.castle(k, Vector3.new(outer[1] + 40, BERM_TOP, 150))
 MONUMENTS.torii(k, Vector3.new(outer[1] + 30, BERM_TOP, 226), toPlazaRight)

 -- Floating gears and time crystals around the bowl.
 local rng = Random.new(2042)
 for i = 1, 10 do
  local sign = i % 2 == 0 and 1 or -1
  local position = i <= 6 and Vector3.new(sign * rng:NextNumber(outer[sign] + 10, outer[sign] + 90), rng:NextNumber(32, 52), rng:NextNumber(20, 220))
   or Vector3.new(sign * rng:NextNumber(28, 110), rng:NextNumber(36, 60), rng:NextNumber(backFar + 10, backFar + 50))
  local facing = i <= 6 and CFrame.Angles(0, sign * math.pi / 2, rng:NextNumber(-0.3, 0.3)) or CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, 0)
  gear(k, folder, frame, position, rng:NextNumber(10, 22), facing, (i % 3 == 0 and -1 or 1) * rng:NextNumber(10, 25))
 end
 for i = 1, 12 do
  local sign = i % 2 == 0 and 1 or -1
  local position = Vector3.new(sign * rng:NextNumber(outer[sign] + 15, outer[sign] + 110), BERM_TOP + rng:NextNumber(10, 26), rng:NextNumber(0, 300))
  timeCrystal(k, position, rng:NextNumber(5, 10), rng:NextNumber(0, 2 * math.pi))
 end
end

-- ---------- Future ----------

local PLAZA_A, PLAZA_B = Color3.fromRGB(230, 235, 243), Color3.fromRGB(214, 221, 233)
local SEAM = Color3.fromRGB(90, 224, 255) -- the cyan glow of World 3
local WALK = Color3.fromRGB(38, 48, 80)
local HULL = Color3.fromRGB(240, 243, 248) -- white composite panels
local GUNMETAL = Color3.fromRGB(64, 72, 92)
local HOLO = Color3.fromRGB(120, 236, 255)
local HOLO_PINK = Color3.fromRGB(255, 110, 214)
local SKY_GLASS = Color3.fromRGB(120, 170, 225)
local BEACON_RED = Color3.fromRGB(255, 72, 84)
local FUTURE_BOWL = {wall = HULL, wallMaterial = M.SmoothPlastic, cap = GUNMETAL,
 step = Color3.fromRGB(198, 206, 220), stepMaterial = M.Metal, seats = {HOLO, Color3.fromRGB(250, 251, 253)},
 seatMaterials = {M.Neon, M.SmoothPlastic}, berm = Color3.fromRGB(58, 66, 92), bermMaterial = M.Concrete}

-- A dark walkway patch with glowing edges along its long sides.
local function walkway(k, name, x0, x1, z0, z1)
 k.patch(name, x0, x1, z0, z1, WALK, M.SmoothPlastic, 2)
 if x1 - x0 >= z1 - z0 then
  k.patch(name .. "Edge", x0, x1, z0, z0 + 0.4, SEAM, M.Neon, 3)
  k.patch(name .. "Edge", x0, x1, z1 - 0.4, z1, SEAM, M.Neon, 3)
 else
  k.patch(name .. "Edge", x0, x0 + 0.4, z0, z1, SEAM, M.Neon, 3)
  k.patch(name .. "Edge", x1 - 0.4, x1, z0, z1, SEAM, M.Neon, 3)
 end
end

-- Lights circling a centre: `count` small glowing spheres on a tilted ring (tilt about X), each
-- turning about the centre (Spin with SpinPivot, so they orbit).
local function orbitLights(k, center, radius, tilt, count, color, speed)
 local axis = CFrame.Angles(tilt, 0, 0).UpVector
 for i = 1, count do
  local angle = 2 * math.pi * i / count
  local offset = CFrame.Angles(tilt, 0, 0):VectorToWorldSpace(Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius)
  local light = k.box("OrbitLight", Vector3.one * 1.1, center + offset, color, M.Neon, false)
  light.Shape = Enum.PartType.Ball
  light:SetAttribute("Spin", speed)
  light:SetAttribute("SpinAxis", axis)
  light:SetAttribute("SpinPivot", -offset)
 end
end

-- The event stage: a dark dais ringed with light, and a hologram globe above it with lights in orbit.
local function hologramStage(k, center, radius)
 k.disc("StageGlow", center, radius + 1.2, SEAM, M.Neon, 2)
 k.disc("Stage", center, radius, WALK, M.SmoothPlastic, 3)
 for index, r in {radius * 0.78, radius * 0.5} do
  k.disc("StageRing", center, r, HOLO, M.Neon, 3 + index * 2)
  k.disc("StageRingInner", center, r - 0.6, WALK, M.SmoothPlastic, 4 + index * 2)
 end
 k.disc("StageEmitter", center, 3, HULL, M.SmoothPlastic, 9)
 k.disc("StageEmitterGlow", center, 1.6, HOLO, M.Neon, 10)
 local globeCenter = center + Vector3.new(0, 16, 0)
 local globe = k.box("HoloGlobe", Vector3.one * 11, globeCenter, HOLO, M.Neon, false)
 globe.Shape, globe.Transparency = Enum.PartType.Ball, 0.55
 globe:SetAttribute("Pulse", 0.5)
 local core = k.box("HoloGlobeCore", Vector3.one * 5, globeCenter, Color3.fromRGB(230, 252, 255), M.Neon, false)
 core.Shape = Enum.PartType.Ball
 orbitLights(k, globeCenter, 10, math.rad(20), 10, HOLO, 40)
 orbitLights(k, globeCenter, 13, math.rad(-35), 12, HOLO_PINK, -28)
 -- A faint beam from the emitter up to the globe.
 local beam = k.column("HoloBeam", center, 1.2, 0.2, 13, HOLO, M.Neon, false)
 beam.Transparency = 0.6
end

-- A holo lamp: a slim white pole with a glowing ring cap and a bobbing light above it.
local function holoLamp(k, position)
 k.column("LampBase", position, 2, position.Y, position.Y + 1.6, GUNMETAL, M.SmoothPlastic, true)
 k.column("LampPole", position, 0.6, position.Y + 1.6, position.Y + 26, HULL, M.Metal, true)
 k.column("LampCap", position, 2.2, position.Y + 26, position.Y + 27, SEAM, M.Neon, false)
 local orb = k.box("LampOrb", Vector3.one * 3.6, position + Vector3.new(0, 31, 0), HOLO, M.Neon, false)
 orb.Shape = Enum.PartType.Ball
 orb:SetAttribute("Bob", 1.2)
 orb:SetAttribute("BobSpeed", 1.4)
 orb:SetAttribute("Phase", position.X * 0.1)
 local light = Instance.new("PointLight")
 light.Color, light.Range, light.Brightness, light.Shadows = HOLO, 40, 1.5, false
 light.Parent = orb
end

-- A hovering drone: a small white body with glowing rotor rings and an eye, bobbing in place.
local function drone(k, position, phase)
 local parts = {
  k.box("DroneBody", Vector3.new(2.4, 0.9, 2.4), position, HULL, M.SmoothPlastic, false),
  k.box("DroneEye", Vector3.new(0.9, 0.5, 0.3), position + Vector3.new(0, -0.1, -1.25), HOLO, M.Neon, false),
 }
 for _, corner in {Vector3.new(-1.6, 0.3, -1.6), Vector3.new(1.6, 0.3, -1.6), Vector3.new(-1.6, 0.3, 1.6), Vector3.new(1.6, 0.3, 1.6)} do
  local rotor = k.box("DroneRotor", Vector3.new(0.15, 1.6, 1.6), position + corner, HOLO, M.Neon, false, CFrame.Angles(0, 0, math.pi / 2))
  rotor.Shape, rotor.Transparency = Enum.PartType.Cylinder, 0.35
  table.insert(parts, rotor)
 end
 for _, part in parts do
  part:SetAttribute("Bob", 0.8)
  part:SetAttribute("BobSpeed", 1.6)
  part:SetAttribute("Phase", phase)
 end
end

-- A glass skyscraper on the berm: setback crown, glowing bands, a spire with a blinking light.
local function skyTower(k, base, width, height, glow)
 local half = width / 2
 k.block("SkyTower", base.X - half, base.X + half, base.Y, base.Y + height, base.Z - half, base.Z + half, SKY_GLASS, M.Glass)
 for band = 1, math.floor(height / 14) do
  local y = base.Y + band * 14
  k.block("SkyTowerBand", base.X - half - 0.2, base.X + half + 0.2, y, y + 0.7, base.Z - half - 0.2, base.Z + half + 0.2, glow, M.Neon, false)
 end
 local crown = height * 0.16
 k.block("SkyTowerCrown", base.X - half * 0.62, base.X + half * 0.62, base.Y + height, base.Y + height + crown,
  base.Z - half * 0.62, base.Z + half * 0.62, HULL, M.SmoothPlastic)
 local top = base.Y + height + crown
 k.column("SkyTowerSpire", Vector3.new(base.X, 0, base.Z), 0.45, top, top + 12, HULL, M.Metal, false)
 local tip = k.box("SkyTowerBeacon", Vector3.one * 1.8, Vector3.new(base.X, top + 12.9, base.Z), BEACON_RED, M.Neon, false)
 tip.Shape = Enum.PartType.Ball
 tip:SetAttribute("Pulse", 0.8)
 tip:SetAttribute("Phase", base.X * 0.05)
end

-- The beacon tower behind the back terraces, facing the plaza (-Z): a white shaft with a glowing
-- core, the World's sign, a turning ring of light and a pulsing beacon on top.
local function beaconTower(k, base)
 local x, y, z = base.X, base.Y, base.Z
 k.block("BeaconFoot", x - 12, x + 12, y, y + 5, z - 12, z + 12, GUNMETAL, M.SmoothPlastic)
 for _, cx in {-1, 1} do
  for _, cz in {-1, 1} do
   k.block("BeaconFin", x + cx * 6.5 - 1.5, x + cx * 6.5 + 1.5, y + 5, y + 52, z + cz * 6.5 - 1.5, z + cz * 6.5 + 1.5, HULL, M.SmoothPlastic)
  end
 end
 k.column("BeaconCore", Vector3.new(x, 0, z), 4.2, y + 5, y + 56, SEAM, M.Neon, false).Transparency = 0.15
 k.column("BeaconCollar", Vector3.new(x, 0, z), 9, y + 52, y + 54, HULL, M.SmoothPlastic, true)
 k.column("BeaconCrown", Vector3.new(x, 0, z), 6, y + 54, y + 62, HULL, M.SmoothPlastic, true)
 local light = k.box("BeaconLight", Vector3.one * 6, Vector3.new(x, y + 66, z), HOLO, M.Neon, false)
 light.Shape = Enum.PartType.Ball
 light:SetAttribute("Pulse", 0.6)
 local point = Instance.new("PointLight")
 point.Color, point.Range, point.Brightness, point.Shadows = HOLO, 60, 2, false
 point.Parent = light
 -- A ring of light segments turning round the crown.
 local ringCenter = Vector3.new(x, y + 58, z)
 for i = 1, 8 do
  local angle = 2 * math.pi * i / 8
  local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 12
  local segment = k.box("BeaconRing", Vector3.new(1, 0.8, 7.5), ringCenter + offset, i % 2 == 0 and HOLO or HOLO_PINK, M.Neon, false,
   CFrame.Angles(0, -angle, 0))
  segment:SetAttribute("Spin", 30)
  segment:SetAttribute("SpinAxis", Vector3.yAxis)
  segment:SetAttribute("SpinPivot", CFrame.Angles(0, -angle, 0):VectorToObjectSpace(-offset))
 end
 -- The World's sign on the front fins.
 local board = k.box("BeaconSign", Vector3.new(15, 8, 0.6), Vector3.new(x, y + 24, z - 8.4), WALK, M.SmoothPlastic, false)
 k.box("BeaconSignTrim", Vector3.new(16, 9, 0.4), Vector3.new(x, y + 24, z - 8.2), SEAM, M.Neon, false)
 local gui = Instance.new("SurfaceGui")
 gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 24, 0
 gui.Parent = board
 for _, line in {{"FUTURE WORLD", 0.08, 0.5, HOLO}, {"WORLD 3", 0.62, 0.3, Color3.new(1, 1, 1)}} do
  local label = Instance.new("TextLabel")
  label.BackgroundTransparency, label.Font, label.TextScaled = 1, Enum.Font.GothamBlack, true
  label.Text, label.TextColor3 = line[1], line[4]
  label.Position, label.Size = UDim2.fromScale(0.05, line[2]), UDim2.fromScale(0.9, line[3])
  label.Parent = gui
 end
end

local function future(k, folder, frame, config, worldId)
 local depth = config.depth
 local width = config.left + config.right

 -- The plaza floor: white tiles with thin glowing seams.
 local columns, rows = 9, 8
 for i = 0, columns - 1 do
  for j = 0, rows - 1 do
   k.block("Tile", -config.left + i * width / columns, -config.left + (i + 1) * width / columns, -Field.GroundThickness, 0,
    j * depth / rows, (j + 1) * depth / rows, (i + j) % 2 == 0 and PLAZA_A or PLAZA_B, M.SmoothPlastic)
  end
 end
 for i = 1, columns - 1 do
  local x = -config.left + i * width / columns
  k.patch("Seam", x - 0.2, x + 0.2, 0, depth, SEAM, M.Neon, 1)
 end
 for j = 1, rows - 1 do
  local z = j * depth / rows
  k.patch("Seam", -config.left, config.right, z - 0.2, z + 0.2, SEAM, M.Neon, 1)
 end

 -- Dark walkways with glowing edges to the cages, the displays and the stage, a glowing ring
 -- round the batting area, and a landing-pad marking at the spawn.
 k.disc("BatterRing", Vector3.new(0, 0, 10), 10.8, SEAM, M.Neon, 2)
 k.disc("BatterCircle", Vector3.new(0, 0, 10), 10, WALK, M.SmoothPlastic, 3)
 local doorX, cagesEnd, displayX, displaysEnd = layoutExtents(config, worldId)
 walkway(k, "FrontPath", doorX, displayX - 2, 20, 28)
 walkway(k, "CageLane", doorX, doorX + 8, 28, cagesEnd)
 walkway(k, "DisplayLane", displayX - 10, displayX - 2, 28, displaysEnd)
 local spawnZ = 60
 k.disc("SpawnPadGlow", Vector3.new(0, 0, spawnZ), 4.2, SEAM, M.Neon, 4)
 k.disc("SpawnPad", Vector3.new(0, 0, spawnZ), 3.5, HULL, M.SmoothPlastic, 5)
 k.disc("SpawnPadCore", Vector3.new(0, 0, spawnZ), 1.4, SEAM, M.Neon, 6)

 -- The hologram stage for events, and the World portal's pad.
 local event = config.eventArea
 if event then
  local radius = event.size / 2
  walkway(k, "CenterPath", -4, 4, 28, event.center.Z - radius - 1)
  hologramStage(k, event.center, radius)
 end
 local portal = config.portalPad
 if portal then
  k.disc("PortalPadGlow", portal.center, portal.radius + 1, SEAM, M.Neon, 3)
  k.disc("PortalPadRing", portal.center, portal.radius, HULL, M.SmoothPlastic, 4)
  k.disc("PortalPad", portal.center, portal.radius - 1.6, WALK, M.SmoothPlastic, 5)
 end

 -- White walls with a gunmetal cap and a glowing strip, white terraces up to the berm.
 local outer, backFar = bowl(k, config, FUTURE_BOWL)
 for _, sign in {-1, 1} do
  local x = sign * (edge(config, sign) - 0.1)
  k.block("WallGlow", x - 0.1, x + 0.1, 2.6, 3.1, 0, depth, SEAM, M.Neon, false)
 end
 k.block("WallGlow", -config.left, config.right, 2.6, 3.1, depth - 0.1, depth + 0.1, SEAM, M.Neon, false)

 -- The beacon tower at the back, holo lamps at the corners, drones over the plaza.
 beaconTower(k, Vector3.new(0, BERM_TOP, backFar + 24))
 for _, sign in {-1, 1} do
  holoLamp(k, Vector3.new(sign * (outer[sign] + 8), BERM_TOP, 8))
  holoLamp(k, Vector3.new(sign * (outer[sign] + 8), BERM_TOP, backFar + 6))
 end
 local rng = Random.new(3030)
 for i = 1, 8 do
  local sign = i % 2 == 0 and 1 or -1
  drone(k, Vector3.new(sign * rng:NextNumber(20, 110), rng:NextNumber(24, 40), rng:NextNumber(30, 200)), rng:NextNumber(0, 2 * math.pi))
 end

 -- A glass skyline on the berm, tallest at the back.
 for i = 1, 22 do
  local sign = i % 2 == 0 and 1 or -1
  local base, height
  if i % 3 == 0 then
   base = Vector3.new(rng:NextNumber(-outer[-1] - 40, outer[1] + 40), BERM_TOP, rng:NextNumber(backFar + 70, 470))
   height = rng:NextNumber(70, 130)
  else
   base = Vector3.new(sign * rng:NextNumber(outer[sign] + 70, 390), BERM_TOP, rng:NextNumber(30, 430))
   height = rng:NextNumber(40, 100)
  end
  skyTower(k, base, rng:NextNumber(14, 24), height, i % 4 == 0 and HOLO_PINK or HOLO)
 end

 -- World 3's runway models on the berm and the terraces' edge (each skipped while missing).
 local colors = {color = Color3.fromRGB(206, 214, 222), accent = HOLO}
 local spaceport = {color = Color3.fromRGB(168, 170, 176), accent = Color3.fromRGB(255, 120, 40)}
 RunwayDecor.PlaceMesh(folder, frame, "rocket", Vector3.new(outer[1] + 40, BERM_TOP, 70), 2.4, 2, spaceport)
 RunwayDecor.PlaceMesh(folder, frame, "launchTowers", Vector3.new(outer[1] + 46, BERM_TOP, 170), 0.55, 1, spaceport)
 RunwayDecor.PlaceMesh(folder, frame, "radarDish", Vector3.new(outer[1] + 30, BERM_TOP, 236), 2, 3, spaceport)
 RunwayDecor.PlaceMesh(folder, frame, "biodome", Vector3.new(-(outer[-1] + 44), BERM_TOP, 60), 2.4, 1,
  {color = Color3.fromRGB(66, 150, 128), accent = Color3.fromRGB(214, 120, 255)})
 RunwayDecor.PlaceMesh(folder, frame, "ecoHouse", Vector3.new(-(outer[-1] + 34), BERM_TOP, 150), 2, 2, colors)
 RunwayDecor.PlaceMesh(folder, frame, "solarTree", Vector3.new(-(outer[-1] + 20), BERM_TOP, 210), 1.8, 1, colors)
 for i = 1, 4 do
  RunwayDecor.PlaceMesh(folder, frame, "windTurbine", Vector3.new(-(outer[-1] + 90 + i * 28), BERM_TOP, 40 + i * 70), 3, i, colors)
 end
 for i = 1, 3 do
  RunwayDecor.PlaceMesh(folder, frame, "hoverCar", Vector3.new((i - 2) * 60, 46 + i * 6, backFar + 30 + i * 12), 2, i,
   {color = Color3.fromRGB(66, 72, 88), accent = HOLO})
 end
end

local THEMES = {HomeField = homeField, TimeTravel = timeTravel, Future = future}

-- Builds the hub's theme into hub.Decor (rebuilt each time). Returns true when a theme was built,
-- in which case it supplies the hub's floor.
function HubDecor.Build(hub, frame, config, worldId)
 local old = hub:FindFirstChild("Decor")
 if old then old:Destroy() end
 local builder = config.theme and THEMES[config.theme]
 if not builder then
  if config.theme then warn("Unknown hub theme " .. tostring(config.theme)) end
  return false
 end
 local folder = Instance.new("Folder")
 folder.Name = "Decor"
 folder.Parent = hub
 builder(kit(folder, frame), folder, frame, config, worldId)
 return true
end

return HubDecor
