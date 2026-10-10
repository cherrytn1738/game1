local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Actions = game:GetService("ContextActionService")
local Storage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Config = require(Storage:WaitForChild("TrainingConfig"))
local Progression = require(Storage:WaitForChild("ProgressionConfig"))
local Swing = require(Storage:WaitForChild("SwingConfig"))
local Worlds = require(Storage:WaitForChild("WorldConfig"))
local Remote = Storage:WaitForChild("TrainingRequest")
local UI = require(script.Parent.UICommon)
local Interfaces = require(script.Parent.HubInterfaces)

local gui, panel, show = UI.Menu("TrainingGroundGui","Training Grounds","Train → gain Power → Level Up → hit farther.",Interfaces.CloseAll)
local list = UI.Scroll(panel,"Grounds")
list.Position, list.Size = UDim2.fromOffset(14,92), UDim2.new(1,-28,1,-148)
local offlineDetail = UI.Label(panel,"OfflineInfo","Select a ground, then use the training plate.\nOffline: "
 .. UI.Number(Config.MaximumOfflineSeconds/3600) .. "h maximum at " .. UI.Number(Config.OfflinePowerRateMultiplier*100) .. "% of your Power rate.",13,UI.Colors.Muted)
offlineDetail.Position, offlineDetail.Size, offlineDetail.TextWrapped = UDim2.new(0,16,1,-48),UDim2.new(1,-32,0,40),true
local rows = {}
for index, ground in Config.Grounds do
 local row = UI.Surface(list,ground.id)
 row.Size, row.LayoutOrder = UDim2.new(1,-10,0,140), index
 local name = UI.Label(row,"Name",ground.displayName,18)
 name.Position, name.Size = UDim2.fromOffset(12,8), UDim2.new(1,-24,0,24)
 local rate = UI.Label(row,"Rate","",14,UI.Colors.Muted)
 rate.Position, rate.Size = UDim2.fromOffset(12,35), UDim2.new(1,-24,0,22)
 local status = UI.Label(row,"Status","",14,UI.Colors.Muted)
 status.Position, status.Size = UDim2.fromOffset(12,59), UDim2.new(1,-24,0,22)
 local button = UI.Button(row,"Select","SELECT")
 button.Position, button.Size = UDim2.fromOffset(12,86), UDim2.new(1,-24,0,42)
 button.Activated:Connect(function()
  if button.Active and Interfaces.CanOpen() then Remote:FireServer("Select",ground.id) end
 end)
 rows[ground.id] = {rate=rate,status=status,button=button}
end
Interfaces.Register("Training",show)
Remote.OnClientEvent:Connect(function(ok,message) UI.Notify(message,ok and "success" or "error") end)

local hud = UI.Screen("TrainingHUD",12)
local box = UI.Surface(hud,"Status")
box.AnchorPoint, box.Position, box.Size = Vector2.new(.5,1), UDim2.new(.5,0,1,-18), UDim2.new(1,-24,0,128)
local heading = UI.Label(box,"Heading","TRAINING",16,UI.Colors.Accent)
heading.Position, heading.Size = UDim2.fromOffset(12,8), UDim2.new(1,-24,0,22)
local detail = UI.Label(box,"Detail","",14)
detail.Position, detail.Size, detail.TextWrapped = UDim2.fromOffset(12,34), UDim2.new(1,-24,0,64), true
local exit = UI.Label(box,"Exit","Space / Leave to stop",13,UI.Colors.Muted)
exit.Position, exit.Size = UDim2.fromOffset(12,102), UDim2.new(1,-24,0,20)
local function resizeStatus()
 local size = hud.AbsoluteSize
 if size.Y < 440 and size.X >= 600 then
  box.AnchorPoint, box.Position = Vector2.new(0,1),UDim2.new(0,12,1,-18)
  box.Size = UDim2.fromOffset(math.min(360,size.X-296),128)
 else
  box.AnchorPoint, box.Position = Vector2.new(.5,1),UDim2.new(.5,0,1,-18)
  box.Size = UDim2.fromOffset(math.min(360,size.X-24),128)
 end
end
hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeStatus)
task.defer(resizeStatus)

local visual, rendering, leaveBound
local function stopVisual()
 if rendering then rendering:Disconnect() rendering=nil end
 if visual then visual:Destroy() visual=nil end
end
local function stopPresentation()
 stopVisual()
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
 local pitchOrigin = plate and plate:FindFirstChild("PitchOrigin")
 local contact = plate and plate:FindFirstChild("ContactPosition")
 if not plate or not pitchOrigin or not contact then return end
 visual = Instance.new("Part")
 visual.Name, visual.Shape, visual.Size = "TrainingPracticeBall", Enum.PartType.Ball, Vector3.new(.65,.65,.65)
 visual.Anchored, visual.CanCollide, visual.CanTouch, visual.CanQuery = true,false,false,false
 visual.Color, visual.Parent = Color3.new(1,1,1), workspace
 local lastCycle = -1
 rendering = RunService.RenderStepped:Connect(function()
  if not plate.Parent or not pitchOrigin.Parent or not contact.Parent then stopVisual() return end
  local elapsed = math.max(0,workspace:GetServerTimeNow()-(Player:GetAttribute("TrainingStartedAt") or workspace:GetServerTimeNow()))
  local cycle, phase = math.floor(elapsed/Config.PracticeCycleSeconds), elapsed%Config.PracticeCycleSeconds
  visual.Transparency = phase > Config.PracticePitchSeconds+.15 and 1 or 0
  visual.Position = pitchOrigin.WorldPosition:Lerp(contact.WorldPosition,math.clamp(phase/Config.PracticePitchSeconds,0,1))
  if cycle ~= lastCycle and phase >= Config.PracticePitchSeconds-Swing.ContactTime then
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
  row.status.Text = (unlocked and (selected and "Selected" or "Unlocked") or "Locked")
   .. " | Required Rebirths: " .. UI.Number(ground.requiredRebirths)
  UI.SetButton(row.button,selected and "SELECTED" or unlocked and "SELECT" or "Requires " .. UI.Number(ground.requiredRebirths) .. " Rebirths",
   unlocked and not selected and Interfaces.CanOpen(),selected)
 end
 local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
 local active = Player:GetAttribute("DataLoaded") and Player:GetAttribute("TrainingActive") and humanoid and humanoid.Health>0
 hud.Enabled = active == true
 if not active then stopPresentation() return end
 local ground = Config.Get(Player:GetAttribute("SelectedTrainingGround"))
 if not ground then stopPresentation() return end
 local capped = Player:GetAttribute("Level") >= Player:GetAttribute("LevelCap")
 detail.Text = ground.displayName .. "\n" .. (capped and "MAX LEVEL - Rebirth available"
  or UI.Number(ground.basePower/ground.interval*Progression.GetPowerMultiplier(rebirths)) .. " Power / second")
  .. "\nLevel " .. UI.Number(Player:GetAttribute("Level")) .. " / " .. UI.Number(Player:GetAttribute("LevelCap"))
  .. (capped and " | Gains paused" or " | Power " .. UI.Number(Player:GetAttribute("Power")) .. " / "
   .. UI.Number(Progression.PowerRequiredForNextLevel(Player:GetAttribute("Level"))))
 startPresentation()
end
for _, name in {"DataLoaded","TrainingActive","BattingActive","HitActive","SelectedTrainingGround","Rebirths","Level","LevelCap","Power","WorldTraveling"} do
 Player:GetAttributeChangedSignal(name):Connect(refresh)
end
Player.CharacterRemoving:Connect(stopPresentation)

-- No claim request exists. This display runs once for this player session, not per respawn.
local offlineCaptured, offlineShown, offlinePending = false, false, false
local offlineMessage, offlineHealthConnection
local function offlineNotice()
 if offlineShown or not Player:GetAttribute("DataLoaded") then return end
 if not offlineCaptured then
  -- Capture the login result once. Later training/Rebirths must not rewrite this notice.
  offlineCaptured = true
  local amount, seconds = Player:GetAttribute("OfflinePowerEarned") or 0, Player:GetAttribute("OfflineSeconds") or 0
  if seconds < Config.OfflineNoticeMinimumSeconds then return end
  local ground = Config.Get(Player:GetAttribute("OfflineTrainingGround"))
  local oldLevel, newLevel = Player:GetAttribute("OfflineOldLevel"),Player:GetAttribute("OfflineNewLevel")
  local capped = newLevel and newLevel >= Player:GetAttribute("LevelCap")
  offlineMessage = (ground and ground.displayName or "Training")
   .. " | " .. math.floor(seconds/3600) .. "h " .. math.floor(seconds%3600/60) .. "m trained"
   .. "\n+" .. UI.Number(amount) .. " Power"
   .. (oldLevel and newLevel and newLevel > oldLevel and "\nLEVEL UP! " .. UI.Number(oldLevel) .. " → " .. UI.Number(newLevel) or "")
   .. (capped and "\nMAX LEVEL REACHED - REBIRTH AVAILABLE" or "")
 end
 local character = Player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not offlineMessage or offlinePending or not character or not character.Parent or not humanoid or humanoid.Health <= 0 then return end
 offlinePending = true
 task.delay(1,function()
  offlinePending = false
  local currentCharacter = Player.Character
  local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
  if not Player:GetAttribute("DataLoaded") or not currentCharacter or not currentCharacter.Parent
   or not currentHumanoid or currentHumanoid.Health <= 0 then return end
  UI.Notify(offlineMessage,"offline")
  offlineShown = true
  if offlineHealthConnection then offlineHealthConnection:Disconnect() offlineHealthConnection = nil end
 end)
end
local function characterAdded(character)
 local humanoid = character:WaitForChild("Humanoid",10)
 if Player.Character ~= character then return end
 if humanoid then
  humanoid.Died:Connect(stopPresentation)
  if offlineHealthConnection then offlineHealthConnection:Disconnect() offlineHealthConnection = nil end
  if not offlineShown then offlineHealthConnection = humanoid.HealthChanged:Connect(offlineNotice) end
 end
 refresh()
 offlineNotice()
end
Player.CharacterAdded:Connect(characterAdded)
if Player.Character then task.spawn(characterAdded,Player.Character) end
Player:GetAttributeChangedSignal("DataLoaded"):Connect(offlineNotice)
offlineNotice()
refresh()
