# Troubleshooting

Stellar Blade Online is an experimental beta, played in only a few sessions between two PCs so far.

**Close the game before you copy, change or delete any mod file.**

## Where to look

- `ue4ss/UE4SS.log` (in `SB/Binaries/Win64/`): every line from the mod starts with `[StellarCoop]`. Answers to
  commands and keys read `[StellarCoop] OK: ...` or `[StellarCoop] STOP: ...`; status changes read
  `[StellarCoop] link: ...`.
- `Mods/StellarCoop/coop-link.log`: the native part's numbered events, in UTC. The previous run's log is
  `coop-link.old.log`.
- `coop status` (console) or F6: the current state. See [usage.md](../usage.md#status-lines).
- `coop report` (console): writes `coop-report.txt` with versions, the save folder, where `xinput1_3.dll`,
  `dinput8.dll`, `dwmapi.dll` (UE4SS's loader) and `steam_api64.dll` were loaded from (other mods' DLLs can change
  results), the status, a summary of save folder changes and the last 100 events, with SteamIDs and join codes masked
  (see [Which logs to send](#which-logs-to-send)).

## Install and the Steam link

### F6 does nothing, or no `[StellarCoop]` line at all

- No `[StellarCoop]` line in `UE4SS.log`: UE4SS did not start the mod. Check that the folder is
  `Mods/StellarCoop/Scripts/main.lua`, with `enabled.txt` and `StellarCoop.dll` next to `Scripts/` (Windows "Extract
  All" may add one folder level). See [INSTALL.md](../../INSTALL.md#install).
- `Native part not loaded`: `StellarCoop.dll` is missing or was quarantined. The keys and the Steam link need it. See
  [INSTALL.md: Windows Defender and SmartScreen](../../INSTALL.md#windows-defender-and-smartscreen).
- `Native tick unavailable`: the DLL loaded but its per-frame entry did not. Without it no pose is read or drawn, so
  no ghost shows, and the loopback, record and replay refuse to start.
- A `settings:` line: a value in `coop-settings.txt` was refused and keeps its default. `F10` is never allowed, and
  two actions on one key put all nine keys back to their defaults: `F5` (menu), `none` (host), `F6` (status), `F7`
  (travel to the host), `F8` (leave), `F9` (race checkpoint), `F3` (bike), `F4` (gun mode) and `F2` (emote wheel). See
  [settings.md](settings.md#coop-settingstxt).
- `keys: <key> is also bound by a mod loaded earlier; both run`: another mod uses the same key. Pick another key.

### `Co-op: waiting for Steam.` or `Co-op: the Steam link stopped; coop status says why.`

- `steam=waiting` in `coop status`: the game has not started Steam yet. Until then each request gets
  `Steam is not ready yet: request ignored` in `coop-link.log`.
- `missing=<name>`: the game's Steamworks build lacks a function the link needs. The native part stops for the run,
  the link and the ghost with it, and `coop-link.log` says `worker stopped: Steam exports missing`.
- `stopped=fault <code>`: Steam faulted under the link (for example at game exit), and the native part stopped the link
  and the ghost to keep the game running. The last line of `coop-link.log` says why the worker stopped. Restart the
  game.

### My friend cannot join

- `Version mismatch: ...`: you run different Stellar Blade Online protocols or game builds. Both players update
  together: see [INSTALL.md: Update](../../INSTALL.md#update).
- `Invite held: joining once your save has loaded.`: they join once their save has loaded. This is normal.
- `Could not join: that game is full.`: an online session holds as many players as its host's `max_players` (2 to 4);
  a match lobby of the [SBO lobby](../online/lobby.md) holds 8. `Left: the lobby has more than 4 players.` means the lobby
  was not made by Stellar Blade Online (it holds more players than a Stellar Blade Online session can), so the mod
  left it.
- `Could not join: that game is closed (a private session, or a match that started).`: the host's online session is
  Private (`who_can_join=closed`), which nobody can join, or the match lobby of the [SBO lobby](../online/lobby.md) shut when
  its round started. A match lobby opens again when the round ends. A Private session stays shut: the host has to host
  again with another Who can join value.
- `Could not join: Steam had an unexpected error. Try again.`: Steam failed the join on its side.
- `Could not join: too many tries in a short time. Wait a moment and try again.`: Steam limits how often an account
  can try to join.
- `Could not join: a player in that game has blocked you on Steam.` or `... you have blocked a player in that game on
  Steam.`: Steam does not let two players into one lobby when one has blocked the other. Removing the block in Steam
  lets the join through.
- `Could not join: your Steam account is limited. Spending 5 USD on Steam lifts the limit.`: Steam does not let a
  limited account join this lobby.
- `Could not join: Steam has banned you from that game's lobby.`, `... your Steam account has a community ban.` or
  `... that Steam group is locked or disabled.`: Steam refused the account. Stellar Blade Online cannot change that.
- `Could not join: Steam response <n>.`: Steam gave an answer its documentation does not list. `coop-link.log` has the
  same number in `joining lobby ... failed (response <n>)`. Send `coop-report.txt` (`coop report`) with a bug report.
- `coop join` without an id logs `no friend is in a Stellar Blade lobby`: ask your friend to host, then accept their
  invite, or use `coop join <lobby id>`.
- `You are in <host>'s game: leave it first.`: a guest cannot host. Press F8 first.
- The host set Who can join to Invitation (`who_can_join=invitation`): that session shows neither in the Steam
  friends list nor in Find a session. Join with the host's code, or the host invites you with the menu's Invite a
  friend row. See "Join codes and asking to join" below.

### Find a session lists nothing

- `No open session.`: the search found no session to show. The Public tab lists Public sessions only. A session
  hosted with Friends only shows on the Friends tab of the host's Steam friends. Invitation and Private sessions
  never show. Ask the host which Who can join value they used.
- A session of another protocol or game build is never listed. The bottom left of the Sessions screen names yours
  (`Your version: protocol <n>, game build <n>.`). The host's `coop status` names theirs on its first line (`proto=`
  and `build=`). Both players update together: see [INSTALL.md: Update](../../INSTALL.md#update). A host on a build of
  the mod from before the session list writes no rows, so it is not listed either: join it with an invite or a code.
- A full session is not listed. An online session holds as many players as its host's `max_players` (2 to 4). A
  player who waits for the host's answer takes a place, so a session she fills leaves the list until the host
  answers.
- A host you blocked on Steam or with `coop block` is not listed, nor is your own session.
- The Friends tab asks Steam for each friend's lobby and waits 5 s at most. A lobby Steam sent nothing for is left
  out (`coop-link.log`: `lobby <id> sent no data within 5 s`). Refresh to ask again.
- `The search failed. Refresh to try again.`: Steam refused or failed the search (`coop-link.log`: `Steam refused the
  lobby search` or `lobby search failed`).
- `You can search again in <n> s.`: one search every 5 s at most. Refresh once the count ends. While a match search of
  the [SBO lobby](../online/lobby.md) runs, the status line shows the search and Refresh does nothing: Steam runs one lobby
  search at a time.
- From the console, `coop list public` or `coop list friends` gets `Leave this game first.` in a lobby,
  `A search is already running.` while a search runs and `Wait 5 s between two searches.` under 5 s after the last
  one.

For the host whose session does not show:

- Only Who can join set to Public puts it on the Public tab. Public and Friends only put it on the Friends tab of your
  Steam friends. The notice `Hosting a public session: other players can find it in Find a session.` says it is
  listed.
- The other player needs your protocol and game build and a free place in your session. They do not see it when
  you are on their block list or they blocked you on Steam. A player on your block list still sees it: your game
  refuses them when they join.

### Join codes and asking to join

For the player who types the code:

- `A join code is 7 letters and digits, like XXX-XXXX.` under the code box: the text does not have the shape of a
  code. Type the 7 letters and digits, with or without the dash after the third.
- `That is not a join code: check its 7 characters.`: the shape is right but the code's check fails, so a character
  is wrong. I and L count as 1 and O as 0, and no code holds a U. Ask the host to copy the code (Copy my code, or
  `coop copy`) and paste it. About 1 typo in 9 passes the check; it then usually leads to one of the two notices
  below.
- `Could not join: that game no longer exists.`: the host left, or hosted again, and each session has its own code.
  Ask for the new code.
- `Could not join: that is not a StellarCoop game.`: the code leads to another game's lobby. Check the code.
- `Joined <host>'s game. Waiting to be let in.`: you are not on the host's Steam friends list, or the host set Friends
  join without asking to Off, so the host has to accept you. Your partner's ghost and card do not show until then. The
  host has 60 s to answer. The game's popup `Waiting for <host>'s answer` counts them down; Close in it cancels your
  request and leaves the host's lobby.
- `<host> refused the link: <reason>`, with `you were not let in`, `no answer within 60 s`, `you were removed from
  this session` or `you cannot join this session again`: the host refused or removed you, and your game left. That
  session stays closed to you. A new session the host starts has a new code and the host is asked again. A removed
  player stays on the host's [block list](playing-with-a-friend.md#block-list), so every later game of that host
  refuses them too until the host types `coop unblock`. After a game restart the host needs your full SteamID for
  that: send the number after `steamid=` in your `coop-status.txt`.
- `Left <host>'s game: Steam would not set relay only.` or, in a match, `Left the match: Steam would not set relay
  only.`: every match goes through Steam's relays only, as does a session with a player who is not your Steam friend.
  Steam refused that setting 3 times, 1 s apart, so your game sent nothing and left. `coop-link.log` has each try
  (`Steam refused relay only, try <n>/3`). Restart the game and try again. If it happens again, send the logs (see
  [Which logs to send](#which-logs-to-send)).
- `No link with <name>: Steam would not set relay only.`: in a session of more than 2 players, Steam refused relay
  only 3 times for another guest who is not your Steam friend. You stay in the host's session; that guest's EVE and
  chat do not reach you until she leaves and joins again.

For the host:

- The question does not show: it opens in a world only, while the game is not paused and shows no menu or mouse
  cursor, and while the chat box is closed. After `coop ui off` it never shows. From the console, `coop status` gives
  the waiting player on its `pending=***<4 digits> <name>` line, the SteamID masked as in every log (see
  [Which logs to send](#which-logs-to-send)). Type `coop allow <4 digits>` or `coop deny <4 digits>`, or the full
  SteamID from the `pending=` line of `coop-status.txt` in the mod folder. With no answer, the player is refused
  after 60 s.
- A refused player is still in the lobby. Steam cannot take a player out of a lobby. A Stellar Blade Online game leaves
  when it is refused. A game that does not keeps its place in the lobby: it gets the refusal again every 10 s and never
  links. Host again: the new session has a new code.
- Players you do not know keep asking: a Public session is listed for every player of your version. Leave, then host
  again with Friends only, or with Invitation and give the new code only to the player you expect. While you host, a
  session keeps the Who can join it was hosted with.
- `A player tried to join your private session and was refused.`: a player got into the lobby of your Private session
  although Steam shuts it to joins. Your game refused them before any handshake. They cannot come back to it.
- `<name> was refused: Steam would not set relay only.`: a session with a player who is not your Steam friend goes
  through Steam's relays only. Steam refused that setting 3 times, 1 s apart. Nothing went to that player. Restart
  the game and host again.
- `No join code to copy.`: you do not host, or you host with Who can join set to Public, Friends only or Private.
  Leave, set it to Invitation, then host again.
- `Could not copy the join code <code>.`: the Windows clipboard was busy. Select Copy my code again, or read the code
  from that row. On Linux, if the code does not paste outside the game, read it from the row too: no test has yet
  checked that Proton passes it on to the desktop's clipboard.
- `Hosting without a join code (unexpected lobby id): ...`: Steam gave the lobby an id that a code cannot hold. The
  invite dialog opens instead; invite the player from it.

## The ghost and its looks

### I do not see my friend's ghost

- `ghost=off` in `coop status`: no session has started since the mod loaded, or the ghost was turned off with
  `coop puppet`. It turns on again with the next session, or with `coop puppet`.
- `ghost=hidden map`, or the notice `<name> is in <map>, you are in <map>.`: you are on different maps. The ghost
  shows once you are on the same map.
- `ghost=waiting`: no table has arrived yet, or the ghost is being built, or your EVE has been in the world for less
  than 2 s. A table that needs a new ghost is taken at most once every 2 s; your friend's next resend (5 s after
  their table changed) brings it.
- The ghost appears and disappears: it hides after a second without a pose, so poses are arriving with gaps. Look
  at the `<name>, last 60 s:` line in `coop-link.log` (RTT, drops, Steam's session quality).
- `engine=off reason=...` in `coop status`: the native pose path is off. On a game build other than 26123051 it never
  reads game memory, so no ghost can be drawn. After a fault, `coop-link.log` has an `engine off: fault ...` line.
- `Ghost not built: ...`: the build failed for that table. It is tried again 2 s later, up to 3 tries in all; after
  the third failure the notice `Ghost failed 3 times: the reason is in UE4SS.log.` shows. Then a new table, a level
  change or `coop basesuit` tries again.
- `coop off` was used: everything stays off until the game restarts.

### The ghost wears the base suit, or a part is missing

Only the body and the hair have a base-suit fallback. One of them falls back when your PC cannot load its mesh (a DLC
you do not own, a mod you lack), when its path is outside the game's character folders and none of your CNS packs
declares it, or when its bones differ. Any other part whose mesh has other bones is drawn on that mesh, its bones
matched by name; one that cannot be loaded is left out, with the parts that follow it. The `Ghost ... built` line in
`UE4SS.log` counts the parts on the base suit and those left out, and gives each one's reason, such as `missing` or
`not declared by your CNS packs or a mod you both have`. `coop basesuit` may also be on: run it again to go back.

### A look misbehaves

The cloth, dyes and effects looks have not been tested in game yet, and all three are on by default. If the game crashes or
the ghost looks wrong with one on, turn it off: `cloth=off` (or `dyes=off`, `effects=off`) in `coop-settings.txt`,
Options > Ghost in the co-op menu, or `coop look <look> off`. An `effects off: fault ...` line means a fault turned
effects off until the game restarts; the ghost stays, without effects.

Your EVE's sounds go to the others with the sounds look on (`sounds=on` in `coop status`). A line `sounds refused:
0x<slot> holds <value>; nothing of that set swapped, the ghost goes on without sounds` in `coop-link.log` means
another mod hooks the same function of the game. Stellar Blade Online leaves that mod's hook in place, so your sounds
are not sent while it is loaded. When the line ends with `(her events' context)`, only some of them are sent. `coop
status` then shows `sounds=refused`. A `sounds off: fault ...` line means a fault turned them off until the game
restarts. The ghost stays either way.

Your EVE's world effects (her footstep dust, the effects her skills place in the world) go the same way with the
effects look on (`world_effects=on` in `coop status`). A line `world effects refused: ...` means another mod hooks the
game's Niagara or Cascade start. Those effects are not sent while it is loaded. `coop status` then shows
`world_effects=refused`. A `world effects off: fault ...` line means a fault turned them off until the game restarts.

## Doro races

### EVE is invisible, or only a Doro shows

During a [Doro race](../online/modes/race.md), and after `coop race look on`, the Doro look hides EVE's parts and the drone
that follows her, and draws a Doro at her feet. The race's end, `coop race quit`, `coop off` and a map change show both
again. If EVE or the drone stays hidden:

- Type `coop race look off`. While the look is still on, it answers `OK: Doro look off (coop race look off): <n> parts
  shown again, tick option <t> asked back.`, with `and the drone` after `parts` when it hid the drone. If it answers
  `The Doro look is off already.`, go on to Ctrl+R.
- Press Ctrl+R. The next Lua load reads `coop-look.txt`, which the look keeps while it is on, and shows EVE and the
  drone again at its first tick: `UE4SS.log` says `[StellarCoop][DR] look restored <n> parts from coop-look.txt`, with
  `and the drone` after `parts` when it showed the drone. This covers a look stopped by a Lua error, and an off that
  failed (`Doro look off (...): ...; <error>` in the log keeps the file for this).
- Restart the game if neither works. The look's changes are in memory only, and no save holds them.

A Doro left standing alone where a race was (at a checkpoint or the start line) goes at the next Lua load too:
`[StellarCoop][DR] race: <n> display Doros an earlier Lua load left destroyed`.

While your look is on, your friend sees your ghost with no body unless their game takes part in the race (see
[online/modes/race-internals.md](../online/modes/race-internals.md#the-doro-look)).

### EVE does not speed up or stop after a race

During a [Doro race](../online/modes/race.md), the native part sets four values of EVE's movement to 0 so the race can
drive her (see [Driving](../online/modes/race.md#driving)). Her result, `coop race quit`, `coop off`, a map change and
a new Lua load put them back. If she keeps sliding or does not move with the stick after a race or
`coop race drive probe`:

- Type `coop race drive off` if the probe still runs.
- Press Ctrl+R. At the new Lua load the native part puts the values back at the game thread's next frame. When it held
  them, `coop-link.log` then says `race hold: fields game's (none), tick option game's (none)`.
- `race hold fault ...` in `coop-link.log` means the hold stopped for the game run after a fault, with the values put
  back. Races then do not drive until the game restarts.
- Restart the game if neither works. The values are in memory only, and no save holds them.

### I sit out every Doro race round of a match

The notice and the `[StellarCoop][DR] sit out: <why>` line in `UE4SS.log` say why (see
[A round](../online/modes/race.md#a-round)):

- `the track runs outside the room <key>`: the track does not fit this room's fence. Only a track recorded inside the
  room fits: the host picks another, or Random.
- `the track is on <map>; EVE is on <map>`: the host's track was recorded on another map.
- `EVE is not in the lobby room`: your game does not see you in the SBO lobby's room.
- `SB's chair seats EVE`: you rested on one of the game's chairs in a hall when the round started. Get up before
  the countdown ends.
- `a track is being recorded`, `the drive probe runs` or `a race is on`: type `coop race cancel`, `coop race drive off`
  or `coop race quit`.
- `the game refused the teleport to slot <k>` or `no EVE in the world`: the game would not move EVE to her slot.
- `the track did not come whole`: the host's lines did not all arrive within 10 s. The log line before it gives the
  reason (`match round <n>: ...`).

`No track here: record one in this room with coop race record.` on the host's screen means the room offers no track:
a hall lobby has no official track yet. Record one inside the hall (`coop race record <name>`, F9 at each checkpoint,
`coop race save`), then pick it on the Track row.

### A racer is not ranked

The host's `UE4SS.log` has `rank: refused <name>: <why>` for a split or an end its checks refused (`order`, `time`,
`flags` or `why`; see [The end and the ranking](../online/modes/race.md#the-end-and-the-ranking)). A racer is
also left out when her end came after the ranking. The host stops waiting 65 s after the first finish. It does not
wait at all for a racer whose countdown started more than 10 s after the round's start. A racer who left the lobby or
lost her link is left out too.

## Score attack

### I sit out every round

The notice and the `[StellarCoop][SA] sit out: <why>` line in `UE4SS.log` say why (see
[A round](../online/modes/scoreattack.md#a-round)). After `Your game could not start the challenge`, the line gives the
run's own reason:

- `census: 1 living within 40 m (nearest 23.4 m); 0 wave bodies`: a living character other than EVE stands within
  40 m of your spot. The census of a challenge refuses that start too (see
  [Starting a run](../online/modes/nightop.md#starting-a-run)).
- `your EVE is down`: the in-place respawn after your last death has not ended. Its `respawn` lines say why.
- `a coop no probe rule is set in this game run`: `coop no rule` ran in this game run. Restart the game.
- `the game refused the teleport to <x,y,z>`: the game would not move EVE to her spot.

`EVE is not in the lobby room` means your game does not see you in the SBO lobby's room. `this room has no spot <k>`
means the round has more players than the room has spots.

### Not ranked

The host's `UE4SS.log` has `rank: refused <name>: <why>` for a result its checks refused (`time`, `score` or `twice`).
A player is also left out when her result comes after the host stopped waiting (5 s plus the time limit plus 30 s
after the round's start, a pause included), when she left the lobby or lost her link, or when her run ended with a
stop: a map change, a load, EVE farther than 80 m from her spot for 10 s, or a Lua reload.

### `The round was cancelled.` or `The host left. This round has no ranking.`

`The round was cancelled.` follows the host's `coop match end`, a Lua reload on the host's PC, or a room that offers no
challenge (`round <n>: this room offers no challenge: void` in the host's log). `The host left. This round has no
ranking.` means the host left the lobby or was silent for 10 s. The next host counts down and starts the next round.

### EVE leaves the lobby room after a death

A button pressed on the death screen takes EVE out of the room. Press none: the mod asks the game's in-place respawn
within 10 s of the death. When it does not, `UE4SS.log` has `respawn waits: <reason>`, then
`respawn not asked in 10 s: <reason>`. Send that log (see [Which logs to send](#which-logs-to-send)).

## Fishing tournament

### A catch does not count

Your `UE4SS.log` has `[StellarCoop][FT] catch: <ID> <points>` for each catch your game counted and sent. With no such
line for a catch:

- it came during the countdown, or after your game's last read of the book, a second or so after your end;
- your game took its baseline again in that second, after a map change, a fast travel, a load, a respawn or a loading
  screen (see [What stops a tournament](../online/modes/fishing.md#what-stops-a-tournament));
- the log has `book jumped by <n>: baseline again` or `book fell: baseline again`: that read of the book changed by
  more than a catch, so it counted nothing;
- `coop-link.log` has `fishbook (ask <n>): none <why>`. `noeve` means no EVE could be read (the title, a load).
  `nobook` means SB made no fishing log book for this save. `unread` is a torn read, asked again a second later.
  `unpinned` means another game build.

With the line, the host's `UE4SS.log` may have `rank: refused <name>: <why>` for a catch its checks refused (`sender`,
`fish`, `points`, `time` or `rate`, see [The host's checks](../online/modes/fishing.md#the-hosts-checks)). `sender`
means the host did not count that player: her ready line came more than 10 s after the start line.

### `Not ranked.`

The ranking holds only the players the host counted who are still in the online session at its end plus 10 s. You are
left out when you sat out (a notice said why), when your ready line came late, or when you had left or your link was
lost at that time.

### `The tournament was cancelled.`, `The host left. This tournament has no ranking.` or `No ranking came from the host.`

`The tournament was cancelled.` follows the host's `coop fish stop`, or a Lua reload on the host's PC (the host's log
then has `void <seed>: a catch from <name> of a tournament we do not run`). `The host left. This tournament has no
ranking.` means the host left the online session, or typed `coop off`. `No ranking came from the host.` comes 30 s
after your end with no ranking line, for example after a Lua reload on the host's PC with no catch after it.

## Photo hunt

### A photo does not count

Take the photo in selfie mode, with the Camera. SB's free photo mode (Esc, Photo Mode) checks nothing. Your
`UE4SS.log` has `[StellarCoop][PH] claim: <k> <row>` for each target your game claimed. With no such line:

- the notice after your selfie mode closed says why: `was in your photo: get closer, centre it and face it.` means SB
  saw the target outside the centre box or not faced. No notice means SB answered 0 for each drawn target in every
  photo of that selfie session (too far, off screen or hidden behind something), or the mod saw no photo;
- the photo came during the countdown or after your end;
- the target was taken before your photo (`<name> took ...`): your game claims only an open target;
- the log has `row <row> has no FName in this game: not checked`, `photo checks stopped in this game: <why>` or
  `no target of this round has an FName in this game: no photo checks`;
- `coop-link.log` has no `photohunt (ask <n>): 3 rows checked at each selfie photo` line after GO, or has
  `photohunt (ask <n>) refused: <why>`. `unpinned` means another game build. `fault` comes after
  `photohunt fault ...`: the photo checks stopped until the game restarts.

To see what SB answers for each photo, try the check alone: `coop photohunt try` near a target, then a selfie photo.
Each photo logs `try: shot <n>: <row>=<answer> ...`. With no `try: shot` line for a photo, the mod does not see that
photo: send `UE4SS.log` and `coop-link.log` (see [Which logs to send](#which-logs-to-send)).

With the claim line, the host's `UE4SS.log` may have `rank: refused <name>: <why>` (`sender`, `row`, `taken`, `again`
or `time`, see [The host's checks](../online/modes/photohunt.md#the-hosts-checks)). `taken` means another player's
claim of that target reached the host first. `sender` means the host did not count that player: her ready line came
more than 10 s after the start line.

### `This map has fewer than 3 photo targets.`

Only Xion, the Wasteland and the Great Desert have photo targets. `coop photohunt status` lists the targets of your
map after `targets here:`.

### `The photo hunt was cancelled.`, `The host left. This photo hunt has no ranking.` or `No ranking came from the host.`

`The photo hunt was cancelled.` follows the host's `coop photohunt stop`, or a Lua reload on the host's PC (the host's
log then has `void <seed>: a claim from <name> of a round we do not run`). `The host left. This photo hunt has no
ranking.` means the host left the online session, or typed `coop off`. `No ranking came from the host.` comes 30 s
after your end with no ranking line, for example after a Lua reload on the host's PC with no claim after it.

## Menu, chat, controller and screen

### The game ignores its keys after the co-op menu or the chat

Open the console (F10 or `~`) and type `coop ui reset`: the menu, the chat box and the code box close, an open host's
question is answered with Deny, and the game gets its keys back. Without the console, press Ctrl+R or restart the game.
`UI off until the mod reloads: <why>` in `UE4SS.log` means that the on-screen UI hit an engine error and turned itself
off; notices then show on the line above EVE. `coop ui off` turns the UI off the same way by hand.

### No co-op line hint at a camp phone booth

- Look for `booths:` lines in `UE4SS.log`. `booths: <n> on <map> (<ms> ms)` gives the number of booths that the scans
  have found on that map so far. With no `booths:` line at all, no scan has run yet: the on-screen UI is off
  (`UI off until the mod reloads`, or `coop ui off`), `coop off` ran, or the native part is not loaded.
  `booths: 0 on <map>` means that no booth was loaded at the scans so far. A scan runs at once on a new map, then
  once EVE is 100 m from where the last one ran and 30 s after it, never while she runs or sprints. Walk 100 m away
  and back, then stand at the booth for up to 30 s.
  `booths: scan failed on <map>: <why> (<ms> ms)` means that the scan hit an error; the next one runs 30 s later.
- Press the menu key at the booth. `line: booth <name> (<class>) at <d> m` after `key F5: menu` means that the line
  opened. If the main page opens with no `line:` line, no booth was within 3 m of EVE: stand closer to the booth.
- The hint stays hidden while the chat box, the code box, a join popup, the co-op saves' question, the Sessions screen
  or the Create a session screen is open. `coop ui reset` in the console (F10 or `~`) closes them all.
- `booths: slow scan <ms> ms (<n> found, <route>, <lookup>)`: one scan took 5 ms or more on that PC. The scan runs on
  the game thread, so that frame took as much longer. `<route>` is how the scan listed the booths: `class hash` is the
  fast route, and `walk` means this UE4SS could not use it, so each scan walks every object. `<lookup>` is how it found
  the two booth classes: `soft path` asks the engine by name; `walk` means UE4SS walked the objects because the
  soft path was not checked yet (no pawn at that scan); `walk (<reason>)` means the check failed for this Lua load,
  with the reason. If the line comes back, send `UE4SS.log` (see [Which logs to send](#which-logs-to-send)).
- `booths: class lookup route: soft path`, or `booths: class lookup route: walk (<reason>)`, comes once a Lua load, at
  the first scan with a pawn, whatever that scan took. `walk (<reason>)` means every booth class lookup of that load
  walks the objects (25 to 35 ms in game for a class that is not in memory).

### The co-op menu or the chat box closed by itself

- `[StellarCoop] focus watchdog: <who> lost the focus for 1 s: co-op UI closed, the game has its input back` in
  `UE4SS.log`: something took the keyboard focus from the mod's UI for 1 s (one of the game's screens, another mod, a
  window switch), so the mod closed it as `coop ui reset` does and gave the game its keys back. Who is `menu`, `chat`,
  `code`, `ask` (the host's question, answered with Deny) or `saves` (the co-op saves' question, closed as Decide later;
  a copy already under way keeps going and its result shows as a notice). A click of the middle or a side mouse button
  does this too. Open the menu again. If it closes this way with nothing else on screen, send `UE4SS.log` and
  `coop-link.log` with a note of what you did just before: the line before the watchdog's names what held the focus, and
  `coop-link.log` has a `window:` line when another window took the foreground. See [interface.md: Focus
  watchdog](interface.md#focus-watchdog).
- No watchdog line: the menu also closes when the game pauses or shows the mouse cursor for one of its own screens
  (EVE dies, a shop opens, your friend's photo mode pauses your game). The chat box closes the same way, and what you
  typed is lost.

### The controller does nothing in the co-op menu

Look at the `pad:` lines in `coop-link.log`:

- `pad: the game's controller input (Slate's handler)`: the mod reads every controller the game reads. Go on with the
  last item of this list.
- `pad: the game has no FName <name>; XInput instead`, `pad: Slate's handler is not at 0x145fe5430 (...); XInput
  instead`, `pad: Slate's handler refused (...); XInput instead` or a `pad: fault` line: the mod could not take the
  game's input and reads XInput. `Slate's handler refused` with a slot holding a value outside the game means another
  mod hooked the same slot. The XInput lines below apply from then on.
- `pad: no XInput pad` (XInput only): the mod sees no XInput controller. A DualSense read by the game's own PlayStation
  support is not one: turn Steam Input on for Stellar Blade (Steam, right-click the game, Properties, Controller),
  restart the game and look for `pad: XInput pads connected: 0` (or another slot number).
- `pad: no XInput in System32: the controller works only through Slate's handler`: Windows' `xinput1_4.dll` and
  `xinput9_1_0.dll` were not found in System32. The mod never loads them from the game folder, where other tools put
  their own `xinput1_3.dll`.
- `Native pad unavailable (no controller in the co-op menu)` in `UE4SS.log`: `StellarCoop.dll` is older than the
  scripts. Install the whole folder of one version again.
- `pad: XInput pads connected: ...` or the game's controller input and still nothing: hold View for a full second, in a world with the game's HUD
  shown. The mod reads the controller only while the game's window is in front. If the menu cannot open, the same
  `STOP:` line as for F5 shows. A join popup ignores every button for 1 s after it shows. In the chat box and the
  code box only B acts (it closes them).

### Screen notices stopped

`Screen notices off: <why>; notices stay in UE4SS.log.`: the engine refused the line above EVE. That line stays off
until the next Lua load (game start or Ctrl+R); the notices still go to `UE4SS.log`, and to the feed at the top left
while the on-screen UI is up.

### Photo mode still freezes everything with Scenery live

- `UE4SS.log` has `[StellarCoop] photo pause: off until the mod reloads: <why>`: the game refused the console variable
  `SB.PhotoMode.PauseMethod` (`reads 0 after the set` on another game build), and photo mode keeps the game's full
  pause until the mod reloads.
- The change applies from the next photo mode: leave photo mode and press P again.
- To go back to the game's own pause, choose Full in Options, or type `SB.PhotoMode.PauseMethod 0` in the console
  (F10).

## UE4SS settings and mod errors

### The game does not start at all with UE4SS installed

You press Play. The game closes or never shows a window. The usual cause is the UE4SS signature file
`SB/Binaries/Win64/ue4ss/UE4SS_Signatures/FText_Constructor.lua`: its byte pattern can stop matching the game after a
Stellar Blade update. UE4SS can then stop the game during its start. Players have reported it on the Stellar Blade
Steam forum since July 2025.

Close the game. Rename `FText_Constructor.lua` to `dFText_Constructor.lua` (or delete it), then start the game again.
If the folder holds both files, delete `FText_Constructor.lua`.

On game build 26123051 (the update of 5 November 2026), the pattern in the Stellar Blade UE4SS 1.3 package matches the
game's FText constructor at one place only, so the file is not the cause there. If the mod's menus show empty texts
after the rename, put the file back and post your `UE4SS.log`.

### The game crashes when EVE lets go of a crate

Look in `UE4SS.log` for a `[StellarCoop] UE4SS-settings.ini:` line. With `HookBeginPlay` on in
`ue4ss/UE4SS-settings.ini`, the game can crash when EVE lets go of a movable crate; with `bUseUObjectArrayCache` on, it
can stutter and crash at startup. Close the game, set `HookBeginPlay = 0` and `bUseUObjectArrayCache = false` (the
Stellar Blade UE4SS 1.3 values), and start it again. The usual cause is another mod's `UE4SS-settings.ini` copied over
the 1.3 one. See [INSTALL.md: Other mods](../../INSTALL.md#other-mods). `UE4SS-settings.ini not checked: <why>` means the
mod could not read the file, so check the two lines by hand.

### `<name>: error (logged once until the mod reloads; the other modules go on)`

A Lua error escaped one part of the mod. The name before the colon says which (`lion`, `race`, `menu`, `ghost`...).
The message follows the parenthesis, and the `stack traceback:` lines under it give the script and the line
(`fight/bosses/lion.lua:<line>: in ...`). Each call of that part logs its first error once until the next Lua load (game
start or Ctrl+R), even when the error comes back every frame, so the same name can show more than once. The other parts
keep running, and the named part is still called at each pass, so it can recover by itself. If it stays broken, a Lua
reload builds it again. Send `UE4SS.log` either way.

## Preview and developer commands

### `coop no` or `coop recruiter` says `STOP`

- `runs only on a co-op save`: at the title, choose Play co-op (or Convert and play co-op), then load your save. See
  [saves.md](saves.md#co-op-saves).
- `STOP: text: this UE4SS build cannot pass a Lua table as a map inside a struct parameter ...` comes from
  `coop scene emil` and is expected: the Emil scene's subtitles stay in Korean and Japanese, and the scene goes on (see
  [story/scenes.md](../story/scenes.md#cut-scenes-coop-scene)).
- `[RC] STOP: text: the native part stopped at a fault ...`: the recruiter's lines stay as they are until the game
  restarts, and the rest goes on (see [online/modes/nightop-previews.md](../online/modes/nightop-previews.md#his-language)).
- Most other `STOP:` lines from the previews give the reason, and many say that nothing was changed. If the probe logs
  `STOP: a new character is ... m from EVE: kill the game now`, kill the game at once. See
  [online/modes/nightop-previews.md](../online/modes/nightop-previews.md).

### `coop devmenu` or `coop devinfo` does nothing

- `coop devmenu <row>` says `runs only on a co-op save`: load a co-op save (see [saves.md](saves.md#co-op-saves)).
  `... is not in this game's EffectTable: nothing asked` means a game update renamed or removed that effect.
- `a respawn or a warp is under way` or `EVE's GUID reads 0`: wait until EVE stands in the world and try again.
- An enemy row changed nothing: it reaches only the enemies near EVE. Move closer and run it again.
- `devinfo quest refused: not playing` (or `not in game`) in `coop-link.log`: open it while you play, not on the title
  screen, during a load or in a menu. `the game opened nothing` means the game refused the panel; send `coop-link.log`
  and `UE4SS.log`.
- `devinfo fault ...: coop devinfo off for the run`: the panels stay off until the game restarts. Send both logs.

## Saves

### The co-op saves question does not show

It shows only with `auto_coop_save=ask`, on the title screen, once the on-screen UI has loaded. `coop status` gives the
reason:

- `saves=coop` on the slot line: the game already uses the co-op copies, and `CO-OP SAVES` shows at the top right of
  the title screen. They stay on until the game restarts.
- `saves=off` or `saves=?`: the mod cannot use the save file name on this game build, or a check failed. The
  `save name: saves=...` line of `coop-link.log` says why. The mod makes no copies, and the game uses your own saves.
  After a game update, the engine line reads `engine=off reason=build stamp ...` or `reason=code bytes differ`, and the
  title screen says once `Co-op saves are off: StellarCoop does not support this version of the game.` Wait for a
  Stellar Blade Online update for the new game version.
- `steam=waiting`: Steam is not ready yet, and the mod needs your Steam ID to find your save folder.
- `convert=busy ...`: a copy pass runs. The question waits for its end.
- `UE4SS.log` has `[StellarCoop] co-op saves: the question cannot show (the co-op UI is off)`: the on-screen UI
  stopped (see the `[StellarCoop][UI]` lines). `auto_coop_save=always` still switches to the copies.

### `Co-op saves off for this load: <why>`

The copies were not switched on, and the game uses your own saves. The reason comes from `coop-link.log`:

- `Continue or Load Game was chosen at the title (load mode 2)`: Continue or Load Game was pressed before the copies
  were ready, so the game loads your own save.
- `slot N's save ...` or `slot N's copy ...`: that save could not be copied (it fails the game's own check, it changed
  while it was read, or the disk is full). The other copies are made, but the switch needs a copy of every save.
- `the backup folder could not be made` or `the backup of <file> could not be written`: the disk is full, or
  `%LOCALAPPDATA%\SB\Saved\StellarCoopBackups` cannot be written.

### CNS outfits stay locked on the co-op saves

CNS (Custom Nanosuit System) decides which of the game's own outfits you have unlocked by reading
`StellarBladeSave00.sav`, your first save, by its file name. Once the game uses the co-op copies (`saves=coop`), it
plays `StellarBladeCoop0N.sav` and no longer writes `StellarBladeSave00.sav`, so an outfit you unlock on the copies
stays locked in CNS.

CNS has a setting for the save it reads. With the game closed, open
`SB\Binaries\Win64\ue4ss\Mods\DekCNS\Scripts\config.lua` and set `Config.ManualSaveFilePath` to the co-op copy you
play: the part of its path after `SaveGames\`, with forward slashes. For co-op slot 1 that is
`"76561198000000000/StellarBladeCoop00.sav"`, with the name of your own save folder in place of the number. CNS reads
the setting when the game starts. Set it back to `""` when you play your own saves again. This has not been tested in
game with Stellar Blade Online yet.

### A save looks wrong

Do not start the game again. Turn Steam Cloud off for Stellar Blade first, then restore your backup. See
[saves.md](saves.md#steam-cloud) and [INSTALL.md: Recovery](../../INSTALL.md#recovery).

## Shared enemies and group play

### Enemies are not shared

Shared enemies are on by default. Both players need Options > Combat > Shared enemies (experimental) set to On in the
co-op menu. The `fight=` line of `coop status` says what is missing (see
[fight/enemies.md: Shared enemies](../fight/enemies.md#shared-enemies-experimental)):

- `fight=off` with no `why=`, and `shared enemies: off (experimental)` in `UE4SS.log` at load: shared enemies are off
  in your game. A `coop-settings.txt` from version 0.2 says `shared_enemies=off`.
- `fight=waiting mode=on ... why=not on a co-op save`: you play your own save. Quit to the title screen and choose
  Convert and play co-op (Play co-op once you have co-op copies), then load the same slot number.
- `her=own-save`, `her=off` or `her=stopped`: your friend plays their own save, has shared enemies off, or theirs
  stopped for the run (their `coop-link.log` says why). `her=?`: nothing came from their game yet. A friend on an
  older build of the mod sends nothing until their shared enemies run.
- `fight=on mode=on role=host enemies=0` or `role=guest pairs=0` while you both fight the same enemies: the two games
  spawned them differently (another map, a different save), or `fight_chars=auto` leaves them out, or a `fight_chars`
  list does not name them. `auto` leaves out bosses and Alpha Naytibas (unless the host has `bosses=on`), the Gorgon,
  two turrets with 999,999 HP and any enemy above 500,000 maximum HP; `coop fight probe` marks the last three with
  `left_out=`. On the guest's side, `coop fight status` lists the host's enemies it could not pair and why: `charId`
  (another enemy at that spawn point), `maxhp` (another difficulty or New Game+ in one of the two games) or
  `duplicate`.
- `paks=differ` in `coop status`: the two games load different `.pak` mods. Each `coop-link.log` names its own in the
  `paks` line at the top; compare the two lists. When both players have `mod_names=on`, the `mods_missing=`,
  `mods_other=` and `mods_extra=` lines in `coop status` name the differences already.
- `dlcs=differ` in `coop status`: the two PCs have different DLCs of the game installed. Each `dlc_missing=` line names
  one your friend has and you lack, each `dlc_extra=` line one you have and they lack. Each `coop-link.log` lists its
  own after `Steam ready` (`DLCs installed:`).
- `fight kill held` in `coop-link.log`: a kill from the other game waits while this game's copy is in a grab or another
  state that takes no damage, or, on the host with same place, while the guest's takedown of that enemy runs (`her
  takedown`). It goes when the state or the takedown ends, or after 6 s (`fight held-expired`).
- `fight full every place holds an enemy in a fight; a hurt one is not shared` in the host's `coop-link.log`: 16 enemies
  are in fights at once, which is the most it shares. The others stay unshared until one of the 16 dies or leaves.
- `fight=stopped why=<why>`: shared enemies stopped for this run, and the ghost and the link go on. A reason that
  starts with `implausible` means a value in the game's memory did not look as expected on this game build.
- `fight desync guest-dead` in the guest's `coop-link.log`: an enemy died on the guest's screen and lives on in the
  host's game, whose copy had more HP left. If it happens often, the guest can set `guest_kills=confirmed` in
  `coop-settings.txt`: the guest's copies then keep 1 HP until the host's game kills its own.

### Quests are not shared

Shared quests are experimental and on by default, and both players need Options > Saves > Shared quests
(experimental) set to On. The `quests=` line of `coop status` says what is missing (see
[playing-with-a-friend.md: Shared quests](playing-with-a-friend.md#shared-quests-experimental)):

- `quests=off`, and `shared quests: off (experimental)` in `UE4SS.log` at load: shared quests are off in your game.
- `quests=waiting mode=on why=friend`: no friend is linked. `why=save`: you play your own save; quit to the title
  screen and load a co-op save. `why=game`: the game's world or quest data is not loaded yet.
- `partner=off`: your friend's side is off. Their setting is off, they play their own save, or theirs stopped.
- The notice `You are behind <name> on <quest>`: the host moved that quest while you stood in another zone, or while
  your copy of it stood at another point. Play it in your own game until it stands where the host's stands; the next
  step made together is then shared.
- `coop quests status` lists what each quest that waits waits for. In `coop-quests.log`:
  - `<quest> ... refused: <why>`, then `<quest> unsynced for the session: the game refused its step`: a check before
    the game's call found that quest other than the host's line said, and the mod leaves it alone until the next
    session.
  - `acquire off until the next load`: after a load, a complete or failed quest was missing from the game's quest map,
    so the guest's game starts no quest until its next load.
  - `blocked: the host's line names no task her quest has in progress`: the two games built that quest's tasks
    differently.
  - `bad host line (...)` or `bad guest line (...)`, and after 16 of them `ignored until the session ends`: lines that
    did not parse or did not fit the quest table.
  - `<number> is no shared quest here`: the two games do not use the same quest table (another build of the mod or of
    the game).
- `quests=stopped`: stopped for this run. `coop-link.log` has `shared quests fault ... in <where>` or a
  `quests: ...; off for this run` line. A reason that starts with `implausible` means a value in the game's memory did
  not look as expected on this game build; `tick on SB's logic thread` means the pass ran on the game's logic thread.

### Same place does not start, or stops

Same place is experimental and on by default, and only the host's setting counts. `coop fight pilot status` prints
the `pilot=` line of `coop status` (see [fight/enemies.md: Same place](../fight/enemies.md#same-place-experimental)):

- `pilot=refused why=...`: another game build, or `coop off`.
- `pilot=off why=fight`: shared enemies are not running. See [Enemies are not shared](#enemies-are-not-shared).
- `pilot=off why=setting`: you host and your `same_place` is off. Turn on Options > Combat > Same place (experimental)
  in the co-op menu.
- `pilot=off why=host`: you are the guest, and the host's game has it off: its row is off, it typed
  `coop fight pilot off`, or an error stopped it there.
- `pilot=off why=asked`: `coop fight pilot off` on this PC. `coop fight pilot on` or the next `coop fight on` lifts it.
- `pilot=stopped`: an error stopped it until the game restarts, and `coop-link.log` has a `same-place enemies fault`
  line. That line also says whether the copies the mod already moved went back to the game. If they did not, they
  stand still until they leave the map or you rest at a camp.
- `pilot=on piloted=0`: it runs, but no enemy is shared yet.
- `fight pilot refused <key> hguid=<n> its movement component is not the game's` in the guest's `coop-link.log`: that
  copy stays an ordinary enemy in her game.
- `fight freeze-lost <key> hguid=<n> state 39 gone too often` in the guest's `coop-link.log`: the game took the mod's
  freeze off a copy 5 times within 10 s. The copy stays an ordinary enemy until the pair ends.
- `fight frozen <key> hguid=<n> the game froze it first`, and later `fight thaw skipped <key> the game froze it first`,
  in `coop-link.log`: the game had frozen that enemy itself (a boss before its cutscene, an enemy that waits for a
  trigger). The mod adds no freeze until the game's freeze ends and leaves it on when it lets the copy go, so the enemy
  wakes at the game's own event. Until then the game with that frozen copy does not take the enemy over, except for
  the guest's takedown: the guest answers a hand-over with `fight own-no hguid=<n> state`, and the host does not take
  back an enemy that the guest runs.
- `pilot take-over refused hguid=<n> oe=<n>: <why>` in `coop-link.log`: that game took an enemy over but could not
  point it at its EVE. The reason is `not net mode 0`, `a logic task in flight` or `copy not found` (each after 250 ms
  of waiting), `a game singleton not made yet`, `no EVE of ours` or `no AI on the copy`. As guest, the enemy goes back
  to the host (`fight own-no hguid=<n> target`), which keeps it for 30 s.
- Enemies never fight the guest: the host's `aggro` is `host` (Options > Combat > Enemies attack (host's)), or her
  side answers each hand-over with `fight own-no` (its reason follows the GUID in her `coop-link.log`).
- A takedown shows only on the screen of the player who does it: compare the `fight exec` lines of both
  `coop-link.log` files. No `fight exec` line on the guest's side: same place is off there, or the host's `aggro` is
  `host`. `fight exec refused <key> hguid=<n> no Groggy or takedown on our copy` on the host: its copy was no longer
  groggy when her line came. `one runs already`: her game started a takedown of that enemy again while the host still
  ran the last one. A takedown that starts within 2 s of her last one on that enemy is refused with no line; the
  `refused` count of `takedowns of hers` in the host's `fight stats:` lines shows it. A takedown also does not move an
  enemy that the guest refused or gave back in the last 30 s, and it moves an enemy only once the host's copy is out
  of the game's NoDamageNoHit state.
- `fight held-expired` right after `fight kill held ... her takedown` or `fight dead held ... her takedown` on the
  host: the end of her takedown did not reach the host within 6 s of its start, and the host killed the enemy anyway.

If copies slide, stand still or play no animation, keep `coop-fight.log` from both PCs: its `pilot drawn:` lines count
the copies moved, the Shows replayed, late and missing, and the drift (how far the game moved a copy between two of the
mod's writes, in cm/s and degrees a second). Drift above a few cm/s on a copy at rest means something in the game still
moves it.

### A shared boss differs between the two games

Shared bosses (`bosses`) are experimental, on by default and not tested in game yet, and only the host's setting counts.
With same place on, the guest's copy of a boss follows the host's through the lines in
[fight/enemies-internals.md: Shared bosses](../fight/enemies-internals.md#shared-bosses).
With `aggro=game` a boss changes hands as a common enemy does: while the guest's game runs it, the host's lines below
come from her game. Look in the guest's `coop-link.log` first:

- No arena walls on her side: there is no `fight bstart hguid=<n>` line. Her game calls the boss start only for a copy
  it draws: check `pilot=` in `coop status` and the `fight paired` and `fight frozen` lines for that boss. The host
  logs `fight bstart sent <key> hguid=<n>` when its boss enters battle mode.
- Her copy stays in battle mode after the host's fight: her game logs `fight battle off <key> hguid=<n>` when it takes
  the copy out of battle mode, 10 s after the host's last bstart, or at once when the pair ends. A gap of over 2 s with
  no line from the host (a paused host game) is not counted in those 10 s. Without that line her copy is still paired
  and drawn, and the host's game still sends a bstart each second: the host's boss is still in battle mode. Leaving
  battle mode does not take arena walls down; the game's own events for that boss do.
- Her copy's HP stops at a phase threshold while the host's boss fights on: look for `fight phase hguid=<n>` lines.
  `fight phase hguid=<n> the game refused a row` means the game refused a phase effect on her frozen copy. Her game
  tries again at the host's next line (every second in battle mode) and logs the refusal once until a line goes
  through. `fight bad
  line hguid=<n> not its row` or `not a boss` means the two games do not run the same build of the mod. The host logs
  `fight phase sent <key> hguid=<n>` at each phase change.
- `fight finish guard <key> hguid=<n>` is expected once a copy reaches its finishing stance in a game whose finisher
  does not count: on her side with `boss_finish=host`, on either side with `first` once the host named the other
  member's press. That game takes the finisher's state (`Passive_FinishReady`) off and keeps the copy at 1 HP. The
  host logs `fight finisher <key> hguid=<n> ours` or `hers` for the press that won, `fight finish refused <key>
  hguid=<n> another member won` for its own press that came second and `fight exec refused <key> hguid=<n> the host
  finishes` for hers with `boss_finish=host`. On the host, `fight finish-held <key> hguid=<n>` means a killing hit of
  hers came while the host's boss waited for a finisher that was not hers; the `finish-held` count of the host's
  `fight stats:` lines shows how often. `fight finish guard ended <key>
  Immortal off` means the pair ended before the host's finisher (the link dropped, the host's world changed, `coop
  fight off`): her copy is at 1 HP with no Immortal, and her own hit ends it in her game. With `the game refused its
  dispel` in place of `Immortal off`, her copy keeps its Immortal at 1 HP: load a checkpoint to fight that boss again.
- No QTE for anybody, or both players press: the host logs `fight qte owner <key> hguid=<n> ours` or `hers` (with `after
  a miss` for a later try) when it names the QTE's owner, `fight qte none <key> hguid=<n> nobody up` when nobody
  stands and `fight qte off ...` while story together does not run in both games. The `qte=` word of the `fight=`
  line shows the last owner and its try.
- A boss stays with the host whoever hits it: look for `fight boss pilot off`. The guest's game refused to take a boss
  once, so every boss stays with the host until the game restarts.
- A downed player does not watch the fight: the `[StellarCoop][SP]` lines of her `UE4SS.log` and the `spectate` lines
  of her `coop-link.log` say why. `spectate filter refused: ...` means another mod holds the death screen's press slot:
  spectate then runs without its filter, so the death screen's buttons are not held back while she watches.
  `spectate off: <reason>, the death screen back` names why it stopped: `nobody`, `ended`, `link`, `off` or `revive`
  (the respawn did not come). After `spectate fault ...` it stays off until the game restarts.
- A summoned enemy missing on her side: the host logs `fight summon keyed <key>` and `fight summon sent <key>
  hguid=<owner>`, and she logs `fight summon made <key>` or `fight summon refused <key> <why>`. The host sends the line
  again every second while it follows the summon, and she logs a refusal only when its reason changes for that key,
  so a refusal for a passing reason can be followed by `fight summon made` for the same key. The reason is `off`
  (same place not running on her side), `owner` (she does not pair the boss that summoned it), `too far` (more than 1 km
  from her EVE), `full`, `not made` (a game object was not made yet), `stale`, `key`, `not a summon` or `charId` (the
  two games differ). `fight summon despawned <key> unpaired` means no pair held her summon 3 s after she made it: the
  host's summon never joined the shared list (16 places in use), or its pair ended. `fight summon despawned <key> its
  row's effects refused` means the game refused an effect of the summon's row on her copy, so her game removed it at
  once. After either line her game does not make that key again until the next on, off or world line of either game,
  and the host fights that summon alone.
- The `fight stats:` lines in `coop-fight.log` add `bosses: <n> summons made, <n> bstart, <n> phase rows (<n>
  refused), <n> finish guards` on the guest's side and `bosses: <n> summons sent` on the host's.

### A kill or an achievement did not count

A shared enemy dies in your game only if you took part in its fight
([fight/enemies.md: Shared enemies](../fight/enemies.md#shared-enemies-experimental)). When the other player kills one
that you never hit, that never targeted you and that stood more than 30 m from your EVE (`kill_credit=together`, the
default), your copy stays alive at full HP, and its kill, loot and achievements do not reach your save. Fight it
yourself to get them. As the guest, while same spawns run (within 100 m of each other in one zone), the host's next drop
line removes that copy a few seconds later instead, without a kill.

The guest's `coop-link.log` says `fight dead-unshared <key> hguid=<n> not taken part`, the host's says
`fight kill-unshared <key> hguid=<n> not taken part`, and the `fight stats:` lines in `coop-fight.log` count them as
`not taken part`.

With `kill_credit=fought` the 30 m do not count, and they never count while your EVE is down. A `kill_credit=all` line
from 0.4.0-beta.1 reads as `together`. A `fight last player <key> set by a mirrored crowd control` line means that a
knockdown the other player started made the game record your EVE as that enemy's last player. The mod then stops
counting that record for this enemy, so only your hit or the 30 m make its kill yours.

### Travel to the host does not start

A refusal that ends in `no read of the camps this save has activated (<why>)` means the mod had no read of your
activated camps at that moment (a load, the title); the `activated=` line of `coop status` shows the read. With
`(fault)`, a fault stopped that read until the game restarts, and `coop-link.log` has `camps read off: fault 0x... at
StellarCoop.dll+0x... reading 0x...; coop travel probe and coop mxiii leave refused until the game restarts`. Restart
the game; if the line comes back, send `coop-link.log` (see [Which logs to send](#which-logs-to-send)).

Following the host is for the guest, on a co-op save, with `follow_host` not `off`. Each refusal writes a
`[StellarCoop][TR] travel refused: <why>` line in `UE4SS.log`, and the native part's refusals are also in
`coop-link.log` as `travel refused <camp>: <why>`.

- `You cannot travel now. Try again in a moment.`: something of the moment held it back: your EVE down, a respawn or
  another travel under way, the game paused, in photo mode or in a menu (the co-op menu too), a Night Operation run, a
  cutscene, a boss fight or an enemy in battle near you, the host's game loading or busy, or less than 10 s since the
  last travel. The log line names which.
  On the host's map it also covers `the host is in a solo area`, `we are in a solo area`, an answer from the host's
  game that says it is busy (`no spot from the host: none <loading|busy|solo|boss>`), no answer in 10 s
  (`no answer from the host in 10 s`) and a host who left your map before his answer came
  (`refused at the call: the host left this map`). The native part's refusals of the warp to his place are in
  `coop-link.log` as `travel spot refused: <why>` (`solo` while your own zone is a solo area).
- `<host> is not on solid ground. Try again in a moment.`: the host's EVE had not walked on a floor in the last 10 s
  (`no spot from the host: none air`). Wait until he stands on the ground, then press F7 again.
- `No camp you have found is near <host>.`: the host's game found no travel camp on its map (`none nocamp`), none of
  the camps it sent could be used (`travel: <camp> is not activated in this save` for a camp you have not found), or
  the game refused each one (`travel: SB refused <camp>`).
- `The travel did not start. UE4SS.log says why.`: the host's game is on the title screen (`none title`), no answer
  came from the host's game in 10 s, the native part gave no result in 5 s or refused the call
  (`the native part refused: <why>`), or the warp never started 10 s after the game took the call (`refused:stuck`).
  After a warp that never started, the travel stays off on that map until you change map. A fault turns the travel off
  until the game restarts (`travel off: fault ...` in `coop-link.log`).
- No notice at all: `follow_host=off`, `follow_key=none` (use `coop travel host`), you are the host, your own save is
  loaded, or the host is within 150 m of you on your map. Press F7 and read the `travel refused:` line.
- A second F7 within 2.5 s is refused in the log only (`one request to the host each 2.5 s`).
- F7 within 5 m of the host is refused in the log only (`the host is within 5 m`). With his ghost hidden or not yet
  placed, the log says `the host's place on this map is unknown`.
- After a camp travel to the host's map you stay at the camp: `travel: no second hop: <why>` means a guard held for
  30 s after the arrival. Press F7 again.

The way back after a death (`<name> is alive. Press F7 to go back to them.`) writes `[StellarCoop][GR] return: ...`
lines. No notice shows with `follow_key=none` or `follow_host=off` (`return: no notice (follow_key=none)`), with
`revive=off`, during a boss fight, in a solo area on either side, with your friend down or on another map, or within
10 s of the last respawn the mod asked for. `return refused: <why>` names the guard that stopped the respawn call.
`return: no warp, <why>` means you got up where you fell with no warp: your friend left, went down or entered a solo
area, the respawn did not take, or you went down again before the warp.

### A revive is not offered

The revive is experimental and on by default. Each player's own `revive` setting decides for their own EVE, and your
friend's `<name> is down` notice shows whatever that setting says. The downed player's `UE4SS.log` has a
`[StellarCoop][GR] revive waits: <why>` line each time the reason changes:

- `revive=off`: turn on Options > Session > Friend can revive me before the fight.
- `friend not alive`, `friend on another map` or `friend far`: your friend's EVE must stand within 2 m of yours across,
  and 1 m up or down, for 3 s with no gap. A body that fell into a pit or below the map cannot be reached.
- `boss fight`: no revive during a boss fight on your side, nor in the 10 s after the host's last boss start.
- `no shared fight`: the revive needs shared enemies running, with both players on co-op saves.
- `a respawn or a warp is under way`: you pressed the death screen's respawn first.
- `no death screen`, `the game is not standalone`, `no warp read`, `no SB player controller` or
  `a coop no probe rule is set in this game run`: the game is not in a state the revive supports; respawn at a camp.
- `revive off for this run: <why>`: a Lua error turned the revive off until the next Lua load.

After a call, the `revive result` line gives the life state, HP and death screen before and after. If the death screen
stays up over a living EVE, the mod hides it.

During a co-op Night Operation run the run's own revive applies instead (see
[Down and revive](../online/modes/nightop.md#down-and-revive)). It needs the downed player's `revive=on` too, but none of the
friend's distance, the shared fight or the boss rule above. Its `[StellarCoop][NR]` lines say what happened:

- No `down (life 3): ...` line after a death, and the run failed at once: the dead player's `revive` setting is off,
  or the game's own life state was not read (`coop status` shows no `life=` line). The down needs both.
- On the partner's side, `revive of <name> stopped at <n> %`: the interact key was let go, the partner's EVE stepped
  more than 2 m across or 1 m up or down from the downed EVE's ghost, or the game was paused. Only F and the pad's right
  trigger count, not a rebound interact key.
- On the downed side, `revive not asked (friend): <why>` or `(self): <why>`: the reasons of the list above that the
  call itself checks, such as `revive=off`, `a respawn or a warp is under way` or `no death screen`. For her own
  revive, `your EVE lies <n> m across and <n> m up or down from where she last walked` means the body is more than
  2 m across or 1 m up or down from the last ground her EVE walked on, as after a fall into a pit; only her partner can
  revive her then.
- `revive (<who>) did not take: not up 5 s after the call`: the game's respawn did not bring EVE up. The `[GR]`
  `revive result` line before it gives the life state and the death screen. The down asks for no other call.
- `up with no revive asked` or `up after a revive that did not take`: the death screen's respawn was pressed. That ends
  the run as a death.

### Stuck at a doorway with the solid partner

With `collide=on`, your friend's ghost stops your EVE. It lets her through after 2 s of contact, until you are 50 cm
apart, so wait 2 s and walk on. If the ghost still blocks a door, a ladder or a ledge, or a dodge stops at it, turn
Options > Ghost > Solid partner off (`collide=off`): it applies at once. `coop status` shows `collide=on solid=<0|1>
changes=...`, and each contact writes a `Solid partner contact:` line in `UE4SS.log`; send both with a bug report. A
`Solid partner off on this ghost: <why>` line means the capsule could not be built or failed. That ghost then has no
collision until it is built again (a level change or a new outfit).

### Same spawns do not start, or enemies appear and vanish

Same spawns (`same_spawns`) is experimental, on by default and not tested in game yet. With it on in the host's game,
the guest's game creates the common enemies it lacks where the host's stand and removes those the host's game lacks,
through the game's own spawn function and despawn job. On her screen an enemy can therefore appear out of nowhere, or
vanish without dying and without rewards. Both happen only where the two players stand within 100 m of each other in
one zone, and only to enemies of rows the zone resets anyway (bosses, quest and event enemies and the enemies a save
records are never touched). To go back, turn off Options > Combat > Same spawns (experimental) in the host's menu, then
turn Shared enemies off and on again or restart the game: the setting counts from the next start of shared enemies.
[fight/enemies.md](../fight/enemies.md#same-spawns-experimental) has the details.

Read the `spawns=` part of the `fight=` line in `coop status` on both PCs:

- `spawns=off` on the host: its `same_spawns` is off, or the guest's shared enemies are not on (the line's `her=`
  says so). After turning the row on, turn Shared enemies off and on again.
- `spawns=off` on the guest: the host's `same_spawns` is off (only the host's value counts), or the host's game has
  not sent its zone yet. It sends it once its zone is known, again after each map load, and every 5 s.
- `spawns=on` but nothing changes: both players must be in the same zone, within 100 m of each other, and 3 s past
  either game's last zone entry or reset (a camp rest, a death). The guest may also hold the host's set already. If
  the other PC's line says `spawns=stopped`, its error stopped same spawns in both games.
- `spawns=stopped`: the same-place error stopped same spawns too, until the game restarts. `coop-link.log` has the
  `same-place enemies fault` line.
- `spawns_differ=` above 0 on the guest: her game refused, or removed again, enemies whose spawn rows or character
  differ from the host's, or that her `fight_chars` leaves out. Her `coop-link.log` names each one in `fight spawn
  refused <key> <why>`, `fight drop refused <key> <why>`, `fight spawn undone <key> <why>` or `fight spawn kept <key>
  <why>`. The same .pak mods and the same `fight_chars` on both PCs avoid it.
- `fight spawn refused <key> no spawn manager` on the guest: her game had not made its spawn manager or its job
  sender yet. The host asks for that enemy again after either game's next zone change or reset.

`coop fight spawn probe` checks the reads on one PC: each shared enemy in your zone gets a `fight spawns probe <key>`
line in `coop-link.log` saying whether same spawns would handle it. For a report, keep `coop-link.log` and
`coop-fight.log` from both PCs.

An enemy that the host's game lacks still appears for a moment on the guest's screen after her death or a camp rest,
then vanishes: that is same spawns with the spawn filter off. With `spawn_filter=on` (the default) on her PC it stays
away after the first entry into the zone, unless her reset is also a world change (`fight world <why>` in her
`coop-link.log`; see [Turn the spawn filter off](#turn-the-spawn-filter-off) and
[fight/enemies.md: Spawn filter](../fight/enemies.md#spawn-filter-experimental)).

### Turn the spawn filter off

The spawn filter (`spawn_filter`, the guest's own setting, on by default) has not been tested in game. If the game
misbehaves with it on (a crash, a door or a zone event that waits for enemies that never come), close the game, set
`spawn_filter=off` in the guest's `coop-settings.txt` and start again. `coop off` puts the game's pointer back at once,
until the game restarts. Send the guest's `coop-link.log` and `coop-fight.log`: the `spawn filter` lines name each
enemy it refused (`spawn filter refused <spawnId>:<index>`), and the `fight stats:` lines count `filter <n> seen, <n>
refused`. `spawn filter refused: ...` with no key means the filter never started (another mod holds the same pointer,
or the page would not become writable), and every spawn went on as with it off. See
[fight/enemies.md: Spawn filter](../fight/enemies.md#spawn-filter-experimental).

## Reading the 60 s lines

Every 60 s, `coop-link.log` gets these lines for diagnosing performance problems:

- `native tick, last 60 s: ...`: the per-frame tick's count, mean and maximum cost, the largest gap between ticks and
  the gaps over 100 ms.
- `stream, last 60 s: ...`, while poses flow: poses sent (count, rate, the highest cap among the members as
  `link cap <n>`, size, KB/s; keyframes, deltas and their mean size, and frames held back by the 192 KiB/s byte budget),
  tables in and refused, poses received, foreign (of no table, or of one the ghost is not built on yet), malformed and
  rejected, keyless (deltas whose keyframe was lost), losses, stalls, the one-way delay, and poses drawn and written.
  Between two PCs the one-way delay includes the offset between their clocks, so the value means nothing there. At 60
  poses a second a lost keyframe leaves a gap of about 270 ms, so it also counts as one stall, and the deltas dropped
  with it count as both keyless and missing. In a match lobby the deltas a sender skips for your cap also count as
  missing, because the playback counts each gap in the sequence numbers as lost.
- `<name>, last 60 s: ...`, per linked friend: channel 1 traffic, drops, failed sends with the last Steam result (25
  means its send buffer is full), ping RTT and loss, and Steam's view of the session.
- `link, last 60 s: <p> passes, <f> full receive batches (16 messages)`: the link's passes (one every 5 ms while
  poses stream, every 50 ms otherwise) and the reads that returned 16 messages on one channel, so more may have waited
  for the next pass. The first of these lines in a run counts only its first pass.
- `score lines, last 60 s: <in> in, <out> out, <dropped> dropped`, in a minute that carried
  [score attack](../online/modes/scoreattack.md) lines: the lines received, sent and dropped (see
  [The score line](../online/steam-link-internals.md#the-score-line)).
- `mode lines, last 60 s: <in> in, <out> out, <dropped> dropped`, in a minute that carried
  [fishing tournament](../online/modes/fishing.md) or [photo hunt](../online/modes/photohunt.md) lines: the lines
  received, sent and dropped (see
  [The mode line](../online/steam-link-internals.md#the-mode-line)).
- `dr lines, last 60 s: <in> in, <out> out, <dropped> dropped`, in a minute that carried the lines of
  [Doro races in matches](../online/modes/race.md#races-in-a-match): the same counts (see
  [The dr line](../online/steam-link-internals.md#the-dr-line)).
- `effects, last 60 s: ...`, with any effect activity: effects started, over 6, unlisted reads and boxes written.
- `sounds, last 60 s: ...`, with any sound of yours recorded: why each one counted as yours (mark, owner, attach, or a
  start on another thread, which is not sent), sounds put in a pose, those dropped after 100 ms without a slot, paths
  refused (outside the game's folders), parameters left out, sounds past the 4096 keys and starts lost to a full ring.
- `vitals read, last 60 s: ...`, during a session: the reads of your vitals for your friend's partner card and the
  slowest one in µs. Over 1000 µs, the next read waits 500 ms instead of 100.

Between the 60 s lines, `pose rate cap <n> a second for <name>: ...` marks each change of the cap on the poses you send.
In a match lobby each member's cap starts at 30, with no line. A step down to 30 or 20 means Steam's queue to that
friend reached 100 ms, or 64 KiB waited to be sent, two seconds in a row: the ghost they see moves with fewer poses a
second, still interpolated, instead of falling behind. The line gives the queue time, the pending bytes, Steam's send
rate and the session quality at that moment. The cap goes up one step after 10 s calm
(`10 s calm (queue under 20 ms, pending under 16 KiB)`); if it keeps coming back down, the wait before the next step up
grows to 80 s. A cap that stays at 20 points at the connection itself: compare the send rate and quality in the
`<name>, last 60 s:` line on both PCs.

`UE4SS.log` gets one more line each minute while the on-screen UI is up: `[StellarCoop] Lua frame time, last 60 s:
ghost <x> ms, doro <d> ms, race <r> ms, UI <y> ms a frame (<n> frames); longest frame <f> ms (<a> over 16 ms, <b> over
50 ms): mxiii <m> ms, lion <l> ms, scene <s> ms; longest 250 ms pass <p> ms (<c> over 16 ms, <e> over 50 ms): booth
<o> ms, kit.slow <k> ms`. Its first part is the mean game-thread cost per frame of placing the ghost, of the Doro look,
of a Doro race or a bike ride and of the co-op menu, chat and partner HUD. To see what the marker and the arrow cost, compare a minute
with them on against a minute with Options > Partner > HP marker and Off-screen arrow set to Off. A mean hides a single
frozen frame, so the rest of the line gives the longest Lua work in one frame and in one pass of the 250 ms loop, how
many frames and passes took over 16 ms (one frame at 60 fps) or over 50 ms, and the longest call of Matrix XIII, the
Lion, `coop scene`, the camp booth scan and the UI's 250 ms pass. The game's clock counts whole milliseconds, so each of
these values is accurate to about 1 ms.

Between the 60 s lines, each gap over 100 ms between two native ticks has a line of its own in `coop-link.log`:
`gap 20:00:44.512Z: 312 ms since the last native tick (frame 4818231), that tick took 0.05 ms; vkd3d cache +496 bytes`.
The time is when the gap ended, in UTC, and `that tick took` is the mod's per-frame native work in the frame before it.
Under Proton the last field says how much `vkd3d-proton.cache.write`, next to `SB-Win64-Shipping.exe`, grew since the
previous gap line. vkd3d-proton adds the GPU pipelines it builds to that file, so growth next to a gap hints at a
pipeline built on first use. On Windows the file does not exist and the field is left out. `UE4SS.log` gets the Lua
side of the same gap: `[StellarCoop] gap 312 ms before this frame; 250 ms pass in it: 88 ms (kit.slow 36, booth 0)`,
or `no pass in it` when the mod's 250 ms pass did not run in the gap. Both logs keep at most 200 gap lines a minute and
then write `gap lines: 200 ...` once, because every frame of a long load is a gap; the `native tick` line still counts
them all.

A write the engine refuses is logged once per new ghost or capture generation as `write refused: ...`.

## Which logs to send

If something goes wrong, close the game and send these files before you start the game again, because each launch
overwrites `UE4SS.log` and moves `coop-link.log` to `coop-link.old.log`. Some of the files may not exist; send the ones
that do.

- `Mods/StellarCoop/coop-report.txt`
- `Mods/StellarCoop/coop-link.log`
- `Mods/StellarCoop/coop-link.old.log`
- `ue4ss/UE4SS.log`
- `Mods/StellarCoop/nightop-probe.txt`, only if you ran the Night Operation probe (`coop no`)
- `Mods/StellarCoop/coop-quests.log`, only if shared quests were on

The mod masks SteamIDs and join codes in what it writes to these files. A SteamID shows as `***` and its last 4 digits
(`***5678`), which still tell the players in one report apart. A join code shows its first 3 characters (`ABC-****`),
as does a lobby ID, whose digits would give its code away. The files still contain your Steam name, the other players'
Steam names and folder paths, which may include your Windows user name. They contain no passwords. Logs from an older
version of the mod keep the full IDs, as does the `coop-link.old.log` of the first run after an update. You can read
the files before you send them.

When you test with a friend, the player who leads the test types `coop mark <step>` in the console before each step,
for example `coop mark 3 lift`. Each mark puts a numbered line with that text in both players' `coop-link.log` and
`UE4SS.log` (see [usage.md](../usage.md#coop-mark)), so the four logs line up step by step. The text of each mark stays
in the logs you send.

This list is the same as in [INSTALL.md](../../INSTALL.md#which-logs-to-send).
