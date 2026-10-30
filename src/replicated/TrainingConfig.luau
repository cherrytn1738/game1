-- Training Grounds are physical batting cages, each with its own plate, standing in a row in
-- a World's hub (Hubs below). Rebirth grounds unlock by Rebirth count; paid grounds are Roblox
-- game passes (gamePassId 0 = not created yet, so the ground cannot be bought or used). A
-- ground can only be used once a World it stands in is unlocked.
--   powerMultiplier: Power per practice hit = Training base (ProgressionConfig, by Level) x powerMultiplier
--   sharesPass: a paid ground opened by another ground's game pass (no pass of its own)
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
   theme = {template = "CosmicRiftCage", turf = Color3.fromRGB(22, 14, 46), turfMaterial = M.SmoothPlastic,
    lane = Color3.fromRGB(90, 220, 255), laneMaterial = M.Neon,
    accent = Color3.fromRGB(90, 220, 255), frame = Color3.fromRGB(150, 156, 180), net = Color3.fromRGB(120, 80, 220),
    banner = Color3.fromRGB(50, 24, 110), lights = true, decorations = {}}},
  -- World 2 (Time Travel). Its Rebirth tiers continue on from World 1's; the first cage is
  -- free once World 2 is unlocked. They use the standard cage in era colors for now.
  {id = "caveman_camp", displayName = "Caveman Camp", requiredRebirths = 0, powerMultiplier = 25, interval = 2,
   theme = {template = "TrainingCage", turf = Color3.fromRGB(150, 112, 74), turfMaterial = M.Ground,
    lane = Color3.fromRGB(214, 180, 104), laneMaterial = M.Fabric,
    accent = Color3.fromRGB(232, 222, 196), frame = Color3.fromRGB(112, 78, 48), net = Color3.fromRGB(86, 104, 52),
    banner = Color3.fromRGB(196, 104, 40), lights = false, decorations = {}}},
  {id = "pharaohs_tomb", displayName = "Pharaoh's Tomb", requiredRebirths = 8, powerMultiplier = 35, interval = 2,
   theme = {template = "TrainingCage", turf = Color3.fromRGB(230, 200, 136), turfMaterial = M.Sand,
    lane = Color3.fromRGB(214, 170, 92), laneMaterial = M.Sandstone,
    accent = Color3.fromRGB(240, 190, 50), frame = Color3.fromRGB(206, 170, 110), net = Color3.fromRGB(36, 70, 150),
    banner = Color3.fromRGB(30, 60, 140), lights = true, decorations = {}}},
  {id = "gladiator_colosseum", displayName = "Gladiator Colosseum", requiredRebirths = 10, powerMultiplier = 50, interval = 2,
   theme = {template = "TrainingCage", turf = Color3.fromRGB(214, 186, 140), turfMaterial = M.Sand,
    lane = Color3.fromRGB(184, 102, 70), laneMaterial = M.Brick,
    accent = Color3.fromRGB(180, 30, 36), frame = Color3.fromRGB(236, 230, 214), net = Color3.fromRGB(176, 120, 60),
    banner = Color3.fromRGB(150, 24, 30), lights = true, decorations = {}}},
  {id = "samurai_dojo", displayName = "Samurai Dojo", requiredRebirths = 12, powerMultiplier = 70, interval = 2,
   theme = {template = "TrainingCage", turf = Color3.fromRGB(196, 190, 132), turfMaterial = M.Fabric,
    lane = Color3.fromRGB(150, 104, 64), laneMaterial = M.WoodPlanks,
    accent = Color3.fromRGB(200, 36, 36), frame = Color3.fromRGB(34, 30, 32), net = Color3.fromRGB(46, 40, 40),
    banner = Color3.fromRGB(190, 30, 30), lights = true, decorations = {}}},
  {id = "time_machine_lab", displayName = "Time Machine Lab", sharesPass = "cosmic_rift", powerMultiplier = 35, interval = 2,
   theme = {template = "TrainingCage", turf = Color3.fromRGB(46, 50, 62), turfMaterial = M.DiamondPlate,
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
   theme = {template = "QuantumLabCage", turf = Color3.fromRGB(20, 22, 40), turfMaterial = M.SmoothPlastic,
    lane = Color3.fromRGB(120, 240, 255), laneMaterial = M.Neon,
    accent = Color3.fromRGB(120, 240, 255), frame = Color3.fromRGB(200, 206, 230), net = Color3.fromRGB(110, 80, 230),
    banner = Color3.fromRGB(58, 30, 140), lights = true, decorations = {}}},
  -- The most expensive ground; it stands in every World's hub.
  {id = "dragons_lair", displayName = "Dragon's Lair", gamePassId = 0, robuxPrice = 1000, powerMultiplier = 30, interval = 2,
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
 -- One return's offline Power is at most this share of the Power the player still needs for their
 -- Level Cap, so offline Training helps but never finishes a run by itself.
 OfflineRunShare = 0.5,
 OfflineNoticeMinimumSeconds = 60,
 -- Welcome Back's "3x" offer: a Robux developer product that adds the offline reward twice more
 -- (multiplier 3 in all), once per login, up to runShare of the Power the player needed for their
 -- Level Cap at login (all of it: the 3x can finish the run but never go past the cap).
 -- productId 0 = not created yet (the button shows SOON); robuxPrice is the price shown on the
 -- button (nil until decided).
 OfflineTriple = {productId = 0, robuxPrice = nil, multiplier = 3, runShare = 1},
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
 if ground.gamePassId ~= nil then table.insert(Training.PassGrounds, ground) end
end
for _, ground in Training.Grounds do
 local owner = ground.sharesPass and Training.Get(ground.sharesPass)
 assert(not ground.sharesPass or owner and owner.gamePassId ~= nil, ground.id .. " shares an unknown pass")
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
-- the quick teleport).
function Training.GetBestGround(rebirths, passes, worlds)
 local best = Training.Get(Training.DefaultGround)
 for _, ground in Training.Grounds do
  if Training.CanUse(ground.id, rebirths, passes, worlds) and ground.powerMultiplier / ground.interval > best.powerMultiplier / best.interval then
   best = ground
  end
 end
 return best
end

-- Offline base Power for the time away (before Ball and Rebirth, and before the run cap below):
-- trainingBase is the Training base (ProgressionConfig.TrainingBase, the same at every Level).
function Training.GetOfflineReward(timestamp, now, groundId, trainingBase)
 local ground = Training.Get(groundId)
 if not Training.OfflineTrainingEnabled or not ground or type(timestamp) ~= "number"
  or timestamp ~= timestamp or timestamp <= 0 or timestamp % 1 ~= 0 or timestamp > now
  or type(trainingBase) ~= "number" or trainingBase ~= trainingBase or trainingBase < 0 or trainingBase == math.huge then
  return 0, 0
 end
 local seconds = math.min(now - timestamp, Training.MaximumOfflineSeconds)
 return math.floor(seconds * trainingBase * ground.powerMultiplier / ground.interval * Training.OfflinePowerRateMultiplier), seconds
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
