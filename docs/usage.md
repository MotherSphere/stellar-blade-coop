# Using StellarCoop

This page lists everything you can do with StellarCoop in game: the keys, the co-op menu, the session chat, your
friend's card, marker and arrow, every `coop` console command, the settings file, the ghost's looks, the notices and status lines, and the files the mod
writes. To install the mod first, see
[INSTALL.md](../INSTALL.md). For what happens behind each feature, see [how-it-works.md](how-it-works.md).

Close the game before you change any file in the mod folder.

## Keys

The keys work with or without the console. They need the native part (`StellarCoop.dll`).

| Key (default) | Action | Console equivalent |
| --- | --- | --- |
| F5 | Open or close the [co-op menu](#co-op-menu); its first row hosts a session | (none) |
| F6 | Show the status: one line on screen (see [Notices](#notices)) and in `UE4SS.log` | (a short form of `coop status`) |
| F8 | Leave the session | `coop leave` |
| Enter | Open the [session chat](#session-chat) during a session, then send a line; Esc closes it | (none) |
| none | Host a session at once, or open the Steam invite dialog again while you host (`host_key`) | `coop host` |

You can change them in the menu's Options page or in [coop-settings.txt](#coop-settingstxt). A key only hands its
action to the game thread, where the console's checks apply (`coop off` included). The log says `key F5: menu`, then
an `OK:` or `STOP:` line when there is something to say.

Before this menu, F5 hosted. A settings file written by an older version has no `menu_key` line: the menu then opens on
that file's `host_key` (F5, or Shift+F5 if you set that), and no key hosts directly. Set both `menu_key` and
`host_key` to keep a direct host key.

## Co-op menu

F5 opens the co-op menu on the left of the screen, in a world only (not on the title screen, not while the game is
paused or shows the mouse cursor for one of its own screens, and not in your own photo mode). While it is open the game
ignores its own keys, so EVE stands still:

| Key | In the menu |
| --- | --- |
| Up arrow, W or Z | Up |
| Down arrow or S | Down |
| Left and right arrows, A or Q, D | Change the value of a setting |
| Enter or Space | Select |
| Esc | Back, then close |
| F5 | Close |

The main page follows your session:

- **Host a session** (not in a session): as `coop host`. The menu closes first, because the Steam invite dialog opens.
- **Join a friend** (not in a session): as `coop join`.
- **Leave the session** (in a session): select it twice within 3 s.
- **Invite a friend (Steam)** (while you host): as `coop invite`. The menu closes first.
- **Chat** (in a session, with chat on): closes the menu and opens the [session chat](#session-chat).
- **Options**: the settings below.
- **Write a bug report**: as `coop report`.
- **Close**.

The status line under the rows is the F6 line, with your friend's ping once linked. Under it, the newest notice of the
last 8 s shows while the menu covers the [feed](#session-chat) (for example the result of Join a friend), unless a row
just said something there. The menu closes by itself when the game pauses or shows the mouse cursor for one of its own
screens.

**Options.** Each row is a setting of [coop-settings.txt](#coop-settingstxt): the keys, the synced photo mode, the name
tag and the [partner HUD](#partner-hud), the ghost's looks and send rate, who can join a session you host, the shared
enemies, the menu's own size, sounds and language, and the chat. Left and right change a value; Enter changes it too. Each change rewrites only that setting's line in `coop-settings.txt`
(comments and other lines stay), and the first change after the mod loads keeps the file as it was as
`coop-settings.old.txt`. A change applies at once, except the name tag and the shared enemies: those say `It takes
effect when the mod reloads`.

**Keys.** Select a key row, then press the new key: `F1` to `F12` except `F10`, alone or with Shift, Ctrl or Alt. A key
another action already holds is refused and named; Esc stops waiting. The new key works at once.

The menu follows the game's language: French or English (`ui_language=english` keeps English). The status line stays
in English.

If the menu or the chat box ever leaves the game deaf to its own keys, open the console (F10 or `~`) and type
`coop ui reset`: the menu and the box close and the game gets its keys back. `coop ui off` removes the co-op menu,
chat box and partner HUD until the mod reloads (game start or Ctrl+R); the notices then go back to the line above
your EVE and your friend's name back to the name tag above their ghost.

## Session chat

During a session (or `coop loopback`), Enter opens a text box at the top left of the screen, under the feed, in a world
only (not while the game is paused or shows the mouse cursor for one of its own screens). While it is open the game
ignores its own keys, so EVE stands still, and the mod's keys (F5, F6, F8) do nothing. If the game pauses or shows the
mouse cursor while the box is open (EVE dies, or your friend's photo mode pauses your game), the box closes by itself
and what you typed goes. Alt+Enter never opens it.

| Key | In the chat |
| --- | --- |
| Enter | Send the line; on an empty line, close the box |
| Esc | Close the box; what you typed goes |

- Type in any keyboard layout, with accents: the game's own text box turns your keys into characters. A line is at
  most 200 bytes (200 letters, fewer with accents or emoji); the rest is cut.
- Your lines show at once in white, your friend's in teal, notices in grey, each with the time. A line that could not
  be sent turns red and ends with `(not sent)`. At most two lines leave a second; when four are waiting, the line you
  typed stays in the box: press Enter again.
- The feed shows lines for 8 s (the last 6 rows) while the box is closed, and the last 12 rows while it is open. It
  hides while the co-op menu is open; the menu shows the newest notice meanwhile.
- Outside a session, Enter says `Chat needs a session.` (at most once every 10 s).
- `chat=off` in [coop-settings.txt](#coop-settingstxt), or Options > Chat, hides your friend's lines and sends none;
  Enter then says `Chat is off (Options > Chat).`
- The history is kept in memory only, 50 lines at most. It is cleared when the session ends, at `coop off` and when
  the mod reloads (game start or Ctrl+R). Chat text never goes into a log, a report, the console or a lasting file
  (see [Files in the mod folder](#files-in-the-mod-folder)); a crash dump holds the game's memory, so it may hold
  lines of the session.
- Key binds of other mods still run while you type.
- The mod cannot tell when the game's console has the keyboard. During a session, Enter to run a console command other
  than `coop ...` also opens the box a moment later; press Esc to close it.
- If the on-screen UI stopped (an engine error, said in `UE4SS.log`), the box does not open
  (`The chat box is off (the UI stopped, see UE4SS.log).`) and your friend's lines show on the line above your EVE.

## Partner HUD

During a session (or `coop loopback`, where your own values stand in for your friend's), three things show your
friend, in teal:

- **The card**, at the top left above the chat's feed: their Steam name, their HP (three rows of dots), shield blocks,
  Beta and Burst cubes, filled by the same rules as your own gauges at the bottom left, and one line beside the name:
  - their ping and map, for example `118 ms · e04` (`card_details`);
  - `DOWN` in red while they are down;
  - `elsewhere · b07` while they are on another map;
  - `connection lost`, or `—` when no HP has come from them for 3 s; both grey the card out, their last values kept.
- **The marker**, over their ghost's head: their name, a row of HP dots, a shield line, and the distance once they are
  more than 15 m away. While it shows their name, the ghost's own name tag hides; with the marker off, or the
  on-screen UI stopped, the name tag is back (`name_tag`).
- **The arrow**: when they are out of view or behind you, an arrow at the edge of the screen points to them, with the
  distance and three HP pips. While nothing comes from them (connection lost, or no HP for 3 s) the marker and the
  arrow turn grey and stay where they were last seen, until they are back or one of you changes map. On another map
  there is no arrow: the card says where they are.

The gauges move over 150 ms and run up to about half a second behind your friend's own screen. The game's alert sound
plays when your friend goes down and when the connection is lost (unless `ui_sounds=off`). Options > Partner turns each
part on or off at once: `partner_bar` (the marker), `partner_arrow`, `partner_card` and `card_details`. All three hide
while the game is paused or shows one of its own screens (a shop, a dialogue choice). Your own photo mode hides them
all, like the rest of the mod's screen.

## Playing with a friend

1. The host presses F5 and selects **Host a session**. This creates a Steam lobby for 2 players and opens the Steam
   invite dialog. Pick your friend there. By default the lobby is friends-only: your Steam friends with the mod can
   also join from their friends list or with `coop join`. With Options > Session > Who can join set to **Invited only**
   (`who_can_join=private`), only the friends you invite can join. The setting counts for the next session you host.
2. Your friend accepts the invite in Steam. If their game is closed, Steam starts it. They join once a save is loaded
   (EVE in a world, not on the title screen). Until then their game holds the invite (`Invite held: joining once your
   save has loaded.`). A newer invite replaces a held one, and host, join or leave drops it.
3. The ghost turns on by itself in both games when the session starts. Once both games have accepted each other's
   handshake, each of you sees the other's EVE where she stands, in her outfit, with their Steam name above her.

More about sessions:

- The host leads. When the host leaves, the guest leaves too (`Session ended: <host> left.`).
- A guest cannot host: the menu shows them Leave instead of Host, and `coop host` answers
  `You are in <host>'s game: leave it first.`, so one key press never ends their friend's session.
- If the guest loses the host's lobby another way (Steam drops them, a network cut), their game rejoins it by itself. It
  tries at 2, 12 and 42 s and gives up at 60 s (`Lost <host>'s game: rejoining.`, then `Rejoined <host>'s game.` or
  `Session ended: ...`). A lobby that is gone, or that someone else owns by then, ends the session. Leave, host, join
  or a new invite stops the rejoin. Meanwhile the host's lobby stays; the ghost goes with the link and comes back with
  it.
- Your friend's ghost only shows when you are both on the same map. When they are on another map, the screen says once
  `<name> is in <map>, you are in <map>.`, by the maps' last segments (for example `b07`).
- If your friend goes silent, their ghost hides after a second without a pose and comes back with the next one.
- Both players need the same protocol (8) and game build. A mismatch is explained on screen instead of being silently
  ignored (see [Notices](#notices)).

The ghost is display only. Nothing is copied between your two games: no enemies, items, unlocks or progress.

## Synced photo mode

When one of you enters the game's photo mode (P), the other's game pauses about half a second later, until the
photographer leaves photo mode. The paused player can open the pause menu and enter photo mode from there, so both of
you can pose for one shot; with both in photo mode, each game resumes only when both have left. Nothing is saved: the
pause is the game's own pause, held in memory only. It is not yet tried in game.

- Both PCs need `photo_sync=both` (the default) in [coop-settings.txt](#coop-settingstxt). With `notice` on either PC
  there is a notice and no pause; `off` shows nothing and pauses nothing.
- Selfie mode gives a notice only: the game itself does not pause in selfie mode.
- The pause ends when the photographer leaves photo mode, when the connection is lost (after 10 s; it comes back if
  they are still in photo mode when they return), when either of you leaves (F8), with `coop off`, and after
  `photo_freeze_max` seconds (10 min by default) until the photographer's next photo session.
- During your own photo or selfie mode, the notices above EVE wait until it ends, your friend's ghost stays in the shot
  unless `photo_ghost=off`, and its name tag leaves it unless `photo_name_tag=on`.
- It runs on game build 24463856 only. On another build, or after a fault (`photo pause off: ...` in the log), photo
  sync gives notices only.
- `coop freeze <seconds>` (1 to 3600) holds the same pause in your game alone, to test it without a friend;
  `coop freeze off` ends it. A load ends it too.

## Console commands

The console comes with ConsoleEnablerMod (see [INSTALL.md](../INSTALL.md#requirements)); it opens with F10 or `~`.
Every command starts with `coop`. Each answer goes to `UE4SS.log` as a `[StellarCoop] OK: ...` or
`[StellarCoop] STOP: ...` line. An unknown command prints the usage line.

| Command | What it does |
| --- | --- |
| `coop host` | Host a session (2 players, friends-only or invited only by `who_can_join`) and open the Steam invite dialog (the menu's first row) |
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
| `coop fight on\|off\|status` | Shared enemies (experimental, off by default, co-op save slot only) |
| `coop fight probe\|record\|replay`, `coop fight test hp\|sh\|st <change>`, `coop fight test kill` | Shared enemies' solo test tools (experimental, co-op save slot only) |
| `coop freeze <seconds>` / `coop freeze off` | Hold the [synced photo mode](#synced-photo-mode)'s pause alone, 1 to 3600 s |
| `coop ui reset` | Close the co-op menu and the chat box, and give the game its keys back at once |
| `coop ui off` | Remove the co-op menu, chat box and partner HUD until the mod reloads |
| `coop off` | Stop everything until the game restarts |

### Session commands

- `coop host` works like the menu's Host row. While you host, it opens the invite dialog again, as `coop invite` does. A guest's host
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
  reason (`protocol` for one made under another protocol, so any made before protocol 8). It then plays it in a loop as
  the remote side, each pose re-stamped as if sent now, until `coop replay off`, which removes the ghost. The
  generation, map and positions stay as recorded: the ghost wears the recorded outfit and walks where you walked, with
  no offset, and the map gate applies.
- During `coop loopback` with no friend linked, a chat line you send comes back as your friend's, and your own HP,
  shield and gauges stand in for theirs (`mate=` in `coop status`).
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

The ghost, the link and every other command except `coop fight` (below) run on any save.

### Shared enemies (experimental, off by default)

`coop fight` is the first stage of shared enemies, not yet tried in game. With a friend linked, each enemy that both
games spawned at the same spawn point, with the same character id and maximum HP, shares one HP bar, balance gauge and
death, decided by the host. Each player gets the kill and the loot in their own game. Each screen's enemy still fights
only its own EVE, and positions are not shared. It changes enemy stats through the game's own code, so it runs only on
the co-op save slot, only for the enemy types in `fight_chars`, and kills count in the co-op save. Back up your saves
first (see [saves.md](saves.md)).

- `shared_enemies=on` in [coop-settings.txt](#coop-settingstxt) allows `coop fight on` and asks for it once a load,
  when your first save has loaded: on the co-op save slot it starts; on another slot the notice
  `Shared fight off: not on the co-op save` says why not. Setting it back to `off` and pressing Ctrl+R stops a running
  `coop fight on` (the solo test tools below go on).
- `coop fight on` starts it by hand (it needs `shared_enemies=on` and `fight_chars`) and `coop fight off` stops it. It
  waits for a linked friend and a loaded save, and pauses while either player is in photo mode (selfies and the
  pause menu do not pause it). Loading another save slot turns it off until it is asked again.
- `coop fight status` answers with the `fight=` line of `coop status`, for example
  `fight=on mode=on role=host enemies=3 ...`.
- Solo test tools: `coop fight probe` is read only and logs each actor (character id, HP, Shield, Stamina) to
  `coop-fight.log`, which is where to find the ids for `fight_chars`. Once the log says `fight writes=armed`,
  `coop fight test hp|sh|st <change>` (whole units, never 0) and `coop fight test kill` write to the eligible enemy with
  the lowest HP share. `coop fight record` keeps the host's side in `coop-fight-record.txt` until `coop fight off`;
  `coop fight replay` plays that file into the guest's side.
- Every `coop fight` command except `off` and `status` stops on another slot with
  `STOP: coop fight runs only with the co-op save slot loaded (INSTALL.md: Co-op save slot); now <the slot line>`.
- Notices: `Shared fight on: <n> enemies linked` when it starts, and again when enemies get linked after none (the
  host counts none until the friend's side is on);
  `Shared fight off: <why>` when it stops after it ran or waited.

### `coop off`

`coop off` stops everything until the game restarts, even across a Lua reload: the ghost, EVE's capture, the loopback,
a recording (which is written), a replay, engine reads, the Steam link, the screen notices, the Night Operation
poller, a recruiter (despawned when one was asked, in Xion) and the photo pause (released: only for this does the
native tick still run).
Afterwards only `coop status` and `coop report` answer; every other command answers
`STOP: coop off is active until the game restarts`.

## coop-settings.txt

`Mods/StellarCoop/coop-settings.txt` is yours. The mod writes it with the defaults when it is missing. Afterwards only
the [co-op menu](#co-op-menu) changes it, one line at a time, and keeps the file as it was before its first change of a
load as `coop-settings.old.txt`. Neither the release zip nor an install ships or removes it (`tools/install.py
--uninstall` backs it up with the folder, then removes it). It is read when the mod loads (game start, or Ctrl+R).
Delete it to get the defaults back.

The file the mod writes:

```
# StellarCoop settings, read when the mod loads (game start, or Ctrl+R). The co-op menu (menu_key) changes them too,
# one line at a time, and keeps the file as it was as coop-settings.old.txt. Delete this file to get the defaults back.
# Keys: F1 to F12 except F10, optionally with Shift+, Ctrl+ or Alt+ in front (for example Shift+F7). menu_key opens
# the co-op menu, whose first row hosts; host_key hosts at once, or none.
menu_key=F5
host_key=none
status_key=F6
leave_key=F8
# Who can join a session you host: friends (your Steam friends can join from their friends list) or private (only the
# friends you invite).
who_can_join=friends
# Your friend's Steam name above her ghost: on or off.
name_tag=on
# Poses sent to your friend a second: 10 to 30.
send_rate=20
# What the ghost shows, each on or off (off unless set here): cloth (her ponytail swings), dyes (hair colours and
# material variants), effects (her attack and skill effects). dyes and effects off also stop sending yours.
# For example: cloth=on
# Shared enemies, experimental: on or off. On, the enemies you and your friend both fight share one HP bar and one
# death, while both of you play your co-op save slot. fight_chars: the enemy character ids it shares, separated by
# spaces (coop fight probe logs them), for example fight_chars=15011001.
shared_enemies=off
fight_chars=
# Synced photo mode: while your friend is in photo mode, your game pauses. both: pause and be paused (both PCs need
# both), notice: a notice only, off: nothing. photo_freeze_max: the longest pause in seconds, 30 to 3600, or 0 for no
# limit. photo_ghost: your friend's ghost in your own photos; photo_name_tag: its name tag in them.
photo_sync=both
photo_freeze_max=600
photo_ghost=on
photo_name_tag=off
# The co-op menu: ui_scale 75 to 150 (%), ui_sounds on or off, ui_language game (the game's: English or French) or
# english.
ui_scale=100
ui_sounds=on
ui_language=game
# The session chat (Enter opens it during a session): on or off. Off hides your friend's lines and sends none.
chat=on
# Your friend on screen, each on or off: partner_bar her name, HP and shield over her head; partner_arrow an arrow at
# the screen's edge toward her when she is out of view; partner_card her card at the top left; card_details the ping
# and her map on it. While partner_bar shows her name, the name tag above her ghost hides.
partner_bar=on
partner_arrow=on
partner_card=on
card_details=on
```

| Setting | Values | Default |
| --- | --- | --- |
| `menu_key` | `F1` to `F12` except `F10`, with at most one of `Shift+`, `Ctrl+` or `Alt+` in front | `F5` |
| `host_key` | same, or `none`: hosts at once | `none` |
| `status_key` | same, without `none` | `F6` |
| `leave_key` | same | `F8` |
| `who_can_join` | `friends` or `private`: who can join a session you host (private: only the friends you invite) | `friends` |
| `name_tag` | `on` or `off`: your friend's Steam name above their ghost | `on` |
| `send_rate` | `10` to `30` poses sent a second | `20` |
| `cloth` | `on` or `off` | `off` |
| `dyes` | `on` or `off` | `off` |
| `effects` | `on` or `off` | `off` |
| `shared_enemies` | `on` or `off`: [shared enemies](#shared-enemies-experimental-off-by-default), experimental | `off` |
| `fight_chars` | At most 16 enemy character ids, whole numbers separated by spaces | empty |
| `photo_sync` | `both`, `notice` or `off`: the [synced photo mode](#synced-photo-mode); a pause needs `both` on both PCs | `both` |
| `photo_freeze_max` | `0` (no limit) or `30` to `3600`: the longest pause your friend's photo mode holds your game in, in seconds | `600` |
| `photo_ghost` | `on` or `off`: your friend's ghost in your own photos | `on` |
| `photo_name_tag` | `on` or `off`: its name tag in your own photos | `off` |
| `ui_scale` | `75` to `150`: the menu's size, in percent | `100` |
| `ui_sounds` | `on` or `off`: the game's UI sounds in the menu | `on` |
| `ui_language` | `game` (French or English, as the game) or `english` | `game` |
| `chat` | `on` or `off`: the [session chat](#session-chat); off hides your friend's lines and sends none | `on` |
| `partner_bar` | `on` or `off`: the [marker](#partner-hud) over your friend's ghost; on, it carries their name instead of the name tag | `on` |
| `partner_arrow` | `on` or `off`: the arrow toward your friend when they are out of view | `on` |
| `partner_card` | `on` or `off`: your friend's card at the top left | `on` |
| `card_details` | `on` or `off`: the ping and your friend's map on the card | `on` |

Rules:

- `F10` is refused because it opens the console (as does `~`). Function keys do not depend on the keyboard layout.
- Names and values ignore case, a UTF-8 BOM (Notepad) is accepted, and lines starting with `#` are comments. Only the
  first 4096 bytes are read.
- A refused value keeps its default, and `UE4SS.log` says why in a `[StellarCoop] settings:` line. An unknown setting
  is ignored with a note.
- Two actions on one key put all four keys back to their defaults: `F5` for the menu, `none` to host, `F6` and `F8`.
- No `menu_key` line (a file from before the menu): the menu takes `host_key`'s key and `host_key` counts as `none`.
  The first `menu_key` the menu writes into such a file also writes `host_key=none`.
- The `[StellarCoop] keys:` line gives the keys in use, the name tag and the send rate, for example
  `keys: menu=F5 host=none status=F6 leave=F8, name tag on, 20 poses a second`. Another line says when a mod loaded earlier binds
  the same key; both then run. The `[StellarCoop] photo sync:` line gives the photo settings in use.

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

Each session event shows in the feed at the top left of the screen, in grey with the time, for 8 s (see
[Session chat](#session-chat)). `UE4SS.log` gets each one once as `[StellarCoop] link: notice=<n> <text>`. On the
title screen they go to the log only.

While the on-screen UI is not up (still loading after a map change, or stopped after an engine error), a notice shows
instead as a line of text about 30 cm above your EVE, turned to the camera, for 4 s each in turn. At most 4 wait; the
oldest goes. If the engine refuses that line too, screen notices stay off until the next Lua load
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
| Your friend's photo mode pauses you | `<name> is taking photos: game paused. Esc > Photo Mode to join in.`, then `Game resumed.` or `Paused for <n> min: game resumed.` (`photo_freeze_max`) |
| Your friend's photo mode, no pause | `<name> is taking photos.` (your `photo_sync=notice`), `<name> is taking photos (their photo sync gives notices only).` or `<name> is taking a selfie.` |
| Your photo mode | Once a session, `<name>'s game does not pause for photos.` (shown when you leave photo mode) |
| The photo pause failed | `Photo sync can no longer pause this game: notices only until the game restarts.` |

## Status lines

### The status key (F6)

F6 gives one line, in the log (`OK: ...`) and on screen as a notice:

- `Co-op: not in a session.`
- `Co-op: hosting, no friend yet.`
- `Co-op: <name> is connecting.`
- `Co-op: hosting <name>.` or `Co-op: in <name>'s game.` (`Paused by <name>.` while their photo mode pauses your game;
  a lost friend adds `Connection lost.`)
- `Co-op: invite held until your save has loaded.`
- `Co-op: rejoining your friend's game (try <n>/3).`
- `Co-op: waiting for Steam.`
- `Co-op: the Steam link stopped; coop status says why.`

### `coop status`

`coop status` prints the full state on one log line, its parts separated by ` | `:

- **Steam**: `mod=<version> proto=8 steam=<waiting|ready>`, then the Steam ID, app id, game build, overlay, relay
  availability and callback counts.
- **Link**: `link=<none|host|guest> lobby=<id>`, with `pending=1` while a lobby call runs, `held=<lobby>` for an invite
  held and `rejoin=<n>/3` while rejoining. Then a `peer=...` line per lobby member (handshake, lost flag, RTT), a
  `friend=<linked 0|1> <lost 0|1> <name>` line, a `mate=<12 numbers>` line with your friend's HP, shield, Beta, Burst
  and Tachy for the partner card (while their last reading is under 3 s old; your own during `coop loopback`), and the
  last 8 notices as `notice=<n> <text>`.
- **Pose path**: `engine=on` (then `loopback=on <delay> <jitter> <loss>` or `loopback=waiting` until EVE's capture comes,
  `record=on`, `replay=on`, `remote=<generation> <count> <loopback|replay|peer>`), or `engine=off reason=<why>`; then
  `nightop=on` or `nightop=rule` while the probe's poller runs.
- **Save slot**: `slot=<coop|main|none|unknown> index=<n|?> marker=<n|none|bad|?>` (see
  [saves.md](saves.md#the-co-op-save-slot)).
- **Photo mode**: `photo=<0|1|s> peer_photo=<0|1|s> frozen=<0|1> sync=<both|notice|off>`: yours and your friend's
  (`s` for selfie mode), whether your game holds the photo pause (`coop freeze` holds it too), and the `photo_sync`
  your friend gets (`notice` when your game cannot pause).
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
| `coop-settings.txt` | Lua, once, then the co-op menu | Your settings (see above) |
| `coop-settings.old.txt` | Lua, at the menu's first change of a load | `coop-settings.txt` as it was before that change |
| `coop-status.txt` | native | The current state, as `coop status` shows it |
| `coop-link.log` | native | This run's header and numbered events, in UTC like `UE4SS.log`, repeats counted, capped at 1 MB |
| `coop-link.old.log` | native | The previous run's `coop-link.log`, moved there at start |
| `coop-report.txt` | native | Written on `coop report` |
| `coop-record.bin` | native | The last recording (`coop record`) |
| `nightop-probe.txt` | native | The `coop no` poller's lines, capped at 4 MB |
| `nightop-probe.old.txt` | native | An earlier run's last probe file, moved there when the native part starts and finds one |
| `coop-fight.log` | native | The shared enemies' probe actors and stats lines, capped at 4 MB |
| `coop-fight.old.log` | native | The previous run's `coop-fight.log` |
| `coop-fight-record.txt` | native | The last shared-enemies recording (`coop fight record`) |
| `coop-request.txt` | Lua | A console request for the native part |
| `coop-session.txt` | Lua | A token per Lua load |
| `coop-components.txt` | Lua | Your EVE's capture (the component table) |
| `coop-remote.txt` | native | The remote table the ghost is built from |
| `coop-display.txt` | Lua | The ghost Lua built for that table |
| `coop-state.txt` | Lua | Whether a save is loaded, the send rate, your photo mode and the photo settings |
| `coop-puppet.txt` | Lua | The ghost's object path, so the next Lua load can remove a ghost left standing |
| `coop-ui.txt` | Lua | The co-op menu's on-screen root, so the next Lua load (Ctrl+R) can remove it and, if the menu was open, give the game its keys back |
| `coop-say.txt` | Lua | A chat line you typed, for a moment: the native part takes and deletes it at once |
| `coop-chat.txt` | native | Your friend's chat lines, for a moment: Lua takes and deletes it within 250 ms |

The files shared between Lua and the native part are each written whole beside (a `.tmp` file) and renamed over, so
neither side ever reads one half-written. The native part deletes the capture, remote, display, state and chat files,
and any stale request or report, when it starts. The chat files are also deleted when a session ends and when the
game exits, and chat text never goes into a log, a report or the console. A run without `coop no` writes no probe
file, so `nightop-probe.old.txt` can be older than the previous run.

An install and the release zip both add `Scripts/version.lua`. An install also writes `install-manifest.txt`; the
release zip adds `INSTALL.md`, `CHANGELOG.md` and `SHA256SUMS.txt`.
