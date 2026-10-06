local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Timing = require(ReplicatedStorage:WaitForChild("BattingTimingConfig"))
local Field = require(ReplicatedStorage:WaitForChild("FieldConfig"))
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Progress = require(script.Parent:WaitForChild("WorldProgress"))

local CONTACT_DELAY = 0.20
local BASE_LAUNCH_SPEED = 130
local CASH_PER_STUD = 1
local VALID_QUALITY = {Perfect = true, Good = true, Okay = true}
local BallLauncher = {}
local stations = {}

local function teeFrame(station)
 local ball = station.ball
 return station.area.Tee.Stem.BallPosition.WorldCFrame * CFrame.new(0, ball.Size.Y / 2, 0)
end

local function resetBall(station)
 local ball = station.ball
 ball.Anchored = true
 ball.AssemblyLinearVelocity, ball.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
 ball.CFrame = teeFrame(station)
 ball:SetAttribute("BallState", "Ready")
 for _, name in {"LastHitQuality", "LaunchAngleDegrees", "HorizontalAngleDegrees", "LaunchSpeed", "CurrentSectionId"} do
  ball:SetAttribute(name, nil)
 end
end

local function cleanup(station, hit)
 if station.hit ~= hit then return end
 station.hit = nil
 hit.finished = true
 if hit.tracking then hit.tracking:Disconnect() end
 if hit.groundContact then hit.groundContact:Disconnect() end
 if hit.force then hit.force:Destroy() end
 if hit.attachment then hit.attachment:Destroy() end
 if hit.focused and hit.player.Parent == Players then hit.player:RemoveReplicationFocus(station.ball) end
 resetBall(station)
end

function BallLauncher.CancelPlayer(player)
 for _, station in stations do
  if station.hit and station.hit.player == player then cleanup(station, station.hit) end
 end
end

function BallLauncher.IsBusy(worldId)
 local station = stations[worldId]
 return not station or station.hit ~= nil
end

local function launch(station, hit)
 if station.hit ~= hit then return end
 local player, tool, result = hit.player, hit.tool, hit.result
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not PlayerData.IsReady(player) or player:GetAttribute("CurrentWorldId") ~= station.world.id
  or not player:GetAttribute("BattingActive") or station.area.BatterPosition:GetAttribute("OccupantUserId") ~= player.UserId
  or tool.Parent ~= character or tool:GetAttribute("TimingSession") ~= result.session
  or not humanoid or humanoid.Health <= 0 then cleanup(station, hit) return end

 local ball, world = station.ball, station.world
 local originFrame = teeFrame(station)
 local difference = station.area.HitDirection.Position - originFrame.Position
 local flat = Vector3.new(difference.X, 0, difference.Z)
 if flat.Magnitude < 0.01 then warn("HitDirection must be separated from the tee.") cleanup(station, hit) return end
 local forward = flat.Unit
 result.horizontalAngleDegrees = Timing.GetHorizontalAngleDegrees(result.timingOffset)
 result.launchAngleDegrees = Timing.GetLaunchAngleDegrees(result.timingOffset)
 result.launchSpeed = BASE_LAUNCH_SPEED * result.batPowerMultiplier * Timing.GetPowerMultiplier(result.timingOffset)
 local direction = CFrame.fromAxisAngle(Vector3.yAxis, -math.rad(result.horizontalAngleDegrees)):VectorToWorldSpace(forward)
 local loft = math.rad(result.launchAngleDegrees)
 ball.CFrame = originFrame
 ball.Anchored = false
 ball:SetNetworkOwner(nil)
 ball.AssemblyLinearVelocity = direction * (result.launchSpeed * math.cos(loft)) + Vector3.yAxis * (result.launchSpeed * math.sin(loft))
 ball.AssemblyAngularVelocity = Vector3.zero
 ball:SetAttribute("BallState", "InFlight")
 ball:SetAttribute("LastHitQuality", result.quality)
 ball:SetAttribute("LaunchAngleDegrees", result.launchAngleDegrees)
 ball:SetAttribute("HorizontalAngleDegrees", result.horizontalAngleDegrees)
 ball:SetAttribute("LaunchSpeed", result.launchSpeed)
 player:AddReplicationFocus(ball)
 hit.focused = true
 hit.character = character

 -- Ground-only rolling resistance is a physics force, never a scripted trajectory.
 -- A sphere otherwise retains substantial rolling energy on a flat Roblox floor.
 hit.attachment = Instance.new("Attachment")
 hit.attachment.Name = "RollingResistanceAttachment"
 hit.attachment.Parent = ball
 hit.force = Instance.new("VectorForce")
 hit.force.Name = "RollingResistance"
 hit.force.Attachment0 = hit.attachment
 hit.force.ApplyAtCenterOfMass = true
 hit.force.RelativeTo = Enum.ActuatorRelativeTo.World
 hit.force.Force = Vector3.zero
 hit.force.Parent = ball

 local origin = originFrame.Position
 local startedAt = os.clock()
 local slowTime = 0
 local farthestDistance, farthestSection = 0, nil
 local lastGroundPosition, firstGroundDistance
 local lastGroundDistance = 0
 local rayParams = RaycastParams.new()
 rayParams.FilterType = Enum.RaycastFilterType.Include
 rayParams.FilterDescendantsInstances = {station.field.Ground}

 local function sample(position, grounded)
  local section = Field.GetSectionAtPosition(position, origin, forward, world)
  if section then
   local distance = Field.GetForwardDistance(position, origin, forward)
   farthestDistance = math.max(farthestDistance, distance)
   if not farthestSection or section.order > farthestSection.order then farthestSection = section end
   if grounded then
    lastGroundPosition, lastGroundDistance = position, distance
    if not firstGroundDistance then firstGroundDistance = distance end
   end
  end
  return section
 end

 local function finish(reason, failsafe)
  if station.hit ~= hit or hit.finished then return end
  hit.finished = true
  if failsafe then warn("[BallFlight] " .. player.Name .. " / " .. world.id .. ": failsafe " .. reason) end
  local finalSection = lastGroundPosition and Field.GetRewardSection(lastGroundDistance, world)
  local distance = lastGroundPosition and lastGroundDistance or 0
  local final = {
   swingId = result.swingId, worldId = world.id, quality = result.quality,
   launchAngleDegrees = result.launchAngleDegrees, horizontalAngleDegrees = result.horizontalAngleDegrees,
   launchSpeed = result.launchSpeed, ballRewardMultiplier = result.ballRewardMultiplier,
   distanceStuds = distance, startPosition = origin, finalPosition = lastGroundPosition or origin,
   firstGroundDistanceStuds = firstGroundDistance, farthestDistanceStuds = farthestDistance,
   sectionId = finalSection and finalSection.id, sectionName = finalSection and finalSection.displayName or "No field landing",
   sectionMultiplier = finalSection and finalSection.rewardMultiplier or 1,
   farthestSectionId = farthestSection and farthestSection.id,
   finishReason = reason, flightSeconds = os.clock() - startedAt, measuredAt = Workspace:GetServerTimeNow(),
  }
  result.distanceResult = final
  if PlayerData.IsReady(player) and player:GetAttribute("CurrentWorldId") == world.id then
   local best = player:GetAttribute("SessionBestDistanceStuds") or 0
   final.newPersonalBest = distance > best
   if final.newPersonalBest then player:SetAttribute("SessionBestDistanceStuds", distance) end
   local previousWorld = Worlds.Get(player:GetAttribute("SessionFarthestWorldId"))
   local previousSection = previousWorld and Field.GetById(player:GetAttribute("SessionFarthestSectionId"), previousWorld)
   if farthestSection and (not previousWorld or world.order > previousWorld.order
    or (world.id == previousWorld.id and (not previousSection or farthestSection.order > previousSection.order))) then
    player:SetAttribute("SessionFarthestWorldId", world.id)
    player:SetAttribute("SessionFarthestSectionId", farthestSection.id)
   end
   if finalSection and not result.rewardAwarded then
    local cashEarned = math.floor(distance * CASH_PER_STUD * result.ballRewardMultiplier * final.sectionMultiplier)
    result.rewardAwarded = true
    result.cashEarned, final.cashEarned = cashEarned, cashEarned
    player.leaderstats.Cash.Value += cashEarned
    player:SetAttribute("LastBatCashEarned", cashEarned)
    player:SetAttribute("LastBatCashSwingId", result.swingId)
    final.worldCompletionMessage = Progress.Complete(player, world, distance)
   end
   final.personalBestStuds = player:GetAttribute("SessionBestDistanceStuds") or 0
  end
  player:SetAttribute("LastBatDistanceStuds", distance)
  player:SetAttribute("LastBatDistanceSwingId", result.swingId)
  player:SetAttribute("LastBatSectionId", final.sectionId)
  player:SetAttribute("LastBatSectionMultiplier", final.sectionMultiplier)
  player:SetAttribute("LastBatWorldId", world.id)
  ball:SetAttribute("LastHitDistanceStuds", distance)
  ball:SetAttribute("LastHitDistanceSwingId", result.swingId)
  print(string.format("[BatDistance] %s #%d %s: %.1f studs — %s, +%d Cash [%s, %.1fs]",
   player.Name, result.swingId, world.id, distance, final.sectionName, result.cashEarned or 0, reason, final.flightSeconds))
  if player.Parent == Players then
   ReplicatedStorage.BattingTiming:FireClient(player, tool, {kind = "Distance", distanceResult = final, cashEarned = result.cashEarned or 0})
  end
  cleanup(station, hit)
 end

 -- Preserve the Milestone 9 fast-bounce contact fix. Contact records a landing,
 -- but never ends a moving hit.
 hit.groundContact = ball.Touched:Connect(function(part)
  if station.hit == hit and not hit.finished and part:IsDescendantOf(station.field.Ground) then sample(ball.Position, true) end
 end)
 hit.tracking = RunService.Heartbeat:Connect(function(dt)
  if station.hit ~= hit or hit.finished then return end
  local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if not PlayerData.IsReady(player) or player.Character ~= hit.character or not h or h.Health <= 0
   or player:GetAttribute("CurrentWorldId") ~= world.id then cleanup(station, hit) return end
  local position, velocity = ball.Position, ball.AssemblyLinearVelocity
  if position.Magnitude ~= position.Magnitude or velocity.Magnitude ~= velocity.Magnitude
   or position.Magnitude == math.huge or velocity.Magnitude == math.huge then finish("invalid physics", true) return end
  local contact = Workspace:Raycast(position, -Vector3.yAxis * (ball.Size.Y / 2 + 0.1), rayParams)
  local section = sample(position, contact ~= nil)
  local grounded = section ~= nil and contact ~= nil
  if ball:GetAttribute("CurrentSectionId") ~= (section and section.id) then ball:SetAttribute("CurrentSectionId", section and section.id) end
  local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
  if grounded and math.abs(velocity.Y) < 2 and horizontal.Magnitude > 0.01 then
   local acceleration = math.min(Field.RollingDeceleration, horizontal.Magnitude / math.max(dt, 1/240) * 0.5)
   hit.force.Force = -horizontal.Unit * ball.AssemblyMass * acceleration
  else
   hit.force.Force = Vector3.zero
  end
  local surfaceSpeed = ball.AssemblyAngularVelocity.Magnitude * ball.Size.Y / 2
  if grounded and velocity.Magnitude <= Field.StopLinearSpeed and surfaceSpeed <= Field.StopSurfaceSpeed then
   slowTime += dt
  else
   slowTime = 0
  end
  if slowTime >= Field.StopHoldSeconds then finish("stopped", false)
  elseif position.Y < Field.GroundTop - 50 then finish("out of bounds", true)
  elseif os.clock() - startedAt >= Field.MaximumFlightSeconds then finish("timeout", true) end
 end)
 print(string.format("[BallLaunch] %s / %s: spray %+.1f, loft %.1f, speed %.1f",
  player.Name, world.id, result.horizontalAngleDegrees, result.launchAngleDegrees, result.launchSpeed))
end

function BallLauncher.TryLaunch(player, result, tool)
 local station = stations[result.worldId]
 if not station or station.hit or not PlayerData.IsReady(player) or not VALID_QUALITY[result.quality]
  or player:GetAttribute("CurrentWorldId") ~= result.worldId then return false end
 local hit = {player = player, tool = tool, result = result}
 station.hit = hit
 station.ball:SetAttribute("BallState", "Reserved")
 task.delay(CONTACT_DELAY, launch, station, hit)
 return true
end

local fieldServer = script.Parent:WaitForChild("FieldServer")
while not fieldServer:GetAttribute("FieldsReady") do fieldServer:GetAttributeChangedSignal("FieldsReady"):Wait() end
for _, world in Worlds.Worlds do
 local station = {world = world, area = Workspace:WaitForChild(world.stationName), field = Workspace:WaitForChild(world.fieldName)}
 station.ball = station.area:WaitForChild("Baseball")
 stations[world.id] = station
 resetBall(station)
end
return BallLauncher
