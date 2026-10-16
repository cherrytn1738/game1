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
- Bat equipment multiplies Power gained from Training, real hits, and offline Training.
- Ball equipment multiplies Cash rewards only.
- Tee is not player equipment; the physical batting tee remains part of the batting station.
- Training is the primary Power source; real hits give a small Power reward.
- Offline Training is supported and capped.
- Rebirth resets Level/Power and increases Power gain multiplier and Level Cap while preserving unrelated progression.
- Training Grounds are six separate physical batting cages in a row in the World 1 hub; the plate a player stands on is the ground they train at. There is no saved ground selection.
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

- Power requirements currently scale as `100 * Level^2`.
- Level Cap currently scales as `10 + 10 * Rebirths`.
- Rebirth Power multiplier currently scales as `Rebirths + 1`.
- These are implementation/balance values, not immutable design decisions.
- Level is the sole long-term determinant of batting distance.

### Bat

Bat equipment increases Power gain.

Current placeholder multipliers:

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

Bat does not affect launch distance.

### Ball

Ball equipment increases Cash rewards from batting.

Ball does not affect Power gain or launch distance.

### Training Grounds

Six physical Grounds, each its own batting cage, stand in two rows of three on either side of the World 1 hub (parallel to the runway, grounds 1-3 on the right, 4-6 on the left):

- Basic Training: available from the start, 1x
- Enchanted Grove: 2 Rebirths, 5x
- Sunken Atlantis: 4 Rebirths, 10x
- Sky Temple: 6 Rebirths, 20x
- Dragon's Lair: 500 Robux game pass, 10x (intentionally below Sky Temple)
- Cosmic Rift: 1000 Robux game pass, 30x

Multipliers apply to the first ground's base Power. Paid grounds need no Rebirths. Game-pass ownership is checked by the server through MarketplaceService, never saved and never trusted from the client.

Grounds 2-6 are fantasy themed and get more intricate down the row. The themes are visual only and never affect Power.

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

There are six physical Training Grounds, each with its own plate and at most one occupant.

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

## Offline Training

Offline Power:

- uses authoritative server timestamps
- uses the best Training Ground the player can use (from Rebirths and owned game passes)
- applies configured offline-rate limits
- applies Bat Power multiplier
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

Completing a World permanently unlocks the next World.

World unlocks persist.

Players may travel between unlocked Worlds.

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

Preserve the game's own visual identity.

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

Current confirmed schema is Schema 8 (Schema 6 removed Tee equipment, Schema 7 added Juice, Schema 8 retired the saved Training Ground selection).

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
- monetization (the two Training Ground game passes are the approved exception)
- leaderboards
- trading
- rarity systems
- new currencies
- additional Worlds
- new equipment categories

Normal batting is deterministic and Level-based.

Training Grounds are six physical batting cages in a row; access comes from Rebirths or a game pass.

Environmental art, equipment cosmetics, final balance, and future content should remain separate from gameplay architecture unless explicitly requested.
