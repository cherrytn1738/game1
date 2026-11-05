# Balance tools

A repeatable model of the game's progression and economy. It loads the real config modules
(`ProgressionConfig`, `EquipmentConfig`, `TrainingConfig`, `WorldConfig`, `FieldConfig`,
`TutorialConfig`, `JuiceConfig`, `MonetizationConfig`) and measured hit physics
(`HitMeasurements.luau`), then plays model players through the game. `.vscode/ECONOMY.md`
explains the model, the targets and the current results.

| File | What it is |
|---|---|
| `SimulateBalance.luau` | The simulator: `run(sources, options) -> {report, csv, bands, speedTable}` |
| `HitMeasurements.luau` | Launch speed -> distance and hit time, measured in Studio |
| `output/*.csv` | The last saved run (see below) |

## Running it in Studio

There is no command-line Luau here, so the simulator runs in Studio (Edit mode, no Play needed):

1. Copy the two `.luau` files straight into `src/server/` as `BalanceSim.luau` and
   `HitMeasurements.luau` and let Rojo sync them. (Single files, not a folder: deleting a synced
   folder afterwards can crash `rojo serve`.)
2. In the command bar (or through MCP `execute_luau`), collect every script's source by name and
   run it in a background thread (a full report takes about a minute; `solveBands` about 20 s):

   ```lua
   local sources = {}
   for _, root in {game.ServerScriptService, game.ReplicatedStorage, game.StarterPlayer, game.StarterPack} do
    for _, d in root:GetDescendants() do
     if d:IsA("LuaSourceContainer") then sources[d.Name] = d.Source end
    end
   end
   _G.SIM = {done = false}
   task.spawn(function()
    local run = loadstring(sources.BalanceSim)()
    _G.SIM = run(sources, {mode = "report", activeRebirths = 24, paceOptions = true})
    _G.SIM.done = true
   end)
   ```

3. Read `_G.SIM.report` (text) and `_G.SIM.csv[name]` (CSV text) when `_G.SIM.done` is true.
   (A full report with the spender scenarios takes a few minutes; poll it in short calls.)
4. Delete the two copies afterwards, one file at a time.

## Modes and options

| Option | Meaning |
|---|---|
| `mode = "report"` | Tutorial, Training-only, active, spender, casual and offline archetypes, Worlds (with the wait from each World's last purchase), purchases, batting vs Training, Level bands |
| `mode = "solveBands"` | Solve the Level bands for a pace: `pace = "FAST" / "MEDIUM" / "LONG"` (run k takes 3 + 1/2/4 x (k - 1) minutes), `bands = 20`; `keepBands = n` keeps the configured bands of the first n Rebirths and solves only the rest (World 4: `bands = 25, keepBands = 18`) |
| `mode = "designSpeed"` | Build `LaunchSpeedTable` from the measurements (`speedPlan` overrides the plan) |
| `distanceShape = {r21, r140, floorFrom}` | A distance curve for Levels 21-140: each Level adds a share of distance falling linearly from `r21` (at 21) to `r140` (at 140), or with `floorFrom` to a floor (solved so Level 140 lands at 505's measurement) held from that Level to 140. Alone it builds an interpolated `LaunchSpeedTable` (`distanceStep` 5 spaces the points); the shipped curve is `{0.05, 0, 100}` |
| `measuredSteps = {tolerance, repeatTolerance, wideTolerance}` | With `distanceShape`: give each Level 22-139 a speed from `HitMeasurements.sweep` whose average lands on the curve (within `tolerance` 0.035, preferring speeds whose hits agree within `repeatTolerance` 0.06, then within `wideTolerance` 0.06), always farther than the Level before; prints the `LaunchSpeedSteps` head (Levels 22-140) and the `ExpectedHitDistances` head. This is how the shipped steps were chosen |
| `tutorialBand = {start, add}` | What-if: the tutorial band (Levels 1-19) as `start + add x (Level - 1)` |
| `solveTutorial = {start, target}` | Solve the tutorial band's `add` so its Level 20 climb takes `target` seconds of Training |
| `prices = {{category, id, price}, ...}` | What-if: equipment prices for this run |
| `scenarios = {...}` | The SPENDERS section's players: `{name, powerTiers, cashTiers, juices, passes, starterPack}` (default: free to play, 1 and 2 tiers each, every tier, + juices, whale) |
| `tierValues = true` | Also play each multiplier tier on its own and report what it saves |
| `casualSpenders = true` | Also run the casual player with each spender scenario (day of each World and the finale) |
| `bandStarts = {...}` | What-if: report with these band starts instead of the config's |
| `activeRebirths`, `trainingRuns`, `casualDays`, `casualMinutes` | How far each archetype plays (the casual player stops at the finale) |
| `paceOptions = true` | Re-solve FAST, MEDIUM and LONG and report their World timings |
| `trainBlock`, `batBlock` | The active player's Training and batting block lengths (60 s / 30 s) |
| `bandGrowth`, `minBandRatio`, `smooth` | Band solving: growth per Level inside a band (1.02), the smallest step between bands (1.8x), smoothing on/off |

`output/` holds `runs_active.csv`, `purchases_active.csv`, `offline.csv`, `casual.csv` and
`levels.csv` from the last report; paste `_G.SIM.csv[name]` into the file to refresh one.

## Re-measuring hits

Hit distance comes from Roblox physics, so the table in `HitMeasurements.luau` must be
re-measured after any change to hit physics, the runway or `FieldConfig.HitTimeScale`. In Studio
(`StudioFreshSave` on, so no real save or leaderboard is touched), set the Workspace attribute
`StudioLaunchSpeed` to a speed (and `StudioLaunchAngle` to a loft in degrees and
`StudioLaunchGravityScale` to a first-flight gravity scale; the table's measurements are at 38
degrees and full gravity), bat once, and read the player's `LastBatDistanceStuds`. The simulator
looks distances up by speed only, so its Levels 1-20 (the early launch curve's steeper loft and
lighter first flight) are only rough. Distance changes erratically from one speed to the next at
every speed (see ECONOMY.md "Hit physics"), so every speed the game uses from Level 22 is measured
exactly, at least twice where possible. To re-measure a range, sweep it from a server loop that
sets `StudioLaunchSpeed` (and `StudioLaunchLevel` 60 for the 38-degree loft) while the ball is
on the tee, with a client loop pressing Swing once it has sat there a moment, then add the hits
to `sweep` and re-run `measuredSteps`. A sweep of 213 speeds takes about 40 minutes.

Hits that reach a World's end are captured by its portal at that distance, so speeds that land
past 7,000 were measured in World 4's field (end 8,000): `far` in `HitMeasurements.luau`. Set the
player's `CurrentWorldId` to `world_4` and stand them on `BattingArea4`'s pad from the server
loop (a fresh save also needs `WorldUnlocked_world_4`), and turn `ForcePortalJourney` off so a
portal hit does not move them. About 21 s a hit at these distances; the first World 4
completion plays the finale (an 11.8 s hold) once.
