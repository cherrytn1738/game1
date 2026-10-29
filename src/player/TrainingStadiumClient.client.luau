-- Training Ground and hub presentation on this client only, in every World's hub:
--  * each cage's lock sign shows the Rebirths still needed or the Robux pass price
--  * a label floats over each cage's door with its name, whether this player may use it and
--    its Power multiplier (shown only near the camera, WorldUIClient)
--  * parts tagged by the server (Spin, SpinPivot, Bob, Sway, Pulse attributes) in fantasy
--    cages, hub scenery and World portals are animated
--  * a cage's Tint* attributes grade the view while the camera is inside it
-- Display only; the server decides who can train on each plate.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Storage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Config = require(Storage:WaitForChild("TrainingConfig"))
local Worlds = require(Storage:WaitForChild("WorldConfig"))
local WorldUI = require(Storage:WaitForChild("WorldUIConfig"))
local UI = require(script.Parent:WaitForChild("UICommon"))

local LABEL_SIZE = UDim2.fromScale(14, 7) -- studs
-- Every label floats at the same height, just above a standard cage's roof: from the sign over
-- the door (Cage.doorHeight + 1.8 up) to 1.5 studs over Cage.height, plus half the label.
local LABEL_OFFSET = Vector3.new(0, Config.Cage.height + 1.5 + LABEL_SIZE.Y.Scale / 2 - (Config.Cage.doorHeight + 1.8), 0)

local hubs, groundFolders = {}, {}
for _, world in Worlds.Worlds do
 if world.hub then
  local hub = workspace:WaitForChild(world.hub.name)
  table.insert(hubs, hub)
  if Config.GetHub(world.id) then table.insert(groundFolders, hub:WaitForChild("TrainingGrounds")) end
 end
end
local pending = false
local animated = {}

-- Cages with a Tint* attribute grade the view while this player's camera is inside them.
local grade = Instance.new("ColorCorrectionEffect")
grade.Name, grade.Enabled, grade.Parent = "TrainingGroundTint", false, game:GetService("Lighting")
local tint, blend = nil, 0

local function tintAround(position)
 local c = Config.Cage
 for _, grounds in groundFolders do
  for _, stadium in grounds:GetChildren() do
   local cage, plate = stadium:FindFirstChild("Cage"), stadium:FindFirstChild("TrainingPlate")
   if cage and plate and cage:GetAttribute("TintColor") then
    local p = plate.CFrame:PointToObjectSpace(position)
    if p.X > c.left and p.X < c.right and p.Z > c.front and p.Z < c.back and p.Y > -1 and p.Y < c.height + 4 then
     return cage
    end
   end
  end
 end
 return nil
end

-- A cage is only reachable from inside an unlocked World, so its sign needs no World check.
local function lockText(ground)
 if Config.IsPaid(ground) then
  local pass = Config.GetPassGround(ground)
  if Player:GetAttribute("TrainingPass_" .. pass.id) then return nil end
  return "🔒 R$ " .. pass.robuxPrice
 end
 local rebirths = Player:GetAttribute("Rebirths") or 0
 if rebirths >= ground.requiredRebirths then return nil end
 return "🔒 " .. ground.requiredRebirths .. " REBIRTHS"
end

local function line(gui, name, order, height, color)
 local label = UI.Label(gui, name, "", 40, color)
 label.Size, label.LayoutOrder = UDim2.fromScale(1, height), order
 label.TextXAlignment, label.TextScaled = Enum.TextXAlignment.Center, true
 return label
end

-- The floating label over a cage's door (made once per streamed-in cage). Themed cages and
-- their door decorations rise above the standard roof, so it draws on top of the scenery
-- (WorldUIClient keeps only the nearby ones showing).
local function groundLabel(entrance, ground)
 local gui = entrance:FindFirstChild("GroundLabel")
 if gui then return gui end
 gui = Instance.new("BillboardGui")
 gui.Name, gui.Size, gui.StudsOffsetWorldSpace = "GroundLabel", LABEL_SIZE, LABEL_OFFSET
 gui.AlwaysOnTop, gui.LightInfluence, gui.ResetOnSpawn = true, 0, false
 local layout = Instance.new("UIListLayout")
 layout.SortOrder, layout.HorizontalAlignment = Enum.SortOrder.LayoutOrder, Enum.HorizontalAlignment.Center
 layout.VerticalAlignment, layout.Parent = Enum.VerticalAlignment.Bottom, gui
 line(gui, "GroundName", 1, .34, UI.Colors.Text).Text = string.upper(ground.displayName)
 line(gui, "Status", 2, .28, UI.Colors.Text)
 line(gui, "Boost", 3, .38, UI.Colors.Gold).Text = "×" .. ground.powerMultiplier .. " POWER"
 gui.Parent = entrance
 WorldUI.Register(gui, "Training")
 return gui
end

local function apply()
 pending = false
 for _, grounds in groundFolders do
  for _, ground in Config.Grounds do
   local stadium = grounds:FindFirstChild(ground.id)
   local text = lockText(ground)
   local sign = stadium and stadium:FindFirstChild("LockSign", true)
   if sign then
    sign.Transparency = text and 0 or 1
    for _, gui in sign:GetChildren() do
     if gui:IsA("SurfaceGui") then
      gui.Enabled = text ~= nil
      gui.Label.Text = text or ""
     end
    end
   end
   local entrance = stadium and stadium:FindFirstChild("EntranceSign", true)
   if entrance then
    local status = groundLabel(entrance, ground).Status
    status.Text = text or "UNLOCKED"
    status.TextColor3 = text and UI.Colors.Error or UI.Showcase.Value
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
  pivot = part:GetAttribute("SpinPivot"), -- part-space point to turn about (clock hands)
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
   local turn = CFrame.fromAxisAngle(state.axis, (now * state.spin) % (2 * math.pi))
   frame = state.pivot and frame * CFrame.new(state.pivot) * turn * CFrame.new(-state.pivot) or frame * turn
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

-- Hub parts stream in and out as players move between Worlds; watch each hub as a whole.
for _, hub in hubs do
 hub.DescendantAdded:Connect(function(object)
  schedule()
  track(object)
 end)
 for _, object in hub:GetDescendants() do track(object) end
end
Player:GetAttributeChangedSignal("Rebirths"):Connect(schedule)
for _, ground in Config.PassGrounds do
 Player:GetAttributeChangedSignal("TrainingPass_" .. ground.id):Connect(schedule)
end
schedule()
