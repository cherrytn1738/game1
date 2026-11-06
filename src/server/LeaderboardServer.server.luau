-- Mirrors every successful PlayerData save into the global leaderboards' OrderedDataStores and
-- keeps every World's physical boards up to date (Leaderboards).
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Leaderboards = require(script.Parent:WaitForChild("Leaderboards"))

PlayerData.OnSaved(Leaderboards.Submit)
Leaderboards.Start()
