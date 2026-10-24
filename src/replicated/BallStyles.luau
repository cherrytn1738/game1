-- Looks and flight effects for each Ball (cosmetic only: nothing here changes launch,
-- physics, distance or rewards). Models come from tools/blender/balls.py; each mesh is named
-- "<item id>__<Part>" and is coloured here by its Part name.
--   parts: Part -> {color, material, transparency}
--   light: {color, brightness, range} glow on the display and in flight
--   flight: the ball's own stack of flight layers (ribbons, particles, orbiters, debris, arcs,
--     pulses, echoes; see the builders below and BallEffects), its main colour (glow halo and
--     impact rings; aura = false drops the halo), and launch / land (Bursts presets)
--   idle: an Emitters preset shown around the ball on its display pedestal
-- FlightSounds (below) gives the fancier balls their own sound in flight.
local M = Enum.Material
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function look(color, material, transparency)
 return {color = color, material = material or M.SmoothPlastic, transparency = transparency or 0}
end

local Styles = {}

-- Flight layer builders (BallEffects draws them; see its header for what each does). Sizes
-- are for the 0.8-stud physics ball; the visible ball and its effects are drawn bigger.
--   ribbon:   colors (head to tail) or rainbow, width, lifetime, glow, taper (a silhouette:
--             "comet", "teardrop", "needle", "swell", "scallop", "flame"), bands (glowing
--             segments), fade {head, tail}, offset, orbit {radius, speed (turns/s), phase},
--             wobble {amp, freq, phase}, jitter, flicker, hueShift (turns/s)
--   streak:   a soft round particle trail: texture ("glow", "smoke", "fire", "sparkle",
--             "vortex"), colors over its life, size, endSize, lifetime, rate, glow, transparency
--   emit:     an Emitters preset with rate, size, offset, back (emitted behind the ball)
--   orbiters: count, radius, speed, size, shape, color(s), material, spin, lag, trail {width, lifetime}
--   debris:   rate, size, shape, color(s), material, life, fall, spread
--   arcs:     rate, color, length, segments, thickness
--   pulse:    interval, color, size, texture ("shockwave", "vortex", "glow", "core"), life
--   echoes:   interval, color, life, grow
local function ribbon(spec) spec.type = "ribbon" return spec end
local function streak(spec) spec.type = "streak" return spec end
local function emit(preset, spec) spec = spec or {} spec.type, spec.preset = "emitter", preset return spec end
local function orbiters(spec) spec.type = "orbiters" return spec end
local function debris(spec) spec.type = "debris" return spec end
local function arcs(spec) spec.type = "arcs" return spec end
local function pulse(spec) spec.type = "pulse" return spec end
local function echoes(spec) spec.type = "echoes" return spec end
local WHITE = rgb(255, 255, 255)

Styles.Balls = {
 baseball = {
  parts = {Shell = look(rgb(245, 244, 236), M.Leather), Stitches = look(rgb(205, 30, 36))},
  -- A clean white streak of cut air.
  flight = {color = rgb(240, 244, 255), aura = false, land = "Dust", layers = {
   ribbon {colors = {WHITE, rgb(215, 225, 240)}, width = 0.22, lifetime = 0.22, fade = {0.3, 1}, taper = "needle"},
   streak {colors = {WHITE}, size = 0.5, lifetime = 0.15, transparency = 0.7, glow = true},
  }},
 },
 practice_ball = { -- Sandlot Ball
  parts = {Shell = look(rgb(214, 178, 128), M.Leather), Stitches = look(rgb(160, 60, 48)),
   Scuffs = look(rgb(150, 112, 74), M.Leather)},
  -- Kicks up the sandlot: a dusty streak in a billowing dirt cloud, dirt puffs and clods.
  flight = {color = rgb(235, 210, 160), land = "Dust", layers = {
   ribbon {colors = {rgb(255, 248, 230), rgb(214, 178, 128)}, width = 0.4, lifetime = 0.3, taper = "teardrop"},
   streak {texture = "smoke", colors = {rgb(235, 212, 170), rgb(180, 140, 95)}, size = 0.8, endSize = 2.4, lifetime = 0.6,
    rate = 70, transparency = 0.45},
   emit("DirtPuff", {rate = 14, back = true}),
   debris {rate = 10, size = Vector3.new(0.16, 0.14, 0.16), colors = {rgb(150, 110, 70), rgb(120, 86, 56)}, life = 0.7, fall = 7},
  }},
 },
 bubblegum_ball = {
  parts = {Shell = look(rgb(255, 120, 190)), Icing = look(rgb(255, 246, 250)),
   Sprinkles1 = look(rgb(255, 220, 50)), Sprinkles2 = look(rgb(90, 215, 255)), Sprinkles3 = look(rgb(150, 255, 140))},
  -- A twisted pink-and-white candy ribbon in a bubbly pink glow, bubbles and sprinkles.
  flight = {color = rgb(255, 120, 200), land = "Sprinkles", layers = {
   ribbon {colors = {rgb(255, 110, 190), rgb(255, 60, 160)}, width = 0.3, lifetime = 0.45, taper = "swell", orbit = {radius = 0.35, speed = 2.2}},
   ribbon {colors = {WHITE, rgb(255, 210, 235)}, width = 0.3, lifetime = 0.45, taper = "swell", orbit = {radius = 0.35, speed = 2.2, phase = 0.5}},
   streak {colors = {rgb(255, 170, 220), rgb(255, 110, 200)}, size = 1.1, endSize = 0.3, lifetime = 0.3, transparency = 0.5, glow = true},
   emit("Bubbles", {rate = 40, back = true}),
   emit("Sprinkles", {rate = 30}),
  }},
  idle = "Bubbles",
 },
 crystal_ball = {
  parts = {Shell = look(rgb(160, 92, 235), M.Glass, 0.25), Core = look(rgb(215, 150, 255), M.Neon),
   Points = look(rgb(205, 160, 255), M.Glass, 0.15)},
  light = {rgb(200, 130, 255), 1.5, 8},
  -- A prismatic ribbon in glittering segments, a sparkling glow, three crystal shards in orbit.
  flight = {color = rgb(200, 130, 255), land = "Gems", layers = {
   ribbon {colors = {rgb(230, 180, 255), rgb(180, 100, 255), rgb(90, 170, 255)}, width = 0.7, lifetime = 0.45, glow = true, taper = "teardrop", bands = 4},
   ribbon {colors = {rgb(170, 90, 240), rgb(90, 40, 200)}, width = 0.3, lifetime = 0.35, taper = "needle"},
   streak {texture = "sparkle", colors = {rgb(230, 190, 255), rgb(140, 200, 255)}, size = 1, endSize = 0.2, lifetime = 0.35, glow = true,
    rotSpeed = 180},
   orbiters {count = 3, radius = 0.9, speed = 1.3, size = Vector3.new(0.16, 0.34, 0.16), color = rgb(215, 160, 255),
    material = M.Glass, transparency = 0.15, spin = 6, trail = {width = 0.1, lifetime = 0.2}},
   emit("Glitter", {back = true}),
  }},
  idle = "Glitter",
 },
 frost_comet = {
  parts = {Shell = look(rgb(140, 210, 255), M.Glass, 0.3), Core = look(rgb(225, 245, 255), M.Neon),
   Shards = look(rgb(220, 240, 255), M.Ice), Seam = look(rgb(255, 255, 255), M.Neon)},
  light = {rgb(160, 220, 255), 2, 10},
  -- A long glowing comet tail wrapped in frosty mist, shedding snow and ice shards.
  flight = {color = rgb(170, 225, 255), land = "Frost", layers = {
   ribbon {colors = {rgb(200, 240, 255), rgb(90, 190, 255), rgb(30, 90, 230)}, width = 1.1, lifetime = 0.9, glow = true, fade = {0.05, 1}, taper = "needle"},
   streak {colors = {rgb(220, 245, 255), rgb(120, 190, 255)}, size = 1.4, endSize = 0.4, lifetime = 0.5, glow = true, transparency = 0.35},
   streak {texture = "smoke", colors = {rgb(235, 250, 255), rgb(160, 215, 255)}, size = 1, endSize = 3, lifetime = 0.7, rate = 60,
    transparency = 0.5},
   emit("Snow", {back = true}),
   debris {rate = 9, size = Vector3.new(0.08, 0.3, 0.08), color = rgb(210, 240, 255), material = M.Ice, transparency = 0.2,
    life = 0.6, fall = 4},
  }},
  idle = "Snow",
 },
 inferno_ball = {
  parts = {Shell = look(rgb(34, 28, 28), M.Basalt), Lava = look(rgb(255, 115, 25), M.Neon)},
  light = {rgb(255, 120, 40), 2, 10},
  -- A tongue of flame licking behind the ball inside rolling fire, over a trail of black smoke.
  flight = {color = rgb(255, 130, 40), land = "Fire", layers = {
   ribbon {colors = {rgb(255, 245, 170), rgb(255, 140, 30), rgb(200, 40, 10)}, width = 1, lifetime = 0.4, glow = true, taper = "flame"},
   streak {texture = "fire", colors = {rgb(255, 230, 140), rgb(255, 90, 20)}, size = 1.4, endSize = 0.5, lifetime = 0.35, glow = true,
    rotSpeed = 120},
   streak {texture = "smoke", colors = {rgb(80, 60, 55), rgb(25, 20, 20)}, size = 1, endSize = 3, lifetime = 0.9, rate = 60, transparency = 0.4},
   emit("Embers", {rate = 25, back = true}),
  }},
  idle = "Embers",
 },
 thunder_ball = {
  parts = {Shell = look(rgb(92, 42, 165)), Bolts = look(rgb(255, 235, 70), M.Neon)},
  light = {rgb(255, 235, 120), 2, 10},
  -- A jagged, crackling electric streak in a violet glow, with lightning arcing off the ball.
  flight = {color = rgb(255, 235, 110), launch = "Zap", land = "Zap", layers = {
   ribbon {colors = {rgb(255, 250, 160), rgb(255, 215, 50), rgb(150, 80, 255)}, width = 0.5, lifetime = 0.3, glow = true, taper = "scallop",
    jitter = 0.18, flicker = true},
   streak {colors = {rgb(200, 160, 255), rgb(110, 60, 220)}, size = 1.3, endSize = 0.3, lifetime = 0.3, glow = true, transparency = 0.4},
   arcs {rate = 26, color = rgb(255, 245, 160), length = 2.2},
   arcs {rate = 12, color = rgb(190, 140, 255), length = 1.6},
   emit("Sparks", {rate = 50}),
  }},
  idle = "Sparks",
 },
 galaxy_ball = {
  parts = {Shell = look(rgb(18, 12, 52)), NebulaPink = look(rgb(255, 100, 205), M.Neon, 0.15),
   NebulaBlue = look(rgb(90, 160, 255), M.Neon, 0.15), Stars = look(rgb(255, 255, 255), M.Neon)},
  light = {rgb(170, 130, 255), 1.5, 9},
  -- Three spiralling star streams through a drifting nebula cloud, with stars orbiting the ball.
  flight = {color = rgb(170, 130, 255), land = "Stardust", layers = {
   ribbon {colors = {rgb(255, 130, 225), rgb(200, 60, 180)}, width = 0.22, lifetime = 0.55, glow = true, taper = "teardrop", orbit = {radius = 0.45, speed = 1.5}},
   ribbon {colors = {rgb(110, 170, 255), rgb(50, 80, 220)}, width = 0.22, lifetime = 0.55, glow = true, taper = "teardrop", orbit = {radius = 0.45, speed = 1.5, phase = 1 / 3}},
   ribbon {colors = {rgb(200, 150, 255), rgb(110, 60, 220)}, width = 0.22, lifetime = 0.55, glow = true, taper = "teardrop", orbit = {radius = 0.45, speed = 1.5, phase = 2 / 3}},
   streak {texture = "smoke", colors = {rgb(255, 120, 220), rgb(90, 120, 255)}, size = 1.2, endSize = 3, lifetime = 0.75, rate = 70,
    glow = true, transparency = 0.55},
   orbiters {count = 4, radius = 0.85, speed = 2, size = Vector3.one * 0.12, shape = "Ball", color = WHITE,
    trail = {width = 0.06, lifetime = 0.25}},
   emit("Stardust", {back = true}),
  }},
  idle = "Stardust",
 },
 dragonfire_ball = {
  parts = {Shell = look(rgb(52, 10, 12)), Scales = look(rgb(135, 22, 22), M.Slate),
   EyeSlit = look(rgb(255, 175, 35), M.Neon), Spines = look(rgb(28, 22, 22))},
  light = {rgb(255, 130, 40), 2.5, 12},
  -- Twin weaving tongues of dragon flame in a fiery wake, black smoke, and bursts of fire
  -- breath along the way.
  flight = {color = rgb(255, 120, 30), launch = "Fire", land = "Fire", layers = {
   ribbon {colors = {rgb(255, 235, 130), rgb(255, 90, 20), rgb(150, 10, 10)}, width = 0.7, lifetime = 0.45, glow = true,
    taper = "flame", offset = Vector3.new(-0.45, 0, 0), wobble = {amp = 0.25, freq = 3}},
   ribbon {colors = {rgb(255, 235, 130), rgb(255, 90, 20), rgb(150, 10, 10)}, width = 0.7, lifetime = 0.45, glow = true,
    taper = "flame", offset = Vector3.new(0.45, 0, 0), wobble = {amp = 0.25, freq = 3, phase = 0.5}},
   streak {texture = "fire", colors = {rgb(255, 220, 120), rgb(220, 40, 10)}, size = 1.6, endSize = 0.6, lifetime = 0.4, glow = true,
    rotSpeed = 140},
   streak {texture = "smoke", colors = {rgb(70, 25, 20), rgb(20, 12, 12)}, size = 1.2, endSize = 3.2, lifetime = 0.9, rate = 60, transparency = 0.45},
   pulse {interval = 0.3, color = rgb(255, 120, 30), texture = "core", size = 3.5, life = 0.35},
   emit("Embers", {rate = 30, back = true}),
  }},
  idle = "Embers",
 },
 supernova_ball = {
  parts = {Core = look(rgb(255, 246, 210), M.Neon), Halo = look(rgb(255, 220, 120), M.Neon, 0.65),
   Flares = look(rgb(255, 205, 80), M.Neon),
   Ring1 = look(rgb(255, 70, 80), M.Neon), Ring2 = look(rgb(255, 155, 40), M.Neon), Ring3 = look(rgb(255, 240, 70), M.Neon),
   Ring4 = look(rgb(90, 255, 120), M.Neon), Ring5 = look(rgb(80, 155, 255), M.Neon), Ring6 = look(rgb(180, 90, 255), M.Neon)},
  light = {rgb(255, 240, 200), 3, 14},
  -- A blazing rainbow comet in glowing bands around a white-hot core, rainbow sparks in orbit,
  -- and shockwaves pulsing out behind it.
  flight = {color = rgb(255, 240, 200), launch = "Shockwave", land = "Supernova", layers = {
   ribbon {rainbow = true, width = 1.1, lifetime = 0.65, glow = true, taper = "teardrop", bands = 5},
   streak {colors = {WHITE, rgb(255, 230, 160)}, size = 1.6, endSize = 0.3, lifetime = 0.35, glow = true, transparency = 0.1},
   ribbon {colors = {rgb(255, 220, 120), rgb(255, 160, 60)}, width = 0.2, lifetime = 0.5, glow = true, taper = "teardrop", orbit = {radius = 0.55, speed = 2}},
   ribbon {colors = {WHITE, rgb(200, 220, 255)}, width = 0.2, lifetime = 0.5, glow = true, taper = "teardrop", orbit = {radius = 0.55, speed = 2, phase = 0.5}},
   orbiters {count = 6, radius = 1.05, speed = 1.4, size = Vector3.one * 0.14, shape = "Ball",
    colors = {rgb(255, 70, 80), rgb(255, 155, 40), rgb(255, 240, 70), rgb(90, 255, 120), rgb(80, 155, 255), rgb(180, 90, 255)},
    trail = {width = 0.08, lifetime = 0.3}},
   pulse {interval = 0.22, color = rgb(255, 240, 200), size = 6, life = 0.4},
   emit("Stars", {rate = 60}),
  }},
  idle = "Stars",
 },
 -- World 2 (Time Travel): one ball per era, from tools/blender/balls_world2.py.
 dino_egg_ball = {
  parts = {Shell = look(rgb(242, 232, 204)), Spots = look(rgb(96, 150, 70)), Cracks = look(rgb(70, 52, 40))},
  -- A swaying jungle-green trail in a leafy glow, shedding leaves, eggshell bits and spores.
  flight = {color = rgb(150, 220, 110), land = "Leaves", layers = {
   ribbon {colors = {rgb(160, 235, 90), rgb(80, 175, 55), rgb(40, 110, 40)}, width = 0.75, lifetime = 0.5, taper = "scallop",
    wobble = {amp = 0.18, freq = 2.5}},
   streak {colors = {rgb(190, 250, 130), rgb(90, 185, 60)}, size = 1.2, endSize = 0.3, lifetime = 0.35, glow = true, transparency = 0.35},
   debris {rate = 14, size = Vector3.new(0.26, 0.03, 0.15), colors = {rgb(90, 170, 60), rgb(60, 140, 50), rgb(140, 200, 80)},
    life = 0.9, fall = 2.5, spread = 2},
   debris {rate = 6, size = Vector3.new(0.14, 0.03, 0.12), color = rgb(245, 236, 210), life = 0.6, fall = 6},
   emit("Spores", {back = true}),
  }},
  idle = "Spores",
 },
 stone_ball = {
  parts = {Shell = look(rgb(140, 136, 130), M.Slate), Cracks = look(rgb(60, 56, 54), M.Slate), Moss = look(rgb(90, 140, 60), M.Grass)},
  -- A heavy boulder: a thick billowing dust cloud, pebbles circling, and rock chunks breaking off.
  flight = {color = rgb(200, 195, 185), aura = false, land = "Rockslide", layers = {
   streak {texture = "smoke", colors = {rgb(215, 210, 200), rgb(130, 125, 118)}, size = 1.2, endSize = 3.2, lifetime = 0.7, rate = 70,
    transparency = 0.3},
   ribbon {colors = {rgb(170, 165, 158), rgb(110, 105, 100)}, width = 0.45, lifetime = 0.3, taper = "teardrop"},
   orbiters {count = 3, radius = 0.85, speed = 1.2, size = Vector3.new(0.2, 0.17, 0.22), colors = {rgb(130, 126, 120), rgb(100, 96, 92)},
    material = M.Slate, spin = 4},
   debris {rate = 16, size = Vector3.new(0.26, 0.22, 0.24), colors = {rgb(140, 136, 130), rgb(105, 100, 96), rgb(90, 140, 60)},
    material = M.Slate, life = 0.7, fall = 10},
  }},
 },
 scarab_ball = {
  parts = {Shell = look(rgb(38, 68, 168)), Scarab = look(rgb(255, 196, 60), M.Foil), Bands = look(rgb(240, 186, 64), M.Foil)},
  light = {rgb(255, 210, 110), 1.5, 9},
  -- Gold and lapis strands spiralling through a swirling stream of desert sand, with golden
  -- scarabs circling the ball.
  flight = {color = rgb(255, 205, 90), land = "Sandstorm", layers = {
   ribbon {colors = {rgb(255, 225, 110), rgb(220, 160, 40)}, width = 0.25, lifetime = 0.55, glow = true, taper = "teardrop", orbit = {radius = 0.4, speed = 1.7}},
   ribbon {colors = {rgb(80, 120, 230), rgb(30, 50, 160)}, width = 0.25, lifetime = 0.55, taper = "teardrop", orbit = {radius = 0.4, speed = 1.7, phase = 0.5}},
   streak {texture = "smoke", colors = {rgb(250, 225, 160), rgb(214, 170, 100)}, size = 1, endSize = 3, lifetime = 0.8, rate = 70,
    transparency = 0.4},
   streak {texture = "sparkle", colors = {rgb(255, 230, 140)}, size = 0.8, endSize = 0.2, lifetime = 0.4, glow = true, rate = 60, rotSpeed = 180},
   orbiters {count = 2, radius = 0.95, speed = 0.9, size = Vector3.new(0.22, 0.08, 0.3), color = rgb(255, 200, 60), material = M.Foil},
  }},
  idle = "GoldGlitter",
 },
 laurel_ball = { -- Olympian Laurel
  parts = {Shell = look(rgb(244, 242, 236), M.Marble), Laurel = look(rgb(255, 204, 70), M.Foil), Meander = look(rgb(232, 182, 60), M.Foil)},
  light = {rgb(255, 236, 170), 1.8, 10},
  -- A triumphant white-gold streak in golden segments, shedding laurel leaves, with victory
  -- rings rippling out behind.
  flight = {color = rgb(255, 225, 140), launch = "Laurel", land = "Laurel", layers = {
   ribbon {colors = {rgb(255, 225, 120), rgb(255, 190, 50), rgb(215, 135, 20)}, width = 0.9, lifetime = 0.55, glow = true, taper = "teardrop", bands = 3},
   streak {colors = {rgb(255, 235, 160), rgb(255, 190, 60)}, size = 1.4, endSize = 0.3, lifetime = 0.4, glow = true, transparency = 0.2},
   debris {rate = 12, size = Vector3.new(0.24, 0.03, 0.12), colors = {rgb(255, 205, 70), rgb(240, 180, 50)}, material = M.Foil,
    life = 1, fall = 2, spread = 1.8},
   pulse {interval = 0.35, color = rgb(255, 215, 110), size = 4, life = 0.45},
   emit("GoldGlitter", {rate = 25}),
  }},
  idle = "GoldGlitter",
 },
 viking_rune_ball = {
  parts = {Shell = look(rgb(58, 60, 68), M.Metal), Bands = look(rgb(176, 120, 60), M.Metal), Rivets = look(rgb(214, 168, 96), M.Metal),
   Runes = look(rgb(110, 230, 255), M.Neon)},
  light = {rgb(110, 230, 255), 2, 10},
  -- Glowing rune stones circling the ball, an icy flickering trail in rune-lit segments, frost
  -- mist and rune lightning.
  flight = {color = rgb(110, 230, 255), launch = "Zap", land = "Frost", layers = {
   ribbon {colors = {rgb(120, 235, 255), rgb(40, 190, 255), rgb(20, 80, 200)}, width = 0.85, lifetime = 0.55, glow = true, fade = {0.05, 1},
    taper = "scallop", bands = 3, flicker = true},
   streak {texture = "smoke", colors = {rgb(210, 245, 255), rgb(120, 180, 230)}, size = 1, endSize = 2.8, lifetime = 0.6, rate = 60,
    transparency = 0.55},
   orbiters {count = 4, radius = 0.95, speed = 1.1, size = Vector3.new(0.16, 0.26, 0.06), color = rgb(110, 230, 255),
    spin = 3, trail = {width = 0.08, lifetime = 0.2}},
   arcs {rate = 8, color = rgb(150, 240, 255), length = 1.4, thickness = 0.05},
   emit("Runes", {back = true}),
  }},
  idle = "Runes",
 },
 samurai_ball = {
  parts = {Shell = look(rgb(198, 30, 34)), Bands = look(rgb(28, 24, 26)), Crest = look(rgb(255, 200, 70), M.Foil),
   Petals = look(rgb(255, 182, 214))},
  light = {rgb(255, 150, 190), 1.5, 9},
  -- Two crossing katana-slash ribbons and a flowing red silk trail in a storm of cherry blossoms.
  flight = {color = rgb(255, 160, 200), land = "Petals", layers = {
   ribbon {colors = {WHITE, rgb(255, 200, 225)}, width = 0.16, lifetime = 0.25, glow = true, taper = "needle",
    wobble = {amp = 0.55, freq = 2.2}, fade = {0, 1}},
   ribbon {colors = {WHITE, rgb(255, 200, 225)}, width = 0.16, lifetime = 0.25, glow = true, taper = "needle",
    wobble = {amp = 0.55, freq = 2.2, phase = 0.5}, fade = {0, 1}},
   ribbon {colors = {rgb(255, 90, 110), rgb(180, 20, 40)}, width = 0.5, lifetime = 0.5, taper = "swell", wobble = {amp = 0.12, freq = 4}},
   streak {colors = {rgb(255, 200, 225), rgb(255, 120, 170)}, size = 1, endSize = 0.3, lifetime = 0.3, glow = true, transparency = 0.5},
   debris {rate = 22, size = Vector3.new(0.18, 0.02, 0.14), colors = {rgb(255, 182, 214), rgb(255, 210, 230), rgb(255, 150, 190)},
    life = 1.1, fall = 1.6, spread = 2.2},
  }},
  idle = "Petals",
 },
 knight_ball = { -- Knight's Ball
  parts = {Shell = look(rgb(204, 210, 220), M.Metal), Visor = look(rgb(24, 24, 30)), Trim = look(rgb(255, 200, 70), M.Foil),
   Plume = look(rgb(210, 30, 36), M.Fabric)},
  light = {rgb(230, 236, 255), 1.8, 10},
  -- A gleaming steel streak with a red plume banner fluttering above it, sparks flying and
  -- glints of light.
  flight = {color = rgb(220, 230, 255), launch = "Clang", land = "Clang", layers = {
   ribbon {colors = {rgb(210, 225, 255), rgb(140, 160, 210), rgb(80, 100, 155)}, width = 0.9, lifetime = 0.5, taper = "teardrop", fade = {0.05, 1}},
   streak {colors = {WHITE, rgb(190, 205, 235)}, size = 0.9, endSize = 0.2, lifetime = 0.25, glow = true, transparency = 0.3},
   ribbon {colors = {rgb(235, 45, 55), rgb(140, 10, 20)}, width = 0.35, lifetime = 0.55, taper = "flame", offset = Vector3.new(0, 0.5, 0),
    wobble = {amp = 0.22, freq = 6}},
   pulse {interval = 0.3, color = WHITE, texture = "glow", from = 0.3, size = 2.2, life = 0.2},
   emit("Sparks", {rate = 40}),
  }},
  idle = "GoldGlitter",
 },
 sheriff_star_ball = {
  parts = {Shell = look(rgb(196, 150, 96), M.Leather), Stitches = look(rgb(250, 244, 230)), Star = look(rgb(255, 204, 60), M.Foil)},
  light = {rgb(255, 210, 110), 1.8, 10},
  -- A dusty frontier trail in a billowing dust cloud, with gold stars circling like a
  -- spinning badge.
  flight = {color = rgb(255, 205, 100), launch = "Dust", land = "Sheriff", layers = {
   ribbon {colors = {rgb(255, 225, 140), rgb(225, 160, 60)}, width = 0.6, lifetime = 0.45, glow = true, taper = "teardrop"},
   streak {texture = "smoke", colors = {rgb(232, 205, 155), rgb(170, 125, 80)}, size = 1, endSize = 3, lifetime = 0.75, rate = 65,
    transparency = 0.45},
   orbiters {count = 3, radius = 0.9, speed = 1.6, size = Vector3.new(0.22, 0.22, 0.05), color = rgb(255, 205, 60), material = M.Foil,
    spin = 8, trail = {width = 0.07, lifetime = 0.2}},
   emit("GoldGlitter", {rate = 25}),
  }},
  idle = "GoldGlitter",
 },
 clockwork_ball = {
  parts = {Shell = look(rgb(222, 170, 76), M.Metal), Gears = look(rgb(196, 112, 60), M.Metal), Dial = look(rgb(252, 246, 226)),
   Glow = look(rgb(90, 230, 255), M.Neon)},
  light = {rgb(140, 230, 255), 2.2, 11},
  -- Brass and cyan strands winding round the ball in ticking segments, spinning gears in
  -- orbit, steam puffs, and a ticking ring every half second.
  flight = {color = rgb(140, 225, 255), launch = "Shockwave", land = "TimeWarp", layers = {
   ribbon {colors = {rgb(255, 205, 90), rgb(200, 135, 40)}, width = 0.34, lifetime = 0.6, taper = "teardrop", bands = 4, orbit = {radius = 0.42, speed = 1.2}},
   ribbon {colors = {rgb(110, 230, 255), rgb(30, 150, 230)}, width = 0.34, lifetime = 0.6, glow = true, taper = "teardrop", bands = 4,
    orbit = {radius = 0.42, speed = 1.2, phase = 0.5}},
   streak {colors = {rgb(150, 235, 255), rgb(50, 165, 230)}, size = 1.2, endSize = 0.3, lifetime = 0.35, glow = true, transparency = 0.3},
   orbiters {count = 3, radius = 0.95, speed = 0.8, size = Vector3.new(0.08, 0.46, 0.46), shape = "Cylinder", color = rgb(200, 120, 60),
    material = M.Metal, spin = 5},
   pulse {interval = 0.5, color = rgb(120, 230, 255), size = 3.5, life = 0.35},
   emit("Steam", {back = true}),
  }},
  idle = "TimeDust",
 },
 chrono_orb = {
  parts = {Shell = look(rgb(170, 240, 255), M.Glass, 0.55), Core = look(rgb(90, 230, 255), M.Neon),
   Ring1 = look(rgb(232, 182, 74), M.Metal), Ring2 = look(rgb(232, 182, 74), M.Metal), Numerals = look(rgb(255, 230, 150), M.Neon)},
  light = {rgb(110, 230, 255), 3, 14},
  -- Bends time: ghostly echoes of the orb left behind, a swirling vortex wake, colour-shifting
  -- strands, time ripples and golden sparks in orbit.
  flight = {color = rgb(110, 230, 255), launch = "TimeWarp", land = "TimeWarp", layers = {
   echoes {interval = 0.06, color = rgb(120, 235, 255), life = 0.4, grow = 1.5},
   streak {texture = "vortex", colors = {rgb(150, 245, 255), rgb(160, 90, 255)}, size = 1.4, endSize = 2.4, lifetime = 0.5, glow = true,
    rotSpeed = 240, transparency = 0.3},
   ribbon {width = 0.2, lifetime = 0.55, glow = true, taper = "teardrop", orbit = {radius = 0.5, speed = 2}, hueShift = 0.4, colors = {WHITE}},
   ribbon {width = 0.2, lifetime = 0.55, glow = true, taper = "teardrop", orbit = {radius = 0.5, speed = 2, phase = 1 / 3}, hueShift = 0.4, colors = {WHITE}},
   ribbon {width = 0.2, lifetime = 0.55, glow = true, taper = "teardrop", orbit = {radius = 0.5, speed = 2, phase = 2 / 3}, hueShift = 0.4, colors = {WHITE}},
   orbiters {count = 2, radius = 1.15, speed = 2.4, size = Vector3.one * 0.14, shape = "Ball", color = rgb(255, 220, 120),
    trail = {width = 0.08, lifetime = 0.3}},
   pulse {interval = 0.25, color = rgb(140, 240, 255), texture = "vortex", size = 5, life = 0.45, rotSpeed = 200},
   emit("TimeDust", {rate = 50}),
  }},
  idle = "TimeDust",
 },
 -- World 3 (Future World): one ball per runway section, from tools/blender/balls_world3.py.
 solar_cell_ball = { -- Solar Cell
  parts = {Shell = look(rgb(255, 190, 60), M.Foil), Panels = look(rgb(28, 48, 120), M.Glass), Frames = look(rgb(214, 218, 226), M.Metal),
   Glow = look(rgb(255, 170, 40), M.Neon)},
  light = {rgb(255, 200, 90), 1.5, 9},
  -- A warm sunbeam streak in glowing segments, sun glints scattering off it, and a ring of sunlight.
  flight = {color = rgb(255, 214, 110), land = "Solar", layers = {
   ribbon {colors = {rgb(255, 250, 220), rgb(255, 200, 70), rgb(240, 140, 30)}, width = 0.8, lifetime = 0.5, glow = true, taper = "teardrop", bands = 4},
   streak {colors = {rgb(255, 245, 200), rgb(255, 190, 60)}, size = 1.3, endSize = 0.3, lifetime = 0.35, glow = true, transparency = 0.25},
   emit("SunGlints", {rate = 40}),
   pulse {interval = 0.4, color = rgb(255, 220, 120), texture = "glow", from = 0.4, size = 3, life = 0.3},
  }},
  idle = "SunGlints",
 },
 hover_ball = {
  parts = {Shell = look(rgb(214, 220, 230), M.Metal), Ring = look(rgb(70, 190, 255), M.Neon), Vents = look(rgb(32, 34, 42), M.Metal),
   Lights = look(rgb(110, 220, 255), M.Neon)},
  light = {rgb(110, 220, 255), 2, 10},
  -- Twin thin cyan contrails like hover thrusters, with hover rings rippling out along the path.
  flight = {color = rgb(110, 220, 255), land = "HoverRing", layers = {
   ribbon {colors = {rgb(200, 245, 255), rgb(60, 180, 255)}, width = 0.12, lifetime = 0.5, glow = true, taper = "needle", offset = Vector3.new(0.45, 0, 0)},
   ribbon {colors = {rgb(200, 245, 255), rgb(60, 180, 255)}, width = 0.12, lifetime = 0.5, glow = true, taper = "needle", offset = Vector3.new(-0.45, 0, 0)},
   streak {colors = {rgb(170, 235, 255), rgb(70, 170, 255)}, size = 0.9, endSize = 0.2, lifetime = 0.25, glow = true, transparency = 0.35},
   pulse {interval = 0.2, color = rgb(110, 225, 255), size = 3.2, life = 0.35},
  }},
 },
 hologram_ball = {
  parts = {Shell = look(rgb(90, 190, 255), M.Glass, 0.6), Grid = look(rgb(80, 220, 255), M.Neon), Scanlines = look(rgb(200, 250, 255), M.Neon, 0.2),
   Core = look(rgb(225, 250, 255), M.Neon)},
  light = {rgb(110, 220, 255), 2, 10},
  -- Glitchy blue afterimages: flickering echoes of the ball, a crackling scan-line ribbon and
  -- hologram sparks.
  flight = {color = rgb(120, 230, 255), launch = "Glitch", land = "Glitch", layers = {
   echoes {interval = 0.05, color = rgb(120, 230, 255), life = 0.3, grow = 1.25},
   ribbon {colors = {rgb(200, 250, 255), rgb(60, 170, 255)}, width = 0.7, lifetime = 0.4, glow = true, taper = "scallop", bands = 6,
    flicker = true, jitter = 0.06},
   streak {colors = {rgb(170, 240, 255), rgb(60, 160, 255)}, size = 1, endSize = 0.3, lifetime = 0.3, glow = true, transparency = 0.4},
   emit("HoloSparks", {rate = 35}),
  }},
  idle = "HoloSparks",
 },
 robo_core_ball = { -- Robo Core
  parts = {Shell = look(rgb(160, 166, 176), M.Metal), Seams = look(rgb(96, 100, 110), M.Metal), Rivets = look(rgb(205, 210, 218), M.Metal),
   Eye = look(rgb(255, 40, 30), M.Neon), Bezel = look(rgb(30, 30, 36), M.Metal)},
  light = {rgb(255, 60, 40), 1.5, 8},
  -- A steel streak with a red laser core, sparks flying and nuts and bolts shaken loose.
  flight = {color = rgb(255, 90, 80), launch = "Clang", land = "Clang", layers = {
   ribbon {colors = {rgb(220, 226, 236), rgb(130, 138, 152), rgb(70, 76, 88)}, width = 0.8, lifetime = 0.45, taper = "teardrop", fade = {0.05, 1}},
   ribbon {colors = {rgb(255, 120, 110), rgb(220, 20, 30)}, width = 0.16, lifetime = 0.35, glow = true, taper = "needle"},
   emit("Sparks", {rate = 45}),
   debris {rate = 12, size = Vector3.new(0.14, 0.14, 0.2), colors = {rgb(120, 126, 138), rgb(170, 176, 188)}, material = M.Metal,
    shape = "Cylinder", life = 0.7, fall = 8},
  }},
  idle = "Sparks",
 },
 bio_seed_ball = { -- Bio Seed
  parts = {Shell = look(rgb(200, 255, 225), M.Glass, 0.6), Sprout = look(rgb(120, 255, 90), M.Neon), Soil = look(rgb(92, 60, 38), M.Ground),
   Vines = look(rgb(60, 140, 55), M.Grass)},
  light = {rgb(140, 255, 110), 1.8, 9},
  -- A curling vine-green trail, glowing spores drifting off it, and leaves shed behind.
  flight = {color = rgb(140, 255, 150), land = "Leaves", layers = {
   ribbon {colors = {rgb(190, 255, 160), rgb(80, 200, 90), rgb(30, 120, 60)}, width = 0.6, lifetime = 0.5, taper = "scallop",
    wobble = {amp = 0.22, freq = 2.2}},
   ribbon {colors = {rgb(220, 255, 200), rgb(120, 230, 140)}, width = 0.14, lifetime = 0.5, glow = true, taper = "needle",
    orbit = {radius = 0.5, speed = 1.4}},
   streak {colors = {rgb(200, 255, 190), rgb(90, 210, 110)}, size = 1.1, endSize = 0.3, lifetime = 0.35, glow = true, transparency = 0.35},
   emit("Spores", {rate = 40, back = true}),
   debris {rate = 10, size = Vector3.new(0.24, 0.03, 0.14), colors = {rgb(90, 190, 80), rgb(130, 220, 100)}, life = 0.9, fall = 2.5, spread = 2},
  }},
  idle = "Spores",
 },
 pixel_ball = {
  parts = {Shell = look(rgb(40, 120, 255)), Pixels1 = look(rgb(255, 60, 180)), Pixels2 = look(rgb(255, 215, 40)),
   Pixels3 = look(rgb(240, 255, 255), M.Neon)},
  light = {rgb(120, 255, 190), 1.8, 10},
  -- A trail of square pixels in arcade colours and a stepped rainbow ribbon.
  flight = {color = rgb(120, 255, 190), launch = "Pixels", land = "Pixels", layers = {
   ribbon {rainbow = true, width = 0.6, lifetime = 0.45, glow = true, taper = "scallop", bands = 7},
   debris {rate = 45, size = Vector3.new(0.2, 0.2, 0.2), colors = {rgb(255, 90, 140), rgb(255, 210, 60), rgb(90, 160, 255), rgb(60, 230, 160),
    rgb(200, 120, 255)}, material = M.Neon, life = 0.55, fall = 0.5, spread = 1.4},
   streak {colors = {rgb(220, 255, 240), rgb(120, 255, 190)}, size = 0.9, endSize = 0.2, lifetime = 0.25, glow = true, transparency = 0.45},
  }},
  idle = "PixelSparks",
 },
 rocket_ball = {
  parts = {Shell = look(rgb(245, 245, 242)), Stripes = look(rgb(220, 35, 40)), Fins = look(rgb(220, 35, 40)),
   Window = look(rgb(140, 210, 255), M.Glass, 0.2), Nozzle = look(rgb(52, 54, 60), M.Metal)},
  light = {rgb(255, 150, 60), 2.2, 11},
  -- Rocket exhaust: a roaring flame ribbon, a fire streak and a billowing smoke trail.
  flight = {color = rgb(255, 150, 60), launch = "Fire", land = "Shockwave", layers = {
   ribbon {colors = {rgb(255, 250, 200), rgb(255, 160, 40), rgb(230, 60, 20)}, width = 0.85, lifetime = 0.35, glow = true, taper = "flame",
    wobble = {amp = 0.06, freq = 9}},
   streak {texture = "fire", colors = {rgb(255, 230, 140), rgb(255, 110, 30)}, size = 1.1, endSize = 0.4, lifetime = 0.3, glow = true, rate = 90},
   streak {texture = "smoke", colors = {rgb(230, 230, 236), rgb(150, 150, 160)}, size = 1, endSize = 3.4, lifetime = 0.9, rate = 70,
    transparency = 0.4},
   emit("Flame", {back = true}),
  }},
 },
 moon_rock_ball = { -- Moon Rock
  parts = {Shell = look(rgb(170, 170, 176), M.Slate), Craters = look(rgb(112, 112, 120), M.Slate), Glow = look(rgb(110, 255, 210), M.Neon)},
  light = {rgb(120, 255, 210), 1.2, 8},
  -- Floating moon dust hanging in the air behind it, pale moonlight, and little moon rocks in orbit.
  flight = {color = rgb(190, 220, 255), land = "MoonDust", layers = {
   streak {texture = "smoke", colors = {rgb(225, 228, 236), rgb(160, 164, 176)}, size = 1, endSize = 2.6, lifetime = 1.1, rate = 55,
    transparency = 0.45},
   ribbon {colors = {rgb(230, 240, 255), rgb(140, 170, 220)}, width = 0.45, lifetime = 0.5, glow = true, taper = "teardrop", fade = {0.3, 1}},
   orbiters {count = 3, radius = 0.9, speed = 0.7, size = Vector3.new(0.18, 0.15, 0.2), colors = {rgb(150, 150, 158), rgb(120, 120, 128)},
    material = M.Slate, spin = 2},
   emit("MoonDust", {rate = 30, back = true}),
  }},
  idle = "MoonDust",
 },
 red_planet_ball = { -- Red Planet
  parts = {Shell = look(rgb(196, 88, 46), M.Sandstone), Regions = look(rgb(120, 44, 28), M.Sandstone), Storm = look(rgb(248, 196, 140)),
   IceCaps = look(rgb(245, 250, 255), M.Snow)},
  light = {rgb(255, 150, 90), 1.8, 10},
  -- A billowing plume of red dust, a rust-orange ribbon, and two tiny moons in orbit.
  flight = {color = rgb(255, 150, 90), land = "RedDust", layers = {
   streak {texture = "smoke", colors = {rgb(236, 150, 100), rgb(170, 70, 40)}, size = 1.2, endSize = 3.4, lifetime = 0.85, rate = 70,
    transparency = 0.35},
   ribbon {colors = {rgb(255, 200, 140), rgb(220, 100, 50), rgb(130, 40, 20)}, width = 0.7, lifetime = 0.45, glow = true, taper = "teardrop"},
   orbiters {count = 2, radius = 1.05, speed = 1.3, size = Vector3.one * 0.16, shape = "Ball", colors = {rgb(160, 130, 110), rgb(130, 110, 96)},
    trail = {width = 0.05, lifetime = 0.25}},
   emit("RedDust", {back = true}),
  }},
  idle = "RedDust",
 },
 singularity_orb = { -- Singularity Orb
  parts = {Shell = look(rgb(6, 6, 10)), Ring = look(rgb(255, 160, 60), M.Neon), Halo = look(rgb(255, 240, 210), M.Neon),
   Lens = look(rgb(170, 190, 255), M.Glass, 0.8)},
  light = {rgb(255, 170, 80), 2.5, 12},
  -- Bends space: a purple vortex wake, an accretion ribbon whirling round the core, warping
  -- rings rippling out, and bright motes spiralling in.
  flight = {color = rgb(190, 130, 255), launch = "Singularity", land = "Singularity", layers = {
   streak {texture = "vortex", colors = {rgb(210, 170, 255), rgb(60, 20, 110)}, size = 1.6, endSize = 2.8, lifetime = 0.55, glow = true,
    rotSpeed = 300, transparency = 0.25},
   ribbon {colors = {rgb(255, 230, 190), rgb(255, 150, 70)}, width = 0.18, lifetime = 0.5, glow = true, taper = "teardrop",
    orbit = {radius = 0.55, speed = 2.6}},
   ribbon {colors = {rgb(220, 180, 255), rgb(120, 60, 220)}, width = 0.18, lifetime = 0.5, glow = true, taper = "teardrop",
    orbit = {radius = 0.55, speed = 2.6, phase = 0.5}},
   echoes {interval = 0.08, color = rgb(150, 90, 255), life = 0.45, grow = 1.7},
   pulse {interval = 0.22, color = rgb(190, 130, 255), texture = "vortex", size = 5.5, life = 0.45, rotSpeed = -220},
   orbiters {count = 3, radius = 1.2, speed = 2.8, size = Vector3.one * 0.12, shape = "Ball", color = rgb(255, 230, 200),
    trail = {width = 0.07, lifetime = 0.3}},
   emit("VoidDust", {rate = 50}),
  }},
  idle = "VoidDust",
 },
}

-- Particle presets on built-in Roblox textures (no uploads needed). Sizes suit the
-- 0.8-stud ball in flight; the display scales them with the item.
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/fire_sparks_main.dds"
local function range(a, z) return NumberRange.new(a, z) end
local function grow(a, z) return NumberSequence.new(a, z) end
local function pop(size) return NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, size), NumberSequenceKeypoint.new(1, 0)}) end
local function fadeOut(start) return NumberSequence.new(start or 0, 1) end

Styles.Emitters = {
 Bubbles = {Texture = SPARKLE, Color = ColorSequence.new(rgb(255, 210, 240), rgb(210, 245, 255)), LightEmission = 0.3,
  Size = pop(0.35), Transparency = NumberSequence.new(0.35), Rate = 30, Lifetime = range(0.8, 1.4), Speed = range(0.5, 1.5),
  SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 2, 0)},
 Glitter = {Texture = SPARKLE, Color = ColorSequence.new(rgb(240, 210, 255), rgb(170, 110, 255)), LightEmission = 1,
  Size = pop(0.3), Rate = 40, Lifetime = range(0.4, 0.8), Speed = range(0.5, 2), SpreadAngle = Vector2.new(180, 180),
  RotSpeed = range(-180, 180)},
 Snow = {Texture = SPARKLE, Color = ColorSequence.new(rgb(255, 255, 255), rgb(170, 225, 255)), LightEmission = 0.8,
  Size = pop(0.3), Rate = 50, Lifetime = range(0.6, 1.2), Speed = range(0.5, 2), SpreadAngle = Vector2.new(180, 180),
  Acceleration = Vector3.new(0, -3, 0), RotSpeed = range(-90, 90)},
 Flame = {Texture = FIRE, Color = ColorSequence.new(rgb(255, 200, 80), rgb(255, 60, 15)), LightEmission = 1,
  Size = grow(0.9, 0.1), Rate = 35, Lifetime = range(0.25, 0.5), Speed = range(0.5, 1.5), SpreadAngle = Vector2.new(25, 25)},
 Embers = {Texture = SPARKLE, Color = ColorSequence.new(rgb(255, 160, 50), rgb(255, 60, 10)), LightEmission = 1,
  Size = pop(0.25), Rate = 12, Lifetime = range(1, 2), Speed = range(0.3, 1), Acceleration = Vector3.new(0, 1.5, 0),
  SpreadAngle = Vector2.new(180, 180)},
 Sparks = {Texture = SPARK, Color = ColorSequence.new(rgb(255, 250, 170), rgb(190, 140, 255)), LightEmission = 1,
  Size = pop(0.4), Rate = 45, Lifetime = range(0.15, 0.35), Speed = range(3, 6), SpreadAngle = Vector2.new(180, 180)},
 Stardust = {Texture = SPARKLE, Color = ColorSequence.new(rgb(255, 140, 225), rgb(120, 170, 255)), LightEmission = 1,
  Size = pop(0.35), Rate = 45, Lifetime = range(0.8, 1.5), Speed = range(0.2, 1), SpreadAngle = Vector2.new(180, 180),
  RotSpeed = range(-120, 120)},
 Stars = {Texture = SPARKLE, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, rgb(255, 120, 120)),
  ColorSequenceKeypoint.new(0.33, rgb(255, 240, 120)), ColorSequenceKeypoint.new(0.66, rgb(120, 220, 255)),
  ColorSequenceKeypoint.new(1, rgb(220, 140, 255))}), LightEmission = 1, Size = pop(0.5), Rate = 50,
  Lifetime = range(0.6, 1.2), Speed = range(1, 3), SpreadAngle = Vector2.new(180, 180), RotSpeed = range(-200, 200)},
 Dust = {Texture = SMOKE, Color = ColorSequence.new(rgb(225, 205, 170)), Size = grow(0.6, 2.2), Transparency = fadeOut(0.3),
  Lifetime = range(0.6, 1), Speed = range(2, 5), SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -2, 0)},
 Leaves = {Texture = SPARKLE, Color = ColorSequence.new(rgb(140, 220, 90), rgb(60, 150, 50)), LightEmission = 0.2,
  Size = pop(0.4), Lifetime = range(0.8, 1.4), Speed = range(2, 5), SpreadAngle = Vector2.new(180, 180),
  Acceleration = Vector3.new(0, -4, 0), RotSpeed = range(-200, 200)},
 FireBurst = {Texture = FIRE, Color = ColorSequence.new(rgb(255, 220, 100), rgb(255, 60, 15)), LightEmission = 1,
  Size = grow(2, 0.2), Lifetime = range(0.4, 0.8), Speed = range(6, 14), SpreadAngle = Vector2.new(180, 180)},
 -- World 2
 Sand = {Texture = SMOKE, Color = ColorSequence.new(rgb(240, 214, 150), rgb(214, 170, 100)), Size = grow(0.4, 1.4),
  Transparency = fadeOut(0.35), Rate = 20, Lifetime = range(0.5, 0.9), Speed = range(0.5, 1.5), SpreadAngle = Vector2.new(60, 60)},
 GoldGlitter = {Texture = SPARKLE, Color = ColorSequence.new(rgb(255, 240, 170), rgb(255, 190, 50)), LightEmission = 1,
  Size = pop(0.3), Rate = 35, Lifetime = range(0.5, 1), Speed = range(0.5, 2), SpreadAngle = Vector2.new(180, 180),
  RotSpeed = range(-180, 180)},
 Runes = {Texture = SPARKLE, Color = ColorSequence.new(rgb(200, 250, 255), rgb(60, 170, 255)), LightEmission = 1,
  Size = pop(0.4), Rate = 30, Lifetime = range(0.5, 1), Speed = range(0.3, 1.2), SpreadAngle = Vector2.new(180, 180),
  RotSpeed = range(-60, 60)},
 Petals = {Texture = SPARKLE, Color = ColorSequence.new(rgb(255, 210, 230), rgb(255, 140, 190)), LightEmission = 0.3,
  Size = pop(0.4), Rate = 30, Lifetime = range(0.9, 1.6), Speed = range(0.5, 2), SpreadAngle = Vector2.new(180, 180),
  Acceleration = Vector3.new(0, -1.5, 0), RotSpeed = range(-200, 200)},
 DirtPuff = {Texture = SMOKE, Color = ColorSequence.new(rgb(225, 200, 155), rgb(185, 150, 105)), Size = grow(0.4, 1.8),
  Transparency = fadeOut(0.4), Rate = 14, Lifetime = range(0.4, 0.8), Speed = range(0.5, 2), SpreadAngle = Vector2.new(40, 40),
  Acceleration = Vector3.new(0, -1, 0), RotSpeed = range(-60, 60)},
 Sprinkles = {Texture = SPARK, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, rgb(255, 230, 60)),
  ColorSequenceKeypoint.new(0.5, rgb(90, 215, 255)), ColorSequenceKeypoint.new(1, rgb(150, 255, 140))}), LightEmission = 0.6,
  Size = pop(0.25), Rate = 30, Lifetime = range(0.5, 0.9), Speed = range(1, 3), SpreadAngle = Vector2.new(180, 180),
  Acceleration = Vector3.new(0, -6, 0), RotSpeed = range(-300, 300)},
 FrostMist = {Texture = SMOKE, Color = ColorSequence.new(rgb(235, 250, 255), rgb(170, 220, 255)), LightEmission = 0.3,
  Size = grow(0.6, 2.4), Transparency = fadeOut(0.5), Rate = 20, Lifetime = range(0.5, 0.9), Speed = range(0.3, 1),
  SpreadAngle = Vector2.new(30, 30), RotSpeed = range(-40, 40)},
 Spores = {Texture = SPARKLE, Color = ColorSequence.new(rgb(240, 255, 170), rgb(150, 220, 90)), LightEmission = 0.8,
  Size = pop(0.3), Rate = 25, Lifetime = range(0.8, 1.6), Speed = range(0.2, 0.8), SpreadAngle = Vector2.new(180, 180),
  Acceleration = Vector3.new(0, 0.8, 0)},
 Steam = {Texture = SMOKE, Color = ColorSequence.new(rgb(255, 255, 255), rgb(220, 230, 240)), Size = grow(0.3, 1.6),
  Transparency = fadeOut(0.35), Rate = 18, Lifetime = range(0.4, 0.7), Speed = range(1, 2.5), SpreadAngle = Vector2.new(25, 25),
  Acceleration = Vector3.new(0, 2, 0), RotSpeed = range(-80, 80)},
 TimeDust = {Texture = SPARKLE, Color = ColorSequence.new(rgb(140, 245, 255), rgb(180, 120, 255)), LightEmission = 1,
  Size = pop(0.4), Rate = 45, Lifetime = range(0.7, 1.3), Speed = range(0.3, 1.2), SpreadAngle = Vector2.new(180, 180),
  RotSpeed = range(-150, 150)},
 -- World 3
 SunGlints = {Texture = SPARKLE, Color = ColorSequence.new(rgb(255, 250, 220), rgb(255, 196, 70)), LightEmission = 1,
  Size = pop(0.35), Rate = 35, Lifetime = range(0.4, 0.8), Speed = range(0.8, 2.4), SpreadAngle = Vector2.new(180, 180),
  RotSpeed = range(-120, 120)},
 HoloSparks = {Texture = SPARK, Color = ColorSequence.new(rgb(210, 250, 255), rgb(60, 170, 255)), LightEmission = 1,
  Size = pop(0.3), Rate = 30, Lifetime = range(0.2, 0.45), Speed = range(1, 3), SpreadAngle = Vector2.new(180, 180)},
 PixelSparks = {Texture = SPARK, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, rgb(255, 90, 140)),
  ColorSequenceKeypoint.new(0.33, rgb(255, 210, 60)), ColorSequenceKeypoint.new(0.66, rgb(90, 160, 255)),
  ColorSequenceKeypoint.new(1, rgb(60, 230, 160))}), LightEmission = 0.8, Size = pop(0.35), Rate = 30, Lifetime = range(0.4, 0.8),
  Speed = range(1, 3), SpreadAngle = Vector2.new(180, 180), RotSpeed = range(-90, 90)},
 MoonDust = {Texture = SMOKE, Color = ColorSequence.new(rgb(230, 232, 240), rgb(170, 174, 186)), LightEmission = 0.2,
  Size = grow(0.4, 1.8), Transparency = fadeOut(0.45), Rate = 20, Lifetime = range(1, 1.6), Speed = range(0.2, 0.8),
  SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -0.4, 0), RotSpeed = range(-30, 30)},
 RedDust = {Texture = SMOKE, Color = ColorSequence.new(rgb(240, 160, 110), rgb(176, 76, 44)), Size = grow(0.5, 2),
  Transparency = fadeOut(0.4), Rate = 22, Lifetime = range(0.6, 1), Speed = range(0.5, 1.5), SpreadAngle = Vector2.new(60, 60),
  RotSpeed = range(-60, 60)},
 VoidDust = {Texture = SPARKLE, Color = ColorSequence.new(rgb(255, 220, 190), rgb(170, 100, 255)), LightEmission = 1,
  Size = pop(0.4), Rate = 45, Lifetime = range(0.6, 1.1), Speed = range(0.4, 1.4), SpreadAngle = Vector2.new(180, 180),
  RotSpeed = range(-200, 200)},
}

-- One-shot bursts at launch or landing: Emitters presets to emit, plus optional extras.
-- Each fancier Ball's own sound while it flies, layered over the shared whoosh (BallSounds):
-- {id, volume, playbackSpeed}. Roblox-licensed Pro Sound Effects audio. Volumes are measured
-- against the whoosh so the theme colours the flight without burying the sense of speed:
-- about half the whoosh's loudness for the gentle themes, up to ~0.9x for the top tiers.
Styles.FlightSounds = {
 bubblegum_ball = {"rbxassetid://9112752570", 0.5, 1.15}, -- bubbles, small bloops (0.5x)
 crystal_ball = {"rbxassetid://9125718987", 0.13, 1.1}, -- crystal shimmer, ringing glass (0.6x)
 frost_comet = {"rbxassetid://9125718987", 0.13, 1.6}, -- the same shimmer, pitched up icy (0.6x)
 inferno_ball = {"rbxassetid://9112822944", 0.075, 1.1}, -- restrained crackling fire (0.7x)
 thunder_ball = {"rbxassetid://9114237976", 0.34, 1}, -- electric arcing, bright so kept lower (0.6x)
 galaxy_ball = {"rbxassetid://9119409838", 0.16, 0.9}, -- low soft cosmic hum (0.7x)
 dragonfire_ball = {"rbxassetid://9112825609", 0.055, 1}, -- stronger fire roar (0.9x)
 supernova_ball = {"rbxassetid://9125636853", 0.47, 1.05}, -- sizzling magic energy (0.9x)
 viking_rune_ball = {"rbxassetid://9125718987", 0.13, 0.8}, -- the shimmer, pitched down to a rune hum (0.6x)
 clockwork_ball = {"rbxassetid://9119409838", 0.15, 1.3}, -- the hum, pitched up like whirring gears (0.6x)
 chrono_orb = {"rbxassetid://9125636853", 0.45, 0.8}, -- the magic energy, slowed and deeper (0.9x)
 hologram_ball = {"rbxassetid://9114237976", 0.26, 1.35}, -- the electric arcing, pitched up to a glitchy buzz (0.6x)
 robo_core_ball = {"rbxassetid://9119409838", 0.15, 1.6}, -- the hum, pitched up to a servo whine (0.6x)
 rocket_ball = {"rbxassetid://9112825609", 0.05, 0.8}, -- the fire roar, deeper, like an engine (0.8x)
 singularity_orb = {"rbxassetid://9119409838", 0.2, 0.6}, -- the cosmic hum, slowed into a deep drone (0.9x)
}

Styles.Bursts = {
 Dust = {emit = {{"Dust", 14}}},
 Leaves = {emit = {{"Leaves", 30}}},
 Sprinkles = {emit = {{"Bubbles", 25}, {"Glitter", 20}}},
 Gems = {emit = {{"Glitter", 45}}, flash = rgb(200, 130, 255)},
 Frost = {emit = {{"Snow", 60}}, ring = rgb(190, 235, 255), flash = rgb(170, 225, 255)},
 Fire = {emit = {{"FireBurst", 30}, {"Embers", 30}}, flash = rgb(255, 130, 40)},
 Zap = {emit = {{"Sparks", 40}}, bolts = rgb(255, 245, 140), flash = rgb(255, 240, 150)},
 Stardust = {emit = {{"Stardust", 60}}, flash = rgb(170, 130, 255)},
 Shockwave = {ring = rgb(255, 240, 200), flash = rgb(255, 240, 200)},
 Supernova = {emit = {{"Stars", 80}}, ring = rgb(255, 240, 200), flash = rgb(255, 245, 210)},
 Rockslide = {emit = {{"Dust", 24}}, ring = rgb(170, 160, 150)},
 Sandstorm = {emit = {{"Sand", 40}, {"GoldGlitter", 20}}, flash = rgb(255, 214, 120)},
 Laurel = {emit = {{"GoldGlitter", 45}}, ring = rgb(255, 220, 120), flash = rgb(255, 240, 190)},
 Petals = {emit = {{"Petals", 60}}, flash = rgb(255, 180, 210)},
 Clang = {emit = {{"Sparks", 45}}, ring = rgb(230, 236, 255), flash = rgb(255, 255, 255)},
 Sheriff = {emit = {{"Dust", 16}, {"GoldGlitter", 35}}, ring = rgb(255, 210, 90)},
 TimeWarp = {emit = {{"TimeDust", 70}}, ring = rgb(120, 240, 255), flash = rgb(170, 240, 255)},
 -- World 3
 Solar = {emit = {{"SunGlints", 60}}, ring = rgb(255, 214, 110), flash = rgb(255, 230, 160)},
 HoverRing = {ring = rgb(110, 225, 255), flash = rgb(170, 235, 255)},
 Glitch = {emit = {{"HoloSparks", 50}}, ring = rgb(120, 230, 255), flash = rgb(150, 235, 255)},
 Pixels = {emit = {{"PixelSparks", 60}}, flash = rgb(170, 255, 210)},
 MoonDust = {emit = {{"MoonDust", 30}}, ring = rgb(210, 220, 240)},
 RedDust = {emit = {{"RedDust", 36}}, ring = rgb(230, 140, 90)},
 Singularity = {emit = {{"VoidDust", 70}}, ring = rgb(190, 130, 255), flash = rgb(210, 170, 255), bolts = rgb(220, 190, 255)},
}

function Styles.Get(itemId)
 return Styles.Balls[itemId]
end

-- The Part name of an imported mesh ("crystal_ball__Core" -> "Core").
function Styles.PartName(name)
 return name:match("__(.+)$") or name
end

-- Colours a model's parts by name from a style's parts table (shared with BatStyles).
function Styles.ApplyParts(model, style)
 if not style then return model end
 for _, part in model:GetDescendants() do
  if part:IsA("BasePart") then
   local partLook = style.parts and style.parts[Styles.PartName(part.Name)]
   if partLook then
    part.Color, part.Material, part.Transparency = partLook.color, partLook.material, partLook.transparency
    if part:IsA("MeshPart") then part.TextureID = "" end
   end
   part.CastShadow = false
  end
 end
 return model
end

function Styles.ApplyLook(model, itemId)
 return Styles.ApplyParts(model, Styles.Balls[itemId])
end

-- A ParticleEmitter from a preset (scaled by sizeScale, rate optionally overridden).
function Styles.MakeEmitter(presetName, parent, sizeScale, rate)
 local preset = Styles.Emitters[presetName]
 if not preset then return nil end
 local emitter = Instance.new("ParticleEmitter")
 emitter.Name = presetName
 for property, value in preset do
  if property == "Size" and sizeScale and sizeScale ~= 1 then
   local points = {}
   for _, keypoint in value.Keypoints do
    table.insert(points, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * sizeScale))
   end
   value = NumberSequence.new(points)
  end
  emitter[property] = value
 end
 if rate then emitter.Rate = rate end
 emitter.Parent = parent
 return emitter
end

return Styles
