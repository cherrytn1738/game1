-- Each World's lighting, in one place to tune. Look-only values: nothing here changes gameplay.
-- WorldLightingClient applies the player's World's preset on their own client (players in
-- different Worlds share a server), when they enter a World and again after any cinematic.
-- SkyServer applies the starting World's preset at server start, so the replicated defaults
-- match World 1. See .vscode/ART_STYLE.md for each World's look.
--
-- A preset sets, by section: lighting (Lighting's own properties), atmosphere, sky, bloom,
-- sunRays and colorCorrection (the place's effects of those names, created if missing), and
-- clouds (Terrain clouds: a table turns them on, false turns them off). A property one preset
-- sets and another leaves out returns to the place's own value, so switching Worlds never leaves
-- one World's setting behind.
--
-- Haze: every World keeps Atmosphere Density near 0.3 (the far runway fades softly for depth,
-- the ball and the end portal stay clear); Haze and Glare add the colour.
local Lighting = game:GetService("Lighting")

local WorldLighting = {}

WorldLighting.Presets = {
 -- Home Field: bright, cheerful midday (the Daylight preset, from the developer's Oct 2026
 -- Studio edits toned down), with a pale sky-blue distance fade. (Haze above 0 darkens this
 -- World's horizon into a deep blue band, so the depth comes from Density and a light Color.)
 world_1 = {
  lighting = {
   GeographicLatitude = 0, ClockTime = 14.5,
   Brightness = 2.8, ExposureCompensation = -0.1,
   Ambient = Color3.fromRGB(124, 155, 184), OutdoorAmbient = Color3.fromRGB(157, 178, 255),
   ColorShift_Top = Color3.fromRGB(0, 0, 0),
  },
  atmosphere = {Density = 0.34, Offset = 0.25, Color = Color3.fromRGB(215, 228, 245),
   Decay = Color3.fromRGB(150, 175, 215), Glare = 0, Haze = 0},
  clouds = false,
  sky = {SunAngularSize = 11, MoonAngularSize = 11, StarCount = 3000},
  bloom = {Intensity = 0.5, Size = 40, Threshold = 2.4},
  sunRays = {Intensity = 0.01, Spread = 0.1},
  colorCorrection = {Saturation = 0.32, Contrast = 0.2, Brightness = 0, TintColor = Color3.fromRGB(243, 234, 255)},
 },
 -- Time Travel: warm golden hour (from the original GoldenHour preset, warmed): a low
 -- late-afternoon sun behind and to the left of the batter, about 22 degrees up, so it lights
 -- the runway but never sits in the camera's view of the ball down the runway (-Z). Peach
 -- clouds, an amber horizon, warm glare.
 world_2 = {
  lighting = {
   GeographicLatitude = 45, ClockTime = 16.4,
   Brightness = 2.4, ExposureCompensation = 0.1,
   Ambient = Color3.fromRGB(120, 92, 110), OutdoorAmbient = Color3.fromRGB(180, 140, 140),
   ColorShift_Top = Color3.fromRGB(255, 186, 120),
  },
  atmosphere = {Density = 0.3, Offset = 0.15, Color = Color3.fromRGB(255, 206, 160),
   Decay = Color3.fromRGB(196, 120, 150), Glare = 0.45, Haze = 0.9},
  clouds = {Cover = 0.6, Density = 0.75, Color = Color3.fromRGB(255, 214, 190)},
  sky = {SunAngularSize = 16, MoonAngularSize = 14, StarCount = 3000},
  bloom = {Intensity = 0.5, Size = 28, Threshold = 1.6},
  sunRays = {Intensity = 0.04, Spread = 0.75},
  colorCorrection = {Saturation = 0.22, Contrast = 0.06, Brightness = 0.02, TintColor = Color3.fromRGB(255, 238, 220)},
 },
 -- Future World: night, so the Neon strips, skyscraper bands and space areas glow. A bright
 -- violet-blue ambient keeps the ball, the runway and the cages easy to read; stronger bloom
 -- with a lower threshold makes the Neon bloom without washing out the lit white surfaces.
 world_3 = {
  lighting = {
   GeographicLatitude = 30, ClockTime = 0,
   Brightness = 1.6, ExposureCompensation = 0.05,
   Ambient = Color3.fromRGB(78, 88, 150), OutdoorAmbient = Color3.fromRGB(110, 118, 200),
   ColorShift_Top = Color3.fromRGB(120, 150, 255),
  },
  atmosphere = {Density = 0.32, Offset = 0.1, Color = Color3.fromRGB(96, 104, 180),
   Decay = Color3.fromRGB(44, 30, 96), Glare = 0, Haze = 0.8},
  clouds = false,
  sky = {SunAngularSize = 11, MoonAngularSize = 18, StarCount = 5000},
  bloom = {Intensity = 1.1, Size = 40, Threshold = 1.25},
  sunRays = {Intensity = 0, Spread = 0.1},
  colorCorrection = {Saturation = 0.3, Contrast = 0.22, Brightness = 0.03, TintColor = Color3.fromRGB(228, 230, 255)},
 },
 -- Tiny Town: a bedroom in the evening, lit by a warm lamp: a very low amber sun from the left
 -- (about 5 degrees up, behind the batter), a dusk-blue sky over a warm horizon, a strong warm
 -- ambient standing in for the lamp, warm haze, and gentle bloom on the toys and the keyhole's
 -- glow. Saturation stays up so the toys keep their primaries. (Later than 17.65 turns the sky
 -- to night and the scene muddy orange.)
 world_4 = {
  lighting = {
   GeographicLatitude = 35, ClockTime = 17.65,
   Brightness = 2.1, ExposureCompensation = 0.15,
   Ambient = Color3.fromRGB(145, 106, 90), OutdoorAmbient = Color3.fromRGB(206, 156, 124),
   ColorShift_Top = Color3.fromRGB(255, 170, 100),
  },
  atmosphere = {Density = 0.3, Offset = 0.2, Color = Color3.fromRGB(255, 196, 150),
   Decay = Color3.fromRGB(168, 96, 100), Glare = 0.5, Haze = 1.2},
  clouds = false,
  sky = {SunAngularSize = 14, MoonAngularSize = 11, StarCount = 3000},
  bloom = {Intensity = 0.7, Size = 36, Threshold = 1.7},
  sunRays = {Intensity = 0.05, Spread = 0.5},
  colorCorrection = {Saturation = 0.3, Contrast = 0.12, Brightness = 0.02, TintColor = Color3.fromRGB(255, 236, 216)},
 },
}
WorldLighting.Default = "world_1"

-- Lighting's effects, by preset section: the class and the name looked up under Lighting. Found
-- by name, never by class, so the cinematics' own grades and blurs are never touched.
local EFFECTS = {
 atmosphere = {"Atmosphere", "Atmosphere"}, sky = {"Sky", "Sky"}, bloom = {"BloomEffect", "Bloom"},
 sunRays = {"SunRaysEffect", "SunRays"}, colorCorrection = {"ColorCorrectionEffect", "ColorCorrection"},
}

function WorldLighting.ForWorld(worldId)
 return WorldLighting.Presets[worldId] or WorldLighting.Presets[WorldLighting.Default]
end

local function target(section)
 if section == "lighting" then return Lighting end
 local info = EFFECTS[section]
 local existing = Lighting:FindFirstChild(info[2])
 if existing and existing:IsA(info[1]) then return existing end
 local created = Instance.new(info[1])
 created.Name, created.Parent = info[2], Lighting
 return created
end

-- The place's own value of every property any preset sets, read once before the first preset.
local baseline
local function snapshot()
 baseline = {}
 for _, preset in WorldLighting.Presets do
  for section, values in preset do
   if section ~= "clouds" and type(values) == "table" then
    local object = target(section)
    baseline[section] = baseline[section] or {}
    for property in values do
     if baseline[section][property] == nil then baseline[section][property] = object[property] end
    end
   end
  end
 end
end

-- Applies a preset (from ForWorld) to this machine's Lighting and Terrain clouds.
function WorldLighting.Apply(preset)
 if not baseline then snapshot() end
 for section, values in baseline do
  local object = target(section)
  local wanted = preset[section] or {}
  for property, value in values do
   local chosen = wanted[property]
   if chosen == nil then chosen = value end
   object[property] = chosen
  end
 end
 local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
 if preset.clouds then
  if not clouds then
   clouds = Instance.new("Clouds")
   clouds.Name, clouds.Parent = "Clouds", workspace.Terrain
  end
  clouds.Enabled = true
  for property, value in preset.clouds do clouds[property] = value end
 elseif clouds then
  clouds.Enabled = false
 end
end

return WorldLighting
