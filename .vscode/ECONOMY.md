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
Power by Rebirths + 1, and **Level alone** sets the launch (and so the distance). The **purchased
multipliers** (Robux, permanent tiers) multiply Power gain and batting Cash, never the distance.

- **Level requirement:** in bands. Levels 1-19 need `10 + 1.5 × (Level − 1)`, rounded down (10,
  11, 13, 14, ... 37; 442 in all). From Level 20 each Rebirth's 20 new Levels are one band: the
  band's first Level needs `start`, and each Level after it 1.02× the one before (the band's last
  Level needs ~1.46× its first). Past Level 419 each band starts 1.8× above the one before.
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
- **Hit Cash** = `(distance / 80)^1.5` × World (1, 10, 100) × section (1, 1.15, 1.35) × Bat ×
  purchased Cash × Cash juice, rounded, at least $1. An early hit (80-100 studs) pays $1.
- **Distance:** Level → launch speed (`LaunchSpeedTable` to Level 140, then `LaunchSpeedSteps`),
  built from measured hits (see Hit physics below).

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
| Free-to-play World 2 / World 3 / finale | ~1h 40m / ~4h 45m / ~10h 30m | 1h 41m / 4h 44m / 10h 27m | |
| One tier of each multiplier | 30-35% faster finale | 49% (5h 19m): stronger on purpose, see Decisions to review | |
| Every tier | finale no sooner than half of free-to-play (~5h 15m) | 2h 33m (76% faster): stronger on purpose | |

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
| 380-399 | 8.9T | 216T | ×1.2 |
| 400-419 | 16T | 389T | ×1.2 |
| 420+ | ×1.8 a band | | |

The big steps at Levels 40 and 60 are the second and third runs' bands: from run 2 the active
player has the Enchanted Grove (5x), better Balls and two Rebirths, many times run 1's Power rate.

**Existing saves** keep their Level and Power: every load re-runs the save through the current
bands (`Progression.Normalize` → `Advance(state, 0)`), so Power above a now-smaller requirement
levels the player up at once (up to the Level Cap, where the rest banks), and where a requirement
grew the player just needs a little more for their next Level. Nothing is taken away and no save
field migrates for a band change.

## Training Grounds

Unchanged by this pass (multipliers and gates already rise in order). Power a practice hit at any
Level, before Ball, Rebirth and purchased multiplier:

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
| Dragon's Lair | every | 1000 R$ pass | 30 | 150 |

Free-to-play never needs a paid ground. Game-pass ids stay 0 until the passes are created.

## Equipment

**World 1 Balls** (the fixed anchors): Baseball 1x free, Sandlot 3x $2, Bubblegum 5x $10,
Crystal 12x $40, Frost Comet 30x $150, Inferno 75x $500, Thunder 200x $1,500, Galaxy 500x $4,500,
Dragonfire 1,250x $14,000, Supernova 3,500x $40,000.

**World 2 Balls** (×1.5 a step, all above the Supernova; priced for World 2's ×10 Cash):

| Ball | × | Price |
|---|---:|---:|
| Dino Egg | 5,000 | $150K |
| Stone Ball | 7,500 | $200K |
| Scarab Ball | 11,000 | $270K |
| Olympian Laurel | 17,000 | $365K |
| Viking Rune | 25,000 | $490K |
| Samurai Ball | 38,000 | $660K |
| Knight's Ball | 57,000 | $890K |
| Sheriff Star | 85,000 | $1.2M |
| Clockwork Ball | 130,000 | $1.6M |
| Chrono Orb | 200,000 | $2.2M |

**World 3 Balls** (×1.5 a step, all above the Chrono Orb; priced for World 3's ×100 Cash):

| Ball | × | Price |
|---|---:|---:|
| Solar Cell | 300,000 | $10M |
| Hover Ball | 450,000 | $13M |
| Hologram Ball | 675,000 | $17M |
| Robo Core | 1,000,000 | $22M |
| Bio Seed | 1,500,000 | $29M |
| Pixel Ball | 2,250,000 | $38M |
| Rocket Ball | 3,400,000 | $49M |
| Moon Rock | 5,000,000 | $64M |
| Red Planet | 7,500,000 | $83M |
| Singularity Orb | 11,000,000 | $108M |

**Bats** (Cash ×1.5 a step; same identities, order and models):

| Bat | Cash × | Price |
|---|---:|---:|
| Wood | 1 | free |
| Metal | 1.5 | $25 |
| Jungle | 2 | $120 |
| Amethyst | 3 | $600 |
| Candy Cane | 4 | $3,000 |
| Frostbite | 6 | $15,000 |
| Magma | 9 | $50,000 |
| Lightning | 13 | $1.5M |
| Dragon Bone | 19 | $25M |
| Celestial | 28 | $120M |

The Magma Bat was $300,000 (World 2's first Bat). At $50,000 it is World 1's last purchase: with
the LONG pace the Supernova Ball came 24 minutes before World 2 opened, with nothing left to buy;
the Magma Bat now lands in that gap (1h 32m, 9 minutes before World 2). One price, no new content;
Bat pedestals show the whole series in every hub.

## Cash

One formula for every World: `(distance / 80)^1.5 × World × section × Bat` (× purchased Cash and
juice). The 1.5 power makes farther hits worth more than their distance; the World multiplier
(1, 10, 100) lets each World's prices sit a tier above the last without changing the formula.
Examples (Wood Bat, no multiplier):

| Hit | Distance | Cash |
|---|---:|---:|
| Level 1, World 1 | 81 | $1 |
| Level 20, World 1 | 143 | $2 |
| Level 40, World 1 | 347 | $10 |
| Level 60, World 1 | 755 | $33 |
| Level 80, World 1 | 1,363 | $95 |
| Level 100, World 1 | 2,053 | $176 |
| Level 140, World 1 | 3,906 | $461 |
| Level 150, World 2 | 5,104 | ~$6,900 |
| Level 250, World 3 | 6,136 | ~$91,000 |
| Level 370, World 3 (the end) | 7,000 | ~$110,000 |

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
| 1h 43m | Dino Egg | $150K | 5,000 | 1.43 | 13 | 2 | |
| 1h 46m | Stone Ball | $200K | 7,500 | 1.5 | 3 | 3 | |
| 1h 51m | Scarab Ball | $270K | 11,000 | 1.47 | 5 | 7 | |
| 1h 57m | Olympian Laurel | $365K | 17,000 | 1.55 | 6 | 6 | |
| 2h 04m | Viking Rune | $490K | 25,000 | 1.47 | 8 | 8 | |
| 2h 13m | Samurai Ball | $660K | 38,000 | 1.52 | 10 | 10 | |
| 2h 26m | Knight's Ball | $890K | 57,000 | 1.5 | 14 | 13 | |
| 2h 44m | Sheriff Star | $1.2M | 85,000 | 1.49 | 18 | 19 | |
| 3h 04m | Lightning Bat | $1.5M | 13 | 1.44 | 21 | 21 | 47 |
| 3h 20m | Clockwork Ball | $1.6M | 130,000 | 1.53 | 16 | 17 | |
| 3h 39m | Chrono Orb | $2.2M | 200,000 | 1.54 | 21 | 21 | |
| 4h 48m | Solar Cell | $10M | 300,000 | 1.5 | 72 | 8 | |
| 4h 58m | Hover Ball | $13M | 450,000 | 1.5 | 11 | 13 | |
| 5h 13m | Hologram Ball | $17M | 675,000 | 1.5 | 15 | 14 | |
| 5h 31m | Robo Core | $22M | 1,000,000 | 1.48 | 19 | 18 | |
| 5h 53m | Dragon Bone Bat | $25M | 19 | 1.46 | 21 | 20 | 44 |
| 6h 09m | Bio Seed | $29M | 1,500,000 | 1.5 | 16 | 16 | |
| 6h 28m | Pixel Ball | $38M | 2,250,000 | 1.5 | 20 | 20 | |
| 6h 54m | Rocket Ball | $49M | 3,400,000 | 1.51 | 27 | 26 | |
| 7h 27m | Moon Rock | $64M | 5,000,000 | 1.47 | 34 | 34 | |
| 8h 10m | Red Planet | $83M | 7,500,000 | 1.5 | 44 | 43 | |
| 9h 05m | Singularity Orb | $108M | 11,000,000 | 1.47 | 56 | 55 | |
| 10h 06m | Celestial Bat | $120M | 28 | 1.47 | 61 | 60 | 126 |

The Dino Egg and Solar Cell cost few hits because they are bought just after a new World raises
Cash ×10; everything else costs 2-60 hits, rising slowly through the game. The longest stretch
with nothing to buy is the end of World 2: the Chrono Orb at 3h 39m, then World 3 at 4h 44m
(72 hits, 65 minutes; see Decisions to review).

## Results: progression (active player, LONG)

| Milestone | Time | Rebirth / Level |
|---|---|---|
| First Rebirth (end of the tutorial) | 1m 44s | 0 → 1 at Level 20 |
| Second Rebirth | 4m 26s (Training only: 4m 43s) | 1 → 2 at Level 40 |
| World 2 unlock (World 1's end, 5,000) | 1h 41m | Rebirth 7, Level 150 |
| World 3 unlock (World 2's end, 6,000) | 4h 44m | Rebirth 12, Level 250 |
| Finale (World 3's end, 7,000) | 10h 27m | Rebirth 18, Level 370 |

Run lengths (Rebirth k → k+1): 2.7, 6.4, 12.7, 11.3, 20.3, 22.3, 31.8, 20.5, 32.2, 36.0, 43.0,
55.4, 45.0, 53.1, 60.5, 52.8, 64.6, 70.3 minutes for runs 1-18 (target 3 + 4 × (k − 1)); run 8
is short because World 2's first ground and Balls arrive with it. After the finale nothing new is
bought, so run 19 takes 123 minutes. Over the playthrough batting gives 0.2% of the Power.

**Training only** (no Cash, so no new Balls): runs take 3.0, 12.0, 139 and 563 minutes, then days.
Cash comes only from batting, so a player who never bats stalls after about Rebirth 3.

**Casual returning** (30 minutes a day): World 2 on day 4 (1h 35m of play), World 3 on day 9
(4h 09m), the finale on day 17 (8h 31m of play). Offline Training gives 44% of their Power.

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
| **LONG** (chosen) | 4 min | 1h 41m | 4h 44m | 10h 27m |

## Purchased multipliers (Robux)

Two permanent ladders (`MonetizationConfig.Multipliers`), each tier its own developer product,
bought in order. Both start at 2x and add 0.5x a tier: Power 2x-4x (5 tiers), Cash 2x-5x (7
tiers). The ladders are intentionally stronger than the spender targets below (one tier of each
about 30-35% faster, every tier no sooner than ~5h 15m) because a World 4 is planned; see
Decisions to review.

| Tier | Power | Robux | Finale with only this Power tier | Cash | Robux | Finale with only this Cash tier |
|---|---|---:|---|---|---:|---|
| 1 | 2x | 129 | 7h 47m (−2h 40m) | 2x | 129 | 7h 50m (−2h 36m) |
| 2 | 2.5x | 169 | 7h 08m (−39m) | 2.5x | 159 | 7h 18m (−32m) |
| 3 | 3x | 219 | 6h 40m (−28m) | 3x | 199 | 6h 52m (−26m) |
| 4 | 3.5x | 279 | 6h 17m (−23m) | 3.5x | 249 | 6h 40m (−13m) |
| 5 | 4x | 359 | 6h 01m (−15m) | 4x | 309 | 6h 25m (−14m) |
| 6 | | | | 4.5x | 389 | 6h 18m (−7m) |
| 7 | | | | 5x | 489 | 6h 11m (−8m) |
| All | | 1,155 | | | 1,923 | |

Prices are unchanged from the earlier 1.5x-2.1x ladders: both start at 129, Power rises ~30% a
tier and Cash ~25%.

| Player | World 2 | World 3 | Finale | vs free-to-play | Casual (World 2 / 3 / finale) |
|---|---|---|---|---|---|
| Free to play | 1h 41m | 4h 44m | 10h 27m | | day 4 / 9 / 17 |
| Light, 1 tier each (258 Robux) | 53m | 2h 27m | 5h 19m | 49% faster | day 2 / 5 / 10 |
| Light, 2 tiers each (586 Robux) | 44m | 1h 59m | 4h 17m | 59% faster | day 2 / 4 / 8 |
| Heavy, every tier (3,078 Robux) | 29m | 1h 13m | 2h 33m | 76% faster | day 1 / 3 / 5 |
| Heavy + both juices nonstop | 18m | 42m | 1h 24m | 87% faster | day 1 / 2 / 3 |
| Whale (+ Starter Pack, both paid grounds) | 16m | 39m | 1h 21m | 87% faster | day 1 / 2 / 3 |

Worst case (every tier and both juices): 4 × 2 = 8x Power and 5 × 2 = 10x Cash. At finale gear
that is ~1.8e12 Power a practice hit (5 × 210 × 11M × 19 × 8) and ~$31M a hit at 7,000 studs with
the Celestial Bat in World 3, far below `MaxPower` (9e15) and Cash's 9e12 limit. Offline gets the
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
| 150 | 5,104 | 68% | 2.7% (Caveman Camp) |
| 250 | 6,136 | 69% | 0.8% (Solar Rooftop) |
| 370 | 7,000 | 68% | 0.3% (Lunar Base) |

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
| 18 (Singularity Orb, Lunar Base) | 119T (18.1 min) | 21 / 62% | 50 / 100% | 50 / 100% | 50 / 100% | 9.1 min |

Logged out at Level 1, just after the Rebirth (Training base 5, so the time-based reward is small):

| Rebirths | Run left (Training) | 15 min | 1 h | 4 h | 8 h | 8 h is worth |
|---|---|---:|---:|---:|---:|---:|
| 1 | 2.62K (1.8 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 0.9 min |
| 3 | 1.25M (2.1 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 1.1 min |
| 6 | 406M (5.5 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 2.8 min |
| 9 | 43.3B (14.5 min) | 26 / 78% | 50 / 100% | 50 / 100% | 50 / 100% | 7.2 min |
| 12 | 991B (18.8 min) | 20 / 60% | 50 / 100% | 50 / 100% | 50 / 100% | 9.4 min |
| 15 | 30.8T (21.4 min) | 18 / 53% | 50 / 100% | 50 / 100% | 50 / 100% | 10.7 min |
| 18 | 252T (38.3 min) | 10 / 29% | 39 / 100% | 50 / 100% | 50 / 100% | 19.1 min |

The run cap binds within the first hour away almost everywhere, so longer absences add nothing
more; the 8-hour limit never binds.

## Hit physics and the launch table

Distance comes from Roblox physics (flight, bounces, roll), and it is erratic in launch speed at
every speed (measured 2026-11-04: a sweep of every 2 studs/s from 80 to 504, each Level's speed
re-hit, about 380 hits; 	ools/balance/HitMeasurements sweep). The bounces make a sawtooth:
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
speed measured at least twice (`LaunchSpeedSteps`), chosen so distance rises in steps and each
World's end is reached exactly at its Level:

| Levels | Distance |
|---|---|
| 141-149 | ~4,050 → 4,770 (World 1, short of its 5,000 end) |
| 150-249 | ~5,100 → 5,820 (past World 1's end, short of World 2's 6,000) |
| 250-369 | ~6,140 → 6,820 (past World 2's end, short of World 3's 7,000) |
| 370+ | reaches 7,000 (speed 716, which also reaches World 1's and 2's ends) |

The ~2% margins around each end cover the trial-to-trial spread. Launch speed is not shown
anywhere, so speeds that are not in rising order are invisible; only the distance shows.

## Decisions to review

- **The multiplier ladders are intentionally stronger than the spender targets** (2x-4x Power,
  2x-5x Cash, +0.5x a tier). One tier of each finishes 49% faster (target 30-35%) and every tier
  in 2h 33m (floor ~5h 15m). This is on purpose because a World 4 is planned: World 4's balance
  (its bands, prices and the finale) should account for players holding these ladders, rather
  than the ladders being cut back to today's three Worlds.
- **The end of World 2** has the longest stretch with nothing to buy: the Chrono Orb at 3h 39m,
  then World 3 at 4h 44m (65 minutes). A cheaper Dragon Bone Bat ($3.5M) only cuts it to 37
  minutes and makes the finale 31 minutes faster (9h 58m), so it needs its own pass (perhaps
  with a re-solve of the World 2 bands).
- **Juices are the strongest Robux lever:** both running nonstop on top of every tier take the
  finale from 2h 33m to 1h 24m. They are consumables (39 Robux for 10 minutes), so that would
  cost far more than the tiers; revisit if juices get cheaper or longer.
- **The casual finale is day 17** (about 2.4 weeks; ~3 weeks was hoped for). Offline Training
  gives 44% of a casual player's Power; lowering `OfflineRunShare` would stretch it.
- **The Magma Bat** used to be World 2's first Bat (the ×20 price jump from Frostbite followed the
  World Cash tiers); now the big jump sits between Magma ($50K) and Lightning ($1.5M), bought in
  World 2.
- **Starter Pack / +10K Power** reach the Level Cap of an early run on their own (the first bands
  are much smaller now), so a buyer mid-tutorial goes straight to its Rebirth step.
- **After the finale** nothing new is bought and bands keep growing 1.8×, so runs double (123 min
  for run 19). Requirements reach `MaxPower` (9 quadrillion) around Level 600 (Rebirth ~29).
- **Training-only stalls** after about Rebirth 3: Balls cost Cash and only batting earns it.
- **Batting gives almost no Power** past the first grounds, by the no-ground rule.
- **Paid grounds:** Dragon's Lair (30x) is the best ground until Pharaoh's Tomb (35x, Rebirth 8);
  the shared-pass grounds sit below each World's top Rebirth ground. Unchanged.
- **New-World bursts:** a World's first Ball costs 2-8 hits right after the World opens.
- **Offline run cap:** a return fills at most half the run left (the 3x up to all of it), so
  8 hours away is worth about 1-19 minutes of active Training. Raise `OfflineRunShare` if returns
  feel stingy; the cap, not the 8-hour limit, is what binds now.
- **Hit distance is noisy** (see Hit physics): every Level now has a measured speed on the curve,
  but early Levels (speeds under ~200) still vary from hit to hit, and the measurements come from
  one Studio session (a speed can land differently on another server). Making hits deterministic
  (the rolling force is updated per frame) would be a physics change of its own. Re-measure a few
  Levels on a live server before final balance.
## Re-tuning

1. Change config values; run the simulator report and compare with the targets above.
2. Bands: `mode = "solveBands"` with the pace, paste the result into `LevelBands`; the tutorial
   band with `solveTutorial`.
3. Distance: `distanceShape` + `measuredSteps` print the `LaunchSpeedSteps` for Levels 22-140 (from the
   sweep) and the `ExpectedHitDistances` head to paste.
4. After any change to hit physics, the runway or `HitTimeScale`: re-measure (README), then
   `mode = "designSpeed"` and paste `LaunchSpeedTable` / `LaunchSpeedSteps`.
5. Multipliers: the report's SPENDERS section (and `tierValues`, `casualSpenders`) checks the
   light-spender and heavy-spender targets.
6. Refresh `tools/balance/output/*.csv`, the tests' expected values, and this file.
