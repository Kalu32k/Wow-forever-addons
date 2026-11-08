# WoW Forever addons

## ProfessionProfit

Lists the **most profitable things you can craft** with the recipes your character has
actually learned, based on prices from **Forever Guide**'s auction house scan.

### Installation
1. Copy the `ProfessionProfit` folder to `World of Warcraft/<client>/Interface/AddOns/`.
2. Start the game. If the addon shows as "out of date", tick *Load out of date AddOns*.

### Usage
1. **Open each profession window once** (Tailoring, Alchemy, ...). The addon then saves
   which recipes the character knows. Do it again when you learn new recipes.
2. **Scan the AH with Forever Guide** as usual.
3. Type **`/pp`** to show the list, sorted by highest profit first.
   Hover a row to see reagents and costs. Shift-click to search for the item on the AH
   (or link it in chat).

Profit = AH price × amount made per craft × 0.95 (the AH's 5 % cut) − reagent cost.
Reagents are costed at the cheaper of the AH price and the vendor price. The addon learns
vendor prices by itself when you open a vendor (e.g. thread and vials).
Recipes where a reagent has no price, and items with no AH price (soulbound), are not shown.

### Commands
| Command | What it does |
|---|---|
| `/pp` | Show/hide the list |
| `/pp min 1g50s` | Only show recipes with at least this much profit |
| `/pp status` | Shows whether Forever Guide's prices were found and which recipes are saved |
| `/pp fgdump` | Troubleshooting: shows what Forever Guide's data looks like |
| `/pp reset` | Forget saved recipes for the character |

### How the Forever Guide connection works
Forever Guide has no documented API for other addons, so ProfessionProfit finds it by
itself. First it looks for a price function, e.g. `GetAuctionPrice(itemID)`. Otherwise it
looks for the table where Forever Guide stores its scanned prices (`[itemID] = price`),
preferring the table for your realm and faction.
All AH prices come **only from Forever Guide**. No other AH addons are used.

If `/pp status` says no prices were found even though you have scanned:
run `/pp fgdump`, do `/reload` and send the contents under `fgdump` in
`WTF/Account/<account>/SavedVariables/ProfessionProfit.lua`. The connection can then be
adapted exactly to Forever Guide.

## RollTracker

Shows **what everyone in the group picked – Need, Greed or Pass** (and Disenchant/Transmog
if the game has them) on every item that drops. Works **with and without ElvUI**.

### Installation
Copy the `RollTracker` folder to `Interface/AddOns/`.

### What you see
- **A window** that opens by itself when something is up for rolling. It lists each drop
  with who picked what, roll numbers, who won and who **has not picked yet**.
  Names are shown in class colors. The window can be moved and resized.
- **A row of counts above the roll frame itself**, e.g. `Need: 1  Greed: 2  Pass: 1  Waiting: 1`.
  Hover the row to see the names. This works on both Blizzard's roll frames and ElvUI's.

With ElvUI, ElvUI's look is used (frame, font, buttons). Without ElvUI, regular Blizzard
frames are used.

### How it works
The game writes every choice in loot chat ("X has selected Greed for: [item]").
RollTracker reads those lines using the game's own localized texts, so it works in every
language and regardless of which UI shows the roll frames.

### Commands
| Command | What it does |
|---|---|
| `/rt` | Show/hide the window |
| `/rt auto` | Toggle opening the window automatically on rolls |
| `/rt clear` | Clear the history |
