# World 4 overnight report (branch `world4-art`)

Work on Phases 2-6 of `.vscode/WORLD4_DESIGN.md`, done without review. Everything is on the
`world4-art` branch, which starts from `main` at `bd4b478`. Nothing was merged into `main`.
This file is updated after every phase.

## Status by phase

| Phase | What | Commit | State |
|---|---|---|---|
| 2 | Runway props, sections 1-5 | (this commit) | Done; the models need importing by hand |

## What was finished

### Phase 2: runway props, sections 1-5
- **Blender script:** `tools/blender/runway_world4_home.py` builds 25 templates. It is exported
  to `assets/models/RunwayWorld4Home.fbx`, with the manifest `RunwayWorld4Home.json`.
  - **Giant Backyard:** GrassBlade, HoseReel, Sprinkler, Ladybug; filler Pebble; backdrop
    GiantFence.
  - **Picnic Blanket:** Sandwich, AntLine, PicnicBasket; filler Crumbs; backdrop BlanketFolds.
  - **Kitchen Counter:** CuttingBoard, Toaster, Faucet; filler CerealPiece; backdrop CerealHills.
  - **Block Town:** AlphabetBlock, TrainTrack, BrickTower; filler ToyBrick; backdrop BrickTower
    at backdrop scale.
  - **Board Game Boulevard:** GiantDie, PlayingCard, GamePiece; filler ChessPawn; backdrop
    BoardGameBox.
  - It uses World 3's conventions: one mesh per colour role, every mesh under 20 units, fronts
    facing -Y, and World 3's helpers (it runs `runway_world3_city.py`'s helper half).
- **`RunwayDecor`:**
  - Tiny Town colours plus the 21 prop and filler entries and 5 backdrop entries.
  - A `fallback` field: while a kind's model is missing, the Phase 1 placeholder it replaced
    stands in, so World 4 looks exactly as before until the import. `PlaceMesh` uses the same
    fallback.
  - A new floor flag, `floorChecker`: big 20-stud checks for the picnic blanket and the
    chessboard.
- **`WorldConfig`:** World 4's sections 1-5 now use the new kinds, and the Picnic Blanket and Board
  Game Boulevard use `floorChecker`.
- **Import tool:** `tools/studio/group_runway_imports.luau` is a command-bar script that sorts an
  Import 3D result into `ServerStorage.RunwayAssets` templates, the same way World 3's were grouped.
- **Checks:**
  - **Placeholders:** in a playtest, World 4's runway builds with its placeholders and 280 checker
    tiles, and the Output is clean.
  - **New meshes:** with stand-in templates (plain parts carrying the manifest names), all 25 new
    kinds placed along World 4's runway (878 parts) and every part got its tint. The stand-ins
    were removed afterwards.

## Decisions I made on my own
- **Hose:** the garden hose is a hose on a reel cart. A coil lying flat would barely show at
  runway scale.
- **Filler:** the Giant Backyard uses `pebble` plus World 1's `bush` as fillers.
- **Grass:** `grassBlade` is listed twice in its section, so grass appears most often.
- **Block Town's backdrop:** `blockSkyline` reuses the BrickTower model, scaled up, instead of a
  separate mesh. World 3 does the same with its wind farm.
- **Game piece:** it is a wooden player token, a generic board-game shape.
- **Placeholders until the import:** each new kind has a `fallback` (its Phase 1 placeholder) so
  the runway never loses its props. Otherwise, a missing mesh-only prop is skipped.
- **Checker floor:** `floorChecker` is the one new floor flag the design doc allows. It uses
  20-stud checks in the section's accent colour.
- **Tests:** UIModal can't run normally while Studio is in the background (see the next
  section), so it was run with a stand-in TweenService instead.

## Things that didn't work or were skipped
- **Screen captures time out**, so I couldn't look at anything in Studio. Studio isn't drawing
  frames while it is in the background, and a retry failed the same way. Every Studio check was
  done by data instead: part counts, positions, tints and Output errors. All visual checks are
  listed below for you.
- **Importing models into Studio** needs you. The Studio tools I have can't run Import 3D.
- **UIModal test:** Studio in the background doesn't step Edit-mode tweens; a 0.1 s tween was
  still at 0 after 0.25 s. So the spec's "closing animations eventually hide both menus" check
  fails on a timing wait, on code this branch never touches.
  - Run with a stand-in TweenService (each tween jumps to its goal after its time), it passes
    17/17.
  - Please re-run it once with Studio in the foreground.
  - The other 8 suites pass as normal: Equipment 2825, BallLauncher 5366, Field 612, TrainingUI
    33, GameAudio 15, Leaderboards 72, UICommon 13, WorldUI 14.

## What you need to do by hand
1. **Phase 2 models:**
   1. In Studio, use **Import 3D** on `assets/models/RunwayWorld4Home.fbx`. Keep the default
      settings, and leave the result in the Workspace (it is named `RunwayWorld4Home`).
   2. Paste `tools/studio/group_runway_imports.luau` into the command bar and press Enter. It
      prints one line per template and `RunwayWorld4Home: made 25, parts left 0`.
   3. Save the place.

## What to check in Studio
### Phase 2
- **Before importing:** World 4's runway should look as it did on `main`, except that the Picnic
  Blanket and Board Game Boulevard floors now have big checks (cream on red, and cream on dark).
- **After importing:** walk or fly along World 4's runway from the batting area.
  - Sections 1-5 should show the new props on the decks: grass clumps, hose reels, sprinklers,
    ladybugs, sandwiches, ants, picnic baskets, cutting boards, toasters, faucets, A-B-C blocks,
    toy trains, brick towers, dice, cards and player tokens.
  - The fillers should be small pebbles, crumbs, cereal loops, toy bricks and chess pawns.
  - On the outer ground should be the giant backdrops: picket fences, blanket heaps, cereal
    heaps, brick towers and game boxes.
- **What to look for:**
  - props facing the batter that should (the ladybug, the heart card, the token, the cutting
    board);
  - anything sunk into or floating above the deck;
  - fences running along the runway;
  - see-through water on the sprinkler and the faucet.
