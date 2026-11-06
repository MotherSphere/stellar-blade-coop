# Doro races

A Doro race is a run along a track of checkpoints that you record, for one player or two. Each racer is drawn as a
Doro (Dororong): your EVE on your screen, and your ghost on your friend's. From GO, EVE drives like a rally car (see
[Driving](#driving)); her jumps, dodges and camera stay the game's. Doro races have not been tested in game yet.

## Recording a track

1. Stand where the race starts, facing the way it goes, and type `coop race record <name>`. The name is 1 to 24
   characters of `a-z`, `0-9`, `_` and `-`. The start line is where EVE's feet are, facing her way.
2. Run the route. At each checkpoint, press F9 (`race_key`) or type `coop race cp`. The checkpoint is where EVE's feet
   are at that moment, with a 12 m radius. It must be at least 15 m from the one before it (from the start line for
   the first), or it is refused with `Too close: 15 m at least between checkpoints.` A track holds at most 64
   checkpoints, and the last one is the finish.
3. Type `coop race save` to write the track to `coop-track-<name>.txt` beside `coop-settings.txt`. It replaces a
   track of the same name, and it needs 2 checkpoints at least. `coop race save <laps>` (1 to 9) makes a circuit,
   which needs the last checkpoint within 30 m of the start line. `coop race cancel` drops the recording and writes
   nothing.

The log line `[StellarCoop][DR] track <name> saved: <n> checkpoints, <laps> laps, path <m> m in <s> s` gives the
distance you ran and how long it took. Recording works on any save. A checkpoint on another map than the start line's
is refused, and F9 does nothing while no track is being recorded. The mod ships no track of its own.

## Starting a race

`coop race start <name>` arms a race on `coop-track-<name>.txt`, on a co-op save only. The host starts every race: a
guest's `coop race start` is refused, and the guest's game takes part when the host starts one. The start is also
refused while a Night Operation run is on, while a track is being recorded, when the track is on another map than
yours, and when your friend is on another map or their map is not known yet. `coop nightop start` is refused while a
race is armed.

- With no session, you race alone against the clock.
- With a friend linked, your game sends the track to theirs, which checks it and joins the race. They need no track
  file, and their screen says `<host> starts a race: walk to your start.` When their game does not join, you race
  alone, and your notice says why: they are on another map, their game could not read the track, they do not play a
  co-op save, or no answer came within 10 s.
- During `coop loopback` with no friend linked, the loopback ghost races as the second player, which tests the
  two-player race on one PC. It walks 2 m to your right as you faced when it appeared, and keeps that side. Start the
  loopback facing the way the race goes: the ghost then stands in the guest's slot while you stand in yours.

## Slots and countdown

The start line has two slots, 3 m apart across its facing: the host's on the left and the guest's on the right. Alone,
you take the left one. A marker labelled `Your start` stands over yours, and a Doro stands at the centre of the line.
Walk to your slot: the mod moves nobody. You are in it within 2.5 m of its centre, and out of it past 3 m.

Once every racer has stood in their slot for 1 s, the host's game starts a 4 s countdown: 3, 2, 1, then GO. On the
guest's PC the countdown starts when the host's line arrives, less half the ping.

Leaving your slot before the countdown holds the start. Leaving it during the countdown is a false start: the
countdown stops on both screens with `False start: back to your start.`, and the 1 s check starts again. A false
start has no penalty.

## Driving

From GO until your own result (your finish or a DNF), EVE drives like a rally car:

- The left stick points where you want to go, relative to the camera, as outside a race. Doro turns toward it at 220
  degrees a second when it stands, and slower as it gets faster, down to 75 degrees a second at top speed. It speeds
  up along the way it faces, quickly at first and slowly near its top speed of 22 m/s. EVE runs at 5 m/s and sprints
  at 7. A stick pushed halfway gives half the throttle.
- Pulling the stick back, more than 120 degrees from where Doro faces, brakes down to 3 m/s without turning. With the
  stick released, Doro coasts and loses 2.5 m/s each second.
- To drift, hold R2 on a pad or B on the keyboard above 4 m/s, or steer more than 45 degrees off the way Doro faces
  above 12 m/s. Doro then keeps its speed and slides sideways while it turns, at 1.4 times the turn rate, until the
  slide is under 1.5 m/s.
- Over a crest faster than 9 m/s, Doro leaves the ground. In the air it keeps its speed and turns at 0.3 times the
  rate.
- A wall hit faster than 9 m/s that takes 40% of the speed at once makes Doro stumble for 0.6 s: no throttle, half
  the steering.
- While a dodge or another of the game's root-motion moves carries EVE, the driving waits.

Both players race with the host's driving values: the host's game sends them after the track, and a guest's game that
gets a track without them stays out of the race. They are starting values, not yet tuned in game.

`drift_keys` in `coop-settings.txt` names the drift keys: Unreal key names, at most 4, or `none` to drift by steering
alone. R2 still picks up items within reach during a race, as it does outside one.

To drive EVE, the race sets four values of her movement component to 0 (`MaxAcceleration`, `GroundFriction`,
`BrakingDecelerationWalking` and `BrakingFrictionFactor`), so her movement keeps the velocity the race gives it each
frame, and turns her to Doro's heading. Floors, walls, slopes and gravity stay the game's. Your result, `coop race
quit`, a DNF, `coop off`, a map change and the race's first Lua error put the four values back. While it drives,
`coop-drive.txt` holds them, so the next Lua load (Ctrl+R) puts them back when this one could not. If EVE no longer
speeds up or stops after a race, press Ctrl+R.

Test and tuning commands, left out of the usage line:

- `coop race drive` shows the host's driving values and how the velocity reaches EVE's movement.
- `coop race drive probe`, on a co-op save with no race armed: EVE goes straight ahead at 15 m/s for 3 s through
  impulses, then 3 s through writes of her velocity, then drives with your stick as in a race until
  `coop race drive off`.
- `coop race drive <name> <value>` changes one driving value for your next races, until the mod reloads. The names are
  `top` (cm/s), `accel`, `brake` and `coast` (cm/s per second), `grip` and `drift_grip` (tenths a second: how fast a
  slide fades), `turn_slow` and `turn_fast` (degrees a second, standing and at top speed) and `drift_angle` (degrees).
  Each value is a whole number, kept within its range.
- `coop race drive feed impulse|struct` picks how the velocity reaches her movement: an impulse each frame (the
  default) or a write of its velocity.

During a drive, `UE4SS.log` has a line once a second, `[StellarCoop][DR] drive v=<cm/s> vz=<cm/s> asked=<cm/s>
yaw=<degrees> heading=<degrees> air=0|1 root=0|1 drift=0|1 stumble=0|1`, and a line for each drift key pressed or
released, each wall hit and each crest. `asked` is the speed the car gave the last frame, `yaw` EVE's facing as read
one frame after the car turned her.

## Rules

- Checkpoints count only in order. A checkpoint counts when EVE's path from one frame to the next comes within its
  radius horizontally and within 6 m vertically, at any speed. A marker over the next checkpoint shows its distance,
  and an arrow at the edge of the screen points to it when it is off screen or behind you. A Doro stands at the next
  checkpoint and another at the one after it. The Doro at the finish hops in a loop.
- `MISSED CHECKPOINT <n>`: you entered a later checkpoint while checkpoint `<n>` was still due. Nothing counts until
  you go back through it.
- `WRONG WAY`: the distance to the next checkpoint grew 20 m past its lowest since your last checkpoint, after you ran
  more than 25 m. It clears once that distance drops by 10 m.
- Neither a missed checkpoint nor a wrong way has a penalty other than the time it costs.
- On a circuit, the checkpoints repeat from the first one each lap. You finish at the last checkpoint of the last lap.
- Each racer is timed from their own GO by their own game's clock. Pausing the game does not stop it.

A DNF (did not finish) ends your race. A notice says why:

| Notice | Cause |
| --- | --- |
| `Moved more than 20 m at once.` | EVE moved over 20 m in one frame: a fast travel, a respawn at a camp after a death, or any other warp. After a frame that took long (a hitch), the limit is the distance twice the top speed covers in that time, when that is more |
| `Left the map.` | A map change, or no EVE in the world for 2 s (a load, the title screen) |
| `The session ended.` | The link with your friend ended |
| `Not finished 60 s after the winner.` | You were still racing 60 s after the first racer finished |
| `Over the 15 min limit.` | You were still racing 15 min after GO |

`coop race quit` and `coop off` end your race as a DNF too, with the command's answer instead of a notice. Before GO,
the host's quit or map change cancels the race for both players (`Race cancelled.`). A guest who does the same leaves
the race. Before the countdown the host then races alone; during it, the guest stays in the race as a DNF, so `POS`
counts two racers and the results list the guest as `DNF`.

## Results

During the race, the panel at the top centre shows `DORO RACE`, your time (`1:23.45`), `CP`, `LAP` and `POS`. Your
place comes from laps, checkpoints and the distance to the next checkpoint, your friend's from where their ghost is.

Once every racer has finished or is out, `RESULTS` takes the panel's place for 10 s, with each racer's place and time,
or `DNF`. Times within 10 ms share a place. The host's game sends the ranking, so both screens show the same one. While
they stand still, the winner's Doro hops in place and the other Doro plays its tired animation. Then the race closes:
its Doros go, and EVE and the ghost are drawn as themselves again.

Two flags can show under `RESULTS` for your own run. Neither changes the ranking.

- `fast run`: for 1 s or more, EVE moved faster than 5.5 m/s horizontally while she was not sprinting and not in the
  air. The flag was there for Tachy mode, which runs faster. A driven run's speed no longer depends on Tachy mode, and
  the flag does not show while the race drives EVE.
- `paused`: the game was paused, or showed one of its own screens, for 2 s or more.

Each PC logs one line per race that reaches its results there: `[StellarCoop][DR] result id=<id> track=<name> ms=<ms>
clock=<s> time=<s> flags=<n> rank=<place>`. `ms` is your time in milliseconds, `clock` and `time` measure the race with
two different clocks (for a bug report), `flags` adds 1 for a fast run and 2 for paused, and `rank` is your place. `ms`
and `rank` read `-` after a DNF, and `track` reads `-` on the guest's PC.

The panel, the banners and the results hide while the game is paused or shows one of its own screens. With the
co-op UI off (`coop ui off`, or after an engine error), they do not show, and the banners other than the countdown
come as notices on the line above EVE.

## The Doro look

From the start of a race on your PC until it closes, your EVE is drawn as a Doro. The Doro stands at EVE's feet, walks
and runs on two legs, runs on all fours while she sprints, and hops when she jumps. Your friend's ghost is drawn as a
Doro from the moment their game joins the race. If it does not join, it stays EVE on both screens.

While the race drives EVE, her Doro runs on all fours from 60% of the top speed, plays its run up to 3 times faster,
faces where it is heading (so it shows its side in a drift), leans into bends, dips its nose when it lands and plays a
tired hop when it hits a wall. Your friend's Doro does the same from their ghost's movement, except the tired hop.

To draw the Doro, the look hides EVE's mesh parts in game, and sets her main mesh to keep animating while hidden. It
also hides the body of the drone that follows EVE, when it is within 30 m of her as the look starts. The drone's light
and signals keep working. The race's end, `coop race quit`, `coop off`, a map change and the look's first error undo
these changes. While the look is on, `coop-look.txt` holds what it changed, so the next Lua load (Ctrl+R) undoes them
when this one could not. If EVE or the drone stays hidden, see
[troubleshooting.md](troubleshooting.md#eve-is-invisible-or-only-a-doro-shows).

Each Doro keeps its animations loaded while it stands. The first Doro of a race loads them all at once, so it can take
a moment to appear, and none loads during the race. While the look is on, `UE4SS.log` has a line once a minute,
`[StellarCoop][DR] look hid=<n> tick=<t>->0 rehid=<n>/min retick=<n>/min reload=<n>/min reload_ms=<ms>`. `reload`
counts the Doro animations loaded again since the look's Doro appeared, and `reload_ms` the total time they took. In
0.5.0-beta.1 these loads froze the Doro for a moment when EVE sprinted. It should read 0.

While the look is on, your friend's game receives your EVE's parts as hidden. In a race their game joined, they see
your ghost as a Doro. Otherwise your ghost on their screen shows its name and marker but no body until the look ends.
After a race, it can show no body for about 1 s.

Two test commands are left out of the usage line. Both need a co-op save, except `coop race look off`:

- `coop race look on` turns on the look on your EVE and the Doro on your friend's ghost, with no race.
  `coop race look off` turns both off, on any save.
- `coop race probe doro` shows a Doro 3 m in front of EVE that plays each of its animations in turn, for about 45 s,
  with a `[StellarCoop][DR]` line in `UE4SS.log` for each step.

## Limits

- Two players at most. The host starts every race, and only the host needs the track file.
- Both players must be on the track's map.
- Enemies stay as they are: each game runs its own fights during a race, and shared enemies, same place and same
  spawns work as usual. Record tracks through ground you have cleared.
- A race gives no reward, item, progress or achievement, and writes nothing to a save. Its Doros are display only,
  with collision off: nothing can hit them, and they cannot die.

## Track files

A track file is plain text:

```
SBR 1
map /game/art/bg/worldmap/e03_wasteland_p/e03_wasteland_p
laps 1
grid -42511 -14642 -2682 -165
cp -46580 -15709 -2473 1200
cp -49676 -17231 -2472 1200
```

`grid x y z yaw` is the start line's centre in centimetres and its facing in degrees. Each `cp x y z r` line is a
checkpoint's centre (EVE's feet when it was set) and its radius in centimetres. With the game closed, you can change a
radius by hand, from 300 to 3000. The file keeps this form: whole numbers, single spaces, 1 to 9 laps, 2 to 64
checkpoints, each at least 15 m from the one before it (the first from the start line), at most 4096 bytes.
`coop race start` refuses a file that breaks a rule, with the reason.
