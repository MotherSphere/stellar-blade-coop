# Shared enemies: how they work

The player's side, with the settings of each part, is in [Shared enemies](../shared-enemies.md). The rule for kills and
achievements is in [Achievements and safety](safety.md#achievements).

## Same-place enemies

Same place (`same_place`, experimental, the host's value, on by default, not tested in game yet) builds on shared
enemies: the same pairs, the same host and the same Steam channel 2. Each pair has an owner, the game whose copy runs
the enemy's AI and moves it; the other game draws its copy (stages 3a and 3b of Phase 11). The host decides the owner.
HP, Shield, balance and death stay with the host's game whoever owns the pair.

- The host's `same_place` decides for both games. The host sends it as `SBF19 place <gen> <0|1>` after its world line
  (and its scale line) while it is on, and again at each change, `coop fight pilot off` and an error included. The
  guest draws her copies only while the host's last place line says 1, and forgets it with the host's next world, on or
  off line. Her own value is not read at a start: her co-op menu row only stops same place on her side, or starts it
  again, while shared enemies wait or run (`coop fight pilot off` and `on`).
- Every pair starts as the host's. With `aggro=game` (the host's setting, the default) the host's job runs a rule on
  each pair every turn: the pair goes to whoever hit it last (a hit on the host's copy, or a claim of hers that lowered
  a stat), and after 10 s without a hit to the other player once that player's EVE has stood at least 3 m nearer, and
  within 30 m of it, for 2 s (the force target that follows makes that EVE the enemy's last player, which counts as
  taking part in its fight: [Achievements](safety.md#achievements)). Nothing changes hands within 4 s of the last change, while
  an AI task runs on the owner's copy, during Down, Groggy, Airborne or a takedown, while the enemy dies, or while the
  host draws a copy that the game froze before the mod did (below: its AI would not run once the host owns it); the
  start of a takedown is the exception (below). Each change moves the owner epoch one up and goes to her as
  `SBF19 own <gen> <hguid> <H|G> <oe>`; the host freezes its copy as it sends own G and thaws it as it sends own H. With
  `aggro=host` the host keeps every pair (stage 3a). The host sends `SBF19 aggro <gen> <game|host>`.
- The guest takes an own G only at her epoch plus one, for a paired copy in life state 1 while same place runs on her
  side, and thaws her copy in that turn. She refuses a copy that the game froze before the mod did (why `state`),
  except for her takedown. Otherwise, and when she can no longer run a pair she owns, she answers
  `SBF19 own-no <gen> <hguid> <oe> <why>`, where why is `unpaired`, `state`, `off`, `epoch`, `aggro`, `full` or
  `target`, and the pair is the host's again. After `off` or `aggro` the host hands her nothing for 30 s, and after any
  other reason not that pair. A world line, an on or an off line starts the epochs over on both sides and ends both
  pauses.
- In the frame a hand-over makes a pair a game's own at a new epoch, its game thread first puts the copy back
  (below), then calls the game's force target function (`FUN_141a36010`) toward its own EVE: detect result 3, aggro
  level 1, and the game's own TargetedByEnemy jobs. The call runs only with the cached net mode 0 (in net mode 3 that
  function would send server requests), no logic task in flight, the two game objects it fetches already made (their
  getters would make them), the copy found by its GUID, its own EVE found and an AI owner on the copy. A task in
  flight or a copy not found puts it off for up to 250 ms. A refused take-over goes back to the job, and the guest
  gives the pair back with `own-no target`. A pair that comes back to the host after an own-no or
  place 0 gets no call: the host's copy keeps the target it had.
- Every 33 ms the owner's game thread reads each enemy it owns: position, rotation, animation speed, BattleMode,
  whether it is dying and whether an AI task runs, into one `SBE` message on channel 1 (26 bytes an enemy, 16 enemies
  at most), stamped with the pose clock. It also walks the game's Show manager (the game's animation sequences) for the
  Shows each enemy starts, and sends `show`, `show-set` and `show-stop` lines on channel 2 with the asset's path and
  the hit context. It never sends a Show that one of its own replays started, so a pair just taken over sends nothing
  back. Only two lookups by GUID are called for this; the rest is plain reads. Neither lookup, nor any drawing step
  below, runs in a frame where a logic task is in flight (logic `+0x5c0` set): an enemy that spawns in that task grows
  the two maps the lookups walk. Such a frame is skipped, and the Show lines due wait for the next.
- On the drawing side's logic thread, each copy gets the game's own BlockAI effect (2000100, then SkillCancel
  2004400), only in life state 1 and outside NoDamageNoHit. When the game takes it off, the mod puts it back, at most 5
  times in any 10 s (then `freeze-lost`: the copy stays an ordinary enemy). On every way out, and before a kill, the
  BlockAI dispel effect (2000101) takes it off. That dispel would also end the game's own BlockAI, and the game
  freezes some enemies from their spawn until an event of its own (a boss before its cutscene, the sitting LabMutants
  of AYL_02). Timed rows hold the same state too, such as LV_Sequence_Warp_Effect (7000144, 1 s). A copy that already
  holds state 39 when the mod first freezes it gets no effect from the mod and no dispel on the way out
  (`thaw skipped` in the log). When the game's freeze ends, by its own dispel or by running out, the next census finds
  state 39 gone and the mod freezes the copy as any other. A copy whose last dispel the game refused is the exception:
  its state 39 is the mod's, so the mod freezes it and dispels it again (it keeps the last 16 such copies).
- On the drawing side's game thread, each frame, each copy is found again by its GUID. Its movement component goes out
  of the game's parallel movement manager through the game's own function for that (only on the game's class with the
  game's function in that vtable slot), the speed override that the game's own MoveToLocation writes is set to the
  owner's speed, the root moves to the sample at the ghost's draw time, and Velocity follows the samples. Each Show is
  replayed through the game's Show handle API when the draw time reaches its stamp, with its hit context written into
  the new player. A Show that the drawing game started on the copy less than 1 s before (a hit's reaction, a
  mirrored crowd control, its death) and still plays is not replayed a second time.
- A copy that is knocked down, groggy, in the air or in a takedown is released: the game moves it until 200 ms after
  that ends, then it blends back to the stream over 300 ms (a snap beyond 2 m).
- Takedowns (stage 3c). Each pass reads two takedown markers in a copy's effect list, `Check_LinkSkillHit_Skill`
  (5000039) and `LinkState_MonsterHit` (2006004). When one shows on the guest's copy while same place runs on her side
  with `aggro=game`, she sends `SBF19 exec <gen> <hguid> 1`, and `SBF19 exec <gen> <hguid> 0` once her copy has held
  none for 200 ms, or at once when the copy dies or goes (a turn between the two markers ends nothing). The host takes
  one exec 1 an enemy in 2 s, none while one runs, and only when its own copy is a Monster (ActorType 3) in life state 1
  holding Groggy or a marker, or with its balance at 0 after her claims of that turn. It then hands her the enemy
  without the 4 s hold or the guards, in that turn once its copy is out of NoDamageNoHit, freezes its copy although
  Groggy releases it, and holds her lethal claim (its copy at 1 HP, its hp lines at 0) and its own dead for that enemy
  until her exec 0: 6 s after her exec 1 at most, and her lethal claim 6 s after it came at most (`held-expired`). A
  marker on the host's copy of an enemy she owns gives it back to the host the same way. While a takedown runs it counts
  as its executor's hit, so a living enemy stays with them for 10 s after it unless the other player hits it. The guest
  takes an own G for a copy in her takedown even under NoDamageNoHit.
- The owner's SBE entry carries flag 8 (`kExec`) while its copy holds a marker. The drawing side then freezes its copy
  despite Groggy, follows the stream through Groggy and through the stream's dying flag, and goes back onto the stream
  at once instead of after 200 ms, so the takedown plays there with the executor's ghost. Its own copy's death still
  releases it. Nothing in the mod starts `Passive_FinishReady` (2001102), and the host refuses an exec line for a
  BossMonster. The game still applies 2001102 by itself to a boss in a Finish stance, on her copy too; the finish
  guard ([Shared bosses](#shared-bosses)) takes it off her copy and holds her killing hit on the host's boss.
- Every way back puts each copy back in this order: its replays stopped, Velocity zeroed, the movement component back
  in the manager if it was there, the speed override as it was; then the freeze comes off. The game-thread part has
  its own SEH latch: the first fault stops it for the run, and after a fault in the mod's own reads every copy is put
  back once.
- `coop fight pilot test` limits the guest's side for solo tests from a recording: `freeze` (the BlockAI effect only),
  `cmc` (the movement component out too, nothing written), `drive` (root, speed and Velocity too) or `replay` (all of
  it, the default). Each change puts every copy back once. `coop fight pilot test target` calls the force target once,
  on the first enemy this game owns, and logs its target, aggro level and detect result as they change for a second.
  `coop fight pilot test exec` empties the balance of the first frozen copy this game draws at the job's next turn
  (a stamina drop, as a hit of its EVE), so the copy goes groggy and can be taken down.

The commands, the notices and the solo test are in [Shared enemies](../shared-enemies.md#same-place-experimental).

## Same spawns

Same spawns (`same_spawns`, experimental, the host's value, on by default, not tested in game yet) has the guest's game
hold the host's common enemies in a zone where both players stand. It builds on shared enemies: an enemy it creates
pairs through its spawn key like any other.

- Only EventSpawnTable rows that spawn on zone entry (SpawnType EnterZone), whose enemy is a Monster that shared
  enemies share (`fight_chars`, or with `auto` every Monster but the few it leaves out) and whose SaveType is None,
  ResetZone or ResetZoneWithTransform take part. Save and SaveWithTransform rows, rows that keep
  their object through a zone reset (`bResetZoneKeepObject`), and ZoneEvent and quest rows are never touched. Each
  game reads a row through the game's own lookup (`FUN_141a9db80`) and the row's zone through the ZoneTable lookup
  (`FUN_141a9b8a0`), and keeps what it read for the session. The game runs a row's lazy init (vtable slot `+0x20`)
  before its first use; in this build that slot is an empty function for both row types, so reading the rows without
  it skips nothing.
- Zones travel as ZoneTable row IDs: a zone's name is an FName, whose index differs between two processes.
- Each game counts its own epoch: one more when its current zone (logic `+0x598`) changes, when the game's spawn
  manager starts entering or resetting a zone again (its `+0x1c` goes to 1 or 2 after 3 or 4), and when 3 or more of
  its enemies come back under new GUIDs in one census (two enemies of one key are no change). The host sends `SBF19
  epoch <gen> <zone> <n>` at each change and every 5 s, so a line lost on the way stalls nothing for long, and each
  side drops a line of another epoch.
- The zone is shared while both games are in the host's zone, each settled 3 s after its last epoch began with no
  spawn pass running, and the other EVE (as its ghost stands) is within 100 m. The guest then sends her keys there as
  `SBF19 have <gen> <n> <part> <parts> <spawnId>:<idx> ...`, 24 keys a line and 10 lines at most, at once at a new
  epoch and every 5 s after. The host answers one round each 500 ms at most: `SBF19 spawn <gen> <n> <spawnId> <idx>
  <charId> <x> <y> <z> <yaw>` for each of its Monsters there she lacks within 1 km of her EVE (as her ghost stands in
  the host's world; never a dying one), where it stands in whole
  centimetres, and `SBF19 drop <gen> <n> <spawnId> <idx>` for each key of hers it lacks, 16 of each a round.
- The guest checks each line: the epoch, the shared zone, the row in her own tables and its zone, a place within 1 km of
  her EVE, no enemy of hers with that key, and 32 calls a second at most. She creates a key through the game's spawn
  function on its spawn manager (`FUN_141c1c9a0`, as `FSBCreateActor` does) and removes one through the game's despawn
  job (`FUN_141b077f0`, as a ZoneEvent despawn does): never a kill, and never an enemy that shared enemies pair. A
  created enemy that shows up as no Monster, or as another character than the host's, is removed again, within the same
  32 calls a second. One the despawn cannot find again (a dying one, for example) stays and is logged as kept. A key she
  refused counts as hers in her next list, so the host stops asking for it until the epoch moves. So does an enemy she
  killed that shared enemies did not pair (another difficulty, or past 16 pairs), since the host's enemy may still be
  alive. When its row takes part in the host's zone, the host's first drop line for such a key shows the host lacks it
  too, and the key leaves the list. A key refused as too far or for room (`full`) is left out of the list, so the host
  asks again once she is nearer or has room, and an enemy she created leaves the list once it has died or left her game.
- Both calls run inside the shared fight's job on the logic thread, under its fault latch. The spawn manager, the table
  holder and the job sender are read from their globals and never made by the mod: their getters (`FUN_141adc3d0`,
  `FUN_141a97f20`, `FUN_141a97b90`) allocate one when it is missing.
  - The spawn call gets the spawn manager, the EventSpawnId, the SpawnIndex, the position, the rotation (0, yaw, 0), no
    extra request data and flag 0 (what the flag does is not known yet). `FUN_141c1c9a0` itself passes a delay of 0 to
    `FUN_141c1ca40`, so the key spawns at once. It reads the table holder through its getter, and for a row with
    EventOnSpawning events it sends them through the job sender's getter. The spawn it starts reaches `NewActor`, whose
    actor setup reads the reg through `FUN_141a97cb0`. So the guest calls it only while the holder, its tables, the job
    sender and the reg exist; with the spawn manager or one of those not made she refuses the key (`no spawn manager`)
    and calls nothing.
  - The despawn call gets the job sender, the logic turn and the enemy's GUID, after the enemy is found again by GUID
    with that key and still fighting. While that enemy holds BattleMode (state 30) or runs a takedown marker, or either
    read fails, she refuses the drop (`busy`): the enemy stays in her list, so the host asks again and the despawn goes
    once she is done with it. A census whose list of enemies came out partial (a read that failed, or more than 256
    enemies with spawn keys) does nothing, since an enemy missing from it would read as one the game lacks.
- The `fight=` line of `coop-status.txt` carries `spawns=off`, `on` or `stopped` (the pilot's latch stops same spawns,
  since the ghost's position no longer reaches the job), and on the guest's side `spawned=`, `despawned=` and
  `spawns_differ=`: the refusals, and the created enemies undone or kept, whose reason shows that the two games' tables
  or `fight_chars` differ (`no row`, `save-row`, `keep-row`, `event-row`, `another zone`, `row taken`, `not shared`,
  `charId`), not those of the moment (`too far`, `full`, `no spawn manager`, `not made`, `gone`, `busy`, `no such
  enemy`). Lua's notices read it.
- `coop fight spawn probe` (`fight probe spawns`) runs the same census, epoch and row reads in the probe's job on one
  game, and logs the outcome for each shared Monster once an epoch, 32 a census at most so that one hand-over's 128 log
  lines are enough. It sends no line and calls neither the spawn nor the despawn function.

The log lines are in [Shared enemies](../shared-enemies.md#same-spawns-experimental).

### The spawn filter

Same spawns let the guest's game spawn its own enemies on each zone entry and reset, then remove the ones the host's
game lacks on its drop lines, at best 3 s after the zone settles. The spawn filter (`spawn_filter`, the guest's own,
off by default, not tested in game) has her game refuse those spawns instead. Lua adds the word `filter` to the `coop
fight on` request (and to the spawn probe's); it is a word of that request, never a line on the wire, so the protocol
stays 12.

- The keys (`SpawnGuest` in `fight/spawn_sync.h`): a key she despawned on the host's drop, a key she answered with no
  enemy of hers left (refused, or killed while not paired) that the host's drop names, and the key of each paired copy
  of hers that died on the host's `dead` line, when its row takes part in the host's zone. A copy whose fight she took
  no part in does not die there ([Achievements](safety.md#achievements)) and is not listed; the host's next drop removes it
  and lists it then. Her own lethal hit adds nothing until the host's `dead` comes, since the host may refuse it. An
  extra enemy's key has no row, so no spawn request names it, and it is never listed. A spawn line of the host's epoch
  takes its key off before her spawn runs (her own create meets the filter too). A new host epoch, a world line from
  either side and the session's end empty the list: the host's on, off or world as it comes in, and hers as it goes
  out (her fence: a load, or a census whose every enemy is new). Her own epoch moves keep it, since her resets respawn
  exactly these keys, but a reset of hers that her fence also takes as a world change runs unfiltered. Which of her
  deaths and camp rests do that is for the in-game test to show. 240 keys at most.
- After each of her steps, and before each spawn of hers, the shared fight's job publishes the list to a table of 240
  atomics (`BlockTable`, `spawnId << 8 | index` a slot), which a hook on any thread can read without a lock. A new
  session empties the table before its gate opens.
- The hook sits in one slot of the game's image: the second entry of the SpawnRequest vtable (`.rdata` `0x145c10020`,
  the vtable at `0x145c10018`), which holds `SpawnRequest::Execute` (`0x141c10a90`). RequestSpawn (`FUN_141c1ca40`)
  calls Execute directly while the slot holds it and through the slot otherwise, and the consumer of its delayed queue
  (`FUN_141c1cd20`) always calls through the slot; neither has a CFG check. One aligned 8-byte store therefore routes
  both through the hook, and no instruction byte of the game changes.
- The worker makes the swap once a run, when the gate first opens (the guest's side asked with `filter`, or the spawn
  probe), on the pinned build, before `coop off` and before any fault of the hook. It reads the slot, makes its page
  writable with `VirtualProtect`, swaps it with `InterlockedCompareExchange64` from Execute only, and puts the page's
  protection back. A slot that holds anything else (another mod's hook) is refused with a log line naming what it
  holds, and never written. At `coop off`, and after a fault of the hook, a compare-and-swap from the hook only puts
  Execute back; any other value is left. The DLL is pinned, so a thread still inside the hook after the undo returns
  into mapped code. Between sessions the hook stays and passes every request on.
- The hook takes the request. With the gate shut it calls Execute at once. With the gate open, under its own SEH latch,
  it reads the table holder (`DAT_147032510`, never through its getter `FUN_141a97f20`, which makes one when none
  exists), finds the request's EventSpawnTable row with `FUN_141a9a780(holder, 0, request + 0x28)` (the row's FName,
  the call Execute makes first), and builds the key from the row's EventSpawnId (`+0x10`) and the request's SpawnIndex
  (`+0x30`), the two values Execute passes to `NewActor`. A key in the table is counted, pushed to a 16-entry ring for
  the worker's log, and refused: the hook returns null, which every caller takes (the immediate path returns it, the
  delayed one ignores it, and SB's own spawn rule asks again later and is refused again). Any other request goes to
  Execute, which runs outside the guard, so a fault inside the game's code is never taken for the hook's. Execute reads
  RCX only, so a one-argument hook forwards all it reads.
- It refuses only EnterZone Monster rows of None and ResetZone types that the host lacks at that place, the keys same
  spawns already remove. It never kills, so nothing reaches rewards, drops, kill counters, the zone's death record or
  zone events, and ZoneEvent and Quest spawns are other rows that never reach the table. A wrong refusal heals: the
  host's next round sends `spawn` for the key, which leaves the table before her create runs.
- The first entry into a zone still spawns and removes: the guest learns what the host lacks only from its drops and
  its `dead` lines. The filter takes her later resets in that host epoch, except one that is also a world change in
  her game. Sending the host's absent keys with its epoch line would cover the first entry too; it needs a walk of the
  EventSpawn table by zone, not reverse-engineered yet.

The log lines are in [Shared enemies](../shared-enemies.md#spawn-filter-experimental).

## Extra enemies

Extra enemies (`enemy_extra`, 0 to 3, the host's value, 0 by default, not tested in game yet) build on same spawns:
the host's game makes that many more of each common enemy where both players stand, and same spawns hand them to the
guest's game like any other key of the host's that she lacks.

- The host gives extras to a Monster that shared enemies share, of a row that same spawns reconcile (an EnterZone row
  that is no Save or keep row: the guest's save may hold that enemy dead), not dying, within 116 m of either EVE (so
  its farthest extra stands within 120 m), while the zone is shared. Bosses and Alpha Naytibas are BossMonsters
  (ActorType 4), so they get none, and neither do the four Monsters the CharacterTable ranks Boss or Elite: M_Gorgon
  (50330), M_RoyalGuardFemale (50500) and its WLA_ and WLB_ variants (45050001, 55050001). An enemy gets its extras
  once a life: after a respawn under a new GUID it gets new ones. Extras are made only while the shared Monsters within
  120 m of either EVE, counted with the host's extras and the new ones, stay at 16 or fewer, the most stage 1 can
  pair.
- An extra's key is EventSpawnId `0xE0000000 | n << 8 | slot` and SpawnIndex `slot`, where n counts the enemies given
  extras since the game started (a new session goes on counting, so a dying extra of the last one never shares a key
  with a new one) and slot runs from 1 to 3. No EventSpawnTable row of this build is in that range (its highest
  EventSpawnId is `0xD42B5F51`). The host checks once a session that its tables hold no row at the first key,
  `0xE0000101`; if they do, extras stay off for the session. The game's death path skips the respawn and the zone
  bookkeeping for an actor whose key has no row; that a save never holds one is still to be checked in game.
- Slot s stands 100 + 100 s cm from its enemy (2, 3 or 4 m), 120 degrees apart around the enemy's yaw, at the
  enemy's height and facing its way. The game's `NewActor` (`FUN_141ad1290`) makes it, with the arguments
  `SpawnRequest::Execute` passes: the logic singleton, the charId, the position, the rotation (0, yaw, 0), not a
  player (0, 0), the key, 0 for the row field, 0, 1, no request extra data, 0, flag 0 (no actor replaced) and 0. The
  request extra data is null because the game's FSBActor creation (`FUN_141ca9100`) checks it for null and then keeps
  the same default a fresh request would copy in.
- Same spawns count an extra's key as part of the shared zone without a row: the host sends `spawn` for one she lacks
  and `drop` for one of hers it lacks. She makes the key through `NewActor` too, with the charId of the host's line,
  and refuses it (`row taken`) when her own tables hold a row at that key, or (`no such enemy`) when no Monster of
  hers that shared enemies share has that charId: the host makes extras of common enemies only, so any other charId
  would be a character the host picked freely. A key refused as `no such enemy` or `full` is left out of her list, so
  the host sends it again: an extra's own enemy can come in the same answer and only show in her next census. Stage 1
  then pairs the two copies by key.
- Each game keeps the extras it made in its capture list, 48 at most. One that left the map (killed, despawned) is
  forgotten at the next census. The host despawns one still fighting more than 120 m from both EVEs. At the session's
  end every extra still fighting is despawned in each game, and a dying one is left to its death. The host's extras
  also go when her shared enemies stop (her off line) or her lines are ignored, and hers when the host's same spawns
  stop on her side (its off or world line). Every despawn goes through the game's despawn
  job (`FUN_141b077f0`), never a kill.
- `NewActor` runs inside the shared fight's job on the logic thread, under its fault latch, only while the table
  holder, the world's actor manager, the job sender and the reg exist: `NewActor` and its actor setup
  (`FUN_141ba6d20`) read them through getters that would make them (the job sender's `FUN_141a97b90` and the reg's
  `FUN_141a97cb0` for the last two). An extra whose GUID cannot be read right after `NewActor` stops the shared fight
  for the run and is logged as kept, since no capture can take it off.

The log lines are in [Shared enemies](../shared-enemies.md#extra-enemies-experimental).

## Shared bosses

Shared bosses (`bosses`, experimental, the host's value, on by default, not tested in game yet) add the bosses and
Alpha Naytibas (the game's BossMonster type, ActorType 4) to the pairs of shared enemies. A boss takes a place before
any common enemy, its maximum HP takes the host's `boss_hp_scale`, and with same place on its AI stays in the host's
game. The host sends `SBF19 bosses <gen> <percent>` with its list.

With same place on, the guest's copy of a boss is frozen and never casts a skill, so on its own it would never enter
battle mode, change phase or summon anything. The host's job reads them on its own copy and tells her game, which
applies them to her copy:

- The host reads its boss's battle mode (FSBActor `+0xb58`) and sends `SBF19 bstart <gen> <hguid>` when it turns on,
  then every second while it stays on.
  - The guest calls the game's SetBattleMode wrapper (`FUN_141a7cd30`) on her copy, once while the copy stays in battle
    mode, with the arguments of the game's own `FSBActor::AddTargetedByEnemy`: on, then `0, 0, 0, 1`. The fifth
    argument, 0, runs the boss's `EventOnBattle` (mostly the arena walls), and the call runs `EventFirstTimeOnBattle`
    once. Called from the logic thread, the game queues it for its game thread. She calls it only for a copy her game
    draws as a BossMonster in life state 1, with the job sender and the reg already made (the call reads both through
    getters that would make them), and only while her EVE is within 30 m of her copy or its last player
    ([Achievements](safety.md#achievements)). A refused bstart is taken at the host's next repeat.
  - Her game takes the copy out of battle mode through the same wrapper with off, then `0, 0, 1, 1`, the arguments of
    the game's own battle-off calls: when the host's lines bring no bstart for 10 s (the host's boss left battle mode; a
    gap of over 2 s with no line from the host, as while the host's game is paused, is not counted), when her game stops
    drawing the copy (the pair ends, same place stops) and when the session ends (`coop fight off`, the link, the fault
    latch). A dying copy gets no call. The host's next bstart for that copy calls it again.
- The host reads its boss's effect list and keeps the rows of that boss's allowlist, a table built from the game's
  tables for build 24463856: its phase rows and their FX rows that a skill applies, and its MinimumHP rows (the phase
  thresholds, and `MinimumHP_Dispel` 1001323). It sends them in list order as
  `SBF19 phase <gen> <hguid> <oe> <id,id,...|->` when they change and every second in battle mode.
  - The guest refuses a line with an ID her own table does not hold for that boss (a bad line), of another owner epoch,
    or for a copy her game does not draw. Through the game's effect call (`FUN_141ad08b0`), her copy its own caster as
    for the boss's own skill step, she applies each row that came into the host's set since her last line for that copy,
    in the host's order, a dispel row first (the host's copy holds a row next to the dispel that would end it only when
    that row started later).
  - On her first line for a copy, and on the line after the game refused one of her rows, she compares the set with her
    copy's effect list instead: each row the copy lacks has come, and each row of the allowlist it holds that the set
    lacks has left. Before them she applies `MinimumHP_Dispel` when a threshold left the set and none came in, and the
    boss's phase dispel row (Crawler 5022094, SkullJuggernaut 5015002) when a phase row left and none came in. The phase
    row's own stance change does the rest on her copy.
  - 19 bosses have a row in the table; the other BossMonsters (the Alpha Naytibas, challenge and variant rows) get
    bstart lines only.
- At each census the host looks for actors with no spawn key whose owner (logic actor `+0x400`) is a boss it shares, and
  finds the SummonActor row that made each one in the owner's effect list, by the effect GUID at `+0x40c` (an effect's
  GUID is at its `+0x20`). Marionette's DollHeads and Maelstrom's BodyBags have rows in the table. The reward dummies
  and the Elder's dummy have none and stay in the host's game.
  - A summon gets a key in the summon range, EventSpawnId `0xF0000000 | n` and SpawnIndex 0, where n counts the summons
    since the game started, and joins the shared list under it. After its up the host sends
    `SBF19 spawn <gen> <n> <key> 0 <charId> <x> <y> <z> <yaw> <owner hguid> <row>`, with epoch 1 when same spawns do not
    run, and sends it again every second while it follows the summon: her game takes a repeat as one it has, and a line
    it refused for a passing reason (its boss not paired yet) can go through later.
  - The guest makes it through `NewActor`, as for extra enemies, with that key where the host's stands: only within 1 km
    of her EVE, for an owner she pairs as a BossMonster, and for a row of her table that makes that charId. She then
    applies the row's effects through the effect call (its Start row, which holds the summon still for a moment, and its
    Check row), and the pair forms on the key; same place freezes and drives it like any other copy. If the game refuses
    one of those effects, she despawns the summon at once: without them her hits would take far more HP than the host's
    copy loses.
  - A summon of hers that no pair holds 3 s after she made it is despawned too, and so is every one still fighting when
    the session ends. A key she despawned for either reason is not made again until the next on, off or world line of
    either game. She holds 32 at most at once.
- A Finish stance (HP under 2) applies `Passive_DeathReady` (2001101), which chains `Passive_FinishReady` (2001102, the
  state the finisher needs). In each turn a paired boss copy of hers holds either one, her game applies
  `FinishReady_Dispel` (2001103) and then the boss's own `Passive_Immortal` (2001100) again: her hits stop at 1 HP and
  no finisher starts on her side. On the host's side, her claim that would kill a boss whose copy holds either row takes
  it down to 1 HP and kills nothing, however long the stance lasts (`fight finish-held`). So a boss in its Finish stance
  ends only by the host's finisher; a boss without one dies of her killing hit, unless its own thresholds or Immortal
  hold it. When the host's `dead` comes for a boss whose fight she took part in, her game applies `MinimumHP_Dispel`
  and `FinishReady_Dispel` to her copy before the kill, so neither a threshold nor Immortal holds it. When the pair
  ends any other way (the host's `dead` for a fight she was not in, the host's `down` or world line, the link,
  `coop fight off`, the fault latch), her game applies `FinishReady_Dispel` to a guarded copy still under 2 HP, so the
  Immortal it put back goes and her own hit ends that boss in her game.
- Every call runs inside the shared fight's job on the logic thread, under its fault latch. The host's side makes no
  new game call: it reads, and her claims go through ApplyStat as before. Recordings keep none of these lines.

The log lines are in [troubleshooting.md](../troubleshooting.md#a-shared-boss-differs-between-the-two-games).
