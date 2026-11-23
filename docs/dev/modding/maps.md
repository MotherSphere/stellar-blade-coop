# Map pipeline

Stellar Blade Online has three sets of maps of its own: the cut dungeon Matrix XIII (module `world.maps.matrix13`),
the five hall lobbies of `online.lobby` and SBO Xion (module `world.maps.sboxion`, a test not run in game). This page
lists what the game needs before such a map works and the steps that make one, with the steps the repository holds.
The map tools stay with MotherSphere for now, so a clone of the repository cannot build a map pak today.

How each map does these steps is in [world/matrix13-internals.md](../../world/matrix13-internals.md),
[online/lobby.md](../../online/lobby.md#hall-lobbies) and [world/maps/sboxion.md](../../world/maps/sboxion.md). The
field offsets are in the generators named below.

## What the game needs

1. A WorldTable row. Its `UMapPath` names the cooked persistent level, written `/Game/<folders>/<Map>.<Map>`. Each
   hall lobby copies a shipped world row and changes only `UMapPath`.
2. A ZoneTable row for each zone. `WorldAlias` names the world row, `ZoneType` gives the zone's type and
   `StartPointAlias` names the arrival point.
3. The rows before the warp. The warp finds the zone and the arrival point by name. It refuses a name that this game
   run has not made yet. The rows make those names. A row name must not end in `_<digits>`: the warp sends FName
   number 0, which turns such a name into another one. `tools/sbo_lobby_rows.py` refuses such names.
4. The rows before the world starts. When a world starts, SB makes its zone manager, which lists the camps and the
   ZoneEnvSpawnTable rows once. Camp travel looks a camp up in that list. A row added after the world started is
   missing from it until the next world start. So every batch goes in at the title, before a save loads, on the
   co-op save files only. See [The camp list](../../world/matrix13-internals.md#the-camp-list).
5. SB's own AddRow. SB reads some tables by ID through maps that only its own AddRow fills, so the native part adds
   every row through that call, on the game thread with no game logic task running (`native/src/rows/rows.h`). Lua
   never adds a row. After a batch, `core/enemy.lua` reads every patched field back. A row that reads back other
   than written counts as a refusal.
6. A way in. The hall lobbies use SB's URL warp: the native part reads the zone row, then its world row's `UMapPath`,
   then asks the warp (`native/src/game/sbo.h`). EVE arrives at the cooked `SBSpawnPoint` the warp names. The hall
   lobbies give it the name in the zone row's `StartPointAlias`.
   SBO Xion has no spawn point of its own. Its native part gives the warp no point and writes the arrival location
   and rotation into the warp block right after the call (`native/src/world/maps/sboxion/sboxion.h`).
   Matrix XIII uses SB's camp travel: it looks the camp up in the zone manager's list, takes the camp's first
   ZoneEnvSpawnTable row, then that row's zone and the zone's world. EVE arrives at the actor named after the camp.
7. Saving. SB's save writes nothing while EVE is in a zone of type 3, 5 or 6. The hall zones keep type 5 for that
   reason. Entering a world the save has never been in may write that world, its zones and its enemies into the save.
   Matrix XIII therefore runs on co-op saves only. `saves export` refuses a save that played it:
   `native/src/game/twins.h` looks for its `DLC02_` names.
8. Objects. A ZoneEnvSpawnTable row with `EnvBPPath` empty binds the placed actor whose `EnvActorName` equals the
   row's. With `EnvBPPath` set, it spawns that class at the actor named in `SpawnPointName`. A camp is a ZoneCampTable
   row plus such rows.

A batch holds under 256 rows, since a row index is one byte. A row's strings and lists must fit a 4 KB pool
(`POOL` in `tools/mxiii_rows.py`). IDs sit above the highest shipped ID of their table. An SB update that takes one of
them refuses the whole batch: the hall lobbies then stay in Xion. The first refused row stops the rest of its batch.

## Steps for a small map

The table assumes a walkable map with one arrival point, reached by URL warp as the hall lobbies are.

| Step | What | Editor needed |
| --- | --- | --- |
| 1 | The geometry: copies of shipped levels, or a new layout | Only for a new layout |
| 2 | The arrival `SBSpawnPoint` and the actors the env rows bind | Yes, or an edit of copied levels |
| 3 | Lighting | Yes |
| 4 | Navmesh, for a map with enemies | Yes |
| 5 | Cook the levels | No window: the editor's command line |
| 6 | The persistent level, the container written with retoc, its checks | No |
| 7 | `data/<map>.json` and its generator, which writes `<map>_rows.h` and the Lua rows | No |
| 8 | The world row and the zone row, with free IDs and names | No |
| 9 | The module: title batch, read-back, pak gate, travel, its `coop` command, tests | No |
| 10 | Names on screen, as `native/src/game/camp_text.h` adds Matrix XIII's | No; it edits the shared `game/` folder |
| 11 | The install: `tools/install.py --pak` copies the hall lobby pak only | No; it edits a shared tool |
| 12 | One game test: arrival, floor, zone entry, save, leave | The game, not the editor |

Copies of shipped levels come out of the game's container with retoc, get their edits through UAssetAPI, then go back
into a new container. A new layout is built in the UE 4.26 editor and cooked there. Both ways end in an IoStore
container (`.utoc`, `.ucas`, `.pak`) written by retoc. `core/pak_gate.lua` reads the map's names from the `.utoc` as
plain text, so the container must not be encrypted. `coop mxiii`'s pak check also reads names from the `.ucas`, which
Oodle compression hides.

## In the repository

- The data and its generator. `data/sbo-lobby.json` with `tools/sbo_lobby_rows.py` writes
  `native/src/online/lobby/halls_rows.h` and `mod/StellarCoop/Scripts/online/lobby/sbo_maps.lua`.
  `data/mxiii-world.json` with `tools/mxiii_rows.py` writes `native/src/world/maps/matrix13/mxiii_rows.h` and
  `world/maps/matrix13/level/rows.lua`. With `--check`, each generator exits 1 when a written file is out of date.
  `tests/tools/sbo_lobby_rows_test.py` and `tests/tools/mxiii_rows_test.py` run that check.
  SBO Xion has two rows and no data file: `native/src/world/maps/sboxion/sboxion_rows.h` is written by hand, with the
  same rows in `world/maps/sboxion/data.lua`. `tests/lua/world/maps/sboxion/rows_test.lua` checks that the two agree.
- The title batch. `core/enemy.lua`'s `title_batch` asks a batch at the title while the game uses the co-op save
  files, then reads it back. A gate that stayed shut is asked again 10 s later, at most four times a visit of the
  title. `online/lobby/halls_rows.lua`, `world/maps/matrix13/level/travel.lua` and
  `world/maps/sboxion/sboxion.lua` call it.
- The pak gate. `core/pak_gate.lua` looks for the container's `.utoc` in `SB/Content/Paks/~mods`, then in
  `LogicMods`, reads its first 1 MB and needs the `.pak` and the `.ucas` beside it. A new map needs no change to it.
- The install of the hall lobby pak. `python3 tools/install.py --pak <folder>` copies `zSBO_Lobby.pak`,
  `zSBO_Lobby.ucas` and `zSBO_Lobby.utoc` into `~mods`. The Matrix XIII pak `zMXIII_P` and the SBO Xion pak
  `zSBO_Xion` are copied by hand.
- The module. A new map is a module `world.maps.<map>` in `world/maps/<map>/`, added as
  [Adding a module](../structure.md#adding-a-module) says.

## Outside the repository

- The UE 4.26 editor project, with SB's placed actor classes declared as stubs so the cooked map loads into SB's own
  classes.
- The cook scripts, the persistent level edits and the retoc steps.
- The UAssetAPI edits of copied levels.
- The CUE4Parse reads of the game's paks and of the new container, with the checks run on it.
- The tools that write the data files. `data/sbo-lobby.json` is read from the editor maps; `data/mxiii-world.json` is
  built from the cook's manifest and table reads.
- Game files: levels, meshes, mappings and table reads. They never go into the repository (AGENTS.md).

## Shared pieces a second map changes

These hold one map by name today. AGENTS.md lets a shared piece change only when MotherSphere asks.

- `native/src/game/camp_text.h` and `native/src/game/record_text.h` add Matrix XIII's camp names and records only.
- `native/src/game/twins.h` refuses an export only for Matrix XIII's `DLC02_` names. It knows neither the hall rows'
  names nor SBO Xion's.
- `tools/world_rows.py` reads only `data/mxiii-world.json`.
- `tools/install.py --pak` copies only the three `zSBO_Lobby` files.
