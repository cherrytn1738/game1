# Custom cages report (branch `custom-cages`)

This report covers rebuilding World 2's five and World 4's five Training Ground cages as fully
custom Blender models. It is updated after each cage, so it stays current even if the session ends
early.

## Step 1: merge
- I merged `world4-art` into `main` as a fast-forward with no conflicts, and pushed it. `main` is at
  `d5c1452`.
- The cage work is on a new branch, `custom-cages`, made from `main`. Commits don't go straight onto
  `main`.

## Status
| # | Cage | Template | Commit | Notes |
|---|---|---|---|---|
| 1 | Caveman Camp | CavemanCampCage | `59f14ee` | 33 meshes, about 96K triangles |
| 2 | Pharaoh's Tomb | PharaohsTombCage | `4185b2b` | 40 meshes, about 145K triangles |
| 3 | Gladiator Colosseum | GladiatorColosseumCage | `8c6130f` | 44 meshes, about 107K triangles |
| 4 | Samurai Dojo | SamuraiDojoCage | `23a06cf` | 53 meshes, about 98K triangles |
| 5 | Time Machine Lab | TimeMachineLabCage | `9ac7256` | 58 meshes, about 91K triangles, 25 moving parts |
| 6 | Sandbox Diamond | SandboxDiamondCage | `0a0d5d6` | 42 meshes, about 50K triangles |
| 7 | Pinball Cage | PinballCage | `aa2d9d9` | 46 meshes, about 40K triangles |
| 8 | Cereal Bowl Stadium | CerealBowlCage | | |
| 9 | Toy Soldier Fort | ToySoldierCage | | |
| 10 | Snow Globe | SnowGlobeCage | | |

## Decisions I made on my own
- **Branch:** I made the cage commits on a new branch, `custom-cages`, not on `main`. It will be
  pushed at the end and is not merged.
- **Shared builders:** small builders the custom cages share (rounded profiles, straight members,
  plates, rings, gears, and the final step that names and colours every mesh) were added to
  `tools/blender/cage_helpers.py`. Without them, each script would copy them, as the World 3 scripts
  do. The scripts that already exist redefine any name they need, so they are unaffected.

### Every cage
- **Names:** each cage's meshes start with a short prefix (Cave, Tomb, Arena, Dojo, Chrono, Sand,
  Pin, Bowl, Fort, Globe), and its home plate is `<Prefix>Plate`. `group_item_imports.luau` checks
  that plate against the standard cage's.
- **The ball:** each pitcher holds a real ball mesh at PITCH, like the World 3 robot's.
- **Motion:** the client can only spin, bob, sway or pulse a part (TrainingStadiumClient), so a
  pitcher's "launch" is shown in its resting pose. Each cage's moving pieces use those four.
- **Templates:** World 2's grounds now name their new templates in `TrainingConfig`. That is
  presentation only, and their era colours stay, so the standard-cage fallback looks as it did. Until
  a cage is imported, Studio's Output shows "RunwayAssets.<Template> is missing; using the standard
  cage" for that ground, as World 4's did.

### Caveman Camp
- **Arches:** the tusk arches alternate with rib-bone arches, every other hoop. Both curl in sharply
  and cross in a point, lashed with rope, with a log pole in the crotch along the ridge.
- **Walls:** the hides are laced to the arches on the walls, and two are draped over the roof. The
  end walls are rope net.
- **Catapult:** a log mangonel with stone wheels, shown with its arm up and the ball in the stone cup.
- **Campfire:** it is outside the right wall, with a spit roast that turns (it spins about the spit).
- **Mammoth:** it lies along the left wall, head toward the door, breathing (a slow bob), and its ears
  sway.
- **Paintings:** two painted standing stones stand inside on the left and a third outside the front.
  The paintings show mammoths, bison, hunters, a hand and a sun.
- **Extras:** skull totems at the back corners, bone torches at the door, a hide drying rack, ferns
  and boulders.
- **New emitter:** `CampSmoke` (grey smoke), in `TrainingCageStyles.Emitters`.

### Pharaoh's Tomb
- **Pillars:** square sandstone pillars, so the hieroglyphs have flat faces. Each pillar has a painted
  hieroglyph column on its inner and outer face and a lotus capital.
- **Walls:** sandstone block walls with a coloured frieze, linen net above, and a painted gorge cornice
  all round.
- **Roof:** a pyramid over the whole hall, framed in gold, netted in linen, with a gold capstone.
- **Door:** a pylon gateway, two sloping towers with reliefs, and a winged sun above the entrance sign.
- **Sarcophagus:** it stands upright with its lid swung open toward the right, so the lid stays out of
  the ball's path. The batter sees the inside of the lid, painted as a starry sky. The mummy inside
  holds the ball out at PITCH in both hands, and its eyes glow.
- **Screen:** a gold scarab with lapis wing ribs, pushing a turning sun disc.
- **Floor:** limestone tiles laid over gold, so every joint is a gold line, with a lapis lane and gold
  ankhs. The tiles leave out the batter's boxes, so the chalk still shows.
- **Inside:** four torches, two swinging incense burners, chests, coin piles, canopic jars, vases
  and a black cat statue.
- **Outside:** a sphinx along the left wall and four obelisks at the corners.
- **New emitters:** `Incense` and `GoldDust`.

### Gladiator Colosseum
- **Plan:** the cage is an oval amphitheatre round the batting rectangle, a superellipse with power 4.
  The first try, with power 6, still read as a rectangle.
- **Arcade:** 32 bays in two tiers, with Tuscan half-columns below and Ionic above. The lower arches
  have bronze grilles, except the gate arch at the door. The upper arches have balustrades, with
  spectators leaning over them round the machine end and the sides.
- **Roof:** a velarium of alternating red and cream canvas sails, stretched from masts on the attic to
  a ring over the middle. The middle stays open.
- **Walls:** banners hang on every third bay and shields on every other bay. They are left off the
  wall behind the batter, where the camera is.
- **Ballista:** a torsion ballista with its arms drawn and the ball at the front of the stock.
- **Screen:** a round bronze shield with a rim of rivets, a laurel wreath and lightning bolts.
- **Chariot:** there is no room between the oval and the side limit, so the chariot stands on the arena
  sand beside the cage. It is parked, so its wheels don't turn.
- **Lions:** two bronze lions on plinths outside the gate, facing each other across it.
- **Crowd stands:** they stand outside the machine end, with an emperor's box under a red awning.
  They are behind the arena wall, so they are mostly seen from outside; the spectators in the upper
  arches are the crowd seen from inside.
- **Motion:** the crowd's four groups bob a quarter beat apart (a wave), and the brazier flames pulse.

### Samurai Dojo
- **Frame:** every hoop is a vermilion torii: black-footed pillars, a tie beam, a central strut with a
  gold plaque, and an upswept lintel.
- **Walls:** shoji between the torii, with a black frame, a lattice on both faces, paper, and a slatted
  transom above.
- **Doorway:** a split indigo curtain hangs in it, and the opened sliding doors are pushed aside behind
  the wall.
- **Roof:** a curved hip-and-gable pagoda roof whose corners sweep up, with tile ridges, hips, white
  rafter ends and golden fish (shachi) on the ridge.
- **Floor:** a plank floor, with tatami along both walls and a black border round the batter's ground.
  The batter's boxes are left open, so the chalk shows.
- **Launcher:** a bamboo spring arm bent over a lashed cross pole, with its cut-bamboo cup holding the
  ball at PITCH.
- **Screen:** a six-fold gold screen. The middle panel holds the window, a crane flies across the left
  leaves, and a red sun and a pine bough are on the right.
- **Inside:** six red paper lanterns hang from the tie beams and sway out of step, each with a warm
  light. There is also a katana stand, bokken, a suit of armour, a taiko drum, a bonsai and two
  hanging scrolls. The brush strokes on the scrolls are abstract, not real writing.
- **Outside:** a cherry tree at the front-right corner dropping petals (a new `Petals` emitter, also
  falling lightly inside the hall). There are also stone lanterns, stepping stones from the door, two
  bamboo groves, and a raked gravel garden with three mossy rocks.
- **Koi pond:** it is along the left wall, with lily pads and four koi that circle it. A deer-scarer
  rocks at its end.

### Time Machine Lab (World 2's showpiece)
- **Plan:** an oval rotunda (superellipse, power 4) of brass and glass, under a glass dome with brass
  ribs. A gear crown turns round the oculus lantern.
- **Wall gears:** a train of three meshing gears on each side wall. Each turns at a speed set by its
  tooth count, opposite to its neighbour.
- **Armillary:** three toothed rings turn on their own axes round a glowing core over the middle. It
  floats; there is no rod, so the rings never pass through anything.
- **Clock-face floor:** about 19 studs across, centred at y 13, so it stays clear of the batter's
  boxes. It has Roman numerals, minute ticks and a sunburst.
- **Clock hands:** each hand is symmetric (a tip at one end, a counterweight ring of the same length at
  the other), so it can spin about its own middle. `TrainingStadium` turns a part about its
  bounding-box centre.
- **Time portal:**
  - It is centred on the ball and made large enough to rise over the screen; its lower part sinks into
    the floor.
  - The swirl, its core and the toothed ring all turn about the ball.
  - At first the portal sat entirely behind the screen, so I enlarged it and lowered the screen.
- **Screen:** riveted brass, with a bolted porthole flange, two pressure gauges, a nameplate, and
  copper pipes with valve wheels.
- **Lab:** tesla coils with sparking arcs, copper pipes, a pressure tank (with steam), a control
  console, and a gear and clock over the door.
- **Relics:**
  - **Turning and drifting:** a caveman's club, a pharaoh's mask, a Roman helmet, a samurai helmet,
    a dinosaur skull and a rocket.
  - **Drifting only:** three pocket watches and an hourglass. Each of these is several meshes, and the
    pieces must move together.
- **New emitter:** `ChronoMotes`.

### World 4, all five
- **Names and effects:** the template names are unchanged (SandboxDiamondCage, PinballCage,
  CerealBowlCage, ToySoldierCage, SnowGlobeCage). The Snow Globe keeps its snow swirl practice effect.
- **Legacy styles:** your place still holds the previous World 4 models, built on the standard cage.
  Their mesh names stay in `TrainingCageStyles` as legacy entries next to the new ones, so the old
  models stay coloured until the new ones are imported over them. Remove those entries after the
  import; I'll do it when you say the models are in.

### Sandbox Diamond
- **Frame:** the sandbox is a hexagon round the cage, so it doesn't read as a rectangle. Its wall is
  two boards high, with a single low board as a step at the door. Twelve posts of doubled boards carry
  board beams.
- **Walls and roof:** a blue rope play net between the posts, four triangular shade sails at
  alternating corner heights (yellow, red, blue, green) for the roof, and bunting along the beams.
- **Floor:** sand inside the hexagon, rake lines down the pitch lane and round the batter's ground,
  and sand heaps along the walls.
- **Pail:** a yellow pail tipped on its side on a sand heap, its mouth to the batter. The ball rests on
  its lower lip at PITCH, and sand spills out.
- **Screen:** a round green plastic sand sifter on edge, with a square mesh and a ring round the window.
- **Bat rack:** four toy shovels standing in a blue crate by the left wall.
- **Toys:** three sandcastles. The big one outside the front has a pinwheel that turns. There are
  also starfish moulds, shells, a toy dump truck, a rake and spare pails.
- **Beach ball:** it bobs and turns. Its opposite gores share a mesh, so each mesh is centred on the
  ball.

### Pinball Cage
- **Cabinet:** a painted purple cabinet with a rounded top arch past the machine end, so its plan
  isn't a rectangle. Its walls rise with the playfield's tilt to a sloping glass top (the roof), with
  chrome side rails, a lockdown bar, chrome legs and lightning-and-star side art.
- **Head:** the backbox head stands up at the top arch end, with art (a ringed planet, a rocket and
  stars), a marquee and a border of chase lights. It makes the silhouette read as pinball from the hub.
- **Door:** the entrance is the coin door: a chrome frame, with a coin panel beside it whose slots glow.
- **Playfield:** glowing inserts pulse at four rates, and there are painted arrows and a starburst
  behind the batter's ground. Rollover lanes sit under the top arch, and an apron lies at the batter's
  end.
- **Toys:** two pairs of flippers with red rubbers along the sides, slingshots with lane guides, five
  pop bumpers whose caps glow out of step, two spinners that turn, a six-point star turntable that
  turns, a bank of drop targets and a clear wire ramp.
- **Lights:** chase lights along the top rails blink in turn (two meshes, half a cycle apart), and
  light strips glow inside the walls.
- **Plunger:** the spring plunger sits in a raised shooter lane, with the ball against its tip at PITCH.
- **Screen:** the scoreboard backglass, with a seven-segment score ("1450980"), the ball count and
  credits, speaker grilles and art on dark glass.

### Cereal Bowl Stadium
- **Bowl:** the wall is a flaring oval bowl (superellipse, power 3.5), blue outside with a white
  stripe band and dots, white inside, under a rolled white rim.
- **Door:** a chip broken out of the bowl, with jagged shards along its edges.
- **Roof:** six bendy drinking straws, striped red or blue, each with an accordion bend near one end.
  They arch rim to rim under a sheet of cling film (glass, mostly see-through) that sags between them.
- **Milk:** milk fills the bowl round the cage. Cereal loops in three colours bob on it out of step,
  with berries, banana slices, flakes and ripple rings. The loops spilled outside are a separate,
  still mesh, so they don't bob on dry ground.
- **Spoon catapult:** a spoon balanced on a sugar-cube fulcrum. Its bowl holds the ball at PITCH, and a
  strawberry weighs down its handle.
- **Screen:** an opened cereal box with its flaps folded out and the window tunnelled through it. The
  art is a smiling sun mascot, a bowl of loops, a starburst badge and a milk-splash band, with no
  text. Its prize, a spinning top, turns on top.
- **Outside:** a gable-top milk carton with cow spots, a resting spoon, spilled cereal and sugar cubes.

## Things that didn't work or were skipped
(none yet)
