local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Tool = script.Parent
local Player = Players.LocalPlayer

local Remote = ReplicatedStorage:WaitForChild("BattingTiming")
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))


-- Legacy filename retained for Rojo. This script now handles camera and leaving only.
local CAMERA_DISTANCE_BEHIND = 12
local CAMERA_HEIGHT = 3
local BATTING_CAMERA_FOV = 55

local battingArea, batterPosition, tee, stem, ball, hitDirection
local boundWorldId
local bindingVersion = 0

local function getFlatHitDirection()
 local difference = hitDirection.Position - stem.BallPosition.WorldPosition
 local flat = Vector3.new(difference.X, 0, difference.Z)
 if flat.Magnitude < 0.01 then return -Vector3.zAxis end
 return flat.Unit
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
  Remote:FireServer(Tool:GetAttribute("BattingSession"), "Exit")
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

end)

Tool.Destroying:Connect(function()
 bindingVersion += 1
 worldConnection:Disconnect()

 if exitBound then ContextActionService:UnbindAction("ExitBatting") end
 leaveBattingCamera()
 equippedConnection:Disconnect()
 renderConnection:Disconnect()

end)
