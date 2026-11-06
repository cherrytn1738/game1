-- Global leaderboards: four physical boards in every World's hub (WorldConfig hub.leaderboards),
-- styled to the World, showing the top players across every server by current Level, time
-- played, Robux spent in this experience, and current Cash. Every hub shows the same rankings:
-- each refresh reads each store once and fills every board.
--
-- PlayerData's save stays the source of truth. Each board reads an OrderedDataStore that mirrors
-- one saved value (key: the player's UserId). The mirrors are written from PlayerData's
-- successful saves (Submit), at most once every WRITE_SECONDS per player while they play and once
-- more when they leave, and only for values that changed. Every server re-reads the four stores
-- every REFRESH_SECONDS. Names come from players in the server, or a cached
-- GetNameFromUserIdAsync lookup. A failed write, read or lookup is retried later and never
-- touches gameplay or saves.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local WorldUI = require(game:GetService("ReplicatedStorage"):WaitForChild("WorldUIConfig"))

local Leaderboards = {}

Leaderboards.Entries = 10 -- rows per board
local WRITE_SECONDS = 120 -- the most often one player's values are written while they play
local FLUSH_SECONDS = 10 -- how often pending writes are checked
local REFRESH_SECONDS = 60
local MAX_WRITE_ATTEMPTS = 5 -- a player who has left is dropped after this many failed writes
local SHUTDOWN_MIN_SECONDS, SHUTDOWN_MAX_SECONDS = 6, 20 -- final writes while the server closes
local NAME_RETRY_SECONDS = 300 -- a failed name lookup waits this long before trying again
local NAME_LOOKUPS_PER_REFRESH = 10
local MAX_VALUE = 9000000000000000 -- below 2^53, so every value stays an exact integer

-- stat: the saved PlayerData field each board mirrors. store is the live name; Studio adds a
-- "Studio_" prefix (StoreName). Changing a store name starts that board afresh (the old store
-- is left untouched).
Leaderboards.Stats = {
 Level = {title = "TOP LEVEL", store = "GlobalLeaderboard_Level_v1", color = Color3.fromRGB(96, 196, 255)},
 TimePlayed = {title = "TOP TIME PLAYED", store = "GlobalLeaderboard_TimePlayed_v1", color = Color3.fromRGB(200, 140, 255)},
 RobuxSpent = {title = "TOP ROBUX SPENT", store = "GlobalLeaderboard_RobuxSpent_v1", color = Color3.fromRGB(110, 230, 120)},
 Cash = {title = "TOP CASH", store = "GlobalLeaderboard_Cash_v1", color = Color3.fromRGB(255, 208, 60)},
}
Leaderboards.Order = {"Level", "TimePlayed", "RobuxSpent", "Cash"}

local function validValue(value)
 return type(value) == "number" and value == value and value >= 0 and value <= MAX_VALUE and value % 1 == 0
end

-- The leaderboard values in a saved PlayerData record ({[stat] = value}); anything missing or
-- malformed is left out, so it is never written.
function Leaderboards.Extract(data)
 local values = {}
 if type(data) ~= "table" then return values end
 for _, stat in Leaderboards.Order do
  if validValue(data[stat]) then values[stat] = data[stat] end
 end
 return values
end

-- ---------- formatting ----------

-- Whole numbers with commas below 10,000, then 12.3K / 4.5M / 1.2B / 3T.
function Leaderboards.FormatNumber(value)
 if value < 10000 then
  local text = tostring(math.floor(value))
  return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
 end
 for _, unit in {{1e15, "Qd"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}} do
  if value >= unit[1] then
   return (string.format("%.1f", math.floor(value / unit[1] * 10) / 10):gsub("%.0$", "")) .. unit[2]
  end
 end
 return tostring(value)
end

-- 45m, 2h 14m, 18h 42m, 3d 7h (whole minutes, never raw seconds).
function Leaderboards.FormatDuration(seconds)
 local minutes = math.floor(seconds / 60)
 if minutes < 60 then return minutes .. "m" end
 local hours = minutes // 60
 if hours < 24 then return string.format("%dh %dm", hours, minutes % 60) end
 return string.format("%dd %dh", hours // 24, hours % 24)
end

function Leaderboards.FormatValue(stat, value)
 if stat == "TimePlayed" then return Leaderboards.FormatDuration(value) end
 if stat == "RobuxSpent" then return "R$ " .. Leaderboards.FormatNumber(value) end
 if stat == "Cash" then return "$" .. Leaderboards.FormatNumber(value) end
 return Leaderboards.FormatNumber(value)
end

-- ---------- writing the mirrors ----------

-- Studio playtests read and write their own copies of the stores, so test accounts and test
-- values never reach the live rankings. Player saves are not separated (PlayerData).
local STORE_PREFIX = RunService:IsStudio() and "Studio_" or ""

-- The OrderedDataStore a board mirrors in this server (live or Studio).
function Leaderboards.StoreName(stat)
 return STORE_PREFIX .. Leaderboards.Stats[stat].store
end

local stores = {}
local function store(stat)
 stores[stat] = stores[stat] or DataStoreService:GetOrderedDataStore(Leaderboards.StoreName(stat))
 return stores[stat]
end

-- pending[userId] = {values, final, attempts}: the latest saved values not yet written.
-- written[userId] = {values, at}: what each store holds for a player still in this server.
local pending, written = {}, {}

-- Called by PlayerData after each successful save (PlayerData.OnSaved); final is the save made
-- as the player leaves. Only records the values: Flush writes them.
function Leaderboards.Submit(userId, data, final)
 if type(userId) ~= "number" or userId <= 0 or userId % 1 ~= 0 then return end
 local previous = pending[userId]
 pending[userId] = {values = Leaderboards.Extract(data), final = final == true or (previous ~= nil and previous.final),
  attempts = previous and previous.attempts or 0}
end

local function writeBudget()
 local ok, budget = pcall(DataStoreService.GetRequestBudgetForRequestType, DataStoreService,
  Enum.DataStoreRequestType.SetIncrementSortedAsync)
 return not ok or budget > 0
end

-- Writes one player's changed values. A failed write stays pending and is retried on a later
-- flush; a player who has left is given up on after MAX_WRITE_ATTEMPTS.
local function writePlayer(userId, entry, now)
 local last = written[userId]
 local done = last and table.clone(last.values) or {}
 local failed = false
 for stat, value in entry.values do
  if done[stat] ~= value then
   if not writeBudget() then failed = true break end
   local ok = pcall(function() store(stat):SetAsync(tostring(userId), value) end)
   if ok then done[stat] = value else failed = true end
  end
 end
 -- A newer save may have replaced the entry while the writes yielded; that one stays pending.
 if pending[userId] == entry then
  if failed then entry.attempts += 1 end
  if not failed or (entry.final and entry.attempts >= MAX_WRITE_ATTEMPTS) then pending[userId] = nil end
 end
 -- A player who has left is forgotten once written; one still here keeps what was written, so
 -- the next save writes only what changed. A failure leaves the player due again next flush.
 if entry.final and pending[userId] == nil then
  written[userId] = nil
 else
  written[userId] = {values = done, at = failed and (last and last.at or now - WRITE_SECONDS) or now}
 end
end

-- Writes every player that is due: one not written yet, one last written WRITE_SECONDS ago,
-- or one who has left. Yields; one flush runs at a time.
local flushing = false
function Leaderboards.Flush()
 if flushing then return end
 flushing = true
 local now = os.clock()
 -- A list first, since saves can submit more while the writes yield.
 local due = {}
 for userId, entry in pending do
  local last = written[userId]
  if entry.final or not last or now - last.at >= WRITE_SECONDS then table.insert(due, {userId, entry}) end
 end
 local ok, problem = pcall(function()
  for _, item in due do writePlayer(item[1], item[2], now) end
 end)
 flushing = false
 if not ok then error(problem, 0) end
end

function Leaderboards.HasPending()
 return next(pending) ~= nil
end

-- ---------- reading the boards ----------

local names = {} -- [userId] = {name = string} or {failedAt = os.clock()}

-- A player's name for the boards: from the server when they are in it, otherwise a cached
-- lookup. allowLookup permits one web lookup (bounded per refresh). Returns the name (nil when
-- unknown) and whether a lookup was made.
function Leaderboards.GetName(userId, allowLookup)
 local player = Players:GetPlayerByUserId(userId)
 if player then
  names[userId] = {name = player.Name}
  return player.Name, false
 end
 local cached = names[userId]
 if cached and cached.name then return cached.name, false end
 if not allowLookup or (cached and os.clock() - cached.failedAt < NAME_RETRY_SECONDS) then return nil, false end
 local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
 if ok and type(name) == "string" and #name > 0 then
  names[userId] = {name = name}
  return name, true
 end
 names[userId] = {failedAt = os.clock()}
 return nil, true
end

-- The top entries of one board, best first ({rank, userId, value}), or nil and the error.
function Leaderboards.Fetch(stat)
 local ok, page = pcall(function()
  return store(stat):GetSortedAsync(false, Leaderboards.Entries):GetCurrentPage()
 end)
 if not ok or type(page) ~= "table" then return nil, tostring(page) end
 local entries = {}
 for _, item in page do
  local userId = tonumber(item.key)
  if userId and validValue(item.value) and #entries < Leaderboards.Entries then
   table.insert(entries, {rank = #entries + 1, userId = userId, value = item.value})
  end
 end
 return entries
end

-- ---------- the physical boards ----------

local BOARD_SIZE = Vector3.new(12, 15, 0.8)
local BOARD_BOTTOM = 3 -- height of the board's lower edge, on its posts
local PIXELS_PER_STUD = 32
-- Each World's board look (its hub theme; .vscode/ART_STYLE.md): the panel, its trim, the posts
-- and the text outline. Panels stay dark so the rows read clearly.
local rgb = Color3.fromRGB
local STYLES = {
 HomeField = {board = rgb(24, 58, 40), trim = rgb(255, 205, 50), post = rgb(120, 126, 134), ink = rgb(16, 30, 22)}, -- ballpark scoreboard
 TimeTravel = {board = rgb(44, 36, 70), trim = rgb(226, 176, 80), post = rgb(170, 122, 54), ink = rgb(22, 16, 36)}, -- ink and brass
 Future = {board = rgb(28, 34, 54), trim = rgb(90, 224, 255), post = rgb(198, 206, 220), ink = rgb(10, 14, 26)}, -- gunmetal and holo cyan
 TinyTown = {board = rgb(70, 44, 28), trim = rgb(255, 206, 44), post = rgb(150, 98, 58), ink = rgb(30, 18, 10)}, -- dark wood and toy yellow
}
local RANK_COLORS = {Color3.fromRGB(255, 214, 64), Color3.fromRGB(214, 222, 232), Color3.fromRGB(226, 150, 92)}
local FONT, FONT_BOLD = Enum.Font.GothamBlack, Enum.Font.GothamBold

local screens = {} -- [stat] = {{rows = {...}, status = TextLabel, hub = the hub it stands in}, ...}

local function part(parent, name, size, cframe, color, material)
 local p = Instance.new("Part")
 p.Name, p.Size, p.CFrame = name, size, cframe
 p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, true, false, true
 p.Material, p.Color = material or Enum.Material.SmoothPlastic, color
 p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
 p.Parent = parent
 return p
end

local function label(parent, name, text, font, size, color, position, frameSize, alignment, ink)
 local l = Instance.new("TextLabel")
 l.Name, l.Text, l.Font, l.TextSize, l.TextColor3 = name, text, font, size, color
 l.Position, l.Size, l.BackgroundTransparency = position, frameSize, 1
 l.TextXAlignment = alignment or Enum.TextXAlignment.Center
 l.TextTruncate = Enum.TextTruncate.AtEnd
 local stroke = Instance.new("UIStroke")
 stroke.Color, stroke.Thickness, stroke.Transparency = ink or STYLES.HomeField.ink, 2, 0.1
 stroke.Parent = l
 l.Parent = parent
 return l
end

-- One board: a dark panel in the World's style with a trim on two posts, its stat's colour on the
-- header bar and values, and Entries ranked rows on a SurfaceGui.
local function buildBoard(parent, hub, stat, cframe, style)
 local definition = Leaderboards.Stats[stat]
 local ink = style.ink
 local model = Instance.new("Model")
 model.Name = stat .. "Board"
 model:SetAttribute("Stat", stat)
 local centre = cframe * CFrame.new(0, BOARD_BOTTOM + BOARD_SIZE.Y / 2, 0)
 local board = part(model, "Board", BOARD_SIZE, centre, style.board)
 part(model, "Trim", BOARD_SIZE + Vector3.new(0.7, 0.7, -0.2), centre * CFrame.new(0, 0, 0.2), style.trim)
 part(model, "HeaderBar", Vector3.new(BOARD_SIZE.X + 1, 0.8, 1.2), centre * CFrame.new(0, BOARD_SIZE.Y / 2 + 0.6, 0.1), definition.color)
 for _, side in {-1, 1} do
  local x = side * (BOARD_SIZE.X / 2 - 1.6)
  part(model, "Post", Vector3.new(0.6, BOARD_BOTTOM + BOARD_SIZE.Y - 1, 0.6),
   cframe * CFrame.new(x, (BOARD_BOTTOM + BOARD_SIZE.Y - 1) / 2, 0.75), style.post, Enum.Material.Metal)
 end
 part(model, "Footing", Vector3.new(BOARD_SIZE.X - 1, 0.4, 2.4), cframe * CFrame.new(0, 0.2, 0.5), style.post, Enum.Material.Concrete)

 local gui = Instance.new("SurfaceGui")
 gui.Name, gui.Face = "Screen", Enum.NormalId.Front
 gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, PIXELS_PER_STUD
 gui.LightInfluence = 0
 gui.Parent = board
 local width, height = BOARD_SIZE.X * PIXELS_PER_STUD, BOARD_SIZE.Y * PIXELS_PER_STUD
 label(gui, "Title", definition.title, FONT, 40, definition.color, UDim2.fromOffset(0, 10), UDim2.new(1, 0, 0, 48), nil, ink)
 label(gui, "Subtitle", "GLOBAL  -  TOP " .. Leaderboards.Entries, FONT_BOLD, 18, Color3.fromRGB(220, 236, 224),
  UDim2.fromOffset(0, 58), UDim2.new(1, 0, 0, 22), nil, ink)
 local top, rowHeight = 92, math.floor((height - 92 - 40) / Leaderboards.Entries)
 local rows = {}
 for i = 1, Leaderboards.Entries do
  local row = Instance.new("Frame")
  row.Name, row.BorderSizePixel = "Row" .. i, 0
  row.Position, row.Size = UDim2.fromOffset(14, top + (i - 1) * rowHeight), UDim2.fromOffset(width - 28, rowHeight - 4)
  row.BackgroundColor3, row.BackgroundTransparency = Color3.new(1, 1, 1), i % 2 == 1 and 0.9 or 0.95
  local corner = Instance.new("UICorner")
  corner.CornerRadius = UDim.new(0, 6)
  corner.Parent = row
  row.Parent = gui
  local textSize = rowHeight - 12
  rows[i] = {
   rank = label(row, "Rank", "#" .. i, FONT, textSize, RANK_COLORS[i] or Color3.new(1, 1, 1),
    UDim2.fromOffset(6, 0), UDim2.new(0, 46, 1, 0), Enum.TextXAlignment.Left, ink),
   name = label(row, "PlayerName", "", FONT_BOLD, textSize, Color3.new(1, 1, 1),
    UDim2.fromOffset(54, 0), UDim2.new(1, -170, 1, 0), Enum.TextXAlignment.Left, ink),
   value = label(row, "Value", "", FONT, textSize, definition.color,
    UDim2.new(1, -116, 0, 0), UDim2.new(0, 110, 1, 0), Enum.TextXAlignment.Right, ink),
  }
 end
 local status = label(gui, "Status", "Loading...", FONT_BOLD, 16, Color3.fromRGB(200, 214, 204),
  UDim2.fromOffset(0, height - 34), UDim2.new(1, 0, 0, 24), nil, ink)
 screens[stat] = screens[stat] or {}
 table.insert(screens[stat], {rows = rows, status = status, hub = hub})
 WorldUI.Register(gui, "Leaderboard")
 model.Parent = parent
 return model
end

-- Builds hub.Leaderboards (rebuilt each time) from the hub's leaderboards config:
-- {facing = hub-frame point the boards turn toward, theme = a STYLES key (HomeField when
-- missing), boards = {{stat, position}, ...}}. Only this hub's old boards are dropped, so every
-- other hub's boards keep refreshing.
function Leaderboards.Build(hub, frame, config)
 local old = hub:FindFirstChild("Leaderboards")
 if old then old:Destroy() end
 for _, list in screens do
  for index = #list, 1, -1 do
   if list[index].hub == hub then table.remove(list, index) end
  end
 end
 local style = STYLES[config.theme] or STYLES.HomeField
 local folder = Instance.new("Folder")
 folder.Name = "Leaderboards"
 for _, entry in config.boards do
  assert(Leaderboards.Stats[entry.stat], "Unknown leaderboard stat " .. tostring(entry.stat))
  local facing = Vector3.new(config.facing.X, entry.position.Y, config.facing.Z)
  buildBoard(folder, hub, entry.stat, frame * CFrame.lookAt(entry.position, facing), style)
 end
 folder.Parent = hub
end

-- Shows entries (nil when the read failed: the previous rows stay, with a notice).
local function render(stat, entries)
 for _, screen in screens[stat] or {} do
  if entries then
   for i, row in screen.rows do
    local entry = entries[i]
    row.name.Text = entry and (entry.name or "Unknown") or "---"
    row.value.Text = entry and Leaderboards.FormatValue(stat, entry.value) or ""
   end
   screen.status.Text = #entries == 0 and "No scores yet - be the first!" or "Updates every minute"
  else
   screen.status.Text = "Couldn't update - retrying soon"
  end
 end
end

local function readBudget()
 local ok, budget = pcall(DataStoreService.GetRequestBudgetForRequestType, DataStoreService,
  Enum.DataStoreRequestType.GetSortedAsync)
 return not ok or budget > 0
end

-- Re-reads every board shown in this server and fills in names. Yields.
function Leaderboards.Refresh()
 local lookups = NAME_LOOKUPS_PER_REFRESH
 for _, stat in Leaderboards.Order do
  if screens[stat] and readBudget() then
   local entries = Leaderboards.Fetch(stat)
   for _, entry in entries or {} do
    local name, lookedUp = Leaderboards.GetName(entry.userId, lookups > 0)
    if lookedUp then lookups -= 1 end
    entry.name = name
   end
   render(stat, entries)
  end
 end
end

local started = false
function Leaderboards.Start()
 if started then return end
 started = true
 task.spawn(function()
  while true do
   local ok, problem = pcall(Leaderboards.Refresh)
   if not ok then warn("[Leaderboards] refresh failed: " .. tostring(problem)) end
   task.wait(REFRESH_SECONDS)
  end
 end)
 task.spawn(function()
  while true do
   task.wait(FLUSH_SECONDS)
   local ok, problem = pcall(Leaderboards.Flush)
   if not ok then warn("[Leaderboards] write failed: " .. tostring(problem)) end
  end
 end)
 -- When the server closes, PlayerData's final saves submit every player's last values; write
 -- them as they arrive (best effort, within the shutdown window).
 game:BindToClose(function()
  local started = os.clock()
  repeat
   task.wait(1)
   pcall(Leaderboards.Flush)
  until (os.clock() - started > SHUTDOWN_MIN_SECONDS and not Leaderboards.HasPending())
   or os.clock() - started > SHUTDOWN_MAX_SECONDS
 end)
end

return Leaderboards
