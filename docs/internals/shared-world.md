# Shared world: how it works

The player's side is in [Shared world](../shared-world.md). The shared world (`shared_world`, experimental, on by
default) has not run in game yet. Every address and offset below is build 26123051's, read in Ghidra.

The code is split as for the shared quests:

- `native/src/world/rows.h`: the four lists of what may be shared, written by `tools/world_rows.py`;
- `native/src/world/sync.h`: the lines, the ring, both players' sides and the status line, with no Windows types and
  no game call;
- `native/src/world/engine.h`: the root reads and the game calls, through a `Game` that is SB's memory on Windows and
  fake memory in the tests;
- `native/src/glue/tick/world_game.inc`: the hooks and each frame's pass on the game thread;
- `native/src/glue/tick/world_worker.inc`: Lua's request, the slot swaps, channel 2 and the status line on the worker;
- `mod/StellarCoop/Scripts/commands/world.lua` and `main.lua`: the setting, `coop world` and the notices.

## Roots

A player's interaction with an env (SB's word for a placed object with states) runs an interaction graph. A graph
changes an env through four kinds of nodes. Each change one of them makes is a root. Only roots are sent. What a
root sets off afterwards (the lever's own events opening its door, a counter reaching its target) runs in each world
from that world's tables, so it never goes on the wire.

| Root | Node | Slot | Run | Fields read |
| --- | --- | --- | --- | --- |
| R1 | ChangeEnvState action | `0x145bfef68` | `0x141b7cc70` | `+0xd0` target EnvSpawnAlias, `+0xd8` state tag |
| R2 | SetEnvActive action | `0x145bff008` | `0x141b7d600` | `+0xd0` target, `+0xd8` ObjectState (1 Enable, 2 Disable) |
| R3 | ZoneEvent action | `0x145bfece8` | `0x141b7a3c0` | `+0xd0` ZoneEventTable row |
| R4 | linked env node | `0x145c0ee98` | `0x141b8ddd0` | `+0x200` tag (None for none), `+0x208` progress to add, `+0x20c` ObjectState (0 for none), `+0x210` index into the owner env's LinkEnvSpawnList |

R1 and R2 can name their target `self`, the env that owns the graph: owner node `+0xc0`, its graph `+0x130`, the
graph's object `+0x188`. R4 always goes through that owner env, whose LinkEnvSpawnList is at `+0x310` (count
`+0x318`). Only one class has the env's set-ObjectState function in its vtable, so a read checks for that vtable
(`0x145c4de70`) and reads the env's alias at `+0x1ec` instead of calling into the game. R4's run changes its target
only when `0x141d1e100` finds it live in the current zone, so the R4 read calls it too and pushes nothing for a target
in another zone. The worker finds the FName `self` once, with FName's find, before it swaps anything.

The worker swaps the R1, R2 and R4 slots once a run, when the gates first open (`shared_world` on, a friend linked, a
co-op save, no match lobby or SBO lobby session), on the pinned build only. Each swap is one aligned 8-byte
compare-and-swap from the game's run to our hook, as the spawn filter does, so a slot that holds another mod's value is
left as it is and logged. R3's slot is the one the SBO lobby hooks for the recruiter's Join (`game/sbo.h`'s
`kJoinSlot`): `join_slot_install()` swaps it once for whichever of the two features needs it first. The lobby's hook hands each ZoneEvent action to the shared world before its own Join test. `coop off` and the first fault swap our slots
back.

Each hook reads the node before it calls the game's run and pushes a fixed-size root into a ring of 64. The hook
allocates nothing and takes no lock, because the hooks and the pass that drains the ring both run on the game thread.
A hook pushes nothing when it runs on another thread (counted as `elsewhere=`), before the worker's swaps, after a
fault, or while our own pass applies the partner's lines. That last rule keeps a change we make for her from coming
back to her as ours. An R2 node with ObjectState 0 pushes nothing, since SB's run changes nothing then. A full ring
drops the new root and counts it.

## Filter

`tools/world_rows.py` reads the table exports of the pinned build and writes the generated block of `world/rows.h`:

```
python3 -I tools/world_rows.py <folder of <Table>.uasset.json exports>
```

It reads ZoneEnvSpawnTable, ZoneEnvTable, ZoneEventTable, EventEnvControlTable, QuestTable, QuestTaskGroupTable,
QuestTaskTable and AchievementTable, puts Matrix XIII's rows from `data/mxiii-world.json` into them first (each a copy
of its donor row with every field the file sets, as `lion/rows.h` adds them at run time, so the 114 game rows it
changes in place are judged on their new values). It writes four sorted lists:

- 6,423 (EnvSpawnAlias, tag) pairs over 2,554 of the 4,628 ZoneEnvSpawnTable rows (2,459 of the game's 4,430 and 95
  of the 198 Matrix XIII adds), for R1 and the state part of an `l` line;
- 2,409 EnvSpawnAliases for an ObjectState (R2 and an `l` line whose ObjectState is not 0);
- 2,058 ZoneEventTable rows for R3;
- 11 kept EnvSpawnAliases an `l` line may not add progress to.

A ZoneEnvSpawnTable row is out, with all its states, when it is per player (its EnvAlias family, such as
`Env_SupplyBox*`, `Env_RecordsObject`, `Env_Cabinet` or `Env_Alphacore`, the boss cores whose graphs give the item;
an EnvType Camp, Can or Nikke; an EnvCrate scan type; a box or record trophy on it), belongs to a camp, has a reward
group on any state, has no ZoneEnvTable row, or is story driven: the target of an EventEnvControlTable row that a
quest's events, task groups or tasks reach, through chained rows and the states those rows set. The rows.h header
gives the counts per reason; a row counts under each reason it meets: family 1,052, camp 870, type 774, reward 737,
trophy 572, crate 457, story 131, no env row 37. 15 rows pass these rules but lose every state to the state rules
below, so they are on no list.

A state of a kept row is out when it is the crane's `ResetCam` or `ChangeCam`, when the events its ChangeState runs
(followed through AddEvents, FinishEvents and every state an env control row among them sets) reach a type that acts on
the player, her items or her story (Theater, UIAction, GuideAction, CompleteHint, ActivateHint, Item, ItemAction,
AcquireQuest, InteractCamp, FinishBossChallenge, PlayerWarp, ChangeZone, StartMatchMaking, StopMatchMaking or
ReturnToSinglePlay), or when that state, or one an env control row among them sets, has a ChangeState achievement.
ChangeState credits such an achievement to its caster. The receiver's caster is her own player: without this rule
`Xion_22_EnvS_002` A would complete `Xion_Phase_2` in her game. 65 states are out for an achievement, 43 of them
directly. The same holds for a state that an EnvState quest task waits for (QuestTaskTable `CustomStr` and
`CustomStr2`): the task tests only the env and its state, so a line would complete it outside the shared quests' rules.
16 states are out for a quest task, ten of them for no other reason. Seven of those ten are states that one task in each of
nine shared quests waits for, such as `DED20_EnvS_210` On for `Quest_Epic_02_M01_T01`; the shared quests move those
tasks. The other three, `DED10_EnvS_197` On and `Xion_10_EnvS_042` B and Off, belong to collectible quests, which are
not shared: each player sets them in her own game. A row is on the ObjectState list only when every one of its states
is kept, so a forwarded Disable never locks a lever whose state change stayed local. A ZoneEvent row is kept when it and every row it chains to are env
control rows, none names a camp, each names a kept row, every tag it can set is a kept pair and each Disable is on an
env of the ObjectState list. A kept row goes on the no-progress list when one of its states counts progress and moves
at its count to a tag that is not a kept pair: `0x141fe39b0` adds to the current state's counter and at the count runs
ChangeState to that state's progress change tag. `WLA_30_EnvS_068` is one: On at 3 goes to A, which gives an item.

Rows that neither the tables nor `data/mxiii-world.json` hold, such as another mod's, are on no list. Another game
build needs the block written again from that build's tables.

The sender checks its lists before a root becomes a line. The receiver checks them again when the line arrives.
A3 checks the ZoneEvent list a third time right before it calls RunZoneEvent, since SB's RunEvent reaches its
matchmaking from some row types (see `tests/tools/matchmaking_scan_test.py` in [Tests](../tests.md#python-tests)).

## Wire

The lines go on Steam channel 2, reliable, after the tag `SBW21`:

| Line | Meaning |
| --- | --- |
| `SBW21 s <seq> <zone> <alias> <tag>` | an env put in a state (R1) |
| `SBW21 a <seq> <zone> <alias> <1\|2>` | an env enabled or disabled (R2) |
| `SBW21 e <seq> <zone> <row>` | a ZoneEventTable row run (R3) |
| `SBW21 l <seq> <zone> <alias> <tag> <objectState> <progress>` | a linked env: its state (`None` for none), ObjectState 0 to 2 and a progress to add (R4) |
| `SBW21 on`, `SBW21 off <reason>` | the sender's own state; the reason is `setting`, `match`, `save` or `fault` |
| `SBW21 on reply` | `on`, as the answer to her `on` |

Each line is at most `kMaxMessage` bytes. Zone, alias, tag and row are FName text: letters, digits and `_`, at most
64 bytes. `seq` starts at 1 after each `on` and goes up by one per line; the receiver counts an old one as bad and logs
a gap once. A player sends `on` or `off` each time her own state changes and again to a new partner. Each side also
answers her `on` with its own state, as `on reply` or its `off`. It never answers an `on reply`. A guest who loses the
host's lobby and rejoins before the host sees her leave starts again and sends `on`, while the host's partner never
changed; the answer gives her the host's `on` back. An `l` line is sent only when it changes something (a tag other
than `None`, an ObjectState other than 0 or a progress above 0). Each of those parts is checked on its own list.
Before a root becomes a line, the sender reads each FName's text, writes the line, parses it back and checks the
lists.

The worker hands our lines to `send_fight()`, which refuses a line while its channel 2 queue holds 256. A refused line
waits with the lines after it for the next pass, up to 1,024 (`world/sync.h`'s `Outbox`); a new partner, or none,
drops what waits, as the link drops its own queue then.

`link/core.h` refuses `SBW` lines in match lobbies both ways, as it does `SBQ` lines; one that arrives there is dropped. The log says `dropped fight data from <name>: the shared world is off in a match lobby`.

A last check stops echoes that the applying rule above would miss: the value she sent for an env or a row stops one
root of ours with the same value for that env or row within 3 s, for her last 32 values. Any other root of ours for
that env or row ends it.

## Applying her lines

The worker takes her `SBW` lines out of channel 2 before the shared fight sees them and hands them to the game thread
(up to 1,024 waiting there; past that they are dropped and counted as `inbox_dropped=`). The game thread queues them in
arrival order, up to 256; when the queue is full, the newest line is dropped and the log says so once per full spell.
A line is dropped on arrival (`gated=`) when our setting is off, no friend is linked, we are in a match lobby or the
SBO lobby, we do not play a co-op save, or her side is not on. It is refused (`refused=`) when the lists do not hold it.
When one of our own gates closes, or a new partner links, the queue is dropped. Her `off` does not drop it: she sent
those lines while she was on. A load (a map, the title, leaving Xion) reads `slot=none` or `slot=unknown` for a
while, because Lua's world flag is false without EVE; the co-op save gate keeps the last verdict through those
(`world::slot_coop()`), so neither side turns off and her lines wait in the queue until we are in game. A main save
ends it.

Each frame, `coop_tick` applies up to 8 queued lines when the game is ready for them: `lion_gate` open (net mode 0, no
logic task in flight), the client in game and playing (flow 2, phase `0xe`), the world's level manager present, not on
SB's logic thread (`0x1470683b0`) and our own player found. That player, the caster of every call, is read the way
SB's load restore reads it at `0x141fe2cdb`: the actor of client `+0x58` in the world's actor map (`0x141aae0d0` on
world `+0xc8`), then its `+0x10`'s vtable `+0x38`. Names are found with FName's find (`FNAME_Find`), which never adds a
name: a name her game has and ours lacks refuses the line.

- A1, a state on a live env (`0x141d1e100` on the world's level manager): the env must have the env vtable, not
  already be in that tag (`+0x1f4`), have that tag among its states (`+0x278`, count `+0x280`). That state must have no reward group or one already dropped. Then ChangeState `0x141fe3b70(env, tag, caster, L"", 0, 0, 0, 0)`, as
  R1's run calls it. A tag that does not read back afterwards refuses the line. ChangeState and the runs of R1 and R4
  never test ObjectState (`+0x28`) or ActiveState (`+0x21c`). SB's graphs change disabled envs (the lift of
  `SE_Area07_Lift_Lever` is Disable during its ride and goes to WaitBottom then), so A1 does not test them either.
- A1b, an ObjectState on a live env: the setter `0x141fe4f10` (env vtable `+0x78`) when the value differs, then
  `0x141fe33c0`, which copies the env into the records of its row's other zones, as R2's run does.
- A2, either one with no live env: the stored record of each zone of the spawn row (`0x141a9b420` for the row,
  `0x141d1df50`, `0x141d15a20` and `0x141d14620` then `0x141d12490` for a record that is missing), as R1's run does
  offline. The tag goes to record `+0x28` with its StateInfoList entry's flag set, the ObjectState to `+0x20`, whatever
  the record's ObjectState and ActiveState, as SB's offline branch writes it. The game replays the tag's events when
  she loads that zone.
- A3, a ZoneEventTable row: RunZoneEvent `0x141ca5790(world, caster, &row, 0)`, as R3's run calls it.
- A4, a linked env, live only (SB's node has no offline branch; a line for an env that is not live is refused as
  `away`), in the order R4's run uses: A1 with its guards when the tag is not `None`, skipped when the env is already
  in that tag; then the ObjectState through vtable `+0x78` when not 0; then `0x141fe39b0(env, progress, caster, 0)`
  when the progress is above 0 (0 adds); then `0x141fe33c0`. An A1 guard that refuses (the lists missed something)
  stops the whole line. A tag that does not read back does not stop the parts after it, as SB's node runs them anyway. The line then counts as refused (`game`).

A line the game refuses is not tried again. Each refusal is logged once per env or row in `coop-link.log`, for up to
256 of them; after that one line says the rest are only counted.

## Status line

`coop-status.txt` holds one `world=` line, which `coop world status` prints:

```
world=<on|off|waiting why=<friend|match|save|partner>> sent= skipped= denied= echoes= invalid= full= received=
applied= refused= gated= queued= overflow= bad= gaps= hooks= inbox_dropped= unsent= elsewhere=
```

It reads `world=off why=build` on another game build, `world=off why=coop_off` after `coop off` and `world=stopped`
after a fault.

| Field | Counts |
| --- | --- |
| `sent` | our roots sent |
| `skipped` | our roots while the feature was off on either side |
| `denied` | our roots that no list holds |
| `echoes` | our roots stopped because they repeat a value of hers |
| `invalid` | our roots with a name that has no text, or a value no line carries |
| `full` | our roots dropped by a full ring |
| `received` | her `s`, `a`, `e` and `l` lines |
| `applied` | her lines our game made |
| `refused` | her lines the lists or the game refused |
| `gated` | her lines while the feature was off on either side, or in a match lobby |
| `queued` | her lines that wait now |
| `overflow` | her lines dropped by a full queue |
| `bad` | malformed lines and lines with an old `seq` |
| `gaps` | `seq` numbers skipped |
| `hooks` | the slots of ours in place, out of 4 |
| `inbox_dropped` | her lines dropped before the game thread took them |
| `unsent` | our lines dropped unsent: past 1,024 waiting for the link, or at a new partner |
| `elsewhere` | hook calls on a thread other than the game thread |

The line changes with its counters. Each change goes to `UE4SS.log` as a `[StellarCoop] link:` line.

## Lua side

`shared_world` is a switch in `core/link.lua`'s settings, on by default. Once a load, as soon as the native part has
judged the save slot, `main.lua` sends the request `world on` when the setting is on; the native part starts off. The
Options row sends `world on` at once, or `world off` each time it turns off (the `world=` line lags a `world on` by a
worker pass and a frame, so it is not read there). `shared_world=off` at a reload sends `world off` when an
earlier load turned it on. `coop world on|off` sends the request itself and leaves the setting alone. The notices
come from the `world=` line: on with her each time it reads `on` after anything else and stopped when it changes to `stopped`.

## Limits

- Nothing here has run in game.
- After a live ChangeState, R1's run has a second pass over the envs of type 5 when an object of the tables has
  `+0x182 == 5`. The receiver does not make that pass: what type 5 covers there was not mapped.
- The guards are the mod's own beyond SB's: A1 refuses a tag the env already has (SB would run it again, with its
  events) and a state with a reward still to drop. A refused line is never retried.
- An R4 change reaches her game only while its target is live there. A linked env of a zone she is not in is refused
  as `away` and is not written into her records. Nothing catches it up when she loads that zone.
- The story walk does not follow a quest NPC's spawn into EventSpawnTable's EventOnDead or EventOnBattle, nor the
  events a theater or level sequence asset fires itself.
- The tables do not show which of the 2,058 kept ZoneEvent rows a graph's ZoneEvent action runs.
- A graph that runs one of these nodes off the game thread is not shared; `elsewhere=` counts those calls.
- Not in this phase: condition triggers, the puzzles played on a UI screen, progress snapping, moved objects (their
  transform), catching up two worlds that changed apart and putting the partner onto a moving lift.

## Addresses

| What | Address | Use |
| --- | --- | --- |
| ChangeEnvState action slot and run | `0x145bfef68`, `0x141b7cc70` | R1 hook |
| SetEnvActive action slot and run | `0x145bff008`, `0x141b7d600` | R2 hook |
| ZoneEvent action slot and run | `0x145bfece8`, `0x141b7a3c0` | R3, through the SBO lobby's hook |
| Linked env node slot and run | `0x145c0ee98`, `0x141b8ddd0` | R4 hook |
| Env vtable | `0x145c4de70` | which object is an env |
| FString `self` | `0x146f44a70` | the target name R1 and R2 compare |
| Live env by alias | `0x141d1e100` | A1, A1b, A4, the R4 read |
| ChangeState | `0x141fe3b70` | A1, A4 |
| Set ObjectState (env vtable `+0x78`) | `0x141fe4f10` | A1b, A4 |
| Copy env into the other zones' records | `0x141fe33c0` | A1b, A4 |
| Add progress | `0x141fe39b0` | A4 |
| RunZoneEvent | `0x141ca5790` | A3 (`game/sbo.h`) |
| Spawn row by alias | `0x141a9b420` | A2 |
| Zone records, find record, new record, init record | `0x141d1df50`, `0x141d15a20`, `0x141d14620`, `0x141d12490` | A2 |
| Find actor by ID | `0x141aae0d0` | the caster |
| FName make (find only) | `0x14293dde0` | names from text |
| FName pool, None's index | `0x147003ac0`, `0x147017b00` | text of a name, None refused |
| Empty text `L""` | `0x14592a858` | ChangeState's text argument |
| World, client, tables globals | `0x1470373d0`, `0x1470373f8`, `0x1470373b0` | read only; their getters allocate |
| SB's logic thread ID | `0x1470683b0` | no apply on that thread |
| Load restore's caster read | `0x141fe2cdb` | the model for our caster read |
