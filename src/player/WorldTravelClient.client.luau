local Player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Travel = ReplicatedStorage:WaitForChild("WorldTravel")
local GameAudio = require(ReplicatedStorage:WaitForChild("GameAudio"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))
local UI = require(script.Parent:WaitForChild("UICommon"))
local gui, panel, show = UI.Menu("WorldTravelGui","Worlds","Hit farther to unlock your next destination.",Interfaces.CloseAll)
local list = UI.Scroll(panel,"WorldList")
list.Position, list.Size = UDim2.fromOffset(14,110), UDim2.new(1,-28,1,-166)
local feedback = UI.Label(panel,"Feedback","Your world unlocks are saved.",14,UI.Colors.Muted)
feedback.Position, feedback.Size, feedback.TextWrapped = UDim2.new(0,16,1,-44), UDim2.new(1,-32,0,36), true
local rows = {}
local pending, requestVersion = false, 0

local function refresh()
 local short = panel.AbsoluteSize.Y < 400
 list.Position, list.Size = UDim2.fromOffset(14,short and 80 or 110),UDim2.new(1,-28,1,short and -136 or -166)
 for _, world in Worlds.Worlds do
  local row = rows[world.id]
  local ready = Player:GetAttribute("DataLoaded") == true
  local unlocked = ready and Player:GetAttribute("WorldUnlocked_"..world.id) == true
  local current = Player:GetAttribute("CurrentWorldId") == world.id
  local predecessor
  for _, previous in Worlds.Worlds do if previous.nextWorldId == world.id then predecessor = previous end end
  row.state.Text = (world.title and world.title .. " | " or "")
   .. (not ready and "Loading destinations..." or current and "Current world" or unlocked and "Unlocked" or "Locked")
  row.state.TextColor3 = current and UI.Colors.Accent or UI.Colors.Muted
  row.detail.Text = unlocked and ("Field end · " .. UI.Number(world.endDistance) .. " studs")
   or predecessor and ("Reach " .. UI.Number(predecessor.endDistance) .. " studs in " .. predecessor.displayName .. " to unlock.") or "Not available yet."
  UI.SetButton(row.button,pending and "PLEASE WAIT" or current and "YOU ARE HERE" or unlocked and "TRAVEL" or "LOCKED",ready and unlocked and not current and not pending and Interfaces.CanOpen(),unlocked)
  UI.CardState(row.frame,current and "selected" or unlocked and "available" or "locked")
  row.badge.BackgroundColor3 = unlocked and UI.Colors.Accent or UI.Colors.Error
  row.frame.Size = UDim2.new(1,-10,0,224)
  row.title.Size, row.state.Size, row.detail.Size = UDim2.new(1,-130,0,36),UDim2.new(1,-130,0,26),UDim2.new(1,-36,0,48)
  row.button.Position, row.button.Size = UDim2.fromOffset(18,154),UDim2.new(1,-36,0,54)
 end
end

for index, world in Worlds.Worlds do
 local frame = UI.Surface(list,world.id,UI.Colors.Card)
 frame.LayoutOrder = index
 local badge=UI.Badge(frame,string.format("%02d",index),UI.Colors.Accent)
 badge.Position,badge.Size=UDim2.fromOffset(18,16),UDim2.fromOffset(70,70)
 local title = UI.Label(frame,"WorldName",world.displayName,30)
 title.Font, title.Position = UI.Font, UDim2.fromOffset(110,18)
 local state = UI.Label(frame,"State","",18)
 state.Position = UDim2.fromOffset(110,58)
 local detail = UI.Label(frame,"Requirement","",17,UI.Colors.Muted)
 detail.Position, detail.TextWrapped = UDim2.fromOffset(18,98), true
 local button = UI.Button(frame,"Travel","")
 rows[world.id] = {frame=frame,title=title,state=state,detail=detail,button=button,badge=badge}
 button.Activated:Connect(function()
  if pending or not button.Active or not Interfaces.CanOpen() then return end
  if Player:GetAttribute("WorldUnlocked_"..world.id) ~= true then
   feedback.Text, feedback.TextColor3 = detail.Text, UI.Colors.Error
   return
  end
  pending = true
  requestVersion += 1
  local version = requestVersion
  feedback.Text = "Travelling to " .. world.displayName .. "..."
  refresh()
  Travel:FireServer(world.id)
  task.delay(8,function()
   if pending and version == requestVersion then
    pending = false
    feedback.Text = "No response yet. Please try again."
    refresh()
   end
  end)
 end)
 Player:GetAttributeChangedSignal("WorldUnlocked_"..world.id):Connect(refresh)
end
Interfaces.Register("Travel",function(visible)
 show(visible)
 if visible then feedback.Text, feedback.TextColor3 = "Your world unlocks are saved.", UI.Colors.Muted refresh() end
end)
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
Player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh)
Player:GetAttributeChangedSignal("CurrentWorldId"):Connect(refresh)

-- Stepping into a hub's World portal (WorldPortal's Trigger) opens this menu, once per entry;
-- choosing a World sends the same server-checked travel request as the buttons above.
local PORTAL_CHECK_SECONDS = 0.15
local inPortal, sinceCheck = false, 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
 sinceCheck += dt
 if sinceCheck < PORTAL_CHECK_SECONDS then return end
 sinceCheck = 0
 local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
 local world = Worlds.Get(Player:GetAttribute("CurrentWorldId"))
 local hub = world and world.hub and workspace:FindFirstChild(world.hub.name)
 local portal = hub and hub:FindFirstChild("WorldPortal")
 local trigger = portal and portal:FindFirstChild("Trigger")
 local inside = false
 if root and trigger then
  local point = trigger.CFrame:PointToObjectSpace(root.Position)
  inside = math.abs(point.X) <= trigger.Size.X / 2 and math.abs(point.Y) <= trigger.Size.Y / 2 + 1
   and math.abs(point.Z) <= trigger.Size.Z / 2
 end
 if inside and not inPortal and not Interfaces.IsOpen() then Interfaces.Open("Travel") end
 inPortal = inside
end)
Travel.OnClientEvent:Connect(function(message)
 pending = false
 requestVersion += 1
 local success = type(message) == "string" and message:sub(1,7) == "Arrived"
 if success then
  Interfaces.CloseAll()
  GameAudio.Play("Travel")
 end
 feedback.Text = success and message or "That destination is unavailable. Check its unlock requirement."
 feedback.TextColor3 = success and UI.Colors.Accent or UI.Colors.Error
 if not gui.Scrim.Visible then UI.Notify(feedback.Text,success and "success" or "error") end
 refresh()
end)
refresh()
