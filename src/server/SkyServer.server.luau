-- One stylized sky for the whole game, applied when the server starts. Look-only values; tune
-- them here. Lighting, its effects, and Terrain clouds replicate to clients.
-- Two presets: switch PRESET to go back to the original golden hour.
local Lighting = game:GetService("Lighting")

local PRESET = "Daylight" -- "Daylight" (current) or "GoldenHour" (original)

local PRESETS = {
 -- Bright midday look, from the developer's Studio Lighting edits (Oct 2026: Brightness 4,
 -- bloom 1 / 56 / 2, contrast and saturation 0.5), toned down so it is easier on the eyes while
 -- keeping the cool blue ambient, lavender tint and vivid colour. No terrain clouds
 -- (clouds = false turns off any that exist); the place's own Sky skybox is kept.
 Daylight = {
  lighting = {
   GeographicLatitude = 0, ClockTime = 14.5,
   Brightness = 2.8, ExposureCompensation = -0.1,
   Ambient = Color3.fromRGB(124, 155, 184), OutdoorAmbient = Color3.fromRGB(157, 178, 255),
   ColorShift_Top = Color3.fromRGB(0, 0, 0),
  },
  atmosphere = {Density = 0.3, Offset = 0.25, Color = Color3.fromRGB(199, 199, 199),
   Decay = Color3.fromRGB(106, 112, 125), Glare = 0, Haze = 0},
  clouds = false,
  sky = {SunAngularSize = 11, MoonAngularSize = 11},
  bloom = {Intensity = 0.5, Size = 40, Threshold = 2.4},
  sunRays = {Intensity = 0.01, Spread = 0.1},
  colorCorrection = {Saturation = 0.32, Contrast = 0.2, Brightness = 0, TintColor = Color3.fromRGB(243, 234, 255)},
 },
 -- The original stylized golden hour: late-afternoon sun behind and to the left of the batter
 -- (about 34 degrees up), so it lights the runway but never sits in the camera's view of the
 -- ball down the runway (-Z).
 GoldenHour = {
  lighting = {
   GeographicLatitude = 45, ClockTime = 15.5,
   Brightness = 2.4, ExposureCompensation = 0.1,
   Ambient = Color3.fromRGB(110, 90, 130), OutdoorAmbient = Color3.fromRGB(160, 130, 165),
   ColorShift_Top = Color3.fromRGB(255, 200, 150),
  },
  atmosphere = {Density = 0.3, Offset = 0.15, Color = Color3.fromRGB(255, 196, 196),
   Decay = Color3.fromRGB(150, 110, 220), Glare = 0.35, Haze = 0.9},
  clouds = {Cover = 0.6, Density = 0.75, Color = Color3.fromRGB(255, 222, 236)},
  sky = {SunAngularSize = 16, MoonAngularSize = 14},
  bloom = {Intensity = 0.5, Size = 28, Threshold = 1.6},
  sunRays = {Intensity = 0.04, Spread = 0.75},
  colorCorrection = {Saturation = 0.18, Contrast = 0.06, Brightness = 0.02, TintColor = Color3.fromRGB(255, 244, 240)},
 },
}

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

local preset = PRESETS[PRESET] or PRESETS.GoldenHour
apply(Lighting, preset.lighting)
apply(effect(Lighting, "Atmosphere", "Atmosphere"), preset.atmosphere)
apply(effect(Lighting, "Sky", "Sky"), preset.sky)
apply(effect(Lighting, "BloomEffect", "Bloom"), preset.bloom)
apply(effect(Lighting, "SunRaysEffect", "SunRays"), preset.sunRays)
apply(effect(Lighting, "ColorCorrectionEffect", "SkyColorCorrection"), preset.colorCorrection)
if preset.clouds then
 local clouds = effect(workspace.Terrain, "Clouds", "Clouds")
 clouds.Enabled = true
 apply(clouds, preset.clouds)
else
 local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
 if clouds then clouds.Enabled = false end
end
