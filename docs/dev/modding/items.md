# Team shop items

The [team shop](../../world/teamshop.md) sells outfits made by SBO team members for gold in Stellar Blade's own shop
screen. Each team member writes their items in one data file, `data/teamshop/<owner>.json`. `tools/teamshop_rows.py`
turns every file into the rows the module `world.teamshop` adds to the game's tables. This page covers stage 1: items
that point at an outfit the game already ships. Outfits with meshes of their own (stage 2) are not built yet.

## The data file

The Gothic Rose suit, `data/teamshop/kwisatz_haderach.json`:

```json
{"about": "Team shop items of kwisatz_haderach. tools/teamshop_rows.py turns them into rows. Set a field only when it differs from the donor's.",
 "owner": "kwisatz_haderach",
 "ids": {"ItemTable": [2001000, 2001999], "ShopItemTable": [10000, 10999]},
 "items": [{"alias": "SBOTeam_GothicRose", "donor": "BS_Yellow_Suit_Jacket",
            "set": {"EquipmentAlias": "BS_1000", "Name": "Item_BS_1000_Name", "DescContent": "Item_BS_1000_Content"},
            "price": {"BetaCrystal": 5000}}]}
```

- `about`: text for readers. The generator ignores it.
- `owner`: your name in letters, digits and `_`. One file per owner.
- `ids`: your two ID ranges, first and last ID (see [IDs](#ids)).
- `items`: your items, each with these keys:
  - `alias`: the item's ItemTable row name. It starts with `SBOTeam_` followed by letters, digits and `_`. No other
    item of any file may use it.
  - `donor`: the shipped ItemTable row the item copies. The generator knows one donor today, `BS_Yellow_Suit_Jacket`,
    a suit (category 4, NanoSuit) whose `EquipmentAlias` names an EquipmentTable Body row.
  - `set`: the ItemTable fields that differ from the donor's, from the [allow-list](#fields). A field left out keeps
    the donor's value. Gothic Rose keeps the donor's icon (`Asset2D`) and `DescFunction` text.
  - `price`: `{"BetaCrystal": <n>}`, one price in gold (`BetaCrystal`, ItemTable row 9001) from 1 to 999999.

Gothic Rose sets three fields. `EquipmentAlias` names `BS_1000`, the cut outfit's EquipmentTable row, which the game
looks up when EVE puts the suit on. `Name` and `DescContent` name the cut outfit's ItemStringTable keys.

Each item gives two rows. The ItemTable row takes the alias as its name. The ShopItemTable row `<alias>_Buy` copies
`StudioTest_BS_Yellow_Suit_Jacket_x1_Buy` (a buy row with no gate field and a limit of 1) and sells the item for its
price. One ShopTable row, `SBOTeam_Shop` with ID 10000, copies `Shop_NightOperation` and lists every `_Buy` row of
every file, in file name order. The generator writes the shop rows' fields itself. A data file never names a
ShopItemTable or ShopTable field.

## IDs

Each owner holds one ID range in ItemTable and one in ShopItemTable. The item at index `i` of `items` (0 for the
first) gets the ID `first + i` in both tables. A range must lie above the highest ID the game ships. It must also lie
above the IDs the lion, bolt and Night Operation shop batches add. It may not overlap another owner's range. It must
hold at least one ID per item.

| Table | Highest ID taken: game, batches | kwisatz_haderach |
| --- | --- | --- |
| ItemTable | 2000151, 300014 | 2001000 to 2001999 |
| ShopItemTable | 9007, 3573 | 10000 to 10999 |

The taken IDs are `SHIPPED_MAX` and `BATCH_MAX` in `tools/teamshop_rows.py`. The game's come from build 26123051's
table dumps, the batches' from their headers.

Ask MotherSphere for your two ranges before you write your file. If an SB update ships a row on one of your IDs, the
row engine refuses that row. The shop then stays shut (see [Limits](#limits)) until the range moves.

## Fields

An item's `set` may hold these ItemTable fields (`FIELDS` in `tools/teamshop_rows.py`):

| Field | Value |
| --- | --- |
| `Name`, `DescFunction`, `DescContent` | An ItemStringTable key, not the text itself |
| `Asset2D` | The icon's texture, written as the shipped rows write it |
| `Category`, `Rarity`, `MaxAmountOverrideActorStat` | An enum value as a number |
| `MaxAmount` | A whole number |
| `InventoryAlias`, `EquipableAlias`, `SkillEquipableAlias`, `EquipmentAlias`, `EquipmentAlias2`, `ValidConditionGroup` | A row name, or `None` |

For a suit (category 4) the generator requires `MaxAmount` 1, `InventoryAlias` `None` and `MaxAmountOverrideActorStat`
0. Before the buy takes the gold, SB's shop screen compares `MaxAmount` with the count EVE holds under the item's
alias. With those three values a suit EVE holds is not sold again.

`ApplyEquipType` is not on the list. It is an array of bytes, a kind the row engine (`native/src/rows/rows.h`) cannot
write, so an item keeps its donor's.

### Adding a field

1. Read the field in Ghidra on build 26123051: its offset in `SBItemTableProperty` and its property type, from its
   `FPropertyParams`. A value from notes, a forum or another mod does not count ([AGENTS.md](../../../AGENTS.md)).
2. Add a line to the ItemTable part of `FIELDS`: the offset, the patch kind of `rows/rows.h` and the read-back kind
   of `core/enemy.lua`, with the params address in a comment. The generator writes the patch kinds `u8`, `i32`,
   `name`, `string` and `names`. Their read-back kinds are `e` (enum) or `b` (bool), `i`, `n`, `s` and `N`. A float or
   a list of strings needs the generator's checks and writers first.
3. Add a case to `tests/tools/teamshop_rows_test.py` that sets the field.
4. Run the [commands](#commands).

A new donor is a line in `ITEM_DONORS` with the donor's `Category`, `MaxAmount`, `InventoryAlias` and
`MaxAmountOverrideActorStat`, read in the table dumps. The dumps are game files that stay out of the repository, so
ask MotherSphere for the read.

## Commands

From the repository root, after a change to a data file:

```bash
python3 tools/teamshop_rows.py
python3 -I tests/tools/teamshop_rows_test.py
lua5.4 tests/lua/world/teamshop/shop_test.lua
python3 tools/install.py --dry-run
```

The first command writes `native/src/world/teamshop/teamshop_rows.h` and
`mod/StellarCoop/Scripts/world/teamshop/rows.lua`. Commit both with the data file. With `--check` the generator
writes nothing. It exits 1 when either file differs from what the data gives.

`teamshop_rows_test.py` runs that check, then its own refusal cases. `shop_test.lua` loads the new `rows.lua`.
`install.py --dry-run` runs every test of the repository, `tests/native/rows/rows_test.cpp` among them, which checks
the team shop's names and IDs against the lion, bolt and Night Operation shop batches. It needs the toolchain of
[Building](../building.md#toolchain). Where the toolchain exists, it must exit 0 before a commit.

## What the checks refuse

The generator stops with a Python error and writes nothing on:

- an owner named twice, or an owner name with a character other than a letter, a digit or `_`;
- an ID range at or under a taken ID of [IDs](#ids), a range that overlaps another owner's, a first ID after the last,
  an ID of 2^32 or more, a range smaller than the owner's item count;
- an alias without the `SBOTeam_` prefix, with a character other than a letter, a digit or `_` after it, or an alias
  another item holds;
- a field off the allow-list, or a donor not in `ITEM_DONORS`;
- a price other than one whole gold price from 1 to 999999;
- a suit whose `MaxAmount` is not 1, whose `InventoryAlias` is not `None` or whose `MaxAmountOverrideActorStat` is not
  0;
- text that is not ASCII or holds `"` or `\`, a byte field above 255, a whole number of 2^24 or more;
- a batch of 256 rows or more;
- a row whose strings and lists do not fit the row engine's 4 KB pool (`POOL`).

In game, the row engine also refuses a row whose name or ID the table holds already, or whose donor it cannot find.
An SB update that takes one of the team's names or IDs shows up there, never in the generator.

## In the game

At the title, while the game uses the co-op save files, `world.teamshop` asks for the `teamshop` batch once a game
run. The native part adds each row through SB's own AddRow on the game thread. Lua then reads every patched field
back. `coop teamshop` opens SB's shop screen, the one the vending machines open, on `SBOTeam_Shop`. The game does the
buy. It takes the gold and puts the item in EVE's inventory. The player equips the suit in the game's own menu. A suit
EVE holds is refused before the gold goes. The buy counts toward no achievement.

The module logs `[StellarCoop][TS]` lines in `UE4SS.log`. `coop-status.txt` holds a `teamshop=` line for the rows and
a `teamshopui=` line for the screen. [world/teamshop.md](../../world/teamshop.md) lists when `coop teamshop` refuses.
Nothing of the shop has been tested in game yet.

## Limits

- One batch, `teamshop`, holds every owner's rows: every ItemTable row, then every ShopItemTable row, then the
  ShopTable row. The first refused row stops the rows after it. The shop then stays shut for every owner for
  that game run.
- A fault in any batch's table calls stops every batch not in yet for the game run, the team shop's included (the
  shared latch of `native/src/rows/rows_game.inc`).
- The rows live for one game run. They go in at the title before a co-op save loads. The next game run adds them
  again.
- Co-op saves only. The title asks for the rows only while the game uses the co-op save files. `coop teamshop`
  refuses on your own saves.
- `coop saves export` refuses a save that names a team item anywhere: an `ItemAlias` name or a quick slot name that
  starts with `SBOTeam_` (`kTeamItems` in `native/src/game/twins.h`), in the save as played or in its New Game+ copy.
  The inventory and a pickup left in the world hold such names. So does SB's save record of limited buys,
  `SBShopHistory`, whose entries are `SBSaveGameData_ShopLimitedItemHistoryObject` {`ItemAlias`, `PurchaseCount`}.
  Each `_Buy` row keeps its donor's limit of 1, so that record may keep the item's name after the buy. The code that
  writes it has not been traced. A save may then stay refused after EVE no longer holds the item. See
  [Saves](../../players/saves.md).
- ASCII text only. The row engine writes each byte of a text as one UTF-16 character, so the two bytes of a UTF-8
  `é` would show as two wrong characters.
- `Name`, `DescFunction` and `DescContent` are keys of the game's ItemStringTable. Stage 1 adds no key, so an item
  shows names and text the game ships, such as the cut outfit's `Item_BS_1000_Name`. The generator cannot check that
  a key exists.
- One ShopTable row, `SBOTeam_Shop`, sells the items of every owner on one screen.
- At most 127 items in all: a batch holds under 256 rows, two per item plus the shop row.
- `EquipmentAlias` must name an EquipmentTable row the game ships. EquipmentTable rows for meshes of your own are
  stage 2, which is not started.
- An item changes no shared piece: no row word, no `RowsJob`, no line in `twins.h`, no word in `ui/text/`. Only the
  data file and the two files the generator writes change. A new field or donor changes `tools/teamshop_rows.py` and
  its test. A field of a kind the row engine lacks, as `ApplyEquipType`, needs a change to `rows/rows.h`, a shared
  piece that changes only when MotherSphere asks.
