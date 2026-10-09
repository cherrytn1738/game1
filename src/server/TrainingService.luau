local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Data = require(script.Parent.PlayerData)
local Worlds = require(game.ReplicatedStorage.WorldConfig)
local Service = {}
local active, plate, remote
local mustLeave, requests = {}, {}
local sessionId = 0
local started = false

function Service.Stop(player)
 local state = active
 if not state or state.player ~= player then return end
 active = nil
 mustLeave[player] = true
 player:SetAttribute("TrainingActive", false)
 player:SetAttribute("TrainingSession", nil)
 player:SetAttribute("TrainingStartedAt", nil)
 plate:SetAttribute("OccupantUserId", nil)
 if state.root.Parent then state.root.Anchored = state.saved.anchored end
 if state.humanoid.Parent then
  state.humanoid.WalkSpeed, state.humanoid.JumpPower, state.humanoid.JumpHeight =
   state.saved.walkSpeed, state.saved.jumpPower, state.saved.jumpHeight
  state.humanoid.AutoRotate = state.saved.autoRotate
  state.humanoid:UnequipTools()
 end
end

local function inside(root)
 local position = plate.CFrame:PointToObjectSpace(root.Position)
 return math.abs(position.X) <= plate.Size.X/2 and math.abs(position.Z) <= plate.Size.Z/2
  and position.Y >= 0 and position.Y <= 6
end

local function characterState(player)
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not Data.IsReady(player) or player:GetAttribute("CurrentWorldId") ~= Worlds.StartingWorldId
  or player:GetAttribute("BattingActive") or player:GetAttribute("HitActive")
  or not humanoid or humanoid.Health <= 0 or not root or not character.Parent then return nil end
 return character, humanoid, root
end

local function enter(player, character, humanoid, root)
 local ground = Data.GetTrainingGround(player)
 local backpack = player:FindFirstChildOfClass("Backpack")
 local tool = character:FindFirstChild("Bat") or backpack and backpack:FindFirstChild("Bat")
 if not ground or not tool or not tool:IsA("Tool") or humanoid.Sit then return end
 sessionId += 1
 local height = humanoid.HipHeight + root.Size.Y/2
 local frame = plate.CFrame * CFrame.new(0,plate.Size.Y/2+height,0) * CFrame.Angles(0,-math.pi/2,0)
 active = {player=player, character=character, humanoid=humanoid, root=root, tool=tool,
  ground=ground, frame=frame, nextTick=os.clock()+ground.interval,
  saved={anchored=root.Anchored,walkSpeed=humanoid.WalkSpeed,jumpPower=humanoid.JumpPower,
   jumpHeight=humanoid.JumpHeight,autoRotate=humanoid.AutoRotate}}
 root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
 root.CFrame, root.Anchored = frame, true
 humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight, humanoid.AutoRotate = 0,0,0,false
 plate:SetAttribute("OccupantUserId", player.UserId)
 player:SetAttribute("TrainingSession",sessionId)
 player:SetAttribute("TrainingStartedAt",workspace:GetServerTimeNow())
 player:SetAttribute("TrainingActive",true)
 humanoid:EquipTool(tool)
end

function Service.Start()
 if started then return end
 started = true
 local fieldServer = script.Parent:WaitForChild("FieldServer")
 while not fieldServer:GetAttribute("FieldsReady") do fieldServer:GetAttributeChangedSignal("FieldsReady"):Wait() end
 plate = workspace[Worlds.Get(Worlds.StartingWorldId).hub.name].TrainingStadium.TrainingPlate
 remote = game.ReplicatedStorage:FindFirstChild("TrainingRequest") or Instance.new("RemoteEvent")
 remote.Name, remote.Parent = "TrainingRequest", game.ReplicatedStorage
 remote.OnServerEvent:Connect(function(player, action, value)
  if action == "Exit" then
   if active and active.player == player and value == player:GetAttribute("TrainingSession") then Service.Stop(player) end
   return
  end
  if action ~= "Select" or type(value) ~= "string" or #value > 64 then return end
  local now = os.clock()
  if requests[player] and now-requests[player] < .25 then return end
  requests[player] = now
  local ok, message = Data.SelectTrainingGround(player,value)
  remote:FireClient(player,ok,message)
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
 Players.PlayerRemoving:Connect(function(player) Service.Stop(player) mustLeave[player],requests[player]=nil,nil end)
 for _, player in Players:GetPlayers() do watch(player) end
 local elapsed = 0
 RunService.Heartbeat:Connect(function(dt)
  elapsed += dt
  if elapsed < .1 then return end
  elapsed = 0
  if active then
   local state = active
   local character, humanoid, root = characterState(state.player)
   if character ~= state.character or root ~= state.root or state.tool.Parent ~= character
    or (root.Position-state.frame.Position).Magnitude > 1 or Data.GetTrainingGround(state.player) ~= state.ground then
    Service.Stop(state.player)
   else
    local progression = Data.GetProgression(state.player)
    if os.clock() >= state.nextTick then
     state.nextTick = os.clock() + state.ground.interval -- No burst/catch-up rewards after stalls.
     if progression.Level < progression.LevelCap then Data.GrantPower(state.player,state.ground.basePower,"ActiveTraining") end
    end
   end
  end
  for _, player in Players:GetPlayers() do
   local character, humanoid, root = characterState(player)
   if root then
    if not inside(root) then mustLeave[player]=nil end
    if not active and not mustLeave[player] and not player:GetAttribute("TrainingActive") and inside(root) then
     enter(player,character,humanoid,root)
    end
   end
  end
 end)
end

return Service
