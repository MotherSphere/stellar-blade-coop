# The Steam link

The player's side of a session is in [Playing with a friend](../players/playing-with-a-friend.md), and
[Troubleshooting](../players/troubleshooting.md#reading-the-60-s-lines) explains the link's 60 s log lines.

The link runs in the native worker, through the Steamworks API that the game itself loaded and started (the game's
`steam_api64.dll`, flat API, SDK 1.59). Stellar Blade Online does not start Steam or call `SteamAPI_Init`, and linking
changes nothing in the game or the saves. If one of the Steam functions it needs is missing (another Steamworks build),
the worker and the pose path stop for the rest of the run, and the status file says `missing=<name>`.

One worker thread makes every Steam call. The game's Steam callback thread only stores a few numbers for it. The worker
runs a pass every 50 ms, or every 5 ms while poses flow (the loopback, a recording, a replay or a friend).

## Lobby and invites

- The native request `host <who> [ask] [<n>]` creates a lobby with room for `n` players, 2 to 4 (`max_players`; 4
  without the number). `<who>` is the word `who_can_join` stores:
  - `public`: a Public lobby (Steam's `ELobbyType` 2) carrying the session list's rows with `sbo_list=1`, so the
    Public tab of Find a session lists it (see [The session list](#the-session-list)). No invite dialog opens; the
    request `invite` opens it.
  - `friends`, or `host` alone: a friends-only lobby (type 1) carrying the rows without `sbo_list`. Steam's invite
    dialog opens.
  - `invitation`: an invisible lobby (type 3) with a join code. Steam's invite dialog opens too. `code` and
    `private`, the words older settings files hold, mean the same.
  - `closed` (Private in the menus): an invisible lobby the host shuts to joins at once (`SetLobbyJoinable`). It has
    no code and no rows. No invite dialog opens. Asked again, or with `invite`, the game says
    `Nobody can join a private session.` A join gets Steam's refusal. The mod reads response 3 as
    `Could not join: that game is closed (a private session, or a match that started).`; which response Steam sends for
    a lobby set not joinable has not been checked in game. A member Steam lets in anyway is refused before any hello with the reject
    `this session is private`. The host sees `A player tried to join your private session and was refused.`

  `ask` after the word (`host public ask`, from `friends_ask=on`) makes the host's Steam friends wait for her answer
  too (see [Players who are not Steam friends](#players-who-are-not-steam-friends)). The lobby carries a tag under the
  key `stellarcoop`: the protocol and the game's Steam build (`29:<build>`). A lobby from another protocol or game
  build is refused on joining, with both versions in the joiner's log and on screen. A lobby with no tag is another
  game's. It is refused as such.
- Anyone who has an invisible lobby's id can join it. The host's friends do not see it. Steamworks documents that a
  lobby search still returns it. The quick match's search (below) asks for `sbo_mode` and `sbo_state`, which an online
  session never carries. The session list's search asks for `sbo_list`, which an invisible one never carries. A player
  who finds it another way waits for the host's answer like any other player who is not a friend. The host of an
  Invitation session gets a 7-character join code (`CCS-CBMH`), on screen and in `coop-status.txt`. The request `copy`
  puts it on the Windows clipboard. Under Proton, Wine should pass it on to the desktop's clipboard; the Wine smoke
  test checks the Windows side only. `join <code>` joins the lobby it names.
- The code holds the low 32 bits of the lobby id in Crockford's base 32, which leaves out I, L, O and U. Every lobby
  id seen so far starts with the same high 32 bits, `0x01860000`, which the code leaves out. The 3 spare bits hold the
  low part modulo 7, so 89% of the codes with one character wrong are turned away (over 2,000 random ids) instead of
  leading to another lobby. Either case is accepted, I and L read as 1, O as 0, and the dash is optional.
- An accepted invite arrives as a Steam callback, or as `+connect_lobby <id>` on the command line when Steam starts the
  game for it. Either way the game joins only once a save is loaded (Lua writes `world=1` in `coop-state.txt`), so a
  launch never joins from the title screen. Until then the invite is held.
- `coop join` without an id searches your Steam friends for one who is playing Stellar Blade in a lobby.
- The host leads. When the host leaves, every guest leaves too, even though Steam hands the lobby to one of them. A
  co-op lobby with more than 4 players is left. [Sessions of more than 2 players](#sessions-of-more-than-2-players)
  says what changes past 2.
- When a guest's game loses the host's lobby another way, it rejoins automatically: it tries at 2, 12 and 42 s and
  gives up at 60 s. A lobby that is gone or has a new owner by then ends the session.

### Match lobbies

A match lobby holds up to 8 players. Its owner writes five keys beside `stellarcoop`: `sbo_mode` (the mode: `ffa`,
`scoreattack` or `race`), `sbo_state`, `sbo_map`, `sbo_room` and `sbo_hall`. A lobby whose `sbo_mode` names a mode the game knows
is a match lobby, a co-op lobby carries none, and a lobby of a mode the game does not know is left. A match lobby keeps
its mode while a player is in it: if its owner clears `sbo_mode` or writes another mode, the player leaves, so the
rules of [In a match lobby](#in-a-match-lobby) never lapse for her. `sbo_state` is written on Public lobbies only:
`open` while players can join, `playing` during a round. `sbo_map` names the round's map, `lobby` for a score attack
round or a Doro race round, which plays in the room the members wait in. `sbo_room` and `sbo_hall` are the last two
words of the request that created the lobby: the SBO lobby map its players wait in (`xion`, or a hall lobby's key such
as `hotel`) and the version of the hall lobby pak `zSBO_Lobby` (its `.utoc` and `.ucas` sizes joined by `_`, or `xion`
without the pak). Lua's `online/lobby/sbo.lua` picks both words (`lobby_words()`): the lobby map the player stands in,
or one drawn at random outside it, and the pak's version. Every member reads both keys each pass, keeps a word only when
it holds letters, digits and `_` and is 40 bytes at most, and the status shows them after `owner=` on its `link=` line.

- `match search <mode> <room> <hall>` is the quick match. It asks Steam for lobbies whose `stellarcoop` equals this
  game's tag, `sbo_mode` the mode, `sbo_state` `open` and `sbo_hall` the hall word, with a free slot, at Steam's default
  distance (the player's region and nearby ones). A player without the hall lobby pak, or with another build of it,
  never finds a lobby on maps she lacks. It joins the first lobby found. When that join fails (the lobby filled up or is
  gone), it tries the next one. With none left, it creates a Public lobby (Steam's `ELobbyType` 2) for 8, and the notice
  names this game's protocol and build, since another version's lobbies never match the tag. Steam runs one lobby search
  per player at a time: a second `match search` is ignored while one runs, and `match cancel` drops it.
- Two players who search in the same second find nothing and each create a lobby. So a host alone in a Public match
  lobby searches again every 5 s, with her lobby's `sbo_hall`, and moves to an open lobby with a lower id, never a
  higher one. The two lobbies of one become one within about 5 s, and the next player who searches joins it. The
  lobby she moves to can name another `sbo_room`.
- `match create <mode> <room> <hall>` creates a private match lobby: Invisible like a code lobby, with a join code, and
  without `sbo_state`, so no search returns it. Friends join it with `join <code>`. With the hall lobbies in use, the
  host picks the room on the Map row of the lobby settings screen, or Random for a draw (`create()` in
  `online/lobby/sbo.lua`). When the room is a hall other than the one she stands in, she warps there first and the
  request goes out when she arrives.
- In the SBO lobby, a guest of a match lobby whose `sbo_room` names another of the lobby maps her entries use (the
  halls with the lobby pak, else Xion) warps there, once per arrival and joined lobby, so a refused warp is not asked
  again before the next arrival or a new join. A lobby whose `sbo_room` names any other map, or whose `sbo_hall`
  differs from hers (a join by code skips the search's filter), shows the notice
  `Left the match: its lobby map is missing or a different version here.` and she leaves it. A host does not follow
  `sbo_room`: her lobby names the map she stood on when she created it.
- In a match lobby, public or private, nobody waits for the host's answer, Steam friend or not. The host can still
  `remove` a player.
- `match search` and `match create` are refused while the game is in a lobby.
- Match sessions, and co-op sessions with a player who is not your Steam friend, go through Steam's relays only, so
  no player learns another's IP address. The game sets `P2P_Transport_ICE_Enable` (104) to 0 before a match's search,
  create or join, on entering a match lobby joined by its code, on joining a co-op lobby whose host is not a Steam
  friend, and on a co-op host before its first session with a member who is not one (before it accepts her session,
  pings her or sends her a reject). The log line is `relay only (ICE off): match session` or
  `relay only (ICE off): <name> is not a Steam friend`. The setting holds for the whole game run. Hosting a co-op
  lobby sets it back to -1, the Steam client's own setting, and so does joining a co-op lobby whose host is a Steam
  friend, before the first session opens. A co-op host stays on relays only after a stranger has been in her lobby,
  until she hosts again or joins a friend's co-op lobby.
- Relay only fails closed. When Steam refuses ICE off, the game keeps ICE marked on and logs `Steam refused relay
  only, try <n>/3: <why>`. While it is on, no line goes to a player who needs relay only (every member of a match
  lobby, any player who is not a Steam friend in a co-op lobby): the send returns EResult 15 and her session request
  waits (`session request from <name> held: no relay only yet`). The next member pass at least 1 s later asks Steam
  again. After 3 refusals in a row the log reads `no link with <name>: Steam refused relay only 3 times`. A co-op
  host refuses her (`<name> was refused: Steam would not set relay only.`). A co-op guest leaves with `Left <host>'s
  game: Steam would not set relay only.` when it is the host she cannot link with. When it is another guest, only
  that link goes, until that guest leaves the lobby: `No link with <name>: Steam would not set relay only.` In a match
  lobby every role leaves with `Left the match: Steam would not set relay only.` A refused ICE back to -1 leaves relay
  only on.
- In a match lobby, Steam's lobby owner is the host. An owner who leaves from the menu first hands the lobby to the
  member past the handshake who joined first (`SetLobbyOwner`), then leaves. When the owner changes during a round,
  every game ends it with `host_left`. Ten seconds of silence from the owner also end it, with `host_lost` and the
  notice `Round ended: the host stopped answering.` On a guest, the same silence stops a countdown the owner sent, with
  the log line `countdown stopped: <owner> stopped answering`. The players then stay in the lobby, and no countdown
  starts until Steam moves the ownership. The new owner makes the lobby joinable again, writes `sbo_state=open` on a
  Public lobby, and runs the next countdown.
- A guest whose game is no longer in a match lobby's member list leaves it, with no rejoin. Friend sessions keep the
  rules in [Lobby and invites](#lobby-and-invites).

### The session list

Find a session lists the online sessions other players host. The host of a Public or Friends only online session
writes these lobby keys beside `stellarcoop` with `SetLobbyData`, each only when its value changed:

| Key | Value | Written |
| --- | --- | --- |
| `sbo_list` | `1`, on a Public session only | At create |
| `sbo_host` | Her Steam name, 48 bytes at most | At create, then within 5 s of a change (her game reads her name every 5 s) |
| `sbo_owner` | Her SteamID | At create |
| `sbo_players` | Members and room, `<n>/<max_players>`, for example `1/4`. A joiner who waits for the host's answer counts | At create, at each join or leave |
| `sbo_zone`, `sbo_camp` | The words of Lua's `where <map segment> [<camp alias>]` | At create, at each `where` |
| `sbo_rules` | The word of Lua's `rules <word>`: the session rules that are on | At create, at each `rules` |
| `sbo_ping` | Her ping location, from Steam's `ConvertPingLocationToString` | At create (again every 5 s while Steam does not know it yet), then every 5 minutes when it changed |
| `sbo_ask` | `1` on any online session whose Steam friends wait for her answer too (`host ... ask`) | At create |

An Invitation or Private session writes none of these keys but `sbo_ask`. `where` and `rules` take words of letters,
digits and `_`, 32 bytes at most (24 for the camp alias). The game keeps the last ones for the next session it hosts. The log has one line for
each (`where: b07 WLB10_Camp_01`, `rules: <word>`).

Any SBO client can write any of these keys, so a reader cleans each one before the status shows it. The name loses
`<`, `>` (Stellar Blade's rich text would read a tag), control characters, bidirectional and zero-width marks and any
byte that is no valid UTF-8, then is cut to 48 bytes at a character. The zone, camp and rules show only when they are
one word of letters, digits and `_` within 32 bytes (24 for the camp alias), else as `-`. The ping location goes to Steam only when it is
printable ASCII without spaces, 1023 bytes at most.

- `list public` asks Steam for lobbies whose `stellarcoop` equals this game's tag and `sbo_list` equals `1`, with a
  free place, at the worldwide distance, 50 at most. Another version's sessions never match. A joiner who waits for
  the host's answer takes a place meanwhile: a session she fills leaves the list.
- `list friends` walks the Steam friends playing Stellar Blade in a lobby (`GetFriendGamePlayed`). Steam gives no data
  for a lobby the player is not in before it answers `RequestLobbyData`, so the game asks once for each lobby and reads
  its data each pass until its tag shows, 5 s at most. A lobby with no answer by then is dropped with the log line
  `lobby <id> sent no data within 5 s`.
- Either search keeps its rows and joins none of them. A row is hidden when the lobby runs another version, is a match
  lobby (`sbo_mode`), has no `sbo_owner` (an Invitation or Private session), is the player's own, is full by its
  `sbo_players`, or when the player blocked its host on Steam (`GetFriendRelationship` Blocked, Ignored or
  IgnoredFriend) or with `coop block`. Each row's ping is Steam's estimate from the host's `sbo_ping`
  (`EstimatePingTimeFromLocalHost`). Once the search ends, the rows go best ping first, those without one last. The
  log line reads `list public done: <n> shown, <n> hidden`.
- A row's Steam friend mark takes Steam's word, not the row's: the SteamID in `sbo_owner` is the player's Steam friend
  (`HasFriend`) and `GetFriendGamePlayed` puts that friend in this lobby. A lobby that writes a friend's SteamID and
  name over its own gets no mark, since Steam has the friend elsewhere or in no lobby.
- One search runs at a time, 5 s apart at least, with no automatic refresh. A list search is refused in a lobby
  (`Leave this game first.`), while a match search or another list search runs (`A search is already running.`), or
  under 5 s after the last one (`Wait 5 s between two searches.`). Steam runs one lobby search per player, so a match
  search that starts while Steam has not answered the list's ends it (`list search dropped: a match search started`).
- `list stop` forgets the list.
- A row is joined with `join <lobby id>`, then everything runs as for any join: the tag check, relay only with a host
  who is not a Steam friend, the host's answer.

The status shows the list while it lasts, then one line per row, the host's name last:

```
list=<public|friends> <searching|done|failed> <rows>
session=<lobby id> <host's SteamID> <n>/<max> <ping ms|-> <Steam friend 1|0> <zone|-> <camp|-> <rules|-> <host's name>
```

Steamworks documents the read rules the list relies on: a search result's data can be read without joining,
`GetLobbyOwner` answers members only, a friends-only lobby never comes back from a search while an invisible one does.
The fake Steam of the tests follows them. None of them was checked in game yet.

None of this changes the protocol: the rows are lobby data, never a line between two games.

## Players who are not Steam friends

In a co-op lobby, a player who joins and is not the host's Steam friend waits for the host's answer. The host's game
holds the handshake: it sends no hello and reads none of the player's messages, only pings them so that neither game
reports a lost connection. The host's status shows a `pending=<SteamID> <name>` line for each player who waits, in the
order they joined. A notice says that a player who is not a Steam friend is asking to join. The joiner's game shows `Joined <host>'s game. Waiting to be let in.` Until the host
lets it in, its status has the line `wait=<seconds left> <host's name>`: the most the host's answer may still take, as
the host's last `wait` line gave it (below), else the minute counted from the join. The name is read from Steam each time, since Steam may learn a stranger's name a moment after the join. With `friends_ask=on` (`host <who> ask`), the host's Steam friends wait the same way. The host's notice
for one of them reads `<name> is asking to join.` The lobby's `sbo_ask=1` tells the friend's game that it waits. The
host answers with native requests, which Lua writes to `coop-request.txt` like the others:

- `allow <SteamID>` lets the player in. The handshake then runs as with a friend, and a rejoin after a drop is let in
  without a new question for as long as the lobby lasts.
- `deny <SteamID>`, or 60 s with no answer, refuses the player. So does leaving before the answer. The host's
  questions come one at a time, in the order the players joined: a player's minute starts when her question is the
  first one waiting. The host's game sends each waiting player `SBC29 wait <seconds>`, reliable, at the start and after
  each change: what is left of the minute of the player asked now, plus a minute for each player after that one, hers
  included.
  `remove <SteamID>` refuses any player already in (friends included) and puts them on the block list.
- A refused player gets a `SBC reject` with the reason (`you were not let in`, `no answer within 60 s`, `you were
  removed from this session`). Every build since protocol 9 shows it as `<host> refused the link: <reason>` and leaves. That
  player stays refused until the host creates a new lobby: the host never greets them again, ignores their session
  requests and messages, and sends `you cannot join this session again` each time they come back. Steam has no way to
  remove a lobby member, so a game that ignores the reject keeps its place in the lobby. It gets the reject
  again every 10 s, and the host can create a new lobby, which gets a new code.
- Answers go by SteamID, so an answer meant for a player who left never reaches the next one. A guest's answers, and
  an answer for a player who is not waiting, are ignored with a line in `coop-link.log`.
- The block list (`block <SteamID>`, `unblock <SteamID>`, `unblock all`) lasts across lobbies and game runs. The
  native part reads `coop-blocked.txt` once at start and writes it again after each change. Each line is FNV-1a 64 of a
  fixed salt and the SteamID's digits, in 16 hex digits. While we host, a lobby member on the list is put on the
  refused list of this lobby before any approval question, hello or accepted session. She gets the same
  `you cannot join this session again` reject. When Steam makes us the owner of a match lobby, a member on our list
  who linked while we were a guest is refused at once with the same reject. A guest's list applies only in a Public
  match lobby, which a search or a regroup chose for her: with a member on it, she leaves and searches again. A guest
  whose Public match lobby's host refuses her searches again too. Either way her searches skip that lobby for the rest
  of the game run, so a regroup never takes her back to it.

On the host, `online/session/join.lua` turns the first `pending=` line into a question on screen and writes the answer.
While more lines follow, its seconds line adds how many players wait after this one. Once the first player is answered
or gone, the next `pending=` line gets its own question. It asks each player once a lobby; with no answer, the native
part refuses the player 60 s after her question became the first one. The question opens without a key press, so it
ignores every key for 1 s after it shows, and `main/keys.lua` gives it the arrow keys but not W, S or Space.
`core/link.lua` keeps in memory which lobby members waited for an answer, for the menu's Remove row, so a Lua reload
forgets them.

Apart from the wait line, this uses the hello's timing, the ping and the reject.

### Sessions of more than 2 players

An online session holds up to 4 players (`max_players`). The host leads every guest:

- The host's game sends each guest past its handshake `SBC29 let <pair> <id>,<id>,... <max>`, reliable, again after
  each change and after each hello of hers. It names the pair, then the guests past the host's handshake in the order
  they came, then the host's `max_players` (2 to 4). A guest greets, reads and accepts a session from the host and the members this line names only. A joiner who
  waits for the host's answer gets nothing from the guests and sends them nothing. A member the line no longer names
  (refused or removed) loses her link with each guest at its next pass, which says `<name> left.`
- The pair is the host and the guest in ghost slot 0. On a guest, the host always holds slot 0. On the host, slot 0
  goes to the first guest: one who comes in without a question while no other guest is let in, or the first one let
  in. The shared enemies, the shared world and story together run within the pair only (`Link::partner()`): the other
  guests' games keep their own enemies and world. They wait through the host's cutscenes as before. When the pair's
  guest leaves, the let line's pair is 0 for one pass. At the next pass the guest who got in first of those past the
  handshake (at once, or when the host let her in) moves to slot 0 (`<name> is the pair now: ghost slot <k> to 0` in
  the host's log). The pass between lets the host's pose path drop the old pair's table from slot 0. The let line then
  names her: her game says `Shared enemies, the shared world and story together now run between <host> and you.` and
  sends its pose table to every member at once (`glue/steam.cpp`), since the host's slot 0 holds none of hers yet.
  With no guest past the handshake, slot 0 waits for the next one. A guest who passes the handshake while slot 0 waits
  gets no let line until she or another guest takes it, so her first one names the pair and she hears no notice that
  the features are off for her.
- The first let line that does not name a guest as the pair gives her one notice for the session: `Shared enemies,
  the shared world and story together run between <host> and <pair> only. Your game keeps its own.` With no pair, it
  reads `Shared enemies, the shared world and story together are off for you in <host>'s session. Your game keeps its
  own.`
- Channel 2 follows the pair. `glue/steam.cpp` sends the shared fight's, the shared world's and story together's lines
  to `partner()` only. It hands those three the pair's lines only: a guest out of the pair sends none and reads none.
  Same-place enemies' `SBE` on channel 1 goes to the pair only. The shared quests run with every member: the host's game
  runs one quest side per guest past the handshake, all fed by one read of its quests each pass. Each guest gets her own
  lines (see [Group play: how it works](group-internals.md#shared-quests)). A guest sends her `SBQ` lines to the host
  only and reads the host's only. Lines from any other member are dropped. A quest step a guest makes first (`SBQ29
  step`) is story together's: the host's game takes it from the pair only and logs any other guest's as `a step line
  from guest <SteamID> not taken: her game is not the pair`. A guest out of the pair sends none.
- In a shared boss fight the pair's `SBF` lines go both ways: the game that runs a boss sends its `bstart`, `phase`
  and summon `spawn` lines, the host sends `fin` (whose finisher counts) and `qte-own` (who owns a boss QTE at which
  try) and each side sends `spec` while its player watches the fight
  ([Shared enemies: how they work](../fight/enemies-internals.md#shared-bosses)). The host's `bosses` line carries
  its `boss_finish` as a fourth word. Story together's `SBS` lines of a boss QTE scene come from the member who leads
  it, the guest included ([Story together: how it works](../story/together-internals.md#boss-qte-scenes)).
- A new pair, or none, empties channel 2's queues both ways of all but the shared quests' lines, so a snapshot on its
  way to another guest still goes.
- The status has `host=<host's SteamID> pair=<pair's SteamID or 0> max=<max_players>` in an online session (on a
  guest, `pair=` is the let line's, her own when she is the pair; `max=0` before the let line came), then
  `players=<n>`: the host and each member past the handshake with it, the reader included. On a guest that is the let
  line's members plus the host (0 before the let line came), whether her own link with each is made or not. Night
  Operation and Doro races read it (`Link.crowd()`): the pair ends a run as soon as the host's let line names a third
  player, even while her own link with that player is still being made. Then `vit=<SteamID> <13 numbers>` for each
  member past the handshake whose vit line is under 3 s old. `mate=` is the slot-0 member's: the host's on a guest,
  the pair's on the host. A match lobby has neither.
- A member who comes in while the lobby holds more than 2 players starts at 30 poses a second, as in a match lobby.
  When the lobby grows past 2, each link still at 60 starts again at 30 too (`pose rate cap 30 a second for <name>: 3
  players in the lobby`). Each one steps back up after 10 calm readings, as any capped link does.
- A guest who leaves is announced on the host and on each guest she linked with (`<name> left.`). In a match lobby
  only the owner says it.
- With more than 2 players, a gift is refused at once (`Gifts need a session of 2 players.`; Lua gets `gift n <id>
  nolink`). Its answers (`a`, `n`) still go to every member, so a gift sent in a session of 2 gets its answer after a
  third player came in. Doro races and Night Operation send nothing. Lua refuses a gift, a race, a Night Operation run and the PvP
  test before it asks, from the count of `member=` lines past the handshake (`core/link.lua`'s `others()`). A guest's
  photo mode no longer pauses the host's game (`<name> is taking photos (no pause with more than 2 players).`). Her
  game counts the let line's members: past one, it says `<host>'s game does not pause for photos with more than 2
  players.` once a session. The host's photo mode and cutscene still pause each guest that asked for it.
- A player on another protocol or game build is refused by the host, who keeps the lobby for the others. A reject from
  a guest is logged with a notice and the host stays.

### In a match lobby

A match lobby lets players in without the host's answer (see [Match lobbies](#match-lobbies)), so these rules change
there:

- Only the lobby owner's `SBC reject` makes a game leave. A reject from another member counts as an invalid message
  (`invalid message from <name>` in `coop-link.log`), and the game stays.
- The owner refuses a member whose hello names another protocol or game build and keeps the lobby. Its notice reads
  `<name> runs another version and was refused.` That player then stays refused for the lobby, as above. A guest who
  gets such a hello from another guest marks that member incompatible, counts an invalid message, sends no reject and
  stays. A mismatched hello from the owner still makes the guest reject it and leave.
- No photo line (and so no photo or cutscene pause), gift, race line, mode line, camps line, night line, shared quests' `SBQ` line,
  shared world's `SBW` line or story together's `SBS` line goes either way. The game sends none. Such a line that
  arrives on channel 0 is dropped with no log line. An `SBQ`, `SBW` or `SBS` line on channel 2 is dropped too. The log
  says `dropped fight data from <name>: shared quests are off in a match lobby`, `...: the shared world is off in a
  match lobby` or `...: story together is off in a match lobby` at most once a minute. `coop gift` gets its items back
  at once (`gift n <id> nolink`), and a camps request ends with `camps line not sent: a match lobby` in the log.
  A Doro race of a match goes on the dr line instead of the race line (see [The dr line](#the-dr-line)).
  The spot lines and the rest line go neither way either (`spot line not sent: a match lobby`, `rest line not sent:
  a match lobby`).
- Chat stays on, with a mute per player. `mute <SteamID>` drops that player's chat lines and `unmute <SteamID>` lets
  them through again. The notices read `Muted <name>.` and `Unmuted <name>.` A dropped line counts in the chat totals
  and gives `dropped chat lines from <name>: muted` in the log at most once a minute, never with its text. A mute
  lasts for the game run in every lobby, co-op ones included, so a player muted in one match stays muted in the next.
  The fifth field of that player's `member=` status line is 1 while muted.
- A member who stays over a channel's rate limit for 5 s is refused: more than 128 lines a second on channel 0, or
  past channel 1's or channel 2's limit, each second. This counts from her first message, handshake or not. One
  second over, such as a list of 257 pak lines, is not enough. The owner keeps the lobby and a guest stays. The notice
  reads `<name> sent too many messages and was refused.` and the log `refused <name> (<id>): channel-0 lines over the
  rate limit for 5 s` (or `pose data`, `fight data`). Her session is closed and a new one of hers is never accepted,
  so her messages stop reaching the game. She gets no reject every 10 s, as that would open a session again; she gets
  one if she leaves the lobby and comes back. A guest logs her later messages once, as `ignored messages from <id>:
  refused for a flood`. A guest whose owner floods leaves the match: `Left the match: <name> sent too many
  messages.`

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
The mod version is reported but does not have to match. In a match lobby only the owner rejects, and it keeps the
lobby (see [In a match lobby](#in-a-match-lobby)).

A friend who passed the handshake both ways is linked (`peer linked: poses and tables go over Steam` in
`coop-link.log`) while the native pose path is on (`engine=on`) and no loopback or replay runs. The ghost turns on with
the session (the link going from none to host or guest). That publishes your EVE's capture and builds the ghost of
your friend's EVE, which stands where her main mesh is, with no offset.

## Channel 0: text

Channel 0 carries short text messages over Steam's relayed P2P messages (SteamNetworkingMessages). Apart from the
handshake, every message carries the protocol number, and a peer that runs another protocol drops it:

```
SBC29 ping <seq> <ms>
SBC29 pong <seq> <ms>
SBC29 photo <0|1|s|c> <both|notice>
SBC29 say <text>
SBC29 vit <hp> <max hp> <shield> <max shield> <shield blocks> <beta> <max beta> <burst> <max burst> <tachy> <max tachy> <life> <zone type>
SBC29 pak <hash> <name>
SBC29 paks <count> <hash>
SBC29 dlc <app id> <name>
SBC29 dlcs
SBC29 cycle <count> <difficulty>
SBC29 camps? <id>
SBC29 camps <id> <world> <camp>:<m> ...
SBC29 camps <id> none <title|loading|nocamp|busy>
SBC29 spot? <id>
SBC29 spot <id> <x> <y> <z> <yaw>
SBC29 spot <id> none <title|loading|air|busy|solo|boss>
SBC29 rest <zone> <SteamID>
SBC29 night h <n> <run> <seed> <phase> <wave> <run time ms> <score> <kills> <clears> <found> <x> <y> <z> <yaw> <map> <end> <level> <down> <help>
SBC29 night g <n> <run> <state> <up> <killed> <done> <why> <down> <help>
SBC29 mark <n> [<text>]
SBC29 race <text>
SBC29 score <text>
SBC29 mode <word> <text>
SBC29 dr <text>
SBC29 gift s <id> <item> <count>
SBC29 gift a <id>
SBC29 gift n <id> <why>
SBC29 bike park <map> <x> <y> <z> <pitch> <yaw> <roll>
SBC29 bike none
SBC29 start <mode> <map> <seed> <id>,<id>,...
SBC29 count <1-10|stop>
SBC29 end
SBC29 let <pair> <id>,<id>,... <max>
SBC29 wait <seconds>
```

### The photo line

The photo line is sent reliable. It carries the sender's photo mode (`1`, `s` for selfie mode, `0`) and whether their
game may be paused for the other player's photo mode (`both`). It is sent after each handshake and on each change, and
the receiver takes at most 8 a second. While your friend's line says `1 both` and your setting is `photo_sync=both`,
the game thread holds a pause tag of the mod's own in the game's pause set. It sets the tag through the function that
the game's photo mode pauses with (build 26123051 only). [Playing with a friend](../players/playing-with-a-friend.md#synced-photo-mode) lists when the pause is
released. A host's line says `c` while a cutscene plays in its game and its own photo state is `0`
([Cutscene wait](group-internals.md#cutscene-wait)).

### The say line

The say line is one chat line, sent reliable. Both games clean it the same way: they keep well-formed UTF-8 only, drop
control, bidi and zero-width characters, trim spaces, and keep at most 200 bytes, never cutting inside a character.
At most 3 lines a second are sent, and at most 10 a second are kept from a friend. The rest are dropped, with one log
line a minute that holds no text. At most 64 received lines, chat, race, score, mode and dr lines together, wait for the Lua side. The
text never goes into `coop-link.log`, `coop-status.txt`, `coop-report.txt` or the console. When the session ends, the
log gets the counts only: `chat this session: <n> in, <n> out, <n> dropped; race lines: <n> in, <n> out, <n> dropped`.

### The vit line

The vit line is sent unreliable. It carries your EVE's numbers for your friend's partner card, in whole units: HP,
shield and shield blocks, Beta, Burst and Tachy with their maximums, and the life state. It is sent when a number
changes, at most 10 times a second, and once a second otherwise. During a session the native worker reads the numbers
every 100 ms, or 500 ms after a read that took over 1 ms (game build 26123051 only). Each read is eight
`ReadProcessMemory` calls on the worker, never on the game thread, on the EVE that the game's actor manager marks as the
local player. A vit line is invalid if a value is over 10,000,000, HP is over its maximum, there are more than 64 shield
blocks or the life state is over 255. The last line of the member in ghost slot 0 shows in `coop status` as `mate=`
for 3 s. Each member's shows as `vit=<SteamID> ...`.

The 13th number is the type of the zone the sender's EVE stands in, from the game's ZoneTable (0 to 6, see
[Solo areas](group-internals.md#solo-areas)). The game thread reads it on the sender's side. A type above 6 goes out
as 0. A line whose type is above 6 is invalid. A vit line of 12 numbers is invalid too. A protocol-24 build sends
12 numbers. It is refused at the hello.

### The pak and paks lines

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
[Shared enemies](../fight/enemies.md#shared-enemies-experimental)). Without names, or with only mods of yours that they lack, the notice
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
component table (see [The ghost pipeline](partner-internals.md)).

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

### The dlc and dlcs lines

The dlc lines and the dlcs line are sent reliable right after the paks line, again after each hello of the other player
as the pak lines are. Once Steam is ready, the native part asks Steam for the game's own DLCs (`GetDLCCount`, then
`BGetDLCDataByIndex` for each) and keeps the first 64 that `BIsDlcInstalled` says are on this PC. No DLC id is written
in the mod. `coop-link.log` lists them after its `Steam ready` line (`DLCs installed: <n> (<names>)`). A DLC installed
while the game runs counts from the next start. Each one goes in a dlc line: its Steam app id, then its name as Steam
gives it, cleaned like a chat line and cut to 100 bytes, or the app id when Steam gives no name. The dlcs line ends the
list. In a match lobby every member gets them.

Once your friend's list came, `coop status` has `dlcs=same <yours> <theirs>` or `dlcs=differ <yours> <theirs>`. A
`dlc_missing=<app id> <name>` line follows for each DLC they have and you lack, then a `dlc_extra=<app id> <name>` line
for each one you have and they lack. The two lists are compared by app id. `coop-link.log` says it each time their list
changes (`<name> has <n> DLCs installed, the same as ours` or `<name> has <n> DLCs installed; we lack <names>; she lacks
<names>`). When the lists differ, one notice a session names the DLCs your friend has and you lack, then the ones you
have and they lack: `<name> has DLCs you don't have: <DLCs>. You have DLCs <name> doesn't have: <DLCs>.` A part whose
list is empty is left out. The notice keeps to the feed's 200 bytes: each sentence names at most its first two DLCs
when they fit, then `(+n)` for the others. When your friend's name is so long that the two counts alone
pass 200 bytes, the notice cuts that name. Nothing is refused.

### The cycle line

The cycle line gives your game's New Game+ count and difficulty: `SBC29 cycle 1 2` is New Game+ 1 on Hard. The count
is 0 on a first playthrough and goes up to 99; the difficulty is 0 for Normal, 1 for Story and 2 for Hard. Any other
value makes the line invalid. The game thread reads both once a second while you are in game: the count is the int32 at
`+0xe4` of the game object at 0x1470373c8 (the value SB's IsPlayNewGamePlus tests); the difficulty is the one SB gives
the client's difficulty alias. Nothing is read at the title or in a load. The native part never makes that object
when it is not there yet. A fault in the read turns it off with one `New Game+ read off` line in `coop-link.log`; a
value out of range is dropped with one `New Game+ read refused` line. Either way the last good read stays.

The line is sent reliable once both values are read, after the dlcs line, to each player past the handshake. It goes
again when a value changes (SB's Settings can change the difficulty during play) and after each hello of the other
player. Until the first read, nothing is sent. `coop-link.log` names each change of yours (`our game: New Game+ <n>,
difficulty <d>`) and of each other player (`<name>'s game: New Game+ <n>, difficulty <d>`). `coop status` has
`mycycle=<count> <difficulty>` once yours is read, then `cycle=<SteamID> <count> <difficulty> <name>` for each player
past the handshake whose line came. A cycle line that comes before the handshake is ignored without a log line.

### The camps lines

The camps lines carry the [follow](group-internals.md#following-the-host), both reliable: the guest's `camps?` with a number from 0 to
65535, and the host's answer to it, its world and up to 8 camps nearest its EVE with their distance in whole metres, or
`none` and why. Only a guest asks, of the host only. Only the host answers. The host's link takes one `camps?`
each 2 s from each guest and gives it a number of its own, 1 to 65535 in turn: two guests' numbers may meet, the
host's never do. Its status shows that number (`camps?=`) for the oldest request still waiting for an answer, else
for the last one taken. His Lua answers each number once. The answer goes to the guest whose request had that
number, alone, with her own number in place of the host's. A guest's link keeps only the answer to her last number. A
world or camp name is letters, digits and `_`, at most 64 characters. Both lines show in `coop status` until the
session ends: `camps=` on the guest, `camps?=` on the host.

### The spot lines

The spot lines carry [the spot warp](group-internals.md#the-spot-warp), both reliable: a member's `spot?` with a number
from 0 to 65535, then the answer of the member asked: her last ground point (x, y and z in whole centimetres, each
within 10,000,000 either way, then her yaw in whole degrees within 360 either way) or `none` and why (`title`,
`loading`, `air`, `busy`, `solo`, `boss`). A guest asks the host only. The host may ask any guest past the handshake.
A guest takes a `spot?` from the host only. Each game takes one `spot?` each 2 s from each asker and gives it a number
of its own, 1 to 65535 in turn. Its status shows that number (`spot?=`) for the oldest request still waiting for an
answer, else for the last one taken. Its Lua answers each number once. The answer goes to the member whose request
had that number, with her own number in place. An answer counts only from the member asked, with the number of the
last request: `spot=<id> <answer>` in the asker's status. A new request forgets the answer to the one before. The
session's end drops both lines. `coop-link.log` has one line for each line sent, taken or dropped
(`dropped a spot line from <name>: <why>`).

### The rest line

The rest line carries a member's [camp rest](group-internals.md#rests-between-members), reliable: the zone's alias
(letters, digits and `_`, at most 64 characters), then the resting member's SteamID, never 0. A guest sends hers to
the host. The host sends his to every guest past the handshake. The host takes a guest's rest only when its SteamID
is hers, one each 2 s from each guest, then sends it on to every other guest past the handshake. A guest takes rest
lines from the host only, with no limit of her own. Lua gets each one in `coop-chat.txt` as `rest <zone> <SteamID>`.
`coop-link.log` has one line for each rest line sent, taken or dropped (`dropped a rest line from <name>: <why>`).

### The night line

The night line carries a Night Operation run between the two games (see
[online/modes/nightop.md](modes/nightop.md#the-co-op-run)). It is sent reliable, and each line holds the whole state of
one side, so a lost line is repaired by the next.

The host's `h` line has a counter, the run number and seed, the phase (`ask`, `count`, `wave`, `rest` or `end`), the
wave, the run time in milliseconds, the score, kills and waves cleared, the wave monsters his run found and has not done
(a hex mask), his start point, yaw and map, the outcome once the run ends (`success`, `time`, `failed:host`,
`failed:guest`, `failed:both` or `aborted:<reason>`), and the run's level (`easy`, `normal`, `hard` or `nightmare`, or
`range` for the Shooting Range challenge), which the guest's run takes. A mask has one bit for each wave and slot, 8
slots a wave, so it covers the largest level's waves and the range's three rounds.

The guest's `g` line has a counter, the run number, her state (`ready`, `refuse`, `run`, `dead` or `abort`), her
monsters still up, masks of the ones killed and done in her world, and a refusal or abort word. Both lines end with the
[revive](modes/nightop.md#down-and-revive)'s two words: the seconds the side's downed EVE still waits (1 to 30, 0
while she stands) and the side's revive of the other, the percent of the 3 s its interact key has been held next to her
(0 to 100). The downed game makes its call once the other line says 100. The host's run fails as `failed:both` once his
down and her down word above 0 have held together for 6 s with no call of his under way: her line does not show a call
of hers, which has 5 s to get her up.

Each game writes its line when it changes and at least once a second, never twice in one Lua tick, and logs each line
out and in as `[StellarCoop][NR] night out: ...` and `night in: ...`.

The native part checks only the bytes: 3 to 300 of `0-9`, `a-z`, `/`, `_`, `:` and `-` with single spaces between
words, the first word `h` from the lobby owner and `g` from the guest. It sends an `h` line only while it owns the
lobby and a `g` line only as a guest, and a received line from the wrong side counts as invalid. At most 8 lines a
second go each way; the rest are dropped, with one log line a minute. The last line received is the `night=` line of
`coop-status.txt` while the session holds, and is cleared when the friend is lost or the session ends. Lua checks every
field and refuses the whole line on one bad field. A co-op run ends as lost once the friend's counter has not moved for
5 s. No line carries points: each game turns its own run's final score into points, at most 42 a run at the normal
level and 129 at nightmare.

### The mark line

The mark line is one `coop mark`, sent reliable to each friend past the handshake: its number in the sender's game
(from 1, one count per game process) and its text, cleaned as a say line is and cut to 100 bytes, maybe empty. A longer
text from a friend is cut, not refused. The receiver counts mark lines with say lines against the same 10 a second and
drops the rest, with one log line a minute (`dropped marks from <name>: over the rate limit`). Unlike a say line, the
text goes into `coop-link.log` on both sides (`mark <n>: <text>`, `mark <n> from <name>: <text>`) and into
`coop-status.txt` as the `mark=` line, which the Lua side copies into `UE4SS.log`.

### The race line

The race line carries one line of a [Doro race](modes/race-internals.md), sent reliable. The link passes its text on as
it is: it reads no further, and only refuses a line with a byte outside printable ASCII (0x20 to 0x7e) or longer than
512 bytes in all. At most 40 lines a second are sent, and at most 40 a second are kept from a friend. Your friend's
lines past that are dropped, with at most one line a minute per friend in `coop-link.log` (`dropped race lines from
<name>: over the rate limit` or `too many waiting`). Yours past it are only counted, in the session's end line. During
`coop loopback` with no friend linked, your race lines come back as your friend's.

### The score line

The score line carries one line of a [score attack](modes/scoreattack.md#how-it-works) round, sent reliable. It goes in
a match lobby only: Lua's `score <text>` request sends it to every member past the handshake. Outside a match lobby the
request sends nothing. A score line that arrives there is dropped with no log line. The link reads it as it reads the
race line: it passes the text on as it is and refuses only a byte outside printable ASCII or a line over 512 bytes. A
member's line reaches Lua in `coop-chat.txt` as `score <SteamID> <text>`. The SteamID is the one Steam gives for the
sender, never one from the text. `core/link.lua` keeps these lines apart from the chat for the module
(`take_score()`).

At most 16 lines a second go out. At most 16 a second are kept from each member. A player sends about one a
second. The margin is for reliable lines that a stall of up to 10 s holds back, which then arrive together. Lines past
the limit are dropped, with at most one line a minute in `coop-link.log`: `dropped our score lines: over the rate
limit`, or `dropped score lines from <name>: over the rate limit` (or `too many waiting`). In a minute that carried score
lines, `score lines, last 60 s: <in> in, <out> out, <dropped> dropped` follows the 60 s link line.

### The mode line

The mode line carries one line of a mode of online sessions, sent reliable. The [fishing
tournament](modes/fishing.md#the-mode-line) is the first such mode. Its word is `fish`. The
[photo hunt](modes/photohunt.md#the-mode-line) uses the word `photohunt`. The line goes in an online
session only: Lua's `mode <word> <text>` request sends it to every member past the handshake, the host and each guest
the let line names (guests link with each other, see [Sessions of more than 2
players](#sessions-of-more-than-2-players)). In a match lobby the request sends nothing. A mode line that arrives there
is dropped with no log line. The word is 1 to 16 lowercase letters. The link reads no further: it passes the text on as
it is and refuses only a byte outside printable ASCII (0x20 to 0x7e) or a line over 512 bytes. A member's line reaches
Lua in `coop-chat.txt` as `mode <SteamID> <word> <text>`. The SteamID is the one Steam gives for the sender, never one
from the text. `core/link.lua` keeps these lines apart from the chat under their word, 64 at most a word
(`take_mode(word)`), so each mode takes its own lines only. The mode's module checks who may send which text.

The rate is the score line's, for all modes together: at most 16 lines a second go out. At most 16 a second are
kept from each member. Lines past the limit are dropped, with at most one line a minute in `coop-link.log`:
`dropped our mode lines: over the rate limit`, or `dropped mode lines from <name>: over the rate limit` (or `too many
waiting`). With nobody linked the request sends nothing. In a minute that carried mode lines,
`mode lines, last 60 s: <in> in, <out> out, <dropped> dropped` follows the 60 s link line.
### The dr line

The dr line carries one line of a round of [Doro races in matches](modes/race-internals.md#races-in-a-match), sent
reliable. It is a copy of the score line with its own kind, so score attack's round, which takes every score line at
each pass, never reads it. It goes in a match lobby only: Lua's `dr <text>` request sends it to every member past the
handshake. Outside a match lobby the request sends nothing. A dr line that arrives there is dropped with no log line.
The link passes the text on as it is and refuses only a byte outside printable ASCII or a line over 512 bytes. A
member's line reaches Lua in `coop-chat.txt` as `dr <SteamID> <text>`, the SteamID the one Steam gives for the sender.
`core/link.lua` keeps these lines apart from the chat, the race lines and the score lines for the module (`take_dr()`,
64 at most, the oldest dropped).

At most 16 lines a second go out (`kDrPerSecond`). At most 16 a second are kept from each member. A racer sends about
one a second. The host's busiest moment is the round's start: its track, cps and go lines, up to 8, one each 250 ms.
Lines past the limit are dropped, with at most one line a minute in `coop-link.log`: `dropped our dr lines: over the
rate limit`, or `dropped dr lines from <name>: over the rate limit` (or `too many waiting`). In a minute that carried
dr lines, `dr lines, last 60 s: <in> in, <out> out, <dropped> dropped` follows the 60 s link line.

### The gift line

The gift line carries a [cut mailbox](../cutmenus/menus-internals.md#cut-mailbox) gift and its answer, sent reliable: `s` with the gift's id (1
to 20 digits, not 0), an item name (letters, digits and `_`, at most 64) and a count from 1 to 10; `a` when the
receiver kept it; `n` and a word of 1 to 16 lowercase letters when it refused it. The link checks that shape and no
more: Lua checks the item. At most 8 lines a second go each way, and each one, sent, refused or received, has a line in
`coop-link.log` (`gift line sent: ...`, `gift line not sent: ...`, `gift line from <name>: ...`). A gift line of yours
that cannot go (no session, past the rate, a send Steam refused) comes back to Lua at once as `gift n <id> nolink`;
Lua gives the items back only when it was the gift's first line.
Your friend's lines reach Lua in `coop-chat.txt` as `gift <payload>`, beside the chat and race lines. During
`coop loopback` with no friend linked, your gift lines come back as your friend's.

### The bike line

The bike line carries where a player's [parked bike](../vehicles/bike-internals.md#the-bike-line) stands, sent reliable:
`park` with its map, place and angles, or `none` when she has no parked bike (she rides it, has `bike=off` or has no
place yet). The map is a lower-case package path as the pose table carries it: `/` first, then `a-z`, `0-9`, `_`, `/`
and `-`, at most 128 bytes. `<x> <y> <z>` are whole centimetres and `<pitch> <yaw> <roll>` hundredths of a degree, each
an optional `-` then digits, the place within 10,000,000 and the angles within 36,000. With a 128-byte map the line is
at most 195 bytes. A line of another shape counts as an invalid message (`invalid message from <name>` in
`coop-link.log`).

Each player sends only her own bike. Her line is keyed by the Steam identity that Steam attaches to each message, so no
member can move another player's bike. The line goes in co-op lobbies, match lobbies and the SBO lobby alike, with no
owner role. The native part sends Lua's newest line (`coop-parked.txt`) to each member past the handshake who has not
had it, then again after her hello and her return from lost, so a late joiner and a broken session get it with no
timer. A send Steam refuses goes again at the next pass. Nothing goes before Lua's first line. The receiver keeps each
member's latest line and lists it in `coop-status.txt` as `bike_of=<SteamID> <payload>` after the `member=` lines until
she leaves the lobby. No rate limit applies beyond keeping the latest line. In a match lobby the flood rule of
[In a match lobby](#in-a-match-lobby) counts it with her other channel-0 lines.

### The start, count and end lines

These lines run a round in a [match lobby](#match-lobbies). Only the lobby's owner sends them, reliable, to each member
past the handshake. A member counts the same line from anyone else as invalid.

The owner counts the players past the handshake, itself included and lost players left out. When they reach the
mode's minimum (2 for `ffa`, `scoreattack` and `race`), a 10 s countdown starts. When the lobby is full (8) it drops
to 5 s. Each member gets a count line with the seconds left at the start, at the drop to 5 s, and when they complete the
handshake while it runs. If the count falls under the minimum, the countdown stops and the owner sends `count stop`.

A member takes at most 8 start, count and end lines a second from the owner and drops the rest, with at most one log
line a minute (`dropped round lines from <name>: over the rate limit`). It logs a count line only when the line moves
its own countdown (`countdown: <n> s from <owner>`, `countdown stopped by <owner>`), so an owner who repeats one does
not fill `coop-link.log`.

At 0 the owner checks the count again. If it still holds, the owner sets the lobby not joinable, writes
`sbo_state=playing` (Public lobbies only) and `sbo_map`, and sends the start line: the mode, the map, a 32-bit seed and
the SteamIDs of the players counted at 0, the owner first, then in Steam's member order. A member whose SteamID is not
in the list stays in the lobby, out of the round, with the notice `A round started without you.`, shown once for the
countdown that member saw. A player who tries to
join after the start gets Steam's answer 3 and the notice `Could not join: that game is closed (a private session, or
a match that started).`

`match end` on the owner ends the round: the lobby is joinable again, `sbo_state` goes back to `open` on a Public lobby,
and each member gets the end line. While the minimum still holds, the next countdown starts at once. `coop status`
shows the countdown as `match=countdown <mode> <players> 8 <seconds left>`, and the last round as `round=<n> start
<mode> <map> <seed> <id>,...` while it plays, then `round=<n> end <why>`: `host` after `match end`, `left` when this
game left the lobby during the round, `host_left` when the lobby changed owner, and `host_lost` after 10 s of silence
from the owner.

### Unlinked peers, pings and session requests

Say, vit, pak, paks, camps, spot, rest, night, mark, race, score, mode, dr, gift, bike, start, count and end lines from a friend who has not passed the handshake are ignored, without a log line.

Accepted peers ping every 2 s. A game answers at most 4 pings a second from one player and sends no pong for the
rest. A peer silent on channel 0 for 10 s is marked lost (`<name> silent for 10 s: lost`)
until they are heard again; they stay linked and their table is kept. A message longer than 512 bytes is treated as
invalid.

A session request from Steam is accepted only after a live check that the requester is a member of your lobby. A guest
of an online session also accepts one only from the host and the members the host's let line names. Any other request
is ignored.

## Channel 1: tables and poses

Channel 1 carries the pose path's bytes unchanged: the component table as text starting `SBT 29` (sent reliable) and
each pose as a binary message starting `SBP` (a keyframe) or `SBD` (a delta), then the protocol byte (sent unreliable,
without Nagle delay). Same-place enemies add a binary message starting `SBE` and the protocol byte, at most 30 a
second (sent unreliable): the place, rotation and animation speed of up to 16 enemies that the sender moves on the
other screen. An `SBE` goes to the pair only (`Link::partner()`), never in a match lobby.

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

## Channel 2: asset names

A ghost's events name what her game played by an asset key, 1 to 4096 in a link session (see
[Partner: how it works](partner-internals.md)). The name behind each key travels once on channel 2, reliable, to every
member:

```
SBA29 <k> <kind> <asset> <a> <b>[ <params>]
```

- `kind` is `sound`, `niagara`, `cascade`, `decal` or `trail`. A sound's `a` and `b` are its sound class and
  attenuation paths, or `-`, then `-` or at most 8 `<name>:<int>` parameters joined by commas. Niagara and Cascade
  carry `- -`. A decal carries its size in cm (`<x>,<y>,<z>`, 1 to 4096) and its fade-out in ms (0 to 60000). A trail
  carries its two sockets (`<socket>,<socket>`) and its width in 1/100 cm (1 to 100000).
- Every path is one of SB's own: `/Game/[DLC_<n>/](Sound|Art)/<folders>/<asset>.<asset>`, at most 255 bytes, names of
  letters, digits and `_`. A line is at most 512 bytes. The receiver refuses any other line (`parse_asset_line` in
  `game/events.h`).
- `glue/steam.cpp` keeps every SBA line of the link session in order. Each member past the handshake gets them from her
  own place in that list, at 8 KB a second, while fewer than 64 of the 256 channel-2 lines wait for her. So the pair's
  fight, world and story lines keep their room. A member who comes in later gets the earlier lines the same way.
- A new pair keeps the SBA lines queued both ways, as it keeps the shared quests' lines. A link session that starts or
  ends empties them. Our keys then start again from 1. A guest who becomes the pair sends all her lines again, since the
  host moved her ghost to slot 0 and forgot her names. The other members drop the lines they already have.
- The receiver takes an SBA line from any member and files it under her ghost slot. A key lives for the link session:
  another line for a key she already named is refused. A slot forgets its names when its member changes (leaving
  counts) and when a session starts or ends.

Two files per ghost slot carry the names to Lua and back. Slot 0's have no number, the others end in `-<k>`. Both are
appended to, not rewritten:

- `coop-names.txt`: the native part adds each name it took as `name <k> <kind> <asset> <a> <b>[ <params>]`. Lua reads
  it from its last offset (`names(from, head)` in `core/link.lua`). A reset starts the file again with a head line
  `book <n>`, its number new at each reset of the run. A file shorter than that offset, gone or with another head
  means the slot was reset. The head catches a new file that is already longer than the offset.
- `coop-loaded.txt`: Lua adds `loaded <k> 0x<object> 0x<class> 0x<a|0> 0x<b|0>` once a key's assets are loaded
  (`loaded(line)`). The native part reads it from its last offset every 250 ms and hands the objects to the game thread
  in place, with no new ghost. A later line for a key replaces the earlier one. A key the slot never named is refused.
  A file shorter than that offset, or gone, empties the slot's objects.

While `coop loopback` runs outside a link session, our own names go to slot 0 too. In a link session slot 0 holds a
member's names, so the loopback ghost gets none of ours there. Every 60 s `coop-link.log` counts them: `asset names,
last 60 s: <n> taken, <n> refused; <n> loaded lines taken, <n> refused`. The native part deletes both files when it
starts.

## Protocol versions

The protocol number goes up with any change to what travels between two games, so an older Stellar Blade Online version
is refused instead of misread:

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
| 19 | Matrix XIII's world rows (spawn rows, camps, warps): shared Naytibas key an enemy by its spawn row's ID, so a peer without those rows would never match the host's new enemies; no line changes shape, the number keeps 0.7.5 out |
| 20 | The PvP test's pvp line on channel 2: a drop of the attacker's stand-in for the victim, applied to the victim's EVE in her game, and the match lobbies' start, count and end lines on channel 0 |
| 21 | Never released: development builds of the shared world's `SBW` lines on channel 2 and of the dlc and dlcs lines on channel 0 used it (see [Shared world: how it works](../world/objects-internals.md)) |
| 22 | Never released: development builds of story together's `SBS` lines on channel 2 (the host's story scenes and story trips, followed in the guest's game; see [Story together: how it works](../story/together-internals.md)) and of the guest's `SBQ22 step` line (a quest step she made first, made in the host's game) used it |
| 23 | Online sessions of up to 4 players: the host's `let` and `wait` lines on channel 0, which a protocol-22 peer would count invalid; a protocol-22 game would also leave a lobby of 3. The cycle line (each game's New Game+ count and difficulty) and the bike line (where each player's parked bike stands) on channel 0. 23 also adds the shared world's catch-up lines (`c ask`, `c`, `c end`) on channel 2, which an earlier protocol-23 development build counts malformed. On channel 2, shared flinches and stagger resistance: the cc line with the hit's level and the reaction's time (`SBF23 cc <gen> <hguid> <effect> <level> <ms>`), the host's `SBF23 stagger <gen> <0\|1> <0\|1>` and the owner's `SBF23 poise <gen> <hguid> <oe> <k> <ms>` (see [Shared enemies: how they work](../fight/enemies-internals.md#lines-and-counters)), which an earlier protocol-23 build drops as malformed lines. Never released |
| 24 | The score attack: the `scoreattack` match mode under `sbo_mode` and its score line (`SBC24 score <text>`) on channel 0 (see [The score line](#the-score-line)), which a protocol-23 peer would count invalid. Never released |
| 25 | The [spot lines](#the-spot-lines) (`spot?`, `spot`) and the [rest line](#the-rest-line) on channel 0, with the zone type as the [vit line](#the-vit-line)'s 13th number, which a protocol-24 peer would count invalid. Never released |
| 26 | The [mode line](#the-mode-line) on channel 0 in online sessions, first for the fishing tournament (go, ready, catch, board, rank and void), which a protocol-25 peer would count invalid. Never released |
| 27 | [Doro races in matches](modes/race-internals.md#races-in-a-match): the `race` match mode under `sbo_mode` and the [dr line](#the-dr-line) on channel 0 (track, cps, go, ready, cp, done, rank and void), which a protocol-26 peer would count invalid. Never released |
| 28 | The ghost's fidelity: her drone (a free part placed by the pose), six effect slots, four event slots and her morph weights in the pose and the table, with the [asset names](#channel-2-asset-names) (`SBA28 <k> <kind> <asset> <a> <b>`) on channel 2 to every member, which a protocol-27 peer would refuse. Never released |
| 29 | Shared boss fights ([Shared enemies: how they work](../fight/enemies-internals.md#shared-bosses)): the `fin`, `qte-own` and `spec` lines on channel 2, the host's `boss_finish` as the `bosses` line's last word and a summon's owner in its key. A guest sends the boss lines of a boss her game runs and story together's `SBS` lines of a [boss QTE scene](../story/together-internals.md#boss-qte-scenes) she leads. A protocol-28 peer would count the new lines invalid (this version) |

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
line shows the highest member cap as `link cap <n>`. A single 16 KiB keyframe takes 62.5 ms to leave at Steam's
default send rate and a 64 KiB table 250 ms, which is why one reading over the limit is not enough.

Each member has her own cap, and in a match lobby it starts at 30. The pose path encodes at the highest member cap,
never above `send_rate`. A delta goes to a member only once 1000 / cap less 5 ms has passed since her last pose, so at
30 she gets every second delta of a 60 a second stream. Keyframes, tables and SBE lines always go.
