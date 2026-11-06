# Night Operation's shop: how it works

## The Night Operation shop screen

`coop nightop shop` (`nightop/shop.lua`) sells the shop's seven items in the game's own shop screen, the vending
machine's. Three parts make it work: a rows batch with the currency and the shops, a native opener, and Lua that keeps
the wallet file the record of the points.

### Its rows

The cut `Shop_NightOperation` (ShopTable 1060) ships with 12 ShopItemTable rows priced in `Money_NightOperation`, the
Beta Seed, whose name, function and lore keys ship in ItemStringTable but whose ItemTable row does not. Without that
row the screen shows no price and the bucket cannot hold a seed. The sixth batch of `lion/rows.h` (`kShopRecipe`,
request word `shop`) adds six near copies through the same build as the other batches, with ShopTable (row struct
`0xa8` bytes) and ShopItemTable (`0xa0`) as the eighteenth and nineteenth tables every rows request names:

| Row | Table | ID | Copy of | Changed |
| --- | --- | --- | --- | --- |
| `Money_NightOperation` | ItemTable | 9011 | `FishingPoint` | the seed's own text keys `Item_Money_NightOperation_*`, no drop pool, BetaCore's icon (no seed icon ships) |
| `NightOperation_HP2Burst_Potion_Buy` | ShopItemTable | 3571 | `NightOperation_HP_Potion_Buy` | sells `HP2Burst_Potion` for 20 seeds |
| `NightOperation_Buff_HP2MP_Buy` | ShopItemTable | 3572 | `NightOperation_HP_Potion_Buy` | sells `Buff_HP2MP` for 16 seeds |
| `NightOperation_Bullet_Shock_Buy` | ShopItemTable | 3573 | `NightOperation_Bullet_Scatter_Buy` | sells `Bullet_Shock` for 5 seeds |
| `Shop_NightOperation_Coop` | ShopTable | 1061 | `Shop_NightOperation` | currency `Money_NightOperation`, no tag, items 1 to 6 |
| `Shop_NightOperation_CoopBolt` | ShopTable | 1062 | `Shop_NightOperation` | the same, and the Shock Bolt |

The generator refuses a shop item priced in anything but Beta Seeds, with a second price, a gate (achievement,
condition, condition group) or a linked item, a shop with a tag or a discount, and any name or currency that resolves
to no row. Items 1 to 4 are the shipped rows with no gate, so no story gate is skipped. Lua opens a screen only once
the stimpacks' item rows (in the lion rows batch) are in, since both shops list them, and sells the Shock Bolt only
from the second shop, which it opens once `shock=in`. So every item a screen lists has its row, and a bolt the gun
cannot fire never shows. What the screen does with a shop item whose item row is missing is not checked.

Lua asks for the lion and bolt rows batches before the shop's. The worker takes one request a pass, so the lion rows,
which have gone in through AddRow in game, usually land first. The rows of every batch share one SEH latch: a fault in
the shop rows' AddRow turns every batch that is not in yet to fault until the game restarts. A latch for each batch
would not contain that fault, because the lion, bolt and shop batches all write ItemTable, and a fault inside an
ItemTable AddRow leaves that table in an unknown state for each of them.

### The opener

`nightop/shop_ui.h` (free of Windows, tested on the build machine) and `glue/tick/nightop_game.inc` make the calls the
vending machine's interaction node makes (`SBInteractionNode_ShopUI`, its execute `FUN_141b89c80`), on the game thread
under their own SEH latch. The UI manager is the client's `+0x48` (client global `0x147032520`, read directly and never
through its getter, which allocates). An open needs the client in game (flow `+0xa00` 2) and playing (phase `+0xb9c`
`0xe`) and no shop screen open (`FUN_141fc51d0` with the shop logic's type `0xab`); then `FUN_141fc4aa0` opens the
screen (manager, type, no child list, no parent, 0, an empty FString, 0) and the shop logic (the entry's `+0x60`) takes
the shop alias, the instance alias (the same: the rows keep `UnionLimitedItem`) and the title tag (None, as the cut
machine leaves it) through `FUN_141f47130`. A close calls `FUN_141fc5120` with the entry's own type, the virtual at
`+0x38` of its `+0x10`, as the node does. A new entry with no shop logic is closed the same way at once, and the open
answers `logic`. A fault inside `FUN_141f47130` leaves the new screen up without its shop: the latch then stops every
read and close, so the player closes it. A purchase is then the game's own local job (`FSBActorBuyItem`): it checks
the seeds, removes them, raises its BuyItem and ConsumeInShop achievement events with the seed and the shop's (empty)
tags, and adds the item through the bucket add `ItemBucketItemAdd` also uses.

After the first request (Lua's `nightshop watch`), every 250 ms the game thread reads whether a shop screen is open and,
with the client in game (flow 2, which the title screen fails) and inside the rows' gate (net mode 0, no logic task in
flight, since a purchase is a logic task), the bucket's seed count through the screen's own call (`FUN_141c3e6c0` on
`FUN_141cc1d60` of the player data, the world's `+0xe8`). The reads go on for the rest of the game run; whether a level
load leaves the flow at 2 while the player data is torn down is not checked. The `nightshop=` status line carries both
and the last request's answer. A close asked after `coop off` still runs.

### The wallet

The wallet file (`coop-night-<steamid>-<index>.txt`) stays the record. Before the open, Lua adds the wallet's points to
the bucket as Beta Seeds, minus any seeds already there (or takes the surplus out), through the player controller's
`ServerRequest_ItemBucketItemAdd` (no pickup message) and `ServerRequest_ItemBucketItemRemove` (any pocket), with
`Money_NightOperation` only, and asks for the open once the count matches. While the screen is open, each new count is
written to the wallet. After the close, the wallet keeps the last count and the seeds leave the bucket, through the
controller and GUID read again then (after a map change the controller read at the open may be another object; Lua
also stops before the fill when EVE's map changed during the rows). Until the open, each step first checks that the
status still reads the wallet's co-op save (`slot=coop` with its index): on another save, or during a load, Lua stops
with no seeds added, no open and no removal, since the bucket may then be another save's. A save made while seeds are
in the bucket holds them: from the fill to the removal, or after a removal that failed, which the next
`coop nightop shop` corrects. A game
restarted from that save loads them before the shop's rows are in. A save restore does not change the points, as
before. The run's start refuses while the screen runs, and so does a guest's answer to the host's run, so no credit
lands while seeds are out. When a step fails, Lua asks for the close only once the game opened the screen for it,
never after a refused open, when the screen up may be the game's own. `coop off` also asks for it while the open's
answer is not read yet (about 250 ms), so a game shop screen that came up in that time closes too. When the screen
ends early (`coop off`, a fault, a step that times out), the seeds that go are the last count read once open, and
before that at least the count Lua added, since a read from before the add still says the old count. After a fault the
native part no longer reads or closes the screen, so those seeds leave the bucket at once and a screen left open sells
nothing. After a Lua reload, the first tick that reads seeds in the bucket with a shop screen open takes the screen
over as open: only the screen adds Beta Seeds, so they are this wallet's. With no shop screen open, those seeds leave at
once and the wallet is not written: after a removal that failed or an older save loaded, the bucket no longer matches
the wallet, which stays the record as at a fill.

## Roxanne's Night Operation choices

`nightop/roxanne.lua` adds Night Operation's levels and supplies to Roxanne's dialogue on a co-op save. Her choice list,
`TS_Xion_Roxane_Choice`, holds two TheaterSelectDataTable rows (Shop, End Conversation). The game does not read the list
from the table when a dialogue starts: `FUN_141b41090` looks the list's name up in a cache built before play, a TMap at
the world singleton's (`0x147032570`) `+0xe0` object's `+0x5f0` (elements of `0x28` bytes: the name at `+0`, its TArray
of row names at `+0x10`, count `+0x18`, max `+0x1c`; find `FUN_1417022e0`), then fetches each listed row by name and
reads its fields live. So writing a row's `SelectDataName` does nothing, and a row added with AddRow is not listed
either.

1. Text: the four labels go into the `DisplayText` of four shipped test rows that no story graph lists
   (`Temp_TS_Select_Test_1` to `_3`, `TS_GoToTest_1`), in the game's language read each time the rows are armed
   (KismetInternationalizationLibrary `GetCurrentLanguage`, mapped by `culture()`: `fr-FR` to `fr`, an unknown or
   unreadable one to `en`; `nightop/roxanne_text.lua` has the 23 languages). The rows are armed at a Lua load, and again
   when her choices come back after `coop off` or after a save that is not a co-op save. Going to the title and loading
   a co-op save keeps the labels. No text key is registered: KismetTextLibrary `PolyglotDataToText` takes the languages
   as a TMap inside its struct parameter, and UE4SS 3.0.1 converts a Lua table there from the wrong stack slot
   (`Lua::for_each_in_table` walks slot 1, the outer struct's table), so the call raises, or reads the struct's own
   fields, `CachedText` included.
2. Rows: each is edited in place through the recruiter's checked edit (its ID and list checked, then
   `InteractionGraphExec` `Success2`, the exec of her End Conversation, so her graph plays a goodbye and ends,
   `NextTaskTagName` `None`, and `DisplayText` `FText(label)`), read back through a fresh FindRow. Either the shipped
   value or ours is accepted, so a Lua reload goes on. A row that does not read back stops the arm, and every row is
   put back, that one included. The exception is a Lua reload while the `roxanne=` line still reads `on`: her list
   may show the rows, so they stay ours until the off of step 5.
3. The list: `nightop/roxanne.h` (free of Windows, tested against fake memory) and `glue/tick/nightop_game.inc` point
   her entry at a new array of six FNames, the four rows then her two, allocated with the game's GMalloc
   (`0x14706b500`, Malloc at its vtable's `+0x10`) so the game may free it like its own. From the moment the entry
   points at it, the array is the game's: it is used again only after off took it back, and an entry the game rebuilt
   meanwhile gets a new one (the shape check compares the count too, as GMalloc may hand a freed array out again). The
   entry is changed only while it holds exactly her two rows in her order; the old array is kept, and off puts the old
   pointer, count and max back only while the entry still points at the new array. The entry is found again by name
   at every step. The writes run on the game thread inside the rows' gate under their own SEH latch: the pointer
   before the count when the list grows, the count before the pointer when it shrinks. All six rows read priority 0,
   so End Conversation stays last whether the choice box sorts by priority with a stable order or not, and the cancel
   input, which picks the last slot, still ends the talk. The `roxanne=` status line gives the entry's shape every
   250 ms after the first request; Lua asks again when it reads `off` while it wants it on (a rebuilt cache).
4. The pick: every 250 ms while EVE is in Xion, Lua looks for the choice boxes (`SBSequencerInteractionSelectWidget`)
   through UMG's `GetAllWidgetsOfClass` (the engine's class lookup, not a walk over every object) and reads each one's
   `SelectIndex`. A box found again keeps its last value (by address), so a box built for a later talk is watched
   while an older one is still valid. A change from -1 to a line is a pick; a box first seen on a line holds an old
   pick. The line's `DisplayText` (from `DataArray`) is matched against the labels in every language. A level is
   booked and started through `coop nightop start <level>` once EVE is out of Xion (every 5 s, with that command's
   co-op save and race checks). A host's start only asks the guest (the run's phase `ask`), so the booking holds until
   the run leaves that phase: it goes once the run counts down, and a dropped ask is tried again 30 s later. The
   supplies call `coop nightop shop` 5 s after the pick.
5. Off: on `coop off` and on a save that is not a co-op save, `roxanne off`, asked again every 10 s while the `roxanne=`
   line reads `on` (Lua's tick goes on after `coop off` for that alone, and the native part still takes an off then).
   The rows get their shipped values only once the line reads `off` after an off it took, or `absent`: while her entry
   may still list them, they keep `Success2`, which only plays her goodbye, and after a fault they keep it until the
   game exits. Going off writes each row's Korean source (from `nightop/roxanne_text.lua`'s keys) back into
   `DisplayText` as plain text, not the asset's keyed text. No vanilla list holds these rows, so the difference does not
   show. A load (the title, a map, leaving Xion included) reads `slot=none` or `unknown` for a while: once armed, Lua's
   tick only runs the drops below then, so the swap holds through it, and a booking and a supplies pick hold through a
   map load. A supplies pick still goes 30 s after its screen was due (`SHOP_WAIT`), a load included. The title screen
   (Lua's `puppet.world`, the `world=title` of `coop-state.txt`, since the status line has no such flag) and a co-op
   save with another index drop the booking and the supplies pick: after the title, the slot loaded may hold another
   file.

Not checked offline: that UE4SS writes a TextProperty (`FText(label)`) into a row FindRow returns and reads it back
through `U.text` (if not, the arm logs a `STOP: roxanne` line and puts the rows back), and that the choice box draws
that plain FText; who builds the cache and whether anything rebuilds it (the `off` re-ask covers a rebuild); the
choice box's sort; that `GetAllWidgetsOfClass` finds the box in this build; and whether the game builds a new box for
each talk or keeps one (both are read).

## The cut stimpacks

The game ships the Burst Stimpack's consumable row (`HP2Burst_Potion`, ID 1004: 400 HP for 600 Burst gauge), the Beta
Stimpack's use condition, effects (20% of maximum HP for 50 Beta energy) and icon, and English text for both, but no
ItemTable row for either. The first 4 rows of the batch make them usable. Each is a copy of a shipped row of its table
with a few fields changed, and the generator restates every other field from that row's dump:

| Row | Table | ID | Copy of | Changed |
| --- | --- | --- | --- | --- |
| `P_Eve_Sword_Normal_Buff_1` | SkillTable | 6000101 | `P_Eve_Sword_Normal_Potion_1` | nothing: the name `HP2Burst_Potion` gives its use skill, which the game never shipped (its Show `P_EVE_SWORD_USE_Buff` ships, its steps do not), so the stimpacks play the health potion's steps |
| `Buff_HP2MP` | ItemConsumableTable | 1032 | `HP2Burst_Potion` | the condition group `CG_Item_ConsumeAllow_HP2MP` and the effects `Item_Buff_HP2MP_ReduceHP` and `Item_Buff_HP2MP_GainMP` |
| `HP2Burst_Potion` | ItemTable | 300013 | `HP_Potion` | text keys, consumable, icon `Item/Burst`, pickup blueprint `BP_Item_HP2Burst_Potion`, no drop pool, 2 charges with no stat override (as `HealGrenade`) |
| `Buff_HP2MP` | ItemTable | 300014 | `HP_Potion` | text keys, consumable, icon `Item/Buff_HP2MP`, no drop pool, 2 charges with no stat override |

The generator checks that each consumable, condition group, effect, skill, icon, blueprint and Show the rows name
exists in the dumps or the pak listing. `nightop/shop.lua` sells both items. Before a buy of one, it calls
`cut/lion.lua`'s `Lion.rows`, which takes the same steps as `coop lion rows` (the tables, the request or the rows
already in, the wait, the read-back) and then hands the end to the shop: the shop checks the buy again and grants it,
or says why the rows are not in. The answer of a buy that waited comes from `coop lion`'s tick.

## The cut Shock Bolt

The game ships most of the Shock Bolt, a third cut ammo for EVE's gun: its two fire commands (SkillCommandTable
`P_Eve_Gun_ShootShockSlug1_1` and `_1_2`, `RangedFireItem` with `BulletItemAlias` `Bullet_Shock`) and its failed shot,
its skill's three steps (100340101 to 100340103: `Hit1` plays `CH_P_EVE_01/Skill/P_Eve_Gun_ShootShockSlug1` and fires
`P_Eve_Gun_ShootShockSlug1_Projectile1`), its consumable (`Bullet_Shock_Consume`, 1027: the skill and a 1.5 s cool
time), its ItemBulletTable row (1004), the projectile's blueprint, and the stun effect `ShockSlugStun` (4100056: 10 s of
blocked behaviour and a skill cancel, not on an animal, elite or boss, ended by the next hit) with its Show and sounds.
Four rows are missing. They are a batch of their own (`kBoltRecipe`, request word `bolt`), at free IDs in gaps of each
table's numbering:

| Row | Table | ID | Copy of | Changed |
| --- | --- | --- | --- | --- |
| `Bullet_Shock` | ItemTable | 32 | `Bullet_Scatter` | text keys `Item_Bullet_Shock_*` (no plural ships, so the name serves), consumable, bullet, pickup blueprint `BP_Item_ammo_shock`, icon `HUD/bullet_icon_06` (shipped, used by no item: a guess), no drop pool, a cap of 30 with no stat override |
| `P_Eve_Gun_ShootShockSlug1_1` | SkillTable | 1003401 | `P_Eve_Gun_ShootScatterSlug1_1` | the shipped Shock steps; no acquisition, damage upgrade or achievement tag |
| `P_Eve_Gun_ShootShockSlug1_Projectile1` | ProjectileTable | 1010051 | `P_Eve_Gun_ShootSlug1_Projectile1` | the shock blueprint and the hit result below |
| `P_Eve_Gun_ShootShockSlug1_Projectile1_Hit1` | SkillResultTable | 100200801 | `P_Eve_Gun_ShootSlug1_Projectile1_Hit1` | `ShockSlugStun` added to the effects on the target |

ProjectileTable is the fifteenth table every rows request names, and only this batch has a row in it. The batch is
apart from the Lion's because nothing in it had run in game when it was added: a refusal stops a batch at its first
row that fails, and the Lua read-back stops at its first value that differs, so in the lion rows batch a Shock Bolt row
would have stopped `coop lion`, `coop chainspin` and the stimpack buys. Only the shop (`nightop/shop.lua`, through
`Lion.rows` with the word `bolt`) asks for it: a Shock Bolt buy, and `coop nightop shop` before it opens the screen.
Its line in `coop-status.txt` is `bolt=`, in the same forms as `lion=`
(`bolt=rows added=4/4 asks=<a> spawns=<s> char=0/0 skills=<k>/1 stance=0/0`), and `cut/lion.lua` reads its 87 fields
back as it does the Lion's.

With no stat override (`ActorStatType_None`) the game reads the cap from the row's `MaxAmount`; all six
`ItemStackBullet` stats belong to shipped ammo. The skill has no acquisition because the game refuses a skill whose
acquisition the player lacks, and no Shock Bolt Magazine (`Drone_BulletAdd3_1`) ships. The generator checks that every
projectile the skill's shipped steps fire is a row, and the projectile's blueprint, target filter and results.

The rows alone do not let EVE fire it: her two gun stances (`P_Eve_Gun`, 100104, and `P_Eve_GunBlockSword`, 100110)
list only the failed shot, and the game's ammo list stops at five. `lion/shock.h` grows both in place, in the same
game-thread call as the bolt batch's last AddRow (so inside its gate), under a latch of its own. No other batch runs
it, so `coop lion`, `coop chainspin` and the stimpack buys leave both lists as the game ships them:

- The game reads a stance's `CommandArray` (a `TArray<FName>` at row `+0x90`) in one place: when the stance starts, it
  copies each command into nodes of its own and keeps no pointer into the array. The native part takes the row the
  stance change looks up (the registry's lookup by name, `0x141a9cd20`), checks its ID and appends the two fire
  commands the way the game appends: the count raised, the game's grow (`0x140e47f00`, a reallocation through the
  game's allocator) when it passes the capacity, then the names. EVE gets them the next time she enters the stance.
  AddRow under a live stance's name would free the row the game hands out.
- The ammo list is `BulletItemSlotArray`, a string array in the game's constant store (the singleton at `0x147032540`,
  keyed by the hash of the name, `0x14117c1f0`): `Bullet_Normal`, `Bullet_Scatter`, `Bullet_Railgun`, `Bullet_Missile`,
  `Bullet_Explosive`. The item slot manager and the TPS bullet HUD copy it when they start. The game locks a slot only
  while its index is below the 5 entries of `BulletItemAcquisitionSlotArray`, so a sixth, `Bullet_Shock`, is never
  locked. The native part appends it there through the game's allocator and, when the slot manager already exists, to
  the manager's own list. The HUD is a carousel of three slots (`Slot_Left`, `Slot_Center1`, `Slot_Right`) plus the
  Missile and Railgun slots, filled from the list at its start, and each reader of the selected slot checks it against
  its list's length.

Every value is checked before the first write: both rows and their IDs, each array's count and capacity, and both ammo
lists holding exactly the five shipped entries (or those and `Bullet_Shock`: grown already, left as they are). A
refusal writes nothing, except `why=alloc`: the game's allocator gave nothing partway through the writes, and what went
in before it stays (the fire commands appended, and the ammo list's sixth entry when the slot manager's list is the one
that failed). The status gets a `shock=` line:

```
shock=off
shock=in commands=<gun>,<block> added=<n> list=<n> slots=<n|->
shock=refused why=<word> at=<P_Eve_Gun|P_Eve_GunBlockSword|BulletItemSlotArray|slots>
shock=fault where=<text>
```

`slots=-` means the slot manager did not exist yet; it copies the list when it starts. The native part sets the line
before the `bolt=` line says `rows`, so whoever reads `rows` reads the final `shock=`. `nightop/shop.lua` grants Shock
Bolts only once it reads `shock=in`. Firing, the bolt count, the cool time and the stun are the game's own once the data
is in. None of it has run in game, and how the HUD shows a sixth entry is the main unknown.
