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

- Level alone determines authoritative launch strength.
- Every valid batting hit launches straight at a configured loft; the old timing mechanic is retired.
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

- Power requirements currently scale as `9 * Level + 1` below Level 20 (the quick early band: 10, 19, 28, ...) and `100 * Level^2` from Level 20 on.
- Level Cap currently scales as `20 + 10 * Rebirths` (the first Rebirth is at Level 20).
- Rebirth Power multiplier currently scales as `Rebirths + 1`.
- These are implementation/balance values, not immutable design decisions.
- Level is the sole long-term determinant of batting distance.

### Equipment Roles

- Ball: multiplies Power gain (Training, real hits, offline Training).
- Bat: multiplies Cash rewards from batting.
- Level: solely determines hit distance.
- Training Ground: multiplies Training Power only.
- Rebirth: multiplies Power gain.

The server derives every multiplier from the authoritative equipped IDs through `EquipmentConfig`; a hit snapshots the Ball ID and Bat Cash multiplier when the swing is accepted.

Formulas (whole Power and Cash are rounded down once, after all bonuses):

- Training Power = ground base Power (base × ground multiplier) × Ball × (Rebirths + 1) × any Power juice
- Hit Power = `HitPowerReward` × Ball × (Rebirths + 1) × any Power juice (no ground)
- Offline Power = the best usable ground's capped offline base × Ball × (Rebirths + 1)
- Hit Cash = distance × Cash per stud × Bat × section multiplier × any Cash juice

### Bat

Bat equipment increases Cash earned from batting.

Current placeholder Cash multipliers (the old Power values, carried over until the Bat balance pass):

- Wood: 1.0x
- Metal: 1.5x
- Jungle: 2.0x
- Amethyst: 2.5x
- Candy Cane: 3.2x
- Frostbite: 4.0x
- Magma: 5.0x
- Lightning: 6.5x
- Dragon Bone: 8.0x
- Celestial: 10.0x

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

Balls are sold in purchase series, each bought in order: World 1's ten (Baseball to Supernova Ball), World 2's ten (Dino Egg to Chrono Orb, 12x-95x placeholders) and World 3's ten (Solar Cell to Singularity Orb, 110x-750x placeholders). World 2 and 3 keep their old Cash numbers as Power multipliers until their balance pass, so they sit below World 1's late balls for now. A later World's series needs that World unlocked but none of the earlier series' balls. Each series has its own server-issued purchase token. Owned balls of any series stay equippable everywhere.

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

Every World:

- Dragon's Lair: 1000 Robux game pass, 30x (the most expensive ground)

Multipliers apply to the first ground's base Power. A ground can only be used once a World it stands in is unlocked; World 1 grounds stay usable after reaching World 2. Paid grounds need no Rebirths. Game-pass ownership is checked by the server through MarketplaceService, never saved and never trusted from the client.

World 1's grounds 2-6 are fantasy themed and World 3's grounds 1-5 futuristic, each with its own cage model, getting more intricate down the row; World 2's use the standard cage in era colors for now. The themes are visual only and never affect Power.

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
3. Buy the Sandlot Ball (the first Ball upgrade, $2, 3x Power; arrows lead to its pedestal, where the Shop opens with the Ball spotlit).
4. Reach Level 20 and Rebirth (the Rebirth menu opens with its buttons spotlit); the server's successful Rebirth completes it.

The server (`PlayerData`) owns, saves and advances it from its own events only: granted Power, batting Cash (`RecordBattingCash`), purchases, Level and Rebirths. There is no client request that moves it; clients only draw the banner, arrows (`GuideArrows`) and spotlight (`Spotlight`) from the `TutorialStep` / `TutorialProgress` attributes. Saves from before Schema 10, or with malformed tutorial fields, skip it when they already show play (any Rebirth, Level, Power, Cash, bought equipment or later World). In Studio, the Workspace attribute `StudioFreshSave` plays as a brand-new player on a throwaway Studio-only record (to test it).

## Offline Training

Offline Power:

- uses authoritative server timestamps
- uses the best Training Ground the player can use in any unlocked World (from Rebirths, owned game passes and World unlocks)
- applies configured offline-rate limits
- applies the saved equipped Ball's Power multiplier
- applies Rebirth multiplier
- respects Level Cap behavior
- grants once per valid login/session

Never trust client time or client-provided offline duration.

## Worlds

Each World uses:

Hub / batting area
-> long field/runway
-> progression sections
-> world endpoint

World completion is based on authoritative final forward distance.

Completing a World permanently unlocks the next World. World 3 (Future World) is the last World for now: its end portal plays a temporary "you finished the game" finale instead of a trip.

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

Current confirmed schema is Schema 10 (Schema 6 removed Tee equipment, Schema 7 added Juice, Schema 8 retired the saved Training Ground selection, Schema 9 added TimePlayed, RobuxSpent and RobuxPurchases for the global leaderboards, Schema 10 added the new-player tutorial: TutorialCompleted, and while unfinished TutorialStep and TutorialProgress).

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
- `CURRENT_STATE.md` - optional current development snapshot when present

Other documentation may be added later when justified, such as:

- `ARCHITECTURE.md`
- `SYSTEMS.md`
- `ECONOMY.md`
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
- monetization (the two Training Ground game passes and the Welcome Back 3x offline-reward developer product are the approved exceptions)
- leaderboards (World 1's four global boards are the approved exception)
- trading
- rarity systems
- new currencies
- additional Worlds
- new equipment categories

Normal batting is deterministic and Level-based.

Training Grounds are physical batting cages in a row in each World's hub; access comes from Rebirths or a game pass, once a World the ground stands in is unlocked.

Environmental art, equipment cosmetics, final balance, and future content should remain separate from gameplay architecture unless explicitly requested.
