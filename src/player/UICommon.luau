-- Shared presentation helpers following the Check-UI design system
-- (.agents/skills/check-ui-clean-roblox). No gameplay state or authoritative calculations.
local TweenService = game:GetService("TweenService")
local player = game.Players.LocalPlayer
local UI = {}

UI.Font = Enum.Font.GothamBlack
-- Global size factor for the HUD, quick menu, and notifications (1 = full size).
UI.SizeScale = 0.75
-- Menus (Shop, Rebirth, Training, Worlds, Inventory, Welcome Back) are sized separately and
-- larger, with a higher floor so they stay readable and easy to tap on phones.
UI.MenuScale = 0.95
UI.MenuMinScale = 0.75
UI.MenuBoxTransparency = 0.3
UI.Colors = {
 Panel = Color3.fromRGB(59, 88, 102), -- Solid slate window canvas (#3B5866).
 Card = Color3.fromRGB(26, 44, 52), -- Recessed item container (#1A2C34).
 Border = Color3.fromRGB(24, 30, 34), -- Window outline (#181E22).
 Text = Color3.fromRGB(255, 255, 255),
 Muted = Color3.fromRGB(225, 235, 245), -- Subtitle / instruction text (#E1EBF5).
 Accent = Color3.fromRGB(0, 190, 255),
 Gold = Color3.fromRGB(255, 208, 0),
 Error = Color3.fromRGB(255, 32, 80),
 Success = Color3.fromRGB(255, 214, 40), -- Positive feedback text (gold; the UI uses no green).
 Locked = Color3.fromRGB(148, 160, 176),
}
UI.Icons = {
 Power = "rbxassetid://17368078790", Cash = "rbxassetid://88694661500877",
 Rebirth = "rbxassetid://17368214873", Shop = "rbxassetid://17368217589",
 Training = "rbxassetid://15403007921", Worlds = "rbxassetid://17368164592",
 Inventory = "rbxassetid://15402958715", Rewards = "rbxassetid://128442519585600",
}

local CHECKER = "rbxassetid://385956923"
local SUNBURST = "rbxassetid://130563114903838"
local CLICK_SOUND = "rbxassetid://6895079853"
local OUTLINE = Color3.fromRGB(12, 20, 26) -- #0C141A button border.
local TEXT_OUTLINE = Color3.fromRGB(17, 23, 26) -- #11171A label stroke.

-- Button state triad (plus the cyan "Codes" palette for neutral/selected-tab buttons).
local BUTTON_STATES = {
 Claim = {Color3.fromRGB(255, 214, 40), Color3.fromRGB(255, 150, 0)},
 Claimed = {Color3.fromRGB(216, 222, 228), Color3.fromRGB(148, 160, 176)},
 Locked = {Color3.fromRGB(255, 32, 80), Color3.fromRGB(208, 0, 32)},
 Cyan = {Color3.fromRGB(0, 205, 255), Color3.fromRGB(0, 130, 245)},
}
UI.ButtonStates = BUTTON_STATES

-- Header themes: gradient top/bottom, top highlight, damier colour, dark divider.
local HEADER_THEMES = {
 EquipmentShopGui = {Color3.fromRGB(255, 20, 150), Color3.fromRGB(225, 0, 25), Color3.fromRGB(255, 200, 225), Color3.fromRGB(150, 0, 20), Color3.fromRGB(125, 0, 18)},
 RebirthGui = {Color3.fromRGB(160, 0, 255), Color3.fromRGB(96, 0, 200), Color3.fromRGB(224, 160, 255), Color3.fromRGB(96, 0, 144), Color3.fromRGB(80, 0, 120)},
 WorldTravelGui = {Color3.fromRGB(0, 205, 255), Color3.fromRGB(0, 130, 245), Color3.fromRGB(180, 240, 255), Color3.fromRGB(0, 75, 150), Color3.fromRGB(0, 50, 110)},
 TrainingGroundGui = {Color3.fromRGB(255, 208, 0), Color3.fromRGB(255, 140, 0), Color3.fromRGB(255, 240, 160), Color3.fromRGB(176, 96, 0), Color3.fromRGB(153, 76, 0)},
 OfflineTrainingGui = {Color3.fromRGB(80, 170, 255), Color3.fromRGB(30, 100, 230), Color3.fromRGB(200, 230, 255), Color3.fromRGB(20, 60, 150), Color3.fromRGB(15, 45, 115)},
 InventoryGui = {Color3.fromRGB(255, 150, 60), Color3.fromRGB(205, 95, 30), Color3.fromRGB(255, 215, 170), Color3.fromRGB(140, 60, 10), Color3.fromRGB(110, 45, 5)},
}

local function corner(parent, radius)
 local object = Instance.new("UICorner")
 object.CornerRadius = UDim.new(0, radius)
 object.Parent = parent
 return object
end

local function stroke(parent, color, thickness, transparency)
 local object = Instance.new("UIStroke")
 object.Color, object.Thickness = color, thickness
 object.Transparency = transparency or 0
 object.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
 object.Parent = parent
 return object
end

-- A thin inset frame carrying a highlight stroke (glass rims, card highlights).
local function rim(parent, inset, color, thickness, transparency, radius)
 local frame = Instance.new("Frame")
 frame.Name = "InnerHighlight"
 frame.AnchorPoint, frame.Position = Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
 frame.Size = UDim2.new(1, -inset, 1, -inset)
 frame.BackgroundTransparency, frame.BorderSizePixel = 1, 0
 if radius then corner(frame, radius) end
 stroke(frame, color, thickness, transparency)
 frame.Parent = parent
 return frame
end

-- Seamless fading damier (checkerboard) overlay. Decorative only.
local function damier(parent, color, tile, fade)
 local image = Instance.new("ImageLabel")
 image.Name, image.BackgroundTransparency = "Checkerboard", 1
 image.Size, image.Image = UDim2.fromScale(1, 1), CHECKER
 image.ScaleType, image.TileSize = Enum.ScaleType.Tile, UDim2.fromOffset(tile, tile)
 image.ImageColor3 = color
 local gradient = Instance.new("UIGradient")
 gradient.Rotation = 90
 gradient.Transparency = fade or NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.3, .82),
  NumberSequenceKeypoint.new(.7, .35), NumberSequenceKeypoint.new(1, .1)})
 gradient.Parent = image
 image.Parent = parent
 return image
end
UI.Damier = damier

-- Shrinks an element around its AnchorPoint by the global size factor.
function UI.Shrink(object)
 local scale = Instance.new("UIScale")
 scale.Name, scale.Scale, scale.Parent = "SizeScale", UI.SizeScale, object
 return scale
end

function UI.Gradient(parent, top, bottom)
 local gradient = Instance.new("UIGradient")
 gradient.Rotation, gradient.Color = 90, ColorSequence.new(top, bottom)
 gradient.Parent = parent
 return gradient
end

function UI.Icon(parent, name, image)
 local icon = Instance.new("ImageLabel")
 icon.Name, icon.Image, icon.BackgroundTransparency = name, image, 1
 icon.ScaleType, icon.Parent = Enum.ScaleType.Fit, parent
 return icon
end

local clickSound
local function playClick()
 if not clickSound then
  clickSound = Instance.new("Sound")
  clickSound.Name, clickSound.SoundId, clickSound.Volume = "UIClick", CLICK_SOUND, .35
  clickSound.Parent = game:GetService("SoundService")
 end
 game:GetService("SoundService"):PlayLocalSound(clickSound)
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

function UI.Number(value, decimals)
 local text = string.format("%." .. (decimals or 0) .. "f", value)
 local whole, fraction = text:match("^(%-?%d+)(.*)$")
 local grouped = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""):gsub("^-,", "-")
 return grouped .. fraction
end

function UI.Compact(value)
 if math.abs(value) < 10000 then return UI.Number(value) end
 for _, unit in {{1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}} do
  if math.abs(value) >= unit[1] then return string.format("%.1f", value / unit[1]):gsub("%.0$", "") .. unit[2] end
 end
 return UI.Number(value)
end

function UI.Screen(name, order)
 local gui = Instance.new("ScreenGui")
 gui.Name, gui.DisplayOrder, gui.ResetOnSpawn = name, order, false
 gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
 gui.Parent = player:WaitForChild("PlayerGui")
 return gui
end

function UI.Label(parent, name, text, size, color)
 local label = Instance.new("TextLabel")
 label.Name, label.Text = name, text
 label.TextSize, label.TextColor3 = size or 16, color or UI.Colors.Text
 label.Font = UI.Font
 label.TextStrokeTransparency = 1
 -- Black outline proportional to the font size (2.0 to 3.5px).
 local outline = Instance.new("UIStroke")
 outline.Thickness, outline.Color = math.clamp((size or 16) / 11, 2, 3.5), Color3.new(0, 0, 0)
 outline.Parent = label
 label.BackgroundTransparency = 1
 label.TextXAlignment = Enum.TextXAlignment.Left
 label.TextYAlignment = Enum.TextYAlignment.Center
 label.Parent = parent
 return label
end

-- Surfaces. Passing UI.Colors.Card makes a recessed item card (#1A2C34, black border,
-- slate inner highlight); any other colour makes a solid panel with the window outline.
function UI.Surface(parent, name, color, className)
 local panel = Instance.new(className or "Frame")
 panel.Name, panel.BorderSizePixel = name, 0
 panel.BackgroundColor3, panel.BackgroundTransparency = color or UI.Colors.Panel, 0
 corner(panel, 4)
 if color == UI.Colors.Card then
  stroke(panel, Color3.new(0, 0, 0), 2.8)
  rim(panel, 4, Color3.fromRGB(75, 125, 145), 1.2, .4, 3)
 else
  stroke(panel, UI.Colors.Border, 3.5)
 end
 panel.Parent = parent
 return panel
end

function UI.CardState(frame, state)
 local highlight = frame:FindFirstChild("InnerHighlight")
 local highlightStroke = highlight and highlight:FindFirstChildOfClass("UIStroke")
 frame.BackgroundTransparency = 0
 if state == "selected" then
  frame.BackgroundColor3 = Color3.fromRGB(28, 66, 82)
  if highlightStroke then highlightStroke.Color, highlightStroke.Transparency, highlightStroke.Thickness = Color3.fromRGB(0, 205, 255), 0, 2 end
 elseif state == "locked" then
  frame.BackgroundColor3 = Color3.fromRGB(34, 32, 42)
  if highlightStroke then highlightStroke.Color, highlightStroke.Transparency, highlightStroke.Thickness = Color3.fromRGB(144, 0, 24), .2, 1.2 end
 else
  frame.BackgroundColor3 = UI.Colors.Card
  if highlightStroke then highlightStroke.Color, highlightStroke.Transparency, highlightStroke.Thickness = Color3.fromRGB(75, 125, 145), .4, 1.2 end
 end
end

-- A small beveled tile carrying a tier number. Its BackgroundColor3 sets the hue.
function UI.Badge(parent, text, color)
 local badge = Instance.new("Frame")
 badge.Name, badge.Size, badge.BorderSizePixel = "Badge", UDim2.fromOffset(64, 64), 0
 badge.BackgroundColor3 = color or UI.Colors.Accent
 corner(badge, 4)
 stroke(badge, Color3.new(0, 0, 0), 2.8)
 local shade = Instance.new("UIGradient")
 shade.Rotation, shade.Color = 90, ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
 shade.Parent = badge
 local bevel = Instance.new("Frame")
 bevel.Name, bevel.BorderSizePixel = "Bevel", 0
 bevel.Size, bevel.Position = UDim2.new(1, 0, 0, 4), UDim2.new(0, 0, 1, -4)
 bevel.BackgroundColor3, bevel.BackgroundTransparency = Color3.new(0, 0, 0), .55
 bevel.Parent = badge
 damier(badge, Color3.new(0, 0, 0), 16, NumberSequence.new(.92, .7))
 rim(badge, 4, Color3.new(1, 1, 1), 1.2, .45, 3)
 local label = UI.Label(badge, "Value", text, 28)
 label.Size, label.TextXAlignment, label.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 3
 badge.Parent = parent
 return badge
end

-- Orange-to-gold progress bar in a recessed trough (Check-UI 3.3).
function UI.ProgressBar(parent, name)
 local trough = Instance.new("Frame")
 trough.Name, trough.BorderSizePixel = name or "ProgressTrough", 0
 trough.BackgroundColor3, trough.ClipsDescendants = Color3.fromRGB(20, 30, 36), true
 stroke(trough, Color3.fromRGB(12, 18, 22), 2)
 local fill = Instance.new("Frame")
 fill.Name, fill.BorderSizePixel = "ProgressFill", 0
 fill.Size, fill.BackgroundColor3 = UDim2.fromScale(0, 1), Color3.new(1, 1, 1)
 UI.Gradient(fill, Color3.fromRGB(255, 200, 0), Color3.fromRGB(255, 106, 0))
 local bevel = Instance.new("Frame")
 bevel.Name, bevel.BorderSizePixel = "Bevel", 0
 bevel.Size, bevel.Position, bevel.BackgroundColor3 = UDim2.new(1, 0, 0, 2), UDim2.new(0, 0, 1, -2), Color3.fromRGB(153, 60, 0)
 bevel.Parent = fill
 fill.Parent = trough
 local label = UI.Label(trough, "ProgressLabel", "", 20)
 label.Size, label.TextXAlignment, label.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 2
 trough.Parent = parent
 return trough, function(progress, text)
  fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
  label.Text = text or string.format("%d%% Completed", math.floor(math.clamp(progress, 0, 1) * 100))
 end
end

-- Buttons follow the canonical iconless blueprint: sharp rectangle, 3px dark border,
-- vertical state gradient, fading black damier, triple glass rim, outlined label.
-- The TextButton stays a stable hit target; only its centered Visual scales.
local buttonVisuals = {}

local SELECTED_TEXT = {EQUIPPED = true, SELECTED = true, ["YOU ARE HERE"] = true}

local function buttonState(button, text, enabled, accent)
 if button:GetAttribute("Danger") or text == "LOCKED" then return "Locked" end
 if button.Name:find("Tab") then return accent and "Cyan" or "Claimed" end
 if SELECTED_TEXT[text] then return "Claimed" end
 if not enabled then return "Claimed" end
 return accent and "Claim" or "Cyan"
end

function UI.SetButton(button, text, enabled, accent)
 button.Text, button.Active, button.Selectable = text, enabled, enabled
 button:SetAttribute("Accent", accent == true)
 local state = buttonState(button, text, enabled, accent)
 button:SetAttribute("State", state)
 -- BackgroundColor3 mirrors the state's base colour; the visual uses the full gradient.
 button.BackgroundColor3 = BUTTON_STATES[state][2]
 button.BackgroundTransparency = 1
 local visual = buttonVisuals[button]
 if visual then
  if visual.tween then visual.tween:Cancel() end
  visual.scale.Scale = 1
  visual.gradient.Color = ColorSequence.new(BUTTON_STATES[state][1], BUTTON_STATES[state][2])
 end
end

function UI.Button(parent, name, text)
 local button = Instance.new("TextButton")
 button.Name, button.Font, button.TextSize = name, UI.Font, 22
 button.AutoButtonColor, button.BorderSizePixel = false, 0
 button.TextWrapped, button.TextTransparency, button.TextStrokeTransparency = true, 1, 1
 button.BackgroundTransparency, button.Parent = 1, parent
 local visual = Instance.new("Frame")
 visual.Name, visual.AnchorPoint, visual.Position = "Visual", Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
 visual.Size, visual.BorderSizePixel, visual.BackgroundColor3 = UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1)
 visual.ClipsDescendants = true
 visual.Parent = button
 stroke(visual, OUTLINE, 3)
 local gradient = UI.Gradient(visual, BUTTON_STATES.Cyan[1], BUTTON_STATES.Cyan[2])
 damier(visual, Color3.new(0, 0, 0), 19, NumberSequence.new(.91, .62))
 for index, transparency in {.25, .45, .8} do
  rim(visual, index * 2, Color3.new(1, 1, 1), 1, transparency).Name = "InnerHighlight" .. index
 end
 local caption = UI.Label(visual, "Caption", text, 22)
 caption.AnchorPoint, caption.Position = Vector2.new(.5, .5), UDim2.new(.5, 0, .5, -1)
 caption.Size, caption.TextXAlignment, caption.TextWrapped, caption.ZIndex = UDim2.new(1, -12, 1, 0), Enum.TextXAlignment.Center, true, 3
 local captionStroke = caption:FindFirstChildOfClass("UIStroke")
 captionStroke.Color, captionStroke.Thickness = TEXT_OUTLINE, 3
 captionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
 local scale = Instance.new("UIScale")
 scale.Name, scale.Parent = "ButtonScale", visual
 local state = {scale = scale, gradient = gradient}
 buttonVisuals[button] = state
 local function syncCaption()
  caption.Text, caption.TextSize = button.Text, button.TextSize
 end
 for _, property in {"Text", "TextSize"} do button:GetPropertyChangedSignal(property):Connect(syncCaption) end
 UI.SetButton(button, text, true, false)
 syncCaption()
 local hovered, selected = false, false
 local function animate(value, style, duration)
  if state.tween then state.tween:Cancel() end
  state.tween = TweenService:Create(scale, TweenInfo.new(duration or .08, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = value})
  state.tween:Play()
 end
 local function rest()
  animate((hovered or selected) and button.Active and 1.05 or 1)
 end
 button.MouseEnter:Connect(function() hovered = true rest() end)
 button.MouseLeave:Connect(function() hovered = false rest() end)
 button.SelectionGained:Connect(function() selected = true rest() end)
 button.SelectionLost:Connect(function() selected = false rest() end)
 button.MouseButton1Down:Connect(function()
  if not button.Active then return end
  playClick()
  animate(.94, Enum.EasingStyle.Quad, .05)
 end)
 button.MouseButton1Up:Connect(function()
  animate((hovered or selected) and button.Active and 1.05 or 1, Enum.EasingStyle.Back, .12)
 end)
 button:GetPropertyChangedSignal("Visible"):Connect(function()
  if not button.Visible then
   hovered, selected = false, false
   if state.tween then state.tween:Cancel() end
   scale.Scale = 1
  end
 end)
 button.Destroying:Connect(function()
  if state.tween then state.tween:Cancel() end
  buttonVisuals[button] = nil
 end)
 return button
end

-- Signature 38x38 3D beveled square close button (Check-UI 3.1).
local function closeButton(parent)
 local button = Instance.new("ImageButton")
 button.Name, button.Size = "Close", UDim2.fromOffset(38, 38)
 button.AnchorPoint, button.Position = Vector2.new(.5, .5), UDim2.new(1, -34, .5, -2)
 button.BackgroundColor3, button.BorderSizePixel, button.AutoButtonColor = Color3.fromRGB(115, 0, 16), 0, false
 button.ZIndex = 25
 stroke(button, Color3.new(0, 0, 0), 2.8)
 local face = Instance.new("Frame")
 face.Name, face.Size, face.BorderSizePixel, face.ZIndex = "Face", UDim2.new(1, 0, 1, -4), 0, 26
 face.BackgroundColor3 = Color3.new(1, 1, 1)
 UI.Gradient(face, Color3.fromRGB(255, 125, 175), Color3.fromRGB(255, 20, 40))
 rim(face, 2, Color3.fromRGB(255, 210, 235), 1.2).ZIndex = 27
 face.Parent = button
 local line = Instance.new("Frame")
 line.Name, line.Size, line.Position = "SepLine", UDim2.new(1, 0, 0, 1), UDim2.new(0, 0, 1, -4)
 line.BackgroundColor3, line.BorderSizePixel, line.ZIndex = Color3.fromRGB(70, 0, 10), 0, 27
 line.Parent = button
 local x = UI.Label(face, "X", "X", 29)
 x.AnchorPoint, x.Position, x.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(1, 1)
 x.TextXAlignment, x.ZIndex = Enum.TextXAlignment.Center, 28
 x:FindFirstChildOfClass("UIStroke").Thickness = 3
 local scale = Instance.new("UIScale")
 scale.Name, scale.Parent = "ButtonScale", button
 local function animate(value, style, duration)
  TweenService:Create(scale, TweenInfo.new(duration or .08, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = value}):Play()
 end
 button.MouseEnter:Connect(function() animate(1.05) end)
 button.MouseLeave:Connect(function() animate(1) end)
 button.MouseButton1Down:Connect(function() playClick() animate(.94, Enum.EasingStyle.Quad, .05) end)
 button.MouseButton1Up:Connect(function() animate(1.05, Enum.EasingStyle.Back, .12) end)
 button.Parent = parent
 return button
end

function UI.Scroll(parent, name)
 local list = Instance.new("ScrollingFrame")
 list.Name, list.BackgroundTransparency, list.BorderSizePixel = name, 1, 0
 list.ScrollBarThickness, list.ScrollBarImageColor3 = 7, Color3.fromRGB(85, 140, 160)
 list.ScrollingDirection = Enum.ScrollingDirection.Y
 list.CanvasSize, list.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.Y
 local layout = Instance.new("UIListLayout")
 layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 10), Enum.SortOrder.LayoutOrder, list
 local padding = Instance.new("UIPadding")
 padding.PaddingLeft, padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 3), UDim.new(0, 3), UDim.new(0, 3)
 padding.Parent = list
 list.Parent = parent
 return list
end

-- Modal window: a solid slate box with the menu's icon and title riding over its top edge,
-- the beveled close button on its top-right corner, and responsive WindowScale. The panel
-- is a transparent CanvasGroup TITLE_RISE taller than the box so the title is not clipped;
-- callers keep laying out content in panel space (content starts below y = 70).
local TITLE_RISE = 30
local MENU_ICONS = {
 EquipmentShopGui = UI.Icons.Shop, RebirthGui = UI.Icons.Rebirth, WorldTravelGui = UI.Icons.Worlds,
 TrainingGroundGui = UI.Icons.Training, OfflineTrainingGui = UI.Icons.Power, InventoryGui = UI.Icons.Inventory,
}
function UI.Menu(name, title, subtitle, close)
 local gui = UI.Screen(name, 20)
 local scrim = Instance.new("Frame")
 scrim.Name, scrim.Size = "Scrim", UDim2.fromScale(1, 1)
 scrim.BackgroundColor3, scrim.BackgroundTransparency = Color3.new(0, 0, 0), .65
 scrim.BorderSizePixel, scrim.Active, scrim.Visible, scrim.Parent = 0, true, false, gui
 local panel = Instance.new("CanvasGroup")
 panel.Name, panel.BackgroundTransparency, panel.BorderSizePixel = "Panel", 1, 0
 panel.AnchorPoint, panel.Position, panel.Active = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), true
 panel.Parent = scrim
 -- Inset so the box outline is not clipped by the CanvasGroup edges.
 local box = UI.Surface(panel, "Box", UI.Colors.Panel)
 box.Position, box.Size = UDim2.fromOffset(4, TITLE_RISE), UDim2.new(1, -8, 1, -TITLE_RISE - 4)
 -- Slightly see-through so the blurred world shows behind the menu.
 box.BackgroundTransparency = UI.MenuBoxTransparency
 -- Subtle full-height damier on the canvas, faded so content stays readable.
 damier(box, Color3.new(0, 0, 0), 22, NumberSequence.new({NumberSequenceKeypoint.new(0, 1),
  NumberSequenceKeypoint.new(.5, .97), NumberSequenceKeypoint.new(1, .9)})).Name = "CanvasDamier"
 local theme = HEADER_THEMES[name] or HEADER_THEMES.WorldTravelGui
 -- Themed accent strip along the top of the box, under the title.
 local accent = Instance.new("Frame")
 accent.Name, accent.Size, accent.BorderSizePixel = "TopAccent", UDim2.new(1, 0, 0, 6), 0
 accent.BackgroundColor3 = Color3.new(1, 1, 1)
 UI.Gradient(accent, theme[1], theme[2])
 accent.Parent = box
 local icon = Instance.new("ImageLabel")
 icon.Name, icon.BackgroundTransparency, icon.ZIndex = "TitleIcon", 1, 4
 icon.AnchorPoint, icon.Position, icon.Size = Vector2.new(.5, .5), UDim2.fromOffset(38, TITLE_RISE), UDim2.fromOffset(58, 58)
 icon.Image, icon.ScaleType = MENU_ICONS[name] or UI.Icons.Worlds, Enum.ScaleType.Fit
 icon.Parent = panel
 local heading = UI.Label(panel, "Title", string.upper(title), 46)
 heading.AnchorPoint, heading.ZIndex = Vector2.new(0, .5), 3
 heading.Position, heading.Size = UDim2.fromOffset(74, TITLE_RISE), UDim2.new(1, -130, 0, 52)
 heading.TextScaled = true
 heading:FindFirstChildOfClass("UIStroke").Thickness = 4
 UI.Gradient(heading, Color3.new(1, 1, 1), theme[3])
 local titleSize = Instance.new("UITextSizeConstraint")
 titleSize.MinTextSize, titleSize.MaxTextSize, titleSize.Parent = 22, 46, heading
 local sub = UI.Label(panel, "Subtitle", subtitle, 14, UI.Colors.Muted)
 sub.Position, sub.Size, sub.TextWrapped = UDim2.fromOffset(20, 74), UDim2.new(1, -40, 0, 28), true
 sub.TextXAlignment = Enum.TextXAlignment.Center
 sub:FindFirstChildOfClass("UIStroke").Thickness = 1.9
 local closer = closeButton(panel)
 closer.Position = UDim2.new(1, -30, 0, TITLE_RISE)
 closer.Activated:Connect(close)
 local windowScale = Instance.new("UIScale")
 windowScale.Name, windowScale.Parent = "WindowScale", panel
 local baseScale, transition = 1, nil
 local shown, transitionVersion = false, 0
 local progress = Instance.new("NumberValue")
 progress.Name, progress.Parent = "MenuAnimationProgress", panel
 local function applyAnimation()
  local amount = progress.Value
  windowScale.Scale = baseScale * (.9 + .1 * amount)
  panel.Position = UDim2.new(.5, 0, .5, 18 * (1 - amount))
  panel.GroupTransparency = 1 - math.clamp(amount, 0, 1)
  scrim.BackgroundTransparency = 1 - .35 * math.clamp(amount, 0, 1)
 end
 progress.Changed:Connect(applyAnimation)
 local function resize()
  local available = scrim.AbsoluteSize
  local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or available
  -- Check-UI responsive engine (1050x620 baseline, clamped to [0.52, 1.18]), times the menu
  -- size factor, never below MenuMinScale so phone menus stay large. The window size below
  -- is capped by the screen, so a larger scale never pushes it off-screen.
  local scale = math.max(UI.MenuMinScale, math.clamp(math.min(viewport.X / 1050, viewport.Y / 620), .52, 1.18) * UI.MenuScale)
  baseScale = scale
  applyAnimation()
  panel.Size = UDim2.fromOffset(math.min(680, math.max(240, (available.X - 24) / scale)), math.min(520 + TITLE_RISE, math.max(240, (available.Y - 24) / scale)))
  sub.Visible = panel.Size.Y.Offset * scale >= 400
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
   TweenInfo.new(visible and .24 or .16, visible and Enum.EasingStyle.Back or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
   {Value = visible and 1 or 0})
  transition.Completed:Once(function(state)
   if state ~= Enum.PlaybackState.Completed or version ~= transitionVersion then return end
   if not shown then scrim.Visible = false end
  end)
  transition:Play()
  modalScreens[gui] = visible and true or nil
  updateBlur()
 end
end

-- Featured icon over a continuously rotating sunburst (20 degrees per second while visible).
function UI.Hero(parent, imageId)
 local hero = Instance.new("Frame")
 hero.Name, hero.Size, hero.BackgroundTransparency = "Hero", UDim2.new(1, -12, 0, 136), 1
 hero.Parent = parent
 local burst = Instance.new("ImageLabel")
 burst.Name, burst.BackgroundTransparency = "Sunburst", 1
 burst.AnchorPoint, burst.Position, burst.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromOffset(136, 136)
 burst.Image, burst.ScaleType, burst.ImageTransparency = SUNBURST, Enum.ScaleType.Fit, .4
 burst.Parent = hero
 local icon = burst:Clone()
 icon.Name, icon.Image, icon.ImageTransparency, icon.Size = "Icon", imageId, 0, UDim2.fromOffset(96, 96)
 icon.ZIndex, icon.Parent = 2, hero
 local connection = game:GetService("RunService").RenderStepped:Connect(function(dt)
  local ancestor = hero
  while ancestor do
   if ancestor:IsA("GuiObject") and not ancestor.Visible then return end
   if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return end
   ancestor = ancestor.Parent
  end
  burst.Rotation = (burst.Rotation + 20 * dt) % 360
 end)
 hero.Destroying:Connect(function() connection:Disconnect() end)
 return hero
end

local NOTICE_THEMES = {
 unlock = {"WORLD PROGRESS", BUTTON_STATES.Cyan[1]}, error = {"PLEASE TRY AGAIN", BUTTON_STATES.Locked[1]},
 level = {"LEVEL UP!", BUTTON_STATES.Claim[1]}, cap = {"MAX LEVEL REACHED", UI.Colors.Gold},
 offline = {"OFFLINE TRAINING", BUTTON_STATES.Claim[1]}, rebirth = {"REBIRTH COMPLETE", Color3.fromRGB(190, 90, 255)},
 success = {"SUCCESS!", BUTTON_STATES.Claim[1]},
}
local notification, noticeText, noticeTitle, noticeBar, noticeVersion = nil, nil, nil, nil, 0
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
 if message == previousText and os.clock() - previousTime < 1 then return end
 previousText, previousTime = message, os.clock()
 -- Routine menu responses use the menu's reserved feedback line, not a toast over its controls.
 if kind == "success" or kind == "error" then
  for screen in modalScreens do
   local feedback = screen.Scrim.Panel:FindFirstChild("Feedback")
   if feedback then
    feedback.Text, feedback.TextColor3 = message, kind == "error" and UI.Colors.Error or UI.Colors.Success
    return
   end
  end
 end
 if not notification then
  local gui = UI.Screen("NotificationGui", 40)
  notification = UI.Surface(gui, "Notice", UI.Colors.Panel)
  notification.AutomaticSize = Enum.AutomaticSize.Y
  notification.Size = UDim2.new(1, -24, 0, 0)
  local noticeScale = Instance.new("UIScale")
  noticeScale.Name, noticeScale.Scale, noticeScale.Parent = "SizeScale", UI.SizeScale, notification
  noticeBar = Instance.new("Frame")
  noticeBar.Name, noticeBar.Size, noticeBar.BorderSizePixel = "ThemeBar", UDim2.new(1, 0, 0, 5), 0
  noticeBar.Parent = notification
  local padding = Instance.new("UIPadding")
  padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
  padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
  local content = Instance.new("Frame")
  content.Name, content.BackgroundTransparency = "Content", 1
  content.Size, content.AutomaticSize = UDim2.fromScale(1, 0), Enum.AutomaticSize.Y
  content.Position = UDim2.fromOffset(0, 5) -- Below the theme bar.
  content.Parent = notification
  padding.Parent = content
  local layout = Instance.new("UIListLayout")
  layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 6), Enum.SortOrder.LayoutOrder, content
  local header = Instance.new("Frame")
  header.Name, header.BackgroundTransparency, header.Size, header.LayoutOrder = "Header", 1, UDim2.new(1, 0, 0, 34), 1
  header.Parent = content
  noticeIcon = UI.Icon(header, "Icon", UI.Icons.Power)
  noticeIcon.Size = UDim2.fromOffset(32, 32)
  noticeSymbol = UI.Label(header, "Symbol", "", 28)
  noticeSymbol.Size, noticeSymbol.TextXAlignment = UDim2.fromOffset(32, 32), Enum.TextXAlignment.Center
  noticeTitle = UI.Label(header, "Title", "", 22)
  noticeTitle.Size, noticeTitle.Position = UDim2.new(1, -44, 1, 0), UDim2.fromOffset(44, 0)
  noticeTitle.TextScaled = true
  local constraint = Instance.new("UITextSizeConstraint")
  constraint.MinTextSize, constraint.MaxTextSize, constraint.Parent = 14, 22, noticeTitle
  noticeText = UI.Label(content, "Message", "", 17)
  noticeText.Size, noticeText.TextWrapped = UDim2.new(1, 0, 0, 0), true
  noticeText.AutomaticSize, noticeText.LayoutOrder = Enum.AutomaticSize.Y, 2
  resizeNotice = function()
   local size = gui.AbsoluteSize
   notification.AnchorPoint, notification.Position = Vector2.new(.5, 0), UDim2.new(.5, 0, 0, 12)
   notification.Size = UDim2.fromOffset(math.min(420, size.X < 600 and size.X - 24 or size.X - 340), 0)
  end
  gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeNotice)
 end
 local theme = NOTICE_THEMES[kind] or {"UPDATE", BUTTON_STATES.Cyan[1]}
 noticeTitle.Text, noticeTitle.TextColor3 = theme[1], theme[2]
 noticeBar.BackgroundColor3 = theme[2]
 noticeIcon.Image = kind == "rebirth" and UI.Icons.Rebirth or kind == "success" and UI.Icons.Shop or UI.Icons.Power
 noticeSymbol.Visible = kind == "error" or kind == "success"
 noticeIcon.Visible = not noticeSymbol.Visible
 noticeSymbol.Text, noticeSymbol.TextColor3 = kind == "error" and "!" or "✓", theme[2]
 noticeText.Text, notification.Visible = message, true
 resizeNotice()
 if noticeTween then noticeTween:Cancel() end
 notification.Position = UDim2.new(.5, 0, 0, 0)
 noticeTween = TweenService:Create(notification, TweenInfo.new(.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(.5, 0, 0, 12)})
 noticeTween:Play()
 noticeVersion += 1
 local version = noticeVersion
 task.delay((kind == "unlock" or kind == "offline") and 8 or 5, function()
  if version == noticeVersion then notification.Visible = false end
 end)
end
return UI
