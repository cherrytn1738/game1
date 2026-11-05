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
 -- Band 1 is the tutorial (10, 11.5, 13, ...: its Level 20 climb takes about 54 s of Training with
 -- the Sandlot Ball). Bands from Level 20 match the Level Caps, so each Rebirth's new 20 Levels
 -- are one band, sized so Rebirth k's run takes about 3 + 4 x (k - 1) minutes for an active
 -- player (the LONG pace, solved with tools/balance).
 LevelBands = {
  {fromLevel = 1, start = 10, add = 1.5},
  {fromLevel = 20, start = 90, growth = 1.02},
  {fromLevel = 40, start = 3_200, growth = 1.02},
  {fromLevel = 60, start = 48_000, growth = 1.02},
  {fromLevel = 80, start = 470_000, growth = 1.02},
  {fromLevel = 100, start = 3_200_000, growth = 1.02},
  {fromLevel = 120, start = 13_000_000, growth = 1.02},
  {fromLevel = 140, start = 64_000_000, growth = 1.02},
  {fromLevel = 160, start = 300_000_000, growth = 1.02},
  {fromLevel = 180, start = 1_400_000_000, growth = 1.02},
  {fromLevel = 200, start = 4_000_000_000, growth = 1.02},
  {fromLevel = 220, start = 9_000_000_000, growth = 1.02},
  {fromLevel = 240, start = 26_000_000_000, growth = 1.02},
  {fromLevel = 260, start = 86_000_000_000, growth = 1.02},
  {fromLevel = 280, start = 310_000_000_000, growth = 1.02},
  {fromLevel = 300, start = 830_000_000_000, growth = 1.02},
  {fromLevel = 320, start = 1_500_000_000_000, growth = 1.02},
  {fromLevel = 340, start = 2_700_000_000_000, growth = 1.02},
  {fromLevel = 360, start = 4_900_000_000_000, growth = 1.02},
  {fromLevel = 380, start = 8_900_000_000_000, growth = 1.02},
  {fromLevel = 400, start = 16_000_000_000_000, growth = 1.02},
 },
 -- Bands past the last listed one: 20 Levels each, starting this many times above the band before.
 LevelBandTailGrowth = 1.8,
 -- Training: base Power per practice hit at Basic Training, before the Ground, Ball, Rebirth and
 -- Juice multipliers. The same at every Level (Level only sets how far hits go).
 TrainingBase = 5,
 -- Real hits: Power for each second the ball is in play, as a share of the Training base (before
 -- Ball, Rebirth and Juice), rounded; never scaled by Level (higher Levels only stay in play
 -- longer because they hit farther). Counting the time between hits, batting
 -- earns about 50-70% of Basic Training's Power (Training gives half the base per second) and
 -- never uses the Ground, so Training is always the best Power source.
 HitPowerPerSecond = 0.37,
 -- Launch speed by Level, built from measured hits (tools/balance/HitMeasurements). Levels 1-21:
 -- linear between these {Level, speed} points (with EarlyLaunch below).
 LaunchSpeedTable = {{1, 55}, {11, 64.6}, {21, 78}},
 -- From Level 22: {Level, speed} steps, each speed used from its Level until the next. The landing
 -- bounces make distance jump around from one speed to the next at every speed (110 lands ~300
 -- studs, 112 ~280, 118 ~350; 649 lands at 7,000, 650 at 5,959), so each step is a measured speed
 -- chosen for where it lands, and distances rise with Level (not the speeds).
 --  * Levels 22-140, one step each: distance grows 5% a Level from Level 21 (~146 studs), easing
 --    to 1.7% at Level 100 and staying there to 140 (3,906), so mid-game hits grow fast and
 --    Levels 100-140 grow evenly (tools/balance `distanceShape` + `measuredSteps`). A Level with
 --    no measured speed on the curve repeats the Level before. Below ~200 studs/s a speed varies
 --    from hit to hit (up to ~40%), so early hits spread around the curve.
 --  * From Level 141, each a speed measured twice to land in its range: World 1's end (5,000) is
 --    reached from Level 150, World 2's (6,000) from 250 and World 3's (7,000) from 370, matching
 --    the Training Ground Rebirth gates (Rebirths 7, 12 and 18 reach those Levels).
 -- Re-measure and re-solve with tools/balance after any physics change.
 LaunchSpeedSteps = {
  {22, 86}, {23, 84}, {24, 84}, {25, 90}, {26, 92}, {27, 88}, {28, 108}, {29, 108}, {30, 106},
  {31, 115}, {32, 104}, {33, 114}, {34, 105.4}, {35, 111.1}, {36, 116}, {37, 122}, {38, 126},
  {39, 136}, {40, 124}, {41, 133}, {42, 134}, {43, 132}, {44, 142}, {45, 162}, {46, 160}, {47, 156},
  {48, 154}, {49, 152}, {50, 205.6}, {51, 174}, {52, 196}, {53, 210}, {54, 164}, {55, 168},
  {56, 206}, {57, 169}, {58, 222}, {59, 184}, {60, 252}, {61, 204}, {62, 282}, {63, 280}, {64, 234},
  {65, 246}, {66, 262}, {67, 248}, {68, 198}, {69, 294}, {70, 278}, {71, 226}, {72, 244}, {73, 358},
  {74, 342}, {75, 274}, {76, 322}, {77, 290}, {78, 272}, {79, 240}, {80, 372}, {81, 352}, {82, 302},
  {83, 404}, {84, 370}, {85, 304}, {86, 413.8}, {87, 268}, {88, 402}, {89, 424.5}, {90, 283.9},
  {91, 368}, {92, 423.2}, {93, 284}, {94, 400}, {95, 466}, {96, 432}, {97, 452}, {98, 380},
  {99, 455.5}, {100, 398}, {101, 346}, {102, 430}, {103, 364}, {104, 390.8}, {105, 444}, {106, 496},
  {107, 489.6}, {108, 462}, {109, 456.8}, {110, 489.4}, {111, 480}, {112, 455.1}, {113, 344},
  {114, 408}, {115, 488.9}, {116, 500}, {117, 394}, {118, 460}, {119, 360}, {120, 484}, {121, 492},
  {122, 478}, {123, 392}, {124, 458}, {125, 502}, {126, 470.8}, {127, 406}, {128, 438}, {129, 472},
  {130, 486}, {131, 456}, {132, 424}, {133, 390}, {134, 390}, {135, 422}, {136, 470}, {137, 470},
  {138, 470}, {139, 470}, {140, 505},
  {141, 660}, {144, 693}, {147, 655}, -- ~4,050 / 4,450 / 4,770 studs
  {150, 690}, {160, 677}, {170, 686}, {180, 669}, {190, 652}, {200, 695}, {210, 704}, {220, 680},
  {230, 648}, {240, 687}, -- ~5,100 rising to 5,820 studs
  {250, 665}, {263, 667}, {276, 705}, {290, 714}, {303, 719}, {316, 679}, {330, 702}, {343, 685},
  {356, 699}, -- ~6,140 rising to 6,820 studs
  {370, 716}}, -- reaches World 3's end (and every earlier World's)
 -- About how far a hit at a Level lands (studs), from the same measured hits: {Level, distance}
 -- points, rising evenly in proportion between them. For estimates only (the Cash packs'
 -- "normal hits", MonetizationConfig); real hits are always measured.
 ExpectedHitDistances = {{1, 81}, {21, 146}, {30, 228}, {40, 347}, {50, 516}, {60, 755}, {70, 1002},
  {80, 1363}, {90, 1677}, {100, 2053}, {110, 2347}, {120, 2789}, {130, 3397}, {140, 3906},
  {141, 4050}, {144, 4450}, {147, 4770}, {150, 5100}, {249, 5820}, {250, 6140}, {369, 6820}, {370, 7000}},
 LaunchAngleDegrees = 38,
 -- The first Levels' hits: at the table's 55 studs/s a 38-degree hit only rises ~2 studs and lands
 -- ~20 studs out (Roblox gravity, 196 studs/s^2), then rolls, so it looks like a grounder. Level 1
 -- launches at this speed and angle instead, and both blend evenly back into LaunchSpeedTable and
 -- LaunchAngleDegrees by untilLevel (from where nothing changes). Until its first landing the
 -- ball also falls at gravityScale x normal gravity (a lighter, longer arc; BallLauncher), which
 -- eases back to 1 by untilLevel (most of it kept through ~Level 5); bounces and rolling always
 -- use normal gravity. Measured at Level 1: ~0.52 s in the air (full gravity: ~0.28 s) and still
 -- ~90 studs ($1). A softer landing rolls less, so less gravity needs more lift, not less speed.
 EarlyLaunch = {untilLevel = 21, speed = 61.6, angleDegrees = 48.3, gravityScale = 0.57},
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

-- A real hit's base Power: HitPowerPerSecond of the Training base for each second in play.
function Progression.GetHitPowerBase(seconds)
 return math.floor(Progression.TrainingBase * Progression.HitPowerPerSecond * math.max(0, seconds) + 0.5)
end

-- How much of EarlyLaunch still applies at this Level: 1 at Level 1, falling evenly to 0 at untilLevel.
local function earlyShare(level)
 local early = Progression.EarlyLaunch
 return math.clamp((early.untilLevel - level) / (early.untilLevel - 1), 0, 1)
end

local function tableSpeed(level)
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

-- Launch speed (studs/s), angle (degrees) and first-flight gravity scale for a Level: the only
-- inputs to a hit's distance.
function Progression.GetLaunchSpeed(level)
 local speed = tableSpeed(level)
 return speed + (Progression.EarlyLaunch.speed - tableSpeed(1)) * earlyShare(level)
end

function Progression.GetLaunchAngle(level)
 local angle = Progression.LaunchAngleDegrees
 return angle + (Progression.EarlyLaunch.angleDegrees - angle) * earlyShare(level)
end

-- Eased (smoothstep), so the first Levels keep most of the lighter gravity and it settles gently
-- into normal gravity near untilLevel.
function Progression.GetLaunchGravityScale(level)
 local share = earlyShare(level)
 return 1 + (Progression.EarlyLaunch.gravityScale - 1) * share * share * (3 - 2 * share)
end

-- About how far a hit at this Level lands (ExpectedHitDistances; flat past the last point).
function Progression.GetExpectedHitDistance(level)
 local points = Progression.ExpectedHitDistances
 if level <= points[1][1] then return points[1][2] end
 for index = 2, #points do
  local a, b = points[index - 1], points[index]
  if level <= b[1] then
   return a[2] * (b[2] / a[2]) ^ ((level - a[1]) / (b[1] - a[1]))
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
