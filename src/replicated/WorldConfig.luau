-- World IDs are persistent ownership keys. Sections are scoped to their world.

-- Every World's batting station is a copy of World 1's moved by the World's offset; World 1's
-- tee (the hub frame's origin, FieldBuilder) stands here on the ground.
local TEE = Vector3.new(-17.2, 0, -21.2)

-- ---------- Shared hub layout ----------
-- Every World's hub follows one compact layout, so a player knows where everything is in any
-- World. It is given in FieldBuilder's hub frame: origin at the tee, +Z back into the hub, +X
-- to the right when facing down the runway. The spawn stands just behind the batting area,
-- looking INTO the hub (+Z) with the runway behind it, so from the spawn LEFT is +X and RIGHT
-- is -X:
--   front   the batting circle round the tee, the runway beyond it (behind the spawn)
--   left    the World's row of six Training Grounds, the first nearest the batting area
--           (TrainingConfig.Row: plates at x 56, z 18-183; cage scenery reaches x 36-113)
--   right   the item displays, balls then bats, side by side facing the middle (x -36 to -51)
--   middle  an open plaza (x -26 to 26) with a path from the spawn to the back, and the
--           World's event piece (eventArea) halfway along it
--   back    the World portal in the middle (portalPad); World 1's global leaderboards stand
--           either side of it (leaderboards), and the other Worlds keep those spots open
-- The hub floor spans x minX..maxX and z 0..depth. Only the Training Grounds' side reaches
-- past the runway (x -86..86 with its walls).
local SPAWN = Vector3.new(0, 4, 30)
local function arrival(offset)
 return CFrame.new(TEE + offset + SPAWN) * CFrame.Angles(0, math.pi, 0) -- facing +Z, into the hub
end
local function hubLayout(name, theme, ballSeries, ballTitle)
 return {name = name, minX = -56, maxX = 118, depth = 220, theme = theme, spawn = SPAWN,
  promptDistance = 10,
  -- The physical stations are removed for now (their menus stay reachable from the HUD where a
  -- button exists); to restore one, add it here:
  --   {id = "Shop", actionText = "Open Equipment Shop", position = Vector3.new(-20, 0, 60), size = Vector3.new(28, 0.1, 24)},
  interactions = {},
  -- Physical item displays (ItemDisplay): one pedestal per item of one EquipmentConfig purchase
  -- series (series; nil is the category's main series), in stepped rows of perRow; position is
  -- the centre of the front row's edge, and yaw turns the display to face the middle (+X).
  -- Each row of 5 is about 35 studs wide. Items show RunwayAssets.DisplayItems.<item id> when
  -- that model exists, otherwise a placeholder. Bats stand upright, so theirs are taller.
  -- stairSide puts a staircase up to the top row beside one end (1 = the display's local +X end,
  -- here toward the spawn; -1 = toward the back), on the outer ends so the gap between the two
  -- displays stays clear. The flights reach about 12 (balls) and 15 (bats) studs past the ends.
  displays = {
   {id = "BallDisplay", category = "Ball", series = ballSeries, title = ballTitle, subtitle = "Gain more Power",
    position = Vector3.new(-36, 0, 86), yaw = math.pi / 2, perRow = 5, stairSide = 1},
   {id = "BatDisplay", category = "Bat", title = "BATS", subtitle = "Earn more Cash per hit",
    position = Vector3.new(-36, 0, 126), yaw = math.pi / 2, perRow = 5, itemSize = 3.6, itemHeight = 2.3, labelHeight = 3.6,
    stairSide = -1},
  },
  -- HubDecor marks these: the World's event piece in the middle of the plaza (kept flat so it
  -- never hides the portal), and the pad of the World portal (WorldPortal), facing the spawn
  -- (yaw 0). Stepping into the portal opens the Worlds menu.
  eventArea = {center = Vector3.new(0, 0, 118), size = 40},
  portalPad = {center = Vector3.new(0, 0, 205), radius = 12, yaw = 0}}
end

-- The starting World's hub also holds the global leaderboards (Leaderboards), two either side
-- of the portal, each turned toward `facing` so the four read as one curved wall from the
-- plaza. Left to right from the spawn: Level, Time Played | portal | Robux Spent, Cash.
local world1Hub = hubLayout("World1Hub", "HomeField", nil, "BALLS")
world1Hub.leaderboards = {facing = Vector3.new(0, 0, 90), boards = {
 {stat = "Level", position = Vector3.new(37, 0, 207)},
 {stat = "TimePlayed", position = Vector3.new(22, 0, 207)},
 {stat = "RobuxSpent", position = Vector3.new(-22, 0, 207)},
 {stat = "Cash", position = Vector3.new(-37, 0, 207)},
}}

local Worlds = {
 StartingWorldId = "world_1",
 Worlds = {
  {id = "world_1", displayName = "World 1", title = "Home Field", order = 1, endDistance = 5000,
   stationName = "BattingArea", fieldName = "LongRangeField",
   -- The shared hub layout (above), styled as a sunken ballpark with stands, a berm and a
   -- scoreboard (HubDecor "HomeField").
   offset = Vector3.zero, arrival = arrival(Vector3.zero), nextWorldId = "world_2",
   hub = world1Hub,
   -- The World's card in the Worlds menu (WorldTravelClient): image is a picture of the World's
   -- hub (an uploaded Studio capture, cropped to the card's 3.4:1 shape); without one, a
   -- painted scene in the sky and ground colours is shown instead.
   preview = {image = "rbxassetid://123256532508164", sky = Color3.fromRGB(110, 196, 255), ground = Color3.fromRGB(86, 176, 78)},
   runoutDistance = 2000,
   -- Cash per hit in this World is multiplied by cashMultiplier (ProgressionConfig.GetHitCash), so
   -- each World has its own price tier.
   cashMultiplier = 1,
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
   offset = Vector3.new(8000, 0, 0), arrival = arrival(Vector3.new(8000, 0, 0)), nextWorldId = "world_3",
   -- World 2's portals (the hub's World portal and the giant one at the runway's end) lead on to
   -- World 3, so they wear its look (WorldPortal: RunwayAssets.FuturePortal); the other Worlds
   -- use the clockwork time portal.
   portalModel = "FuturePortal",
   -- The shared hub layout (above), styled as a sunken clockwork plaza with a giant clock face, a
   -- clock tower and monuments from the eras ahead (HubDecor "TimeTravel"). World 2 sells its own ball series (EquipmentConfig Ball series "world_2"); bats are
   -- the same in every World.
   hub = hubLayout("World2Hub", "TimeTravel", "world_2", "TIME TRAVEL BALLS"),
   preview = {image = "rbxassetid://97442980907113", sky = Color3.fromRGB(150, 120, 235), ground = Color3.fromRGB(104, 88, 166)},
   runoutDistance = 2000,
   cashMultiplier = 10,
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
   -- The shared hub layout (above): a sunken spaceport plaza with glowing seams, a hologram
   -- stage, a beacon tower and the skyline of the future on the berm (HubDecor "Future").
   offset = Vector3.new(16000, 0, 0), arrival = arrival(Vector3.new(16000, 0, 0)),
   hub = hubLayout("World3Hub", "Future", "world_3", "FUTURE BALLS"),
   preview = {image = "rbxassetid://135986912788694", sky = Color3.fromRGB(150, 220, 255), ground = Color3.fromRGB(226, 234, 244)},
   runoutDistance = 2000,
   cashMultiplier = 100,
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
