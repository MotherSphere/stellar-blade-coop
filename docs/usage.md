# Using StellarCoop

This page lists everything you can do with StellarCoop in game: the keys, every `coop` console command, the settings
file, the ghost's looks, the notices and status lines, and the files the mod writes. To install the mod first, see
[INSTALL.md](../INSTALL.md). For what happens behind each feature, see [how-it-works.md](how-it-works.md).

Close the game before you change any file in the mod folder.

## Keys

The keys work with or without the console. They need the native part (`StellarCoop.dll`).

| Key (default) | Action | Console equivalent |
| --- | --- | --- |
| F5 | Host a session, or open the Steam invite dialog again while you host | `coop host` |
| F6 | Show the status: one line above EVE and in `UE4SS.log` | (a short form of `coop status`) |
| F8 | Leave the session | `coop leave` |

You can change them in [coop-settings.txt](#coop-settingstxt). A key only hands its action to the game thread, where
the console's checks apply (`coop off` included). The log says `key F5: host`, then the usual `OK:` or `STOP:` line.

## Playing with a friend

1. The host presses F5. This creates a friends-only Steam lobby for 2 players and opens the Steam invite dialog. Pick
   your friend there.
2. Your friend accepts the invite in Steam. If their game is closed, Steam starts it. They join once a save is loaded
   (EVE in a world, not on the title screen). Until then their game holds the invite (`Invite held: joining once your
   save has loaded.`). A newer invite replaces a held one, and host, join or leave drops it.
3. The ghost turns on by itself in both games when the session starts. Once both games have accepted each other's
   handshake, each of you sees the other's EVE where she stands, in her outfit, with their Steam name above her.

More about sessions:

- The host leads. When the host leaves, the guest leaves too (`Session ended: <host> left.`).
- A guest cannot host: F5 answers `You are in <host>'s game: leave it first.`, so one key press never ends their
  friend's session.
- If the guest loses the host's lobby another way (Steam drops them, a network cut), their game rejoins it by itself. It
  tries at 2, 12 and 42 s and gives up at 60 s (`Lost <host>'s game: rejoining.`, then `Rejoined <host>'s game.` or
  `Session ended: ...`). A lobby that is gone, or that someone else owns by then, ends the session. Leave, host, join
  or a new invite stops the rejoin. Meanwhile the host's lobby stays; the ghost goes with the link and comes back with
  it.
- Your friend's ghost only shows when you are both on the same map. When they are on another map, the screen says once
  `<name> is in <map>, you are in <map>.`, by the maps' last segments (for example `b07`).
- If your friend goes silent, their ghost hides after a second without a pose and comes back with the next one.
- Both players need the same protocol (6) and game build. A mismatch is explained on screen instead of being silently
  ignored (see [Notices](#notices)).

The ghost is display only. Nothing is copied between your two games: no enemies, items, unlocks or progress.

## Console commands

The console comes with ConsoleEnablerMod (see [INSTALL.md](../INSTALL.md#requirements)); it opens with F10 or `~`.
Every command starts with `coop`. Each answer goes to `UE4SS.log` as a `[StellarCoop] OK: ...` or
`[StellarCoop] STOP: ...` line. An unknown command prints the usage line.

| Command | What it does |
| --- | --- |
| `coop host` | Host a friends-only session (2 players) and open the Steam invite dialog (F5) |
| `coop invite` | Open the Steam invite dialog again while you are in a lobby |
| `coop join` | Join the first Steam friend found in a Stellar Blade lobby |
| `coop join <lobby id>` | Join that lobby (digits only) |
| `coop leave` | Leave the session (F8) |
| `coop status` | Print the full state: link, friend, notices, pose path, save slot, ghost |
| `coop report` | Write `coop-report.txt`, to send with a bug report |
| `coop where` | Print one line of positions to compare between two PCs |
| `coop puppet` | Turn the ghost on or off by hand |
| `coop basesuit` | Draw the ghost's body and hair on the base suit, or back on her own meshes |
| `coop look` | Show which looks are on |
| `coop look <cloth\|dyes\|effects> <on\|off>` | Turn one look on or off until the mod reloads |
| `coop loopback <delay ms> <jitter ms> <loss %>` | Run your own ghost through a simulated network on one PC |
| `coop loopback off` | Stop the loopback |
| `coop record` / `coop record off` | Record what you send (table and poses) to `coop-record.bin` |
| `coop replay` / `coop replay off` | Play `coop-record.bin` back as a ghost, in a loop |
| `coop no [heal\|rule\|spawnpt\|actor]` | Night Operation probe (research preview, co-op save slot only) |
| `coop recruiter [off]` | Night Operation recruiter (research preview, co-op save slot only) |
| `coop off` | Stop everything until the game restarts |

### Session commands

- `coop host` works like F5. While you host, it opens the invite dialog again, as `coop invite` does. A guest's host
  request is refused.
- `coop join` and `coop join <lobby id>` never wait for a save to load, unlike an accepted invite. Without an id it
  joins the first friend found in a Stellar Blade lobby; the log says `no friend is in a Stellar Blade lobby` when
  there is none. A lobby id is digits only.
- `coop leave` works like F8.
- `coop report` writes `coop-report.txt` in the mod folder: versions, the save folder, DLLs loaded from other mods, the
  status, a summary of save folder changes and the last 100 events.

### Ghost commands

- `coop puppet` turns the ghost on or off by hand. The ghost turns on by itself when a session starts (the link going
  from none to host or guest); turning it off with `coop puppet` holds until the next session. On its own it shows
  nothing: it publishes your EVE's capture, and a ghost is drawn once a table comes back, from a linked friend, the
  loopback or a replay.
- `coop basesuit` draws the body and hair on the base suit whatever the table names, and rebuilds the ghost. Run it
  again to go back to each part's own mesh.
- `coop look` alone answers the `look:` line that each load logs, for example `look: cloth=off dyes=off effects=off`.
  `coop look <cloth|dyes|effects> <on|off>` changes one look until the mod reloads (game start or Ctrl+R) and rebuilds
  the ghost. `coop-settings.txt` stays as it is. See [Looks](#looks).

### `coop where`

`coop where` prints one line to compare between the two PCs, with or without a link or a ghost:

```
where map=<map> eve=<x,y,z> yaw=<yaw> mesh=<x,y,z> camp=<id>:<class>@<x,y,z> camp_m=<m>
spawn=<id>:SBSpawnPoint@<x,y,z> spawn_m=<m> origin=<x,y,z> composition=<flag> rebasing=<flag> ghost=<...>
```

- Positions are in centimetres, distances in metres.
- `eve=` is your EVE actor's location. `mesh=` and `yaw=` are her main mesh's, which is what a friend's ghost of you is
  placed from.
- `camp=` is the nearest object of the four camp classes `Env_VendingMachine_C`, `Env_VendingMachine_Simple_C`,
  `Env_Camp_TeleportMachine_C` and `Env_Camp_TeleportMachine_Tetrapod_C` (vending machines and phone booths): its data
  id (`EnvActorName`), class, position and distance, or `none`. Camps are placed in the levels, so the same id should
  give the same position on both PCs. Finding them walks every object, so it runs only when asked.
- `spawn=` is the nearest `SBSpawnPoint` (its `SpawnPointName`), found the same way. A map can stream every camp out
  (Spire IV does) while its spawn points stay loaded, so this field gives a reference anywhere on such a map.
- `origin=` is the world origin (`GetWorldOriginLocation`). `composition=` and `rebasing=` are the world settings'
  world composition and origin rebasing flags.
- `ghost=` is `<source>@<x,y,z> ghost_yaw=<yaw> ghost_m=<m> ghost_age=<s>`: where the main mesh of the ghost's EVE
  last was (before the loopback's 2 m offset), its yaw, its distance from your mesh and the seconds since that pose.
  The source is `peer`, `loopback` or `replay`. Otherwise `ghost=` reads `waiting` (a table for your map, no pose
  placed yet), `elsewhere:<her map>` or `none`.
- If the camp or spawn point search, the world origin or the world settings fail, that field reads `?(<why>)` and the
  rest of the line still prints. The map, EVE's position and her mesh are read without a guard: if one of them fails,
  the command prints `STOP:` with the error instead of the line.

### Solo testing: loopback, record, replay

These three run the ghost pipeline on one PC. They need the native tick and the ghost on (`coop puppet`).

- `coop loopback <delay ms> <jitter ms> <loss %>` (0 to 1000, 0 to 500, 0 to 100) sends your own EVE through an
  in-process network: that one-way delay, plus or minus the jitter, with each 1200-byte segment of a pose lost at that
  rate. The table is never lost. The ghost is yours, so it walks 2 m to your right. `coop loopback 0 0 0` shows it with
  no delay. New settings drop what is in flight and send the table again. `coop loopback off` removes the ghost.
- `coop record` records what is sent, the table and your poses, with or without the loopback or a linked friend, for
  up to 120 s or 24 MiB, or until `coop record off`. It is kept in memory and written at the stop to `coop-record.bin`
  in the mod folder, if it holds a pose. The name is fixed, so a new recording replaces the last one: rename the file
  by hand to keep it.
- `coop replay` checks the whole of `coop-record.bin` before anything plays and refuses a file that fails, with the
  reason (`protocol` for one made under another protocol, so any made before protocol 6). It then plays it in a loop as
  the remote side, each pose re-stamped as if sent now, until `coop replay off`, which removes the ghost. The
  generation, map and positions stay as recorded: the ghost wears the recorded outfit and walks where you walked, with
  no offset, and the map gate applies.
- The loopback and the replay never run together. Either one takes over from a linked friend until it is off: nothing
  is sent to them meanwhile, what they send is ignored, and their ghost goes. Then they are linked again: your table
  goes to them at once and theirs comes back with their next resend. A recording runs beside them.

See [how-it-works.md](how-it-works.md#loopback-record-and-replay) for what each one exercises.

### Night Operation previews

`coop no` (the probe) and `coop recruiter` (the cut recruiter) are research previews of the cut Night Operation mode,
not a playable mode. They run only with the co-op save slot loaded and need preparation first: read
[night-operation.md](night-operation.md) before you use them. Otherwise they stop with:

```
STOP: coop no runs only with the co-op save slot loaded (INSTALL.md: Co-op save slot); now <the slot line>
```

(`now no slot status` without the native part.)

The ghost, the link and every other command run on any save.

### `coop off`

`coop off` stops everything until the game restarts, even across a Lua reload: the ghost, EVE's capture, the loopback,
a recording (which is written), a replay, the native tick, engine reads, the Steam link, the screen notices, the
Night Operation poller, and a recruiter (despawned when one was asked, in Xion). Afterwards only `coop status` and
`coop report` answer; every other command answers `STOP: coop off is active until the game restarts`.

## coop-settings.txt

`Mods/StellarCoop/coop-settings.txt` is yours. The mod writes it with the defaults when it is missing and never
overwrites it. Neither the release zip nor an install ships or removes it (`tools/install.py --uninstall` backs it up
with the folder, then removes it). It is read when the mod loads (game start, or Ctrl+R). Delete it to get the
defaults back.

The file the mod writes:

```
# StellarCoop settings, read when the mod loads (game start, or Ctrl+R). Delete this file to get the defaults back.
# Keys: F1 to F12 except F10, optionally with Shift+, Ctrl+ or Alt+ in front (for example Shift+F7).
host_key=F5
status_key=F6
leave_key=F8
# Your friend's Steam name above her ghost: on or off.
name_tag=on
# Poses sent to your friend a second: 10 to 30.
send_rate=20
# What the ghost shows, each on or off (off unless set here): cloth (her ponytail swings), dyes (hair colours and
# material variants), effects (her attack and skill effects). dyes and effects off also stop sending yours.
# For example: cloth=on
```

| Setting | Values | Default |
| --- | --- | --- |
| `host_key` | `F1` to `F12` except `F10`, with at most one of `Shift+`, `Ctrl+` or `Alt+` in front | `F5` |
| `status_key` | same | `F6` |
| `leave_key` | same | `F8` |
| `name_tag` | `on` or `off`: your friend's Steam name above their ghost | `on` |
| `send_rate` | `10` to `30` poses sent a second | `20` |
| `cloth` | `on` or `off` | `off` |
| `dyes` | `on` or `off` | `off` |
| `effects` | `on` or `off` | `off` |

Rules:

- `F10` is refused because it opens the console (as does `~`). Function keys do not depend on the keyboard layout.
- Names and values ignore case, a UTF-8 BOM (Notepad) is accepted, and lines starting with `#` are comments. Only the
  first 4096 bytes are read.
- A refused value keeps its default, and `UE4SS.log` says why in a `[StellarCoop] settings:` line. An unknown setting
  is ignored with a note.
- Two actions on one key put all three keys back to `F5`, `F6` and `F8`.
- The `[StellarCoop] keys:` line gives the keys in use, the name tag and the send rate, for example
  `keys: host=F5 status=F6 leave=F8, name tag on, 20 poses a second`. Another line says when a mod loaded earlier binds
  the same key; both then run.

## Looks

Three looks change what the ghost shows. Each is `on` or `off` in `coop-settings.txt` (off by default; the file names
them in a comment only, so add a line such as `cloth=on`), and `coop look` changes one until the mod reloads. With one
on, the `Ghost ... built` log line ends with `; look: ...`.

The three looks are not yet tried in game. Back up your saves before you turn one on (see [saves.md](saves.md)), and
turn it off again if the game crashes or the ghost looks wrong.

- **`cloth`**: her ponytail swings as cloth. A follower part whose mesh has clothing assets is drawn as a
  SkeletalMeshComponent whose cloth simulates on its leader's bones. If that fails, it is a plain part, with a note in
  the log. Off, the ponytail stays rigid. Only the viewer's setting counts.
- **`dyes`**: her hair colour and other material variants. Her capture also names each part's overridden materials (a
  material made at run time is sent as the asset it was made from), and the ghost puts on each one your PC has, by the
  same path rule as the meshes. Not on a fallback mesh. Off, each part has its mesh's own colours.
- **`effects`**: her attack and skill effects. The native part reads which of 19 known effects (Niagara systems) are
  playing on her, at most 4, into four effect slots of each pose (an index into a fixed list, never a path). The ghost
  starts each on the part it hangs on, moves it with the slot and stops it when the slot changes, at most 8 starts a
  second. A fault in the native effect read or write turns effects off until the game restarts
  (`effects off: fault ...`); the ghost goes on without them. Every 60 s with any effect activity, an
  `effects, last 60 s:` line counts those started, those over 4, unlisted reads and boxes written.
- `dyes=off` and `effects=off` also stop sending yours, so your friend's ghost of you lacks them too.

## Notices

Each session event shows as a line of text about 30 cm above your EVE, turned to the camera, for 4 s each in turn. At
most 4 wait; the oldest goes. `UE4SS.log` gets each one once as `[StellarCoop] link: notice=<n> <text>`. On the title
screen they go to the log only. If the engine refuses the line, screen notices stay off until the next Lua load
(`Screen notices off: <why>; notices stay in UE4SS.log.`).

| Event | Notice |
| --- | --- |
| Hosting | `Hosting: invite a friend from the Steam overlay (Shift+Tab).` |
| Could not host | `Could not host: Steam refused.` or `Could not host: Steam result <n>.` |
| Host asked as a guest | `You are in <host>'s game: leave it first.` |
| Joined | `Joined <host>'s game.` |
| Could not join | `Could not join: that game no longer exists.`, `... that game is full.` or `... Steam response <n>.` |
| A friend joined, left, came back | `<name> joined.`, `<name> left.`, `<name> is back.` |
| Connection lost | `<name>: connection lost.` |
| Version mismatch | `Version mismatch: that game runs protocol ..., build ...; yours runs ...` (on joining) or `Version mismatch with <name>: ...` |
| Refused link | `<name> refused the link: <reason>` |
| Invite held | `Invite held: joining once your save has loaded.` |
| Rejoin | `Lost <host>'s game: rejoining.`, then `Rejoined <host>'s game.` |
| Session ended | `Session ended: <host> left.`, `Session ended: <host>'s game is gone.` or `Session ended: could not rejoin <host>'s game.` |
| Too many players | `Left: the lobby has more than 2 players.` |
| Leaving | `Left the session.`, `Not in a session.` or `Held invite dropped.` |
| Friend on another map | `<name> is in <map>, you are in <map>.` |
| Ghost failed 3 times on one table | `Ghost failed 3 times: the reason is in UE4SS.log.` |

## Status lines

### The status key (F6)

F6 gives one line, in the log (`OK: ...`) and on screen:

- `Co-op: not in a session.`
- `Co-op: hosting, no friend yet.`
- `Co-op: <name> is connecting.`
- `Co-op: hosting <name>.` or `Co-op: in <name>'s game.` (a lost friend adds `Connection lost.`)
- `Co-op: invite held until your save has loaded.`
- `Co-op: rejoining your friend's game (try <n>/3).`
- `Co-op: waiting for Steam.`
- `Co-op: the Steam link stopped; coop status says why.`

### `coop status`

`coop status` prints the full state on one log line, its parts separated by ` | `:

- **Steam**: `mod=<version> proto=6 steam=<waiting|ready>`, then the Steam ID, app id, game build, overlay, relay
  availability and callback counts.
- **Link**: `link=<none|host|guest> lobby=<id>`, with `pending=1` while a lobby call runs, `held=<lobby>` for an invite
  held and `rejoin=<n>/3` while rejoining. Then a `peer=...` line per lobby member (handshake, lost flag, RTT), a
  `friend=<linked 0|1> <lost 0|1> <name>` line, and the last 8 notices as `notice=<n> <text>`.
- **Pose path**: `engine=on` (then `loopback=on <delay> <jitter> <loss>` or `loopback=waiting` until EVE's capture comes,
  `record=on`, `replay=on`, `remote=<generation> <count> <loopback|replay|peer>`), or `engine=off reason=<why>`; then
  `nightop=on` or `nightop=rule` while the probe's poller runs.
- **Save slot**: `slot=<coop|main|none|unknown> index=<n|?> marker=<n|none|bad|?>` (see
  [saves.md](saves.md#the-co-op-save-slot)).
- **Last event**: `last=<the last coop-link.log event>`.
- **Ghost**: `ghost=on parts=<n> leaders=<n> basesuit=<0|1> left_out=<n> table=<generation> source=<source>`,
  `ghost=waiting`, `ghost=hidden map` or `ghost=off`, plus `stray_parts=<n>` if ghost parts that are not this load's
  ghost stand in the world.

Each changed status line, except the per-peer ones, also goes to `UE4SS.log` as `[StellarCoop] link: ...`. Each load
logs the save slot as `link: slot=...`.

## Files in the mod folder

Everything the mod writes stays in `Mods/StellarCoop/`. An install never removes these files, and
`tools/install.py --uninstall` backs them up before it removes the folder.

| File | Written by | What it is |
| --- | --- | --- |
| `coop-settings.txt` | Lua, once | Your settings (see above) |
| `coop-status.txt` | native | The current state, as `coop status` shows it |
| `coop-link.log` | native | This run's header and numbered events, in UTC like `UE4SS.log`, repeats counted, capped at 1 MB |
| `coop-link.old.log` | native | The previous run's `coop-link.log`, moved there at start |
| `coop-report.txt` | native | Written on `coop report` |
| `coop-record.bin` | native | The last recording (`coop record`) |
| `nightop-probe.txt` | native | The `coop no` poller's lines, capped at 4 MB |
| `nightop-probe.old.txt` | native | An earlier run's last probe file, moved there when the native part starts and finds one |
| `coop-request.txt` | Lua | A console request for the native part |
| `coop-session.txt` | Lua | A token per Lua load |
| `coop-components.txt` | Lua | Your EVE's capture (the component table) |
| `coop-remote.txt` | native | The remote table the ghost is built from |
| `coop-display.txt` | Lua | The ghost Lua built for that table |
| `coop-state.txt` | Lua | Whether a save is loaded, and the send rate |
| `coop-puppet.txt` | Lua | The ghost's object path, so the next Lua load can remove a ghost left standing |

The files shared between Lua and the native part are each written whole beside (a `.tmp` file) and renamed over, so
neither side ever reads one half-written. The native part deletes the capture, remote, display and state files, and any
stale request or report, when it starts. A run without `coop no` writes no probe file, so `nightop-probe.old.txt` can
be older than the previous run.

An install and the release zip both add `Scripts/version.lua`. An install also writes `install-manifest.txt`; the
release zip adds `INSTALL.md`, `CHANGELOG.md` and `SHA256SUMS.txt`.
