# Story and world state: where the save keeps it

The co-op campaign's step 5 (story sync) needs to know what the
game's story and world state is before any of it can go from one player to the other. This page maps the part of it
that the save holds, as read on 2026-10-23 from the test copy's first-beach co-op save (New Game, Story Mode,
`StellarBladeCoop00.sav`, 629,404 bytes, Steam build 24463856), and says what the mapping does and does not cover.

## Why the save first

There are two ways to sync a story: mirror the live game objects, or keep the persistent world state and send its
changes. The game already writes the persistent state into `SBSaveGame` — quests, mission records, and per-zone object
state — keyed by its own aliases. Reading that is cheaper and steadier than enumerating live actors, and step 4 already
carries the host's save to the guest. What the save cannot show is anything the game has not written yet (see
[Gaps](#gaps)).

## The three structures

`SBSaveGame` is a plain UE 4.26 tagged-property save (`tools/gvas.py` reads it); the story lives in three of its
properties.

### Quests: `DataMap_SBQuest[Quest]`

| Field | What it holds |
|---|---|
| `ProgressQuestList[]` | the quests in progress |
| `.QuestAlias` | the quest, e.g. `Quest_Epic_01`, `CQ_SD10_RR` |
| `.QuestState` | `1` for both quests seen in progress; the other values are not mapped |
| `.QuestTaskGroupList[]` | the quest's mission steps: `TaskGroupAlias` (`Quest_Epic_01_M01`), `TaskGroupState` (`TaskGroup_Progress` or `TaskGroup_None`), `PathIndex`, `PathNodeIndex` |
| `.TaskInfoList[0].TaskList[]` | the tasks the step panel shows: `TaskAlias`, `CurrentValue`, `TaskState` (`ESBQuestTaskState_Progress`), `CompleteOrder` (`-1` unfinished) |
| `.AllChildTaskList` | the same tasks as a map keyed by `TaskAlias`, complete where `TaskList` is a view: values matched in this save |
| `.LastUpdateTimestamp` | when the quest last moved (not story state) |
| `TrackingQuestAliases` | the quest the HUD tracks |
| `CompleteQuestList` / `FailedQuestList` | finished and failed quests, by alias (both empty in this save) |
| `CustomTrackingList`, `CustomPinContainerList`, `CustomTrackingTarget*` | map pins; not read |

`TaskValueMap`, `CustomIntMap` and `CustomFloatMap` were empty in every task of this save; they are not read, so a
counter that lives there would be missed.

### Mission records: `GamePlayProgressRecordData`

`ProgressRecordGroup` is a list per quest task group (`RecordGroupName`, e.g. `Quest_Epic_01_M01`). Each holds
`RecordTaskGroupMap`, keyed by the kind of record — the save holds `ESBMission_Achievement`, `ESBMission_EnterTrigger`
and `ESBMission_EnvState` — and each of those holds `TaskDataList` of `DataAlias` + `bSuccessTask`. This is where the
game notes that an achievement fired, a trigger was entered or an env object reached a state, *including the ones the
achievement and mission systems only need to remember once*. `DataAlias` repeats inside a list (two `SD_10_EnvS_010`
entries in `ESBMission_EnvState`), so lines are numbered by occurrence.

### Zones: `DataMap_SBEnv[Env]`

| Field | What it holds |
|---|---|
| `WorldContainerList[]` | per world (`WorldAlias`): `ZoneEventActorStorageList` (event actors spawned in that world) |
| `ZoneContainerList[]` | 201 zones; each has `ZoneAlias`, `ZoneObjectState` (`ESBObject_Enable`), `bZoneReset` and the lists below |
| `.ZoneEnvStorageList[]` | doors, lifts, consoles, pickups: `EnvAlias` (`SD_10_EnvS_067`), `EnvActivate` (`ESBObject_Enable`/`_Disable`), `EnvActiveState` (`ESBENV_State_*`), `EnvStateSlotTag`, `CurrentTriggerCount`, `InteractData.bInteracted`, `StateInfoList`, `EnvProgressInfo`, the four buffer lists, `SaveType`, and its own position |
| `.ZoneNpcStorageList[]` | NPCs: `CharacterDataAlias`, `ObjectState`, `LifeState`, `bActiveActor`, `bHiddenGame`, `SpawnIndex`, `StayZoneAlias`, `RetargetSpawnPointName`, `InteractData`, the AI maps |
| `.ZoneTriggerStorageList[]` | triggers: `TriggerAlias` (`SD_10_ZTrigger_001`), `TriggerActivate`, `DoingCount` |
| `.ZoneEventItemStorageList[]` | event items taken in the zone (empty in this save) |
| `.ZoneEventActorStorageList[]` | event actors of the zone (empty in this save) |
| `.WorldObjectStorageMap` | saved world objects, keyed by an integer that is *not* stable across saves: `UniqueKey` (`SD_10_EffVol_003`), `ObjectType` (`ESBWorldObjectType_EffectVolume`), `Activate`, `SaveType`, `JsonInfo`, `EffectVolumeDeadCount` |

What the first-beach save holds: 2 quests in progress (its `CompleteQuestList` and `FailedQuestList` are empty),
1,502 story lines in all, and inside `Zone_SD_10` 12 world objects, 2 NPCs, 1 trigger and no event items; the other
200 zones are empty scaffolding.

## What two saves of the same session showed

`coop00-before-run.sav` and `coop00-before-walk.sav` are the same test save before and after a walk on the first
beach. The whole-save diff is 236 lines, almost all of it noise:

- 198 `bZoneReset: False -> True`, on every zone but the loaded one (its meaning is not known; not read);
- 26 inventory lines, the same 10 items with new GUIDs and a new order (each player keeps her own inventory);
- the player's position and rotation, HP 1760 -> 2000, the camera, `PlayTime` 467 -> 760 s, two timestamps;
- `TheaterStorage.LevelSeqPlayingSet` gained one subtitle sequence (cutscene bookkeeping; not read).

Three lines are story:

```
~ progress Quest_Epic_01_M01 ESBMission_Achievement Ach_LV_SD10_FirstTachySpawn_01 done: False -> True
~ progress Quest_Epic_01_M01 ESBMission_Achievement Xion_Phase_1 done: False -> True
~ zone Zone_SD_10 object SD_10_EffVol_003 activate: ESBObject_Disable -> ESBObject_Enable
```

That side by side is the whole argument for a canonical state: 236 changed lines, 3 of them worth sending.

## The canonical state

`tools/story.py` reads a save and prints the story state as one sorted `key = value` line per fact:

```
progress Quest_Epic_01_M01 ESBMission_Achievement Xion_Phase_1 done = True
quest Quest_Epic_01 group Quest_Epic_01_M01 task Quest_Epic_01_M01_T01 value = 0
quest Quest_Epic_01 state = 1
quest Quest_Epic_01 tracked = True
zone Zone_SD_10 env SD_10_EnvS_067 activate = ESBObject_Disable
zone Zone_SD_10 env SD_10_EnvS_067 interacted = False
zone Zone_SD_10 object SD_10_EffVol_003 activate = ESBObject_Enable
zone Zone_SD_10 state = ESBObject_Enable
zone Zone_SD_10 trigger SD_10_ZTrigger_001 count = 0
```

The rules, so that a line means the same thing in any save:

- Keys are the game's own aliases (`QuestAlias`, `EnvAlias`, `TriggerAlias`, `UniqueKey`, `DataAlias`), never an array
  index or a map key that moves (`WorldObjectStorageMap`'s integers are replaced by `UniqueKey`).
- A plain list or map entry with no alias of its own is keyed by its index or map key, and a repeated alias inside one
  list gets `#2`, `#3` in the order the game lists it.
- Left out: positions, rotations, timestamps, playtime, the camera, the inventory, `bZoneReset`, the theater's
  sequence set, and the zone scaffolding (a zone with nothing in it contributes only its `state` line).
- `digest` is one SHA-256 over the sorted lines: two saves whose story agrees give one value, whatever moved.

Verified: `python -I tools/gvas.py selftest`, `python -I tools/story.py selftest`, `tests/story_test.py` (a save
written the way the game writes it — EVAS, GVAS, CRC-32 — read back; a moved zone, a reset zone and reordered zones
keep the digest and produce no diff; a quest state, a task value, a mission flag, an env object and a world object each
show as one line; the command line's snapshot, digest and diff), and the two real saves above.

## The live dump

`coop story [dump|find]` prints the same lines from the save object the running game holds, read only
(`mod/StellarCoop/Scripts/story/dump.lua`). It writes `StellarCoopStory.txt` in the mod folder: a header, one comment per
save-shaped object found, a `# stage:` line, then the sorted lines, so `python tools/story.py compare SAVE DUMP` reads
it as it reads any dump. The file is rewritten after every stage (quests, the mission records, each zone, the world
actors), so a run that ends in a crash still says how far it got. `coop-story.txt` in the mod folder asks for a dump
(`find` for the listing instead) once a world is loaded, for when the console is out of reach; the dump is identical
whichever way it is asked for.

What reading the live object took, all of it found by running it in the test copy:

- UE4SS hands containers and their elements over wrapped (`RemoteUnrealParam`/`LocalUnrealParam`), so every key and
element is opened with `:get()` before use; a `TMap` is walked instead of asked `Find`, so a key of the wrong type can
never reach the game thread.
- A struct value is its own `UStruct`: its fields come from `ForEachProperty` on the value itself, not from
`GetClass():ForEachProperty` (which lists the class's own properties, none). A `TArray` is never asked for its class:
`GetClass` on one faults the game (the first attempt crashed it with an access violation).
- The save stores an enum's name where the running game holds its number. The number is turned back into the name with
the game's own `UEnum` (`StaticFindObject('/Script/SB.ESBObjectState')`, `GetNameByValue`), field by field and for
`RecordTaskGroupMap`'s keys (`ESBQuestMissionType`).
- A `TArray`'s `ForEach` counts from 1 and the save's element names count from 0, so every list's fallback name is
its index minus one (`item 0` in both). A map that is not mapped field by field is walked entry by entry and printed
the way the save writes it, `ElementInfoMap[Element_Fire].ElementAmount`; its key is named through the enum it holds
(`ESBElementType`), and an empty map prints nothing where it used to print its address.
- An `FName` leaf is a userdata too; it is printed as text, not walked into.

Result, test copy on 2026-10-23 (`StellarBladeSave00.sav`, 647,849 bytes, digest `b71a70c8…`, loaded by Continue):
the dump was asked for at the title, before the load, so it ran as soon as the world reported loaded. It found three
save-shaped objects, dumped the largest in 6.0 s, and wrote 1,532 lines whose digest is `b71a70c8…` —
`python tools/story.py compare` printed `the same`, no line only in the dump, none only in the save.

That object is a full mirror only at load and around a save. A dump taken two minutes later in the same session found
one save-shaped object with 946 lines (130 of the 199 zones, 534 of the 950 mission-record lines, and a few records the
file does not have); another session's dumps 25 to 30 s after the load found 865 and 1,373 lines as the game replaced
the object mid-session. So the file stays the fuller source, and the live object shows what the game has in hand at that
moment: the live-not-yet-saved state gap, now with a way to look at it.

### During play

The same test copy, played on 2026-10-23, says what that gap looks like from inside a session:

- Asked for twice, 25 s apart, with nothing done between the two, the dump was identical both times (946 lines). A
  partial object is a stable snapshot, so two dumps can be diffed to see what changed: sort their ` = ` lines and
  `comm` them (`tools/story.py diff` reads two saves, not two dumps).
- The game autosaved at 04:40:17 (647,849 to 1,976,427 bytes; the new save carries 10,443 story lines where the loaded
  one had 1,532). A dump asked for 32 s later found **three** `SBSaveGame` objects and merged them: 10,800 lines in
  15.3 s. `tools/story.py compare` then found the quests and the mission records identical, and two kinds of
  difference:
  - `zone Zone_DED10 item N`, 63 lines each way: the live array index was 1 where the save's is 0, and `SaveType`
    printed as `1` where the save names `ESBZoneObjSaveType_Save`;
  - the world-actor stage, 4,757 lines only in the dump and 4,400 only in the save: its maps printed as pointers
    (`ElementInfoMap = TMap: 0000000D4B194028`) where the save lists their elements, `Location` and `Rotation` were not
    filtered although they are volatile, and its actor index was 1 where the save's is 0.
  Both were fixed the same night (below); the lines stayed as an example of the gap, not of the current dump.
- 73 s after that dump the game held one object again, with the same 946 lines as before the save: the objects the game
  fills exist only for about a minute around a save.

A second session the same night (the game as host of the loop bot, `StellarBladeCoop00.sav` loaded, 648,105 bytes) put
numbers on both sides of that window. Two dumps 25 s apart with nothing done were identical (949 lines with the three
header lines), so the partial object is steady. An 8 s walk forward then made the game autosave (648,080 bytes at
06:07:16); a dump asked for 16 s later found three `SBSaveGame` objects, merged them into 1,532 lines in 6.6 s, and
`tools/story.py compare` with the new file printed `the same` — the same digest, `b71a70c8…`, and the same count. So a
change made during play reaches the live dump when the game writes its save (the walk's autosave, here), and the full
mirror is exact at that moment; before the write, a change is only in the partial object and the save is the only
complete copy. What no run has shown yet is a story line moving between two dumps with no save in between.

So the dump is exact for the quests, the mission records and the zones' env state at load, and it covers the whole
object only in that minute after a save.

### The whole object, matched

On the night of 2026-10-23 the dump was asked for at the title of the game holding the first save's 1.9 MB autosave
(`StellarBladeSave00.sav`, 1,984,213 bytes), so it ran as the world came up. The first run reproduced the two
world-actor and item differences above: 4,824 lines only in the dump, 4,465 only in the save. The causes and the
fixes:

- **Maps were printed as containers.** A live `TMap` has no fields, so `ElementInfoMap`, `MeshInfoMap` and two more
  printed as `TMap: 0x…`. They are now walked entry by entry and printed as the save writes them
  (`ElementInfoMap[Element_Fire].ElementAmount`); an empty map prints nothing. The key is the enum's name
  (`ESBElementType` gives `Element_Fire`).
- **Lists were named from 1.** Every list's fallback name is now the save's 0-based index, so the zone event items
  (`item 0`, `item 1`, …) and the world actors (`actor 0`, …) match.
- **Positions leaked in.** `Location` and `Rotation` are now filtered like `ActorLocation`, and so is
  `PhysicsConstraintStateMap`, which the save never stores (16 live entries of `False` had no line in the file).
- **`SaveType` was a number.** The enum's own name is `ESBZoneObjectSaveType` (not `ESBZoneObjSaveType`), and 1 is
  `ESBZoneObjSaveType_Save`; the dump names it now.
- **Finished quests.** The save now writes `CompleteQuestList` entries as whole quest structs, not names, and
  `tools/story.py` skipped anything that was not a string, so the file hid two completed quests the live object had.
  It reads `QuestAlias` from a struct now (tests/story_test.py covers both shapes).

Result on the same save: the dump wrote 10,430 lines in 15.6 s and `tools/story.py compare` printed `the same` — the
same digest, `faeb83f9…`, 10,430 lines, no line only in the dump and none only in the save. The whole object is now a
full mirror at load and around a save, world actors included.

`coop story find` was tried in game too (typed into the UE4SS console, F10). It wrote its listing — each class, its
live objects, the save's fields and which of the three story structures it has — but `FindAllOf('Class')` failed in
this build (`FindAllOf(Class) failed: listed 5 known names instead`), so it reported only the five names it knows
(`SBGameInstance`, `SBQuestManager`, `SBSaveGame`, `SBSaveManager`, `SBZoneManager`): a class it does not know is not
found. The listing named one live `SBSaveGame` with 130 zones at that point, and the quests, mission records and env
maps among its fields.

## Gaps

- **Live, not-yet-saved state.** A door opened, a trigger entered or a quest task finished since the last autosave is
  only in memory. `coop story dump` reads that memory, but the save object matches the file in full only at load and
  in the minute after a save: after that the game replaces it with a partial one (see
  [The live dump](#the-live-dump)), so a change made during play has to be found by diffing two dumps taken close
  together, not by comparing one dump with the file.
- **Which env aliases are what.** The save says an env object is called `SD_10_EnvS_067` and where it stands, not
  whether it is a door, a lift, a console or scenery. That needs the live actor's class and name behind the alias.
- **Cutscenes and level transitions.** No structure here names them. `TheaterStorage.LevelSeqPlayingSet` moves when
  sequences play, but whether it is story state or playback bookkeeping is unknown, so it is not read. The live
  sequence player and the level-transition triggers are not mapped at all.
- **Enums.** `QuestState` 1, `TaskGroup_Progress`, `TaskGroup_None`, `ESBQuestTaskState_Progress` and `ESBObject_*`
  are what this save shows; the rest of each enum is unnamed here.
- **`bZoneReset`.** It flips for every zone that is not the loaded one between two saves of the same session. What the
  game does with it on entry is unknown, so it is neither read nor synced.
- **Applying it.** The guest's own game holds its story in memory. Writing the received lines into its save file is
  not enough while it runs: a change has to reach the live object (a UE4SS call, needs the setters) or the guest has
  to reload at a moment that does not break the session (step 4's save sets and the title, or an area transition).

## Next, in order

1. **A live dump, read only.** Done: `coop story [dump|find]` ([The live dump](#the-live-dump)), and at load its
   digest is the file's. Two dumps during play are known to be comparable (they are identical when nothing happens),
   and the full object is there only in the minute after a save: a walk that made the game autosave was followed, 16 s
   later, by a dump whose digest was that new save's. A partial object also drops whole parts of the save: two minutes
   after a load it had 166 of the 299 env entries and 528 of the 950 mission-record lines, so a change made during play
   is invisible until the next save writes it. Still to see: what a door opening, a trigger or a quest task looks like
   between two dumps taken before the save writes it (so far every walk that crossed a trigger also made the game
   autosave). The dump now matches the whole object, world actors included (see [The whole object, matched](#the-whole-object-matched)).
2. **Host to guest, logging only.** The host sends its story lines (or the delta since the last save) on every save and
   area change; the guest writes them to its log and changes nothing. A chapter played with the bot measures what a
   real session produces, which decides whether delta or whole-state is the right unit.
3. **Then apply**: live writes for the state a player sees (env objects, triggers, quest tasks), or a reload on area
   transitions, which step 4's save sets already make possible. The owner decides which before it is built.

## Running it

```
python -I tools/gvas.py dump SAVE [PREFIX]     every leaf of the save, for a new structure
python -I tools/story.py snapshot SAVE [PREFIX]  the story lines
python -I tools/story.py diff OLD NEW            what the story did between two saves
python -I tools/story.py digest SAVE             one hash to compare two players' worlds
```

Both tools are read only. They are not installed into the game and the mod does not use them yet.
