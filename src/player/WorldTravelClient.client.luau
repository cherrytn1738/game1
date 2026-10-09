local Player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Travel = ReplicatedStorage:WaitForChild("WorldTravel")
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))
local UI = require(script.Parent:WaitForChild("UICommon"))
local gui, panel, show = UI.Menu("WorldTravelGui","World travel","Hit farther to unlock your next destination.",Interfaces.CloseAll)
local list = UI.Scroll(panel,"WorldList")
list.Position, list.Size = UDim2.fromOffset(14,94), UDim2.new(1,-28,1,-150)
local feedback = UI.Label(panel,"Feedback","Your world unlocks are saved.",14,UI.Colors.Muted)
feedback.Position, feedback.Size, feedback.TextWrapped = UDim2.new(0,16,1,-44), UDim2.new(1,-32,0,36), true
local rows = {}
local pending, requestVersion = false, 0

local function refresh()
 for _, world in Worlds.Worlds do
  local row = rows[world.id]
  local ready = Player:GetAttribute("DataLoaded") == true
  local unlocked = ready and Player:GetAttribute("WorldUnlocked_"..world.id) == true
  local current = Player:GetAttribute("CurrentWorldId") == world.id
  local predecessor
  for _, previous in Worlds.Worlds do if previous.nextWorldId == world.id then predecessor = previous end end
  row.state.Text = not ready and "Loading destinations..." or current and "Current world" or unlocked and "Unlocked" or "Locked"
  row.state.TextColor3 = current and UI.Colors.Accent or UI.Colors.Muted
  row.detail.Text = unlocked and ("Field end · " .. UI.Number(world.endDistance) .. " studs")
   or predecessor and ("Reach " .. UI.Number(predecessor.endDistance) .. " studs in " .. predecessor.displayName .. " to unlock.") or "Not available yet."
  UI.SetButton(row.button,pending and "PLEASE WAIT" or unlocked and (current and "RETURN TO ARRIVAL" or "TRAVEL") or "LOCKED",ready and not pending and Interfaces.CanOpen(),unlocked)
  local narrow = panel.AbsoluteSize.X < 540
  row.frame.Size = UDim2.new(1,-10,0,narrow and 174 or 124)
  row.title.Size, row.state.Size, row.detail.Size = UDim2.new(1,narrow and -28 or -214,0,26), UDim2.new(1,narrow and -28 or -214,0,22), UDim2.new(1,narrow and -28 or -214,0,48)
  row.button.Position = narrow and UDim2.fromOffset(14,124) or UDim2.new(1,-184,0,36)
  row.button.Size = narrow and UDim2.new(1,-28,0,40) or UDim2.fromOffset(170,52)
 end
end

for index, world in Worlds.Worlds do
 local frame = UI.Surface(list,world.id,UI.Colors.Card)
 frame.LayoutOrder = index
 local title = UI.Label(frame,"WorldName",world.displayName,20)
 title.Font, title.Position = Enum.Font.GothamBold, UDim2.fromOffset(14,10)
 local state = UI.Label(frame,"State","",14)
 state.Position = UDim2.fromOffset(14,39)
 local detail = UI.Label(frame,"Requirement","",14,UI.Colors.Muted)
 detail.Position, detail.TextWrapped = UDim2.fromOffset(14,64), true
 local button = UI.Button(frame,"Travel","")
 rows[world.id] = {frame=frame,title=title,state=state,detail=detail,button=button}
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
Travel.OnClientEvent:Connect(function(message)
 pending = false
 requestVersion += 1
 local success = type(message) == "string" and message:sub(1,7) == "Arrived"
 if success then Interfaces.CloseAll() end
 feedback.Text = success and message or "That destination is unavailable. Check its unlock requirement."
 feedback.TextColor3 = success and UI.Colors.Accent or UI.Colors.Error
 if not gui.Scrim.Visible then UI.Notify(feedback.Text,success and "success" or "error") end
 refresh()
end)
refresh()
