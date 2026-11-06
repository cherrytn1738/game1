-- Playtime Rewards (the HUD's Rewards tile): twelve rewards unlocked by time played in the current
-- session, counted on the server (PlaytimeRewardServer). Each one is claimed once per cycle; after
-- all twelve, the board starts again from reward 1. Nothing is saved: leaving resets the timer.
--
-- A reward is any mix of:
--   cashHits          Cash worth that many normal hits for the player now (the Cash Pack quote:
--                     Monetization.GetCashPackReward with their Level, World, Bat and Cash tier)
--   trainingSeconds   Power worth that many seconds of Training at the best ground the player can
--                     use in their current World (as offline Training picks one), with their Ball,
--                     Rebirths and purchased Power tier (no juice); added through the Level path
--   juices            juices into the inventory ({[juiceId] = count}), never drunk
-- Amounts are worked out on the server when claimed; the menu shows the same numbers now.
-- row: the tile's colour (a UICommon CardPalettes key); grand: the grand prize.
local Storage = game:GetService("ReplicatedStorage")
local Progression = require(Storage:WaitForChild("ProgressionConfig"))
local Training = require(Storage:WaitForChild("TrainingConfig"))
local Monetization = require(Storage:WaitForChild("MonetizationConfig"))

local Playtime = {}

Playtime.Rewards = {
 {minutes = 1, cashHits = 3, row = "Blue"},
 {minutes = 3, trainingSeconds = 20, row = "Blue"},
 {minutes = 5, cashHits = 5, row = "Blue"},
 {minutes = 8, juices = {power_punch = 1}, row = "Blue"},
 {minutes = 12, trainingSeconds = 45, row = "Purple"},
 {minutes = 15, cashHits = 10, row = "Purple"},
 {minutes = 20, juices = {cash_splash = 1}, row = "Purple"},
 {minutes = 25, trainingSeconds = 60, row = "Purple"},
 {minutes = 30, cashHits = 15, row = "Gold"},
 {minutes = 40, trainingSeconds = 120, row = "Gold"},
 {minutes = 50, juices = {power_punch = 1, cash_splash = 1}, row = "Gold"},
 {minutes = 60, cashHits = 30, trainingSeconds = 180, row = "Rainbow", grand = true},
}

-- The shortest gap between two claim requests from one player.
Playtime.ClaimCooldownSeconds = 0.4
-- In Studio only, the Workspace attribute StudioPlaytimeScale (0.01-1) shortens every timer by that
-- factor (0.05: the 1-minute reward after 3 s), to test every state. Live servers ignore it.
Playtime.StudioScaleAttribute = "StudioPlaytimeScale"

for index, reward in Playtime.Rewards do
 assert(reward.cashHits or reward.trainingSeconds or reward.juices, "Playtime reward " .. index .. " gives nothing")
 assert(index == 1 or reward.minutes > Playtime.Rewards[index - 1].minutes, "Playtime rewards unlock in order")
end

-- Seconds of play (in the current cycle) before a reward is ready; scale is the Studio factor.
function Playtime.UnlockSeconds(index, scale)
 return Playtime.Rewards[index].minutes * 60 * (scale or 1)
end

-- Cash for a reward (0 when it gives none): its hits x one normal hit for the player now.
function Playtime.GetCash(reward, level, worldId, batId, cashTier)
 if not reward.cashHits then return 0 end
 return Monetization.GetCashPackReward({hits = reward.cashHits}, level, worldId, batId,
  Monetization.GetMultiplier("Cash", cashTier or 0))
end

-- The best ground the player can use in their current World, and its Power per second (after the
-- Ball, Rebirths and purchased Power tier). passes: owned pass grounds ({[id] = true}).
function Playtime.GetTrainingRate(rebirths, ballMultiplier, powerTier, passes, worldId)
 local ground = Training.GetBestGround(rebirths, passes, {[worldId] = true})
 local perHit = Progression.GetPowerGrant(Progression.TrainingBase * Training.GetMultiplier(ground, worldId), rebirths,
  ballMultiplier, Monetization.GetMultiplier("Power", powerTier or 0))
 return perHit / ground.interval, ground
end

-- Power for a reward (0 when it gives none).
function Playtime.GetPower(reward, rebirths, ballMultiplier, powerTier, passes, worldId)
 if not reward.trainingSeconds then return 0 end
 local rate = Playtime.GetTrainingRate(rebirths, ballMultiplier, powerTier, passes, worldId)
 return math.floor(rate * reward.trainingSeconds)
end

return Playtime
