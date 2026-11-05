# World 4 overnight report (branch `world4-art`)

Work on Phases 2-6 of `.vscode/WORLD4_DESIGN.md`, done without review. Everything is on the
`world4-art` branch, which starts from `main` at `bd4b478`. Nothing was merged into `main`.
This file is updated after every phase.

## Status by phase

| Phase | What | Commit | State |
|---|---|---|---|
| 2 | Runway props, sections 1-5 | `410485c` | Done; the models need importing by hand |
| 3 | Runway props, sections 6-10; keyhole end portal | `012bd89` | Done; the models need importing by hand |
| 4 | The ten World 4 Balls and the Rolling Pin Bat | `5227bcf` | Done; the models need importing by hand |
| 5 | The five World 4 cages and the Snow Globe swirl | (this commit) | Done; the models need importing by hand |

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

### Phase 3: runway props, sections 6-10, and the keyhole end portal
- **Blender script:** `tools/blender/runway_world4_house.py` builds 24 templates. It is exported
  to `assets/models/RunwayWorld4House.fbx`, with its manifest.
  - **Craft Table:** Crayon, PaperPlane (floating), GluePuddle; filler PaperScrap; backdrop
    PaperHills.
  - **Bathtub Bay:** RubberDuck, SoapBar, BubbleFoam; filler Bubbles (floating); backdrop TubWall.
  - **Bookshelf Cliffs:** Pencil (three in a cup), SpinningGlobe, ReadingLamp; filler Eraser;
    backdrop BookCliffs.
  - **Attic Treasures:** OldTrunk, RockingHorse, Cobweb (with a little spider); filler
    DustBunny; backdrop AtticWindow (moonlit).
  - **Pillow Fort:** GiantPillow, BlanketTunnel, NightLight (a glowing crescent moon and star);
    filler PlushToy; backdrop GiantPillow at backdrop scale.
- **Keyhole portal:** `tools/blender/keyhole_portal.py`, exported to
  `assets/models/KeyholePortal.fbx`.
  - It is an arched wooden door with panel mouldings, a brass escutcheon, a knob and hinges, on
    a stone threshold.
  - Its keyhole-shaped `PortalVortex` glows warm, with the spiral `PortalSwirl` turning in the
    keyhole's round top.
  - `WorldPortal` has a new `LOOKS.KeyholePortal`, and `world_4.portalModel = "KeyholePortal"`.
    Until the model is imported, the clockwork portal stands in, as before.
- **Sections:** `RunwayDecor` has entries for all 24 kinds, each with its placeholder fallback.
  `WorldConfig` sections 6-10 are switched to them.
- **Import tool:** `group_runway_imports.luau` now also handles the house batch, and moves the
  keyhole portal into `RunwayAssets` whole.
- **Checks:**
  - **Placeholders:** in a playtest, World 4 builds with its placeholders, and both portals use
    the clockwork stand-in (opening radius 106).
  - **Stand-ins:** with stand-in templates, all 24 house kinds placed (1,083 parts) and every part
    was tinted. A stand-in `KeyholePortal` gate got its looks: the swirl spins, the glow pulses,
    and it stands 360 studs tall with an opening radius of 79.
  - **Tests:** the same as Phase 2. All suites pass; UIModal passes with the tween stand-in.

### Phase 4: the ten Balls and the Rolling Pin Bat
- **Balls:** `tools/blender/balls_world4.py` builds the ten Balls at radius 1, each mesh named
  `<id>__<Part>` with a 2-unit `Shell`. It is exported to `assets/models/BallsWorld4.fbx`.
  - **Dandelion Puff:** seed stalks with parachute tufts.
  - **Blueberry:** a crown, a frosty bloom and a leaf.
  - **Meatball:** a lumpy shell, a sauce dollop and herb flecks.
  - **Bouncy Ball:** three rainbow spiral stripes.
  - **Lucky Dice:** a die's pips on six sides; the single pip is red.
  - **Yarn Ball:** wound strands and a loose end.
  - **Bath Bomb:** a swirl band, speckles and fizz bubbles.
  - **Mini Globe:** continents and ice caps.
  - **Cat's-Eye Marble:** a glass shell with three glowing vanes.
  - **Dream Orb:** a crescent moon, stars and a cloud wisp.
- **Rolling Pin Bat:** `tools/blender/bats_world4.py` uses `bats.py`'s helpers and hand-at-origin
  layout. It is a wooden roller with red turned handles at both ends, red rings and a flour
  dusting, exported to `assets/models/BatsWorld4.fbx`.
- **`BallStyles`:** each World 4 Ball has parts, a light where it glows, its own flight layers, and
  launch and landing bursts.
  - The effects are seeds drifting off the Dandelion Puff, juice splashing from the Blueberry,
    steam and a sauce splat from the Meatball, a rainbow wiggle and a boing from the Bouncy Ball,
    tumbling mini dice round the Lucky Dice, coloured threads off the Yarn Ball, fizz from the Bath
    Bomb, an orbiting moon round the Mini Globe, glimmers off the Cat's-Eye Marble, and dreamy
    stars and echoes behind the Dream Orb.
  - There are eight new emitters (seven for the Balls, plus FlourDust for the bat) and eleven new
    bursts, and flight sounds for the Bath Bomb and Dream Orb (existing sound ids, retuned).
- **Lucky Dice:** its landing pops up a number from 1 to 6 (`BallEffects` burst `number`). The
  number is picked on each client, so it is cosmetic only.
- **`BatStyles`:** `rolling_pin_bat` has a flour-white swing trail, a flour puff on contact and
  idle flour dust. Its `EquipmentConfig` appearance stays as the stand-in until the model is
  imported; only the comment changed.
- **Import tool:** `tools/studio/group_item_imports.luau` groups both imports into `DisplayItems`.
  A Ball is pivoted on its Shell, and the Bat on the hand, the same as World 3's.
- **Checks (playtest, client):**
  - All ten World 4 styles resolve every burst and emitter name, and every burst plays.
  - The dice number pops up.
  - Each World 4 Ball's flight effects launch, update along a fake flight and stop without
    errors.
  - The Output is clean.
  - Tests: as before.

### Phase 5: the five cage models
- **Scripts:** one Blender script per cage, all on a shared `tools/blender/tiny_cage_helpers.py`.
  It builds the standard cage's frame, nets, screen, plate, bucket and lights (from
  `batting_cage.py`) with each cage's own mesh names, and each script adds its toy scenery. All
  are exported at 1/4 scale to `assets/models/`, within the row's side limits.
  - **Sandbox Diamond** (`SandboxDiamondCage`): a wooden sandbox border with corner seats, sand
    heaps, a toy pail on its side as the pitching machine, a rack of toy shovels, and a sandcastle
    and beach ball at the far end.
  - **Pinball Cage** (`PinballCage`): a purple cabinet with glass sides and a glass roof,
    neon-ringed bumpers, slingshot kickers, flippers behind the batter, a spring plunger, a lit
    backbox with marquee lights and a star, and neon lane arrows.
  - **Cereal Bowl Stadium** (`CerealBowlCage`): a rounded-square ceramic bowl wall round the cage
    (open at the door) with a rolled rim, a milk pool, floating and heaped cereal loops, a spoon
    catapult as the pitcher, and two cereal-box towers.
  - **Toy Soldier Fort** (`ToySoldierCage`): crenellated wooden walls with a gate, four corner
    towers with cone roofs and pennants, and a wind-up toy soldier as the pitcher whose brass key
    turns.
  - **Snow Globe** (`SnowGlobeCage`): a glass superellipsoid dome over the whole cage (cut open
    at the door, with a wooden door frame), a turned wooden base with a gold band, snowdrifts,
    pines, a snowman and snow on the cage roof.
- **`TrainingCageStyles`:** entries for all five, with motion and effects.
  - The key spins, the bumper rings and marquee pulse, and the pennants sway.
  - The Pinball Cage has sparkles, and snow falls inside the Snow Globe.
  - Each cage has a colour tint inside.
- **`TrainingConfig`:** the five grounds now name their templates. Until the models are imported,
  the standard cage stands in, as it did for World 3; TrainingStadium logs one existing "missing"
  warning per cage, and nothing else.
- **Snow Globe swirl:** the ground's theme has `practiceHitEffect = "SnowSwirl"`. As the bat
  meets each practice ball, `TrainingClient` blows a ring of snow gusts round the plate. This is a
  client visual only; Training and Power are untouched.
- **Import tool:** `tools/studio/group_item_imports.luau` also moves the five cage imports into
  `RunwayAssets` (a half turn and 0.01 scale, like World 3's cages). It prints each cage's home
  plate next to the standard cage's, as a check.
- **Checks:**
  - **Styles:** all five load and every effect preset exists, covering every exported mesh.
  - **Grounds:** World 4's six grounds build in a playtest.
  - **Swirl:** its emitter code runs on the client.
  - **Output:** only the five expected missing-template warnings.
  - **Tests:** as before.

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
- **Pencils:** the pencil is three pencils in a cup, so it stands tall.
- **Pillow Fort's backdrop:** `pillowHills` reuses the GiantPillow model, scaled up.
- **Portal opening:** the keyhole portal's opening is keyhole-shaped, so its `OpeningRadius` is
  smaller than the round vortex's. A hit is still captured by distance alone (BallLauncher); only
  the trip's camera framing uses the radius.
- **Floating props:** the paper plane (lift 6) and the bubbles (lift 2) float, like World 3's
  floating props.
- **The keyhole look stays in World 4.** It is World 4's `portalModel`, as the design says, so it
  appears on World 4's hub portal and end portal. World 3's portals are unchanged.
- **Rolling Pin Bat file:** the bat has its own script and FBX (`bats_world4.py`,
  `BatsWorld4.fbx`) instead of being added to `bats.py`. Re-exporting `Bats.fbx` would have meant
  re-importing all ten earlier bats.
- **Flight sounds:** only the Bath Bomb and Dream Orb have their own flight sound, reusing
  existing sound ids. The other World 4 Balls use the shared whoosh, as most earlier Balls do.
- **Rolling Pin Bat's swing:** it gets a flour trail, a flour contact burst and idle flour dust,
  to fit its theme.
- **Cages, shared base:** the World 4 cages share one helper that rebuilds the standard cage's
  pieces under each cage's names. They are simpler than World 3's 700-900 line cage scripts:
  themed scenery round the standard frame, rather than wholly custom structures.
- **Cages, pitchers:** the Sandbox Diamond's pitcher is a toy pail and the Cereal Bowl's a spoon
  catapult, replacing the standard machine. The Pinball Cage and Snow Globe keep the standard
  machine (the pinball adds a plunger behind it).
- **Snow Globe enclosure:** it keeps the standard nets inside its glass dome. The dome is cut open
  at the door and framed in wood, so walking in still reads as a doorway.
- **Snow Globe swirl hook:** the swirl uses a new theme field, `practiceHitEffect`, read by
  `TrainingClient`. This is the simplest hook that keeps it a client practice visual.
- **Pinball flippers** sit behind the batter, clear of the door path. Cage meshes don't collide,
  but a flipper across the doorway would look wrong.

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
2. **Phase 3 models:** Import 3D `assets/models/RunwayWorld4House.fbx` and
   `assets/models/KeyholePortal.fbx`, leaving both in the Workspace. Run the same script again
   (it reports `RunwayWorld4House: made 24, parts left 0` and `KeyholePortal: moved into
   RunwayAssets`), then save the place. You can import all three files first and run the script
   once.
3. **Phase 4 models:** Import 3D `assets/models/BallsWorld4.fbx` and `assets/models/BatsWorld4.fbx`,
   leaving both in the Workspace. Run `tools/studio/group_item_imports.luau` in the command bar.
   - It should print ten Ball lines, each about 2 studs across (the Dandelion Puff about 2.8),
     and one Bat line about 4.3 studs long.
   - It should end with `BallsWorld4 parts left: 0` and `BatsWorld4 parts left: 0`.
   - Then save the place.
4. **Phase 5 cages:** Import 3D the five cage files from `assets/models/`
   (`SandboxDiamondCage.fbx`, `PinballCage.fbx`, `CerealBowlCage.fbx`, `ToySoldierCage.fbx` and
   `SnowGlobeCage.fbx`). Run `tools/studio/group_item_imports.luau` again; it handles the cages
   too. Check that each printed "home plate (x4)" matches the standard TrainingCage's line,
   printed last. If one is off, the cage's pivot is wrong, so tell me. Then save the place.
5. **Restart the playtest after importing.** The runway, portals, displays and cages are built
   when the server starts.

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

### Phase 3
- **Before importing:** sections 6-10 look as they did on `main`, and World 4's hub portal and end
  portal are still the clockwork portal.
- **After importing:**
  - **Sections 6-10:**
    - **Craft Table:** crayons, gliding paper planes, glue bottles with puddles, paper scraps, and
      faceted paper hills on the outer ground.
    - **Bathtub Bay:** rubber ducks, soap bars on dishes, foam heaps, floating bubbles and the
      claw-foot tub wall.
    - **Bookshelf Cliffs:** pencil cups, globes, desk lamps, erasers and cliffs of giant books.
    - **Attic Treasures:** trunks, rocking horses (side on), cobwebs, dust bunnies and moonlit
      round windows.
    - **Pillow Fort:** pillows, blanket tunnels (opening toward the batter), night lights, teddy
      bears and pillow heaps.
  - **World 4's hub portal:** the arched door with a glowing keyhole.
  - **End portal:** the same door, 360 studs tall, at 8,000 studs. A World 4 portal hit should
    still be pulled into the keyhole and play the finale.
- **What to look for:**
  - whether the keyhole glow reads warm and bright from the batting area;
  - whether the swirl turns inside the keyhole's round top;
  - whether the floating paper planes and bubbles hover at a sensible height.

### Phase 4
- **Before importing:** nothing changes on the displays. The World 4 Balls and the Rolling Pin Bat
  are still the placeholder ball and bat in their `EquipmentConfig` colours, and their idle
  effects only show on the real models (`ItemDisplay`). A hit with a World 4 Ball already plays
  its new flight effects, though.
- **After importing:** World 4's Ball display shows the real models. The Rolling Pin Bat pedestal
  shows a rolling pin, and so does the batter's hand once it is equipped.
- **What to look for, hitting with each World 4 Ball (`StudioFreshSave` with the Studio
  attributes to own them):**
  - **Lucky Dice:** a red number pops up where it lands.
  - **Cat's-Eye Marble:** the glass shell lets its green vanes glow through.
  - **Yarn Ball:** its threads twist behind it.
  - **Dandelion Puff:** its seeds drift slowly.
- **Rolling Pin Bat:** swing it and look for a flour puff on contact.

### Phase 5
- **Before importing:** World 4's grounds look as before: the standard cage in toy colours. The
  Output shows one "is missing; using the standard cage" warning for each of the five.
- **After importing:** walk down World 4's Training Ground row.
  - **What each cage should show:**
    - **Sandbox Diamond:** a sandbox border, a toy pail and shovels.
    - **Pinball Cage:** a purple cabinet under glass, with glowing bumpers and a lit backbox.
    - **Cereal Bowl Stadium:** a bowl wall, cereal loops and a spoon catapult.
    - **Toy Soldier Fort:** fort walls, towers and a wind-up soldier whose key turns.
    - **Snow Globe:** a glass dome with falling snow, and a swirl of snow after each practice hit
      (it needs the Cosmic Rift pass; in Studio, the pass attribute you normally test with).
  - **Things to check:**
    - each cage's door lines up with the doorway in the walls, bowl or dome;
    - nothing overlaps the next cage;
    - the camera stays inside the cage while training;
    - the Snow Globe's glass doesn't make the inside too hazy.
