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
 local workspaceFake={Gravity=196.2,GetServerTimeNow=os.clock,Raycast=function() return {} end,
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
 local grants,delayed={},{}
 local juiceCash = 1
 local completionMessage = nil
 local modules={EquipmentConfig=Equipment,ProgressionConfig=Progression,FieldConfig=Field,WorldConfig=Worlds,SwingConfig=Swing,
  WorldProgress={Complete=function() return completionMessage end},
  PlayerData={IsReady=function() return true end,GetJuiceMultiplier=function(_,effect) return effect=="Cash" and juiceCash or 1 end,GrantPower=function(_,base,source,batId)
   table.insert(grants,{base=base,source=source,batId=batId})
   return true,{powerGranted=Progression.GetPowerGrant(base,1,Equipment.Get("Bat",batId).powerGainMultiplier)}
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
  Instance={new=function(class) local instance=object() instance.ClassName=class table.insert(created,instance) return instance end},
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
   local result={worldId=world.id,session=1,swingId=passed+1,launchLevel=5,batId=bat.id,ballRewardMultiplier=ballItem.rewardMultiplier}
   check(Launcher.TryLaunch(player,result,tool),"valid hit accepted")
   check(not Launcher.TryLaunch(player,table.clone(result),tool),"busy station cannot accept another hit")
   local callback=table.remove(delayed,1)
   callback.fn(table.unpack(callback.args,1,callback.args.n))
   local ball=balls[world.id]
   velocity=velocity or ball.AssemblyLinearVelocity
   check((ball.AssemblyLinearVelocity-velocity).Magnitude<.00001,"all Bat/Ball combinations produce identical Level-based velocity")
   check(result.launchSpeed==115 and result.launchAngleDegrees==38,"launch strength and loft remain Level-based")
   -- Change the display selection after acceptance; the reward must use the snapshot.
   player:SetAttribute("EquippedBat",bat.id=="wood_bat" and "amethyst_bat" or "wood_bat")
   ball.CFrame=CFrame.new(0,.5,-100)
   ball.AssemblyLinearVelocity,ball.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
   local count,cash=#grants,player.leaderstats.Cash.Value
   heartbeat:Fire(Field.StopHoldSeconds+.01)
   check(result.distanceResult.distanceStuds==100,"equipment does not change measured distance")
   check(player.leaderstats.Cash.Value-cash==math.floor(100*ballItem.rewardMultiplier),"Cash uses only Ball and field multiplier")
   check(#grants==count+1 and grants[#grants].batId==bat.id and grants[#grants].source=="CompletedHit",
    "completed hit grants Power once with accepted Bat snapshot")
   check(result.distanceResult.powerEarned==math.floor(2*bat.powerGainMultiplier*2),"hit reward includes Bat and Rebirth exactly once (whole Power)")
   heartbeat:Fire(10)
   Launcher.CancelPlayer(player)
   check(#grants==count+1 and player.leaderstats.Cash.Value-cash==math.floor(100*ballItem.rewardMultiplier),"reset and extra samples never duplicate rewards")
   check(ball:GetAttribute("BallState")=="Ready" and not Launcher.IsBusy(world.id),"hit resets cleanly")
  end
 end
 -- An active Cash juice multiplies the hit's Cash reward (and only Cash).
 juiceCash = 2
 local juiced={worldId=world.id,session=1,swingId=700,launchLevel=5,batId="wood_bat",ballRewardMultiplier=1}
 check(Launcher.TryLaunch(player,juiced,tool),"juiced hit accepted")
 local juicedLaunch=table.remove(delayed,1)
 juicedLaunch.fn(table.unpack(juicedLaunch.args,1,juicedLaunch.args.n))
 balls[world.id].CFrame=CFrame.new(0,.5,-100)
 balls[world.id].AssemblyLinearVelocity,balls[world.id].AssemblyAngularVelocity=Vector3.zero,Vector3.zero
 local cashBefore=player.leaderstats.Cash.Value
 heartbeat:Fire(Field.StopHoldSeconds+.01)
 check(player.leaderstats.Cash.Value-cashBefore==200 and juiced.distanceResult.distanceStuds==100,"Cash juice doubles Cash without changing distance")
 Launcher.CancelPlayer(player)
 juiceCash = 1
 -- A Legendary Hit only waits longer: the same launch, distance and Cash follow.
 local normalHit={worldId=world.id,session=1,swingId=750,launchLevel=5,batId="wood_bat",ballRewardMultiplier=1}
 check(Launcher.TryLaunch(player,normalHit,tool),"normal hit accepted")
 local normalLaunch=table.remove(delayed,1)
 normalLaunch.fn(table.unpack(normalLaunch.args,1,normalLaunch.args.n))
 local normalVelocity=balls[world.id].AssemblyLinearVelocity
 Launcher.CancelPlayer(player)
 forceLegendary=true
 local legendary={worldId=world.id,session=1,swingId=751,launchLevel=5,batId="wood_bat",ballRewardMultiplier=1}
 check(Launcher.TryLaunch(player,legendary,tool),"legendary hit accepted")
 forceLegendary=false
 local legendaryBall=balls[world.id]
 local legendaryLaunch=table.remove(delayed,1)
 check(math.abs(legendaryLaunch.seconds-normalLaunch.seconds-Swing.LegendaryHit.HoldSeconds)<.0001,"legendary hit holds the launch")
 check(legendaryBall:GetAttribute("LegendaryHitUserId")==player.UserId and legendaryBall:GetAttribute("LegendaryLaunchAt")~=nil,
  "legendary hit is published on the ball")
 check(legendaryBall:GetAttribute("BallState")=="Reserved","ball waits on the tee during the hold")
 legendaryLaunch.fn(table.unpack(legendaryLaunch.args,1,legendaryLaunch.args.n))
 check((legendaryBall.AssemblyLinearVelocity-normalVelocity).Magnitude<.00001 and legendary.launchSpeed==115,
  "legendary hit launches exactly like a normal one")
 legendaryBall.CFrame=CFrame.new(0,.5,-100)
 legendaryBall.AssemblyLinearVelocity,legendaryBall.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
 local legendaryCash=player.leaderstats.Cash.Value
 heartbeat:Fire(Field.StopHoldSeconds+.01)
 check(player.leaderstats.Cash.Value-legendaryCash==100 and legendary.distanceResult.distanceStuds==100,"legendary hit rewards are unchanged")
 check(legendaryBall:GetAttribute("LegendaryHitUserId")==nil and legendaryBall:GetAttribute("LegendaryLaunchAt")==nil,
  "ball reset clears the legendary attributes")
 Launcher.CancelPlayer(player)
 -- A Mythic Hit holds longer, launches the same, and its attributes clear on cancel.
 forceMythic=true
 local mythic={worldId=world.id,session=1,swingId=752,launchLevel=5,batId="wood_bat",ballRewardMultiplier=1}
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
  check(Launcher.TryLaunch(player,{worldId=world.id,session=1,swingId=760+i,launchLevel=5,batId="wood_bat",ballRewardMultiplier=1},tool),"forced hit accepted")
  kinds[i]=legendaryBall:GetAttribute("MythicHitUserId") and "Mythic" or legendaryBall:GetAttribute("LegendaryHitUserId") and "Legendary"
  table.remove(delayed,1)
  Launcher.CancelPlayer(player)
 end
 check(kinds[1]~=kinds[2] and kinds[1]~=nil and kinds[2]~=nil,"both forced: Mythic and Legendary take turns")
 forceLegendary,forceMythic=false,false
 -- Shipped config: 2x is disabled, so requests are rejected and no speed state is published.
 check(not Field.FlightSpeedUpEnabled,"2x ball flight ships disabled")
 local disabled={worldId=world.id,session=1,swingId=800,launchLevel=5,batId="wood_bat",ballRewardMultiplier=1}
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
 local result={worldId=world.id,session=1,swingId=900,launchLevel=5,batId="wood_bat",ballRewardMultiplier=1}
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
 check(force.ClassName=="VectorForce" and math.abs(force.Force.Y+ball.AssemblyMass*workspaceFake.Gravity*((2*Field.HitTimeScale)^2-1))<.0001,
  "extra gravity scales total acceleration by four without changing workspace gravity")
 check(player:GetAttribute("BallFlightSpeed")==2,"speed replicated for UI")
 for _=1,3 do
  testTime += 1
  check(not Launcher.SpeedUp(player,1),"2x is one-way: later requests cannot turn it off or reapply it")
 end
 check((ball.AssemblyLinearVelocity-normalVelocity*2).Magnitude<.00001 and player:GetAttribute("BallFlightSpeed")==2,
  "rejected requests never compound or restore velocity")
 check(math.abs(force.Force.Y+ball.AssemblyMass*workspaceFake.Gravity*((2*Field.HitTimeScale)^2-1))<.0001,"rejected requests leave the 2x gravity unchanged")
 check(result.launchSpeed==115,"speedup does not change Level launch strength")
 ball.CFrame=CFrame.new(0,.5,-100)
 ball.AssemblyLinearVelocity,ball.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
 local cash=player.leaderstats.Cash.Value
 heartbeat:Fire(Field.StopHoldSeconds/2+.01)
 check(result.distanceResult and result.distanceResult.distanceStuds==100,"scaled stop timer finalizes real position")
 check(player.leaderstats.Cash.Value==cash+100,"speedup does not multiply Cash")
 heartbeat:Fire(10)
 check(player.leaderstats.Cash.Value==cash+100,"accelerated hit awards only once")
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
  local hit={worldId=world.id,session=1,swingId=swingId,launchLevel=5,batId="wood_bat",ballRewardMultiplier=1}
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
  local hit={worldId=last.id,session=1,swingId=swingId,launchLevel=5,batId="wood_bat",ballRewardMultiplier=1}
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
