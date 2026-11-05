-- Studio command-bar script (not Rojo-managed): sorts World 4's imported runway FBX files into
-- ServerStorage.RunwayAssets templates, one Model per template, the way World 3's were grouped.
--
-- 1. In Studio, Import 3D each FBX listed below (default settings), leaving each result in the
--    Workspace under its file name (for example Workspace.RunwayWorld4Home).
-- 2. Paste this whole file into the command bar and press Enter (or run it through MCP).
-- 3. Save the place (the templates live in the place file, not in Git).
--
-- Each manifest mirrors the JSON written beside its FBX (assets/models/<name>.json). A template that
-- already exists is replaced. Templates rest on their base (CENTRED ones on their centre), at
-- Blender size (Roblox imports FBX at 100x; this scales them back by 0.01). The imported model is
-- removed once every part has been moved. Missing imports are reported and skipped.
local manifests = {
 RunwayWorld4Home = {
  GrassBlade = {"GrassBlades", "GrassBladesLight", "GrassDew"},
  HoseReel = {"HoseReelFrame", "HoseReelDrum", "HoseTube", "HoseNozzle"},
  Sprinkler = {"SprinklerBody", "SprinklerMetal", "SprinklerWater"},
  Ladybug = {"LadybugShell", "LadybugSpots", "LadybugBody", "LadybugEyes"},
  Pebble = {"PebbleStoneA", "PebbleStoneB"},
  GiantFence = {"FencePickets", "FenceRails", "FenceGrass"},
  Sandwich = {"SandwichBread", "SandwichCrust", "SandwichLettuce", "SandwichTomato", "SandwichCheese", "SandwichPick"},
  AntLine = {"AntBodies", "AntLegs", "AntEyes", "AntCrumb"},
  PicnicBasket = {"BasketWicker", "BasketWeave", "BasketLid", "BasketHandle", "BasketCloth"},
  Crumbs = {"CrumbBread", "CrumbCrust"},
  BlanketFolds = {"BlanketRed", "BlanketWhite"},
  CuttingBoard = {"BoardWood", "BoardWoodDark", "BoardCarrot", "BoardGreens", "BoardSlices"},
  Toaster = {"ToasterBody", "ToasterTrim", "ToasterChrome", "ToasterToast", "ToasterCrust"},
  Faucet = {"FaucetChrome", "FaucetHandle", "FaucetWater"},
  CerealPiece = {"CerealLoopA", "CerealLoopB", "CerealLoopC"},
  CerealHills = {"CerealHeapBase", "CerealHeapA", "CerealHeapB", "CerealHeapC"},
  AlphabetBlock = {"BlockWood", "BlockPanelA", "BlockPanelB", "BlockPanelC", "BlockLetters"},
  TrainTrack = {"TrackWood", "TrainBody", "TrainCab", "TrainWheels", "TrainTrim"},
  BrickTower = {"BrickRed", "BrickYellow", "BrickBlue", "BrickGreen"},
  ToyBrick = {"ToyBrickA", "ToyBrickB"},
  GiantDie = {"DieBody", "DiePips"},
  PlayingCard = {"CardFace", "CardBack", "CardSuitsRed", "CardSuitsBlack"},
  GamePiece = {"MeepleBody", "MeepleBodyB"},
  ChessPawn = {"PawnBody"},
  BoardGameBox = {"GameBoxBase", "GameBoxLid", "GameBoxArt", "GameBoxBoard"},
 },
}
local CENTRED = {}

local assets = game.ServerStorage:FindFirstChild("RunwayAssets")
if not assets then
 assets = Instance.new("Folder")
 assets.Name = "RunwayAssets"
 assets.Parent = game.ServerStorage
end
local out = {}
for importName, manifest in manifests do
 local source = workspace:FindFirstChild(importName)
 if not source then
  table.insert(out, importName .. ": not imported")
  continue
 end
 local missing = {}
 for _, parts in manifest do
  for _, name in parts do
   if not source:FindFirstChild(name, true) then table.insert(missing, name) end
  end
 end
 if #missing > 0 then
  table.insert(out, importName .. " missing: " .. table.concat(missing, ", "))
  continue
 end
 local made = 0
 for templateName, parts in manifest do
  local old = assets:FindFirstChild(templateName)
  if old then old:Destroy() end
  local model = Instance.new("Model")
  model.Name = templateName
  for _, name in parts do
   local part = source:FindFirstChild(name, true)
   part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
   part.Parent = model
  end
  model.Parent = workspace
  local box, size = model:GetBoundingBox()
  model.WorldPivot = CENTRED[templateName] and CFrame.new(box.Position) or CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
  model:ScaleTo(0.01)
  model:PivotTo(CFrame.new())
  model.Parent = assets
  local _, scaled = model:GetBoundingBox()
  table.insert(out, string.format("%s %.1f x %.1f x %.1f", templateName, scaled.X, scaled.Y, scaled.Z))
  made += 1
  task.wait()
 end
 local left = 0
 for _, d in source:GetDescendants() do
  if d:IsA("BasePart") then left += 1 end
 end
 if left == 0 then source:Destroy() end
 table.insert(out, importName .. ": made " .. made .. ", parts left " .. left)
end
print(table.concat(out, "\n"))
return table.concat(out, "\n")
