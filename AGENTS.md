# Roblox Baseball Simulator

## Purpose

Help build a Roblox baseball batting simulator while teaching the developer Roblox development.

Priorities, in order:

1. Fun and reliable gameplay
2. Simple, maintainable architecture
3. Security for important game state
4. Incremental development
5. Scalability when justified

Do not over-engineer early versions of the game.

## Development Environment

- Windows
- Roblox Studio
- Luau
- Claude as the primary AI-assisted coding environment
- Roblox Studio MCP for inspecting and testing the open Studio place
- Git/GitHub for version control
- Rojo is adopted; repository `.luau` files are the source of truth
- Keep Rojo mappings stable unless the requested feature requires a change

Edit script source in the filesystem repository. Use Studio/MCP to inspect and test the live game and manage necessary non-source physical objects. Never directly edit Rojo-managed Source in Studio.

## Working Style

The developer is learning Roblox development. Explain important Roblox concepts clearly, but avoid unnecessary theory.

Before making a significant change:

1. Inspect the relevant existing files and Studio objects first.
2. Preserve working behavior unless the requested change requires replacing it.
3. Explain the intended change briefly.
4. Implement the smallest coherent milestone.
5. Inspect the result for obvious problems.
6. Playtest through MCP when useful and supported.
7. Report what still requires manual verification in Roblox Studio.

For small changes, bug fixes, syntax fixes, property changes, and obvious implementation tasks, skip unnecessary explanation and make the change directly.

Prefer completing coherent milestones over splitting routine work into many tiny steps.

Do not make unrelated changes while implementing or debugging a feature.

## Game Identity

This is a Power/Level-based baseball batting simulator.

Core loop:

Train -> Power -> Level -> hit farther -> earn Cash -> reach Level Cap -> Rebirth -> higher Power gain/cap -> better Training Grounds -> progress through Worlds -> repeat

Players hit a ball from a batting tee into long progression fields rather than playing traditional baseball games.

Established design decisions:

- Level, and the World you bat in, determine authoritative launch strength: hits start over in each new World (World 2 onward) and grow back to its end portal over that World's Level range (`WorldConfig` `launchLevels`, `ProgressionConfig.GetWorldLaunchLevel`).
- Every valid batting hit launches straight at a configured loft from that launch Level; the old timing mechanic is retired.
- Ball equipment multiplies Power gained from Training, real hits, and offline Training (`powerGainMultiplier`).
- Bat equipment multiplies the Cash a real hit earns, only (`cashMultiplier`).
- Neither changes launch strength, loft, direction or distance; Training Grounds multiply Training Power only; Rebirths multiply Power gain.
- Tee is not player equipment; the physical batting tee remains part of the batting station.
- Training is the primary Power source; real hits give a small Power reward.
- Offline Training is supported and capped.
- Rebirth resets Level/Power and increases Power gain multiplier and Level Cap while preserving unrelated progression.
- Training Grounds are separate physical batting cages, one row of six in each World's hub (Dragon's Lair stands in every World); the plate a player stands on is the ground they train at. There is no saved ground selection.
- Worlds are unlocked through legitimate batting distance progression, not by buying them with Cash.

Do not reconsider these decisions unless explicitly asked.

## Current Development Priority

Preserve the implemented core loop, persistence, training, equipment, worlds, UI foundation, and server authority.

Expand only the requested milestone.

Keep placeholder balance configurable.

Do not assume discussed/planned work is implemented; inspect the current repository and Studio state first.

## Architecture Principles

Use server authority for important or exploitable gameplay state.

The server should control or validate:

- Cash, Power, rewards, and progression
- Level, Rebirths, and Level Cap
- Purchases and equipment ownership/equipping
- Training Ground access (Rebirths and game-pass ownership) and Training Power grants
- Offline Training calculations
- World unlocks and travel eligibility
- Important gameplay results
- Authoritative launch strength/direction/angle
- Final hit distance

The client should primarily handle:

- Player input
- UI
- Camera
- Animations
- Practice-ball visuals
- Local visual/audio feedback

Do not trust client-provided values for rewards, distance, prices, ownership, progression, multipliers, Power, Level, or other important results without server validation.

Keep RemoteEvents and networking minimal and understandable.

Do not introduce complex frameworks, service architectures, abstractions, dependencies, or premature optimization unless they solve a real current problem.

## Roblox Studio MCP Rules

Use Roblox Studio MCP to inspect and verify the live game.

Before modifying an existing system:

- Inspect the relevant DataModel hierarchy.
- Read the relevant repository files.
- Check existing properties/configuration rather than guessing.
- Avoid duplicating Instances that already exist.

When making changes:

- Edit repository source and let Rojo sync.
- Use Studio/MCP for runtime tests and required non-source objects.
- Keep object names descriptive and consistent.
- Keep scripts focused on one clear responsibility.
- Do not silently restructure unrelated parts of the game.
- Avoid unnecessary Rojo mapping changes.

When possible after implementation:

- Check Studio Output for errors.
- Use MCP playtesting for relevant verification.
- Report what gameplay/visual behavior still requires manual verification.

Visual correctness must be judged from actual playtesting, not only property inspection.

## Rojo Workflow

The filesystem repository is authoritative.

Normal workflow:

Design -> Edit filesystem -> Rojo sync -> Test in Studio -> Fix -> Commit -> Push

Do not directly edit Rojo-managed Script/LocalScript/ModuleScript source through Studio MCP.

Do not bypass Git by treating the live Studio place as the source of truth for scripts.

## Development Workflow

Use:

Design -> Implement -> Test -> Fix -> Commit -> Continue

Before significantly changing a working system, consider whether a Git checkpoint should be created.

For debugging:

1. Identify the likely cause.
2. Inspect only the relevant code/objects.
3. Make the smallest useful change.
4. Test it.
5. Avoid unrelated refactoring.

If a visual/cosmetic issue does not block the current gameplay milestone, prefer recording it for later polish rather than repeatedly blocking development on it.

## Code Guidelines

- Write clear, beginner-readable Luau.
- Prefer descriptive names over clever abstractions.
- Keep scripts focused on a clear responsibility.
- Use Roblox APIs and patterns appropriate for the current Roblox Studio version.
- Avoid unnecessary dependencies.
- Avoid premature optimization.
- Use comments only where they explain non-obvious intent.
- Preserve existing working behavior unless the task requires changing it.
- Keep important tuning values easy to find rather than scattering magic numbers.
- When multiple implementations are valid, choose the simplest option that is secure and maintainable.

## Current Progression Model

### Power / Level

- Power requirements come in bands (`ProgressionConfig.LevelBands`), solved for the LONG pace (Rebirth k's run takes about 3 + 4 × (k - 1) minutes): `10 + 1.5 × (Level - 1)` below Level 20 (the tutorial band: 10, 11, 13, 14, ...; its Level 20 climb takes about 54 s of Training), then one band for each Rebirth's 20 new Levels (90 at Level 20, 3,200 at 40, 48,000 at 60, 470,000 at 80, ...), each Level 1.02x the one before inside its band, listed to Level 500 (World 4's runs, Rebirths 19-24, solved without changing the earlier bands); bands past the listed ones start 1.8x above the band before, and a Level never needs more than `MaxPower` (9 quadrillion, from about Level 555). A grant bigger than `MaxPower` levels through in pieces (`Progression.Advance`), so none is lost before the Level Cap.
- Level Cap currently scales as `20 * (Rebirths + 1)` (20, 40, 60, ...; the first Rebirth is at Level 20).
- Rebirth Power multiplier currently scales as `Rebirths + 1`.
- The Training base (Power per practice hit at Basic Training) is 5 at every Level; Level never scales Power gain.
- Launch speed comes from a Level -> speed table built from measured hits (`tools/balance/HitMeasurements`), at a 38-degree loft. Distance is erratic in speed (bounces), so from Level 22 each Level uses its own measured speed (`LaunchSpeedSteps`) chosen to land on a curve that grows 5% a Level from Level 21 (~146 studs), easing to 1.65% at Level 100 and staying there to Level 140 (3,906 studs): about 347 studs at Level 40, 755 at 60, 1,363 at 80, 2,053 at 100; below ~200 studs/s single hits still vary (up to ~40%). World 1's end is still reached at Level 150, World 2's at 250, World 3's at 370 and World 4's (8,000, measured in World 4's longer field) at 490. The first Levels use an early launch curve (`ProgressionConfig.EarlyLaunch`: Level 1 at 61.6 studs/s and 48.3 degrees, falling at 0.57x gravity until its first landing; speed and loft blend evenly, and the gravity eases, into the table, 38 degrees and normal gravity by Level 21) so a new player's hit rises and hangs in a light arc instead of skimming into the ground. Bounces and rolling always use normal gravity.
- These are implementation/balance values, not immutable design decisions; `tools/balance` simulates and re-solves them (`.vscode/ECONOMY.md`).
- Level (through the World's launch Levels) is the sole long-term determinant of batting distance.

### Equipment Roles

- Ball: multiplies Power gain (Training, real hits, offline Training).
- Bat: multiplies Cash rewards from batting.
- Level and the current World: solely determine hit distance (hits start over in each later World).
- Training Ground: multiplies Training Power only.
- Rebirth: multiplies Power gain.
- Purchased Power / Cash multipliers (Robux, see Monetization): multiply Power gain / batting Cash; never distance.

The server derives every multiplier from the authoritative equipped IDs through `EquipmentConfig`, and the purchased ones from the saved tier counts through `MonetizationConfig`; a hit snapshots the Ball ID, the Bat Cash multiplier, its juices and the purchased multipliers when the swing is accepted.

Formulas (whole Power is rounded down once, after all bonuses):

- Training Power = Training base (5) × ground multiplier × Ball × (Rebirths + 1) × purchased Power multiplier × any Power juice
- Hit Power = Training base × 0.37 per second in play (rounded) × Ball × (Rebirths + 1) × purchased Power multiplier × any Power juice (no ground; about 50-70% of Basic Training's rate)
- Offline Power = 25% of the best usable ground's Training rate (no Level term), for up to 8 hours, × Ball × (Rebirths + 1) × purchased Power multiplier (never a juice), held to half the Power still needed for the Level Cap (Welcome Back's 3x adds it twice more, up to all of it)
- Hit Cash = (World start pay + World Cash multiplier × (distance / 80)^1.5) × section multiplier × Bat × purchased Cash multiplier × any Cash juice, rounded, at least $1

### Bat

Bat equipment increases Cash earned from batting.

Current Cash multipliers and prices (each Bat about 1.5x the one before):

- Wood: 1x, $0
- Metal: 1.5x, $25
- Jungle: 2x, $120
- Amethyst: 3x, $600
- Candy Cane: 4x, $3,000
- Frostbite: 6x, $15,000
- Magma: 9x, $50,000 (World 1's last purchase, before World 2 opens)
- Lightning: 13x, $3.2M (World 2's last purchase)
- Dragon Bone: 19x, $28M
- Celestial: 28x, $100M
- Rolling Pin: 42x, $1.65B (World 4, bought midway through it)
- Catastrophe Bat: 2.5x, exclusive to the Starter Pack (never sold for Cash, outside the series)

Bat does not affect Power gain or launch distance.

### Ball

Ball equipment increases Power gain.

Ball does not affect Cash or launch distance.

World 1's Balls (intended balance; the Sandlot Ball's $2 is the tutorial's first purchase):

- Baseball: 1x, $0
- Sandlot Ball: 3x, $2
- Bubblegum Ball: 5x, $10
- Crystal Ball: 12x, $40
- Frost Comet: 30x, $150
- Inferno Ball: 75x, $500
- Thunder Ball: 200x, $1,500
- Galaxy Ball: 500x, $4,500
- Dragonfire Ball: 1,250x, $14,000
- Supernova Ball: 3,500x, $40,000

Balls are sold in purchase series, each bought in order: World 1's ten (Baseball to Supernova Ball), World 2's ten (Dino Egg to Chrono Orb, 5,000x-200,000x for $175K-$2.1M), World 3's ten (Solar Cell to Singularity Orb, 300,000x-11,000,000x for $15M-$97M) and World 4's ten (Dandelion Puff to Dream Orb, 16,000,000x-600,000,000x for $530M-$2.8B). Every ball beats the one before it and every ball of an earlier series (about 1.5x a step from World 2 on). A later World's series needs that World unlocked but none of the earlier series' balls. Each series has its own server-issued purchase token. Owned balls of any series stay equippable everywhere.

### Training Grounds

Each World's hub has one row of six physical Grounds, each its own batting cage, down the left side as seen from the spawn (parallel to the runway, the first ground beside the batting area; `TrainingConfig.Hubs`).

World 1 (Home Field):

- Basic Training: available from the start, 1x
- Enchanted Grove: 2 Rebirths, 5x
- Sunken Atlantis: 4 Rebirths, 10x
- Sky Temple: 6 Rebirths, 20x
- Cosmic Rift: 500 Robux game pass, 10x (intentionally below Sky Temple)

World 2 (Time Travel; placeholder values continuing on from World 1's):

- Caveman Camp: free once World 2 is unlocked, 25x
- Pharaoh's Tomb: 8 Rebirths, 35x
- Gladiator Colosseum: 10 Rebirths, 50x
- Samurai Dojo: 12 Rebirths, 70x
- Time Machine Lab: opened by Cosmic Rift's 500 Robux pass, 35x

World 3 (Future World; placeholder values continuing on from World 2's):

- Solar Rooftop: free once World 3 is unlocked, 90x
- Robo Factory: 14 Rebirths, 120x
- Biodome Lab: 16 Rebirths, 160x
- Lunar Base: 18 Rebirths, 210x
- Quantum Lab: opened by Cosmic Rift's 500 Robux pass, 120x

World 4 (Tiny Town; the design's starting values, kept by the balance pass):

- Sandbox Diamond: free once World 4 is unlocked, 270x
- Pinball Cage: 20 Rebirths, 350x
- Cereal Bowl Stadium: 22 Rebirths, 450x
- Toy Soldier Fort: 24 Rebirths, 580x
- Snow Globe: opened by Cosmic Rift's 500 Robux pass, 400x

Every World:

- Dragon's Lair: 1000 Robux game pass, 30x (the most expensive ground)

Multipliers apply to the first ground's base Power. A ground can only be used once a World it stands in is unlocked; World 1 grounds stay usable after reaching World 2. Paid grounds need no Rebirths. Game-pass ownership is checked by the server through MarketplaceService, never saved and never trusted from the client.

World 1's grounds 2-6 are fantasy themed, World 2's grounds 1-5 are eras of time, World 3's grounds 1-5 are futuristic and World 4's grounds 1-5 are toys. Each has its own fully custom cage model (`tools/blender/*_cage.py` on `cage_helpers.py`, styled by `TrainingCageStyles`), getting more intricate down the row, with the paid ground as the showpiece. Only Basic Training uses the standard cage, which also stands in for any cage model that isn't imported. The themes are visual only and never affect Power.

Unlock requirements and multipliers are configurable and should not be treated as final balance.

## Batting

The old timing mechanic is retired.

Normal batting flow:

Player enters batting position
-> presses/taps Swing
-> swing animation plays
-> server launches the ball straight downfield
-> Level determines launch strength
-> Roblox physics handles flight/bounces/roll
-> ball naturally stops
-> final forward distance is calculated
-> rewards are granted
-> ball resets

Do not reintroduce:

- timing fan
- Perfect/Good/Okay/Miss
- timing-based power
- timing-based horizontal direction

Animation is presentation only and must not determine authoritative gameplay results.

## Ball Physics

The ball uses Roblox physics.

Normal lifecycle:

- flight
- bounce
- roll
- natural slowdown
- stopped-state confirmation
- final distance
- rewards
- reset

Rolling distance counts.

Distance is authoritative server-side forward/downfield distance, not total 3D displacement.

Preserve the existing natural-stop and ground-contact logic unless a task explicitly requires changing it.

## Training

Training is the primary Power source.

Each World's hub has its own row of physical Training Grounds, each with its own plate and at most one occupant.

The player steps onto a ground's plate that they can use:

- Training starts automatically
- character is positioned/locked
- client practice pitch/swing loop plays
- server grants Power on the configured interval

Training practice visuals do not:

- calculate distance
- award Cash
- unlock Worlds
- use the real batting result pipeline

Training stops cleanly on Leave, death, travel, disconnect, or other valid cleanup.

## New-Player Tutorial

A new save runs a four-step tutorial in World 1 (`TutorialConfig`), then never again:

1. Get 30 Power (any granted Power counts; arrows lead to Basic Training).
2. Earn $2 Cash from batting (Cash earned, so spending never takes progress back; arrows lead to the tee).
3. Purchase and equip the Sandlot Ball (the first Ball upgrade, $2, 3x Power; arrows lead to its pedestal, whose prompt reads Buy). During the tutorial buying it does not equip it: the Inventory tile then returns to the HUD and the spotlight leads to it, its Balls tab and the Sandlot's card, which equips it. It needs a real purchase recorded by the server (`TutorialBoughtBall`) plus the Ball equipped; owning it alone never completes the step. Studio's `OwnAllBalls` is not applied to fresh saves or while the tutorial runs.
4. Reach Level 20 and Rebirth (the Rebirth menu opens with its buttons spotlit); the server's successful Rebirth completes it (only the player's own Rebirth; the Starter Pack's bonus Rebirth only raises the Level Cap to reach).

The server (`PlayerData`) owns, saves and advances it from its own events only: granted Power, batting Cash (`RecordBattingCash`), purchases, Level and Rebirths. There is no client request that moves it; clients only draw the banner, arrows (`GuideArrows`) and spotlight (`Spotlight`) from the `TutorialStep` / `TutorialProgress` attributes. Saves from before Schema 10, or with malformed tutorial fields, skip it when they already show play (any Rebirth, Level, Power, Cash, bought equipment or later World). In Studio, the Workspace attribute `StudioFreshSave` plays as a brand-new player on a throwaway Studio-only record (to test it).

While the tutorial runs (and before the save has loaded), the persistent HUD shows only the Level bar and Power (`HubInterfaces.TutorialFocus`, from `TutorialStep`): no quick-menu tiles (except those it brings back, `HubInterfaces.TutorialTile`: Inventory from the Sandlot purchase on, Rebirth at the Rebirth step), counters, Batting shortcut, Auto Bat, Power purchases or juice pills. The tutorial's banner, arrows and spotlight, the batting / Training controls, feedback and the menus a step opens still show. Everything returns the moment the step becomes Complete.

## Offline Training

Offline Power:

- uses authoritative server timestamps
- uses the best Training Ground the player can use in any unlocked World (from Rebirths, owned game passes and World unlocks)
- applies configured offline-rate limits
- applies the saved equipped Ball's Power multiplier
- applies Rebirth multiplier
- fills at most half the Power still needed for the Level Cap per return (the Welcome Back 3x up to all of it), so offline never finishes a run by itself
- respects Level Cap behavior
- grants once per valid login/session
- only once the new-player tutorial is complete: a return mid-tutorial earns nothing and shows no Welcome Back screen (its logout time is still used up)

Never trust client time or client-provided offline duration.

## Juice

Two consumable drinks (`JuiceConfig`, stored in the existing `OwnedJuices` / `ActiveJuices` save fields): Power Punch (`power_punch`, 2x Power: Training and batting) and Cash Splash (`cash_splash`, 2x Cash: batting), 600 seconds each.

- The client only asks to USE one by id; the server checks the count, uses up exactly one and saves its expiry time (Unix `os.time()`), so a timer keeps running while the player is offline and ends on its own.
- Drinking a running juice adds 600 seconds to it (still 2x, never 4x); the two juices run side by side.
- Offline Training never gets a juice; a hit's juices are snapshotted when its swing is accepted; Training reads them at each grant.
- Juices never change launch strength, distance, equipment or the Level Cap.
- Sold in the Shop (Boost Bundle, Power Punch, Cash Splash) and one comes with the Starter Pack; in Studio, `StudioGrantJuice` (on a `StudioFreshSave` save) and `StudioJuiceSeconds` test them.
- Juice boxes are built from Parts (`JuiceModels`); running juices show as pills on the right of the HUD (`JuiceHUDClient`).

## Monetization

Sold for Robux (`.vscode/MONETIZATION.md`; ids in `MonetizationConfig` and `TrainingConfig`, 0 until created on the Creator Dashboard, when the button reads SOON):

- Three Power developer products in a row under the Level bar (the Batting button below them): +10K / +100K / +1M Power for 11 / 45 / 95 Robux, added exactly (no multipliers, purchased ones included) through the normal Level path (`PlayerData.ClaimPowerProduct`)
- Permanent Power and Cash multipliers (`MonetizationConfig.Multipliers`), bought one tier at a time in the Shop, each tier its own developer product: Power 2x / 2.5x / 3x / 3.5x / 4x for 129 / 169 / 219 / 279 / 359 Robux, Cash 2x / 2.5x / 3x / 3.5x / 4x / 4.5x / 5x for 129 / 159 / 199 / 249 / 309 / 389 / 489 Robux. The server prompts only the next tier ("BuyMultiplier"); the receipt (`PlayerData.ClaimMultiplier`) raises the saved `PowerMultiplierTier` / `CashMultiplierTier` (at least one tier per receipt, up to the top), never from the client. Power multiplies Training, hit and offline Power (and the 3x), never the Power products or the Starter Pack's Power; Cash multiplies batting Cash and a Cash pack's "normal hit". Both stack with juices, are kept through Rebirths, are not giftable and never change launch or distance. Intentionally stronger than the spender targets because a World 4 is planned (`.vscode/ECONOMY.md`)
- Auto Bat game pass (25 Robux), a top-centre ON/OFF button: while ON, the Bat client presses the normal Swing whenever a manual swing would be accepted and the last hit has settled; the server checks every swing as usual
- The Training Ground passes and the Welcome Back 3x product (above)
- The Shop (HUD Shop tile; `ShopClient`, menu "Store"), one scrolling window of colour cards (see UI), each able to show an uploaded picture (`shopImage`, 512 x 512 transparent PNG; grounds 1100 x 500) in place of its built-in icons or 3D models:
  - Starter Pack (game pass, 39 Robux, once): +10K Power, +1 Rebirth (a bonus one: Rebirths and the Level Cap rise, nothing resets), 1 Power Punch and the exclusive Catastrophe Bat; given once ever (saved `StarterPackGranted`)
  - Multipliers: the Power and Cash cards, each showing its next tier as the change it makes ("POWER 2x → 2.5x"), MAXED at the top
  - Cash Packs (developer products, 25 / 59 / 115 / 229 Robux): Cash worth 15 / 50 / 125 / 300 normal hits for the player now (Level, current World, equipped Bat, purchased Cash multiplier; `MonetizationConfig.GetCashPackReward`)
  - Boosts (developer products): Boost Bundle (2 Power Punch + 2 Cash Splash, 95 Robux), Power Punch or Cash Splash (39 Robux each), added to the Inventory, never started
  - Training Grounds: Dragon's Lair always, plus the World's premium ground (Cosmic Rift / Time Machine Lab / Quantum Lab / Snow Globe, one shared pass), through the existing passes, each with its screenshot (`TrainingConfig` `shopImage`) or, until one is uploaded, a 3D preview of its cage (`ReplicatedStorage.TrainingGroundModels`)
  - Gifts: every Shop item can be bought for another player in the server (Gift button → player picker → confirm) through a gift developer product at the same price (`MonetizationConfig.GiftProducts`). The server saves the recipient (and a Cash pack's amount from the recipient's progression) in the buyer's `PendingGifts` before the prompt; the receipt queues the gift in the recipient's saved `GiftInbox`, applied once (`ReceivedGifts`), even after they leave. A gifted ground is a saved `GiftedEntitlements` entry counted exactly like owning its pass
- Bats and Balls are bought for Cash only at their hub display pedestals (each pedestal's ProximityPrompt); there is no Cash equipment menu, and the Shop is the game's only shop menu

`ProductServer` is the one `ProcessReceipt` handler; every receipt pays once (the saved `RobuxPurchases.Receipts` list). Game-pass ownership comes from Roblox (login and the server's purchase event), never saved or taken from the client. Auto Bat starts OFF each session; the server turns it on only for owners.

## Worlds

Each World uses:

Hub / batting area
-> long field/runway
-> progression sections
-> world endpoint

World completion is based on authoritative final forward distance.

Completing a World permanently unlocks the next World. World 4 (Tiny Town; being built in phases, `.vscode/WORLD4_DESIGN.md`) is the last World for now: its end portal plays a temporary "you finished the game" finale instead of a trip. World 3's portal leads to World 4. A save that completed World 3 before World 4 existed has World 4 unlocked on load.

Hits start over in each World after World 1: below the World's `launchLevels.from` (the Level where it opens) a hit uses the early floaty arc (99-143 studs), and from `from` to `to` (the Level where its end is reached) it grows evenly in studs to the end portal (`WorldLaunchSteps`). Each later World has a start pay (`cashBase`; World 2 3,000, World 3 40,000, World 4 500,000, with multipliers 7 / 60 / 600), so even its shortest hit pays more than the previous World's farthest. In an earlier World a later player hits its end every time, at that World's lower pay.

Every hub shares one compact layout (`WorldConfig` `hubLayout`), named from the spawn, which looks into the hub with the batting area and runway behind it: Training Grounds on the left, item displays on the right, an open plaza with the World's event piece in the middle, and the World portal at the back. World 1's four global leaderboards (Level, Time Played, Robux Spent, Cash) stand either side of its portal. Only the art differs between Worlds.

World unlocks persist.

Players may travel between unlocked Worlds through the Worlds menu (from the HUD, or by stepping into the World portal in each hub); the server checks the unlock.

Do not assume future runway/environment redesigns are implemented unless the current code confirms them.

## UI

A functional UI foundation exists for:

- HUD
- Equipment
- Training Grounds
- Rebirth
- Worlds
- Offline Training
- notifications
- mobile/touch controls

For major UI work, use the installed Check-UI skill in:

`.agents/skills/check-ui-clean-roblox/`

Relevant files:

- `SKILL.md`
- `DESIGN_SYSTEM.md`

Use that skill as a design foundation, not as a reason to make every screen identical.

The game's own visual identity is the Inventory's style, which every screen follows (`UICommon`): the rounded FredokaOne font with heavy dark outlines, blue rounded windows with a faint checker and a title riding over the top edge, a red rounded close button, rounded dark blue cards, and chunky studded buttons (green go, grey done, red locked, blue neutral). Preserve it.

The Shop is the colourful exception, built from UICommon's reusable colour-card pieces (for other menus later): a dark Showcase window (Grey theme, the shared menu blur behind it) of bold saturated cards (`UI.ColorCard`, `UI.CardPalettes`: a gradient face, a faint stud pattern, a lighter inner rim, the thick dark outline), huge outlined names tinted to their card (`UI.CardTitle`), big tilted pictures that may overlap the card's edge, a slowly turning sunburst behind featured items (`UI.Sunburst`), white content tiles for packs (`UI.ItemTile`), and one purchase row: a lime Robux price button (`UI.PriceButton`) plus a square purple Gift button (`UI.GiftButton`). Each section ("~ NAME ~") opens with a full-width hero card for its best item, then smaller cards in columns (one column on phones held upright). SOON and owned states keep the card's colour and add a sticker (`UI.CardBadge`); a crossed-out price (`UI.StrikePrice`) appears only for a real comparison (the Boost Bundle's juices bought one at a time).

World-space UI in the hubs (item labels, Training Ground labels, the portal sign, leaderboards, the batter's box label) shows only near the local camera: register new world-space guis with `WorldUIConfig.Register(gui, range)` rather than setting `MaxDistance` by hand.

Do not copy another game's proprietary assets, branding, or exact UI layout.

## Persistence

Use the existing player-data lifecycle.

Do not create separate DataStores for new systems unless explicitly justified.

Preserve existing protections:

- distinguish failed loads from new players
- failed-load sessions must not overwrite known data with defaults
- periodic autosave
- PlayerRemoving save
- BindToClose save
- validation/sanitization
- bounded retry behavior

Current confirmed schema is Schema 12 (Schema 6 removed Tee equipment, Schema 7 added Juice, Schema 8 retired the saved Training Ground selection, Schema 9 added TimePlayed, RobuxSpent and RobuxPurchases for the global leaderboards, Schema 10 added the new-player tutorial: TutorialCompleted, and while unfinished TutorialStep and TutorialProgress, Schema 11 added StarterPackGranted, CashPackQuotes and the gift fields: PendingGifts, GiftInbox, ReceivedGifts, GiftedEntitlements, Schema 12 added the purchased multiplier tier counts PowerMultiplierTier and CashMultiplierTier: 0 for older saves).

The global leaderboards' OrderedDataStores are mirrors of saved values, written from successful saves; PlayerData remains canonical.

Tee equipment data and SelectedTrainingGround are obsolete and should not be reintroduced.

## Multiplayer

Important systems have already received a major multiplayer stabilization pass.

Player state must remain isolated.

Physical stations use server-authoritative occupancy where relevant.

Leaving/death/travel/disconnect must clean up:

- batting occupancy
- Training occupancy
- active hits
- UI state
- animation state

Do not introduce shared player progression state.

## Project Documentation

Treat project documentation as the source of truth for evolving design details.

Relevant files include:

- `GAME_DESIGN.md` - gameplay rules and feature design
- `WORLDS.md` - world progression and unlock rules
- `README.md` - repository/project overview
- `CLAUDE.md` - Claude-specific current project context when present
- `ECONOMY.md` - progression and economy balance: formulas, targets, tables and `tools/balance` simulator results
- `MONETIZATION.md` - Robux products and passes: ids, receipt handling, Auto Bat
- `WORLD4_DESIGN.md` - World 4 (Tiny Town) design and its phased build checklist; each World 4 session works from it
- `CURRENT_STATE.md` - optional current development snapshot when present

Other documentation may be added later when justified, such as:

- `ARCHITECTURE.md`
- `SYSTEMS.md`
- `SECURITY.md`
- `ROADMAP.md`
- `DECISIONS.md`

Do not create documentation files merely because they are listed here.

If documentation conflicts with current code or the developer's latest explicit instruction, point out the conflict rather than silently guessing.

## Context Efficiency

Use the smallest relevant set of files, scripts, and Studio objects needed for the current task.

Do not inspect or rewrite the entire project for a focused change.

Do not repeatedly reread every documentation file for small tasks.

Do not repeatedly restate established game design or architecture.

Ask for clarification only when ambiguity materially affects implementation. Otherwise inspect the project and make the simplest reasonable choice.

## Claude Development Behavior

Claude is the primary implementation agent.

For routine implementation:

- inspect the relevant repository files and Studio state
- edit repository source
- let Rojo sync
- use MCP for runtime verification and required physical objects
- test when practical
- report a concise summary and remaining manual checks

For architecture, security-sensitive systems, difficult debugging, major refactors, or important tradeoffs, reason more carefully before editing.

Do not create complexity simply because a capable model can generate it.

## Current Scope Boundaries

Do not invent unrelated simulator systems unless explicitly requested.

Unless asked, do not add:

- pets
- crates
- quests
- daily rewards
- monetization (the approved exceptions are listed under Monetization: the Training Ground passes, the Welcome Back 3x, the three Power products, Auto Bat, the permanent Power and Cash multipliers, and the Shop's Starter Pack, Cash Packs and Boosts)
- leaderboards (World 1's four global boards are the approved exception)
- trading
- rarity systems
- new currencies
- additional Worlds
- new equipment categories

Normal batting is deterministic and based on Level and the World batted in.

Training Grounds are physical batting cages in a row in each World's hub; access comes from Rebirths or a game pass, once a World the ground stands in is unlocked.

Environmental art, equipment cosmetics, final balance, and future content should remain separate from gameplay architecture unless explicitly requested.
