-- GameAudio's mix rules with fake services: ducks combine and restore, cooldowns hold, cues
-- without an asset stay silent, and world sounds are positional. Nothing live is touched.
return function(sources)
 local passed = 0
 local function check(condition, message) assert(condition, message) passed += 1 end
 local function instance(className)
  local children = {}
  local object = {ClassName = className, Name = className, Volume = 0.5, TimeLength = 0, PlaybackSpeed = 1, Parent = nil}
  function object:IsA(name) return name == className end
  function object:FindFirstChild(name) for _, child in children do if child.Name == name then return child end end end
  function object:Play() self.Playing = true end
  setmetatable(object, {__newindex = function(t, key, value)
   if key == "Parent" and value and value.addChild then value.addChild(t) end
   rawset(t, key, value)
  end})
  return object
 end
 local soundService = instance("SoundService")
 local serviceChildren = {}
 soundService.addChild = function(child) table.insert(serviceChildren, child) end
 function soundService:FindFirstChild(name) for _, child in serviceChildren do if child.Name == name then return child end end end
 local tweens = {}
 local tweenService = {Create = function(_, target, _, goal)
  return {Play = function() for k, v in goal do target[k] = v end table.insert(tweens, goal) end, Cancel = function() end}
 end}
 local delayed = {}
 local services = {SoundService = soundService, TweenService = tweenService,
  ContentProvider = {PreloadAsync = function() end}, Debris = {AddItem = function() end}}
 local clock = 0
 local environment = setmetatable({
  game = {GetService = function(_, name) return assert(services[name], name) end},
  Instance = {new = instance},
  os = {clock = function() return clock end},
  task = {spawn = function(fn) fn() end, delay = function(seconds, fn) table.insert(delayed, {at = clock + seconds, fn = fn}) end},
 }, {__index = getfenv()})
 local module = assert(loadstring(sources.GameAudio))
 setfenv(module, environment)
 local Audio = module()

 local function volume(group) return Audio.Group(group).Volume end
 check(math.abs(volume("Music") - Audio.GroupVolumes.Music) < 1e-6, "groups start at their configured volume")
 Audio.Duck("legendary", "Cinematic")
 check(math.abs(volume("Music") - Audio.GroupVolumes.Music * Audio.Ducks.Cinematic.Music) < 1e-6, "a cinematic ducks music")
 check(math.abs(volume("Cinematic") - Audio.GroupVolumes.Cinematic) < 1e-6, "a duck leaves groups it does not name alone")
 Audio.Duck("rebirth", "Sting")
 local expected = Audio.GroupVolumes.Music * math.min(Audio.Ducks.Cinematic.Music, Audio.Ducks.Sting.Music)
 check(math.abs(volume("Music") - expected) < 1e-6, "overlapping ducks use the deepest, never multiply down")
 Audio.Duck("legendary", "Cinematic")
 check(math.abs(volume("Music") - expected) < 1e-6, "ducking twice with one key does not stack")
 check(Audio.CinematicActive(), "an active cinematic duck is reported")
 Audio.Unduck("legendary")
 Audio.Unduck("rebirth")
 check(math.abs(volume("Music") - Audio.GroupVolumes.Music) < 1e-6 and not Audio.CinematicActive(), "releasing every duck restores the mix")

 Audio.Cues.TestCue = {"rbxassetid://1", 0.4, "UI", cooldown = 0.5}
 check(Audio.Play("TestCue") ~= nil, "a cue with an asset plays")
 check(Audio.Play("TestCue") == nil, "a cue inside its cooldown is skipped")
 clock += 0.6
 local flat = Audio.Play("TestCue")
 check(flat and flat.Parent == soundService and flat.SoundGroup == Audio.Group("UI"), "a cue without a world parent plays flat in its group")
 Audio.Cues.Empty = {nil, 0.4, "UI"}
 check(Audio.Play("Empty") == nil, "a cue with no asset yet stays silent")
 local part = instance("BasePart")
 local world = Audio.Play("TestCue", part, nil)
 check(world == nil, "cooldown also applies to world sounds")
 clock += 1
 Audio.Cues.TestCue.rolloff = {5, 50}
 world = Audio.Play("TestCue", part)
 check(world.Parent == part and world.RollOffMaxDistance == 50, "a cue played on a part is positional with its rolloff")

 Audio.Cues.Payoff = {"rbxassetid://2", 0.9, "UI", duck = "Sting", duckSeconds = 2}
 Audio.Play("Payoff")
 check(volume("Music") < Audio.GroupVolumes.Music, "a payoff cue ducks the background while it plays")
 clock += 2.1
 for _, entry in delayed do if entry.at <= clock then entry.fn() end end
 check(math.abs(volume("Music") - Audio.GroupVolumes.Music) < 1e-6, "and releases it afterwards")
 return {passed = passed}
end
