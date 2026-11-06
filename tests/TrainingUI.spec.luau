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
  local function find() return nil end
  return {Name=name,AbsoluteSize=Vector2.new(720,550),Activated=signal(),GetPropertyChangedSignal=function() return signal() end,
   FindFirstChild=find,Visual={FindFirstChildOfClass=function() return {} end},Scrim={Visible=false}}
 end
 -- The login's offline result (read once, as the client starts): 8 hours held by the run cap, and
 -- a 3x offer the run cap holds below three times the reward.
 local attributes = {DataLoaded=true,Rebirths=1,Level=4,LevelCap=20,Power=0,WorldUnlocked_world_1=true,
  OfflineSeconds=8*3600,OfflinePowerEarned=8740,OfflineTriplePower=17481,OfflineTripleAvailable=true}
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
 player.Character={Parent={},FindFirstChildOfClass=function() return {Health=100} end}
 local buttons,requests,labels,teleports,menus={},{},{},{},{}
 local UI={Colors={},Icons={},Showcase={},Number=tostring,Compact=tostring,Notify=function() end,CardState=function() end}
 function UI.Badge() return object("Badge") end
 function UI.Icon() return object("Icon") end
 function UI.Menu(name)
  menus[name]=object("Menu")
  return menus[name],object("Panel"),function() end
 end
 -- The Welcome Back popup: records what the client shows on it.
 local popups,delayed={},{}
 function UI.RewardPopup(name)
  local popup={claim=object("Claim"),offer=object("Offer"),shown=false,celebrated=0}
  function popup.show(visible) popup.shown=visible end
  function popup.setDetails(lines) popup.lines=lines end
  function popup.setOffer(text,price) popup.offerText,popup.offerPrice=text,price end
  function popup.setAmount(value) popup.amount=value end
  function popup.countTo(value,_,onDone) popup.amount=value if onDone then onDone() end end
  function popup.celebrate() popup.celebrated+=1 end
  popups[name]=popup
  return popup
 end
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
  buttons[parent.Name .. "." .. name]=button
  return button
 end
 function UI.SetButton(button,text,enabled)
  button.Text,button.Active=text,enabled
 end
 local registered={}
 local Interfaces={CloseAll=function() end,Changed=signal(),IsOpen=function() return false end}
 function Interfaces.Register(name,show) registered[name]=show show(false) end
 function Interfaces.Open(name) registered[name](true) end
 function Interfaces.CanOpen()
  return attributes.DataLoaded and not attributes.TrainingActive and not attributes.BattingActive
   and not attributes.HitActive and not attributes.WorldTraveling
 end
 local remote={OnClientEvent=signal(),FireServer=function(_,...) table.insert(requests,table.pack(...)) end}
 local teleport={FireServer=function(_,...) table.insert(teleports,table.pack(...)) end}
 local trainingConfig=compile(sources.TrainingConfig)()
 trainingConfig.Get("cosmic_rift").gamePassId=111 -- Fixture: only this pass "exists".
 local modules={UICommon=UI,HubInterfaces=Interfaces,
  EquipmentConfig=compile(sources.EquipmentConfig)(),TrainingConfig=trainingConfig,
  ProgressionConfig=compile(sources.ProgressionConfig)(),SwingConfig={},WorldConfig=compile(sources.WorldConfig)(),
  JuiceConfig=compile(sources.JuiceConfig)(),FieldConfig=compile(sources.FieldConfig)(),
  GameAudio={Play=function() end,Preload=function() end}}
 -- MonetizationConfig requires the other configs; it gets these copies.
 local monetization=compile(sources.MonetizationConfig)
 setfenv(monetization,setmetatable({game={GetService=function() return {WaitForChild=function(_,name) return name end} end},
  require=function(name) return assert(modules[name],name) end},{__index=getfenv()}))
 modules.MonetizationConfig=monetization()
 local storage={}
 -- The real client fetches its RemoteEvents directly rather than requiring them.
 function storage:WaitForChild(name)
  return name=="TrainingRequest" and remote or name=="TrainingTeleport" and teleport or name
 end
 local services={Players={LocalPlayer=player},RunService={},ContextActionService={},ReplicatedStorage=storage,TweenService={},Debris={},MarketplaceService={}}
 local environment=setmetatable({
  game={GetService=function(_,name) return assert(services[name],name) end},
  script={Parent={UICommon="UICommon",HubInterfaces="HubInterfaces"}},
  require=function(name) return assert(modules[name],name) end,
  task={defer=function() end,spawn=function() end,delay=function(_,callback) table.insert(delayed,callback) end},
  Instance={new=function(className) return object(className) end},
 },{__index=getfenv()})
 local client=compile(sources.TrainingClient)
 setfenv(client,environment)
 client()
 -- The Training base is 5 a practice hit at every Level (every 2 s); one Rebirth doubles it.
 check(labels["basic_training.Rate"].Text == "x1 POWER  |  5 Power / second", "starting Ball stacks with Rebirth in rate preview")
 player:SetAttribute("EquippedBall","practice_ball")
 check(labels["basic_training.Rate"].Text == "x1 POWER  |  15 Power / second", "equipping a Ball updates effective Training rate")
 player:SetAttribute("EquippedBat","amethyst_bat")
 check(labels["basic_training.Rate"].Text == "x1 POWER  |  15 Power / second", "the Bat does not alter Training preview")
 player:SetAttribute("EquippedBall","bubblegum_ball")
 check(labels["enchanted_grove.Rate"].Text == "x5 POWER  |  125 Power / second", "ground, Ball and Rebirth compose once in preview")
 player:SetAttribute("Level",20)
 check(labels["enchanted_grove.Rate"].Text == "x5 POWER  |  125 Power / second", "the preview is the same at every Level")
 -- The purchased Power multiplier (the server's tier count) is in the preview too: 2x.
 player:SetAttribute("PowerMultiplierTier",1)
 check(labels["enchanted_grove.Rate"].Text == "x5 POWER  |  250 Power / second", "the purchased Power multiplier is in the preview")
 player:SetAttribute("PowerMultiplierTier",nil)
 player:SetAttribute("Level",4)
 check(buttons.basic_training.Active and buttons.basic_training.Text == "GO","unlocked ground offers a teleport")
 check(not buttons.enchanted_grove.Active and buttons.enchanted_grove.Text == "REQUIRES 2 REBIRTHS","locked Rebirth ground stays disabled")
 check(not buttons.dragons_lair.Active and buttons.dragons_lair.Text == "COMING SOON","paid ground without a pass id cannot be bought")
 check(buttons.cosmic_rift.Active and buttons.cosmic_rift.Text == "BUY  R$ 500","paid ground offers its pass")
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
 buttons.cosmic_rift.Activated:Fire()
 check(#requests==1 and requests[1].n==2 and requests[1][1]=="Buy" and requests[1][2]=="cosmic_rift","BUY asks the server for the pass prompt")
 buttons.enchanted_grove.Activated:Fire()
 check(#requests==1 and #teleports==1,"locked button sends nothing")
 player:SetAttribute("WorldTraveling",true)
 check(not buttons.basic_training.Active,"travel disables the menu")
 player:SetAttribute("WorldTraveling",false)
 check(buttons.basic_training.Active,"travel completion restores the menu")
 check(not buttons.caveman_camp.Active and buttons.caveman_camp.Text == "UNLOCK WORLD 2","World 2 grounds wait for World 2")
 check(not buttons.time_machine_lab.Active and buttons.time_machine_lab.Text == "UNLOCK WORLD 2","a shared-pass ground in a locked World is not sold")
 buttons.caveman_camp.Activated:Fire()
 buttons.time_machine_lab.Activated:Fire()
 check(#requests==1 and #teleports==1,"grounds in a locked World send nothing")
 player:SetAttribute("WorldUnlocked_world_2",true)
 check(buttons.caveman_camp.Active and buttons.caveman_camp.Text == "GO","unlocking World 2 opens its free ground")
 check(not buttons.pharaohs_tomb.Active and buttons.pharaohs_tomb.Text == "REQUIRES 8 REBIRTHS","World 2 Rebirth tiers continue on")
 check(buttons.time_machine_lab.Active and buttons.time_machine_lab.Text == "BUY  R$ 500","Time Machine Lab sells Cosmic Rift's pass")
 buttons.time_machine_lab.Activated:Fire()
 check(#requests==2 and requests[2][1]=="Buy" and requests[2][2]=="time_machine_lab","BUY names the ground; the server resolves its pass")
 player:SetAttribute("TrainingPass_cosmic_rift",true)
 check(buttons.cosmic_rift.Active and buttons.cosmic_rift.Text == "GO","owned pass turns BUY into GO")
 check(buttons.time_machine_lab.Active and buttons.time_machine_lab.Text == "GO","the shared pass opens both of its grounds")
 player:SetAttribute("Rebirths",2)
 check(buttons.enchanted_grove.Active and buttons.enchanted_grove.Text == "GO","Rebirth unlock refreshes the menu")
 -- Welcome Back (it opens a second after the data loads): the amount counts up to the login's
 -- reward, one line says how long the player was away, and the 3x button shows the server's
 -- total with the 3x (not three times the reward), with SOON while its product id is 0.
 local function openWelcomeBack()
  local queued=delayed
  delayed={}
  for _,callback in queued do callback() end
  return popups.OfflineTrainingGui
 end
 local welcome=openWelcomeBack()
 check(welcome.shown and welcome.amount==8740 and welcome.offerText=="+17481" and welcome.offerPrice==nil,
  "the 3x button shows the server's capped total, not three times the reward, and SOON without a product")
 check(#welcome.lines==1 and welcome.lines[1]=="Away 8h 0m (max)","one small line says how long the player was away")
 -- Bought: the amount counts up to the server's new total, it celebrates and the 3x goes away.
 player:SetAttribute("OfflineTriplePower",14481)
 player:SetAttribute("OfflineTripleAvailable",false)
 check(welcome.amount==14481 and welcome.celebrated==1 and welcome.offerText==nil,
  "after the 3x the popup counts up to the server's new total, celebrates and hides the 3x")
 local function rerun(changes)
  for name,value in changes do attributes[name]=value end
  local again=compile(sources.TrainingClient)
  setfenv(again,environment)
  again()
  return openWelcomeBack()
 end
 -- With a product id the badge shows the Robux price.
 trainingConfig.OfflineTriple.productId=777
 local priced=rerun({OfflineSeconds=3*3600+12*60,OfflinePowerEarned=500,OfflineTriplePower=1500,OfflineTripleAvailable=true})
 trainingConfig.OfflineTriple.productId=0
 check(priced.shown and priced.offerPrice==10 and priced.lines[1]=="Away 3h 12m","the price badge shows 10 Robux once the product exists")
 -- At the Level Cap offline Power still shows; there is no 3x, and a short line says to Rebirth.
 local capped=rerun({OfflineSeconds=2*3600,OfflinePowerEarned=5000,OfflineTriplePower=5000,OfflineTripleAvailable=false,
  OfflineNewLevel=20,LevelCap=20})
 check(capped.shown and capped.amount==5000 and capped.offerText==nil and #capped.lines==2
  and capped.lines[2].text=="MAX LEVEL - REBIRTH AVAILABLE","at the Level Cap: the Power earned, no 3x and the Rebirth line")
 -- Under five minutes away there is no Welcome Back.
 local short=rerun({OfflineSeconds=299,OfflinePowerEarned=40,OfflineNewLevel=4})
 check(not short.shown and short.amount==nil,"no Welcome Back under five minutes away")
 return {passed=passed}
end
