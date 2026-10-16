# Baseball Simulator — Game Design

## Core Concept

A Power/Level-based baseball batting simulator where players hit a ball from a batting tee and progress by increasing how far they can hit.

The core gameplay loop is:

Train to gain Power → Level up → hit farther → earn Cash → reach farther sections → unlock worlds → reach Level Cap → Rebirth → repeat

The game is not intended to simulate traditional baseball games. The focus is on satisfying batting, distance progression, equipment progression, and reaching increasingly distant environments.

## Batting

Players approach a batting tee to enter batting mode.

While batting:

- The player is positioned and locked at the batting location.
- Click/tap to swing; every valid swing launches straight downfield at a fixed configured loft.
- Level alone determines launch speed. There is no timing fan, quality, spray, or timing power bonus.
- The server validates station occupancy, session, cooldown, ball readiness, Level, and launch.
- Space / touch Leave exits batting; the established animation and camera remain.

After being hit, the ball uses Roblox physics.

The ball can:

- Fly
- Bounce
- Roll
- Naturally lose speed

The hit ends after the ball has naturally come to rest rather than after a fixed flight duration.

Rolling distance counts toward the final hit distance.

## Distance

Distance is one of the primary measures of progression.

The server calculates the authoritative final hit distance after the ball stops.

Progression distance should represent meaningful downfield travel from the batting location.

Horizontal deviation and vertical height should not artificially increase progression distance.

Longer hits generally produce better rewards and allow the player to reach farther parts of the game.

## Equipment

### Hub access

World 1 uses deliberate physical interactions to open the equipment and world travel interfaces.
Only one hub interface is open at a time. Browsing does not lock movement; batting, an active hit,
death, respawning, and world changes close these interfaces. Equipment changes wait until the
hit has finished and the player has left batting mode. Worlds without a physical hub retain
on-screen access to the same interfaces.

There are two player equipment categories:

### Bat

Bats remain owned, purchasable, equippable, and persistent. They do not affect launch strength or distance.

Each configured Bat increases Power gain from active Training, real hits, and offline Training. Its `powerGainMultiplier` stacks with Rebirth; it never changes Cash, launch speed, loft, or direction. Multiplier values are placeholder balance.

### Ball

Balls primarily increase rewards earned from distance.

The equipped Ball multiplies Cash rewards only. It does not affect launch strength or Power grants.

The physical batting tee remains part of each station. It is not purchasable, owned, or equipped by players.

### Bat lineup, models and swing effects

Ten Bats, cooler as the price rises (Power multipliers stack with Rebirth; placeholder balance):

| Bat (id) | Price | Power | Swing trail / contact burst |
|---|---|---|---|
| Wood Bat (wood_bat) | Free | ×1 | none |
| Metal Bat (metal_bat) | 300 | ×1.5 | faint white swoosh |
| Jungle Bat (jungle_bat) | 900 | ×2 | green swoosh / leaves |
| Amethyst Bat (amethyst_bat) | 2,000 | ×2.5 | purple swoosh / gem sparkle |
| Candy Cane Bat (candy_cane_bat) | 6,000 | ×3.2 | pink-and-white swirl / sprinkles |
| Frostbite Bat (frostbite_bat) | 15,000 | ×4 | icy trail / frost ring |
| Magma Bat (magma_bat) | 40,000 | ×5 | fire trail / fire burst |
| Lightning Bat (lightning_bat) | 100,000 | ×6.5 | flickering trail / lightning zap |
| Dragon Bone Bat (dragon_bone_bat) | 250,000 | ×8 | flame trail / fire burst |
| Celestial Bat (celestial_bat) | 600,000 | ×10 | rainbow trail / starburst and shockwave |

The Alloy and Carbon Bats were removed (cleared from the developer's save; other saves drop them on load).

- **Models:** `tools/blender/bats.py` exports `assets/models/Bats.fbx`. Every bat matches the Bat tool: hand (Handle) at the origin, knob -0.52..-0.40, grip to 0.50, barrel to 3.40 along the Handle's +Y, so the grip and swing animation are unchanged. Each has a `Grip` and a `Barrel` part.
- **In hand:** `EquipmentVisualServer` welds the styled model (`BatStyles`) to the Handle, massless and non-colliding, and hides the plain BatBody/BatGrip/BatKnob. Without a model the plain bat is painted as before.
- **Swing trail:** the server adds `SwingTrailBase` (y 1.6) and `SwingTrailTip` (y 3.4) to the Handle; `BatEffects` on every client draws the bat's trail between them while the tip moves faster than 30 studs/s (real and practice swings).
- **Contact burst:** when a ball leaves the tee, the batter's Bat burst plays at the tee (with the ball's launch burst).
- **Display:** the Bat Display (upright 3.6-stud bats) stands beside the Ball Display at the back of the hub; both face the spawn.

### Ball lineup, models and flight effects

Ten Balls, cooler as the price rises (prices and multipliers are placeholder balance):

| Ball (id) | Price | Cash | Flight |
|---|---|---|---|
| Baseball (baseball) | Free | ×1 | none |
| Sandlot Ball (practice_ball) | 250 | ×1.3 | thin white streak, dust where it lands |
| Bubblegum Ball (bubblegum_ball) | 800 | ×1.7 | pink trail, bubbles, sprinkle burst |
| Crystal Ball (crystal_ball) | 1,800 | ×2.2 | purple trail, glitter, gem burst |
| Frost Comet (frost_comet) | 5,000 | ×2.8 | long comet tail, snow, frost ring |
| Inferno Ball (inferno_ball) | 12,000 | ×3.5 | fire trail and flames, fire burst |
| Thunder Ball (thunder_ball) | 30,000 | ×4.5 | flickering trail, sparks, lightning zap at launch and landing |
| Galaxy Ball (galaxy_ball) | 75,000 | ×6 | colour-shifting trail, stardust |
| Dragonfire Ball (dragonfire_ball) | 180,000 | ×8 | twin flame trails, fire burst at launch and landing |
| Supernova Ball (supernova_ball) | 400,000 | ×10 | rainbow trail, stars, shockwave at launch, starburst where it lands |

The All-Star and Championship Balls were removed (their IDs were also cleared from the developer's save; other saves drop them on load).

- **Models:** `tools/blender/balls.py` builds all ten (radius 1, meshes named `<id>__<Part>`) and exports `assets/models/Balls.fbx`; run it headless with `blender --background --python tools/blender/balls.py`. After import they are split into one model per id in `ServerStorage.RunwayAssets.DisplayItems`.
- **Looks:** `BallStyles.luau` (ReplicatedStorage) colours each part by name and holds each ball's glow, flight effects, bursts and display idle particles. The physics ball keeps its locked `CustomPhysicalProperties`, so no look can change flight.
- **Display:** pedestals show the styled model with its glow and a few of its particles as a preview.
- **On the tee and in flight:** the server publishes the styled models to `ReplicatedStorage.BallModels`. Each client shows the batter's model (from the station ball's `EquipmentId`) on the physics ball, which is hidden locally, and `BallEffects` adds the trail, particles and glow once the ball visibly leaves the tee, with a burst at launch and at the first landing. Without a model the plain coloured ball is shown and the effects still play.
- **Trail colour:** ball and bat trails are drawn unlit with normal blending (`LightEmission` 0, `Brightness` 1.6). Additive light washed every trail to white against the bright sky and bloom, so trail colours are also kept saturated.
- **Layered effects (build up with price):** each flight has the coloured trail plus a thin white-hot additive core, a glow halo riding on the ball, cosmetic backspin on the model, theme particles (denser and larger for fancier balls), and a flash with a flat shockwave ring at launch and at the first landing (bigger for fancier balls). From the Bubblegum Ball up a sparkle ribbon is added. Bat swings layer the coloured sweep, a white-hot streak along the last half stud of the barrel, and from the Candy Cane Bat up a sparkle sweep. Tier is the item's place in its lineup (0 first to 1 last).

### Item displays

The World 1 hub has a physical **Ball Display** and **Bat Display** side by side at the back of the hub, behind the last Training Grounds (z 120, centred at x -36 and 36), facing the spawn down the walkway (`WorldConfig` `hub.displays`; built by `ItemDisplay.luau`). It is a white stepped stage with red trim and a backdrop wall, with the title ("BALLS" / "Earn more Cash per hit") above it. There is one pedestal per Ball in `EquipmentConfig` order, `perRow` (10) per row, sized so 10 Balls fit in one row about 67 studs wide (6.4-stud spacing, 2-stud items, compact labels); extra rows step back and up. Adding a Ball to the config adds a pedestal, and another category can get its own display with one more `displays` entry.

- **Item models:** each pedestal shows `ServerStorage.RunwayAssets.DisplayItems.<item id>` when that model exists, scaled to 2 studs and spun about its centre. Without one, it shows a placeholder ball in the item's `appearance` colour with two red seams. To show a designed ball, put its model in `DisplayItems` named by its item ID (for example `practice_ball`).
- **Labels (client):** a floating label per pedestal shows this player's status (EQUIPPED cyan, OWNED white, FOR SALE gold, LOCKED red), the name, the boost (×1.3 CASH) and the price (red when unaffordable). Items spin and bob locally (`ItemDisplayClient`).
- **Buying:** the pedestal's ProximityPrompt reads Buy, Equip, Equipped (disabled) or Locked. Triggering it sends the same `EquipmentUpgrade` request as the Equipment menu (Purchase with the server-issued offer token, or Equip), so the server validates everything and the menu's listener shows the result as a notification. Locked items explain why instead of sending a request.

## Equipment Progression

Equipment progression is based on distinct equipment rather than numeric equipment levels.

Players progress from one Bat or Ball to another piece of equipment with its own configuration and gameplay effects.

Equipment uses stable internal IDs and is server-authoritative.

Purchased/equipped equipment persists between sessions.

Equipment visual design, models, materials, and special effects are intentionally handled separately from gameplay progression. Gameplay milestones should not introduce new equipment cosmetics unless explicitly part of a dedicated visual-content milestone.

## Currency

The primary currency is Cash.

Players earn Cash from completed hits.

Rewards are influenced by:

- Hit distance
- Equipped Ball
- Field section

Cash and equipment progression are server-authoritative and persist between sessions.

## Field Sections

Each world contains one long continuous batting field extending away from its batting location.

The field is divided into progressively farther sections.

A baseball physically travels through these sections without teleportation.

Sections:

- Represent progression within a world
- Occupy different distance ranges
- May provide different reward multipliers
- Will eventually have distinct visual/environmental themes

Players do not purchase access to individual sections.

If a ball can physically reach a section, the player has reached that section.

Final section themes, environments, and visual presentation will be designed separately from the underlying progression system.

## Worlds

Worlds represent a larger layer of progression above field sections.

Each world contains:

Batting area → long field → multiple sections → end marker

The player progresses through a world by becoming powerful enough to hit farther down its field.

Reaching or passing the world's configured end distance with a legitimate hit completes that world and permanently unlocks the next world.

Worlds are not unlocked by simply purchasing them with Cash.

Example progression:

World 1
→ reach farther sections
→ reach World 1 end
→ unlock World 2
→ progress through World 2
→ eventually unlock World 3

Unlocked worlds remain available permanently and players may return to previously unlocked worlds.

## Progression Philosophy

Progression should be physically visible through batting performance.

A new player should hit relatively short distances.

As Level increases, the player should:

- Hit farther
- Reach new field sections
- Earn more Cash
- Purchase better equipment
- Eventually reach the end of the current world
- Unlock the next world

The beginning of the game should leave substantial visible room for future power growth.

Level 1 should produce a short hit far below the World 1 endpoint.

## UI Presentation (Check-UI redo)

The UI now follows the Check-UI skill (`.agents/skills/check-ui-clean-roblox/`) strictly. `UICommon` implements it behind the same API, so clients keep their gameplay wiring.

- **Windows:** a slightly see-through slate canvas (`#3B5866` at `UI.MenuBoxTransparency` 0.3, so the blurred world shows behind it; 4px corners, 3.5px `#181E22` outline) with a faint full-height checkerboard.
- **Titles:** each menu's icon and title (GothamBlack up to 46px, thick black outline, white fading to the theme tint) ride over the top edge of the box, half above it, with the close button on the top-right corner. A 6px themed gradient strip runs along the top of the box: Shop magenta, Rebirth purple, Worlds cyan, Training amber, Welcome Back blue, Inventory orange.
- **Close button:** the signature 38×38 beveled crimson close button.
- **Buttons:** follow the canonical iconless blueprint: sharp rectangle, 3px `#0C141A` border, vertical state gradient, black checkerboard fading 0.91 to 0.62, triple glass rims, and a 3px outlined label.
- **Button states:**
  - Claim (gold): available actions. The UI uses no green; positive feedback text is gold too.
  - Claimed (silver): equipped, selected, or disabled.
  - Locked (crimson): locked items and destructive actions such as Leave and Cancel.
  - Cyan: neutral buttons and the selected tab.
- **Motion and sound:** hover 1.05, press 0.94 with a Back.Out release, and a click sound.
- **Cards:** recessed (`#1A2C34`, black border, slate inner highlight). A cyan highlight marks the selected card; a crimson tint marks locked ones.
- **Badges:** beveled tiles.
- **Notifications:** solid panels with a themed top bar.
- **Scaling:** windows scale with the skill's responsive rule (1050×620 baseline, clamped 0.52 to 1.18) times `UI.MenuScale` (0.95), never below `UI.MenuMinScale` (0.75) so menus stay large and tappable on phones. The window is capped by the screen, so it never goes off-screen.
- **Rebirth:** follows the skill's Rebirth archetype: gold "Rebirth N ➡ Rebirth N+1" comparison cards (Power multiplier and Level Cap), an orange-to-gold Level progress bar, and a recessed requirements box, above the Reset/Keep/Gain cards.
- **Quick menu:** matches the reference 2×2 tile design (dark outline and bevel, textured sky-blue face, colored top accent bar, large icon, outlined label) with Shop, Rebirth, Inventory, and Rewards. Rewards is a placeholder that shows "coming soon". A wide **Training** tile sits under the grid, and a **Batting** button sits under the level bar (it replaced the Rebirth Available shortcut; Rebirth is still in the quick menu):
  - **Training** teleports the player to their best usable Training Ground (see below).
  - **Batting** uses the `TeeTeleport` remote, which takes no arguments. It places the player 7 studs behind the batter's box of their current world, facing it, so batting never starts by itself. It shows whenever the level bar does, and is refused during a hit or while already batting.

  Both teleports show no message on success, only an explanation when refused.
- **Level bar:** styled as a baseball: white, with progress filling it as bold red diagonal stripes (the bar's only red; no seams, stitching or progress line).
- **Batting tee:** each station is dressed with `ServerStorage.RunwayAssets.BattingTee`, from `tools/blender/batting_tee.py`, styled in FieldBuilder: a rubber home-plate base with a white plate top, a steel tube with an orange band, an adjustment collar with a knob, and a ribbed rubber tube and cup. The original Base, Stem and HomePlate stay as invisible colliders, and `Tee.Stem.BallPosition` remains the launch point; the cup lip sits exactly at it.

### Inventory

`InventoryClient` opens from the Inventory tile: an orange-themed Check-UI window with three tabs down the left side and a three-column card grid (two columns on narrow windows).
- **Bats / Balls:** every item in the category, with tier-colored borders and names (gray, blue, purple, gold by item order), its effect, and a state line (EQUIPPED, TAP TO EQUIP, or a lock icon with BUY IN THE SHOP). Tapping an owned item sends the existing `EquipmentUpgrade` "Equip" intent; the server validates it as before. Counters show "BATS 2 / 4" and the equipped item. The Bats and Balls tab icons are small 3D previews.
- **Juice:** owned and active juices, showing multiplier, effect, and duration, plus "x3 · TAP TO DRINK" and "1:57 LEFT". Tapping drinks one. With nothing owned, an empty-state message explains juice.
- Purchasing stays in the Shop.

### Juice (Schema 7)

Juice is a consumable item that grants a temporary, server-timed bonus. The architecture is in place, but no juices are defined yet.
- **Definitions:** `JuiceConfig.DEFINITIONS` entries `{id, displayName, effect, multiplier, durationSeconds, color}`, validated at load. `effect` is `Power` or `Cash`. IDs are persistent and must never be renamed or reused.
- **Storage:** inside the existing `PlayerProgression` save (Schema 7) as `OwnedJuices` (id → count, up to 999) and `ActiveJuices` (id → whole seconds left, capped at 24 hours). Older saves start with none. A malformed (non-table) field fails closed like other progression; unknown juices and invalid entries are dropped.
- **Server authority:** only `PlayerData` changes juice state.
  - `GrantJuice` is server-only (for future rewards, shop, or codes).
  - `UseJuice` runs on the client's `JuiceRequest` "Use" intent, with a 0.3s cooldown, in `JuiceServer`.
  - `GetJuiceMultiplier` returns the combined bonus for an effect.
  - Grants and uses schedule an important save.
- **Timing:** active juices count down once per second by real elapsed time, only while the player is in the game; timers pause offline.
- **Stacking:** drinking a juice that is already active adds its duration, up to the cap. Different juices with the same effect multiply.
- **Effects:**
  - Power juice multiplies online Power grants (active Training and real hits) inside the single grant path, so whole Power is still rounded once after all bonuses. It does not apply to offline Training.
  - Cash juice multiplies the hit's Cash reward.
  - Neither changes launch strength or distance.
- **Display:** clients read `OwnedJuices` and `ActiveJuices` folder attributes on the player. The HUD multiplier includes active Power juice. The Training rate preview does not yet.
- **Size:** `UI.SizeScale` (currently 0.75) shrinks the HUD groups, quick menu, notifications, and the Training status box, each around its own anchor (`UI.Shrink`). Windows use their own larger `UI.MenuScale` (see Scaling) and are capped at 680×550 before scaling. The quick menu never drops below 0.45, so phones stay readable and tappable. The HUD's bottom clearance for the Roblox hotbar and touch controls is not scaled.

### Training teleport

The quick menu's Training tile sends an intent-only `TrainingTeleport` request (a RemoteEvent the server creates at runtime). `BattingTimingServer`:
- refuses it during an active hit or while already training, with a message
- shares World Travel's 1-second cooldown
- places the player 9 studs from the World 1 Training plate, facing it, so Training starts only when they step on
- from another world, travels back to World 1 first, using the same `relocate` cleanup as World Travel (ends batting, Training, and active hits, and bumps the batting session)

Because World 2 has no hub, this tile is also how players return from World 2. Travel to World 2 uses the World Travel prompt in the World 1 hub.

### Earlier pass (Milestone 19B)

UICommon owns Check-UI presentation inspired by the four navigation tiles: rounded cyan faces, dark outlines, inset highlights, translucent navy shells, recessed state-colored cards, and outlined GothamBlack typography. Equipment uses a pink accent, Rebirth purple, Worlds cyan, Training gold, and Welcome Back blue. Shared controls have centered hover/press motion and menus have a brief opening pop. Existing client controllers and HubInterfaces still own the same gameplay intents. Only one hub modal is shown at a time; activity, travel, and character cleanup close menus and release the single local blur.

The HUD shows icon-based Cash/Rebirth counters, current world, and a blue studded Level/Power bar with Level Cap and Bat × Rebirth gain. Power fill changes tween locally. QuickMenu keeps its 2×2 tile design and opens Shop, Rebirth, Training (the Training Grounds selector), and Worlds (the World Travel menu) in every world; the unimplemented Inventory/Rewards stubs are retired. Equipment and Worlds use numbered badges rather than invented preview art. Equipment prices, ownership and action states remain separate and readable. Rebirth has a distinct confirmation view; Cancel sends no gameplay request. Short landscape screens compact the headers and confirmation content, and scrolling keeps actions accessible. Portrait cards stack their actions. Mobile modal actions use 52–54 logical pixel targets with a minimum 0.8 scale. Explicit Swing/Leave buttons invoke the existing Tool and server requests; click/Space still work. Touch movement and the hotbar are restored after menus/activities. No progression or reward calculation moved to the client.

Offline gains are already granted by the server. CONTINUE only dismisses the once-per-login presentation; the Power icon and rotating sunburst are cosmetic. Hit results separate distance, Cash and Power and expire after six seconds. Shared notifications replace the current notice and suppress immediate duplicates. Icons reuse already approved image references; the CheckUIIcons registry was not installed in this place. The Worlds globe is made from UI geometry. This presentation pass adds no new systems, monetization controls or environment changes.

## World 1 Runway Themes

World 1's open field is replaced by a 160-stud-wide runway (`WorldConfig` `runway.width`). World 2 keeps the original wide field; width is per-world through `Field.GetWidth(world)`, and the out-of-runway check uses it.

The runway is divided into ten themed sections. `FieldBuilder` builds the collidable ground; `RunwayDecor` builds all scenery from `WorldConfig`:

| # | ID | Name | Distance (studs) | Cash multiplier |
| --- | --- | --- | --- | --- |
| 1 | grass | Meadow Run | 0–300 | 1.00 |
| 2 | snow | Frost Pass | 300–800 | 1.15 |
| 3 | stone | Crystal Ridge | 800–1300 | 1.35 |
| 4 | desert | Golden Dunes | 1300–1800 | 1.35 |
| 5 | candy | Candy Crossing | 1800–2300 | 1.35 |
| 6 | jungle | Emerald Grove | 2300–2800 | 1.35 |
| 7 | lava | Ember Canyon | 2800–3300 | 1.35 |
| 8 | neon | Neon Circuit | 3300–3800 | 1.35 |
| 9 | sky | Skyway | 3800–4400 | 1.35 |
| 10 | cosmic | Starlight Finish | 4400–5000 | 1.35 |

The first three IDs and all reward thresholds are unchanged from the earlier Grass/Snow/Stone layout; sections 3–10 subdivide the former Stone tier without changing its 1.35× Cash multiplier. The World 1 endpoint (5000) and 2000-stud runout are unchanged.

Scenery (all cosmetic):

- **Floor:** each section's `material` sets the ground's look only. Ground physics stay fixed through an explicit `CustomPhysicalProperties`, so materials never change bounces or rolling. Optional per-section extras: `floorPattern` (a faint caustic texture), `floorGrid` (neon grid lines), and `floorCracks` (glowing lava cracks). Flush edge stripes line both sides, and a checkered band marks each section start.
- **Walls:** two-tone checkered walls (`wallHeight`, `wallThickness`, `wallTileLength`) with a rounded cream cap. `wallTileColor` can override the light tile color for dark themes.
- **Decks and props:** a raised deck behind each wall (`deckWidth`, `deckMaterial`) holds the section's `props`, cycling every `propSpacing` and staggered between sides. Props are scaled up by `propScale`, and small filler clusters by `fillerScale`. Disc-shaped props (lollipops, the rainbow) face back toward the tee.
- **Backdrop:** outer ground (`outerGroundWidth`) with large themed shapes (`backdrop`) every `backdropSpacing` for a horizon.
- **Section titles:** each section's name floats as text on a fully transparent, non-colliding anchor 40 studs up, facing the tee (Meadow Run's floats at 60 studs so it is not over the batter). There are no physical gates or signs. A checkered finish line and a floating "WORLD 1 FINISH" title mark the 5000-stud endpoint, and plain walls continue through the runout.
- **Mesh props:** props listed in `RunwayDecor`'s `MESH_PROPS` use imported Blender models from `ServerStorage.RunwayAssets`, tinted per section. These templates live in the place file, not Rojo/Git, so the place must be saved after importing. Generator scripts and FBX exports are in `tools/blender/` and `assets/models/`. If a template is missing, the prop falls back to its primitive-part version. Every runway prop, filler, and backdrop now has a mesh template (31 in total):
- `MeadowTree` (`tools/blender/meadow_tree.py`): Meadow and jungle trees, and the jungle canopy backdrop.
- Batch 1 (`batch1_props.py`, `RunwayBatch1.fbx`): `Mushroom`, `FlowerPatch`, `Fern`.
- Batch 2 (`batch2_props.py`, `RunwayBatch2.fbx`): fillers `Bush` and `Rock` (per-section `fillers` list, default both), plus Candy Crossing's `Lollipop`, `Cake`, `Gumdrops`, and `CandyCane`.
- Batch 3 (`batch3_props.py`, `RunwayBatch3.fbx`): `Pine`, `Snowman`, `Ice`, `Crystal`, `Geode`, `Cactus`, `Mesa`, `Dune`, `Spire`, `LavaRock`, `Beacon`, `Arch`, `Cloud`, `Rainbow`, `Island`, `Planet`, `Star`, `Moon`, and backdrops `Mountain`, `Volcano`, `Hill`.

Shared Blender helpers live in `tools/blender/prop_helpers.py`. Every model is authored under ~20 units so the import stays below Roblox's 2048-stud part limit; backdrops are scaled up through `BACKDROP_MESHES`. Mesh definitions can also set `materials` (Neon for glowing parts), `lift` (floating props), and `faceTee` (`true` allows a half turn; `"exact"` plus `yawOffset` keeps an authored front toward the tee).

Roblox imports these FBX files at 100× scale; templates are scaled back to their Blender size (1 unit = 1 stud) and pivoted at their base.

The runway has no floating distance labels or floor tick lines; the live HUD shows distance during a hit. World 2's open field keeps its original distance markers.

Every `RunwayDecor` part is anchored with collision, touch, and query disabled, so scenery cannot affect ball flight, measured distance, rewards, or camera occlusion. The full runway is about 3,000 decoration parts.

## Sky

`SkyServer` applies one stylized golden-hour sky to the whole game at server start:
- a late-afternoon sun about 34° up, behind and to the left of the batter, so it lights the runway but never sits in the camera's view of the ball (an earlier sun placed straight down the runway made the ball hard to see)
- warm pink and purple atmosphere, soft pink dynamic clouds, and gentle bloom and sun rays
- a light saturation boost

It reuses the place's existing Lighting effects rather than adding duplicates. All values are look-only and tunable at the top of the script. The sky does not change per section.

## Hit presentation

All cosmetic; none of it affects launch, distance or rewards.

- **Timing:** every effect starts when the client sees the ball leave the tee (the rendered ball 0.5 studs off its tee spot), not when `BallState` turns InFlight. The attribute arrives about 0.25 s before the ball's smoothed physics movement is drawn, so starting on it put the effects ahead of the ball.
- **Bat crack:** each client plays a local `BatCrack` Sound on the tee's Stem when any station's ball leaves the tee, so nearby players hear each other's hits in sync (Pro Sound Effects "Wood Bat Hits Hard Ball", `rbxassetid://9125380872`; `HIT_SOUND_ID` and `HIT_SOUND_VOLUME` in `HitCinematicClient`). It is on the tee rather than the ball so it does not fly away with the hit. Practice swings in Training are silent.
- **Cinematic swing and flight:** from the click that starts a real swing (BatClient fires "SwingStart" on the bat's local marker; Training practice swings do not), `HitCinematicClient` slides in black letterbox bars (11% of the screen each) and adds a light colour grade (contrast and saturation). They stay while the hit is active (`HitActive`) and ease out when it ends; a refused swing lets them slide back out after 1.2 s. The bars sit under the HUD, so the distance counter and 2x/Leave buttons stay on top. The Cash counter is hidden during flight.
- **Camera:** from the click, the batting camera (`BatTimingClient`) zooms from 55° to 46° FOV through the backswing (Load and Windup, 0.24 s) and holds. When the ball leaves the tee it widens from there to 70° over 0.8 s with a 0.35 s decaying shake. With no launch it eases back out.

## Hit time scale

Rolling made up most of each hit's time: at Level 20, about 2 s in the air and about 17 s rolling. Every hit now plays at one steady time scale from launch, `FieldConfig.HitTimeScale` (1.6): launch velocity ×s, gravity and rolling friction ×s², and the stop checks scaled to match. There is no change of speed during a hit.

This replaced a roll-only fast-forward (3× once the ball was rolling after its first landing). That kept distances but looked like the ball suddenly speeding up for a second or two after landing.

Roblox bounce and friction physics do not scale cleanly, so the time scale shortens distances: the ball loses more horizontal speed in its first bounces. Level 20 playtests (3 hits each):

| Mode | Time | Distance |
| --- | --- | --- |
| Normal speed (×1) | ≈ 19.6 s | ≈ 1,913 studs |
| Old roll fast-forward | ≈ 9.6 s | ≈ 2,060 studs |
| Steady ×1.3 | ≈ 14 s | ≈ 1,690 studs |
| Steady ×1.6 (current) | ≈ 9.2 s | ≈ 1,300 studs |

Distances feed Cash, sections and World progress. The developer chose ×1.6 for short, smooth hits; distances (sections, World endpoints, Cash) will be rebalanced in a later balancing pass.

## 2× Ball Flight (disabled)

**Currently disabled** via `FieldConfig.FlightSpeedUpEnabled = false`. While disabled, the server rejects every `SpeedUp` request, no `BallFlightSpeed` state is published, and the HUD hides the 2× button. The code path stays in place and tested for if it is fixed and re-enabled.

When enabled, the batter can press **2×** during their own hit to watch the ball travel at double speed, as a convenience.

- The client sends only the batting session and the `SpeedUp` action. The server checks that the hit belongs to the player, the session matches, the player is still batting and alive, and their data is ready.
- The server time-scales the ball: velocity and spin ×2, and an extra downward force so total gravity is ×4. Rolling resistance and the stop thresholds/timer are scaled to match. Launch speed, loft, and Level snapshot are unchanged.
- **One-way per hit.** Once 2× is on, it stays on until the hit finishes; further requests are rejected and the button shows ON (disabled). Every new hit starts at normal speed.
- **Known issue (unresolved): 2× changes final distance.** The airborne arc scales exactly (first landing matches normal hits), but bounces and rolling do not. The 0.8-stud ball moves more than its own diameter per physics step at impact, so bounce results depend on impact timing, and enabling 2× shifts that timing. Level 20 playtest results (normal ≈ 1,820–1,960 studs):
  - 2× enabled at launch: 1,734–1,763 studs, with occasional ~1,110-stud outliers.
  - 2× enabled 0.7 s into flight: ≈ 2,340–2,380 studs, repeatable (+25%).
  
  Because switch timing is player-controlled, 2× could be used to inflate distance, Cash, and World completion. One-way switching did not fix this, so the feature is disabled until bounce/roll behavior can be made timing-independent.
- `BallFlightSpeed` (1 or 2, nil when no hit is active) is replicated for the HUD only. Rewards, distance, and world completion still come from the server's measured final position, granted once.

## Equipment Roles and Save Migration (Milestone 18)

Active categories are Bat and Ball only. Schema 6 reuses PlayerProgression and removes OwnedTees/EquippedTee during load and save. Cash, Power, Levels, Rebirths, Bat/Ball ownership and selections, grounds, worlds, and valid offline metadata remain intact. Older schema rules still apply; no progression is wiped or converted into refunds.

PlayerData owns the Power grant pipeline. Active Training resolves the server-equipped Bat. Offline grants resolve the normalized saved Bat in the atomic login transaction. Real hits snapshot the Bat ID at acceptance and use it for their once-only reward: `floor(base hit Power * Bat multiplier * Rebirth multiplier)`. Equipment remains locked throughout Training and active hits. Clients send equipment intent, never bonuses or rewards.

Training rate previews use the same whole-Power arithmetic divided by the tick interval. HUD and Rebirth previews show the combined Bat/Rebirth multiplier. Ball Cash rewards and Level-based launch calculations are unchanged.

## Power, Level, and Rebirth (Milestone 15A)

`ProgressionConfig` owns the placeholder formulas. Schema 4 extends the existing
`PlayerProgression` store with Power, Level, Rebirths, and LevelCap. Older saves
receive 0 Power, Level 1, 0 Rebirths, and cap 10 without converting equipment.
Cash, ownership, equipped selections, worlds, and unknown saved fields are preserved.
Malformed new fields are repaired; LevelCap is derived, never trusted from a save.

- Power is progress toward the next Level. Requirement = `100 * Level^2`.
- Requirements are consumed on advancement; one grant can advance multiple Levels.
- At the cap, Power is zero and excess grants are discarded (no overflow bank).
- Level cap = `10 + 10 * Rebirths`; Power gain multiplier = `Rebirths + 1`.
- A valid finalized field hit grants base 2 Power, once, through server-only
  `PlayerData.GrantPower(player, baseAmount, source)`. Active training uses this API; offline grants use the same private grant path inside the atomic load transaction.
- Speed = `55 + 15 * (Level - 1)` studs/second, with fixed 38-degree loft.
  Level is snapshotted at swing acceptance; Power, Rebirths, Bat, and Ball
  do not modify launch speed. Physics still determines actual final distance.
- `PlayerData.CanRebirth(player)` checks eligibility. `TryRebirth(player)` also
  rejects active training/batting/hits, dead characters, and world travel, increments Rebirths, resets Level/Power, derives
  the new cap, revalidates the selected ground, and preserves all other progression.
  The confirmed Rebirth interface calls this server transaction. Technical safety limit: 1,000 Rebirths.
- Replicated progression attributes are HUD copies. Grants, launches, Rebirths,
  and saves read private server session state.

The historical `BattingTiming` Remote and script filenames remain for Rojo
compatibility, but no timing mechanics remain. The client sends only its batting
session (and optional `Exit`); the server sends final distance/reward feedback.
SwingConfig provides a single phase timeline: the named Contact marker is at 0.50 seconds in a 1.10-second swing (a 0.14 s Windup phase after Load coils the hands, barrel and torso a little further back before the stride plants). ContactTime and Duration drive the visual swing and existing server contact/cooldown; the client-local SwingMarkerReached event reports the marker without requesting a launch. The server launches `ContactTime - LaunchVisualLead (0.25 s) - the batter's ping` after accepting the swing (at least `MinimumLaunchDelay`, 0.1 s), because clients draw server-moved parts about 0.25 s late; the ball then visibly leaves the tee at the animation's contact (measured gap 0.02-0.05 s, down from about 0.3 s). Launch strength and direction are unchanged.
Natural stopping, sections, world endpoints, and Cash formulas are unchanged.

Milestone 15A added no training mechanics or Rebirth UI. Training is added below in Milestone 15B.
## Training and Offline Power (Milestone 15B)

Training is the primary Power source.

### Six physical Training Grounds (supersedes the single logical stadium)

Each Training Ground is its own batting cage, with its own plate and one occupant at a time. The six cages stand in two rows of three, parallel to the runway, either side of a walkway in World1Hub (right = right when facing down the runway), under `World1Hub.TrainingGrounds.<ground id>`.
- Right row: Basic Training, Enchanted Grove and Sunken Atlantis, with plates at hub-relative x 42. Left row: Sky Temple, Dragon's Lair and Cosmic Rift, at x -42. Both rows start at z 35 and step 33 studs back into the hub (the models' 44-stud spacing, narrowed with the cages); see `TrainingConfig.Rows`.
- The first ground of each row is nearest the runway. Cages are turned a quarter turn so their doors face the walkway and their machine ends point outward.
- The hub was shrunk to 210 × 136, and the spawn moved into the walkway, 60 studs behind the tee. The physical Shop, World Travel and Rebirth stations and the Training Grounds board are removed for now. Their settings are commented in `WorldConfig`; FieldBuilder deletes any unconfigured station left in the place.
- Shop, Travel, Rebirth, normal batting and world endpoints are unchanged.

| # | Ground ID | Unlock | Power multiplier (× 20 Power per 2 s) |
| --- | --- | --- | --- |
| 1 | basic_training | start | 1× |
| 2 | enchanted_grove | 2 Rebirths | 5× |
| 3 | sunken_atlantis | 4 Rebirths | 10× |
| 4 | sky_temple | 6 Rebirths | 20× |
| 5 | dragons_lair | 500 Robux game pass | 10× |
| 6 | cosmic_rift | 1000 Robux game pass | 30× |

**Access:**
- Walking onto a plate starts training only if the server's private Rebirths or pass ownership allow that ground.
- Otherwise the player gets the reason once per visit. On a paid ground, the server also re-checks ownership and shows Roblox's purchase prompt.
- Paid grounds need no Rebirths and are not lost on Rebirth.

**Game passes:**
- `gamePassId` stays 0 until the passes are created on Roblox. While it is 0, the ground shows "COMING SOON" and cannot be used or bought.
- Ownership is read with `UserOwnsGamePassAsync` at login (before the offline grant) and updated by the server's `PromptGamePassPurchaseFinished` event.
- Ownership is never saved and never taken from the client. A failed lookup grants nothing.

**Menu and teleport:**
- The Training Grounds menu lists every ground with its multiplier and effective rate.
- Each card shows GO (teleport beside that plate), BUY (asks the server for the pass prompt), or the Rebirths still needed.
- The QuickMenu Training tile teleports to the player's best usable ground.
- Each cage shows a per-player lock sign in its doorway.

### Batting cage (visual)

`TrainingStadium.luau` builds a batting cage around each plate (model `Cage`), dressed in that ground's `theme` on the server. Its footprint is `TrainingConfig.Cage`: modelled 30 × 48 × 14 studs in plate space, then narrowed in game to `widthScale` (0.75, `CAGE_WIDTH_SCALE` in TrainingConfig) across the cage, about the pitch line, so it is 22.5 studs wide. Parts are squeezed across the cage and moved toward the pitch line; spinning parts shrink evenly to stay round. Turf, walls, door, banners, decoration slots and particle zones use the same narrowed width. The batter faces +X, the machine is at −Z, and there is extra room behind the batter so the default camera stays inside. The door is in the batter-end net.

The mesh comes from `ServerStorage.RunwayAssets.TrainingCage` (Studio-managed, generated by `tools/blender/batting_cage.py` and exported at 1/4 scale, then scaled up 4×):
- steel hoops with padded posts, and strand netting on all sides and the roof
- a two-wheel pitching machine whose ball exit is the PitchOrigin
- a protective screen with a window on the pitch line
- home plate, a ball bucket and two floodlights

Parts built in code: the turf, pitch lane, batter's-box chalk, three banners and invisible walls that leave the door open. The walls have CanQuery off, so camera raycasts pass through. The plain plate is hidden under the turf but still defines training occupancy. If the template is missing, the cage builds without its mesh and warns.

Each ground's `theme` sets:
- `template`: the cage mesh in RunwayAssets
- colors by role: turf, lane, accent, frame, net, banner
- `lights`: the floodlights
- `decorations`: `{slot, template}` pairs cloned from RunwayAssets onto the named Attachments in `Cage.DecorSlots`. The slots are outside both long sides, behind both ends, and inside the cage away from the lane, door and camera.

The banners show the ground name. Themes never affect Power.

### Fantasy cages (grounds 2–6)

Each fantasy ground has its own Blender model, generated by its own script in `tools/blender/`. All scripts share `cage_helpers.py`, which holds the layout and export rules, and export to their own FBX in `assets/models/`:

| Ground | Script → FBX / template | Highlights |
| --- | --- | --- |
| Enchanted Grove | `grove_cage.py` → `GroveCage` | Living-wood arches, woven vine net with glowing strands, stepping stones, a tree-stump machine with a knot-hole, wicker screen, glowing mushrooms, a fairy-door tree, fireflies |
| Sunken Atlantis | `atlantis_cage.py` → `AtlantisCage` | Fluted marble arcade under a force-field bubble dome, mosaic lane, giant clam with a pearl, porthole screen, coral, swaying kelp, chest, trident, circling fish, bobbing jellyfish, bubbles |
| Sky Temple | `sky_temple_cage.py` → `SkyTempleCage` | Marble plinth and gold-banded columns, glowing gold lattice, sun inlay, winged golden statue, sunburst screen, cloud bank, bobbing islands with waterfalls and a shrine, spinning armillary rings, blue braziers, feathers |
| Dragon's Lair | `dragon_lair_cage.py` → `DragonLairCage` | Obsidian shard pillars with lava veins, gabled iron roof with spiked eaves, chain-link lattice and draped chains, lava cracks, dragon-head machine, portcullis, treasure hoards, a complete dragon skeleton sprawled over the roof (sculpted skull with glowing sockets over the entrance, spine and ribcage along the ridge, legs gripping the eaves, wing bones with tattered membrane, tail coiled round a hoard), torches, lava pools, embers |
| Cosmic Rift | `cosmic_rift_cage.py` → `CosmicRiftCage` | Chrome hex hoops with star nodes, force-field shell with constellations, spinning galaxy floor, portal machine with a swirling core, holographic screen, black hole with accretion disc, the rift tear, ringed planet, orbiting planets, asteroids, crystals, nebulae, shooting stars |

All five keep the standard layout:
- the plate at the origin
- the ball exit at PitchOffset
- the screen window on the pitch line
- the door in the batter-end wall
- nothing past the 14-stud gaps to the neighbouring cages

Every model is exported at 1/4 scale and imported into `ServerStorage.RunwayAssets` under its template name. `TrainingCageStyles` (server) gives every MeshPart its color, material, transparency and glow light by name, because FBX imports carry no colors. It also sets the `Spin`, `Bob`, `Sway` and `Pulse` motion attributes and lists each cage's particle effects, which use built-in Roblox particle textures. `TrainingStadiumClient` animates those attributes on each client, relative to the server-built CFrame.

The Atlantis dome and Cosmic field are tinted glass, so the view through them reads as underwater or deep space. A style `tint` (Dragon's Lair) sets Tint* attributes on the cage, and the client blends a ColorCorrectionEffect in while its camera is inside that cage.

A ground whose fantasy template is not imported falls back to the standard cage in its theme colors, with a warning. Banners hang between frames so every design leaves room for them. A larger invisible block keeps players out of the bigger machines.

Walk onto an unlocked ground's 5-by-5 plate to train automatically. Leave training
before shopping or rebirthing. Space/touch Leave restores movement and requires
stepping off before re-entry. Death, respawn, disconnect, invalid data/character,
and travel release the plate. Normal batting and active-hit state exclude training.

The server grants a configured tick through PlayerData.GrantPower: `floor(ground base Power * equipped Bat multiplier * Rebirth multiplier)`. Level advancement and cap overflow rules remain unchanged.
Ticks do not catch up in bursts after server stalls. At the cap, no Power grant
calls are made. Client-local pitches and the reused Bat swing are presentation
only: no real ball launch, Cash, distance, sections, or world completion occurs.

Schema 5 added SelectedTrainingGround and LastLogoutTime to PlayerProgression.
Schema 8 retires SelectedTrainingGround: grounds are physical, so nothing is
selected or saved, and the field is dropped on load and save. Existing profiles keep Cash, Power, Level,
Rebirths, equipment, juices and worlds. Old schemas and missing, zero, malformed, or
future timestamps grant no historical offline Power.

Offline base Power = floor(min(elapsed seconds, 8 hours) * best usable ground's
base Power / interval * 0.25). The best usable ground is the highest-rate ground the player can use from Rebirths and owned passes, checked at login. The same server grant path multiplies that base by the saved, ownership-validated Bat multiplier and Rebirth multiplier, floors the result to whole Power, and applies cap rules. These are placeholder balance values. Offline earning does not
require leaving while actively training.

The login UpdateAsync commits the reward, consumes LastLogoutTime, and claims the
session atomically. A lost-response retry recognizes its own session and does not
grant again. There is no client offline-claim operation. Normal exit records the
server close time; autosaves record a checkpoint time for crash recovery. No
extra periodic DataStore writes are added. A crash before the first autosave after
login conservatively has no new offline timestamp to use.

TrainingRequest accepts only Buy(id), which shows the pass prompt, or Exit(session). TrainingTeleport accepts an
optional ground id; anything the player cannot use falls back to their best ground. No remote starts
training or accepts rates, Power, ownership, timestamps, duration, or Rebirths. The HUD shows
training state/rate alongside existing Power/Level values. Offline notifications
are shown once per client session for absences covering at least 60 seconds,
including capped sessions with no further Power gain.
## Confirmed Rebirth and Swing Presentation (Milestone 16)

The plain Rebirth interaction is at hub-relative (-35, 0, 120), currently near
(-52.2, 1.62, 98.8), separated from training, batting, and World Travel. The menu
shows current/next multiplier and cap, eligibility, and exact reset/keep/gain
consequences. Rebirth then Confirm are separate actions; Cancel/close/death/travel
clear confirmation. The quick menu Rebirth tile provides access in every world.

RebirthRequest accepts intent only, with no arguments. The server checks session,
private cap eligibility, alive character, active gameplay/travel, per-player
cooldown, and processing state. TryRebirth commits Level, Power, Rebirths, derived
cap without yielding. Cash, equipment and
worlds are preserved. Completion schedules an important save through the existing
serialized autosave loop (normally within its next five-second check). A save
already in flight cannot clear a later Rebirth's pending save. The existing store/session leases remain unchanged.

Ground access updates from Rebirths, game passes and TrainingConfig immediately. Training
Ground rates and all level/world balance remain placeholders.
Rebirth multiplies Power, never Cash or same-Level launch speed. The HUD shows a
Power progress bar, multiplier, aggregated level changes, and capped/Rebirth state.
Offline feedback includes the best usable ground, credited time, Power, and resulting
level range/cap without adding a new claim request.

The R15 swing remains a local procedural pose using existing bat geometry and hand
IK. A short load precedes hip rotation, torso/shoulder rotation, accelerating bat
contact, extension, follow-through, and recovery. Legs shift weight and the neck
counter-rotates. Smooth keyframe curves stagger the hips, chest, hands, and barrel;
foot IK plants the lead side and pivots the rear foot about its toe. The absolute shared timeline avoids chained-wait drift. Training
uses the same swing/contact time but its server Power ticks remain independent.
Unsupported or failed presentation cannot disable valid server swing requests.
Exit/reset/destruction restore original joints/grip and remove temporary IK state.
No third-party animation assets or new cosmetic models are used.
## Server Authority

Important progression and gameplay state must remain server-authoritative.

This includes:

- Cash
- Equipment
- Purchases
- Hit results
- Distance
- Rewards
- Section results
- World completion
- World unlocks
- Persistent player data

The client primarily handles:

- Input
- UI
- Camera
- Animations
- Local visual/audio feedback

## Visual Development

Gameplay systems should be developed and validated before major visual polish.

Environment themes, equipment appearances, Ball effects, UI styling, and other cosmetic work should be handled in dedicated visual milestones rather than being added piecemeal during gameplay-system development.
