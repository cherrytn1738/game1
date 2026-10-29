-- New-player tutorial presentation (TutorialConfig): the objective banner, ground arrows to
-- where each step happens, and a spotlight on the one control a menu step needs. The server
-- moves the tutorial (TutorialStep / TutorialProgress attributes); this script only shows it,
-- and removes everything for good once the tutorial is complete. Players who have finished it
-- never load the guide or the spotlight.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Storage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Tutorial = require(Storage:WaitForChild("TutorialConfig"))
local Equipment = require(Storage:WaitForChild("EquipmentConfig"))
local Worlds = require(Storage:WaitForChild("WorldConfig"))
local Training = require(Storage:WaitForChild("TrainingConfig"))
local GameAudio = require(Storage:WaitForChild("GameAudio"))

while Player:GetAttribute("TutorialStep") == nil do Player:GetAttributeChangedSignal("TutorialStep"):Wait() end
if Player:GetAttribute("TutorialStep") == Tutorial.Complete then return end

local UI = require(script.Parent:WaitForChild("UICommon"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))
local GuideArrows = require(script.Parent:WaitForChild("GuideArrows"))
local Spotlight = require(script.Parent:WaitForChild("Spotlight"))

local CHECK_SECONDS = 0.2
local SHOP_OPEN_DISTANCE = 14 -- studs from the tutorial Ball's pedestal that open the Shop
local SHOP_REARM_DISTANCE = 24 -- walking this far away lets it open the Shop again
local IDLE_SECONDS = 20 -- ReachLevel: arrows return to Training after this long without Power
local BALL = Equipment.Get("Ball", Tutorial.BallId)
local WORLD = Worlds.Get(Tutorial.WorldId)

GameAudio.Preload({"TutorialStep", "TutorialComplete"})

-- Banner: top centre, below Roblox's top bar, above menus and the spotlight.
local gui = UI.Screen("TutorialGui", 46)
local banner = Instance.new("Frame")
banner.Name, banner.BackgroundTransparency = "Banner", 1
banner.AnchorPoint, banner.Position, banner.Size = Vector2.new(.5, 0), UDim2.new(.5, 0, 0, 4), UDim2.new(.94, 0, 0, 98)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize, limit.Parent = Vector2.new(680, 98), banner
local pop = Instance.new("UIScale")
pop.Parent = banner
banner.Parent = gui
local function line(name, y, height, size, color)
 local label = UI.Label(banner, name, "", size, color)
 label.Position, label.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, height)
 label.TextXAlignment, label.TextScaled = Enum.TextXAlignment.Center, true
 local constraint = Instance.new("UITextSizeConstraint")
 constraint.MaxTextSize, constraint.MinTextSize, constraint.Parent = size, 10, label
 return label
end
local heading = line("Heading", 0, .24, 22, UI.Colors.Text)
local objective = line("Objective", .22, .54, 46, UI.Colors.Gold)
local hint = line("Hint", .76, .24, 20, UI.Colors.Muted)
heading.Text = "TUTORIAL"

local guide = GuideArrows.new()
local connections = {}
local shownStep, shownProgress
local shopDismissed, rebirthOpened = false, false
local lastProgressAt = os.clock()
local finished = false

local function hub()
 return workspace:FindFirstChild(WORLD.hub.name)
end

-- Notifications drop in at the same top-centre spot; while one shows, the banner sits under it.
local function placeBanner()
 local notifications = Player.PlayerGui:FindFirstChild("NotificationGui")
 local notice = notifications and notifications:FindFirstChild("Notice")
 local top = 4
 if notice and notice.Visible then top = notice.AbsolutePosition.Y + notice.AbsoluteSize.Y + 6 end
 banner.Position = UDim2.new(.5, 0, 0, top)
end

local function bump()
 pop.Scale = 1.12
 TweenService:Create(pop, TweenInfo.new(.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
end

-- Through the Basic Training cage's door to its plate (straight to the plate once inside).
local function trainingRoute(root)
 local grounds = hub() and hub():FindFirstChild("TrainingGrounds")
 local stadium = grounds and grounds:FindFirstChild(Tutorial.TrainingGroundId)
 local plate = stadium and stadium:FindFirstChild("TrainingPlate")
 if not plate then return nil end
 local entrance = stadium:FindFirstChild("EntranceSign", true)
 local c = Training.Cage
 local p = plate.CFrame:PointToObjectSpace(root.Position)
 if not entrance or (p.X > c.left and p.X < c.right and p.Z > c.front and p.Z < c.back) then return {plate.Position} end
 local out = plate.CFrame:VectorToWorldSpace(Vector3.zAxis) -- the door is on the cage's +Z end
 local door = Vector3.new(entrance.Position.X, plate.Position.Y, entrance.Position.Z)
 return {door + out * 5, door - out * 3, plate.Position}
end

local function battingRoute()
 local area = workspace:FindFirstChild(WORLD.stationName)
 local pad = area and area:FindFirstChild("BatterPosition")
 return pad and {pad.Position} or nil
end

local function ballPedestal()
 local world = hub()
 for _, pedestal in CollectionService:GetTagged("ItemPedestal") do
  if pedestal:GetAttribute("ItemId") == Tutorial.BallId and world and pedestal:IsDescendantOf(world) then
   return pedestal:FindFirstChild("Pedestal")
  end
 end
 return nil
end

local function namedButton(screen, name)
 for _, object in screen and screen:GetDescendants() or {} do
  if object:IsA("GuiButton") and object.Name == name then return object end
 end
 return nil
end

-- The Shop's Balls tab, then (once the Balls show) the tutorial Ball's PURCHASE button.
local function shopTarget()
 local shop = Player.PlayerGui:FindFirstChild("EquipmentShopGui")
 local list = shop and shop:FindFirstChild("EquipmentList", true)
 local row = list and list:FindFirstChild(Tutorial.BallId)
 if row then
  return row:FindFirstChild("Action"), shop, string.format("BUY THE %s - $%s", string.upper(BALL.displayName), UI.Number(BALL.price))
 end
 return namedButton(shop, "BallTab"), shop, "OPEN THE BALLS"
end

-- The Rebirth menu's REBIRTH button, then its CONFIRM button.
local function rebirthTarget()
 local menu = Player.PlayerGui:FindFirstChild("RebirthGui")
 local confirm = namedButton(menu, "ConfirmRebirth")
 if confirm and confirm.Visible then return confirm, menu, "CONFIRM YOUR REBIRTH" end
 return namedButton(menu, "Rebirth"), menu, "PRESS REBIRTH"
end

local function texts(step, progress)
 if step == "EarnPower" then
  return string.format("GET %d POWER (%d/%d)", Tutorial.PowerGoal, progress, Tutorial.PowerGoal), "Train at Basic Training"
 elseif step == "EarnCash" then
  return string.format("EARN $%d FROM BATTING ($%d/$%d)", Tutorial.CashGoal, progress, Tutorial.CashGoal), "Hit the ball down the runway"
 elseif step == "BuyBall" then
  return "BUY THE " .. string.upper(BALL.displayName),
   string.format("$%s for x%s POWER", UI.Number(BALL.price), UI.Number(BALL.powerGainMultiplier))
 elseif step == "ReachLevel" then
  local cap = Player:GetAttribute("LevelCap") or Tutorial.RebirthLevel
  return string.format("REACH LEVEL %d (%d/%d)", cap, Player:GetAttribute("Level") or 1, cap), "Train to gain Power"
 elseif step == "Rebirth" then
  return "REBIRTH NOW!", "Open Rebirth and confirm"
 end
 return "", ""
end

local function finish()
 finished = true
 for _, connection in connections do connection:Disconnect() end
 guide:Destroy()
 Spotlight.Destroy()
 banner.Visible = true
 objective.Text, hint.Text = "TUTORIAL COMPLETE!", "Keep Training, batting and Rebirthing!"
 bump()
 -- The Rebirth notice shows now too; keep clear of it until the banner fades.
 local placing = RunService.Heartbeat:Connect(placeBanner)
 task.delay(6, function() placing:Disconnect() end)
 -- After the Rebirth fanfare's opening, so the two don't collide.
 task.delay(1.6, GameAudio.Play, "TutorialComplete")
 task.delay(5, function()
  for _, label in {heading, objective, hint} do
   TweenService:Create(label, TweenInfo.new(.6), {TextTransparency = 1}):Play()
   TweenService:Create(label:FindFirstChildOfClass("UIStroke"), TweenInfo.new(.6), {Transparency = 1}):Play()
  end
  task.wait(.7)
  gui:Destroy()
 end)
end

local function update()
 if finished then return end
 local step = Player:GetAttribute("TutorialStep")
 local progress = Player:GetAttribute("TutorialProgress") or 0
 if step == Tutorial.Complete then finish() return end
 if step ~= shownStep then
  if shownStep then GameAudio.Play("TutorialStep") bump() end
  shownStep, shopDismissed, rebirthOpened, lastProgressAt = step, false, false, os.clock()
 elseif progress ~= shownProgress then
  bump()
 end
 shownProgress = progress
 local character = Player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local alive = root ~= nil and humanoid ~= nil and humanoid.Health > 0
 local inWorld = Player:GetAttribute("CurrentWorldId") == Tutorial.WorldId
 local busy = Player:GetAttribute("TrainingActive") or Player:GetAttribute("BattingActive") or Player:GetAttribute("HitActive")
 local menu = Interfaces.Current()
 objective.Text, hint.Text = texts(step, progress)
 local needsHome = step == "EarnPower" or step == "EarnCash" or step == "BuyBall"
 if needsHome and not inWorld then hint.Text = "Travel back to " .. WORLD.title end

 -- Ground arrows: only while walking around World 1's hub with no menu open. Once Level 20 is
 -- the goal they stay away unless the player goes a while without gaining Power.
 local idle = step == "ReachLevel" and os.clock() - lastProgressAt > IDLE_SECONDS
 local route
 if alive and inWorld and not busy and not menu then
  if step == "EarnPower" or idle then
   route = trainingRoute(root)
  elseif step == "EarnCash" then
   route = battingRoute()
  elseif step == "BuyBall" then
   local pedestal = ballPedestal()
   route = pedestal and {pedestal.Position}
  end
 end
 if route then guide:Show(route) else guide:Hide() end

 -- At the tutorial Ball's pedestal, the Shop opens once per approach with the Ball spotlit.
 local pedestal = step == "BuyBall" and alive and inWorld and ballPedestal()
 if pedestal then
  local distance = (root.Position - pedestal.Position).Magnitude
  if distance > SHOP_REARM_DISTANCE then shopDismissed = false end
  if distance < SHOP_OPEN_DISTANCE and not shopDismissed and not menu and Interfaces.CanOpen() then
   shopDismissed = true
   Interfaces.Open("Shop")
   menu = Interfaces.Current()
  end
 end
 -- The Rebirth menu opens by itself once, as soon as menus can open (after leaving Training).
 if step == "Rebirth" and not rebirthOpened and not menu and Interfaces.CanOpen() then
  rebirthOpened = true
  Interfaces.Open("Rebirth")
  menu = Interfaces.Current()
 end

 local target, scope, caption, dim
 if step == "BuyBall" and menu == "Shop" then
  target, scope, caption = shopTarget()
 elseif step == "Rebirth" and menu == "Rebirth" then
  target, scope, caption = rebirthTarget()
 elseif step == "Rebirth" and not menu then
  -- Only a ring on the HUD's Rebirth tile (no darkening outside a menu).
  target, caption, dim = namedButton(Player.PlayerGui:FindFirstChild("GameHUD"), "Rebirth"), "OPEN REBIRTH", false
 end
 if target then
  Spotlight.Show(target, {dim = dim ~= false, scope = scope, caption = caption, allowed = {scope and namedButton(scope, "Close")}})
 else
  Spotlight.Hide()
 end
 -- Inside a menu the spotlight and its caption carry the instruction; the banner steps aside.
 banner.Visible = menu == nil
 placeBanner()
end

table.insert(connections, Player:GetAttributeChangedSignal("Power"):Connect(function() lastProgressAt = os.clock() end))
table.insert(connections, Player:GetAttributeChangedSignal("TrainingActive"):Connect(function() lastProgressAt = os.clock() end))
for _, attribute in {"TutorialStep", "TutorialProgress", "Level"} do
 table.insert(connections, Player:GetAttributeChangedSignal(attribute):Connect(update))
end
table.insert(connections, Interfaces.Changed:Connect(function()
 -- Closing the Shop by hand means it shouldn't pop open again until the player walks off.
 task.defer(update)
end))
table.insert(connections, Player.CharacterRemoving:Connect(function()
 guide:Hide()
 Spotlight.Hide()
end))
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
 elapsed += dt
 if elapsed < CHECK_SECONDS then return end
 elapsed = 0
 update()
end))
update()
