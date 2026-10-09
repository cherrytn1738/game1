local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Actions = game:GetService("ContextActionService")
local Storage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Config = require(Storage:WaitForChild("TrainingConfig"))
local Progression = require(Storage:WaitForChild("ProgressionConfig"))
local Worlds = require(Storage:WaitForChild("WorldConfig"))
local Remote = Storage:WaitForChild("TrainingRequest")
local UI = require(script.Parent.UICommon)
local Interfaces = require(script.Parent.HubInterfaces)

local gui, panel, show = UI.Menu("TrainingGroundGui","Training Grounds","Select a ground, then step onto the training plate.",Interfaces.CloseAll)
local list = UI.Scroll(panel,"Grounds")
list.Position, list.Size = UDim2.fromOffset(14,92), UDim2.new(1,-28,1,-110)
local rows = {}
for index, ground in Config.Grounds do
 local row = UI.Surface(list,ground.id)
 row.Size, row.LayoutOrder = UDim2.new(1,-10,0,136), index
 local name = UI.Label(row,"Name",ground.displayName,18)
 name.Position, name.Size = UDim2.fromOffset(12,8), UDim2.new(1,-24,0,24)
 local rate = UI.Label(row,"Rate","",14,UI.Colors.Muted)
 rate.Position, rate.Size = UDim2.fromOffset(12,35), UDim2.new(1,-24,0,22)
 local status = UI.Label(row,"Status","",14,UI.Colors.Muted)
 status.Position, status.Size = UDim2.fromOffset(12,59), UDim2.new(1,-24,0,22)
 local button = UI.Button(row,"Select","SELECT")
 button.Position, button.Size = UDim2.fromOffset(12,86), UDim2.new(1,-24,0,38)
 button.Activated:Connect(function() Remote:FireServer("Select",ground.id) end)
 rows[ground.id] = {rate=rate,status=status,button=button}
end
Interfaces.Register("Training",show)
Remote.OnClientEvent:Connect(function(ok,message) UI.Notify(message,ok and "success" or "error") end)

local hud = UI.Screen("TrainingHUD",12)
local box = UI.Surface(hud,"Status")
box.AnchorPoint, box.Position, box.Size = Vector2.new(.5,1), UDim2.new(.5,0,1,-18), UDim2.new(1,-24,0,104)
local limit = Instance.new("UISizeConstraint",box)
limit.MaxSize = Vector2.new(360,104)
local heading = UI.Label(box,"Heading","TRAINING",16,UI.Colors.Accent)
heading.Position, heading.Size = UDim2.fromOffset(12,8), UDim2.new(1,-24,0,22)
local detail = UI.Label(box,"Detail","",14)
detail.Position, detail.Size, detail.TextWrapped = UDim2.fromOffset(12,34), UDim2.new(1,-24,0,36), true
local exit = UI.Label(box,"Exit","Space / Leave to stop",13,UI.Colors.Muted)
exit.Position, exit.Size = UDim2.fromOffset(12,76), UDim2.new(1,-24,0,20)

local visual, rendering, leaveBound
local function stopPresentation()
 if rendering then rendering:Disconnect() rendering=nil end
 if visual then visual:Destroy() visual=nil end
 if leaveBound then Actions:UnbindAction("ExitTraining") leaveBound=false end
 hud.Enabled = false
end
local function leave(_,state)
 if state == Enum.UserInputState.Begin then Remote:FireServer("Exit",Player:GetAttribute("TrainingSession")) end
 return Enum.ContextActionResult.Sink
end
local function startPresentation()
 if rendering then return end
 if not leaveBound then
  Actions:BindActionAtPriority("ExitTraining",leave,true,3000,Enum.KeyCode.Space)
  Actions:SetTitle("ExitTraining","Leave")
  Actions:SetPosition("ExitTraining",UDim2.new(1,-90,1,-180))
  leaveBound = true
 end
 local hub = workspace:FindFirstChild(Worlds.Get(Worlds.StartingWorldId).hub.name)
 local stadium = hub and hub:FindFirstChild("TrainingStadium")
 local plate = stadium and stadium:FindFirstChild("TrainingPlate")
 if not plate then return end
 visual = Instance.new("Part")
 visual.Name, visual.Shape, visual.Size = "TrainingPracticeBall", Enum.PartType.Ball, Vector3.new(.65,.65,.65)
 visual.Anchored, visual.CanCollide, visual.CanTouch, visual.CanQuery = true,false,false,false
 visual.Color, visual.Parent = Color3.new(1,1,1), workspace
 local lastCycle = -1
 rendering = RunService.RenderStepped:Connect(function()
  if not plate.Parent then stopPresentation() return end
  local elapsed = math.max(0,workspace:GetServerTimeNow()-(Player:GetAttribute("TrainingStartedAt") or workspace:GetServerTimeNow()))
  local cycle, phase = math.floor(elapsed/Config.PracticeCycleSeconds), elapsed%Config.PracticeCycleSeconds
  visual.Transparency = phase > Config.PracticePitchSeconds+.15 and 1 or 0
  visual.Position = plate.PitchOrigin.WorldPosition:Lerp(plate.ContactPosition.WorldPosition,math.clamp(phase/Config.PracticePitchSeconds,0,1))
  if cycle ~= lastCycle and phase >= Config.PracticePitchSeconds-Config.SwingLeadSeconds then
   lastCycle = cycle
   local tool = Player.Character and Player.Character:FindFirstChild("Bat")
   local swing = tool and tool:FindFirstChild("PracticeSwing")
   if swing then swing:Fire() end
  end
 end)
end

local function refresh()
 local rebirths = Player:GetAttribute("Rebirths") or 0
 for _, ground in Config.Grounds do
  local row = rows[ground.id]
  local unlocked = Config.IsUnlocked(ground.id,rebirths)
  local selected = ground.id == Player:GetAttribute("SelectedTrainingGround")
  row.rate.Text = UI.Number(ground.basePower/ground.interval * Progression.GetPowerMultiplier(rebirths)) .. " Power / second"
  row.status.Text = unlocked and (selected and "Currently selected" or "Unlocked") or "Requires " .. ground.requiredRebirths .. " Rebirths"
  UI.SetButton(row.button,selected and "SELECTED" or unlocked and "SELECT" or "LOCKED",unlocked and not selected,selected)
 end
 local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
 local active = Player:GetAttribute("DataLoaded") and Player:GetAttribute("TrainingActive") and humanoid and humanoid.Health>0
 hud.Enabled = active == true
 if not active then stopPresentation() return end
 local ground = Config.Get(Player:GetAttribute("SelectedTrainingGround"))
 local capped = Player:GetAttribute("Level") >= Player:GetAttribute("LevelCap")
 detail.Text = ground.displayName .. "\n" .. (capped and "Level cap reached - Power gains paused"
  or UI.Number(ground.basePower/ground.interval*Progression.GetPowerMultiplier(rebirths)) .. " Power / second")
 startPresentation()
end
for _, name in {"DataLoaded","TrainingActive","SelectedTrainingGround","Rebirths","Level","LevelCap","Power"} do
 Player:GetAttributeChangedSignal(name):Connect(refresh)
end
Player.CharacterRemoving:Connect(stopPresentation)
Player.CharacterAdded:Connect(function(character)
 local humanoid=character:WaitForChild("Humanoid",10)
 if humanoid then humanoid.Died:Connect(stopPresentation) end
 refresh()
end)

-- No claim request exists. This display runs once for this player session, not per respawn.
local offlineShown = false
local function offlineNotice()
 if offlineShown or not Player:GetAttribute("DataLoaded") then return end
 offlineShown=true
 local amount, seconds = Player:GetAttribute("OfflinePowerEarned") or 0, Player:GetAttribute("OfflineSeconds") or 0
 if amount <= 0 or seconds < Config.OfflineNoticeMinimumSeconds then return end
 task.delay(1,function()
  UI.Notify(string.format("OFFLINE TRAINING\n+%s Power - %dh %dm",UI.Number(amount),math.floor(seconds/3600),math.floor(seconds%3600/60)),"success")
 end)
end
Player:GetAttributeChangedSignal("DataLoaded"):Connect(offlineNotice)
offlineNotice()
refresh()
