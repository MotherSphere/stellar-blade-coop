# Story together: how it works

The player's side is in [Story together](../story-together.md). Story together (`shared_story`, experimental, on by
default) has not run in game yet. Every address and offset below is build 26123051's, read in Ghidra.

The code is split as for the [shared world](shared-world.md):

- `native/src/story/rows.h`: the scene and trip lists, written by `tools/story_rows.py`;
- `native/src/story/sync.h`: the lines, the host's reader (`Lead`), both players' sides (`Sync`), the story gate, the
  leash and the status line, with no Windows types and no game call;
- `native/src/story/engine.h`: the theater reads and the game calls, through a `Game` that is SB's memory on Windows
  and fake memory in the tests;
- `native/src/glue/tick/story_game.inc`: the hooks and each frame's pass on the game thread;
- `native/src/glue/tick/story_worker.inc`: Lua's request, the slot swaps, channel 2 and the status line on the worker;
- `native/src/quest/sync.h` and `quest/engine.h`: the guest's quest steps the host makes (`SBQ22 step`);
- `mod/StellarCoop/Scripts/commands/scenes.lua` and `main.lua`: the setting, `coop scenes` and the notices.

## Model

The host leads and never waits. For each scene he plays, his game sends its root (a ZoneEventTable row, or a talk's
theater path), then his place in it and each result that picks a branch, then its end. The guest replays the root
through the function SB used, with her own player as caster, so her game runs the scene's end from its own tables.
Each result is written once into her copy, keyed by its take (a TakeUID), its widget class and its ordinal in that
take. A leash pauses her copy where his last position stands. SBO never stops or skips her copy through SB's do-skip:
it always ends through its last take into End. When his scene ends, the link drops or he starts another scene, the
leash and her input holds go. Her copy then plays out. A scene she cannot play keeps the
[cutscene wait](../playing-with-a-friend.md#cutscene-wait).

## The host's side

The theater manager is the global at `0x1470375a0`, read and never made (its getter allocates). Its `+0x18` is the
theater that plays (P). P's `+0x28` is the take context (C), made for each take; C's `+0x40` is the take data, whose
`+0x28` is the TakeUID. Each frame in game, `Lead::pass` reads P through `GameEngine::theater()`:

- A new P sends its root once its first take started. When hook 1 saw an ActionTheater node start that play id, the root
  is a `talk` line: the path (P `+0xf8`), its priority (`+0x1e0`), where it plays (`+0x114`, `+0x120`) and the first
  take. Otherwise `story/rows.h`'s `scene()` finds the ZoneEventTable row from the path, the priority, the FinishEvents
  (P `+0x158`) and his zone; the host sends it in a `play` line. A path that is neither came from one of SB's other
  theater starts; it is logged once and not shared.
- While P plays: the results his widgets committed, a skip that moved it (a rise of one of three skip latches, then a
  new take or a jump of 5 frames or more), then his position: take, sequence asset (the sequence player `+0x468`) and
  frame (`0x1424d32e0`). A position that changed only its frame goes at most every 100 ms.
- When P ends or another one starts: `end`. A skip that ended the scene sends `skip ... take -1` first.

Each result goes before the skip that leaves its take, before the position that passes it and before the end of the
scene it closed in. Results of a scene that is not shared are logged once for each play and not sent.

| Hook | Slot | Game's function | What it records |
| --- | --- | --- | --- |
| 1, ActionTheater node run | `0x145bfed88` | `0x141b7aa10` | the play id the node made (node `+0xe4`), after the game's run |
| 2, QTE OnStartBlock | `0x145d20f28` | `0x142551000` | each QTE block with its take and ordinal |
| 3, InputCounter OnStartBlock | `0x145d223b0` | `0x14254a440` | each InputCounter block, with the last one's count before its widget's next start |
| 4, ZoneEvent action run | `0x145bfece8` | `0x141b7a3c0` | the row the action runs and his zone (client `+0x68`), for trips |

The worker swaps hooks 1 to 3 once a run, when the gates first open (`shared_story` on, a friend linked, a co-op save,
no match lobby or SBO lobby session), on the pinned build only. Each swap is one aligned 8-byte compare-and-swap from
the game's function to our hook, so a slot that holds another mod's value is left as it is and logged with what each
missing hook costs. Hook 4's slot is the SBO lobby's (`game/sbo.h`'s `kJoinSlot`), which the shared world uses too:
`join_slot_install()` swaps it once for whichever feature needs it first. `coop off` and the first fault swap our
slots back from our hook only.

A QTE or InputCounter result is final once its Result shows (QTE `+0x7d8`, InputCounter `+0x820`) or its block
closed, whichever he sees first. The QTE line carries its count (`+0x7d4`) and the forced success of the
accessibility option (`+0x858`). The InputCounter line also carries its Flow entries' results as bits and whether his
take skip had run, or his take had ended, when his Result was read. An InteractionSelect of this play (`+0x718` equal
to P `+0x1dc`) or a PlayerChoice is read when its block closes: the chosen line's TakeAlias and graph exec, or the
PlayerChoice's index.

## Tables

`tools/story_rows.py` reads the table exports of the pinned build and writes the generated block of `story/rows.h`:

```
python3 -I tools/story_rows.py <folder of <Table>.uasset.json exports>
```

It reads ZoneEventTable, EventTheaterTable, EventZoneWarpTable, ZoneTable, ZoneTriggerTable, WorldTransitionTable,
ZoneEnvSpawnTable, ZoneEnvTable and the three quest tables, with `quest/sync.h`'s quest table:

- 847 scene rows over 761 paths, 146 of them a level sequence alone, 27 run by a shared quest step. Several rows can
  share a path. The priority and the FinishEvents tell most apart; the host's zone tells the rest. 44 paths keep rows
  equal in both, 17 of them with the same zone: those rows play the same theater with the same end chain, so the first
  in table order stands for them all. 38 theater rows have both a ZoneEventTable condition and AddEvents.
  RunZoneEvent runs AddEvents whatever the condition says, so the guest tests such a row's condition for her own player
  first (`0x141c8d850`, as RunEvent tests it).
- 73 story trips (PlayerWarp or ChangeZone rows). The 35 that no table starts (starter `g`: an interaction graph ran
  them on the host) are sent; the others run in each game from its own tables. Left out: the cut multiplayer's warp,
  3 warps with no target and 6 rows of test worlds.

Another game build needs the block written again from that build's tables.

## Wire

The lines go on Steam channel 2, reliable, after the tag `SBS22`. Names are FName text, found with FName's find on the
receiving side and never made. `scene` is the host's own number for one play of a scene. `take` is a TakeUID. `n` is
the ordinal of a widget's block within its take, the same in both games since both build the blocks from one
sequence.

| Line | Meaning |
| --- | --- |
| `SBS22 play <seq> <scene> <zone> <row> <take>` | a zone-event scene: its ZoneEventTable row and first take |
| `SBS22 talk <seq> <scene> <zone> <path> <priority> <x> <y> <z> <pitch> <yaw> <roll> <take>` | a talk: its theater path, priority, place (whole centimetres, hundredths of a degree) and first take |
| `SBS22 pos <seq> <scene> <take> <sequence> <frame> <0\|1>` | the host's place; 1 while his player plays |
| `SBS22 sel <seq> <scene> <take> <n> <alias\|-> <exec\|->` | an InteractionSelect: the line's TakeAlias and graph exec, `-` for None, never both |
| `SBS22 pch <seq> <scene> <take> <n> <index>` | a PlayerChoice: the index chosen |
| `SBS22 qte <seq> <scene> <take> <n> <count> <0\|1>` | a QTE: the presses counted, 1 for a forced success |
| `SBS22 cnt <seq> <scene> <take> <n> <count> <0\|1> <bits> <0\|1>` | an InputCounter: the same, its Flow results, then 1 when his take skip had run |
| `SBS22 skip <seq> <scene> <take> seek <frame>` | a skip that moved him within the take |
| `SBS22 skip <seq> <scene> <take> take <next>` | a skip that finished the take: the next take, -1 for the end |
| `SBS22 end <seq> <scene>` | his scene ended |
| `SBS22 trip <seq> <zone> <row>` | a story trip a graph ran |
| `SBS22 on <hooks>`, `SBS22 on reply <hooks>`, `SBS22 off <reason>` | the sender's state, as the shared world's; hooks: 1, 2 and 4 added for hooks 1 to 3 in |

`seq` is 1 for the first line after each `on` and one more for each later one. The guest takes them in order: an old
one is counted as bad and a gap is logged once, so the leash never steps back. Before a line is sent, the sender writes
it, parses it back and checks the lists. The worker hands our lines to `send_fight()`; a refused one waits with the
lines after it for the next pass, up to 1,024 (the shared world's `Outbox`). `link/core.h` refuses `SBS` lines in match
lobbies both ways. One that arrives there is dropped with `dropped fight data from <name>: story together is off in a
match lobby` in the log.

## The guest's side

The worker takes her `SBS` lines out of channel 2 after the shared world and before the shared fight. It hands them
to the game thread (up to 1,024 waiting there, then dropped and counted as `inbox_dropped=`). The game thread queues
them in `seq` order, up to 256; a position replaces the position of the same scene just before it, so positions never
fill the queue. Each pass in game (lion_gate open, the client in game and playing, not on SB's logic thread, our
player found, our photo pause not held) takes them in order, one start a pass.

A `play` or `talk` line goes through the story gate, in this order. Each refusal word goes to the log and counts as a
fallback:

| Check | Word |
| --- | --- |
| her zone is the host's | `zone` |
| the host's ghost stands on her map | `ghost` |
| her EVE lives (her actor's `+0x2600` not 2 to 5, RunZoneEvent's own test) | `dead` |
| no warp written (client `+0xa20`), no camp asked (`+0xb60`, `+0xb61`), no respawn (world `+0x1c4`), no Boss Challenge (client `+0x3688`) | a word for each |
| her theater already plays that path: attach to it, no start | |
| she ended that path less than 120 s ago | `replay` |
| a shared quest step runs that row: wait for it to start her copy | |
| every Epic quest of hers covers the host's last snapshot of it, his covering hers | `story` |
| her theater manager plays nothing, or its theater has finished | `busy` |

The `story` check comes from the shared quests' guest side (`quest::Engine::story_in_step`). It is false while no
guest side runs, so with shared quests off every start falls back. A start calls RunZoneEvent `0x141ca5790(world, her
id, &row, 0)` for a `play` line. A `talk` line calls the ActionTheater node's start `0x141d02830` with the path, her
actor's key (`+0x4a4`), the host's place, his priority, no FinishEvents and a zero owner key; a result below 0 refuses
it. Her copy must show within 5 s with the same path; a copy she started must begin on the host's first take. Either
failure is a fallback. Her copy then plays as hers.

While her copy follows his:

- Each result waits in her copy's list (up to 64) until her copy is in its take, then is applied once. A result for a
  take her copy has left is dropped. A skip `seek` calls `0x1424d3a20` (waiting while `0x147037680` is set). A skip
  `take` finds the host's next take in her take data and makes the stores SB's take skips make. A choice goes where
  the widget's own OnFinishBlock stores it. QTE and InputCounter values go into her open block so her own section
  end commits them. Her do-skip `0x1424d5010` is never called: its outcome depends on her played set.
- The leash: when her take and sequence asset equal the host's and her frame is at or past his, her sequence player
  pauses (`0x143b00990`). It plays again (`0x143b002c0`) when his position moves on, only on the player it paused
  and only while no dialogue line of hers waits for a press.
- Her can-skip byte (listener `+0x159`) is set to 0 after each take start, so her skip input does nothing. Her
  InteractionSelect menu keeps its input block (`+0x71c`) and her PlayerChoice its delay (`+0x714`), so neither takes
  her press; their skip latches stay taken. Her QTE and InputCounter presses are unbound at each block start
  (`0x142551ea0`, `0x14254daa0`) while the host's hook for that class is in. A class whose hook is not in on his side
  keeps her own presses. The log says so when his `on` comes.
- A dialogue line of hers that waits for a press closes through `FinishBlock 0x142549a60(widget, 0)` once the host is
  past her frame or in another take. FinishBlock never gets a negative result.

The host's `end`, another scene of his, a new partner or the feature going off on either side releases the leash and the
holds; her copy plays out with the results it has. While a copy starts or plays, or a `play` or `talk` line waits, the
photo pause is not held, so the cutscene wait does not freeze her game under it. A copy that leaves her theater manager
ends the follow.

Every game call runs on the game thread, in `coop_tick` under `lion_gate`, under story together's own SEH latch. An
applying flag keeps her own hooks from sending what SBO applied for her. SBO never calls Stop `0x1424d8a40`, do-skip
`0x1424d5010` or CreateSBZoneEvent on her copy. At `coop off`, or after a fault in StellarCoop.dll's own code,
`story_undo` gives her copy back: the pause and the input holds are released when they still stand. After a fault
outside the DLL her copy stays as it stands. The log says so.

## Trips

Hook 4 runs inside the SBO lobby's hook for the ZoneEvent action. While the host leads (the gates above, in game or
not) it keeps each row the action runs with his zone, up to 16, for the next pass in game. 34 of the story trips load
another map, so kept rows wait at most 60 s from the first pass out of game. Past that each one is logged, not sent. The
pass turns a story trip among them into a `trip` line after the scene's own lines, so a talk's end goes first.

The guest keeps up to 8 trips, each dropped when she was not in the host's zone when it came. One runs when no shared
copy plays: the story gate's zone, ghost, life, block and story checks, then RunZoneEvent with her id, SB's own replay
of a ZoneEvent row (`0x141b218d0`). RunEvent tests the row's condition and the warp row's against her. PlayerWarp moves
only the local player.

## Quest steps the guest makes first

These belong to the shared quests and need `shared_quests` on, not `shared_story`. The guest's pass sends this line
when her quest moved one SB step past the host's line it equalled, his line lacks that step and she stands in his zone:

```
SBQ22 step <gen> <seq> <id> <state> <acq> <groups> <tasks> <done> <zone>
```

The fields after `<id>` are her quest's whole state after the step, as a `q` line has it, then the zone alias she made
it in. A step marked `#`, a kill task, an item task and a step that moves the player are not sent (`step_hold()`).

The host queues her step lines per quest, the newer one replacing the older. His pass judges each one with `accept()`
on his quest as the walk read it: her quest before the step undone from her line, his zone equal to hers, his quest
holding her quest's state before the step, her task in progress in his active group, the step's zones for a `t` mark.
Then `Engine::apply` re-reads and makes SB's call on his own unit. SB runs the step's events with his EVE as caster.
His next pass sends the change to her. While he is out of game, a cutscene of his plays or his game is paused (a menu
or photo mode), the line waits, up to 16. A load drops them. Each line gets one log line. The host's `coop quests
status` answer counts her steps applied and refused.

## Status line

`coop-status.txt` holds one `story=` line, which `coop scenes status` prints:

```
story=<on|off|waiting why=<friend|match|save|partner>> scene=<none|starting|shared|out> sent= skipped= denied=
invalid= received= started= attached= shared= fallbacks= applied= refused= dropped= trips= holds= wakes= gated=
queued= overflow= bad= gaps= hooks= inbox_dropped= unsent= elsewhere=
```

It reads `story=off why=build` on another game build, `story=off why=coop_off` after `coop off` and `story=stopped`
after a fault. The line moves with every position of a shared scene, so `core/link.lua` keeps it out of `UE4SS.log`;
the native log has its events.

| Field | Counts |
| --- | --- |
| `scene` | her copy: none, starting (asked for, not shown yet), shared (following his) or out (his ended, hers plays out) |
| `sent` | our lines sent |
| `skipped` | our lines while the feature was off on either side |
| `denied` | our scenes and trips that no list holds, or no talk and no row names |
| `invalid` | our lines with a value no line carries |
| `received` | her lines in `seq` order |
| `started` | copies her game started |
| `attached` | copies her own game had started, followed |
| `shared` | copies that followed his |
| `fallbacks` | scenes she waited through as before |
| `applied` | results her game took |
| `refused` | results and trips her game refused |
| `dropped` | results and trips dropped (her copy left the take, the scene is not shared, a full list), lines off the lists |
| `trips` | trips run in her game |
| `holds` | leash pauses |
| `wakes` | dialogue waits closed |
| `gated` | her lines while the feature was off on either side |
| `queued` | her lines that wait now |
| `overflow` | her lines dropped by a full queue |
| `bad` | malformed lines, lines from the wrong side and old `seq` |
| `gaps` | `seq` numbers skipped |
| `hooks` | our slots in place, out of 4 (hooks 1 to 3 and the ZoneEvent slot) |
| `inbox_dropped` | her lines dropped before the game thread took them |
| `unsent` | our lines dropped unsent |
| `elsewhere` | hook calls on a thread other than the game thread |

## Lua side

`shared_story` is a switch in `core/link.lua`'s settings, on by default. The native part starts with it on. Once a
load, as soon as the native part has judged the save slot, `main.lua` sends `scenes off` for `shared_story=off`, or
`scenes on` for `shared_story=on` while the `story=` line reads off by the setting (`story=off scene=`). It sends
nothing while that line already agrees, or while it reads `story=off why=`, where the native part refuses any request.
The Options row sends `scenes on` or `scenes off` at once. `coop scenes on|off` sends the request itself, leaves the
setting alone and cancels the load's request. The notices come from the `story=` line: on with her each time it reads
`on` after anything else and stopped when it changes to `stopped`.

## Limits

- Nothing here has run in game.
- Not in this phase: the four other theater start callers (env ChangeState `0x141fe3b70`, the fights `0x141a38770`
  and `0x141a3af50`, `0x141c34760`), ZoneEvent_PlayLevelSeq sequences (RunEvent case 1, which never uses the
  manager), a node that plays only a subtitle sequence, select sets registered on her side, warp-block trip matching,
  holds on her own graph nodes.
- SB's writer of the requested skip at manager `+0x44` was not found. A skip through it would not raise the input
  skip latch (`+0x181`), so the host's line would miss it.
- A skip `seek` leaves out do-skip's side steps (closing the remaining widgets, the camera fade); the sequencer's own
  section teardowns are expected to close the widgets it jumps over.
- The InputCounter's send point was not read from its template: the host sends when its Result is set or when its
  block closes, whichever comes first.
- A result that comes after her copy left its take is dropped; her copy then takes her own branch.

## Addresses

| What | Address | Use |
| --- | --- | --- |
| ActionTheater node slot and run | `0x145bfed88`, `0x141b7aa10` | hook 1 |
| QTE OnStartBlock slot and function | `0x145d20f28`, `0x142551000` | hook 2 |
| InputCounter OnStartBlock slot and function | `0x145d223b0`, `0x14254a440` | hook 3 |
| ZoneEvent action slot and run | `0x145bfece8`, `0x141b7a3c0` | hook 4, through the SBO lobby's hook |
| Theater manager, UI singleton | `0x1470375a0`, `0x1470375a8` | read only; their getters allocate |
| Seek block byte | `0x147037680` | the seek waits while it is set |
| World, client, None's index | `0x1470373d0`, `0x1470373f8`, `0x147017b00` | read only |
| Frame of a listener | `0x1424d32e0` | positions |
| Theater finished | `0x1424d70c0` | the gate's idle test, the host's holds |
| Weak pointer read, make | `0x142ba9510`, `0x142ba93c0` | the root widget, kept blocks |
| ZoneEventTable condition | `0x141c8d850` | rows with a condition and AddEvents |
| RunZoneEvent | `0x141ca5790` | a `play` start, a trip (`game/sbo.h`) |
| ActionTheater start | `0x141d02830` | a `talk` start |
| Sequence player pause, play | `0x143b00990`, `0x143b002c0` | the leash |
| Seek | `0x1424d3a20` | skip `seek` |
| Next take | `0x1424d6ef0` | skip `take` |
| FinishBlock | `0x142549a60` | dialogue waits, her menus |
| QTE unbind, Result, take select, take skip | `0x142551ea0`, `0x142551530`, `0x142551290`, `0x142551300` | her QTE |
| InputCounter unbind, Result, take select, take skip | `0x14254daa0`, `0x14254b170`, `0x14254a750`, `0x14254a800` | her InputCounter |
| PlayerChoice OK | `0x1425507c0` | her PlayerChoice |
| Stop, do-skip | `0x1424d8a40`, `0x1424d5010` | never called on her copy |
