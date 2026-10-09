local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local Equipment = require(ReplicatedStorage:WaitForChild("EquipmentConfig"))
local Remote = ReplicatedStorage:WaitForChild("EquipmentUpgrade")
local Interfaces = require(script.Parent:WaitForChild("HubInterfaces"))
local UI = require(script.Parent:WaitForChild("UICommon"))

local gui, panel, show = UI.Menu("EquipmentShopGui", "Equipment", "Choose your gear. Purchased equipment stays yours.", Interfaces.CloseAll)
local balance = UI.Label(panel, "Balance", "Loading Cash...", 16, UI.Colors.Gold)
balance.Position, balance.Size = UDim2.fromOffset(16,86), UDim2.new(1,-32,0,24)
local list = UI.Scroll(panel, "EquipmentList")
list.Position, list.Size = UDim2.fromOffset(14,164), UDim2.new(1,-28,1,-210)
local feedback = UI.Label(panel, "Feedback", "", 14, UI.Colors.Muted)
feedback.Position, feedback.Size, feedback.TextWrapped = UDim2.new(0,16,1,-42), UDim2.new(1,-32,0,36), true
local rows, tabs, ownership = {}, {}, {}
local selectedCategory = Equipment.CategoryOrder[1]
local pending, requestVersion = false, 0
local cash

local function effect(category, item)
 if category == "Bat" then return string.format("%.2fx hitting power", item.powerMultiplier) end
 if category == "Ball" then return string.format("%.2fx Cash rewards", item.rewardMultiplier) end
 return string.format("%.2fx timing window", item.timingScale)
end

local function layoutRows()
 local narrow = panel.AbsoluteSize.X < 540
 for _, row in rows do
  row.frame.Size = UDim2.new(1,-10,0,narrow and 144 or 102)
  local textWidth = narrow and UDim2.new(1,-28,0,24) or UDim2.new(1,-212,0,24)
  row.title.Position, row.title.Size = UDim2.fromOffset(14,10), textWidth
  row.stat.Position, row.stat.Size = UDim2.fromOffset(14,38), textWidth
  row.state.Position, row.state.Size = UDim2.fromOffset(14,64), textWidth
  row.button.Position = narrow and UDim2.fromOffset(14,94) or UDim2.new(1,-184,0,25)
  row.button.Size = narrow and UDim2.new(1,-28,0,40) or UDim2.fromOffset(170,52)
 end
end

local function refresh()
 local ready = Player:GetAttribute("DataLoaded") == true and cash ~= nil
 balance.Text = ready and UI.Number(cash.Value) .. " Cash" or "Loading Cash..."
 local owned = ownership[selectedCategory] and ownership[selectedCategory]:GetAttributes() or {}
 local nextItem = Equipment.GetNextPurchase(selectedCategory, owned)
 local equipped = Player:GetAttribute("Equipped" .. selectedCategory)
 for category, tab in tabs do
  UI.SetButton(tab, Equipment.Categories[category].displayName, not pending, category == selectedCategory)
 end
 for id, row in rows do
  local item = Equipment.Get(selectedCategory,id)
  local isOwned, isEquipped = owned[id] == true, equipped == id
  local isNext = nextItem ~= nil and nextItem.id == id
  local affordable = ready and cash.Value >= item.price
  row.state.Text = isEquipped and "Equipped" or isOwned and "Owned" or isNext and
   (affordable and "Next equipment" or "Need " .. UI.Number(item.price-cash.Value) .. " more Cash") or "Locked · Progress through this category"
  row.state.TextColor3 = isEquipped and UI.Colors.Accent or UI.Colors.Muted
  local text = isEquipped and "EQUIPPED" or isOwned and "EQUIP"
   or isNext and ("PURCHASE · " .. UI.Number(item.price) .. " Cash") or "LOCKED"
  local enabled = ready and Interfaces.CanOpen() and not pending and not isEquipped and (isOwned or isNext)
  UI.SetButton(row.button,text,enabled,isNext and affordable or isOwned and not isEquipped)
 end
end

local function showCategory(category)
 selectedCategory = category
 for _, row in rows do row.frame:Destroy() end
 table.clear(rows)
 list.CanvasPosition = Vector2.zero
 for index, item in Equipment.GetItems(category) do
  local frame = UI.Surface(list,item.id,UI.Colors.Card)
  frame.LayoutOrder = index
  local title = UI.Label(frame,"Equipment",item.displayName,18)
  title.Font = Enum.Font.GothamBold
  local stat = UI.Label(frame,"Effect",effect(category,item),15,UI.Colors.Muted)
  local state = UI.Label(frame,"State","",13,UI.Colors.Muted)
  state.TextWrapped = true
  local button = UI.Button(frame,"Action","")
  rows[item.id] = {frame=frame,title=title,stat=stat,state=state,button=button}
  button.Activated:Connect(function()
   if pending or not button.Active or not Interfaces.CanOpen() then return end
   local owned = ownership[category]:GetAttributes()
   local nextItem = Equipment.GetNextPurchase(category,owned)
   local action, value
   if owned[item.id] then action, value = "Equip", item.id
   elseif nextItem and nextItem.id == item.id then
    if cash.Value < item.price then
     feedback.Text = "You need " .. UI.Number(item.price-cash.Value) .. " more Cash."
     feedback.TextColor3 = UI.Colors.Error
     return
    end
    action, value = "Purchase", Player:GetAttribute("EquipmentPurchaseToken_" .. category)
   else return end
   if not value then return end
   pending = true
   requestVersion += 1
   local version = requestVersion
   feedback.Text = action == "Purchase" and "Purchasing..." or "Equipping..."
   refresh()
   Remote:FireServer(action,category,value)
   task.delay(8,function()
    if pending and version == requestVersion then
     pending = false
     feedback.Text = "No response yet. Check your connection and try again."
     refresh()
    end
   end)
  end)
 end
 layoutRows()
 refresh()
end

for index, category in Equipment.CategoryOrder do
 local tab = UI.Button(panel,category.."Tab",Equipment.Categories[category].displayName)
 tab.Position = UDim2.new((index-1)/3,16-(index-1)*8,0,116)
 tab.Size = UDim2.new(1/3,-16,0,40)
 tabs[category] = tab
 tab.Activated:Connect(function() if not pending then showCategory(category) end end)
end
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutRows)
Interfaces.Register("Shop",function(visible)
 show(visible)
 if visible then feedback.Text = "" refresh() end
end)
Remote.OnClientEvent:Connect(function(success,message)
 pending = false
 requestVersion += 1
 feedback.Text = success and message or "Action unavailable. Check your Cash and equipment, then try again."
 feedback.TextColor3 = success and UI.Colors.Accent or UI.Colors.Error
 if not gui.Scrim.Visible then UI.Notify(feedback.Text,success and "success" or "error") end
 refresh()
end)
showCategory(selectedCategory)
Player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh)
task.spawn(function()
 while Player:GetAttribute("DataLoaded") ~= true do Player:GetAttributeChangedSignal("DataLoaded"):Wait() end
 cash = Player:WaitForChild("leaderstats"):WaitForChild("Cash")
 for _, category in Equipment.CategoryOrder do
  ownership[category] = Player:WaitForChild(Equipment.Categories[category].ownedField)
  ownership[category].AttributeChanged:Connect(refresh)
  Player:GetAttributeChangedSignal("Equipped"..category):Connect(refresh)
  Player:GetAttributeChangedSignal("EquipmentPurchaseToken_"..category):Connect(refresh)
 end
 cash:GetPropertyChangedSignal("Value"):Connect(refresh)
 refresh()
end)
