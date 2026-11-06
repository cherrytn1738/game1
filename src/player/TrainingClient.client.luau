local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Actions = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local Storage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Config = require(Storage:WaitForChild("TrainingConfig"))
local Progression = require(Storage:WaitForChild("ProgressionConfig"))
local Equipment = require(Storage:WaitForChild("EquipmentConfig"))
local Juice = require(Storage:WaitForChild("JuiceConfig"))
local Monetization = require(Storage:WaitForChild("MonetizationConfig"))
local Swing = require(Storage:WaitForChild("SwingConfig"))
local Worlds = require(Storage:WaitForChild("WorldConfig"))
local Remote = Storage:WaitForChild("TrainingRequest")
local GameAudio = require(Storage:WaitForChild("GameAudio"))
local Teleport = Storage:WaitForChild("TrainingTeleport")
local UI = require(script.Parent.UICommon)
local Interfaces = require(script.Parent.HubInterfaces)

local gui, panel, show = UI.Menu("TrainingGroundGui","Training Grounds","Train → gain Power → Level Up → hit farther.",Interfaces.CloseAll)
local list = UI.Scroll(panel,"Grounds")
list.Position, list.Size = UDim2.fromOffset(14,110), UDim2.new(1,-28,1,-166)
local offlineDetail = UI.Label(panel,"Feedback","Walk onto any unlocked ground's plate to train.\nOffline: "
 .. UI.Number(Config.MaximumOfflineSeconds/3600) .. "h maximum at " .. UI.Number(Config.OfflinePowerRateMultiplier*100) .. "% of your best ground's rate.",13,UI.Colors.Muted)
offlineDetail.Position, offlineDetail.Size, offlineDetail.TextWrapped = UDim2.new(0,16,1,-48),UDim2.new(1,-32,0,44),true

-- The server decides access; these only describe it and send intent (teleport / buy prompt).
local function reachable(ground)
 return Config.IsReachable(ground, Config.ReadUnlockedWorlds(Player))
end
local function usable(ground)
 if not reachable(ground) then return false end
 if Config.IsPaid(ground) then return Player:GetAttribute("TrainingPass_" .. Config.GetPassGround(ground).id) == true end
 return (Player:GetAttribute("Rebirths") or 0) >= ground.requiredRebirths
end
-- Where a ground stands, for its card: "World 2", or "Every World" for one in every hub.
local function whereText(ground)
 if #ground.worlds == #Config.Hubs then return "Every World" end
 local world = Worlds.Get(ground.worlds[1])
 return world and world.displayName or ""
end

local rows = {}
for index, ground in Config.Grounds do
 local row = UI.Surface(list,ground.id,UI.Colors.Card)
 row.Size, row.LayoutOrder = UDim2.new(1,-10,0,166), index
 local badge = UI.Badge(row,string.format("%02d",index),Config.IsPaid(ground) and UI.Colors.Accent or UI.Colors.Gold)
 badge.Position = UDim2.fromOffset(16,18)
 local name = UI.Label(row,"Name",ground.displayName,24)
 name.Position, name.Size = UDim2.fromOffset(98,10), UDim2.new(1,-114,0,30)
 local rate = UI.Label(row,"Rate","",19,UI.Colors.Gold)
 rate.Position, rate.Size = UDim2.fromOffset(98,42), UDim2.new(1,-114,0,26)
 local status = UI.Label(row,"Status","",15,UI.Colors.Muted)
 status.Position, status.Size, status.TextWrapped = UDim2.fromOffset(98,70), UDim2.new(1,-114,0,24),true
 local button = UI.Button(row,"Action","GO")
 button.Position, button.Size = UDim2.fromOffset(16,104), UDim2.new(1,-32,0,50)
 button.Activated:Connect(function()
  if not button.Active or not Interfaces.CanOpen() then return end
  if usable(ground) then
   Interfaces.CloseAll()
   Teleport:FireServer(ground.id)
  elseif Config.IsPaid(ground) and reachable(ground) then
   Remote:FireServer("Buy",ground.id)
  end
 end)
 rows[ground.id] = {rate=rate,status=status,button=button}
end
Interfaces.Register("Training",show)
Remote.OnClientEvent:Connect(function(ok,message,details) UI.Notify(message,ok and "success" or "error",details) end)

-- No status panel is shown while training (the HUD's Power bar and Leave button cover it);
-- Space leaves through the same action as the HUD's Leave button.

-- "+Power" popup each time the bat meets a practice ball, like the Cash popup after a real hit:
-- the Power bolt and the amount, popping in above the batter, rising and fading. The amount is
-- what each Training tick grants (the server's own formula: ground, Ball, Rebirths, any Power
-- juice and the purchased Power multiplier), granted by the server at that same moment, at the
-- Level Cap too.
local POPUP_SECONDS, POPUP_RISE = 1.4, 50
local popupGui = UI.Screen("TrainingPopups", 12)
popupGui.IgnoreGuiInset = true
local function powerPerHit()
 local ground = Config.Get(Player:GetAttribute("TrainingGround"))
 if not ground then return 0 end
 local ball = Equipment.Get("Ball", Player:GetAttribute("EquippedBall"))
 local active = Player:FindFirstChild("ActiveJuices")
 local boost = active and Juice.GetMultiplier(active:GetAttributes(), "Power", workspace:GetServerTimeNow()) or 1
 boost *= Monetization.GetMultiplier("Power", Player:GetAttribute("PowerMultiplierTier") or 0)
 -- Training stops on a World change, so the current World is the plate's (Dragon's Lair's multiplier depends on it).
 local base = Progression.TrainingBase * Config.GetMultiplier(ground, Player:GetAttribute("CurrentWorldId"))
 return Progression.GetPowerGrant(base, Player:GetAttribute("Rebirths") or 0, ball and ball.powerGainMultiplier or 1, boost)
end
local function powerPopup(amount)
 local popup = Instance.new("CanvasGroup")
 popup.Name, popup.BackgroundTransparency = "PowerPopup", 1
 popup.AnchorPoint, popup.Size = Vector2.new(.5, .5), UDim2.fromOffset(240, 64)
 -- A little sideways jitter so quick repeats don't stack exactly.
 local x = .5 + (math.random() - .5) * .05
 popup.Position = UDim2.fromScale(x, .4)
 local scale = Instance.new("UIScale")
 scale.Scale, scale.Parent = .85 * UI.SizeScale, popup
 local icon = UI.Icon(popup, "PowerIcon", UI.Icons.Power)
 icon.Position, icon.Size = UDim2.fromOffset(8, 8), UDim2.fromOffset(48, 48)
 local label = UI.Label(popup, "Amount", "+" .. UI.Compact(amount), 34, UI.Showcase.Value)
 label.Position, label.Size, label.TextScaled = UDim2.fromOffset(62, 6), UDim2.new(1, -68, 1, -12), true
 local limit = Instance.new("UITextSizeConstraint")
 limit.MinTextSize, limit.MaxTextSize, limit.Parent = 20, 34, label
 popup.Parent = popupGui
 TweenService:Create(scale, TweenInfo.new(.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = UI.SizeScale}):Play()
 TweenService:Create(popup, TweenInfo.new(POPUP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
  {Position = UDim2.new(x, 0, .4, -POPUP_RISE)}):Play()
 TweenService:Create(popup, TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, POPUP_SECONDS - .5),
  {GroupTransparency = 1}):Play()
 Debris:AddItem(popup, POPUP_SECONDS + .1)
end

local visual, rendering, leaveBound
local refresh
-- A ground's practiceHitEffect (TrainingConfig theme), played on this client as the bat meets a
-- practice ball. Visual only: nothing here touches Training or Power.
local PracticeHitEffects = {}
-- Snow Globe: a flurry of snow swirls round the plate, blown along a ring of little gusts.
function PracticeHitEffects.SnowSwirl(center)
 local ring = Instance.new("Model")
 ring.Name = "SnowSwirl"
 for k = 0, 7 do
  local a = k * math.pi / 4
  local position = center + Vector3.new(math.cos(a) * 7, 3 + (k % 2) * 2.5, math.sin(a) * 7)
  local tangent = Vector3.new(-math.sin(a), 0.15, math.cos(a))
  local gust = Instance.new("Part")
  gust.Name, gust.Transparency, gust.Size = "Gust", 1, Vector3.new(2, 2, 2)
  gust.Anchored, gust.CanCollide, gust.CanTouch, gust.CanQuery = true, false, false, false
  gust.CFrame = CFrame.lookAt(position, position + tangent)
  local snow = Instance.new("ParticleEmitter")
  snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
  snow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(210, 232, 255))
  snow.LightEmission = 0.5
  snow.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.4), NumberSequenceKeypoint.new(1, 0)})
  snow.Lifetime, snow.Speed = NumberRange.new(1.2, 2), NumberRange.new(5, 9)
  snow.EmissionDirection, snow.SpreadAngle = Enum.NormalId.Front, Vector2.new(25, 25)
  snow.Acceleration, snow.Drag, snow.RotSpeed = Vector3.new(0, -1.5, 0), 1.5, NumberRange.new(-180, 180)
  snow.Rate, snow.Enabled = 0, false
  snow.Parent = gust
  gust.Parent = ring
 end
 ring.Parent = workspace
 for _, emitter in ring:GetDescendants() do
  if emitter:IsA("ParticleEmitter") then emitter:Emit(12) end
 end
 Debris:AddItem(ring, 3)
end

local function stopVisual()
 if rendering then rendering:Disconnect() rendering=nil end
 if visual then visual:Destroy() visual=nil end
end
local function stopPresentation()
 stopVisual()
 if leaveBound then Actions:UnbindAction("ExitTraining") leaveBound=false end
end
local function leave(_,state)
 if state == Enum.UserInputState.Begin then Remote:FireServer("Exit",Player:GetAttribute("TrainingSession")) end
 return Enum.ContextActionResult.Sink
end
-- Practice audio (GameAudio): a soft machine thump as each ball is pitched, and a lighter,
-- smaller bat crack than a real hit, heard from the cage. The swing's swish comes from the Bat.
GameAudio.Preload({"PracticeCrack", "PracticePitch", "OfflineReward", "PowerTick"})

local function startPresentation()
 if rendering then return end
 if not leaveBound then
  -- HUD owns the visible Leave button; Space uses the same existing action.
  Actions:BindActionAtPriority("ExitTraining",leave,false,3000,Enum.KeyCode.Space)
  leaveBound = true
 end
 -- Training always happens in the player's current World (travel stops it).
 local world = Worlds.Get(Player:GetAttribute("CurrentWorldId"))
 local hub = world and world.hub and workspace:FindFirstChild(world.hub.name)
 local grounds = hub and hub:FindFirstChild("TrainingGrounds")
 local stadium = grounds and grounds:FindFirstChild(Player:GetAttribute("TrainingGround") or "")
 local plate = stadium and stadium:FindFirstChild("TrainingPlate")
 local pitchOrigin = plate and plate:FindFirstChild("PitchOrigin")
 local contact = plate and plate:FindFirstChild("ContactPosition")
 -- The cage may still be streaming in; try again shortly.
 if not plate or not pitchOrigin or not contact then task.delay(0.5, refresh) return end
 visual = Instance.new("Part")
 visual.Name, visual.Shape, visual.Size = "TrainingPracticeBall", Enum.PartType.Ball, Vector3.new(.65,.65,.65)
 visual.Anchored, visual.CanCollide, visual.CanTouch, visual.CanQuery = true,false,false,false
 visual.Color, visual.Parent = Color3.new(1,1,1), workspace
 local lastCycle, lastCrackCycle, lastPitchCycle = -1, -1, -1
 rendering = RunService.RenderStepped:Connect(function()
  if not plate.Parent or not pitchOrigin.Parent or not contact.Parent then stopVisual() return end
  local elapsed = math.max(0,workspace:GetServerTimeNow()-(Player:GetAttribute("TrainingStartedAt") or workspace:GetServerTimeNow()))
  local cycle, phase = math.floor(elapsed/Config.PracticeCycleSeconds), elapsed%Config.PracticeCycleSeconds
  visual.Transparency = phase > Config.PracticePitchSeconds+.15 and 1 or 0
  visual.Position = pitchOrigin.WorldPosition:Lerp(contact.WorldPosition,math.clamp(phase/Config.PracticePitchSeconds,0,1))
  if cycle ~= lastPitchCycle and phase < Config.PracticePitchSeconds then
   lastPitchCycle = cycle
   GameAudio.Play("PracticePitch", pitchOrigin)
  end
  if cycle ~= lastCycle and phase >= Config.PracticePitchSeconds-Swing.ContactTime then
   lastCycle = cycle
   local tool = Player.Character and Player.Character:FindFirstChild("Bat")
   local swing = tool and tool:FindFirstChild("PracticeSwing")
   if swing then swing:Fire() end
  end
  -- The bat meets the practice ball as it reaches the contact point.
  if cycle ~= lastCrackCycle and phase >= Config.PracticePitchSeconds then
   lastCrackCycle = cycle
   GameAudio.Play("PracticeCrack", contact)
   local ground = Config.Get(Player:GetAttribute("TrainingGround"))
   local hitEffect = ground and ground.theme and PracticeHitEffects[ground.theme.practiceHitEffect or ""]
   if hitEffect then hitEffect(plate.Position) end
   local amount = powerPerHit()
   if amount > 0 then
    powerPopup(amount)
    GameAudio.Play("PowerTick")
   end
  end
 end)
end

function refresh()
 local short = panel.AbsoluteSize.Y < 400
 list.Position, list.Size = UDim2.fromOffset(14,short and 80 or 110),UDim2.new(1,-28,1,short and -136 or -166)
 local rebirths = Player:GetAttribute("Rebirths") or 0
 local ball = Equipment.Get("Ball", Player:GetAttribute("EquippedBall"))
 local ballMultiplier = ball and ball.powerGainMultiplier or 1
 local purchased = Monetization.GetMultiplier("Power", Player:GetAttribute("PowerMultiplierTier") or 0)
 local trainingBase = Progression.TrainingBase
 local trainingAt = Player:GetAttribute("TrainingActive") and Player:GetAttribute("TrainingGround")
 for _, ground in Config.Grounds do
  local row = rows[ground.id]
  local open = usable(ground)
  local paid = Config.IsPaid(ground)
  local pass = paid and Config.GetPassGround(ground)
  local home = Worlds.Get(ground.worlds[1])
  local inReach = reachable(ground)
  -- In this World (Dragon's Lair's multiplier depends on it; other Worlds' grounds show their own).
  local multiplier = Config.GetMultiplier(ground, Player:GetAttribute("CurrentWorldId"))
  row.rate.Text = "x" .. UI.Number(multiplier) .. " POWER  |  "
   .. UI.Number(Progression.GetPowerGrant(trainingBase * multiplier, rebirths, ballMultiplier, purchased)/ground.interval,1) .. " Power / second"
  row.status.Text = whereText(ground) .. " | " .. (trainingAt == ground.id and "Training here now"
   or open and (paid and "Pass owned" or "Unlocked")
   or not inReach and "Locked | Unlock " .. home.displayName .. " first"
   or paid and (pass ~= ground and "Opened by the " .. pass.displayName .. " pass" or "Robux pass - no Rebirths needed")
   or "Locked | Requires " .. UI.Number(ground.requiredRebirths) .. " Rebirths")
  local onSale = paid and inReach and pass.gamePassId > 0
  local label = open and "GO" or not inReach and "UNLOCK " .. string.upper(home.displayName)
   or paid and (onSale and "BUY  R$ " .. UI.Number(pass.robuxPrice) or "COMING SOON")
   or "REQUIRES " .. UI.Number(ground.requiredRebirths) .. " REBIRTHS"
  UI.CardState(row.button.Parent,trainingAt == ground.id and "selected" or open and "available" or "locked")
  UI.SetButton(row.button,label,(open or onSale) and Interfaces.CanOpen() and trainingAt ~= ground.id,open or onSale)
 end
 local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
 local active = Player:GetAttribute("DataLoaded") and Player:GetAttribute("TrainingActive") and humanoid and humanoid.Health>0
 if not active then stopPresentation() return end
 if not Config.Get(Player:GetAttribute("TrainingGround")) then stopPresentation() return end
 startPresentation()
end
for _, name in {"DataLoaded","TrainingActive","TrainingGround","BattingActive","HitActive","EquippedBall","Rebirths","Level","LevelCap","Power","WorldTraveling","PowerMultiplierTier","CurrentWorldId"} do
 Player:GetAttributeChangedSignal(name):Connect(refresh)
end
for _, ground in Config.PassGrounds do
 Player:GetAttributeChangedSignal("TrainingPass_" .. ground.id):Connect(refresh)
end
for _, hub in Config.Hubs do
 Player:GetAttributeChangedSignal("WorldUnlocked_" .. hub.world):Connect(refresh)
end
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
Player.CharacterRemoving:Connect(stopPresentation)

-- Welcome Back: a notification-like popup (UI.RewardPopup) over the blurred game. The clock and
-- bolt break out of its corner, the Power earned counts up under a bolt on a turning sunburst,
-- one small line says how long the player was away (and, at the Level Cap, that a Rebirth is
-- ready), and Claim! closes it (the reward was already added at login). Below the cap there may
-- be a rainbow 3x button beside it that buys the reward twice more for Robux, up to the rest of
-- the run (the server grants it from the receipt; see PlayerData.ClaimOfflineTriple); without an
-- offer Claim! stands alone, centred.
local triple = Config.OfflineTriple
local offlinePopup = UI.RewardPopup("OfflineTrainingGui", {title = "Welcome Back!",
 subtitle = "You trained while you were offline:", icon = UI.ClockIcon, picture = UI.Icons.Power, suffix = " POWER"})
local offlineEarned, offlineVisible = 0, false
local function layoutOffer()
 if Player:GetAttribute("OfflineTripleAvailable") == true then
  -- The server's total with the 3x: the run cap can hold it below three times the reward.
  offlinePopup.setOffer("+" .. UI.Number(Player:GetAttribute("OfflineTriplePower") or offlineEarned),
   triple.productId > 0 and triple.robuxPrice or nil)
 else
  offlinePopup.setOffer(nil)
 end
end
offlinePopup.claim.Activated:Connect(Interfaces.CloseAll)
offlinePopup.offer.Activated:Connect(function()
 if Player:GetAttribute("OfflineTripleAvailable") ~= true then return end
 if triple.productId <= 0 then
  UI.Notify("The 3x offline reward is coming soon!")
  return
 end
 MarketplaceService:PromptProductPurchase(Player, triple.productId)
end)
-- Bought: the server adds the extra Power, sets the new total and withdraws the offer. Count up
-- to it and celebrate (the 3x button goes away); if the popup was already closed, say so.
local offlineShown = false
Player:GetAttributeChangedSignal("OfflineTripleAvailable"):Connect(function()
 local total = Player:GetAttribute("OfflineTriplePower") or offlineEarned
 if Player:GetAttribute("OfflineTripleAvailable") == false and offlineShown and total > offlineEarned then
  if offlineVisible then
   GameAudio.Play("Purchase")
   offlinePopup.countTo(total, 1.2, offlinePopup.celebrate)
  else
   UI.Notify("3x offline Training: +" .. UI.Number(total - offlineEarned) .. " more Power!", "rewardClaimed")
  end
 end
 layoutOffer()
end)
Interfaces.Register("Offline",function(visible)
 offlineVisible = visible
 if visible then layoutOffer() end
 offlinePopup.show(visible)
end)

-- "Away 3h 12m" (the time that counted, at most MaximumOfflineSeconds).
local function awayText(seconds)
 local hours, minutes = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
 local text = "Away " .. (hours > 0 and hours .. "h " .. minutes .. "m" or minutes .. "m")
 return seconds >= Config.MaximumOfflineSeconds and text .. " (max)" or text
end

-- The base reward was added at login (Claim! only closes the screen). This display runs once for
-- this player session, not per respawn.
local offlineCaptured, offlinePending = false, false
local offlineLines, offlineHealthConnection
local function offlineNotice()
 if offlineShown or not Player:GetAttribute("DataLoaded") then return end
 if not offlineCaptured then
  -- Capture the login result once. Later training/Rebirths must not rewrite this notice.
  offlineCaptured = true
  local amount, seconds = Player:GetAttribute("OfflinePowerEarned") or 0, Player:GetAttribute("OfflineSeconds") or 0
  if seconds < Config.OfflineNoticeMinimumSeconds then return end
  local newLevel = Player:GetAttribute("OfflineNewLevel")
  local capped = newLevel and newLevel >= Player:GetAttribute("LevelCap")
  offlineEarned = amount
  offlineLines = {awayText(seconds)}
  if capped then table.insert(offlineLines, {text = "MAX LEVEL - REBIRTH AVAILABLE", color = UI.Colors.Gold}) end
 end
 local character = Player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not offlineLines or offlinePending or not character or not character.Parent or not humanoid or humanoid.Health <= 0 then return end
 offlinePending = true
 task.delay(1,function()
  offlinePending = false
  local currentCharacter = Player.Character
  local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
  if not Player:GetAttribute("DataLoaded") or not currentCharacter or not currentCharacter.Parent
   or not currentHumanoid or currentHumanoid.Health <= 0 then return end
  if not Interfaces.CanOpen() or Interfaces.IsOpen() then return end
  offlineShown = true
  offlinePopup.setDetails(offlineLines)
  offlinePopup.setAmount(0)
  Interfaces.Open("Offline")
  GameAudio.Play("OfflineReward")
  offlinePopup.countTo(offlineEarned, .9)
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
Interfaces.Changed:Connect(offlineNotice)
for _,attribute in {"TrainingActive","BattingActive","HitActive","WorldTraveling"} do
 Player:GetAttributeChangedSignal(attribute):Connect(offlineNotice)
end
offlineNotice()
refresh()
