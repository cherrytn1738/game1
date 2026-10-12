-- Runs the real TrainingClient against event-driven player/UI fakes.
-- Exercises availability after batting/flight transitions without live gameplay.
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
 local attributes = {DataLoaded=true,Rebirths=1,Level=4,LevelCap=20,Power=0,
  SelectedTrainingGround="advanced_training",OfflineSeconds=0}
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
 local buttons,requests,labels={},{},{}
 local UI={Colors={},Icons={},Number=tostring,Compact=tostring,Notify=function() end,CardState=function() end}
 function UI.Badge() return object("Badge") end
 function UI.Icon() return object("Icon") end
 function UI.Menu() return object("Menu"),object("Panel"),function() end end
 function UI.Scroll(_,name) return object(name) end
 function UI.Surface(_,name) return object(name) end
 function UI.Hero() return object("Hero") end
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
 local modules={UICommon=UI,HubInterfaces=Interfaces,TrainingRequest=remote,
  EquipmentConfig=compile(sources.EquipmentConfig)(),
  TrainingConfig=compile(sources.TrainingConfig)(),
  ProgressionConfig=compile(sources.ProgressionConfig)(),SwingConfig={},WorldConfig={}}
 local storage={WaitForChild=function(_,name) return name end}
 local services={Players={LocalPlayer=player},RunService={},ContextActionService={},ReplicatedStorage=storage}
 local environment=setmetatable({
  game={GetService=function(_,name) return assert(services[name],name) end},
  script={Parent={UICommon="UICommon",HubInterfaces="HubInterfaces"}},
  require=function(name) return assert(modules[name],name) end,
  task={defer=function() end,spawn=function() end},
 },{__index=getfenv()})
 -- The real client fetches its RemoteEvent directly rather than requiring it.
 function storage:WaitForChild(name) return name=="TrainingRequest" and remote or name end
 local client=compile(sources.TrainingClient)
 setfenv(client,environment)
 client()
 check(labels["basic_training.Rate"].Text == "20 Power / second", "starting Bat stacks with Rebirth in rate preview")
 player:SetAttribute("EquippedBat","carbon_bat")
 check(labels["basic_training.Rate"].Text == "50 Power / second", "equipping Bat updates effective Training rate")
 player:SetAttribute("EquippedBall","championship_ball")
 check(labels["basic_training.Rate"].Text == "50 Power / second", "Ball does not alter Training preview")
 player:SetAttribute("EquippedBat","metal_bat")
 check(labels["advanced_training.Rate"].Text == "75 Power / second", "ground, Bat and Rebirth compose once in preview")
 check(buttons.basic_training.Active,"unlocked alternative starts selectable")
 check(not buttons.advanced_training.Active,"selected ground stays disabled")
 check(not buttons.expert_training.Active,"locked ground stays disabled")
 player:SetAttribute("BattingActive",true)
 player:SetAttribute("HitActive",true)
 player:SetAttribute("Power",4)
 check(not buttons.basic_training.Active,"Power refresh during batting disables selection")
 player:SetAttribute("HitActive",false)
 check(not buttons.basic_training.Active,"finishing a hit does not enable changes while batting")
 player:SetAttribute("BattingActive",false)
 check(buttons.basic_training.Active,"leaving batting restores ground selection without another progression change")
 player:SetAttribute("BattingActive",true)
 player:SetAttribute("HitActive",true)
 player:SetAttribute("Power",8)
 player:SetAttribute("BattingActive",false)
 check(not buttons.basic_training.Active,"leaving during flight keeps selection disabled")
 player:SetAttribute("HitActive",false)
 check(buttons.basic_training.Active,"flight completion restores selection after the player has left batting")
 buttons.basic_training.Activated:Fire()
 check(#requests==1 and requests[1].n==2 and requests[1][1]=="Select" and requests[1][2]=="basic_training",
  "restored button submits only selection intent")
 player:SetAttribute("WorldTraveling",true)
 check(not buttons.basic_training.Active,"travel disables selection")
 player:SetAttribute("WorldTraveling",false)
 check(buttons.basic_training.Active,"travel completion restores selection")
 player:SetAttribute("SelectedTrainingGround","basic_training")
 check(not buttons.basic_training.Active,"selected ground refreshes after server confirmation")
 check(buttons.advanced_training.Active,"previously selected unlocked ground becomes selectable")
 return {passed=passed}
end
