-- Studio command-bar script (not Rojo-managed): frames one paid Training Ground for its Shop card
-- screenshot (TrainingConfig shopImage), from the same view the Shop's 3D preview uses, so all
-- five screenshots match. Steps are in .vscode/MONETIZATION.md ("Training Ground Shop images").
--
-- 1. Play solo (Play, not Run). Switch the command bar's context to the Client.
-- 2. Set GROUND below, paste this whole file into the command bar and press Enter.
-- 3. Take the screenshot, then run it again with RESTORE = true (or stop the playtest).
local GROUND = "cosmic_rift" -- cosmic_rift, time_machine_lab, quantum_lab, snow_globe, dragons_lair
local RESTORE = false

-- Match ShopClient's preview (PREVIEW_VIEW, PREVIEW_FOV, PREVIEW_PADDING).
local VIEW, FOV, PADDING = Vector3.new(-1.2, .42, .75), 34, 1.06
local ASPECT = 1100 / 500 -- the screenshot's shape

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

if RESTORE then
 for _, gui in player.PlayerGui:GetChildren() do
  if gui:IsA("ScreenGui") and gui:GetAttribute("HiddenForShot") then
   gui.Enabled = true
   gui:SetAttribute("HiddenForShot", nil)
  end
 end
 StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
 camera.CameraType, camera.FieldOfView = Enum.CameraType.Custom, 70
 for _, part in (player.Character or Instance.new("Model")):GetDescendants() do
  if part:IsA("BasePart") then part.LocalTransparencyModifier = 0 end
 end
 return "restored"
end

local Training = require(game.ReplicatedStorage:WaitForChild("TrainingConfig"))
local Worlds = require(game.ReplicatedStorage:WaitForChild("WorldConfig"))
local ground = Training.Get(GROUND)
assert(ground, "Unknown ground " .. GROUND)
local hub = workspace:WaitForChild(Worlds.Get(ground.worlds[1]).hub.name)
local stadium = hub:WaitForChild("TrainingGrounds"):WaitForChild(GROUND)
local platePart = stadium:WaitForChild("TrainingPlate")
player:RequestStreamAroundAsync(platePart.Position)
local cage = stadium:WaitForChild("Cage")
local plate = platePart.CFrame

-- Hide the HUD, Roblox's own UI and your character.
for _, gui in player.PlayerGui:GetChildren() do
 if gui:IsA("ScreenGui") and gui.Enabled then
  gui.Enabled = false
  gui:SetAttribute("HiddenForShot", true)
 end
end
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
for _, part in (player.Character or Instance.new("Model")):GetDescendants() do
 if part:IsA("BasePart") then part.LocalTransparencyModifier = 1 end
end

-- Fit every visible part's corners, centred in the frame, as the Shop preview does.
local corners = {}
for _, part in cage:GetDescendants() do
 if part:IsA("BasePart") and part.Transparency < 1 then
  for _, x in {-1, 1} do for _, y in {-1, 1} do for _, z in {-1, 1} do
   table.insert(corners, part.CFrame:PointToWorldSpace(part.Size / 2 * Vector3.new(x, y, z)))
  end end end
 end
end
local view = plate:VectorToWorldSpace(VIEW.Unit)
-- Fit the centred 2.2:1 crop of this window (a narrower window crops top and bottom).
local window = camera.ViewportSize
local tanV = math.tan(math.rad(FOV / 2)) * math.min(1, window.X / window.Y / ASPECT)
local tanH = tanV * ASPECT
local function fit(target)
 local look = CFrame.lookAt(target + view, target)
 local distance = 0
 for _, corner in corners do
  local p = look:VectorToObjectSpace(corner - target)
  distance = math.max(distance, math.abs(p.X) / (tanH / PADDING) + p.Z, math.abs(p.Y) / (tanV / PADDING) + p.Z)
 end
 return distance
end
local box = cage:GetBoundingBox()
local target = box.Position
for _ = 1, 3 do
 local distance = fit(target)
 local look = CFrame.lookAt(target + view * distance, target)
 local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
 for _, corner in corners do
  local p = look:PointToObjectSpace(corner)
  local x, y = p.X / (-p.Z * tanH), p.Y / (-p.Z * tanV)
  minX, maxX, minY, maxY = math.min(minX, x), math.max(maxX, x), math.min(minY, y), math.max(maxY, y)
 end
 target += look.RightVector * ((minX + maxX) / 2 * distance * tanH) + look.UpVector * ((minY + maxY) / 2 * distance * tanV)
end
camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, FOV
camera.CFrame = CFrame.lookAt(target + view * fit(target), target)
return "framed " .. GROUND .. ": crop the viewport to 1100 x 500 (2.2:1) around the centre"
