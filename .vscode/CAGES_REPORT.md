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
| 1 | Caveman Camp | CavemanCampCage | | |
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

## Things that didn't work or were skipped
(none yet)
