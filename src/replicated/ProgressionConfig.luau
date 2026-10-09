-- Placeholder balance. Power is progress toward the next level, not launch power.
local Progression = {
 StartingPower = 0,
 StartingLevel = 1,
 StartingRebirths = 0,
 BaseLevelCap = 10,
 LevelsPerRebirth = 10,
 PowerRequirementBase = 100,
 HitPowerReward = 2,
 BaseLaunchSpeed = 55,
 LaunchSpeedPerLevel = 15,
 LaunchAngleDegrees = 38,
 SwingCooldown = 0.84,
 ContactDelay = 0.20,
 -- Technical validation limits, not progression rewards or client inputs.
 MaxRebirths = 1000,
 MaxPower = 9000000000000,
 MaxBaseGrant = 1000000000,
}

function Progression.IsInteger(value, minimum, maximum)
 return type(value) == "number" and value == value and value >= minimum
  and value <= maximum and value % 1 == 0
end

function Progression.GetLevelCap(rebirths)
 return Progression.BaseLevelCap + Progression.LevelsPerRebirth * rebirths
end

function Progression.PowerRequiredForNextLevel(level)
 return Progression.PowerRequirementBase * level * level
end

function Progression.GetPowerMultiplier(rebirths)
 return rebirths + 1
end

function Progression.GetLaunchSpeed(level)
 return Progression.BaseLaunchSpeed + (level - Progression.StartingLevel) * Progression.LaunchSpeedPerLevel
end

-- Shared pure arithmetic; only PlayerData may grant authoritative Power.
-- Requirements are consumed, multiple levels can advance, and cap overflow is discarded.
function Progression.Advance(state, amount)
 state.Power += amount
 while state.Level < state.LevelCap do
  local required = Progression.PowerRequiredForNextLevel(state.Level)
  if state.Power < required then break end
  state.Power -= required
  state.Level += 1
 end
 if state.Level >= state.LevelCap then state.Power = 0 end
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
