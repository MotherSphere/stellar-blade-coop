# Doro races

A Doro race is a run along a track of checkpoints that you record, for one player or two in an online session. In
the SBO lobby it is also a match mode for 2 to 8 players (see [Races in a match](#races-in-a-match)). Each racer is
drawn as a Doro (Dororong): your EVE on your screen and your ghost on the other racers' screens. From GO, EVE drives
like a rally car (see [Driving](#driving)); her jumps, dodges and camera stay the game's. Doro races have not been
tested in game yet.

How the mod draws the Doros and drives EVE is in [online/modes/race-internals.md](race-internals.md). Problems are in
[players/troubleshooting.md](../../players/troubleshooting.md#doro-races).

## Recording a track

1. Stand where the race starts, facing the way it goes. Type `coop race record <name>`. The name is 1 to 24
   characters of `a-z`, `0-9`, `_` and `-`. The start line is where EVE's feet are, facing her way.
2. Run the route. At each checkpoint, press F9 (`race_key`) or type `coop race cp`. The checkpoint is where EVE's feet
   are at that moment, with a 12 m radius. It must be at least 15 m from the one before it (from the start line for
   the first), or it is refused with `Too close: 15 m at least between checkpoints.` A track holds at most 64
   checkpoints. The last one is the finish.
3. Type `coop race save` to write the track to `coop-track-<name>.txt` beside `coop-settings.txt`. It replaces a
   track of the same name. It needs 2 checkpoints at least. `coop race save <laps>` (1 to 9) makes a circuit,
   which needs the last checkpoint within 30 m of the start line. `coop race cancel` drops the recording and writes
   nothing.

The log line `[StellarCoop][DR] track <name> saved: <n> checkpoints, <laps> laps, path <m> m in <s> s` gives the
distance you ran and how long it took. `coop race save` also adds the name to `coop-tracks.txt`, the list of your
tracks that a match lobby may offer (see [Tracks a room offers](#tracks-a-room-offers)). Recording works on any save. A
checkpoint on another map than the start line's is refused. F9 does nothing while no track is being recorded. The
mod ships one track, `xion_eight`, for races in a match in Xion's training room.

## Starting a race

`coop race start <name>` arms a race on `coop-track-<name>.txt`, on a co-op save only. The host starts every race: a
guest's `coop race start` is refused. The guest's game takes part when the host starts one. The start is also
refused while a Night Operation run is on, while a track is being recorded, when the track is on another map than
yours and when your friend is on another map or their map is not known yet. A session of more than 2 players refuses
it too (`Doro races are for 2 players at most; this session has <n>`). In a match lobby it is refused with
`In a match lobby, races start from the lobby menu.` `coop nightop start` is refused while a race is armed.

- With no session, you race alone against the clock.
- With a friend linked, your game sends the track to theirs, which checks it and joins the race. They need no track
  file. Their screen says `<host> starts a race: walk to your start.` When their game does not join, you race
  alone. Your notice says why: they are on another map, their game could not read the track, they do not play a
  co-op save, or no answer came within 10 s.
- During `coop loopback` with no friend linked, the loopback ghost races as the second player, which tests the
  two-player race on one PC. It walks 2 m to your right as you faced when it appeared and keeps that side. Start the
  loopback facing the way the race goes: the ghost then stands in the guest's slot while you stand in yours.

## Slots and countdown

The start line has two slots, 3 m apart across its facing: the host's on the left and the guest's on the right. Alone,
you take the left one. A marker labelled `Your start` stands over yours. A Doro stands at the centre of the line.
Walk to your slot: the mod moves nobody. You are in it within 2.5 m of its centre. You are out of it past 3 m.

Once every racer has stood in their slot for 1 s, the host's game starts a 4 s countdown: 3, 2, 1, then GO. On the
guest's PC the countdown starts when the host's line arrives, less half the ping.

Leaving your slot before the countdown holds the start. Leaving it during the countdown is a false start: the
countdown stops on both screens with `False start: back to your start.` The 1 s check then starts again. A false
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

Both players race with the host's driving values: the host's game sends them after the track. A guest's game that
gets a track without them stays out of the race. They are starting values, not yet tuned in game. A race in a match
always drives with the default values, so times on one track compare.

`drift_keys` in `coop-settings.txt` names the drift keys: Unreal key names, at most 4, or `none` to drift by steering
alone. R2 still picks up items within reach during a race, as it does outside one.

To drive EVE, the race has four values of her movement component set to 0 (`MaxAcceleration`, `GroundFriction`,
`BrakingDecelerationWalking` and `BrakingFrictionFactor`), so her movement keeps the velocity the race gives it each
frame. The race turns her to Doro's heading. Floors, walls, slopes and gravity stay the game's. The mod's native
part holds the four values on the game thread (see [The native hold](race-internals.md#the-native-hold)). Your
result, `coop race quit`, a DNF, `coop off`, a map change, a new Lua load (Ctrl+R) and the race's first Lua error put
them back. A cutscene and photo mode (with any camera but the selfie's) put them back for as long as they last. The race
gives EVE no velocity meanwhile. A pause keeps them at 0. If EVE no longer speeds up or stops after a race, press
Ctrl+R.

Test and tuning commands, left out of the usage line:

- `coop race drive` shows the host's driving values.
- `coop race drive probe`, on a co-op save with no race armed: EVE goes straight ahead at 15 m/s for 3 s through
  impulses, then drives with your stick as in a race until `coop race drive off`.
- `coop race drive <name> <value>` changes one driving value for your next races in an online session, until the mod
  reloads. The names are `top` (cm/s), `accel`, `brake` and `coast` (cm/s per second), `grip` and `drift_grip`
  (tenths a second: how fast a slide fades), `turn_slow` and `turn_fast` (degrees a second, standing and at top speed)
  and `drift_angle` (degrees). Each value is a whole number, kept within its range.

During a drive, `UE4SS.log` has a line every 10 s, `[StellarCoop][DR] drive v=<cm/s> vz=<cm/s> asked=<cm/s>
yaw=<degrees> heading=<degrees> air=0|1 root=0|1 drift=0|1 stumble=0|1`, and a line for each drift key pressed or
released, each wall hit and each crest. `asked` is the speed the car gave the last frame, `yaw` EVE's facing as read
one frame after the car turned her. `[StellarCoop][DR] drive hold applied` comes once the native part holds the four
values. `drive hold not applied: her movement brakes, no impulse goes` comes when it stops holding them (a cutscene,
photo mode).

## Rules

- Checkpoints count only in order. A checkpoint counts when EVE's path from one frame to the next comes within its
  radius horizontally and within 6 m vertically, at any speed. A marker over the next checkpoint shows its distance.
  An arrow at the edge of the screen points to it when it is off screen or behind you. A Doro stands at the next
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
| `Doro races do not run in a session of more than 2 players.` | A third player got into the session. Both racers get this DNF at once, the guest even before her game has linked with the new player |
| `Not finished 60 s after the winner.` | You were still racing 60 s after the first racer finished |
| `Over the 15 min limit.` | You were still racing 15 min after GO |

`coop race quit` and `coop off` end your race as a DNF too, with the command's answer instead of a notice. Before GO,
the host's quit or map change cancels the race for both players (`Race cancelled.`). A third player who gets into the
session before GO cancels it too, with the notice `Doro races do not run in a session of more than 2 players.` A guest
who quits or changes map before GO leaves the race. Before the countdown the host then races alone; during it, the
guest stays in the race as a DNF, so `POS` counts two racers and the results list the guest as `DNF`.

## Results

During the race, the panel at the top centre shows `DORO RACE`, your time (`1:23.45`), `CP`, `LAP` and `POS`. Your
place comes from laps, checkpoints and the distance to the next checkpoint, your friend's from where their ghost is.

Once every racer has finished or is out, `RESULTS` takes the panel's place for 10 s, with each racer's place and time,
or `DNF`. Times within 10 ms share a place. The host's game sends the ranking, so both screens show the same one. While
they stand still, the winner's Doro hops in place and the other Doro plays its tired animation. Then the race closes:
its Doros go. EVE and the ghost are drawn as themselves again.

Two flags can show under `RESULTS` for your own run. Neither changes the ranking.

- `fast run`: for 1 s or more, EVE moved faster than 5.5 m/s horizontally while she was not sprinting and not in the
  air. The flag was there for Tachy mode, which runs faster. A driven run's speed no longer depends on Tachy mode.
  The flag does not show while the race drives EVE.
- `paused`: the game was paused, or showed one of its own screens, for 2 s or more.

Each PC logs one line per race that reaches its results there: `[StellarCoop][DR] result id=<id> track=<name> ms=<ms>
clock=<s> time=<s> flags=<n> rank=<place>`. `ms` is your time in milliseconds, `clock` and `time` measure the race with
two different clocks (for a bug report), `flags` adds 1 for a fast run and 2 for paused, and `rank` is your place. `ms`
and `rank` read `-` after a DNF. `track` reads `-` on the guest's PC.

The panel, the banners and the results hide while the game is paused or shows one of its own screens. With the
co-op UI off (`coop ui off`, or after an engine error), they do not show. The banners other than the countdown
come as notices on the line above EVE.

## The Doro look

From the start of a race on your PC until it closes, your EVE is drawn as a Doro. The Doro stands at EVE's feet, walks
and runs on two legs, runs on all fours while she sprints, and hops when she jumps. Your friend's ghost is drawn as a
Doro from the moment their game joins the race. If it does not join, it stays EVE on both screens.

While the race drives EVE, her Doro runs on all fours from 60% of the top speed, plays its run up to 3 times faster,
faces where it is heading (so it shows its side in a drift), leans into bends, dips its nose when it lands and plays a
tired hop when it hits a wall. Your friend's Doro does the same from their ghost's movement, except the tired hop.

To draw the Doro, the look hides EVE's mesh parts in game. The native part sets her main mesh to keep animating while
hidden. The look also hides the body of the drone that follows EVE, when it is within 30 m of her as the look starts.
The drone's light and signals keep working. The race's end, `coop race quit`, `coop off`, a map change and the look's
first error undo these changes. While the look is on, `coop-look.txt` holds the parts it hid, so the next Lua load
(Ctrl+R) shows them again when this one could not. The native part puts the mesh's animation option back at that
load. If EVE or the drone stays hidden, see
[players/troubleshooting.md](../../players/troubleshooting.md#eve-is-invisible-or-only-a-doro-shows).

Each Doro keeps its animations loaded while it stands. The first Doro of a race loads them all at once, so it can take
a moment to appear. None loads during the race. While the look is on, `UE4SS.log` has a line once a minute,
`[StellarCoop][DR] look hid=<n> tick=<t>->0 rehid=<n>/min retick=<n>/min reload=<n>/min reload_ms=<ms>`. `reload`
counts the Doro animations loaded again since the look's Doro appeared. `reload_ms` is the total time they took. In
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

- In an online session, two players at most: a third player who gets into the session ends the race. The host starts
  every race. Only the host needs the track file. A match lobby races 2 to 8 players (see
  [Races in a match](#races-in-a-match)).
- Every racer must be on the track's map.
- Enemies stay as they are: each game runs its own fights during a race. Shared enemies, same place and same
  spawns work as usual. Record tracks through ground you have cleared.
- A race gives no reward, item, progress or achievement and writes nothing to a save. Its Doros are display only,
  with collision off: nothing can hit them. They cannot die.

## Races in a match

A Doro race is a match mode of the [SBO lobby](../lobby.md), beside free-for-all and
[score attack](scoreattack.md). Every player of a race match lobby races the same track at the same time, in the room
the lobby waits in, each in her own game. Each game times its own racer and sends her splits and her time. The host's
game checks them against the track and sends the ranking: the shortest time first. A round holds 2 to 8 players. The
races of an online session do not change.

Races in a match have not been tested in game. Their code has run only in the tests (see
[Doro races: how they work](race-internals.md#races-in-a-match)).

### Starting a round

1. In the SBO lobby, open the lobby menu (F5, or View held for 1 s). Its first four rows are the modes: Free-for-all,
   Score attack, Doro race and More modes. Select on Doro race picks it for Search and Private match until the mod
   reloads, marked `picked`. Score attack stays the mode picked when the menu first opens.
2. Search joins an open public race lobby, or hosts one
   (`No race match found (SBO protocol <n>, build 26123051): hosting one.`). Private match hosts one that only its
   join code opens (`Hosting a private race match. Your join code is <code>.`). Search for a race never finds a lobby
   of another mode.
3. In a race match lobby the mode rows are Doro race (locked), Track and More modes. The host's Select on Track goes
   from Random to each track the room offers in turn, then back to Random. The pick shows beside the row, cut to 18
   characters with `…`. It lasts until the mod reloads. A guest's Track row is locked and reads `Host's pick`.
4. The lobby's countdown starts once 2 players have linked: 10 s, or 5 s with 8 players. At 0 the round starts.

`coop match search race` and `coop match create race` do steps 1 and 2 from the console. While `race_match=off`, or
while the module is off, the Doro race row is locked.

Settings, tab MATCH, lists the rules of a race lobby (all locked): Players `2 to 8`, Track (the host's pick), Ranking
`Shortest time, ties within 0.01 s`, Damage between players `None` and Start `10 s from 2 players, 5 s when full`.

### Tracks a room offers

A room offers a track when the track's `map` line is the room's map and its 8 grid slots and every checkpoint's centre
stand 2 m or more inside the room's fence, horizontally, within the fence's height range. Xion's training room has a
fence of 30 m around its centre. A track recorded in Xion's streets carries the same `map` line as one recorded in the
room, so the fence test leaves it out.

The tracks come from two places:

- The official tracks ship in the mod, under `Scripts/online/modes/race/match/tracks/`. Xion's training room has
  `xion_eight`: a figure eight of 6 checkpoints of 4 m radius, 5 laps of about 129 m. It was computed from the room's
  floor and wall in the game's files. The hall lobbies have no official track yet.
- The host's own tracks: the names in `coop-tracks.txt` in the mod folder, the newest 32. `coop race save` adds the
  track it writes. `coop race match pick <name>` adds that name. A name whose `coop-track-<name>.txt` is gone or
  does not read as a track is dropped from the file as it is read. An own track named as an official one is not
  offered.

The Track row lists Random, then the room's official tracks, then the host's own tracks it offers. Random draws one of
the room's official tracks from the round's seed. With none, it draws among all the tracks offered. A pick the room
does not offer draws as Random. A room that offers no track ends the round at once. The host then gets the notice
`No track here: record one in this room with coop race record.` Only the host needs the track file: her game sends
the track to the others.

### A round

At the countdown's 0 every game closes the lobby menu. The log reads `[StellarCoop] round start: Doro race`. The
host's game fixes the track and sends it to every player, one line each 250 ms. Each game, once it has the whole
track:

1. stands EVE up if she sits on a hall seat through F5. A player that Stellar Blade's own chair seats (its Rest
   prompt) sits out instead: the mod cannot stand her up from the game's chair;
2. moves her to her slot on the start line, facing the track's way. The slots stand in rows of two, 3 m apart across
   and 3 m back from row to row: slot 1 on the left of the start line's centre, slot 2 on its right, slots 3 and 4
   behind them and so on to slot 8. Her slot is her place in the round's player list: the host first, then the
   others in Steam's member order;
3. draws EVE and every other round player's ghost as a Doro;
4. starts the 4 s countdown: 3, 2, 1, then GO.

The host's countdown starts at the round's start. A guest's starts when the host's lines have come: about 1 s later on
`xion_eight` (3 lines), up to about 2 s on a track of 64 checkpoints (8 lines), plus the ping. Each racer is timed
from her own GO by her own game's clock, so this does not change the times. A pause does not stop the clock.

There is no false start in a match. At GO, a racer more than 3 m from her slot is moved back onto it. The race then
runs as in a session: the same checkpoints, laps, missed checkpoints, wrong way and DNFs (see [Rules](#rules)), with
the driving of [Driving](#driving) at its default values. The late rule starts at the first finish your game hears of,
yours or another racer's: 60 s later you are out with `Not finished 60 s after the winner.` The 15 min limit holds.

At GO, a racer more than 3 m from her slot whom Stellar Blade's own chair seats is not moved back. She sits out with
`Get up from your seat to race in the next round.` Her game sends a DNF `quit` for her, since the host already counts
her as ready, then closes her race.

A player who cannot race sits out the round. She gets one notice and one `[StellarCoop][DR] sit out: <why>` line in
her log. Her game sends nothing:

| Notice | When |
| --- | --- |
| `Doro races are off in Options: you sit out this round.` | `race_match=off` |
| `Get off the bike to race in the next round.` | EVE rides the [bike](../../vehicles/bike.md) |
| `Get up from your seat to race in the next round.` | Stellar Blade's own chair seats EVE in a [hall lobby](../lobby.md#hall-lobbies) |
| `A Night Operation run is on: you sit out this round.` | A [Night Operation](nightop.md) run or a challenge of `coop challenge` is on |
| `Doro races need a co-op save: you sit out this round.` | Her game does not play a co-op save |
| `You are not in the waiting room: you sit out this round.` | EVE is not in the lobby room |
| `The track is on another map: you sit out this round.` | The track's `map` line is not her map |
| `The track runs outside this room: you sit out this round.` | The track does not fit her room's fence |
| `You are recording a track or testing the drive: you sit out this round.` | A track is being recorded, the drive probe runs or a race is on |
| `Your game could not start the race: you sit out this round. UE4SS.log says why.` | No EVE in the world, the game refused the teleport to her slot, or the race stopped on an error earlier in this Lua load |
| `The track did not arrive whole: you sit out this round.` | A guest whose game got no whole track within 10 s of the round's start, or lines that do not make a valid track |

### The end and the ranking

Each game sends a split at each checkpoint and its end: the finish with its time, or a DNF with its reason. Once your
race ends, the results panel opens with your row alone and `Results still to come: <n>.`, `<n>` being the racers
still on the track.

The host's game waits for the ends. For the first 10 s of the round it waits for every player. After that it waits
only for the players whose countdown started within those 10 s and who are still in the lobby. It stops waiting 65 s
after the first finish, or 15 min 30 s after its own GO. Then it sends the ranking: the finishers by time, then the
DNFs, unplaced. Times within 10 ms share a place. A player with no end when the host stops waiting is not listed. 10 s
later the host's game ends the round. The lobby menu then opens again in every game.

The host refuses a split or an end that does not fit the track. That player is then left out of the ranking. The
host's log gets `rank: refused <name>: <why>`:

- `order`: a split that is not her next one (lap, then checkpoint), or a finish before every split came;
- `time`: a split or a finish faster than the track allows, under her split before it, or over the 15 min limit. Each
  split has a floor: the legs up to it, each the horizontal distance between two checkpoint centres (the start line's
  for the first) less both radii and 3 m, never under 0, driven at twice the default top speed (44 m/s);
- `flags`: a finish whose flags are not 0 to 3;
- `why`: a DNF with a reason the race never gives.

A second end from the same player gets `rank: refused <name>: twice`. Her first end counts, so she stays in the
ranking.

Once the ranking comes, the panel lists each player's place, name and time, or `DNF`, your row in blue. Under the
heading it reads `Not ranked.` when the ranking came without you, or `New personal best.` when your finish set your
best time on that track. The winner's Doro hops in place and the others play their tired animation. The panel closes
at the round's end, or 20 s after the ranking. With `coop ui off` the ranking comes as notices:
`Doro race: you placed <n> of <m>.` or `Not ranked.`, then `New personal best.`

A round that ends before its ranking says why to the players who raced: `The host left. This round has no ranking.`
when the host left or went silent, `The round was cancelled.` after the host's `coop match end` or when the host's
game cancelled the round. A player who sat out sees only her notice.

### What stops a round

| Event | What happens |
| --- | --- |
| A player leaves the match lobby or the SBO lobby, or her link is lost | Her race closes. The host stops waiting for her and leaves her out of the ranking |
| The host leaves, or goes silent for 10 s | The round ends in every game: `The host left. This round has no ranking.` The next host counts down and starts the next round, as the lobby does |
| The host's `coop match end` | The round ends in every game: `The round was cancelled.` |
| `coop off` | Your race ends as a DNF and closes. Your link goes with the mod, so the others count you as a player who left. The native part puts EVE's movement values back |
| A map change, or no EVE in the world for 2 s | Your race ends as a DNF (`Left the map.`), which your game sends |
| A death | The race asks no respawn. Your race ends when one of its rules sees it: EVE gone for 2 s (`Left the map.`), a respawn that moves her over 20 m (`Moved more than 20 m at once.`), else the late rule or the 15 min limit |
| A Lua reload (Ctrl+R) | Your race's state is lost. After the reload a guest's game sends a DNF. The round goes on for the others. A host's game cancels the round (`The round was cancelled.` for the others) and ends it |
| Pause, photo mode or a cutscene | Your clock runs on. A pause keeps the driving's hold on EVE's movement. Photo mode and a cutscene put it back until they end. The host's wait does not stop |
| A new round starts while your race is on | The old race closes, unranked |

### Best times

Your best time on each track goes in `coop-records.txt` in the mod folder as `best_race_<sum>=<ms> <name>`, beside
the challenges' bests. `<sum>` is the track's sum, a number made of all its numbers, so two tracks of one name from two
hosts never share a line. Your game writes it at your own finish when it beats the stored time, through a
`coop-records.txt.tmp` and a rename, as the challenges do (see
[Best runs](challenges.md#best-runs-coop-recordstxt)). The host's ranking does not change it. Races in an online
session keep no best time. The log says `[StellarCoop][DR] best on <name>: <ms> ms (was <ms or none>)`.

### Settings and commands

| Setting | Values | Default |
| --- | --- | --- |
| `race_match` | `on` or `off`. Off locks the lobby menu's Doro race row. You then sit out each round of a race lobby you are in. Options, Modes, Doro race; read at each round's start. Races in an online session do not read it | `on` |

| Command | What it does |
| --- | --- |
| `coop race match`, `coop race match status` | One line: the setting, the count of official tracks, the host's pick, the tracks the room offers, then your last round, its track, its state and its ranking, for example `OK: Doro races in matches: race_match=on, official tracks: 1; pick random; offered: xion_eight; round 2 (xion_eight): ranked; ranking: 1. Ann 41.20 s, 2. Bob 44.05 s, Cid DNF` |
| `coop race match pick <name>\|<number>\|random` | Set the pick as the host's Track row does: `OK: Doro race: next track xion_eight`. A number is the place of a track in the room's list, from 1. A name goes into `coop-tracks.txt`. Only the host's pick counts |

Without the Steam link the status line ends with `no Steam link.` and `pick` answers
`Doro races in matches need the Steam link.` The round's state is `wait` (for the host's track), `play` or `ranked`.
Once the round is over it is why the round ended: `host` (the host's `coop match end`, which the host's game also asks
10 s after each ranking), `void`, `notrack`, `track`, `host_left`, `host_lost`, `left`, `replaced`, `reload` or
`coop off`.

### Log lines

`UE4SS.log` gets `[StellarCoop][DR]` lines:

| Line | When |
| --- | --- |
| `match round <n>: <track>, seed <seed>, slot <k> of <players>` | The round's track is known: your race starts on slot k |
| `sit out: <why>` | You sit out the round |
| `race <seed>: out of slot <k> at GO: put back` | You stood more than 3 m from your slot at GO |
| `race <seed>: out of slot <k> at GO: sit out: SB's chair seats EVE` | Stellar Blade's own chair seated you more than 3 m from your slot at GO |
| `rank: rank <seed> <id>:<ms>,...,<id>:dnf` | The host's game sent the ranking (`rank: rank <seed> -` for nobody) |
| `rank: refused <name>: <why>` | The host's game refused a split or an end |
| `line refused from <name>: sender` or `malformed` | A line from a player who may not send it, or one that cannot be read (once a player a round) |
| `match round <n> was playing at this Lua load: void` or `dnf` | A Lua reload in a round: the host cancels it, a guest sends a DNF |
| `match round <n>: this room offers no track: void` | The host's room offers no track |
| `match round <n>: no whole track within 10 s`, `match round <n>: the track did not come whole: <why>` | A guest's track did not come whole |
| `best on <name>: <ms> ms (was <ms or none>)`, `records: <why>` | Your best time written, or why it was not |
| `official track <name>: <why>`, `coop-tracks.txt: <n> names without a track file dropped` | A track file that could not be read |
| `match round: error (logged once until the mod reloads): <error>` | The round stopped on an error; races go on |

The `result id=<seed> track=<name> ...` line of [Results](#results) comes at each race's results. `coop-link.log`
gets `dr lines, last 60 s: <in> in, <out> out, <dropped> dropped` after the 60 s link line, in each minute that
carried race lines of a match. Past the rate limit it gets at most once a minute `dropped our dr lines: over the rate
limit` or `dropped dr lines from <name>: over the rate limit` (or `too many waiting`).

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
