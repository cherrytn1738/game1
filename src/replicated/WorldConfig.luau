-- World IDs are persistent ownership keys. Sections are scoped to their world.
local Worlds = {
 StartingWorldId = "world_1",
 Worlds = {
  {id = "world_1", displayName = "World 1", order = 1, endDistance = 5000,
   stationName = "BattingArea", fieldName = "LongRangeField",
   -- Hub extends behind the existing tee at (-17.2, 0, -21.2); forward is -Z.
   -- Spawn is 100 studs behind the tee, leaving 40 studs of open space at the back.
   offset = Vector3.zero, arrival = CFrame.new(-17.2, 4, 78.8), nextWorldId = "world_2",
   hub = {name = "World1Hub", width = 210, depth = 140,
    promptDistance = 10,
    -- Positions relative to the batting edge: +Z is back into the hub.
    interactions = {
     {id = "Shop", actionText = "Open Equipment Shop", position = Vector3.new(-70, 0, 65), size = Vector3.new(28, 0.1, 24)},
     {id = "Travel", actionText = "Open World Travel", position = Vector3.new(35, 0, 120), size = Vector3.new(14, 0.1, 12)},
    }},
   runoutDistance = 2000,
   sections = {
    {id = "grass", displayName = "Grass", startDistance = 0, endDistance = 300,
     order = 1, rewardMultiplier = 1, color = Color3.fromRGB(83, 135, 65), material = Enum.Material.Grass},
    {id = "snow", displayName = "Snow", startDistance = 300, endDistance = 800,
     order = 2, rewardMultiplier = 1.15, color = Color3.fromRGB(225, 237, 242), material = Enum.Material.Snow},
    {id = "stone", displayName = "Stone", startDistance = 800, endDistance = 5000,
     order = 3, rewardMultiplier = 1.35, color = Color3.fromRGB(122, 133, 151), material = Enum.Material.Slate},
   }},
  {id = "world_2", displayName = "World 2", order = 2, endDistance = 6000,
   stationName = "BattingArea2", fieldName = "LongRangeField2",
   offset = Vector3.new(8000, 0, 0), arrival = CFrame.new(8000, 4, 0),
   runoutDistance = 2000,
   sections = {
    {id = "section_1", displayName = "Section 1", startDistance = 0, endDistance = 500, order = 1, rewardMultiplier = 1},
    {id = "section_2", displayName = "Section 2", startDistance = 500, endDistance = 1500, order = 2, rewardMultiplier = 1.15},
    {id = "section_3", displayName = "Section 3", startDistance = 1500, endDistance = 6000, order = 3, rewardMultiplier = 1.35},
   }},
 },
}
function Worlds.Get(id)
 for _, world in Worlds.Worlds do if world.id == id then return world end end
 return nil
end
return Worlds
