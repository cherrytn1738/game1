-- Presentation and intent only. The server validates and performs every Rebirth.
local Player = game.Players.LocalPlayer
local Storage = game:GetService("ReplicatedStorage")
local Progression = require(Storage:WaitForChild("ProgressionConfig"))
local Equipment = require(Storage:WaitForChild("EquipmentConfig"))
local Training = require(Storage:WaitForChild("TrainingConfig"))
local Remote = Storage:WaitForChild("RebirthRequest")
local UI = require(script.Parent:WaitForChild("UICommon"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))

local gui, panel, show = UI.Menu("RebirthGui","Rebirth","Reset Level and Power to grow further on your next run.",Interfaces.CloseAll)
local list = UI.Scroll(panel,"Details")
list.Position, list.Size = UDim2.fromOffset(14,92), UDim2.new(1,-28,1,-210)

local function card(name, order, title)
 local frame = UI.Surface(list,name,UI.Colors.Card)
 frame.Size, frame.AutomaticSize, frame.LayoutOrder = UDim2.new(1,-10,0,0), Enum.AutomaticSize.Y, order
 local padding = Instance.new("UIPadding",frame)
 padding.PaddingTop, padding.PaddingBottom = UDim.new(0,12), UDim.new(0,12)
 padding.PaddingLeft, padding.PaddingRight = UDim.new(0,12), UDim.new(0,12)
 local layout = Instance.new("UIListLayout",frame)
 layout.Padding, layout.SortOrder = UDim.new(0,6), Enum.SortOrder.LayoutOrder
 local heading = UI.Label(frame,"Heading",title,18,UI.Colors.Accent)
 heading.Size, heading.AutomaticSize, heading.TextWrapped = UDim2.new(1,0,0,0), Enum.AutomaticSize.Y, true
 heading.LayoutOrder = 1
 local text = UI.Label(frame,"Description","",15)
 text.Size, text.AutomaticSize, text.TextWrapped = UDim2.new(1,0,0,0), Enum.AutomaticSize.Y, true
 text.LayoutOrder = 2
 return heading, text
end
local summaryHeading, summary = card("Benefits",1,"")
local _, reset = card("Reset",2,"RESET")
reset.Text = "Level returns to " .. Progression.StartingLevel .. ". Power returns to " .. Progression.StartingPower .. "."
local _, keep = card("Keep",3,"KEEP")
keep.Text = "Cash, owned and equipped equipment, world unlocks, your valid Training Ground selection, and other progression."
local _, gain = card("Gain",4,"GAIN")

local feedback = UI.Label(panel,"Feedback","",14,UI.Colors.Muted)
feedback.Position, feedback.Size, feedback.TextWrapped = UDim2.new(0,16,1,-112), UDim2.new(1,-32,0,54), true
local rebirth = UI.Button(panel,"Rebirth","REBIRTH")
local confirm = UI.Button(panel,"ConfirmRebirth","CONFIRM REBIRTH")
local cancel = UI.Button(panel,"Cancel","CANCEL")
rebirth.Position, rebirth.Size = UDim2.new(0,16,1,-52), UDim2.new(1,-32,0,40)
confirm.Position, confirm.Size = UDim2.new(0,16,1,-52), UDim2.new(.65,-22,0,40)
cancel.Position, cancel.Size = UDim2.new(.65,2,1,-52), UDim2.new(.35,-18,0,40)

local visible, confirming, pending, requestVersion = false, false, false, 0
local function eligibility()
 if not Player:GetAttribute("DataLoaded") then return false,"Player data is not ready." end
 if not Interfaces.CanOpen() then return false,"Leave Training or batting and finish your hit before Rebirthing." end
 local level, cap = Player:GetAttribute("Level"), Player:GetAttribute("LevelCap")
 if Player:GetAttribute("Rebirths") >= Progression.MaxRebirths then return false,"Maximum Rebirth count reached." end
 if level < cap then return false,"Reach Level " .. UI.Number(cap) .. " to Rebirth." end
 return true,"Eligible - choose Rebirth to review your confirmation."
end

local function refresh()
 local count = Player:GetAttribute("Rebirths") or Progression.StartingRebirths
 local level = Player:GetAttribute("Level") or Progression.StartingLevel
 local cap = Player:GetAttribute("LevelCap") or Progression.GetLevelCap(count)
 local batMultiplier = Equipment.Get("Bat", Player:GetAttribute("EquippedBat")).powerGainMultiplier
 local nextCount = math.min(count + 1,Progression.MaxRebirths)
 summaryHeading.Text = "REBIRTH " .. UI.Number(count) .. " → " .. UI.Number(nextCount)
 summary.Text = "Current Level: " .. UI.Number(level) .. " / " .. UI.Number(cap)
  .. "\nPower gain: " .. UI.Number(Progression.GetPowerMultiplier(count) * batMultiplier, 2) .. "x → " .. UI.Number(Progression.GetPowerMultiplier(nextCount) * batMultiplier, 2) .. "x"
  .. "\nLevel Cap: " .. UI.Number(cap) .. " → " .. UI.Number(Progression.GetLevelCap(nextCount))
 local grounds = {}
 for _, ground in Training.Grounds do
  if Training.IsUnlocked(ground.id,nextCount) and not Training.IsUnlocked(ground.id,count) then
   table.insert(grounds,ground.displayName)
  end
 end
 gain.Text = "+1 Rebirth, higher Power gain, and a higher Level Cap."
  .. (#grounds > 0 and "\nNew Training Ground: " .. table.concat(grounds,", ") or "\nGround availability follows your Rebirth count.")
 if count >= Progression.MaxRebirths then gain.Text = "Maximum Rebirth count reached. Your current benefits remain." end
 local eligible, reason = eligibility()
 if not eligible then confirming = false end
 feedback.Text = pending and "Rebirth requested - waiting for the server..."
  or confirming and "Confirm resetting Level and Power? Everything listed under KEEP remains."
  or reason
 feedback.TextColor3 = confirming and UI.Colors.Gold or eligible and UI.Colors.Accent or UI.Colors.Muted
 rebirth.Visible, confirm.Visible, cancel.Visible = not confirming, confirming, confirming
 UI.SetButton(rebirth,pending and "PLEASE WAIT" or "REBIRTH",eligible and not pending,true)
 UI.SetButton(confirm,"CONFIRM REBIRTH",eligible and not pending,true)
 UI.SetButton(cancel,"CANCEL",not pending,false)
end

rebirth.Activated:Connect(function()
 if not visible or pending then return end
 local eligible = eligibility()
 if not eligible then refresh() return end
 confirming = true
 refresh()
end)
cancel.Activated:Connect(function()
 if pending then return end
 confirming = false
 refresh()
end)
confirm.Activated:Connect(function()
 if not visible or not confirming or pending or not eligibility() then return end
 pending, confirming = true, false
 requestVersion += 1
 local version = requestVersion
 refresh()
 Remote:FireServer()
 task.delay(8,function()
  if pending and requestVersion == version then
   pending = false
   refresh()
   if visible then feedback.Text = "No response yet. Reopen the confirmation to try again." end
  end
 end)
end)
Interfaces.Register("Rebirth",function(open)
 visible, confirming = open, false
 show(open)
 refresh()
end)
for _, attribute in {"DataLoaded","EquippedBat","Level","LevelCap","Rebirths","TrainingActive","BattingActive","HitActive","WorldTraveling","CurrentWorldId"} do
 Player:GetAttributeChangedSignal(attribute):Connect(function()
  confirming = false
  refresh()
 end)
end
Remote.OnClientEvent:Connect(function(success,message)
 pending, confirming = false, false
 requestVersion += 1
 if success then Interfaces.CloseAll() end
 refresh()
 if not success and visible then feedback.Text, feedback.TextColor3 = message, UI.Colors.Error end
 UI.Notify(success and message:gsub("^REBIRTH COMPLETE\n","") or message,success and "rebirth" or "error")
end)
refresh()
