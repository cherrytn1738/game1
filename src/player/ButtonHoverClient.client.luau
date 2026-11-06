-- A very soft click whenever the mouse cursor moves onto a pressable button anywhere in this
-- player's screen UI (HUD, menus, the Shop). Touch taps also fire MouseEnter, so they are
-- skipped. Presentation only.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GameAudio = require(game:GetService("ReplicatedStorage"):WaitForChild("GameAudio"))
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
GameAudio.Preload({"UIHover"})

-- Pressable: active, and every GuiObject up to its ScreenGui is visible and enabled.
local function pressable(button)
 if not button.Active then return false end
 local ancestor = button
 while ancestor do
  if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
  if ancestor:IsA("LayerCollector") then return ancestor.Enabled end
  ancestor = ancestor.Parent
 end
 return false
end

local hooked = setmetatable({}, {__mode = "k"})
local function hook(object)
 if not object:IsA("GuiButton") or hooked[object] then return end
 hooked[object] = true
 object.MouseEnter:Connect(function()
  if UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch and pressable(object) then
   GameAudio.Play("UIHover")
  end
 end)
end

for _, object in playerGui:GetDescendants() do hook(object) end
playerGui.DescendantAdded:Connect(hook)
