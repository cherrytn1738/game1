-- Global leaderboard mirror, formatting, reads and boards, with in-memory OrderedDataStores,
-- players and name lookups. No live stores are touched; the boards are built outside the
-- DataModel and destroyed.
return function(sources)
 local passed = 0
 local function check(condition, message)
  assert(condition, message)
  passed += 1
 end
 local now = 1000
 local stores, failWrites, failReads, setCalls = {}, {}, false, 0
 local function orderedStore(name)
  if stores[name] then return stores[name] end
  local store = {data = {}}
  function store:SetAsync(key, value)
   setCalls += 1
   if failWrites[name] then error("simulated write outage") end
   check(type(key) == "string" and type(value) == "number" and value % 1 == 0, "integer values under UserId keys")
   self.data[key] = value
  end
  function store:GetSortedAsync(ascending, size)
   if failReads then error("simulated read outage") end
   check(ascending == false and size == 10, "boards read the top 10, highest first")
   local items = {}
   for key, value in self.data do table.insert(items, {key = key, value = value}) end
   table.sort(items, function(a, b) return a.value > b.value end)
   local page = {}
   for i = 1, math.min(size, #items) do page[i] = items[i] end
   return {GetCurrentPage = function() return page end}
  end
  stores[name] = store
  return store
 end
 local online, nameCalls, failNames = {}, 0, {}
 local players = {
  GetPlayerByUserId = function(_, id) return online[id] end,
  GetNameFromUserIdAsync = function(_, id)
   nameCalls += 1
   if failNames[id] then error("simulated lookup failure") end
   return "User" .. id
  end,
 }
 local budget, studio = 100, false
 local dataStores = {
  GetOrderedDataStore = function(_, name) return orderedStore(name) end,
  GetRequestBudgetForRequestType = function() return budget end,
 }
 local env = setmetatable({
  game = {
   GetService = function(_, name)
    if name == "Players" then return players end
    if name == "DataStoreService" then return dataStores end
    if name == "RunService" then return {IsStudio = function() return studio end} end
    if name == "ReplicatedStorage" then return {WaitForChild = function(_, child) return child end} end
    error("Unexpected service " .. name)
   end,
   BindToClose = function() end,
  },
  require = function(module)
   assert(module == "WorldUIConfig", "Unexpected require " .. tostring(module))
   return {Register = function() end}
  end,
  os = {clock = function() return now end, time = os.time},
  task = {wait = function(seconds) now += seconds or 0 end, spawn = function() end},
  warn = function() end,
 }, {__index = getfenv()})
 local fn = assert(loadstring(sources.Leaderboards))
 setfenv(fn, env)
 local L = fn()
 local function value(stat, userId) return orderedStore(L.StoreName(stat)).data[tostring(userId)] end
 -- Live servers keep the production store names.
 check(L.StoreName("Level") == "GlobalLeaderboard_Level_v1" and L.StoreName("TimePlayed") == "GlobalLeaderboard_TimePlayed_v1"
  and L.StoreName("RobuxSpent") == "GlobalLeaderboard_RobuxSpent_v1" and L.StoreName("Cash") == "GlobalLeaderboard_Cash_v1",
  "live servers use the production stores")

 -- Formatting: readable durations (never raw seconds), compact Cash and Robux.
 for seconds, text in {[0] = "0m", [59] = "0m", [2700] = "45m", [8040] = "2h 14m", [67320] = "18h 42m",
  [284400] = "3d 7h", [86399] = "23h 59m"} do
  check(L.FormatDuration(seconds) == text, "duration " .. seconds .. " reads " .. text)
 end
 check(L.FormatValue("TimePlayed", 8040) == "2h 14m" and L.FormatValue("Level", 125) == "125"
  and L.FormatValue("Level", 12345) == "12.3K", "Time Played and Level values")
 check(L.FormatValue("Cash", 9999) == "$9,999" and L.FormatValue("Cash", 31285812) == "$31.2M"
  and L.FormatValue("Cash", 2500000000) == "$2.5B" and L.FormatValue("Cash", 9000000000000) == "$9T", "Cash values")
 check(L.FormatValue("RobuxSpent", 1500) == "R$ 1,500" and L.FormatValue("RobuxSpent", 0) == "R$ 0", "Robux values")

 -- Extracting from a saved record: only valid whole numbers become leaderboard values.
 local values = L.Extract({Level = 25, Cash = 31285812, TimePlayed = 8040, RobuxSpent = 0, Power = 99})
 check(values.Level == 25 and values.Cash == 31285812 and values.TimePlayed == 8040 and values.RobuxSpent == 0
  and values.Power == nil, "Level, Cash, Time Played and Robux Spent come from the saved record")
 for _, bad in {-1, 1.5, 0/0, math.huge, "25", true} do
  check(next(L.Extract({Level = bad, Cash = bad, TimePlayed = bad, RobuxSpent = bad})) == nil, "malformed values are never written")
 end
 check(next(L.Extract(nil)) == nil and next(L.Extract("bad")) == nil, "a missing record writes nothing")

 -- Writing: the first save writes everything, later ones only what changed, at most every
 -- WRITE_SECONDS while the player plays, and immediately when they leave.
 L.Submit(1, {Level = 5, Cash = 100, TimePlayed = 60, RobuxSpent = 0})
 L.Flush()
 check(setCalls == 4 and value("Level", 1) == 5 and value("Cash", 1) == 100 and value("TimePlayed", 1) == 60
  and value("RobuxSpent", 1) == 0 and not L.HasPending(), "first save writes all four boards")
 now += 30
 L.Submit(1, {Level = 6, Cash = 100, TimePlayed = 90, RobuxSpent = 0})
 L.Flush()
 check(setCalls == 4 and L.HasPending() and value("Level", 1) == 5, "no write sooner than the write interval")
 now += 90
 L.Flush()
 check(setCalls == 6 and value("Level", 1) == 6 and value("TimePlayed", 1) == 90 and not L.HasPending(),
  "after the interval only the changed values are written")
 now += 120
 L.Submit(1, {Level = 6, Cash = 100, TimePlayed = 90, RobuxSpent = 0})
 L.Flush()
 check(setCalls == 6 and not L.HasPending(), "unchanged values are not written again")
 now += 5
 L.Submit(1, {Level = 6, Cash = 40, TimePlayed = 95, RobuxSpent = 0}, true)
 L.Flush()
 check(setCalls == 8 and value("Cash", 1) == 40 and not L.HasPending(), "leaving writes at once; spent Cash lowers the board")
 for _, bad in {0, -3, 1.5, "1", nil} do L.Submit(bad, {Level = 1}) end
 check(not L.HasPending(), "invalid UserIds are ignored")

 -- Failures: a failed write stays pending and is retried; other boards still update.
 failWrites[L.StoreName("Cash")] = true
 L.Submit(2, {Level = 3, Cash = 50, TimePlayed = 10, RobuxSpent = 0})
 L.Flush()
 check(value("Level", 2) == 3 and value("Cash", 2) == nil and L.HasPending(), "a failed write is kept for later")
 failWrites[L.StoreName("Cash")] = nil
 now += 10
 L.Flush()
 check(value("Cash", 2) == 50 and not L.HasPending(), "the retry writes only what failed")
 budget = 0
 L.Submit(3, {Level = 9})
 L.Flush()
 check(value("Level", 3) == nil and L.HasPending(), "no writes without request budget")
 budget = 100
 now += 10
 L.Flush()
 check(value("Level", 3) == 9 and not L.HasPending(), "writes resume when budget returns")
 failWrites[L.StoreName("Level")] = true
 L.Submit(4, {Level = 2}, true)
 for _ = 1, 5 do
  L.Flush()
  now += 10
 end
 check(not L.HasPending() and value("Level", 4) == nil, "a departed player's failing write is given up after bounded attempts")
 failWrites[L.StoreName("Level")] = nil

 -- Reading: the top entries, best first, ranked; a failed read returns nil.
 for id = 10, 22 do orderedStore(L.StoreName("Level")).data[tostring(id)] = id * 10 end
 orderedStore(L.StoreName("Level")).data.notAUser = 9999
 local entries = L.Fetch("Level")
 check(#entries == 9 and entries[1].userId == 22 and entries[1].value == 220 and entries[1].rank == 1
  and entries[2].rank == 2 and entries[9].userId == 14, "top ten, highest first, ranked; an entry that is not a UserId is skipped")
 failReads = true
 check(L.Fetch("Level") == nil, "a failed read returns nothing")
 failReads = false

 -- Names: players in the server need no lookup; others are looked up once and cached; a failed
 -- lookup waits before it is tried again.
 online[22] = {Name = "Slugger"}
 local name, lookedUp = L.GetName(22, true)
 check(name == "Slugger" and not lookedUp and nameCalls == 0, "a player in the server needs no lookup")
 check(L.GetName(21, false) == nil and nameCalls == 0, "no lookup when lookups are used up")
 check(L.GetName(21, true) == "User21" and nameCalls == 1, "an offline player is looked up")
 check(L.GetName(21, true) == "User21" and nameCalls == 1, "and then cached")
 failNames[20] = true
 check(L.GetName(20, true) == nil and nameCalls == 2, "a failed lookup has no name")
 check(L.GetName(20, true) == nil and nameCalls == 2, "and is not retried at once")
 failNames[20] = nil
 now += 301
 check(L.GetName(20, true) == "User20" and nameCalls == 3, "it is retried after a while")

 -- The physical boards: built from the hub config, filled by Refresh, kept on a failed read.
 local hub = Instance.new("Model")
 L.Build(hub, CFrame.new(), {facing = Vector3.new(0, 0, 90), boards = {
  {stat = "Level", position = Vector3.new(20, 0, 200)}, {stat = "Cash", position = Vector3.new(-20, 0, 200)}}})
 local level = hub.Leaderboards:FindFirstChild("LevelBoard")
 check(level and hub.Leaderboards:FindFirstChild("CashBoard") and #hub.Leaderboards:GetChildren() == 2, "one board per configured stat")
 local screen = level.Board.Screen
 local toward = (Vector3.new(0, level.Board.Position.Y, 90) - level.Board.Position).Unit
 check(level.Board.CFrame.LookVector:Dot(toward) > 0.99 and screen.Face == Enum.NormalId.Front, "boards face the plaza")
 check(screen.Title.Text == "TOP LEVEL" and screen:FindFirstChild("Row10") and not screen:FindFirstChild("Row11"), "ten ranked rows")
 L.Refresh()
 check(screen.Row1.PlayerName.Text == "Slugger" and screen.Row1.Value.Text == "220" and screen.Row2.PlayerName.Text == "User21"
  and screen.Status.Text == "Updates every minute", "Refresh fills names and values")
 local cashRows = hub.Leaderboards.CashBoard.Board.Screen
 check(cashRows.Row1.Value.Text == "$50" or cashRows.Row1.Value.Text == "$40", "each board shows its own stat")
 failReads = true
 L.Refresh()
 check(screen.Row1.PlayerName.Text == "Slugger" and screen.Status.Text:find("retrying") ~= nil, "a failed read keeps the last rows")
 failReads = false
 hub:Destroy()

 -- Studio: every board writes and reads its own Studio_ store; the production stores stay untouched.
 studio = true
 local studioFn = assert(loadstring(sources.Leaderboards))
 setfenv(studioFn, env)
 local S = studioFn()
 for _, stat in S.Order do
  check(S.StoreName(stat) == "Studio_" .. L.StoreName(stat), stat .. " uses a separate Studio store")
 end
 local liveBefore = orderedStore(L.StoreName("Cash")).data["77"]
 S.Submit(77, {Level = 4, Cash = 900, TimePlayed = 30, RobuxSpent = 0})
 S.Flush()
 check(orderedStore("Studio_GlobalLeaderboard_Cash_v1").data["77"] == 900 and orderedStore(L.StoreName("Cash")).data["77"] == liveBefore
  and orderedStore("Studio_GlobalLeaderboard_Level_v1").data["77"] == 4, "Studio writes land in the Studio stores only")
 local studioEntries = S.Fetch("Cash")
 check(#studioEntries == 1 and studioEntries[1].userId == 77 and studioEntries[1].value == 900, "Studio reads the same Studio stores it writes")
 studio = false
 return passed
end
