# Tests

The toolchain the tests need is in [Building](building.md#toolchain).

The tests run on the build machine, without the game. `tools/install.py` runs them all before every build. To run one
by hand, from the repository root:

```
lua5.4 tests/lua/partner/puppet_test.lua
python3 tests/tools/save_guard_test.py
mkdir -p build/host
c++ -std=c++17 -Wall -Wextra -Werror -I native/src tests/native/pose/codec_test.cpp -o build/host/pose_codec_test
build/host/pose_codec_test
```

## Lua tests

The Lua tests (`core/`: `actors_of`, `keybind`, `link`, `settings_file`, `ue4ss_settings`; `cut/`: `chainspin`,
`devmenu`, `emote`, `enemy`, `flight`, `gardener`, `glide`, `leviathan`, `lines`, `lion`, `mailbox`, `scene`, `tendril`,
`wear`; `main/`: `boot`, `fight`, `fight_notices`, `guide`, `input`, `menu`, `quests`, `session_ui`, `settings`;
`matrix13/quest/`: `on_time`, `zone_talks`; `matrix13/talks/`: `zones`; `matrix13/world/`: `boss`, `drone`, `fans`,
`mila`, `move`, `travel`; `nightop/`: `board`, `challenges`, `probe`, `recruiter`, `recruiter_text`, `roxanne`, `run`,
`shop`, `waves`; `partner/`: `capture`, `hud`, `puppet`, `sentinel`; `race/`: `doro`, `drive`, `drive_model`, `model`,
`run`; `session/`: `booth`, `chat`, `group`, `join`, `saves`, `travel`; `story/`: `dump`, `subtitles`; `ui/`: `guide`,
`kit`, `model`, `notice`, `region_tabs`, `text`) run the scripts, with fake UE4SS objects for those that call the
engine. In the capture test, any write to the fake EVE fails the test. The `main/` tests load `main/fixture.lua` first,
with UE4SS stubbed for `main.lua`.

- `main/fight_test` also covers `coop fight pilot` (its `test target` and boss tests included),
  `coop fight spawn probe`, the `spawn_filter` setting with the `filter` word it adds, and the `same_place`, `aggro`,
  `same_spawns`, `enemy_extra`, `bosses` and `boss_hp_scale` settings, whose rows `main/menu_test` covers with the
  `shared_quests` row;
- `main/fight_notices_test` covers the same place and same spawns notices in both languages;
- `main/quests_test` covers `coop quests` with the `shared_quests` and `quest_deny` settings and the shared quests'
  notices;
- `main/input_test` covers the controller's events from a fake `coop_pad` (routed to the menu, the co-op saves' question
  and the two boxes, never to the host's question; at most 8 a frame; an older DLL without it), the mouse in the menu
  and the focus watchdog's reset;
- `ui/kit_test` covers the menu's mouse cursor, the focus put back after a click and the focus watchdog;
- `session/chat_test` covers the Thai leading vowels at a row's end.

## C++ tests

The C++ tests cover the platform-free headers in `native/src`.

### Link

- `link_protocol_test`: the text protocol, with a fuzz loop, the requests from Lua (`coop fight` with its `place`,
  `aggro-host`, `bosses <boss %>`, `spawns`, `extra <n>` and `filter` words and its `pilot` requests, `test target`
  and the boss tests included; `lion rows`, `gardener rows`, `tendril rows`, `bolt rows`, `mxiii rows`, `shop rows`
  and `signal rows` with their 25 table words and bad addresses, the longest of them 813 bytes; `fly` and `slowmo` on
  or off; `anim play` with its id, path and `once` or `loop`, and `anim stop`; `shortcut list` and `shortcut load
  <map> <1-4>`; `nightshop`, `roxanne`, `lily` and the 8 `signal` words, in `quest/own.h`'s order), Night
  Operation's night line (its round trip, its refusals and a fuzz seed), and the join codes (both real lobby ids,
  loose typing, malformed codes, and the share of one-character typos the check turns away);
- `link_core_test`: the link against a fake Steam, and two links through it with the handshake both ways, channel 1
  and channel 2 with their checks, the photo line, the chat and vitals lines, Night Operation's night line, joining
  with a code, and the host's approval of a player who is not a Steam friend (let in, refused, no answer, removed, a
  flood while waiting);
- `link_pose_cap_test`: the adaptive pose rate (`PoseCap` in `link/core.h`), one reading a second: a calm link and
  a lone bad reading never step; two readings in a row over the line (queue time or pending bytes) step down 60, 30,
  20, to the first cap under the player's `send_rate`, never below 20; 10 calm readings step up one cap; a step up
  undone within its wait doubles the wait up to 80 s, and one that holds brings it back to 10 s;

### Poses

- `pose_engine_test`: the pose path against fake memory;
- `pose_codec_test`: the codec's round trips, the deltas against a keyframe, and a decoder fuzz;
- `pose_delta_gain_test`: what the sender's delta tolerance (`kTolerance` in `pose/codec.h`) saves. With no
  argument, as `tools/install.py` runs it, it encodes two synthetic recordings (idle and running) made by the real
  sender with no tolerance and with it, checks that the tolerance saves bytes on both and prints keyframes, deltas,
  their mean sizes and KiB/s for each. `build/host/pose_delta_gain_test path/to/coop-record.bin` measures a recording
  of the current protocol instead;
- `pose_table_test`: the component table and the display file, with a parser fuzz;
- `pose_resend_test`: our component table's resends (`TableResend` in `pose/table.h`) on a worker passing every
  50 ms: at once to a new friend, then 5, 10, 20, 40 and 60 s apart, every 60 s from then on; a change brings the
  next one 5 s after it and starts the doubling over; a sign her side lost our table brings it within 5 s, and a
  flood of them sends one each 5 s at most;
- `pose_record_test`: the recording's reader, with a fuzz, and its replay, with same-place enemies' `SBE` and show
  lines re-stamped on the poses' clock;
- `pose_stream_test`: the loopback pipeline in simulated time;

### Saves

- `save_watch_test`: the save watcher;
- `save_slot_test`: the slot line, the marker, the save file name's lookup in the game's constant table, its
  switch and the read-only probe, against fake memory;
- `save_twins_test`: the co-op save copies on a temporary folder: the game's save check, the name check on every
  write, the manifest, the backup before the first copy, torn reads and failed writes, the requests and the
  switch against a fake game, the plant of a built save as one co-op copy with its mark, and the export's refusal
  of a planted copy;
- `save_shortcut_test`: `coop shortcut`'s paths and its read of built GVAS bytes (the engine branch, `MapName`,
  `CampAlias` and `DateTime` within their maps, an EVAS header stripped, short and bad bytes), its copies, lines and
  summary;
- `save_shortcut_load_test`: `coop shortcut load`'s cleaning on built GVAS bytes (`SBAchievement` dropped, six
  gears out of `Inventory` and `ItemOtaineSet` with every size fixed, items with no row kept, a gear named anywhere
  else refused, the EVAS wrap and its CRC, the pin, cut bytes refused), then the 15 developer saves themselves when
  the machine holds the research copies under `~/.claude/project-notes/stellar-blade-minecraft/runtime/2026-10-26/`
  (skipped elsewhere): each cleaned and checked, the file without `SBAchievement` byte for byte, with no achievement
  name or gear left and no item missing from the `ItemTable` dump but the seven known ones;

### Night Operation

- `nightop_probe_test`: the Night Operation poller's reads, lines and verdict against a fake image;
- `nightop_roxanne_test`: Roxanne's and Lily's choice lists in SB's select cache (`nightop/roxanne.h`) against fake
  memory laid out like the pinned build: on (our six rows in a GMalloc array, the pointer written before the count,
  her old array never written), off (her pointer, count and max back), a second on, an element array moved by a
  rehash, an entry the game rebuilt, the refusals (no world, no holder, her list absent or of another shape, no
  memory) and the `roxanne=` line; Lily's eight rows taken in the cache's own order behind the borrowed row, a row
  twice, one of another list or one missing refused, and the `lily=` line;
- `nightop_shop_ui_test`: the Night Operation shop screen's guard (`nightop/shop_ui.h`: a client and its UI manager
  always, in game and playing for an open only), its answer word's round trip, the `nightshop=` line and the log
  lines;

### Table rows

- `lion_rows_test`: the Lion's, the Gardener's, the Tendril's, the Shock Bolt's, Matrix XIII's and the Night Operation
  shop's rows against fake memory laid out like the pinned build:
  - the recipes:
    - unique names and IDs across the batches, every patch inside its struct, the steps, skills, commands, stances,
      moves and target filters pointing at the new rows, the CharacterTable rows last with the link flag Common and the
      phase-2 stance, no value naming a Behemoth row or asset but the sound set;
    - the Gardener's ToxicBeam steps, skills, stance at speed 0 and CharacterTable rows;
    - the Tendril's skills on their run-time Shows, its Hit steps on its own areas, its stance, dead and CharacterTable
      rows;
    - the Shock Bolt's 4 rows;
    - Matrix XIII's camp, the env-spawn row that leads the travel there (the camp base) and the 6 camp objects, each
      naming the camp and spawning its blueprint at the spawn point of its own name, the third zone's camp with no coin
      and its row in `Zone_DLC02_30`, then the 5 trigger rows patched in place, in a table with no parsed arrays;
    - the shop's Beta Seed, shop items and shops;
  - a whole run of each batch:
    - each row built from its template with the game's lazy-init flag and parsed arrays reset, its ID and patches of
      every kind, AddRow given the new name;
    - the Gardener's reading only the tables its rows go into, a ProjectileTable of another row size stopping the Shock
      Bolt's batch, not the Lion's, and Matrix XIII's 10 rows from patches of their own in the two zone tables and its 5
      shipped trigger rows copied back over themselves, never added, a ZoneEnvSpawnTable or ZoneTriggerTable of another
      row size, a taken camp ID, a missing trigger row or one its ID does not name stopping that batch alone, a
      ShopTable of another row size stopping the shop's batch, not the Lion's;
    - Lily's signal's 24 quest rows (8 filters, 7 tasks, 7 groups, the two quest rows last of them) with their task
      containers and filter list built in the pool and the borrowed choice row patched in place with no ID check, a
      TheaterSelectDataTable of another row size or a taken quest ID stopping it;
  - the refusals that call no AddRow (a missing template, a taken ID or name, a wrong vtable, AddRow slot or row size);
  - a later run skipping the rows already in, FName's number split, the read-back through the game's lookups by ID, the
    answer word, the `lion=`, `gardener=`, `tendril=`, `bolt=`, `mxiii=`, `shop=` and `signal=` status lines and the log
    lines;
- `lion_shock_test`: the Shock Bolt's two lists against fake memory: both gun stances given the two fire commands
  (through the game's grow or inside the capacity), the const ammo list and the slot manager's list given
  `Bullet_Shock`, a second run writing nothing, no slot manager yet, the key found down its hash chain, each refusal
  writing nothing, an allocation that fails, the answer word, the `shock=` line and the log line;

### Shared enemies

- `fight_engine_test`: the shared enemies' side inside the game, the enemies `fight_chars=auto` picks and leaves out,
  the enemies' state map, the two-player scaling, the vitals read, and same-place enemies' freeze (BlockAI put back
  after the game's own dispel, freeze-lost after 5 tries in any 10 s, none in the turn we start a crowd control, taken
  off before a kill and on every way out, none of ours on a copy the game froze first until the game's freeze ends by
  its dispel or a timed row running out, a refused dispel tried again and its copy not taken later for one the game
  froze, a floor that keeps a killed copy alive frozen again from the next turn, a copy the game thread would not drive
  let go the same way) with the pair table for the game thread, the rows it captures (only those the side owns and does
  not draw), the rows it drives (only those it draws) and how it reads the table (fresh for 1 s after the job published
  it and never once the engine is latched; the Shows told so far are told again only after a new session, a new
  generation or a change of the table's on, not after a stale table), against fake memory.
  - Same place is the host's setting: the guest draws only while the host's last place line says on, and never reads her
    own;
  - `coop fight pilot off` and the pilot's latch stop it on either side (the host then sends place 0), and the worker's
    `pilot=` words say why it does not run (on the guest's side, `host` only once the host's list came, `fight` after
    its off or on line);
  - stage 3b's hand-overs on both sides (the host's rule and its own lines, its freeze and thaw, her answers and
    give-backs with each own-no reason, no hand-over to a side whose copy the game froze first but for her takedown,
    `target` for a take-over her game thread refused, a pair kept from her for 30 s after her own-no about it, the
    table's taken mark only after a hand-over) and in two worlds, where an enemy has no AI copy or two for one hop at
    most;
  - stage 3c's takedowns (her exec lines from the markers, exec 0 after 200 ms without one, the host's hand-over past
    the guards once its copy is kReady and its freeze despite Groggy, the host's own takedown, a BossMonster refused, a
    balance emptied by her claim in the turn of her exec 1, her lethal claim held until her exec 0 or for 6 s, a copy
    frozen on its stream's takedown, `coop fight pilot test exec`) and in two worlds, where her takedown holds the
    host's kill until her exec 0 reaches it;
  - same spawns in two worlds: nothing while the host's `same_spawns` is off or the players stand 200 m apart, then her
    set becomes the host's (keys created where the host's stand and paired, keys the host lacks despawned, save, keep,
    event and other-zone keys left, a Monster outside `fight_chars` never sent, nothing killed), a spawn line of an old
    epoch dropped after the host's zone resets, a drop line ignored for a key paired on her side, nothing done while a
    census's list of keys is partial, and a Save row logged once, with keys that have no row kept out of the 512-row
    cache and rows past it never logged;
  - the two game calls on fake memory (the spawn with the spawn manager, the key, where the host's enemy stands and its
    yaw; the despawn with the job sender, the turn and the GUID), none with no spawn manager, job sender or reg made, no
    despawn while her enemy holds BattleMode or runs a takedown marker (then one once she is done), and no call, line or
    log line after a latch on an unreadable row, and a host enemy of a SaveWithTransform row never sent;
  - the read-only spawn probe (each shared Monster's row told once an epoch, 32 a census at most, nothing sent or
    called);
  - the `fight=` line's `spawns=` field;
  - extra enemies in two worlds with `enemy_extra=2` (two `NewActor` calls for each of the host's four enemies, 2 and
    3 m from it, the same keys made on her side where the host's stand, all twelve paired, one 130 m from both EVEs
    despawned on the host and then by a drop on hers, the rest despawned at the end, hers when the host's off line
    comes, nothing killed), and on the host alone (no extras for a BossMonster, an NPC, a ZoneEvent or Quest spawn or a
    charId not shared, none before the zone is settled or while she stands 200 m away, an extra 105 m from her ghost
    kept, a dying one left and the other despawned when her shared enemies stop, extras off when the tables hold a row
    at the first key, `NewActor` refusing or the reg not made logged once a life, an extra whose GUID cannot be read
    logged as kept, a new session's extras under the next n);
  - the `extra` word reaching the stats line;
  - shared bosses (BossMonsters taken by `fight_chars=auto` only with bosses on, on the guest once the host's bosses
    line came; their MaxHP times `boss_hp_scale` once and back at off; a boss never handed to her; in two worlds with
    same spawns on, a boss both saves hold paired and scaled in both, one only the host's save holds left unpaired, one
    only hers left hers, none created or removed);
  - her boss copies taken out of battle mode (after 10 s of the host's lines with no bstart, a 15 s silence of the
    host's not counted, at the host's down, at her own same place off and at the session's end, a dying one left alone;
    a new copy paired in the turn its pair's old one went keeps its boss start);
  - the `bosses` word through a recording and its replay;
  - and the boss tests of `coop fight pilot test` on the nearest frozen boss copy (SetBattleMode once a copy and no
    BattleMode_5s on boss copies from the next session, a phase line and the threshold's dispel 5 s later, the copy held
    at 1 HP with no claim and the host's HP back after 10 s, or its HP from the start when the test stops early, a
    summon made, frozen and frozen again, then removed as unpaired, or at once when the freeze is refused; one test at a
    time, none left after the session ends);
  - Night Operation's wave monsters, taken like any keyed Monster, and paired by their keys in two worlds, where the
    host's kill reaches her copy only when she took part;
  - and the spawn filter's table in two worlds (her blocked keys published while she filters, refused by a fake hook on
    her reset, nothing published without the filter or on the host's side, a key the host spawns again let through, the
    host's dead on her paired copy blocking its key but not her own lethal hit, the table empty at a new session, at the
    host's off and at the end, and the gate);
- `fight_sync_test`:
  - the shared enemies' channel 2 text (with a fuzz),
  - the host's and the guest's rules (the place line sent after the world and at each change, and held by the guest
    until the host's next world; the aggro, own and own-no lines taken from the right side only; the bosses line after
    the aggro line, held the same way; boss pairs first in the 16 places, a common enemy's place taken by a boss (not
    while its kill or her takedown is under way) and never the other way; the exec line's checks, rate and holds of a
    kill and of a dead, an exec 1 that never restarts a running takedown, a held claim's 6 s cap, a balance emptied by
    her claim in the step of her exec 1, refusals within 2 s counted with no line; same spawns' epoch, have, spawn and
    drop lines refused by Host and Guest, since the engine takes them, and never recorded),
  - the boss table of stage 5 (one row a boss, each row's allowlist sent in a phase line and read back the same, the
    rows two bosses' shared step applies kept apart, the summon rows),
  - the bstart, phase and summon spawn lines with a fuzz,
  - the guest's checks of them (one bstart a copy, taken again by a new copy under the same key or on a repeat after the
    pair forms, phase IDs from that boss's allowlist only, a summon's key, row, charId and owner),
  - and two fake worlds linked through a delayed, lossy line;
- `spawn_sync_test`: the core of same spawns (stage 4):
  - which rows take part,
  - each side's epoch (a zone change, a reset of the spawn manager, 3 or more keys with a new GUID, two actors of one
    key no change) and its 3 s grace,
  - the host's epoch line (at each change and every 5 s),
  - her rounds and its answers (a key more than 1 km from her held back until she is nearer),
  - the guest's rounds and her checks of each answer (the epoch, the shared zone, her own tables, 1 km, the rates, a
    created key that is no Monster or another charId, removed again within the rates or kept and logged when it cannot
    be found again, a drop of an enemy she fights refused as busy and asked again, the refusals that show the two games
    differ counted apart),
  - a key refused as too far asked again,
  - a created key that died leaving her rounds,
  - extra enemies (their keys and places, which enemies get them, none for a Save or keep row, an Elite or an enemy past
    116 m, once a life, the room left and stage 1's 16 pairs, n going on after a new session, the host's answers and her
    checks for extra keys, `row taken`, a charId none of her Monsters has yet or a `full` refusal asked again,
    `not made` counted as no difference; their keys below the summons' range, and a summon's key never made by same
    spawns),
  - the guest's blocked keys for the spawn filter (a drop she despawned, the host's kill of a paired copy, never an
    extra's key, a spawn line of the host's epoch taking a key off before her spawn, cleared at a new host epoch and by
    `clear()`, kept through her own epoch moves, 240 at most),
  - and two fake worlds through a delayed line until her set is the host's, with an epoch that moves while a round is on
    the way;
- `pilot_test`: the core of same-place enemies (stages 3a to 3c):
  - the SBE message with a fuzz, the gen and owner epoch filters, an enemy's samples drawn on the ghost's own clock
    (150 ms extrapolation cap, warp, hole and 3 m snaps, a velocity of 100 m/s at most), the drawn copy's states with
    the 2 m convergence snap, the capture list's restore order;
  - the show lines with a fuzz and the Show paths they refuse (outside the roots, over 200 characters, a character
    outside `A-Za-z0-9_./`, `..` or an empty segment), their timeline and line ids, the FNamePool decode and compact id
    over fake blocks;
  - the owner's capture against fake memory:
    - each enemy found through the game's two lookups by GUID, its root, flags and animation speed into SBE;
    - the show manager's stages matched by their main actor's weak pointer, a stale one refused, an empty one matched by
      the actor's show interface;
    - only the first player of a stage, a finished one never told;
    - show-set and show-stop;
    - each asset's path decoded once, and again when another asset takes its address and index under another name or
      package;
    - a character pending kill, a failed lookup, a wrong class, no world, no show manager or a logic task in flight;
  - the drawn side's writes against fake memory:
    - each copy found by its GUID every frame and skipped while it is not or while a logic task is in flight, its rows
      then kept for a later frame;
    - its movement component taken out of the game's parallel manager only when it is the game's class with the game's
      own function in slot 0x350, and again when something put it back;
    - the speed override, the root moved through its vtable and Velocity;
    - the drift probe;
    - the Show replayed through the handle API with its hit context (each field at its offset), only on a copy driven
      that frame, show-set and show-stop (also while the copy is not found), a missing asset, a context too far away,
      the oldest replay giving way when eight are held, at most 2 AddShow calls a frame and 60 a second, the lines
      behind waiting in order (late once more than 34 ms past their stamp);
    - a Show the copy started itself less than 1 s before not replayed again, unlike another enemy's, an older one, a
      finished one or one of its own replays;
    - a release;
    - a log line per release, convergence and snap;
    - restore's order on every way back, with Velocity zeroed and the class checked again before the component goes
      back, once after a fault and nothing after it;
    - `coop fight pilot test`'s steps, each copy put back once at a change and driven only from the next frame;
  - stage 3b's owners (the host's rule, its guards and hold, random hand-overs over a delayed link, the 30 s pause after
    an own-no);
  - stage 3c's takedowns (the rule giving a pair to its executor at once, the guest's exec lines, their spacing and the
    200 ms wait before exec 0, a drawn copy following the stream through a takedown) and the take-over (the copy put
    back first, then the game's force target, only on a pair a hand-over brought; its net mode and logic task gates, a
    stale or missing copy, the refusals named for the job's own-no, the latch, `coop fight pilot test target`);
  - and two worlds through a delayed, lossy line (120 ms, plus or minus 30, 2 % lost), where the guest's copies stay
    within 30 cm of the host's enemies at the same host time while they move (an 8 m/s lunge to a dead stop included)
    and 5 cm at rest, the show lines apply in the host's order with no Show held back by those two caps, and restore
    puts every copy back to local, with its CMC back in SB's movement manager and the speed override gone;

### Other native headers

- `photo_freeze_test`: the synced photo mode's pause against a fake pause set;
- `globals_test`: SB's globals as build 26123051 lays them out, checked at compile time: the block offsets the fight
  engine, the photo freeze, the lion gate and the Night Operation probe read land on the registry, the world, logic
  and the net-mode cache, and every header that names one of these globals by address names the same one;
- `debug_keys_test`: `coop fly`'s and `coop slowmo`'s gates against fake memory laid out like the pinned build: the
  keys' hash, the lookup through inline and allocated buckets and along a chain of collisions, each refusal with no
  write, and the passes (a gate set with its old value kept, set again after the game built its map again, its old
  value back once unwanted, nothing read while neither gate is wanted or ours); the worker's side: no gate wanted off
  a co-op save, slow motion only with no friend linked, the asks cleared by `off`, a Lua load and a refusal, and a
  gate's state logged from the first pass that read its ask, never from an earlier one; the level flight's hold: the
  flight key set again only while the controller's pawn flies with none held, never after a press of the jump key
  in that flight until it ends (a jump key held from before the flight counts only once let go and pressed again);
- `anim_test`: `coop emote`'s native clips: the clip paths that pass, the game's string built from one, the call's
  arguments, the custom animation slot as read, and the track (a play answered with or without an id, the watch on
  our clip, another clip, a cleared slot, a gone EVE and a slot that takes no weight, with paused time left out,
  the stops, the fault, the status word and the log lines), our EVE as the controller's pawn and the check that she
  is still the object played on, over fake memory (no pawn, a pawn of another class, a pending kill, a new serial),
  and what each frame does;
- `items_test`: `coop gift`'s inventory read against a fake image laid out like the pinned build: the FName and
  CityHash64 hashes checked against the game's, a count over two instances and along chains of collisions, an item
  EVE does not carry, no manager, bucket or owner, an instance the manager no longer holds, and hostile memory (a
  chain that loops, an index past the array, a hash size that is no power of two, an unreadable item) ending in
  `unread`, never in a hang;
- `pad_test`: the controller's events for the co-op menu (each press, up and down repeating while held, a D-pad
  diagonal read as up or down and the stick along its main axis, which keeps its pressed axis near 45 degrees, the
  stick's thresholds, View held 1 s, a disconnect,
  the event queue) and which XInput slots each poll asks;
- `dev_panels_test`: `coop devinfo`'s guard (each read failing alone, refused with its own reason; a close needs
  neither the flow nor the phase), the plan over every mix of open panels and every ask (the other panel closes, the
  one asked opens unless it is open), and the two panels' logic types and names;
- `travel_test`: the follow's fast travel request, its bytes at each offset, each guard refusing with its own reason
  (a respawn in flight included), the call count (three calls in 10 s, a 10 s wait after an accepted call, none after
  a refused one) and the watch over the warp block (pending, warping, arrived, a block cleared before it ran, and one
  that never ran: stuck);
- `region_tabs_test`: the teleport screen's record list: the sanity check, the name lookup, the append.
- `camp_text_test`: Matrix XIII's camp names and the 25 records' words, the keys (unique, the region's ending in a
  letter), the language pick, when a pass is due and the `camptext=` and `recordtext=` lines;
- `camps_test`: the activated camps' read, each guard refusing with its own reason (a warp, a respawn or a logic
  task as busy), when the list is read (at once with none held, in a new world or after a drop, then every 2 s) and
  the `activated=` line (the list, the camp EVE respawns at, a refusal, names that would not split left out);
- `pak_list_test`: the `.pak` mod list's filter and digest (the base game's files left out, mods in any folder and
  any case counted, the listing's order and a name's case changing nothing, a size or a name changing the hash), the
  containers by name, the names as they go to the friend, hers against ours, the status list, and the CNS packs
  under `~mods` with their outfits and the `/Game` assets they declare (comments, other keys and a text cut short
  included), a `.utoc` directory index read into object paths (maps, other roots, encrypted, unindexed, cut short
  and looped indexes refused) and the shared list of containers both players have;

### Quests

- `quest_sync_test`: the shared quests' quest table, line format and parser (with a fuzz), the host's and the guest's
  rules, the zone marks, the steps made together and those that are not, the record file, and lost lines and
  reloads;
- `quest_engine_test`: the shared quests against a fake quest unit: the walk, the guards before each game call, the
  gate, a fault, two PCs through channel 2's text with delay and loss, a recording replayed into another save, and
  the worker's side (the gates that start and end a side, channel 2's lines beside the fight's, the record file and
  the status lines);
- `quest_own_test`: the mod's own quests in a fake quest unit (`quest/own.h`): nothing read off a co-op save, on SB's
  logic thread or before the world and the manager exist; the ID map through its inline and heap bits; the prologue
  and Quest_Epic_11 read beside "On Time"; each request word's one call (an acquire once, never when held; a first
  task's Complete only at that word's group with its task in progress, through SB's Complete and no other address);
  the answer word (every field through it, a value out of its 4 bits read as -1) and the `signalquest=` line.

## Python tests

- `save_guard_test.py`: `tools/save_guard.py`, its `slot` command included, on temporary folders;
- `story_test.py`: `tools/story.py` and `tools/gvas.py`, the story lines and digest of a built save, and the
  fixture `story/dump_test` reads, against the tool's own sample;
- `install_test.py`: `tools/install.py`'s install, backup, uninstall and zip, on a fake game folder;
- `mxiii_rows_test.py`: `tools/mxiii_rows.py`'s two outputs match `data/mxiii-world.json`, its checks refuse bad rows,
  and the data holds the camps, bosses and mechanism rows the cooked map expects, with no warp switch left and the
  names of every new door, EnvC and ZoneEvent row chained. After a change to the data file, run
  `python3 tools/mxiii_rows.py` and commit the two files it writes;
- `matchmaking_scan_test.py`: a scan that fails if any script or native source could reach the game's matchmaking
  (see [night-operation-previews.md](night-operation-previews.md#how-the-original-matchmaking-is-blocked));
- `release_test.py`: `tools/release.py`'s build, upload and publish steps and its refusals, with git, gh and
  `tools/install.py` faked.
