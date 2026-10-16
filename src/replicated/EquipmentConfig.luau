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
   },
  },

 },
}

-- Derive catalog order from the existing nextId links in one place.
local byId = {}
local ordered = {}
for _, category in Equipment.CategoryOrder do
 local definition = Equipment.Categories[category]
 local items = {}
 local id = definition.startingId
 while id do
  local item = definition.items[id]
  assert(item and item.id == id and not byId[id], "Invalid or repeated equipment ID: " .. id)
  assert(type(item.price) == "number" and item.price >= 0 and item.price < math.huge
   and item.price % 1 == 0, "Invalid equipment price: " .. id)
  if category == "Bat" then
   assert(type(item.powerGainMultiplier) == "number" and item.powerGainMultiplier >= 1
    and item.powerGainMultiplier < math.huge, "Invalid Bat Power multiplier: " .. id)
  end
  item.category, item.order = category, #items + 1
  byId[id] = item
  table.insert(items, item)
  id = item.nextId
 end
 for itemId in definition.items do
  assert(byId[itemId] and byId[itemId].category == category, "Unlinked equipment: " .. itemId)
 end
 ordered[category] = items
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

function Equipment.GetNextPurchase(category, owned)
 -- Legacy saves can own the starting item and a later item without the items
 -- between them. Continue past their furthest owned item; equipping never moves it.
 local furthest
 for _, item in Equipment.GetItems(category) do
  if owned[item.id] == true then furthest = item end
 end
 return furthest and Equipment.GetNext(category, furthest.id) or nil
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
