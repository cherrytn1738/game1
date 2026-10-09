# Baseball Simulator — Game Design

## Core Concept

A Power/Level-based baseball batting simulator where players hit a ball from a batting tee and progress by increasing how far they can hit.

The core gameplay loop is:

Gain Power (training in a future milestone) → Level up → hit farther → earn Cash → reach farther sections → unlock worlds → reach Level Cap → Rebirth → repeat

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
  `PlayerData.GrantPower(player, baseAmount, source)`. Future training uses this API.
- Speed = `55 + 15 * (Level - 1)` studs/second, with fixed 38-degree loft.
  Level is snapshotted at swing acceptance; Power, Rebirths, Bat, Ball, and Tee
  do not modify launch speed. Physics still determines actual final distance.
- `PlayerData.CanRebirth(player)` checks eligibility. `TryRebirth(player)` also
  rejects active batting/hits, increments Rebirths, resets Level/Power, derives
  the new cap, and preserves all other progression. There is no client Rebirth
  remote or final UI yet. Technical safety limit: 1,000 Rebirths.
- Replicated progression attributes are HUD copies. Grants, launches, Rebirths,
  and saves read private server session state.

The historical `BattingTiming` Remote and script filenames remain for Rojo
compatibility, but no timing mechanics remain. The client sends only its batting
session (and optional `Exit`); the server sends final distance/reward feedback.
Contact delay remains 0.20 seconds and swing cooldown remains 0.84 seconds.
Natural stopping, sections, world endpoints, and Cash formulas are unchanged.

No training mechanics, final Rebirth experience, or new cosmetics are included.
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
