-- Runs the real launch/finalization code with controlled physics samples.
return function(sources)
 local passed = 0
 local function check(value,message) assert(value,message) passed+=1 end
 local function signal()
  local listeners={}
  return {
   Connect=function(_,fn)
    listeners[fn]=true
    return {Disconnect=function() listeners[fn]=nil end}
   end,
   Fire=function(_,...) for fn in listeners do fn(...) end end,
  }
 end
 local function object()
  local attributes={}
  return {
   GetAttribute=function(_,name) return attributes[name] end,
   SetAttribute=function(_,name,value) attributes[name]=value end,
   Destroy=function() end,
  }
 end
 local Equipment=assert(loadstring(sources.EquipmentConfig))()
 local Progression=assert(loadstring(sources.ProgressionConfig))()
 local Field=assert(loadstring(sources.FieldConfig))()
 local Worlds=assert(loadstring(sources.WorldConfig))()
 local Swing=assert(loadstring(sources.SwingConfig))()
 local world=Worlds.Get(Worlds.StartingWorldId)
 local heartbeat=signal()
 local forceLegendary,forceMythic=false,false
 -- What the ground raycast finds under the ball (anything: touching the ground; nil: airborne).
 local rayHit={}
 local workspaceFake={Gravity=196.2,GetServerTimeNow=os.clock,Raycast=function() return rayHit end,
  GetAttribute=function(_,name)
   if name=="ForceLegendaryHit" then return forceLegendary or nil end
   if name=="ForceMythicHit" then return forceMythic or nil end
   return nil
  end}
 local balls={}
 for _,definition in Worlds.Worlds do
  local ball=object()
  ball.Size,ball.Touched,ball.AssemblyMass=Vector3.one,signal(),1
  ball.SetNetworkOwner=function() end
  setmetatable(ball,{__index=function(t,key) if key=="Position" then return t.CFrame.Position end end})
  balls[definition.id]=ball
  local pad=object()
  pad:SetAttribute("OccupantUserId",1)
  workspaceFake[definition.stationName]={Baseball=ball,BatterPosition=pad,
   Tee={Stem={BallPosition={WorldCFrame=CFrame.new(0,3,0)}}},HitDirection={Position=Vector3.new(0,3,-10)},
   WaitForChild=function(_,name) assert(name=="Baseball") return ball end}
  local field=object()
  field.Ground=Instance.new("Folder")
  workspaceFake[definition.fieldName]=field
 end
 function workspaceFake:WaitForChild(name) return assert(self[name],name) end
 local players={}
 local player=object()
 player.Name,player.UserId,player.Parent="Fixture",1,players
 player.Character={FindFirstChildOfClass=function() return {Health=100} end}
 player.leaderstats={Cash={Value=0}}
 player.AddReplicationFocus,player.RemoveReplicationFocus=function() end,function() end
 player:SetAttribute("CurrentWorldId",world.id)
 player:SetAttribute("BattingActive",true)
 local tool=object()
 tool.Parent=player.Character
 tool:SetAttribute("BattingSession",1)
 local grants,delayed,cashReports={},{},{}
 local juiceCash = 1
 local completionMessage = nil
 local modules={EquipmentConfig=Equipment,ProgressionConfig=Progression,FieldConfig=Field,WorldConfig=Worlds,SwingConfig=Swing,
  WorldProgress={Complete=function() return completionMessage end},
  PlayerData={IsReady=function() return true end,RecordBattingCash=function(_,amount) table.insert(cashReports,amount) end,GetJuiceMultiplier=function(_,effect) return effect=="Cash" and juiceCash or 1 end,GrantPower=function(_,base,source,ballId,boost)
   table.insert(grants,{base=base,source=source,ballId=ballId,boost=boost})
   return true,{powerGranted=Progression.GetPowerGrant(base,1,Equipment.Get("Ball",ballId).powerGainMultiplier)}
  end}}
 local storage={WaitForChild=function(_,name) return name end,BattingTiming={FireClient=function() end}}
 local services={Workspace=workspaceFake,RunService={Heartbeat=heartbeat,IsStudio=function() return true end},Players=players,ReplicatedStorage=storage}
 local ready={GetAttribute=function() return true end}
 local created={}
 local testTime = 100
 local env=setmetatable({
  game={GetService=function(_,name) return assert(services[name],name) end},
  script={Parent={WaitForChild=function(_,name) return name=="FieldServer" and ready or name end}},
  require=function(name) return assert(modules[name],name) end,
  Instance={new=function(class)
   local instance=object()
   instance.ClassName=class
   instance.Destroy=function(self) self.destroyed=true end
   table.insert(created,instance)
   return instance
  end},
  task={delay=function(seconds,fn,...) table.insert(delayed,{seconds=seconds,fn=fn,args=table.pack(...)}) end},
  print=function() end,
  os={clock=function() return testTime end},
 },{__index=getfenv()})
 local run=assert(loadstring(sources.BallLauncher))
 setfenv(run,env)
 local Launcher=run()
 local velocity
 for _,bat in Equipment.GetItems("Bat") do
  for _,ballItem in Equipment.GetItems("Ball") do
   local result={worldId=world.id,session=1,swingId=passed+1,launchLevel=5,ballId=ballItem.id,batCashMultiplier=bat.cashMultiplier}
   check(Launcher.TryLaunch(player,result,tool),"valid hit accepted")
   check(not Launcher.TryLaunch(player,table.clone(result),tool),"busy station cannot accept another hit")
   local callback=table.remove(delayed,1)
   callback.fn(table.unpack(callback.args,1,callback.args.n))
   local ball=balls[world.id]
   velocity=velocity or ball.AssemblyLinearVelocity
   check((ball.AssemblyLinearVelocity-velocity).Magnitude<.00001,"all Bat/Ball combinations produce identical Level-based velocity")
   check(result.launchSpeed==Progression.GetLaunchSpeed(5) and result.launchAngleDegrees==Progression.GetLaunchAngle(5)
    and result.launchGravityScale==Progression.GetLaunchGravityScale(5),"launch strength, loft and early gravity remain Level-based")
   -- Change the display selection after acceptance; the reward must use the snapshot.
   player:SetAttribute("EquippedBall",ballItem.id=="baseball" and "practice_ball" or "baseball")
   player:SetAttribute("EquippedBat",bat.id=="wood_bat" and "amethyst_bat" or "wood_bat")
   ball.CFrame=CFrame.new(0,.5,-100)
   ball.AssemblyLinearVelocity,ball.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
   local count,cash=#grants,player.leaderstats.Cash.Value
   -- Ten seconds in play: the hit's Power follows its time (Training base x HitPowerPerSecond).
   testTime += 10
   heartbeat:Fire(Field.StopHoldSeconds+.01)
   local expectedCash=Progression.GetHitCash(100,world.cashMultiplier,1,bat.cashMultiplier)
   check(result.distanceResult.distanceStuds==100,"equipment does not change measured distance")
   check(player.leaderstats.Cash.Value-cash==expectedCash,"Cash uses only the Bat and field multiplier (never the Ball)")
   check(cashReports[#cashReports]==player.leaderstats.Cash.Value-cash,"the paid Cash is reported once for the tutorial")
   check(#grants==count+1 and grants[#grants].ballId==ballItem.id and grants[#grants].source=="CompletedHit"
    and grants[#grants].base==Progression.GetHitPowerBase(10),
    "completed hit grants Power once with the accepted Ball snapshot, from its time in play")
   check(result.distanceResult.powerEarned==Progression.GetPowerGrant(Progression.GetHitPowerBase(10),1,ballItem.powerGainMultiplier),
    "hit Power includes the Ball and Rebirth exactly once, never the Bat (whole Power)")
   heartbeat:Fire(10)
   Launcher.CancelPlayer(player)
   check(#grants==count+1 and player.leaderstats.Cash.Value-cash==expectedCash,"reset and extra samples never duplicate rewards")
   check(ball:GetAttribute("BallState")=="Ready" and not Launcher.IsBusy(world.id),"hit resets cleanly")
  end
 end
 -- Juices count as the swing's snapshot (taken when it was accepted): a Cash Splash and Power
 -- Punch running at the swing still pay this hit after they end mid-flight (the live juice is
 -- 1 by then), and one drunk mid-flight (live 2) adds nothing to a hit swung without it.
 local function juicedHit(swingId, cashJuice, powerJuice, liveCash)
  local hit={worldId=world.id,session=1,swingId=swingId,launchLevel=5,ballId="baseball",batCashMultiplier=1,
   cashJuiceMultiplier=cashJuice,powerJuiceMultiplier=powerJuice}
  check(Launcher.TryLaunch(player,hit,tool),"juiced hit accepted")
  local launch=table.remove(delayed,1)
  launch.fn(table.unpack(launch.args,1,launch.args.n))
  juiceCash = liveCash
  balls[world.id].CFrame=CFrame.new(0,.5,-100)
  balls[world.id].AssemblyLinearVelocity,balls[world.id].AssemblyAngularVelocity=Vector3.zero,Vector3.zero
  local cashBefore=player.leaderstats.Cash.Value
  heartbeat:Fire(Field.StopHoldSeconds+.01)
  Launcher.CancelPlayer(player)
  juiceCash = 1
  return hit, player.leaderstats.Cash.Value-cashBefore, grants[#grants]
 end
 local juiced, juicedCash, juicedGrant = juicedHit(700, 2, 2, 1)
 check(juicedCash==Progression.GetHitCash(100,world.cashMultiplier,1,1,2)
  and Progression.GetHitCash(100,world.cashMultiplier,1,1,2)>Progression.GetHitCash(100,world.cashMultiplier,1,1)
  and juiced.distanceResult.distanceStuds==100,"Cash Splash at the swing doubles that hit's Cash (before rounding), even if it ends mid-flight, without changing distance")
 check(juicedGrant.source=="CompletedHit" and juicedGrant.boost==2,"Power Punch at the swing doubles that hit's Power, even if it ends mid-flight")
 local _, laterCash, laterGrant = juicedHit(701, 1, 1, 2)
 check(laterCash==Progression.GetHitCash(100,world.cashMultiplier,1,1) and laterGrant.boost==1,
  "a juice drunk after the swing does not boost that hit")
 local _, splashCash, splashGrant = juicedHit(702, 2, 1, 2)
 check(splashCash==Progression.GetHitCash(100,world.cashMultiplier,1,1,2) and splashGrant.boost==1,
  "Cash Splash alone leaves the hit's Power alone")
 -- Worked Cash formula: (distance / 80)^1.5 x World x section x Bat, rounded once. A 3x Bat
 -- landing in a 1.35x section; swapping the Ball (a Power item) changes nothing.
 local tierDistance=100
 while Field.GetRewardSection(tierDistance,world).rewardMultiplier~=1.35 do tierDistance+=50 end
 for index,ballId in {"baseball","supernova_ball"} do
  local hit={worldId=world.id,session=1,swingId=710+index,launchLevel=5,ballId=ballId,batCashMultiplier=Equipment.Get("Bat","amethyst_bat").cashMultiplier}
  check(Launcher.TryLaunch(player,hit,tool),"formula hit accepted")
  local launch=table.remove(delayed,1)
  launch.fn(table.unpack(launch.args,1,launch.args.n))
  balls[world.id].CFrame=CFrame.new(0,.5,-tierDistance)
  balls[world.id].AssemblyLinearVelocity,balls[world.id].AssemblyAngularVelocity=Vector3.zero,Vector3.zero
  local before=player.leaderstats.Cash.Value
  heartbeat:Fire(Field.StopHoldSeconds+.01)
  local expected=math.floor((tierDistance/80)^1.5*world.cashMultiplier*1.35*3+.5)
  check(Equipment.Get("Bat","amethyst_bat").cashMultiplier==3 and player.leaderstats.Cash.Value-before==expected,
   "Cash = (distance / 80)^1.5 x section 1.35 x Bat 3 with the " .. ballId .. " (the Ball never changes Cash)")
  Launcher.CancelPlayer(player)
 end
 -- A Legendary Hit only waits longer: the same launch, distance and Cash follow.
 local normalHit={worldId=world.id,session=1,swingId=750,launchLevel=5,ballId="baseball",batCashMultiplier=1}
 check(Launcher.TryLaunch(player,normalHit,tool),"normal hit accepted")
 local normalLaunch=table.remove(delayed,1)
 normalLaunch.fn(table.unpack(normalLaunch.args,1,normalLaunch.args.n))
 local normalVelocity=balls[world.id].AssemblyLinearVelocity
 Launcher.CancelPlayer(player)
 -- Juices change only rewards: a hit with both running launches exactly like one without.
 local juiced={worldId=world.id,session=1,swingId=749,launchLevel=5,ballId="supernova_ball",batCashMultiplier=28,
  powerJuiceMultiplier=2,cashJuiceMultiplier=2}
 check(Launcher.TryLaunch(player,juiced,tool),"juiced hit accepted")
 local juicedLaunch=table.remove(delayed,1)
 juicedLaunch.fn(table.unpack(juicedLaunch.args,1,juicedLaunch.args.n))
 check((balls[world.id].AssemblyLinearVelocity-normalVelocity).Magnitude<.00001
  and juiced.launchGravityScale==normalHit.launchGravityScale,"Power Punch / Cash Splash never change the launch")
 Launcher.CancelPlayer(player)
 -- A new player's hit (Level 1) leaves the tee rising, at its early-launch speed and angle.
 local firstHit={worldId=world.id,session=1,swingId=748,launchLevel=1,ballId="baseball",batCashMultiplier=1}
 check(Launcher.TryLaunch(player,firstHit,tool),"Level 1 hit accepted")
 local firstLaunch=table.remove(delayed,1)
 firstLaunch.fn(table.unpack(firstLaunch.args,1,firstLaunch.args.n))
 local firstVelocity=balls[world.id].AssemblyLinearVelocity
 local firstFlat=Vector3.new(firstVelocity.X,0,firstVelocity.Z).Magnitude
 check(firstVelocity.Y>0 and math.abs(math.deg(math.atan2(firstVelocity.Y,firstFlat))-Progression.EarlyLaunch.angleDegrees)<.001
  and math.abs(firstVelocity.Magnitude-Progression.EarlyLaunch.speed*Field.HitTimeScale)<.001,
  "the Level 1 hit launches upward at the early-launch speed and angle")
 -- Until its first landing an early hit falls at its lighter gravity (the time scale's gravity
 -- force, lifted by the scale); the first ground contact restores normal gravity for good.
 local ball=balls[world.id]
 local function gravityForce(scale)
  return -Vector3.yAxis*ball.AssemblyMass*workspaceFake.Gravity*(Field.HitTimeScale^2*scale-1)
 end
 local earlyScale=Progression.EarlyLaunch.gravityScale
 local firstAttachment,firstForce=created[#created-1],created[#created]
 check(firstForce.ClassName=="VectorForce" and earlyScale<1 and firstHit.launchGravityScale==earlyScale
  and ball:GetAttribute("LaunchGravityScale")==earlyScale and (firstForce.Force-gravityForce(earlyScale)).Magnitude<.001,
  "the Level 1 hit leaves the tee at the early, lighter gravity")
 rayHit=nil
 heartbeat:Fire(1/60)
 check((firstForce.Force-gravityForce(earlyScale)).Magnitude<.001,"the lighter gravity holds while the ball is airborne")
 local groundPart={IsDescendantOf=function(_,ancestor) return ancestor==workspaceFake[world.fieldName].Ground end}
 ball.Touched:Fire(groundPart)
 check((firstForce.Force-gravityForce(1)).Magnitude<.001,"the first ground contact restores normal gravity")
 heartbeat:Fire(1/60)
 check(math.abs(firstForce.Force.Y-gravityForce(1).Y)<.001,"bounces after the first landing keep normal gravity")
 rayHit={}
 Launcher.CancelPlayer(player)
 check(firstForce.destroyed and firstAttachment.destroyed and ball:GetAttribute("LaunchGravityScale")==nil
  and ball:GetAttribute("BallState")=="Ready","ending the hit removes its force and attachment from the ball")
 -- The ground raycast counts as a landing too (a Level 10 hit, still partly lighter).
 local midHit={worldId=world.id,session=1,swingId=747,launchLevel=10,ballId="baseball",batCashMultiplier=1}
 check(Launcher.TryLaunch(player,midHit,tool),"Level 10 hit accepted")
 local midLaunch=table.remove(delayed,1)
 midLaunch.fn(table.unpack(midLaunch.args,1,midLaunch.args.n))
 local midForce=created[#created]
 local midScale=Progression.GetLaunchGravityScale(10)
 check(midScale>earlyScale and midScale<1 and (midForce.Force-gravityForce(midScale)).Magnitude<.001,
  "a Level 10 hit gets less of the lighter gravity")
 heartbeat:Fire(1/60)
 check(math.abs(midForce.Force.Y-gravityForce(1).Y)<.001,"touching the ground (raycast) restores normal gravity")
 Launcher.CancelPlayer(player)
 check(midForce.destroyed and created[#created-1].destroyed,"a cancelled hit leaves no force behind")
 -- Level 21 launches exactly as before the early curve: the table's 78 studs/s at 38 degrees,
 -- under the plain time-scaled gravity.
 local level21={worldId=world.id,session=1,swingId=746,launchLevel=21,ballId="baseball",batCashMultiplier=1}
 check(Launcher.TryLaunch(player,level21,tool),"Level 21 hit accepted")
 local level21Launch=table.remove(delayed,1)
 level21Launch.fn(table.unpack(level21Launch.args,1,level21Launch.args.n))
 local loft=math.rad(38)
 local oldVelocity=(Vector3.new(0,0,-1)*(78*math.cos(loft))+Vector3.yAxis*(78*math.sin(loft)))*Field.HitTimeScale
 local oldForce=-Vector3.yAxis*ball.AssemblyMass*workspaceFake.Gravity*(Field.HitTimeScale^2-1)
 check(level21.launchSpeed==78 and level21.launchAngleDegrees==38 and level21.launchGravityScale==1
  and (ball.AssemblyLinearVelocity-oldVelocity).Magnitude<.0001 and (created[#created].Force-oldForce).Magnitude<.0001,
  "a Level 21 hit is unchanged: 78 studs/s, 38 degrees, normal gravity")
 Launcher.CancelPlayer(player)
 forceLegendary=true
 local legendary={worldId=world.id,session=1,swingId=751,launchLevel=5,ballId="baseball",batCashMultiplier=1}
 check(Launcher.TryLaunch(player,legendary,tool),"legendary hit accepted")
 forceLegendary=false
 local legendaryBall=balls[world.id]
 local legendaryLaunch=table.remove(delayed,1)
 check(math.abs(legendaryLaunch.seconds-normalLaunch.seconds-Swing.LegendaryHit.HoldSeconds)<.0001,"legendary hit holds the launch")
 check(legendaryBall:GetAttribute("LegendaryHitUserId")==player.UserId and legendaryBall:GetAttribute("LegendaryLaunchAt")~=nil,
  "legendary hit is published on the ball")
 check(legendaryBall:GetAttribute("BallState")=="Reserved","ball waits on the tee during the hold")
 legendaryLaunch.fn(table.unpack(legendaryLaunch.args,1,legendaryLaunch.args.n))
 check((legendaryBall.AssemblyLinearVelocity-normalVelocity).Magnitude<.00001 and legendary.launchSpeed==Progression.GetLaunchSpeed(5),
  "legendary hit launches exactly like a normal one")
 legendaryBall.CFrame=CFrame.new(0,.5,-100)
 legendaryBall.AssemblyLinearVelocity,legendaryBall.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
 local legendaryCash=player.leaderstats.Cash.Value
 heartbeat:Fire(Field.StopHoldSeconds+.01)
 check(player.leaderstats.Cash.Value-legendaryCash==Progression.GetHitCash(100,world.cashMultiplier,1,1)
  and legendary.distanceResult.distanceStuds==100,"legendary hit rewards are unchanged")
 check(legendaryBall:GetAttribute("LegendaryHitUserId")==nil and legendaryBall:GetAttribute("LegendaryLaunchAt")==nil,
  "ball reset clears the legendary attributes")
 Launcher.CancelPlayer(player)
 -- A Mythic Hit holds longer, launches the same, and its attributes clear on cancel.
 forceMythic=true
 local mythic={worldId=world.id,session=1,swingId=752,launchLevel=5,ballId="baseball",batCashMultiplier=1}
 check(Launcher.TryLaunch(player,mythic,tool),"mythic hit accepted")
 forceMythic=false
 local mythicLaunch=table.remove(delayed,1)
 check(math.abs(mythicLaunch.seconds-normalLaunch.seconds-Swing.MythicHit.HoldSeconds)<.0001,"mythic hit holds the launch longer")
 check(legendaryBall:GetAttribute("MythicHitUserId")==player.UserId and legendaryBall:GetAttribute("LegendaryHitUserId")==nil,
  "mythic hit is published on the ball, without a legendary roll")
 mythicLaunch.fn(table.unpack(mythicLaunch.args,1,mythicLaunch.args.n))
 check((legendaryBall.AssemblyLinearVelocity-normalVelocity).Magnitude<.00001,"mythic hit launches exactly like a normal one")
 Launcher.CancelPlayer(player)
 check(legendaryBall:GetAttribute("MythicHitUserId")==nil and legendaryBall:GetAttribute("MythicLaunchAt")==nil,
  "cancel clears the mythic attributes")
 -- Both forced in Studio: they take turns.
 forceLegendary,forceMythic=true,true
 local kinds={}
 for i=1,2 do
  check(Launcher.TryLaunch(player,{worldId=world.id,session=1,swingId=760+i,launchLevel=5,ballId="baseball",batCashMultiplier=1},tool),"forced hit accepted")
  kinds[i]=legendaryBall:GetAttribute("MythicHitUserId") and "Mythic" or legendaryBall:GetAttribute("LegendaryHitUserId") and "Legendary"
  table.remove(delayed,1)
  Launcher.CancelPlayer(player)
 end
 check(kinds[1]~=kinds[2] and kinds[1]~=nil and kinds[2]~=nil,"both forced: Mythic and Legendary take turns")
 forceLegendary,forceMythic=false,false
 -- Shipped config: 2x is disabled, so requests are rejected and no speed state is published.
 check(not Field.FlightSpeedUpEnabled,"2x ball flight ships disabled")
 local disabled={worldId=world.id,session=1,swingId=800,launchLevel=5,ballId="baseball",batCashMultiplier=1}
 check(Launcher.TryLaunch(player,disabled,tool),"hit accepted while 2x is disabled")
 local disabledLaunch=table.remove(delayed,1)
 disabledLaunch.fn(table.unpack(disabledLaunch.args,1,disabledLaunch.args.n))
 local disabledVelocity=balls[world.id].AssemblyLinearVelocity
 check(player:GetAttribute("BallFlightSpeed")==nil,"no 2x button state is published while disabled")
 check(not Launcher.SpeedUp(player,1) and (balls[world.id].AssemblyLinearVelocity-disabledVelocity).Magnitude<.00001,
  "disabled 2x requests never change the ball")
 Launcher.CancelPlayer(player)
 -- The remaining checks keep the 2x code path tested in case it is re-enabled.
 Field.FlightSpeedUpEnabled=true
 local result={worldId=world.id,session=1,swingId=900,launchLevel=5,ballId="baseball",batCashMultiplier=1}
 check(not Launcher.SpeedUp(player,1),"no hit cannot speed up")
 check(Launcher.TryLaunch(player,result,tool),"speed test hit accepted")
 check(not Launcher.SpeedUp(player,1),"cannot speed up before contact")
 local callback=table.remove(delayed,1)
 callback.fn(table.unpack(callback.args,1,callback.args.n))
 local ball=balls[world.id]
 local normalVelocity=ball.AssemblyLinearVelocity
 local stranger=object()
 stranger:SetAttribute("CurrentWorldId",world.id)
 check(not Launcher.SpeedUp(stranger,1),"another player cannot accelerate this ball")
 check(not Launcher.SpeedUp(player,2),"wrong session rejected")
 check(Launcher.SpeedUp(player,1),"owner may speed up live hit")
 check((ball.AssemblyLinearVelocity-normalVelocity*2).Magnitude<.00001,"velocity doubles")
 local force=created[#created]
 -- (A Level 5 hit is still in its lighter early gravity, which the time scale multiplies too.)
 local airborneScale=Progression.GetLaunchGravityScale(5)
 check(force.ClassName=="VectorForce" and math.abs(force.Force.Y+ball.AssemblyMass*workspaceFake.Gravity*((2*Field.HitTimeScale)^2*airborneScale-1))<.0001,
  "extra gravity scales total acceleration by four without changing workspace gravity")
 check(player:GetAttribute("BallFlightSpeed")==2,"speed replicated for UI")
 for _=1,3 do
  testTime += 1
  check(not Launcher.SpeedUp(player,1),"2x is one-way: later requests cannot turn it off or reapply it")
 end
 check((ball.AssemblyLinearVelocity-normalVelocity*2).Magnitude<.00001 and player:GetAttribute("BallFlightSpeed")==2,
  "rejected requests never compound or restore velocity")
 check(math.abs(force.Force.Y+ball.AssemblyMass*workspaceFake.Gravity*((2*Field.HitTimeScale)^2*airborneScale-1))<.0001,"rejected requests leave the 2x gravity unchanged")
 check(result.launchSpeed==Progression.GetLaunchSpeed(5),"speedup does not change Level launch strength")
 ball.CFrame=CFrame.new(0,.5,-100)
 ball.AssemblyLinearVelocity,ball.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
 local cash=player.leaderstats.Cash.Value
 heartbeat:Fire(Field.StopHoldSeconds/2+.01)
 check(result.distanceResult and result.distanceResult.distanceStuds==100,"scaled stop timer finalizes real position")
 local plainCash=Progression.GetHitCash(100,world.cashMultiplier,1,1)
 check(player.leaderstats.Cash.Value==cash+plainCash,"speedup does not multiply Cash")
 heartbeat:Fire(10)
 check(player.leaderstats.Cash.Value==cash+plainCash,"accelerated hit awards only once")
 check(player:GetAttribute("BallFlightSpeed")==nil and ball:GetAttribute("BallState")=="Ready","reset clears speed state")
 check(Launcher.TryLaunch(player,table.clone(result),tool),"next hit can start")
 callback=table.remove(delayed,1)
 callback.fn(table.unpack(callback.args,1,callback.args.n))
 check(player:GetAttribute("BallFlightSpeed")==1,"next hit starts at normal speed")
 Launcher.CancelPlayer(player)
 check(player:GetAttribute("BallFlightSpeed")==nil,"cancellation clears speed")
 Field.FlightSpeedUpEnabled=false
 -- The end portal: a ball reaching the endpoint at any height is pulled in, the hit counts at
 -- the endpoint, and only a first completion (with an unlocked next World) starts the trip.
 local gate=Vector3.new(0,150,-world.endDistance)
 workspaceFake[world.fieldName]:SetAttribute("GateCenter",gate)
 local journeys={}
 Launcher.OnPortalJourney=function(who,from,to) table.insert(journeys,{who=who,from=from,to=to}) end
 player:SetAttribute("WorldUnlocked_"..world.nextWorldId,true)
 local function portalHit(swingId)
  local hit={worldId=world.id,session=1,swingId=swingId,launchLevel=5,ballId="baseball",batCashMultiplier=1}
  check(Launcher.TryLaunch(player,hit,tool),"portal hit accepted")
  local launchNow=table.remove(delayed,1)
  launchNow.fn(table.unpack(launchNow.args,1,launchNow.args.n))
  local portalBall=balls[world.id]
  portalBall.CFrame=CFrame.new(0,420,-(world.endDistance+3))
  heartbeat:Fire(1/60)
  check(portalBall.Anchored==true and portalBall:GetAttribute("PortalCaptured")==true and hit.distanceResult==nil,
   "reaching the endpoint high in the air, the portal captures the ball before the hit ends")
  testTime += 0.7
  heartbeat:Fire(1/60)
  check(hit.distanceResult==nil and (portalBall.CFrame.Position-gate).Magnitude<(Vector3.new(0,420,-(world.endDistance+3))-gate).Magnitude,
   "the captured ball is drawn toward the opening")
  testTime += 1
  heartbeat:Fire(1/60)
  return hit,portalBall
 end
 completionMessage=nil
 local repeatHit,portalBall=portalHit(950)
 check(repeatHit.distanceResult and repeatHit.distanceResult.distanceStuds==world.endDistance and repeatHit.distanceResult.finishReason=="portal",
  "a portal hit is measured at the World's endpoint")
 check(portalBall:GetAttribute("BallState")=="Ready" and portalBall:GetAttribute("PortalCaptured")==nil and not Launcher.IsBusy(world.id),
  "the ball resets after entering the portal")
 check(#journeys==0,"an already-completed World does not start the trip again")
 completionMessage="World 1 Complete!"
 local firstHit=portalHit(951)
 check(firstHit.distanceResult.worldCompletionMessage==completionMessage,"the portal hit completes the World")
 check(#journeys==1 and journeys[1].who==player and journeys[1].to.id==world.nextWorldId,"a first completion starts the trip to the next World")
 completionMessage=nil
 -- Through the last World's portal (World 3 for now) a first completion plays the finale
 -- instead of a trip.
 local last=Worlds.Get("world_3")
 workspaceFake[last.fieldName]:SetAttribute("GateCenter",Vector3.new(0,150,-last.endDistance))
 local finales={}
 Launcher.OnGameFinale=function(who,from) table.insert(finales,{who=who,from=from}) end
 player:SetAttribute("CurrentWorldId",last.id)
 local function lastPortalHit(swingId)
  local hit={worldId=last.id,session=1,swingId=swingId,launchLevel=5,ballId="baseball",batCashMultiplier=1}
  check(Launcher.TryLaunch(player,hit,tool),"last World portal hit accepted")
  local launchNow=table.remove(delayed,1)
  launchNow.fn(table.unpack(launchNow.args,1,launchNow.args.n))
  balls[last.id].CFrame=CFrame.new(0,420,-(last.endDistance+3))
  heartbeat:Fire(1/60)
  testTime += 1.7
  heartbeat:Fire(1/60)
  return hit
 end
 local repeatLast=lastPortalHit(960)
 check(repeatLast.distanceResult and repeatLast.distanceResult.finishReason=="portal" and repeatLast.distanceResult.distanceStuds==last.endDistance
  and #finales==0,"a repeat completion of the last World plays no finale")
 completionMessage="World 3 Complete!"
 lastPortalHit(961)
 check(#finales==1 and finales[1].who==player and finales[1].from.id==last.id and #journeys==1,
  "a first completion of the last World plays the finale, not a trip")
 completionMessage=nil
 player:SetAttribute("CurrentWorldId",world.id)
 for _,definition in Worlds.Worlds do workspaceFake[definition.fieldName].Ground:Destroy() end
 return {passed=passed,message="Launch/rewards and 2x flight: authorization, one-way speed, acceleration, reset and once-only rewards"}
end
