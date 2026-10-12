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
 local workspaceFake={Gravity=196.2,GetServerTimeNow=os.clock,Raycast=function() return {} end}
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
  workspaceFake[definition.fieldName]={Ground=Instance.new("Folder")}
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
 local modules={EquipmentConfig=Equipment,ProgressionConfig=Progression,FieldConfig=Field,WorldConfig=Worlds,SwingConfig=Swing,
  WorldProgress={Complete=function() end},
  PlayerData={IsReady=function() return true end,GrantPower=function(_,base,source,batId)
   table.insert(grants,{base=base,source=source,batId=batId})
   return true,{powerGranted=Progression.GetPowerGrant(base,1,Equipment.Get("Bat",batId).powerGainMultiplier)}
  end}}
 local storage={WaitForChild=function(_,name) return name end,BattingTiming={FireClient=function() end}}
 local services={Workspace=workspaceFake,RunService={Heartbeat=heartbeat},Players=players,ReplicatedStorage=storage}
 local ready={GetAttribute=function() return true end}
 local created={}
 local testTime = 100
 local env=setmetatable({
  game={GetService=function(_,name) return assert(services[name],name) end},
  script={Parent={WaitForChild=function(_,name) return name=="FieldServer" and ready or name end}},
  require=function(name) return assert(modules[name],name) end,
  Instance={new=function(class) local instance=object() instance.ClassName=class table.insert(created,instance) return instance end},
  task={delay=function(_,fn,...) table.insert(delayed,{fn=fn,args=table.pack(...)}) end},
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
   player:SetAttribute("EquippedBat",bat.id=="wood_bat" and "carbon_bat" or "wood_bat")
   ball.CFrame=CFrame.new(0,.5,-100)
   ball.AssemblyLinearVelocity,ball.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
   local count,cash=#grants,player.leaderstats.Cash.Value
   heartbeat:Fire(Field.StopHoldSeconds+.01)
   check(result.distanceResult.distanceStuds==100,"equipment does not change measured distance")
   check(player.leaderstats.Cash.Value-cash==math.floor(100*ballItem.rewardMultiplier),"Cash uses only Ball and field multiplier")
   check(#grants==count+1 and grants[#grants].batId==bat.id and grants[#grants].source=="CompletedHit",
    "completed hit grants Power once with accepted Bat snapshot")
   check(result.distanceResult.powerEarned==2*bat.powerGainMultiplier*2,"hit reward includes Bat and Rebirth exactly once")
   heartbeat:Fire(10)
   Launcher.CancelPlayer(player)
   check(#grants==count+1 and player.leaderstats.Cash.Value-cash==math.floor(100*ballItem.rewardMultiplier),"reset and extra samples never duplicate rewards")
   check(ball:GetAttribute("BallState")=="Ready" and not Launcher.IsBusy(world.id),"hit resets cleanly")
  end
 end
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
 check(force.ClassName=="VectorForce" and math.abs(force.Force.Y+ball.AssemblyMass*workspaceFake.Gravity*3)<.0001,
  "extra gravity scales total acceleration by four without changing workspace gravity")
 check(player:GetAttribute("BallFlightSpeed")==2,"speed replicated for UI")
 for _=1,3 do
  testTime += 1
  check(not Launcher.SpeedUp(player,1),"2x is one-way: later requests cannot turn it off or reapply it")
 end
 check((ball.AssemblyLinearVelocity-normalVelocity*2).Magnitude<.00001 and player:GetAttribute("BallFlightSpeed")==2,
  "rejected requests never compound or restore velocity")
 check(math.abs(force.Force.Y+ball.AssemblyMass*workspaceFake.Gravity*3)<.0001,"rejected requests leave the 2x gravity unchanged")
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
 for _,definition in Worlds.Worlds do workspaceFake[definition.fieldName].Ground:Destroy() end
 return {passed=passed,message="Launch/rewards and 2x flight: authorization, one-way speed, acceleration, reset and once-only rewards"}
end
