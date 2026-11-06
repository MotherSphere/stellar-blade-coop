# Cut menus and the mailbox: how they work

The commands are in [Cut scenes and menus](../cut-scenes-and-menus.md).

## The cut Load Shortcut menu

`coop shortcut` (`save/shortcut.h`, `glue/tick/shortcut_game.inc`, not tested in game yet) lists the saves of a cut
chapter loader. What the pinned build keeps of it:

- The title screen's widget `WB_Lobby_Menu_Set` has a `WB_Lobby_Menu_Btn_ShortCut` button, collapsed, whose text key
  `UI_Lobby_ShortCut` is in no string table. The lobby's set-up (`FUN_141ef0e70`) gives a click handler to 14 named
  buttons, and this one is not among them.
- The `ShortcutGame` menu (UI logic 130, constructor `FUN_141f5efd0`) lists slots 1 to 4 of one map, the one the
  constant `ShortCutMapPath` names (`FUN_141f60140`). `FUN_1422907c0` builds each path as `"%s%s%s/%s%02d.sav"`
  (`FUN_142324b70`: the project's content folder, `ShortCutRootFolderPath`, the map, `ShortCut`, the slot), reads the
  file the way `FFileHelper::LoadFileToArray` does, turns it into a save object and keeps a few fields of it for the
  slot.
- The menu's Accept branch (`FUN_141f5f9b0`) copies the chosen slot, calls `GetBestSaveSlotNum` (`0x142290b50`) and
  drops its result, then asks for the lobby's UI logic and drops that too: the load itself was compiled out. The
  cheats `SBLoadFromShortcut` and `SBLoadShortcutData` read their parameters and return.
- The paks hold 15 such saves under `SB/Content/System/Waypoint/`: B07 4, F02 3, G03 4 and Matrix_XI 4. G03's slots
  2 to 4 are byte for byte F02's 1 to 3.

The list makes the menu's own calls, on the game thread, one file a frame, under its own SEH latch. It reads the file
manager object that `IFileManager::Get()` (`FUN_142820e70`) returns, a function-local static at `0x14710a7a8`, and
checks its vtable (`0x145f5c9a0`). It calls `CreateFileReader` at vtable `+0x18` (`FUN_142811eb0`) with the path
`../../../SB/Content/System/Waypoint/<map>/ShortCut0<n>.sav` and flags 0, so a missing file returns null instead of a
fatal error. On the reader it checks the vtable (`FArchiveFileReaderGeneric`, `0x145f5bc60`), then calls `TotalSize`
(`+0x30`), `Serialize` into a buffer of ours (`+0x150`), `Close` (`+0x1b8`, false after a read error) and the deleting
destructor (`+0`). The bytes go to `shortcut::parse()` and are then dropped. It reads the GVAS header's engine branch,
`MapName` and `CampAlias` in the map property `DataMap_FString`, and `DateTime` in `DataMap_int64`, each searched only
within its own map's bytes. An EVAS header is stripped first when there is one, as the game's slot loader does.
Nothing is written. The worker logs a line per file and a summary, which reaches `UE4SS.log` as the status's `last=`
line. A fault ends `coop shortcut` for the run.

### Loading one

`coop shortcut load <map> <1-4>` (`save/shortcut_load.h`, `Convert::plant` in `save/twins.h`, not tested in game yet)
writes one of the 15 files, cleaned, as co-op slot 5 (`StellarBladeCoop04.sav`). The player then loads it with the
game's own Load Game. It is refused unless `coop-settings.txt` has `shortcut_load=on` (off by default), and
`commands/cut.lua` sends the request only when the same words come twice within 10 s.

What the files are, against a save of the released game (2026-10-26):

- Format. The files are bare GVAS, with no EVAS header and no CRC. Eleven come from UE 4.26 (package version 522) and
  Matrix_XI's four from 4.25 (518), against 525 for the released game's saves. Their dates run from March 2021 to July
  2022. The game's slot loader (`FUN_141cd5e10`) hands the bytes to the engine's `LoadGameFromMemory`
  (`FUN_1441fbbc0`), which reads a save with the package and custom versions its own header names, and its account
  check (`FUN_1421d1390`) passes a save with no `OnlineAccountInfo`.
- Missing fields. None of the 15 has `NewGameCreateTime`, `LevelActorStorage`, `UIStorage`, `EventGiftInfo`,
  `NikkeStageInfo`, `SaveFileVersionInfo`, `OnlineAccountInfo` or a `GameDifficulty`, and only G03 1 has
  `GamePlayProgressRecordData`. The game creates the save object before it reads the properties, so a missing one
  keeps its default.
- Content the game no longer has. Six of the 12 distinct files hold items with no `ItemTable` row in their inventory:
  `BS_Attacker`, `BS_Defender`, `Buff_HP2MP` and `Gear_NarrowVision_Rare` (Matrix_XI 1 to 4),
  `DesignPattern_Blue_Suit`, `DesignPattern_Sailor_Jean` and `DesignPattern_Black_Leather_bikini` (F02 2 and 3).
  `DataMap_SBActor`'s `PlayerActor` names some of them too. In Matrix_XI 1 to 4, EVE wears `BS_Defender`: its
  `Equipment` entry for slot 5 points at that inventory element by `SavedGuid` and `PocketGuid`, and
  `BodySuitSlotArray` names it. Matrix_XI 2 to 4 have `Buff_HP2MP` in `ItemQuickSlotArray`. `BodySuitSlotArray` names
  `BS_Attacker` in all 12, as it does in the released game's own saves. Names such as `betacrystal` or `PT_crowd`
  differ from their row only in case, which an FName ignores. Matrix_XI 1 has three quests with no
  `QuestTable` row (`SQ_ME_KillTumblerDrone`, `SQ_ME01_GetFusionCell01` and `02`), and F02 1 and 2 name task groups
  in an older form (`CQ_DED01_KillTumblerDrone_T01`).
- Achievements. Every file but Matrix_XI 1 has a top-level `SBAchievement` struct: its `AchievementList` holds
  `{AchievementAlias, ProgressValue, bCompleted, bRecievedReward}` entries. F02 2 holds `DED_Opener_KillCharacter`,
  `DED_GrubShooter_KillCharacter` and `DED_Gigas_KillCharacter` as done, which are trophies 3, 4 and 5 in
  `TrophyTable`. F02 3 holds those and `ME_Stalker_KillCharacter`, `ME_Juggernaut_KillCharacter` and
  `ME_Tachy_KillCharacter` (trophies 8, 9 and 10), with progress toward trophies 28 to 31 and 43. G03 3 and 4 are the
  same files. No achievement name appears anywhere else in the 15 files.

The game runs nine fix-up passes on a loaded save (`FUN_1421def10`, reached through no direct call, with the save
object as its second argument). `SBAchievement` is the save object's `+0x2c8` (the `USBSaveGame` layout of a
Dumper-7 SDK of the game), and each pass reads these fields:

| Pass | Reads | Writes |
| --- | --- | --- |
| `FUN_1421defb0` | `SBAchievement`: its `Ach_Album_Unlock_*` entries | the count of them into the `Trophy_KillCharacter_AllNative` entry, when the list has one |
| `FUN_1421e1ff0` | `SBAchievement`: `Trophy_KillCharacter_AllNative` | an achievement event for it (the pool `FUN_1421f1920`, the list at the manager's `+0x50`, when its `+0xe0` is 1): the path to Steam |
| `FUN_1421e21f0` | `SBAchievement`: `Trophy_WeaponMaxUpgrade`; `DataMap_SBActor`'s `PlayerActor` | `PlayerActor`'s weapon level |
| `FUN_1421e2650` | `DataMap_SBQuest`'s `Quest_Epic_Hidden` (M05 to M07); `DataMap_SBEnv` objects of `Zone_DED40` | a stuck DED40 object's position |
| `FUN_1421e31f0` | `DataMap_SBEnv`'s `DED20_E_EnvC_002` and `DED20_EnvS_250` | their On or Off state |
| `FUN_1421e3860` | `SBAchievement`: one completed entry; `DataMap_SBEnv` objects of ME_03 | a Matrix 11 object's state (`OpenMode_Burst`, `ToOpen`, `Closed`) |
| `FUN_1421e41e0` | `DataMap_SBItem`'s `Item` inventory: six gears; `SBAchievement`: `Kill_Character_*`, `ChangeState_*` and record entries | completed `Ach_BossChal_Unlock_*` entries added to `SBAchievement` |
| `FUN_1421e5e60` | `DataMap_int32` (a New Game+ count), `NewGamePlusBaseData`, two `_MK2` gears in the inventory, `SBAchievement`'s `Nest_Ending` | `NewGamePlusBaseData` |
| `FUN_1421e62b0` | `DataMap_SBActor`'s `PlayerActor`; `DataMap_SBEnv`'s `SE_06_EnvS_071`, `SE_07_EnvS_001` and `SE_07_EnvS_076` | `PlayerActor` |

So only `FUN_1421e1ff0` turns save data into an achievement event, only from the achievement list, and only
`FUN_1421e41e0` makes achievement data from anything else: from six gears in the inventory
(`Gear_HighHpDamageAdditiveRate_Common`, `Gear_KillEnemyAdditiveDamageRate_Common` and `_Uncommon`,
`Gear_GainBurstGaugeValueOnDamaged_Common` and `_Uncommon`, `Gear_AdditiveGiveAndReciveDamageRate_Rare`), none of
which the 15 files hold. The game's save builder (`FUN_1421d3ec0`) copies the running achievement container into
`+0x2c8` when it saves, which is the same list in the other direction.

`shortcut::clean()` therefore:

1. Takes only the 15 files of the pinned build's paks, by their CRC-32 (12 distinct values, in `kPinned`). Any other
   bytes are refused.
2. Walks the GVAS body's top-level tags (each tag's name, type, size, index and type-specific header, its value
   skipped by its size) and drops the `SBAchievement` property whole. The save object then starts with an empty list,
   so the passes that read it find nothing.
3. Rebuilds `DataMap_SBItem`: in each entry's struct, the `Inventory` array loses the elements whose `ItemAlias` or
   `ItemInstance.ItemAlias` names one of the six gears (case ignored), and the `ItemOtaineSet` set loses the same
   names. The array's count, its inner tag's size and the sizes of `Inventory`, `ItemOtaineSet` and `DataMap_SBItem`
   are set to the new lengths. Everything else is copied byte for byte, the GVAS header included. None of the 15
   files holds a gear, so for them this step changes nothing. The seven items with no `ItemTable` row stay as saved:
   removing their inventory elements would leave EVE's suit in Matrix_XI pointing at an element that no longer
   exists.
4. Wraps the body as the game's save writer wraps its own (`FSBSaveSystemWindows::OnCompleteSerialize`,
   `FUN_1421f5de0`): `EVAS`, the version byte 1, three bytes the writer leaves unset (0 here, as in most real saves;
   one real save seen holds `47 61 3e`), the body, then its CRC-32 (`FUN_1428dbbd0`, zlib's) in little endian.
   The game's validity check (`FUN_1421f4e00`) compares that CRC.
5. Checks the result before it is written: the game's own check (EVAS, version 1, CRC), a body of class
   `/Script/SB.SBSaveGame` whose tags all fit and end in `None` with the 4 trailing bytes, no `SBAchievement`, a
   `DataMap_SBItem` that parses, and none of the six gears anywhere in the body (any whole string, case ignored). A
   save that names a gear outside the inventory, in `PlayerActor`'s equipment or quick slots, is refused.

`tests/native/save/shortcut_load_test.cpp` cleans the 15 files themselves when the machine holds the research copies:
each passes that check, holds none of the strings `Achievement`, `Trophy` or `Ach_`, and is the file without its
`SBAchievement` bytes, byte for byte. Against the table's dump, the only inventory items with no `ItemTable` row are
the seven above. A parse of the 15 results with `tools/gvas.py` (EVAS, CRC, header and every property, 2026-10-27)
read them whole.

The write is a co-op saves pass (`Switch::plant`), refused unless the game uses the co-op copies (`saves=coop`), the
title is shown with no save loaded and no load asked (client `+0x86c` is 0), the Steam account is known and no other
pass runs. The game thread reads the file through the file manager as the list does and keeps its bytes; the worker
cleans them; the pass backs up the current `StellarBladeCoop04.sav` into a new folder of `StellarCoopBackups` (the
whole backup of a first conversion when there is no manifest), writes the mark `StellarCoopShortcut04.txt`, then the
cleaned save beside the copy as `.coop-tmp`, renames it over the copy and reads it back. The manifest then has no line
for slot 4, so later passes count it as played and keep it. `saves export` refuses slot 4 while the mark is there,
and only a later copy of the player's own save into slot 4 removes it. Every write goes through the co-op saves' name
check, and the player's own `StellarBladeSave0N.sav` files are only read, by the backup.

The load is the game's own Load Game. Picking the fifth slot stores the slot at client `+0x868` (`FUN_141eee190`)
and starts the lobby's fade; the start of play (`FUN_141cd6890`, run by the client's start-step queue in
`FUN_141ccbb30`) then calls `FUN_141cd5e10(client, slot, 0, ...)`, which reads `StellarBladeCoop04.sav` through the
save system, strips the EVAS header, loads it (`FUN_1441fbbc0`), checks its class and account, and applies it
(`FUN_141cd7480`). The mod does not call `FUN_141cd5e10` itself: the game calls it as one step of that start
sequence, after the fade, the level travel and the prep calls `FUN_141cd6890` makes first, and none of that can be
tested without the game. The title's slot list is not rebuilt, so the fifth slot may show the old copy's details;
the file is read when the slot is picked.

What the cleaning does not cover:

- The developer's progress stays: quests, zone objects, skills (`DataMap_SBAcquisitionSkill`), items, camps and
  `GamePlayProgressRecordData` in G03 1. The game counts collection achievements from events as the player adds to
  them, and whether any of those counts read the save's contents again was not traced. A load can therefore still
  unlock a Steam achievement during play, and a Steam achievement cannot be taken back. That is why the command is
  off by default, and why [Cut scenes and menus](../cut-scenes-and-menus.md#loading-one-coop-shortcut-load) says to try it only on a Steam account
  whose achievements do not matter, with Steam Cloud off.
- The seven items with no `ItemTable` row stay in the inventory, in `PlayerActor`'s equipment and in its slot lists,
  where the developer left them. How the game loads an equipped or held item with no row was not traced. Some of its
  item code checks for a missing row and logs it (`FSBUILogicReward::AddItem`, `FUN_141f36090`: `Failed to find
  ItemTableProperty`). Matrix_XI 1 to 4 and F02 2 and 3 are the files that hold them.
- The quests and task groups with no row stay in `DataMap_SBQuest`; what the game does with them was not traced.
- Nothing was tried in game, so whether these old saves load at all, and where they start, is untested.

The lobby's ShortCut button stays hidden: its menu's load call was compiled out, and this command does not use it.

## Developer menu and panels

The game ships its developer cheat menu as assets only. The UI definition `/Game/Art/UI/Definition/DebugCommand` names
`WB_DebugCommand_Master` with `ESBUILogicType_DebugCommand` (191), and the widget is a plain `SBUserWidget` whose list
and buttons a native UI logic would fill. SB registers one prototype logic per type at startup (the static initializers
that call `0x141fc33a0`); the open path (`0x141fc4aa0`, through `0x141fc4d20`) clones the prototype of the type asked
(`0x141fc3220`). Of the 220 initializers, 218 resolve to a type through the getter at their vtable's `+0x10` (`mov eax,
<type>`), and 191 is not among them, nor are the other debug panels (DebugViewer 193, HUDRealTimeDebug 194, the sound
debuggers 195 and 196, FishingDebugger 49, BossChallengeDebugInfo 240). HUDQuestDebugger (51), DebugToastMessage (230)
and DebugPlayerInfo (232) are.

Each `CheatCommandTable` row is a console command for `USBCheatManager`. The class's native function table
(`0x145dbc690`, 703 name and thunk pairs) points to 111 distinct thunks, and every thunk but one calls only the
parameter readers (`FFrame::Step` and its typed helpers, `FMemory::Free`, the FString copy): the bodies are compiled
out. 267 names share the empty thunk `0x141167170`. The one with a body, `SBLoadingScreenFadeAuto` (`0x14269e260`),
is in no row. The 157 command words of the table include none with a body. The table's queue for game play progress
cheats (`0x141c94fb0`) runs its rows through `APlayerController::ConsoleCommand` (vtable `+0xcd0`), so they end in the
same stubs.

What still runs is the controller's `ServerRequest_Cheat`, whose logic job (`FSBCheat::Simulate`, `0x141b11800`) knows
`SBSuicide`, `SBPlayerRevival`, `SBPlayerSP`, `SBApplyEffectMe`, `SBLogPlayerLocation` and `SBPlayerMaxTachyGauge`.
The table uses three: `SBApplyEffectMe` in 82 rows (64 effects, 62 of them in the shipped EffectTable), `SBPlayerSP`
in 4 and `SBPlayerRevival` in 1. `coop devmenu` (`cut/devmenu.lua`) keeps 20 rows of 23 effects, which 35 table rows
call (Common 25, Battle 7, CombatTestMapMk2 2, System 1). Each is applied as the menu's rows would have been:
`ServerRequest_Cheat(<EVE's GUID>, 0, "SBApplyEffectMe", "<ID>")`, through `cut/chainspin.lua`'s one call
(`ChainSpin.apply`) after its checks (`ChainSpin.target`: `warp=idle`, `me=` not 0, EVE in the world, the
controller). The menu passes effect names, and the job reads a number, so the module reads the ID from the
EffectTable row of that name (`FindRow`) at each use. Effects on enemies use the test target filter
`TestEffect_Enemy_Target`, `clear` uses `TestEffect_All_Target`. The attack rows are `EffectOverlap_Overlap` (+4 or
+29 to `PhysicAttackPowerRate` and `ShieldAttackPowerRate` at each run), so they add up; the speed rows are
`EffectOverlap_Unique`. With shared enemies on, the attack rows' damage and the balance `enemybalance1` takes reach
the shared HP and balance like any hit, and so the friend's game; the other enemy rows act on the local copies only.

Both dispels (`Test_EffectDispelEnemy`, `Test_EffectDispelAll`) hand their targets `Test_EffectDispelAll_Effect`
(target `Self`, `DispelFlagsArray` `TestEffect`), which removes the `TestEffect` flag that every lasting row's effect
carries but `nolockswitch`'s (flag `LockOnDelivery`, which `lockswitch` removes). Their own `DispelFlagsArray`
(`TestEffect`, and `Groggy` for `clear`) most likely acts on the effect's owner, EVE: the game's
`P_Eve_Stance_GunTutorial_End` targets `Ally_Drone` yet lists EVE's stance flags, and hands the drone a child effect
of its own. So `enemyclear` probably ends EVE's lasting rows too, and no row removes the menu's
`Test_EnemyEffectGroggy` (its `Test_GroggyInfinite` on the enemies has flag `Groggy` and `EffectLifeType_Infinite`).
No effect has `bEnableSave`; that a save load ends them is expected, not checked. `coop off` calls the module's stop
before it asks the native part off, while the engine line still has `warp=` and `me=`: when a row reached the game in
this Lua load or an earlier one (`coop-devmenu.txt`, written at the first row and deleted by that stop), it runs
`clear` and `lockswitch` once more. That try goes through the same checks, so a warp under way skips it, and `clear`
reaches only the enemies near EVE then.

The rows left out: the enemy kills (`ImmediateDeath`) and the thirteen HP cuts (a lethal drop would credit our EVE,
see [Achievements](safety.md#achievements)), the TPS unlock (`ActorStatType_UnlockTPSMode`), the consumable stacks,
`FishingGod`, `SBPlayerSP`, EVE's death and revival, the test stances, `Test_MaxHPUpAll` and `Test_MaxShieldUpAll`
(all actors), and the five lasting effects no dispel row reaches (`NoDamageNoHitImmuneAbnormal_Infinite`, the two
`Test_Final*DamageReduce_080p`, `T_Drone_NoCoolScan` and `Test_EnemyEffectGroggy`).

`coop devinfo` (`game/dev_panels.h`, run by `glue/tick/debug_game.inc`) opens the two registered read-only panels
through the client's UI manager (`FSBUMGManager`, the client global `0x147032520` at `+0x48`). The quest debugger's
logic (vtable `0x145c31fc8`) builds its text in its tick (`0x141e99710`, the vtable's `+0x48`, which the manager's tick
`0x141fc5440` calls for each open UI) from the quest manager's quests, task groups and tasks, and sends it to the
widget as a `LogMessage` notification. The player info's logic (vtable `0x145c209e8`) sets `PlayerTagName: %s` from
the client's string at `+0xe0` once at its start (`0x141d854c0`). The cheats meant to show them
(`SBQuestDebuggerShow`, `SBHUDPlayerInfoDetailToggle`) are on the empty thunk. The calls copy SB's own: find
(`0x141fc51d0`, the open entry whose logic has that type), open (`0x141fc4aa0(manager, type, null, null, 0, &FString{},
0)`, as the client tick `0x141cd2e50` opens type 235) and close (`0x141fc5120(manager, type)`, the type read through
the virtual at `+0x38` of the entry's `+0x10`, as `0x141abe390` closes type 242). An open waits for part of the guard
the client tick checks before its own open: flow 2 at `+0xa00` and phase `0xe` at `+0xb9c`. The tick also needs
`+0xa21` not 1, not both `+0xb60` and `+0xb61`, the local player's `+0x25` at 3 (`0x141cff700`) and `0x141cf0580`
true; their meaning is unknown and the mod does not read them, so a panel may open where the game would not open its
own. Both panels are untested in game. The client is read from its global,
never through `0x141a978c0`, which allocates it. The worker hands the ask over with a number; the game thread takes it
with `try_lock` at its next frame, under its own SEH latch, and hands back the number, the panel, the reason for a
refusal and what it opened and closed. Lua's `coop off` asks `devinfo off` before `off`, and the game thread takes it
after the block too.

## Cut mailbox

`coop gift` (`cut/mailbox.lua`, not tested in game yet) carries consumables from one player's co-op save to the other's.

### Why the game's mailbox is not used

The mailbox's UI logic (`ESBUILogicType_MailBox`) is still compiled in, unlike the Load Shortcut menu's load call. Its
open (`FUN_141ef3850`) takes the mailbox object's alias from its init parameter, builds the list from
`MailBoxGiftTable` rows whose `EnableMailBoxEnvSpawnList` holds that alias, and marks a row received when its
`EventGiftAlias` is in the game data's received list (`+0x848`, its array at `+0x850`). Its confirm handler
(`FUN_141ef4db0`) calls `FUN_141cfd8e0`, which adds the gift's alias to that list, looks up its `EventGiftTable` row and
grants each item through `FUN_141cfde20`, a grant of its own that builds an item instance and queues an add. The save
struct has the same kind of list (`FSBSaveGameData_EventGiftInfo.GiftList`, an array of names), which is where the
received list most likely goes.

Feeding it would mean rows in two tables, a second grant path and a mod alias in the save's received list, so the mod
keeps its own list on disk and only shows the cut toast: `WidgetBlueprintLibrary::Create` with
`WB_MailBox_Toast_GetGift_C`, its `Text_Title` set, `AddToViewport` and its `Play` function. `Play` starts its `In`
animation, whose event track calls the widget's `Toast In Play Sound` (from the offline dump of the widget; what that
function plays is not read). The toast comes off after 4 s, and its first failure turns it off for the Lua load. The
widget has no removal of its own, so while it shows its object path waits in `coop-gift-toast.txt`, and the next Lua
load's first tick takes off a toast an earlier load left on screen.

### The inventory read

SB has no reflected function that returns how many of an item EVE carries, and its remove by alias takes what there is
when asked for more, so the native part reads the count itself (`game/items.h`, `glue/tick/items_worker.inc`). Lua asks
`items <ask> <alias> <FName index> <FName number>`; the worker reads at once through `ReadProcessMemory`, EVE's GUID
(client `+0x58`) included, apart from the revive guard and its latch, and the engine line of `coop-status.txt` gets
`items=<ask> <count>` or `items=<ask> none <why>` (`unpinned`, `noeve`, `nomanager`, `nobucket`, `unread`; after
`coop off` the status leaves `items=` out and only the worker's log line has `none off`).
The read follows the game's own lookups on build 24463856:

- the item bucket manager, a lazy singleton at `0x147032568` (its getter `FUN_141a97b20` makes it when null; the read
  never does, so 0 is no inventory yet);
- its bucket map at `+0x2b0`, from the bucket type (1, the inventory) to a map from the owner's GUID to the bucket,
  both keyed by an int that is its own hash (`FUN_141ad7250`);
- the bucket's map at `+0x90` from the item's alias (an FName) to the GUIDs of its instances, hashed as UE 4.26 hashes
  an FName (`FUN_140ecc610`, the find that the remove by alias `FUN_141bde8c0` calls);
- the manager's instance map at `+0x210` from an instance GUID to the item, hashed with CityHash64 of its 16 bytes
  (`FUN_142835af0`; the test checks the result against that function run in Ghidra's emulator), and each item's count
  at `+0x6c`, the field the remove lowers.

Each set is a TSet: its element array at `+0`, the array's count at `+8`, its free count at `+0x34`, an inline hash
bucket at `+0x38`, the hash array at `+0x40` when there is one and its size at `+0x48`. A chain longer than the array,
an index outside it, a hash size that is not a power of two or an implausible pointer ends the read as `unread`.

### The remove, the gift and its answer

The remove is the player controller's `ServerRequest_ItemBucketItemRemove(1, <GUID>, <alias>, <count>, -1)`. Its
implementation (`FUN_1423ba230`, vtable `+0x13d8` of the network player controller, behind a validate that returns true)
queues the game's remove request (type 0x16, `FUN_141af93e0`) for the next turn of the logic thread, where
`FSBItemBucketItemRemove::Simulate` (`FUN_141b0ba20`) removes by alias. -1 is the pocket index the request pool sets by
default (`FUN_141b48810`). The count therefore falls a turn later, and Lua reads again every 0.5 s until it fell by the
gift's count, for 10 s of play at most. A read that comes back `unread` (the remove changes the very sets the worker
walks, so a read can tear) or `noeve` is asked again the same way; any other `none` answer stops the send. A tick while
the game is paused, in photo mode, or in the friend's photo mode that pauses ours does not count: SB's logic thread
stops then, and the remove waits with it. If the count has not fallen by then, nothing is sent and the notice says the
items may be gone.

Once it fell, Lua writes the gift into `coop-gift-<steamid>-<index>.txt` (`out <id> <alias> <count> <to> <at> <sent>`)
and only then sends the gift line as a request, `gift s <id> <alias> <count>`. The id is the time in seconds and three
digits. The receiving game answers `gift a <id>` once the gift is in its file (`box ...`), or `gift n <id> <why>`
(`slot`, `full`, `item`, `store`). A refusal, no answer in 60 s, the friend gone from the lobby (not one whose link is
lost and may come back) or the native part's own `n <id> nolink` turns the entry into `back <id> <alias> <count>`,
and the next tick with EVE in the world and the game playing grants it through the shop's call
(`ServerRequest_ItemBucketItemAdd`, nightop/shop.lua's `Shop.add`). The entry leaves the file before the grant, as a
take's does, and goes back if the grant raises, so a file that cannot be written gives nothing back until it can. A
grant that raises, or a write that fails, is tried again after 10 s.
Until an answer, the gift line goes again every 10 s with the same id while the friend is linked. A `nolink` for one of
those lines brings nothing back: the first line went out and the friend may have kept the gift, so her answer, the 60 s
or her leaving decides.

The receiver keys each gift by the sender's SteamID (the first peer line; 0 in the loopback) and the id. A key in its
mailbox gets `a` again, and so does one among the last 64 it took (`seen <from> <id> a`); a key it refused for a full
mailbox gets `full` again (`seen <from> <id> n`). A take writes the file before the grant and puts the entry back if the
grant raises, so a gift is never taken twice.

The file holds whole lines and is written whole through `link.write_file`. A line in no known shape, or with an item
outside the seven or a count outside 1 to 10, is dropped and logged. When the file is missing, its `.tmp` is read,
since `link.write_file` removes the file before renaming the `.tmp` over it. A write whose rename failed after that
removal therefore counts as done; one whose old file is still there counts as failed, and its text stands.
