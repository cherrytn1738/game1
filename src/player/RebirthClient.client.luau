-- Presentation and intent only. The server validates and performs every Rebirth.
local Player = game.Players.LocalPlayer
local Storage = game:GetService("ReplicatedStorage")
local Progression = require(Storage:WaitForChild("ProgressionConfig"))
local Equipment = require(Storage:WaitForChild("EquipmentConfig"))
local Training = require(Storage:WaitForChild("TrainingConfig"))
local GameAudio = require(Storage:WaitForChild("GameAudio"))
local Remote = Storage:WaitForChild("RebirthRequest")
local UI = require(script.Parent:WaitForChild("UICommon"))
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))

local gui, panel, show = UI.Menu("RebirthGui","Rebirth","Reset Level and Power to grow further on your next run.",Interfaces.CloseAll)
local list = UI.Scroll(panel,"Details")
list.Position, list.Size = UDim2.fromOffset(14,110), UDim2.new(1,-28,1,-228)

local function card(name, order, title)
 local frame = UI.Surface(list,name,UI.Colors.Card)
 frame.Size, frame.AutomaticSize, frame.LayoutOrder = UDim2.new(1,-10,0,0), Enum.AutomaticSize.Y, order
 -- Content gets its own frame so the card's inner highlight stays out of the list layout.
 local content = Instance.new("Frame",frame)
 content.Name, content.BackgroundTransparency = "Content", 1
 content.Size, content.AutomaticSize = UDim2.fromScale(1,0), Enum.AutomaticSize.Y
 local padding = Instance.new("UIPadding",content)
 padding.PaddingTop, padding.PaddingBottom = UDim.new(0,12), UDim.new(0,12)
 padding.PaddingLeft, padding.PaddingRight = UDim.new(0,12), UDim.new(0,12)
 local layout = Instance.new("UIListLayout",content)
 layout.Padding, layout.SortOrder = UDim.new(0,6), Enum.SortOrder.LayoutOrder
 local heading = UI.Label(content,"Heading",title,20,title=="RESET" and UI.Colors.Error or title=="KEEP" and UI.Colors.Accent or UI.Colors.Gold)
 heading.Size, heading.AutomaticSize, heading.TextWrapped = UDim2.new(1,0,0,0), Enum.AutomaticSize.Y, true
 heading.LayoutOrder = 1
 local text = UI.Label(content,"Description","",17)
 text.Size, text.AutomaticSize, text.TextWrapped = UDim2.new(1,0,0,0), Enum.AutomaticSize.Y, true
 text.LayoutOrder = 2
 return heading, text
end
-- Rebirth comparison flow: two green tier cards with an arrow between them.
local comparison = Instance.new("Frame")
comparison.Name, comparison.BackgroundTransparency, comparison.LayoutOrder = "Comparison", 1, 1
comparison.Size, comparison.Parent = UDim2.new(1, -10, 0, 124), list
local function tierCard(name, anchorX, positionX)
 local frame = Instance.new("Frame")
 frame.Name, frame.BorderSizePixel = name, 0
 frame.AnchorPoint, frame.Position, frame.Size = Vector2.new(anchorX, 0), UDim2.new(positionX, 0, 0, 2), UDim2.new(.5, -30, 1, -4)
 frame.BackgroundColor3 = Color3.new(1, 1, 1)
 UI.Gradient(frame, UI.ButtonStates.Claim[1], UI.ButtonStates.Claim[2])
 Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
 local outline = Instance.new("UIStroke", frame)
 outline.Color, outline.Thickness = UI.Colors.Border, 4
 UI.Damier(frame, Color3.fromRGB(20, 110, 20), 22)
 frame.Parent = comparison
 local tier = UI.Label(frame, "Tier", "", 18)
 tier.Position, tier.Size, tier.TextXAlignment, tier.ZIndex = UDim2.fromOffset(6, 8), UDim2.new(1, -12, 0, 24), Enum.TextXAlignment.Center, 2
 local value = UI.Label(frame, "Value", "", 26)
 value.Position, value.Size, value.TextXAlignment, value.ZIndex = UDim2.fromOffset(6, 38), UDim2.new(1, -12, 0, 36), Enum.TextXAlignment.Center, 2
 value.TextScaled = true
 local constraint = Instance.new("UITextSizeConstraint", value)
 constraint.MinTextSize, constraint.MaxTextSize = 14, 26
 local cap = UI.Label(frame, "Cap", "", 16)
 cap.Position, cap.Size, cap.TextXAlignment, cap.ZIndex = UDim2.fromOffset(6, 80), UDim2.new(1, -12, 0, 24), Enum.TextXAlignment.Center, 2
 return tier, value, cap
end
local beforeTier, beforeValue, beforeCap = tierCard("Before", 0, 0)
local afterTier, afterValue, afterCap = tierCard("After", 1, 1)
local arrow = UI.Label(comparison, "Arrow", "➡", 34, Color3.fromRGB(235, 245, 255))
arrow.AnchorPoint, arrow.Position, arrow.Size = Vector2.new(.5, .5), UDim2.fromScale(.5, .5), UDim2.fromOffset(50, 50)
arrow.TextXAlignment = Enum.TextXAlignment.Center
arrow:FindFirstChildOfClass("UIStroke").Thickness = 3
-- Level progress toward the cap, and the requirement in a recessed box.
local progressHolder = Instance.new("Frame")
progressHolder.Name, progressHolder.BackgroundTransparency, progressHolder.LayoutOrder = "Progress", 1, 2
progressHolder.Size, progressHolder.Parent = UDim2.new(1, -10, 0, 34), list
local levelBar, setLevelBar = UI.ProgressBar(progressHolder, "LevelProgress")
levelBar.Size = UDim2.new(1, -4, 1, -4)
levelBar.Position = UDim2.fromOffset(2, 2)
local requirement = Instance.new("Frame")
requirement.Name, requirement.BorderSizePixel, requirement.LayoutOrder = "Requirement", 0, 3
requirement.BackgroundColor3, requirement.Size = UI.Colors.Card, UDim2.new(1, -10, 0, 40)
Instance.new("UICorner", requirement).CornerRadius = UDim.new(0, 12)
local requirementStroke = Instance.new("UIStroke", requirement)
requirementStroke.Color, requirementStroke.Thickness = UI.Colors.Border, 4
requirement.Parent = list
local requirementText = UI.Label(requirement, "Text", "", 17)
requirementText.Position, requirementText.Size = UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0)
requirementText.TextXAlignment = Enum.TextXAlignment.Center
local _, reset = card("Reset",4,"RESET")
reset.Text = "Level returns to " .. Progression.StartingLevel .. ". Power returns to " .. Progression.StartingPower .. "."
local _, keep = card("Keep",5,"KEEP")
keep.Text = "Cash, owned and equipped equipment, world unlocks, your valid Training Ground selection, and other progression."
local _, gain = card("Gain",6,"GAIN")

local feedback = UI.Label(panel,"Feedback","",14,UI.Colors.Muted)
feedback.Position, feedback.Size, feedback.TextWrapped = UDim2.new(0,16,1,-120), UDim2.new(1,-32,0,50), true
local rebirth = UI.Button(panel,"Rebirth","REBIRTH")
local confirm = UI.Button(panel,"ConfirmRebirth","CONFIRM REBIRTH")
local cancel = UI.Button(panel,"Cancel","CANCEL")
cancel:SetAttribute("Danger",true)
rebirth.Position, rebirth.Size = UDim2.new(0,16,1,-64), UDim2.new(1,-32,0,52)
confirm.Position, confirm.Size = UDim2.new(0,16,1,-64), UDim2.new(.65,-22,0,52)
cancel.Position, cancel.Size = UDim2.new(.65,2,1,-64), UDim2.new(.35,-18,0,52)

local confirmation = UI.Surface(panel,"Confirmation",UI.Colors.Card)
confirmation.Position,confirmation.Size,confirmation.Visible=UDim2.fromOffset(16,80),UDim2.new(1,-32,1,-212),false
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
 local count = Player:GetAttribute("Rebirths") or Progression.StartingRebirths
 local level = Player:GetAttribute("Level") or Progression.StartingLevel
 local cap = Player:GetAttribute("LevelCap") or Progression.GetLevelCap(count)
 local batMultiplier = Equipment.Get("Bat", Player:GetAttribute("EquippedBat")).powerGainMultiplier
 local nextCount = math.min(count + 1,Progression.MaxRebirths)
 beforeTier.Text, afterTier.Text = "REBIRTH " .. UI.Number(count), "REBIRTH " .. UI.Number(nextCount)
 beforeValue.Text = "x" .. UI.Number(Progression.GetPowerMultiplier(count)*batMultiplier,2) .. " POWER"
 afterValue.Text = "x" .. UI.Number(Progression.GetPowerMultiplier(nextCount)*batMultiplier,2) .. " POWER"
 beforeCap.Text, afterCap.Text = "LEVEL CAP " .. UI.Number(cap), "LEVEL CAP " .. UI.Number(Progression.GetLevelCap(nextCount))
 setLevelBar(level / math.max(cap, 1), "LEVEL " .. UI.Number(level) .. " / " .. UI.Number(cap))
 requirementText.Text = level >= cap and "REQUIREMENT MET: LEVEL " .. UI.Number(cap) or "REQUIREMENT: REACH LEVEL " .. UI.Number(cap)
 requirementText.TextColor3 = level >= cap and UI.Colors.Success or UI.Colors.Muted
 panel.Title.Text = confirming and "ARE YOU SURE?" or "REBIRTH"
 local grounds = {}
 local worlds = Training.ReadUnlockedWorlds(Player)
 for _, ground in Training.Grounds do
  if Training.IsUnlocked(ground.id,nextCount,worlds) and not Training.IsUnlocked(ground.id,count,worlds) then
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
 if success then
  Interfaces.CloseAll()
  GameAudio.Play("Rebirth")
 end
 refresh()
 if not success and visible then feedback.Text, feedback.TextColor3 = message, UI.Colors.Error end
 UI.Notify(success and message:gsub("^REBIRTH COMPLETE\n","") or message,success and "rebirth" or "error")
end)
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
refresh()
