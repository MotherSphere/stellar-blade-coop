# StellarCoop

Experimental co-op for Stellar Blade (PC), as a UE4SS mod. Nothing else is needed: no Minecraft, no bridge.
Installing it by hand: see [INSTALL.md](INSTALL.md).

Status: probes only.

- `coop off` stops everything (puppet, native tick, engine reads, the link) until the game restarts.
- Native pose path: the DLL exports `coop_tick`, which the Lua loop calls once per frame on the game
  thread. It checks the game's exe against the pinned build (Steam build 24463856) before it reads any engine memory,
  runs once per engine frame (GFrameCounter), and stops for the run at the first fault. `coop probe` (with the puppet
  out, mirror off) checks, part by part, that the bone memory the puppet copied matches EVE's: `offsets_ok`, or what
  differs. Every 60 s the log gives the tick's cost and the mirror's or the loopback's counts. The
  puppet publishes its parts in `coop-components.txt`, and each Lua load writes a new `coop-session.txt` token.
- The native part also watches the save folder (names, sizes and write times every 5 s, never opening a file) and logs
  every change in `coop-link.log`; `coop report` sums them up. `tools/save_guard.py backup|check|restore` keeps copies
  of the saves outside the game (it refuses while the game runs; restore needs `--yes`).
- `coop puppet` (UE4SS console) shows or removes a second EVE 2 m to her right that copies her pose every frame. Its
  parts hang as hers do (same parent part, socket and placement: the blade stays in its hand), its visibility follows
  hers, and after a level change it comes back on its own. A puppet left standing by a Lua reload (Ctrl+R) is found
  and removed at the next load. The log says how much each frame cost when it is removed.
- `coop mirror <ms>` (1 to 2000) makes the puppet repeat her moves that many milliseconds late, written natively: the
  native part first probes the puppet's table, then each frame records her pose and writes the delayed one into the
  puppet's bones behind the engine's own CopyPose gate; it hands the delayed placement to Lua through a mailbox
  component. `coop mirror off` goes back to copying.
- `coop loopback <delay ms> <jitter ms> <loss %>` (0 to 1000, 0 to 500, 0 to 100) runs the whole ghost pipeline on one
  PC, as a friend's EVE would arrive over the network: after the same probe, the native part reads her pose 20 times a
  second, encodes it (about 4.7 KB: quantized local bones, the world transform as floats), sends it through an
  in-process delay line (that one-way delay, plus or minus the jitter, each 1200-byte segment lost at that rate),
  decodes what comes back and draws it into the puppet, interpolated between received poses on a clock that absorbs
  transit and jitter. `coop loopback off` goes back to copying; the mirror and the loopback never run together. Every
  60 s the log gives poses sent and received, bytes, losses, stalls, the one-way delay, extrapolated frames and writes.
- The Steam link (native part, `StellarCoop.dll`, loaded by the Lua script) connects two players through the Steamworks
  copy the game loaded. It never starts Steam itself and changes nothing in the game or the saves.
  - `coop host` creates a friends-only lobby (2 players) and opens the Steam invite dialog. `coop invite` reopens it.
  - A friend who accepts the invite joins automatically, whether the game was running or Steam starts it.
    `coop join` joins the first friend found in a Stellar Blade lobby; `coop join <lobby id>` joins that lobby.
  - The host leads the session: when the host leaves, the guest leaves too. A lobby with more than 2 players is left.
  - Once both are in the lobby, the two games exchange a hello (protocol, mod version, game build). Each answers
    `accept` or `reject <reason>`, so a mismatch is explained instead of silently ignored; a lobby from another
    protocol or game build is refused on joining, with both versions in the joiner's log. Accepted peers ping
    every 2 s over Steam's relayed P2P messages; a peer silent for 10 s is marked lost until it is heard again.
  - `coop leave` leaves the lobby. `coop status` prints the current state. `coop report` writes `coop-report.txt`:
    versions, the save folder, DLLs from other mods, the status and the last 100 events.
  - Files in the mod folder: `coop-status.txt` (current state; each changed line except the per-peer ones also goes
    to `UE4SS.log` as `[StellarCoop] link: ...`), `coop-link.log` (this run's header and numbered events, in UTC like
    `UE4SS.log`, capped at 1 MB, repeats counted; the previous run's is `coop-link.old.log`), `coop-report.txt` and
    `coop-request.txt` (the console's request, taken by the native part). If Steam faults under the link (for example
    at game exit), it stops itself: `stopped=fault <code>`. The log's last line says why the worker stopped.

## Layout

- `mod/StellarCoop/`: the UE4SS mod folder (`Scripts/main.lua`, `Scripts/puppet.lua`, `Scripts/link.lua`,
  `enabled.txt`). The installer adds `Scripts/version.lua`.
- `native/`: the DLL (CMake, clang-cl or MSVC). Free of Windows and tested on the build machine: `src/link_core.h`
  (the link's logic), `src/link_protocol.h` (its text protocol), `src/pose_core.h` (component table, delay ring),
  `src/pose_engine.h` (engine memory reads and the build pin), `src/pose_codec.h` (the pose's wire format),
  `src/pose_stream.h` (the loopback's delay line, the receiving clock and interpolation) and `src/save_watch.h`. The
  Windows side:
  `src/steam_link.cpp` (Steam callbacks, worker thread, files, faults) and `src/pose_tick.cpp` (`coop_tick`).
- `tests/`: Lua checks with fake UE4SS objects (`lua5.4 tests/puppet_test.lua` from the repository root), C++ checks
  built and run on the build machine (the protocol with a fuzz loop, the link against a fake Steam, the pose path
  against fake memory, the codec's round trips and a decoder fuzz, the loopback pipeline in simulated time, the save
  watcher) and a Python check of `save_guard.py`. `tools/wine_smoke.py` loads the DLL
  under Proton's wine in a scratch prefix.
- `tools/install.py`: runs the checks, builds the DLL with the clang-cl/xwin toolchain (`STELLAR_WINDOWS_TOOLCHAIN`)
  and copies the mod into `<game>/SB/Binaries/Win64/ue4ss/Mods/StellarCoop`. It refuses while the game runs.
  `--zip` writes a package for a friend instead.
