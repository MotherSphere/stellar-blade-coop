# Building from source

This page is for developers: the toolchain, the build and install script, the tests, the Wine smoke test, the
reproducible build, and how the repository is laid out. StellarCoop is developed on Linux: the Lua scripts need no
build, and the Windows DLL is cross-compiled with clang-cl. To understand the design first, see
[how-it-works.md](how-it-works.md).

## Toolchain

- Python 3 and Git.
- Lua 5.4 (`lua5.4`), the version the game's UE4SS embeds, for the Lua tests.
- A host C++17 compiler (`c++`) for the native tests. When it can build and run them, AddressSanitizer and
  UndefinedBehaviorSanitizer are turned on.
- CMake 3.20 or newer and Ninja.
- clang-cl with [xwin](https://github.com/Jake-Shadle/xwin)'s Windows SDK and MSVC CRT, through a CMake toolchain file:
  `~/.local/share/xwin/clang-cl-msvc.cmake` by default, or the path in the `STELLAR_WINDOWS_TOOLCHAIN` environment
  variable.
- For the Wine smoke test only: a Proton build's `wine`.

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

In order, a run:

1. runs the Lua tests (`tests/*_test.lua`), the Python tests (`tests/*_test.py`) and the native tests
   (`tests/*_test.cpp`, built and run on this machine);
2. configures and builds the DLL in `build/windows` with the clang-cl toolchain, baking the version (`git describe`)
   into it;
3. installs, writes a dry-run report, or writes the zip.

**Installing.** The mod folder gets the scripts, `enabled.txt`, `StellarCoop.dll`, `Scripts/version.lua` (the version)
and `install-manifest.txt` (the files it installed). It first backs up the files it replaces or removes into
`~/StellarCoop-install-backups/<UTC time>/StellarCoop`, outside the game folder (UE4SS would load a copy under `Mods`).
Backups are never pruned. Files the previous install shipped and this one does not are removed; what the mod writes in
game (its logs, status files and settings) is never removed.

**Uninstalling.** `--uninstall` backs up the whole folder (logs and `coop-settings.txt` included) into the same backup
folder, then removes it. It leaves alone a folder without `install-manifest.txt` (one copied from the zip) or a
symbolic link. It never touches saves, `StellarCoopSlot.txt` or `mods.txt`; it says if a `mods.txt` line still names
StellarCoop.

**The release zip.** `--zip` holds the mod folder with `INSTALL.md`, a `CHANGELOG.md` generated from the commits'
`feat` and `fix` subjects (newest first), and `SHA256SUMS.txt` over every other file. It never holds
`coop-settings.txt`. `CHANGELOG.md` is generated for the zip and never committed. Commit subjects follow Conventional
Commits; only `feat` and `fix` subjects reach the changelog, with their scope, and a `!` marks a breaking change.

## Tests

The tests run on the build machine, without the game. `tools/install.py` runs them all before every build; to run one
by hand, from the repository root:

```
lua5.4 tests/puppet_test.lua
python3 tests/save_guard_test.py
mkdir -p build/host
c++ -std=c++17 -Wall -Wextra -Werror -I native/src tests/pose_codec_test.cpp -o build/host/pose_codec_test
build/host/pose_codec_test
```

- **Lua** (`capture`, `link`, `main`, `nightop`, `notice`, `puppet`, `recruiter`, `recruiter_text`): the scripts
  against fake UE4SS objects. The capture's fake EVE only reads, so any write to her fails the test.
- **C++** (the platform-free headers in `native/src`):
  - `link_protocol_test`: the text protocol, with a fuzz loop;
  - `link_core_test`: the link against a fake Steam, and two links through it with the handshake both ways and
    channel 1's checks;
  - `pose_engine_test`: the pose path against fake memory;
  - `pose_codec_test`: the codec's round trips and a decoder fuzz;
  - `pose_table_test`: the component table and the display file, with a parser fuzz;
  - `pose_record_test`: the recording's reader, with a fuzz, and its replay;
  - `pose_stream_test`: the loopback pipeline in simulated time;
  - `save_watch_test`: the save watcher;
  - `save_slot_test`: the slot line and the marker against fake memory;
  - `nightop_probe_test`: the Night Operation poller's reads, lines and verdict against a fake image.
- **Python**:
  - `save_guard_test.py`: `tools/save_guard.py`, its `slot` command included, on temporary folders;
  - `install_test.py`: `tools/install.py`'s install, backup, uninstall and zip, on a fake game folder;
  - `matchmaking_scan_test.py`: a scan proving that no script or native source can reach the game's matchmaking (see
    [night-operation.md](night-operation.md#why-the-original-matchmaking-can-never-run)).

## tools/wine_smoke.py

`tools/wine_smoke.py` builds `StellarCoop.dll` exactly as the installer does, builds `tests/wine/smoke.cpp`, and loads
the DLL under Proton's `wine` in a scratch prefix with no `steam_api64.dll` around. It checks that the DLL attaches,
waits for Steam, answers `coop_tick`, refuses the engine and the Night Operation poller on an exe that is not the game,
and logs a clean process exit, and that `ReadProcessMemory` behaves as the poller needs.

```
python3 tools/wine_smoke.py [--wine <wine binary>] [--prefix <scratch WINEPREFIX>]
```

It never touches the game folder or the game's prefix: it refuses a prefix under a Steam `compatdata` folder. The run
folder `build/wine/run` is kept afterwards, so its `coop-link.log` can be read.

## Reproducible build

The DLL is reproducible: the same commit, built through `tools/install.py` with clang-cl 23.1.3 and xwin's Windows SDK
10.0.26100 and MSVC CRT 14.44.35220 (linked statically), gives the same `StellarCoop.dll` bytes from any checkout. The
build uses `/Brepro` and maps the checkout path to a fixed prefix. `tools/install.py` bakes `git describe` into the
DLL; a plain CMake build bakes `dev`.

The zip is reproducible too: the same commit gives the same zip, every entry dated from the commit, in sorted order.
Anyone with the repository can therefore rebuild a release and compare its `SHA256SUMS.txt` (see
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
  save_guard.py             save backups and the co-op save slot
  wine_smoke.py             loads the DLL under Wine
docs/                       this documentation
INSTALL.md                  the player install guide (shipped in the release zip)
```

### Native sources

Free of Windows, and tested on the build machine:

| File | Contents |
| --- | --- |
| `link_core.h` | The Steam link's logic: lobby, invites, members, handshake, liveness, status and channel 1 |
| `link_protocol.h` | The link's text protocol and the requests Lua sends |
| `pose_core.h` | The pose path's limits, one part, one effect slot, hex addresses |
| `pose_table.h` | The component table, the mesh path rule and the display file |
| `pose_engine.h` | Engine memory reads and writes, and the build pin |
| `pose_codec.h` | The pose's wire format |
| `pose_stream.h` | The loopback's delay line, the receiving clock and interpolation |
| `pose_record.h` | The recording, its check and its replay |
| `nightop_probe.h` | The `coop no` poller's reads, lines and verdict |
| `save_watch.h` | The save watcher |
| `save_slot.h` | The entered slot's read, the marker's grammar and the `slot=` line |

The Windows side:

| File | Contents |
| --- | --- |
| `steam_link.cpp` | Steam callbacks, the worker thread, files and fault containment |
| `pose_tick.cpp`, `pose_tick.h` | `coop_tick`, and the worker's side of the pose path: what is sent and received, the files shared with Lua |
