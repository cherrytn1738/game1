-- Progression balance: Level requirements, Level Caps, Training and batting Power, launch speed
-- and Cash per hit. The numbers are tuned with tools/balance (see .vscode/ECONOMY.md). Power is
-- progress toward the next Level, not launch power; Level alone sets launch strength.
local Progression = {
 StartingPower = 0,
 StartingLevel = 1,
 StartingRebirths = 0,
 -- Level Cap = BaseLevelCap + LevelsPerRebirth x Rebirths: 20, 40, 60, ... The first Rebirth
 -- (Level 20) ends the tutorial; each Rebirth opens one more 20-Level band.
 BaseLevelCap = 20,
 LevelsPerRebirth = 20,
 -- Power to go from a Level to the next, in bands. Each band starts at fromLevel (a breakpoint)
 -- and rises smoothly to the next band: by `add` per Level (linear) or x`growth` per Level.
 -- Band 1 is the tutorial (10, 19, 28, ...). Bands from Level 20 match the Level Caps, so each
 -- Rebirth's new 20 Levels are one band, sized so Rebirth k's run takes about 3 + 2 x (k - 1)
 -- minutes for an active player (the MEDIUM pace, solved with tools/balance).
 LevelBands = {
  {fromLevel = 1, start = 10, add = 9},
  {fromLevel = 20, start = 580, growth = 1.02},
  {fromLevel = 40, start = 12_000, growth = 1.02},
  {fromLevel = 60, start = 67_000, growth = 1.02},
  {fromLevel = 80, start = 380_000, growth = 1.02},
  {fromLevel = 100, start = 2_900_000, growth = 1.02},
  {fromLevel = 120, start = 14_000_000, growth = 1.02},
  {fromLevel = 140, start = 98_000_000, growth = 1.02},
  {fromLevel = 160, start = 390_000_000, growth = 1.02},
  {fromLevel = 180, start = 1_900_000_000, growth = 1.02},
  {fromLevel = 200, start = 4_600_000_000, growth = 1.02},
  {fromLevel = 220, start = 14_000_000_000, growth = 1.02},
  {fromLevel = 240, start = 42_000_000_000, growth = 1.02},
  {fromLevel = 260, start = 150_000_000_000, growth = 1.02},
  {fromLevel = 280, start = 380_000_000_000, growth = 1.02},
  {fromLevel = 300, start = 880_000_000_000, growth = 1.02},
  {fromLevel = 320, start = 1_600_000_000_000, growth = 1.02},
  {fromLevel = 340, start = 3_700_000_000_000, growth = 1.02},
  {fromLevel = 360, start = 6_700_000_000_000, growth = 1.02},
  {fromLevel = 380, start = 12_000_000_000_000, growth = 1.02},
  {fromLevel = 400, start = 22_000_000_000_000, growth = 1.02},
 },
 -- Bands past the last listed one: 20 Levels each, starting this many times above the band before.
 LevelBandTailGrowth = 1.8,
 -- Training: base Power per practice hit at Basic Training, before the Ground, Ball, Rebirth and
 -- Juice multipliers. TrainingBase at Level 1, plus TrainingBasePerLevel per Level up to
 -- TrainingBaseMaxLevel (rounded down): 5, 6, 8, 9, ... 33 from Level 20. The early growth lets the
 -- tutorial take ~6 hits for 30 Power yet reach Level 20 in about a minute.
 TrainingBase = 5,
 TrainingBasePerLevel = 1.5,
 TrainingBaseMaxLevel = 20,
 -- Real hits: Power for each second the ball is in play, as a share of the Training base at the
 -- hit's Level (before Ball, Rebirth and Juice), rounded. Counting the time between hits, batting
 -- earns about 50-70% of Basic Training's Power (Training gives half the base per second) and
 -- never uses the Ground, so Training is always the best Power source.
 HitPowerPerSecond = 0.37,
 -- Launch speed by Level, built from measured hits (tools/balance/HitMeasurements). Levels 1-140:
 -- linear between these {Level, speed} points; distance rises ~2.8% a Level, from ~81 studs at
 -- Level 1 to 3,906 at 140.
 LaunchSpeedTable = {{1, 55}, {11, 64.6}, {21, 78}, {31, 97.3}, {41, 119.1}, {51, 135.8}, {61, 157.8},
  {71, 178.1}, {81, 211.8}, {91, 284.7}, {101, 338.3}, {111, 393.3}, {121, 437.8}, {131, 475.9},
  {140, 505}},
 -- From Level 141: {Level, speed} steps, each speed used from its Level until the next. Above
 -- about 505 studs/s the landing bounces make distance jump from one speed to the next (649 lands
 -- at 7,000, 650 at 5,959), so each step is a speed measured twice to land in its range, and the
 -- distances rise step by step (not the speeds). World 1's end (5,000) is reached from Level 150,
 -- World 2's (6,000) from 250 and World 3's (7,000) from 370, matching the Training Ground Rebirth
 -- gates (Rebirths 7, 12 and 18 reach those Levels). Re-solve with tools/balance after any
 -- physics change.
 LaunchSpeedSteps = {{141, 660}, {144, 693}, {147, 655}, -- ~4,050 / 4,450 / 4,770 studs
  {150, 690}, {160, 677}, {170, 686}, {180, 669}, {190, 652}, {200, 695}, {210, 704}, {220, 680},
  {230, 648}, {240, 687}, -- ~5,100 rising to 5,820 studs
  {250, 665}, {263, 667}, {276, 705}, {290, 714}, {303, 719}, {316, 679}, {330, 702}, {343, 685},
  {356, 699}, -- ~6,140 rising to 6,820 studs
  {370, 716}}, -- reaches World 3's end (and every earlier World's)
 LaunchAngleDegrees = 38,
 -- Cash per hit = World cashMultiplier x (distance / CashReferenceDistance)^CashDistanceExponent
 -- x section rewardMultiplier x Bat cashMultiplier x Cash Juice, rounded, at least 1.
 CashReferenceDistance = 80,
 CashDistanceExponent = 1.5,
 -- Technical validation limits, not progression rewards or client inputs.
 MaxRebirths = 1000,
 MaxPower = 9000000000000000, -- below 2^53, so Power stays an exact integer (saves are exact too)
 MaxBaseGrant = 1000000000,
}

function Progression.IsInteger(value, minimum, maximum)
 return type(value) == "number" and value == value and value >= minimum
  and value <= maximum and value % 1 == 0
end

function Progression.GetLevelCap(rebirths)
 return Progression.BaseLevelCap + Progression.LevelsPerRebirth * rebirths
end

-- The band a Level falls in: a listed band, or a tail band past the last one.
local function bandFor(level)
 local bands = Progression.LevelBands
 local last = bands[#bands]
 local tailFrom = last.fromLevel + Progression.LevelsPerRebirth
 if level < tailFrom then
  for index = #bands, 1, -1 do
   if level >= bands[index].fromLevel then return bands[index] end
  end
  return bands[1]
 end
 local steps = math.floor((level - tailFrom) / Progression.LevelsPerRebirth) + 1
 return {fromLevel = tailFrom + (steps - 1) * Progression.LevelsPerRebirth,
  start = last.start * Progression.LevelBandTailGrowth ^ steps, growth = last.growth, add = last.add}
end

function Progression.PowerRequiredForNextLevel(level)
 local band = bandFor(level)
 local offset = level - band.fromLevel
 local required = band.add and band.start + band.add * offset or band.start * band.growth ^ offset
 return math.min(Progression.MaxPower, math.floor(required))
end

function Progression.GetPowerMultiplier(rebirths)
 return rebirths + 1
end

-- Integer Power is rounded once after every bonus; shared with rate previews.
-- baseAmount already includes any Training Ground multiplier; ballMultiplier is the equipped
-- Ball's powerGainMultiplier; boostMultiplier is the active Juice Power bonus (1 when none or
-- not applicable).
function Progression.GetPowerGrant(baseAmount, rebirths, ballMultiplier, boostMultiplier)
 return math.floor(baseAmount * ballMultiplier * Progression.GetPowerMultiplier(rebirths) * (boostMultiplier or 1))
end

-- Training base Power per practice hit at this Level (Basic Training, before multipliers).
function Progression.GetTrainingBase(level)
 local levels = math.min(level, Progression.TrainingBaseMaxLevel) - Progression.StartingLevel
 return math.floor(Progression.TrainingBase + Progression.TrainingBasePerLevel * math.max(0, levels))
end

-- A real hit's base Power: HitPowerPerSecond of the Training base for each second in play.
function Progression.GetHitPowerBase(level, seconds)
 return math.floor(Progression.GetTrainingBase(level) * Progression.HitPowerPerSecond * math.max(0, seconds) + 0.5)
end

function Progression.GetLaunchSpeed(level)
 local steps = Progression.LaunchSpeedSteps
 if steps and level >= steps[1][1] then
  local speed = steps[1][2]
  for _, step in steps do
   if level < step[1] then break end
   speed = step[2]
  end
  return speed
 end
 local points = Progression.LaunchSpeedTable
 if level <= points[1][1] then return points[1][2] end
 for index = 2, #points do
  local low, high = points[index - 1], points[index]
  if level <= high[1] then
   return low[2] + (high[2] - low[2]) * (level - low[1]) / (high[1] - low[1])
  end
 end
 return points[#points][2]
end

-- Cash for a hit that landed `distance` studs out (see the formula above).
function Progression.GetHitCash(distance, worldMultiplier, sectionMultiplier, batMultiplier, boostMultiplier)
 local scaled = (math.max(0, distance) / Progression.CashReferenceDistance) ^ Progression.CashDistanceExponent
 return math.max(1, math.floor(scaled * worldMultiplier * sectionMultiplier * batMultiplier * (boostMultiplier or 1) + 0.5))
end

-- Shared pure arithmetic; only PlayerData may grant authoritative Power.
-- Requirements are consumed and multiple levels can advance. At the Level Cap, Level stops but
-- Power keeps building (up to MaxPower) until the player Rebirths.
function Progression.Advance(state, amount)
 state.Power = math.min(Progression.MaxPower, state.Power + amount)
 while state.Level < state.LevelCap do
  local required = Progression.PowerRequiredForNextLevel(state.Level)
  if state.Power < required then break end
  state.Power -= required
  state.Level += 1
 end
end

-- Power still needed to reach the Level Cap from this state: the rest of the current run (0 at
-- the cap). Offline Training is held to a share of it (TrainingConfig.OfflineRunShare).
function Progression.GetPowerToLevelCap(state)
 local needed = 0
 for level = state.Level, state.LevelCap - 1 do
  needed += Progression.PowerRequiredForNextLevel(level)
 end
 return math.max(0, needed - state.Power)
end

-- Legacy saves receive defaults. Invalid new fields are repaired independently;
-- an arbitrary saved LevelCap never grants additional levels.
function Progression.Normalize(saved, legacy)
 saved = legacy and {} or saved
 local rebirths = Progression.IsInteger(saved.Rebirths, 0, Progression.MaxRebirths)
  and saved.Rebirths or Progression.StartingRebirths
 local cap = Progression.GetLevelCap(rebirths)
 local level = Progression.IsInteger(saved.Level, Progression.StartingLevel,
  Progression.GetLevelCap(Progression.MaxRebirths)) and math.min(saved.Level, cap) or Progression.StartingLevel
 local power = Progression.IsInteger(saved.Power, 0, Progression.MaxPower) and saved.Power or Progression.StartingPower
 local state = {Power = power, Level = level, Rebirths = rebirths, LevelCap = cap}
 Progression.Advance(state, 0)
 return state
end

return Progression
