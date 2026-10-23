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
show as one line; the command line's snapshot, digest and diff), and the two real saves above. Not verified in game:
nothing of this has run against a live game yet.

## Gaps

- **Live, not-yet-saved state.** The tool reads files. A door opened, a trigger entered or a quest task finished since
  the last autosave is only in memory, and finding it needs a live dump of the game's own objects (the game thread,
  UE4SS, as `coop saves probe` does for the slot fields).
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

1. **A live dump, read only.** A `coop` command that finds the game's save object in a loaded world and prints the same
   lines to the mod folder, next to the file's: do they match, and what does a door opening look like between two
   dumps? Needs the game.
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
