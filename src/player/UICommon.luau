-- Shared presentation helpers. Every screen follows the Inventory's chunky cartoon style:
-- the rounded FredokaOne font with heavy black outlines, blue rounded windows with a faint
-- checker, a big title riding over the window's top edge, a red rounded close button,
-- rounded dark-blue cards, and studded buttons in blue, green, red and grey. (Built on the
-- Check-UI foundation in .agents/skills/check-ui-clean-roblox.) No gameplay state or
-- authoritative calculations.
local TweenService = game:GetService("TweenService")
local GameAudio = require(game:GetService("ReplicatedStorage"):WaitForChild("GameAudio"))
local player = game.Players.LocalPlayer
local UI = {}

UI.Font = Enum.Font.FredokaOne
-- Global size factor for the HUD, quick menu, and notifications (1 = full size).
UI.SizeScale = 0.75
-- Menus (Shop, Rebirth, Training, Worlds, Inventory, Welcome Back) are sized separately and
-- larger, with a higher floor so they stay readable and easy to tap on phones.
UI.MenuScale = 0.95
UI.MenuMinScale = 0.75
-- Menu windows are slightly see-through, so the blurred world shows faintly behind them.
UI.MenuBoxTransparency = 0.3
UI.Colors = {
 Panel = Color3.fromRGB(34, 86, 196), -- Blue window canvas.
 Card = Color3.fromRGB(26, 48, 100), -- Dark blue card / recessed container.
 Border = Color3.fromRGB(14, 14, 18), -- The thick near-black outline.
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
 -- Free Creator Store images: "Robux Icon White" (decal 11560341145, tinted where used) and
 -- "Baseball bat icon" (decal 14583816406).
 Robux = "rbxassetid://11560341132", Bat = "rbxassetid://14583816373",
}

local CHECKER = "rbxassetid://385956923"
local SUNBURST = "rbxassetid://130563114903838"
local TEXT_OUTLINE = Color3.fromRGB(17, 23, 26) -- #11171A label stroke.

-- Button states, as the face's top and bottom colours: Claim (go / buy / confirm) green,
-- Claimed (done or unavailable) grey, Locked red, Cyan (neutral, selected tabs) blue.
local BUTTON_STATES = {
 Claim = {Color3.fromRGB(120, 230, 70), Color3.fromRGB(50, 175, 40)},
 Claimed = {Color3.fromRGB(160, 162, 172), Color3.fromRGB(110, 112, 122)},
 Locked = {Color3.fromRGB(255, 80, 90), Color3.fromRGB(215, 25, 45)},
 Cyan = {Color3.fromRGB(70, 160, 255), Color3.fromRGB(30, 105, 235)},
}
UI.ButtonStates = BUTTON_STATES

-- Every window is blue, like the Inventory: its gradient (top, bottom), faint checker tint and
-- the title's gradient end colour.
local WINDOW = {top = Color3.fromRGB(72, 150, 245), bottom = Color3.fromRGB(34, 86, 196),
 checker = Color3.fromRGB(10, 40, 110), title = Color3.fromRGB(150, 228, 255)}

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

-- The shared UI sound vocabulary (GameAudio): click, menu open/close, locked, invalid, notice.
local function playClick()
 GameAudio.Play("UIClick")
end
GameAudio.Preload({"UIClick", "MenuOpen", "MenuClose", "Locked", "Invalid", "Notice"})

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
 for _, unit in {{1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}} do
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
 -- A heavy near-black outline proportional to the font size (2 to 6px).
 local outline = Instance.new("UIStroke")
 outline.Thickness, outline.Color = math.clamp((size or 16) / 9, 2, 6), UI.Colors.Border
 outline.Parent = label
 label.BackgroundTransparency = 1
 label.TextXAlignment = Enum.TextXAlignment.Left
 label.TextYAlignment = Enum.TextYAlignment.Center
 label.Parent = parent
 return label
end

-- Surfaces: rounded, with the thick dark outline. Passing UI.Colors.Card makes a dark blue
-- card with a light blue inner rim; any other colour makes a solid panel.
local CARD_RIM = Color3.fromRGB(110, 160, 235)
function UI.Surface(parent, name, color, className)
 local panel = Instance.new(className or "Frame")
 panel.Name, panel.BorderSizePixel = name, 0
 panel.BackgroundColor3, panel.BackgroundTransparency = color or UI.Colors.Panel, 0
 corner(panel, 12)
 stroke(panel, UI.Colors.Border, 4)
 if color == UI.Colors.Card then rim(panel, 6, CARD_RIM, 2, .45, 9) end
 panel.Parent = parent
 return panel
end

function UI.CardState(frame, state)
 local highlight = frame:FindFirstChild("InnerHighlight")
 local highlightStroke = highlight and highlight:FindFirstChildOfClass("UIStroke")
 frame.BackgroundTransparency = 0
 if state == "selected" then
  frame.BackgroundColor3 = Color3.fromRGB(40, 92, 178)
  if highlightStroke then highlightStroke.Color, highlightStroke.Transparency, highlightStroke.Thickness = Color3.fromRGB(110, 210, 255), 0, 3 end
 elseif state == "locked" then
  frame.BackgroundColor3 = Color3.fromRGB(30, 32, 50)
  if highlightStroke then highlightStroke.Color, highlightStroke.Transparency, highlightStroke.Thickness = Color3.fromRGB(215, 25, 45), .25, 2 end
 else
  frame.BackgroundColor3 = UI.Colors.Card
  if highlightStroke then highlightStroke.Color, highlightStroke.Transparency, highlightStroke.Thickness = CARD_RIM, .45, 2 end
 end
end

-- A small beveled tile carrying a tier number. Its BackgroundColor3 sets the hue.
function UI.Badge(parent, text, color)
 local badge = Instance.new("Frame")
 badge.Name, badge.Size, badge.BorderSizePixel = "Badge", UDim2.fromOffset(64, 64), 0
 badge.BackgroundColor3 = color or UI.Colors.Accent
 corner(badge, 12)
 stroke(badge, UI.Colors.Border, 4)
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
 trough.BackgroundColor3, trough.ClipsDescendants = Color3.fromRGB(22, 36, 74), true
 corner(trough, 8)
 stroke(trough, UI.Colors.Border, 3)
 local fill = Instance.new("Frame")
 fill.Name, fill.BorderSizePixel = "ProgressFill", 0
 fill.Size, fill.BackgroundColor3 = UDim2.fromScale(0, 1), Color3.new(1, 1, 1)
 corner(fill, 8)
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

-- Buttons are chunky and studded like the Inventory's: a slightly rounded face in the state's
-- colours with a faint stud pattern, a darker bottom edge, a white inner rim, a thick dark
-- outline and a big outlined caption. The TextButton stays a stable hit target; only its
-- centered Visual scales.
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
 corner(visual, 6)
 stroke(visual, UI.Colors.Border, 4)
 local gradient = UI.Gradient(visual, BUTTON_STATES.Cyan[1], BUTTON_STATES.Cyan[2])
 damier(visual, Color3.new(1, 1, 1), 22, NumberSequence.new(.86, .9)).Name = "Studs"
 local edge = Instance.new("Frame")
 edge.Name, edge.BorderSizePixel, edge.Size, edge.Position = "Edge", 0, UDim2.new(1, 0, 0, 5), UDim2.new(0, 0, 1, -5)
 edge.BackgroundColor3, edge.BackgroundTransparency, edge.Parent = Color3.new(0, 0, 0), .7, visual
 rim(visual, 6, Color3.new(1, 1, 1), 2, .55, 4).Name = "InnerHighlight1"
 local caption = UI.Label(visual, "Caption", text, 22)
 caption.AnchorPoint, caption.Position = Vector2.new(.5, .5), UDim2.new(.5, 0, .5, -2)
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
  -- A muted thunk tells the player a locked/unavailable button heard them.
  if not button.Active then GameAudio.Play("Locked") return end
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

-- The close button, as on the Inventory: a red rounded square with a white outlined X.
local function closeButton(parent)
 local button = Instance.new("ImageButton")
 button.Name, button.Size = "Close", UDim2.fromOffset(52, 52)
 button.AnchorPoint, button.Position = Vector2.new(.5, .5), UDim2.new(1, -34, .5, -2)
 button.BackgroundColor3, button.BorderSizePixel, button.AutoButtonColor = Color3.new(1, 1, 1), 0, false
 button.ZIndex = 25
 corner(button, 12)
 stroke(button, UI.Colors.Border, 4)
 UI.Gradient(button, Color3.fromRGB(255, 70, 90), Color3.fromRGB(220, 15, 45))
 rim(button, 8, Color3.new(1, 1, 1), 2, .5, 8).ZIndex = 26
 local x = UI.Label(button, "X", "X", 40)
 x.AnchorPoint, x.Position, x.Size = Vector2.new(.5, .5), UDim2.new(.5, 0, .5, -2), UDim2.fromScale(1, 1)
 x.TextXAlignment, x.ZIndex = Enum.TextXAlignment.Center, 28
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
 RebirthGui = UI.Icons.Rebirth, WorldTravelGui = UI.Icons.Worlds,
 TrainingGroundGui = UI.Icons.Training, OfflineTrainingGui = UI.Icons.Power, InventoryGui = UI.Icons.Inventory,
}
-- The shared modal shell: a dimming scrim, a transparent CanvasGroup panel with a responsive
-- WindowScale, and the open/close animation, blur and sounds. The panel is capped at
-- maxWidth x maxHeight menu units; onResize(scale, panel) runs after each resize. Returns the
-- ScreenGui, scrim, panel and show(visible).
local function modalShell(name, maxWidth, maxHeight, onResize)
 local gui = UI.Screen(name, 20)
 local scrim = Instance.new("Frame")
 scrim.Name, scrim.Size = "Scrim", UDim2.fromScale(1, 1)
 scrim.BackgroundColor3, scrim.BackgroundTransparency = Color3.new(0, 0, 0), .65
 scrim.BorderSizePixel, scrim.Active, scrim.Visible, scrim.Parent = 0, true, false, gui
 local panel = Instance.new("CanvasGroup")
 panel.Name, panel.BackgroundTransparency, panel.BorderSizePixel = "Panel", 1, 0
 panel.AnchorPoint, panel.Position, panel.Active = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), true
 panel.Parent = scrim
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
  panel.Size = UDim2.fromOffset(math.min(maxWidth, math.max(240, (available.X - 24) / scale)), math.min(maxHeight, math.max(240, (available.Y - 24) / scale)))
  if onResize then onResize(scale, panel) end
 end
 scrim:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
 task.defer(resize)
 gui.Destroying:Connect(function()
  transitionVersion += 1
  if transition then transition:Cancel() end
  modalScreens[gui] = nil
  updateBlur()
 end)
 return gui, scrim, panel, function(visible)
  if shown == visible then return end
  shown = visible
  GameAudio.Play(visible and "MenuOpen" or "MenuClose")
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

function UI.Menu(name, title, subtitle, close)
 local sub
 local gui, _, panel, show = modalShell(name, 680, 520 + TITLE_RISE, function(scale, window)
  if sub then sub.Visible = window.Size.Y.Offset * scale >= 400 end
 end)
 -- The blue rounded window (inset so its outline is not clipped by the CanvasGroup edges):
 -- a vertical gradient, a faint checker and a soft white inner rim.
 local box = UI.Surface(panel, "Box", Color3.new(1, 1, 1))
 box.BackgroundTransparency = UI.MenuBoxTransparency
 box.Position, box.Size = UDim2.fromOffset(4, TITLE_RISE), UDim2.new(1, -8, 1, -TITLE_RISE - 4)
 box:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 16)
 UI.Gradient(box, WINDOW.top, WINDOW.bottom)
 damier(box, WINDOW.checker, 30, NumberSequence.new(.9, .78)).Name = "CanvasDamier"
 rim(box, 8, Color3.new(1, 1, 1), 2, .65, 12)
 -- The title rides centred over the top edge, white fading to light cyan, with the menu's icon
 -- just left of the text.
 local heading = UI.Label(panel, "Title", title, 56)
 heading.AnchorPoint, heading.ZIndex = Vector2.new(.5, .5), 5
 heading.Position, heading.Size = UDim2.new(.5, 0, 0, TITLE_RISE), UDim2.new(1, -170, 0, 60)
 heading.TextScaled, heading.TextXAlignment = true, Enum.TextXAlignment.Center
 UI.Gradient(heading, Color3.new(1, 1, 1), WINDOW.title)
 local titleSize = Instance.new("UITextSizeConstraint")
 titleSize.MinTextSize, titleSize.MaxTextSize, titleSize.Parent = 24, 56, heading
 local icon = Instance.new("ImageLabel")
 icon.Name, icon.BackgroundTransparency, icon.ZIndex = "TitleIcon", 1, 6
 icon.AnchorPoint, icon.Size = Vector2.new(1, .5), UDim2.fromOffset(58, 58)
 icon.Image, icon.ScaleType = MENU_ICONS[name] or UI.Icons.Worlds, Enum.ScaleType.Fit
 icon.Parent = panel
 local function placeIcon()
  local width = math.min(heading.TextBounds.X, heading.AbsoluteSize.X) / math.max(panel.WindowScale.Scale, .01)
  icon.Position = heading.Position + UDim2.fromOffset(-width / 2 - 4, -2)
 end
 heading:GetPropertyChangedSignal("TextBounds"):Connect(placeIcon)
 placeIcon()
 sub = UI.Label(panel, "Subtitle", subtitle, 16, UI.Colors.Muted)
 sub.Position, sub.Size, sub.TextWrapped = UDim2.fromOffset(20, 74), UDim2.new(1, -40, 0, 28), true
 sub.TextXAlignment = Enum.TextXAlignment.Center
 local closer = closeButton(panel)
 closer.Position = UDim2.new(1, -34, 0, TITLE_RISE + 2)
 closer.Activated:Connect(close)
 return gui, panel, show
end

-- ---------- Showcase menus (Worlds, Inventory) ----------
-- A chunkier cartoon style: a big rounded title riding over the top edge, a grey rounded
-- window with a thick black outline holding a dark well, and a red rounded close button on the
-- top-right corner. Text uses ShowcaseFont with heavy black outlines.
UI.ShowcaseFont = Enum.Font.FredokaOne
UI.Showcase = {
 Window = Color3.fromRGB(72, 70, 80), -- the grey window frame
 Well = Color3.fromRGB(38, 39, 45), -- the dark area holding the content
 Outline = Color3.fromRGB(14, 14, 18),
 Card = Color3.fromRGB(88, 88, 98), -- an item card
 CardLight = Color3.fromRGB(150, 150, 160), -- an item card's rim
 Selected = Color3.fromRGB(170, 240, 255), -- the selected/equipped rim
 Value = Color3.fromRGB(110, 240, 60), -- multiplier text (green)
}
-- Button colours by kind: top and bottom of the face.
UI.ShowcaseButtons = {
 Blue = {Color3.fromRGB(70, 160, 255), Color3.fromRGB(30, 105, 235)},
 Red = {Color3.fromRGB(255, 80, 90), Color3.fromRGB(215, 25, 45)},
 Green = {Color3.fromRGB(120, 230, 70), Color3.fromRGB(50, 175, 40)},
 Grey = {Color3.fromRGB(160, 162, 172), Color3.fromRGB(110, 112, 122)},
}
local SHOWCASE_RISE = 44 -- how far the title rises above the window
-- Colour themes for showcase menus: the window's gradient (top, bottom), its faint checker
-- tint, the dark well, the title's gradient end colour, and a tint for cards and tabs.
UI.ShowcaseThemes = {
 Blue = {top = Color3.fromRGB(72, 150, 245), bottom = Color3.fromRGB(34, 86, 196), checker = Color3.fromRGB(10, 40, 110),
  well = Color3.fromRGB(22, 36, 74), title = Color3.fromRGB(150, 228, 255), tint = Color3.fromRGB(70, 120, 210)},
 Purple = {top = Color3.fromRGB(160, 100, 240), bottom = Color3.fromRGB(96, 52, 184), checker = Color3.fromRGB(50, 10, 100),
  well = Color3.fromRGB(38, 24, 66), title = Color3.fromRGB(255, 214, 120), tint = Color3.fromRGB(140, 90, 210)},
 Grey = {top = Color3.fromRGB(80, 78, 88), bottom = Color3.fromRGB(64, 62, 72), checker = Color3.new(0, 0, 0),
  well = Color3.fromRGB(38, 39, 45), title = Color3.new(1, 1, 1), tint = Color3.fromRGB(88, 88, 98)},
}

-- A label in the showcase style: rounded font, white, heavy black outline.
function UI.ShowcaseLabel(parent, name, text, size, color)
 local label = UI.Label(parent, name, text, size, color)
 label.Font = UI.ShowcaseFont
 local outline = label:FindFirstChildOfClass("UIStroke")
 outline.Thickness, outline.Color = math.clamp(size / 9, 2.5, 6), UI.Showcase.Outline
 return label
end

-- A rounded frame with a thick black outline.
function UI.ShowcaseFrame(parent, name, color, radius)
 local frame = Instance.new("Frame")
 frame.Name, frame.BorderSizePixel, frame.BackgroundColor3 = name, 0, color
 corner(frame, radius or 14)
 stroke(frame, UI.Showcase.Outline, 4)
 frame.Parent = parent
 return frame
end

-- A chunky rectangular button: coloured face with a faint stud pattern, a darker bottom edge,
-- a thick black outline and a big outlined caption. Set its look with UI.SetShowcaseButton.
function UI.ShowcaseButton(parent, name)
 local button = Instance.new("TextButton")
 button.Name, button.Text, button.AutoButtonColor, button.BackgroundTransparency = name, "", false, 1
 button.Parent = parent
 local visual = Instance.new("Frame")
 visual.Name, visual.AnchorPoint, visual.Position = "Visual", Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
 visual.Size, visual.BorderSizePixel, visual.BackgroundColor3 = UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1)
 visual.ClipsDescendants, visual.Parent = true, button
 corner(visual, 6)
 stroke(visual, UI.Showcase.Outline, 4)
 local gradient = UI.Gradient(visual, UI.ShowcaseButtons.Blue[1], UI.ShowcaseButtons.Blue[2])
 gradient.Name = "Face"
 local studs = damier(visual, Color3.new(1, 1, 1), 22, NumberSequence.new(.86, .9))
 studs.Name = "Studs"
 local edge = Instance.new("Frame")
 edge.Name, edge.BorderSizePixel, edge.Size, edge.Position = "Edge", 0, UDim2.new(1, 0, 0, 6), UDim2.new(0, 0, 1, -6)
 edge.BackgroundColor3, edge.BackgroundTransparency, edge.Parent = Color3.new(0, 0, 0), .7, visual
 rim(visual, 6, Color3.new(1, 1, 1), 2, .55, 4)
 local caption = UI.ShowcaseLabel(visual, "Caption", "", 34)
 caption.Size, caption.Position, caption.ZIndex = UDim2.new(1, -16, 1, -6), UDim2.fromOffset(8, 0), 3
 caption.TextXAlignment, caption.TextScaled = Enum.TextXAlignment.Center, true
 local limit = Instance.new("UITextSizeConstraint")
 limit.MaxTextSize, limit.Parent = 34, caption
 local scale = Instance.new("UIScale")
 scale.Name, scale.Parent = "ButtonScale", visual
 local function animate(value, duration, style)
  TweenService:Create(scale, TweenInfo.new(duration or .08, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = value}):Play()
 end
 button.MouseEnter:Connect(function() if button.Active then animate(1.04) end end)
 button.MouseLeave:Connect(function() animate(1) end)
 button.MouseButton1Down:Connect(function()
  if not button.Active then GameAudio.Play("Locked") return end
  playClick()
  animate(.95, .05)
 end)
 button.MouseButton1Up:Connect(function() animate(button.Active and 1.04 or 1, .12, Enum.EasingStyle.Back) end)
 return button
end

-- kind is a UI.ShowcaseButtons key; enabled sets whether a press does anything.
function UI.SetShowcaseButton(button, text, kind, enabled)
 local colors = UI.ShowcaseButtons[kind] or UI.ShowcaseButtons.Grey
 button.Active, button.Selectable = enabled, enabled
 button:SetAttribute("Kind", kind)
 button.Visual.Face.Color = ColorSequence.new(colors[1], colors[2])
 button.Visual.Caption.Text = text
end

-- The showcase close button: a red rounded square with a white X.
local function showcaseClose(parent)
 local button = Instance.new("TextButton")
 button.Name, button.Text, button.AutoButtonColor = "Close", "", false
 button.AnchorPoint, button.Size, button.ZIndex = Vector2.new(.5, .5), UDim2.fromOffset(64, 64), 25
 button.BackgroundColor3, button.BorderSizePixel = Color3.new(1, 1, 1), 0
 corner(button, 12)
 stroke(button, UI.Showcase.Outline, 4)
 UI.Gradient(button, Color3.fromRGB(255, 70, 90), Color3.fromRGB(220, 15, 45))
 rim(button, 8, Color3.new(1, 1, 1), 2, .5, 8).ZIndex = 26
 local x = UI.ShowcaseLabel(button, "X", "X", 50)
 x.Size, x.Position, x.ZIndex, x.TextXAlignment = UDim2.fromScale(1, 1), UDim2.fromOffset(0, -2), 27, Enum.TextXAlignment.Center
 local scale = Instance.new("UIScale")
 scale.Name, scale.Parent = "ButtonScale", button
 local function animate(value, duration, style)
  TweenService:Create(scale, TweenInfo.new(duration or .08, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = value}):Play()
 end
 button.MouseEnter:Connect(function() animate(1.06) end)
 button.MouseLeave:Connect(function() animate(1) end)
 button.MouseButton1Down:Connect(function() playClick() animate(.92, .05) end)
 button.MouseButton1Up:Connect(function() animate(1.06, .12, Enum.EasingStyle.Back) end)
 button.Parent = parent
 return button
end

-- A showcase modal. options: maxWidth / maxHeight (menu units), boxLeft (extra left inset for
-- tabs that stick out of the window), theme (a UI.ShowcaseThemes key, Grey by default).
-- Returns the ScreenGui, the panel, show(visible) and the window parts {box, title, titleIcon
-- (a holder left of the title, empty by default), theme}. Content is laid out in panel space;
-- the window's top edge is at y = SHOWCASE_RISE.
function UI.ShowcaseMenu(name, title, close, options)
 options = options or {}
 local theme = UI.ShowcaseThemes[options.theme or "Grey"]
 local gui, _, panel, show = modalShell(name, options.maxWidth or 860, options.maxHeight or 620)
 local left = 4 + (options.boxLeft or 0)
 local box = UI.ShowcaseFrame(panel, "Box", Color3.new(1, 1, 1), 16)
 box.BackgroundTransparency = UI.MenuBoxTransparency
 box.Position, box.Size = UDim2.fromOffset(left, SHOWCASE_RISE), UDim2.new(1, -left - 4, 1, -SHOWCASE_RISE - 4)
 UI.Gradient(box, theme.top, theme.bottom)
 damier(box, theme.checker, 30, NumberSequence.new(.9, .78)).Name = "Checker"
 rim(box, 8, Color3.new(1, 1, 1), 2, .65, 12)
 local heading = UI.ShowcaseLabel(panel, "Title", title, 72)
 UI.Gradient(heading, Color3.new(1, 1, 1), theme.title)
 heading.AnchorPoint, heading.ZIndex = Vector2.new(.5, .5), 5
 heading.Position, heading.Size = UDim2.new(.5, (options.boxLeft or 0) / 2, 0, SHOWCASE_RISE), UDim2.new(1, -220, 0, 80)
 heading.TextXAlignment, heading.TextScaled = Enum.TextXAlignment.Center, true
 local limit = Instance.new("UITextSizeConstraint")
 limit.MinTextSize, limit.MaxTextSize, limit.Parent = 30, 72, heading
 -- A soft drop shadow under the title.
 local shadow = UI.ShowcaseLabel(panel, "TitleShadow", title, 72, UI.Showcase.Outline)
 shadow.AnchorPoint, shadow.ZIndex, shadow.TextTransparency = Vector2.new(.5, .5), 4, .4
 shadow.Position, shadow.Size = heading.Position + UDim2.fromOffset(0, 5), heading.Size
 shadow.TextXAlignment, shadow.TextScaled = Enum.TextXAlignment.Center, true
 shadow:FindFirstChildOfClass("UIStroke").Transparency = .4
 limit:Clone().Parent = shadow
 heading:GetPropertyChangedSignal("Text"):Connect(function() shadow.Text = heading.Text end)
 local titleIcon = Instance.new("Frame")
 titleIcon.Name, titleIcon.BackgroundTransparency, titleIcon.ZIndex = "TitleIcon", 1, 6
 titleIcon.AnchorPoint, titleIcon.Size = Vector2.new(1, .5), UDim2.fromOffset(80, 80)
 titleIcon.Parent = panel
 -- Keeps the icon just left of the title's text, however wide the text is.
 local function placeIcon()
  local width = math.min(heading.TextBounds.X, heading.AbsoluteSize.X) / math.max(panel.WindowScale.Scale, .01)
  titleIcon.Position = heading.Position + UDim2.fromOffset(-width / 2 - 4, -4)
 end
 heading:GetPropertyChangedSignal("TextBounds"):Connect(placeIcon)
 placeIcon()
 local closer = showcaseClose(panel)
 closer.Position = UDim2.new(1, -38, 0, SHOWCASE_RISE + 2)
 closer.Activated:Connect(close)
 return gui, panel, show, {box = box, title = heading, titleIcon = titleIcon, top = SHOWCASE_RISE, left = left, theme = theme}
end

-- Featured icon over a continuously rotating sunburst (20 degrees per second while visible).
-- A cartoon clock filling parent: a white face with a thick blue rim and dark outline, hour marks,
-- blue hands at ten past ten, and the Power bolt tucked over its lower-right edge (Welcome Back:
-- time spent offline turned into Power).
function UI.ClockIcon(parent)
 local clock = Instance.new("Frame")
 clock.Name, clock.BackgroundTransparency = "Clock", 1
 clock.AnchorPoint, clock.Position, clock.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(1, 1)
 clock.Parent = parent
 local rim = Instance.new("Frame")
 rim.Name, rim.BorderSizePixel = "Rim", 0
 rim.AnchorPoint, rim.Position, rim.Size = Vector2.new(.5, .5), UDim2.fromScale(.46, .46), UDim2.fromScale(.86, .86)
 rim.BackgroundColor3 = Color3.new(1, 1, 1)
 Instance.new("UICorner", rim).CornerRadius = UDim.new(.5, 0)
 UI.Gradient(rim, Color3.fromRGB(120, 200, 255), Color3.fromRGB(30, 110, 230))
 stroke(rim, UI.Colors.Border, 3)
 rim.Parent = clock
 local face = Instance.new("Frame")
 face.Name, face.BorderSizePixel = "Face", 0
 face.AnchorPoint, face.Position, face.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.76, .76)
 face.BackgroundColor3 = Color3.new(1, 1, 1)
 Instance.new("UICorner", face).CornerRadius = UDim.new(.5, 0)
 UI.Gradient(face, Color3.new(1, 1, 1), Color3.fromRGB(214, 230, 245))
 stroke(face, Color3.fromRGB(20, 60, 140), 2)
 face.Parent = rim
 for hour = 1, 12 do
  local angle = math.rad(hour * 30)
  local mark = Instance.new("Frame")
  mark.BorderSizePixel, mark.BackgroundColor3 = 0, Color3.fromRGB(40, 70, 130)
  mark.AnchorPoint = Vector2.new(.5, .5)
  mark.Position = UDim2.fromScale(.5 + math.sin(angle) * .4, .5 - math.cos(angle) * .4)
  mark.Size = hour % 3 == 0 and UDim2.fromScale(.07, .07) or UDim2.fromScale(.04, .04)
  Instance.new("UICorner", mark).CornerRadius = UDim.new(.5, 0)
  mark.Parent = face
 end
 -- A hand grows from the centre toward rotation 0 = 12 o'clock.
 for _, hand in {{"MinuteHand", .36, .07, 60}, {"HourHand", .25, .09, -60}} do
  local pivot = Instance.new("Frame")
  pivot.Name, pivot.BackgroundTransparency = hand[1], 1
  pivot.AnchorPoint, pivot.Position, pivot.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(1, 1)
  pivot.Rotation, pivot.Parent = hand[4], face
  local bar = Instance.new("Frame")
  bar.BorderSizePixel, bar.BackgroundColor3 = 0, Color3.fromRGB(30, 90, 210)
  bar.AnchorPoint, bar.Position, bar.Size = Vector2.new(.5, 1), UDim2.fromScale(.5, .5), UDim2.fromScale(hand[3], hand[2])
  Instance.new("UICorner", bar).CornerRadius = UDim.new(.5, 0)
  stroke(bar, UI.Colors.Border, 1.5)
  bar.Parent = pivot
 end
 local cap = Instance.new("Frame")
 cap.Name, cap.BorderSizePixel, cap.BackgroundColor3 = "CenterCap", 0, Color3.fromRGB(30, 90, 210)
 cap.AnchorPoint, cap.Position, cap.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.14, .14)
 Instance.new("UICorner", cap).CornerRadius = UDim.new(.5, 0)
 stroke(cap, UI.Colors.Border, 1.5)
 cap.Parent = face
 local bolt = UI.Icon(clock, "Bolt", UI.Icons.Power)
 bolt.AnchorPoint, bolt.Position, bolt.Size = Vector2.new(.5, .5), UDim2.fromScale(.8, .74), UDim2.fromScale(.56, .56)
 bolt.Rotation, bolt.ZIndex = 12, 3
 return clock
end

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
 -- Refusals get a short negative tick and routine updates a soft notice. Level Up, Max Level,
 -- Rebirth, World unlock, Offline Training and purchases have their own payoff sounds where
 -- they happen, so their notices stay silent here. Nothing routine plays over a rare hit.
 if kind == "error" then
  GameAudio.Play("Invalid")
 elseif kind == nil and not GameAudio.CinematicActive() then
  GameAudio.Play("Notice")
 end
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
 -- Successes never pop up a notice: the result itself (an equipped item, the new World, Power or
 -- Cash on the HUD) and its sound are the confirmation.
 if kind == "success" then return end
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
 noticeIcon.Image = kind == "rebirth" and UI.Icons.Rebirth or UI.Icons.Power
 noticeSymbol.Visible = kind == "error"
 noticeIcon.Visible = not noticeSymbol.Visible
 noticeSymbol.Text, noticeSymbol.TextColor3 = "!", theme[2]
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
