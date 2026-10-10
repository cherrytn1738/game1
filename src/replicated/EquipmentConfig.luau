-- Stable IDs are persisted; prices, stats, and primitive appearances are configured here.
-- Add an item and link the previous item through nextId to extend a progression.
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
     nextId = "alloy_bat",
     modelPath = "StarterPack.Bat",
     appearance = {BatBody = {color = Color3.fromRGB(195, 205, 220), material = Enum.Material.Metal}, BatGrip = {color = Color3.fromRGB(35, 40, 50), material = Enum.Material.SmoothPlastic}, BatKnob = {color = Color3.fromRGB(35, 40, 50), material = Enum.Material.SmoothPlastic}},
    },
    alloy_bat = {
     id = "alloy_bat", displayName = "Alloy Bat", price = 900,
     powerGainMultiplier = 2, -- Placeholder Power gain balance.
     nextId = "carbon_bat",
     modelPath = "StarterPack.Bat",
     appearance = {BatBody = {color = Color3.fromRGB(200, 45, 45), material = Enum.Material.Metal}, BatGrip = {color = Color3.fromRGB(30, 30, 35), material = Enum.Material.SmoothPlastic}, BatKnob = {color = Color3.fromRGB(30, 30, 35), material = Enum.Material.SmoothPlastic}},
    },
    carbon_bat = {
     id = "carbon_bat", displayName = "Carbon Bat", price = 2000,
     powerGainMultiplier = 2.5, -- Placeholder Power gain balance.
     modelPath = "StarterPack.Bat",
     appearance = {BatBody = {color = Color3.fromRGB(30, 35, 45), material = Enum.Material.Slate}, BatGrip = {color = Color3.fromRGB(240, 180, 50), material = Enum.Material.Metal}, BatKnob = {color = Color3.fromRGB(240, 180, 50), material = Enum.Material.Metal}},
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
     id = "practice_ball", displayName = "Practice Ball", price = 250,
     rewardMultiplier = 1.3,
     nextId = "all_star_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(245, 100, 35), material = Enum.Material.SmoothPlastic},
    },
    all_star_ball = {
     id = "all_star_ball", displayName = "All-Star Ball", price = 800,
     rewardMultiplier = 1.7,
     nextId = "championship_ball",
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(45, 130, 245), material = Enum.Material.SmoothPlastic},
    },
    championship_ball = {
     id = "championship_ball", displayName = "Championship Ball", price = 1800,
     rewardMultiplier = 2.2,
     modelPath = "Workspace.BattingArea.Baseball",
     appearance = {color = Color3.fromRGB(245, 195, 55), material = Enum.Material.Metal},
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
