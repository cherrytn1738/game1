-- Background audio for the local player, presentation only (all tuning lives in GameAudio):
--   * a soft outdoor air bed under everything
--   * a quiet themed loop at each fantasy Training Ground, heard only near its cage
--   * background music, once GameAudio.MusicTrack is set
-- Each loop is created once and keeps playing; Roblox's distance rolloff silences the cage
-- loops when the player is away from them.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameAudio = require(ReplicatedStorage:WaitForChild("GameAudio"))
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))

local function loop(name, parent, overrides)
 local sound = GameAudio.Make(name, overrides)
 if not sound then return nil end
 local cue = GameAudio.Ambience[name]
 sound.Looped = true
 if cue and cue.rolloff then
  sound.RollOffMode = Enum.RollOffMode.InverseTapered
  sound.RollOffMinDistance, sound.RollOffMaxDistance = cue.rolloff[1], cue.rolloff[2]
 end
 -- Start somewhere random so loops don't all begin at the same point.
 sound.Parent = parent
 local function start() sound.TimePosition = math.random() * sound.TimeLength end
 if sound.IsLoaded then start() else sound.Loaded:Once(start) end
 sound:Play()
 return sound
end

loop("HubAir", SoundService)

if GameAudio.MusicTrack then
 local music = Instance.new("Sound")
 music.Name, music.SoundId, music.Volume, music.Looped = "Music", GameAudio.MusicTrack, GameAudio.MusicVolume, true
 music.SoundGroup = GameAudio.Group("Music")
 music.Parent = SoundService
 music:Play()
end

-- Training Ground loops, attached to each cage's plate as the hubs build.
local function attachGround(stadium)
 local name = GameAudio.GroundAmbience[stadium.Name]
 if not name or stadium:FindFirstChild("GroundAmbience", true) then return end
 local plate = stadium:WaitForChild("TrainingPlate", 10)
 if not plate or not plate:IsA("BasePart") then return end
 local sound = loop(name, plate)
 if sound then sound.Name = "GroundAmbience" end
end

local function watchHub(world)
 if not world.hub then return end
 task.spawn(function()
  local hub = workspace:WaitForChild(world.hub.name, 60)
  local grounds = hub and hub:WaitForChild("TrainingGrounds", 30)
  if not grounds then return end
  for _, stadium in grounds:GetChildren() do task.spawn(attachGround, stadium) end
  grounds.ChildAdded:Connect(function(stadium) task.spawn(attachGround, stadium) end)
 end)
end
for _, world in Worlds.Worlds do watchHub(world) end
