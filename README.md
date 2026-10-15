# StellarCoop

Experimental co-op for Stellar Blade (PC), as a UE4SS mod. Nothing else is needed: no Minecraft, no bridge.
Installing it by hand: see [INSTALL.md](INSTALL.md).

Status: release R1, a friends beta. Two players linked over Steam see each other's ghost, with keys to host, show the
status and leave, and the session's notices on screen (not yet tried between two PCs). On one PC the ghost also runs
through the loopback, a recording and its replay. `coop where` prints coordinates to compare between the two PCs.
The ghost can also show her ponytail's cloth, her hair colour and her attack and skill effects, each off by default
until it is tried in game (`coop look`, below).

- `coop off` stops everything (the ghost, her capture, the loopback, a recording, which is written, a replay, the native
  tick, engine reads, the link, the screen notices) until the game restarts, even across a Lua reload.
- Native pose path: the DLL exports `coop_tick`, which the Lua loop calls once per frame on the game
  thread. It checks the game's exe against the pinned build (Steam build 24463856) before it reads any engine memory,
  runs once per engine frame (GFrameCounter), and stops for the run at the first fault. Every 60 s the log gives the
  tick's cost and, while poses flow, the stream's counts: poses sent, tables in and refused, poses received, foreign
  (of no table or of one the ghost is not built on yet), malformed and rejected, losses, stalls, the one-way delay
  (between two PCs it includes the offset between their clocks, so it says nothing there), poses drawn and written.
  A write the engine's gate refuses is logged once each time the native part takes a new ghost or a new capture
  generation (`write refused: ...`).
- The native part also watches the save folder (names, sizes and write times every 5 s, never opening a save) and logs
  every change in `coop-link.log`; `coop report` sums them up. It also reads the co-op marker `StellarCoopSlot.txt`
  beside the saves (every 5 s) and, only on the pinned build and until `coop off`, the slot the game entered (every
  250 ms), for the `slot=<coop|main|none|unknown> index=<n|?> marker=<n|none|bad|?>` line of `coop status`.
- `tools/save_guard.py backup|check|restore` keeps copies of the saves outside the game (it refuses while the game
  runs; restore needs `--yes`). `save_guard.py slot SOURCE TARGET` makes the co-op save slot (INSTALL.md: Co-op save
  slot): it copies main slot SOURCE onto free slot TARGET and names TARGET in `StellarCoopSlot.txt`. Apart from a
  restore putting a backup back, that copy is the only save anything here writes, with the game closed and after a
  safety backup; it is never copied back. `--dry-run` writes nothing, replacing the co-op slot needs `--yes`, and a
  restore of a backup older than the slot removes the marker.
- The mod never reads or writes a save, the inventory, unlocks or equipment, and nothing is copied between two players'
  games: the ghost is display only.
- The ghost turns on by itself when a session starts (see the Steam link below); `coop puppet` (UE4SS console) turns it
  on or off by hand. On its own it shows nothing: it publishes EVE's capture for the native part, and a ghost is drawn
  once a table comes back: a linked friend's, or yours through the loopback or a replay.
  - The capture starts once EVE has been in the world 2 s (never on the title screen or a menu pawn) and only reads.
    It names each skeletal mesh part: its mesh path, the part it follows, the part and socket it hangs from, its
    placement there, whether it is shown, a leader's bone names, and the map she is on (the package path of her world,
    lowercased). It looks again once a second: a new mesh (her outfit) is a new generation; a part hung elsewhere (the
    blade drawn or sheathed), shown or hidden is published again under the same one. The log gives a `Capture` line
    per generation.
  - The ghost is a plain actor with one PoseableMeshComponent per part and no collision: not a Pawn, so lock-on, AI and
    saves never see it. It is built from the table, one mesh a frame. Each part loads the mesh its path names (LoadAsset
    only brings a cooked asset into memory; nothing is worn or unlocked) with the mesh's own materials (unless the dyes
    look is on), so the ghost wears the outfit captured. Only `/Game/Art/Character/...` and
    `/Game/DLC_<n>/Art/Character/...` meshes are loaded. A path refused by that rule, a mesh this PC cannot load (a DLC
    it does not own) or a leader with other bones than the table's falls back to the base suit: the body on
    `CH_P_EVE_08`, the hair on `EVE_HR_01`, each bone taking hers of the same name. A part with no fallback is left out,
    with the parts that follow it.
  - Parts hang as the table says (parent part, socket, placement) and followers follow their leader. No morphs: a
    neutral face; without the cloth look, a rigid ponytail. Each frame the native part writes the leaders' bones behind
    the engine's own CopyPose gate, and the main mesh's world transform into a mailbox component that Lua places the
    ghost from. The ghost stays hidden until the first pose and after a second without one.
  - The same generation with a part hung elsewhere, shown or hidden is applied to the ghost in place; a new generation
    is a new ghost. The `Ghost ... built` line gives the parts, the meshes loaded and their time, those on the base suit
    (with how many of its bones follow) and those left out.
  - Map gate: the ghost is only built when the table's map is the one you are on. Otherwise the log says once
    `Ghost hidden: she is on <map>, you are on <map>.` and `coop status` shows `ghost=hidden map`; the poses that
    arrive are counted foreign. After a level change the ghost is removed, and it comes back once EVE has been in the
    world 2 s and the maps match. A ghost left standing by a Lua reload (Ctrl+R) is found and removed at the next load.
- `coop basesuit` draws the body and hair on the base suit whatever the table names, and rebuilds the ghost. Run it
  again to go back to each part's own mesh.
- What else the ghost shows: three looks, each `on` or `off` in `coop-settings.txt` (`cloth`, `dyes`, `effects`; off
  by default, and the file written for you names them in a comment only). `coop look <cloth|dyes|effects> <on|off>`
  changes one until the mod reloads (game start or Ctrl+R) and rebuilds the ghost; `coop look` alone answers the
  `look:` line that each load logs. With one on, the `Ghost ... built` line ends with `; look: ...`.
  - `cloth`: a follower part whose mesh has clothing assets (her ponytail) is a SkeletalMeshComponent whose cloth
    simulates on its leader's bones; if that fails, it is a plain part, with a note. Only the viewer's setting counts.
  - `dyes`: her capture also names each part's overridden materials (a dynamic instance as the asset it was made
    from), and the ghost puts on each one this PC has, by the same path rule as the meshes. Not on a fallback mesh.
  - `effects`: the native part reads which of 19 known Niagara systems are playing on her leaders, at most 4, into
    four effect slots of each pose (an index into the list, never a path). The ghost starts each on the part it hangs
    on, moves it with the slot and stops it when the slot changes, at most 8 starts a second. A fault in the native
    effect read or write turns effects off until the game restarts (`effects off: fault ...`); the ghost goes on. Every
    60 s with any effect activity, an `effects, last 60 s:` line counts those started, over 4, unlisted and written.
  - `dyes=off` and `effects=off` also stop sending yours, so the friend's ghost of you lacks them too.
- `coop where` prints one line to compare between the two PCs, with or without a link or a ghost:
  `where map=<map> eve=<x,y,z> yaw=<yaw> mesh=<x,y,z> camp=<id>:<class>@<x,y,z> camp_m=<m>
  spawn=<id>:SBSpawnPoint@<x,y,z> spawn_m=<m> origin=<x,y,z> composition=<flag> rebasing=<flag> ghost=<...>`.
  - `eve=` is her actor's location; `mesh=` and `yaw=` are her main mesh's, which is what a friend's ghost is placed
    from. Positions are in centimetres, distances in metres.
  - `camp=` is the nearest object of the four camp classes `Env_VendingMachine_C`, `Env_VendingMachine_Simple_C`,
    `Env_Camp_TeleportMachine_C` and `Env_Camp_TeleportMachine_Tetrapod_C` (vending machines and phone booths): its
    data id (`EnvActorName`), class, position and distance, or `none`. Camps are placed in the levels, so the same id
    should give the same position on both PCs. Finding them walks every object, so it runs only when asked.
  - `spawn=` is the nearest `SBSpawnPoint` (its `SpawnPointName`), the same way. A map can stream every camp out
    (Spire IV does) while its spawn points stay loaded, so this field gives a reference anywhere on such a map.
  - `origin=` is the world origin (`GetWorldOriginLocation`); `composition=` and `rebasing=` are the world settings'
    world composition and origin rebasing flags.
  - `ghost=` is `<source>@<x,y,z> ghost_yaw=<yaw> ghost_m=<m> ghost_age=<s>`: where the main mesh of the ghost's EVE
    last was (before the loopback's 2 m offset), its yaw, its distance from your mesh and the seconds since that pose.
    Otherwise `waiting` (a table for your map, no pose placed yet), `elsewhere:<her map>` or `none`.
  - If the camp or spawn point search, the world origin or the world settings fail, that field reads `?(<why>)` and the rest of the
    line still prints. The map, EVE's position and her mesh are read without a guard: if one of them fails, the
    command prints `STOP:` with the error instead of the line.
- `coop loopback <delay ms> <jitter ms> <loss %>` (0 to 1000, 0 to 500, 0 to 100; needs `coop puppet`) runs the whole
  ghost pipeline on one PC, as a friend's EVE would arrive over the network. The native part sends EVE's capture as the
  table, then reads her pose 20 times a second and encodes it (about 4.7 KB in the outfit measured: quantized local
  bones, the world transform as floats, four effect slots). Both go through an in-process delay line: that one-way
  delay, plus or minus the jitter, each 1200-byte segment of a pose lost at that rate; the table is never lost. What
  comes back is the remote side: the table is checked and the ghost built from it, the poses are decoded with it and
  drawn into the ghost, interpolated between received poses on a clock that absorbs transit and jitter. In loopback the
  ghost is yours, so it walks 2 m to your right; `coop loopback 0 0 0` shows it with no delay. New settings drop what is
  in flight and send the table again. `coop loopback off` removes the remote table, and the ghost with it.
- `coop record` (needs `coop puppet` and her capture) records what is sent, the table and her poses, with or without
  the loopback or a linked friend, for up to 120 s or 24 MiB, or until `coop record off`. It is kept in memory and
  written at the stop to `coop-record.bin` in the mod folder, if it holds a pose. The name is fixed, so a new
  recording replaces the last one: rename the file by hand to keep it.
- `coop replay` (needs `coop puppet`; not while the loopback runs, and the loopback not while it runs) checks the whole
  of `coop-record.bin` before anything plays, and refuses a file that fails with the reason (`protocol` for one made
  under another protocol, so any made before protocol 6). It then plays it in a loop as the remote side, each pose
  re-stamped as if sent now, until `coop replay off`, which removes the ghost.
  Generation, map and positions stay as recorded: the ghost wears the outfit recorded, walks where she walked with no
  offset, and the map gate applies.
- `coop no` is the Night Operation probe, a test run by hand only, after a `tools/save_guard.py backup`. It runs only on
  the co-op save slot: unless `coop status` has a `slot=coop` line, it refuses with `STOP: coop no runs only with the
  co-op save slot loaded (INSTALL.md: Co-op save slot); now <the slot line>` (`now no slot status` without the native
  part). Each load logs the slot as `link: slot=...` in `UE4SS.log`. The ghost, the link and every other command run on
  any save. A probe rule only ends with the game (`coop off` does not end it), so the test ends by killing the game.
  Bare `coop no` starts the native part's read-only poller and logs a baseline: every 100 ms it reads the game's rule
  manager and a few of its neighbours into `nightop-probe.txt`, a line on each change and otherwise once a second (`coop
  status` shows `nightop=on`). Each subcommand below refuses until the poller runs, and `coop off` stops the poller. The
  probe fires only the zone events and the monster below (no achievement, no drop), kills nothing, and calls no save,
  inventory, equip or quest function; no console argument reaches a game call. At the `spawnpt` check (+3 s) and the
  `actor` checks (+3 s, +10 s), a new character within 20 m of EVE logs a `STOP` line: kill the game. Nothing watches at
  other times: if a monster comes towards EVE, kill the game. Then, one command each, in this order:
  - `coop no heal` fires the game's heal zone event `SE_10_E_ActorEff_011`: her health bar should refill.
  - `coop no rule` adds a probe row to the game's empty MultiPlayRuleTable (no achievement, quest or reward), reads it
    back field by field and sets it as the rule, once per game run (`nightop=rule`). 60 s later the native part writes
    its verdict to `nightop-probe.txt` and `coop-link.log`, and so to `UE4SS.log` as a `link:` line.
  - `coop no spawnpt` fires one spawn row of the DLC02_20 area on a loaded spawn point 60 m or more from EVE, and logs
    the new characters 3 s later.
  - `coop no actor` asks the game for one M_Antlion 60 m ahead of EVE and logs it 3 s and 10 s later.
- The Steam link (native part, `StellarCoop.dll`, loaded by the Lua script) connects two players through the Steamworks
  copy the game loaded. It never starts Steam itself and changes nothing in the game or the saves.
  - Keys, with or without the console: F5 hosts, F6 shows the status, F8 leaves (the defaults; `coop-settings.txt` below
    changes them). A key hands its action to the game thread, where the console's checks apply (`coop off` included);
    the log says `key F5: host` and then the usual `OK:` or `STOP:` line.
  - `coop host` (F5) creates a friends-only lobby (2 players) and opens the Steam invite dialog; while hosting it opens
    the dialog again, as `coop invite` does. A guest's host request is refused (`You are in <host>'s game: leave it
    first.`), so one key press never ends her friend's session.
  - A friend who accepts the invite joins automatically, whether the game was running or Steam starts it, once a save is
    loaded (EVE in a world, not on the title screen). Until then the invite is held (`Invite held: joining once your
    save has loaded.`); a newer invite replaces it, and host, join or leave drops it. `coop join` joins the first friend
    found in a Stellar Blade lobby; `coop join <lobby id>` joins that lobby; neither waits.
  - The host leads the session: when the host leaves, the guest leaves too (`Session ended: <host> left.`). A lobby with
    more than 2 players is left.
  - If the guest loses the host's lobby another way (Steam drops her, a network cut), her game rejoins it by itself:
    tries at 2, 12 and 42 s, given up at 60 s (`Lost <host>'s game: rejoining.`, then `Rejoined <host>'s game.` or
    `Session ended: ...`). The host still leads: a lobby that is gone, or that someone else owns by then, ends the
    session. Leave, host, join or a new invite stops the rejoin. The host's lobby stays meanwhile; the ghost goes with
    the link and comes back with it.
  - Once both are in the lobby, the two games exchange a hello (protocol, mod version, game build). Each answers
    `accept` or `reject <reason>`, so a mismatch is explained instead of silently ignored; a lobby from another
    protocol or game build is refused on joining, with both versions in the joiner's log. The protocol is 6 (the
    component table, with its material lines, and the pose, with its four effect slots, on Steam channel 1), so an
    older StellarCoop is refused. Accepted peers ping every 2 s over Steam's relayed P2P messages on channel 0; a peer
    silent there for 10 s is marked lost until it is heard again.
  - A friend who passed the handshake both ways is linked (`peer linked: poses and tables go over Steam` in
    `coop-link.log`), while the native pose path is on (`engine=on`). Each side's table and poses then travel on
    channel 1 as the loopback carries them: the table reliable, a pose unreliable, 20 a second (`send_rate`). The ghost
    turns on with the session (the link going from none to host or guest), which publishes EVE's capture and builds the
    ghost; `coop puppet` off holds until the next session. The ghost stands where her main mesh is, with no offset, and
    wears her outfit (display only, as above); the map gate applies.
  - Her Steam name stands above her ghost (`loopback` or `replay` for those), turned to the camera at each pose; a tag
    that fails is left out and the ghost stays. When she is on another map, the screen says once `<name> is in <map>,
    you are in <map>.`, by the maps' last segments (`b07`).
  - Your table goes to her at once and again every 5 s, which heals one lost with a broken session or sent before her
    accept; an identical table is ignored. A changed capture (a new outfit, the blade drawn) goes at once. A table of
    hers that needs a new ghost (a new generation or layout) is taken at most once per 2 s: one that comes sooner is
    refused (the stream line's `tables: ... refused`) and her next resend brings it.
  - Channel 1 hands on only what comes from a lobby member past the handshake, at most 64 KiB a message, 64 messages
    and 1 MiB a second per friend. The rest is dropped and counted, with at most one line a minute per friend
    (`dropped pose data from <name>: before the handshake`, `bad size` or `over the rate limit`); a non-member's is
    logged once (`ignored pose data from <id>: not in our lobby`). Channel 1 never counts as hearing from her.
  - Every 60 s, one line per linked friend (`<name>, last 60 s: ...`): messages and KB/s in and out on channel 1,
    drops, failed sends with the last Steam result (25: its send buffer is full), the ping's RTT average and maximum,
    pings sent and pongs received (the difference is ping loss), and Steam's view of the session: quality local and
    remote, send rate, pending unreliable bytes and queue time.
  - If she goes silent, her ghost hides after a second without a pose and comes back with the next one. Marked lost
    (`<name> silent for 10 s: lost`), she stays linked and her table is kept. Once she is out of the lobby (`<name>
    left the lobby`), or you left it (`coop leave`, or the host left), the log says `peer unlinked`, her table goes
    and the ghost with it (`Ghost <generation> removed (her table is gone).`).
  - A loopback or a replay started by hand takes over from her until it is off: meanwhile nothing is sent to her, what
    she sends is ignored, and her ghost goes. Then she is linked again, your table goes to her at once and hers comes
    back with her next resend. A recording runs beside her.
  - Notices: each session event (hosting, joined, a friend joined or left, connection lost or back, a version mismatch,
    a refused link, an invite held, a rejoin, the session ended) shows as a line of text about 30 cm above your EVE,
    turned to the camera, 4 s each in turn; at most 4 wait, and the oldest goes. `UE4SS.log` gets each once as
    `[StellarCoop] link: notice=<n> <text>`. On the title screen they go to the log only. If the engine refuses the
    line, screen notices stay off until the next Lua load (`Screen notices off: <why>; notices stay in UE4SS.log.`).
  - The status key (F6) gives one line, in the log (`OK: ...`) and on screen: `Co-op: not in a session.`, `Co-op:
    hosting, no friend yet.`, `Co-op: <name> is connecting.`, `Co-op: hosting <name>.` or `Co-op: in <name>'s game.`
    (a lost friend adds `Connection lost.`), `Co-op: invite held until your save has loaded.`, `Co-op: rejoining your
    friend's game (try <n>/3).`, `Co-op: waiting for Steam.` or `Co-op: the Steam link stopped; coop status says why.`
    `coop status` keeps the full state.
  - `coop leave` (F8) leaves the lobby. `coop report` writes `coop-report.txt`: versions, the save folder, DLLs from
    other mods, the status and the last 100 events.
  - If Steam faults under the link (for example at game exit), it stops itself: `stopped=fault <code>`. The log's last
    line says why the worker stopped.
- `coop status` prints the current state: the link (`link=<none|host|guest>`, with `held=<lobby>` for an invite held and
  `rejoin=<n>/3` while rejoining; a `friend=<linked> <lost> <name>` line; the last 8 notices), the pose path
  (`engine=on`, then `loopback=on <delay> <jitter> <loss>` or `loopback=waiting` until her capture comes, `record=on`,
  `replay=on`, `remote=<generation> <count> <loopback|replay|peer>`) and the ghost (`ghost=on parts=... leaders=...
  basesuit=... left_out=... table=... source=...`, `ghost=waiting`, `ghost=hidden map` or `ghost=off`).
- Files in the mod folder:
  - `coop-settings.txt` is yours: the keys, the name tag, the send rate and the ghost's looks. The mod writes it with
    the defaults when it is missing and never overwrites it; neither the zip nor an install ships or removes it
    (`--uninstall` backs it up with the folder, then removes it). It is read when the mod loads (game start, or Ctrl+R).
    Keys: F1 to F12 except F10 (F10 and `~` open the console on AZERTY), with at most one of `Shift+`, `Ctrl+` or `Alt+`
    in front. `name_tag` is `on` or `off`; `send_rate` is 10 to 30 poses a second (20 by default); `cloth`, `dyes` and
    `effects` are `on` or `off` (off by default). A refused value keeps its default, with a `settings:` line in
    `UE4SS.log` saying why; two actions on one key put all three keys back to the defaults. The `keys:` line gives what
    is in use, and another line says when a mod loaded earlier binds the same key (both run).
  - `coop-status.txt` (current state; each changed line except the per-peer ones also goes to `UE4SS.log` as
    `[StellarCoop] link: ...`), `coop-link.log` (this run's header and numbered events, in UTC like `UE4SS.log`,
    capped at 1 MB, repeats counted; the previous run's is `coop-link.old.log`) and `coop-report.txt`.
  - Between Lua and the native part, each written whole beside and renamed over, so never read half-written:
    `coop-request.txt` (the console's request), `coop-session.txt` (a token per Lua load), `coop-components.txt` (EVE's
    capture), `coop-remote.txt` (the remote table the ghost is built from), `coop-display.txt` (the ghost Lua built for
    it) and `coop-state.txt` (whether a save is loaded, and the send rate). The native part deletes the capture, remote,
    display and state files when it starts. Lua alone keeps `coop-puppet.txt` (the ghost's object path, for the next Lua
    load), written the same way.
  - `nightop-probe.txt` (the `coop no` poller's lines, capped at 4 MB). An earlier run's last probe file is
    `nightop-probe.old.txt`, moved there when the native part starts and finds one; a run without `coop no` writes
    none, so it can be older than the previous run.
  - `coop-record.bin` (the recording). An install never removes what the mod writes; `--uninstall` backs it up first.

## Layout

- `mod/StellarCoop/`: the UE4SS mod folder (`Scripts/main.lua`, `Scripts/capture.lua` (EVE's capture),
  `Scripts/puppet.lua` (the ghost), `Scripts/link.lua`, `Scripts/notice.lua` (notices on screen), `Scripts/nightop.lua`
  (the `coop no` probe), `Scripts/unreal.lua` (helpers over UE4SS objects), `enabled.txt`). The installer adds
  `Scripts/version.lua`.
- `native/`: the DLL (CMake, clang-cl or MSVC). Free of Windows and tested on the build machine: `src/link_core.h`
  (the link's logic, channel 1 included), `src/link_protocol.h` (its text protocol), `src/pose_core.h` (limits, one
  part, hex addresses), `src/pose_table.h` (the component table, the mesh path rule and the display file),
  `src/pose_engine.h` (engine memory reads and writes, and the build pin), `src/pose_codec.h` (the pose's wire
  format), `src/pose_stream.h` (the loopback's delay line, the receiving clock and interpolation),
  `src/pose_record.h` (the recording, its check and its replay), `src/nightop_probe.h` (the `coop no` poller's reads,
  lines and verdict), `src/save_watch.h` and `src/save_slot.h` (the entered slot's read, the marker's grammar and the
  `slot=` line). The Windows side:
  `src/steam_link.cpp` (Steam callbacks, worker thread, files, faults) and `src/pose_tick.cpp` (`coop_tick`, and the
  worker's side of the pose path: what is sent and received, the files shared with Lua).
- `tests/`: Lua checks with fake UE4SS objects (`lua5.4 tests/puppet_test.lua` from the repository root; the
  capture's fake EVE only reads, so any write to her fails), C++ checks built and run on the build machine (the
  protocol with a fuzz loop, the link against a fake Steam, two links through it with the handshake both ways and
  channel 1's checks, the pose path against fake memory, the codec's round trips and a decoder fuzz, the component
  table and display file with a parser fuzz, the recording's reader with a fuzz and its replay, the loopback pipeline
  in simulated time, the save watcher, the slot line and marker against fake memory in `tests/save_slot_test.cpp`)
  and Python checks of `save_guard.py`, its `slot` command included, and of `install.py`'s install, backup, uninstall
  and zip, on temporary folders.
  `tools/wine_smoke.py` loads the DLL under Proton's wine in a scratch prefix.
- `tools/install.py`: runs the checks, builds the DLL with the clang-cl/xwin toolchain (`STELLAR_WINDOWS_TOOLCHAIN`)
  and copies the mod into `<game>/SB/Binaries/Win64/ue4ss/Mods/StellarCoop`. It refuses while the game runs.
  - It first backs up the files it replaces or removes into `~/StellarCoop-install-backups/<UTC time>/StellarCoop`,
    outside the game folder (UE4SS would load a copy under `Mods`). Backups are never pruned.
  - `--uninstall` backs up the whole folder there, then removes it. It runs no checks and no build, and leaves a
    folder without `install-manifest.txt` alone. It never touches saves, `StellarCoopSlot.txt` or `mods.txt`; it
    says if a `mods.txt` line still names StellarCoop. `--dry-run` with it changes nothing.
  - `--zip` writes `build/StellarCoop-<version>.zip` for a friend instead, from a clean tree only: the mod folder
    with `INSTALL.md`, a `CHANGELOG.md` generated from the commits' `feat` and `fix` subjects, and `SHA256SUMS.txt`
    over them all. The same commit gives the same zip, dated from the commit. `CHANGELOG.md` is never committed.
  - The DLL is reproducible (`/Brepro`, checkout paths mapped): building a commit through `tools/install.py` (which
    bakes `git describe` into it; a plain CMake build bakes `dev`) with clang-cl 23.1.3 and xwin's SDK 10.0.26100 and
    MSVC CRT 14.44.35220 (linked statically) gives the same `StellarCoop.dll` bytes.
