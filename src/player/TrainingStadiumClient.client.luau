-- Training Ground presentation on this client only:
--  * each cage's lock sign shows the Rebirths still needed or the Robux pass price
--  * fantasy cage parts tagged by the server (Spin, Bob, Sway, Pulse attributes) are animated
--  * a cage's Tint* attributes grade the view while the camera is inside it
-- Display only; the server decides who can train on each plate.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Storage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Config = require(Storage:WaitForChild("TrainingConfig"))
local Worlds = require(Storage:WaitForChild("WorldConfig"))

local grounds = workspace:WaitForChild(Worlds.Get(Worlds.StartingWorldId).hub.name):WaitForChild("TrainingGrounds")
local pending = false
local animated = {}

-- Cages with a Tint* attribute grade the view while this player's camera is inside them.
local grade = Instance.new("ColorCorrectionEffect")
grade.Name, grade.Enabled, grade.Parent = "TrainingGroundTint", false, game:GetService("Lighting")
local tint, blend = nil, 0

local function tintAround(position)
 local c = Config.Cage
 for _, stadium in grounds:GetChildren() do
  local cage, plate = stadium:FindFirstChild("Cage"), stadium:FindFirstChild("TrainingPlate")
  if cage and plate and cage:GetAttribute("TintColor") then
   local p = plate.CFrame:PointToObjectSpace(position)
   if p.X > c.left and p.X < c.right and p.Z > c.front and p.Z < c.back and p.Y > -1 and p.Y < c.height + 4 then
    return cage
   end
  end
 end
 return nil
end

local function lockText(ground)
 if Config.IsPaid(ground) then
  if Player:GetAttribute("TrainingPass_" .. ground.id) then return nil end
  return "🔒 R$ " .. ground.robuxPrice
 end
 local rebirths = Player:GetAttribute("Rebirths") or 0
 if rebirths >= ground.requiredRebirths then return nil end
 return "🔒 " .. ground.requiredRebirths .. " REBIRTHS"
end

local function apply()
 pending = false
 for _, ground in Config.Grounds do
  local stadium = grounds:FindFirstChild(ground.id)
  local sign = stadium and stadium:FindFirstChild("LockSign", true)
  if sign then
   local text = lockText(ground)
   sign.Transparency = text and 0 or 1
   for _, gui in sign:GetChildren() do
    if gui:IsA("SurfaceGui") then
     gui.Enabled = text ~= nil
     gui.Label.Text = text or ""
    end
   end
  end
 end
end

-- Cages stream in as players approach; batch late arrivals into one pass.
local function schedule()
 if pending then return end
 pending = true
 task.defer(apply)
end

-- Motion is applied relative to the CFrame the server built, so it never drifts.
local function track(part)
 if not part:IsA("BasePart") or animated[part] then return end
 local spin, bob, sway, pulse = part:GetAttribute("Spin"), part:GetAttribute("Bob"), part:GetAttribute("Sway"), part:GetAttribute("Pulse")
 if not (spin or bob or sway or pulse) then return end
 animated[part] = {
  base = part.CFrame, transparency = part.Transparency, height = part.Size.Y,
  spin = spin and math.rad(spin), axis = part:GetAttribute("SpinAxis") or Vector3.yAxis,
  bob = bob, bobSpeed = part:GetAttribute("BobSpeed") or 1,
  sway = sway and math.rad(sway), swaySpeed = part:GetAttribute("SwaySpeed") or 1,
  phase = part:GetAttribute("Phase") or 0, pulse = pulse,
 }
end

RunService.RenderStepped:Connect(function(dt)
 local now = os.clock()
 local camera = workspace.CurrentCamera
 local inside = camera and tintAround(camera.CFrame.Position)
 if inside then tint = inside end
 blend = math.clamp(blend + (inside and dt or -dt) * 2.5, 0, 1)
 grade.Enabled = blend > 0 and tint ~= nil and tint.Parent ~= nil
 if grade.Enabled then
  grade.TintColor = Color3.new(1, 1, 1):Lerp(tint:GetAttribute("TintColor"), blend)
  grade.Brightness = (tint:GetAttribute("TintBrightness") or 0) * blend
  grade.Contrast = (tint:GetAttribute("TintContrast") or 0) * blend
  grade.Saturation = (tint:GetAttribute("TintSaturation") or 0) * blend
 end
 for part, state in animated do
  if not part.Parent then
   animated[part] = nil
   continue
  end
  local frame = state.base
  if state.bob then
   frame = frame + Vector3.yAxis * math.sin(now * state.bobSpeed + state.phase) * state.bob
  end
  if state.spin then
   frame = frame * CFrame.fromAxisAngle(state.axis, (now * state.spin) % (2 * math.pi))
  end
  if state.sway then
   -- Rock about the base of the part (its local bottom), like weed or a hanging lantern.
   local angle = math.sin(now * state.swaySpeed + state.phase) * state.sway
   local base = CFrame.new(0, -state.height / 2, 0)
   frame = frame * base * CFrame.Angles(angle, 0, angle * 0.6) * base:Inverse()
  end
  if state.spin or state.bob or state.sway then part.CFrame = frame end
  if state.pulse then
   part.Transparency = state.transparency + (1 - state.transparency) * 0.35 * (0.5 + 0.5 * math.sin(now * state.pulse * 2 * math.pi + state.phase))
  end
 end
end)

grounds.DescendantAdded:Connect(function(object)
 schedule()
 track(object)
end)
for _, object in grounds:GetDescendants() do track(object) end
Player:GetAttributeChangedSignal("Rebirths"):Connect(schedule)
for _, ground in Config.Grounds do
 if Config.IsPaid(ground) then Player:GetAttributeChangedSignal("TrainingPass_" .. ground.id):Connect(schedule) end
end
schedule()
