# SBO Xion (experimental)

SBO Xion is a world of Stellar Blade Online's own. Its persistent level, `/Game/SBO_World/Xion_P`, is a copy of the
persistent level of SB's Xion that lists 95 of its 180 sublevels: the city's geometry, lights, sky and sound. Those
sublevels are not copied. They load from the player's own game files. The level has none of SB's level-design
sublevels, so it has no NPC, no quest, no event, no shop and no camp.

SB's own Xion is not changed. Its world row `Xion`, its zones and its sublevels stay as shipped. Story mode and
online sessions keep SB's Xion.

The module `world.maps.sboxion` is a test tool. Its first game test answered one question: can a persistent level in
a container of SBO's stream SB's sublevels, with EVE standing in a lit, empty city. It can: the 93 always-loaded
sublevels loaded and the day light applied. In the same test EVE fell out of the city and stayed dead.
[Falls and deaths](#falls-and-deaths) describes the fix. The commands are left out of the usage line. They run only
alone (not in a session) on a [co-op save](../../players/playing-with-a-friend.md#co-op-saves). Their lines go to
`UE4SS.log` as `[StellarCoop][SX]` and the native part's to `coop-link.log`.

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
| `coop xion status` | One line: the pak, the rows, the native part's last answer, EVE's place, the nearest waypoint and the recovery's state |
| `coop xion recover on`, `death` or `off` | Inside SBO Xion: what the module does after a fall or a death, until the next arrival ([Falls and deaths](#falls-and-deaths)). Alone, it prints the recovery's state |

`coop xion` refuses with nothing asked when the save is not a co-op save, when a session is open, without the pak,
when the rows were refused and when EVE is already in SBO Xion. The native part then refuses the warp during a
cutscene or talk, in photo mode, during a warp, a camp request or a reload, in a zone of type 3, 5 or 6 and after
`coop off`. Its refusal is one word in `coop-link.log` and in the `sboxionwarp=` line of `coop-status.txt`.

`coop xion leave` returns EVE to the last save of the co-op slot, not to the place she left. Rest at a camp before
`coop xion`. If the reload does not start, quit to the title from SB's menu: the in-game save wrote nothing in SBO
Xion.

## EVE inside

The zone `Zone_SBO_Xion` is of SB's type 5, the Boss Challenge type. SB builds EVE again when it loads a zone of that
type, from the newest save of the save list (`0x141cf3750` picks it by its time, not the loaded slot). So EVE in SBO
Xion is SB's Boss Challenge EVE. Her gear selection may differ from the EVE who typed `coop xion`. The rest at a camp
makes the co-op save the newest one. The SBO lobby resets EVE after such a load (`native/src/game/sbo.h`). This
module does not yet: the first test compares her outfit, gear, HP, item slots and skills before, inside and after.
The functions that apply the rebuild have not been read in the game's code.

SB's own zone warps and camp travel are refused in a type-5 zone (`0x141cdfe70`). The UI code that tests the zone
type has not been read: the pause menu may show Boss Challenge entries.

## Falls and deaths

SB catches a fall out of Xion with fall volumes in the level-design sublevel `E04_Area01_A_LD_Visible`. SBO Xion does
not load it. The lift's doors are in a level-design sublevel too, so lift doorway A near (3958, -9124, 1222) is open
and leads into the shaft. In the first game test EVE walked through it and fell. SB's own timer kills an EVE who
falls for `Falling_Time_Dead`, 10 s by the default in the game's code. Her death screen could not respawn her: its
camp respawn ends in SB's zone warp, which refuses a zone of type 5 (`0x141cdfe70`). The player had to quit the
game.

`recover.lua` handles both cases at each 250 ms pass while EVE is in SBO Xion. The fall catch ran in game on
2026-11-23: three falls were caught and EVE walked 0.3 s after each move. The death rule and
[the black](#the-black) have not run in game.

### A fall

The module keeps a ground point: the last place where EVE walked for four passes in a row. While she walks it is
under 1 s old. A jump or a fall keeps it. An arrival drops it.

Once EVE's Z is under -3275 the module asks [SB's black](#the-black). Two passes later (0.5 s) it moves her 10 cm
above the ground point with `K2_TeleportTo`, facing the way she faced there, then calls `StopMovementImmediately`.
-3275 is the top of SB's largest fall volume, `SBEffectVolume_Xion10_04`. It lies 1410 cm under the lowest spawn
point of the upper city and 3500 cm under the city point. In the first game test EVE fell more than 26,000 cm before
SB's timer ended the fall.

With no ground point, or after a failure, the target is the arrival point of the stay. After a failure the move is
made at once, in the pass that reads her under the floor. The first read of EVE walking within 3 s of the world's
time is the success. SB sets its fall timer to 0 on the first frame she does not fall (`0x141ba1810`), so the module
writes nothing of SB.

### The black

SB shows a fade of its loading widget when it warps a fallen EVE to a safe place (`0x141bb1e40`, `0x141b1b8e0`). The
module asks the same fade with one call, `LoadingScreenFadeAuto(1, 0.3, 0, 1, 0.5, 1, 0, 0)`. Its exec `0x1426641e0`
builds the two blocks SB's own fade builds, with SB's tag 0. It hands them to the same function (`0x14c91ad10`).

| | SB's fall warp | SBO Xion |
| --- | --- | --- |
| Fade to black | 0.3 s, from the warp's start | 0.3 s, from the pass that reads her under the floor |
| The move | 0.4 s after the start | 0.5 s after that pass (two passes) |
| The black stands | 2.0 s | 1.0 s |
| Fade back | 0.5 s | 0.5 s |
| EVE under the black | three actor states from the warp's start to its end: `ActorState_NoDamage`, `ActorState_BlockSkill`, `ActorState_BlockMoveInputBlock` | no state set |
| HP | a loss worked out from `HPPercentOnWarpSafeLocation`, 15 by default | untouched |

SB's numbers are the defaults in its code: the three values `0x141b1b8e0` falls back to, the 0.4 s registered at
`0x1425f4cdb` and the 15 registered at `0x1425ec690`. A table or a file of the game may change them. The module's
black stands 1.0 s because the module sets none of the three states: EVE walked 0.3 s after the move in the game
test, so each second of black is a second in which she can move unseen.

The move does not wait for the black. It is made two passes after the call whatever the call did. A call that
raised, a zero GUID (SB made no loading screen) and a GUID that did not read each give their own log line. A
put-back after a failure moves first. Its black is asked after the accepted move with a fade-in of 0 s, which is
black inside the call. A refused teleport asks no black.

SB ends the black: its loading controller counts the 1.0 s from the end of the fade-in, then fades the widget out
(`0x1424ea330`). The module keeps no handle of it and lifts nothing. A failure, the stop of the recovery, a map
change, `coop off` and `coop xion leave` therefore leave no black of the module's to end.

The limits:

- The black does not know about loading. The arrival point can be far from the fall, so parts of the city may still
  load when the picture is back. A long frame takes its whole time off the 1.0 s. The game test of 2026-11-23 logged
  a frame hitch of 1244 ms in the minute of its falls.
- A wait (photo mode, a warp) or a world time that stands still holds the move back. The black may be over by then.
  The move is then seen.
- No black of SB ends while SB's app pause is on (`0x1422a2a00`, reason `AppPause`). The count goes on after it.
- While any black of SB's loading controller is up, SB's UI manager keeps a counter above 0 (`0x1424f4060`). Other
  functions of the game answer a fixed value while it is (`0x142ccdbc0` is one). What that does to EVE's moves was
  not read. The module blocks no input of its own.
- Not read in the game's code: what SB's pause menu and photo mode do to a black that is up, what a map change does
  to it (`coop xion leave` typed during the black), whether SB's HUD draws over it.

### A death

While the `sboxionwarp=` line of `coop-status.txt` reads `life=3`, `4` or `5`, the module asks SB's own respawn job in
place: `ServerRequest_ActorRespawn(<EVE's GUID>, false)`. The job's code has no test for a zone of type 5. It sets
her life state to alive, sets her HP to its maximum and refills her recovery items. With `false` it does not move her
to a camp. The module waits until the death screen plays, 5 s at most, then makes the call once. Two seconds later
it logs the result and hides a death screen that still plays. If EVE is then not walking, or is under -3275, the
put-back of a fall runs, with the same black and the move two passes later.

The native part writes the `life=` word from an accepted `coop xion` until an accepted `coop xion leave`. Leaving by
SB's title menu does not end it: the read then goes on in any map until the game closes or a later `coop xion leave`
is accepted. The call also needs `warp=idle` and EVE's GUID (`me=`) from the `engine=` line, which the group's native
read writes. If that read is off or stopped on a fault, falls are still caught and deaths are not. The log says so
once a stay. Two other native reads can stop on a fault for the rest of the game run. The theater read then writes
`theater=fault`. The zone row read then writes `zonetype=0`. Neither word makes the recovery wait: SBO Xion has no
cutscene and `area=` still names the zone.

Nothing is saved. The items are refilled in memory and SB's in-game save queues nothing in this zone
([Saves](#saves)).

### When it waits and when it stops

The recovery waits with no EVE, in photo mode, during a cutscene, while a warp is under way and while the `engine=`
line names another zone or a zone type other than 5 or 0. The zone row read writes 0 before its first read, after a
fault, for a zone with no row and for a type above 6. The ground point, the fall and the check skip the passes on
which the world's time did not move. The respawn does not.

These are failures: a teleport the game refuses, 3 s without a walking read after a put-back, life still 3 to 5 two
seconds after the call, no call in 10 s, an error in a pass. After one failure the next put-back goes to the arrival
point. A put-back that works, a respawn that leaves EVE walking and 1 s of walking each set the count back to 0. Two
failures with none of these between them stop the recovery until the next arrival or `coop xion recover on`. A death
screen the module hid is shown again at that stop, so a death after it has its screen. `coop xion leave` stays the way
out.

A move that waits under the black is dropped wherever a put-back's check is dropped: a death that starts, an error
in a pass, an arrival, a map change, `coop off` and `coop xion recover off`. A wait holds it back and uses up none
of its two passes.

`coop xion recover death` leaves falls alone, so a test can let EVE die of one. `coop xion recover off` does nothing
after a fall or a death, as in the first game test. Each arrival sets the mode back to `on`.

The floor is one height for the whole map, so a roof or a ledge outside the city above -3275 counts as ground. Lift
doorway A stays open. Other open edges were not looked for.

### What the log shows after a fall or a death

| Line | Meaning |
| --- | --- |
| `sboxion: recovery on: floor Z -3275, arrival point <name> (x, y, z)` | Each arrival |
| `sboxion: ground: first point (x, y, z)` | The first ground point of the stay |
| `sboxion: recovery waits: <reason>`, then `sboxion: recovery waits no more` | A wait started, then ended |
| `sboxion: recovery: the engine line has no warp= word: falls are caught, deaths are not` | The group's native read is off |
| `sboxion: black: up in 0.3 s; EVE at (x, y, z) moves in 2 passes` | A fall, or a respawn that left her off the ground, was caught. SB made its black. The move comes two passes later |
| `sboxion: black: not shown: SB made no loading screen; EVE at (x, y, z) moves in 2 passes` | The call returned a zero GUID. The move comes all the same |
| `sboxion: black: asked, its handle did not read; EVE at (x, y, z) moves in 2 passes` | The call returned. Its GUID could not be read |
| `sboxion: black: not shown: <why>; EVE at (x, y, z) moves in 2 passes` | The call raised |
| `sboxion: black: up at once` | After a put-back that followed a failure. The three other forms end at their reason |
| `sboxion: fall: EVE at (x, y, z) under the floor, mode m, life n: to the ground point (x, y, z) read t s ago` | The move of a caught fall, two passes after its `black:` line. It names the place where she was caught. The target also reads `the arrival point <name> (x, y, z), no ground point` or `after a failure` |
| `sboxion: put back: EVE walks at (x, y, z), t s after the move` | The put-back worked |
| `sboxion: put back refused by K2_TeleportTo: failure n of 2` | The game refused the teleport |
| `sboxion: put back failed: EVE at (x, y, z), mode m, 3 s after the move: failure n of 2` | No walking read in 3 s |
| `sboxion: death: life n, EVE at (x, y, z)` | The death rule started |
| `sboxion: respawn waits: <reason>` | Why the call is not made yet, each reason once |
| `sboxion: respawn: ServerRequest_ActorRespawn(<GUID>, false) asked (life n, death screen up)` | The call. It reads `no death screen in 5 s` when none played |
| `sboxion: respawn result: life 3/1, death screen up/hidden, EVE pawn same, mode m` | Before and after, 2 s after the call. `life 3/3` comes with `failure n of 2` |
| `sboxion: death: EVE at (x, y, z) not on the ground: to the ground point (x, y, z) read t s ago` | The respawn left her off the ground. The move, two passes after its `black:` line |
| `sboxion: respawn not asked in 10 s: <reason>: failure n of 2` | The call was never made |
| `sboxion: death: over before the respawn was asked (life n)` | She was alive again before the call |
| `sboxion: respawn: death screen shown again (<reason>)` | A death screen the module hid is back: a new death, a map change, `coop off` or the recovery stopped |
| `sboxion: recovery: error (<why>): failure n of 2` | A pass raised an error |
| `sboxion: recovery stopped after 2 failures in a row; coop xion recover on starts it again; way out: coop xion leave` | Nothing more is tried |
| `sboxion: recovery mode <on, death or off>: ...` | `coop xion recover` changed the mode |
| `link: sboxionwarp=entered asks=a life=n` | The status line, at each change of her life state |

### Testing it in game

On a co-op save, alone, with the test pak in. `coop xion status` prints EVE's place: use it to find lift doorway A.

If the screen stays black: press the pause button again. Click the game window if it lost focus. After 10 s of black
type `coop xion leave`. Last, quit the game.

1. `coop xion`, then walk for 5 s. The log has `recovery on` and `ground: first point`.
2. Walk through lift doorway A and let go of the stick. The picture fades to black in about a third of a second
   while EVE falls. It stays black about one second. It fades back in half a second with EVE standing in front of
   the doorway. No camera jump is seen and no death screen shows. The log has `black: up in 0.3 s; EVE at ... moves
   in 2 passes`, one `fall:` line and one `put back: EVE walks` line.
3. The same fall with the stick held forward through the black. Note where EVE is when the picture is back and
   whether she falls again.
4. Fall again and press the pause button as soon as the screen is black. Note what shows, whether the menu answers
   and whether the black is still there when the menu closes.
5. Jump off the edge near (-10800, 9900), where the first two falls of 2026-11-23 happened. Note whether the black
   is long enough: the city drawn when the picture is back, or parts still loading.
6. Note whether SB's HUD or the mod's own screens show over the black.
7. Fall, then click another window while the screen is black. Come back after 5 s. Note whether the black ends.
8. Run and jump through the doorway, then walk on for 10 s. The log has the same three lines as in step 2. EVE does
   not die 10 s later.
9. `coop glide on`, jump through the doorway and hold Jump. EVE comes back by the catch or, after SB's 10 s, by a
   death and its respawn. Note which. `coop glide off`.
10. `coop xion recover death`, then walk through the doorway. The death screen shows after 10 s. Within about 3 s
    the same fade shows, then EVE is alive in front of the doorway and the death screen is gone. Moving, jumping and
    the pause menu work. The log has `death: life 3`, `respawn: ... asked`, `respawn result: life 3/1`, `black: up in
    0.3 s`, `death: ... not on the ground` and `put back: EVE walks`.
11. `coop xion leave`. The co-op save reloads at its camp with no black left over. `coop-link.log` has
    `sboxion leave: ... last save unchanged, reload call 1`.
12. `coop xion`, `coop xion recover off`, walk through the doorway, wait for the death screen, then
    `coop xion leave`. If the native part refuses it, note its `why=` word, type `coop xion recover on`, wait for the
    respawn, then `coop xion leave` again.
13. `coop xion`, `coop xion recover off`, walk through the doorway. At the death screen press its left button and
    wait 5 s. Note what the screen shows. Then `coop xion leave`, with `coop xion recover on` first if it is refused.

Not known before this test: whether SB's respawn job runs as read in a zone of type 5, what the death screen shows
after its left button, whether `coop xion leave` passes with a dead EVE, whether `LoadingScreenFadeAuto` called from
Lua shows SB's black, whether EVE can move under it and what SB's pause menu does to it.

## Saves

Two things keep the player's story saves untouched, the same two Matrix XIII and the hall lobbies use.

1. The rows and the command need the co-op save files (`saves=coop`). The game then reads and writes
   `StellarBladeCoop0N.sav`, never `StellarBladeSave0N.sav` ([Saves](../../players/saves.md)).
2. SB's in-game save (`0x141ce8050`) queues nothing while EVE is in a zone of type 3, 5 or 6. SB's three other save
   requests (`0x1421d71e0`, `0x1421d72f0`, `0x1421d7fa0`) set one value each and have no zone test. On the co-op save
   files they write the co-op file. The URL warp itself saves nothing.

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
| `sboxion leave: queue q, last save unchanged, reload call 1` (`coop-link.log`) | SB's reload started and its last save time did not move since the enter |
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
  the day table, the two probe levels and the recovery's numbers.
- `sboxion.lua`: the pak gate, the rows at the title, the commands, the arrival and the watch.
- `recover.lua`: the ground point, the black and the put-back after a fall, the respawn after a death. Its respawn
  block is the module's copy of score attack's. Its ground read is the module's copy of the group's.
- `engine.lua`: the UE4SS calls. Its black call is the module's copy of the lobby's. `commands.lua`: `coop xion`.
  `wiring.lua`: the manifest, export `sboxion`.

Native, in `native/src/world/maps/sboxion/`:

- `sboxion_rows.h`: the batch `sboxion`, two rows written by hand.
- `sboxion.h`: the guards, the answer word, the status line and the log lines, tested on Linux.
- `warp_game.inc` and `warp_worker.inc`: the two requests, on the game thread under the module's own fault latch.
  The worker also reads EVE's life state each 250 ms while she is inside, for the `life=` word of the status line.
  That read is a `ReadProcessMemory` on the worker thread, which fails instead of faulting.

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
has no zone volume: Xion's 15 are in level-design sublevels. Type 5 is also a type SB's in-game save queues nothing
in (`0x141ce8050`).

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

- The 50 level-design sublevels: NPCs, quests, shops, camps, zone volumes, doors, ladders, the lift, SB's fall
  volumes. EVE can fall out of the city: [Falls and deaths](#falls-and-deaths) says what brings her back.
- The 15 underground sublevels, the theater set, one distant-view level and the light variants for night.
- `E04_Area02_FX_A_01`, which holds the 12 rats. Its 16 effects and its water body are missing with it.
- The 50 actors of the persistent level tagged `XionChristmasEvent`.
- The tunnel exit toward the first MMO map. `data.lua` keeps the old exit box as a comment.

## Tests

- `tests/lua/world/maps/sboxion/off_test.lua`: a failure of this module at load turns this module off alone.
- `sboxion_test.lua`: the words of `coop xion`, `recover` and its three modes included.
- `rows_test.lua`: the Lua rows against `sboxion_rows.h`, the IDs 7131 and 1000131, no name ending in `_<digits>`,
  the 41 names of the day table.
- `title_test.lua`: no ask without the pak, none on the player's own saves, one ask on the co-op save files, the
  read-back, a refusal logged once.
- `world_test.lua`: the commands' refusals and requests, then on a fake world the 41 writes matched by level and
  name, the counts 72, 65 and 41, nothing read outside SBO Xion, a second arrival, a probe change logged once, a
  waypoint logged once a visit, the watch ended by a map change and by `coop off`. For the recovery: ticked only in
  SBO Xion, started again at each arrival with the point `coop xion` asked, fed by the engine's read of EVE when
  `me()` names another place, SB's black asked through the module's own wiring with the move two passes later, a
  death answered with her GUID, the hidden death screen shown again at a map change and at `coop off`, `coop xion
  recover`, the mode back to `on` at an arrival and the status line's part.
- `recover_test.lua`: the ground point, the fall with its black and the move two passes later, a black that is not
  shown, the move dropped or held back like a check, each guard, the check on the world's time, the two failures
  that stop the recovery, then the death with score attack's respawn cases and this module's own (no death screen
  for 5 s, a respawn that leaves EVE off the ground, a death left from the mode `off` or read during a wait).
- `engine_test.lua`: the UE4SS calls over fake objects, the recovery's included: one read of EVE a pass, no stop call
  after a refused teleport, the black's call and its three answers, the respawn's request, the death screen hidden
  and shown again.
- `tests/native/world/maps/sboxion/sboxion_test.cpp`: one case for each guard of the two requests, the answer word,
  the status line and the log lines, the inside flag and the `life=` word on each form of the line.
- `tests/native/rows/rows_test.cpp` runs the batch on the row engine. `tests/native/link/protocol_test.cpp` parses
  the two requests.
