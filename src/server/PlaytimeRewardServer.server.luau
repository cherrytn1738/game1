-- Playtime Rewards (PlaytimeRewardConfig): counts each player's time played this session and grants
-- a reward when they claim it, once its time has passed. The server owns the clock and the board;
-- the client only asks to claim (one reward by number, or every ready one). Nothing is saved:
-- leaving resets the board. After all twelve are claimed, a new cycle starts from reward 1.
--
-- Display copies for the client (attributes on the player):
--   PlaytimeCycleStart  server time (workspace:GetServerTimeNow) the current cycle started
--   PlaytimeClaimed     the rewards claimed this cycle, as a bit mask (bit 1 = reward 1)
--   PlaytimeScale       the timer factor (1 live; StudioPlaytimeScale in Studio)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Storage = game:GetService("ReplicatedStorage")
local Playtime = require(Storage:WaitForChild("PlaytimeRewardConfig"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local remote = Instance.new("RemoteEvent")
remote.Name, remote.Parent = "PlaytimeRewards", Storage

local boards = {} -- [player] = {cycleStart = server time, claimed = {[index] = true}, lastRequest = os.clock()}

local function timeScale()
 local value = RunService:IsStudio() and workspace:GetAttribute(Playtime.StudioScaleAttribute)
 if type(value) == "number" and value >= 0.01 and value <= 1 then return value end
 return 1
end

local function publish(player, board)
 local mask = 0
 for index in board.claimed do mask += 2 ^ (index - 1) end
 player:SetAttribute("PlaytimeCycleStart", board.cycleStart)
 player:SetAttribute("PlaytimeClaimed", mask)
 player:SetAttribute("PlaytimeScale", timeScale())
end

local function isReady(board, index)
 return not board.claimed[index]
  and workspace:GetServerTimeNow() - board.cycleStart >= Playtime.UnlockSeconds(index, timeScale())
end

-- Grants one reward (already checked ready). Returns what it gave, or nil.
local function claim(player, board, index)
 local granted = PlayerData.ClaimPlaytimeReward(player, Playtime.Rewards[index])
 if not granted then return nil end
 board.claimed[index] = true
 granted.index = index
 return granted
end

remote.OnServerEvent:Connect(function(player, action, index)
 local board = boards[player]
 if not board or (action ~= "Claim" and action ~= "ClaimAll") then return end
 local now = os.clock()
 if now - board.lastRequest < Playtime.ClaimCooldownSeconds then return end
 board.lastRequest = now
 -- The menu only opens once the tutorial is done; the server checks again.
 if not PlayerData.IsTutorialComplete(player) then return end
 local results = {}
 if action == "Claim" then
  if type(index) ~= "number" or index % 1 ~= 0 or not Playtime.Rewards[index] or not isReady(board, index) then return end
  results[1] = claim(player, board, index)
 else
  for number in Playtime.Rewards do
   local granted = isReady(board, number) and claim(player, board, number)
   if granted then table.insert(results, granted) end
  end
 end
 if #results == 0 then return end
 -- Every reward claimed: a new cycle from now.
 local all = true
 for number in Playtime.Rewards do if not board.claimed[number] then all = false end end
 if all then board.cycleStart, board.claimed = workspace:GetServerTimeNow(), {} end
 publish(player, board)
 remote:FireClient(player, "Claimed", results, all)
end)

local function added(player)
 boards[player] = {cycleStart = workspace:GetServerTimeNow(), claimed = {}, lastRequest = -math.huge}
 publish(player, boards[player])
end
Players.PlayerAdded:Connect(added)
for _, player in Players:GetPlayers() do added(player) end
Players.PlayerRemoving:Connect(function(player) boards[player] = nil end)

-- The Studio timer factor can change mid-test.
workspace:GetAttributeChangedSignal(Playtime.StudioScaleAttribute):Connect(function()
 for player, board in boards do publish(player, board) end
end)
