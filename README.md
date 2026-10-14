# StellarCoop

Experimental co-op for Stellar Blade (PC), as a UE4SS mod. Nothing else is needed: no Minecraft, no bridge.
Installing it by hand: see [INSTALL.md](INSTALL.md).

Status: the ghost of an EVE runs on one PC (loopback, record and replay). Two players can link over Steam, but poses
do not travel over it yet (Phase 4).

- `coop off` stops everything (the ghost, her capture, the loopback, a recording, which is written, a replay, the
  native tick, engine reads, the link) until the game restarts, even across a Lua reload.
- Native pose path: the DLL exports `coop_tick`, which the Lua loop calls once per frame on the game
  thread. It checks the game's exe against the pinned build (Steam build 24463856) before it reads any engine memory,
  runs once per engine frame (GFrameCounter), and stops for the run at the first fault. Every 60 s the log gives the
  tick's cost and, while poses flow, the stream's counts: poses sent, tables in and refused, poses received, foreign
  (of no table or of one the ghost is not built on yet), malformed and rejected, losses, stalls, the one-way delay,
  poses drawn and written. A write the engine's gate refuses is logged once each time the native part takes a new
  ghost or a new capture generation (`write refused: ...`).
- The native part also watches the save folder (names, sizes and write times every 5 s, never opening a file) and logs
  every change in `coop-link.log`; `coop report` sums them up. `tools/save_guard.py backup|check|restore` keeps copies
  of the saves outside the game (it refuses while the game runs; restore needs `--yes`).
- Nothing reads or writes a save, the inventory, unlocks or equipment, and nothing is copied between two players'
  games: the ghost is display only.
- `coop puppet` (UE4SS console) turns the ghost on or off. On its own it shows nothing: it publishes EVE's capture for
  the native part, and a ghost is drawn once a table comes back, through the loopback or a replay.
  - The capture starts once EVE has been in the world 2 s (never on the title screen or a menu pawn) and only reads.
    It names each skeletal mesh part: its mesh path, the part it follows, the part and socket it hangs from, its
    placement there, whether it is shown, a leader's bone names, and the map she is on (the package path of her world,
    lowercased). It looks again once a second: a new mesh (her outfit) is a new generation; a part hung elsewhere (the
    blade drawn or sheathed), shown or hidden is published again under the same one. The log gives a `Capture` line
    per generation.
  - The ghost is a plain actor with one PoseableMeshComponent per part and no collision: not a Pawn, so lock-on, AI
    and saves never see it. It is built from the table, one mesh a frame. Each part loads the mesh its path names
    (LoadAsset only brings a cooked asset into memory; nothing is worn or unlocked) with the mesh's own materials, so
    the ghost wears the outfit captured. Only `/Game/Art/Character/...` and `/Game/DLC_<n>/Art/Character/...` meshes
    are loaded. A path refused by that rule, a mesh this PC cannot load (a DLC it does not own) or a leader with other
    bones than the table's falls back to the base suit: the body on `CH_P_EVE_08`, the hair on `EVE_HR_01`, each
    bone taking hers of the same name. A part with no fallback is left out, with the parts that follow it.
  - Parts hang as the table says (parent part, socket, placement) and followers follow their leader. No cloth or
    morphs: a rigid ponytail and a neutral face. Each frame the native part writes the leaders' bones behind the
    engine's own CopyPose gate, and the main mesh's world transform into a mailbox component that Lua places the ghost
    from. The ghost stays hidden until the first pose and after a second without one.
  - The same generation with a part hung elsewhere, shown or hidden is applied to the ghost in place; a new generation
    is a new ghost. The `Ghost ... built` line gives the parts, the meshes loaded and their time, those on the base suit
    (with how many of its bones follow) and those left out.
  - Map gate: the ghost is only built when the table's map is the one you are on. Otherwise the log says once
    `Ghost hidden: she is on <map>, you are on <map>.` and `coop status` shows `ghost=hidden map`; the poses that
    arrive are counted foreign. After a level change the ghost is removed, and it comes back once EVE has been in the
    world 2 s and the maps match. A ghost left standing by a Lua reload (Ctrl+R) is found and removed at the next load.
- `coop basesuit` draws the body and hair on the base suit whatever the table names, and rebuilds the ghost. Run it
  again to go back to each part's own mesh.
- `coop loopback <delay ms> <jitter ms> <loss %>` (0 to 1000, 0 to 500, 0 to 100; needs `coop puppet`) runs the whole
  ghost pipeline on one PC, as a friend's EVE would arrive over the network. The native part sends EVE's capture as
  the table, then reads her pose 20 times a second and encodes it (about 4.7 KB in the outfit measured: quantized local
  bones, the world transform as floats). Both go through an in-process delay line: that one-way delay, plus or minus
  the jitter, each 1200-byte segment of a pose lost at that rate; the table is never lost. What comes back is the
  remote side: the table is checked and the ghost built from it, the poses are decoded with it and drawn into the
  ghost, interpolated between received poses on a clock that absorbs transit and jitter. In loopback the ghost is
  yours, so it walks 2 m to your right; `coop loopback 0 0 0` shows it with no delay. New settings drop what is in
  flight and send the table again. `coop loopback off` removes the remote table, and the ghost with it.
- `coop record` (needs `coop puppet` and her capture) records what is sent, the table and her poses, with or without
  the loopback, for up to 120 s or 24 MiB, or until `coop record off`. It is kept in memory and written at the stop to
  `coop-record.bin` in the mod folder, if it holds a pose. The name is fixed, so a new recording replaces the last one:
  rename the file by hand to keep it.
- `coop replay` (needs `coop puppet`; not while the loopback runs, and the loopback not while it runs) checks the whole
  of `coop-record.bin` before anything plays, and refuses a file that fails with the reason. It then plays it in a
  loop as the remote side, each pose re-stamped as if sent now, until `coop replay off`, which removes the ghost.
  Generation, map and positions stay as recorded: the ghost wears the outfit recorded, walks where she walked with no
  offset, and the map gate applies.
- The Steam link (native part, `StellarCoop.dll`, loaded by the Lua script) connects two players through the Steamworks
  copy the game loaded. It never starts Steam itself and changes nothing in the game or the saves.
  - `coop host` creates a friends-only lobby (2 players) and opens the Steam invite dialog. `coop invite` reopens it.
  - A friend who accepts the invite joins automatically, whether the game was running or Steam starts it.
    `coop join` joins the first friend found in a Stellar Blade lobby; `coop join <lobby id>` joins that lobby.
  - The host leads the session: when the host leaves, the guest leaves too. A lobby with more than 2 players is left.
  - Once both are in the lobby, the two games exchange a hello (protocol, mod version, game build). Each answers
    `accept` or `reject <reason>`, so a mismatch is explained instead of silently ignored; a lobby from another
    protocol or game build is refused on joining, with both versions in the joiner's log. The protocol is 3 (the
    component table beside the pose), so an older StellarCoop is refused. Accepted peers ping every 2 s over Steam's
    relayed P2P messages; a peer silent for 10 s is marked lost until it is heard again.
  - `coop leave` leaves the lobby. `coop report` writes `coop-report.txt`: versions, the save folder, DLLs from other
    mods, the status and the last 100 events.
  - If Steam faults under the link (for example at game exit), it stops itself: `stopped=fault <code>`. The log's last
    line says why the worker stopped.
- `coop status` prints the current state: the link, the pose path (`engine=on`, then `loopback=on <delay> <jitter>
  <loss>` or `loopback=waiting` until her capture comes, `record=on <s>s`, `replay=on`, `remote=<generation> <count>
  <loopback|replay>`) and the ghost (`ghost=on parts=... leaders=... basesuit=... left_out=... table=... source=...`,
  `ghost=waiting`, `ghost=hidden map` or `ghost=off`).
- Files in the mod folder:
  - `coop-status.txt` (current state; each changed line except the per-peer ones also goes to `UE4SS.log` as
    `[StellarCoop] link: ...`), `coop-link.log` (this run's header and numbered events, in UTC like `UE4SS.log`,
    capped at 1 MB, repeats counted; the previous run's is `coop-link.old.log`) and `coop-report.txt`.
  - Between Lua and the native part, each written whole beside and renamed over, so never read half-written:
    `coop-request.txt` (the console's request), `coop-session.txt` (a token per Lua load), `coop-components.txt`
    (EVE's capture), `coop-remote.txt` (the remote table the ghost is built from) and `coop-display.txt` (the ghost
    Lua built for it). The native part deletes the capture, remote and display files when it starts. Lua alone keeps
    `coop-puppet.txt` (the ghost's object path, for the next Lua load), written the same way.
  - `coop-record.bin` (the recording). `tools/install.py` never removes what the mod writes.

## Layout

- `mod/StellarCoop/`: the UE4SS mod folder (`Scripts/main.lua`, `Scripts/capture.lua` (EVE's capture),
  `Scripts/puppet.lua` (the ghost), `Scripts/link.lua`, `Scripts/unreal.lua` (helpers over UE4SS objects),
  `enabled.txt`). The installer adds `Scripts/version.lua`.
- `native/`: the DLL (CMake, clang-cl or MSVC). Free of Windows and tested on the build machine: `src/link_core.h`
  (the link's logic), `src/link_protocol.h` (its text protocol), `src/pose_core.h` (limits, one part, hex addresses),
  `src/pose_table.h` (the component table, the mesh path rule and the display file), `src/pose_engine.h` (engine
  memory reads and writes, and the build pin), `src/pose_codec.h` (the pose's wire format), `src/pose_stream.h` (the
  loopback's delay line, the receiving clock and interpolation), `src/pose_record.h` (the recording, its check and its
  replay) and `src/save_watch.h`. The Windows side:
  `src/steam_link.cpp` (Steam callbacks, worker thread, files, faults) and `src/pose_tick.cpp` (`coop_tick`, and the
  worker's side of the pose path: what is sent and received, the files shared with Lua).
- `tests/`: Lua checks with fake UE4SS objects (`lua5.4 tests/puppet_test.lua` from the repository root; the
  capture's fake EVE only reads, so any write to her fails), C++ checks built and run on the build machine (the
  protocol with a fuzz loop, the link against a fake Steam, the pose path against fake memory, the codec's round trips
  and a decoder fuzz, the component table and display file with a parser fuzz, the recording's reader with a fuzz and
  its replay, the loopback pipeline in simulated time, the save watcher) and a Python check of `save_guard.py`.
  `tools/wine_smoke.py` loads the DLL under Proton's wine in a scratch prefix.
- `tools/install.py`: runs the checks, builds the DLL with the clang-cl/xwin toolchain (`STELLAR_WINDOWS_TOOLCHAIN`)
  and copies the mod into `<game>/SB/Binaries/Win64/ue4ss/Mods/StellarCoop`. It refuses while the game runs.
  `--zip` writes a package for a friend instead.
