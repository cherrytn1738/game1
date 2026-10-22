-- The World portal on a hub's portal pad (WorldConfig hub.portalPad), in FieldBuilder's hub
-- frame. The model is ServerStorage.RunwayAssets.WorldPortal (Studio-managed, from
-- tools/blender/world_portal.py), or a plain octagon of parts until it is imported. An
-- invisible Trigger fills the opening; stepping into it opens the Worlds menu on that client
-- (WorldTravelClient), and travel itself stays the server-checked World Travel request.
-- Parts with Spin/Pulse attributes are animated on each client (TrainingStadiumClient).
local ServerStorage = game:GetService("ServerStorage")

local Portal = {}

local HEIGHT = 26 -- studs from the pad to the top of the model
local BRASS = Color3.fromRGB(222, 168, 72)
local GOLD = Color3.fromRGB(255, 204, 70)
local IRON = Color3.fromRGB(58, 54, 66)
local VORTEX = Color3.fromRGB(34, 168, 214)
local SWIRL = Color3.fromRGB(160, 242, 255)
local M = Enum.Material

-- Looks for the Blender model's meshes, by name: color, material, and optional motion
-- (Spin in degrees per second about SpinAxis in part space; the portal faces its part Z).
local LOOKS = {
 PortalFrame = {color = BRASS, material = M.SmoothPlastic},
 PortalBands = {color = IRON, material = M.Metal},
 PortalRivets = {color = Color3.fromRGB(255, 222, 140), material = M.SmoothPlastic},
 PortalMarkers = {color = Color3.fromRGB(255, 240, 190), material = M.SmoothPlastic},
 PortalBase = {color = Color3.fromRGB(74, 64, 104), material = M.SmoothPlastic, collide = true},
 PortalBaseTrim = {color = GOLD, material = M.SmoothPlastic},
 PortalClock = {color = Color3.fromRGB(252, 246, 226), material = M.SmoothPlastic},
 PortalClockRim = {color = GOLD, material = M.SmoothPlastic},
 PortalHourHand = {color = Color3.fromRGB(40, 34, 52), material = M.SmoothPlastic, spin = 6},
 PortalMinuteHand = {color = Color3.fromRGB(40, 34, 52), material = M.SmoothPlastic, spin = 45},
 PortalGearA = {color = Color3.fromRGB(196, 142, 58), material = M.SmoothPlastic, spin = 24},
 PortalGearB = {color = Color3.fromRGB(196, 142, 58), material = M.SmoothPlastic, spin = -30},
 PortalLampFrames = {color = IRON, material = M.Metal},
 PortalLampGlow = {color = Color3.fromRGB(130, 240, 255), material = M.Neon, pulse = 0.6, light = true},
 PortalVortex = {color = VORTEX, material = M.Neon},
 PortalSwirl = {color = SWIRL, material = M.Neon, spin = -70},
}

local function prepare(part, collide)
 part.Anchored = true
 part.CanCollide, part.CanQuery, part.CanTouch = collide == true, collide == true, false
end

local function placeModel(template, base)
 local model = template:Clone()
 model.Name = "PortalModel"
 for _, part in model:GetDescendants() do
  if part:IsA("BasePart") then
   local look = LOOKS[part.Name]
   prepare(part, look and look.collide)
   if look then
    part.Color, part.Material = look.color, look.material
    if look.spin then
     part:SetAttribute("Spin", look.spin)
     part:SetAttribute("SpinAxis", Vector3.zAxis)
    end
    if look.pulse then part:SetAttribute("Pulse", look.pulse) end
    if look.light then
     local light = Instance.new("PointLight")
     light.Color, light.Range, light.Brightness, light.Shadows = look.color, 12, 1.5, false
     light.Parent = part
    end
   end
  end
 end
 -- Stand the model's bounding-box bottom centre on the pad, scaled to HEIGHT. The imported
 -- model faces its -Z, which is the hub frame's -Z (toward the spawn and tee).
 local box, size = model:GetBoundingBox()
 model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
 model:ScaleTo(model:GetScale() * HEIGHT / size.Y)
 model:PivotTo(base)
 return model
end

-- The stand-in until the Blender model is imported: an octagonal brass frame and a glowing disc.
local function placeholder(base)
 local model = Instance.new("Model")
 model.Name = "PortalModel"
 local radius, center = 10, base * CFrame.new(0, 12, 0)
 local function piece(name, size, cframe, color, material)
  local part = Instance.new("Part")
  part.Name, part.Size, part.CFrame = name, size, cframe
  part.Color, part.Material = color, material
  prepare(part)
  part.Parent = model
  return part
 end
 local side = 2 * radius * math.tan(math.pi / 8)
 for i = 0, 7 do
  local angle = i * math.pi / 4
  piece("PortalFrame", Vector3.new(side + 1.6, 2.4, 2.4),
   center * CFrame.Angles(0, 0, angle) * CFrame.new(0, -radius, 0), BRASS, M.SmoothPlastic)
 end
 local disc = piece("PortalVortex", Vector3.new(0.4, radius * 2, radius * 2), center * CFrame.Angles(0, math.pi / 2, 0), VORTEX, M.Neon)
 disc.Shape = Enum.PartType.Cylinder
 return model
end

-- Builds hub.WorldPortal (rebuilt each time) on the pad. Returns the portal model.
function Portal.Build(hub, frame, pad)
 local old = hub:FindFirstChild("WorldPortal")
 if old then old:Destroy() end
 local portal = Instance.new("Model")
 portal.Name = "WorldPortal"
 -- pad.yaw turns the portal from facing the hub frame's -Z (toward the tee).
 local base = frame * CFrame.new(pad.center) * CFrame.Angles(0, pad.yaw or 0, 0)
 local assets = ServerStorage:FindFirstChild("RunwayAssets")
 local template = assets and assets:FindFirstChild("WorldPortal")
 local model = template and placeModel(template, base) or placeholder(base)
 model.Parent = portal

 -- The trigger fills the opening, a little deeper than the frame, down to the pad.
 local vortex = model:FindFirstChild("PortalVortex", true)
 local opening = vortex and math.max(vortex.Size.X, vortex.Size.Y, vortex.Size.Z) or 18
 local openingCenter = vortex and vortex.Position or (base * CFrame.new(0, 12, 0)).Position
 local bottom = base.Position.Y
 local top = openingCenter.Y + opening * 0.4
 local trigger = Instance.new("Part")
 trigger.Name, trigger.Transparency = "Trigger", 1
 trigger.Size = Vector3.new(opening * 0.8, top - bottom, 4)
 trigger.CFrame = base.Rotation + Vector3.new(openingCenter.X, (top + bottom) / 2, openingCenter.Z)
 trigger.Anchored, trigger.CanCollide, trigger.CanQuery, trigger.CanTouch = true, false, false, false
 trigger.Parent = portal

 -- Sign above the portal.
 local anchor = Instance.new("Part")
 anchor.Name, anchor.Transparency, anchor.Size = "SignAnchor", 1, Vector3.new(1, 1, 1)
 anchor.CFrame = base * CFrame.new(0, HEIGHT + 7, 0)
 prepare(anchor)
 anchor.Parent = portal
 local gui = Instance.new("BillboardGui")
 gui.Name, gui.Size, gui.MaxDistance, gui.LightInfluence = "Sign", UDim2.fromScale(30, 10), 400, 0
 gui.Parent = anchor
 local function text(content, y, height, color)
  local label = Instance.new("TextLabel")
  label.BackgroundTransparency, label.Font, label.TextScaled = 1, Enum.Font.FredokaOne, true
  label.Text, label.TextColor3 = content, color
  label.Position, label.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, height)
  label.Parent = gui
  local stroke = Instance.new("UIStroke")
  stroke.Thickness, stroke.Color, stroke.Transparency = 3, Color3.fromRGB(30, 20, 50), 0.2
  stroke.Parent = label
 end
 text("WORLDS", 0, 0.45, GOLD)
 text("TRAVEL PORTAL", 0.42, 0.28, Color3.fromRGB(255, 255, 255))
 text("Step in to choose a World", 0.72, 0.2, SWIRL)

 portal.Parent = hub
 return portal
end

return Portal
