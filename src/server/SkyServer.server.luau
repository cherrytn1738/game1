-- Applies the starting World's lighting when the server starts, so the Lighting that replicates
-- to every client (and any client before its World is known) matches World 1. Each player's
-- client then switches to their own World's preset (WorldLightingClient). Look-only values,
-- all in WorldLightingConfig.
local Storage = game:GetService("ReplicatedStorage")
local WorldLighting = require(Storage:WaitForChild("WorldLightingConfig"))
local Worlds = require(Storage:WaitForChild("WorldConfig"))

WorldLighting.Apply(WorldLighting.ForWorld(Worlds.StartingWorldId))
