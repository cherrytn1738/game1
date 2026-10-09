-- Shared presentation helpers. No gameplay state or authoritative calculations.
local TweenService = game:GetService("TweenService")
local player = game.Players.LocalPlayer
local UI = {}
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
  local base = button:GetAttribute("Accent") and UI.Colors.Accent or UI.Colors.Card
  TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = hover and base:Lerp(Color3.new(1,1,1), 0.12) or base}):Play()
 end
 button.MouseEnter:Connect(function() tint(true) end)
 button.MouseLeave:Connect(function() tint(false) end)
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
  notification.AnchorPoint, notification.Position = Vector2.new(.5,0), UDim2.new(.5,0,0,88)
  notification.Size = UDim2.new(1,-24,0,90)
  local limit = Instance.new("UISizeConstraint", notification)
  limit.MaxSize = Vector2.new(400,90)
  noticeTitle = UI.Label(notification,"Title","",13)
  noticeTitle.Position, noticeTitle.Size = UDim2.fromOffset(14,8), UDim2.new(1,-28,0,20)
  noticeText = UI.Label(notification,"Message","",15)
  noticeText.Position, noticeText.Size, noticeText.TextWrapped = UDim2.fromOffset(14,30), UDim2.new(1,-28,0,52), true
 end
 noticeTitle.Text = kind == "unlock" and "WORLD PROGRESS" or kind == "error" and "PLEASE TRY AGAIN" or "UPDATE"
 noticeTitle.TextColor3 = kind == "error" and UI.Colors.Error or UI.Colors.Accent
 noticeText.Text, notification.Visible = message, true
 noticeVersion += 1
 local version = noticeVersion
 task.delay(kind == "unlock" and 8 or 4, function()
  if version == noticeVersion then notification.Visible = false end
 end)
end
return UI
