local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Tool = script.Parent
local Player = Players.LocalPlayer

local Remote = ReplicatedStorage:WaitForChild("BattingTiming")
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Swing = require(ReplicatedStorage:WaitForChild("SwingConfig"))


-- Legacy filename retained for Rojo. This script now handles camera and leaving only.
local CAMERA_DISTANCE_BEHIND = 12
local CAMERA_HEIGHT = 3
local BATTING_CAMERA_FOV = 55
-- Cinematic launch: the view widens as the ball leaves the bat, with a short decaying shake.
local FLIGHT_CAMERA_FOV = 70
local FLIGHT_FOV_SECONDS = 0.8
local SHAKE_SECONDS = 0.35
local SHAKE_RADIANS = 0.03
-- The flight camera waits until the rendered ball has moved this far off the tee: the
-- InFlight attribute arrives before the ball's (smoothed) physics movement is drawn.
local LEAVE_DISTANCE = 0.5
-- Swing zoom: from the click, the view narrows through the backswing (Load and Windup) and
-- holds until the ball leaves the tee, when the flight widening takes over from there. If no
-- launch follows (the swing was refused), it eases back out.
local SWING_ZOOM_FOV = 46
local BACKSWING_SECONDS = 0
for _, phase in Swing.Phases do
 BACKSWING_SECONDS += phase.duration
 if phase.name == "Windup" then break end
end
local SWING_ZOOM_HOLD_SECONDS = Swing.Duration + 0.6
local SWING_ZOOM_RELEASE_SECONDS = 0.3

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
local flightStartedAt
local flightStartFov = BATTING_CAMERA_FOV
local swingStartedAt

local function ease(t) return 1 - (1 - math.clamp(t, 0, 1))^3 end

-- The batting-view FOV, zoomed while a swing is winding up.
local function swingFieldOfView()
 if not swingStartedAt then return BATTING_CAMERA_FOV end
 local elapsed = os.clock() - swingStartedAt
 local zoom = ease(elapsed / BACKSWING_SECONDS)
 if elapsed > SWING_ZOOM_HOLD_SECONDS then
  local release = (elapsed - SWING_ZOOM_HOLD_SECONDS) / SWING_ZOOM_RELEASE_SECONDS
  if release >= 1 then swingStartedAt = nil return BATTING_CAMERA_FOV end
  zoom = 1 - ease(release)
 end
 return BATTING_CAMERA_FOV + (SWING_ZOOM_FOV - BATTING_CAMERA_FOV) * zoom
end

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
 swingStartedAt = nil
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

 local readyBallPosition = (stem.BallPosition.WorldCFrame * CFrame.new(0, ball.Size.Y / 2, 0)).Position
 local leftTee = flightCameraActive or (ball.Position - readyBallPosition).Magnitude >= LEAVE_DISTANCE
 if ballState == "InFlight" and leftTee then
  if not flightCameraActive then
   local fixed = camera.CFrame -- Preserve the actual viewing rotation from just before launch.
   flightCameraActive = true
   flightCameraOffset = fixed.Position - readyBallPosition -- Same framing as from the tee.
   flightCameraRotation = fixed.Rotation
   flightStartedAt = os.clock()
   flightStartFov = camera.FieldOfView -- Widen from the swing zoom, not from the resting view.
   swingStartedAt = nil
  end
  local elapsed = os.clock() - flightStartedAt
  local widen = ease(elapsed / FLIGHT_FOV_SECONDS)
  camera.FieldOfView = flightStartFov + (FLIGHT_CAMERA_FOV - flightStartFov) * widen
  local shake = math.max(0, 1 - elapsed / SHAKE_SECONDS) * SHAKE_RADIANS
  local jolt = CFrame.Angles(math.noise(elapsed * 30, 0.5) * shake, math.noise(0.5, elapsed * 30) * shake, 0)
  camera.CFrame = CFrame.new(ball.Position + flightCameraOffset) * flightCameraRotation * jolt
 else
  flightCameraActive = false
  camera.FieldOfView = swingFieldOfView()
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
    "ExitBatting", exitAction, false, 3000, Enum.KeyCode.Space
   )
   -- HUD owns the visible Leave button; keep the Space binding here.
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

-- BatClient fires "SwingStart" on the bat's local marker when a real swing begins.
local markerConnection
task.spawn(function()
 local marker = Tool:WaitForChild("SwingMarkerReached")
 markerConnection = marker.Event:Connect(function(name)
  if name == "SwingStart" and cameraActive then swingStartedAt = os.clock() end
 end)
end)

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
 if markerConnection then markerConnection:Disconnect() end
 renderConnection:Disconnect()

end)
