# World 4: Tiny Town (design and build plan)

World 4 is built in phases, one session each. Every session starts from this doc and the
checklist at the bottom, then stops for review once its phase is done. Numbers here are
starting points; the balance simulator (`tools/balance`, `.vscode/ECONOMY.md`) has the final say.

## Concept

The player falls through World 3's singularity and comes out shrunk to bug size, playing
baseball across a giant house and yard. Everyday objects are huge: grass blades stand like
trees, a sandwich is a hill, a pencil is a tower. The tone is **playful and funny**, unlike the
epic tone of Worlds 1-3: bright toy colors, soft rounded shapes and silly details.

The core loop does not change. World 4 is one more World on the existing systems: the same
batting station, runway, sections, Training Grounds row, Ball series, item displays, portals and
saves. Reuse World 3's systems; do not build new ones.

## World

| Setting | Value |
|---|---|
| Id / name | `world_4`, "World 4", title "Tiny Town" |
| End distance | 8,000 studs (runout 2,000, like every World) |
| Cash | start pay 500,000 + x600 distance pay (Phase 1b; Phase 1 had x1,000). Hits start over here: Levels 370-490 grow from the early arc to the end portal |
| Offset | `Vector3.new(24000, 0, 0)` (World 3 is at 16,000) |
| Station / field | `BattingArea4` / `LongRangeField4` |
| Hub | `World4Hub`, theme `TinyTown`, Ball display title "TINY TOWN BALLS" |
| Runway | the existing `RunwayDecor` system, 10 sections, same widths and spacing as World 3 |
| Unlock | completing World 3 (final distance ≥ 7,000 in World 3), like every World |
| Finale | World 4 is the last World: its end portal plays the temporary "you finished the game" finale |

Section Cash multipliers follow the earlier Worlds' pattern: x1 for section 1, x1.15 for
sections 2-3, x1.35 beyond (and in the runout).

## Runway sections

| # | Id | Name | Distance | Look |
|---|---|---|---|---|
| 1 | `backyard` | Giant Backyard | 0-700 | grass blades like trees, garden hose, sprinkler, giant ladybug |
| 2 | `picnic` | Picnic Blanket | 700-1,400 | checkered blanket floor, huge sandwich, line of marching ants |
| 3 | `kitchen` | Kitchen Counter | 1,400-2,100 | cutting board, toaster, spilled cereal hills, dripping faucet |
| 4 | `blocktown` | Block Town | 2,100-2,800 | alphabet blocks as buildings, toy train track, building-brick towers |
| 5 | `boardgame` | Board Game Boulevard | 2,800-3,500 | chessboard floor, giant dice, playing cards, game pieces |
| 6 | `crafttable` | Craft Table | 3,500-4,200 | crayon pillars, paper airplanes, glue puddles, paper hills |
| 7 | `bathtub` | Bathtub Bay | 4,200-4,900 | bubble foam, rubber ducks, soap bars, tile floor |
| 8 | `bookshelf` | Bookshelf Cliffs | 4,900-5,700 | books as cliffs, pencils, spinning globe, reading lamp |
| 9 | `attic` | Attic Treasures | 5,700-6,800 | old trunks, cobwebs, rocking horse, moonlight through a window |
| 10 | `pillowfort` | Pillow Fort | 6,800-8,000 | blanket tunnels, giant pillows, glowing night-light |

**End portal:** a giant door keyhole glowing from the other side (`RunwayAssets.KeyholePortal`,
World 4's `portalModel`, so its hub World portal wears the same look).

Each section's `props`, `fillers` and `backdrop` name mesh kinds in `RunwayDecor` `MESH_PROPS` /
`BACKDROP_MESHES`. Phase 1 uses existing primitive kinds as placeholders (tinted by the
section's colors). Phases 2-3 add the real mesh kinds and switch the sections to them.

Suggested mesh kinds for Phases 2-3 (one Blender batch per phase):

| Section | Props | Filler | Backdrop |
|---|---|---|---|
| Giant Backyard | `grassBlade`, `gardenHose`, `sprinkler`, `ladybug` | `pebble` | `giantFence` |
| Picnic Blanket | `sandwich`, `antLine`, `picnicBasket` | `crumbs` | `blanketFolds` |
| Kitchen Counter | `cuttingBoard`, `toaster`, `faucet` | `cerealPiece` | `cerealHills` |
| Block Town | `alphabetBlock`, `trainTrack`, `brickTower` | `toyBrick` | `blockSkyline` |
| Board Game Boulevard | `giantDie`, `playingCard`, `gamePiece` | `chessPawn` | `boardGameBox` |
| Craft Table | `crayon`, `paperPlane`, `gluePuddle` | `paperScrap` | `paperHills` |
| Bathtub Bay | `rubberDuck`, `soapBar`, `bubbleFoam` | `bubbles` | `tubWall` |
| Bookshelf Cliffs | `pencil`, `spinningGlobe`, `readingLamp` | `eraser` | `bookCliffs` |
| Attic Treasures | `oldTrunk`, `rockingHorse`, `cobweb` | `dustBunny` | `atticWindow` |
| Pillow Fort | `giantPillow`, `blanketTunnel`, `nightLight` | `plushToy` | `pillowHills` |

Floors: the picnic blanket and the chessboard are checkered floors, Bathtub Bay is tiled, and
the Kitchen Counter, Craft Table, Bookshelf and Attic are planked or wood. Use the existing
`floorTiles` / `floorPlanks` / `floorPattern` flags, plus at most one new floor flag (a large
checker) if it is needed.

## Hub: Mouse-Hole Plaza

The shared hub layout (`WorldConfig` `hubLayout`), themed as a little town under the baseboard:

- matchbox houses and thread-spool towers on the berm
- bottle-cap floor tiles, with the plaza path laid in matchsticks or buttons
- a thimble fountain
- the mouse-hole arch in the baseboard behind the portal
- **event piece:** a giant wind-up key in the middle of the plaza, slowly turning (inside
  `eventArea`, kept low enough that it never hides the portal)

Built as a `HubDecor` theme `TinyTown` (Phase 6, done), from Parts like the other hubs
(the wind-up key turns through its Spin attributes).

## Training Grounds

World 4's row (`TrainingConfig.Hubs`), first cage nearest the batting area:

| Ground | Id | Access | Multiplier | Look |
|---|---|---|---|---|
| Sandbox Diamond | `sandbox_diamond` | free once World 4 unlocks | x270 | a sandbox, toy shovels as the bat rack, bucket pitching machine |
| Pinball Cage | `pinball_cage` | 20 Rebirths | x350 | inside a giant pinball machine |
| Cereal Bowl Stadium | `cereal_bowl_stadium` | 22 Rebirths | x450 | a spoon catapult pitcher |
| Toy Soldier Fort | `toy_soldier_fort` | 24 Rebirths | x580 | a wind-up soldier pitcher |
| Snow Globe | `snow_globe` | Cosmic Rift's pass (`sharesPass = "cosmic_rift"`) | x400 | snow swirls after each hit |
| Dragon's Lair | `dragons_lair` | its existing 1000 Robux pass | x30 | unchanged, stands in every hub |

Rules as for every ground: a ground can only be used once a World it stands in is unlocked;
paid grounds need no Rebirths; game-pass ownership is checked by the server. Phase 1 uses the
standard cage (`TrainingCage`) in toy colors; Phase 5 adds the five cage models
(`SandboxDiamondCage`, `PinballCage`, `CerealBowlCage`, `ToySoldierCage`, `SnowGlobeCage`), now fully
custom (none is built on the standard cage, which only stands in when a model isn't imported). The
Snow Globe's swirl after each hit is a client practice visual only.

## Balls (World 4 series)

A fourth purchase series (`EquipmentConfig` Ball `series` `world_4`, `requiredWorld = "world_4"`),
one Ball per section, bought in order from the Dandelion Puff. It needs World 4 unlocked and none
of the earlier series. Every Ball beats the one before and the Singularity Orb (11M).

| # | Ball | Id | Power | Price | Look and effects (Phase 4) |
|---|---|---|---|---|---|
| 1 | Dandelion Puff | `dandelion_puff_ball` | 16M | $500M | seeds drift off its trail |
| 2 | Blueberry | `blueberry_ball` | 24M | $650M | juice splash on landing |
| 3 | Meatball | `meatball_ball` | 36M | $850M | steaming, sauce-splat landing |
| 4 | Bouncy Ball | `bouncy_ball` | 54M | $1.1B | rainbow swirl, boing bounce |
| 5 | Lucky Dice | `lucky_dice_ball` | 80M | $1.4B | rounded die, shows a random number on landing |
| 6 | Yarn Ball | `yarn_ball` | 120M | $1.8B | colorful thread trail |
| 7 | Bath Bomb | `bath_bomb_ball` | 180M | $2.4B | fizzy colored bubble trail |
| 8 | Mini Globe | `mini_globe_ball` | 270M | $3.1B | tiny spinning Earth |
| 9 | Cat's-Eye Marble | `cats_eye_marble` | 400M | $4B | glass with a glowing swirl |
| 10 | Dream Orb | `dream_orb` | 600M | $5.4B | soft night-light glow, fading stars |

These are the design's starting prices. The balance passes kept the Power values and set the prices
to $530M, $1.1B, $1.2B, $1.35B, $1.5B, $1.9B, $2.1B, $2.3B, $2.55B and $2.8B (Phase 1b, with hits starting
over in each World and the Rolling Pin Bat; see `ECONOMY.md`). `EquipmentConfig` holds the live values.

The Lucky Dice's number is cosmetic, chosen by the client; it never changes a result. Effects
use `BallStyles` (flight layers, landing effects, idle emitters) like World 3's Balls, and models
come from one Blender batch (`tools/blender/balls_world4.py` → `assets/models/BallsWorld4.fbx`).
One new Bat, the **Rolling Pin Bat** (`rolling_pin_bat`, 42x Cash, $1.65B), added after the Celestial Bat in the shared Bat series (Phase 1b); its model comes in Phase 4.

## Portal journey

- World 3's end portal now leads to World 4 instead of playing the finale (`world_3.nextWorldId =
  "world_4"`). The finale's text moves to World 4's `endPortal.finale`.
- The trip cinematic (`PortalJourneyClient`) shows the player **shrinking** as they pass through
  (Phase 6, done: `world_4.shrinkTrip`; a shrinking copy of the batter spirals into the swirl).
- World 4's end portal takes over the temporary finale.
- Saves that already completed World 3 get World 4 unlocked on their next load (a completed
  World always unlocks its next World, `PlayerData` validate); their next World 3 portal hit
  does not replay the finale.

## Rules for every phase

- Read `AGENTS.md`, `WORLDS.md`, `ECONOMY.md` and the World 3 code first; reuse World 3's systems.
- Server-authoritative and configurable: unlocks, Power, Cash, prices and access stay on the
  server, and every value lives in a config module.
- Primitive fallbacks: World 4 stays playable when any model is missing. Runway props fall back
  to primitive builders or are skipped, cages to the standard cage, Balls to their
  `EquipmentConfig` appearance, the hub to the plain floor, and portals to the clockwork portal.
- Blender phases follow the existing pipeline:
  - one script per batch in `tools/blender/`, using `prop_helpers.py` (props, Balls, portal) or
    `cage_helpers.py` (cages);
  - built through the Blender MCP and exported as FBX to `assets/models/`;
  - imported into `ServerStorage.RunwayAssets` (by hand in Studio; not Rojo-managed);
  - loaded by name with primitive fallbacks;
  - matched to the scale and style of the World 3 models.
  Each phase lists the Studio import steps it needs by hand.
- Tests pass at the end of each phase, and each phase ends with a commit.
- At the end of each phase: update the checklist below, list what to check in Studio, and stop.

## Known issues (for World 5)

- **The Power cap:** Level requirements reach `ProgressionConfig.MaxPower` (9 quadrillion, kept
  below 2^53 so saved Power stays an exact integer) at about **Level 555** (Rebirth 27, three runs
  past World 4's end at Level 490). From there every Level needs exactly `MaxPower`, so runs stop
  growing and the pace flattens. World 4 itself is unaffected (its last band, Levels 500-519,
  peaks at ~2.5 quadrillion a Level), and `Progression.Advance` adds a grant bigger than
  `MaxPower` in pieces so no Power is lost. A World 5 past Level ~555 needs a bigger Power scale
  (for example a stored exponent or a second "Power tier" unit) or much slower band growth,
  decided before its bands are solved.

## Phase checklist

### Phase 0: design doc
- [x] Save this design as `.vscode/WORLD4_DESIGN.md` with the phase checklist
- [x] Add it to the docs list in `AGENTS.md`

### Phase 1: game setup (playable with primitive fallbacks)
- [x] `WorldConfig`: `world_4` (offset, station, field, hub, 10 sections with placeholder
      primitive props, end portal with the finale, preview colors); `world_3.nextWorldId =
      "world_4"` and its finale removed
- [x] `TrainingConfig`: the five new grounds (standard cage in toy colors) and World 4's hub row
- [x] `EquipmentConfig`: the `world_4` Ball series (10 Balls)
- [x] `ProgressionConfig`: launch speeds that carry hits from World 3's end to World 4's end
      (measured in World 4's field, `HitMeasurements.far`, since no hit past 7,000 studs had been
      measured; World 4 ends at Level 490), the Level bands for Levels 380-519 (LONG pace,
      `keepBands = 18`) and `ExpectedHitDistances`
- [x] Save data: no change needed (World unlocks are keyed by World id; a save that completed
      World 3 gets World 4 unlocked on load). `Progression.Advance` now adds a grant bigger than
      `MaxPower` in pieces, so late-World-4 offline grants and the 3x are not cut off
- [x] Balance simulator: World 4 included; re-run with the current multiplier ladders; Ball
      prices flattened ($500M-$2.5B), ground multipliers and Ball Power kept; times in `ECONOMY.md`
- [x] Tests pass
- [x] `ECONOMY.md` and `WORLDS.md` updated (plus `AGENTS.md`, `CLAUDE.md`, `GAME_DESIGN.md` and
      `tools/balance/README.md`)
- [x] Commit

### Phase 1b: hits start over in each World, and the Rolling Pin Bat
- [x] `WorldConfig` `launchLevels` (World 2 150-250, World 3 250-370, World 4 370-490), `cashBase`
      start pay (3,000 / 40,000 / 500,000) with multipliers 7 / 60 / 600
- [x] `ProgressionConfig.GetWorldLaunchLevel` + `WorldLaunchSteps` (simulator `designWorldLaunch`);
      `GetHitCash` start pay; used by `BallLauncher` and the Cash Pack quotes
- [x] Rolling Pin Bat (`rolling_pin_bat`, 42x, $1.65B) after the Celestial Bat; placeholder colours
- [x] Worlds 2-4 repriced; World 2's end gap closed (Lightning Bat $3.2M, now World 2's last
      purchase; Clockwork Ball $1.35M); Phase 1's World 4 bands kept (re-solving did not help)
- [x] Simulator `WORLD DISTANCES` section; tests (every World reaches its end exactly at its `to`,
      first hit pays more than the previous World's best, earlier Worlds never pay more)
- [x] Docs; commit
- Not done: shortening World 4's first full run's early-arc stretch (about a quarter of
  Rebirth 19). With distance from Level and World only, it cannot be shortened while the arrival
  hit still starts over (see `ECONOMY.md` Decisions to review).

### Phase 2: runway props, sections 1-5 (Blender)
- [x] `tools/blender/runway_world4_home.py` (Giant Backyard to Board Game Boulevard), exported to
      `assets/models/RunwayWorld4Home.fbx` (+ `RunwayWorld4Home.json` manifest): 25 templates. The
      backyard has a `HoseReel` (a hose on a reel cart, easier to read than a coil on the ground);
      `blockSkyline` reuses `BrickTower` at backdrop scale; `GamePiece` is a wooden player token
- [x] `RunwayDecor` `MESH_PROPS` / `BACKDROP_MESHES` entries; sections 1-5 switched to them. Each new
      kind has a `fallback` (the Phase 1 placeholder it replaced), used until its model is imported,
      so the runway keeps its current look before the import
- [x] New floor flag `floorChecker` (20-stud checks in the section accent) for the Picnic Blanket and
      Board Game Boulevard
- [x] Studio import steps (`tools/studio/group_runway_imports.luau` groups the import); tests pass; commit
- Studio import (by hand): Import 3D `assets/models/RunwayWorld4Home.fbx` (defaults, leave it in the
  Workspace), run `tools/studio/group_runway_imports.luau` in the command bar, save the place

### Phase 3: runway props, sections 6-10, and the keyhole end portal (Blender)
- [x] `tools/blender/runway_world4_house.py` (Craft Table to Pillow Fort), exported to
      `assets/models/RunwayWorld4House.fbx` (+ manifest): 24 templates; `pillowHills` reuses
      `GiantPillow` at backdrop scale; the paper plane and bubbles float (`lift`)
- [x] `tools/blender/keyhole_portal.py`, exported to `assets/models/KeyholePortal.fbx`: an arched
      wooden door, brass escutcheon, knob and hinges; `PortalVortex` is keyhole-shaped (the gate's
      capture is by distance, so the smaller opening only changes the trip's framing);
      `world_4.portalModel = "KeyholePortal"`; `WorldPortal` `LOOKS.KeyholePortal` (until imported,
      the clockwork portal stands in)
- [x] Sections 6-10 switched to their meshes (each with its placeholder `fallback`); Studio import
      steps listed; tests pass; commit
- Studio import (by hand): Import 3D `RunwayWorld4House.fbx` and `KeyholePortal.fbx`, run
  `tools/studio/group_runway_imports.luau`, save the place

### Phase 4: the 10 Balls and the Rolling Pin Bat (Blender)
- [x] `tools/blender/balls_world4.py`, exported to `assets/models/BallsWorld4.fbx`
- [x] `BallStyles` entries: parts, trails, landing effects and idle emitters (World 4 emitters and
      bursts; the Lucky Dice's landing burst pops up a number 1-6 picked on each client,
      `BallEffects` `number`, cosmetic only; flight sounds for the Bath Bomb and Dream Orb)
- [x] The Rolling Pin Bat model (`tools/blender/bats_world4.py`, bats.py's helpers and conventions,
      exported to `assets/models/BatsWorld4.fbx` so the ten earlier bats need no re-import;
      `BatStyles` entry with a flour trail, flour contact burst and idle flour dust). Its
      `EquipmentConfig` appearance stays as the stand-in until the model is imported
- [x] Studio import steps (`tools/studio/group_item_imports.luau` groups both imports into
      `DisplayItems`); tests pass; commit
- Studio import (by hand): Import 3D `BallsWorld4.fbx` and `BatsWorld4.fbx`, run
  `tools/studio/group_item_imports.luau`, save the place

### Phase 5: the cage models (Blender)
- [x] `cage_helpers.py` scripts for the Sandbox Diamond, Pinball Cage, Cereal Bowl Stadium, Toy
      Soldier Fort and Snow Globe (`sandbox_diamond_cage.py`, `pinball_cage.py`, `cereal_bowl_cage.py`,
      `toy_soldier_cage.py`, `snow_globe_cage.py`), exported to `assets/models/` (`SandboxDiamondCage`,
      `PinballCage`, `CerealBowlCage`, `ToySoldierCage`, `SnowGlobeCage`)
- [x] Rebuilt as fully custom cages (branch `custom-cages`, `.vscode/CAGES_REPORT.md`): each has its
      own frame, walls, roof, floor, pitcher, screen, scenery and moving pieces, none from the
      standard cage, and no plain rectangle: a hexagonal sandbox, a pinball cabinet with a backbox
      head, a flared cereal bowl, a toy fort with towers, and a glass dome on a music box as the
      showpiece. They share `cage_helpers.py`; `tiny_cage_helpers.py` is removed
- [x] `TrainingConfig` templates switched, with `TrainingCageStyles` entries (the Toy Soldier's
      wind-up key turns and its flags wave, the pinball bumpers and chase lights pulse and its
      spinners turn, the cereal bobs, the Snow Globe's carousel, skaters and flakes turn and snow falls
      in it); the Snow Globe's after-hit swirl is a client practice visual
      (`theme.practiceHitEffect = "SnowSwirl"`, `TrainingClient`)
- [x] Studio import steps (`tools/studio/group_item_imports.luau` also moves the cages into
      `RunwayAssets`); tests pass; commit
- [x] Imported and checked in Studio: the home plates match the standard cage's, every mesh is
      styled, every moving piece moves, and no cage overlaps its neighbours or the hub

### Phase 6: hub, event piece and the shrinking portal cinematic
- [x] `HubDecor` theme `TinyTown` (Mouse-Hole Plaza) and the turning wind-up key: floorboards with
      bottle caps, matchstick-edged paths, a button spawn and portal pad, a baseboard bowl, the mouse
      hole (with glowing eyes and the World's sign) behind the portal, a thimble fountain, matchbox
      houses and thread-spool towers outside, and World 4's runway models (placeholder kinds until
      imported). Built from Parts, like the other hubs; no new Blender batch
- [x] `PortalJourneyClient`: the shrinking trip from World 3 to World 4 (`world_4.shrinkTrip`): in the
      plunge an anchored copy of the batter spirals in and shrinks to bug size while the real
      character stays hidden (it is never scaled)
- [ ] World 4's Worlds-menu card image (a Studio capture of the hub). Not done: Studio's screen
      capture did not work while it was in the background; World 4's card keeps its painted
      sky/ground colours until a capture is uploaded and set as `world_4.preview.image`
- [x] Studio checks listed; tests pass; commit
