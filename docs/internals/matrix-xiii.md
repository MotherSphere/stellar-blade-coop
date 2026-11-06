# The cut Matrix XIII dungeon (experimental)

The player's side of the dungeon is in [Matrix XIII](../matrix-xiii.md), and the quests that lead into it in
[Lily's signal: how it works](lily-signal.md).

WorldTable row `DLCMatrix13` (ID 2800) points to `/Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P`, a map that no pak of
build 24463856 holds. ZoneTable keeps its four zones (`Zone_DLC02_10` to `Zone_DLC02_40`, IDs 2800 to 2815) and
EventSpawnTable 92 spawn rows for them, but no camp, zone warp, world transition or cheat row leads there. `coop mxiii`
tests one way in. The zMXIII_P test pak, built outside the repository from shipped Matrix 11 levels and never in the
mod's zip, puts a map at that path with a spawn point named `DLC02_10_Camp_01`; its v2 build adds the spawn points of
a camp's objects, its v3 build a spawn point named `DLC02_30_Camp_01` in the third zone, and the full map (v4) a spawn
point named `DLC02_00_Camp_00` at the zone 0 Tetrapod, 4.4 m from Lily. The mod adds the rows of
a camp in `Zone_DLC02_10` and of a camp with no objects in `Zone_DLC02_30`, patches five trigger rows of the later
zones in place, then calls the game's camp travel: on v4 `coop mxiii` goes to the Tetrapod camp, on older paks to the first camp, and
`coop mxiii 30` to the second. With the
test pak installed and the game on the co-op save files, the same rows also go in at the title, before any save loads
([At the title](#at-the-title)).

## Its rows

The camp travel (`FUN_141cdd7b0`, see [Following the host](group-play.md#following-the-host)) looks the camp up in the zone
manager's camp list, takes the camp's first ZoneEnvSpawnTable row, then that row's zone and the zone's world. The
arrival (`FUN_141a8afe0`) puts EVE at the actor named after the camp, the test pak's spawn point. A camp's objects are
ZoneEnvSpawnTable rows too: each row's `EnvAlias` picks the ZoneEnvTable row that gives the object its type and its
interaction graph, and its `TargetCamp` is the camp that activating, resting, the phone booth and a respawn act on. The
game keeps the DLC02_10 camp kit (`DLC02_10_EnvS_420` to `_426`), but its rows name placeholder camps of other worlds
(`WLB10_Camp_05`, `SE02_Camp_02`) and expect actors placed in a map that no pak has.

The mxiii rows batch, written by hand in `lion/rows.h` after the generated part and with patches of its own, adds ten
rows, each a copy of a shipped row with its own name and ID:

| Row | Table | ID | Template | Changes |
| --- | --- | --- | --- | --- |
| `DLC02_10_Camp_01` | ZoneCampTable | 280001 | `ME01_Camp_03` | `CoinSpawnPointName` `DLC02_10_E_ItemS_001`; `CampType` stays FullCamp, `CampDisplayType` stays WhenActive |
| `DLC02_10_EnvS_900` | ZoneEnvSpawnTable | 2800032900 | `DLC02_10_EnvS_425` | `TargetCamp` `DLC02_10_Camp_01`; `EnvActorName` and `SpawnPointName` its own name; `EnvBPPath` the camp base `Env_Camp_Base`; `ZoneList` stays `Zone_DLC02_10` |
| `DLC02_10_EnvS_901` to `_905` | ZoneEnvSpawnTable | 2800032901 to 2800032905 | `DLC02_10_EnvS_420` to `_424` | `TargetCamp` `DLC02_10_Camp_01`; `EnvActorName` and `SpawnPointName` their own name; `EnvBPPath` the skill machine, chair, storage, turntable and phone booth blueprints under `/Game/GameDesign/Level/ZoneEnv/` |
| `DLC02_10_EnvS_906` | ZoneEnvSpawnTable | 2800032906 | `DLC02_10_EnvS_426` | The same four, with `Env_VendingMachine`; `LinkEnvSpawnList` 901, 902, 900, 903, 904, 905, in the shipped order; `ShopDataList` its own name |
| `DLC02_30_Camp_01` | ZoneCampTable | 281001 | `ME01_Camp_02` | `CampType` stays SimplyCamp, `CoinSpawnPointName` `DLC02_30_E_ItemS_001`, Region `Matrix13` |
| `DLC02_30_EnvS_900` | ZoneEnvSpawnTable | 2810032900 | `DLC02_10_EnvS_425` | `ZoneList` `Zone_DLC02_30`, `TargetCamp` `DLC02_30_Camp_01`, `EnvActorName` its own name |

`FUN_141d18100` lists a camp's rows in table order, and AddRow appends, so row 900 stays the camp's first: it leads the
travel to `Zone_DLC02_10`. All seven spawn their objects. `FUN_141d1e5b0`, which makes a zone's
env objects, looks for a placed actor named `EnvActorName` when `EnvBPPath` is empty; with `EnvBPPath` set it spawns
that class at the actor named `SpawnPointName`, as 137 shipped rows do (Xion's supply boxes, `DLC02_10_EnvS_441`), none
of them a camp object until now. The blueprints are the six kit actors of the Space Elevator's full camp
`SE02_Camp_02`. The vending machine row starts enabled and the others disabled: activating the camp with a coin sets
it and every row in its `LinkEnvSpawnList` on, 900 included, as the shipped full camp `ME03_Camp_01` links its base
row `ME_03_EnvS_012`. The coin is `DLC02_10_E_ItemS_001`, an EventItemTable row of the game's that spawns a vending machine coin
at the spawn point of that name when EVE enters the zone. The camp keeps
`ME01_Camp_03`'s picture, and its name until [the camp names](#the-camp-names) replace it. Its Region is `Matrix13`, a name the game makes a bucket for on first sight, so a full
camp's list shows only the dungeon's full camps. The Tetrapod row `DLC02_00_Camp_00` keeps Region `Matrix11` from its
donor `ME01_Camp_00`. In game (2026-11-03) the region teleport screen still shows it under a tab of its own, "Matrice 13",
right after "Matrice 11", with Matrix 11's picture; Matrix 11's tab lists only its own six camps. No dungeon has a world map in the
game (WorldMapTable has 5 rows, none of them Matrix 11), so for a dungeon camp the camp list is the whole display.

The third zone's camp gives `coop mxiii 30` a way past the climb from `Zone_DLC02_20` (see below). The travel reads
only the camp's first env-spawn row (its `Zone`, else `ZoneList[0]`, then that zone's world), and the arrival needs
only the spawn point named after the camp. No DLC02_30 row is an activation-only one, so `DLC02_30_EnvS_900` takes row
900's template and gets `Zone_DLC02_30` as its `ZoneList`. The camp is a simple camp copied from `ME01_Camp_02`, with
a vending machine, a kit and the coin `DLC02_30_E_ItemS_001`, like the map's other simple camps. The v3 pak's spawn
point takes the site of `ME03_Camp_01` (26392, -23650, 4414, Matrix 11's own arrival point for that camp). The v3
pak moves the six Matrix 11 kit objects placed around that site 40000 units down, as v2 does at the first camp's
site: their rows belong to `Zone_ME_03`, which never starts in this world, and the vending machine's row
`ME_03_EnvS_005` is one of the camp achievements' rows. For the same reason it moves the vending machines of the
other Matrix 11 camps in its levels: two more in Area03, two in Area04 and one in Area01
([Achievements](safety.md#achievements)).

The two zone tables are the sixteenth and seventeenth of the 37 tables every rows request names (`kLionTables`), and
only Matrix XIII's batches write them; their struct sizes (0xa8 and 0x508) and offsets come from the SDK, as the generator reads
them for the other tables, and neither struct has a Transient field. The batch's line is `mxiii=`, in the `lion=`
line's forms (`mxiii=rows added=15/15 asks=<a> spawns=<s> char=0/0 skills=0/0 stance=0/0`), and `cut/enemy.lua` reads
its 41 patched fields back (the 36 of the camp rows and the 5 of the trigger rows below), `EnvBPPath` as text and
`LinkEnvSpawnList`, `ZoneList` and `TouchEvents` as lists of names. The read-back compares an ID
on its 32 bits, so 2800032900 matches whether UE4SS reads it as signed or not.

## Its event spawns

Of the dungeon's 92 spawn rows, 19 wait for props of the cut map. The 11 Antlions of `Zone_DLC02_20` are `ZoneEvent`
spawns in three waves: when the countdown gates `DLC02_20_EnvS_014`, `_018` and `_016` reach their `Open` tag, their
ZoneEnvSpawnTable rows run the zone events `DLC02_20_ZoneE_022` to `_025`, `_026` to `_028` and `_029` to `_032`, each a
`ZoneEvent_Spawn` of one row. In `Zone_DLC02_40`, triggers `DLC02_40_ZTrigger_001` and `_002` start the chains of spawn
rows 003 to 007 and 013 to 015 (each spawn event's `AddEvents` runs the next), but both start disabled, and only the
drain devices `DLC02_40_EnvS_002` and `_003` enable them, through `DLC02_40_E_ObjectC_001` and `_002`. The gates and
the devices are placed actors of the cut map, and the devices' interaction graph is a greybox asset missing from the
paks, so none of these events fires. The test pak places every DLC02 trigger row on a box, so the smallest change is
one field in five shipped ZoneTriggerTable rows:

| Row | ID | Field | Shipped | Patched |
| --- | --- | --- | --- | --- |
| `DLC02_20_ZTrigger_001` | 280501001 | `TouchEvents` (`+0x20`) | empty | `DLC02_20_ZoneE_022` to `_025` |
| `DLC02_20_ZTrigger_005` | 280501005 | `TouchEvents` | `DLC02_20_E_EnvC_030` | the same, then `DLC02_20_ZoneE_026` to `_028` |
| `DLC02_20_ZTrigger_006` | 280501006 | `TouchEvents` | `DLC02_20_E_EnvC_031` | the same, then `DLC02_20_ZoneE_029` to `_032` |
| `DLC02_40_ZTrigger_001` | 281501001 | `InitActivate` (`+0x1c`) | 2, Disable | 1, Enable |
| `DLC02_40_ZTrigger_002` | 281501002 | `InitActivate` | 2, Disable | 1, Enable |

The mechanism batches later took the three zone 2 patches back out: the waves now run from triggers 601 to 603 of
the `mxupper` batch, which also shut the arena gate behind EVE, and 001, 005 and 006 are their shipped rows again
([Matrix XIII's world rows](#matrix-xiiis-world-rows)).

ZoneTriggerTable (row struct `0xa8` bytes, ID at `+0x10`, no Transient field) is the twentieth table of `kLionTables`,
and only this batch reads it. A row whose template is itself is a shipped row patched in place: the builder needs it in
RowMap under its name and its ID in the ID map naming it, copies it into the block, patches the block and copies the
block back over the row with CopyScriptStruct, which reassigns `TouchEvents` through the game's allocator. The row
keeps its address, ID and lazy-init flag, and AddRow is never called for it, so nothing that holds the row loses it.
`describe` says `15/15 in, 10 added through SB's AddRow 0x14417ba30 and 5 shipped rows patched in place`. A missing
row refuses with `no shipped row of that name`, an ID that names another row with `ID <id> does not name it`. The
trigger rows keep their shipped `SaveType`: `ResetZone` for 001, `Save` for 005 and 006, `None` for the zone 40 pair.
When the game reads `InitActivate` and `TouchEvents` was not traced: the patches go in before the travel, so a zone that
starts after it sees them whether it copies the row or keeps a pointer to it. The Antlions and Clrikets they spawn are
species the other DLC02 rows already spawn, so their kills feed no achievement row the dungeon could not feed before.

The rows cannot make the climb from `Zone_DLC02_20` to `Zone_DLC02_30` work. On Matrix 11's Area02 it runs on
`Zone_ME_02`'s triggers (falling-train QTE sequences `MV_ME02_0x_QTE_*`, theater events and env controls of the ropes
and trains, all `Zone_ME_02` rows) and on the cameras of `Matrix_XI_Area02_Sequence`, which the test pak does not
stream. No zone volume of `Zone_ME_02` exists in the test map, so those rows never start, and no DLC02 row drives
those actors. Making them start would take a `Zone_ME_02` volume in world 2800, and a zone of the Matrix 11 world
starting there could write Matrix 11 zone state into the save, so the third zone's camp goes around the climb instead.

## The command

`matrix13/world/travel.lua` runs on a co-op save only (`commands/cut.lua`). It first asks the follow for `coop travel
probe`'s guards (solo, a co-op save, the native travel there, not stopped by a fault, with no warp under way and no
travel accepted in the last 10 s), then looks for the test pak: `zMXIII_P.utoc` in `SB/Content/Paks/~mods` or
`SB/Content/Paks/LogicMods`, whose directory index must name `WorldMap_DLC_01`, `Level_P` and `MXIII_P.umap` (plain text
in a container that is not encrypted), with `zMXIII_P.pak` and `zMXIII_P.ucas` beside it, since UE 4.26 mounts an
IoStore container through its `.pak`. It reads the live folder, so a pak copied in after the game started passes the
check although the engine mounts paks only at start. It reads those files once a command and never looks the map up with
`StaticFindObject`, which finds only loaded packages and costs 4 to 35 ms a miss. Then the rows go in through
`cut/enemy.lua`'s rows part, and once they read back, the follow's probe calls the camp travel for the Tetrapod camp
`DLC02_00_Camp_00` (`DLC02_30_Camp_01` for `coop mxiii 30`), a camp in none of its tables (`probe(alias, true)`). A pak
before v4 has no spawn point named after the Tetrapod camp, so there `coop mxiii` travels to `DLC02_10_Camp_01`.
`coop mxiii 30` stops before the rows unless the pak is v3 or later: on v1 or v2 the arrival would find no spawn point
of that name, and what it does then was not traced. The native side is the follow's: the guard, the count and the watch of `game/travel.h`. The
travel's result comes in `[TR]` lines. The command's answer names the way out, `coop mxiii leave`: the follow's probe,
with its activation read ([Following the host](group-play.md#following-the-host)), to a camp the read lists among the 120 travel
camps. The arrival at the Tetrapod camp, `DLC02_10_Camp_01` or `DLC02_30_Camp_01` makes it the camp EVE respawns at
(`+0x26d0`), and none of the three is in a travel table, so each command keeps the camp she respawned at when it asked its travel, if the read
lists it (inside the dungeon it keeps the one it had), and `leave` takes that camp first, then the camp she respawns at
now, then the read's first travel camp. The kept camp lives in the Lua state only, so a reload of the scripts in the
dungeon loses it.

The check tells the builds of the test pak apart by the `.ucas`, of which it reads up to 16 MB at a time. A zen package of
UE 4.26 keeps its own name map, in plain text when the container is not compressed, and an FName whose text ends in `_`
and a number with no leading zero is stored as its base: v2's `MXIII_10_LD` holds `DLC02_10_EnvS`, the base of the six
spawn point names, and v1 has no such name (its own names, such as `DLC02_10_E_CharS_001` and `DLC02_10_Camp_01`, are
stored whole). v3's `MXIII_30_LD` holds `DLC02_30_Camp_01` whole, a name neither older build has, and the full map
holds `DLC02_00_Camp_00` whole too, which makes it v4. The checks line says
which build it found and where its camp's spawn point stands: at the dungeon start (40368, 35663, -846) in v1, beside
the camp objects at Matrix 11's first simple camp site (36624, 16140, -2136) in v2, and in v3 also where `coop mxiii
30` arrives (26392, -23650, 4414); v4 adds the Tetrapod arrival (38290, 36221, 715). All get the same rows; on v1 the objects find no spawn point and none appears.
A container compressed with Oodle would read as v1.

## The arrival and the coins

The camps of the map start inactive, so the first trip lands at the Tetrapod camp, whose machine stands 11.8 m from the
spawn point and Lily 4.4 m from it. `DLC02_00_Camp_00` is CampType 4 and its only env row is `DLC02_00_EnvS_960`
(`ZoneList` `Zone_DLC02_10`). The arrival (`FUN_141a8afe0`) writes EVE's fields only: her respawn row `+0x26d0` becomes
960 and, since the camp is CampType 4, `+0x2738` (`TetrapodCampEnvSpawnAlias`) becomes the camp. It writes no env state
(read from its code), and in a shipped save a Tetrapod arrival left `LastFullCampEnvSpawnAlias` as it was, so the trip
activates nothing. The machine's row keeps `InitActivate` Enable and `InitStateTag` On, as 2 of the 7
shipped Tetrapods do, and has no coin, as none of them has. Without it the teleport screen would not list this
Tetrapod.

The 10 other camps name a coin each, `CoinSpawnPointName`, all `ETC_Item_VendingMachineCoin` EnterZone rows:
`DLC02_10_E_ItemS_001`, `DLC02_20_E_ItemS_001` to `_003`, `DLC02_30_E_ItemS_001`, `_002` and `DLC02_40_E_ItemS_001`
are the game's rows, and `DLC02_10_E_ItemS_014`, `DLC02_20_E_ItemS_022` and `DLC02_30_E_ItemS_029` are the mod's copies.
Each stands at the cooked spawn point of its own name, 80 or 88 cm from its vending machine and at its floor height.
The vending machine starts Enable and Off, the rest of the kit Disable and Off, so EVE activates a camp on foot by
spending a coin there. Of the game's 105 full and simple camps, 80 point at a Vitcoin row.

A save that has been in the dungeon keeps what happened there. The camp records and the taken coin are saved rows
(SaveType Save), so a camp activated in an earlier test stays active and its coin stays gone. The mod leaves those
records alone; a co-op slot with no DLC02 record shows the inactive state. The link to the base row runs only when the
coin is used, so a full camp activated before the base rows existed has no saved On state for its base, and row data
says the base then spawns Off (`SaveType` Save, `InitStateTag` Off; not seen in game).

## Lily's menu

`DLC02_00_E_CharS_960` uses the graph `Xion01_NPC_Lily_01` that every Tetrapod Lily uses. The graph's root is a switch
with one pin per world and no default, and `DLCMatrix13` is on no pin, so without a patch her Talk prompt opens nothing.
The `mxlily` batch patches six shipped rows in place, routing the dungeon into the Great Desert's Phase 5 branch:

| Row (prefix `Xion01_NPC_Lily_01_`) | Table | ID | Field | Shipped | Patched |
| --- | --- | --- | --- | --- | --- |
| `IACC__075` | ConditionTable | 1202 | `CustomStr01` (+0x18) | `WasteLandB` | `DLCMatrix13` |
| `IACC__073` | ConditionTable | 1194 | `CustomStr01` | `WasteLandB` | `DLCMatrix13` |
| `IACC__077` | ConditionTable | 1204 | `CustomStr01` | `WasteLandB` | `DLCMatrix13` |
| `ConditionGroup_019` (root, pin 9) | ConditionGroupTable | 244 | `ConditionEq` (+0x28) | AND (4) | OR (3) |
| `ConditionGroup_017` (console, pin 8) | ConditionGroupTable | 243 | `ConditionEq` | AND | OR |
| `ConditionGroup_018` (end, pin 8) | ConditionGroupTable | 245 | `ConditionEq` | AND | OR |

Each group then reads `IsInWorld(DLCMatrix13) OR IsValidActor(WLB_10_E_CharS_125)`. In the Great Desert the world test
is false and the actor test decides, as it did under AND. That actor is a Great Desert row, so the other worlds should not
gain the branch; this comes from the tables and has not run in game. Her start line talks about the bike's signal, and her `TS_Xion_Lily_Choice` rows have no
world condition: the bike signal, the other region, the console and the end show under their shipped conditions, and
`TS_GoToTest_2` under the mod's swap (`nightop/roxanne.h`).

The batch goes in at the title like the others, so only with the test pak and on the co-op save files, and the patch
stays for the game run. It is optional: `coop mxiii` does not wait for it, a refusal or a table that does not load
leaves her with no menu, and no other batch waits for it (`mxnames` waits only while its ask runs). The other region
row opens the teleport screen with this Tetrapod among its tabs; the bike signal's leave warps to the Wasteland
through `Xion_10_E_ZoneWarp_012` (Quest_Epic_11 M04), the main quest's point of no return, so a save that takes it with
On Time running leaves that quest unfinished.

## The camp list

`FSBGameWorld::Init` (`FUN_141c97ca0`, named by its own log line) makes a new zone manager at the world's `+0xe0`. Its
setup (`FUN_141d1a520`, `FUN_141d1af70`) runs `FUN_141d18100`, which goes over every ZoneEnvSpawnTable row, adds each
row with a `TargetCamp` under that camp at `+0x4a8` and each row to the env list of every zone in its `ZoneList`, with
no world filter; `FUN_141d1a700` clears the list. Rows added after the current world started are then missing from its
lists, and the first `coop mxiii` should end in `SB refused DLC02_10_Camp_01`. After the next world start (a save
loaded, a travel to a camp), a second `coop mxiii` reads the rows back without asking again and travels, and the world
it lands in lists the camp objects in `Zone_DLC02_10`. When the rows went in at the title, the first world
started after it lists both camps already, and the first `coop mxiii` travels. This comes from reading the code; it
has not run in game.

## The save

The save names camps and their rows in four fields: `USBSaveData`'s activated camps (`OpenCampAliases`, `+0x88`) and
the row a camp was last used through (`LastInteractCampEnvSpawnAlias`, `+0x98`), and `FSBSaveGameData_Actor`'s last
full camp and last simple camp rows (`LastFullCampEnvSpawnAlias`, `+0x26c`; `LastSimplyCampEnvSpawnAlias`, `+0x28c`).
A death or a load resolves the last row to its camp. The vending machine's interaction graph saves after the
activation and the phone booth's saves before its camp list (read from the graphs), so `DLC02_10_Camp_01` and the
mod's rows are on disk from the activation on. Resting at another camp does not take the camp out of
`OpenCampAliases`, and a rest at a SimplyCamp, such as Matrix 11's `ME01_Camp_01`, changes only the simple camp row
and leaves `LastFullCampEnvSpawnAlias` on a mod row. The arrival of `coop mxiii 30` saves the game too (read from its
code), with `DLC02_30_EnvS_900` as the save's camp row. What a load or the camp list does with a camp or row that has
no table row (`ESBEnterGameResult_NotFoundTargetCamp`, a skip or a null read) was not traced. So the rows go in at the
title whenever a co-op save could name them, and the usage section gives `coop saves refresh` at the title as the way
back once the pak is gone. On the manual co-op slot that `StellarCoopSlot.txt` names, the game uses the player's own
save files and the title adds nothing: there, as before, the rows exist only once `coop mxiii` has run in the game
run.

## At the title

`matrix13/world/travel.lua`'s `title()`, called from `main.lua`'s 250 ms loop, asks the batch when three things hold:
the title screen shows with no save loaded, the slot line reads `saves=coop` (the co-op save switch of
`session/saves.lua`, so never on the player's own saves), and the pak check finds zMXIII_P. The pak is looked for once a
Lua load, and nothing is logged without it. The request goes through `coop mxiii`'s rows flow with no EVE and no map to
keep: the tables found by path, the `mxiii rows` request, the native gate (the game thread, net mode 0, no logic task in
flight), the shared fault latch and the read-back, and no travel after. Once the `mxiii=` line reads `rows`, nothing is
asked again in the game run, and `coop mxiii` then reads the rows back and only travels. A gate that stayed shut for its
300 frames (`busy`, `net` or `unread`), no answer, or an end before the request (a table not loaded) is asked again 10 s
later while the title shows, at most four times a visit of the title. Any other refusal leaves the rows to
`coop mxiii`. `coop off` drops the wait without an end, and the next call at the title asks again. The end's line says
`before any save loads` only when the last call, at most 250 ms earlier, still saw the title with no save loaded;
otherwise it says the title closed and that a save may have loaded first.

What the title holds, read in Ghidra on build 24463856:

- The tables. `FSBLocalClient::StartLobby` (`FUN_141cc8150`, named by its own log string) calls the table holder's
  getter (`FUN_141a97f20`, the global at `0x147032510`). The first time, that getter loads every table of its list by
  path (`FUN_1426292c0`, a `StaticLoadObject` of `/Game/Local/<path>`) and roots each one (`FUN_1426293f0` keeps a weak
  pointer in the registry's first set at `+0x8` and sets the object's `RootSet` flag). StartLobby's reset
  (`FUN_142629ed0`, a jump to `FUN_14c8618d0`) un-roots and drops only the registry's second set at `+0x60`, the
  override set that `FUN_141c451b0` reads first while `+0x58` is set. So the 20 tables of the first batches are in
  memory at the title and stay rooted through the load that follows, and rows added there are in the objects the game
  reads after it. The quest tables of Lily's signal are in the same holder (QuestTable at index `0x21`, QuestTaskTable
  `0x22`, QuestTaskGroupTable `0x23`); whether LevelTargetFilter and TheaterSelectDataTable are in its list was not
  checked (one missing at the title shows as `tables: 4/5 found, missing ...` on the `[LY]` lines and the title asks
  again; each batch sends only the tables its rows use, so the other batches never wait for these two).
- The gate's globals. The logic singleton (`0x147032568`) and the net-mode cache (`0x147032528`) are made by their
  getters (`FUN_141a97b20`, `FUN_141a97aa0`) on first use and never freed. The cache starts at 4 and takes the world's
  mode at the first of the game's many inlined reads that resolves it (the dispatch's, `FUN_141aca570`,
  `FUN_141d256c0` and others). The logic task at `+0x5c0` is set only by the logic dispatch (`FUN_141acd5c0`), which
  waits for the last task and clears it before it starts the next. `FUN_14b85e230` registers that dispatch as a tick
  once, at the first world start (`FUN_141c72100`, `FUN_141cd8590`), which also sets the logic's run flag `+0x5b2`
  that the dispatch needs before it starts a task.
- So at the title of a fresh game no logic task can be in flight, and the gate opens if both globals exist and the
  cached mode reads 0. If a global is still unmade or the mode still reads 4, the gate stays shut and no table call is
  made; the code does not show which of these holds at a fresh title. `coop-link.log` answers it in game:
  `mxiii rows: 15/15 in, ...`, or `mxiii rows refused -: net mode 4 for 300 frames` or `no logic or net-mode global
  for 300 frames`. After a return to the title the dispatch keeps running, and the gate waits for a frame with no
  task, as in a world.

The rows stay in for the game run, also when the player then turns the co-op saves off and loads one of their own:
nothing in the main game leads to the dungeon or its camps.

## Matrix XIII's world rows

The cooked map (the full-build pak of all four zones) places a spawn point, trigger box, zone volume and waypoint
chain for every row the dungeon needs, and the rows themselves come from the mod. `data/mxiii-world.json` holds them
all, each as a copy of a shipped row (its donor) with the fields that differ; `tools/mxiii_rows.py` writes
`native/src/lion/mxiii_rows.h` and `matrix13/world/rows.lua` from it, so the native batches and the Lua read-back never
disagree (`tests/tools/mxiii_rows_test.py` fails when either file is out of date). The generator knows each field's
offset in its row struct from the SDK (stellar-sdk-647527f) and refuses an unknown field, two fields on the same
bytes, a batch of 256 rows or more, a name given twice, a string list of one empty item (its `|`-joined text would read
as no item) and a row whose strings and lists overflow the native part's 4 KB pool. The data file is built outside the
repository from the cook's manifest, the mechanism design and the build 24463856 table dumps.

Nine batches, each its own ask (`mxiii rows`, `mxspawn rows`, `mxenv rows`, `mxupper rows`, `mxmiddle rows`, `mxlower
rows`, `mxlily rows`, `mxnames rows`, `mxrecords rows`), so a refusal in one never stops another (`mxlily`: [Lily's menu](#lilys-menu)):

- `mxiii`, 75 rows: the 15 rows of the camp work above, less the three zone 2 trigger patches (the waves moved to
  triggers of their own, below) (the zone 3 rest stop `DLC02_30_Camp_01` is now a simple camp
  with its coin `DLC02_30_E_ItemS_001`), then the nine other camps of the map (the zone 0 Tetrapod camp
  `DLC02_00_Camp_00`, simple and full camps in every zone), their kits (34 shipped rows patched in place with a
  blueprint, a spawn point and the camp's name; 14 new rows for the two new full camps), the three new coins, and zone
  0's Tetrapod: the machine `DLC02_00_EnvS_960`, Lily `DLC02_00_E_CharS_960` (a copy of her Great Desert row with her
  Tetrapod graph) and WorldTransitionTable `WT_T_MX13`. Each of the ten coin camps holds the rows of the shipped camp of
  its type. A full camp, like `ME03_Camp_01`, has the base `Env_Camp_Base` (floor, parasol, brazier and its fire, lights
  and shield belt, its row's alias `Env_Camp_OnlyActivation`), skill machine, chair, storage, turntable, phone and
  `Env_VendingMachine`. A simple camp, like `ME01_Camp_02`, has skill machine, chair, turntable and
  `Env_VendingMachine_Simple`, with no base, storage or phone. No shipped camp spawns these objects from a row: the
  levels place them. Here each row spawns its blueprint at the point of its own name. The vending machine links every
  other object of its camp, 6 on a full camp and 3 on a simple one, and the game's graph has 7 link nodes. The base rows
  are `DLC02_10_EnvS_900`, `DLC02_20_EnvS_048`, `DLC02_20_EnvS_110`, `DLC02_30_EnvS_033` and `DLC02_40_EnvS_015`. The
  pak had points for the last four, each where the shipped offsets put the base from its vending machine, within
  0.01 unit. `DLC02_10_EnvS_900` needs a point at (39693.4, 36897.6, 587.0), yaw 15.07, in `MXIII_Z0_LD`, where the
  cooked `Z0_Camp_Floor` mesh stands; until a pak has it, that row makes no object. The cooked levels also hold static
  copies of the base's meshes (`Z0_Camp_*`, `Z2_Z2R06_D_Camp_*`, `Z2_Z2R17_D_CampD_*`, `Z3_Z3R35_D_Camp_*`,
  `Z4_Z4R03_D_Camp_*`) and, at the last four camps, a static `VendingMachine` mesh at the row's machine. A pak has to
  remove them, or the spawned objects stand on top of them and the static ones stay as they are after activation. The
  DLC02 kits ship with the
  `ShopDataList` `SE_02_EnvS_010`, a row one of the 89 `ChangeState_ZoneEnv_*_Camp` trophy rows counts, so each of the
  ten vending machines names itself there instead, as 77 shipped machines do. The rows name no trophy row, in their own
  fields or in those their donors give them.
- `mxspawn`, 51 rows: `MX13_M_Sawshark` (CharacterTable 50071, the Stalker `CHAL_UME_M_Sawshark_01` without
  `Passive_Immortal`, so it dies at 0 HP without Matrix 11's finisher), the 8 `M_DummyC` rows patched to shipped
  Naytibas (zone 3's to `DED_M_ClriketAGround_01`, zone 4's to `WLB_M_AntlionE_01`), the zone 4 rows 035, 036 and 042
  made ZoneEvent spawns, 25 new enemy rows from the 29 October roster (each bound to the spawn point of its own name,
  walking its waypoint chain), five zone 2 rows added on 2 November (`DLC02_20_E_CharS_905` to `_909`: a Hive and a
  Cricket Butcher in the A1 stores, a Chain Cricket Slasher in the A2 workshop, a Cricket Butcher in the A3 vault and a
  Barnacle on the landfill ledge, EnterZone spawns standing at their point with no patrol), the three bosses (`DLC02_20_E_CharS_904` the Gardener, a ZoneEvent spawn from
  `DLC02_20_ZTrigger_002`; `DLC02_30_E_CharS_029` the Stalker; `DLC02_40_E_CharS_051` the Lion; all SaveType Save, no
  patrol, RewardGroup `m_beach_elite1`), the four zone events that spawn the Gardener and the zone 4 trio, and the two
  trigger rows that run them.
- `mxenv`, 172 rows: the shipped device rows dev patched first, now on the mechanism design: the one-way doors 050, 051
  and 037 spawn an empty arrow at their point and move the cooked leaf with our sequences (051 has no prompt: 050's
  link opens it); the R29 gate switch spawns the wall switch `Env_CardControl_Switch_Wireless_C` (below) and, with the
  gate, lists zones 10 and 20; the 55 m lift waits at the top with our
  sequences; the 74 m lift's call switches spawn `BP_Env_LiftController_C`, disabled until the first ride up as Shift Up
  wired them; two kill volumes go under the lift shafts. Then the loot: the 10 shipped supply box rows, which ship with
  no blueprint and no spawn point, are patched in place with `BP_Env_SupplyBox01_C` (the class of
  `Env_SupplyBox_Normal01` boxes in the shipped levels) and the point of their own name; 55 new boxes copy
  `DLC02_10_EnvS_440` (reward group `b_desert_Box2`) at their point and in their zone; 97 new pickups copy
  `DLC02_10_E_ItemS_001` with the item and count of their map marker (`BetaCrystal` x12 where the marker names none).
  The 25 records wait for the records batch.
- `mxupper` (zones 0 to 2, 168 rows), `mxmiddle` (zone 3, 106) and `mxlower` (zone 4, 105): the mechanisms, built the
  way Matrix 11 builds its own. A door is an `Env_Countdown_Gate` row (a copy of `DLC02_20_EnvS_076`) whose actor is an
  empty arrow (`BP_Env_Empty_Arrow_C`) at the spawn point of its own name; its four LevelSequences
  in `/Game/MXIII_Editor/Seq` (ToOpen as the Close state's OutTransit, ToClose as the Open state's, Closed and Opened as
  the two Active ones, KeepState) move the cooked leaf and the hidden doorway blockers, as Matrix 11's `ME_04_EnvS_030`
  moves its door. 34 doors start in the Open state and have no opener row, so EVE walks through them and presses
  nothing (14 of them are arena doors, below). Twelve start closed: eleven doors and the Z2P07 grille. Nine are shortcut doors opened from one side: zone
  1's R12 door and zone 4's D2, D3, D5, D7, drive room door, Z4P07 lift door, I3 walkway door and outfall grate door.
  The zone 4 control room door opens once E10 is dead, and the car 9 airlock's inner door opens from its panels. The
  airlock's outer door and the zone 3 pressure door start open and close by mechanism (below). A
  shortcut door's opener (`Env_EnvState_2Phase` with the graph `ME_Area01_ShotCutDoor`, a copy of `ME_01_EnvS_026`)
  fires, from its On state, the ZoneEvent row whose EventEnvControlTable row of the same name sets the door Open; the
  locked side has the `_Opposite` graph, which only says it cannot be opened from there. Zone 2's one-way doors 050
  and 037 keep their shipped rows (graph `MT20_ShortCutDoor01`); new rows `DLC02_20_EnvS_934` and `_935` show the
  notice on the locked side of 051 and 037, and 050 and 037 disable them from their On state. In the cook copy each of
  these twelve leaves carries Matrix 11's lock box (`Interaction/Door/004_C_SM` at scale 0.7, 112 cm over the floor;
  on the drive room door and on D2, D3, D5 and D7 it sits on the bar that rises 150 cm during the first second of the swing), and the opener's spawn point is where
  Matrix 11's `ME_Area01_ShotCutDoor_C` puts EVE relative to its box, so her hand lands on it. Zone 2's lattice gates
  077, 078, 079, 081, 082 and 083 lead only to scenery: no prompt, disabled at the start, shut for good. The switches
  of zone 1's doors 438 and 439, the shutter switches 432, 446 and 447, the ladder gate switch 434, the R29 gate's switches 001 and 601, the
  Z2P07 grille switch 937 and the sockets 027 and 038 spawn `Env_CardControl_Switch_Wireless_C`: the Off/On code of `Env_CardControl_Switch2_C` on
  the `003_E_SM` box of the zone 2 switches (Switch2's `003_D_SM` has a second piece 4 m up). Their spawn points sit
  on a wall beside the door, root 115 cm over the floor, with EVE 60 cm in front of the box.
  The Z2P07 grille (`DLC02_20_EnvS_936`, a copy of `DLC02_20_EnvS_076`) is such a gate: switch 937 in the manhole room
  fires `DLC02_20_E_EnvC_936` 1.5 s after the press, the grille rises 255 cm in 4 s and pickup `DLC02_20_E_ItemS_023`
  (2DQuantumWafer x1) lies in the pipe behind it.
  Switch gates and approach gates keep their shipped rows and switch chains with our sequences. Lifts are their shipped
  `Env_Lift` rows with our sequences per Wait state. A cab panel's graph holds EVE for a fixed time after her press
  (`WLA30_Lift` and `MT40_Lift`: the ride starts 1.5 s after the press animation, she moves again 11 s into the ride and
  the panel comes back 1.5 s later), so the ride has to end when that time does. The surface lift 431 and the train lift
  R13 (row 621) ride for 6 to 7 s and take Drowned Eidos's rooftop lift graph `DED02_RooftopLift` instead: the ride
  starts with the press and she moves again 7.25 s into it. Call switches (`MT20_DoorSwitch01` rows) send the cab to
  their landing from either of their states; the zone 4 lift I3's two call switches start enabled, since their shipped
  enabler, row `DLC02_40_EnvS_017`, has no actor in the map. Arenas use SE_08's pattern: a fight (EventOnBattle of a
  spawn row) shuts the doors, each EventOnDead adds 1 to an `Env_<N>CountProgress` row (an
  EnvC of type StateProgress), and its On state opens the doors again; the Stalker's and the Lion's own deaths open
  theirs. The Lion shuts its fan door and gate D7 on battle (D7 through `DLC02_40_E_EnvC_630` and the
  `MX13_DLC02_40_EnvS_611_ToClose` sequence) and opens both on its death. Its death also enables the fan levers 023 to
  025 (`DLC02_40_E_EnvC_631` to `633`), which start disabled. The fallback Lion of `coop mxiii boss` has no spawn row and
  so no EventOnDead: `boss.lua` fires the same three events with `CreateSBZoneEvent` kind 10 when it reads that Lion dead
  [inference: never run in game]. A save whose Lion died on a build without these rows keeps its levers disabled and
  needs a new run. `matrix13/world/fans.lua` holds each cooked rotor's
  RotatingMovementComponent off until that fan's lever reads On, so the fans stand still from arrival without a cook
  change. Lever 023's On also fires scene 4G. The counters, the zone 2 wave triggers, the
  14 zone 3 and fan room arena doors and every opener a lock disables (D7's) are `ResetZone` (2), as SE_08's counter
  `SE_08_EnvS_090` is: if EVE dies in an arena, the zone reset puts them back, the arena doors to their Open start, the
  other doors keep their saved state, and the next fight locks them again (that a death
  resets ResetZone rows and keeps Save rows is not traced). The zone 2 waves moved to new triggers 601 to 603
  (the cooked boxes inside each arena doorway), which also shut the arena gate behind EVE but leave switches 005, 007
  and 009 alone; triggers 001, 005 and 006 go back to their shipped rows. Zone 3's trigger 601 shuts the pressure door
  behind EVE for good. Zone 1's shutter 429 (the two 015_B leaves between R02 and R03) starts down and rises when EVE
  uses switch `DLC02_10_EnvS_447` on the R02 side of the pillar between them, a copy of switch 432, which opens
  shutter 433 the same way; the shipped foot switch row 430 is an `Env_Lift` with a level-placed foothold, which the
  map does not have. The car 9 airlock's panel inside toggles two states:
  one shuts the outer door and opens the inner one 3.5 s later, the other does the reverse, and a call panel outside
  each door sets the state that opens its own door. Zone 4's water device keeps its shipped P1, P2 and P3 states with
  our sequences, driven by its drain and pipe panels (`ME_Area04_2Phase`), with two toxic effect volumes. An enable-only
  EnvC row has TagName None, as 100 shipped rows do. Every new name and ID is free in the dumps, and every event a row
  fires resolves to a ZoneEvent row of the data or of the game.

The 72 warp switches of the first full build are gone (Matrix 11 has none): their rows went with the `mxwarp` batch,
and their spawn points in the cooked map stay empty. `coop mxiii warp` lists the 72 arrival points they led to
(`DLC02_<zone>_WarpPoint_<n>`, kept in the cooked map and in `matrix13/world/rows.lua`'s WARP list), and `coop mxiii
warp <n|name>` puts EVE on one with `K2_TeleportTo`, under the follow's guards (solo, a co-op save, no travel under way)
and in world 2800 only, as a test fallback.

At the title, once the `mxiii=` line has an answer, `matrix13/world/travel.lua` asks the others one at a time, each once
the batch before it has an answer (rows, or a refusal, which never holds the next one back): `mxspawn`, `mxenv`,
`mxupper`, `mxmiddle`, `mxlower`, then the `lion` and `gardener` batches, whose CharacterTable rows `M_LionC` and
`M_Gardener` the boss spawn rows name, and last `mxnames` ([below](#the-camp-names)). All go in before any save loads,
since the zone manager lists a world's rows when the world starts. `coop mxiii` asks no travel until every one of these
lines but `mxnames` reads `rows`, and names the first batch that does not: the travel would reach a dungeon without its
Naytibas or its doors, and a peer's shared Naytibas would match no spawn row.

In world 2800, `matrix13/world/drone.lua` gives the drone's spot light 20 % more range and cone at the same intensity: a
post hook on `CH_Drone_BP_C:ReceiveTick` scales the radius the blueprint writes each tick, and the cone goes back to
30/40 degrees on leaving the world.

In world 2800, `matrix13/world/travel.lua`'s tick runs two more files. `matrix13/world/move.lua` spawns, once a world,
SB's `BP_EM_Ladder_C` at 41 ladders (the 37 of the map, the three fan room walls and ladder gate 435's lowered ladder),
`BP_EM_Ledge_C` at the three R16 ledges, the shimmy and an exit ledge on the counterweight's east face (its south end
hangs over catwalk S1, so a drop from there lands on the catwalk), and `Env_EM_VerticalRope_C` at the R28 and zone 4 ropes. A
ladder's height comes from its `Meshes` stack (enum `Enum_EM_LadderMeshes`: 160.9, 200, 240, 600 or 40.9 cm pieces) plus
the 79.885 cm head. Its construction script stacks the pieces up from the actor's origin, starting at the actor's
`TotalHeight` and adding each piece to it, so the mod leaves `TotalHeight` at its class default 0: written before the
finish, it lifted every ladder by its own height. `tools/mxiii_climb.py` takes each map ladder's stack, foot and rung
line from the editor's proxy ladder (`data/mxiii-climb.json`), its -X toward the upper landing, and checks that the
pieces, rebuilt as the script builds them, lie within 2 cm of the proxies; it checks the ledges and ropes against their
editor ledges and markers the same way. At the top EVE steps off onto the floor a trace from 25 cm over the stack's top
to 25 cm under it finds at x -60, else into the air. The editor's stacks miss that at 20 ladders: 17 tops stand 23 to
100 cm over their landing, R11_R08's and Z3P08's 78 and 60 cm under their deck, and Z4_L1's foot floats 24 cm over its
floor. Those ladders get the stack and foot that put the landing within 20 cm of the top and the foot on its floor, with
the rungs nearest the editor's, and match the proxies on the rail line only. A ledge gets the
climbing mesh `006_B_SM`. A rope gets its drop (`RopeDistanceB`) and the `EnvActorName` of its row (R28's
`DLC02_10_EnvS_642`, zone 4's `DLC02_40_EnvS_022`), which its winch turns On; gate 435's ladder gets
`DLC02_10_EnvS_437`, the row the gate's lever turns On. Whether an SBZoneEnvActor spawned after its zone's rows were
made registers with its row is untested. A cooked map never reruns a placed actor's construction script, so these values
must reach the actor at spawn. The spawn is deferred (`BeginDeferredActorSpawnFromClass`, the fields,
`FinishSpawningActor`); if that call fails, `SpawnActor` and a second `UserConstructionScript` call take over for the
rest of the Lua load. UE4SS 3.0.1 grows a TArray written two or more past its end to the index before and loses the
value (its TArray fix, #436, came in 4.0): filled from its last piece, every multi-piece stack read back one piece
short in game (R28's 3,3 as 3). The `Meshes` stack now gets its first piece, then a write one past its last piece
that only sizes the array, then every piece inside it. It is read back; a stack that differs is emptied and written
front to back, and one that still differs is destroyed before its finish and named in the log. Each spawn logs an `[MX] [MXMOVE]` line, a ladder's with its stack as read back
before `FinishSpawningActor` and the `TotalHeight` its script built. `matrix13/world/boss.lua` looks, once a second
while EVE is within 80 m of a boss point, for a body of the Lion's or the Gardener's blueprint within 30 m of it, and
fixes it once: the Lion through `cut/lion.lua`'s `adopt` (its anim instance, else the hidden Behemoth leader that `coop
lion` uses), the Gardener's mesh turned -90 degrees. While one lives, the boss bar shows its name. EVE standing 20 s
within 25 m of a boss point with no body there gets one `[MXBOSS]` line naming `coop mxiii boss`, which spawns that
arena's boss through `coop lion` or `coop gardener fight` (key 0, no saved death). It never runs by itself: a boss
killed before stays dead through its row's SaveType, and an automatic spawn would bring it back at each visit.

The same tick runs `matrix13/world/breakables.lua`. The cooked map has 316 StaticMeshActors tagged `MXIII_BREAK` in
`MXIII_Z0_Surface` and `MXIII_Z1_Life` to `MXIII_Z4_Life`. They are proxies and cannot be broken. The shipped levels
place `BP_Destruction_Box_01`, `BP_Destruction_Box_02` and `BP_Barrel_01_Child` actors, and no table row spawns them.
Once a world, the mod spawns one of these actors at each of the 317 points of the `break` list in
`data/mxiii-world.json` (`R.BREAK` in `matrix13/world/rows.lua`). The deferred spawn is the same as the ladders'. The
row alias follows Matrix 11: `ME_01_ZEA_003` on a Box_01, `ME_01_ZEA_007` on a Plus Box_01 and on every Box_02, and
`ME_01_ZEA_001` on a barrel, which explodes 2.0 to 2.5 s after it is hit and drops nothing. No save type is written,
because a spawned actor's name changes from load to load. The boxes come back at each world load. One
`FindAllOf('StaticMeshActor')` pass per world finds the proxies by name. Each proxy loses its collision and is hidden
before its actor spawns, and gets both back if the spawn fails. A proxy that is not found means no spawn at that
point. The R23 box in front of `DLC02_10_E_ItemS_015` has no cooked proxy and spawns alone. It stands in the way of
that pickup until it is broken. The list spawns 40 entries per tick, and the Z4R21 Box_02 spawns before the Box_01
that rests on it. Only the world's address decides a new spawn, since a broken box destroys itself. Each entry writes
one `[MX] [MXBREAK]` line, and a total line follows the last one. Each PC spawns its own boxes, so a box broken on one
PC stays whole on the other. Whether a ZoneEventActor spawned after its level loaded registers with its row and breaks
is untested.

The export check (`save/twins.h`) refuses a co-op save holding any FString that starts with `DLC02_` outside the camp
fields it already reads (names that start with `Zone_DLC02_` excepted, every save holds them). None of the user's 15
released-game saves holds one; a save that played the dungeon keeps its zones' rows for good, so it can never be
exported.

## The camp names

The camps have names of their own in French and English, and every other language shows the English. The region's key
is `MX13_Region`, and a camp's is `MX13_Camp_<row>`:

| Row | French | English |
| --- | --- | --- |
| `MX13_Region` | Matrice 13 | Matrix 13 |
| `DLC02_00_Camp_00` | Matrice 13 | Matrix 13 |
| `DLC02_10_Camp_01` | Tête d'ascenseur | Lift Head |
| `DLC02_10_Camp_02` | Bureau du chef de gare | Station Master's Office |
| `DLC02_20_Camp_01` | Sas de la voiture 9 | Car 9 Airlock |
| `DLC02_20_Camp_02` | Voies de garage | Sidings |
| `DLC02_20_Camp_03` | Hall de l'ascenseur | Lift Hall |
| `DLC02_20_Camp_04` | Salle des signaux | Signal Room |
| `DLC02_30_Camp_01` | Première halte | First Rest Stop |
| `DLC02_30_Camp_02` | Deuxième halte | Second Rest Stop |
| `DLC02_30_Camp_03` | Puits de pompage | Pump Shaft |
| `DLC02_40_Camp_01` | Salle des pompes | Pump Hall |

The rows hold keys of `StringTable_UI`, so the names go in two steps, in this order:

1. `game/camp_text.h` and `glue/tick/camp_text_game.inc` add the 12 entries to the live table from `coop_tick`. Each 250
   ms, at the title and with coop off too, the game thread reads the culture and, while a pass is due, looks for the
   table. It waits until the table's loaded byte is set: the table is registered in its constructor, and `Serialize`
   empties it later. `coop-status.txt` then goes from `camptext=wait` to `camptext=ready`.
2. `matrix13/world/travel.lua` asks `mxnames` at the title once `gardener=` has an answer and the line reads
   `camptext=ready`. The batch is 11 rows that name themselves as donor: the existing in-place form, with the same
   IDs, applied to rows the `mxiii` batch added. It writes `CampName` (`+0x18`) and `RegionName` (`+0x34`) and no other field, on the Tetrapod row
   `DLC02_00_Camp_00` too, which keeps Region `Matrix11` ([above](#its-rows)).

The order is there because of what this build does with a key it cannot find: `FUN_142879140` shows `<key>`. A row names
a key only after its entry exists, so this path cannot show `<key>`. If the pass faults (`camptext=fault`, with a `camp
names off` line in the log) or the table never loads at the title, `mxnames` is never asked, the rows keep their donors'
keys and show the donors' names. `coop mxiii` does not wait for this batch, so the travel works either way.

This build has no `FStringTable::SetSourceString`, and `ImportStrings` clears the table first, so the pass makes each
entry with the out of line calls `ImportStrings` makes (`14285a4f2`-`14285a643`), under the table's lock. The first fault
latches the passes off for the run; the handler lets go of the locks the mod's code took. `FUN_14287d320` overrides an
existing display string only under the culture `ko`, so on a language change the pass assigns the display string and
the source directly, under the manager's lock. Saves hold the camp's alias and are not touched: only rows in memory
and the live table change.

All of this comes from reading build 24463856's code and has not run in game. The first run has to show
`camptext=ready` at the title in a French and an English boot, `mxnames=rows`, the names on the TeleportCamp title,
`WB_TeleportSlot`, `WB_Teleport_Preview`, `WB_AreaTeleport_Tab` and the load slot, and no fault over two boots and a
return to the title.

## The records

The dungeon's 25 records (7 memorysticks, 18 documents) use the path of the game's own: an env row that reaches state
`CallPuzzle` when EVE reads it completes an unlock achievement, and the Data Bank row on that achievement opens. The
cooked map already holds a spawn point named after each env row (`DLC02_00_EnvS_950`, `DLC02_10_EnvS_950` to `957`, and
so on) and the prop EVE looks at, so the map does not change.

`mxrecords` is 100 rows, 25 in each of four tables, in this order so that no row names a later one:

| Table | Rows | Copies | What it sets |
| --- | --- | --- | --- |
| PuzzleStringArrayTable | `Records_MX13_<id>` | `DED10_EnvS_Corpse05` | The reader's title and text keys |
| AchievementTable | `Ach_Album_Unlock_MX13_<id>`, 280900 to 280924 | `Ach_Album_Unlock_Item_Records_ME01_Memory_01` | The env row in `ParamValue1`. Its three trophy links are None, so no record reaches `Trophy_Acquire_AllRecords` |
| AlbumTable | `Records_MX13_<id>`, 10700 to 10724 | one shipped record of each group | Name, text and unlock. No popup: reading already shows the text |
| ZoneEnvSpawnTable | the env rows | `DED10_EnvS_168` for memorysticks, `SE_06_EnvS_076` for documents | `BP_Env_Empty_Arrow` at the spawn point, and the puzzle row. The memorysticks also clear their donor's reward (`Legion_Drown` on state On), so reading a record gives nothing |

The memorysticks form a new group named by `MX13_Region`, the camp names' "Matrix 13" / "Matrice 13" entry. The documents
join the shipped Messages (5), Announcements (5) and Log Data (8) groups.

The words go the way of the camp names: the same pass adds 50 entries from `game/record_text.h` to
`StringTable_Records`, again whenever a table no longer holds its first entry (a table only a Lua LoadAsset held may be
collected and loaded again without ours [inference]), and `coop-status.txt` goes from `recordtext=wait` to `recordtext=ready`. The batch waits for that
line and for `camptext=ready`, and `travel.lua` loads the string table once if nothing else has. Like the other batches
it goes in at the title only while the game uses the co-op save files and the test pak is there, and `coop mxiii` does
not wait for it. The entries reach every player's live table but no row outside the batch names them.

The save keeps the unlocks and red dots by alias, so `coop saves export` refuses a save that holds one
([saves.md](../saves.md#co-op-saves)), and these aliases must never change. Rows the title batch added stay until the game
exits: after `coop saves main` at the title, your own save's Data Bank would list them locked until a restart, as with
every row of this batch family.

Not run in game. The first run has to show `mxrecords=rows added=100/100`, the prompt at each of the 25 spots, the
reader's text with its line breaks, the tile opening with the group counter, no Steam popup, and the tile still open
after a reload. Whether the achievement system fires for rows added at the title and whether `BP_Env_Empty_Arrow` shows a
reading prompt are [inference].

## Open questions

- whether the native gate opens at the title of a fresh game ([At the title](#at-the-title)), and what a co-op save
  that names a mod camp does when the rows are not in;
- whether the game loads `MXIII_P` from a mod container, and whether it accepts retoc's zen output of a renamed map;
- whether `FSBGameWorld::Init` runs at each map load, and whether `FUN_141d18100` lists the camps of every world;
- whether the camp arrival (`FUN_141a8afe0`) finds the spawn points named `DLC02_00_Camp_00`, `DLC02_10_Camp_01` and
  `DLC02_30_Camp_01` in the test map, whether a floor coin spawns in any zone of the map, whether the `mxlily` patch
  opens Lily's menu and leaves the Great Desert Lily as she was, and whether a death in the third or fourth zone brings EVE back to the second camp;
- whether camp blueprints spawned through `EnvBPPath` work as placed ones do (their `CampRespawnActor` is unset; the
  base has no kit attached to its capsule, and its meshes stand on the cook's copies of the same meshes at the five
  full camps until a pak drops those), and
  whether the camp list shows the camp once the vending machine has activated it: the list takes a camp with a row
  whose active state is Active ([Following the host](group-play.md#following-the-host)), and whether the vending machine's graph
  sets that on the mod's rows was read from the interaction graphs, not run;
- what the world map, the region name and the loading screen do with a world that has no map data;
- what entering `Zone_DLC02_10` writes into the save. Its 15 spawn rows are `EnterZone` rows, so 14 Antlions and a
  data drone should appear;
- whether the five patched trigger rows start the waves of `Zone_DLC02_20` and the chains of `Zone_DLC02_40`, and
  whether EVE can reach those zones on the test map at all.
