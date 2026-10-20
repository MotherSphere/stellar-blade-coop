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

- Lua tests (`capture`, `chat`, `join`, `keybind`, `link`, `main`, `nightop`, `notice`, `partner`, `puppet`,
  `recruiter`, `recruiter_text`, `saves`, `settings_file`, `ui`, `ui_kit`, `ui_model`) run the scripts, with fake UE4SS
  objects for those that call the engine. In the capture test, any write to the fake EVE fails the test.
- C++ tests cover the platform-free headers in `native/src`:
  - `link_protocol_test`: the text protocol, with a fuzz loop, and the join codes (both real lobby ids, loose typing,
    malformed codes, and the share of one-character typos the check turns away);
  - `link_core_test`: the link against a fake Steam, and two links through it with the handshake both ways, channel 1
    and channel 2 with their checks, the photo line, the chat and vitals lines, joining with a code, and the host's
    approval of a player who is not a Steam friend (let in, refused, no answer, removed, a flood while waiting);
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
  - `fight_engine_test`: the shared enemies' side inside the game, the enemies `fight_chars=auto` picks and leaves
    out, the enemies' state map, the two-player scaling, the vitals read, and same-place enemies' freeze (BlockAI put
    back after the game's own dispel, freeze-lost after 5 tries in any 10 s, none in the turn we start a crowd
    control, taken off before a kill and on every way out, a refused dispel tried again) with the pair table for the
    game thread, against fake memory;
  - `fight_sync_test`: the shared enemies' channel 2 text (with a fuzz), the host's and the guest's rules, and two fake
    worlds linked through a delayed, lossy line;
  - `pilot_test`: the core of same-place enemies (stage 3a): the SBE message with a fuzz, the gen and owner epoch
    filters, an enemy's samples drawn on the ghost's own clock (150 ms extrapolation cap, warp, hole and 3 m snaps),
    the drawn copy's states with the 2 m convergence snap, the capture list's restore order, the show lines with a
    fuzz, their timeline and line ids, the 1 s dedupe window, the FNamePool decode and compact id over fake blocks,
    and two worlds through a delayed, lossy line (120 ms, plus or minus 30, 2 % lost), where the guest's copies stay
    within 30 cm of the host's enemies at the same host time while they move (an 8 m/s lunge to a dead stop included)
    and 5 cm at rest, the show lines apply in the host's order, and restore puts every copy back to local, with its
    CMC back in SB's movement manager and the speed override gone;
  - `photo_freeze_test`: the synced photo mode's pause against a fake pause set.
- Python tests:
  - `save_guard_test.py`: `tools/save_guard.py`, its `slot` command included, on temporary folders;
  - `install_test.py`: `tools/install.py`'s install, backup, uninstall and zip, on a fake game folder;
  - `matchmaking_scan_test.py`: a scan that fails if any script or native source could reach the game's matchmaking
    (see [night-operation.md](night-operation.md#how-the-original-matchmaking-is-blocked)).

## tools/wine_smoke.py

`tools/wine_smoke.py` builds `StellarCoop.dll` exactly as the installer does, builds `tests/wine/smoke.cpp`, and loads
the DLL under Proton's `wine` in a scratch prefix with no `steam_api64.dll` present. It checks that the DLL attaches,
waits for Steam, answers `coop_tick`, refuses the engine, the Night Operation poller, the save name's probe and
`saves coop` on an exe that is not the game, logs `save name: saves=off` once, and logs a clean process exit. It also
checks that `ReadProcessMemory` behaves as the poller needs, that the chat files an earlier run left are deleted at
start, that a typed line is taken and never logged, that a request file the worker cannot delete is never run twice,
and that the `copy` request's clipboard call puts a code on the clipboard that another program reads back. It runs wine
with no display, so that clipboard stays inside wine and the desktop's clipboard is never touched.

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
| `photo_freeze.h` | The synced photo mode's pause |

The Windows side:

| File | Contents |
| --- | --- |
| `steam_link.cpp` | Steam callbacks, the worker thread, files and fault containment |
| `pose_tick.cpp`, `pose_tick.h` | `coop_tick`, and the worker's side of the pose path: what is sent and received, the files shared with Lua |
| `clipboard.h` | The `copy` request's clipboard call, also built into the Wine smoke test |
