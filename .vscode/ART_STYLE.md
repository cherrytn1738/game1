# Art Style

How each World looks, so new visual work (props, cages, hubs, runway sections, effects, UI art)
fits in. It describes what is already in the game: when the game and this file disagree, check
the game and fix whichever is wrong. Lighting values live in `src/replicated/WorldLightingConfig.luau`
(see GAME_DESIGN.md, "Sky"); colours below come from `HubDecor`, `RunwayDecor`, `WorldConfig`
and the Blender generators in `tools/blender/`.

## Shared rules

- **Stylized, toy-like, readable.** Chunky simple shapes, bold saturated colours, big
  silhouettes that read from the batting camera and on a phone. No realism, no photo textures.
- **Shapes:** Blender low-poly meshes (1 Blender unit = 1 stud) with smooth or lightly bevelled
  edges, soft rounded forms for nature (bulbous trees, mushrooms, bushes) and clean hard edges
  for built things. Exaggerated proportions: oversized props, thick posts, fat rims.
- **Materials:** mostly SmoothPlastic and vertex/material colour, with a few Roblox materials
  for character (Grass, Wood / WoodPlanks, Slate, Sandstone, Concrete, Metal, Glass, Snow,
  Basalt). **Neon** is for things that glow (lamps, seams, portals, holograms, energy), never for
  large plain surfaces: bloom turns big Neon areas into white blobs.
- **Glow budget:** a World's accent colour carries its glow. Keep glowing parts small and
  thin (strips, rims, cores). At night (World 3) every glow stands out more, so bloom stays soft.
- **No fast flashing:** glowing parts pulse at most about once a second (`Pulse` / `pulse`
  around 1). Faster bright pulses read as harsh flicker and are hard on light-sensitive players;
  flames are the exception (small, warm, not Neon-bright).
- **The ball and its flight come first.** Nothing beside the runway should match the ball's
  white or its trail colours closely enough to hide it; nothing should hang over the runway's
  flight path. The end portal must stay visible from far down the runway, so keep haze light.
- **Sun out of the shot:** any sun stays behind the batter (+Z), never in the camera's view down
  the runway (-Z).
- **Cages and props get more elaborate down each row**, with the paid ground as the showpiece.
- **UI** has its own style (UICommon; AGENTS.md "UI"): the blue Inventory look, and the Shop's
  colour cards. In-world signs use the same rounded bold font with dark outlines.

## World 1 - Home Field

- **Mood:** a bright, cheerful afternoon at a sunny ballpark in a fantasy meadow.
- **Lighting:** clear midday (clock 14.5, Brightness 2.8), cool blue ambient, a pale sky-blue
  distance fade (no Haze: it darkens this horizon), moderate bloom (0.5 / 40 / 2.4), a vivid grade
  with a faint lavender tint. No clouds.
- **Palette:** striped grass greens (96, 172, 80) / (82, 154, 68), infield dirt (178, 126, 82),
  chalk white, padded wall green (30, 88, 54), red and navy seats, red / white / blue bunting.
- **Accent:** foul-pole and wall-cap yellow (255, 214, 40); the runway's mint-and-white checkers.
- **Materials:** Grass and SmoothPlastic, aluminium and steel stands (Metal), concrete pads.
- **Shapes:** classic ballpark pieces (bleachers, light towers, scoreboard, foul poles) plus
  round bulbous cartoon trees, spotted mushrooms and rolling hills. The runway's ten sections
  each take one fantasy theme (meadow, snow, crystal, desert, candy, jungle, lava, neon, sky,
  cosmic) in the same chunky style.

## World 2 - Time Travel

- **Mood:** a warm golden-hour trip through history, held together by clockwork.
- **Lighting:** golden hour (clock 16.4, latitude 45): a low sun behind and left of the batter,
  warm amber haze and glare, peach clouds, gentle bloom (0.5 / 28 / 1.6), a warm grade.
- **Palette:** lavender and violet checker tiles (122, 106, 186) / (104, 88, 166), cream walkways
  (236, 204, 136), brass (226, 176, 80) and dark brass, ink purple, plus each era's own stone:
  sandstone, marble, grey stone, red lacquer.
- **Accent:** chrono cyan (90, 230, 255), the glow of time energy, on terrace edges, lamps and
  crystals; brass gears for detail.
- **Materials:** Slate walls, Sandstone and Marble monuments, Metal brass, WoodPlanks; Neon only
  for chrono-cyan strips and lamps.
- **Shapes:** gears, clock faces, pillars, pyramids, torii gates and castle towers: each era
  reduced to its most recognisable silhouette, in toy proportions. Each runway section is one
  era, in the order of World 2's balls.

## World 3 - Future World

- **Mood:** a city of tomorrow at night, lit by its own neon, heading out into space.
- **Lighting:** night (clock 0): a dark starry sky with a big moon, a bright violet-blue ambient
  so everything stays readable, a soft blue haze, soft wide bloom (0.55 / 56 / 1.7: stronger,
  tighter bloom made the hundreds of thin Neon strips shimmer and glare), a cool grade. No sun
  rays. The dark night is what makes the Neon stand out.
- **Palette:** white composite (240, 243, 248) and pale plaza tiles, gunmetal (64, 72, 92), dark
  navy walkways (38, 48, 80), sky glass (120, 170, 225).
- **Accent:** hologram cyan (90, 224, 255) / (120, 236, 255), with hologram pink (255, 110, 214)
  and beacon red (255, 72, 84) as secondaries.
- **Materials:** SmoothPlastic white panels, Metal, Glass, Concrete; Neon for seams, skyscraper
  bands, holograms and lamp cores (thin bands: bloom is strong here).
- **Shapes:** clean rounded-rectangle forms, fins, domes, rings and spires; glass skyscrapers
  with glowing bands; rockets, turbines and biodomes. The runway goes from suburbs and city
  (sections 1-5) to orbit, the Moon, Mars and a black hole (6-10).

## World 4 - Tiny Town

- **Mood:** shrunk to bug size in a house in the evening: warm, cozy and lamp-lit.
- **Lighting:** a bedroom in the evening (clock 17.65): a very low amber sun from the left, a
  dusk-blue sky over a warm horizon, a strong peach ambient standing in for the lamp, warm haze
  with glare, gentle bloom (0.7 / 36 / 1.7) on toys and the keyhole's glow, a warm grade that
  keeps the toys' primaries saturated. No clouds.
- **Palette:** honey floorboards (204, 156, 104) / (188, 140, 92) with dark seams, pale wood
  paths, white baseboard (248, 246, 240), brass and silver, plus the toy primaries: red
  (232, 60, 54), yellow (255, 206, 44), blue (52, 122, 234), green (66, 186, 90).
- **Accent:** warm brass gold (230, 180, 78) and the keyhole portal's warm glow.
- **Materials:** Wood / WoodPlanks floors and trim, SmoothPlastic toys (plastic should look like
  plastic: smooth, bright, slightly glossy), Fabric for blankets and pillows; Neon only for the
  keyhole, night-lights and lamps.
- **Shapes:** everyday objects made giant: bottle caps, matchsticks, thread spools, alphabet
  blocks, rubber ducks, toy trains, pencils, books, pillows. Rounded, slightly soft edges, as if
  a child could hold them. The runway runs from the backyard (sections 1-5) through the house
  (6-10), in the order of World 4's balls.
