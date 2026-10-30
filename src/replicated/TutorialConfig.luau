-- The new-player tutorial: four objectives in order, then Complete. These are the shared rules.
-- The server (PlayerData) owns, saves and advances the state, only from authoritative events
-- (granted Power, batting Cash, purchases, Level, Rebirths). Clients only read the published
-- TutorialStep / TutorialProgress attributes to draw the banner, arrows and spotlight.
--   EarnPower   earn PowerGoal Power (any source; Training is where the arrows lead)
--   EarnCash    earn CashGoal Cash from batting (Cash spent meanwhile doesn't count against it)
--   BuyBall     own BallId, the first Ball upgrade (buying it also equips it)
--   ReachLevel  reach the Level Cap (Level 20, the first Rebirth)
--   Rebirth     Rebirth; the server's successful Rebirth completes the tutorial
local Storage = game:GetService("ReplicatedStorage")
local Equipment = require(Storage:WaitForChild("EquipmentConfig"))
local Progression = require(Storage:WaitForChild("ProgressionConfig"))

local Tutorial = {
 Steps = {"EarnPower", "EarnCash", "BuyBall", "ReachLevel", "Rebirth"},
 Complete = "Complete",
 PowerGoal = 30,
 CashGoal = 2,
 -- The first Ball upgrade: the main series' second ball (the Sandlot Ball, $2, 3x Power).
 BallId = Equipment.GetSeriesItems("Ball")[2].id,
 TrainingGroundId = "basic_training",
 WorldId = "world_1",
 RebirthLevel = Progression.GetLevelCap(0),
}

local order = {}
for index, step in Tutorial.Steps do order[step] = index end

-- The counted target of a step (nil for steps that wait on a condition instead).
function Tutorial.Goal(step)
 if step == "EarnPower" then return Tutorial.PowerGoal end
 if step == "EarnCash" then return Tutorial.CashGoal end
 return nil
end

-- boughtBall: whether the player has bought BallId during the tutorial (at any step, so buying it
-- early still counts for the Ball step).
function Tutorial.New()
 return {step = Tutorial.Steps[1], progress = 0, boughtBall = false}
end

function Tutorial.IsComplete(state)
 return state.step == Tutorial.Complete
end

-- Adds an authoritative amount ("Power" granted, "Cash" earned from batting) to the current
-- step's count when that step counts it; "BallPurchase" (the server bought BallId for the player)
-- marks the tutorial's Ball as bought.
function Tutorial.Credit(state, kind, amount)
 if kind == "BallPurchase" then
  if state.boughtBall or Tutorial.IsComplete(state) then return false end
  state.boughtBall = true
  return true
 end
 local goal = Tutorial.Goal(state.step)
 if not goal or type(amount) ~= "number" or amount <= 0 then return false end
 if (kind == "Power") ~= (state.step == "EarnPower") or (kind == "Cash") ~= (state.step == "EarnCash") then return false end
 local progress = math.min(goal, state.progress + math.floor(amount))
 if progress == state.progress then return false end
 state.progress = progress
 return true
end

-- Moves on through every step whose condition holds. facts = {level, levelCap, equippedBall,
-- rebirthed}, all from the server's state. The Ball step needs BallId bought during the tutorial
-- AND equipped (buying it equips it), so it is always played, never skipped by owning it; rebirthed is true only for the player's own Rebirth
-- (PlayerData.TryRebirth at the Level Cap), which ends the tutorial from any step. A bonus Rebirth
-- (the Starter Pack's) only raises the Level Cap the ReachLevel step waits for. Returns whether
-- the step changed.
function Tutorial.Advance(state, facts)
 local changed = false
 while state.step ~= Tutorial.Complete do
  local step, done = state.step, false
  if facts.rebirthed then
   state.step, state.progress = Tutorial.Complete, 0
   return true
  elseif Tutorial.Goal(step) then
   done = state.progress >= Tutorial.Goal(step)
  elseif step == "BuyBall" then
   done = state.boughtBall == true and facts.equippedBall == Tutorial.BallId
  elseif step == "ReachLevel" then
   done = facts.level >= facts.levelCap
  end
  if not done then break end
  state.step, state.progress = Tutorial.Steps[order[step] + 1] or Tutorial.Complete, 0
  changed = true
 end
 return changed
end

-- Whether a save without (valid) tutorial fields already shows real play, so it should not be
-- sent through the tutorial: any Rebirth, Level, Power, Cash, bought equipment or later World.
function Tutorial.HasProgressed(data)
 if (data.Rebirths or 0) > 0 or (data.Level or 1) > 1 or (data.Power or 0) > 0 or (data.Cash or 0) > 0 then return true end
 for _, category in Equipment.CategoryOrder do
  for id in data[Equipment.Categories[category].ownedField] or {} do
   if not Equipment.IsStarting(category, id) then return true end
  end
 end
 for id in data.UnlockedWorlds or {} do
  if id ~= Tutorial.WorldId then return true end
 end
 return false
end

-- The state from a save's TutorialCompleted / TutorialStep / TutorialProgress fields. A new
-- record starts the tutorial; a finished one stays finished; a legacy or malformed one is
-- finished when the save has progressed (HasProgressed) and starts over otherwise.
function Tutorial.FromSave(data, isNew)
 if isNew then return Tutorial.New() end
 if data.TutorialCompleted == true then return {step = Tutorial.Complete, progress = 0} end
 if data.TutorialCompleted == false and order[data.TutorialStep] then
  local goal = Tutorial.Goal(data.TutorialStep)
  local progress = data.TutorialProgress
  local valid = goal and Progression.IsInteger(progress, 0, goal)
  return {step = data.TutorialStep, progress = valid and progress or 0, boughtBall = data.TutorialBoughtBall == true}
 end
 if Tutorial.HasProgressed(data) then return {step = Tutorial.Complete, progress = 0} end
 return Tutorial.New()
end

-- The save fields for a state (the step, its count and whether the Ball was bought are only kept
-- while unfinished).
function Tutorial.ToSave(state, data)
 local complete = Tutorial.IsComplete(state)
 data.TutorialCompleted = complete
 data.TutorialStep = not complete and state.step or nil
 data.TutorialProgress = not complete and state.progress or nil
 data.TutorialBoughtBall = not complete and state.boughtBall == true or nil
end

return Tutorial
