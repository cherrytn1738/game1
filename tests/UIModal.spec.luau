-- Real UI instances in unparented test folders; no live PlayerGui or Lighting edits.
return function(sources)
 local passed=0
 local function check(value,message) assert(value,message) passed+=1 end
 local root, lighting=Instance.new("Folder"),Instance.new("Folder")
 local originalBlur=Instance.new("BlurEffect",lighting)
 originalBlur.Name, originalBlur.Size = "ExistingWorldBlur",4
 local tweenService=game:GetService("TweenService")
 local environment=setmetatable({
  game={Players={LocalPlayer={WaitForChild=function() return root end}},
   GetService=function(_,name) return name=="Lighting" and lighting or tweenService end},
  task={defer=function(fn) fn() end,delay=function() end},
 },{__index=getfenv()})
 local run=assert(loadstring(sources.UICommon))
 setfenv(run,environment)
 local UI=run()
 local a,_,showA=UI.Menu("Equipment","Equipment","",function() end)
 local b,_,showB=UI.Menu("Worlds","Worlds","",function() end)
 showA(true)
 local blur=lighting:FindFirstChild("MenuBlur")
 check(blur and blur.Enabled,"opening a modal enables owned blur")
 for _=1,10 do showB(true) showA(false) showA(true) showB(false) end
 check(#lighting:GetChildren()==2 and blur.Enabled,"repeated menu switches never stack blur effects")
 showB(true)
 showA(false)
 check(blur.Enabled,"closing one menu does not remove blur from another visible menu")
 showB(false)
 check(not blur.Enabled,"closing the final modal restores the world")
 check(originalBlur.Enabled and originalBlur.Size==4,"unrelated world effects are untouched")
 task.wait(.25)
 check(not a.Scrim.Visible and not b.Scrim.Visible,"closing animations eventually hide both menus")
 showA(true)
 task.wait(.3)
 check(a.Scrim.Visible and a.Scrim.Panel.GroupTransparency==0,"opening finishes fully visible")
 showA(false)
 check(a.Scrim.Visible,"closing stays visible long enough to animate")
 task.wait(.05)
 showA(true)
 task.wait(.3)
 check(a.Scrim.Visible and a.Scrim.Panel.GroupTransparency==0 and blur.Enabled,
  "reopening cancels the old close without hiding the new menu")
 showA(false)
 task.wait(.25)
 check(not a.Scrim.Visible,"reopened menu can close cleanly again")
 showA(true)
 a:Destroy()
 task.wait() -- Studio may deliver Destroying signals on the deferred event queue.
 check(not blur.Enabled,"destroyed modal releases its blur state")
 b:Destroy()
 root:Destroy()
 lighting:Destroy()
 return {passed=passed}
end
