# How StellarCoop works

For the commands, see [usage.md](usage.md). For the code layout, see [building.md](building.md#repository-layout).

## Lua and native parts

StellarCoop has two parts, both in the mod folder `Mods/StellarCoop/`:

- The Lua part (`Scripts/*.lua`), run by UE4SS on the game thread. It uses UE4SS's object API to read what EVE is made
  of, build the ghost's actor and place it, draw the co-op menu, the chat and your friend's card, marker and arrow,
  show notices, and handle the console and the keys.
- The native part (`StellarCoop.dll`), loaded by the Lua script with `package.loadlib`. It has two entry points:
  - a worker thread, started when Windows loads the DLL. It makes every Steam call, reads and writes the files shared
    with Lua, sends and receives tables and poses, and writes the logs.
  - `coop_tick`, an exported function that the Lua loop calls once per frame on the game thread. It reads and encodes
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
| `notice.lua` | The line of notices above your EVE, used while the on-screen UI is not up |
| `chat.lua` | The session chat: its history (memory only), the feed of chat lines and notices, and the text box |
| `join.lua` | The code box and the host's question about a player who is not her Steam friend |
| `partner.lua` | Your friend's card, marker and off-screen arrow, and the maths that places them |
| `menu.lua` | The co-op menu: draws its pages, takes its keys, runs its rows as `coop` commands, writes and applies settings |
| `ui_model.lua` | The menu's rows and settings, with no engine call |
| `ui_text.lua` | The words of the menu, the chat, the partner HUD, the co-op saves, the join codes, the status line and the notices written in Lua, in the game's 23 text languages |
| `ui.lua` | The UI kit (runtime UMG widgets in the game's look) that draws the menu, the chat and the partner HUD, and the `coop ui test` spike |
| `keybind.lua` | The key settings' grammar and their clash check |
| `settings_file.lua` | Rewrites one line of `coop-settings.txt` and keeps the rest of the file |
| `nightop.lua` | The `coop no` probe, and the heal that the solo run fires |
| `nightop_waves.lua` | The solo run's waves, keys, score, timers and states, with no engine call |
| `nightop_run.lua` | The `coop nightop` solo run: start checks, spawns, the monsters it tracks, its card and result panel |
| `recruiter.lua` | The `coop recruiter` preview |
| `recruiter_text.lua` | The recruiter's lines in the game's 23 languages |
| `unreal.lua` | Small helpers over UE4SS objects |

`main.lua` runs two game-thread loops. One runs every frame: the ghost's build step, `coop_tick`, placing the ghost, the
notice line, the previews' follow-ups, the UI's open and close animations, the game's input given back after the menu or
the chat box closes, and your friend's marker and gauges. The other runs every 250 ms: link status changes, session
start, notices to show, chat lines in and out, Night Operation's run, the UI's root, the menu's rows and status line,
the chat's feed, your friend's card, the capture and the remote table.

### Files shared by Lua and the native part

Apart from the call to `coop_tick`, Lua and the native part exchange data through small files in the mod folder. Each
file is written in full beside its final name and then renamed over it, so the reader never sees half a file:

- Lua writes `coop-request.txt` (a console request), `coop-session.txt` (a new token per Lua load, so the native part
  drops what an older load published), `coop-components.txt` (EVE's capture), `coop-display.txt` (the ghost it built)
  and `coop-state.txt` (whether a save is loaded or the title screen is shown, the send rate, and the synced photo
  mode's state and settings).
- The native part writes `coop-status.txt` (the state Lua and `coop status` read), `coop-remote.txt` (the remote
  table), `coop-link.log` and `coop-report.txt`.
- The chat has two files that exist for a moment only. Lua writes a typed line into `coop-say.txt` once the native
  part has taken the previous one, and the native part takes and deletes it at its next pass (every 5 to 50 ms). The
  native part writes your friend's lines into `coop-chat.txt` (`in <text>`, or `fail` for a line of yours that could
  not be sent) once Lua has taken the previous file, and Lua reads and deletes it every 250 ms. Both files are deleted
  when a session ends, when the native part starts and when the game exits. Chat text is written nowhere else. A crash
  dump (`Saved/Crashes`) holds the game's memory, so it may hold lines of the session.

The full list is in [usage.md](usage.md#files-in-the-mod-folder).

## The Steam link

The link runs in the native worker, through the Steamworks API that the game itself loaded and started (the game's
`steam_api64.dll`, flat API, SDK 1.59). StellarCoop does not start Steam or call `SteamAPI_Init`, and linking changes
nothing in the game or the saves. If one of the Steam functions it needs is missing (another Steamworks build), the
worker and the pose path stop for the rest of the run, and the status file says `missing=<name>`.

One worker thread makes every Steam call. The game's Steam callback thread only stores a few numbers for it. The worker
runs a pass every 50 ms, or every 5 ms while poses flow (the loopback, a recording, a replay or a friend).

### Lobby and invites

- `coop host` creates a friends-only lobby with room for 2 players and opens Steam's invite dialog. With
  `who_can_join=private`, Lua asks for `host private` instead, and the lobby is a private one that only invited friends
  can join. The lobby carries a tag under the key `stellarcoop`: the protocol and the game's Steam build
  (`11:<build>`). A lobby from another protocol or game build is refused on joining, with both versions in the joiner's
  log and on screen. A lobby with no tag is another game's, and is refused as such.
- The native request `host code` creates an invisible lobby (Steam's `ELobbyType` 3): anyone who has its id can ask
  to join, and the host's friends do not see it. Steamworks documents that a lobby search still returns it.
  StellarCoop never searches, and a player who finds it that way waits for the host's answer like any other player
  who is not a friend. No invite dialog opens. The host gets a 7-character join code instead (`CCS-CBMH`), on screen
  and in `coop-status.txt`. The request `copy` puts it on the Windows clipboard. Under Proton, Wine should pass it on
  to the desktop's clipboard; the Wine smoke test checks the Windows side only. `join <code>` joins the lobby it names.
- The code holds the low 32 bits of the lobby id in Crockford's base 32, which leaves out I, L, O and U. Every lobby
  id seen so far starts with the same high 32 bits, `0x01860000`, which the code leaves out. The 3 spare bits hold the
  low part modulo 7, so 89% of the codes with one character wrong are turned away (over 2,000 random ids) instead of
  leading to another lobby. Either case is accepted, I and L read as 1, O as 0, and the dash is optional.
- An accepted invite arrives as a Steam callback, or as `+connect_lobby <id>` on the command line when Steam starts the
  game for it. Either way the game joins only once a save is loaded (Lua writes `world=1` in `coop-state.txt`), so a
  launch never joins from the title screen. Until then the invite is held.
- `coop join` without an id searches your Steam friends for one who is playing Stellar Blade in a lobby.
- The host leads. When the host leaves, the guest leaves too, even though Steam would hand the lobby to them. A lobby
  with more than 2 players is left.
- When a guest's game loses the host's lobby another way, it rejoins automatically: it tries at 2, 12 and 42 s and
  gives up at 60 s. A lobby that is gone or has a new owner by then ends the session.

### Players who are not Steam friends

In any lobby, a player who joins and is not the host's Steam friend waits for the host's answer. The host's game holds
the handshake: it sends no hello and reads none of the player's messages, only pings them so that neither game reports
a lost connection. The host's status shows `pending=<SteamID> <name>` and a notice says that a player who is not a
Steam friend is asking to join. The joiner's game shows `Joined <host>'s game. Waiting to be let in.` The host
answers with native requests, which Lua writes to `coop-request.txt` like the others:

- `allow <SteamID>` lets the player in. The handshake then runs as with a friend, and a rejoin after a drop is let in
  without a new question for as long as the lobby lasts.
- `deny <SteamID>`, or 60 s with no answer, refuses the player, and so does leaving before the answer.
  `remove <SteamID>` refuses any player already in, friends included.
- A refused player gets a `SBC reject` with the reason (`you were not let in`, `no answer within 60 s`, `you were
  removed from this session`). Every build since protocol 9 shows it as `<host> refused the link: <reason>` and leaves. That
  player stays refused until the host creates a new lobby: the host never greets them again, ignores their session
  requests and messages, and sends `you cannot join this session again` each time they come back. Steam has no way to
  remove a lobby member, so a game that ignores the reject keeps the second place in the lobby. It gets the reject
  again every 10 s, and the host can create a new lobby, which gets a new code.
- Answers go by SteamID, so an answer meant for a player who left never reaches the next one. A guest's answers, and
  an answer for a player who is not waiting, are ignored with a line in `coop-link.log`.

On the host, `join.lua` turns the first `pending=` line into a question on screen and writes the answer. It asks each
player once a lobby; with no answer, the native part refuses the player after 60 s. The question opens without a key
press, so it ignores every key for 1 s after it shows, and `main.lua` gives it the arrow keys but not W, S or Space.
`link.lua` keeps in memory which lobby members waited for an answer, for the menu's Remove row, so a Lua reload
forgets them.

None of this adds a line to the protocol: it uses the hello's timing, the ping and the reject.

### Handshake

Once both games are in the lobby, they exchange a hello on channel 0:

```
SBC hello <protocol> <mod version> <game build>
SBC accept
SBC reject <reason>
```

The handshake format is the same in every protocol version, so a peer on another version always gets an answer. A
peer whose protocol or game build differs from yours is rejected, with both versions in the reason, and both leave
the lobby. The side that rejects shows `Version mismatch with <name>: ...`, the other `<name> refused the link: ...`.
The mod version is reported but does not have to match.

A friend who passed the handshake both ways is linked (`peer linked: poses and tables go over Steam` in
`coop-link.log`) while the native pose path is on (`engine=on`) and no loopback or replay runs. The ghost turns on with
the session (the link going from none to host or guest). That publishes your EVE's capture and builds the ghost of
your friend's EVE, which stands where her main mesh is, with no offset.

### Channel 0: text

Channel 0 carries short text messages over Steam's relayed P2P messages (SteamNetworkingMessages). Apart from the
handshake, every message carries the protocol number, and a peer that runs another protocol drops it:

```
SBC12 ping <seq> <ms>
SBC12 pong <seq> <ms>
SBC12 photo <0|1|s> <both|notice>
SBC12 say <text>
SBC12 vit <hp> <max hp> <shield> <max shield> <shield blocks> <beta> <max beta> <burst> <max burst> <tachy> <max tachy> <life>
SBC12 paks <count> <hash>
```

The photo line is sent reliable. It carries the sender's photo mode (`1`, `s` for selfie mode, `0`) and whether their
game may be paused for the other player's photo mode (`both`). It is sent after each handshake and on each change, and
the receiver takes at most 8 a second. While your friend's line says `1 both` and your setting is `photo_sync=both`,
the game thread holds a pause tag of the mod's own in the game's pause set. It sets the tag through the function that
the game's photo mode pauses with (build 24463856 only). [usage.md](usage.md#synced-photo-mode) lists when the pause is
released.

The say line is one chat line, sent reliable. Both games clean it the same way: they keep well-formed UTF-8 only, drop
control, bidi and zero-width characters, trim spaces, and keep at most 200 bytes, never cutting inside a character.
At most 3 lines a second are sent, and at most 10 a second are kept from a friend. The rest are dropped, with one log
line a minute that holds no text. At most 16 received lines wait for the Lua side. The text never goes into
`coop-link.log`, `coop-status.txt`, `coop-report.txt` or the console. When the session ends, the log gets the counts
only: `chat this session: <n> in, <n> out, <n> dropped`.

The vit line is sent unreliable. It carries your EVE's numbers for your friend's partner card, in whole units: HP,
shield and shield blocks, Beta, Burst and Tachy with their maximums, and the life state. It is sent when a number
changes, at most 10 times a second, and once a second otherwise. During a session the native worker reads the numbers
every 100 ms, or 500 ms after a read that took over 1 ms (game build 24463856 only). Each read is eight
`ReadProcessMemory` calls on the worker, never on the game thread, on the EVE that the game's actor manager marks as the
local player. A vit line is invalid if a value is over 10,000,000, HP is over its maximum, there are more than 64 shield
blocks or the life state is over 255. Your friend's last line shows in `coop status` as `mate=` for 3 s.

The paks line is sent reliable, once after each handshake. At start the native part lists the files under
`SB/Content/Paks` (three folders deep) and leaves out the base game's own (`pakchunk<n>-WindowsNoEditor` and
`pakchunk<n>optional-WindowsNoEditor`, `global`). The line carries the number of `.pak` files left and a 64-bit hash of
their paths and sizes, and of their `.ucas` and `.utoc` files. The header of `coop-link.log` names those `.pak` files
(`paks <n> beyond the base game, hash <hash>: ...`). When your friend's hash differs from yours, `coop status` has
`paks=differ <yours> <theirs>` and a notice says so once a session; with the same hash it has `paks=same`. Nothing is
refused: enemies that differ already stay unshared (same character id and maximum HP for each pair).

Say, vit and paks lines from a friend who has not passed the handshake are ignored, without a log line.

Accepted peers ping every 2 s. A peer silent on channel 0 for 10 s is marked lost (`<name> silent for 10 s: lost`)
until they are heard again; they stay linked and their table is kept. A message longer than 512 bytes is treated as
invalid.

A session request from Steam is accepted only after a live check that the requester is a member of your lobby. Any
other request is ignored.

### Channel 1: tables and poses

Channel 1 carries the pose path's bytes unchanged: the component table as text starting `SBT 12` (sent reliable), and
each pose as a binary message starting `SBP` (a keyframe) or `SBD` (a delta), then the protocol byte (sent unreliable,
without Nagle delay). Same-place enemies add a binary message starting `SBE` and the protocol byte, at most 30 a
second (sent unreliable): the place, rotation and animation speed of up to 16 enemies that the sender moves on the
other screen.

- Your table goes to your friend at once and again every 5 s, so a table lost with a broken session, or sent before
  they accepted, arrives with a later resend. An identical table is ignored. A changed capture (a new outfit, the
  blade drawn) goes at once.
- A table of theirs that needs a new ghost (a new generation or layout) is taken at most once every 2 s. One that comes
  sooner is refused (the stream line's `tables: ... refused`) and their next resend brings it.
- Poses go 60 a second by default (`send_rate`, 10 to 60), at most one per game frame: a game running at 45 fps
  sends 45. With deltas, 60 a second took 89 to 131 KiB/s in tests with simulated idle, running and combat motion on a
  5 KB outfit, and 20 a second 40 to 52 KiB/s. The sender holds a pose back while its poses would pass 192 KiB/s
  (176 KiB/s while it also sends `SBE`), under Steam's default send rate of 256 KiB/s.
- Channel 1 passes on only data from a lobby member past the handshake: at most 64 KiB a message, and 240 messages
  and 1 MiB a second per friend. The rest is dropped and counted, with at most one line a minute per friend
  (`dropped pose data from <name>: before the handshake`, `bad size` or `over the rate limit`). A non-member's data is
  logged once (`ignored pose data from <id>: not in our lobby`). Channel 1 traffic does not count as hearing from a
  friend for the 10 s lost check.
- Once they are out of the lobby (`<name> left the lobby`), or you left it, the log says `peer unlinked`, and their
  table and the ghost are removed (`Ghost <generation> removed (her table is gone).`).

### Protocol versions

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
| 8 | The say and vit lines, for the chat and the partner card |
| 9 | Poses sent as deltas against a keyframe (`SBD`) on Steam channel 1 |
| 10 | The shared enemies' scale line: the host's enemy HP and balance multipliers; the paks line |
| 11 | Same-place enemies: `SBE` on Steam channel 1; the show lines, the host's place, aggro and own lines and the guest's own-no lines on channel 2; same spawns' epoch, have, spawn and drop lines; the host's bosses, bstart and phase lines and its summons' spawn lines |
| 12 | Shared quests: the `SBQ` lines on channel 2 (this version) |

### Link health in the log

Every 60 s, `coop-link.log` has one line per linked friend (`<name>, last 60 s: ...`): messages and KB/s in and out on
channel 1, drops, failed sends with the last Steam result (25 means its send buffer is full), the ping's RTT average
and maximum, pings sent and pongs received (the difference is ping loss), and Steam's view of the session: quality
local and remote, send rate, pending unreliable bytes and queue time.

## The ghost pipeline

The ghost goes through the same pipeline whatever its source: a linked friend, the loopback or a replay.

### 1. Capture

When the ghost is on, `capture.lua` describes your EVE once she has been in the world for 2 s (never on a menu
pawn). It only reads. For each skeletal mesh part (up to 16, with up to 1024 bones each) it notes the mesh path, the
part it follows, the part and socket it hangs from, its placement there, whether it is shown, a leader's bone names,
and the map she is on (the package path of her world, lowercased). With the dyes look on, it adds each part's
overridden materials. With the effects look on, it adds what the native part needs to read her effects.

It reads her again once a second. A new mesh (her outfit) starts a new generation. A part hung elsewhere (the blade
drawn or sheathed), shown or hidden is published again under the same generation. The log gives a `Capture` line per
generation.

### 2. The component table

The capture becomes the component table: one plain-ASCII grammar used for the capture file, the wire and the remote
table handed to Lua. In order:

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
those never go on the wire. A leader part has bones of its own. A follower follows a leader's bones (her ponytail, for
example). Part 0 is her main mesh. A table is at most 64 KiB, and the native parser checks every line (the tests fuzz
it).

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

A pose is at most 16 KiB; in the outfits measured it is 4.7 to 5 KB. A world position beyond 1e7 cm, or not finite,
is refused.

Since protocol 9 most poses go as deltas. A keyframe is a full pose as above. A delta has the same header, the age of
its keyframe in microseconds, the world transform, one bit for each bone rotation, translation, scale and effect slot,
and the bytes of those that changed since the keyframe. The sender sends a keyframe first, then every 250 ms, and
whenever a delta would not be smaller. The receiver rebuilds the full pose from the keyframe it holds and decodes it
like a keyframe, so a delta gives exactly the same pose. A delta whose keyframe was lost on the way is dropped and
counted as keyless; the ghost waits for the next keyframe, at most 250 ms later. In tests a delta was 26 % (idle) to
41 % (combat) of the full pose.

### 4. Playback clock and interpolation

The receiving side keeps the last 24 poses (400 ms at 60 a second) and draws the ghost a little in the past, so a late
pose still arrives before it is needed:

- The clock tracks the lowest one-way lag seen (which, between two PCs, includes the offset between their clocks). It
  drops to any lower lag at once and otherwise rises 1 ms a second, so it follows drift both ways. A lag that stays
  250 ms above it for 5 s (a clock step) moves it at once.
- Without jitter the ghost is drawn 1.5 send intervals behind the newest pose. With jitter it is drawn far enough back
  that a late pose is still ahead of it (the recent jitter peak, decaying, capped at 250 ms).
- The send interval is the time between two poses' publications divided by the difference of their sequence numbers,
  so lost poses, or the deltas dropped after a lost keyframe, do not push the ghost further back.
- Between two poses the pose is interpolated. Past the newest one it is extrapolated by at most half an interval.
  After 3 s without a pose the old ones are dropped, so the ghost never slides across the gap.

Poses that belong to no table, or to a table the ghost is not built on yet, are counted as foreign and not drawn.

### 5. The ghost, built from the table

When a remote table arrives, the native part checks it and hands it to Lua as `coop-remote.txt`. `puppet.lua` builds
the ghost from it:

- The ghost is a plain actor with one PoseableMeshComponent per part and no collision. It is not a Pawn, so lock-on,
  AI and saves leave it out.
- It is built one mesh a frame, which spreads the loading over several frames. Each part loads the mesh its path names.
  Loading only brings a cooked game asset into memory: nothing is worn or unlocked. Each part keeps the mesh's own
  materials (unless the dyes look is on), so the ghost wears the captured outfit.
- Only meshes under `/Game/Art/Character/...` and `/Game/DLC_<n>/Art/Character/...` are loaded. This path rule means a
  friend's table cannot make your game load anything else.
- Parts hang as the table says (parent part, socket, placement), and followers follow their leader. There are no
  morphs (a neutral face) and, without the cloth look, the ponytail is rigid. The ghost always draws its highest
  detail level, so it never pops as it walks away.
- The ghost stays hidden until the first pose and after a second without one, so it never stands frozen. Your friend's
  Steam name (or `loopback`, `replay`) stands above it, turned to the camera at each pose. The tag's font has only the
  Latin-1 characters: any other shows as `?`, and a name that would lose more than half its characters shows the
  partner card's word for them instead (`Partner`, in your language when the font has its letters). A name tag that
  fails is left out and the ghost stays.
- The same generation with a part hung elsewhere, shown or hidden is applied to the ghost in place. A new generation is
  a new ghost. The `Ghost ... built` log line gives the parts, the meshes loaded and their time, those on the base suit
  (with how many of its bones follow) and those left out.

Lua then names what it built in `coop-display.txt`. Each frame, `coop_tick` writes the leaders' bones into the ghost
behind the engine's own CopyPose write gate, and writes the main mesh's world transform into a mailbox: a scene
component that nothing else moves. Right after the native tick, Lua places the ghost's root from the mailbox. A write
that the engine's gate refuses is logged once each time the native part takes a new ghost or a new capture generation
(`write refused: ...`).

### 6. Fallback: the base suit

A part falls back to the base suit when the path rule refuses its path, when your PC cannot load the mesh (a DLC you do
not own), or when a leader's mesh has other bones than the table's. The body falls back to `CH_P_EVE_08` and the hair
to `EVE_HR_01`, and each of the fallback's bones follows her bone with the same name. A part with no fallback is left
out, with the parts that follow it. `coop basesuit` forces the base suit for the body and hair.

### 7. Map gate

The ghost is built only when the table's map is the one you are on. Otherwise the log says once
`Ghost hidden: she is on <map>, you are on <map>.`, `coop status` shows `ghost=hidden map`, and the poses that arrive
are counted as foreign. After a level change the ghost is removed. It comes back once your EVE has been in the world
for 2 s and the maps match. A ghost left standing by a Lua reload (Ctrl+R) is found and removed at the next load.

### Looks

The three looks (cloth, dyes, effects) use the same pipeline. Dyes add `material` lines to the table. Effects fill the
pose's four slots, and the native part writes the drawn slots into four boxes beside the mailbox, from which Lua
starts and moves the effects. Effects have their own fault latch, so a fault there turns effects off for the run and
the ghost stays. See [usage.md](usage.md#looks).

## Same-place enemies

Same place (`same_place`, experimental, the host's value, on by default, not tested in game yet) builds on shared
enemies: the same pairs, the same host and the same Steam channel 2. Each pair has an owner, the game whose copy runs
the enemy's AI and moves it; the other game draws its copy (stages 3a and 3b of Phase 11). The host decides the owner.
HP, Shield, balance and death stay with the host's game whoever owns the pair.

- The host's `same_place` decides for both games. The host sends it as `SBF12 place <gen> <0|1>` after its world line
  (and its scale line) while it is on, and again at each change, `coop fight pilot off` and an error included. The
  guest draws her copies only while the host's last place line says 1, and forgets it with the host's next world, on or
  off line. Her own value is not read at a start: her co-op menu row only stops same place on her side, or starts it
  again, while shared enemies wait or run (`coop fight pilot off` and `on`).
- Every pair starts as the host's. With `aggro=game` (the host's setting, the default) the host's job runs a rule on
  each pair every turn: the pair goes to whoever hit it last (a hit on the host's copy, or a claim of hers that
  lowered a stat), and after 10 s without a hit to the other player once that player's EVE has stood at least 3 m
  nearer for 2 s. Nothing changes hands within 4 s of the last change, while an AI task runs on the owner's copy,
  during Down, Groggy, Airborne or a takedown, while the enemy dies, or while the host draws a copy that the game
  froze before the mod did (below: its AI would not run once the host owns it); the start of a takedown is the
  exception (below). Each change moves the owner epoch one up and goes to her as
  `SBF12 own <gen> <hguid> <H|G> <oe>`; the host freezes its copy as it sends own G and thaws it as it sends own H.
  With `aggro=host` the host keeps every pair (stage 3a). The host sends `SBF12 aggro <gen> <game|host>`.
- The guest takes an own G only at her epoch plus one, for a paired copy in life state 1 while same place runs on her
  side, and thaws her copy in that turn. She refuses a copy that the game froze before the mod did (why `state`),
  except for her takedown. Otherwise, and when she can no longer run a pair she owns, she answers
  `SBF12 own-no <gen> <hguid> <oe> <why>`, where why is `unpaired`, `state`, `off`, `epoch`, `aggro`, `full` or
  `target`, and the pair is the host's again. After `off` or `aggro` the host hands her nothing for 30 s, and after any
  other reason not that pair. A world line, an on or an off line starts the epochs over on both sides and ends both
  pauses.
- In the frame a hand-over makes a pair a game's own at a new epoch, its game thread first puts the copy back
  (below), then calls the game's force target function (`FUN_141a36010`) toward its own EVE: detect result 3, aggro
  level 1, and the game's own TargetedByEnemy jobs. The call runs only with the cached net mode 0 (in net mode 3 that
  function would send server requests), no logic task in flight, the two game objects it fetches already made (their
  getters would make them), the copy found by its GUID, its own EVE found and an AI owner on the copy. A task in
  flight or a copy not found puts it off for up to 250 ms. A refused take-over goes back to the job, and the guest
  gives the pair back with `own-no target`. A pair that comes back to the host after an own-no or
  place 0 gets no call: the host's copy keeps the target it had.
- Every 33 ms the owner's game thread reads each enemy it owns: position, rotation, animation speed, BattleMode,
  whether it is dying and whether an AI task runs, into one `SBE` message on channel 1 (26 bytes an enemy, 16 enemies
  at most), stamped with the pose clock. It also walks the game's Show manager (the game's animation sequences) for the
  Shows each enemy starts, and sends `show`, `show-set` and `show-stop` lines on channel 2 with the asset's path and
  the hit context. It never sends a Show that one of its own replays started, so a pair just taken over sends nothing
  back. Only two lookups by GUID are called for this; the rest is plain reads.
- On the drawing side's logic thread, each copy gets the game's own BlockAI effect (2000100, then SkillCancel
  2004400), only in life state 1 and outside NoDamageNoHit. When the game takes it off, the mod puts it back, at most 5
  times in any 10 s (then `freeze-lost`: the copy stays an ordinary enemy). On every way out, and before a kill, the
  BlockAI dispel effect (2000101) takes it off. That dispel would also end the game's own BlockAI, and the game
  freezes some enemies from their spawn until an event of its own (a boss before its cutscene, the sitting LabMutants
  of AYL_02). Timed rows hold the same state too, such as LV_Sequence_Warp_Effect (7000144, 1 s). A copy that already
  holds state 39 when the mod first freezes it gets no effect from the mod and no dispel on the way out
  (`thaw skipped` in the log). When the game's freeze ends, by its own dispel or by running out, the next census finds
  state 39 gone and the mod freezes the copy as any other. A copy whose last dispel the game refused is the exception:
  its state 39 is the mod's, so the mod freezes it and dispels it again (it keeps the last 16 such copies).
- On the drawing side's game thread, each frame, each copy is found again by its GUID. Its movement component goes out
  of the game's parallel movement manager through the game's own function for that (only on the game's class with the
  game's function in that vtable slot), the speed override that the game's own MoveToLocation writes is set to the
  owner's speed, the root moves to the sample at the ghost's draw time, and Velocity follows the samples. Each Show is
  replayed through the game's Show handle API when the draw time reaches its stamp, with its hit context written into
  the new player. A Show that the drawing game started on the copy less than 1 s before (a hit's reaction, a
  mirrored crowd control, its death) and still plays is not replayed a second time.
- A copy that is knocked down, groggy, in the air or in a takedown is released: the game moves it until 200 ms after
  that ends, then it blends back to the stream over 300 ms (a snap beyond 2 m).
- Takedowns (stage 3c). Each pass reads two takedown markers in a copy's effect list, `Check_LinkSkillHit_Skill`
  (5000039) and `LinkState_MonsterHit` (2006004). When one shows on the guest's copy while same place runs on her side
  with `aggro=game`, she sends `SBF12 exec <gen> <hguid> 1`, and `SBF12 exec <gen> <hguid> 0` once her copy has held
  none for 200 ms, or at once when the copy dies or goes (a turn between the two markers ends nothing). The host takes
  one exec 1 an enemy in 2 s, none while one runs, and only when its own copy is a Monster (ActorType 3) in life state 1
  holding Groggy or a marker, or with its balance at 0 after her claims of that turn. It then hands her the enemy
  without the 4 s hold or the guards, in that turn once its copy is out of NoDamageNoHit, freezes its copy although
  Groggy releases it, and holds her lethal claim (its copy at 1 HP, its hp lines at 0) and its own dead for that enemy
  until her exec 0: 6 s after her exec 1 at most, and her lethal claim 6 s after it came at most (`held-expired`). A
  marker on the host's copy of an enemy she owns gives it back to the host the same way. While a takedown runs it counts
  as its executor's hit, so a living enemy stays with them for 10 s after it unless the other player hits it. The guest
  takes an own G for a copy in her takedown even under NoDamageNoHit.
- The owner's SBE entry carries flag 8 (`kExec`) while its copy holds a marker. The drawing side then freezes its copy
  despite Groggy, follows the stream through Groggy and through the stream's dying flag, and goes back onto the stream
  at once instead of after 200 ms, so the takedown plays there with the executor's ghost. Its own copy's death still
  releases it. Nothing in the mod starts `Passive_FinishReady` (2001102), and the host refuses an exec line for a
  BossMonster. The game still applies 2001102 by itself to a boss in a Finish stance, on her copy too; the finish
  guard ([Shared bosses](#shared-bosses)) takes it off her copy and holds her killing hit on the host's boss.
- Every way back puts each copy back in this order: its replays stopped, Velocity zeroed, the movement component back
  in the manager if it was there, the speed override as it was; then the freeze comes off. The game-thread part has
  its own SEH latch: the first fault stops it for the run, and after a fault in the mod's own reads every copy is put
  back once.
- `coop fight pilot test` limits the guest's side for solo tests from a recording: `freeze` (the BlockAI effect only),
  `cmc` (the movement component out too, nothing written), `drive` (root, speed and Velocity too) or `replay` (all of
  it, the default). Each change puts every copy back once. `coop fight pilot test target` calls the force target once,
  on the first enemy this game owns, and logs its target, aggro level and detect result as they change for a second.
  `coop fight pilot test exec` empties the balance of the first frozen copy this game draws at the job's next turn
  (a stamina drop, as a hit of its EVE), so the copy goes groggy and can be taken down.

The commands, the notices and the solo test are in [usage.md](usage.md#same-place-experimental).

## Same spawns

Same spawns (`same_spawns`, experimental, the host's value, on by default, not tested in game yet) has the guest's game
hold the host's common enemies in a zone where both players stand. It builds on shared enemies: an enemy it creates
pairs through its spawn key like any other.

- Only EventSpawnTable rows that spawn on zone entry (SpawnType EnterZone), whose enemy is a Monster that shared
  enemies share (`fight_chars`, or with `auto` every Monster but the few it leaves out) and whose SaveType is None,
  ResetZone or ResetZoneWithTransform take part. Save and SaveWithTransform rows, rows that keep
  their object through a zone reset (`bResetZoneKeepObject`), and ZoneEvent and quest rows are never touched. Each
  game reads a row through the game's own lookup (`FUN_141a9db80`) and the row's zone through the ZoneTable lookup
  (`FUN_141a9b8a0`), and keeps what it read for the session. The game runs a row's lazy init (vtable slot `+0x20`)
  before its first use; in this build that slot is an empty function for both row types, so reading the rows without
  it skips nothing.
- Zones travel as ZoneTable row IDs: a zone's name is an FName, whose index differs between two processes.
- Each game counts its own epoch: one more when its current zone (logic `+0x598`) changes, when the game's spawn
  manager starts entering or resetting a zone again (its `+0x1c` goes to 1 or 2 after 3 or 4), and when 3 or more of
  its enemies come back under new GUIDs in one census (two enemies of one key are no change). The host sends `SBF12
  epoch <gen> <zone> <n>` at each change and every 5 s, so a line lost on the way stalls nothing for long, and each
  side drops a line of another epoch.
- The zone is shared while both games are in the host's zone, each settled 3 s after its last epoch began with no
  spawn pass running, and the other EVE (as its ghost stands) is within 100 m. The guest then sends her keys there as
  `SBF12 have <gen> <n> <part> <parts> <spawnId>:<idx> ...`, 24 keys a line and 10 lines at most, at once at a new
  epoch and every 5 s after. The host answers one round each 500 ms at most: `SBF12 spawn <gen> <n> <spawnId> <idx>
  <charId> <x> <y> <z> <yaw>` for each of its Monsters there she lacks within 1 km of her EVE (as her ghost stands in
  the host's world; never a dying one), where it stands in whole
  centimetres, and `SBF12 drop <gen> <n> <spawnId> <idx>` for each key of hers it lacks, 16 of each a round.
- The guest checks each line: the epoch, the shared zone, the row in her own tables and its zone, a place within 1 km of
  her EVE, no enemy of hers with that key, and 32 calls a second at most. She creates a key through the game's spawn
  function on its spawn manager (`FUN_141c1c9a0`, as `FSBCreateActor` does) and removes one through the game's despawn
  job (`FUN_141b077f0`, as a ZoneEvent despawn does): never a kill, and never an enemy that shared enemies pair. A
  created enemy that shows up as no Monster, or as another character than the host's, is removed again, within the same
  32 calls a second. One the despawn cannot find again (a dying one, for example) stays and is logged as kept. A key she
  refused counts as hers in her next list, so the host stops asking for it until the epoch moves. A key refused as too
  far or for room (`full`) is left out of the list, so the host asks again once she is nearer or has room, and an enemy
  she created leaves the list once it has died or left her game.
- Both calls run inside the shared fight's job on the logic thread, under its fault latch. The spawn manager, the table
  holder and the job sender are read from their globals and never made by the mod: their getters (`FUN_141adc3d0`,
  `FUN_141a97f20`, `FUN_141a97b90`) allocate one when it is missing. The spawn call gets the spawn manager, the
  EventSpawnId, the SpawnIndex, the position, the rotation (0, yaw, 0), no extra request data and flag 0 (what the flag
  does is not known yet). `FUN_141c1c9a0` itself passes a delay of 0 to `FUN_141c1ca40`, so the key spawns at once. It
  reads the table holder through its getter, and for a row with EventOnSpawning events it sends them through the job
  sender's getter. The spawn it starts reaches `NewActor`, whose actor setup reads the reg through `FUN_141a97cb0`. So
  the guest calls it only while the holder, its tables, the job sender and the reg exist; with the spawn manager or
  one of those not made she refuses the key (`no spawn manager`) and calls nothing. The despawn call gets the job
  sender, the logic turn and the enemy's GUID, after the enemy is found again by GUID with that key and still fighting.
  While that enemy holds BattleMode (state 30) or runs a takedown marker, or either read fails, she refuses the drop
  (`busy`): the enemy stays in her list, so the host asks again and the despawn goes once she is done with it. A census
  whose list of enemies came out partial (a read that failed, or more than 256 enemies with spawn keys) does nothing,
  since an enemy missing from it would read as one the game lacks.
- The `fight=` line of `coop-status.txt` carries `spawns=off`, `on` or `stopped` (the pilot's latch stops same spawns,
  since the ghost's position no longer reaches the job), and on the guest's side `spawned=`, `despawned=` and
  `spawns_differ=`: the refusals, and the created enemies undone or kept, whose reason shows that the two games' tables
  or `fight_chars` differ (`no row`, `save-row`, `keep-row`, `event-row`, `another zone`, `row taken`, `not shared`,
  `charId`), not those of the moment (`too far`, `full`, `no spawn manager`, `not made`, `gone`, `busy`, `no such
  enemy`). Lua's notices read it.
- `coop fight spawn probe` (`fight probe spawns`) runs the same census, epoch and row reads in the probe's job on one
  game, and logs the outcome for each shared Monster once an epoch, 32 a census at most so that one hand-over's 128 log
  lines are enough. It sends no line and calls neither the spawn nor the despawn function.

The log lines are in [usage.md](usage.md#same-spawns-experimental).

## Extra enemies

Extra enemies (`enemy_extra`, 0 to 3, the host's value, 0 by default, not tested in game yet) build on same spawns:
the host's game makes that many more of each common enemy where both players stand, and same spawns hand them to the
guest's game like any other key of the host's that she lacks.

- The host gives extras to a Monster that shared enemies share, of a row that same spawns reconcile (an EnterZone row
  that is no Save or keep row: the guest's save may hold that enemy dead), not dying, within 116 m of either EVE (so
  its farthest extra stands within 120 m), while the zone is shared. Bosses and Alpha Naytibas are BossMonsters
  (ActorType 4), so they get none, and neither do the four Monsters the CharacterTable ranks Boss or Elite: M_Gorgon
  (50330), M_RoyalGuardFemale (50500) and its WLA_ and WLB_ variants (45050001, 55050001). An enemy gets its extras
  once a life: after a respawn under a new GUID it gets new ones. Extras are made only while the shared Monsters within
  120 m of either EVE, counted with the host's extras and the new ones, stay at 16 or fewer, the most stage 1 can
  pair.
- An extra's key is EventSpawnId `0xE0000000 | n << 8 | slot` and SpawnIndex `slot`, where n counts the enemies given
  extras since the game started (a new session goes on counting, so a dying extra of the last one never shares a key
  with a new one) and slot runs from 1 to 3. No EventSpawnTable row of this build is in that range (its highest
  EventSpawnId is `0xD42B5F51`). The host checks once a session that its tables hold no row at the first key,
  `0xE0000101`; if they do, extras stay off for the session. The game's death path skips the respawn and the zone
  bookkeeping for an actor whose key has no row; that a save never holds one is still to be checked in game.
- Slot s stands 100 + 100 s cm from its enemy (2, 3 or 4 m), 120 degrees apart around the enemy's yaw, at the
  enemy's height and facing its way. The game's `NewActor` (`FUN_141ad1290`) makes it, with the arguments
  `SpawnRequest::Execute` passes: the logic singleton, the charId, the position, the rotation (0, yaw, 0), not a
  player (0, 0), the key, 0 for the row field, 0, 1, no request extra data, 0, flag 0 (no actor replaced) and 0. The
  request extra data is null because the game's FSBActor creation (`FUN_141ca9100`) checks it for null and then keeps
  the same default a fresh request would copy in.
- Same spawns count an extra's key as part of the shared zone without a row: the host sends `spawn` for one she lacks
  and `drop` for one of hers it lacks. She makes the key through `NewActor` too, with the charId of the host's line,
  and refuses it (`row taken`) when her own tables hold a row at that key, or (`no such enemy`) when no Monster of
  hers that shared enemies share has that charId: the host makes extras of common enemies only, so any other charId
  would be a character the host picked freely. A key refused as `no such enemy` or `full` is left out of her list, so
  the host sends it again: an extra's own enemy can come in the same answer and only show in her next census. Stage 1
  then pairs the two copies by key.
- Each game keeps the extras it made in its capture list, 48 at most. One that left the map (killed, despawned) is
  forgotten at the next census. The host despawns one still fighting more than 120 m from both EVEs. At the session's
  end every extra still fighting is despawned in each game, and a dying one is left to its death. The host's extras
  also go when her shared enemies stop (her off line) or her lines are ignored, and hers when the host's same spawns
  stop on her side (its off or world line). Every despawn goes through the game's despawn
  job (`FUN_141b077f0`), never a kill.
- `NewActor` runs inside the shared fight's job on the logic thread, under its fault latch, only while the table
  holder, the world's actor manager, the job sender and the reg exist: `NewActor` and its actor setup
  (`FUN_141ba6d20`) read them through getters that would make them (the job sender's `FUN_141a97b90` and the reg's
  `FUN_141a97cb0` for the last two). An extra whose GUID cannot be read right after `NewActor` stops the shared fight
  for the run and is logged as kept, since no capture can take it off.

The log lines are in [usage.md](usage.md#extra-enemies-experimental).

## Shared bosses

Shared bosses (`bosses`, experimental, the host's value, on by default, not tested in game yet) add the bosses and
Alpha Naytibas (the game's BossMonster type, ActorType 4) to the pairs of shared enemies. A boss takes a place before
any common enemy, its maximum HP takes the host's `boss_hp_scale`, and with same place on its AI stays in the host's
game. The host sends `SBF12 bosses <gen> <percent>` with its list.

With same place on, the guest's copy of a boss is frozen and never casts a skill, so on its own it would never enter
battle mode, change phase or summon anything. The host's job reads them on its own copy and tells her game, which
applies them to her copy:

- The host reads its boss's battle mode (FSBActor `+0xb58`) and sends `SBF12 bstart <gen> <hguid>` when it turns on,
  then every second while it stays on. The guest calls the game's SetBattleMode wrapper (`FUN_141a7cd30`) on her copy,
  once while the copy stays in battle mode, with the arguments of the game's own `FSBActor::AddTargetedByEnemy`: on,
  then `0, 0, 0, 1`. The fifth argument, 0, runs the boss's `EventOnBattle` (mostly the arena walls), and the call runs
  `EventFirstTimeOnBattle` once. Called from the logic thread, the game queues it for its game thread. She calls it only
  for a copy her game draws as a BossMonster in life state 1, with the job sender and the reg already made (the call
  reads both through getters that would make them). A refused bstart is taken at the host's next repeat. Her game takes
  the copy out of battle mode through the same wrapper with off, then `0, 0, 1, 1`, the arguments of the game's own
  battle-off calls: when the host's lines bring no bstart for 10 s (the host's boss left battle mode; a gap of over 2 s
  with no line from the host, as while the host's game is paused, is not counted), when her game stops drawing the copy
  (the pair ends, same place stops) and when the session ends (`coop fight off`, the link, the fault latch). A dying
  copy gets no call. The host's next bstart for that copy calls it again.
- The host reads its boss's effect list and keeps the rows of that boss's allowlist, a table built from the game's
  tables for build 24463856: its phase rows and their FX rows that a skill applies, and its MinimumHP rows (the phase
  thresholds, and `MinimumHP_Dispel` 1001323). It sends them in list order as `SBF12 phase <gen> <hguid> <oe>
  <id,id,...|->` when they change and every second in battle mode. The guest refuses a line with an ID her own table
  does not hold for that boss (a bad line), of another owner epoch, or for a copy her game does not draw. Through the
  game's effect call (`FUN_141ad08b0`), her copy its own caster as for the boss's own skill step, she applies each row
  that came into the host's set since her last line for that copy, in the host's order, a dispel row first (the host's
  copy holds a row next to the dispel that would end it only when that row started later). On her first line for a
  copy, and on the line after the game refused one of her rows, she compares the set with her copy's effect list
  instead: each row the copy lacks has come, and each row of the allowlist it holds that the set lacks has left. Before
  them she applies `MinimumHP_Dispel` when a threshold left the set and none came in, and the boss's phase dispel row
  (Crawler 5022094, SkullJuggernaut 5015002) when a phase row left and none came in. The phase row's own stance change
  does the rest on her copy. 19 bosses have a row in the table; the other BossMonsters (the
  Alpha Naytibas, challenge and variant rows) get bstart lines only.
- At each census the host looks for actors with no spawn key whose owner (logic actor `+0x400`) is a boss it shares,
  and finds the SummonActor row that made each one in the owner's effect list, by the effect GUID at `+0x40c` (an
  effect's GUID is at its `+0x20`). Marionette's DollHeads and Maelstrom's BodyBags have rows in the table. The reward
  dummies and the Elder's dummy have none and stay in the host's game. A summon gets a key in the summon range,
  EventSpawnId `0xF0000000 | n` and SpawnIndex 0, where n counts the summons since the game started, and joins the
  shared list under it. After its up the host sends `SBF12 spawn <gen> <n> <key> 0 <charId> <x> <y> <z> <yaw> <owner
  hguid> <row>`, with epoch 1 when same spawns do not run, and sends it again every second while it follows the
  summon: her game takes a repeat as one it has, and a line it refused for a passing reason (its boss not paired yet)
  can go through later. The guest makes it through `NewActor`, as for extra enemies,
  with that key where the host's stands: only within 1 km of her EVE, for an owner she pairs as a BossMonster, and for a
  row of her table that makes that charId. She then applies the row's effects through the effect call (its Start row,
  which holds the summon still for a moment, and its Check row), and the pair forms on the key; same place freezes and
  drives it like any other copy. If the game refuses one of those effects, she despawns the summon at once: without
  them her hits would take far more HP than the host's copy loses. A summon of hers that no pair holds 3 s after she
  made it is despawned too, and so is every one still fighting when the session ends. A key she despawned for either
  reason is not made again until the next on, off or world line of either game. She holds 32 at most at once.
- A Finish stance (HP under 2) applies `Passive_DeathReady` (2001101), which chains `Passive_FinishReady` (2001102, the
  state the finisher needs). In each turn a paired boss copy of hers holds either one, her game applies
  `FinishReady_Dispel` (2001103) and then the boss's own `Passive_Immortal` (2001100) again: her hits stop at 1 HP and
  no finisher starts on her side. On the host's side, her claim that would kill a boss whose copy holds either row takes
  it down to 1 HP and kills nothing, however long the stance lasts (`fight finish-held`). So a boss in its Finish stance
  ends only by the host's finisher; a boss without one dies of her killing hit, unless its own thresholds or Immortal
  hold it. When the host's `dead` comes for a boss, her game applies `MinimumHP_Dispel` and `FinishReady_Dispel` to her
  copy before the kill, so neither a threshold nor Immortal holds it. When the pair ends any other way (the host's
  `down` or world line, the link, `coop fight off`, the fault latch), her game applies `FinishReady_Dispel` to a guarded
  copy still under 2 HP, so the Immortal it put back goes and her own hit ends that boss in her game.
- Every call runs inside the shared fight's job on the logic thread, under its fault latch. The host's side makes no
  new game call: it reads, and her claims go through ApplyStat as before. Recordings keep none of these lines.

The log lines are in [troubleshooting.md](troubleshooting.md#a-shared-boss-differs-between-the-two-games).

## Shared quests

Shared quests (`shared_quests`, experimental, off by default, not tested in game yet) move the guest's quests to the
host's state through the game's own quest functions, one step at a time, for the steps the two players make together.
`quest_sync.h` holds the line format, the quest table and each side's rules; `quest_engine.h` holds the reads and calls
on the game's quest data and the worker's side.

The game's quest manager runs on the game thread, so the mod's pass does too: every 250 ms `coop_tick` reads the local
player's quest unit (the quest manager at `0x147032588`, its unit from `FUN_141c5e880`) under the shared quests' own SEH
latch. The pass walks the unit's three quest arrays (in progress, complete, failed) and its ID map, and for each shared
quest reads its state, its active group and the state of each task the game made for it. Before each pass and each call
it checks that it is not on the game's logic worker thread (whose ID the game keeps at `0x1470634f0`) and that the save
is still the co-op save it started on: another save ends the side with `SBQ12 off slot` (the worker starts a new one
on the next co-op save), while a load (the title screen, a map change) only pauses it.

- The host only reads. Each quest whose state changed goes to the guest as one reliable line on channel 2 with the
  whole state, numbered per quest, so a repeated or late line changes nothing: `SBQ12 q <gen> <seq> <id> <state>
  <acquire mark> <finished groups> <tasks done> <done mark>`. A group or a task is named by its place (container and
  position), which the game builds the same on both PCs from the same tables.
- Each step carries a mark that says where it may be made: `-` anywhere (no zone event, or only quest, item, UI or
  hint events), `t` in the zones the game's tables give for its events (spawns, despawns, environment changes, scenes),
  `z<n>` in the zone where the host stood when its pass saw the step (for the 38 steps the tables cannot place), `?`
  for such a step the host's pass did not see, `K` for a kill task and `#` for a quest the host denies. The table that
  gives each step's class, zones and events is built into `quest_sync.h` from the tables of build 24463856; another
  game build needs it built again.
- The guest's pass compares each host line with her own quest and plans the next forward step: an Epic or Sub quest
  she lacks is acquired by ID (`FUN_141c5cf20`, the call a quest zone event makes), a Request on her board is accepted
  with the board's own call (the Request quest's vtable `+0x10`), and a task is completed through its own Complete
  (task vtable `+0x60`). There is no quest-complete call: an Epic or Sub quest completes inside its last task's
  Complete, with its reward and next quest, and a Request stops ready to hand in, as in solo play.
- Each call has its guards, read again just before it: a task only at state 1 in her active group, whose parent is
  that group and whose Complete slot is one of the game's two Complete functions; an acquire only for an ID her quest
  map does not hold (the game refuses any other too, and after each load the pass checks that every complete and failed
  quest is in that map before it acquires anything); a Request accept only at state 0 on a Request her board accepts.
  A step the game refuses leaves that quest alone for the session. At most one step goes per pass.
- A step is the guest's only when she stood in the host's zone when its line came and her quest stood where the host's
  stood before the step. A quest the host moved without her is behind: nothing of it is planned, a forced step
  included, until her own play brings it to the host's state.
- The guest sends display lines only: `at` (her zone), `have`, `wait <why>` and `ahead`. The host applies nothing from
  them.
- When the guest's side comes on, the host sends a snapshot (`snap`, the `zone` and `q` lines, then `end` with their
  count and an FNV-1a digest) of the quests it moved while linked with that friend. It sends a new one after its own
  load, and when one of its quests goes back (an older save).

The record beside each co-op slot (`StellarCoopQuests0N.txt` in the account's save folder) keeps, per friend, the
host's marks (`h` lines) and the host lines the guest's game took (`g` lines). The worker writes it through the same
name check as the co-op copies, at most once a second and only on a change, as a temporary file renamed over the old
one. A bad line only loses that quest's marks; her live quests always decide what is made.

## Safety design

StellarCoop reads and writes game memory, so it fails closed: a failed check or a fault stops the affected feature or
drops the input.

- Before it reads any engine memory, the native part checks the game's exe against the pinned build (Steam build
  24463856): its PE time stamp, its image size and 19 code bytes. On any other build the pose path stays off
  (`engine=off reason=...`) and nothing is read. The save slot read, the vitals read for the partner card and the
  Night Operation poller also run only on the pinned build.
- Every engine access in `coop_tick` runs under a Windows structured exception (SEH) guard. The first fault latches the
  feature off for the run and is logged with its code, the DLL offset, the address and the part. Effects have a latch
  of their own. A fault inside Steam in the worker (for example a call racing the game's Steam shutdown at exit) stops
  the link and the pose path for the rest of the run (`stopped=fault <code>`) instead of crashing the game. The log's
  last line gives the reason the worker stopped.
- The save slot read, the vitals read and the Night Operation poller read through `ReadProcessMemory`, which returns an
  error instead of faulting, and only after a plausibility check of every pointer and count.
- `coop_tick` never blocks the game thread. It runs once per engine frame (it checks the engine's frame counter) and
  shares only atomics and a lock it never waits on: when the worker holds the lock, the hand-over waits for the next
  frame. Nothing is allocated under the lock: the worker sizes the pose buffers beforehand and the game thread only
  swaps them. Every 60 s the log gives the tick's cost and, while poses flow, the stream's counts.
- Everything from your friend's game is checked before use: the table parser and the pose decoder (both fuzzed by the
  tests), the mesh path rule, the channel 1 size and rate limits, and at most 8 effect starts a second.
- The co-op save copies (`StellarBladeCoop00.sav` to `04.sav`) are made only on a `saves convert`, `saves coop` or
  `saves refresh N` request (the question on the title screen, `auto_coop_save=always` or `coop saves`), and only at the
  title: Lua reports the title screen (`world=title` in `coop-state.txt`), no save is loaded, and Continue or Load Game
  was not chosen (the game's load mode is 0). A pass checks this again before each file and before the switch. The
  native part reads your saves and writes each copy as a `.coop-tmp` file, renames it over the copy and reads it back.
  One name check guards every write: only the copies, their temporary files, `StellarCoopSaves.txt`, the shared quests'
  records `StellarCoopQuests00.txt` to `04.txt` and the backup in `StellarCoopBackups` pass it. The backup is taken
  before any copy whenever `StellarCoopSaves.txt` does not exist yet, and a refresh backs up the copy it replaces first.
  The switch to the copies is one 8-byte compare-and-swap in the game's memory, on the pinned build only, read back
  every 250 ms; an entry that moves or changes stops it for the run.
- Except for those copies, the mod never reads or writes a save, the inventory, unlocks or equipment. Apart from enemy
  stats with the experimental shared enemies (`coop fight`, on by default, co-op saves only), their positions and
  animations with the experimental same place (on by default), and the quest steps of the experimental shared quests
  (off by default, co-op saves only, made by the guest's game through its own quest functions), nothing is copied
  between the two players' games. Beside
  the saves it reads only the co-op marker `StellarCoopSlot.txt` and the copies' manifest `StellarCoopSaves.txt`; Lua
  only checks whether a copy exists, opening none of your own saves. See [saves.md](saves.md).
- `coop off` stops engine access, the link and every feature until the game restarts, even across a Lua reload,
  because the native part keeps the flag.
- The DLL pins itself in memory, so a Lua reload that frees the script's libraries never unloads code the worker is
  running. It also pins Steam's DLLs, so a call in flight at game exit returns into mapped code.

## Loopback, record and replay

These solo tools run the whole pipeline on one PC, so most of the mod can be tested without a second player.

- The loopback sends EVE's capture as the table, then her poses, through an in-process delay line in place of Steam. It
  applies the one-way delay you give, plus or minus the jitter, and loses each 1200-byte segment of a pose at the rate
  you give (Steam's relay splits a message the same way, and one lost segment loses the pose). The line keeps order,
  like a single relay route. What comes back is handled exactly like a friend's data: the table is checked and the ghost
  built from it, and the poses are decoded and drawn on the playback clock. Because the ghost is yours, it walks 2 m to
  your right.
- A recording keeps what is sent (the table and the poses, as the exact wire bytes) in memory for up to 120 s or 25 MiB,
  and writes it to `coop-record.bin` when it stops. The file holds `SBR` and the protocol, then entries of a kind (`T` a
  table, `P` a keyframe, `D` a delta, `E` a same-place enemies' `SBE` or `S` a show line), a size and the bytes.
  `SBE` messages and show lines come after the first pose and are re-stamped with the poses on replay. A show line over
  493 bytes is not recorded: its new time can be up to 19 digits longer, and past 512 bytes the line would lose its
  hit context.
- A replay reads and checks the whole file before anything plays (the tests fuzz the reader), then plays it in a loop as
  the remote side, each pose re-stamped as if sent now. A file made under another protocol is refused.

The commands are in [usage.md](usage.md#solo-testing-loopback-record-replay).
