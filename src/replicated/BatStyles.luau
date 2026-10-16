-- Looks and swing effects for each Bat (cosmetic only: nothing here changes Power, launch,
-- distance or rewards). Models come from tools/blender/bats.py; each mesh is named
-- "<item id>__<Part>" and is coloured here by its Part name. Particle presets and bursts are
-- shared with BallStyles.
--   parts: Part -> {color, material, transparency}
--   light: {color, brightness, range} glow on the display and in hand
--   swing: a trail behind the barrel while it moves fast (colors, lifetime, plus rainbow /
--     hueShift / flicker like ball trails)
--   contact: a BallStyles burst where the ball leaves the tee on a real hit
--   idle: a BallStyles emitter preset shown around the bat on its display pedestal
local BallStyles = require(script.Parent:WaitForChild("BallStyles"))
local M = Enum.Material
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function look(color, material, transparency)
 return {color = color, material = material or M.SmoothPlastic, transparency = transparency or 0}
end

local Styles = {}

-- Trail span along the bat (Handle space, studs up the barrel) and the barrel tip.
Styles.TrailBase = 1.6
Styles.TrailTip = 3.4

Styles.Bats = {
 wood_bat = {
  parts = {Barrel = look(rgb(196, 146, 92), M.Wood), Grip = look(rgb(22, 22, 24), M.Fabric),
   Knob = look(rgb(186, 136, 84), M.Wood), Logo = look(rgb(96, 60, 32), M.Wood)},
 },
 metal_bat = {
  parts = {Barrel = look(rgb(200, 206, 218), M.Metal), Grip = look(rgb(40, 95, 220), M.Fabric),
   Knob = look(rgb(28, 28, 32)), EndCap = look(rgb(215, 40, 45)), Stripes = look(rgb(40, 95, 220))},
  swing = {colors = {rgb(255, 255, 255), rgb(200, 215, 235)}, lifetime = 0.12},
 },
 jungle_bat = {
  parts = {Barrel = look(rgb(200, 180, 100), M.Wood), Grip = look(rgb(120, 86, 48), M.Fabric),
   Knob = look(rgb(120, 86, 48), M.Wood), Nodes = look(rgb(150, 130, 60), M.Wood),
   Vines = look(rgb(60, 130, 45), M.Grass), Leaves = look(rgb(90, 185, 60), M.Grass)},
  swing = {colors = {rgb(170, 235, 120), rgb(70, 160, 60)}, lifetime = 0.15},
  contact = "Leaves",
  idle = "Leaves",
 },
 amethyst_bat = {
  parts = {Barrel = look(rgb(160, 92, 235), M.Glass, 0.25), Grip = look(rgb(205, 210, 220), M.Metal),
   Knob = look(rgb(205, 210, 220), M.Metal), Core = look(rgb(215, 150, 255), M.Neon),
   Points = look(rgb(205, 160, 255), M.Glass, 0.15)},
  light = {rgb(200, 130, 255), 1.5, 7},
  swing = {colors = {rgb(230, 180, 255), rgb(140, 80, 230)}, lifetime = 0.16},
  contact = "Gems",
  idle = "Glitter",
 },
 candy_cane_bat = {
  parts = {Barrel = look(rgb(250, 250, 250)), Grip = look(rgb(215, 35, 45), M.Fabric),
   Knob = look(rgb(215, 35, 45)), Stripes = look(rgb(215, 35, 45)), Peppermint = look(rgb(250, 250, 250))},
  swing = {colors = {rgb(255, 120, 140), rgb(255, 255, 255)}, lifetime = 0.16},
  contact = "Sprinkles",
  idle = "Bubbles",
 },
 frostbite_bat = {
  parts = {Barrel = look(rgb(140, 210, 255), M.Glass, 0.3), Grip = look(rgb(225, 242, 255), M.Fabric),
   Knob = look(rgb(200, 230, 255), M.Ice), Core = look(rgb(225, 245, 255), M.Neon),
   Icicles = look(rgb(220, 240, 255), M.Ice)},
  light = {rgb(160, 220, 255), 1.8, 8},
  swing = {colors = {rgb(235, 250, 255), rgb(90, 180, 255)}, lifetime = 0.2},
  contact = "Frost",
  idle = "Snow",
 },
 magma_bat = {
  parts = {Barrel = look(rgb(34, 28, 28), M.Basalt), Grip = look(rgb(52, 40, 34), M.Fabric),
   Knob = look(rgb(34, 28, 28), M.Basalt), Lava = look(rgb(255, 115, 25), M.Neon)},
  light = {rgb(255, 120, 40), 2, 8},
  swing = {colors = {rgb(255, 210, 90), rgb(255, 60, 15)}, lifetime = 0.2},
  contact = "Fire",
  idle = "Embers",
 },
 lightning_bat = {
  parts = {Barrel = look(rgb(92, 42, 165)), Grip = look(rgb(20, 20, 26), M.Fabric), Knob = look(rgb(20, 20, 26)),
   Bolts = look(rgb(255, 235, 70), M.Neon), Coils = look(rgb(190, 195, 210), M.Metal)},
  light = {rgb(255, 235, 120), 2, 8},
  swing = {colors = {rgb(255, 250, 180), rgb(170, 110, 255)}, lifetime = 0.18, flicker = true},
  contact = "Zap",
  idle = "Sparks",
 },
 dragon_bone_bat = {
  parts = {Barrel = look(rgb(232, 222, 192), M.Limestone), Grip = look(rgb(120, 20, 20), M.Leather),
   Knob = look(rgb(220, 208, 175), M.Limestone), Spikes = look(rgb(36, 28, 28)), Eye = look(rgb(255, 175, 35), M.Neon)},
  light = {rgb(255, 130, 40), 2, 8},
  swing = {colors = {rgb(255, 200, 70), rgb(220, 30, 10)}, lifetime = 0.22},
  contact = "Fire",
  idle = "Embers",
 },
 celestial_bat = {
  parts = {Barrel = look(rgb(18, 12, 52)), Grip = look(rgb(240, 190, 70), M.Fabric), Knob = look(rgb(240, 190, 70), M.Metal),
   SwirlPink = look(rgb(255, 100, 205), M.Neon), SwirlBlue = look(rgb(90, 160, 255), M.Neon),
   Rings = look(rgb(240, 190, 70), M.Metal), Stars = look(rgb(255, 255, 255), M.Neon), Star = look(rgb(255, 225, 120), M.Neon)},
  light = {rgb(255, 230, 170), 2.5, 9},
  swing = {lifetime = 0.25, rainbow = true},
  contact = "Supernova",
  idle = "Stars",
 },
}

function Styles.Get(itemId)
 return Styles.Bats[itemId]
end

function Styles.ApplyLook(model, itemId)
 return BallStyles.ApplyParts(model, Styles.Bats[itemId])
end

return Styles
