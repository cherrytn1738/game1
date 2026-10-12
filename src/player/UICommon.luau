-- Shared presentation helpers. No gameplay state or authoritative calculations.
local TweenService = game:GetService("TweenService")
local player = game.Players.LocalPlayer
local UI = {}
local PANEL_TRANSPARENCY = 0.7 -- 30% opaque: readable while the world remains visible.
local buttonVisuals = {}
local tintTweens = {}
local function cancelTint(button)
 local tween = tintTweens[button]
 if not tween then return end
 tintTweens[button] = nil
 tween:Cancel()
 tween:Destroy()
end
UI.Font = Enum.Font.GothamBlack
UI.Colors = {
 Panel = Color3.fromRGB(25, 65, 91), Card = Color3.fromRGB(35, 77, 103),
 Border = Color3.fromRGB(24, 30, 34), Text = Color3.fromRGB(255, 255, 255),
 Muted = Color3.fromRGB(207, 219, 237), Accent = Color3.fromRGB(34, 173, 255),
 Gold = Color3.fromRGB(255, 212, 49), Error = Color3.fromRGB(255, 76, 99),
 Success = Color3.fromRGB(107, 228, 72), Locked = Color3.fromRGB(92, 103, 124),
}
UI.Icons = {
 Power = "rbxassetid://17368078790", Cash = "rbxassetid://88694661500877",
 Rebirth = "rbxassetid://17368214873", Shop = "rbxassetid://17368217589",
}

function UI.Icon(parent, name, image)
 local icon = Instance.new("ImageLabel")
 icon.Name, icon.Image, icon.BackgroundTransparency = name,image,1
 icon.ScaleType, icon.Parent = Enum.ScaleType.Fit,parent
 return icon
end

function UI.WorldIcon(parent)
 local globe = Instance.new("Frame",parent)
 globe.Name, globe.BackgroundColor3, globe.BorderSizePixel = "Globe",Color3.fromRGB(63,206,243),0
 Instance.new("UICorner",globe).CornerRadius=UDim.new(1,0)
 local outline=Instance.new("UIStroke",globe)
 outline.Color,outline.Thickness=UI.Colors.Border,3
 for _,size in {UDim2.fromScale(.45,1),UDim2.fromScale(1,.42)} do
  local line=Instance.new("Frame",globe)
  line.AnchorPoint,line.Position,line.Size=Vector2.new(.5,.5),UDim2.fromScale(.5,.5),size
  line.BackgroundTransparency=1
  Instance.new("UICorner",line).CornerRadius=UDim.new(1,0)
  local stroke=Instance.new("UIStroke",line)
  stroke.Color,stroke.Thickness=Color3.fromRGB(22,88,127),2
 end
 return globe
end

-- Decorative layers never handle input or gameplay state.
local function checker(parent)
 local image = Instance.new("ImageLabel")
 image.Name, image.BackgroundTransparency = "Checkerboard", 1
 image.Size, image.Image = UDim2.fromScale(1,1), "rbxassetid://385956923"
 image.ScaleType, image.TileSize = Enum.ScaleType.Tile, UDim2.fromOffset(20,20)
 image.ImageColor3, image.Parent = Color3.new(0,0,0), parent
 local fade = Instance.new("UIGradient",image)
 fade.Rotation = 90
 fade.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.35,.94),NumberSequenceKeypoint.new(.7,.85),NumberSequenceKeypoint.new(1,.72)})
 return image
end

function UI.Gradient(parent, top, bottom)
 local gradient = Instance.new("UIGradient",parent)
 gradient.Rotation, gradient.Color = 90, ColorSequence.new(top,bottom)
 return gradient
end
local modalScreens = {}
local blur
local function updateBlur()
 local visible = next(modalScreens) ~= nil
 if visible and not blur then
  blur = Instance.new("BlurEffect")
  blur.Name, blur.Size, blur.Parent = "MenuBlur", 10, game:GetService("Lighting")
 end
 if blur then blur.Enabled = visible end
end

function UI.Compact(value)
 if math.abs(value) < 10000 then return UI.Number(value) end
 for _, unit in {{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}} do
  if math.abs(value) >= unit[1] then return string.format("%.1f",value/unit[1]):gsub("%.0$","") .. unit[2] end
 end
 return UI.Number(value)
end

function UI.CardState(frame, state)
 frame.BackgroundColor3 = state == "selected" and Color3.fromRGB(26,107,150)
  or state == "locked" and Color3.fromRGB(53,48,72) or UI.Colors.Card
 frame.BackgroundTransparency = .12
 local stroke = frame:FindFirstChildOfClass("UIStroke")
 if stroke then stroke.Color = state == "selected" and Color3.fromRGB(134,235,255)
  or state == "locked" and Color3.fromRGB(124,68,89) or UI.Colors.Border end
end

function UI.Number(value, decimals)
 local text = string.format("%." .. (decimals or 0) .. "f", value)
 local whole, fraction = text:match("^(%-?%d+)(.*)$")
 local grouped = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""):gsub("^-,", "-")
 return grouped .. fraction
end

function UI.Screen(name, order)
 local gui = Instance.new("ScreenGui")
 gui.Name, gui.DisplayOrder, gui.ResetOnSpawn = name, order, false
 gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
 gui.Parent = player:WaitForChild("PlayerGui")
 return gui
end

function UI.Surface(parent, name, color, className)
 local panel = Instance.new(className or "Frame")
 panel.Name, panel.BackgroundColor3, panel.BorderSizePixel = name, color or UI.Colors.Panel, 0
 Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
 local stroke = Instance.new("UIStroke")
 stroke.Color, stroke.Thickness, stroke.Parent = UI.Colors.Border, 3, panel
 panel.BackgroundTransparency = PANEL_TRANSPARENCY
 panel.Parent = parent
 return panel
end

-- A numbered badge supplies a clear tier identity without inventing item/world art.
function UI.Badge(parent, text, color)
 local badge = UI.Surface(parent,"Badge",color or UI.Colors.Accent)
 badge.BackgroundTransparency, badge.Size = 0,UDim2.fromOffset(64,64)
 UI.Gradient(badge,Color3.new(1,1,1),Color3.fromRGB(140,170,210))
 local label = UI.Label(badge,"Value",text,30)
 label.Size, label.TextXAlignment = UDim2.fromScale(1,1),Enum.TextXAlignment.Center
 return badge
end

function UI.Label(parent, name, text, size, color)
 local label = Instance.new("TextLabel")
 label.Name, label.Text = name, text
 label.TextSize, label.TextColor3 = size or 16, color or UI.Colors.Text
 label.Font = UI.Font
 label.TextStrokeColor3, label.TextStrokeTransparency = UI.Colors.Border, 1
 local outline = Instance.new("UIStroke",label)
 outline.Thickness, outline.Color = math.clamp((size or 16)/11,2,3.5), Color3.fromRGB(17,23,26)
 label.BackgroundTransparency = 1
 label.TextXAlignment = Enum.TextXAlignment.Left
 label.TextYAlignment = Enum.TextYAlignment.Center
 label.Parent = parent
 return label
end

function UI.SetButton(button, text, enabled, accent)
 -- A previous hover must not overwrite the newly selected/disabled state.
 cancelTint(button)
 button.Text, button.Active, button.Selectable = text, enabled, enabled
 button:SetAttribute("Accent", accent == true)
 local selected = text == "EQUIPPED" or text == "SELECTED" or text == "YOU ARE HERE" or button.Name:find("Tab")
 local action = accent and not selected
 local base = button:GetAttribute("Danger") and UI.Colors.Error
  or text == "LOCKED" and UI.Colors.Error
  or not enabled and not accent and UI.Colors.Locked
  or action and (button:GetAttribute("ActionColor") or UI.Colors.Success)
  or accent and UI.Colors.Accent or UI.Colors.Card
 button:SetAttribute("BaseColor",base)
 button.BackgroundColor3 = base
 button.TextColor3 = (enabled or accent) and UI.Colors.Text or UI.Colors.Muted
 button.BackgroundTransparency = 1
 local visual = buttonVisuals[button]
 if visual then
  if visual.tween then visual.tween:Cancel() end
  visual.scale.Scale = 1
  visual.face.BackgroundColor3 = base
 end
end

function UI.Button(parent, name, text)
 local button = Instance.new("TextButton")
 button.Name, button.Font, button.TextSize = name, UI.Font, 19
 button.AutoButtonColor, button.BorderSizePixel = false, 0
 button.TextWrapped, button.TextTransparency, button.TextStrokeTransparency = true,1,1
 button.BackgroundTransparency, button.Parent = 1,parent
 -- Scale the centered visual only: existing layout coordinates and hit targets stay stable.
 local visual = Instance.new("Frame",button)
 visual.Name, visual.AnchorPoint, visual.Position = "Visual",Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
 visual.Size, visual.BorderSizePixel, visual.BackgroundColor3 = UDim2.fromScale(1,1),0,Color3.fromRGB(12,27,40)
 Instance.new("UICorner",visual).CornerRadius = UDim.new(0,10)
 local border = Instance.new("UIStroke",visual)
 border.Color, border.Thickness = UI.Colors.Border,3
 local scale = Instance.new("UIScale",visual)
 local face = Instance.new("Frame",visual)
 face.Name, face.Size, face.BorderSizePixel = "Face",UDim2.new(1,0,1,-5),0
 Instance.new("UICorner",face).CornerRadius = UDim.new(0,10)
 UI.Gradient(face,Color3.fromRGB(255,255,255),Color3.fromRGB(165,190,215))
 checker(face)
 local rim = Instance.new("Frame",face)
 rim.Name, rim.BackgroundTransparency = "InnerHighlight",1
 rim.AnchorPoint, rim.Position, rim.Size = Vector2.new(.5,.5),UDim2.fromScale(.5,.5),UDim2.new(1,-6,1,-6)
 Instance.new("UICorner",rim).CornerRadius = UDim.new(0,8)
 local line = Instance.new("UIStroke",rim)
 line.Color, line.Thickness, line.Transparency = Color3.fromRGB(218,247,255),1.2,.25
 local caption = UI.Label(face,"Caption",text,19)
 caption.Size, caption.Position = UDim2.new(1,-12,1,0),UDim2.fromOffset(6,-1)
 caption.TextXAlignment, caption.TextWrapped, caption.ZIndex = Enum.TextXAlignment.Center,true,2
 local state = {face=face,scale=scale}
 buttonVisuals[button] = state
 local function syncCaption()
  caption.Text, caption.TextSize, caption.TextColor3 = button.Text,button.TextSize,button.TextColor3
 end
 for _,property in {"Text","TextSize","TextColor3"} do button:GetPropertyChangedSignal(property):Connect(syncCaption) end
 button:GetPropertyChangedSignal("BackgroundColor3"):Connect(function() face.BackgroundColor3=button.BackgroundColor3 end)
 UI.SetButton(button,text,true,false)
 syncCaption()
 local hovered, selected = false,false
 local function animate(value)
  if state.tween then state.tween:Cancel() end
  state.tween = TweenService:Create(scale,TweenInfo.new(.1,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=value})
  state.tween:Play()
 end
 local function tint(hover)
  if not button.Active then return end
  cancelTint(button)
  local base = button:GetAttribute("BaseColor")
  local tween = TweenService:Create(button,TweenInfo.new(.1),{BackgroundColor3=hover and base:Lerp(Color3.new(1,1,1),.12) or base})
  tintTweens[button] = tween
  tween.Completed:Once(function() if tintTweens[button]==tween then tintTweens[button]=nil end end)
  tween:Play()
  animate(hover and 1.025 or 1)
 end
 button.MouseEnter:Connect(function() hovered=true tint(true) end)
 button.MouseLeave:Connect(function() hovered=false tint(selected) end)
 button.SelectionGained:Connect(function() selected=true tint(true) end)
 button.SelectionLost:Connect(function() selected=false tint(hovered) end)
 button.MouseButton1Down:Connect(function()
  if button.Active then cancelTint(button) button.BackgroundColor3=button:GetAttribute("BaseColor"):Lerp(Color3.new(),.18) animate(.95) end
 end)
 button.MouseButton1Up:Connect(function() tint(hovered or selected) end)
 button:GetPropertyChangedSignal("Visible"):Connect(function()
  if not button.Visible then
   hovered,selected=false,false
   cancelTint(button)
   if state.tween then state.tween:Cancel() end
   scale.Scale=1
  end
 end)
 button.Destroying:Connect(function()
  cancelTint(button)
  if state.tween then state.tween:Cancel() end
  buttonVisuals[button]=nil
 end)
 return button
end

function UI.Scroll(parent, name)
 local list = Instance.new("ScrollingFrame")
 list.Name, list.BackgroundTransparency, list.BorderSizePixel = name, 1, 0
 list.ScrollBarThickness, list.ScrollBarImageColor3 = 7, UI.Colors.Accent
 list.ScrollingDirection = Enum.ScrollingDirection.Y
 list.CanvasSize, list.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
 local layout = Instance.new("UIListLayout")
 layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 10), Enum.SortOrder.LayoutOrder, list
 local padding = Instance.new("UIPadding")
 padding.PaddingLeft, padding.PaddingTop, padding.PaddingBottom = UDim.new(0,2), UDim.new(0,2), UDim.new(0,2)
 padding.Parent = list
 list.Parent = parent
 return list
end

local themes = {
 EquipmentShopGui = {Color3.fromRGB(255,20,150),Color3.fromRGB(225,0,25)},
 RebirthGui = {Color3.fromRGB(160,0,255),Color3.fromRGB(96,0,200)},
 WorldTravelGui = {Color3.fromRGB(0,205,255),Color3.fromRGB(0,130,245)},
 TrainingGroundGui = {Color3.fromRGB(255,208,0),Color3.fromRGB(230,125,0)},
 OfflineTrainingGui = {Color3.fromRGB(152,255,0),Color3.fromRGB(80,208,0)},
}

function UI.Menu(name, title, subtitle, close)
 local gui = UI.Screen(name, 20)
 local scrim = Instance.new("Frame")
 scrim.Name, scrim.Size = "Scrim", UDim2.fromScale(1,1)
 scrim.BackgroundColor3, scrim.BackgroundTransparency = Color3.new(0,0,0), 0.65
 scrim.BorderSizePixel, scrim.Active, scrim.Visible, scrim.Parent = 0, true, false, gui
 local panel = UI.Surface(scrim, "Panel",nil,"CanvasGroup")
 panel.BackgroundColor3 = Color3.fromRGB(20,49,71)
 local rim = Instance.new("Frame",panel)
 rim.Name, rim.BackgroundTransparency = "InnerHighlight",1
 rim.Position, rim.Size = UDim2.fromOffset(4,4),UDim2.new(1,-8,1,-8)
 Instance.new("UICorner",rim).CornerRadius=UDim.new(0,10)
 local rimStroke=Instance.new("UIStroke",rim)
 rimStroke.Color,rimStroke.Thickness,rimStroke.Transparency=Color3.fromRGB(139,220,250),1.5,.25
 panel.AnchorPoint, panel.Position = Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
 panel.Active = true
 local theme = themes[name] or themes.WorldTravelGui
 local header = Instance.new("Frame",panel)
 header.Name, header.Size = "Header",UDim2.new(1,0,0,64)
 header.BorderSizePixel, header.BackgroundColor3 = 0,Color3.new(1,1,1)
 Instance.new("UICorner",header).CornerRadius=UDim.new(0,12)
 UI.Gradient(header,Color3.fromRGB(158,232,255),Color3.fromRGB(65,159,214))
 checker(header)
 local accent=Instance.new("Frame",header)
 accent.Name,accent.Position,accent.Size= "Accent",UDim2.fromOffset(10,4),UDim2.new(1,-20,0,5)
 accent.BackgroundColor3,accent.BorderSizePixel=theme[1],0
 Instance.new("UICorner",accent).CornerRadius=UDim.new(0,3)
 local headerIcon
 if name=="WorldTravelGui" then headerIcon=UI.WorldIcon(header)
 else headerIcon=UI.Icon(header,"Icon",name=="EquipmentShopGui" and UI.Icons.Shop or name=="RebirthGui" and UI.Icons.Rebirth or UI.Icons.Power) end
 headerIcon.Position,headerIcon.Size=UDim2.fromOffset(16,14),UDim2.fromOffset(40,40)
 for index,color in {theme[2]:Lerp(Color3.new(),.5),Color3.new()} do
  local divider = Instance.new("Frame",header)
  divider.Name, divider.Size, divider.Position = "Divider"..index,UDim2.new(1,0,0,3),UDim2.new(0,0,1,(index-1)*3)
  divider.BackgroundColor3, divider.BorderSizePixel = color,0
 end
 local heading = UI.Label(panel, "Title", string.upper(title), 32)
 heading.ZIndex = 3
 heading.Font, heading.Position, heading.Size = UI.Font, UDim2.fromOffset(68,12), UDim2.new(1,-132,0,44)
 heading.TextScaled = true
 local titleSize = Instance.new("UITextSizeConstraint",heading)
 titleSize.MinTextSize, titleSize.MaxTextSize = 20,32
 local sub = UI.Label(panel, "Subtitle", subtitle, 16, UI.Colors.Muted)
 sub.Position, sub.Size, sub.TextWrapped = UDim2.fromOffset(20,74), UDim2.new(1,-40,0,28), true
 local button = UI.Button(panel, "Close", "X")
 button:SetAttribute("Danger",true)
 UI.SetButton(button,"X",true,false)
 button.AnchorPoint = Vector2.new(.5,.5)
 button.Position, button.Size, button.ZIndex = UDim2.new(1,-32,0,36), UDim2.fromOffset(52,52), 4
 button.TextSize = 29
 button.Activated:Connect(close)
 local windowScale = Instance.new("UIScale",panel)
 windowScale.Name = "WindowScale"
 local baseScale, transition = 1,nil
 local shown, transitionVersion = false,0
 local progress = Instance.new("NumberValue",panel)
 progress.Name = "MenuAnimationProgress"
 local function applyAnimation()
  local amount = progress.Value
  windowScale.Scale = baseScale * (.9 + .1*amount)
  panel.Position = UDim2.new(.5,0,.5,18*(1-amount))
  panel.GroupTransparency = 1-math.clamp(amount,0,1)
  scrim.BackgroundTransparency = 1-.35*math.clamp(amount,0,1)
 end
 progress.Changed:Connect(applyAnimation)
 local function resize()
  local available = scrim.AbsoluteSize
  local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or available
  -- Keep small-screen text readable; scroll content instead of shrinking it further.
  local scale = math.clamp(math.min(viewport.X/1050,viewport.Y/620),(viewport.X < 600 or viewport.Y < 440) and .8 or .65,1.18)
  baseScale = scale
  applyAnimation()
  panel.Size = UDim2.fromOffset(math.min(800, math.max(240, (available.X-24)/scale)), math.min(640, math.max(240,(available.Y-24)/scale)))
  sub.Visible = panel.Size.Y.Offset*scale >= 400
 end
 scrim:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
 task.defer(resize)
 gui.Destroying:Connect(function()
  transitionVersion += 1
  if transition then transition:Cancel() end
  modalScreens[gui] = nil
  updateBlur()
 end)
 return gui, panel, function(visible)
  if shown == visible then return end
  shown = visible
  transitionVersion += 1
  local version = transitionVersion
  if transition then transition:Cancel() end
  scrim.Visible = true
  transition = TweenService:Create(progress,
   TweenInfo.new(visible and .24 or .16,visible and Enum.EasingStyle.Back or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
   {Value=visible and 1 or 0})
  transition.Completed:Once(function(state)
   if state ~= Enum.PlaybackState.Completed or version ~= transitionVersion then return end
   if not shown then scrim.Visible = false end
  end)
  transition:Play()
  modalScreens[gui] = visible and true or nil
  updateBlur()
 end
end

function UI.Hero(parent, imageId)
 local hero = Instance.new("Frame",parent)
 hero.Name, hero.Size, hero.BackgroundTransparency = "Hero",UDim2.new(1,-12,0,136),1
 local burst = Instance.new("ImageLabel",hero)
 burst.Name, burst.BackgroundTransparency = "Sunburst",1
 burst.AnchorPoint, burst.Position, burst.Size = Vector2.new(.5,.5),UDim2.fromScale(.5,.5),UDim2.fromOffset(136,136)
 burst.Image, burst.ScaleType, burst.ImageTransparency = "rbxassetid://130563114903838",Enum.ScaleType.Fit,.4
 local icon = burst:Clone()
 icon.Name, icon.Image, icon.ImageTransparency, icon.Size = "Icon",imageId,0,UDim2.fromOffset(96,96)
 icon.ZIndex, icon.Parent = 2,hero
 local connection = game:GetService("RunService").RenderStepped:Connect(function(dt)
  local ancestor = hero
  while ancestor do
   if ancestor:IsA("GuiObject") and not ancestor.Visible then return end
   if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return end
   ancestor = ancestor.Parent
  end
  burst.Rotation = (burst.Rotation + 20*dt)%360
 end)
 hero.Destroying:Connect(function() connection:Disconnect() end)
 return hero
end

local notification, noticeText, noticeTitle, noticeVersion = nil, nil, nil, 0
local noticeIcon, noticeSymbol, noticeTween
local resizeNotice
local previousText, previousTime = "", 0
function UI.ClearNotifications()
 noticeVersion += 1
 if noticeTween then noticeTween:Cancel() end
 if notification then notification.Visible = false end
 previousText = ""
end

function UI.Notify(message, kind)
 if type(message) ~= "string" or message == "" then return end
 if message == previousText and os.clock()-previousTime < 1 then return end
 previousText, previousTime = message, os.clock()
 -- Routine menu responses use the menu's reserved feedback line, not a toast over its controls.
 if kind=="success" or kind=="error" then
  for screen in modalScreens do
   local feedback=screen.Scrim.Panel:FindFirstChild("Feedback")
   if feedback then
    feedback.Text,feedback.TextColor3=message,kind=="error" and UI.Colors.Error or UI.Colors.Success
    return
   end
  end
 end
 if not notification then
  local gui = UI.Screen("NotificationGui", 40)
  notification = UI.Surface(gui, "Notice")
  notification.AutomaticSize = Enum.AutomaticSize.Y
  notification.Size = UDim2.new(1,-24,0,0)
  local padding = Instance.new("UIPadding",notification)
  padding.PaddingLeft, padding.PaddingRight = UDim.new(0,14), UDim.new(0,14)
  padding.PaddingTop, padding.PaddingBottom = UDim.new(0,10), UDim.new(0,12)
  local layout = Instance.new("UIListLayout",notification)
  layout.Padding, layout.SortOrder = UDim.new(0,6),Enum.SortOrder.LayoutOrder
  local header=Instance.new("Frame",notification)
  header.Name,header.BackgroundTransparency,header.Size,header.LayoutOrder="Header",1,UDim2.new(1,0,0,34),1
  noticeIcon=UI.Icon(header,"Icon",UI.Icons.Power)
  noticeIcon.Position,noticeIcon.Size=UDim2.fromOffset(0,0),UDim2.fromOffset(32,32)
  noticeSymbol=UI.Label(header,"Symbol","",28)
  noticeSymbol.Size,noticeSymbol.TextXAlignment=UDim2.fromOffset(32,32),Enum.TextXAlignment.Center
  noticeTitle = UI.Label(header,"Title","",20)
  noticeTitle.Size, noticeTitle.Position = UDim2.new(1,-44,1,0),UDim2.fromOffset(44,0)
  noticeTitle.TextScaled=true
  local constraint=Instance.new("UITextSizeConstraint",noticeTitle)
  constraint.MinTextSize,constraint.MaxTextSize=14,20
  noticeText = UI.Label(notification,"Message","",17)
  noticeText.Size, noticeText.TextWrapped = UDim2.new(1,0,0,0),true
  noticeText.AutomaticSize, noticeText.LayoutOrder = Enum.AutomaticSize.Y,2
  resizeNotice = function()
   local size = gui.AbsoluteSize
   notification.AnchorPoint, notification.Position = Vector2.new(.5,0),UDim2.new(.5,0,0,12)
   notification.Size = UDim2.fromOffset(math.min(420,size.X < 600 and size.X-24 or size.X-340),0)
  end
  gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeNotice)
 end
 noticeTitle.Text = kind == "unlock" and "WORLD PROGRESS" or kind == "error" and "PLEASE TRY AGAIN"
  or kind == "level" and "LEVEL UP!" or kind == "cap" and "MAX LEVEL REACHED"
  or kind == "offline" and "OFFLINE TRAINING" or kind == "rebirth" and "REBIRTH COMPLETE" or kind == "success" and "SUCCESS!" or "UPDATE"
 noticeTitle.TextColor3 = kind == "error" and UI.Colors.Error or UI.Colors.Accent
 noticeIcon.Image = kind=="rebirth" and UI.Icons.Rebirth or kind=="success" and UI.Icons.Shop or UI.Icons.Power
 noticeSymbol.Visible = kind=="error" or kind=="success"
 noticeIcon.Visible = not noticeSymbol.Visible
 noticeSymbol.Text,noticeSymbol.TextColor3=kind=="error" and "!" or "✓",kind=="error" and UI.Colors.Error or UI.Colors.Success
 notification:FindFirstChildOfClass("UIStroke").Color=kind=="error" and UI.Colors.Error or kind=="rebirth" and Color3.fromRGB(220,124,255) or UI.Colors.Accent
 noticeText.Text, notification.Visible = message, true
 resizeNotice()
 if noticeTween then noticeTween:Cancel() end
 notification.Position=UDim2.new(.5,0,0,0)
 noticeTween=TweenService:Create(notification,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(.5,0,0,12)})
 noticeTween:Play()
 noticeVersion += 1
 local version = noticeVersion
 task.delay((kind == "unlock" or kind == "offline") and 8 or 5, function()
  if version == noticeVersion then notification.Visible = false end
 end)
end
return UI
