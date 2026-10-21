# Building from source

StellarCoop is developed on Linux. The Lua scripts need no build, and the Windows DLL is cross-compiled with clang-cl.
For the design, see [how-it-works.md](how-it-works.md).

## Toolchain

- Python 3 and Git.
- Lua 5.4 (`lua5.4`), the version the game's UE4SS embeds, for the Lua tests.
- A host C++17 compiler (`c++`) for the native tests. If it can build and run binaries with AddressSanitizer and
  UndefinedBehaviorSanitizer, the native tests use both.
- CMake 3.20 or newer and Ninja.
- clang-cl with [xwin](https://github.com/Jake-Shadle/xwin)'s Windows SDK and MSVC CRT, through a CMake toolchain file:
  `~/.local/share/xwin/clang-cl-msvc.cmake` by default, or the path in the `STELLAR_WINDOWS_TOOLCHAIN` environment
  variable.
- `wine` from a Proton build, for the Wine smoke test only.

The CMake project in `native/` builds one target, `StellarCoop.dll`, with the C++ runtime linked statically, so there
is no runtime DLL to ship.

## tools/install.py

`tools/install.py` runs every check, builds the DLL and copies the mod into
`<game>/SB/Binaries/Win64/ue4ss/Mods/StellarCoop`. It refuses while the game runs.

```
python3 tools/install.py [--game <Stellar Blade folder>] [--dry-run | --zip [PATH] | --uninstall]
```

| Option | What it does |
| --- | --- |
| (none) | Runs the tests, builds the DLL and installs the mod |
| `--game <folder>` | The Stellar Blade folder (the default points at one particular Steam library; see `--help`) |
| `--dry-run` | Runs the tests and the build, then says what an install would back up, remove and write, and changes nothing |
| `--zip [PATH]` | Runs the tests and the build, then writes a release zip (by default `build/StellarCoop-<version>.zip`) instead of installing. Needs a clean tree; no game folder needed |
| `--uninstall` | Backs up the installed folder, then removes it. No tests and no build; with `--dry-run` it changes nothing |

Except with `--zip`, the game's UE4SS `Mods` folder must exist.

A run does these steps in order:

1. runs the Lua tests (`tests/*_test.lua`), the Python tests (`tests/*_test.py`) and the native tests
   (`tests/*_test.cpp`, built and run on this machine);
2. configures and builds the DLL in `build/windows` with the clang-cl toolchain, and writes the version
   (`git describe`) into it;
3. installs, writes a dry-run report, or writes the zip.

An install puts into the mod folder the scripts, `enabled.txt`, `StellarCoop.dll`, `Scripts/version.lua` (the
version) and `install-manifest.txt` (the list of installed files). Before that, it backs up the files it replaces or
removes into `~/StellarCoop-install-backups/<UTC time>/StellarCoop`. The backups go outside the game folder because
UE4SS would load a copy under `Mods`. Backups are never pruned. Files that the previous install shipped and this one
does not are removed. Files the mod writes in game (its logs, status files and settings) are never removed.

`--uninstall` backs up the whole folder (logs and `coop-settings.txt` included) into the same backup folder, then
removes it. It does not touch a folder without `install-manifest.txt` (one copied from the zip) or a symbolic link. It
never touches saves, `StellarCoopSlot.txt` or `mods.txt`, and it reports any `mods.txt` line that still names
StellarCoop.

The release zip from `--zip` holds the mod folder with `INSTALL.md`, `LICENSE`, a `CHANGELOG.md` and a
`SHA256SUMS.txt` over every other file. It never holds `coop-settings.txt`. `CHANGELOG.md` is generated for the zip
and never committed. Commit subjects follow Conventional Commits. The changelog lists the `feat` and `fix` subjects
only, newest first, with their scope; a `!` marks a breaking change.

## Tests

The tests run on the build machine, without the game. `tools/install.py` runs them all before every build. To run one
by hand, from the repository root:

```
lua5.4 tests/puppet_test.lua
python3 tests/save_guard_test.py
mkdir -p build/host
c++ -std=c++17 -Wall -Wextra -Werror -I native/src tests/pose_codec_test.cpp -o build/host/pose_codec_test
build/host/pose_codec_test
```

- Lua tests (`capture`, `chat`, `join`, `keybind`, `link`, `main`, `nightop`, `nightop_run`, `nightop_shop`,
  `nightop_waves`, `notice`, `partner`, `puppet`, `recruiter`, `recruiter_text`, `saves`, `settings_file`, `ui`,
  `ui_kit`, `ui_model`, `ui_text`)
  run the scripts, with fake UE4SS objects for those that call the engine. In the capture test, any write to the fake
  EVE fails the test. `main_test` also covers `coop fight pilot` (its `test target` and boss tests included), the
  `same_place` and `aggro` settings and rows, the `same_spawns`, `enemy_extra`, `bosses` and `boss_hp_scale` settings
  and rows, `coop fight spawn probe`, the same place and same spawns notices in both languages, and `coop quests` with
  the `shared_quests` and `quest_deny` settings, the menu's row and the shared quests' notices.
- C++ tests cover the platform-free headers in `native/src`:
  - `link_protocol_test`: the text protocol, with a fuzz loop, the requests from Lua (`coop fight` with its `place`,
    `aggro-host`, `bosses <boss %>`, `spawns` and `extra <n>` words and its `pilot` requests, `test target` and the boss
    tests included),
    and the join codes (both real lobby ids, loose typing, malformed codes, and the share of one-character typos the
    check turns away);
  - `link_core_test`: the link against a fake Steam, and two links through it with the handshake both ways, channel 1
    and channel 2 with their checks, the photo line, the chat and vitals lines, Night Operation's night line, joining
    with a code, and the host's approval of a player who is not a Steam friend (let in, refused, no answer, removed, a
    flood while waiting);
  - `pose_engine_test`: the pose path against fake memory;
  - `pose_codec_test`: the codec's round trips, the deltas against a keyframe, and a decoder fuzz;
  - `pose_table_test`: the component table and the display file, with a parser fuzz;
  - `pose_record_test`: the recording's reader, with a fuzz, and its replay, with same-place enemies' `SBE` and show
    lines re-stamped on the poses' clock;
  - `pose_stream_test`: the loopback pipeline in simulated time;
  - `save_watch_test`: the save watcher;
  - `save_slot_test`: the slot line, the marker, the save file name's lookup in the game's constant table, its
    switch and the read-only probe, against fake memory;
  - `save_twins_test`: the co-op save copies on a temporary folder: the game's save check, the name check on every
    write, the manifest, the backup before the first copy, torn reads and failed writes, and the requests and the
    switch against a fake game;
  - `nightop_probe_test`: the Night Operation poller's reads, lines and verdict against a fake image;
  - `fight_engine_test`: the shared enemies' side inside the game, the enemies `fight_chars=auto` picks and leaves out,
    the enemies' state map, the two-player scaling, the vitals read, and same-place enemies' freeze (BlockAI put back
    after the game's own dispel, freeze-lost after 5 tries in any 10 s, none in the turn we start a crowd control, taken
    off before a kill and on every way out, none of ours on a copy the game froze first until the game's freeze ends by
    its dispel or a timed row running out, a refused dispel tried again and its copy not taken later for one the game
    froze, a floor that keeps a killed copy alive frozen again from the next turn, a copy the game thread would not
    drive let go the same way) with the pair table for the game thread, the rows it captures (only those the side owns
    and does not draw), the rows it drives (only those it draws) and how it reads the table (fresh for 1 s after the job
    published it and never once the engine is latched; the Shows told so far are told again only after a new session, a
    new generation or a change of the table's on, not after a stale table), against fake memory. Same place is the
    host's setting: the guest draws only while the host's last place line says on, and never reads her own; `coop fight
    pilot off` and the pilot's latch stop it on either side (the host then sends place 0), and the worker's `pilot=`
    words say why it does not run (on the guest's side, `host` only once the host's list came, `fight` after its off or
    on line); stage 3b's hand-overs on both sides (the host's rule and its own lines, its freeze and thaw, her answers
    and give-backs with each own-no reason, no hand-over to a side whose copy the game froze first but for her takedown,
    `target` for a take-over her game thread refused, a pair kept from her for 30 s after her own-no about it, the
    table's taken mark only after a hand-over) and in two worlds, where an enemy has no AI copy or two for one hop at
    most; stage 3c's takedowns (her exec lines from the markers, exec 0 after 200 ms without one, the host's hand-over
    past the guards once its copy is kReady and its freeze despite Groggy, the host's own takedown, a BossMonster
    refused, a balance emptied by her claim in the turn of her exec 1, her lethal claim held until her exec 0 or for 6
    s, a copy frozen on its stream's takedown, `coop fight pilot test exec`) and in two worlds, where her takedown holds
    the host's kill until her exec 0 reaches it; same spawns in two worlds: nothing while the host's `same_spawns` is
    off or the players stand 200 m apart, then her set becomes the host's (keys created where the host's stand and
    paired, keys the host lacks despawned, save, keep, event and other-zone keys left, a Monster outside `fight_chars`
    never sent, nothing killed), a spawn line of an old epoch dropped after the host's zone resets, a drop line ignored
    for a key paired on her side, nothing done while a census's list of keys is partial, and a Save row logged once,
    with keys that have no row kept out of the 512-row cache and rows past it never logged; the two game calls on fake
    memory (the spawn with the spawn manager, the key, where the host's enemy stands and its yaw; the despawn with the
    job sender, the turn and the GUID), none with no spawn manager, job sender or reg made, no despawn while her enemy
    holds BattleMode or runs a takedown marker (then one once she is done), and no call, line or log line after a latch
    on an unreadable row, and a host enemy of a SaveWithTransform row never sent; the read-only spawn probe (each shared
    Monster's row told once an epoch, 32 a census at most, nothing sent or called); the `fight=` line's `spawns=` field;
    extra enemies in two worlds with `enemy_extra=2` (two `NewActor` calls for each of the host's four enemies, 2 and 3
    m from it, the same keys made on her side where the host's stand, all twelve paired, one 130 m from both EVEs
    despawned on the host and then by a drop on hers, the rest despawned at the end, hers when the host's off line
    comes, nothing killed), and on the host alone (no extras for a BossMonster, an NPC, a ZoneEvent or Quest spawn or a
    charId not shared, none before the zone is settled or while she stands 200 m away, an extra 105 m from her ghost
    kept, a dying one left and the other despawned when her shared enemies stop, extras off when the tables hold a row
    at the first key, `NewActor` refusing or the reg not made logged once a life, an extra whose GUID cannot be read
    logged as kept, a new session's extras under the next n); the `extra` word reaching the stats line; shared bosses
    (BossMonsters taken by `fight_chars=auto` only with bosses on, on the guest once the host's bosses line came; their
    MaxHP times `boss_hp_scale` once and back at off; a boss never handed to her; in two worlds with same spawns on, a
    boss both saves hold paired and scaled in both, one only the host's save holds left unpaired, one only hers left
    hers, none created or removed), her boss copies taken out of battle mode (after 10 s of the host's lines with no
    bstart, a 15 s silence of the host's not counted, at the host's down, at her own same place off and at the session's
    end, a dying one left alone; a new copy paired in the turn its pair's old one went keeps its boss start), the
    `bosses` word through a recording and its replay, and the boss tests of `coop fight pilot test` on the nearest
    frozen boss copy (SetBattleMode once a copy and no BattleMode_5s on boss copies from the next session, a phase line
    and the threshold's dispel 5 s later, the copy held at 1 HP with no claim and the host's HP back after 10 s, or its
    HP from the start when the test stops early, a summon made, frozen and frozen again, then removed as unpaired, or at
    once when the freeze is refused; one test at a time, none left after the session ends);
  - `fight_sync_test`: the shared enemies' channel 2 text (with a fuzz), the host's and the guest's rules (the place
    line sent after the world and at each change, and held by the guest until the host's next world; the aggro, own
    and own-no lines taken from the right side only; the bosses line after the aggro line, held the same way; boss
    pairs first in the 16 places, a common enemy's place taken by a boss (not while its kill or her takedown is under
    way) and never the other way; the exec line's checks, rate and holds of a kill and of a dead, an exec 1 that never
    restarts a running takedown, a held claim's 6 s
    cap, a balance emptied by her claim in the step of her exec 1, refusals within 2 s counted with no line; same
    spawns' epoch, have, spawn and drop lines refused by Host and Guest, since the engine takes them, and never
    recorded), the boss table of stage 5 (one row a
    boss, each row's allowlist sent in a phase line and read back the same, the rows two bosses' shared step applies
    kept apart, the summon rows), the bstart, phase and summon spawn lines with a fuzz, the guest's checks of them (one
    bstart a copy, taken again by a new copy under the same key or on a repeat after the pair forms, phase IDs from that
    boss's allowlist only, a summon's key, row, charId and owner), and two fake worlds linked through a delayed, lossy
    line;
  - `spawn_sync_test`: the core of same spawns (stage 4): which rows take part, each side's epoch (a zone change, a
    reset of the spawn manager, 3 or more keys with a new GUID, two actors of one key no change) and its 3 s grace, the
    host's epoch line (at each change and every 5 s), her rounds and its answers (a key more than 1 km from her held
    back until she is nearer), the guest's rounds and her checks of each answer (the epoch, the shared zone, her own
    tables, 1 km, the rates, a created key that is no Monster or another charId, removed again within the rates or kept
    and logged when it cannot be found again, a drop of an enemy she fights refused as busy and asked again, the
    refusals that show the two games differ counted apart), a key refused as too far asked again, a created key that
    died leaving her rounds, extra enemies (their keys and places, which enemies get them, none for a Save or keep
    row, an Elite or an enemy past 116 m, once a life, the room left and stage 1's 16 pairs, n going on after a new
    session, the host's answers and her checks for extra keys, `row taken`, a charId none of her Monsters has yet or a
    `full` refusal asked again, `not made` counted as no difference; their keys below the summons' range, and a
    summon's key never made by same spawns), and two fake worlds through a delayed line until her set is the host's,
    with an epoch that moves while a round is on the way;
  - `pilot_test`: the core of same-place enemies (stages 3a to 3c): the SBE message with a fuzz, the gen and owner epoch
    filters, an enemy's samples drawn on the ghost's own clock (150 ms extrapolation cap, warp, hole and 3 m snaps), the
    drawn copy's states with the 2 m convergence snap, the capture list's restore order, the show lines with a fuzz,
    their timeline and line ids, the FNamePool decode and compact id over fake blocks, the
    owner's capture against fake memory (each enemy found through the game's two lookups by GUID, its root, flags and
    animation speed into SBE; the show manager's stages matched by their main actor's weak pointer, a stale one refused,
    an empty one matched by the actor's show interface; only the first player of a stage, a finished one never told;
    show-set and show-stop; each asset's path decoded once, and again when another asset takes its address and index
    under another name or package; a character pending kill, a failed lookup, a wrong class, no world or no show
    manager), the drawn side's writes against fake memory (each copy found by its GUID every frame and skipped while
    it is not; its movement component taken out of the game's parallel manager only when it is the game's class with
    the game's own function in slot 0x350, and again when something put it back; the speed override, the root moved
    through its vtable and Velocity; the drift probe; the Show replayed through the handle API with its hit context
    (each field at its offset), only on a copy driven that frame, show-set and show-stop (also while the copy is not
    found), a missing asset, a context too far away, the oldest replay giving way when eight are held; a Show the copy
    started itself less than 1 s before not replayed again, unlike another enemy's, an older one, a finished one or
    one of its own replays; a release; a log line per release, convergence and snap;
    restore's order on every way back, with Velocity zeroed and the class checked again before the component goes
    back, once after a fault and nothing after it; `coop fight pilot test`'s steps, each copy put back once at a
    change and driven only from the next frame); stage 3b's owners (the host's rule, its guards and hold, random
    hand-overs over a delayed link, the 30 s pause after an own-no), stage 3c's takedowns (the rule giving a pair to its
    executor at once, the guest's exec lines, their spacing and the 200 ms wait before exec 0, a drawn copy following
    the stream through a takedown)
    and the take-over (the copy put back first, then
    the game's force target, only on a pair a hand-over brought; its net mode and logic task gates, a stale or missing
    copy, the refusals named for the job's own-no, the latch, `coop fight pilot test
    target`), and two worlds through a delayed, lossy line (120 ms, plus or minus
    30, 2 % lost), where the guest's copies stay within 30 cm of the host's enemies at the same host time while they
    move (an 8 m/s lunge to a dead stop included) and 5 cm at rest, the show lines apply in the host's order, and
    restore puts every copy back to local, with its CMC back in SB's movement manager and the speed override gone;
  - `photo_freeze_test`: the synced photo mode's pause against a fake pause set;
  - `quest_sync_test`: the shared quests' quest table, line format and parser (with a fuzz), the host's and the guest's
    rules, the zone marks, the steps made together and those that are not, the record file, and lost lines and
    reloads;
  - `quest_engine_test`: the shared quests against a fake quest unit: the walk, the guards before each game call, the
    gate, a fault, two PCs through channel 2's text with delay and loss, a recording replayed into another save, and
    the worker's side (the gates that start and end a side, channel 2's lines beside the fight's, the record file and
    the status lines).
- Python tests:
  - `save_guard_test.py`: `tools/save_guard.py`, its `slot` command included, on temporary folders;
  - `install_test.py`: `tools/install.py`'s install, backup, uninstall and zip, on a fake game folder;
  - `matchmaking_scan_test.py`: a scan that fails if any script or native source could reach the game's matchmaking
    (see [night-operation.md](night-operation.md#how-the-original-matchmaking-is-blocked)).

## tools/wine_smoke.py

`tools/wine_smoke.py` builds `StellarCoop.dll` exactly as the installer does, builds `tests/wine/smoke.cpp`, and loads
the DLL under Proton's `wine` in a scratch prefix with no `steam_api64.dll` present. It checks that the DLL attaches,
waits for Steam, answers `coop_tick`, refuses the engine, the Night Operation poller, the save name's probe,
`saves coop` and same-place enemies (`pilot=refused` in `coop-status.txt`, and a refused `coop fight pilot test`) on an
exe that is not the game, takes `coop fight pilot off` there, logs `save name: saves=off` once, and logs a clean process
exit. It also checks that `ReadProcessMemory` behaves as the poller needs, that the chat files an earlier run left are
deleted at start, that a typed line is taken and never logged, that a request file the worker cannot delete is never run
twice, and that the `copy` request's clipboard call puts a code on the clipboard that another program reads back. It
runs wine with no display, so that clipboard stays inside wine and the desktop's clipboard is never touched.

```
python3 tools/wine_smoke.py [--wine <wine binary>] [--prefix <scratch WINEPREFIX>]
```

It does not touch the game folder or the game's prefix, and it refuses any prefix under a Steam `compatdata` folder.
It keeps the run folder `build/wine/run` afterwards, so you can read its `coop-link.log`.

## Reproducible build

The same commit, built through `tools/install.py` with clang-cl 23.1.3 and xwin's Windows SDK 10.0.26100 and MSVC CRT
14.44.35220 (linked statically), gives the same `StellarCoop.dll` bytes from any checkout. The build uses `/Brepro` and
maps the checkout path to a fixed prefix. `tools/install.py` writes the `git describe` output into the DLL; a plain
CMake build writes `dev`.

The release zip is reproducible too: the same commit gives the same zip, with every entry dated from the commit and in
sorted order. Anyone with the repository can rebuild a release and compare its `SHA256SUMS.txt` (see
[INSTALL.md: Check the files](../INSTALL.md#check-the-files)).

## Repository layout

```
mod/StellarCoop/            the UE4SS mod folder
  enabled.txt               makes UE4SS start the mod
  Scripts/                  the Lua side (see how-it-works.md)
native/                     the DLL (CMake)
  CMakeLists.txt
  src/                      platform-free headers, tested on the build machine, and the Windows side
tests/                      Lua, C++ and Python tests; wine/smoke.cpp for the Wine smoke test
tools/
  install.py                checks, build, install, uninstall, release zip
  save_guard.py             save backups and the manual co-op slot
  wine_smoke.py             loads the DLL under Wine
docs/                       this documentation
INSTALL.md                  the player install guide (shipped in the release zip)
LICENSE                     GPL-3.0-or-later (shipped in the release zip)
```

### Native sources

Platform-free headers, tested on the build machine:

| File | Contents |
| --- | --- |
| `link_core.h` | The Steam link's logic: lobby, invites, join codes, members, the host's approval, handshake, liveness, status, channels 1 and 2, chat and vitals |
| `link_protocol.h` | The link's text protocol, the join code's encoding and the requests Lua sends |
| `pose_core.h` | The pose path's limits, one part, one effect slot, hex addresses |
| `pose_table.h` | The component table, the mesh path rule and the display file |
| `pose_engine.h` | Engine memory reads and writes, and the build pin |
| `pose_codec.h` | The pose's wire format: keyframes and deltas |
| `pose_stream.h` | The loopback's delay line, the receiving clock and interpolation |
| `pose_record.h` | The recording, its check and its replay |
| `nightop_probe.h` | The `coop no` poller's reads, lines and verdict |
| `save_watch.h` | The save watcher |
| `save_slot.h` | The entered slot's read, the marker's grammar, the save file name's lookup and switch, the probe and the `slot=` line |
| `save_twins.h` | The co-op save copies, their manifest and backup, and the `saves` requests |
| `fight_sync.h` | The shared enemies' host and guest rules, and channel 2's text |
| `fight_engine.h` | The shared enemies' side inside the game, and the vitals read for the partner card |
| `quest_sync.h` | The shared quests' line format, the quest table built from the game's tables, and the host's and the guest's rules |
| `quest_engine.h` | The shared quests' side on the game's quest data (reads, guards and calls), and the worker's side |
| `pilot.h` | Same-place enemies: `SBE` and the show lines, an enemy's samples, the drawn copy's states, the owner's capture and the drawn side's writes and Show replay |
| `photo_freeze.h` | The synced photo mode's pause |

The Windows side:

| File | Contents |
| --- | --- |
| `steam_link.cpp` | Steam callbacks, the worker thread, files and fault containment |
| `pose_tick.cpp`, `pose_tick.h` | `coop_tick`, and the worker's side of the pose path: what is sent and received, the files shared with Lua |
| `clipboard.h` | The `copy` request's clipboard call, also built into the Wine smoke test |
