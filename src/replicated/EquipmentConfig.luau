-- Stable IDs are persisted; prices, stats, and primitive appearances are configured here.
-- Add an item and link the previous item through nextId to extend a progression.
-- Roles: a Ball's powerGainMultiplier multiplies Power gained (Training, real hits, offline
-- Training); a Bat's cashMultiplier multiplies the Cash a real hit earns. Neither changes
-- launch strength or distance, which come from Level (and the World batted in).
-- Fallback Bat colours for the three parts of the plain bat (body, grip, knob).
local function batLook(body, grip, bodyMaterial)
 return {BatBody = {color = body, material = bodyMaterial}, BatGrip = {color = grip, material = Enum.Material.SmoothPlastic},
  BatKnob = {color = grip, material = Enum.Material.SmoothPlastic}}
end
local Equipment = {
 CategoryOrder = {"Bat", "Ball"},
 Categories = {
  Bat = {
   displayName = "Bats", ownedField = "OwnedBats",
   startingId = "wood_bat",
   -- Each Bat earns about 1.5x the Cash of the one before, priced at several minutes of batting
   -- with that one (tuned with tools/balance; see .vscode/ECONOMY.md).
   items = {
    wood_bat = {
     id = "wood_bat", displayName = "Wood Bat", price = 0,
     cashMultiplier = 1,
     nextId = "metal_bat",
     modelPath = "StarterPack.Bat",
     appearance = {BatBody = {color = Color3.fromRGB(160, 110, 60), material = Enum.Material.Wood}, BatGrip = {color = Color3.fromRGB(160, 110, 60), material = Enum.Material.Wood}, BatKnob = {color = Color3.fromRGB(160, 110, 60), material = Enum.Material.Wood}},
    },
    metal_bat = {
     id = "metal_bat", displayName = "Metal Bat", price = 25,
     cashMultiplier = 1.5,
     nextId = "jungle_bat",
     modelPath = "StarterPack.Bat",
     appearance = {BatBody = {color = Color3.fromRGB(195, 205, 220), material = Enum.Material.Metal}, BatGrip = {color = Color3.fromRGB(35, 40, 50), material = Enum.Material.SmoothPlastic}, BatKnob = {color = Color3.fromRGB(35, 40, 50), material = Enum.Material.SmoothPlastic}},
    },
    -- The designed models (tools/blender/bats.py, styled by BatStyles) replace these
    -- fallback colours on the bat in hand.
    jungle_bat = {
     id = "jungle_bat", displayName = "Jungle Bat", price = 120,
     cashMultiplier = 2, nextId = "amethyst_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(190, 170, 90), Color3.fromRGB(120, 85, 45), Enum.Material.Wood),
    },
    amethyst_bat = {
     id = "amethyst_bat", displayName = "Amethyst Bat", price = 600,
     cashMultiplier = 3, nextId = "candy_cane_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(160, 90, 235), Color3.fromRGB(200, 205, 215), Enum.Material.Glass),
    },
    candy_cane_bat = {
     id = "candy_cane_bat", displayName = "Candy Cane Bat", price = 3000,
     cashMultiplier = 4, nextId = "frostbite_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(245, 245, 245), Color3.fromRGB(210, 35, 45), Enum.Material.SmoothPlastic),
    },
    frostbite_bat = {
     id = "frostbite_bat", displayName = "Frostbite Bat", price = 15000,
     cashMultiplier = 6, nextId = "magma_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(150, 215, 255), Color3.fromRGB(230, 245, 255), Enum.Material.Ice),
    },
    magma_bat = {
     id = "magma_bat", displayName = "Magma Bat", price = 50000,
     cashMultiplier = 9, nextId = "lightning_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(40, 30, 30), Color3.fromRGB(255, 110, 25), Enum.Material.Basalt),
    },
    lightning_bat = {
     id = "lightning_bat", displayName = "Lightning Bat", price = 3200000,
     cashMultiplier = 13, nextId = "dragon_bone_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(95, 45, 165), Color3.fromRGB(255, 235, 70), Enum.Material.SmoothPlastic),
    },
    dragon_bone_bat = {
     id = "dragon_bone_bat", displayName = "Dragon Bone Bat", price = 28000000,
     cashMultiplier = 19, nextId = "celestial_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(230, 220, 190), Color3.fromRGB(120, 20, 20), Enum.Material.SmoothPlastic),
    },
    celestial_bat = {
     id = "celestial_bat", displayName = "Celestial Bat", price = 100000000,
     cashMultiplier = 28, nextId = "rolling_pin_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(25, 18, 70), Color3.fromRGB(255, 205, 80), Enum.Material.SmoothPlastic),
    },
    -- World 4's Bat (Tiny Town): priced so it is bought midway through World 4. Its model is
    -- tools/blender/bats_world4.py (BatStyles); appearance is the stand-in until it is imported.
    rolling_pin_bat = {
     id = "rolling_pin_bat", displayName = "Rolling Pin Bat", price = 1650000000,
     cashMultiplier = 42,
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(222, 184, 135), Color3.fromRGB(200, 60, 60), Enum.Material.Wood),
    },
    -- Exclusive: only from the Starter Pack (MonetizationConfig.StarterPack), never sold for
    -- Cash. A side-grade between the Jungle and Amethyst Bats. Its model is built from Parts
    -- (server CatBatModel).
    catastrophe_bat = {
     id = "catastrophe_bat", displayName = "Catastrophe Bat", price = 0,
     cashMultiplier = 2.5,
     modelPath = "StarterPack.Bat",
     source = "Starter Pack", effectTier = .35,
     appearance = batLook(Color3.fromRGB(250, 240, 225), Color3.fromRGB(70, 35, 110), Enum.Material.SmoothPlastic),
    },
   },
   -- Items outside every purchase series (granted, never bought), listed after the series.
   exclusives = {"catastrophe_bat"},
  },
  Ball = {
   displayName = "Balls", ownedField = "OwnedBalls",
   startingId = "baseball",
   -- Further series sold in order from their own first item, alongside the main series
   -- (startingId). A series with requiredWorld can only be bought once that World is unlocked.
   series = {
    {id = "world_2", startingId = "dino_egg_ball", requiredWorld = "world_2"},
    {id = "world_3", startingId = "solar_cell_ball", requiredWorld = "world_3"},
    {id = "world_4", startingId = "dandelion_puff_ball", requiredWorld = "world_4"},
   },
   items = {
    -- World 1's series: intended Power balance. The Sandlot Ball's $2 is the tutorial's first
    -- purchase (two early hits earn it).
    baseball = {
     id = "baseball", displayName = "Baseball", price = 0,
     powerGainMultiplier = 1,
     nextId = "practice_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(255, 255, 255), material = Enum.Material.Plastic},
    },
    practice_ball = {
     id = "practice_ball", displayName = "Sandlot Ball", price = 2,
     powerGainMultiplier = 3,
     nextId = "bubblegum_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(210, 175, 125), material = Enum.Material.SmoothPlastic},
    },
    -- Glossy pink candy shell with sprinkles (placeholder colour until its model is designed).
    bubblegum_ball = {
     id = "bubblegum_ball", displayName = "Bubblegum Ball", price = 10,
     powerGainMultiplier = 5,
     nextId = "crystal_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(255, 120, 190), material = Enum.Material.SmoothPlastic},
    },
    -- Faceted purple amethyst with silver stitches.
    crystal_ball = {
     id = "crystal_ball", displayName = "Crystal Ball", price = 40,
     powerGainMultiplier = 12,
     nextId = "frost_comet",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(160, 90, 235), material = Enum.Material.Glass},
    },
    frost_comet = {
     id = "frost_comet", displayName = "Frost Comet", price = 150,
     powerGainMultiplier = 30, nextId = "inferno_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(150, 215, 255), material = Enum.Material.SmoothPlastic},
    },
    inferno_ball = {
     id = "inferno_ball", displayName = "Inferno Ball", price = 500,
     powerGainMultiplier = 75, nextId = "thunder_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(40, 30, 30), material = Enum.Material.SmoothPlastic},
    },
    thunder_ball = {
     id = "thunder_ball", displayName = "Thunder Ball", price = 1500,
     powerGainMultiplier = 200, nextId = "galaxy_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(95, 45, 165), material = Enum.Material.SmoothPlastic},
    },
    galaxy_ball = {
     id = "galaxy_ball", displayName = "Galaxy Ball", price = 4500,
     powerGainMultiplier = 500, nextId = "dragonfire_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(25, 18, 70), material = Enum.Material.SmoothPlastic},
    },
    dragonfire_ball = {
     id = "dragonfire_ball", displayName = "Dragonfire Ball", price = 14000,
     powerGainMultiplier = 1250, nextId = "supernova_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(130, 20, 20), material = Enum.Material.SmoothPlastic},
    },
    supernova_ball = {
     id = "supernova_ball", displayName = "Supernova Ball", price = 40000,
     powerGainMultiplier = 3500,
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(255, 240, 190), material = Enum.Material.SmoothPlastic},
    },
    -- World 2 (Time Travel) series, one ball per era (see series below). Each ball beats the one
    -- before and the whole series beats World 1's; prices follow World 2's Cash (WorldConfig).
    dino_egg_ball = {
     id = "dino_egg_ball", displayName = "Dino Egg", price = 175000,
     powerGainMultiplier = 5000, nextId = "stone_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(240, 230, 200), material = Enum.Material.SmoothPlastic},
    },
    stone_ball = {
     id = "stone_ball", displayName = "Stone Ball", price = 220000,
     powerGainMultiplier = 7500, nextId = "scarab_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(140, 136, 130), material = Enum.Material.Slate},
    },
    scarab_ball = {
     id = "scarab_ball", displayName = "Scarab Ball", price = 350000,
     powerGainMultiplier = 11000, nextId = "laurel_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(40, 70, 170), material = Enum.Material.SmoothPlastic},
    },
    laurel_ball = {
     id = "laurel_ball", displayName = "Olympian Laurel", price = 440000,
     powerGainMultiplier = 17000, nextId = "viking_rune_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(242, 240, 232), material = Enum.Material.Marble},
    },
    viking_rune_ball = {
     id = "viking_rune_ball", displayName = "Viking Rune", price = 490000,
     powerGainMultiplier = 25000, nextId = "samurai_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(60, 62, 70), material = Enum.Material.Metal},
    },
    samurai_ball = {
     id = "samurai_ball", displayName = "Samurai Ball", price = 630000,
     powerGainMultiplier = 38000, nextId = "knight_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(196, 32, 36), material = Enum.Material.SmoothPlastic},
    },
    knight_ball = {
     id = "knight_ball", displayName = "Knight's Ball", price = 960000,
     powerGainMultiplier = 57000, nextId = "sheriff_star_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(200, 206, 216), material = Enum.Material.Metal},
    },
    sheriff_star_ball = {
     id = "sheriff_star_ball", displayName = "Sheriff Star", price = 1150000,
     powerGainMultiplier = 85000, nextId = "clockwork_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(196, 150, 96), material = Enum.Material.Leather},
    },
    clockwork_ball = {
     id = "clockwork_ball", displayName = "Clockwork Ball", price = 1350000,
     powerGainMultiplier = 130000, nextId = "chrono_orb",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(222, 170, 76), material = Enum.Material.Metal},
    },
    chrono_orb = {
     id = "chrono_orb", displayName = "Chrono Orb", price = 2100000,
     powerGainMultiplier = 200000,
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(90, 230, 255), material = Enum.Material.Neon},
    },
    -- World 3 (Future World) series, one ball per runway section. Each ball beats the one before
    -- and the whole series beats World 2's; prices follow World 3's Cash and stay far below
    -- PlayerData's Cash cap.
    solar_cell_ball = {
     id = "solar_cell_ball", displayName = "Solar Cell", price = 15000000,
     powerGainMultiplier = 300000, nextId = "hover_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(255, 196, 64), material = Enum.Material.Foil},
    },
    hover_ball = {
     id = "hover_ball", displayName = "Hover Ball", price = 16500000,
     powerGainMultiplier = 450000, nextId = "hologram_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(200, 208, 220), material = Enum.Material.Metal},
    },
    hologram_ball = {
     id = "hologram_ball", displayName = "Hologram Ball", price = 22000000,
     powerGainMultiplier = 675000, nextId = "robo_core_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(110, 220, 255), material = Enum.Material.Glass},
    },
    robo_core_ball = {
     id = "robo_core_ball", displayName = "Robo Core", price = 24500000,
     powerGainMultiplier = 1000000, nextId = "bio_seed_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(150, 158, 170), material = Enum.Material.Metal},
    },
    bio_seed_ball = {
     id = "bio_seed_ball", displayName = "Bio Seed", price = 29000000,
     powerGainMultiplier = 1500000, nextId = "pixel_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(150, 240, 170), material = Enum.Material.Glass},
    },
    pixel_ball = {
     id = "pixel_ball", displayName = "Pixel Ball", price = 34000000,
     powerGainMultiplier = 2250000, nextId = "rocket_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(80, 255, 170), material = Enum.Material.SmoothPlastic},
    },
    rocket_ball = {
     id = "rocket_ball", displayName = "Rocket Ball", price = 45000000,
     powerGainMultiplier = 3400000, nextId = "moon_rock_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(245, 245, 250), material = Enum.Material.SmoothPlastic},
    },
    moon_rock_ball = {
     id = "moon_rock_ball", displayName = "Moon Rock", price = 56000000,
     powerGainMultiplier = 5000000, nextId = "red_planet_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(160, 160, 168), material = Enum.Material.Slate},
    },
    red_planet_ball = {
     id = "red_planet_ball", displayName = "Red Planet", price = 76000000,
     powerGainMultiplier = 7500000, nextId = "singularity_orb",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(196, 86, 48), material = Enum.Material.Sand},
    },
    singularity_orb = {
     id = "singularity_orb", displayName = "Singularity Orb", price = 97000000,
     powerGainMultiplier = 11000000,
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(20, 16, 30), material = Enum.Material.Neon},
    },
    -- World 4 (Tiny Town) series, one ball per runway section. Each ball beats the one before
    -- and the whole series beats World 3's. Prices rise about 1.1x a step, with the Rolling Pin Bat
    -- bought midway through World 4 (tools/balance).
    -- Placeholder colours until their models are made (WORLD4_DESIGN.md, Phase 4).
    dandelion_puff_ball = {
     id = "dandelion_puff_ball", displayName = "Dandelion Puff", price = 530000000,
     powerGainMultiplier = 16000000, nextId = "blueberry_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(250, 250, 240), material = Enum.Material.Fabric},
    },
    blueberry_ball = {
     id = "blueberry_ball", displayName = "Blueberry", price = 1100000000,
     powerGainMultiplier = 24000000, nextId = "meatball_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(70, 80, 170), material = Enum.Material.SmoothPlastic},
    },
    meatball_ball = {
     id = "meatball_ball", displayName = "Meatball", price = 1200000000,
     powerGainMultiplier = 36000000, nextId = "bouncy_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(130, 70, 50), material = Enum.Material.Pebble},
    },
    bouncy_ball = {
     id = "bouncy_ball", displayName = "Bouncy Ball", price = 1350000000,
     powerGainMultiplier = 54000000, nextId = "lucky_dice_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(255, 90, 160), material = Enum.Material.SmoothPlastic},
    },
    lucky_dice_ball = {
     id = "lucky_dice_ball", displayName = "Lucky Dice", price = 1500000000,
     powerGainMultiplier = 80000000, nextId = "yarn_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(245, 245, 245), material = Enum.Material.SmoothPlastic},
    },
    yarn_ball = {
     id = "yarn_ball", displayName = "Yarn Ball", price = 1900000000,
     powerGainMultiplier = 120000000, nextId = "bath_bomb_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(236, 90, 110), material = Enum.Material.Fabric},
    },
    bath_bomb_ball = {
     id = "bath_bomb_ball", displayName = "Bath Bomb", price = 2100000000,
     powerGainMultiplier = 180000000, nextId = "mini_globe_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(190, 140, 255), material = Enum.Material.Sand},
    },
    mini_globe_ball = {
     id = "mini_globe_ball", displayName = "Mini Globe", price = 2300000000,
     powerGainMultiplier = 270000000, nextId = "cats_eye_marble",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(60, 140, 220), material = Enum.Material.SmoothPlastic},
    },
    cats_eye_marble = {
     id = "cats_eye_marble", displayName = "Cat's-Eye Marble", price = 2550000000,
     powerGainMultiplier = 400000000, nextId = "dream_orb",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(150, 230, 210), material = Enum.Material.Glass},
    },
    dream_orb = {
     id = "dream_orb", displayName = "Dream Orb", price = 2800000000,
     powerGainMultiplier = 600000000,
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(255, 226, 150), material = Enum.Material.Neon},
    },
   },
  },

 },
}

-- Derive catalog order from the existing nextId links in one place: the main series from
-- startingId, then each further series. item.series is the series id (nil for the main one).
local byId = {}
local ordered = {}
local seriesLists, seriesItems = {}, {}
for _, category in Equipment.CategoryOrder do
 local definition = Equipment.Categories[category]
 local items = {}
 seriesLists[category] = {{startingId = definition.startingId}}
 for _, series in definition.series or {} do table.insert(seriesLists[category], series) end
 seriesItems[category] = {}
 for _, series in seriesLists[category] do
  local chain = {}
  local id = series.startingId
  while id do
   local item = definition.items[id]
   assert(item and item.id == id and not byId[id], "Invalid or repeated equipment ID: " .. id)
   assert(type(item.price) == "number" and item.price >= 0 and item.price < math.huge
    and item.price % 1 == 0, "Invalid equipment price: " .. id)
   -- Each category carries only its own role's multiplier (Bat: Cash, Ball: Power).
   local field, other = "cashMultiplier", "powerGainMultiplier"
   if category == "Ball" then field, other = "powerGainMultiplier", "cashMultiplier" end
   assert(type(item[field]) == "number" and item[field] >= 1 and item[field] < math.huge,
    "Invalid " .. category .. " " .. field .. ": " .. id)
   assert(item[other] == nil and item.rewardMultiplier == nil, "Wrong multiplier field on " .. category .. ": " .. id)
   item.category, item.order, item.series = category, #items + 1, series.id
   byId[id] = item
   table.insert(items, item)
   table.insert(chain, item)
   id = item.nextId
  end
  seriesItems[category][series.id or ""] = chain
 end
 -- Exclusive items: owned and equipped like the rest, but in no series, so never for sale.
 for _, id in definition.exclusives or {} do
  local item = definition.items[id]
  assert(item and item.id == id and not byId[id] and item.nextId == nil, "Invalid exclusive equipment: " .. id)
  local field = category == "Ball" and "powerGainMultiplier" or "cashMultiplier"
  local other = category == "Ball" and "cashMultiplier" or "powerGainMultiplier"
  assert(type(item[field]) == "number" and item[field] >= 1 and item[field] < math.huge and item[other] == nil,
   "Invalid exclusive " .. category .. " multiplier: " .. id)
  item.category, item.order, item.exclusive = category, #items + 1, true
  byId[id] = item
  table.insert(items, item)
 end
 for itemId in definition.items do
  assert(byId[itemId] and byId[itemId].category == category, "Unlinked equipment: " .. itemId)
 end
 ordered[category] = items
end

-- A category's purchase series: the main one (id nil) first, then definition.series.
function Equipment.GetSeries(category)
 return seriesLists[category] or {}
end

function Equipment.GetSeriesInfo(category, seriesId)
 for _, series in Equipment.GetSeries(category) do
  if series.id == seriesId then return series end
 end
 return nil
end

function Equipment.GetSeriesItems(category, seriesId)
 return seriesItems[category] and seriesItems[category][seriesId or ""] or {}
end

-- Each series has its own server-issued purchase offer, published as the player attribute
-- "EquipmentPurchaseToken_" .. OfferKey (the main series keeps the plain category key).
function Equipment.OfferKey(category, seriesId)
 return seriesId and category .. "_" .. seriesId or category
end

function Equipment.Get(category, id)
 if type(category) ~= "string" or (id ~= nil and type(id) ~= "string") then return nil end
 local definition = Equipment.Categories[category]
 if not definition then return nil end
 return definition.items[id or definition.startingId]
end

function Equipment.GetNext(category, currentId)
 local current = Equipment.Get(category, currentId)
 if not current or not current.nextId then return nil end
 return Equipment.Get(category, current.nextId)
end

function Equipment.GetById(id)
 return type(id) == "string" and byId[id] or nil
end

function Equipment.GetItems(category)
 return ordered[category] or {}
end

function Equipment.IsStarting(category, id)
 local definition = Equipment.Categories[category]
 return definition ~= nil and definition.startingId == id
end

function Equipment.IsFinal(category, id)
 local item = Equipment.Get(category, id)
 return item ~= nil and item.nextId == nil
end

-- The next item for sale in one series (the main series when seriesId is nil).
function Equipment.GetNextPurchase(category, owned, seriesId)
 -- Legacy saves can own the starting item and a later item without the items
 -- between them. Continue past their furthest owned item; equipping never moves it.
 local items = Equipment.GetSeriesItems(category, seriesId)
 local furthest
 for _, item in items do
  if owned[item.id] == true then furthest = item end
 end
 if furthest then return Equipment.GetNext(category, furthest.id) end
 -- A further series with nothing owned yet starts at its first item (the main series always
 -- owns its first).
 return seriesId and items[1] or nil
end

function Equipment.NormalizeOwnership(category, saved, equippedId, legacySave)
 local definition = Equipment.Categories[category]
 local owned = {}
 if type(saved) == "table" then
  for id, value in saved do
   if type(id) == "string" and value == true and Equipment.Get(category, id) then
    owned[id] = true
   end
  end
 end
 owned[definition.startingId] = true
 if type(equippedId) ~= "string" or not Equipment.Get(category, equippedId) then
  equippedId = definition.startingId
 end
 -- Only saves from before ownership existed may prove ownership by equipped ID.
 if legacySave then owned[equippedId] = true end
 if not owned[equippedId] then equippedId = definition.startingId end
 return owned, equippedId
end

return Equipment
