-- Balance simulator. Loads the game's real config modules (ProgressionConfig, EquipmentConfig,
-- TrainingConfig, WorldConfig, FieldConfig, TutorialConfig) from their sources, plus measured hits
-- (HitMeasurements), and plays model players through the progression:
--   tutorial        the four tutorial steps, with measured walking/clicking times
--   trainingOnly    after the tutorial, only Trains at the best free ground; Rebirths at the cap
--   active          Trains, bats in blocks, buys upgrades as Cash allows; Rebirths at the cap
--   offline         Offline Training rewards at progression snapshots
--   casual          one active session a day, Offline Training between
-- It can also design tuning: the Level -> launch speed table (designSpeedTable) and the Level
-- requirement bands for a pacing (solveBands). See tools/balance/README.md.
--
-- Usage (any Luau with loadstring, e.g. Studio): require/loadstring this file to get
-- run(sources, options) -> {report = string, csv = {[name] = text}, bands = {...}, speedTable = {...}}
-- where sources maps module names to their source text (as the test runner collects them).
return function(sources, options)
 options = options or {}
 local out, csv = {}, {}
 local function say(...) table.insert(out, string.format(...)) end

 -- Modules ----------------------------------------------------------------------------------
 local loaded = {}
 local storage = {WaitForChild = function(_, name) return name end, FindFirstChild = function(_, name) return name end}
 local env
 local function load(name)
  if loaded[name] == nil then
   local fn = assert(loadstring(assert(sources[name], "missing source " .. name)), name)
   setfenv(fn, env)
   loaded[name] = fn()
  end
  return loaded[name]
 end
 env = setmetatable({game = {GetService = function() return storage end, ReplicatedStorage = storage},
  require = load, workspace = {}}, {__index = getfenv()})
 local P = load("ProgressionConfig")
 local Equipment = load("EquipmentConfig")
 local Training = load("TrainingConfig")
 local Worlds = load("WorldConfig")
 local Field = load("FieldConfig")
 local Tutorial = load("TutorialConfig")
 local Measured = load("HitMeasurements")

 -- Assumptions (seconds), from Studio playtests --------------------------------------------
 local A = {
  launchDelay = 0.3, -- swing acceptance to launch, inside the measured hit seconds
  cycleOverhead = 1.2, -- ball reset, swing cooldown and reaction between hits
  walk = 6, -- between a Training Ground and the tee
  shop = 4, -- one purchase at a display or in the Shop
  rebirth = 5, -- opening Rebirth and confirming
  travel = 15, -- a World portal trip
  firstContact = Training.PracticePitchSeconds, -- first practice hit after stepping on a plate
  contact = Training.PracticeCycleSeconds,
  trainBlock = options.trainBlock or 60, -- active player: Training before each batting block
  batBlock = options.batBlock or 30, -- active player: batting per block
 }

 -- Hit physics from measurements ------------------------------------------------------------
 local usable = {}
 for _, point in Measured.points do table.insert(usable, point) end
 table.sort(usable, function(a, b) return a.speed < b.speed end)
 local gap = Measured.erraticFrom and {from = Measured.erraticFrom, to = math.huge}
 local warnings = {}
 -- Speeds in the erratic range were measured one at a time: each trial is {distance, seconds}.
 local erratic = {}
 for speed, trials in Measured.erratic or {} do
  local sum, time, low, high = 0, 0, math.huge, -math.huge
  for _, trial in trials do
   sum, time = sum + trial[1], time + trial[2]
   low, high = math.min(low, trial[1]), math.max(high, trial[1])
  end
  erratic[speed] = {speed = speed, distance = sum / #trials, seconds = time / #trials, low = low, high = high, trials = #trials}
 end
 local function hitAt(speed)
  local exact = erratic[speed]
  if exact then return exact.distance, exact.seconds end
  if gap and speed > gap.from then
   warnings[string.format("speed %.1f is in the erratic range (from %d) but was never measured", speed, gap.from)] = true
  end
  if speed <= usable[1].speed then return usable[1].distance, usable[1].seconds end
  for index = 2, #usable do
   local low, high = usable[index - 1], usable[index]
   if speed <= high.speed then
    local f = (speed - low.speed) / (high.speed - low.speed)
    return low.distance + (high.distance - low.distance) * f, low.seconds + (high.seconds - low.seconds) * f
   end
  end
  local last = usable[#usable]
  return last.distance, last.seconds
 end
 -- The speed that lands `distance` (monotonic stretches only), or nil inside the gap.
 local function speedFor(distance)
  for index = 2, #usable do
   local low, high = usable[index - 1], usable[index]
   local across = gap and low.speed <= gap.from and high.speed >= gap.to
   if not across and distance >= low.distance - 1e-6 and distance <= high.distance + 1e-6 then
    local f = math.clamp((distance - low.distance) / (high.distance - low.distance), 0, 1)
    return low.speed + (high.speed - low.speed) * f
   end
  end
  return nil
 end

 -- Speed table design ------------------------------------------------------------------------
 -- Levels 1 to gapLevel: an even (exponential) distance curve up to the last smooth measurement.
 -- Above it distance is erratic in speed, so Levels step through measured speeds. Each range
 -- (between two World ends, with margins) uses speeds whose every trial lands inside it, in
 -- rising order with no overlap between their trials, spread evenly over its Levels (plateaus of
 -- at least minPlateau Levels). The last range (no high) reaches the last World's end: its speed
 -- is the one whose neighbouring speeds also reach it (least sensitive), the lowest on a tie.
 local function designSpeedTable(plan)
  local last = usable[#usable]
  local d1 = usable[1].distance
  local growth = (last.distance / d1) ^ (1 / (plan.gapLevel - 1))
  local function distanceAt(level) return d1 * growth ^ (level - 1) end
  local levels = {}
  for level = 1, plan.gapLevel, 10 do table.insert(levels, level) end
  if levels[#levels] ~= plan.gapLevel then table.insert(levels, plan.gapLevel) end
  local table_ = {}
  for _, level in levels do
   local speed = assert(speedFor(distanceAt(level)), "no measured speed lands " .. distanceAt(level) .. " studs")
   table.insert(table_, {level, math.floor(speed * 10 + 0.5) / 10})
  end
  local candidates = {}
  for _, entry in erratic do if entry.trials >= (plan.minTrials or 2) then table.insert(candidates, entry) end end
  table.sort(candidates, function(a, b) return a.distance < b.distance or a.distance == b.distance and a.speed < b.speed end)
  local function inside(entry, range)
   return entry.low >= range.low and (not range.high or entry.high <= range.high)
  end
  local steps, previous = {}, last.distance
  for _, range in plan.ranges do
   local chain = {}
   if range.high then
    for _, entry in candidates do
     if inside(entry, range) and entry.low > previous then table.insert(chain, entry) previous = entry.high end
    end
   else
    local best, bestNeighbours
    for _, entry in candidates do
     if inside(entry, range) then
      local neighbours = 0
      for _, offset in {-1, 1} do
       local other = erratic[entry.speed + offset]
       if other and inside(other, range) then neighbours += 1 end
      end
      if not best or neighbours > bestNeighbours or neighbours == bestNeighbours and entry.speed < best.speed then
       best, bestNeighbours = entry, neighbours
      end
     end
    end
    chain = {best}
   end
   local levels = range.toLevel and range.toLevel - range.fromLevel + 1 or 1
   local count = math.min(#chain, math.max(1, math.floor(levels / (range.minPlateau or plan.minPlateau or 1))))
   assert(count >= 1, string.format("no speed measured %d times lands in %.0f-%s", plan.minTrials or 2, range.low, tostring(range.high)))
   -- Use `count` of the chain, spread evenly by distance (each pick the nearest to its target,
   -- leaving enough of the chain for the picks after it).
   local pick = 0
   for index = 1, count do
    local target = count == 1 and (chain[1].distance + chain[#chain].distance) / 2
     or chain[1].distance + (chain[#chain].distance - chain[1].distance) * (index - 1) / (count - 1)
    local best = pick + 1
    for candidate = pick + 1, #chain - (count - index) do
     if math.abs(chain[candidate].distance - target) < math.abs(chain[best].distance - target) then best = candidate end
    end
    pick = best
    local entry = chain[pick]
    table.insert(steps, {range.fromLevel + math.floor((index - 1) * levels / count), entry.speed, entry.distance})
   end
  end
  return table_, steps, distanceAt
 end

 -- Player state ------------------------------------------------------------------------------
 local function ballMultiplier(s) return Equipment.Get("Ball", s.ball).powerGainMultiplier end
 local function batMultiplier(s) return Equipment.Get("Bat", s.bat).cashMultiplier end
 local function newState()
  return {time = 0, level = 1, power = 0, rebirths = 0, cash = 0, ball = "baseball", bat = "wood_bat",
   ownedBalls = {baseball = true}, ownedBats = {wood_bat = true}, world = Worlds.StartingWorldId,
   unlocked = {[Worlds.StartingWorldId] = true}, completed = {}, hits = 0, contacts = 0,
   runStart = 0, runs = {}, purchases = {}, worldTimes = {}, hitsSincePurchase = 0,
   trainingPower = 0, battingPower = 0, earned = 0}
 end
 local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, inner in value do result[key] = copy(inner) end
  return result
 end
 local function cap(s) return P.GetLevelCap(s.rebirths) end
 local function advance(s, amount)
  local state = {Power = s.power, Level = s.level, LevelCap = cap(s)}
  P.Advance(state, amount)
  s.power, s.level = state.Power, state.Level
 end
 -- The best free ground only changes with Rebirths and World unlocks, so it is cached.
 local function bestGround(s)
  local key = s.rebirths .. (s.unlocked.world_2 and "b" or "") .. (s.unlocked.world_3 and "c" or "")
  if s.groundKey ~= key then s.groundKey, s.groundId = key, Training.GetBestGround(s.rebirths, {}, s.unlocked).id end
  return Training.Get(s.groundId)
 end
 local function trainContact(s)
  local ground = bestGround(s)
  local grant = P.GetPowerGrant(P.GetTrainingBase(s.level) * ground.powerMultiplier, s.rebirths, ballMultiplier(s))
  s.time += A.contact
  s.contacts += 1
  s.trainingPower += grant
  advance(s, grant)
  return grant
 end
 local function landing(s)
  local world = Worlds.Get(s.world)
  local distance, seconds = hitAt(P.GetLaunchSpeed(s.level))
  return world, distance, seconds
 end
 local function hit(s)
  local world, distance, seconds = landing(s)
  local landed = math.min(distance, world.endDistance)
  local section = Field.GetSection(landed, world)
  local cash = P.GetHitCash(landed, world.cashMultiplier, section.rewardMultiplier, batMultiplier(s))
  local power = P.GetPowerGrant(P.GetHitPowerBase(s.level, seconds - A.launchDelay), s.rebirths, ballMultiplier(s))
  s.cash += cash
  s.earned += cash
  s.battingPower += power
  advance(s, power)
  s.time += seconds + A.cycleOverhead
  s.hits += 1
  s.hitsSincePurchase += 1
  if distance >= world.endDistance and not s.completed[world.id] then
   s.completed[world.id] = true
   s.worldTimes[world.id] = {time = s.time, rebirths = s.rebirths, level = s.level}
   if world.nextWorldId then
    s.unlocked[world.nextWorldId] = true
    s.world = world.nextWorldId
    s.time += A.travel
   end
  end
  return cash, power, seconds
 end
 local function equipBest(s)
  local best, bestValue = s.ball, ballMultiplier(s)
  for id in s.ownedBalls do
   local value = Equipment.Get("Ball", id).powerGainMultiplier
   if value > bestValue then best, bestValue = id, value end
  end
  s.ball = best
  local bat, batValue = s.bat, batMultiplier(s)
  for id in s.ownedBats do
   local value = Equipment.Get("Bat", id).cashMultiplier
   if value > batValue then bat, batValue = id, value end
  end
  s.bat = bat
 end
 -- Cash for one hit right now (current Level, World and Bat).
 local function cashPerHit(s)
  local world = Worlds.Get(s.world)
  local landed = math.min(hitAt(P.GetLaunchSpeed(s.level)), world.endDistance)
  return P.GetHitCash(landed, world.cashMultiplier, Field.GetSection(landed, world).rewardMultiplier, batMultiplier(s))
 end
 -- improvement: the new multiplier over the equipped one. costHits: the price in hits at the
 -- current Cash per hit. paybackHits (Bats): hits for the extra Cash to repay the price.
 local function record(s, kind, item)
  local multiplier = kind == "Ball" and item.powerGainMultiplier or item.cashMultiplier
  local improvement = multiplier / (kind == "Ball" and ballMultiplier(s) or batMultiplier(s))
  local perHit = cashPerHit(s)
  table.insert(s.purchases, {kind = kind, id = item.id, name = item.displayName, price = item.price,
   time = s.time, rebirths = s.rebirths, level = s.level, hits = s.hitsSincePurchase,
   multiplier = multiplier, improvement = improvement, costHits = item.price / perHit,
   paybackHits = kind == "Bat" and item.price / (perHit * (improvement - 1)) or nil})
  s.hitsSincePurchase = 0
 end
 -- Greedy shopping: the strongest affordable Ball that beats the equipped one, then the next Bat.
 local function shop(s)
  local bought = true
  while bought do
   bought = false
   local choice
   for _, series in Equipment.GetSeries("Ball") do
    if not series.requiredWorld or s.unlocked[series.requiredWorld] then
     local item = Equipment.GetNextPurchase("Ball", s.ownedBalls, series.id)
     if item and item.price <= s.cash and (not choice or item.powerGainMultiplier > choice.powerGainMultiplier) then choice = item end
    end
   end
   if choice and choice.powerGainMultiplier > ballMultiplier(s) then
    s.cash -= choice.price
    s.ownedBalls[choice.id] = true
    s.time += A.shop
    record(s, "Ball", choice)
    bought = true
   else
    local bat = Equipment.GetNextPurchase("Bat", s.ownedBats)
    if bat and bat.price <= s.cash then
     s.cash -= bat.price
     s.ownedBats[bat.id] = true
     s.time += A.shop
     record(s, "Bat", bat)
     bought = true
    end
   end
   equipBest(s)
  end
 end
 local function rebirth(s)
  table.insert(s.runs, {rebirths = s.rebirths, start = s.runStart, finish = s.time, duration = s.time - s.runStart,
   ball = s.ball, bat = s.bat, ground = bestGround(s).id, world = s.world, cash = s.cash})
  s.rebirths += 1
  s.level, s.power = P.StartingLevel, P.StartingPower
  s.time += A.rebirth
  s.runStart = s.time
 end

 -- Archetypes -------------------------------------------------------------------------------
 -- The tutorial, step by step, as measured in Studio (walks and clicks included).
 local function tutorial()
  local s = newState()
  local steps = {}
  s.time += 4 -- spawn to Basic Training
  local earned = 0
  s.time += A.firstContact - A.contact
  while earned < Tutorial.PowerGoal do earned += trainContact(s) end
  steps.EarnPower = s.time
  s.time += 4.6 -- to the tee
  local cash = 0
  while cash < Tutorial.CashGoal do cash += hit(s) end
  steps.EarnCash = s.time - steps.EarnPower
  s.time += 5.6 + 3 -- to the Sandlot Ball's pedestal and two clicks
  local ball = Equipment.Get("Ball", Tutorial.BallId)
  if s.cash >= ball.price then s.cash -= ball.price s.ownedBalls[ball.id] = true equipBest(s) end
  steps.BuyBall = s.time - steps.EarnPower - steps.EarnCash
  local before = s.time
  s.time += 7.7 + A.firstContact - A.contact -- back to Basic Training
  while s.level < cap(s) do trainContact(s) end
  steps.ReachLevel = s.time - before
  rebirth(s)
  steps.total = s.time
  s.runs = {}
  s.runStart = s.time
  return s, steps
 end
 -- One run: from the state's current Level to the cap, then Rebirth.
 local function runTrainingOnly(s)
  local start = s.time
  s.time += A.firstContact - A.contact
  while s.level < cap(s) do trainContact(s) end
  rebirth(s)
  return s.time - start
 end
 local function runActive(s, timeLimit)
  local start = s.time
  local limit = start + (timeLimit or math.huge)
  while s.time < limit do
   local blockEnd = s.time + A.trainBlock
   s.time += A.firstContact - A.contact
   while s.time < blockEnd and s.level < cap(s) do trainContact(s) end
   if s.level >= cap(s) then rebirth(s) return s.time - start end
   s.time += A.walk
   local batEnd = s.time + A.batBlock
   repeat hit(s) shop(s) until s.time >= batEnd
   s.time += A.walk
  end
  return s.time - start
 end
 -- Offline Power for a return, as the server grants it: the time-based reward, held to the run
 -- cap (a share of the Power left to the Level Cap). Returns that, the time-based reward, and
 -- the Power left before the return.
 local function offlinePower(s, seconds)
  local base = Training.GetOfflineReward(1, 1 + seconds, bestGround(s).id, P.GetTrainingBase(s.level))
  local timed = P.GetPowerGrant(base, s.rebirths, ballMultiplier(s))
  local remaining = P.GetPowerToLevelCap({Level = s.level, Power = s.power, LevelCap = cap(s)})
  return math.min(timed, Training.GetOfflinePowerLimit(remaining)), timed, remaining
 end
 -- Casual returning player: one active session a day; Offline Training (granted once on
 -- return, from the time away, under the run cap) covers the rest. s.time counts play time only.
 local function runCasual(s, days, sessionMinutes)
  local rows = {}
  local away = 24 * 3600 - sessionMinutes * 60
  for day = 1, days do
   if day > 1 then
    local grant = offlinePower(s, away)
    s.offlinePower = (s.offlinePower or 0) + grant
    advance(s, grant)
   end
   local sessionEnd = s.time + sessionMinutes * 60
   while s.time < sessionEnd do runActive(s, sessionEnd - s.time) end
   table.insert(rows, {day = day, rebirths = s.rebirths, level = s.level, world = s.world, ball = s.ball, bat = s.bat})
  end
  return rows
 end

 -- Pacing targets and band solving -------------------------------------------------------------
 -- Target length (minutes) of each Rebirth's run: run 1 is the Training-only anchor; later runs
 -- grow by `slope` minutes each (FAST 1, MEDIUM 2, LONG 4).
 local paces = {FAST = 1, MEDIUM = 2, LONG = 4}
 local function targetMinutes(slope, rebirths)
  return 3 + slope * (rebirths - 1)
 end
 local bandGrowth = options.bandGrowth or 1.02
 local function setBands(starts)
  local bands = {P.LevelBands[1]}
  for k, start in starts do
   table.insert(bands, {fromLevel = P.LevelsPerRebirth * k, start = start, growth = bandGrowth})
  end
  P.LevelBands = bands
 end
 local function round2(value)
  local digits = math.floor(math.log10(value)) - 1
  local unit = 10 ^ math.max(0, digits)
  return math.floor(value / unit + 0.5) * unit
 end
 local originalBands = P.LevelBands
 local function solveBands(slope, count)
  local starts = {}
  local s = tutorial()
  for k = 1, count do
   local target = targetMinutes(slope, k) * 60
   local low, high = math.log(1), math.log(1e15)
   for _ = 1, 30 do
    if task and task.wait then task.wait() end -- keep Studio responsive
    local mid = (low + high) / 2
    starts[k] = math.exp(mid)
    setBands(starts)
    local trial = copy(s)
    local duration = k == 1 and runTrainingOnly(trial) or runActive(trial, target * 4)
    if duration > target then high = mid else low = mid end
   end
   starts[k] = math.exp((low + high) / 2)
   setBands(starts)
   if k == 1 then runTrainingOnly(s) else runActive(s) end
  end
  if options.smooth == false then
   for k, start in starts do starts[k] = round2(start) end
   return starts
  end
  -- Smooth the bands (run 1 is the exact Training-only anchor): Power arrives in bursts (a new
  -- ground, several Balls on reaching a World), so exact per-run solutions jump around and even
  -- dip. Bands are kept non-decreasing (pooling dips), at least minRatio apart, and averaged with
  -- their neighbours, so each Rebirth's band is a clean breakpoint; run lengths then vary a little
  -- around the targets (the report shows the real ones).
  local logs = {}
  for k, start in starts do logs[k] = math.log(start) end
  local blocks = {}
  for k = 2, #logs do
   table.insert(blocks, {sum = logs[k], count = 1})
   while #blocks > 1 and blocks[#blocks - 1].sum / blocks[#blocks - 1].count > blocks[#blocks].sum / blocks[#blocks].count do
    local top = table.remove(blocks)
    blocks[#blocks].sum += top.sum
    blocks[#blocks].count += top.count
   end
  end
  local k = 2
  for _, block in blocks do
   for _ = 1, block.count do logs[k] = block.sum / block.count k += 1 end
  end
  local averaged = table.clone(logs)
  for index = 3, #logs - 1 do averaged[index] = (logs[index - 1] + logs[index] + logs[index + 1]) / 3 end
  local minRatio = math.log(options.minBandRatio or 1.8)
  for index = 2, #averaged do averaged[index] = math.max(averaged[index], averaged[index - 1] + minRatio) end
  for index, value in averaged do starts[index] = round2(math.exp(value)) end
  return starts
 end

 -- Reports ----------------------------------------------------------------------------------
 local function minutes(seconds) return string.format("%.1f", seconds / 60) end
 local function clock(seconds)
  local m = math.floor(seconds / 60)
  return m >= 60 and string.format("%dh %02dm", math.floor(m / 60), m % 60) or string.format("%dm %02ds", m, math.floor(seconds % 60))
 end
 local function short(value)
  for _, unit in {{1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}} do
   if math.abs(value) >= unit[1] then return string.format("%.3g%s", value / unit[1], unit[2]) end
  end
  return string.format("%.4g", value)
 end

 -- What-if: report with these band starts instead of the config's (e.g. just solved).
 if options.bandStarts then setBands(options.bandStarts) originalBands = P.LevelBands end
 local mode = options.mode or "report"
 local result = {}
 if mode == "designSpeed" then
  -- Margins around each World's end allow for the ~1-2% trial-to-trial spread of a hit.
  local plan = options.speedPlan or {gapLevel = 140, minPlateau = 10, minTrials = 2, ranges = {
   {fromLevel = 141, toLevel = 149, low = 4000, high = 4850, minPlateau = 3}, -- World 1, short of its end
   {fromLevel = 150, toLevel = 249, low = 5090, high = 5880}, -- past World 1's end, short of World 2's
   {fromLevel = 250, toLevel = 369, low = 6100, high = 6880}, -- past World 2's end, short of World 3's
   {fromLevel = 370, low = Worlds.Worlds[#Worlds.Worlds].endDistance}, -- reaches the last World's end
  }}
  local table_, steps, distanceAt = designSpeedTable(plan)
  local parts = {}
  for _, point in table_ do table.insert(parts, string.format("{%d, %s}", point[1], tostring(point[2]))) end
  say("LaunchSpeedTable = {%s}", table.concat(parts, ", "))
  parts = {}
  for _, step in steps do table.insert(parts, string.format("{%d, %s}", step[1], tostring(step[2]))) end
  say("LaunchSpeedSteps = {%s}", table.concat(parts, ", "))
  for _, point in table_ do
   say("  Level %4d  speed %6.1f  target %7.0f  model %7.0f studs", point[1], point[2], distanceAt(point[1]), (hitAt(point[2])))
  end
  for _, step in steps do say("  Levels from %3d  speed %6.1f  measured %7.0f studs", step[1], step[2], step[3]) end
  result.speedTable, result.speedSteps = table_, steps
 elseif mode == "solveBands" then
  local slope = paces[options.pace or "MEDIUM"]
  local starts = solveBands(slope, options.bands or 20)
  local parts = {}
  for k, start in starts do table.insert(parts, string.format("  {fromLevel = %d, start = %s, growth = %s},", P.LevelsPerRebirth * k, string.format("%.0f", start), tostring(bandGrowth))) end
  say("LevelBands for %s (run k target %s + %d x (k - 1) min):", options.pace or "MEDIUM", "3", slope)
  say("%s", table.concat(parts, "\n"))
  local last, before = starts[#starts], starts[#starts - 1]
  say("LevelBandTailGrowth = %.2f", last / before)
  result.bands = starts
 end
 P.LevelBands = (mode == "solveBands" and options.keepSolved) and P.LevelBands or originalBands

 if mode == "report" then
  -- Tutorial.
  local s, steps = tutorial()
  say("TUTORIAL (fresh player, measured walks)")
  say("  Get 30 Power      %5.1f s   (target ~15)", steps.EarnPower)
  say("  Earn $2 batting   %5.1f s   (target 15-20)", steps.EarnCash)
  say("  Buy Sandlot Ball  %5.1f s   (target 10-15)", steps.BuyBall)
  say("  Level 20 + Rebirth%6.1f s   (target 45-60 of Training)", steps.ReachLevel)
  say("  Whole tutorial    %5.1f s   (target 90-120)", steps.total)
  local afterTutorial = copy(s)

  -- Training-only runs.
  say("")
  say("TRAINING ONLY (Sandlot Ball, best free ground, no shopping)")
  local t = copy(afterTutorial)
  local total = t.time
  for _ = 1, options.trainingRuns or 8 do
   local cap0 = cap(t)
   local ground = bestGround(t)
   local duration = runTrainingOnly(t)
   total = t.time
   say("  Rebirth %2d -> %2d  Level cap %4d  %-16s %7s min  (total %s)", t.rebirths - 1, t.rebirths, cap0, ground.displayName, minutes(duration), clock(total))
  end

  -- Active player.
  say("")
  say("ACTIVE (Train %ds, bat %ds, buy the best affordable Ball then the next Bat, Rebirth at cap)", A.trainBlock, A.batBlock)
  local a = copy(afterTutorial)
  local maxRebirths = options.activeRebirths or 20
  local guard = 0
  while a.rebirths < maxRebirths and guard < 200 do guard += 1 runActive(a) end
  local runRows = {"rebirths,cap,start_min,duration_min,ball,ball_multiplier,bat,bat_multiplier,ground,ground_multiplier,world"}
  for _, run in a.runs do
   local ball, bat, ground = Equipment.Get("Ball", run.ball), Equipment.Get("Bat", run.bat), Training.Get(run.ground)
   say("  Run %2d (cap %3d)  %6s min  ends %8s  %-16s x%-8s %-15s x%-5s %-18s %s", run.rebirths, P.GetLevelCap(run.rebirths),
    minutes(run.duration), clock(run.finish), ball.displayName, short(ball.powerGainMultiplier), bat.displayName,
    tostring(bat.cashMultiplier), ground.displayName, run.world)
   table.insert(runRows, string.format("%d,%d,%.2f,%.2f,%s,%s,%s,%s,%s,%s,%s", run.rebirths, P.GetLevelCap(run.rebirths), run.start / 60,
    run.duration / 60, run.ball, ball.powerGainMultiplier, run.bat, bat.cashMultiplier, run.ground, ground.powerMultiplier, run.world))
  end
  csv["runs_active.csv"] = table.concat(runRows, "\n")
  say("  Batting share of Power: %.0f%% (Training %s, batting %s)", 100 * a.battingPower / (a.battingPower + a.trainingPower),
   short(a.trainingPower), short(a.battingPower))

  say("")
  say("WORLDS (active player)")
  for _, world in Worlds.Worlds do
   local reached = a.worldTimes[world.id]
   say("  %-10s end %5d studs: %s", world.title, world.endDistance,
    reached and string.format("completed at %s (Rebirth %d, Level %d)", clock(reached.time), reached.rebirths, reached.level) or "not completed")
  end

  say("")
  say("PURCHASES (active player; improvement over the equipped item, price in hits at that moment)")
  local purchaseRows = {"kind,id,price,multiplier,improvement,time_min,rebirths,level,hits_since_previous,price_in_hits,bat_payback_hits"}
  for _, purchase in a.purchases do
   say("  %8s  %-4s %-18s %8s  x%-8s (x%-4.2g) Rebirth %2d Level %3d  %3d hits since last, costs %4.0f hits%s", clock(purchase.time),
    purchase.kind, purchase.name, "$" .. short(purchase.price), short(purchase.multiplier), purchase.improvement, purchase.rebirths,
    purchase.level, purchase.hits, purchase.costHits, purchase.paybackHits and string.format(", pays back in %.0f", purchase.paybackHits) or "")
   table.insert(purchaseRows, string.format("%s,%s,%d,%s,%.3f,%.2f,%d,%d,%d,%.1f,%s", purchase.kind, purchase.id, purchase.price,
    tostring(purchase.multiplier), purchase.improvement, purchase.time / 60, purchase.rebirths, purchase.level, purchase.hits,
    purchase.costHits, purchase.paybackHits and string.format("%.1f", purchase.paybackHits) or ""))
  end
  csv["purchases_active.csv"] = table.concat(purchaseRows, "\n")
  local unbought = {}
  for _, category in {"Ball", "Bat"} do
   local owned = category == "Ball" and a.ownedBalls or a.ownedBats
   for _, item in Equipment.GetItems(category) do if not owned[item.id] then table.insert(unbought, item.displayName) end end
  end
  say("  Not bought by Rebirth %d: %s", a.rebirths, #unbought > 0 and table.concat(unbought, ", ") or "none")

  -- Batting vs Training.
  say("")
  say("BATTING vs TRAINING (Power per minute, same Level/Ball/Rebirth)")
  for _, level in {1, 3, 20, 40, 80, 140, 150, 250, 370} do
   local probe = newState()
   probe.level = level
   probe.rebirths = math.max(0, math.ceil(level / P.LevelsPerRebirth) - 1)
   probe.world = level >= 250 and "world_3" or level >= 150 and "world_2" or "world_1"
   local _, distance, seconds = landing(probe)
   local batting = P.GetHitPowerBase(level, seconds - A.launchDelay) / (seconds + A.cycleOverhead) * 60
   local basic = P.GetTrainingBase(level) / A.contact * 60
   local ground = Training.GetBestGround(probe.rebirths, {}, {world_1 = true, world_2 = level >= 150, world_3 = level >= 250})
   say("  Level %3d  hit %5.0f studs %4.1fs: batting %6.1f vs Basic Training %6.1f (%3.0f%%) vs %s x%d (%4.1f%%)", level,
    distance, seconds, batting, basic, 100 * batting / basic, ground.displayName, ground.powerMultiplier,
    100 * batting / (basic * ground.powerMultiplier))
  end

  -- Offline.
  say("")
  -- Offline is 25% of Training at the best ground for the time away (8 h cap), held to a share of
  -- the Power left to the Level Cap; the 3x claim adds it twice more, up to all of it. Measured
  -- against that remaining run, logged out at the first Level of the run's new 20-Level band
  -- (Power 0) and, to compare, at Level 1 just after the Rebirth.
  say("OFFLINE TRAINING (25%%, 8 h cap; a return fills at most %.0f%% of the run left, the 3x up to %.0f%%)",
   100 * Training.OfflineRunShare, 100 * Training.OfflineTriple.runShare)
  say("  Share of the run left: time-based (before the cap) -> granted / with the 3x")
  -- Minutes of active Training (best free ground, from this state) that earn this much Power.
  local function trainingMinutes(s, power)
   local probe, gained = copy(s), 0
   while gained < power and probe.level < cap(probe) do gained += trainContact(probe) end
   return (probe.time - s.time) / 60
  end
  local durations = {15, 60, 240, 480}
  local offlineRows = {"rebirths,logout_level,ball,ground,minutes_away,remaining,time_power,power,triple_power,time_share,share,triple_share,power_training_minutes,run_training_minutes"}
  for _, run in a.runs do
   if ({[1] = true, [3] = true, [6] = true, [9] = true, [12] = true, [15] = true, [18] = true})[run.rebirths] then
    for _, logoutLevel in {P.LevelsPerRebirth * run.rebirths, P.StartingLevel} do
     local probe = newState()
     probe.rebirths, probe.ball, probe.level = run.rebirths, run.ball, logoutLevel
     probe.unlocked = {world_1 = true, world_2 = run.world ~= "world_1", world_3 = run.world == "world_3"}
     local ground = bestGround(probe)
     local parts, remaining, runMinutes, lastMinutes = {}, nil, nil, nil
     for _, duration in durations do
      local power, timePower, left = offlinePower(probe, duration * 60)
      remaining = left
      runMinutes = runMinutes or trainingMinutes(probe, left)
      lastMinutes = trainingMinutes(probe, power)
      local triple = power + Training.GetOfflineTripleExtra(power, left)
      table.insert(parts, string.format("%s %5.0f%% -> %3.0f%% / %3.0f%%", duration < 60 and duration .. "m" or (duration / 60) .. "h",
       100 * timePower / left, 100 * power / left, 100 * triple / left))
      table.insert(offlineRows, string.format("%d,%d,%s,%s,%d,%.0f,%.0f,%.0f,%.0f,%.3f,%.3f,%.3f,%.2f,%.2f", run.rebirths, logoutLevel, run.ball,
       ground.id, duration, left, timePower, power, triple, timePower / left, power / left, triple / left, lastMinutes, runMinutes))
     end
     say("  Rebirth %2d, out at Level %3d (%s, %s): run left %s = %.1f min of Training", run.rebirths, logoutLevel,
      Equipment.Get("Ball", run.ball).displayName, ground.displayName, short(remaining), runMinutes)
     say("    %s  (8 h grants %.1f min of Training)", table.concat(parts, " | "), lastMinutes)
    end
   end
  end
  say("  (A normal return never reaches the Level Cap, and repeated returns take that share of what is")
  say("  left each time. The 3x can finish the run, never pass it: the Rebirth resets banked Power.)")
  csv["offline.csv"] = table.concat(offlineRows, "\n")

  -- Casual returning player.
  say("")
  local sessionMinutes = options.casualMinutes or 30
  say("CASUAL RETURNING (one %d-minute active session a day, Offline Training between)", sessionMinutes)
  local casual = copy(afterTutorial)
  local casualRows = {"day,rebirths,level,world,ball,bat,play_minutes"}
  for _, row in runCasual(casual, options.casualDays or 14, sessionMinutes) do
   say("  Day %2d: Rebirth %2d, Level %3d, %-8s %-18s %s", row.day, row.rebirths, row.level, row.world,
    Equipment.Get("Ball", row.ball).displayName, Equipment.Get("Bat", row.bat).displayName)
   table.insert(casualRows, string.format("%d,%d,%d,%s,%s,%s,%d", row.day, row.rebirths, row.level, row.world, row.ball, row.bat, row.day * sessionMinutes))
  end
  local casualWorlds = {}
  for _, world in Worlds.Worlds do
   local reached = casual.worldTimes[world.id]
   if reached then table.insert(casualWorlds, string.format("%s after %s of play", world.title, clock(reached.time))) end
  end
  say("  Completed: %s", #casualWorlds > 0 and table.concat(casualWorlds, "; ") or "no World yet")
  csv["casual.csv"] = table.concat(casualRows, "\n")

  -- Requirement bands.
  say("")
  say("LEVEL BANDS (first Level's requirement, breakpoint vs the Level before, Power for the band)")
  local previousLast
  for k = 0, (options.bandRows or 20) do
   local first = k == 0 and 1 or P.LevelsPerRebirth * k
   local last = P.LevelsPerRebirth * (k + 1) - 1
   local total = 0
   for level = first, last do total += P.PowerRequiredForNextLevel(level) end
   local start = P.PowerRequiredForNextLevel(first)
   say("  Levels %3d-%3d  start %9s  %-8s  band total %9s", first, last, short(start),
    previousLast and string.format("x%.1f", start / previousLast) or "", short(total))
   previousLast = P.PowerRequiredForNextLevel(last)
  end

  -- Level table.
  local levelRows = {"level,requirement,run_cumulative,training_base,launch_speed,distance,hit_seconds,cash_world1_wood"}
  local cumulative = 0
  for level = 1, options.levelRows or 420 do
   local required = P.PowerRequiredForNextLevel(level)
   if level % P.LevelsPerRebirth == 0 then cumulative = 0 end
   cumulative += required
   local speed = P.GetLaunchSpeed(level)
   local distance, seconds = hitAt(speed)
   local world = Worlds.Worlds[1]
   local landed = math.min(distance, world.endDistance)
   local cash = P.GetHitCash(landed, 1, Field.GetSection(landed, world).rewardMultiplier, 1)
   table.insert(levelRows, string.format("%d,%d,%d,%d,%.1f,%.0f,%.2f,%d", level, required, cumulative, P.GetTrainingBase(level), speed, distance, seconds, cash))
  end
  csv["levels.csv"] = table.concat(levelRows, "\n")

  -- Pacing options (bands solved per pace).
  if options.paceOptions then
   say("")
   say("PACING OPTIONS (bands re-solved per pace; active player; World endpoints from the speed table)")
   for _, pace in {"FAST", "MEDIUM", "LONG"} do
    local starts = solveBands(paces[pace], options.bands or 20)
    setBands(starts)
    local probe = tutorial()
    local guard2 = 0
    while probe.rebirths < (options.bands or 20) and guard2 < 200 do guard2 += 1 runActive(probe) end
    local function at(id) local reached = probe.worldTimes[id] return reached and clock(reached.time) or "-" end
    say("  %-6s World 2 unlock %8s | World 3 unlock %8s | finale %8s | Rebirth 20 at %s", pace, at("world_1"), at("world_2"), at("world_3"), clock(probe.time))
   end
   P.LevelBands = originalBands
  end
 end

 local warningList = {}
 for message in warnings do table.insert(warningList, message) end
 table.sort(warningList)
 if #warningList > 0 then
  say("")
  say("WARNINGS")
  for _, message in warningList do say("  %s", message) end
 end
 result.report = table.concat(out, "\n")
 result.csv = csv
 return result
end
