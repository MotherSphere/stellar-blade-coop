# Doro races

A Doro race runs in Lua: `race/run.lua` on the game side, `race/model.lua` for the rules and the race lines,
`race/doro.lua` for the Doros, `race/drive.lua` and `race/drive_model.lua` for the driving. Its only SB calls are two
reads on EVE, `IsSprint` and `GetSBSpeedForAnimGraph` (for a log line); the rest are engine functions. The native
part only carries the race lines. The commands and rules are in [../doro-races.md](../doro-races.md).

## The display Doro

Each Doro the mod shows is a plain `Actor` that Lua spawns, with one `SkeletalMeshComponent` that holds Doro's mesh
(`CH_NPC_Dororong`, at the game's own scale of 1.5, about 59 cm tall) and collision off. It is not an SB character: it
has no row in the game's tables, no AI and nothing that can die. Doro's own animation Blueprint is never used. The
component runs the engine's single-node animation (`SetAnimationMode(1)`), and each frame Lua picks what it plays with
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

The mesh and the clips come from the game's own files (`StaticFindObject`, else `LoadAsset`). The engine's garbage
collector unloads an asset that nothing in the engine references, and a reference held in Lua does not count. In
0.5.0-beta.1, a clip that no Doro had played for a while was unloaded, and the next `PlayAnimation` loaded it again
synchronously: 5 loads a minute taking 185 ms in all while EVE sprinted, each one a short freeze in game. Each Doro
now carries one keeper per clip: a second `SkeletalMeshComponent` with Doro's mesh, in single-node mode, given the clip
with `SetAnimation`. Its animation instance holds the clip through `CurrentAsset`, which the collector follows, so every
clip stays loaded while any Doro stands. The keepers are not attached and never move. They have `bVisible` off, so the
renderer never gets them, component tick off, `VisibilityBasedAnimTickOption` 3 (pose only while drawn) and collision
off. They go with their Doro's actor; on the ghost, whose actor stays, they go when Doro mode ends. A clip that is not
in memory is loaded when a Doro is made, not during the race.

A race shows at most two Doros of its own: before GO one at the start line's centre, and during the race one at the next
checkpoint and one at the one after it, facing the checkpoint before them. Their object paths stay in
`coop-race-doros.txt` while they stand, so a Lua reload (Ctrl+R) in a race destroys them at its first tick.

## The Doro look

The look draws your EVE as a Doro. Its Doro is placed each frame, after the native tick, at the world location and
rotation of EVE's main mesh (her feet); it is not attached to her. The look and the race's driving (below) are the
features that write to the player actor. The look writes two things on her, and hides the drone:

- `bHiddenInGame` on each of EVE's mesh components that did not have it, through `SetHiddenInGame`. The game shows and
  hides her parts (a drawn blade) with `SetVisibility`, which sets the separate `bVisible` flag, so the look neither
  fights those changes nor undoes them. `SetActorHiddenInGame` on EVE is not used.
- `VisibilityBasedAnimTickOption` on her main mesh, set to 0 (always tick the pose). EVE's Blueprint ticks her pose
  only while she is drawn, so a hidden EVE would stop her pose, her animation notifies and the root-motion moves of
  dodges and ledges.
- The drone that follows EVE is an SB character of its own, so hiding EVE's parts left it flying beside the Doro. The
  look sets `bHiddenInGame` on the drone's main mesh (`CharacterMesh0`) through `SetHiddenInGame`, only when the mesh
  does not have it, and writes nothing else on the drone. The actor itself stays shown: hiding it would also turn off
  its spot light, which lights EVE's way in dark places, and its guide ray and wait signal. The look finds the drone
  with one `FindAllOf('CH_Drone_BP_C')`, the drone's Blueprint class: the nearest one of exactly that class within 30 m
  of EVE, whether the game shows it or not. `FindAllOf` walks every object on the game thread (25 to 40 ms in game), so
  it runs at look on and once more each time the drone the look holds goes, and never on a timer. If it finds none, it
  does not look again until the next look on. Once a second the look checks the held drone's mesh, and hides it if the
  game showed it. A mesh the game hid is left alone until the game shows it. The log says
  `[StellarCoop][DR] look drone hid <name> at <m> m` when it hides the drone the first time,
  `[StellarCoop][DR] look drone <name> at <m> m hidden by the game: hidden when it shows` when the game had hidden it,
  or `[StellarCoop][DR] look drone none within 30 m (<n> in the world)`.

Before it changes anything, the look writes `coop-look.txt`: EVE's object path, the old tick option, its Doro's path and
the names of the parts it hides. Before it hides the drone's mesh the first time, it writes the file again with the
drone's object path added at the end. Every 250 ms it checks that the same EVE is on the same map (otherwise it turns
off), hides again any listed part the game showed, and sets the tick option back to 0. Once a second it hides the drone
again if the game showed it. The log names each flag change the game made
(`[StellarCoop][DR] flag <part> visible=<0|1> hidden=<0|1>`) and gives the counts once a minute:

```
[StellarCoop][DR] look hid=<n> tick=<t>->0 rehid=<n>/min retick=<n>/min reload=<n>/min reload_ms=<ms>
```

`rehid` counts the parts and the drone hidden again, `retick` the tick option set back, and `reload` the Doro assets
loaded again after the collector unloaded them, with the total time those loads took in `reload_ms`. The loads at the
making of the look's own Doro are not counted: the counter starts at 0 once that Doro stands. Its keepers (see
[The display Doro](#the-display-doro)) then hold every clip, so `reload` reads 0 for the whole look.

Turning the look off destroys its Doro, clears `bHiddenInGame` on the listed parts only, puts the tick option back,
clears it on the drone's mesh if the look hid that mesh, the drone is still there and the mesh still has it, and deletes
the file. That runs at the race's end, on `coop race look off` and `coop off`, after a map change and at the look's
first error, after which the look stays off until the mod reloads. If one of those steps fails, the file stays. A Lua
load that finds `coop-look.txt` (after Ctrl+R, or a Lua state that stopped) uses it at its first game-thread tick: it
destroys the Doro named there if that actor still shows Doro's mesh, clears `bHiddenInGame` on the listed parts that
still have it, puts the tick option back, clears `bHiddenInGame` on the main mesh of the drone named there if the object
at that path is still an SB character and its mesh still has it, and deletes the file. The log says
`[StellarCoop][DR] look restored <n> parts from coop-look.txt`, with `and the drone` after `parts` when it showed the
drone.

The capture is unchanged, and it counts a part with `bHiddenInGame` as hidden. While the look is on, your friend's game
therefore receives every part of your EVE as hidden, and draws your ghost with no body unless its Doro mode is on.
After the look ends, the next capture pass (once a second) publishes the parts as shown again.

## The ghost's Doro mode

Your friend's ghost is drawn as a Doro while their game takes part in the race: on the host's PC from the guest's
`have` line, on the guest's PC once the host's track has arrived and passed the checks, until the race closes. A guest
whose game answers `have <id> no <why>` stays EVE on both screens.

In Doro mode, `partner/puppet.lua` hides every part of the ghost and hangs one more `SkeletalMeshComponent`, with Doro's
mesh, on the ghost's main mesh, where her feet are, and adds the Doro's keepers to the ghost's actor. A ghost built in
Doro mode resolves Doro's mesh and each clip in a build step of its own, so no frame loads more than one. The ghost is
the mod's own actor, so nothing of the game's is touched. The Doro's speed and vertical speed come from the ghost's feet
between poses, measured over 50 ms at least. The pose stream has no sprint or falling flag, so the Doro goes on all
fours above 560 cm/s and back on two legs below 520 cm/s, and a vertical speed over 400 cm/s, up or down, counts as
being in the air. The ghost's own hiding (no pose for 1 s, another map) covers the Doro too. A Doro that cannot be made
leaves the ghost drawn as EVE, with the reason in the log. The pose stream is the same during a race: the bones still
arrive and are written into the hidden parts. While the race drives, the ghost's Doro follows the same driving rules as
yours, with the turn rate taken from the ghost's yaw in the pose stream, and its lean and nose set as a relative
rotation on the ghost's main mesh.

## Driving

From GO until our own result, `race/drive.lua` drives EVE with `race/drive_model.lua`'s car model. The model holds a
heading and a horizontal velocity. Each frame it turns the heading toward the stick's world direction
(`GetLastMovementInputVector`) at a rate that falls with speed, adds speed along the heading with a throttle that fades
near the top speed, and decays the speed across the heading by a grip, which drops during a drift (the drift keys, read
with the player controller's `IsInputKeyDown`, or hard steering at speed).

In SB's movement component, the turn of the velocity toward the stick is the engine's friction step in `CalcVelocity`,
with `GroundFriction` as the friction. SB's own speed fields (`MaxRunSpeedOverride` and the sprint scales) only set the
top speed. With `MaxAcceleration`, `GroundFriction`, `BrakingDecelerationWalking` and `BrakingFrictionFactor` at 0,
`CalcVelocity` neither accelerates, brakes nor turns the velocity, and the component moves EVE with the velocity it has.
Each frame the race gives it the model's velocity: by default through `AddImpulse` with the difference from
`GetVelocity()` and a vertical part of 0, or through a write of its `Velocity`. Before each impulse,
`ClearAccumulatedForces` drops any impulse an earlier frame left unused. In photo mode with `photo_pause=scenery` the
world's time runs while SB's logic stands still; if her movement stands still with it, the impulses would otherwise add
up. The next frame starts from the velocity the component made of it, so walls, slopes and landings act on the model.
The yaw goes to EVE with `K2_SetActorRotation`, and the pose stream carries it to your friend. The driving runs each
frame before the native tick, so the pose it captures and the Doro look both have the yaw written that frame.

On the ground SB's walking step ends by setting `Velocity.Z` to 0 (the engine's `MaintainHorizontalGroundVelocity`), so
the model takes EVE's vertical speed from her height between frames. Over a crest (on the ground at over 900 cm/s, a
climb held two frames that drops by more than 250 cm/s in one), the race calls `LaunchCharacter` with the climb's
vertical speed instead of giving a velocity.

The model steps by EVE's world time (`GetGameTimeSinceCreation`): when it has not moved since the last frame (the
pause menu), nothing is written, since impulses would pile up. Under root motion (`IsPlayingRootMotion`: a dodge) the
model holds and writes nothing, and starts again from her yaw and velocity. Every 250 ms the race sets back to 0 any of
the four values the game wrote (a stance change).

Before the four values change, `coop-drive.txt` gets EVE's object path and their old values. Our result, a quit, a DNF,
`coop off`, a map change and the race's first error write them back, on that EVE only while she is still the object they
came from, and delete the file. A Lua load that finds the file writes the values back at its first tick, even with
`coop off` still in force. No SB code found writes `MaxAcceleration` or `GroundFriction`, so the values from before the
race are the ones to put back; the 250 ms check catches a write the search missed.

## Race lines

The host owns a race. Its game sends the track and the start, each game times its own racer from its own GO, and the
host's game sends the ranking. The guest's game checks each line against fixed bounds before using it, and sends only
its own racer's lines. Each line travels as `SBC19 race <text>` on channel 0 (see [Channel 0: text](steam-link.md#channel-0-text)),
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
race model answers them, run on the loopback ghost's feet, and its lines go straight to the host's.

Each PC logs a `[StellarCoop][DR] result` line per race that reaches its results there, with the race's length by
`os.clock` and by `os.time`. The race clock is `os.clock`, and the two values show whether it counts wall time on that
PC.

A race calls no achievement, reward, item, quest or save function and no console command, and the only class it spawns
is `/Script/Engine.Actor`. `tests/lua/race/run_test.lua` checks both in `race/doro.lua`, `race/model.lua`,
`race/run.lua`, `race/drive.lua` and `race/drive_model.lua`.
