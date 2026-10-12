-- One stylized golden-hour sky for the whole game, applied when the server starts.
-- Look-only values; tune them here. Lighting, its effects, and Terrain clouds replicate to clients.
local Lighting = game:GetService("Lighting")

local LIGHTING = {
 -- Late-afternoon sun behind and to the left of the batter (about 34 degrees up), so it
 -- lights the runway but never sits in the camera's view of the ball down the runway (-Z).
 GeographicLatitude = 45, ClockTime = 15.5,
 Brightness = 2.4, ExposureCompensation = 0.1,
 Ambient = Color3.fromRGB(110, 90, 130), OutdoorAmbient = Color3.fromRGB(160, 130, 165),
 ColorShift_Top = Color3.fromRGB(255, 200, 150),
}
local ATMOSPHERE = {Density = 0.3, Offset = 0.15, Color = Color3.fromRGB(255, 196, 196),
 Decay = Color3.fromRGB(150, 110, 220), Glare = 0.35, Haze = 0.9}
local CLOUDS = {Cover = 0.6, Density = 0.75, Color = Color3.fromRGB(255, 222, 236)}
local SKY = {SunAngularSize = 16, MoonAngularSize = 14}
local BLOOM = {Intensity = 0.5, Size = 28, Threshold = 1.6}
local SUN_RAYS = {Intensity = 0.04, Spread = 0.75}
local COLOR_CORRECTION = {Saturation = 0.18, Contrast = 0.06, Brightness = 0.02,
 TintColor = Color3.fromRGB(255, 244, 240)}

local function apply(instance, properties)
 for property, value in properties do instance[property] = value end
end

-- Reuse the place's existing effect of each class so settings never stack.
local function effect(parent, className, name)
 local existing = parent:FindFirstChildOfClass(className)
 if existing then return existing end
 local created = Instance.new(className)
 created.Name = name
 created.Parent = parent
 return created
end

apply(Lighting, LIGHTING)
apply(effect(Lighting, "Atmosphere", "Atmosphere"), ATMOSPHERE)
apply(effect(Lighting, "Sky", "Sky"), SKY)
apply(effect(Lighting, "BloomEffect", "Bloom"), BLOOM)
apply(effect(Lighting, "SunRaysEffect", "SunRays"), SUN_RAYS)
apply(effect(Lighting, "ColorCorrectionEffect", "SkyColorCorrection"), COLOR_CORRECTION)
apply(effect(workspace.Terrain, "Clouds", "Clouds"), CLOUDS)
