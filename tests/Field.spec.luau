-- Pure section arithmetic and server world-completion fixtures. No live player/save writes.
return function(sources)
 local passed = 0
 local function check(value, message)
  assert(value, message)
  passed += 1
 end
 local Worlds = assert(loadstring(sources.WorldConfig))()
 local Field = assert(loadstring(sources.FieldConfig))()
 local Progression = assert(loadstring(sources.ProgressionConfig))()
 for _, world in Worlds.Worlds do
  local previousEnd = 0
  for index, section in world.sections do
   check(section.startDistance == previousEnd and section.endDistance > previousEnd, "continuous configured sections")
   check(Field.GetSection(section.startDistance, world) == section, "inclusive section start")
   check(Field.GetSection(section.endDistance - 0.001, world) == section, "section interior before boundary")
   check(Field.GetSection(section.endDistance, world) == (world.sections[index+1] or section), "next section owns shared boundary")
   previousEnd = section.endDistance
  end
  check(previousEnd == world.endDistance, "final section meets world endpoint")
  check(Field.GetSection(-0.001,world) == nil, "behind start excluded")
  check(Field.GetSection(world.endDistance+world.runoutDistance,world) == world.sections[#world.sections], "runout belongs to final section")
  check(Field.GetSection(world.endDistance+world.runoutDistance+0.001,world) == nil, "beyond runout excluded")
  check(Field.GetSection(math.huge,world) == nil and Field.GetSection(0/0,world) == nil, "invalid distance has no reward section")
  for _, forward in {-Vector3.zAxis, Vector3.xAxis, Vector3.new(1,0,-1).Unit} do
   local origin = Vector3.new(1500,3,-7200)
   local right = forward:Cross(Vector3.yAxis)
   for _, height in {-100,0,10000} do
    for _, side in {-Field.GetWidth(world)/3,0,Field.GetWidth(world)/3} do
     local point = origin+forward*350+Vector3.yAxis*height+right*side
     check(math.abs(Field.GetForwardDistance(point,origin,forward)-350)<0.001, "height/lateral/global offset cannot inflate progression")
     check(Field.GetSectionAtPosition(point,origin,forward,world)==Field.GetSection(350,world), "all field queries share downfield boundaries")
    end
   end
   check(Field.GetSectionAtPosition(origin+forward*350+right*(Field.GetWidth(world)/2+1),origin,forward,world)==nil, "outside runway excluded")
   check(Field.GetSectionAtPosition(origin-forward,origin,forward,world)==nil, "behind tee excluded spatially")
  end
 end
 -- Distance, not speed, is what rises with Level: from Level 22 each Level uses a measured speed
 -- chosen for where it lands (bounces make distance erratic in speed), so speeds may dip.
 local priorSpeed, priorDistance = 0, 0
 for _,level in {1,5,10,20} do
  local speed = Progression.GetLaunchSpeed(level)
  check(speed > priorSpeed, "the early Levels' launch strength rises with Level")
  priorSpeed = speed
 end
 for _,level in {1,5,10,20,30,40,50,60,70,100,140,150,250,370} do
  local distance = Progression.GetExpectedHitDistance(level)
  check(distance > priorDistance, "Level alone monotonically increases hit distance")
  priorDistance = distance
 end

 local function player()
  local attrs = {CurrentWorldId=Worlds.StartingWorldId,["WorldUnlocked_"..Worlds.StartingWorldId]=true}
  return {Name="Fixture",ready=true,
   GetAttribute=function(_,name) return attrs[name] end,
   SetAttribute=function(_,name,value) attrs[name]=value end}
 end
 local env = setmetatable({
  game={ReplicatedStorage={WaitForChild=function(_,name) return name end}},
  script={Parent={WaitForChild=function(_,name) return name end}},
  require=function(name)
   if name=="WorldConfig" then return Worlds end
   if name=="PlayerData" then return {IsReady=function(p) return p.ready end} end
   error(name)
  end,
  print=function() end,
 },{__index=getfenv()})
 local run = assert(loadstring(sources.WorldProgress))
 setfenv(run,env)
 local Progress = run()
 local a,b = player(),player()
 local first = Worlds.Get(Worlds.StartingWorldId)
 check(#first.sections==10,"World 1 has ten ordered runway themes")
 local second = Worlds.Get("world_2")
 check(Field.GetWidth(first)==160 and Field.GetWidth(second)==160 and Field.GetWidth({})==Field.Width,
  "width is per-world: both themed runways are 160 wide; a world without a runway uses the open field")
 check(#second.sections==10,"World 2 has ten ordered runway themes")
 for _,distance in {0,499,500,999,1000,1499,1500,3000,6000,7500} do
  local expected=distance<500 and 1 or distance<1500 and 1.15 or 1.35
  check(Field.GetSection(distance,second).rewardMultiplier==expected,"World 2's themes keep its reward tiers")
 end
 for _,distance in {0,299,300,799,800,1299,1800,4400,5000,6500} do
  local expected=distance<300 and 1 or distance<800 and 1.15 or 1.35
  check(Field.GetSection(distance,first).rewardMultiplier==expected,"new themes preserve existing reward tiers")
 end
 local third = Worlds.Get("world_3")
 local fourth = Worlds.Get("world_4")
 check(second.nextWorldId=="world_3" and third and third.order==3 and third.endDistance==7000 and third.nextWorldId=="world_4",
  "World 2 leads to World 3 (7000 studs), which leads to World 4")
 check(third.endPortal and third.endPortal.finale==nil,"World 3's end portal is a trip again, not the finale")
 check(fourth and fourth.order==4 and fourth.endDistance==8000 and fourth.nextWorldId==nil and fourth.cashMultiplier==1000
  and fourth.offset==Vector3.new(24000,0,0) and Worlds.Worlds[#Worlds.Worlds]==fourth,
  "World 4 (Tiny Town) is the last World for now (8000 studs, x1000 Cash, offset 24000)")
 check(fourth.endPortal and fourth.endPortal.finale and fourth.endPortal.finale.title~=nil,"World 4's end portal has the temporary finale")
 for _, world in {third, fourth} do
  check(#world.sections==10 and Field.GetWidth(world)==160,world.id .. " has ten runway themes on a 160-stud runway")
  local previousEnd=0
  for index,section in world.sections do
   check(section.order==index and section.startDistance==previousEnd,world.id .. "'s sections are consecutive")
   previousEnd=section.endDistance
  end
  check(previousEnd==world.endDistance,world.id .. "'s last section ends at its endpoint")
 end
 for _,distance in {0,699,700,2099,2100,6800,7999,9000} do
  local expected=distance<700 and 1 or distance<2100 and 1.15 or 1.35
  check(Field.GetSection(distance,fourth).rewardMultiplier==expected,"World 4's sections follow the reward tiers")
 end
 -- The shared compact hub layout, seen from the spawn looking into the hub (+Z): Training
 -- Grounds on the left (+X), item displays on the right (-X), the event piece in the middle
 -- and the portal at the back, all inside the hub and clear of each other.
 local Training = assert(loadstring(sources.TrainingConfig))()
 local CAGE_REACH_DOOR, CAGE_REACH_BACK, CAGE_HALF = 20, 57, 16 -- cage scenery around a plate
 local DISPLAY_HALF, DISPLAY_DEPTH = 18, 15
 local firstHub = first.hub
 for _, world in Worlds.Worlds do
  local hub = world.hub
  -- World 4's Mouse-Hole Plaza theme is not built yet (WORLD4_DESIGN.md, Phase 6): plain floor.
  check(hub and hub.minX < 0 and hub.maxX > 0 and hub.depth > 0 and (hub.theme ~= nil or world.id == "world_4"), world.id .. " has a themed hub")
  check(hub.minX == firstHub.minX and hub.maxX == firstHub.maxX and hub.depth == firstHub.depth
   and hub.portalPad.center == firstHub.portalPad.center and hub.eventArea.center == firstHub.eventArea.center,
   world.id .. " shares World 1's hub layout")
  local function inside(x0, x1, z0, z1) return x0 >= hub.minX and x1 <= hub.maxX and z0 >= 0 and z1 <= hub.depth end
  -- Arrival: the spawn just behind the batting circle, facing into the hub.
  local tee = Vector3.new(-17.2, 0, -21.2) + world.offset
  local spawn = world.arrival.Position - tee
  check(math.abs(spawn.X - hub.spawn.X) < 0.01 and math.abs(spawn.Z - hub.spawn.Z) < 0.01 and spawn.Z > 20 and spawn.Z < 40
   and world.arrival.LookVector.Z > 0.99, world.id .. " arrives just behind the batting area, facing into the hub")
  -- Training Grounds: one row on the left, doors facing the middle, inside the hub, not overlapping.
  local layout = Training.GetHub(world.id)
  local doorFacing = CFrame.Angles(0, Training.GetPlateYaw(), 0):VectorToWorldSpace(Vector3.zAxis)
  check(doorFacing.X < -0.99, "cage doors face the middle (-X)")
  local cageDoorX, lastCageZ = math.huge, 0
  for index, id in layout.grounds do
   local plate = Training.GetPlatePosition(Training.Get(id), world.id)
   check(plate.X > 0 and inside(plate.X - CAGE_REACH_DOOR, plate.X + CAGE_REACH_BACK, plate.Z - CAGE_HALF, plate.Z + CAGE_HALF),
    id .. " stands inside the hub on the left")
   if index > 1 then
    local previous = Training.GetPlatePosition(Training.Get(layout.grounds[index - 1]), world.id)
    check(plate.Z - previous.Z >= 2 * CAGE_HALF, "cages in the row do not overlap")
   end
   cageDoorX, lastCageZ = math.min(cageDoorX, plate.X - CAGE_REACH_DOOR), math.max(lastCageZ, plate.Z + CAGE_HALF)
  end
  -- Item displays: on the right facing the middle, inside the hub, side by side.
  local displayFrontX, lastDisplayZ = -math.huge, 0
  for index, display in hub.displays do
   local facing = CFrame.Angles(0, display.yaw, 0):VectorToWorldSpace(Vector3.zAxis)
   local p = display.position
   check(p.X < 0 and facing.X > 0.99 and inside(p.X - DISPLAY_DEPTH, p.X, p.Z - DISPLAY_HALF, p.Z + DISPLAY_HALF),
    display.id .. " stands inside the hub on the right, facing the middle")
   if index > 1 then check(p.Z - hub.displays[index - 1].position.Z >= 2 * DISPLAY_HALF, "displays do not overlap") end
   displayFrontX, lastDisplayZ = math.max(displayFrontX, p.X), math.max(lastDisplayZ, p.Z + DISPLAY_HALF)
  end
  check(hub.displays[1].category == "Ball" and hub.displays[2].category == "Bat"
   and hub.displays[1].series == (world.id ~= "world_1" and world.id or nil), "each World shows its own balls, then the bats")
  -- The plaza between them stays open (8-stud lanes along both sides), with the event piece in it.
  local plaza0, plaza1 = displayFrontX + 8, cageDoorX - 8
  check(plaza1 - plaza0 >= 40, "the middle plaza is at least 40 studs wide")
  local event = hub.eventArea
  check(event.center.X - event.size / 2 >= plaza0 and event.center.X + event.size / 2 <= plaza1
   and event.center.Z - event.size / 2 > spawn.Z, "the event piece sits in the plaza, in front of the spawn")
  -- The portal: middle of the back, facing the spawn, behind everything else.
  local portal = hub.portalPad
  check(portal.center.X == 0 and (portal.yaw or 0) == 0 and portal.center.Z + portal.radius <= hub.depth
   and portal.center.Z - portal.radius > event.center.Z + event.size / 2 and portal.center.Z > lastDisplayZ,
   "the portal stands at the back in the middle, facing the spawn")
  -- World 1 alone holds the leaderboards: either side of the portal, behind the last cage.
  check((hub.leaderboards ~= nil) == (world.id == Worlds.StartingWorldId), "only World 1 holds the global leaderboards")
  for _, board in hub.leaderboards and hub.leaderboards.boards or {} do
   local p = board.position
   check(math.abs(p.X) - 6 > portal.radius and p.Z > lastCageZ and inside(p.X - 6, p.X + 6, p.Z - 2, p.Z + 2),
    board.stat .. " board stands beside the portal, clear of it and of the cages")
  end
 end
 local stats = {}
 for _, board in firstHub.leaderboards.boards do stats[board.stat] = true end
 check(stats.Level and stats.TimePlayed and stats.RobuxSpent and stats.Cash and #firstHub.leaderboards.boards == 4,
  "four boards: Level, Time Played, Robux Spent and Cash")
 for _,distance in {0,599,600,1999,2000,4000,7000,8500} do
  local expected=distance<600 and 1 or distance<2000 and 1.15 or 1.35
  check(Field.GetSection(distance,third).rewardMultiplier==expected,"World 3 follows the reward tier pattern")
 end
 check(Progress.Complete(a,first,first.endDistance-0.001)==nil,"below endpoint does not unlock")
 check(Progress.Complete(a,first,0/0)==nil and Progress.Complete(a,first,math.huge)==nil,"nonfinite final distance rejected")
 a.ready=false
 check(Progress.Complete(a,first,first.endDistance)==nil,"unloaded profile cannot complete")
 a.ready=true
 a:SetAttribute("CurrentWorldId","elsewhere")
 check(Progress.Complete(a,first,first.endDistance)==nil,"wrong-world result cannot complete")
 a:SetAttribute("CurrentWorldId",first.id)
 a:SetAttribute("WorldUnlocked_"..first.id,false)
 check(Progress.Complete(a,first,first.endDistance)==nil,"locked world cannot complete")
 a:SetAttribute("WorldUnlocked_"..first.id,true)
 check(Progress.Complete(a,first,first.endDistance)~=nil,"exact endpoint completes")
 check(a:GetAttribute("WorldCompleted_"..first.id)==true,"completion records only authoritative player")
 check(first.nextWorldId==nil or a:GetAttribute("WorldUnlocked_"..first.nextWorldId)==true,"completion unlocks configured successor")
 check(Progress.Complete(a,first,first.endDistance+10)==nil,"completion repeats have no second outcome")
 check(b:GetAttribute("WorldCompleted_"..first.id)==nil and (not first.nextWorldId or not b:GetAttribute("WorldUnlocked_"..first.nextWorldId)),"player B never inherits player A completion")
 return {passed=passed,message="Field boundaries, downfield/height/lateral isolation, runout, Level scaling, guarded world completion and player isolation"}
end
