-- Generates the configured runways and optional empty hubs.
local Field = require(game:GetService("ReplicatedStorage"):WaitForChild("FieldConfig"))
local Worlds = require(game.ReplicatedStorage:WaitForChild("WorldConfig"))
local Training = require(game.ReplicatedStorage:WaitForChild("TrainingConfig"))
local Builder = {}

local function buildHub(world, area)
 local config = world.hub
 if not config then return end
 assert(config.width > 0 and config.depth > 0, "Hub dimensions must be positive")
 local origin = area.Tee.Stem.BallPosition.WorldPosition
 local difference = area.HitDirection.Position - origin
 local forward = Vector3.new(difference.X, 0, difference.Z).Unit
 -- A small surface separation prevents the old baseplate texture bleeding through.
 local surfaceY = Field.GroundTop + 0.1
 local edge = Vector3.new(origin.X, surfaceY, origin.Z)
 local frame = CFrame.lookAt(edge, edge + forward)
 local hub = workspace:FindFirstChild(config.name)
 if not hub then
  hub = Instance.new("Model")
  hub.Name = config.name
  hub.Parent = workspace
 end
 hub:SetAttribute("WorldId", world.id)
 local function part(name, size, position, color, collidable)
  local p = hub:FindFirstChild(name) or Instance.new("Part")
  p.Name, p.Size = name, size
  p.CFrame = frame * CFrame.new(position)
  p.Anchored = true
  p.CanCollide, p.CanTouch, p.CanQuery = collidable, false, collidable
  p.Material, p.Color = Enum.Material.SmoothPlastic, color
  p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
  p.Parent = hub
 end
 part("Floor", Vector3.new(config.width, Field.GroundThickness, config.depth),
  Vector3.new(0, -Field.GroundThickness / 2, config.depth / 2), Color3.fromRGB(160, 166, 172), true)
 -- Flush boundary strips define the rectangle without walls or movement barriers.
 local boundaryColor = Color3.fromRGB(100, 108, 116)
 for _, side in {-1, 1} do
  part(side == -1 and "LeftBoundary" or "RightBoundary", Vector3.new(1, 0.025, config.depth),
   Vector3.new(side * (config.width / 2 - 0.5), 0.0125, config.depth / 2), boundaryColor, false)
 end
 part("BackBoundary", Vector3.new(config.width, 0.025, 1),
  Vector3.new(0, 0.0125, config.depth - 0.5), boundaryColor, false)
 local interactions = hub:FindFirstChild("Interactions") or Instance.new("Folder")
 interactions.Name, interactions.Parent = "Interactions", hub
 for _, definition in config.interactions or {} do
  local station = interactions:FindFirstChild(definition.id) or Instance.new("Model")
  station.Name, station.Parent = definition.id, interactions
  local pad = station:FindFirstChild("Pad") or Instance.new("Part")
  pad.Name, pad.Size = "Pad", definition.size
  pad.CFrame = frame * CFrame.new(definition.position + Vector3.new(0, definition.size.Y / 2, 0))
  pad.Anchored, pad.CanCollide = true, false
  pad.Material, pad.Color = Enum.Material.SmoothPlastic, boundaryColor
  pad.Parent = station
  local post = station:FindFirstChild("Interaction") or Instance.new("Part")
  post.Name, post.Size = "Interaction", Vector3.new(4, 3, 4)
  post.CFrame = frame * CFrame.new(definition.position + Vector3.new(0, 1.5, 0))
  post.Anchored = true
  post.Material, post.Color = Enum.Material.SmoothPlastic, boundaryColor
  post.Parent = station
  local prompt = post:FindFirstChild("Prompt") or Instance.new("ProximityPrompt")
  prompt.Name, prompt.ActionText = "Prompt", definition.actionText
  prompt.ObjectText = definition.objectText or (definition.id == "Shop" and "Equipment" or "Worlds")
  prompt.MaxActivationDistance, prompt.HoldDuration = config.promptDistance, 0
  prompt.RequiresLineOfSight = false
  prompt:SetAttribute("HubAction", definition.id)
  prompt:SetAttribute("WorldId", world.id)
  prompt.Parent = post
  if definition.id == "Shop" then
   -- Empty placement references only; future displays can use these attachments.
   local retiredSlot = pad:FindFirstChild("TeeDisplay")
   if retiredSlot then retiredSlot:Destroy() end
   for index, category in {"Bat", "Ball"} do
    local slot = pad:FindFirstChild(category .. "Display") or Instance.new("Attachment")
    slot.Name = category .. "Display"
    slot.Position = Vector3.new((index - 2) * 8, 0.05, -8)
    slot.Parent = pad
   end
  end
 end
 if world.id == Worlds.StartingWorldId then
  local stadium = hub:FindFirstChild("TrainingStadium") or Instance.new("Model")
  stadium.Name, stadium.Parent = "TrainingStadium", hub
  local plate = stadium:FindFirstChild("TrainingPlate") or Instance.new("Part")
  plate.Name, plate.Size = "TrainingPlate", Training.PlateSize
  plate.CFrame = frame * CFrame.new(Training.PlatePosition + Vector3.yAxis * Training.PlateSize.Y / 2)
  plate.Anchored, plate.CanCollide = true, false
  plate.Color = Color3.fromRGB(110,110,110)
  plate.Parent = stadium
  for name, offset in {PitchOrigin = Training.PitchOffset, ContactPosition = Training.ContactOffset} do
   local reference = plate:FindFirstChild(name) or Instance.new("Attachment")
   reference.Name, reference.Position, reference.Parent = name, offset, plate
  end
  local selector = stadium:FindFirstChild("Selector") or Instance.new("Part")
  selector.Name, selector.Size = "Selector", Vector3.new(3,0.1,3)
  selector.CFrame = plate.CFrame * CFrame.new(Training.SelectorOffset)
  selector.Anchored, selector.CanCollide = true, false
  selector.Color, selector.Parent = plate.Color, stadium
  local prompt = selector:FindFirstChild("Prompt") or Instance.new("ProximityPrompt")
  prompt.Name, prompt.ActionText, prompt.ObjectText = "Prompt", "Choose Training Ground", "Training"
  prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0, config.promptDistance, false
  prompt:SetAttribute("HubAction", "Training")
  prompt:SetAttribute("WorldId", world.id)
  prompt.Parent = selector
  local spawn = workspace:FindFirstChild("SpawnLocation") or hub:FindFirstChild("SpawnLocation")
  if not spawn then spawn = Instance.new("SpawnLocation") end
  spawn.Name, spawn.Size = "SpawnLocation", Vector3.new(12, 0.1, 12)
  spawn.CFrame = CFrame.new(world.arrival.Position.X, surfaceY + 0.05, world.arrival.Position.Z)
   * world.arrival.Rotation
  spawn.Anchored, spawn.CanCollide, spawn.Transparency = true, false, 1
  spawn.Neutral, spawn.Enabled = true, true
  for _, child in spawn:GetChildren() do
   if child:IsA("Decal") or child:IsA("Texture") then child.Transparency = 1 end
  end
  spawn.Parent = hub
 end
end

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
  buildHub(world, area)
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
