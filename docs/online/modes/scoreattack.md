# Score attack

Score attack is a match mode of the [SBO lobby](../lobby.md). Every player of a match lobby plays the same
[challenge](challenges.md) at the same time, in her own game, from her own spot in the lobby room. Each game counts its
own score and sends it at the end of its run. The host's game checks each result and sends the ranking: the best score
first, then the shortest time. The other players stay visible as [ghosts](../partner.md) during the round. No player
can hurt another. A round holds 2 to 8 players. The solo challenges of `coop challenge` do not change.

Score attack has not been tested in game yet. Its code has run only in the tests (see [Tests](#tests)).

## Starting a round

1. In the SBO lobby, open the lobby menu (F5, or View held for 1 s). Its first four rows are the modes: Free-for-all,
   Score attack, Doro race and More modes. Score attack is picked when the menu first opens, marked `picked`. Select on
   Free-for-all, Score attack or Doro race picks that mode for Search and Private match until the mod reloads.
2. Search joins an open public score attack lobby, or hosts one
   (`No scoreattack match found (SBO protocol <n>, build 26123051): hosting one.`). Private match hosts one that only
   its join code opens (`Hosting a private scoreattack match. Your join code is <code>.`). Search for one mode never
   finds a lobby of the other. A lobby keeps its mode for its whole life.
3. In a score attack match lobby the mode rows are Score attack (locked), Challenge and More modes. The host's Select
   on Challenge goes from Random to each challenge the room offers in turn, then back to Random. The pick shows beside
   the row and lasts until the mod reloads. A guest's Challenge row is locked and reads `Host's pick`.
4. The lobby's countdown starts once 2 players have linked: 10 s, or 5 s with 8 players. At 0 the round starts.

`coop match search scoreattack` and `coop match create scoreattack` do steps 1 and 2 from the console. While
`scoreattack=off`, or while the module is off, the Score attack row is locked and Free-for-all is picked.

Settings, tab MATCH, lists the rules of a score attack lobby (all locked): Players `2 to 8`, Challenge (the host's
pick), Ranking `Best score, then shortest time`, Damage between players `None`, Equipment `The same for everyone` and
Start `10 s from 2 players, 5 s when full`.

### Which challenges a room offers

| Room | Challenges |
| --- | --- |
| Xion's training room (the lobby without the hall lobby pak) | All five |
| A hall lobby (with the hall lobby pak) | Target Practice only |

The mod works this out at each round's start from the room's 8 spots and its fence circle: a challenge is offered when
every point its run may stand a body on, from every spot, lies inside the fence. Antlion Swarm, Skull Squad and
Gauntlet also need Xion's training room, because their monsters walk on the game's navmesh and the halls have none. In
the halls the Shooting Range's dummies would stand 3 to 6 m past the fence.

Random draws one of the offered challenges from the round's seed, so every game plays the same one. A pick the room
does not offer draws as Random. A room that offers none ends the round at once (`The round was cancelled.`).

## A round

At the countdown's 0 every game closes the lobby menu. The log reads `[StellarCoop] round start: score attack`. The
host's game fixes the challenge and sends it to every player. Then each game:

1. stands EVE up if she sits on a hall seat through F5. A player that Stellar Blade's own chair seats (its Rest
   prompt) sits out instead: the mod cannot stand her up from the game's chair;
2. moves her to her spot of the lobby's ring of 8, facing its centre. Her spot is her place in the round's player list:
   the host first, then the others in Steam's member order;
3. starts the challenge's 5 s countdown there. The round's seed sets the order of the spots each wave uses, so every
   game draws the same.

The run then plays as the solo challenge does (see [The challenges](challenges.md#the-challenges)): the same waves,
time limit, heals and score. Each game spawns only its own player's monsters and dummies, around her spot, so you see
the other players as ghosts and never their monsters. Each game scales its monsters by its own difficulty, so a player
on Hard fights monsters with more HP. Items and HP are not refilled at the start. The lobby's `Preset_Eve_Max` stays
on.

A player who cannot start sits out the round. She gets one notice and one `sit out: <why>` line in her log. Her game
sends nothing:

| Notice | When |
| --- | --- |
| `Score attack is off in Options: you sit out this round.` | `scoreattack=off` |
| `Get off the bike to play the next round.` | EVE rides the [bike](../../vehicles/bike.md) |
| `Get up from your seat to play the next round.` | Stellar Blade's own chair seats EVE in a [hall lobby](../lobby.md#hall-lobbies) |
| `A Night Operation run is on: you sit out this round.` | A [Night Operation](nightop.md) run or a challenge of `coop challenge` is on |
| `You are not in the waiting room: you sit out this round.` | EVE is not in the lobby room |
| `Your game could not start the challenge: you sit out this round. UE4SS.log says why.` | The run's own start check refused: a run already on, her EVE still down after a death, a `coop no` probe rule set in this game run, no EVE or no player controller, the teleport refused, a living character within 40 m of her spot, or every run byte taken (see [Starting a run](nightop.md#starting-a-run)) |

Monsters that an earlier run left in the room do not stop a start: the census does not count them (see
[Starting a run](nightop.md#starting-a-run)).

### A death

A death ends your run as failed at once. Every way out of the game's death screen in the lobby room takes EVE out of
the room: the game's camp respawn, or its Boss Challenge exit. So the mod asks the game's in-place respawn
(`ServerRequest_ActorRespawn`, the call the [revive](../../players/playing-with-a-friend.md#revive-by-your-friend-experimental)
uses) as soon as its checks hold, for 10 s at most. A death with no run on in the lobby room of a score attack match,
in a round's result or between rounds, gets the same respawn. EVE then gets up where she fell with her recovery items
refilled.
Press no button on the death screen. 2 s after the call, a death screen still on over a living EVE is hidden; it shows
again at the next death and at `coop off`. The same call ran in game in [SBO Xion](../../world/maps/sboxion.md#a-death)
on 2026-11-25, on game build 26123051. It brought EVE back: life 3 to 1, the same pawn, walking. The death screen went
off by itself. The mouse cursor then stayed free during play. SB's death screen gives the cursor back when its logic
gets the end of its fade or of its revival animation. The in-place respawn plays neither. SBO Xion has since sent the
death screen `FinishComaRevivalAnimation`, the event SB's revival ends with. That call has not run in game. Score
attack's respawn (`online/modes/scoreattack/run.lua`) sends no such event. The respawn has not run in a score attack
lobby room. A player whose EVE is still down when the next round starts sits out that round:
her run refuses to start while her life state reads dead.

## The end and the ranking

Each game sends its result when its run ends: how it ended, the score and the time in tenths of a second. The time is
game time, as the solo run counts it, so a pause stops it. A win sends its run time rounded down to the tenth. Time up,
a death and a stop send the time limit, so at an equal score dying early never ranks above playing to the end.

The host's game waits for the results. For the first 10 s of the round it waits for every player. After that it waits
only for the players whose run started within those 10 s and who are still in the lobby. It stops waiting 5 s plus the
time limit plus 30 s after the round's start, on its own clock. Then it sends the ranking: the best score first, then
the shortest time. Equal score and time share a place. 10 s later it ends the round. The lobby menu then opens again in
every game.

The host refuses a result that does not fit the challenge. That player is then left out of the ranking. The host's log
gets `rank: refused <name>: <why>`:

- a second result from the same player (`twice`; the first counts);
- a win with a time of 0 or past the limit (`time`), or a score above every kill plus the bonus of the time left
  (`score`);
- a time up or a death whose time is not the limit (`time`), or whose score is above every kill (`score`).

A stop (an aborted run) is never ranked.

| Challenge | Score for every kill | Time bonus | Time limit | Highest score |
| --- | --- | --- | --- | --- |
| Antlion Swarm | 180 | 1 for each whole second left | 3:00 | 360 |
| Skull Squad | 320 | 1 for each whole second left | 6:00 | 680 |
| Gauntlet | 900 | 1 for each whole second left | 12:00 | 1620 |
| Target Practice | 720 | 10 a second left, to the tenth | 1:30 | 1620 |
| Shooting Range | 480 | 10 a second left, to the tenth | 2:00 | 1680 |

Players on different difficulties share one ranking. The result panel shows each player's difficulty.

## What you see

All three screens sit at the top centre, where Night Operation's card goes. They hide while the game is paused or
shows one of its own screens. Their words follow the game's language unless `ui_language=english`.

- The card: the challenge's name over `STARTS IN 5`, then `WAVE 2/3  1:12  SCORE 140`: the wave, the time left and
  your score. Between two waves the first part reads `NEXT WAVE IN 3`.
- The board under the card: one row per player of the round, the best score first. Each row has the place and the
  name, then the score with the wave (`Wave 2/3`) or, once her run ended, `Cleared`, `Time up`, `Died` or `Stopped`.
  Your row is teal. Equal scores share a place. Each game sends its score and wave at most once a second while its
  waves play.
- The result panel, in place of the card and the board when your run ends: the challenge's name (teal after a win,
  orange otherwise), your end, score and time (`Cleared · score 1246 · 0:37.4`), a note, then one row per ranked
  player with her place, name, difficulty (Normal, Story or Hard), score and time. The note reads
  `Results still to come: <n>.` while players who started have not finished, `Not ranked.` when the ranking came
  without you, or `New personal best.` after a success that set your best. The panel closes at the round's end, or
  20 s after the ranking. A player who sat out sees it too, with `Not ranked.`

A round that ends with no ranking says why in a notice: `The host left. This round has no ranking.` when the host
left or went silent, `The round was cancelled.` after the host's `coop match end` or when the host's game cancelled the
round. With `coop ui off` the screens come as notices: `Target Practice starts in 5 s.`, `Target Practice: wave 2/3.`,
`Target Practice: Cleared, score 1246, time 0:37.4.`, then `New personal best.` when your run set one, then
`Score attack: you placed 1 of 3.` or `Not ranked.`

## What stops a round

| Event | What happens |
| --- | --- |
| A player leaves the match lobby or the SBO lobby, or her link is lost for 10 s | Her run stops. The host stops waiting for her and leaves her out of the ranking |
| The host leaves, or goes silent for 10 s | The round ends in every game: `The host left. This round has no ranking.` The next host counts down and starts the next round, as the lobby does |
| The host's `coop match end` | The round ends in every game: `The round was cancelled.` |
| `coop off` | Your run stops and your game sends nothing more. Your link goes with the mod, so the others count you as a player who left. A host's `coop off` is a host who leaves |
| A map change or a load | Your run stops as the solo run does. Your game sends a stop, which is never ranked |
| A Lua reload (Ctrl+R) | Your run's state is lost and its monsters stay. After the reload a guest's game sends a stop, which is never ranked. The round goes on for the others. A host's game cancels the round (`The round was cancelled.` for the others) and ends it |
| Pause or photo mode | Game time stops, so your run's time stops too. The host's wait does not stop: past it you are left out of the ranking |
| A new round starts while your run is on | The old run stops, unranked |

Monsters still alive after a time up or a death stay in the room as ordinary enemies, as after a solo run (see
[Score and the end of a run](nightop.md#score-and-the-end-of-a-run)). They can attack you in the waiting room.

## Best runs

Your best match run of each challenge goes in `coop-records.txt` as `best_match_<name>=<score> <seconds>`, beside the
solo challenges' `best_<name>` lines, which a match never changes. A match plays with the lobby's `Preset_Eve_Max` in
the lobby room, so its bests are kept apart. The file is read and written as for the solo challenges (see
[Best runs](challenges.md#best-runs-coop-recordstxt)): only after a success that beats the stored match best, never
when a monster never came or nothing was killed. The host's ranking does not change it. It stays on your PC.

## Settings and commands

| Setting | Values | Default |
| --- | --- | --- |
| `scoreattack` | `on` or `off`. Off locks the lobby menu's Score attack row. You then sit out each round of a score attack lobby you are in. Options, Modes, Score attack; read at each round's start | `on` |

| Command | What it does |
| --- | --- |
| `coop scoreattack`, `coop scoreattack status` | One line: the host's pick, then your last round, its challenge, its state and its ranking, for example `OK: score attack: pick random; round 3 (targets): ranked; ranking: 1. Ann 1246 in 37.4 s (win), 2. Bob 1100 in 41.0 s (win)`. Before the first round: `OK: score attack: pick random; no round yet` |
| `coop scoreattack pick <random\|swarm\|skulls\|gauntlet\|targets\|range\|1-5>` | Set the pick as the host's Challenge row does: `OK: score attack: next challenge targets`. Only the host's pick counts |

Without the Steam link both answer `STOP: Score attack needs the Steam link.` The round's state is `wait` (for the
host's challenge), `play` or `ranked`. Once the round is over it is why the round ended: `host` (the host's
`coop match end`, which the host's game also asks 10 s after each ranking), `void`, `host_left`, `host_lost`, `left`,
`replaced`, `reload` or `coop off`. The ranking stays in the line.

## Log lines

`UE4SS.log` gets `[StellarCoop][SA]` lines:

| Line | When |
| --- | --- |
| `round <n>: <challenge>, seed <seed>, spot <k> of <players>` | The round's challenge is known: your run starts at spot k |
| `start: run 0x2A seed 0x... at <x,y,z> yaw <degrees> map <map> challenge <name>; census: ...` | Your run started |
| `result: success waves=3/3 kills=18 score=1246 time=0:37 find_ms=0.8/2.1 challenge=targets best=1246/37 new` | Your run ended, as the solo run's `result:` line (see [The card and the result panel](challenges.md#the-card-and-the-result-panel)) |
| `sit out: <why>` | You sit out the round |
| `rank: rank <seed> <id>:<score>:<tenths>:<end>,...` | The host's game sent the ranking (`rank: rank <seed> -` for nobody) |
| `rank: refused <name>: <why>` | The host's game refused a result |
| `line refused from <name>: sender` or `malformed` | A line from a player who may not send it, or one that cannot be read (once a player a round) |
| `round <n> was playing at this Lua load: void` or `stop` | A Lua reload in a round: the host cancels it, a guest sends a stop |
| `round <n>: this room offers no challenge: void` | The host's room offers no challenge |
| `death with no run on: in the lobby room`, `respawn waits: <reason>`, `respawn not asked in 10 s: <reason>`, `respawn: ServerRequest_ActorRespawn(<id>, false) asked (...)`, `respawn result: ...`, `respawn: death screen shown again (...)` | The in-place respawn after a death |
| `STOP: HUD: <error>` | The screens stopped after an error; notices from then on |

The wave, spawn, kill and record lines are the solo run's (see [Night Operation](nightop.md)). `coop-link.log` gets
`score lines, last 60 s: <in> in, <out> out, <dropped> dropped` after the 60 s link line, in each minute that carried
score lines. Past the rate limit it gets at most once a minute `dropped our score lines: over the rate limit` or
`dropped score lines from <name>: over the rate limit` (or `too many waiting`).

## How it works

The module is `online.modes.scoreattack` in `mod/StellarCoop/Scripts/online/modes/scoreattack/`. It has no native part
and writes no game memory.

| File | What it does |
| --- | --- |
| `model.lua` | The round without a game call: which challenges a room offers, the pick and the Random draw, the score line's texts, a run's result, the host's checks, the ranking and the host's wait |
| `round.lua` | The round on the Steam link: the link's start line, the score lines sent and read, the host's draw and arbitration |
| `game.lua` | Between the round and the run: the sit-out checks, the hall seat, the run's start at the spot, the ready, now and done lines |
| `run.lua` | The run in game: a copy of `online/modes/nightop/run.lua` with Night Operation's heal and group play's in-place respawn |
| `challenges.lua`, `waves.lua` | Copies of Night Operation's five challenge definitions and wave code, the bests under `best_match_` |
| `ui/board.lua` | The card, the board and the result panel on the kit, with their notices |
| `commands.lua`, `wiring.lua` | `coop scoreattack` and the module's manifest |

The copies keep the solo run's rules and drop what a match cannot use: Night Operation's levels and night line, the
down and its revive, the shop points, the refusal in Xion, every check of the Steam session and the Shooting Range's
cut score widget. A fix in Night Operation's files does not reach them. The run's game requests are the copy's three:
`ServerRequest_CreateActor` for each monster and dummy, the full heal's `CreateSBZoneEvent` of `SE_10_E_ActorEff_011`
and `ServerRequest_ActorRespawn` after a death. Each has its entry in `tests/tools/matchmaking_scan_test.py`. None
reaches Shift Up's servers (see
[How the original matchmaking is blocked](nightop-previews.md#how-the-original-matchmaking-is-blocked)). The wave keys
are in the solo range, `0xD8000000` to `0xD8FFFFFF`: the shared enemies are off in a match lobby, so no key is paired
between two games.

The wiring reads `online.lobby`'s `sbo` (the room, its spots, the hall seat, SB's chair through `busy()`) and
`online.modes.nightop`'s `night` (whether a run is on). It exports `scoreattack` (the round) and `scoreattack_board`
(the screens). `main/pass.lua` ticks the round every 250 ms after the inbox. `coop off` stops it from
`main/commands.lua`. `main/ui.lua` builds the screens after Night Operation's. The lobby reads `scoreattack`'s pick and cycle for its Challenge row. It opens its
menu again at the end line of a round its player took part in.

The match lobby's mode is `scoreattack`, with the map word `lobby`: its round plays where the members wait. The round
starts on the link's start line (see [The start, count and end lines](../steam-link-internals.md#the-start-count-and-end-lines)).
The score lines go on channel 0 as `SBC<protocol> score <text>`, in a match lobby only (see
[The score line](../steam-link-internals.md#the-score-line)). Each carries one text:

| Text | From | When |
| --- | --- | --- |
| `go <seed> <challenge>` | The host | Once, at the round's start. The challenge is `swarm`, `skulls`, `gauntlet`, `targets` or `range` |
| `ready <seed>` | Each player | Her run's countdown started |
| `now <seed> <score> <wave>` | Each player | Her score or wave changed, at most once a second while her waves play |
| `done <seed> <end> <score> <tenths>` | Each player | Her run ended: `win`, `time`, `dead` or `stop` |
| `rank <seed> <id>:<score>:<tenths>:<end>,...` | The host | The ranking, best first, or `-` for nobody |
| `void <seed>` | The host | The host's game lost the round (a Lua reload) or its room offers no challenge |

The seed is the round's, from the start line, the same in every game. A game takes `go`, `rank` and `void` from the
match lobby's owner only. It takes `ready`, `now` and `done` from the round's players only. The sender's SteamID comes
from Steam, never from the text. A guest may read `go` before the start line shows its seed: she keeps it for 10 s.

## Tests

The Lua tests are in `tests/lua/online/modes/scoreattack/`: `model_test` (the offered rule on planted rooms, the draw,
the texts and their refusals, the host's checks and wait, the ranking), `round_test` (the round on a fake link and
clock), `game_test` (the sit-outs and the run's start), `run_test` (the copied run on strict fakes of the game, the
respawn included), `board_test` (the screens on a fake kit and their notices), `challenges_test` and `waves_test` (the
copies), `scoreattack_test` (`coop scoreattack`) and `off_test` (the module turned off alone).
`tests/lua/main/scoreattack_test.lua` covers the pass line and the `coop off` stop through `main.lua`. The native
`link_protocol_test` and `link_match_test` cover the score line. The lobby's tests cover its rows (see
[Tests](../../dev/tests.md)).

Not checked in game: everything on this page. In particular the places and sizes of the screens, whether a character
of Xion stands within 40 m of the training room's spots (every player would sit out), whether a Target Practice dummy
stands in a hall's wall (only the fence circles were compared), the drone's ranged mode with `Preset_Eve_Max` in the
Shooting Range, the death screen and the respawn in the lobby room, and a cutscene during a round.
