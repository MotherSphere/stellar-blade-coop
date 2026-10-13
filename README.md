# StellarCoop

Experimental co-op for Stellar Blade (PC), as a UE4SS mod. Nothing else is needed: no Minecraft, no bridge.

Status: probes only.

- `coop puppet` (UE4SS console) shows or removes a second EVE 2 m to her right that copies her pose every frame. The
  log says how much each frame cost when it is removed.
- The Steam link (native part, `StellarCoop.dll`, loaded by the Lua script) connects two players through the Steamworks
  copy the game loaded. It never starts Steam itself and changes nothing in the game or the saves.
  - `coop host` creates a friends-only lobby (2 players) and opens the Steam invite dialog. `coop invite` reopens it.
  - A friend who accepts the invite joins automatically, whether the game was running or Steam starts it.
    `coop join` joins the first friend found in a Stellar Blade lobby; `coop join <lobby id>` joins that lobby.
  - Once both are in the lobby, the two games exchange a hello (game build, Steam name) and then ping every 2 s, over
    Steam's relayed P2P messages. Both players need the same game build and mod protocol.
  - `coop leave` leaves the lobby. `coop status` prints the current state.
  - Files in the mod folder: `coop-status.txt` (current state; each changed line except the per-peer ones also goes
    to `UE4SS.log` as `[StellarCoop] link: ...`), `coop-link.log` (every event of this run, numbered like the status's
    `last=`; the previous run's is `coop-link.old.log`) and `coop-request.txt` (the console's request, taken by the
    native part). If Steam faults under the link (for example at game exit), it stops itself: `stopped=fault`.

## Layout

- `mod/StellarCoop/`: the UE4SS mod folder (`Scripts/main.lua`, `Scripts/puppet.lua`, `Scripts/link.lua`,
  `enabled.txt`).
- `native/`: the DLL (CMake, clang-cl or MSVC). `src/link_protocol.h` holds the platform-free text protocol.
- `tests/`: Lua checks with fake UE4SS objects (`lua tests/puppet_test.lua` from the repository root) and C++ checks of
  the protocol, built and run on the build machine.
- `tools/install.py`: runs the checks, builds the DLL with the clang-cl/xwin toolchain (`STELLAR_WINDOWS_TOOLCHAIN`)
  and copies the mod into `<game>/SB/Binaries/Win64/ue4ss/Mods/StellarCoop`. It refuses while the game runs.
