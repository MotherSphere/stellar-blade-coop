# Shared world: how it works

The player's side is in [Shared world](objects.md). The shared world (`shared_world`, experimental, on by
default) has not run in game yet. Every address and offset below is build 26123051's, read in Ghidra.

The code is split as for the shared quests:

- `native/src/game/objects/rows.h`: the six lists of what may be shared, written by `tools/world_rows.py`;
- `native/src/game/objects/sync.h`: the lines, the ring, both players' sides, the watcher, the catch-up and the status
  line, with no Windows types and no game call;
- `native/src/game/objects/engine.h`: the root reads, the env and zone reads and the game calls, through a `Game` that
  is SB's memory on Windows and fake memory in the tests;
- `native/src/world/objects/world_game.inc`: the hooks and each frame's pass on the game thread, with its state, latch
  and game calls that other modules' parts read in `native/src/glue/tick/world_game_shared.inc`;
- `native/src/world/objects/world_worker.inc`: Lua's request, the slot swaps, channel 2 and the status line on the
  worker;
- `mod/StellarCoop/Scripts/world/objects/commands.lua` and `world/objects/wiring.lua`: the setting, `coop world` and the
  notices.

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

`tools/world_rows.py` reads the table exports of the pinned build and writes the generated block of
`game/objects/rows.h`:

```
python3 -I tools/world_rows.py <folder of <Table>.uasset.json exports>
```

It reads ZoneEnvSpawnTable, ZoneEnvTable, ZoneEventTable, EventEnvControlTable, QuestTable, QuestTaskGroupTable,
QuestTaskTable and AchievementTable, puts Matrix XIII's rows from `data/mxiii-world.json` into them first (each a copy
of its donor row with every field the file sets, as `rows/rows.h` adds them at run time, so the 114 game rows it
changes in place are judged on their new values). It writes six sorted lists:

- 6,463 (EnvSpawnAlias, tag) pairs over 2,554 of the 4,628 ZoneEnvSpawnTable rows (2,459 of the game's 4,430 and 95
  of the 198 Matrix XIII adds), for R1, the state part of an `l` line and a `c` line;
- 2,447 EnvSpawnAliases for an ObjectState (R2, an `l` line whose ObjectState is not 0 and the ObjectState of a `c`
  line);
- 2,091 ZoneEventTable rows for R3;
- 9 kept EnvSpawnAliases an `l` line may not add progress to;
- 1 watched pair (`kWatch`), the AltesLab trap floor's end;
- 1,838 zone entries (`kZoneEnvs`) of 1,696 EnvSpawnAliases over 96 zones, the saved envs two worlds compare.

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
the player, her items or her story (Theater, UIAction, GuideAction, ActivateHint, Item, ItemAction, AcquireQuest,
InteractCamp, FinishBossChallenge, PlayerWarp, ChangeZone, StartMatchMaking, StopMatchMaking or ReturnToSinglePlay), or
when that state, or one an env control row among them sets, has a ChangeState achievement. ChangeState credits such an
achievement to its caster. The receiver's caster is her own player: without this rule `Xion_22_EnvS_002` A would
complete `Xion_Phase_2` in her game. 37 states are out for an achievement, 30 of them directly. The same holds for a
state that an EnvState quest task waits for (QuestTaskTable `CustomStr` and `CustomStr2`): the task tests only the env
and its state, so a line would complete it outside the shared quests' rules. 16 states are out for a quest task, ten of
them for no other reason. Seven of those ten are states that one task in each of nine shared quests waits for, such as
`DED20_EnvS_210` On for `Quest_Epic_02_M01_T01`; the shared quests move those tasks. The other three, `DED10_EnvS_197`
On and `Xion_10_EnvS_042` B and Off, belong to collectible quests, which are not shared: each player sets them in her
own game.

An achievement that only marks a map's progress holds no state out: its name matches `_ChangeStateZoneEnv_` or
`^ChangeState_ZoneEnv_.*_Guide$` and its `ProgressAchievementOnCompleted`, `ProgressAchievementOnCompleted2` and
`ProgressAchievementArrayOnCompleted` name no other achievement. The receiver's ChangeState credits it to her own
player, so she gets the same hidden progress entry when the env is live in her game. A hint completion (CompleteHint)
holds none out either: once a door is shared, a hint left open would point at a door she can no longer open, so the hint
closes in both games. These two rules let 40 more states travel. 16 were held out only by a map-progress achievement,
among them the crane's `DED20_E_EnvC_001` CallPuzzle and the train call `DED20_E_EnvC_002` CallTrain. 24 were held out
by a hint completion (9 of them by a map-progress achievement too), among them the ME_04 pipe puzzle's water gate
`ME_04_EnvS_099` On and the trap floor's end `ATL_01_EnvS_074` On. Before these two rules the lists held 6,423 pairs,
2,409 ObjectState aliases, 2,058 ZoneEvent rows and 11 no-progress aliases.

A row is on the ObjectState list only when every one of its states is kept, so a forwarded Disable never locks a lever
whose state change stayed local. A ZoneEvent row is kept when it and every row it chains to are env control rows, none
names a camp, each names a kept row, every tag it can set is a kept pair and each Disable is on an env of the
ObjectState list. A kept row goes on the no-progress list when one of its states counts progress and moves at its count
to a tag that is not a kept pair: `0x141fe39b0` adds to the current state's counter and at the count runs ChangeState to
that state's progress change tag. `WLA_30_EnvS_068` is one: On at 3 goes to A, which gives an item.

The watched pairs (`kWatch`) are kept pairs that a condition trigger sets, for which no root goes out. For each
ZoneEnvSpawnTable row whose ZoneEnvTable row has EnvType Trigger, the tool follows its TriggerTrueEvents (the env row's
when the spawn row's list is empty, as the trigger tick falls back) through AddEvents and FinishEvents, with no state
cascade, to each env control row's target and `TagName`. That pair goes on the list when it is kept and its target has
SaveType Save. Build 26123051 gives one pair, `ATL_01_EnvS_074` On, which `ATL_01_E_EnvC_051` sets at the end of the
AltesLab trap floor. The floor's steps (`ATL_01_EnvS_019` Success1 to Success4) are on a ResetZone row, so they stay
out. An empty list, for another build, is written as `{"", ""}`, as the no-progress list is.

Each zone's saved envs (`kZoneEnvs`) are one entry per zone of a row's ZoneList for each kept row with SaveType Save
whose InitStateTag is one of its states (case ignored). An entry holds the zone, the alias, the InitStateTag as the
table spells it and the InitActivate (1 Enable, 2 Disable, 0 None). There are 1,838 entries of 1,696 aliases over 96
zones. The largest zones are `Zone_DLC02_20` with 83 entries, `Zone_WLB_20` with 81, `Zone_DED20` and `Zone_Xion_10`
with 76. The pseudo-zone `None` is left out. 30 spawn rows list it in their ZoneList, always beside real zones; 18 of
them give entries here. `0x141d1df50` and `0x141d15a20` both answer 0 for None, so no record lives under it. Of the
1,773 kept Save rows, 52 have InitStateTag None and 25 a tag none of their states holds (`CGH_data_EnvS_032` Close,
whose states are `off` and `on`): they are left out. ResetZone and None rows keep nothing across a rest.
SaveWithTransform rows would need their transform too. An empty `kZoneEnvs` stops the tool.

Rows that neither the tables nor `data/mxiii-world.json` hold, such as another mod's, are on no list. Another game
build needs the block written again from that build's tables.

The sender checks its lists before a root becomes a line. The receiver checks them again when the line arrives.
A3 checks the ZoneEvent list a third time right before it calls RunZoneEvent, since SB's RunEvent reaches its
matchmaking from some row types (see `tests/tools/matchmaking_scan_test.py` in [Tests](../dev/tests.md#python-tests)).

## Wire

The lines go on Steam channel 2, reliable, after the tag `SBW29`:

| Line | Meaning |
| --- | --- |
| `SBW29 s <seq> <zone> <alias> <tag>` | an env put in a state (R1) |
| `SBW29 a <seq> <zone> <alias> <1\|2>` | an env enabled or disabled (R2) |
| `SBW29 e <seq> <zone> <row>` | a ZoneEventTable row run (R3) |
| `SBW29 l <seq> <zone> <alias> <tag> <objectState> <progress>` | a linked env: its state (`None` for none), ObjectState 0 to 2 and a progress to add (R4) |
| `SBW29 on`, `SBW29 off <reason>` | the sender's own state; the reason is `setting`, `match`, `save` or `fault` |
| `SBW29 on reply` | `on`, as the answer to her `on` |
| `SBW29 c ask <zone>` | send me what you changed in this zone (no `seq`) |
| `SBW29 c <seq> <zone> <alias> <tag> <objectState>` | one changed env of that zone: its state and ObjectState 0 to 2 (0: not carried) |
| `SBW29 c end <zone> <count>` | the answer is complete, `count` `c` lines sent (no `seq`) |

Each line is at most `kMaxMessage` bytes. Zone, alias, tag and row are FName text: letters, digits and `_`, at most 64
bytes. `seq` starts at 1 after each `on` and goes up by one per line, `c` lines included; the receiver counts an old one
as bad and logs a gap once. A player sends `on` or `off` each time her own state changes and again to a new partner.
Each side also answers her `on` with its own state, as `on reply` or its `off`. It never answers an `on reply`. A guest
who loses the host's lobby and rejoins before the host sees her leave starts again and sends `on`, while the host's
partner never changed; the answer gives her the host's `on` back. An `l` line is sent only when it changes something (a
tag other than `None`, an ObjectState other than 0 or a progress above 0). Each of those parts is checked on its own
list. A `c` line is refused when its zone and alias are not an entry of `kZoneEnvs` or its alias and tag are not a kept
pair; its ObjectState counts only for an alias on the ObjectState list. Before a root becomes a line, the sender reads
each FName's text, writes the line, parses it back and checks the lists.

The worker hands our lines to `send_fight()` for the pair only (`Link::partner()`, the host and the guest in ghost slot
0 in an online session of more than 2 players), which refuses a line while its channel 2 queue holds 256. A refused line
waits with the lines after it for the next pass, up to 1,024 (`game/objects/sync.h`'s `Outbox`); a new partner, or none,
drops what waits, as the link drops its own queue then.

`link/core.h` (in `link/core/channels.inc`) refuses `SBW` lines in match lobbies both ways, as it does `SBQ` lines; one
that arrives there is dropped. The log says `dropped fight data from <name>: the shared world is off in a match lobby`.

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

Before an `s` line goes to the game, `Sync` reads our value of that env when `kZoneEnvs` has an entry for it in the
line's zone. When ours is touched into a state that is not a kept pair (a passcode door typed open), the line is not
applied and counts in `kept`. The catch-up keeps such a state by the same check (`held()`, see
[Her answer](#her-answer)).

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

## The trap floor's end

The AltesLab trap floor (`Zone_ATL_01`) ends when the condition trigger `ATL_01_EnvS_074` runs its TriggerTrueEvents:
the env control row `ATL_01_E_EnvC_051` puts 074 in On. The events of that On put `ATL_01_EnvS_134` and
`ATL_01_EnvS_146` in On and close the hint `ATL_Scaffolding` (`ATL_01_ZoneE_114`). The trigger tick (`0x141fdcc40`)
runs the control row through RunZoneEvent, not through a graph node, so no root marks the end.

A watcher sends it instead. Each pass while the feature is open and we are in game, `Sync::pass` reads each `kWatch`
entry with `read()` in the client's current zone, once before her lines and once after them. Only a live read counts.
A record or no env skips that entry for the pass and keeps its stored tag: the env may still be streaming in, since the
end scene `ATL_01_E_Theater_014` and the camp `ATL_01_E_InteractCamp_004` follow the end in 074's TriggerTrueEvents.
The first live sight in a zone stores the tag and sends nothing. A later live read that turns to the watched tag (case
ignored) goes out as an ordinary `s` line, through the same checks as a root: parsed back, on the lists, not her value
come back, the next `seq`. The read after her lines only stores, so a change one of her lines made is never sent back.
The stored tags are cleared when the client's zone changes or reads as none, when the feature closes and at a new
partner.

The receiver applies that `s` line as any other: A1 when 074 is live (ChangeState with her caster runs the events of
074's On), else A2 into her records, whose events run when she loads `Zone_ATL_01`. Each player still walks their own
floor. The steps (`ATL_01_EnvS_019`, a ResetZone row), the falls, the end scene and the camp stay with the player who
walked it.

A watcher, not a hook on the trigger tick: a tick hook would see the end only if RunZoneEvent applies the control row
before it returns, which was not traced. The watcher needs no slot swap and no game call beyond the reads below.

## Catching up by zone

Each side asks the other for the saved envs of the zone it stands in, then takes what the other changed there.

### The ask

While the feature is open and we are in game, each pass reads the client's current zone with `zone()`: the FName at
client `+0x68`, refused when there is no client, when it is None or when it has no text. A zone that held `kAskHoldMs`
(2 s) of open in-game passes goes out once as `SBW29 c ask <zone>`, counted in `asked=`. The hold lets the zone's envs
stream in after a zone change or a load. The opening (both sides ready, her `on` heard), a new partner and her `on`
(not her `on reply`: a rejoin we did not see may hide changes made apart) let the current zone be asked again. So does
a load, read as more than 2 s without an open in-game pass (a map, the title). The load dropped what was applied since
that save, so the zone is asked again after the hold even when it is the zone asked last. A partner that never answers
(an older protocol-23 build counts the `c` lines as bad) costs one ask per zone entry and per load, nothing more.

### The walk

Her asks wait in line, each zone once. An ask for a zone with no `kZoneEnvs` entry is answered with `c end <zone> 0`
at once. The log then says `world: the partner asked for <zone>, which has no env on the catch-up list, said once`,
once a run. One walk runs at a time, in game only. It reads at most `kWalkReads` (128) entries a pass and goes on
where it stopped in the next pass, after a load too.

`read(zone, alias)` takes the live env when `0x141d1e100` finds one with the env vtable: its tag at `+0x1f4`, its
ObjectState at `+0x28` (what env vtable `+0x60`, `0x1415dc420`, returns). Else it takes the zone's stored record
(`0x141d1df50`, then `0x141d15a20`): its tag at `+0x28`, its ObjectState at `+0x20`, which `0x141d11750` copies from
those two env fields. Else it reads nothing. An ObjectState other than 1 or 2 reads 0; a tag with no text reads as
nothing. An entry is touched when its tag differs from the InitStateTag (case ignored) or, for an alias on the
ObjectState list, when its ObjectState differs from the InitActivate. An env that no Enable or Disable changed reads its
InitActivate: the env's spawn (`0x141fdeaa0`, call at `0x141fe1aef`) passes the spawn row's InitActivate byte (`+0x60`)
to env vtable `+0x78`, which stores it at `+0x28`. So the one entry with InitActivate None (`ME_05_EnvS_064`) reads 0
untouched.

Each touched entry whose state is a kept pair goes out as a `c` line with the next `seq` (ObjectState 0 for an alias off
the ObjectState list), then `c end <zone> <count>`. The largest zone, `Zone_DLC02_20` with 83 entries, fits in one pass
and in the 256-line queue.

### Her answer

Her `c` line meets our value of that env: live, else its record, else the entry's initial value.

| Our value | Done | Counted |
| --- | --- | --- |
| the same as hers (tag case ignored; the ObjectState only for an alias on the ObjectState list) | nothing | `same` |
| changed by a root of ours sent after the question her line answers (our ask for the zone, or her ask, which her send-back follows) | ours kept, host or guest; nothing applied or sent back | `kept` |
| touched into a state that is not a kept pair (held out for its player: a passcode door typed open, a quest state, the WLB_20 supply chain's `On`) | ours kept, host or guest; nothing applied or sent back | `kept` |
| untouched, or we are a guest | hers applied: the state as an `s` line when the tags differ (A1 live, A2 offline), then the Enable or Disable as an `a` line when it differs | `caught` |
| touched, we are the host | ours kept | `kept` |

When the host keeps its value under the last row for a zone it asked and still waits for, it sends its own value back
as a `c` line. After her `c end` it closes those lines with its own `c end <zone> <n>`. The guest takes them under the
fourth row, so the host's value ends in both worlds, even for a guest who asked that zone long before. Only a zone the
host asked gets lines sent back, so two sides that both think they host cannot ping-pong.

Her `c` line can be older than a root of ours. Her walk reads the env after she takes our ask. Her send-back reads it
when she takes our `c` line. A root of ours sent after that ask or that `c` line may not have reached her yet. Each
side marks, in send order, its last root line per env (`s`, `a`, `l` and the watcher's `s`), its asks until her
`c end` and her asks until its own next ask for that zone. Her `c` line for an env whose root mark is later than our
ask for the zone, or than her ask for it, goes under the second row: our root's own line brings our value to her. A
root sent before the question reached her before her read, since she takes our lines in order.

`c` lines leave the queue with her live lines in arrival order, 8 a pass in all (`kApplyPerPass`). They go through
phase 1's apply with its guards. A `c` line whose state part is refused skips its ObjectState part. The echo backstop
remembers a `c` line that applied both parts as its state part, the one a graph could send back. `c` lines count in
`received=` (they carry a `seq`) and in `caught=`, `kept=`, `same=` or `refused=`, never in `applied=`. Walk and
send-back lines do not count in `sent=`.

Her `c end` writes one log line:

```
world: catch-up for <zone> from the partner: <count> sent, <n> applied (<n> live), <n> kept ours, <n> same, <n> refused
```

`live` counts the applied lines whose env our read found live; the rest went to records. An applied count above its
live count means envs were not live yet 2 s after the zone change: the figure that tunes the hold. The tallies are
kept per zone, logged and dropped at that zone's `c end`. A tally exists only for a zone with entries on `kZoneEnvs`,
so junk zone names in refused lines cannot grow the map. When both sides ask one zone at once (at the link), the
host's send-back lines and its walk answer that zone together, so the guest's first log line for it can count lines of
both answers.

A close (a match lobby, her `off`, our setting off) or a new partner drops her asks, the walk, the tallies, the zones
we wait for and the catch-up lines still queued, so no half answer lands later. The current zone is asked again once
it holds.

### Bounds

- Every read runs on the game thread inside `world_sync.pass()`, under `world_guarded`'s SEH latch, only while
  `world_in_game()` holds.
- Reads call `live_env`, `zone_records`, `find_record`, `text` and `find` only, never `new_record`
  (`0x141d14620` stays A2's), so a read makes no record. Names are found with FName's find, never made. Every pointer
  passes `game::plausible`. A live env counts only with the env vtable `0x145c4de70`.
- Per pass: the watcher reads `kWatch` (1 entry), the walk at most 128 entries, at most 8 lines are applied (live and
  catch-up together), the queue holds 256.
- No call in this phase to the trigger tick `0x141fdcc40`, the condition check `0x141c8bda0`, the safe-location
  Execute `0x141b305d0`, the env reset `0x141fe2f80`, the achievement queue `0x141b01440` or ProcessEvent.

### More than two players

The world runs between the host and the first guest today. The catch-up is host centred, one `Sync` per partner: a guest
asks the host; the host asks each guest. A guest's change enters the host's world where the host's own value is
untouched. It reaches a later guest through that guest's own ask. `kWalkReads` is per `Sync`, so a glue that runs one
`Sync` per seat has to split it: each pass, each open `Sync`'s `walk_reads` is `max(1, 128 / <open Syncs>)`. Without
that, 7 guests asking at once after a group travel would cost 7 x 128 reads in one frame.

## Status line

`coop-status.txt` holds one `world=` line, which `coop world status` prints:

```
world=<on|off|waiting why=<friend|match|save|partner>> sent= skipped= denied= echoes= invalid= full= received=
applied= refused= gated= queued= overflow= bad= gaps= asked= caught= kept= same= hooks= inbox_dropped= unsent=
elsewhere=
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
| `received` | her `s`, `a`, `e`, `l` and `c` lines |
| `applied` | her `s`, `a`, `e` and `l` lines our game made |
| `refused` | her lines the lists or the game refused, `c` lines included |
| `gated` | her lines while the feature was off on either side, or in a match lobby |
| `queued` | her lines that wait now |
| `overflow` | her lines dropped by a full queue |
| `bad` | malformed lines and lines with an old `seq` |
| `gaps` | `seq` numbers skipped |
| `asked` | our `c ask` lines |
| `caught` | her `c` lines our game made |
| `kept` | her `c` lines where ours stayed (a newer root of ours, a state held out for us, or the host's touched value) and her `s` lines where ours stayed in a state held out for us |
| `same` | her `c` lines equal to our value |
| `hooks` | the slots of ours in place, out of 4 |
| `inbox_dropped` | her lines dropped before the game thread took them |
| `unsent` | our lines dropped unsent: past 1,024 waiting for the link, or at a new partner |
| `elsewhere` | hook calls on a thread other than the game thread |

The line changes with its counters. Each change goes to `UE4SS.log` as a `[StellarCoop] link:` line.

## Lua side

`shared_world` is a switch in `core/link.lua`'s settings, on by default. Once a load, as soon as the native part has
judged the save slot, `world/objects/wiring.lua` sends the request `world on` when the setting is on; the native part
starts off. The Options row sends `world on` at once, or `world off` each time it turns off (the `world=` line lags a
`world on` by a worker pass and a frame, so it is not read there). `shared_world=off` at a reload sends `world off` when
an earlier load turned it on. `coop world on|off` sends the request itself and leaves the setting alone. The notices
come from the `world=` line: on with her each time it reads `on` after anything else and stopped when it changes to
`stopped`.

## Limits

- Nothing here has run in game.
- After a live ChangeState, R1's run has a second pass over the envs of type 5 when an object of the tables has
  `+0x182 == 5`. The receiver does not make that pass: what type 5 covers there was not mapped.
- The guards are the mod's own beyond SB's: A1 refuses a tag the env already has (SB would run it again, with its
  events) and a state with a reward still to drop. A refused line is never retried.
- An R4 change reaches her game only while its target is live there. A linked env of a zone she is not in is refused
  as `away` and is not written into her records. For a saved object (an entry of `kZoneEnvs`), the catch-up brings
  that change in when she enters the zone. Any other such change stays apart.
- Only her `s` line meets the check for a state held out for us. The state part of her `l` line goes to A1 without
  it. The check needs an entry of `kZoneEnvs` for the env in the line's zone: an env the game does not save has no
  initial tag on the lists, so her `s` line can still move it out of a state held out for us. The line's zone is her
  client's current zone (client `+0x68`) when she worked the env, not the env's own zone. When the two differ, no entry
  is found and the line goes to A1 without the check. Each of the 10 passcode doors that
  `tests/native/game/objects/rows_test.cpp` lists has one entry, in its own zone, so this is the case that reaches them.
- The check of her `c` line against a newer root of ours looks only at the env that root names. An env its events
  change in turn (the door a lever opens) carries no mark, so her older `c` line for that door is still taken.
- 212 kept pairs of 106 aliases are spelled `off` and `on` in lowercase, 15 of those aliases on `kZoneEnvs` (`WLB_60`
  7, `WLA_10` 2, `WLB_30` 1, test maps 5). The kept-pair checks are exact. If the game's FName text for them reads
  `Off` and `On`, the roots and the catch-up both skip them. Not measured.
- The story walk does not follow a quest NPC's spawn into EventSpawnTable's EventOnDead or EventOnBattle, nor the
  events a theater or level sequence asset fires itself.
- The tables do not show which of the 2,091 kept ZoneEvent rows a graph's ZoneEvent action runs.
- A graph that runs one of these nodes off the game thread is not shared; `elsewhere=` counts those calls.
- The 2 s hold before an ask is a guess: envs of a zone stream in after the zone changes. The log line's live count
  shows whether it is long enough.
- Not in this phase:
  - one shared trap floor: each player walks their own floor, only its end is shared;
  - the 10 passcode doors, kept per player with their album entry;
  - story flags (Xion's phases, `ElderOrcal_Dead`, quest, ending and shop flags), which belong to story together;
  - the WLB_20 supply box chain (loot) and two states on test maps (`LV_Test_LastLegacy_01_EnvS_001` Up,
    `LV_Test_Map_EnvS_078` B), each held by a `Temp_` achievement;
  - the FA_02 colour triggers: their TriggerTrueEvents ask `FA_02_EnvS_035` for tags its row lacks (`Red`, `Yellow`,
    `Bule`, `Turauoise`);
  - achievement credit for a change applied while she is away: A2 writes her record only;
  - ActiveState, progress counters, trigger counts, ResetZone and None rows, moved objects (their transform) and the
    77 Save rows whose InitStateTag is None or none of their states;
  - graph-only puzzle actions (PlayTheater, PlayLevelSeq, PropertyAcquireItem), which no root carries;
  - putting the partner onto a moving lift.

## Addresses

| What | Address | Use |
| --- | --- | --- |
| ChangeEnvState action slot and run | `0x145bfef68`, `0x141b7cc70` | R1 hook |
| SetEnvActive action slot and run | `0x145bff008`, `0x141b7d600` | R2 hook |
| ZoneEvent action slot and run | `0x145bfece8`, `0x141b7a3c0` | R3, through the SBO lobby's hook |
| Linked env node slot and run | `0x145c0ee98`, `0x141b8ddd0` | R4 hook |
| Env vtable | `0x145c4de70` | which object is an env |
| FString `self` | `0x146f44a70` | the target name R1 and R2 compare |
| Live env by alias | `0x141d1e100` | A1, A1b, A4, the R4 read, the watcher and catch-up reads |
| ChangeState | `0x141fe3b70` | A1, A4 |
| Set ObjectState (env vtable `+0x78`) | `0x141fe4f10` | A1b, A4; stores the value at env `+0x28` |
| Get ObjectState (env vtable `+0x60`) | `0x1415dc420` | returns env `+0x28`, the ObjectState a live read takes |
| Env spawn, its InitActivate call | `0x141fdeaa0`, `0x141fe1aef` | passes the spawn row's byte `+0x60` (InitActivate) to env vtable `+0x78`: an untouched env reads its InitActivate |
| Copy env into its record | `0x141d11750` | writes record `+0x20` from env vtable `+0x60` and record `+0x28` from env `+0x1f4`: where a record read finds them |
| Copy env into the other zones' records | `0x141fe33c0` | A1b, A4 |
| Add progress | `0x141fe39b0` | A4 |
| RunZoneEvent | `0x141ca5790` | A3 (`game/sbo.h`) |
| Spawn row by alias | `0x141a9b420` | A2 |
| Zone records, find record, new record, init record | `0x141d1df50`, `0x141d15a20`, `0x141d14620`, `0x141d12490` | A2; the first two also for the catch-up reads, both answer 0 for None (no record under None) |
| Find actor by ID | `0x141aae0d0` | the caster |
| FName make (find only) | `0x14293dde0` | names from text |
| FName pool, None's index | `0x147003ac0`, `0x147017b00` | text of a name, None refused |
| Empty text `L""` | `0x14592a858` | ChangeState's text argument |
| World, client, tables globals | `0x1470373d0`, `0x1470373f8`, `0x1470373b0` | read only; their getters allocate |
| Client's current zone | client `+0x68` (read at `0x141cf763a` in `0x141cf7630`) | the zone the asks name |
| SB's logic thread ID | `0x1470683b0` | no apply on that thread |
| Load restore's caster read | `0x141fe2cdb` | the model for our caster read |
