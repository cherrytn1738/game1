-- Check-UI styled HUD navigation, modeled on the reference 2x2 tile menu, plus wide
-- Training teleport tile underneath (the Batting teleport sits under the level bar).
-- Icons: DevJoob's free Simulator Icon Pack https://create.roblox.com/store/asset/99176447965360
local TweenService = game:GetService("TweenService")
local UI = require(script.Parent.UICommon)
local QuickMenu = {}
local BUTTON_SIZE, GAP, WIDE_HEIGHT = 108, 14, 58
local GRID_SIZE = BUTTON_SIZE * 2 + GAP
local definitions = {
 {name = "Shop", image = UI.Icons.Shop, accent = Color3.fromRGB(255, 77, 151)},
 {name = "Rebirth", image = UI.Icons.Rebirth, accent = Color3.fromRGB(87, 190, 255)},
 {name = "Inventory", image = UI.Icons.Inventory, accent = Color3.fromRGB(176, 106, 60)},
 {name = "Rewards", image = UI.Icons.Rewards, accent = UI.Colors.Gold},
 {name = "TrainingTeleport", label = "Training", image = UI.Icons.Training, accent = Color3.fromRGB(255, 208, 0), wide = true},
}
local wideCount = 0
for _, definition in definitions do
 if definition.wide then wideCount += 1 end
end
QuickMenu.Height = GRID_SIZE + (GAP + WIDE_HEIGHT) * wideCount

local function corner(parent, radius)
 local object = Instance.new("UICorner")
 object.CornerRadius, object.Parent = UDim.new(0, radius), parent
end

local function stroke(parent, color, thickness)
 local object = Instance.new("UIStroke")
 object.Color, object.Thickness, object.Parent = color, thickness, parent
 return object
end

local function frame(parent, name, size, position, color, zIndex)
 local object = Instance.new("Frame")
 object.Name, object.Size, object.Position = name, size, position
 object.BackgroundColor3, object.BorderSizePixel = color, 0
 object.ZIndex, object.Parent = zIndex, parent
 return object
end

local function createTile(navigation, definition, center, size, onActivated)
 local button = Instance.new("ImageButton")
 button.Name, button.Image, button.AutoButtonColor = definition.name, "", false
 button.AnchorPoint, button.Position = Vector2.new(.5, .5), UDim2.fromOffset(center.X, center.Y)
 button.Size, button.BackgroundColor3 = UDim2.fromOffset(size.X, size.Y), Color3.fromRGB(24, 43, 54)
 button.BorderSizePixel, button.ZIndex, button.Parent = 0, 2, navigation
 corner(button, 13)
 stroke(button, Color3.fromRGB(12, 20, 26), 3.5)
 local face = frame(button, "Face", UDim2.new(1, 0, 1, -6), UDim2.new(), Color3.new(1,1,1), 3)
 corner(face, 12)
 stroke(face, Color3.fromRGB(24, 30, 34), 3)
 local gradient = Instance.new("UIGradient")
 gradient.Color = ColorSequence.new(Color3.fromRGB(167, 232, 255), Color3.fromRGB(102, 191, 236))
 gradient.Rotation, gradient.Parent = 90, face
 local highlight = frame(face, "InnerHighlight", UDim2.new(1,-6,1,-6), UDim2.fromOffset(3,3), Color3.new(), 4)
 highlight.BackgroundTransparency = 1
 corner(highlight, 10)
 stroke(highlight, Color3.fromRGB(220, 248, 255), 1.2)
 -- Faint texture across the face, inset so it stays inside the rounded corners.
 local texture = UI.Damier(face, Color3.new(1, 1, 1), 18, NumberSequence.new(.9, .78))
 texture.AnchorPoint, texture.Position, texture.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.new(1, -10, 1, -10)
 texture.ZIndex = 3
 local accent = frame(face, "Accent", UDim2.new(1,-16,0,5), UDim2.fromOffset(8,5), definition.accent, 4)
 corner(accent, 2)
 local icon = Instance.new("ImageLabel")
 icon.Name, icon.BackgroundTransparency = "Icon", 1
 icon.Image, icon.ScaleType = definition.image, Enum.ScaleType.Fit
 icon.ZIndex, icon.Parent = 5, face
 local label = Instance.new("TextLabel")
 label.Name, label.Text, label.Font = "Label", definition.label or definition.name, Enum.Font.GothamBlack
 label.TextColor3, label.BackgroundTransparency = Color3.new(1,1,1), 1
 label.ZIndex, label.Parent = 6, face
 stroke(label, Color3.new(0, 0, 0), 3)
 if definition.wide then
  -- Wide tile: icon on the left, label filling the rest.
  icon.AnchorPoint, icon.Position, icon.Size = Vector2.new(0, .5), UDim2.new(0, 14, .5, 2), UDim2.fromOffset(42, 42)
  label.TextSize, label.Size, label.Position = 24, UDim2.new(1, -70, 1, 0), UDim2.fromOffset(62, 2)
 else
  icon.AnchorPoint, icon.Position, icon.Size = Vector2.new(.5,0), UDim2.new(.5,0,0,12), UDim2.fromOffset(66, 66)
  label.TextSize, label.Size, label.Position = 22, UDim2.new(1,-4,0,28), UDim2.new(0,2,1,-29)
 end
 local scale = Instance.new("UIScale")
 scale.Name, scale.Parent = "ButtonScale", button
 local tween, hovered, selected = nil, false, false
 local function animate(value, style, duration)
  if tween then tween:Cancel() end
  tween = TweenService:Create(scale, TweenInfo.new(duration or .08, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale=value})
  tween:Play()
 end
 local function rest() animate((hovered or selected) and 1.05 or 1) end
 button.MouseEnter:Connect(function() hovered = true rest() end)
 button.MouseLeave:Connect(function() hovered = false rest() end)
 button.SelectionGained:Connect(function() selected = true rest() end)
 button.SelectionLost:Connect(function() selected = false rest() end)
 button.MouseButton1Down:Connect(function() animate(.94, Enum.EasingStyle.Quad, .05) end)
 button.MouseButton1Up:Connect(function() animate((hovered or selected) and 1.05 or 1, Enum.EasingStyle.Back, .12) end)
 button.Activated:Connect(function() rest() onActivated(definition.name) end)
 navigation:GetPropertyChangedSignal("Visible"):Connect(function()
  if not navigation.Visible then
   if tween then tween:Cancel() end
   hovered, selected, scale.Scale = false, false, 1
  end
 end)
end

function QuickMenu.Create(parent, onActivated)
 local navigation = frame(parent, "Navigation", UDim2.fromOffset(GRID_SIZE + 2, QuickMenu.Height + 2), UDim2.new(), Color3.new(), 1)
 navigation.BackgroundTransparency = 1
 local responsiveScale = Instance.new("UIScale")
 responsiveScale.Name, responsiveScale.Parent = "ResponsiveScale", navigation
 local gridIndex, wideIndex = 0, 0
 for _, definition in definitions do
  if definition.wide then
   wideIndex += 1
   createTile(navigation, definition, Vector2.new(GRID_SIZE / 2 + 1, GRID_SIZE + wideIndex * GAP + (wideIndex - 0.5) * WIDE_HEIGHT),
    Vector2.new(GRID_SIZE, WIDE_HEIGHT), onActivated)
  else
   gridIndex += 1
   local column, row = (gridIndex - 1) % 2, math.floor((gridIndex - 1) / 2)
   createTile(navigation, definition, Vector2.new(BUTTON_SIZE / 2 + 1 + column * (BUTTON_SIZE + GAP), BUTTON_SIZE / 2 + 1 + row * (BUTTON_SIZE + GAP)),
    Vector2.new(BUTTON_SIZE, BUTTON_SIZE), onActivated)
  end
 end
 return navigation
end

function QuickMenu.Resize(navigation, availableSize)
 local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or availableSize
 -- Floor keeps tiles large enough to tap on small phones.
 local scale = math.max(.45, math.clamp(math.min(viewport.X/1050, viewport.Y/620), .52, 1.18) * UI.SizeScale)
 navigation.ResponsiveScale.Scale = scale
 local y = availableSize.X < 600 and 96 or math.max(12, (availableSize.Y - QuickMenu.Height * scale) * .42)
 navigation.Position = UDim2.fromOffset(12, y)
end

return QuickMenu
