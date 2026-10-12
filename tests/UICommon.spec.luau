-- Deterministic hover-completion races using the real UICommon source and fake buttons.
-- No live UI, player state, or Instances are modified.
return function(sources)
 local passed = 0
 local function check(condition,message) assert(condition,message) passed+=1 end
 local function signal()
  local callbacks = {}
  local event = {}
  function event:Connect(callback)
   local connection = {Connected=true}
   function connection:Disconnect() self.Connected=false end
   table.insert(callbacks,{connection=connection,callback=callback})
   return connection
  end
  function event:Once(callback)
   local connection
   connection=self:Connect(function(...) connection:Disconnect() callback(...) end)
   return connection
  end
  function event:Fire(...)
   for _,entry in table.clone(callbacks) do if entry.connection.Connected then entry.callback(...) end end
  end
  return event
 end
 local function object()
  local attributes = {}
  local result = {MouseEnter=signal(),MouseLeave=signal(),MouseButton1Down=signal(),MouseButton1Up=signal(),Destroying=signal(),SelectionGained=signal(),SelectionLost=signal()}
  function result:SetAttribute(name,value) attributes[name]=value end
  function result:GetAttribute(name) return attributes[name] end
  function result:GetPropertyChangedSignal() return signal() end
  function result:Destroy() self.Destroying:Fire() end
  return result
 end
 local pending = {}
 local tweens = {}
 function tweens:Create(target,_,properties)
  local tween = {Completed=signal()}
  function tween:Play() pending[self]={target=target,properties=properties} end
  function tween:Cancel() pending[self]=nil self.Completed:Fire(Enum.PlaybackState.Cancelled) end
  function tween:Destroy() pending[self]=nil end
  return tween
 end
 local function completeTweens()
  for tween,entry in table.clone(pending) do
   if not pending[tween] then continue end
   pending[tween]=nil
   for property,value in entry.properties do entry.target[property]=value end
   tween.Completed:Fire(Enum.PlaybackState.Completed)
  end
 end
 local environment = setmetatable({
  game={Players={LocalPlayer={}},GetService=function(_,name) assert(name=="TweenService") return tweens end},
  Instance={new=object},
 },{__index=getfenv()})
 local module = assert(loadstring(sources.UICommon))
 setfenv(module,environment)
 local UI = module()
 local ball,bat = UI.Button({},"BallTab","Balls"),UI.Button({},"BatTab","Bats")
 ball.MouseEnter:Fire()
 UI.SetButton(ball,"Balls",true,true)
 completeTweens()
 check(ball.BackgroundColor3==UI.Colors.Accent,"finishing a stale hover must not erase a newly selected tab")
 ball.MouseLeave:Fire()
 bat.MouseEnter:Fire()
 UI.SetButton(ball,"Balls",true,false)
 UI.SetButton(bat,"Bats",true,true)
 completeTweens()
 check(ball.BackgroundColor3==UI.Colors.Card,"a previous selection must not regain its accent")
 check(bat.BackgroundColor3==UI.Colors.Accent,"the newly selected tab must keep its accent")
 bat.MouseEnter:Fire()
 UI.SetButton(bat,"Unavailable",false,false)
 completeTweens()
 check(bat.BackgroundColor3==UI.Colors.Locked and not bat.Active,"disabling a hovered button must preserve its disabled appearance")
 UI.SetButton(bat,"Bats",true,true)
 bat.MouseEnter:Fire()
 completeTweens()
 check(bat.BackgroundColor3==UI.Colors.Accent:Lerp(Color3.new(1,1,1),.12),"hover tint still works after a selection update")
 bat.MouseLeave:Fire()
 completeTweens()
 check(bat.BackgroundColor3==UI.Colors.Accent,"leaving hover restores the current selection color")
 bat.MouseEnter:Fire()
 bat:Destroy()
 check(next(pending)==nil,"destroying a button releases its pending tween")
 ball:Destroy()
 check(UI.Compact(1250)=="1,250" and UI.Compact(12500)=="12.5K" and UI.Compact(1200000)=="1.2M", "compact HUD formatting retains readable magnitudes")
 local action=UI.Button({},"Purchase","PURCHASE")
 UI.SetButton(action,"PURCHASE",true,true)
 action.MouseButton1Down:Fire()
 UI.SetButton(action,"EQUIPPED",false,true)
 action.MouseButton1Up:Fire()
 completeTweens()
 check(action.BackgroundColor3==UI.Colors.Accent and not action.Active,"press release cannot override a server-confirmed equipped state")
 action:Destroy()
 return {passed=passed}
end
