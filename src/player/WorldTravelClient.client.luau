local Player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Travel = ReplicatedStorage:WaitForChild("WorldTravel")
local GameAudio = require(ReplicatedStorage:WaitForChild("GameAudio"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))
local UI = require(script.Parent:WaitForChild("UICommon"))

-- The Worlds menu: one big picture card per World, its name over the top-left, what unlocks it
-- along the bottom-left, and a status button on the bottom-right (YOU ARE HERE, TRAVEL or
-- LOCKED). The World you are in has a blue frame. Presentation and intent only; the server
-- checks every trip.
local CARD_ASPECT = 3.4 -- card width / height
local SUNBURST = "rbxassetid://130563114903838"
local _, panel, show, window = UI.ShowcaseMenu("WorldTravelGui", "Worlds", Interfaces.CloseAll, {maxWidth = 820, maxHeight = 640, theme = "Blue"})
local well = UI.ShowcaseFrame(window.box, "Well", window.theme.well, 12)
well.Position, well.Size = UDim2.fromOffset(18, 40), UDim2.new(1, -36, 1, -58)
local list = UI.Scroll(well, "WorldList")
list.Position, list.Size = UDim2.fromOffset(4, 4), UDim2.new(1, -8, 1, -8)
list.ScrollBarImageColor3 = UI.Showcase.CardLight
list.UIListLayout.Padding = UDim.new(0, 16)
list.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local padding = list:FindFirstChildOfClass("UIPadding")
padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 0), UDim.new(0, 0)
local rows = {}
local pending, requestVersion = false, 0

local function predecessorOf(world)
 for _, previous in Worlds.Worlds do
  if previous.nextWorldId == world.id then return previous end
 end
 return nil
end

local function refresh()
 local ready = Player:GetAttribute("DataLoaded") == true
 for _, world in Worlds.Worlds do
  local row = rows[world.id]
  local unlocked = ready and Player:GetAttribute("WorldUnlocked_" .. world.id) == true
  local current = Player:GetAttribute("CurrentWorldId") == world.id
  local previous = predecessorOf(world)
  row.requirement.Visible = ready and not unlocked and previous ~= nil
  row.requirement.Text = previous and ("REACH " .. UI.Number(previous.endDistance) .. " STUDS IN " .. string.upper(previous.displayName)) or ""
  row.shade.Visible = ready and not unlocked
  row.frame.BlueFrame.Enabled = current
  local text, kind = "LOCKED", "Red"
  if not ready then text, kind = "LOADING...", "Grey"
  elseif current then text, kind = "YOU ARE HERE", "Blue"
  elseif pending and unlocked then text, kind = "PLEASE WAIT", "Grey"
  elseif unlocked then text, kind = "TRAVEL", "Green" end
  UI.SetShowcaseButton(row.button, text, kind, ready and (unlocked or not current))
 end
end

-- The card's picture: the World's image when it has one, otherwise a painted scene (sky,
-- checkered ground and a sunburst) in its colours.
local function scene(card, world)
 local art = world.preview or {}
 local group = Instance.new("CanvasGroup")
 group.Name, group.Size, group.BorderSizePixel = "Scene", UDim2.fromScale(1, 1), 0
 group.BackgroundColor3 = art.sky or Color3.fromRGB(110, 196, 255)
 local round = Instance.new("UICorner")
 round.CornerRadius, round.Parent = UDim.new(0, 12), group
 group.Parent = card
 if art.image then
  local picture = UI.Icon(group, "Picture", art.image)
  picture.Size, picture.ScaleType = UDim2.fromScale(1, 1), Enum.ScaleType.Crop
  return group
 end
 -- A gradient on the CanvasGroup itself would tint everything in it, so the sky is its own frame.
 local sky = Instance.new("Frame")
 sky.Name, sky.Size, sky.BorderSizePixel, sky.BackgroundColor3 = "Sky", UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1)
 sky.Parent = group
 UI.Gradient(sky, (art.sky or Color3.fromRGB(110, 196, 255)):Lerp(Color3.new(1, 1, 1), .25), art.sky or Color3.fromRGB(110, 196, 255))
 local burst = Instance.new("ImageLabel")
 burst.Name, burst.BackgroundTransparency, burst.Image = "Sunburst", 1, SUNBURST
 burst.AnchorPoint, burst.Position, burst.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .45), UDim2.fromScale(.9, 2.6)
 burst.ScaleType, burst.ImageTransparency, burst.Parent = Enum.ScaleType.Fit, .55, group
 local ground = Instance.new("Frame")
 ground.Name, ground.BorderSizePixel = "Ground", 0
 ground.AnchorPoint, ground.Position, ground.Size = Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, .42)
 ground.BackgroundColor3, ground.Parent = art.ground or Color3.fromRGB(86, 176, 78), group
 UI.Damier(ground, Color3.new(0, 0, 0), 40, NumberSequence.new(.75, .9))
 local icon = UI.Icon(group, "WorldIcon", UI.Icons.Worlds)
 icon.AnchorPoint, icon.Position, icon.Size = Vector2.new(.5, .5), UDim2.fromScale(.42, .5), UDim2.fromScale(.4, .76)
 return group
end

for index, world in Worlds.Worlds do
 local card = UI.ShowcaseFrame(list, world.id, UI.Showcase.Card, 14)
 card.LayoutOrder = index
 -- A second, blue frame round the card of the World you are in.
 local blue = Instance.new("UIStroke")
 blue.Name, blue.Color, blue.Thickness, blue.Enabled = "BlueFrame", Color3.fromRGB(70, 175, 255), 8, false
 blue.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
 card:FindFirstChildOfClass("UIStroke"):Destroy()
 blue.Parent = card
 local black = Instance.new("UIStroke")
 black.Name, black.Color, black.Thickness, black.ApplyStrokeMode = "Outline", UI.Showcase.Outline, 4, Enum.ApplyStrokeMode.Border
 local scenery = scene(card, world)
 black.Parent = scenery
 -- Locked Worlds are shown a little darker.
 local shade = Instance.new("Frame")
 shade.Name, shade.Size, shade.BorderSizePixel, shade.ZIndex = "Shade", UDim2.fromScale(1, 1), 0, 2
 shade.BackgroundColor3, shade.BackgroundTransparency, shade.Visible, shade.Parent = Color3.new(0, 0, 0), .45, false, scenery
 local name = UI.ShowcaseLabel(card, "WorldName", world.displayName, 64)
 name.Position, name.Size, name.TextScaled, name.ZIndex = UDim2.fromScale(.035, .06), UDim2.fromScale(.6, .3), true, 3
 local subtitle = UI.ShowcaseLabel(card, "Theme", world.title or "", 30, Color3.fromRGB(255, 236, 140))
 subtitle.Position, subtitle.Size, subtitle.TextScaled, subtitle.ZIndex = UDim2.fromScale(.036, .37), UDim2.fromScale(.5, .14), true, 3
 local requirement = UI.ShowcaseLabel(card, "Requirement", "", 30)
 requirement.Position, requirement.Size, requirement.TextScaled, requirement.ZIndex = UDim2.fromScale(.036, .74), UDim2.fromScale(.5, .15), true, 3
 local button = UI.ShowcaseButton(card, "Status")
 button.AnchorPoint, button.Position, button.Size, button.ZIndex = Vector2.new(1, 1), UDim2.fromScale(.965, .88), UDim2.fromScale(.42, .3), 4
 rows[world.id] = {frame = card, button = button, requirement = requirement, shade = shade}
 button.Activated:Connect(function()
  if pending or not button.Active or not Interfaces.CanOpen() then return end
  if Player:GetAttribute("CurrentWorldId") == world.id then return end
  if Player:GetAttribute("WorldUnlocked_" .. world.id) ~= true then
   GameAudio.Play("Locked")
   local previous = predecessorOf(world)
   if previous then
    local distance = UI.Number(previous.endDistance) .. " studs"
    UI.Notify("Reach " .. distance .. " in " .. previous.displayName .. " to unlock " .. world.displayName .. ".", "error",
     {kind = "locked", title = "WORLD LOCKED", highlight = distance})
   else
    UI.Notify("This World is locked.", "error", {kind = "locked", title = "WORLD LOCKED"})
   end
   return
  end
  pending = true
  requestVersion += 1
  local version = requestVersion
  refresh()
  Travel:FireServer(world.id)
  task.delay(8, function()
   if pending and version == requestVersion then
    pending = false
    UI.Notify("No response yet. Please try again.", "error")
    refresh()
   end
  end)
 end)
 Player:GetAttributeChangedSignal("WorldUnlocked_" .. world.id):Connect(refresh)
end
-- Cards keep their shape as the window resizes: full list width, CARD_ASPECT wide per tall
-- (in menu units, before the window's scale).
local function sizeCards()
 local scale = math.max(panel.WindowScale.Scale, .01)
 local width = list.AbsoluteSize.X / scale - 24 - list.ScrollBarThickness
 for _, row in rows do row.frame.Size = UDim2.fromOffset(width, width / CARD_ASPECT) end
end
list:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeCards)
sizeCards()

Interfaces.Register("Travel", function(visible)
 show(visible)
 if visible then refresh() end
end)
Player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh)
Player:GetAttributeChangedSignal("CurrentWorldId"):Connect(refresh)

-- Stepping into a hub's World portal (WorldPortal's Trigger) opens this menu, once per entry;
-- choosing a World sends the same server-checked travel request as the buttons above.
local PORTAL_CHECK_SECONDS = 0.15
local inPortal, sinceCheck = false, 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
 sinceCheck += dt
 if sinceCheck < PORTAL_CHECK_SECONDS then return end
 sinceCheck = 0
 local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
 local world = Worlds.Get(Player:GetAttribute("CurrentWorldId"))
 local hub = world and world.hub and workspace:FindFirstChild(world.hub.name)
 local portal = hub and hub:FindFirstChild("WorldPortal")
 local trigger = portal and portal:FindFirstChild("Trigger")
 local inside = false
 if root and trigger then
  local point = trigger.CFrame:PointToObjectSpace(root.Position)
  inside = math.abs(point.X) <= trigger.Size.X / 2 and math.abs(point.Y) <= trigger.Size.Y / 2 + 1
   and math.abs(point.Z) <= trigger.Size.Z / 2
 end
 if inside and not inPortal and not Interfaces.IsOpen() then Interfaces.Open("Travel") end
 inPortal = inside
end)
Travel.OnClientEvent:Connect(function(message)
 pending = false
 requestVersion += 1
 local success = type(message) == "string" and message:sub(1,7) == "Arrived"
 if success then
  Interfaces.CloseAll()
  GameAudio.Play("Travel")
 end
 UI.Notify(success and message or "That destination is unavailable. Check its unlock requirement.", success and "success" or "error")
 refresh()
end)
refresh()
