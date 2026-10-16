-- Client-side Bat cosmetics (BatStyles): layered swing trails drawn between the attachments the
-- server adds to each held Bat's Handle, shown only while the barrel tip moves fast (so on
-- real and practice swings, not while standing). Contact bursts are triggered by the hit
-- presentation when a ball leaves the tee. Nothing here affects Power, launch or rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BatStyles = require(ReplicatedStorage:WaitForChild("BatStyles"))
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))

local BatEffects = {}

local SWING_SPEED = 30 -- studs per second at the tip before the trail shows
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SPARKLE_TIER = 0.4 -- bats at or above this tier also get a sparkle layer
local CORE_BASE = 2.85 -- the white-hot streak runs along the last half stud of the barrel

local trails = {} -- Tool -> {layers, itemId, spec, lastTip, started}

local function rainbow()
 local points = {}
 for i = 0, 6 do table.insert(points, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 * 0.85, 0.9, 1))) end
 return ColorSequence.new(points)
end

-- How far up the Bat lineup an item is: 0 for the first, 1 for the last.
local function tierOf(itemId)
 local item = Equipment.GetById(itemId)
 local count = #Equipment.GetItems("Bat")
 return item and count > 1 and (item.order - 1) / (count - 1) or 0
end

local function layer(handle, a0, a1, properties)
 local trail = Instance.new("Trail")
 trail.Name = "SwingTrail"
 trail.Attachment0, trail.Attachment1 = a0, a1
 trail.MinLength, trail.FaceCamera, trail.LightInfluence, trail.Enabled = 0.02, false, 0, false
 for property, value in properties do trail[property] = value end
 trail.Parent = handle
 return trail
end

-- Layers swept by the bat: the coloured sweep (true colour, unlit, normal blending), a
-- white-hot additive streak along the tip, and a sparkle sweep for the fancier bats.
local function makeLayers(handle, spec, tier)
 local base, tip = handle:FindFirstChild("SwingTrailBase"), handle:FindFirstChild("SwingTrailTip")
 if not base or not tip then return nil end
 local colors = spec.rainbow and rainbow() or ColorSequence.new(spec.colors[1], spec.colors[2])
 local head = spec.rainbow and Color3.fromRGB(255, 235, 170) or spec.colors[1]
 local lifetime = spec.lifetime or 0.15
 local layers = {}
 table.insert(layers, {kind = "outer", trail = layer(handle, base, tip, {
  Lifetime = lifetime, LightEmission = 0, Brightness = 1.6, Color = colors,
  Transparency = NumberSequence.new(0.2, 1)})})
 local coreBase = handle:FindFirstChild("SwingCoreBase") or Instance.new("Attachment")
 coreBase.Name, coreBase.Position, coreBase.Parent = "SwingCoreBase", Vector3.new(0, CORE_BASE, 0), handle
 table.insert(layers, {kind = "core", trail = layer(handle, coreBase, tip, {
  Lifetime = lifetime * 0.6, LightEmission = 1, Brightness = 2.5,
  Color = ColorSequence.new(Color3.new(1, 1, 1), head), Transparency = NumberSequence.new(0, 1)})})
 if tier >= SPARKLE_TIER then
  table.insert(layers, {kind = "sparkle", trail = layer(handle, base, tip, {
   Lifetime = lifetime * 1.3, LightEmission = 1, Brightness = 1.5, Color = colors,
   Texture = SPARKLE_TEXTURE, TextureMode = Enum.TextureMode.Wrap, TextureLength = 1.2,
   Transparency = NumberSequence.new(0.3 - tier * 0.2, 1)})})
 end
 return layers
end

local function drop(tool)
 local entry = trails[tool]
 for _, item in entry and entry.layers or {} do item.trail:Destroy() end
 trails[tool] = nil
end

-- Call every frame.
function BatEffects.Update(dt)
 local seen = {}
 for _, player in Players:GetPlayers() do
  local character = player.Character
  local tool = character and character:FindFirstChild("Bat")
  local handle = tool and tool:IsA("Tool") and tool:FindFirstChild("Handle")
  if handle then
   seen[tool] = true
   local itemId = tool:GetAttribute("EquipmentId")
   local entry = trails[tool]
   if entry and entry.itemId ~= itemId then drop(tool) entry = nil end
   if not entry then
    local style = BatStyles.Get(itemId)
    local layers = style and style.swing and makeLayers(handle, style.swing, tierOf(itemId))
    -- No trail yet (plain bat, or attachments not replicated): retry when they appear.
    entry = {layers = layers, itemId = layers and itemId or nil, spec = style and style.swing, started = os.clock()}
    trails[tool] = entry
   end
   if entry.layers then
    local tip = handle.CFrame:PointToWorldSpace(Vector3.new(0, BatStyles.TrailTip, 0))
    local speed = entry.lastTip and dt > 0 and (tip - entry.lastTip).Magnitude / dt or 0
    entry.lastTip = tip
    local swinging = speed >= SWING_SPEED
    for _, item in entry.layers do
     item.trail.Enabled = swinging
     if entry.spec.hueShift and item.kind ~= "core" then
      local hue = ((os.clock() - entry.started) * 0.35) % 1
      item.trail.Color = ColorSequence.new(Color3.fromHSV(hue, 0.85, 1), Color3.fromHSV((hue + 0.3) % 1, 0.9, 1))
     end
     if entry.spec.flicker and item.kind ~= "core" then
      item.trail.Transparency = NumberSequence.new(0.15 + math.random() * 0.5, 1)
     end
    end
   end
  end
 end
 for tool in trails do
  if not seen[tool] then drop(tool) end
 end
end

-- The contact burst for a station's batter (by their equipped Bat), if it has one.
function BatEffects.ContactBurstFor(batterUserId)
 local player = batterUserId and Players:GetPlayerByUserId(batterUserId)
 local style = player and BatStyles.Get(player:GetAttribute("EquippedBat"))
 return style and style.contact
end

return BatEffects
