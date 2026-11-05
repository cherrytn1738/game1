# World Progression

## Overview

World progression is based on hitting increasingly farther distances.

Each world contains one long continuous batting field divided into multiple distance-based sections.

The structure is:

World
→ Section 1
→ Section 2
→ Section 3
→ ...
→ End Marker
→ Next World

Sections represent progression within a world.

Worlds represent larger progression tiers.

## World Structure

Each world contains:

- A batting location
- A long continuous field/runway
- Multiple distance-based sections
- A configured end distance
- An end marker
- A world arrival/spawn location
- A batting station
- A reference to the next world when applicable

The baseball physically travels through the entire field using normal ball physics.

The ball is not teleported between sections.

## Sections

Sections divide a world's field into distance ranges.

Conceptually:

Section 1:
0 → A studs

Section 2:
A → B studs

Section 3:
B → C studs

World End:
C studs

Exact distances are balance values and should remain configurable.

Sections should be configuration-driven so new sections can be added without rewriting the batting or reward systems.

## Reaching Sections

Sections are not individually unlocked.

There are:

- No section purchase requirements
- No invisible progression walls
- No teleportation between sections

If the player's ball has enough power to physically reach a section, the player has reached that section.

This makes Level progression directly visible through hit distance.

## Section Rewards

Sections can provide different Cash reward multipliers.

The server determines the applicable section from the authoritative final hit result.

Conceptually, rewards can be calculated from:

Base distance reward
× Equipped Ball multiplier
× Section multiplier

Exact multipliers are balance values and should remain configurable.

## World Completion

Every world has a configured end distance.

A visible end marker represents this boundary in the field.

The end marker itself should not determine completion through physical collision.

World completion is determined by the server using authoritative final hit distance:

Final distance >= World end distance

When this occurs for the first time:

1. The current world is completed.
2. The next world is permanently unlocked.
3. The player's world progression is saved.

Repeated hits beyond the same end distance must not repeatedly unlock or reward the same progression event.

## World Unlocking

Worlds are unlocked through batting progression rather than Cash purchases.

For example:

World 1
→ become stronger
→ reach farther sections
→ hit to World 1 end
→ unlock World 2

World 2
→ continue Power/Level progression
→ reach farther sections
→ hit to World 2 end
→ unlock World 3

This keeps world progression directly connected to the game's core batting mechanic.

## World Travel

Once a world has been unlocked, the player may travel between it and previously unlocked worlds.

Travel should not cost Cash.

Locked worlds cannot be entered.

Travel must safely exit any active batting state before moving the player.

Players may return to earlier worlds whenever they want.

## Persistence

World unlocks are persistent player progression.

The server is authoritative over which worlds a player has unlocked.

At minimum, persistent player data includes:

- Cash
- Equipped Bat
- Equipped Ball
- Unlocked worlds

World 1 is always unlocked.

A player does not lose previously unlocked worlds after leaving the game.

## Distance

World and section progression uses authoritative forward/downfield distance.

Progression distance should not be inflated by:

- Ball height
- Sideways travel
- Global world coordinates

Ground roll counts toward the final distance.

The final distance is determined after the ball naturally comes to rest.

## End Markers

Each world should eventually have a visually clear end marker.

The marker represents the world's configured end distance but should not act as a physical wall that interferes with ball flight.

A sufficiently powerful ball may travel beyond the marker.

Completion is based on measured distance rather than collision with the marker.

## Future Worlds

The world system should support adding additional worlds without rewriting core systems.

Adding a future world should primarily require:

- World configuration
- Section configuration
- Physical field/runway
- Batting station
- Arrival position
- End marker

Core systems such as:

- Batting
- Ball physics
- Distance
- Rewards
- Persistence
- World completion

should remain reusable.

## Visual Themes

World and section themes are intentionally not finalized as part of the progression architecture.

Future sections may use different environments and themes, but examples such as grass, snow, desert, volcano, or space are concepts rather than established content unless explicitly finalized later.

Environment art, terrain, props, effects, and other cosmetic work should be implemented during dedicated visual/content milestones.

### Current World Layouts

Every World uses a 160-stud-wide themed runway with ten sections, a 2,000-stud runout and an end portal (`WorldConfig`). The themes are cosmetic; each World keeps the reward tiers 1.0×, 1.15× and 1.35× (the last also in the runout).

| World | Title | End | Cash (start pay + multiplier) | Offset (X) | Sections | Reward tiers |
|---|---|---|---|---|---|---|
| World 1 | Home Field | 5,000 | 0 + ×1 | 0 | Meadow Run → Starlight Finish | 1.0× to 300, 1.15× to 800, 1.35× beyond |
| World 2 | Time Travel | 6,000 | 3,000 + ×7 | 8,000 | Prehistoric Valley → Chrono Nexus | 1.0× to 500, 1.15× to 1,500, 1.35× beyond |
| World 3 | Future World | 7,000 | 40,000 + ×60 | 16,000 | Solar Suburbs → Quantum Singularity | 1.0× to 600, 1.15× to 2,000, 1.35× beyond |
| World 4 | Tiny Town | 8,000 | 500,000 + ×600 | 24,000 | Giant Backyard → Pillow Fort | 1.0× to 700, 1.15× to 2,100, 1.35× beyond |

Each World's end portal pulls the batter through to the next World (World 3's through the singularity into Tiny Town). **World 4 is the last World for now:** its end portal completes it as usual, then plays the temporary "you finished the game" finale instead of a trip. To add a World 5, give World 4 a `nextWorldId` and move the finale (`endPortal.finale`) to the new last World.

**Hits start over in each World.** From World 2 on, a World's hits begin again at the very start of the game's distance (the early floaty arc, 99-146 studs) and grow back to its end portal across the World's Level range (`WorldConfig` `launchLevels`: World 2 150-250, World 3 250-370, World 4 370-490; `ProgressionConfig.GetWorldLaunchLevel`). Below the range (the cheap first Levels of each run) hits use the floaty arc; inside it they grow evenly in studs, so every run lands in two or three new sections and the World's end is reached at the same Level as before. Each later World adds a start pay (`cashBase`) to its Cash, so even its shortest hit pays more than the previous World's farthest. In an earlier World a later player still hits its end every time, at that World's lower pay. Distance stays authoritative on the server: it comes from the server's Level and the World the player bats in.

World 4 is being built in phases (`.vscode/WORLD4_DESIGN.md`). Its configuration, unlock, Training Grounds and Ball series are in place; its runway props, Balls, cages and Mouse-Hole Plaza hub use primitive placeholders until their models are made.

A save that completed a World always has the next World unlocked when it loads (`PlayerData` validate), so players who finished World 3 before World 4 existed find World 4 open on their next visit; their next World 3 portal hit does not replay the finale.

## Current Balance

Exact values such as:

- Section boundaries
- World lengths
- Reward multipliers
- Level required to complete a world

are not considered final design decisions yet.

These values should remain configurable while the core progression and economy are tested.

Early Levels should produce relatively short hits compared with the total length of World 1, leaving substantial room for future progression.
