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

Open the console (F10 or `~`) and type `coop ui reset`: the menu and the chat box close and the game gets its keys
back. Without the console, press Ctrl+R or restart the game. `UI off until the mod reloads: <why>` in `UE4SS.log`
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
  slowest one in µs. Over 1000 µs, the next read waits 500 ms instead of 250.

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
