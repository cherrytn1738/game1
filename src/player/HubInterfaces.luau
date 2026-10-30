-- Local presentation only. Purchases, equipping, and travel remain server-validated.
local Players = game:GetService("Players")
local Prompts = game:GetService("ProximityPromptService")
local Worlds = require(game.ReplicatedStorage:WaitForChild("WorldConfig"))
local player = Players.LocalPlayer
local Interfaces = {}
local panels = {}
local currentMenu
local changed = Instance.new("BindableEvent")
Interfaces.Changed = changed.Event

function Interfaces.IsOpen()
 return currentMenu ~= nil
end

-- The open menu's name ("Shop", "Rebirth", ...), or nil.
function Interfaces.Current()
 return currentMenu
end

-- The new-player tutorial keeps the HUD focused: until the server says it is complete (the
-- TutorialStep attribute; also before the save has loaded, so nothing flashes up first), the
-- persistent HUD shows only the Level bar and Power. The tutorial's own banner, arrows and
-- spotlight, the batting / Training controls, feedback, and the menus a step opens (Inventory,
-- Rebirth) still show; HUD scripts hide everything else, and show it again the moment the step
-- becomes "Complete" (watch TutorialStep). Returns whether to focus, and the step.
function Interfaces.TutorialFocus()
 local step = player:GetAttribute("TutorialStep")
 return step ~= "Complete", step
end

-- The quick-menu tiles the tutorial has brought back: Inventory once the tutorial Ball is bought
-- (to equip it there; it stays for the rest of the tutorial), and Rebirth at the Rebirth step.
function Interfaces.TutorialTile(name)
 local step = player:GetAttribute("TutorialStep")
 if name == "Inventory" then
  return step == "ReachLevel" or step == "Rebirth"
   or step == "BuyBall" and player:GetAttribute("TutorialBoughtBall") == true
 end
 return name == "Rebirth" and step == "Rebirth"
end

function Interfaces.CanOpen()
 local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 return player:GetAttribute("DataLoaded") == true and humanoid ~= nil and humanoid.Health > 0
  and not player:GetAttribute("TrainingActive") and not player:GetAttribute("BattingActive") and not player:GetAttribute("HitActive")
  and not player:GetAttribute("WorldTraveling")
end

function Interfaces.CloseAll()
 for _, show in panels do show(false) end
 if currentMenu then currentMenu = nil changed:Fire() end
end

function Interfaces.Open(name)
 if not Interfaces.CanOpen() or not panels[name] then return end
 Interfaces.CloseAll()
 panels[name](true)
 currentMenu = name
 changed:Fire()
end

function Interfaces.Register(name, show)
 panels[name] = show
 show(false)
end

function Interfaces.HasPhysicalHub()
 local world = Worlds.Get(player:GetAttribute("CurrentWorldId"))
 return world ~= nil and world.hub ~= nil
end

Prompts.PromptTriggered:Connect(function(prompt, triggeringPlayer)
 if triggeringPlayer ~= player or not Interfaces.CanOpen() then return end
 local world = Worlds.Get(player:GetAttribute("CurrentWorldId"))
 local hub = world and world.hub and workspace:FindFirstChild(world.hub.name)
 local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not hub or not prompt:IsDescendantOf(hub) or prompt:GetAttribute("WorldId") ~= world.id
  or not root or not prompt.Parent:IsA("BasePart") then return end
 if (root.Position - prompt.Parent.Position).Magnitude > prompt.MaxActivationDistance + 1 then return end
 Interfaces.Open(prompt:GetAttribute("HubAction"))
end)

for _, attribute in {"BattingActive", "TrainingActive", "HitActive", "DataLoaded", "CurrentWorldId", "WorldTraveling"} do
 player:GetAttributeChangedSignal(attribute):Connect(Interfaces.CloseAll)
end
-- An arrival may return to the same world, without changing CurrentWorldId.
game.ReplicatedStorage:WaitForChild("WorldTravel").OnClientEvent:Connect(function(message)
 if type(message) == "string" and message:sub(1,7) == "Arrived" then Interfaces.CloseAll() end
end)
player.CharacterRemoving:Connect(Interfaces.CloseAll)
local function characterAdded(character)
 Interfaces.CloseAll()
 local humanoid = character:WaitForChild("Humanoid", 10)
 if humanoid then humanoid.Died:Connect(Interfaces.CloseAll) end
end
player.CharacterAdded:Connect(characterAdded)
if player.Character then task.spawn(characterAdded, player.Character) end
return Interfaces
