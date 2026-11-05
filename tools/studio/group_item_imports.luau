-- Studio command-bar script (not Rojo-managed): sorts World 4's imported Ball, Bat and cage FBX files into
-- ServerStorage.RunwayAssets (items in DisplayItems, one Model per item id), the way World 3's were.
--
-- 1. In Studio, Import 3D assets/models/BallsWorld4.fbx, BatsWorld4.fbx and the five World 4 cages (default
--    settings), leaving each result in the Workspace under its file name.
-- 2. Paste this whole file into the command bar and press Enter (or run it through MCP).
-- 3. Save the place.
--
-- Every mesh is named "<item id>__<Part>". A ball's pivot is the centre of its Shell; a bat's is the
-- hand, GRIP_CENTRE below the centre of its Grip (bats.py: the grip spans -0.41..0.5 studs, so its
-- centre is 0.045 studs up the bat from the hand). Models end at scale 1 at Blender size (the import
-- is 100x), pivoted on the origin, like every other DisplayItems model. An item model that already
-- exists is replaced. The imported model is removed once every part has been moved.
local GRIP_CENTRE = 0.045
local IMPORTS = {
 BallsWorld4 = {anchor = "Shell", ids = {"dandelion_puff_ball", "blueberry_ball", "meatball_ball", "bouncy_ball", "lucky_dice_ball",
  "yarn_ball", "bath_bomb_ball", "mini_globe_ball", "cats_eye_marble", "dream_orb"}},
 BatsWorld4 = {anchor = "Grip", ids = {"rolling_pin_bat"}},
}

local assets = game.ServerStorage:WaitForChild("RunwayAssets")
local displayItems = assets:FindFirstChild("DisplayItems")
if not displayItems then
 displayItems = Instance.new("Folder")
 displayItems.Name = "DisplayItems"
 displayItems.Parent = assets
end
local out = {}
for importName, spec in IMPORTS do
 local imported = workspace:FindFirstChild(importName)
 if not imported then
  table.insert(out, importName .. ": not imported")
  continue
 end
 for _, id in spec.ids do
  local temp = Instance.new("Model")
  for _, part in imported:GetDescendants() do
   if part:IsA("BasePart") and part.Name:sub(1, #id + 2) == id .. "__" then part.Parent = temp end
  end
  local anchor = temp:FindFirstChild(id .. "__" .. spec.anchor)
  if not anchor then
   table.insert(out, id .. ": no " .. spec.anchor .. " found")
   temp:Destroy()
   continue
  end
  local old = displayItems:FindFirstChild(id)
  if old then old:Destroy() end
  local pivot = anchor.Position
  if spec.anchor == "Grip" then pivot -= Vector3.new(0, GRIP_CENTRE * 100, 0) end
  temp.WorldPivot = CFrame.new(pivot)
  temp:ScaleTo(0.01)
  temp:PivotTo(CFrame.new())
  local model = Instance.new("Model")
  model.Name = id
  for _, part in temp:GetChildren() do
   part.Anchored = true
   part.Parent = model
  end
  temp:Destroy()
  model.WorldPivot = CFrame.new()
  model.Parent = displayItems
  local _, size = model:GetBoundingBox()
  table.insert(out, string.format("%s: %d parts, %.2f x %.2f x %.2f", id, #model:GetChildren(), size.X, size.Y, size.Z))
 end
 local left = 0
 for _, d in imported:GetDescendants() do
  if d:IsA("BasePart") then left += 1 end
 end
 if left == 0 then imported:Destroy() end
 table.insert(out, importName .. " parts left: " .. left)
end
-- The five World 4 cages (Phase 5): each import is kept whole as a template of the same name, turned a
-- half turn and scaled back by 0.01 like World 3's cages (TrainingStadium scales templates up 4x). The
-- home plate's position (x4) should match the standard TrainingCage's, printed last.
local CAGES = {SandboxDiamondCage = "SandHomePlate", PinballCage = "PinHomePlate", CerealBowlCage = "BowlHomePlate",
 ToySoldierCage = "FortHomePlate", SnowGlobeCage = "GlobeHomePlate"}
for name, plateName in CAGES do
 local cage = workspace:FindFirstChild(name)
 if not cage then
  table.insert(out, name .. ": not imported")
  continue
 end
 cage.WorldPivot = CFrame.new(cage.WorldPivot.Position) * CFrame.Angles(0, math.pi, 0)
 cage:ScaleTo(0.01)
 for _, part in cage:GetDescendants() do
  if part:IsA("BasePart") then part.Anchored = true end
 end
 local old = assets:FindFirstChild(name)
 if old then old:Destroy() end
 cage.Parent = assets
 local plate = cage:FindFirstChild(plateName, true)
 table.insert(out, name .. ": home plate (x4) = " .. tostring(plate and cage.WorldPivot:PointToObjectSpace(plate.Position) * 4))
end
local reference = assets:FindFirstChild("TrainingCage")
local referencePlate = reference and reference:FindFirstChild("HomePlate", true)
if referencePlate then
 table.insert(out, "standard TrainingCage home plate (x4) = " .. tostring(reference.WorldPivot:PointToObjectSpace(referencePlate.Position) * 4))
end
print(table.concat(out, "\n"))
return table.concat(out, "\n")
