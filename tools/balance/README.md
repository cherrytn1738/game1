# Balance tools

A repeatable model of the game's progression and economy. It loads the real config modules
(`ProgressionConfig`, `EquipmentConfig`, `TrainingConfig`, `WorldConfig`, `FieldConfig`,
`TutorialConfig`) and measured hit physics (`HitMeasurements.luau`), then plays model players
through the game. `.vscode/ECONOMY.md` explains the model, the targets and the current results.

| File | What it is |
|---|---|
| `SimulateBalance.luau` | The simulator: `run(sources, options) -> {report, csv, bands, speedTable}` |
| `HitMeasurements.luau` | Launch speed -> distance and hit time, measured in Studio |
| `output/*.csv` | The last saved run (see below) |

## Running it in Studio

There is no command-line Luau here, so the simulator runs in Studio (Edit mode, no Play needed):

1. Copy the two `.luau` files into `src/server/TempSpecs/` as `BalanceSim.luau` and
   `HitMeasurements.luau` and let Rojo sync them.
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
4. Delete the `TempSpecs` copies afterwards.

## Modes and options

| Option | Meaning |
|---|---|
| `mode = "report"` | Tutorial, Training-only, active, casual and offline archetypes, Worlds, purchases, batting vs Training, Level bands |
| `mode = "solveBands"` | Solve the Level bands for a pace: `pace = "FAST" / "MEDIUM" / "LONG"` (run k takes 3 + 1/2/4 x (k - 1) minutes), `bands = 20` |
| `mode = "designSpeed"` | Build `LaunchSpeedTable` from the measurements (`speedPlan` overrides the plan) |
| `bandStarts = {...}` | What-if: report with these band starts instead of the config's |
| `activeRebirths`, `trainingRuns`, `casualDays`, `casualMinutes` | How far each archetype plays |
| `paceOptions = true` | Re-solve FAST, MEDIUM and LONG and report their World timings |
| `trainBlock`, `batBlock` | The active player's Training and batting block lengths (60 s / 30 s) |
| `bandGrowth`, `minBandRatio`, `smooth` | Band solving: growth per Level inside a band (1.02), the smallest step between bands (1.8x), smoothing on/off |

`output/` holds `runs_active.csv`, `purchases_active.csv`, `offline.csv`, `casual.csv` and
`levels.csv` from the last report; paste `_G.SIM.csv[name]` into the file to refresh one.

## Re-measuring hits

Hit distance comes from Roblox physics, so the table in `HitMeasurements.luau` must be
re-measured after any change to hit physics, the runway or `FieldConfig.HitTimeScale`. In Studio
(`StudioFreshSave` on, so no real save or leaderboard is touched), set the Workspace attribute
`StudioLaunchSpeed` to a speed, bat once, and read the player's `LastBatDistanceStuds`. Above
about 505 studs/s distance changes erratically from one speed to the next (see ECONOMY.md), so
every speed the table uses up there is measured exactly, twice.
