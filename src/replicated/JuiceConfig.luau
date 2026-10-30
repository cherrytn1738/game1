-- Juice: consumable drinks that grant temporary, server-timed bonuses (owned counts in
-- OwnedJuices, running timers in ActiveJuices). IDs are persisted in player saves, so never
-- rename or reuse one.
--
-- A drunk juice runs on real time, also while the player is offline: ActiveJuices stores the Unix
-- time (os.time) it expires at. Drinking one that is already running adds its duration (the
-- multiplier never stacks). Power juices apply to online Power (Training and batting, not offline
-- Training); Cash juices to batting Cash.
local Juice = {
 -- Effects a juice can apply. Each multiplies the matching gain while the juice is active.
 Effects = {
  Power = {displayName = "Power", description = "Power gain"},
  Cash = {displayName = "Cash", description = "Cash earned"},
 },
 MaxOwned = 999, -- per juice
 MaxActiveSeconds = 24 * 60 * 60, -- stacking cap per active juice
}

-- appearance: the juice box's colours (JuiceModels): body, roof (the folded carton top), bands,
-- label (the front panel), straw, accent (a small Neon trim, or nil), and its front icon.
local DEFINITIONS = {
 {id = "power_punch", displayName = "Power Punch", effect = "Power", multiplier = 2, durationSeconds = 600,
  color = Color3.fromRGB(110, 80, 255), appearance = {
   body = Color3.fromRGB(62, 70, 225), roof = Color3.fromRGB(136, 66, 240), bands = Color3.fromRGB(150, 90, 255),
   label = Color3.fromRGB(245, 245, 255), straw = Color3.fromRGB(255, 214, 40), accent = Color3.fromRGB(80, 235, 255),
   icon = "Power"}},
 {id = "cash_splash", displayName = "Cash Splash", effect = "Cash", multiplier = 2, durationSeconds = 600,
  color = Color3.fromRGB(60, 200, 80), appearance = {
   body = Color3.fromRGB(40, 176, 72), roof = Color3.fromRGB(120, 222, 90), bands = Color3.fromRGB(255, 200, 40),
   label = Color3.fromRGB(255, 250, 220), straw = Color3.fromRGB(255, 255, 255), splash = Color3.fromRGB(150, 240, 120),
   icon = "Cash"}},
}

local byId, ordered = {}, {}

-- Validates and registers a definition (also usable by tests to add fixtures).
function Juice.Define(definition)
 assert(type(definition.id) == "string" and #definition.id > 0 and #definition.id <= 64 and not byId[definition.id],
  "Invalid or repeated juice ID")
 assert(type(definition.displayName) == "string", "Juice needs a displayName: " .. definition.id)
 assert(Juice.Effects[definition.effect], "Unknown juice effect: " .. tostring(definition.effect))
 assert(type(definition.multiplier) == "number" and definition.multiplier >= 1 and definition.multiplier < math.huge,
  "Invalid juice multiplier: " .. definition.id)
 assert(type(definition.durationSeconds) == "number" and definition.durationSeconds % 1 == 0
  and definition.durationSeconds > 0 and definition.durationSeconds <= Juice.MaxActiveSeconds,
  "Invalid juice duration: " .. definition.id)
 definition.order = #ordered + 1
 byId[definition.id] = definition
 table.insert(ordered, definition)
 return definition
end

for _, definition in DEFINITIONS do Juice.Define(definition) end

function Juice.Get(id)
 return type(id) == "string" and byId[id] or nil
end

function Juice.GetAll()
 return ordered
end

local function validInteger(value, minimum, maximum)
 return type(value) == "number" and value == value and value % 1 == 0 and value >= minimum and value <= maximum
end

-- Normalizes saved juice data at Unix time now. Returns nil for a malformed (non-table) field so
-- the caller can fail closed; unknown juices, invalid entries and expired timers are dropped.
-- A running juice is its expiry time; a small value (at most MaxActiveSeconds) is a save from
-- before timers ran on real time, holding the seconds that were left, and starts again from now.
function Juice.Sanitize(owned, active, now)
 if (owned ~= nil and type(owned) ~= "table") or (active ~= nil and type(active) ~= "table") then return nil end
 local cleanOwned, cleanActive = {}, {}
 for id, count in owned or {} do
  if Juice.Get(id) and validInteger(count, 1, Juice.MaxOwned) then cleanOwned[id] = count end
 end
 for id, value in active or {} do
  if Juice.Get(id) and validInteger(value, 1, now + Juice.MaxActiveSeconds) then
   local expiresAt = value <= Juice.MaxActiveSeconds and now + value or value
   if expiresAt > now then cleanActive[id] = expiresAt end
  end
 end
 return cleanOwned, cleanActive
end

-- Seconds left on a running juice (id -> expiry time) at time now; 0 when it has ended.
function Juice.GetRemaining(expiresAt, now)
 return type(expiresAt) == "number" and math.max(0, expiresAt - now) or 0
end

-- Combined multiplier for one effect from a table of active juices (id -> expiry time) at time
-- now. Each juice counts once, however long it has left.
function Juice.GetMultiplier(active, effect, now)
 local multiplier = 1
 for id, expiresAt in active do
  local definition = Juice.Get(id)
  if definition and definition.effect == effect and Juice.GetRemaining(expiresAt, now) > 0 then
   multiplier *= definition.multiplier
  end
 end
 return multiplier
end

return Juice
