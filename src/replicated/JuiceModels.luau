-- Juice box models, built from Parts in each juice's colours (JuiceConfig appearance): a carton
-- body with coloured bands, a folded gable top with its sealed seam, a bent straw, and a front
-- label carrying the juice's icon (Power bolt or Cash). Power Punch adds thin Neon trims, Cash
-- Splash a gold coin and splash drops. About 2 x 4 studs, front facing -Z. Presentation only (the
-- Inventory's pictures); Decals are used for the icons because they also show in ViewportFrames.
local JuiceModels = {}

local ICONS = {Power = "rbxassetid://17368078790", Cash = "rbxassetid://88694661500877"}
local WIDTH, DEPTH, HEIGHT = 2, 1.4, 2.6
local ROOF = .55

local function part(model, name, className, size, cframe, color, material)
 local object = Instance.new(className)
 object.Name, object.Size, object.CFrame, object.Color = name, size, cframe, color
 object.Material = material or Enum.Material.SmoothPlastic
 object.Anchored, object.CanCollide, object.CanQuery, object.CastShadow = true, false, false, false
 object.TopSurface, object.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
 object.Parent = model
 return object
end

local function decal(target, face, image)
 local object = Instance.new("Decal")
 object.Face, object.Texture, object.Parent = face, image, target
 return object
end

local function darker(color, amount)
 return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- Builds the juice's box (a new Model named after the juice id).
function JuiceModels.Build(definition)
 local look = definition.appearance or {}
 local body = look.body or definition.color or Color3.fromRGB(200, 200, 200)
 local roof, bands = look.roof or body, look.bands or body
 local model = Instance.new("Model")
 model.Name = definition.id
 local carton = part(model, "Body", "Part", Vector3.new(WIDTH, HEIGHT, DEPTH), CFrame.new(0, HEIGHT / 2, 0), body)
 model.PrimaryPart = carton
 part(model, "Base", "Part", Vector3.new(WIDTH + .08, .16, DEPTH + .08), CFrame.new(0, .08, 0), darker(body, .3))
 part(model, "TopBand", "Part", Vector3.new(WIDTH + .06, .28, DEPTH + .06), CFrame.new(0, HEIGHT - .14, 0), bands)
 part(model, "BottomBand", "Part", Vector3.new(WIDTH + .06, .22, DEPTH + .06), CFrame.new(0, .36, 0), bands)
 -- The gable top: two sloped halves meeting at a ridge along the width, then the sealed fin.
 local roofY = HEIGHT + ROOF / 2
 part(model, "RoofFront", "WedgePart", Vector3.new(WIDTH, ROOF, DEPTH / 2), CFrame.new(0, roofY, -DEPTH / 4), roof)
 part(model, "RoofBack", "WedgePart", Vector3.new(WIDTH, ROOF, DEPTH / 2),
  CFrame.new(0, roofY, DEPTH / 4) * CFrame.Angles(0, math.pi, 0), darker(roof, .12))
 part(model, "Seam", "Part", Vector3.new(WIDTH, .32, .12), CFrame.new(0, HEIGHT + ROOF + .16, 0), darker(roof, .2))
 -- Front label with the icon, and the icon again on both sides.
 local label = part(model, "Label", "Part", Vector3.new(WIDTH - .36, 1.55, .06), CFrame.new(0, 1.42, -DEPTH / 2 - .03),
  look.label or Color3.new(1, 1, 1))
 local image = ICONS[look.icon] or ICONS[definition.effect] or ICONS.Power
 local plate = part(model, "Icon", "Part", Vector3.new(1.25, 1.25, .02), CFrame.new(0, 1.42, -DEPTH / 2 - .07), Color3.new(1, 1, 1))
 plate.Transparency = 1
 decal(plate, Enum.NormalId.Front, image)
 decal(carton, Enum.NormalId.Left, image)
 decal(carton, Enum.NormalId.Right, image)
 label.Name = "Label"
 -- The straw leans out of the roof, bending at the top.
 local strawColor = look.straw or Color3.new(1, 1, 1)
 local straw = part(model, "Straw", "Part", Vector3.new(1.5, .17, .17),
  CFrame.new(.55, HEIGHT + ROOF + .45, .2) * CFrame.Angles(0, 0, math.rad(82)), strawColor)
 straw.Shape = Enum.PartType.Cylinder
 local tip = part(model, "StrawTip", "Part", Vector3.new(.5, .17, .17),
  straw.CFrame * CFrame.new(.72, 0, 0) * CFrame.Angles(0, 0, math.rad(45)) * CFrame.new(.22, 0, 0), strawColor)
 tip.Shape = Enum.PartType.Cylinder
 part(model, "StrawHole", "Part", Vector3.new(.06, .3, .3), CFrame.new(.6, HEIGHT + ROOF * .55, .2) * CFrame.Angles(0, 0, math.rad(90)),
  darker(roof, .45)).Shape = Enum.PartType.Cylinder
 if look.accent then
  -- Thin Neon trims under the top band and above the bottom band.
  for _, y in {HEIGHT - .32, .52} do
   part(model, "Trim", "Part", Vector3.new(WIDTH + .07, .06, DEPTH + .07), CFrame.new(0, y, 0), look.accent, Enum.Material.Neon)
  end
 end
 if look.splash then
  -- A gold coin leaning on the front corner and a few drops splashing off the roof.
  local coin = part(model, "Coin", "Part", Vector3.new(.12, .7, .7),
   CFrame.new(.78, .52, -DEPTH / 2 - .2) * CFrame.Angles(0, math.rad(80), math.rad(-15)), bands, Enum.Material.Metal)
  coin.Shape = Enum.PartType.Cylinder
  for index, drop in {{-.75, HEIGHT + .55, -.45, .32}, {-.98, HEIGHT + .9, -.3, .22}, {.95, HEIGHT + .7, -.35, .26}} do
   part(model, "Drop" .. index, "Part", Vector3.one * drop[4], CFrame.new(drop[1], drop[2], drop[3]), look.splash).Shape = Enum.PartType.Ball
  end
 end
 return model
end

return JuiceModels
