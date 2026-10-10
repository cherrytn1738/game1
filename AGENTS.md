# Roblox Baseball Simulator

## Purpose

Help build a Roblox baseball batting simulator while teaching the
developer Roblox development.

Priorities, in order:

1.  Fun and reliable gameplay
2.  Simple, maintainable architecture
3.  Security for important game state
4.  Incremental development
5.  Scalability when justified

Do not over-engineer early versions of the game.

## Development Environment

-   Windows
-   Roblox Studio
-   Luau
-   VS Code with Codex as the primary AI-assisted coding environment
-   Roblox Studio MCP for inspecting and modifying the open Studio place
-   Git/GitHub for version control
-   Rojo is adopted; repository .luau files are the source of truth
-   Keep Rojo mappings stable unless the requested feature requires a change

Edit script source in the filesystem repository. Use Studio/MCP to inspect and test the live game and manage necessary non-source physical objects. Never directly edit Rojo-managed Source in Studio.

## Working Style

The developer is learning Roblox development. Explain important Roblox
concepts clearly, but avoid unnecessary theory.

Before making a significant change:

1.  Inspect the relevant existing Studio objects/scripts first.
2.  Preserve working behavior unless the requested change requires
    replacing it.
3.  Explain the intended change briefly.
4.  Implement the smallest coherent milestone.
5.  Inspect the result for obvious problems.
6.  Playtest through MCP when useful and supported.
7.  Tell the developer what to manually verify in Roblox Studio.

For small changes, bug fixes, syntax fixes, property changes, and
obvious implementation tasks, skip unnecessary explanation and make the
change directly.

Prefer completing coherent milestones over splitting routine work into
many tiny steps.

Do not make unrelated changes while implementing or debugging a feature.

## Game Identity

This is a Power/Level-based baseball batting simulator.

Core loop:

Train -> Power -> Level -> hit farther -> Cash/sections/worlds -> Level Cap -> confirmed Rebirth -> higher Power gain/cap -> better Training Grounds -> repeat

Players hit a ball from a batting tee into progressively larger themed
worlds rather than playing traditional baseball games.

Established design decisions:

-   Level alone determines authoritative launch strength; every valid hit launches straight at a configured loft.
-   Bat equipment multiplies Power from Training, hits, and offline Training; Ball equipment multiplies Cash only. Tee is not player equipment; the physical batting tee remains.
-   Training is the primary Power source; hits give a small Power reward. Offline training is capped.
-   Rebirth resets Level/Power and increases the Power gain multiplier and Level Cap; preserve other progression.
-   Progression worlds should provide meaningful gameplay/economic
    progression, not only cosmetic changes.

Do not reconsider these decisions unless explicitly asked.

## Current Development Priority

Preserve the implemented core loop, persistence, training, equipment, worlds, and server authority. Expand only the requested milestone. Keep placeholder balance configurable.

Current implementation should be inspected through Roblox Studio MCP
before assuming what has already been built.

## Architecture Principles

Use server authority for important or exploitable gameplay state.

The server should control or validate:

-   Currency and rewards
-   Purchases
-   Upgrade ownership
-   Progression and world unlocks
-   Important gameplay results
-   Authoritative hit/launch results when those systems are implemented

The client should primarily handle:

-   Player input
-   UI
-   Animations
-   Local visual/audio feedback

Do not trust client-provided values for rewards, distance, prices,
ownership, progression, or other important results without server
validation.

Keep RemoteEvents and networking minimal and understandable.

Do not introduce complex frameworks, service architectures,
abstractions, dependencies, or premature optimization unless they solve
a real problem in the current project.

## Roblox Studio MCP Rules

Use Roblox Studio MCP as the primary way to work with the live game.

Before modifying an existing system:

-   Inspect the relevant DataModel hierarchy.
-   Read the relevant scripts.
-   Check existing properties/configuration rather than guessing.
-   Avoid duplicating Instances that already exist.

When making changes:

-   Edit repository source and let Rojo sync; use Studio/MCP for runtime tests and required non-source objects.
-   Keep object names descriptive and consistent.
-   Keep scripts focused on one clear responsibility.
-   Do not silently restructure unrelated parts of the game.
-   Avoid unnecessary Rojo mapping changes.

When possible after implementation:

-   Check Studio output for errors.
-   Use MCP playtesting for basic verification.
-   Still tell the developer what gameplay/visual behavior requires
    manual verification.

Visual correctness must be judged from actual playtesting, not only from
property inspection.

## Development Workflow

Use:

Design -\> Implement -\> Test -\> Fix -\> Commit -\> Continue

Before significantly changing a working system, consider whether a Git
checkpoint should be created.

For debugging:

1.  Identify the likely cause.
2.  Inspect the relevant code/objects.
3.  Make the smallest useful change.
4.  Test it.
5.  Avoid unrelated refactoring.

If a visual/cosmetic issue does not block the current gameplay
milestone, prefer recording it for later polish rather than repeatedly
blocking development on it.

## Code Guidelines

-   Write clear, beginner-readable Luau.
-   Prefer descriptive names over clever abstractions.
-   Keep scripts focused on a clear responsibility.
-   Use Roblox APIs and patterns appropriate for the current Roblox
    Studio version.
-   Avoid unnecessary dependencies.
-   Avoid premature optimization.
-   Use comments only where they explain non-obvious intent.
-   Preserve existing working behavior when modifying code unless the
    task requires changing it.
-   Keep important tuning values easy to find rather than scattering
    magic numbers.
-   When multiple implementations are valid, choose the simplest option
    that is secure and maintainable.

## Project Documentation

Treat project documentation as the source of truth for details that
evolve over time.

Relevant files may include:

-   `GAME_DESIGN.md` - gameplay rules and feature design
-   `ARCHITECTURE.md` - current technical architecture
-   `SYSTEMS.md` - implemented systems and how they interact
-   `ECONOMY.md` - rewards, currencies, prices, and progression balance
-   `WORLDS.md` - world progression and unlock rules
-   `SECURITY.md` - exploit risks and server validation rules
-   `ROADMAP.md` - planned and completed work
-   `DECISIONS.md` - important design/architecture decisions and
    reasoning

Do not duplicate large amounts of these documents unnecessarily.

If a significant design or architectural decision becomes final, suggest
updating the appropriate documentation.

If documentation conflicts with current code or the developer's latest
explicit instruction, point out the conflict rather than silently
guessing.

## Context Efficiency

Use the smallest relevant set of files, scripts, and Studio objects
needed for the current task.

Do not inspect or rewrite the entire project when only a few
objects/scripts are relevant.

Do not repeatedly restate established game design or architecture.

Ask for clarification only when the ambiguity materially affects
implementation. Otherwise inspect the project and make the simplest
reasonable choice.

## AI Development Behavior

Codex should act as the primary implementation agent.

For routine implementation:

-   Inspect the current Studio state.
-   Edit repository source; use MCP for runtime verification and required physical objects.
-   Test when practical.
-   Report a concise summary and manual verification steps.

For architecture, security-sensitive systems, difficult debugging, major
refactors, or important tradeoffs, spend more time reasoning before
making changes.

Do not create complexity simply because an AI agent can generate it.

## Current Scope Boundaries

Normal batting is deterministic: one input starts the presentation, then the server launches a straight physics hit using Level. Animation never decides rewards or launch strength. Timing quality and equipment-level progression are retired.

Training Grounds are logical per-player selections using one plain physical stadium. Keep environmental art, equipment cosmetics, new simulator systems, and future worlds out of scope unless explicitly requested.
