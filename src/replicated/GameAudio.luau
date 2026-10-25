-- The game's shared sound vocabulary and mix, for client scripts (it lives in ReplicatedStorage
-- so the Bat tool's scripts can use it too). Presentation only: nothing here affects gameplay.
--
--   GameAudio.Play("Purchase")               flat, for the local player only (UI, progression)
--   GameAudio.Play("BatCrack", somePart)     heard from that part in the world
--   GameAudio.Duck("cinematic", "Cinematic") lowers background groups; GameAudio.Unduck("cinematic")
--
-- Every sound belongs to one of a few SoundGroups so the whole mix can be balanced here:
--   Music, Ambience, Gameplay (bat, ball, Training), UI (menus, buttons, notifications,
--   progression payoffs), Cinematic (Legendary / Mythic Hits).
-- Loudness follows a deliberate hierarchy, loudest first: rare-hit climaxes, Rebirth / World
-- unlock, bat contact, Level Up, ball flight and landings, rewards / purchases / equips /
-- travel, Training feedback, rolling, UI clicks, ambience.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local GameAudio = {}

-- Group volumes (the overall level of each part of the mix).
GameAudio.GroupVolumes = {Music = 0.5, Ambience = 0.6, Gameplay = 1, UI = 0.8, Cinematic = 1}

-- How far each duck lowers the groups it names (multipliers), and how fast it fades.
GameAudio.Ducks = {
 -- A Legendary / Mythic Hit: the cinematic owns the moment.
 Cinematic = {Music = 0.2, Ambience = 0.15, UI = 0.4, Gameplay = 0.6},
 -- Rebirth and World unlock payoffs.
 Sting = {Music = 0.35, Ambience = 0.4, Gameplay = 0.75},
}
local DUCK_IN_SECONDS, DUCK_OUT_SECONDS = 0.25, 0.8

-- Cues: {id, volume, group, ...} with optional speed (playbackSpeed), startAt (skips a quiet
-- lead-in, seconds), peak (where the recording is loudest, seconds), vary (random +/- share
-- of speed so repeats don't sound identical), eq = {low, mid, high} dB, cooldown (minimum
-- seconds between plays), fadeAt / fadeSeconds (fade out early), rolloff = {min, max} studs for
-- world sounds, follow = {cue, delay}
-- (a second layer played after delay seconds), duck = a Ducks entry held for duckSeconds.
-- All assets are Roblox-licensed: Pro Sound Effects (PSE) and APM Music libraries.
GameAudio.Cues = {
 -- Batting -----------------------------------------------------------------------------
 -- PSE "Wood Bat Hits Hard Ball": the crack itself is 0.61 s in. A little low end gives it
 -- body under the sharp transient.
 BatCrack = {"rbxassetid://9125380872", 1, "Gameplay", startAt = 0.58, eq = {4, 0, 0}, rolloff = {20, 300}},
 -- Training contact: the same crack, much quieter, softer on top and a touch higher, so
 -- practice reads as smaller than a real hit.
 PracticeCrack = {"rbxassetid://9125380872", 0.3, "Gameplay", startAt = 0.58, speed = 1.06, vary = 0.04,
  eq = {-2, 0, -6}, rolloff = {10, 120}},
 -- PSE "Wood Whoosh Slicing Air Quick Swings 4": a tight, dry swish, loudest 0.11 s in.
 Swing = {"rbxassetid://9120972321", 0.45, "Gameplay", peak = 0.11, vary = 0.05, rolloff = {8, 80}},
 PracticeSwing = {"rbxassetid://9120972321", 0.2, "Gameplay", peak = 0.11, vary = 0.06, eq = {0, 0, -4}, rolloff = {8, 60}},
 -- A soft, low wooden thump as the practice ball is pitched (the hard-floor landing, slowed).
 PracticePitch = {"rbxassetid://9126266458", 0.1, "Gameplay", speed = 0.7, vary = 0.04, eq = {0, 0, -10}, rolloff = {6, 50}},

 -- Progression ---------------------------------------------------------------------------
 -- Training Power gain: plays every couple of seconds, so it is barely there. PSE "Synth
 -- Tone Multi Pitch Short Waa Tone Swell": a short smooth blip.
 PowerTick = {"rbxassetid://9126086045", 0.09, "UI", vary = 0.03, eq = {0, 0, -4}, cooldown = 0.5},
 -- APM Music "Magical (f)": a sparkling rising figure, cut to its opening flourish (~0.8 s) and
 -- kept a little under the other payoffs, so frequent Level Ups stay short and light.
 LevelUp = {"rbxassetid://1841173505", 0.65, "UI", fadeAt = 0.55, fadeSeconds = 0.25, cooldown = 0.3},
 -- Max Level: the same Level Up figure crowned by a bright bell, so it is related but
 -- unmistakable. PSE "Synth Sparkle Tone High Pitch Bell Tone Burst" (bell 0.3 s in).
 MaxLevel = {"rbxassetid://1841173505", 0.7, "UI", fadeAt = 0.7, fadeSeconds = 0.3, cooldown = 0.5, follow = {"MaxLevelBell", 0.3}},
 MaxLevelBell = {"rbxassetid://9126072453", 0.55, "UI", startAt = 0.28, eq = {0, 0, -4}},
 -- Rebirth: a triumphant brass fanfare straight away (APM Music "Triumphant Fanfare", 5.3 s,
 -- eased out after ~4.5 s), with a magic burst sparkling over its opening (PSE "Magic Burst 1")
 -- so it still reads as a rebirth. The rest of the mix ducks under it.
 Rebirth = {"rbxassetid://1845287239", 0.85, "UI", fadeAt = 4.2, fadeSeconds = 0.8, follow = {"RebirthBurst", 0.05},
  duck = "Sting", duckSeconds = 4.6},
 RebirthBurst = {"rbxassetid://9116384485", 0.35, "UI"},
 -- APM Music "System Transforms Sting": a broad musical reveal (~3.4 s), different in kind
 -- from Rebirth's magic.
 WorldUnlock = {"rbxassetid://9043809359", 0.85, "UI", duck = "Sting", duckSeconds = 3.5},
 -- PSE "Magic Twirling Small High Pitch Spinning Chime": soft sparkle, top end tamed.
 OfflineReward = {"rbxassetid://9125644323", 0.6, "UI", eq = {0, 0, -6}},

 -- Rewards, shop, travel ---------------------------------------------------------------------
 -- "Ka-ching" (~0.4 s): a register snap (the "ka", PSE "Cash Register 1"), then a bright
 -- bell ding (the "ching", PSE "Gas Pump Bell Cu Metallic Dinging Muted 2", its ding 0.62 s
 -- in) with one coin ring under it for money shimmer (PSE "Coin Bounce 3", faded before the
 -- coin's second bounce 0.47 s into the file).
 CashReward = {"rbxassetid://9113728625", 0.9, "UI", startAt = 0.03, vary = 0.02, follow = {"CashChing", 0.07}},
 CashChing = {"rbxassetid://9114557075", 0.5, "UI", startAt = 0.6, speed = 1.05, follow = {"CashCoin", 0}},
 CashCoin = {"rbxassetid://9113848469", 0.15, "UI", speed = 1.12, fadeAt = 0.26, fadeSeconds = 0.1},
 -- A register snap (PSE "Cash Register 5") with a short positive ding after it.
 Purchase = {"rbxassetid://9113728756", 0.3, "UI", eq = {0, 0, -3}, follow = {"Confirm", 0.08}},
 -- PSE "Switch Impact On Flip Up Large Metal 2": a chunky mechanical lock-in.
 Equip = {"rbxassetid://9119727134", 0.26, "UI", eq = {1, 0, -3}, cooldown = 0.1},
 -- PSE "Magic Zoom Up Sharp Tubular Whoosh": a rising portal whoosh.
 Travel = {"rbxassetid://9125647922", 0.4, "UI", eq = {0, 0, -3}, cooldown = 1},

 -- UI vocabulary ---------------------------------------------------------------------------
 UIClick = {"rbxassetid://6895079853", 0.3, "UI", cooldown = 0.04},
 -- PSE "Swishes Quick Airy Pass By Whooshy 3": up a little to open, down to close.
 MenuOpen = {"rbxassetid://9119696500", 0.2, "UI", startAt = 0.2, speed = 1.15, cooldown = 0.1},
 MenuClose = {"rbxassetid://9119696500", 0.15, "UI", startAt = 0.2, speed = 0.9, cooldown = 0.1},
 -- PSE "Synth Sparkle Tone High Pitch Tone Burst 9": a short positive ding.
 Confirm = {"rbxassetid://9119834602", 0.3, "UI", eq = {0, 0, -3}, cooldown = 0.1},
 -- PSE "Rifle On Shelf Small Thuddy Wood Impacts 20": a dull, muted thunk.
 Locked = {"rbxassetid://9118173486", 0.18, "UI", cooldown = 0.15},
 -- PSE "Single Tone Single High Pitch Beep Tones 6", pitched down into a soft "no".
 Invalid = {"rbxassetid://9119140867", 0.14, "UI", speed = 0.75, startAt = 0.1, cooldown = 0.3},
 -- PSE "Tone Clusters Classic Synth Switch Tones 5": a smooth, quiet notice.
 Notice = {"rbxassetid://9120133722", 0.45, "UI", startAt = 0.2, cooldown = 1},
}

-- Ambience loops (AmbienceClient): felt more than noticed. HubAir plays softly everywhere;
-- each themed Training Ground has a quiet loop heard only near its cage (rolloff in studs).
GameAudio.Ambience = {
 -- Placeholder: no licensed outdoor-air bed was found yet. Set an id to turn it on.
 HubAir = {nil, 0.25, "Ambience"},
 -- Volumes even out each file's own loudness (measured), so no cage is louder than another.
 -- PSE "Eastern Wind Constant Resonant Humming Ambience": wind with soft chimes.
 Grove = {"rbxassetid://9125515918", 0.35, "Ambience", rolloff = {14, 70}},
 -- PSE "Sci Fi Presence Phasey Weirdness 1" (recorded through a hydrophone): underwater air.
 Atlantis = {"rbxassetid://9118807149", 0.45, "Ambience", rolloff = {14, 70}},
 -- PSE "Tonal Wind Fluctuating Hollow 1": soft high wind.
 SkyTemple = {"rbxassetid://9120125188", 0.25, "Ambience", rolloff = {14, 70}},
 -- PSE "Rumble Breath Growl 1": a deep, slow breathing rumble, like something huge asleep.
 DragonLair = {"rbxassetid://9112863181", 0.09, "Ambience", rolloff = {14, 70}},
 -- PSE "Air With Ring Off Fluctuating Tones 3" (cosmic ambience).
 CosmicRift = {"rbxassetid://9113078321", 0.3, "Ambience", rolloff = {14, 70}},
}
-- Which loop each Training Ground plays (Basic Training and World 2's standard cages: none).
-- World 3's cages reuse the loops that suit them: rooftop wind, the cosmic air on the Moon and in
-- the quantum lab, the grove's chimes in the biodome, the hydrophone hum in the factory.
GameAudio.GroundAmbience = {
 enchanted_grove = "Grove", sunken_atlantis = "Atlantis", sky_temple = "SkyTemple",
 dragons_lair = "DragonLair", cosmic_rift = "CosmicRift",
 solar_rooftop = "SkyTemple", robo_factory = "Atlantis", biodome_lab = "Grove", lunar_base = "CosmicRift",
 quantum_lab = "CosmicRift",
}

-- Background music: none is chosen yet. Set an APM track id here to turn it on (it loops in
-- the Music group and ducks under cinematics and big payoffs).
GameAudio.MusicTrack = nil
GameAudio.MusicVolume = 0.3

local groups = {}
local function group(name)
 local existing = groups[name]
 if existing then return existing end
 local soundGroup = SoundService:FindFirstChild(name .. "Audio")
 if not soundGroup then
  soundGroup = Instance.new("SoundGroup")
  soundGroup.Name, soundGroup.Volume = name .. "Audio", GameAudio.GroupVolumes[name] or 1
  soundGroup.Parent = SoundService
 end
 groups[name] = soundGroup
 return soundGroup
end
GameAudio.Group = group

local lastPlayed = {}

-- Applies a cue's (or ambience loop's) settings to a new Sound (not parented or played).
function GameAudio.Make(name, overrides)
 local cue = GameAudio.Cues[name] or GameAudio.Ambience[name]
 if not cue or not cue[1] then return nil end
 local sound = Instance.new("Sound")
 sound.Name, sound.SoundId, sound.Volume = name, cue[1], cue[2]
 sound.SoundGroup = group(cue[3])
 local vary = cue.vary or 0
 sound.PlaybackSpeed = (cue.speed or 1) * (1 + (math.random() * 2 - 1) * vary)
 sound.TimePosition = cue.startAt or 0
 if cue.eq then
  local eq = Instance.new("EqualizerSoundEffect")
  eq.LowGain, eq.MidGain, eq.HighGain = cue.eq[1], cue.eq[2], cue.eq[3]
  eq.Parent = sound
 end
 for property, value in overrides or {} do sound[property] = value end
 return sound
end

-- Plays a cue once. With a BasePart/Attachment parent it is heard from there (positional);
-- otherwise it plays flat for this player only. Returns the Sound, or nil if the cue has no
-- asset yet or played too recently.
function GameAudio.Play(name, parent, overrides)
 local cue = GameAudio.Cues[name]
 if not cue or not cue[1] then return nil end
 local now = os.clock()
 if cue.cooldown and lastPlayed[name] and now - lastPlayed[name] < cue.cooldown then return nil end
 lastPlayed[name] = now
 local sound = GameAudio.Make(name, overrides)
 local positional = parent and (parent:IsA("BasePart") or parent:IsA("Attachment"))
 if positional then
  local rolloff = cue.rolloff or {15, 200}
  sound.RollOffMode = Enum.RollOffMode.InverseTapered
  sound.RollOffMinDistance, sound.RollOffMaxDistance = rolloff[1], rolloff[2]
 end
 sound.Parent = positional and parent or SoundService
 sound:Play()
 -- Removed once it has finished (generously, since TimeLength may not be known yet).
 Debris:AddItem(sound, math.max(4, (sound.TimeLength > 0 and sound.TimeLength or 8) / sound.PlaybackSpeed + 1))
 if cue.fadeAt then
  task.delay(cue.fadeAt, function()
   if sound.Parent then TweenService:Create(sound, TweenInfo.new(cue.fadeSeconds or 0.3), {Volume = 0}):Play() end
  end)
 end
 if cue.duck then GameAudio.DuckFor(name, cue.duck, cue.duckSeconds or 2) end
 if cue.follow then
  task.delay(cue.follow[2], GameAudio.Play, cue.follow[1], positional and parent or nil)
 end
 return sound
end

-- Loads cues ahead of time so the first play of the session starts on cue.
function GameAudio.Preload(names)
 local sounds = {}
 local function add(name)
  local cue = GameAudio.Cues[name]
  if cue and cue[1] then
   local sound = Instance.new("Sound")
   sound.SoundId = cue[1]
   table.insert(sounds, sound)
   if cue.follow then add(cue.follow[1]) end
  end
 end
 for _, name in names do add(name) end
 task.spawn(function() pcall(function() ContentProvider:PreloadAsync(sounds) end) end)
end

-- ---------- ducking ----------

local activeDucks = {} -- key -> duck name
local duckTweens = {}
local function applyDucks()
 for name, base in GameAudio.GroupVolumes do
  local factor = 1
  for _, duck in activeDucks do
   factor = math.min(factor, GameAudio.Ducks[duck][name] or 1)
  end
  local soundGroup = group(name)
  local target = base * factor
  if math.abs(soundGroup.Volume - target) > 0.001 then
   if duckTweens[name] then duckTweens[name]:Cancel() end
   local seconds = target < soundGroup.Volume and DUCK_IN_SECONDS or DUCK_OUT_SECONDS
   duckTweens[name] = TweenService:Create(soundGroup, TweenInfo.new(seconds, Enum.EasingStyle.Quad), {Volume = target})
   duckTweens[name]:Play()
  end
 end
end

-- Starts a duck (by key, so the same thing ducking twice doesn't stack) until Unduck(key).
function GameAudio.Duck(key, duck)
 if not GameAudio.Ducks[duck] then return end
 activeDucks[key] = duck
 applyDucks()
end

function GameAudio.Unduck(key)
 if activeDucks[key] == nil then return end
 activeDucks[key] = nil
 applyDucks()
end

local duckVersions = {}
function GameAudio.DuckFor(key, duck, seconds)
 duckVersions[key] = (duckVersions[key] or 0) + 1
 local version = duckVersions[key]
 GameAudio.Duck(key, duck)
 task.delay(seconds, function()
  if duckVersions[key] == version then GameAudio.Unduck(key) end
 end)
end

-- True while a Legendary / Mythic Hit has the mix (routine notification sounds wait it out).
function GameAudio.CinematicActive()
 for _, duck in activeDucks do
  if duck == "Cinematic" then return true end
 end
 return false
end

return GameAudio
