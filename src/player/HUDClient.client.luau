local Player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Progression = require(ReplicatedStorage:WaitForChild("ProgressionConfig"))
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local Remote = ReplicatedStorage:WaitForChild("BattingTiming")
local UI = require(script.Parent:WaitForChild("UICommon"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))
local StarterGui = game:GetService("StarterGui")
local savedBackpackEnabled

local gui = UI.Screen("GameHUD", 12)
local root = Instance.new("Frame")
root.Name, root.Size, root.BackgroundTransparency, root.Parent = "Root", UDim2.fromScale(1,1), 1, gui
local wallet = UI.Surface(root,"Wallet")
wallet.AnchorPoint, wallet.Position = Vector2.new(1,0), UDim2.new(1,-12,0,10)
local worldLabel = UI.Label(wallet,"World","Loading player data...",13,UI.Colors.Muted)
worldLabel.Position, worldLabel.Size = UDim2.fromOffset(14,7), UDim2.new(1,-28,0,20)
local cashLabel = UI.Label(wallet,"Cash","Please wait",22,UI.Colors.Gold)
cashLabel.Position, cashLabel.Size, cashLabel.Font = UDim2.fromOffset(14,29), UDim2.new(1,-28,0,30), Enum.Font.GothamBold
local levelLabel = UI.Label(wallet,"Level","",16)
levelLabel.Position, levelLabel.Size = UDim2.fromOffset(14,65), UDim2.new(1,-28,0,22)
local powerLabel = UI.Label(wallet,"Power","",14,UI.Colors.Muted)
powerLabel.Position, powerLabel.Size = UDim2.fromOffset(14,89), UDim2.new(1,-28,0,22)
local rebirthLabel = UI.Label(wallet,"Rebirths","",14,UI.Colors.Muted)
rebirthLabel.Position, rebirthLabel.Size = UDim2.fromOffset(14,137), UDim2.new(1,-28,0,22)
local multiplierLabel = UI.Label(wallet,"PowerMultiplier","",14,UI.Colors.Muted)
multiplierLabel.Position, multiplierLabel.Size = UDim2.fromOffset(14,159), UDim2.new(1,-28,0,22)
local powerTrack = UI.Surface(wallet,"PowerTrack",UI.Colors.Card)
powerTrack.Position, powerTrack.Size, powerTrack.ClipsDescendants = UDim2.fromOffset(14,117), UDim2.new(1,-28,0,10), true
local powerFill = Instance.new("Frame")
powerFill.Name, powerFill.BorderSizePixel, powerFill.BackgroundColor3 = "Fill",0,UI.Colors.Accent
powerFill.Size, powerFill.Parent = UDim2.fromScale(0,1),powerTrack
local rebirthShortcut = UI.Button(root,"RebirthShortcut","REBIRTH AVAILABLE")
rebirthShortcut.AnchorPoint, rebirthShortcut.Position = Vector2.new(1,0),UDim2.new(1,-12,0,208)
rebirthShortcut.Size = UDim2.fromOffset(260,40)
rebirthShortcut.Activated:Connect(function() Interfaces.Open("Rebirth") end)

local navigation = Instance.new("Frame")
navigation.Name, navigation.BackgroundTransparency = "Navigation", 1
navigation.Position, navigation.Size, navigation.Parent = UDim2.new(0,12,1,-112), UDim2.fromOffset(150,92), root
for index, definition in {{"Shop","Equipment"},{"Travel","World travel"}} do
 local button = UI.Button(navigation,definition[1],definition[2])
 button.Position, button.Size = UDim2.fromOffset(0,(index-1)*48), UDim2.fromOffset(150,42)
 button.Activated:Connect(function() Interfaces.Open(definition[1]) end)
end

local hint = UI.Label(root,"BattingHint","Click to swing · Space to leave",14,UI.Colors.Text)
hint.TextXAlignment, hint.AnchorPoint = Enum.TextXAlignment.Center, Vector2.new(.5,1)
hint.Position, hint.Size = UDim2.new(.5,0,1,-12), UDim2.new(1,-24,0,28)
local flight = UI.Surface(root,"Flight")
flight.AnchorPoint, flight.Position, flight.Size = Vector2.new(.5,1), UDim2.new(.5,0,1,-70), UDim2.fromOffset(300,46)
local flightLabel = UI.Label(flight,"Status","Ball in play · waiting for it to stop",14,UI.Colors.Muted)
flightLabel.Size, flightLabel.TextXAlignment = UDim2.fromScale(1,1), Enum.TextXAlignment.Center

local result = UI.Surface(root,"HitResult")
result.AnchorPoint, result.Position, result.Visible = Vector2.new(.5,1), UDim2.new(.5,0,1,-70), false
local resultTitle = UI.Label(result,"Title","HIT COMPLETE",12,UI.Colors.Muted)
resultTitle.Position, resultTitle.Size = UDim2.fromOffset(16,8), UDim2.new(1,-32,0,20)
local distance = UI.Label(result,"Distance","",28)
distance.Position, distance.Size, distance.Font = UDim2.fromOffset(16,29), UDim2.new(1,-32,0,36), Enum.Font.GothamBold
local section = UI.Label(result,"Section","",14,UI.Colors.Muted)
section.Position, section.Size = UDim2.fromOffset(16,66), UDim2.new(1,-32,0,22)
local reward = UI.Label(result,"Reward","",18,UI.Colors.Accent)
reward.Position, reward.Size, reward.Font = UDim2.fromOffset(16,92), UDim2.new(1,-32,0,26), Enum.Font.GothamBold
local resultVersion, lastSwingId = 0, 0
local resultUntil = 0
local cash

local function refresh()
 local ready = Player:GetAttribute("DataLoaded") == true
 local world = Worlds.Get(Player:GetAttribute("CurrentWorldId"))
 worldLabel.Text = ready and world and world.displayName or "Loading player data..."
 cashLabel.Text = ready and cash and UI.Number(cash.Value) .. " Cash" or "Please wait"
 local level, cap = Player:GetAttribute("Level"), Player:GetAttribute("LevelCap")
 local power, rebirths = Player:GetAttribute("Power"), Player:GetAttribute("Rebirths")
 levelLabel.Text = ready and string.format("Level %d / %d",level,cap) or ""
 local capped = ready and level >= cap
 powerLabel.Text = ready and (capped and "MAX LEVEL"
  or "Power: " .. UI.Number(power) .. " / " .. UI.Number(Progression.PowerRequiredForNextLevel(level))) or ""
 powerLabel.TextColor3 = capped and UI.Colors.Accent or UI.Colors.Muted
 rebirthLabel.Text = ready and "Rebirths: " .. UI.Number(rebirths) or ""
 local bat = Equipment.Get("Bat", Player:GetAttribute("EquippedBat"))
 multiplierLabel.Text = ready and "Power Gain: "
  .. UI.Number(Progression.GetPowerMultiplier(rebirths) * bat.powerGainMultiplier, 2) .. "x" or ""
 powerTrack.Visible = ready
 powerFill.Size = UDim2.fromScale(ready and (capped and 1 or math.clamp(power / Progression.PowerRequiredForNextLevel(level),0,1)) or 0,1)
 local alive = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
 alive = alive and alive.Health > 0
 local batting = ready and alive and Player:GetAttribute("BattingActive") == true
 local playing = ready and alive and Player:GetAttribute("HitActive") == true
 local hideBackpack = Interfaces.IsOpen() or batting or Player:GetAttribute("TrainingActive")
 if hideBackpack and savedBackpackEnabled == nil then
  savedBackpackEnabled = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
  StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
 elseif not hideBackpack and savedBackpackEnabled ~= nil then
  StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, savedBackpackEnabled)
  savedBackpackEnabled = nil
 end
 wallet.Visible = not Interfaces.IsOpen()
 rebirthShortcut.Visible = capped and rebirths < Progression.MaxRebirths and not Interfaces.IsOpen() and alive == true
 UI.SetButton(rebirthShortcut,"REBIRTH AVAILABLE",Interfaces.CanOpen(),true)
 navigation.Visible = Interfaces.CanOpen() and not Interfaces.HasPhysicalHub() and not Interfaces.IsOpen()
 hint.Visible = batting and not playing
 hint.Text = UserInputService.TouchEnabled and "Tap to swing · Use Leave to exit" or "Click to swing · Space to leave"
 flight.Visible = playing and not Interfaces.IsOpen()
 if Interfaces.IsOpen() or not ready or not alive then
  resultUntil = 0
  UI.ClearNotifications()
 end
 result.Visible = os.clock() < resultUntil and not playing
end

local function clearTransient()
 resultVersion += 1
 resultUntil = 0
 result.Visible = false
 UI.ClearNotifications()
 refresh()
end
local function resize()
 local width, height = root.AbsoluteSize.X, root.AbsoluteSize.Y
 wallet.Size = UDim2.fromOffset(math.min(260,width-24),190)
 rebirthShortcut.Size = UDim2.fromOffset(math.min(260,width-24),40)
 local landscape = height < 440 and width >= 600
 result.AnchorPoint = landscape and Vector2.new(0,1) or Vector2.new(.5,1)
 flight.AnchorPoint = result.AnchorPoint
 result.Position = landscape and UDim2.new(0,12,1,-50) or UDim2.new(.5,0,1,-70)
 flight.Position = result.Position
 result.Size = UDim2.fromOffset(math.min(360,landscape and width-296 or width-24),128)
 flight.Size = UDim2.fromOffset(math.min(300,landscape and width-296 or width-24),46)
end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
Interfaces.Changed:Connect(refresh)
for _, name in {"DataLoaded","BattingActive","TrainingActive","HitActive","WorldTraveling"} do Player:GetAttributeChangedSignal(name):Connect(refresh) end
for _, name in {"Power","Level","LevelCap","Rebirths","EquippedBat"} do Player:GetAttributeChangedSignal(name):Connect(refresh) end
local lastLevel = Player:GetAttribute("DataLoaded") and Player:GetAttribute("Level") or nil
local noticePending = false
Player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
 lastLevel = Player:GetAttribute("DataLoaded") and Player:GetAttribute("Level") or nil
end)
Player:GetAttributeChangedSignal("Level"):Connect(function()
 if noticePending or not Player:GetAttribute("DataLoaded") then return end
 noticePending = true
 -- Coalesce a multi-level grant into one notification; loading/resetting is silent.
 task.defer(function()
  noticePending = false
  local level = Player:GetAttribute("Level")
  if Player:GetAttribute("DataLoaded") and lastLevel and level > lastLevel then
   local atCap = level >= Player:GetAttribute("LevelCap")
   UI.Notify("Level " .. UI.Number(lastLevel) .. " → " .. UI.Number(level)
    .. (atCap and "\nMAX LEVEL REACHED\nREBIRTH AVAILABLE" or ""),atCap and "cap" or "level")
  end
  lastLevel = level
 end)
end)
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
 resultVersion += 1
 local version = resultVersion
 resultTitle.Text = final.newPersonalBest and "NEW SESSION BEST" or "HIT COMPLETE"
 resultTitle.TextColor3 = final.newPersonalBest and UI.Colors.Accent or UI.Colors.Muted
 distance.Text = UI.Number(final.distanceStuds,1) .. " studs"
 section.Text = final.sectionName or "No field landing"
 reward.Text = "+" .. UI.Number(message.cashEarned or final.cashEarned or 0) .. " Cash"
  .. "  +" .. UI.Number(final.powerEarned or 0) .. " Power"
 resultUntil = os.clock() + 6
 refresh()
 if final.worldCompletionMessage then UI.Notify(final.worldCompletionMessage,"unlock") end
 task.delay(6,function() if version == resultVersion then resultUntil = 0 result.Visible = false end end)
end)
resize()
refresh()
