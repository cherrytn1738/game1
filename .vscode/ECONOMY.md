# Economy and Progression Balance

How Power, Levels, Rebirths, Cash, equipment and the purchased multipliers are tuned, what the
targets are, and what the simulator says the game does with them. The numbers live in config
modules; this file explains them. Everything here is balance, not fixed design: re-tune with
`tools/balance` (see its `README.md`) and update this file with the new results.

| What | Where |
|---|---|
| Level bands, Level Cap, Training base, hit Power, launch speed, Cash formula | `src/replicated/ProgressionConfig.luau` |
| Ball / Bat multipliers and prices | `src/replicated/EquipmentConfig.luau` |
| Training Grounds, offline rate and cap | `src/replicated/TrainingConfig.luau` |
| World Cash multipliers, runway sections | `src/replicated/WorldConfig.luau` |
| Purchased Power / Cash multipliers (Robux tiers) | `src/replicated/MonetizationConfig.luau` |
| Simulator, hit measurements, results | `tools/balance/` (`output/*.csv`) |

## The model

Roles (established design): the **Ball** multiplies Power (Training, hits, offline), the **Bat**
multiplies batting Cash, **Training Grounds** multiply Training Power only, **Rebirths** multiply
Power by Rebirths + 1, and **Level and the World you bat in** set the launch (and so the distance):
hits start over in each new World. The **purchased multipliers** (Robux, permanent tiers) multiply
Power gain and batting Cash, never the distance.

- **Level requirement:** in bands. Levels 1-19 need `10 + 1.5 × (Level − 1)`, rounded down (10,
  11, 13, 14, ... 37; 442 in all). From Level 20 each Rebirth's 20 new Levels are one band: the
  band's first Level needs `start`, and each Level after it 1.02× the one before (the band's last
  Level needs ~1.46× its first). Past Level 519 each band starts 1.8× above the one before.
- **Level Cap:** `20 × (Rebirths + 1)`: 20, 40, 60, ... Power keeps banking at the cap until the
  Rebirth, which resets Level and Power.
- **Training base:** Power per practice hit at Basic Training: 5 at every Level (Level never
  scales Power gain). One practice hit every 2 s.
- **Training Power** = Training base × ground × Ball × (Rebirths + 1) × purchased Power × Power juice.
- **Hit Power** = Training base × 0.37 × seconds in play (rounded) × Ball × (Rebirths + 1) ×
  purchased Power × Power juice. No ground.
- **Offline Power** = 25% of the best usable ground's Training rate (no Level term), for up to
  8 hours, × the saved Ball × (Rebirths + 1) × purchased Power (never a juice), held to half the
  Power still needed for the Level Cap (the run cap). Welcome Back's 3x product adds it twice
  more, up to all of it.
- **Hit Cash** = `(World start pay + World multiplier × (distance / 80)^1.5)` × section (1, 1.15,
  1.35) × Bat × purchased Cash × Cash juice, rounded, at least $1. World 1 has no start pay and
  multiplier 1 (an early hit pays $1); see Cash below for the later Worlds.
- **Distance:** Level → launch Level in the World you bat in (`GetWorldLaunchLevel`, see Distance per
  World) → launch speed (`LaunchSpeedTable` to Level 140, then `LaunchSpeedSteps`), built from
  measured hits (see Hit physics below).

## Simulator assumptions

The baseline player is free-to-play: no game passes, no Juice, no Welcome Back claim, no Robux.
The spender scenarios (below) add the purchased multipliers, juices and paid grounds to the same
active player.

- Timings measured in Studio: first practice hit 1.1 s after stepping on a plate, then every 2 s;
  a hit takes 3.4 s (Level 1) to ~23 s (World 3) from swing to result, plus 1.2 s to swing again.
- Walks: spawn → Basic Training 4 s, plate → tee 4.6 s, tee → Sandlot pedestal 5.6 s + two clicks
  (3 s), back to Basic Training 7.7 s; plate ↔ tee later 6 s. A purchase 4 s, a Rebirth 5 s, a
  World trip 15 s.
- **Training-only:** after the tutorial, only Trains at the best free ground with the Sandlot Ball
  and Rebirths at each cap.
- **Active:** repeats 60 s of Training and 30 s of batting; after every hit buys the strongest
  affordable Ball that beats the equipped one (any unlocked series), otherwise the next Bat;
  Rebirths at each cap. This is the player the bands are solved for.
- **Casual returning:** the active pattern for one 30-minute session a day; Offline Training (8 h
  cap, run cap) on each return, without the 3x.

## Hard targets

| Target | Goal | Simulator | Studio (fresh save) |
|---|---|---|---|
| Tutorial 1: 30 Power | ~15 s, ~6 hits at ~+5 | 15.1 s (6 hits: +5 +5 +6 +6 +6 +6) | 11.1 s on the plate, 6 hits (+ ~4 s walk) |
| Tutorial 2: $2 from batting | 15-20 s, ~2 hits at ~$1 | 14.4 s, 2 hits | 2 hits at $1, 3.5 s each (+ walk) |
| Tutorial 3: Sandlot Ball | $2, 3x, 10-15 s | 8.6 s | bought for $2 and equipped |
| Tutorial 4: Level 20 + Rebirth | 45-60 s of Training | 54.0 s of Training (60.8 s with the walk) | to re-measure (LONG bands) |
| Whole tutorial | 1.5-2 min | 1 min 44 s | to re-measure |
| Second run, Training only, Level 1 → 40 | ~3 min | 3.0 min | to re-measure |
| Batting vs Basic Training | 50-70% | 49-69% | 11 Power a hit at Level 3 |
| Free-to-play World 2 / World 3 / World 4 | ~1h 40m / ~4h 45m / ~10h 30m | 1h 41m / 4h 38m / 10h 15m | |
| World 4's runs (Rebirths 19-24) | LONG pace: 75-95 min | 68-99 min; finale 18h 03m | |
| Hits start over in each World | its first hit far shorter than the last World's, but paying more; every section landed in | first hits 146 studs paying 3.9-4.5× the last World's best; each run sweeps 2-3 sections | |
| Nothing to buy | no long waits | longest: World 1 17 min, World 2 34, World 3 48, World 4 55 | |
| One tier of each multiplier | 30-35% faster finale | 49% (9h 15m): stronger on purpose, see Decisions to review | |
| Every tier | finale no sooner than half of free-to-play | 4h 18m (76% faster): stronger on purpose | |

Tutorial step 3 is mostly walking and clicking, so balance cannot move it.

## Level bands

**LONG pace (chosen):** run k of an active player takes about `3 + 4 × (k − 1)` minutes. Solved
with `solveBands` and smoothed so a band never starts below the Level before it; the tutorial band
is solved separately so its Level 20 climb takes ~54 s of Training (`solveTutorial`).

| Levels | First Level needs | Band total | Step from the Level before |
|---|---:|---:|---:|
| 1-19 | 10 (+1.5 a Level) | 442 | |
| 20-39 | 90 | 2.18K | ×2.4 |
| 40-59 | 3,200 | 77.7K | ×24.4 |
| 60-79 | 48,000 | 1.17M | ×10.3 |
| 80-99 | 470,000 | 11.4M | ×6.7 |
| 100-119 | 3.2M | 77.8M | ×4.7 |
| 120-139 | 13M | 316M | ×2.8 |
| 140-159 | 64M | 1.56B | ×3.4 |
| 160-179 | 300M | 7.29B | ×3.2 |
| 180-199 | 1.4B | 34B | ×3.2 |
| 200-219 | 4B | 97.2B | ×2.0 |
| 220-239 | 9B | 219B | ×1.5 |
| 240-259 | 26B | 632B | ×2.0 |
| 260-279 | 86B | 2.09T | ×2.3 |
| 280-299 | 310B | 7.53T | ×2.5 |
| 300-319 | 830B | 20.2T | ×1.8 |
| 320-339 | 1.5T | 36.4T | ×1.2 |
| 340-359 | 2.7T | 65.6T | ×1.2 |
| 360-379 | 4.9T | 119T | ×1.2 |
| 380-399 | 19T | 462T | ×2.7 |
| 400-419 | 53T | 1.29Qa | ×1.9 |
| 420-439 | 130T | 3.16Qa | ×1.7 |
| 440-459 | 260T | 6.32Qa | ×1.4 |
| 460-479 | 520T | 12.6Qa | ×1.4 |
| 480-499 | 940T | 22.8Qa | ×1.2 |
| 500-519 | 1.7Qa | 41.3Qa | ×1.2 |
| 520+ | ×1.8 a band (each Level at most `MaxPower`, 9Qa, from about Level 555) | | |

**World 4's bands** (Levels 380-519, Rebirths 19-24) were solved for the LONG pace with
`keepBands = 18`, which keeps every band before them, so Worlds 1-3 play exactly as before (no
player reached Level 380 before the old finale at Level 370). (Qa = quadrillion.)

The big steps at Levels 40 and 60 are the second and third runs' bands: from run 2 the active
player has the Enchanted Grove (5x), better Balls and two Rebirths, many times run 1's Power rate.

**Existing saves** keep their Level and Power: every load re-runs the save through the current
bands (`Progression.Normalize` → `Advance(state, 0)`), so Power above a now-smaller requirement
levels the player up at once (up to the Level Cap, where the rest banks), and where a requirement
grew the player just needs a little more for their next Level. Nothing is taken away and no save
field migrates for a band change.

## Training Grounds

Multipliers and gates rise in order; World 4's are the design's starting values, kept as they
are because the bands were solved around them. Power a practice hit at any Level, before Ball,
Rebirth and purchased multiplier:

| Ground | World | Unlock | × | Power a hit |
|---|---|---|---:|---:|
| Basic Training | 1 | start | 1 | 5 |
| Enchanted Grove | 1 | 2 Rebirths | 5 | 25 |
| Sunken Atlantis | 1 | 4 Rebirths | 10 | 50 |
| Sky Temple | 1 | 6 Rebirths | 20 | 100 |
| Cosmic Rift | 1 | 500 R$ pass | 10 | 50 |
| Caveman Camp | 2 | World 2 | 25 | 125 |
| Pharaoh's Tomb | 2 | 8 Rebirths | 35 | 175 |
| Gladiator Colosseum | 2 | 10 Rebirths | 50 | 250 |
| Samurai Dojo | 2 | 12 Rebirths | 70 | 350 |
| Time Machine Lab | 2 | Cosmic Rift's pass | 35 | 175 |
| Solar Rooftop | 3 | World 3 | 90 | 450 |
| Robo Factory | 3 | 14 Rebirths | 120 | 600 |
| Biodome Lab | 3 | 16 Rebirths | 160 | 800 |
| Lunar Base | 3 | 18 Rebirths | 210 | 1,050 |
| Quantum Lab | 3 | Cosmic Rift's pass | 120 | 600 |
| Sandbox Diamond | 4 | World 4 | 270 | 1,350 |
| Pinball Cage | 4 | 20 Rebirths | 350 | 1,750 |
| Cereal Bowl Stadium | 4 | 22 Rebirths | 450 | 2,250 |
| Toy Soldier Fort | 4 | 24 Rebirths | 580 | 2,900 |
| Snow Globe | 4 | Cosmic Rift's pass | 400 | 2,000 |
| Dragon's Lair | 1 / 2 / 3 / 4 | 1000 R$ pass | 15 / 45 / 150 / 500 | 75 / 225 / 750 / 2,500 |

Dragon's Lair stands in every hub, and its multiplier is the World's it is used in (`TrainingConfig`
`worldMultipliers`, read through `Training.GetMultiplier`): a little above that World's premium
ground (10 / 35 / 120 / 400) and below its best Rebirth ground (20 / 70 / 210 / 580), so it is never
the best cage in a World once that ground opens. Training, offline Training (`GetBestGround`
returns the World too), the quick teleport, the Shop card, the Training menu and the cage labels
all use the World's value.

Free-to-play never needs a paid ground. Game-pass ids stay 0 until the passes are created.

## Equipment

**World 1 Balls** (the fixed anchors): Baseball 1x free, Sandlot 3x $2, Bubblegum 5x $10,
Crystal 12x $40, Frost Comet 30x $150, Inferno 75x $500, Thunder 200x $1,500, Galaxy 500x $4,500,
Dragonfire 1,250x $14,000, Supernova 3,500x $40,000.

**World 2 Balls** (×1.5 a step, all above the Supernova; priced for World 2's Cash, which now
starts over with the World: see Cash):

| Ball | × | Price | Before the per-World reset |
|---|---:|---:|---:|
| Dino Egg | 5,000 | $175K | $150K |
| Stone Ball | 7,500 | $220K | $200K |
| Scarab Ball | 11,000 | $350K | $270K |
| Olympian Laurel | 17,000 | $440K | $365K |
| Viking Rune | 25,000 | $490K | $490K |
| Samurai Ball | 38,000 | $630K | $660K |
| Knight's Ball | 57,000 | $960K | $890K |
| Sheriff Star | 85,000 | $1.15M | $1.2M |
| Clockwork Ball | 130,000 | $1.35M | $1.6M |
| Chrono Orb | 200,000 | $2.1M | $2.2M |

**World 3 Balls** (×1.5 a step, all above the Chrono Orb):

| Ball | × | Price | Before |
|---|---:|---:|---:|
| Solar Cell | 300,000 | $15M | $10M |
| Hover Ball | 450,000 | $16.5M | $13M |
| Hologram Ball | 675,000 | $22M | $17M |
| Robo Core | 1,000,000 | $24.5M | $22M |
| Bio Seed | 1,500,000 | $29M | $29M |
| Pixel Ball | 2,250,000 | $34M | $38M |
| Rocket Ball | 3,400,000 | $45M | $49M |
| Moon Rock | 5,000,000 | $56M | $64M |
| Red Planet | 7,500,000 | $76M | $83M |
| Singularity Orb | 11,000,000 | $97M | $108M |

**World 4 Balls** (×1.5 a step, all above the Singularity Orb). The design's starting prices
($500M to $5.4B) were for a World whose hits barely grew; with the reset and the Rolling Pin Bat
they rise ~1.1× a step:

| Ball | × | Price | Phase 1 | Design start |
|---|---:|---:|---:|---:|
| Dandelion Puff | 16,000,000 | $530M | $500M | $500M |
| Blueberry | 24,000,000 | $1.1B | $800M | $650M |
| Meatball | 36,000,000 | $1.2B | $1B | $850M |
| Bouncy Ball | 54,000,000 | $1.35B | $1.2B | $1.1B |
| Lucky Dice | 80,000,000 | $1.5B | $1.5B | $1.4B |
| Yarn Ball | 120,000,000 | $1.9B | $1.7B | $1.8B |
| Bath Bomb | 180,000,000 | $2.1B | $1.9B | $2.4B |
| Mini Globe | 270,000,000 | $2.3B | $2.1B | $3.1B |
| Cat's-Eye Marble | 400,000,000 | $2.55B | $2.3B | $4B |
| Dream Orb | 600,000,000 | $2.8B | $2.5B | $5.4B |

**Bats** (Cash ×1.5 a step; same identities, order and models; one shared series):

| Bat | Cash × | Price | Before |
|---|---:|---:|---:|
| Wood | 1 | free | |
| Metal | 1.5 | $25 | |
| Jungle | 2 | $120 | |
| Amethyst | 3 | $600 | |
| Candy Cane | 4 | $3,000 | |
| Frostbite | 6 | $15,000 | |
| Magma | 9 | $50,000 | |
| Lightning | 13 | $3.2M | $1.5M |
| Dragon Bone | 19 | $28M | $25M |
| Celestial | 28 | $100M | $120M |
| **Rolling Pin** (World 4) | 42 | $1.65B | new |

The Magma Bat was $300,000 (World 2's first Bat). At $50,000 it is World 1's last purchase: with
the LONG pace the Supernova Ball came 24 minutes before World 2 opened, with nothing left to buy;
the Magma Bat now lands in that gap (1h 32m, 9 minutes before World 2). One price, no new content;
Bat pedestals show the whole series in every hub.

**World 2's end gap** (63 minutes from the Chrono Orb to World 3) is closed by moving the
**Lightning Bat** to the end of World 2: at $3.2M it is bought after the last Ball. A Bat adds no
Power, so buying it later does not slow the World; the Clockwork Ball drops to $1.35M so the last
Balls still arrive on time without the Bat's Cash. Two prices; the longest World 2 wait is now
34 minutes (31 before World 3 opens), and World 3 opens 5 minutes earlier than before.

The **Rolling Pin Bat** (World 4's only new item besides its Balls) is bought midway through
World 4 (13h 51m). Placed among the last Balls instead it delayed the finale to 19h 41m and the
Dream Orb was never bought; midway its Cash shortens every wait after it.

## Cash

One formula for every World: `(start pay + multiplier × (distance / 80)^1.5) × section × Bat`
(× purchased Cash and juice). The 1.5 power makes farther hits worth more than their distance.
Hits start over in each World (see Distance per World), so each later World has a **start pay**
that makes even its first, shortest hits pay more than the previous World's farthest ones, and a
multiplier for the distance pay on top. The Bat multiplies both, so this holds with any Bat.

| World | Start pay | Multiplier | First hit (99 studs) | Last hit (its end) | Previous World's last hit | First vs that |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 0 | 1 | $1 | $667 | | |
| 2 | 3,000 | 7 | $3,010 | $10,188 | $667 | 4.5× |
| 3 | 40,000 | 60 | $40,082 | $120,297 | $10,188 | 3.9× |
| 4 | 500,000 | 600 | $500,824 | $1.49M | $120,297 | 4.2× |

Inside a World, Cash now grows about 3.4× from the first hit to the end (it grew only 1.1-1.3×
before the reset, when every World's hits started near its end). A plain multiplier alone would
need ×1,000 a World to beat the previous World's best with a 99-stud hit, putting World 4's end hits
past the Cash cap. Examples (Wood Bat, no multiplier):

| Hit | Distance | Cash |
|---|---:|---:|
| Level 1, World 1 | 81 | $1 |
| Level 40, World 1 | 347 | $10 |
| Level 100, World 1 | 2,053 | $176 |
| Level 150, World 1 (the end) | 5,000 | $667 |
| Level 150, World 2 (its start) | 146 | $3,017 |
| Level 200, World 2 | 3,005 | $6,226 |
| Level 250, World 2 (the end) | 6,000 | $10,188 |
| Level 250, World 3 (its start) | 146 | $40,148 |
| Level 310, World 3 | 3,515 | $77,593 |
| Level 370, World 3 (the end) | 7,000 | $120,297 |
| Level 370, World 4 (its start) | 146 | $501,475 |
| Level 430, World 4 | 4,048 | $966,548 |
| Level 490, World 4 (the end) | 8,000 | $1.49M |

## Affordability (active player)

When each item is bought, its gain over the equipped item, the hits batted since the previous
purchase, its price in hits at that moment, and for Bats the hits until the extra Cash repays it.

| Time | Item | Price | × | Gain | Hits since last | Price in hits | Bat payback |
|---|---|---:|---:|---:|---:|---:|---:|
| 3m 12s | Bubblegum Ball | $10 | 5 | 1.7 | 5 | 2 | |
| 5m 55s | Metal Bat | $25 | 1.5 | 1.5 | 4 | 2 | 5 |
| 7m 35s | Crystal Ball | $40 | 12 | 2.4 | 3 | 2 | |
| 9m 24s | Jungle Bat | $120 | 2 | 1.33 | 4 | 4 | 11 |
| 12m 17s | Frost Comet | $150 | 30 | 2.5 | 4 | 4 | |
| 15m 56s | Inferno Ball | $500 | 75 | 2.5 | 8 | 5 | |
| 18m 10s | Amethyst Bat | $600 | 3 | 1.5 | 6 | 5 | 11 |
| 23m 10s | Thunder Ball | $1,500 | 200 | 2.7 | 7 | 6 | |
| 27m 28s | Candy Cane Bat | $3,000 | 4 | 1.33 | 10 | 9 | 27 |
| 32m 56s | Galaxy Ball | $4,500 | 500 | 2.5 | 9 | 8 | |
| 46m 13s | Dragonfire Ball | $14,000 | 1,250 | 2.5 | 22 | 19 | |
| 58m 48s | Frostbite Bat | $15,000 | 6 | 1.5 | 16 | 17 | 33 |
| 1h 15m | Supernova Ball | $40,000 | 3,500 | 2.8 | 21 | 17 | |
| 1h 32m | Magma Bat | $50,000 | 9 | 1.5 | 19 | 15 | 30 |
| 1h 43m | Dino Egg | $175K | 5,000 | 1.43 | 16 | 6 | |
| 1h 46m | Stone Ball | $220K | 7,500 | 1.5 | 8 | 8 | |
| 1h 52m | Scarab Ball | $350K | 11,000 | 1.47 | 12 | 13 | |
| 1h 57m | Olympian Laurel | $440K | 17,000 | 1.55 | 15 | 13 | |
| 2h 05m | Viking Rune | $490K | 25,000 | 1.47 | 14 | 14 | |
| 2h 14m | Samurai Ball | $630K | 38,000 | 1.52 | 17 | 18 | |
| 2h 28m | Knight's Ball | $960K | 57,000 | 1.5 | 22 | 20 | |
| 2h 45m | Sheriff Star | $1.15M | 85,000 | 1.49 | 23 | 25 | |
| 3h 05m | Clockwork Ball | $1.35M | 130,000 | 1.53 | 25 | 22 | |
| 3h 33m | Chrono Orb | $2.1M | 200,000 | 1.54 | 35 | 31 | |
| 4h 07m | Lightning Bat | $3.2M | 13 | 1.44 | 45 | 48 | 107 |
| 4h 47m | Solar Cell | $15M | 300,000 | 1.5 | 56 | 28 | |
| 4h 59m | Hover Ball | $16.5M | 450,000 | 1.5 | 32 | 32 | |
| 5h 13m | Hologram Ball | $22M | 675,000 | 1.5 | 42 | 41 | |
| 5h 33m | Robo Core | $24.5M | 1,000,000 | 1.48 | 38 | 36 | |
| 5h 55m | Dragon Bone Bat | $28M | 19 | 1.46 | 46 | 42 | 90 |
| 6h 10m | Bio Seed | $29M | 1,500,000 | 1.5 | 28 | 23 | |
| 6h 28m | Pixel Ball | $34M | 2,250,000 | 1.5 | 26 | 26 | |
| 6h 53m | Rocket Ball | $45M | 3,400,000 | 1.51 | 42 | 35 | |
| 7h 26m | Moon Rock | $56M | 5,000,000 | 1.47 | 39 | 37 | |
| 8h 06m | Red Planet | $76M | 7,500,000 | 1.5 | 53 | 48 | |
| 8h 52m | Singularity Orb | $97M | 11,000,000 | 1.47 | 62 | 56 | |
| 9h 40m | Celestial Bat | $100M | 28 | 1.47 | 56 | 54 | 114 |
| 10h 29m | Dandelion Puff | $530M | 16M | 1.45 | 66 | 38 | |
| 10h 52m | Blueberry | $1.1B | 24M | 1.5 | 78 | 78 | |
| 11h 28m | Meatball | $1.2B | 36M | 1.5 | 72 | 66 | |
| 12h 06m | Bouncy Ball | $1.35B | 54M | 1.5 | 82 | 73 | |
| 12h 53m | Lucky Dice | $1.5B | 80M | 1.48 | 74 | 89 | |
| 13h 48m | Rolling Pin Bat | $1.65B | 42 | 1.5 | 72 | 62 | 124 |
| 14h 18m | Yarn Ball | $1.9B | 120M | 1.5 | 46 | 45 | |
| 15h 00m | Bath Bomb | $2.1B | 180M | 1.5 | 60 | 52 | |
| 15h 43m | Mini Globe | $2.3B | 270M | 1.5 | 51 | 47 | |
| 16h 33m | Cat's-Eye Marble | $2.55B | 400M | 1.48 | 59 | 52 | |
| 17h 23m | Dream Orb | $2.8B | 600M | 1.5 | 57 | 64 | |

"Price in hits" swings more than before because Cash per hit now depends on where in its World's
range the Level is (low at the start of each run). The longest waits with nothing to buy (from the
previous purchase, or from the World's last purchase to its end):

| World | Longest wait | Last purchase → World's end |
|---|---|---|
| 1 | 17 min (Frostbite → Supernova) | 9 min |
| 2 | 34 min (Chrono Orb → Lightning Bat); was 63 | 31 min |
| 3 | 48 min (Singularity Orb → Celestial Bat); was 61 | 35 min |
| 4 | 55 min (Lucky Dice → Rolling Pin Bat); was 67 | 40 min |

## Results: progression (active player, LONG)

| Milestone | Time | Rebirth / Level |
|---|---|---|
| First Rebirth (end of the tutorial) | 1m 44s | 0 → 1 at Level 20 |
| Second Rebirth | 4m 26s (Training only: 4m 43s) | 1 → 2 at Level 40 |
| World 2 unlock (World 1's end, 5,000) | 1h 41m | Rebirth 7, Level 150 |
| World 3 unlock (World 2's end, 6,000) | 4h 38m (4h 44m before the reset) | Rebirth 12, Level 250 |
| World 4 unlock (World 3's end, 7,000) | 10h 15m (10h 27m) | Rebirth 18, Level 370 |
| Finale (World 4's end, 8,000) | 18h 03m (18h 28m) | Rebirth 24, Level 490 |

Run lengths (Rebirth k → k+1): 2.7, 6.4, 12.7, 11.3, 20.3, 22.3, 31.5, 20.5, 31.8, 31.7, 42.5,
56.1, 47.0, 53.5, 59.2, 50.0, 60.0, 64.8, 68.2, 68.5, 99.1, 83.4, 83.1, 70.8 minutes for runs
1-24 (target 3 + 4 × (k − 1)); run 8 is short because World 2's first ground and Balls arrive with
it. Re-solving World 4's bands with the reset in place did not bring its runs closer to the
targets (the smoothing evens bands across runs) and moved the finale 10 minutes earlier, so
Phase 1's bands are kept. After the finale nothing new is bought, so run 25 takes 119 minutes.
Over the playthrough batting gives well under 0.1% of the Power.

**Training only** (no Cash, so no new Balls): runs take 3.0, 12.0, 139 and 563 minutes, then days.
Cash comes only from batting, so a player who never bats stalls after about Rebirth 3.

**Casual returning** (30 minutes a day): World 2 on day 4 (1h 35m of play), World 3 on day 8
(3h 42m), World 4 on day 16 (8h 06m), the finale on day 28 (14h 02m of play). Offline Training
gives 61% of their Power.

**Before** (the flat Training base on the MEDIUM bands): tutorial 4m 36s (226 s of Training for
the Level 20 climb), Training-only run 1 17.7 min, World 2 2h 31m, World 3 6h 27m, finale 12h 42m;
casual World 2 day 5, World 3 day 10, finale day 19.

## Pacing options

Run k of an active player is solved to take `3 + slope × (k − 1)` minutes. **LONG is chosen**; to
switch, run `solveBands` with the pace and paste its bands. (The FAST and MEDIUM rows are from
the earlier Training base, before it was flat, so only their order of size still holds.)

| Pace | Slope | World 2 unlock | World 3 unlock | Finale |
|---|---:|---|---|---|
| FAST | 1 min | 41m | 1h 38m | 3h 28m |
| MEDIUM | 2 min | 1h 04m | 2h 48m | 5h 53m |
| **LONG** (chosen) | 4 min | 1h 41m | 4h 38m | 10h 15m (World 4 unlock; the finale is now 18h 03m) |

## Purchased multipliers (Robux)

Two permanent ladders (`MonetizationConfig.Multipliers`), each tier its own developer product,
bought in order. Both start at 2x and add 0.5x a tier: Power 2x-4x (5 tiers), Cash 2x-5x (7
tiers). The ladders are intentionally stronger than the spender targets (one tier of each about
30-35% faster, every tier no sooner than half of free-to-play); see Decisions to review. World 4
was balanced with them in place: its bands are solved for the free player, so spenders keep the
same share of time saved.

Finale = World 4's end:

| Tier | Power | Robux | Finale with only this Power tier | Cash | Robux | Finale with only this Cash tier |
|---|---|---:|---|---|---:|---|
| 1 | 2x | 129 | 14h 14m (−3h 49m) | 2x | 129 | 12h 39m (−5h 23m) |
| 2 | 2.5x | 169 | 13h 15m (−58m) | 2.5x | 159 | 11h 33m (−1h 06m) |
| 3 | 3x | 219 | 12h 38m (−37m) | 3x | 199 | 10h 41m (−52m) |
| 4 | 3.5x | 279 | 11h 54m (−44m) | 3.5x | 249 | 10h 12m (−29m) |
| 5 | 4x | 359 | 11h 24m (−30m) | 4x | 309 | 9h 49m (−23m) |
| 6 | | | | 4.5x | 389 | 9h 20m (−29m) |
| 7 | | | | 5x | 489 | 9h 04m (−16m) |
| All | | 1,155 | | | 1,923 | |

Prices are unchanged from the earlier 1.5x-2.1x ladders: both start at 129, Power rises ~30% a
tier and Cash ~25%. Cash tiers are worth more than Power tiers: Balls gate the pace, and Cash buys
them.

| Player | World 2 | World 3 | World 4 | Finale | vs free-to-play | Casual (World 2 / 3 / 4 / finale) |
|---|---|---|---|---|---|---|
| Free to play | 1h 41m | 4h 38m | 10h 15m | 18h 03m | | day 4 / 8 / 16 / 28 |
| Dragon's Lair only (1,000 Robux pass) | 1h 31m | 4h 25m | 9h 56m | 17h 38m | 2% faster | not run |
| Light, 1 tier each (258 Robux) | 53m | 2h 23m | 5h 14m | 9h 15m | 49% faster | day 2 / 5 / 10 / 16 |
| Light, 2 tiers each (586 Robux) | 44m | 1h 58m | 4h 16m | 7h 30m | 58% faster | day 2 / 4 / 8 / 14 |
| Heavy, every tier (3,078 Robux) | 29m | 1h 12m | 2h 32m | 4h 18m | 76% faster | day 1 / 3 / 5 / 8 |
| Both passes + every tier (4,578 Robux) | 27m | 1h 08m | 2h 27m | 4h 08m | 77% faster | not run |
| Heavy + both juices nonstop | 18m | 41m | 1h 24m | 2h 20m | 87% faster | day 1 / 2 / 3 / 5 |
| Whale (+ Starter Pack, both paid grounds) | 16m | 40m | 1h 22m | 2h 18m | 87% faster | day 1 / 2 / 3 / 5 |

**Dragon's Lair by World (Nov 2026).** It was 30x in every World; it now follows the World
(15 / 45 / 150 / 500x). The same simulator run with the old and new values (everything else
unchanged; free-to-play, casual and offline results identical):

| Player | Before (30x everywhere): World 2 / 3 / 4 / finale | After (by World) |
|---|---|---|
| Dragon's Lair only | 1h 13m / 4h 10m / 9h 47m / 17h 35m (3% faster) | 1h 31m / 4h 25m / 9h 56m / 17h 38m (2% faster) |
| Both passes + every tier | 22m / 1h 05m / 2h 24m / 4h 10m | 27m / 1h 08m / 2h 27m / 4h 08m |
| Whale | 16m / 38m / 1h 22m / 2h 17m | 16m / 40m / 1h 22m / 2h 18m |

At 30x it was by far World 1's best cage (Sky Temple is 20x), so a Dragon's Lair owner reached
World 2 28 minutes sooner; at 15x it saves 10. Later it helps more than before (45 / 150 / 500x
against 30x), which is why the finale barely moves. Either way the pass alone saves little at the
finale: Balls gate the pace, and Cash buys them, so faster Power mostly waits on Cash.

Worst case (every tier and both juices): 4 × 2 = 8x Power and 5 × 2 = 10x Cash. At World 4's
finale gear that is ~3.5e14 Power a practice hit (5 × 580 × 600M × 25 × 8) and ~$620M a hit at
8,000 studs with the Rolling Pin Bat, below `MaxPower` (9e15) and far below Cash's 9e12 limit. Offline gets the
Power tier but no juice, and the run cap (applied after every multiplier) still holds. The Power
products and the Starter Pack's Power are never multiplied.

## Batting vs Training

Power a minute from batting (with the time between hits) against Training at the same Level,
Ball and Rebirths:

| Level | Hit | vs Basic Training | vs the best ground then |
|---:|---:|---:|---|
| 1 | 99 studs (sim; ~81-92 in Studio) | 50% | 50% (Basic) |
| 3 | 102 | 49% | 49% (Basic) |
| 20 | 143 | 52% | 52% (Basic) |
| 40 | 347 | 61% | 61% (Basic) |
| 80 | 1,363 | 61% | 12% (Enchanted Grove) |
| 140 | 3,906 | 69% | 3.4% (Sky Temple) |
| 150 | 146 (World 2's start) | 52% | 2.1% (Caveman Camp) |
| 250 | 146 (World 3's start) | 52% | 0.6% (Solar Rooftop) |
| 370 | 146 (World 4's start) | 52% | 0.2% (Sandbox Diamond) |
| 430 | 4,048 | 66% | 0.2% (Pinball Cage) |
| 490 | 8,000 | 68% | 0.1% (Toy Soldier Fort) |

Batting never uses the ground (design), so once better grounds open it is a Cash activity; over a
whole active playthrough it gives well under 1% of the Power. Batting Power is already "periodic":
it is paid per second the ball is in play.

## Offline Training

A return earns 25% of the best usable ground's Training rate for the time away (8 h at most),
then the **run cap** holds it to half the Power the player still needs for their Level Cap,
measured at login (`TrainingConfig.OfflineRunShare` 0.5):

`granted = min(time-based reward, floor(0.5 × Power left to the Level Cap))`

Welcome Back's 3x claim adds the granted reward twice more, up to all of the Power left
(`OfflineTriple.runShare` 1), and never past the Level Cap at the moment it is claimed:

`3x total = min(3 × granted, Power left to the Level Cap)`

So a normal return never reaches the Level Cap, repeated returns take half of what is left each
time (50%, 75%, 87.5%, ...), and a return at the cap adds nothing and offers no 3x (Power still
banks there from Training). The 3x can finish the run but never makes a Rebirth automatic.

Share of the run left, granted / with the 3x (best free ground, the Ball the active player has in
that run; "Training" is the active Training time from there, at the same ground and Ball):

Logged out at the first Level of the run's new band (Power 0):

| Rebirths (Ball, ground) | Run left (Training) | 15 min | 1 h | 4 h | 8 h | 8 h is worth |
|---|---|---:|---:|---:|---:|---:|
| 1 (Bubblegum, Basic) | 2.18K (1.5 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 0.7 min |
| 3 (Thunder, Grove) | 1.17M (2.0 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 1.0 min |
| 6 (Supernova, Sky Temple) | 316M (4.3 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 2.2 min |
| 9 (Knight's Ball, Pharaoh's Tomb) | 34B (11.4 min) | 33 / 99% | 50 / 100% | 50 / 100% | 50 / 100% | 5.7 min |
| 12 (Solar Cell, Solar Rooftop) | 632B (12.0 min) | 31 / 94% | 50 / 100% | 50 / 100% | 50 / 100% | 6.0 min |
| 15 (Moon Rock, Robo Factory) | 20.2T (14.0 min) | 27 / 80% | 50 / 100% | 50 / 100% | 50 / 100% | 7.0 min |
| 18 (Singularity Orb, Sandbox Diamond) | 119T (14.1 min) | 27 / 80% | 50 / 100% | 50 / 100% | 50 / 100% | 7.0 min |
| 21 (Yarn Ball, Pinball Cage) | 3.16Qa (22.8 min) | 16 / 49% | 50 / 100% | 50 / 100% | 50 / 100% | 11.4 min |
| 24 (Dream Orb, Toy Soldier Fort) | 22.8Qa (17.5 min) | 21 / 64% | 50 / 100% | 50 / 100% | 50 / 100% | 8.8 min |

Logged out at Level 1, just after the Rebirth (Training base 5, so the time-based reward is small):

| Rebirths | Run left (Training) | 15 min | 1 h | 4 h | 8 h | 8 h is worth |
|---|---|---:|---:|---:|---:|---:|
| 1 | 2.62K (1.8 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 0.9 min |
| 3 | 1.25M (2.1 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 1.1 min |
| 6 | 406M (5.5 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 2.8 min |
| 9 | 43.3B (14.5 min) | 26 / 78% | 50 / 100% | 50 / 100% | 50 / 100% | 7.2 min |
| 12 | 991B (18.8 min) | 20 / 60% | 50 / 100% | 50 / 100% | 50 / 100% | 9.4 min |
| 15 | 30.8T (21.4 min) | 18 / 53% | 50 / 100% | 50 / 100% | 50 / 100% | 10.7 min |
| 18 | 252T (29.8 min) | 13 / 38% | 50 / 100% | 50 / 100% | 50 / 100% | 14.9 min |
| 21 | 5.16Qa (37.2 min) | 10 / 30% | 40 / 100% | 50 / 100% | 50 / 100% | 18.6 min |
| 24 | 47Qa (36.0 min) | 10 / 31% | 42 / 100% | 50 / 100% | 50 / 100% | 18.0 min |

The run cap binds within the first hour away almost everywhere, so longer absences add nothing
more; the 8-hour limit never binds. (Rebirth 18's rows changed because World 4 now opens in that
run: its best ground is the Sandbox Diamond.)

Late in World 4 a single offline grant (and the 3x) can be bigger than `MaxPower` (an 8-hour
return at Rebirth 24, Level 1 grants ~2.3e16). `Progression.Advance` adds such a grant in pieces
that each fit, levelling up between them, so none of it is lost before the Level Cap; Power itself
never passes `MaxPower`. (Before World 4 it clamped the whole grant to `MaxPower` first, which no
earlier World's grants reached.)

## Hit physics and the launch table

Distance comes from Roblox physics (flight, bounces, roll), and it is erratic in launch speed at
every speed (measured 2026-11-04: a sweep of every 2 studs/s from 80 to 504, each Level's speed
re-hit, about 380 hits; `tools/balance/HitMeasurements` sweep). The bounces make a sawtooth:
along a run of speeds distance falls (110 → 304, 112 → 286, 114 → 265, 116 → 255), then jumps
(118 → 354), so a smooth interpolation between a few measured speeds is wrong between them (the
old table's Levels landed anywhere from 30% short to 70% long of their model). Below about 200
studs/s the same speed also varies from hit to hit (up to ~40%: 90 landed 153 and 210); above it
a speed usually repeats within ~3% in one session, but not always (322: 1,167 and 1,309), and
once differed between sessions (336: 1,324 in one playtest, 1,482 / 1,502 in the next). The ball
launches identically every time (anchored on the tee, the same CFrame and velocity), so the spread
comes from the bounces and the per-frame rolling force, not the launch.

So from Level 22 each Level uses its own measured speed (LaunchSpeedSteps), chosen for where it
lands (distanceShape {0.05, 0, 100} + measuredSteps): the curve grows 5% a Level from Level 21
(~146 studs), easing linearly to 1.65% at Level 100, then 1.65% a Level to Level 140 (3,906
studs), and each Level takes the measured speed whose average lands nearest the curve (within
3.5%, preferring speeds whose two hits agree within 6%; within 6% where nothing closer exists),
always farther than the Level before. Levels 24, 29, 134 and 137-139 had no measured speed there
and repeat the Level before. Levels 1-21 (the early launch curve) are unchanged.

| Level | 30 | 40 | 50 | 60 | 70 | 80 | 90 | 100 | 110 | 120 | 130 | 140 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Before (model) | 183 | 237 | 319 | 421 | 556 | 738 | 957 | 1,284 | 1,684 | 2,242 | 2,954 | 3,906 |
| Before (Studio, the old speeds) | | | | 370 | | 861 | 1,148 | | | | | 3,928 |
| Curve | 225 | 349 | 520 | 742 | 1,015 | 1,332 | 1,674 | 2,017 | 2,380 | 2,807 | 3,311 | 3,906 |
| Now (measured average of that Level's speed) | 228 | 347 | 516 | 755 | 1,002 | 1,363 | 1,677 | 2,053 | 2,347 | 2,789 | 3,397 | 3,906 |

Individual hits still spread around these: about ±20-40% below Level ~55 (speeds under 200), and
usually within a few percent above it. Launch speed is not shown anywhere, so speeds that are not
in rising order are invisible; only the distance shows. The points in HitMeasurements are the
average trend (every hit within 5% of each speed), used only where no measured speed exists.

Above 505 the bounces make distance jump around from one speed to the next (640 → 4,310,
641 → 3,395, 649 → 7,000, 650 → 5,959, 695 → 5,586); the same speed repeats within about 1%, and
lands the same in every World (World 1, 2 and 3 checked). So from Level 141 each Level uses a
speed measured at least twice (`LaunchSpeedSteps`), chosen so distance rises in steps. By launch
Level (World 1 uses these with the player's Level; later Worlds through their launch Levels):

| Levels | Distance |
|---|---|
| 141-149 | ~4,050 → 4,770 (World 1, short of its 5,000 end) |
| 150-249 | ~5,100 → 5,820 (past World 1's end, short of World 2's 6,000) |
| 250-369 | ~6,140 → 6,820 (past World 2's end, short of World 3's 7,000) |
| 370-398 | 7,195 (speed 716, which reaches every earlier World's end) |
| 399-489 | ~7,380 → 7,955, in 8 steps (399, 406, 420, 435, 446, 457, 462, 483) |
| 490+ | reaches 8,000, World 4's end (speed 717) |

The ~2% margins around each end cover the trial-to-trial spread. Launch speed is not shown
anywhere, so speeds that are not in rising order are invisible; only the distance shows.

**World 4 (2026-11-05):** hits past 7,000 had never been measured, because World 3's end portal
captured them at 7,000. A sweep in World 4's field (end 8,000) of the capped speeds and every 2
from 722 to 800, then the useful speeds re-hit twice and 13 odd speeds (about 100 hits;
`HitMeasurements.far`), shows the same sawtooth (716 → 7,195, 722 → 6,295, 724 → 4,965) and
repeats within ~1%. The global table (launch Levels 371-490) rises evenly in proportion from
7,195 to 8,000. No measured speed lands between 7,195 and 7,365 or between 7,805 and 7,940. The
simulator uses these hits in place of the capped ones (and adds them to older uncapped trials).

The table above is the **global launch table**: World 1 uses it with the player's Level; the later
Worlds use it through their launch Levels (below), so every hit still uses a measured speed.

### Distance per World

Hits start over in each later World (WorldConfig `launchLevels`, ProgressionConfig
`GetWorldLaunchLevel` and `WorldLaunchSteps`, built by the simulator's `designWorldLaunch`):

| World | Levels (from → to) | Below `from` | From `from` to `to` |
|---|---|---|---|
| 1 | | the player's Level | |
| 2 | 150 → 250 | the early floaty arc (launch Levels 1-21: 99 → 143 studs), spread over the run's cheap Levels | 146 studs rising evenly to 6,000 at Level 250 |
| 3 | 250 → 370 | the same | 146 → 7,000 at Level 370 |
| 4 | 370 → 490 | the same | 146 → 8,000 at Level 490 |

`from` is the Level where the World opens (the previous World's end), `to` the Level where its
own end is reached, so World unlocks still happen at the same Levels and Rebirths. Each Level from
`from` takes the highest launch Level whose measured distance does not pass its even-in-studs
target (so the end is reached exactly at `to`), and `to` the first that reaches the end. The
server picks the launch Level at swing acceptance from the player's Level and the World they bat
in; in an earlier World a later player is past its `to`, so every hit reaches its end, at that
World's lower pay. Studio's `StudioLaunchLevel` goes through the same lookup.

Where each run's hits land (its top 20 Levels, where most of a run's time goes; the simulator's
WORLD DISTANCES section):

| World | Run | Lands in |
|---|---|---|
| 2 | 7 (arrival) | Prehistoric Valley → Stone Age Camp |
| 2 | 8 / 9 / 10 / 11 | Stone Age → Olympian Heights / → Samurai Gardens / → Frontier Town / → Chrono Nexus |
| 2 | 12 | Chrono Nexus → the end |
| 3 | 12 (arrival) | Solar Suburbs → Maglev Highway |
| 3 | 13 / 14 / 15 / 16 / 17 | Maglev → Skyline Metropolis / → Biodome Gardens / → Virtual Grid / → Lunar Colony / → Quantum Singularity |
| 3 | 18 | Quantum Singularity → the end |
| 4 | 18 (arrival) | Giant Backyard → Picnic Blanket |
| 4 | 19 / 20 / 21 / 22 / 23 | Picnic → Kitchen Counter / → Board Game Boulevard / → Bathtub Bay / → Attic Treasures / → Pillow Fort |
| 4 | 24 | Pillow Fort → the end |

Each run also starts in section 1 with the floaty arc. In World 4's first full run (Rebirth 19)
about a quarter of the Power goes into Levels below 370 (the early arc); 9% in the next run, 3% in
the one after, under 1% from then on. With a rule that depends only on Level and World, that
stretch cannot be shortened without the arrival hit no longer starting over (see Decisions to
review).

## Decisions to review

- **Hits start over in each World** (World 2, 3 and 4; World 1 unchanged). This changed an
  established rule: launch strength now comes from the Level *and the World you bat in*, not Level
  alone. Each World's start pay keeps a new World's shortest hit worth 3.9-4.5× the previous World's
  best, so the reset never lowers Cash.
- **World 4's first full run** (Rebirth 19) spends about a quarter of its Power at Levels below 370,
  hitting the 99-143-stud early arc before its hits start growing (9% in the next run, then under
  3%). Not shortened: any rule on Level and World alone that starts the arrival hit over (at Level
  370) must keep every lower Level at or below that start. Shortening it would need the Rebirth
  count in the distance rule, or cheaper Levels 300-369 (World 3's top bands, moving World 3).
- **The multiplier ladders are intentionally stronger than the spender targets** (2x-4x Power,
  2x-5x Cash, +0.5x a tier). One tier of each finishes 49% faster (target 30-35%) and every tier
  76% faster (floor: half of free-to-play): 4h 18m against free-to-play's 18h 03m. The shares hold
  with World 4 in, because the bands are solved for the free player and the multipliers scale
  every World alike. Bringing spenders back to the targets would need smaller ladders.
- **World 3's last wait** (Singularity Orb, then the Celestial Bat 61 minutes later) is closed by
  two price cuts: the Singularity Orb $113M → $97M and the Celestial Bat $130M → $100M (still just
  above the Orb, so bought after it). Its last purchases now come 40, 46 and 48 minutes apart, then
  35 minutes before World 4; World 4 opens 2 minutes and the finale 6 minutes earlier.
- **World 4's waits** are 23-55 minutes (was up to 67); the World lasts 8 hours with 11 purchases,
  so its average wait is ~44 minutes. Its runs (68-99 minutes) wander around the LONG targets
  (75-95); re-solving the bands did not tighten them.
- **`MaxPower` is close:** requirements reach it (9 quadrillion) at about Level 555 (Rebirth 27,
  three runs past World 4's end); World 5 needs a bigger Power scale (or slower band growth). See
  `WORLD4_DESIGN.md` Known issues.
- **The casual finale is day 28** (about 4 weeks; 14h 02m of play), and Offline Training gives
  61% of a casual player's Power.
- **Juices are the strongest Robux lever:** both running nonstop on top of every tier take the
  finale from 4h 18m to 2h 20m. They are consumables (39 Robux for 10 minutes), so that would
  cost far more than the tiers; revisit if juices get cheaper or longer.
- **The Magma Bat** used to be World 2's first Bat (the ×20 price jump from Frostbite followed the
  World Cash tiers); now the big jump sits between Magma ($50K) and Lightning ($3.2M, bought last
  in World 2).
- **Starter Pack / +10K Power** reach the Level Cap of an early run on their own (the first bands
  are much smaller now), so a buyer mid-tutorial goes straight to its Rebirth step.
- **After the finale** nothing new is bought and bands keep growing 1.8×, so runs grow fast (119
  min for run 25).
- **Training-only stalls** after about Rebirth 3: Balls cost Cash and only batting earns it.
- **Batting gives almost no Power** past the first grounds, by the no-ground rule.
- **Paid grounds:** Dragon's Lair follows the World (15 / 45 / 150 / 500x): a little above the
  World's premium ground and below its top Rebirth ground (Sky Temple 20x, Samurai Dojo 70x, Lunar
  Base 210x, Toy Soldier Fort 580x), so it leads only until that ground opens. The shared-pass
  grounds sit below each World's top Rebirth ground. The pass alone saves about 2% at the finale.
- **New-World bursts:** a World's first Ball costs 6-38 hits right after the World opens (its
  start pay is a big step up).
- **Offline run cap:** a return fills at most half the run left (the 3x up to all of it), so
  8 hours away is worth about 1-19 minutes of active Training. Raise `OfflineRunShare` if returns
  feel stingy; the cap, not the 8-hour limit, is what binds now.
- **Hit distance is noisy** (see Hit physics): every launch Level has a measured speed, but the
  early arc (speeds under ~200), which now also opens every World and every run, varies from hit
  to hit (up to ~40%), and the measurements come from one Studio session (a speed can land
  differently on another server). Making hits deterministic (the rolling force is updated per
  frame) would be a physics change of its own. Re-measure a few Levels on a live server before
  final balance.

## Re-tuning

1. Change config values; run the simulator report and compare with the targets above.
2. Bands: `mode = "solveBands"` with the pace, paste the result into `LevelBands`; the tutorial
   band with `solveTutorial`. For a new World, `keepBands` keeps the bands before it (World 4:
   `bands = 25, keepBands = 18`).
3. Distance: `distanceShape` + `measuredSteps` print the `LaunchSpeedSteps` for Levels 22-140 (from the
   sweep) and the `ExpectedHitDistances` head to paste. Per World: `designWorldLaunch = true` prints
   `WorldLaunchSteps` for every World with `launchLevels` (re-run after any change to the launch
   table or a World's range).
4. After any change to hit physics, the runway or `HitTimeScale`: re-measure (README), then
   `mode = "designSpeed"` and paste `LaunchSpeedTable` / `LaunchSpeedSteps`.
5. Multipliers: the report's SPENDERS section (and `tierValues`, `casualSpenders`) checks the
   light-spender and heavy-spender targets.
6. Refresh `tools/balance/output/*.csv`, the tests' expected values, and this file.
