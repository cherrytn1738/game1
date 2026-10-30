# Economy and Progression Balance

How Power, Levels, Rebirths, Cash and equipment are tuned, what the targets are, and what the
simulator says the game does with them. The numbers live in config modules; this file explains
them. Everything here is balance, not fixed design: re-tune with `tools/balance` (see its
`README.md`) and update this file with the new results.

| What | Where |
|---|---|
| Level bands, Level Cap, Training base, hit Power, launch speed, Cash formula | `src/replicated/ProgressionConfig.luau` |
| Ball / Bat multipliers and prices | `src/replicated/EquipmentConfig.luau` |
| Training Grounds, offline rate and cap | `src/replicated/TrainingConfig.luau` |
| World Cash multipliers, runway sections | `src/replicated/WorldConfig.luau` |
| Simulator, hit measurements, results | `tools/balance/` (`output/*.csv`) |

## The model

Roles (established design): the **Ball** multiplies Power (Training, hits, offline), the **Bat**
multiplies batting Cash, **Training Grounds** multiply Training Power only, **Rebirths** multiply
Power by Rebirths + 1, and **Level alone** sets the launch (and so the distance).

- **Level requirement:** in bands. Levels 1-19 need `9 × Level + 1` (10, 19, 28, ... 172; 1,729
  in all). From Level 20 each Rebirth's 20 new Levels are one band: the band's first Level needs
  `start`, and each Level after it 1.02× the one before (the band's last Level needs ~1.46× its
  first). Past Level 419 each band starts 1.8× above the one before.
- **Level Cap:** `20 × (Rebirths + 1)`: 20, 40, 60, ... Power keeps banking at the cap until the
  Rebirth, which resets Level and Power.
- **Training base:** Power per practice hit at Basic Training: `5 + 1.5 × (Level − 1)` rounded
  down up to Level 20 (5, 6, 8, 9, 11, ... 33), then 33. One practice hit every 2 s.
- **Training Power** = Training base × ground × Ball × (Rebirths + 1) × Power juice.
- **Hit Power** = Training base × 0.37 × seconds in play (rounded) × Ball × (Rebirths + 1) × Power
  juice. No ground.
- **Offline Power** = 25% of the best usable ground's Training rate at the logout Level, for up to
  8 hours, × the saved Ball × (Rebirths + 1), held to half the Power still needed for the Level
  Cap (the run cap). Welcome Back's 3x product adds it twice more, up to all of it.
- **Hit Cash** = `(distance / 80)^1.5` × World (1, 10, 100) × section (1, 1.15, 1.35) × Bat ×
  Cash juice, rounded, at least $1. An early hit (80-100 studs) pays $1.
- **Distance:** Level → launch speed (`LaunchSpeedTable` to Level 140, then `LaunchSpeedSteps`),
  built from measured hits (see Hit physics below).

## Simulator assumptions

The baseline player is free-to-play: no game passes, no Juice, no Welcome Back claim, no Robux.

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
| Tutorial 2: $2 from batting | 15-20 s, ~2 hits at ~$1 | 13.9 s, 2 hits | 2 hits at $1, 3.5 s each (+ walk) |
| Tutorial 3: Sandlot Ball | $2, 3x, 10-15 s | 8.6 s | bought for $2 and equipped |
| Tutorial 4: Level 20 + Rebirth | 45-60 s of Training | 56 s of Training (62.8 s with the walk) | 51.3 s of Training |
| Whole tutorial | 1.5-2 min | 1 min 45 s | about 1.6 min |
| Second run, Training only, Level 1 → 40 | ~3 min | 3.0 min | 2.9 min (173 s) |
| Batting vs Basic Training | 50-70% | 48-69% | 11 Power a hit at Level 3 |

Tutorial step 3 is mostly walking and clicking, so balance cannot move it.

## Level bands

Solved for the MEDIUM pace (below) and smoothed so a band never starts below the Level before it.

| Levels | First Level needs | Band total | Step from the Level before |
|---|---:|---:|---:|
| 1-19 | 10 (+9 a Level) | 1,729 | |
| 20-39 | 580 | 14.1K | ×3.4 |
| 40-59 | 12,000 | 292K | ×14.2 |
| 60-79 | 67,000 | 1.63M | ×3.8 |
| 80-99 | 380,000 | 9.23M | ×3.9 |
| 100-119 | 2.9M | 70.5M | ×5.2 |
| 120-139 | 14M | 340M | ×3.3 |
| 140-159 | 98M | 2.38B | ×4.8 |
| 160-179 | 390M | 9.48B | ×2.7 |
| 180-199 | 1.9B | 46.2B | ×3.3 |
| 200-219 | 4.6B | 112B | ×1.7 |
| 220-239 | 14B | 340B | ×2.1 |
| 240-259 | 42B | 1.02T | ×2.1 |
| 260-279 | 150B | 3.64T | ×2.5 |
| 280-299 | 380B | 9.23T | ×1.7 |
| 300-319 | 880B | 21.4T | ×1.6 |
| 320-339 | 1.6T | 38.9T | ×1.2 |
| 340-359 | 3.7T | 89.9T | ×1.6 |
| 360-379 | 6.7T | 163T | ×1.2 |
| 380-399 | 12T | 292T | ×1.2 |
| 400-419 | 22T | 535T | ×1.3 |
| 420+ | ×1.8 a band | | |

The big ×14 step at Level 40 is the second run's band: from run 2 the active player has the
Enchanted Grove (5x), the Crystal Ball (12x) and two Rebirths, about 18× run 1's Power rate.

## Training Grounds

Unchanged by this pass (multipliers and gates already rise in order). Power a practice hit from
Level 20 on, before Ball and Rebirth:

| Ground | World | Unlock | × | Power a hit |
|---|---|---|---:|---:|
| Basic Training | 1 | start | 1 | 33 |
| Enchanted Grove | 1 | 2 Rebirths | 5 | 165 |
| Sunken Atlantis | 1 | 4 Rebirths | 10 | 330 |
| Sky Temple | 1 | 6 Rebirths | 20 | 660 |
| Cosmic Rift | 1 | 500 R$ pass | 10 | 330 |
| Caveman Camp | 2 | World 2 | 25 | 825 |
| Pharaoh's Tomb | 2 | 8 Rebirths | 35 | 1,155 |
| Gladiator Colosseum | 2 | 10 Rebirths | 50 | 1,650 |
| Samurai Dojo | 2 | 12 Rebirths | 70 | 2,310 |
| Time Machine Lab | 2 | Cosmic Rift's pass | 35 | 1,155 |
| Solar Rooftop | 3 | World 3 | 90 | 2,970 |
| Robo Factory | 3 | 14 Rebirths | 120 | 3,960 |
| Biodome Lab | 3 | 16 Rebirths | 160 | 5,280 |
| Lunar Base | 3 | 18 Rebirths | 210 | 6,930 |
| Quantum Lab | 3 | Cosmic Rift's pass | 120 | 3,960 |
| Dragon's Lair | every | 1000 R$ pass | 30 | 990 |

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
| Magma | 9 | $300,000 |
| Lightning | 13 | $1.5M |
| Dragon Bone | 19 | $25M |
| Celestial | 28 | $120M |

## Cash

One formula for every World: `(distance / 80)^1.5 × World × section × Bat`. The 1.5 power makes
farther hits worth more than their distance; the World multiplier (1, 10, 100) lets each World's
prices sit a tier above the last without changing the formula. Examples (Wood Bat):

| Hit | Distance | Cash |
|---|---:|---:|
| Level 1, World 1 | 81 | $1 |
| Level 20, World 1 | 138 | $2 |
| Level 40, World 1 | 237 | $5 |
| Level 80, World 1 | 738 | $32 |
| Level 140, World 1 | 3,906 | $461 |
| Level 150, World 2 | 5,104 | ~$6,900 |
| Level 250, World 3 | 6,136 | ~$91,000 |
| Level 370, World 3 (the end) | 7,000 | ~$110,000 |

## Affordability (active player)

When each item is bought, its gain over the equipped item, the hits batted since the previous
purchase, its price in hits at that moment, and for Bats the hits until the extra Cash repays it.

| Time | Item | Price | × | Gain | Hits since last | Price in hits | Bat payback |
|---|---|---:|---:|---:|---:|---:|---:|
| 3m 18s | Bubblegum Ball | $10 | 5 | 1.7 | 6 | 3 | |
| 6m 09s | Metal Bat | $25 | 1.5 | 1.5 | 5 | 4 | 8 |
| 7m 46s | Crystal Ball | $40 | 12 | 2.4 | 3 | 3 | |
| 12m 09s | Jungle Bat | $120 | 2 | 1.33 | 8 | 5 | 16 |
| 14m 05s | Frost Comet | $150 | 30 | 2.5 | 5 | 4 | |
| 18m 57s | Inferno Ball | $500 | 75 | 2.5 | 10 | 9 | |
| 22m 26s | Amethyst Bat | $600 | 3 | 1.5 | 6 | 4 | 8 |
| 26m 46s | Thunder Ball | $1,500 | 200 | 2.7 | 8 | 7 | |
| 32m 12s | Candy Cane Bat | $3,000 | 4 | 1.33 | 9 | 7 | 22 |
| 38m 11s | Galaxy Ball | $4,500 | 500 | 2.5 | 7 | 11 | |
| 47m 50s | Dragonfire Ball | $14,000 | 1,250 | 2.5 | 14 | 8 | |
| 55m 12s | Frostbite Bat | $15,000 | 6 | 1.5 | 9 | 7 | 13 |
| 1h 04m | Supernova Ball | $40,000 | 3,500 | 2.8 | 9 | 1 | |
| 1h 06m | Dino Egg | $150K | 5,000 | 1.43 | 3 | 4 | |
| 1h 11m | Stone Ball | $200K | 7,500 | 1.5 | 5 | 5 | |
| 1h 17m | Scarab Ball | $270K | 11,000 | 1.47 | 6 | 6 | |
| 1h 23m | Magma Bat | $300K | 9 | 1.5 | 7 | 7 | 14 |
| 1h 29m | Olympian Laurel | $365K | 17,000 | 1.55 | 6 | 6 | |
| 1h 36m | Viking Rune | $490K | 25,000 | 1.47 | 7 | 7 | |
| 1h 46m | Samurai Ball | $660K | 38,000 | 1.52 | 10 | 10 | |
| 1h 57m | Knight's Ball | $890K | 57,000 | 1.5 | 12 | 13 | |
| 2h 12m | Sheriff Star | $1.2M | 85,000 | 1.49 | 17 | 16 | |
| 2h 34m | Lightning Bat | $1.5M | 13 | 1.44 | 21 | 20 | 45 |
| 2h 45m | Clockwork Ball | $1.6M | 130,000 | 1.53 | 11 | 1 | |
| 2h 47m | Chrono Orb | $2.2M | 200,000 | 1.54 | 2 | 2 | |
| 2h 56m | Solar Cell | $10M | 300,000 | 1.5 | 9 | 8 | |
| 3h 07m | Hover Ball | $13M | 450,000 | 1.5 | 11 | 11 | |
| 3h 21m | Hologram Ball | $17M | 675,000 | 1.5 | 14 | 14 | |
| 3h 37m | Robo Core | $22M | 1,000,000 | 1.48 | 17 | 17 | |
| 3h 57m | Dragon Bone Bat | $25M | 19 | 1.46 | 20 | 19 | 42 |
| 4h 12m | Bio Seed | $29M | 1,500,000 | 1.5 | 15 | 15 | |
| 4h 32m | Pixel Ball | $38M | 2,250,000 | 1.5 | 20 | 20 | |
| 4h 57m | Rocket Ball | $49M | 3,400,000 | 1.51 | 26 | 25 | |
| 5h 29m | Moon Rock | $64M | 5,000,000 | 1.47 | 32 | 33 | |
| 6h 10m | Red Planet | $83M | 7,500,000 | 1.5 | 42 | 41 | |
| 7h 00m | Singularity Orb | $108M | 11,000,000 | 1.47 | 52 | 51 | |
| 7h 54m | Celestial Bat | $120M | 28 | 1.47 | 58 | 57 | 121 |

The Supernova, Clockwork and Chrono cost 1-2 hits because they are bought just after a new
World raises Cash ×10; everything else costs 3-58 hits, rising slowly through the game.

## Results: progression (active player, MEDIUM)

| Milestone | Time | Rebirth / Level |
|---|---|---|
| First Rebirth (end of the tutorial) | 1m 45s | 0 → 1 at Level 20 |
| Second Rebirth | 4m 27s (Training only: 4m 43s) | 1 → 2 at Level 40 |
| World 2 unlock (World 1's end, 5,000) | 1h 02m | Rebirth 7, Level 151 |
| World 3 unlock (World 2's end, 6,000) | 2h 43m | Rebirth 12, Level 251 |
| Finale (World 3's end, 7,000) | 5h 47m | Rebirth 18, Level 371 |

Run lengths (Rebirth k → k+1): 2.7, 4.4, 8.1, 6.0, 13.5, 11.3, 18.4, 11.1, 20.9, 17.2, 23.4, 29.3,
25.2, 23.8, 35.0, 29.5, 37.4, 33.4, 41.9 minutes for runs 1-19 (target 3 + 2 × (k − 1)). After the
finale there is nothing new to buy, so runs 20-23 take 51, 75, 130 and 226 minutes.

**Training only** (no Cash, so no new Balls): runs take 3.0, 7.0, 32.7, 75 and 458 minutes, then
days. Cash comes only from batting, so a player who never bats stalls after about Rebirth 4.

**Casual returning** (30 minutes a day): Day 1 Rebirth 5, day 2 Rebirth 7 (World 2, after 1h 01m
of play), World 3 on day 6 (2h 38m), day 10 Rebirth 18, finale on day 11 (5h 13m of play). Before
the run cap a return usually reached the Level Cap and the player rebirthed straight away; now
they come back partway through a run and bat at its higher Levels, so World 3 comes a day later
(day 6, was 5) but the finale a day sooner (day 11, was 12).

## Pacing options for the later Worlds

Run k of an active player is solved to take `3 + slope × (k − 1)` minutes. MEDIUM is the
provisional choice in the config; to switch, run `solveBands` with the pace and paste its bands.

| Pace | Slope | World 2 unlock | World 3 unlock | Finale | Rebirth 20 |
|---|---:|---|---|---|---|
| FAST | 1 min | 41m | 1h 38m | 3h 28m | 3h 54m |
| **MEDIUM** (current) | 2 min | 1h 04m | 2h 48m | 5h 53m | 6h 44m |
| LONG | 4 min | 1h 39m | 4h 47m | 10h 30m | 12h 52m |

(The MEDIUM row is a fresh re-solve; the config's smoothed MEDIUM bands give 1h 02m / 2h 43m /
5h 47m.)

## Batting vs Training

Power a minute from batting (with the time between hits) against Training at the same Level,
Ball and Rebirths:

| Level | Hit | vs Basic Training | vs the best ground then |
|---:|---:|---:|---|
| 1 | 81 studs | 53% | 53% (Basic) |
| 3 | 86 | 48% | 48% (Basic) |
| 20 | 138 | 53% | 53% (Basic) |
| 40 | 237 | 56% | 56% (Basic) |
| 80 | 738 | 62% | 12% (Enchanted Grove) |
| 140 | 3,906 | 68% | 3.4% (Sky Temple) |
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
| 1 (Bubblegum, Basic) | 14.1K (1.4 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 0.7 min |
| 3 (Frost Comet, Grove) | 1.63M (2.8 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 1.4 min |
| 6 (Dragonfire, Sky Temple) | 340M (2.0 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 1.0 min |
| 9 (Viking Rune, Pharaoh's Tomb) | 46.2B (5.3 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 2.7 min |
| 12 (Chrono Orb, Solar Rooftop) | 1.02T (4.4 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 2.2 min |
| 15 (Bio Seed, Robo Factory) | 21.4T (7.5 min) | 50 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 3.8 min |
| 18 (Moon Rock, Lunar Base) | 163T (8.3 min) | 45 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 4.1 min |

Logged out at Level 1, just after the Rebirth (Training base 5, so the time-based reward is small):

| Rebirths | Run left (Training) | 15 min | 1 h | 4 h | 8 h | 8 h is worth |
|---|---|---:|---:|---:|---:|---:|
| 1 | 15.8K (1.8 min) | 36 / 100% | 50 / 100% | 50 / 100% | 50 / 100% | 1.0 min |
| 3 | 1.94M (3.3 min) | 17 / 52% | 50 / 100% | 50 / 100% | 50 / 100% | 1.7 min |
| 6 | 422M (2.5 min) | 23 / 70% | 50 / 100% | 50 / 100% | 50 / 100% | 1.3 min |
| 9 | 58.4B (6.8 min) | 8 / 25% | 34 / 100% | 50 / 100% | 50 / 100% | 3.4 min |
| 12 | 1.53T (6.7 min) | 9 / 26% | 34 / 100% | 50 / 100% | 50 / 100% | 3.3 min |
| 15 | 35.8T (12.6 min) | 5 / 14% | 18 / 54% | 50 / 100% | 50 / 100% | 6.3 min |
| 18 | 327T (16.6 min) | 3 / 10% | 14 / 41% | 50 / 100% | 50 / 100% | 8.3 min |

Before the run cap the band-start returns were 45-264% of the run at 15 minutes and 1,456-8,435%
at 8 hours (they stopped at the Level Cap, so any 15-minute break could finish a run). The run cap
now binds within the first hour away at a band start (within minutes in the early runs) and after
1-4 hours just after a Rebirth, so longer absences add nothing more; in these cases the 8-hour
limit never binds.

## Hit physics and the launch table

Distance comes from Roblox physics (flight, bounces, roll). Up to about 505 studs/s it rises
smoothly with speed, so Levels 1-140 interpolate measured speeds for distances rising ~2.8% a
Level (81 studs at Level 1, 3,906 at 140). Above 505 the bounces make distance jump around from
one speed to the next (640 → 4,310, 641 → 3,395, 649 → 7,000, 650 → 5,959, 695 → 5,586); the same
speed repeats within about 1%, and lands the same in every World (World 1, 2 and 3 checked).
So from Level 141 each Level uses a speed measured at least twice (`LaunchSpeedSteps`), chosen so
distance rises in steps and each World's end is reached exactly at its Level:

| Levels | Distance |
|---|---|
| 141-149 | ~4,050 → 4,770 (World 1, short of its 5,000 end) |
| 150-249 | ~5,100 → 5,820 (past World 1's end, short of World 2's 6,000) |
| 250-369 | ~6,140 → 6,820 (past World 2's end, short of World 3's 7,000) |
| 370+ | reaches 7,000 (speed 716, which also reaches World 1's and 2's ends) |

The ~2% margins around each end cover the trial-to-trial spread. Launch speed is not shown
anywhere, so speeds that are not in rising order are invisible; only the distance shows.

## Decisions to review

- **MEDIUM pace** (finale ~5h 50m for an active player) is provisional; FAST and LONG are ready.
- **The Training base grows with Level** (5 → 33). A flat base cannot give both a ~15 s first step
  (6 hits at +5) and a ~1 minute climb to Level 20.
- **After the finale** nothing new is bought and bands keep growing 1.8×, so runs double (75,
  130, 226 min). Requirements reach `MaxPower` (9 quadrillion) around Level 600 (Rebirth ~29).
- **Training-only stalls** after about Rebirth 4: Balls cost Cash and only batting earns it.
- **Batting gives almost no Power** past the first grounds, by the no-ground rule.
- **Paid grounds:** Dragon's Lair (30x) is the best ground until Pharaoh's Tomb (35x, Rebirth 8);
  the shared-pass grounds sit below each World's top Rebirth ground. Unchanged.
- **New-World bursts:** the last ball of a World costs 1-2 hits right after the next World opens.
- **Bat price gaps** of ×20 and ×17 (Frostbite → Magma, Lightning → Dragon Bone) follow the
  World Cash tiers; the Celestial Bat and Singularity Orb are post-finale goals.
- **Offline run cap:** a return fills at most half the run left (the 3x up to all of it), so
  8 hours away is worth about 1-8 minutes of active Training. Raise `OfflineRunShare` if returns
  feel stingy; the cap, not the 8-hour limit, is what binds now.

## Re-tuning

1. Change config values; run the simulator report and compare with the targets above.
2. Bands: `mode = "solveBands"` with the pace, paste the result into `LevelBands`.
3. After any change to hit physics, the runway or `HitTimeScale`: re-measure (README), then
   `mode = "designSpeed"` and paste `LaunchSpeedTable` / `LaunchSpeedSteps`.
4. Refresh `tools/balance/output/*.csv`, the tests' expected values, and this file.
