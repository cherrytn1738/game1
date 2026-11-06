# Baseball Simulator — Game Design

## Core Concept

A Power/Level-based baseball batting simulator where players hit a ball from a batting tee and progress by increasing how far they can hit.

The core gameplay loop is:

Train to gain Power → Level up → hit farther → earn Cash → reach farther sections → unlock worlds → reach Level Cap → Rebirth → repeat

The game is not intended to simulate traditional baseball games. The focus is on satisfying batting, distance progression, equipment progression, and reaching increasingly distant environments.

## Batting

Players approach a batting tee to enter batting mode.

While batting:

- The player is positioned and locked at the batting location.
- Click/tap to swing; every valid swing launches straight downfield at a configured loft (38 degrees, steeper for the first Levels; see below).
- Level, and the World you bat in, determine launch speed (hits start over in each later World: see World 4 below and `ECONOMY.md` Distance per World). There is no timing fan, quality, spray, or timing power bonus.
- The server validates station occupancy, session, cooldown, ball readiness, Level, and launch.
- Space / touch Leave exits batting; the established animation and camera remain.

After being hit, the ball uses Roblox physics.

The ball can:

- Fly
- Bounce
- Roll
- Naturally lose speed

The hit ends after the ball has naturally come to rest rather than after a fixed flight duration.

Rolling distance counts toward the final hit distance.

## Distance

Distance is one of the primary measures of progression.

The server calculates the authoritative final hit distance after the ball stops.

Progression distance should represent meaningful downfield travel from the batting location.

Horizontal deviation and vertical height should not artificially increase progression distance.

Longer hits generally produce better rewards and allow the player to reach farther parts of the game.

## Equipment

### Hub access

World 1 uses deliberate physical interactions to open the equipment and world travel interfaces.
Only one hub interface is open at a time. Browsing does not lock movement; batting, an active hit,
death, respawning, and world changes close these interfaces. Equipment changes wait until the
hit has finished and the player has left batting mode. Worlds without a physical hub retain
on-screen access to the same interfaces.

There are two player equipment categories.

### Equipment Roles

An established architecture decision (it replaced the earlier Bat = Power, Ball = Cash split):

- **Ball:** multiplies Power gain (`powerGainMultiplier`).
- **Bat:** multiplies Cash rewards from batting (`cashMultiplier`).
- **Level:** solely determines hit distance. Neither Ball nor Bat changes launch speed, loft, direction or distance.
- **Training Ground:** multiplies Training Power only.
- **Rebirth:** multiplies Power gain (`Rebirths + 1`).

The server derives every multiplier from the authoritative equipped IDs through `EquipmentConfig`; clients never supply one. Whole Power is rounded down once, after every bonus (formulas in `ProgressionConfig`; tuning in `.vscode/ECONOMY.md`):

- **Training Power** = the Training base (5 at every Level) × ground multiplier × Ball × (Rebirths + 1) × any Power juice.
- **Hit Power** = the Training base × `HitPowerPerSecond` (0.37) × seconds the ball was in play, rounded, × Ball × (Rebirths + 1) × any Power juice. No ground multiplier: counting the time between hits, batting earns about 50-70% of Basic Training's Power, so Training stays the best Power source.
- **Offline Power** = 25% of the best usable ground's Training rate (no Level term; up to 8 hours) × the saved equipped Ball × (Rebirths + 1), held to half the Power still needed for the Level Cap (the run cap, below).
- **Hit Cash** = (the World's `cashBase` start pay + its `cashMultiplier` × (distance / 80)^1.5) × section multiplier × Bat × any Cash juice, rounded, at least $1 (about $1 for an early hit).

A hit snapshots the Ball ID and the Bat's Cash multiplier when the swing is accepted, so swapping equipment mid-flight (which is blocked anyway) cannot change that hit's rewards.

### Bat

Bats remain owned, purchasable, equippable, and persistent. Each Bat's `cashMultiplier` multiplies the Cash a real hit earns; it never changes Power, launch speed, loft, or direction. Each Bat earns about 1.5x the Cash of the one before.

### Ball

Balls are the Power progression equipment. The equipped Ball's `powerGainMultiplier` multiplies Power from active Training, real hits, and offline Training, and stacks with Rebirth. It never changes Cash or launch strength.

The physical batting tee remains part of each station. It is not purchasable, owned, or equipped by players.

### Bat lineup, models and swing effects

Ten Bats, cooler as the price rises (Cash multipliers, tuned with `tools/balance`):

| Bat (id) | Price | Cash | Swing trail / contact burst |
|---|---|---|---|
| Wood Bat (wood_bat) | Free | ×1 | none |
| Metal Bat (metal_bat) | 25 | ×1.5 | faint white swoosh |
| Jungle Bat (jungle_bat) | 120 | ×2 | green swoosh / leaves |
| Amethyst Bat (amethyst_bat) | 600 | ×3 | purple swoosh / gem sparkle |
| Candy Cane Bat (candy_cane_bat) | 3,000 | ×4 | pink-and-white swirl / sprinkles |
| Frostbite Bat (frostbite_bat) | 15,000 | ×6 | icy trail / frost ring |
| Magma Bat (magma_bat) | 50,000 | ×9 | fire trail / fire burst |
| Lightning Bat (lightning_bat) | 3,200,000 | ×13 | flickering trail / lightning zap |
| Dragon Bone Bat (dragon_bone_bat) | 28,000,000 | ×19 | flame trail / fire burst |
| Celestial Bat (celestial_bat) | 100,000,000 | ×28 | rainbow trail / starburst and shockwave |
| Rolling Pin Bat (rolling_pin_bat) | 1,650,000,000 | ×42 | placeholder look until its model (World 4, Phase 4) |

The Alloy and Carbon Bats were removed (cleared from the developer's save; other saves drop them on load).

- **Models:** `tools/blender/bats.py` exports `assets/models/Bats.fbx`. Every bat matches the Bat tool: hand (Handle) at the origin, knob -0.52..-0.40, grip to 0.50, barrel to 3.40 along the Handle's +Y, so the grip and swing animation are unchanged. Each has a `Grip` and a `Barrel` part.
- **In hand:** `EquipmentVisualServer` welds the styled model (`BatStyles`) to the Handle, massless and non-colliding, and hides the plain BatBody/BatGrip/BatKnob. Without a model the plain bat is painted as before.
- **Swing trail:** the server adds `SwingTrailBase` (y 1.6) and `SwingTrailTip` (y 3.4) to the Handle; `BatEffects` on every client draws the bat's trail between them while the tip moves faster than 30 studs/s (real and practice swings).
- **Contact burst:** when a ball leaves the tee, the batter's Bat burst plays at the tee (with the ball's launch burst).
- **Display:** the Bat Display (upright 3.6-stud bats) stands just behind each World's Ball Display on the right side of the hub (seen from the spawn); both face the middle.

### Ball lineup, models and flight effects

Ten Balls, cooler as the price rises (Power multipliers, intended balance; the Sandlot Ball's $2 is the tutorial's first purchase):

| Ball (id) | Price | Power | Flight |
|---|---|---|---|
| Baseball (baseball) | Free | ×1 | a clean white streak of cut air |
| Sandlot Ball (practice_ball) | 2 | ×3 | dusty streak in a smoky dirt trail, dirt puffs, falling clods |
| Bubblegum Ball (bubblegum_ball) | 10 | ×5 | twisted pink-and-white candy ribbon, bubbles, falling sprinkles |
| Crystal Ball (crystal_ball) | 40 | ×12 | prismatic sparkle ribbon, three crystal shards in orbit, glitter |
| Frost Comet (frost_comet) | 150 | ×30 | long glowing comet tail in frost mist, snow, falling ice shards |
| Inferno Ball (inferno_ball) | 500 | ×75 | roaring fire ribbon over black smoke, flames, embers |
| Thunder Ball (thunder_ball) | 1,500 | ×200 | crackling electric streak, lightning bolts arcing off the ball, sparks |
| Galaxy Ball (galaxy_ball) | 4,500 | ×500 | three spiralling star streams through a shifting nebula, orbiting stars |
| Dragonfire Ball (dragonfire_ball) | 14,000 | ×1,250 | twin weaving dragon-flame trails, black smoke, fire-breath bursts along the way |
| Supernova Ball (supernova_ball) | 40,000 | ×3,500 | rainbow comet with a white-hot core, rainbow sparks in orbit, pulsing shockwaves |

The All-Star and Championship Balls were removed (their IDs were also cleared from the developer's save; other saves drop them on load).

**World 2 (Time Travel) balls** are a second purchase series in the same Ball category (`EquipmentConfig` Ball `series`, id `world_2`), one ball per era of World 2. They are bought in their own order, starting from the Dino Egg, and need World 2 unlocked but none of World 1's balls. World 1 balls stay owned and equippable everywhere. Every one beats the Supernova Ball, each about 1.5x the one before, priced for World 2's Cash (×10):

| Ball (id) | Price | Power | Flight |
|---|---|---|---|
| Dino Egg (dino_egg_ball) | 175,000 | ×5,000 | swaying jungle trail shedding leaves and eggshell, spores |
| Stone Ball (stone_ball) | 220,000 | ×7,500 | thick dust trail, pebbles in orbit, rock chunks breaking off |
| Scarab Ball (scarab_ball) | 350,000 | ×11,000 | gold and lapis spiral through a sand stream, golden scarabs in orbit |
| Olympian Laurel (laurel_ball) | 440,000 | ×17,000 | white-gold streak shedding golden laurel leaves, victory rings rippling behind |
| Viking Rune (viking_rune_ball) | 490,000 | ×25,000 | glowing rune stones in orbit, icy flickering trail, frost mist, rune lightning |
| Samurai Ball (samurai_ball) | 630,000 | ×38,000 | two crossing katana-slash ribbons, red silk trail, a storm of cherry petals |
| Knight's Ball (knight_ball) | 960,000 | ×57,000 | gleaming steel streak with a fluttering red plume banner, sparks, glints |
| Sheriff Star (sheriff_star_ball) | 1,150,000 | ×85,000 | dusty frontier trail, gold stars circling like a spinning badge |
| Clockwork Ball (clockwork_ball) | 1,350,000 | ×130,000 | brass and cyan strands winding round it, spinning gears in orbit, steam, a ticking ring |
| Chrono Orb (chrono_orb) | 2,100,000 | ×200,000 | ghostly echoes left behind, a swirling time vortex, colour-shifting strands, time ripples |

- **Offers:** each series has its own server-issued purchase token (`EquipmentPurchaseToken_Ball` for World 1's, `EquipmentPurchaseToken_Ball_world_2` for World 2's, `EquipmentPurchaseToken_Ball_world_3` for World 3's). The server finds the series from the token, checks the World unlock, then sells that series' next ball.
- **Where they're sold:** World 2's ball display (`hub.displays` entry with `series = "world_2"`) only, where locked pedestals say "Unlock Time Travel to buy these." World 1's ball display shows only World 1's series.
- **Models:** `tools/blender/balls_world2.py` builds them like `balls.py` and exports `assets/models/BallsWorld2.fbx`, to be split into `DisplayItems` the same way. Until then, each shows as a plain sphere in its `appearance` colour.
- **Effects:** each has its own flight layers like World 1's balls (see Flight layers above).

**World 3 (Future World) balls** are the third series (`series` id `world_3`), one ball per World 3 runway section, sold the same way from World 3's "FUTURE BALLS" display. They need World 3 unlocked and none of the other series. Every one beats the Chrono Orb, each about 1.5x the one before, priced for World 3's Cash (×100) and far below `PlayerData`'s 9 trillion Cash cap:

| Ball (id) | Price | Power | Flight |
|---|---|---|---|
| Solar Cell (solar_cell_ball) | 15,000,000 | ×300,000 | warm sunbeam streak in glowing segments, sun glints, rings of sunlight |
| Hover Ball (hover_ball) | 16,500,000 | ×450,000 | twin thin cyan thruster contrails, hover rings rippling out |
| Hologram Ball (hologram_ball) | 22,000,000 | ×675,000 | glitchy blue afterimages, a flickering scan-line ribbon, hologram sparks |
| Robo Core (robo_core_ball) | 24,500,000 | ×1,000,000 | steel streak with a red laser core, sparks, nuts and bolts shaken loose |
| Bio Seed (bio_seed_ball) | 29,000,000 | ×1,500,000 | curling vine-green trail, a glowing tendril, drifting spores, falling leaves |
| Pixel Ball (pixel_ball) | 34,000,000 | ×2,250,000 | trail of square arcade pixels, a stepped rainbow ribbon |
| Rocket Ball (rocket_ball) | 45,000,000 | ×3,400,000 | roaring flame exhaust, fire streak and a billowing smoke trail |
| Moon Rock (moon_rock_ball) | 56,000,000 | ×5,000,000 | floating moon dust hanging behind it, pale moonlight, little moon rocks in orbit |
| Red Planet (red_planet_ball) | 76,000,000 | ×7,500,000 | billowing red dust plume, rust-orange ribbon, two tiny moons in orbit |
| Singularity Orb (singularity_orb) | 97,000,000 | ×11,000,000 | purple vortex wake, accretion ribbons whirling round it, warping rings, bright motes |

- **Models:** `tools/blender/balls_world3.py` (reusing the World 1 and 2 ball helpers) exports `assets/models/BallsWorld3.fbx`, split into `DisplayItems` the same way.

- **Models:** `tools/blender/balls.py` builds all ten (radius 1, meshes named `<id>__<Part>`) and exports `assets/models/Balls.fbx`; run it headless with `blender --background --python tools/blender/balls.py`. After import they are split into one model per id in `ServerStorage.RunwayAssets.DisplayItems`.
- **Looks:** `BallStyles.luau` (ReplicatedStorage) colours each part by name and holds each ball's glow, flight effects, bursts and display idle particles. The physics ball keeps its locked `CustomPhysicalProperties`, so no look can change flight.
- **Display:** pedestals show the styled model with its glow and a few of its particles as a preview.
- **On the tee and in flight:** the server publishes the styled models to `ReplicatedStorage.BallModels`. Each client shows the batter's model (from the station ball's `EquipmentId`) on the physics ball, which is hidden locally, and `BallEffects` adds the trail, particles and glow once the ball visibly leaves the tee, with a burst at launch and at the first landing. Without a model the plain coloured ball is shown and the effects still play.
- **Trail colour:** ball and bat trails are drawn unlit with normal blending (`LightEmission` 0, `Brightness` 1.6). Additive light washed every trail to white against the bright sky and bloom, so trail colours are also kept saturated.
- **Flight layers (each ball its own):** every ball has its own stack of layers in `BallStyles` `flight.layers`, drawn by `BallEffects`: ribbons (trails with colour gradients and a shaped silhouette, such as teardrop, needle, swell, scalloped or flame-tongued, optionally split into glowing bands; they can spiral round the ball, sway or crackle), streaks (soft, round glowing trails made of overlapping particles, for fire, smoke, dust, sand, mist and glow, so trails aren't flat strips), particles (optionally emitted behind the ball), orbiters (crystals, gears, rune stones, stars circling the ball), debris (leaves, petals, rocks, ice shed behind it), lightning arcs, pulses (rings rippling out along the path) and echoes (fading ghost copies of the ball). Glow adds only some light (`GLOW_EMISSION`), because fully additive light washed colours to white against the sky. A soft glow halo, cosmetic backspin and a flash + ring at launch and landing are shared. All of it is client-side and cosmetic.
- **Visible size:** the ball you see, and all of its flight effects, are drawn 2× the 0.8-stud physics ball (`BallEffects` `VISUAL_SCALE`) and raised so the bottom still rests where the physics ball's does (on the tee and the ground). The physics ball, its collisions and distances are unchanged.

### Item displays

Every World's hub has a physical **Ball Display** (that World's ball series) and **Bat Display** side by side on the right side of the hub as seen from the spawn, facing the middle, as one shopping zone (`WorldConfig` `hub.displays`, from the shared hub layout; built by `ItemDisplay.luau`; front edge hub x -36, centred at z 86 and 126). Each is a dark slate stepped stage with red trim and a backdrop wall, with the title ("BALLS" / "Gain more Power"; the Bat Display's reads "BATS" / "Earn more Cash per hit"); each pedestal label shows the item's multiplier as "×N POWER" (Balls) or "×N CASH" (Bats) above it. There is one pedestal per item of its series in `EquipmentConfig` order, `perRow` (5) per row (6.4-stud spacing, so a row is about 35 studs wide); further rows step back and up. Adding a Ball to the config adds a pedestal, and another category can get its own display with one more `displays` entry.

- **Item models:** each pedestal shows `ServerStorage.RunwayAssets.DisplayItems.<item id>` when that model exists, scaled to 2 studs and spun about its centre. Without one, it shows a placeholder ball in the item's `appearance` colour with two red seams. To show a designed ball, put its model in `DisplayItems` named by its item ID (for example `practice_ball`).
- **Labels (client):** a floating label per pedestal shows this player's status (EQUIPPED cyan, OWNED white, FOR SALE gold, LOCKED red), the name, the boost (×1.3 CASH) and the price (red when unaffordable). Items spin and bob locally (`ItemDisplayClient`).
- **Buying:** the pedestal's ProximityPrompt reads Buy, Equip, Equipped (disabled) or Locked. The pedestals are the only place Bats and Balls are bought (there is no Cash equipment menu; the Inventory only equips). Triggering one sends an `EquipmentUpgrade` request (Purchase with the server-issued offer token, or Equip), so the server validates everything, and `ItemDisplayClient` shows the result as a notification and plays the Purchase / Equip sound. Locked items explain why instead of sending a request.

## Equipment Progression

Equipment progression is based on distinct equipment rather than numeric equipment levels.

Players progress from one Bat or Ball to another piece of equipment with its own configuration and gameplay effects.

Equipment uses stable internal IDs and is server-authoritative.

Purchased/equipped equipment persists between sessions.

Equipment visual design, models, materials, and special effects are intentionally handled separately from gameplay progression. Gameplay milestones should not introduce new equipment cosmetics unless explicitly part of a dedicated visual-content milestone.

## Currency

The primary currency is Cash.

Players earn Cash from completed hits.

Rewards are influenced by:

- Hit distance
- Equipped Ball
- Field section

Cash and equipment progression are server-authoritative and persist between sessions.

## Field Sections

Each world contains one long continuous batting field extending away from its batting location.

The field is divided into progressively farther sections.

A baseball physically travels through these sections without teleportation.

Sections:

- Represent progression within a world
- Occupy different distance ranges
- May provide different reward multipliers
- Will eventually have distinct visual/environmental themes

Players do not purchase access to individual sections.

If a ball can physically reach a section, the player has reached that section.

Final section themes, environments, and visual presentation will be designed separately from the underlying progression system.

## Worlds

Worlds represent a larger layer of progression above field sections.

Each world contains:

Batting area → long field → multiple sections → end marker

The player progresses through a world by becoming powerful enough to hit farther down its field.

Reaching or passing the world's configured end distance with a legitimate hit completes that world and permanently unlocks the next world.

### End portal

A giant time portal (the hub portal's model, 360 studs tall, `WorldConfig` `endPortal`) stands across each runway at its endpoint, facing the tee; it replaces the floating "FINISH" title, and nothing in it is solid.

- **Capture (server, `BallLauncher`):** the moment a hit's ball reaches the endpoint, at any height, the portal takes it: the ball is anchored and drawn into the opening's centre over 1.4 s, spiralling in (`PORTAL_SUCTION_SECONDS`). The hit then ends as `"portal"` and is measured at the endpoint exactly (the full distance, in the last section), so Cash and World completion follow the normal rules.
- **Capture sound:** as any ball is drawn in, the portal's swirl spins up and a vortex blast swells to peak as the ball reaches the centre.
- **The trip:** when that hit completes the World for the first time and the next World is unlocked, the server ends batting, holds the batter, keeps the portal streamed in for them (a replication focus), and sets the player's `PortalJourney` attribute (and `WorldTraveling`, which keeps menus away). Their client (`PortalJourneyClient`, built on `CinematicFX` like the rare hits) hides the HUD and plays about 9 s:
  1. Impact (0 s): a white flash, glowing rings blasting out of the opening, lightning across it, a boom and thunder; the music starts.
  2. Reveal (0–2.2 s): a slow, low push-in on the giant portal as "WORLD 2 UNLOCKED! / TIME TRAVEL" slams in.
  3. Summons (2.2–3.6 s): a cut to the batter at the tee; a shockwave, crackling lightning and a sparkling aura, and they are lifted off the ground as a riser builds to a hard stop at takeoff.
  4. Flight (3.6–6.0 s): they rocket down the runway in a high arc toward the portal on a trail of light, with a chase camera, a widening field of view, speed lines and a rumbling rush.
  5. Plunge (6.0–6.85 s): a wide shot as they spiral into the swirl (an energy whoosh peaks as they vanish), then white with a last boom.
  6. Arrival: at 8.6 s the server moves them to the next World through the normal travel step; the white fades there with a shockwave, a sparkle burst, a magic chime and the World's title, and the HUD returns.
  Audio (Roblox-licensed): APM "New World Anthem Link 4" (music); Pro Sound Effects vortex blast, thunder, rushing pass-by and energy whoosh, the rare hits' launch boom and riser, and "Magic Transformation 17" (arrival). The rest of the mix ducks under it (the Cinematic duck), and the HUD skips its own World-unlock sting for portal hits. Dying, leaving or travelling cancels the trip.
- Already-completed Worlds still capture the ball (normal rewards), without the trip. World 1's portal leads to World 2, World 2's to World 3 and World 3's to World 4.
- **Finale (temporary, World 4):** World 4 (Tiny Town) is the last World for now (World 3 had the finale until World 4 was added), so its portal has a `finale` (`WorldConfig` `endPortal.finale`) instead of a next World. A first completion through it (or any portal hit with `ForcePortalJourney` in Studio) holds the batter the same way, sets `GameFinale`, and plays about 12 s on their client (`PortalJourneyClient`): the impact as above with APM's "A Winner's Anthem"; a push-in on the portal as "YOU FINISHED THE GAME! / MORE WORLDS COMING SOON" slams in; a crane shot over the runway's end as fireworks burst round the portal (Pro Sound Effects fireworks); then back at the tee, the batter in a shower of confetti and fireworks with a cheering crowd as "THANKS FOR PLAYING! / WORLD 3 COMPLETE" lands; then white, and at 11.8 s the server returns them to World 3's hub. World 3 still saves as completed, so a future World 4 can unlock from it: to add one, give World 3 a `nextWorldId` and remove the `finale`.
- **Testing in Studio:** the Workspace attribute `ForcePortalJourney` plays the trip on every portal hit, not only the first completion; `StudioLaunchLevel` launches hits as that Level, through the World's launch Levels (World 1: 150 reaches its portal; Worlds 2-4: their `launchLevels.to`, 250 / 370 / 490; the saved Level is untouched); `StudioWalkSpeed` sets the playtest walk speed (e.g. to run down a runway). Live servers ignore all three.
- The giant portals' gears, hands and swirl turn on each client (`PortalJourneyClient`).

Worlds are not unlocked by simply purchasing them with Cash.

Example progression:

World 1
→ reach farther sections
→ reach World 1 end
→ unlock World 2
→ progress through World 2
→ reach World 2 end
→ unlock World 3 (Future World)
→ progress through World 3
→ reach World 3 end
→ unlock World 4 (Tiny Town, the last World for now)

Unlocked worlds remain available permanently and players may return to previously unlocked worlds.

**Studio testing:** with the Workspace attribute `UnlockAllWorlds` set to true, every World is unlocked at load in Studio playtests only (`RunService:IsStudio()`). These unlocks last for the session and are never saved; a real completion during the session still saves normally. Clear the attribute to test as a normal player.

## Progression Philosophy

Progression should be physically visible through batting performance.

A new player should hit relatively short distances.

As Level increases, the player should:

- Hit farther
- Reach new field sections
- Earn more Cash
- Purchase better equipment
- Eventually reach the end of the current world
- Unlock the next world

The beginning of the game should leave substantial visible room for future power growth.

Level 1 should produce a short hit far below the World 1 endpoint.

## New-Player Tutorial

A new save starts a four-step tutorial in World 1 that shows the whole loop in about a minute and a half. It runs once: a completed tutorial never shows again.

**A focused HUD.** While it runs (and before the save loads, so nothing flashes up first), the persistent HUD shows only the Level bar with the Power amount and multiplier above it (`HubInterfaces.TutorialFocus`, read by HUDClient, MonetizationClient and JuiceHUDClient from `TutorialStep`). The quick-menu tiles, the Cash / Rebirth counters, the Batting shortcut, Auto Bat, the Power purchase row and the juice pills are hidden; the tutorial brings back only the tiles it points at (`HubInterfaces.TutorialTile`): the Inventory tile from the Sandlot purchase on, and the Rebirth tile at the Rebirth step. The banner, arrows and spotlight, the batting and Training controls (Swing, Leave), hit and Power feedback, notifications, and the menus a step uses (Inventory, Rebirth) still show. Everything returns the moment the server marks the tutorial Complete, with no respawn. Only the player's own Rebirth completes the Rebirth step; the Starter Pack's bonus Rebirth only raises the Level Cap it waits for.

| Step | Objective (banner) | Done when (server) | Guidance | Target | Measured (Studio, balance pass) |
|---|---|---|---|---|---|
| 1 | GET 30 POWER (n/30) | 30 Power granted (any source) | arrows to Basic Training | ~15 s | ~15 s (4 s walk + 6 practice hits at +5/+6: 11.1 s on the plate) |
| 2 | EARN $2 FROM BATTING ($n/$2) | $2 of batting Cash earned | arrows to the tee | 15-20 s | ~14 s (5 s walk + two hits at $1, 3.5 s each) |
| 3 | BUY THE SANDLOT BALL, then EQUIP THE SANDLOT BALL | a real Sandlot purchase recorded by the server (saved as `TutorialBoughtBall`, even when bought earlier in the tutorial), then the Sandlot equipped; during the tutorial buying it does not equip it. Owning it alone never completes the step, and Studio's `OwnAllBalls` is not applied to fresh saves or while the tutorial runs | arrows to its pedestal, where its prompt reads Buy; once bought, the Inventory tile returns and is ringed, then the Inventory's Balls tab and the Sandlot's card are spotlit | 10-15 s | not yet measured (6 s walk + one press + three taps) |
| 4 | REACH LEVEL 20 (n/20), then REBIRTH NOW! | Level 20 (the Level Cap), then a successful Rebirth | "Train to gain Power"; arrows to Basic Training only after 20 s without Power; then the Rebirth menu opens (or the HUD's Rebirth tile is ringed while Training) with REBIRTH, then CONFIRM, spotlit | 45-60 s | ~233 s with the flat Training base (was ~59 s); needs a later rebalance |
| | TUTORIAL COMPLETE! | | the banner fades after 5 s | 1.5-2 min | about 1.75 min |

- **Values:** `TutorialConfig` (30 Power, $2, the main Ball series' second ball, Basic Training, World 1; Level 20 is `Progression.GetLevelCap(0)`). The Ball's price and multiplier come from `EquipmentConfig`.
- **Balance it relies on:** the Training base is +5 Power per practice hit at every Level; Levels below 20 need `10 + 1.5 * (Level - 1)` Power (442 from Level 1 to 20, about 54 s of Training with the Sandlot Ball's 3x); an early hit pays $1 (`ProgressionConfig.GetHitCash`); the first Level Cap is 20. `tools/balance` checks these timings (`.vscode/ECONOMY.md`).
- **Server authority:** `PlayerData` owns the state (session `tutorial`), moves it only from its own events (granted Power, `RecordBattingCash` from `BallLauncher`, purchases, Level, Rebirths; a Rebirth from any step completes it), publishes `TutorialStep` / `TutorialProgress`, and saves a step change soon (the important-save path). There is no client request that moves it. Progress counts what was earned, so spending Cash never takes it back.
- **Persistence (Schema 10):** `TutorialCompleted`, and while unfinished `TutorialStep` and `TutorialProgress` (a finished save keeps no step or count). Rejoining resumes the saved step and count, moving past anything already done.
- **Existing players:** a save from before Schema 10, or with malformed tutorial fields, skips the tutorial when it already shows play (any Rebirth, Level above 1, Power, Cash, bought equipment or a World beyond World 1) and starts it otherwise. An out-of-range count resets to 0.
- **Arrows (`GuideArrows`):** chunky white chevrons with a dark outline every 5 studs along the route from the player (through a cage's door when the goal is inside it), rippling forward, plus a big chevron bobbing over the destination. Client-only parts (no collisions, shadows or replication), pooled, one RenderStepped connection while shown. They show only while walking in World 1's hub with no menu open, hide while Training / batting, during death and outside World 1, and come back on respawn.
- **Spotlight (`Spotlight`, tutorial-only):** four dark frames around the real target (its AbsolutePosition / AbsoluteSize, re-measured every frame, so resizing and scrolling keep it aligned), a pulsing gold ring and a short caption (below a wide target, beside a small one). The target's list scrolls it into view. The menu's other buttons are non-interactive meanwhile, except its close button, so closing the menu always removes the spotlight and restores the world guidance. Outside a menu it is only a ring (the HUD's Rebirth tile).
- **Banner:** top centre below Roblox's top bar, gold FredokaOne with heavy outlines; it steps aside while a menu is open (the spotlight caption carries the instruction there); notifications float in the middle of the screen, clear of it.
- **Sound:** `TutorialStep` (a soft ding on each new objective) and `TutorialComplete` (a chime after the Rebirth fanfare's opening); progress ticks are silent.
- **Studio testing:** the Workspace attribute `StudioFreshSave` plays as a brand-new player on a throwaway record in a Studio-only store (`Studio_FreshPlayers`), ignoring `OwnAllBalls` / `UnlockAllWorlds`, and never touches the real save or the leaderboards.

## UI Presentation (Inventory style)

Every screen follows the Inventory's chunky cartoon style, built on the Check-UI foundation (`.agents/skills/check-ui-clean-roblox/`). `UICommon` implements it behind the same API, so clients keep their gameplay wiring; the Worlds and Inventory menus use its `UI.ShowcaseMenu` variant (both blue).

- **Font:** FredokaOne (`UI.Font`) everywhere, with a heavy near-black outline in proportion to the text size (2 to 6px). Hit cinematic titles keep their own font.
- **Windows:** a slightly see-through blue rounded window (`UI.MenuBoxTransparency` 0.3, so the blurred world shows faintly through; 16px corners) with a top-to-bottom blue gradient, a faint checker, a soft white inner rim and a thick 4px outline.
- **Titles:** the menu's title rides centred over the top edge of the window (up to 56px, white fading to light cyan), with the menu's icon just left of the text, and the close button on the top-right corner.
- **Close button:** a 52×52 red rounded square with a white outlined X.
- **Buttons:** chunky and studded: a slightly rounded face in the state's colours with a faint white stud pattern, a darker bottom edge, a white inner rim, a 4px outline and a big outlined caption.
- **Button states:**
  - Claim (green): available actions (go, buy, equip, confirm).
  - Claimed (grey): equipped, selected, or disabled.
  - Locked (red): locked items and destructive actions such as Leave and Cancel.
  - Cyan (blue): neutral buttons and the selected tab.
- **Motion and sound:** hover 1.05, press 0.94 with a Back.Out release, and a click sound.
- **Cards:** rounded dark blue cards (12px corners) with a thick outline and a light blue inner rim. A bright cyan rim marks the selected card; a dark tint with a red rim marks locked ones.
- **Badges:** rounded tiles with a thick outline.
- **Notifications** (`UI.Notify`): no panel, just big outlined FredokaOne text with a soft drop shadow floating in the middle of the screen. The title names the problem in its own colour with an icon (CAGE / WORLD / ITEM / REBIRTH LOCKED in red with a padlock, NOT ENOUGH CASH in gold with the Cash icon, CAN'T DO THAT for other refusals, plus REBIRTH COMPLETE, WORLD COMPLETE!, LEVEL UP!). The message highlights the key value (gold for Rebirths, Levels and other values, green for Cash). When the refusal has numbers (from the server for Training Grounds and Rebirth, never parsed from text), a slim bar shows "7 / 10" or a percentage with a line like "3 more Rebirths to unlock" or "$15M more to go". Errors, Rebirth complete and World unlocks unfocus the screen: the menus' shared blur (9) and a 45% dark tint over the HUD. Routine notices float with neither, and nothing blurs during the hit cinematics or the portal trip. A notice fades in and out quickly and stays about 2 s (2.6 s with a bar, 8 s for unlock and offline notices). It never takes input, and any tap or click dismisses it early. A new notice replaces the old one, and clearing one, even mid-fade, always hands the blur back. Errors inside an open menu with a feedback line still use that line. `UI.Notify(message, kind, details)` still takes plain text, with `details` optional.
- **Training:** the HUD stays on screen while training (counters, the Level / Power bar and the menu tiles) and no status panel appears; the red Leave button or Space ends training. A menu tile tapped while training leaves training first, then opens its menu (menus can't open while training).
- **Scaling:** windows scale with the skill's responsive rule (1050×620 baseline, clamped 0.52 to 1.18) times `UI.MenuScale` (0.95), never below `UI.MenuMinScale` (0.75) so menus stay large and tappable on phones. The window is capped by the screen, so it never goes off-screen.
- **Rebirth:** follows the skill's Rebirth archetype: green "Rebirth N ➡ Rebirth N+1" comparison cards (Power multiplier and Level Cap), an orange-to-gold Level progress bar, and a recessed requirements box, above the Reset/Keep/Gain cards.
- **Quick menu:** a 2×2 tile design matching the Inventory tabs (thick dark outline and bevel, textured blue face, colored top accent bar, large icon, outlined label) with Shop, Rebirth, Inventory, and Rewards. Rewards is a placeholder that shows "coming soon". A wide **Training** tile sits under the grid, and a **Batting** button sits under the level bar (it replaced the Rebirth Available shortcut; Rebirth is still in the quick menu):
  - **Training** teleports the player to their best usable Training Ground (see below).
  - **Batting** uses the `TeeTeleport` remote, which takes no arguments. It places the player 7 studs behind the batter's box of their current world, facing it, so batting never starts by itself. It shows whenever the level bar does, and is refused during a hit or while already batting.

  Both teleports show no message on success, only an explanation when refused.
- **Level bar:** styled as a baseball: white, with progress filling it as bold red diagonal stripes (the bar's only red; no seams, stitching or progress line).
- **Batting tee:** each station is dressed with `ServerStorage.RunwayAssets.BattingTee`, from `tools/blender/batting_tee.py`, styled in FieldBuilder: a rubber home-plate base with a white plate top, a steel tube with an orange band, an adjustment collar with a knob, and a ribbed rubber tube and cup. The original Base, Stem and HomePlate stay as invisible colliders, and `Tee.Stem.BallPosition` remains the launch point; the cup lip sits exactly at it.

### Inventory

`InventoryClient` opens from the Inventory tile in the showcase menu style (`UI.ShowcaseMenu`, shared with the Worlds menu; each menu picks a colour theme from `UI.ShowcaseThemes`: Worlds and Inventory both blue with a white-to-cyan title, the Inventory's tabs and cards tinted blue and its selected tab bright cyan): a big rounded title over a coloured, faintly checkered rounded window with a thick black outline, a dark well for the content and a red rounded close button. Three tabs (Bats, Balls, Juice: a picture over the name) stand down the left, sticking out of the window; the selected one turns blue. The title follows the tab ("My Bats" with a bat beside it), with a count under it ("3 / 10 Bats").
- **Bats / Balls:** only the items you own, as square picture cards (the item's designed model in a ViewportFrame, from `ReplicatedStorage.BatModels` / `BallModels`, which `ItemDisplay.PublishItemModels` fills; a plain stand-in if a model is missing) with the multiplier along the bottom in green: a Power bolt and "x2.5" for bats, a Cash icon and "x1.3" for balls. No names or text lines. The equipped item has a blue frame and a green tick. Tapping an owned item sends the existing `EquipmentUpgrade` "Equip" intent; the server validates it and the result shows as a notification.
- **Juice:** owned and active juices as cards with the multiplier along the bottom and the count ("x3") or time left ("1:57") on top; active ones are framed and ticked. Tapping drinks one. With nothing owned, an empty-state message explains juice.
- Purchasing stays in the Shop.

### Leaderboard stats (Schema 9)

Schema 9 adds two saved stats for the global leaderboards (see Global Leaderboards), inside the existing `PlayerProgression` save. Older saves start both at zero; a malformed value (negative, fractional, too large or not a number) fails closed like Cash, so a known value is never overwritten.
- **TimePlayed:** whole seconds in the game across all sessions. Server-authoritative: the saved total plus this session's time from the server's own clock (`os.clock`), stopping when the player leaves. It is saved with every normal save (autosave, leave, shutdown); no extra writes.
- **RobuxSpent:** verified Robux spent in this experience, counted only from purchases the server can verify, never from the client:
  - game passes bought through an in-game prompt (`PromptGamePassPurchaseFinished` with `purchased` true, which Roblox fires on the server), at Roblox's price (`GetProductInfo`), or the configured `robuxPrice` if that lookup fails;
  - developer product receipts through `PlayerData.RecordRobuxReceipt(player, receipt)`, called once a developer product is granted (the Welcome Back 3x offer and the Power, Cash and juice products, through `ProductServer`).
- **No double counting:** `RobuxPurchases` saves what has been counted: game pass ids (`Passes`) and the 50 most recent receipt `PurchaseId`s (`Receipts`). A repeated event or receipt, in the same session or after a rejoin, adds nothing.
- **Limits:** passes bought outside the game (such as on the website) and purchases from before tracking began are not counted, and nothing is estimated. Both training passes have `gamePassId` 0 for now, so no Robux can be spent yet and the Robux Spent board shows R$ 0 until the passes are created.

### The Shop (Robux)

The HUD's Shop tile opens the Shop (`ShopClient`, menu "Store"): a purple showcase window with one scrolling list of colourful cards under five headings. It is the game's only shop menu: Bats and Balls are bought with Cash only at their hub display pedestals. Every amount comes from config and server-set attributes; ids still 0 show a grey SOON button. Details and ids: `MONETIZATION.md`.
- **~ PACK ~ Starter Pack** (game pass, 39 Robux): the Catastrophe Bat large on the left, then +10K POWER, +1 REBIRTH, POWER PUNCH x1 and CATASTROPHE BAT, and the buy button (OWNED once owned). Owned at login or bought in game, it is given once ever: the Bat, one Power Punch (not started), a bonus Rebirth (Rebirths +1 and the Level Cap rise; Level, Power and everything else stay, and banked Power levels up), then 10,000 Power through the normal Level path; saved straight away (`StarterPackGranted`). Its bonus Rebirth never counts as the tutorial's Rebirth (only the player's own Rebirth at the Level Cap, `TryRebirth`, does; the bonus one just raises the Level Cap the tutorial waits for). One notice: "STARTER PACK UNLOCKED! +10K POWER • +1 REBIRTH • POWER PUNCH +1 • CATASTROPHE BAT".
- **Catastrophe Bat** (`catastrophe_bat`): an exclusive 2.5x Cash Bat (between Jungle and Amethyst), outside every purchase series, never sold for Cash; Cash only, like every Bat. Its model is built from Parts (`CatBatModel`, the bat-template layout): a cream barrel whose top is a cat's head (cream ears with pink insides, glowing cyan eyes, a pink nose, whiskers), lavender paw prints front and back, gold bands, a dark purple grip wrapped in lavender like a tail, and a curled lavender tail at the knob; a soft cyan glow, a pink-to-lavender swing trail and a sprinkle burst on contact.
- **~ MULTIPLIERS ~** (one developer product per tier): two cards, POWER MULTIPLIER (orange) and CASH MULTIPLIER (teal), each with its icon, the next tier as the change it makes ("2x → 2.5x", from the server's saved tier count), "TIER 2 OF 5 • PERMANENT", what it multiplies, and the Robux button for that tier (MAX and a grey MAXED button once every tier is owned; SOON while that tier's id is 0). Power runs 2x-4x in 5 tiers (129-359 Robux) and Cash 2x-5x in 7 (129-489 Robux). Buy asks the server ("BuyMultiplier"), which prompts only the next tier; the receipt adds it, and "POWER MULTIPLIER 2.5x!" shows. Power multiplies Training, hit and offline Power (never the Power products); Cash multiplies batting Cash and the Cash packs. Permanent, kept through Rebirths, not giftable, never changes distance. Balance: `.vscode/ECONOMY.md`.
- **~ CASH PACKS ~** (developer products): Tiny / Small / Medium / Large for 25 / 59 / 115 / 229 Robux, each worth 15 / 50 / 125 / 300 normal hits of Cash for the player now: a hit at their Level's usual distance (`Progression.GetExpectedHitDistance`, from the measured hits, at most the World's end) in that section of their current World with their equipped Bat and Cash multiplier, no juice. The card shows the amount from the same formula, so it stays meaningful at every stage. The amount is fixed when the player presses Buy (the server quotes it, saves it, then prompts), so a delayed or retried receipt pays exactly that.
- **~ BOOSTS ~** (developer products): Boost Bundle (2 Power Punch + 2 Cash Splash, 95 Robux) above Power Punch and Cash Splash (39 Robux each), with the juice-box models. Bought juices go to the Inventory; the player chooses when to USE them.
- **~ TRAINING GROUNDS ~**: Dragon's Lair (30x, 1000 Robux) always, beside the premium ground in the player's World: Cosmic Rift (World 1, 10x), Time Machine Lab (World 2, 35x) or Quantum Lab (World 3, 120x), all on Cosmic Rift's one 500 Robux pass. Buying asks the server (TrainingRequest "Buy"), exactly as at the cage; owned passes show OWNED. The list follows the player's World. Each card's top half is a 3D preview of the ground's own cage (a clean copy the server publishes to `ReplicatedStorage.TrainingGroundModels`, framed from above one side), then its name, "30x POWER", and the Gift and Robux buttons.
- **Gifts:** every Shop item also has a square Gift button (a present). It opens a picker of the other players in the server (headshot, display name, @username), then "Gift Power Punch to Josh?" with the price and GIFT / CANCEL (ALREADY OWNED for a permanent item they have). The buyer pays through a gift developer product at the same price; the server saved the recipient (and a Cash pack's amount, from the recipient's own progression) before the prompt, and the receipt queues the gift on the recipient's record so it arrives even if they left (at their next login), exactly once. A gifted Training Ground is a saved entitlement that opens the same grounds as its pass. Details: `MONETIZATION.md`.

### No hotbar

The Roblox backpack hotbar is off (`HUDClient`), so the Bat can't be equipped by hand with the number keys; the batting and Training stations equip it themselves and put it away afterwards.

### Power purchases and Auto Bat

Details, ids and setup steps: `MONETIZATION.md`.
- **Power purchases:** three buttons in a row under the Level bar, as wide as it, with the Batting button below them: yellow "+10K", red "+100K" and rainbow "+1M", each with the Power bolt leaning out behind the amount and its price in green with the Robux icon in the corner (SOON while the developer product id is 0). They show and hide with the bar. A purchase adds exactly that Power (no Ball, Rebirth or juice multiplier) through the normal Level path, so Level-ups, banking at the Level Cap and the tutorial follow; "+10K POWER" confirms it.
- **Auto Bat:** a game pass, one button at the very top centre (the flight distance shows just under it), with a bat leaning across its left edge: red "AUTO BAT / ONLY [Robux] 25" until owned, then grey OFF / green ON. It starts OFF each session. While ON, every time the player could swing at the plate (no hit in play, ball back on the tee, past the cooldown) and the last hit settled a second ago, the Bat presses Swing for them; the server checks the swing as usual. It shows while batting and in flight, under the tutorial banner during the tutorial, and hides with menus and cinematics.

### Juice (Schema 7)

Juice is a consumable drink that grants a temporary, server-timed bonus. Two are defined (`JuiceConfig`):

| id | Name | Effect | Duration |
|---|---|---|---|
| `power_punch` | Power Punch | 2x Power (Training and batting) | 600 s (10 min) |
| `cash_splash` | Cash Splash | 2x Cash (batting) | 600 s (10 min) |

- **Definitions:** `JuiceConfig.DEFINITIONS` entries `{id, displayName, effect, multiplier, durationSeconds, color, appearance}`, validated at load. `effect` is `Power` or `Cash`. IDs are persistent and must never be renamed or reused.
- **Storage:** inside the existing `PlayerProgression` save (Schema 7, no schema change) as `OwnedJuices` (id → count, up to 999) and `ActiveJuices` (id → the Unix time, `os.time()`, the juice ends at). A malformed (non-table) field fails closed like other progression; unknown juices, invalid counts, malformed or impossibly long timers and ended timers are dropped. A small timer value (at most 24 hours) is a save from before real-time timers, holding the seconds that were left; it starts again from login.
- **Real time:** a juice's timer runs on real time, also while the player is offline (10 minutes drunk, 3 minutes played, 2 minutes away: about 5 minutes left on return). The server ends it the moment its time passes (`ExpireJuices`, every second; no client request), and its bonus stops at that moment even before the sweep.
- **Stacking:** drinking a juice that is already running adds its duration to the time left (capped at 24 hours left); it stays 2x, never 4x. Power Punch and Cash Splash run side by side, independently.
- **Server authority:** only `PlayerData` changes juice state. The client's `JuiceRequest` "Use" intent names a juice id only (0.3 s cooldown, `JuiceServer`); the server checks the count, uses up exactly one and sets the expiry. `GrantJuice` is server-only. Grants and uses schedule an important save.
- **Formulas:** Training Power = Training base × ground × Ball × (Rebirths + 1) × Power juice; hit Power = hit base × Ball × (Rebirths + 1) × Power juice; hit Cash = (distance / 80)^1.5 × World × section × Bat × Cash juice. Offline Training never gets a juice. Neither juice changes launch strength, loft, distance, equipment or the Level Cap. Power Punch never touches Cash, Cash Splash never touches Power, and developer product rewards get neither.
- **Hit snapshot:** a hit's juice bonuses are taken when its swing is accepted (with its Ball and Bat). A juice that ends mid-flight still pays that hit; one drunk mid-flight does not boost it. Training reads the juice at each Power grant.
- **Inventory (Juice tab):** a card per juice: its juice box, name, "2x Power • 10 min", "Owned: N", the time left under the box while it runs, and USE (grey at 0).
- **Juice boxes:** `JuiceModels` builds each carton from Parts: body, bands, folded gable top with a sealed seam, a bent straw, and a front label with the juice's icon (Decals, so it shows in ViewportFrames). Power Punch is blue and electric purple with a yellow straw, the Power bolt and thin cyan Neon trims; Cash Splash is green with gold bands, a white straw, the Cash icon, a gold coin and splash drops.
- **HUD:** a pill per running juice on the right edge, a little above the middle ("2x POWER 09:42", "2x CASH 07:31", in the juice's colours), counting down to the server's expiry time. The HUD multiplier and the Training rate previews include Power Punch.
- **Feedback:** "POWER PUNCH ACTIVATED! / 2x POWER FOR 10 MIN" (or "POWER PUNCH +10 MIN" when extending) with a short glug and a light ding (`JuiceDrink`).
- **Getting them:** the Shop sells them (Boost Bundle, Power Punch, Cash Splash) and the Starter Pack includes one Power Punch. In Studio only, on a `StudioFreshSave` throwaway save, the Workspace attribute `StudioGrantJuice` = N gives N of each at login, and `StudioJuiceSeconds` makes a drunk juice last that many seconds (to watch it end).
- **Size:** `UI.SizeScale` (currently 0.75) shrinks the HUD groups, quick menu, notifications, and the Training status box, each around its own anchor (`UI.Shrink`). Windows use their own larger `UI.MenuScale` (see Scaling) and are capped at 680×550 before scaling. The quick menu never drops below 0.45, so phones stay readable and tappable. The HUD's bottom clearance for the Roblox hotbar and touch controls is not scaled.

### World-space UI distance

Floating and surface UI in the hubs shows only while the local camera is near it (measured from the camera, so batting and cinematic views see what is near them), so the hubs never fill with distant labels. Builders register each gui with `WorldUIConfig.Register(gui, range)`; `WorldUIClient` checks distances about 7 times a second in one loop, shows a gui inside its range, hides it only 10% past it (no flicker on the edge), and fades over 0.2 s. A hidden gui is culled through `MaxDistance`, so whoever owns its `Enabled` keeps it. Ranges (`WorldUIConfig.Ranges`, studs):
- Ball/Bat pedestal labels 65, the batter's box "STEP HERE TO BAT" 80, Training Ground labels 75 (about three cages at once down the row), the BALLS/BATS titles 140, the portal's WORLDS sign 200, the leaderboards 240 (readable from anywhere in the plaza).
- Each Training Ground has a floating label over its door, all at one height just above a standard cage's roof and drawn on top of the scenery (themed cages rise higher): its name, UNLOCKED (green) or what it still needs (red: Rebirths or the Robux pass), and its Power multiplier (gold).
- Left as they were: runway section titles and distance markers, the cage banners and lock signs painted on the cages, and the hub's World signs and scoreboard (environmental signage).

Visibility is presentation only: prompts, buying, Training access and travel never depend on it.

### Training teleport

The quick menu's Training tile sends an intent-only `TrainingTeleport` request (a RemoteEvent the server creates at runtime). `BattingTimingServer`:
- refuses it during an active hit or while already training, with a message
- shares World Travel's 1-second cooldown
- places the player 9 studs from the Training plate, facing it, so Training starts only when they step on
- goes to the ground in the player's current World when it stands there (Dragon's Lair stands in every World), otherwise to the first unlocked World it stands in, travelling there with the same `relocate` cleanup as World Travel (ends batting, Training, and active hits, and bumps the batting session)

With no ground named (the quick menu tile), it picks the best usable ground across all unlocked Worlds, so it can travel between Worlds.

### Earlier pass (Milestone 19B)

UICommon owns Check-UI presentation inspired by the four navigation tiles: rounded cyan faces, dark outlines, inset highlights, translucent navy shells, recessed state-colored cards, and outlined GothamBlack typography. Equipment uses a pink accent, Rebirth purple, Worlds cyan, Training gold, and Welcome Back blue. Shared controls have centered hover/press motion and menus have a brief opening pop. Existing client controllers and HubInterfaces still own the same gameplay intents. Only one hub modal is shown at a time; activity, travel, and character cleanup close menus and release the single local blur.

The HUD shows icon-based Cash/Rebirth counters, current world, and a blue studded Level/Power bar with Level Cap and Ball × Rebirth Power gain. Power fill changes tween locally. QuickMenu keeps its 2×2 tile design and opens Shop, Rebirth, Training (the Training Grounds selector), and Worlds (the World Travel menu) in every world; the unimplemented Inventory/Rewards stubs are retired. Equipment and Worlds use numbered badges rather than invented preview art. Equipment prices, ownership and action states remain separate and readable. Rebirth has a distinct confirmation view; Cancel sends no gameplay request. Short landscape screens compact the headers and confirmation content, and scrolling keeps actions accessible. Portrait cards stack their actions. Mobile modal actions use 52–54 logical pixel targets with a minimum 0.8 scale. Explicit Swing/Leave buttons invoke the existing Tool and server requests; click/Space still work. Touch movement and the hotbar are restored after menus/activities. No progression or reward calculation moved to the client.

Offline gains are already granted by the server. CONTINUE only dismisses the once-per-login presentation; the Power icon and rotating sunburst are cosmetic. Hit results separate distance, Cash and Power and expire after six seconds. Shared notifications replace the current notice and suppress immediate duplicates. Icons reuse already approved image references; the CheckUIIcons registry was not installed in this place. The Worlds globe is made from UI geometry. This presentation pass adds no new systems, monetization controls or environment changes.

## World 1 Runway Themes

World 1's open field is replaced by a 160-stud-wide runway (`WorldConfig` `runway.width`); World 2 has its own (see World 2 Runway Themes). Width is per-world through `Field.GetWidth(world)` (a world without a `runway` would use the original wide field), and the out-of-runway check uses it.

The runway is divided into ten themed sections. `FieldBuilder` builds the collidable ground; `RunwayDecor` builds all scenery from `WorldConfig`:

| # | ID | Name | Distance (studs) | Cash multiplier |
| --- | --- | --- | --- | --- |
| 1 | grass | Meadow Run | 0–300 | 1.00 |
| 2 | snow | Frost Pass | 300–800 | 1.15 |
| 3 | stone | Crystal Ridge | 800–1300 | 1.35 |
| 4 | desert | Golden Dunes | 1300–1800 | 1.35 |
| 5 | candy | Candy Crossing | 1800–2300 | 1.35 |
| 6 | jungle | Emerald Grove | 2300–2800 | 1.35 |
| 7 | lava | Ember Canyon | 2800–3300 | 1.35 |
| 8 | neon | Neon Circuit | 3300–3800 | 1.35 |
| 9 | sky | Skyway | 3800–4400 | 1.35 |
| 10 | cosmic | Starlight Finish | 4400–5000 | 1.35 |

The first three IDs and all reward thresholds are unchanged from the earlier Grass/Snow/Stone layout; sections 3–10 subdivide the former Stone tier without changing its 1.35× Cash multiplier. The World 1 endpoint (5000) and 2000-stud runout are unchanged.

Scenery (all cosmetic):

- **Floor:** each section's `material` sets the ground's look only. Ground physics stay fixed through an explicit `CustomPhysicalProperties`, so materials never change bounces or rolling. Optional per-section extras: `floorPattern` (a faint caustic texture), `floorGrid` (neon grid lines), `floorCracks` (glowing lava cracks), `floorTiles` (thin grout lines in a square grid) and `floorPlanks` (lengthwise plank lines). Flush edge stripes line both sides, and a checkered band marks each section start.
- **Walls:** two-tone checkered walls (`wallHeight`, `wallThickness`, `wallTileLength`) with a rounded cream cap. `wallTileColor` can override the light tile color for dark themes.
- **Decks and props:** a raised deck behind each wall (`deckWidth`, `deckMaterial`, optional `deckColor`, e.g. snow) holds the section's `props`, cycling every `propSpacing` and staggered between sides. Props are scaled up by `propScale`, and small filler clusters by `fillerScale`. Disc-shaped props (lollipops, the rainbow) face back toward the tee.
- **Backdrop:** outer ground (`outerGroundWidth`) with large themed shapes (`backdrop`) every `backdropSpacing` for a horizon.
- **Section titles:** each section's name floats as text on a fully transparent, non-colliding anchor 40 studs up, facing the tee (Meadow Run's floats at 60 studs so it is not over the batter). There are no physical gates or signs. A checkered finish line and the giant end portal (see End portal) mark the 5000-stud endpoint, and plain walls continue through the runout.
- **Mesh props:** props listed in `RunwayDecor`'s `MESH_PROPS` use imported Blender models from `ServerStorage.RunwayAssets`, tinted per section. These templates live in the place file, not Rojo/Git, so the place must be saved after importing. Generator scripts and FBX exports are in `tools/blender/` and `assets/models/`. If a template is missing, the prop falls back to its primitive-part version. Every runway prop, filler, and backdrop now has a mesh template (31 in total):
- `MeadowTree` (`tools/blender/meadow_tree.py`): Meadow and jungle trees, and the jungle canopy backdrop.
- Batch 1 (`batch1_props.py`, `RunwayBatch1.fbx`): `Mushroom`, `FlowerPatch`, `Fern`.
- Batch 2 (`batch2_props.py`, `RunwayBatch2.fbx`): fillers `Bush` and `Rock` (per-section `fillers` list, default both), plus Candy Crossing's `Lollipop`, `Cake`, `Gumdrops`, and `CandyCane`.
- Batch 3 (`batch3_props.py`, `RunwayBatch3.fbx`): `Pine`, `Snowman`, `Ice`, `Crystal`, `Geode`, `Cactus`, `Mesa`, `Dune`, `Spire`, `LavaRock`, `Beacon`, `Arch`, `Cloud`, `Rainbow`, `Island`, `Planet`, `Star`, `Moon`, and backdrops `Mountain`, `Volcano`, `Hill`.

Shared Blender helpers live in `tools/blender/prop_helpers.py`. Every model is authored under ~20 units so the import stays below Roblox's 2048-stud part limit; backdrops are scaled up through `BACKDROP_MESHES`. Mesh definitions can also set `materials` (Neon for glowing parts), `lift` (floating props), and `faceTee` (`true` allows a half turn; `"exact"` plus `yawOffset` keeps an authored front toward the tee).

Roblox imports these FBX files at 100× scale; templates are scaled back to their Blender size (1 unit = 1 stud) and pivoted at their base.

The runway has no floating distance labels or floor tick lines; the live HUD shows distance during a hit.

## World 2 Runway Themes

World 2 (Time Travel) has the same 160-stud runway and scenery system as World 1, ten sections in time order, each matching a World 2 ball. The Cash multipliers keep World 2's earlier thresholds (×1 to 500, ×1.15 to 1500, ×1.35 beyond); the endpoint (6000) and 2000-stud runout are unchanged.

| # | ID | Name | Distance (studs) | Cash multiplier | Props | Backdrop |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | prehistoric | Prehistoric Valley | 0–500 | 1.00 | cycads, egg nests, fossils | brontosaurus |
| 2 | stoneage | Stone Age Camp | 500–1000 | 1.15 | stone huts, tusk arches, campfires | standing-stone circles |
| 3 | egypt | Pharaoh's Sands | 1000–1500 | 1.15 | obelisks, sphinxes, scarab pillars | pyramids |
| 4 | greek | Olympian Heights | 1500–2100 | 1.35 | column ruins, amphorae, hero statues | temple |
| 5 | viking | Viking Fjord | 2100–2700 | 1.35 | longships, rune stones, shield racks | snowy peaks (World 1's Mountain) |
| 6 | samurai | Samurai Gardens | 2700–3300 | 1.35 | torii gates, stone lanterns, cherry trees | pagodas |
| 7 | knight | Knight's Kingdom | 3300–3900 | 1.35 | banners, catapults, armor stands | castle |
| 8 | frontier | Frontier Town | 3900–4500 | 1.35 | water towers, covered wagons, cacti | red buttes (World 1's Mesa) |
| 9 | foundry | Clockwork Foundry | 4500–5200 | 1.35 | gear towers, boiler pipe works | factory smokestacks |
| 10 | chrono | Chrono Nexus | 5200–6000 | 1.35 | time rings, floating hourglasses and holo clocks | futuristic spires |

The 37 new meshes come from one generator, `tools/blender/runway_world2.py` (export `assets/models/RunwayWorld2.fbx`, plus a `RunwayWorld2.json` manifest of template → mesh names used to group the import into `ServerStorage.RunwayAssets`). Fillers reuse World 1's `Fern`, `Pine`, `Bush` and `Rock`, plus a new `Barrels` cluster. The hourglass glass is see-through (`transparency` in its mesh definition). A section whose mesh template is missing simply skips that prop.

Every `RunwayDecor` part is anchored with collision, touch, and query disabled, so scenery cannot affect ball flight, measured distance, rewards, or camera occlusion. The full runway is about 3,000 decoration parts.

## World 3 Runway Themes

World 3 (Future World) is a trip from a near-future city out to the edge of reality, on the same 160-stud runway and scenery system, ten sections each matching a World 3 ball. Its endpoint is 7000 studs (plus the 2000-stud runout); the Cash multipliers follow the earlier pattern (×1 to 600, ×1.15 to 2000, ×1.35 beyond). Its stadium sits 16,000 studs along X from World 1's (`offset`).

| # | ID | Name | Distance (studs) | Cash multiplier | Props | Backdrop | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | solar | Solar Suburbs | 0–600 | 1.00 | eco homes, wind turbines, solar flower lamps | wind farm | paving tiles, green lawns |
| 2 | maglev | Maglev Highway | 600–1300 | 1.15 | hover cars, maglev pylons, hologram road signs | maglev viaduct with a train | asphalt lanes, glowing centre line |
| 3 | metropolis | Skyline Metropolis | 1300–2000 | 1.15 | hologram billboards, neon street lamps, flying sky taxis | glass skyscrapers | polished plaza tiles |
| 4 | robotics | Robo Assembly Line | 2000–2700 | 1.35 | robot arms, conveyors, robots on assembly stands | mega factory | steel plate, hazard stripes |
| 5 | biodome | Biodome Gardens | 2700–3400 | 1.35 | biodomes, alien plants, glowing mushrooms | giant domes | moss |
| 6 | virtual | Virtual Grid | 3400–4100 | 1.35 | floating data cubes, voxel trees, glitching pillars | voxel mountains | black with a green neon grid |
| 7 | spaceport | Orbital Spaceport | 4100–4800 | 1.35 | rockets on pads, radar dishes, fuel tanks | launch towers | concrete with runway markings |
| 8 | lunar | Lunar Colony | 4800–5500 | 1.35 | habitat pods, lunar landers, flags | moon ridges | grey dust with crater rings |
| 9 | mars | Red Planet Outpost | 5500–6200 | 1.35 | Mars rovers, terraformer towers, red-dusted habitats | red buttes (World 1's Mesa) | rust sand with crater rings |
| 10 | singularity | Quantum Singularity | 6200–7000 | 1.35 | energy ring gates, floating quantum shards, rift rocks | giant floating shards | violet glass with glowing reality cracks |

- **Models:** two generators share World 2's helpers: `tools/blender/runway_world3_city.py` (sections 1–5, `assets/models/RunwayWorld3City.fbx`) and `runway_world3_space.py` (sections 6–10 plus the black hole, `RunwayWorld3Space.fbx`), each with a JSON manifest for grouping the import into `ServerStorage.RunwayAssets`. Fillers are new planters, cargo crates and voxel bushes plus World 1's flowers, ferns, bushes and rocks. Sky taxis are the hover car lifted high; the Mars habitats are the lunar pod dusted red; the glowing mushrooms are World 1's mushroom in neon.
- **Floor patterns** (`RunwayDecor`, flags on the section): `floorLanes` (a glowing centre line and dashed lane lines), `floorHazard` (yellow and black warning bands along both edges) and `floorCraters` (crater rings scattered deterministically), alongside the earlier tiles, grid and cracks.
- **Landmark:** `runway.landmarks` places single giant meshes by their centre. World 3 has one, a black hole with a glowing accretion disc looming above and behind its end portal (7550 studs downfield, 760 up, about 670 studs across).

## World 4 (Tiny Town)

World 4 is being built in phases from `.vscode/WORLD4_DESIGN.md` (concept, sections, hub, grounds, Balls, portal trip and the phase checklist). Phase 1 is in: `world_4` in `WorldConfig` (offset 24,000, end 8,000, start pay 500,000 and Cash ×600, Levels 370-490, ten sections from Giant Backyard to Pillow Fort with reward tiers 1.0× to 700, 1.15× to 2,100 and 1.35× beyond), the finale at its end portal (World 3's portal now leads to World 4), its row of grounds (Sandbox Diamond, Pinball Cage, Cereal Bowl Stadium, Toy Soldier Fort, Snow Globe, Dragon's Lair; each toy ground has its own custom cage, see Era and toy cages), and its ten Balls as the `world_4` series. Until the later phases its runway uses existing primitive props tinted in its colours, its hub the plain floor and its Balls their `EquipmentConfig` colours. Balance: `.vscode/ECONOMY.md`.

**Hits start over in each World** (Worlds 2-4; World 1 is unchanged). A World's `launchLevels` (`from` = the Level where it opens, `to` = the Level where its end is reached: World 2 150-250, World 3 250-370, World 4 370-490) pick the launch through `ProgressionConfig.GetWorldLaunchLevel`: below `from` the early floaty arc (99-143 studs), then even growth in studs to the end portal at `to`, so each run sweeps two or three of the World's sections and its end is still reached at the same Level. Each later World pays a start pay (`cashBase`) on top of its distance pay, so even its first 99-stud hit pays more than the previous World's best (3.9-4.5×). In an earlier World a later player hits its end every time, at that World's lower pay. World 4 also sells the **Rolling Pin Bat** (42×, $1.65B), bought midway through it.

## Hubs

### Shared compact hub layout

Every World's hub uses one compact layout (`WorldConfig` `hubLayout`), so a player knows where everything is in any World; only the art differs. Positions are in the hub frame: origin at the tee, +Z back into the hub, +X to the right when facing down the runway. The spawn stands just behind the batting area looking **into** the hub, with the runway behind it, so from the spawn **left is +X and right is -X**:

| Zone | What stands there | Hub frame |
| --- | --- | --- |
| Front | the batting circle round the tee; the runway beyond it, behind the spawn | z 0-20 |
| Spawn | arrival point, facing into the hub (every World's `arrival`) | x 0, z 30 |
| Left | the World's row of six Training Grounds, the first beside the batting area, doors facing the middle | plates x 56, z 18-183; scenery x 36-113 |
| Right | the item displays: the World's balls, then the bats, facing the middle | front edge x -36, z 68-144 |
| Middle | an open plaza (x -26 to 26) with a path from the spawn to the back, and the World's event piece in it | event square centre z 118, 40 across |
| Back | the World portal in the middle, facing the spawn; the four global leaderboards stand either side of it, in every World | portal x 0, z 205; boards x ±22 and ±37, z 207 |

- **Footprint:** the hub floor spans x -56 to 118 and 220 back (`hub.minX`, `hub.maxX`, `hub.depth`): 174 × 220 studs, down from 222 × 222. Only the Training Grounds' side reaches past the runway (x -86 to 86 with its walls); on the other side the runway's edge meets the corner of the stands. The depth is set by the row of six cages (each needs 33 studs).
- **Paths** (`HubDecor` `hubPaths`, the same in every theme): a cross path in front of the spawn from the display lane to the Training Ground lane, a short path to the batting circle, an 8-stud lane along the cage doors and one before the displays, both running on to a back path that leads to the portal, and a path up the middle of the plaza past the event piece. They follow the configured positions, so moving a group moves its paths.
- **View from the spawn:** the cages fill the left, the displays the right, and the path runs straight up the middle to the portal and the leaderboards; the World's landmark (scoreboard, clock tower or beacon tower) rises behind the portal. Event pieces stay flat (World 3's hologram globe floats high) so nothing hides the portal.
- **Stairs:** each display has a staircase (`stairSide`) beside its outer end, the Ball display's toward the spawn and the Bat display's toward the back, climbing in 0.75-stud steps with red nosings and handrails to the top tier. The top row's pedestals stand 1.3 studs further back so a 3-stud walkway runs in front of them.
- **Display rows:** each further row of a display rises above the one in front (`ItemDisplay`: label height + half a label + half an item + a small gap), so its items sit above the front row's labels and no names or prices overlap. Prompts reach 14 studs, plus 10 per row back, so the whole display can be used from its lane.

### Hub themes

Each World's hub can have its own look. `WorldConfig` `hub.theme` names a builder in `HubDecor`, which runs from `FieldBuilder.buildHub` into `<Hub>.Decor`. A themed hub supplies its own walkable floor, so the plain grey floor and boundary strips are skipped. Hub stations, item displays and Training Grounds are built the same way for every theme.

**Home Field (World 1)** is a sunken ballpark.
- **Ground:** 12 mowing stripes of grass form the floor, with the shared paths in dirt and a dirt batter's circle behind the tee. A white home plate marks the spawn.
- **Plaza:** an infield diamond for events (`hub.eventArea`: dirt with an inner grass square, white bases and a pitcher's mound). A gold-ringed pad at the back holds the World portal (`hub.portalPad`), between the global leaderboards (see Global Leaderboards).
- **Walls:** a padded green outfield wall with a gold cap runs along both sides and the back, with an invisible barrier above it to 14 studs and red, white and blue bunting along the top.
- **Stands:** aluminium bleachers on both sides and across the back, five tiers with red and blue seats. They climb to a grass berm that is level with the runway's outer ground (9 studs), so the park sits in a bowl that meets the runway decks.
- **Landmarks:** yellow foul poles where the runway walls begin, four light towers on the berm corners with spotlights on the field, and a "HOME FIELD / WORLD 1" scoreboard on tall legs behind the back stand, rising above the portal.
- **Treeline:** trees, bushes and hills on the berm, reusing the runway's `MeadowTree`, `Bush` and `Hill` meshes through `RunwayDecor.PlaceMesh`.

**Time Travel (World 2)** uses the shared layout, styled as a sunken clockwork plaza:
- **Floor:** a lavender checkerboard of large tiles with thin brass seams, brass walkways (the same paths as World 1), a cyan glowing ring round the batter's circle, and a small clock rosette at the spawn.
- **Event area:** a giant clock face (`hub.eventArea`) with Roman numerals, hour marks and turning hands.
- **Bowl:** a slate wall with a brass cap and a cyan glow strip, then slate terraces with alternating brass and glowing cyan edges up to a dark slate berm at 9 studs.
- **Landmarks:** a clock tower behind the back terraces (a turning clock and a "TIME TRAVEL / WORLD 2" sign), four chrono lamps, floating gears (the Blender `HubGear` when imported, brass discs until then) and bobbing time crystals.
- **Monuments** from the eras ahead stand on the berm: a stone circle, a stepped pyramid with obelisks and a torii gate on the left; a Greek temple, a castle tower and a torii gate on the right.
- World 2's own "TIME TRAVEL BALLS" display stands in front of the Bats, and the leaderboards stand either side of the portal in ink and brass. World 2's themed runway runs downfield from the tee (see World 2 Runway Themes).

**Future (World 3)** uses the shared layout, styled as a sunken spaceport plaza:
- **Floor:** a checkerboard of large white tiles with thin glowing cyan seams, dark navy walkways with glowing edges (the same paths as the other hubs), a glowing ring round the batter's circle, and a landing-pad marking at the spawn.
- **Event area:** a hologram stage (`hub.eventArea`): a dark dais ringed with light, a short glowing emitter and a pulsing hologram globe floating 40 studs up (above the spawn's view of the portal), and two tilted rings of lights orbiting it (cyan and pink).
- **Bowl:** a white wall with a gunmetal cap and a cyan glow strip, then white terraces with alternating glowing cyan and white edges up to a dark concrete berm at 9 studs.
- **Landmarks:** a beacon tower behind the back terraces (white fins round a glowing core, a ring of light turning round its crown, a pulsing beacon and a "FUTURE WORLD / WORLD 3" sign), four holo lamps with bobbing lights, and hovering drones over the plaza.
- **Skyline:** glass skyscrapers with glowing bands and blinking spire lights on the berm, tallest at the back. Once imported, World 3's runway models join them through `RunwayDecor.PlaceMesh`: a rocket, a launch tower and a radar dish on the right; a biodome, an eco home, a solar tree and a row of wind turbines on the left; hover cars floating behind the beacon.
- World 3's "FUTURE BALLS" display stands in front of the Bats, and the leaderboards stand either side of the portal in gunmetal and holo cyan.

Hub scenery and portal parts can carry motion attributes (`Spin`, with an optional `SpinPivot` to turn about a point such as a clock centre, `Bob`, `Sway`, `Pulse`); `TrainingStadiumClient` animates them in every hub on each client.

### World portals

Each hub with a `portalPad` gets a World portal on it (`WorldPortal.luau`), at the back of the hub in the middle (hub x 0, z 205), facing the spawn down the plaza (`portalPad.yaw` 0). The model is `ServerStorage.RunwayAssets.WorldPortal`, built by `tools/blender/world_portal.py`: an octagonal brass clockwork frame with iron bands and rivets, a swirling cyan vortex, an alarm clock on top with turning hands, hourglass lamps on the sides and two turning gears. It is scaled to 26 studs tall. Until it is imported, a plain octagon of parts stands in. A floating sign reads "WORLDS / TRAVEL PORTAL / Step in to choose a World".

**Future portal (World 2):** a World's portals wear the look of the World they lead to. World 2's hub portal and the giant portal at the end of its runway lead on to World 3, so they use `RunwayAssets.FuturePortal` (`WorldConfig` `portalModel`, built by `tools/blender/future_portal.py`) instead of the clockwork model: a smooth white composite ring with a gunmetal inner lip, eight clamps with glowing slots and a glowing inset ring, a segmented halo of light turning round the frame, a floating magenta crystal spinning on top, a stepped hexagonal platform with glowing step edges and two emitter posts, and a violet vortex with a pink swirl. Its looks live in `WorldPortal.luau` (`LOOKS.FuturePortal`); the vortex keeps the shared `PortalVortex` / `PortalSwirl` names, so the trigger, the ball capture and the trip work the same. World 1's and World 3's portals keep the clockwork look; if the Future model is missing, the clockwork one is used.

The portal is not a teleporter. An invisible `Trigger` fills the opening, and stepping into it opens the Worlds menu on that client (`WorldTravelClient`), once per entry and only when another menu can open (not while batting, training, in a hit or travelling). The menu lists every World with its theme name and state (Worlds 1 to 3 for now). Choosing one sends the normal `WorldTravel` request, which the server checks against the unlock before relocating the player.
**Worlds menu** (`WorldTravelClient`, showcase menu style): a "Worlds" title over the window and one big picture card per World in a scrolling list. Each card shows a picture of the World's hub (`WorldConfig` `preview.image`: a high Studio capture looking into the hub from over the runway, cropped to the card's 3.4:1 shape and uploaded as an image; a World without one shows a painted scene in its `preview` sky and ground colours instead). After a hub redesign, retake and re-upload its picture, the World's name and theme over the top-left, what unlocks it along the bottom-left for a locked World ("REACH 5,000 STUDS IN WORLD 1", which is also shaded darker), and a chunky status button on the bottom-right: YOU ARE HERE (blue, and the card gets a blue frame), TRAVEL (green, sends the trip request), PLEASE WAIT (grey) or LOCKED (red; pressing it shows the requirement). Results and errors show as notifications.

### Global leaderboards

Every World's hub has the four physical global leaderboards, two either side of the portal at the back (`WorldConfig` `hub.leaderboards`, part of the shared `hubLayout`; built and refreshed by `Leaderboards.luau`, started by `LeaderboardServer`). Left to right from the spawn: **TOP LEVEL**, **TOP TIME PLAYED** | portal | **TOP ROBUX SPENT**, **TOP CASH**. Each board turns toward the plaza so the four read as one curved wall. They show the same global rankings in every World (each refresh reads each store once and fills every hub's boards); only their look follows the World (`Leaderboards` STYLES, by hub theme): the ballpark scoreboard green and gold in World 1, ink and brass in World 2, gunmetal and holo cyan in World 3, dark wood and toy yellow in World 4.

- **Look:** a green scoreboard panel (the ballpark scoreboard's colour) with a gold trim on two steel posts, a coloured header bar, a bold outlined title in the board's colour (Level blue, Time Played violet, Robux Spent green, Cash gold), "GLOBAL - TOP 10", ten ranked rows (#1 gold, #2 silver, #3 bronze) with the player's name and value, and a status line ("Updates every minute", "No scores yet", or "Couldn't update - retrying soon" while keeping the last rows). The SurfaceGui is unlit so it stays readable, and fades out beyond 220 studs.
- **Values:** current Level (it resets on Rebirth; not the highest ever), current Cash (it drops when Cash is spent; not total earned), Time Played as `45m`, `2h 14m` or `3d 7h`, and Robux Spent as `R$ 1,500`. Large numbers are compacted (`$31.2M`).
- **Source of truth:** PlayerData's save. Each board reads an OrderedDataStore that mirrors one saved field, keyed by UserId: `GlobalLeaderboard_Level_v1`, `GlobalLeaderboard_TimePlayed_v1`, `GlobalLeaderboard_RobuxSpent_v1`, `GlobalLeaderboard_Cash_v1` in live servers (Studio uses `Studio_` copies, below).
- **Writes:** after each successful save, `PlayerData.OnSaved` hands the saved record to `Leaderboards.Submit`, in its own thread. A flush every 10 seconds writes a player's changed values at most once every 2 minutes while they play, and right away for the save made as they leave (and during shutdown). Unchanged values are not written; nothing is written per second or per Power tick. Writes check the sorted-store request budget first.
- **Reads:** every server re-reads the four stores once a minute (top 10, highest first), if the read budget allows. Names come from the player when they are in the server, otherwise a cached `GetNameFromUserIdAsync` lookup (at most 10 new lookups per refresh; a failed one waits 5 minutes before retrying; "Unknown" meanwhile).
- **Failures:** every write, read and lookup is wrapped. A failed write stays pending and is retried next flush (a departed player's after up to 5 attempts it is dropped); a failed read keeps the last rows. Nothing here can block or break gameplay or saves.
- **Studio:** Studio playtests (`RunService:IsStudio()`) read and write separate copies of the four stores, prefixed `Studio_` (`Studio_GlobalLeaderboard_Level_v1` and so on), so test accounts and values never reach the live rankings. Player saves are not separated: Studio sessions still save to `PlayerProgression` and add to that account's real Time Played, which reaches the live boards the next time that account plays in a live server.

## Sky

Each World has its own lighting preset in `WorldLightingConfig` (one file to tune; each World's look is described in `.vscode/ART_STYLE.md`):
- **World 1 (Home Field):** bright midday (the former Daylight preset), with a pale sky-blue distance fade.
- **World 2 (Time Travel):** warm golden hour (the former GoldenHour preset, warmed): a low sun about 22° up behind and left of the batter, peach clouds, an amber horizon.
- **World 3 (Future World):** night: a starry sky and a bright violet-blue ambient; the dark makes the Neon glow, with soft, weak bloom so its many thin strips never shimmer or glare.
- **World 4 (Tiny Town):** a bedroom in the evening under a warm lamp: a low amber sun, peach ambient and a warm haze.

Players in different Worlds share a server, so the server never switches Lighting. `WorldLightingClient` applies the player's World's preset on their own client: at start, whenever the server moves them to a World (`CurrentWorldId`, which a portal trip changes under its white screen) and again whenever a cinematic ends (`CinematicCamera` clears). The hit cinematics, Legendary and Mythic hits and the portal trip only add their own grades and blurs; they never edit the base Lighting. `SkyServer` applies the starting World's preset at server start, so the replicated defaults match World 1.

A preset covers Lighting's own properties, the Atmosphere, Sky, Bloom, SunRays and the place's `ColorCorrection`, and Terrain clouds. Effects are found by name, never by class, so the cinematics' grades are never touched. A property one preset sets and another leaves out returns to the place's value. Lighting edits made in Studio only show in playtests once they are copied into a preset. All values are look-only. The sky does not change per section.

Lighting technology: the place has gone through Roblox's unified lighting migration (it was saved with ShadowMap). `Lighting.Technology` is no longer readable from scripts; the place uses `LightingStyle` Realistic and `PrioritizeLightingQuality` on.

## Hit presentation

All cosmetic; none of it affects launch, distance or rewards.

- **Timing:** every effect starts when the client sees the ball leave the tee (the rendered ball 0.5 studs off its tee spot), not when `BallState` turns InFlight. The attribute arrives about 0.25 s before the ball's smoothed physics movement is drawn, so starting on it put the effects ahead of the ball.
- **Bat crack:** each client plays the `BatCrack` cue (`GameAudio`) on the tee's Stem when any station's ball leaves the tee, so nearby players hear each other's hits in sync (Pro Sound Effects "Wood Bat Hits Hard Ball", with a little added low end). It is on the tee rather than the ball so it does not fly away with the hit. The recording has a quiet lead-in, with the crack itself 0.61 s in, so the cue starts at 0.58 s; it is preloaded so the session's first hit is on time. The cinematics start their impact sounds past any lead-in the same way (the fourth `startAt` value in their `SOUNDS` specs). A Mythic Hit, and the batter's own Legendary Hit, skip this crack, because the cinematic already cracked at contact.
- **Cinematic swing and flight:** from the click that starts a real swing (BatClient fires "SwingStart" on the bat's local marker; Training practice swings do not), `HitCinematicClient` slides in black letterbox bars (11% of the screen each) and adds a light colour grade (contrast and saturation). They stay while the hit is active (`HitActive`) and ease out when it ends; a refused swing lets them slide back out after 1.2 s. The bars sit under the HUD, so the distance counter and 2x/Leave buttons stay on top. The Cash counter is hidden during flight. While the batter's own ball flies, thin white speed lines streak outward from around it across the screen (under the bars); how many there are and how bright depends on the ball's speed (none below 25 studs/s, full from 160), so they thin out as it rolls to a stop. Legendary and Mythic Hits keep their own speed lines instead.
- **Camera:** from the click, the batting camera (`BatTimingClient`) zooms from 55° to 46° FOV through the backswing (Load and Windup, 0.24 s) and holds. When the ball leaves the tee it widens from there to 70° over 0.8 s with a 0.35 s decaying shake. With no launch it eases back out.
- **Ball sounds** (`BallSounds`, run by `HitCinematicClient` for every station): from launch to reset, sounds come from the ball itself, so nearby players hear each other's hits:
  - a wind whoosh while it is in the air, louder and a little higher-pitched with speed, on a gentle curve so slow hits still whoosh a little
  - a landing sound on each bounce, on a volume curve so a hard first landing is clearly heard and the last little hops barely at all. It is timed to the drawn ball: it fires when the ball, at its current downward speed, will reach the ground within the next frame (a hair early, covering a new Sound's start-up), or, when the client's smoothing turns a fast bounce around above the grass, on the frame it turns. One landing per fall; a reset jump back to the tee is ignored
  - a smooth, understated roll once it is on the ground, quieter and lower as it slows (mostly a soft noise bed, with only a faint grass texture)
  - grounded hysteresis: the ball counts as on the ground from its first bounce until 0.25 s without contact, so the whoosh and roll never flicker during bounces
  - light surface variation from the runway section under the ball (raycast to the field's ground parts): soft ground (Meadow, Emerald Grove, Golden Dunes; World 2's Prehistoric, Stone Age, Samurai and Frontier) keeps the muted thud and grass texture; hard floors (Candy, Ember Canyon, Skyway; World 2's Egypt, Greek, Viking, Knight and Foundry) knock and roll firmer; ice, crystal and glass (Frost Pass, Crystal Ridge, Neon Circuit, Starlight Finish; World 2's Chrono Nexus) add a clean clink and roll glassy-smooth
  - for the fancier Balls, their own loop on top (`BallStyles.FlightSounds`), measured against the whoosh so it colours the flight without burying it: about half the whoosh's loudness for gentle themes, up to ~0.9x for the top tiers, and softer once the ball is on the ground

  All loops start at a random point and fade out when the hit ends. All are Roblox-licensed Pro Sound Effects audio. Speeds and volumes are tunable at the top of `BallSounds`.

### Audio

All sound is client-side presentation; nothing in it affects gameplay. `GameAudio` (ReplicatedStorage) is the shared vocabulary and mix: every cue's asset, volume, pitch, lead-in skip and group in one table, plus ducking.

- **SoundGroups:** Music, Ambience, Gameplay (bat, ball, Training), UI (menus, notifications, progression payoffs), Cinematic (Legendary / Mythic). Group volumes are in `GameAudio.GroupVolumes`.
- **Hierarchy** (loudest first, measured): rare-hit climaxes, then Rebirth / World unlock (about the bat crack's loudness), the bat crack, Level Up (about 0.85x the crack), ball flight and hard landings, purchases / equips / Cash / travel, Training feedback, rolling, UI clicks, ambience.
- **Positional vs flat:** physical sounds (crack, swish, ball, Training, cage ambience) come from parts in the world, so nearby players hear them; personal progression and UI play flat for the local player only.
- **Swing:** a short dry swish from the bat, timed so its loudest moment lands as the barrel moves fastest (0.46 s into the swing), just before contact. Skipped if a cinematic already holds the swing.
- **Training:** a soft pitch thump, a quieter swish, a lighter and smaller crack than a real hit, and a barely-there tick with each Power grant (it repeats every 2 s, so it must never tire).
- **Progression:** Level Up is a ~0.7 s electronic "rise -> hit": a quick rising synth swell into a bright ping (PSE "Short Waa Tone Swell" -> "Tone Burst Ping 1"), louder than Cash, Equip and UI confirms; Max Level is the same rise into a stronger ping with a resonant bell ringing on; Rebirth is a triumphant brass fanfare (APM "Triumphant Fanfare", ~5 s) with a magic burst sparkling over its opening; World unlock is an APM reveal sting (~3.4 s). Rebirth and World unlock briefly duck music, ambience and gameplay.
- **Rewards and shop:** a "ka-ching" for a hit's Cash (a register snap, then a bright bell ding with a coin ring under it); a register snap plus a short ding for a purchase (a purchase also equips, which plays only the purchase sound); a mechanical lock-in for equipping; a rising whoosh for World travel; a soft sparkle for Welcome Back.
- **UI vocabulary** (`UICommon`): the shared click; a soft swoosh up on menu open and down on close; a muted thunk when pressing a locked or unavailable button; a soft "no" tone on refusals (error notices); a quiet notice tone for routine updates. Level Up, Rebirth, unlock, offline and purchase notices stay silent because their payoff sounds play where they happen.
- **Ambience** (`AmbienceClient`): a quiet themed loop at each fantasy Training Ground, heard only near its cage (Grove wind and chimes, Atlantis underwater air, Sky Temple high wind, Dragon's Lair slow breathing rumble, Cosmic Rift cosmic air). The hub air bed (`HubAir`) is a placeholder: no licensed outdoor-air loop has been chosen yet. There is no runway ambience; the flight sounds and visuals carry the runway.
- **Music:** none yet. Setting `GameAudio.MusicTrack` to an APM track id turns on one looping track in the Music group, ducked under cinematics and big payoffs.
- **Ducking:** the batter's own Legendary / Mythic Hit ducks music, ambience, UI and gameplay (the ball's own sounds) until the cinematic's audio fades out; Rebirth and World unlock duck the background while they play. Fades are short and smooth.
- **Cleanup:** one-shots remove themselves; ball loops are stopped by `HitCinematicClient` when the ball resets or is gone; cage loops are created once. Repeated hits do not accumulate Sounds (playtested).

### Rare cinematic hits (Legendary and Mythic)

Two rare hits play a cinematic before the ball launches: the **Legendary Hit**, 1 in 1,000 swings, and the **Mythic Hit**, 1 in 10,000. The odds and hold times are `Swing.LegendaryHit` and `Swing.MythicHit` in `SwingConfig`. They are presentation only: the launch, distance and rewards are the same as any other hit.

- **Server:** `BallLauncher.TryLaunch` rolls them when it accepts a swing (Mythic first, then Legendary). A rare hit delays the normal launch by its `HoldSeconds` (Legendary 3.6, Mythic 5.5). The station ball gets `<Kind>HitUserId` and `<Kind>LaunchAt` (server time), cleared when the ball resets.
- **Testing in Studio:** set the Workspace attribute `ForceLegendaryHit` or `ForceMythicHit` to force every hit. With both set, they take turns. Live servers ignore them.
- **Code:** `CinematicFX` holds the shared pieces: effect parts, lightning, shockwaves, sounds, the screen overlay (flash, bars, speed lines, title), the announcement, swing control, the chase camera, and a station watcher. `LegendaryHitClient` and `MythicHitClient` hold each timeline. All audio is Roblox-licensed Pro Sound Effects and APM Music, listed in each script's `SOUNDS`.
- **Swing control:** BatClient's swing clock reads two client-local attributes on the Bat. `SwingHoldAt` stops the swing at that time and fires a "Hold" marker, so a freeze lands on the exact frame. `SwingClockOverride` sets the swing time directly, for freezes, slow motion and replays. Every new swing clears both. `Swing.BallContactTime` (0.492 s) is when the barrel meets the ball. A playtest measured the closest pass at 0.50 s, with the bat touching from about 0.49 s.
- **Camera:** while the Player's client-local `CinematicCamera` attribute is set, `BatTimingClient` leaves the camera alone. When it clears mid-flight, it blends from the cinematic's last shot (relative to the ball) to its normal flight framing over 1.2 s.
- **Other players** see the world effects at that station and hear them from the tee. They get a short announcement ("⭐ Name hit a LEGENDARY HIT! ⭐" or "☠ Name hit a MYTHIC HIT! ☠"). Their camera is untouched.
- **Cleanup:** leaving the box, death or travel stops the cinematic at once (the server cancels the launch when the hold ends). The ball reset clears every effect. Errors are contained, so a broken cinematic can never keep the camera.
- **Audio ends with the pictures:** every cinematic sound is tracked (`FX.PlayFor`) and fades out over the last second of the chase, never playing on past it. The chase ends early, 0.6 s after the check, when the ball is already below 12 studs/s a second after launch, as with a low-Level player's short hit. If the hit ends before the cinematic does, everything fades out within 0.4 s.

**Legendary Hit** (about 7 s from contact; gold):
1. Contact: the swing stops exactly as the bat meets the ball. A white flash, a crack and a boom. The world drains to a cold grey, sparks, dust and a shockwave hang in the air (particle `TimeScale`), and a heartbeat plays.
2. Orbit: the camera circles 200° around the side away from the batter, showing their face. Energy streams into the ball, lightning crackles, and three ribbons orbit it.
3. Charge (last 1.15 s): a flash covers a cut to a low push-in from behind the ball. A pillar of light rises, colour floods back gold, a reverse riser builds to the launch, and "LEGENDARY HIT! / 1 IN 1,000" slams in with a brass sting.
4. Launch (the real ball leaving the tee): a flash, a triple shockwave, lightning from the sky, the frozen debris blasting outward, a boom and a crowd roar. The swing follows through at full speed.
5. Chase (3.2 s): an FOV punch to 88°, speed lines, and a rainbow comet tail on the ball for the whole flight.

**Mythic Hit** (about 9 s from the click; red and black, sinister):
1. Power-up (about 3 s): the batter freezes at the top of the backswing (end of Windup). The world darkens to red. The batter gets a red Highlight and an aura of red flames, black smoke and sparks. Red energy streams in, red lightning crackles, rocks lift off the ground and tumble, and red pulses ripple out. Sounds: a slowed creature growl, the "Arise From The Dead" drone, the "Ice Wave" swell and a slowed heartbeat. The camera is low and off to the downfield side, looking up at the batter and circling in.
2. Three swings, 1.05 s apart: each plays from the windup to contact at 0.4× speed and holds at contact. The angles are over the shoulder from the catcher's side, facing the batter from beyond the tee, then close on the ball from downfield. Each impact is bigger and louder than the last: a black "impact frame" snapping to red, a shockwave, red lightning, smoke, a distorted kick and the crack, with the drone bed dipping for a moment under each hit; the third adds a deep boom. The bars close in a little more each time. "MYTHIC HIT! / 1 IN 10,000" slams in on the third.
3. Launch: a red explosion, a column of red light, eight lightning strikes from the sky, a black smoke burst, the rocks blasting away, a boom, a roar and the "Wounded Symphony" braam. A cut to the chase camera, then a red and black comet tail with smoke and sparks for the whole flight.

## Hit time scale

Rolling made up most of each hit's time: at Level 20, about 2 s in the air and about 17 s rolling. Every hit now plays at one steady time scale from launch, `FieldConfig.HitTimeScale` (1.6): launch velocity ×s, gravity and rolling friction ×s², and the stop checks scaled to match. There is no change of speed during a hit.

This replaced a roll-only fast-forward (3× once the ball was rolling after its first landing). That kept distances but looked like the ball suddenly speeding up for a second or two after landing.

Roblox bounce and friction physics do not scale cleanly, so the time scale shortens distances: the ball loses more horizontal speed in its first bounces. Level 20 playtests (3 hits each):

| Mode | Time | Distance |
| --- | --- | --- |
| Normal speed (×1) | ≈ 19.6 s | ≈ 1,913 studs |
| Old roll fast-forward | ≈ 9.6 s | ≈ 2,060 studs |
| Steady ×1.3 | ≈ 14 s | ≈ 1,690 studs |
| Steady ×1.6 (current) | ≈ 9.2 s | ≈ 1,300 studs |

Distances feed Cash, sections and World progress. The developer chose ×1.6 for short, smooth hits; distances (sections, World endpoints, Cash) will be rebalanced in a later balancing pass.

## 2× Ball Flight (disabled)

**Currently disabled** via `FieldConfig.FlightSpeedUpEnabled = false`. While disabled, the server rejects every `SpeedUp` request, no `BallFlightSpeed` state is published, and the HUD hides the 2× button. The code path stays in place and tested for if it is fixed and re-enabled.

When enabled, the batter can press **2×** during their own hit to watch the ball travel at double speed, as a convenience.

- The client sends only the batting session and the `SpeedUp` action. The server checks that the hit belongs to the player, the session matches, the player is still batting and alive, and their data is ready.
- The server time-scales the ball: velocity and spin ×2, and an extra downward force so total gravity is ×4. Rolling resistance and the stop thresholds/timer are scaled to match. Launch speed, loft, and Level snapshot are unchanged.
- **One-way per hit.** Once 2× is on, it stays on until the hit finishes; further requests are rejected and the button shows ON (disabled). Every new hit starts at normal speed.
- **Known issue (unresolved): 2× changes final distance.** The airborne arc scales exactly (first landing matches normal hits), but bounces and rolling do not. The 0.8-stud ball moves more than its own diameter per physics step at impact, so bounce results depend on impact timing, and enabling 2× shifts that timing. Level 20 playtest results (normal ≈ 1,820–1,960 studs):
  - 2× enabled at launch: 1,734–1,763 studs, with occasional ~1,110-stud outliers.
  - 2× enabled 0.7 s into flight: ≈ 2,340–2,380 studs, repeatable (+25%).
  
  Because switch timing is player-controlled, 2× could be used to inflate distance, Cash, and World completion. One-way switching did not fix this, so the feature is disabled until bounce/roll behavior can be made timing-independent.
- `BallFlightSpeed` (1 or 2, nil when no hit is active) is replicated for the HUD only. Rewards, distance, and world completion still come from the server's measured final position, granted once.

## Equipment Roles and Save Migration (Milestone 18)

Active categories are Bat and Ball only. Schema 6 reuses PlayerProgression and removes OwnedTees/EquippedTee during load and save. Cash, Power, Levels, Rebirths, Bat/Ball ownership and selections, grounds, worlds, and valid offline metadata remain intact. Older schema rules still apply; no progression is wiped or converted into refunds.

PlayerData owns the Power grant pipeline. Since the equipment role flip (see Equipment Roles above) it resolves the Ball, not the Bat: active Training uses the server-equipped Ball, offline grants the normalized saved Ball in the atomic login transaction, and real hits the Ball ID snapshotted at acceptance for their once-only reward: `floor(base hit Power * Ball multiplier * Rebirth multiplier)`. The hit also snapshots the Bat's Cash multiplier for its Cash. Equipment remains locked throughout Training and active hits. Clients send equipment intent, never bonuses or rewards.

Training rate previews use the same whole-Power arithmetic divided by the tick interval. HUD and Rebirth previews show the combined Ball/Rebirth multiplier. Bat Cash rewards and Level-based launch calculations are unchanged by Power.

## Power, Level, and Rebirth (Milestone 15A)

`ProgressionConfig` owns the formulas and their tuning (`tools/balance`, `.vscode/ECONOMY.md`). Schema 4 extends the existing
`PlayerProgression` store with Power, Level, Rebirths, and LevelCap. Older saves
receive 0 Power, Level 1, 0 Rebirths, and the first Level Cap (20) without converting equipment.
Cash, ownership, equipped selections, worlds, and unknown saved fields are preserved.
Malformed new fields are repaired; LevelCap is derived, never trusted from a save.

- Power is progress toward the next Level, in bands (`LevelBands`, solved for the LONG pace): `10 + 1.5 * (Level - 1)` rounded down below Level 20 (the tutorial band: 10, 11, 13, 14, ...; 442 Power from Level 1 to 20), then one band for each Rebirth's 20 new Levels (90 at Level 20, 3,200 at 40, 48,000 at 60, 470,000 at 80, ... up to 16 trillion at 400), each Level 1.02x the one before inside its band. Past the listed bands each new band starts 1.8x above the one before. Requirements never drop at a band breakpoint. A saved Level and Power are re-run through the current bands at every load, so a band change never lowers a Level or takes Power away.
- Requirements are consumed on advancement; one grant can advance multiple Levels.
- At the cap, Level stops but Power keeps building (no grant is discarded) up to the technical `MaxPower` limit (9 quadrillion, below 2^53 so it stays an exact integer); a Rebirth resets it to 0 with the Level.
- Level cap = `20 * (Rebirths + 1)` (20, 40, 60, ...; the first Rebirth is at Level 20); Power gain multiplier = `Rebirths + 1`.
- Training base Power per practice hit = `5 + 1.5 * (Level - 1)` rounded down up to Level 20 (5, 6, 8, ... 33), then 33.
- A valid finalized field hit grants Power once, through server-only
  `PlayerData.GrantPower(player, baseAmount, source)`: the Training base × `HitPowerPerSecond` (0.37) × the seconds the ball was in play, rounded. Active training uses this API; offline grants use the same private grant path inside the atomic load transaction.
- Speed comes from `LaunchSpeedTable` to Level 21 ({Level, speed} points, linear between them), then `LaunchSpeedSteps` (each speed used from its Level until the next), with a 38-degree loft (`Progression.GetLaunchSpeed` / `GetLaunchAngle`). The bounces make distance erratic in speed, so every Level from 22 to 140 has its own speed, measured in Studio, chosen to land on a curve growing 5% a Level from Level 21, easing to 1.65% at Level 100 and 1.65% a Level to 140 (~347 studs at Level 40, 755 at 60, 1,363 at 80, 2,053 at 100, 3,906 at 140). Below ~200 studs/s (to about Level 55) single hits still vary by up to ~40%.
- **Early launch curve** (`EarlyLaunch`): at the table's 55 studs/s a 38-degree hit only rose ~2 studs over the tee and first landed ~17 studs out, then rolled (Roblox gravity is 196 studs/s²), so the first hits looked like grounders; a faster, steeper launch alone still dropped out of the air in about 0.28 s. Level 1 now launches at 61.6 studs/s and 48.3 degrees (41 forward, 46 up) and falls at 0.57x gravity until its first landing (through the hit's existing VectorForce, sized from the ball's mass; Workspace.Gravity is untouched). The first ground contact restores normal gravity for the bounces and roll. The extra speed and loft shrink evenly to nothing by Level 21; the lighter gravity eases out (smoothstep: about 0.62x at Level 5, 0.75x at 10, 0.91x at 15, 0.997x at 20), and from Level 21 the measured table, 38 degrees and normal gravity take over unchanged. A softer landing bounces and rolls less, so the lower gravity is paired with a little more lift rather than less forward speed. Measured at Level 1 against full gravity (66 studs/s at 42 degrees): first flight 0.28 s to about 0.52 s, apex 7.5 to about 12-12.7 studs, first bounce 22 to about 34-35 studs, final distance 91 to about 84-96 studs, still $1 (Levels 1-6 measured at $1, so the tutorial's $2 takes two hits).
  Level is snapshotted at swing acceptance; Power, Rebirths, Bat, and Ball
  do not modify launch speed. Physics still determines actual final distance; the table is built from measured hits (`tools/balance/HitMeasurements`).
- `PlayerData.CanRebirth(player)` checks eligibility. `TryRebirth(player)` also
  rejects active training/batting/hits, dead characters, and world travel, increments Rebirths, resets Level/Power, derives
  the new cap, revalidates the selected ground, and preserves all other progression.
  The confirmed Rebirth interface calls this server transaction. Technical safety limit: 1,000 Rebirths.
- Replicated progression attributes are HUD copies. Grants, launches, Rebirths,
  and saves read private server session state.

The historical `BattingTiming` Remote and script filenames remain for Rojo
compatibility, but no timing mechanics remain. The client sends only its batting
session (and optional `Exit`); the server sends final distance/reward feedback.
SwingConfig provides a single phase timeline: the named Contact marker is at 0.50 seconds in a 1.10-second swing (a 0.14 s Windup phase after Load coils the hands, barrel and torso a little further back before the stride plants). ContactTime and Duration drive the visual swing and existing server contact/cooldown; the client-local SwingMarkerReached event reports the marker without requesting a launch. The server launches `ContactTime - LaunchVisualLead (0.25 s) - the batter's ping` after accepting the swing (at least `MinimumLaunchDelay`, 0.1 s), because clients draw server-moved parts about 0.25 s late; the ball then visibly leaves the tee at the animation's contact (measured gap 0.02-0.05 s, down from about 0.3 s). Launch strength and direction are unchanged.
Natural stopping, sections, world endpoints, and Cash formulas are unchanged.

Milestone 15A added no training mechanics or Rebirth UI. Training is added below in Milestone 15B.
## Training and Offline Power (Milestone 15B)

**Feedback (presentation only):**
- Each time the bat meets a practice ball, a "+Power" popup like the Cash popup after a real hit pops in above the batter (the Power bolt and the amount in green, rising and fading) with a soft tick (`TrainingClient`). The amount is what each Training tick grants, from the same formula the server uses (ground, Bat, Rebirths and any Power juice). The server grants it at that same moment (below), so the HUD's Power bar moves with the hit and the popup. It shows at the Level Cap too, where Power keeps building. (The server's `TrainingPowerGained` / `TrainingPowerTick` display attributes remain but nothing shows them.)
- Every practice hit plays a quieter bat crack from the cage's contact point as the ball reaches the bat (`TrainingClient`).
- Any level-up plays a short (~0.7 s) rising synth swell into a bright ping and a slight 0.45 s camera shake. The offline catch-up at login is shown by the Welcome Back screen instead.

Training is the primary Power source.

### Physical Training Grounds, one row per World (supersedes the single logical stadium)

Each Training Ground is its own batting cage, with its own plate and one occupant at a time. Every World's hub has its own row of six cages, under `<Hub>.TrainingGrounds.<ground id>` (`TrainingConfig.Hubs`). Dragon's Lair stands in every hub, so the server treats each plate in each hub as its own station.
- Every row runs front to back down the left side of its hub as seen from the spawn (the shared hub layout; `TrainingConfig.Row`), the first cage beside the batting area. Plates are at hub-relative x 56, from z 18 stepping 33 studs back (the models' 44-stud spacing, narrowed with the cages), with doors facing the open middle; the item displays face them from across the plaza.
- World 1, from the front: Basic Training, Enchanted Grove, Sunken Atlantis, Sky Temple, Cosmic Rift, Dragon's Lair.
- World 2, from the front: Caveman Camp, Pharaoh's Tomb, Gladiator Colosseum, Samurai Dojo, Time Machine Lab, Dragon's Lair. Each has its own era cage (see Era and toy cages below).
- World 3, from the front: Solar Rooftop, Robo Factory, Biodome Lab, Lunar Base, Quantum Lab, Dragon's Lair. Each has its own futuristic cage (see Future cages below).
- World 4, from the front: Sandbox Diamond, Pinball Cage, Cereal Bowl Stadium, Toy Soldier Fort, Snow Globe, Dragon's Lair. Each has its own toy cage (see Era and toy cages below).
- Cages are turned a quarter turn so their doors face the middle and their machine ends point outward. The spawn is 30 studs behind each World's tee, facing into the hub.
- The physical Shop, World Travel and Rebirth stations and the Training Grounds board are removed for now. Their settings are commented in `WorldConfig`; FieldBuilder deletes any unconfigured station left in the place.

| # | Ground ID | World | Unlock | Power multiplier (× the Training base per 2 s) |
| --- | --- | --- | --- | --- |
| 1 | basic_training | 1 | start | 1× |
| 2 | enchanted_grove | 1 | 2 Rebirths | 5× |
| 3 | sunken_atlantis | 1 | 4 Rebirths | 10× |
| 4 | sky_temple | 1 | 6 Rebirths | 20× |
| 5 | cosmic_rift | 1 | 500 Robux game pass | 10× |
| 6 | caveman_camp | 2 | free once World 2 is unlocked | 25× |
| 7 | pharaohs_tomb | 2 | 8 Rebirths | 35× |
| 8 | gladiator_colosseum | 2 | 10 Rebirths | 50× |
| 9 | samurai_dojo | 2 | 12 Rebirths | 70× |
| 10 | time_machine_lab | 2 | Cosmic Rift's 500 Robux pass | 35× |
| 11 | solar_rooftop | 3 | free once World 3 is unlocked | 90× |
| 12 | robo_factory | 3 | 14 Rebirths | 120× |
| 13 | biodome_lab | 3 | 16 Rebirths | 160× |
| 14 | lunar_base | 3 | 18 Rebirths | 210× |
| 15 | quantum_lab | 3 | Cosmic Rift's 500 Robux pass | 120× |
| 16 | dragons_lair | every World | 1000 Robux game pass | 30× (most expensive) |

The balance pass kept every ground's requirement and multiplier: each free ground trains faster than every free ground before it, World after World, and the Rebirth gates (7, 12 and 18 Rebirths reach World 1's, World 2's and World 3's ends) line up with them. As in the earlier Worlds, the paid ground in World 3 is set below its top Rebirth ground; paid grounds stay optional.

**Access:**
- A ground can only be used once a World it stands in is unlocked (the server-set `WorldUnlocked_<id>` attributes). World 1 cages stay usable after reaching World 2.
- Walking onto a plate in the player's current World starts training only if the server's private Rebirths or pass ownership allow that ground.
- Otherwise the player gets the reason once per visit. On a paid ground, the server also re-checks ownership and shows Roblox's purchase prompt.
- Paid grounds need no Rebirths and are not lost on Rebirth.

**Game passes:**
- There are two passes. A ground with `sharesPass` has no pass of its own: Time Machine Lab and Quantum Lab are opened by Cosmic Rift's pass. Ownership, prompts, prices and the `TrainingPass_<id>` attribute all use the pass's own ground (`TrainingConfig.GetPassGround`, `TrainingConfig.PassGrounds`).
- `gamePassId` stays 0 until the passes are created on Roblox. While it is 0, the ground shows "COMING SOON" and cannot be used or bought.
- Ownership is read with `UserOwnsGamePassAsync` at login (before the offline grant) and updated by the server's `PromptGamePassPurchaseFinished` event.
- Ownership is never saved and never taken from the client. A failed lookup grants nothing.

**Menu and teleport:**
- The Training Grounds menu lists every ground with where it stands ("World 2", "Every World"), its multiplier and effective rate.
- Each card shows GO (teleport beside that plate, travelling Worlds if needed), BUY (asks the server for the pass prompt), the Rebirths still needed, or UNLOCK WORLD 2 for a ground in a locked World.
- The QuickMenu Training tile teleports to the player's best usable ground in any unlocked World.
- Each cage shows a per-player lock sign in its doorway.

### Batting cage (visual)

`TrainingStadium.luau` builds a batting cage around each plate (model `Cage`), dressed in that ground's `theme` on the server. Its footprint is `TrainingConfig.Cage`: modelled 30 × 48 × 14 studs in plate space, then narrowed in game to `widthScale` (0.75, `CAGE_WIDTH_SCALE` in TrainingConfig) across the cage, about the pitch line, so it is 22.5 studs wide. Parts are squeezed across the cage and moved toward the pitch line; spinning parts shrink evenly to stay round. Turf, walls, door, banners, decoration slots and particle zones use the same narrowed width. The batter faces +X, the machine is at −Z, and there is extra room behind the batter so the default camera stays inside. The door is in the batter-end net.

The mesh comes from `ServerStorage.RunwayAssets.TrainingCage` (Studio-managed, generated by `tools/blender/batting_cage.py` and exported at 1/4 scale, then scaled up 4×):
- steel hoops with padded posts, and strand netting on all sides and the roof
- a two-wheel pitching machine whose ball exit is the PitchOrigin
- a protective screen with a window on the pitch line
- home plate, a ball bucket and two floodlights

Parts built in code: the turf, pitch lane, batter's-box chalk, three banners and invisible walls that leave the door open. The walls have CanQuery off, so camera raycasts pass through. The plain plate is hidden under the turf but still defines training occupancy. If the template is missing, the cage builds without its mesh and warns.

Each ground's `theme` sets:
- `template`: the cage mesh in RunwayAssets
- colors by role: turf, lane, accent, frame, net, banner
- `lights`: the floodlights
- `decorations`: `{slot, template}` pairs cloned from RunwayAssets onto the named Attachments in `Cage.DecorSlots`. The slots are outside both long sides, behind both ends, and inside the cage away from the lane, door and camera.

The banners show the ground name. Themes never affect Power.

### Fantasy cages (grounds 2–6)

Each fantasy ground has its own Blender model, generated by its own script in `tools/blender/`. All scripts share `cage_helpers.py`, which holds the layout and export rules, and export to their own FBX in `assets/models/`:

| Ground | Script → FBX / template | Highlights |
| --- | --- | --- |
| Enchanted Grove | `grove_cage.py` → `GroveCage` | Living-wood arches, woven vine net with glowing strands, stepping stones, a tree-stump machine with a knot-hole, wicker screen, glowing mushrooms, a fairy-door tree, fireflies |
| Sunken Atlantis | `atlantis_cage.py` → `AtlantisCage` | Fluted marble arcade under a force-field bubble dome, mosaic lane, giant clam with a pearl, porthole screen, coral, swaying kelp, chest, trident, circling fish, bobbing jellyfish, bubbles |
| Sky Temple | `sky_temple_cage.py` → `SkyTempleCage` | Marble plinth and gold-banded columns, glowing gold lattice, sun inlay, winged golden statue, sunburst screen, cloud bank, bobbing islands with waterfalls and a shrine, spinning armillary rings, blue braziers, feathers |
| Dragon's Lair | `dragon_lair_cage.py` → `DragonLairCage` | Obsidian shard pillars with lava veins, gabled iron roof with spiked eaves, chain-link lattice and draped chains, lava cracks, dragon-head machine, portcullis, treasure hoards, a complete dragon skeleton sprawled over the roof (sculpted skull with glowing sockets over the entrance, spine and ribcage along the ridge, legs gripping the eaves, wing bones with tattered membrane, tail coiled round a hoard), torches, lava pools, embers |
| Cosmic Rift | `cosmic_rift_cage.py` → `CosmicRiftCage` | Chrome hex hoops with star nodes, force-field shell with constellations, spinning galaxy floor, portal machine with a swirling core, holographic screen, black hole with accretion disc, the rift tear, ringed planet, orbiting planets, asteroids, crystals, nebulae, shooting stars |

All five keep the standard layout:
- the plate at the origin
- the ball exit at PitchOffset
- the screen window on the pitch line
- the door in the batter-end wall
- nothing past the 14-stud gaps to the neighbouring cages

Every model is exported at 1/4 scale and imported into `ServerStorage.RunwayAssets` under its template name. `TrainingCageStyles` (server) gives every MeshPart its color, material, transparency and glow light by name, because FBX imports carry no colors. It also sets the `Spin`, `Bob`, `Sway` and `Pulse` motion attributes and lists each cage's particle effects, which use built-in Roblox particle textures. `TrainingStadiumClient` animates those attributes on each client, relative to the server-built CFrame.

The Atlantis dome and Cosmic field are tinted glass, so the view through them reads as underwater or deep space. A style `tint` (Dragon's Lair) sets Tint* attributes on the cage, and the client blends a ColorCorrectionEffect in while its camera is inside that cage.

### Future cages (World 3, grounds 1–5)

World 3's five grounds each have their own futuristic Blender model on the same layout, conventions and `TrainingCageStyles` styling as the fantasy cages, more intricate down the row:

| Ground | Script → FBX / template | Highlights |
| --- | --- | --- |
| Solar Rooftop | `solar_rooftop_cage.py` → `SolarRooftopCage` | White aluminium frame under a sawtooth canopy of glass solar modules, sky-blue glass walls, living walls and planters, a sun-emblem machine with a sun-tracking solar flower, rooftop deck with parapet and glass railing, HVAC units with spinning fans, a helical wind turbine, a stair hut with a blinking beacon, drifting sun motes |
| Robo Factory | `robo_factory_cage.py` → `RoboFactoryCage` | Steel portal frames with hazard-striped guards, yellow safety fence and chain-link roof, a bridge crane carrying a bobbing cog, an orange six-axis robot pitcher holding the ball, spinning warning beacons, stack lights, a conveyor of robot parts through a laser scanner, a welding robot throwing sparks, steam |
| Biodome Lab | `biodome_lab_cage.py` → `BiodomeLabCage` | A geodesic glass vault with glowing nodes and grow bars, raised beds of glowing alien plants and mushrooms, bobbing moss-ball planters, a misting tower with a spinning sprinkler, a giant seed-pod pitcher with a glowing throat, a woven-vine screen, hydroponic racks, specimen tubes, drifting spores |
| Lunar Base | `lunar_base_cage.py` → `LunarBaseCage` | A pressurised tunnel of white module rings under a frosted shell, portholes, a mass-driver pitcher with glowing coils, EVA suits and consoles, a cratered regolith apron with a lander, a rover and a turning radar dish, and a turning, bobbing Earth framed by the observation window, low-gravity dust |
| Quantum Lab | `quantum_lab_cage.py` → `QuantumLabCage` | Graphite ribs and hologram force-field walls traced with glowing grids, three energy rings turning round the whole cage, a particle accelerator overhead, a reactor with tilted spinning rings, a teleporter pitcher with a vortex core, golden quantum computers, glitching cubes, data rain |

The Robo Factory and Biodome Lab scripts reuse small builders from the top of `solar_rooftop_cage.py`, and the Quantum Lab script reuses the top of `lunar_base_cage.py` (split at a marker, as the runway scripts do). A part's `spinAxis` is in its own space: a Blender direction (x, y, z) is (−x, z, y), because imported cages arrive turned a half turn. Lunar Base and Quantum Lab play the Cosmic Rift ambience, Solar Rooftop Sky Temple's wind, Biodome Lab the Grove's chimes and Robo Factory the Atlantis hum.

### Era and toy cages (World 2 and World 4, grounds 1–5)

World 2's and World 4's grounds each have their own fully custom Blender model: none is built on the standard cage, and none reads as a plain rectangle. Each has its own frame, walls, roof, floor, pitcher holding the ball at the pitch point, screen, scenery and at least one moving piece. They keep the same layout, conventions and `TrainingCageStyles` styling as the fantasy and future cages, and grow more intricate down the row, with the paid ground (Time Machine Lab, Snow Globe) as each World's showpiece. The scripts share the builders in `cage_helpers.py` (profiles, members, rings, gears, screen panels, and the step that names and colours every mesh). Every mesh starts with a short prefix, and the home plate is `<Prefix>Plate`, which `tools/studio/group_item_imports.luau` checks against the standard cage's.

| Ground | Script → FBX / template | Highlights |
| --- | --- | --- |
| Caveman Camp | `caveman_camp_cage.py` → `CavemanCampCage` | Crossed tusk-and-bone arches, rope net and hides, a stone catapult, a campfire with a turning spit roast, a sleeping mammoth (bobbing, ears swaying), camp smoke |
| Pharaoh's Tomb | `pharaohs_tomb_cage.py` → `PharaohsTombCage` | Hieroglyph pillars under a pyramid roof frame, gold-jointed floor, an open sarcophagus with a mummy holding the ball, a scarab screen, sphinx, obelisks, a turning sun disc, swinging censers with incense |
| Gladiator Colosseum | `gladiator_colosseum_cage.py` → `GladiatorColosseumCage` | An oval two-tier arcade under a striped canvas awning, a ballista pitcher, bronze shield screen, a crowd doing the wave, lions, a parked chariot, gold dust |
| Samurai Dojo | `samurai_dojo_cage.py` → `SamuraiDojoCage` | Torii frames, shoji walls and an upturned pagoda roof, a bamboo launcher, crane folding screen, swaying lanterns, a cherry tree with falling petals, a koi pond with circling koi, a swaying shishi |
| Time Machine Lab | `time_machine_lab_cage.py` → `TimeMachineLabCage` | A brass-and-glass rotunda, turning gear trains and armillary rings, a clock-face floor with turning hands, a swirling time portal round the ball, relics from every era drifting overhead, chrono motes |
| Sandbox Diamond | `sandbox_diamond_cage.py` → `SandboxDiamondCage` | A hexagonal plank sandbox under shade sails, a tipped pail pitcher, a sand-sifter screen, a sandcastle, a turning pinwheel, a turning, bobbing beach ball |
| Pinball Cage | `pinball_cage.py` → `PinballCage` | A pinball cabinet with a backbox head under a sloping glass top, flippers and slings, glowing pop bumpers, blinking chase lights, turning spinners and star turntable, a plunger pitcher, a scoreboard screen |
| Cereal Bowl Stadium | `cereal_bowl_cage.py` → `CerealBowlCage` | A flared bowl with a chipped doorway, bendy straws and cling film overhead, cereal bobbing on the milk, a spoon catapult, a cereal box screen whose prize top spins |
| Toy Soldier Fort | `toy_soldier_cage.py` → `ToySoldierCage` | A painted toy fort with towers and waving flags, a drawbridge over a moat, a striped tent roof, a wind-up soldier pitcher whose key turns, a drum screen, a cannon and guards |
| Snow Globe | `snow_globe_cage.py` → `SnowGlobeCage` | A glass dome as the enclosure on a music-box base whose key turns, a snowy village, circling skaters, a turning carousel, a sleigh, a Christmas tree, a snowflake screen, drifting flake ornaments, falling snow (and the swirl after each hit) |

The game can only spin, bob, sway or pulse a part, so the catapults, sarcophagus lid, ballista and spoon rest in their loaded poses.

A ground whose fantasy template is not imported falls back to the standard cage in its theme colors, with a warning. Banners hang between frames so every design leaves room for them. A larger invisible block keeps players out of the bigger machines.

Walk onto an unlocked ground's 5-by-5 plate to train automatically. Leave training
before shopping or rebirthing. Space/touch Leave restores movement and requires
stepping off before re-entry. Death, respawn, disconnect, invalid data/character,
and travel release the plate. Normal batting and active-hit state exclude training.

The server grants a configured tick as the bat meets each practice ball: the client's practice loop runs on the server clock from `TrainingStartedAt` (contact `PracticePitchSeconds` = 1.1 s into each 2 s cycle), and the server grants on that same schedule, checking trainees every frame, so the Power bar, the hit and its "+Power" popup land together (each ground's interval must equal `PracticeCycleSeconds`; hits missed during a server stall are skipped, never caught up). Each tick goes through PlayerData.GrantPower: `floor(ground base Power * equipped Bat multiplier * Rebirth multiplier)`. Level advancement and cap overflow rules remain unchanged.
Ticks do not catch up in bursts after server stalls. At the cap, grants continue
and Power keeps building. Client-local pitches and the reused Bat swing are presentation
only: no real ball launch, Cash, distance, sections, or world completion occurs.

Schema 5 added SelectedTrainingGround and LastLogoutTime to PlayerProgression.
Schema 8 retires SelectedTrainingGround: grounds are physical, so nothing is
selected or saved, and the field is dropped on load and save. Existing profiles keep Cash, Power, Level,
Rebirths, equipment, juices and worlds. Schema 9 adds TimePlayed, RobuxSpent and
RobuxPurchases (see Leaderboard stats). Schema 10 adds the tutorial fields (see New-Player Tutorial). Old schemas and missing, zero, malformed, or
future timestamps grant no historical offline Power.

Offline base Power = floor(min(elapsed seconds, 8 hours) * best usable ground's
base Power / interval * 0.25). The best usable ground is the highest-rate ground the player can use in any unlocked World, from Rebirths, owned passes and the saved World unlocks, checked at login. The same server grant path multiplies that base by the saved, ownership-validated Ball multiplier and Rebirth multiplier, floors the result to whole Power, and applies cap rules. These are placeholder balance values. Offline earning does not
require leaving while actively training.

**Run cap.** One return grants at most half the Power the player still needs to reach their Level Cap, measured at login (`TrainingConfig.OfflineRunShare` 0.5, `ProgressionConfig.GetPowerToLevelCap`), so offline Training helps but never finishes a run by itself: a normal return never reaches the Level Cap, repeated returns take half of what is left each time, and a return at the cap adds nothing (Training Power still banks there). Active Training stays the best Power source.

The login UpdateAsync commits the reward, consumes LastLogoutTime, and claims the
session atomically. A lost-response retry recognizes its own session and does not
grant again. There is no client offline-claim operation. Normal exit records the
server close time; autosaves record a checkpoint time for crash recovery. No
extra periodic DataStore writes are added. A crash before the first autosave after
login conservatively has no new offline timestamp to use.

**Welcome Back screen and the 3x offer.** The screen (`TrainingClient`, standard window) has a clock in its title (`UI.ClockIcon`: a white face with a blue rim, hour marks and hands, and the Power bolt over its edge), "You trained while you were offline:", the Power earned in full ("+1,486,600 POWER") under a glowing bolt, the ground and time trained, and two buttons:
- **Claim!** (green) closes the screen; the reward was already added at login.
- **3x** (rainbow, with the total it brings and a Robux price tag) buys the offline reward twice more, 3x in all, up to all the Power the player needed for the Level Cap at login (`TrainingConfig.OfflineTriple`, `runShare` 1: it can finish the run, never pass it; a developer product, `productId` 0 and `robuxPrice` nil until it is created and priced, while the tag reads SOON and a tap explains it is coming soon). It shows whenever this login had an offline reward, so not at the Level Cap (`OfflineTripleAvailable`, set by the server); its amount is the server's total with the 3x (`OfflineTriplePower`).
- **Server authority:** the client only opens Roblox's purchase prompt. Roblox sends the receipt to `ProductServer` (the game's one `ProcessReceipt` handler), which calls `PlayerData.ClaimOfflineTriple`: it adds this login's offline base reward x2 through the normal grant path, with the Ball that earned it, up to the offer's limit (the rest of the run at login) and never past the Level Cap now (if the player has already trained to the cap there is nothing to fill, so the receipt is left for Roblox to retry; a retry after the Rebirth, or at a later login with an offline reward, fills it); records the receipt (RobuxSpent, never twice: a repeated receipt is acknowledged without granting again); withdraws the offer; and saves straight away before telling Roblox the purchase was granted. The offer is once per login. A receipt with no offer to fill (a second purchase in the same login, or the player not in the server) is left for Roblox to retry later, such as at their next login with an offline reward. The window then shows the new total (`OfflineTriplePower`).

TrainingRequest accepts only Buy(id), which shows the pass prompt, or Exit(session). TrainingTeleport accepts an
optional ground id; anything the player cannot use falls back to their best ground. No remote starts
training or accepts rates, Power, ownership, timestamps, duration, or Rebirths. The HUD shows
training state/rate alongside existing Power/Level values. Offline notifications
are shown once per client session for absences covering at least 60 seconds,
including capped sessions with no further Power gain.
## Confirmed Rebirth and Swing Presentation (Milestone 16)

The plain Rebirth interaction is at hub-relative (-35, 0, 120), currently near
(-52.2, 1.62, 98.8), separated from training, batting, and World Travel. The menu
shows current/next multiplier and cap, eligibility, and exact reset/keep/gain
consequences. Rebirth then Confirm are separate actions; Cancel/close/death/travel
clear confirmation. The quick menu Rebirth tile provides access in every world.

RebirthRequest accepts intent only, with no arguments. The server checks session,
private cap eligibility, alive character, active gameplay/travel, per-player
cooldown, and processing state. TryRebirth commits Level, Power, Rebirths, derived
cap without yielding. Cash, equipment and
worlds are preserved. Completion schedules an important save through the existing
serialized autosave loop (normally within its next five-second check). A save
already in flight cannot clear a later Rebirth's pending save. The existing store/session leases remain unchanged.

Ground access updates from Rebirths, game passes and TrainingConfig immediately. Training
Ground rates and all level/world balance remain placeholders.
Rebirth multiplies Power, never Cash or same-Level launch speed. The HUD shows a
Power progress bar, multiplier, aggregated level changes, and capped/Rebirth state.
Offline feedback includes the best usable ground, credited time, Power, and resulting
level range/cap without adding a new claim request.

The R15 swing remains a local procedural pose using existing bat geometry and hand
IK. A short load precedes hip rotation, torso/shoulder rotation, accelerating bat
contact, extension, follow-through, and recovery. Legs shift weight and the neck
counter-rotates. Smooth keyframe curves stagger the hips, chest, hands, and barrel;
foot IK plants the lead side and pivots the rear foot about its toe. The absolute shared timeline avoids chained-wait drift. Training
uses the same swing/contact time but its server Power ticks remain independent.
Unsupported or failed presentation cannot disable valid server swing requests.
Exit/reset/destruction restore original joints/grip and remove temporary IK state.
No third-party animation assets or new cosmetic models are used.
## Server Authority

Important progression and gameplay state must remain server-authoritative.

This includes:

- Cash
- Equipment
- Purchases
- Hit results
- Distance
- Rewards
- Section results
- World completion
- World unlocks
- Persistent player data

The client primarily handles:

- Input
- UI
- Camera
- Animations
- Local visual/audio feedback

## Visual Development

Gameplay systems should be developed and validated before major visual polish.

Environment themes, equipment appearances, Ball effects, UI styling, and other cosmetic work should be handled in dedicated visual milestones rather than being added piecemeal during gameplay-system development.
