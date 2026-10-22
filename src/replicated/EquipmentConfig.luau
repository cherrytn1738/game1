-- Stable IDs are persisted; prices, stats, and primitive appearances are configured here.
-- Add an item and link the previous item through nextId to extend a progression.
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
   items = {
    wood_bat = {
     id = "wood_bat", displayName = "Wood Bat", price = 0,
     powerGainMultiplier = 1, -- Placeholder Power gain balance.
     nextId = "metal_bat",
     modelPath = "StarterPack.Bat",
     appearance = {BatBody = {color = Color3.fromRGB(160, 110, 60), material = Enum.Material.Wood}, BatGrip = {color = Color3.fromRGB(160, 110, 60), material = Enum.Material.Wood}, BatKnob = {color = Color3.fromRGB(160, 110, 60), material = Enum.Material.Wood}},
    },
    metal_bat = {
     id = "metal_bat", displayName = "Metal Bat", price = 300,
     powerGainMultiplier = 1.5, -- Placeholder Power gain balance.
     nextId = "jungle_bat",
     modelPath = "StarterPack.Bat",
     appearance = {BatBody = {color = Color3.fromRGB(195, 205, 220), material = Enum.Material.Metal}, BatGrip = {color = Color3.fromRGB(35, 40, 50), material = Enum.Material.SmoothPlastic}, BatKnob = {color = Color3.fromRGB(35, 40, 50), material = Enum.Material.SmoothPlastic}},
    },
    -- The designed models (tools/blender/bats.py, styled by BatStyles) replace these
    -- fallback colours on the bat in hand.
    jungle_bat = {
     id = "jungle_bat", displayName = "Jungle Bat", price = 900,
     powerGainMultiplier = 2, nextId = "amethyst_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(190, 170, 90), Color3.fromRGB(120, 85, 45), Enum.Material.Wood),
    },
    amethyst_bat = {
     id = "amethyst_bat", displayName = "Amethyst Bat", price = 2000,
     powerGainMultiplier = 2.5, nextId = "candy_cane_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(160, 90, 235), Color3.fromRGB(200, 205, 215), Enum.Material.Glass),
    },
    candy_cane_bat = {
     id = "candy_cane_bat", displayName = "Candy Cane Bat", price = 6000,
     powerGainMultiplier = 3.2, nextId = "frostbite_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(245, 245, 245), Color3.fromRGB(210, 35, 45), Enum.Material.SmoothPlastic),
    },
    frostbite_bat = {
     id = "frostbite_bat", displayName = "Frostbite Bat", price = 15000,
     powerGainMultiplier = 4, nextId = "magma_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(150, 215, 255), Color3.fromRGB(230, 245, 255), Enum.Material.Ice),
    },
    magma_bat = {
     id = "magma_bat", displayName = "Magma Bat", price = 40000,
     powerGainMultiplier = 5, nextId = "lightning_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(40, 30, 30), Color3.fromRGB(255, 110, 25), Enum.Material.Basalt),
    },
    lightning_bat = {
     id = "lightning_bat", displayName = "Lightning Bat", price = 100000,
     powerGainMultiplier = 6.5, nextId = "dragon_bone_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(95, 45, 165), Color3.fromRGB(255, 235, 70), Enum.Material.SmoothPlastic),
    },
    dragon_bone_bat = {
     id = "dragon_bone_bat", displayName = "Dragon Bone Bat", price = 250000,
     powerGainMultiplier = 8, nextId = "celestial_bat",
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(230, 220, 190), Color3.fromRGB(120, 20, 20), Enum.Material.SmoothPlastic),
    },
    celestial_bat = {
     id = "celestial_bat", displayName = "Celestial Bat", price = 600000,
     powerGainMultiplier = 10,
     modelPath = "StarterPack.Bat",
     appearance = batLook(Color3.fromRGB(25, 18, 70), Color3.fromRGB(255, 205, 80), Enum.Material.SmoothPlastic),
    },
   },
  },
  Ball = {
   displayName = "Balls", ownedField = "OwnedBalls",
   startingId = "baseball",
   -- Further series sold in order from their own first item, alongside the main series
   -- (startingId). A series with requiredWorld can only be bought once that World is unlocked.
   series = {
    {id = "world_2", startingId = "dino_egg_ball", requiredWorld = "world_2"},
   },
   items = {
    baseball = {
     id = "baseball", displayName = "Baseball", price = 0,
     rewardMultiplier = 1,
     nextId = "practice_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(255, 255, 255), material = Enum.Material.Plastic},
    },
    practice_ball = {
     id = "practice_ball", displayName = "Sandlot Ball", price = 250,
     rewardMultiplier = 1.3,
     nextId = "bubblegum_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(210, 175, 125), material = Enum.Material.SmoothPlastic},
    },
    -- Glossy pink candy shell with sprinkles (placeholder colour until its model is designed).
    bubblegum_ball = {
     id = "bubblegum_ball", displayName = "Bubblegum Ball", price = 800,
     rewardMultiplier = 1.7,
     nextId = "crystal_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(255, 120, 190), material = Enum.Material.SmoothPlastic},
    },
    -- Faceted purple amethyst with silver stitches.
    crystal_ball = {
     id = "crystal_ball", displayName = "Crystal Ball", price = 1800,
     rewardMultiplier = 2.2,
     nextId = "frost_comet",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(160, 90, 235), material = Enum.Material.Glass},
    },
    frost_comet = {
     id = "frost_comet", displayName = "Frost Comet", price = 5000,
     rewardMultiplier = 2.8, nextId = "inferno_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(150, 215, 255), material = Enum.Material.SmoothPlastic},
    },
    inferno_ball = {
     id = "inferno_ball", displayName = "Inferno Ball", price = 12000,
     rewardMultiplier = 3.5, nextId = "thunder_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(40, 30, 30), material = Enum.Material.SmoothPlastic},
    },
    thunder_ball = {
     id = "thunder_ball", displayName = "Thunder Ball", price = 30000,
     rewardMultiplier = 4.5, nextId = "galaxy_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(95, 45, 165), material = Enum.Material.SmoothPlastic},
    },
    galaxy_ball = {
     id = "galaxy_ball", displayName = "Galaxy Ball", price = 75000,
     rewardMultiplier = 6, nextId = "dragonfire_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(25, 18, 70), material = Enum.Material.SmoothPlastic},
    },
    dragonfire_ball = {
     id = "dragonfire_ball", displayName = "Dragonfire Ball", price = 180000,
     rewardMultiplier = 8, nextId = "supernova_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(130, 20, 20), material = Enum.Material.SmoothPlastic},
    },
    supernova_ball = {
     id = "supernova_ball", displayName = "Supernova Ball", price = 400000,
     rewardMultiplier = 10,
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(255, 240, 190), material = Enum.Material.SmoothPlastic},
    },
    -- World 2 (Time Travel) series, one ball per era (see series below). Placeholder balance.
    dino_egg_ball = {
     id = "dino_egg_ball", displayName = "Dino Egg", price = 1000000,
     rewardMultiplier = 12, nextId = "stone_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(240, 230, 200), material = Enum.Material.SmoothPlastic},
    },
    stone_ball = {
     id = "stone_ball", displayName = "Stone Ball", price = 2500000,
     rewardMultiplier = 15, nextId = "scarab_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(140, 136, 130), material = Enum.Material.Slate},
    },
    scarab_ball = {
     id = "scarab_ball", displayName = "Scarab Ball", price = 6000000,
     rewardMultiplier = 19, nextId = "laurel_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(40, 70, 170), material = Enum.Material.SmoothPlastic},
    },
    laurel_ball = {
     id = "laurel_ball", displayName = "Olympian Laurel", price = 14000000,
     rewardMultiplier = 24, nextId = "viking_rune_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(242, 240, 232), material = Enum.Material.Marble},
    },
    viking_rune_ball = {
     id = "viking_rune_ball", displayName = "Viking Rune", price = 32000000,
     rewardMultiplier = 30, nextId = "samurai_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(60, 62, 70), material = Enum.Material.Metal},
    },
    samurai_ball = {
     id = "samurai_ball", displayName = "Samurai Ball", price = 75000000,
     rewardMultiplier = 38, nextId = "knight_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(196, 32, 36), material = Enum.Material.SmoothPlastic},
    },
    knight_ball = {
     id = "knight_ball", displayName = "Knight's Ball", price = 170000000,
     rewardMultiplier = 48, nextId = "sheriff_star_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(200, 206, 216), material = Enum.Material.Metal},
    },
    sheriff_star_ball = {
     id = "sheriff_star_ball", displayName = "Sheriff Star", price = 400000000,
     rewardMultiplier = 60, nextId = "clockwork_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(196, 150, 96), material = Enum.Material.Leather},
    },
    clockwork_ball = {
     id = "clockwork_ball", displayName = "Clockwork Ball", price = 900000000,
     rewardMultiplier = 75, nextId = "chrono_orb",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(222, 170, 76), material = Enum.Material.Metal},
    },
    chrono_orb = {
     id = "chrono_orb", displayName = "Chrono Orb", price = 2000000000,
     rewardMultiplier = 95,
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(90, 230, 255), material = Enum.Material.Neon},
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
   if category == "Bat" then
    assert(type(item.powerGainMultiplier) == "number" and item.powerGainMultiplier >= 1
     and item.powerGainMultiplier < math.huge, "Invalid Bat Power multiplier: " .. id)
   end
   item.category, item.order, item.series = category, #items + 1, series.id
   byId[id] = item
   table.insert(items, item)
   table.insert(chain, item)
   id = item.nextId
  end
  seriesItems[category][series.id or ""] = chain
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
