-- Studio command-bar script (not Rojo-managed): sorts World 4's imported Ball and Bat FBX files into
-- ServerStorage.RunwayAssets.DisplayItems, one Model per item id, the way World 3's balls were grouped.
--
-- 1. In Studio, Import 3D assets/models/BallsWorld4.fbx and assets/models/BatsWorld4.fbx (default
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
print(table.concat(out, "\n"))
return table.concat(out, "\n")
