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
local Tutorial = require(game.ReplicatedStorage:WaitForChild("TutorialConfig"))
local Monetization = require(game.ReplicatedStorage:WaitForChild("MonetizationConfig"))

local STORE_NAME = "PlayerProgression"
local SCHEMA_VERSION = 11
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
local MAX_RECEIVED_GIFTS = 100 -- recent gifts a player has been given (and their queue), so none applies twice
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

-- Gifts (see Gifts below). A delivered gift, as queued in the recipient's GiftInbox: its id (the
-- buyer's receipt PurchaseId), the gift (MonetizationConfig.GiftProducts id), the Cash fixed for
-- a Cash pack, and who sent it (UserId, plus their name for the notice). nil when malformed.
local function sanitizeGiftEntry(entry)
 if typeof(entry) ~= "table" or type(entry.id) ~= "string" or #entry.id == 0 or #entry.id > 64 then return nil end
 local gift = Monetization.GetGiftById(entry.gift)
 if not gift or not validCounter(entry.from) or entry.from < 1 then return nil end
 if gift.item.cashPack and not (validCash(entry.amount) and entry.amount >= 1) then return nil end
 local name = type(entry.fromName) == "string" and entry.fromName:sub(1, 40) or ""
 return {id = entry.id, gift = gift.id, amount = gift.item.cashPack and entry.amount or nil, from = entry.from, fromName = name}
end

-- The buyer's saved intent for a gift product, set before its prompt opens: who receives it, where
-- their save is (store and key), the Cash fixed for a Cash pack, when, and whether Roblox has
-- reported the purchase. nil when malformed.
local function sanitizeGiftIntent(id, intent)
 local gift = Monetization.GetGiftById(id)
 if not gift or typeof(intent) ~= "table" or not validCounter(intent.recipient) or intent.recipient < 1
  or type(intent.store) ~= "string" or #intent.store == 0 or #intent.store > 64
  or type(intent.key) ~= "string" or #intent.key == 0 or #intent.key > 64 or not validCounter(intent.at)
  or (intent.state ~= "prompted" and intent.state ~= "purchased") then
  return nil
 end
 if gift.item.cashPack and not (validCash(intent.amount) and intent.amount >= 1) then return nil end
 return {recipient = intent.recipient, recipientName = type(intent.recipientName) == "string" and intent.recipientName:sub(1, 40) or "",
  store = intent.store, key = intent.key, amount = gift.item.cashPack and intent.amount or nil, at = intent.at, state = intent.state}
end

-- Only a missing record means NEW. A malformed record/version fails closed.
local function validate(record)
 if record ~= nil and typeof(record) ~= "table" then return nil, "invalid record" end
 local isNew = record == nil
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
 -- Schema 7 adds Juice (owned counts and the expiry times of active juices). Older saves
 -- have none; a malformed field fails closed like other progression; expired timers drop.
 local ownedJuices, activeJuices = Juice.Sanitize(data.OwnedJuices, data.ActiveJuices, os.time())
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
 -- Schema 11 adds StarterPackGranted: whether the Starter Pack's rewards were given (once ever).
 -- Older saves have not had them; a malformed value fails closed.
 if data.StarterPackGranted == nil then
  data.StarterPackGranted = false
 elseif type(data.StarterPackGranted) ~= "boolean" then
  return nil, "invalid StarterPackGranted"
 end
 -- ...and CashPackQuotes: the Cash each Cash pack pays, fixed when the player last asked to buy it
 -- (QuoteCashPack). A non-table fails closed; unknown packs and invalid amounts are dropped.
 if data.CashPackQuotes ~= nil and typeof(data.CashPackQuotes) ~= "table" then return nil, "invalid CashPackQuotes" end
 local quotes = {}
 for id, amount in data.CashPackQuotes or {} do
  if Monetization.GetCashProductById(id) and validCash(amount) and amount >= 1 then quotes[id] = amount end
 end
 data.CashPackQuotes = quotes
 -- ...and the gift fields (see Gifts below): GiftedEntitlements, ReceivedGifts, GiftInbox and
 -- PendingGifts. A non-table fails closed; invalid entries are dropped.
 for _, field in {"GiftedEntitlements", "ReceivedGifts", "GiftInbox", "PendingGifts"} do
  if data[field] ~= nil and typeof(data[field]) ~= "table" then return nil, "invalid " .. field end
 end
 local entitlements = {}
 for id, owned in data.GiftedEntitlements or {} do
  if Monetization.GiftEntitlements[id] and owned == true then entitlements[id] = true end
 end
 data.GiftedEntitlements = entitlements
 local received = {}
 for _, id in data.ReceivedGifts or {} do
  if type(id) == "string" and #id > 0 and #id <= 64 then table.insert(received, id) end
 end
 while #received > MAX_RECEIVED_GIFTS do table.remove(received, 1) end
 data.ReceivedGifts = received
 local inbox = {}
 for _, entry in data.GiftInbox or {} do
  local clean = sanitizeGiftEntry(entry)
  if clean and #inbox < MAX_RECEIVED_GIFTS then table.insert(inbox, clean) end
 end
 data.GiftInbox = inbox
 local pending = {}
 for id, intent in data.PendingGifts or {} do
  local clean = sanitizeGiftIntent(id, intent)
  if clean then pending[id] = clean end
 end
 data.PendingGifts = pending
 data.UnlockedWorlds[Worlds.StartingWorldId] = true
 -- A recorded completion always implies ownership of that world and its next one.
 for _, world in Worlds.Worlds do
  if data.CompletedWorlds[world.id] then
   data.UnlockedWorlds[world.id] = true
   if world.nextWorldId then data.UnlockedWorlds[world.nextWorldId] = true end
  end
 end
 -- Schema 10 adds the new-player tutorial (TutorialCompleted, and while unfinished TutorialStep
 -- and TutorialProgress). A new record starts it; a save from before it, or with malformed
 -- fields, skips it when it already shows play (TutorialConfig.HasProgressed).
 Tutorial.ToSave(Tutorial.FromSave(data, isNew), data)
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
   local store = DataStoreService:GetDataStore(session.storeName or STORE_NAME)
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
-- limit (offline only) caps the whole Power granted, after every multiplier.
local function grantProgression(state, baseAmount, source, ballId, boost, limit)
 if not Progression.IsInteger(baseAmount, 0, Progression.MaxBaseGrant)
  or type(source) ~= "string" or #source == 0 or #source > 64 then
  return false, "Invalid Power grant."
 end
 local ball = Equipment.Get("Ball", ballId)
 if not ball then return false, "Invalid Ball for Power grant." end
 local oldLevel = state.Level
 -- Granted at the Level Cap too: Power keeps building there until a Rebirth.
 local amount = Progression.GetPowerGrant(baseAmount, state.Rebirths, ball.powerGainMultiplier, boost)
 if limit then amount = math.min(amount, limit) end
 Progression.Advance(state, amount)
 return true, {powerGranted = amount, oldLevel = oldLevel, newLevel = state.Level, source = source}
end

local function scheduleImportantSave(session)
 session.importantSavePending = true
 session.nextSave = math.min(session.nextSave, os.clock() + IMPORTANT_SAVE_SECONDS)
end

-- New-player tutorial (TutorialConfig). It moves only on this server's own events: granted
-- Power, batting Cash, purchases, Level and Rebirths; there is no client request to move it.
-- Clients read the TutorialStep / TutorialProgress attributes; a step change is saved soon.
local function publishTutorial(player, session)
 player:SetAttribute("TutorialStep", session.tutorial.step)
 player:SetAttribute("TutorialProgress", session.tutorial.progress)
 player:SetAttribute("TutorialBoughtBall", session.tutorial.boughtBall == true)
end

local function updateTutorial(player, session, kind, amount)
 local tutorial = session.tutorial
 if not tutorial or Tutorial.IsComplete(tutorial) then return end
 local counted = kind ~= nil and Tutorial.Credit(tutorial, kind, amount)
 local state = session.progression
 -- The Ball step needs the tutorial's Ball bought during the tutorial ("BallPurchase", only from
 -- PurchaseNextEquipment) and equipped (the server's EquippedBall). Only the player's own Rebirth
 -- ("ManualRebirth", from TryRebirth) counts as the tutorial's Rebirth; a bonus Rebirth (the
 -- Starter Pack's) does not.
 local moved = Tutorial.Advance(tutorial, {level = state.Level, levelCap = state.LevelCap,
  equippedBall = player:GetAttribute("EquippedBall"), rebirthed = kind == "ManualRebirth"})
 if moved or (counted and kind == "BallPurchase") then scheduleImportantSave(session) end
 if counted or moved then publishTutorial(player, session) end
end

-- Batting Cash, reported by BallLauncher after it pays a hit (for the tutorial's Cash step).
function PlayerData.RecordBattingCash(player, amount)
 if not PlayerData.IsReady(player) then return end
 updateTutorial(player, sessions[player], "Cash", amount)
end

function PlayerData.GrantPower(player, baseAmount, source, hitBallId, hitPowerBoost)
 if not PlayerData.IsReady(player) then return false, "Player data is not ready." end
 -- The optional ID and Power juice multiplier are a server-created hit snapshot (taken when the
 -- swing was accepted), never client values. Without them, the equipped Ball and juices now count.
 local ballId = hitBallId or player:GetAttribute("EquippedBall")
 if not PlayerData.OwnsEquipment(player, "Ball", ballId) then return false, "Invalid equipped Ball." end
 local session = sessions[player]
 local state = session.progression
 local snapshot = type(hitPowerBoost) == "number" and hitPowerBoost >= 1 and hitPowerBoost < math.huge
 local boost = snapshot and hitPowerBoost or Juice.GetMultiplier(session.juices.active, "Power", os.time())
 local ok, result = grantProgression(state, baseAmount, source, ballId, boost)
 if ok then
  publishProgression(player, state)
  updateTutorial(player, session, "Power", result.powerGranted)
 end
 return ok, result
end

-- Juice ---------------------------------------------------------------------------
-- Timers run on real time (os.time), also while the player is offline: session.juices.active
-- holds each running juice's expiry time, saved as is. Display copies for the client:
-- OwnedJuices (id -> count) and ActiveJuices (id -> expiry time, to compare with
-- workspace:GetServerTimeNow()). Gameplay reads the private session state.
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
  for id, value in entry[2] do folder:SetAttribute(id, value) end
 end
end

-- Combined multiplier of the player's active juices for one effect ("Power" or "Cash").
function PlayerData.GetJuiceMultiplier(player, effect)
 if not PlayerData.IsReady(player) then return 1 end
 return Juice.GetMultiplier(sessions[player].juices.active, effect, os.time())
end

-- In Studio only, the Workspace attribute StudioJuiceSeconds makes a drunk juice last that many
-- seconds instead (to watch one expire). Live servers ignore it.
local function juiceDuration(definition)
 local studioSeconds = RunService:IsStudio() and workspace:GetAttribute("StudioJuiceSeconds")
 if type(studioSeconds) == "number" and studioSeconds >= 1 and studioSeconds <= definition.durationSeconds then
  return math.floor(studioSeconds)
 end
 return definition.durationSeconds
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

-- Drinks one juice: it runs for its duration from now, or, if it is already running, that much
-- longer (the multiplier stays the same; capped at MaxActiveSeconds left). The client only names
-- the juice; count, duration and multiplier are the server's.
function PlayerData.UseJuice(player, id)
 if not PlayerData.IsReady(player) then return false, "Your data is not ready. Please wait." end
 local definition = Juice.Get(id)
 if not definition then return false, "Unknown juice." end
 local session = sessions[player]
 local owned = session.juices.owned[id] or 0
 if owned < 1 then return false, "You don't have any " .. definition.displayName .. "." end
 local now = os.time()
 local remaining = Juice.GetRemaining(session.juices.active[id], now)
 local duration = juiceDuration(definition)
 if remaining + duration > Juice.MaxActiveSeconds then
  return false, definition.displayName .. " is already at its maximum time."
 end
 session.juices.owned[id] = owned > 1 and owned - 1 or nil
 session.juices.active[id] = now + remaining + duration
 scheduleImportantSave(session)
 publishJuices(player, session)
 local name, minutes = string.upper(definition.displayName), math.floor(definition.durationSeconds / 60)
 if remaining > 0 then return true, string.format("%s +%d MIN", name, minutes) end
 return true, string.format("%s ACTIVATED!\n%gx %s FOR %d MIN", name, definition.multiplier,
  string.upper(Juice.Effects[definition.effect].displayName), minutes)
end

-- Ends the juices whose time is up at Unix time now (called every second; no client request).
function PlayerData.ExpireJuices(now)
 for player, session in sessions do
  if session.loaded and not session.closing and not session.failed then
   local expired = false
   for id, expiresAt in session.juices.active do
    if expiresAt <= now then
     session.juices.active[id] = nil
     expired = true
    end
   end
   if expired then publishJuices(player, session) end
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

-- Roblox's passes plus the pass grounds that gifted entitlements stand for (saved
-- GiftedEntitlements; see Gifts): either one opens the same grounds.
local function withGifted(passes, entitlements)
 local usable = table.clone(passes)
 for id in entitlements or {} do
  local passGround = Monetization.GiftEntitlements[id]
  if passGround then usable[passGround] = true end
 end
 return usable
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

-- Auto Bat ----------------------------------------------------------------------------
-- A game pass, checked like the Training Ground passes: at login and on purchase, never saved,
-- never taken from the client. In Studio only, the Workspace attribute StudioOwnAutoBat owns it
-- for playtests (before the pass exists). AutoBatOwned is the display copy; ProductServer
-- turns Auto Bat on (AutoBatEnabled) only for owners.
local function fetchAutoBat(player)
 if RunService:IsStudio() and workspace:GetAttribute("StudioOwnAutoBat") == true then return true end
 local passId = Monetization.AutoBat.gamePassId
 if passId <= 0 then return false end
 local ok, owned = pcall(Marketplace.UserOwnsGamePassAsync, Marketplace, player.UserId, passId)
 return ok and owned == true
end

function PlayerData.OwnsAutoBat(player)
 return PlayerData.IsReady(player) and sessions[player].autoBat == true
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
 if Monetization.AutoBat.gamePassId == gamePassId then return Monetization.AutoBat.robuxPrice end
 if Monetization.StarterPack.gamePassId == gamePassId then return Monetization.StarterPack.robuxPrice end
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
 updateTutorial(player, session, "ManualRebirth")
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
 -- A purchase equips the item, except the tutorial's Ball during the tutorial: its step has the
 -- player equip it themselves in the Inventory.
 local tutorialBall = category == "Ball" and item.id == Tutorial.BallId
 local equipItem = not (tutorialBall and not Tutorial.IsComplete(session.tutorial))
 if equipItem then player:SetAttribute("Equipped" .. category, item.id) end
 player:SetAttribute("EquipmentPurchaseToken_" .. offerKey, session.purchaseTokens[offerKey])
 updateTutorial(player, session, tutorialBall and "BallPurchase" or nil)
 if not equipItem then return true, "Purchased " .. item.displayName .. "! Equip it in your Inventory." end
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
 -- (Equipping the tutorial's Ball, once bought, completes its step.)
 updateTutorial(player, sessions[player])
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
 -- Expiry times, saved as they are: the timers keep running while the player is away.
 data.ActiveJuices = {}
 local now = os.time()
 for id, expiresAt in session.juices.active do
  if expiresAt > now then data.ActiveJuices[id] = expiresAt end
 end
 data.TimePlayed = timePlayed(session)
 data.RobuxSpent = session.robux.spent
 data.RobuxPurchases = {Passes = table.clone(session.robux.passes), Receipts = table.clone(session.robux.receipts)}
 data.StarterPackGranted = session.starterPack.granted
 data.CashPackQuotes = table.clone(session.cashQuotes)
 -- GiftInbox is not here: save() keeps what other servers have queued, minus what this session
 -- has applied (ReceivedGifts).
 data.GiftedEntitlements = table.clone(session.gifts.entitlements)
 data.ReceivedGifts = table.clone(session.gifts.received)
 data.PendingGifts = {}
 for id, intent in session.gifts.pending do data.PendingGifts[id] = table.clone(intent) end
 Tutorial.ToSave(session.tutorial, data)
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

-- Applies queued gifts to a loaded session (defined with the Gifts below).
local applyGiftEntries

-- Returns whether the save was written.
local function save(player, session, release)
 if not session.loaded or session.failed then return false end
 local data = snapshot(player)
 if not data then fail(player, session, "invalid runtime progression; save refused") return false end
 -- Gifts another server queued since this session loaded (applied once the save is written).
 local arrivals
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
  -- A finished tutorial keeps no step or count (the snapshot leaves them out).
  updated.TutorialStep, updated.TutorialProgress, updated.TutorialBoughtBall = nil, nil, nil
  for field, value in data do updated[field] = value end
  -- The gift queue: gifts this session has applied leave it; any others stay queued and are
  -- applied after this save (another server may have added them).
  arrivals = {}
  local kept = {}
  for _, entry in typeof(current.GiftInbox) == "table" and current.GiftInbox or {} do
   local clean = sanitizeGiftEntry(entry)
   if clean and not table.find(data.ReceivedGifts, clean.id) then
    table.insert(kept, clean)
    table.insert(arrivals, clean)
   end
  end
  updated.GiftInbox = kept
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
  if savedListener and not session.fresh then task.spawn(savedListener, player.UserId, data, release == true) end
  if not release and arrivals and #arrivals > 0 then task.spawn(applyGiftEntries, player, session, arrivals) end
  return true
 elseif rejection then
  fail(player, session, rejection)
 else
  if importantSave then session.importantSavePending = true end
  warn(string.format("[PlayerData] SAVE FAILED %d (%s): %s",
   player.UserId, release and "leave/shutdown" or "autosave", tostring(record)))
  -- An autosave failure may recover next interval while the lease is still safe.
 end
 return false
end

-- Welcome Back's 3x offer, from the developer product's receipt (ProductServer): adds this
-- login's offline Training reward twice more (3x in all) through the normal grant path, with the
-- Ball that earned it, up to the offer's limit (the rest of the run the player had at login) and
-- never past the Level Cap now. Once per login. Returns Roblox's ProductPurchaseDecision:
--   PurchaseGranted  granted now (and saved straight away), or this receipt was already granted
--   NotProcessedYet  the player's data isn't ready, there is no offer to fill, or the player is
--                    already at the Level Cap (nothing to fill); Roblox retries the receipt later
--                    (such as at their next login with an offline reward)
function PlayerData.ClaimOfflineTriple(player, receipt)
 local decision = Enum.ProductPurchaseDecision
 if not PlayerData.IsReady(player) or not validReceipt(player, receipt) then return decision.NotProcessedYet end
 local session = sessions[player]
 if table.find(session.robux.receipts, receipt.PurchaseId) then return decision.PurchaseGranted end
 local offer = session.offlineTriple
 if not offer then return decision.NotProcessedYet end
 local limit = math.min(offer.limit, Progression.GetPowerToLevelCap(session.progression))
 if limit <= 0 then return decision.NotProcessedYet end
 local extra = offer.baseAmount * (Training.OfflineTriple.multiplier - 1)
 local granted, result = grantProgression(session.progression, extra, "OfflineTriple", offer.ballId, nil, limit)
 if not granted then return decision.NotProcessedYet end
 session.offlineTriple = nil
 player:SetAttribute("OfflineTriplePower", offer.power + result.powerGranted)
 player:SetAttribute("OfflineTripleAvailable", false)
 publishProgression(player, session.progression)
 PlayerData.RecordRobuxReceipt(player, receipt)
 -- Save now rather than at the next autosave, so a paid reward is on record before Roblox is
 -- told it was granted. (A failed save is retried by the autosave loop.)
 while session.saving do task.wait(0.1) end
 save(player, session, false)
 return decision.PurchaseGranted
end

-- A developer product's receipt (ProductServer, from MonetizationConfig): grants the reward the
-- server's config names for that product, once per receipt (its PurchaseId joins the saved
-- receipt list that RobuxSpent uses), never a client value. reward is one of:
--   {power = n}       exactly n Power (no Ball, Rebirth or juice multiplier) through the normal
--                     Level path, so Level-ups, the Level Cap (it banks there) and the tutorial follow
--   {cashPack = id, cashHits = n}  a Cash pack: the Cash fixed for that pack when the player asked to
--                     buy it (QuoteCashPack), so a delayed or retried receipt pays the same; only with
--                     no quote, n normal hits for the player now (MonetizationConfig.GetCashPackReward)
--   {juices = {id = count}}  juices added to the Inventory (not started)
-- Returns Roblox's ProductPurchaseDecision, and what was granted when this call granted it
-- ({power}, {cash} or {juices}):
--   PurchaseGranted  granted now (and saved straight away), or this receipt was already granted
--   NotProcessedYet  the player's data isn't ready, or the reward is invalid (Roblox retries)
function PlayerData.ClaimProduct(player, receipt, reward)
 local decision = Enum.ProductPurchaseDecision
 if not PlayerData.IsReady(player) or not validReceipt(player, receipt) or type(reward) ~= "table" then
  return decision.NotProcessedYet
 end
 local power, hits, juices = reward.power, reward.cashHits, reward.juices
 if (power ~= nil and not Progression.IsInteger(power, 1, Progression.MaxBaseGrant))
  or (hits ~= nil and not Progression.IsInteger(hits, 1, 100000))
  or (juices ~= nil and type(juices) ~= "table") or (power == nil and hits == nil and juices == nil) then
  return decision.NotProcessedYet
 end
 for id, count in juices or {} do
  if not Juice.Get(id) or not Progression.IsInteger(count, 1, Juice.MaxOwned) then return decision.NotProcessedYet end
 end
 local session = sessions[player]
 if table.find(session.robux.receipts, receipt.PurchaseId) then return decision.PurchaseGranted end
 local granted = {}
 if power then
  Progression.Advance(session.progression, power)
  publishProgression(player, session.progression)
  updateTutorial(player, session, "Power", power)
  granted.power = power
 end
 if hits then
  local cash = player.leaderstats.Cash
  local amount = type(reward.cashPack) == "string" and session.cashQuotes[reward.cashPack]
   or Monetization.GetCashPackReward({hits = hits}, session.progression.Level,
   player:GetAttribute("CurrentWorldId"), player:GetAttribute("EquippedBat"))
  amount = math.min(amount, MAX_CASH - cash.Value)
  cash.Value += amount
  granted.cash = amount
 end
 if juices then
  -- Added up to the most a player can hold of each.
  for id, count in juices do
   session.juices.owned[id] = math.min(Juice.MaxOwned, (session.juices.owned[id] or 0) + count)
  end
  publishJuices(player, session)
  granted.juices = table.clone(juices)
 end
 PlayerData.RecordRobuxReceipt(player, receipt)
 -- Save now, as for the 3x, so a paid reward is on record before Roblox is told it was granted.
 while session.saving do task.wait(0.1) end
 save(player, session, false)
 return decision.PurchaseGranted, granted
end

-- Fixes what a Cash pack pays before its purchase prompt opens (ProductServer): its hits x one
-- normal hit for the player now (their Level, current World and equipped Bat, all server state).
-- Saved with the player, so a receipt that arrives late, is retried or comes after a rejoin pays
-- this same amount; asking again (the next Buy) replaces it. Returns the amount, or nil.
function PlayerData.QuoteCashPack(player, productId)
 local product = Monetization.GetCashProductById(productId)
 if not product or not PlayerData.IsReady(player) then return nil end
 local session = sessions[player]
 local amount = Monetization.GetCashPackReward(product, session.progression.Level,
  player:GetAttribute("CurrentWorldId"), player:GetAttribute("EquippedBat"))
 session.cashQuotes[product.id] = math.min(MAX_CASH, amount)
 scheduleImportantSave(session)
 return session.cashQuotes[product.id]
end

-- A Power product's receipt (MonetizationConfig.PowerProducts): exactly powerAmount Power.
-- Returns the decision and the Power added when this call added it.
function PlayerData.ClaimPowerProduct(player, receipt, powerAmount)
 local decision, granted = PlayerData.ClaimProduct(player, receipt, {power = powerAmount})
 return decision, granted and granted.power
end

-- Starter Pack ------------------------------------------------------------------------
-- A game pass (MonetizationConfig.StarterPack). Roblox's ownership record is checked at login and
-- on purchase, like the other passes; its rewards are given once ever, recorded in the saved
-- StarterPackGranted. In Studio only, on a StudioFreshSave throwaway record, the Workspace
-- attribute StudioOwnStarterPack owns it (to test the grant). StarterPackOwned is the display copy.
local starterPackListener
function PlayerData.OnStarterPackGranted(callback)
 starterPackListener = callback
end

local function fetchStarterPack(player, session)
 if session.fresh and RunService:IsStudio() and workspace:GetAttribute("StudioOwnStarterPack") == true then return true end
 local passId = Monetization.StarterPack.gamePassId
 if passId <= 0 then return false end
 local ok, owned = pcall(Marketplace.UserOwnsGamePassAsync, Marketplace, player.UserId, passId)
 return ok and owned == true
end

-- The pack's rewards into a loaded session (no checks, no save), shared by the pass and by a
-- gifted Starter Pack: the Catastrophe Bat, a Power Punch, a bonus Rebirth (Rebirths and the
-- Level Cap rise; Level, Power and everything else stay, and banked Power then levels up; it is
-- not the tutorial's Rebirth), then its Power through the normal Level path. The flag is set
-- first, so nothing can give it twice.
local function giveStarterPack(player, session)
 local pack = Monetization.StarterPack
 session.starterPack.granted = true
 local bat = Equipment.Get("Bat", pack.batId)
 if bat then
  session.owned.Bat[bat.id] = true
  session.studioOwned.Bat[bat.id] = nil
  local folder = player:FindFirstChild(Equipment.Categories.Bat.ownedField)
  if folder then folder:SetAttribute(bat.id, true) end
 end
 for id, count in pack.juices do
  session.juices.owned[id] = math.min(Juice.MaxOwned, (session.juices.owned[id] or 0) + count)
 end
 publishJuices(player, session)
 local state = session.progression
 state.Rebirths = math.min(Progression.MaxRebirths, state.Rebirths + pack.rebirths)
 state.LevelCap = Progression.GetLevelCap(state.Rebirths)
 Progression.Advance(state, 0)
 Progression.Advance(state, pack.power)
 publishProgression(player, state)
 updateTutorial(player, session, "Power", pack.power)
 player:SetAttribute("StarterPackOwned", true)
end

-- Gives the pack to a player who owns the pass and has not had it, then saves at once.
local function grantStarterPack(player, session)
 if not session.starterPack.owned or session.starterPack.granted or not PlayerData.IsReady(player) then return end
 giveStarterPack(player, session)
 if starterPackListener then task.spawn(starterPackListener, player) end
 -- Saved now (this yields), as for the developer products, so the paid rewards are on record.
 while session.saving do task.wait(0.1) end
 if sessions[player] == session then save(player, session, false) end
end

-- Re-checks Roblox (e.g. bought on the website mid-session) and grants the pack if owned. Yields.
function PlayerData.RefreshStarterPack(player)
 if not PlayerData.IsReady(player) then return end
 local session = sessions[player]
 if not session.starterPack.owned and fetchStarterPack(player, session) then session.starterPack.owned = true end
 grantStarterPack(player, session)
end

-- Gifts ---------------------------------------------------------------------------------
-- A player buys a Shop item for another player in the server (MonetizationConfig.GiftProducts,
-- always developer products):
--  1. PrepareGift, before the prompt: checks both players and the item, fixes a Cash pack's
--     amount from the RECIPIENT's progression, and saves the intent (who receives it, where their
--     save is) in the buyer's PendingGifts. No prompt opens unless that save is written.
--  2. The buyer's receipt (ClaimGift): queues the gift in the recipient's saved GiftInbox (an
--     UpdateAsync on their record, so it works whether they are here, offline or in another
--     server), keyed by the receipt's PurchaseId; only then is the receipt recorded and granted.
--  3. The recipient's session applies queued gifts (applyGiftEntries): straight away when they
--     are here, at their next login, or after an autosave finds ones queued from another server.
--     Each gift's id joins ReceivedGifts in the same save as its reward, so it applies once.
-- A gifted Training Ground is a saved entitlement (GiftedEntitlements) that opens the same
-- grounds as its pass (it joins session.trainingPasses), so every check and OWNED label treats
-- it like the pass.
local giftListener
-- callback(kind, player, info): "Received" for the recipient ({gift, entry}), "Sent" for the
-- buyer ({gift, recipientName}).
function PlayerData.OnGift(callback)
 giftListener = callback
end

local function hasGiftItem(session, gift)
 if gift.item.starterPack then return session.starterPack.owned or session.starterPack.granted end
 if gift.item.entitlement then
  return session.trainingPasses[Monetization.GiftEntitlements[gift.item.entitlement]] == true
 end
 return false
end

applyGiftEntries = function(player, session, entries)
 if sessions[player] ~= session or not PlayerData.IsReady(player) then return end
 local applied = {}
 for _, entry in entries do
  local gift = Monetization.GetGiftById(entry.gift)
  if gift and not table.find(session.gifts.received, entry.id) then
   table.insert(session.gifts.received, entry.id)
   while #session.gifts.received > MAX_RECEIVED_GIFTS do table.remove(session.gifts.received, 1) end
   local item = gift.item
   if item.starterPack then
    -- (Never twice: the gift was refused if they had it, and is spent if they got it since.)
    if not session.starterPack.granted then giveStarterPack(player, session) end
   elseif item.cashPack then
    local cash = player.leaderstats.Cash
    cash.Value += math.min(entry.amount or 0, MAX_CASH - cash.Value)
   elseif item.juiceProduct then
    for id, count in Monetization.GetJuiceProductById(item.juiceProduct).juices do
     session.juices.owned[id] = math.min(Juice.MaxOwned, (session.juices.owned[id] or 0) + count)
    end
    publishJuices(player, session)
   elseif item.entitlement then
    session.gifts.entitlements[item.entitlement] = true
    session.trainingPasses[Monetization.GiftEntitlements[item.entitlement]] = true
    publishTrainingPasses(player, session)
   end
   table.insert(applied, {gift = gift, entry = entry})
  end
 end
 if #applied == 0 then return end
 while session.saving do task.wait(0.1) end
 save(player, session, false)
 if giftListener then
  for _, info in applied do task.spawn(giftListener, "Received", player, info) end
 end
end

-- Step 1. Returns true when the prompt may open, or false and a message for the buyer.
function PlayerData.PrepareGift(buyer, giftId, recipient)
 local gift = Monetization.GetGiftById(giftId)
 if not gift then return false, "That can't be gifted." end
 if gift.developerProductId <= 0 then return false, "Gifting the " .. gift.displayName .. " is coming soon!" end
 if not PlayerData.IsReady(buyer) then return false, "Your data is not ready. Please wait." end
 -- (recipient comes from Players:GetPlayerByUserId, so it is a Player or nil.)
 if not recipient or recipient.Parent ~= Players then return false, "That player is no longer in this server." end
 if recipient == buyer then return false, "You can't send a gift to yourself." end
 if not PlayerData.IsReady(recipient) then return false, "That player is still loading. Try again soon." end
 local session, target = sessions[buyer], sessions[recipient]
 if hasGiftItem(target, gift) then return false, "THIS PLAYER ALREADY OWNS THE " .. string.upper(gift.displayName) end
 local existing = session.gifts.pending[gift.id]
 if existing and existing.state == "purchased" then
  return false, "Your last " .. gift.displayName .. " gift is still on its way. Try again shortly."
 end
 local amount
 if gift.item.cashPack then
  amount = math.min(MAX_CASH, Monetization.GetCashPackReward(Monetization.GetCashProductById(gift.item.cashPack),
   target.progression.Level, recipient:GetAttribute("CurrentWorldId"), recipient:GetAttribute("EquippedBat")))
 end
 session.gifts.pending[gift.id] = {recipient = recipient.UserId, recipientName = recipient.DisplayName,
  store = target.storeName or STORE_NAME, key = target.key, amount = amount, at = os.time(), state = "prompted"}
 while session.saving do task.wait(0.1) end
 if not save(buyer, session, false) then
  session.gifts.pending[gift.id] = existing
  return false, "The gift couldn't be started. Please try again."
 end
 return true
end

-- Roblox's prompt result for a gift product (the server's PromptProductPurchaseFinished): a
-- cancelled prompt drops the intent; a bought one keeps it until its receipt is processed.
function PlayerData.GiftPromptFinished(buyer, gift, purchased)
 local session = sessions[buyer]
 local intent = session and session.loaded and session.gifts.pending[gift.id]
 if not intent then return end
 if purchased then
  intent.state = "purchased"
 elseif intent.state ~= "purchased" then
  session.gifts.pending[gift.id] = nil
 end
 scheduleImportantSave(session)
end

-- Adds a gift to the recipient's saved queue unless it is already queued or applied there.
-- Returns whether the gift is now safely on their record.
local function queueGift(intent, entry)
 local found = false
 local ok = update({storeName = intent.store, key = intent.key}, function(current)
  found = false
  if typeof(current) ~= "table" then return nil end
  found = true
  local inbox = typeof(current.GiftInbox) == "table" and current.GiftInbox or {}
  if typeof(current.ReceivedGifts) == "table" and table.find(current.ReceivedGifts, entry.id) then return nil end
  for _, queued in inbox do
   if typeof(queued) == "table" and queued.id == entry.id then return nil end
  end
  local updated = table.clone(current)
  updated.GiftInbox = table.clone(inbox)
  table.insert(updated.GiftInbox, entry)
  return updated
 end, os.clock() + REQUEST_SECONDS)
 return ok and found
end

-- Step 2: a gift product's receipt. Returns Roblox's decision, and the intent when this call
-- delivered it:
--   PurchaseGranted  queued for the recipient (and given at once if they are here), or this
--                    receipt was already handled
--   NotProcessedYet  the buyer's data isn't ready, no intent was saved for it, or the
--                    recipient's record couldn't be written (Roblox retries)
function PlayerData.ClaimGift(buyer, receipt, gift)
 local decision = Enum.ProductPurchaseDecision
 if not PlayerData.IsReady(buyer) or not validReceipt(buyer, receipt) or not gift then return decision.NotProcessedYet end
 local session = sessions[buyer]
 if table.find(session.robux.receipts, receipt.PurchaseId) then return decision.PurchaseGranted end
 local intent = session.gifts.pending[gift.id]
 if not intent then
  warn("[PlayerData] gift receipt " .. receipt.PurchaseId .. " for " .. gift.id .. " has no saved recipient; left for Roblox to retry")
  return decision.NotProcessedYet
 end
 local entry = {id = receipt.PurchaseId, gift = gift.id, amount = intent.amount, from = buyer.UserId,
  fromName = buyer.DisplayName}
 if not queueGift(intent, entry) then return decision.NotProcessedYet end
 local recipient = Players:GetPlayerByUserId(intent.recipient)
 local target = recipient and sessions[recipient]
 if target and target.key == intent.key then applyGiftEntries(recipient, target, {entry}) end
 if session.gifts.pending[gift.id] == intent then session.gifts.pending[gift.id] = nil end
 PlayerData.RecordRobuxReceipt(buyer, receipt)
 while session.saving do task.wait(0.1) end
 save(buyer, session, false)
 if giftListener then task.spawn(giftListener, "Sent", buyer, {gift = gift, recipientName = intent.recipientName}) end
 return decision.PurchaseGranted, intent
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
 -- In Studio only, the Workspace attribute StudioFreshSave plays as a brand-new player (to
 -- test the tutorial): a throwaway record in a Studio-only store, so the real save and the
 -- leaderboards are never touched, and the OwnAllBalls / UnlockAllWorlds playtest grants are skipped.
 if RunService:IsStudio() and workspace:GetAttribute("StudioFreshSave") == true then
  session.fresh, session.storeName = true, "Studio_FreshPlayers"
  session.key = "Fresh_" .. player.UserId .. "_" .. os.time()
 end
 sessions[player] = session
 player:SetAttribute("DataLoaded", false)
 player:SetAttribute("DataLoadState", "Loading")
 local rejection, repairs
 local newRecord = false
 local offlineResult, offlineSeconds, offlineGround, offlineBase, offlineBall, offlineTripleExtra
 -- Pass ownership is needed before the atomic login: offline Training uses the best
 -- ground the player can use, including paid ones.
 local passes = fetchTrainingPasses(player)
 local autoBat = fetchAutoBat(player)
 local starterPackOwned = fetchStarterPack(player, session)
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
  -- Offline Training only starts once the tutorial is complete: time away mid-tutorial earns
  -- nothing (and shows no Welcome Back screen), though its logout time is still used up below.
  if not owns(current, session) and Tutorial.IsComplete(Tutorial.FromSave(data, false)) then
   offlineGround = Training.GetBestGround(data.Rebirths, withGifted(passes, data.GiftedEntitlements), data.UnlockedWorlds).id
   local progression = Progression.Normalize(data, false)
   -- Offline Training uses the Training base (the same at every Level) at the best ground, and fills at
   -- most part of the Power still needed for the Level Cap (TrainingConfig.OfflineRunShare).
   local baseAmount, seconds = Training.GetOfflineReward(data.LastLogoutTime, os.time(), offlineGround,
    Progression.TrainingBase)
   local remaining = Progression.GetPowerToLevelCap(progression)
   local granted, result = grantProgression(progression, baseAmount, "OfflineTraining", data.EquippedBall, nil,
    Training.GetOfflinePowerLimit(remaining))
   if not granted then rejection = "invalid offline reward configuration" return nil end
   for field, value in progression do data[field] = value end
   offlineResult, offlineSeconds = result, seconds
   offlineBase, offlineBall = baseAmount, data.EquippedBall
   offlineTripleExtra = Training.GetOfflineTripleExtra(result.powerGranted, remaining)
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
 -- Training Ground access: Roblox's passes, or the same grounds' gifted entitlements.
 session.trainingPasses = withGifted(passes, record.GiftedEntitlements)
 session.gifts = {entitlements = table.clone(record.GiftedEntitlements), received = table.clone(record.ReceivedGifts), pending = {}}
 for id, intent in record.PendingGifts do session.gifts.pending[id] = table.clone(intent) end
 publishTrainingPasses(player, session)
 -- Auto Bat always starts off; an owner turns it on (ProductServer).
 session.autoBat = autoBat
 player:SetAttribute("AutoBatOwned", autoBat)
 player:SetAttribute("AutoBatEnabled", false)
 session.juices = {owned = table.clone(record.OwnedJuices), active = table.clone(record.ActiveJuices)}
 -- In Studio only, on a StudioFreshSave throwaway record, the Workspace attribute
 -- StudioGrantJuice gives that many of every juice (juices have no other source yet). Real saves
 -- and live servers never get them.
 local studioJuice = session.fresh and RunService:IsStudio() and workspace:GetAttribute("StudioGrantJuice")
 if type(studioJuice) == "number" and studioJuice >= 1 then
  for _, definition in Juice.GetAll() do
   session.juices.owned[definition.id] = math.min(Juice.MaxOwned, math.floor(studioJuice))
  end
 end
 publishJuices(player, session)
 session.timePlayed, session.playClock = record.TimePlayed, os.clock()
 session.robux = {spent = record.RobuxSpent, passes = table.clone(record.RobuxPurchases.Passes),
  receipts = table.clone(record.RobuxPurchases.Receipts)}
 session.starterPack = {owned = starterPackOwned, granted = record.StarterPackGranted}
 session.cashQuotes = table.clone(record.CashPackQuotes)
 player:SetAttribute("StarterPackOwned", starterPackOwned or record.StarterPackGranted)
 local offlinePower = offlineResult and offlineResult.powerGranted or 0
 player:SetAttribute("OfflinePowerEarned", offlinePower)
 player:SetAttribute("OfflineSeconds", offlineSeconds or 0)
 player:SetAttribute("OfflineTrainingGround",
  offlineGround or Training.GetBestGround(session.progression.Rebirths, session.trainingPasses, record.UnlockedWorlds).id)
 player:SetAttribute("OfflineOldLevel", offlineResult and offlineResult.oldLevel or session.progression.Level)
 player:SetAttribute("OfflineNewLevel", offlineResult and offlineResult.newLevel or session.progression.Level)
 -- Welcome Back's 3x offer (ClaimOfflineTriple): this login's offline reward, for adding it
 -- twice more, up to limit (the rest of the run at login). Offered whenever there was a reward
 -- (at the Level Cap there is none). OfflineTriplePower is the total with the 3x, for its button.
 local tripleEligible = offlinePower > 0 and offlineTripleExtra ~= nil and offlineTripleExtra > 0
 session.offlineTriple = tripleEligible and {baseAmount = offlineBase, ballId = offlineBall,
  limit = offlineTripleExtra, power = offlinePower} or nil
 player:SetAttribute("OfflineTriplePower", offlinePower + (tripleEligible and offlineTripleExtra or 0))
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
 -- grants last for the session and are never saved (snapshot skips them). Never on a
 -- StudioFreshSave run (a real new player) or while a save's tutorial is running: its Ball step
 -- is buying the first Ball in order, which owning the rest would make impossible.
 local tutorialRunning = not Tutorial.IsComplete(Tutorial.FromSave(record, false))
 local grantAllBalls = RunService:IsStudio() and workspace:GetAttribute("OwnAllBalls") == true and not session.fresh
  and not tutorialRunning
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
 if RunService:IsStudio() and workspace:GetAttribute("UnlockAllWorlds") == true and not session.fresh then
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
 -- Resume the tutorial where the save left it, moving past anything already done.
 session.tutorial = Tutorial.FromSave(record, false)
 updateTutorial(player, session)
 publishTutorial(player, session)
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
  -- An owned Starter Pack whose rewards were never given (bought elsewhere, or a save that
  -- failed before) is given now, then any gifts queued while the player was away.
  grantStarterPack(player, session)
  applyGiftEntries(player, session, record.GiftInbox)
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
  if Monetization.AutoBat.gamePassId > 0 and gamePassId == Monetization.AutoBat.gamePassId then
   session.autoBat = true
   player:SetAttribute("AutoBatOwned", true)
  end
  if Monetization.StarterPack.gamePassId > 0 and gamePassId == Monetization.StarterPack.gamePassId then
   session.starterPack.owned = true
   grantStarterPack(player, session)
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
 -- Juices end on their own when their expiry time passes (checked once per second).
 task.spawn(function()
  while not shuttingDown do
   task.wait(1)
   PlayerData.ExpireJuices(os.time())
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
