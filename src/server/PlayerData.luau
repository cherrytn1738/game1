-- Server-only persistence. Gameplay continues to use leaderstats.Cash and Equipped* attributes.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Equipment = require(game:GetService("ReplicatedStorage"):WaitForChild("EquipmentConfig"))

local Worlds = require(game.ReplicatedStorage:WaitForChild("WorldConfig"))

local STORE_NAME = "PlayerProgression"
local SCHEMA_VERSION = 3
local AUTOSAVE_SECONDS = 60
local LEASE_SECONDS = 180
local LEASE_SAFETY_SECONDS = 15
local MAX_ATTEMPTS = 3
local REQUEST_SECONDS = 20
local SHUTDOWN_SECONDS = 25
local MAX_CASH = 9000000000000 -- Safely below the integer precision limit.
local CATEGORIES = Equipment.CategoryOrder

local PlayerData = {}
local sessions = {}
local started, shuttingDown = false, false

local function validCash(value)
 return typeof(value) == "number" and value == value
  and value >= 0 and value <= MAX_CASH and value % 1 == 0
end

-- Only a missing record means NEW. A malformed record/version fails closed.
local function validate(record)
 if record ~= nil and typeof(record) ~= "table" then return nil, "invalid record" end
 record = record or {}
 local version = record.SchemaVersion
 if version ~= nil and (typeof(version) ~= "number" or version % 1 ~= 0
  or version < 1 or version > SCHEMA_VERSION) then
  return nil, "unsupported schema version"
 end
 local data = table.clone(record)
 local repairs = {}
 data.SchemaVersion = SCHEMA_VERSION
 if data.Cash == nil then
  data.Cash = 0
 elseif not validCash(data.Cash) then
  -- Do not silently discard an existing balance that cannot be interpreted safely.
  return nil, "invalid Cash"
 end
 for _, category in CATEGORIES do
  local field = "Equipped" .. category
  local ownedField = Equipment.Categories[category].ownedField
  local previousId = data[field]
  data[ownedField], data[field] = Equipment.NormalizeOwnership(
   category, data[ownedField], previousId, (version or 1) < 3)
  if previousId ~= nil and previousId ~= data[field] then
   table.insert(repairs, field .. "=" .. tostring(previousId))
  end
 end
 -- Version 1 records have no world fields. Preserve their Cash/equipment.
 for _, field in {"UnlockedWorlds", "CompletedWorlds"} do
  local saved = data[field]
  if saved ~= nil and typeof(saved) ~= "table" then return nil, "invalid " .. field end
  data[field] = {}
  for id, owned in saved or {} do
   if Worlds.Get(id) and owned == true then data[field][id] = true end
  end
 end
 data.UnlockedWorlds[Worlds.StartingWorldId] = true
 -- A recorded completion always implies ownership of that world and its next one.
 for _, world in Worlds.Worlds do
  if data.CompletedWorlds[world.id] then
   data.UnlockedWorlds[world.id] = true
   if world.nextWorldId then data.UnlockedWorlds[world.nextWorldId] = true end
  end
 end
 return data, nil, repairs
end

local function owns(record, session)
 return typeof(record) == "table" and typeof(record.Session) == "table"
  and record.Session.Id == session.id
end

-- Retries stay inside a single serialized operation; an older save never overtakes a newer save.
local function update(session, transform, deadline)
 local lastError = "request deadline exceeded"
 for attempt = 1, MAX_ATTEMPTS do
  if os.clock() >= deadline then break end
  local ok, result = pcall(function()
   local store = DataStoreService:GetDataStore(STORE_NAME)
   return store:UpdateAsync(session.key, function(record)
    if os.clock() >= deadline then return nil end
    return transform(record)
   end)
  end)
  if ok then return true, result end
  lastError = tostring(result)
  if attempt < MAX_ATTEMPTS and os.clock() + 2 ^ attempt < deadline then
   task.wait(2 ^ attempt)
  end
 end
 return false, lastError
end

function PlayerData.IsReady(player)
 local session = sessions[player]
 return session ~= nil and session.loaded and not session.closing and not session.failed
  and not shuttingDown and player.Parent == Players
  and os.time() < session.expiresAt - LEASE_SAFETY_SECONDS
end

function PlayerData.OwnsEquipment(player, category, id)
 if not PlayerData.IsReady(player) or type(id) ~= "string" or not Equipment.Get(category, id) then return false end
 return sessions[player].owned[category][id] == true
end

function PlayerData.GetNextEquipment(player, category)
 if not PlayerData.IsReady(player) or not Equipment.Categories[category] then return nil end
 return Equipment.GetNextPurchase(category, sessions[player].owned[category])
end

function PlayerData.PurchaseNextEquipment(player, category, purchaseToken)
 if not PlayerData.IsReady(player) then return false, "Your data is not ready. Please wait." end
 local definition = Equipment.Categories[category]
 if not definition then return false, "Invalid equipment category." end
 if player:GetAttribute("BattingActive") then return false, "Press Space to leave batting before shopping." end
 local session = sessions[player]
 -- This opaque server-issued token identifies the current offer. Retrying an old
 -- request can never buy the following item, even after the request cooldown.
 if type(purchaseToken) ~= "string" or purchaseToken ~= session.purchaseTokens[category] then
  return false, "That purchase is out of date. Check the current equipment list."
 end
 local item = PlayerData.GetNextEquipment(player, category)
 if not item then return false, "No additional equipment is currently available." end
 if session.owned[category][item.id] then return false, "You already own this equipment." end
 local cash = player.leaderstats.Cash
 local price = item.price
 if not validCash(price) or not validCash(cash.Value) then return false, "Invalid purchase data." end
 if cash.Value < price then return false, string.format("Not enough Cash. Need %d more.", price - cash.Value) end
 -- No yields between validation, deduction, ownership, and equipping.
 cash.Value -= price
 session.owned[category][item.id] = true
 session.purchaseTokens[category] = HttpService:GenerateGUID(false)
 player[definition.ownedField]:SetAttribute(item.id, true)
 player:SetAttribute("Equipped" .. category, item.id)
 player:SetAttribute("EquipmentPurchaseToken_" .. category, session.purchaseTokens[category])
 return true, "Purchased and equipped " .. item.displayName .. "!"
end

function PlayerData.EquipEquipment(player, category, id)
 if not PlayerData.IsReady(player) then return false, "Your data is not ready. Please wait." end
 if player:GetAttribute("BattingActive") then return false, "Press Space to leave batting before equipping." end
 if not PlayerData.OwnsEquipment(player, category, id) then return false, "You do not own that equipment in this category." end
 local item = Equipment.Get(category, id)
 player:SetAttribute("Equipped" .. category, item.id)
 return true, "Equipped " .. item.displayName .. "."
end

local function fail(player, session, reason)
 if session.failed then return end
 session.failed = true
 player:SetAttribute("DataLoaded", false)
 player:SetAttribute("DataLoadState", "Failed")
 warn(string.format("[PlayerData] FAILED %d: %s. Progression disabled; no default save.",
  player.UserId, reason))
 if player.Parent == Players then
  player:Kick("Your data could not be safely loaded or saved. Please rejoin in a few minutes.")
 end
end

local function snapshot(player)
 local session = sessions[player]
 local stats = player:FindFirstChild("leaderstats")
 local cash = stats and stats:FindFirstChild("Cash")
 if not cash or not cash:IsA("IntValue") or not validCash(cash.Value) then return nil end
 local data = {SchemaVersion = SCHEMA_VERSION, Cash = cash.Value}
 for _, category in CATEGORIES do
  local field = "Equipped" .. category
  local id = player:GetAttribute(field)
  local owned = session.owned[category]
  if typeof(id) ~= "string" or not Equipment.Get(category, id) or owned[id] ~= true then return nil end
  local definition = Equipment.Categories[category]
  if owned[definition.startingId] ~= true then return nil end
  for ownedId, value in owned do
   if type(ownedId) ~= "string" or value ~= true or not Equipment.Get(category, ownedId) then return nil end
  end
  data[definition.ownedField] = table.clone(owned)
  data[field] = id
 end
 data.UnlockedWorlds, data.CompletedWorlds = {}, {}
 for _, world in Worlds.Worlds do
  if player:GetAttribute("WorldUnlocked_" .. world.id) == true then data.UnlockedWorlds[world.id] = true end
  if player:GetAttribute("WorldCompleted_" .. world.id) == true then data.CompletedWorlds[world.id] = true end
 end
 data.UnlockedWorlds[Worlds.StartingWorldId] = true
 return data
end

local function save(player, session, release)
 if not session.loaded or session.failed then return end
 local data = snapshot(player)
 if not data then fail(player, session, "invalid runtime progression; save refused") return end
 session.saving = true
 local writeId = HttpService:GenerateGUID(false)
 local rejection
 local ok, record = update(session, function(current)
  rejection = nil
  -- A retry after a committed response was lost must not write twice or reacquire a released lease.
  if typeof(current) == "table" and current.LastWriteId == writeId then return current end
  if not owns(current, session) or typeof(current.Session.ExpiresAt) ~= "number"
   or current.Session.ExpiresAt <= os.time() then
   rejection = "session ownership lost or expired"
   return nil
  end
  local updated = table.clone(current)
  for field, value in data do updated[field] = value end
  updated.LastWriteId = writeId
  if release then
   updated.Session = nil
  else
   updated.Session = {Id = session.id, ExpiresAt = os.time() + LEASE_SECONDS}
  end
  return updated
 end, os.clock() + REQUEST_SECONDS)
 session.saving = false
 if ok and record and record.LastWriteId == writeId then
  if not release then session.expiresAt = record.Session.ExpiresAt end
  print(string.format("[PlayerData] SAVED %d (%s), Cash=%d",
   player.UserId, release and "leave/shutdown" or "autosave", data.Cash))
 elseif rejection then
  fail(player, session, rejection)
 else
  warn(string.format("[PlayerData] SAVE FAILED %d (%s): %s",
   player.UserId, release and "leave/shutdown" or "autosave", tostring(record)))
  -- An autosave failure may recover next interval while the lease is still safe.
 end
end

local function close(player, session)
 session.closing = true
 player:SetAttribute("DataLoaded", false)
 if not session.failed then player:SetAttribute("DataLoadState", "Closing") end
 -- The loader will call close when its pending request finishes.
 if session.loading or session.closeStarted then return end
 session.closeStarted = true
 while session.saving do task.wait(0.1) end
 save(player, session, true)
 session.finished = true
 sessions[player] = nil
end

local function loadPlayer(player)
 if sessions[player] or shuttingDown then return end
 local session = {
  id = HttpService:GenerateGUID(false), key = "Player_" .. player.UserId,
  loading = true, loaded = false, expiresAt = 0,
 }
 sessions[player] = session
 player:SetAttribute("DataLoaded", false)
 player:SetAttribute("DataLoadState", "Loading")
 local rejection, repairs
 local newRecord = false
 local ok, record = update(session, function(current)
  rejection = nil
  if session.closing or shuttingDown then return nil end
  local data, invalid, warnings = validate(current)
  if not data then rejection = invalid return nil end
  local lock = data.Session
  if lock ~= nil then
   if typeof(lock) ~= "table" or typeof(lock.Id) ~= "string"
    or typeof(lock.ExpiresAt) ~= "number" or lock.ExpiresAt ~= lock.ExpiresAt
    or lock.ExpiresAt == math.huge then
    rejection = "invalid session metadata"
    return nil
   end
   if lock.Id ~= session.id and lock.ExpiresAt > os.time() then
    rejection = "data is still in use by another server; retry shortly"
    return nil
   end
  end
  -- Remember NEW across retries of our own successful claim.
  newRecord = current == nil or (owns(current, session) and newRecord)
  repairs = warnings
  data.Session = {Id = session.id, ExpiresAt = os.time() + LEASE_SECONDS}
  return data
 end, os.clock() + REQUEST_SECONDS)
 session.loading = false
 if not ok or not owns(record, session) then
  if not session.closing then fail(player, session, rejection or tostring(record)) end
  session.finished = true
  sessions[player] = nil
  return
 end
 session.expiresAt = record.Session.ExpiresAt
 -- Publish the complete authoritative runtime state only after a successful claim.
 local stats = Instance.new("Folder")
 stats.Name = "leaderstats"
 local cash = Instance.new("IntValue")
 cash.Name = "Cash"
 cash.Value = record.Cash
 cash.Parent = stats
 session.owned, session.purchaseTokens = {}, {}
 for _, category in CATEGORIES do
  local field = "Equipped" .. category
  local ownedField = Equipment.Categories[category].ownedField
  session.owned[category] = table.clone(record[ownedField])
  session.purchaseTokens[category] = HttpService:GenerateGUID(false)
  -- Replicated display state is a copy; purchase/equip/save checks use the private set.
  local ownedFolder = Instance.new("Folder")
  ownedFolder.Name = ownedField
  for id in session.owned[category] do ownedFolder:SetAttribute(id, true) end
  ownedFolder.Parent = player
  player:SetAttribute("EquipmentPurchaseToken_" .. category, session.purchaseTokens[category])
  player:SetAttribute(field, record[field])
 end
 for _, world in Worlds.Worlds do
  player:SetAttribute("WorldUnlocked_" .. world.id, record.UnlockedWorlds[world.id] == true)
  player:SetAttribute("WorldCompleted_" .. world.id, record.CompletedWorlds[world.id] == true)
 end
 stats.Parent = player
 session.loaded = true
 session.nextSave = os.clock() + AUTOSAVE_SECONDS + math.random(0, 10)
 for _, repair in repairs or {} do
  warn("[PlayerData] " .. player.UserId .. ": replaced obsolete/invalid " .. repair .. " with starting equipment")
 end
 print(string.format("[PlayerData] %s %d, Cash=%d", newRecord and "NEW" or "RESTORED", player.UserId, record.Cash))
 if session.closing or shuttingDown or player.Parent ~= Players then
  close(player, session)
 elseif os.time() >= session.expiresAt - LEASE_SAFETY_SECONDS then
  fail(player, session, "load completed after the safe session deadline")
 else
  player:SetAttribute("DataLoadState", "Ready")
  player:SetAttribute("DataLoaded", true)
 end
end

function PlayerData.Start()
 if started then return end
 started = true
 Players.PlayerAdded:Connect(loadPlayer)
 Players.PlayerRemoving:Connect(function(player)
  local session = sessions[player]
  if session then close(player, session) end
 end)
 for _, player in Players:GetPlayers() do task.spawn(loadPlayer, player) end
 task.spawn(function()
  while not shuttingDown do
   task.wait(5)
   for player, session in sessions do
    if session.loaded and not session.closing and not session.failed then
     if os.time() >= session.expiresAt - LEASE_SAFETY_SECONDS then
      fail(player, session, "autosave could not renew the session safely")
     elseif not session.saving and os.clock() >= session.nextSave then
      session.nextSave = os.clock() + AUTOSAVE_SECONDS
      task.spawn(save, player, session, false)
     end
    end
   end
  end
 end)
 game:BindToClose(function()
  shuttingDown = true
  local pending = {}
  for player, session in sessions do
   table.insert(pending, session)
   task.spawn(close, player, session)
  end
  local deadline = os.clock() + SHUTDOWN_SECONDS
  repeat
   local complete = true
   for _, session in pending do
    if not session.finished then complete = false break end
   end
   if complete then return end
   task.wait(0.1)
  until os.clock() >= deadline
  warn("[PlayerData] Shutdown save deadline reached; check earlier save warnings.")
 end)
end

return PlayerData
