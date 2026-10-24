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
 local Juice = assert(loadstring(sources.JuiceConfig))()
 -- Test fixtures: the shipped paid grounds have no game pass created yet (id 0).
 Training.Get("cosmic_rift").gamePassId = 111
 Training.Get("dragons_lair").gamePassId = 222
 local ownedPasses, passFailures = {}, {}
 local marketplace = {PromptGamePassPurchaseFinished = signal(), prompts = {}}
 function marketplace:UserOwnsGamePassAsync(userId, passId)
  if passFailures[userId] then error("simulated pass lookup outage") end
  return ownedPasses[userId .. ":" .. passId] == true
 end
 -- Roblox's price for a pass; a pass with no entry simulates a failed lookup.
 local passPrices = {}
 function marketplace:GetProductInfo(passId, infoType)
  check(infoType == Enum.InfoType.GamePass, "pass prices are looked up as game passes")
  if not passPrices[passId] then error("simulated product info outage") end
  return {PriceInRobux = passPrices[passId]}
 end
 -- Test fixtures: the shipped config defines no juices yet.
 Juice.Define({id = "test_power", displayName = "Test Power Juice", effect = "Power", multiplier = 2, durationSeconds = 60})
 Juice.Define({id = "test_cash", displayName = "Test Cash Juice", effect = "Cash", multiplier = 3, durationSeconds = 30})
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
 local studioMode = false
 local modules = {EquipmentConfig = Equipment, WorldConfig = Worlds, ProgressionConfig = Progression, TrainingConfig = Training, JuiceConfig = Juice}
 local env = setmetatable({
  game = {
   ReplicatedStorage = storage,
   GetService = function(_, name)
    if name == "Players" then return players end
    if name == "ReplicatedStorage" then return storage end
    if name == "MarketplaceService" then return marketplace end
    if name == "RunService" then return {IsStudio = function() return studioMode end} end
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
  workspace = workspace,
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

 saved.Player_1 = {SchemaVersion = 2, Cash = 5000, EquippedBat = "jungle_bat",
  EquippedBall = "practice_ball", EquippedTee = "rubber_tee",
  UnlockedWorlds = {world_1 = true, world_2 = true}, CompletedWorlds = {world_1 = true}, OtherProgress = 42}
 local a, b = join(1), join(2)
 check(Data.IsReady(a) and Data.IsReady(b), "players loaded")
 check(a.leaderstats.Cash.Value == 5000 and a:GetAttribute("WorldUnlocked_world_2"), "migration preserves Cash/worlds")
 check(Data.OwnsEquipment(a, "Bat", "jungle_bat") and Data.OwnsEquipment(a, "Bat", "wood_bat"), "migration grants current/starter")
 check(not Data.OwnsEquipment(b, "Bat", "jungle_bat"), "ownership is isolated")
 check(not Data.EquipEquipment(b, "Bat", "jungle_bat"), "unowned equip rejected")
 check(not Data.EquipEquipment(a, "Bat", "practice_ball"), "wrong category rejected")
 a.OwnedBats:SetAttribute("amethyst_bat", true)
 check(not Data.EquipEquipment(a, "Bat", "amethyst_bat"), "replicated display cannot grant ownership")
 a.OwnedBats:SetAttribute("amethyst_bat", nil)
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
 check(a.leaderstats.Cash.Value == 3000 and a:GetAttribute("EquippedBat") == "amethyst_bat", "price and auto-equip")
 check(Data.OwnsEquipment(a, "Bat", "jungle_bat"), "previous equipment retained")
 check(not Data.PurchaseNextEquipment(a, "Bat", offer) and a.leaderstats.Cash.Value == 3000, "duplicate charged once")
 check(Data.EquipEquipment(a, "Bat", "wood_bat"), "older owned item equips")
 check(Data.GetNextEquipment(a, "Bat") == Equipment.GetNext("Bat", "amethyst_bat"), "older equip cannot regress progression")
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
 check(not Data.OwnsEquipment(b, "Bat", "jungle_bat"), "replay never grants next equipment")
 remote.OnServerEvent:Fire(a, "Equip", "Bat", "jungle_bat")
 check(a:GetAttribute("EquippedBat") == "jungle_bat", "other player has independent cooldown/state")
 now += 1
 remote.OnServerEvent:Fire(b, "Equip", "Bat", "baseball")
 remote.OnServerEvent:Fire(b, {}, {}, {})
 remote.OnServerEvent:Fire(b, "Purchase", "Bat", {price = 0})
 remote.OnServerEvent:Fire(b, "Purchase", "Bat", "amethyst_bat")
 check(b:GetAttribute("EquippedBat") == "metal_bat" and b.leaderstats.Cash.Value == 1700, "forged request inputs rejected")
 check(Data.EquipEquipment(a, "Bat", "wood_bat"), "select old item before saving")
 leave(a)
 check(saved.Player_1.SchemaVersion == 9 and saved.Player_1.Session == nil, "version 9 save and lease release")
 check(saved.Player_1.OwnedBats.amethyst_bat and saved.Player_1.EquippedBat == "wood_bat", "ownership and selection saved separately")
 check(saved.Player_1.OtherProgress == 42 and saved.Player_1.UnlockedWorlds.world_2, "other progression preserved")
 local returned = join(1)
 check(returned.leaderstats.Cash.Value == 3000 and Data.OwnsEquipment(returned, "Bat", "amethyst_bat")
  and returned:GetAttribute("EquippedBat") == "wood_bat", "rejoin restores purchased ownership and older selection")

 saved.Player_3 = {SchemaVersion = 3, Cash = 100, EquippedBat = "amethyst_bat", OwnedBats = {wood_bat = true},
  EquippedBall = "invalid", OwnedBalls = "malformed", OwnedTees = {basic_tee = true, baseball = true}}
 local repaired = join(3)
 check(repaired:GetAttribute("EquippedBat") == "wood_bat" and not Data.OwnsEquipment(repaired, "Bat", "amethyst_bat"), "modern unowned equipped ID falls back")
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
 check(ok and state.powerGranted == 90 and fresh:GetAttribute("Power") == 90, "central Bat and Rebirth multipliers")
 check(Progression.GetLaunchSpeed(Data.GetProgression(fresh).Level) == Progression.GetLaunchSpeed(1), "Power/Rebirth do not affect same-level launch")
 check(Progression.GetLaunchSpeed(10) > Progression.GetLaunchSpeed(1) * 3, "Level 10 launch substantially stronger")
 leave(fresh)
 fresh = join(20)
 state = Data.GetProgression(fresh)
 check(state.Rebirths == 1 and state.LevelCap == 20 and state.Level == 1 and state.Power == 90, "new progression saves and rejoins")
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
 check(Worlds.Get("world_1").endDistance == 5000 and Worlds.Get("world_2").endDistance == 6000
  and Worlds.Get("world_3").endDistance == 7000, "world endpoints unchanged")
 -- Physical grounds: access derives from private Rebirths or a Roblox pass, and offline
 -- grants use the best usable ground inside the atomic login transaction.
 local multipliers = {}
 for _, entry in Training.Grounds do table.insert(multipliers, entry.powerMultiplier) end
 check(table.concat(multipliers, ",") == "1,5,10,20,10,25,35,50,70,35,90,120,160,210,120,30" and Training.Get("dragons_lair").basePower == 600,
  "ground multipliers on the first ground's Power")
 check(Training.Get("sky_temple").requiredRebirths == 6 and Training.IsPaid(Training.Get("cosmic_rift"))
  and not Training.IsUnlocked("cosmic_rift", 1000), "Rebirth and paid ground requirements")
 check(Training.GetBestGround(0, nil).id == "basic_training" and Training.GetBestGround(4, nil).id == "sunken_atlantis"
  and Training.GetBestGround(6, {cosmic_rift=true}).id == "sky_temple" and Training.GetBestGround(0, {cosmic_rift=true}).id == "cosmic_rift"
  and Training.GetBestGround(6, {dragons_lair=true}).id == "dragons_lair", "best ground is the highest usable rate")
 Training.Get("dragons_lair").gamePassId = 0
 check(not Training.CanUse("dragons_lair", 0, {dragons_lair=true}), "a paid ground without a created pass is unusable")
 Training.Get("dragons_lair").gamePassId = 222
 -- Per-World hubs: a ground needs a World it stands in to be unlocked; Dragon's Lair stands in
 -- every hub; Time Machine Lab is opened by Cosmic Rift's pass.
 local bothWorlds = {world_1=true, world_2=true}
 check(table.concat(Training.Get("dragons_lair").worlds, ",") == "world_1,world_2,world_3"
  and table.concat(Training.Get("caveman_camp").worlds, ",") == "world_2"
  and table.concat(Training.Get("solar_rooftop").worlds, ",") == "world_3", "grounds know the Worlds they stand in")
 check(Training.GetPlatePosition(Training.Get("dragons_lair"), "world_1") == Training.GetPlatePosition(Training.Get("dragons_lair"), "world_2")
  and Training.GetPlatePosition(Training.Get("caveman_camp"), "world_2") == Training.GetPlatePosition(Training.Get("basic_training"), "world_1"),
  "every hub uses the same row")
 check(not Training.CanUse("caveman_camp", 99, nil) and not Training.CanUse("caveman_camp", 99, nil, {world_1=true})
  and Training.CanUse("caveman_camp", 0, nil, bothWorlds), "World 2 grounds wait for World 2")
 check(not Training.IsUnlocked("pharaohs_tomb", 8) and Training.IsUnlocked("pharaohs_tomb", 8, bothWorlds)
  and not Training.IsUnlocked("pharaohs_tomb", 7, bothWorlds), "World 2 Rebirth tiers continue on")
 check(Training.CanUse("time_machine_lab", 0, {cosmic_rift=true}, bothWorlds) and not Training.CanUse("time_machine_lab", 0, {time_machine_lab=true}, bothWorlds)
  and not Training.CanUse("time_machine_lab", 0, {cosmic_rift=true}, {world_1=true}), "Time Machine Lab uses Cosmic Rift's pass in World 2")
 check(Training.GetPassGround(Training.Get("time_machine_lab")).id == "cosmic_rift" and #Training.PassGrounds == 2, "one pass per pass ground")
 check(Training.CanUse("dragons_lair", 0, {dragons_lair=true}, {world_2=true}), "Dragon's Lair is usable from any World")
 check(Training.GetBestGround(0, nil, bothWorlds).id == "caveman_camp" and Training.GetBestGround(12, {dragons_lair=true}, bothWorlds).id == "samurai_dojo"
  and Training.GetBestGround(0, {cosmic_rift=true}, bothWorlds).id == "time_machine_lab", "best ground looks across unlocked Worlds")
 -- World 3's grounds: its free ground waits for World 3, its Rebirth tiers continue on from
 -- World 2's, and Quantum Lab is opened by Cosmic Rift's pass there.
 local allWorlds = {world_1=true, world_2=true, world_3=true}
 check(Training.GetPlatePosition(Training.Get("solar_rooftop"), "world_3") == Training.GetPlatePosition(Training.Get("basic_training"), "world_1")
  and Training.GetPlatePosition(Training.Get("dragons_lair"), "world_3") == Training.GetPlatePosition(Training.Get("dragons_lair"), "world_1"),
  "World 3's hub uses the same row")
 check(not Training.CanUse("solar_rooftop", 99, nil, bothWorlds) and Training.CanUse("solar_rooftop", 0, nil, allWorlds),
  "World 3 grounds wait for World 3")
 check(Training.IsUnlocked("robo_factory", 14, allWorlds) and not Training.IsUnlocked("robo_factory", 13, allWorlds)
  and Training.IsUnlocked("lunar_base", 18, allWorlds) and not Training.IsUnlocked("lunar_base", 17, allWorlds),
  "World 3 Rebirth tiers continue on")
 check(Training.CanUse("quantum_lab", 0, {cosmic_rift=true}, allWorlds) and not Training.CanUse("quantum_lab", 0, {cosmic_rift=true}, bothWorlds)
  and Training.GetPassGround(Training.Get("quantum_lab")).id == "cosmic_rift" and #Training.PassGrounds == 2,
  "Quantum Lab uses Cosmic Rift's pass in World 3")
 check(Training.GetBestGround(0, nil, allWorlds).id == "solar_rooftop" and Training.GetBestGround(18, nil, allWorlds).id == "lunar_base"
  and Training.GetBestGround(0, {cosmic_rift=true}, allWorlds).id == "quantum_lab", "best ground looks across all three Worlds")
 local trainee = join(30)
 check(trainee:GetAttribute("OfflinePowerEarned")==0 and trainee:GetAttribute("OfflineTrainingGround")==Training.DefaultGround,"new player has no historical reward")
 check(Data.CanUseTrainingGround(trainee,"basic_training") and not Data.CanUseTrainingGround(trainee,"enchanted_grove"),"Rebirth grounds start locked")
 check(not Data.CanUseTrainingGround(trainee,{}) and not Data.CanUseTrainingGround(trainee,"fake"),"malformed ground ids rejected")
 check(not Data.CanUseTrainingGround(trainee,"cosmic_rift") and trainee:GetAttribute("TrainingPass_cosmic_rift")==false,"paid grounds need a pass")
 trainee:SetAttribute("TrainingPass_dragons_lair",true)
 trainee:SetAttribute("Rebirths",6)
 check(not Data.CanUseTrainingGround(trainee,"dragons_lair") and not Data.CanUseTrainingGround(trainee,"sky_temple"),"display pass and Rebirth copies not authoritative")
 for _ = 1, 2 do check(Data.GrantPower(trainee,1000000,"Test") and Data.TryRebirth(trainee),"Rebirth unlock setup") end
 check(Data.CanUseTrainingGround(trainee,"enchanted_grove") and not Data.CanUseTrainingGround(trainee,"sunken_atlantis"),"two Rebirths unlock the second ground only")
 check(Data.GetBestTrainingGround(trainee).id=="enchanted_grove","best ground follows Rebirths")
 trainee:SetAttribute("TrainingActive",true)
 check(not Data.EquipEquipment(trainee,"Bat","wood_bat"),"training blocks equipment changes")
 local ground=Training.Get("enchanted_grove")
 local ok, gain=Data.GrantPower(trainee,ground.basePower,"ActiveTraining")
 check(ok and gain.powerGranted==300 and trainee:GetAttribute("Level")==2,"active training uses central multiplier/advancement")
 trainee:SetAttribute("TrainingActive",false)
 leave(trainee)
 check(saved.Player_30.SelectedTrainingGround==nil and saved.Player_30.SchemaVersion==9 and saved.Player_30.LastLogoutTime==math.floor(now),"no ground selection saved; logout saved")
 trainee=join(30)
 check(trainee:GetAttribute("OfflineTrainingGround")=="enchanted_grove" and trainee:GetAttribute("OfflinePowerEarned")==0,"rejoin with zero offline duration")
 local nowStamp=100000
 local amount, seconds=Training.GetOfflineReward(nowStamp-60,nowStamp,"basic_training")
 check(amount==150 and seconds==60,"short offline duration")
 amount,seconds=Training.GetOfflineReward(nowStamp-3600,nowStamp,"enchanted_grove")
 check(amount==45000 and seconds==3600,"ground offline rate")
 amount,seconds=Training.GetOfflineReward(1,nowStamp,"basic_training")
 check(seconds==Training.MaximumOfflineSeconds and amount==72000,"offline cap enforced")
 for _, timestamp in {0,-1,"bad",math.huge,0/0,1.5,nowStamp+10} do
  check(Training.GetOfflineReward(timestamp,nowStamp,"basic_training")==0,"malformed or future timestamp cannot award")
 end
 check(Training.GetOfflineReward(nil,nowStamp,"basic_training")==0,"missing timestamp cannot award")
 saved.Player_31={SchemaVersion=5,Cash=321,Power=0,Level=1,Rebirths=2,LevelCap=30,SelectedTrainingGround="advanced_training",LastLogoutTime=math.floor(now)-10,OtherProgress=123}
 loseResponse.Player_31=true
 local offline=join(31)
 check(offline:GetAttribute("OfflinePowerEarned")==375 and offline:GetAttribute("Level")==2
  and offline:GetAttribute("Power")==275,"offline grant once despite committed response loss")
 check(saved.Player_31.LastLogoutTime==nil and saved.Player_31.OtherProgress==123 and saved.Player_31.SelectedTrainingGround==nil,"timestamp consumed atomically, unknown fields preserved, retired selection dropped")
 check(offline.leaderstats.Cash.Value==321 and offline:GetAttribute("OfflineTrainingGround")=="enchanted_grove","best usable ground used, not the old saved selection")
 players.PlayerAdded:Fire(offline)
 check(offline:GetAttribute("Power")==275,"same session cannot reprocess offline reward")
 saved.Player_32={SchemaVersion=5,Cash=777,Power=3,Level=1,Rebirths=0,SelectedTrainingGround="expert_training",LastLogoutTime=math.floor(now)-60}
 local fallback=join(32)
 check(fallback:GetAttribute("OfflineTrainingGround")=="basic_training" and fallback:GetAttribute("OfflinePowerEarned")==150,"removed selection ignored; offline uses the best usable ground")
 check(fallback:GetAttribute("Level")==2 and fallback:GetAttribute("Power")==53 and fallback.leaderstats.Cash.Value==777,"offline progression preserves Cash")
 saved.Player_33={SchemaVersion=4,Cash=999,Power=41,Level=2,Rebirths=1,LastLogoutTime=1}
 local legacy=join(33)
 check(legacy:GetAttribute("Power")==41 and legacy:GetAttribute("Level")==2 and legacy:GetAttribute("OfflinePowerEarned")==0,"migration preserves progression without fabricated offline time")
 saved.Player_34={SchemaVersion=5,Cash=500,Power=0,Level=10,Rebirths=0,SelectedTrainingGround="fake",LastLogoutTime=1}
 local atCap=join(34)
 check(atCap:GetAttribute("Power")==0 and atCap:GetAttribute("Level")==10 and atCap:GetAttribute("OfflinePowerEarned")==0,"offline cap overflow discarded")
 check(not Data.CanUseTrainingGround(failed,"basic_training"),"failed loads cannot train")
 -- Paid grounds: Roblox pass ownership is read at login (before the offline grant) and on
 -- the server's purchase event; lookups that fail grant nothing.
 ownedPasses["35:111"] = true
 saved.Player_35={SchemaVersion=7,Cash=1,Power=0,Level=1,Rebirths=0,LastLogoutTime=math.floor(now)-12}
 local passHolder=join(35)
 check(passHolder:GetAttribute("OfflineTrainingGround")=="cosmic_rift" and passHolder:GetAttribute("OfflinePowerEarned")==300,"offline uses an owned paid ground with no Rebirths")
 check(Data.CanUseTrainingGround(passHolder,"cosmic_rift") and passHolder:GetAttribute("TrainingPass_cosmic_rift")==true
  and not Data.CanUseTrainingGround(passHolder,"dragons_lair"),"owned pass opens only its ground")
 check(passHolder:GetAttribute("TrainingPass_time_machine_lab")==nil and not Data.CanUseTrainingGround(passHolder,"time_machine_lab"),
  "the shared pass has one attribute and its World 2 ground waits for World 2")
 passHolder:SetAttribute("WorldUnlocked_world_2",true)
 check(Data.CanUseTrainingGround(passHolder,"time_machine_lab") and Data.GetBestTrainingGround(passHolder).id=="time_machine_lab",
  "unlocking World 2 opens the shared-pass ground")
 passHolder:SetAttribute("WorldUnlocked_world_2",false)
 marketplace.PromptGamePassPurchaseFinished:Fire(passHolder,222,false)
 marketplace.PromptGamePassPurchaseFinished:Fire(passHolder,999,true)
 check(not Data.CanUseTrainingGround(passHolder,"dragons_lair"),"cancelled or unknown purchases grant nothing")
 marketplace.PromptGamePassPurchaseFinished:Fire(passHolder,222,true)
 check(Data.CanUseTrainingGround(passHolder,"dragons_lair") and Data.GetBestTrainingGround(passHolder).id=="dragons_lair"
  and passHolder:GetAttribute("TrainingPass_dragons_lair")==true,"completed purchase opens the ground immediately")
 leave(passHolder)
 check(saved.Player_35.TrainingPasses==nil and saved.Player_35.SelectedTrainingGround==nil,"pass ownership is never saved")
 -- The configured fallback price applied (no Roblox price for pass 222 here); the unknown pass
 -- 999 has no price anywhere, so it adds nothing.
 check(saved.Player_35.RobuxSpent==1000 and saved.Player_35.RobuxPurchases.Passes["222"]==true
  and saved.Player_35.RobuxPurchases.Passes["999"]==true,"a verified in-game pass purchase counts its Robux")

 -- Leaderboard stats (schema 9). TimePlayed: whole seconds from the server clock, across sessions.
 saved.Player_42={SchemaVersion=8,Cash=10,Power=0,Level=1,Rebirths=0}
 local veteran=join(42)
 now += 125.6
 leave(veteran)
 check(saved.Player_42.TimePlayed==125 and saved.Player_42.RobuxSpent==0 and saved.Player_42.Cash==10,
  "schema 8 saves start TimePlayed and RobuxSpent at zero; a session adds its whole seconds")
 veteran=join(42)
 veteran:SetAttribute("TimePlayed",999999)
 now += 30.2
 leave(veteran)
 check(saved.Player_42.TimePlayed==155,"time accumulates across sessions; client attributes cannot change it")
 -- Wind the fake clock back: these fakes never run the autosave loop that renews the other
 -- players' leases, so 155 seconds would expire them.
 now -= 155.8
 -- RobuxSpent: Roblox's pass price is preferred, each pass counts once, cancelled purchases never.
 passPrices[111]=450
 local buyer=join(43)
 marketplace.PromptGamePassPurchaseFinished:Fire(buyer,111,false)
 marketplace.PromptGamePassPurchaseFinished:Fire(buyer,111,true)
 marketplace.PromptGamePassPurchaseFinished:Fire(buyer,111,true)
 check(Data.RecordRobuxReceipt(buyer,{PlayerId=43,PurchaseId="receipt-1",CurrencySpent=75,CurrencyType=Enum.CurrencyType.Robux}),
  "a developer product receipt counts")
 check(not Data.RecordRobuxReceipt(buyer,{PlayerId=43,PurchaseId="receipt-1",CurrencySpent=75,CurrencyType=Enum.CurrencyType.Robux}),
  "a repeated receipt is not counted twice")
 for _, bad in {{PlayerId=2,PurchaseId="r2",CurrencySpent=10}, {PlayerId=43,PurchaseId="r3",CurrencySpent=-5},
  {PlayerId=43,PurchaseId="r4",CurrencySpent=1.5}, {PlayerId=43,PurchaseId="",CurrencySpent=10}, {PlayerId=43,PurchaseId={},CurrencySpent=10},
  {PlayerId=43,PurchaseId="r5",CurrencySpent=10,CurrencyType="Robux"}, "receipt"} do
  check(not Data.RecordRobuxReceipt(buyer,bad),"another player's, malformed or non-Robux receipts are rejected")
 end
 check(not Data.RecordRobuxReceipt(failed,{PlayerId=6,PurchaseId="r6",CurrencySpent=10}),"a failed load records nothing")
 leave(buyer)
 check(saved.Player_43.RobuxSpent==525 and saved.Player_43.RobuxPurchases.Passes["111"]==true
  and saved.Player_43.RobuxPurchases.Receipts[1]=="receipt-1","pass and receipt Robux saved once each")
 buyer=join(43)
 marketplace.PromptGamePassPurchaseFinished:Fire(buyer,111,true)
 check(not Data.RecordRobuxReceipt(buyer,{PlayerId=43,PurchaseId="receipt-1",CurrencySpent=75}),"counted purchases are remembered across sessions")
 leave(buyer)
 check(saved.Player_43.RobuxSpent==525,"a rejoin never counts a purchase again")
 passPrices[111]=nil
 -- Sanitizing: malformed counters fail closed (the save is untouched); stray purchase entries are dropped.
 for id, record in {[44]={TimePlayed=-5}, [45]={RobuxSpent=1.5}, [46]={RobuxSpent="100"}, [47]={TimePlayed=1e20},
  [48]={RobuxPurchases="bad"}, [49]={RobuxPurchases={Passes="bad"}}} do
  record.SchemaVersion, record.Cash = 9, 7
  saved["Player_" .. id] = record
  local broken=join(id)
  check(not Data.IsReady(broken) and saved["Player_" .. id].Cash==7,"malformed leaderboard stats fail closed")
 end
 saved.Player_50={SchemaVersion=9,Cash=7,TimePlayed=60,RobuxSpent=40,
  RobuxPurchases={Passes={["12"]=true,bad=true,["13"]="yes"},Receipts={"r1",5,string.rep("x",80)}}}
 local tidy=join(50)
 leave(tidy)
 local tidied=saved.Player_50.RobuxPurchases
 check(tidied.Passes["12"]==true and tidied.Passes.bad==nil and tidied.Passes["13"]==nil and #tidied.Receipts==1
  and tidied.Receipts[1]=="r1" and saved.Player_50.RobuxSpent==40 and saved.Player_50.TimePlayed==60,"stray purchase entries dropped, totals kept")
 -- Studio's UnlockAllWorlds playtest switch opens every World for the session only.
 workspace:SetAttribute("UnlockAllWorlds", true)
 saved.Player_37={SchemaVersion=8,Cash=1,Power=0,Level=1,Rebirths=0}
 local outsideStudio=join(37)
 check(outsideStudio:GetAttribute("WorldUnlocked_world_2")==false,"UnlockAllWorlds does nothing outside Studio")
 leave(outsideStudio)
 studioMode = true
 saved.Player_38={SchemaVersion=8,Cash=1,Power=0,Level=1,Rebirths=0}
 local tester=join(38)
 check(tester:GetAttribute("WorldUnlocked_world_2")==true and Data.CanUseTrainingGround(tester,"caveman_camp"),"Studio switch opens World 2 and its grounds")
 leave(tester)
 check(saved.Player_38.UnlockedWorlds.world_2==nil and saved.Player_38.UnlockedWorlds.world_1==true,"Studio unlocks are never saved")
 workspace:SetAttribute("OwnAllBalls", true)
 saved.Player_40={SchemaVersion=8,Cash=1,Power=0,Level=1,Rebirths=0,OwnedBalls={baseball=true,practice_ball=true},EquippedBall="practice_ball"}
 local collector=join(40)
 check(Data.OwnsEquipment(collector,"Ball","chrono_orb") and Data.OwnsEquipment(collector,"Ball","supernova_ball")
  and collector.OwnedBalls:GetAttribute("dino_egg_ball")==true and not Data.OwnsEquipment(collector,"Bat","celestial_bat"),"Studio switch owns every Ball only")
 check(Data.EquipEquipment(collector,"Ball","chrono_orb") and collector:GetAttribute("EquippedBall")=="chrono_orb","a granted Ball can be equipped")
 leave(collector)
 check(saved.Player_40.OwnedBalls.chrono_orb==nil and saved.Player_40.OwnedBalls.practice_ball==true
  and saved.Player_40.EquippedBall=="practice_ball","Studio Ball grants are never saved; the saved equipped Ball stays")
 workspace:SetAttribute("OwnAllBalls", nil)
 studioMode = false
 workspace:SetAttribute("UnlockAllWorlds", nil)
 -- World 2's balls are their own series: their own offer, World 2 must be unlocked, then in order.
 local worldTwoBalls = Equipment.GetSeriesItems("Ball", "world_2")
 local aboveTen = true
 for _, ball in worldTwoBalls do aboveTen = aboveTen and ball.rewardMultiplier > 10 and ball.series == "world_2" end
 check(#worldTwoBalls == 10 and worldTwoBalls[1].id == "dino_egg_ball" and worldTwoBalls[10].id == "chrono_orb" and aboveTen
  and #Equipment.GetSeriesItems("Ball") == 10 and #Equipment.GetItems("Ball") == 30, "World 2 sells ten balls above x10")
 local worldThreeBalls = Equipment.GetSeriesItems("Ball", "world_3")
 local aboveChrono = true
 for _, ball in worldThreeBalls do
  aboveChrono = aboveChrono and ball.rewardMultiplier > 95 and ball.series == "world_3" and ball.price > 2000000000
 end
 check(#worldThreeBalls == 10 and worldThreeBalls[1].id == "solar_cell_ball" and worldThreeBalls[10].id == "singularity_orb" and aboveChrono
  and Equipment.GetSeriesInfo("Ball", "world_3").requiredWorld == "world_3" and worldThreeBalls[10].price < 9000000000000,
  "World 3 sells ten balls above the Chrono Orb, below the Cash cap")
 saved.Player_39={SchemaVersion=8,Cash=5000000,Power=0,Level=1,Rebirths=0}
 local shopper=join(39)
 local worldTwoOffer=shopper:GetAttribute("EquipmentPurchaseToken_Ball_world_2")
 check(type(worldTwoOffer)=="string" and worldTwoOffer~=shopper:GetAttribute("EquipmentPurchaseToken_Ball"),"World 2's ball series has its own offer")
 check(not Data.PurchaseNextEquipment(shopper,"Ball",worldTwoOffer) and shopper.leaderstats.Cash.Value==5000000,"World 2's balls need World 2 unlocked")
 shopper:SetAttribute("WorldUnlocked_world_2",true)
 check(Data.PurchaseNextEquipment(shopper,"Ball",worldTwoOffer) and Data.OwnsEquipment(shopper,"Ball","dino_egg_ball")
  and shopper:GetAttribute("EquippedBall")=="dino_egg_ball" and shopper.leaderstats.Cash.Value==4000000
  and not Data.OwnsEquipment(shopper,"Ball","practice_ball"),"World 2's first ball needs none of World 1's")
 check(not Data.PurchaseNextEquipment(shopper,"Ball",worldTwoOffer),"a used World 2 offer cannot buy again")
 check(Data.GetNextEquipment(shopper,"Ball","world_2").id=="stone_ball" and Data.GetNextEquipment(shopper,"Ball").id=="practice_ball","each series moves on separately")
 check(Data.PurchaseNextEquipment(shopper,"Ball",shopper:GetAttribute("EquipmentPurchaseToken_Ball")) and Data.OwnsEquipment(shopper,"Ball","practice_ball")
  and Data.GetNextEquipment(shopper,"Ball","world_2").id=="stone_ball","World 1's offer still buys World 1's next ball")
 leave(shopper)
 check(saved.Player_39.OwnedBalls.dino_egg_ball==true and saved.Player_39.OwnedBalls.practice_ball==true,"World 2 balls save with the rest")
 -- World 3's series works the same way: its own offer, and World 3 must be unlocked.
 saved.Player_41={SchemaVersion=8,Cash=3000000000,Power=0,Level=1,Rebirths=0}
 local futureShopper=join(41)
 local worldThreeOffer=futureShopper:GetAttribute("EquipmentPurchaseToken_Ball_world_3")
 check(type(worldThreeOffer)=="string" and worldThreeOffer~=futureShopper:GetAttribute("EquipmentPurchaseToken_Ball_world_2"),
  "World 3's ball series has its own offer")
 futureShopper:SetAttribute("WorldUnlocked_world_2",true)
 check(not Data.PurchaseNextEquipment(futureShopper,"Ball",worldThreeOffer) and futureShopper.leaderstats.Cash.Value==3000000000,
  "World 3's balls need World 3 unlocked")
 futureShopper:SetAttribute("WorldUnlocked_world_3",true)
 check(Data.PurchaseNextEquipment(futureShopper,"Ball",worldThreeOffer) and Data.OwnsEquipment(futureShopper,"Ball","solar_cell_ball")
  and futureShopper.leaderstats.Cash.Value==500000000 and Data.GetNextEquipment(futureShopper,"Ball","world_3").id=="hover_ball",
  "World 3's first ball is bought from its own series")
 leave(futureShopper)
 check(saved.Player_41.OwnedBalls.solar_cell_ball==true,"World 3 balls save with the rest")
 passFailures[36] = true
 ownedPasses["36:111"] = true
 saved.Player_36={SchemaVersion=7,Cash=1,Power=0,Level=1,Rebirths=0,LastLogoutTime=math.floor(now)-12}
 local lookupOutage=join(36)
 check(Data.IsReady(lookupOutage) and not Data.CanUseTrainingGround(lookupOutage,"cosmic_rift")
  and lookupOutage:GetAttribute("OfflinePowerEarned")==30,"pass lookup outage loads safely with Rebirth grounds only")
 local offlineBase=Training.GetOfflineReward(100,7300,"basic_training")
 local simulated=Progression.Normalize({},false)
 Progression.Advance(simulated,offlineBase*Progression.GetPowerMultiplier(simulated.Rebirths))
 check(simulated.Level==8 and simulated.Power==4000,"several hours advance multiple levels")
 offlineBase=Training.GetOfflineReward(100,100000,"enchanted_grove")
 simulated=Progression.Normalize({Rebirths=2,Level=1,Power=0},false)
 Progression.Advance(simulated,offlineBase*Progression.GetPowerMultiplier(simulated.Rebirths))
 check(simulated.Level==30 and simulated.Power==0,"capped offline duration can reach cap but never exceed it")
 check(Data.GetBestTrainingGround(trainee).id=="enchanted_grove" and Data.GetBestTrainingGround(fallback).id=="basic_training"
  and not Data.CanUseTrainingGround(fallback,"dragons_lair"),"players have independent access")
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
  check(state.Rebirths == rebirths and state.LevelCap == Progression.GetLevelCap(rebirths), "cycle starts at derived cap")
  check(not Data.CanRebirth(cyclist), "each cycle requires reaching its own cap")
  check(Data.GrantPower(cyclist, 1000000, "Test") and Data.CanRebirth(cyclist), "large grant reaches cycle cap")
  check(Data.GetProgression(cyclist).Level == Progression.GetLevelCap(rebirths), "large grant cannot exceed cycle cap")
  check(Data.TryRebirth(cyclist), "next cycle Rebirth succeeds")
  state = Data.GetProgression(cyclist)
  check(state.Rebirths == rebirths + 1 and state.Level == Progression.StartingLevel
   and state.Power == Progression.StartingPower and state.LevelCap == Progression.GetLevelCap(rebirths + 1), "complete atomic cycle result")
  check(not Data.TryRebirth(cyclist), "one capped state permits only one Rebirth")
  check(Data.CanUseTrainingGround(cyclist, "basic_training"), "earlier grounds stay usable after Rebirth")
  check(cyclist.leaderstats.Cash.Value == preservedCash and cyclist:GetAttribute("WorldUnlocked_world_2")
   and cyclist:GetAttribute("WorldCompleted_world_1"), "cycle preserves Cash and world progression")
  for _, category in Equipment.CategoryOrder do
   local entries = Equipment.GetItems(category)
   check(Data.OwnsEquipment(cyclist, category, entries[1].id) and Data.OwnsEquipment(cyclist, category, entries[2].id)
    and cyclist:GetAttribute("Equipped" .. category) == entries[2].id, "cycle preserves owned and equipped equipment")
  end
  -- World 2 is unlocked, so its free ground (x25) is the best ground at any Rebirth count.
  local best = Data.GetBestTrainingGround(cyclist)
  check(best.id == "caveman_camp" and (Data.CanUseTrainingGround(cyclist, "enchanted_grove") ~= nil) == (rebirths + 1 >= 2),
   "the second ground opens at two Rebirths; the best ground spans unlocked Worlds")
  local granted, tick = Data.GrantPower(cyclist, best.basePower, "ActiveTraining")
  check(granted and tick.powerGranted == best.basePower * 1.5 * Progression.GetPowerMultiplier(rebirths + 1), "ground, Bat and Rebirth multipliers compose")
 end
 leave(cyclist)
 local cycleRecord = saved.Player_100
 check(cycleRecord.Rebirths == 2 and cycleRecord.LevelCap == 30 and cycleRecord.SelectedTrainingGround == nil, "two Rebirths saved without a ground selection")
 check(cycleRecord.LastLogoutTime == math.floor(now) and cycleRecord.Session == nil, "Rebirth save retains offline lifecycle and releases lease")
 cyclist = join(100)
 check(Data.GetProgression(cyclist).Rebirths == 2 and Data.GetBestTrainingGround(cyclist).id == "caveman_camp"
  and cyclist.leaderstats.Cash.Value == preservedCash, "multiple cycles survive rejoin")
 check(Data.GetProgression(b).Rebirths == 0 and Data.GetBestTrainingGround(b).id == Training.DefaultGround, "cycles do not change another player's state")

 -- Configuration may evolve; access is re-evaluated from private state on every check.
 saved.Player_101 = {SchemaVersion=5, Cash=42, Rebirths=2, Level=20, Power=0, SelectedTrainingGround="advanced_training"}
 local changedGround = join(101)
 local grove = Training.Get("enchanted_grove")
 grove.requiredRebirths = 3
 check(not Data.CanUseTrainingGround(changedGround, "enchanted_grove") and Data.GetBestTrainingGround(changedGround).id == Training.DefaultGround, "raised requirement applies immediately")
 grove.requiredRebirths = 2
 check(Data.CanUseTrainingGround(changedGround, "enchanted_grove"), "restored requirement applies immediately")

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
 -- Real login fixtures separately verify that offline payouts use the best usable ground.
 for _, rebirths in {0, 2, 4, 6} do
  for _, trainingGround in Training.Grounds do
   local label = trainingGround.id .. "/Rebirth" .. rebirths
   local multiplier = Progression.GetPowerMultiplier(rebirths)
   local paid = Training.IsPaid(trainingGround)
   check(Training.IsUnlocked(trainingGround.id, rebirths) == (not paid and rebirths >= trainingGround.requiredRebirths
    and Training.IsReachable(trainingGround, nil)), "central ground eligibility " .. label)
   check(Training.CanUse(trainingGround.id, rebirths, nil) == Training.IsUnlocked(trainingGround.id, rebirths), "no pass means Rebirth grounds only " .. label)
   check(trainingGround.basePower == Training.BasePowerPerTick * trainingGround.powerMultiplier, "ground base Power from multiplier " .. label)
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
 -- One fixture per ground and Rebirth count, numbered clear of every other test player's id.
 local fixtureId = 1000
 for _, rebirths in {0, 2, 4, 6} do
  for _, trainingGround in Training.Grounds do
   fixtureId += 1
   local key = "Player_" .. fixtureId
   saved[key] = {SchemaVersion=7, Cash=456, Rebirths=rebirths, Level=1, Power=0,
    LevelCap=999999, SelectedTrainingGround=trainingGround.id, LastLogoutTime=now-12,
    UnlockedWorlds={world_1=true, world_2=true}, CompletedWorlds={world_1=true}, OtherProgress=73}
   local fixture = join(fixtureId)
   -- These saves have World 2 unlocked, so World 2's grounds count too.
   local best = Training.GetBestGround(rebirths, nil, bothWorlds)
   local baseOffline = math.floor(12 * best.basePower / best.interval * Training.OfflinePowerRateMultiplier)
   local expected = Progression.Normalize({Rebirths=rebirths, Level=1, Power=0}, false)
   Progression.Advance(expected, baseOffline * Progression.GetPowerMultiplier(rebirths))
   local actual = Data.GetProgression(fixture)
   check(fixture:GetAttribute("OfflinePowerEarned") == baseOffline * Progression.GetPowerMultiplier(rebirths)
    and fixture:GetAttribute("OfflineTrainingGround") == best.id
    and actual.Level == expected.Level and actual.Power == expected.Power, "actual offline login uses the best ground, whatever was saved")
   check(not Data.CanUseTrainingGround(fixture, trainingGround.id) == not Training.IsUnlocked(trainingGround.id, rebirths, bothWorlds)
    and actual.LevelCap == Progression.GetLevelCap(rebirths), "actual login access and repaired saved caps")
   local granted, tick = Data.GrantPower(fixture, best.basePower, "ActiveTraining")
   check(granted and tick.powerGranted == best.basePower * Progression.GetPowerMultiplier(rebirths), "actual active grant ground/Rebirth cross-product")
   leave(fixture)
   check(saved[key].Cash == 456 and saved[key].OtherProgress == 73 and saved[key].UnlockedWorlds.world_2
    and saved[key].CompletedWorlds.world_1 and saved[key].SelectedTrainingGround == nil, "offline and active grants preserve unrelated fields")
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
 check(Data.GrantPower(cyclePlayer, 123, "Test"), "session A gains post-Rebirth Power")
 cyclePlayer:SetAttribute("WorldUnlocked_world_2", true)
 cyclePlayer:SetAttribute("WorldCompleted_world_1", true)
 local firstState, firstCash = Data.GetProgression(cyclePlayer), cyclePlayer.leaderstats.Cash.Value
 leave(cyclePlayer)
 cyclePlayer = join(250)
 local secondState = Data.GetProgression(cyclePlayer)
 check(secondState.Level == firstState.Level and secondState.Power == firstState.Power
  and secondState.Rebirths == firstState.Rebirths and secondState.LevelCap == firstState.LevelCap, "session B restores all progression fields")
 check(cyclePlayer.leaderstats.Cash.Value == firstCash
  and cyclePlayer:GetAttribute("WorldUnlocked_world_2") and cyclePlayer:GetAttribute("WorldCompleted_world_1"), "session B restores economy and worlds")
 for _, category in Equipment.CategoryOrder do
  local items = Equipment.GetItems(category)
  check(Data.OwnsEquipment(cyclePlayer, category, items[1].id) and Data.OwnsEquipment(cyclePlayer, category, items[2].id)
   and cyclePlayer:GetAttribute("Equipped" .. category) == items[2].id, "session B restores ownership and equipped selection")
  check(Data.PurchaseNextEquipment(cyclePlayer, category, cyclePlayer:GetAttribute("EquipmentPurchaseToken_" .. category)), "session B purchases next configured item")
  check(Data.EquipEquipment(cyclePlayer, category, items[1].id), "session B re-equips starting item without losing purchases")
 end
 check(Data.GrantPower(cyclePlayer, 456, "Test"), "session B changes Power")
 local latestState, latestCash = Data.GetProgression(cyclePlayer), cyclePlayer.leaderstats.Cash.Value
 leave(cyclePlayer)
 cyclePlayer = join(250)
 local restoredState = Data.GetProgression(cyclePlayer)
 check(restoredState.Level == latestState.Level and restoredState.Power == latestState.Power
  and restoredState.Rebirths == latestState.Rebirths and restoredState.LevelCap == latestState.LevelCap, "session C restores latest progression rather than first snapshot")
 check(cyclePlayer.leaderstats.Cash.Value == latestCash
  and cyclePlayer:GetAttribute("WorldUnlocked_world_2") and cyclePlayer:GetAttribute("WorldCompleted_world_1"), "session C restores latest economy and preserves worlds")
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
   and not Data.CanUseTrainingGround(unavailable, "basic_training"), "unavailable profile cannot progress or train")
 end

 -- Schema 6 removes only retired player equipment; its physical station is unrelated.
 check(#Equipment.CategoryOrder == 2 and Equipment.Categories.Tee == nil
  and Equipment.Get("Tee", "basic_tee") == nil, "catalog contains only Bat/Ball")
 saved.Player_300 = {SchemaVersion=5, Cash=4321, Power=7, Level=3, Rebirths=2,
  OwnedBats={wood_bat=true,metal_bat=true}, EquippedBat="metal_bat",
  OwnedBalls={baseball=true,practice_ball=true}, EquippedBall="practice_ball",
  OwnedTees="malformed retired data", EquippedTee={invalid=true},
  SelectedTrainingGround="advanced_training", LastLogoutTime=math.floor(now),
  UnlockedWorlds={world_1=true,world_2=true},CompletedWorlds={world_1=true},OtherProgress=123}
 local migrated=join(300)
 check(Data.IsReady(migrated) and migrated.leaderstats.Cash.Value==4321
  and migrated:GetAttribute("Power")==7 and migrated:GetAttribute("Level")==3
  and migrated:GetAttribute("Rebirths")==2, "schema 5 migration preserves progression")
 check(not migrated:FindFirstChild("OwnedTees") and migrated:GetAttribute("EquippedTee")==nil
  and migrated:GetAttribute("EquipmentPurchaseToken_Tee")==nil, "no retired runtime state")
 check(saved.Player_300.OwnedTees==nil and saved.Player_300.EquippedTee==nil
  and saved.Player_300.SchemaVersion==9, "atomic migration discards even malformed Tee fields")
 check(not Data.PurchaseNextEquipment(migrated,"Tee","fake")
  and not Data.EquipEquipment(migrated,"Tee","basic_tee"), "removed category operations rejected")
 local migratedCash=migrated.leaderstats.Cash.Value
 remote.OnServerEvent:Fire(migrated,"Purchase","Tee","fake")
 remote.OnServerEvent:Fire(migrated,"Equip","Tee","basic_tee")
 remote.OnServerEvent:Fire(migrated,"Equip","Bat",{powerGainMultiplier=100000})
 check(migrated.leaderstats.Cash.Value==migratedCash and migrated:GetAttribute("EquippedBat")=="metal_bat",
  "removed category and fake multiplier remote inputs do not change equipment or Cash")
 leave(migrated)
 check(saved.Player_300.OwnedTees==nil and saved.Player_300.EquippedTee==nil
  and saved.Player_300.OtherProgress==123 and saved.Player_300.UnlockedWorlds.world_2
  and saved.Player_300.SelectedTrainingGround==nil, "save retains valid unrelated fields and drops the retired selection")
 migrated=join(300)
 check(migrated:GetAttribute("EquippedBat")=="metal_bat" and migrated:GetAttribute("EquippedBall")=="practice_ball"
  and Data.OwnsEquipment(migrated,"Bat","wood_bat"), "schema 6 rejoin preserves Bat/Ball equipment")

 local fixtureId=400
 for _,entry in {{id="wood_bat",gain=1},{id="metal_bat",gain=1.5},{id="jungle_bat",gain=2},{id="amethyst_bat",gain=2.5}} do
  for rebirths=0,2 do
   fixtureId+=1
   local key="Player_"..fixtureId
   saved[key]={SchemaVersion=5,Cash=5000,Power=0,Level=1,Rebirths=rebirths,
    OwnedBats={wood_bat=true,[entry.id]=true},EquippedBat=entry.id,
    SelectedTrainingGround="basic_training",LastLogoutTime=math.floor(now)-12}
   local fixture=join(fixtureId)
   check(fixture:GetAttribute("OfflinePowerEarned")==30*Training.GetBestGround(rebirths).powerMultiplier*entry.gain*(rebirths+1),
    "offline bonus uses saved Bat and Rebirth exactly once")
   local trainingOk,tick=Data.GrantPower(fixture,20,"ActiveTraining")
   check(trainingOk and tick.powerGranted==20*entry.gain*(rebirths+1), "active Training composes Bat and Rebirth")
   local hitOk,hit=Data.GrantPower(fixture,2,"CompletedHit",entry.id)
   check(hitOk and hit.powerGranted==2*entry.gain*(rebirths+1), "hit snapshot composes Bat and Rebirth")
   check(Data.PurchaseNextEquipment(fixture,"Ball",fixture:GetAttribute("EquipmentPurchaseToken_Ball")),
    "Ball purchase still works")
   local _,afterBall=Data.GrantPower(fixture,2,"CompletedHit",entry.id)
   check(afterBall.powerGranted==hit.powerGranted,"Ball reward bonus does not affect Power")
   fixture:SetAttribute("TrainingActive",true)
   check(not Data.EquipEquipment(fixture,"Bat","wood_bat"),"Bat switch blocked during Training")
   fixture:SetAttribute("TrainingActive",false)
   fixture:SetAttribute("HitActive",true)
   check(not Data.EquipEquipment(fixture,"Bat","wood_bat"),"Bat switch blocked during flight")
   fixture:SetAttribute("HitActive",false)
   check(Data.EquipEquipment(fixture,"Bat","wood_bat"),"owned Bat switches after activity")
   local _,olderHit=Data.GrantPower(fixture,2,"CompletedHit",entry.id)
   check(olderHit.powerGranted==hit.powerGranted,"accepted hit snapshot survives later equipment selection")
   local _,newTick=Data.GrantPower(fixture,20,"ActiveTraining")
   check(newTick.powerGranted==20*(rebirths+1),"next Training uses newly equipped Bat")
   check(not Data.GrantPower(fixture,20,"ActiveTraining",1000),"a number cannot supply a Bat bonus")
  end
 end
 check(not Data.GrantPower(migrated,20,"CompletedHit","amethyst_bat"),"unowned snapshot rejected")
 check(Progression.GetPowerGrant(3,1,1.5)==9 and Progression.GetPowerGrant(1,0,1.5)==1,
  "whole Power rounds only after composing bonuses")
 -- Juice (Schema 7): server-granted consumables with online-only timers.
 local juicer = join(400)
 check(juicer.OwnedJuices and juicer.ActiveJuices and next(juicer.OwnedJuices:GetAttributes()) == nil, "new players start with no juice")
 check(Data.GetJuiceMultiplier(juicer, "Power") == 1 and Data.GetJuiceMultiplier(juicer, "Cash") == 1, "no juice means no bonus")
 check(not Data.UseJuice(juicer, "test_power"), "cannot drink juice you do not own")
 check(not Data.GrantJuice(juicer, "fake_juice", 1, "Test") and not Data.GrantJuice(juicer, "test_power", 0, "Test")
  and not Data.GrantJuice(juicer, "test_power", 1.5, "Test"), "invalid juice grants rejected")
 check(Data.GrantJuice(juicer, "test_power", 2, "Test") and juicer.OwnedJuices:GetAttribute("test_power") == 2, "server grant adds juice")
 local baseGrant = select(2, Data.GrantPower(juicer, 10, "Test")).powerGranted
 check(Data.UseJuice(juicer, "test_power") and juicer.OwnedJuices:GetAttribute("test_power") == 1
  and juicer.ActiveJuices:GetAttribute("test_power") == 60, "drinking consumes one and starts its timer")
 check(Data.GetJuiceMultiplier(juicer, "Power") == 2 and Data.GetJuiceMultiplier(juicer, "Cash") == 1, "juice affects only its own effect")
 check(select(2, Data.GrantPower(juicer, 10, "Test")).powerGranted == baseGrant * 2, "Power juice doubles online Power grants")
 check(Data.UseJuice(juicer, "test_power") and juicer.ActiveJuices:GetAttribute("test_power") == 120
  and juicer.OwnedJuices:GetAttribute("test_power") == nil, "drinking an active juice extends it")
 Data.TickJuices(30)
 check(juicer.ActiveJuices:GetAttribute("test_power") == 90, "timers count down")
 leave(juicer)
 check(saved.Player_400.SchemaVersion == 9 and saved.Player_400.ActiveJuices.test_power == 90
  and saved.Player_400.OwnedJuices.test_power == nil, "juice state saves")
 now += 600
 local returning = join(400)
 check(returning.ActiveJuices:GetAttribute("test_power") == 90, "timers pause while offline")
 Data.TickJuices(95)
 check(returning.ActiveJuices:GetAttribute("test_power") == nil and Data.GetJuiceMultiplier(returning, "Power") == 1, "expired juice ends its bonus")
 leave(returning)
 saved.Player_401 = {SchemaVersion = 7, Cash = 5, OwnedJuices = "corrupt"}
 local corrupt = join(401)
 check(not Data.IsReady(corrupt) and saved.Player_401.OwnedJuices == "corrupt", "malformed juice data fails closed")
 saved.Player_402 = {SchemaVersion = 7, Cash = 5, OwnedJuices = {test_cash = 3, removed_juice = 4, test_power = -1}, ActiveJuices = {test_cash = 12.5}}
 local cleaned = join(402)
 check(Data.IsReady(cleaned) and cleaned.OwnedJuices:GetAttribute("test_cash") == 3 and cleaned.OwnedJuices:GetAttribute("removed_juice") == nil
  and cleaned.OwnedJuices:GetAttribute("test_power") == nil and cleaned.ActiveJuices:GetAttribute("test_cash") == nil, "unknown or invalid juice entries are dropped")
 leave(cleaned)
 local expiring = join(251)
 expiring.leaderstats.Cash.Value = 1000
 local expiredOffer = expiring:GetAttribute("EquipmentPurchaseToken_Bat")
 now += 181
 check(not Data.IsReady(expiring), "expired session lease immediately blocks gameplay")
 check(not Data.PurchaseNextEquipment(expiring, "Bat", expiredOffer)
  and not Data.EquipEquipment(expiring, "Bat", "wood_bat") and not Data.GrantPower(expiring, 50, "Test")
  and not Data.TryRebirth(expiring) and not Data.CanUseTrainingGround(expiring, "basic_training"), "expired lease cannot mutate progression through public operations")
 local recordBeforeExpiredClose = copy(saved.Player_251)
 leave(expiring)
 check(saved.Player_251.Cash == recordBeforeExpiredClose.Cash and expiring.KickReason ~= nil
  and saved.Player_251.Session.Id == recordBeforeExpiredClose.Session.Id, "expired close refuses a stale save instead of overwriting owned data")
 return {passed = passed, message = "Equipment, repeated Rebirths, remote abuse/state isolation, active/offline rate matrix, caps, migration, save/rejoin, failure safety"}
end
