-- Shared presentation helpers. No gameplay state or authoritative calculations.
local TweenService = game:GetService("TweenService")
local player = game.Players.LocalPlayer
local UI = {}
local tintTweens = {}
local function cancelTint(button)
 local tween = tintTweens[button]
 if not tween then return end
 tintTweens[button] = nil
 tween:Cancel()
 tween:Destroy()
end
UI.Colors = {
 Panel = Color3.fromRGB(22, 30, 43), Card = Color3.fromRGB(33, 44, 60),
 Border = Color3.fromRGB(66, 83, 104), Text = Color3.fromRGB(242, 246, 251),
 Muted = Color3.fromRGB(180, 195, 213), Accent = Color3.fromRGB(107, 224, 181),
 Gold = Color3.fromRGB(255, 217, 125), Error = Color3.fromRGB(255, 171, 158),
}

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

function UI.Surface(parent, name, color)
 local panel = Instance.new("Frame")
 panel.Name, panel.BackgroundColor3, panel.BorderSizePixel = name, color or UI.Colors.Panel, 0
 Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
 local stroke = Instance.new("UIStroke")
 stroke.Color, stroke.Transparency, stroke.Parent = UI.Colors.Border, 0.3, panel
 panel.Parent = parent
 return panel
end

function UI.Label(parent, name, text, size, color)
 local label = Instance.new("TextLabel")
 label.Name, label.Text = name, text
 label.TextSize, label.TextColor3 = size or 16, color or UI.Colors.Text
 label.Font = Enum.Font.GothamMedium
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
 button.BackgroundColor3 = accent and UI.Colors.Accent or UI.Colors.Card
 button.TextColor3 = accent and UI.Colors.Panel or (enabled and UI.Colors.Text or UI.Colors.Muted)
 button.BackgroundTransparency = enabled and 0 or 0.3
end

function UI.Button(parent, name, text)
 local button = Instance.new("TextButton")
 button.Name, button.Font, button.TextSize = name, Enum.Font.GothamBold, 14
 button.AutoButtonColor, button.BorderSizePixel = false, 0
 button.TextWrapped = true
 Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
 button.Parent = parent
 UI.SetButton(button, text, true, false)
 local function tint(hover)
  if not button.Active then return end
  cancelTint(button)
  local base = button:GetAttribute("Accent") and UI.Colors.Accent or UI.Colors.Card
  local tween = TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = hover and base:Lerp(Color3.new(1,1,1), 0.12) or base})
  tintTweens[button] = tween
  tween.Completed:Once(function()
   if tintTweens[button] == tween then tintTweens[button] = nil end
  end)
  tween:Play()
 end
 button.MouseEnter:Connect(function() tint(true) end)
 button.MouseLeave:Connect(function() tint(false) end)
 button.Destroying:Connect(function() cancelTint(button) end)
 return button
end

function UI.Scroll(parent, name)
 local list = Instance.new("ScrollingFrame")
 list.Name, list.BackgroundTransparency, list.BorderSizePixel = name, 1, 0
 list.ScrollBarThickness, list.ScrollBarImageColor3 = 4, UI.Colors.Muted
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

-- Resize actual layout dimensions rather than shrinking text/touch targets.
function UI.Menu(name, title, subtitle, close)
 local gui = UI.Screen(name, 20)
 local scrim = Instance.new("Frame")
 scrim.Name, scrim.Size = "Scrim", UDim2.fromScale(1,1)
 scrim.BackgroundColor3, scrim.BackgroundTransparency = Color3.new(0,0,0), 0.4
 scrim.BorderSizePixel, scrim.Active, scrim.Visible, scrim.Parent = 0, true, false, gui
 local panel = UI.Surface(scrim, "Panel")
 panel.AnchorPoint, panel.Position = Vector2.new(.5,.5), UDim2.fromScale(.5,.5)
 panel.Active = true
 local heading = UI.Label(panel, "Title", title, 24)
 heading.Font, heading.Position, heading.Size = Enum.Font.GothamBold, UDim2.fromOffset(16,12), UDim2.new(1,-94,0,30)
 local sub = UI.Label(panel, "Subtitle", subtitle, 14, UI.Colors.Muted)
 sub.Position, sub.Size, sub.TextWrapped = UDim2.fromOffset(16,46), UDim2.new(1,-32,0,36), true
 local button = UI.Button(panel, "Close", "Close")
 button.Position, button.Size = UDim2.new(1,-78,0,12), UDim2.fromOffset(62,40)
 button.Activated:Connect(close)
 local function resize()
  local available = scrim.AbsoluteSize
  panel.Size = UDim2.fromOffset(math.min(720, math.max(240, available.X-24)), math.min(550, math.max(240,available.Y-24)))
 end
 scrim:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
 task.defer(resize)
 return gui, panel, function(visible) scrim.Visible = visible end
end

local notification, noticeText, noticeTitle, noticeVersion = nil, nil, nil, 0
local resizeNotice
local previousText, previousTime = "", 0
function UI.ClearNotifications()
 noticeVersion += 1
 if notification then notification.Visible = false end
 previousText = ""
end

function UI.Notify(message, kind)
 if type(message) ~= "string" or message == "" then return end
 if message == previousText and os.clock()-previousTime < 1 then return end
 previousText, previousTime = message, os.clock()
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
  noticeTitle = UI.Label(notification,"Title","",13)
  noticeTitle.Size, noticeTitle.LayoutOrder = UDim2.new(1,0,0,20),1
  noticeText = UI.Label(notification,"Message","",15)
  noticeText.Size, noticeText.TextWrapped = UDim2.new(1,0,0,0),true
  noticeText.AutomaticSize, noticeText.LayoutOrder = Enum.AutomaticSize.Y,2
  resizeNotice = function()
   local size = gui.AbsoluteSize
   local hud = player.PlayerGui:FindFirstChild("GameHUD")
   local hudRoot = hud and hud:FindFirstChild("Root")
   local shortcut = hudRoot and hudRoot:FindFirstChild("RebirthShortcut")
   if size.Y < 440 and size.X >= 600 then
    -- Leave the progression HUD on the right and touch controls at the bottom.
    notification.AnchorPoint, notification.Position = Vector2.zero,UDim2.fromOffset(12,10)
    notification.Size = UDim2.fromOffset(math.min(400,size.X-296),0)
   else
    local top = size.X >= 1040 and 18 or (shortcut and shortcut.Visible and 262 or 214)
    notification.AnchorPoint, notification.Position = Vector2.new(.5,0),UDim2.new(.5,0,0,top)
    notification.Size = UDim2.fromOffset(math.min(400,size.X-24),0)
   end
  end
  gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeNotice)
 end
 noticeTitle.Text = kind == "unlock" and "WORLD PROGRESS" or kind == "error" and "PLEASE TRY AGAIN"
  or kind == "level" and "LEVEL UP!" or kind == "cap" and "MAX LEVEL REACHED"
  or kind == "offline" and "OFFLINE TRAINING" or kind == "rebirth" and "REBIRTH COMPLETE" or "UPDATE"
 noticeTitle.TextColor3 = kind == "error" and UI.Colors.Error or UI.Colors.Accent
 noticeText.Text, notification.Visible = message, true
 resizeNotice()
 noticeVersion += 1
 local version = noticeVersion
 task.delay((kind == "unlock" or kind == "offline") and 8 or 5, function()
  if version == noticeVersion then notification.Visible = false end
 end)
end
return UI
