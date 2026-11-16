# Story dump

The story dump prints the state of the story that Stellar Blade keeps in a save: quests and their tasks, mission
records, and the state of each zone's doors, lifts, pickups, NPCs, triggers and event actors. It is a research tool
for the co-op work, to see which of these values change at a story step and which ones two players would have to
share. It only reads. Nothing in it writes a save or changes the running game.

It has three parts:

- `coop story`, in game, reads the game's save object in memory (`SBSaveGame`) and writes its story lines to
  `StellarCoopStory.txt` in the mod folder (`story/snapshot.lua`).
- `tools/story_lines.py` reads a `.sav` file and prints the same lines, so that two saves, or a save and an in-game
  dump, compare line by line.
- `tools/save_read.py` prints every value of a `.sav` file, for looking past the story lines.

The tools run on the build machine with Python 3 and are not in the release zip. The save files are where
[saves.md](saves.md#where-the-saves-are) says. Copy one out before reading it while the game runs.

## In game: `coop story`

| Command | What it does |
| --- | --- |
| `coop story` or `coop story dump` | Write the story lines of the fullest live save object to `StellarCoopStory.txt` |
| `coop story find` | Write a list of the objects that may hold the story state to the same file, and no story lines |

Any other word, or a second one, gets the usage line and writes nothing. The command works on any save, with or
without the Steam link, and is refused after `coop off` like every other command. It runs on the game thread, so the
game waits until the file is written. Its result is a `[StellarCoop] OK:` or `STOP:` line in `UE4SS.log`, and its
progress goes to `[StellarCoop][ST]` lines: which enum objects were found, each candidate object and its zone count,
the line count after each part, and at the end the total, the time taken and the file's path.

### The request file `coop-story.txt`

A player without the UE4SS console can ask for the same run with a file. Put `coop-story.txt` in the mod folder
(`Mods/StellarCoop/`, next to `Scripts`). While a world is loaded, the mod checks for it every 250 ms, removes it and
runs once. A file whose first word is `find` (any case, after any blank space) asks for the list; anything else, an
empty file included, asks for the dump. At the title screen and while a map loads the file stays where it is, and it
is acted on once a world is loaded. The check runs only with the Steam link loaded and stops after `coop off`. A file
the mod cannot remove gives one `STOP:` line and no run.

### Which object it reads

The game keeps its story state in `SBSaveGame` objects, in three properties: `DataMap_SBQuest`,
`GamePlayProgressRecordData` and `DataMap_SBEnv`. The candidates are the valid live `SBSaveGame` objects, class default
objects left out, whose class has `DataMap_SBQuest` or `DataMap_SBEnv`. The dump reads the one with the most zones in
`DataMap_SBEnv[Env].ZoneContainerList`, the first one found on a tie, and never merges two.

What was seen of these objects in game:

| Moment | Live `SBSaveGame` objects |
| --- | --- |
| Just after a load | One, identical line for line to the save file |
| About 60 s after the game writes a save | Up to three; the fullest one is identical to the new save |
| Later in the session | One partial object, with some zones and records missing, which the game replaces now and then |

So the dump matches a save file right after loading it or right after saving. Progress made since the last save is
only in memory, and a later dump may miss part of it. While nothing happens in the game, a partial object gives the
same dump each time, so two dumps taken a short time apart show what changed in between.

### The file

`StellarCoopStory.txt` is replaced at each run. It starts with `#` comment lines: the UTC time of the run, the object
read and every candidate with its zone count, and the last part finished. The sorted story lines follow. The dump
works in parts (the quests, the mission records, one part per zone that has a `ZoneAlias`, the world actors) and
rewrites the whole file after each one, so if the game crashes during a run the file holds every part finished up to
then, and its header names the last one.

When no candidate is found, or for `coop story find`, the file holds comment lines only: the candidates' names (for
`find`), then for each of `SBSaveGame`, `SBSaveManager`, `SBSaveGameComponent`, `SBGameInstance` and `SBGameState` its
number of live instances and the names of up to five, and for a class whose objects hold one of the three story
properties, which ones and the class's property names (60 at most). With no candidate, the result says so.

## The tools

```
python3 tools/story_lines.py snapshot SAVE [PREFIX]
python3 tools/story_lines.py diff OLD NEW
python3 tools/story_lines.py digest SAVE
python3 tools/story_lines.py digest-lines FILE
python3 tools/story_lines.py compare SAVE FILE
python3 tools/save_read.py dump SAVE [PREFIX]
python3 tools/save_read.py diff OLD NEW
```

| Command | Output | Exit code |
| --- | --- | --- |
| `story_lines.py snapshot SAVE [PREFIX]` | The save's story lines, sorted; with PREFIX, the lines whose key starts with it, such as `quest ` or `zone Zone_Example_N ` | 0 |
| `story_lines.py diff OLD NEW` | Each story line that changed, sorted by key: `~ key: old -> new`, `+ key = value` (only in NEW), `- key = value` (only in OLD); nothing when the stories agree | 0 |
| `story_lines.py digest SAVE` | The digest of the save's story lines | 0 |
| `story_lines.py digest-lines FILE` | The digest of a file of lines, such as `StellarCoopStory.txt`: UTF-8, trailing blanks cut (CRLF files work), blank and `#` lines left out, the rest sorted | 0, or 2 with a `story_lines:` message for a missing file or one that holds a NUL byte |
| `story_lines.py compare SAVE FILE` | A `save` line and a `dump` line with each side's digest and line count; then `same story: every line matches`, or a `+` line for each dump line the save lacks, a `-` line for each save line the dump lacks, and both counts | 0 same, 1 different, 2 when the save or the file cannot be read |
| `save_read.py dump SAVE [PREFIX]` | A comment line with the save class, the engine version and the bytes read, then one `path = value` line per value in save order; with PREFIX, the paths that start with it. A list or a map of plain values is one value, in Python's list notation | 0 |
| `save_read.py diff OLD NEW` | One line per path that differs, sorted, in the same `+`, `-` and `~` form | 0 |

Both tools also take `selftest`, and print their usage line with exit code 2 for anything else. A file that is not a
save, or whose CRC-32 does not match, stops `save_read.py`, `snapshot`, `diff` and `digest` with a Python error.

To check an in-game dump against a save: load the save, type `coop story`, copy the save file and
`StellarCoopStory.txt` out, then run `python3 tools/story_lines.py compare <save> StellarCoopStory.txt`.

## The line format

One fact per line: a key, ` = `, the value. A key is words separated by single spaces. The two sides write the same
format, `tools/story_lines.py`'s output is the reference, and the tests hold both to `tests/tools/story_case.txt`.

| Fact | Key |
| --- | --- |
| Mission record | `progress <record group> <mission type> <data> done` |
| Finished or failed quest | `quest <alias> complete`, `quest <alias> failed` (always `True`) |
| Quest in progress | `quest <quest> state`, `quest <quest> tracked` |
| Task group | `quest <quest> group <group> state` |
| Task | `quest <quest> group <group> task <task> order\|state\|value` |
| Zone | `zone <zone> state` |
| Env object (doors, lifts, pickups and other interactive objects) | `zone <zone> env <env> activate\|active\|count\|slot\|interacted`, and `zone <zone> env <env> <path>` |
| NPC | `zone <zone> npc <npc> active\|hidden\|life\|spawn\|state\|interacted` |
| Trigger | `zone <zone> trigger <trigger> activate\|count\|interacted` |
| World object | `zone <zone> object <object> activate\|deaths` |
| Zone event item | `zone <zone> item <item> <path>` |
| Zone event actor | `zone <zone> actor <actor> <path>` |
| World event actor | `world <world> actor <actor> <path>` |

The last word of a field line comes from a save field:

| Entry | Save field | Word |
| --- | --- | --- |
| Mission record | `bSuccessTask` | `done` |
| Quest | `QuestState` | `state` |
| Task group | `TaskGroupState` | `state` |
| Task | `CompleteOrder`, `TaskState`, `CurrentValue` | `order`, `state`, `value` |
| Zone | `ZoneObjectState` | `state` |
| Env | `EnvActivate`, `EnvActiveState`, `CurrentTriggerCount`, `EnvStateSlotTag` | `activate`, `active`, `count`, `slot` |
| NPC | `bActiveActor`, `bHiddenGame`, `LifeState`, `SpawnIndex`, `ObjectState` | `active`, `hidden`, `life`, `spawn`, `state` |
| World object | `Activate`, `EffectVolumeDeadCount` | `activate`, `deaths` |
| Trigger | `TriggerActivate`, `DoingCount` | `activate`, `count` |
| Env, NPC, trigger | `InteractData.bInteracted` | `interacted` |

A field line exists when the field holds a plain value (a string, number or boolean) other than the string `None`.
`tracked` is `True` when the quest's name, without a `#n` suffix, is one of `TrackingQuestAliases`. The finished and
failed lists hold either plain quest names or whole quest records; both read the same.

Where the save holds them:

- `DataMap_SBQuest[Quest]`: `ProgressQuestList` (the quests in progress, each with `QuestTaskGroupList`, whose groups
  hold every task in `AllChildTaskList`), `TrackingQuestAliases`, `CompleteQuestList` and `FailedQuestList`.
- `GamePlayProgressRecordData.ProgressRecordGroup`: per task group, `RecordTaskGroupMap` from a mission type
  (`ESBMission_Achievement`, `ESBMission_EnterTrigger`, `ESBMission_EnvState`) to a `TaskDataList` of records.
- `DataMap_SBEnv[Env]`: `ZoneContainerList` (about 200 zones in a full save, each with `ZoneEnvStorageList`,
  `ZoneNpcStorageList`, `ZoneTriggerStorageList`, `WorldObjectStorageMap`, `ZoneEventItemStorageList` and
  `ZoneEventActorStorageList`) and `WorldContainerList` (each world's `ZoneEventActorStorageList`).

### Names

An entry is named by the first of these fields it holds with a string other than `None`: `ZoneAlias`, `EnvAlias`,
`TriggerAlias`, `QuestAlias`, `TaskGroupAlias`, `TaskAlias`, `CharacterDataAlias`, `UniqueKey`, `WorldAlias`,
`ObjectName`, `RecordGroupName`, `DataAlias`, `Alias`. Without one, a map entry is named by its key when the key is a
string or an integer, and a list entry by its position from 0. World objects therefore get their `UniqueKey`, not the
map's integer key, which differs from one save to the next. A zone with no `ZoneAlias` and a world with no `WorldAlias`
give no lines.

When a name repeats, the first entry keeps it and the n-th gets `#n`, counted in save order: mission types within a
record group, records within a mission type, quests across `ProgressQuestList`, task groups within a quest, tasks
across all the groups of their quest, actors within a world, world objects within a zone, and env, NPC, trigger, item
and actor entries within their list. Record groups, zones and worlds are not numbered: of two lines with the same key,
the later one counts.

### Path lines

Env entries' `StateInfoList` and `EnvProgressInfo`, and whole event items and event actors, have no fixed fields. Each
plain value under them gives a line keyed by its path below the entry: field names joined by dots, and entries of a
list or map in brackets. A map entry is written by its key when the key is a string or an integer, a list entry by
its first field ending in `Alias` that is not `None`, else by its position. A list or map of plain values only (the
three floats of a `Vector`, for example) gives no line, nor does a value under `ActorLocation`, `ActorRotation`,
`QuestMarkerLocation` or `LastUpdateTimestamp`. A `None` value gives a line.

```
progress Quest_Example_07_M03 ESBMission_EnterTrigger 1 done = False
quest Quest_Example_07 group Quest_Example_07_M03 task Quest_Example_07_M03_T02 value = 12
quest Quest_Example_07#2 tracked = True
world Example_World_2 actor 1 ElementInfoMap[Element_Fire].ElementAmount = 0.30000001192092896
zone Zone_Example_N env Example_EnvS_031#2 [0].ExampleRatio = 2.5e-05
zone Zone_Example_N object Example_EffVol_020 deaths = 3
```

### Values

Booleans are `True` and `False`, integers decimal, strings and enum values as stored. Floats are written as Python 3's
`repr` writes the double: the shortest decimal that reads back as the same double, in plain notation for decimal
exponents from -4 to 15 (`7.0`, `0.00025`) and as `2.5e-05` or `1e+16` outside. A `FloatProperty` is written as the
double it widens to, so a stored 0.3 is `0.30000001192092896`. An empty string ends the line in `= ` with a space,
which `compare` never matches, since it cuts trailing blanks from dump lines only.

### Order and digest

Lines are sorted by plain code-point order of the whole line. The digest is the SHA-256 of the sorted lines joined by
single LF characters, with none after the last, as UTF-8 and 64 lowercase hex digits. It depends on the story lines
only, so positions and the order of zones cannot change it.

## Left out

| Left out | Why |
| --- | --- |
| Positions and rotations (`ActorLocation`, `ActorRotation`, `QuestMarkerLocation`, any `Vector` or `Rotator`) | Two players at the same story step stand in different places |
| `LastUpdateTimestamp` | A time, not a state |
| `bZoneReset` | Between two saves of one session it changed on every zone but the player's; what it means is not known |
| `TaskList` | It repeats part of `AllChildTaskList` |
| Inventory, player stats, camera, play time | Per player, and outside the three properties |
| `TheaterStorage.LevelSeqPlayingSet` | It gains an entry each time a subtitled sequence plays; nothing shows it is story state |
| `TaskValueMap`, `CustomIntMap`, `CustomFloatMap` | Empty in every save looked at. If the game ever keeps task progress there, the lines will not show it |
| The other fields of env, NPC and trigger entries | Not mapped |

On the live side, `Location`, `Rotation` and `PhysicsConstraintStateMap` are dropped too: live actors hold them and
the save does not.

## How the in-game dump reads the game

It uses UE4SS reads only: `FindAllOf`, `StaticFindObject`, property reads, `ForEach` on arrays and maps,
`ForEachProperty`, `GetClass`, `GetFullName`, `GetFName`, `IsValid`, `GetArrayNum`, `GetNameByValue`, `ToString` and
`get()` on the values UE4SS wraps. It calls no game function and no setter.

- Array elements, map keys and map values come as `RemoteUnrealParam` or `LocalUnrealParam` objects, opened with
  `get()` first.
- Maps are read with `ForEach` only. Their keys are `FName`s, and no lookup by a Lua value is made.
- A struct value lists its fields through `ForEachProperty` on itself; an object through its class.
- Arrays and maps are told apart before anything asks for a class: `GetClass` on an array crashed the game in a test.
- Enum fields hold numbers in memory and names in the save. The dump turns them into names with `GetNameByValue` on
  the game's enum objects (`/Script/SB.ESBQuestTaskGroupState`, `ESBQuestTaskState`, `ESBObjectState`,
  `ESBZoneEnvActiveState`, `ESBZoneObjectSaveType`, `ESBQuestMissionType` for the mission types,
  `ESBElementType` for the keys of `ElementInfoMap`), and writes the number when one is missing. `QuestState` is a
  number on both sides.
- A map key with no usable text gets its position. A `Vector`, `Rotator`, `Quat`, `Color`, `LinearColor`, `Vector2D`
  or `IntPoint` struct reads as a list, a `DateTime` or `Timespan` as its tick count and a `Guid` as 32 hex digits, as
  in the save. In memory these are known by their field names only, so a game struct with exactly the same fields
  would read the same way.

## The save file

A Stellar Blade save is an EVAS wrapper around an Unreal Engine 4.26 GVAS body: `EVAS`, a version byte (1), three zero
bytes, the body, and the CRC-32 of the body, little endian. `tools/save_guard.py` and `native/src/save/twins.h` check
the same wrapper. `tools/save_read.py` refuses a file without `EVAS` and `GVAS` or with a wrong CRC-32, and refuses an
FString longer than 1 MiB as a misread. It reads the tagged properties of the body, including arrays, sets, maps,
structs (tagged, or `Vector`, `Rotator`, `Quat`, `LinearColor`, `Vector2D`, `Color`, `IntPoint`, `DateTime`,
`Timespan` and `Guid` in their fixed layout), and keeps texts and unknown types as hex. A byte value inside a map or a
set is either an enum value's name or a raw byte, and nothing in the file says which: the reader takes a name when the
next bytes read as a short printable string with its closing NUL.

## Limits

- Only the enum values seen in the studied saves are known by meaning.
- An env alias does not say what kind of object it is (a door, a lift); that needs the actor that carries the alias
  in the running game.
- Nothing here covers cutscene playback or map changes, and nothing applies lines to another player's game.
