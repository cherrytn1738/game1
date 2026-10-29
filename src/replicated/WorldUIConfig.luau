-- Distance visibility for world-space UI (BillboardGuis and SurfaceGuis standing in the
-- hubs). A builder registers each finished gui under one of the Ranges below; WorldUIClient
-- then shows it while the local camera is within that many studs and fades it out once the
-- camera is past the range plus Hysteresis. Measured from the camera, not the character, so
-- batting and cinematic cameras see what is near them.
-- Presentation only: hidden UI never changes what a player can do (prompts, Training, buying).
local CollectionService = game:GetService("CollectionService")

local WorldUI = {
 Tag = "DistanceUI",
 RangeAttribute = "DistanceUIRange",
 -- Studs from the camera. The compact hub is about 175 wide and 220 deep, the spawn stands
 -- 30 in, the Training row runs down the left 33 studs apart and the item displays sit about
 -- 90 across the hub from it.
 Ranges = {
  ItemDisplay = 65, -- one Ball/Bat pedestal's label (status, name, boost, price)
  Interaction = 80, -- "STEP HERE TO BAT" over the batter's box
  Training = 75, -- a Training Ground's floating name, status and multiplier: about 3 cages
  DisplayTitle = 140, -- the BALLS / BATS title over each item display
  Portal = 200, -- the WORLDS sign: seen from the spawn and across the hub, not down the runway
  Leaderboard = 240, -- the global leaderboards' screens, readable from anywhere in the plaza
 },
 Hysteresis = 0.1, -- hide only 10% past the range, so a camera on the edge doesn't flicker
 FadeSeconds = 0.2,
 CheckInterval = 0.15, -- seconds between distance checks
}

-- Whether a gui should be showing, given whether it is showing now.
function WorldUI.ShouldShow(showing, distance, range)
 if showing then return distance <= range * (1 + WorldUI.Hysteresis) end
 return distance < range
end

-- Builders call this once the gui and its contents are made (on the server it replicates).
function WorldUI.Register(gui, category)
 assert(WorldUI.Ranges[category], "Unknown world UI range: " .. tostring(category))
 gui:SetAttribute(WorldUI.RangeAttribute, category)
 CollectionService:AddTag(gui, WorldUI.Tag)
end

return WorldUI
