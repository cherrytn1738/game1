-- WorldUIConfig's distance rules: every range is set and ordered from detail to landmark, a
-- gui shows inside its range and only hides past the hysteresis band, and Register tags it.
return function(sources)
 local passed = 0
 local function check(condition, message) assert(condition, message) passed += 1 end
 local tagged = {}
 local env = setmetatable({
  game = {GetService = function(_, name)
   assert(name == "CollectionService", "Unexpected service " .. name)
   return {AddTag = function(_, instance, tag) tagged[instance] = tag end}
  end},
 }, {__index = getfenv()})
 local fn = assert(loadstring(sources.WorldUIConfig))
 setfenv(fn, env)
 local WorldUI = fn()
 local r = WorldUI.Ranges

 for _, name in {"ItemDisplay", "Interaction", "Training", "DisplayTitle", "Portal", "Leaderboard"} do
  check(type(r[name]) == "number" and r[name] > 0, name .. " has a range")
 end
 check(r.ItemDisplay < r.Training and r.Training < r.DisplayTitle and r.DisplayTitle < r.Portal
  and r.Portal < r.Leaderboard, "item labels cull first, leaderboards last")
 check(WorldUI.Hysteresis > 0 and WorldUI.FadeSeconds >= 0.15 and WorldUI.FadeSeconds <= 0.3
  and WorldUI.CheckInterval <= 0.2, "a hysteresis band, a quick fade and frequent checks")

 local range = 100
 check(WorldUI.ShouldShow(false, 99, range) and not WorldUI.ShouldShow(false, 101, range), "a hidden gui shows inside its range")
 check(WorldUI.ShouldShow(true, 105, range), "a shown gui stays shown just past its range")
 check(not WorldUI.ShouldShow(true, range * (1 + WorldUI.Hysteresis) + 1, range), "a shown gui hides past the band")
 check(not WorldUI.ShouldShow(false, 105, range), "a hidden gui stays hidden inside the band")

 local attributes = {}
 local gui = {SetAttribute = function(_, key, value) attributes[key] = value end}
 WorldUI.Register(gui, "Portal")
 check(tagged[gui] == WorldUI.Tag and attributes[WorldUI.RangeAttribute] == "Portal", "Register tags the gui with its range")
 check(not pcall(WorldUI.Register, gui, "Nowhere"), "an unknown range is refused")
 return {passed = passed}
end
