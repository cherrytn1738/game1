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
list.Position, list.Size = UDim2.fromOffset(14,110), UDim2.new(1,-28,1,-228)

local function card(name, order, title)
 local frame = UI.Surface(list,name,UI.Colors.Card)
 frame.Size, frame.AutomaticSize, frame.LayoutOrder = UDim2.new(1,-10,0,0), Enum.AutomaticSize.Y, order
 local padding = Instance.new("UIPadding",frame)
 padding.PaddingTop, padding.PaddingBottom = UDim.new(0,12), UDim.new(0,12)
 padding.PaddingLeft, padding.PaddingRight = UDim.new(0,12), UDim.new(0,12)
 local layout = Instance.new("UIListLayout",frame)
 layout.Padding, layout.SortOrder = UDim.new(0,6), Enum.SortOrder.LayoutOrder
 local heading = UI.Label(frame,"Heading",title,20,title=="RESET" and UI.Colors.Error or title=="KEEP" and UI.Colors.Accent or UI.Colors.Gold)
 heading.Size, heading.AutomaticSize, heading.TextWrapped = UDim2.new(1,0,0,0), Enum.AutomaticSize.Y, true
 heading.LayoutOrder = 1
 local text = UI.Label(frame,"Description","",17)
 text.Size, text.AutomaticSize, text.TextWrapped = UDim2.new(1,0,0,0), Enum.AutomaticSize.Y, true
 text.LayoutOrder = 2
 return heading, text
end
local benefits = UI.Surface(list,"Benefits",UI.Colors.Card)
UI.Gradient(benefits,Color3.fromRGB(148,83,220),Color3.fromRGB(63,35,112))
benefits.BackgroundColor3 = Color3.new(1,1,1)
benefits.BackgroundTransparency = 0
benefits.Size, benefits.LayoutOrder = UDim2.new(1,-10,0,176),1
local summaryHeading = UI.Label(benefits,"Heading","",24,UI.Colors.Gold)
summaryHeading.Position, summaryHeading.Size = UDim2.fromOffset(12,8),UDim2.new(1,-24,0,32)
summaryHeading.TextXAlignment = Enum.TextXAlignment.Center
local before = UI.Label(benefits,"Before","",20)
before.Position, before.Size = UDim2.fromOffset(8,46),UDim2.new(.5,-16,0,120)
before.TextXAlignment = Enum.TextXAlignment.Center
local after = UI.Label(benefits,"After","",20,UI.Colors.Gold)
after.Position, after.Size = UDim2.new(.5,8,0,46),UDim2.new(.5,-16,0,120)
after.TextXAlignment = Enum.TextXAlignment.Center
local arrow = UI.Label(benefits,"Arrow","→",32)
arrow.AnchorPoint,arrow.Position,arrow.Size,arrow.TextXAlignment=Vector2.new(.5,.5),UDim2.fromScale(.5,.62),UDim2.fromOffset(40,44),Enum.TextXAlignment.Center
local _, reset = card("Reset",2,"RESET")
reset.Text = "Level returns to " .. Progression.StartingLevel .. ". Power returns to " .. Progression.StartingPower .. "."
local _, keep = card("Keep",3,"KEEP")
keep.Text = "Cash, owned and equipped equipment, world unlocks, your valid Training Ground selection, and other progression."
local _, gain = card("Gain",4,"GAIN")

local feedback = UI.Label(panel,"Feedback","",14,UI.Colors.Muted)
feedback.Position, feedback.Size, feedback.TextWrapped = UDim2.new(0,16,1,-120), UDim2.new(1,-32,0,50), true
local rebirth = UI.Button(panel,"Rebirth","REBIRTH")
rebirth:SetAttribute("ActionColor",Color3.fromRGB(215,83,240))
local confirm = UI.Button(panel,"ConfirmRebirth","CONFIRM REBIRTH")
local cancel = UI.Button(panel,"Cancel","CANCEL")
cancel:SetAttribute("Danger",true)
rebirth.Position, rebirth.Size = UDim2.new(0,16,1,-64), UDim2.new(1,-32,0,52)
confirm.Position, confirm.Size = UDim2.new(0,16,1,-64), UDim2.new(.65,-22,0,52)
cancel.Position, cancel.Size = UDim2.new(.65,2,1,-64), UDim2.new(.35,-18,0,52)

local confirmation = UI.Surface(panel,"Confirmation",Color3.fromRGB(81,40,110))
confirmation.Position,confirmation.Size,confirmation.Visible=UDim2.fromOffset(16,80),UDim2.new(1,-32,1,-212),false
confirmation.BackgroundTransparency=.1
local confirmIcon=UI.Icon(confirmation,"Icon",UI.Icons.Rebirth)
confirmIcon.AnchorPoint,confirmIcon.Position,confirmIcon.Size=Vector2.new(.5,0),UDim2.new(.5,0,0,14),UDim2.fromOffset(64,64)
local confirmTitle=UI.Label(confirmation,"Title","START A STRONGER RUN?",25)
confirmTitle.Position,confirmTitle.Size,confirmTitle.TextXAlignment=UDim2.fromOffset(14,88),UDim2.new(1,-28,0,38),Enum.TextXAlignment.Center
confirmTitle.TextScaled=true
local confirmReset=UI.Label(confirmation,"Reset","RESET: Level + Power",22,UI.Colors.Error)
confirmReset.Position,confirmReset.Size,confirmReset.TextXAlignment=UDim2.fromOffset(14,140),UDim2.new(1,-28,0,34),Enum.TextXAlignment.Center
local confirmKeep=UI.Label(confirmation,"Keep","KEEP: Cash, equipment and worlds",18,UI.Colors.Accent)
confirmKeep.Position,confirmKeep.Size,confirmKeep.TextWrapped,confirmKeep.TextXAlignment=UDim2.fromOffset(14,184),UDim2.new(1,-28,0,54),true,Enum.TextXAlignment.Center

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
 local short = panel.AbsoluteSize.Y < 400
 list.Position, list.Size = UDim2.fromOffset(14,short and 80 or 110),UDim2.new(1,-28,1,short and -210 or -240)
 local compactConfirm = panel.Size.Y.Offset < 470
 confirmIcon.Visible = not compactConfirm
 confirmTitle.Position,confirmTitle.Size = UDim2.fromOffset(14,compactConfirm and 6 or 88),UDim2.new(1,-28,0,compactConfirm and 28 or 38)
 confirmReset.Position,confirmReset.Size = UDim2.fromOffset(14,compactConfirm and 36 or 140),UDim2.new(1,-28,0,compactConfirm and 24 or 34)
 confirmKeep.Position,confirmKeep.Size = UDim2.fromOffset(14,compactConfirm and 62 or 184),UDim2.new(1,-28,0,compactConfirm and 36 or 54)
 confirmReset.TextSize,confirmKeep.TextSize = compactConfirm and 18 or 22,compactConfirm and 16 or 18
 benefits.Size = UDim2.new(1,-10,0,short and 148 or 190)
 before.Position, after.Position = UDim2.fromOffset(8,38),UDim2.new(.5,8,0,38)
 before.Size, after.Size = UDim2.new(.5,-30,0,short and 100 or 134),UDim2.new(.5,-30,0,short and 100 or 134)
 before.Position,after.Position=UDim2.fromOffset(8,38),UDim2.new(.5,22,0,38)
 local count = Player:GetAttribute("Rebirths") or Progression.StartingRebirths
 local level = Player:GetAttribute("Level") or Progression.StartingLevel
 local cap = Player:GetAttribute("LevelCap") or Progression.GetLevelCap(count)
 local batMultiplier = Equipment.Get("Bat", Player:GetAttribute("EquippedBat")).powerGainMultiplier
 local nextCount = math.min(count + 1,Progression.MaxRebirths)
 summaryHeading.Text = "REBIRTH " .. UI.Number(count) .. " → " .. UI.Number(nextCount)
 before.Text = "BEFORE\n" .. UI.Number(Progression.GetPowerMultiplier(count)*batMultiplier,2) .. "x Power\nLevel Cap " .. UI.Number(cap)
 after.Text = "AFTER\n" .. UI.Number(Progression.GetPowerMultiplier(nextCount)*batMultiplier,2) .. "x Power\nLevel Cap " .. UI.Number(Progression.GetLevelCap(nextCount))
 panel.Title.Text = confirming and "ARE YOU SURE?" or "REBIRTH"
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
  or confirming and "Reset Level + Power. Keep Cash, equipment and worlds."
  or reason
 feedback.TextColor3 = confirming and UI.Colors.Gold or eligible and UI.Colors.Accent or UI.Colors.Muted
 rebirth.Visible, confirm.Visible, cancel.Visible = not confirming, confirming, confirming
 list.Visible = not confirming
 panel.Subtitle.Visible = not confirming and panel.AbsoluteSize.Y >= 400
 confirmation.Visible = confirming
 UI.SetButton(rebirth,pending and "PLEASE WAIT" or "REBIRTH",eligible and not pending,true)
 UI.SetButton(confirm,"CONFIRM",eligible and not pending,true)
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
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
refresh()
