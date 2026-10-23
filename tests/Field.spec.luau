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
 local priorSpeed = 0
 for _,level in {1,5,10,20,30,40,50,60,70} do
  local speed = Progression.GetLaunchSpeed(level)
  check(speed > priorSpeed, "Level alone monotonically increases launch strength")
  priorSpeed = speed
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
