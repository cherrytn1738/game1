-- Logical grounds share ONE plain stadium; appearance remains a future milestone.
local Training = {
 DefaultGround = "basic_training",
 Grounds = {
  {id = "basic_training", displayName = "Basic Training", requiredRebirths = 0, basePower = 20, interval = 2},
  {id = "advanced_training", displayName = "Advanced Training", requiredRebirths = 1, basePower = 50, interval = 2},
  {id = "expert_training", displayName = "Expert Training", requiredRebirths = 2, basePower = 100, interval = 2},
 },
 OfflineTrainingEnabled = true,
 MaximumOfflineSeconds = 8 * 60 * 60,
 OfflinePowerRateMultiplier = 0.25,
 OfflineNoticeMinimumSeconds = 60,
 -- Relative to the hub's batting-edge frame, in the reserved right-side area.
 PlatePosition = Vector3.new(70, 0, 70),
 PlateSize = Vector3.new(5, 0.1, 5),
 SelectorOffset = Vector3.new(-10, 0, 5),
 PitchOffset = Vector3.new(3, 3, -24),
 ContactOffset = Vector3.new(3, 3, 0),
 PracticeCycleSeconds = 2,
 PracticePitchSeconds = 1.1,
 SwingLeadSeconds = 0.2,
}

function Training.Get(id)
 for _, ground in Training.Grounds do if ground.id == id then return ground end end
 return nil
end

function Training.IsUnlocked(id, rebirths)
 local ground = Training.Get(id)
 return ground ~= nil and rebirths >= ground.requiredRebirths
end

function Training.ValidSelection(id, rebirths)
 return Training.IsUnlocked(id, rebirths) and id or Training.DefaultGround
end

function Training.GetOfflineReward(timestamp, now, selectedId)
 local ground = Training.Get(selectedId)
 if not Training.OfflineTrainingEnabled or not ground or type(timestamp) ~= "number"
  or timestamp ~= timestamp or timestamp <= 0 or timestamp % 1 ~= 0 or timestamp > now then
  return 0, 0
 end
 local seconds = math.min(now - timestamp, Training.MaximumOfflineSeconds)
 return math.floor(seconds * ground.basePower / ground.interval * Training.OfflinePowerRateMultiplier), seconds
end

return Training
