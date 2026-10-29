-- Tutorial-only spotlight on one real on-screen control. Four dark frames cover the screen
-- around the target's AbsolutePosition / AbsoluteSize (re-measured every frame, so resizing,
-- rotating a phone or scrolling keeps it lined up) with a pulsing gold ring around it.
--   Spotlight.Show(target, {dim = true, scope = aScreenGui, allowed = {closeButton}, caption = "BUY IT"})
--   Spotlight.Hide()
-- The caption sits just below the ring (above it when there is no room below).
-- With a scope, that ScreenGui's other buttons are made non-interactive until Hide, except
-- the allowed ones (a menu's close button, so nobody is trapped). The target stays the real,
-- clickable control. dim = false shows only the ring (for HUD hints outside a menu).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UI = require(script.Parent:WaitForChild("UICommon"))

local Spotlight = {}

local DIM = 0.35 -- transparency of the darkened area
local PADDING = 6 -- pixels between the target and the ring
local CAPTION_HEIGHT, CAPTION_GAP = 34, 8
local GOLD = Color3.fromRGB(255, 208, 0)

-- Covers the whole screen, top bar included; targets in inset ScreenGuis are shifted to match.
local gui = Instance.new("ScreenGui")
gui.Name, gui.DisplayOrder, gui.ResetOnSpawn = "TutorialSpotlight", 45, false
gui.ZIndexBehavior, gui.Enabled, gui.IgnoreGuiInset = Enum.ZIndexBehavior.Sibling, false, true
local shades = {}
for _, name in {"Top", "Bottom", "Left", "Right"} do
 local shade = Instance.new("Frame")
 shade.Name, shade.BorderSizePixel = name, 0
 shade.BackgroundColor3, shade.BackgroundTransparency = Color3.new(0, 0, 0), DIM
 shade.Parent = gui
 shades[name] = shade
end
local ring = Instance.new("Frame")
ring.Name, ring.BackgroundTransparency = "Ring", 1
ring.Parent = gui
Instance.new("UICorner", ring).CornerRadius = UDim.new(0, 14)
local ringStroke = Instance.new("UIStroke", ring)
ringStroke.Color, ringStroke.Thickness = GOLD, 4
local caption = UI.Label(gui, "Caption", "", 26, GOLD)
caption.AnchorPoint, caption.TextXAlignment, caption.TextScaled = Vector2.new(.5, 0), Enum.TextXAlignment.Center, true
local captionSize = Instance.new("UITextSizeConstraint")
captionSize.MaxTextSize, captionSize.Parent = 26, caption
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local current, disabled, connection = nil, {}, nil

-- Shown when it and every ancestor up to its ScreenGui are visible.
local function onScreen(object)
 local node = object
 while node do
  if node:IsA("ScreenGui") then return node.Enabled end
  if node:IsA("GuiObject") and not node.Visible then return false end
  node = node.Parent
 end
 return false
end

local function restore()
 for button, interactable in disabled do
  if button.Parent then button.Interactable = interactable end
 end
 table.clear(disabled)
end

-- Scrolls the target's list (if any) just enough to bring the target into view.
local function reveal(target)
 local scroller = target:FindFirstAncestorWhichIsA("ScrollingFrame")
 if not scroller or target.AbsoluteSize.Y == 0 then return false end
 local canvas = scroller.CanvasPosition
 local top = target.AbsolutePosition.Y - scroller.AbsolutePosition.Y + canvas.Y
 local bottom = top + target.AbsoluteSize.Y
 local y = canvas.Y
 if top < y then
  y = top - PADDING * 2
 elseif bottom > y + scroller.AbsoluteSize.Y then
  y = bottom - scroller.AbsoluteSize.Y + PADDING * 2
 end
 scroller.CanvasPosition = Vector2.new(canvas.X, math.max(0, y))
 return true
end

local function update()
 local target = current and current.target
 local screen = target and target:FindFirstAncestorOfClass("ScreenGui")
 if not screen or not onScreen(target) then
  gui.Enabled = false
  return
 end
 -- Once laid out, a target in a scrolling list is scrolled into view (the player may scroll
 -- away again; the spotlight follows it).
 if not current.revealed then current.revealed = reveal(target) or target:FindFirstAncestorWhichIsA("ScrollingFrame") == nil end
 gui.Enabled = true
 local position, size = target.AbsolutePosition, target.AbsoluteSize
 if not screen.IgnoreGuiInset then position += GuiService:GetGuiInset() end
 -- Whole pixels, so the four shades meet without a seam.
 local x0, y0 = math.floor(position.X - PADDING), math.floor(position.Y - PADDING)
 local x1, y1 = math.ceil(position.X + size.X + PADDING), math.ceil(position.Y + size.Y + PADDING)
 local dim = current.dim
 shades.Top.Visible, shades.Bottom.Visible, shades.Left.Visible, shades.Right.Visible = dim, dim, dim, dim
 shades.Top.Position, shades.Top.Size = UDim2.new(), UDim2.new(1, 0, 0, math.max(0, y0))
 shades.Bottom.Position, shades.Bottom.Size = UDim2.fromOffset(0, y1), UDim2.new(1, 0, 1, -y1)
 shades.Left.Position, shades.Left.Size = UDim2.fromOffset(0, y0), UDim2.fromOffset(math.max(0, x0), y1 - y0)
 shades.Right.Position, shades.Right.Size = UDim2.fromOffset(x1, y0), UDim2.new(1, -x1, 0, y1 - y0)
 ring.Position, ring.Size = UDim2.fromOffset(x0, y0), UDim2.fromOffset(x1 - x0, y1 - y0)
 caption.Visible = current.caption ~= nil
 if current.caption then
  caption.Text = current.caption
  local screen = gui.AbsoluteSize
  if x1 - x0 < 200 and x1 + CAPTION_GAP + 300 <= screen.X then
   -- Beside a small target (a HUD tile), so it doesn't cover its neighbours.
   caption.AnchorPoint, caption.TextXAlignment = Vector2.new(0, .5), Enum.TextXAlignment.Left
   caption.Size = UDim2.fromOffset(300, CAPTION_HEIGHT)
   caption.Position = UDim2.fromOffset(x1 + CAPTION_GAP, (y0 + y1) / 2)
  else
   local below = y1 + CAPTION_GAP + CAPTION_HEIGHT <= screen.Y
   caption.AnchorPoint, caption.TextXAlignment = Vector2.new(.5, 0), Enum.TextXAlignment.Center
   caption.Size = UDim2.fromOffset(math.max(x1 - x0, 300), CAPTION_HEIGHT)
   caption.Position = UDim2.fromOffset(math.clamp((x0 + x1) / 2, 150, math.max(150, screen.X - 150)),
    below and y1 + CAPTION_GAP or y0 - CAPTION_GAP - CAPTION_HEIGHT)
  end
 end
 local pulse = 0.5 + 0.5 * math.sin(os.clock() * 6)
 ringStroke.Thickness = 3 + 3 * pulse
 ringStroke.Transparency = 0.25 * pulse
end

function Spotlight.Show(target, options)
 options = options or {}
 if current and current.target == target and current.scope == options.scope then
  current.caption = options.caption
  return
 end
 Spotlight.Hide()
 current = {target = target, dim = options.dim ~= false, scope = options.scope, caption = options.caption}
 if options.scope then
  local allowed = {}
  for _, object in options.allowed or {} do allowed[object] = true end
  for _, button in options.scope:GetDescendants() do
   if button:IsA("GuiButton") and button ~= target and not allowed[button] and not button:IsDescendantOf(target) then
    disabled[button] = button.Interactable
    button.Interactable = false
   end
  end
 end
 connection = RunService.RenderStepped:Connect(update)
 update()
end

function Spotlight.Hide()
 if connection then connection:Disconnect() connection = nil end
 restore()
 current = nil
 gui.Enabled = false
end

function Spotlight.Target()
 return current and current.target
end

-- Removes the spotlight's ScreenGui for good (once the tutorial is over).
function Spotlight.Destroy()
 Spotlight.Hide()
 gui:Destroy()
end

return Spotlight
