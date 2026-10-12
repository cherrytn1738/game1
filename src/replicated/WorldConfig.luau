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
     {id = "Rebirth", actionText = "View Rebirth", objectText = "Rebirth", position = Vector3.new(-35, 0, 120), size = Vector3.new(8, 0.1, 8)},
    }},
   runoutDistance = 2000,
   -- Cosmetic only (RunwayDecor); none of these change flight or progression distances.
   runway = {width = 160, wallHeight = 12, wallThickness = 6, wallTileLength = 12,
    deckWidth = 72, outerGroundWidth = 260, propSpacing = 60, backdropSpacing = 90,
    propScale = 1.8, fillerScale = 1.5},
   sections = {
    -- Retain the existing IDs and reward thresholds; later themes subdivide the
    -- former Stone tier without changing its Cash multiplier.
    -- material: runway floor look only (ground physics are fixed separately).
    -- deckMaterial/props/backdrop: scenery beside the runway, see RunwayDecor.
    {id = "grass", displayName = "Meadow Run", startDistance = 0, endDistance = 300,
     order = 1, rewardMultiplier = 1, color = Color3.fromRGB(94, 190, 111), accent = Color3.fromRGB(215, 249, 112),
     material = Enum.Material.Grass, deckMaterial = Enum.Material.Grass, props = {"tree", "flowers", "mushroom"}, backdrop = "hills"},
    {id = "snow", displayName = "Frost Pass", startDistance = 300, endDistance = 800,
     order = 2, rewardMultiplier = 1.15, color = Color3.fromRGB(146, 217, 239), accent = Color3.fromRGB(229, 252, 255),
     material = Enum.Material.Marble, floorPattern = true, deckMaterial = Enum.Material.Snow, props = {"pine", "snowman", "iceShards"}, backdrop = "mountains", fillers = {"rock"}},
    {id = "stone", displayName = "Crystal Ridge", startDistance = 800, endDistance = 1300,
     order = 3, rewardMultiplier = 1.35, color = Color3.fromRGB(142, 116, 214), accent = Color3.fromRGB(231, 167, 255),
     material = Enum.Material.Marble, floorPattern = true, deckMaterial = Enum.Material.Slate, props = {"crystals", "geode"}, backdrop = "spires", fillers = {"rock"}},
    {id = "desert", displayName = "Golden Dunes", startDistance = 1300, endDistance = 1800,
     order = 4, rewardMultiplier = 1.35, color = Color3.fromRGB(228, 182, 100), accent = Color3.fromRGB(255, 232, 163),
     material = Enum.Material.Sand, deckMaterial = Enum.Material.Sand, props = {"cactus", "mesa", "dunes"}, backdrop = "mesas", fillers = {"rock"}},
    {id = "candy", displayName = "Candy Crossing", startDistance = 1800, endDistance = 2300,
     order = 5, rewardMultiplier = 1.35, color = Color3.fromRGB(229, 127, 184), accent = Color3.fromRGB(255, 218, 241),
     material = Enum.Material.Marble, floorPattern = true, deckMaterial = Enum.Material.SmoothPlastic, props = {"lollipop", "cake", "gumdrops", "candyCane"}, backdrop = "candyHills"},
    {id = "jungle", displayName = "Emerald Grove", startDistance = 2300, endDistance = 2800,
     order = 6, rewardMultiplier = 1.35, color = Color3.fromRGB(40, 139, 120), accent = Color3.fromRGB(148, 239, 125),
     material = Enum.Material.LeafyGrass, deckMaterial = Enum.Material.LeafyGrass, props = {"jungleTree", "fern", "mushroom"}, backdrop = "canopy"},
    {id = "lava", displayName = "Ember Canyon", startDistance = 2800, endDistance = 3300,
     order = 7, rewardMultiplier = 1.35, color = Color3.fromRGB(106, 67, 73), accent = Color3.fromRGB(255, 149, 64),
     material = Enum.Material.CrackedLava, deckMaterial = Enum.Material.Basalt, props = {"emberSpire", "lavaRock"}, backdrop = "volcanoes", fillers = {"rock"},
     floorCracks = true, wallTileColor = Color3.fromRGB(196, 96, 52)},
    {id = "neon", displayName = "Neon Circuit", startDistance = 3300, endDistance = 3800,
     order = 8, rewardMultiplier = 1.35, color = Color3.fromRGB(46, 78, 128), accent = Color3.fromRGB(79, 243, 239),
     material = Enum.Material.Glass, deckMaterial = Enum.Material.SmoothPlastic, props = {"beacon", "neonArch"}, backdrop = "towers", floorGrid = true, fillers = {"rock"}},
    {id = "sky", displayName = "Skyway", startDistance = 3800, endDistance = 4400,
     order = 9, rewardMultiplier = 1.35, color = Color3.fromRGB(109, 171, 230), accent = Color3.fromRGB(237, 248, 255),
     material = Enum.Material.Marble, floorPattern = true, deckMaterial = Enum.Material.SmoothPlastic, props = {"cloud", "rainbow", "island"}, backdrop = "bigClouds", fillers = {"bush"}},
    {id = "cosmic", displayName = "Starlight Finish", startDistance = 4400, endDistance = 5000,
     order = 10, rewardMultiplier = 1.35, color = Color3.fromRGB(79, 63, 130), accent = Color3.fromRGB(241, 189, 255),
     material = Enum.Material.Marble, floorPattern = true, deckMaterial = Enum.Material.SmoothPlastic, props = {"planet", "star", "moon"}, backdrop = "planets", fillers = {"rock"}},
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
