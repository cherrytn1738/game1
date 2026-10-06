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
 local saved, calls, simulatedFailures = {}, {}, {}
 local store = {}
 function store:UpdateAsync(key, transform)
  calls[key] = (calls[key] or 0) + 1
  if simulatedFailures[key] then error("simulated DataStore outage") end
  local value = transform(copy(saved[key]))
  if value == nil then return nil end
  saved[key] = copy(value)
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
 local modules = {EquipmentConfig = Equipment, WorldConfig = Worlds}
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
 check(saved.Player_1.SchemaVersion == 3 and saved.Player_1.Session == nil, "version 3 save and lease release")
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
 return {passed = passed, message = "Catalog, migration, ownership, remote validation, isolation, replay protection, save/rejoin, failure safety"}
end
