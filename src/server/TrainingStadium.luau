-- Builds one Training Ground's batting cage around its plate, dressed in that ground's
-- theme: the Blender cage (theme.template in ServerStorage.RunwayAssets, managed in Studio,
-- not Rojo), turf, chalk, banners, floodlights, invisible walls, DecorSlots with the theme's
-- decorations, and a LockSign that TrainingGroundsClient fills in for each player.
local ServerStorage = game:GetService("ServerStorage")
local Training = require(game.ReplicatedStorage:WaitForChild("TrainingConfig"))
local Styles = require(script.Parent:WaitForChild("TrainingCageStyles"))
local Stadium = {}

local CHALK = Color3.fromRGB(240, 240, 236)

-- Theme color role and material of each MeshPart in the cage template (names from
-- batting_cage.py). Parts without a role keep FIXED_COLORS or the template's own color.
local MESH_ROLES = {
 CageFrame = "frame", LightHousing = "frame", CagePads = "accent", MachineBody = "accent", ScreenFrame = "accent",
 NetLeft = "net", NetRight = "net", NetRoof = "net", NetBack = "net", NetFront = "net", ScreenNet = "net",
}
local MESH_LOOKS = {
 CageFrame = Enum.Material.Metal, LightHousing = Enum.Material.Metal, MachineMetal = Enum.Material.Metal,
 CagePads = Enum.Material.Fabric, MachineTires = Enum.Material.Rubber,
}
local FIXED_COLORS = {
 HomePlate = CHALK, Baseballs = CHALK, LightLens = Color3.fromRGB(255, 244, 214),
 MachineTires = Color3.fromRGB(26, 26, 28), MachineMetal = Color3.fromRGB(178, 182, 188), BallBucket = Color3.fromRGB(230, 118, 34),
}

-- Decoration slots (training-plate space, at turf level) that ground themes fill. Inside
-- slots avoid the pitch lane, the door and the space behind the batter where the camera sits.
local DECOR_SLOTS = {
 OutsideLeftFront = Vector3.new(-22, 0, -26), OutsideLeftMiddle = Vector3.new(-22, 0, -10), OutsideLeftBack = Vector3.new(-22, 0, 6),
 OutsideRightFront = Vector3.new(20, 0, -26), OutsideRightMiddle = Vector3.new(20, 0, -10), OutsideRightBack = Vector3.new(20, 0, 6),
 BackMiddle = Vector3.new(0, 0, 19), BackRight = Vector3.new(10, 0, 19),
 FrontLeft = Vector3.new(-8, 0, -39), FrontRight = Vector3.new(8, 0, -39),
 InsideLeftFront = Vector3.new(-11, 0, -26), InsideLeftMiddle = Vector3.new(-11, 0, -14),
 InsideRightBack = Vector3.new(11, 0, 8), InsideRightFront = Vector3.new(11, 0, -16),
}

local function prepare(part)
 part.Anchored = true
 part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
 part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
end

local function textSurface(part, faces, text)
 for _, face in faces do
  local gui = Instance.new("SurfaceGui")
  gui.Name, gui.Face = face.Name .. "Text", face
  gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
  gui.LightInfluence = 0.4
  gui.Parent = part
  local label = Instance.new("TextLabel")
  label.Name, label.BackgroundTransparency = "Label", 1
  label.Size, label.Position = UDim2.fromScale(0.92, 0.72), UDim2.fromScale(0.04, 0.14)
  label.Font, label.TextScaled = Enum.Font.FredokaOne, true
  label.TextColor3, label.Text = Color3.new(1, 1, 1), text
  label.Parent = gui
  local stroke = Instance.new("UIStroke")
  stroke.Thickness, stroke.Color, stroke.Transparency = 3, Color3.new(0, 0, 0), 0.55
  stroke.Parent = label
 end
end

-- Fantasy cage parts: color, material, glow and the motion attributes the client animates.
local function applyStyle(part, entry)
 part.Color, part.Material = entry.color, entry.material
 part.Transparency = entry.transparency or 0
 if entry.shadow == false then part.CastShadow = false end
 if entry.light then
  local light = Instance.new("PointLight")
  light.Color, light.Range, light.Brightness, light.Shadows = entry.light[1], entry.light[2], entry.light[3], false
  light.Parent = part
 end
 for attribute, key in {Spin = "spin", SpinAxis = "spinAxis", Bob = "bob", BobSpeed = "bobSpeed", Sway = "sway",
  SwaySpeed = "swaySpeed", Phase = "phase", Pulse = "pulse"} do
  if entry[key] ~= nil then part:SetAttribute(attribute, entry[key]) end
 end
end

local function placeEffects(cage, frame, effects)
 for index, effect in effects or {} do
  local preset = Styles.Emitters[effect.kind]
  if preset then
   local zone = Instance.new("Part")
   local s = Training.Cage.widthScale
   zone.Name, zone.Transparency = "Effect" .. index .. effect.kind, 1
   zone.Size = Vector3.new(effect.size.X * s, effect.size.Y, effect.size.Z)
   zone.CFrame = frame * CFrame.new(Training.CageX(effect.position.X), effect.position.Y, effect.position.Z)
   prepare(zone)
   local emitter = Instance.new("ParticleEmitter")
   emitter.Shape, emitter.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
   for property, value in preset do emitter[property] = value end
   emitter.Parent = zone
   zone.Parent = cage
  end
 end
end

-- Squeezes a placed cage model to Cage.widthScale across the cage (plate-space X) about the
-- pitch line, so the machine, plate and pitch path stay put. Spinning parts shrink evenly
-- instead, so rings and discs stay round as they turn.
local function narrow(model, frame)
 local s = Training.Cage.widthScale
 if s == 1 then return end
 local across = frame.RightVector
 for _, part in model:GetDescendants() do
  if part:IsA("BasePart") then
   local p = frame:PointToObjectSpace(part.Position)
   local rotation = part.CFrame - part.Position
   if part:GetAttribute("Spin") then
    part.Size *= s
   else
    -- Scale whichever of the part's own axes lies across the cage.
    local x, y = math.abs(part.CFrame.RightVector:Dot(across)), math.abs(part.CFrame.UpVector:Dot(across))
    local z = math.abs(part.CFrame.LookVector:Dot(across))
    local size = part.Size
    if x >= y and x >= z then
     part.Size = Vector3.new(size.X * s, size.Y, size.Z)
    elseif y >= z then
     part.Size = Vector3.new(size.X, size.Y * s, size.Z)
    else
     part.Size = Vector3.new(size.X, size.Y, size.Z * s)
    end
   end
   part.CFrame = rotation + frame:PointToWorldSpace(Vector3.new(Training.CageX(p.X), p.Y, p.Z))
  end
 end
end

local function placeTemplate(cage, frame, theme)
 local assets = ServerStorage:FindFirstChild("RunwayAssets")
 local template = assets and assets:FindFirstChild(theme.template)
 if not template then
  -- Until a fantasy cage is imported, its ground uses the standard cage in theme colors.
  template = assets and assets:FindFirstChild("TrainingCage")
  warn("TrainingStadium: ServerStorage.RunwayAssets." .. theme.template .. " is missing; using the standard cage")
  if not template then return end
 end
 local styles = Styles[template.Name]
 local model = template:Clone()
 model.Name = "CageMesh"
 for _, part in model:GetDescendants() do
  if part:IsA("BasePart") then
   prepare(part)
   local entry = styles and styles.parts[part.Name]
   if entry then applyStyle(part, entry) continue end
   local role = MESH_ROLES[part.Name]
   part.Color = role and theme[role] or FIXED_COLORS[part.Name] or part.Color
   part.Material = MESH_LOOKS[part.Name] or part.Material
   if part.Name == "LightLens" then
    part.Material = theme.lights and Enum.Material.Neon or Enum.Material.SmoothPlastic
    local light = Instance.new("SpotLight")
    light.Face, light.Angle, light.Range, light.Brightness = Enum.NormalId.Bottom, 110, 24, 4
    light.Color, light.Shadows, light.Enabled = part.Color, true, theme.lights == true
    light.Parent = part
   end
  end
 end
 -- The template's pivot is the training plate centre at turf level (see batting_cage.py).
 model:PivotTo(frame)
 model:ScaleTo(model:GetScale() * Training.Cage.templateScale)
 narrow(model, frame)
 model.Parent = cage
 placeEffects(cage, frame, styles and styles.effects)
 local tint = styles and styles.tint
 if tint then
  cage:SetAttribute("TintColor", tint.color)
  cage:SetAttribute("TintBrightness", tint.brightness)
  cage:SetAttribute("TintContrast", tint.contrast)
  cage:SetAttribute("TintSaturation", tint.saturation)
 end
end

local function placeDecorations(cage, slots, theme)
 local assets = ServerStorage:FindFirstChild("RunwayAssets")
 for _, definition in theme.decorations or {} do
  local slot = slots:FindFirstChild(definition.slot)
  local template = assets and assets:FindFirstChild(definition.template)
  if slot and template then
   local model = template:Clone()
   for _, part in model:GetDescendants() do
    if part:IsA("BasePart") then prepare(part) end
   end
   model:PivotTo(slot.WorldCFrame)
   model.Parent = cage
  else
   warn("TrainingStadium: decoration skipped:", definition.slot, definition.template)
  end
 end
end

function Stadium.Build(stadium, plate, ground)
 local old = stadium:FindFirstChild("Cage")
 if old then old:Destroy() end
 local c, theme = Training.Cage, ground.theme
 local cage = Instance.new("Model")
 cage.Name = "Cage"
 -- Plate space at turf level: the turf replaces the plain plate visual.
 local turfTop = plate.Size.Y / 2
 local frame = plate.CFrame * CFrame.new(0, turfTop, 0)
 local width, length = c.right - c.left, c.back - c.front
 local centerX, centerZ = (c.left + c.right) / 2, (c.back + c.front) / 2
 local function flat(name, size, position, color, material)
  local part = Instance.new("Part")
  part.Name, part.Size = name, size
  part.CFrame = frame * CFrame.new(position)
  part.Material = material or Enum.Material.SmoothPlastic
  prepare(part)
  if color then part.Color = color end
  part.Parent = cage
  return part
 end
 flat("Turf", Vector3.new(width, plate.Size.Y, length), Vector3.new(centerX, -turfTop, centerZ), theme.turf,
  theme.turfMaterial or Enum.Material.Grass)
 flat("Lane", Vector3.new(4.5, 0.02, 30), Vector3.new(3, 0.01, -11), theme.lane, theme.laneMaterial or Enum.Material.Fabric)
 -- Batter's boxes either side of home plate, chalked just above the lane.
 for _, boxX in {-0.5, 6.5} do
  for _, side in {-1, 1} do
   flat("Chalk", Vector3.new(0.25, 0.02, 6), Vector3.new(boxX + side * 2, 0.03, 0), CHALK)
   flat("Chalk", Vector3.new(4.25, 0.02, 0.25), Vector3.new(boxX, 0.03, side * 3), CHALK)
  end
 end
 plate.Transparency = 1
 placeTemplate(cage, frame, theme)

 -- Banners hang on the outside of both long walls (between frames, so every cage design
 -- leaves room for them) and over the door; a lock sign hangs inside the doorway (hidden by
 -- the client once this player may use the ground).
 local doorX, doorWidth = (c.doorLeft + c.doorRight) / 2, c.doorRight - c.doorLeft
 local sides, ends = {Enum.NormalId.Left, Enum.NormalId.Right}, {Enum.NormalId.Front, Enum.NormalId.Back}
 local title = string.upper(theme.bannerText or ground.displayName)
 for _, spec in {
  {"BannerLeft", Vector3.new(0.15, 2.6, 6), Vector3.new(c.left - 0.6, 9, -22), sides},
  {"BannerRight", Vector3.new(0.15, 2.6, 6), Vector3.new(c.right + 0.6, 9, -6), sides},
  {"EntranceSign", Vector3.new(doorWidth + 1, 2.2, 0.15), Vector3.new(doorX, c.doorHeight + 1.8, c.back + 0.6), ends},
 } do
  local part = flat(spec[1], spec[2], spec[3], theme.banner, Enum.Material.Fabric)
  textSurface(part, spec[4], title)
 end
 local lockSign = flat("LockSign", Vector3.new(doorWidth - 0.4, 2.4, 0.15), Vector3.new(doorX, 4, c.back + 0.3),
  Color3.fromRGB(30, 30, 34))
 textSurface(lockSign, ends, "LOCKED")
 lockSign.Transparency = 1
 for _, gui in lockSign:GetChildren() do gui.Enabled = false end

 -- Invisible walls follow the nets, leaving the door open. CanQuery stays off so camera
 -- and click raycasts pass through the netting.
 local function wall(name, size, position)
  local part = flat(name, size, position)
  part.Transparency, part.CanCollide = 1, true
 end
 local h = c.height
 wall("WallLeft", Vector3.new(1, h, length), Vector3.new(c.left, h / 2, centerZ))
 wall("WallRight", Vector3.new(1, h, length), Vector3.new(c.right, h / 2, centerZ))
 wall("WallFront", Vector3.new(width, h, 1), Vector3.new(centerX, h / 2, c.front))
 wall("WallBackLeft", Vector3.new(c.doorLeft - c.left, h, 1), Vector3.new((c.left + c.doorLeft) / 2, h / 2, c.back))
 wall("WallBackRight", Vector3.new(c.right - c.doorRight, h, 1), Vector3.new((c.doorRight + c.right) / 2, h / 2, c.back))
 wall("WallBackDoorTop", Vector3.new(doorWidth, h - c.doorHeight, 1), Vector3.new(doorX, (h + c.doorHeight) / 2, c.back))
 wall("MachineBlock", Vector3.new(4, 7, 7), Vector3.new(3, 3.5, -26.3))
 wall("ScreenBlock", Vector3.new(7.4 * c.widthScale, 7.6, 0.8), Vector3.new(3, 3.8, -21))

 local slots = flat("DecorSlots", Vector3.new(1, 1, 1), Vector3.new(centerX, 0.5, centerZ))
 slots.Transparency = 1
 for name, position in DECOR_SLOTS do
  local slot = Instance.new("Attachment")
  slot.Name, slot.Parent = name, slots
  slot.WorldCFrame = frame * CFrame.new(Training.CageX(position.X), position.Y, position.Z)
 end
 placeDecorations(cage, slots, theme)
 cage.Parent = stadium
 return cage
end

return Stadium
