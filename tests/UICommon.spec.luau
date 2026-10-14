-- Deterministic button-state and hover/press races using the real UICommon source and fake
-- instances. No live UI, player state, or Instances are modified.
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
  local result = {MouseEnter=signal(),MouseLeave=signal(),MouseButton1Down=signal(),MouseButton1Up=signal(),Destroying=signal(),
   SelectionGained=signal(),SelectionLost=signal(),Active=true,Name=""}
  function result:SetAttribute(name,value) attributes[name]=value end
  function result:GetAttribute(name) return attributes[name] end
  function result:GetPropertyChangedSignal() return signal() end
  function result:FindFirstChildOfClass() return object() end
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
 local sounds = {PlayLocalSound=function() end}
 local environment = setmetatable({
  game={Players={LocalPlayer={}},GetService=function(_,name) return name=="TweenService" and tweens or sounds end},
  Instance={new=object},
 },{__index=getfenv()})
 local module = assert(loadstring(sources.UICommon))
 setfenv(module,environment)
 local UI = module()
 local function makeButton(name,text)
  local button = UI.Button({},name,text)
  button.Name = name -- the fake does not keep Instance.new arguments
  return button
 end
 local ball,bat = makeButton("BallTab","Balls"),makeButton("BatTab","Bats")
 ball.MouseEnter:Fire()
 UI.SetButton(ball,"Balls",true,true)
 completeTweens()
 check(ball:GetAttribute("State")=="Cyan","finishing a stale hover must not erase a newly selected tab")
 ball.MouseLeave:Fire()
 bat.MouseEnter:Fire()
 UI.SetButton(ball,"Balls",true,false)
 UI.SetButton(bat,"Bats",true,true)
 completeTweens()
 check(ball:GetAttribute("State")=="Claimed","a previous selection returns to the unselected tab style")
 check(bat:GetAttribute("State")=="Cyan","the newly selected tab keeps its selected style")
 bat.MouseEnter:Fire()
 UI.SetButton(bat,"Unavailable",false,false)
 completeTweens()
 check(bat:GetAttribute("State")=="Claimed" and not bat.Active,"disabling a hovered button shows the disabled style")
 bat.MouseEnter:Fire()
 bat:Destroy()
 check(next(pending)==nil,"destroying a button releases its pending tween")
 ball:Destroy()
 check(UI.Compact(1250)=="1,250" and UI.Compact(12500)=="12.5K" and UI.Compact(1200000)=="1.2M","compact HUD formatting retains readable magnitudes")
 local action=makeButton("Purchase","PURCHASE")
 UI.SetButton(action,"PURCHASE",true,true)
 check(action:GetAttribute("State")=="Claim","an available action uses the lime Claim style")
 action.MouseButton1Down:Fire()
 UI.SetButton(action,"EQUIPPED",false,true)
 action.MouseButton1Up:Fire()
 completeTweens()
 check(action:GetAttribute("State")=="Claimed" and not action.Active,"press release cannot override a server-confirmed equipped state")
 local locked=makeButton("Next","LOCKED")
 UI.SetButton(locked,"LOCKED",false,false)
 check(locked:GetAttribute("State")=="Locked","locked items use the crimson Locked style")
 local leave=makeButton("Leave","LEAVE")
 leave:SetAttribute("Danger",true)
 UI.SetButton(leave,"LEAVE",true,false)
 check(leave:GetAttribute("State")=="Locked","destructive actions use the crimson style")
 local secondary=makeButton("Select","SELECT")
 UI.SetButton(secondary,"SELECT",true,false)
 check(secondary:GetAttribute("State")=="Cyan","neutral enabled buttons use the cyan style")
 return {passed=passed}
end
