# The reward shop

Night Operation's other pages are [the run](night-operation.md), [the challenges](challenges.md) and [the
previews](night-operation-previews.md). How the shop's rows, screen and wallet work is in
[internals/night-operation-shop.md](internals/night-operation-shop.md).

A run of yours that goes from its countdown to a success or a time up gives you points: 1 for each 25 of its final score
at the normal level, times the level's percent at the others (50 % at easy, 150 % at hard, 200 % at nightmare), rounded
down. The score counts up to the highest its level allows, so a run gives at most 20 points at easy, 42 at normal, 83 at
hard and 129 at nightmare. A normal run with a score of about 730 gives 29, a hard one 43. Your game adds them to your
own points and shows `Night Operation: +29 points, 41 in all.` A success where a monster never came (its spawn failed)
or nothing was killed pays for its kills only, without the bonus for the time left. A solo run counts too; a challenge
gives none. A failed or aborted run gives nothing, and a guest whose game missed the countdown gets nothing either. Each
game credits only its own player: no line between the two games carries points. If the points cannot be written, a
notice says so and `UE4SS.log` says why.

The shop sells seven items. `coop nightop shop` opens them in the game's own shop screen (below), and
`coop nightop buy` sells them from the console, the way the shop worked before the screen.

| # | Item | Points (Beta Seeds) | At a camp |
| --- | --- | --- | --- |
| 1 | `HP_Potion` | 15 | 400 gold |
| 2 | `HP_Potion_Small` | 10 | 300 gold |
| 3 | `PulseGrenade` | 6 | 300 gold |
| 4 | `ConcussionGrenade` | 8 | 400 gold |
| 5 | `HP2Burst_Potion` (Burst Stimpack) | 20 | not sold |
| 6 | `Buff_HP2MP` (Beta Stimpack) | 16 | not sold |
| 7 | `Bullet_Shock` (Shock Bolt) | 5 a bolt | not sold |

Items 1 to 4 and their prices come from the cut mode's own shop table, `Shop_NightOperation`. It lists 12 items; these
four are the ones every camp shop sells with no story condition, so a buy here skips no story gate.

Items 5 to 7 are cut items. The game ships their effects, use conditions, icons and English text, but no ItemTable
row, so it cannot hold them. Their prices are the mod's own starting values.

- The Burst Stimpack takes 400 HP and fills the Burst gauge by 600. The game's use conditions refuse it when EVE has
  too little HP or a full Burst gauge.
- The Beta Stimpack takes 20% of EVE's maximum HP and gives 50 Beta energy, refused the same way with too little HP or
  full Beta energy.
- The Shock Bolt is ammo for EVE's gun. A hit stuns a common enemy for 10 s, or until it is hit again, with the game's
  own stun effect, which does nothing to animals, elites or bosses. EVE carries 30 bolts at most; each shot takes one,
  and the next shot waits 1.5 s. The game adds bolts only up to 30 and drops the rest, and the shop cannot read how
  many she holds, so a buy past 30 costs the points of the dropped bolts.

The two stimpacks play the health potion's drinking animation and have a charge count of 2 that no upgrade raises, like
the Heal Grenade. The native part adds the rows of all three through the game's own AddRow, in memory for the game
run: the stimpacks' (two ItemTable rows, the Beta Stimpack's ItemConsumableTable row and the skill both play, which the
game names but never shipped) in the same batch as the [cut Lion's](cut-enemies.md#cut-boss-coop-lion) rows, and the Shock
Bolt's (its item, skill, projectile and hit result) in a batch of their own, so a Shock Bolt row the game refuses
leaves the Lion and the stimpacks alone. A buy of item 5, 6 or 7 asks for its rows first. When they are already in, the
buy goes through at once. Otherwise the answer is `OK: Buff_HP2MP x1: its rows are asked of the native part; the buy
follows once they are in`, and the buy's own answer follows within 30 s, as an `OK:` or `STOP:` line of `coop lion`.
Rows that cannot be added buy nothing and take no points: `STOP: Buff_HP2MP cannot be added to the game (...): nothing
bought, no points taken`, with the reason in the parentheses.

For the Shock Bolt the rows are not enough: EVE's two gun stances list only its failed shot, and the game's ammo list
stops at five types. Right after the Shock Bolt's rows go in, the native part adds the two fire commands the game
ships to both stances and `Bullet_Shock` as a sixth ammo type, in place (see [Cut ammo: Shock Bolt](#cut-ammo-shock-bolt)).
Only the shop does this, through a Shock Bolt buy or `coop nightop shop`: a stimpack buy, `coop lion` and
`coop chainspin` leave the gun as the game ships it. A buy of item 7 goes through only when `coop-status.txt` then
reads `shock=in`. Otherwise it stops with
`STOP: Bullet_Shock cannot be fired in this game (shock=...): nothing bought, no points taken`, and the shop screen
leaves the Shock Bolt out.

The rows of these items went in during the 2026-10-27 game run and the shop screen opened, but no item has been
bought, used or fired in game yet. Check that the items show with their names and icons, that using a stimpack
plays the animation and changes HP and the gauge, that the Shock Bolt shows in the ammo selector, fires and stuns, and
what happens to a cut item left in the inventory when the game saves: after a restart the rows are not in until the next
buy of that item or the next `coop nightop shop` (or `coop lion rows` for the stimpacks), and how the game loads an
item it has no row for is not known. Use them up or
keep a backup of the co-op save. If the Shock Bolt is selected, switch to another ammo before you save or quit from the
menu; the game's autosaves at a camp or a zone change keep the selected slot too.

## The shop screen (`coop nightop shop`)

`coop nightop shop` opens the game's own shop screen, the one its vending machines use, with the items of the table
above. It shows each item's icon, price, Available and Stored counts, and its Purchase button buys through the game's
own purchase. While the screen is open your points are Beta Seeds, the cut mode's currency: the top of the screen
shows how many you hold, every price is in Beta Seeds (one seed for one point), and a purchase takes them out of the
inventory. The screen also caps a purchase as the game's vending machines do: at most what your seeds pay for, what
the item's carry limit leaves (30 Shock Bolts) and 99.

What the command does, in order:

1. It checks the co-op save, your Steam ID, that no run is on and that the game plays (no pause, no menu screen).
2. It asks the native part for three rows batches at once, through `coop lion`'s flow (their `[LI]` lines start with
   `lion`, `bolt` and `shop`): the stimpacks' (the lion rows batch), the Shock Bolt's (which also grows EVE's gun
   lists, as a Shock Bolt buy does) and the shop's own 6 rows. The shop's go last because they have not been added in
   game yet: a fault in the game's AddRow stops every batch that is not in yet until the game restarts, and a batch
   already in stays usable. The shop's rows and the stimpacks' have to go in, since both shops list the stimpacks.
   Without the Shock Bolt's, the screen leaves the Shock Bolt out.
3. It reads EVE again and stops if her map changed while the rows were asked. Then it puts as many Beta Seeds in the
   inventory as your wallet holds (seeds left over from a crash are taken out first), waits until the native part
   counts them, and asks it to open the screen. The Shock Bolt is on sale only when its rows are in and
   `coop-status.txt` reads `shock=in`. Until the screen opens, each step first checks that the co-op save the wallet
   belongs to is still the one loaded.
4. While the screen is open, each change of the seed count is written to your wallet at once.
5. When you close the screen, the wallet keeps what is left and the seeds leave the inventory.

Beta Seeds are in the inventory from step 3 until they leave after the close. A save made in that time, an autosave
included, holds them. So does a save made after a removal that failed: the log then says that the next
`coop nightop shop` takes them, and that screen sets the count back to the wallet. A game restarted from such a save
loads Beta Seeds before the shop's rows are in, and how the game loads an item it has no row for is not known (as for
the cut items above), so keep a backup of the co-op save. Each step logs a `[StellarCoop][NR]` line in `UE4SS.log`:

```
[StellarCoop][NR] shop: 41 points; its rows asked
[StellarCoop][NR] shop: rows in (Shock Bolt in)
[StellarCoop][NR] shop: wallet 41, the bucket held 0 Beta Seeds: +41
[StellarCoop][NR] shop: SB's shop screen open with 41 Beta Seeds, the Shock Bolt sold
[StellarCoop][NR] shop: 26 Beta Seeds, wallet written
[StellarCoop][NR] shop: closed: 26 Beta Seeds back in the wallet; 26 Beta Seeds left the inventory
```

The command answers at once with
`OK: Night Operation shop: 41 points as Beta Seeds; SB's shop screen opens once its rows are in ([NR] lines)`. It
answers with one `STOP:` line and opens nothing when the save is not a co-op save, the Steam link has no Steam ID yet,
a run is on, the game is paused or shows one of its screens, the screen is already open, `coop-status.txt` has no
`nightshop` line (an older DLL) or reads a fault there, or the wallet holds more than 999999 points.

Once the seeds are counted, a pause or one of the game's screens (the pause menu that Escape opens when it closes the
console, for example) holds the open: it goes on when the game plays again, for up to 30 s.

If a later step fails (the shop's or the stimpacks' rows refused, EVE's map changed while they were asked, the seeds not
counted within 5 s, the game still paused or on one of its screens 30 s after they are, the game not opening the
screen), the seeds leave the inventory, the wallet stays as it was, the log has a `STOP: shop:` line with the reason,
and a notice says `The Night Operation shop could not open. UE4SS.log says why.` A shop screen the game already had open
stays open.

When another save was loaded before the open (or a load still reads no save), the mod stops in the same way but adds no
seeds, asks no open and removes nothing: seeds it already added stay with the co-op save, and the next
`coop nightop shop` there takes them.

- After a fault in the native part's shop calls, the mod can no longer read or close the screen: the seeds it counted
  last leave the inventory, so a screen left open sells nothing more, and you close it yourself. A fault while the game
  sets the new screen up leaves that screen open without its goods in the same way.
- While the screen runs, no run starts, a guest turns down the host's run, and `coop nightop buy` refuses.
- `coop off` closes it first, writes the last seed count to the wallet and takes the seeds out (before the screen
  opened, the seeds the mod added); a purchase made in the last 250 ms before `coop off` is not counted. In the 250 ms
  or so between the open request and its answer, `coop off` closes whatever shop screen is up, a vending machine's
  included.
- After a Lua reload while the screen is open, the mod takes it over at its first tick, so purchases still reach the
  wallet and the seeds leave after the close. Seeds still in the inventory with no shop screen open leave at that first
  tick, and the wallet keeps its count.

The rows are a sixth rows batch of the native part, `shop` (`native/src/lion/rows.h`), added through the game's own
AddRow in memory for the game run, as the Lion's are:

| Table | Row | ID | Copy of |
| --- | --- | --- | --- |
| ItemTable | `Money_NightOperation` (Beta Seed) | 9011 | `FishingPoint`, Clyde's currency |
| ShopItemTable | `NightOperation_HP2Burst_Potion_Buy`, 20 seeds | 3571 | `NightOperation_HP_Potion_Buy` |
| ShopItemTable | `NightOperation_Buff_HP2MP_Buy`, 16 seeds | 3572 | `NightOperation_HP_Potion_Buy` |
| ShopItemTable | `NightOperation_Bullet_Shock_Buy`, 5 seeds | 3573 | `NightOperation_Bullet_Scatter_Buy` |
| ShopTable | `Shop_NightOperation_Coop` | 1061 | `Shop_NightOperation` |
| ShopTable | `Shop_NightOperation_CoopBolt` | 1062 | `Shop_NightOperation` |

The Beta Seed keeps the name, function and lore text the game ships for it ("Beta Seed", "Used for trading with
Roxanne") and uses BetaCore's icon, since no seed icon ships. The two shops have the Beta Seed as their currency and no
shop tag; the first lists items 1 to 6 (the shipped rows of items 1 to 4 and the two new stimpack rows), the second the
same and the Shock Bolt. No shipped row changes. A purchase takes Beta Seeds, which none of the game's achievement
rows names, in a shop with no tag. The gold-spending trophy needs gold spent in a shop tagged `AllShop`, so a purchase
here cannot move it.

Check in game: the screen opens with the seed count at the top and the items with their icons and prices; a purchase
takes the seeds, adds the item and writes the wallet; the screen stops the Shock Bolt at 30; the seeds are gone from
the inventory after the close; whether the screen takes the game's input and keeps EVE still with no vending machine
behind it; a save made while it is open and loaded again gives the same count.

## Buying from the console (`coop nightop buy`)

`coop nightop buy` with no number lists your points and the seven items:

```
OK: Night Operation shop, 41 points: 1 HP_Potion 15, 2 HP_Potion_Small 10, 3 PulseGrenade 6, 4 ConcussionGrenade 8, 5 HP2Burst_Potion 20, 6 Buff_HP2MP 16, 7 Bullet_Shock 5. coop nightop buy <n> [count] buys up to 10.
```

`coop nightop buy <n> [count]` buys 1 to 10 of item n, 1 when the count is left out. The answer reads
`OK: bought 2 HP_Potion for 30 points; 11 left`. The game's own request for adding an item puts it in the inventory
of the co-op save, with the game's pickup message. The buy takes no points and answers with one `STOP:` line when:

- the save is not a co-op save, or the Steam link has not given the mod your Steam ID yet;
- the item number or the count is not a whole number in range, or a word follows them;
- a run is on, or the shop screen is open;
- the game is paused or shows one of its screens;
- EVE or the player controller is not in the world, or EVE's GUID reads 0;
- you have too few points, for example `STOP: HP_Potion x1 needs 15 points; you have 11`;
- for items 5 and 6, their rows cannot be added, or `coop lion` is busy with another command;
- the game's request raises an error.

The points go once the game's request has returned. If the game turns the item down without an error, the points
are gone all the same, so check the inventory after a buy. The first potion or grenade a save gets can open the game's
guide for it, as a buy at a camp does. In the game's tables, none of items 1 to 4 feeds a Steam achievement.

Your points are kept per Steam ID and co-op slot, in `coop-night-<steamid>-<index>.txt` in the mod folder, one line
with the number. The game never reads that file, so restoring a save backup does not give points back or take them
away. `coop off` leaves the file as it is, an install never removes it, and `tools/install.py --uninstall` backs it up
with the mod's other files. While the file cannot be opened (another program holds it, or access is denied), a run's
points are not credited and `coop nightop shop` and `buy` refuse with `wallet not read:`, so the total in the file stays
as it is.

## Night Operation at Roxanne's

On a co-op save, Roxanne in Xion's Scrap Market offers Night Operation in her dialogue. Talk to her as usual: above
her Shop and End Conversation choices, the list shows Night Operation (Easy), Night Operation (Normal), Night Operation
(Hard) and Night Operation supplies, in the game's language. The game ships no such dialogue. Her graph's one dormant
Night Operation branch only greets a customer who paid her in Beta Seeds, and nothing reaches it. So the mod lends her
four of the game's test choice rows, which no story dialogue lists.

- A level: she says one of her goodbyes and the run is booked, with the notice
  `Night Operation starts once you leave Xion and no one is within 40 m.` A run never starts in Xion, so it starts on
  its own once EVE is out of Xion, the game plays and no one is within 40 m, as `coop nightop start <level>` would
  (the mod tries every 5 s, through that command's own checks). `coop nightop stop` drops the booking. In a Steam
  session only the host's pick books a run; a guest's pick shows `In a co-op session, only the host starts Night
  Operation.` The host's start asks the guest to join, and the booking holds until the guest's answer. When the guest
  cannot join (another map, more than 50 m away, a game screen up), the host gets a notice with the reason and the
  mod asks again 30 s later, until the run counts down or `coop nightop stop` drops the booking.
- Night Operation supplies: she says goodbye, and 5 s later the shop screen opens, as with `coop nightop shop`.
- Shop and End Conversation work as before, and the cancel input still ends the talk.

Nightmare is not in her list: the choice box has six slots, and her own two choices take two of them.
`coop nightop start nightmare` starts it.

Once EVE is in Xion on a co-op save, the mod reads the game's language, edits the rows in place (each checked first,
then read back: InteractionGraphExec `Success2`, the one her End Conversation uses, NextTaskTagName `None`, and
DisplayText the label in that language, or in English for a language the game does not ship), then asks the native part
to point her choice list in the game's select cache at the four rows and her two (`roxanne on`). The labels take the
game's language each time the rows are armed: at the next Lua load (game start or Ctrl+R), or when her choices come back
after `coop off` or after a save that is not a co-op save. Going to the title and loading a co-op save keeps the labels.

A pick is read from the game's choice boxes, looked for every 250 ms so a box the game builds for a later talk is read
too: a selected line turning from none to one, and that line's text matched against the labels.

Everything goes back on `coop off` and on a save that is not a co-op save: the choice list first (asked again every 10 s
until the native part has put it back), then the rows' shipped values. Until the list is back, and after a fault in its
calls, the rows keep the goodbye, which ends the talk on any save. A map load, leaving Xion included, reads no save for
a while: a booking and her choices hold through it. The supplies' shop screen waits up to 30 s for the game to play
(while it is paused or loading), then the pick goes. The title screen and another co-op save drop the booking and the
supplies pick. Nothing is saved, and a game restart undoes it too.

Talking to her still runs her own graph, so her first meeting and her side quest start as without the mod. No quest,
item, achievement or save call is added.

`UE4SS.log` has `[StellarCoop][NR]` lines for each step, for example:

```
[StellarCoop][NR] roxanne text: game language fr-FR -> fr; the 4 rows get its labels
[StellarCoop][NR] roxanne: 4 rows read back as ours; asked the native part: roxanne on
[StellarCoop][NR] roxanne: hard booked: it starts once EVE is out of Xion with no one within 40 m
[StellarCoop][NR] roxanne: the booked hard run waits: census: 1 living within 40 m (nearest 23.4 m); 0 wave bodies: go where no one is within 40 m
[StellarCoop][NR] roxanne: the booked hard run: Night Operation (hard) starts in 5 s (run 0x2A)
[StellarCoop][NR] roxanne off (coop off): asked the native part: roxanne off; the 4 rows go back once her list reads off
[StellarCoop][NR] roxanne: her two choices back, the 4 rows shipped
```

A step that fails logs a `STOP: roxanne` line and leaves her two choices as the game ships them until the next Lua load
(the rows it wrote are put back, also when a label does not read back, and nothing is asked of the native part). After
a Ctrl+R while her list still holds the six choices, a step that fails leaves the rows as they are instead, since they
only play her goodbye; `coop off` or a save that is not a co-op save puts them back.
`coop-status.txt`'s `roxanne=` line is described in
[Status lines](#status-lines).

Check in game: the six choices in this order, End Conversation last, the four labels in the game's language; each level
books its run and the run starts out of Xion; the supplies open the shop screen after her goodbye; Shop and End
Conversation as before; `coop off` gives her two choices back.

## Cut ammo: Shock Bolt

The game's files hold a third ammo for EVE's gun that was cut before release, the Shock Bolt. A hit stuns a common enemy
for 10 s, or until it is hit again (the game's own stun effect, `ShockSlugStun`, which does nothing to animals, elites
and bosses). Its fire commands, steps, consumable, projectile blueprint and stun ship, but it has no item, skill,
projectile or hit result row, EVE's gun stances list only its failed shot, and the ammo selector stops at five types.

The reward shop sells it as item 7, 5 points a bolt: `coop nightop buy 7 10`, or
on the shop screen of `coop nightop shop`. The buy (or the screen) gets the Shock Bolt's 4 rows in first, a batch of
their own (`bolt rows`), apart from the
[cut Lion's rows](cut-enemies.md#cut-boss-coop-lion). In the same frame as the last of the 4, the native part adds the two fire
commands the game ships (`P_Eve_Gun_ShootShockSlug1_1` and `_1_2`) to EVE's gun stances and `Bullet_Shock` as a sixth
entry of the game's ammo list, without replacing a row (see [internals/night-operation-shop.md](internals/night-operation-shop.md#the-cut-shock-bolt)).
The buy goes through only when that worked, and the screen sells the Shock Bolt only then. Nothing else adds these
rows or the sixth slot: `coop lion`, `coop chainspin` and the stimpack buys leave EVE's gun as the game ships it.

- EVE carries 30 bolts at most. A shot takes one, and the next shot waits 1.5 s. The game adds bolts only up to 30
  and drops the rest, and the shop cannot read how many she holds, so the points of dropped bolts are not given back.
  Check her count before a buy.
- Aim to get the fire commands. If she was aiming when they went in, aim again.
- The ammo selector builds its list when the HUD starts. If the Shock Bolt does not show there, load a save and look
  again (when the HUD starts again is not known).
- The slot stays for the game run, with or without bolts. With none, the trigger should play the failed shot, as with
  the other ammo types.
- Every save keeps the bolts and the selected slot, the game's autosaves at a camp or a zone change included. After a
  restart the Shock Bolt's rows and the sixth slot are not in until the next Shock Bolt buy or `coop nightop shop`, so
  the save loads into a
  game without them, with the mod installed as without it. The readers of the selected slot found so far check it
  against their list's length, so slot 6 should read as no ammo, but the code that restores the slot from the save was
  not traced, and how the game loads bolts it has no row for is not known. Keep a backup of the co-op save, and switch
  to another ammo before you save or quit from the menu (which saves).
- Only your game has it. What your friend sees of a shot in a session is untested.

`coop-status.txt` has a `bolt=` line for the 4 rows, in the same forms as the `lion=` line (`bolt=rows added=4/4 ...`
once they are in), and a `shock=` line for the two lists: `shock=off` before, then
`shock=in commands=24,24 added=4 list=6 slots=6` (both stances' command counts, the commands added, the ammo list's and
the slot manager's entries; `slots=-` when the slot manager did not exist yet), or
`shock=refused why=<word> at=<where>`, with nothing written unless `why=alloc` (see the table below).

The log lines, in `UE4SS.log` (the shop's `[StellarCoop][NR]` lines) unless marked:

| Line | What it answers |
| --- | --- |
| `bolt rows: 4/4 added through SB's AddRow 0x1441815b0, 0 refused` (`coop-link.log`) | The native part added the 4 rows |
| `bolt rows by SB's lookups: CharacterTable - 0/0, SkillTable 1003401 1/1, stance - 0/0` (`coop-link.log`) | The game's own lookup by ID finds the Shock Bolt's skill |
| `[StellarCoop][LI] bolt rows read back through FindRow: 4/4 authored rows, 87 fields as written (22 differ from the template row)` | Every field the native part wrote reads as written |
| `bolt rows refused <row>: <why>; <n>/4 added` (`coop-link.log`) | A row the native part would not add, and why. The buy stops with no points taken, and the Lion's rows are not touched |
| `shock bolt in: 4 fire commands added (P_Eve_Gun 24 commands, P_Eve_GunBlockSword 24), BulletItemSlotArray grown, 6 entries, the slot manager's list grown, 6 entries` (`coop-link.log`) | Both stances and both ammo lists grew |
| `shock bolt refused at <where>: <why>; nothing written` (`coop-link.log`) | A check failed before any write: a stance row missing or with another ID, a list out of range, or an ammo list that is not the five the game ships |
| `shock bolt refused at <where>: SB's allocator gave nothing; the writes before it stay` (`coop-link.log`) | The game's allocator gave no memory partway through the writes (`why=alloc`). What went in before it stays: the fire commands appended, and the ammo list's sixth entry when `<where>` is `slots`. The shop sells no Shock Bolt |
| `shock bolt off: fault 0x... in ... reading 0x...; the rows stay, no Shock Bolt until the game restarts` (`coop-link.log`) | A fault in the native step. The rows and everything else keep running |
| `buy Bullet_Shock x10: the gun cannot fire it (shock=...); no points taken` | A buy refused because the `shock=` line does not say `in` |

None of it has been tried in game yet. Check that the Shock Bolt shows in the ammo selector with its icon and count,
that EVE fires it and the count drops, that a hit stuns a common enemy and not an elite, and that the game keeps running
normally after you switch ammo.

## Status lines

`coop nightop shop` and Roxanne's choices are described in
[The shop screen (`coop nightop shop`)](#the-shop-screen-coop-nightop-shop) and
[Night Operation at Roxanne's](#night-operation-at-roxannes). Both run on a co-op save only. The native part
reports them in `coop-status.txt`:

- `shop=`, the shop's rows batch, in the same forms as the `lion=` line (see [Cut boss](cut-enemies.md#cut-boss-coop-lion)):
  `shop=off` before an ask, `shop=rows added=6/6 asks=1 spawns=? char=0/0 skills=0/0 stance=0/0` once the 6 rows are
  in.
- `nightshop=`, the shop screen: `nightshop=off` before the first ask, then
  `nightshop=<open|closed|?> seeds=<n|?> asks=<a> last=<ask>:<why>`, where `open` means a shop screen is open (any,
  the game's own too), `seeds` is the inventory's Beta Seeds (`?` while unread: no player data yet, or the game's logic
  busy that moment), `asks` the requests handled so far and `last` the last one (`open`, `open_bolt`, `close` or
  `watch`) with why it did nothing (`none` when it did): `client` or `manager` (no game client or UI manager yet),
  `flow` or `phase` (not in game, or not playing), `open` (a shop screen is already open), `game` or `logic` (the
  game's open gave nothing), `closed` (nothing to close), `name` (no FName). `nightshop=fault asks=<a> where=<where>`
  after a fault in its calls.
- `roxanne=`, her choice list: `roxanne=<unread|absent|on|off|other> asks=<a> want=<on|off> why=<word>`. `on` is the
  list of six, `off` her own two, `other` a list the mod does not know and never touches, `absent` no list of hers in
  the game's cache, `unread` the cache not read yet. `why` is `none`, or why the last request did nothing: `unread`,
  `absent`, `other`, `name`, `alloc` (the game's allocator gave nothing), or `busy`, `net` and `gate` (the rows' gate
  stayed shut for 300 frames: the game's logic busy, a net mode other than 0, or its globals unread).
  `roxanne=fault asks=<a> where=<where>` after a fault.

The native part's own lines, in `coop-link.log`:

| Line | What it answers |
| --- | --- |
| `shop rows: 6/6 added through SB's AddRow 0x1441815b0, 0 refused` | The shop's 6 rows are in |
| `nightshop watch: the shop screen and the Beta Seeds read every 250 ms` | The reads started (the screen's first request) |
| `nightshop open_bolt: SB's shop screen opened on Shop_NightOperation_CoopBolt` | The game opened its shop screen on the shop that sells the Shock Bolt (`open` and `Shop_NightOperation_Coop` without it) |
| `nightshop open refused: phase` | The screen did not open: the game was not playing (the other words as in the `nightshop=` line) |
| `nightshop fault 0x... in ... reading 0x...: no Night Operation shop screen until the game restarts (coop nightop buy still works)` | A fault in the screen's calls. Everything else keeps running |
| `roxanne on: her list reads on` | Her choice list now holds the six rows |
| `roxanne off: her list reads off` | Her two choices are back |
| `roxanne on refused: other, her list reads other` | Her list was not the two rows the mod knows, so it changed nothing |
| `roxanne fault 0x... in ... reading 0x...: Roxanne's choices stay as they are until the game restarts` | A fault in the list's calls |
