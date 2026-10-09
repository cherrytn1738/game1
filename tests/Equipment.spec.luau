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
  local methods = {
   GetAttribute = function(_, name) return attributes[name] end,
   SetAttribute = function(_, name, value) attributes[name] = value end,
   GetAttributes = function() return table.clone(attributes) end,
   GetChildren = function() return table.clone(children) end,
   FindFirstChild = function(_, name)
    for _, child in children do if child.Name == name then return child end end
   end,
   IsA = function(_, name) return name == className end,
   Kick = function(self, reason) self.KickReason = reason end,
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
 local remote = {OnServerEvent = signal(), replies = {}}
 function remote:FireClient(player, success, message) self.replies[player] = {success, message} end
 local storage = {}
 function storage:WaitForChild(name) return name end
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
 function storage:WaitForChild(name) return name == "EquipmentUpgrade" and remote or name end
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
 return {passed = passed, message = "Equipment, progression, training selection/grants, offline atomicity, migration, save/rejoin, failure safety"}
end
