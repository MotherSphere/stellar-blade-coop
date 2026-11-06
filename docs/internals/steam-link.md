# The Steam link

The link runs in the native worker, through the Steamworks API that the game itself loaded and started (the game's
`steam_api64.dll`, flat API, SDK 1.59). StellarCoop does not start Steam or call `SteamAPI_Init`, and linking changes
nothing in the game or the saves. If one of the Steam functions it needs is missing (another Steamworks build), the
worker and the pose path stop for the rest of the run, and the status file says `missing=<name>`.

One worker thread makes every Steam call. The game's Steam callback thread only stores a few numbers for it. The worker
runs a pass every 50 ms, or every 5 ms while poses flow (the loopback, a recording, a replay or a friend).

## Lobby and invites

- `coop host` creates a friends-only lobby with room for 2 players and opens Steam's invite dialog. With
  `who_can_join=private`, Lua asks for `host private` instead, and the lobby is a private one that only invited friends
  can join. The lobby carries a tag under the key `stellarcoop`: the protocol and the game's Steam build
  (`19:<build>`). A lobby from another protocol or game build is refused on joining, with both versions in the joiner's
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

## Players who are not Steam friends

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

On the host, `session/join.lua` turns the first `pending=` line into a question on screen and writes the answer. It asks
each player once a lobby; with no answer, the native part refuses the player after 60 s. The question opens without a
key press, so it ignores every key for 1 s after it shows, and `main.lua` gives it the arrow keys but not W, S or Space.
`core/link.lua` keeps in memory which lobby members waited for an answer, for the menu's Remove row, so a Lua reload
forgets them.

None of this adds a line to the protocol: it uses the hello's timing, the ping and the reject.

## Handshake

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

## Channel 0: text

Channel 0 carries short text messages over Steam's relayed P2P messages (SteamNetworkingMessages). Apart from the
handshake, every message carries the protocol number, and a peer that runs another protocol drops it:

```
SBC19 ping <seq> <ms>
SBC19 pong <seq> <ms>
SBC19 photo <0|1|s|c> <both|notice>
SBC19 say <text>
SBC19 vit <hp> <max hp> <shield> <max shield> <shield blocks> <beta> <max beta> <burst> <max burst> <tachy> <max tachy> <life>
SBC19 pak <hash> <name>
SBC19 paks <count> <hash>
SBC19 camps? <id>
SBC19 camps <id> <world> <camp>:<m> ...
SBC19 camps <id> none <title|loading|nocamp|busy>
SBC19 night h <n> <run> <seed> <phase> <wave> <run time ms> <score> <kills> <clears> <found> <x> <y> <z> <yaw> <map> <end> <level> <down> <help>
SBC19 night g <n> <run> <state> <up> <killed> <done> <why> <down> <help>
SBC19 mark <n> [<text>]
SBC19 race <text>
SBC19 gift s <id> <item> <count>
SBC19 gift a <id>
SBC19 gift n <id> <why>
```

The photo line is sent reliable. It carries the sender's photo mode (`1`, `s` for selfie mode, `0`) and whether their
game may be paused for the other player's photo mode (`both`). It is sent after each handshake and on each change, and
the receiver takes at most 8 a second. While your friend's line says `1 both` and your setting is `photo_sync=both`,
the game thread holds a pause tag of the mod's own in the game's pause set. It sets the tag through the function that
the game's photo mode pauses with (build 24463856 only). [../playing-with-a-friend.md](../playing-with-a-friend.md#synced-photo-mode) lists when the pause is
released. A host's line says `c` while a cutscene plays in its game and its own photo state is `0`
([Cutscene wait](group-play.md#cutscene-wait)).

The say line is one chat line, sent reliable. Both games clean it the same way: they keep well-formed UTF-8 only, drop
control, bidi and zero-width characters, trim spaces, and keep at most 200 bytes, never cutting inside a character.
At most 3 lines a second are sent, and at most 10 a second are kept from a friend. The rest are dropped, with one log
line a minute that holds no text. At most 64 received lines, chat and race lines together, wait for the Lua side. The
text never goes into `coop-link.log`, `coop-status.txt`, `coop-report.txt` or the console. When the session ends, the
log gets the counts only: `chat this session: <n> in, <n> out, <n> dropped; race lines: <n> in, <n> out, <n> dropped`.

The vit line is sent unreliable. It carries your EVE's numbers for your friend's partner card, in whole units: HP,
shield and shield blocks, Beta, Burst and Tachy with their maximums, and the life state. It is sent when a number
changes, at most 10 times a second, and once a second otherwise. During a session the native worker reads the numbers
every 100 ms, or 500 ms after a read that took over 1 ms (game build 24463856 only). Each read is eight
`ReadProcessMemory` calls on the worker, never on the game thread, on the EVE that the game's actor manager marks as the
local player. A vit line is invalid if a value is over 10,000,000, HP is over its maximum, there are more than 64 shield
blocks or the life state is over 255. Your friend's last line shows in `coop status` as `mate=` for 3 s.

The pak and paks lines are sent reliable, once after each handshake. At start the native part lists the files under
`SB/Content/Paks` (eight folders deep, 4096 files at most) and leaves out the base game's own
(`pakchunk<n>-WindowsNoEditor` and `pakchunk<n>optional-WindowsNoEditor`, `global`). The `.pak`, `.ucas` and `.utoc`
files of one name make one mod container, and each container goes in a pak line: a 64-bit hash of its files' paths and
sizes in 16 hex digits, then its name, which is its path from `SB/Content/Paks` in lower case with `/`, without the
extension (`logicmods/hd-atool_p/hd-atool_p`). In a name, spaces, commas and bytes outside printable ASCII become `_`,
and it keeps 100 bytes at most. Up to 256 containers go, sorted by name; with `mod_names=off` in `coop-settings.txt`,
none. The paks line comes last and ends the list. It carries the number of `.pak` files left and a 64-bit hash of their
paths and sizes, and of their `.ucas` and `.utoc` files. The header of `coop-link.log` names those `.pak` files
(`paks <n> beyond the base game, hash <hash>: ...`).

When your friend's hash differs from yours, `coop status` has `paks=differ <yours> <theirs>`; with the same hash it
has `paks=same`. When their list came with names, three lines follow it: `mods_missing=<n> <names>` (theirs that you
lack), `mods_other=<n> <names>` (the same name with another hash: another version) and `mods_extra=<n> <names>`
(yours that they lack). Each line has the count, then the first names separated by commas, 400 bytes at most.
`coop-link.log` names the ones you lack and the other versions each time their list changes
(`<name> has mods we lack (<n> <names>) and mods we have in another version (<n> <names>)`). Once a session, a notice
names the mods you lack and then the other versions, up to two file names each (see
[../shared-enemies.md](../shared-enemies.md#shared-enemies-experimental)). Without names, or with only mods of yours that they lack, the notice
gives the two counts. Nothing is refused: enemies that differ already stay unshared (same character id and maximum HP
for each pair).

The same scan counts the CNS packs (`*.dekcns.json` files of the Custom Nanosuit System under `~mods`, 256 at most,
the first MiB of each) and their outfits (their `UniqueFitID` keys). With at least one pack, the header of
`coop-link.log` has `cns <n> packs, <m> outfits, <k> assets`, the status a `cns=<n> <m>` line, and the Lua side logs
`CNS detected (<n> packs, <m> outfits)` and adds those words to `coop status`.

The scan also lists the assets the packs declare: each `/Game/...` string given as the value of an `OutfitPaths`,
`Mesh`, `Materials`, `PonyPhysics`, `Textures` or `Value` key (or in an array under one), 255 printable bytes at most,
8192 at most in all, each with the `UniqueFitID` given last before it. It is a bounded scan of the text, not a JSON
parser: it tells strings (with their escapes) and keys apart and skips `//` and `/* */` comments, which real packs
carry. Image and AnimBP paths are never listed. The list goes to `coop-cns.txt`, one `<path> <outfit>` line each,
rewritten at every start. It never goes to your friend: only the tag of an outfit your EVE wears does, in the
component table (see [The ghost pipeline](ghost.md)).

The scan also reads each mod's `.utoc` (its first MiB): the directory index of an IoStore container that is not
encrypted, TOC versions 2 and 3 (UE 4.26 and 4.27). Each `../../../SB/Content/<p>.uasset` entry becomes the object path
`/Game/<p>.<name>`, kept when the native path rule takes it, 8192 paths in all. `.umap` files and files outside
`SB/Content` are never kept, and a mod that is a `.pak` alone gives no paths. The header of `coop-link.log` then has
`mod assets <n> indexed in <k> .utoc files`. Each time the containers your friend lists with the same name and hash as
yours change, the native part writes `coop-shared-assets.txt`: the paths of those containers, one `<path> <container>`
line each, sorted. It is empty with no friend, when your friend's list came without names (her `mod_names=off`) and
with your own `mod_names=off`. The status's `shared=<version> <paths>` line counts the lists written; Lua reads the
file again when the version changes and rebuilds the ghost. The hash is FNV-1a over file names and sizes and your
friend's game states it, so it says that both of you run one build of the mod, without proving it. The list only ever
holds paths of your own containers.

The camps lines carry the [follow](group-play.md#following-the-host), both reliable: the guest's `camps?` with a number from 0 to
65535, and the host's answer to it, its world and up to 8 camps nearest its EVE with their distance in whole metres, or
`none` and why. Only the guest asks and only the host answers. The host's link takes one `camps?` each 2 s, and the
guest's keeps only the answer to her last number. A world or camp name is letters, digits and `_`, at most 64
characters. Both lines show in `coop status` (`camps?=`, `camps=`) until the session ends.

The night line carries a Night Operation run between the two games (see
[night-operation.md](../night-operation.md#the-co-op-run)). It is sent reliable, and each line holds the whole state of
one side, so a lost line is repaired by the next. The host's `h` line has a counter, the run number and seed, the
phase (`ask`, `count`, `wave`, `rest` or `end`), the wave, the run time in milliseconds, the score, kills and waves
cleared, the wave monsters his run found and has not done (a hex mask), his start point, yaw and map, the outcome once
the run ends (`success`, `time`, `failed:host`, `failed:guest`, `failed:both` or `aborted:<reason>`), and the run's
level (`easy`, `normal`, `hard` or `nightmare`, or `range` for the Shooting Range challenge), which the guest's run
takes. A mask has one bit for each wave and slot, 8 slots a wave, so it covers the largest level's waves and the
range's three rounds. The guest's `g` line has a counter, the run number, her state (`ready`, `refuse`, `run`, `dead`
or `abort`), her monsters still up, masks of the ones killed and done in her world, and a refusal or abort word. Both
lines end with the [revive](../night-operation.md#down-and-revive)'s two words: the seconds the side's downed EVE still
waits (1 to 30, 0 while she stands) and the side's revive of the other, the percent of the 3 s its interact key has
been held next to her (0 to 100). The downed game makes its call once the other line says 100. The host's run fails
as `failed:both` once his down and her down word above 0 have held together for 6 s with no call of his under way:
her line does not show a call of hers, which has 5 s to get her up. Each game writes its line when it changes and
at least once a second, never twice in one Lua tick, and logs each line out and in as
`[StellarCoop][NR] night out: ...` and `night in: ...`.

The native part checks only the bytes: 3 to 300 of `0-9`, `a-z`, `/`, `_`, `:` and `-` with single spaces between
words, the first word `h` from the lobby owner and `g` from the guest. It sends an `h` line only while it owns the
lobby and a `g` line only as a guest, and a received line from the wrong side counts as invalid. At most 8 lines a
second go each way; the rest are dropped, with one log line a minute. The last line received is the `night=` line of
`coop-status.txt` while the session holds, and is cleared when the friend is lost or the session ends. Lua checks every
field and refuses the whole line on one bad field. A co-op run ends as lost once the friend's counter has not moved for
5 s. No line carries points: each game turns its own run's final score into points, at most 42 a run at the normal
level and 129 at nightmare.

The mark line is one `coop mark`, sent reliable to each friend past the handshake: its number in the sender's game
(from 1, one count per game process) and its text, cleaned as a say line is and cut to 100 bytes, maybe empty. A longer
text from a friend is cut, not refused. The receiver counts mark lines with say lines against the same 10 a second and
drops the rest, with one log line a minute (`dropped marks from <name>: over the rate limit`). Unlike a say line, the
text goes into `coop-link.log` on both sides (`mark <n>: <text>`, `mark <n> from <name>: <text>`) and into
`coop-status.txt` as the `mark=` line, which the Lua side copies into `UE4SS.log`.

The race line carries one line of a [Doro race](doro-races.md), sent reliable. The link passes its text on as it is: it
reads no further, and only refuses a line with a byte outside printable ASCII (0x20 to 0x7e) or longer than 512 bytes
in all. At most 40 lines a second are sent, and at most 40 a second are kept from a friend. Your friend's lines past
that are dropped, with at most one line a minute per friend in `coop-link.log` (`dropped race lines from <name>: over
the rate limit` or `too many waiting`). Yours past it are only counted, in the session's end line. During
`coop loopback` with no friend linked, your race lines come back as your friend's.

The gift line carries a [cut mailbox](cut-menus.md#cut-mailbox) gift and its answer, sent reliable: `s` with the gift's id (1
to 20 digits, not 0), an item name (letters, digits and `_`, at most 64) and a count from 1 to 10; `a` when the
receiver kept it; `n` and a word of 1 to 16 lowercase letters when it refused it. The link checks that shape and no
more: Lua checks the item. At most 8 lines a second go each way, and each one, sent, refused or received, has a line in
`coop-link.log` (`gift line sent: ...`, `gift line not sent: ...`, `gift line from <name>: ...`). A gift line of yours
that cannot go (no session, past the rate, a send Steam refused) comes back to Lua at once as `gift n <id> nolink`;
Lua gives the items back only when it was the gift's first line.
Your friend's lines reach Lua in `coop-chat.txt` as `gift <payload>`, beside the chat and race lines. During
`coop loopback` with no friend linked, your gift lines come back as your friend's.

Say, vit, pak, paks, camps, night, mark, race and gift lines from a friend who has not passed the handshake are ignored, without a log line.

Accepted peers ping every 2 s. A peer silent on channel 0 for 10 s is marked lost (`<name> silent for 10 s: lost`)
until they are heard again; they stay linked and their table is kept. A message longer than 512 bytes is treated as
invalid.

A session request from Steam is accepted only after a live check that the requester is a member of your lobby. Any
other request is ignored.

## Channel 1: tables and poses

Channel 1 carries the pose path's bytes unchanged: the component table as text starting `SBT 19` (sent reliable), and
each pose as a binary message starting `SBP` (a keyframe) or `SBD` (a delta), then the protocol byte (sent unreliable,
without Nagle delay). Same-place enemies add a binary message starting `SBE` and the protocol byte, at most 30 a
second (sent unreliable): the place, rotation and animation speed of up to 16 enemies that the sender moves on the
other screen.

- Your table goes to your friend at once, again 5 s later, and then at waits that double while nothing changes, up to
  60 s: 5, 10, 20, 40, 60, 60 s. A table lost with a broken session, or sent before they accepted, arrives with a
  later resend. An identical table is ignored. A changed capture (a new outfit, the blade drawn) goes at once, and the
  next resend comes 5 s after it. A pose of theirs that comes after a second or more without one brings the next
  resend within 5 s. Such a gap comes with a broken session, which stops their poses too, and with their loopback or
  replay, which removes your table and sends you nothing until it ends. Their game does the same for their table.
- A table of theirs that needs a new ghost (a new generation or layout) is taken at most once every 2 s. One that comes
  sooner is refused (the stream line's `tables: ... refused`) and their next resend brings it.
- Poses go 60 a second by default (`send_rate`, 10 to 60), at most one per game frame: a game running at 45 fps
  sends 45. With deltas, 60 a second took 89 to 131 KiB/s in tests with simulated idle, running and combat motion on a
  5 KB outfit, and 20 a second 40 to 52 KiB/s. The sender holds a pose back while its poses would pass 192 KiB/s
  (176 KiB/s while it also sends `SBE`), under Steam's default send rate of 256 KiB/s. When Steam's queue to the
  friend shows that the link cannot keep up, the rate drops to 30 or 20 a second until the link is calm again (see
  [link health](#link-health-in-the-log)).
- Channel 1 passes on only data from a lobby member past the handshake: at most 64 KiB a message, and 240 messages
  and 1 MiB a second per friend. The rest is dropped and counted, with at most one line a minute per friend
  (`dropped pose data from <name>: before the handshake`, `bad size` or `over the rate limit`). A non-member's data is
  logged once (`ignored pose data from <id>: not in our lobby`). Channel 1 traffic does not count as hearing from a
  friend for the 10 s lost check.
- Once they are out of the lobby (`<name> left the lobby`), or you left it, the log says `peer unlinked`, and their
  table and the ghost are removed (`Ghost <generation> removed (her table is gone).`).

## Protocol versions

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
| 12 | Shared quests: the `SBQ` lines on channel 2; the `camps?` and `camps` lines, the photo line's `c`, Night Operation's night line, the mark line and the Doro races' race line on channel 0 |
| 13 | The pak lines: each mod container's name and hash, before the paks line; the table's cloth and mod lines, and mod paths outside the game's folders |
| 14 | Night Operation's level on the host's night line (or `range` for a co-op Shooting Range), night line masks for a level's extra monsters, each side's down time and revive progress on both night lines, and the gift line for `coop gift` |
| 15 | Never released: development builds of Matrix XIII's world rows used it |
| 16 | Never released: the table's value lines alone, before the hide lines joined them |
| 17 | The table's value lines (the colours and textures set on a dynamic material) and hide lines (the material slots a part hides); a 0.7.5 test build |
| 18 | The table's fx lines (effect indexes 20 to 64 named by path) and pose effect slots up to index 64; 0.7.5 |
| 19 | Matrix XIII's world rows (spawn rows, camps, warps): shared Naytibas key an enemy by its spawn row's ID, so a peer without those rows would never match the host's new enemies; no line changes shape, the number keeps 0.7.5 out (this version) |

## Link health in the log

Every 60 s, `coop-link.log` has one line per linked friend (`<name>, last 60 s: ...`): messages and KB/s in and out on
channel 1, drops, failed sends with the last Steam result (25 means its send buffer is full), the ping's RTT average
and maximum, pings sent and pongs received (the difference is ping loss), and Steam's view of the session: quality
local and remote, send rate, pending unreliable bytes and queue time.

The same view, read once a second, caps the poses sent a second. Steam keeps an unreliable message queued until it
goes, so a link slower than the stream would make the ghost fall further and further behind. Two readings in a row
with a queue time of 100 ms or more, or 64 KiB or more of unreliable bytes pending, lower the cap: 60, then 30, then
20, never below 20, and never to a value that changes nothing under your `send_rate` (at `send_rate=30` it goes
straight to 20). Ten calm readings (queue under 20 ms and pending under 16 KiB) with none over the limit raise it one
step; readings in between neither count nor reset. When a step up is undone before its wait is over, the next wait
doubles (10, 20, 40, then 80 s), so on a link that carries 30 but not 60 the cap returns to 60 less and less often.
Each step writes one line, for example `pose rate cap 30 a second for <name>: Steam's queue 150.0 ms, 70000 B pending
(2 s at 100 ms or 64 KiB or more); send rate 131072 B/s, quality 0.91/0.93; up again after 10 s calm`. The stream
line shows the cap in force as `link cap <n>`. A single 16 KiB keyframe takes 62.5 ms to leave at Steam's default send
rate and a 64 KiB table 250 ms, which is why one reading over the limit is not enough.
