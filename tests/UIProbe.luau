-- Read-only client diagnostic. Run after layout settles, then inspect returned data.
-- Example in a client-side test runner: print(HttpService:JSONEncode(probe()))
-- This file is outside Rojo mappings; it creates no Instances or connections.
return function(player)
 player = player or game:GetService("Players").LocalPlayer
 local playerGui = assert(player and player:FindFirstChildOfClass("PlayerGui"), "Run on a client with PlayerGui.")
 local names = {GameHUD=true, EquipmentShopGui=true, WorldTravelGui=true, TrainingGroundGui=true,
  RebirthGui=true, TrainingHUD=true, OfflineTrainingGui=true, NotificationGui=true, ContextActionGui=true}
 local report = {duplicates={}, offscreen={}, textDoesNotFit={}, visibleButtons={}, scrollingFrames={},
  screens={}, inspected=0, hidden=0, clippedByAncestors=0}
 local function rect(object)
  local p, s = object.AbsolutePosition, object.AbsoluteSize
  return {x=p.X,y=p.Y,w=s.X,h=s.Y}
 end
 local function intersect(a,b)
  local x,y = math.max(a.x,b.x),math.max(a.y,b.y)
  local right,bottom = math.min(a.x+a.w,b.x+b.w),math.min(a.y+a.h,b.y+b.h)
  if right<=x or bottom<=y then return nil end
  return {x=x,y=y,w=right-x,h=bottom-y}
 end
 local function visibleRect(object,screen)
  local area = rect(object)
  local parent = object
  while parent and parent~=screen do
   if parent:IsA("GuiObject") then
    if not parent.Visible then return nil,"hidden" end
    if parent~=object and (parent.ClipsDescendants or parent:IsA("ScrollingFrame")) then
     -- Normal scrolling intentionally hides content; do not flag it as overflow.
     area = intersect(area,rect(parent))
     if not area then return nil,"clipped" end
    end
   end
   parent = parent.Parent
  end
  return area
 end
 local counts = {}
 for _, screen in playerGui:GetChildren() do
  if not screen:IsA("ScreenGui") or not names[screen.Name] then continue end
  counts[screen.Name] = (counts[screen.Name] or 0)+1
  local size = screen.AbsoluteSize
  local origin = screen.AbsolutePosition
  local viewport = {x=origin.X,y=origin.Y,w=size.X,h=size.Y}
  table.insert(report.screens,{name=screen.Name,enabled=screen.Enabled,bounds=viewport})
  if not screen.Enabled then continue end
  for _, object in screen:GetDescendants() do
   if not object:IsA("GuiObject") then continue end
   local area,reason = visibleRect(object,screen)
   if not area then
    if reason=="hidden" then report.hidden+=1 else report.clippedByAncestors+=1 end
    continue
   end
   report.inspected+=1
   local path = object:GetFullName()
   local onScreen = intersect(area,viewport)
   local clipped = not onScreen or onScreen.w<area.w-1.5 or onScreen.h<area.h-1.5
   if clipped and area.w>1 and area.h>1 then
    table.insert(report.offscreen,{path=path,bounds=area,visibleBounds=onScreen})
   end
   if not onScreen then continue end
   if (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox"))
    and object.Text~="" and object.TextTransparency<1 and not object.TextFits then
    table.insert(report.textDoesNotFit,{path=path,text=object.Text,bounds=rect(object),
     textWidth=object.TextBounds.X,textHeight=object.TextBounds.Y})
   end
   if object:IsA("GuiButton") then
    local bounds = rect(object)
    table.insert(report.visibleButtons,{path=path,text=object:IsA("TextButton") and object.Text or "",
     active=object.Active,bounds=bounds,visibleBounds=onScreen,
     center={x=onScreen.x+onScreen.w/2,y=onScreen.y+onScreen.h/2},
     below40Pixels=bounds.w<40 or bounds.h<40})
   end
   if object:IsA("ScrollingFrame") then
    table.insert(report.scrollingFrames,{path=path,bounds=rect(object),enabled=object.ScrollingEnabled,
     scrollY=object.CanvasPosition.Y,canvasHeight=object.AbsoluteCanvasSize.Y,
     viewportHeight=object.AbsoluteWindowSize.Y})
   end
  end
 end
 for name,count in counts do if count>1 then table.insert(report.duplicates,{name=name,count=count}) end end
 return report
end
