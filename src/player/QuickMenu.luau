-- Check-UI styled HUD navigation. Icons: DevJoob's free Simulator Icon Pack
-- https://create.roblox.com/store/asset/99176447965360
local TweenService = game:GetService("TweenService")
local UI = require(script.Parent.UICommon)
local QuickMenu = {}
local BUTTON_SIZE, GAP = 108, 14
local definitions = {
 {name = "Shop", image = "rbxassetid://17368217589", accent = Color3.fromRGB(255, 77, 151)},
 {name = "Rebirth", image = "rbxassetid://17368214873", accent = Color3.fromRGB(87, 222, 255)},
 {name = "Training", image = UI.Icons.Power, accent = UI.Colors.Gold},
 -- No image: the Worlds globe is built from UI geometry by UI.WorldIcon.
 {name = "Worlds", accent = Color3.fromRGB(63, 206, 243)},
}

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

function QuickMenu.Create(parent, onActivated)
 local navigation = frame(parent, "Navigation", UDim2.fromOffset(230, 236), UDim2.new(), Color3.new(), 1)
 navigation.BackgroundTransparency = 1
 local responsiveScale = Instance.new("UIScale")
 responsiveScale.Name, responsiveScale.Parent = "ResponsiveScale", navigation
 for index, definition in definitions do
  local button = Instance.new("ImageButton")
  button.Name, button.Image, button.AutoButtonColor = definition.name, "", false
  button.AnchorPoint = Vector2.new(.5, .5)
  button.Position = UDim2.fromOffset(54 + (index-1)%2 * (BUTTON_SIZE+GAP), 54 + math.floor((index-1)/2) * (BUTTON_SIZE+GAP))
  button.Size, button.BackgroundColor3 = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE), Color3.fromRGB(24, 43, 54)
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
  local accent = frame(face, "Accent", UDim2.new(1,-16,0,5), UDim2.fromOffset(8,5), definition.accent, 4)
  corner(accent, 2)
  local icon = definition.image and Instance.new("ImageLabel") or UI.WorldIcon(face)
  icon.Name, icon.BackgroundTransparency = "Icon", 1
  if definition.image then icon.Image, icon.ScaleType = definition.image, Enum.ScaleType.Fit
  else icon.BackgroundTransparency = 0 end
  icon.AnchorPoint, icon.Position = Vector2.new(.5,0), UDim2.new(.5,0,0,13)
  icon.Size, icon.ZIndex, icon.Parent = UDim2.fromOffset(definition.image and 64 or 54,definition.image and 64 or 54), 5, face
  local label = Instance.new("TextLabel")
  label.Name, label.Text, label.Font = "Label", definition.name, Enum.Font.GothamBlack
  label.TextSize, label.TextColor3, label.BackgroundTransparency = 21, Color3.new(1,1,1), 1
  label.Size, label.Position = UDim2.new(1,-4,0,28), UDim2.new(0,2,1,-29)
  label.ZIndex, label.Parent = 6, face
  stroke(label, Color3.fromRGB(17,23,26), 2.5)
  local scale = Instance.new("UIScale")
  scale.Name, scale.Parent = "ButtonScale", button
  local tween, hovered, selected = nil, false, false
  local function animate(value)
   if tween then tween:Cancel() end
   tween = TweenService:Create(scale, TweenInfo.new(.1,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {Scale=value})
   tween:Play()
  end
  local function rest() animate((hovered or selected) and 1.04 or 1) end
  button.MouseEnter:Connect(function() hovered = true rest() end)
  button.MouseLeave:Connect(function() hovered = false rest() end)
  button.SelectionGained:Connect(function() selected = true rest() end)
  button.SelectionLost:Connect(function() selected = false rest() end)
  button.MouseButton1Down:Connect(function() animate(.95) end)
  button.MouseButton1Up:Connect(rest)
  button.Activated:Connect(function() rest() onActivated(definition.name) end)
  navigation:GetPropertyChangedSignal("Visible"):Connect(function()
   if not navigation.Visible then
    if tween then tween:Cancel() end
    hovered, selected, scale.Scale = false, false, 1
   end
  end)
 end
 return navigation
end

function QuickMenu.Resize(navigation, availableSize)
 local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or availableSize
 local scale = math.clamp(math.min(viewport.X/1050, viewport.Y/620), .52, 1.18)
 navigation.ResponsiveScale.Scale = scale
 local y = availableSize.X < 600 and 116 or math.max(16, (availableSize.Y-236*scale)*.42)
 navigation.Position = UDim2.fromOffset(14,y)
end

return QuickMenu
