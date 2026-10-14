# StellarCoop

Experimental co-op for Stellar Blade (PC), as a UE4SS mod. Nothing else is needed: no Minecraft, no bridge.
Installing it by hand: see [INSTALL.md](INSTALL.md).

Status: probes only.

- `coop puppet` (UE4SS console) shows or removes a second EVE 2 m to her right that copies her pose every frame. The
  log says how much each frame cost when it is removed.
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
- `native/`: the DLL (CMake, clang-cl or MSVC). `src/link_core.h` is the link's logic and `src/link_protocol.h` its text
  protocol, both free of Windows; `src/steam_link.cpp` is the Windows side (callbacks, worker thread, files, faults).
- `tests/`: Lua checks with fake UE4SS objects (`lua5.4 tests/puppet_test.lua` from the repository root) and C++ checks
  built and run on the build machine: the protocol (with a fuzz loop) and the link's logic against a fake Steam.
- `tools/install.py`: runs the checks, builds the DLL with the clang-cl/xwin toolchain (`STELLAR_WINDOWS_TOOLCHAIN`)
  and copies the mod into `<game>/SB/Binaries/Win64/ue4ss/Mods/StellarCoop`. It refuses while the game runs.
  `--zip` writes a package for a friend instead.
