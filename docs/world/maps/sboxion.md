# SBO Xion (experimental)

SBO Xion is a world of Stellar Blade Online's own. Its persistent level, `/Game/SBO_World/Xion_P`, is a copy of the
persistent level of SB's Xion that lists 95 of its 180 sublevels: the city's geometry, lights, sky and sound. Those
sublevels are not copied. They load from the player's own game files. The level has none of SB's level-design
sublevels, so it has no NPC, no quest, no event, no shop and no camp. A third pak, [the full test
pak](#the-full-test-pak), lists 156 of the 180 with 47 of the 50 level-design sublevels, to see what they start.

SB's own Xion is not changed. Its world row `Xion`, its zones and its sublevels stay as shipped. Story mode and
online sessions keep SB's Xion.

The module `world.maps.sboxion` is a test tool. Its first game test answered one question: can a persistent level in
a container of SBO's stream SB's sublevels, with EVE standing in a lit, empty city. It can: the 93 always-loaded
sublevels loaded and the day light applied. In the same test EVE fell out of the city and stayed dead.
[Falls and deaths](#falls-and-deaths) describes the fix. [The rooms](#the-rooms) are rooms of SBO's own behind
closed doors of Xion, which later test paks add: five, then eleven. [The Tetrapod's door](#the-tetrapods-door) leads
into SB's own Tetrapod interior. [The threshold doors](#the-threshold-doors) lead into rooms behind doors that stay
shut. The commands are left out of the usage line.
They run only alone (not in a session) on a [co-op save](../../players/playing-with-a-friend.md#co-op-saves). Their
lines go to `UE4SS.log` as `[StellarCoop][SX]` and the native part's to `coop-link.log`.

## The test pak

The level is in the container `zSBO_Xion` (`zSBO_Xion.utoc`, `zSBO_Xion.ucas`, `zSBO_Xion.pak`, one package). The
mod does not ship it and the repository cannot build it: the map tools stay outside the repository
([Map pipeline](../../dev/modding/maps.md)). Without the pak the module asks nothing and logs nothing.

The module looks for the pak once a Lua load, in `SB/Content/Paks/~mods`, then in `SB/Content/Paks/LogicMods`. The
`.utoc` must name `SBO_World` and `Xion_P.umap`, with its `.pak` and `.ucas` beside it.

There are seven builds of the pak, under the same three file names. Only one of them is installed at a time.

| Pak | Packages | Levels listed | `.utoc` | `.ucas` | Version in `coop xion status` |
| --- | --- | --- | --- | --- | --- |
| 23 November 2026 | `Xion_P` | 95 | 657 bytes | 1,261,721 bytes | `657_1261721` |
| 24 November 2026, rooms | `Xion_P` and five room levels | 100 | 1203 bytes | 1,501,348 bytes | `1203_1501348` |
| 24 November 2026, full test | `Xion_P` and the same five room levels | 161 | 1203 bytes | 1,501,548 bytes | `1203_1501548` |
| 24 November 2026, rooms, second build | `Xion_P` and the five room levels, rebuilt | 100 | 1203 bytes | 1,545,808 bytes | `1203_1545808` |
| 24 November 2026, full test, second build | `Xion_P` and the five rebuilt room levels | 161 | 1203 bytes | 1,546,008 bytes | `1203_1546008` |
| 24 November 2026, full test, third build | `Xion_P` and eleven room levels | 167 | 1863 bytes | 1,918,741 bytes | `1863_1918741` |
| 25 November 2026, full test, fourth build | `Xion_P` and nineteen room levels | 175 | 2719 bytes | 2,331,195 bytes | `2719_2331195` |

All seven pass the check above. The module looks for package paths, never for a version: `self.gate()` in
`sboxion.lua` hands the version to `coop xion status`, which prints it. Nothing else reads it. Two rebuilds of the
third full test build, made on 25 November 2026 with pieces turned inside the rooms, read the same version: it is
made of two sizes. At the first arrival
of a Lua load the module asks again for each room of `rooms/list.lua` on its own: `Rooms` and that room's file name,
such as `Xion_Rooms_D011.umap`. It opens the rooms the pak holds. The first and second builds hold five (`D011`,
`D031`, `D081`, `D107`, `D158`). The third build holds those, the five of the list added for it and `D039`, which the
list leaves out of its walk-in rooms. With the pak of 23 November the module works as before
[the rooms](#the-rooms) existed: it logs `rooms: none in this pak` at each arrival and hides nothing.

The list also names nine rooms behind [threshold doors](#the-threshold-doors). The module asks for each of them the
same way. `D039` is one of them, so the third build holds one threshold room. The level files of the eight others
are `Xion_Rooms_D111.umap`, `D157`, `D109`, `D029`, `D030`, `D037`, `D163` and `D164`. The fourth build holds all
nine. Its level line reads `175 listed, 141 of 141`. Read that line before the first push on a door: four of the
new rooms (`D029`, `D030`, `D163`, `D164`) load on streaming slots of a kind no game run has loaded yet.

## Commands

| Command | What it does |
| --- | --- |
| `coop xion` or `coop xion city` | Warps EVE into SBO Xion at the city point (-8304, 7201, 225) |
| `coop xion gate` | The same at the gate point (-23393, 17287, 1285) |
| `coop xion leave` | Asks SB's reload of the co-op save. The native part runs it only from SBO Xion |
| `coop xion status` | One line: the pak, the rows, the native part's last answer, EVE's place, the nearest waypoint, the recovery's state, the rooms' state, the threshold doors' state and the last look: its age, the characters with the nearest one, the levels, the zone, the area and EVE's life state |
| `coop xion recover on`, `death` or `off` | Inside SBO Xion: what the module does after a fall or a death, until the next arrival ([Falls and deaths](#falls-and-deaths)). Alone, it prints the recovery's state |
| `coop xion rooms on` or `off` | Inside SBO Xion: `off` puts SB's pieces back in the doorways of [the rooms](#the-rooms) until `on` or the next arrival, so the doors are closed as SB ships them. It turns [the threshold doors](#the-threshold-doors) off for the same time. Alone, it prints the rooms' state and the threshold doors' state |
| `coop xion tetrapod in` or `out` | Inside SBO Xion: puts EVE inside the Tetrapod or back in front of it, from wherever she stands ([The Tetrapod's door](#the-tetrapods-door)). Alone, it says whether she is inside |

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

`recover.lua` handles both cases at each 250 ms pass while EVE is in SBO Xion. Three game tests ran it:

- 2026-11-23: three falls were caught. EVE walked 0.3 s after each move.
- 2026-11-24: [the black](#the-black) showed over a put-back. EVE also left the city at a second place west of the
  arrival square, near (-11272, 9451). The first one is near (-10823, 9941). Both are on the long bridge between the
  arrival square and the hub. SB's own block walls stand along both sides of it, 210 cm high (`BP_BlockWall33` to
  `54`), in a level SBO Xion keeps. A jumping EVE passes over them.
- 2026-11-25, build v0.11.0-1070-gcda5c388: the death rule. EVE died in the Tetrapod and the in-place respawn
  brought her back ([A death](#a-death)).

`coop xion leave` has not run in game.

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
it logs the result. If EVE lives it tells SB's death screen that its revival ended, so SB gives back the mouse cursor
the screen holds. It then hides a death screen that still plays. A hide that raises gives one line. The result is
still logged with the screen `up` and counts no failure. If EVE is not walking, or is under -3275, the
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

The respawn ran in game for the first time on 25 November 2026 (build v0.11.0-1070-gcda5c388), after EVE died in the
Tetrapod. It brought her back:
life 3 to 1, the same pawn, walking, the death screen off by itself. The mouse cursor then stayed free during play.
SB's death screen takes the cursor when it opens. It gives it back when its logic gets the event that ends its fade
or its revival animation. The in-place respawn plays neither, so the screen kept the cursor.

Since then the module calls `NotifyBlueprint("FinishComaRevivalAnimation")` on the death screen's widget once the
result reads alive. That is the event SB's own revival ends with. SB's handler for it gives the cursor back and sets
the screen's logic to its idle state. On a screen that holds no cursor the give-back does nothing. The log says
`respawn: death screen told its revival ended`, or why it was not told: no widget, or the error of the call.

The call has not run in game. SB first offers the event to the widget's blueprint (`ConsumeNotifyBlueprint`). Its
handler gets the event only when the blueprint does not consume it. Blueprints are not readable in Ghidra, so the log
line says that the call was made, not that the cursor came back.

In that same run, Esc pressed 25 s later crashed the game inside UE4SS. That call did not come from this module. It
came from a test build of the pause menu's Online page, which took the shown cursor for a paused game.

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

The floor is one height for the whole map, so a roof or a ledge outside the city above -3275 counts as ground. With
the paks of 23 and 24 November lift doorway A and the other edges one step leads out from are open. The recovery is
what brings EVE back from those.

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
| `sboxion: respawn: death screen not hidden: <why>` | The hide of a death screen that still plays raised. The result line follows with `death screen up/up` |
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

The game tests of 2026-11-23 and 2026-11-24 answered two points of this list. A fall is caught, with EVE walking
0.3 s after the move. `LoadingScreenFadeAuto` called from Lua shows SB's black over the move. The test of 2026-11-25
answered a third: SB's respawn job brings EVE back in a zone of type 5 ([A death](#a-death)). Still not known: what
the death screen shows after its left button, whether `coop xion leave` passes at all and with a dead EVE, whether
EVE can move under the black and what SB's pause menu does to it.

## The walls

The walls were tried on 24 November 2026. Each arrival queued 145 invisible walls at 22 edges where one step leads out
of the city, lift doorway A among them. One more stood in the cave at the gate point. Each wall was an engine cube with SB's
collision profile `SB_InvisiblewallIgnoreCamera`. In the game run all 145 failed with `the cube is not on the
component`, so they never made a wall in game. They were dropped for real pieces of Stellar Blade: the doors, ladders
and lift pieces of SB's own level-design sublevels. `coop xion walls` is gone. A `coop-xion-walls.txt` left by an older
build is no longer read.

## The rooms

The paks of 24 November 2026 add rooms behind closed doors of Xion: five in the first and second builds, eleven in
the third build of the full test pak. Each room is a level of its own, `/Game/SBO_World/Rooms/Xion_Rooms_<room>`, on
the streaming list of `Xion_P` as an always-loaded level. The rooms pak then lists 100 levels, 98 of them always
loaded. The third full test build lists 167, 133 of them always loaded. In the second and third builds the first five
rooms hold 510 actors: 476 pieces and 34 movable lights. The six rooms the third build adds hold 688: 647 pieces and
41 lights. A piece names one of Stellar Blade's meshes by its path. The mesh loads from the player's own game files.
No `/Script/SB` class is in a room.

A room has an open doorway of ours at the place of SB's closed door. SB's door stays where it is unless the module hides
it: the rooms would stand behind closed doors, with our open frame inside SB's closed door unit. So at each arrival the
module hides SB's pieces in the doorway of each room the pak holds. EVE then walks in through the door with no loading
screen: the room was loaded with the map.

| Room | What it is | Level | Door (X, Y, Z) | From the city point | Actors | Rows |
| --- | --- | --- | --- | --- | --- | --- |
| `D011` | Repair shop | `Xion_Rooms_D011` | (-10901, 3361, 412) | 46 m | 108 pieces, 9 lights | 4 |
| `D031` | Goods store | `Xion_Rooms_D031` | (-5854, 4, 466) | 76 m | 94 pieces, 6 lights | 4 |
| `D081` | Kitchen | `Xion_Rooms_D081` | (-6972, 1706, 475) | 57 m | 87 pieces, 5 lights | 4 |
| `D107` | Tailor | `Xion_Rooms_D107` | (8279, -5081, 1374) | 206 m | 86 pieces, 6 lights | 3 |
| `D158` | Workshop | `Xion_Rooms_D158` | (-4798, 6917, 596) | 35 m | 101 pieces, 8 lights | 8 |
| `D009` | Schoolroom | `Xion_Rooms_D009` | (-12133, 3785, 542) | 51 m | 157 pieces, 8 lights | 4 |
| `D049` | Apothecary | `Xion_Rooms_D049` | (-3711, -52, 347) | 86 m | 131 pieces, 4 lights | 5 |
| `D092` | One-room home | `Xion_Rooms_D092` | (-1607, -2372, 457) | 117 m | 85 pieces, 5 lights | 2 |
| `D036` | Tea room | `Xion_Rooms_D036` | (-5705, 7747, 592) | 27 m | 116 pieces, 9 lights | 3 |
| `D106` | Memorial room | `Xion_Rooms_D106` | (7872, 2974, 1498) | 167 m | 64 pieces, 8 lights | 4 |
| `D039` | Growing room | `Xion_Rooms_D039` | (-4743, -8, 461) | 80 m | 94 pieces, 7 lights | none |

The first five rooms are in every pak that holds rooms. The last six are in the third build only. The actors are
those of the second and third builds: the first build's five rooms held 394 pieces and 27 lights. The door is the
centre of the doorway. The distance is a straight line on the map from the city point (-8304, 7201, 225). The way on
foot was not surveyed. Each door of the list is a waypoint: `coop xion status` names the nearest one with its
distance.

`D039` has no rows, so its door stays closed. Two of the three pieces its layout hides are blueprint props of SB in
front of the door (`PhysicalObj_Trash_2` and `_3` of `E04_Area02_Object_B_01`). Their `StaticMesh` component
simulates physics and starts asleep. How the calls below act on a simulated body was not read in the game's code.
With the third build the room loads behind SB's closed shutter. EVE gets in through
[a threshold](#the-threshold-doors).

### What is hidden

`rooms/list.lua` holds 41 rows for ten rooms. A row is one piece of SB in a doorway: the closed door unit or shutter
(a mesh of `Architecture/Door`, the door leaf `Architecture/Bar/005_A_SM` in `D036`), the wall panel behind it
(`Architecture/Building_003`) or street debris that reaches into the doorway (`Deco/Rubble`, `Deco/Trash`,
`Deco/Beam`, `Deco/Wire`). The pieces are in 10 art sublevels that SBO Xion keeps. All of them are of Static mobility
with baked lighting. Each row was checked against the level dumps of build 26123051: the sublevel, the actor, the
component's class, its mesh, the place it stores and the instance count.

- 18 rows are whole components. The module calls `SetVisibility(false, false)` and `SetCollisionEnabled(0)` on the
  component. `D036`'s wire stores the collision profile `NoCollision`. The module writes back the value it read.
- 23 rows are one instance of an instanced component. 18 components hold them, with 2 to 54 instances each. The
  other instances stay. `D036` hides instance 6 of the debris component whose instances 0 to 3 `D158` hides. Each
  row keeps its own instance's values. The module scales the instance to nothing where it stands, with
  `UpdateInstanceTransform`. It never removes an instance: the engine would move the last one into the hole. The
  baked lightmap rows go by index.

Before it hides a row the module compares the live object with the row: its class, its mesh, the place it stores
(within 1 cm on each axis) and, for an instance, the number of instances of its component. A game update that
reorders a level then hides no other piece. It reads the values it is about to change and keeps them: the visible
flag and the collision value of a component, the rotation, place and scale of an instance.

A room opens as a whole or stays closed. Every row of the room is found and compared first. Then all are hidden. If
one row is not found or cannot be hidden, the rows hidden before it are put back and the room's door stays as SB
ships it. The log names the row and the reason. The other rooms open. A facade with one of SB's pieces left in it is
worse than a closed door.

The calls were read in the game's code on build 26123051. None of them tests the mobility.

- `SetVisibility` (`0x14410dfb0`) flips the component's visible flag and marks its render state dirty
  (`0x14408e490`). The engine makes the render state again at the end of the frame. It adds the component to the
  scene only when the flag is set (`0x1440e7a10`, `0x1440e8fb0`, `0x14410de00`). The hidden component is not drawn.
  The shadow it baked onto its neighbours stays.
- `SetCollisionEnabled` (`0x144495c70`) writes the value into the body instance, then ends the physics state
  (`0x1440e84c0`, `0x1440e9000`): the body leaves the physics scene (`0x144143960`). The value read before, written
  back, makes the body again. The body instance's profile name reads `Custom` afterwards. Its responses are kept.
- `UpdateInstanceTransform` on a hierarchical component (`0x14424e0c0`, then `0x14427eeb0`) writes the instance's
  matrix. With a scale of 0.0001 or less on each axis it ends the instance's body and deletes it (`0x14427ed70`). A
  larger scale makes a new body. That is the engine's own state for an instance with no body.
- What is drawn after that call depends on the component. A component that kept a CPU copy of its instance buffer
  gets the new matrix written into the buffer. The tree cooked with the level stays. The copy is kept by a
  component that casts a shadow and affects distance field lighting while `r.GenerateMeshDistanceFields` is on
  (`0x144281ec0`). SB's `DefaultEngine.ini` sets it. A component without the copy starts an async build of a new
  tree and a new instance buffer from its instances (`0x1442511b0`, `0x144251400`, `0x144250d90`). The instance is
  drawn until the build is taken over, some frames later. 8 of the 18 components store `CastShadow` false: six
  debris components (two of `D011`, one each of `D081`, `D107`, `D049` and `D106`) and the two shutter components of
  `D092`.

### When a room opens and closes

After each arrival the module looks at the streaming levels once a second while a room waits. A room is decided
once its own level and every sublevel of its rows read loaded and visible. All levels are always loaded, so the
rooms open in the arrival's first pass. A room whose levels are not there after 30 s stays closed. A room the pak
does not hold is not looked at, waited for or counted.

A map change, `coop off` and `coop xion rooms off` put every hidden row back, the last hidden first.
`coop xion leave` ends in a map change. The module writes only on an object that is still the one it found. After a
map change the world is gone with its levels and nothing is called. Nothing is hidden in any other map: SB's own Xion
is never changed. At `coop off` and at a map change the recovery ends first. The rows are put back after it.

`coop xion rooms off` closes the doors until `coop xion rooms on` or the next arrival. SB's door unit comes
back with its collision: type `off` outside the doorway. `on` asks the pak and opens the rooms again.

The module keeps what it read before each hide in `coop-xion-rooms.txt`, one line. After a Lua reload (Ctrl+R) the
first pass in SBO Xion puts those rows back, until the first one that is not found. The arrival then hides them
again. A file left by a game that closed inside SBO Xion changes nothing in a new world: its components read
visible and its instances read their own scale. A file that cannot be written is logged once an arrival. A file
that cannot be read is logged and nothing is put back.

### What the log shows

| Line | Meaning |
| --- | --- |
| `sboxion: levels: 100 listed, 98 of 98 always-loaded ones loaded and visible, missing: none; by volume: 2 listed, 2 loaded, 2 visible` | The rooms pak of 24 November is in and its five room levels loaded. The full test pak reads `161 listed, 127 of 127`, its third build `167 listed, 133 of 133` |
| `sboxion: rooms: none in this pak (<path>\zSBO_Xion.utoc does not hold Rooms): no door is opened` | The pak of 23 November. One line an arrival. Nothing else of the rooms runs |
| `sboxion: rooms: this pak holds n of 10 rooms: <rooms>` | One line an arrival: the rooms of the list whose level the pak holds. 5 with the first and second builds, 10 with the third |
| `sboxion: rooms: <room> open: n rows hidden, t ms` | Every row of the room is hidden. `t` is the time spent on the room |
| `sboxion: rooms: <room> closed: <row>: <why>` | One row failed. Nothing of the room is hidden. `<row>` reads `<sublevel>.<actor>.<component>`, with `[<index>]` for an instance |
| `sboxion: rooms: <room> waits for <levels>` | A level the room needs is not loaded and visible yet. Said once |
| `sboxion: rooms: <room> closed: <levels> not loaded and visible after 30 s` | The wait ended |
| `sboxion: rooms: closed (<reason>): n rows put back` | A map change, `coop off`, `coop xion rooms off` or an arrival. It adds `m gone already` for rows their world took and `k raised (<why>)` for a put-back that failed |
| `sboxion: rooms: an earlier Lua load left n rows hidden: m put back` | After a Lua reload |
| `sboxion: rooms: an earlier Lua load's rows unread (<why>): none put back` | `coop-xion-rooms.txt` could not be read after a Lua reload |
| `sboxion: rooms: rows not kept (<why>): a Lua reload could not put them back` | `coop-xion-rooms.txt` could not be written |
| `sboxion: rooms: levels unread (<why>): the rooms wait` | The level list did not read for a pass. Said once an arrival |
| `sboxion: at D158: A_01 loaded b visible b, A_03 loaded b visible b` | EVE stood 5 s within 3 m of that room's door |

The rooms' part of `coop xion status` reads `rooms 5 of 5 open`, `rooms n of 5 open, m waiting`,
`rooms n of 5 open, closed: D031, D107`, `rooms off` or `rooms none in the pak`. The second number is the count of
rooms the pak holds: 10 with the third build. The threshold doors' part follows it.

Reasons a row closes its room: `not found`, `not the class listed`, `another mesh`, `another number of instances`,
`another place`, `its instance did not read`, `it is hidden already`, `its collision did not read`,
`the engine refused its instance`, `it did not hide`, or the message of a call that raised.

### What the first game test left open

The rooms ran in game on 24 November 2026. With the rooms pak `1203_1501348` and a build of commit `af340a08` EVE
walked into the five rooms with no loading screen. With build v0.11.0-986-g9f844a09 and the full test pak
`1203_1501548` the arrival's pass opened the five rooms: 4, 4, 4, 3 and 8 rows hidden, 0 or 1 ms a room. Each of the
five has an instance row, so UE4SS read and wrote an instance's transform. The six rooms of the third build were in
neither pak.

- Light. The check of the pak expects dark rooms. The room levels hold only their own lights, 4 to 9 small ones a
  room. In editor captures of the first build made with those lights alone, 41 to 90 % of each inside view is near
  black. Only `D107` reads as a lit room there. The brighter captures of the build used a sky fill that is not in
  the levels. In the third build `D106`'s door side and `D049`'s back wall read dark. What else lights a room in game
  is not known.
- The path each instanced component takes of the two above. How long the pieces of the 8 components that store
  `CastShadow` false stay drawn while the new tree is built. `D092`'s two shutters are among them.
- The doorway's look. SB's door unit baked its shadow onto the pieces around it. Our facade has two materials. In
  four rooms a strip under the facade is closed by other pieces of SB. In `D158` a strip 7 cm high stays open
  under the floor line. `D107` has a wall edge of another colour.
- Other pieces of SB in a doorway. The 41 rows are the pieces the room layouts found. SB's levels were not searched
  for more. SBO Xion keeps `E04_Blocking_VOL`, with 409 blocking volumes: none was checked against the doorways.
- A closed room at `D009`, `D049` or `D106`. Our facade piece stands where SB's wall panel stands. If a row fails
  there, the panel stays and the two may flicker from the street.
- Collision inside. The room's floor is an engine plane whose collision box has no height. SB's own floor lies
  0.9 cm under it in the first five rooms. The six of the third build were not measured. Small clutter may block
  or not.
- The cost of the pass. Each room's line carries its ms.
- EVE in the doorway at `coop xion rooms off`. SB's door unit comes back around her.

### Testing them in game

Install a pak of 24 November with the game closed: copy its three files over the three in `SB/Content/Paks/~mods`. The
third build of the full test pak has all ten rooms of the list. The pak's own `INSTALL.md` has the commands, the three
hashes and the way back. Never keep two containers that hold `Xion_P`. Install it together with a build of the mod that
has this part. An older build hides nothing: the rooms then stand behind SB's closed doors.

On a co-op save, alone.

1. `coop xion`. Within 5 s the log has `levels: 100 listed, 98 of 98` (`161 listed, 127 of 127` with the full test
   pak, `167 listed, 133 of 133` with its third build), `rooms: this pak holds 5 of 10 rooms` and five lines
   `rooms: <room> open`, with 4, 4, 4, 3 and 8 rows. With the third build it reads `10 of 10 rooms`, then ten lines
   with 4, 4, 4, 3, 8, 4, 5, 2, 3 and 4 rows. Note each ms figure and any hitch.
2. `coop xion status` reads `pak 1203_1501348` (`1863_1918741` with the third build) and ends with
   `rooms 5 of 5 open` (`rooms 10 of 10 open`). It names the nearest waypoint.
   Walk until it reads `nearest waypoint D158`, 35 m east of the city point and 3.7 m higher, near
   (-4798, 6917, 596).
3. Look at the door from the street. It should be an open doorway with the room behind it, where SB's closed door
   stood. Note what is wrong: a piece of SB left in the doorway, a gap around the frame, debris in the air, a
   flicker, a black room.
4. Walk in. No loading screen comes. Note an invisible wall in the doorway, a step, a hole in the floor. Walk
   along the walls and to the furniture, then jump. Note where EVE passes through a piece or stands on air.
5. Stand 5 s in the doorway. The log has `at D158`.
6. Walk out, away from the doorway. `coop xion rooms off`. The log has
   `rooms: closed (coop xion rooms off): 23 rows put back` (41 with the third build). SB's closed door is back. Walk
   into it: it blocks. Note any difference from the door SB ships: its light, debris that comes back late.
7. `coop xion rooms on`. The room lines come again. The doorway is open again.
8. The same at `D011` near (-10901, 3361, 412), `D081` near (-6972, 1706, 475), `D031` near (-5854, 4, 466) and
   `D107` near (8279, -5081, 1374), in the east city. With the third build also at `D036` near (-5705, 7747, 592),
   `D009` near (-12133, 3785, 542), `D049` near (-3711, -52, 347), `D092` near (-1607, -2372, 457) and `D106` near
   (7872, 2974, 1498). Look at `D039` near (-4743, -8, 461) too: its shutter should stay closed as SB ships it.
9. Press Ctrl+R in the UE4SS console, inside SBO Xion. The log has
   `rooms: an earlier Lua load left 23 rows hidden: 23 put back` (41 with the third build), then the room lines.
10. `coop xion leave`. The log has `rooms: closed (a map change): 0 rows put back, 23 gone already` (41 with the
    third build). If the co-op save is in SB's Xion, look at one of the doors there: it is closed as SB ships it.
11. `coop xion` again, then `coop off` outside a doorway. The log has `rooms: closed (coop off): 23 rows put back`
    (41 with the third build).
    The door is closed again.

A room whose line reads `closed` keeps SB's door. Send that line: it names the row and the reason.

## The Tetrapod's door

The Tetrapod of the hangar has an open doorway that shows a dark fog. In SBO Xion it led nowhere. Since 25 November
2026 the module moves EVE through it. It needs the full test pak: the two levels below are level-design levels.

SB keeps the inside of the ship in another place. It is one blueprint actor, `BP_Env_TetraPod3_2` of the level
`E04_Area05_B_LD`, about 540 m from the hangar and 19 m lower. It has 124 parts: a cockpit with two pilot seats, a
table, a desk, beds and two side doors. The cabin is about 10.5 m wide and 16 m long. SB sends the player there with
a warp from the Wasteland (`EventZoneWarpTable` row `WLA_40_E_ZoneWarp_001`, to the point
`TeleportPoint_XionTetrapodInside`). It brings her back to the hangar at the point `Xion_Camp_10`. SB's zone events
run in `Zone_Xion_10` only, so nothing of this runs in `Zone_SBO_Xion`.

| Step | What the module does |
| --- | --- |
| The way in | EVE stands 0.5 s in the doorway of the hangar or on the top of its steps: X -13437 to -13093, Y 19330 to 19771, from Z 150. The doorway itself is the box of SB's entrance fog, from Y 19572. She is put inside at (16638, -24558, -1852), 2.3 m from the ship's right door, facing the cabin |
| The way out | Inside, EVE stands 0.5 s in front of the right door, the one with a step. She is put at SB's point in front of the Tetrapod, (-13413, 18383, 82), 11.9 m from the doorway |
| After a move | Nothing is looked at for 2 s |

Each move is made as [a fall's put-back](#a-fall) is: [SB's black](#the-black) first, the teleport 0.5 s later. While
the recovery waits or handles a fall or a death, the door counts nothing. `coop xion tetrapod in` and
`coop xion tetrapod out` ask the same move at once from anywhere in SBO Xion.

SB ships the ship with no floor to stand on: its blueprint gives all 124 parts the collision profile `NoCollision`.
In the first game test (25 November 2026, build v0.11.0-1064-g1f41affb) EVE fell through it twice and the recovery
brought her back to the hangar.
The meshes carry collision shapes and name `BlockAll` as their own profile, so the way in gives every part SB's
`BlockAll`. The way out and `coop off` give them `NoCollision` again.

The first fix set every channel of each part to block. In the second game test (25 November 2026, build
v0.11.0-1070-gcda5c388) EVE stood in the ship and died in the same pass. SB's `DefaultEngine.ini` leaves `BlockAll`
at each custom channel's own default: Ignore for `Water`,
`Volume`, `LogicCollision`, `FluidTrace`, `SoundOcclusion` and `CameraAnim`, Overlap for `Projectile`. The module
now sets the profile by its name and no channel of its own. Which of those channels killed her was not traced.

The ship's level is loaded by volume, so it may come in after EVE. After the way in the module watches her until
she walks. When she reads 60 cm under the point, it puts her on the point again and asks the ship again if it was
not found. A black that is up at once comes every 1.5 s while that lasts. After 8 s with no floor she is put back
outside.

| Line in `UE4SS.log` | Meaning |
| --- | --- |
| `sboxion: tetrapod: door on: in at (16638, -24558, -1852), out at (-13413, 18383, 82)` | An arrival in SBO Xion |
| `sboxion: tetrapod: in asked (EVE stood 2 passes at (x, y, z)); black up in 0.3 s; EVE moves in 2 passes` | EVE stood in the doorway. `out asked` is the same from the ship's door. After `asked (coop xion tetrapod in)` the command asked it |
| `sboxion: tetrapod: in: EVE at (16638, -24558, -1852), yaw -132.2` | The move was made. `out: EVE at (-13413, 18383, 82), yaw -87.2` is the way out |
| `sboxion: tetrapod: in: EVE stands in the ship after n passes, 124 parts solid` | She walks on the ship's floor. `ship not found` in place of the parts: the ship's actor was not in memory |
| `sboxion: tetrapod: in: no floor yet under EVE at (x, y, z): on the point again (...)` | She fell 60 cm. Said once a way in |
| `sboxion: tetrapod: in: no floor under EVE after 32 passes (...): back outside` | 8 s with no floor. She is at SB's point in front of the Tetrapod |
| `sboxion: tetrapod: in: EVE is out of the ship at (x, y, z) before she stood: the watch ends` | The recovery moved her |
| `sboxion: tetrapod: ship as SB ships it again: 124 parts` | The way out or `coop off` |
| `sboxion: tetrapod: ship: unread (...)` | The call on the ship's parts raised. Said once a stay |
| `sboxion: tetrapod: in: the move to (...) was refused by K2_TeleportTo` | The engine refused the teleport. EVE stays where she is |
| `sboxion: tetrapod: door off until the next arrival: error (...)` | A pass raised. The door does nothing more until `coop xion` |

In the second game test EVE walked in by the doorway: she stood at (-13231, 19490, 368) and the move was asked. The
log read `EVE stands in the ship after 1 passes, 124 parts solid`, so the ship was there at the first pass. What the
two tests left open:

- Whether EVE lives in the ship with SB's `BlockAll`. With every channel blocked she stood on its floor and died.
- Whether the point inside is free floor. In the second test it lay 10 cm in the floor and the engine pushed her up
  and aside. It now lies 3 cm over the place where she stood. That point was not seen in game.
- Whether EVE can reach the box in front of the right door. The step is on that side by the bounds of the floor
  part `001_F_SM4`.
- How the cabin is lit and what SB's lights there do in `Zone_SBO_Xion`.

Testing it in game, alone, on a co-op save, with the full test pak:

1. `coop xion`, then walk to the hangar and up the steps of the Tetrapod into the dark doorway. Stand still. Within
   1 s the screen fades to black and EVE stands inside the ship.
2. If nothing happens after 3 s, type `coop xion status`, note EVE's place, then `coop xion tetrapod in`.
3. Inside, walk around. `coop xion tetrapod` answers `EVE is inside the Tetrapod, door on`.
4. Walk to the door on the ship's right side and stand in front of it. The screen fades and EVE stands in front of
   the Tetrapod of the hangar. If nothing happens, `coop xion tetrapod out`.
5. Send `UE4SS.log` with the `tetrapod:` lines.

## The threshold doors

46 doors of Xion got no walk-in room: a merged shell of SB crosses the doorway, the opening does not lie on the
room's box, or a sill or a beam stays. A threshold room stands behind such a door. It is closed on all four sides and
SB's door stays shut. Nothing of SB is hidden. EVE pushes the door, SB's black comes and she stands inside.

`rooms/list.lua` lists nine threshold rooms. None of this has run in game.

| Room | What it is | Level | Street door (X, Y, Z) | From the city point | Size (cm) | Floor | Street door | Inner door |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `D039` | Growing room | `Xion_Rooms_D039` | (-4745, -6, 463) | 80 m | 1263 x 365 x 400 | SB's | shutter `Door/001_A_SM` | none: its own doorway is open behind the shutter |
| `D111` | Radio room | `Xion_Rooms_D111` | (10642, 888, 1464) | 200 m | 750 x 550 x 400 | SB's | `Door/031_B_SM` | `Door/031_B_SM` |
| `D157` | Canteen | `Xion_Rooms_D157` | (-3459, -2441, 463) | 108 m | 1070 x 730 x 400 | SB's | `Door/031_C_SM` | `Door/031_A_SM` |
| `D109` | Bookshop | `Xion_Rooms_D109` | (9250, 1494, 1334) | 185 m | 788 x 528 x 387 | SB's | shop front `Store/001_G_SM` with two shutters | wood leaf `Bar/005_A_SM` |
| `D029` | Courier office | `Xion_Rooms_D029` | (-6117, 4973, 215) | 31 m | 470 x 630 x 400 | SB's | `Door/031_A_SM` | `Door/031_A_SM` |
| `D030` | Wash house | `Xion_Rooms_D030` | (-6045, 2184, 93) | 55 m | 590 x 450 x 326 | its own | `Door/031_B_SM` | `Door/031_B_SM` at scale 0.855 |
| `D037` | Watch post | `Xion_Rooms_D037` | (-5189, 4595, 106) | 41 m | 250 x 630 x 400 | SB's | `Door/031_C_SM` | `Door/031_A_SM` at X scale 0.944 |
| `D163` | Kitchen back room | `Xion_Rooms_D163` | (-2130, 3619, 221) | 71 m | 450 x 270 x 400 | its own | `Door/031_C_SM` | `Door/031_A_SM` |
| `D164` | Goods store | `Xion_Rooms_D164` | (-1243, 4386, 221) | 76 m | 530 x 250 x 400 | its own | `Door/031_C_SM` | `Door/031_A_SM` |

The meshes are under `/Game/Art/BG/Actor/Architecture/`. The street door's place is the centre of its opening on the
street floor. The distance is a straight line on the map from the city point. Each of these doors is a waypoint:
`coop xion status` names the nearest one with its distance. A room on a floor of its own stands on the slab
`Building_003/001_P_SM`, laid under the room's floor plane. `D039`'s room is in the pak since the third build. The
eight others need a pak that holds their levels.

### The push

A door opens to a push, with no key to press. A push is three passes in a row (0.75 s) on which EVE:

- is on the ground,
- is within 100 cm in front of the door's plane and inside the opening's width,
- reads 40 to 160 cm over the door's floor (her place is the middle of her capsule),
- is turned toward the door within 50 degrees.

Running along the facade, a jump before the door and standing with her back to it do nothing. A pass that fails one
of the four starts the count again.

A door that does not answer says why. When EVE stands 2 s before a door, inside its width, either within 100 cm or
turned toward it, with no push, the log gets one `no push` line with her distance, her turn and her height beside
their limits. It comes once a door and way a stay. Where a move leaves her she is 150 cm away with her back to the
door, so standing there logs nothing.

The way in is a push on the street door. The module asks [SB's black](#the-black) and two passes later moves EVE to
the point 150 cm inside the inner door, turned into the room.

The way out is the same push from inside, on SB's closed door unit that stands on the door wall (the wood leaf in
`D109`). The module moves her to the point 150 cm in front of the street door, turned away from it. At `D037` that
point lies 70 cm left of the opening's centre and at `D157` 40 cm left, where the street is free of SB's props.
`D039` has no inner door: its own doorway is open and runs 94 cm to the back of SB's shutter. A push anywhere in that
passage counts.

EVE's height is no number of the module. She is put as high over the new floor as she stood over the old one at the
push, plus 10 cm. A ramp or rubble before a door then does not put her into the floor.

### After a move

The module watches EVE for 8 s after each move. The first pass that reads her walking 40 to 160 cm over the floor
she was put on ends the watch. If she reads under 40 cm over that floor, or does not stand after 8 s, the module asks
a black that is up at once and puts her back where she pushed. One line says so. That door then does nothing until
the next arrival. A teleport the engine refuses ends the same way, with EVE left where she is.

`D030`, `D163` and `D164` stand on a floor of their own. No such floor has run in game: the watch is what brings EVE
back if one does not hold her.

### Locked and opened

A door starts locked. Its first push opens it: one log line and the door's name in `coop-xion-doors.txt` in the mod
folder, one line of names. `tools/install.py` never removes a `coop-*.txt`, so the file outlives installs and game
runs. Each arrival reads it. The door then stays open for good. The file belongs to the mod folder, not to a Steam
account or a save.

A room of the list may carry `requires=<a requirement>`. Its door then opens only once the module's requirement
check answers yes. No room has one and no check exists yet. Such a door would log `stays locked: its requirement
<name> is not met` once a stay and do nothing. An opened door asks no more. The way out never asks, so a room cannot
hold EVE. `rooms/threshold.lua` answers both questions for other code: `may(name)` and `opened(name)`.

### The pak and the waits

A threshold door works only when the pak holds its room's level. The module asks the pak gate for each threshold
room on its own, as for the walk-in rooms. With the pak of 23 November and the five-room builds the arrival logs
`threshold: none of the 9 rooms is in this pak` and nothing else happens. With the third full test build it logs
`threshold: this pak holds 1 of 9 rooms: D039; opened: none`. With the fourth it logs `this pak holds 9 of 9 rooms`.

The pak holding a room's level does not say the game loaded it. So a way in also reads the streaming list once a
whole push. It needs the room's level loaded and visible. A level that is not there keeps its door shut: no black,
no move, nothing opened. The log says `stays shut` once a door a stay. A read that fails counts as not there. The
door works once the level is there. The way out never asks. Without this check EVE would be put behind the facade
of a room that is not there. At `D029` SB's floor runs on under the room, so the watch would not catch it.

The doors count nothing while the recovery waits (no EVE, photo mode, a cutscene, a warp, another zone) or handles a
fall or a death. They count nothing while [the Tetrapod's door](#the-tetrapods-door) moves EVE. The Tetrapod's door
counts nothing while a threshold door moves her. `coop xion tetrapod in` and `out` are refused for that time. A move
already asked is still made and watched. `coop xion rooms off` turns the doors off until `on` or the next arrival.
Nothing is ticked after `coop off`. An error in a pass turns the doors off until the next arrival.

### What the log shows for a threshold

| Line in `UE4SS.log` | Meaning |
| --- | --- |
| `sboxion: threshold: this pak holds n of 9 rooms: <rooms>; opened: <rooms>` | Each arrival: the threshold rooms the pak holds and those of them whose door is opened. `opened: none` with none |
| `sboxion: threshold: none of the 9 rooms is in this pak` | Each arrival with an older pak |
| `sboxion: threshold: <room> opened for good (kept in the door file)` | The first push of that door. `(the door file was not written: <why>)` when `coop-xion-doors.txt` could not be written: the door is open until the mod reloads |
| `sboxion: threshold: <room> in asked (EVE pushed 3 passes at (x, y, z)); black up in 0.3 s; EVE moves in 2 passes` | A push on the street door. `out asked` is the push on the inner door. The black's part reads as in [a fall's lines](#what-the-log-shows-after-a-fall-or-a-death) when SB made no black |
| `sboxion: threshold: <room> in: no push in 8 passes with EVE at (x, y, z): d cm before the door's plane (100 at most), turned t degrees from the door (50 at most), h cm over its floor (40 to 160)` | EVE stood 2 s close to that door or turned toward it and one of the three numbers is out of its limit. Once a door and way a stay |
| `sboxion: threshold: <room> in: EVE at (x, y, z), yaw y` | The move was made, to the point inside. `out:` names the point outside |
| `sboxion: threshold: <room> in: EVE stands on the room floor after n passes` | The watch ended well. `out: EVE stands on the street` |
| `sboxion: threshold: <room> in: EVE fell under the room floor to (x, y, z) after n passes: back at (x, y, z) where she pushed; this door does nothing more until the next arrival` | She read under 40 cm over the room floor: at least 57 cm under where she stands |
| `sboxion: threshold: <room> in: EVE does not stand on the room floor after 32 passes, at (x, y, z) in mode m: back at (x, y, z) where she pushed; this door does nothing more until the next arrival` | 8 s without a walking read 40 to 160 cm over the room floor |
| `... the move back to (x, y, z) was refused by K2_TeleportTo; this door does nothing more until the next arrival` | The end of the two lines above when the engine refused the put-back |
| `sboxion: threshold: <room> in: the move to (x, y, z) was refused by K2_TeleportTo; this door does nothing more until the next arrival` | The engine refused the move. EVE stays where she is |
| `sboxion: threshold: <room> out: ...; the way out stays open` | The end of the four lines above for a way out that failed. EVE is back inside. The next push on the inner door tries again, so a room cannot hold her |
| `sboxion: threshold: <room> stays locked: its requirement <name> is not met` | A locked door with a requirement, once a stay |
| `sboxion: threshold: <room> stays shut: its level <level> reads loaded l visible v` | A push on the street door of a room whose level is not loaded and visible, once a stay. `is not on the streaming list` when the map does not list it. `the levels did not read (<why>)` when the read raised |
| `sboxion: threshold: the door file did not read (<why>): no door is opened from it` | `coop-xion-doors.txt` raised an error at an arrival |
| `sboxion: threshold: off until the next arrival: error (<why>)` | A pass raised. No threshold door does anything until `coop xion` |
| `sboxion: at D037: A_01 loaded b visible b, A_03 loaded b visible b` | EVE stood 5 s within 3 m of that room's street door |

The threshold doors' part of `coop xion status` reads `threshold doors 9 in the pak, 2 opened`,
`threshold doors none in the pak` or `threshold doors off`.

### What was measured

Every number comes from the paks of build 26123051, read with the map tools outside the repository. None was seen in
game.

- Each threshold was compared with the door's data. The street point lies on the opening's axis within 0.3 cm. The
  way in is the door's outward yaw plus 180 degrees. The half width is half the opening.
- For the seven doors of the `Door/031` family the door's plane is the middle of the unit's depth. On SB's collision
  shapes the leaf of each of the nine street doors stands from 18 cm behind its plane to 2 cm in front of it. On the
  room side the leaf of the inner door stands 13 to 33 cm in front of the door wall.
- SB's vending machine `Deco/VendingMachine/005_A_SM` stands before the right half of `D157`'s door, 54 to 64 cm in
  front of the plane. Push that door on its left half. Rubble lies before the right edge of `D037`'s door.
- At the nine points outside SB's collision floor lies within 7 cm of the street point's height. `D030`'s door is at
  the top of a ramp: the floor rises 14 cm over the last 150 cm.
- In two game runs of 24 November 2026 EVE read 97 cm over SB's collision floor at the city point.

Not known:

- Whether a body gets close enough to every door. The radius of EVE's capsule was not read.
- Whether the yaw the module reads, her actor's rotation, follows the way EVE walks while she pushes a door. The
  `no push` line shows both numbers.
- Whether the engine accepts each point inside and outside.
- Whether the floors of `D030`, `D163` and `D164` hold EVE.
- How the rooms are lit in game and what the black looks like over a move of this length.

### Testing a threshold in game

On a co-op save, alone, with a pak that holds the rooms. `D039` can be tested with the third full test build.

1. `coop xion`. The log has `threshold: this pak holds n of 9 rooms: ...; opened: none`.
2. Walk until `coop xion status` reads `nearest waypoint D029`, 31 m from the city point near (-6117, 4973, 215).
   With the third full test build walk to `D039` near (-4745, -6, 463) instead.
3. Run along the facade past the door. Then stand 3 s with EVE's back to it. Nothing should happen.
4. Walk into the door and keep walking into it for a second. The screen fades to black and EVE stands inside,
   looking into the room. The log has `opened for good`, `in asked`, `in: EVE at` and `in: EVE stands on the room
   floor`. If nothing happens, keep walking into the door for 3 s and look for a `no push` line: it names the number
   that is out of its limit. Try the other half of the door too. A `stays shut` line means the room's level did
   not load: send it with the `sboxion: levels:` line of that arrival.
5. Inside, walk along the walls and jump. Note a hole in the floor, a prop in the way, a dark room.
6. Turn to the door she came in by and walk into it for a second. The screen fades and EVE stands in the street with
   her back to the door. The log has `out asked`, `out: EVE at` and `out: EVE stands on the street`.
7. `coop xion rooms off`, then push the door for 3 s. Nothing happens. `coop xion rooms on`.
8. The same at `D037`, then at `D163`, `D164` and `D030`, the three rooms on a floor of their own. A line with `fell
   under the room floor` means that floor did not hold her. Then `D157` (on its left half), `D109` and `D111`.
9. Close the game and start it again. After `coop xion` the arrival line ends with `opened:` and the doors pushed
   before. `coop-xion-doors.txt` in the mod folder holds their names.

Send the `threshold:` lines of `UE4SS.log`.

## The full test pak

The third pak of 24 November 2026 is a test build. It loads the levels of Xion as Stellar Blade ships them,
level-design levels included and nothing removed from them. Its test asks what wakes up in `Zone_SBO_Xion` and
whether the game holds. The pak was built and checked outside the game.

Its first build (`1203_1501548`) ran in game on 24 November 2026 with build v0.11.0-986-g9f844a09, alone on a co-op
save. The `zone:` line read type 1 for the first 5 s after the arrival, then type 5 `Zone_SBO_Xion` for the rest of
the run, never a zone of Xion's own. No NPC spawned: the characters were EVE, her drone and one
`CH_NPC_Dororong_BP_Seq_C` 110 m away. The 127 always-loaded levels loaded and the volume levels loaded as EVE
walked. The five rooms opened. SBO logged no Lua error. The 13 Lua errors in `UE4SS.log` (`LUA_ERRRUN`) come from
another mod.

### What it loads

`Xion_P` lists 161 levels. 127 are always loaded. 34 stream by SB's own volumes, as SB ships them.

- The 95 levels of the first pak.
- 14 levels of the underground: the lower end of the lift with its hall, the Elder's chamber in its peace state and
  the hyper drive room. 10 of them stream by SB's volumes. 4 are always loaded.
- 47 of Xion's 50 level-design levels.
- The five room levels, the same as in the rooms pak.

The third build lists 167 levels, 133 always loaded. Its six more room levels take the streaming slots of six levels
of the list below, which the set never shows: `E04_Area01_Light_OFF_VER`, `E04_Area02_Light_OFF_VER`,
`E04_Area02_Light_Night`, `E04_Area04_Light_Night`, `E04_Area06_Light_A_01_Battle` and `E04_Area06_FX_A_01_Battle`.

24 levels of SB's Xion stay out: 5 light variants for the night and the story phases before the day light, the
chamber's battle state (2), 4 light phases of the hyper drive room, the 6 cutscene levels, the theater set, one far
view, the effects level with the 12 rats and the Elder's body. The 3 level-design levels left out are the two Boss
Challenge arenas (`E04_LD_RavenBeast_01`, `E04_LD_Mann`) and the refugees of story phase 5
(`E04_Area01_A_LD_5Phase_Unload`).

What the 47 level-design levels hold, read in the paks of build 26123051:

- 263 spawn points. 155 of their rows spawn an NPC, each in a zone of Xion's own, 111 of them when the player enters
  that zone. Each row has its own story conditions (`Xion_Phase_2`, `Xion_Phase_5`, side quests).
- 15 zone volumes. The city point (-8304, 7201, 225) and the gate point both lie inside `Zone_Xion_10_A` and
  `Zone_Xion_10_B2`.
- 117 zone triggers. Some end in a warp. `Xion_10_ZTrigger_102`, 7 m from the city point, warps to the camp
  `Xion_Camp_10` of SB's world `Xion`.
- 13 doors, among them SB's closed lift door in lift doorway A at (3982, -9162, 1222) with its open twin at
  (3958, -9124, 1222). The lever of the second lift with its deck at the top. 5 ladders, 2 ledges and 1 rope.
- Camps with their chairs and teleport machines. Teleport machine 4 stands 1.5 m from the city point.
- 19 fall volumes under the city, active in `Zone_Xion_10`. The pit's fall volume under ground is active in
  `Zone_Xion_22`.

### What the module does with it

The same as with the rooms pak. The rooms open as before. The recovery catches EVE under Z -3275 while the zone is
`Zone_SBO_Xion` and waits while it is another. The levels line counts the 34 volume levels apart. The look lines say
what wakes up ([What the log shows](#what-the-log-shows)). Nothing pins the pak's version: `coop xion status` prints
`pak 1203_1501548`, `pak 1203_1546008` for the second build and `pak 1863_1918741` for the third.

### What is not known

- Whether SB changes the current zone from `Zone_SBO_Xion` to one of Xion's own while EVE stands in its volumes. In
  the run of 24 November it did not, where EVE walked. How SB picks one among overlapping zone volumes was not read.
  Why the zone read type 1 for the first 5 s was not looked at.
- While the zone is `Zone_SBO_Xion`, SB's zone warp does not run: `0x141cdfe70` writes no warp when `0x141cf7630`
  reads type 5 in the current zone's row. If the zone turns to one of Xion's own, that guard no longer holds. A
  warp trigger, a camp or a teleport machine could then take EVE to SB's own Xion, since its row names the world
  `Xion`. Copy the co-op save files before the test.
- Which NPCs spawn. That depends on the story state of the co-op save EVE is built from.
- What `SBAIWorldManager_0` of `E04_LD_MetalAI` starts. What the 154 env actors and the sequences of their start
  states do. Some of those sequences load, unload or hide streaming levels by name.
- The memory and the frame time of the 61 added levels. The 14 underground levels alone hold 379 MB of build data.
  `E04_Area07_Light_A_03` adds 226 movable lights under ground, loaded from the start.
- The way down. The module has none. SB's lift is a trigger, a cutscene and a zone warp, which the type-5 test
  refuses. The recovery's floor of -3275 would also catch EVE as soon as she stood under ground.

### The game test

Close the game. Copy the co-op save files (`StellarBladeCoop0N.sav`, [Saves](../../players/saves.md)) to a folder
outside the game. Copy the pak's three files over the three of the rooms pak in `SB/Content/Paks/~mods`. The pak's
own `INSTALL.md` has the commands, the three hashes and the way back. Never keep two containers that hold `Xion_P`.

On a co-op save, alone.

The rule of this test: read the zone before each step. `coop xion status` shows it. Go on only while it reads zone
type 5 and area `Zone_SBO_Xion`. If it reads anything else, Stellar Blade took EVE into one of its own zones. Its
triggers, its saves and its warps then work again. Stop walking. Do not jump. Leave by Stellar Blade's title menu:
`coop xion leave` is refused outside `Zone_SBO_Xion`. Then put the copied co-op saves back.

1. `coop xion`. Do not move. Within 15 s the log has `levels: 161 listed, 127 of 127` (`167 listed, 133 of 133` with the
   third build), the `rooms: <room> open` lines (five, or ten with the third build), a `characters:` line,
   `zone: zonetype 5 area Zone_SBO_Xion` and `life: 1`. Note any hitch.
2. `coop xion status`. Note the look part: the count of characters, the nearest one, the zone.
3. Stand still for 2 minutes, then walk on the arrival square for 1 minute. Stay out of the box 7 m to the north
   around (-8340, 6502, 403): a trigger of Stellar Blade's camp warp stands there. Note every NPC, guard or merchant,
   a teleport machine and any cutscene. Type `coop xion status` again and note the zone.
4. Climb the ladder `BP_EM_Ladder3` at (-9973, 7549, -234), west of the arrival square, with its two ledges beside
   it. Then the ladder `BP_EM_Ladder5` at (-12218, 22514, -470), on the south rim of the round plaza. Note whether
   EVE can grab them and climb.
5. Only if the zone still reads type 5: jump off the long bridge near (-10823, 9941). Note who brings EVE back: the
   module (a `black:`, a `fall:` and a `put back:` line) or SB itself (no `fall:` line, maybe a `zone:` line first).
6. Only if the zone still reads type 5: walk to lift doorway A near (3958, -9124, 1222). The lift hall is the place
   with the most triggers: a zone volume of `Zone_Xion_11`, the lift's cutscene and warp at the doorway and a
   cutscene trigger at (4578, -9973, 955). Look at the doorway from 5 m first: a closed lift door of Stellar Blade
   should stand in it. Then walk into it. Note whether it blocks EVE, whether a cutscene starts and the zone.
7. `coop xion leave`. The log has `left`. `coop-link.log` has `sboxion leave: ... reload call 1`.

Do not use `coop xion gate` in this test. Do not walk into the cave at the west gate: Stellar Blade's exit trigger to
the Wasteland stands there.

Send the `[SX]` lines of `UE4SS.log` and `coop-link.log`. The fall steps of [Testing it in
game](#testing-it-in-game) under Falls and deaths walk through lift doorway A: with this pak a door should stand
there.

### Back to the rooms pak

Close the game. Copy the three files of the rooms pak over the three of the full test pak in
`SB/Content/Paks/~mods`. `coop xion status` then reads `pak 1203_1501348`. The full test pak's `INSTALL.md` has
the commands and the hashes of both.

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
file with `grep -a -o SBO_Xion <file> | wc -l`. In the game test of 24 November 2026 (build v0.11.0-986-g9f844a09)
SB wrote co-op save 00 when it loaded, after the rows went in at the title. Nothing was written inside SBO Xion. The
count read 0.

## What the log shows

Each line below is one proof of the test. They are in `UE4SS.log` unless said.

| Line | Meaning |
| --- | --- |
| `sboxion title: the rows are in, before any save loads` and `sboxion rows: 2/2 in` | The two rows went in at the title and read back as written |
| `sboxion enter: zone row found, type 5, world row found, call 1, to (x, y, z) yaw y, queue q, last save t` (`coop-link.log`) | The native guards passed and SB's warp returned 1 |
| `sboxion: arrived, map /Game/SBO_World/Xion_P, zone Zone_SBO_Xion, EVE at (x, y, z)` | EVE stands in SBO Xion |
| `sboxion: levels: 95 listed, 93 of 93 always-loaded ones loaded and visible, missing: none; by volume: 2 listed, 2 loaded, 2 visible` | Every always-loaded sublevel loaded from the game's own files. With the rooms pak: `100 listed, 98 of 98`. With the full test pak: `161 listed, 127 of 127`. The levels streamed by SB's volumes (the 34 of `data.lua`'s `VOLUMED`, two with the older paks) are counted, never named as missing: they load and show where SB's volumes say |
| `sboxion: light: 72 env volumes found, 65 in E04_ENV_VOL, 41 named, 21 changed, CountDown_Posing_ENV active true` | The day table was written |
| `sboxion: light: 41 of 41 read back as written` | The writes held, 2 s and 10 s after the arrival |
| `sboxion: characters: 1` | EVE is the only character. With more: `characters: n by class: <class> <count>, ...; nearest: <name> (<class>) d m, ...`. The classes come the most first. Only the five nearest to EVE are named, with the distance in metres. EVE is counted, never among the nearest. Logged at the arrival, 10 s later and at each later look whose count by class or five names differ |
| `sboxion: zone: zonetype t area <alias>` | The zone type and the area of the `engine=` line of `coop-status.txt`, at the arrival. Each change adds `, EVE at (x, y, z)`. `zonetype 5 area Zone_SBO_Xion` is SBO Xion's own zone. `area none` means the world and the logic name different zones. `zone unread (...)` means the group's native read is off |
| `sboxion: life: n` | EVE's life state (ESBActorLifeState) of the `sboxionwarp=` line, at the arrival. Each change adds `, EVE at (x, y, z)`. 3 to 5 are the death states [the recovery](#a-death) answers. `unread (...)` before the native part's first read |
| `sboxion: levels changed: <level> loaded b visible b, ...; EVE at (x, y, z)` | At a look, each listed level whose state differs from the look before, in the list's order |
| `sboxion: probe: start: E04_DistantView_A_01 loaded b visible b, E04_DistantView_A_03 loaded b visible b` | The two volume-streamed levels at the arrival |
| `sboxion: probe: <level> loaded b visible b, EVE at (x, y, z)` | One of the two changed state |
| `sboxion: at <waypoint>: A_01 loaded b visible b, A_03 loaded b visible b` | EVE stood 5 s within 3 m of a waypoint |
| `sboxion leave: queue q, last save unchanged, reload call 1` (`coop-link.log`) | SB's reload started and its last save time did not move since the enter |
| `sboxion: left, map <path>` | EVE is out |

The module reads the zone and the life state each second, from the status text only. It looks at the levels and the
characters 10 s after the arrival, then every 10 s. A look says only what changed. A look reads each listed level
three times and each character five times through UE4SS: with 161 levels and 156 characters that is about 1,260
calls every 10 s. Their time was not measured in game. The two probe levels are the only
ones the older paks leave volume streamed, as SB ships them. Both read loaded and
visible at the arrival, which decides nothing. A waypoint line with `visible false` and a later probe line back to
`visible true` shows that UE's volume streaming runs in a persistent level of SBO. The waypoints `kaya` (the front of
Kaya's shop) and `camp7` (the camp beside Roxanne's place) lie outside every visibility volume of both levels.
`tie` is 15 m from the city point, where two env volumes of the same priority overlap. `tree` is the place of two
Christmas sound actors in `E04_Sound`.

## How it works

Lua, in `mod/StellarCoop/Scripts/world/maps/sboxion/`:

- `data.lua`: the pak's name, the level, the two rows, the two arrival points, the 14 waypoints (four of the first
  test walk and the ten doors), the 41 names of the day table, the two probe levels, the 34 levels a pak leaves
  streamed by SB's volumes (`VOLUMED`), the recovery's numbers and the threshold doors' limits.
- `sboxion.lua`: the pak gate, asked a second time for the room levels, the rows at the title, the commands, the
  arrival and the watch.
- `recover.lua`: the ground point, the black and the put-back after a fall, the respawn after a death. Its respawn
  block is the module's copy of score attack's. Its ground read is the module's copy of the group's.
- `rooms/list.lua`: the ten rooms and their 41 rows, then the nine threshold rooms, one block a room.
  `rooms/rooms.lua`: the pass that opens a room once its levels are there, the put-back, `coop xion rooms` and the
  sweep after a Lua reload. `rooms/threshold.lua`: the push, the level read before a way in, the move under the
  black, the watch, the door file and the two questions `may` and `opened`.
- `engine.lua`: the UE4SS calls. Its black call is the module's copy of the lobby's. It also finds, hides and puts
  back a piece of a room's doorway.
  `commands.lua`: `coop xion`. `wiring.lua`: the manifest, export `sboxion`.

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

The two paks of 23 and 24 November leave out the parts below. [The full test pak](#the-full-test-pak) brings back the
underground and 47 of the 50 level-design sublevels.

- The 50 level-design sublevels: NPCs, quests, shops, camps, zone volumes, doors, ladders, the lift, SB's fall
  volumes. EVE can step or jump out of the city: [Falls and deaths](#falls-and-deaths) says what brings her back.
- The 15 underground sublevels, the theater set, one distant-view level and the light variants for night.
- `E04_Area02_FX_A_01`, which holds the 12 rats. Its 16 effects and its water body are missing with it.
- The 50 actors of the persistent level tagged `XionChristmasEvent`.
- The tunnel exit toward the first MMO map. `data.lua` keeps the old exit box as a comment.

## Tests

- `tests/lua/world/maps/sboxion/off_test.lua`: a failure of this module at load turns this module off alone.
- `sboxion_test.lua`: the words of `coop xion`, `recover` with its three modes, `rooms` with `on` and `off` and
  `tetrapod` with `in` and `out` included, `walls` refused, then the wiring's two stores, `coop-xion-rooms.txt` and
  `coop-xion-doors.txt`.
- `tetrapod_test.lua`: the ship frame, the way in and the way out with SB's black, the hold after a move, the count
  that starts again, a busy recovery, a refused teleport, an error that turns the door off and the command. Then the
  floor: the ship made solid before the move and put back at the way out and at `coop off`, EVE put on the point
  again while she falls, the end after 32 passes and a recovery that moved her out. `busy()` for the threshold
  doors: true while a move waits and while she is watched.
- `engine_test.lua` holds the call on the ship's parts: SB's `BlockAll` by a name the game has made, `NoCollision`
  at the put-back, nothing written with no actor in memory.
- `rows_test.lua`: the Lua rows against `sboxion_rows.h`, the IDs 7131 and 1000131, no name ending in `_<digits>`,
  the 41 names of the day table.
- `title_test.lua`: no ask without the pak, none on the player's own saves, one ask on the co-op save files, the
  read-back, a refusal logged once.
- `world_test.lua`: the commands' refusals and requests, then on a fake world the 41 writes matched by level and
  name, the counts 72, 65 and 41, the full test pak's 161 levels with the 34 volume-streamed ones counted apart, 155
  characters counted by class with the five nearest named, the zone, area and life lines at the arrival and at each
  change, a look that says nothing when nothing changed, the levels and characters that changed said once, the
  status line's look part, nothing read outside SBO Xion, a second arrival, a probe change logged once, a
  waypoint logged once a visit, the watch ended by a map change and by `coop off`. For the recovery: ticked only in
  SBO Xion, started again at each arrival with the point `coop xion` asked, fed by the engine's read of EVE when
  `me()` names another place, SB's black asked through the module's own wiring with the move two passes later, a
  death answered with her GUID, the hidden death screen shown again at a map change and at `coop off`, `coop xion
  recover`, the mode back to `on` at an arrival and the status line's part. For the rooms: with the pak of
  23 November one line an arrival, the pak read once more a Lua load, no piece asked; with the five room levels in
  the pak the five rooms opened in the arrival's pass, with two of them those two, with the eleven of the third
  build the ten of the list, their part of the status, `coop xion rooms`, no row called
  once a map change took the world, every row put back at `coop off`, the recovery ended before the rooms close at
  `coop off` and at a map change. For the threshold doors: one line an arrival and their part of the status with
  the pak of 23 November (none), with the third build (`D039` alone) and with a pak that holds every room, each
  street door a waypoint, a push made through the module's own wiring with one read of EVE a pass, the opened door
  in the doors' own store and read again by a new Lua load, the doors off and on with `coop xion rooms`, a cutscene
  and a death that make them wait, a door kept shut while its room's level does not show, a threshold door and
  the Tetrapod's door never moving her at once, no move after `coop off`.
- `recover_test.lua`: the ground point, the fall with its black and the move two passes later, a black that is not
  shown, the move dropped or held back like a check, each guard, the check on the world's time, the two failures
  that stop the recovery, then the death with score attack's respawn cases and this module's own (no death screen
  for 5 s, a respawn that leaves EVE off the ground, a death left from the mode `off` or read during a wait).
- `engine_test.lua`: the UE4SS calls over fake objects, the recovery's included: one read of EVE a pass, no stop call
  after a refused teleport, the black's call and its three answers, the respawn's request, the death screen hidden
  and shown again. No wall call is left. For a piece of a doorway: found by its names and refused for another
  class, mesh, place or instance count, a whole component hidden with its two values read first, an instance
  scaled to nothing where it stands, a piece that reads hidden already refused, the put-back and no call on an
  object that is gone.
- `rooms/list_test.lua`: the ten rooms, their 41 rows as the level dumps gave them, 18 whole components and 23
  instances of 18 components in 10 sublevels, no piece twice, each door a waypoint. Then the nine threshold rooms:
  no rows, the numbers of each layout one line a room, the inner door 60 to 280 cm behind the street door, each
  standing point 150 cm from its door, a passage at `D039` alone, no requirement.
- `rooms/threshold_test.lua`: the pak cases (every room, none, one, a gate that raises), the push with each of its
  limits tried 1 cm or 1 degree on both sides, both ways, a push that fails said once a door and way a stay and
  what says nothing, the black before the move, the height kept, the watch
  with a late landing, a fall, a floor far below or above, 32 passes without standing and a refused move, the door
  whose way in does nothing more for the stay while its way out still answers, the first push that opens a door
  and writes the file, a new Lua load that reads
  it, a file that cannot be written or read, a requirement not met and met, a room level that is not loaded, not
  visible, off the streaming list or unread, busy passes, off and on, an arrival that drops a move, an error in a
  pass.
- `rooms/rooms_test.lua`: one line and no read with a pak that has no room, the five rooms opened in one pass, a
  room that waits for a level and closes after 30 looks, a row not found, a row that cannot be hidden with the rows
  before it put back, the put-back with a world that still stands and with one that is gone, `coop xion rooms`,
  the store's line and the sweep, a store that raises, a level read that raises.
- `tests/native/world/maps/sboxion/sboxion_test.cpp`: one case for each guard of the two requests, the answer word,
  the status line and the log lines, the inside flag and the `life=` word on each form of the line.
- `tests/native/rows/rows_test.cpp` runs the batch on the row engine. `tests/native/link/protocol_test.cpp` parses
  the two requests.
