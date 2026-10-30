-- The Catastrophe Bat's model (the Starter Pack's exclusive Bat), built from Parts in the same
-- layout as the Blender bat templates (tools/blender/bats.py): its pivot at the hand, the barrel
-- up +Y, each part named "catastrophe_bat__<Part>" so BatStyles colours it. The barrel's top is a
-- cat's head (ears, eyes, nose, whiskers), with a paw print on the barrel, gold bands, a grip
-- wrapped like a tail and a curled tail at the knob. Ensure() puts it with the other templates
-- (ServerStorage.RunwayAssets.DisplayItems) unless one is already there (a designed mesh
-- imported later replaces it). Presentation only.
local ServerStorage = game:GetService("ServerStorage")
local BatStyles = require(game:GetService("ReplicatedStorage"):WaitForChild("BatStyles"))

local CatBatModel = {}
local ID = "catastrophe_bat"
local UP = CFrame.Angles(0, 0, math.pi / 2) -- a Cylinder's axis (X) turned to point up the bat
local FACING = CFrame.Angles(0, math.pi / 2, 0) -- a Cylinder's axis turned to face +Z

local function part(model, name, shape, size, cframe)
 local object = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
 if shape ~= "Wedge" then object.Shape = shape end
 object.Name, object.Size, object.CFrame = ID .. "__" .. name, size, cframe
 object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
 object.TopSurface, object.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
 object.Parent = model
 return object
end

-- A cylinder along the bat from y0 to y1.
local function ring(model, name, radius, y0, y1, tilt)
 return part(model, name, Enum.PartType.Cylinder, Vector3.new(y1 - y0, radius * 2, radius * 2),
  CFrame.new(0, (y0 + y1) / 2, 0) * CFrame.Angles(tilt or 0, 0, 0) * UP)
end

local function ball(model, name, diameter, position)
 return part(model, name, Enum.PartType.Ball, Vector3.one * diameter, CFrame.new(position))
end

-- A flat disc on the barrel's surface, facing out (+Z on the front, -Z on the back).
local function disc(model, name, radius, position, back)
 return part(model, name, Enum.PartType.Cylinder, Vector3.new(.02, radius * 2, radius * 2),
  CFrame.new(position) * (back and CFrame.Angles(0, -math.pi / 2, 0) or FACING))
end

function CatBatModel.Build()
 local model = Instance.new("Model")
 model.Name = ID
 -- Grip and knob, at the template bat's sizes, so the hand holds it the same way.
 ring(model, "Grip", .1, -.4, .52)
 for index, y in {-.27, -.07, .13, .33} do ring(model, "Wrap", .108, y - .025, y + .025, math.rad(index % 2 == 0 and 10 or -10)) end
 ring(model, "Knob", .155, -.51, -.39)
 -- The tail curls up from the knob.
 for _, segment in {{.12, Vector3.new(.17, -.48, 0)}, {.1, Vector3.new(.25, -.4, 0)}, {.085, Vector3.new(.29, -.31, 0)},
  {.07, Vector3.new(.27, -.23, 0)}} do
  ball(model, "Tail", segment[1], segment[2])
 end
 -- The barrel widens up to the head.
 local radii = {{.52, .8, .11}, {.8, 1.05, .125}, {1.05, 1.3, .14}, {1.3, 1.55, .155}, {1.55, 3.25, .165}}
 for _, step in radii do ring(model, "Barrel", step[3], step[1], step[2]) end
 ball(model, "Barrel", .33, Vector3.new(0, 3.25, 0))
 for _, y in {1.6, 3.06} do ring(model, "Bands", .172, y - .025, y + .025) end
 -- The head: ears on top (the upright edge outside), pink inside, then the face on the front.
 for _, side in {1, -1} do
  -- Turned 45 degrees outward, so each ear shows a triangle from the front, back and sides alike.
  local ear = CFrame.new(side * .12, 3.56, 0) * CFrame.Angles(0, side * math.pi / 4, 0)
  part(model, "Ears", "Wedge", Vector3.new(.08, .42, .27), ear)
  part(model, "InnerEars", "Wedge", Vector3.new(.02, .26, .15), ear * CFrame.new(-side * .05, -.06, .03))
  ball(model, "Eyes", .085, Vector3.new(side * .07, 3.2, .14))
  for _, lift in {.02, -.02} do
   part(model, "Whiskers", Enum.PartType.Block, Vector3.new(.2, .012, .012),
    CFrame.new(side * .16, 3.12 + lift, .13) * CFrame.Angles(0, 0, math.rad(side * lift * 400)))
  end
 end
 ball(model, "Nose", .045, Vector3.new(0, 3.12, .16))
 -- Paw prints, front and back: a pad and three toe beans.
 for _, back in {false, true} do
  local z, y = back and -.162 or .162, back and 1.95 or 2.25
  disc(model, "Paw", .055, Vector3.new(0, y, z), back)
  for _, toe in {{-.05, .085}, {0, .105}, {.05, .085}} do
   disc(model, "Paw", .025, Vector3.new(toe[1], y + toe[2], z * .98), back)
  end
 end
 -- An invisible, unrotated part at the hand as the PrimaryPart, so the published copy keeps its
 -- pivot there, upright (the publisher would otherwise pivot on a turned barrel cylinder).
 local pivot = part(model, "Pivot", Enum.PartType.Block, Vector3.one * .05, CFrame.identity)
 pivot.Transparency = 1
 model.PrimaryPart = pivot
 return BatStyles.ApplyLook(model, ID)
end

-- Puts the model with the bat templates unless one is there already. Safe to call repeatedly.
function CatBatModel.Ensure()
 local assets = ServerStorage:FindFirstChild("RunwayAssets")
 local folder = assets and assets:FindFirstChild("DisplayItems")
 if not folder or folder:FindFirstChild(ID) then return end
 CatBatModel.Build().Parent = folder
end

return CatBatModel
