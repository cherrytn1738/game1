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
| 2 | Pharaoh's Tomb | PharaohsTombCage | | |
| 3 | Gladiator Colosseum | GladiatorColosseumCage | | |
| 4 | Samurai Dojo | SamuraiDojoCage | | |
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

## Things that didn't work or were skipped
(none yet)
