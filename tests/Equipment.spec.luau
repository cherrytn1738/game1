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
 local Field = assert(loadstring(sources.FieldConfig))()
 -- MonetizationConfig requires the other configs; it gets the spec's copies.
 local function loadMonetization()
  local fn = assert(loadstring(sources.MonetizationConfig))
  local configs = {ProgressionConfig = Progression, WorldConfig = Worlds, FieldConfig = Field, EquipmentConfig = Equipment,
   TrainingConfig = Training}
  setfenv(fn, setmetatable({game = {GetService = function() return {WaitForChild = function(_, name) return name end} end},
   require = function(name) return assert(configs[name], name) end}, {__index = getfenv()}))
  return fn()
 end
 local Monetization = loadMonetization()
 -- Test fixtures: the shipped paid grounds have no game pass created yet (id 0).
 Training.Get("cosmic_rift").gamePassId = 111
 Training.Get("dragons_lair").gamePassId = 222
 -- ...nor do the Power, Cash and juice products, the Auto Bat pass or the Starter Pack.
 for index, product in Monetization.PowerProducts do product.developerProductId = 700 + index end
 for index, product in Monetization.CashProducts do product.developerProductId = 710 + index end
 for index, product in Monetization.JuiceProducts do product.developerProductId = 720 + index end
 for index, gift in Monetization.GiftProducts do gift.developerProductId = 730 + index end
 for index, tier in Monetization.Multipliers.Power do tier.developerProductId = 760 + index end
 for index, tier in Monetization.Multipliers.Cash do tier.developerProductId = 770 + index end
 Monetization.AutoBat.gamePassId = 801
 Monetization.StarterPack.gamePassId = 802
 local ownedPasses, passFailures = {}, {}
 local marketplace = {PromptGamePassPurchaseFinished = signal(), PromptProductPurchaseFinished = signal(), prompts = {}}
 function marketplace:PromptProductPurchase(player, productId) table.insert(self.prompts, {player = player, product = productId}) end
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
 function players:GetPlayerByUserId(id)
  for _, p in self:GetChildren() do if p.UserId == id then return p end end
  return nil
 end
 local now, tokenId = 100, 0
 local shutdown
 local storage = object("ReplicatedStorage")
 function storage:WaitForChild(name) return self:FindFirstChild(name) or name end
 local remote = object("RemoteEvent")
 remote.Name, remote.Parent = "EquipmentUpgrade", storage
 local workspace = object("Workspace")
 local studioMode = false
 local tutorialFn = assert(loadstring(sources.TutorialConfig))
 setfenv(tutorialFn, setmetatable({game = {GetService = function() return {WaitForChild = function(_, name) return name end} end},
  require = function(name) return ({EquipmentConfig = Equipment, ProgressionConfig = Progression})[name] end}, {__index = getfenv()}))
 local Tutorial = tutorialFn()
 local modules = {EquipmentConfig = Equipment, WorldConfig = Worlds, ProgressionConfig = Progression, TrainingConfig = Training,
  JuiceConfig = Juice, TutorialConfig = Tutorial, MonetizationConfig = Monetization}
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
 local afterAmethyst = 5000 - Equipment.Get("Bat", "amethyst_bat").price
 check(a.leaderstats.Cash.Value == afterAmethyst and a:GetAttribute("EquippedBat") == "amethyst_bat", "price and auto-equip")
 check(Data.OwnsEquipment(a, "Bat", "jungle_bat"), "previous equipment retained")
 check(not Data.PurchaseNextEquipment(a, "Bat", offer) and a.leaderstats.Cash.Value == afterAmethyst, "duplicate charged once")
 check(Data.EquipEquipment(a, "Bat", "wood_bat"), "older owned item equips")
 check(Data.GetNextEquipment(a, "Bat") == Equipment.GetNext("Bat", "amethyst_bat"), "older equip cannot regress progression")
 check(Data.EquipEquipment(a, "Bat", "wood_bat") and a.leaderstats.Cash.Value == afterAmethyst, "repeat equip is free")
 check(not Data.PurchaseNextEquipment(b, "Bat", b:GetAttribute("EquipmentPurchaseToken_Bat")), "insufficient Cash")

 -- Exercise the real remote handler with malformed/spam requests and two players.
 local serverFn = assert(loadstring(sources.EquipmentServer)) setfenv(serverFn, env) serverFn()
 b.leaderstats.Cash.Value = 2000
 local bOffer = b:GetAttribute("EquipmentPurchaseToken_Bat")
 remote.OnServerEvent:Fire(b, "Purchase", "Bat", bOffer)
 remote.OnServerEvent:Fire(b, "Purchase", "Bat", bOffer)
 now += 1
 remote.OnServerEvent:Fire(b, "Purchase", "Bat", bOffer)
 local afterMetal = 2000 - Equipment.Get("Bat", "metal_bat").price
 check(b.leaderstats.Cash.Value == afterMetal and b:GetAttribute("EquippedBat") == "metal_bat", "spam/replay cannot skip next item")
 check(not Data.OwnsEquipment(b, "Bat", "jungle_bat"), "replay never grants next equipment")
 remote.OnServerEvent:Fire(a, "Equip", "Bat", "jungle_bat")
 check(a:GetAttribute("EquippedBat") == "jungle_bat", "other player has independent cooldown/state")
 now += 1
 remote.OnServerEvent:Fire(b, "Equip", "Bat", "baseball")
 remote.OnServerEvent:Fire(b, {}, {}, {})
 remote.OnServerEvent:Fire(b, "Purchase", "Bat", {price = 0})
 remote.OnServerEvent:Fire(b, "Purchase", "Bat", "amethyst_bat")
 check(b:GetAttribute("EquippedBat") == "metal_bat" and b.leaderstats.Cash.Value == afterMetal, "forged request inputs rejected")
 check(Data.EquipEquipment(a, "Bat", "wood_bat"), "select old item before saving")
 leave(a)
 check(saved.Player_1.SchemaVersion == 12 and saved.Player_1.Session == nil, "version 12 save and lease release")
 check(saved.Player_1.OwnedBats.amethyst_bat and saved.Player_1.EquippedBat == "wood_bat", "ownership and selection saved separately")
 check(saved.Player_1.OtherProgress == 42 and saved.Player_1.UnlockedWorlds.world_2, "other progression preserved")
 local returned = join(1)
 check(returned.leaderstats.Cash.Value == afterAmethyst and Data.OwnsEquipment(returned, "Bat", "amethyst_bat")
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
 check(state.Power == 0 and state.Level == 1 and state.Rebirths == 0 and state.LevelCap == 20, "progression defaults (first Level Cap 20)")
 check(not Data.CanRebirth(fresh) and not Data.TryRebirth(fresh), "early Rebirth rejected")
 check(Progression.PowerRequiredForNextLevel(3) > Progression.PowerRequiredForNextLevel(2), "requirements increase")
 -- The early band: 10 + 1.5 x (Level - 1), rounded down, below Level 20 (10, 11, 13, 14, ...);
 -- from Level 20, one band per Rebirth (ProgressionConfig.LevelBands, the LONG pace).
 check(Progression.PowerRequiredForNextLevel(1) == 10 and Progression.PowerRequiredForNextLevel(2) == 11
  and Progression.PowerRequiredForNextLevel(3) == 13 and Progression.PowerRequiredForNextLevel(19) == 37
  and Progression.PowerRequiredForNextLevel(20) == 90 and Progression.PowerRequiredForNextLevel(40) == 3200,
  "early Levels need 10 + 1.5 x (Level - 1) Power; Levels 20 and 40 start their bands")
 check(Data.GrantPower(fresh, 5, "Test") and fresh:GetAttribute("Power") == 5, "partial Power grant")
 -- 60 Power in all: Levels 1-4 take 10 + 11 + 13 + 14 = 48, leaving 12 at Level 5.
 check(Data.GrantPower(fresh, 55, "Test") and fresh:GetAttribute("Level") == 5
  and fresh:GetAttribute("Power") == 12, "multiple levels consume requirements")
 for _, bad in {-1, 0/0, math.huge, "100", 1.5, Progression.MaxBaseGrant + 1} do
  check(not Data.GrantPower(fresh, bad, "Test"), "invalid Power grant rejected")
 end
 check(not Data.GrantPower(future, 100, "Test") and not Data.GrantPower(fresh, 10, {}), "invalid session/source rejected")
 state.Level = 500
 fresh:SetAttribute("Level",500)
 check(Data.GetProgression(fresh).Level == 5, "copies and display attributes cannot grant levels")
 -- Level stops at the cap; the rest of the Power stays (1,000,012 minus the 394 for Levels 5-19).
 check(Data.GrantPower(fresh, 1000000, "Test") and Data.GetProgression(fresh).Level == 20
  and Data.GetProgression(fresh).Power == 999618, "cap enforced; Power past it is kept")
 local ok, capped = Data.GrantPower(fresh, 20, "Test")
 check(ok and capped.powerGranted == 20 and Data.GetProgression(fresh).Power == 999638 and Data.GetProgression(fresh).Level == 20
  and Data.CanRebirth(fresh), "Power keeps building at the cap and Rebirth eligibility is exposed")
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
 check(state.Rebirths == 1 and state.Level == 1 and state.Power == 0 and state.LevelCap == 40, "Rebirth resets and cap grows")
 check(not Data.TryRebirth(fresh), "duplicate Rebirth rejected")
 local afterBat = 2000 - Equipment.Get("Bat", "metal_bat").price
 check(fresh.leaderstats.Cash.Value == afterBat and Data.OwnsEquipment(fresh,"Bat","metal_bat")
  and fresh:GetAttribute("EquippedBat") == "metal_bat" and fresh:GetAttribute("WorldUnlocked_world_2"), "Rebirth preserves unrelated progression")
 ok, state = Data.GrantPower(fresh, 4, "FutureTraining")
 check(ok and state.powerGranted == 8 and fresh:GetAttribute("Power") == 8, "central Ball and Rebirth multipliers (the bought Bat adds no Power)")
 check(Progression.GetLaunchSpeed(Data.GetProgression(fresh).Level) == Progression.GetLaunchSpeed(1)
  and Progression.GetLaunchAngle(Data.GetProgression(fresh).Level) == Progression.GetLaunchAngle(1)
  and Progression.GetLaunchGravityScale(Data.GetProgression(fresh).Level) == Progression.GetLaunchGravityScale(1),
  "Power/Rebirth do not affect same-level launch")
 check(Progression.GetLaunchSpeed(10) > Progression.GetLaunchSpeed(1), "a higher Level launches faster")
 leave(fresh)
 fresh = join(20)
 state = Data.GetProgression(fresh)
 check(state.Rebirths == 1 and state.LevelCap == 40 and state.Level == 1 and state.Power == 8, "new progression saves and rejoins")
 check(fresh.leaderstats.Cash.Value == afterBat and fresh:GetAttribute("EquippedBat") == "metal_bat"
  and fresh:GetAttribute("WorldCompleted_world_1"), "equipment Cash and worlds survive new schema")
 check(returned:GetAttribute("Level") == 1 and returned:GetAttribute("Power") == 0, "legacy saves gain defaults without Bat conversion")
 saved.Player_21 = {SchemaVersion = 4, Cash = 765, Power = -4, Level = 999, Rebirths = -5, LevelCap = 999999}
 local malformed = join(21)
 state = Data.GetProgression(malformed)
 check(state.Rebirths == 0 and state.LevelCap == 20 and state.Level == 20 and state.Power == 0
  and malformed.leaderstats.Cash.Value == 765, "malformed fields cannot increase derived cap or lose Cash")
 for _, bad in {0/0, math.huge, -1, "bad", 1.5} do
  local normalized = Progression.Normalize({Power=bad, Level=bad, Rebirths=bad, LevelCap=math.huge},false)
  check(normalized.Power == 0 and normalized.Level == 1 and normalized.Rebirths == 0 and normalized.LevelCap == 20, "malformed numeric fields repaired")
 end
 local migrated = Progression.Normalize({Level=900, Power=999999, Rebirths=99},true)
 check(migrated.Level == 1 and migrated.Power == 0 and migrated.Rebirths == 0, "legacy fields cannot grant new progression")
 -- Levels 2-7 take 11 + 13 + 14 + 16 + 17 + 19 = 90 of the 100, leaving 10 at Level 8 (it needs 20).
 local over = Progression.Normalize({Level=2, Power=100, Rebirths=0},false)
 check(over.Level == 8 and over.Power == 10, "saved excess Power normalizes consistently")
 check(Worlds.Get("world_1").endDistance == 5000 and Worlds.Get("world_2").endDistance == 6000
  and Worlds.Get("world_3").endDistance == 7000 and Worlds.Get("world_4").endDistance == 8000, "world endpoints unchanged")
 -- Physical grounds: access derives from private Rebirths or a Roblox pass, and offline
 -- grants use the best usable ground inside the atomic login transaction.
 local multipliers = {}
 for _, entry in Training.Grounds do table.insert(multipliers, entry.powerMultiplier) end
 check(table.concat(multipliers, ",") == "1,5,10,20,10,25,35,50,70,35,90,120,160,210,120,270,350,450,580,400,30",
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
 check(table.concat(Training.Get("dragons_lair").worlds, ",") == "world_1,world_2,world_3,world_4"
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
 -- World 4's grounds: the same pattern again (Snow Globe on Cosmic Rift's pass).
 local fourWorlds = {world_1=true, world_2=true, world_3=true, world_4=true}
 check(table.concat(Training.GetHub("world_4").grounds, ",") == "sandbox_diamond,pinball_cage,cereal_bowl_stadium,toy_soldier_fort,snow_globe,dragons_lair"
  and Training.GetPlatePosition(Training.Get("sandbox_diamond"), "world_4") == Training.GetPlatePosition(Training.Get("basic_training"), "world_1"),
  "World 4's hub has its row of six, Dragon's Lair last")
 check(not Training.CanUse("sandbox_diamond", 99, nil, allWorlds) and Training.CanUse("sandbox_diamond", 0, nil, fourWorlds),
  "World 4 grounds wait for World 4")
 check(Training.IsUnlocked("pinball_cage", 20, fourWorlds) and not Training.IsUnlocked("pinball_cage", 19, fourWorlds)
  and Training.IsUnlocked("cereal_bowl_stadium", 22, fourWorlds) and not Training.IsUnlocked("cereal_bowl_stadium", 21, fourWorlds)
  and Training.IsUnlocked("toy_soldier_fort", 24, fourWorlds) and not Training.IsUnlocked("toy_soldier_fort", 23, fourWorlds),
  "World 4 Rebirth tiers continue on")
 check(Training.CanUse("snow_globe", 0, {cosmic_rift=true}, fourWorlds) and not Training.CanUse("snow_globe", 0, {cosmic_rift=true}, allWorlds)
  and Training.GetPassGround(Training.Get("snow_globe")).id == "cosmic_rift" and #Training.PassGrounds == 2,
  "Snow Globe uses Cosmic Rift's pass in World 4")
 check(Training.GetBestGround(0, nil, fourWorlds).id == "sandbox_diamond" and Training.GetBestGround(24, nil, fourWorlds).id == "toy_soldier_fort",
  "best ground looks across all four Worlds")
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
 local ok, gain=Data.GrantPower(trainee,Progression.TrainingBase*ground.powerMultiplier,"ActiveTraining")
 -- 5 x 5 x 3 (two Rebirths) = 75 Power from Level 1: Levels 1-5 take 64, leaving 11 at Level 6.
 check(ok and gain.powerGranted==75 and trainee:GetAttribute("Level")==6 and trainee:GetAttribute("Power")==11,
  "active training uses central multiplier/advancement")
 trainee:SetAttribute("TrainingActive",false)
 leave(trainee)
 check(saved.Player_30.SelectedTrainingGround==nil and saved.Player_30.SchemaVersion==12 and saved.Player_30.LastLogoutTime==math.floor(now),"no ground selection saved; logout saved")
 trainee=join(30)
 check(trainee:GetAttribute("OfflineTrainingGround")=="enchanted_grove" and trainee:GetAttribute("OfflinePowerEarned")==0,"rejoin with zero offline duration")
 local nowStamp=100000
 -- Offline: 25% of the ground's Training rate at the player's Level (5 Power a hit at Level 1).
 local levelOneBase=Progression.TrainingBase
 local amount, seconds=Training.GetOfflineReward(nowStamp-60,nowStamp,"basic_training",levelOneBase)
 check(amount==37 and seconds==60,"short offline duration")
 amount,seconds=Training.GetOfflineReward(nowStamp-3600,nowStamp,"enchanted_grove",levelOneBase)
 check(amount==11250 and seconds==3600,"ground offline rate")
 amount,seconds=Training.GetOfflineReward(1,nowStamp,"basic_training",levelOneBase)
 check(seconds==Training.MaximumOfflineSeconds and amount==18000,"offline cap enforced")
 check(Progression.GetTrainingBase==nil and Training.GetOfflineReward(nowStamp-60,nowStamp,"basic_training",Progression.TrainingBase)==37,
  "offline Training's rate is the same at every Level (one Training base, no Level scaling)")
 for _, timestamp in {0,-1,"bad",math.huge,0/0,1.5,nowStamp+10} do
  check(Training.GetOfflineReward(timestamp,nowStamp,"basic_training",levelOneBase)==0,"malformed or future timestamp cannot award")
 end
 check(Training.GetOfflineReward(nil,nowStamp,"basic_training",levelOneBase)==0,"missing timestamp cannot award")
 for _, base in {-1,0/0,math.huge,"5"} do
  check(Training.GetOfflineReward(nowStamp-60,nowStamp,"basic_training",base)==0,"malformed Training base cannot award")
 end
 -- The run cap: a return fills at most half the Power still needed for the Level Cap; the 3x adds
 -- the reward twice more, up to all of it.
 check(Progression.GetPowerToLevelCap(Progression.Normalize({},false))==442
  and Progression.GetPowerToLevelCap({Level=19,Power=10,LevelCap=20})==27
  and Progression.GetPowerToLevelCap({Level=20,Power=5,LevelCap=20})==0,"Power left to the Level Cap")
 check(Training.GetOfflinePowerLimit(442)==221 and Training.GetOfflinePowerLimit(1)==0 and Training.GetOfflinePowerLimit(0)==0,
  "a return fills at most half the run left")
 check(Training.GetOfflineTripleExtra(37,442)==74 and Training.GetOfflineTripleExtra(200,442)==242
  and Training.GetOfflineTripleExtra(221,442)==221 and Training.GetOfflineTripleExtra(0,442)==0,
  "the 3x adds the reward twice more, up to the whole run left")
 saved.Player_31={SchemaVersion=5,Cash=321,Power=0,Level=1,Rebirths=2,LevelCap=30,SelectedTrainingGround="advanced_training",LastLogoutTime=math.floor(now)-10,OtherProgress=123}
 loseResponse.Player_31=true
 local offline=join(31)
 -- Ten seconds at Enchanted Grove: 31 x 3 (two Rebirths) = 93 Power from Level 1: Levels 1-6
 -- take 81, leaving 12 at Level 7.
 check(offline:GetAttribute("OfflinePowerEarned")==93 and offline:GetAttribute("Level")==7
  and offline:GetAttribute("Power")==12,"offline grant once despite committed response loss")
 check(saved.Player_31.LastLogoutTime==nil and saved.Player_31.OtherProgress==123 and saved.Player_31.SelectedTrainingGround==nil,"timestamp consumed atomically, unknown fields preserved, retired selection dropped")
 check(offline.leaderstats.Cash.Value==321 and offline:GetAttribute("OfflineTrainingGround")=="enchanted_grove","best usable ground used, not the old saved selection")
 players.PlayerAdded:Fire(offline)
 check(offline:GetAttribute("Power")==12,"same session cannot reprocess offline reward")
 saved.Player_32={SchemaVersion=5,Cash=777,Power=3,Level=1,Rebirths=0,SelectedTrainingGround="expert_training",LastLogoutTime=math.floor(now)-60}
 local fallback=join(32)
 check(fallback:GetAttribute("OfflineTrainingGround")=="basic_training" and fallback:GetAttribute("OfflinePowerEarned")==37,"removed selection ignored; offline uses the best usable ground")
 -- A minute at Basic Training: 37 Power. 3 + 37 = 40 Power from Level 1: Levels 1-3 take 34, leaving 6 at Level 4.
 check(fallback:GetAttribute("Level")==4 and fallback:GetAttribute("Power")==6 and fallback.leaderstats.Cash.Value==777,"offline progression preserves Cash")
 -- Offline Training waits for the tutorial: a minute away mid-tutorial earns nothing and shows
 -- no Welcome Back (OfflineSeconds 0), and the logout time is still used up.
 saved.Player_399={SchemaVersion=11,Cash=0,Power=8,Level=2,Rebirths=0,TutorialCompleted=false,TutorialStep="EarnPower",
  TutorialProgress=18,LastLogoutTime=math.floor(now)-60}
 local midTutorial=join(399)
 check(midTutorial:GetAttribute("TutorialStep")=="EarnPower" and midTutorial:GetAttribute("OfflinePowerEarned")==0
  and midTutorial:GetAttribute("OfflineSeconds")==0 and midTutorial:GetAttribute("OfflineTripleAvailable")==false
  and midTutorial:GetAttribute("Power")==8 and midTutorial:GetAttribute("Level")==2,"no offline Training during the tutorial")
 check(saved.Player_399.LastLogoutTime==nil,"mid-tutorial logout time is used up, so it never pays later")
 -- Welcome Back's 3x offer: the receipt adds the login's offline reward twice more, once.
 local decisions = Enum.ProductPurchaseDecision
 local tripleReceipt = {PlayerId=32, PurchaseId="triple-1", ProductId=555, CurrencySpent=9, CurrencyType=Enum.CurrencyType.Robux}
 check(fallback:GetAttribute("OfflineTripleAvailable")==true,"an offline reward below the cap offers the 3x purchase")
 -- 40 + 74 = 114 Power from Level 1: Levels 1-7 take 100, leaving 14 at Level 8.
 check(Data.ClaimOfflineTriple(fallback,tripleReceipt)==decisions.PurchaseGranted and Data.GetProgression(fallback).Level==8
  and Data.GetProgression(fallback).Power==14 and fallback:GetAttribute("OfflineTripleAvailable")==false,
  "3x adds the 37 offline Power twice more (with the Ball and Rebirth multipliers) and withdraws the offer")
 check(saved.Player_32.RobuxSpent==9 and saved.Player_32.RobuxPurchases.Receipts[1]=="triple-1" and saved.Player_32.Power==14,
  "a paid 3x is saved straight away with its Robux")
 check(Data.ClaimOfflineTriple(fallback,tripleReceipt)==decisions.PurchaseGranted and Data.GetProgression(fallback).Power==14,
  "a repeated receipt is acknowledged without granting again")
 check(Data.ClaimOfflineTriple(fallback,{PlayerId=32,PurchaseId="triple-2",ProductId=555,CurrencySpent=9})==decisions.NotProcessedYet
  and Data.GetProgression(fallback).Power==14,"a second purchase in the same login has no offer to fill")
 check(Data.ClaimOfflineTriple(fallback,{PlayerId=99,PurchaseId="triple-3",ProductId=555,CurrencySpent=9})==decisions.NotProcessedYet
  and Data.ClaimOfflineTriple(failed,{PlayerId=6,PurchaseId="triple-4",ProductId=555,CurrencySpent=9})==decisions.NotProcessedYet,
  "another player's receipt or a failed load is not granted")
 check(trainee:GetAttribute("OfflineTripleAvailable")==false,"no offline reward, no 3x offer")
 saved.Player_33={SchemaVersion=4,Cash=999,Power=41,Level=2,Rebirths=1,LastLogoutTime=1}
 local legacy=join(33)
 -- The saved 41 Power at Level 2 is re-levelled on the current curve: 11 + 13 + 14 for Levels 2-4, 3 left at Level 5.
 check(legacy:GetAttribute("Power")==3 and legacy:GetAttribute("Level")==5 and legacy:GetAttribute("OfflinePowerEarned")==0,"migration preserves progression without fabricated offline time")
 saved.Player_34={SchemaVersion=5,Cash=500,Power=0,Level=20,Rebirths=0,SelectedTrainingGround="fake",LastLogoutTime=1}
 local atCap=join(34)
 check(atCap:GetAttribute("OfflineSeconds")>0 and atCap:GetAttribute("Level")==20 and atCap:GetAttribute("OfflinePowerEarned")==0
  and atCap:GetAttribute("Power")==0 and atCap:GetAttribute("OfflineTripleAvailable")==false,"at the Level Cap offline adds nothing and offers no 3x")
 check(Data.GrantPower(atCap,10,"ActiveTraining") and atCap:GetAttribute("Level")==20 and atCap:GetAttribute("Power")==10,
  "Training Power still banks at the cap")
 check(not Data.CanUseTrainingGround(failed,"basic_training"),"failed loads cannot train")
 -- Paid grounds: Roblox pass ownership is read at login (before the offline grant) and on
 -- the server's purchase event; lookups that fail grant nothing.
 ownedPasses["35:111"] = true
 saved.Player_35={SchemaVersion=7,Cash=1,Power=0,Level=1,Rebirths=0,LastLogoutTime=math.floor(now)-12}
 local passHolder=join(35)
 check(passHolder:GetAttribute("OfflineTrainingGround")=="cosmic_rift" and passHolder:GetAttribute("OfflinePowerEarned")==75,"offline uses an owned paid ground with no Rebirths")
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
 -- The Studio switch leaves a save that is still in its tutorial alone (its Ball step is buying
 -- the first Ball), so that tutorial plays as for a real new player.
 saved.Player_560={SchemaVersion=11,Cash=10,Level=3,Power=0,Rebirths=0,TutorialCompleted=false,TutorialStep="BuyBall",TutorialProgress=0}
 local studioLearner=join(560)
 check(studioLearner:GetAttribute("TutorialStep")=="BuyBall" and not Data.OwnsEquipment(studioLearner,"Ball","practice_ball")
  and not Data.OwnsEquipment(studioLearner,"Ball","supernova_ball"), "OwnAllBalls is not applied while the tutorial runs")
 check(Data.PurchaseNextEquipment(studioLearner,"Ball",studioLearner:GetAttribute("EquipmentPurchaseToken_Ball"))
  and Data.EquipEquipment(studioLearner,"Ball","practice_ball")
  and studioLearner:GetAttribute("TutorialStep")=="ReachLevel", "so the Sandlot Ball can be bought and equipped, completing the step")
 leave(studioLearner)
 workspace:SetAttribute("OwnAllBalls", nil)
 studioMode = false
 workspace:SetAttribute("UnlockAllWorlds", nil)
 -- World 2's balls are their own series: their own offer, World 2 must be unlocked, then in order.
 local worldOneBalls = Equipment.GetSeriesItems("Ball")
 local worldTwoBalls = Equipment.GetSeriesItems("Ball", "world_2")
 local supernova = worldOneBalls[#worldOneBalls]
 local aboveWorldOne = true
 for _, ball in worldTwoBalls do
  aboveWorldOne = aboveWorldOne and ball.powerGainMultiplier > supernova.powerGainMultiplier and ball.price > supernova.price
   and ball.series == "world_2"
 end
 check(#worldTwoBalls == 10 and worldTwoBalls[1].id == "dino_egg_ball" and worldTwoBalls[10].id == "chrono_orb" and aboveWorldOne
  and #worldOneBalls == 10 and #Equipment.GetItems("Ball") == 40, "World 2 sells ten balls above World 1's best")
 local worldThreeBalls = Equipment.GetSeriesItems("Ball", "world_3")
 local chrono = worldTwoBalls[#worldTwoBalls]
 local aboveChrono = true
 for _, ball in worldThreeBalls do
  aboveChrono = aboveChrono and ball.powerGainMultiplier > chrono.powerGainMultiplier and ball.price > chrono.price
   and ball.series == "world_3"
 end
 local worldFourBalls = Equipment.GetSeriesItems("Ball", "world_4")
 local singularity = worldThreeBalls[#worldThreeBalls]
 local aboveSingularity = true
 for _, ball in worldFourBalls do
  aboveSingularity = aboveSingularity and ball.powerGainMultiplier > singularity.powerGainMultiplier and ball.price > singularity.price
   and ball.series == "world_4"
 end
 check(#worldFourBalls == 10 and worldFourBalls[1].id == "dandelion_puff_ball" and worldFourBalls[10].id == "dream_orb" and aboveSingularity
  and Equipment.GetSeriesInfo("Ball", "world_4").requiredWorld == "world_4" and worldFourBalls[10].price < 9000000000000,
  "World 4 sells ten balls above the Singularity Orb, below the Cash cap")
 -- Each series rises in Power and price, so later Balls are always upgrades.
 for _, series in {worldOneBalls, worldTwoBalls, worldThreeBalls, worldFourBalls} do
  for index = 2, #series do
   check(series[index].powerGainMultiplier > series[index - 1].powerGainMultiplier and series[index].price > series[index - 1].price,
    series[index].id .. " beats " .. series[index - 1].id .. " and costs more")
  end
 end
 -- Equipment roles: every Ball carries only a Power multiplier, every Bat only a Cash one.
 for _, ball in Equipment.GetItems("Ball") do
  check(type(ball.powerGainMultiplier) == "number" and ball.powerGainMultiplier >= 1 and ball.cashMultiplier == nil
   and ball.rewardMultiplier == nil, ball.id .. " is a Power multiplier only")
 end
 for _, bat in Equipment.GetItems("Bat") do
  check(type(bat.cashMultiplier) == "number" and bat.cashMultiplier >= 1 and bat.powerGainMultiplier == nil
   and bat.rewardMultiplier == nil, bat.id .. " is a Cash multiplier only")
 end
 -- World 1's balls, exactly (the Sandlot Ball's $2 is the tutorial's first purchase).
 local worldOneTable = {{"baseball", 1, 0}, {"practice_ball", 3, 2}, {"bubblegum_ball", 5, 10}, {"crystal_ball", 12, 40},
  {"frost_comet", 30, 150}, {"inferno_ball", 75, 500}, {"thunder_ball", 200, 1500}, {"galaxy_ball", 500, 4500},
  {"dragonfire_ball", 1250, 14000}, {"supernova_ball", 3500, 40000}}
 for index, row in worldOneTable do
  local ball = Equipment.GetSeriesItems("Ball")[index]
  check(ball.id == row[1] and ball.powerGainMultiplier == row[2] and ball.price == row[3],
   string.format("World 1 ball %d is %s at %dx Power for $%d", index, row[1], row[2], row[3]))
 end
 -- Bats for sale, in order: each earns more Cash than the one before and costs more. (The
 -- exclusive Catastrophe Bat is outside the series; see the Shop tests.)
 local bats = Equipment.GetSeriesItems("Bat")
 local batOrder = {}
 for _, bat in bats do table.insert(batOrder, bat.id .. "=" .. bat.cashMultiplier) end
 check(table.concat(batOrder, ",") == "wood_bat=1,metal_bat=1.5,jungle_bat=2,amethyst_bat=3,candy_cane_bat=4,"
  .. "frostbite_bat=6,magma_bat=9,lightning_bat=13,dragon_bone_bat=19,celestial_bat=28,rolling_pin_bat=42", "Bat Cash multipliers in order")
 for index = 2, #bats do
  check(bats[index].cashMultiplier > bats[index - 1].cashMultiplier and bats[index].price > bats[index - 1].price,
   bats[index].id .. " beats " .. bats[index - 1].id .. " and costs more")
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
  and shopper:GetAttribute("EquippedBall")=="dino_egg_ball" and shopper.leaderstats.Cash.Value==5000000-Equipment.Get("Ball","dino_egg_ball").price
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
  and futureShopper.leaderstats.Cash.Value==3000000000-Equipment.Get("Ball","solar_cell_ball").price
  and Data.GetNextEquipment(futureShopper,"Ball","world_3").id=="hover_ball",
  "World 3's first ball is bought from its own series")
 leave(futureShopper)
 check(saved.Player_41.OwnedBalls.solar_cell_ball==true,"World 3 balls save with the rest")
 passFailures[36] = true
 ownedPasses["36:111"] = true
 saved.Player_36={SchemaVersion=7,Cash=1,Power=0,Level=1,Rebirths=0,LastLogoutTime=math.floor(now)-12}
 local lookupOutage=join(36)
 check(Data.IsReady(lookupOutage) and not Data.CanUseTrainingGround(lookupOutage,"cosmic_rift")
  and lookupOutage:GetAttribute("OfflinePowerEarned")==7,"pass lookup outage loads safely with Rebirth grounds only")
 -- Four minutes at Basic Training: 150 Power, under the run cap. Levels 1-9 take 142, leaving 8 at Level 10.
 local offlineBase=Training.GetOfflineReward(100,340,"basic_training",levelOneBase)
 local simulated=Progression.Normalize({},false)
 Progression.Advance(simulated,math.min(offlineBase*Progression.GetPowerMultiplier(simulated.Rebirths),
  Training.GetOfflinePowerLimit(Progression.GetPowerToLevelCap(simulated))))
 check(offlineBase==150 and simulated.Level==10 and simulated.Power==8,"minutes offline advance multiple levels")
 offlineBase=Training.GetOfflineReward(100,100000,"basic_training",levelOneBase)
 simulated=Progression.Normalize({Rebirths=0,Level=1,Power=0},false)
 Progression.Advance(simulated,math.min(offlineBase*Progression.GetPowerMultiplier(simulated.Rebirths),
  Training.GetOfflinePowerLimit(Progression.GetPowerToLevelCap(simulated))))
 -- 18,000 Power for 8 hours, held to half the 442 the run needs: 221 takes Levels 1-12 (216),
 -- leaving 5 at Level 13.
 check(offlineBase==18000 and simulated.Level==13 and simulated.Power==5,"the 8-hour reward is held to half the run left")
 check(Data.GetBestTrainingGround(trainee).id=="enchanted_grove" and Data.GetBestTrainingGround(fallback).id=="basic_training"
  and not Data.CanUseTrainingGround(fallback,"dragons_lair"),"players have independent access")
 -- Two complete Rebirth cycles use the same public server operations as gameplay.
 local cyclist = join(100)
 cyclist.leaderstats.Cash.Value = 8000
 for _, category in Equipment.CategoryOrder do
  check(Data.PurchaseNextEquipment(cyclist, category, cyclist:GetAttribute("EquipmentPurchaseToken_" .. category)), "cycle equipment purchase")
  -- (A new save is in its tutorial, whose Ball is equipped by hand rather than on purchase.)
  Data.EquipEquipment(cyclist, category, Equipment.GetItems(category)[2].id)
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
  local base = Progression.TrainingBase * best.powerMultiplier
  local granted, tick = Data.GrantPower(cyclist, base, "ActiveTraining")
  check(granted and tick.powerGranted == base * Equipment.Get("Ball", cyclist:GetAttribute("EquippedBall")).powerGainMultiplier
   * Progression.GetPowerMultiplier(rebirths + 1), "ground, Ball and Rebirth multipliers compose")
 end
 leave(cyclist)
 local cycleRecord = saved.Player_100
 check(cycleRecord.Rebirths == 2 and cycleRecord.LevelCap == 60 and cycleRecord.SelectedTrainingGround == nil, "two Rebirths saved without a ground selection")
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
 check(Data.GrantPower(requester, 9, "Test") and Data.GetProgression(requester).Power == 9, "forged multiplier cannot increase Power gain")
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
 check(Data.GetProgression(durable).Rebirths == 1 and Data.GetProgression(durable).LevelCap == 40, "saved Rebirth is restored after response loss")
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
   for _, duration in {12, 3*60*60, Training.MaximumOfflineSeconds, Training.MaximumOfflineSeconds+60*60} do
    local trainingBase = Progression.TrainingBase
    local base, seconds = Training.GetOfflineReward(nowStamp-duration, nowStamp, trainingGround.id, trainingBase)
    local eligibleSeconds = math.min(duration, Training.MaximumOfflineSeconds)
    local expectedBase = math.floor(eligibleSeconds * trainingBase * trainingGround.powerMultiplier / trainingGround.interval * Training.OfflinePowerRateMultiplier)
    check(base == expectedBase and seconds == eligibleSeconds, "offline duration boundary " .. label .. "/" .. duration)
    local rateState = Progression.Normalize({Rebirths=rebirths, Level=1, Power=0}, false)
    local remaining = Progression.GetPowerToLevelCap(rateState)
    local power = math.min(base * multiplier, Training.GetOfflinePowerLimit(remaining))
    Progression.Advance(rateState, power)
    check(power <= remaining * Training.OfflineRunShare and rateState.Level < rateState.LevelCap
     and rateState.Power < Progression.PowerRequiredForNextLevel(rateState.Level), "a return fills at most half the run " .. label .. "/" .. duration)
    local extra = Training.GetOfflineTripleExtra(power, remaining)
    Progression.Advance(rateState, extra)
    check(power + extra <= remaining and (rateState.Level < rateState.LevelCap or rateState.Power == 0),
     "the 3x never passes the cap " .. label .. "/" .. duration)
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
   local levelOneGround = Progression.TrainingBase * best.powerMultiplier
   local baseOffline = math.floor(12 * levelOneGround / best.interval * Training.OfflinePowerRateMultiplier)
   local expected = Progression.Normalize({Rebirths=rebirths, Level=1, Power=0}, false)
   Progression.Advance(expected, baseOffline * Progression.GetPowerMultiplier(rebirths))
   local actual = Data.GetProgression(fixture)
   check(fixture:GetAttribute("OfflinePowerEarned") == baseOffline * Progression.GetPowerMultiplier(rebirths)
    and fixture:GetAttribute("OfflineTrainingGround") == best.id
    and actual.Level == expected.Level and actual.Power == expected.Power, "actual offline login uses the best ground, whatever was saved")
   check(not Data.CanUseTrainingGround(fixture, trainingGround.id) == not Training.IsUnlocked(trainingGround.id, rebirths, bothWorlds)
    and actual.LevelCap == Progression.GetLevelCap(rebirths), "actual login access and repaired saved caps")
   local granted, tick = Data.GrantPower(fixture, levelOneGround, "ActiveTraining")
   check(granted and tick.powerGranted == levelOneGround * Progression.GetPowerMultiplier(rebirths), "actual active grant ground/Rebirth cross-product")
   leave(fixture)
   check(saved[key].Cash == 456 and saved[key].OtherProgress == 73 and saved[key].UnlockedWorlds.world_2
    and saved[key].CompletedWorlds.world_1 and saved[key].SelectedTrainingGround == nil, "offline and active grants preserve unrelated fields")
  end
 end

 -- Offline never finishes a run: 8 hours a Level short of the second cap fill half the Power
 -- left; the 3x fills the rest exactly, and the Rebirth stays the player's choice.
 do
  local capTwo = Progression.GetLevelCap(2)
  local left = Progression.PowerRequiredForNextLevel(capTwo - 1)
  local half = Training.GetOfflinePowerLimit(left)
  for id = 220, 222 do
   saved["Player_" .. id] = {SchemaVersion=5, Cash=100, Rebirths=2, Level=capTwo - 1, Power=0,
    SelectedTrainingGround="expert_training", LastLogoutTime=math.floor(now)-Training.MaximumOfflineSeconds}
  end
  local offlineCap = join(220)
  check(offlineCap:GetAttribute("OfflineSeconds") == Training.MaximumOfflineSeconds and offlineCap:GetAttribute("OfflinePowerEarned") == half
   and Data.GetProgression(offlineCap).Level == capTwo - 1 and Data.GetProgression(offlineCap).Power == half
   and not Data.CanRebirth(offlineCap), "an 8-hour return stops at half the run left")
  check(offlineCap:GetAttribute("OfflineTripleAvailable") == true and offlineCap:GetAttribute("OfflineTriplePower") == left,
   "the 3x offer shows the whole run left")
  check(Data.ClaimOfflineTriple(offlineCap, {PlayerId=220, PurchaseId="triple-220", ProductId=555, CurrencySpent=9}) == decisions.PurchaseGranted
   and Data.GetProgression(offlineCap).Level == capTwo and Data.GetProgression(offlineCap).Power == 0
   and Data.CanRebirth(offlineCap) and offlineCap:GetAttribute("OfflineTriplePower") == left, "the 3x fills the run exactly to the Level Cap")
  check(Data.GetProgression(offlineCap).Rebirths == 2, "offline cap never automatically Rebirths")
  -- Training between the login and the 3x: the claim stops at the Level Cap, and at the cap it
  -- waits for Roblox to retry rather than take Robux for nothing.
  local partway, capped = join(221), join(222)
  -- (x3 for the two Rebirths: 1,500 and 3,000 Power.)
  check(Data.GrantPower(partway, 500, "ActiveTraining") and not Data.CanRebirth(partway)
   and Data.GrantPower(capped, 1000, "ActiveTraining") and Data.CanRebirth(capped), "training after the login")
  check(Data.ClaimOfflineTriple(partway, {PlayerId=221, PurchaseId="triple-221", ProductId=555, CurrencySpent=9}) == decisions.PurchaseGranted
   and Data.GetProgression(partway).Level == capTwo and Data.GetProgression(partway).Power == 0
   and partway:GetAttribute("OfflineTriplePower") == half + (left - half - 1500), "the 3x stops at the Level Cap")
  local banked = Data.GetProgression(capped).Power
  local receipt = {PlayerId=222, PurchaseId="triple-222", ProductId=555, CurrencySpent=9}
  check(Data.ClaimOfflineTriple(capped, receipt) == decisions.NotProcessedYet and Data.GetProgression(capped).Power == banked
   and capped:GetAttribute("OfflineTripleAvailable") == true and saved.Player_222.RobuxSpent ~= 9, "at the cap the 3x waits instead of granting nothing")
  check(Data.TryRebirth(capped), "explicit Rebirth with the 3x still waiting")
  local expected = Progression.Normalize({Rebirths=3, Level=1, Power=0}, false)
  Progression.Advance(expected, left - half)
  check(Data.ClaimOfflineTriple(capped, receipt) == decisions.PurchaseGranted and Data.GetProgression(capped).Level == expected.Level
   and Data.GetProgression(capped).Power == expected.Power and capped:GetAttribute("OfflineTripleAvailable") == false,
   "a retried 3x after the Rebirth adds the offer's Power, no more")
  for _, player in {offlineCap, partway, capped} do leave(player) end
 end
 local oneBelow = Progression.Normalize({Rebirths=0, Level=Progression.BaseLevelCap - 1,
  Power=Progression.PowerRequiredForNextLevel(Progression.BaseLevelCap - 1)-1}, false)
 Progression.Advance(oneBelow, 1)
 check(oneBelow.Level == Progression.BaseLevelCap and oneBelow.Power == 0, "exact Power boundary advances to cap")
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
  check(progress.Rebirths == (version < 4 and 0 or 1) and progress.LevelCap == (version < 4 and 20 or 40)
   and migration:GetAttribute("OfflinePowerEarned") == 0, "each old schema defaults progression only when needed and fabricates no offline time")
 end
 -- Three sessions combine every persistent field through real public data operations.
 -- These keys exist only in the in-memory store, so accelerated progress cannot touch
 -- a development player's legitimate save.
 local cyclePlayer = join(250)
 cyclePlayer.leaderstats.Cash.Value = 10000
 for _, category in Equipment.CategoryOrder do
  check(Data.PurchaseNextEquipment(cyclePlayer, category, cyclePlayer:GetAttribute("EquipmentPurchaseToken_" .. category)), "session A purchases each equipment category")
  Data.EquipEquipment(cyclePlayer, category, Equipment.GetItems(category)[2].id) -- (the tutorial Ball isn't equipped on purchase)
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
  and saved.Player_300.SchemaVersion==12, "atomic migration discards even malformed Tee fields")
 check(not Data.PurchaseNextEquipment(migrated,"Tee","fake")
  and not Data.EquipEquipment(migrated,"Tee","basic_tee"), "removed category operations rejected")
 local migratedCash=migrated.leaderstats.Cash.Value
 remote.OnServerEvent:Fire(migrated,"Purchase","Tee","fake")
 remote.OnServerEvent:Fire(migrated,"Equip","Tee","basic_tee")
 remote.OnServerEvent:Fire(migrated,"Equip","Bat",{cashMultiplier=100000})
 remote.OnServerEvent:Fire(migrated,"Equip","Ball",{powerGainMultiplier=100000})
 check(migrated.leaderstats.Cash.Value==migratedCash and migrated:GetAttribute("EquippedBat")=="metal_bat"
  and migrated:GetAttribute("EquippedBall")=="practice_ball",
  "removed category and fake multiplier remote inputs do not change equipment or Cash")
 leave(migrated)
 check(saved.Player_300.OwnedTees==nil and saved.Player_300.EquippedTee==nil
  and saved.Player_300.OtherProgress==123 and saved.Player_300.UnlockedWorlds.world_2
  and saved.Player_300.SelectedTrainingGround==nil, "save retains valid unrelated fields and drops the retired selection")
 migrated=join(300)
 check(migrated:GetAttribute("EquippedBat")=="metal_bat" and migrated:GetAttribute("EquippedBall")=="practice_ball"
  and Data.OwnsEquipment(migrated,"Bat","wood_bat"), "schema 6 rejoin preserves Bat/Ball equipment")

 -- The equipped Ball multiplies every Power source (offline, Training, hits); the Bat never does.
 local fixtureId=400
 for _,entry in {{id="baseball",gain=1},{id="practice_ball",gain=3},{id="bubblegum_ball",gain=5},{id="crystal_ball",gain=12}} do
  for rebirths=0,2 do
   fixtureId+=1
   local key="Player_"..fixtureId
   saved[key]={SchemaVersion=5,Cash=5000,Power=0,Level=1,Rebirths=rebirths,
    OwnedBalls={baseball=true,[entry.id]=true},EquippedBall=entry.id,
    OwnedBats={wood_bat=true,celestial_bat=true},EquippedBat="celestial_bat",
    SelectedTrainingGround="basic_training",LastLogoutTime=math.floor(now)-12}
   local fixture=join(fixtureId)
   local offlineBase=Training.GetOfflineReward(1,13,Training.GetBestGround(rebirths).id,Progression.TrainingBase)
   check(fixture:GetAttribute("OfflinePowerEarned")==Progression.GetPowerGrant(offlineBase,rebirths,entry.gain),
    "offline bonus uses the saved Ball and Rebirth exactly once (never the Bat)")
   local trainingOk,tick=Data.GrantPower(fixture,20,"ActiveTraining")
   check(trainingOk and tick.powerGranted==20*entry.gain*(rebirths+1), "active Training composes Ball and Rebirth")
   local hitOk,hit=Data.GrantPower(fixture,2,"CompletedHit",entry.id)
   check(hitOk and hit.powerGranted==2*entry.gain*(rebirths+1), "hit snapshot composes Ball and Rebirth")
   check(Data.EquipEquipment(fixture,"Bat","wood_bat"),"Bat switch")
   local _,afterBat=Data.GrantPower(fixture,20,"ActiveTraining")
   check(afterBat.powerGranted==tick.powerGranted,"the Bat does not affect Training Power")
   local _,hitAfterBat=Data.GrantPower(fixture,2,"CompletedHit",entry.id)
   check(hitAfterBat.powerGranted==hit.powerGranted,"the Bat does not affect hit Power")
   fixture:SetAttribute("TrainingActive",true)
   check(not Data.EquipEquipment(fixture,"Ball","baseball"),"Ball switch blocked during Training")
   fixture:SetAttribute("TrainingActive",false)
   fixture:SetAttribute("HitActive",true)
   check(not Data.EquipEquipment(fixture,"Ball","baseball"),"Ball switch blocked during flight")
   fixture:SetAttribute("HitActive",false)
   check(Data.EquipEquipment(fixture,"Ball","baseball"),"owned Ball switches after activity")
   local _,olderHit=Data.GrantPower(fixture,2,"CompletedHit",entry.id)
   check(olderHit.powerGranted==hit.powerGranted,"accepted hit snapshot survives later equipment selection")
   local _,newTick=Data.GrantPower(fixture,20,"ActiveTraining")
   check(newTick.powerGranted==20*(rebirths+1),"next Training uses the newly equipped Ball")
   check(not Data.GrantPower(fixture,20,"ActiveTraining",1000),"a number cannot supply a Ball bonus")
  end
 end
 check(not Data.GrantPower(migrated,20,"CompletedHit","crystal_ball"),"unowned snapshot rejected")
 check(not Data.GrantPower(migrated,20,"CompletedHit","metal_bat"),"a Bat cannot stand in for the Ball snapshot")
 -- Worked formulas. Training: base 5, Ball 3x (Sandlot), Rebirth 2x (1 Rebirth), ground 5x is
 -- folded into the ground's base Power: 5 x 5 x 3 x 2 = 150.
 check(Progression.GetPowerGrant(5 * 5, 1, Equipment.Get("Ball", "practice_ball").powerGainMultiplier) == 150,
  "Training: base x ground x Ball x Rebirth")
 -- Real hit: the Training base x HitPowerPerSecond for each second in play (rounded), then
 -- Ball x Rebirth, no ground, never the Level. 10 seconds: 5 x 0.37 x 10 = 18.5 -> 19.
 local hitBase = Progression.GetHitPowerBase(10)
 check(hitBase == 19 and Progression.GetPowerGrant(hitBase, 1, 3) == 19 * 3 * 2, "hit: base x Ball x Rebirth")
 check(Progression.GetHitPowerBase(-5) == 0, "a hit with no time in play earns no Power")
 check(Progression.GetPowerGrant(3,1,1.5)==9 and Progression.GetPowerGrant(1,0,1.5)==1,
  "whole Power rounds only after composing bonuses")
 -- Balance shapes (tools/balance tunes the numbers; these keep the relationships).
 -- Past World 4's end the tail bands reach MaxPower (about Level 555), where requirements stop.
 local previousRequirement, requirementsRise, clampedFrom = 0, true, nil
 for level = 1, 600 do
  local required = Progression.PowerRequiredForNextLevel(level)
  if previousRequirement == Progression.MaxPower then
   requirementsRise = requirementsRise and required == Progression.MaxPower
  else
   requirementsRise = requirementsRise and required > previousRequirement
  end
  if required == Progression.MaxPower and not clampedFrom then clampedFrom = level end
  previousRequirement = required
 end
 check(requirementsRise and (clampedFrom == nil or clampedFrom > 520),
  "every Level needs more Power than the one before, across band breakpoints, until MaxPower (past World 4)")
 -- A grant bigger than MaxPower (a late offline return or 3x) levels through in pieces, none lost.
 local big = {Power = 0, Level = 500, LevelCap = 520, Rebirths = 25}
 local grant = 2 * Progression.MaxPower
 Progression.Advance(big, grant)
 local consumed = big.Power
 for level = 500, big.Level - 1 do consumed += Progression.PowerRequiredForNextLevel(level) end
 local single = {Power = 0, Level = 500, LevelCap = 520, Rebirths = 25}
 Progression.Advance(single, Progression.MaxPower)
 check(big.Level > single.Level and big.Power < Progression.MaxPower and math.abs(consumed - grant) < 64,
  "a grant above MaxPower keeps levelling instead of being cut off")
 local capped = {Power = 0, Level = 519, LevelCap = 520, Rebirths = 25}
 Progression.Advance(capped, grant)
 check(capped.Level == 520 and capped.Power == Progression.MaxPower, "at the Level Cap Power still banks only up to MaxPower")
 check(Progression.GetLevelCap(0) == 20 and Progression.GetLevelCap(1) == 40 and Progression.GetLevelCap(5) == 120,
  "Level Cap is 20 x (Rebirths + 1)")
 check(Progression.TrainingBase == 5 and Progression.GetTrainingBase == nil and Progression.TrainingBasePerLevel == nil,
  "the Training base is one constant, 5 Power a hit, with no Level scaling left")
 -- A Basic Training hit (the base TrainingService grants) at different Levels, everything else equal.
 for index, level in {1, 5, 20, 40, 100} do
  local rebirths = level > 20 and math.ceil(level / 20) - 1 or 0
  saved["Player_" .. (570 + index)] = {SchemaVersion = 11, Cash = 0, Level = level, Power = 0, Rebirths = rebirths, TutorialCompleted = true}
  local leveled = join(570 + index)
  check(leveled:GetAttribute("Level") == level and select(2, Data.GrantPower(leveled, Progression.TrainingBase, "ActiveTraining")).powerGranted
   == 5 * (rebirths + 1), "Level " .. level .. ": Basic Training gives 5 x (Rebirths + 1), never more for the Level")
  leave(leveled)
 end
 saved.Player_576 = {SchemaVersion = 11, Cash = 0, Level = 40, Power = 0, Rebirths = 0, TutorialCompleted = true,
  OwnedBalls = {baseball = true, practice_ball = true}, EquippedBall = "practice_ball",
  OwnedBats = {wood_bat = true, catastrophe_bat = true}, EquippedBat = "catastrophe_bat", OwnedJuices = {power_punch = 1, cash_splash = 1}}
 local trainer = join(576)
 local function hit() return select(2, Data.GrantPower(trainer, Progression.TrainingBase, "ActiveTraining")).powerGranted end
 check(trainer:GetAttribute("Level") == 20 and hit() == 15, "Sandlot Ball: 5 x 3 = 15 (the Catastrophe Bat adds nothing)")
 check(Data.UseJuice(trainer, "cash_splash") and hit() == 15, "Cash Splash leaves Training Power alone")
 check(Data.UseJuice(trainer, "power_punch") and hit() == 30, "Power Punch doubles it: 30")
 check(select(2, Data.GrantPower(trainer, Progression.TrainingBase * 5, "ActiveTraining")).powerGranted == 150,
  "a 5x ground: 5 x 5 x 3 x 2 = 150")
 leave(trainer)
 local speedTable, speedSteps = Progression.LaunchSpeedTable, Progression.LaunchSpeedSteps
 local speedRises = true
 for level = 2, speedTable[#speedTable][1] do
  speedRises = speedRises and Progression.GetLaunchSpeed(level) > Progression.GetLaunchSpeed(level - 1)
 end
 local stepsInOrder = speedSteps[1][1] == speedTable[#speedTable][1] + 1
 for index = 2, #speedSteps do
  stepsInOrder = stepsInOrder and speedSteps[index][1] > speedSteps[index - 1][1]
   and Progression.GetLaunchSpeed(speedSteps[index][1] - 1) == speedSteps[index - 1][2]
   and Progression.GetLaunchSpeed(speedSteps[index][1]) == speedSteps[index][2]
 end
 check(speedRises and stepsInOrder and Progression.GetLaunchSpeed(10000) == speedSteps[#speedSteps][2],
  "launch speed rises through the table, then steps through measured speeds and holds after the last")
 -- The early launch curve: Level 1 hits faster and steeper, blending evenly into the table, which
 -- (and the 38-degree loft) is untouched from EarlyLaunch.untilLevel on.
 local early = Progression.EarlyLaunch
 check(Progression.GetLaunchSpeed(1) == early.speed and Progression.GetLaunchAngle(1) == early.angleDegrees
  and early.speed > speedTable[1][2] and early.angleDegrees > Progression.LaunchAngleDegrees and early.angleDegrees <= 50,
  "Level 1 launches at the early speed and a steeper loft (at most 50 degrees)")
 local smooth, inRange = true, true
 for level = 2, early.untilLevel + 5 do
  local speedStep = Progression.GetLaunchSpeed(level) - Progression.GetLaunchSpeed(level - 1)
  local angleStep = Progression.GetLaunchAngle(level - 1) - Progression.GetLaunchAngle(level)
  -- Small rising steps up to and into the table at untilLevel; after it each Level uses its own
  -- measured speed (chosen for where it lands, so speeds may dip), at the table's loft.
  smooth = smooth and (level > early.untilLevel or speedStep > 0 and speedStep < 2) and angleStep >= 0 and angleStep < 1
  local angle = Progression.GetLaunchAngle(level)
  inRange = inRange and angle > 0 and angle >= Progression.LaunchAngleDegrees and angle <= early.angleDegrees
 end
 check(smooth and inRange, "early speeds rise and the loft eases down every Level, with no jump into the table")
 -- The lighter first-flight gravity: strongest at Level 1, easing back to normal gravity by untilLevel.
 local gravitySmooth = Progression.GetLaunchGravityScale(1) == early.gravityScale
  and early.gravityScale > 0 and early.gravityScale < 1
 for level = 2, early.untilLevel do
  local step = Progression.GetLaunchGravityScale(level) - Progression.GetLaunchGravityScale(level - 1)
  gravitySmooth = gravitySmooth and step > 0 and step < .05
 end
 for _, level in {early.untilLevel, early.untilLevel + 1, 40, 140, 141, 370, 10000} do
  gravitySmooth = gravitySmooth and Progression.GetLaunchGravityScale(level) == 1
 end
 check(gravitySmooth, "early hits fall lighter, easing back to normal gravity by untilLevel and after")
 -- Eased: the first Levels keep most of it (Level 5 still has over 3/4 of Level 1's reduction).
 local reduction = 1 - early.gravityScale
 check(1 - Progression.GetLaunchGravityScale(5) > reduction * .75
  and Progression.GetLaunchGravityScale(1) < Progression.GetLaunchGravityScale(2),
  "the lighter gravity is strongest at Level 1 and mostly kept through the first Levels")
 check(Progression.GetLaunchSpeed(21) == 78 and Progression.GetLaunchAngle(21) == 38 and Progression.GetLaunchGravityScale(21) == 1,
  "Level 21 launches exactly as before the early curve")
 local tableKept = Progression.GetLaunchAngle(early.untilLevel) == Progression.LaunchAngleDegrees
  and Progression.GetLaunchAngle(10000) == Progression.LaunchAngleDegrees
 for _, point in speedTable do
  if point[1] >= early.untilLevel then tableKept = tableKept and Progression.GetLaunchSpeed(point[1]) == point[2] end
 end
 -- The table ends at untilLevel; from there every Level is a measured step: one per Level to 140
 -- (the last smooth measurement, 505), then the high-speed steps from 141 (660 ... 716 at World 3's
 -- end, Level 370), then World 4's to its end at Level 490 (717).
 local stepAt = {}
 for _, step in speedSteps do stepAt[step[1]] = step[2] end
 local perLevel = true
 for level = early.untilLevel + 1, 140 do perLevel = perLevel and stepAt[level] ~= nil end
 check(tableKept and speedTable[#speedTable][1] == early.untilLevel and perLevel and stepAt[140] == 505 and stepAt[141] == 660
  and stepAt[370] == 716 and speedSteps[#speedSteps][1] == 490 and speedSteps[#speedSteps][2] == 717,
  "the table hands over to measured steps at untilLevel; 140 = 505, 141 = 660, 370 = 716, the last 490 = 717")
 -- Hits start over in each later World (WorldConfig launchLevels, GetWorldLaunchLevel): the
 -- early floaty arc below the World's range, rising after it, its end reached exactly at the
 -- range's last Level; its start pay makes even its shortest hit pay more than the previous
 -- World's farthest, and no earlier World ever pays more at the same Level.
 local function worldPay(level, world)
  local distance = math.min(Progression.GetExpectedHitDistance(Progression.GetWorldLaunchLevel(level, world)), world.endDistance)
  return Progression.GetHitCash(distance, world.cashMultiplier, Field.GetSection(distance, world).rewardMultiplier, 1, 1, world.cashBase)
 end
 local previousWorld
 for _, world in Worlds.Worlds do
  local range = world.launchLevels
  if not range then
   check(Progression.GetWorldLaunchLevel(37, world) == 37 and Progression.GetWorldLaunchLevel(450, world) == 450
    and (world.cashBase or 0) == 0, world.id .. " uses the player's Level and has no start pay")
  else
   local early = Progression.EarlyLaunch.untilLevel
   local rises, belowEarly, last = true, true, 0
   for level = 1, 600 do
    local launch = Progression.GetWorldLaunchLevel(level, world)
    rises = rises and launch >= last
    last = launch
    if level < range.from then belowEarly = belowEarly and launch <= early end
   end
   check(rises and belowEarly and Progression.GetWorldLaunchLevel(1, world) == 1
    and Progression.GetWorldLaunchLevel(range.from, world) == early, world.id .. "'s hits start over and only ever grow with Level")
   check(Progression.GetExpectedHitDistance(Progression.GetWorldLaunchLevel(range.to - 1, world)) < world.endDistance
    and Progression.GetExpectedHitDistance(Progression.GetWorldLaunchLevel(range.to, world)) >= world.endDistance,
    world.id .. " reaches its end exactly at Level " .. range.to)
   local farthest = Progression.GetHitCash(previousWorld.endDistance, previousWorld.cashMultiplier,
    Field.GetSection(previousWorld.endDistance, previousWorld).rewardMultiplier, 1, 1, previousWorld.cashBase)
   check(Progression.GetHitCash(81, world.cashMultiplier, 1, 1, 1, world.cashBase) > farthest,
    world.id .. "'s shortest hit pays more than " .. previousWorld.id .. "'s farthest")
   local earlierPaysLess = true
   for level = 1, 520 do earlierPaysLess = earlierPaysLess and worldPay(level, world) > worldPay(level, previousWorld) end
   check(earlierPaysLess, previousWorld.id .. " never pays more than " .. world.id .. " at the same Level")
  end
  previousWorld = world
 end
 check(Worlds.Get("world_2").launchLevels.from == 150 and Worlds.Get("world_3").launchLevels.from == 250
  and Worlds.Get("world_4").launchLevels.from == 370 and Worlds.Get("world_4").launchLevels.to == 490,
  "each World's range starts where the World before it ends")
 check(Progression.GetHitCash(81, 1, 1, 1) == 1 and Progression.GetHitCash(95, 1, 1, 1) == 1 and Progression.GetHitCash(0, 1, 1, 1) == 1,
  "early hits pay $1, so the tutorial's $2 takes two hits")
 check(Progression.GetHitCash(4000, 1, 1, 1) > Progression.GetHitCash(2000, 1, 1, 1)
  and Progression.GetHitCash(5000, Worlds.Get("world_2").cashMultiplier, 1, 1) > Progression.GetHitCash(5000, 1, 1, 1)
  and Progression.GetHitCash(5000, 1, 1, 2) > Progression.GetHitCash(5000, 1, 1, 1), "Cash rises with distance, World and Bat")
 local lastFreeMultiplier, freeGroundsRise = 0, true
 for _, hub in Training.Hubs do
  for _, id in hub.grounds do
   local ground = Training.Get(id)
   if not Training.IsPaid(ground) then
    freeGroundsRise = freeGroundsRise and ground.powerMultiplier > lastFreeMultiplier
    lastFreeMultiplier = ground.powerMultiplier
   end
  end
 end
 check(freeGroundsRise, "each free ground trains faster than every free ground before it, World after World")
 -- Juice: Power Punch (2x Power) and Cash Splash (2x Cash), 10 minutes each, on real time (the
 -- saved ActiveJuices are expiry times, so a timer keeps running while the player is away).
 local shippedJuice = assert(loadstring(sources.JuiceConfig))()
 local juiceList = {}
 for _, definition in shippedJuice.GetAll() do
  table.insert(juiceList, table.concat({definition.id, definition.effect, definition.multiplier, definition.durationSeconds}, ":"))
 end
 check(table.concat(juiceList, ",") == "power_punch:Power:2:600,cash_splash:Cash:2:600"
  and shippedJuice.Get("power_punch").displayName == "Power Punch" and shippedJuice.Get("cash_splash").displayName == "Cash Splash",
  "exactly two juices: Power Punch (2x Power) and Cash Splash (2x Cash), 600 seconds each, with stable ids")
 local PUNCH, SPLASH = "power_punch", "cash_splash"
 local function expiry(p, id) return p.ActiveJuices:GetAttribute(id) end
 local function owned(p, id) return p.OwnedJuices:GetAttribute(id) end
 local juicer = join(400)
 check(juicer.OwnedJuices and juicer.ActiveJuices and next(juicer.OwnedJuices:GetAttributes()) == nil, "new players start with no juice")
 check(Data.GetJuiceMultiplier(juicer, "Power") == 1 and Data.GetJuiceMultiplier(juicer, "Cash") == 1, "no juice means no bonus")
 check(not Data.UseJuice(juicer, PUNCH) and expiry(juicer, PUNCH) == nil, "cannot drink a juice you have none of")
 check(not Data.UseJuice(juicer, "fake_juice") and not Data.UseJuice(juicer, 5) and not Data.UseJuice(juicer, nil), "unknown juice ids are refused")
 check(not Data.GrantJuice(juicer, "fake_juice", 1, "Test") and not Data.GrantJuice(juicer, PUNCH, 0, "Test")
  and not Data.GrantJuice(juicer, PUNCH, 1.5, "Test"), "invalid juice grants rejected")
 check(Data.GrantJuice(juicer, PUNCH, 3, "Test") and Data.GrantJuice(juicer, SPLASH, 2, "Test")
  and owned(juicer, PUNCH) == 3 and owned(juicer, SPLASH) == 2, "server grants add juice")
 local trainingBase = select(2, Data.GrantPower(juicer, 10, "ActiveTraining")).powerGranted
 local start = math.floor(now)
 -- The remote passes only the id; any extra values a client sends are ignored.
 local juiceFn = assert(loadstring(sources.JuiceServer)) setfenv(juiceFn, env) juiceFn()
 local juiceRemote = storage:FindFirstChild("JuiceRequest")
 juiceRemote.OnServerEvent:Fire(juicer, "Use", PUNCH, 4, 99999, start + 99999)
 check(owned(juicer, PUNCH) == 2 and expiry(juicer, PUNCH) == start + 600 and Data.GetJuiceMultiplier(juicer, "Power") == 2,
  "drinking consumes exactly one and runs 600 s at 2x (client values ignored)")
 check(juiceRemote.replies[juicer][1] == true and juiceRemote.replies[juicer][2] == "POWER PUNCH ACTIVATED!\n2x POWER FOR 10 MIN",
  "the player is told it is active")
 check(Data.GetJuiceMultiplier(juicer, "Cash") == 1, "Power Punch leaves Cash alone")
 check(select(2, Data.GrantPower(juicer, 10, "ActiveTraining")).powerGranted == trainingBase * 2, "Power Punch doubles Training Power")
 check(select(2, Data.GrantPower(juicer, 10, "CompletedHit", nil, 1)).powerGranted == trainingBase
  and select(2, Data.GrantPower(juicer, 10, "CompletedHit", nil, 2)).powerGranted == trainingBase * 2,
  "a hit's Power uses the juice snapshot from its swing (none, or 2x)")
 now += 60
 local extended, extendedMessage = Data.UseJuice(juicer, PUNCH)
 check(extended and extendedMessage == "POWER PUNCH +10 MIN" and expiry(juicer, PUNCH) == start + 1200
  and Data.GetJuiceMultiplier(juicer, "Power") == 2 and owned(juicer, PUNCH) == 1,
  "a second Power Punch adds 10 minutes to the time left and stays 2x (never 4x)")
 check(Data.UseJuice(juicer, SPLASH) and expiry(juicer, SPLASH) == start + 660 and Data.GetJuiceMultiplier(juicer, "Cash") == 2
  and Data.GetJuiceMultiplier(juicer, "Power") == 2, "Power Punch and Cash Splash run side by side, each 2x its own gain")
 leave(juicer)
 check(saved.Player_400.ActiveJuices[PUNCH] == start + 1200 and saved.Player_400.ActiveJuices[SPLASH] == start + 660
  and saved.Player_400.OwnedJuices[PUNCH] == 1 and saved.Player_400.OwnedJuices[SPLASH] == 1,
  "counts and expiry times save (no extra copy is used up)")
 -- Three minutes away: the timers kept running.
 now += 180
 local returning = join(400)
 check(expiry(returning, PUNCH) - math.floor(now) == 1200 - 240 and expiry(returning, SPLASH) - math.floor(now) == 660 - 240
  and owned(returning, PUNCH) == 1 and owned(returning, SPLASH) == 1, "rejoining keeps the counts and the real time left")
 leave(returning)
 -- Long after both ended: they are gone at login.
 now += 1000
 returning = join(400)
 check(expiry(returning, PUNCH) == nil and expiry(returning, SPLASH) == nil and Data.GetJuiceMultiplier(returning, "Power") == 1
  and next(saved.Player_400.ActiveJuices) == nil, "juices that ended while away are dropped at login (and from the save)")
 -- A juice ends on its own (the server's expiry sweep); its bonus stops even before the sweep.
 studioMode = true
 workspace:SetAttribute("StudioJuiceSeconds", 5)
 check(Data.UseJuice(returning, PUNCH) and expiry(returning, PUNCH) == math.floor(now) + 5,
  "in Studio, StudioJuiceSeconds shortens a juice to watch it end")
 workspace:SetAttribute("StudioJuiceSeconds", nil)
 studioMode = false
 now += 5
 check(Data.GetJuiceMultiplier(returning, "Power") == 1 and expiry(returning, PUNCH) ~= nil, "the bonus stops the moment the time is up")
 Data.ExpireJuices(math.floor(now))
 check(expiry(returning, PUNCH) == nil, "the expiry sweep removes the ended juice (no client request)")
 leave(returning)
 check(saved.Player_400.ActiveJuices[PUNCH] == nil, "an ended juice is not saved")
 saved.Player_401 = {SchemaVersion = 7, Cash = 5, OwnedJuices = "corrupt"}
 local corrupt = join(401)
 check(not Data.IsReady(corrupt) and saved.Player_401.OwnedJuices == "corrupt", "malformed juice data fails closed")
 local nowSeconds = math.floor(now)
 saved.Player_402 = {SchemaVersion = 10, Cash = 5, OwnedJuices = {cash_splash = 3, removed_juice = 4, power_punch = -1},
  ActiveJuices = {cash_splash = 12.5, removed_juice = nowSeconds + 60, power_punch = "soon"}}
 local cleaned = join(402)
 check(Data.IsReady(cleaned) and owned(cleaned, SPLASH) == 3 and owned(cleaned, "removed_juice") == nil
  and owned(cleaned, PUNCH) == nil and expiry(cleaned, SPLASH) == nil and expiry(cleaned, "removed_juice") == nil
  and expiry(cleaned, PUNCH) == nil, "unknown ids, bad counts and malformed timers are dropped")
 leave(cleaned)
 saved.Player_403 = {SchemaVersion = 10, Cash = 5, ActiveJuices = {power_punch = nowSeconds - 1, cash_splash = nowSeconds + 10 ^ 7}}
 local stale = join(403)
 check(Data.IsReady(stale) and expiry(stale, PUNCH) == nil and expiry(stale, SPLASH) == nil,
  "an expired or impossibly long saved timer is removed")
 leave(stale)
 -- A save from before real-time timers held the seconds left: they start again from login.
 saved.Player_404 = {SchemaVersion = 10, Cash = 5, ActiveJuices = {power_punch = 90}}
 local legacyJuice = join(404)
 check(expiry(legacyJuice, PUNCH) == nowSeconds + 90, "an old seconds-left timer carries over")
 leave(legacyJuice)
 -- Offline Training never gets Power Punch, even while it runs (a minute at Basic Training: 37).
 saved.Player_405 = {SchemaVersion = 10, Cash = 0, Level = 1, Power = 3, Rebirths = 0, TutorialCompleted = true,
  ActiveJuices = {power_punch = nowSeconds + 600}, LastLogoutTime = nowSeconds - 60}
 local napper = join(405)
 check(napper:GetAttribute("OfflinePowerEarned") == 37 and Data.GetJuiceMultiplier(napper, "Power") == 2,
  "Offline Training is not doubled; the juice still runs online")
 leave(napper)

 -- New-player tutorial (Schema 10): moved only by the server's own events, saved, resumable.
 local newbie = join(900)
 local function step(p) return p:GetAttribute("TutorialStep"), p:GetAttribute("TutorialProgress") end
 check(step(newbie) == "EarnPower" and select(2, step(newbie)) == 0, "a new save starts the tutorial at 0/30 Power")
 check(Data.GrantPower(newbie, 20, "ActiveTraining") and select(2, step(newbie)) == 20, "granted Power counts toward the Power step")
 Data.RecordBattingCash(newbie, 50)
 check(select(2, step(newbie)) == 20, "Cash does not count toward the Power step")
 Data.GrantPower(newbie, 20, "ActiveTraining")
 check(step(newbie) == "EarnCash" and select(2, step(newbie)) == 0, "30 Power moves on to the Cash step")
 Data.GrantPower(newbie, 20, "ActiveTraining")
 check(select(2, step(newbie)) == 0, "Power does not count toward the Cash step")
 Data.RecordBattingCash(newbie, 1)
 newbie.leaderstats.Cash.Value = 0
 check(step(newbie) == "EarnCash" and select(2, step(newbie)) == 1, "batting Cash counts, and spending it never takes progress back")
 leave(newbie)
 check(saved.Player_900.SchemaVersion == 12 and saved.Player_900.TutorialCompleted == false
  and saved.Player_900.TutorialStep == "EarnCash" and saved.Player_900.TutorialProgress == 1, "an unfinished tutorial saves its step and count")
 newbie = join(900)
 check(step(newbie) == "EarnCash" and select(2, step(newbie)) == 1, "rejoining resumes the same step and count")
 Data.RecordBattingCash(newbie, 1)
 check(step(newbie) == "BuyBall", "$2 of batting Cash moves on to buying the Ball")
 -- Client-side changes can't fake owning it: only the server's own data counts.
 newbie.OwnedBalls:SetAttribute(Tutorial.BallId, true)
 check(Data.GrantPower(newbie, 1, "ActiveTraining") and step(newbie) == "BuyBall"
  and not Data.OwnsEquipment(newbie, "Ball", Tutorial.BallId), "a faked Ball does not complete the step")
 newbie.OwnedBalls:SetAttribute(Tutorial.BallId, nil)
 newbie.leaderstats.Cash.Value = 1000
 check(Data.PurchaseNextEquipment(newbie, "Bat", newbie:GetAttribute("EquipmentPurchaseToken_Bat")) and step(newbie) == "BuyBall",
  "buying a Bat does not complete the Ball step")
 -- In the tutorial, buying its Ball doesn't equip it: the player equips it in the Inventory.
 local bought, boughtMessage = Data.PurchaseNextEquipment(newbie, "Ball", newbie:GetAttribute("EquipmentPurchaseToken_Ball"))
 check(bought and Data.OwnsEquipment(newbie, "Ball", Tutorial.BallId) and newbie:GetAttribute("EquippedBall") == "baseball"
  and step(newbie) == "BuyBall" and newbie:GetAttribute("TutorialBoughtBall") == true
  and string.find(boughtMessage, "Inventory", 1, true) ~= nil,
  "buying the " .. Tutorial.BallId .. " leaves it unequipped and the step waiting")
 check(Data.EquipEquipment(newbie, "Bat", "wood_bat") and step(newbie) == "BuyBall", "equipping something else does not complete it")
 check(Data.EquipEquipment(newbie, "Ball", Tutorial.BallId) and step(newbie) == "ReachLevel",
  "equipping it moves on to reaching Level 20")
 -- The Ball step is always played: owning the Ball is not enough. Bought early in the tutorial,
 -- it still waits for the Ball to be equipped at step 3.
 local early = join(561)
 early.leaderstats.Cash.Value = 5
 check(step(early) == "EarnPower" and Data.PurchaseNextEquipment(early, "Ball", early:GetAttribute("EquipmentPurchaseToken_Ball"))
  and step(early) == "EarnPower" and early:GetAttribute("TutorialBoughtBall") == true, "buying the Ball early is remembered")
 check(Data.EquipEquipment(early, "Ball", "baseball") and step(early) == "EarnPower", "(then swapped back to the Baseball)")
 leave(early)
 early = join(561)
 Data.GrantPower(early, Tutorial.PowerGoal, "ActiveTraining")
 Data.RecordBattingCash(early, Tutorial.CashGoal)
 check(step(early) == "BuyBall" and early:GetAttribute("TutorialBoughtBall") == true,
  "after the Cash step the Ball step shows (owned, not equipped; the purchase survived a rejoin)")
 check(Data.EquipEquipment(early, "Ball", Tutorial.BallId) and step(early) == "ReachLevel", "equipping it completes the step")
 leave(early)
 -- Owning it without buying it in the tutorial never completes the step.
 saved.Player_562 = {SchemaVersion = 11, Cash = 0, Level = 3, Power = 0, Rebirths = 0, TutorialCompleted = false,
  TutorialStep = "BuyBall", TutorialProgress = 0, OwnedBalls = {baseball = true, [Tutorial.BallId] = true}, EquippedBall = Tutorial.BallId}
 local holder = join(562)
 Data.GrantPower(holder, 1, "ActiveTraining")
 check(step(holder) == "BuyBall", "owning (even equipping) the Ball without the tutorial purchase does not complete the step")
 holder:SetAttribute("TutorialBoughtBall", true)
 Data.GrantPower(holder, 1, "ActiveTraining")
 check(step(holder) == "BuyBall", "a faked purchase flag (a display attribute) changes nothing")
 leave(holder)
 check(Equipment.Get("Ball", Tutorial.BallId).price == 2 and Equipment.Get("Ball", Tutorial.BallId).powerGainMultiplier == 3
  and Tutorial.RebirthLevel == 20, "the tutorial's Ball costs $2 for 3x Power, and the first Rebirth is at Level 20")
 Data.GrantPower(newbie, 5000, "ActiveTraining")
 check(newbie:GetAttribute("Level") == 20 and step(newbie) == "Rebirth", "the Level Cap (20) moves on to the Rebirth step")
 check(Data.TryRebirth(newbie) and step(newbie) == Tutorial.Complete and newbie:GetAttribute("Rebirths") == 1,
  "a successful Rebirth completes the tutorial")
 leave(newbie)
 check(saved.Player_900.TutorialCompleted == true and saved.Player_900.TutorialStep == nil
  and saved.Player_900.TutorialProgress == nil, "completion saves")
 newbie = join(900)
 check(step(newbie) == Tutorial.Complete, "a completed save never sees the tutorial again")
 leave(newbie)
 check(Data.CompleteTutorial == nil and Data.SetTutorialStep == nil and storage:FindFirstChild("TutorialRequest") == nil,
  "there is no request a client could send to move the tutorial")
 -- Older and malformed saves.
 for id, case in {
  [901] = {record = {SchemaVersion = 9, Cash = 0}, step = "EarnPower", why = "an untouched pre-tutorial save starts it"},
  [902] = {record = {SchemaVersion = 9, Cash = 500, Level = 3}, step = Tutorial.Complete, why = "a progressed pre-tutorial save skips it"},
  [903] = {record = {SchemaVersion = 6, Cash = 0, Rebirths = 2}, step = Tutorial.Complete, why = "a Rebirthed legacy save skips it"},
  [904] = {record = {SchemaVersion = 9, Cash = 0, OwnedBats = {wood_bat = true, metal_bat = true}}, step = Tutorial.Complete,
   why = "a legacy save that bought equipment skips it"},
  [905] = {record = {SchemaVersion = 10, Cash = 0, TutorialCompleted = true}, step = Tutorial.Complete, why = "a completed save stays complete"},
  [906] = {record = {SchemaVersion = 10, Cash = 0, TutorialCompleted = "yes", Level = 4}, step = Tutorial.Complete,
   why = "a malformed flag on a progressed save completes it"},
  [907] = {record = {SchemaVersion = 10, Cash = 0, TutorialCompleted = false, TutorialStep = "Nonsense", TutorialProgress = -3},
   step = "EarnPower", why = "a malformed step on a fresh save restarts it"},
  [908] = {record = {SchemaVersion = 10, Cash = 0, TutorialCompleted = false, TutorialStep = "EarnPower", TutorialProgress = 99},
   step = "EarnPower", why = "an out-of-range count resets to 0"},
  [909] = {record = {SchemaVersion = 10, Cash = 0, TutorialCompleted = false, TutorialStep = "BuyBall", TutorialBoughtBall = true,
   OwnedBalls = {baseball = true, [Tutorial.BallId] = true}, EquippedBall = Tutorial.BallId}, step = "ReachLevel",
   why = "a resumed step that is already done moves on at login"},
 } do
  saved["Player_" .. id] = case.record
  local p = join(id)
  check(Data.IsReady(p) and step(p) == case.step and (select(2, step(p)) or 0) == 0, case.why)
  leave(p)
 end
 -- Monetization (MonetizationConfig, ProductServer). The shipped config: three Power products and
 -- the Auto Bat pass at their intended prices, every id still 0 (so nothing can be prompted).
 local shipped = loadMonetization()
 local amounts, prices, names = {}, {}, {}
 for _, product in shipped.PowerProducts do
  table.insert(amounts, product.powerAmount)
  table.insert(prices, product.robuxPrice)
  check(not names[product.id] and product.developerProductId == 0, "each Power product is named once and has no real id yet")
  names[product.id] = true
 end
 check(#shipped.PowerProducts == 3 and table.concat(amounts, ",") == "10000,100000,1000000" and table.concat(prices, ",") == "11,45,95",
  "the Power products give 10K, 100K and 1M Power for 11, 45 and 95 Robux")
 check(shipped.AutoBat.gamePassId == 0 and shipped.AutoBat.robuxPrice == 25 and shipped.GetPowerProduct(0) == nil
  and shipped.GetPowerProduct(-1) == nil and shipped.GetPowerProduct("701") == nil, "Auto Bat costs 25 Robux; id 0 matches no product")
 for index, product in Monetization.PowerProducts do
  check(Monetization.GetPowerProduct(700 + index) == product, "a real developer product id finds its product")
 end
 local productFn = assert(loadstring(sources.ProductServer)) setfenv(productFn, env) productFn()
 local shop = storage:FindFirstChild("Monetization")
 local robux = Enum.CurrencyType.Robux
 local function receipt(userId, purchaseId, productIndex)
  return {PlayerId = userId, PurchaseId = purchaseId, ProductId = 700 + productIndex,
   CurrencySpent = Monetization.PowerProducts[productIndex].robuxPrice, CurrencyType = robux}
 end
 -- Power products add exactly their amount (no Ball or Rebirth multiplier), through the normal
 -- Level path, once per receipt.
 saved.Player_310 = {SchemaVersion = 10, Cash = 0, Level = 1, Power = 0, Rebirths = 1, TutorialCompleted = true,
  OwnedBalls = {baseball = true, practice_ball = true}, EquippedBall = "practice_ball"}
 local spender = join(310)
 local expected = Progression.Normalize({Level = 1, Power = 0, Rebirths = 1}, false)
 Progression.Advance(expected, 10000)
 local spent = 0
 for level = 1, expected.Level - 1 do spent += Progression.PowerRequiredForNextLevel(level) end
 check(marketplace.ProcessReceipt(receipt(310, "power-1", 1)) == decisions.PurchaseGranted
  and spender:GetAttribute("Level") == expected.Level and spender:GetAttribute("Power") == expected.Power
  and expected.Level > 2 and spent + expected.Power == 10000, "10K adds exactly 10,000 Power, over several Levels")
 check(shop.replies[spender] and shop.replies[spender][1] == "PowerGranted" and shop.replies[spender][2] == 10000,
  "the client is told what was added")
 check(saved.Player_310.Power == expected.Power and saved.Player_310.RobuxSpent == 11
  and table.find(saved.Player_310.RobuxPurchases.Receipts, "power-1"), "a Power purchase is saved straight away with its Robux")
 shop.replies[spender] = nil
 check(marketplace.ProcessReceipt(receipt(310, "power-1", 1)) == decisions.PurchaseGranted
  and spender:GetAttribute("Power") == expected.Power and saved.Player_310.RobuxSpent == 11 and shop.replies[spender] == nil,
  "a repeated receipt is acknowledged without adding Power again")
 spender:SetAttribute("TrainingActive", true)
 Progression.Advance(expected, 100000)
 check(marketplace.ProcessReceipt(receipt(310, "power-2", 2)) == decisions.PurchaseGranted
  and spender:GetAttribute("Level") == expected.Level and spender:GetAttribute("Power") == expected.Power,
  "100K adds exactly 100,000 Power, also while Training")
 spender:SetAttribute("TrainingActive", nil)
 leave(spender)
 spender = join(310)
 check(marketplace.ProcessReceipt(receipt(310, "power-1", 1)) == decisions.PurchaseGranted
  and spender:GetAttribute("Power") == expected.Power and saved.Player_310.RobuxSpent == 56,
  "a granted receipt retried after a rejoin adds nothing")
 leave(spender)
 -- At the Level Cap the Power banks, as Training's does; no Rebirth happens by itself.
 saved.Player_311 = {SchemaVersion = 10, Cash = 0, Level = 20, Power = 5, Rebirths = 0, TutorialCompleted = true}
 local capped = join(311)
 capped:SetAttribute("BattingActive", true)
 check(marketplace.ProcessReceipt(receipt(311, "power-3", 3)) == decisions.PurchaseGranted
  and capped:GetAttribute("Level") == 20 and capped:GetAttribute("Power") == 1000005 and capped:GetAttribute("Rebirths") == 0
  and Data.CanRebirth(capped), "1M at the Level Cap banks 1,000,000 Power (also while batting) and waits for a Rebirth")
 capped:SetAttribute("BattingActive", nil)
 check(marketplace.ProcessReceipt(receipt(999, "power-4", 1)) == decisions.NotProcessedYet,
  "a buyer who has left is retried by Roblox later")
 check(marketplace.ProcessReceipt({PlayerId = 311, PurchaseId = "power-5", ProductId = 799, CurrencySpent = 5}) == decisions.NotProcessedYet
  and capped:GetAttribute("Power") == 1000005, "an unknown product grants nothing")
 check(Data.ClaimPowerProduct(failed, receipt(6, "power-6", 1), 10000) == decisions.NotProcessedYet
  and Data.ClaimPowerProduct(capped, receipt(2, "power-7", 1), 10000) == decisions.NotProcessedYet
  and Data.ClaimPowerProduct(capped, receipt(311, "power-8", 1), -5) == decisions.NotProcessedYet
  and capped:GetAttribute("Power") == 1000005, "a failed load, another player's receipt or a bad amount grants nothing")
 leave(capped)
 -- A tutorial player's purchase is real Power: it completes the Power step and the tutorial goes on.
 local learner = join(312)
 check(step(learner) == "EarnPower" and marketplace.ProcessReceipt(receipt(312, "power-9", 1)) == decisions.PurchaseGranted
  and step(learner) == "EarnCash" and learner:GetAttribute("Level") == 20, "bought Power moves the tutorial on to its Cash step")
 leave(learner)
 -- Auto Bat: Roblox pass ownership, checked at login and on purchase; only owners can turn it on.
 ownedPasses["314:801"] = true
 local walker, owner = join(313), join(314)
 check(walker:GetAttribute("AutoBatOwned") == false and owner:GetAttribute("AutoBatOwned") == true
  and owner:GetAttribute("AutoBatEnabled") == false, "ownership comes from Roblox and Auto Bat starts off")
 shop.OnServerEvent:Fire(walker, "AutoBat", true)
 check(walker:GetAttribute("AutoBatEnabled") == false and shop.replies[walker][1] == "AutoBatRefused",
  "a player without the pass cannot turn it on")
 shop.OnServerEvent:Fire(owner, "AutoBat", true)
 check(owner:GetAttribute("AutoBatEnabled") == true and walker:GetAttribute("AutoBatEnabled") == false,
  "an owner turns it on, for themselves only")
 now += 0.1
 shop.OnServerEvent:Fire(owner, "AutoBat", false)
 check(owner:GetAttribute("AutoBatEnabled") == true, "requests closer than the toggle limit are ignored")
 now += 0.5
 for _, bad in {{"AutoBat", "no"}, {"AutoBat"}, {"Power", false}, {nil, false}} do
  shop.OnServerEvent:Fire(owner, table.unpack(bad))
 end
 check(owner:GetAttribute("AutoBatEnabled") == true, "malformed requests change nothing")
 now += 0.5
 shop.OnServerEvent:Fire(owner, "AutoBat", false)
 check(owner:GetAttribute("AutoBatEnabled") == false, "an owner turns it off")
 marketplace.PromptGamePassPurchaseFinished:Fire(walker, 801, false)
 check(walker:GetAttribute("AutoBatOwned") == false, "a cancelled purchase grants nothing")
 marketplace.PromptGamePassPurchaseFinished:Fire(walker, 801, true)
 now += 0.5
 shop.OnServerEvent:Fire(walker, "AutoBat", true)
 check(walker:GetAttribute("AutoBatOwned") == true and walker:GetAttribute("AutoBatEnabled") == true,
  "buying the pass in the session unlocks it straight away")
 leave(walker)
 leave(owner)
 check(saved.Player_313.RobuxSpent == 25 and saved.Player_313.AutoBatOwned == nil and saved.Player_313.AutoBatEnabled == nil
  and saved.Player_314.AutoBatOwned == nil, "the pass's Robux is counted (its configured price here) and ownership is never saved")
 passFailures[315] = true
 local outage = join(315)
 check(outage:GetAttribute("AutoBatOwned") == false, "a failed ownership lookup grants nothing")
 leave(outage)
 passFailures[315] = nil
 studioMode = true
 workspace:SetAttribute("StudioOwnAutoBat", true)
 local tester = join(316)
 check(tester:GetAttribute("AutoBatOwned") == true, "in Studio, StudioOwnAutoBat owns the pass for playtests")
 leave(tester)
 workspace:SetAttribute("StudioOwnAutoBat", nil)
 studioMode = false
 -- When Auto Bat presses Swing: only when a manual swing would be accepted, after the hit settles.
 local ready = {enabled = true, batting = true, training = false, hitActive = false, exitPending = false, cinematic = false,
  traveling = false, ballState = "Ready", serverNow = 50, nextSwingTime = 49, settledSeconds = Monetization.AutoBat.settleSeconds}
 check(Monetization.ShouldAutoSwing(ready), "a settled, ready batter swings")
 for field, value in {enabled = false, batting = false, training = true, hitActive = true, exitPending = true, cinematic = true,
  traveling = true, ballState = "InFlight", nextSwingTime = 51, settledSeconds = Monetization.AutoBat.settleSeconds - 0.01} do
  local state = table.clone(ready)
  state[field] = value
  check(not Monetization.ShouldAutoSwing(state), "Auto Bat waits while " .. field .. " = " .. tostring(value))
 end
 for _, ballState in {"Reserved", false} do
  local state = table.clone(ready)
  state.ballState = ballState or nil
  check(not Monetization.ShouldAutoSwing(state), "Auto Bat waits until the ball is back on the tee")
 end

 -- The Shop (Schema 11). The Catastrophe Bat: an exclusive Bat, owned and equipped like the rest,
 -- in no Cash purchase series, multiplying Cash only.
 local catBat = Equipment.Get("Bat", "catastrophe_bat")
 check(catBat and catBat.exclusive and catBat.displayName == "Catastrophe Bat" and catBat.cashMultiplier == 2.5
  and catBat.powerGainMultiplier == nil and Equipment.GetById("catastrophe_bat") == catBat, "the Catastrophe Bat is a 2.5x Cash Bat")
 local inSeries = false
 for _, series in Equipment.GetSeries("Bat") do
  for _, item in Equipment.GetSeriesItems("Bat", series.id) do inSeries = inSeries or item.id == "catastrophe_bat" end
 end
 local everySeriesBat = {}
 for _, item in Equipment.GetSeriesItems("Bat") do everySeriesBat[item.id] = true end
 check(not inSeries and Equipment.GetNextPurchase("Bat", everySeriesBat) == nil, "it is never for sale for Cash")
 local pack = shipped.StarterPack
 check(pack.gamePassId == 0 and pack.robuxPrice == 39 and pack.power == 10000 and pack.rebirths == 1
  and pack.juices.power_punch == 1 and pack.juices.cash_splash == nil and pack.batId == "catastrophe_bat",
  "the Starter Pack: 10K Power, 1 Rebirth, 1 Power Punch and the Catastrophe Bat, 39 Robux, no real id yet")
 -- Owned at login: given once, all of it, and saved.
 ownedPasses["520:802"] = true
 saved.Player_520 = {SchemaVersion = 10, Cash = 50, Level = 5, Power = 3, Rebirths = 0, TutorialCompleted = true}
 local packer = join(520)
 local afterPack = Progression.Normalize({Level = 5, Power = 3, Rebirths = 0}, false)
 afterPack.Rebirths, afterPack.LevelCap = 1, Progression.GetLevelCap(1)
 Progression.Advance(afterPack, 10000)
 check(packer:GetAttribute("Rebirths") == 1 and packer:GetAttribute("LevelCap") == Progression.GetLevelCap(1)
  and packer:GetAttribute("Level") == afterPack.Level and packer:GetAttribute("Power") == afterPack.Power and afterPack.Level > 20,
  "+1 Rebirth raises the Level Cap without resetting, then 10K Power levels up through it")
 check(Data.OwnsEquipment(packer, "Bat", "catastrophe_bat") and packer.OwnedBats:GetAttribute("catastrophe_bat") == true
  and owned(packer, PUNCH) == 1 and owned(packer, SPLASH) == nil and expiry(packer, PUNCH) == nil,
  "the Catastrophe Bat and one Power Punch (not started) are given")
 check(packer.leaderstats.Cash.Value == 50 and packer:GetAttribute("StarterPackOwned") == true, "Cash is kept; the Shop shows OWNED")
 check(saved.Player_520.StarterPackGranted == true and saved.Player_520.Rebirths == 1 and saved.Player_520.OwnedBats.catastrophe_bat == true
  and saved.Player_520.OwnedJuices.power_punch == 1 and saved.Player_520.SchemaVersion == 12, "the grant is saved straight away")
 marketplace.PromptGamePassPurchaseFinished:Fire(packer, 802, true)
 marketplace.PromptGamePassPurchaseFinished:Fire(packer, 802, true)
 Data.RefreshStarterPack(packer)
 check(packer:GetAttribute("Rebirths") == 1 and packer:GetAttribute("Power") == afterPack.Power and owned(packer, PUNCH) == 1,
  "repeated purchase events never give it again")
 packer.leaderstats.Cash.Value = 1000
 check(Data.PurchaseNextEquipment(packer, "Bat", packer:GetAttribute("EquipmentPurchaseToken_Bat"))
  and Data.OwnsEquipment(packer, "Bat", "metal_bat"), "the normal Bat series carries on from the Wood Bat")
 check(Data.EquipEquipment(packer, "Bat", "catastrophe_bat") and packer:GetAttribute("EquippedBat") == "catastrophe_bat", "the Bat can be equipped")
 leave(packer)
 packer = join(520)
 check(packer:GetAttribute("Rebirths") == 1 and owned(packer, PUNCH) == 1 and Data.OwnsEquipment(packer, "Bat", "catastrophe_bat")
  and packer:GetAttribute("EquippedBat") == "catastrophe_bat" and packer:GetAttribute("StarterPackOwned") == true,
  "a rejoin keeps the Bat and never gives the pack again")
 leave(packer)
 -- Bought during a session: given at the server's purchase event (Roblox's own result).
 local buyerLater = join(521)
 check(buyerLater:GetAttribute("StarterPackOwned") == false and buyerLater:GetAttribute("Rebirths") == 0, "not owned, not given")
 marketplace.PromptGamePassPurchaseFinished:Fire(buyerLater, 802, false)
 check(buyerLater:GetAttribute("Rebirths") == 0, "a cancelled purchase gives nothing")
 marketplace.PromptGamePassPurchaseFinished:Fire(buyerLater, 802, true)
 check(buyerLater:GetAttribute("Rebirths") == 1 and Data.OwnsEquipment(buyerLater, "Bat", "catastrophe_bat"),
  "an in-game purchase gives it at once")
 -- Its bonus Rebirth is not the tutorial's Rebirth: the tutorial carries on (its 10K Power finished
 -- the Power step) and only the player's own Rebirth at the (now higher) Level Cap completes it.
 check(step(buyerLater) == "EarnCash" and buyerLater:GetAttribute("LevelCap") == 40, "the Starter Pack does not complete the tutorial")
 Data.RecordBattingCash(buyerLater, Tutorial.CashGoal)
 buyerLater.leaderstats.Cash.Value = 10
 local ballToken = buyerLater:GetAttribute("EquipmentPurchaseToken_Ball")
 -- (The pack's 10K Power already reached the new Level Cap, 40, so the Level step is done too.)
 check(Data.PurchaseNextEquipment(buyerLater, "Ball", ballToken) and Data.EquipEquipment(buyerLater, "Ball", Tutorial.BallId)
  and buyerLater:GetAttribute("Level") == 40 and step(buyerLater) == "Rebirth",
  "the Ball step follows as usual, then the Level Cap (already reached) moves on to the Rebirth step")
 check(Data.TryRebirth(buyerLater) and step(buyerLater) == Tutorial.Complete and buyerLater:GetAttribute("Rebirths") == 2,
  "the player's own Rebirth completes the tutorial")
 leave(buyerLater)
 check(saved.Player_521.RobuxSpent == 39 and saved.Player_521.StarterPackGranted == true, "its Robux is counted once")
 saved.Player_522 = {SchemaVersion = 11, Cash = 1, StarterPackGranted = "yes"}
 local badFlag = join(522)
 check(not Data.IsReady(badFlag) and saved.Player_522.StarterPackGranted == "yes", "a malformed StarterPackGranted fails closed")
 -- Cash packs: Cash worth so many normal hits for the player now, from server state only.
 local tiers = {}
 for _, product in shipped.CashProducts do table.insert(tiers, table.concat({product.id, product.robuxPrice, product.hits}, ":")) end
 check(table.concat(tiers, ",") == "CashTiny:25:15,CashSmall:59:50,CashMedium:115:125,CashLarge:229:300",
  "four Cash packs, 25 / 59 / 115 / 229 Robux, worth 15 / 50 / 125 / 300 hits")
 local distance30 = Progression.GetExpectedHitDistance(30)
 local world1 = Worlds.Get("world_1")
 local perHit = Progression.GetHitCash(distance30, world1.cashMultiplier, Field.GetRewardSection(distance30, world1).rewardMultiplier, 1)
 check(math.abs(Monetization.GetCashPerHit(30, "world_1", "wood_bat") - perHit) < 1e-9
  and Monetization.GetCashPerHit(30, "world_2", "wood_bat") > perHit * 5 and Monetization.GetCashPerHit(30, "world_1", "catastrophe_bat")
  == Progression.GetHitCash(distance30, world1.cashMultiplier, Field.GetRewardSection(distance30, world1).rewardMultiplier, 2.5),
  "a normal hit's Cash follows the Level, World and Bat")
 check(Progression.GetExpectedHitDistance(1) == 81 and math.abs(Progression.GetExpectedHitDistance(140) - 3906) < 1e-6
  and Progression.GetExpectedHitDistance(370) == 7000 and Progression.GetExpectedHitDistance(1000) == 8000 and Progression.GetExpectedHitDistance(70) > Progression.GetExpectedHitDistance(69),
  "expected hit distances follow the measured hits")
 saved.Player_523 = {SchemaVersion = 11, Cash = 100, Level = 30, Power = 0, Rebirths = 1, TutorialCompleted = true}
 local cashBuyer = join(523)
 cashBuyer:SetAttribute("CurrentWorldId", "world_1")
 local tiny = Monetization.GetCashPackReward(Monetization.CashProducts[1], 30, "world_1", "wood_bat")
 check(tiny == math.floor(15 * perHit + 0.5) and marketplace.ProcessReceipt({PlayerId = 523, PurchaseId = "cash-1", ProductId = 711,
  CurrencySpent = 25, CurrencyType = robux}) == decisions.PurchaseGranted and cashBuyer.leaderstats.Cash.Value == 100 + tiny,
  "the Tiny pack adds 15 normal hits of Cash")
 check(shop.replies[cashBuyer][1] == "Granted" and shop.replies[cashBuyer][3].cash == tiny, "the client is told the Cash added")
 check(marketplace.ProcessReceipt({PlayerId = 523, PurchaseId = "cash-1", ProductId = 711, CurrencySpent = 25, CurrencyType = robux})
  == decisions.PurchaseGranted and cashBuyer.leaderstats.Cash.Value == 100 + tiny, "a repeated receipt adds nothing")
 cashBuyer:SetAttribute("CurrentWorldId", "world_2")
 local medium = Monetization.GetCashPackReward(Monetization.CashProducts[3], 30, "world_2", "wood_bat")
 check(marketplace.ProcessReceipt({PlayerId = 523, PurchaseId = "cash-2", ProductId = 713, CurrencySpent = 99999, CurrencyType = robux})
  == decisions.PurchaseGranted and cashBuyer.leaderstats.Cash.Value == 100 + tiny + medium and medium > tiny,
  "the Medium pack pays for the World the player is in; what the receipt says it cost changes nothing")
 leave(cashBuyer)
 check(saved.Player_523.Cash == 100 + tiny + medium and saved.Player_523.RobuxSpent == 25 + 99999, "pack Cash is saved")
 -- Each purchase pays what was fixed when it began: Buy asks the server, which quotes the pack and
 -- then prompts; changing Level, World or Bat afterwards, retries and rejoins change nothing.
 saved.Player_525 = {SchemaVersion = 11, Cash = 100, Level = 30, Power = 0, Rebirths = 1, TutorialCompleted = true}
 local quoted = join(525)
 quoted:SetAttribute("CurrentWorldId", "world_1")
 local promptsBefore = #marketplace.prompts
 shop.OnServerEvent:Fire(quoted, "BuyCash", "CashTiny")
 local quote = Monetization.GetCashPackReward(Monetization.CashProducts[1], 30, "world_1", "wood_bat")
 check(#marketplace.prompts == promptsBefore + 1 and marketplace.prompts[#marketplace.prompts].product == 711
  and marketplace.prompts[#marketplace.prompts].player == quoted, "Buy quotes the pack and opens the right prompt")
 shop.OnServerEvent:Fire(quoted, "BuyCash", "CashTiny")
 shop.OnServerEvent:Fire(quoted, "BuyCash", "FreeCash")
 check(#marketplace.prompts == promptsBefore + 1, "repeated or unknown Buy requests open no extra prompts")
 Data.GrantPower(quoted, 100000, "ActiveTraining")
 quoted:SetAttribute("CurrentWorldId", "world_2")
 quoted.leaderstats.Cash.Value = 1000
 Data.PurchaseNextEquipment(quoted, "Bat", quoted:GetAttribute("EquipmentPurchaseToken_Bat"))
 local cashNow = quoted.leaderstats.Cash.Value
 check(quoted:GetAttribute("Level") > 30 and quoted:GetAttribute("EquippedBat") == "metal_bat"
  and Monetization.GetCashPackReward(Monetization.CashProducts[1], quoted:GetAttribute("Level"), "world_2", "metal_bat") > quote * 10,
  "(the player's Level, World and Bat have all changed since)")
 local tinyReceipt = {PlayerId = 525, PurchaseId = "quote-1", ProductId = 711, CurrencySpent = 25, CurrencyType = robux}
 check(marketplace.ProcessReceipt(tinyReceipt) == decisions.PurchaseGranted and quoted.leaderstats.Cash.Value == cashNow + quote,
  "the receipt pays the quote from when the purchase began")
 check(marketplace.ProcessReceipt(tinyReceipt) == decisions.PurchaseGranted and quoted.leaderstats.Cash.Value == cashNow + quote,
  "a retried receipt pays nothing more")
 leave(quoted)
 check(saved.Player_525.CashPackQuotes.CashTiny == quote, "the quote is saved with the player")
 quoted = join(525)
 quoted:SetAttribute("CurrentWorldId", "world_2")
 local cashBefore = quoted.leaderstats.Cash.Value
 check(marketplace.ProcessReceipt({PlayerId = 525, PurchaseId = "quote-2", ProductId = 711, CurrencySpent = 25, CurrencyType = robux})
  == decisions.PurchaseGranted and quoted.leaderstats.Cash.Value == cashBefore + quote, "a receipt delayed past a rejoin pays the same quote")
 local small = Monetization.CashProducts[2]
 local smallNow = Monetization.GetCashPackReward(small, quoted:GetAttribute("Level"), "world_2", quoted:GetAttribute("EquippedBat"))
 check(marketplace.ProcessReceipt({PlayerId = 525, PurchaseId = "quote-3", ProductId = 712, CurrencySpent = 59, CurrencyType = robux})
  == decisions.PurchaseGranted and quoted.leaderstats.Cash.Value == cashBefore + quote + smallNow,
  "each pack has its own quote (one never quoted pays its amount now)")
 leave(quoted)
 saved.Player_526 = {SchemaVersion = 11, Cash = 1, CashPackQuotes = {CashTiny = -5, FreeCash = 10, CashLarge = 77}}
 local cleanQuotes = join(526)
 leave(cleanQuotes)
 check(saved.Player_526.CashPackQuotes.CashLarge == 77 and saved.Player_526.CashPackQuotes.CashTiny == nil
  and saved.Player_526.CashPackQuotes.FreeCash == nil, "invalid saved quotes are dropped")
 saved.Player_527 = {SchemaVersion = 11, Cash = 1, CashPackQuotes = "lots"}
 local badQuotes = join(527)
 check(not Data.IsReady(badQuotes), "a malformed CashPackQuotes fails closed")

 -- Purchased multipliers (Schema 12): permanent Power and Cash tiers, each its own developer
 -- product, bought in order; the server prompts only the next tier and grants it from the receipt.
 local function ladderText(kind)
  local parts = {}
  for _, tier in shipped.Multipliers[kind] do
   table.insert(parts, tier.multiplier .. ":" .. tier.robuxPrice .. ":" .. tier.developerProductId)
  end
  return table.concat(parts, ",")
 end
 check(ladderText("Power") == "2:129:0,2.5:169:0,3:219:0,3.5:279:0,4:359:0"
  and ladderText("Cash") == "2:129:0,2.5:159:0,3:199:0,3.5:249:0,4:309:0,4.5:389:0,5:489:0",
  "Power 2x-4x in 5 tiers and Cash 2x-5x in 7 (+0.5x a tier), at their prices, no real ids yet")
 check(Monetization.GetMultiplier("Power", 0) == 1 and Monetization.GetMultiplier("Power", 1) == 2
  and Monetization.GetMultiplier("Cash", 7) == 5 and Monetization.GetMultiplier("Cash", 99) == 5
  and Monetization.GetMultiplier("Luck", 3) == 1 and Monetization.GetNextMultiplierTier("Power", 5) == nil
  and select(2, Monetization.GetNextMultiplierTier("Cash", 0)).multiplier == 2 and shipped.GetMultiplierProduct(0) == nil,
  "the tier count picks the multiplier (1x with none); the top tier has no next one; id 0 matches nothing")
 local foundKind, foundTier = Monetization.GetMultiplierProduct(763)
 check(foundKind == "Power" and foundTier == 3 and select(2, Monetization.GetMultiplierProduct(777)) == 7,
  "a real developer product id finds its multiplier tier")
 saved.Player_530 = {SchemaVersion = 11, Cash = 100, Level = 30, Power = 0, Rebirths = 1, TutorialCompleted = true}
 local tierBuyer = join(530)
 check(tierBuyer:GetAttribute("PowerMultiplierTier") == 0 and tierBuyer:GetAttribute("CashMultiplierTier") == 0
  and Data.GetPurchasedMultiplier(tierBuyer, "Power") == 1, "an older save starts with no multiplier tiers")
 local function tierReceipt(id, productId)
  local kind, number = Monetization.GetMultiplierProduct(productId)
  return {PlayerId = 530, PurchaseId = id, ProductId = productId, CurrencySpent = Monetization.Multipliers[kind][number].robuxPrice,
   CurrencyType = robux}
 end
 now += 1
 local promptsAtStart = #marketplace.prompts
 shop.OnServerEvent:Fire(tierBuyer, "BuyMultiplier", "Power")
 check(#marketplace.prompts == promptsAtStart + 1 and marketplace.prompts[#marketplace.prompts].product == 761
  and marketplace.prompts[#marketplace.prompts].player == tierBuyer, "Buy prompts the first Power tier")
 now += 1
 shop.OnServerEvent:Fire(tierBuyer, "BuyMultiplier", "Power")
 shop.OnServerEvent:Fire(tierBuyer, "BuyMultiplier", "Luck")
 check(#marketplace.prompts == promptsAtStart + 1, "no second prompt of a kind while one is open; unknown kinds open nothing")
 marketplace.PromptProductPurchaseFinished:Fire(530, 761, false)
 now += 1
 shop.OnServerEvent:Fire(tierBuyer, "BuyMultiplier", "Power")
 check(#marketplace.prompts == promptsAtStart + 2 and marketplace.prompts[#marketplace.prompts].product == 761,
  "a cancelled prompt can be opened again")
 local _, unboosted = Data.GrantPower(tierBuyer, 10, "ActiveTraining")
 check(marketplace.ProcessReceipt(tierReceipt("tier-1", 761)) == decisions.PurchaseGranted
  and tierBuyer:GetAttribute("PowerMultiplierTier") == 1 and Data.GetPurchasedMultiplier(tierBuyer, "Power") == 2
  and shop.replies[tierBuyer][1] == "MultiplierGranted" and shop.replies[tierBuyer][2] == "Power" and shop.replies[tierBuyer][3] == 1,
  "the receipt grants tier 1 and tells the client")
 check(saved.Player_530.PowerMultiplierTier == 1 and saved.Player_530.RobuxSpent == 129, "a tier is saved straight away with its Robux")
 local _, boosted = Data.GrantPower(tierBuyer, 10, "ActiveTraining")
 check(unboosted.powerGranted == 20 and boosted.powerGranted == 40, "the Power multiplier applies to Training Power (10 x 2 x 2)")
 check(marketplace.ProcessReceipt(tierReceipt("tier-1", 761)) == decisions.PurchaseGranted
  and tierBuyer:GetAttribute("PowerMultiplierTier") == 1 and saved.Player_530.RobuxSpent == 129, "a repeated receipt grants nothing more")
 now += 1
 shop.OnServerEvent:Fire(tierBuyer, "BuyMultiplier", "Power")
 check(marketplace.prompts[#marketplace.prompts].product == 762, "after a tier, Buy prompts the next one")
 -- A late or repeated purchase still adds a tier, so none is lost: two tier-2 receipts give tiers 2 and 3.
 marketplace.ProcessReceipt(tierReceipt("tier-2a", 762))
 check(marketplace.ProcessReceipt(tierReceipt("tier-2b", 762)) == decisions.PurchaseGranted
  and tierBuyer:GetAttribute("PowerMultiplierTier") == 3, "a second purchase of the same tier still adds one")
 for number = 4, 5 do marketplace.ProcessReceipt(tierReceipt("tier-" .. number, 760 + number)) end
 check(tierBuyer:GetAttribute("PowerMultiplierTier") == 5 and Data.GetPurchasedMultiplier(tierBuyer, "Power") == 4
  and Data.GetNextMultiplierTier(tierBuyer, "Power") == nil, "five tiers reach the top, 4x")
 now += 1
 local promptsAtTop = #marketplace.prompts
 shop.OnServerEvent:Fire(tierBuyer, "BuyMultiplier", "Power")
 check(#marketplace.prompts == promptsAtTop, "at the top tier no prompt opens")
 -- A hit's snapshot is used instead of the live multiplier; without one the live one counts.
 check(select(2, Data.GrantPower(tierBuyer, 10, "CompletedHit", nil, 1, 1)).powerGranted == 20
  and select(2, Data.GrantPower(tierBuyer, 10, "CompletedHit", nil, 2, 1.5)).powerGranted == 60
  and select(2, Data.GrantPower(tierBuyer, 10, "CompletedHit")).powerGranted == 80, "a hit uses its snapshot (with juices)")
 local exact = Data.GetProgression(tierBuyer)
 Progression.Advance(exact, 10000)
 check(marketplace.ProcessReceipt(receipt(530, "power-530", 1)) == decisions.PurchaseGranted
  and tierBuyer:GetAttribute("Level") == exact.Level and tierBuyer:GetAttribute("Power") == exact.Power,
  "Power products stay exact: the purchased multiplier never applies to them")
 check(Data.ClaimMultiplier(failed, {PlayerId = 6, PurchaseId = "tier-x", ProductId = 771, CurrencySpent = 1}, "Cash", 1) == decisions.NotProcessedYet
  and Data.ClaimMultiplier(tierBuyer, tierReceipt("tier-y", 771), "Luck", 1) == decisions.NotProcessedYet
  and Data.ClaimMultiplier(tierBuyer, tierReceipt("tier-z", 771), "Cash", 0) == decisions.NotProcessedYet
  and tierBuyer:GetAttribute("CashMultiplierTier") == 0, "a failed load, an unknown kind or tier grants nothing")
 check(marketplace.ProcessReceipt(tierReceipt("cash-tier-1", 771)) == decisions.PurchaseGranted
  and tierBuyer:GetAttribute("CashMultiplierTier") == 1 and tierBuyer:GetAttribute("PowerMultiplierTier") == 5,
  "the Cash ladder is separate")
 -- A Cash pack's "normal hit" includes the Cash multiplier.
 tierBuyer:SetAttribute("CurrentWorldId", "world_1")
 now += 1
 shop.OnServerEvent:Fire(tierBuyer, "BuyCash", "CashTiny")
 local packLevel = Data.GetProgression(tierBuyer).Level
 local tieredQuote = Monetization.GetCashPackReward(Monetization.CashProducts[1], packLevel, "world_1", "wood_bat", 2)
 leave(tierBuyer)
 check(saved.Player_530.CashPackQuotes.CashTiny == tieredQuote
  and tieredQuote > Monetization.GetCashPackReward(Monetization.CashProducts[1], packLevel, "world_1", "wood_bat"),
  "a Cash pack quote counts the Cash multiplier")
 check(saved.Player_530.SchemaVersion == 12 and saved.Player_530.PowerMultiplierTier == 5 and saved.Player_530.CashMultiplierTier == 1,
  "both tier counts are saved")
 tierBuyer = join(530)
 Data.GrantPower(tierBuyer, 1000000, "Test")
 check(Data.TryRebirth(tierBuyer) and Data.GetPurchasedMultiplier(tierBuyer, "Power") == 4
  and Data.GetPurchasedMultiplier(tierBuyer, "Cash") == 2, "tiers survive a rejoin and a Rebirth")
 leave(tierBuyer)
 saved.Player_531 = {SchemaVersion = 12, Cash = 1, PowerMultiplierTier = 1.5}
 check(not Data.IsReady(join(531)) and saved.Player_531.PowerMultiplierTier == 1.5, "a malformed tier count fails closed")
 saved.Player_532 = {SchemaVersion = 12, Cash = 1, CashMultiplierTier = 99}
 local clamped = join(532)
 check(clamped:GetAttribute("CashMultiplierTier") == 7 and Data.GetPurchasedMultiplier(clamped, "Cash") == 5,
  "a count past the ladder keeps the top tier")
 leave(clamped)
 -- Offline Training gets the Power multiplier (a minute at Basic Training: 37 x 2 = 74), and
 -- the Welcome Back 3x keeps it: 3 x 74 in all.
 saved.Player_533 = {SchemaVersion = 12, Cash = 0, Level = 1, Power = 0, Rebirths = 0, TutorialCompleted = true,
  PowerMultiplierTier = 1, LastLogoutTime = math.floor(now) - 60}
 local tierNapper = join(533)
 check(tierNapper:GetAttribute("OfflinePowerEarned") == 74, "offline Training gets the Power multiplier")
 check(Data.ClaimOfflineTriple(tierNapper, {PlayerId = 533, PurchaseId = "triple-533", ProductId = 555, CurrencySpent = 9})
  == decisions.PurchaseGranted and tierNapper:GetAttribute("OfflineTriplePower") == 222, "the 3x keeps the multiplier")
 leave(tierNapper)

 -- Gifts: every Shop item has a gift developer product at the same price; the server saves who
 -- receives it before the buyer's prompt, and the receipt queues it on the recipient's record.
 local giftPrices = {}
 for _, gift in shipped.GiftProducts do table.insert(giftPrices, gift.id .. ":" .. gift.robuxPrice .. ":" .. gift.developerProductId) end
 check(table.concat(giftPrices, ",") == "GiftStarterPack:39:0,GiftCashTiny:25:0,GiftCashSmall:59:0,GiftCashMedium:115:0,GiftCashLarge:229:0,"
  .. "GiftBoostBundle:95:0,GiftPowerPunch:39:0,GiftCashSplash:39:0,GiftPremiumTraining:500:0,GiftDragonsLair:1000:0",
  "ten gift products, each at its item's own price, no real ids yet")
 check(Monetization.GetGroundGift(Training.Get("cosmic_rift")).id == "GiftPremiumTraining"
  and Monetization.GetGroundGift(Training.Get("time_machine_lab")).id == "GiftPremiumTraining"
  and Monetization.GetGroundGift(Training.Get("quantum_lab")).id == "GiftPremiumTraining"
  and Monetization.GetGroundGift(Training.Get("dragons_lair")).id == "GiftDragonsLair"
  and Monetization.GetGroundGift(Training.Get("snow_globe")).id == "GiftPremiumTraining",
  "the four World premium grounds share one gift (their shared pass); Dragon's Lair has its own")
 local function giftIndex(id) for index, gift in Monetization.GiftProducts do if gift.id == id then return index end end end
 local function giftReceipt(buyerId, purchaseId, id)
  return {PlayerId = buyerId, PurchaseId = purchaseId, ProductId = 730 + giftIndex(id),
   CurrencySpent = Monetization.GetGiftById(id).robuxPrice, CurrencyType = robux}
 end
 local function ask(buyer, id, recipientId)
  now += 1.1 -- (past the request cooldown)
  shop.replies[buyer] = nil
  local before = #marketplace.prompts
  shop.OnServerEvent:Fire(buyer, "Gift", id, recipientId)
  return #marketplace.prompts == before + 1 and marketplace.prompts[#marketplace.prompts].player == buyer
   and marketplace.prompts[#marketplace.prompts].product == 730 + giftIndex(id)
 end
 saved.Player_540 = {SchemaVersion = 11, Cash = 1000, Level = 10, Power = 0, Rebirths = 0, TutorialCompleted = true}
 saved.Player_541 = {SchemaVersion = 11, Cash = 50, Level = 30, Power = 0, Rebirths = 1, TutorialCompleted = true}
 local giver, friend = join(540), join(541)
 friend:SetAttribute("CurrentWorldId", "world_1")
 check(not ask(giver, "GiftPowerPunch", 540) and shop.replies[giver][1] == "GiftRefused", "no gifts to yourself")
 check(not ask(giver, "GiftPowerPunch", 9999) and shop.replies[giver][1] == "GiftRefused", "no gifts to someone not in the server")
 check(not ask(giver, "FreeStuff", 541) and not ask(giver, nil, 541), "unknown gifts open nothing")
 check(ask(giver, "GiftPowerPunch", 541) and saved.Player_540.PendingGifts.GiftPowerPunch.recipient == 541,
  "a gift saves its recipient on the buyer's record, then opens the buyer's prompt")
 check(Data.ClaimGift(giver, giftReceipt(540, "gift-1", "GiftPowerPunch"), Monetization.GetGiftById("GiftPowerPunch"))
  == decisions.PurchaseGranted and owned(friend, PUNCH) == 1 and expiry(friend, PUNCH) == nil and owned(giver, PUNCH) == nil,
  "the recipient gets one Power Punch (not started); the buyer gets nothing")
 check(table.find(saved.Player_541.ReceivedGifts, "gift-1") and saved.Player_541.OwnedJuices.power_punch == 1
  and saved.Player_540.PendingGifts.GiftPowerPunch == nil and saved.Player_540.RobuxSpent == 39,
  "the gift is saved with the recipient; the buyer's receipt and Robux are recorded")
 check(marketplace.ProcessReceipt(giftReceipt(540, "gift-1", "GiftPowerPunch")) == decisions.PurchaseGranted
  and owned(friend, PUNCH) == 1, "a repeated gift receipt gives nothing more")
 check(marketplace.ProcessReceipt(giftReceipt(540, "gift-2", "GiftCashSplash")) == decisions.NotProcessedYet
  and owned(friend, SPLASH) == nil, "a gift receipt with no saved recipient is left for Roblox to retry")
 check(Data.ClaimGift(failed, giftReceipt(6, "gift-3", "GiftPowerPunch"), Monetization.GetGiftById("GiftPowerPunch"))
  == decisions.NotProcessedYet, "a failed load is never granted")
 -- A cancelled prompt drops the intent; a bought one blocks a second gift until delivered.
 check(ask(giver, "GiftCashSplash", 541), "Cash Splash gift asked")
 marketplace.PromptProductPurchaseFinished:Fire(540, 730 + giftIndex("GiftCashSplash"), false)
 check(marketplace.ProcessReceipt(giftReceipt(540, "gift-x", "GiftCashSplash")) == decisions.NotProcessedYet,
  "a cancelled prompt drops the intent")
 check(ask(giver, "GiftCashSplash", 541), "after a cancel the gift can be asked again")
 marketplace.PromptProductPurchaseFinished:Fire(540, 730 + giftIndex("GiftCashSplash"), true)
 check(not ask(giver, "GiftCashSplash", 541) and shop.replies[giver][1] == "GiftRefused", "a bought gift waits for its receipt")
 check(marketplace.ProcessReceipt(giftReceipt(540, "gift-4", "GiftCashSplash")) == decisions.PurchaseGranted
  and owned(friend, SPLASH) == 1, "the receipt delivers it")
 -- Boost Bundle: two of each.
 check(ask(giver, "GiftBoostBundle", 541) and marketplace.ProcessReceipt(giftReceipt(540, "gift-5", "GiftBoostBundle"))
  == decisions.PurchaseGranted and owned(friend, PUNCH) == 3 and owned(friend, SPLASH) == 3, "the Boost Bundle gives two of each")
 -- Cash packs pay what the RECIPIENT's progression was worth when the gift began.
 local giftQuote = Monetization.GetCashPackReward(Monetization.CashProducts[1], 30, "world_1", "wood_bat")
 check(ask(giver, "GiftCashTiny", 541) and saved.Player_540.PendingGifts.GiftCashTiny.amount == giftQuote, "the Tiny gift quotes the recipient")
 Data.GrantPower(friend, 100000, "ActiveTraining")
 friend:SetAttribute("CurrentWorldId", "world_2")
 friend.leaderstats.Cash.Value = 1000
 Data.PurchaseNextEquipment(friend, "Bat", friend:GetAttribute("EquipmentPurchaseToken_Bat"))
 local friendCash = friend.leaderstats.Cash.Value
 check(friend:GetAttribute("Level") > 30 and friend:GetAttribute("EquippedBat") == "metal_bat"
  and marketplace.ProcessReceipt(giftReceipt(540, "gift-6", "GiftCashTiny")) == decisions.PurchaseGranted
  and friend.leaderstats.Cash.Value == friendCash + giftQuote and giver.leaderstats.Cash.Value == 1000,
  "later Level, World and Bat changes don't change it; only the recipient is paid")
 -- Training Grounds: the shared premium entitlement and Dragon's Lair, like their passes.
 friend:SetAttribute("WorldUnlocked_world_2", true)
 check(friend:GetAttribute("TrainingPass_cosmic_rift") == false and ask(giver, "GiftPremiumTraining", 541)
  and marketplace.ProcessReceipt(giftReceipt(540, "gift-7", "GiftPremiumTraining")) == decisions.PurchaseGranted,
  "premium Training gift delivered")
 check(friend:GetAttribute("TrainingPass_cosmic_rift") == true and Data.CanUseTrainingGround(friend, "cosmic_rift")
  and Data.CanUseTrainingGround(friend, "time_machine_lab") and not Data.CanUseTrainingGround(friend, "dragons_lair")
  and Data.OwnsTrainingPass(friend, "cosmic_rift"), "it opens every ground of the shared pass, exactly like owning the pass")
 check(not ask(giver, "GiftPremiumTraining", 541) and shop.replies[giver][2] == "THIS PLAYER ALREADY OWNS THE PREMIUM TRAINING GROUND",
  "an owner can't be gifted it again")
 check(ask(giver, "GiftDragonsLair", 541) and marketplace.ProcessReceipt(giftReceipt(540, "gift-8", "GiftDragonsLair"))
  == decisions.PurchaseGranted and Data.CanUseTrainingGround(friend, "dragons_lair") and friend:GetAttribute("TrainingPass_dragons_lair") == true,
  "the Dragon's Lair gift opens Dragon's Lair")
 leave(friend)
 check(saved.Player_541.GiftedEntitlements.premium_training == true and saved.Player_541.GiftedEntitlements.dragons_lair == true
  and saved.Player_541.TrainingPasses == nil, "gifted entitlements are saved (Roblox pass ownership never is)")
 friend = join(541)
 check(Data.CanUseTrainingGround(friend, "dragons_lair") and friend:GetAttribute("TrainingPass_cosmic_rift") == true
  and owned(friend, PUNCH) == 3, "a rejoin keeps the gifted grounds and gifts")
 -- A Roblox pass owner can't be gifted that ground either.
 ownedPasses["542:222"] = true
 local passOwner = join(542)
 check(not ask(giver, "GiftDragonsLair", 542), "a Dragon's Lair pass owner can't be gifted it")
 leave(passOwner)
 -- Starter Pack: the same grant as the pass; its bonus Rebirth leaves the tutorial running.
 local newcomer = join(543)
 check(step(newcomer) == "EarnPower" and ask(giver, "GiftStarterPack", 543)
  and marketplace.ProcessReceipt(giftReceipt(540, "gift-9", "GiftStarterPack")) == decisions.PurchaseGranted,
  "a Starter Pack gift delivered")
 check(newcomer:GetAttribute("Rebirths") == 1 and Data.OwnsEquipment(newcomer, "Bat", "catastrophe_bat") and owned(newcomer, PUNCH) == 1
  and newcomer:GetAttribute("StarterPackOwned") == true and step(newcomer) == "EarnCash" and saved.Player_543.StarterPackGranted == true,
  "the whole pack arrives once, and the tutorial carries on")
 check(not ask(giver, "GiftStarterPack", 543) and shop.replies[giver][2] == "THIS PLAYER ALREADY OWNS THE STARTER PACK",
  "it can't be gifted twice")
 leave(newcomer)
 -- The recipient leaves before the receipt: the gift waits in their saved queue and applies
 -- once at their next login.
 local leaver = join(544)
 check(ask(giver, "GiftPowerPunch", 544), "gift asked")
 leave(leaver)
 check(marketplace.ProcessReceipt(giftReceipt(540, "gift-10", "GiftPowerPunch")) == decisions.PurchaseGranted
  and saved.Player_544.GiftInbox[1].id == "gift-10" and saved.Player_544.GiftInbox[1].from == 540,
  "a recipient who left gets it queued on their record (the buyer's Robux are safe)")
 check(marketplace.ProcessReceipt(giftReceipt(540, "gift-10", "GiftPowerPunch")) == decisions.PurchaseGranted
  and #saved.Player_544.GiftInbox == 1, "a retry queues nothing more")
 leaver = join(544)
 check(owned(leaver, PUNCH) == 1 and #saved.Player_544.GiftInbox == 0 and table.find(saved.Player_544.ReceivedGifts, "gift-10"),
  "it applies at their next login and leaves the queue")
 leave(leaver)
 leaver = join(544)
 check(owned(leaver, PUNCH) == 1, "and never applies again")
 leave(leaver)
 leave(giver)
 saved.Player_545 = {SchemaVersion = 11, Cash = 1, GiftInbox = {{id = "x", gift = "FreeStuff", from = 1}, {id = "y", gift = "GiftPowerPunch", from = 0}},
  GiftedEntitlements = {premium_training = true, fake_ground = true}, ReceivedGifts = {"a", 5}}
 local cleanGifts = join(545)
 check(Data.IsReady(cleanGifts) and owned(cleanGifts, PUNCH) == nil and Data.CanUseTrainingGround(cleanGifts, "cosmic_rift"),
  "malformed gift entries are dropped; valid entitlements stay")
 leave(cleanGifts)
 saved.Player_546 = {SchemaVersion = 11, Cash = 1, GiftInbox = "lots"}
 check(not Data.IsReady(join(546)), "a malformed gift field fails closed")
 -- Juice products add juices to the Inventory (never started).
 local juiceProducts = {}
 for _, product in shipped.JuiceProducts do
  table.insert(juiceProducts, table.concat({product.id, product.robuxPrice, product.juices.power_punch or 0, product.juices.cash_splash or 0}, ":"))
 end
 check(table.concat(juiceProducts, ",") == "BoostBundle:95:2:2,PowerPunch:39:1:0,CashSplash:39:0:1",
  "the Boost Bundle (2 + 2, 95 Robux) and one of each juice (39 Robux)")
 local drinker = join(524)
 check(marketplace.ProcessReceipt({PlayerId = 524, PurchaseId = "juice-1", ProductId = 722, CurrencySpent = 39, CurrencyType = robux})
  == decisions.PurchaseGranted and owned(drinker, PUNCH) == 1 and owned(drinker, SPLASH) == nil and expiry(drinker, PUNCH) == nil,
  "Power Punch adds exactly one, not started")
 check(marketplace.ProcessReceipt({PlayerId = 524, PurchaseId = "juice-2", ProductId = 723, CurrencySpent = 39, CurrencyType = robux})
  == decisions.PurchaseGranted and owned(drinker, SPLASH) == 1 and expiry(drinker, SPLASH) == nil, "Cash Splash adds exactly one")
 check(marketplace.ProcessReceipt({PlayerId = 524, PurchaseId = "juice-3", ProductId = 721, CurrencySpent = 95, CurrencyType = robux})
  == decisions.PurchaseGranted and owned(drinker, PUNCH) == 3 and owned(drinker, SPLASH) == 3, "the Boost Bundle adds two of each")
 check(marketplace.ProcessReceipt({PlayerId = 524, PurchaseId = "juice-3", ProductId = 721, CurrencySpent = 95, CurrencyType = robux})
  == decisions.PurchaseGranted and owned(drinker, PUNCH) == 3 and owned(drinker, SPLASH) == 3, "a repeated receipt adds no juice")
 leave(drinker)
 check(saved.Player_524.OwnedJuices.power_punch == 3 and saved.Player_524.OwnedJuices.cash_splash == 3, "bought juices are saved")
 -- Training Grounds: Dragon's Lair always, plus the premium ground in the player's World, each
 -- through its existing pass (one shared pass for the four World grounds).
 for worldId, expected in {world_1 = "cosmic_rift", world_2 = "time_machine_lab", world_3 = "quantum_lab", world_4 = "snow_globe"} do
  local listed = Monetization.GetShopGrounds(worldId)
  check(#listed == 2 and listed[1].id == expected and listed[2].id == "dragons_lair", worldId .. " lists " .. expected .. " and Dragon's Lair")
  check(Training.GetPassGround(listed[1]).id == "cosmic_rift" and Training.GetPassGround(listed[2]).id == "dragons_lair",
   worldId .. "'s Shop grounds use the existing passes")
 end

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
