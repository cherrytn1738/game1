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
- `MONETIZATION.md` (Robux products and passes)

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

Power required for next level, in bands (`ProgressionConfig.LevelBands`):

`10 + 1.5 × (Level − 1)` below Level 20 (the tutorial band: 10, 11, 13, 14, ...), then one band for each Rebirth's 20 new Levels (90 at Level 20, 3,200 at 40, 48,000 at 60, 470,000 at 80, ..., each Level 1.02× the one before inside its band). The bands are solved by `tools/balance` for the chosen LONG pace (run k ≈ 3 + 4 × (k − 1) minutes; see `.vscode/ECONOMY.md`).

Power requirements are consumed as the player levels.

Level Cap:

`20 × (Rebirths + 1)`: 20, 40, 60, ... (the first Rebirth is at Level 20, the end of the tutorial)

Training base (Power per practice hit at Basic Training, before multipliers): 5 at every Level (`Progression.TrainingBase`); Level never scales Power gain.

Launch speed: `ProgressionConfig.LaunchSpeedTable` to Level 21, then `LaunchSpeedSteps`: one measured speed per Level from 22 (distance is erratic in speed, so each is chosen from a Studio sweep for where it lands; `tools/balance/HitMeasurements`), on a curve growing 5% a Level from Level 21, easing to 1.65% at Level 100 and staying there to Level 140 (3,906 studs); World 1's end is reached at Level 150.

New players run a four-step tutorial (`TutorialConfig`): get 30 Power, earn $2 from batting, purchase and equip the Sandlot Ball (a real purchase, not just ownership), reach Level 20 and Rebirth. The server advances and saves it from its own events only (no client request moves it); clients draw the banner, ground arrows (`GuideArrows`) and menu spotlight (`Spotlight`). Older saves that already show play skip it. See GAME_DESIGN.md "New-Player Tutorial".

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

### Equipment Roles (established)

- Ball: multiplies Power gain (`powerGainMultiplier`)
- Bat: multiplies Cash rewards from batting (`cashMultiplier`)
- Level: solely determines hit distance
- Training Ground: multiplies Training Power only
- Rebirth: multiplies Power gain (`Rebirths + 1`)

- Training Power = Training base (5) × ground multiplier × Ball × (Rebirths + 1) × purchased Power multiplier (× Power juice)
- Hit Power = Training base × `HitPowerPerSecond` (0.37) × seconds in play, rounded, × Ball × (Rebirths + 1) × purchased Power multiplier (× Power juice); no ground
- Offline Power = 25% of the best usable ground's rate, no Level term (8 h cap) × saved Ball × (Rebirths + 1) × purchased Power multiplier (never a juice), held to half the Power still needed for the Level Cap (Welcome Back's 3x: twice more, up to all of it)
- Hit Cash = (distance / 80)^1.5 × World `cashMultiplier` (1, 10, 100, 1,000) × section multiplier × Bat × purchased Cash multiplier (× Cash juice), rounded, at least $1
- Purchased multipliers (`MonetizationConfig.Multipliers`, Robux tiers; saved `PowerMultiplierTier` / `CashMultiplierTier`): Power 2x-4x in 5 tiers, Cash 2x-5x in 7 (+0.5x a tier); 1x with none; never distance
- Juices (`JuiceConfig`): Power Punch (2x Power) and Cash Splash (2x Cash), 600 s each, on real time (saved expiry times, so they run while offline); a repeat drink adds 600 s (never 4x); never offline Training; a hit snapshots its juices when its swing is accepted. Sold in the Shop and one in the Starter Pack (Studio: `StudioGrantJuice` on a `StudioFreshSave` save, `StudioJuiceSeconds`)

A hit snapshots the Ball ID, the Bat's Cash multiplier, its juices and the purchased multipliers at swing acceptance.

### Bat

Bat increases Cash earned from real completed hits.

Bat does NOT increase Power or hit distance.

Current Cash multipliers and prices: Wood 1x $0, Metal 1.5x $25, Jungle 2x $120, Amethyst 3x $600, Candy Cane 4x $3,000, Frostbite 6x $15,000, Magma 9x $50,000 (World 1's last purchase), Lightning 13x $1.5M, Dragon Bone 19x $25M, Celestial 28x $120M.

These are balance values from `tools/balance` and may change.

### Ball

Ball increases Power gained from:

- active Training
- real completed hits
- offline Training

Ball does not increase Cash or distance.

World 1's Balls (intended balance): Baseball 1x $0, Sandlot 3x $2 (the tutorial's first purchase), Bubblegum 5x $10, Crystal 12x $40, Frost Comet 30x $150, Inferno 75x $500, Thunder 200x $1,500, Galaxy 500x $4,500, Dragonfire 1,250x $14,000, Supernova 3,500x $40,000. World 2's run 5,000x-200,000x ($150K-$2.2M) and World 3's 300,000x-11,000,000x ($10M-$108M); every ball beats the one before and every earlier series.

Equipment ownership and equipped selections persist.

Server validates purchases and equipping.

---

## Training

Training is the primary source of Power.

Each World's hub has a row of six physical Training Grounds (batting cages) down its left side as seen from the spawn, each with its own plate. Dragon's Lair stands in every World.

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

Current Grounds (Power multiplier on the Training base, one practice hit every ~2 seconds; `TrainingConfig.Hubs` lists each World's row):

- World 1: Basic Training (start, 1x), Enchanted Grove (2 Rebirths, 5x), Sunken Atlantis (4 Rebirths, 10x), Sky Temple (6 Rebirths, 20x), Cosmic Rift (500 Robux game pass, 10x)
- World 2 (placeholder values): Caveman Camp (free once World 2 is unlocked, 25x), Pharaoh's Tomb (8 Rebirths, 35x), Gladiator Colosseum (10 Rebirths, 50x), Samurai Dojo (12 Rebirths, 70x), Time Machine Lab (Cosmic Rift's pass, 35x)
- World 3 (placeholder values): Solar Rooftop (free once World 3 is unlocked, 90x), Robo Factory (14 Rebirths, 120x), Biodome Lab (16 Rebirths, 160x), Lunar Base (18 Rebirths, 210x), Quantum Lab (Cosmic Rift's pass, 120x)
- World 4 (Tiny Town): Sandbox Diamond (free once World 4 is unlocked, 270x), Pinball Cage (20 Rebirths, 350x), Cereal Bowl Stadium (22 Rebirths, 450x), Toy Soldier Fort (24 Rebirths, 580x), Snow Globe (Cosmic Rift's pass, 400x); the standard cage in toy colors for now
- Every World: Dragon's Lair (1000 Robux game pass, 30x, most expensive)

A ground needs a World it stands in to be unlocked. Paid grounds need no Rebirths. Pass ownership is server-checked through MarketplaceService and is never saved; a shared pass (`sharesPass`) is keyed by its owning ground. `gamePassId` is 0 until the passes are created. Offline Training and the Training teleport use the best ground the player can use in any unlocked World.

World 1's themes are fantasy after the first ground and World 3's are futuristic, getting more intricate down the row. Each has its own Blender model (tools/blender/*_cage.py, sharing cage_helpers.py) styled by TrainingCageStyles; a ground whose model is not imported falls back to the standard cage. World 2's grounds use the standard cage in era colors until their own models are made.

---

## Offline Training

Players gain limited Power while offline.

Current design:

- uses the best Training Ground the player can use in any unlocked World
- applies offline rate multiplier
- applies the saved equipped Ball multiplier
- applies Rebirth multiplier
- fills at most half the Power still needed for the Level Cap per return, so offline never finishes a run by itself
- respects Level Cap rules
- uses authoritative server timestamps
- grants once per valid session

Current offline rate:

25% of normal training rate

Current maximum offline duration:

8 hours

Current run cap:

half the Power left to the Level Cap per return (`OfflineRunShare`); Welcome Back's 3x claim adds the reward twice more, up to all of it, never past the cap

These are balance values and may change later.

Do not trust client time.

---

## Cash

Cash is separate from Power.

Cash is earned from real completed batting hits.

Cash is used for purchases.

Bat equipment increases Cash rewards.

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

World 1 now uses a 160-stud-wide runway with 10 cosmetic themed sections (Meadow Run → Starlight Finish), built by `RunwayDecor` (walls, decks, props, backdrops, and floating text-only section and finish titles; no physical signs). It has no distance labels. Some props are Blender meshes from `ServerStorage.RunwayAssets` (not in Git; sources in `tools/blender/`, exports in `assets/models/`), with primitive fallbacks. `SkyServer` sets one golden-hour sky for the whole game, with the sun behind and left of the batter (kept out of the ball's path). Reward tiers and the 5000-stud endpoint are unchanged. World 2 (Time Travel, 6000 studs) and World 3 (Future World, 7000 studs) have their own themed runways on the same system. A giant portal stands at each endpoint: World 1's and World 2's pull the batter through to the next World; World 3's, the last World for now, plays a temporary "you finished the game" finale.

See `GAME_DESIGN.md` → World 1/2/3 Runway Themes and End portal.

## 2× Ball Flight

2× flight speed is DISABLED (`FieldConfig.FlightSpeedUpEnabled = false`): the server rejects requests and the HUD hides the button. The code path remains (server-validated, one-way per hit) and is still covered by BallLauncher.spec.

Reason: 2× changes final distance through bounce/roll physics. Enabling it about 0.7 s into flight repeatably added about 25%. Do not re-enable it unless that is fixed.

See `GAME_DESIGN.md` → 2× Ball Flight.

---

## Hub

Each World with a `hub` config has a compact rectangular player hub (hub x -56 to 118, 220 back) behind its batting station, styled by `HubDecor` (`hub.theme`): Home Field (World 1, a sunken ballpark), Time Travel (World 2, a sunken clockwork plaza) and Future (World 3, a sunken spaceport plaza).

Every hub shares one layout (`WorldConfig` `hubLayout`). The spawn stands just behind the batting area looking into the hub, with the runway behind it; sides are named from that view (left is hub +X):

- front: batting station, runway behind the spawn
- left: the World's row of six Training Grounds, front to back, doors facing the middle
- right: the item displays facing the middle (the World's own ball series, then Bats)
- middle: an open plaza with a path to the back and the World's event piece (World 1 infield diamond, World 2 giant clock, World 3 hologram stage)
- back: the World portal in the middle (opens the Worlds menu when stepped into); World 1's four global leaderboards stand either side of it (Worlds 2 and 3 keep those spots open)
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

Every screen follows the Inventory's style (`UICommon`): FredokaOne with heavy dark outlines, blue rounded windows with a title over the top edge, a red rounded close button, rounded dark blue cards, and chunky studded buttons (green go, grey done, red locked, blue neutral). The skill below is its foundation.

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
- Ball Power multiplier
- Bat Cash multiplier
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

Monetization (`MONETIZATION.md`): `ProductServer` is the one `ProcessReceipt` handler. Power products (+10K / +100K / +1M Power for 11 / 45 / 95 Robux, `MonetizationConfig`) add exactly their amount (no multiplier) through `PlayerData.ClaimPowerProduct` and the normal Level path; the permanent Power and Cash multipliers are one developer product per tier, bought in order from the Shop's Multipliers cards ("BuyMultiplier": the server prompts only the next tier; `PlayerData.ClaimMultiplier` raises the saved tier count, at least one tier per receipt; `StudioPowerTier` / `StudioCashTier` on a `StudioFreshSave` save test them); each receipt pays once (saved `RobuxPurchases.Receipts`). The Auto Bat game pass (25 Robux) is checked through Roblox at login and on purchase; the server sets `AutoBatEnabled` only for owners, and the Bat client then presses the normal Swing when a manual swing would be accepted. Ids are 0 (button reads SOON) until created; `StudioOwnAutoBat` owns Auto Bat in Studio playtests.

The Shop (`ShopClient`, menu "Store", the HUD's Shop tile): Starter Pack (game pass: +10K Power, a bonus Rebirth that resets nothing, 1 Power Punch, the exclusive 2.5x Cash Catastrophe Bat; given once, saved `StarterPackGranted`; its bonus Rebirth never completes the tutorial (only `TryRebirth`, "ManualRebirth"); `StudioOwnStarterPack` on a `StudioFreshSave` save tests it), Cash Packs (Cash worth 15 / 50 / 125 / 300 normal hits: `MonetizationConfig.GetCashPackReward` from the Level, current World and equipped Bat, fixed and saved when Buy is pressed (`PlayerData.QuoteCashPack`, `CashPackQuotes`) so retries pay the same), juice products (Boost Bundle, Power Punch, Cash Splash: added to the Inventory, not started) and Training Grounds (Dragon's Lair plus the World's premium ground, existing passes; 3D cage previews from `ReplicatedStorage.TrainingGroundModels`). Developer products go through `PlayerData.ClaimProduct`. The Equipment menu still opens from the hub displays.

Gifts: every Shop item has a Gift button (picker of other players in the server, then confirm). Gift developer products (`MonetizationConfig.GiftProducts`, same prices, ids 0 until created). `PlayerData.PrepareGift` saves the recipient (and a Cash pack's amount from the recipient's progression) in the buyer's `PendingGifts` before the prompt; `ClaimGift` queues it in the recipient's saved `GiftInbox` (UpdateAsync, keyed by PurchaseId) before granting the receipt; `applyGiftEntries` applies it once (`ReceivedGifts`) now, at their next login, or after an autosave elsewhere. Gifted grounds are `GiftedEntitlements` (`premium_training` = Cosmic Rift's pass, `dragons_lair`), merged into `trainingPasses`, so they count exactly as the pass. Schema 11 also holds these gift fields.

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

Current schema is Schema 12 (Schema 12 added PowerMultiplierTier and CashMultiplierTier, the purchased multiplier tier counts, 0 for older saves; Schema 6 removed Tee equipment; Schema 7 added Juice: OwnedJuices and ActiveJuices; Schema 8 retired SelectedTrainingGround; Schema 9 added TimePlayed, RobuxSpent and RobuxPurchases for the global leaderboards; Schema 10 added the tutorial: TutorialCompleted, TutorialStep, TutorialProgress; Schema 11 added StarterPackGranted, CashPackQuotes, PendingGifts, GiftInbox, ReceivedGifts and GiftedEntitlements).

The global leaderboards (World 1's hub) read OrderedDataStores that mirror saved values; PlayerData stays the source of truth (`Leaderboards.luau`).

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
- monetization beyond the Training Ground passes, the Welcome Back 3x offline-reward product, the three Power products, Auto Bat, the permanent Power and Cash multipliers and the Shop's Starter Pack, Cash Packs and juice products
- leaderboards beyond World 1's four global boards
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
- Bat now multiplies Power gain (later flipped: Balls multiply Power, Bats multiply Cash)
- Ball still multiplies Cash gain (see above)
- Level alone determines batting distance
- 944 automated checks passed
- Schema 6 persistence active

After Milestone 18, the following were implemented:

- Milestone 19B UI presentation pass (HUD, QuickMenu, modals, Welcome Back screen)
- World 1 themed runway (10 sections), with a detailed scenery pass
- 2× ball flight (implemented, currently disabled)

World 2 (Time Travel): per-World Training Grounds with World 2's row, the Time Travel hub, World portals that open the Worlds menu, cross-World Training teleport and offline Training, World 2's ten balls as their own purchase series, and its themed runway. Still NOT implemented: World 2 cage models (it uses the standard cage in era colors).

World 3 (Future World): its themed runway (ten sections and a black-hole landmark), ten balls as the third purchase series, five futuristic cage models, the Future hub, and the temporary finale at its end portal. The Blender models live in ServerStorage.RunwayAssets once imported (sources in tools/blender/, exports in assets/models/).

World 4 (Tiny Town), Phase 1 of `.vscode/WORLD4_DESIGN.md`: World 4's config (offset 24,000, end 8,000, Cash x1,000, ten runway sections with placeholder primitive props, the finale moved to its end portal, World 3's portal now leading there), its row of five grounds plus Dragon's Lair (standard cage), ten balls as the fourth purchase series, launch steps measured in World 4's field, and Level bands to 500. Its runway meshes, Balls, cages, Mouse-Hole Plaza hub and shrinking trip are later phases.

Always inspect the current code before acting on those planned features.