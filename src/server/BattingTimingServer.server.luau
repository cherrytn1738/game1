local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Swing = require(ReplicatedStorage:WaitForChild("SwingConfig"))
-- Legacy Rojo/Remote name retained; clients send only a session and optional action.
local Remote = ReplicatedStorage:WaitForChild("BattingTiming")
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local BallLauncher = require(script.Parent:WaitForChild("BallLauncher"))

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Training = require(script.Parent:WaitForChild("TrainingService"))

local CHECK_INTERVAL = 0.1
local ENTRY_HEIGHT = 6
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Travel = ReplicatedStorage:WaitForChild("WorldTravel")
local TrainingTeleport = ReplicatedStorage:FindFirstChild("TrainingTeleport") or Instance.new("RemoteEvent")
TrainingTeleport.Name, TrainingTeleport.Parent = "TrainingTeleport", ReplicatedStorage
-- Where the Training teleport places a player, relative to the Training plate: a few studs
-- back toward the hub so they arrive beside the plate instead of on it.
local TRAINING_TELEPORT_OFFSET = Vector3.new(0, 0, 9)
local TeeTeleport = ReplicatedStorage:FindFirstChild("TeeTeleport") or Instance.new("RemoteEvent")
TeeTeleport.Name, TeeTeleport.Parent = "TeeTeleport", ReplicatedStorage
-- Where the tee teleport places a player: this many studs back from the batter's box
-- (away from the field), facing it, so batting never starts by itself.
local TEE_TELEPORT_BACK = 7
-- The trip through a World's end portal (BallLauncher.OnPortalJourney): the batter is held
-- while their client plays the cinematic (PortalJourneyClient; its screen is white from 6.85 s),
-- then travels.
local PORTAL_JOURNEY_SECONDS = 8.6
-- The finale after the last World (BallLauncher.OnGameFinale): held the same way while the
-- client celebrates (white from 11.2 s), then returned to that World's hub.
local GAME_FINALE_SECONDS = 11.8
local states = {}
local occupants = {}

local function insidePad(root, pad)
 local point = pad.CFrame:PointToObjectSpace(root.Position)
 return math.abs(point.X) <= pad.Size.X / 2
  and math.abs(point.Z) <= pad.Size.Z / 2
  and point.Y >= -1 and point.Y <= ENTRY_HEIGHT
end

local function leave(player)
 local state = states[player]
 if not state or not state.worldId or occupants[state.worldId] ~= player then return end
 local pad = workspace[Worlds.Get(state.worldId).stationName].BatterPosition
 occupants[state.worldId] = nil
 pad:SetAttribute("OccupantUserId", nil)
 pad.EntryLabel.Enabled = true
 player:SetAttribute("BattingActive", false)
 state.mustLeavePad = true -- Space must not immediately re-enter the same area.
 if state.tool then
  state.tool:SetAttribute("BattingSession", nil)
 end
 if state.root and state.root.Parent then
  state.root.Anchored = state.saved.anchored
 end
 if state.humanoid and state.humanoid.Parent then
  local humanoid = state.humanoid
  humanoid.WalkSpeed = state.saved.walkSpeed
  humanoid.JumpPower = state.saved.jumpPower
  humanoid.JumpHeight = state.saved.jumpHeight
  humanoid.AutoRotate = state.saved.autoRotate
  humanoid:UnequipTools()
 end
 state.tool, state.root, state.humanoid, state.worldId = nil, nil, nil, nil
end

local function enter(player, character, humanoid, root)
 if not PlayerData.IsReady(player) or player:GetAttribute("TrainingActive") then return end
 local state = states[player]
 local world = Worlds.Get(player:GetAttribute("CurrentWorldId"))
 if not world or player:GetAttribute("WorldUnlocked_" .. world.id) ~= true then return end
 local area = workspace[world.stationName]
 local pad = area.BatterPosition
 local backpack = player:FindFirstChildOfClass("Backpack")
 local tool = character:FindFirstChild("Bat") or (backpack and backpack:FindFirstChild("Bat"))
 if not tool or not tool:IsA("Tool") or not tool:FindFirstChild("BatClient") then return end
 if occupants[world.id] or BallLauncher.IsBusy(world.id) or state.mustLeavePad or not insidePad(root, pad) or humanoid.Sit then return end
 occupants[world.id] = player
 state.worldId = world.id
 state.root, state.humanoid, state.tool = root, humanoid, tool
 state.saved = {anchored = root.Anchored, walkSpeed = humanoid.WalkSpeed,
  jumpPower = humanoid.JumpPower, jumpHeight = humanoid.JumpHeight, autoRotate = humanoid.AutoRotate}
 state.session += 1
 tool:SetAttribute("BattingSession", state.session)
 pad:SetAttribute("OccupantUserId", player.UserId)
 pad.EntryLabel.Enabled = false
 player:SetAttribute("BattingActive", true)
 -- Face the tee: the right-handed batter's left side points downfield.
 local height = humanoid.HipHeight + root.Size.Y / 2
 local position = Vector3.new(pad.Position.X, pad.Position.Y + pad.Size.Y / 2 + height, pad.Position.Z)
 local teePosition = area.Tee.Stem.Position
 state.battingFrame = CFrame.lookAt(position, Vector3.new(teePosition.X, position.Y, teePosition.Z))
 root.AssemblyLinearVelocity = Vector3.zero
 root.AssemblyAngularVelocity = Vector3.zero
 root.CFrame = state.battingFrame
 root.Anchored = true
 humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 0, 0, 0
 humanoid.AutoRotate = false
 tool.Enabled = true
 humanoid:EquipTool(tool)
end

local function addPlayer(player)
 player:SetAttribute("CurrentWorldId", Worlds.StartingWorldId)
 player:SetAttribute("SessionBestDistanceStuds", 0)
 player:SetAttribute("SessionFarthestSectionId", "")
 player:SetAttribute("SessionFarthestWorldId", "")
 states[player] = {session = 0, swingId = 0, nextSwingTime = 0, lastRequest = 0, lastTravel = -math.huge}
 player:SetAttribute("BattingActive", false)
 player.CharacterRemoving:Connect(function()
  leave(player)
  BallLauncher.CancelPlayer(player)
 end)
 local function characterAdded(character)
  local state = states[player]
  if not state then return end
  state.mustLeavePad = false
  local humanoid = character:WaitForChild("Humanoid", 10)
  local root = character:WaitForChild("HumanoidRootPart", 10)
  if player.Character ~= character or not humanoid or not root then return end
  humanoid.Died:Connect(function()
   leave(player)
   BallLauncher.CancelPlayer(player)
  end)
  -- A new character ends any portal trip or finale in progress (it respawns where it is).
  state.journey = nil
  player:SetAttribute("PortalJourney", nil)
  player:SetAttribute("GameFinale", nil)
  player:SetAttribute("WorldTraveling", false)
  local world = Worlds.Get(player:GetAttribute("CurrentWorldId")) or Worlds.Get(Worlds.StartingWorldId)
  character:PivotTo(world.arrival)
 end
 player.CharacterAdded:Connect(characterAdded)
 if player.Character then task.spawn(characterAdded, player.Character) end
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
 leave(player)
 BallLauncher.CancelPlayer(player)
 states[player] = nil
end)
for _, player in Players:GetPlayers() do addPlayer(player) end

local function livingCharacter(player)
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not humanoid or humanoid.Health <= 0 or not root then return nil end
 return character, root
end

-- Moves an already-validated player to a location in a world, first ending batting,
-- Training, and any active hit (shared by World Travel and the Training and tee teleports).
local function relocate(player, state, character, root, world, destination)
 state.lastTravel = os.clock()
 -- Any travel ends a portal trip or finale in progress, which holds the character in place.
 if state.journey then
  player:SetAttribute(state.journey.attribute, nil)
  state.journey = nil
  root.Anchored = false
 end
 player:SetAttribute("WorldTraveling", true)
 Training.Stop(player)
 leave(player)
 BallLauncher.CancelPlayer(player)
 state.session += 1
 state.nextSwingTime, state.mustLeavePad = 0, false
 player:SetAttribute("BatNextSwingTime", 0)
 player:SetAttribute("CurrentWorldId", world.id)
 root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
 character:PivotTo(destination)
 player:SetAttribute("WorldTraveling", false)
end

-- Holds a batter whose ball went through a World's end portal while their client plays a
-- cinematic: ends batting, anchors the character, keeps the giant portal streamed in on that
-- client, and sets `attribute` to `value` (PortalJourneyClient plays the matching cinematic;
-- WorldTraveling keeps menus and the HUD out of the way). After `seconds` the character is
-- relocated to `destination` in `destinationWorld`, unless the hold was ended or the player is
-- no longer eligible (`stillEligible`).
local function holdForCinematic(player, world, attribute, value, seconds, destinationWorld, stillEligible)
 local state = states[player]
 local character, root = livingCharacter(player)
 if not state or not character or state.journey or player:GetAttribute("CurrentWorldId") ~= world.id then return end
 Training.Stop(player)
 leave(player)
 local journey = {attribute = attribute}
 state.journey = journey
 root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
 root.Anchored = true
 local field = workspace:FindFirstChild(world.fieldName)
 local vortex = field and field:FindFirstChild("PortalVortex", true)
 if vortex then
  player:AddReplicationFocus(vortex)
  journey.focus = vortex
 end
 player:SetAttribute("WorldTraveling", true)
 player:SetAttribute(attribute, value)
 task.delay(seconds, function()
  if journey.focus and player.Parent == Players then player:RemoveReplicationFocus(journey.focus) end
  if state.journey ~= journey or states[player] ~= state then return end
  local currentCharacter, currentRoot = livingCharacter(player)
  if currentCharacter ~= character or not PlayerData.IsReady(player) or not stillEligible() then
   state.journey = nil
   root.Anchored = false
   player:SetAttribute(attribute, nil)
   player:SetAttribute("WorldTraveling", false)
   return
  end
  -- (No "Arrived" notice: the cinematic's closing title says it.)
  relocate(player, state, currentCharacter, currentRoot, destinationWorld, destinationWorld.arrival)
 end)
end

-- The batter's ball went through a World's end portal and opened the next World: they are
-- pulled through it (PortalJourney names the destination), then travel there.
BallLauncher.OnPortalJourney = function(player, world, nextWorld)
 holdForCinematic(player, world, "PortalJourney", nextWorld.id, PORTAL_JOURNEY_SECONDS, nextWorld, function()
  return player:GetAttribute("WorldUnlocked_" .. nextWorld.id) == true
 end)
end

-- The ball went through the last World's end portal: the temporary finale (GameFinale names
-- the World), then back to that World's hub.
BallLauncher.OnGameFinale = function(player, world)
 holdForCinematic(player, world, "GameFinale", world.id, GAME_FINALE_SECONDS, world, function()
  return player:GetAttribute("CurrentWorldId") == world.id
 end)
end

Travel.OnServerEvent:Connect(function(player, destinationId)
 local state = states[player]
 if not state or not PlayerData.IsReady(player) or type(destinationId) ~= "string" then return end
 local world = Worlds.Get(destinationId)
 if not world or player:GetAttribute("WorldUnlocked_" .. world.id) ~= true then
  Travel:FireClient(player, "That world is locked.")
  return
 end
 if os.clock() - state.lastTravel < 1 then return end
 local character, root = livingCharacter(player)
 if not character then return end
 relocate(player, state, character, root, world, world.arrival)
 Travel:FireClient(player, "Arrived in " .. world.displayName)
end)

-- Where a ground's Training teleport goes: the player's current World when the ground stands
-- there, otherwise the first unlocked World it stands in (CanUseTrainingGround has already
-- checked that one exists).
local function trainingWorld(player, ground)
 local current = player:GetAttribute("CurrentWorldId")
 if table.find(ground.worlds, current) then return Worlds.Get(current) end
 for _, worldId in ground.worlds do
  if player:GetAttribute("WorldUnlocked_" .. worldId) == true then return Worlds.Get(worldId) end
 end
 return nil
end

-- Training teleport: the client may name a ground; otherwise (or if that ground is not
-- usable) the server picks the player's best ground in any unlocked World. It lands beside
-- that plate, not on it, so Training never starts by itself, and travels to that ground's
-- World if needed.
TrainingTeleport.OnServerEvent:Connect(function(player, ...)
 local state = states[player]
 local requested = ...
 if select("#", ...) > 1 or (requested ~= nil and (type(requested) ~= "string" or #requested > 64))
  or not state or not PlayerData.IsReady(player) then return end
 if os.clock() - state.lastTravel < 1 then return end
 if player:GetAttribute("HitActive") then
  TrainingTeleport:FireClient(player, "Wait for your hit to finish first.", false)
  return
 end
 if player:GetAttribute("TrainingActive") then
  TrainingTeleport:FireClient(player, "You are already training.", false)
  return
 end
 local character, root = livingCharacter(player)
 if not character then return end
 local ground = requested and PlayerData.CanUseTrainingGround(player, requested) or PlayerData.GetBestTrainingGround(player)
 local world = ground and trainingWorld(player, ground)
 local hub = world and world.hub and workspace:FindFirstChild(world.hub.name)
 local stadium = ground and hub and hub:FindFirstChild("TrainingGrounds") and hub.TrainingGrounds:FindFirstChild(ground.id)
 local plate = stadium and stadium:FindFirstChild("TrainingPlate")
 if not plate then return end
 local standAt = (plate.CFrame * CFrame.new(TRAINING_TELEPORT_OFFSET)).Position + Vector3.new(0, 3.5, 0)
 relocate(player, state, character, root, world, CFrame.lookAt(standAt, Vector3.new(plate.Position.X, standAt.Y, plate.Position.Z)))
 TrainingTeleport:FireClient(player, "Teleported to " .. ground.displayName .. ". Step onto the plate to train!", true)
end)

-- Tee teleport: intent only, no arguments. Lands just behind the batter's box of the
-- player's current world.
TeeTeleport.OnServerEvent:Connect(function(player, ...)
 local state = states[player]
 if select("#", ...) ~= 0 or not state or not PlayerData.IsReady(player) then return end
 if os.clock() - state.lastTravel < 1 then return end
 if player:GetAttribute("HitActive") then
  TeeTeleport:FireClient(player, "Wait for your hit to finish first.", false)
  return
 end
 if player:GetAttribute("BattingActive") then
  TeeTeleport:FireClient(player, "You are already at the tee.", false)
  return
 end
 local character, root = livingCharacter(player)
 if not character then return end
 local world = Worlds.Get(player:GetAttribute("CurrentWorldId")) or Worlds.Get(Worlds.StartingWorldId)
 local area = workspace:FindFirstChild(world.stationName)
 local pad, direction = area and area:FindFirstChild("BatterPosition"), area and area:FindFirstChild("HitDirection")
 if not pad or not direction then return end
 local difference = direction.Position - area.Tee.Stem.Position
 local forward = Vector3.new(difference.X, 0, difference.Z).Unit
 local standAt = pad.Position - forward * TEE_TELEPORT_BACK + Vector3.new(0, 3.5, 0)
 relocate(player, state, character, root, world, CFrame.lookAt(standAt, Vector3.new(pad.Position.X, standAt.Y, pad.Position.Z)))
 TeeTeleport:FireClient(player, "Teleported to the tee. Step into the batter's box to bat!", true)
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(delta)
 elapsed += delta
 if elapsed < CHECK_INTERVAL then return end
 elapsed = 0
 for player, state in states do
  local character = player.Character
  local humanoid = character and character:FindFirstChildOfClass("Humanoid")
  local root = character and character:FindFirstChild("HumanoidRootPart")
  local valid = character and character.Parent and humanoid and humanoid.Health > 0 and root
  local world = Worlds.Get(player:GetAttribute("CurrentWorldId"))
  local area = world and workspace:FindFirstChild(world.stationName)
  local pad = area and area:FindFirstChild("BatterPosition")
  if state.worldId and occupants[state.worldId] == player then
   if not PlayerData.IsReady(player) or not valid or not world or world.id ~= state.worldId or root ~= state.root or state.tool.Parent ~= character then
    leave(player)
   else
    root.CFrame = state.battingFrame
   end
  elseif valid and pad then
   if not insidePad(root, pad) then state.mustLeavePad = false end
   if not occupants[world.id] and not state.mustLeavePad and insidePad(root, pad) then
    enter(player, character, humanoid, root)
   end
  end
 end
end)

Remote.OnServerEvent:Connect(function(player, session, action)
 local state = states[player]
 if not state or not state.worldId or occupants[state.worldId] ~= player or session ~= state.session then return end
 if action == "Exit" then leave(player) return end
 if action == "SpeedUp" then BallLauncher.SpeedUp(player, session) return end
 if action ~= nil or not PlayerData.IsReady(player) or BallLauncher.IsBusy(state.worldId) then return end
 local now = workspace:GetServerTimeNow()
 if now - state.lastRequest < 0.05 then return end
 state.lastRequest = now
 local tool = state.tool
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not tool or tool.Parent ~= character or not tool.Enabled then return end
 if not humanoid or humanoid.Health <= 0 or root ~= state.root then return end
 if (root.Position - state.battingFrame.Position).Magnitude > 1 then return end
 if now < state.nextSwingTime then return end

	local progression = PlayerData.GetProgression(player)
 if not progression then return end
 -- In Studio only, the Workspace attribute StudioLaunchLevel launches hits as that Level
 -- (e.g. to reach a World's end portal); the saved Level is untouched. Live servers ignore it.
 local studioLevel = RunService:IsStudio() and workspace:GetAttribute("StudioLaunchLevel")
 local launchLevel = type(studioLevel) == "number" and math.floor(studioLevel) >= 1 and math.floor(studioLevel) or progression.Level
	state.nextSwingTime = now + Swing.Duration
	player:SetAttribute("BatNextSwingTime", state.nextSwingTime)
	state.swingId += 1
	-- Snapshot the server's Level, Bat ID, and Ball reward effect at swing acceptance.
	local result = {
		swingId = state.swingId,
  worldId = state.worldId,
		session = state.session,
  launchLevel = launchLevel,
  batId = player:GetAttribute("EquippedBat"),
  ballRewardMultiplier = Equipment.Get("Ball", player:GetAttribute("EquippedBall")).rewardMultiplier,
		evaluatedAt = now,
	}
	result.contact = BallLauncher.TryLaunch(player, result, tool)
	state.lastResult = result
	player:SetAttribute("LastBatSwingId", result.swingId)
end)
