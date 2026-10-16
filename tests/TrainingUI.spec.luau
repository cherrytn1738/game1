-- Runs the real TrainingClient against event-driven player/UI fakes.
-- Exercises the ground overview (GO / BUY / locked) and availability after batting/flight
-- transitions without live gameplay.
return function(sources)
 local passed = 0
 local function compile(source)
  return type(source)=="function" and source or assert(loadstring(source))
 end
 local function check(condition,message) assert(condition,message) passed+=1 end
 local function signal()
  local callbacks = {}
  return {
   Connect=function(_,callback) table.insert(callbacks,callback) return {Disconnect=function() end} end,
   Fire=function(_,...) for _,callback in callbacks do callback(...) end end,
  }
 end
 local function object(name)
  return {Name=name,AbsoluteSize=Vector2.new(720,550),Activated=signal(),GetPropertyChangedSignal=function() return signal() end}
 end
 local attributes = {DataLoaded=true,Rebirths=1,Level=4,LevelCap=20,Power=0,OfflineSeconds=0}
 local changed = {}
 local player = {CharacterAdded=signal(),CharacterRemoving=signal()}
 function player:GetAttribute(name) return attributes[name] end
 function player:GetAttributeChangedSignal(name)
  changed[name]=changed[name] or signal()
  return changed[name]
 end
 function player:SetAttribute(name,value)
  if attributes[name]==value then return end
  attributes[name]=value
  self:GetAttributeChangedSignal(name):Fire()
 end
 player.Character={FindFirstChildOfClass=function() return {Health=100} end}
 local buttons,requests,labels,teleports={},{},{},{}
 local UI={Colors={},Icons={},Number=tostring,Compact=tostring,Notify=function() end,CardState=function() end}
 function UI.Badge() return object("Badge") end
 function UI.Icon() return object("Icon") end
 function UI.Menu() return object("Menu"),object("Panel"),function() end end
 function UI.Scroll(_,name) return object(name) end
 function UI.Surface(_,name) return object(name) end
 function UI.Hero() return object("Hero") end
 function UI.Shrink() end
 function UI.Label(parent,name)
  local label=object(name)
  labels[parent.Name .. "." .. name]=label
  return label
 end
 function UI.Screen(name) return object(name) end
 function UI.Button(parent,name)
  local button=object(name)
  buttons[parent.Name]=button
  return button
 end
 function UI.SetButton(button,text,enabled)
  button.Text,button.Active=text,enabled
 end
 local Interfaces={CloseAll=function() end,Register=function() end,Changed=signal(),IsOpen=function() return false end}
 function Interfaces.CanOpen()
  return attributes.DataLoaded and not attributes.TrainingActive and not attributes.BattingActive
   and not attributes.HitActive and not attributes.WorldTraveling
 end
 local remote={OnClientEvent=signal(),FireServer=function(_,...) table.insert(requests,table.pack(...)) end}
 local teleport={FireServer=function(_,...) table.insert(teleports,table.pack(...)) end}
 local trainingConfig=compile(sources.TrainingConfig)()
 trainingConfig.Get("dragons_lair").gamePassId=111 -- Fixture: only this pass "exists".
 local modules={UICommon=UI,HubInterfaces=Interfaces,
  EquipmentConfig=compile(sources.EquipmentConfig)(),TrainingConfig=trainingConfig,
  ProgressionConfig=compile(sources.ProgressionConfig)(),SwingConfig={},WorldConfig={}}
 local storage={}
 -- The real client fetches its RemoteEvents directly rather than requiring them.
 function storage:WaitForChild(name)
  return name=="TrainingRequest" and remote or name=="TrainingTeleport" and teleport or name
 end
 local services={Players={LocalPlayer=player},RunService={},ContextActionService={},ReplicatedStorage=storage}
 local environment=setmetatable({
  game={GetService=function(_,name) return assert(services[name],name) end},
  script={Parent={UICommon="UICommon",HubInterfaces="HubInterfaces"}},
  require=function(name) return assert(modules[name],name) end,
  task={defer=function() end,spawn=function() end,delay=function() end},
 },{__index=getfenv()})
 local client=compile(sources.TrainingClient)
 setfenv(client,environment)
 client()
 check(labels["basic_training.Rate"].Text == "x1 POWER  |  20 Power / second", "starting Bat stacks with Rebirth in rate preview")
 player:SetAttribute("EquippedBat","amethyst_bat")
 check(labels["basic_training.Rate"].Text == "x1 POWER  |  50 Power / second", "equipping Bat updates effective Training rate")
 player:SetAttribute("EquippedBall","crystal_ball")
 check(labels["basic_training.Rate"].Text == "x1 POWER  |  50 Power / second", "Ball does not alter Training preview")
 player:SetAttribute("EquippedBat","metal_bat")
 check(labels["enchanted_grove.Rate"].Text == "x5 POWER  |  150 Power / second", "ground, Bat and Rebirth compose once in preview")
 check(buttons.basic_training.Active and buttons.basic_training.Text == "GO","unlocked ground offers a teleport")
 check(not buttons.enchanted_grove.Active and buttons.enchanted_grove.Text == "REQUIRES 2 REBIRTHS","locked Rebirth ground stays disabled")
 check(not buttons.cosmic_rift.Active and buttons.cosmic_rift.Text == "COMING SOON","paid ground without a pass id cannot be bought")
 check(buttons.dragons_lair.Active and buttons.dragons_lair.Text == "BUY  R$ 500","paid ground offers its pass")
 player:SetAttribute("BattingActive",true)
 player:SetAttribute("HitActive",true)
 player:SetAttribute("Power",4)
 check(not buttons.basic_training.Active,"Power refresh during batting disables the menu")
 player:SetAttribute("HitActive",false)
 check(not buttons.basic_training.Active,"finishing a hit does not enable it while batting")
 player:SetAttribute("BattingActive",false)
 check(buttons.basic_training.Active,"leaving batting restores the menu without another progression change")
 player:SetAttribute("BattingActive",true)
 player:SetAttribute("HitActive",true)
 player:SetAttribute("Power",8)
 player:SetAttribute("BattingActive",false)
 check(not buttons.basic_training.Active,"leaving during flight keeps the menu disabled")
 player:SetAttribute("HitActive",false)
 check(buttons.basic_training.Active,"flight completion restores the menu after the player has left batting")
 buttons.basic_training.Activated:Fire()
 check(#teleports==1 and teleports[1].n==1 and teleports[1][1]=="basic_training" and #requests==0,
  "GO submits only the ground id as teleport intent")
 buttons.dragons_lair.Activated:Fire()
 check(#requests==1 and requests[1].n==2 and requests[1][1]=="Buy" and requests[1][2]=="dragons_lair","BUY asks the server for the pass prompt")
 buttons.enchanted_grove.Activated:Fire()
 check(#requests==1 and #teleports==1,"locked button sends nothing")
 player:SetAttribute("WorldTraveling",true)
 check(not buttons.basic_training.Active,"travel disables the menu")
 player:SetAttribute("WorldTraveling",false)
 check(buttons.basic_training.Active,"travel completion restores the menu")
 player:SetAttribute("TrainingPass_dragons_lair",true)
 check(buttons.dragons_lair.Active and buttons.dragons_lair.Text == "GO","owned pass turns BUY into GO")
 player:SetAttribute("Rebirths",2)
 check(buttons.enchanted_grove.Active and buttons.enchanted_grove.Text == "GO","Rebirth unlock refreshes the menu")
 return {passed=passed}
end
