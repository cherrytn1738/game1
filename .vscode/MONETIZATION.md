# Monetization

Everything the game sells for Robux, where its ids live, and how the server grants it. The
server owns every grant; the client only opens Roblox's purchase prompts and shows what the
server confirms.

## What is sold

| Item | Kind | Price | Effect | Config |
|---|---|---|---|---|
| +10K Power | Developer product | 11 Robux | +10,000 Power | `MonetizationConfig.PowerProducts` |
| +100K Power | Developer product | 45 Robux | +100,000 Power | `MonetizationConfig.PowerProducts` |
| +1M Power | Developer product | 95 Robux | +1,000,000 Power | `MonetizationConfig.PowerProducts` |
| Auto Bat | Game pass | 25 Robux | Bats automatically at the plate, ON/OFF | `MonetizationConfig.AutoBat` |
| Cosmic Rift (+ Time Machine Lab, Quantum Lab) | Game pass | 500 Robux | Training Grounds | `TrainingConfig` (`gamePassId`) |
| Dragon's Lair | Game pass | 1000 Robux | Training Ground in every World: 15x / 45x / 150x / 500x in Worlds 1-4 | `TrainingConfig` (`gamePassId`, `worldMultipliers`) |
| Welcome Back 3x | Developer product | not priced yet | Offline reward x3, up to the rest of the run | `TrainingConfig.OfflineTriple` (`productId`, `robuxPrice`) |
| Starter Pack | Game pass (once) | 39 Robux | +10K Power, +1 Rebirth, 1 Power Punch, Catastrophe Bat | `MonetizationConfig.StarterPack` |
| Tiny / Small / Medium / Large Cash Pack | Developer product | 25 / 59 / 115 / 229 Robux | Cash worth 15 / 50 / 125 / 300 normal hits | `MonetizationConfig.CashProducts` |
| Boost Bundle | Developer product | 95 Robux | 2 Power Punch + 2 Cash Splash | `MonetizationConfig.JuiceProducts` |
| Power Punch / Cash Splash | Developer product | 39 Robux each | 1 juice (into the Inventory) | `MonetizationConfig.JuiceProducts` |
| Power multiplier tiers 1-5 | Developer product per tier | 129 / 169 / 219 / 279 / 359 Robux | Permanent Power 2x / 2.5x / 3x / 3.5x / 4x | `MonetizationConfig.Multipliers.Power` |
| Cash multiplier tiers 1-7 | Developer product per tier | 129 / 159 / 199 / 249 / 309 / 389 / 489 Robux | Permanent Cash 2x / 2.5x / 3x / 3.5x / 4x / 4.5x / 5x | `MonetizationConfig.Multipliers.Cash` |

Nothing else is sold. Prices in config are only what the buttons show until Roblox's live price
loads (`GetProductInfo`); Roblox charges the price set on the Creator Dashboard.

## Setting it up (Creator Dashboard)

1. Create three developer products (Power 10K / 100K / 1M, priced 11 / 45 / 95) and paste each id
   into `developerProductId` in `src/replicated/MonetizationConfig.luau`.
2. Create the Auto Bat game pass (25 Robux) and paste its id into `AutoBat.gamePassId`.
3. Create the Starter Pack game pass (39 Robux) and paste its id into `StarterPack.gamePassId`.
4. Create seven developer products: the four Cash Packs (25 / 59 / 115 / 229) into
   `CashProducts`, and the Boost Bundle (95), Power Punch (39) and Cash Splash (39) into
   `JuiceProducts`.
5. (Already pending: the Training Ground passes in `TrainingConfig`, Cosmic Rift's at 500 and
   Dragon's Lair's at 1000, and the Welcome Back 3x product's `productId` and `robuxPrice`.)
6. Create twelve multiplier developer products, one per tier: Power tiers 1-5 (129 / 169 / 219 /
   279 / 359) and Cash tiers 1-7 (129 / 159 / 199 / 249 / 309 / 389 / 489), and paste each id into
   its tier's `developerProductId` in `MonetizationConfig.Multipliers` (in tier order; a tier
   whose id is 0 shows SOON when it is the next one).
7. Create the ten gift developer products below and paste each id into its `developerProductId`
   in `MonetizationConfig.GiftProducts`. A gifted Training Ground is NOT Roblox game pass
   ownership: the gift product buys the recipient a saved in-game entitlement that opens the same
   grounds.

| Gift product | Robux | `GiftProducts` id | Current id | Shop item |
|---|---|---|---|---|
| Gift: Starter Pack | 39 | `GiftStarterPack` | 0 | Starter Pack |
| Gift: Tiny Cash Pack | 25 | `GiftCashTiny` | 0 | Tiny Cash Pack |
| Gift: Small Cash Pack | 59 | `GiftCashSmall` | 0 | Small Cash Pack |
| Gift: Medium Cash Pack | 115 | `GiftCashMedium` | 0 | Medium Cash Pack |
| Gift: Large Cash Pack | 229 | `GiftCashLarge` | 0 | Large Cash Pack |
| Gift: Boost Bundle | 95 | `GiftBoostBundle` | 0 | Boost Bundle |
| Gift: Power Punch | 39 | `GiftPowerPunch` | 0 | Power Punch |
| Gift: Cash Splash | 39 | `GiftCashSplash` | 0 | Cash Splash |
| Gift: Premium Training Ground | 500 | `GiftPremiumTraining` | 0 | Cosmic Rift / Time Machine Lab / Quantum Lab (one shared entitlement) |
| Gift: Dragon's Lair | 1000 | `GiftDragonsLair` | 0 | Dragon's Lair |

## Gifts

Every Shop item has a square Gift button (a present) beside its Robux button; it stays available
when you own the item yourself. It opens a picker over the Shop listing the other players in this
server (headshot, display name, @username; never yourself; "NO OTHER PLAYERS IN THIS SERVER" when
alone), then a confirmation ("Gift Power Punch to Josh?", the price, GIFT / CANCEL; ALREADY OWNED
for a permanent item they have). While a gift's id is 0 the button is grey with SOON and refuses
(in Studio the picker still opens, to try the layout).
- **Before the prompt** (`PlayerData.PrepareGift`): the client sends only the gift id and the
  recipient's UserId. The server checks the buyer, that the recipient is another loaded player in
  this server, the item, its id, and that the recipient doesn't already have a permanent item
  (Starter Pack: owned or granted; a ground: its pass or a gifted entitlement). A Cash pack's
  amount is fixed from the RECIPIENT's Level, World and Bat. The intent (recipient, their save
  location, the amount) is saved in the buyer's `PendingGifts` before the buyer's prompt opens; a
  second gift of the same product waits until the first purchase is delivered, and a cancelled
  prompt drops its intent.
- **The receipt** (`PlayerData.ClaimGift`, through `ProductServer`): the gift is queued on the
  recipient's own record (`GiftInbox`, an UpdateAsync that adds only that entry, keyed by the
  receipt's `PurchaseId`), whether they are here, offline or in another server. Only then is the
  buyer's receipt recorded (RobuxSpent) and `PurchaseGranted` returned. No saved intent, or a
  failed write, returns `NotProcessedYet` for Roblox to retry.
- **Delivery** (`applyGiftEntries`): straight away if the recipient is here, at their next login,
  or after an autosave on another server finds it. Each gift id joins `ReceivedGifts` in the same
  save as its reward, so retries, crashes and rejoins never apply it twice.
- **What arrives:** Cash packs pay the fixed amount; juices go to the Inventory (not started); the
  Starter Pack uses the same grant as the pass (its bonus Rebirth still never completes the
  tutorial); a ground adds its entitlement to `GiftedEntitlements` (`premium_training` = Cosmic
  Rift's pass, `dragons_lair`). The server counts an entitlement as owning that pass, so every
  ground check, the offline best ground and every OWNED label treat both alike.
- **Notices:** the buyer sees "GIFT SENT! POWER PUNCH → JOSH"; the recipient "GIFT FROM JOSH!
  POWER PUNCH +1" (also when it was queued while they were away). Names are the server's.

## The Shop

The HUD's Shop tile opens it (`ShopClient`): ~ PACK ~, ~ MULTIPLIERS ~, ~ CASH PACKS ~,
~ BOOSTS ~ and ~ TRAINING GROUNDS ~ in one scrolling window (the game's only shop menu; Bats and
Balls are bought for Cash only at the hub display pedestals).
- **Starter Pack:** owned at login (also bought elsewhere) or bought in game (the server's
  `PromptGamePassPurchaseFinished`), its rewards are given once ever, in this order, then saved at
  once: the Catastrophe Bat, one Power Punch, a bonus Rebirth (Rebirths and the Level Cap rise; it
  resets nothing, and banked Power then levels up), and 10,000 Power through the normal Level path.
  The saved `StarterPackGranted` (Schema 11) is set first, so repeated events, logins or rejoins
  never give it again. Its bonus Rebirth is not the tutorial's Rebirth: only the player's own
  Rebirth (`TryRebirth`, reason "ManualRebirth") completes the tutorial. In Studio only,
  `StudioOwnStarterPack` on a `StudioFreshSave` save owns it.
- **Multipliers:** two cards, Power and Cash, each showing its next tier as the change it makes
  ("2x → 2.5x", "TIER 2 OF 5 • PERMANENT", that tier's price), and MAX / MAXED once every tier
  is owned. See "Purchased multipliers" below. No Gift button (not giftable for now).
- **Cash Packs:** a Buy asks the server ("BuyCash"), which fixes the pack's reward first
  (`PlayerData.QuoteCashPack`: `hits` x the Cash of one normal hit for the player then, from
  `MonetizationConfig.GetCashPackReward`: their Level's usual hit distance, at most their current
  World's end, that section, their equipped Bat and purchased Cash multiplier; no juice) and only
  then opens Roblox's prompt. A gifted pack uses the recipient's Cash multiplier.
  The quote is saved with the player (`CashPackQuotes`, Schema 11), so the receipt, a retry, a
  delayed receipt or one after a rejoin all pay that amount; the next Buy of that pack replaces it.
  A receipt with no quote (bought some other way) pays the amount at processing time. The card
  shows the same formula from the replicated Level, World and Bat.
- **Juices:** added to `OwnedJuices` (capped at 999 each), never started.
- **Training Grounds:** Dragon's Lair always, plus the premium ground in the player's World (Cosmic
  Rift, Time Machine Lab, Quantum Lab or Snow Globe: the one shared Cosmic Rift pass), bought
  through the existing TrainingRequest "Buy" (the server checks the pass and opens the prompt).
  OWNED from the server's `TrainingPass_<id>` attributes (true for the pass or a gifted
  entitlement). Dragon's Lair's card shows its multiplier in the player's World (15x / 45x / 150x /
  500x, `Training.GetMultiplier`): a little above that World's premium ground (10x / 35x / 120x /
  400x), never above its best Rebirth ground. The cards are rebuilt when the World changes.
- **Ground pictures:** a card shows the ground's screenshot when its `TrainingConfig` `shopImage`
  is set (cropped to fill), otherwise a 3D preview of its own cage. The server publishes clean
  copies of the paid grounds' cages to `ReplicatedStorage.TrainingGroundModels` at start
  (streaming keeps other Worlds' cages off a client). The preview stands the copy on a platform in
  the card's colours, over an opaque gradient backdrop (purple for the premium grounds, orange
  for Dragon's Lair). It uses low ambient and a strong key light, and frames the whole cage with
  padding, centred, mostly side-on from the door side and the batter's end. The camera sways
  slowly while the Shop is open. Neon and particles don't glow in a ViewportFrame, which is what
  the screenshots fix. A copied MeshPart only draws once its mesh has loaded, so the Shop preloads
  `TrainingGroundModels` and rebuilds the ground cards when the meshes arrive.

While an id is 0 its button shows the price in blue with a SOON sticker on the card, never opens
a prompt, and a tap says it is coming soon.

### Shop look
A dark Showcase window (UICommon's Grey theme, with the shared menu blur) holding bold colour
cards (`UI.ColorCard`: a palette gradient, a faint stud pattern, a lighter inner rim and the thick
dark outline). Each section opens with a full-width hero card for its best item, then smaller
cards in columns:
- **Heroes:** the Starter Pack (rainbow), the Large Cash Pack (green) and the Boost Bundle (pink),
  each with its picture over a slowly turning sunburst, and Dragon's Lair (orange) ahead of the
  World's premium ground (purple). Grounds are both full width, since their pictures are wide.
  Multipliers have no hero: Power (gold) and Cash (teal) sit side by side as equals.
- **Small cards:** the Tiny / Small / Medium Cash Packs in three columns, Power Punch (crimson) and
  Cash Splash (blue) in two. Phones held upright get one column and stacked heroes.
- **Contents:** packs list what they hold as white tiles (`UI.ItemTile`: icon and "+10K", "x2").
- **Purchase row:** a lime price button with the Robux icon (`UI.PriceButton`) and a square purple
  Gift button (`UI.GiftButton`) where gifting applies.
- **States:** cards keep their colour. SOON is a blue price button and a blue sticker, owned is a
  gold OWNED button and a green sticker, and a full multiplier reads MAXED in gold
  (`UI.CardBadge`).
- **Real comparisons only:** the Boost Bundle's crossed-out price (`UI.StrikePrice`) and SAVE n%
  come from the same juices bought one at a time (live prices once loaded). BEST VALUE marks the
  Cash Pack with the most hits per Robux. The Starter Pack has no crossed-out price: its Rebirth
  and Bat are not sold on their own.

### Shop images
Every card can show an uploaded picture instead of its built-in one (icons and 3D models). Leave
a field empty to keep the built-in picture.
- **Items** (`MonetizationConfig`): `StarterPack.shopImage`, each Cash Pack's and juice product's
  `shopImage`, and `MultiplierShopImages.Power` / `.Cash`. Use a **512 x 512 PNG with a
  transparent background**: the item alone, centred, filling about 90% of the square, and no text.
  The card tilts it a little and lets it overlap the card's top edge.
- **Training Grounds** (`TrainingConfig` `shopImage`): a 1100 x 500 screenshot, below.

Worth making first: the Starter Pack (the Catastrophe Bat with a juice box and a Power bolt), the
Large Cash Pack (a big pile of Cash), the Boost Bundle (both juice boxes together) and the five
ground screenshots. Then the Power and Cash multipliers (a glowing bolt and a Cash stack with a
"x" badge drawn as part of the art), the Tiny / Small / Medium Cash Packs (bigger piles each) and
the two juices.

### Training Ground Shop images
All five use the same framing, so the cards match. `tools/studio/ground_shop_shot.luau` sets the
camera to the 3D preview's view of a ground.

1. **Prepare Studio.** Bring Studio to the front with a wide window (any shape works; wider is
   better). Use solo Play with no other players, and close every menu.
2. **Frame the ground.** In the command bar (Client context), set `GROUND` and run the script. It
   hides the HUD, Roblox's own UI and your character, and frames the cage from the preview's angle
   to fit a centred 2.2:1 crop.
3. **Take the screenshot.** Wait a second for the particles and glow to settle, then take a
   screenshot of the viewport (for example Win+Shift+S).
4. **Crop it** to the centred 2.2:1 area and resize it to **1100 x 500 PNG**.
   - The cage fills the middle; keep it centred and don't add text.
   - Every image is the same size: the card's picture window is always 2.2:1 (beside the name on
     wide screens, across the top on phones held upright).
5. **Restore.** Run the script with `RESTORE = true`, then repeat for the next ground:
   `cosmic_rift`, `time_machine_lab`, `quantum_lab`, `snow_globe`, `dragons_lair`.
6. **Upload.** Upload each PNG as an image: Studio's Asset Manager > Import, or the Creator
   Dashboard's Decals. Copy the **image** asset id. A decal id shows nothing in an ImageLabel;
   Asset Manager's "Copy ID" gives the image id.
7. **Set the ids.** Put each id in `TrainingConfig` as `shopImage = "rbxassetid://<id>"`, then
   playtest and open the Shop in each World.

Claude can take, crop and upload all five through Studio MCP while Studio is in the foreground.

## Power purchases

- Three buttons in a row under the Level bar, as wide as it, with the Batting button below them
  (`MonetizationClient`; children of the HUD's Progression frame, so they show and hide with it:
  hidden while batting, a hit is in flight or a menu is open). Each has its own face (yellow
  +10K, red +100K, rainbow +1M), a big outlined amount with the Power bolt leaning out behind it,
  and the price in green with the Robux icon in the bottom-right corner (SOON while the id is 0).
- The receipt goes to `ProductServer`, the game's one `ProcessReceipt` handler. It finds the
  product from the receipt's `ProductId` in its own config and calls
  `PlayerData.ClaimPowerProduct(player, receipt, powerAmount)`.
- The Power is added exactly as listed: no Ball, Rebirth, juice or purchased multiplier. It goes through
  `Progression.Advance`, like every other grant, so Level-ups, the Level Cap (Power banks there
  until a Rebirth; no Rebirth ever happens by itself), the tutorial's Power step and saving all
  follow. It works while Training, batting or in a menu.
- The client is then told (`Monetization` RemoteEvent, "PowerGranted") and shows "+10K POWER".

## Purchased multipliers

- **Tiers:** two permanent ladders (`MonetizationConfig.Multipliers`), each tier its own
  developer product, bought in order. The saved tier count (`PowerMultiplierTier`,
  `CashMultiplierTier`; Schema 12, 0 for older saves) picks the multiplier: 1x with none,
  then 2x, 2.5x, ... (+0.5x a tier: Power to 4x, Cash to 5x). Kept through Rebirths. Balance in `.vscode/ECONOMY.md` ("Purchased
  multipliers"): one tier of each finishes the game ~49% faster, every tier ~76% faster,
  intentionally stronger than the spender targets because a World 4 is planned.
- **Buying:** the card's Buy sends only ("BuyMultiplier", "Power" or "Cash"). `ProductServer`
  looks up the player's next tier itself (`PlayerData.GetNextMultiplierTier`) and prompts that
  tier's product; nothing happens at the top tier, while its id is 0, within 0.5 s of another
  Buy, or while a prompt of that kind is still on its way (until Roblox reports it cancelled, the
  receipt is granted, or 60 s pass).
- **The receipt** (`PlayerData.ClaimMultiplier`): the product id gives the kind and tier from the
  server's config. The count becomes `max(owned + 1, that tier)`, capped at the ladder, so a late
  or repeated purchase still adds a tier and none is lost; it is saved straight away, then
  `PurchaseGranted`. The client is told ("MultiplierGranted", kind, tier count) and shows
  "POWER MULTIPLIER 1.6x!".
- **Where they apply:** Power multiplies Training, real-hit and offline Power (and the Welcome
  Back 3x), never the +10K / +100K / +1M products or the Starter Pack's Power. Cash multiplies
  batting Cash and a Cash pack's "normal hit". Both stack with juices (juices never apply
  offline); a hit snapshots both when its swing is accepted. They never change launch strength,
  distance, the Level Cap or World unlocks. The HUD's "× Multiplier" and the Training rate
  previews include the Power tier.
- **Studio:** on a `StudioFreshSave` save, the Workspace attributes `StudioPowerTier` /
  `StudioCashTier` start the player with that many tiers (to test the cards and multipliers
  before the products exist).

## Receipts and duplicates

- `ProcessReceipt` answers `NotProcessedYet` when the buyer isn't in this server or their data
  isn't ready; Roblox retries later (for example at their next join).
- Each granted receipt's `PurchaseId` joins `RobuxPurchases.Receipts` (the 50 most recent, saved
  with the player's data; the same list RobuxSpent uses). A receipt already in it is answered
  `PurchaseGranted` without granting again, in the same session or after a rejoin.
- After a grant the player is saved straight away, then Roblox is told `PurchaseGranted`.
- The same path serves the Welcome Back 3x (`PlayerData.ClaimOfflineTriple`), the Shop's
  developer products (`PlayerData.ClaimProduct`: Power, Cash packs and juices) and the multiplier
  tiers (`PlayerData.ClaimMultiplier`).

## Auto Bat

- **Ownership:** Roblox's record is the source of truth (`UserOwnsGamePassAsync` at login, and
  `PromptGamePassPurchaseFinished` on the server for an in-game purchase, which unlocks it straight
  away). It is never saved. A failed lookup grants nothing; a pass bought on the website counts
  from the next join. `AutoBatOwned` is the display copy.
- **ON/OFF:** the top-centre button, with a bat leaning across its left edge. Not owned: red,
  "AUTO BAT / ONLY [Robux icon] 25" in green, which opens the pass prompt (just SOON while the id
  is 0). Owned: grey OFF / green ON. The client asks (`Monetization` RemoteEvent, "AutoBat", on);
  `ProductServer` sets `AutoBatEnabled` only for owners (requests within 0.3 s are ignored). It
  starts OFF every session.
- **Batting:** the Bat's client (`BatClient`) presses Swing for the player through the same request
  as a click, only when a click would be accepted and the last hit has settled
  (`MonetizationConfig.ShouldAutoSwing`: at the plate, no hit in play, the ball back on the tee,
  past the swing cooldown, no cinematic or travel, 1 s after the hit ended or batting started). The
  server checks every swing exactly as before, so Auto Bat cannot overlap hits, skip flight, change
  rewards or occupy a station. It does nothing while Training. Leaving, death, travel and
  respawning end batting, which stops it; it resumes when the player steps back in while it is ON.
- **Placement:** at the very top centre, with the HUD's flight distance just under it (on phones
  a little left of centre, clear of the counters); under the tutorial banner while the tutorial
  shows.
- Icons (`UI.Icons.Robux`, `UI.Icons.Bat`) are free Creator Store images ("Robux Icon White",
  "Baseball bat icon").

## Studio testing

- Workspace attribute `StudioOwnAutoBat` (Studio only) owns Auto Bat for playtests.
- Power purchases can't be prompted until their ids exist; the tests grant them through
  `PlayerData.ClaimPowerProduct` with simulated receipts (`tests/Equipment.spec.luau`). Use
  `StudioFreshSave` for any live check, so the real save and the Robux Spent board aren't touched.
