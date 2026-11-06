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

-- One shared BlurEffect for menus, popups and unfocusing notices, so blurs never stack: open menus
-- hold it at full size, open popups (UI.RewardPopup) at the notices' size, otherwise a notice fades
-- it in and out (noticeBlur, 0-1) while it unfocuses. Closing the last one turns it off.
local MENU_BLUR, NOTICE_BLUR = 10, 9
local NOTICE_TINT = .45 -- opacity of the dark tint while a notice or popup unfocuses the screen
local modalScreens = {} -- open modal ScreenGui -> "menu" or "popup"
local blur
local noticeFocused, noticeBlur = false, 0
local function updateBlur()
 local menus, popups = false, false
 for _, kind in modalScreens do
  if kind == "popup" then popups = true else menus = true end
 end
 local wanted = menus or popups or noticeFocused
 if wanted and not blur then
  blur = Instance.new("BlurEffect")
  blur.Name, blur.Size, blur.Parent = "MenuBlur", MENU_BLUR, game:GetService("Lighting")
 end
 if blur then
  blur.Enabled = wanted
  blur.Size = menus and MENU_BLUR or popups and NOTICE_BLUR or NOTICE_BLUR * noticeBlur
 end
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
-- maxWidth x maxHeight menu units; onResize(scale, panel) runs after each resize. popup uses the
-- notices' lighter blur and tint (UI.RewardPopup) instead of a menu's. Returns the ScreenGui,
-- scrim, panel and show(visible).
local function modalShell(name, maxWidth, maxHeight, onResize, popup)
 local tint = popup and NOTICE_TINT or .35
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
  scrim.BackgroundTransparency = 1 - tint * math.clamp(amount, 0, 1)
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
  modalScreens[gui] = visible and (popup and "popup" or "menu") or nil
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

-- ---------- Colour cards (the Shop; for any menu on a dark Showcase window) ----------
-- Bold saturated cards: a gradient face in the palette's colours, a faint stud pattern, a lighter
-- inner rim and the thick dark outline. Cards never clip, so a big picture can overlap the edge.
-- Names are huge outlined labels tinted to the card (UI.CardTitle).
local STUDS = "rbxassetid://89044545794996" -- a white raised-stud tile (tinted and faded in use)
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
-- top / bottom: the face gradient (or colors: a left-to-right ColorSequence), rim: the inner
-- rim, name: the name's tint (light, deep).
UI.CardPalettes = {
 Green = {top = rgb(110, 225, 70), bottom = rgb(30, 145, 55), rim = rgb(190, 255, 150), name = {rgb(235, 255, 190), rgb(150, 255, 90)}},
 Teal = {top = rgb(50, 215, 190), bottom = rgb(15, 120, 130), rim = rgb(170, 255, 240), name = {rgb(225, 255, 250), rgb(110, 250, 225)}},
 Gold = {top = rgb(255, 208, 50), bottom = rgb(232, 128, 15), rim = rgb(255, 240, 160), name = {rgb(255, 252, 215), rgb(255, 220, 70)}},
 Orange = {top = rgb(255, 150, 40), bottom = rgb(205, 50, 20), rim = rgb(255, 210, 140), name = {rgb(255, 240, 190), rgb(255, 180, 60)}},
 Crimson = {top = rgb(240, 60, 90), bottom = rgb(145, 15, 45), rim = rgb(255, 160, 175), name = {rgb(255, 225, 230), rgb(255, 130, 150)}},
 Pink = {top = rgb(255, 120, 205), bottom = rgb(200, 40, 145), rim = rgb(255, 200, 240), name = {rgb(255, 235, 250), rgb(255, 170, 230)}},
 Purple = {top = rgb(165, 100, 255), bottom = rgb(85, 38, 195), rim = rgb(215, 185, 255), name = {rgb(245, 230, 255), rgb(205, 160, 255)}},
 Blue = {top = rgb(70, 170, 255), bottom = rgb(28, 78, 215), rim = rgb(170, 215, 255), name = {rgb(225, 245, 255), rgb(130, 210, 255)}},
 Rainbow = {colors = ColorSequence.new({ColorSequenceKeypoint.new(0, rgb(255, 80, 110)), ColorSequenceKeypoint.new(.2, rgb(255, 160, 50)),
  ColorSequenceKeypoint.new(.4, rgb(255, 215, 60)), ColorSequenceKeypoint.new(.6, rgb(90, 210, 90)), ColorSequenceKeypoint.new(.8, rgb(60, 160, 255)),
  ColorSequenceKeypoint.new(1, rgb(170, 90, 255))}), rim = rgb(255, 255, 255), name = {rgb(255, 255, 235), rgb(255, 225, 90)}},
}
-- Extra button faces for colour cards: Lime (buy), Purple (gift), Gold (owned / maxed).
UI.ShowcaseButtons.Lime = {rgb(185, 255, 70), rgb(75, 195, 25)}
UI.ShowcaseButtons.Purple = {rgb(195, 120, 255), rgb(125, 50, 220)}
UI.ShowcaseButtons.Gold = {rgb(255, 225, 80), rgb(235, 150, 20)}
-- Sticker colours (UI.CardBadge): face top and bottom.
UI.BadgeColors = {
 Soon = {rgb(110, 190, 255), rgb(40, 100, 230)}, Owned = {rgb(150, 245, 80), rgb(45, 170, 40)},
 Maxed = {rgb(255, 225, 80), rgb(235, 150, 20)}, Deal = {rgb(255, 90, 100), rgb(205, 20, 50)},
}

-- A faint tiled stud pattern filling parent (rounded to radius).
function UI.Pattern(parent, transparency, tile, radius)
 local image = Instance.new("ImageLabel")
 image.Name, image.BackgroundTransparency = "Pattern", 1
 image.Size, image.Image, image.ImageTransparency = UDim2.fromScale(1, 1), STUDS, transparency or .72
 image.ScaleType, image.TileSize = Enum.ScaleType.Tile, UDim2.fromOffset(tile or 34, tile or 34)
 corner(image, radius or 16)
 image.Parent = parent
 return image
end

-- A colour card (a UI.CardPalettes key). Returns the card and its palette.
function UI.ColorCard(parent, name, paletteName)
 local palette = UI.CardPalettes[paletteName] or UI.CardPalettes.Blue
 local card = Instance.new("Frame")
 card.Name, card.BorderSizePixel, card.BackgroundColor3 = name, 0, Color3.new(1, 1, 1)
 card:SetAttribute("Palette", paletteName)
 corner(card, 16)
 stroke(card, UI.Showcase.Outline, 4)
 local face = Instance.new("UIGradient")
 face.Name = "Face"
 if palette.colors then
  face.Color, face.Rotation = palette.colors, 0
 else
  face.Color, face.Rotation = ColorSequence.new(palette.top, palette.bottom), 90
 end
 face.Parent = card
 UI.Pattern(card)
 rim(card, 8, palette.rim, 3, .2, 11).Name = "Rim"
 card.Parent = parent
 return card, palette
end

-- A huge outlined name tinted to its card's palette (TextScaled up to size).
function UI.CardTitle(parent, name, text, size, palette)
 local label = UI.ShowcaseLabel(parent, name, text, size)
 label.TextScaled = true
 label:FindFirstChildOfClass("UIStroke").Thickness = math.clamp(size / 8, 3, 6)
 local limit = Instance.new("UITextSizeConstraint")
 limit.MaxTextSize, limit.MinTextSize, limit.Parent = size, 12, label
 if palette and palette.name then UI.Gradient(label, palette.name[1], palette.name[2]) end
 return label
end

-- A slowly turning sunburst filling parent, for featured items (it turns only while shown).
local spinners, spinning = {}, nil
local function onScreen(object)
 local ancestor = object
 while ancestor do
  if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
  if ancestor:IsA("LayerCollector") then return ancestor.Enabled end
  ancestor = ancestor.Parent
 end
 return false
end
function UI.Sunburst(parent, transparency)
 local burst = Instance.new("ImageLabel")
 burst.Name, burst.BackgroundTransparency = "Sunburst", 1
 burst.AnchorPoint, burst.Position, burst.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(1, 1)
 burst.Image, burst.ScaleType, burst.ImageTransparency = SUNBURST, Enum.ScaleType.Fit, transparency or .45
 local ratio = Instance.new("UIAspectRatioConstraint")
 ratio.AspectRatio, ratio.Parent = 1, burst
 burst.Parent = parent
 spinners[burst] = true
 burst.Destroying:Connect(function() spinners[burst] = nil end)
 if not spinning then
  spinning = game:GetService("RunService").RenderStepped:Connect(function(dt)
   for spinner in spinners do
    if onScreen(spinner) then spinner.Rotation = (spinner.Rotation + 12 * dt) % 360 end
   end
  end)
 end
 return burst
end

-- The colour cards' purchase button: the Robux icon and a price. set(state, text): "buy" (lime),
-- "soon" (blue: not on sale yet, still pressable to say so) or "owned" (gold, no icon, inactive).
function UI.PriceButton(parent, name, textSize)
 textSize = textSize or 30
 local button = UI.ShowcaseButton(parent, name)
 local visual = button.Visual
 visual.Caption.Visible = false
 local content = Instance.new("Frame")
 content.Name, content.BackgroundTransparency, content.ZIndex = "Content", 1, 3
 content.Size = UDim2.new(1, -8, 1, -6)
 content.Position = UDim2.fromOffset(4, 0)
 content.Parent = visual
 local row = Instance.new("UIListLayout")
 row.FillDirection, row.HorizontalAlignment = Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center
 row.VerticalAlignment, row.Padding, row.SortOrder = Enum.VerticalAlignment.Center, UDim.new(0, 6), Enum.SortOrder.LayoutOrder
 row.Parent = content
 -- The white Robux icon over a dark copy a little larger, as its outline.
 local iconSize = math.floor(textSize * 1.05)
 local robux = Instance.new("Frame")
 robux.Name, robux.BackgroundTransparency, robux.Size, robux.ZIndex = "Robux", 1, UDim2.fromOffset(iconSize, iconSize), 3
 robux.Parent = content
 local shade = UI.Icon(robux, "Outline", UI.Icons.Robux)
 shade.AnchorPoint, shade.Position, shade.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.new(1, 5, 1, 5)
 shade.ImageColor3, shade.ZIndex = UI.Showcase.Outline, 3
 local icon = UI.Icon(robux, "Icon", UI.Icons.Robux)
 icon.Size, icon.ZIndex = UDim2.fromScale(1, 1), 4
 local price = UI.ShowcaseLabel(content, "Price", "", textSize)
 price.AutomaticSize, price.Size, price.LayoutOrder, price.ZIndex = Enum.AutomaticSize.X, UDim2.new(0, 0, 1, 0), 2, 4
 local function set(state, text)
  UI.SetShowcaseButton(button, "", state == "buy" and "Lime" or state == "soon" and "Blue" or "Gold", state ~= "owned")
  button:SetAttribute("PriceState", state)
  robux.Visible, price.Text = state ~= "owned", text
 end
 set("buy", "")
 return button, set
end

-- A small square purple Gift button (a wrapped present); soon adds a SOON note under it.
function UI.GiftButton(parent, name, soon)
 local button = UI.ShowcaseButton(parent, name or "Gift")
 UI.SetShowcaseButton(button, "", "Purple", true)
 local present = UI.Icon(button.Visual, "GiftIcon", UI.Icons.Rewards)
 present.AnchorPoint, present.Position, present.ZIndex = Vector2.new(.5, .5), UDim2.fromScale(.5, soon and .4 or .46), 4
 present.Size = UDim2.fromScale(soon and .62 or .76, soon and .62 or .76)
 if soon then
  local note = UI.ShowcaseLabel(button.Visual, "Soon", "SOON", 14)
  note.AnchorPoint, note.Position, note.Size, note.ZIndex = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, -5), UDim2.new(1, 0, 0, 14), 5
  note.TextXAlignment = Enum.TextXAlignment.Center
 end
 return button
end

-- A white rounded tile showing one item of a pack: picture (an image id, or a function(parent)
-- returning a GuiObject) over its quantity ("x10K", "+1").
function UI.ItemTile(parent, name, quantity, picture)
 local tile = Instance.new("Frame")
 tile.Name, tile.BorderSizePixel, tile.BackgroundColor3 = name, 0, Color3.new(1, 1, 1)
 corner(tile, 12)
 stroke(tile, UI.Showcase.Outline, 3)
 UI.Gradient(tile, Color3.new(1, 1, 1), rgb(205, 218, 238))
 local art = type(picture) == "string" and UI.Icon(tile, "Icon", picture) or picture(tile)
 art.AnchorPoint, art.Position, art.Size, art.ZIndex = Vector2.new(.5, .5), UDim2.fromScale(.5, .4), UDim2.fromScale(.78, .74), 2
 local count = UI.ShowcaseLabel(tile, "Quantity", quantity, 24)
 count.AnchorPoint, count.Position, count.Size, count.ZIndex = Vector2.new(.5, 1), UDim2.new(.5, 0, 1, 3), UDim2.new(1, 6, .42, 0), 3
 count.TextXAlignment, count.TextScaled = Enum.TextXAlignment.Center, true
 local limit = Instance.new("UITextSizeConstraint")
 limit.MaxTextSize, limit.Parent = 24, count
 tile.Parent = parent
 return tile
end

-- A tilted sticker on a card's top corner (side "right" or "left"); kind is a UI.BadgeColors key.
-- set(text, kind) changes it; an empty text hides it.
function UI.CardBadge(parent, name, side)
 local right = side ~= "left"
 local badge = Instance.new("Frame")
 badge.Name, badge.BorderSizePixel, badge.BackgroundColor3, badge.ZIndex = name, 0, Color3.new(1, 1, 1), 8
 badge.AnchorPoint = Vector2.new(right and 1 or 0, 0)
 badge.Position = right and UDim2.new(1, 8, 0, -12) or UDim2.fromOffset(-8, -12)
 badge.Size, badge.AutomaticSize, badge.Rotation = UDim2.fromOffset(0, 32), Enum.AutomaticSize.X, right and 7 or -7
 corner(badge, 10)
 stroke(badge, UI.Showcase.Outline, 3)
 local face = UI.Gradient(badge, UI.BadgeColors.Soon[1], UI.BadgeColors.Soon[2])
 local padding = Instance.new("UIPadding")
 padding.PaddingLeft, padding.PaddingRight, padding.Parent = UDim.new(0, 12), UDim.new(0, 12), badge
 local text = UI.ShowcaseLabel(badge, "Text", "", 22)
 text.AutomaticSize, text.Size, text.ZIndex = Enum.AutomaticSize.X, UDim2.new(0, 0, 1, -2), 9
 badge.Parent = parent
 return badge, function(value, kind)
  local colors = UI.BadgeColors[kind] or UI.BadgeColors.Soon
  face.Color = ColorSequence.new(colors[1], colors[2])
  text.Text, badge.Visible = value or "", value ~= nil and value ~= ""
 end
end

-- A crossed-out Robux price (a real comparison only, such as the items bought separately).
function UI.StrikePrice(parent, name, textSize)
 textSize = textSize or 26
 local holder = Instance.new("Frame")
 holder.Name, holder.BackgroundTransparency = name, 1
 holder.Size, holder.AutomaticSize = UDim2.fromOffset(0, textSize + 6), Enum.AutomaticSize.X
 -- The icon and price sit in a row; the bar lies over the row, outside its layout.
 local content = Instance.new("Frame")
 content.Name, content.BackgroundTransparency = "Row", 1
 content.Size, content.AutomaticSize = UDim2.new(0, 0, 1, 0), Enum.AutomaticSize.X
 content.Parent = holder
 local row = Instance.new("UIListLayout")
 row.FillDirection, row.VerticalAlignment, row.Padding = Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center, UDim.new(0, 3)
 row.SortOrder, row.Parent = Enum.SortOrder.LayoutOrder, content
 local icon = UI.Icon(content, "Robux", UI.Icons.Robux)
 icon.Size = UDim2.fromOffset(textSize - 4, textSize - 4)
 local text = UI.ShowcaseLabel(content, "Price", "", textSize)
 text.AutomaticSize, text.Size, text.LayoutOrder = Enum.AutomaticSize.X, UDim2.new(0, 0, 1, 0), 2
 local bar = Instance.new("Frame")
 bar.Name, bar.BorderSizePixel, bar.BackgroundColor3, bar.ZIndex = "Strike", 0, rgb(230, 25, 50), 6
 bar.AnchorPoint, bar.Position, bar.Size, bar.Rotation = Vector2.new(.5, .5), UDim2.fromScale(.5, .55), UDim2.new(1, 8, 0, 3), -12
 corner(bar, 2)
 stroke(bar, UI.Showcase.Outline, 1.5)
 bar.Parent = holder
 holder.Parent = parent
 return holder, function(value)
  text.Text, holder.Visible = value or "", value ~= nil
 end
end

-- ---------- Reward popup (Welcome Back; any "here is what you got" moment) ----------
-- Feels like a notification rather than a menu: the notices' blur and tint over the game, a
-- translucent dark panel with a thick dark outline, a big outlined title riding over its top
-- edge with an icon breaking out of the top-left corner, a line under it, a big picture over a
-- slowly turning sunburst, a large gold amount that counts up, small detail lines, and one row of
-- buttons: an optional rainbow offer button (its total, a Robux price badge on its corner) beside
-- a lime claim button, which stands alone and centred when there is no offer. There is no close
-- button: the caller closes it from the claim button.
-- options: title, subtitle, icon (function(holder) drawing the corner icon), picture (an image
-- id), suffix (after the amount, such as " POWER"), claimText (default "Claim!").
-- Returns a table:
--   gui, panel, claim, offer         the ScreenGui, the panel and the two buttons
--   show(visible)                    open / close (the blur and tint go with it)
--   setDetails(lines)                the small lines under the amount: strings or {text, color}
--   setOffer(text, price)            show the offer button with text and a Robux price (nil: SOON);
--                                    setOffer(nil) hides it
--   countTo(value, seconds, onDone)  count the amount up from what it shows now to value
--   setAmount(value)                 show value at once
--   celebrate()                      sparks out of the picture, a pop and the reward chime
local POPUP_RISE = 62 -- how far the title rises above the panel
-- Vertical layout (menu units): the subtitle's centre and the picture's top below the panel's
-- top edge, the button height and bottom margin, a detail line, the gap above the buttons (more
-- beside the offer's price badge) and the amount's height. Compact is for short screens.
local POPUP_ROOMY = {subtitle = 72, subtitleHeight = 40, hero = 94, button = 78, bottom = 24, line = 28, gap = 14, badgeGap = 30, amount = 72}
local POPUP_COMPACT = {subtitle = 54, subtitleHeight = 30, hero = 72, button = 62, bottom = 14, line = 22, gap = 10, badgeGap = 26, amount = 56}
local POPUP_GOLD = {rgb(255, 238, 120), rgb(255, 174, 20)}
function UI.RewardPopup(name, options)
 local popup, layout = {}, nil
 local gui, _, panel, show = modalShell(name, 800, 540, function() if layout then layout() end end, true)
 popup.gui, popup.panel, popup.show = gui, panel, show
 local box = UI.ShowcaseFrame(panel, "Box", rgb(40, 42, 52), 10)
 box.BackgroundTransparency = .22
 box:FindFirstChildOfClass("UIStroke").Thickness = 6
 rim(box, 7, Color3.new(1, 1, 1), 2, .86, 6)
 -- One line each, at the largest size (up to size) that fits the label's width: measured with
 -- TextService, because TextScaled would wrap the title onto two lines on a narrow phone.
 local TextService = game:GetService("TextService")
 local fitted = {}
 local function fit(label)
  local width, height = label.Size.X.Offset, label.Size.Y.Offset
  if width <= 0 then return end
  local natural = TextService:GetTextSize(label.Text, 100, label.Font, Vector2.new(1e6, 1e6)).X / 100
  local largest = math.max(10, math.min(fitted[label], height * .95))
  label.TextSize = natural > 0 and math.clamp(math.floor(width * .92 / natural), 10, largest) or largest
 end
 local function scaledLabel(labelName, text, size)
  local label = UI.ShowcaseLabel(panel, labelName, text, size)
  label.AnchorPoint, label.TextXAlignment, label.ZIndex = Vector2.new(.5, .5), Enum.TextXAlignment.Center, 5
  label.TextScaled, label.TextWrapped = false, false
  fitted[label] = size
  label:GetPropertyChangedSignal("Text"):Connect(function() fit(label) end)
  label:GetPropertyChangedSignal("Size"):Connect(function() fit(label) end)
  return label
 end
 -- Title, with a soft drop shadow (as on the showcase menus).
 local title = scaledLabel("Title", options.title or "", 84)
 title:FindFirstChildOfClass("UIStroke").Thickness = 7
 local shadow = scaledLabel("TitleShadow", options.title or "", 84)
 shadow.ZIndex, shadow.TextColor3, shadow.TextTransparency = 4, UI.Showcase.Outline, .4
 local shadowStroke = shadow:FindFirstChildOfClass("UIStroke")
 shadowStroke.Thickness, shadowStroke.Transparency = 7, .4
 local iconHolder = Instance.new("Frame")
 iconHolder.Name, iconHolder.BackgroundTransparency, iconHolder.ZIndex = "TitleIcon", 1, 6
 iconHolder.AnchorPoint, iconHolder.Parent = Vector2.new(.5, .5), panel
 if options.icon then options.icon(iconHolder) end
 local subtitle = scaledLabel("Subtitle", options.subtitle or "", 34)
 -- The picture over its sunburst.
 local hero = Instance.new("Frame")
 hero.Name, hero.BackgroundTransparency, hero.AnchorPoint, hero.ZIndex = "Hero", 1, Vector2.new(.5, .5), 2
 hero.Parent = panel
 local burst = UI.Sunburst(hero, .3)
 burst.ZIndex = 2
 local picture = UI.Icon(hero, "Picture", options.picture or "")
 picture.AnchorPoint, picture.Position, picture.Size, picture.ZIndex = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.6, .6), 3
 -- The amount: big gold outlined text that pops when it lands.
 local suffix = options.suffix or ""
 local amount = scaledLabel("Amount", "", 68)
 amount:FindFirstChildOfClass("UIStroke").Thickness = 6
 UI.Gradient(amount, POPUP_GOLD[1], POPUP_GOLD[2])
 local pop = Instance.new("UIScale")
 pop.Name, pop.Parent = "Pop", amount
 local details = Instance.new("Frame")
 details.Name, details.BackgroundTransparency, details.Parent = "Details", 1, panel
 local stack = Instance.new("UIListLayout")
 stack.SortOrder, stack.HorizontalAlignment, stack.Parent = Enum.SortOrder.LayoutOrder, Enum.HorizontalAlignment.Center, details
 -- Buttons: the rainbow offer (with its price badge) and the lime claim.
 local offer = UI.ShowcaseButton(panel, "Offer")
 UI.SetShowcaseButton(offer, "", "Blue", true)
 offer.Visual.Face.Color, offer.Visual.Face.Rotation = UI.CardPalettes.Rainbow.colors, 0
 offer.Visual.Caption:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 40
 -- Above the claim button, so the price badge on its corner is never covered.
 offer.ZIndex, offer.Visible = 6, false
 local badge = Instance.new("Frame")
 badge.Name, badge.BorderSizePixel, badge.BackgroundColor3, badge.ZIndex = "PriceBadge", 0, UI.Showcase.Outline, 8
 badge.AnchorPoint, badge.Position, badge.Rotation = Vector2.new(1, .5), UDim2.new(1, 16, 0, 0), 8
 badge.Size, badge.AutomaticSize = UDim2.fromOffset(0, 40), Enum.AutomaticSize.X
 corner(badge, 20)
 stroke(badge, Color3.new(1, 1, 1), 2, .5)
 local badgePadding = Instance.new("UIPadding")
 badgePadding.PaddingLeft, badgePadding.PaddingRight, badgePadding.Parent = UDim.new(0, 10), UDim.new(0, 12), badge
 local badgeRow = Instance.new("UIListLayout")
 badgeRow.FillDirection, badgeRow.VerticalAlignment, badgeRow.Padding = Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center, UDim.new(0, 4)
 badgeRow.SortOrder, badgeRow.Parent = Enum.SortOrder.LayoutOrder, badge
 local badgeRobux = UI.Icon(badge, "Robux", UI.Icons.Robux)
 badgeRobux.Size, badgeRobux.ImageColor3, badgeRobux.ZIndex = UDim2.fromOffset(26, 26), UI.ShowcaseButtons.Lime[1], 9
 local badgePrice = UI.ShowcaseLabel(badge, "Price", "", 28, UI.ShowcaseButtons.Lime[1])
 badgePrice.AutomaticSize, badgePrice.Size, badgePrice.LayoutOrder, badgePrice.ZIndex = Enum.AutomaticSize.X, UDim2.new(0, 0, 1, 0), 2, 9
 badge.Parent = offer
 local claim = UI.ShowcaseButton(panel, "Claim")
 UI.SetShowcaseButton(claim, options.claimText or "Claim!", "Lime", true)
 claim.Visual.Caption:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 40
 claim.ZIndex = 5
 popup.claim, popup.offer = claim, offer

 local lineCount = 0
 layout = function()
  local width, height = panel.Size.X.Offset, panel.Size.Y.Offset
  box.Position, box.Size = UDim2.fromOffset(0, POPUP_RISE), UDim2.fromOffset(width, height - POPUP_RISE)
  local iconSize = width < 560 and 104 or 128
  iconHolder.Size = UDim2.fromOffset(iconSize, iconSize)
  iconHolder.Position = UDim2.fromOffset(iconSize / 2 + 6, math.max(iconSize / 2 + 2, POPUP_RISE + 4))
  -- The title is centred in the space right of the icon.
  local titleLeft = iconSize + 10
  local titleWidth = width - titleLeft - 20
  title.Position, title.Size = UDim2.fromOffset(titleLeft + titleWidth / 2, POPUP_RISE), UDim2.fromOffset(titleWidth, 92)
  shadow.Position, shadow.Size = title.Position + UDim2.fromOffset(0, 6), title.Size
  -- Short screens (phones held sideways) tighten every gap so the picture keeps its room.
  local m = height < 520 and POPUP_COMPACT or POPUP_ROOMY
  subtitle.Position, subtitle.Size = UDim2.fromOffset(width / 2, POPUP_RISE + m.subtitle), UDim2.fromOffset(width - 48, m.subtitleHeight)
  -- Buttons along the bottom.
  local buttonHeight = m.button
  local buttonsTop = height - m.bottom - buttonHeight
  if offer.Visible then
   local offerWidth = math.floor((width - 64) * .58)
   offer.Position, offer.Size = UDim2.fromOffset(24, buttonsTop - 2), UDim2.fromOffset(offerWidth, buttonHeight + 4)
   claim.Position, claim.Size = UDim2.fromOffset(40 + offerWidth, buttonsTop + 4), UDim2.fromOffset(width - 64 - offerWidth, buttonHeight - 8)
  else
   local claimWidth = math.min(340, width - 48)
   claim.Position, claim.Size = UDim2.fromOffset((width - claimWidth) / 2, buttonsTop), UDim2.fromOffset(claimWidth, buttonHeight)
  end
  -- Detail lines, then the amount, above the buttons; the picture fills the space left.
  -- (The offer's price badge rises 20 above the buttons, so the lines sit higher beside it.)
  local detailsHeight = lineCount * m.line
  local detailsTop = buttonsTop - (offer.Visible and m.badgeGap or m.gap) - detailsHeight
  details.Position, details.Size = UDim2.fromOffset(24, detailsTop), UDim2.fromOffset(width - 48, detailsHeight)
  for _, line in details:GetChildren() do
   if line:IsA("GuiObject") then line.Size = UDim2.new(1, 0, 0, m.line) end
  end
  local amountTop = detailsTop - m.amount
  amount.Position, amount.Size = UDim2.fromOffset(width / 2, amountTop + m.amount / 2), UDim2.fromOffset(width - 48, m.amount)
  local heroTop = POPUP_RISE + m.hero
  local space = math.clamp(amountTop - heroTop, 60, 240)
  hero.Position, hero.Size = UDim2.fromOffset(width / 2, heroTop + (amountTop - heroTop) / 2), UDim2.fromOffset(space * 1.45, space * 1.45)
 end

 function popup.setDetails(lines)
  for _, child in details:GetChildren() do
   if child:IsA("GuiObject") then child:Destroy() end
  end
  lineCount = #lines
  for index, line in lines do
   local text, color = line, nil
   if type(line) == "table" then text, color = line.text, line.color end
   local label = UI.ShowcaseLabel(details, "Line" .. index, text, 22, color or rgb(226, 230, 242))
   label.Size, label.LayoutOrder, label.TextXAlignment, label.ZIndex = UDim2.new(1, 0, 0, 28), index, Enum.TextXAlignment.Center, 5
   label.TextScaled = true
   local limit = Instance.new("UITextSizeConstraint")
   limit.MaxTextSize, limit.Parent = 22, label
  end
  layout()
 end

 function popup.setOffer(text, price)
  offer.Visible = text ~= nil
  offer.Visual.Caption.Text = text or ""
  badgeRobux.Visible = price ~= nil
  badgePrice.Text = price and UI.Number(price) or "SOON"
  badgePrice.TextColor3 = price and UI.ShowcaseButtons.Lime[1] or UI.BadgeColors.Soon[1]
  layout()
 end

 local shown, countVersion = 0, 0
 function popup.setAmount(value)
  countVersion += 1
  shown = value
  amount.Text = "+" .. UI.Number(value) .. suffix
 end
 function popup.countTo(value, seconds, onDone)
  countVersion += 1
  local version, from, began = countVersion, shown, os.clock()
  seconds = seconds or .9
  task.spawn(function()
   while version == countVersion do
    local progress = seconds > 0 and math.min(1, (os.clock() - began) / seconds) or 1
    -- Eases out, so it rushes up and settles on the exact value.
    shown = progress >= 1 and value or math.floor(from + (value - from) * (1 - (1 - progress) ^ 3))
    amount.Text = "+" .. UI.Number(shown) .. suffix
    if progress >= 1 then break end
    GameAudio.Play("PowerTick")
    game:GetService("RunService").RenderStepped:Wait()
   end
   if version ~= countVersion then return end
   pop.Scale = 1.18
   TweenService:Create(pop, TweenInfo.new(.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
   if onDone then onDone() end
  end)
 end

 function popup.celebrate()
  GameAudio.Play("OfflineReward")
  burst.Size = UDim2.fromScale(1.35, 1.35)
  TweenService:Create(burst, TweenInfo.new(.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1, 1)}):Play()
  for index = 1, 18 do
   local spark = Instance.new("Frame")
   spark.Name, spark.BorderSizePixel, spark.ZIndex, spark.Rotation = "Spark", 0, 6, 45
   spark.BackgroundColor3 = index % 3 == 0 and Color3.new(1, 1, 1) or index % 3 == 1 and POPUP_GOLD[1] or UI.ShowcaseButtons.Lime[1]
   spark.AnchorPoint, spark.Position, spark.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromOffset(16, 16)
   corner(spark, 4)
   spark.Parent = hero
   local angle = index / 18 * math.pi * 2 + math.random() * .3
   local reach = .42 + math.random() * .2
   TweenService:Create(spark, TweenInfo.new(.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Position = UDim2.fromScale(.5 + math.cos(angle) * reach, .5 + math.sin(angle) * reach),
    BackgroundTransparency = 1, Size = UDim2.fromOffset(5, 5), Rotation = 225}):Play()
   game:GetService("Debris"):AddItem(spark, .75)
  end
 end

 task.defer(layout)
 return popup
end

-- Notices float as big outlined text in the middle of the screen, with no panel behind them.
-- Errors, Rebirth complete and World unlocks also unfocus the screen (the shared blur and a dark
-- tint); routine notices only float. A notice never takes input: players keep moving and
-- clicking, and any tap or click dismisses it early. A new notice replaces the old one.
--   kind: the title, its color and icon (icon: an image id, or "lock" / "alert", drawn here)
--   focus: blur and tint behind it; seconds: how long it stays (default NOTICE_SECONDS)
local NOTICE_KINDS = {
 locked = {title = "LOCKED", color = BUTTON_STATES.Locked[1], icon = "lock", focus = true},
 cash = {title = "NOT ENOUGH CASH", color = UI.Colors.Gold, icon = UI.Icons.Cash, focus = true},
 error = {title = "CAN'T DO THAT", color = BUTTON_STATES.Locked[1], icon = "alert", focus = true},
 unlock = {title = "WORLD COMPLETE!", color = BUTTON_STATES.Cyan[1], icon = UI.Icons.Worlds, focus = true, seconds = 8},
 rebirth = {title = "REBIRTH COMPLETE", color = Color3.fromRGB(190, 90, 255), icon = UI.Icons.Rebirth, focus = true},
 level = {title = "LEVEL UP!", color = BUTTON_STATES.Claim[1], icon = UI.Icons.Power},
 cap = {title = "MAX LEVEL REACHED", color = UI.Colors.Gold, icon = UI.Icons.Power},
 offline = {title = "OFFLINE TRAINING", color = BUTTON_STATES.Claim[1], icon = UI.Icons.Power, seconds = 8},
 -- Playtime Rewards (PlaytimeRewardsClient): never blurred, they only float.
 rewardReady = {title = "REWARD READY!", color = UI.Colors.Gold, icon = UI.Icons.Rewards},
 rewardClaimed = {title = "REWARD CLAIMED!", color = BUTTON_STATES.Claim[1], icon = UI.Icons.Rewards},
}
local NOTICE_DEFAULT = {title = "HEADS UP", color = BUTTON_STATES.Cyan[1]}
-- Requirement units: how the required value reads, its highlight color, and whether the bar
-- shows a count ("7 / 10") or a percentage.
local NOTICE_UNITS = {
 Rebirths = {color = UI.Colors.Gold, count = true, verb = "needs", action = "to unlock",
  value = function(n) return UI.Number(n) .. (n == 1 and " Rebirth" or " Rebirths") end},
 Level = {color = UI.Colors.Gold, count = true, verb = "needs", action = "to go",
  value = function(n) return "Level " .. UI.Number(n) end,
  more = function(n) return UI.Number(n) .. (n == 1 and " more Level" or " more Levels") end},
 Cash = {color = BUTTON_STATES.Claim[1], verb = "costs", action = "to go",
  value = function(n) return "$" .. UI.Compact(n) end},
}
local NOTICE_SECONDS, NOTICE_DETAIL_SECONDS = 2, 2.6
local NOTICE_WIDTH = 640
local TITLE_SIZE, ICON_SIZE, ICON_GAP = 56, 56, 12
local BAR_WIDTH, BAR_HEIGHT = 300, 18
local SHADOW = Vector2.new(0, 4)

local function hex(color)
 return string.format("#%02X%02X%02X", math.floor(color.R * 255 + .5), math.floor(color.G * 255 + .5), math.floor(color.B * 255 + .5))
end
local function escapeRich(text)
 return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
local function colored(text, color)
 return '<font color="' .. hex(color) .. '">' .. escapeRich(text) .. "</font>"
end
-- Rich text for a plain message, with the first occurrence of highlight colored.
local function highlighted(text, highlight, color)
 if type(highlight) ~= "string" or highlight == "" then return escapeRich(text) end
 local first, last = text:find(highlight, 1, true)
 if not first then return escapeRich(text) end
 return escapeRich(text:sub(1, first - 1)) .. colored(highlight, color) .. escapeRich(text:sub(last + 1))
end
local function finite(value)
 return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

-- What a notice shows: the theme, the message as rich text and plain text, and the progress bar
-- (nil without numbers). details (optional): kind, title, item, unit, required, current, text
-- ("%s" marks the highlighted value), highlight (a part of the message to color), action.
local function noticeContent(message, kind, details)
 local theme = NOTICE_KINDS[details and details.kind] or NOTICE_KINDS[kind] or NOTICE_DEFAULT
 local title = details and type(details.title) == "string" and details.title or theme.title
 local text = type(message) == "string" and message or ""
 local rich = escapeRich(text)
 local unit = details and NOTICE_UNITS[details.unit]
 local progress
 if unit and finite(details.required) and details.required > 0 then
  local value = unit.value(details.required)
  local template = type(details.text) == "string" and details.text
   or (type(details.item) == "string" and details.item .. " " .. unit.verb .. " %s")
  if template and template:find("%s", 1, true) then
   local before, after = template:match("^(.-)%%s(.*)$")
   text = before .. value .. after
   rich = escapeRich(before) .. colored(value, unit.color) .. escapeRich(after)
  end
  if finite(details.current) then
   local current = math.max(0, details.current)
   local remaining = math.max(0, details.required - current)
   local share = math.clamp(current / details.required, 0, 1)
   local count = unit.count and UI.Number(math.min(current, details.required)) .. " / " .. UI.Number(details.required)
    or math.floor(share * 100) .. "%"
   local more = unit.more and unit.more(remaining) or (unit.count and UI.Number(remaining) .. " more " .. details.unit
    or unit.value(remaining) .. " more")
   if unit.count and remaining == 1 and not unit.more then more = "1 more " .. details.unit:gsub("s$", "") end
   progress = {share = share, count = count, remaining = more .. " " .. (type(details.action) == "string" and details.action or unit.action)}
  end
 elseif details then
  rich = highlighted(text, details.highlight, UI.Colors.Gold)
 end
 return theme, title, rich, text, progress
end

-- A label with a soft drop shadow (a dark copy just below it) inside a holder Frame.
local function shadowedLabel(parent, name, size, color)
 local holder = Instance.new("Frame")
 holder.Name, holder.BackgroundTransparency, holder.Size = name, 1, UDim2.fromScale(1, 0)
 holder.AutomaticSize, holder.Parent = Enum.AutomaticSize.Y, parent
 local labels = {}
 for index, role in {"Shadow", "Text"} do
  local label = UI.Label(holder, role, "", size, role == "Shadow" and UI.Colors.Border or color)
  label.Size, label.AutomaticSize = UDim2.fromScale(1, 0), Enum.AutomaticSize.Y
  label.TextXAlignment, label.TextWrapped, label.RichText = Enum.TextXAlignment.Center, true, true
  label.ZIndex = index
  if role == "Shadow" then
   label.Position, label.TextTransparency = UDim2.fromOffset(SHADOW.X, SHADOW.Y), .5
   label:FindFirstChildOfClass("UIStroke").Transparency = .5
  end
  labels[role] = label
 end
 return holder, function(rich, textColor)
  labels.Text.Text = rich
  if textColor then labels.Text.TextColor3 = textColor end
  -- The shadow is one dark shape, so its copy drops the color tags.
  labels.Shadow.Text = rich:gsub("<font[^>]*>", ""):gsub("</font>", "")
 end, labels
end

-- A padlock drawn from Frames: a red body with a keyhole under a steel shackle.
local function lockIcon(parent)
 local lock = Instance.new("Frame")
 lock.Name, lock.BackgroundTransparency, lock.Size = "Lock", 1, UDim2.fromScale(1, 1)
 lock.Parent = parent
 for _, layer in {{"ShackleOutline", UI.Colors.Border, 9}, {"Shackle", Color3.fromRGB(205, 212, 224), 4}} do
  local shackle = Instance.new("Frame")
  shackle.Name, shackle.BackgroundTransparency = layer[1], 1
  shackle.AnchorPoint, shackle.Position, shackle.Size = Vector2.new(.5, 0), UDim2.fromScale(.5, .06), UDim2.fromScale(.5, .62)
  Instance.new("UICorner", shackle).CornerRadius = UDim.new(.5, 0)
  stroke(shackle, layer[2], layer[3])
  shackle.Parent = lock
 end
 local body = Instance.new("Frame")
 body.Name, body.BorderSizePixel, body.BackgroundColor3 = "Body", 0, Color3.new(1, 1, 1)
 body.AnchorPoint, body.Position, body.Size = Vector2.new(.5, 1), UDim2.fromScale(.5, .98), UDim2.fromScale(.82, .54)
 corner(body, 8)
 UI.Gradient(body, BUTTON_STATES.Locked[1], BUTTON_STATES.Locked[2])
 stroke(body, UI.Colors.Border, 3)
 body.Parent = lock
 local hole = Instance.new("Frame")
 hole.Name, hole.BorderSizePixel, hole.BackgroundColor3 = "Keyhole", 0, UI.Colors.Border
 hole.AnchorPoint, hole.Position, hole.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .42), UDim2.fromScale(.22, .3)
 Instance.new("UICorner", hole).CornerRadius = UDim.new(.5, 0)
 hole.Parent = body
 local slot = hole:Clone()
 slot.Name, slot.Position, slot.Size = "KeySlot", UDim2.fromScale(.5, .64), UDim2.fromScale(.1, .34)
 slot.Parent = body
 return lock
end

-- A red warning badge: a round outlined disc with a "!".
local function alertIcon(parent)
 local badge = Instance.new("Frame")
 badge.Name, badge.BorderSizePixel, badge.BackgroundColor3 = "Alert", 0, Color3.new(1, 1, 1)
 badge.AnchorPoint, badge.Position, badge.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromScale(.9, .9)
 Instance.new("UICorner", badge).CornerRadius = UDim.new(.5, 0)
 UI.Gradient(badge, BUTTON_STATES.Locked[1], BUTTON_STATES.Locked[2])
 stroke(badge, UI.Colors.Border, 3)
 badge.Parent = parent
 local mark = UI.Label(badge, "Mark", "!", 38)
 mark.Size, mark.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
 return badge
end

local notice -- the built notice's parts (made on the first notice)
local noticeVersion, noticeTween, noticeShownAt = 0, nil, 0
local previousText, previousTime = "", 0

-- True while a Legendary / Mythic Hit or the portal trip has the screen.
local function cinematicPlaying()
 return GameAudio.CinematicActive() or player:GetAttribute("CinematicCamera") ~= nil
  or player:GetAttribute("PortalJourney") ~= nil
end

local function hideNotice(seconds)
 if not notice then return end
 noticeVersion += 1
 local version = noticeVersion
 if noticeTween then noticeTween:Cancel() end
 local function finish()
  notice.frame.Visible, notice.tint.Visible = false, false
  noticeFocused, noticeBlur = false, 0
  notice.fade.Value = 0
  updateBlur()
 end
 if seconds <= 0 then return finish() end
 noticeTween = TweenService:Create(notice.fade, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Value = 0})
 noticeTween:Play()
 -- Finished on a timer rather than the tween, so the blur is always handed back; a newer notice
 -- owns the screen by then if the version moved on.
 task.delay(seconds, function()
  if version == noticeVersion then finish() end
 end)
end

function UI.ClearNotifications()
 hideNotice(0)
 previousText = ""
end

local function buildNotice()
 local gui = UI.Screen("NotificationGui", 40)
 gui.IgnoreGuiInset = true
 local tint = Instance.new("Frame")
 tint.Name, tint.Size, tint.BorderSizePixel = "Tint", UDim2.fromScale(1, 1), 0
 tint.BackgroundColor3, tint.BackgroundTransparency = Color3.new(0, 0, 0), 1
 tint.Active, tint.Visible, tint.Parent = false, false, gui
 -- One CanvasGroup fades the whole notice, outlines and shadows included.
 local frame = Instance.new("CanvasGroup")
 frame.Name, frame.BackgroundTransparency, frame.BorderSizePixel = "Notice", 1, 0
 frame.AnchorPoint, frame.Position = Vector2.new(.5, .5), UDim2.fromScale(.5, .45)
 frame.AutomaticSize, frame.Active, frame.Visible, frame.ZIndex = Enum.AutomaticSize.Y, false, false, 2
 frame.Parent = gui
 local scale = Instance.new("UIScale")
 scale.Name, scale.Parent = "SizeScale", frame
 local padding = Instance.new("UIPadding")
 padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 10), UDim.new(0, 14)
 padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
 padding.Parent = frame
 local layout = Instance.new("UIListLayout")
 layout.SortOrder, layout.Padding = Enum.SortOrder.LayoutOrder, UDim.new(0, 8)
 layout.HorizontalAlignment, layout.Parent = Enum.HorizontalAlignment.Center, frame
 -- Title row: the icon just left of the centered title.
 local titleRow = Instance.new("Frame")
 titleRow.Name, titleRow.BackgroundTransparency, titleRow.LayoutOrder = "TitleRow", 1, 1
 titleRow.Size, titleRow.Parent = UDim2.new(1, 0, 0, TITLE_SIZE + 8), frame
 local iconHolder = Instance.new("Frame")
 iconHolder.Name, iconHolder.BackgroundTransparency, iconHolder.AnchorPoint = "Icon", 1, Vector2.new(0, .5)
 iconHolder.Size, iconHolder.Parent = UDim2.fromOffset(ICON_SIZE, ICON_SIZE), titleRow
 local image = UI.Icon(iconHolder, "Image", "")
 image.Size = UDim2.fromScale(1, 1)
 local drawn = {lock = lockIcon(iconHolder), alert = alertIcon(iconHolder)}
 -- Single-line rows (title, count) are sized in layout() from their own text.
 local function singleLine(holder, labels, alignment)
  holder.AutomaticSize = Enum.AutomaticSize.None
  for _, label in labels do
   label.TextWrapped, label.TextXAlignment = false, alignment
   label.AutomaticSize, label.Size = Enum.AutomaticSize.None, UDim2.fromScale(1, 1)
  end
 end
 local titleHolder, setTitle, titleLabels = shadowedLabel(titleRow, "Title", TITLE_SIZE, Color3.new(1, 1, 1))
 titleHolder.AnchorPoint = Vector2.new(0, .5)
 singleLine(titleHolder, titleLabels, Enum.TextXAlignment.Left)
 local messageHolder, setMessage = shadowedLabel(frame, "Message", 30, UI.Colors.Text)
 messageHolder.LayoutOrder = 2
 -- Progress row: a slim bar with its count to the right.
 local progressRow = Instance.new("Frame")
 progressRow.Name, progressRow.BackgroundTransparency, progressRow.LayoutOrder = "ProgressRow", 1, 3
 progressRow.Size, progressRow.Parent = UDim2.new(1, 0, 0, 32), frame
 local trough, setBar = UI.ProgressBar(progressRow, "Bar")
 trough.AnchorPoint, trough.Size = Vector2.new(0, .5), UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
 local countHolder, setCount, countLabels = shadowedLabel(progressRow, "Count", 26, UI.Colors.Text)
 countHolder.AnchorPoint = Vector2.new(0, .5)
 singleLine(countHolder, countLabels, Enum.TextXAlignment.Left)
 local remainingHolder, setRemaining = shadowedLabel(frame, "Remaining", 24, UI.Colors.Muted)
 remainingHolder.LayoutOrder = 4
 local fade = Instance.new("NumberValue")
 fade.Name, fade.Parent = "NoticeFade", frame
 notice = {gui = gui, tint = tint, frame = frame, scale = scale, fade = fade, titleRow = titleRow, iconHolder = iconHolder,
  image = image, drawn = drawn, titleHolder = titleHolder, titleLabels = titleLabels, setTitle = setTitle,
  setMessage = setMessage, progressRow = progressRow, trough = trough, setBar = setBar, countHolder = countHolder,
  countLabels = countLabels, setCount = setCount, remainingHolder = remainingHolder, setRemaining = setRemaining}

 local TextService = game:GetService("TextService")
 local function textWidth(text, size)
  return TextService:GetTextSize(text, size, UI.Font, Vector2.new(4000, 400)).X
 end
 -- Fits the title (shrinking it on narrow screens) and centers icon + title, and bar + count.
 function notice.layout()
  local viewport = gui.AbsoluteSize
  local fit = math.clamp(math.min(viewport.X / 1050, viewport.Y / 620), .72, 1.1)
  scale.Scale = fit
  local width = math.min(NOTICE_WIDTH, math.max(200, (viewport.X - 32) / fit))
  frame.Size = UDim2.fromOffset(width + 20, 0)
  local iconSpace = iconHolder.Visible and ICON_SIZE + ICON_GAP or 0
  local text = notice.titleText or ""
  local size = TITLE_SIZE
  local titleWidth = textWidth(text, size)
  if titleWidth + iconSpace > width then
   size = math.max(24, math.floor(size * (width - iconSpace) / titleWidth))
   titleWidth = textWidth(text, size)
  end
  for _, label in titleLabels do label.TextSize = size end
  local left = -(titleWidth + iconSpace) / 2
  iconHolder.Position = UDim2.new(.5, left, .5, 0)
  titleHolder.Position = UDim2.new(.5, left + iconSpace, .5, 0)
  titleHolder.Size = UDim2.fromOffset(titleWidth + 8, size + 8)
  local countWidth = textWidth(notice.countText or "", 26)
  local barLeft = -(BAR_WIDTH + 14 + countWidth) / 2
  trough.Position = UDim2.new(.5, barLeft, .5, 0)
  countHolder.Position = UDim2.new(.5, barLeft + BAR_WIDTH + 14, .5, 0)
  countHolder.Size = UDim2.fromOffset(countWidth + 8, 30)
 end
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(notice.layout)

 fade.Changed:Connect(function(amount)
  frame.GroupTransparency = 1 - amount
  frame.Position = UDim2.new(.5, 0, .45, 14 * (1 - amount))
  tint.BackgroundTransparency = 1 - NOTICE_TINT * amount
  noticeBlur = noticeFocused and amount or 0
  updateBlur()
 end)
 -- A tap or click anywhere dismisses the notice early (input still reaches the game). The
 -- first moment is ignored so the click that caused a notice does not close it at once.
 game:GetService("UserInputService").InputBegan:Connect(function(input)
  local inputType = input.UserInputType
  if (inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch)
   and frame.Visible and os.clock() - noticeShownAt > .3 then
   hideNotice(.15)
  end
 end)
 -- The portal trip hides this screen, and the hit cinematics own the view: never leave the blur.
 gui:GetPropertyChangedSignal("Enabled"):Connect(function()
  if not gui.Enabled then UI.ClearNotifications() end
 end)
 for _, attribute in {"CinematicCamera", "PortalJourney"} do
  player:GetAttributeChangedSignal(attribute):Connect(function()
   if player:GetAttribute(attribute) ~= nil and noticeFocused then UI.ClearNotifications() end
  end)
 end
end

-- message: the text (a plain string, as before). kind: "error", "success", a NOTICE_KINDS name or
-- nil. details (optional table): see noticeContent; a details.kind of "locked", "cash" or "error"
-- picks the title and icon, and numbers add the progress bar.
function UI.Notify(message, kind, details)
 if type(details) ~= "table" then details = nil end
 local theme, title, rich, text, progress = noticeContent(message, kind, details)
 if text == "" then return end
 if text == previousText and os.clock() - previousTime < 1 then return end
 previousText, previousTime = text, os.clock()
 -- Refusals get a short negative tick and routine updates a soft notice. Level Up, Max Level,
 -- Rebirth, World unlock, Offline Training and purchases have their own payoff sounds where
 -- they happen, so their notices stay silent here. Nothing routine plays over a rare hit.
 if kind == "error" then
  GameAudio.Play("Invalid")
 elseif kind == nil and not GameAudio.CinematicActive() then
  GameAudio.Play("Notice")
 end
 -- Routine menu responses use the menu's reserved feedback line, not a notice over its controls.
 if kind == "success" or kind == "error" then
  for screen in modalScreens do
   local feedback = screen.Scrim.Panel:FindFirstChild("Feedback")
   if feedback then
    feedback.Text, feedback.TextColor3 = text, kind == "error" and UI.Colors.Error or UI.Colors.Success
    return
   end
  end
 end
 -- Successes never pop up a notice: the result itself (an equipped item, the new World, Power or
 -- Cash on the HUD) and its sound are the confirmation.
 if kind == "success" then return end
 if not notice then buildNotice() end
 -- Fill it in.
 local icon = theme.icon
 notice.iconHolder.Visible = icon ~= nil
 notice.image.Visible = icon ~= nil and notice.drawn[icon] == nil
 notice.image.Image = notice.image.Visible and icon or ""
 for name, drawing in notice.drawn do drawing.Visible = icon == name end
 notice.titleText = title
 notice.setTitle(escapeRich(title), theme.color)
 notice.setMessage(rich)
 notice.progressRow.Visible = progress ~= nil
 notice.remainingHolder.Visible = progress ~= nil
 if progress then
  notice.countText = progress.count
  notice.setBar(progress.share, "")
  notice.setCount(escapeRich(progress.count))
  notice.setRemaining(escapeRich(progress.remaining))
 end
 notice.layout()
 -- Show it, replacing any notice already up (the blur stays one shared effect).
 noticeVersion += 1
 local version = noticeVersion
 if noticeTween then noticeTween:Cancel() end
 noticeShownAt = os.clock()
 noticeFocused = theme.focus == true and notice.gui.Enabled and not cinematicPlaying()
 notice.tint.Visible = noticeFocused
 notice.frame.Visible = true
 notice.fade.Value = math.min(notice.fade.Value, .4)
 noticeBlur = noticeFocused and notice.fade.Value or 0
 updateBlur()
 noticeTween = TweenService:Create(notice.fade, TweenInfo.new(.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = 1})
 noticeTween:Play()
 task.delay(theme.seconds or (progress and NOTICE_DETAIL_SECONDS or NOTICE_SECONDS), function()
  if version == noticeVersion then hideNotice(.25) end
 end)
end
return UI
