-- Inventory: the Bats and Balls you own (tap one to equip it) and your Juice (tap to drink).
-- Tabs stand down the left of the window; each owned item is a picture card with its multiplier
-- along the bottom, and the equipped one has a blue frame and a green tick.
-- Presentation and intent only; the server validates every equip and juice use, and the
-- item displays' listener (ItemDisplayClient) shows each equip result as a notification.
local Player = game.Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local Storage = game:GetService("ReplicatedStorage")
local Equipment = require(Storage:WaitForChild("EquipmentConfig"))
local Juice = require(Storage:WaitForChild("JuiceConfig"))
local JuiceModels = require(Storage:WaitForChild("JuiceModels"))
local GameAudio = require(Storage:WaitForChild("GameAudio"))
GameAudio.Preload({"JuiceDrink", "JuiceActivate"})
local EquipRemote = Storage:WaitForChild("EquipmentUpgrade")
local UI = require(script.Parent:WaitForChild("UICommon"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))

local JUICE_ICON = "rbxassetid://15403270948"
local TAB_WIDTH, TAB_HEIGHT, TAB_GAP = 150, 104, 14
local TAB_OVERHANG = 70 -- how far the tabs stick out left of the window
local CARD_SIZE, CARD_GAP = 124, 16
-- Inside the window, content starts clear of the tabs that overlap its left edge.
local CONTENT_LEFT = TAB_WIDTH - TAB_OVERHANG + 22
local TABS = {
 {id = "Bat", label = "Bats"},
 {id = "Ball", label = "Balls"},
 {id = "Juice", label = "Juice"},
}
-- Where each category's published models are (ItemDisplay.PublishItemModels).
local MODEL_FOLDERS = {Bat = "BatModels", Ball = "BallModels"}
-- The multiplier's icon: Balls multiply Power, Bats multiply Cash.
local VALUE_ICONS = {Bat = UI.Icons.Cash, Ball = UI.Icons.Power, Power = UI.Icons.Power, Cash = UI.Icons.Cash}

local _, panel, show, window = UI.ShowcaseMenu("InventoryGui", "My Bats", Interfaces.CloseAll,
 {maxWidth = 900, maxHeight = 620, boxLeft = TAB_OVERHANG, theme = "Blue"})
local visible, selected = false, "Bat"

local function corner(parent, radius)
 local object = Instance.new("UICorner")
 object.CornerRadius, object.Parent = UDim.new(0, radius), parent
end

local function outline(parent, color, thickness)
 local object = Instance.new("UIStroke")
 object.Color, object.Thickness, object.ApplyStrokeMode = color, thickness, Enum.ApplyStrokeMode.Border
 object.Parent = parent
 return object
end

-- A ViewportFrame showing a model, fitted to its frame. Bats lean diagonally like the reference
-- icons; balls face the camera.
local function viewport(parent, model, kind)
 local frame = Instance.new("ViewportFrame")
 frame.Name, frame.BackgroundTransparency = "Icon", 1
 frame.Ambient, frame.LightColor, frame.LightDirection = Color3.fromRGB(200, 200, 200), Color3.new(1, 1, 1), Vector3.new(-1, -1.5, -1)
 local clone = model:Clone()
 clone:PivotTo(kind == "Bat" and CFrame.Angles(0, 0, math.rad(-45)) or CFrame.Angles(math.rad(10), math.rad(-20), 0))
 clone.Parent = frame
 local box, size = clone:GetBoundingBox()
 local camera = Instance.new("Camera")
 camera.FieldOfView = 30
 local reach = math.max(size.X, size.Y) / 2 / math.tan(math.rad(camera.FieldOfView / 2)) * 1.12 + size.Z / 2
 camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0, 0, reach), box.Position)
 camera.Parent, frame.CurrentCamera = frame, camera
 frame.Parent = parent
 return frame
end

-- A simple bat or ball built from parts, for the tabs and for items with no designed model.
local function partModel(kind, color)
 local model = Instance.new("Model")
 local function part(shape, size, cframe, partColor)
  local object = Instance.new("Part")
  object.Shape, object.Size, object.CFrame, object.Color = shape, size, cframe, partColor
  object.Material, object.Anchored, object.Parent = Enum.Material.SmoothPlastic, true, model
 end
 if kind == "Bat" then
  local wood = color or Color3.fromRGB(196, 140, 80)
  local up = CFrame.Angles(0, 0, math.pi / 2)
  part(Enum.PartType.Cylinder, Vector3.new(2.3, .62, .62), CFrame.new(0, 2.2, 0) * up, wood)
  part(Enum.PartType.Cylinder, Vector3.new(1.9, .32, .32), CFrame.new(0, .2, 0) * up, wood)
  part(Enum.PartType.Cylinder, Vector3.new(.18, .5, .5), CFrame.new(0, -.8, 0) * up, Color3.fromRGB(120, 80, 45))
 else
  part(Enum.PartType.Ball, Vector3.one * 2, CFrame.new(), color or Color3.fromRGB(250, 250, 245))
  -- Two thin discs read as the red stitched seams.
  for _, angle in {.5, -.5} do
   part(Enum.PartType.Cylinder, Vector3.new(.05, 2.04, 2.04), CFrame.Angles(0, math.pi / 2 + angle, .35), Color3.fromRGB(220, 40, 50))
  end
 end
 return model
end

-- The picture of an item: its designed model when published, otherwise a plain stand-in in the
-- item's colour.
local function itemPicture(parent, category, item)
 local folder = Storage:FindFirstChild(MODEL_FOLDERS[category])
 local model = folder and folder:FindFirstChild(item.id)
 local appearance = item.appearance
 local color = typeof(appearance) == "table" and typeof(appearance.color) == "Color3" and appearance.color or nil
 return viewport(parent, model or partModel(category, color), category)
end

local function tabPicture(parent, id)
 if id == "Juice" then return UI.Icon(parent, "Icon", JUICE_ICON) end
 return viewport(parent, partModel(id), id)
end

local function pressable(button, visual)
 local scale = Instance.new("UIScale")
 scale.Name, scale.Parent = "ButtonScale", visual
 local function animate(value, style, duration)
  TweenService:Create(scale, TweenInfo.new(duration or .08, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = value}):Play()
 end
 button.MouseEnter:Connect(function() animate(1.05) end)
 button.MouseLeave:Connect(function() animate(1) end)
 button.MouseButton1Down:Connect(function() animate(.94, Enum.EasingStyle.Quad, .05) end)
 button.MouseButton1Up:Connect(function() animate(1.05, Enum.EasingStyle.Back, .12) end)
end

-- Tabs down the left, sticking out of the window: a picture over the tab's name. The selected
-- tab turns blue.
local TINT = window.theme.tint
local TAB_IDLE = {TINT:Lerp(Color3.new(1, 1, 1), .1), TINT:Lerp(Color3.new(0, 0, 0), .35)}
local TAB_SELECTED = {Color3.fromRGB(120, 225, 255), Color3.fromRGB(40, 160, 235)}
local tabButtons = {}
for index, tab in TABS do
 local button = Instance.new("TextButton")
 button.Name, button.Text, button.AutoButtonColor, button.BackgroundTransparency = tab.id .. "Tab", "", false, 1
 button.ZIndex, button.Parent = 8, panel
 local visual = Instance.new("Frame")
 visual.Name, visual.AnchorPoint, visual.Position = "Visual", Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
 visual.Size, visual.BorderSizePixel, visual.BackgroundColor3 = UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1)
 visual.ZIndex, visual.Parent = 8, button
 corner(visual, 10)
 outline(visual, UI.Showcase.Outline, 4)
 local gradient = UI.Gradient(visual, TAB_IDLE[1], TAB_IDLE[2])
 local highlight = Instance.new("Frame")
 highlight.Name, highlight.BackgroundTransparency, highlight.AnchorPoint = "Highlight", 1, Vector2.new(.5, .5)
 highlight.Position, highlight.Size, highlight.ZIndex = UDim2.fromScale(.5, .5), UDim2.new(1, -6, 1, -6), 9
 corner(highlight, 8)
 local highlightStroke = outline(highlight, Color3.new(1, 1, 1), 3)
 highlight.Parent = visual
 local icon = tabPicture(visual, tab.id)
 icon.AnchorPoint, icon.Position, icon.Size, icon.ZIndex = Vector2.new(.5, 0), UDim2.new(.5, 0, 0, 4), UDim2.new(.62, 0, .62, 0), 10
 local label = UI.ShowcaseLabel(visual, "Label", tab.label, 38)
 label.AnchorPoint, label.Position, label.Size = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -2), UDim2.new(1, -8, .42, 0)
 label.TextXAlignment, label.TextScaled, label.ZIndex = Enum.TextXAlignment.Center, true, 11
 pressable(button, visual)
 tabButtons[tab.id] = {button = button, gradient = gradient, highlight = highlightStroke, index = index}
end

-- Inside the window: the count ("3 / 10 Bats") and the dark well holding the item grid.
local countLabel = UI.ShowcaseLabel(window.box, "Count", "", 34)
countLabel.Position, countLabel.Size = UDim2.fromOffset(CONTENT_LEFT + 16, 28), UDim2.new(1, -CONTENT_LEFT - 110, 0, 42)
countLabel.TextScaled = true
local countSize = Instance.new("UITextSizeConstraint")
countSize.MaxTextSize, countSize.Parent = 34, countLabel
local well = UI.ShowcaseFrame(window.box, "Items", window.theme.well, 18)
well.Position, well.Size = UDim2.fromOffset(CONTENT_LEFT, 78), UDim2.new(1, -CONTENT_LEFT - 24, 1, -100)
local grid = Instance.new("ScrollingFrame")
grid.Name, grid.BackgroundTransparency, grid.BorderSizePixel = "Grid", 1, 0
grid.Position, grid.Size = UDim2.fromOffset(6, 6), UDim2.new(1, -12, 1, -12)
grid.ScrollBarThickness, grid.ScrollBarImageColor3 = 8, UI.Showcase.CardLight
grid.CanvasSize, grid.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
grid.Parent = well
local layout = Instance.new("UIGridLayout")
layout.CellSize, layout.CellPadding = UDim2.fromOffset(CARD_SIZE, CARD_SIZE), UDim2.fromOffset(CARD_GAP, CARD_GAP)
layout.SortOrder, layout.Parent = Enum.SortOrder.LayoutOrder, grid
local padding = Instance.new("UIPadding")
for _, side in {"PaddingTop", "PaddingLeft", "PaddingRight", "PaddingBottom"} do padding[side] = UDim.new(0, 26) end
padding.Parent = grid
local emptyLabel = UI.ShowcaseLabel(well, "Empty", "", 28, Color3.fromRGB(200, 204, 214))
emptyLabel.AnchorPoint, emptyLabel.Position, emptyLabel.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.new(1, -60, 0, 100)
emptyLabel.TextXAlignment, emptyLabel.TextWrapped = Enum.TextXAlignment.Center, true

-- Short windows shrink the tabs so all three always fit beside the window.
local function layoutTabs()
 local top = window.top + 30
 local height = math.clamp((panel.Size.Y.Offset - top - 20 - TAB_GAP * (#TABS - 1)) / #TABS, 70, TAB_HEIGHT)
 for _, tab in tabButtons do
  tab.button.Position = UDim2.fromOffset(4, top + (tab.index - 1) * (height + TAB_GAP))
  tab.button.Size = UDim2.fromOffset(TAB_WIDTH, height)
 end
end
panel:GetPropertyChangedSignal("Size"):Connect(layoutTabs)
layoutTabs()

local function formatTime(seconds)
 seconds = math.max(0, math.ceil(seconds))
 local hours, minutes, secs = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
 return hours > 0 and string.format("%d:%02d:%02d", hours, minutes, secs) or string.format("%d:%02d", minutes, secs)
end

local function multiplier(value)
 return "x" .. (value >= 100 and UI.Compact(value) or (string.format("%.2f", value):gsub("%.?0+$", "")))
end

local function folderValue(folderName, id)
 local folder = Player:FindFirstChild(folderName)
 return folder and folder:GetAttribute(id)
end

-- A green round badge with a white tick, on the equipped card's top-right corner.
local function tick(parent)
 local badge = Instance.new("Frame")
 badge.Name, badge.AnchorPoint, badge.Position = "Equipped", Vector2.new(.5, .5), UDim2.new(1, -14, 0, 14)
 badge.Size, badge.BorderSizePixel, badge.BackgroundColor3, badge.ZIndex = UDim2.fromOffset(38, 38), 0, Color3.new(1, 1, 1), 5
 corner(badge, 19)
 outline(badge, UI.Showcase.Outline, 3)
 UI.Gradient(badge, Color3.fromRGB(110, 230, 80), Color3.fromRGB(40, 170, 50))
 for _, stroke in {{Vector2.new(-6, 4), 10, 45}, {Vector2.new(4, 0), 20, -50}} do
  local bar = Instance.new("Frame")
  bar.AnchorPoint, bar.BorderSizePixel, bar.BackgroundColor3 = Vector2.new(.5, .5), 0, Color3.new(1, 1, 1)
  bar.Position, bar.Size, bar.Rotation, bar.ZIndex = UDim2.new(.5, stroke[1].X, .5, stroke[1].Y), UDim2.fromOffset(stroke[2], 5), stroke[3], 6
  corner(bar, 2)
  bar.Parent = badge
 end
 badge.Parent = parent
end

-- One item card: the picture, the multiplier along the bottom (icon + green value), an optional
-- note on top (a juice count or time left), and a blue frame and tick when equipped/active.
local function card(order, name, picture, valueIcon, valueText, note, highlighted, onClick)
 local button = Instance.new("TextButton")
 button.Name, button.Text, button.AutoButtonColor, button.BackgroundTransparency = name, "", false, 1
 button.LayoutOrder, button.Parent = order, grid
 local visual = Instance.new("Frame")
 visual.Name, visual.AnchorPoint, visual.Position = "Visual", Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
 visual.Size, visual.BorderSizePixel, visual.BackgroundColor3 = UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1)
 visual.Parent = button
 corner(visual, 12)
 outline(visual, highlighted and UI.Showcase.Selected or TINT:Lerp(Color3.new(1, 1, 1), .45), highlighted and 5 or 4)
 UI.Gradient(visual, TINT:Lerp(Color3.new(1, 1, 1), .08), TINT:Lerp(Color3.new(0, 0, 0), .3))
 local image = picture(visual)
 image.AnchorPoint, image.Position, image.Size, image.ZIndex = Vector2.new(.5, .5), UDim2.fromScale(.5, .4), UDim2.fromScale(.86, .86), 2
 local value = Instance.new("Frame")
 value.Name, value.BackgroundTransparency, value.ZIndex = "Value", 1, 3
 value.AnchorPoint, value.Position, value.Size = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -4), UDim2.new(1, -8, .32, 0)
 value.Parent = visual
 local row = Instance.new("UIListLayout")
 row.FillDirection, row.HorizontalAlignment, row.VerticalAlignment = Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center
 row.SortOrder, row.Padding, row.Parent = Enum.SortOrder.LayoutOrder, UDim.new(0, 2), value
 local icon = UI.Icon(value, "Icon", valueIcon)
 icon.Size, icon.ZIndex, icon.LayoutOrder = UDim2.fromOffset(34, 34), 4, 1
 local text = UI.ShowcaseLabel(value, "Amount", valueText, 32, UI.Showcase.Value)
 text.AutomaticSize, text.Size, text.ZIndex, text.LayoutOrder = Enum.AutomaticSize.X, UDim2.fromOffset(0, 36), 4, 2
 if note then
  local noteLabel = UI.ShowcaseLabel(visual, "Note", note, 22, Color3.fromRGB(255, 220, 90))
  noteLabel.Position, noteLabel.Size, noteLabel.ZIndex = UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 24), 5
 end
 if highlighted then tick(visual) end
 pressable(button, visual)
 button.Activated:Connect(onClick)
end

local function clearGrid()
 for _, child in grid:GetChildren() do
  if child:IsA("GuiObject") then child:Destroy() end
 end
end

local function buildEquipment(category)
 local definition = Equipment.Categories[category]
 local equippedId = Player:GetAttribute("Equipped" .. category)
 local items, ownedCount = Equipment.GetItems(category), 0
 for _, item in items do
  if folderValue(definition.ownedField, item.id) == true then
   ownedCount += 1
   local equipped = item.id == equippedId
   local value = category == "Bat" and item.cashMultiplier or item.powerGainMultiplier
   card(item.order, item.id, function(parent) return itemPicture(parent, category, item) end, VALUE_ICONS[category],
    multiplier(value), nil, equipped, function()
     if equipped then return end
     EquipRemote:FireServer("Equip", category, item.id)
    end)
  end
 end
 countLabel.Text = ownedCount .. " / " .. #items .. " " .. definition.displayName
 emptyLabel.Visible = ownedCount == 0
 emptyLabel.Text = "Buy " .. string.lower(definition.displayName) .. " at the displays in each World!"
end

-- The juice box model, turned a little so its side shows (JuiceModels builds it facing -Z).
local function juicePicture(parent, definition)
 local frame = Instance.new("ViewportFrame")
 frame.Name, frame.BackgroundTransparency = "Icon", 1
 frame.Ambient, frame.LightColor, frame.LightDirection = Color3.fromRGB(205, 205, 205), Color3.new(1, 1, 1), Vector3.new(-1, -1.5, 1)
 local model = JuiceModels.Build(definition)
 model:PivotTo(CFrame.Angles(0, math.rad(-28), 0))
 model.Parent = frame
 local box, size = model:GetBoundingBox()
 local camera = Instance.new("Camera")
 camera.FieldOfView = 30
 local reach = math.max(size.X, size.Y) / 2 / math.tan(math.rad(camera.FieldOfView / 2)) * 1.08 + size.Z / 2
 camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0, size.Y * .12, -reach), box.Position)
 camera.Parent, frame.CurrentCamera = frame, camera
 frame.Parent = parent
 return frame
end

-- Running juices' timer labels, ticked once a second while the Juice tab is open.
local juiceTimers = {}
local juiceRemote
local JUICE_CARD = Vector2.new(300, 160)

-- One juice card: the box, its name, effect and duration, the count owned, the time left while it
-- runs, and USE (grey with none owned; the server checks the count either way).
local function juiceCard(definition, owned, expiresAt)
 local active = Juice.GetRemaining(expiresAt, workspace:GetServerTimeNow()) > 0
 local frame = Instance.new("Frame")
 frame.Name, frame.LayoutOrder, frame.BackgroundColor3, frame.BorderSizePixel = definition.id, definition.order, Color3.new(1, 1, 1), 0
 corner(frame, 12)
 outline(frame, active and UI.Showcase.Selected or TINT:Lerp(Color3.new(1, 1, 1), .45), active and 5 or 4)
 UI.Gradient(frame, TINT:Lerp(Color3.new(1, 1, 1), .08), TINT:Lerp(Color3.new(0, 0, 0), .3))
 frame.Parent = grid
 local picture = juicePicture(frame, definition)
 picture.AnchorPoint, picture.Position, picture.Size, picture.ZIndex = Vector2.new(0, .5), UDim2.new(0, 4, .5, 0), UDim2.fromOffset(122, 140), 2
 local function line(name, text, size, color, y)
  local label = UI.ShowcaseLabel(frame, name, text, size, color)
  label.Position, label.Size, label.ZIndex, label.TextScaled = UDim2.fromOffset(128, y), UDim2.new(1, -136, 0, size + 4), 3, true
  local limit = Instance.new("UITextSizeConstraint")
  limit.MaxTextSize, limit.Parent = size, label
  return label
 end
 line("Name", definition.displayName, 30, UI.Colors.Text, 10)
 line("Effect", string.format("%gx %s • %d min", definition.multiplier, Juice.Effects[definition.effect].displayName,
  definition.durationSeconds / 60), 22, UI.Showcase.Value, 46)
 line("Owned", "Owned: " .. UI.Number(owned), 22, owned > 0 and UI.Colors.Text or UI.Colors.Locked, 76)
 if active then
  -- The time left, across the bottom of the box picture.
  local timer = line("Timer", "", 22, Color3.fromRGB(255, 220, 90), 0)
  timer.AnchorPoint, timer.Position, timer.Size = Vector2.new(0, 1), UDim2.new(0, 6, 1, -6), UDim2.fromOffset(118, 26)
  timer.TextXAlignment, timer.ZIndex = Enum.TextXAlignment.Center, 4
  table.insert(juiceTimers, {label = timer, expiresAt = expiresAt})
 end
 local use = UI.Button(frame, "Use", "USE")
 use.AnchorPoint, use.Position, use.Size, use.ZIndex = Vector2.new(1, 1), UDim2.new(1, -10, 1, -10), UDim2.fromOffset(104, 44), 3
 use.TextSize = 24
 UI.SetButton(use, "USE", owned > 0, true)
 use.Activated:Connect(function()
  if owned < 1 or not juiceRemote then return end
  juiceRemote:FireServer("Use", definition.id)
 end)
end

local function tickJuiceTimers()
 local now = workspace:GetServerTimeNow()
 for _, timer in juiceTimers do
  local remaining = Juice.GetRemaining(timer.expiresAt, now)
  timer.label.Text = remaining > 0 and "ACTIVE " .. formatTime(remaining) or ""
 end
end

local function buildJuice()
 local ownedTotal = 0
 table.clear(juiceTimers)
 for _, definition in Juice.GetAll() do
  local owned = folderValue("OwnedJuices", definition.id) or 0
  ownedTotal += owned
  juiceCard(definition, owned, folderValue("ActiveJuices", definition.id))
 end
 tickJuiceTimers()
 countLabel.Text = UI.Number(ownedTotal) .. " Juice"
 emptyLabel.Visible = false
end

local function refresh()
 if not visible then return end
 for id, tab in tabButtons do
  local colors = id == selected and TAB_SELECTED or TAB_IDLE
  tab.gradient.Color = ColorSequence.new(colors[1], colors[2])
  tab.highlight.Enabled = id == selected
 end
 local label = selected == "Juice" and "Juice" or Equipment.Categories[selected].displayName
 window.title.Text = "My " .. label
 window.titleIcon:ClearAllChildren()
 local titleIcon = tabPicture(window.titleIcon, selected)
 titleIcon.Size, titleIcon.Rotation, titleIcon.ZIndex = UDim2.fromScale(1, 1), -15, 6
 clearGrid()
 -- Juice cards are wider, with their details beside the box.
 layout.CellSize = selected == "Juice" and UDim2.fromOffset(JUICE_CARD.X, JUICE_CARD.Y) or UDim2.fromOffset(CARD_SIZE, CARD_SIZE)
 if selected == "Juice" then buildJuice() else table.clear(juiceTimers) buildEquipment(selected) end
end

for id, tab in tabButtons do
 tab.button.Activated:Connect(function()
  if selected == id then return end
  selected = id
  grid.CanvasPosition = Vector2.zero
  refresh()
 end)
end

Interfaces.Register("Inventory", function(open)
 visible = open
 show(open)
 if open then refresh() end
end)

-- Keep the open inventory in sync with server-replicated ownership, equips, and juice timers.
local watched = {OwnedBats = true, OwnedBalls = true, OwnedJuices = true, ActiveJuices = true}
local function watch(child)
 if watched[child.Name] then child.AttributeChanged:Connect(refresh) end
end
Player.ChildAdded:Connect(watch)
for _, child in Player:GetChildren() do watch(child) end
for _, attribute in {"EquippedBat", "EquippedBall"} do Player:GetAttributeChangedSignal(attribute):Connect(refresh) end

task.spawn(function()
 while true do
  task.wait(1)
  if visible and selected == "Juice" then tickJuiceTimers() end
 end
end)

task.spawn(function()
 juiceRemote = Storage:WaitForChild("JuiceRequest")
 juiceRemote.OnClientEvent:Connect(function(success, message)
  if type(message) ~= "string" then return end
  if success then GameAudio.Play("JuiceDrink") end
  UI.Notify(message, success and "success" or "error")
 end)
end)
