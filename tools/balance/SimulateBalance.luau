-- Balance simulator. Loads the game's real config modules (ProgressionConfig, EquipmentConfig,
-- TrainingConfig, WorldConfig, FieldConfig, TutorialConfig, JuiceConfig, MonetizationConfig) from
-- their sources, plus measured hits (HitMeasurements), and plays model players through the
-- progression:
--   tutorial        the four tutorial steps, with measured walking/clicking times
--   trainingOnly    after the tutorial, only Trains at the best free ground; Rebirths at the cap
--   active          Trains, bats in blocks, buys upgrades as Cash allows; Rebirths at the cap
--   spenders        the active player with purchased multiplier tiers, juices and paid grounds
--   offline         Offline Training rewards at progression snapshots
--   casual          one active session a day, Offline Training between
-- It can also design tuning: the Level -> launch speed table (designSpeedTable, or a distance
-- curve with distanceShape), the tutorial band (solveTutorial) and the Level requirement bands
-- for a pacing (solveBands). See tools/balance/README.md.
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
 local Juice = load("JuiceConfig")
 local Monetization = load("MonetizationConfig")
 local Measured = load("HitMeasurements")
 local Playtime = sources.PlaytimeRewardConfig and load("PlaytimeRewardConfig")
 -- What-if prices: {{category, id, price}, ...} (this run's copy of the config only).
 for _, override in options.prices or {} do Equipment.Get(override[1], override[2]).price = override[3] end
 -- What-if tutorial band: {start, add} for Levels 1-19.
 if options.tutorialBand then
  P.LevelBands[1] = {fromLevel = 1, start = options.tutorialBand.start, add = options.tutorialBand.add}
 end

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
  claim = 2, -- opening Playtime Rewards and claiming one
 }

 -- Hit physics from measurements ------------------------------------------------------------
 local usable = {}
 for _, point in Measured.points do table.insert(usable, point) end
 table.sort(usable, function(a, b) return a.speed < b.speed end)
 local gap = Measured.erraticFrom and {from = Measured.erraticFrom, to = math.huge}
 local warnings = {}
 -- Speeds in the erratic range were measured one at a time: each trial is {distance, seconds}.
 -- The sweep below 505 (one speed at a time, too) is looked up exactly the same way.
 local erratic = {}
 local measuredSpeeds = {}
 for speed, trials in Measured.sweep or {} do measuredSpeeds[speed] = trials end
 for speed, trials in Measured.erratic or {} do measuredSpeeds[speed] = trials end
 -- Speeds measured in the longest field (World 4, to 8,000 studs): where an earlier field cut a hit
 -- short at its own end (7,000), these trials replace that speed's; otherwise they join them.
 for speed, trials in Measured.far or {} do
  local earlier = measuredSpeeds[speed]
  local capped = false
  for _, trial in earlier or {} do capped = capped or trial[1] >= 7000 end
  if not earlier or capped then
   measuredSpeeds[speed] = trials
  else
   local merged = table.clone(earlier)
   for _, trial in trials do table.insert(merged, trial) end
   measuredSpeeds[speed] = merged
  end
 end
 for speed, trials in measuredSpeeds do
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

 -- A distance curve for Levels 21-140 (Levels 1-21 and the steps from 141 stay as configured):
 -- shape = {r21, r140, floorFrom}. Each Level adds a share of distance that falls linearly from
 -- r21 at Level 21 to r140 at Level 140; with floorFrom, it falls to a floor at that Level and
 -- stays there to 140 (the floor is solved so 140 lands where the last smooth measurement does,
 -- and r140 is then ignored). Builds a LaunchSpeedTable point every `step` Levels (5) and returns
 -- it with the ExpectedHitDistances head to paste into ProgressionConfig.
 local function designDistanceShape(shape, step)
  local fixed = P.LaunchSpeedTable
  local startLevel, endLevel = 21, 140
  local r1, r2, floorLevel = shape[1], shape[2], shape[3]
  local d0 = (hitAt(fixed[3][2]))
  local last = usable[#usable]
  local span = endLevel - startLevel
  local floorAt = floorLevel and floorLevel - startLevel or span
  if floorLevel then r2 = (math.log(last.distance / d0) - floorAt * r1 / 2) / (floorAt / 2 + span - floorAt) end
  local function rawAt(x)
   if x <= floorAt then return r1 * x + (r2 - r1) * x * x / (2 * floorAt) end
   return r1 * floorAt + (r2 - r1) * floorAt / 2 + r2 * (x - floorAt)
  end
  local total = rawAt(span)
  local function distanceAt(level)
   return d0 * math.exp(math.log(last.distance / d0) * rawAt(level - startLevel) / total)
  end
  local table_ = {fixed[1], fixed[2], fixed[3]}
  for level = startLevel + step, endLevel - 1, step do
   local speed = assert(speedFor(distanceAt(level)), "no measured speed lands " .. distanceAt(level) .. " studs")
   table.insert(table_, {level, math.floor(speed * 10 + 0.5) / 10})
  end
  table.insert(table_, {endLevel, last.speed})
  return table_, floorLevel and r2 or nil, distanceAt
 end

 -- Measured steps for Levels 22-140: below 505 distance is erratic in speed too (Studio,
 -- 2026-11-04: nearby speeds land far apart, and below ~200 studs/s the same speed varies from
 -- hit to hit), so instead of interpolating, each Level gets a speed from the sweep
 -- (HitMeasurements.sweep) whose average distance lands near the curve's distance for that
 -- Level and beyond the Level before (distance always rises). In order of preference: a speed
 -- hit at least twice whose trials agree within `repeatTolerance`, within `tolerance` of the
 -- curve; any speed hit twice within `tolerance`; a speed hit once within `tolerance`; then the
 -- same with `wideTolerance`. A Level with no candidate repeats the Level before. Level 140 keeps
 -- the last smooth measurement (505). Returns the steps (to prepend to LaunchSpeedSteps) and the
 -- chosen distances.
 local function designMeasuredSteps(distanceAt, tolerance, repeatTolerance, wideTolerance)
  local candidates = {}
  for speed, trials in Measured.sweep or {} do
   local sum, time, low, high = 0, 0, math.huge, -math.huge
   for _, trial in trials do
    sum, time = sum + trial[1], time + trial[2]
    low, high = math.min(low, trial[1]), math.max(high, trial[1])
   end
   local distance = sum / #trials
   table.insert(candidates, {speed = speed, distance = distance, seconds = time / #trials, trials = #trials,
    spread = (high - low) / distance})
  end
  local steps, distances = {}, {}
  local previous = (hitAt(P.LaunchSpeedTable[3][2]))
  for level = 22, 139 do
   local target = distanceAt(level)
   local best
   for _, rule in {{tolerance, 2, repeatTolerance}, {tolerance, 2, math.huge}, {tolerance, 1, math.huge},
    {wideTolerance, 2, repeatTolerance}, {wideTolerance, 2, math.huge}, {wideTolerance, 1, math.huge}} do
    local bestOff
    for _, candidate in candidates do
     local off = math.abs(math.log(candidate.distance / target))
     if candidate.distance > previous and off <= rule[1] and candidate.trials >= rule[2] and candidate.spread <= rule[3]
      and (not bestOff or off < bestOff) then
      best, bestOff = candidate, off
     end
    end
    if best then break end
   end
   if best then
    table.insert(steps, {level, best.speed})
    distances[level] = best.distance
    previous = best.distance
   else
    table.insert(steps, {level, steps[#steps] and steps[#steps][2] or P.LaunchSpeedTable[3][2]})
    distances[level] = previous
   end
  end
  local last = usable[#usable]
  table.insert(steps, {140, last.speed})
  distances[140] = last.distance
  return steps, distances
 end

 -- Player state ------------------------------------------------------------------------------
 local function ballMultiplier(s) return Equipment.Get("Ball", s.ball).powerGainMultiplier end
 local function batMultiplier(s) return Equipment.Get("Bat", s.bat).cashMultiplier end
 local function newState()
  return {time = 0, level = 1, power = 0, rebirths = 0, cash = 0, ball = "baseball", bat = "wood_bat",
   ownedBalls = {baseball = true}, ownedBats = {wood_bat = true}, world = Worlds.StartingWorldId,
   unlocked = {[Worlds.StartingWorldId] = true}, completed = {}, hits = 0, contacts = 0,
   runStart = 0, runs = {}, purchases = {}, worldTimes = {}, hitsSincePurchase = 0,
   trainingPower = 0, battingPower = 0, earned = 0,
   -- Spenders (applyScenario): purchased multipliers, juices (online only) and owned passes.
   powerBoost = 1, cashBoost = 1, juicePower = 1, juiceCash = 1, passes = {}}
 end
 local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, inner in value do result[key] = copy(inner) end
  return result
 end
 -- Where a hit at this Level lands in this World (ProgressionConfig.GetWorldLaunchLevel: hits
 -- start over in each later World), and its Cash there (with the World's start pay).
 local function worldHit(level, worldId)
  local world = Worlds.Get(worldId)
  return world, hitAt(P.GetLaunchSpeed(P.GetWorldLaunchLevel(level, world)))
 end
 local function hitCash(landed, world, sectionMultiplier, bat, boost)
  return P.GetHitCash(landed, world.cashMultiplier, sectionMultiplier, bat, boost, world.cashBase)
 end
 -- designWorldLaunch = true: builds WorldLaunchSteps for every World with launchLevels (used for
 -- the rest of this run, and printed to paste into ProgressionConfig). From launchLevels.from to
 -- .to the target distance rises evenly in studs from the early arc's end (EarlyLaunch.untilLevel)
 -- to the World's end; each Level takes the highest global Level whose measured distance does not
 -- pass the target (so the end is reached only at .to), and .to the first Level that reaches it.
 if options.designWorldLaunch then
  local reach, best = {}, 0
  for level = 1, 700 do
   best = math.max(best, (hitAt(P.GetLaunchSpeed(level))))
   reach[level] = best
  end
  local early = P.EarlyLaunch.untilLevel
  P.WorldLaunchSteps = {}
  for _, world in Worlds.Worlds do
   local range = world.launchLevels
   if range then
    local steps, last = {}, nil
    for level = range.from, range.to do
     local launch
     if level >= range.to then
      launch = 700
      for g = early, 700 do if reach[g] >= world.endDistance then launch = g break end end
     else
      local target = reach[early] + (world.endDistance - reach[early]) * (level - range.from) / (range.to - range.from)
      target = math.min(target, world.endDistance - 1)
      launch = early
      for g = early, 700 do if reach[g] <= target then launch = g else break end end
     end
     if launch ~= last then table.insert(steps, {level, launch}) last = launch end
    end
    P.WorldLaunchSteps[world.id] = steps
    local parts = {}
    for _, step in steps do table.insert(parts, string.format("{%d, %d}", step[1], step[2])) end
    say("WorldLaunchSteps.%s = {%s}", world.id, table.concat(parts, ", "))
   end
  end
  say("")
 end
 -- The set of Worlds up to and including worldId (in order), as unlocked Worlds.
 local function worldsThrough(worldId)
  local set = {}
  for _, world in Worlds.Worlds do
   set[world.id] = true
   if world.id == worldId then break end
  end
  return set
 end
 -- The furthest World a hit at this Level has unlocked (each World's end opens the next).
 local function worldForLevel(level)
  local id = Worlds.StartingWorldId
  for _, world in Worlds.Worlds do
   if world.id == id and world.nextWorldId and select(2, worldHit(level, world.id)) >= world.endDistance then id = world.nextWorldId end
  end
  return id
 end
 -- "World 2 <time> | World 3 <time> | ...": when each World after the first opened (at(id) gives
 -- the time the World before it was completed).
 local function unlockTimes(at)
  local parts = {}
  for index = 2, #Worlds.Worlds do
   table.insert(parts, string.format("World %d %8s", index, at(Worlds.Worlds[index - 1].id)))
  end
  return table.concat(parts, " | ")
 end
 local function cap(s) return P.GetLevelCap(s.rebirths) end
 local function advance(s, amount)
  local state = {Power = s.power, Level = s.level, LevelCap = cap(s)}
  P.Advance(state, amount)
  s.power, s.level = state.Power, state.Level
 end
 -- The best ground only changes with Rebirths, World unlocks and passes, so it is cached, with
 -- the World it is best in and its multiplier there (Dragon's Lair's depends on the World).
 local function bestGround(s)
  local key = tostring(s.rebirths)
  for _, world in Worlds.Worlds do key ..= s.unlocked[world.id] and "+" or "-" end
  key ..= next(s.passes) and "p" or ""
  if s.groundKey ~= key then
   local ground, worldId = Training.GetBestGround(s.rebirths, s.passes, s.unlocked)
   s.groundKey, s.groundId, s.groundWorld = key, ground.id, worldId
   s.groundMultiplier = Training.GetMultiplier(ground, worldId)
  end
  return Training.Get(s.groundId)
 end
 local function trainContact(s)
  local ground = bestGround(s)
  local grant = P.GetPowerGrant(P.TrainingBase * s.groundMultiplier, s.rebirths, ballMultiplier(s), s.powerBoost * s.juicePower)
  s.time += A.contact
  s.contacts += 1
  s.trainingPower += grant
  advance(s, grant)
  return grant
 end
 local function landing(s)
  return worldHit(s.level, s.world)
 end
 local function hit(s)
  local world, distance, seconds = landing(s)
  local landed = math.min(distance, world.endDistance)
  local section = Field.GetSection(landed, world)
  local cash = hitCash(landed, world, section.rewardMultiplier, batMultiplier(s), s.cashBoost * s.juiceCash)
  local power = P.GetPowerGrant(P.GetHitPowerBase(seconds - A.launchDelay), s.rebirths, ballMultiplier(s), s.powerBoost * s.juicePower)
  s.cash += cash
  s.earned += cash
  s.battingPower += power
  advance(s, power)
  s.time += seconds + A.cycleOverhead
  s.hits += 1
  s.hitsSincePurchase += 1
  if distance >= world.endDistance and not s.completed[world.id] then
   s.completed[world.id] = true
   s.worldTimes[world.id] = {time = s.time, rebirths = s.rebirths, level = s.level, day = s.day}
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
  local world, distance = worldHit(s.level, s.world)
  local landed = math.min(distance, world.endDistance)
  return hitCash(landed, world, Field.GetSection(landed, world).rewardMultiplier, batMultiplier(s), s.cashBoost * s.juiceCash)
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
   ball = s.ball, bat = s.bat, ground = bestGround(s).id, groundMultiplier = s.groundMultiplier, world = s.world, cash = s.cash})
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
  local trainingFrom = s.time
  while s.level < cap(s) do trainContact(s) end
  steps.ReachLevel = s.time - before
  steps.Training = s.time - trainingFrom -- the practice hits alone
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
 -- Playtime Rewards (scenario.playtime): the player claims every reward as soon as it is ready,
 -- in one long session from the start of the game (the board starts again after the 12th), with
 -- the server's amounts: Cash worth its hits (the Cash Pack quote), Power worth its seconds of
 -- Training at the best ground in the current World, and juices drunk at once (each 2x for its
 -- duration, added to any running one).
 local function claimPlaytime(s)
  local board = s.playtime
  if not board then return end
  while s.time - board.cycleStart >= Playtime.UnlockSeconds(board.next) do
   local reward = Playtime.Rewards[board.next]
   if reward.cashHits then
    local cash = Monetization.GetCashPackReward({hits = reward.cashHits}, s.level, s.world, s.bat, s.cashBoost)
    s.cash += cash
    s.earned += cash
    board.cash += cash
   end
   if reward.trainingSeconds then
    local ground, worldId = Training.GetBestGround(s.rebirths, s.passes, {[s.world] = true})
    local perHit = P.GetPowerGrant(P.TrainingBase * Training.GetMultiplier(ground, worldId), s.rebirths, ballMultiplier(s), s.powerBoost)
    local power = math.floor(perHit / ground.interval * reward.trainingSeconds)
    advance(s, power)
    board.power += power
   end
   for id, count in reward.juices or {} do
    local juice = Juice.Get(id)
    local key = juice.effect == "Power" and "powerJuiceUntil" or "cashJuiceUntil"
    s[key] = math.max(s[key], s.time) + juice.durationSeconds * count
   end
   s.time += A.claim
   board.claims += 1
   board.next += 1
   if board.next > #Playtime.Rewards then board.next, board.cycleStart = 1, s.time end
  end
  -- Drunk reward juices run on real time.
  s.juicePower = s.time < s.powerJuiceUntil and Juice.Get("power_punch").multiplier or 1
  s.juiceCash = s.time < s.cashJuiceUntil and Juice.Get("cash_splash").multiplier or 1
 end
 local function runActive(s, timeLimit)
  local start = s.time
  local limit = start + (timeLimit or math.huge)
  while s.time < limit do
   claimPlaytime(s)
   local blockEnd = s.time + A.trainBlock
   s.time += A.firstContact - A.contact
   while s.time < blockEnd and s.level < cap(s) do trainContact(s) end
   if s.level >= cap(s) then rebirth(s) return s.time - start end
   s.time += A.walk
   local batEnd = s.time + A.batBlock
   claimPlaytime(s)
   repeat hit(s) shop(s) until s.time >= batEnd
   s.time += A.walk
  end
  return s.time - start
 end
 -- Offline Power for a return, as the server grants it: the time-based reward, held to the run
 -- cap (a share of the Power left to the Level Cap). Returns that, the time-based reward, and
 -- the Power left before the return.
 local function offlinePower(s, seconds)
  local base = Training.GetOfflineReward(1, 1 + seconds, bestGround(s).id, P.TrainingBase, s.groundWorld)
  -- The purchased Power multiplier applies offline; juices never do.
  local timed = P.GetPowerGrant(base, s.rebirths, ballMultiplier(s), s.powerBoost)
  local remaining = P.GetPowerToLevelCap({Level = s.level, Power = s.power, LevelCap = cap(s)})
  return math.min(timed, Training.GetOfflinePowerLimit(remaining)), timed, remaining
 end
 -- Casual returning player: one active session a day; Offline Training (granted once on
 -- return, from the time away, under the run cap) covers the rest. s.time counts play time only.
 -- Stops after the day the last World is completed (the finale).
 local finaleWorld = Worlds.Worlds[#Worlds.Worlds].id
 local function runCasual(s, days, sessionMinutes)
  local rows = {}
  local away = 24 * 3600 - sessionMinutes * 60
  for day = 1, days do
   s.day = day
   if day > 1 then
    local grant = offlinePower(s, away)
    s.offlinePower = (s.offlinePower or 0) + grant
    advance(s, grant)
   end
   local sessionEnd = s.time + sessionMinutes * 60
   while s.time < sessionEnd and not s.completed[finaleWorld] do runActive(s, sessionEnd - s.time) end
   table.insert(rows, {day = day, rebirths = s.rebirths, level = s.level, world = s.world, ball = s.ball, bat = s.bat})
   if s.completed[finaleWorld] then break end
   if task and task.wait and day % 2 == 0 then task.wait() end
  end
  return rows
 end

 -- Spenders: a scenario sets the purchased multiplier tiers (MonetizationConfig.Multipliers),
 -- juices running all the time (juices = true), the paid grounds' passes (passes = true for both,
 -- or a list of pass ground ids, e.g. {"dragons_lair"}) and the Starter Pack (starterPack = true,
 -- given right after the tutorial) and Playtime Rewards (playtime = true: every reward claimed when ready).
 local function applyScenario(s, scenario)
  s.powerBoost = Monetization.GetMultiplier("Power", scenario.powerTiers or 0)
  s.cashBoost = Monetization.GetMultiplier("Cash", scenario.cashTiers or 0)
  s.juicePower = scenario.juices and Juice.Get("power_punch").multiplier or 1
  s.juiceCash = scenario.juices and Juice.Get("cash_splash").multiplier or 1
  if scenario.passes then
   -- (This run's config copy only: a pass with no id can't be used.)
   for _, ground in Training.PassGrounds do
    if scenario.passes == true or table.find(scenario.passes, ground.id) then
     ground.gamePassId = math.max(ground.gamePassId, 1)
     s.passes[ground.id] = true
    end
   end
   s.groundKey = nil
  end
  if scenario.playtime then
   -- The session started when the player joined (time 0), so the first rewards are ready once
   -- the tutorial is done.
   assert(Playtime, "playtime needs PlaytimeRewardConfig in sources")
   s.playtime = {next = 1, cycleStart = 0, claims = 0, cash = 0, power = 0}
   s.powerJuiceUntil, s.cashJuiceUntil = 0, 0
  end
  if scenario.starterPack then
   local pack = Monetization.StarterPack
   s.rebirths += pack.rebirths
   s.groundKey = nil
   s.ownedBats[pack.batId] = true
   equipBest(s)
   advance(s, pack.power)
  end
 end
 -- Robux for a scenario's multiplier tiers.
 local function tierRobux(scenario)
  local total = 0
  for _, kind in Monetization.MultiplierKinds do
   for number = 1, scenario[string.lower(kind) .. "Tiers"] or 0 do total += Monetization.Multipliers[kind][number].robuxPrice end
  end
  return total
 end
 -- Plays an active (or, with casualMinutes, casual) player through to the finale.
 local function playToFinale(start, scenario, casualMinutes)
  local s = copy(start)
  applyScenario(s, scenario)
  if casualMinutes then
   runCasual(s, options.casualDays or 60, casualMinutes)
  else
   local guard = 0
   while not s.completed[finaleWorld] and guard < 3000 do
    guard += 1
    runActive(s, 900)
    if task and task.wait and guard % 4 == 0 then task.wait() end
   end
  end
  return s
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
 -- keepBands = n keeps the configured bands of the first n Rebirths and solves only the ones
 -- after them (e.g. for a new World past the last one).
 local function solveBands(slope, count)
  local starts = {}
  local kept = options.keepBands or 0
  for k = 1, kept do
   for _, band in originalBands do
    if band.fromLevel == P.LevelsPerRebirth * k then starts[k] = band.start end
   end
   assert(starts[k], "keepBands: no configured band at Level " .. P.LevelsPerRebirth * k)
  end
  local s = tutorial()
  for k = 1, count do
   local target = targetMinutes(slope, k) * 60
   local low, high = math.log(1), math.log(P.MaxPower)
   if k <= kept then
    setBands(starts)
    if k == 1 then runTrainingOnly(s) else runActive(s) end
    continue
   end
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
  local first = math.max(2, kept + 1)
  local blocks = {}
  for k = first, #logs do
   table.insert(blocks, {sum = logs[k], count = 1})
   while #blocks > 1 and blocks[#blocks - 1].sum / blocks[#blocks - 1].count > blocks[#blocks].sum / blocks[#blocks].count do
    local top = table.remove(blocks)
    blocks[#blocks].sum += top.sum
    blocks[#blocks].count += top.count
   end
  end
  local k = first
  for _, block in blocks do
   for _ = 1, block.count do logs[k] = block.sum / block.count k += 1 end
  end
  local averaged = table.clone(logs)
  for index = math.max(3, first), #logs - 1 do averaged[index] = (logs[index - 1] + logs[index] + logs[index + 1]) / 3 end
  local minRatio = math.log(options.minBandRatio or 1.8)
  for index = first, #averaged do averaged[index] = math.max(averaged[index], averaged[index - 1] + minRatio) end
  for index, value in averaged do if index >= first then starts[index] = round2(math.exp(value)) end end
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
 -- What-if distance curve (designDistanceShape): used for the rest of this run, and printed to paste.
 if options.distanceShape then
  local table_, floor, distanceAt = designDistanceShape(options.distanceShape, options.distanceStep or 5)
  P.LaunchSpeedTable = table_
  -- measuredSteps = {tolerance, repeatTolerance}: Levels 22-140 from measured sweep speeds instead.
  local chosen
  if options.measuredSteps then
   local steps
   steps, chosen = designMeasuredSteps(distanceAt, options.measuredSteps.tolerance or 0.035,
    options.measuredSteps.repeatTolerance or 0.06, options.measuredSteps.wideTolerance or 0.06)
   P.LaunchSpeedTable = {table_[1], table_[2], table_[3]}
   local merged = table.clone(steps)
   for _, step in P.LaunchSpeedSteps do if step[1] > 140 then table.insert(merged, step) end end
   P.LaunchSpeedSteps = merged
   local parts = {}
   for _, step in steps do table.insert(parts, string.format("{%d, %s}", step[1], tostring(step[2]))) end
   say("LaunchSpeedSteps head (Levels 22-140) = {%s}", table.concat(parts, ", "))
   local misses = {}
   for level = 22, 140 do
    local off = chosen[level] / distanceAt(level) - 1
    if math.abs(off) > (options.measuredSteps.tolerance or 0.035) + 1e-9 then table.insert(misses, string.format("L%d %+.0f%%", level, 100 * off)) end
   end
   say("  Levels off the curve by more than the tolerance: %s", #misses > 0 and table.concat(misses, ", ") or "none")
   result.speedSteps = steps
  end
  local parts = {}
  for _, point in P.LaunchSpeedTable do table.insert(parts, string.format("{%d, %s}", point[1], tostring(point[2]))) end
  say("LaunchSpeedTable = {%s}", table.concat(parts, ", "))
  parts = {}
  for _, level in {1, 21, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140} do
   table.insert(parts, string.format("{%d, %.0f}", level, (hitAt(P.GetLaunchSpeed(level)))))
  end
  say("ExpectedHitDistances head = {%s}", table.concat(parts, ", "))
  if floor then say("  (the curve grows %.2f%% a Level from Level %d to 140)", 100 * floor, options.distanceShape[3]) end
  say("")
  result.speedTable = P.LaunchSpeedTable
 end
 -- Solve the tutorial band's per-Level step so its Level 20 climb takes `target` seconds of
 -- Training (solveTutorial = {start, target}); used for the rest of this run.
 if options.solveTutorial then
  local start, low, high = options.solveTutorial.start or 10, 0, 20
  for _ = 1, 30 do
   local mid = (low + high) / 2
   P.LevelBands[1] = {fromLevel = 1, start = start, add = mid}
   local _, steps = tutorial()
   if steps.Training > options.solveTutorial.target then high = mid else low = mid end
  end
  P.LevelBands[1] = {fromLevel = 1, start = start, add = (low + high) / 2}
  say("Tutorial band: start %d, add %.3f a Level (Level 20 climb %.0f s of Training)", start, (low + high) / 2, options.solveTutorial.target)
  say("")
  result.tutorialAdd = (low + high) / 2
 end
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
  say("  Level 20 + Rebirth%6.1f s   (%.1f s of it Training; target 45-60)", steps.ReachLevel, steps.Training)
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
    run.duration / 60, run.ball, ball.powerGainMultiplier, run.bat, bat.cashMultiplier, run.ground, run.groundMultiplier, run.world))
  end
  csv["runs_active.csv"] = table.concat(runRows, "\n")
  say("  Batting share of Power: %.0f%% (Training %s, batting %s)", 100 * a.battingPower / (a.battingPower + a.trainingPower),
   short(a.trainingPower), short(a.battingPower))

  say("")
  say("WORLDS (active player; the wait from the last purchase before each World's end)")
  for _, world in Worlds.Worlds do
   local reached = a.worldTimes[world.id]
   local lastBuy
   for _, purchase in a.purchases do
    if reached and purchase.time <= reached.time then lastBuy = purchase end
   end
   say("  %-10s end %5d studs: %s%s", world.title, world.endDistance,
    reached and string.format("completed at %s (Rebirth %d, Level %d)", clock(reached.time), reached.rebirths, reached.level) or "not completed",
    reached and lastBuy and string.format(", %s at %s (%s before)", lastBuy.name, clock(lastBuy.time), clock(reached.time - lastBuy.time)) or "")
  end

  -- Where each run's hits land: the run's top 20 Levels (most of its time) in the World it is
  -- played in, from the run's first Level in that band to its last (or the World's end).
  say("")
  say("WORLD DISTANCES (active player: each run's top 20 Levels in its World, Wood Bat Cash, no boosts)")
  for _, run in a.runs do
   local world = Worlds.Get(run.world)
   local low, high = P.LevelsPerRebirth * run.rebirths, P.GetLevelCap(run.rebirths) - 1
   if world.launchLevels then low = math.max(low, math.min(world.launchLevels.from, high)) end
   local function at(level)
    local _, distance = worldHit(level, world.id)
    local landed = math.min(distance, world.endDistance)
    local section = Field.GetSection(landed, world)
    return landed, section.displayName, hitCash(landed, world, section.rewardMultiplier, 1, 1)
   end
   local d1, s1, c1 = at(low)
   local d2, s2, c2 = at(high)
   say("  Run %2d  %-12s Levels %3d-%3d: %5.0f %-22s -> %5.0f %-22s $%s -> $%s", run.rebirths, world.title, low, high,
    d1, s1, d2, s2, short(c1), short(c2))
  end

  -- Spenders.
  say("")
  say("SPENDERS (active player with purchased multipliers; 'faster' is the finale against free to play)")
  local powerTiers, cashTiers = #Monetization.Multipliers.Power, #Monetization.Multipliers.Cash
  local scenarios = options.scenarios or {
   {name = "Free to play"},
   {name = "Light (1 tier each)", powerTiers = 1, cashTiers = 1},
   {name = "Light (2 tiers each)", powerTiers = 2, cashTiers = 2},
   {name = "Heavy (every tier)", powerTiers = powerTiers, cashTiers = cashTiers},
   {name = "Heavy + juices nonstop", powerTiers = powerTiers, cashTiers = cashTiers, juices = true},
   {name = "Whale (+ both paid grounds, Starter Pack)", powerTiers = powerTiers, cashTiers = cashTiers, juices = true,
    passes = true, starterPack = true},
  }
  local freeFinale
  for _, scenario in scenarios do
   local p = playToFinale(afterTutorial, scenario)
   local function at(id) local reached = p.worldTimes[id] return reached and clock(reached.time) or "-" end
   local finale = p.worldTimes[finaleWorld] and p.worldTimes[finaleWorld].time
   freeFinale = freeFinale or finale
   say("  %-42s %s | finale %8s%s | %d Robux of tiers", scenario.name, unlockTimes(at),
    at(finaleWorld), finale and freeFinale and finale < freeFinale and string.format(" (%.0f%% faster)", 100 * (1 - finale / freeFinale)) or "",
    tierRobux(scenario))
  end
  -- Each tier on its own (tierValues = true): its finale and what it saves over the tier before.
  if options.tierValues then
   for _, kind in Monetization.MultiplierKinds do
    local previous = freeFinale
    for number, tier in Monetization.Multipliers[kind] do
     local p = playToFinale(afterTutorial, {[string.lower(kind) .. "Tiers"] = number})
     local finale = p.worldTimes[finaleWorld].time
     say("  %-5s tier %d (%gx, %d Robux) alone: finale %s (saves %s)", kind, number, tier.multiplier, tier.robuxPrice, clock(finale),
      clock(previous - finale))
     previous = finale
    end
   end
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
  for _, level in {1, 3, 20, 40, 80, 140, 150, 250, 370, 430, 490} do
   local probe = newState()
   probe.level = level
   probe.rebirths = math.max(0, math.ceil(level / P.LevelsPerRebirth) - 1)
   probe.world = worldForLevel(level)
   local _, distance, seconds = landing(probe)
   local batting = P.GetHitPowerBase(seconds - A.launchDelay) / (seconds + A.cycleOverhead) * 60
   local basic = P.TrainingBase / A.contact * 60
   local ground, groundWorld = Training.GetBestGround(probe.rebirths, {}, worldsThrough(probe.world))
   local groundMultiplier = Training.GetMultiplier(ground, groundWorld)
   say("  Level %3d  hit %5.0f studs %4.1fs: batting %6.1f vs Basic Training %6.1f (%3.0f%%) vs %s x%d (%4.1f%%)", level,
    distance, seconds, batting, basic, 100 * batting / basic, ground.displayName, groundMultiplier,
    100 * batting / (basic * groundMultiplier))
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
   if ({[1] = true, [3] = true, [6] = true, [9] = true, [12] = true, [15] = true, [18] = true, [21] = true, [24] = true})[run.rebirths] then
    for _, logoutLevel in {P.LevelsPerRebirth * run.rebirths, P.StartingLevel} do
     local probe = newState()
     probe.rebirths, probe.ball, probe.level = run.rebirths, run.ball, logoutLevel
     probe.unlocked = worldsThrough(run.world)
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
  for _, row in runCasual(casual, options.casualDays or 60, sessionMinutes) do
   say("  Day %2d: Rebirth %2d, Level %3d, %-8s %-18s %s", row.day, row.rebirths, row.level, row.world,
    Equipment.Get("Ball", row.ball).displayName, Equipment.Get("Bat", row.bat).displayName)
   table.insert(casualRows, string.format("%d,%d,%d,%s,%s,%s,%d", row.day, row.rebirths, row.level, row.world, row.ball, row.bat, row.day * sessionMinutes))
  end
  local function casualWorlds(p)
   local parts = {}
   for _, world in Worlds.Worlds do
    local reached = p.worldTimes[world.id]
    if reached then table.insert(parts, string.format("%s day %d (%s of play)", world.title, reached.day, clock(reached.time))) end
   end
   return #parts > 0 and table.concat(parts, "; ") or "no World yet"
  end
  say("  Completed: %s", casualWorlds(casual))
  say("  Offline Training gave %.0f%% of the Power", 100 * (casual.offlinePower or 0)
   / math.max(1, (casual.offlinePower or 0) + casual.trainingPower + casual.battingPower))
  csv["casual.csv"] = table.concat(casualRows, "\n")
  -- The same casual player with each spender scenario (casualSpenders = true).
  if options.casualSpenders then
   for index, scenario in scenarios do
    if index > 1 then say("  %-42s %s", scenario.name, casualWorlds(playToFinale(afterTutorial, scenario, sessionMinutes))) end
   end
  end

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
   table.insert(levelRows, string.format("%d,%d,%d,%d,%.1f,%.0f,%.2f,%d", level, required, cumulative, P.TrainingBase, speed, distance, seconds, cash))
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
    say("  %-6s %s | finale %8s | Rebirth %d at %s", pace, unlockTimes(at), at(finaleWorld), options.bands or 20, clock(probe.time))
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
