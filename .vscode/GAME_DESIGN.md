# Baseball Simulator — Game Design

## Core Concept

A timing-based baseball batting simulator where players hit a ball from a batting tee and progress by increasing how far they can hit.

The core gameplay loop is:

Hit ball → measure distance → earn Cash → improve equipment → hit farther → reach farther sections → unlock new worlds → repeat

The game is not intended to simulate traditional baseball games. The focus is on satisfying batting, distance progression, equipment progression, and reaching increasingly distant environments.

## Batting

Players approach a batting tee to enter batting mode.

While batting:

- The player is positioned and locked at the batting location.
- A timing display controls the result of the swing.
- The player swings based on the timing indicator.
- Timing affects the horizontal direction of the hit.
- Better timing also provides some advantage to hitting power.
- Every valid batting swing makes contact; poor timing does not create a complete miss.
- The server remains authoritative over gameplay-relevant hit results.

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

Bats primarily increase hitting power.

Better Bats allow the player to hit farther and eventually reach sections/worlds that were previously unreachable.

### Ball

Balls primarily increase rewards earned from distance.

The equipped Ball provides a reward multiplier without being the primary source of hitting power.

### Tee

Tees primarily improve the timing mechanic.

Better Tees make favorable timing easier while preserving the importance of player timing skill.

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

As equipment improves, the player should:

- Hit farther
- Reach new field sections
- Earn more Cash
- Purchase better equipment
- Eventually reach the end of the current world
- Unlock the next world

The beginning of the game should leave substantial visible room for future power growth.

Starting equipment should not be capable of approaching the end of the first world.

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
