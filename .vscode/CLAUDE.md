# Roblox Baseball Simulator — Claude Project Context

## Purpose

Help develop a Roblox baseball simulator while preserving the existing working systems and architecture.

Priorities:

1. Fun and reliable gameplay
2. Simple, maintainable architecture
3. Server authority for exploitable/important state
4. Incremental development
5. Scalability only when justified

Do not over-engineer.

---

## Development Environment

- Windows
- Roblox Studio
- Luau
- Rojo
- Git/GitHub
- Claude as AI-assisted coding environment
- Roblox Studio MCP when available

Repository source files are the source of truth.

Do not directly edit Rojo-managed Script/LocalScript/ModuleScript source inside Studio.

Edit filesystem `.luau` files and allow Rojo to sync them into Studio.

Normal workflow:

Design
→ Edit filesystem
→ Rojo sync
→ Test in Studio
→ Fix
→ Git commit
→ Git push

---

## Important Project Documentation

Read relevant documentation before making major architectural/design changes:

- `GAME_DESIGN.md`
- `WORLDS.md`
- `AGENTS.md`

Do not reread every document unnecessarily for small fixes.

Use the smallest relevant context.

If documentation conflicts with current code or my latest instruction, point out the conflict.

---

## Game Concept

This is a Roblox simulator centered around baseball batting.

Current high-level loop:

Train
→ gain Power
→ Level Up
→ hit farther
→ earn Cash
→ reach Level Cap
→ Rebirth
→ gain a larger Power multiplier
→ unlock better Training Grounds
→ increase Level Cap
→ progress farther
→ unlock additional Worlds
→ repeat

---

## Current Batting Design

The old timing mechanic has been retired.

There is:

- no timing fan
- no Perfect/Good/Okay/Miss
- no timing-based power
- no timing-based horizontal direction

Current batting:

Player enters batting position
→ presses/taps Swing
→ baseball swing animation plays
→ ball launches straight downfield
→ fixed configured launch angle
→ Level determines authoritative launch strength
→ Roblox physics handles flight/bounces/roll
→ ball naturally stops
→ final forward distance is calculated
→ rewards are awarded
→ ball resets

Level is the sole long-term determinant of hit distance.

Bat equipment must not affect distance.

---

## Ball Physics

The ball uses Roblox physics.

After launch:

- flies
- bounces
- rolls
- loses speed naturally

A hit finalizes when the ball has valid ground contact and remains below low linear/angular speed thresholds for approximately 0.75 seconds.

There is a generous emergency timeout for pathological cases.

Rolling distance counts.

Distance is authoritative server-side forward/downfield distance, not total 3D displacement.

---

## Power / Level Progression

Persistent progression includes:

- Power
- Level
- Rebirths
- Level Cap

Current progression formula:

Power required for next level:

`100 × Level²`

Power requirements are consumed as the player levels.

Level Cap:

`10 + 10 × Rebirths`

Power gain multiplier:

`Rebirths + 1`

At the Level Cap, normal Level advancement stops.

Rebirth resets:

- Level
- Power

Rebirth preserves:

- Cash
- equipment
- world progression
- unrelated progression

Rebirth increases:

- Rebirth count
- Power gain multiplier
- Level Cap
- access to better Training Grounds

---

## Equipment

Active player equipment categories:

- Bat
- Ball

Tee is no longer player equipment.

The physical batting tee still exists in the world.

### Bat

Bat increases Power gained from:

- active Training
- real completed hits
- offline Training

Bat does NOT increase hit distance.

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

These are temporary balance values.

### Ball

Ball increases Cash earned from batting.

Ball does not increase Power or distance.

Equipment ownership and equipped selections persist.

Server validates purchases and equipping.

---

## Training

Training is the primary source of Power.

Each World's hub has a row of six physical Training Grounds (batting cages) down its left side, each with its own plate. Dragon's Lair stands in every World.

Player walks onto an unlocked ground's training plate:

→ Training begins automatically
→ character is positioned/locked
→ client practice-ball pitch loop runs
→ existing swing animation repeats
→ server grants Power automatically

Training ends through Leave, death, travel, disconnect, or other valid cleanup.

Training practice balls:

- do not calculate distance
- do not award Cash
- do not unlock Worlds
- do not use real batting reward logic

### Training Grounds

Each Training Ground is a separate physical cage (developer decision, superseding the old single logical stadium). There is no saved selection: the plate you stand on is the ground you train at.

Current Grounds (Power multiplier on 20 Power every ~2 seconds; `TrainingConfig.Hubs` lists each World's row):

- World 1: Basic Training (start, 1x), Enchanted Grove (2 Rebirths, 5x), Sunken Atlantis (4 Rebirths, 10x), Sky Temple (6 Rebirths, 20x), Cosmic Rift (500 Robux game pass, 10x)
- World 2 (placeholder values): Caveman Camp (free once World 2 is unlocked, 25x), Pharaoh's Tomb (8 Rebirths, 35x), Gladiator Colosseum (10 Rebirths, 50x), Samurai Dojo (12 Rebirths, 70x), Time Machine Lab (Cosmic Rift's pass, 35x)
- Every World: Dragon's Lair (1000 Robux game pass, 30x, most expensive)

A ground needs a World it stands in to be unlocked. Paid grounds need no Rebirths. Pass ownership is server-checked through MarketplaceService and is never saved; a shared pass (`sharesPass`) is keyed by its owning ground. `gamePassId` is 0 until the passes are created. Offline Training and the Training teleport use the best ground the player can use in any unlocked World.

World 1's themes are fantasy after the first ground and get more intricate down the row. Each has its own Blender model (tools/blender/*_cage.py, sharing cage_helpers.py) styled by TrainingCageStyles; a ground whose model is not imported falls back to the standard cage. World 2's grounds use the standard cage in era colors until their own models are made.

---

## Offline Training

Players gain limited Power while offline.

Current design:

- uses the best Training Ground the player can use in any unlocked World
- applies offline rate multiplier
- applies equipped Bat multiplier
- applies Rebirth multiplier
- respects Level Cap rules
- uses authoritative server timestamps
- grants once per valid session

Current offline rate:

25% of normal training rate

Current maximum offline duration:

8 hours

These are balance values and may change later.

Do not trust client time.

---

## Cash

Cash is separate from Power.

Cash is earned from real completed batting hits.

Cash is used for purchases.

Ball equipment increases Cash rewards.

Cash is server-authoritative and persistent.

---

## Worlds

Each World contains:

Hub / batting location
→ long batting runway
→ distance sections
→ end marker

The player completes a World by legitimately hitting far enough to reach or exceed its configured end distance.

Completion unlocks the next World permanently.

World unlocks are not purchased with Cash.

World unlocks persist.

Players can travel between unlocked Worlds.

World completion is based on authoritative final forward distance.

---

## Field / Runway Direction

The old design used a broad/open field.

World 1 now uses a 160-stud-wide runway with 10 cosmetic themed sections (Meadow Run → Starlight Finish), built by `RunwayDecor` (walls, decks, props, backdrops, and floating text-only section and finish titles; no physical signs). It has no distance labels. Some props are Blender meshes from `ServerStorage.RunwayAssets` (not in Git; sources in `tools/blender/`, exports in `assets/models/`), with primitive fallbacks. `SkyServer` sets one golden-hour sky for the whole game, with the sun behind and left of the batter (kept out of the ball's path). Reward tiers and the 5000-stud endpoint are unchanged. World 2 still uses the original wide field with distance markers.

See `GAME_DESIGN.md` → World 1 Runway Themes.

## 2× Ball Flight

2× flight speed is DISABLED (`FieldConfig.FlightSpeedUpEnabled = false`): the server rejects requests and the HUD hides the button. The code path remains (server-validated, one-way per hit) and is still covered by BallLauncher.spec.

Reason: 2× changes final distance through bounce/roll physics. Enabling it about 0.7 s into flight repeatably added about 25%. Do not re-enable it unless that is fixed.

See `GAME_DESIGN.md` → 2× Ball Flight.

---

## Hub

Each World with a `hub` config has a rectangular player hub (136 studs left of the tee line, 86 right, 222 back) behind its batting station, styled by `HubDecor` (`hub.theme`): Home Field (World 1, a sunken ballpark) and Time Travel (World 2, a sunken clockwork plaza).

Layout (the same in both hubs):

- front edge: batting station / field
- left: the World's row of six Training Grounds
- right: the World portal and the item displays in one line facing the cages (World 1: Balls and Bats; World 2: its own Time Travel balls and Bats); the portal opens the Worlds menu when stepped into
- middle: an event area (World 1 infield diamond, World 2 giant clock)
- the Shop, Travel and Rebirth stations are removed for now

The hub intentionally leaves space for future content.

Do not fill empty space with invented systems.

---

## UI

A functional UI foundation already exists for:

- HUD
- Equipment
- Training Grounds
- Rebirth
- Worlds
- Offline Training
- notifications
- mobile controls

A major visual redesign is planned/ongoing.

Desired style:

- bright Roblox simulator aesthetic
- bold outlined typography
- saturated colors
- strong visual hierarchy
- dimensional/tactile buttons
- clear locked/equipped/selected states
- responsive desktop/mobile layouts

Reference design direction resembles modern simulator UI, but do not copy another game's assets or branding.

---

## Check-UI Skill

A Roblox UI design skill is installed in:

`.agents/skills/check-ui-clean-roblox/`

It includes:

- `SKILL.md`
- `DESIGN_SYSTEM.md`

Use it when performing major UI work.

Treat it as a design foundation rather than a reason to make every screen identical.

Preserve the game's own visual identity.

---

## Server Authority

Server must control or validate:

- Cash
- Power
- Levels
- Rebirths
- Level Cap
- Training Power
- offline Power
- equipment ownership/equipping
- purchases/prices
- Bat Power multiplier
- Ball Cash multiplier
- world unlocks
- travel eligibility
- launch strength/direction/angle
- final hit distance
- rewards
- important persistent data

Client primarily handles:

- input
- UI
- camera
- animations
- practice-ball visuals
- local audio/visual feedback

Never trust client-provided authoritative reward, distance, multiplier, price, ownership, Level, Power, or progression values.

---

## Multiplayer

Important systems have already received a major two-player stabilization pass.

Player state must remain isolated.

Physical stations use server-authoritative occupancy where relevant.

Leaving/death/travel/disconnect must clean up:

- batting occupancy
- Training occupancy
- active hits
- UI state
- animation state

Do not introduce shared player progression state.

---

## Persistence

The game uses one existing DataStore/player-data lifecycle.

Do not create separate DataStores for new systems unless explicitly justified.

Existing safety principles include:

- failed loads are distinguished from new players
- failed-load sessions cannot overwrite known data with defaults
- periodic autosave
- PlayerRemoving save
- BindToClose save
- validation/sanitization
- bounded retry behavior

Preserve these protections.

Current schema is Schema 8 (Schema 6 removed Tee equipment; Schema 7 added Juice: OwnedJuices and ActiveJuices; Schema 8 retired SelectedTrainingGround).

Tee equipment data was removed from active saves.

---

## Existing Testing State

A major stabilization milestone passed:

- 642 assertions during earlier stabilization
- later equipment milestone reached 944 automated checks
- multiplayer isolation tested
- phone emulator tested
- persistence A→B→C sessions tested
- offline reward duplication tested
- Rebirth spam tested
- station occupancy tested
- leaving during ball flight tested
- no known major runtime regressions at last verification

Do not assume new changes remain safe; continue testing modified systems.

---

## Coding Style

- clear beginner-readable Luau
- descriptive names
- focused scripts/modules
- minimal abstractions
- no unnecessary frameworks
- no unrelated refactoring during bug fixes
- comments only when they explain non-obvious intent

Prefer the simplest secure implementation.

---

## Feature Discipline

Do not invent unrelated simulator systems.

Unless explicitly requested, do not add:

- pets
- crates
- quests
- daily rewards
- monetization
- leaderboards
- trading
- rarity systems
- new currencies
- World 3
- equipment categories

---

## Visual Development

Do not add cosmetics during gameplay architecture milestones unless explicitly requested.

When visual work is requested, follow that scope deliberately.

Equipment/stadium/world themes should not be invented during unrelated backend changes.

---

## Current Known Project State

The latest explicitly confirmed completed milestone is:

Milestone 18:
- Tee removed as player equipment
- Bat now multiplies Power gain
- Ball still multiplies Cash gain
- Level alone determines batting distance
- 944 automated checks passed
- Schema 6 persistence active

After Milestone 18, the following were implemented:

- Milestone 19B UI presentation pass (HUD, QuickMenu, modals, Welcome Back screen)
- World 1 themed runway (10 sections), with a detailed scenery pass
- 2× ball flight (implemented, currently disabled)

World 2 (Time Travel) is being built in stages. Stage 2 (done): per-World Training Grounds with World 2's row, the Time Travel hub, World portals that open the Worlds menu, and cross-World Training teleport and offline Training. World 2's ten balls (Stage 4) are in as their own purchase series (models pending import). Still NOT implemented: World 2's runway zones (Stage 3) and World 2 cage models (Stage 5).

Always inspect the current code before acting on those planned features.