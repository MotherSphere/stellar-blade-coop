# Photo hunt

A photo hunt is a mode of online sessions. The host types `coop photohunt start` on a map with photo targets. The
host's game draws three of them from SB's PhotoChallengeTable and sends their names. Then every player looks for the
three targets in her own game and photographs them with the Camera (SB's selfie mode). At each photo, SB's own photo
check tells each game whether a target is in the photo, close enough, in the centre and faced. The first player whose
valid photo of a target reaches the host takes its point. The round ends when the three targets are taken or at the
time limit. The host's game sends the ranking. A photo hunt holds 2 to 4 players, as many as an online session holds
today.

The photo hunt has not been tested in game yet. Its code has run only in the tests (see [Tests](#tests)). The first
in-game test is whether a selfie photo reaches the mod at all (see [The photo check](#the-photo-check)).

## Starting a photo hunt

In an online session, the host types `coop photohunt start` for 15 minutes, or `coop photohunt start <minutes>` for 1
to 60 minutes. Every player past the handshake with the host takes part, the host first. Every game shows
`<host> starts a photo hunt in Xion: Cat 4, Cat 9, Memory of Xion. 15 min.`, then `Use the Camera to take the photos.`
It counts down 5 s from the moment the start line came. At 0 (GO) the round runs for that many minutes. The console
answers with the round's state line (see [Settings and commands](#settings-and-commands)).

Today three maps have photo targets: Xion (Memory of Xion and Cat 1 to Cat 10), the Wasteland (Butterfly 1 to
Butterfly 10) and the Great Desert (Fish 1 to Fish 10). The host's game reads them from SB's tables at each start (see
[The targets of a map](#the-targets-of-a-map)). A guest on another map plays too: her photos count once she gets there.

The host's start is refused, with nothing sent, in these cases:

| Answer | When |
| --- | --- |
| `STOP: A photo hunt runs in an online session.` | No online session, or a match lobby of the [SBO lobby](../lobby.md) |
| `STOP: Only the host starts a photo hunt.` | You are a guest |
| `STOP: Nobody else is in the online session yet.` | No other player is past the handshake. A player still in hers, or lost, does not count |
| `STOP: A photo hunt is already on.` | One is on |
| `STOP: Photo hunt is off in Options.` | `photohunt=off` |
| `STOP: Load a co-op save to play the photo hunt.` | Your game is not on a [co-op save](../../players/playing-with-a-friend.md#co-op-saves) |
| `STOP: Photo checks are off in this game.` | An earlier photo check of this Lua load was answered `none fault` or `none unpinned` (see [The photo check](#the-photo-check)) |
| `STOP: Could not read the photo targets.` | No world is loaded, or SB's tables could not be read |
| `STOP: This map has fewer than 3 photo targets. Try Xion, the Wasteland or the Great Desert.` | Your map has fewer than three targets |
| `STOP: Use: coop photohunt [status \| start [<minutes>] \| stop \| try [<row> ...]]` | The minutes are not a whole number from 1 to 60 |

On another game build the first start of a Lua load is not refused: the game learns that it cannot check photos only
from the answer to its first check, at GO. That round then gives `Photo checks are off in this game.` and every later
start of the Lua load is refused.

A guest takes part when her game is on a co-op save with `photohunt=on` and its photo checks are not off. Her game then
answers the start line with a ready line. Otherwise she gets one notice and sits out the round. Her game sends nothing,
shows no card and writes no record of it:

| Notice | When |
| --- | --- |
| `Photo hunt is off in Options.` | `photohunt=off` |
| `Load a co-op save to play the photo hunt.` | Her game is not on a co-op save |
| `Photo checks are off in this game.` | Her photo checks stopped earlier in this Lua load |

The host counts a guest only when her ready line came within 10 s of the start line. A player who joins the online
session during a round plays the next one. Her game hears nothing of the current one.

The mode does not check that a player has the Camera. A co-op save without it cannot take a selfie, so it scores
nothing.

## Photos and points

From GO to your end, each photo you take in selfie mode gives each of the three targets one of SB's three answers:

| Answer | What SB found |
| --- | --- |
| 3 | The target is within its distance, on screen inside the centre box, faced and not hidden. A valid photo |
| 1 | The target is within its distance, on screen and not hidden. It is outside the centre box or not faced |
| 0 | The target was not found, is farther than its distance, is off screen or is hidden behind something |

The distance is 20 m for the cats, the butterflies and the fish, 50 m for Memory of Xion. The centre box is the middle
80 % of the photo's width and 75 % of its height. Faced means the camera looks within 45 degrees of the target's own
direction (70 for Cat 2, 120 for Memory of Xion). These values are SB's own, in each row of PhotoChallengeTable: the
mode reads them through SB's check and holds none of them.

Your first 3 for a target that is open on your card makes a claim: a guest's game sends it to the host, the host's game
hands its own straight to its checks. A claim goes once a target. The host gives the target to the first claim it reads
and sends the board to every game. Each target is one point, so a round gives 3 points in all.

SB's free photo mode (Esc, Photo Mode) checks nothing: the mode reads photos of the selfie camera only. SB's own photo
quests also want the target held in the frame for a moment before the photo. The photo hunt does not: a 3 at the
shutter counts.

The photo check does not look at SB's quests. A target counts whether its quest is taken, done or never started. That
has not been checked in game yet: SB may not place a target's actor while its quest is not active.

## The end and the ranking

The round ends on the host when the three targets are taken (it ranks at once) or at its GO plus the minutes (it ranks
10 s later, for late claims). A guest's round ends at her GO plus the minutes, or at the first board with three takers.
Her card reads `Time up` and the result panel opens with `Waiting for the host's ranking.` The panel closes 20 s after
the ranking. The online session goes on. The host may start another round.

The ranking holds the counted players who are still in the online session at that time (linked, not lost), most points
first, then the earlier time of the last point (the host's seconds since its GO). Equal points and time share a place.
Every player with 0 points shares the last place. A player who left keeps her targets on the board: they do not open
again. She is not ranked.

### The host's checks

The host's game refuses a claim when:

- its sender is not a counted player (`sender`);
- its target is not 1 to 3 (`row`);
- another player took that target (`taken`). Two players can photograph one target in the same second, so this is
  not a cheat: the first claim read wins;
- the same sender claimed that target before, a claim refused for its time included (`again`);
- it comes more than 1 s before the host's GO or more than 10 s after the host's end (`time`). Each game counts its
  GO from a whole second of its own clock, so an honest guest's GO can come up to 1 s before the host's. A claim in
  that second counts 0 s.

A refused claim gives no point. The host's log gets `rank: refused <name>: <why>` once a sender and reason each round.
The host's own claims go to the same checks in its own game: the host sends no claim line. A player can win 3 claims at
most, so the mode needs no rate bound beyond the link's.

### What the checks do not catch

The host's game cannot see a guest's photo. A claim says only which target, so a modified game can claim any target.
The host's own photos are judged at its 250 ms pass, while a guest's claim also travels over Steam, so a near tie
favours the host by that much. A claim carries no time: the order in which the host reads the claims decides.

## What you see

The card and the result panel hide while the game is paused, while it shows one of its own screens and in your own
photo and selfie modes. Their words follow the game's language unless `ui_language=english`.

- The card, at the top right (the fishing tournament's place): the title line `PHOTO HUNT  12:41` (`Starts in 4`
  during the countdown, then the time left, then `Time up`), then one row a target: its name, then `open`, `you` in teal
  or the taker's name. The last line has your points and place, `2 points · place 1`, ranked as the host ranks. The
  rows come from the host's board lines. The card shows from the start line to the ranking. It hides on the title
  screen, where the co-op saves' badge takes its place. A host who runs a fishing tournament at the same time gets two
  cards that overlap.
- The result panel, at the top centre in score attack's layout: the heading `Photo hunt`, your `<points> points`, a
  note, then one row per ranked player with her place, name, the time of her last point (`m:ss` after GO, empty with 0
  points) and points. The note reads `Waiting for the host's ranking.` before the ranking, `Not ranked.` when the
  ranking came without you, `New personal best.` when your row set a [record](#best-photo-hunts), or
  `No ranking came from the host.` 30 s after your end with no ranking. The panel opens at your end. It closes 20 s
  after the ranking, or 20 s after the note that none came.

SBO shows nothing while your selfie mode is open, so a photo's words wait until you close it. Then each drawn target
that was in your photos gives one notice, the strongest of that selfie session in this order:

| Notice | When |
| --- | --- |
| `Cat 4 counts: 1 point.` | A 3 on a target open on your card: your game claimed it. The host's board still decides who takes it |
| `Cat 4 was taken by Kaanta.` | A 1 or a 3 on a target another player took |
| `Cat 4 is yours already.` | A 1 or a 3 on a target you took |
| `Cat 4 was in your photo: get closer, centre it and face it.` | A 1 on an open target |

A target with a 0 gives nothing. A 1 never means too far: SB answers 0 past the target's distance.

These notices come whatever the screens show: the start and `Use the Camera to take the photos.`, a sit-out, each target
taken (`Kaanta took Cat 4.`, `You took Cat 4.`), `The host left. This photo hunt has no ranking.`,
`The photo hunt was cancelled.`, `Your game reloaded: your photos no longer count in this photo hunt.` and the stops of
the photo checks (`Photo checks stopped in this game: restart the game to play.`, `Photo checks are off in this game.`,
`This game does not know this photo hunt's targets: your photos do not count.`). With `coop ui off` the screens come as
notices: `Photo hunt: take your photos. 15 min left.` at GO, `Photo hunt over: 2 points.` at your end, then the first
three (`Photo hunt: 1. Ann 2, 2. Bob 1.`), `You placed 2 of 3.` or `Not ranked.`, then `New personal best.` when you set
one. `No ranking came from the host.` is a notice with the UI off only.

## What stops a photo hunt

| Event | What happens |
| --- | --- |
| A guest leaves the online session, or her link is lost | Her targets stay taken. Still gone at the ranking, she is not ranked |
| A guest's link comes back (the 60 s rejoin) | The host kept her targets. She is ranked if linked at the ranking. A claim she made while her link was down may be lost: its line may have had no link to go on. Her game does not send it again |
| The host leaves | The online session ends for every guest, so the round cannot pass to a guest. Each game says `The host left. This photo hunt has no ranking.` No record. A guest's game knows it from the link's notice since the start line: `Session ended: <host> left.` or `Session ended: <host>'s game is gone.` A guest's round goes on while her own rejoin runs |
| A guest leaves the online session herself (`coop leave`), or her rejoin gives up | Her round stops with no notice of its own: the link's notice says what happened. Her game checks no more photos. If she joins the same host again before the ranking, her panel shows the ranking when it names her. Her record comes from it |
| `coop photohunt stop` on the host | Every game ends the round with `The photo hunt was cancelled.` No record |
| `coop off` | Your round stops with no line. The photo checks stop and the screens hide. Your link goes with the mod, so the host counts you as a player who left. A host's `coop off` is a host who leaves |
| A map change, a fast travel, a load or a respawn | The round goes on. Your game keeps its three targets armed. The native part finds the photo UI again each frame and looks each target up again at each photo |
| A guest's Lua reload (Ctrl+R) | The native part stops her photo checks at the new Lua session. Her game loses the round and sends nothing more. The host keeps her targets and ranks her. The first board line that names her under a round her game does not run gives `Your game reloaded: your photos no longer count in this photo hunt.` Her panel still shows the ranking when it names her. Her record comes from the world the ranking line carries |
| The host's Lua reload | The host's game loses the round. The first claim of it that the host's game hears gets a cancel back, once: each guest's game then says `The photo hunt was cancelled.` The host's game shows nothing of it. A guest whose end passed 30 s ago with no ranking shows `No ranking came from the host.` |
| A cutscene or SB's free photo mode | No selfie camera, so no photo is checked. The clock runs on |
| Pause, a death or a loading screen | The clock runs on: it is the wall clock (`os.time()`), whole seconds. Another player's free photo mode may pause your game ([photo sync](../../players/interface.md#notices)); the clock runs on then too |
| A fault in the native part | Its photo checks stop for the game run. Your game says `Photo checks stopped in this game: restart the game to play.` You stay ranked with your points |
| `coop photohunt start` while one is on | Refused |

## Best photo hunts

Your best photo hunt of each world goes in `coop-records.txt` in the mod folder as
`best_photohunt_<world>=<points> <seconds>`, beside the [challenges'](challenges.md#best-runs-coop-recordstxt)
`best_<name>` lines, [score attack's](scoreattack.md#best-runs) `best_match_<name>` lines and the
[fishing tournament's](fishing.md#best-tournaments) `best_fish_<minutes>` lines. `<world>` is SB's world alias in lower
case: `xion`, `wastelanda` (the Wasteland) or `wastelandb` (the Great Desert). `<seconds>` is the host's time of your
last point after GO. Your game writes it at the ranking from your own row in it, when you took a point and it beats the
stored best: more points, or the same points in fewer seconds. No ranking, no record: a round the host left, cancelled
or never ranked writes nothing. Neither does one you were not ranked in or scored 0 in.

The file is written as the challenges write it: through `coop-records.txt.tmp`, then a rename, with every other line
kept. A file that does not exist yet starts with the challenges' comment line. `UE4SS.log` gets
`[StellarCoop][PH] new best in <world>: <points> points, last at <seconds> s`. The file stays on your PC.

## Settings and commands

| Setting | Values | Default |
| --- | --- | --- |
| `photohunt` | `on` or `off`. Off refuses the host's start. A guest with it off sits out each round, with a notice. Options, Modes, Photo hunt; read at each start line | `on` |

| Command | What it does |
| --- | --- |
| `coop photohunt`, `coop photohunt status` | One line: your last round, its state, its clock, the board and the ranking, the photo checks' state and the targets your map offers, for example `OK: photohunt: round 1803442, 15 minutes in Xion, play, 12:41 left; board: Cat4 Kaanta (63 s), Cat9 open, MemoryOfXion open; photo checks on Cat4 Cat9 MemoryOfXion, 2 shots; targets here: MemoryOfXion Cat1 Cat2 ...`. Before the first round: `OK: photohunt: no photo hunt yet; photo checks idle; targets here: ...` |
| `coop photohunt start [<minutes>]` | On the host: a round of 15 minutes, or of 1 to 60. The answer is the state line, or one of the refusals of [Starting a photo hunt](#starting-a-photo-hunt) |
| `coop photohunt stop` | On the host: cancels the round in every game (`OK: photohunt: the photo hunt was cancelled`). On a guest: `STOP: Only the host stops a photo hunt.` With none on: `STOP: No photo hunt is on.` |
| `coop photohunt try [<row> ...]` | A test alone: SB's photo check of up to 3 PhotoChallengeTable rows by name (`Cat4`, `MemoryOfXion`) at each selfie photo for 5 minutes, with no round and no line sent. Without a row it takes the first three targets of your map in the table's order. See [Trying the check alone](#trying-the-check-alone) |

Without the Steam link each one answers `STOP: A photo hunt needs the Steam link.` Any other word, or more than three
rows, answers `STOP: Use: coop photohunt [status | start [<minutes>] | stop | try [<row> ...]]`.

The state is `play` or `ranked`. While it plays, the clock part reads `starts in <n>`, `<m>:<ss> left` or `time up`.
Once a round ended with no ranking for you, the state is why: `void` (cancelled), `host_left`, `left` (the host's own
online session ended, or a guest left hers or her rejoin gave up), `norank` (no ranking came), `out` (you sat out),
`replaced` (a new round started) or `coop off`. The board part names each target by its row name, then `open` or its
taker with the host's seconds. The ranking part (`; ranking: ...`) reads `nobody` when empty. The photo checks' part
reads `photo checks idle`, `photo checks on <rows>, <n> shots` (`, a try` during a try) or
`photo checks stopped (<why>)`. The targets part reads `none` on a map with no target, or `not read` when SB's tables
could not be read.

### Trying the check alone

`coop photohunt try` runs on any save and with any `photohunt` setting, with nobody else in the session. It is refused
while a round's photo checks run. A round's start ends it. Its answer is
`OK: photohunt: MemoryOfXion Cat1 Cat2 checked at each selfie photo for 5 minutes`. Each photo then logs
`[StellarCoop][PH] try: shot <n>: MemoryOfXion=3 Cat1=0 Cat2=0`, with SB's answer for each row (see
[Photos and points](#photos-and-points)). Its refusals:

| Answer | When |
| --- | --- |
| `STOP: A photo hunt is on: its targets are checked already.` | A round's photo checks run |
| `STOP: This map has no photo target.` | No row given and your map has no target |
| `STOP: No such photo target in this game.` | No row given has an FName in this game |
| `STOP: Photo checks are off in this game.` | An earlier check of this Lua load was answered `none fault` or `none unpinned` |
| `STOP: Could not read the photo targets.` | No row given: no world is loaded or SB's tables could not be read |

## Log lines

`UE4SS.log` gets `[StellarCoop][PH]` lines:

| Line | When |
| --- | --- |
| `round <seed>: <minutes> minutes in <world>, <row> <row> <row>, <n> players, ours` | The host started a round |
| `round <seed>: <minutes> minutes in <world>, <row> <row> <row>, <n> players, from <host>` | A guest's game heard the start line |
| `claim: <k> <row>` | Your first valid photo of target k (1 to 3) while it was open on your card |
| `rank: rank <seed> <world> <id>:<points>:<seconds>,...` | The host's game sent the ranking (`rank: rank <seed> <world> -` for nobody) |
| `ranked: rank <seed> <world> ...` | The ranking came from the host |
| `rank: refused <name>: <why>` | The host's game refused a claim (see [The host's checks](#the-hosts-checks)) |
| `line refused from <name>: sender` or `malformed` | A photohunt line from a player who may not send it, or one that cannot be read |
| `round <seed>: <why>` | The round ended for you with no ranking, with the state word of [Settings and commands](#settings-and-commands) |
| `round <seed>: our game reloaded, our photos no longer count` | A guest whose Lua reloaded heard a board line that names her |
| `void <seed>: a claim from <name> of a round we do not run` | The host's game after its Lua reload, at the first claim of the old round |
| `row <row> has no FName in this game: not checked` | A drawn target whose name this game does not hold, left out of the check |
| `no target of this round has an FName in this game: no photo checks` | None of the three is known here |
| `photo checks stopped in this game: <why>` | The native part answered `none fault` or `none unpinned` |
| `photo targets not read: <error>` | SB's tables could not be read, or no world is loaded |
| `try: <rows> for 5 minutes`, `try: shot <n>: <row>=<answer> ...`, `try: over` | `coop photohunt try`, each photo of it and its end (`try: over, a round starts` when a round ends it) |
| `record not written: <why>` | `coop-records.txt` could not be written |
| `STOP: HUD: <error>` | The screens stopped after an error; notices from then on |

`coop-link.log` gets each ask of the photo check: `photohunt (ask <n>): 3 rows checked at each selfie photo`,
`photohunt off: no photo checks` or `photohunt (ask <n>) refused: <why>` (`unpinned`, `off` or `fault`). A fault of
the native part logs once a run `photohunt fault 0x<code> in <where> reading 0x<address>: no photo checks until the
game restarts`. The mode lines have the [fishing tournament's](fishing.md#log-lines) 60 s count line and rate lines.

## How it works

The module is `online.modes.photohunt`, in `mod/StellarCoop/Scripts/online/modes/photohunt/` with its native part in
`native/src/online/modes/photohunt/`. Nothing it does reaches SB's matchmaking or Shift Up's servers: it makes no
`ServerRequest_` call and starts no zone event, so it has no entry in `tests/tools/matchmaking_scan_test.py`.

| File | What it does |
| --- | --- |
| `model.lua` | The round with no game call: the length, the clock, the host's draw, the photohunt texts and who may send each, the host's checks, the board and the ranking with shared places, the end at the third point or at the time, the native part's answer and what a new answer brings |
| `round.lua` | The round on the Steam link: the start, the texts sent and read on the mode line, the host's board and ranking, the ends |
| `game.lua` | Between the round and SB: the targets read from SB's tables, the sit-outs, the photo check asked at GO and its answers, the claims, `coop photohunt try` |
| `targets.lua` | Which rows lead to a map (from a walk of SB's tables passed in) and a row's name on screen |
| `records.lua` | A copy of score attack's `C.best`, `C.better` and `C.write` on `best_photohunt_<world>` |
| `ui/board.lua` | The card, the result panel, the notices and the photo words' queue on the kit |
| `commands.lua`, `wiring.lua` | `coop photohunt` and the module's manifest |
| `photohunt.h` (native) | The photo check over a game interface: the shot per photo UI object, the rows checked, the answer's text |
| `photohunt_game.inc` (native) | SB's reads and calls on the game thread under the part's latch |
| `photohunt_worker.inc` (native) | The worker's side: Lua's `photohunt` request, the engine line's `photohunt=` and the fault's log line |

The wiring reads no other module (`uses` is empty). It exports `photohunt` (the round) and `photohunt_board` (the
screens). `main/pass.lua` ticks the round every 250 ms after the inbox, then the game side and the screens. `coop off`
stops it from `main/commands.lua`. `main/ui.lua` builds the screens after the fishing tournament's. It reads shared
pieces only, among them `core/where.lua` (a loaded world, EVE's map), `core/unreal.lua` (SB's tables), `core/worlds.lua` (each
world's map), `core/link.lua`'s files (the records), `M.fname`, `M.photo_state`, `M.coop_slot` and the `photohunt`
setting.

### The targets of a map

At each `coop photohunt start` on the host, at `coop photohunt try` without a row and at each `coop photohunt status`,
the game reads three of SB's tables under pcall, as gun mode walks its rows:

- every row of `/Game/Local/Data/PhotoChallengeTable.PhotoChallengeTable` with `ForEachRow`, its name and its
  `TargetZoneEnvActorAlias`;
- that alias's row of `/Game/Local/Data/ZoneEnvSpawnTable.ZoneEnvSpawnTable` (`FindRow`), its `ZoneList`;
- each zone's row of `/Game/Local/Data/ZoneTable.ZoneTable`, its `WorldAlias`.

A row counts when one of its zones has a world whose map in `core/worlds.lua` is EVE's map. The go line's world is the
world of the first row that counts. The host's game draws three distinct rows of those that count. The repository holds
no row list. On build 26123051 the table has 33 rows: 11 lead to Xion, 10 to the Wasteland (`WasteLandA`), 10 to the
Great Desert (`WasteLandB`). The two test rows `Test_SysTestD_1` and `Test_SysTestD_2` lead to no world of
`core/worlds.lua`, so they never count.

A target shows on screen by its row name split before its number (`Cat4` as `Cat 4`), in the game's language for the
four known words (`Cat`, `Butterfly`, `Fish`, `MemoryOfXion`). Any other row shows its raw name.

### The photo check

At GO each game makes the three rows' FNames with the runtime's `M.fname` (UE4SS's `FName` with `FNAME_Find`) and asks
the native part `photohunt <ask> <index> <number> ...` (ask 1 to 65535, 1 to 3 rows) in `coop-request.txt`, the form
of `coop gift`'s `items` ask. A row this game holds no FName for is left out. At its end, at `coop off` and when the
round stops, it asks `photohunt off`. A new Lua session also disarms the part. An ask with no answer after 3 s goes
again with a new number. Each ask has a new number, never the one the engine line shows, which may be an earlier Lua
load's.

Each frame while armed, on the game thread under its own SEH latch (`photohunt_faulted`), on the pinned build only and
never after `coop off`, the part reads, on build 26123051:

1. SB's photo manager (global `0x147037440`): its `+0x38` must be set and its `+0x48` must be 2, the selfie camera
   (the test of `IsSelfieMode`, `FUN_14266d5d0`). SB's photo check runs only there: its occlusion trace has a defined
   start for the selfie camera only. Any other camera: the part forgets the photo UI it saw.
2. The photo UI: SB's finder `FUN_141fc93f0` on the client's UI manager (global `0x1470373f8`, its `+0x48`) with the
   photo UI's type `0xf2`. The node's logic at `+0x60` must have the photo UI's vtable `0x145c3bee0`, whose slot 2
   (`0x141f09650`) returns `0xf2`. No node or another vtable: nothing this frame.
3. The shot: the photo UI's byte `+0x310`. The shutter `FUN_141f0d410` stores there the result of the screenshot ask
   `FUN_142371d30` (`0x141f0d4d0`), whose one caller it is. 3 means a screenshot was asked. `FUN_141f16280`, which the
   capture event's handler `FUN_141f16240` calls, sets it back to 0 (`0x141f17168`) while `DAT_147037569` is 0
   (`0x141f162b8`). No instruction of the image Ghidra holds writes that byte. Code SB decrypts at run time was not
   searched. A shot is a frame where the byte reads 3 on the same photo UI object whose byte read something else at the
   frame before. The first frame on a new object only records its byte.
4. At a shot, for each armed row: the row from SB's getter `FUN_141f24370` on `*(*(0x1470373b0) + 0x20)`, the FName by
   value as SB's challenge tick passes it (`0x141f0e30e`). While the row's byte `+8` is 0, the part sets it to 1 and
   calls the row's vfunc `+0x20` once, the lazy init SB's tick makes at `0x141f0e31e` to `0x141f0e32e`. That byte is the
   part's only write to game memory. Then SB's check `FUN_141f0d7a0(photo UI, row, &screen)` gives 0, 1 or 3. A null
   row counts 0. So does any other result. The check runs only while the registry (global `0x1470373c8`) and the photo
   manager are set: their getters `FUN_141a98bc0` and `FUN_141add5a0`, which the check calls, allocate when null.

Rows are looked up at each shot and the photo UI found again each frame, so no game pointer outlives a map change. The
check reads the camera, the target actor, the viewport and runs one `RaycastSingle` (`PhotoChallengeTrace`). It looks
at no quest. The part never calls SB's success path of a photo challenge (`FUN_141f0ea50` and the `FUN_141a314e0` it
calls) and never writes the photo UI.

The engine line of `coop-status.txt` gets `photohunt=<ask> <shots> <v1>,<v2>,<v3> <l1><l2><l3>`: the shots since the
ask, then for each armed row in the ask's order the number of the last shot that gave it a 3 (0 for none), then its
answer at the last shot. It reads `photohunt=<ask> none <why>` off the pinned build (`unpinned`), after `coop off`
(`off`) or after the latch (`fault`). It has no `photohunt=` before the first ask of the run, after `photohunt off` and
after a new Lua session. Lua reads its own ask's answer every 250 ms pass. A row whose `v` rose is a valid photo of
that target. When `shots` rose, the `l` answers give the photo's words. `none fault` and `none unpinned` stop the photo
checks for the Lua load. `none off` ends them for the round.

The pass does not wait while SB's logic is paused: it is in selfie mode. The Lua frame loop runs the native tick each
frame, photo modes included.

Not read: whether a selfie on PC reaches `+0x310`. Two paths would hide it. The shutter runs only while the photo UI's
`+0x1c8` holds a child panel (`JZ` at `0x141f0d426`). Its setter `0x141f15ae0` is bound to the child panels of types
`0xf3` to `0xf5`. The event that fires it was not read. The platform object of `FUN_142371d30` may also answer the
screenshot at once, so the byte goes back to 0 in the same call. Only a test in game can tell.

### The mode line

The photo hunt's texts go on channel 0 as `SBC<protocol> mode photohunt <text>`, reliable, in an online session only
(see [The mode line](../steam-link-internals.md#the-mode-line)). The mode adds no line kind and no protocol change:
it uses the fishing tournament's. Each line carries one text:

| Text | From | When |
| --- | --- | --- |
| `go <seed> <minutes> <world> <row>,<row>,<row> <id>,<id>,...` | The host | `coop photohunt start`: the world alias, the three rows, 2 to 8 SteamIDs, each once, the host first |
| `ready <seed>` | Each guest who takes part | At the start line |
| `claim <seed> <k>` | Each guest who takes part | Her first valid photo of target k (1 to 3) while it is open on her card |
| `board <seed> <id>:<s>,<id>:<s>,<id>:<s>` | The host | At each point given: who took each target and the host's seconds since its GO; `0:0` for an open one |
| `rank <seed> <world> <id>:<points>:<s>,...` | The host | Once, at the third point or at the host's end plus 10 s; `-` for nobody |
| `void <seed>` | The host | `coop photohunt stop`, or the answer to a claim of a round the host's game does not run |

The seed (1 to 2^31 - 1) ties the lines to one round. A game takes `go`, `board`, `rank` and `void` from the online
session's host only. The host takes `ready` and `claim` from the start line's players only. Guests link with each other,
so the mode line reaches them too: a guest drops another guest's `ready` and `claim` with no log line. The sender's
SteamID comes from Steam, never from the text. World and row names are letters, digits and `_`, 32 characters at most.
A `go` line for 8 players with 17-digit SteamIDs and the longest names is 292 bytes, under the link's 512. The `rank`
line carries the world, so a guest whose Lua reloaded can still write her record.

## Tests

The Lua tests are in `tests/lua/online/modes/photohunt/`: `model_test` (the length, the clock, the draw, the texts and
their refusals, who a game takes each from, the host's checks, the board, the ranking with shared places for 2, 4 and 8
players, the native part's answer and what a new one brings, the photo's words), `round_test` (the round on a fake link
and clock: the start and its refusals, each check of the host, two claims of one target in one pass, the end at three
takers and at the time, a guest who is lost and comes back, the host leaving, a guest who leaves or whose rejoin gives
up, `coop photohunt stop`, a guest's and the host's Lua reload), `game_test` (the targets walk, the sit-outs, the asks
and their numbers, `M.fname` nil for one row and for all, the answers, a map change with the ask kept armed, each
`none`, `coop photohunt try`), `targets_test`, `board_test` (the screens on a fake kit and their notices),
`records_test` (the copy of the records), `photohunt_test` (`coop photohunt`) and `off_test` (the module turned off
alone). `tests/lua/main/photohunt_test.lua` covers the records file, the pass line, the `coop off` stop and the screens
through `main.lua`. The native `tests/native/online/modes/photohunt/photohunt_test.cpp` runs the photo check over a
fake game, a map change included. `link_protocol_test` covers the `photohunt` request (see [Tests](../../dev/tests.md)).

Not checked in game: everything on this page. In particular whether a selfie reaches the photo UI's `+0x310` (see
[The photo check](#the-photo-check)), how many frames the byte stays 3, whether a target answers outside its quest or
while its zone is far, what a co-op save without the Camera shows and where the card sits against SB's own HUD at the
top right. Not read in SB: the value of `PhotoChallenge_FocusWaitTime` and which event sets the photo UI's `+0x1c8`.
