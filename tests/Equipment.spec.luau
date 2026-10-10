-- Run with the repository source strings supplied by the test runner. No live saves
-- or Studio Instances are changed: persistence and players below are in-memory fakes.
return function(sources)
 local passed = 0
 local function check(condition, message)
  assert(condition, message)
  passed += 1
 end
 local function signal()
  local callbacks = {}
  return {
   Connect = function(_, callback) table.insert(callbacks, callback) return {Disconnect = function() end} end,
   Fire = function(_, ...) for _, callback in callbacks do callback(...) end end,
  }
 end
 local function object(className)
  local props, attributes, children = {ClassName = className}, {}, {}
  if className == "RemoteEvent" then props.OnServerEvent, props.replies = signal(), {} end
  local methods = {
   GetAttribute = function(_, name) return attributes[name] end,
   SetAttribute = function(_, name, value) attributes[name] = value end,
   GetAttributes = function() return table.clone(attributes) end,
   GetChildren = function() return table.clone(children) end,
   FindFirstChild = function(_, name)
    for _, child in children do if child.Name == name then return child end end
   end,
   FindFirstChildOfClass = function(_, name)
    for _, child in children do if child:IsA(name) then return child end end
   end,
   IsA = function(_, name) return name == className end,
   Kick = function(self, reason) self.KickReason = reason end,
   FireClient = function(self, player, ...) self.replies[player] = table.pack(...) end,
  }
  return setmetatable({}, {
   __index = function(self, key)
    if key == "_children" then return children end
    return methods[key] or props[key] or methods.FindFirstChild(self, key)
   end,
   __newindex = function(self, key, value)
    if key == "Parent" then
     if props.Parent then
      local index = table.find(props.Parent._children, self)
      if index then table.remove(props.Parent._children, index) end
     end
     if value then table.insert(value._children, self) end
    end
    props[key] = value
   end,
  })
 end
 local realHttp = game:GetService("HttpService")
 local function copy(value)
  return value and realHttp:JSONDecode(realHttp:JSONEncode(value)) or nil
 end
 local Equipment = assert(loadstring(sources.EquipmentConfig))()
 local Worlds = assert(loadstring(sources.WorldConfig))()
 local Progression = assert(loadstring(sources.ProgressionConfig))()
 local Training = assert(loadstring(sources.TrainingConfig))()
 local saved, calls, simulatedFailures = {}, {}, {}
 local loseResponse = {}
 local store = {}
 function store:UpdateAsync(key, transform)
  calls[key] = (calls[key] or 0) + 1
  if simulatedFailures[key] then error("simulated DataStore outage") end
  local value = transform(copy(saved[key]))
  if value == nil then return nil end
  saved[key] = copy(value)
  if loseResponse[key] then loseResponse[key]=nil error("simulated committed response loss") end
  return copy(value)
 end
 local players = object("Players")
 players.PlayerAdded, players.PlayerRemoving = signal(), signal()
 function players:GetPlayers() return self:GetChildren() end
 local now, tokenId = 100, 0
 local shutdown
 local storage = object("ReplicatedStorage")
 function storage:WaitForChild(name) return self:FindFirstChild(name) or name end
 local remote = object("RemoteEvent")
 remote.Name, remote.Parent = "EquipmentUpgrade", storage
 local workspace = object("Workspace")
 local modules = {EquipmentConfig = Equipment, WorldConfig = Worlds, ProgressionConfig = Progression, TrainingConfig = Training}
 local env = setmetatable({
  game = {
   ReplicatedStorage = storage,
   GetService = function(_, name)
    if name == "Players" then return players end
    if name == "ReplicatedStorage" then return storage end
    if name == "DataStoreService" then return {GetDataStore = function(_, name)
     check(name == "PlayerProgression", "must reuse the existing store") return store
    end} end
    if name == "HttpService" then return {GenerateGUID = function()
     tokenId += 1 return "offer-" .. tokenId
    end} end
    error("Unexpected service " .. name)
   end,
   BindToClose = function(_, callback) shutdown = callback end,
  },
  Instance = {new = object},
  script = {Parent = {WaitForChild = function(_, name) return name end}},
  require = function(name) return assert(modules[name], name) end,
  os = {clock = function() return now end, time = function() return math.floor(now) end},
  task = {wait = function(seconds) now += seconds end, spawn = function() end},
  print = function() end, warn = function() end,
 }, {__index = getfenv()})
 local dataFn = assert(loadstring(sources.PlayerData))
 setfenv(dataFn, env)
 local Data = dataFn()
 modules.PlayerData = Data
 Data.Start()
 local function join(id)
  local p = object("Player") p.UserId, p.Name = id, "Test" .. id p.Parent = players
  local character = object("Model") character.Name, character.Parent = p.Name, workspace
  local humanoid = object("Humanoid") humanoid.Name, humanoid.Health, humanoid.Parent = "Humanoid", 100, character
  local root = object("Part") root.Name, root.Parent = "HumanoidRootPart", character
  p.Character = character
  players.PlayerAdded:Fire(p)
  return p
 end
 local function leave(p) players.PlayerRemoving:Fire(p) p.Parent = nil end

 for _, category in Equipment.CategoryOrder do
  local list = Equipment.GetItems(category)
  local owned, equipped = Equipment.NormalizeOwnership(category, nil, nil, true)
  check(owned[equipped] and Equipment.IsStarting(category, equipped), "new player starter")
  check(Equipment.GetById(list[2].id).category == category, "ID category lookup")
  check(Equipment.IsFinal(category, list[#list].id), "final item")
  local legacy, chosen = Equipment.NormalizeOwnership(category, nil, list[3].id, true)
  check(chosen == list[3].id and legacy[chosen] and legacy[list[1].id], "legacy equipped preservation")
  check(Equipment.GetNextPurchase(category, legacy).id == list[4].id, "legacy progression gap")
  local sanitized, fallback = Equipment.NormalizeOwnership(category,
   {[list[2].id] = "true", [list[3].id] = false, invalid = true, [1] = list[4].id}, list[4].id, false)
  check(fallback == list[1].id and not sanitized[list[4].id], "malformed ownership cannot grant an equipped item")
 end
 local wrong = Equipment.NormalizeOwnership("Bat", {baseball = true, metal_bat = true}, "metal_bat", false)
 check(wrong.metal_bat and not wrong.baseball, "wrong-category ownership removed")

 saved.Player_1 = {SchemaVersion = 2, Cash = 5000, EquippedBat = "alloy_bat",
  EquippedBall = "practice_ball", EquippedTee = "rubber_tee",
  UnlockedWorlds = {world_1 = true, world_2 = true}, CompletedWorlds = {world_1 = true}, OtherProgress = 42}
 local a, b = join(1), join(2)
 check(Data.IsReady(a) and Data.IsReady(b), "players loaded")
 check(a.leaderstats.Cash.Value == 5000 and a:GetAttribute("WorldUnlocked_world_2"), "migration preserves Cash/worlds")
 check(Data.OwnsEquipment(a, "Bat", "alloy_bat") and Data.OwnsEquipment(a, "Bat", "wood_bat"), "migration grants current/starter")
 check(not Data.OwnsEquipment(b, "Bat", "alloy_bat"), "ownership is isolated")
 check(not Data.EquipEquipment(b, "Bat", "alloy_bat"), "unowned equip rejected")
 check(not Data.EquipEquipment(a, "Bat", "practice_ball"), "wrong category rejected")
 a.OwnedBats:SetAttribute("carbon_bat", true)
 check(not Data.EquipEquipment(a, "Bat", "carbon_bat"), "replicated display cannot grant ownership")
 a.OwnedBats:SetAttribute("carbon_bat", nil)
 local offer = a:GetAttribute("EquipmentPurchaseToken_Bat")
 a:SetAttribute("BattingActive", true)
 check(not Data.PurchaseNextEquipment(a, "Bat", offer), "purchase blocked while batting")
 check(not Data.EquipEquipment(a, "Bat", "wood_bat"), "equip blocked while batting")
 a:SetAttribute("BattingActive", false)
 a:SetAttribute("HitActive", true)
 check(not Data.PurchaseNextEquipment(a, "Bat", offer), "purchase blocked after exiting during flight")
 check(not Data.EquipEquipment(a, "Bat", "wood_bat"), "equip blocked after exiting during flight")
 a:SetAttribute("HitActive", false)
 check(Data.PurchaseNextEquipment(a, "Bat", offer), "valid purchase")
 check(a.leaderstats.Cash.Value == 3000 and a:GetAttribute("EquippedBat") == "carbon_bat", "price and auto-equip")
 check(Data.OwnsEquipment(a, "Bat", "alloy_bat"), "previous equipment retained")
 check(not Data.PurchaseNextEquipment(a, "Bat", offer) and a.leaderstats.Cash.Value == 3000, "duplicate charged once")
 check(Data.EquipEquipment(a, "Bat", "wood_bat"), "older owned item equips")
 check(Data.GetNextEquipment(a, "Bat") == nil, "older equip cannot regress progression")
 check(Data.EquipEquipment(a, "Bat", "wood_bat") and a.leaderstats.Cash.Value == 3000, "repeat equip is free")
 check(not Data.PurchaseNextEquipment(b, "Bat", b:GetAttribute("EquipmentPurchaseToken_Bat")), "insufficient Cash")

 -- Exercise the real remote handler with malformed/spam requests and two players.
 local serverFn = assert(loadstring(sources.EquipmentServer)) setfenv(serverFn, env) serverFn()
 b.leaderstats.Cash.Value = 2000
 local bOffer = b:GetAttribute("EquipmentPurchaseToken_Bat")
 remote.OnServerEvent:Fire(b, "Purchase", "Bat", bOffer)
 remote.OnServerEvent:Fire(b, "Purchase", "Bat", bOffer)
 now += 1
 remote.OnServerEvent:Fire(b, "Purchase", "Bat", bOffer)
 check(b.leaderstats.Cash.Value == 1700 and b:GetAttribute("EquippedBat") == "metal_bat", "spam/replay cannot skip next item")
 check(not Data.OwnsEquipment(b, "Bat", "alloy_bat"), "replay never grants next equipment")
 remote.OnServerEvent:Fire(a, "Equip", "Bat", "alloy_bat")
 check(a:GetAttribute("EquippedBat") == "alloy_bat", "other player has independent cooldown/state")
 now += 1
 remote.OnServerEvent:Fire(b, "Equip", "Bat", "baseball")
 remote.OnServerEvent:Fire(b, {}, {}, {})
 remote.OnServerEvent:Fire(b, "Purchase", "Bat", {price = 0})
 remote.OnServerEvent:Fire(b, "Purchase", "Bat", "carbon_bat")
 check(b:GetAttribute("EquippedBat") == "metal_bat" and b.leaderstats.Cash.Value == 1700, "forged request inputs rejected")
 check(Data.EquipEquipment(a, "Bat", "wood_bat"), "select old item before saving")
 leave(a)
 check(saved.Player_1.SchemaVersion == 5 and saved.Player_1.Session == nil, "version 5 save and lease release")
 check(saved.Player_1.OwnedBats.carbon_bat and saved.Player_1.EquippedBat == "wood_bat", "ownership and selection saved separately")
 check(saved.Player_1.OtherProgress == 42 and saved.Player_1.UnlockedWorlds.world_2, "other progression preserved")
 local returned = join(1)
 check(returned.leaderstats.Cash.Value == 3000 and Data.OwnsEquipment(returned, "Bat", "carbon_bat")
  and returned:GetAttribute("EquippedBat") == "wood_bat", "rejoin restores purchased ownership and older selection")

 saved.Player_3 = {SchemaVersion = 3, Cash = 100, EquippedBat = "carbon_bat", OwnedBats = {wood_bat = true},
  EquippedBall = "invalid", OwnedBalls = "malformed", OwnedTees = {basic_tee = true, baseball = true}}
 local repaired = join(3)
 check(repaired:GetAttribute("EquippedBat") == "wood_bat" and not Data.OwnsEquipment(repaired, "Bat", "carbon_bat"), "modern unowned equipped ID falls back")
 check(repaired:GetAttribute("EquippedBall") == "baseball" and Data.OwnsEquipment(repaired, "Ball", "baseball"), "invalid item/collection repaired")
 saved.Player_4 = {SchemaVersion = 999, Cash = 999}
 local future = join(4)
 check(not Data.IsReady(future) and future.KickReason ~= nil and saved.Player_4.Cash == 999, "future schema fails closed")
 saved.Player_5 = {SchemaVersion = 2, Cash = -100}
 local invalid = join(5)
 check(not Data.IsReady(invalid) and saved.Player_5.Cash == -100, "invalid balance not overwritten")
 simulatedFailures.Player_6 = true
 local failed = join(6)
 leave(failed)
 check(calls.Player_6 == 3 and saved.Player_6 == nil and not failed.leaderstats, "bounded failed load never saves defaults")
 saved.Player_7 = {SchemaVersion = 2, Cash = 999, Session = {Id = "different-server", ExpiresAt = now + 180}}
 local locked = join(7)
 check(not Data.IsReady(locked) and saved.Player_7.Session.Id == "different-server", "other session lease protected")
 check(type(shutdown) == "function", "BindToClose remains registered")
 -- Exercise actual server progression operations against the same persistence lifecycle.
 local fresh = join(20)
 local state = Data.GetProgression(fresh)
 check(state.Power == 0 and state.Level == 1 and state.Rebirths == 0 and state.LevelCap == 10, "progression defaults")
 check(not Data.CanRebirth(fresh) and not Data.TryRebirth(fresh), "early Rebirth rejected")
 check(Progression.PowerRequiredForNextLevel(3) > Progression.PowerRequiredForNextLevel(2), "requirements increase")
 check(Data.GrantPower(fresh, 60, "Test") and fresh:GetAttribute("Power") == 60, "partial Power grant")
 check(Data.GrantPower(fresh, 490, "Test") and fresh:GetAttribute("Level") == 3
  and fresh:GetAttribute("Power") == 50, "multiple levels consume requirements")
 for _, bad in {-1, 0/0, math.huge, "100", 1.5, Progression.MaxBaseGrant + 1} do
  check(not Data.GrantPower(fresh, bad, "Test"), "invalid Power grant rejected")
 end
 check(not Data.GrantPower(future, 100, "Test") and not Data.GrantPower(fresh, 10, {}), "invalid session/source rejected")
 state.Level = 500
 fresh:SetAttribute("Level",500)
 check(Data.GetProgression(fresh).Level == 3, "copies and display attributes cannot grant levels")
 check(Data.GrantPower(fresh, 1000000, "Test") and Data.GetProgression(fresh).Level == 10
  and Data.GetProgression(fresh).Power == 0, "cap enforced and overflow discarded")
 local ok, capped = Data.GrantPower(fresh, 20, "Test")
 check(ok and capped.powerGranted == 0 and Data.CanRebirth(fresh), "no Power banked at cap and eligibility exposed")
 fresh:SetAttribute("HitActive",true)
 check(not Data.TryRebirth(fresh), "active hit cannot Rebirth")
 fresh:SetAttribute("HitActive",false)
 fresh:SetAttribute("BattingActive",true)
 check(not Data.TryRebirth(fresh), "batting cannot Rebirth")
 fresh:SetAttribute("BattingActive",false)
 fresh.leaderstats.Cash.Value = 2000
 check(Data.PurchaseNextEquipment(fresh,"Bat",fresh:GetAttribute("EquipmentPurchaseToken_Bat")), "equipment before Rebirth")
 fresh:SetAttribute("WorldUnlocked_world_2",true)
 fresh:SetAttribute("WorldCompleted_world_1",true)
 check(Data.TryRebirth(fresh), "eligible Rebirth succeeds")
 state = Data.GetProgression(fresh)
 check(state.Rebirths == 1 and state.Level == 1 and state.Power == 0 and state.LevelCap == 20, "Rebirth resets and cap grows")
 check(not Data.TryRebirth(fresh), "duplicate Rebirth rejected")
 check(fresh.leaderstats.Cash.Value == 1700 and Data.OwnsEquipment(fresh,"Bat","metal_bat")
  and fresh:GetAttribute("EquippedBat") == "metal_bat" and fresh:GetAttribute("WorldUnlocked_world_2"), "Rebirth preserves unrelated progression")
 ok, state = Data.GrantPower(fresh, 30, "FutureTraining")
 check(ok and state.powerGranted == 60 and fresh:GetAttribute("Power") == 60, "central Rebirth multiplier")
 check(Progression.GetLaunchSpeed(Data.GetProgression(fresh).Level) == Progression.GetLaunchSpeed(1), "Power/Rebirth do not affect same-level launch")
 check(Progression.GetLaunchSpeed(10) > Progression.GetLaunchSpeed(1) * 3, "Level 10 launch substantially stronger")
 leave(fresh)
 fresh = join(20)
 state = Data.GetProgression(fresh)
 check(state.Rebirths == 1 and state.LevelCap == 20 and state.Level == 1 and state.Power == 60, "new progression saves and rejoins")
 check(fresh.leaderstats.Cash.Value == 1700 and fresh:GetAttribute("EquippedBat") == "metal_bat"
  and fresh:GetAttribute("WorldCompleted_world_1"), "equipment Cash and worlds survive new schema")
 check(returned:GetAttribute("Level") == 1 and returned:GetAttribute("Power") == 0, "legacy saves gain defaults without Bat conversion")
 saved.Player_21 = {SchemaVersion = 4, Cash = 765, Power = -4, Level = 999, Rebirths = -5, LevelCap = 999999}
 local malformed = join(21)
 state = Data.GetProgression(malformed)
 check(state.Rebirths == 0 and state.LevelCap == 10 and state.Level == 10 and state.Power == 0
  and malformed.leaderstats.Cash.Value == 765, "malformed fields cannot increase derived cap or lose Cash")
 for _, bad in {0/0, math.huge, -1, "bad", 1.5} do
  local normalized = Progression.Normalize({Power=bad, Level=bad, Rebirths=bad, LevelCap=math.huge},false)
  check(normalized.Power == 0 and normalized.Level == 1 and normalized.Rebirths == 0 and normalized.LevelCap == 10, "malformed numeric fields repaired")
 end
 local migrated = Progression.Normalize({Level=900, Power=999999, Rebirths=99},true)
 check(migrated.Level == 1 and migrated.Power == 0 and migrated.Rebirths == 0, "legacy fields cannot grant new progression")
 local over = Progression.Normalize({Level=2, Power=1305, Rebirths=0},false)
 check(over.Level == 4 and over.Power == 5, "saved excess Power normalizes consistently")
 check(Worlds.Get("world_1").endDistance == 5000 and Worlds.Get("world_2").endDistance == 6000, "world endpoints unchanged")
 -- Training uses a private selection, and offline grants share the atomic login transaction.
 local trainee = join(30)
 check(trainee:GetAttribute("SelectedTrainingGround")==Training.DefaultGround and trainee:GetAttribute("OfflinePowerEarned")==0,"new player ground and no historical reward")
 check(not Data.SelectTrainingGround(trainee,"advanced_training"),"locked ground rejected")
 check(not Data.SelectTrainingGround(trainee,{}) and not Data.SelectTrainingGround(trainee,"fake"),"malformed selections rejected")
 trainee:SetAttribute("SelectedTrainingGround","expert_training")
 check(Data.GetTrainingGround(trainee).id==Training.DefaultGround,"display selection not authoritative")
 check(Data.GrantPower(trainee,1000000,"Test") and Data.TryRebirth(trainee),"Rebirth unlock setup")
 check(Data.SelectTrainingGround(trainee,"advanced_training"),"Rebirth unlocks ground")
 trainee:SetAttribute("TrainingActive",true)
 check(not Data.SelectTrainingGround(trainee,"basic_training"),"cannot switch during training")
 check(not Data.EquipEquipment(trainee,"Bat","wood_bat"),"training blocks equipment changes")
 local ground=Data.GetTrainingGround(trainee)
 local ok, gain=Data.GrantPower(trainee,ground.basePower,"ActiveTraining")
 check(ok and gain.powerGranted==100 and trainee:GetAttribute("Level")==2,"active training uses central multiplier/advancement")
 trainee:SetAttribute("TrainingActive",false)
 leave(trainee)
 check(saved.Player_30.SelectedTrainingGround=="advanced_training" and saved.Player_30.LastLogoutTime==math.floor(now),"selection and logout saved")
 trainee=join(30)
 check(trainee:GetAttribute("SelectedTrainingGround")=="advanced_training" and trainee:GetAttribute("OfflinePowerEarned")==0,"selection rejoin and zero offline duration")
 local nowStamp=100000
 local amount, seconds=Training.GetOfflineReward(nowStamp-60,nowStamp,"basic_training")
 check(amount==150 and seconds==60,"short offline duration")
 amount,seconds=Training.GetOfflineReward(nowStamp-3600,nowStamp,"advanced_training")
 check(amount==22500 and seconds==3600,"selected ground offline rate")
 amount,seconds=Training.GetOfflineReward(1,nowStamp,"basic_training")
 check(seconds==Training.MaximumOfflineSeconds and amount==72000,"offline cap enforced")
 for _, timestamp in {0,-1,"bad",math.huge,0/0,1.5,nowStamp+10} do
  check(Training.GetOfflineReward(timestamp,nowStamp,"basic_training")==0,"malformed or future timestamp cannot award")
 end
 check(Training.GetOfflineReward(nil,nowStamp,"basic_training")==0,"missing timestamp cannot award")
 saved.Player_31={SchemaVersion=5,Cash=321,Power=0,Level=1,Rebirths=2,LevelCap=30,SelectedTrainingGround="advanced_training",LastLogoutTime=math.floor(now)-10,OtherProgress=123}
 loseResponse.Player_31=true
 local offline=join(31)
 check(offline:GetAttribute("OfflinePowerEarned")==186 and offline:GetAttribute("Level")==2
  and offline:GetAttribute("Power")==86,"offline grant once despite committed response loss")
 check(saved.Player_31.LastLogoutTime==nil and saved.Player_31.OtherProgress==123,"timestamp consumed atomically and unknown fields preserved")
 check(offline.leaderstats.Cash.Value==321 and Data.GetTrainingGround(offline).id=="advanced_training","selected ground used instead of highest eligible")
 players.PlayerAdded:Fire(offline)
 check(offline:GetAttribute("Power")==86,"same session cannot reprocess offline reward")
 saved.Player_32={SchemaVersion=5,Cash=777,Power=3,Level=1,Rebirths=0,SelectedTrainingGround="expert_training",LastLogoutTime=math.floor(now)-60}
 local fallback=join(32)
 check(fallback:GetAttribute("SelectedTrainingGround")=="basic_training" and fallback:GetAttribute("OfflinePowerEarned")==150,"inaccessible selection falls back before offline grant")
 check(fallback:GetAttribute("Level")==2 and fallback:GetAttribute("Power")==53 and fallback.leaderstats.Cash.Value==777,"offline progression preserves Cash")
 saved.Player_33={SchemaVersion=4,Cash=999,Power=41,Level=2,Rebirths=1,LastLogoutTime=1}
 local legacy=join(33)
 check(legacy:GetAttribute("Power")==41 and legacy:GetAttribute("Level")==2 and legacy:GetAttribute("OfflinePowerEarned")==0,"migration preserves progression without fabricated offline time")
 saved.Player_34={SchemaVersion=5,Cash=500,Power=0,Level=10,Rebirths=0,SelectedTrainingGround="fake",LastLogoutTime=1}
 local atCap=join(34)
 check(atCap:GetAttribute("Power")==0 and atCap:GetAttribute("Level")==10 and atCap:GetAttribute("OfflinePowerEarned")==0,"offline cap overflow discarded")
 check(not Data.GetTrainingGround(failed),"failed loads cannot train")
 local offlineBase=Training.GetOfflineReward(100,7300,"basic_training")
 local simulated=Progression.Normalize({},false)
 Progression.Advance(simulated,offlineBase*Progression.GetPowerMultiplier(simulated.Rebirths))
 check(simulated.Level==8 and simulated.Power==4000,"several hours advance multiple levels")
 offlineBase=Training.GetOfflineReward(100,100000,"expert_training")
 simulated=Progression.Normalize({Rebirths=2,Level=1,Power=0},false)
 Progression.Advance(simulated,offlineBase*Progression.GetPowerMultiplier(simulated.Rebirths))
 check(simulated.Level==30 and simulated.Power==0,"capped offline duration can reach cap but never exceed it")
 check(Data.GetTrainingGround(trainee).id=="advanced_training" and Data.GetTrainingGround(fallback).id=="basic_training","players have independent selections")
 -- Two complete Rebirth cycles use the same public server operations as gameplay.
 local cyclist = join(100)
 cyclist.leaderstats.Cash.Value = 8000
 for _, category in Equipment.CategoryOrder do
  check(Data.PurchaseNextEquipment(cyclist, category, cyclist:GetAttribute("EquipmentPurchaseToken_" .. category)), "cycle equipment purchase")
 end
 cyclist:SetAttribute("WorldUnlocked_world_2", true)
 cyclist:SetAttribute("WorldCompleted_world_1", true)
 local preservedCash = cyclist.leaderstats.Cash.Value
 for rebirths = 0, 1 do
  state = Data.GetProgression(cyclist)
  local selected = Data.GetTrainingGround(cyclist).id
  check(state.Rebirths == rebirths and state.LevelCap == Progression.GetLevelCap(rebirths), "cycle starts at derived cap")
  check(not Data.CanRebirth(cyclist), "each cycle requires reaching its own cap")
  check(Data.GrantPower(cyclist, 1000000, "Test") and Data.CanRebirth(cyclist), "large grant reaches cycle cap")
  check(Data.GetProgression(cyclist).Level == Progression.GetLevelCap(rebirths), "large grant cannot exceed cycle cap")
  check(Data.TryRebirth(cyclist), "next cycle Rebirth succeeds")
  state = Data.GetProgression(cyclist)
  check(state.Rebirths == rebirths + 1 and state.Level == Progression.StartingLevel
   and state.Power == Progression.StartingPower and state.LevelCap == Progression.GetLevelCap(rebirths + 1), "complete atomic cycle result")
  check(not Data.TryRebirth(cyclist), "one capped state permits only one Rebirth")
  check(Data.GetTrainingGround(cyclist).id == selected, "valid selected ground survives Rebirth")
  check(cyclist.leaderstats.Cash.Value == preservedCash and cyclist:GetAttribute("WorldUnlocked_world_2")
   and cyclist:GetAttribute("WorldCompleted_world_1"), "cycle preserves Cash and world progression")
  for _, category in Equipment.CategoryOrder do
   local entries = Equipment.GetItems(category)
   check(Data.OwnsEquipment(cyclist, category, entries[1].id) and Data.OwnsEquipment(cyclist, category, entries[2].id)
    and cyclist:GetAttribute("Equipped" .. category) == entries[2].id, "cycle preserves owned and equipped equipment")
  end
  local nextGround = Training.Grounds[rebirths + 2]
  check(Data.SelectTrainingGround(cyclist, nextGround.id), "newly eligible ground immediately selectable")
  local granted, tick = Data.GrantPower(cyclist, nextGround.basePower, "ActiveTraining")
  check(granted and tick.powerGranted == nextGround.basePower * Progression.GetPowerMultiplier(rebirths + 1), "new ground and Rebirth multiplier compose")
 end
 leave(cyclist)
 local cycleRecord = saved.Player_100
 check(cycleRecord.Rebirths == 2 and cycleRecord.LevelCap == 30 and cycleRecord.SelectedTrainingGround == "expert_training", "two Rebirths and selected ground saved")
 check(cycleRecord.LastLogoutTime == math.floor(now) and cycleRecord.Session == nil, "Rebirth save retains offline lifecycle and releases lease")
 cyclist = join(100)
 check(Data.GetProgression(cyclist).Rebirths == 2 and Data.GetTrainingGround(cyclist).id == "expert_training"
  and cyclist.leaderstats.Cash.Value == preservedCash, "multiple cycles survive rejoin")
 check(Data.GetProgression(b).Rebirths == 0 and Data.GetTrainingGround(b).id == Training.DefaultGround, "cycles do not change another player's state")

 -- Configuration may evolve after a selection; the transaction must revalidate it.
 saved.Player_101 = {SchemaVersion=5, Cash=42, Rebirths=1, Level=20, Power=0, SelectedTrainingGround="advanced_training"}
 local changedGround = join(101)
 local advanced = Training.Get("advanced_training")
 local previousRequirement = advanced.requiredRebirths
 advanced.requiredRebirths = 3
 check(Data.TryRebirth(changedGround), "configuration change does not break valid Rebirth")
 check(Data.GetTrainingGround(changedGround).id == Training.DefaultGround
  and changedGround:GetAttribute("SelectedTrainingGround") == Training.DefaultGround, "invalid selection safely falls back during Rebirth")
 advanced.requiredRebirths = previousRequirement

 -- Load the actual request script. The client sends intent only, with no values.
 local rebirthFn = assert(loadstring(sources.RebirthServer)) setfenv(rebirthFn, env) rebirthFn()
 local rebirthRemote = assert(storage:FindFirstChild("RebirthRequest"), "Rebirth remote must exist")
 local function cappedPlayer(id)
  local player = join(id)
  assert(Data.GrantPower(player, 1000000, "Test"))
  return player
 end
 local requester = join(110)
 requester:SetAttribute("Level", 9999)
 requester:SetAttribute("LevelCap", 1)
 requester:SetAttribute("Rebirths", 999)
 requester:SetAttribute("PowerGainMultiplier", 1000000)
 rebirthRemote.OnServerEvent:Fire(requester)
 check(Data.GetProgression(requester).Rebirths == 0 and Data.GetProgression(requester).Level == 1, "forged display progression cannot make Rebirth eligible")
 check(Data.GrantPower(requester, 10, "Test") and Data.GetProgression(requester).Power == 10, "forged multiplier cannot increase Power gain")
 check(rebirthRemote.replies[requester][1] == false, "ineligible request provides failure feedback")
 check(Data.GrantPower(requester, 1000000, "Test"), "remote capped fixture")
 for _, payload in {{99}, {{Rebirths=99, LevelCap=999, Power=1000}}, {"Confirm"}, {true}} do
  now += 2.1
  rebirthRemote.OnServerEvent:Fire(requester, table.unpack(payload))
  check(Data.GetProgression(requester).Rebirths == 0, "client supplied Rebirth values rejected")
 end
 now += 2.1
 rebirthRemote.OnServerEvent:Fire(requester, nil)
 check(Data.GetProgression(requester).Rebirths == 0, "even an explicit nil argument is rejected")
 now += 2.1
 rebirthRemote.OnServerEvent:Fire(requester)
 check(Data.GetProgression(requester).Rebirths == 1 and rebirthRemote.replies[requester][1] == true, "zero argument request performs authoritative Rebirth")
 for _ = 1, 25 do rebirthRemote.OnServerEvent:Fire(requester) end
 check(Data.GetProgression(requester).Rebirths == 1, "duplicate confirmation spam cannot repeat Rebirth")
 now += 2.1
 rebirthRemote.OnServerEvent:Fire(requester)
 check(Data.GetProgression(requester).Rebirths == 1 and rebirthRemote.replies[requester][1] == false, "stale request stays ineligible after cooldown")

 local busy = cappedPlayer(111)
 for _, attribute in {"TrainingActive", "BattingActive", "HitActive", "WorldTraveling"} do
  busy:SetAttribute(attribute, true)
  rebirthRemote.OnServerEvent:Fire(busy)
  check(Data.GetProgression(busy).Rebirths == 0 and rebirthRemote.replies[busy][1] == false, "Rebirth rejects " .. attribute)
  busy:SetAttribute(attribute, false)
  now += 2.1
 end
 local character, humanoid = busy.Character, busy.Character:FindFirstChildOfClass("Humanoid")
 humanoid.Health = 0
 rebirthRemote.OnServerEvent:Fire(busy)
 check(Data.GetProgression(busy).Rebirths == 0, "death before execution cannot Rebirth")
 humanoid.Health = 100
 now += 2.1
 busy.Character = nil
 rebirthRemote.OnServerEvent:Fire(busy)
 check(Data.GetProgression(busy).Rebirths == 0, "missing character cannot Rebirth")
 busy.Character = character
 now += 2.1
 character.Parent = nil
 rebirthRemote.OnServerEvent:Fire(busy)
 check(Data.GetProgression(busy).Rebirths == 0, "removed character cannot Rebirth")
 character.Parent = workspace
 now += 2.1
 rebirthRemote.OnServerEvent:Fire(busy)
 check(Data.GetProgression(busy).Rebirths == 1, "valid request recovers after invalid states clear")

 local independentA, independentB = cappedPlayer(112), cappedPlayer(113)
 rebirthRemote.OnServerEvent:Fire(independentA)
 rebirthRemote.OnServerEvent:Fire(independentB)
 check(Data.GetProgression(independentA).Rebirths == 1 and Data.GetProgression(independentB).Rebirths == 1, "request cooldown and processing state isolated per player")
 local nested = cappedPlayer(114)
 local originalTryRebirth, operationCalls = Data.TryRebirth, 0
 Data.TryRebirth = function(player)
  operationCalls += 1
  if operationCalls == 1 then rebirthRemote.OnServerEvent:Fire(player) end
  return originalTryRebirth(player)
 end
 rebirthRemote.OnServerEvent:Fire(nested)
 Data.TryRebirth = originalTryRebirth
 check(operationCalls == 1 and Data.GetProgression(nested).Rebirths == 1, "reentrant duplicate cannot enter a second transaction")
 local disconnected = cappedPlayer(115)
 leave(disconnected)
 local disconnectedRecord = copy(saved.Player_115)
 rebirthRemote.OnServerEvent:Fire(disconnected)
 check(saved.Player_115.Rebirths == disconnectedRecord.Rebirths and not Data.IsReady(disconnected), "disconnect before execution makes request inert")
 rebirthRemote.OnServerEvent:Fire(future)
 rebirthRemote.OnServerEvent:Fire(failed)
 check(saved.Player_4.SchemaVersion == 999 and saved.Player_6 == nil, "failed-load and future-schema requests never overwrite saves")

 local durable = cappedPlayer(116)
 rebirthRemote.OnServerEvent:Fire(durable)
 loseResponse.Player_116 = true
 leave(durable)
 check(saved.Player_116.Rebirths == 1 and saved.Player_116.Level == 1
  and saved.Player_116.Power == 0 and saved.Player_116.Session == nil, "Rebirth close save survives committed response loss exactly once")
 durable = join(116)
 check(Data.GetProgression(durable).Rebirths == 1 and Data.GetProgression(durable).LevelCap == 20, "saved Rebirth is restored after response loss")
 saved.Player_117 = {SchemaVersion=5, Cash=9, Rebirths=Progression.MaxRebirths,
  Level=Progression.GetLevelCap(Progression.MaxRebirths), LevelCap=1, Power=0}
 local maximum = join(117)
 check(not Data.CanRebirth(maximum) and not Data.TryRebirth(maximum), "technical Rebirth bound cannot overflow")
 check(Data.GetProgression(maximum).LevelCap == Progression.GetLevelCap(Progression.MaxRebirths), "saved cap is always derived even at maximum Rebirths")

 -- Pure boundary arithmetic covers every ground/rate, including locked combinations.
 -- Real login fixtures separately verify that locked selections fall back before payout.
 for rebirths = 0, 2 do
  for index, trainingGround in Training.Grounds do
   local label = trainingGround.id .. "/Rebirth" .. rebirths
   local multiplier = Progression.GetPowerMultiplier(rebirths)
   check(Training.IsUnlocked(trainingGround.id, rebirths) == (rebirths >= trainingGround.requiredRebirths), "central ground eligibility " .. label)
   local priorRate = index > 1 and Training.Grounds[index-1].basePower / Training.Grounds[index-1].interval or 0
   check(trainingGround.basePower / trainingGround.interval > priorRate, "ground base rates increase " .. label)
   for _, duration in {12, 3*60*60, Training.MaximumOfflineSeconds, Training.MaximumOfflineSeconds+60*60} do
    local base, seconds = Training.GetOfflineReward(nowStamp-duration, nowStamp, trainingGround.id)
    local eligibleSeconds = math.min(duration, Training.MaximumOfflineSeconds)
    local expectedBase = math.floor(eligibleSeconds * trainingGround.basePower / trainingGround.interval * Training.OfflinePowerRateMultiplier)
    check(base == expectedBase and seconds == eligibleSeconds, "offline duration boundary " .. label .. "/" .. duration)
    local rateState = Progression.Normalize({Rebirths=rebirths, Level=1, Power=0}, false)
    Progression.Advance(rateState, base * multiplier)
    check(rateState.Level <= Progression.GetLevelCap(rebirths)
     and (rateState.Level < rateState.LevelCap or rateState.Power == 0), "offline multiplier respects cap " .. label .. "/" .. duration)
   end
  end
 end

 -- Move the fake clock only after earlier session assertions; every login below gets
 -- a fresh lease. These are actual PlayerData loads/grants/saves, never live DataStores.
 now = nowStamp
 local fixtureId = 200
 for rebirths = 0, 2 do
  for _, trainingGround in Training.Grounds do
   fixtureId += 1
   local key = "Player_" .. fixtureId
   saved[key] = {SchemaVersion=5, Cash=456, Rebirths=rebirths, Level=1, Power=0,
    LevelCap=999999, SelectedTrainingGround=trainingGround.id, LastLogoutTime=now-12,
    UnlockedWorlds={world_1=true, world_2=true}, CompletedWorlds={world_1=true}, OtherProgress=73}
   local fixture = join(fixtureId)
   local validId = Training.ValidSelection(trainingGround.id, rebirths)
   local validGround = Training.Get(validId)
   local baseOffline = math.floor(12 * validGround.basePower / validGround.interval * Training.OfflinePowerRateMultiplier)
   local expected = Progression.Normalize({Rebirths=rebirths, Level=1, Power=0}, false)
   Progression.Advance(expected, baseOffline * Progression.GetPowerMultiplier(rebirths))
   local actual = Data.GetProgression(fixture)
   check(fixture:GetAttribute("OfflinePowerEarned") == baseOffline * Progression.GetPowerMultiplier(rebirths)
    and actual.Level == expected.Level and actual.Power == expected.Power, "actual offline login ground/Rebirth cross-product")
   check(Data.GetTrainingGround(fixture).id == validId and actual.LevelCap == Progression.GetLevelCap(rebirths), "actual login repairs locked grounds and saved caps")
   local granted, tick = Data.GrantPower(fixture, validGround.basePower, "ActiveTraining")
   check(granted and tick.powerGranted == validGround.basePower * Progression.GetPowerMultiplier(rebirths), "actual active grant ground/Rebirth cross-product")
   leave(fixture)
   check(saved[key].Cash == 456 and saved[key].OtherProgress == 73 and saved[key].UnlockedWorlds.world_2
    and saved[key].CompletedWorlds.world_1 and saved[key].SelectedTrainingGround == validId, "offline and active grants preserve unrelated fields")
  end
 end

 saved.Player_220 = {SchemaVersion=5, Cash=100, Rebirths=2, Level=29,
  Power=Progression.PowerRequiredForNextLevel(29)-1, SelectedTrainingGround="expert_training", LastLogoutTime=now-12}
 local offlineCap = join(220)
 check(Data.GetProgression(offlineCap).Level == 30 and Data.GetProgression(offlineCap).Power == 0
  and Data.CanRebirth(offlineCap), "offline login reaches cap and permits explicit Rebirth without automatic reset")
 check(Data.GetProgression(offlineCap).Rebirths == 2, "offline cap never automatically Rebirths")
 local oneBelow = Progression.Normalize({Rebirths=0, Level=9,
  Power=Progression.PowerRequiredForNextLevel(9)-1}, false)
 Progression.Advance(oneBelow, 1)
 check(oneBelow.Level == 10 and oneBelow.Power == 0, "exact Power boundary advances to cap")
 for _, forgedRebirths in {-1, 0/0, math.huge, 1.5, "2", Progression.MaxRebirths+1} do
  local normalized = Progression.Normalize({Rebirths=forgedRebirths, Level=1, Power=0, LevelCap=99999}, false)
  check(normalized.Rebirths == 0 and normalized.LevelCap == Progression.BaseLevelCap, "malformed Rebirth cannot inflate derived cap")
 end
 for version = 1, 4 do
  local id = 230 + version
  saved["Player_" .. id] = {SchemaVersion=version, Cash=1234, EquippedBat="metal_bat",
   OwnedBats={wood_bat=true, metal_bat=true}, UnlockedWorlds={world_1=true, world_2=true},
   CompletedWorlds={world_1=true}, Power=12, Level=2, Rebirths=1,
   SelectedTrainingGround="advanced_training", LastLogoutTime=1}
  local migration = join(id)
  local progress = Data.GetProgression(migration)
  check(migration.leaderstats.Cash.Value == 1234 and Data.OwnsEquipment(migration,"Bat","metal_bat")
   and migration:GetAttribute("EquippedBat") == "metal_bat" and migration:GetAttribute("WorldUnlocked_world_2"), "each old schema preserves economy/equipment/worlds")
  check(progress.Rebirths == (version < 4 and 0 or 1) and progress.LevelCap == (version < 4 and 10 or 20)
   and migration:GetAttribute("OfflinePowerEarned") == 0, "each old schema defaults progression only when needed and fabricates no offline time")
 end
 -- Three sessions combine every persistent field through real public data operations.
 -- These keys exist only in the in-memory store, so accelerated progress cannot touch
 -- a development player's legitimate save.
 local cyclePlayer = join(250)
 cyclePlayer.leaderstats.Cash.Value = 10000
 for _, category in Equipment.CategoryOrder do
  check(Data.PurchaseNextEquipment(cyclePlayer, category, cyclePlayer:GetAttribute("EquipmentPurchaseToken_" .. category)), "session A purchases each equipment category")
 end
 check(Data.GrantPower(cyclePlayer, 1000000, "Test") and Data.TryRebirth(cyclePlayer), "session A gains Levels and Rebirth")
 check(Data.SelectTrainingGround(cyclePlayer, "advanced_training"), "session A selects eligible ground")
 check(Data.GrantPower(cyclePlayer, 123, "Test"), "session A gains post-Rebirth Power")
 cyclePlayer:SetAttribute("WorldUnlocked_world_2", true)
 cyclePlayer:SetAttribute("WorldCompleted_world_1", true)
 local firstState, firstCash = Data.GetProgression(cyclePlayer), cyclePlayer.leaderstats.Cash.Value
 leave(cyclePlayer)
 cyclePlayer = join(250)
 local secondState = Data.GetProgression(cyclePlayer)
 check(secondState.Level == firstState.Level and secondState.Power == firstState.Power
  and secondState.Rebirths == firstState.Rebirths and secondState.LevelCap == firstState.LevelCap, "session B restores all progression fields")
 check(cyclePlayer.leaderstats.Cash.Value == firstCash and Data.GetTrainingGround(cyclePlayer).id == "advanced_training"
  and cyclePlayer:GetAttribute("WorldUnlocked_world_2") and cyclePlayer:GetAttribute("WorldCompleted_world_1"), "session B restores economy, selected ground, and worlds")
 for _, category in Equipment.CategoryOrder do
  local items = Equipment.GetItems(category)
  check(Data.OwnsEquipment(cyclePlayer, category, items[1].id) and Data.OwnsEquipment(cyclePlayer, category, items[2].id)
   and cyclePlayer:GetAttribute("Equipped" .. category) == items[2].id, "session B restores ownership and equipped selection")
  check(Data.PurchaseNextEquipment(cyclePlayer, category, cyclePlayer:GetAttribute("EquipmentPurchaseToken_" .. category)), "session B purchases next configured item")
  check(Data.EquipEquipment(cyclePlayer, category, items[1].id), "session B re-equips starting item without losing purchases")
 end
 check(Data.GrantPower(cyclePlayer, 456, "Test") and Data.SelectTrainingGround(cyclePlayer, "basic_training"), "session B changes Power and ground")
 local latestState, latestCash = Data.GetProgression(cyclePlayer), cyclePlayer.leaderstats.Cash.Value
 leave(cyclePlayer)
 cyclePlayer = join(250)
 local restoredState = Data.GetProgression(cyclePlayer)
 check(restoredState.Level == latestState.Level and restoredState.Power == latestState.Power
  and restoredState.Rebirths == latestState.Rebirths and restoredState.LevelCap == latestState.LevelCap, "session C restores latest progression rather than first snapshot")
 check(cyclePlayer.leaderstats.Cash.Value == latestCash and Data.GetTrainingGround(cyclePlayer).id == "basic_training"
  and cyclePlayer:GetAttribute("WorldUnlocked_world_2") and cyclePlayer:GetAttribute("WorldCompleted_world_1"), "session C restores latest economy/ground and preserves worlds")
 for _, category in Equipment.CategoryOrder do
  local items = Equipment.GetItems(category)
  check(Data.OwnsEquipment(cyclePlayer, category, items[2].id) and Data.OwnsEquipment(cyclePlayer, category, items[3].id)
   and cyclePlayer:GetAttribute("Equipped" .. category) == items[1].id, "session C retains all purchases and latest equipped choice")
 end
 local beforeDuplicateLogin = Data.GetProgression(cyclePlayer)
 for _ = 1, 5 do players.PlayerAdded:Fire(cyclePlayer) end
 check(Data.GetProgression(cyclePlayer).Power == beforeDuplicateLogin.Power
  and Data.GetProgression(cyclePlayer).Level == beforeDuplicateLogin.Level, "repeated login callbacks cannot repeat offline progression")

 -- Failed and expired sessions cannot execute economy/progression operations, even
 -- if a client has a previously valid request token or changes its display copies.
 for _, unavailable in {failed, future, invalid, locked, disconnected} do
  for _, category in Equipment.CategoryOrder do
   check(not Data.PurchaseNextEquipment(unavailable, category, "forged-offer")
    and not Data.EquipEquipment(unavailable, category, Equipment.Categories[category].startingId), "unavailable profile cannot purchase or equip")
  end
  check(not Data.GrantPower(unavailable, 100, "Test") and not Data.TryRebirth(unavailable)
   and not Data.SelectTrainingGround(unavailable, "basic_training"), "unavailable profile cannot progress or choose ground")
 end
 local expiring = join(251)
 expiring.leaderstats.Cash.Value = 1000
 local expiredOffer = expiring:GetAttribute("EquipmentPurchaseToken_Bat")
 now += 181
 check(not Data.IsReady(expiring), "expired session lease immediately blocks gameplay")
 check(not Data.PurchaseNextEquipment(expiring, "Bat", expiredOffer)
  and not Data.EquipEquipment(expiring, "Bat", "wood_bat") and not Data.GrantPower(expiring, 50, "Test")
  and not Data.TryRebirth(expiring) and not Data.SelectTrainingGround(expiring, "basic_training"), "expired lease cannot mutate progression through public operations")
 local recordBeforeExpiredClose = copy(saved.Player_251)
 leave(expiring)
 check(saved.Player_251.Cash == recordBeforeExpiredClose.Cash and expiring.KickReason ~= nil
  and saved.Player_251.Session.Id == recordBeforeExpiredClose.Session.Id, "expired close refuses a stale save instead of overwriting owned data")
 return {passed = passed, message = "Equipment, repeated Rebirths, remote abuse/state isolation, active/offline rate matrix, caps, migration, save/rejoin, failure safety"}
end
