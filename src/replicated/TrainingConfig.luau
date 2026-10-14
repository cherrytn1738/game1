-- Six physical Training Grounds stand in a row at the back of World1Hub, each its own
-- batting cage and plate. Rebirth grounds unlock by Rebirth count; paid grounds are Roblox
-- game passes (gamePassId 0 = not created yet, so the ground cannot be bought or used).
--   powerMultiplier: Power per tick = BasePowerPerTick * powerMultiplier
--   theme: the cage template in ServerStorage.RunwayAssets (fantasy cages are styled by
--     TrainingCageStyles), turf/lane colors and materials, banner color, and for the standard
--     cage its role colors (accent, frame, net) and floodlights; decorations are
--     {slot = "<Attachment in Cage.DecorSlots>", template = "<Model in RunwayAssets>"}
local M = Enum.Material
local Training = {
 DefaultGround = "basic_training",
 BasePowerPerTick = 20,
 Grounds = {
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
  {id = "dragons_lair", displayName = "Dragon's Lair", gamePassId = 0, robuxPrice = 500, powerMultiplier = 10, interval = 2,
   theme = {template = "DragonLairCage", turf = Color3.fromRGB(34, 28, 30), turfMaterial = M.Basalt,
    lane = Color3.fromRGB(214, 168, 50), laneMaterial = M.Metal,
    accent = Color3.fromRGB(255, 96, 20), frame = Color3.fromRGB(26, 24, 26), net = Color3.fromRGB(60, 50, 46),
    banner = Color3.fromRGB(150, 24, 20), lights = true, decorations = {}}},
  {id = "cosmic_rift", displayName = "Cosmic Rift", gamePassId = 0, robuxPrice = 1000, powerMultiplier = 30, interval = 2,
   theme = {template = "CosmicRiftCage", turf = Color3.fromRGB(22, 14, 46), turfMaterial = M.SmoothPlastic,
    lane = Color3.fromRGB(90, 220, 255), laneMaterial = M.Neon,
    accent = Color3.fromRGB(90, 220, 255), frame = Color3.fromRGB(150, 156, 180), net = Color3.fromRGB(120, 80, 220),
    banner = Color3.fromRGB(50, 24, 110), lights = true, decorations = {}}},
 },
 -- Batting cage footprint in training-plate space (studs): batter faces +X, the machine is
 -- at -Z, and the door is in the batter-end net (z = back). The room behind the batter keeps
 -- the camera inside. The model* sizes are what tools/blender/*_cage.py models; in game every
 -- cage is narrowed to widthScale about the pitch line (x = widthCenter), so left/right and
 -- the door are derived below.
 Cage = {modelLeft = -16, modelRight = 14, back = 14, front = -34, height = 14,
  modelDoorLeft = -13, modelDoorRight = -7, doorHeight = 8, templateScale = 4,
  widthScale = 0.85, widthCenter = 3},
 -- Two rows of three run parallel to the runway, relative to the hub's batting-edge frame
 -- (+Z is back into the hub; right means right when facing down the runway, +X). Cages turn
 -- a quarter turn so their doors face the walkway between the rows; the first ground of each
 -- row is nearest the runway. The models need 44 studs apiece (14-stud gaps for outside
 -- decorations), narrowed with the cages.
 Rows = {
  {grounds = {1, 2, 3}, first = Vector3.new(42, 0, 35), step = Vector3.new(0, 0, 44 * 0.85), yaw = -math.pi / 2},
  {grounds = {4, 5, 6}, first = Vector3.new(-42, 0, 35), step = Vector3.new(0, 0, 44 * 0.85), yaw = math.pi / 2},
 },
 OfflineTrainingEnabled = true,
 MaximumOfflineSeconds = 8 * 60 * 60,
 OfflinePowerRateMultiplier = 0.25,
 OfflineNoticeMinimumSeconds = 60,
 PlateSize = Vector3.new(5, 0.1, 5),
 PitchOffset = Vector3.new(3, 3, -24),
 ContactOffset = Vector3.new(3, 3, 0),
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

for index, ground in Training.Grounds do
 ground.order = index
 ground.basePower = Training.BasePowerPerTick * ground.powerMultiplier
end

function Training.Get(id)
 for _, ground in Training.Grounds do if ground.id == id then return ground end end
 return nil
end

function Training.IsPaid(ground)
 return ground ~= nil and ground.gamePassId ~= nil
end

local function placement(ground)
 for _, row in Training.Rows do
  local index = table.find(row.grounds, ground.order)
  if index then return row, index end
 end
 error("Training ground " .. ground.id .. " is in no row")
end

-- Hub-relative plate position and facing (yaw) of a ground.
function Training.GetPlatePosition(ground)
 local row, index = placement(ground)
 return row.first + row.step * (index - 1)
end

function Training.GetPlateYaw(ground)
 return (placement(ground).yaw)
end

-- Rebirth grounds only; paid grounds are never unlocked by Rebirths.
function Training.IsUnlocked(id, rebirths)
 local ground = Training.Get(id)
 return ground ~= nil and not Training.IsPaid(ground) and rebirths >= ground.requiredRebirths
end

-- passes is the server's set of owned paid ground ids ({[id] = true}).
function Training.CanUse(id, rebirths, passes)
 local ground = Training.Get(id)
 if not ground then return false end
 if Training.IsPaid(ground) then return ground.gamePassId > 0 and passes ~= nil and passes[id] == true end
 return rebirths >= ground.requiredRebirths
end

-- The usable ground with the highest Power rate (offline Training and the quick teleport).
function Training.GetBestGround(rebirths, passes)
 local best = Training.Get(Training.DefaultGround)
 for _, ground in Training.Grounds do
  if Training.CanUse(ground.id, rebirths, passes) and ground.basePower / ground.interval > best.basePower / best.interval then
   best = ground
  end
 end
 return best
end

function Training.GetOfflineReward(timestamp, now, groundId)
 local ground = Training.Get(groundId)
 if not Training.OfflineTrainingEnabled or not ground or type(timestamp) ~= "number"
  or timestamp ~= timestamp or timestamp <= 0 or timestamp % 1 ~= 0 or timestamp > now then
  return 0, 0
 end
 local seconds = math.min(now - timestamp, Training.MaximumOfflineSeconds)
 return math.floor(seconds * ground.basePower / ground.interval * Training.OfflinePowerRateMultiplier), seconds
end

return Training
