# Shared enemies: how they work

The player's side, with the settings of each part, is in [Shared enemies](enemies.md). The rule for kills and
achievements is in [Achievements and safety](../dev/safety.md#achievements).

The shared fight runs between two games: the host and its partner (`Link::partner()`). In an online session of more than
2 players that is the guest in ghost slot 0. `glue/steam.cpp` sends the `SBF` lines to her only and hands the job her
lines only; `SBE` goes to her only too (see [The Steam
link](../online/steam-link-internals.md#sessions-of-more-than-2-players)).

## Same-place enemies

Same place (`same_place`, experimental, the host's value, on by default, not tested in game yet) builds on shared
enemies: the same pairs, the same host and the same Steam channel 2. Each pair has an owner, the game whose copy runs
the enemy's AI and moves it; the other game draws its copy (stages 3a and 3b of Phase 11). The host decides the owner.
HP, Shield, balance and death stay with the host's game whoever owns the pair.

- The host's `same_place` decides for both games. The host sends it as `SBF29 place <gen> <0|1>` after its world line
  (and its scale line) while it is on, and again at each change, `coop fight pilot off` and an error included. The
  guest draws her copies only while the host's last place line says 1, and forgets it with the host's next world, on or
  off line. Her own value is not read at a start: her co-op menu row only stops same place on her side, or starts it
  again, while shared enemies wait or run (`coop fight pilot off` and `on`).
- Every pair starts as the host's. With `aggro=game` (the host's setting, the default) the host's job runs a rule on
  each pair every turn: the pair goes to whoever hit it last (a hit on the host's copy, or a claim of hers that lowered
  a stat), and after 10 s without a hit to the other player once that player's EVE has stood at least 3 m nearer, and
  within 30 m of it, for 2 s (the force target that follows makes that EVE the enemy's last player, which counts as
  taking part in its fight: [Achievements](../dev/safety.md#achievements)). Nothing changes hands within 4 s of the last change, while
  an AI task runs on the owner's copy, during Down, Groggy, Airborne or a takedown, while the enemy dies, or while the
  host draws a copy that the game froze before the mod did (below: its AI would not run once the host owns it); the
  start of a takedown is the exception (below). Each change moves the owner epoch one up and goes to her as
  `SBF29 own <gen> <hguid> <H|G> <oe>`; the host freezes its copy as it sends own G and thaws it as it sends own H. With
  `aggro=host` the host keeps every pair (stage 3a). The host sends `SBF29 aggro <gen> <game|host>`.
- The guest takes an own G only at her epoch plus one, for a paired copy in life state 1 while same place runs on her
  side, and thaws her copy in that turn. She refuses a copy that the game froze before the mod did (why `state`),
  except for her takedown. Otherwise, and when she can no longer run a pair she owns, she answers
  `SBF29 own-no <gen> <hguid> <oe> <why>`, where why is `unpaired`, `state`, `off`, `epoch`, `aggro`, `full` or
  `target`, and the pair is the host's again. After `off` or `aggro` the host hands her nothing for 30 s, and after any
  other reason not that pair. A world line, an on or an off line starts the epochs over on both sides and ends both
  pauses.
- In the frame a hand-over makes a pair a game's own at a new epoch, its game thread first puts the copy back
  (below), then calls the game's force target function (`FUN_141a361b0`) toward its own EVE: detect result 3, aggro
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
  with `aggro=game`, she sends `SBF29 exec <gen> <hguid> 1`, then `SBF29 exec <gen> <hguid> 0` once her copy has held
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
  releases it. Nothing in the mod starts `Passive_FinishReady` (2001102). The host refuses a takedown's exec line for a
  BossMonster; an exec 1 for a boss pair takes the finisher path instead ([The finisher press](#the-finisher-press)).
  The game still applies 2001102 by itself to a boss in a Finish stance, on her copy too; the finish
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

The commands, the notices and the solo test are in [Shared enemies](enemies.md#same-place-experimental).

## Enemies at the ghost

SB keeps two overlapping characters apart in each one's own tick. `ASBCharacter::TickLocationFromOverlapCollision`
(`FUN_1420ad9a0`) moves the character out of each character its overlap list holds, when `FUN_1420ad3b0` lets that one
push it. The list's only writer is the begin-overlap handler (`FUN_142040da0`), which takes SB characters and area
volumes alone, so no list ever holds the ghost. `fight/enemies/push_game.inc` does the same work for the ghost on the
game thread each frame (`push_tick()`, after `guarded_pilot()` in `coop_tick`), under its own SEH latch
(`push_faulted`):

- Gates (`fight::push_now`): game calls allowed (`game_calls_ok()`), not after `coop off`, not while SB's pause holds
  (a menu, our photo mode, our freeze tag: `FreezeGame::paused()`), no cutscene in our theater or shared scene, the
  ghost shown (`ghost_shows()`) and drawn in the last second. A logic task in flight holds the frame. Lua writes
  `collide=0` into `coop-state.txt` when `collide` is off or an SBO session runs (the capsule's rule). The pass then
  stops.
- Enemies: SB's actor manager's FSBActors of type Monster or BossMonster within 5 m of a ghost's body (FSBActor
  `+0x4cc`), never a copy this side draws (same-place enemies' `pilot_table`: her game runs it, where her real EVE
  meets it). Each one's character through SB's character map, at most 32 a frame.
- Bodies: the ghost's is EVE's `BodyCollision` (radius 50, half height 95, 98 cm up her main mesh, pak data), placed on
  the drawn root. The enemy's is its `OverlapBodyCollision` (`+0x850`) or else its `CapsuleComponent` (`+0x338`) at its
  root's place. SB scales a capsule's radius by the smaller of its x and y scale and its half height by z.
- The step (`fight::push`, `0x1420af3b8` to `0x1420af5b9`): along the horizontal line from her centre to its root, to
  its free place (where it touches her, at most 100 cm away: SB's sweep starts 100 cm out), at most
  `max(100 cm/s, 0.95 x the distance to its movement component's vector +0xf74) x dt`. dt is the world's
  `DeltaTimeSeconds` (`+0x758`) times the enemy's `CustomTimeDilation` (`+0xb0`): the actor tick's delta. Two centres
  on one vertical give SB no direction and no push.
- SB's rule (`fight::sb_lets_push`), the ghost standing in for an EVE with your own EVE's weight (`+0x2830`, the
  CharacterTable row's `WeightType`) and rank (`+0x2c9c`): the same weight moves a lower rank, or the same rank while
  it moves or she stands still (her drawn root moved since the last frame). Weights that differ move the lighter one.
  An enemy is never moved while its bytes `+0x26ec` or `+0x26ed` are set, its movement component is not SB's, a float
  of `+0x3300` to `+0x3308` is not 0, its weak pointer `+0x2d90` is live, its int `+0x2848` is above 0, its movement
  mode is 6 with custom mode 3, or its byte `+0x29a8` is set. Her own state bytes are not on the wire and count as
  clear.
- The move: the sum over the ghosts it overlaps, through its root's `MoveComponent` (vtable `+0x4a0`) as a teleport
  with its rotation kept, the call `FUN_1420ad9a0` makes at `0x1420af5b9`.

Not applied: the significance test at the top of `FUN_1420ad3b0` (`FUN_142476c80` and three thresholds at
`0x146d94630`), which needs SB's significance manager's lookups. `UE4SS.log` gets `enemy contact, last 60 s: <n>
pushes, <n> copies left alone, <n> refused by SB's rules, <n> frames held (paused, scene, hidden), <n> not read, <n>
over 32 a frame` and, after a fault, `enemy contact off: fault ...` once.

## Same spawns

Same spawns (`same_spawns`, experimental, the host's value, on by default, not tested in game yet) has the guest's game
hold the host's common enemies in a zone where both players stand. It builds on shared enemies: an enemy it creates
pairs through its spawn key like any other.

- Only EventSpawnTable rows that spawn on zone entry (SpawnType EnterZone), whose enemy is a Monster that shared
  enemies share (`fight_chars`, or with `auto` every Monster but the few it leaves out) and whose SaveType is None,
  ResetZone or ResetZoneWithTransform take part. Save and SaveWithTransform rows, rows that keep
  their object through a zone reset (`bResetZoneKeepObject`), and ZoneEvent and quest rows are never touched. Each
  game reads a row through the game's own lookup (`FUN_141a9eba0`) and the row's zone through the ZoneTable lookup
  (`FUN_141a9c8c0`), and keeps what it read for the session. The game runs a row's lazy init (vtable slot `+0x20`)
  before its first use; in this build that slot is an empty function for both row types, so reading the rows without
  it skips nothing.
- Zones travel as ZoneTable row IDs: a zone's name is an FName, whose index differs between two processes.
- Each game counts its own epoch: one more when its current zone (logic `+0x598`) changes, when the game's spawn
  manager starts entering or resetting a zone again (its `+0x1c` goes to 1 or 2 after 3 or 4), and when 3 or more of
  its enemies come back under new GUIDs in one census (two enemies of one key are no change). The host sends `SBF29
  epoch <gen> <zone> <n>` at each change and every 5 s, so a line lost on the way stalls nothing for long, and each
  side drops a line of another epoch.
- The zone is shared while both games are in the host's zone, each settled 3 s after its last epoch began with no
  spawn pass running, and the other EVE (as its ghost stands) is within 100 m. The guest then sends her keys there as
  `SBF29 have <gen> <n> <part> <parts> <spawnId>:<idx> ...`, 24 keys a line and 10 lines at most, at once at a new
  epoch and every 5 s after. The host answers one round each 500 ms at most: `SBF29 spawn <gen> <n> <spawnId> <idx>
  <charId> <x> <y> <z> <yaw>` for each of its Monsters there she lacks within 1 km of her EVE (as her ghost stands in
  the host's world; never a dying one), where it stands in whole
  centimetres. It also sends `SBF29 drop <gen> <n> <spawnId> <idx>` for each key of hers it lacks, 16 of each a round.
- The guest checks each line: the epoch, the shared zone, the row in her own tables and its zone, a place within 1 km of
  her EVE, no enemy of hers with that key, and 32 calls a second at most. She creates a key through the game's spawn
  function on its spawn manager (`FUN_141c1dbf0`, as `FSBCreateActor` does) and removes one through the game's despawn
  job (`FUN_141b08a30`, as a ZoneEvent despawn does): never a kill, and never an enemy that shared enemies pair. A
  created enemy that shows up as no Monster, or as another character than the host's, is removed again, within the same
  32 calls a second. One the despawn cannot find again (a dying one, for example) stays and is logged as kept. A key she
  refused counts as hers in her next list, so the host stops asking for it until the epoch moves. So does an enemy she
  killed that shared enemies did not pair (another difficulty, or past 16 pairs), since the host's enemy may still be
  alive. When its row takes part in the host's zone, the host's first drop line for such a key shows the host lacks it
  too, and the key leaves the list. A key refused as too far or for room (`full`) is left out of the list, so the host
  asks again once she is nearer or has room, and an enemy she created leaves the list once it has died or left her game.
- Both calls run inside the shared fight's job on the logic thread, under its fault latch. The spawn manager, the table
  holder and the job sender are read from their globals and never made by the mod: their getters (`FUN_141add610`,
  `FUN_141a98e30`, `FUN_141a98aa0`) allocate one when it is missing.
  - The spawn call gets the spawn manager, the EventSpawnId, the SpawnIndex, the position, the rotation (0, yaw, 0), no
    extra request data and flag 0 (what the flag does is not known yet). `FUN_141c1dbf0` itself passes a delay of 0 to
    `FUN_141c1dc90`, so the key spawns at once. It reads the table holder through its getter, and for a row with
    EventOnSpawning events it sends them through the job sender's getter. The spawn it starts reaches `NewActor`, whose
    actor setup reads the reg through `FUN_141a98bc0`. So the guest calls it only while the holder, its tables, the job
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

The log lines are in [Shared enemies](enemies.md#same-spawns-experimental).

### The spawn filter

Same spawns let the guest's game spawn its own enemies on each zone entry and reset, then remove the ones the host's
game lacks on its drop lines, at best 3 s after the zone settles. The spawn filter (`spawn_filter`, the guest's own,
on by default, not tested in game) has her game refuse those spawns instead. Lua adds the word `filter` to the `coop
fight on` request (and to the spawn probe's); it is a word of that request, never a line on the wire, so the protocol
stays 12.

- The keys (`SpawnGuest` in `game/spawn_sync.h`): a key she despawned on the host's drop, a key she answered with no
  enemy of hers left (refused, or killed while not paired) that the host's drop names, and the key of each paired copy
  of hers that died on the host's `dead` line, when its row takes part in the host's zone. A copy whose fight she took
  no part in does not die there ([Achievements](../dev/safety.md#achievements)) and is not listed; the host's next drop removes it
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
- The hook sits in one slot of the game's image: the second entry of the SpawnRequest vtable (`.rdata` `0x145c15ea0`,
  the vtable at `0x145c15e98`), which holds `SpawnRequest::Execute` (`0x141c11ce0`). RequestSpawn (`FUN_141c1dc90`)
  calls Execute directly while the slot holds it and through the slot otherwise, and the consumer of its delayed queue
  (`FUN_141c1df70`) always calls through the slot; neither has a CFG check. One aligned 8-byte store therefore routes
  both through the hook, and no instruction byte of the game changes.
- The worker makes the swap once a run, when the gate first opens (the guest's side asked with `filter`, or the spawn
  probe), on the pinned build, before `coop off` and before any fault of the hook. It reads the slot, makes its page
  writable with `VirtualProtect`, swaps it with `InterlockedCompareExchange64` from Execute only, and puts the page's
  protection back. A slot that holds anything else (another mod's hook) is refused with a log line naming what it
  holds, and never written. At `coop off`, and after a fault of the hook, a compare-and-swap from the hook only puts
  Execute back; any other value is left. The DLL is pinned, so a thread still inside the hook after the undo returns
  into mapped code. Between sessions the hook stays and passes every request on.
- The hook takes the request. With the gate shut it calls Execute at once. With the gate open, under its own SEH latch,
  it reads the table holder (`DAT_1470373b0`, never through its getter `FUN_141a98e30`, which makes one when none
  exists), finds the request's EventSpawnTable row with `FUN_141a9b690(holder, 0, request + 0x28)` (the row's FName,
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

The log lines are in [Shared enemies](enemies.md#spawn-filter-experimental).

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
  enemy's height and facing its way. The game's `NewActor` (`FUN_141ad24d0`) makes it, with the arguments
  `SpawnRequest::Execute` passes: the logic singleton, the charId, the position, the rotation (0, yaw, 0), not a
  player (0, 0), the key, 0 for the row field, 0, 1, no request extra data, 0, flag 0 (no actor replaced) and 0. The
  request extra data is null because the game's FSBActor creation (`FUN_141caa350`) checks it for null and then keeps
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
  job (`FUN_141b08a30`), never a kill.
- `NewActor` runs inside the shared fight's job on the logic thread, under its fault latch, only while the table
  holder, the world's actor manager, the job sender and the reg exist: `NewActor` and its actor setup
  (`FUN_141ba7f60`) read them through getters that would make them (the job sender's `FUN_141a98aa0` and the reg's
  `FUN_141a98bc0` for the last two). An extra whose GUID cannot be read right after `NewActor` stops the shared fight
  for the run and is logged as kept, since no capture can take it off.

The log lines are in [Shared enemies](enemies.md#extra-enemies-experimental).

## Shared bosses

Shared bosses (`bosses`, experimental, the host's value, on by default, not tested in game yet) add the bosses and
Alpha Naytibas (the game's BossMonster type, ActorType 4) to the pairs of shared enemies. A boss takes a place before
any common enemy and its maximum HP takes the host's `boss_hp_scale`. With same place on its AI changes hands by the
aggro rule since phase 3 ([Boss hand-overs](#boss-hand-overs)). The host sends `SBF29 bosses <gen> <percent>
<first|host>` with its list: the last word is its `boss_finish` ([The finisher press](#the-finisher-press)).

With same place on, the copy a game draws is frozen and never casts a skill, so on its own it would never enter battle
mode, change phase or summon anything. The owner's job reads them on its own copy and tells the other game, which
applies them to its copy. The list below says host for the owner and guest for the side that draws, as it was before
phase 3; with the guest as owner the roles swap:

- The host reads its boss's battle mode (FSBActor `+0xb58`) and sends `SBF29 bstart <gen> <hguid>` when it turns on,
  then every second while it stays on.
  - The guest calls the game's SetBattleMode wrapper (`FUN_141a7db20`) on her copy, once while the copy stays in battle
    mode, with the arguments of the game's own `FSBActor::AddTargetedByEnemy`: on, then `0, 0, 0, 1`. The fifth
    argument, 0, runs the boss's `EventOnBattle` (mostly the arena walls), and the call runs `EventFirstTimeOnBattle`
    once. Called from the logic thread, the game queues it for its game thread. She calls it only for a copy her game
    draws as a BossMonster in life state 1, with the job sender and the reg already made (the call reads both through
    getters that would make them), and only while her EVE is within 30 m of her copy or its last player
    ([Achievements](../dev/safety.md#achievements)). A refused bstart is taken at the host's next repeat.
  - Her game takes the copy out of battle mode through the same wrapper with off, then `0, 0, 1, 1`, the arguments of
    the game's own battle-off calls: when the host's lines bring no bstart for 10 s (the host's boss left battle mode; a
    gap of over 2 s with no line from the host, as while the host's game is paused, is not counted), when her game stops
    drawing the copy (the pair ends, same place stops) and when the session ends (`coop fight off`, the link, the fault
    latch). A dying copy gets no call. The host's next bstart for that copy calls it again.
- The host reads its boss's effect list and keeps the rows of that boss's allowlist, a table built from the game's
  tables for build 26123051: its phase rows and their FX rows that a skill applies, and its MinimumHP rows (the phase
  thresholds, and `MinimumHP_Dispel` 1001323). It sends them in list order as
  `SBF29 phase <gen> <hguid> <oe> <id,id,...|->` when they change and every second in battle mode.
  - The guest refuses a line with an ID her own table does not hold for that boss (a bad line), of another owner epoch,
    or for a copy her game does not draw. Through the game's effect call (`FUN_141ad1af0`), her copy its own caster as
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
  - A summon gets a key in the summon range, EventSpawnId `0xF0000000 | member << 24 | n` and SpawnIndex 0, where
    member is the owner's (0 the host, 1 the guest) and n counts that side's summons since the game started (1 to
    2^24 - 1). It joins the shared list under it. After its up the host sends
    `SBF29 spawn <gen> <n> <key> 0 <charId> <x> <y> <z> <yaw> <owner hguid> <row>`, with epoch 1 when same spawns do not
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
  it down to 1 HP and kills nothing, however long the stance lasts (`fight finish-held`), unless her press won the
  finisher. With `boss_finish=host` a boss in its Finish stance ends only by the host's finisher. With `first` the
  guard runs only once the host named another member ([The finisher press](#the-finisher-press)). A boss without a
  Finish stance dies of her killing hit, unless its own thresholds or Immortal hold it. When the host's `dead` comes
  for a boss whose fight she took part in, her game applies `MinimumHP_Dispel` and `FinishReady_Dispel` to her copy
  before the kill, so neither a threshold nor Immortal holds it. When the pair ends any other way (the host's `dead`
  for a fight she was not in, the host's `down` or world line, the link, `coop fight off`, the fault latch), her game
  applies `FinishReady_Dispel` to a guarded copy still under 2 HP, so the Immortal it put back goes and her own hit
  ends that boss in her game.
- Every call runs inside the shared fight's job on the logic thread, under its fault latch. The host's side makes no
  new game call: it reads, and her claims go through ApplyStat as before. Recordings keep none of these lines.

### Boss hand-overs

Since phase 3 a boss pair changes hands under the same rule as a common enemy (`pilot::rule`: the last hit, the nearer
player after 10 s, the 4 s hold, the down EVE's give and take-back), unless `aggro=host`. A boss pair is also busy, and
stays with its owner, while:

- a story scene plays in either game: story together's game part sets the shared flag `story_scene`
  (`glue/tick/freeze_game_shared.inc`) from its `active()` or `pending()`. The fight's worker hands it to the job at
  each pass (`Engine::scene()`);
- its phase rows changed in the last 3000 ms (`kPhaseHoldMs`): the owner's change that logs `phase sent`, or a phase
  line taken whose row set differs from the last one; the 1 s repeats of an unchanged set do not count;
- the host's copy shows its Finish stance;
- a `fin` or `qte-own` line named a member for it (`Host::named`).

The first `own-no ... target` for a boss pair turns the boss pilot off for the run (`Engine::boss_hands()`, `fight
boss pilot off`). Every boss then stays with the host, as with `aggro=host`. The gate fires on a refused take-over
only: a boss that takes the forced target and ignores it is not caught (not checked in game). A fault in the boss code
stops the whole shared fight through the job's latch.

The bstart, phase and summon spawn lines go from the pair's owner on either side. The host's receive loop
(`engine_run.h`) hands her `bstart`, `phase` and summon `spawn` lines to `boss_in_`, as the guest's does. Each side
takes a pair's lines only from its current owner, `phase` also only at the owner's epoch. `bstart` and the summon
`spawn` carry no epoch: the channel is reliable and in order, so a line sent before a hand-over arrives before the
`own` line that ends it. A bstart for a copy already in battle mode is counted with no SetBattleMode call:
`FUN_141a7db90`, with FSBActor `+0xb58` already on, runs `EventOnBattle` (`FUN_141a68440`) again. A copy that turned
ours keeps its battle mode, since its own AI runs the fight from then. `Guest::phase_ran()` forgets the host's last
phase set each turn the pair is hers, so the host's first phase line after it took the boss back plans from her copy's
list. Each side keys only the summons of a boss it owns.

### The finisher press

Lua adds ` finish-host` after `bosses <n>` in `coop fight on` and `coop fight record` for `boss_finish=host`; `first`,
the default, adds nothing. A bosses line without its fourth word reads as `host` (a host built before phase 3).

- With `first`, a press is a takedown marker on the host's copy in its Finish stance (`Host::own_press`, called before
  her lines are drained) or her `exec 1` for a pair whose host copy holds that stance. In one turn the host's own
  wins, then the lowest member number. The winner (`Host::finisher()`) stays until the pair dies or leaves. Her off
  forgets a win of hers. The host sends `SBF29 fin <gen> <hguid> <member>` once, then again in each whole list after
  her on or world, after the up lines.
- The guest's `takedowns()` sends exec 1 for a boss copy in its Finish stance with `first` even when same place does
  not run on her side or with `aggro=host`. `Host::exec()` skips its stale check for a boss pair with bosses on.
  Common enemies keep both gates.
- Her exec 1 for a pair whose host copy is not in its Finish stance yet waits 1000 ms (`kFinishWaitMs`), checked
  again at each step: the game puts DeathReady and FinishReady on the copy a tick after the hit that brought it low.
  Then it is refused with the words a takedown's exec gets. A press refused for another reason never waits.
- With `host`, her exec 1 is refused at once with `the host finishes` while the host's EVE is up. While it is down
  the first press counts. Her game's guard still runs in this mode, so her prompt stays hidden (open).
- Once `fin` names another member, the host's job casts `FinishReady_Dispel` (2001103) then `Passive_Immortal`
  (2001100) on its own copy each turn the stance shows, captured as the guest's guard is: its prompt goes. A press of
  the host's after that is refused (`fight finish refused ... another member won`). Her winning lethal claim lifts
  that capture and casts `MinimumHP_Dispel` (1001323) and `FinishReady_Dispel` on the host's copy before the kill,
  past the NoDamageNoHit hold. Without a win of hers, her lethal claim stays held at 1 HP (`finish-held`).
- The guest runs her finish guard with `host`, or once `fin` names another member. A `fin` naming her: no guard.
- The worker's `fight=` line shows `fin=<member|->` while the mode on runs. Lua says `fight.finisher` with the
  winner's name once a winner, never when the winner is ours.

### The QTE owner

`native/src/game/boss_rows.h`, written by `tools/boss_rows.py` from build 26123051's EventSpawnTable, ConditionTable,
ZoneEventTable, EventTheaterTable, CharacterTable and EffectTable, lists the HP triggers of Boss and Elite spawn rows:
25 triggers on 14 rows, each with its ActorHP value, its zone event and the scene that event plays. Test, demo, NIKKE
and Boss Challenge rows are left out. 10 triggers are HP <= 1 triggers whose theater holds a QTE (`qte_rows()`), by
the exact theater alias (`QTE_THEATERS` in the tool). It also lists the 15 `LV_Dead` EffectTable rows (7000007 to
7000099) for spectate's pit rule. Another build needs the block written again from its tables.

- `Host::set_qte(on)` is on while story together runs on both sides. Story's game part publishes
  `story_together_on` (its gates open and her `on` line heard). `glue/steam.cpp` passes `story_together()` to
  `fight_pass`, which gives the job a local `qte_on` message at each change and, while on, at each new session. Off:
  no owner is named. The host logs `fight qte off ...` once.
- `Host::set_member_up(member, up)` runs each turn: 0 for the host's EVE alive (life 1 or 6), 1 for her vitals alive.
  A member in Coma is not up here, since she cannot press.
- After the turn's claims, `qte_check` names an owner once for a pair whose spawn has a QTE row and whose HP is 1 or
  less: hers when one of her claims took it there in this turn, the host otherwise. When that member is not up, the
  next member up by number takes it; with nobody up, `qte none`. It sends `SBF29 qte-own <gen> <hguid> <spawnId>
  <member> <try>` with try 0 (event `qte owner`).
- A QTE scene of that spawn that ends in the host's game with the pair alive is a miss. Story together reports the
  ended scene (`qte_ended`). The hub hands it to the job as a local `qte_end` message. The next member up after
  the owner gets the next try (255 at most) in one more `qte-own`.
- Her on or world: the whole list sends the live `qte-own` of each pair still up, after the up and fin lines.
- The worker keeps the latest `qte-own` of each spawn, sent as the host or heard as the guest
  (`fight_qte_owners()`). A world line, the host's off and the session's start or stop empty it. The `fight=` line's
  `qte=<member>:<try>` is the newest. The hub hands the list to story together, which gives each QTE scene of that
  spawn a leader ([Story together: how it works](../story/together-internals.md#boss-qte-scenes)).
- Lua tells each change of `qte=`: `fight.qte_you` for ours at try 0, `fight.qte_missed` for ours at a later try
  (unless the last owner shown was ours), `fight.qte_other` for hers.

### The HP scene hold

While our EVE spectates, a change on a boss pair that would cross one of its spawn's triggers with a scene
(`boss_rows::crosses()`) waits. On the host, that claim and every later claim of the pair stay queued in order. On
the guest, her copy keeps its HP (Shield and Stamina go on). The hold ends when our EVE is up (life 1 or 6) or 2000 ms
after it began (`kSceneHoldMs`, event `scene-held expired`). Event `scene-held` comes once a hold. While a hold runs
the host sends no hp entry for that enemy, so an ack with the old values does not take her hits back off her copy.
Exec lines and the host's dead are never held. A trigger with no scene never holds. After an expiry, a later
trigger of the same enemy holds for its own 2 s. A scene binds the player of the game that plays it, so the hold
keeps it from starting on a dead EVE. The guest's `kMaxPending` (32 claims, about 1.6 s at the full claim pace) is
below a 2 s hold: at that pace her oldest claims are forgotten. Her copy then shows a heal until the hold ends.

### Spectate

Spectate (`spectate`, each player's own, on by default, not tested in game yet) lets a player downed in a shared boss
fight watch a living member. The decisions are pure in `fight/enemies/spectate.h`, tested by
`tests/native/fight/enemies/spectate_test.cpp`. `fight/enemies/spectate_game.inc` runs them on the game thread,
`fight/enemies/spectate_worker.inc` swaps the press slot and logs. `fight/enemies/spectate.lua` moves the camera and
asks the respawn. Every address below was read in Ghidra on build 26123051.

- The death screen is HUDDead, the UI logic whose vtable reads `0x145c341e0` (its `+0x10`, `0x141619b70`, returns
  0x14, `ESBUILogicType_HUDDead`). The game thread finds it as the death path `FUN_141a6efe0` does: the client cache
  `0x1470373f8` (never through `FUN_141a987d0`, which allocates when it is 0), its `+0x48` the UI manager, whose
  `+0x10` lists its entries (the count an int at `+0x18`, walked from the last as `FUN_141fc9c40` does), each entry's
  logic at `+0x60`. It looks only while our EVE is down or the hold is ours. Its internal state is the byte at `+0xb0`:
  the event handler `FUN_141e46750` sets 0 at life 1, 4 (the Coma screen) at life 2 and 1 (the Dead screen) at life
  3; the animation end `FUN_141e46350` sets 2 after the Dead animation and 5 after the Coma one.
- The hold calls HUDDead's setter `FUN_141e46b70` with 0 (hidden) while spectate is on, our life reads 2 or 3 and the
  state is neither 0 nor 3, 8 or 9 (3 and 8: the camp respawn chosen, its fade running; 9: the Boss Challenge exit
  chosen). After any leave it calls the setter once with the game's own value: 1 at life 3, 4 at life 2, so the WB Pump
  comes back. The setter returns when `+0xb0` holds the value already. Only 3 and 8 queue its music fade, so 0, 1 and
  4 start none. The mod never writes `+0xb0` itself.
- The press filter: HUDDead's vtable slot `0x145c34250` (`+0x70`) holds the press handler `FUN_141e46860`. The worker
  swaps it to `spectate_filter` with one compare-and-swap from the handler's runtime address. It swaps it back by the
  same compare at `coop off`, at unload and after a fault. A slot that holds anything else is left as it is and logged
  (`spectate filter refused: ...`); spectate then runs without the filter. The filter reads the FName at `msg+0x28`
  and compares it with `UI_FaceButton_Left` (`0x146f52ec8`), `_Top` (`0x146f52eb8`) and `_Right` (`0x146f52ed0`), as the
  handler does. It swallows Left and Right while the state reads 2 or 5 and spectate is on or would start; Left in 5
  then starts spectate at the next step. Top (the WB Pump) always goes through. The game's handler gets every other
  press with the same arguments, as it does a press on another thread than the tick's or one after a fault or
  `coop off`. The filter never writes the message and makes no allocation, lock or log line: the worker logs the count
  (`spectate: <n> press(es) on the death screen swallowed`).
- The facts come from the fight engine on the logic thread (`SpectateFacts` in the pilot table): the boss fight on our
  side, our boss copy's death since we went down, its phase rows as a set (FNV-1a over the sorted distinct rows),
  Task 4's hold, our member number, the member alive or in Coma whose ghost stands within 100 m of our boss copy, the
  member up by her vitals at any distance, our zone's ZoneTable `+0x25` and whether an `LV_Dead` row was on our EVE
  when its life went to 3. The game thread adds our life (FSBActor `+0x2600`), the state, the setting, the pair, the
  fight running, net mode 0 and SB's MultiPlay rule row, read as `FUN_141e46750` reads it: the rule manager cache
  `0x147037410` (its `+8` the row key), the table holder cache `0x1470373b0`, then the lookup `0x141c437d0`, a thunk to
  `FUN_14bafa890`. A row whose `+0x90` is not 0 keeps the death screen shut in solo play, so spectate does not start.
- The rules are in `spectate.h`'s header. Enter at life 3, or by a swallowed Left on the Coma screen at life 2, when
  the state is not 3, 8 or 9, spectate is on, the pair is there, the fight runs with `boss=1`, a member is near, the
  zone type is not 2, 5 or 6 (training room, Boss Challenge, NIKKE), no rule row is set and the game is standalone.
  The first reason after enter counts one in `upn`: our copy died (`boss`), its phase set changed (`phase`) or Task 4
  holds a scene (`scene`). Leave with `nobody`, `ended` (`boss=0` for 10 s with no death of our copy), `link`, `off`
  or `revive` (no life change 4 s after a reason). A pause of the shared fight keeps spectate on with its clocks
  stopped. One spectate per down: after a leave, nothing enters and nothing is swallowed until our life reads 1 or 6.
- The game thread publishes spectate's state as one 64-bit atomic word (on, watched, up, upn, out, state), the only
  thing the worker reads. The worker writes ` spec=<0|1> watch=<member|-> up=<-|boss|phase|scene> upn=<n>
  her_spec=<member|-> mem=<0|1>` on the `fight=` line. The status adds ` spectate=<on|off|faulted> hud=<n|->` to the
  `engine=` line. The worker sends `SBF29 spec <member> <watched|->` at each change of the member watched and again
  after her on. It logs `spectate on: watching member <n>`, `spectate: up (<reason>), reason <n>` and `spectate off:
  <reason>, the death screen back` or `spectate off: our EVE is up`.
- The pit: once our life goes from 3 to 1 or 6 after a spectate revive with an `LV_Dead` row at the death, the engine
  makes one `relocate` (thunk `0x141a51f60`) 200 cm from her ghost toward our EVE, at her feet plus 97 cm, our capsule's
  centre (`fight pit relocate`). A camp respawn moves nobody. The point can lie over the pit when her ghost stands at
  its edge.
- The game tick steps only in game with lion_gate open (net mode 0, no logic task in flight). Its parts run under three
  SEH latches of their own (the tick, the filter, the release after a fault) and the worker's swap under a fourth. A
  fault logs `spectate fault ...: off for this run; the death screen is given back once`, gives the slot back and makes
  one guarded release in the next frame when the hold was ours. The finisher, the QTE owner and the boss pilot run
  inside the fight job, under its latch.
- `spectate test` (refused while the pair is there) holds the death screen at life 3 for 10 s, then for the respawn's
  4 s, 14 s at most or until our EVE is up, then gives 1 or 4 back.

Lua (`fight/enemies/spectate.lua`, log tag `[SP]`) reads those words each 250 ms tick:

- At `spec=1` it makes a camera actor (`core/actors.lua`, its path kept in `coop-spectate.txt` and swept at the next
  Lua load) and takes the view with a 0.5 s blend, only while `GetViewTarget()` is our EVE, so an HP scene's theater
  keeps its camera. Each frame the camera stands 400 cm from the watched ghost's feet along its own horizontal
  direction from her (the first one: from her toward our EVE), 160 cm above her feet, aimed 130 cm above them. With no
  ghost anchor (partner off, a ghost not drawn) it stands 400 cm over our EVE, looking down. At `spec=0` the view goes
  back to our EVE only from our camera. The camera's frame call runs in `main/frame.lua` right after the ghosts'.
- When `upn` rises, once, it calls `ServerRequest_ActorRespawn(me, false)` on our player controller with the checks of
  `online/group/group.lua`'s respawn (our life 2 or 3, `warp=idle`, no `nightop=rule`, the controller, a standalone
  game, our EVE); 2 s later, our life not moved, `ServerRequest_ActorRevival(me, false)` once. The 2 s stop while the
  line reads `fight=waiting`. That code is a copy of group's, with its own tests. A refused call is logged once.
- When the `engine=` line reads `spectate=faulted`, or loses its `spectate=` word (`coop off`), the view goes back to
  our EVE. With our camera on and our life 2 or 3, one respawn call follows, logged. The fault resets `upn` to 0 on
  the `fight=` line. That drop is no reason to get up, so it makes no call.
- `switch('left'|'right')` watches the previous or next member alive on our map (camera only, logged). `main/input.lua`
  calls it for the pad's `left` and `right` that no screen took, `main/keys.lua` for the Left and Right arrows when no
  menu, screen or box is open.
- The members: `mem` is ours; member 0 is the host's SteamID (`link.host()`), member 1 its pair. Outside an online
  session the other member is slot 0's. The map knows 0 and 1 only until 7b2 numbers every guest.
- The ask: `spectate on|off` when the setting changes; at load only when the `engine=` line's `spectate=` word
  disagrees with the setting (no word reads as on, the native default).

The log lines are in [players/troubleshooting.md](../players/troubleshooting.md#a-shared-boss-differs-between-the-two-games).

## Flinches and stagger resistance

Shared flinches (`hit_reactions`) and stagger resistance (`stagger_resist`) are experimental, the host's values, both
on by default and not tested in game yet (phase 8). The rules free of Windows are in
`game/poise.h`, tested by `tests/native/game/poise_test.cpp`. `game/fight/sync.h` carries the lines and runs the rules
on each side. The fight engine (`fight/enemies/engine_read.h`, `engine_write.h`) reads the game's effects and starts
them. Every address and offset below was read in Ghidra on build 26123051.

### The poise compare (Rule A)

Stellar Blade decides whether a hit staggers in `FUN_141c00f80` at 0x141c01064-0x141c010ad:
`(float)(HitLevel + (int)AdditiveHitLevel) >= HitDefenseLevel`. HitLevel is the int at SkillTable row `+0x70`.
AdditiveHitLevel is the attacker's stat 103 (FSBActor `+0x2b4`), cut toward zero by CVTTSS2SI at 0x141c0108d.
HitDefenseLevel, the poise, is the target's stat 37 (FSBActor `+0x1ac`). Both sit at `kStatBase` 0x118 plus 4 for each
stat. A missing FSBActor reads as 0 on either side. A NaN on either side gives false (COMISS, then SETNC at
0x141c010aa). `poise::level()` and `poise::passes()` copy the compare. The sum wraps as SB's ADD does. An additive
that is not finite or not within int32 gives no level.

A told reaction carries the hit's level on its cc line. The side that receives it starts the reaction at its next step
only when `passes(level, poise)` holds on its copy then. Each pass reads the copy's poise into `Seen::poise` with
`g.read` (a failed read is NaN, which refuses). A refused crowd control counts `cc_poise` and logs `cc refused` with
why `poise`. A refused flinch counts `flinch_refused`.

`Engine::reaction` reads the level on the sender's copy at the pass that sees the reaction rise: the copy found again
by GUID, then the last effect with that ID in its list. Only an effect our EVE cast gets a level. Effect `+0x60` holds
the caster's logic actor (`FUN_141bc76e0` stores its third argument there at 0x141bc771f), compared with our EVE and
never read through. The SkillTable row comes from the ID at effect `+0x88`, which is context `+0x20`: `FUN_141c00f80`
fills it with its row's `+0x10`. `FUN_141a9e920` (the repo's `skill_row`) looks the row up by that ID. The level is
the row's HitLevel plus our EVE's AdditiveHitLevel cut toward zero, held to 0 to 99. Another caster, a row ID of 0 (the
mod's own mirrored effects), no row or any failed read gives the guess, level 1 (`poise::kGuessLevel`), counted
`level_guess`. None of them latches. The reaction's life in ms comes from effect `+0x74` in every case, 10 s at most.
`poise.h` also names effect `+0x68` (context `+0x00`, which `FUN_141c00f80` fills from its skill's `+0x20`) for a level
read by skill object, which is not built (`poise::kLevelByRow`).

### The flinch mirror

HitStun (EffectTable 2003000, `kFlinch`) joins the five crowd controls of `kCcEffects` on the cc line. `Seen::cc` gives
it its own bit (`kFlinchBit`), set while the copy's effect list holds it. While `hit_reactions` is on, a flinch is told
when it rises on a copy that held no reaction at all, with Rule A's level and its life in ms. A flinch that rises inside
a crowd control is its chain and is not told. Neither is our own mirror showing up within `kEchoMs`.

The receiving side starts a flinch at its next step only:

- on a copy that holds no reaction (no flinch, no crowd control, not Down, Groggy or Airborne);
- while `hit_reactions` is on (the host's own, or as its stagger line said);
- with same place on, on a copy this side does not draw (`Io::drawn`, read from the last pilot turn's table). A drawn
  copy moves by the owner's stream, which already shows the owner's flinch. A copy the other side owns is not drawn
  while the pilot is off or stopped on this side, or while its pair is lost: it moves by its own AI;
- when Rule A passes.

Each refusal counts `flinch_refused` and logs `flinch refused` with why `held`, `off`, `drawn`, `poise` or `game` (SB
refused the call), once for each enemy and reason every 10 s (`poise::Quiet`). A received crowd control still starts on
a copy that only flinches: a knockdown cuts a flinch. A flinch line never replaces a crowd control still waiting for
its step; it is dropped and counted.

`Engine::cast` starts a mirrored flinch through the effect call `FUN_141ad1af0` with a context (below) that holds the
line's time in seconds at `+0x0c`: 200 ms gives 0.2 s. A time of 0 takes the row's own time with no context, as a
mirrored crowd control does. The hit's push-back move is a separate call in the hit code (`FUN_141ba4080`, called from
`FUN_141c00f80` at 0x141c01120 with the attacker's skill). The mirror does not make it, so a mirrored flinch plays
without push-back.

### The effect context

`effect_ctx` (`fight/enemies/fight_game.inc`) makes a fresh 16-byte-aligned 0xa0-byte buffer on the stack. SB's own
context init `FUN_141acb6f0` (`kEffectInit`, one argument) fills it: it writes its first 0x9c bytes (all but 0x89 to
0x8b) and sets `+0x0c` and `+0x10` to 0. `poise::fill_context` then writes only `+0x0c` (the life in seconds) and
`+0x10` (the value). The call is `FUN_141ad1af0(logic, target, caster, id, zero vector, 0, ctx)`. `FUN_141bc6af0`
copies the context's 0x9c bytes to effect `+0x68`. `FUN_141bc76e0` takes effect `+0x74` (context `+0x0c`) as the
life and `+0x78` (context `+0x10`) as the value, each from the row when the context holds 0. `FUN_141c00f80` builds
its hit contexts the same way: the init on a stack buffer, then its own fields.

### Poise windows (Rule B)

Each side notes for each enemy (the host's GUID) when each player slot last made its copy react (`poise::Recent`, 32
enemies, 8 slots). Slot 0 is a rise on our copy that is not our mirror's echo. Slot 1 is each of the other side's cc
lines taken at a step (started or refused) and our mirror's echo. Slots 2 to 7 stay unused until more players share
one fight. Each side forgets the other's reactions at the other side's on, off and world lines.

A rise on a copy this side moves itself (same place off, or a copy it does not draw) asks for a window while
`stagger_resist` is on, once two players or more made that enemy react within 10 s (`kRecentMs`). The game that runs the
AI decides, only at a rise on its own copy. k, the poise added, is 1 for a Monster (ActorType 3) and 2 for a BossMonster
(ActorType 4); any other type gets no window (`poise::k_for`). The window lasts the reaction's life (effect `+0x74`,
10 s at most) plus 1.5 s for each player past the first, that part 6 s at most: 16 s at most in all
(`poise::window_ms`).

`Engine::window` starts EffectTable 1001400 (AddHitDefense: HitDefenseLevel, Static, bStatRestore, IndependentTime)
on the copy, with the copy as its own caster, through `effect_ctx` with the window in seconds at `+0x0c` and k at
`+0x10`. It refuses in this order: `off` (a window SB never ended, or the latch), `running` (a window on that copy whose
check has not settled), `full` (32 running, before any game call), `gone` (not found again live), `state` (life state
not 1, or a death pending), `type` (not the ActorType that k is for) and `game` (SB refused the call). A refusal counts
`windows_refused` and logs `window refused` with its reason, once for each enemy and reason every 10 s.

With bStatRestore set (row `+0x192`), `FUN_141bcd290` records the delta the effect added at effect `+0x118` (count
`+0x120`). Its end, `FUN_141bcb980`, takes that delta back through ApplyStat (`FUN_141ba9960`). So the mod never writes
the poise. Other effects that raise the copy's poise keep their own deltas.

With same place on, the owner sends a poise line for each window it starts. A side that starts a window on a copy it
neither owns nor draws sends none. The drawing side keeps the line on its pair until its next step. It then starts the
same window on its drawn copy, through the same call, only while `stagger_resist` is on, the sender still owns the enemy
(not `Io::owns`) and the owner epoch is the line's. Otherwise the line counts as stale.

### The restore check

`Engine::restore_turn` runs each turn after the side's step. It reads SB's own effect clock, never the poise value.
The effect tick `FUN_141bc5780` adds dt times the owner's time scale (FSBActor `+0x27c4`) to effect `+0x110`. It does
not advance it while dt is 0, or while the row's byte `+0x55c` and the owner's FSBActor byte `+0x2644` are both set.
`FUN_141bc7f10` ends an IndependentTime effect once `+0x74 <= +0x110`. From 0.5 s after a
window's end on the wall clock (`kRestoreMs`), the check finds the copy again by GUID and walks its effect list for our
effect object (`poise::restore`):

- Our effect no longer listed: done. SB ended it and took its delta back, whatever the poise holds now.
- Listed with `+0x110` 0.5 s or more past `+0x74`: SB never ended it. It counts `unrestored` and logs one
  `poise not restored` line with both values. No window starts again until the game restarts.
- Listed with its clock behind (a pause, photo mode, slow motion): the check waits. 60 s after the end (`kGiveUpMs`) it
  counts as unchecked (`restore_skipped`).
- The copy not found again live, dying, out of life state 1, or a torn effect list: unchecked, with nothing more read.

None of these sets the fault latch. A world, on or off line and a new session drop every check with no count. SB still
ends each window itself.

### Lines and counters

The changed cc line and the two new lines ride channel 2, reliable, in fight pairs only (never in match lobbies, the
SBO lobby or the PvP test). They came with protocol 23, which no release used. This build sends them under protocol 29
(`SBF29`). A game on another protocol does not link with it (see
[Steam link: protocol versions](../online/steam-link-internals.md#protocol-versions)).

- `SBF29 cc <gen> <hguid> <effect> <level> <ms>`, both sides: a crowd control or a flinch that rose on the sender's
  copy, with the hit's level (0 to 99) and the reaction's time: 0 for a crowd control (its row's own), 0 to 10000 ms
  for a flinch (0: its row's own).
- `SBF29 stagger <gen> <0|1> <0|1>`, the host: its `hit_reactions` and `stagger_resist`, after its bosses line in each
  whole list while either is on, then again at each change. A recording keeps it. The guest reads both as off until
  it comes. She reads them as off again after the host's next world line.
- `SBF29 poise <gen> <hguid> <oe> <k> <ms>`, the owner of a same-place enemy: a window it started on its copy, k 1 or
  2, 1 to 16000 ms, at owner epoch oe. Never recorded.

Lua asks for both settings with the words `reactions` and `resist` after `bosses <n>` in `coop fight on` and
`coop fight record`. A change of either Options row asks `coop fight stagger <0|1> <0|1>` while shared enemies wait or
run; the worker answers `stagger: reactions <on|off>, resist <on|off>`.

Each side's `Counts` adds `cc_poise`, `level_guess`, `flinch_told`, `flinch_mirrored`, `flinch_refused`, `windows` and
`windows_refused`. The job's `JobCounts` adds `unrestored` and `restore_skipped`. The `fight=` line and the
`fight stats:` lines show them (see [Flinches and stagger resistance](enemies.md#flinches-and-stagger-resistance)).

Every game call runs inside the shared fight's job on the logic thread, under its fault latch. The reads that may fail
in an ordinary fight (the poise, the level, the restore check) go through `g.read` and never latch. No line starts
anything on a player's EVE: windows go only on ActorType 3 or 4, mirrors only on paired enemy copies.
