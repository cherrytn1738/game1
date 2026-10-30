local Player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Field = require(ReplicatedStorage:WaitForChild("FieldConfig"))
local Progression = require(ReplicatedStorage:WaitForChild("ProgressionConfig"))
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local Juice = require(ReplicatedStorage:WaitForChild("JuiceConfig"))
local Remote = ReplicatedStorage:WaitForChild("BattingTiming")
local GameAudio = require(ReplicatedStorage:WaitForChild("GameAudio"))
GameAudio.Preload({"CashReward", "WorldUnlock"})
local UI = require(script.Parent:WaitForChild("UICommon"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))
local QuickMenu = require(script.Parent:WaitForChild("QuickMenu"))
local StarterGui = game:GetService("StarterGui")
local savedTouchEnabled
-- No Roblox hotbar: the Bat is never equipped by hand (number keys), only by the batting and
-- Training stations, which equip it themselves.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
-- Under the Level bar: the Power purchase row (MonetizationClient builds it inside the bar), then
-- the Batting teleport. Heights before the HUD size factor.
local PURCHASE_ROW_GAP, PURCHASE_ROW_HEIGHT = 10, 76

local gui = UI.Screen("GameHUD", 12)
local root = Instance.new("Frame")
root.Name, root.Size, root.BackgroundTransparency, root.Parent = "Root", UDim2.fromScale(1,1), 1, gui
local wallet = UI.Surface(root,"Wallet")
wallet.BackgroundTransparency = 1
wallet:FindFirstChildOfClass("UIStroke").Enabled = false
wallet.AnchorPoint, wallet.Position = Vector2.new(1,0), UDim2.new(1,-14,0,12)
local worldLabel = UI.Label(wallet,"World","Loading player data...",14,UI.Colors.Muted)
worldLabel.Position, worldLabel.Size = UDim2.fromOffset(12,7), UDim2.new(1,-24,0,20)
local cashLabel = UI.Label(wallet,"Cash","Please wait",32,UI.Colors.Gold)
cashLabel.Position, cashLabel.Size = UDim2.fromOffset(12,29), UDim2.new(1,-24,0,32)
local rebirthLabel = UI.Label(wallet,"Rebirths","",32,Color3.fromRGB(120,232,255))
rebirthLabel.Position, rebirthLabel.Size = UDim2.fromOffset(12,63), UDim2.new(1,-24,0,24)

local progression = UI.Surface(root,"Progression")
progression.AnchorPoint = Vector2.new(.5,1)
progression.BackgroundColor3 = Color3.new(1,1,1)
progression.BackgroundTransparency = 0
-- The level bar is white; progress fills it with red diagonal stripes (its only red).
local STRIPE_RED = Color3.fromRGB(214, 38, 46)
UI.Gradient(progression,Color3.fromRGB(255,255,255),Color3.fromRGB(244,241,234))
local levelLabel = UI.Label(progression,"Level","",22)
local capLabel = UI.Label(progression,"LevelCap","",13,UI.Colors.Text)
capLabel.ZIndex=4
levelLabel.Position, levelLabel.Size = UDim2.fromOffset(14,8), UDim2.new(.52,-14,0,28)
local multiplierLabel = UI.Label(progression,"PowerMultiplier","",16,UI.Colors.Gold)
multiplierLabel.Position, multiplierLabel.Size = UDim2.new(.52,0,0,8), UDim2.new(.48,-14,0,28)
multiplierLabel.TextXAlignment = Enum.TextXAlignment.Right
local powerTrack = UI.Surface(progression,"PowerTrack",UI.Colors.Card)
powerTrack.Position, powerTrack.Size, powerTrack.ClipsDescendants = UDim2.new(), UDim2.fromScale(1,1), true
powerTrack.BackgroundTransparency = 1
powerTrack:FindFirstChildOfClass("UIStroke").Enabled = false
local powerFill = Instance.new("Frame")
powerFill.Name, powerFill.BorderSizePixel, powerFill.BackgroundColor3 = "Fill",0,UI.Colors.Accent
powerFill.Size, powerFill.Parent = UDim2.fromScale(0,1),powerTrack
UI.Gradient(powerFill,Color3.fromRGB(255,130,130),Color3.fromRGB(205,30,40))
powerFill.BackgroundColor3 = Color3.new(1,1,1)
powerFill.BackgroundTransparency, powerFill.ClipsDescendants = 1, true
local powerLabel = UI.Label(progression,"Power","",20)
powerLabel.TextXAlignment, powerLabel.ZIndex = Enum.TextXAlignment.Right, 4
levelLabel.ZIndex = 4
local powerAmount = UI.Label(progression,"PowerAmount","",24,UI.Colors.Gold)
local function icon(parent,name,image)
 local imageLabel = Instance.new("ImageLabel")
 imageLabel.Name, imageLabel.Image, imageLabel.BackgroundTransparency = name,image,1
 imageLabel.ScaleType, imageLabel.Parent = Enum.ScaleType.Fit,parent
 return imageLabel
end
local cashIcon = icon(wallet,"CashIcon","rbxassetid://88694661500877")
local rebirthIcon = icon(wallet,"RebirthIcon","rbxassetid://17368214873")
local powerIcon = icon(progression,"PowerIcon","rbxassetid://17368078790")
-- Red diagonal stripes sit behind the text and are clipped to the filled part of the bar.
local stripes = Instance.new("Frame",powerFill)
stripes.Name, stripes.Size, stripes.BackgroundTransparency = "DiagonalStripes",UDim2.fromScale(1,1),1
local stripeCells = {}
for index=1,24 do
 local stripe = Instance.new("Frame",stripes)
 stripe.AnchorPoint, stripe.Size = Vector2.new(.5,.5),UDim2.fromOffset(10,112)
 stripe.BackgroundColor3, stripe.BackgroundTransparency = STRIPE_RED,.3
 stripe.BorderSizePixel, stripe.Rotation = 0,25
 stripeCells[index] = stripe
end
-- Under the Power purchase row: the Batting teleport (intent only; the server picks the spot).
local battingShortcut = UI.Button(root,"BattingShortcut","BATTING")
battingShortcut.AnchorPoint = Vector2.new(.5,1)
battingShortcut.Activated:Connect(function()
 local remote = ReplicatedStorage:FindFirstChild("TeeTeleport")
 if remote and Interfaces.CanOpen() and not Interfaces.IsOpen() then remote:FireServer() end
end)

-- Tile names map to the interface names registered by each client controller. The Shop tile opens
-- the Robux Shop (ShopClient, "Store"); Bats and Balls are bought at the hub displays ("Shop").
local quickMenuInterfaces = {Shop = "Store", Rebirth = "Rebirth", Inventory = "Inventory"}
local navigation = QuickMenu.Create(root, function(name)
 if name == "TrainingTeleport" then
  -- Intent only: the server checks eligibility and chooses the destination.
  local remote = ReplicatedStorage:FindFirstChild(name)
  if remote and not Interfaces.IsOpen() then remote:FireServer() end
  return
 end
 if Interfaces.IsOpen() then return end
 -- Menus can't open while training, so a menu tile leaves training first (the same request as
 -- the Leave button), then opens once the server has stopped it.
 if quickMenuInterfaces[name] and Player:GetAttribute("TrainingActive") then
  ReplicatedStorage.TrainingRequest:FireServer("Exit", Player:GetAttribute("TrainingSession"))
  task.spawn(function()
   local started = os.clock()
   while Player:GetAttribute("TrainingActive") and os.clock() - started < 3 do task.wait(0.1) end
   task.wait(0.1)
   if Interfaces.CanOpen() and not Interfaces.IsOpen() then Interfaces.Open(quickMenuInterfaces[name]) end
  end)
  return
 end
 if not Interfaces.CanOpen() then return end
 if quickMenuInterfaces[name] then
  Interfaces.Open(quickMenuInterfaces[name])
 else
  -- Rewards is a placeholder until that system exists.
  UI.Notify(name .. " is coming soon!")
 end
end)
for _, remoteName in {"TrainingTeleport", "TeeTeleport"} do
 task.spawn(function()
  ReplicatedStorage:WaitForChild(remoteName).OnClientEvent:Connect(function(message, success)
   -- Arriving is its own feedback; only explain refusals.
   if not success then UI.Notify(message, "error") end
  end)
 end)
end

-- Every HUD group shrinks around its own anchor by the shared size factor.
local SIZE = UI.SizeScale
local shrink = UI.Shrink
shrink(wallet)
shrink(progression)
shrink(battingShortcut)

local hint = UI.Label(root,"BattingHint","Click to swing · Space to leave",14,UI.Colors.Text)
local controls = Instance.new("Frame")
controls.Name, controls.BackgroundTransparency, controls.Parent = "ActivityControls",1,root
controls.AnchorPoint, controls.Position, controls.Size = Vector2.new(1,1),UDim2.new(1,-14,1,-84),UDim2.fromOffset(126,102)
local swingButton = UI.Button(controls,"Swing","SWING")
swingButton.Size = UDim2.fromOffset(126,46)
local speedButton = UI.Button(controls,"SpeedUp","2× SPEED")
speedButton.Size = swingButton.Size
speedButton.Visible = false
speedButton.Activated:Connect(function()
 local tool = Player.Character and Player.Character:FindFirstChild("Bat")
 if tool and Player:GetAttribute("BattingActive") and Player:GetAttribute("BallFlightSpeed") == 1 then
  Remote:FireServer(tool:GetAttribute("BattingSession"),"SpeedUp")
 end
end)
local leaveButton = UI.Button(controls,"Leave","LEAVE")
leaveButton.Position, leaveButton.Size = UDim2.fromOffset(0,56),UDim2.fromOffset(126,46)
leaveButton:SetAttribute("Danger",true)
UI.SetButton(leaveButton,"LEAVE",true,false)
swingButton.Activated:Connect(function()
 local tool = Player.Character and Player.Character:FindFirstChild("Bat")
 if tool and Player:GetAttribute("BattingActive") and not Player:GetAttribute("HitActive") then tool:Activate() end
end)
leaveButton.Activated:Connect(function()
 if Player:GetAttribute("TrainingActive") then
  ReplicatedStorage.TrainingRequest:FireServer("Exit",Player:GetAttribute("TrainingSession"))
 elseif Player:GetAttribute("BattingActive") then
  local tool = Player.Character and Player.Character:FindFirstChild("Bat")
  if tool and not tool:GetAttribute("ExitPending") then
   tool:SetAttribute("ExitPending",true)
   Remote:FireServer(tool:GetAttribute("BattingSession"),"Exit")
  end
 end
end)
hint.TextXAlignment, hint.AnchorPoint = Enum.TextXAlignment.Center, Vector2.new(.5,1)
hint.Position, hint.Size = UDim2.new(.5,0,1,-12), UDim2.new(1,-24,0,28)
local flightDistance = UI.Label(root,"FlightDistance","0 studs",44,UI.Colors.Gold)
flightDistance.AnchorPoint, flightDistance.TextXAlignment = Vector2.new(.5,0), Enum.TextXAlignment.Center
flightDistance.Visible = false
flightDistance.TextScaled = true
local distanceTextSize = Instance.new("UITextSizeConstraint",flightDistance)
distanceTextSize.MinTextSize, distanceTextSize.MaxTextSize = 22,44
shrink(controls)
shrink(hint)
shrink(flightDistance)

local cashPopup = Instance.new("CanvasGroup")
cashPopup.Name, cashPopup.BackgroundTransparency, cashPopup.Parent = "CashPopup",1,root
cashPopup.AnchorPoint, cashPopup.Size, cashPopup.Visible = Vector2.new(.5,.5),UDim2.fromOffset(230,64),false
local popupScale = Instance.new("UIScale",cashPopup)
local rewardIcon = UI.Icon(cashPopup,"CashIcon",UI.Icons.Cash)
rewardIcon.Position, rewardIcon.Size = UDim2.fromOffset(8,8),UDim2.fromOffset(48,48)
local reward = UI.Label(cashPopup,"Amount","",32)
reward.Position, reward.Size = UDim2.fromOffset(64,8),UDim2.new(1,-72,1,-16)
reward.TextScaled = true
local rewardTextSize = Instance.new("UITextSizeConstraint",reward)
rewardTextSize.MinTextSize, rewardTextSize.MaxTextSize = 20,32
local popupVersion, lastSwingId = 0, 0
local popupUntil = 0
local popupTweens = {}
local distanceBall, distanceOrigin, distanceForward
local function hideCashPopup()
 popupVersion += 1
 popupUntil = 0
 cashPopup.Visible = false
 for _, tween in popupTweens do tween:Cancel() end
 table.clear(popupTweens)
end
local cash
local fillTween, lastFill

local function refresh()
 local ready = Player:GetAttribute("DataLoaded") == true
 local world = Worlds.Get(Player:GetAttribute("CurrentWorldId"))
 worldLabel.Text = ready and world and world.displayName or "Loading player data..."
 cashLabel.Text = ready and cash and UI.Compact(cash.Value) or "Please wait"
 local level, cap = Player:GetAttribute("Level"), Player:GetAttribute("LevelCap")
 local power, rebirths = Player:GetAttribute("Power"), Player:GetAttribute("Rebirths")
 levelLabel.Text = ready and string.format("Level %d",level) or ""
 capLabel.Text = ready and "LEVEL CAP " .. UI.Number(cap) or ""
 local capped = ready and level >= cap
 powerLabel.Text = ready and (capped and "MAX LEVEL"
  or UI.Compact(power) .. " / " .. UI.Compact(Progression.PowerRequiredForNextLevel(level))) or ""
 powerAmount.Text = ready and UI.Compact(power) .. " POWER" or ""
 powerLabel.TextColor3 = UI.Colors.Text
 rebirthLabel.Text = ready and UI.Number(rebirths) or ""
 local ball = Equipment.Get("Ball", Player:GetAttribute("EquippedBall"))
 -- Includes any active Power juice (display copy of the server timers).
 local activeFolder = Player:FindFirstChild("ActiveJuices")
 local juiceBoost = activeFolder and Juice.GetMultiplier(activeFolder:GetAttributes(), "Power", workspace:GetServerTimeNow()) or 1
 multiplierLabel.Text = ready and "×" .. UI.Number(Progression.GetPowerMultiplier(rebirths) * ball.powerGainMultiplier * juiceBoost, 2) .. " Multiplier" or ""
 powerTrack.Visible = ready
 local fill = ready and (capped and 1 or math.clamp(power / Progression.PowerRequiredForNextLevel(level),0,1)) or 0
 if fill ~= lastFill then
  if fillTween then fillTween:Cancel() end
  fillTween=TweenService:Create(powerFill,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromScale(fill,1)})
  fillTween:Play()
  lastFill=fill
 end
 local alive = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
 alive = alive and alive.Health > 0
 local batting = ready and alive and Player:GetAttribute("BattingActive") == true
 local playing = ready and alive and Player:GetAttribute("HitActive") == true
 controls.Visible = (batting or Player:GetAttribute("TrainingActive") == true) and alive == true
 local flightSpeed = Player:GetAttribute("BallFlightSpeed")
 swingButton.Visible = batting and not (playing and flightSpeed ~= nil)
 speedButton.Visible = Field.FlightSpeedUpEnabled and batting and playing and flightSpeed ~= nil
 -- 2x is one-way per hit; once on, the button shows ON and stays disabled until reset.
 UI.SetButton(speedButton,flightSpeed == 2 and "2×: ON" or "2×: OFF",batting and playing and flightSpeed == 1,flightSpeed == 2)
 UI.SetButton(swingButton,playing and "IN FLIGHT" or "SWING",batting and not playing,true)
 local hideBackpack = Interfaces.IsOpen() or batting or Player:GetAttribute("TrainingActive")
 local touchGui = Player.PlayerGui:FindFirstChild("TouchGui")
 if touchGui then
  if hideBackpack and savedTouchEnabled == nil then
   savedTouchEnabled = touchGui.Enabled
   touchGui.Enabled = false
  elseif not hideBackpack and savedTouchEnabled ~= nil then
   touchGui.Enabled, savedTouchEnabled = savedTouchEnabled, nil
  end
 end
 -- The tutorial keeps only the Level / Power bar (Interfaces.TutorialFocus), plus the tiles it
 -- has brought back (Interfaces.TutorialTile: Inventory, then Rebirth), which it points at.
 local focus = Interfaces.TutorialFocus()
 -- Hidden while a hit is in flight to keep the cinematic view clear.
 wallet.Visible = not Interfaces.IsOpen() and not playing and not focus
 -- Training keeps the HUD up: the Level / Power bar (watch Power grow), the counters and the
 -- menu tiles. Only batting and a hit in flight clear the screen.
 local training = ready and alive and Player:GetAttribute("TrainingActive") == true
 progression.Visible = not Interfaces.IsOpen() and not batting and not playing
 battingShortcut.Visible = progression.Visible and ready and alive == true and Interfaces.CanOpen() and not focus
 UI.SetButton(battingShortcut,"BATTING",Interfaces.CanOpen(),true)
 navigation.Visible = (Interfaces.CanOpen() or training) and not Interfaces.IsOpen()
  and (not focus or Interfaces.TutorialTile("Inventory") or Interfaces.TutorialTile("Rebirth"))
 for _, tile in navigation:GetChildren() do
  if tile:IsA("GuiButton") then tile.Visible = not focus or Interfaces.TutorialTile(tile.Name) end
 end
 hint.Visible = batting and not playing and os.clock() >= popupUntil
 hint.Text = UserInputService.TouchEnabled and "SWING to hit · LEAVE to exit" or "Click to swing · Space to leave"
 if Interfaces.IsOpen() or not ready or not alive then
  hideCashPopup()
  UI.ClearNotifications()
 end
 cashPopup.Visible = os.clock() < popupUntil and not playing
end

local function clearTransient()
 hideCashPopup()
 distanceBall, distanceOrigin, distanceForward = nil,nil,nil
 flightDistance.Visible = false
 UI.ClearNotifications()
 refresh()
end
local function resize()
 local width, height = root.AbsoluteSize.X, root.AbsoluteSize.Y
 local narrow, short = width < 600, height < 440
 -- Not scaled: the space under the bar, for the Power purchase row and the Batting button (and,
 -- on phones, clear of the touch controls).
 local bottom = UserInputService.TouchEnabled and narrow and 172 or 110
 local progressWidth = math.min(760,narrow and (width-24)/SIZE or math.max(300,width-390))
 controls.Position = UDim2.new(1,-14,1,(short and -16 or -84) * SIZE)
 -- Reserve the bottom-left counters for desktop; touch keeps them clear of movement controls.
 local compactWallet = width < 800 or UserInputService.TouchEnabled or height < 360
 wallet.AnchorPoint = compactWallet and Vector2.new(1,0) or Vector2.new(0,1)
 wallet.Position = compactWallet and UDim2.new(1,-14,0,8) or UDim2.new(0,18,1,-10)
 wallet.Size = UDim2.fromOffset(compactWallet and 146 or 168,compactWallet and 92 or 114)
 local iconSize, rowHeight = compactWallet and 30 or 38, compactWallet and 32 or 40
 rebirthIcon.Position, rebirthIcon.Size = UDim2.fromOffset(0,0),UDim2.fromOffset(iconSize,iconSize)
 cashIcon.Position, cashIcon.Size = UDim2.fromOffset(0,rowHeight),UDim2.fromOffset(iconSize,iconSize)
 rebirthLabel.Position, rebirthLabel.Size = UDim2.fromOffset(iconSize+8,0),UDim2.new(1,-iconSize-8,0,rowHeight)
 cashLabel.Position, cashLabel.Size = UDim2.fromOffset(iconSize+8,rowHeight),UDim2.new(1,-iconSize-8,0,rowHeight)
 rebirthLabel.TextSize, cashLabel.TextSize = compactWallet and 24 or 32,compactWallet and 24 or 32
 worldLabel.Position, worldLabel.Size = UDim2.fromOffset(0,rowHeight*2+4),UDim2.new(1,0,0,20)
 progression.Position, progression.Size = UDim2.new(.5,0,1,-bottom),UDim2.fromOffset(progressWidth,64)
 levelLabel.Position, levelLabel.Size = UDim2.fromOffset(16,6),UDim2.new(.49,-16,0,34)
 capLabel.Position,capLabel.Size=UDim2.fromOffset(16,42),UDim2.new(.49,-16,0,17)
 levelLabel.TextSize = narrow and 24 or short and 26 or 34
 multiplierLabel.Position, multiplierLabel.Size = UDim2.new(.5,0,0,-42),UDim2.new(.5,0,0,34)
 multiplierLabel.TextSize = narrow and 16 or short and 18 or 24
 powerIcon.Position, powerIcon.Size = UDim2.fromOffset(0,-43),UDim2.fromOffset(32,32)
 powerAmount.Position, powerAmount.Size = UDim2.fromOffset(34,-42),UDim2.new(.5,-34,0,34)
 powerAmount.TextSize = narrow and 17 or short and 20 or 26
 powerLabel.Position, powerLabel.Size = UDim2.new(.49,0,0,10),UDim2.new(.51,-16,1,-20)
 powerLabel.TextSize = narrow and 20 or short and 22 or 28
 battingShortcut.Position = UDim2.new(.5,0,1,-bottom+(PURCHASE_ROW_GAP+PURCHASE_ROW_HEIGHT+8+36)*SIZE)
 battingShortcut.Size = UDim2.fromOffset(math.min(300,progressWidth),36)
 for index,stripe in stripeCells do
  local x = (index-2)*36
  stripe.Visible = x <= progressWidth+36
  stripe.Position = UDim2.new(0,x,.5,0)
 end
 QuickMenu.Resize(navigation, root.AbsoluteSize)
 -- Phone counters occupy the top-right; place distance immediately beneath them. Wider screens
 -- show it just under the Auto Bat button (MonetizationClient) at the top centre.
 flightDistance.Position = UDim2.new(.5,0,0,narrow and 104 or 58)
 flightDistance.Size = UDim2.fromOffset(math.min(420,width-32),56)
 distanceTextSize.MaxTextSize = narrow and 34 or 44
 hint.Position = UDim2.new(.5,0,1,-bottom-100*SIZE)
end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
local viewportConnection
local function bindViewport()
 if viewportConnection then viewportConnection:Disconnect() end
 local camera = workspace.CurrentCamera
 if camera then viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
 resize()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport)
bindViewport()
Interfaces.Changed:Connect(refresh)
Player.PlayerGui.ChildAdded:Connect(function(child)
 if child.Name == "TouchGui" then refresh() end
end)
for _, name in {"DataLoaded","BattingActive","TrainingActive","HitActive","BallFlightSpeed","WorldTraveling"} do Player:GetAttributeChangedSignal(name):Connect(refresh) end
Player:GetAttributeChangedSignal("HitActive"):Connect(function()
 distanceBall, distanceOrigin, distanceForward = nil,nil,nil
 if Player:GetAttribute("HitActive") then hideCashPopup() end
end)
for _, name in {"Power","Level","LevelCap","Rebirths","EquippedBall","TutorialStep","TutorialBoughtBall"} do Player:GetAttributeChangedSignal(name):Connect(refresh) end
Player:GetAttributeChangedSignal("CurrentWorldId"):Connect(clearTransient)
Player.CharacterRemoving:Connect(clearTransient)
local function characterAdded(character)
 clearTransient()
 local humanoid = character:WaitForChild("Humanoid",10)
 if humanoid then humanoid.Died:Connect(clearTransient) end
 refresh()
end
Player.CharacterAdded:Connect(characterAdded)
if Player.Character then task.spawn(characterAdded,Player.Character) end
task.spawn(function()
 cash = Player:WaitForChild("leaderstats"):WaitForChild("Cash")
 cash:GetPropertyChangedSignal("Value"):Connect(refresh)
 refresh()
end)

-- A single listener survives Tool/character replacement. The server supplies all results.
Remote.OnClientEvent:Connect(function(_, message)
 if message.kind ~= "Distance" then return end
 local final = message.distanceResult
 if not final or type(final.swingId) ~= "number" or final.swingId <= lastSwingId
  or final.worldId ~= Player:GetAttribute("CurrentWorldId") or not Player:GetAttribute("DataLoaded") then return end
 lastSwingId = final.swingId
 hideCashPopup()
 local earned = message.cashEarned or final.cashEarned or 0
 if earned > 0 then
  local version = popupVersion
  reward.Text = "+" .. UI.Compact(earned)
  cashPopup.Position, cashPopup.GroupTransparency = UDim2.fromScale(.5,.43),0
  popupScale.Scale = .85 * UI.SizeScale
  popupUntil = os.clock() + 1.8
  popupTweens = {
   TweenService:Create(popupScale,TweenInfo.new(.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=UI.SizeScale}),
   TweenService:Create(cashPopup,TweenInfo.new(1.8,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(.5,0,.43,-30)}),
   TweenService:Create(cashPopup,TweenInfo.new(.65,Enum.EasingStyle.Quad,Enum.EasingDirection.In,0,false,1.15),{GroupTransparency=1}),
  }
  for _, tween in popupTweens do tween:Play() end
  task.delay(1.8,function() if version == popupVersion then hideCashPopup() refresh() end end)
 end
 refresh()
 -- A World unlock is the bigger payoff, so it replaces the routine Cash confirmation. A ball
 -- through the end portal gets the portal cinematic's own music instead (PortalJourneyClient).
 local portal = final.finishReason == "portal"
 if final.worldCompletionMessage then
  if not portal then GameAudio.Play("WorldUnlock") end
  UI.Notify(final.worldCompletionMessage,"unlock")
 elseif earned > 0 then
  GameAudio.Play("CashReward")
 end
end)

-- Presentation only: read the replicated physics ball and reuse forward-distance
-- math. The server still measures the final landing and determines every reward.
local distanceConnection = RunService.RenderStepped:Connect(function()
 local character = Player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local visible = Player:GetAttribute("DataLoaded") and Player:GetAttribute("HitActive")
  and humanoid and humanoid.Health > 0 and not Interfaces.IsOpen()
 flightDistance.Visible = false
 if not visible then return end
 if not distanceBall or not distanceBall.Parent then
  local world = Worlds.Get(Player:GetAttribute("CurrentWorldId"))
  local area = world and workspace:FindFirstChild(world.stationName)
  local ball = area and area:FindFirstChild("Baseball")
  local tee = area and area:FindFirstChild("Tee")
  local stem = tee and tee:FindFirstChild("Stem")
  local origin = stem and stem:FindFirstChild("BallPosition")
  local direction = area and area:FindFirstChild("HitDirection")
  if not ball or not origin or not direction then return end
  local start = (origin.WorldCFrame * CFrame.new(0,ball.Size.Y/2,0)).Position
  local delta = direction.Position - start
  local flat = Vector3.new(delta.X,0,delta.Z)
  if flat.Magnitude < .01 then return end
  distanceBall, distanceOrigin, distanceForward = ball,start,flat.Unit
 end
 if distanceBall:GetAttribute("BallState") ~= "InFlight" then return end
 flightDistance.Text = UI.Number(math.floor(Field.GetForwardDistance(distanceBall.Position,distanceOrigin,distanceForward))) .. " studs"
 flightDistance.Visible = true
end)
gui.Destroying:Connect(function()
 distanceConnection:Disconnect()
 hideCashPopup()
end)
resize()
refresh()
-- Refresh the multiplier readout as Power juices start and expire.
local function watchJuices(child)
 if child.Name == "ActiveJuices" then child.AttributeChanged:Connect(refresh) end
end
Player.ChildAdded:Connect(watchJuices)
for _, child in Player:GetChildren() do watchJuices(child) end
