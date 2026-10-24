-- Mirrors every successful PlayerData save into the global leaderboards' OrderedDataStores and
-- keeps World 1's physical boards up to date (Leaderboards).
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Leaderboards = require(script.Parent:WaitForChild("Leaderboards"))

PlayerData.OnSaved(Leaderboards.Submit)
Leaderboards.Start()
