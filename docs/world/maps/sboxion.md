# SBO Xion (experimental)

SBO Xion is a world of Stellar Blade Online's own. Its persistent level, `/Game/SBO_World/Xion_P`, is a copy of the
persistent level of SB's Xion that lists 95 of its 180 sublevels: the city's geometry, lights, sky and sound. Those
sublevels are not copied. They load from the player's own game files. The level has none of SB's level-design
sublevels, so it has no NPC, no quest, no event, no shop and no camp.

SB's own Xion is not changed. Its world row `Xion`, its zones and its sublevels stay as shipped. Story mode and
online sessions keep SB's Xion.

The module `world.maps.sboxion` is a test tool. It has not run in game. Its first test answers one question: can a
persistent level in a container of SBO's stream SB's sublevels, with EVE standing in a lit, empty city. The commands
are left out of the usage line. They run only alone (not in a session) on a
[co-op save](../../players/playing-with-a-friend.md#co-op-saves). Their lines go to `UE4SS.log` as `[StellarCoop][SX]`
and the native part's to `coop-link.log`.

## The test pak

The level is in the container `zSBO_Xion` (`zSBO_Xion.utoc`, `zSBO_Xion.ucas`, `zSBO_Xion.pak`, one package). The
mod does not ship it and the repository cannot build it: the map tools stay outside the repository
([Map pipeline](../../dev/modding/maps.md)). Without the pak the module asks nothing and logs nothing.

The module looks for the pak once a Lua load, in `SB/Content/Paks/~mods`, then in `SB/Content/Paks/LogicMods`. The
`.utoc` must name `SBO_World` and `Xion_P.umap`, with its `.pak` and `.ucas` beside it.

## Commands

| Command | What it does |
| --- | --- |
| `coop xion` or `coop xion city` | Warps EVE into SBO Xion at the city point (-8304, 7201, 225) |
| `coop xion gate` | The same at the gate point (-23393, 17287, 1285) |
| `coop xion leave` | Asks SB's reload of the co-op save. The native part runs it only from SBO Xion |
| `coop xion status` | One line: the pak, the rows, the native part's last answer, EVE's place and the nearest waypoint |

`coop xion` refuses with nothing asked when the save is not a co-op save, when a session is open, without the pak,
when the rows were refused and when EVE is already in SBO Xion. The native part then refuses the warp during a
cutscene or talk, in photo mode, during a warp, a camp request or a reload, in a zone where SB saves nothing and
after `coop off`. Its refusal is one word in `coop-link.log` and in the `sboxionwarp=` line of `coop-status.txt`.

`coop xion leave` returns EVE to the last save of the co-op slot, not to the place she left. Rest at a camp before
`coop xion`. If the reload does not start, quit to the title from SB's menu: nothing was saved in SBO Xion.

## EVE inside

The zone `Zone_SBO_Xion` is of SB's type 5, the Boss Challenge type. SB builds EVE again when it loads a zone of that
type, from the newest save of the save list (`0x141cf3750` picks it by its time, not the loaded slot). So EVE in SBO
Xion is SB's Boss Challenge EVE. Her gear selection may differ from the EVE who typed `coop xion`. The rest at a camp
makes the co-op save the newest one. The SBO lobby resets EVE after such a load (`native/src/game/sbo.h`). This
module does not yet: the first test compares her outfit, gear, HP, item slots and skills before, inside and after.
The functions that apply the rebuild have not been read in the game's code.

SB's own zone warps and camp travel are refused in a type-5 zone (`0x141cdfe70`). The UI code that tests the zone
type has not been read: the pause menu may show Boss Challenge entries.

## Saves

Two things keep the player's story saves untouched, the same two Matrix XIII and the hall lobbies use.

1. The rows and the command need the co-op save files (`saves=coop`). The game then reads and writes
   `StellarBladeCoop0N.sav`, never `StellarBladeSave0N.sav` ([Saves](../../players/saves.md)).
2. SB queues no save while EVE is in a zone of type 3, 5 or 6. The URL warp itself saves nothing.

Never run `coop saves export` on a co-op slot used for this test. The export writes a co-op copy over one of the
player's own saves. A co-op save made while SBO's rows are in the tables may hold their names. The export's refusal
knows Matrix XIII's names only. Whether the names reach a save is not proven: the test counts `SBO_Xion` in the co-op
file with `grep -a -o SBO_Xion <file> | wc -l`.

## What the log shows

Each line below is one proof of the test. They are in `UE4SS.log` unless said.

| Line | Meaning |
| --- | --- |
| `sboxion title: the rows are in, before any save loads` and `sboxion rows: 2/2 in` | The two rows went in at the title and read back as written |
| `sboxion enter: zone row found, type 5, world row found, call 1, to (x, y, z) yaw y, queue q, last save t` (`coop-link.log`) | The native guards passed and SB's warp returned 1 |
| `sboxion: arrived, map /Game/SBO_World/Xion_P, zone Zone_SBO_Xion, EVE at (x, y, z)` | EVE stands in SBO Xion |
| `sboxion: levels: 95 listed, 93 of 93 always-loaded ones loaded and visible, missing: none` | Every sublevel loaded from the game's own files |
| `sboxion: light: 72 env volumes found, 65 in E04_ENV_VOL, 41 named, 21 changed, CountDown_Posing_ENV active true` | The day table was written |
| `sboxion: light: 41 of 41 read back as written` | The writes held, 2 s and 10 s after the arrival |
| `sboxion: characters: 1` | EVE is the only character |
| `sboxion: probe: start: E04_DistantView_A_01 loaded b visible b, E04_DistantView_A_03 loaded b visible b` | The two volume-streamed levels at the arrival |
| `sboxion: probe: <level> loaded b visible b, EVE at (x, y, z)` | One of the two changed state |
| `sboxion: at <waypoint>: A_01 loaded b visible b, A_03 loaded b visible b` | EVE stood 5 s within 3 m of a waypoint |
| `sboxion leave: queue q, last save unchanged, reload call 1` (`coop-link.log`) | SB's reload started and nothing was saved since the enter |
| `sboxion: left, map <path>` | EVE is out |

The two probe levels are the only ones the pak leaves volume streamed, as SB ships them. Both read loaded and
visible at the arrival, which decides nothing. A waypoint line with `visible false` and a later probe line back to
`visible true` shows that UE's volume streaming runs in a persistent level of SBO. The waypoints `kaya` (the front of
Kaya's shop) and `camp7` (the camp beside Roxanne's place) lie outside every visibility volume of both levels.
`tie` is 15 m from the city point, where two env volumes of the same priority overlap. `tree` is the place of two
Christmas sound actors in `E04_Sound`.

## How it works

Lua, in `mod/StellarCoop/Scripts/world/maps/sboxion/`:

- `data.lua`: the pak's name, the level, the two rows, the two arrival points, the four waypoints, the 41 names of
  the day table and the two probe levels.
- `sboxion.lua`: the pak gate, the rows at the title, the three commands, the arrival and the watch.
- `engine.lua`: the UE4SS calls. `commands.lua`: `coop xion`. `wiring.lua`: the manifest, export `sboxion`.

Native, in `native/src/world/maps/sboxion/`:

- `sboxion_rows.h`: the batch `sboxion`, two rows written by hand.
- `sboxion.h`: the guards, the answer word, the status line and the log lines, tested on Linux.
- `warp_game.inc` and `warp_worker.inc`: the two requests, on the game thread under the module's own fault latch.

### The rows

| Table | Row | ID | Copy of | Patches |
| --- | --- | --- | --- | --- |
| WorldTable | `SBO_Xion` | 7131 | `CombatTestMapMk2` | `UMapPath` = `/Game/SBO_World/Xion_P.Xion_P` |
| ZoneTable | `Zone_SBO_Xion` | 1000131 | `Zone_NK_Boss_Scarlet` | `WorldAlias` = `SBO_Xion`, `ZoneType` = 5 |

The hall lobbies hold World 7121 to 7125 and Zone 1000121 to 1000125. Their generator gives hall i the pair
(7121 + i, 1000121 + i), so 7126 to 7130 and 1000126 to 1000130 stay free for five more halls. An SB update that
takes 7131 or 1000131 refuses the batch.

The zone is of type 5 for two reasons read in the game's code. At an arrival (`0x141cde9b0`) SB takes the zone from
the zone volume at EVE's place. It keeps the zone the warp asked for only when that zone's row is of type 5. SBO Xion
has no zone volume: Xion's 15 are in level-design sublevels. Type 5 is also a type SB saves nothing in
(`0x141ce8050`).

The rows go in at the title while the game uses the co-op save files and the pak is found, through `core/enemy.lua`'s
title batch. `coop xion` asks the same batch when the rows are not in yet.

### The warp

`coop xion` sends `sboxion enter <zone FName index> <x> <y> <z> <yaw>`. The native part handles it in one frame of
the game thread:

1. It reads the guards: co-op saves, a slot entered, in game and playing, no warp, camp request or reload under way,
   client `+0x100` at 0, EVE's logic actor present, no theater, photo mode off, the current zone not of type 3, 5
   or 6, no Boss Challenge byte, the asked zone's row found and of type 5, its world row found.
2. It calls SB's URL warp with the world row's `UMapPath`, the zone and no start point.
3. It writes the arrival location and rotation into the warp block (client `+0xa4c` and `+0xa58`). SB's arrival
   keeps a stored location that is not zero.
4. It sets client `+0x3689`, so the first tick in the zone starts no Boss Challenge record.

The two points are the root transforms of SB's own points `SBSpawnPoint_Xion_Camp_10_02` and `Xion_Camp_10_01_SV`.
The request carries whole centimetres and whole degrees.

`coop xion leave` sends `sboxion leave <zone FName index>` from any map. The native part compares the zone with the
client's zone and refuses any other zone with `zone`. SB's reload itself has no zone test.

### The light

SB lights Xion through SBEnvControlVolume actors. Each time its env pass runs (`0x1425c99b0`, from the registry's
tick) it skips a volume whose `bActiveVolume` is off. Among the others that contain the view point it keeps the first
one with the highest priority. SB's sequence
`EnvObj_Xion01_Light_Phase3` sets the day look: 15 volumes of the level `E04_ENV_VOL` on, 26 off. The module writes
those 41 values at each arrival. It plays no sequence.

The world holds 72 such volumes: 65 in `E04_ENV_VOL`, 3 in the persistent level, 3 in `E04_Area01_Sequence_A_01` and
`CountDown_Posing_ENV` in `E04_Area02_Light_A_01`. A volume is matched by level and name, so one of the same name in
another level is left alone. `CountDown_Posing_ENV` holds fog data and ties with the day volume
`E04_Area_01_Global_ENV_01` at priority 100 in a part of Area 01. The module logs its state and leaves it.

The day and night cycle leaves SBO Xion alone: `world/daynight/rule.lua` lists the level as fixed.

### What is left out

- The 50 level-design sublevels: NPCs, quests, shops, camps, zone volumes, doors, ladders, the lift, the
  fall-recovery volume. EVE can fall out of the world: `coop xion leave` is the way back.
- The 15 underground sublevels, the theater set, one distant-view level and the light variants for night.
- `E04_Area02_FX_A_01`, which holds the 12 rats. Its 16 effects and its water body are missing with it.
- The 50 actors of the persistent level tagged `XionChristmasEvent`.
- The tunnel exit toward the first MMO map. `data.lua` keeps the old exit box as a comment.

## Tests

- `tests/lua/world/maps/sboxion/off_test.lua`: a failure of this module at load turns this module off alone.
- `sboxion_test.lua`: the words of `coop xion`.
- `rows_test.lua`: the Lua rows against `sboxion_rows.h`, the IDs 7131 and 1000131, no name ending in `_<digits>`,
  the 41 names of the day table.
- `title_test.lua`: no ask without the pak, none on the player's own saves, one ask on the co-op save files, the
  read-back, a refusal logged once.
- `world_test.lua`: the commands' refusals and requests, then on a fake world the 41 writes matched by level and
  name, the counts 72, 65 and 41, nothing read outside SBO Xion, a second arrival, a probe change logged once, a
  waypoint logged once a visit, the watch ended by a map change and by `coop off`.
- `engine_test.lua`: the UE4SS calls over fake objects.
- `tests/native/world/maps/sboxion/sboxion_test.cpp`: one case for each guard of the two requests, the answer word,
  the status line and the log lines.
- `tests/native/rows/rows_test.cpp` runs the batch on the row engine. `tests/native/link/protocol_test.cpp` parses
  the two requests.
