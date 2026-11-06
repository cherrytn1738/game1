-- Real UI instances in unparented test folders; no live PlayerGui or Lighting edits.
return function(sources)
 local passed=0
 local function check(value,message) assert(value,message) passed+=1 end
 local root, lighting=Instance.new("Folder"),Instance.new("Folder")
 local originalBlur=Instance.new("BlurEffect",lighting)
 originalBlur.Name, originalBlur.Size = "ExistingWorldBlur",4
 local tweenService=game:GetService("TweenService")
 local played={}
 local audio={Play=function(name) table.insert(played,name) end,Preload=function() end,CinematicActive=function() return false end}
 local storage={WaitForChild=function() return "GameAudio" end}
 -- A stand-in player whose attributes the notice reads (CinematicCamera, PortalJourney).
 local playerAttributes, attributeSignals={},{}
 local fakePlayer={WaitForChild=function() return root end}
 function fakePlayer:GetAttribute(name) return playerAttributes[name] end
 function fakePlayer:GetAttributeChangedSignal(name)
  attributeSignals[name]=attributeSignals[name] or Instance.new("BindableEvent")
  return attributeSignals[name].Event
 end
 local function setPlayerAttribute(name,value)
  playerAttributes[name]=value
  if attributeSignals[name] then attributeSignals[name]:Fire() end
 end
 local services={Lighting=lighting,ReplicatedStorage=storage,TweenService=tweenService,
  TextService=game:GetService("TextService"),UserInputService=game:GetService("UserInputService")}
 local environment=setmetatable({
  game={Players={LocalPlayer=fakePlayer},
   GetService=function(_,name) return services[name] or tweenService end},
  task={defer=function(fn) fn() end,delay=function() end},
  require=function(module) assert(module=="GameAudio","UICommon only requires GameAudio") return audio end,
 },{__index=getfenv()})
 local run=assert(loadstring(sources.UICommon))
 setfenv(run,environment)
 local UI=run()
 local a,_,showA=UI.Menu("Equipment","Equipment","",function() end)
 local b,_,showB=UI.Menu("Worlds","Worlds","",function() end)
 check(#played==0,"building menus is silent")
 showA(true)
 showA(true)
 check(#played==1 and played[1]=="MenuOpen","opening a menu plays MenuOpen once, not again while open")
 local blur=lighting:FindFirstChild("MenuBlur")
 check(blur and blur.Enabled,"opening a modal enables owned blur")
 for _=1,10 do showB(true) showA(false) showA(true) showB(false) end
 check(#lighting:GetChildren()==2 and blur.Enabled,"repeated menu switches never stack blur effects")
 showB(true)
 showA(false)
 check(blur.Enabled,"closing one menu does not remove blur from another visible menu")
 table.clear(played)
 showB(false)
 check(played[1]=="MenuClose","closing a menu plays MenuClose")
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
 -- Structure (the Inventory's style): a slightly see-through rounded blue gradient box with a thick
 -- outline, the title and the red close button riding over its top edge.
 local panel=b.Scrim.Panel
 local box=panel.Box
 local gradient=box:FindFirstChildOfClass("UIGradient")
 check(panel.BackgroundTransparency==1 and box.BackgroundTransparency>0 and box.BackgroundTransparency<.5 and gradient and gradient.Color.Keypoints[1].Value.B>gradient.Color.Keypoints[1].Value.R
  and box:FindFirstChildOfClass("UICorner") and box:FindFirstChildOfClass("UIStroke").Thickness>=4,"window box is a slightly see-through rounded blue gradient with a thick outline")
 check(panel.Title.AnchorPoint.Y==.5 and panel.Title.Position.Y.Offset==box.Position.Y.Offset and box.Position.Y.Offset>0
  and panel.Title.Font==Enum.Font.FredokaOne,"rounded title is centred on the box's top edge")
 check(panel.Close.Size==UDim2.fromOffset(52,52) and math.abs(panel.Close.Position.Y.Offset-box.Position.Y.Offset)<=4,"52x52 close button on the top edge")
 -- Notices: floating outlined text with no panel; errors unfocus the screen through the one shared
 -- blur and a tint, routine notices do not, and nothing about a notice takes input.
 UI.Notify("Gladiator Colosseum requires 10 Rebirths.","error",
  {kind="locked",title="CAGE LOCKED",item="Gladiator Colosseum",unit="Rebirths",required=10,current=7})
 local noticeGui=root:FindFirstChild("NotificationGui")
 local notice=noticeGui and noticeGui:FindFirstChild("Notice")
 check(notice and notice:IsA("CanvasGroup") and notice.BackgroundTransparency==1 and not notice:FindFirstChildOfClass("UIStroke")
  and not notice:FindFirstChildOfClass("UICorner"),"the notice is floating text with no panel")
 check(notice.TitleRow.Title.Text.Text=="CAGE LOCKED" and notice.TitleRow.Icon.Lock.Visible and notice.TitleRow.Title.Text.Font==Enum.Font.FredokaOne
  and notice.TitleRow.Title.Text:FindFirstChildOfClass("UIStroke").Thickness>=4,"locked notices name the problem in outlined FredokaOne with a lock")
 local message=notice.Message.Text
 check(message.RichText and message.Text:find("10 Rebirths",1,true) and message.Text:find("<font",1,true)
  and not notice.Message.Shadow.Text:find("<font",1,true),"the required value is highlighted, and the shadow is plain")
 check(notice.ProgressRow.Visible and notice.ProgressRow.Count.Text.Text=="7 / 10" and notice.Remaining.Text.Text=="3 more Rebirths to unlock",
  "Rebirth requirements show a count bar and what is left")
 check(not notice.Active and not noticeGui.Tint.Active,"notices never take input")
 check(noticeGui.Tint.Visible and blur.Enabled and #lighting:GetChildren()==2,"errors unfocus the screen with the one shared blur")
 UI.Notify("You need 15,000,000 more Cash.","error",{kind="cash",item="Dragon Bone Bat",unit="Cash",required=28e6,current=13e6})
 check(notice.TitleRow.Title.Text.Text=="NOT ENOUGH CASH" and notice.ProgressRow.Count.Text.Text=="46%"
  and notice.Remaining.Text.Text=="$15M more to go" and notice.Message.Text.Text:find("$28M",1,true),"Cash requirements show a percentage")
 check(#lighting:GetChildren()==2 and blur.Enabled,"a new notice replaces the old one without another blur")
 UI.ClearNotifications()
 check(not notice.Visible and not noticeGui.Tint.Visible and not blur.Enabled,"clearing a notice always removes its blur and tint")
 UI.Notify("LEVEL 12","level")
 check(notice.Visible and not noticeGui.Tint.Visible and not blur.Enabled and not notice.ProgressRow.Visible,"Level Up floats with no blur or tint")
 UI.Notify("Old plain message","error")
 check(notice.TitleRow.Title.Text.Text=="CAN'T DO THAT" and notice.Message.Text.Text=="Old plain message" and blur.Enabled,
  "plain-text errors still work")
 setPlayerAttribute("CinematicCamera",true)
 task.wait()
 check(not blur.Enabled and not notice.Visible,"a cinematic starting clears an unfocusing notice")
 UI.Notify("Another plain error","error")
 check(notice.Visible and not blur.Enabled and not noticeGui.Tint.Visible,"notices never blur during a cinematic")
 setPlayerAttribute("CinematicCamera",nil)
 UI.ClearNotifications()
 b:Destroy()
 root:Destroy()
 lighting:Destroy()
 return {passed=passed}
end
