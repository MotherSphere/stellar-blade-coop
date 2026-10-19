# How StellarCoop works

This page explains StellarCoop's design for curious players and developers: how the two halves of the mod share the
work, how two games talk over Steam, how a friend's EVE becomes a ghost in your world, and what keeps your game and
saves safe. For the commands themselves, see [usage.md](usage.md). For the code, see
[building.md](building.md#repository-layout).

## Two halves

StellarCoop has two parts, both in the mod folder `Mods/StellarCoop/`:

- **The Lua side** (`Scripts/*.lua`), run by UE4SS on the game thread. It talks to the engine through UE4SS's object
  API: it reads what EVE is made of, builds the ghost's actor, places it, shows notices and handles the console and
  the keys.
- **The native side** (`StellarCoop.dll`), loaded by the Lua script with `package.loadlib`. It has two entry points:
  - a **worker thread**, started when Windows loads the DLL. It makes every Steam call, reads and writes the files
    shared with Lua, sends and receives tables and poses, and logs.
  - **`coop_tick`**, an exported function the Lua loop calls once per frame on the game thread. It reads and encodes
    EVE's pose from engine memory, decodes the poses that came back, and writes the ghost's bones.

```
   your game                                                      friend's game
   ---------                                                      -------------
   capture.lua --coop-components.txt--> worker --table (reliable)-----> worker --coop-remote.txt--> puppet.lua
                                          ^                                |                     builds the ghost
   coop_tick reads EVE's pose ---encode---+---pose (unreliable)----------->+--decode, playback--> coop_tick writes
                                              Steam channel 1                                    the ghost's bones
```

Both games run the same pipeline in both directions, so each player sees the other's ghost.

### The Lua scripts

| Script | Role |
| --- | --- |
| `main.lua` | Entry point: loads the DLL, reads the settings, registers the `coop` command and the keys, runs the loops |
| `link.lua` | The Lua side of the shared files, `coop-settings.txt`, the status key's summary |
| `capture.lua` | EVE's capture: what a ghost of her is made of (read only) |
| `puppet.lua` | The ghost: builds it from a table, places it, its name tag, effects, `coop where` |
| `notice.lua` | Notices on a line above your EVE, while the on-screen UI is not up |
| `chat.lua` | The session chat: its history (memory only), the feed of chat lines and notices, the text box |
| `menu.lua` | The co-op menu: its pages drawn, its keys, its rows run as `coop` commands, settings changed and applied |
| `ui_model.lua` | The menu's rows and settings, with no engine call |
| `ui_text.lua` | The menu's words in English and French |
| `ui.lua` | The UI kit the menu and the chat are drawn with (runtime UMG widgets in the game's look), and the `coop ui test` spike |
| `keybind.lua`, `settings_file.lua` | Key settings and their clash check; one line of `coop-settings.txt` rewritten |
| `nightop.lua` | The `coop no` probe |
| `recruiter.lua` | The `coop recruiter` preview |
| `recruiter_text.lua` | The recruiter's lines in the game's 23 languages |
| `unreal.lua` | Small helpers over UE4SS objects |

`main.lua` runs two game-thread loops: one every frame (the ghost's build step, `coop_tick`, placing the ghost,
notices, the previews' follow-ups, the menu's and the chat's tweens and input) and one every 250 ms (link status
changes, session start, notices to show, the chat's lines in and out, the capture, the remote table, the menu's root
and status line, the chat's feed).

### Files between the two sides

Apart from the call to `coop_tick`, Lua and the native part talk through small files in the mod folder. Each is
written whole beside its final name and renamed over, so the reader never sees half a file:

- Lua writes `coop-request.txt` (a console request), `coop-session.txt` (a new token per Lua load, so the native part
  drops what an older load published), `coop-components.txt` (EVE's capture), `coop-display.txt` (the ghost it built)
  and `coop-state.txt` (whether a save is loaded, the send rate, and the synced photo mode's state and settings).
- The native part writes `coop-status.txt` (the state Lua and `coop status` read), `coop-remote.txt` (the remote
  table), `coop-link.log` and `coop-report.txt`.
- The chat has two files that live a moment only. Lua writes a typed line into `coop-say.txt` only once the native
  part has taken the last one, and the native part takes and deletes it at its next pass (every 5 to 50 ms). The
  native part writes your friend's lines into `coop-chat.txt` (`in <text>`, or `fail` for a line of yours that could
  not go) only once Lua has taken the last one, and Lua deletes it when it reads it, every 250 ms. Both are deleted
  when a session ends, when the native part starts and when the game exits. Chat text is written nowhere
  else; a crash dump (`Saved/Crashes`) holds the game's memory, so it may hold lines of the session.

The full list is in [usage.md](usage.md#files-in-the-mod-folder).

## The Steam link

The link runs in the native worker, through the Steamworks API that the game itself loaded and started (the game's
`steam_api64.dll`, flat API, SDK 1.59). StellarCoop never starts Steam itself, never calls `SteamAPI_Init`, and changes
nothing in the game or the saves to link. If one of the Steam functions it needs is missing (another Steamworks build),
the worker stops for the run, the pose path with it, and the status file says `missing=<name>`.

One worker thread makes every Steam call. The game's Steam callback thread only stores a few numbers for it. The worker
passes every 50 ms, and every 5 ms while poses flow (the loopback, a recording, a replay or a friend).

### Lobby and invites

- `coop host` creates a **friends-only lobby** with room for **2 players** and opens Steam's invite dialog. The lobby
  carries a tag under the key `stellarcoop`: the protocol and the game's Steam build (`8:<build>`). A lobby from
  another protocol or game build is refused on joining, with both versions in the joiner's log and on screen.
- An accepted invite arrives as a Steam callback, or as `+connect_lobby <id>` on the command line when Steam starts the
  game for it. Either way the game joins only once a save is loaded (Lua writes `world=1` in `coop-state.txt`), so a
  launch never joins from the title screen. Until then the invite is held.
- `coop join` without an id looks through your Steam friends for one playing Stellar Blade in a lobby.
- The host leads. When the host leaves, the guest leaves too, even though Steam would hand the lobby to them. A lobby
  with more than 2 players is left.
- A guest who loses the host's lobby another way rejoins it by themselves: tries at 2, 12 and 42 s, given up at 60 s. A
  lobby that is gone or has a new owner by then ends the session.

### Handshake

Once both are in the lobby, the two games exchange a hello on channel 0:

```
SBC hello <protocol> <mod version> <game build>
SBC accept
SBC reject <reason>
```

The handshake reads the same in every protocol version, so a mismatch is always answered, never silently dropped. A
peer whose protocol or game build differs from yours is rejected, with both versions in the reason, and both leave
the lobby: the side that rejects shows `Version mismatch with <name>: ...`, the other `<name> refused the link: ...`.
The mod version is reported but does not have to match.

A friend who passed the handshake both ways is **linked** (`peer linked: poses and tables go over Steam` in
`coop-link.log`) while the native pose path is on (`engine=on`) and no loopback or replay runs. The ghost turns on with
the session (the link going from none to host or guest), which publishes your EVE's capture and builds the ghost of
your friend's EVE. It stands where her main mesh is, with no offset.

### Channel 0: text

Channel 0 carries short text messages over Steam's relayed P2P messages (SteamNetworkingMessages). Beyond the
handshake, every message carries the protocol number and is dropped by a peer that runs another one:

```
SBC8 ping <seq> <ms>
SBC8 pong <seq> <ms>
SBC8 photo <0|1|s> <both|notice>
SBC8 say <text>
SBC8 vit <hp> <max hp> <shield> <max shield> <shield blocks> <beta> <max beta> <burst> <max burst> <tachy> <max tachy> <life>
```

The photo line (reliable) carries the sender's photo mode (`1`, `s` for selfie mode, `0`) and whether their game may
be paused for the other's (`both`). It goes after each handshake and on each change, at most 8 a second are taken, and
while the other's says `1 both` and yours is `photo_sync=both`, the game thread holds a pause tag of the mod's own in
the game's pause set, through the function the game's photo mode pauses with (build 24463856 only); see
[usage.md](usage.md#synced-photo-mode) for when it is released.

The say line (reliable) is one chat line. Both games clean it the same way: well-formed UTF-8 only, control, bidi
and zero-width characters dropped, spaces trimmed, at most 200 bytes, never cut inside a character. At most 3 a second
leave, at most 10 a second are kept from a friend (the rest are dropped, with one log line a minute and no text), and
at most 16 wait for the mod's Lua side. The text never goes into `coop-link.log`, `coop-status.txt`,
`coop-report.txt` or the console: when the session ends, the log gets its counts only (`chat this session: <n> in,
<n> out, <n> dropped`).

The vit line (unreliable) carries your EVE's numbers for your friend's partner card, in whole units: HP, shield and
shield blocks, Beta, Burst and Tachy with their maximums, and the life state. It goes when they change and every
second, from a read 4 times a second during a session (twice after a read over 1 ms; game build 24463856 only): eight
`ReadProcessMemory` reads on the native worker, never on the game thread, of the EVE the game's actor manager marks as
the local player. A line with a value over 10,000,000, HP over its maximum, more than 64 shield blocks or a life state
over 255 is invalid. Your friend's last one shows in `coop status` as `mate=` for 3 s.

Say and vit lines count only from a friend past the handshake; before it they are ignored without a log line.

Accepted peers ping every 2 s. A peer silent on channel 0 for 10 s is marked lost (`<name> silent for 10 s: lost`)
until they are heard again; they stay linked and their table is kept. Messages longer than 512 bytes are junk.

A session request from Steam is accepted only after a live check that the requester is a member of your lobby;
anything else is ignored.

### Channel 1: tables and poses

Channel 1 carries the pose path's bytes as they are: the component table as text starting `SBT 8` (sent reliable), and
each pose as a binary message starting `SBP` and the protocol byte (sent unreliable, without Nagle delay).

- Your table goes to them at once and again every 5 s, which heals one lost with a broken session or sent before
  their accept. An identical table is ignored. A changed capture (a new outfit, the blade drawn) goes at once.
- A table of theirs that needs a new ghost (a new generation or layout) is taken at most once every 2 s. One that comes
  sooner is refused (the stream line's `tables: ... refused`) and their next resend brings it.
- Poses go 20 a second by default (`send_rate`, 10 to 30).
- Channel 1 hands on only what comes from a lobby member past the handshake: at most 64 KiB a message, and 64 messages
  and 1 MiB a second per friend. The rest is dropped and counted, with at most one line a minute per friend
  (`dropped pose data from <name>: before the handshake`, `bad size` or `over the rate limit`). A non-member's data is
  logged once (`ignored pose data from <id>: not in our lobby`). Channel 1 never counts as hearing from them.
- Once they are out of the lobby (`<name> left the lobby`), or you left it, the log says `peer unlinked`, their table
  goes and the ghost with it (`Ghost <generation> removed (her table is gone).`).

### Protocol 8

The protocol number goes up with any change to what travels between two games, so an older StellarCoop is refused
instead of misread:

| Protocol | Change |
| --- | --- |
| 1 | The first link (a hello with a name, no accept or reject) |
| 3 | The component table (`SBT`) beside the pose (`SBP`) |
| 4 | Tables and poses carried on Steam channel 1 |
| 5 | The table's material lines (dyes) |
| 6 | Four effect slots in each pose |
| 7 | Steam channel 2 for the shared enemies, and the photo line |
| 8 | The say and vit lines for the chat and the partner card (this version). A protocol 7 game would drop them without a word, so it is refused instead. |

### Link health in the log

Every 60 s, `coop-link.log` has one line per linked friend (`<name>, last 60 s: ...`): messages and KB/s in and out on
channel 1, drops, failed sends with the last Steam result (25 means its send buffer is full), the ping's RTT average
and maximum, pings sent and pongs received (the difference is ping loss), and Steam's view of the session: quality
local and remote, send rate, pending unreliable bytes and queue time.

## The ghost pipeline

The ghost is the same pipeline whatever its source: a linked friend, the loopback or a replay.

### 1. Capture

When the ghost is on, `capture.lua` describes your EVE once she has been in the world for 2 s (never on a menu
pawn). It only reads. For each skeletal mesh part (up to 16, with up to 1024 bones each) it notes the
mesh path, the part it follows, the part and socket it hangs from, its placement there, whether it is shown, a leader's
bone names, and the map she is on (the package path of her world, lowercased). With the dyes look on, it adds each
part's overridden materials; with the effects look on, what the native part needs to read her effects.

It looks again once a second. A new mesh (her outfit) is a new **generation**. A part hung elsewhere (the blade drawn
or sheathed), shown or hidden is published again under the same generation. The log gives a `Capture` line per
generation.

### 2. The component table

The capture becomes the **component table**: one plain-ASCII grammar used for the capture file, the wire and the
remote table handed to Lua. In order:

```
SBT <protocol>                                    the wire form only
generation <1 to 2^53>
map /<package path, lowercased>
part <i> <lead|-> <parent|-> <socket|-> <shown 0|1> <bones> <name> <path|->
place <i> qx qy qz qw tx ty tz sx sy sz           parts after 0: placement relative to the parent
material <i> <slot> <path>                        up to 16, slots 0 to 63 rising: an overridden material
names <i> <bone>...                               leaders only: one per bone
```

The capture file also carries the memory addresses the native part reads from (`read`, `effects` and `effect` lines);
those never go on the wire. A **leader** part has bones of its own; a **follower** follows a leader's bones (her
ponytail, for example). Part 0 is her main mesh. A table is at most 64 KiB, and the native parser checks every line
(it is fuzzed by the tests).

### 3. The pose codec

While poses are wanted (the loopback, a recording or a linked friend), `coop_tick` reads and encodes EVE's pose on the
game thread at the send rate, and the worker sends it. A pose message holds:

- a header: `SBP`, the protocol, the table's generation, a sequence number, the sender's clock when the pose was read,
  and a hash of EVE's map;
- the main mesh's world transform: translation as three floats, rotation in 6 bytes, scale in three 16-bit integers;
- each leader's bones in local space, 18 bytes a bone: rotation as the smallest three of its unit quaternion (6 bytes),
  translation in 1/32 cm and scale in 1/4096 (16-bit integers each);
- four effect slots of 15 bytes each: an index into a fixed list of effects (never a path), the part it hangs on, a
  serial for each new instance, and its rotation and translation relative to the part.

A pose is at most 16 KiB; in the outfit measured it is about 4.7 KB. Keyframes only, no deltas. A world position
beyond 1e7 cm, or not finite, is refused.

### 4. Playback clock and interpolation

The receiving side keeps the ghost's last 8 poses and draws her a little in the past, so a late pose still arrives
before it is needed:

- The clock tracks the lowest one-way lag seen (which, between two PCs, includes the offset between their clocks). It
  drops to any lower lag at once and otherwise rises 1 ms a second, so it follows drift both ways. A lag that stays
  250 ms above it for 5 s (a clock step) moves it at once.
- Without jitter she is drawn 1.5 send intervals behind her newest pose. With jitter she is drawn far enough back that
  a late pose is still ahead of her (the recent jitter peak, decaying, capped at 250 ms).
- Between two poses the pose is interpolated. Past the newest one it is extrapolated by at most half an interval.
  After 3 s without a pose the old ones are dropped, so she never slides across the gap.

Poses that belong to no table, or to a table the ghost is not built on yet, are counted **foreign** and not drawn.

### 5. The ghost, built from the table

When a remote table arrives, the native part checks it and hands it to Lua as `coop-remote.txt`. `puppet.lua` builds
the ghost from it:

- The ghost is a **plain actor** with one PoseableMeshComponent per part and no collision. It is not a Pawn, so
  lock-on, AI and saves never see it.
- It is built one mesh a frame, which spreads the loading over several frames. Each part loads the mesh its path names.
  Loading only brings a cooked game asset into memory: nothing is worn or unlocked. Each part keeps the mesh's own
  materials (unless the dyes look is on), so the ghost wears the captured outfit.
- **Path rule.** Only meshes under `/Game/Art/Character/...` and `/Game/DLC_<n>/Art/Character/...` are loaded. A
  friend can never make your game load anything else.
- Parts hang as the table says (parent part, socket, placement), and followers follow their leader. There are no
  morphs (a neutral face) and, without the cloth look, a rigid ponytail. The ghost always draws its highest detail
  level, so it never pops as it walks away.
- The ghost stays hidden until the first pose and after a second without one, so it never stands frozen. Your friend's
  Steam name (or `loopback`, `replay`) stands above it, turned to the camera at each pose; a name tag that fails is
  left out and the ghost stays.
- The same generation with a part hung elsewhere, shown or hidden is applied to the ghost in place. A new generation is
  a new ghost. The `Ghost ... built` log line gives the parts, the meshes loaded and their time, those on the base suit
  (with how many of its bones follow) and those left out.

Lua then names what it built in `coop-display.txt`. Each frame, `coop_tick` writes the leaders' bones into the ghost
behind the engine's own CopyPose write gate, and the main mesh's world transform into a **mailbox**: a scene component
nothing else moves. Right after the native tick, Lua places the ghost's root from the mailbox. A write the engine's gate
refuses is logged once each time the native part takes a new ghost or a new capture generation (`write refused: ...`).

### 6. Fallback: the base suit

A part falls back to the **base suit** when its path is refused by the path rule, when your PC cannot load the mesh (a
DLC you do not own), or when a leader's mesh has other bones than the table's. The body falls back to `CH_P_EVE_08` and
the hair to `EVE_HR_01`, each of the fallback's bones taking hers of the same name. A part with no fallback is left out,
with the parts that follow it. `coop basesuit` forces the base suit for the body and hair.

### 7. Map gate

The ghost is only built when the table's map is the one you are on. Otherwise the log says once
`Ghost hidden: she is on <map>, you are on <map>.`, `coop status` shows `ghost=hidden map`, and the poses that arrive
are counted foreign. After a level change the ghost is removed, and it comes back once your EVE has been in the world
2 s and the maps match. A ghost left standing by a Lua reload (Ctrl+R) is found and removed at the next load.

### Looks

The three looks (cloth, dyes, effects) ride on the same pipeline: dyes add `material` lines to the table, effects fill
the pose's four slots and the native part writes the drawn slots into four boxes beside the mailbox, from which Lua
starts and moves the effects. Effects have their own fault latch, so a fault there turns effects off for the run and
the ghost goes on. See [usage.md](usage.md#looks).

## Safety design

StellarCoop reads and writes game memory, so it is built to fail closed: when in doubt, it stops a feature rather than
risk the game or your saves.

- **Build pin.** Before it reads any engine memory, the native part checks the game's exe against the pinned build
  (Steam build 24463856): its PE time stamp, its image size and 19 code bytes. On any other build the pose path stays
  off (`engine=off reason=...`) and nothing is read. The save slot read and the Night Operation poller also run only on
  the pinned build.
- **SEH guards and fault latches.** Every engine access in `coop_tick` runs under a Windows structured exception guard.
  The first fault latches the feature off for the run and is logged with its code, the DLL offset, the address and the
  part. Effects have a latch of their own. A fault inside Steam in the worker (for example a call racing the game's
  Steam shutdown at exit) stops the link and the pose path for good (`stopped=fault <code>`) instead of taking the game
  down; the log's last line says why the worker stopped.
- **Reads that cannot crash.** The save slot read and the Night Operation poller read through `ReadProcessMemory`,
  which fails rather than faults, and only after a plausibility check of every pointer and count.
- **The game thread never blocks.** `coop_tick` runs once per engine frame (it checks the engine's frame counter) and
  shares only atomics and a lock it never waits on: when the worker holds it, the hand-over waits for the next frame.
  Nothing is allocated under the lock: the worker sizes the pose buffers beforehand and the game thread only swaps
  them. Every 60 s the log gives the tick's cost and, while poses flow, the stream's
  counts.
- **Untrusted input is bounded.** Everything from the other player is checked before use: the table parser and the
  pose decoder (both fuzzed by the tests), the mesh path rule, the channel 1 size and rate limits, and at most 8 effect
  starts a second.
- **No save writes.** The mod never reads or writes a save, the inventory, unlocks or equipment, and nothing is copied
  between two players' games. The only file it reads beside the saves is the co-op marker `StellarCoopSlot.txt`. See
  [saves.md](saves.md).
- **`coop off` is final.** It stops engine access, the link and every feature until the game restarts, even across a
  Lua reload: the native part remembers it.
- **Staying loaded.** The DLL pins itself in memory, so a Lua reload that frees the script's libraries never unloads
  code the worker is running. It also pins Steam's DLLs, so a call in flight at game exit returns into mapped code.

## Loopback, record and replay

These solo tools exercise the whole pipeline on one PC, so most of the mod can be tested without a second player.

- **Loopback.** The native part sends EVE's capture as the table, then her poses, through an in-process delay line
  that stands in for Steam: the one-way delay you give, plus or minus the jitter, with each 1200-byte segment of a pose
  lost at the rate you give (the way Steam's relay fragments a message; one lost segment loses the pose). The line keeps
  order, like a single relay route. What comes back is treated exactly as a friend's: the table is checked and the ghost
  built from it, and the poses are decoded and drawn on the playback clock. Because the ghost is yours, it walks 2 m to
  your right.
- **Record.** What is sent (the table and the poses, as the exact wire bytes) is kept in memory, for up to 120 s or
  24 MiB, and written at the stop to `coop-record.bin`: `SBR` and the protocol, then entries of a kind (`T` a table or
  `P` a pose), a size and the bytes.
- **Replay.** The whole file is read and checked before anything plays (the reader is fuzzed by the tests), then played
  in a loop as the remote side, each pose re-stamped as if sent now. A file made under another protocol is refused.

The commands are in [usage.md](usage.md#solo-testing-loopback-record-replay).
