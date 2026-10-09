local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progression = require(ReplicatedStorage:WaitForChild("ProgressionConfig"))
-- Legacy Rojo/Remote name retained; requests now contain only session and optional Exit.
local Remote = ReplicatedStorage:WaitForChild("BattingTiming")
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local BallLauncher = require(script.Parent:WaitForChild("BallLauncher"))

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Training = require(script.Parent:WaitForChild("TrainingService"))

local CHECK_INTERVAL = 0.1
local ENTRY_HEIGHT = 6
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Travel = ReplicatedStorage:WaitForChild("WorldTravel")
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

Travel.OnServerEvent:Connect(function(player, destinationId)
 local state = states[player]
 if not state or not PlayerData.IsReady(player) or type(destinationId) ~= "string" then return end
 local world = Worlds.Get(destinationId)
 if not world or player:GetAttribute("WorldUnlocked_" .. world.id) ~= true then
  Travel:FireClient(player, "That world is locked.")
  return
 end
 if os.clock() - state.lastTravel < 1 then return end
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not humanoid or humanoid.Health <= 0 or not root then return end
 state.lastTravel = os.clock()
 Training.Stop(player)
 leave(player)
 BallLauncher.CancelPlayer(player)
 state.session += 1
 state.nextSwingTime, state.mustLeavePad = 0, false
 player:SetAttribute("BatNextSwingTime", 0)
 player:SetAttribute("CurrentWorldId", world.id)
 root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
 character:PivotTo(world.arrival)
 Travel:FireClient(player, "Arrived in " .. world.displayName)
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
	state.nextSwingTime = now + Progression.SwingCooldown
	player:SetAttribute("BatNextSwingTime", state.nextSwingTime)
	state.swingId += 1
	-- Snapshot the server's Level and Ball reward effect at swing acceptance.
	local result = {
		swingId = state.swingId,
  worldId = state.worldId,
		session = state.session,
  launchLevel = progression.Level,
  ballRewardMultiplier = Equipment.Get("Ball", player:GetAttribute("EquippedBall")).rewardMultiplier,
		evaluatedAt = now,
	}
	result.contact = BallLauncher.TryLaunch(player, result, tool)
	state.lastResult = result
	player:SetAttribute("LastBatSwingId", result.swingId)
end)
