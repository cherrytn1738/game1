-- Ground arrows that lead the local player along a route, plus a big arrow bobbing over the
-- destination. Client-only parts (nothing collides, casts shadows or replicates), pooled and
-- animated by one RenderStepped connection that only runs while arrows are showing.
--   local guide = GuideArrows.new()
--   guide:Show(points)   -- route corners after the player, the last one the destination
--   guide:Hide()
--   guide:Destroy()
-- Presentation only: the arrows never decide anything.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local GuideArrows = {}
GuideArrows.__index = GuideArrows

local SPACING = 5 -- studs between ground arrows
local START_GAP, END_GAP = 4, 3 -- studs kept clear after the player and before the destination
local MAX_ARROWS = 14
local MARKER_HEIGHT = 7 -- the destination arrow's height above the ground
local WHITE, OUTLINE = Color3.fromRGB(250, 250, 250), Color3.fromRGB(22, 24, 32)

local function part(parent, size, cframe, color)
 local p = Instance.new("Part")
 p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
 p.Material, p.Color, p.Size = Enum.Material.SmoothPlastic, color, size
 p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
 p:SetAttribute("Offset", cframe)
 p.Parent = parent
 return p
end

-- A flat chevron (">" pointing along its -Z), white with a dark outline, scale studs across.
local function chevron(scale)
 local model = Instance.new("Model")
 model.Name = "GuideArrow"
 local length, width = 2.3 * scale, 0.75 * scale
 for _, side in {-1, 1} do
  -- Each arm runs from the tip (z -1) back and out at 45 degrees.
  local rotation = CFrame.new(0.8 * scale * side, 0, -0.2 * scale) * CFrame.Angles(0, math.rad(45) * side, 0)
  part(model, Vector3.new(width + 0.35 * scale, 0.12, length + 0.35 * scale), rotation, OUTLINE)
  part(model, Vector3.new(width, 0.12, length), rotation * CFrame.new(0, 0.08, 0), WHITE)
 end
 return model
end

local function place(model, frame)
 for _, p in model:GetChildren() do p.CFrame = frame * p:GetAttribute("Offset") end
end

function GuideArrows.new()
 local self = setmetatable({}, GuideArrows)
 self.folder = Instance.new("Folder")
 self.folder.Name = "TutorialGuide"
 self.pool, self.placed = {}, {}
 self.marker = chevron(2.2)
 self.params = RaycastParams.new()
 self.params.FilterType = Enum.RaycastFilterType.Exclude
 return self
end

-- The ground under a point (ignoring characters and the guide), or the point itself.
function GuideArrows:_ground(point)
 local ignore = {self.folder}
 for _, player in Players:GetPlayers() do
  if player.Character then table.insert(ignore, player.Character) end
 end
 self.params.FilterDescendantsInstances = ignore
 local hit = workspace:Raycast(point + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), self.params)
 return hit and hit.Position or point
end

-- Lays arrows along the route from the player's position through points.
function GuideArrows:Show(points)
 local character = Players.LocalPlayer.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not root or #points == 0 then self:Hide() return end
 local route = {Vector3.new(root.Position.X, 0, root.Position.Z)}
 for _, point in points do table.insert(route, Vector3.new(point.X, 0, point.Z)) end
 local total = 0
 for i = 2, #route do total += (route[i] - route[i - 1]).Magnitude end
 table.clear(self.placed)
 local distance, segment, walked = START_GAP, 2, 0
 while distance <= total - END_GAP and #self.placed < MAX_ARROWS do
  while segment <= #route and walked + (route[segment] - route[segment - 1]).Magnitude < distance do
   walked += (route[segment] - route[segment - 1]).Magnitude
   segment += 1
  end
  if segment > #route then break end
  local from, to = route[segment - 1], route[segment]
  local direction = (to - from).Unit
  local flat = from + direction * (distance - walked)
  local ground = self:_ground(flat + Vector3.new(0, root.Position.Y, 0))
  table.insert(self.placed, CFrame.lookAt(ground, ground + direction) + Vector3.new(0, 0.12, 0))
  distance += SPACING
 end
 for index, frame in self.placed do
  local model = self.pool[index] or chevron(1)
  self.pool[index] = model
  model:SetAttribute("Base", frame)
  model.Parent = self.folder
 end
 for index = #self.placed + 1, #self.pool do self.pool[index].Parent = nil end
 local destination = points[#points]
 self.markerBase = self:_ground(destination + Vector3.new(0, root.Position.Y, 0)) + Vector3.new(0, MARKER_HEIGHT, 0)
 self.marker.Parent = self.folder
 self.folder.Parent = workspace
 if not self.connection then
  self.connection = RunService.RenderStepped:Connect(function() self:_animate() end)
 end
end

-- Arrows ripple forward along the route; the destination arrow points down and bobs.
function GuideArrows:_animate()
 local now = os.clock()
 for index = 1, #self.placed do
  local model = self.pool[index]
  local lift = 0.25 * (0.5 + 0.5 * math.sin(now * 5 - index * 0.7))
  place(model, model:GetAttribute("Base") + Vector3.new(0, lift, 0))
 end
 if self.markerBase then
  local bob = math.sin(now * 3) * 0.6
  -- Stood up with its face to the camera, pointing down at the destination.
  local camera = workspace.CurrentCamera
  local facing = camera and (camera.CFrame.Position - self.markerBase) * Vector3.new(1, 0, 1) or Vector3.zAxis
  if facing.Magnitude < 0.01 then facing = Vector3.zAxis end
  local upright = CFrame.lookAt(self.markerBase, self.markerBase + facing) * CFrame.Angles(math.rad(-90), 0, 0)
  place(self.marker, upright + Vector3.new(0, bob, 0))
 end
end

function GuideArrows:Hide()
 if self.connection then self.connection:Disconnect() self.connection = nil end
 self.folder.Parent = nil
 self.markerBase = nil
end

function GuideArrows:Destroy()
 self:Hide()
 self.folder:Destroy()
 for _, model in self.pool do model:Destroy() end
 self.marker:Destroy()
 table.clear(self.pool)
end

return GuideArrows
