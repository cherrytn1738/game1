-- World IDs are persistent ownership keys. Sections are scoped to their world.
local Worlds = {
 StartingWorldId = "world_1",
 Worlds = {
  {id = "world_1", displayName = "World 1", title = "Home Field", order = 1, endDistance = 5000,
   stationName = "BattingArea", fieldName = "LongRangeField",
   -- Hub extends behind the existing tee at (-17.2, 0, -21.2); forward is -Z.
   -- Layout (hub-relative, +Z back into the hub): the Training Grounds stand in one row down
   -- the left side (TrainingConfig: plates at x -78, depth 34-199; their scenery reaches
   -- x ~-134 to -57), and the World portal and the item displays stand in one line on the right
   -- (front edge x 60, z 45 / 95 / 145), facing them across the middle, which is kept open for
   -- events. The hub reaches 136 studs left of the tee line but only 86 right, just past the
   -- displays, and 222 back, just past the last cage. Spawn is 60 studs behind the tee.
   offset = Vector3.zero, arrival = CFrame.new(-17.2, 4, 38.8), nextWorldId = "world_2",
   hub = {name = "World1Hub", left = 136, right = 86, depth = 222,
    -- Scenery style (HubDecor): a sunken ballpark with stands, a berm and a scoreboard.
    theme = "HomeField",
    promptDistance = 10,
    -- Positions relative to the batting edge: +Z is back into the hub. The physical
    -- stations are removed for now (their menus stay reachable from the HUD where a button
    -- exists); to restore one, uncomment it:
    --   {id = "Shop", actionText = "Open Equipment Shop", position = Vector3.new(-70, 0, 65), size = Vector3.new(28, 0.1, 24)},
    --   {id = "Travel", actionText = "Open World Travel", position = Vector3.new(35, 0, 120), size = Vector3.new(14, 0.1, 12)},
    --   {id = "Rebirth", actionText = "View Rebirth", objectText = "Rebirth", position = Vector3.new(-35, 0, 120), size = Vector3.new(8, 0.1, 8)},
    interactions = {},
    -- Physical item displays (ItemDisplay): one pedestal per item of one EquipmentConfig
    -- purchase series (series; nil is the category's main series), in stepped rows of perRow;
    -- position is the centre of the front row's edge.
    -- Items show RunwayAssets.DisplayItems.<item id> when that model exists, otherwise a
    -- placeholder in the item's appearance colours. Both stand on the right side in two rows of
    -- 5 (about 35 studs wide), turned (yaw) to face the Training Grounds across the middle.
    -- Bats stand upright, so their display uses taller items.
    displays = {
     {id = "BallDisplay", category = "Ball", title = "BALLS", subtitle = "Earn more Cash per hit",
      position = Vector3.new(60, 0, 95), yaw = -math.pi / 2, perRow = 5},
     {id = "BatDisplay", category = "Bat", title = "BATS", subtitle = "Gain more Power",
      position = Vector3.new(60, 0, 145), yaw = -math.pi / 2, perRow = 5, itemSize = 3.6, itemHeight = 2.3, labelHeight = 3.6},
    },
    -- HubDecor marks these: an infield diamond for events in the middle, and the pad of the World
    -- portal (WorldPortal), in line with the displays and turned (yaw) to face the middle. Stepping
    -- into it opens the Worlds menu.
    eventArea = {center = Vector3.new(0, 0, 125), size = 56},
    portalPad = {center = Vector3.new(62.5, 0, 45), radius = 12, yaw = math.pi / 2}},
   runoutDistance = 2000,
   -- A giant time portal stands at the endpoint (RunwayDecor); a ball that reaches it is pulled
   -- in, completing the World, and the batter is pulled through to the next World (PortalJourney).
   endPortal = {height = 360},
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
  {id = "world_2", displayName = "World 2", title = "Time Travel", order = 2, endDistance = 6000,
   stationName = "BattingArea2", fieldName = "LongRangeField2",
   -- Same hub layout as World 1 (TrainingConfig places World 2's cages in the same row), with
   -- spawn 60 studs behind this World's tee.
   offset = Vector3.new(8000, 0, 0), arrival = CFrame.new(7982.8, 4, 38.8), nextWorldId = "world_3",
   -- World 2's portals (the hub's World portal and the giant one at the runway's end) lead on to
   -- World 3, so they wear its look (WorldPortal: RunwayAssets.FuturePortal); the other Worlds
   -- use the clockwork time portal.
   portalModel = "FuturePortal",
   hub = {name = "World2Hub", left = 136, right = 86, depth = 222,
    -- Scenery style (HubDecor): a sunken clockwork plaza with a giant clock face, a clock tower
    -- and monuments from the eras ahead.
    theme = "TimeTravel",
    promptDistance = 10,
    interactions = {},
    -- World 2 sells its own ball series (EquipmentConfig Ball series "world_2"); bats are the
    -- same in every World.
    displays = {
     {id = "BallDisplay", category = "Ball", series = "world_2", title = "TIME TRAVEL BALLS", subtitle = "Earn more Cash per hit",
      position = Vector3.new(60, 0, 95), yaw = -math.pi / 2, perRow = 5},
     {id = "BatDisplay", category = "Bat", title = "BATS", subtitle = "Gain more Power",
      position = Vector3.new(60, 0, 145), yaw = -math.pi / 2, perRow = 5, itemSize = 3.6, itemHeight = 2.3, labelHeight = 3.6},
    },
    eventArea = {center = Vector3.new(0, 0, 125), size = 56},
    -- The World portal, placed as in World 1.
    portalPad = {center = Vector3.new(62.5, 0, 45), radius = 12, yaw = math.pi / 2}},
   runoutDistance = 2000,
   -- The same portal ends World 2 and pulls the batter through to World 3.
   endPortal = {height = 360},
   -- Cosmetic only (RunwayDecor), as World 1.
   runway = {width = 160, wallHeight = 12, wallThickness = 6, wallTileLength = 12,
    deckWidth = 72, outerGroundWidth = 260, propSpacing = 60, backdropSpacing = 90,
    propScale = 1.8, fillerScale = 1.5},
   -- A trip through time, in the order of the World 2 balls (Dino Egg to Chrono Orb). The Cash
   -- multipliers keep the earlier thresholds (x1 to 500, x1.15 to 1500, x1.35 beyond).
   -- floorTiles / floorPlanks: thin floor lines for tiled and planked floors (RunwayDecor).
   -- deckColor: the side decks' color when it should not follow the theme (e.g. snow).
   sections = {
    {id = "prehistoric", displayName = "Prehistoric Valley", startDistance = 0, endDistance = 500,
     order = 1, rewardMultiplier = 1, color = Color3.fromRGB(86, 150, 78), accent = Color3.fromRGB(236, 200, 96),
     material = Enum.Material.Grass, deckMaterial = Enum.Material.LeafyGrass, props = {"cycad", "dinoNest", "fossil"},
     backdrop = "brontosaurus", fillers = {"fern", "rock"}},
    {id = "stoneage", displayName = "Stone Age Camp", startDistance = 500, endDistance = 1000,
     order = 2, rewardMultiplier = 1.15, color = Color3.fromRGB(150, 112, 80), accent = Color3.fromRGB(255, 152, 72),
     material = Enum.Material.Ground, deckMaterial = Enum.Material.Ground, props = {"stoneHut", "tuskArch", "campfire"},
     backdrop = "megaliths", fillers = {"rock", "bush"}},
    {id = "egypt", displayName = "Pharaoh's Sands", startDistance = 1000, endDistance = 1500,
     order = 3, rewardMultiplier = 1.15, color = Color3.fromRGB(214, 172, 100), accent = Color3.fromRGB(255, 208, 80),
     material = Enum.Material.Sandstone, deckMaterial = Enum.Material.Sand, props = {"obelisk", "sphinx", "scarabPillar"},
     backdrop = "pyramids", fillers = {"rock"}, floorTiles = true},
    {id = "greek", displayName = "Olympian Heights", startDistance = 1500, endDistance = 2100,
     order = 4, rewardMultiplier = 1.35, color = Color3.fromRGB(214, 218, 232), accent = Color3.fromRGB(84, 146, 232),
     material = Enum.Material.Marble, deckMaterial = Enum.Material.Limestone, props = {"greekColumn", "amphora", "heroStatue"},
     backdrop = "temple", fillers = {"bush", "rock"}, floorTiles = true},
    {id = "viking", displayName = "Viking Fjord", startDistance = 2100, endDistance = 2700,
     order = 5, rewardMultiplier = 1.35, color = Color3.fromRGB(128, 96, 72), accent = Color3.fromRGB(214, 74, 58),
     material = Enum.Material.WoodPlanks, deckMaterial = Enum.Material.Snow, deckColor = Color3.fromRGB(236, 242, 250),
     props = {"longship", "runeStone", "shieldRack"},
     backdrop = "fjordPeaks", fillers = {"pine", "rock"}, floorPlanks = true},
    {id = "samurai", displayName = "Samurai Gardens", startDistance = 2700, endDistance = 3300,
     order = 6, rewardMultiplier = 1.35, color = Color3.fromRGB(112, 142, 100), accent = Color3.fromRGB(255, 172, 206),
     material = Enum.Material.Pebble, deckMaterial = Enum.Material.Grass, props = {"torii", "stoneLantern", "cherryTree"},
     backdrop = "pagodas", fillers = {"bush", "rock"}},
    {id = "knight", displayName = "Knight's Kingdom", startDistance = 3300, endDistance = 3900,
     order = 7, rewardMultiplier = 1.35, color = Color3.fromRGB(120, 120, 132), accent = Color3.fromRGB(64, 112, 224),
     material = Enum.Material.Cobblestone, deckMaterial = Enum.Material.Grass, props = {"banner", "catapult", "armorStand"},
     backdrop = "castle", fillers = {"bush", "rock"}},
    {id = "frontier", displayName = "Frontier Town", startDistance = 3900, endDistance = 4500,
     order = 8, rewardMultiplier = 1.35, color = Color3.fromRGB(192, 104, 64), accent = Color3.fromRGB(255, 208, 122),
     material = Enum.Material.Ground, deckMaterial = Enum.Material.Sand, props = {"waterTower", "wagon", "cactus"},
     backdrop = "buttes", fillers = {"barrels", "rock"}},
    {id = "foundry", displayName = "Clockwork Foundry", startDistance = 4500, endDistance = 5200,
     order = 9, rewardMultiplier = 1.35, color = Color3.fromRGB(100, 86, 76), accent = Color3.fromRGB(236, 172, 72),
     material = Enum.Material.Metal, deckMaterial = Enum.Material.DiamondPlate, props = {"gearTower", "pipeWorks"},
     backdrop = "smokestacks", fillers = {"barrels", "rock"}, floorTiles = true, wallTileColor = Color3.fromRGB(196, 140, 70)},
    {id = "chrono", displayName = "Chrono Nexus", startDistance = 5200, endDistance = 6000,
     order = 10, rewardMultiplier = 1.35, color = Color3.fromRGB(54, 48, 112), accent = Color3.fromRGB(92, 240, 255),
     material = Enum.Material.Glass, deckMaterial = Enum.Material.SmoothPlastic, props = {"timeRing", "hourglass", "holoClock"},
     backdrop = "futureSpires", fillers = {"rock"}, floorGrid = true},
   }},
  {id = "world_3", displayName = "World 3", title = "Future World", order = 3, endDistance = 7000,
   stationName = "BattingArea3", fieldName = "LongRangeField3",
   -- Same hub layout as the other Worlds, with spawn 60 studs behind this World's tee.
   offset = Vector3.new(16000, 0, 0), arrival = CFrame.new(15982.8, 4, 38.8),
   hub = {name = "World3Hub", left = 136, right = 86, depth = 222,
    -- Scenery style (HubDecor): a sunken spaceport plaza with glowing seams, a hologram stage,
    -- a beacon tower and the skyline of the future on the berm.
    theme = "Future",
    promptDistance = 10,
    interactions = {},
    displays = {
     {id = "BallDisplay", category = "Ball", series = "world_3", title = "FUTURE BALLS", subtitle = "Earn more Cash per hit",
      position = Vector3.new(60, 0, 95), yaw = -math.pi / 2, perRow = 5},
     {id = "BatDisplay", category = "Bat", title = "BATS", subtitle = "Gain more Power",
      position = Vector3.new(60, 0, 145), yaw = -math.pi / 2, perRow = 5, itemSize = 3.6, itemHeight = 2.3, labelHeight = 3.6},
    },
    eventArea = {center = Vector3.new(0, 0, 125), size = 56},
    portalPad = {center = Vector3.new(62.5, 0, 45), radius = 12, yaw = math.pi / 2}},
   runoutDistance = 2000,
   -- The last World for now. Its portal completes it as usual, then plays a temporary finale
   -- (PortalJourneyClient) instead of a trip. To add World 4: give World 3 a nextWorldId and
   -- remove the finale.
   endPortal = {height = 360, finale = {title = "YOU FINISHED THE GAME!", subtitle = "MORE WORLDS COMING SOON",
    closing = "THANKS FOR PLAYING!"}},
   -- Cosmetic only (RunwayDecor), as the other Worlds. Landmarks are single giant meshes
   -- (here a black hole looming behind the end portal); distance is downfield, height above
   -- the ground.
   runway = {width = 160, wallHeight = 12, wallThickness = 6, wallTileLength = 12,
    deckWidth = 72, outerGroundWidth = 260, propSpacing = 60, backdropSpacing = 90,
    propScale = 1.8, fillerScale = 1.5,
    landmarks = {{kind = "blackHole", distance = 7550, height = 760, scale = 34}}},
   -- A trip into the future, in the order of the World 3 balls (Solar Cell to Singularity
   -- Orb). The Cash multipliers follow the earlier Worlds' pattern (x1 to 600, x1.15 to 2000,
   -- x1.35 beyond).
   -- floorLanes / floorHazard / floorCraters: lane markings, warning stripes along the edges
   -- and crater rings (RunwayDecor), alongside the earlier floor patterns.
   sections = {
    {id = "solar", displayName = "Solar Suburbs", startDistance = 0, endDistance = 600,
     order = 1, rewardMultiplier = 1, color = Color3.fromRGB(206, 214, 222), accent = Color3.fromRGB(255, 196, 64),
     material = Enum.Material.Concrete, deckMaterial = Enum.Material.Grass, deckColor = Color3.fromRGB(112, 188, 98),
     props = {"ecoHouse", "windTurbine", "solarTree"}, backdrop = "windFarm", fillers = {"planter", "flowers"}, floorTiles = true},
    {id = "maglev", displayName = "Maglev Highway", startDistance = 600, endDistance = 1300,
     order = 2, rewardMultiplier = 1.15, color = Color3.fromRGB(66, 72, 88), accent = Color3.fromRGB(80, 228, 255),
     material = Enum.Material.Asphalt, deckMaterial = Enum.Material.Concrete, deckColor = Color3.fromRGB(150, 156, 168),
     props = {"hoverCar", "maglevPylon", "holoSign"}, backdrop = "viaduct", fillers = {"planter"}, floorLanes = true},
    {id = "metropolis", displayName = "Skyline Metropolis", startDistance = 1300, endDistance = 2000,
     order = 3, rewardMultiplier = 1.15, color = Color3.fromRGB(176, 186, 210), accent = Color3.fromRGB(255, 92, 206),
     material = Enum.Material.Marble, deckMaterial = Enum.Material.SmoothPlastic, props = {"holoBillboard", "neoLamp", "skyTaxi"},
     backdrop = "skyscrapers", fillers = {"planter"}, floorTiles = true},
    {id = "robotics", displayName = "Robo Assembly Line", startDistance = 2000, endDistance = 2700,
     order = 4, rewardMultiplier = 1.35, color = Color3.fromRGB(96, 102, 114), accent = Color3.fromRGB(255, 160, 32),
     material = Enum.Material.DiamondPlate, deckMaterial = Enum.Material.Metal, props = {"robotArm", "conveyor", "robotUnit"},
     backdrop = "megaFactory", fillers = {"cargoCrate"}, floorHazard = true, wallTileColor = Color3.fromRGB(255, 196, 40)},
    {id = "biodome", displayName = "Biodome Gardens", startDistance = 2700, endDistance = 3400,
     order = 5, rewardMultiplier = 1.35, color = Color3.fromRGB(66, 150, 128), accent = Color3.fromRGB(214, 120, 255),
     material = Enum.Material.LeafyGrass, deckMaterial = Enum.Material.LeafyGrass, deckColor = Color3.fromRGB(78, 156, 102),
     props = {"biodome", "alienPlant", "glowShroom"},
     backdrop = "domes", fillers = {"fern", "bush"}},
    {id = "virtual", displayName = "Virtual Grid", startDistance = 3400, endDistance = 4100,
     order = 6, rewardMultiplier = 1.35, color = Color3.fromRGB(26, 24, 48), accent = Color3.fromRGB(80, 255, 170),
     material = Enum.Material.SmoothPlastic, deckMaterial = Enum.Material.SmoothPlastic, props = {"dataCube", "voxelTree", "glitchPillar"},
     backdrop = "voxelPeaks", fillers = {"voxelBush"}, floorGrid = true},
    {id = "spaceport", displayName = "Orbital Spaceport", startDistance = 4100, endDistance = 4800,
     order = 7, rewardMultiplier = 1.35, color = Color3.fromRGB(168, 170, 176), accent = Color3.fromRGB(255, 120, 40),
     material = Enum.Material.Concrete, deckMaterial = Enum.Material.Concrete, props = {"rocket", "radarDish", "fuelTank"},
     backdrop = "launchTowers", fillers = {"cargoCrate"}, floorLanes = true},
    {id = "lunar", displayName = "Lunar Colony", startDistance = 4800, endDistance = 5500,
     order = 8, rewardMultiplier = 1.35, color = Color3.fromRGB(150, 150, 158), accent = Color3.fromRGB(120, 200, 255),
     material = Enum.Material.Slate, deckMaterial = Enum.Material.Slate, deckColor = Color3.fromRGB(132, 132, 140),
     props = {"habitatPod", "lunarLander", "astronautFlag"}, backdrop = "moonRidges", fillers = {"rock"}, floorCraters = true},
    {id = "mars", displayName = "Red Planet Outpost", startDistance = 5500, endDistance = 6200,
     order = 9, rewardMultiplier = 1.35, color = Color3.fromRGB(184, 92, 56), accent = Color3.fromRGB(255, 184, 96),
     material = Enum.Material.Sand, deckMaterial = Enum.Material.Sand, props = {"marsRover", "terraformer", "marsHabitat"},
     backdrop = "marsButtes", fillers = {"rock"}, floorCraters = true},
    {id = "singularity", displayName = "Quantum Singularity", startDistance = 6200, endDistance = 7000,
     order = 10, rewardMultiplier = 1.35, color = Color3.fromRGB(40, 26, 72), accent = Color3.fromRGB(222, 160, 255),
     material = Enum.Material.Glass, deckMaterial = Enum.Material.SmoothPlastic, props = {"energyRing", "quantumShard", "riftRock"},
     backdrop = "voidShards", fillers = {"rock"}, floorCracks = true},
   }},
 },
}
function Worlds.Get(id)
 for _, world in Worlds.Worlds do if world.id == id then return world end end
 return nil
end
return Worlds
