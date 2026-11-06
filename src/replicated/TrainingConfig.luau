-- Training Grounds are physical batting cages, each with its own plate, standing in a row in
-- a World's hub (Hubs below). Rebirth grounds unlock by Rebirth count; paid grounds are Roblox
-- game passes (gamePassId 0 = not created yet, so the ground cannot be bought or used). A
-- ground can only be used once a World it stands in is unlocked.
--   powerMultiplier: Power per practice hit = Training base (ProgressionConfig, by Level) x powerMultiplier
--   worldMultipliers: a ground standing in several Worlds (Dragon's Lair) has one multiplier per
--     World instead ({[worldId] = multiplier}); always read a ground's multiplier with
--     Training.GetMultiplier(ground, worldId)
--   sharesPass: a paid ground opened by another ground's game pass (no pass of its own)
--   shopImage: optional uploaded screenshot (rbxassetid) for the paid ground's Shop card; empty
--     shows the live 3D preview of its cage instead (see .vscode/MONETIZATION.md)
--   theme: the cage template in ServerStorage.RunwayAssets (fantasy cages are styled by
--     TrainingCageStyles), turf/lane colors and materials, banner color, and for the standard
--     cage its role colors (accent, frame, net) and floodlights; decorations are
--     {slot = "<Attachment in Cage.DecorSlots>", template = "<Model in RunwayAssets>"}
local M = Enum.Material
-- Every cage is narrowed to this share of its modelled width (also spaces the row).
local CAGE_WIDTH_SCALE = 0.75
local Training = {
 DefaultGround = "basic_training",
 Grounds = {
  -- World 1 (Home Field)
  {id = "basic_training", displayName = "Basic Training", requiredRebirths = 0, powerMultiplier = 1, interval = 2,
   theme = {template = "TrainingCage", turf = Color3.fromRGB(74, 140, 72), lane = Color3.fromRGB(176, 128, 84),
    accent = Color3.fromRGB(200, 58, 50), frame = Color3.fromRGB(86, 92, 100), net = Color3.fromRGB(22, 22, 26),
    banner = Color3.fromRGB(200, 58, 50), lights = false, decorations = {}}},
  {id = "enchanted_grove", displayName = "Enchanted Grove", requiredRebirths = 2, powerMultiplier = 5, interval = 2,
   theme = {template = "GroveCage", turf = Color3.fromRGB(78, 138, 58), lane = Color3.fromRGB(96, 140, 70), laneMaterial = M.Grass,
    accent = Color3.fromRGB(190, 120, 230), frame = Color3.fromRGB(110, 78, 50), net = Color3.fromRGB(60, 110, 50),
    banner = Color3.fromRGB(120, 70, 160), lights = false, decorations = {}}},
  {id = "sunken_atlantis", displayName = "Sunken Atlantis", requiredRebirths = 4, powerMultiplier = 10, interval = 2,
   theme = {template = "AtlantisCage", turf = Color3.fromRGB(222, 204, 156), turfMaterial = M.Sand,
    lane = Color3.fromRGB(26, 158, 168), laneMaterial = M.SmoothPlastic,
    accent = Color3.fromRGB(30, 190, 200), frame = Color3.fromRGB(226, 226, 220), net = Color3.fromRGB(40, 120, 150),
    banner = Color3.fromRGB(20, 110, 150), lights = true, decorations = {}}},
  {id = "sky_temple", displayName = "Sky Temple", requiredRebirths = 6, powerMultiplier = 20, interval = 2,
   theme = {template = "SkyTempleCage", turf = Color3.fromRGB(240, 238, 230), turfMaterial = M.Marble,
    lane = Color3.fromRGB(235, 200, 110), laneMaterial = M.Marble,
    accent = Color3.fromRGB(240, 196, 60), frame = Color3.fromRGB(245, 245, 240), net = Color3.fromRGB(214, 170, 60),
    banner = Color3.fromRGB(70, 140, 220), lights = true, decorations = {}}},
  {id = "cosmic_rift", displayName = "Cosmic Rift", gamePassId = 0, robuxPrice = 500, powerMultiplier = 10, interval = 2,
   shopImage = "",
   theme = {template = "CosmicRiftCage", turf = Color3.fromRGB(22, 14, 46), turfMaterial = M.SmoothPlastic,
    lane = Color3.fromRGB(90, 220, 255), laneMaterial = M.Neon,
    accent = Color3.fromRGB(90, 220, 255), frame = Color3.fromRGB(150, 156, 180), net = Color3.fromRGB(120, 80, 220),
    banner = Color3.fromRGB(50, 24, 110), lights = true, decorations = {}}},
  -- World 2 (Time Travel). Its Rebirth tiers continue on from World 1's; the first cage is
  -- free once World 2 is unlocked. Each has its own era cage (tools/blender/*_cage.py,
  -- TrainingCageStyles); until it is imported, the standard cage stands in, in the era colors below.
  {id = "caveman_camp", displayName = "Caveman Camp", requiredRebirths = 0, powerMultiplier = 25, interval = 2,
   theme = {template = "CavemanCampCage", turf = Color3.fromRGB(150, 112, 74), turfMaterial = M.Ground,
    lane = Color3.fromRGB(214, 180, 104), laneMaterial = M.Fabric,
    accent = Color3.fromRGB(232, 222, 196), frame = Color3.fromRGB(112, 78, 48), net = Color3.fromRGB(86, 104, 52),
    banner = Color3.fromRGB(196, 104, 40), lights = false, decorations = {}}},
  {id = "pharaohs_tomb", displayName = "Pharaoh's Tomb", requiredRebirths = 8, powerMultiplier = 35, interval = 2,
   theme = {template = "PharaohsTombCage", turf = Color3.fromRGB(230, 200, 136), turfMaterial = M.Sand,
    lane = Color3.fromRGB(214, 170, 92), laneMaterial = M.Sandstone,
    accent = Color3.fromRGB(240, 190, 50), frame = Color3.fromRGB(206, 170, 110), net = Color3.fromRGB(36, 70, 150),
    banner = Color3.fromRGB(30, 60, 140), lights = true, decorations = {}}},
  {id = "gladiator_colosseum", displayName = "Gladiator Colosseum", requiredRebirths = 10, powerMultiplier = 50, interval = 2,
   theme = {template = "GladiatorColosseumCage", turf = Color3.fromRGB(214, 186, 140), turfMaterial = M.Sand,
    lane = Color3.fromRGB(184, 102, 70), laneMaterial = M.Brick,
    accent = Color3.fromRGB(180, 30, 36), frame = Color3.fromRGB(236, 230, 214), net = Color3.fromRGB(176, 120, 60),
    banner = Color3.fromRGB(150, 24, 30), lights = true, decorations = {}}},
  {id = "samurai_dojo", displayName = "Samurai Dojo", requiredRebirths = 12, powerMultiplier = 70, interval = 2,
   theme = {template = "SamuraiDojoCage", turf = Color3.fromRGB(196, 190, 132), turfMaterial = M.Fabric,
    lane = Color3.fromRGB(150, 104, 64), laneMaterial = M.WoodPlanks,
    accent = Color3.fromRGB(200, 36, 36), frame = Color3.fromRGB(34, 30, 32), net = Color3.fromRGB(46, 40, 40),
    banner = Color3.fromRGB(190, 30, 30), lights = true, decorations = {}}},
  {id = "time_machine_lab", displayName = "Time Machine Lab", sharesPass = "cosmic_rift", powerMultiplier = 35, interval = 2,
   shopImage = "",
   theme = {template = "TimeMachineLabCage", turf = Color3.fromRGB(46, 50, 62), turfMaterial = M.DiamondPlate,
    lane = Color3.fromRGB(70, 230, 255), laneMaterial = M.Neon,
    accent = Color3.fromRGB(70, 230, 255), frame = Color3.fromRGB(196, 150, 70), net = Color3.fromRGB(110, 70, 200),
    banner = Color3.fromRGB(40, 30, 100), lights = true, decorations = {}}},
  -- World 3 (Future World). Its Rebirth tiers continue on from World 2's; the first cage is
  -- free once World 3 is unlocked, and Quantum Lab shares Cosmic Rift's pass like Time Machine
  -- Lab. Each has its own futuristic cage (TrainingCageStyles), more intricate down the row.
  {id = "solar_rooftop", displayName = "Solar Rooftop", requiredRebirths = 0, powerMultiplier = 90, interval = 2,
   theme = {template = "SolarRooftopCage", turf = Color3.fromRGB(196, 200, 206), turfMaterial = M.Concrete,
    lane = Color3.fromRGB(90, 150, 220), laneMaterial = M.SmoothPlastic,
    accent = Color3.fromRGB(255, 196, 64), frame = Color3.fromRGB(240, 242, 245), net = Color3.fromRGB(150, 210, 240),
    banner = Color3.fromRGB(36, 112, 196), lights = true, decorations = {}}},
  {id = "robo_factory", displayName = "Robo Factory", requiredRebirths = 14, powerMultiplier = 120, interval = 2,
   theme = {template = "RoboFactoryCage", turf = Color3.fromRGB(72, 76, 84), turfMaterial = M.DiamondPlate,
    lane = Color3.fromRGB(240, 180, 40), laneMaterial = M.SmoothPlastic,
    accent = Color3.fromRGB(255, 150, 30), frame = Color3.fromRGB(90, 96, 108), net = Color3.fromRGB(60, 64, 72),
    banner = Color3.fromRGB(226, 116, 20), lights = true, decorations = {}}},
  {id = "biodome_lab", displayName = "Biodome Lab", requiredRebirths = 16, powerMultiplier = 160, interval = 2,
   theme = {template = "BiodomeLabCage", turf = Color3.fromRGB(70, 150, 110), turfMaterial = M.LeafyGrass,
    lane = Color3.fromRGB(150, 230, 190), laneMaterial = M.SmoothPlastic,
    accent = Color3.fromRGB(200, 120, 255), frame = Color3.fromRGB(236, 240, 236), net = Color3.fromRGB(80, 160, 120),
    banner = Color3.fromRGB(36, 136, 106), lights = true, decorations = {}}},
  {id = "lunar_base", displayName = "Lunar Base", requiredRebirths = 18, powerMultiplier = 210, interval = 2,
   theme = {template = "LunarBaseCage", turf = Color3.fromRGB(150, 150, 156), turfMaterial = M.Slate,
    lane = Color3.fromRGB(200, 206, 216), laneMaterial = M.SmoothPlastic,
    accent = Color3.fromRGB(120, 200, 255), frame = Color3.fromRGB(236, 238, 242), net = Color3.fromRGB(110, 120, 140),
    banner = Color3.fromRGB(36, 56, 120), lights = true, decorations = {}}},
  {id = "quantum_lab", displayName = "Quantum Lab", sharesPass = "cosmic_rift", powerMultiplier = 120, interval = 2,
   shopImage = "",
   theme = {template = "QuantumLabCage", turf = Color3.fromRGB(20, 22, 40), turfMaterial = M.SmoothPlastic,
    lane = Color3.fromRGB(120, 240, 255), laneMaterial = M.Neon,
    accent = Color3.fromRGB(120, 240, 255), frame = Color3.fromRGB(200, 206, 230), net = Color3.fromRGB(110, 80, 230),
    banner = Color3.fromRGB(58, 30, 140), lights = true, decorations = {}}},
  -- World 4 (Tiny Town). Its Rebirth tiers continue on from World 3's; the first cage is free
  -- once World 4 is unlocked, and Snow Globe shares Cosmic Rift's pass like Quantum Lab. Each has
  -- its own toy cage (tools/blender/*_cage.py, TrainingCageStyles); the standard cage stands in until imported.
  {id = "sandbox_diamond", displayName = "Sandbox Diamond", requiredRebirths = 0, powerMultiplier = 270, interval = 2,
   theme = {template = "SandboxDiamondCage", turf = Color3.fromRGB(232, 206, 150), turfMaterial = M.Sand,
    lane = Color3.fromRGB(214, 180, 120), laneMaterial = M.Sand,
    accent = Color3.fromRGB(255, 196, 40), frame = Color3.fromRGB(230, 60, 60), net = Color3.fromRGB(60, 130, 230),
    banner = Color3.fromRGB(230, 60, 60), lights = false, decorations = {}}},
  {id = "pinball_cage", displayName = "Pinball Cage", requiredRebirths = 20, powerMultiplier = 350, interval = 2,
   theme = {template = "PinballCage", turf = Color3.fromRGB(36, 30, 70), turfMaterial = M.SmoothPlastic,
    lane = Color3.fromRGB(255, 80, 180), laneMaterial = M.Neon,
    accent = Color3.fromRGB(255, 80, 180), frame = Color3.fromRGB(210, 214, 226), net = Color3.fromRGB(90, 60, 200),
    banner = Color3.fromRGB(150, 40, 200), lights = true, decorations = {}}},
  {id = "cereal_bowl_stadium", displayName = "Cereal Bowl Stadium", requiredRebirths = 22, powerMultiplier = 450, interval = 2,
   theme = {template = "CerealBowlCage", turf = Color3.fromRGB(246, 244, 236), turfMaterial = M.SmoothPlastic,
    lane = Color3.fromRGB(236, 170, 70), laneMaterial = M.SmoothPlastic,
    accent = Color3.fromRGB(255, 150, 40), frame = Color3.fromRGB(70, 150, 230), net = Color3.fromRGB(200, 214, 230),
    banner = Color3.fromRGB(240, 120, 30), lights = true, decorations = {}}},
  {id = "toy_soldier_fort", displayName = "Toy Soldier Fort", requiredRebirths = 24, powerMultiplier = 580, interval = 2,
   theme = {template = "ToySoldierCage", turf = Color3.fromRGB(86, 140, 70), turfMaterial = M.SmoothPlastic,
    lane = Color3.fromRGB(196, 160, 110), laneMaterial = M.WoodPlanks,
    accent = Color3.fromRGB(214, 40, 40), frame = Color3.fromRGB(30, 50, 110), net = Color3.fromRGB(40, 40, 50),
    banner = Color3.fromRGB(200, 30, 30), lights = true, decorations = {}}},
  {id = "snow_globe", displayName = "Snow Globe", sharesPass = "cosmic_rift", powerMultiplier = 400, interval = 2,
   shopImage = "",
   theme = {template = "SnowGlobeCage", turf = Color3.fromRGB(240, 246, 252), turfMaterial = M.Snow,
    lane = Color3.fromRGB(170, 220, 255), laneMaterial = M.Ice,
    accent = Color3.fromRGB(140, 210, 255), frame = Color3.fromRGB(150, 100, 70), net = Color3.fromRGB(200, 230, 250),
    banner = Color3.fromRGB(60, 120, 200), lights = true, decorations = {},
    -- A client practice visual only: snow swirls round the cage after each practice hit.
    practiceHitEffect = "SnowSwirl"}},
  -- The most expensive ground; it stands in every World's hub. Its multiplier follows the World
  -- it is used in: a little above that World's premium ground (the Cosmic Rift pass's cage), but
  -- below the World's best Rebirth ground, so it is never the best cage in a World.
  {id = "dragons_lair", displayName = "Dragon's Lair", gamePassId = 0, robuxPrice = 1000, interval = 2,
   worldMultipliers = {world_1 = 15, world_2 = 45, world_3 = 150, world_4 = 500},
   shopImage = "",
   theme = {template = "DragonLairCage", turf = Color3.fromRGB(34, 28, 30), turfMaterial = M.Basalt,
    lane = Color3.fromRGB(214, 168, 50), laneMaterial = M.Metal,
    accent = Color3.fromRGB(255, 96, 20), frame = Color3.fromRGB(26, 24, 26), net = Color3.fromRGB(60, 50, 46),
    banner = Color3.fromRGB(150, 24, 20), lights = true, decorations = {}}},
 },
 -- Which grounds stand in each World's hub, in row order (the first is nearest the batting area).
 -- The first hub is the starting World's.
 Hubs = {
  {world = "world_1", grounds = {"basic_training", "enchanted_grove", "sunken_atlantis", "sky_temple", "cosmic_rift", "dragons_lair"}},
  {world = "world_2", grounds = {"caveman_camp", "pharaohs_tomb", "gladiator_colosseum", "samurai_dojo", "time_machine_lab", "dragons_lair"}},
  {world = "world_3", grounds = {"solar_rooftop", "robo_factory", "biodome_lab", "lunar_base", "quantum_lab", "dragons_lair"}},
  {world = "world_4", grounds = {"sandbox_diamond", "pinball_cage", "cereal_bowl_stadium", "toy_soldier_fort", "snow_globe", "dragons_lair"}},
 },
 -- Batting cage footprint in training-plate space (studs): batter faces +X, the machine is
 -- at -Z, and the door is in the batter-end net (z = back). The room behind the batter keeps
 -- the camera inside. The model* sizes are what tools/blender/*_cage.py models; in game every
 -- cage is narrowed to widthScale about the pitch line (x = widthCenter), so left/right and
 -- the door are derived below.
 Cage = {modelLeft = -16, modelRight = 14, back = 14, front = -34, height = 14,
  modelDoorLeft = -13, modelDoorRight = -7, doorHeight = 8, templateScale = 4,
  widthScale = CAGE_WIDTH_SCALE, widthCenter = 3},
 -- Every hub's row runs front to back down the side on the spawn's left (WorldConfig's shared
 -- hub layout), parallel to the runway, in the hub's batting-edge frame (+Z is back into the
 -- hub; +X is right when facing down the runway, so left when looking into the hub from the
 -- spawn). The first cage stands beside the batting area. Cages turn a quarter turn so their
 -- doors face the open middle (-X); a cage's scenery reaches about 20 studs from its plate
 -- toward the door and 57 away from it, so x 36-113 here. The models need 44 studs apiece
 -- (14-stud gaps for outside decorations), narrowed with the cages. The item displays face
 -- them from across the plaza.
 Row = {first = Vector3.new(56, 0, 18), step = Vector3.new(0, 0, 44 * CAGE_WIDTH_SCALE), yaw = -math.pi / 2},
 OfflineTrainingEnabled = true,
 MaximumOfflineSeconds = 8 * 60 * 60,
 OfflinePowerRateMultiplier = 0.25,
 -- Below the Level Cap, one return's offline Power is at most this share of the Power the player
 -- still needs for their Level Cap, so offline Training helps but never finishes a run by itself.
 -- At the cap there is no run left to fill: offline Power builds up there like Training does at
 -- the cap (up to MaxPower), held only by MaximumOfflineSeconds, and a Rebirth resets it to 0.
 OfflineRunShare = 0.5,
 -- Welcome Back shows only after at least this long away.
 OfflineNoticeMinimumSeconds = 5 * 60,
 -- Welcome Back's "3x" offer: a Robux developer product that adds the offline reward twice more
 -- (multiplier 3 in all), once per login, up to runShare of the Power the player needed for their
 -- Level Cap at login (all of it: the 3x can finish the run but never go past the cap; at the cap
 -- it is never offered). productId 0 = not created yet (the price badge shows SOON); robuxPrice is
 -- the price shown on the badge.
 OfflineTriple = {productId = 0, robuxPrice = 10, multiplier = 3, runShare = 1},
 PlateSize = Vector3.new(5, 0.1, 5),
 PitchOffset = Vector3.new(3, 3, -24),
 ContactOffset = Vector3.new(3, 3, 0),
 -- The practice loop: one pitch every PracticeCycleSeconds, met by the bat PracticePitchSeconds in.
 -- The server grants each Training tick on that hit (TrainingService), so the cycle matches
 -- every ground's interval (asserted below).
 PracticeCycleSeconds = 2,
 PracticePitchSeconds = 1.1,
}

-- Plate-space x of a cage model point after the cage is narrowed.
function Training.CageX(x)
 local c = Training.Cage
 return c.widthCenter + (x - c.widthCenter) * c.widthScale
end
Training.Cage.left, Training.Cage.right = Training.CageX(Training.Cage.modelLeft), Training.CageX(Training.Cage.modelRight)
Training.Cage.doorLeft, Training.Cage.doorRight = Training.CageX(Training.Cage.modelDoorLeft), Training.CageX(Training.Cage.modelDoorRight)

function Training.Get(id)
 for _, ground in Training.Grounds do if ground.id == id then return ground end end
 return nil
end

function Training.GetHub(worldId)
 for _, hub in Training.Hubs do if hub.world == worldId then return hub end end
 return nil
end

-- ground.worlds: the Worlds it stands in, in hub order. PassGrounds: the grounds that own a
-- game pass (a shared pass belongs to the ground named in sharesPass).
Training.PassGrounds = {}
for index, ground in Training.Grounds do
 ground.order = index
 ground.worlds = {}
 for _, hub in Training.Hubs do
  if table.find(hub.grounds, ground.id) then table.insert(ground.worlds, hub.world) end
 end
 assert(#ground.worlds > 0, "Training ground " .. ground.id .. " stands in no hub")
 assert(ground.interval == Training.PracticeCycleSeconds, ground.id .. "'s interval must match the practice cycle")
 for _, worldId in ground.worlds do
  local multiplier = ground.worldMultipliers and ground.worldMultipliers[worldId] or ground.powerMultiplier
  assert(type(multiplier) == "number" and multiplier > 0, ground.id .. " needs a Power multiplier in " .. worldId)
 end
 if ground.gamePassId ~= nil then table.insert(Training.PassGrounds, ground) end
end
for _, ground in Training.Grounds do
 local owner = ground.sharesPass and Training.Get(ground.sharesPass)
 assert(not ground.sharesPass or owner and owner.gamePassId ~= nil, ground.id .. " shares an unknown pass")
end

-- A ground's Power multiplier in a World it stands in (worldId; nil means its first World).
-- Most grounds have one multiplier; Dragon's Lair has one per World (worldMultipliers).
function Training.GetMultiplier(ground, worldId)
 if ground.worldMultipliers then
  return ground.worldMultipliers[worldId or ground.worlds[1]] or ground.worldMultipliers[ground.worlds[1]]
 end
 return ground.powerMultiplier
end

function Training.IsPaid(ground)
 return ground ~= nil and (ground.gamePassId ~= nil or ground.sharesPass ~= nil)
end

-- The ground whose game pass opens a paid ground: itself, or the one it shares a pass with.
-- Pass ownership, the pass id, its price and the TrainingPass_<id> attribute all use this.
function Training.GetPassGround(ground)
 return ground.sharesPass and Training.Get(ground.sharesPass) or ground
end

-- worlds is the set of World ids the player has unlocked ({[id] = true}); nil means only the
-- starting World.
function Training.IsReachable(ground, worlds)
 for _, worldId in ground.worlds do
  if worlds and worlds[worldId] or not worlds and worldId == Training.Hubs[1].world then return true end
 end
 return false
end

-- The unlocked Worlds that have grounds, from the server-set WorldUnlocked_<id> attributes.
function Training.ReadUnlockedWorlds(player)
 local worlds = {}
 for _, hub in Training.Hubs do
  if player:GetAttribute("WorldUnlocked_" .. hub.world) == true then worlds[hub.world] = true end
 end
 return worlds
end

-- Hub-relative plate position and facing (yaw) of a ground in a World's hub.
function Training.GetPlatePosition(ground, worldId)
 local hub = Training.GetHub(worldId)
 local index = hub and table.find(hub.grounds, ground.id)
 assert(index, "Training ground " .. ground.id .. " is not in " .. tostring(worldId) .. "'s hub")
 return Training.Row.first + Training.Row.step * (index - 1)
end

function Training.GetPlateYaw()
 return Training.Row.yaw
end

-- Rebirth grounds only; paid grounds are never unlocked by Rebirths.
function Training.IsUnlocked(id, rebirths, worlds)
 local ground = Training.Get(id)
 return ground ~= nil and not Training.IsPaid(ground) and rebirths >= ground.requiredRebirths
  and Training.IsReachable(ground, worlds)
end

-- passes is the server's set of owned game passes, by pass ground id ({[id] = true}).
function Training.CanUse(id, rebirths, passes, worlds)
 local ground = Training.Get(id)
 if not ground or not Training.IsReachable(ground, worlds) then return false end
 if Training.IsPaid(ground) then
  local pass = Training.GetPassGround(ground)
  return pass.gamePassId > 0 and passes ~= nil and passes[pass.id] == true
 end
 return rebirths >= ground.requiredRebirths
end

-- The usable ground with the highest Power rate in any unlocked World (offline Training and
-- the quick teleport), and the World it is best in (Dragon's Lair's multiplier depends on it).
-- Returns ground, worldId.
function Training.GetBestGround(rebirths, passes, worlds)
 local best = Training.Get(Training.DefaultGround)
 local bestWorld = best.worlds[1]
 local bestRate = Training.GetMultiplier(best, bestWorld) / best.interval
 for _, ground in Training.Grounds do
  if Training.CanUse(ground.id, rebirths, passes, worlds) then
   for _, worldId in ground.worlds do
    local reachable = worlds and worlds[worldId] or not worlds and worldId == Training.Hubs[1].world
    local rate = Training.GetMultiplier(ground, worldId) / ground.interval
    if reachable and rate > bestRate then
     best, bestWorld, bestRate = ground, worldId, rate
    end
   end
  end
 end
 return best, bestWorld
end

-- Offline base Power for the time away (before Ball and Rebirth, and before the run cap below):
-- trainingBase is the Training base (ProgressionConfig.TrainingBase, the same at every Level);
-- worldId is the World the ground is used in (GetBestGround's second result).
function Training.GetOfflineReward(timestamp, now, groundId, trainingBase, worldId)
 local ground = Training.Get(groundId)
 if not Training.OfflineTrainingEnabled or not ground or type(timestamp) ~= "number"
  or timestamp ~= timestamp or timestamp <= 0 or timestamp % 1 ~= 0 or timestamp > now
  or type(trainingBase) ~= "number" or trainingBase ~= trainingBase or trainingBase < 0 or trainingBase == math.huge then
  return 0, 0
 end
 local seconds = math.min(now - timestamp, Training.MaximumOfflineSeconds)
 return math.floor(seconds * trainingBase * Training.GetMultiplier(ground, worldId) / ground.interval
  * Training.OfflinePowerRateMultiplier), seconds
end

-- The run cap, on whole Power after every multiplier. remaining is the Power the player needed for
-- their Level Cap at login (ProgressionConfig.GetPowerToLevelCap); a login grants at most this.
function Training.GetOfflinePowerLimit(remaining)
 return math.floor(remaining * Training.OfflineRunShare)
end

-- What Welcome Back's 3x claim adds to a login's offline Power: that Power twice more, up to
-- OfflineTriple.runShare of remaining in all.
function Training.GetOfflineTripleExtra(power, remaining)
 local triple = Training.OfflineTriple
 return math.max(0, math.min(power * (triple.multiplier - 1), math.floor(remaining * triple.runShare) - power))
end

return Training
