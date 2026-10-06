-- Stable IDs are persisted; prices, stats, and primitive appearances are configured here.
-- Add an item and link the previous item through nextId to extend a progression.
local Equipment = {
 Categories = {
  Bat = {
   startingId = "wood_bat",
   items = {
    wood_bat = {
     id = "wood_bat", displayName = "Wood Bat", price = 0,
     powerMultiplier = 1,
     nextId = "metal_bat",
     modelPath = "StarterPack.Bat",
     appearance = {BatBody = {color = Color3.fromRGB(160, 110, 60), material = Enum.Material.Wood}, BatGrip = {color = Color3.fromRGB(160, 110, 60), material = Enum.Material.Wood}, BatKnob = {color = Color3.fromRGB(160, 110, 60), material = Enum.Material.Wood}},
    },
    metal_bat = {
     id = "metal_bat", displayName = "Metal Bat", price = 300,
     powerMultiplier = 1.15,
     nextId = "alloy_bat",
     modelPath = "StarterPack.Bat",
     appearance = {BatBody = {color = Color3.fromRGB(195, 205, 220), material = Enum.Material.Metal}, BatGrip = {color = Color3.fromRGB(35, 40, 50), material = Enum.Material.SmoothPlastic}, BatKnob = {color = Color3.fromRGB(35, 40, 50), material = Enum.Material.SmoothPlastic}},
    },
    alloy_bat = {
     id = "alloy_bat", displayName = "Alloy Bat", price = 900,
     powerMultiplier = 1.3,
     nextId = "carbon_bat",
     modelPath = "StarterPack.Bat",
     appearance = {BatBody = {color = Color3.fromRGB(200, 45, 45), material = Enum.Material.Metal}, BatGrip = {color = Color3.fromRGB(30, 30, 35), material = Enum.Material.SmoothPlastic}, BatKnob = {color = Color3.fromRGB(30, 30, 35), material = Enum.Material.SmoothPlastic}},
    },
    carbon_bat = {
     id = "carbon_bat", displayName = "Carbon Bat", price = 2000,
     powerMultiplier = 1.5,
     modelPath = "StarterPack.Bat",
     appearance = {BatBody = {color = Color3.fromRGB(30, 35, 45), material = Enum.Material.Slate}, BatGrip = {color = Color3.fromRGB(240, 180, 50), material = Enum.Material.Metal}, BatKnob = {color = Color3.fromRGB(240, 180, 50), material = Enum.Material.Metal}},
    },
   },
  },
  Ball = {
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
  Tee = {
   startingId = "basic_tee",
   items = {
    basic_tee = {
     id = "basic_tee", displayName = "Basic Tee", price = 0,
     timingScale = 1,
     nextId = "rubber_tee",
     modelPath = "Workspace.BattingArea.Tee",
     appearance = {Base = {color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic}, Stem = {color = Color3.fromRGB(163, 162, 165), material = Enum.Material.Plastic}},
    },
    rubber_tee = {
     id = "rubber_tee", displayName = "Rubber Tee", price = 250,
     timingScale = 1.25,
     nextId = "steel_tee",
     modelPath = "Workspace.BattingArea.Tee",
     appearance = {Base = {color = Color3.fromRGB(40, 110, 70), material = Enum.Material.SmoothPlastic}, Stem = {color = Color3.fromRGB(35, 40, 40), material = Enum.Material.SmoothPlastic}},
    },
    steel_tee = {
     id = "steel_tee", displayName = "Steel Tee", price = 750,
     timingScale = 1.55,
     nextId = "pro_tee",
     modelPath = "Workspace.BattingArea.Tee",
     appearance = {Base = {color = Color3.fromRGB(35, 85, 170), material = Enum.Material.Metal}, Stem = {color = Color3.fromRGB(195, 205, 220), material = Enum.Material.Metal}},
    },
    pro_tee = {
     id = "pro_tee", displayName = "Pro Tee", price = 1600,
     timingScale = 1.9,
     modelPath = "Workspace.BattingArea.Tee",
     appearance = {Base = {color = Color3.fromRGB(30, 35, 45), material = Enum.Material.Metal}, Stem = {color = Color3.fromRGB(240, 180, 50), material = Enum.Material.Metal}},
    },
   },
  },
 },
}

function Equipment.Get(category, id)
 local definition = Equipment.Categories[category]
 if not definition then return nil end
 return definition.items[id or definition.startingId]
end

function Equipment.GetNext(category, currentId)
 local current = Equipment.Get(category, currentId)
 if not current or not current.nextId then return nil end
 return Equipment.Get(category, current.nextId)
end

return Equipment
