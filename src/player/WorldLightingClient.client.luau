-- Gives each World its own lighting on this player's client (WorldLightingConfig): players in
-- different Worlds share a server, so the server never switches Lighting. The preset changes the
-- moment the server moves this player to a World (CurrentWorldId), which a portal trip does under
-- its white screen. The hit cinematics and the portal trip only add their own grades and blurs
-- and remove them afterwards; the World's preset is applied again as each one ends
-- (CinematicCamera clears), so nothing they did can linger. Presentation only.
local Players = game:GetService("Players")
local Storage = game:GetService("ReplicatedStorage")
local WorldLighting = require(Storage:WaitForChild("WorldLightingConfig"))
local Worlds = require(Storage:WaitForChild("WorldConfig"))
local player = Players.LocalPlayer

local function refresh()
 WorldLighting.Apply(WorldLighting.ForWorld(player:GetAttribute("CurrentWorldId") or Worlds.StartingWorldId))
end

player:GetAttributeChangedSignal("CurrentWorldId"):Connect(refresh)
player:GetAttributeChangedSignal("CinematicCamera"):Connect(function()
 if not player:GetAttribute("CinematicCamera") then refresh() end
end)
refresh()
