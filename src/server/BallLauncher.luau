local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progression = require(ReplicatedStorage:WaitForChild("ProgressionConfig"))
local Swing = require(ReplicatedStorage:WaitForChild("SwingConfig"))
local Field = require(ReplicatedStorage:WaitForChild("FieldConfig"))
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Progress = require(script.Parent:WaitForChild("WorldProgress"))

local CASH_PER_STUD = 1
local FLIGHT_SPEEDUP = 2
-- The giant portal at a runway's end (WorldConfig endPortal, built by RunwayDecor): a ball that
-- reaches the endpoint is pulled into its opening over this long, spiralling in, and the hit
-- counts as reaching the endpoint.
local PORTAL_SUCTION_SECONDS = 1.4
local PORTAL_SWIRL_RADIUS = 14
local BallLauncher = {}
-- Set by BattingTimingServer: called with (player, world, nextWorld) when a hit through a
-- World's end portal completes it for the first time, to play the trip to the next World.
BallLauncher.OnPortalJourney = nil
-- Set by BattingTimingServer: called with (player, world) instead when that World is the last
-- one for now (its endPortal has a finale), to play the temporary "you finished" finale.
BallLauncher.OnGameFinale = nil
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
 for _, name in {"LaunchLevel", "LaunchAngleDegrees", "LaunchSpeed", "CurrentSectionId",
  "LegendaryHitUserId", "LegendaryLaunchAt", "MythicHitUserId", "MythicLaunchAt", "PortalCaptured"} do
  ball:SetAttribute(name, nil)
 end
end

local function cleanup(station, hit)
 if station.hit ~= hit then return end
 station.hit = nil
 hit.finished = true
 hit.player:SetAttribute("HitActive", false)
 hit.player:SetAttribute("BallFlightSpeed", nil)
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

function BallLauncher.SpeedUp(player, session)
 if not Field.FlightSpeedUpEnabled then return false end
 local station = stations[player:GetAttribute("CurrentWorldId")]
 local hit = station and station.hit
 if not hit or hit.player ~= player or hit.finished or not hit.force
  or hit.result.session ~= session or not hit.speed
  or not PlayerData.IsReady(player) or not player:GetAttribute("BattingActive") then return false end
 local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if player.Character ~= hit.character or not humanoid or humanoid.Health <= 0 then return false end
 -- One-way per hit: repeated on/off switching measurably changed final distance
 -- in playtests, so 2x stays on until this hit finishes.
 if hit.speed ~= Field.HitTimeScale then return false end
 -- Time scaling: velocity scales by 2, acceleration by 4. Scaling only velocity
 -- would turn this convenience action into a large distance/power upgrade.
 -- The airborne arc is preserved approximately; Roblox collision/rolling
 -- responses are not time-scalable, so final distances can still differ.
 local ball = station.ball
 ball.AssemblyLinearVelocity *= FLIGHT_SPEEDUP
 ball.AssemblyAngularVelocity *= FLIGHT_SPEEDUP
 local gravity = Vector3.yAxis * ball.AssemblyMass * Workspace.Gravity
 hit.force.Force = hit.force.Force * FLIGHT_SPEEDUP^2 - gravity * (FLIGHT_SPEEDUP^2 - 1)
 hit.speed = Field.HitTimeScale * FLIGHT_SPEEDUP
 player:SetAttribute("BallFlightSpeed", FLIGHT_SPEEDUP)
 return true
end

local function launch(station, hit)
 if station.hit ~= hit then return end
 local player, tool, result = hit.player, hit.tool, hit.result
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not PlayerData.IsReady(player) or player:GetAttribute("CurrentWorldId") ~= station.world.id
  or not player:GetAttribute("BattingActive") or station.area.BatterPosition:GetAttribute("OccupantUserId") ~= player.UserId
  or tool.Parent ~= character or tool:GetAttribute("BattingSession") ~= result.session
  or not humanoid or humanoid.Health <= 0 then cleanup(station, hit) return end

 local ball, world = station.ball, station.world
 local originFrame = teeFrame(station)
 local difference = station.area.HitDirection.Position - originFrame.Position
 local flat = Vector3.new(difference.X, 0, difference.Z)
 if flat.Magnitude < 0.01 then warn("HitDirection must be separated from the tee.") cleanup(station, hit) return end
 local forward = flat.Unit
 result.launchAngleDegrees = Progression.LaunchAngleDegrees
 result.launchSpeed = Progression.GetLaunchSpeed(result.launchLevel)
 local loft = math.rad(result.launchAngleDegrees)
 ball.CFrame = originFrame
 ball.Anchored = false
 ball:SetNetworkOwner(nil)
 -- Played at HitTimeScale: velocity x s here; gravity and rolling friction x s^2 in tracking.
 local timeScale = Field.HitTimeScale
 ball.AssemblyLinearVelocity = (forward * (result.launchSpeed * math.cos(loft)) + Vector3.yAxis * (result.launchSpeed * math.sin(loft))) * timeScale
 ball.AssemblyAngularVelocity = Vector3.zero
 ball:SetAttribute("BallState", "InFlight")
 ball:SetAttribute("LaunchLevel", result.launchLevel)
 ball:SetAttribute("LaunchAngleDegrees", result.launchAngleDegrees)
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
 hit.force.Force = -Vector3.yAxis * ball.AssemblyMass * Workspace.Gravity * (timeScale^2 - 1)
 hit.force.Parent = ball
 hit.speed = timeScale
 -- Only publish the speed when 2x is available; the HUD shows its button from this.
 if Field.FlightSpeedUpEnabled then player:SetAttribute("BallFlightSpeed", 1) end

 local origin = originFrame.Position
 local startedAt = os.clock()
 local slowTime = 0
 local simulationSeconds = 0
 local farthestDistance, farthestSection = 0, nil
 local lastGroundPosition, firstGroundDistance
 local lastGroundDistance = 0
 local rayParams = RaycastParams.new()
 rayParams.FilterType = Enum.RaycastFilterType.Include
 rayParams.FilterDescendantsInstances = {station.field.Ground}
 local gateCenter = world.endPortal and station.field:GetAttribute("GateCenter")

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
   swingId = result.swingId, worldId = world.id, launchLevel = result.launchLevel,
   launchAngleDegrees = result.launchAngleDegrees,
   launchSpeed = result.launchSpeed, batCashMultiplier = result.batCashMultiplier,
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
    local cashEarned = math.floor(distance * CASH_PER_STUD * result.batCashMultiplier * final.sectionMultiplier
     * PlayerData.GetJuiceMultiplier(player, "Cash"))
    result.rewardAwarded = true
    result.cashEarned, final.cashEarned = cashEarned, cashEarned
    player.leaderstats.Cash.Value += cashEarned
    player:SetAttribute("LastBatCashEarned", cashEarned)
    player:SetAttribute("LastBatCashSwingId", result.swingId)
    local granted, powerResult = PlayerData.GrantPower(player, Progression.HitPowerReward, "CompletedHit", result.ballId)
    final.powerEarned = granted and powerResult.powerGranted or 0
    player:SetAttribute("LastBatPowerEarned", final.powerEarned)
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
  -- Through the portal for the first time (or, in Studio, with the Workspace attribute
  -- ForcePortalJourney for repeat testing): the trip to the next World, or the finale after the
  -- last World.
  local nextWorld = world.nextWorldId and Worlds.Get(world.nextWorldId)
  local forced = RunService:IsStudio() and Workspace:GetAttribute("ForcePortalJourney") == true
  local firstTime = final.worldCompletionMessage or forced
  if reason == "portal" and nextWorld and firstTime and BallLauncher.OnPortalJourney
   and player.Parent == Players and player:GetAttribute("WorldUnlocked_" .. nextWorld.id) == true then
   BallLauncher.OnPortalJourney(player, world, nextWorld)
  elseif reason == "portal" and not nextWorld and world.endPortal.finale and firstTime and BallLauncher.OnGameFinale
   and player.Parent == Players then
   BallLauncher.OnGameFinale(player, world)
  end
 end

 -- The ball's way into the portal: from where it crossed the endpoint to the opening's centre,
 -- speeding up and spiralling tighter about the runway's axis.
 local function suctionPoint(capture, t)
  local ease = t * t
  local right = forward:Cross(Vector3.yAxis)
  local angle = ease * 4 * math.pi
  local swirl = (right * math.cos(angle) + Vector3.yAxis * math.sin(angle)) * PORTAL_SWIRL_RADIUS * math.sin(math.pi * t)
  return capture.from:Lerp(gateCenter, ease) + swirl
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
  if hit.capture then
   local t = math.min(1, (os.clock() - hit.capture.startedAt) / PORTAL_SUCTION_SECONDS)
   ball.CFrame = CFrame.new(suctionPoint(hit.capture, t))
   if t >= 1 then finish("portal", false) end
   return
  end
  local position, velocity = ball.Position, ball.AssemblyLinearVelocity
  local speed = hit.speed
  simulationSeconds += dt * speed
  if position.Magnitude ~= position.Magnitude or velocity.Magnitude ~= velocity.Magnitude
   or position.Magnitude == math.huge or velocity.Magnitude == math.huge then finish("invalid physics", true) return end
  -- Reaching the endpoint, at any height, the portal takes the ball: the hit is measured at
  -- the endpoint (the World's full distance, in its last section).
  if gateCenter and Field.GetSectionAtPosition(position, origin, forward, world)
   and Field.GetForwardDistance(position, origin, forward) >= world.endDistance then
   hit.capture = {from = position, startedAt = os.clock()}
   ball.Anchored = true
   ball:SetAttribute("PortalCaptured", true)
   lastGroundPosition, lastGroundDistance = gateCenter, world.endDistance
   firstGroundDistance = firstGroundDistance or world.endDistance
   farthestDistance = math.max(farthestDistance, world.endDistance)
   farthestSection = Field.GetSection(world.endDistance, world)
   return
  end
  local contact = Workspace:Raycast(position, -Vector3.yAxis * (ball.Size.Y / 2 + 0.1), rayParams)
  local section = sample(position, contact ~= nil)
  local grounded = section ~= nil and contact ~= nil
  if ball:GetAttribute("CurrentSectionId") ~= (section and section.id) then ball:SetAttribute("CurrentSectionId", section and section.id) end
  local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
  local force = -Vector3.yAxis * ball.AssemblyMass * Workspace.Gravity * (speed^2 - 1)
  if grounded and math.abs(velocity.Y) < 2 * speed and horizontal.Magnitude > 0.01 then
   local acceleration = math.min(Field.RollingDeceleration * speed^2, horizontal.Magnitude / math.max(dt, 1/240) * 0.5)
   force -= horizontal.Unit * ball.AssemblyMass * acceleration
  end
  hit.force.Force = force
  local surfaceSpeed = ball.AssemblyAngularVelocity.Magnitude * ball.Size.Y / 2
  if grounded and velocity.Magnitude <= Field.StopLinearSpeed * speed and surfaceSpeed <= Field.StopSurfaceSpeed * speed then
   slowTime += dt * speed
  else
   slowTime = 0
  end
  if slowTime >= Field.StopHoldSeconds then finish("stopped", false)
  elseif position.Y < Field.GroundTop - 50 then finish("out of bounds", true)
  elseif simulationSeconds >= Field.MaximumFlightSeconds then finish("timeout", true) end
 end)
 print(string.format("[BallLaunch] %s / %s: Level %d, loft %.1f, speed %.1f",
  player.Name, world.id, result.launchLevel, result.launchAngleDegrees, result.launchSpeed))
end

-- Seconds after an accepted swing before the launch, so the ball visibly leaves the tee at
-- the animation's contact on the batter's screen (see Swing.LaunchVisualLead).
local function launchDelay(player)
 local ok, ping = pcall(function() return player:GetNetworkPing() end)
 ping = ok and type(ping) == "number" and math.clamp(ping, 0, 0.5) or 0
 return math.max(Swing.MinimumLaunchDelay, Swing.ContactTime - Swing.LaunchVisualLead - ping)
end

-- Rare cinematic hit roll: "Mythic", "Legendary" or nil (see Swing.MythicHit / LegendaryHit).
-- In Studio only, the Workspace attributes ForceMythicHit / ForceLegendaryHit force them for
-- testing (both set: they take turns).
local specialRandom = Random.new()
local forcedTurn = false
local function rollSpecialHit()
 if RunService:IsStudio() then
  local mythic, legendary = Workspace:GetAttribute("ForceMythicHit"), Workspace:GetAttribute("ForceLegendaryHit")
  if mythic and legendary then
   forcedTurn = not forcedTurn
   return forcedTurn and "Mythic" or "Legendary"
  elseif mythic then return "Mythic"
  elseif legendary then return "Legendary" end
 end
 local roll = specialRandom:NextNumber()
 if roll < Swing.MythicHit.Chance then return "Mythic" end
 if roll < Swing.MythicHit.Chance + Swing.LegendaryHit.Chance then return "Legendary" end
 return nil
end
local SPECIAL_HITS = {Mythic = Swing.MythicHit, Legendary = Swing.LegendaryHit}

function BallLauncher.TryLaunch(player, result, tool)
 local station = stations[result.worldId]
 if not station or station.hit or not PlayerData.IsReady(player)
  or not Progression.IsInteger(result.launchLevel, Progression.StartingLevel, Progression.GetLevelCap(Progression.MaxRebirths))
  or player:GetAttribute("CurrentWorldId") ~= result.worldId then return false end
 local hit = {player = player, tool = tool, result = result}
 station.hit = hit
 player:SetAttribute("HitActive", true)
 player:SetAttribute("BallFlightSpeed", nil)
 station.ball:SetAttribute("BallState", "Reserved")
 local delay = launchDelay(player)
 local special = rollSpecialHit()
 if special then
  -- Only the launch waits: the same launch, distance and rewards follow.
  delay += SPECIAL_HITS[special].HoldSeconds
  station.ball:SetAttribute(special .. "HitUserId", player.UserId)
  station.ball:SetAttribute(special .. "LaunchAt", Workspace:GetServerTimeNow() + delay)
  print(string.format("[%sHit] %s / %s", special, player.Name, station.world.id))
 end
 task.delay(delay, launch, station, hit)
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
