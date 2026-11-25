# Fishing tournament

A fishing tournament is a mode of online sessions. The host types `coop fish start`. Then every player of the online
session fishes for the same number of minutes, each in her own game and wherever she wants, with the game's own
fishing. Each catch scores the Fishing Points SB pays for it. Each game reads its own catches from SB's fishing log book
and sends them to the host. The host's game checks each catch, keeps the board and sends the ranking at the end. A
tournament holds 2 to 4 players, as many as an online session holds today. The fish stays in your co-op save's
inventory, as in normal play.

The fishing tournament has not been tested in game yet. Its code has run only in the tests (see [Tests](#tests)).

## Starting a tournament

In an online session, the host types `coop fish start` for 10 minutes, or `coop fish start <minutes>` for 1 to 60
minutes. Every player past the handshake with the host takes part, the host first. Every game shows
`<host> starts a fishing tournament: <n> min.` and counts down 5 s from the moment the start line came. At 0 (GO) the
tournament runs for that many minutes. The console answers with the tournament's state line (see
[Settings and commands](#settings-and-commands)).

The host's start is refused, with nothing sent, in these cases:

| Answer | When |
| --- | --- |
| `STOP: A fishing tournament runs in an online session.` | No online session, or a match lobby of the [SBO lobby](../lobby.md) |
| `STOP: Only the host starts a fishing tournament.` | You are a guest |
| `STOP: Nobody else is in the online session yet.` | No other player is past the handshake. A player still in hers, or lost, does not count |
| `STOP: A fishing tournament is already on.` | One is on |
| `STOP: Fishing tournament is off in Options.` | `fishing=off` |
| `STOP: Load a co-op save to fish in the tournament.` | Your game is not on a [co-op save](../../players/playing-with-a-friend.md#co-op-saves) |
| `STOP: Could not read the fish table.` | SB's fish rows could not be read (see [Points](#points)) |
| `STOP: Use: coop fish [status \| start [<minutes>] \| stop]` | The minutes are not a whole number from 1 to 60 |

A guest takes part when her game is on a co-op save with `fishing=on` and could read the fish table. Her game then
answers the start line with a ready line. Otherwise she gets one notice and sits out the tournament. Her game sends
nothing, shows no board and writes no record of it:

| Notice | When |
| --- | --- |
| `Fishing tournament is off in Options.` | `fishing=off` |
| `Load a co-op save to fish in the tournament.` | Her game is not on a co-op save |
| `Could not read the fish table.` | SB's fish rows could not be read |

The host counts a guest only when her ready line came within 10 s of the start line. A player who joins the online
session during a tournament plays the next one. Her game hears nothing of the current one.

## Catches and points

Every catch of the game's fishing counts once from GO to the end: a fish, a trash catch or a box. A catch made during
the countdown does not count. Neither does one made after your game's last read of the book, a second or so after the
end (see [The end and the ranking](#the-end-and-the-ranking)). The fish, its Fishing Points and a box's items go to
your inventory through SB's own catch, as in normal play. Which fish bites depends on where you cast and which bait
you have, as in normal play. The mode has no part in it.

### Points

A catch scores the `RewardItemCount` of its row in SB's ItemFishTable: the Fishing Points SB pays at each catch of that
fish. A goldfish scores 30, a tuna 138 and a Dunkleosteus 450. The five trash catches and the four boxes score 0. They
still count as catches. Each NIKKE fish scores 100: only a game with the NIKKE DLC can catch them.

Each game reads these values from SB's own tables at the first start of a Lua load, so the repository holds no value of
SB's tables. The module holds only the 40 row names (`rows.lua`). See [The fish table](#the-fish-table).

## The end and the ranking

At GO plus the minutes your game reads its book one last time. The corner board reads `Time up` and the result panel
opens with `Waiting for the host's ranking.` The host's game takes catches until 10 s after its own end. Then it sends
the ranking, which every panel shows. The panel closes 20 s later. The online session goes on. The host may start
another tournament.

The ranking holds the counted players who are still in the online session at that time (linked, not lost), most points
first. Equal points share a place, in the order of the start line. The number of fish only shows: it breaks no tie.

### The host's checks

The host's game refuses a catch when:

- its sender is not a counted player (`sender`);
- its fish is not one of the host's 40 (`fish`);
- its points differ from the host's points for that fish (`points`);
- it comes more than 1 s before the host's GO or more than 10 s after the host's end (`time`). Each game counts its
  GO from a whole second of its own clock, so an honest guest's GO can come up to 1 s before the host's;
- it is the sender's k-th catch line, refused ones included, with k above 1 plus the whole 2 s spans since 1 s before
  the host's GO (`rate`). SB waits at least 2.0 s before each bite (its const `FishingWaitingTimeMin`), so an honest
  player stays under the bound, her GO up to 1 s before the host's included.

A refused catch does not count. Its player stays in the ranking with her other catches. The host's log gets
`rank: refused <name>: <why>` once a sender and reason each tournament. The host's own catches go to the same checks
in its own game: the host sends no catch line.

### What the checks do not catch

The rate bound stops a flood of catch lines. It does not stop a careful cheat: a real catch takes far longer than 2 s
(the cast, a wait of 2 to 5 s, the fight and the 2.9 s success effect). The host's game cannot see these:

- SB's `FishingGod` test effect, which wins each fight faster. `coop devmenu` does not offer it;
- a flag of SB's fishing state (FSBActor `+0x2afd`) that brings each bite at once and skips the fight. What sets it in
  SB was not found;
- whether a guest has the NIKKE DLC. The DLC list comes from the same game as the catch, so the host does not check a
  NIKKE fish against it.

## What you see

The corner board and the result panel hide while the game is paused or shows one of its own screens. Their words follow
the game's language unless `ui_language=english`.

- The corner board, at the top right: the title line `FISHING  7:42` (`Starts in 4` during the countdown, then the time
  left, then `Time up`), then the top three rows with place, name and points. A fourth row shows yours when you are not
  in the top three. Your row is teal. The rows come from the host's board lines, sent at most once a second when the
  standings changed. Before the first one, every player stands first at 0. The board shows from the start line to the
  ranking. It hides on the title screen, where the co-op saves' badge takes its place.
- The result panel, at the top centre in score attack's layout: the heading `Fishing tournament`, your
  `<points> points · <n> fish`, a note, then one row per ranked player with her place, name, fish and points. The note
  reads `Waiting for the host's ranking.` before the ranking, `Not ranked.` when the ranking came without you,
  `New personal best.` when your row set a [record](#best-tournaments), or `No ranking came from the host.` 30 s after
  your end with no ranking. The panel opens at your end. It closes 20 s after the ranking, or 20 s after the note that
  none came.

These notices come whatever the screens show: the start, a sit-out, `The host left. This tournament has no ranking.`,
`The tournament was cancelled.` and `Your game reloaded: your catches no longer count in this tournament.` (see
[What stops a tournament](#what-stops-a-tournament)). With `coop ui off` the screens come as notices:
`Fishing tournament: start fishing. 10 min left.` at GO, `Fishing tournament: place 2, 240 points.` at each change of
your place or points, `Fishing tournament: time up, 240 points, 3 fish.` at your end, then the first three
(`Fishing tournament: 1. Ann 312, 2. Bob 240.`), `You placed 2 of 3.` or `Not ranked.`, then `New personal best.` when
you set one. `No ranking came from the host.` is a notice with the UI off only.

There is no notice for your own catches: SB's result popup shows each one.

## What stops a tournament

| Event | What happens |
| --- | --- |
| A guest leaves the online session, or her link is lost | The host drops her from the board at its next pass. Still lost at the ranking, she is not ranked |
| A guest's link comes back (the 60 s rejoin) | The host kept her counted catches. She is back on the board at its next pass and ranked if linked at the ranking. A catch she made while her link was down may be lost: its line may have had no link to go on |
| The host leaves | The online session ends for every guest, so the tournament cannot pass to a guest. Each game says `The host left. This tournament has no ranking.` No record. A guest's game knows it from the link's notice since the start line: `Session ended: <host> left.` or `Session ended: <host>'s game is gone.` A guest's tournament goes on while her own rejoin runs |
| A guest leaves the online session herself (`coop leave`), or her rejoin gives up | Her tournament stops with no notice of its own: the link's notice says what happened (`Left the session.`, `Session ended: could not rejoin <host>'s game.`). Her game reads no catches after that. If she joins the same host again before the ranking, her panel shows the ranking when it names her. Her record comes from it |
| `coop fish stop` on the host | Every game ends the tournament with `The tournament was cancelled.` No record |
| `coop off` | Your tournament stops with no line. The book reads stop and the screens hide. Your link goes with the mod, so the host counts you as a player who left. A host's `coop off` is a host who leaves |
| A map change, a fast travel, a load or a respawn | The tournament goes on. Your game takes its baseline again (see [From two reads to catches](#from-two-reads-to-catches)), so a catch made in the second before it may not count |
| A guest's Lua reload (Ctrl+R) | Her game loses the tournament and sends nothing more. The host keeps her counted catches and ranks her. The first board line that names her under a tournament her game does not run gives `Your game reloaded: your catches no longer count in this tournament.` Her panel still shows the ranking when it names her. Her record comes from the minutes the ranking line carries |
| The host's Lua reload | The host's game loses the tournament. The first catch line of it that the host's game hears gets a cancel back, once: every game then says `The tournament was cancelled.` A guest whose end passed 30 s ago with no ranking shows `No ranking came from the host.` |
| Pause, photo mode, a cutscene, a death or a loading screen | The clock runs on: it is the wall clock (`os.time()`), whole seconds. You fish again when the game lets you |
| `coop fish start` while one is on | Refused |

## Best tournaments

Your best tournament of each length goes in `coop-records.txt` in the mod folder as
`best_fish_<minutes>=<points> <fish>`, beside the [challenges'](challenges.md#best-runs-coop-recordstxt) `best_<name>`
lines and [score attack's](scoreattack.md#best-runs) `best_match_<name>` lines. Each length has its own key: 5 and 30
minutes do not compare. Your game writes it at the ranking from your own row in it, when it beats the stored best: more
points, or the same points with fewer fish. A first tournament of a length always writes one. No ranking, no record: a
tournament the host left, cancelled or never ranked writes nothing. Neither does one you were not ranked in.

The file is written as the challenges write it: through `coop-records.txt.tmp`, then a rename, with every other line
kept. A file that does not exist yet starts with the challenges' comment line. `UE4SS.log` gets
`[StellarCoop][FT] new best of <minutes> minutes: <points> points, <n> fish`. The file stays on your PC.

## Settings and commands

| Setting | Values | Default |
| --- | --- | --- |
| `fishing` | `on` or `off`. Off refuses the host's start. A guest with it off sits out each tournament, with a notice. Options, Modes, Fishing tournament; read at each start | `on` |

| Command | What it does |
| --- | --- |
| `coop fish`, `coop fish status` | One line: your last tournament, its state, its clock, the board and the ranking, for example `OK: fishing: tournament 1803442, 10 minutes, play, 7:42 left; board: 1. Ann 312 (2 fish), 2. Bob 240 (3 fish)`. Before the first one: `OK: fishing: no tournament yet` |
| `coop fish start [<minutes>]` | On the host: a tournament of 10 minutes, or of 1 to 60. The answer is the state line, or one of the refusals of [Starting a tournament](#starting-a-tournament) |
| `coop fish stop` | On the host: cancels the tournament in every game (`OK: fishing: the tournament was cancelled`). On a guest: `STOP: Only the host stops a fishing tournament.` With none on: `STOP: No fishing tournament is on.` |

Without the Steam link each one answers `STOP: A fishing tournament needs the Steam link.` Any other word answers
`STOP: Use: coop fish [status | start [<minutes>] | stop]`.

The state is `play` or `ranked`. While it plays, the clock part reads `starts in <n>`, `<m>:<ss> left` or `time up`.
Once a tournament ended with no ranking for you, the state is why: `void` (cancelled), `host_left`, `left` (the host's
own online session ended, or a guest left hers or her rejoin gave up), `norank` (no ranking came), `out` (you sat out),
`replaced` (a new tournament started) or `coop off`. The board part (`; board: ...`) and the ranking part (`; ranking:
...`) read `nobody` when empty.

## Log lines

`UE4SS.log` gets `[StellarCoop][FT]` lines:

| Line | When |
| --- | --- |
| `tournament <seed>: <minutes> minutes, <n> players, ours` | The host started a tournament |
| `tournament <seed>: <minutes> minutes, <n> players, from <host>` | A guest's game heard the start line |
| `catch: <ID> <points>` | Each catch of yours from GO to your end, with its ItemTable ID and your points for it |
| `rank: rank <seed> <minutes> <id>:<points>:<fish>,...` | The host's game sent the ranking (`rank: rank <seed> <minutes> -` for nobody) |
| `ranked: rank <seed> <minutes> ...` | The ranking came from the host |
| `rank: refused <name>: <why>` | The host's game refused a catch or a ready line |
| `line refused from <name>: sender` or `malformed` | A fish line from a player who may not send it, or one that cannot be read |
| `tournament <seed>: <why>` | The tournament ended for you with no ranking, with the state word of [Settings and commands](#settings-and-commands) |
| `tournament <seed>: our game reloaded, our catches no longer count` | A guest whose Lua reloaded heard a board line that names her |
| `void <seed>: a catch from <name> of a tournament we do not run` | The host's game after its Lua reload, at the first catch line of the old tournament |
| `book jumped by <n>: baseline again` | More than 2 catches in one book read |
| `book fell: baseline again` | A fish's count fell, or a fish of the baseline was gone |
| `book fish <ID> is not in the fish table: not sent` | A book key that is not one of the 40 rows, once a tournament |
| `fish table not read: <error>` | SB's fish rows could not be read |
| `record not written: <why>` | `coop-records.txt` could not be written |
| `STOP: HUD: <error>` | The screens stopped after an error; notices from then on |

`coop-link.log` gets the worker's book read, `fishbook (ask <n>): read, <k> fish` or `fishbook (ask <n>): none <why>`,
each time the answer's kind changes (Lua asks once a second). In a minute that carried mode lines,
`mode lines, last 60 s: <in> in, <out> out, <dropped> dropped` follows the 60 s link line. Past the rate limit it gets
at most once a minute `dropped our mode lines: over the rate limit` or `dropped mode lines from <name>: over the rate
limit` (or `too many waiting`).

## How it works

The module is `online.modes.fishing`, in `mod/StellarCoop/Scripts/online/modes/fishing/` with its native part in
`native/src/online/modes/fishing/`. It writes no game memory and calls no game function. Nothing it does reaches SB's
matchmaking or Shift Up's servers: it makes no `ServerRequest_` call and starts no zone event, so it has no entry in
`tests/tools/matchmaking_scan_test.py`.

| File | What it does |
| --- | --- |
| `model.lua` | The tournament with no game call: the length, the clock, the fish texts and who may send each, the host's checks, the board and the ranking with shared places, the catches from two book reads |
| `round.lua` | The tournament on the Steam link: the start, the fish texts sent and read, the host's board and ranking, the ends |
| `game.lua` | Between the round and SB: the fish table read, the sit-outs, the book asked once a second and its answers |
| `records.lua` | A copy of score attack's `C.best`, `C.better` and `C.write` on `best_fish_<minutes>` |
| `rows.lua` | The names of SB's 40 fish rows, no value |
| `ui/board.lua` | The corner board, the result panel and their notices on the kit |
| `commands.lua`, `wiring.lua` | `coop fish` and the module's manifest |
| `fishing.h` (native) | The book read over a read function: SB's path to the book and the walk of its set |
| `fishing_worker.inc` (native) | The worker's answer to Lua's `fishbook` request, in the engine line's `fish=` |

The wiring reads no other module. It exports `fishing` (the round) and `fishing_board` (the screens). `main/pass.lua`
ticks the round every 250 ms after the inbox, then the game side and the screens. `coop off` stops it from
`main/commands.lua`. `main/ui.lua` builds the screens after score attack's. It reads shared pieces only, among them
`core/where.lua` (a loaded world, EVE's map), `core/unreal.lua` (SB's tables), `core/link.lua`'s files (the records),
`M.coop_slot` and the `fishing` setting.

### The fish table

At the first start of a Lua load, each game reads the 40 rows by name under pcall, as gun mode reads its rows: `ID` from
`/Game/Local/Data/ItemTable.ItemTable` and `RewardItemCount` from `/Game/Local/Data/ItemFishTable.ItemFishTable`, with
`FindRow(<name>)`. The rows are the 34 base rows `Fish_GoldFish` to `Fish_Box4`, then the six `Fish_Nikke_*`. Each
ItemFishTable row has an ItemTable row of its name. A missing row, an ID not above 0, points below 0 or two rows with
one ID fail the read. A failed read is tried again at the next start. A good one is kept for the Lua load. The fishing
log book keys on the ItemTable ID: 9201 to 9250 on build 26123051.

### The book read

SB counts each fish's catches in its fishing log book. At each lift-up `FUN_141ac43c0` adds 1 to that fish's count
while it is under 999999, or adds the fish with a count of 1. A load fills the book again from the save. A sale to the
fish shop, a box or a gift moves the inventory with no catch, so the mode reads the book and not the inventory.

Lua asks `fishbook <ask>` (ask 1 to 65535) in `coop-request.txt`. The worker reads the book at once through
`ReadProcessMemory`, as `coop gift` reads the inventory (see
[The inventory read](../../cutmenus/menus-internals.md#the-inventory-read)). The engine line of `coop-status.txt` gets
`fish=<ask> <ID>:<count>,...` (IDs ascending), `fish=<ask> -` for an empty book, or `fish=<ask> none <why>`: `unpinned`
(another game build), `noeve` (no logic yet, no actor of EVE's GUID, or one that fails SB's own test), `nobook` (SB made
no book) or `unread` (a failed read, an implausible value or a torn read). After `coop off` the status leaves `fish=`
out and only the worker's log line has `none off`. The read takes the path of SB's lift-up on build 26123051:

- EVE's GUID at client `+0x58` (`slot::kPlayerGuid`);
- the logic singleton at `0x1470373e0` (its getter `FUN_141a98a30` makes it when null; the read never does, so 0 is
  `noeve`);
- its actor map at `+0x170`, a TSet of 0x18-byte elements (GUID `+0`, actor `+8`, chain `+0x10`), looked up by EVE's
  GUID as `FUN_141ad7cf0` does;
- `FUN_141ad7cf0` then calls the actor's vtable `+0x28`, `0x141ba5a30`, which a read cannot call. The read makes that
  slot's tests itself: the GUID at `+0x20` above 0, the alive byte at `+0x491` not 0 and the FSBActor at `+0x60` not 0.
  It also wants the logic actor's vtable `0x145c11e40` and EVE's GUID at `+0x20`;
- the book at FSBActor `+0x2678` (the lift-up's `MOV RBX,[RAX+0x2678]` at `0x141badbae`), null when SB made none, with
  the vtable `0x145bfca38`;
- the book's TSet at `+8`: 0x28-byte elements (the ItemTable ID as an int32 at `+0`, the catch count as a uint32 at
  `+0x14`, the chain at `+0x20`), each in the bucket ID & (hash size - 1).

The book has no list of keys, so the read runs the chain loop of `cutmenus/items.h`'s find on every bucket of the hash
(its own copy). SB's logic thread may change the set while the worker reads it. A torn read ends as `unread`, never in
a loop or a wrong list: more than 1024 elements or buckets, an inline hash of more than one bucket, a chain longer than
the count, an index outside the array, an ID not above 0, outside its bucket or found twice, or a walk that does not
find the header's count less its free count.

From GO to your end Lua asks once a second, plus one last ask at the end. An ask waits 3 s for its answer before the
next one goes. Each ask has a new number, never the one the engine line shows, which may be an earlier Lua load's.

### From two reads to catches

The first good answer after GO is the baseline. Between two answers on one baseline, each fish whose count rose by d
gives d catches. A fish new in the book gives its count. Then:

- the baseline is taken again, as the next good answer, which counts nothing: after a `none` answer other than
  `unread`, a pass with no loaded world (a loading screen, the title), a change of EVE's map, or the slot verdict
  leaving `coop`. The answer to an ask sent before such a pass is dropped. No ask goes in that pass;
- `none unread`, or an answer that cannot be read as a book, keeps the baseline. A first catch of a fish (a new
  element) is when a read most often tears, so a new baseline there would lose that catch;
- a count that fell, or a fish of the baseline missing, counts nothing (`book fell: baseline again`). The next good
  answer is the baseline: outside a load or a rebuild only a catch writes the book. A catch only adds;
- more than 2 catches in one answer counts nothing (`book jumped by <n>: baseline again`). The next good answer is the
  baseline. A bite waits at least 2 s, so a read 1 s after the last sees one catch at most. 2 covers one late answer;
- a fish that is not one of the 40 rows is logged once and never sent;
- at your end no last ask goes when no baseline is left.

### The mode line

The fish texts go on channel 0 as `SBC<protocol> mode fish <text>`, reliable, in an online session only (see
[The mode line](../steam-link-internals.md#the-mode-line)). Each carries one text:

| Text | From | When |
| --- | --- | --- |
| `go <seed> <minutes> <id>,<id>,...` | The host | `coop fish start`: 2 to 8 SteamIDs, each once, the host first |
| `ready <seed>` | Each guest who takes part | At the start line |
| `catch <seed> <ID> <points>` | Each guest who takes part | One per catch: the ItemTable ID and her game's points for it |
| `board <seed> <id>:<points>:<fish>,...` | The host | Every counted player, best first; at most once a second, when it changed |
| `rank <seed> <minutes> <id>:<points>:<fish>,...` | The host | Once, at the host's end plus 10 s; `-` for nobody |
| `void <seed>` | The host | `coop fish stop`, or the answer to a catch of a tournament the host's game does not run |

The seed (1 to 2^31 - 1) ties the lines to one tournament: an online session has no round number of the link. A game
takes `go`, `board`, `rank` and `void` from the online session's host only. The host takes `ready` and `catch` from the
start line's players only. Guests link with each other, so the mode line reaches them too: a guest drops another
guest's `ready` and `catch` with no log line. The sender's SteamID comes from Steam, never from the text. A full `rank`
line for 8 players is about 265 bytes, under the link's 512.

## Tests

The Lua tests are in `tests/lua/online/modes/fishing/`: `model_test` (the length, the clock, the texts and their
refusals, the host's checks, the standings, the board and the ranking for 2, 4 and 8 players, the catches from book
reads with their baseline rules), `round_test` (the tournament on a fake link and clock: the start and its refusals,
each check of the host, a guest who is lost and comes back, the host leaving, a guest who leaves or whose rejoin gives
up, `coop fish stop`, a guest's and the host's Lua reload), `game_test` (the fish table read, the sit-outs, the asks and
their timing, each event that takes the baseline again), `board_test` (the screens on a fake kit and their notices),
`records_test` (the copy of the records), `fishing_test` (`coop fish`) and `off_test` (the module turned off alone).
`tests/lua/main/fishing_test.lua` covers the records file, the pass line, the `coop off` stop, `fishing=off` and the
co-op save check through `main.lua`. The native `tests/native/online/modes/fishing/fishing_test.cpp` reads a fake memory
image laid out like build 26123051's, hostile memory included. `link_protocol_test`, `link_group_test`,
`link_match_test` and `link_core_test` cover the mode line and the `fishbook` request (see [Tests](../../dev/tests.md)).

Not checked in game: everything on this page. In particular the book read and its count at a catch, whether a fast
travel, a camp rest or a respawn rebuilds the book (the baseline rules cover each case), the corner board's place
against SB's own HUD at the top right and whether a reliable Steam line sent while a guest's link is down arrives
after her rejoin. Not read in SB: who sets the FSBActor `+0x2afd` flag, who calls the book's other rebuild
(`FUN_14bbb3c80`) and whether a config file changes `FishingWaitingTimeMin`.
