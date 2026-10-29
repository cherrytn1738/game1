-- Shows each registered world-space gui (WorldUIConfig) only while this player's camera is
-- near it, fading quickly in and out. One Heartbeat loop: distances are checked a few times a
-- second and only guis mid-fade are touched every frame.
-- A hidden gui is culled through its MaxDistance rather than Enabled, so the scripts that own
-- Enabled (the server's batting pad label) keep owning it. Owners may change a registered
-- gui's text and colours freely, but not its transparencies.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("WorldUIConfig"))

local HIDDEN_DISTANCE = 0.01 -- a MaxDistance no camera is ever inside

local entries = {} -- gui -> {range, maxDistance, alpha (0 shown, 1 hidden), target, base}
local fading = {}

local function worldPosition(gui)
 local target = gui.Adornee or gui.Parent
 if not target then return nil end
 if target:IsA("Attachment") then return target.WorldPosition end
 if target:IsA("BasePart") then return target.Position end
 if target:IsA("Model") then return target:GetPivot().Position end
 return nil
end

local function transparencyProperties(object)
 if object:IsA("UIStroke") then return {"Transparency"} end
 if not object:IsA("GuiObject") then return nil end
 if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
  return {"BackgroundTransparency", "TextTransparency", "TextStrokeTransparency"}
 end
 if object:IsA("ImageLabel") or object:IsA("ImageButton") then return {"BackgroundTransparency", "ImageTransparency"} end
 return {"BackgroundTransparency"}
end

-- Each property goes from its own resting value (kept in entry.base, captured the first time
-- it is faded) to fully transparent as alpha goes from 0 to 1.
local function applyAlpha(gui, entry)
 for _, object in gui:GetDescendants() do
  local base = entry.base[object]
  if not base then
   local properties = transparencyProperties(object)
   if properties then
    base = {}
    for _, property in properties do base[property] = object[property] end
    entry.base[object] = base
   end
  end
  if base then
   for property, value in base do object[property] = value + (1 - value) * entry.alpha end
  end
 end
end

local function distanceTo(gui)
 local position = worldPosition(gui)
 local camera = workspace.CurrentCamera
 if not position or not camera then return math.huge end
 return (position - camera.CFrame.Position).Magnitude
end

local function register(gui)
 if entries[gui] or not (gui:IsA("BillboardGui") or gui:IsA("SurfaceGui")) then return end
 local range = Config.Ranges[gui:GetAttribute(Config.RangeAttribute)]
 if not range then return end
 local entry = {range = range, maxDistance = gui.MaxDistance, base = {}}
 -- A gui appears already settled: shown outright if near, hidden outright if far.
 local showing = Config.ShouldShow(false, distanceTo(gui), range)
 entry.alpha, entry.target = showing and 0 or 1, showing and 0 or 1
 if not showing then gui.MaxDistance = HIDDEN_DISTANCE end
 entries[gui] = entry
end

local function unregister(gui)
 entries[gui], fading[gui] = nil, nil
end

local function check()
 for gui, entry in entries do
  local target = Config.ShouldShow(entry.target == 0, distanceTo(gui), entry.range) and 0 or 1
  if target ~= entry.target then
   entry.target = target
   if target == 0 and entry.alpha == 1 then
    gui.MaxDistance = entry.maxDistance
   elseif target == 1 and entry.alpha == 0 then
    entry.base = {} -- capture fresh resting values (they may have changed while shown)
   end
   fading[gui] = entry
  end
 end
end

local function fade(dt)
 local step = dt / Config.FadeSeconds
 for gui, entry in fading do
  if entry.target == 0 then
   entry.alpha = math.max(0, entry.alpha - step)
  else
   entry.alpha = math.min(1, entry.alpha + step)
  end
  applyAlpha(gui, entry)
  if entry.alpha == entry.target then
   fading[gui] = nil
   if entry.alpha == 1 then gui.MaxDistance = HIDDEN_DISTANCE end
  end
 end
end

CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(register)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(unregister)
for _, gui in CollectionService:GetTagged(Config.Tag) do register(gui) end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
 elapsed += dt
 if elapsed >= Config.CheckInterval then
  elapsed = 0
  check()
 end
 if next(fading) then fade(dt) end
end)
