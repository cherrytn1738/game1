-- Inventory: browse Bats and Balls (equip from here) and Juice (drink from here).
-- Presentation and intent only; the server validates every equip and juice use.
local Player = game.Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local Storage = game:GetService("ReplicatedStorage")
local Equipment = require(Storage:WaitForChild("EquipmentConfig"))
local Juice = require(Storage:WaitForChild("JuiceConfig"))
local EquipRemote = Storage:WaitForChild("EquipmentUpgrade")
local UI = require(script.Parent:WaitForChild("UICommon"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))

-- Card borders/names by tier (item order in its category), like rarity colours.
local TIER_COLORS = {Color3.fromRGB(190, 200, 210), Color3.fromRGB(70, 150, 255), Color3.fromRGB(175, 90, 255), Color3.fromRGB(255, 200, 40)}
local LOCK_ICON = "rbxassetid://17368080973"
local JUICE_ICON = "rbxassetid://15403270948"
local TAB_WIDTH, TAB_HEIGHT, GAP = 112, 96, 10
local CARD_HEIGHT = 86
local TABS = {
 {id = "Bat", label = "Bats"},
 {id = "Ball", label = "Balls"},
 {id = "Juice", label = "Juice"},
}

local gui, panel, show = UI.Menu("InventoryGui", "Inventory", "", Interfaces.CloseAll)
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

-- Small 3D previews built from parts, so the tabs show an actual bat and ball.
local function modelIcon(parent, kind)
 local viewport = Instance.new("ViewportFrame")
 viewport.Name, viewport.BackgroundTransparency = "Icon", 1
 viewport.Ambient, viewport.LightColor, viewport.LightDirection = Color3.fromRGB(190, 190, 190), Color3.new(1, 1, 1), Vector3.new(-1, -1, -1)
 local model = Instance.new("Model")
 model.Parent = viewport
 local function part(shape, size, cframe, color)
  local object = Instance.new("Part")
  object.Shape, object.Size, object.CFrame, object.Color = shape, size, cframe, color
  object.Material, object.Anchored, object.Parent = Enum.Material.SmoothPlastic, true, model
 end
 if kind == "Bat" then
  local wood = Color3.fromRGB(196, 140, 80)
  local tilt = CFrame.Angles(0, 0, math.rad(50))
  part(Enum.PartType.Cylinder, Vector3.new(2.3, .62, .62), tilt * CFrame.new(.9, 0, 0), wood)
  part(Enum.PartType.Cylinder, Vector3.new(1.9, .32, .32), tilt * CFrame.new(-1.1, 0, 0), wood)
  part(Enum.PartType.Cylinder, Vector3.new(.18, .5, .5), tilt * CFrame.new(-2.1, 0, 0), Color3.fromRGB(120, 80, 45))
 else
  part(Enum.PartType.Ball, Vector3.one * 2, CFrame.new(), Color3.fromRGB(250, 250, 245))
  -- Two thin discs read as the red stitched seams.
  for _, angle in {.5, -.5} do
   part(Enum.PartType.Cylinder, Vector3.new(.05, 2.04, 2.04), CFrame.Angles(0, math.pi / 2 + angle, .35), Color3.fromRGB(220, 40, 50))
  end
 end
 local camera = Instance.new("Camera")
 -- Close framing so each model fills its tab icon.
 camera.FieldOfView, camera.CFrame = 40, CFrame.lookAt(Vector3.new(0, 0, kind == "Bat" and 4.8 or 3.3), Vector3.zero)
 camera.Parent, viewport.CurrentCamera = viewport, camera
 viewport.Parent = parent
 return viewport
end

local function pressable(button, visual)
 local scale = Instance.new("UIScale")
 scale.Name, scale.Parent = "ButtonScale", visual
 local function animate(value, style, duration)
  TweenService:Create(scale, TweenInfo.new(duration or .08, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = value}):Play()
 end
 button.MouseEnter:Connect(function() animate(1.04) end)
 button.MouseLeave:Connect(function() animate(1) end)
 button.MouseButton1Down:Connect(function() animate(.95, Enum.EasingStyle.Quad, .05) end)
 button.MouseButton1Up:Connect(function() animate(1.04, Enum.EasingStyle.Back, .12) end)
end

-- Left column of tabs.
local tabButtons = {}
for index, tab in TABS do
 local button = Instance.new("TextButton")
 button.Name, button.Text, button.AutoButtonColor, button.BackgroundTransparency = tab.id .. "Tab", "", false, 1
 button.Position, button.Size = UDim2.fromOffset(12, 76 + (index - 1) * (TAB_HEIGHT + GAP)), UDim2.fromOffset(TAB_WIDTH, TAB_HEIGHT)
 button.Parent = panel
 local visual = Instance.new("Frame")
 visual.Name, visual.AnchorPoint, visual.Position = "Visual", Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
 visual.Size, visual.BorderSizePixel, visual.BackgroundColor3 = UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1)
 visual.Parent = button
 corner(visual, 8)
 outline(visual, Color3.new(0, 0, 0), 2.8)
 local gradient = UI.Gradient(visual, UI.ButtonStates.Claimed[1], UI.ButtonStates.Claimed[2])
 UI.Damier(visual, Color3.new(0, 0, 0), 18, NumberSequence.new(.92, .72))
 local icon = tab.id == "Juice" and UI.Icon(visual, "Icon", JUICE_ICON) or modelIcon(visual, tab.id)
 icon.AnchorPoint, icon.Position, icon.Size, icon.ZIndex = Vector2.new(.5, 0), UDim2.new(.5, 0, 0, 6), UDim2.fromOffset(58, 58), 2
 local label = UI.Label(visual, "Label", tab.label, 22)
 label.AnchorPoint, label.Position, label.Size = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -4), UDim2.new(1, -6, 0, 28)
 label.TextXAlignment, label.ZIndex = Enum.TextXAlignment.Center, 3
 pressable(button, visual)
 tabButtons[tab.id] = {button = button, gradient = gradient}
end

-- Right side: counters, item grid, feedback line.
local contentX = 12 + TAB_WIDTH + 12
local countLabel = UI.Label(panel, "Count", "", 20)
countLabel.Position, countLabel.Size = UDim2.fromOffset(contentX + 4, 72), UDim2.new(.5, -contentX / 2, 0, 30)
local statusLabel = UI.Label(panel, "Status", "", 18, UI.Colors.Muted)
statusLabel.AnchorPoint, statusLabel.Position, statusLabel.Size = Vector2.new(1, 0), UDim2.new(1, -16, 0, 72), UDim2.new(.5, -contentX / 2, 0, 30)
statusLabel.TextXAlignment = Enum.TextXAlignment.Right
local well = UI.Surface(panel, "Items", UI.Colors.Card)
well.Position, well.Size = UDim2.fromOffset(contentX, 106), UDim2.new(1, -contentX - 12, 1, -148)
local grid = Instance.new("ScrollingFrame")
grid.Name, grid.BackgroundTransparency, grid.BorderSizePixel = "Grid", 1, 0
grid.Position, grid.Size = UDim2.fromOffset(10, 10), UDim2.new(1, -20, 1, -20)
grid.ScrollBarThickness, grid.ScrollBarImageColor3 = 6, Color3.fromRGB(85, 140, 160)
grid.CanvasSize, grid.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
grid.ZIndex, grid.Parent = 2, well
local layout = Instance.new("UIGridLayout")
layout.CellPadding, layout.SortOrder = UDim2.fromOffset(10, 10), Enum.SortOrder.LayoutOrder
layout.Parent = grid
local padding = Instance.new("UIPadding")
padding.PaddingTop, padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 4)
padding.Parent = grid
local emptyLabel = UI.Label(well, "Empty", "", 18, UI.Colors.Muted)
emptyLabel.AnchorPoint, emptyLabel.Position, emptyLabel.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.new(1, -40, 0, 80)
emptyLabel.TextXAlignment, emptyLabel.TextWrapped, emptyLabel.ZIndex = Enum.TextXAlignment.Center, true, 3
local feedback = UI.Label(panel, "Feedback", "", 15, UI.Colors.Muted)
feedback.Position, feedback.Size = UDim2.new(0, contentX + 4, 1, -38), UDim2.new(1, -contentX - 16, 0, 28)

-- Short windows shrink the tabs so all three always fit.
local function layoutTabs()
 local height = math.clamp((panel.Size.Y.Offset - 76 - 14 - GAP * (#TABS - 1)) / #TABS, 64, TAB_HEIGHT)
 for index, tab in TABS do
  local button = tabButtons[tab.id].button
  button.Position, button.Size = UDim2.fromOffset(12, 76 + (index - 1) * (height + GAP)), UDim2.fromOffset(TAB_WIDTH, height)
 end
end
panel:GetPropertyChangedSignal("Size"):Connect(layoutTabs)
layoutTabs()

local function resizeGrid()
 local width = grid.AbsoluteSize.X / math.max(panel.WindowScale.Scale, .01) - 8
 local columns = width < 330 and 2 or 3
 layout.CellSize = UDim2.fromOffset(math.max(90, math.floor((width - (columns - 1) * 10) / columns)), CARD_HEIGHT)
end
grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeGrid)

local function formatTime(seconds)
 seconds = math.max(0, math.ceil(seconds))
 local hours, minutes, secs = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
 return hours > 0 and string.format("%d:%02d:%02d", hours, minutes, secs) or string.format("%d:%02d", minutes, secs)
end

local function folderValue(folderName, id)
 local folder = Player:FindFirstChild(folderName)
 return folder and folder:GetAttribute(id)
end

-- One item card: tier-coloured border and name, an effect line, and a state line.
local function card(order, title, color, effect, state, stateColor, locked, highlighted, onClick)
 local button = Instance.new("TextButton")
 button.Name, button.Text, button.AutoButtonColor, button.BackgroundTransparency = title, "", false, 1
 button.LayoutOrder, button.Parent = order, grid
 local visual = Instance.new("Frame")
 visual.Name, visual.AnchorPoint, visual.Position = "Visual", Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
 visual.Size, visual.BorderSizePixel = UDim2.fromScale(1, 1), 0
 visual.BackgroundColor3 = highlighted and Color3.fromRGB(28, 66, 82) or Color3.fromRGB(16, 26, 32)
 visual.Parent = button
 corner(visual, 8)
 outline(visual, highlighted and UI.ButtonStates.Cyan[1] or color, 3).Transparency = locked and .45 or 0
 local name = UI.Label(visual, "Name", title, 20, locked and color:Lerp(Color3.new(.3, .3, .3), .45) or color)
 name.Position, name.Size, name.TextXAlignment = UDim2.fromOffset(8, 6), UDim2.new(1, -36, 0, 28), Enum.TextXAlignment.Center
 name.TextScaled = true
 local constraint = Instance.new("UITextSizeConstraint")
 constraint.MinTextSize, constraint.MaxTextSize, constraint.Parent = 9, 20, name
 local effectLabel = UI.Label(visual, "Effect", effect, 14, UI.ButtonStates.Claim[1])
 effectLabel.Position, effectLabel.Size, effectLabel.TextXAlignment = UDim2.fromOffset(6, 36), UDim2.new(1, -12, 0, 20), Enum.TextXAlignment.Center
 local stateLabel = UI.Label(visual, "State", state, 12, stateColor)
 stateLabel.Position, stateLabel.Size, stateLabel.TextXAlignment = UDim2.fromOffset(6, 60), UDim2.new(1, -12, 0, 18), Enum.TextXAlignment.Center
 stateLabel.TextScaled = true
 local stateSize = Instance.new("UITextSizeConstraint")
 stateSize.MinTextSize, stateSize.MaxTextSize, stateSize.Parent = 7, 12, stateLabel
 if locked then
  local lock = UI.Icon(visual, "Lock", LOCK_ICON)
  lock.AnchorPoint, lock.Position, lock.Size = Vector2.new(1, 0), UDim2.new(1, -4, 0, 4), UDim2.fromOffset(22, 22)
 end
 pressable(button, visual)
 button.Activated:Connect(onClick)
end

local function clearGrid()
 for _, child in grid:GetChildren() do
  if child:IsA("GuiButton") then child:Destroy() end
 end
end

local function equipmentEffect(category, item)
 if category == "Bat" then return UI.Number(item.powerGainMultiplier, 2) .. "x Power gain" end
 return UI.Number(item.rewardMultiplier, 2) .. "x Cash"
end

local function buildEquipment(category)
 local definition = Equipment.Categories[category]
 local equippedId = Player:GetAttribute("Equipped" .. category)
 local items, ownedCount = Equipment.GetItems(category), 0
 for _, item in items do
  local owned = folderValue(definition.ownedField, item.id) == true
  local equipped = item.id == equippedId
  if owned then ownedCount += 1 end
  local color = TIER_COLORS[math.min(item.order, #TIER_COLORS)]
  card(item.order, item.displayName, color, equipmentEffect(category, item),
   equipped and "EQUIPPED" or owned and "TAP TO EQUIP" or "BUY IN THE SHOP",
   equipped and UI.ButtonStates.Cyan[1] or owned and UI.Colors.Text or UI.Colors.Muted, not owned, equipped,
   function()
    if equipped then return end
    if not owned then
     feedback.Text, feedback.TextColor3 = "Buy " .. item.displayName .. " in the Shop first.", UI.Colors.Muted
     return
    end
    feedback.Text, feedback.TextColor3 = "Equipping " .. item.displayName .. "...", UI.Colors.Muted
    EquipRemote:FireServer("Equip", category, item.id)
   end)
 end
 local equipped = Equipment.Get(category, equippedId)
 countLabel.Text = string.upper(definition.displayName) .. " " .. ownedCount .. " / " .. #items
 statusLabel.Text = equipped and "EQUIPPED: " .. string.upper(equipped.displayName) or ""
 emptyLabel.Visible = false
end

local juiceRemote
local function buildJuice()
 local ownedTotal, activeCount, shown = 0, 0, 0
 for _, definition in Juice.GetAll() do
  local owned = folderValue("OwnedJuices", definition.id) or 0
  local remaining = folderValue("ActiveJuices", definition.id) or 0
  ownedTotal += owned
  if remaining > 0 then activeCount += 1 end
  if owned > 0 or remaining > 0 then
   shown += 1
   local effect = Juice.Effects[definition.effect]
   local stateParts = {}
   if remaining > 0 then table.insert(stateParts, formatTime(remaining) .. " LEFT") end
   if owned > 0 then table.insert(stateParts, "x" .. owned .. " · TAP TO DRINK") end
   card(definition.order, definition.displayName, definition.color or UI.Colors.Accent,
    string.format("%gx %s · %s", definition.multiplier, effect.displayName, formatTime(definition.durationSeconds)),
    table.concat(stateParts, " · "),
    remaining > 0 and UI.ButtonStates.Claim[1] or UI.Colors.Text, false, remaining > 0,
    function()
     if owned < 1 or not juiceRemote then return end
     feedback.Text, feedback.TextColor3 = "Drinking " .. definition.displayName .. "...", UI.Colors.Muted
     juiceRemote:FireServer("Use", definition.id)
    end)
  end
 end
 countLabel.Text = "JUICE " .. UI.Number(ownedTotal)
 statusLabel.Text = activeCount > 0 and activeCount .. " ACTIVE" or "NONE ACTIVE"
 emptyLabel.Text = "No juice yet!\nJuice gives temporary boosts, like 2x Power for an hour."
 emptyLabel.Visible = shown == 0
end

local function refresh()
 if not visible then return end
 for id, tab in tabButtons do
  local state = id == selected and UI.ButtonStates.Cyan or UI.ButtonStates.Claimed
  tab.gradient.Color = ColorSequence.new(state[1], state[2])
 end
 clearGrid()
 if selected == "Juice" then buildJuice() else buildEquipment(selected) end
 resizeGrid()
end

for id, tab in tabButtons do
 tab.button.Activated:Connect(function()
  if selected == id then return end
  selected = id
  feedback.Text = ""
  grid.CanvasPosition = Vector2.zero
  refresh()
 end)
end

Interfaces.Register("Inventory", function(open)
 visible = open
 show(open)
 if open then
  feedback.Text = ""
  refresh()
 end
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
 juiceRemote = Storage:WaitForChild("JuiceRequest")
 juiceRemote.OnClientEvent:Connect(function(success, message)
  if type(message) ~= "string" then return end
  if visible then
   feedback.Text, feedback.TextColor3 = message, success and UI.Colors.Success or UI.Colors.Error
  else
   UI.Notify(message, success and "success" or "error")
  end
 end)
end)
