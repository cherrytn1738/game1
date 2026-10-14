-- Juice: consumable items that grant temporary, server-timed bonuses.
-- No juices are defined yet. To add one, append a definition to DEFINITIONS, e.g.:
--   {id = "power_juice", displayName = "Power Juice", effect = "Power", multiplier = 2,
--    durationSeconds = 3600, color = Color3.fromRGB(80, 200, 255)}
-- IDs are persisted in player saves, so never rename or reuse one.
local Juice = {
 -- Effects a juice can apply. Each multiplies the matching gain while the juice is active.
 Effects = {
  Power = {displayName = "Power", description = "Power gain"},
  Cash = {displayName = "Cash", description = "Cash earned"},
 },
 MaxOwned = 999, -- per juice
 MaxActiveSeconds = 24 * 60 * 60, -- stacking cap per active juice
}

local DEFINITIONS = {}

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

-- Normalizes saved juice data. Returns nil for a malformed (non-table) field so the
-- caller can fail closed; unknown juices and invalid entries are dropped.
function Juice.Sanitize(owned, active)
 if (owned ~= nil and type(owned) ~= "table") or (active ~= nil and type(active) ~= "table") then return nil end
 local cleanOwned, cleanActive = {}, {}
 for id, count in owned or {} do
  if Juice.Get(id) and validInteger(count, 1, Juice.MaxOwned) then cleanOwned[id] = count end
 end
 for id, seconds in active or {} do
  if Juice.Get(id) and validInteger(seconds, 1, Juice.MaxActiveSeconds) then cleanActive[id] = seconds end
 end
 return cleanOwned, cleanActive
end

-- Combined multiplier for one effect from a table of active juices (id -> seconds left).
function Juice.GetMultiplier(active, effect)
 local multiplier = 1
 for id, seconds in active do
  local definition = Juice.Get(id)
  if definition and definition.effect == effect and seconds > 0 then multiplier *= definition.multiplier end
 end
 return multiplier
end

return Juice
