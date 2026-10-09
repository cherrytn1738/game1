local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Tool = script.Parent
local Player = Players.LocalPlayer
local Timing = require(ReplicatedStorage:WaitForChild("BattingTimingConfig"))
local Remote = ReplicatedStorage:WaitForChild("BattingTiming")
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))

-- Visual and camera tuning. The shared Timing module still owns gameplay angles.
local FAN_RADIUS = 145
local FAN_SPREAD = 160
local FAN_SEGMENTS = 160
local FAN_SCALE = 0.6
local FAN_WORLD_DISTANCE = 4
local CAMERA_DISTANCE_BEHIND = 12
local CAMERA_HEIGHT = 3
local BATTING_CAMERA_FOV = 55

local COLORS = {
 Miss = Color3.fromRGB(180, 73, 73),
 Okay = Color3.fromRGB(220, 157, 66),
 Good = Color3.fromRGB(95, 166, 192),
 Perfect = Color3.fromRGB(101, 208, 135),
}

local battingArea, batterPosition, tee, stem, ball, hitDirection
local boundWorldId
local bindingVersion = 0

local function getFlatHitDirection()
 local difference = hitDirection.Position - stem.BallPosition.WorldPosition
 local flat = Vector3.new(difference.X, 0, difference.Z)
 if flat.Magnitude < 0.01 then return -Vector3.zAxis end
 return flat.Unit
end

local gui = Instance.new("ScreenGui")
gui.Name = "BatTimingGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = true
gui.DisplayOrder = 10
gui.Enabled = false
gui.Parent = Player:WaitForChild("PlayerGui")

-- Exact original fan geometry, cropped to its occupied bounds and uniformly scaled.
local fan = Instance.new("Frame")
fan.Name = "TimingFan"
fan.AnchorPoint = Vector2.new(0.5, 1)
fan.Size = UDim2.fromOffset(304, 154)
fan.BackgroundTransparency = 1
fan.ClipsDescendants = true
fan.Parent = gui

local fanScale = Instance.new("UIScale")
fanScale.Scale = FAN_SCALE
fanScale.Parent = fan

local FAN_ORIGIN = Vector2.new(152, 152)
local function spoke(name, position, length, width, color, zIndex)
 local degrees = (position - 0.5) * FAN_SPREAD
 local radians = math.rad(degrees)
 local item = Instance.new("Frame")
 item.Name = name
 item.AnchorPoint = Vector2.new(0.5, 0.5)
 item.Position = UDim2.fromOffset(
  FAN_ORIGIN.X + math.sin(radians) * length / 2,
  FAN_ORIGIN.Y - math.cos(radians) * length / 2
 )
 item.Size = UDim2.fromOffset(width, length)
 item.Rotation = degrees
 item.BackgroundColor3 = color
 item.BorderSizePixel = 0
 item.ZIndex = zIndex
 item.Parent = fan
 return item
end

-- Rebuild only the colored sections and boundaries when the equipped Tee changes.
local fanSections = {}
local function rebuildFan()
 for _, section in fanSections do section:Destroy() end
 table.clear(fanSections)
 local scale = Equipment.Get("Tee", Player:GetAttribute("EquippedTee")).timingScale
 local windows = Timing.GetWindows(scale)
 for index = 0, FAN_SEGMENTS - 1 do
  local position = (index + 0.5) / FAN_SEGMENTS
  local errorSeconds = math.abs((position - 0.5) * Timing.TravelDuration)
  local zone = "Miss" -- Original outer color; all swings still make contact.
  if errorSeconds <= windows.Perfect then zone = "Perfect"
  elseif errorSeconds <= windows.Good then zone = "Good"
  elseif errorSeconds <= windows.Okay then zone = "Okay" end
  table.insert(fanSections, spoke(zone, position, FAN_RADIUS, 3, COLORS[zone], 1))
 end
 for _, offset in {-windows.Okay, -windows.Good, -windows.Perfect,
  windows.Perfect, windows.Good, windows.Okay} do
  table.insert(fanSections, spoke("Boundary", 0.5 + offset / Timing.TravelDuration,
   FAN_RADIUS, 1, Color3.fromRGB(30, 35, 43), 2))
 end
end
rebuildFan()
local equippedTeeConnection = Player:GetAttributeChangedSignal("EquippedTee"):Connect(rebuildFan)

local marker = spoke("Indicator", 0, FAN_RADIUS + 7, 3, Color3.new(1, 1, 1), 3)
local function moveIndicator(position)
 local degrees = (position - 0.5) * FAN_SPREAD
 local radians = math.rad(degrees)
 local length = FAN_RADIUS + 7
 marker.Position = UDim2.fromOffset(
  FAN_ORIGIN.X + math.sin(radians) * length / 2,
  FAN_ORIGIN.Y - math.cos(radians) * length / 2
 )
 marker.Rotation = degrees
end

local cameraActive = false
local savedFieldOfView
local flightCameraActive = false
local flightCameraOffset
local flightCameraRotation

local function enterBattingCamera()
 if cameraActive then return end
 local camera = workspace.CurrentCamera
 if not camera then return end
 cameraActive = true
 savedFieldOfView = camera.FieldOfView
 camera.CameraType = Enum.CameraType.Scriptable
 camera.FieldOfView = BATTING_CAMERA_FOV
end

local function leaveBattingCamera()
 if not cameraActive then return end
 cameraActive = false
 flightCameraActive = false
 local camera = workspace.CurrentCamera
 if not camera then return end
 local character = Player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 camera.CameraType = Enum.CameraType.Custom
 camera.CameraSubject = humanoid
 if savedFieldOfView then camera.FieldOfView = savedFieldOfView end
 savedFieldOfView = nil
end

local function getFixedCameraCFrame()
 local direction = getFlatHitDirection()
 local readyBallPosition = stem.BallPosition.WorldPosition + Vector3.yAxis * ball.Size.Y / 2
 local setupCenter = Vector3.new(
  (batterPosition.Position.X + readyBallPosition.X) / 2,
  readyBallPosition.Y,
  (batterPosition.Position.Z + readyBallPosition.Z) / 2
 )
 -- The character faces the tee across X, so looking exactly down the
 -- flight axis gives a stable, perpendicular profile view.
 local cameraPosition = setupCenter - direction * CAMERA_DISTANCE_BEHIND
  + Vector3.yAxis * CAMERA_HEIGHT
 return CFrame.lookAt(cameraPosition, setupCenter)
end

local function updateBattingCamera(ballState)
 local camera = workspace.CurrentCamera
 if not camera then return end
 camera.CameraType = Enum.CameraType.Scriptable
 camera.FieldOfView = BATTING_CAMERA_FOV

 if ballState == "InFlight" then
  if not flightCameraActive then
   local fixed = camera.CFrame -- Preserve the actual viewing rotation from just before launch.
   flightCameraActive = true
   flightCameraOffset = fixed.Position - ball.Position
   flightCameraRotation = fixed.Rotation
  end
  camera.CFrame = CFrame.new(ball.Position + flightCameraOffset) * flightCameraRotation
 else
  flightCameraActive = false
  camera.CFrame = getFixedCameraCFrame()
 end
end

local exitBound = false
local function exitAction(_, inputState)
 if inputState == Enum.UserInputState.Begin and not Tool:GetAttribute("ExitPending") then
  Tool:SetAttribute("ExitPending", true)
  Remote:FireServer(Tool:GetAttribute("TimingSession"), "Exit")
 end
 return Enum.ContextActionResult.Sink
end

local function updateBattingState(active)
 if active then
  if not exitBound then
   ContextActionService:BindActionAtPriority(
    "ExitBatting", exitAction, true, 3000, Enum.KeyCode.Space
   )
   ContextActionService:SetTitle("ExitBatting", "Leave")
   ContextActionService:SetPosition("ExitBatting", UDim2.new(1, -90, 1, -180))
   exitBound = true
  end
  enterBattingCamera()
 else
  gui.Enabled = false
  if exitBound then
   ContextActionService:UnbindAction("ExitBatting")
   exitBound = false
  end
  Tool:SetAttribute("ExitPending", nil)
  leaveBattingCamera()
 end
end

local function bindWorld()
 bindingVersion += 1
 local version = bindingVersion
 updateBattingState(false)
 boundWorldId, ball = nil, nil
 local world = Worlds.Get(Player:GetAttribute("CurrentWorldId"))
 if not world then return end
 task.spawn(function()
  local area = workspace:WaitForChild(world.stationName)
  local newPad = area:WaitForChild("BatterPosition")
  local newTee = area:WaitForChild("Tee")
  local newStem = newTee:WaitForChild("Stem")
  local newBall = area:WaitForChild("Baseball")
  local newDirection = area:WaitForChild("HitDirection")
  if version ~= bindingVersion or Tool.Parent == nil then return end
  battingArea, batterPosition, tee, stem, ball, hitDirection = area, newPad, newTee, newStem, newBall, newDirection
  boundWorldId = world.id
 end)
end
local worldConnection = Player:GetAttributeChangedSignal("CurrentWorldId"):Connect(bindWorld)
bindWorld()

local equippedConnection = Tool.Equipped:Connect(function()
 Tool:SetAttribute("ExitPending", nil)
end)

local renderConnection = RunService.RenderStepped:Connect(function()
 local character = Player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local equipped = Tool.Parent == character and humanoid ~= nil and humanoid.Health > 0
 local active = equipped and Player:GetAttribute("DataLoaded") == true
  and Player:GetAttribute("BattingActive") == true
  and ball ~= nil and boundWorldId == Player:GetAttribute("CurrentWorldId")
 updateBattingState(active)
 if not active then return end

 local ballState = ball:GetAttribute("BallState")
 updateBattingCamera(ballState)

 -- Reserved and InFlight both hide the fan; Ready shows it again after reset.
 gui.Enabled = ballState == "Ready"
 if not gui.Enabled then return end

 local camera = workspace.CurrentCamera
 local direction = getFlatHitDirection()
 local fanWorldPosition = ball.Position + direction * FAN_WORLD_DISTANCE
 local fanOnScreen, fanVisible = camera:WorldToViewportPoint(fanWorldPosition)
 gui.Enabled = fanVisible and fanOnScreen.Z > 0
 fan.Position = UDim2.fromOffset(fanOnScreen.X, fanOnScreen.Y)

 local startTime = Tool:GetAttribute("TimingStartTime")
 local now = workspace:GetServerTimeNow()
 if not startTime or now < startTime then
  moveIndicator(0)
  return
 end

 moveIndicator(Timing.GetPosition(now, startTime))
end)

Tool.Destroying:Connect(function()
 bindingVersion += 1
 worldConnection:Disconnect()
 equippedTeeConnection:Disconnect()
 if exitBound then ContextActionService:UnbindAction("ExitBatting") end
 leaveBattingCamera()
 equippedConnection:Disconnect()
 renderConnection:Disconnect()
 gui:Destroy()
end)
