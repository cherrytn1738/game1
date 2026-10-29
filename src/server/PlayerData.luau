-- Server-only persistence. Gameplay continues to use leaderstats.Cash and Equipped* attributes.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Marketplace = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Equipment = require(game:GetService("ReplicatedStorage"):WaitForChild("EquipmentConfig"))

local Worlds = require(game.ReplicatedStorage:WaitForChild("WorldConfig"))
local Progression = require(game.ReplicatedStorage:WaitForChild("ProgressionConfig"))
local Training = require(game.ReplicatedStorage:WaitForChild("TrainingConfig"))
local Juice = require(game.ReplicatedStorage:WaitForChild("JuiceConfig"))

local STORE_NAME = "PlayerProgression"
local SCHEMA_VERSION = 9
local AUTOSAVE_SECONDS = 60
local IMPORTANT_SAVE_SECONDS = 5 -- Rebirth joins the existing serialized save loop.
local LEASE_SECONDS = 180
local LEASE_SAFETY_SECONDS = 15
local MAX_ATTEMPTS = 3
local REQUEST_SECONDS = 20
local SHUTDOWN_SECONDS = 25
local MAX_CASH = 9000000000000 -- Safely below the integer precision limit.
local MAX_COUNTER = 9000000000000 -- the same limit for TimePlayed (seconds) and RobuxSpent
local MAX_RECEIPTS = 50 -- recent developer product receipts remembered, so none counts twice
local CATEGORIES = Equipment.CategoryOrder

local PlayerData = {}
local sessions = {}
local started, shuttingDown = false, false
local savedListener

local function validCash(value)
 return typeof(value) == "number" and value == value
  and value >= 0 and value <= MAX_CASH and value % 1 == 0
end

local function validCounter(value)
 return typeof(value) == "number" and value == value
  and value >= 0 and value <= MAX_COUNTER and value % 1 == 0
end

-- RobuxPurchases: the purchases already counted in RobuxSpent, as {Passes = {["<game pass id>"]
-- = true}, Receipts = {"<PurchaseId>", ...}} (the most recent MAX_RECEIPTS). Missing is empty;
-- a malformed record returns nil (fails closed); stray entries are dropped.
local function sanitizeRobuxPurchases(value)
 if value == nil then return {Passes = {}, Receipts = {}} end
 if typeof(value) ~= "table" or (value.Passes ~= nil and typeof(value.Passes) ~= "table")
  or (value.Receipts ~= nil and typeof(value.Receipts) ~= "table") then
  return nil
 end
 local passes, receipts = {}, {}
 for id, counted in value.Passes or {} do
  if type(id) == "string" and id:match("^%d+$") and counted == true then passes[id] = true end
 end
 for _, id in value.Receipts or {} do
  if type(id) == "string" and #id > 0 and #id <= 64 then table.insert(receipts, id) end
 end
 while #receipts > MAX_RECEIPTS do table.remove(receipts, 1) end
 return {Passes = passes, Receipts = receipts}
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
 -- Schema 6 retires player Tee equipment; malformed legacy fields are harmless.
 data.OwnedTees, data.EquippedTee = nil, nil
 for field, value in Progression.Normalize(record, (version or 1) < 4) do data[field] = value end
 -- Schema 8: Training Grounds are physical cages, so no ground selection is saved.
 data.SelectedTrainingGround = nil
 -- Old schemas cannot manufacture historical offline rewards.
 if (version or 1) < 5 then data.LastLogoutTime = nil end
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
 -- Schema 7 adds Juice (owned counts and remaining seconds of active juices). Older saves
 -- have none; a malformed field fails closed like other progression.
 local ownedJuices, activeJuices = Juice.Sanitize(data.OwnedJuices, data.ActiveJuices)
 if not ownedJuices then return nil, "invalid Juice data" end
 data.OwnedJuices, data.ActiveJuices = ownedJuices, activeJuices
 -- Schema 9 adds, for the global leaderboards, TimePlayed (whole seconds in the game) and
 -- RobuxSpent (verified Robux spent in this experience) with RobuxPurchases (what it already
 -- counts). Older saves start at zero; a malformed value fails closed like Cash.
 for _, field in {"TimePlayed", "RobuxSpent"} do
  if data[field] == nil then
   data[field] = 0
  elseif not validCounter(data[field]) then
   return nil, "invalid " .. field
  end
 end
 local purchases = sanitizeRobuxPurchases(data.RobuxPurchases)
 if not purchases then return nil, "invalid RobuxPurchases" end
 data.RobuxPurchases = purchases
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

local function publishProgression(player, state)
 for field, value in state do player:SetAttribute(field, value) end
end

-- Replicated attributes are display copies; gameplay and saves use private state.
function PlayerData.GetProgression(player)
 if not PlayerData.IsReady(player) then return nil end
 return table.clone(sessions[player].progression)
end

-- Single grant path, also used on the private save snapshot during atomic login.
-- The equipped Ball (ballId) multiplies the Power; the Bat never does.
-- boost is the active Juice Power multiplier (online grants only; offline passes none).
local function grantProgression(state, baseAmount, source, ballId, boost)
 if not Progression.IsInteger(baseAmount, 0, Progression.MaxBaseGrant)
  or type(source) ~= "string" or #source == 0 or #source > 64 then
  return false, "Invalid Power grant."
 end
 local ball = Equipment.Get("Ball", ballId)
 if not ball then return false, "Invalid Ball for Power grant." end
 local oldLevel = state.Level
 -- Granted at the Level Cap too: Power keeps building there until a Rebirth.
 local amount = Progression.GetPowerGrant(baseAmount, state.Rebirths, ball.powerGainMultiplier, boost)
 Progression.Advance(state, amount)
 return true, {powerGranted = amount, oldLevel = oldLevel, newLevel = state.Level, source = source}
end

function PlayerData.GrantPower(player, baseAmount, source, hitBallId)
 if not PlayerData.IsReady(player) then return false, "Player data is not ready." end
 -- The optional ID is a server-created hit snapshot, never a client multiplier.
 local ballId = hitBallId or player:GetAttribute("EquippedBall")
 if not PlayerData.OwnsEquipment(player, "Ball", ballId) then return false, "Invalid equipped Ball." end
 local session = sessions[player]
 local state = session.progression
 local boost = Juice.GetMultiplier(session.juices.active, "Power")
 local ok, result = grantProgression(state, baseAmount, source, ballId, boost)
 if ok then publishProgression(player, state) end
 return ok, result
end

-- Juice ---------------------------------------------------------------------------
-- Display copies for the client: OwnedJuices (id -> count) and ActiveJuices (id ->
-- whole seconds left). Gameplay reads the private session state.
local function publishJuices(player, session)
 for _, entry in {{"OwnedJuices", session.juices.owned}, {"ActiveJuices", session.juices.active}} do
  local folder = player:FindFirstChild(entry[1])
  if not folder then
   folder = Instance.new("Folder")
   folder.Name, folder.Parent = entry[1], player
  end
  for id in folder:GetAttributes() do
   if entry[2][id] == nil then folder:SetAttribute(id, nil) end
  end
  for id, value in entry[2] do folder:SetAttribute(id, math.ceil(value)) end
 end
end

local function scheduleImportantSave(session)
 session.importantSavePending = true
 session.nextSave = math.min(session.nextSave, os.clock() + IMPORTANT_SAVE_SECONDS)
end

-- Combined multiplier of the player's active juices for one effect ("Power" or "Cash").
function PlayerData.GetJuiceMultiplier(player, effect)
 if not PlayerData.IsReady(player) then return 1 end
 return Juice.GetMultiplier(sessions[player].juices.active, effect)
end

-- Server-only: gives juice (for future rewards, shop items, or codes). Never a client input.
function PlayerData.GrantJuice(player, id, count, source)
 if not PlayerData.IsReady(player) then return false, "Player data is not ready." end
 local definition = Juice.Get(id)
 if not definition then return false, "Unknown juice." end
 if not Progression.IsInteger(count, 1, Juice.MaxOwned) or type(source) ~= "string" or #source == 0 then
  return false, "Invalid juice grant."
 end
 local session = sessions[player]
 local total = (session.juices.owned[id] or 0) + count
 if total > Juice.MaxOwned then return false, "You can't hold any more " .. definition.displayName .. "." end
 session.juices.owned[id] = total
 scheduleImportantSave(session)
 publishJuices(player, session)
 return true, "+" .. count .. " " .. definition.displayName
end

-- Drinks one juice. Using a juice that is already active adds its duration (capped).
function PlayerData.UseJuice(player, id)
 if not PlayerData.IsReady(player) then return false, "Your data is not ready. Please wait." end
 local definition = Juice.Get(id)
 if not definition then return false, "Unknown juice." end
 local session = sessions[player]
 local owned = session.juices.owned[id] or 0
 if owned < 1 then return false, "You don't have any " .. definition.displayName .. "." end
 local remaining = session.juices.active[id] or 0
 if remaining + definition.durationSeconds > Juice.MaxActiveSeconds then
  return false, definition.displayName .. " is already at its maximum time."
 end
 session.juices.owned[id] = owned > 1 and owned - 1 or nil
 session.juices.active[id] = remaining + definition.durationSeconds
 scheduleImportantSave(session)
 publishJuices(player, session)
 return true, string.format("%s active! %sx %s", definition.displayName,
  string.format("%g", definition.multiplier), Juice.Effects[definition.effect].description)
end

-- Counts active juices down. Timers only run while the player is in the game.
function PlayerData.TickJuices(seconds)
 if type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 or seconds == math.huge then return end
 for player, session in sessions do
  if session.loaded and not session.closing and not session.failed and next(session.juices.active) then
   for id, remaining in session.juices.active do
    session.juices.active[id] = remaining - seconds > 0 and remaining - seconds or nil
   end
   publishJuices(player, session)
  end
 end
end

-- Training Grounds ------------------------------------------------------------------
-- Paid grounds are Roblox game passes. Roblox is the source of truth, so ownership is
-- checked at login and on purchase, never saved and never taken from the client. A shared
-- pass is keyed by the ground that owns it (Training.GetPassGround).
local function fetchTrainingPasses(player)
 local passes = {}
 for _, ground in Training.PassGrounds do
  if ground.gamePassId > 0 then
   local ok, owned = pcall(Marketplace.UserOwnsGamePassAsync, Marketplace, player.UserId, ground.gamePassId)
   if ok and owned == true then passes[ground.id] = true end
  end
 end
 return passes
end

local function publishTrainingPasses(player, session)
 for _, ground in Training.PassGrounds do
  player:SetAttribute("TrainingPass_" .. ground.id, session.trainingPasses[ground.id] == true)
 end
end

-- Returns the ground when this player may train there, otherwise nil and a reason. World
-- unlocks come from the server-set WorldUnlocked_<id> attributes.
function PlayerData.CanUseTrainingGround(player, id)
 if not PlayerData.IsReady(player) then return nil, "Player data is not ready." end
 local ground = type(id) == "string" and Training.Get(id)
 if not ground then return nil, "Unknown Training Ground." end
 local session = sessions[player]
 local worlds = Training.ReadUnlockedWorlds(player)
 if Training.CanUse(id, session.progression.Rebirths, session.trainingPasses, worlds) then return ground end
 if not Training.IsReachable(ground, worlds) then
  local world = Worlds.Get(ground.worlds[1])
  return nil, string.format("%s is in %s. Unlock %s to train there.", ground.displayName, world.displayName, world.displayName)
 end
 if Training.IsPaid(ground) then
  local pass = Training.GetPassGround(ground)
  return nil, string.format("%s is unlocked with the %d Robux %s pass.", ground.displayName, pass.robuxPrice, pass.displayName)
 end
 return nil, string.format("%s requires %d Rebirths.", ground.displayName, ground.requiredRebirths)
end

function PlayerData.GetBestTrainingGround(player)
 if not PlayerData.IsReady(player) then return nil end
 local session = sessions[player]
 return Training.GetBestGround(session.progression.Rebirths, session.trainingPasses, Training.ReadUnlockedWorlds(player))
end

-- id is a pass ground id (Training.GetPassGround(ground).id).
function PlayerData.OwnsTrainingPass(player, id)
 return PlayerData.IsReady(player) and sessions[player].trainingPasses[id] == true
end

-- Re-checks Roblox, e.g. for a pass bought on the website mid-session. Yields; passes are
-- only ever added here, so a failed lookup cannot take one away.
function PlayerData.RefreshTrainingPasses(player)
 if not PlayerData.IsReady(player) then return end
 local passes = fetchTrainingPasses(player)
 local session = sessions[player]
 if not session or not session.loaded then return end
 for id in passes do session.trainingPasses[id] = true end
 publishTrainingPasses(player, session)
end

-- Leaderboard stats ------------------------------------------------------------------
-- TimePlayed counts whole seconds in the game, from the server's own clock: the saved total
-- plus this session's time so far (it stops when the player leaves).
local function timePlayed(session)
 local seconds = math.floor((session.closeClock or os.clock()) - session.playClock)
 return math.min(MAX_COUNTER, session.timePlayed + math.max(0, seconds))
end

-- RobuxSpent counts only Robux the server saw being spent in this experience: game passes
-- bought through an in-game prompt (PromptGamePassPurchaseFinished, which Roblox fires on the
-- server) and developer product receipts (RecordRobuxReceipt). Each purchase counts once: a pass
-- by its id, a receipt by its PurchaseId. Purchases made elsewhere (such as the website) or
-- before tracking began are not counted, and no amount ever comes from the client.
local function addRobux(session, amount)
 session.robux.spent = math.min(MAX_COUNTER, session.robux.spent + amount)
 scheduleImportantSave(session)
end

-- A game pass's price from Roblox, or failing that the price this game sells it for.
local function gamePassPrice(gamePassId)
 local ok, info = pcall(Marketplace.GetProductInfo, Marketplace, gamePassId, Enum.InfoType.GamePass)
 if ok and typeof(info) == "table" and validCounter(info.PriceInRobux) then return info.PriceInRobux end
 for _, ground in Training.PassGrounds do
  if ground.gamePassId == gamePassId then return ground.robuxPrice end
 end
 return nil
end

-- Yields (price lookup). The pass is marked first, so a repeated event cannot count it twice.
local function recordGamePassPurchase(player, session, gamePassId)
 if not Progression.IsInteger(gamePassId, 1, MAX_COUNTER) then return end
 local key = tostring(gamePassId)
 if session.robux.passes[key] then return end
 session.robux.passes[key] = true
 local price = gamePassPrice(gamePassId)
 if price and sessions[player] == session and not session.failed then addRobux(session, price) end
end

local function validReceipt(player, receipt)
 if typeof(receipt) ~= "table" or receipt.PlayerId ~= player.UserId then return false end
 local id = receipt.PurchaseId
 return type(id) == "string" and #id > 0 and #id <= 64 and validCounter(receipt.CurrencySpent)
  and (receipt.CurrencyType == nil or receipt.CurrencyType == Enum.CurrencyType.Robux)
end

-- For a developer product's ProcessReceipt handler: call it once the product has been granted,
-- with Roblox's receipt. Returns true when counted, false when the receipt is invalid, not this
-- player's, not Robux, or already counted.
function PlayerData.RecordRobuxReceipt(player, receipt)
 if not PlayerData.IsReady(player) or not validReceipt(player, receipt) then return false end
 local id, spent = receipt.PurchaseId, receipt.CurrencySpent
 local session = sessions[player]
 local receipts = session.robux.receipts
 if table.find(receipts, id) then return false end
 table.insert(receipts, id)
 while #receipts > MAX_RECEIPTS do table.remove(receipts, 1) end
 addRobux(session, spent)
 return true
end

-- Leaderboards: callback(userId, savedData, final) runs after each successful save, in its own
-- thread, so it can never delay or break a save. final is the save made as the player leaves.
function PlayerData.OnSaved(callback)
 savedListener = callback
end

function PlayerData.CanRebirth(player)
 if not PlayerData.IsReady(player) then return false end
 local state = sessions[player].progression
 return state.Level >= state.LevelCap and state.Rebirths < Progression.MaxRebirths
end

function PlayerData.TryRebirth(player)
 if not PlayerData.CanRebirth(player) then return false, "Reach your Level Cap first." end
 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not character or not character.Parent or not humanoid or humanoid.Health <= 0
  or player:GetAttribute("WorldTraveling") then
  return false, "Wait until you are alive and world travel has finished."
 end
 if player:GetAttribute("BattingActive") or player:GetAttribute("HitActive") or player:GetAttribute("TrainingActive") then
  return false, "Leave training or batting before rebirthing."
 end
 local session = sessions[player]
 local state = table.clone(session.progression)
 state.Rebirths += 1
 state.Level, state.Power = Progression.StartingLevel, Progression.StartingPower
 state.LevelCap = Progression.GetLevelCap(state.Rebirths)
 -- No yields: validate first, then commit the complete private state and its display copies.
 session.progression = state
 session.importantSavePending = true
 session.nextSave = math.min(session.nextSave, os.clock() + IMPORTANT_SAVE_SECONDS)
 publishProgression(player, state)
 return true, string.format("REBIRTH COMPLETE\nRebirths: %d | Rebirth Power: %dx | Level Cap: %d",
  state.Rebirths, Progression.GetPowerMultiplier(state.Rebirths), state.LevelCap)
end

function PlayerData.OwnsEquipment(player, category, id)
 if not PlayerData.IsReady(player) or type(id) ~= "string" or not Equipment.Get(category, id) then return false end
 return sessions[player].owned[category][id] == true
end

function PlayerData.GetNextEquipment(player, category, seriesId)
 if not PlayerData.IsReady(player) or not Equipment.Categories[category] then return nil end
 return Equipment.GetNextPurchase(category, sessions[player].owned[category], seriesId)
end

function PlayerData.PurchaseNextEquipment(player, category, purchaseToken)
 if not PlayerData.IsReady(player) then return false, "Your data is not ready. Please wait." end
 local definition = Equipment.Categories[category]
 if not definition then return false, "Invalid equipment category." end
 if player:GetAttribute("BattingActive") or player:GetAttribute("HitActive") or player:GetAttribute("TrainingActive") then
  return false, "Leave training or batting before shopping."
 end
 local session = sessions[player]
 -- This opaque server-issued token identifies the current offer of one series. Retrying an
 -- old request can never buy the following item, even after the request cooldown.
 local series
 for _, candidate in Equipment.GetSeries(category) do
  if type(purchaseToken) == "string" and purchaseToken == session.purchaseTokens[Equipment.OfferKey(category, candidate.id)] then
   series = candidate
  end
 end
 if not series then
  return false, "That purchase is out of date. Check the current equipment list."
 end
 local world = series.requiredWorld and Worlds.Get(series.requiredWorld)
 if world and player:GetAttribute("WorldUnlocked_" .. world.id) ~= true then
  return false, "Unlock " .. world.displayName .. " to buy its " .. definition.displayName .. "."
 end
 local item = PlayerData.GetNextEquipment(player, category, series.id)
 if not item then return false, "No additional equipment is currently available." end
 if session.owned[category][item.id] then return false, "You already own this equipment." end
 local cash = player.leaderstats.Cash
 local price = item.price
 if not validCash(price) or not validCash(cash.Value) then return false, "Invalid purchase data." end
 if cash.Value < price then return false, string.format("Not enough Cash. Need %d more.", price - cash.Value) end
 -- No yields between validation, deduction, ownership, and equipping.
 local offerKey = Equipment.OfferKey(category, series.id)
 cash.Value -= price
 session.owned[category][item.id] = true
 session.purchaseTokens[offerKey] = HttpService:GenerateGUID(false)
 player[definition.ownedField]:SetAttribute(item.id, true)
 player:SetAttribute("Equipped" .. category, item.id)
 player:SetAttribute("EquipmentPurchaseToken_" .. offerKey, session.purchaseTokens[offerKey])
 return true, "Purchased and equipped " .. item.displayName .. "!"
end

function PlayerData.EquipEquipment(player, category, id)
 if not PlayerData.IsReady(player) then return false, "Your data is not ready. Please wait." end
 if player:GetAttribute("BattingActive") or player:GetAttribute("HitActive") or player:GetAttribute("TrainingActive") then
  return false, "Leave training or batting before equipping."
 end
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
 for field, value in session.progression do data[field] = value end
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
  -- Studio playtest grants are never saved; equipping one keeps the saved equipped item.
  local saved = table.clone(owned)
  for grantedId in session.studioOwned and session.studioOwned[category] or {} do saved[grantedId] = nil end
  if saved[id] ~= true then id = session.loadedEquipped[category] end
  data[definition.ownedField] = saved
  data[field] = id
 end
 data.OwnedJuices = table.clone(session.juices.owned)
 data.ActiveJuices = {}
 for id, remaining in session.juices.active do data.ActiveJuices[id] = math.ceil(remaining) end
 data.TimePlayed = timePlayed(session)
 data.RobuxSpent = session.robux.spent
 data.RobuxPurchases = {Passes = table.clone(session.robux.passes), Receipts = table.clone(session.robux.receipts)}
 data.UnlockedWorlds, data.CompletedWorlds = {}, {}
 for _, world in Worlds.Worlds do
  -- Studio playtest unlocks are never saved; a real completion re-derives its unlock on load.
  local studioOnly = session.studioWorlds and session.studioWorlds[world.id]
  if player:GetAttribute("WorldUnlocked_" .. world.id) == true and not studioOnly then data.UnlockedWorlds[world.id] = true end
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
 -- A Rebirth during this yielding save sets the flag again for a follow-up snapshot.
 local importantSave = session.importantSavePending
 session.importantSavePending = false
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
  updated.OwnedTees, updated.EquippedTee, updated.SelectedTrainingGround = nil, nil, nil
  for field, value in data do updated[field] = value end
  -- Autosave is also a crash checkpoint; normal exit uses the actual close time.
  updated.LastLogoutTime = release and session.logoutTime or os.time()
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
  if savedListener then task.spawn(savedListener, player.UserId, data, release == true) end
 elseif rejection then
  fail(player, session, rejection)
 else
  if importantSave then session.importantSavePending = true end
  warn(string.format("[PlayerData] SAVE FAILED %d (%s): %s",
   player.UserId, release and "leave/shutdown" or "autosave", tostring(record)))
  -- An autosave failure may recover next interval while the lease is still safe.
 end
end

-- Welcome Back's 3x offer, from the developer product's receipt (ProductServer): adds this
-- login's offline Training reward twice more (3x in all) through the normal grant path, with the
-- Ball that earned it, under the usual Level Cap rules. Once per login. Returns Roblox's
-- ProductPurchaseDecision:
--   PurchaseGranted  granted now (and saved straight away), or this receipt was already granted
--   NotProcessedYet  the player's data isn't ready or there is no offer to fill; Roblox retries
--                    the receipt later (such as at their next login with an offline reward)
function PlayerData.ClaimOfflineTriple(player, receipt)
 local decision = Enum.ProductPurchaseDecision
 if not PlayerData.IsReady(player) or not validReceipt(player, receipt) then return decision.NotProcessedYet end
 local session = sessions[player]
 if table.find(session.robux.receipts, receipt.PurchaseId) then return decision.PurchaseGranted end
 local offer = session.offlineTriple
 if not offer then return decision.NotProcessedYet end
 local extra = offer.baseAmount * (Training.OfflineTriple.multiplier - 1)
 local granted = grantProgression(session.progression, extra, "OfflineTriple", offer.ballId)
 if not granted then return decision.NotProcessedYet end
 session.offlineTriple = nil
 player:SetAttribute("OfflineTripleAvailable", false)
 publishProgression(player, session.progression)
 PlayerData.RecordRobuxReceipt(player, receipt)
 -- Save now rather than at the next autosave, so a paid reward is on record before Roblox is
 -- told it was granted. (A failed save is retried by the autosave loop.)
 while session.saving do task.wait(0.1) end
 save(player, session, false)
 return decision.PurchaseGranted
end

local function close(player, session)
 session.logoutTime = session.logoutTime or os.time()
 session.closeClock = session.closeClock or os.clock()
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
 local offlineResult, offlineSeconds, offlineGround, offlineBase, offlineBall
 -- Pass ownership is needed before the atomic login: offline Training uses the best
 -- ground the player can use, including paid ones.
 local passes = fetchTrainingPasses(player)
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
  if not owns(current, session) then
   offlineGround = Training.GetBestGround(data.Rebirths, passes, data.UnlockedWorlds).id
   local baseAmount, seconds = Training.GetOfflineReward(data.LastLogoutTime, os.time(), offlineGround)
   local progression = Progression.Normalize(data, false)
   local granted, result = grantProgression(progression, baseAmount, "OfflineTraining", data.EquippedBall)
   if not granted then rejection = "invalid offline reward configuration" return nil end
   for field, value in progression do data[field] = value end
   offlineResult, offlineSeconds = result, seconds
   offlineBase, offlineBall = baseAmount, data.EquippedBall
  end
  -- Reward and timestamp consumption commit WITH the session claim. A response-loss
  -- retry sees our session ID and cannot apply the reward a second time.
  data.LastLogoutTime = nil
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
 session.progression = Progression.Normalize(record, false)
 session.trainingPasses = passes
 publishTrainingPasses(player, session)
 session.juices = {owned = table.clone(record.OwnedJuices), active = table.clone(record.ActiveJuices)}
 publishJuices(player, session)
 session.timePlayed, session.playClock = record.TimePlayed, os.clock()
 session.robux = {spent = record.RobuxSpent, passes = table.clone(record.RobuxPurchases.Passes),
  receipts = table.clone(record.RobuxPurchases.Receipts)}
 player:SetAttribute("OfflinePowerEarned", offlineResult and offlineResult.powerGranted or 0)
 player:SetAttribute("OfflineSeconds", offlineSeconds or 0)
 player:SetAttribute("OfflineTrainingGround",
  offlineGround or Training.GetBestGround(session.progression.Rebirths, passes, record.UnlockedWorlds).id)
 player:SetAttribute("OfflineOldLevel", offlineResult and offlineResult.oldLevel or session.progression.Level)
 player:SetAttribute("OfflineNewLevel", offlineResult and offlineResult.newLevel or session.progression.Level)
 -- Welcome Back's 3x offer (ClaimOfflineTriple): this login's offline reward, for adding it
 -- twice more. Offered whenever there was a reward (Power keeps building at the Level Cap).
 local tripleEligible = offlineBase ~= nil and offlineBase > 0
 session.offlineTriple = tripleEligible and {baseAmount = offlineBase, ballId = offlineBall} or nil
 player:SetAttribute("OfflineTripleAvailable", tripleEligible)
 publishProgression(player, session.progression)
 -- Publish the complete authoritative runtime state only after a successful claim.
 local stats = Instance.new("Folder")
 stats.Name = "leaderstats"
 local cash = Instance.new("IntValue")
 cash.Name = "Cash"
 cash.Value = record.Cash
 cash.Parent = stats
 session.owned, session.purchaseTokens = {}, {}
 session.studioOwned, session.loadedEquipped = {}, {}
 -- In Studio only, the Workspace attribute OwnAllBalls owns every Ball for playtests. These
 -- grants last for the session and are never saved (snapshot skips them).
 local grantAllBalls = RunService:IsStudio() and workspace:GetAttribute("OwnAllBalls") == true
 for _, category in CATEGORIES do
  local field = "Equipped" .. category
  local ownedField = Equipment.Categories[category].ownedField
  session.owned[category] = table.clone(record[ownedField])
  session.studioOwned[category] = {}
  session.loadedEquipped[category] = record[field]
  if grantAllBalls and category == "Ball" then
   for _, item in Equipment.GetItems(category) do
    if not session.owned[category][item.id] then
     session.owned[category][item.id] = true
     session.studioOwned[category][item.id] = true
    end
   end
  end
  for _, series in Equipment.GetSeries(category) do
   local offerKey = Equipment.OfferKey(category, series.id)
   session.purchaseTokens[offerKey] = HttpService:GenerateGUID(false)
   player:SetAttribute("EquipmentPurchaseToken_" .. offerKey, session.purchaseTokens[offerKey])
  end
  -- Replicated display state is a copy; purchase/equip/save checks use the private set.
  local ownedFolder = Instance.new("Folder")
  ownedFolder.Name = ownedField
  for id in session.owned[category] do ownedFolder:SetAttribute(id, true) end
  ownedFolder.Parent = player
  player:SetAttribute(field, record[field])
 end
 for _, world in Worlds.Worlds do
  player:SetAttribute("WorldUnlocked_" .. world.id, record.UnlockedWorlds[world.id] == true)
  player:SetAttribute("WorldCompleted_" .. world.id, record.CompletedWorlds[world.id] == true)
 end
 -- In Studio only, the Workspace attribute UnlockAllWorlds opens every World for playtests.
 -- These unlocks last for the session and are never saved (snapshot skips them).
 session.studioWorlds = {}
 if RunService:IsStudio() and workspace:GetAttribute("UnlockAllWorlds") == true then
  for _, world in Worlds.Worlds do
   if not record.UnlockedWorlds[world.id] then
    session.studioWorlds[world.id] = true
    player:SetAttribute("WorldUnlocked_" .. world.id, true)
   end
  end
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
 -- This event fires on the server with Roblox's purchase result, so it can be trusted.
 Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
  local session = sessions[player]
  if not purchased or not session or not session.loaded or session.failed then return end
  for _, ground in Training.PassGrounds do
   if ground.gamePassId > 0 and ground.gamePassId == gamePassId then
    session.trainingPasses[ground.id] = true
    publishTrainingPasses(player, session)
   end
  end
  recordGamePassPurchase(player, session, gamePassId)
 end)
 task.spawn(function()
  while not shuttingDown do
   task.wait(5)
   for player, session in sessions do
    if session.loaded and not session.closing and not session.failed then
     if os.time() >= session.expiresAt - LEASE_SAFETY_SECONDS then
      fail(player, session, "autosave could not renew the session safely")
     elseif not session.saving and (session.importantSavePending or os.clock() >= session.nextSave) then
      session.nextSave = os.clock() + AUTOSAVE_SECONDS
      task.spawn(save, player, session, false)
     end
    end
   end
  end
 end)
 -- Juice timers tick by real elapsed time, once per second.
 task.spawn(function()
  local last = os.clock()
  while not shuttingDown do
   task.wait(1)
   local current = os.clock()
   PlayerData.TickJuices(current - last)
   last = current
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
