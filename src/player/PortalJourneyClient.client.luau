-- The giant portal at each runway's end (RunwayDecor / WorldPortal.BuildGate), on this client:
--   * its gears, clock hands and swirl turn (their Spin attributes, as the hub portals); when a
--     ball is captured (BallLauncher marks it PortalCaptured) the swirl spins up and a vortex
--     blast swells as the ball is drawn in
--   * the trip, when this player's hit opens the next World (BattingTimingServer holds the
--     batter and sets PortalJourney to the destination; it travels them at 8.6 s):
--       impact    the ball vanishes: a white flash, rings blasting out of the opening,
--                 lightning across it, a boom and thunder, and the music starts
--       reveal    a slow push-in on the giant portal as "WORLD 2 UNLOCKED!" slams in
--       summons   a cut to the batter at the tee: a shockwave, crackling lightning, and they
--                 are lifted off the ground as the riser builds
--       flight    they rocket down the runway toward the portal on a trail of light, with a
--                 chase camera and speed lines
--       plunge    a wide shot as they spiral into the swirl, then white
--       arrival   the white fades in the new World with a shockwave and its title
--   * the temporary finale after the last World (WorldConfig endPortal.finale; the server holds
--     the batter and sets GameFinale, then returns them to the hub at 11.8 s):
--       impact    as the trip, with a winner's anthem
--       reveal    a slow push-in on the giant portal as "YOU FINISHED THE GAME!" slams in
--       fireworks a crane shot rising over the runway's end as fireworks burst round the portal
--       batter    back at the tee, the batter in a shower of confetti and fireworks as the
--                 closing title lands, then white and back to the hub
-- Presentation only: the server unlocks the World and performs the travel.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Worlds = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local GameAudio = require(ReplicatedStorage:WaitForChild("GameAudio"))
local FX = require(script.Parent:WaitForChild("CinematicFX"))
local Player = Players.LocalPlayer
local lerp, smooth, easeOut, rng = FX.lerp, FX.smooth, FX.easeOut, FX.rng

-- Roblox-licensed audio (Pro Sound Effects and APM Music): {id, volume, playbackSpeed, startAt}.
local SOUNDS = {
 Music = {"rbxassetid://1844250707", 0.65, 1, 0.3}, -- APM "New World Anthem Link 4"
 Vortex = {"rbxassetid://9120749149", 0.9}, -- "Wind Burst Alien Vortex Blasts 4" (peaks 2.24 s in)
 Boom = {"rbxassetid://9125484511", 0.85}, -- deep launch boom
 Thunder = {"rbxassetid://9120016021", 0.9, 1, 0.25}, -- "Thunder Cracks Big Rumbling Blasts Booming 2"
 Riser = {"rbxassetid://9043343295", 0.75}, -- reverse swell with a hard end (at 4.0 s)
 Rush = {"rbxassetid://9126233536", 0.95, 1, 0.3}, -- "Whoosh Rumbling Pass By Sharp Rushing Scorch"
 Plunge = {"rbxassetid://9114329395", 0.9}, -- "Energy Cloud Whooshing By Very Fast 1" (peaks 1.45 s in)
 Arrive = {"rbxassetid://9116422213", 0.8}, -- "Magic Transformation 17"
}
local VORTEX_PEAK, PLUNGE_PEAK, RISER_END = 2.24, 1.45, 4.0
local SUCTION_SECONDS = 1.4 -- BallLauncher's PORTAL_SUCTION_SECONDS

-- Timeline (seconds from the start of the trip).
local REVEAL_END = 2.2
local TITLE_AT = 0.9
local TAKEOFF = 3.6
local FLIGHT_END = 6.0
local WHITE_AT = 6.85
local WAIT_LIMIT = 12 -- give up waiting for the travel after this long
local MUSIC_SECONDS = 11.5
-- Screens hidden during the trip (the HUD with its Cash popup, progress popups, notices).
local HIDDEN_SCREENS = {"GameHUD", "ProgressFeedback", "NotificationGui", "HitCinematic"}
local LIFT_HEIGHT = 8
local FLIGHT_ARC = 170 -- studs the flight rises above a straight line at its middle
local SPIN_BOOST = 7

local CYAN = Color3.fromRGB(110, 235, 255)
local GOLD = Color3.fromRGB(255, 210, 90)
local THEME = {
 edge = CYAN, stroke = Color3.fromRGB(18, 30, 70), subtitleColor = Color3.fromRGB(200, 245, 255),
 speedLineColor = Color3.fromRGB(200, 245, 255),
 titleColors = ColorSequence.new({
  ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 200, 255)), ColorSequenceKeypoint.new(0.42, Color3.fromRGB(160, 240, 255)),
  ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.58, Color3.fromRGB(255, 225, 130)),
  ColorSequenceKeypoint.new(1, GOLD)}),
}
local GRADE = {Saturation = 0.25, Contrast = 0.18, Brightness = 0.02, TintColor = Color3.fromRGB(225, 240, 255)}
local NEUTRAL = {Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1)}

-- The finale's own audio (APM Music and Pro Sound Effects).
local FINALE_SOUNDS = {
 Music = {"rbxassetid://1845666791", 0.6}, -- APM "A Winner's Anthem"
 Fireworks = {"rbxassetid://9114447096", 0.5}, -- "Fireworks Fast 1": launches and bangs
 Sparkle = {"rbxassetid://9114447277", 0.4}, -- "Fireworks Sparks 1": crackling tails
 Cheer = {"rbxassetid://9120975204", 0.3}, -- "Wrestling Crowd 2": a cheering crowd
}
-- Finale timeline (seconds from its start); BattingTimingServer's GAME_FINALE_SECONDS is 11.8.
local FINALE_REVEAL_END = 3.2
local FINALE_TITLE_AT = 0.9
local FINALE_BATTER_AT = 7.6
local FINALE_CLOSING_AT = 8.1
local FINALE_WHITE_AT = 11.2
local FIREWORK_COLORS = {Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 210, 90), Color3.fromRGB(110, 235, 255),
 Color3.fromRGB(180, 120, 255), Color3.fromRGB(120, 255, 160), Color3.new(1, 1, 1)}

local specs = {}
for _, spec in SOUNDS do table.insert(specs, spec) end
for _, spec in FINALE_SOUNDS do table.insert(specs, spec) end
FX.Preload(specs)

-- ---------- the giant portals' motion ----------

local animated = {}
local spinBoost, boostTarget = 1, 1
local function track(part)
 if animated[part] or not part:IsA("BasePart") or not part:GetAttribute("Spin") then return end
 animated[part] = {base = part.CFrame, spin = math.rad(part:GetAttribute("Spin")), axis = part:GetAttribute("SpinAxis") or Vector3.zAxis, angle = 0}
end

local function gateOf(world)
 local field = world and workspace:FindFirstChild(world.fieldName)
 return field and field:FindFirstChild("EndPortal", true)
end

-- A captured ball: the swirl spins up and a vortex blast peaks as the ball reaches the centre.
local function captured(world)
 local gate = gateOf(world)
 if not gate then return end
 boostTarget = SPIN_BOOST
 local holder = FX.Part("PortalCaptureSound", CFrame.new(gate:GetAttribute("OpeningCenter")))
 FX.Sound(SOUNDS.Vortex, holder, {TimePosition = math.max(0, VORTEX_PEAK - SUCTION_SECONDS), RollOffMaxDistance = 2000})
 game:GetService("Debris"):AddItem(holder, 4)
 task.delay(SUCTION_SECONDS + 1.5, function() if not Player:GetAttribute("PortalJourney") then boostTarget = 1 end end)
end

local function watchWorld(world)
 task.spawn(function()
  local field = workspace:WaitForChild(world.fieldName, 60)
  if field then
   field.DescendantAdded:Connect(function(object)
    if object:FindFirstAncestor("EndPortal") then track(object) end
   end)
   local gate = field:FindFirstChild("EndPortal", true)
   for _, object in (gate and gate:GetDescendants() or {}) do track(object) end
  end
  local area = workspace:WaitForChild(world.stationName, 60)
  local ball = area and area:WaitForChild("Baseball", 60)
  if ball then
   ball:GetAttributeChangedSignal("PortalCaptured"):Connect(function()
    if ball:GetAttribute("PortalCaptured") then captured(world) end
   end)
  end
 end)
end
for _, world in Worlds.Worlds do watchWorld(world) end

RunService.RenderStepped:Connect(function(dt)
 spinBoost += (boostTarget - spinBoost) * math.min(1, dt * 2)
 for part, state in animated do
  if not part.Parent then
   animated[part] = nil
   continue
  end
  state.angle = (state.angle + state.spin * spinBoost * dt) % (2 * math.pi)
  part.CFrame = state.base * CFrame.fromAxisAngle(state.axis, state.angle)
 end
end)

-- ---------- effects ----------

-- A glowing ring blasting out of the opening, standing in the portal's plane.
local function ring(center, forward, fromSize, toSize, seconds, color)
 local frame = CFrame.fromMatrix(center, forward, Vector3.yAxis)
 local disc = FX.Neon("PortalRing", frame, Vector3.new(0.4, fromSize, fromSize), color, 0.15, Enum.PartType.Cylinder)
 FX.Tween(disc, seconds, {Size = Vector3.new(0.4, toSize, toSize), Transparency = 1})
 game:GetService("Debris"):AddItem(disc, seconds)
end

-- Lightning across the opening, from its rim toward the middle.
local function rimBolts(center, right, radius, count)
 for _ = 1, count do
  local a = rng:NextNumber(0, 2 * math.pi)
  local from = center + (right * math.cos(a) + Vector3.yAxis * math.sin(a)) * radius * 1.02
  local b = a + rng:NextNumber(-1, 1)
  local to = center + (right * math.cos(b) + Vector3.yAxis * math.sin(b)) * radius * rng:NextNumber(0.1, 0.5)
  FX.Bolt(from, to, rng:NextNumber() < 0.5 and CYAN or Color3.new(1, 1, 1), rng:NextNumber(1.2, 2.4), 0.22)
 end
end

local function setVisible(character, visible)
 for _, part in character:GetDescendants() do
  if part:IsA("BasePart") or part:IsA("Decal") then part.LocalTransparencyModifier = visible and 0 or 1 end
 end
end

-- ---------- the trip ----------

local running = false
local function journey()
 if running then return end
 local world = Worlds.Get(Player:GetAttribute("CurrentWorldId"))
 local destination = Worlds.Get(Player:GetAttribute("PortalJourney"))
 local gate = gateOf(world)
 local area = world and workspace:FindFirstChild(world.stationName)
 local character = Player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not gate or not area or not root or not destination then return end
 running = true
 local c = {}
 local center, radius = gate:GetAttribute("OpeningCenter"), gate:GetAttribute("OpeningRadius")
 local difference = area.HitDirection.Position - area.Tee.Stem.Position
 local forward = Vector3.new(difference.X, 0, difference.Z).Unit
 local right = forward:Cross(Vector3.yAxis)
 local home = root.CFrame -- where the server holds the batter
 local camera = workspace.CurrentCamera
 local startFov = camera.FieldOfView
 local approach = center - forward * radius * 0.9 -- the flight ends here; the plunge takes it in
 local liftTop = home.Position + Vector3.yAxis * LIFT_HEIGHT
 task.spawn(function() pcall(function() Player:RequestStreamAroundAsync(center) end) end)

 GameAudio.Duck("PortalJourney", "Cinematic")
 boostTarget = SPIN_BOOST
 -- The HUD, popups and notices stay out of the shot until the arrival.
 local hidden = {}
 for _, name in HIDDEN_SCREENS do
  local screen = Player.PlayerGui:FindFirstChild(name)
  if screen and screen:IsA("ScreenGui") and screen.Enabled then
   screen.Enabled = false
   table.insert(hidden, screen)
  end
 end
 Player:SetAttribute("CinematicCamera", true)
 camera.CameraType = Enum.CameraType.Scriptable
 THEME.title = string.upper(destination.displayName) .. " UNLOCKED!"
 THEME.subtitle = string.upper(destination.title or "")
 FX.ShowScreen(THEME)
 FX.Flash(Color3.new(1, 1, 1), 0, 0.6)
 FX.SetBars(0.13, 0.35)
 local grade = Instance.new("ColorCorrectionEffect")
 grade.Name, grade.Parent = "PortalJourneyGrade", Lighting
 FX.Tween(grade, 0.4, GRADE)

 -- Impact.
 FX.PlayFor(c, SOUNDS.Boom, game:GetService("SoundService"))
 FX.PlayFor(c, SOUNDS.Thunder, game:GetService("SoundService"))
 local music = FX.PlayFor(c, SOUNDS.Music, game:GetService("SoundService"))
 for k = 0, 2 do
  task.delay(k * 0.12, ring, center, forward, radius * 0.6, radius * (4 + k), 1.1 + k * 0.2, k == 1 and GOLD or CYAN)
 end
 rimBolts(center, right, radius, 8)
 local inflow = FX.Part("PortalInflow", CFrame.new(center), Vector3.one * radius * 2.4)
 local streams = FX.Emitter(inflow, {Texture = FX.Textures.Sparkle, Shape = Enum.ParticleEmitterShape.Sphere,
  ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
  Speed = NumberRange.new(radius * 1.3), Lifetime = NumberRange.new(0.85), Rate = 160,
  Color = ColorSequence.new(Color3.fromRGB(190, 250, 255), Color3.fromRGB(70, 160, 255)),
  Size = NumberSequence.new(radius * 0.07, radius * 0.01), Transparency = NumberSequence.new(0.05, 0.8)})

 -- The batter's light: an aura while summoned, then a trail of light in flight.
 local aura = FX.Emitter(root, {Texture = FX.Textures.Sparkle, Speed = NumberRange.new(3, 8), Lifetime = NumberRange.new(0.5, 0.8),
  Rate = 0, SpreadAngle = Vector2.new(180, 180), Color = ColorSequence.new(CYAN, GOLD), Size = NumberSequence.new(1.4, 0)})
 local comet

 local startedAt = os.clock()
 local nextBolt, shake = 0, 0.6
 local played = {}
 local function once(key, at, fn)
  if not played[key] and os.clock() - startedAt >= at then
   played[key] = true
   fn()
  end
 end
 local connection = RunService.RenderStepped:Connect(function(dt)
  local t = os.clock() - startedAt
  shake = math.max(0, shake - dt * 0.8)
  local jolt = Vector3.new(math.noise(t * 9, 0.2), math.noise(0.6, t * 9), math.noise(t * 9, 4.1)) * shake * 3

  once("title", TITLE_AT, function() FX.ShowTitle() end)
  once("riserStart", math.max(0, TAKEOFF - RISER_END), function()
   FX.PlayFor(c, SOUNDS.Riser, game:GetService("SoundService"), {TimePosition = math.max(0, RISER_END - TAKEOFF)})
  end)
  once("plungeSound", FLIGHT_END + 0.6 - PLUNGE_PEAK, function() FX.PlayFor(c, SOUNDS.Plunge, game:GetService("SoundService")) end)

  if t < REVEAL_END then
   -- Reveal: a slow push-in on the giant portal from low on the runway.
   local s = smooth(t / REVEAL_END)
   local eye = center - forward * lerp(radius * 3.4, radius * 2.3, s) + right * lerp(radius * 0.7, radius * 0.25, s)
    + Vector3.yAxis * lerp(-radius * 1.1, -radius * 0.55, s)
   camera.CFrame = CFrame.lookAt(eye + jolt, center)
   camera.FieldOfView = lerp(62, 54, s)
   if t >= nextBolt then
    nextBolt = t + 0.28
    rimBolts(center, right, radius, 2)
   end
  elseif t < TAKEOFF then
   -- Summons: back at the tee, the batter is lifted as lightning crackles around them.
   once("summon", REVEAL_END, function()
    FX.Flash(Color3.new(1, 1, 1), 0.3, 0.35)
    FX.Shockwave(home.Position - Vector3.yAxis * 2.8, CYAN, 2, 40, 0.9)
    FX.HideTitle()
    aura.Rate = 90
    shake = 0.35
   end)
   local s = smooth((t - REVEAL_END) / (TAKEOFF - REVEAL_END))
   local position = home.Position:Lerp(liftTop, easeOut(s))
   root.CFrame = CFrame.lookAt(position, position + forward) * CFrame.Angles(0, s * math.pi * 1.5, 0)
   if t >= nextBolt then
    nextBolt = t + 0.18
    FX.Bolt(position + rng:NextUnitVector() * 6, position + rng:NextUnitVector() * 1.5, CYAN, 0.25, 0.15)
   end
   local eye = home.Position - forward * 15 + right * 7 + Vector3.yAxis * lerp(1, 4, s)
   camera.CFrame = CFrame.lookAt(eye + jolt * 0.3, position + Vector3.yAxis * 1.5)
   camera.FieldOfView = lerp(55, 64, s)
  elseif t < FLIGHT_END then
   -- Flight: down the runway on a trail of light, arcing high, into the portal's mouth.
   once("takeoff", TAKEOFF, function()
    FX.PlayFor(c, SOUNDS.Rush, game:GetService("SoundService"))
    FX.Flash(CYAN, 0.55, 0.3)
    shake = 0.5
    comet = FX.Comet(liftTop, {
     {3, {Lifetime = 0.5, LightEmission = 1, Brightness = 2, Color = ColorSequence.new(Color3.new(1, 1, 1), CYAN),
      Transparency = NumberSequence.new(0, 1), WidthScale = NumberSequence.new(1, 0.1)}},
     {6, {Lifetime = 0.9, LightEmission = 1, Brightness = 1, Color = ColorSequence.new(GOLD, Color3.fromRGB(80, 140, 255)),
      Transparency = NumberSequence.new(0.35, 1), WidthScale = NumberSequence.new(1, 0)}},
    }, {}, {CYAN, 3, 30})
   end)
   local s = (t - TAKEOFF) / (FLIGHT_END - TAKEOFF)
   local e = s < 0.5 and 4 * s ^ 3 or 1 - (-2 * s + 2) ^ 3 / 2
   local position = liftTop:Lerp(approach, e) + Vector3.yAxis * math.sin(math.pi * e) * FLIGHT_ARC
   local ahead = liftTop:Lerp(approach, math.min(1, e + 0.02)) + Vector3.yAxis * math.sin(math.pi * math.min(1, e + 0.02)) * FLIGHT_ARC
   local heading = (ahead - position).Magnitude > 0.01 and (ahead - position).Unit or forward
   root.CFrame = CFrame.lookAt(position, position + heading) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, t * 9, 0)
   if comet then comet.CFrame = CFrame.new(position) end
   camera.CFrame = CFrame.lookAt(position - heading * 28 + Vector3.yAxis * 7 + jolt * 0.4, position + heading * 60)
   camera.FieldOfView = lerp(72, 104, math.sin(math.pi * math.min(1, s * 1.2)) * 0.6 + s * 0.4)
   FX.SpeedLines(0.5 + 0.5 * math.sin(math.pi * s))
  else
   -- Plunge: a wide shot as the batter spirals into the swirl.
   once("plunge", FLIGHT_END, function()
    FX.SpeedLines(nil)
    if comet then FX.FadeOut(comet, 1) comet = nil end
    aura.Rate = 140
    rimBolts(center, right, radius, 6)
   end)
   local s = math.clamp((t - FLIGHT_END) / (WHITE_AT - FLIGHT_END), 0, 1)
   local e = s ^ 1.8
   local angle = e * 3 * math.pi
   local swirl = (right * math.cos(angle) + Vector3.yAxis * math.sin(angle)) * radius * 0.35 * (1 - e)
   local position = approach:Lerp(center, e) + swirl
   root.CFrame = CFrame.lookAt(position, center) * CFrame.Angles(0, 0, t * 14)
   local eye = center - forward * radius * 1.6 + right * radius * 0.9 + Vector3.yAxis * radius * 0.15
   camera.CFrame = CFrame.lookAt(eye:Lerp(center - forward * radius * 1.1, e * 0.4) + jolt * 0.5, center:Lerp(position, 0.5))
   camera.FieldOfView = lerp(60, 48, e)
   if s > 0.85 then setVisible(character, false) end
   once("white", WHITE_AT, function()
    FX.PlayFor(c, SOUNDS.Boom, game:GetService("SoundService"), {Volume = 0.6, PlaybackSpeed = 1.2})
    ring(center, forward, radius * 0.2, radius * 3, 0.5, Color3.new(1, 1, 1))
   end)
  end
 end)

 -- White covers the screen from WHITE_AT until the server has moved us (PortalJourney clears).
 local white = Instance.new("ScreenGui")
 white.Name, white.DisplayOrder, white.ResetOnSpawn, white.IgnoreGuiInset = "PortalWhite", 60, false, true
 local fill = Instance.new("Frame")
 fill.Size, fill.BorderSizePixel, fill.BackgroundColor3, fill.BackgroundTransparency = UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1), 1
 fill.Parent = white
 white.Parent = Player:WaitForChild("PlayerGui")
 task.delay(WHITE_AT - 0.2, function() FX.Tween(fill, 0.25, {BackgroundTransparency = 0}) end)
 local waited = os.clock()
 while Player:GetAttribute("PortalJourney") and os.clock() - waited < WAIT_LIMIT do task.wait() end
 while os.clock() - startedAt < WHITE_AT + 0.1 do task.wait() end
 connection:Disconnect()
 fill.BackgroundTransparency = 0
 streams.Enabled = false
 game:GetService("Debris"):AddItem(inflow, 1)
 aura:Destroy()
 if comet then comet:Destroy() end
 FX.SpeedLines(nil)
 boostTarget = 1

 -- Arrival: the camera returns to the batter in the new World as the white fades.
 local newCharacter = Player.Character
 if newCharacter then setVisible(newCharacter, true) end
 camera.CameraType = Enum.CameraType.Custom
 camera.FieldOfView = startFov
 local humanoid = newCharacter and newCharacter:FindFirstChildOfClass("Humanoid")
 if humanoid then camera.CameraSubject = humanoid end
 Player:SetAttribute("CinematicCamera", nil)
 local newRoot = newCharacter and newCharacter:FindFirstChild("HumanoidRootPart")
 task.wait(0.15)
 FX.Tween(fill, 0.9, {BackgroundTransparency = 1})
 FX.PlayFor(c, SOUNDS.Arrive, game:GetService("SoundService"))
 if newRoot then
  FX.Shockwave(newRoot.Position - Vector3.yAxis * 2.8, CYAN, 2, 50, 1.1)
  local burst = FX.Part("ArrivalBurst", newRoot.CFrame)
  FX.Emitter(burst, {Texture = FX.Textures.Sparkle, Speed = NumberRange.new(10, 26), Lifetime = NumberRange.new(0.6, 1.1),
   Rate = 0, SpreadAngle = Vector2.new(180, 180), Color = ColorSequence.new(CYAN, GOLD), Size = NumberSequence.new(1.6, 0)}):Emit(60)
  game:GetService("Debris"):AddItem(burst, 2)
 end
 -- A World whose hits start over says so (WorldConfig arrivalNote), held a little longer to read.
 THEME.title = string.upper(destination.title or destination.displayName)
 THEME.subtitle = destination.arrivalNote or "WELCOME TO " .. string.upper(destination.displayName)
 FX.ShowScreen(THEME)
 FX.SetBars(0.13, 0)
 FX.ShowTitle()
 FX.Tween(grade, 1.5, NEUTRAL)
 task.wait(destination.arrivalNote and 3.4 or 2.4)
 FX.HideTitle()
 FX.SetBars(0, 0.6)
 GameAudio.Unduck("PortalJourney")
 for _, screen in hidden do
  if screen.Parent then screen.Enabled = true end
 end
 task.wait(0.7)
 FX.HideScreen()
 white:Destroy()
 grade:Destroy()
 -- The music's tail plays out, then everything is cleared.
 task.delay(math.max(0, MUSIC_SECONDS - (os.clock() - startedAt)), function() FX.FadeSounds(c, 1.5) end)
 if music then music.Looped = false end
 running = false
end

Player:GetAttributeChangedSignal("PortalJourney"):Connect(function()
 if Player:GetAttribute("PortalJourney") then task.spawn(journey) end
end)

-- ---------- the finale (temporary, after the last World) ----------

-- A firework: a bright shell streaks up from `from` to `at`, then bursts into a sphere of
-- sparks that droop and fade. size scales the burst (studs per unit of spark speed).
local function firework(from, at, color, size)
 local shell = FX.Neon("FireworkShell", CFrame.new(from), Vector3.one * size * 0.5, color:Lerp(Color3.new(1, 1, 1), 0.6), 0,
  Enum.PartType.Ball)
 local tail = FX.Emitter(shell, {Texture = FX.Textures.Sparkle, Speed = NumberRange.new(0), Lifetime = NumberRange.new(0.35, 0.5),
  Rate = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), color), Size = NumberSequence.new(size * 0.45, 0)})
 local rise = rng:NextNumber(0.45, 0.65)
 FX.Tween(shell, rise, {CFrame = CFrame.new(at)})
 task.delay(rise, function()
  tail.Enabled = false
  shell.Transparency = 1
  local burst = FX.Part("FireworkBurst", CFrame.new(at))
  FX.Emitter(burst, {Texture = FX.Textures.Sparkle, Speed = NumberRange.new(size * 9, size * 13), Lifetime = NumberRange.new(1.1, 1.7),
   Rate = 0, SpreadAngle = Vector2.new(180, 180), Drag = 1.8, Acceleration = Vector3.new(0, -size * 3, 0),
   Color = ColorSequence.new(Color3.new(1, 1, 1), color), Size = NumberSequence.new(size * 1.2, 0),
   Transparency = NumberSequence.new(0, 1)}):Emit(70)
  FX.Emitter(burst, {Texture = FX.Textures.Spark, Speed = NumberRange.new(size * 4, size * 7), Lifetime = NumberRange.new(0.6, 1),
   Rate = 0, SpreadAngle = Vector2.new(180, 180), Drag = 2, Color = ColorSequence.new(color), Size = NumberSequence.new(size * 0.5, 0)}):Emit(30)
  local light = Instance.new("PointLight")
  light.Color, light.Brightness, light.Range = color, 4, size * 16
  light.Parent = burst
  FX.Tween(light, 1.2, {Brightness = 0})
  game:GetService("Debris"):AddItem(burst, 2.2)
  game:GetService("Debris"):AddItem(shell, 1)
 end)
end

-- Confetti showering down over the batter (a box of coloured flakes above them).
local function confetti(position)
 local zone = FX.Part("FinaleConfetti", CFrame.new(position + Vector3.yAxis * 14), Vector3.new(26, 1, 26))
 local keys = {}
 for index, color in FIREWORK_COLORS do
  table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#FIREWORK_COLORS - 1), color))
 end
 local flakes = FX.Emitter(zone, {Texture = FX.Textures.Spark, Shape = Enum.ParticleEmitterShape.Box,
  EmissionDirection = Enum.NormalId.Bottom, Speed = NumberRange.new(2, 5), Lifetime = NumberRange.new(2.5, 3.5),
  Rate = 140, Acceleration = Vector3.new(0, -6, 0), Drag = 0.6, RotSpeed = NumberRange.new(-300, 300),
  Rotation = NumberRange.new(0, 360), LightEmission = 0.4, Color = ColorSequence.new(keys), Size = NumberSequence.new(0.45, 0.3)})
 return zone, flakes
end

local function hideScreens()
 local hidden = {}
 for _, name in HIDDEN_SCREENS do
  local screen = Player.PlayerGui:FindFirstChild(name)
  if screen and screen:IsA("ScreenGui") and screen.Enabled then
   screen.Enabled = false
   table.insert(hidden, screen)
  end
 end
 return hidden
end

local function finale()
 if running then return end
 local world = Worlds.Get(Player:GetAttribute("GameFinale"))
 local text = world and world.endPortal and world.endPortal.finale
 local gate = gateOf(world)
 local area = world and workspace:FindFirstChild(world.stationName)
 local character = Player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not text or not gate or not area or not root then return end
 running = true
 local c = {}
 local center, radius = gate:GetAttribute("OpeningCenter"), gate:GetAttribute("OpeningRadius")
 local difference = area.HitDirection.Position - area.Tee.Stem.Position
 local forward = Vector3.new(difference.X, 0, difference.Z).Unit
 local right = forward:Cross(Vector3.yAxis)
 local home = root.CFrame -- where the server holds the batter
 local floor = home.Position.Y - 3 -- about the ground under the batter and the runway
 local camera = workspace.CurrentCamera
 local startFov = camera.FieldOfView
 task.spawn(function() pcall(function() Player:RequestStreamAroundAsync(center) end) end)

 GameAudio.Duck("PortalJourney", "Cinematic")
 boostTarget = SPIN_BOOST
 local hidden = hideScreens()
 Player:SetAttribute("CinematicCamera", true)
 camera.CameraType = Enum.CameraType.Scriptable
 local theme = {edge = GOLD, stroke = Color3.fromRGB(70, 34, 8), subtitleColor = Color3.fromRGB(255, 240, 200),
  speedLineColor = Color3.fromRGB(255, 240, 200), title = text.title, subtitle = text.subtitle,
  titleColors = ColorSequence.new({
   ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 50)), ColorSequenceKeypoint.new(0.42, Color3.fromRGB(255, 228, 130)),
   ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.58, Color3.fromRGB(170, 240, 255)),
   ColorSequenceKeypoint.new(1, CYAN)})}
 FX.ShowScreen(theme)
 FX.Flash(Color3.new(1, 1, 1), 0, 0.6)
 FX.SetBars(0.13, 0.35)
 local grade = Instance.new("ColorCorrectionEffect")
 grade.Name, grade.Parent = "PortalJourneyGrade", Lighting
 FX.Tween(grade, 0.4, GRADE)

 -- Impact: the ball is swallowed; the anthem starts.
 local sounds = game:GetService("SoundService")
 FX.PlayFor(c, SOUNDS.Boom, sounds)
 FX.PlayFor(c, SOUNDS.Thunder, sounds)
 local music = FX.PlayFor(c, FINALE_SOUNDS.Music, sounds)
 for k = 0, 2 do
  task.delay(k * 0.12, ring, center, forward, radius * 0.6, radius * (4 + k), 1.1 + k * 0.2, k == 1 and GOLD or CYAN)
 end
 rimBolts(center, right, radius, 8)

 local startedAt = os.clock()
 local nextBolt, nextFirework, shake = 0, FINALE_REVEAL_END - 0.6, 0.6
 local played = {}
 local function once(key, at, fn)
  if not played[key] and os.clock() - startedAt >= at then
   played[key] = true
   fn()
  end
 end
 local confettiZone, flakes
 local connection = RunService.RenderStepped:Connect(function(dt)
  local t = os.clock() - startedAt
  shake = math.max(0, shake - dt * 0.8)
  local jolt = Vector3.new(math.noise(t * 9, 0.2), math.noise(0.6, t * 9), math.noise(t * 9, 4.1)) * shake * 3

  once("title", FINALE_TITLE_AT, function() FX.ShowTitle() end)
  once("fireworksSound", FINALE_REVEAL_END - 0.6, function()
   FX.PlayFor(c, FINALE_SOUNDS.Fireworks, sounds)
   FX.PlayFor(c, FINALE_SOUNDS.Sparkle, sounds, {TimePosition = 0.5})
  end)
  once("fireworksSound2", FINALE_REVEAL_END + 2.8, function() FX.PlayFor(c, FINALE_SOUNDS.Fireworks, sounds, {PlaybackSpeed = 1.08}) end)

  if t < FINALE_BATTER_AT and t >= nextFirework then
   -- Fireworks round the portal, launched from the runway's end.
   nextFirework = t + rng:NextNumber(0.18, 0.34)
   local at = center + right * rng:NextNumber(-2.4, 2.4) * radius + Vector3.yAxis * rng:NextNumber(0.2, 1.5) * radius
    + forward * rng:NextNumber(-0.6, 0.6) * radius
   local from = Vector3.new(at.X, floor, at.Z) - forward * rng:NextNumber(0.2, 0.8) * radius
   firework(from, at, FIREWORK_COLORS[rng:NextInteger(1, #FIREWORK_COLORS)], radius * rng:NextNumber(0.06, 0.1))
  end

  if t < FINALE_REVEAL_END then
   -- Reveal: a slow push-in on the giant portal from low on the runway.
   local s = smooth(t / FINALE_REVEAL_END)
   local eye = center - forward * lerp(radius * 3.4, radius * 2.4, s) + right * lerp(radius * 0.7, radius * 0.25, s)
    + Vector3.yAxis * lerp(-radius * 1.1, -radius * 0.6, s)
   camera.CFrame = CFrame.lookAt(eye + jolt, center)
   camera.FieldOfView = lerp(62, 55, s)
   if t >= nextBolt then
    nextBolt = t + 0.3
    rimBolts(center, right, radius, 2)
   end
  elseif t < FINALE_BATTER_AT then
   -- Fireworks: a crane shot rising and sweeping across the runway's end.
   local s = smooth((t - FINALE_REVEAL_END) / (FINALE_BATTER_AT - FINALE_REVEAL_END))
   local eye = center - forward * lerp(radius * 5.4, radius * 4.4, s) + right * lerp(-radius * 1.6, radius * 1.4, s)
    + Vector3.yAxis * lerp(-radius * 0.7, radius * 0.9, s)
   camera.CFrame = CFrame.lookAt(eye + jolt * 0.4, center + Vector3.yAxis * radius * 0.4)
   camera.FieldOfView = lerp(72, 64, s)
  else
   -- The batter: back at the tee in a shower of confetti, the camera circling them.
   once("batter", FINALE_BATTER_AT, function()
    FX.Flash(Color3.new(1, 1, 1), 0.3, 0.35)
    FX.Shockwave(home.Position - Vector3.yAxis * 2.8, GOLD, 2, 46, 1)
    FX.HideTitle()
    FX.PlayFor(c, FINALE_SOUNDS.Cheer, sounds)
    confettiZone, flakes = confetti(home.Position)
    nextFirework = t
   end)
   once("closing", FINALE_CLOSING_AT, function()
    theme.title = text.closing or text.title
    theme.subtitle = string.upper(world.displayName) .. " COMPLETE"
    FX.ShowScreen(theme)
    FX.ShowTitle()
   end)
   if t >= nextFirework then
    nextFirework = t + rng:NextNumber(0.3, 0.5)
    local at = home.Position + forward * rng:NextNumber(30, 70) + right * rng:NextNumber(-45, 45) + Vector3.yAxis * rng:NextNumber(30, 55)
    firework(Vector3.new(at.X, floor, at.Z), at, FIREWORK_COLORS[rng:NextInteger(1, #FIREWORK_COLORS)], rng:NextNumber(1.3, 2))
   end
   -- From behind the batter, swinging round them, looking up at the fireworks downfield.
   local s = smooth((t - FINALE_BATTER_AT) / (FINALE_WHITE_AT - FINALE_BATTER_AT))
   local offset = CFrame.fromAxisAngle(Vector3.yAxis, lerp(-0.7, 0.7, s)):VectorToWorldSpace(-forward * 12)
   camera.CFrame = CFrame.lookAt(home.Position + offset + Vector3.yAxis * lerp(3, 6, s), home.Position + forward * 25 + Vector3.yAxis * 10)
   camera.FieldOfView = lerp(64, 72, s)
  end
 end)

 -- White covers the screen from FINALE_WHITE_AT until the server has moved us (GameFinale clears).
 local white = Instance.new("ScreenGui")
 white.Name, white.DisplayOrder, white.ResetOnSpawn, white.IgnoreGuiInset = "PortalWhite", 60, false, true
 local fill = Instance.new("Frame")
 fill.Size, fill.BorderSizePixel, fill.BackgroundColor3, fill.BackgroundTransparency = UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1), 1
 fill.Parent = white
 white.Parent = Player:WaitForChild("PlayerGui")
 task.delay(FINALE_WHITE_AT - 0.4, function() FX.Tween(fill, 0.4, {BackgroundTransparency = 0}) end)
 local waited = os.clock()
 while Player:GetAttribute("GameFinale") and os.clock() - waited < WAIT_LIMIT + 4 do task.wait() end
 while os.clock() - startedAt < FINALE_WHITE_AT + 0.1 do task.wait() end
 connection:Disconnect()
 fill.BackgroundTransparency = 0
 if flakes then flakes.Enabled = false end
 if confettiZone then game:GetService("Debris"):AddItem(confettiZone, 4) end
 boostTarget = 1

 -- Back in the hub as the white fades.
 local newCharacter = Player.Character
 camera.CameraType = Enum.CameraType.Custom
 camera.FieldOfView = startFov
 local humanoid = newCharacter and newCharacter:FindFirstChildOfClass("Humanoid")
 if humanoid then camera.CameraSubject = humanoid end
 Player:SetAttribute("CinematicCamera", nil)
 task.wait(0.15)
 FX.HideTitle()
 FX.Tween(fill, 0.9, {BackgroundTransparency = 1})
 FX.SetBars(0, 0.6)
 FX.Tween(grade, 1.5, NEUTRAL)
 GameAudio.Unduck("PortalJourney")
 for _, screen in hidden do
  if screen.Parent then screen.Enabled = true end
 end
 task.wait(0.7)
 FX.HideScreen()
 white:Destroy()
 task.delay(1, function() grade:Destroy() end)
 if music then music.Looped = false end
 -- (FX.Sound removes its sounds 14 s after they start, so the fade ends before then.)
 FX.FadeSounds(c, 1.2)
 running = false
end

Player:GetAttributeChangedSignal("GameFinale"):Connect(function()
 if Player:GetAttribute("GameFinale") then task.spawn(finale) end
end)
