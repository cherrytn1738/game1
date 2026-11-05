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
| 5 | Time Machine Lab | TimeMachineLabCage | | |
| 6 | Sandbox Diamond | SandboxDiamondCage | | |
| 7 | Pinball Cage | PinballCage | | |
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

## Things that didn't work or were skipped
(none yet)
