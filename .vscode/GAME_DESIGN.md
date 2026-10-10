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

There are three primary equipment categories:

### Bat

Bats remain owned, purchasable, equippable, and persistent. They do not affect launch strength or distance.

No replacement Bat gameplay bonus is defined yet.

### Ball

Balls primarily increase rewards earned from distance.

The equipped Ball multiplies Cash rewards only. It does not affect launch strength or Power grants.

### Tee

Tees remain owned, purchasable, equippable, and persistent. Their timing assistance is retired.

No replacement Tee gameplay bonus is defined yet.

## Equipment Progression

Equipment progression is based on distinct equipment rather than numeric equipment levels.

Players progress from one Bat, Ball, or Tee to another piece of equipment with its own configuration and gameplay effects.

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
  Level is snapshotted at swing acceptance; Power, Rebirths, Bat, Ball, and Tee
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

The server grants a configured tick through PlayerData.GrantPower. Rebirth
multiplication, Level advancement, and cap overflow rules remain unchanged.
Ticks do not catch up in bursts after server stalls. At the cap, no Power grant
calls are made. Client-local pitches and the reused Bat swing are presentation
only: no real ball launch, Cash, distance, sections, or world completion occurs.

Schema 5 adds SelectedTrainingGround and LastLogoutTime to PlayerProgression.
Existing profiles keep Cash, Power, Level, Rebirths, equipment, and worlds.
Missing/locked/unknown selections fall back to Basic Training. Old schemas and
missing, zero, malformed, or future timestamps grant no historical offline Power.

Offline base Power = floor(min(elapsed seconds, 8 hours) * selected ground's
base Power / interval * 0.25). The same server grant path applies the Rebirth
multiplier and cap rules. These are placeholder balance values. The selected
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
already in flight cannot clear a later Rebirth's pending save. Schema 5 and the
existing store/session leases remain unchanged.

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

Environment themes, equipment appearances, Ball effects, Tee effects, UI styling, and other cosmetic work should be handled in dedicated visual milestones rather than being added piecemeal during gameplay-system development.
