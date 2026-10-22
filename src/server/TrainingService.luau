local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Marketplace = game:GetService("MarketplaceService")
local Data = require(script.Parent.PlayerData)
local Worlds = require(game.ReplicatedStorage.WorldConfig)
local Training = require(game.ReplicatedStorage.TrainingConfig)
local Service = {}
-- Every World hub has its own row of grounds (Dragon's Lair stands in each), so a station is
-- one plate in one hub: {ground, plate, worldId}. Each plate has at most one occupant.
local stations, occupants, active, remote = {}, {}, {}, nil
local mustLeave, requests, lockedNotices = {}, {}, {}
local sessionId = 0
local started = false
local LOCKED_NOTICE_SECONDS = 4

function Service.Stop(player)
 local state = active[player]
 if not state then return end
 active[player] = nil
 if occupants[state.plate] == player then occupants[state.plate] = nil end
 mustLeave[player] = true
 player:SetAttribute("TrainingActive", false)
 player:SetAttribute("TrainingGround", nil)
 player:SetAttribute("TrainingSession", nil)
 player:SetAttribute("TrainingStartedAt", nil)
 state.plate:SetAttribute("OccupantUserId", nil)
 if state.root.Parent then state.root.Anchored = state.saved.anchored end
 if state.humanoid.Parent then
  state.humanoid.WalkSpeed, state.humanoid.JumpPower, state.humanoid.JumpHeight =
   state.saved.walkSpeed, state.saved.jumpPower, state.saved.jumpHeight
  state.humanoid.AutoRotate = state.saved.autoRotate
  state.humanoid:UnequipTools()
 end
end

local function inside(plate, root)
 local position = plate.CFrame:PointToObjectSpace(root.Position)
 return math.abs(position.X) <= plate.Size.X/2 and math.abs(position.Z) <= plate.Size.Z/2
  and position.Y >= 0 and position.Y <= 6
end

-- Only plates in the player's current World count.
local function plateUnder(root, worldId)
 for _, station in stations do
  if station.worldId == worldId and inside(station.plate, root) then return station.ground, station.plate end
 end
 return nil
end

local function characterState(player)
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not Data.IsReady(player) or not Worlds.Get(player:GetAttribute("CurrentWorldId"))
  or player:GetAttribute("BattingActive") or player:GetAttribute("HitActive")
  or not humanoid or humanoid.Health <= 0 or not root or not character.Parent then return nil end
 return character, humanoid, root
end

-- Standing on a ground you cannot use explains why (and offers the pass for paid grounds)
-- at most once per visit, then waits until the player steps off.
local function refuse(player, ground, message)
 mustLeave[player] = true
 local now = os.clock()
 if lockedNotices[player] and now - lockedNotices[player] < LOCKED_NOTICE_SECONDS then return end
 lockedNotices[player] = now
 remote:FireClient(player, false, message)
 local pass = Training.IsPaid(ground) and Training.GetPassGround(ground)
 if pass and pass.gamePassId > 0 then
  task.spawn(function()
   Data.RefreshTrainingPasses(player)
   if not Data.OwnsTrainingPass(player, pass.id) and player.Parent == Players then
    Marketplace:PromptGamePassPurchase(player, pass.gamePassId)
   end
  end)
 end
end

local function enter(player, ground, plate, character, humanoid, root)
 local backpack = player:FindFirstChildOfClass("Backpack")
 local tool = character:FindFirstChild("Bat") or backpack and backpack:FindFirstChild("Bat")
 if not tool or not tool:IsA("Tool") or humanoid.Sit then return end
 sessionId += 1
 local height = humanoid.HipHeight + root.Size.Y/2
 local frame = plate.CFrame * CFrame.new(0,plate.Size.Y/2+height,0) * CFrame.Angles(0,-math.pi/2,0)
 active[player] = {player=player, character=character, humanoid=humanoid, root=root, tool=tool,
  ground=ground, plate=plate, frame=frame, nextTick=os.clock()+ground.interval,
  saved={anchored=root.Anchored,walkSpeed=humanoid.WalkSpeed,jumpPower=humanoid.JumpPower,
   jumpHeight=humanoid.JumpHeight,autoRotate=humanoid.AutoRotate}}
 occupants[plate] = player
 root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
 root.CFrame, root.Anchored = frame, true
 humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight, humanoid.AutoRotate = 0,0,0,false
 plate:SetAttribute("OccupantUserId", player.UserId)
 player:SetAttribute("TrainingGround", ground.id)
 player:SetAttribute("TrainingSession",sessionId)
 player:SetAttribute("TrainingStartedAt",workspace:GetServerTimeNow())
 player:SetAttribute("TrainingActive",true)
 humanoid:EquipTool(tool)
end

-- Paid grounds: the client may only ask for the purchase prompt; ownership is checked here.
local function requestPurchase(player, id)
 local ground = type(id) == "string" and Training.Get(id)
 if not ground or not Training.IsPaid(ground) or not Data.IsReady(player) then return end
 local pass = Training.GetPassGround(ground)
 if pass.gamePassId <= 0 then
  remote:FireClient(player, false, ground.displayName .. " is not on sale yet.")
 elseif Data.OwnsTrainingPass(player, pass.id) then
  remote:FireClient(player, false, "You already own the " .. pass.displayName .. " pass.")
 else
  Marketplace:PromptGamePassPurchase(player, pass.gamePassId)
 end
end

function Service.Start()
 if started then return end
 started = true
 local fieldServer = script.Parent:WaitForChild("FieldServer")
 while not fieldServer:GetAttribute("FieldsReady") do fieldServer:GetAttributeChangedSignal("FieldsReady"):Wait() end
 for _, hub in Training.Hubs do
  local grounds = workspace[Worlds.Get(hub.world).hub.name].TrainingGrounds
  for _, id in hub.grounds do
   table.insert(stations, {ground = Training.Get(id), plate = grounds[id].TrainingPlate, worldId = hub.world})
  end
 end
 remote = game.ReplicatedStorage:FindFirstChild("TrainingRequest") or Instance.new("RemoteEvent")
 remote.Name, remote.Parent = "TrainingRequest", game.ReplicatedStorage
 remote.OnServerEvent:Connect(function(player, action, value)
  if action == "Exit" then
   if active[player] and value == player:GetAttribute("TrainingSession") then Service.Stop(player) end
   return
  end
  if action ~= "Buy" or type(value) ~= "string" or #value > 64 then return end
  local now = os.clock()
  if requests[player] and now-requests[player] < 1 then return end
  requests[player] = now
  requestPurchase(player, value)
 end)
 local function watch(player)
  player:SetAttribute("TrainingActive",false)
  player.CharacterRemoving:Connect(function() Service.Stop(player) mustLeave[player]=nil end)
  player:GetAttributeChangedSignal("CurrentWorldId"):Connect(function() Service.Stop(player) end)
  player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
   if not player:GetAttribute("DataLoaded") then Service.Stop(player) end
  end)
 end
 Players.PlayerAdded:Connect(watch)
 Players.PlayerRemoving:Connect(function(player)
  Service.Stop(player)
  mustLeave[player], requests[player], lockedNotices[player] = nil, nil, nil
 end)
 for _, player in Players:GetPlayers() do watch(player) end
 local elapsed = 0
 RunService.Heartbeat:Connect(function(dt)
  elapsed += dt
  if elapsed < .1 then return end
  elapsed = 0
  for player, state in active do
   local character, _, root = characterState(player)
   if character ~= state.character or root ~= state.root or state.tool.Parent ~= character
    or (root.Position-state.frame.Position).Magnitude > 1 or not Data.CanUseTrainingGround(player, state.ground.id) then
    Service.Stop(player)
   elseif os.clock() >= state.nextTick then
    state.nextTick = os.clock() + state.ground.interval -- No burst/catch-up rewards after stalls.
    local progression = Data.GetProgression(player)
    if progression.Level < progression.LevelCap then
     local granted, result = Data.GrantPower(player,state.ground.basePower,"ActiveTraining")
     -- Display copies for the client's "+Power" popup; the tick count makes repeats visible.
     if granted and result.powerGranted > 0 then
      player:SetAttribute("TrainingPowerGained", result.powerGranted)
      player:SetAttribute("TrainingPowerTick", (player:GetAttribute("TrainingPowerTick") or 0) + 1)
     end
    end
   end
  end
  for _, player in Players:GetPlayers() do
   local character, humanoid, root = characterState(player)
   if root and not active[player] then
    local ground, plate = plateUnder(root, player:GetAttribute("CurrentWorldId"))
    if not ground then
     mustLeave[player] = nil
    elseif not mustLeave[player] and not player:GetAttribute("TrainingActive") and not occupants[plate] then
     local usable, reason = Data.CanUseTrainingGround(player, ground.id)
     if usable then enter(player, ground, plate, character, humanoid, root) else refuse(player, ground, reason) end
    end
   end
  end
 end)
end

return Service
