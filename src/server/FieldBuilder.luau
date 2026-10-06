-- Rebuilds only the generated runway. Add sections in WorldConfig to extend it.
local Field = require(game:GetService("ReplicatedStorage"):WaitForChild("FieldConfig"))
local Worlds = require(game.ReplicatedStorage:WaitForChild("WorldConfig"))
local Builder = {}

local function buildField(world)
 local area = workspace:WaitForChild(world.stationName)
 local origin = area.Tee.Stem.BallPosition.WorldPosition
 local difference = area.HitDirection.Position - origin
 local forward = Vector3.new(difference.X, 0, difference.Z).Unit
 local originOnGround = Vector3.new(origin.X, Field.GroundTop, origin.Z)
 local frame = CFrame.lookAt(originOnGround, originOnGround + forward)
 local previousEnd = 0
 local ids = {}
 for index, section in world.sections do
  assert(section.startDistance == previousEnd and section.endDistance > previousEnd, "Field sections must be consecutive")
  assert(section.order == index and not ids[section.id], "Field section order/IDs must be unique")
  assert(section.rewardMultiplier >= 1, "Invalid section reward multiplier")
  ids[section.id] = true
  previousEnd = section.endDistance
 end
 assert(previousEnd == world.endDistance, "Last section must end at the world end distance")
 assert(Field.Width > 0 and Field.MaximumPartSize > 0 and Field.MaximumPartSize <= 2048)
 local existing = workspace:FindFirstChild(world.fieldName)
 if existing then existing:Destroy() end
 local field = Instance.new("Model")
 field.Name = world.fieldName
 local ground = Instance.new("Folder")
 ground.Name = "Ground"
 ground.Parent = field
 local markers = Instance.new("Folder")
 markers.Name = "Markers"
 markers.Parent = field
 local baseplate = workspace:FindFirstChild("Baseplate")
 local groundPhysics = baseplate and baseplate.CurrentPhysicalProperties
  or PhysicalProperties.new(0.7, 0.3, 0.5)
 local function part(name, size, localPosition, color, material, parent, collidable)
  local p = Instance.new("Part")
  p.Name, p.Size = name, size
  p.CFrame = frame * CFrame.new(localPosition)
  p.Color, p.Material = color or baseplate.Color, material or Enum.Material.Plastic
  p.Anchored = true
  p.CanCollide, p.CanTouch, p.CanQuery = collidable, collidable, collidable
  p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
  p.CustomPhysicalProperties = groundPhysics
  p.Parent = parent
  return p
 end
 for _, section in world.sections do
  local start = section.startDistance
  while start < section.endDistance do
   local length = math.min(Field.MaximumPartSize, section.endDistance - start)
   local left = -Field.Width / 2
   while left < Field.Width / 2 do
    local width = math.min(Field.MaximumPartSize, Field.Width / 2 - left)
    local p = part(section.id, Vector3.new(width, Field.GroundThickness, length),
     Vector3.new(left + width / 2, -Field.GroundThickness / 2, -start - length / 2),
     section.color, section.material, ground, true)
    p:SetAttribute("SectionId", section.id)
    left += width
   end
   start += length
  end
 end
 -- Plain runout gives a ball room to roll past the end marker and stop.
 -- It belongs to the final reward section, without extending its cosmetic theme.
 local runoutStart = world.endDistance
 while runoutStart < world.endDistance + world.runoutDistance do
  local length = math.min(Field.MaximumPartSize, world.endDistance + world.runoutDistance - runoutStart)
  local left = -Field.Width / 2
  while left < Field.Width / 2 do
   local width = math.min(Field.MaximumPartSize, Field.Width / 2 - left)
   part("Runout", Vector3.new(width, Field.GroundThickness, length),
    Vector3.new(left + width / 2, -Field.GroundThickness / 2, -runoutStart - length / 2),
    nil, nil, ground, true)
   left += width
  end
  runoutStart += length
 end
 local distances = {}
 local distance = Field.MarkerInterval
 while distance <= previousEnd do
  distances[distance] = true
  distance += distance < Field.DenseMarkersUntil and Field.MarkerInterval or Field.DistantMarkerInterval
 end
 for _, section in world.sections do distances[section.startDistance] = true end
 distances[previousEnd] = true
 for markerDistance in distances do
  local section = Field.GetSection(markerDistance, world)
  local boundary = section and section.startDistance == markerDistance
  local left = -Field.Width / 2
  while left < Field.Width / 2 do
   local width = math.min(Field.MaximumPartSize, Field.Width / 2 - left)
   part("DistanceLine", Vector3.new(width, 0.025, boundary and 1.2 or 0.25),
    Vector3.new(left + width / 2, 0.025, -markerDistance),
    Color3.fromRGB(235, 224, 169), Enum.Material.SmoothPlastic, markers, false)
   left += width
  end
  local anchor = part("Marker_" .. markerDistance, Vector3.new(0.1, 0.1, 0.1),
   Vector3.new(12, 3, -markerDistance), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, markers, false)
  anchor.Transparency = 1
  local gui = Instance.new("BillboardGui")
  gui.Size = UDim2.fromOffset(190, 50)
  gui.MaxDistance = 250
  gui.AlwaysOnTop = false
  gui.Parent = anchor
  local label = Instance.new("TextLabel")
  label.Size = UDim2.fromScale(1, 1)
  label.BackgroundTransparency = 0.25
  label.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
  label.TextColor3 = Color3.new(1, 1, 1)
  label.Font = Enum.Font.GothamBold
  label.TextSize = 17
  label.Text = string.format("%d studs%s", markerDistance,
   boundary and ("\n" .. section.displayName) or "")
  if markerDistance == world.endDistance then label.Text = world.displayName .. " END\n" .. markerDistance .. " studs" end
  label.Parent = gui
 end
 field:SetAttribute("WorldId", world.id)
 field:SetAttribute("LengthStuds", previousEnd)
 field:SetAttribute("RunoutStuds", world.runoutDistance)
 field:SetAttribute("WidthStuds", Field.Width)
 field.Parent = workspace
 return field
end

function Builder.Build()
 local template = workspace:WaitForChild(Worlds.Get(Worlds.StartingWorldId).stationName)
 for _, world in Worlds.Worlds do
  local area = workspace:FindFirstChild(world.stationName)
  if not area then
   area = template:Clone()
   area.Name = world.stationName
   area:PivotTo(template:GetPivot() + world.offset)
   area.Parent = workspace
  end
  area:SetAttribute("WorldId", world.id)
  area.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
  buildField(world)
  if world.id ~= Worlds.StartingWorldId then
   local arrivalName = world.stationName .. "ArrivalFloor"
   if not workspace:FindFirstChild(arrivalName) then
    local floor = Instance.new("Part")
    floor.Name = arrivalName
    floor.Size = Vector3.new(60, 8, 60)
    floor.CFrame = CFrame.new(world.arrival.Position.X, -4, world.arrival.Position.Z)
    floor.Anchored = true
    floor.Parent = workspace
   end
  end
 end
end
return Builder
