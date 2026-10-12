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
- Click/tap to swing; every valid swing launches straight downfield at a fixed configured loft.
- Level alone determines launch speed. There is no timing fan, quality, spray, or timing power bonus.
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

There are two player equipment categories:

### Bat

Bats remain owned, purchasable, equippable, and persistent. They do not affect launch strength or distance.

Each configured Bat increases Power gain from active Training, real hits, and offline Training. Its `powerGainMultiplier` stacks with Rebirth; it never changes Cash, launch speed, loft, or direction. Multiplier values are placeholder balance.

### Ball

Balls primarily increase rewards earned from distance.

The equipped Ball multiplies Cash rewards only. It does not affect launch strength or Power grants.

The physical batting tee remains part of each station. It is not purchasable, owned, or equipped by players.

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

Worlds are not unlocked by simply purchasing them with Cash.

Example progression:

World 1
→ reach farther sections
→ reach World 1 end
→ unlock World 2
→ progress through World 2
→ eventually unlock World 3

Unlocked worlds remain available permanently and players may return to previously unlocked worlds.

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

## UI Presentation (Milestone 19B)

UICommon owns Check-UI presentation inspired by the four navigation tiles: rounded cyan faces, dark outlines, inset highlights, translucent navy shells, recessed state-colored cards, and outlined GothamBlack typography. Equipment uses a pink accent, Rebirth purple, Worlds cyan, Training gold, and Welcome Back lime. Shared controls have centered hover/press motion and menus have a brief opening pop. Existing client controllers and HubInterfaces still own the same gameplay intents. Only one hub modal is shown at a time; activity, travel, and character cleanup close menus and release the single local blur.

The HUD shows icon-based Cash/Rebirth counters, current world, and a blue studded Level/Power bar with Level Cap and Bat × Rebirth gain. Power fill changes tween locally. QuickMenu keeps its 2×2 tile design and opens Shop, Rebirth, Training (the Training Grounds selector), and Worlds (the World Travel menu) in every world; the unimplemented Inventory/Rewards stubs are retired. Equipment and Worlds use numbered badges rather than invented preview art. Equipment prices, ownership and action states remain separate and readable. Rebirth has a distinct confirmation view; Cancel sends no gameplay request. Short landscape screens compact the headers and confirmation content, and scrolling keeps actions accessible. Portrait cards stack their actions. Mobile modal actions use 52–54 logical pixel targets with a minimum 0.8 scale. Explicit Swing/Leave buttons invoke the existing Tool and server requests; click/Space still work. Touch movement and the hotbar are restored after menus/activities. No progression or reward calculation moved to the client.

Offline gains are already granted by the server. CONTINUE only dismisses the once-per-login presentation; the Power icon and rotating sunburst are cosmetic. Hit results separate distance, Cash and Power and expire after six seconds. Shared notifications replace the current notice and suppress immediate duplicates. Icons reuse already approved image references; the CheckUIIcons registry was not installed in this place. The Worlds globe is made from UI geometry. This presentation pass adds no new systems, monetization controls or environment changes.

## World 1 Runway Themes

World 1's open field is replaced by a 160-stud-wide runway (`WorldConfig` `runway.width`). World 2 keeps the original wide field; width is per-world through `Field.GetWidth(world)`, and the out-of-runway check uses it.

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

- **Floor:** each section's `material` sets the ground's look only. Ground physics stay fixed through an explicit `CustomPhysicalProperties`, so materials never change bounces or rolling. Optional per-section extras: `floorPattern` (a faint caustic texture), `floorGrid` (neon grid lines), and `floorCracks` (glowing lava cracks). Flush edge stripes line both sides, and a checkered band marks each section start.
- **Walls:** two-tone checkered walls (`wallHeight`, `wallThickness`, `wallTileLength`) with a rounded cream cap. `wallTileColor` can override the light tile color for dark themes.
- **Decks and props:** a raised deck behind each wall (`deckWidth`, `deckMaterial`) holds the section's `props`, cycling every `propSpacing` and staggered between sides. Props are scaled up by `propScale`, and small filler clusters by `fillerScale`. Disc-shaped props (lollipops, the rainbow) face back toward the tee.
- **Backdrop:** outer ground (`outerGroundWidth`) with large themed shapes (`backdrop`) every `backdropSpacing` for a horizon.
- **Section titles:** each section's name floats as text on a fully transparent, non-colliding anchor 40 studs up, facing the tee (Meadow Run's floats at 60 studs so it is not over the batter). There are no physical gates or signs. A checkered finish line and a floating "WORLD 1 FINISH" title mark the 5000-stud endpoint, and plain walls continue through the runout.
- **Mesh props:** props listed in `RunwayDecor`'s `MESH_PROPS` use imported Blender models from `ServerStorage.RunwayAssets`, tinted per section. These templates live in the place file, not Rojo/Git, so the place must be saved after importing. Generator scripts and FBX exports are in `tools/blender/` and `assets/models/`. If a template is missing, the prop falls back to its primitive-part version. Every runway prop, filler, and backdrop now has a mesh template (31 in total):
- `MeadowTree` (`tools/blender/meadow_tree.py`): Meadow and jungle trees, and the jungle canopy backdrop.
- Batch 1 (`batch1_props.py`, `RunwayBatch1.fbx`): `Mushroom`, `FlowerPatch`, `Fern`.
- Batch 2 (`batch2_props.py`, `RunwayBatch2.fbx`): fillers `Bush` and `Rock` (per-section `fillers` list, default both), plus Candy Crossing's `Lollipop`, `Cake`, `Gumdrops`, and `CandyCane`.
- Batch 3 (`batch3_props.py`, `RunwayBatch3.fbx`): `Pine`, `Snowman`, `Ice`, `Crystal`, `Geode`, `Cactus`, `Mesa`, `Dune`, `Spire`, `LavaRock`, `Beacon`, `Arch`, `Cloud`, `Rainbow`, `Island`, `Planet`, `Star`, `Moon`, and backdrops `Mountain`, `Volcano`, `Hill`.

Shared Blender helpers live in `tools/blender/prop_helpers.py`. Every model is authored under ~20 units so the import stays below Roblox's 2048-stud part limit; backdrops are scaled up through `BACKDROP_MESHES`. Mesh definitions can also set `materials` (Neon for glowing parts), `lift` (floating props), and `faceTee` (`true` allows a half turn; `"exact"` plus `yawOffset` keeps an authored front toward the tee).

Roblox imports these FBX files at 100× scale; templates are scaled back to their Blender size (1 unit = 1 stud) and pivoted at their base.

The runway has no floating distance labels or floor tick lines; the live HUD shows distance during a hit. World 2's open field keeps its original distance markers.

Every `RunwayDecor` part is anchored with collision, touch, and query disabled, so scenery cannot affect ball flight, measured distance, rewards, or camera occlusion. The full runway is about 3,000 decoration parts.

## Sky

`SkyServer` applies one stylized golden-hour sky to the whole game at server start:
- a late-afternoon sun about 34° up, behind and to the left of the batter, so it lights the runway but never sits in the camera's view of the ball (an earlier sun placed straight down the runway made the ball hard to see)
- warm pink and purple atmosphere, soft pink dynamic clouds, and gentle bloom and sun rays
- a light saturation boost

It reuses the place's existing Lighting effects rather than adding duplicates. All values are look-only and tunable at the top of the script. The sky does not change per section.

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

PlayerData owns the Power grant pipeline. Active Training resolves the server-equipped Bat. Offline grants resolve the normalized saved Bat in the atomic login transaction. Real hits snapshot the Bat ID at acceptance and use it for their once-only reward: `floor(base hit Power * Bat multiplier * Rebirth multiplier)`. Equipment remains locked throughout Training and active hits. Clients send equipment intent, never bonuses or rewards.

Training rate previews use the same whole-Power arithmetic divided by the tick interval. HUD and Rebirth previews show the combined Bat/Rebirth multiplier. Ball Cash rewards and Level-based launch calculations are unchanged.

## Power, Level, and Rebirth (Milestone 15A)

`ProgressionConfig` owns the placeholder formulas. Schema 4 extends the existing
`PlayerProgression` store with Power, Level, Rebirths, and LevelCap. Older saves
receive 0 Power, Level 1, 0 Rebirths, and cap 10 without converting equipment.
Cash, ownership, equipped selections, worlds, and unknown saved fields are preserved.
Malformed new fields are repaired; LevelCap is derived, never trusted from a save.

- Power is progress toward the next Level. Requirement = `100 * Level^2`.
- Requirements are consumed on advancement; one grant can advance multiple Levels.
- At the cap, Power is zero and excess grants are discarded (no overflow bank).
- Level cap = `10 + 10 * Rebirths`; Power gain multiplier = `Rebirths + 1`.
- A valid finalized field hit grants base 2 Power, once, through server-only
  `PlayerData.GrantPower(player, baseAmount, source)`. Active training uses this API; offline grants use the same private grant path inside the atomic load transaction.
- Speed = `55 + 15 * (Level - 1)` studs/second, with fixed 38-degree loft.
  Level is snapshotted at swing acceptance; Power, Rebirths, Bat, and Ball
  do not modify launch speed. Physics still determines actual final distance.
- `PlayerData.CanRebirth(player)` checks eligibility. `TryRebirth(player)` also
  rejects active training/batting/hits, dead characters, and world travel, increments Rebirths, resets Level/Power, derives
  the new cap, revalidates the selected ground, and preserves all other progression.
  The confirmed Rebirth interface calls this server transaction. Technical safety limit: 1,000 Rebirths.
- Replicated progression attributes are HUD copies. Grants, launches, Rebirths,
  and saves read private server session state.

The historical `BattingTiming` Remote and script filenames remain for Rojo
compatibility, but no timing mechanics remain. The client sends only its batting
session (and optional `Exit`); the server sends final distance/reward feedback.
SwingConfig provides a single phase timeline: the named Contact marker is at 0.36 seconds in a 0.96-second swing. ContactTime and Duration drive the visual swing and existing server contact/cooldown; the client-local SwingMarkerReached event reports the marker without requesting a launch.
Natural stopping, sections, world endpoints, and Cash formulas are unchanged.

Milestone 15A added no training mechanics or Rebirth UI. Training is added below in Milestone 15B.
## Training and Offline Power (Milestone 15B)

Training is the primary Power source. One plain TrainingStadium occupies the reserved
right side of World1Hub. Its plate is at hub-relative (70, 0, 70), currently near
(52.8, 0.17, 48.8); the selector is 10 studs left and 5 studs behind it. Only two
plain Parts and two pitch/contact Attachments are needed. The builder reuses them.
Shop, Travel, normal batting, and world endpoints remain unchanged.

TrainingConfig defines logical grounds, not additional stadiums:

| Ground ID | Rebirth requirement | Base Power / interval |
| --- | --- | --- |
| basic_training | 0 | 20 / 2 seconds |
| advanced_training | 1 | 50 / 2 seconds |
| expert_training | 2 | 100 / 2 seconds |

Use the nearby prompt to choose an unlocked ground at no Cash cost. Walk onto the
5-by-5 plate to train automatically. One player occupies it at a time. Selection
is private per-player state, persisted as SelectedTrainingGround; access derives
from Rebirths. Leave training before changing ground, shopping, or rebirthing.
Space/touch Leave restores movement and requires stepping off before re-entry.
Death, respawn, disconnect, invalid data/character, and travel release the stadium.
Normal batting and active-hit state exclude training.

The server grants a configured tick through PlayerData.GrantPower: `floor(ground base Power * equipped Bat multiplier * Rebirth multiplier)`. Level advancement and cap overflow rules remain unchanged.
Ticks do not catch up in bursts after server stalls. At the cap, no Power grant
calls are made. Client-local pitches and the reused Bat swing are presentation
only: no real ball launch, Cash, distance, sections, or world completion occurs.

Schema 5 adds SelectedTrainingGround and LastLogoutTime to PlayerProgression.
Existing profiles keep Cash, Power, Level, Rebirths, equipment, and worlds.
Missing/locked/unknown selections fall back to Basic Training. Old schemas and
missing, zero, malformed, or future timestamps grant no historical offline Power.

Offline base Power = floor(min(elapsed seconds, 8 hours) * selected ground's
base Power / interval * 0.25). The same server grant path multiplies that base by the saved, ownership-validated Bat multiplier and Rebirth multiplier, floors the result to whole Power, and applies cap rules. These are placeholder balance values. The selected
ground is used even when a higher one is unlocked. Offline earning does not
require leaving while actively training.

The login UpdateAsync commits the reward, consumes LastLogoutTime, and claims the
session atomically. A lost-response retry recognizes its own session and does not
grant again. There is no client offline-claim operation. Normal exit records the
server close time; autosaves record a checkpoint time for crash recovery. No
extra periodic DataStore writes are added. A crash before the first autosave after
login conservatively has no new offline timestamp to use.

TrainingRequest accepts only Select(id) or Exit(session). No remote starts
training or accepts rates, Power, timestamps, duration, or Rebirths. The HUD shows
training state/rate alongside existing Power/Level values. Offline notifications
are shown once per client session for absences covering at least 60 seconds,
including capped sessions with no further Power gain.
No themes, stadium art, or equipment cosmetics are included.
## Confirmed Rebirth and Swing Presentation (Milestone 16)

The plain Rebirth interaction is at hub-relative (-35, 0, 120), currently near
(-52.2, 1.62, 98.8), separated from training, batting, and World Travel. The menu
shows current/next multiplier and cap, eligibility, and exact reset/keep/gain
consequences. Rebirth then Confirm are separate actions; Cancel/close/death/travel
clear confirmation. A capped HUD shortcut provides access in other worlds.

RebirthRequest accepts intent only, with no arguments. The server checks session,
private cap eligibility, alive character, active gameplay/travel, per-player
cooldown, and processing state. TryRebirth commits Level, Power, Rebirths, derived
cap, and a validated training selection without yielding. Cash, equipment and
worlds are preserved. Completion schedules an important save through the existing
serialized autosave loop (normally within its next five-second check). A save
already in flight cannot clear a later Rebirth's pending save. The existing store/session leases remain unchanged.

Ground access updates from Rebirths and TrainingConfig immediately. Basic,
Advanced, and Expert rates and all level/world balance remain placeholders.
Rebirth multiplies Power, never Cash or same-Level launch speed. The HUD shows a
Power progress bar, multiplier, aggregated level changes, and capped/Rebirth state.
Offline feedback includes the selected ground, credited time, Power, and resulting
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
