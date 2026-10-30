-- Builds a physical item display in a hub: a stepped white stage with one pedestal per
-- item of an EquipmentConfig category. Each pedestal holds the item (its designed model
-- from ServerStorage.RunwayAssets.DisplayItems.<item id>, or a placeholder) and a
-- ProximityPrompt. Labels, prompt text and item spin are per-player presentation in
-- ItemDisplayClient; buying and equipping go through the existing server-validated
-- EquipmentUpgrade remote.
local Equipment = require(game:GetService("ReplicatedStorage"):WaitForChild("EquipmentConfig"))
local BallStyles = require(game:GetService("ReplicatedStorage"):WaitForChild("BallStyles"))
local BatStyles = require(game:GetService("ReplicatedStorage"):WaitForChild("BatStyles"))
local STYLES = {Ball = BallStyles, Bat = BatStyles}
local CollectionService = game:GetService("CollectionService")

local ItemDisplay = {}
ItemDisplay.PedestalTag = "ItemPedestal"

-- A row of 5 items is about 35 studs wide (World 1 shows two rows of 5).
local SPACING = 6.4 -- studs between pedestals in a row
local ROW_DEPTH = 7 -- each further row steps back this far...
local TIER_HEIGHT = 1.2 -- the front tier's height
-- ...and up far enough that its items clear the labels of the row in front (ItemDisplayClient
-- labels are 3.2 studs tall), so names and prices never sit on top of each other.
local LABEL_HALF_HEIGHT = 1.6
local ROW_GAP = 0.4
local PROMPT_REACH_PER_ROW = 10 -- higher rows stand further away from a player at the front
local PEDESTAL = Vector3.new(3.6, 0.8, 3.6)
-- Defaults; a display can override itemSize, itemHeight and labelHeight (bats stand taller).
local ITEM_SIZE = 2 -- the item's largest dimension, in studs
local ITEM_HEIGHT = 2.2 -- item centre above the pedestal top
local LABEL_HEIGHT = 3.1 -- label centre above the item centre
local PROMPT_DISTANCE = 14 -- reaches the front row from anywhere in the dirt lane before the display
-- An item's glow (its style's light, tuned for the ball in flight) is much dimmer and shorter on
-- a pedestal, so neighbouring glows don't wash out the white stage and the items themselves.
local DISPLAY_LIGHT_BRIGHTNESS, DISPLAY_LIGHT_RANGE = 0.3, 0.4
local BACKDROP_HEIGHT = 9 -- wall behind the top row, above its tier
-- Stairs up to the top tier (WorldConfig display stairSide): each step at most STAIR_RISE high
-- and STAIR_RUN deep, STAIR_WIDTH wide; the top row's pedestals stand UPPER_SETBACK further
-- back so a 3-stud walkway runs in front of them.
local STAIR_RISE, STAIR_RUN, STAIR_WIDTH = 0.75, 1.2, 4
local RAIL_HEIGHT = 3
local UPPER_SETBACK = 1.3

-- A dark slate stage and pedestals: the items stand out against them, and they stay clear of
-- bloom under bright lighting (a white stage blew out and hid the items).
local STAGE_COLOR = Color3.fromRGB(52, 60, 84)
local TRIM_COLOR = Color3.fromRGB(205, 40, 48)
local PEDESTAL_COLOR = Color3.fromRGB(82, 92, 120)

local function part(parent, name, size, cframe, color, shape)
 local p = Instance.new("Part")
 p.Name, p.Size, p.CFrame = name, size, cframe
 p.Shape = shape or Enum.PartType.Block
 p.Anchored, p.CanCollide, p.CanTouch = true, true, false
 p.Material, p.Color = Enum.Material.SmoothPlastic, color
 p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
 p.Parent = parent
 return p
end

-- The part an item's glow and idle particles attach to (a ball's shell or core, a bat's barrel).
local function mainPart(model)
 for _, name in {"Shell", "Core", "Barrel"} do
  for _, descendant in model:GetDescendants() do
   if descendant:IsA("BasePart") and BallStyles.PartName(descendant.Name) == name then return descendant end
  end
 end
 return model:FindFirstChildWhichIsA("BasePart", true)
end

-- A preview of the item's effects around it on the pedestal: its glow and a few of its
-- particles (presets are sized for the 0.8-stud ball, so they scale with the display item).
local function addIdleEffects(model, style, itemSize)
 local anchor = style and mainPart(model)
 if not anchor then return end
 if style.light then
  local light = Instance.new("PointLight")
  light.Color, light.Shadows = style.light[1], false
  light.Brightness = style.light[2] * DISPLAY_LIGHT_BRIGHTNESS
  light.Range = style.light[3] * DISPLAY_LIGHT_RANGE
  light.Parent = anchor
 end
 if style.idle then
  local emitter = BallStyles.MakeEmitter(style.idle, anchor, math.min(itemSize, ITEM_SIZE) / 0.8 * 0.6)
  if emitter then emitter.Rate = math.max(2, emitter.Rate * 0.25) end
 end
end

-- The item's designed model when it exists, else a placeholder: a baseball-like ball, or an
-- upright bat in the item's appearance colours.
local function makeItem(item, spot, itemSize)
 local assets = game:GetService("ServerStorage"):FindFirstChild("RunwayAssets")
 local folder = assets and assets:FindFirstChild("DisplayItems")
 local template = folder and folder:FindFirstChild(item.id)
 local styles = STYLES[item.category]
 local model
 if template then
  model = template:Clone()
  if model:IsA("BasePart") then
   local wrapper = Instance.new("Model")
   model.Parent = wrapper
   model = wrapper
  end
  local _, size = model:GetBoundingBox()
  local largest = math.max(size.X, size.Y, size.Z)
  if largest > 0 then model:ScaleTo(model:GetScale() * itemSize / largest) end
  -- Spin about the item's centre, wherever the designed model's pivot was.
  if not model.PrimaryPart then model.WorldPivot = (model:GetBoundingBox()) end
  if styles then
   styles.ApplyLook(model, item.id)
   addIdleEffects(model, styles.Get(item.id), itemSize)
  end
 elseif item.category == "Bat" then
  model = Instance.new("Model")
  local look = item.appearance or {}
  local body, grip = look.BatBody or {}, look.BatGrip or {}
  local barrel = part(model, "Placeholder", Vector3.new(itemSize * 0.72, 0.32, 0.32),
   CFrame.new(0, itemSize * 0.14, 0) * CFrame.Angles(0, 0, math.pi / 2), body.color or Color3.new(1, 1, 1), Enum.PartType.Cylinder)
  barrel.Material = body.material or Enum.Material.SmoothPlastic
  part(model, "Grip", Vector3.new(itemSize * 0.28, 0.2, 0.2), CFrame.new(0, -itemSize * 0.36, 0) * CFrame.Angles(0, 0, math.pi / 2),
   grip.color or Color3.new(0.1, 0.1, 0.1), Enum.PartType.Cylinder)
 else
  model = Instance.new("Model")
  local look = item.appearance or {}
  local ball = part(model, "Placeholder", Vector3.one * itemSize, CFrame.identity,
   look.color or Color3.new(1, 1, 1), Enum.PartType.Ball)
  ball.Material = look.material or Enum.Material.SmoothPlastic
  for _, side in {-1, 1} do
   -- Two red seams so the placeholder reads as a baseball.
   part(model, "Seam", Vector3.new(0.12, itemSize * 0.82, itemSize * 0.82),
    CFrame.new(side * itemSize * 0.3, 0, 0), TRIM_COLOR, Enum.PartType.Cylinder)
  end
 end
 model.Name = "Item"
 for _, descendant in model:GetDescendants() do
  if descendant:IsA("BasePart") then
   descendant.Anchored, descendant.CanCollide, descendant.CanTouch, descendant.CanQuery = true, false, false, false
  end
 end
 model:PivotTo(spot)
 return model
end

-- definition: a WorldConfig hub display; frame: the hub's batting-edge frame (+Z into the hub).
-- definition.yaw turns the display about its position (default math.pi: facing the runway;
-- -math.pi / 2 faces -X, e.g. from the right side of the hub toward its middle).
-- A staircase beside one end of the stage (side 1 = the display's local +X end, -1 = -X) up
-- to the top tier, in line with the walkway in front of its pedestals: solid steps with a red
-- nosing, and a handrail on each side.
local function buildStairs(display, base, side, width, topHeight, rows)
 local steps = math.ceil(topHeight / STAIR_RISE)
 local rise, run = topHeight / steps, STAIR_RUN
 -- The walkway in front of the top row's pedestals, which the stairs line up with.
 local front = -(rows - 1) * ROW_DEPTH
 local centreZ = front - STAIR_WIDTH / 2
 local inner = width / 2
 for step = 1, steps do
  -- Step 1 is outermost and lowest; the last step meets the tier.
  local x0 = inner + (steps - step) * run
  local height = step * rise
  part(display, "StairStep" .. step, Vector3.new(run, height, STAIR_WIDTH),
   base * CFrame.new(side * (x0 + run / 2), height / 2, centreZ), STAGE_COLOR)
  part(display, "StairNosing" .. step, Vector3.new(0.3, 0.3, STAIR_WIDTH + 0.1),
   base * CFrame.new(side * (x0 + run - 0.15), height - 0.15, centreZ), TRIM_COLOR)
 end
 local length = steps * run
 for _, z in {front + 0.25, front - STAIR_WIDTH - 0.25} do
  local bottom = base * Vector3.new(side * (inner + length), rise + RAIL_HEIGHT, z)
  local top = base * Vector3.new(side * inner, topHeight + RAIL_HEIGHT, z)
  part(display, "StairRail", Vector3.new(0.35, 0.35, (top - bottom).Magnitude),
   CFrame.lookAt((bottom + top) / 2, top), TRIM_COLOR)
  for _, t in {0, 0.5, 1} do
   local postTop = bottom:Lerp(top, t)
   part(display, "StairPost", Vector3.new(0.35, RAIL_HEIGHT, 0.35),
    CFrame.new(postTop - Vector3.new(0, RAIL_HEIGHT / 2, 0)) * base.Rotation, PEDESTAL_COLOR)
  end
 end
end

function ItemDisplay.Build(hub, frame, definition, worldId)
 local old = hub:FindFirstChild(definition.id)
 if old then old:Destroy() end
 -- One purchase series per display (definition.series; nil is the main series).
 local items = Equipment.GetSeriesItems(definition.category, definition.series)
 local display = Instance.new("Model")
 display.Name = definition.id
 display:SetAttribute("Category", definition.category)
 display:SetAttribute("Title", definition.title)
 display:SetAttribute("Subtitle", definition.subtitle)
 display.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
 -- The display faces its local +Z; rows climb away from it.
 local base = frame * CFrame.new(definition.position) * CFrame.Angles(0, definition.yaw or math.pi, 0)
 local perRow = math.max(1, definition.perRow or 5)
 local rows = math.ceil(#items / perRow)
 local width = math.min(#items, perRow) * SPACING + 3
 local itemSize = definition.itemSize or ITEM_SIZE
 local itemHeight = definition.itemHeight or ITEM_HEIGHT
 local labelHeight = definition.labelHeight or LABEL_HEIGHT
 local rowRise = labelHeight + LABEL_HALF_HEIGHT + itemSize / 2 + ROW_GAP
 local function tierTop(row) return TIER_HEIGHT + row * rowRise end
 for row = 0, rows - 1 do
  -- Each tier reaches the ground so the stage reads as solid steps.
  local height = tierTop(row)
  local centre = base * CFrame.new(0, height / 2, -(row + 0.5) * ROW_DEPTH)
  part(display, "Tier" .. row + 1, Vector3.new(width, height, ROW_DEPTH), centre, STAGE_COLOR)
  part(display, "Trim" .. row + 1, Vector3.new(width + 0.1, 0.3, 0.3),
   base * CFrame.new(0, height - 0.15, -row * ROW_DEPTH + 0.1), TRIM_COLOR)
 end
 for index, item in items do
  local row = (index - 1) // perRow
  local inRow = math.min(perRow, #items - row * perRow)
  local column = (index - 1) % perRow
  local x = (column - (inRow - 1) / 2) * SPACING
  local top = tierTop(row)
  local pedestal = Instance.new("Model")
  pedestal.Name = item.id
  -- Higher rows sit toward the back of their tier, leaving a walkway in front reached by the stairs.
  local depth = -(row + 0.5) * ROW_DEPTH - (row > 0 and UPPER_SETBACK or 0)
  local slab = part(pedestal, "Pedestal", PEDESTAL, base * CFrame.new(x, top + PEDESTAL.Y / 2, depth), PEDESTAL_COLOR)
  -- A red plinth band under the white top.
  part(pedestal, "Band", Vector3.new(PEDESTAL.X + 0.5, 0.35, PEDESTAL.Z + 0.5),
   slab.CFrame * CFrame.new(0, -PEDESTAL.Y / 2 + 0.175, 0), TRIM_COLOR)
  local spot = slab.CFrame * CFrame.new(0, PEDESTAL.Y / 2 + itemHeight, 0)
  makeItem(item, spot, itemSize).Parent = pedestal
  local label = Instance.new("Attachment")
  label.Name, label.Position, label.Parent = "Label", Vector3.new(0, PEDESTAL.Y / 2 + itemHeight + labelHeight, 0), slab
  local prompt = Instance.new("ProximityPrompt")
  prompt.Name, prompt.ObjectText, prompt.ActionText = "Prompt", item.displayName, "Buy"
  prompt.MaxActivationDistance = PROMPT_DISTANCE + row * PROMPT_REACH_PER_ROW
  prompt.HoldDuration, prompt.RequiresLineOfSight = 0, false
  prompt.Parent = slab
  pedestal:SetAttribute("Category", definition.category)
  pedestal:SetAttribute("ItemId", item.id)
  pedestal:SetAttribute("WorldId", worldId)
  CollectionService:AddTag(pedestal, ItemDisplay.PedestalTag)
  pedestal.Parent = display
 end
 if rows > 1 and definition.stairSide then
  buildStairs(display, base, definition.stairSide, width, tierTop(rows - 1), rows)
 end
 -- A backdrop wall behind the top row, with a red cap, and the title above it.
 local wallTop = tierTop(rows - 1) + BACKDROP_HEIGHT
 local wallZ = -rows * ROW_DEPTH - 0.5
 part(display, "Backdrop", Vector3.new(width, wallTop, 1), base * CFrame.new(0, wallTop / 2, wallZ), STAGE_COLOR)
 part(display, "BackdropCap", Vector3.new(width + 0.4, 0.6, 1.4), base * CFrame.new(0, wallTop + 0.3, wallZ), TRIM_COLOR)
 local title = Instance.new("Attachment")
 title.Name = "Title"
 local anchor = part(display, "TitleAnchor", Vector3.one * 0.2, base, STAGE_COLOR)
 anchor.Transparency, anchor.CanCollide, anchor.CanQuery = 1, false, false
 title.Parent = anchor
 title.WorldPosition = (base * CFrame.new(0, wallTop + 3, wallZ)).Position
 display.Parent = hub
 return display
end

-- Copies each designed Ball and Bat model, styled, into ReplicatedStorage.BallModels /
-- BatModels so clients can show them (ServerStorage is not visible to clients): balls on the
-- station ball and in flight, both as Inventory icons. BallDiameter is the ball body's size in
-- the model, used to fit the 0.8-stud physics ball.
function ItemDisplay.PublishItemModels()
 -- The Starter Pack's Bat is built from Parts rather than imported.
 require(script.Parent:WaitForChild("CatBatModel")).Ensure()
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
 local assets = game:GetService("ServerStorage"):FindFirstChild("RunwayAssets")
 local source = assets and assets:FindFirstChild("DisplayItems")
 for category, folderName in {Ball = "BallModels", Bat = "BatModels"} do
  local folder = ReplicatedStorage:FindFirstChild(folderName) or Instance.new("Folder")
  folder.Name = folderName
  folder:ClearAllChildren()
  for _, item in Equipment.GetItems(category) do
   local template = source and source:FindFirstChild(item.id)
   local body = template and template:IsA("Model") and mainPart(template)
   if body then
    local model = STYLES[category].ApplyLook(template:Clone(), item.id)
    model.Name = item.id
    if not model.PrimaryPart then model.WorldPivot = body.CFrame end
    if category == "Ball" then model:SetAttribute("BallDiameter", math.max(body.Size.X, body.Size.Y, body.Size.Z)) end
    for _, descendant in model:GetDescendants() do
     if descendant:IsA("BasePart") then
      descendant.Anchored, descendant.CanCollide, descendant.CanTouch, descendant.CanQuery = true, false, false, false
      descendant.Massless = true
     end
    end
    model.Parent = folder
   end
  end
  folder.Parent = ReplicatedStorage
 end
end

return ItemDisplay
