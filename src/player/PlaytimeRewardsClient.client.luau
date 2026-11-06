-- Playtime Rewards menu (the HUD's Rewards tile; PlaytimeRewardConfig, PlaytimeRewardServer): a
-- dark Showcase window with a 4 x 3 board of colour tiles, one per reward, in rows of blue, purple
-- and gold with a rainbow grand prize. Locked tiles count down, ready ones glow with a turning
-- sunburst and a Claim button, claimed ones keep their colour under a big check mark. Also the
-- red ready-count badge on the Rewards tile and a floating notice when a reward becomes ready.
-- The server owns the clock, the board and every amount; this only shows them (the amounts with
-- the same formulas, from the server's display attributes) and asks to claim.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Storage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Playtime = require(Storage:WaitForChild("PlaytimeRewardConfig"))
local Training = require(Storage:WaitForChild("TrainingConfig"))
local Equipment = require(Storage:WaitForChild("EquipmentConfig"))
local Juice = require(Storage:WaitForChild("JuiceConfig"))
local JuiceModels = require(Storage:WaitForChild("JuiceModels"))
local GameAudio = require(Storage:WaitForChild("GameAudio"))
local UI = require(script.Parent:WaitForChild("UICommon"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))
local QuickMenu = require(script.Parent:WaitForChild("QuickMenu"))
local remote = Storage:WaitForChild("PlaytimeRewards")
GameAudio.Preload({"Purchase"})

local CHECK_GREEN = Color3.fromRGB(110, 235, 70)
local NARROW = 560 -- below this window width (menu units) the board is 3 x 4
local GAP = 10

local _, panel, show, window = UI.ShowcaseMenu("PlaytimeRewardsGui", "Playtime Rewards", Interfaces.CloseAll,
 {maxWidth = 880, maxHeight = 640, theme = "Grey"})
local visible = false
-- The gift breaking out of the window's top-left corner.
local gift = UI.Icon(panel, "GiftIcon", UI.Icons.Rewards)
gift.Position, gift.Size, gift.Rotation, gift.ZIndex = UDim2.fromOffset(0, 0), UDim2.fromOffset(104, 104), -12, 10

local box = window.box
local board = Instance.new("Frame")
board.Name, board.BackgroundTransparency = "Board", 1
board.Position, board.Size = UDim2.fromOffset(14, 52), UDim2.new(1, -28, 1, -126)
board.Parent = box
local cells = Instance.new("UIGridLayout")
cells.CellPadding, cells.SortOrder = UDim2.fromOffset(GAP, GAP), Enum.SortOrder.LayoutOrder
cells.HorizontalAlignment, cells.VerticalAlignment = Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center
cells.Parent = board

local footer = Instance.new("Frame")
footer.Name, footer.BackgroundTransparency = "Footer", 1
footer.AnchorPoint, footer.Position, footer.Size = Vector2.new(0, 1), UDim2.new(0, 14, 1, -12), UDim2.new(1, -28, 0, 56)
footer.Parent = box
local played = UI.ShowcaseLabel(footer, "Played", "", 22, UI.Colors.Muted)
played.Size, played.TextScaled = UDim2.new(1, -230, 1, 0), true
local playedLimit = Instance.new("UITextSizeConstraint")
playedLimit.MaxTextSize, playedLimit.MinTextSize, playedLimit.Parent = 22, 11, played
local claimAll = UI.ShowcaseButton(footer, "ClaimAll")
claimAll.AnchorPoint, claimAll.Position, claimAll.Size = Vector2.new(1, .5), UDim2.fromScale(1, .5), UDim2.fromOffset(210, 54)
UI.SetShowcaseButton(claimAll, "CLAIM ALL", "Lime", true)

-- Pictures -------------------------------------------------------------------------------
local function viewport(parent, model)
 local frame = Instance.new("ViewportFrame")
 frame.Name, frame.BackgroundTransparency, frame.ZIndex = "Picture", 1, 4
 frame.Ambient, frame.LightColor, frame.LightDirection = Color3.fromRGB(205, 205, 205), Color3.new(1, 1, 1), Vector3.new(-1, -1.5, -1)
 model:PivotTo(CFrame.Angles(0, math.rad(-28), 0))
 model.Parent = frame
 local box, size = model:GetBoundingBox()
 local camera = Instance.new("Camera")
 camera.FieldOfView = 30
 local reach = math.max(size.X, size.Y, size.Z) / 2 / math.tan(math.rad(15)) * 1.05 + math.max(size.X, size.Z) / 2
 camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0, .15, -1).Unit * reach, box.Position)
 camera.Parent, frame.CurrentCamera = frame, camera
 frame.Parent = parent
 return frame
end

local function icon(parent, image, position, size, rotation)
 local picture = UI.Icon(parent, "Picture", image)
 picture.AnchorPoint, picture.Position, picture.Size = Vector2.new(.5, .5), position, size
 picture.Rotation, picture.ZIndex = rotation or 0, 4
 return picture
end

-- The reward's picture filling holder: Cash, the Power bolt, juice boxes, or Cash and Power.
local function rewardArt(holder, reward)
 local kinds = {}
 if reward.cashHits then table.insert(kinds, "cash") end
 if reward.trainingSeconds then table.insert(kinds, "power") end
 if #kinds == 2 then
  icon(holder, UI.Icons.Cash, UDim2.fromScale(.36, .58), UDim2.fromScale(.78, .78), -10)
  icon(holder, UI.Icons.Power, UDim2.fromScale(.68, .44), UDim2.fromScale(.7, .7), 12)
  return
 end
 if kinds[1] then
  icon(holder, kinds[1] == "cash" and UI.Icons.Cash or UI.Icons.Power, UDim2.fromScale(.5, .5), UDim2.fromScale(1, 1),
   kinds[1] == "cash" and -8 or 10)
  return
 end
 local ids = {}
 for id in reward.juices do table.insert(ids, id) end
 table.sort(ids, function(a, b) return a > b end) -- Power Punch first
 for index, id in ids do
  local picture = viewport(holder, JuiceModels.Build(Juice.Get(id)))
  local single = #ids == 1
  picture.AnchorPoint = Vector2.new(.5, .5)
  picture.Position = UDim2.fromScale(single and .5 or (index == 1 and .32 or .68), single and .5 or (index == 1 and .46 or .56))
  picture.Size = UDim2.fromScale(single and 1 or .7, single and 1 or .9)
  picture.ZIndex = 4 + index
 end
end

-- A big green check mark (two rounded bars) filling parent.
local function checkMark(parent)
 local holder = Instance.new("Frame")
 holder.Name, holder.BackgroundTransparency, holder.ZIndex = "Check", 1, 9
 holder.AnchorPoint, holder.Position, holder.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .52), UDim2.fromScale(.7, .7)
 local ratio = Instance.new("UIAspectRatioConstraint")
 ratio.Parent = holder
 for _, bar in {{.27, .66, .42, 45}, {.62, .5, .8, -50}} do
  local arm = Instance.new("Frame")
  arm.Name, arm.BorderSizePixel, arm.BackgroundColor3, arm.ZIndex = "Arm", 0, CHECK_GREEN, 9
  arm.AnchorPoint, arm.Position, arm.Size, arm.Rotation = Vector2.new(.5, .5), UDim2.fromScale(bar[1], bar[2]), UDim2.fromScale(bar[3], .17), bar[4]
  local round = Instance.new("UICorner")
  round.CornerRadius, round.Parent = UDim.new(.5, 0), arm
  local outline = Instance.new("UIStroke")
  outline.Color, outline.Thickness, outline.Parent = UI.Showcase.Outline, 3.5, arm
  local shade = Instance.new("UIGradient")
  shade.Rotation, shade.Color, shade.Parent = 90, ColorSequence.new(Color3.fromRGB(160, 255, 110), Color3.fromRGB(60, 190, 40)), arm
  arm.Parent = holder
 end
 holder.Parent = parent
 return holder
end

-- Amounts (the server's formulas, from its display attributes) -------------------------------
local function passes()
 local owned = {}
 for _, ground in Training.PassGrounds do
  if Player:GetAttribute("TrainingPass_" .. ground.id) == true then owned[ground.id] = true end
 end
 return owned
end

local function amounts(reward)
 local worldId = Player:GetAttribute("CurrentWorldId")
 local ball = Equipment.Get("Ball", Player:GetAttribute("EquippedBall"))
 local cash = Playtime.GetCash(reward, Player:GetAttribute("Level") or 1, worldId, Player:GetAttribute("EquippedBat"),
  Player:GetAttribute("CashMultiplierTier") or 0)
 local power = worldId and Playtime.GetPower(reward, Player:GetAttribute("Rebirths") or 0, ball and ball.powerGainMultiplier or 1,
  Player:GetAttribute("PowerMultiplierTier") or 0, passes(), worldId) or 0
 return cash, power
end

local function juiceText(juices, short)
 local parts = {}
 for _, id in {"power_punch", "cash_splash"} do
  local count = juices[id]
  if count then
   local name = string.upper(Juice.Get(id).displayName)
   table.insert(parts, short and (name:match("(%S+)$")) or (count .. " " .. name))
  end
 end
 return table.concat(parts, short and " + " or "\n")
end

local function amountText(reward)
 local cash, power = amounts(reward)
 local lines = {}
 if reward.cashHits then table.insert(lines, "+$" .. UI.Compact(cash)) end
 if reward.trainingSeconds then table.insert(lines, "+" .. UI.Compact(power) .. " POWER") end
 if reward.juices then
  local count = 0
  for _ in reward.juices do count += 1 end
  table.insert(lines, juiceText(reward.juices, count > 1))
 end
 return table.concat(lines, "\n")
end

-- Tiles -------------------------------------------------------------------------------------
local tiles = {}
for index, reward in Playtime.Rewards do
 local card, palette = UI.ColorCard(board, "Reward" .. index, reward.row)
 card.LayoutOrder = index
 local scale = Instance.new("UIScale")
 scale.Name, scale.Parent = "Pop", card
 local glow = Instance.new("Frame")
 glow.Name, glow.BackgroundTransparency, glow.ClipsDescendants, glow.ZIndex = "Glow", 1, true, 2
 glow.Position, glow.Size = UDim2.fromOffset(8, 8), UDim2.new(1, -16, 1, -16)
 glow.Parent = card
 local burst = UI.Sunburst(glow, .35)
 burst.Size = UDim2.fromScale(1.5, 1.5)
 local art = Instance.new("Frame")
 art.Name, art.BackgroundTransparency, art.ZIndex = "Art", 1, 4
 -- The grand prize's two-line amount needs more room above its picture.
 art.AnchorPoint = Vector2.new(.5, .5)
 art.Position = UDim2.fromScale(.5, reward.grand and .6 or .54)
 art.Size = UDim2.fromScale(.8, reward.grand and .5 or .58)
 local ratio = Instance.new("UIAspectRatioConstraint")
 ratio.Parent = art
 art.Parent = card
 local artScale = Instance.new("UIScale")
 artScale.Parent = art
 rewardArt(art, reward)
 local amount = UI.CardTitle(card, "Amount", "", reward.grand and 26 or 28, palette)
 amount.Position, amount.Size, amount.ZIndex = UDim2.fromOffset(8, 6), UDim2.new(1, -16, reward.grand and .34 or .24, 0), 6
 amount.TextXAlignment, amount.TextWrapped = Enum.TextXAlignment.Center, true
 local shade = Instance.new("Frame")
 shade.Name, shade.BorderSizePixel, shade.BackgroundColor3, shade.ZIndex = "Shade", 0, Color3.new(0, 0, 0), 7
 shade.Size = UDim2.fromScale(1, 1)
 local shadeCorner = Instance.new("UICorner")
 shadeCorner.CornerRadius, shadeCorner.Parent = UDim.new(0, 16), shade
 shade.Parent = card
 local countdown = UI.ShowcaseLabel(card, "Countdown", "", 30)
 countdown.AnchorPoint, countdown.Position, countdown.Size = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -8), UDim2.new(1, -16, .2, 0)
 countdown.TextXAlignment, countdown.TextScaled, countdown.ZIndex = Enum.TextXAlignment.Center, true, 9
 local countdownLimit = Instance.new("UITextSizeConstraint")
 countdownLimit.MaxTextSize, countdownLimit.Parent = 30, countdown
 local check = checkMark(card)
 local claim = UI.ShowcaseButton(card, "Claim")
 claim.AnchorPoint, claim.Position, claim.Size, claim.ZIndex = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -8), UDim2.new(1, -20, .22, 0), 8
 UI.SetShowcaseButton(claim, "CLAIM", "Lime", true)
 claim.Activated:Connect(function() remote:FireServer("Claim", index) end)
 tiles[index] = {card = card, reward = reward, glow = glow, art = art, artScale = artScale, amount = amount, shade = shade,
  countdown = countdown, check = check, claim = claim, scale = scale, state = nil}
end

-- Board state --------------------------------------------------------------------------------
local function clock(seconds)
 seconds = math.max(0, math.ceil(seconds))
 local h, m, s = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
 return h > 0 and string.format("%d:%02d:%02d", h, m, s) or string.format("%d:%02d", m, s)
end

local function elapsed()
 return workspace:GetServerTimeNow() - (Player:GetAttribute("PlaytimeCycleStart") or workspace:GetServerTimeNow())
end

local function isClaimed(index)
 local mask = Player:GetAttribute("PlaytimeClaimed") or 0
 return math.floor(mask / 2 ^ (index - 1)) % 2 == 1
end

local function stateOf(index, time)
 if isClaimed(index) then return "claimed" end
 return time >= Playtime.UnlockSeconds(index, Player:GetAttribute("PlaytimeScale") or 1) and "ready" or "locked"
end

local function setState(tile, state)
 if tile.state == state then return end
 tile.state = state
 tile.glow.Visible = state == "ready"
 tile.claim.Visible = state == "ready"
 tile.countdown.Visible = state == "locked"
 tile.check.Visible = state == "claimed"
 tile.shade.Visible = state ~= "ready"
 tile.shade.BackgroundTransparency = state == "locked" and .5 or .38
 tile.artScale.Scale = 1
end

local function readyCount(time)
 local count = 0
 for index in Playtime.Rewards do
  if stateOf(index, time) == "ready" then count += 1 end
 end
 return count
end

local function updateBoard()
 local time = elapsed()
 local scale = Player:GetAttribute("PlaytimeScale") or 1
 for index, tile in tiles do
  local state = stateOf(index, time)
  setState(tile, state)
  if state == "locked" then tile.countdown.Text = clock(Playtime.UnlockSeconds(index, scale) - time) end
  tile.amount.Text = amountText(tile.reward)
 end
 local ready = readyCount(time)
 claimAll.Visible = ready >= 2
 played.Text = "PLAYED THIS ROUND  " .. clock(time) .. "   •   THE BOARD STARTS AGAIN AFTER THE LAST REWARD"
end

-- Ready tiles breathe gently while the menu is open.
RunService.RenderStepped:Connect(function()
 if not visible then return end
 local pulse = 1 + .05 * math.sin(os.clock() * 3)
 for _, tile in tiles do
  if tile.state == "ready" then tile.artScale.Scale = pulse end
 end
end)

-- Layout: the board picks 3, 4 or 6 columns, whichever keeps the tiles closest to a comfortable
-- shape (about 1.4 wide to 1 tall): 4 x 3 on desktop, 3 x 4 on phones held upright, 6 x 2 on short
-- landscape screens.
local TILE_SHAPE = 1.4
local function layout()
 local scale = math.max(panel.WindowScale.Scale, .01)
 local width, height = board.AbsoluteSize.X / scale, board.AbsoluteSize.Y / scale
 if width < 50 or height < 50 then return end
 local best, bestScore, cellWidth, cellHeight = 4, -1, 0, 0
 for _, columns in {3, 4, 6} do
  local rows = math.ceil(#tiles / columns)
  local w = math.floor((width - GAP * (columns - 1)) / columns)
  local h = math.floor((height - GAP * (rows - 1)) / rows)
  local score = math.min(w / TILE_SHAPE, h)
  if score > bestScore then best, bestScore, cellWidth, cellHeight = columns, score, w, h end
 end
 cells.CellSize = UDim2.fromOffset(cellWidth, cellHeight)
 local narrow = box.AbsoluteSize.X / scale < NARROW
 claimAll.Size = UDim2.fromOffset(narrow and 170 or 210, 54)
 played.Size = UDim2.new(1, narrow and -184 or -230, 1, 0)
 board:SetAttribute("Columns", best)
end
board:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
panel.WindowScale:GetPropertyChangedSignal("Scale"):Connect(layout)

-- Claiming --------------------------------------------------------------------------------
claimAll.Activated:Connect(function() remote:FireServer("ClaimAll") end)

-- A small burst of sparks out of a claimed tile, and a pop.
local function burst(tile)
 tile.scale.Scale = 1.1
 TweenService:Create(tile.scale, TweenInfo.new(.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
 for i = 1, 12 do
  local spark = Instance.new("Frame")
  spark.Name, spark.BorderSizePixel, spark.ZIndex = "Spark", 0, 12
  spark.BackgroundColor3 = i % 3 == 0 and Color3.new(1, 1, 1) or i % 3 == 1 and UI.Colors.Gold or CHECK_GREEN
  spark.AnchorPoint, spark.Position, spark.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromOffset(12, 12)
  spark.Rotation = 45
  local round = Instance.new("UICorner")
  round.CornerRadius, round.Parent = UDim.new(0, 3), spark
  spark.Parent = tile.card
  local angle = (i / 12) * math.pi * 2 + math.random() * .3
  local reach = .45 + math.random() * .25
  TweenService:Create(spark, TweenInfo.new(.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
   Position = UDim2.fromScale(.5 + math.cos(angle) * reach, .5 + math.sin(angle) * reach),
   BackgroundTransparency = 1, Size = UDim2.fromOffset(4, 4), Rotation = 225}):Play()
  game:GetService("Debris"):AddItem(spark, .6)
 end
end

local function grantedText(results)
 local cash, power, juices = 0, 0, {}
 for _, granted in results do
  cash += granted.cash or 0
  power += granted.power or 0
  for id, count in granted.juices or {} do juices[id] = (juices[id] or 0) + count end
 end
 local parts = {}
 if cash > 0 then table.insert(parts, "+$" .. UI.Compact(cash) .. " CASH") end
 if power > 0 then table.insert(parts, "+" .. UI.Compact(power) .. " POWER") end
 for _, id in {"power_punch", "cash_splash"} do
  if juices[id] then table.insert(parts, "+" .. juices[id] .. " " .. string.upper(Juice.Get(id).displayName)) end
 end
 return table.concat(parts, "  •  ")
end

remote.OnClientEvent:Connect(function(kind, results, restarted)
 if kind ~= "Claimed" or type(results) ~= "table" then return end
 GameAudio.Play("Purchase")
 for _, granted in results do
  local tile = type(granted) == "table" and tiles[granted.index]
  if tile then burst(tile) end
 end
 local text = grantedText(results)
 if restarted then text ..= "\nEvery reward claimed: the board starts again!" end
 UI.Notify(text, "rewardClaimed")
 updateBoard()
end)

-- HUD badge and "ready" notices ---------------------------------------------------------------
local rewardsTile
task.spawn(function()
 local gui = Player:WaitForChild("PlayerGui"):WaitForChild("GameHUD")
 rewardsTile = gui:WaitForChild("Root"):WaitForChild("Navigation"):WaitForChild("Rewards")
end)

local wasReady = {}
local function tick()
 local time = elapsed()
 local tutorial = Interfaces.TutorialFocus()
 local count = 0
 local newlyReady
 for index in Playtime.Rewards do
  local ready = stateOf(index, time) == "ready"
  if ready then
   count += 1
   if not wasReady[index] then newlyReady = newlyReady or index end
  end
  wasReady[index] = ready
 end
 if rewardsTile then QuickMenu.SetBadge(rewardsTile, tutorial and 0 or count) end
 -- A reward that just became ready, while the menu is closed (and the tutorial is done).
 if newlyReady and not visible and not tutorial and Player:GetAttribute("DataLoaded") then
  UI.Notify(amountText(Playtime.Rewards[newlyReady]):gsub("\n", "  ") .. " is ready to claim!", "rewardReady")
 end
 if visible then updateBoard() end
end
task.spawn(function()
 while true do
  local ok, problem = pcall(tick)
  if not ok then warn("[PlaytimeRewards] " .. tostring(problem)) end
  task.wait(.25)
 end
end)
Player:GetAttributeChangedSignal("PlaytimeClaimed"):Connect(function() if visible then updateBoard() end end)

Interfaces.Register("Rewards", function(open)
 visible = open
 show(open)
 if open then
  updateBoard()
  layout()
 end
end)
