# Troubleshooting

StellarCoop is an experimental pre-release, played in only a few sessions between two PCs so far.

**Close the game before you copy, change or delete any mod file.**

## Where to look

- `ue4ss/UE4SS.log` (in `SB/Binaries/Win64/`): every line from the mod starts with `[StellarCoop]`. Answers to
  commands and keys read `[StellarCoop] OK: ...` or `[StellarCoop] STOP: ...`; status changes read
  `[StellarCoop] link: ...`.
- `Mods/StellarCoop/coop-link.log`: the native part's numbered events, in UTC. The previous run's log is
  `coop-link.old.log`.
- `coop status` (console) or F6: the current state. See [usage.md](usage.md#status-lines).
- `coop report` (console): writes `coop-report.txt` with versions, the save folder, where `xinput1_3.dll`,
  `dinput8.dll`, `dwmapi.dll` (UE4SS's loader) and `steam_api64.dll` were loaded from (other mods' DLLs can change
  results), the status, a summary of save folder changes and the last 100 events.

## Common problems

### F6 does nothing, or no `[StellarCoop]` line at all

- No `[StellarCoop]` line in `UE4SS.log`: UE4SS did not start the mod. Check that the folder is
  `Mods/StellarCoop/Scripts/main.lua`, with `enabled.txt` and `StellarCoop.dll` next to `Scripts/` (Windows "Extract
  All" may add one folder level). See [INSTALL.md](../INSTALL.md#install).
- `Native part not loaded`: `StellarCoop.dll` is missing or was quarantined. The keys and the Steam link need it. See
  [INSTALL.md: Windows Defender and SmartScreen](../INSTALL.md#windows-defender-and-smartscreen).
- `Native tick unavailable`: the DLL loaded but its per-frame entry did not. Without it no pose is read or drawn, so
  no ghost shows, and the loopback, record and replay refuse to start.
- A `settings:` line: a value in `coop-settings.txt` was refused and keeps its default. `F10` is never allowed, and
  two actions on one key put all four keys back to their defaults: `F5` (menu), `none` (host), `F6` (status) and `F8`
  (leave). See [usage.md](usage.md#coop-settingstxt).
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

- `Version mismatch: ...`: you run different StellarCoop protocols or game builds. Both players update together:
  see [INSTALL.md: Update](../INSTALL.md#update).
- `Invite held: joining once your save has loaded.`: they join once their save has loaded. This is normal.
- `Could not join: that game is full.`: a session holds 2 players. `Left: the lobby has more than 2 players.` means the
  lobby was not made by StellarCoop (it holds more players than a StellarCoop lobby can), so the mod left it.
- `coop join` without an id logs `no friend is in a Stellar Blade lobby`: ask your friend to host, then accept their
  invite, or use `coop join <lobby id>`.
- `You are in <host>'s game: leave it first.`: a guest cannot host. Press F8 first.
- The host set Options > Session > Who can join to Invited only (`who_can_join=private`): `coop join` and the Steam
  friends list do not find that session. The host invites the friend with the menu's Invite a friend row instead.
- The host set Who can join to With a code (`who_can_join=code`): that session does not show in the friends list
  either. Join with the host's code, or the host invites you. See "Join codes and the host's question" below.

### Join codes and the host's question

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
- `Joined <host>'s game. Waiting to be let in.`: you are not on the host's Steam friends list, so the host has to
  accept you. Your partner's ghost and card do not show until then. The host has 60 s to answer.
- `<host> refused the link: <reason>`, with `you were not let in`, `no answer within 60 s`, `you were removed from
  this session` or `you cannot join this session again`: the host refused or removed you, and your game left. That
  session stays closed to you. A new session the host starts has a new code, and the host is asked again.

For the host:

- The question does not show: it opens in a world only, while the game is not paused and shows no menu or mouse
  cursor, and while the chat box is closed. After `coop ui off` it never shows. From the console, `coop status` gives
  the waiting player on its `pending=<SteamID> <name>` line; then type `coop allow <SteamID>` or
  `coop deny <SteamID>`. With no answer, the player is refused after 60 s.
- A refused player is still in the lobby. Steam cannot take a player out of a lobby: a StellarCoop game leaves when
  it is refused, but a game that does not keeps the lobby's second place. It gets the refusal again every 10 s and
  never links. Host again: the new session has a new code.
- Players you do not know keep asking: host again for a new code, and give it only to the player you expect.
- `No join code to copy.`: you do not host, or you host with Friends or Invited only. Set Who can join to With a code,
  then host again.
- `Could not copy the join code <code>.`: the Windows clipboard was busy. Select Copy my code again, or read the code
  from that row. On Linux, if the code does not paste outside the game, read it from the row too: no test has yet
  checked that Proton passes it on to the desktop's clipboard.
- `Hosting without a join code (unexpected lobby id): ...`: Steam gave the lobby an id that a code cannot hold. The
  invite dialog opens instead; invite the player from it.

### I do not see my friend's ghost

- `ghost=off` in `coop status`: no session has started since the mod loaded, or the ghost was turned off with
  `coop puppet`. It turns on again with the next session, or with `coop puppet`.
- `ghost=hidden map`, or the notice `<name> is in <map>, you are in <map>.`: you are on different maps. The ghost
  shows once you are on the same map.
- `ghost=waiting`: no table has arrived yet, or the ghost is being built, or your EVE has been in the world for less
  than 2 s. A table that needs a new ghost is taken at most once every 2 s; your friend's next resend (every 5 s)
  brings it.
- The ghost appears and disappears: it hides after a second without a pose, so poses are arriving with gaps. Look
  at the `<name>, last 60 s:` line in `coop-link.log` (RTT, drops, Steam's session quality).
- `engine=off reason=...` in `coop status`: the native pose path is off. On a game build other than 24463856 it never
  reads game memory, so no ghost can be drawn. After a fault, `coop-link.log` has an `engine off: fault ...` line.
- `Ghost not built: ...`: the build failed for that table. It is tried again 2 s later, up to 3 tries in all; after
  the third failure the notice `Ghost failed 3 times: the reason is in UE4SS.log.` shows. Then a new table, a level
  change or `coop basesuit` tries again.
- `coop off` was used: everything stays off until the game restarts.

### The ghost wears the base suit, or a part is missing

A part falls back to the base suit when your PC cannot load its mesh (a DLC you do not own), when its path is outside
the game's character folders, or when its bones differ. A part with no fallback is left out. The `Ghost ... built` line
in `UE4SS.log` counts both and names each part drawn on the base suit. `coop basesuit` may also be on: run it again to
go back.

### A look misbehaves

The cloth, dyes and effects looks have not been tested in game yet. If the game crashes or the ghost looks wrong with
one on, turn it off in `coop-settings.txt` (or with `coop look <look> off`). An `effects off: fault ...` line means a
fault turned effects off until the game restarts; the ghost stays, without effects.

### The game ignores its keys after the co-op menu or the chat

Open the console (F10 or `~`) and type `coop ui reset`: the menu, the chat box and the code box close, an open
host's question is answered with Deny, and the game gets its keys back. Without the console, press Ctrl+R or restart the game. `UI off until the mod reloads: <why>` in `UE4SS.log`
means that the on-screen UI hit an engine error and turned itself off; notices then show on the line above EVE.
`coop ui off` turns the UI off the same way by hand.

### Screen notices stopped

`Screen notices off: <why>; notices stay in UE4SS.log.`: the engine refused the line above EVE. That line stays off
until the next Lua load (game start or Ctrl+R); the notices still go to `UE4SS.log`, and to the feed at the top left
while the on-screen UI is up.

### `coop no` or `coop recruiter` says `STOP`

- `runs only on a co-op save`: at the title, choose Play co-op (or Convert and play co-op), then load your save. See
  [saves.md](saves.md#co-op-saves).
- Most other `STOP:` lines from the previews give the reason, and many say that nothing was changed. If the probe logs
  `STOP: a new character is ... m from EVE: kill the game now`, kill the game at once. See
  [night-operation.md](night-operation.md).

### The co-op saves question does not show

It shows only with `auto_coop_save=ask`, on the title screen, once the on-screen UI has loaded. `coop status` gives the
reason:

- `saves=coop` on the slot line: the game already uses the co-op copies, and `CO-OP SAVES` shows at the top right of
  the title screen. They stay on until the game restarts.
- `saves=off` or `saves=?`: the mod cannot use the save file name on this game build, or a check failed. The
  `save name: saves=...` line of `coop-link.log` says why. The mod makes no copies, and the game uses your own saves.
- `steam=waiting`: Steam is not ready yet, and the mod needs your Steam ID to find your save folder.
- `convert=busy ...`: a copy pass runs. The question waits for its end.
- `UE4SS.log` has `[StellarCoop] co-op saves: the question cannot show (the co-op UI is off)`: the on-screen UI
  stopped (see the `[StellarCoop][UI]` lines). `auto_coop_save=always` still switches to the copies.

### Enemies are not shared

Shared enemies are on by default. Both players need Options > Combat > Shared enemies (experimental) set to On in the
co-op menu. The `fight=` line of `coop status` says what is missing (see
[usage.md: Shared enemies](usage.md#shared-enemies-experimental)):

- `fight=off` with no `why=`, and `shared enemies: off (experimental)` in `UE4SS.log` at load: shared enemies are off
  in your game. A `coop-settings.txt` from version 0.2 says `shared_enemies=off`.
- `fight=waiting mode=on ... why=not on a co-op save`: you play your own save. Quit to the title screen and choose
  Convert and play co-op (Play co-op once you have co-op copies), then load the same slot number.
- `her=own-save`, `her=off` or `her=stopped`: your friend plays their own save, has shared enemies off, or theirs
  stopped for the run (their `coop-link.log` says why). `her=?`: nothing came from their game yet. A friend on an
  older build of the mod sends nothing until their shared enemies run.
- `fight=on mode=on role=host enemies=0` or `role=guest pairs=0` while you both fight the same enemies: the two games
  spawned them differently (another map, a different save), or `fight_chars=auto` leaves them out, or a `fight_chars`
  list does not name them. `auto` leaves out bosses, Alpha Naytibas, the Gorgon, two turrets with 999,999 HP and any
  enemy above 500,000 maximum HP; `coop fight probe` marks the last three with `left_out=`. On the guest's side,
  `coop fight status` lists the host's enemies it could not pair and why: `charId` (another enemy at that spawn
  point), `maxhp` (another difficulty or New Game+ in one of the two games) or `duplicate`.
- `paks=differ` in `coop status`: the two games load different `.pak` mods. Each `coop-link.log` names its own in the
  `paks` line at the top; compare the two lists.
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

### Same place does not start, or stops

Same place is experimental and off by default, and only the host's setting counts. `coop fight pilot status` prints
the `pilot=` line of `coop status` (see [usage.md: Same place](usage.md#same-place-experimental)):

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

### Same spawns do not start, or enemies appear and vanish

Same spawns (`same_spawns`) is experimental, off by default and not tested in game yet. With it on in the host's game,
the guest's game creates the common enemies it lacks where the host's stand and removes those the host's game lacks,
through the game's own spawn function and despawn job. On her screen an enemy can therefore appear out of nowhere, or
vanish without dying and without rewards. Both happen only where the two players stand within 100 m of each other in
one zone, and only to enemies of rows the zone resets anyway (bosses, quest and event enemies and the enemies a save
records are never touched). To go back, turn off Options > Combat > Same spawns (experimental) in the host's menu, then
turn Shared enemies off and on again or restart the game: the setting counts from the next start of shared enemies.
[usage.md](usage.md#same-spawns-experimental) has the details.

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

### `Co-op saves off for this load: <why>`

The copies were not switched on, and the game uses your own saves. The reason comes from `coop-link.log`:

- `Continue or Load Game was chosen at the title (load mode 2)`: Continue or Load Game was pressed before the copies
  were ready, so the game loads your own save.
- `slot N's save ...` or `slot N's copy ...`: that save could not be copied (it fails the game's own check, it changed
  while it was read, or the disk is full). The other copies are made, but the switch needs a copy of every save.
- `the backup folder could not be made` or `the backup of <file> could not be written`: the disk is full, or
  `%LOCALAPPDATA%\SB\Saved\StellarCoopBackups` cannot be written.

### A save looks wrong

Do not start the game again. Turn Steam Cloud off for Stellar Blade first, then restore your backup. See
[saves.md](saves.md#steam-cloud) and [INSTALL.md: Recovery](../INSTALL.md#recovery).

## Reading the 60 s lines

Every 60 s, `coop-link.log` gets these lines for diagnosing performance problems:

- `native tick, last 60 s: ...`: the per-frame tick's count, mean and maximum cost, the largest gap between ticks and
  the gaps over 100 ms.
- `stream, last 60 s: ...`, while poses flow: poses sent (count, rate, size, KB/s; keyframes, deltas and their mean
  size, and frames held back by the 192 KiB/s byte budget), tables in and refused, poses received, foreign (of no
  table, or of one the ghost is not built on yet), malformed and rejected, keyless (deltas whose keyframe was lost),
  losses, stalls, the one-way delay, and poses drawn and written. Between two PCs the one-way delay includes the
  offset between their clocks, so the value means nothing there. At 60 poses a second a lost keyframe leaves a gap of
  about 270 ms, so it also counts as one stall, and the deltas dropped with it count as both keyless and missing.
- `<name>, last 60 s: ...`, per linked friend: channel 1 traffic, drops, failed sends with the last Steam result (25
  means its send buffer is full), ping RTT and loss, and Steam's view of the session.
- `effects, last 60 s: ...`, with any effect activity: effects started, over 4, unlisted reads and boxes written.
- `vitals read, last 60 s: ...`, during a session: the reads of your vitals for your friend's partner card and the
  slowest one in µs. Over 1000 µs, the next read waits 500 ms instead of 100.

`UE4SS.log` gets one more line each minute while the on-screen UI is up: `[StellarCoop] Lua frame time, last 60 s:
ghost <x> ms, UI <y> ms a frame (<n> frames)`. It gives the game-thread cost of placing the ghost and of the co-op
menu, chat and partner HUD. To see what the marker and the arrow cost, compare a minute with them on against a minute
with Options > Partner > HP marker and Off-screen arrow set to Off.

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

They contain your Steam ID and Steam name, the other player's Steam ID and Steam name, lobby IDs and folder paths,
which may include your Windows user name. They contain no passwords. You can read them before you send them.

This list is the same as in [INSTALL.md](../INSTALL.md#which-logs-to-send).
