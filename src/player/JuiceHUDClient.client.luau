-- The running juices, as small pills on the right edge of the screen ("2x POWER  09:42"), one per
-- juice, in that juice's colours. Presentation only: the server owns every expiry time
-- (ActiveJuices attributes, Unix times compared with workspace:GetServerTimeNow()) and removes a
-- juice when it ends; this only counts down to it.
local Players = game:GetService("Players")
local Storage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Juice = require(Storage:WaitForChild("JuiceConfig"))
local UI = require(script.Parent:WaitForChild("UICommon"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))

local PILL_WIDTH, PILL_HEIGHT, GAP = 236, 46, 8
local EFFECT_ICONS = {Power = UI.Icons.Power, Cash = UI.Icons.Cash}

local gui = UI.Screen("JuiceHUD", 12)
-- Right edge, a little above the middle: clear of the counters (top right), the tutorial banner
-- and Auto Bat (top centre), the Level bar (bottom centre) and the batting buttons (bottom right).
local list = Instance.new("Frame")
list.Name, list.BackgroundTransparency = "ActiveJuices", 1
list.AnchorPoint, list.Position = Vector2.new(1, .5), UDim2.new(1, -14, .4, 0)
list.Size = UDim2.fromOffset(PILL_WIDTH, (PILL_HEIGHT + GAP) * #Juice.GetAll())
list.Parent = gui
UI.Shrink(list)
local layout = Instance.new("UIListLayout")
layout.Padding, layout.SortOrder, layout.HorizontalAlignment = UDim.new(0, GAP), Enum.SortOrder.LayoutOrder, Enum.HorizontalAlignment.Right
layout.Parent = list

local pills = {}
for _, definition in Juice.GetAll() do
 local look = definition.appearance or {}
 local pill = UI.Surface(list, definition.id, Color3.new(1, 1, 1))
 pill.Size, pill.LayoutOrder, pill.Visible = UDim2.fromOffset(PILL_WIDTH, PILL_HEIGHT), definition.order, false
 UI.Gradient(pill, look.roof or definition.color or UI.Colors.Panel, look.body or definition.color or UI.Colors.Panel)
 local icon = UI.Icon(pill, "Icon", EFFECT_ICONS[definition.effect] or UI.Icons.Power)
 icon.AnchorPoint, icon.Position, icon.Size = Vector2.new(0, .5), UDim2.new(0, 6, .5, 0), UDim2.fromOffset(34, 34)
 local effect = UI.Label(pill, "Effect", string.format("%gx %s", definition.multiplier,
  string.upper(Juice.Effects[definition.effect].displayName)), 22)
 effect.Position, effect.Size = UDim2.fromOffset(46, 0), UDim2.new(1, -120, 1, 0)
 local timer = UI.Label(pill, "Timer", "", 22, UI.Colors.Gold)
 timer.AnchorPoint, timer.Position, timer.Size = Vector2.new(1, 0), UDim2.new(1, -10, 0, 0), UDim2.new(0, 70, 1, 0)
 timer.TextXAlignment = Enum.TextXAlignment.Right
 pills[definition.id] = {pill = pill, timer = timer}
end

local function formatTime(seconds)
 seconds = math.max(0, math.ceil(seconds))
 local hours, minutes = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
 return hours > 0 and string.format("%d:%02d:%02d", hours, minutes, seconds % 60) or string.format("%02d:%02d", minutes, seconds % 60)
end

local function refresh()
 local humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
 list.Visible = not Interfaces.TutorialFocus() and Player:GetAttribute("DataLoaded") == true and humanoid ~= nil and humanoid.Health > 0
  and not Interfaces.IsOpen() and Player:GetAttribute("WorldTraveling") ~= true
  and Player:GetAttribute("CinematicCamera") == nil and Player:GetAttribute("PortalJourney") == nil
  and Player:GetAttribute("GameFinale") == nil
 local active = Player:FindFirstChild("ActiveJuices")
 local now = workspace:GetServerTimeNow()
 for id, entry in pills do
  local remaining = Juice.GetRemaining(active and active:GetAttribute(id), now)
  entry.pill.Visible = remaining > 0
  entry.timer.Text = formatTime(remaining)
 end
end

Interfaces.Changed:Connect(refresh)
while gui.Parent do
 refresh()
 task.wait(0.5)
end
