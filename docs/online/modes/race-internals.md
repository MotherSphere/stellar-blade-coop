# Doro races: how they work

A Doro race runs in Lua: `online/modes/race/run.lua` on the game side, `online/modes/race/model.lua` for the rules and
the race lines, `online/modes/race/doro.lua` for the Doros, `online/modes/race/drive.lua` and
`online/modes/race/drive_model.lua` for the driving, `online/modes/race/ui/hud.lua` for the panel, the banners and the
results. The races of a match add the part folder `online/modes/race/match/` (see
[Races in a match](#races-in-a-match)). Its only SB calls are two reads on EVE, `IsSprint` and
`GetSBSpeedForAnimGraph` (for a log line); the rest are engine functions. The native part carries the race lines. Its
own part, `native/src/online/modes/race/`, holds the two game writes the races need on the game thread (see
[The native hold](#the-native-hold)). The commands and rules are in [Doro races](race.md).

## The display Doro

Each Doro the mod shows is a plain `Actor` that Lua spawns, with one `SkeletalMeshComponent` that holds Doro's mesh
(`CH_NPC_Dororong`, at the game's own scale of 1.5, about 59 cm tall) and collision off. It is not an SB character: it
has no row in the game's tables, no AI and nothing that can die. Doro's own animation Blueprint is never used. The
component runs the engine's single-node animation (`SetAnimationMode(1)`). Each frame Lua picks what it plays with
`PlayAnimation`, `SetBlendSpaceInput`, `SetPlayRate` and `SetPosition`:

- On the ground, the two-legged blend space `IdleRun_BS_Peaceful_2`, with the speed as its input up to 500 cm/s (EVE's
  run) and played faster above that, up to 1.8 times. The speed is smoothed over about 0.1 s.
- On all fours (`IdleRun_BS_Peaceful_1`) while EVE sprints, and for 0.3 s after.
- In a jump, `N_Dororong_Evade`: its first 0.5 s at take-off, its frame at 0.5 s held while she is in the air (play
  rate 0, the position set without firing notifies), and the rest, from 0.5 to 1.07 s, at landing.
- At the results, while the racer stands (under 50 cm/s): `N_Dororong_Evade` in a loop for the winner and
  `N_Dororong_Exhaust` for the other racer.
- While the race drives (see [Driving](#driving)): on all fours from 60% of the top speed and back on two legs under
  55%, played up to 3 times faster, and `N_Dororong_Exhaust_Evade` at twice its speed for the 0.6 s of a stumble. The
  Doro also leans into a bend by the speed times the turn rate of its yaw (25 degrees at 1 g, at most 25, smoothed
  over 0.15 s) and dips its nose at a landing by a degree for each 50 cm/s of landing speed (at most 15), on a 6 Hz
  spring. The lean is the rotator's `Pitch` and the nose its `Roll`, since the mesh faces its +Y; both signs are
  unchecked in game.

The mesh, the two blend spaces and the 7 clips of `Doro.ASSETS` are the keep's (`core/keep.lua`): the native part has
SB's own async loader bring them in and holds them for the game run, so `Doro.resolve` never loads one. Before the keep
has settled, or with it off for the Lua load, they come from the game's own files as before (`StaticFindObject`, else
`LoadAsset`). The engine's garbage collector unloads an asset that nothing in the engine references. A reference
held in Lua does not count. In 0.5.0-beta.1, a clip that no Doro had played for a while was unloaded. The next
`PlayAnimation` loaded it again synchronously: 5 loads a minute taking 185 ms in all while EVE sprinted, each one a
short freeze in game. Each Doro now carries one keeper per clip: a second `SkeletalMeshComponent` with Doro's mesh, in
single-node mode, given the clip with `SetAnimation`. Its animation instance holds the clip through `CurrentAsset`,
which the collector follows, so every clip stays loaded while any Doro stands. The keepers are not attached and never
move. They have `bVisible` off, so the renderer never gets them, component tick off, `VisibilityBasedAnimTickOption` 3
(pose only while drawn) and collision off. They go with their Doro's actor; on the ghost, whose actor stays, they go
when Doro mode ends. With the keep off, a clip that is not in memory is loaded when a Doro is made, not during the race.

A race shows at most two Doros of its own: before GO one at the start line's centre, and during the race one at the next
checkpoint and one at the one after it, facing the checkpoint before them. Their object paths stay in
`coop-race-doros.txt` while they stand, so a Lua reload (Ctrl+R) in a race destroys them at its first tick.

## The Doro look

The look draws your EVE as a Doro. Its Doro is placed each frame, after the native tick, at the world location and
rotation of EVE's main mesh (her feet); it is not attached to her. The look and the race's driving (below) are the
features that write to the player actor. Two things change on her. The look also hides the drone:

- `bHiddenInGame` on each of EVE's mesh components that did not have it, through `SetHiddenInGame`. The game shows and
  hides her parts (a drawn blade) with `SetVisibility`, which sets the separate `bVisible` flag, so the look neither
  fights those changes nor undoes them. `SetActorHiddenInGame` on EVE is not used.
- `VisibilityBasedAnimTickOption` on her main mesh, set to 0 (always tick the pose) by the native part while the
  look asks `race tick on` (see [The native hold](#the-native-hold)). EVE's Blueprint ticks her pose only while she is
  drawn, so a hidden EVE would stop her pose, her animation notifies and the root-motion moves of dodges and ledges.
- The drone that follows EVE is an SB character of its own, so hiding EVE's parts left it flying beside the Doro. The
  look sets `bHiddenInGame` on the drone's main mesh (`CharacterMesh0`) through `SetHiddenInGame`, only when the mesh
  does not have it. It writes nothing else on the drone. The actor itself stays shown: hiding it would also turn off
  its spot light, which lights EVE's way in dark places, and its guide ray and wait signal. The look finds the drone
  with one `FindAllOf('CH_Drone_BP_C')`, the drone's Blueprint class: the nearest one of exactly that class within 30 m
  of EVE, whether the game shows it or not. `FindAllOf` walks every object on the game thread (25 to 40 ms in game), so
  it runs at look on and once more each time the drone the look holds goes, and never on a timer. If it finds none, it
  does not look again until the next look on. Once a second the look checks the held drone's mesh and hides it if the
  game showed it. A mesh the game hid is left alone until the game shows it. The log says
  `[StellarCoop][DR] look drone hid <name> at <m> m` when it hides the drone the first time,
  `[StellarCoop][DR] look drone <name> at <m> m hidden by the game: hidden when it shows` when the game had hidden it,
  or `[StellarCoop][DR] look drone none within 30 m (<n> in the world)`.

Before it changes anything, the look writes `coop-look.txt`: EVE's object path, a dash where older versions wrote the
old tick option, its Doro's path and the names of the parts it hides. Before it hides the drone's mesh the first time,
it writes the file again with the drone's object path added at the end. Every 250 ms it checks that the same EVE is on
the same map (otherwise it turns off) and hides again any listed part the game showed. The native part sets the tick
option back to 0 whenever SB's significance manager wrote it back. It counts each re-set. Once a second the look hides
the drone again if the game showed it. The log names each flag change the game made
(`[StellarCoop][DR] flag <part> visible=<0|1> hidden=<0|1>`) and gives the counts once a minute:

```
[StellarCoop][DR] look hid=<n> tick=<t>->0 rehid=<n>/min retick=<n>/min reload=<n>/min reload_ms=<ms>
```

`rehid` counts the parts and the drone hidden again, `retick` the tick option set back (the native part's count, the
`race_retick=` field of its status line), and `reload` the Doro assets
loaded again after the collector unloaded them, with the total time those loads took in `reload_ms`. The loads at the
making of the look's own Doro are not counted: the counter starts at 0 once that Doro stands. Its keepers (see
[The display Doro](#the-display-doro)) then hold every clip, so `reload` reads 0 for the whole look.

Turning the look off destroys its Doro, clears `bHiddenInGame` on the listed parts only, asks `race tick off` so the
native part puts the tick option back, clears it on the drone's mesh if the look hid that mesh, the drone is still there
and the mesh still has it, and deletes the file. That runs at the race's end, on `coop race look off` and `coop off`,
after a map change and at the look's first error, after which the look stays off until the mod reloads. If one of those
steps fails, the file stays. A Lua load that finds `coop-look.txt` (after Ctrl+R, or a Lua state that stopped) uses it
at its first game-thread tick: it destroys the Doro named there if that actor still shows Doro's mesh, clears
`bHiddenInGame` on the listed parts that still have it, clears `bHiddenInGame` on the main mesh of the drone named there
if the object at that path is still an SB character and its mesh still has it, and deletes the file. It writes no tick
option: the native part put it back at that Lua load. A file of an older version with a number in that field writes
nothing either. The log says `[StellarCoop][DR] look restored <n> parts from coop-look.txt`, with `and the drone` after
`parts` when it showed the drone.

The capture is unchanged. It counts a part with `bHiddenInGame` as hidden. While the look is on, your friend's game
therefore receives every part of your EVE as hidden and draws your ghost with no body unless its Doro mode is on.
After the look ends, the next capture pass (once a second) publishes the parts as shown again.

## The ghost's Doro mode

Your friend's ghost is drawn as a Doro while their game takes part in the race: on the host's PC from the guest's
`have` line, on the guest's PC once the host's track has arrived and passed the checks, until the race closes. A guest
whose game answers `have <id> no <why>` stays EVE on both screens.

In Doro mode, `online/partner/puppet.lua` hides every part of the ghost and hangs one more `SkeletalMeshComponent`, with
Doro's mesh, on the ghost's main mesh, where her feet are, and adds the Doro's keepers to the ghost's actor. A ghost
built in Doro mode resolves Doro's mesh and each clip in a build step of its own, so no frame loads more than one. The
ghost is the mod's own actor, so nothing of the game's is touched. The Doro's speed and vertical speed come from the
ghost's feet between poses, measured over 50 ms at least. The pose stream has no sprint or falling flag, so the Doro
goes on all fours above 560 cm/s and back on two legs below 520 cm/s. A vertical speed over 400 cm/s, up or down,
counts as being in the air. The ghost's own hiding (no pose for 1 s, another map) covers the Doro too. A Doro that
cannot be made leaves the ghost drawn as EVE, with the reason in the log. The pose stream is the same during a race: the
bones still arrive and are written into the hidden parts. While the race drives, the ghost's Doro follows the same
driving rules as yours, with the turn rate taken from the ghost's yaw in the pose stream, and its lean and nose set as a
relative rotation on the ghost's main mesh.

## Driving

From GO until our own result, `online/modes/race/drive.lua` drives EVE with `online/modes/race/drive_model.lua`'s car
model. The model holds a heading and a horizontal velocity. Each frame it turns the heading toward the stick's world
direction (`GetLastMovementInputVector`) at a rate that falls with speed, adds speed along the heading with a throttle
that fades near the top speed, and decays the speed across the heading by a grip, which drops during a drift (the drift
keys, read with the player controller's `IsInputKeyDown`, or hard steering at speed). The player controller is read when
the drive starts and checked every 250 ms, never per frame: when it is gone or no longer one, the drift keys wait until
a check finds one again.

In SB's movement component, the turn of the velocity toward the stick is the engine's friction step in `CalcVelocity`,
with `GroundFriction` as the friction. SB's own speed fields (`MaxRunSpeedOverride` and the sprint scales) only set the
top speed. With `MaxAcceleration`, `GroundFriction`, `BrakingDecelerationWalking` and `BrakingFrictionFactor` at 0,
`CalcVelocity` neither accelerates, brakes nor turns the velocity. The component moves EVE with the velocity it has.
Each frame the race gives it the model's velocity through `AddImpulse`, with the difference from `GetVelocity()` and a
vertical part of 0. Before each impulse,
`ClearAccumulatedForces` drops any impulse an earlier frame left unused. In photo mode with `photo_pause=scenery` the
world's time runs while SB's logic stands still; if her movement stands still with it, the impulses would otherwise add
up. The next frame starts from the velocity the component made of it, so walls, slopes and landings act on the model.
Impulses go only while the native part's status line says the hold is applied (`race_hold=1`, read every 250 ms):
they start up to about half a second after GO.
An impulse under 1 cm/s on both axes is not given when the frame before gave none either: EVE parked on the bike costs
no call. The component keeps her within 1 cm/s of the model meanwhile. The yaw goes to EVE with `K2_SetActorRotation`
when it is 0.01 degree or more off the heading, so a turn the game made is corrected in the same frame. The pose stream
carries it to your friend. The driving runs each
frame before the native tick, so the pose it captures and the Doro look both have the yaw written that frame.

On the ground SB's walking step ends by setting `Velocity.Z` to 0 (the engine's `MaintainHorizontalGroundVelocity`), so
the model takes EVE's vertical speed from her height between frames. Over a crest (on the ground at over 900 cm/s, a
climb held two frames that drops by more than 250 cm/s in one), the race calls `LaunchCharacter` with the climb's
vertical speed instead of giving a velocity.

The model steps by EVE's world time (`GetGameTimeSinceCreation`): when it has not moved since the last frame (the
pause menu), nothing is written, since impulses would pile up. Under root motion (`IsPlayingRootMotion`: a dodge) the
model holds and writes nothing. It starts again from her yaw and velocity.

The four values are the native part's: `drive.lua` asks `race hold on` when the drive starts and `race hold off` at
each end (our result, a quit, a DNF, `coop off`, a map change, the race's first error). With no drive on, a hold the
status line still says applied is asked off again every 250 ms, so an off lost in `core/link.lua`'s request queue (8
requests) cannot leave EVE unable to move. `coop-drive.txt` is no longer the races' (the bike's copy still keeps it).

## The native hold

`native/src/online/modes/race/hold.h` holds the rule, `hold_game.inc` runs it on the game thread and `hold_worker.inc`
takes Lua's asks and writes the status field. Two parts, each asked on or off by Lua (`race hold on|off` from
`drive.lua`, `race tick on|off` from `doro.lua`):

- the hold: EVE's movement component's `MaxAcceleration` (+0x1E0), `GroundFriction` (+0x1A0),
  `BrakingDecelerationWalking` (+0x1F4) and `BrakingFrictionFactor` (+0x1E8), floats of
  `UCharacterMovementComponent`, kept and set to 0;
- the tick: her main mesh's `VisibilityBasedAnimTickOption` (+0x7CC of `USkinnedMeshComponent`, a byte enum), kept and
  set to 0, `AlwaysTickPoseAndRefreshBones`.

Each frame on the pinned build, while Lua asks a part or something is still kept, the game thread finds our EVE: the
pawn (`AController::Pawn`, +0x2F8) of the first local player controller, which SB's getter at `0x142321ee0` gives,
checked to be a live `ASBCharacter` (the class global at `0x147038de8`). Her movement component is at
`ACharacter::CharacterMovement` (+0x330) and her main mesh at `ACharacter::Mesh` (+0x328). Each object is checked to
be live, by its object item's index and serial, before a read or a write. An asked part applies only while EVE is in
the world and no scene stands still: no theater plays and photo mode is off, or on with the selfie camera, in which
SB's logic runs (the photo manager at `0x147037440`, its active byte +0x38 and its camera +0x48, 2 for the selfie).
These offsets and addresses were read in Ghidra on build 26123051.

A part that applies keeps the values it finds once, then sets 0 each frame, counting each value the game wrote again
(a stance push writes the four fields; SB's significance manager writes the tick option). A part that stops applying
(the ask gone, EVE gone, a scene) writes the kept values back on the same live object at once. After a map change her
component is another object: the kept values are dropped unwritten when the old object is gone. They are taken again
from the new one while the ask holds. A pause changes nothing. `coop off` (`block()` in `glue/tick/status.inc`) and a new Lua
load (the `coop-session.txt` block of `glue/tick/worker.inc`) clear both asks. The game thread then puts back what it
kept at its next frame, after `coop off` too. It holds nothing more until Lua asks again. An ask `on` is refused off
the pinned build, after `coop off` and after a fault. The first fault closes the part's latch for the game run after
one try to put back what is kept, on live objects only.

The status line's `engine=` line carries ` race_hold=<0|1> race_tick=<0|1> race_retick=<n>` (applied or not, then the
tick option's re-sets this game run), or ` race_hold=fault` after the latch. `coop-link.log` gets the asks' answers
(`race hold on: applied at the game thread's next frame`, `race hold refused: coop off`), a line at each change of what
applies (`race hold: fields 0 (none), tick option game's (none)`, the word in brackets `eve` or `scene` for an asked
part that does not apply), `race hold: <field> written by the game: 0 again (<n> this run)`,
`race hold: kept values dropped unwritten, their object gone (a map change), <n> this run` and, once, the fault with
the notice `Doro races' hold on EVE stopped until the game restarts (a fault); races do not drive.`
`tests/native/online/modes/race/hold_test.cpp` (`online_modes_race_hold_test`) runs the rule on a fake memory.

## Race lines

The host owns a race. Its game sends the track and the start. Each game times its own racer from its own GO. The
host's game sends the ranking. The guest's game checks each line against fixed bounds before using it and sends only
its own racer's lines. Each line travels as `SBC29 race <text>` on channel 0 (see [Channel 0: text](../steam-link-internals.md#channel-0-text)),
with whole numbers only, in centimetres and milliseconds. `<id>` is the host's race number:

| Line | From | Meaning |
| --- | --- | --- |
| `track <id> <n> <laps> <x> <y> <z> <yaw> <map>` | host | A race is armed on that start line and map; `n` checkpoints follow |
| `cps <id> <first> <x> <y> <z> <r> ...` | host | Up to 12 checkpoints from the `first`th one, so a line stays under 512 bytes |
| `drive <id> <top> <accel> <brake> <coast> <grip> <drift_grip> <turn_slow> <turn_fast> <drift_angle>` | host | The driving values both players race with, after the `cps` lines; the guest clamps each to its range |
| `have <id> <sum>` or `have <id> no map\|track\|save` | guest | The track and the driving values arrived and passed the checks (`sum`: all their numbers added, modulo 2^32), or why the guest stays out |
| `ready <id> 0\|1` | both | Out of or in the start slot |
| `go <id> <ms>` or `abort <id> <why>` | host | The countdown's length (4000), or the race cancelled (`false_start`: the ready check again) |
| `cp <id> <lap> <i> <ms>` | both | A checkpoint passed, with the race time |
| `fin <id> <ms> <flags>` or `dnf <id> <why>` | both | Your finish time and flags (1 fast run, 2 paused), or why you did not finish (`teleport`, `map`, `quit`, `left`, `late`, `time`) |
| `rank <id> <host ms or -> <guest ms or ->` | host | The final ranking |
| `end <id>` | host | The race closed |

The guest's game refuses a track with fewer than 2 or more than 64 checkpoints, `|x|` or `|y|` over 2,000,000,
`|z|` over 500,000, a radius outside 300 to 3000, a time over 3,600,000 ms, or another map than its own. A line that
fails a check is dropped and counted. A track whose `drive` line does not follow its last `cps` line is refused with
`have <id> no track`. The guest's countdown starts when `go` arrives, less half the round trip of the link's pings. A host that gets no `have` line within 10 s sends `abort <id> track` and races alone.

In `coop loopback` with no friend linked, the host's lines come back as the friend's. A second, guest instance of the
race model answers them, run on the loopback ghost's feet. Its lines go straight to the host's.

Each PC logs a `[StellarCoop][DR] result` line per race that reaches its results there, with the race's length by
`os.clock` and by `os.time`. The race clock is `os.clock`. The two values show whether it counts wall time on that
PC.

A race calls no achievement, reward, item, quest or save function and no console command. The only class it spawns is
`/Script/Engine.Actor`. `tests/lua/online/modes/race/run_test.lua` checks both in `online/modes/race/doro.lua`,
`online/modes/race/model.lua`, `online/modes/race/run.lua`, `online/modes/race/drive.lua`,
`online/modes/race/drive_model.lua` and the three Lua files of `online/modes/race/match/`. No race file makes a
`ServerRequest_` call or a zone event: `tests/tools/matchmaking_scan_test.py` has no entry for the module. Nothing a
race does reaches SB's matchmaking. The teleport onto a grid slot is `K2_TeleportTo`, an engine call.

## Races in a match

A race in a match is a round of the [SBO lobby](../lobby.md) whose mode is `race`, with the map word `lobby`: it plays
in the room the members wait in. The round starts on the link's start line (see
[The start, count and end lines](../steam-link-internals.md#the-start-count-and-end-lines)). Its lines go on the dr
line (see [The dr line](../steam-link-internals.md#the-dr-line)). The races of an online session keep their race
line, which a match lobby refuses both ways.

| File | What it does |
| --- | --- |
| `match/model.lua` | The round without a game call: the dr line's texts, the track as it travels and comes whole, which tracks a room offers, the pick and its Random draw, the split floors, the host's checks, its wait and the ranking, our race from the start line to the results (`Mm.racer`, `Mm.frame`), the best times and `coop-tracks.txt` |
| `match/round.lua` | The round on the Steam link: the start line, the dr lines sent and read, the host's draw and arbitration. Its first line says it is the race's copy of `online/modes/scoreattack/round.lua` |
| `match/game.lua` | Between the round and our race: the sit-out checks, the hall seat, the ghosts by SteamID, ready, cp and done, the records write |
| `match/tracks.lua`, `match/tracks/*.txt` | The official tracks, by room key (`xion` or a hall's), in the `SBR 1` format of [Track files](race.md#track-files) |
| `run.lua` | A third role, `match`, beside host and guest: the teleport onto the slot at the start and back at GO (a racer that SB's chair seats then sits out with a DNF `quit`), every round player's ghost as a Doro, the round's tick at the start of the race's 250 ms pass, no crowd DNF, `coop race start` refused in a match lobby |
| `ui/hud.lua` | POS among up to 8 racers, the 8 result rows, the note before the ranking, `Not ranked.` and `New personal best.` |

Lua cannot list a folder, so `match/tracks.lua` names each official track. The wiring finds the folder with
`package.searchpath('online.modes.race.match.tracks', package.path)`, as `main/loader.lua` finds a `wiring.lua`. It
reads each file with `io.open(path, 'rb')`, read only. The host's own tracks are the names in `coop-tracks.txt` in the
mod folder (32 at most, the newest kept, under a comment line), each read from its `coop-track-<name>.txt`. A track is
offered when its `map` line equals `core/where.lua`'s map of EVE and the 8 slots (`R.slot`, rows of two 3 m apart) and
every checkpoint's centre stand 2 m or more inside the room's fence from `online/lobby/sbo.lua`'s `target()`.

The host draws the track at the start line: its pick when the room offers it, else one drawn by the seed among the
room's official tracks, else among all offered. It sends the track as the session race's `track` and `cps` lines
(without the `drive` line) and a `go` line, at most 8 lines. The round hands one of its lines or asks to the link each
250 ms pass, in order: `core/link.lua`'s request queue keeps 8 and drops the oldest. The host's lines with its ready
can be 9. Each game builds the track from the owner's lines of one seed, kept 10 s. It checks that its sum is
the go line's. A match race drives with `drive_model.lua`'s defaults, never the host's `coop race drive` values.

Each dr line carries one text. The seed is the round's, from the start line, the same in every game:

| Text | From | When |
| --- | --- | --- |
| `track <seed> <n> <laps> <x> <y> <z> <yaw> <map>` | The host | The round's start: the start line and map, `n` checkpoints to follow |
| `cps <seed> <first> <x> <y> <z> <r> ...` | The host | Then up to 12 checkpoints a line |
| `go <seed> <sum> <name>` | The host | After the cps lines: the track's sum (all its numbers added, modulo 2^32, the default driving values among them) and its name |
| `ready <seed>` | Each player | Her race started on her slot |
| `cp <seed> <lap> <i> <ms>` | Each player | A checkpoint passed, the finish excepted, with her time from her GO |
| `done <seed> fin <ms> <flags>` or `done <seed> dnf <why>` | Each player | Her end: the finish (flags 1 fast run, 2 paused) or the DNF's reason (`teleport`, `map`, `quit`, `left`, `late`, `time`) |
| `rank <seed> <id>:<ms>,...,<id>:dnf` | The host | The ranking: finishers fastest first, then the DNFs, `-` for nobody. 8 players at most, about 230 bytes |
| `void <seed>` | The host | No ranking: the host's game lost the round (a Lua reload) or its room offers no track |

A game takes `track`, `cps`, `go`, `rank` and `void` from the match lobby's owner only. It takes `ready`, `cp` and
`done` from the round's players only. The sender's SteamID comes from Steam, never from the text. A text that does
not decode, or comes from a sender who may not send it, gets one `line refused` line per sender a round.

The host's round (`Mm.host`) holds each player's ready, last split, its time and her end. It takes a ready within 10 s
of its go. For each split it computes a floor (`Mm.floors`): the horizontal legs up to it, each less both radii (0 for
the start line) and 3 m for a slot's side offset, never under 0, at twice the default top speed (4400 cm/s). A split
must be the player's next, not under its floor, not under her split before, not over 900,000 ms. A finish must follow
her last split with the same bounds and flags 0 to 3. A DNF must carry one of the race's reasons. A refused player
leaves the ranking. Her later texts are taken with no further log line. `Mm.tick` waits for everyone during the first 10 s.
Then it waits for every member who sent a ready, is not refused and has no end. It stops 65 s after the first finish it
took (60 s late rule and 5 s for lines on their way) or 930 s after its GO (the 15 min limit and 30 s). It sends `rank`
and asks `match end` 10 s later. The ranking puts the finishers by time, equal times in SteamID order, then the DNFs
in the round's order. `R.rank` gives finishers within 10 ms one place.

Our race (`Mm.racer`, `Mm.frame`) is the third role of `run.lua`'s machine. Its countdown runs 4 s from the moment our
game has the whole track, with no ready check: every racer stands on her slot. The runner is the session race's
(`R.runner`, `R.run`). The late rule starts at the first frame in which the round's board shows a finish. The results
come from the host's `rank` and stay 20 s, unless the round's end line closes them first. POS counts the round's ready
racers (`R.places`): finishers by time, then checkpoints passed by each racer's last split, then the distance from her
ghost's feet to her next checkpoint, a DNF last.

Our best time on a track goes in `coop-records.txt` as `best_race_<sum>=<ms> <name>` at our own finish when it beats
the stored one. `match/model.lua`'s `Mm.best`, `Mm.better` and `Mm.write` are the race's copy of
`online/modes/scoreattack/challenges.lua`'s `C.best`, `C.better` and `C.write`, on `core/settings_file.lua`. The wiring
writes a `.tmp` file, deletes the old file and renames, as score attack's does.

The wiring lists `online.lobby` in `uses` and reads its `sbo` export through `view(M,'sbo')`: the room, its spots and
fence, the hall seat. It exports `race_match`, the round, nil without the Steam link. The race's 250 ms pass ticks it
through `run.lua`'s `round_tick` hook. `coop off` stops it after our race through `round_stop`. No runtime line was
added. The lobby reads `race_match`'s pick and cycle for its Track row through `Loader.get`, so the row is locked
while the module is off. It opens its menu again at the end line of a round its player took part in.

The Lua tests are in `tests/lua/online/modes/race/match/`: `model_test` (the texts both ways with their refusals, the
track coming whole, the offered rule on planted rooms with Xion's fence, the draw, the floors, the host's checks
against honest and forged splits, its wait over a fake clock, the ranking, the records and the index), `round_test`
(the round on a fake link and clock) and `game_test` (each sit-out, the seat, the ghosts, the lines to the round, the
records, the round's end). `tests/lua/main/race_match_test.lua` runs a round through `main.lua` with the official
track read from the Scripts folder. `tests/lua/online/modes/race/ui/hud_test.lua` covers the panel and the results
for up to 8 racers. The native `link_protocol_test` and `link_match_test` cover the dr line.

Not checked in game: everything in this section. In particular whether `xion_eight`'s loops drive well, the speed of
EVE's own dashes against the host's floors, the 720-unit results panel and the lobby menu's four mode rows on screen.
The hall lobbies have no official track to check yet.
