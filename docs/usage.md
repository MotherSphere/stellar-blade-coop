# Using StellarCoop

To install the mod, see [INSTALL.md](../INSTALL.md). For what happens behind each feature, see
[how-it-works.md](how-it-works.md).

Close the game before you change any file in the mod folder.

## Keys

The keys work with or without the console. They need the native part (`StellarCoop.dll`).

| Key (default) | Action | Console equivalent |
| --- | --- | --- |
| F5 | Open or close the [co-op menu](#co-op-menu); its first row hosts a session | (none) |
| F6 | Show the status: one line on screen (see [Notices](#notices)) and in `UE4SS.log` | (a short form of `coop status`) |
| F8 | Leave the session | `coop leave` |
| Enter | During a session, open the [chat](#session-chat) box, then send a line; Esc closes the box | (none) |
| none | Host a session at once, or open the Steam invite dialog again while you host (`host_key`) | `coop host` |

You can change F5, F6 and F8 in the menu's Options page or in [coop-settings.txt](#coop-settingstxt), and `host_key`
in the file only. A key passes its action to the game thread, where the same checks as for the console command apply
(`coop off` included). The log says `key F5: menu`. The other keys then log the usual `OK:` or `STOP:` line; the menu
key logs one only when the menu cannot open.

Before the menu existed, F5 hosted. A settings file written by an older version has no `menu_key` line: the menu then
opens on that file's `host_key` (F5, or the key you set there, such as Shift+F5), and no key hosts at once. To keep a
key that hosts at once, set both `menu_key` and `host_key`.

## Co-op menu

F5 opens the co-op menu on the left of the screen. It opens in a world only: not on the title screen, not while the
game is paused or shows the mouse cursor for one of its own screens, and not during your own photo mode. While the menu
is open, the game ignores its own keys, so EVE stands still.

| Key | In the menu |
| --- | --- |
| Up arrow, W or Z | Up |
| Down arrow or S | Down |
| Left arrow, A or Q | Previous value of a setting |
| Right arrow or D | Next value of a setting |
| Enter or Space | Select |
| Esc | Back, then close |
| F5 | Close |

The main page shows the rows that fit your session:

| Row | Shown | What it does |
| --- | --- | --- |
| Host a session | Outside a session | Runs `coop host`. The menu closes first, because the Steam invite dialog opens. |
| Leave the session | In a session | Runs `coop leave` when you select it a second time within 3 s |
| Invite a friend (Steam) | While you host | Runs `coop invite`. The menu closes first. |
| Copy my code | While you host with a [join code](#join-codes) | Shows the code and runs `coop copy`, which puts it on the clipboard |
| Remove <name> | While a player who is not your Steam friend is in the session you host | Runs `coop remove <SteamID>` when you select it a second time within 3 s |
| Join a friend | Outside a session | Runs `coop join` |
| Join with a code | Outside a session | Closes the menu and opens the [code box](#join-codes) |
| Chat | During a session, with chat on | Closes the menu and opens the [chat](#session-chat) box |
| Options | Always | Opens the settings, below |
| Write a bug report | Always | Runs `coop report` |
| Close | Always | Closes the menu |

Under the rows, a status line shows the F6 text and, once your friend is linked, their ping. Below it the menu shows
its own messages, such as `Select again within 3 s to leave.`, or, while it covers the [feed](#session-chat), the
newest notice under 8 s old (for example the result of Join a friend). The menu closes by itself when the game pauses
or shows the mouse cursor for one of its own screens.

### Options

Each row of the Options page is a setting of [coop-settings.txt](#coop-settingstxt). The rows are in groups: Controls
(the menu, status and leave keys), Photo mode, Partner (the name tag and the [partner HUD](#partner-hud)), Ghost (the
looks and the send rate), Session (who can join a session you host), Saves (the [co-op saves](#co-op-saves) at the
title), Combat (shared enemies), Display (the size, sounds and language of the menu, the chat and the partner HUD) and
Chat.

Left and right change a value, and Enter does the same as right. Each change rewrites only that setting's line in
`coop-settings.txt`; comments and other lines stay as they are. The first change since the mod loaded keeps the file as
it was as `coop-settings.old.txt`. A change applies at once, except for the name tag, which says
`Saved. It takes effect when the mod reloads (game start or Ctrl+R).`

To change a key, select its row, then press the new key: `F1` to `F12` except `F10`, alone or with Shift, Ctrl or Alt.
A key that another action already holds is refused, and the menu names that action. Esc stops waiting. The new key
works at once.

The menu, the chat, the partner HUD, the code box, the host's question, the co-op saves' question and notices, and the
shared enemies' notices use the game's language when it is French, and English otherwise. So do the status line (under
the menu and on F6) and the ghost's notices. `ui_language=english` keeps them all in English. The notices of the Steam
link (a friend joined or left, your join code) and `UE4SS.log` stay in English, and so do the error messages from the
coop commands, shown in the menu or the code box.

If the menu or the chat box ever leaves the game without its own keys, open the console (F10 or `~`) and type
`coop ui reset`: the menu and the boxes close, an open [host's question](#join-codes) is answered with Deny, and the
game gets its keys back. `coop ui off` removes the co-op menu, the chat box, the code box, the host's question, the
feed, the partner HUD and the co-op saves' question until the mod reloads (game start or Ctrl+R). Notices then go back
to the line above your EVE, and your friend's name back to the name tag above their ghost. With the UI off,
`auto_coop_save=ask` plays your own saves and `always` still switches to the copies.

## Session chat

During a session (or `coop loopback`), Enter opens a text box at the top left of the screen, under the feed. It opens
in a world only, and not while the game is paused or shows the mouse cursor for one of its own screens. While the box
is open, the game ignores its own keys, so EVE stands still, and the mod's keys (F5, F6, F8) do nothing. If the game
pauses or shows the mouse cursor while the box is open (EVE dies, or your friend's photo mode pauses your game), the
box closes and what you typed is lost. Alt+Enter never opens it.

| Key | In the chat box |
| --- | --- |
| Enter | Send the line; on an empty line, close the box |
| Esc | Close the box; what you typed is lost |

- Any keyboard layout works, with accents: the game's own text box turns your keys into characters. A line holds at
  most 200 bytes (200 letters, fewer with accents or emoji), and the rest is cut. From 160 bytes, a counter at the
  right of the box shows how many you typed, for example `172/200`. It turns red past 200.
- Your lines show at once in white, your friend's in teal and notices in grey, each with the time. A line that could
  not be sent turns red and ends with `(not sent)`. At most two lines a second are sent. When four lines are waiting,
  the line you typed stays in the box: press Enter again.
- While the box is closed, the feed shows the lines of the last 8 s, at most 6 rows. While it is open, the feed shows
  the last 12 rows. The feed hides while the co-op menu is open, and the menu shows the newest notice instead.
- A sound plays when a line from your friend arrives (unless `ui_sounds=off`).
- Outside a session, Enter shows `Chat needs a session.`, at most once every 10 s.
- `chat=off` in [coop-settings.txt](#coop-settingstxt), or Options > Chat, hides your friend's lines and sends none.
  Enter then shows `Chat is off (Options > Chat).`
- The history is kept in memory only, 50 lines at most. It is cleared when the session ends, at `coop off` and when
  the mod reloads (game start or Ctrl+R). Chat text never goes into a log, a report or the console, and its two files
  exist for a moment only (see [Files in the mod folder](#files-in-the-mod-folder)). A crash or a forced kill can leave
  the last line in `coop-say.txt` or `coop-chat.txt` until the next game start, which deletes it. A crash dump holds
  the game's memory, so it may hold lines of the session.
- Key binds of other mods still run while you type.
- The mod cannot tell when the game's console has the keyboard. During a session, the Enter that runs a console command
  other than `coop ...` also opens the box a moment later. Press Esc to close it.
- If the on-screen UI stopped after an engine error (`UE4SS.log` says why), the box does not open
  (`The chat box is off (the UI stopped, see UE4SS.log).`), and your friend's lines show on the line above your EVE.

## Partner HUD

During a session (or `coop loopback`, where your own values stand in for your friend's), three parts show your
friend, in teal:

- The card, at the top left above the feed: their Steam name, then one row each for their HP (three lines of dots),
  shield blocks and Beta cubes, filled by the same rules as your own gauges at the bottom left. The right end of the
  name's line shows their ping and map, for example `118 ms · e04` (`card_details`), `DOWN` in red while they are down,
  or `elsewhere · b07` while they are on another map. It shows `connection lost`, or `—` when no HP has come from them
  for 3 s; both grey the card out and keep their last values.
- The marker over their ghost's head: their name, a row of HP dots, a shield line, and the distance once they are more
  than 15 m away. While the marker shows their name, the ghost's own name tag is hidden. With the marker off, or the
  on-screen UI stopped, the name tag is back (`name_tag`).
- The arrow at the edge of the screen, which points to them when they are out of view or behind you, with the distance
  and three HP pips.

While nothing comes from your friend (connection lost, or no HP for 3 s), the marker and the arrow turn grey and stay
where your friend was last seen, until they are back or one of you changes map. On another map there is no marker and
no arrow; the card says where they are. The card, the marker and the arrow stay inside the screen at any resolution
and `ui_scale`. From `ui_scale=125` the card covers the top line of the chat while the chat box is open.

The gauges move over 300 ms. They run up to about 0.65 s behind your friend's own screen, plus the network delay. The
game's alert sound plays when your friend goes down and when the connection is lost (unless `ui_sounds=off`). Options >
Partner turns each part on or off at once: `partner_bar` (the marker), `partner_arrow`, `partner_card` and
`card_details`. The card, the marker and the arrow hide while the game is paused or shows one of its own screens (a
shop, a dialogue choice). Your own photo mode hides them too, like the rest of the mod's screen.

## Playing with a friend

1. The host presses F5 and selects Host a session. This creates a Steam lobby for 2 players and opens the Steam invite
   dialog. Pick your friend there. By default the lobby is friends-only: your Steam friends who have the mod can also
   join from their friends list or with `coop join`. With Options > Session > Who can join set to Invited only
   (`who_can_join=private`), only the friends you invite can join. Set to With a code (`who_can_join=code`), it opens
   no dialog, and anyone you give the [join code](#join-codes) to can ask to join. The setting counts for the next
   session you host.
2. Your friend accepts the invite in Steam. If their game is closed, Steam starts it. They join once a save is loaded
   (EVE in a world, not on the title screen). Until then their game holds the invite (`Invite held: joining once your
   save has loaded.`). A newer invite replaces a held one, and host, join or leave drops it.
3. The ghost turns on automatically in both games when the session starts. Once both games have accepted each other's
   handshake, each of you sees the other's EVE where she stands, in her outfit, with their Steam name above her.

More about sessions:

- The host leads. When the host leaves, the guest leaves too (`Session ended: <host> left.`).
- A guest cannot host. The menu shows a guest Leave the session instead of Host a session, and `coop host` answers
  `You are in <host>'s game: leave it first.`, so a guest's key press never ends the host's session.
- If the guest loses the host's lobby another way (Steam drops them, a network cut), their game rejoins it
  automatically. It tries at 2, 12 and 42 s and gives up at 60 s (`Lost <host>'s game: rejoining.`, then
  `Rejoined <host>'s game.` or `Session ended: ...`). A lobby that is gone, or that someone else owns by then, ends the
  session. Leave, host, join or a new invite stops the rejoin. The host keeps the lobby meanwhile. The ghost is removed
  when the link drops and comes back when the link does.
- Your friend's ghost shows only when you are both on the same map. When they are on another map, a notice shows once:
  `<name> is in <map>, you are in <map>.`, with the last segment of each map's path (for example `b07`).
- Your friend's ghost hides after a second without a pose and shows again with the next one.
- Both players need the same protocol (8) and game build. A mismatch shows a notice on screen (see [Notices](#notices)).

The ghost is display only. Items, unlocks and progress are not copied between your two games. The experimental
[shared enemies](#shared-enemies-experimental) are on by default and run on [co-op saves](#co-op-saves) only.

### Join codes

With Options > Session > Who can join set to With a code (`who_can_join=code`), Host a session creates a lobby that
does not show in your friends' lists, and no invite dialog opens. The notice `Hosting. Your join code is CCS-CBMH.`
gives its 7-character code. The menu's Copy my code row shows it too, and selecting it puts it on the clipboard
(`Join code CCS-CBMH copied.`). Send it to the other player, for example in Discord. Each new lobby gets a new code.

The other player opens the menu outside a session and selects Join with a code. A text box opens where the menu was.
It works like the chat box: any keyboard layout, the game ignores its own keys, and the mod's keys do nothing.

| Key | In the code box |
| --- | --- |
| Enter | Join with the code typed, in capitals or not, with or without the dash. Other text stays in the box with `A join code is 7 letters and digits, like XXX-XXXX.`; an empty box closes. |
| Esc | Close the box |

The box closes when a session starts, when the game pauses or shows the mouse cursor, and outside a world. The native
part checks the code: most codes with a wrong character get `That is not a join code: check its 7 characters.` (see
[how-it-works.md](how-it-works.md#lobby-and-invites)), and a code that leads to no game gets one of the
`Could not join: ...` notices.

A player who is not your Steam friend waits for your answer, whatever Who can join says. Their game shows
`Joined <host>'s game. Waiting to be let in.` Yours shows a question in the middle of the screen, `<name> wants to
join`, with Accept and Deny. It opens on its own, maybe while you walk or use the menu. Deny has the focus, and for
1 s after it shows every key does nothing, so keys pressed for something else never answer it.

- The Up and Down arrows move between Accept and Deny, Enter answers, and Esc denies. W, S and Space do nothing here.
  While the question is open, the game ignores its own keys and the mod's keys do nothing.
- The question opens in a world, while the game is not paused and the chat box is closed, and closes the co-op menu.
  Until then it waits. It hides while the game pauses and comes back after.
- With no answer for 60 s, the native part refuses the player, even if the question never showed (with
  `coop ui off`, for example). The question shows the seconds left.
- A denied or removed player cannot come back to that lobby. Their game shows `<host> refused the link: you were not
  let in` (or `you were removed from this session`) and leaves.
- If players you do not know keep asking, host again: the new lobby gets a new code.
- While a player who is not your Steam friend is in your session, the menu shows Remove <name>. After a Lua reload
  (Ctrl+R) that row stays hidden for a player let in before the reload; `coop remove <SteamID>` still works.
- `coop allow <SteamID>` and `coop deny <SteamID>` answer from the console. `coop status` shows the waiting player on
  its `pending=` line.

## Co-op saves

On the title screen, once the on-screen UI has loaded (a few seconds), the mod asks whether to play on co-op copies of
your saves, while the game uses your own saves (`auto_coop_save=ask`, the default).
[INSTALL.md: Co-op saves](../INSTALL.md#co-op-saves) lists the choices; [saves.md](saves.md#co-op-saves) has the files
and the rules.

| Key | In the question |
| --- | --- |
| Up arrow, W or Z | Up |
| Down arrow or S | Down |
| Enter or Space | Select |
| Esc | Decide later (while the copies are made: no switch, the game stays on your own saves) |
| Left click | The choice under the mouse |

While the question shows, the game ignores its own keys and a dark shade over the screen takes the mouse, so neither
reaches the title menu. The game gets its keys back 150 ms after the question closes. A controller cannot answer it:
after 60 s with no key, it closes as Decide later, and `auto_coop_save=always` or `off` skips it. Choosing Continue or
Load Game before the question shows loads your own save; the question comes back at the next title screen.
`coop ui reset` closes it as Decide later.

`auto_coop_save=always` makes the copies and switches to them at each title screen without asking; `off` turns the
question and the automatic copies off. Options > Saves > Co-op saves changes it at once. The result shows as a notice in the
feed (see [Notices](#notices)). While the game uses the co-op copies, the title screen shows `CO-OP SAVES` at the
top right, whatever `auto_coop_save` says, and the question does not show.

## Synced photo mode

When one of you enters the game's photo mode (P), the other's game pauses about half a second later and stays paused
until the photographer leaves photo mode. The paused player can open the pause menu and enter photo mode from there,
so both of you can pose for one shot. With both in photo mode, each game resumes only when both have left. The pause is
the game's own pause, held in memory only, and nothing is saved. This has not been tested in game yet.

- Both PCs need `photo_sync=both` (the default) in [coop-settings.txt](#coop-settingstxt). `notice` on either PC gives
  a notice and no pause. `off` gives neither.
- Selfie mode gives a notice only, because the game itself does not pause in selfie mode.
- The pause ends when the photographer leaves photo mode, when the connection is lost (after 10 s; it comes back if
  they are still in photo mode when they return), when either of you leaves (F8), with `coop off`, and after
  `photo_freeze_max` seconds (10 min by default) until the photographer's next photo session.
- During your own photo or selfie mode, the mod's screen is hidden (the feed, the menu, the partner HUD), and notices
  wait until it ends, then show above EVE. Your friend's ghost stays in the shot unless `photo_ghost=off`, and its name
  tag is hidden unless `photo_name_tag=on`.
- The pause works on game build 24463856 only. On another build, or after a fault (`photo pause off: ...` in the log),
  photo sync gives notices only.
- `coop freeze <seconds>` (1 to 3600) holds the same pause in your game alone, so you can test it without a friend.
  `coop freeze off` ends it, and so does a load.

## Console commands

The console comes with ConsoleEnablerMod (see [INSTALL.md](../INSTALL.md#requirements)) and opens with F10 or `~`.
Every command starts with `coop`. Each answer goes to `UE4SS.log` as a `[StellarCoop] OK: ...` or
`[StellarCoop] STOP: ...` line. An unknown command prints the usage line.

| Command | What it does |
| --- | --- |
| `coop host` | Host a session (2 players, friends-only; invited only with `who_can_join=private`) and open the Steam invite dialog (the menu's Host a session row); with `who_can_join=code`, host with a [join code](#join-codes) and no dialog |
| `coop invite` | Open the Steam invite dialog again while you are in a lobby |
| `coop join` | Join the first Steam friend found in a Stellar Blade lobby |
| `coop join <lobby id>` | Join that lobby (digits only) |
| `coop join <code>` | Join the lobby of that [join code](#join-codes), in capitals or not, with or without the dash |
| `coop copy` | Put your join code on the clipboard while you host with one (the menu's Copy my code row) |
| `coop allow <SteamID>` / `coop deny <SteamID>` | Let in or refuse the player who is not your Steam friend and waits for your answer |
| `coop remove <SteamID>` | Remove a player from the session you host; they cannot come back to that lobby |
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
| `coop no [heal\|rule\|spawnpt\|actor]` | Night Operation probe (research preview, co-op save only) |
| `coop recruiter [off]` | Night Operation recruiter (research preview, co-op save only) |
| `coop fight on\|off\|status` | Shared enemies (experimental, on by default, co-op save only) |
| `coop fight probe\|record\|replay`, `coop fight test hp\|sh\|st <change>`, `coop fight test kill` | Shared enemies' solo test tools (experimental, co-op save only) |
| `coop freeze <seconds>` / `coop freeze off` | Hold the [synced photo mode](#synced-photo-mode)'s pause alone, 1 to 3600 s |
| `coop ui reset` | Close the co-op menu and the chat box, and give the game its keys back at once |
| `coop ui off` | Remove the co-op menu, the chat box, the feed, the partner HUD and the co-op saves' question until the mod reloads |
| `coop saves probe` | Log what the mod reads of the save file name and the plan of the next copy pass; writes nothing |
| `coop saves convert` / `coop saves coop` | At the title: make the [co-op copies](#co-op-saves); `coop` then switches the game to them |
| `coop saves main` | At the title: switch back to your own saves, while no co-op save has been loaded since the game started |
| `coop off` | Stop everything until the game restarts |

### Session commands

- `coop host` works like the menu's Host a session row. While you host, it opens the invite dialog again, as
  `coop invite` does. A guest's host request is refused.
- `coop join` and `coop join <lobby id>` do not wait for a save to load, unlike an accepted invite. Without an id it
  joins the first friend found in a Stellar Blade lobby; the log says `no friend is in a Stellar Blade lobby` when
  there is none. A lobby id is digits only, and any other text is taken for a join code.
- `coop leave` works like F8.
- `coop report` writes `coop-report.txt` in the mod folder: versions, the save folder, DLLs loaded from other mods, the
  status, a summary of save folder changes and the last 100 events.

### Ghost commands

- `coop puppet` turns the ghost on or off by hand. The ghost turns on automatically when a session starts (the link
  going from none to host or guest). If you turn it off with `coop puppet`, it stays off until the next session.
  Turning it on draws nothing at first: it publishes your EVE's capture, and a ghost is drawn once a table comes back
  from a linked friend, the loopback or a replay.
- `coop basesuit` draws the body and hair on the base suit whatever the table names, and rebuilds the ghost. Run it
  again to go back to each part's own mesh.
- `coop look` with no arguments prints the same `look:` line that each load logs, for example
  `look: cloth=off dyes=off effects=off`. `coop look <cloth|dyes|effects> <on|off>` changes one look until the mod
  reloads (game start or Ctrl+R) and rebuilds the ghost. It does not change `coop-settings.txt`. See [Looks](#looks).

### `coop where`

`coop where` prints one line to compare between the two PCs, with or without a link or a ghost:

```
where map=<map> eve=<x,y,z> yaw=<yaw> mesh=<x,y,z> camp=<id>:<class>@<x,y,z> camp_m=<m>
spawn=<id>:SBSpawnPoint@<x,y,z> spawn_m=<m> origin=<x,y,z> composition=<flag> rebasing=<flag> ghost=<...>
```

- Positions are in centimetres, distances in metres.
- `eve=` is your EVE actor's location. `mesh=` and `yaw=` belong to her main mesh, which is what your friend's ghost of
  you is placed from.
- `camp=` is the nearest object of the four camp classes `Env_VendingMachine_C`, `Env_VendingMachine_Simple_C`,
  `Env_Camp_TeleportMachine_C` and `Env_Camp_TeleportMachine_Tetrapod_C` (vending machines and phone booths): its data
  id (`EnvActorName`), class, position and distance, or `none`. Camps are placed in the levels, so the same id should
  give the same position on both PCs. The search walks every object, so it runs only for this command.
- `spawn=` is the nearest `SBSpawnPoint` (its `SpawnPointName`), found the same way. A map can stream every camp out
  (Spire IV does) while its spawn points stay loaded, so this field gives a reference point anywhere on such a map.
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

These three commands run the ghost pipeline on one PC. They need the native tick and the ghost on (`coop puppet`).

- `coop loopback <delay ms> <jitter ms> <loss %>` (0 to 1000, 0 to 500, 0 to 100) sends your own EVE through an
  in-process network: that one-way delay, plus or minus the jitter, with each 1200-byte segment of a pose lost at that
  rate. The table is never lost. The ghost is yours, so it walks 2 m to your right. `coop loopback 0 0 0` shows it with
  no delay. New settings drop what is in flight and send the table again. `coop loopback off` removes the ghost.
- `coop record` records what is sent (the table and your poses), with or without the loopback or a linked friend, for
  up to 120 s or 24 MiB, or until `coop record off`. The recording is kept in memory. When it stops, it is written to
  `coop-record.bin` in the mod folder if it holds a pose. The name is fixed, so a new recording replaces the last one.
  Rename the file by hand to keep it.
- `coop replay` checks the whole of `coop-record.bin` before anything plays and refuses a file that fails, with the
  reason (`protocol` for a file made under another protocol, which includes every file made before protocol 8). It
  then plays the file in a loop as the remote side, each pose re-stamped as if sent now, until `coop replay off`, which
  removes the ghost. The generation, map and positions stay as recorded: the ghost wears the recorded outfit and walks
  where you walked, with no offset, and the map gate applies.
- During `coop loopback` with no friend linked, a chat line you send comes back as your friend's, and your own HP,
  shield and gauges stand in for theirs on the partner card (`mate=` in `coop status`).
- The loopback and the replay never run together. Either one replaces a linked friend until it is off: nothing is sent
  to the friend meanwhile, what they send is ignored, and their ghost is removed. When it stops, you are linked again:
  your table goes to them at once and theirs comes back with their next resend. A recording can run at the same time
  as either one.

See [how-it-works.md](how-it-works.md#loopback-record-and-replay) for the parts of the pipeline each one tests.

### Night Operation previews

`coop no` (the probe) and `coop recruiter` (the cut recruiter) are research previews of the cut Night Operation mode,
not a playable mode. They run only on a [co-op save](#co-op-saves) and need preparation first: read
[night-operation.md](night-operation.md) before you use them. Otherwise they stop with:

```
STOP: coop no runs only on a co-op save (INSTALL.md: Co-op saves); now <the slot line>
```

(`now no slot status` without the native part.)

The ghost, the link and every other command except `coop fight` (below) run on any save.

### Shared enemies (experimental)

`coop fight` is the first stage of shared enemies. It has not been tested in game yet. With a friend linked, each
enemy that both games spawned at the same spawn point, with the same character id and maximum HP, shares one HP bar,
balance gauge and death, decided by the host. Each player gets the kill and the loot in their own game. Each screen's
enemy still fights only its own EVE, and positions are not shared. It changes enemy stats through the game's own code,
so it shares enemies only on a co-op save, and kills count in the co-op save. Back up your saves first (see
[saves.md](saves.md)).

It is on by default. Options > Combat > Shared enemies (experimental) in the [co-op menu](#options) shows On, and a
new [coop-settings.txt](#coop-settingstxt) has `shared_enemies=on`; a file with no `shared_enemies` line counts as on
too. It starts by itself once you are linked and both play a [co-op save](#co-op-saves), and changes no enemy on your
own save. Enemies get linked only while you are on the same map. Turning the row off (`shared_enemies=off`) stops it
at once, but not the solo test tools below.

`fight_chars=auto`, the default, shares every common enemy (the game's Monster type). Bosses and Alpha Naytibas (the
game's BossMonster type) are not shared yet. `auto` also leaves out a few Monster-type enemies that are not common
ones: the Gorgon (character id 50330), the two laser turrets with 999,999 HP (35027002 and 35027003), and any enemy
with more than 500,000 maximum HP. The common enemy with the most HP has 213,125, on Hard. A list of character ids
instead, for example `fight_chars=15011001 15011002` (16 at most), shares those enemies only, of any type, including
the ones `auto` leaves out. A file written before `auto` existed has `fight_chars=` with nothing after it, which counts
as `auto`.

The host shares 16 enemies at a time. When all 16 places are taken, an enemy the host hurts takes the place of one at
full HP that the friend never hit. When every place holds an enemy in a fight, `coop-link.log` says
`fight full every place holds an enemy in a fight; a hurt one is not shared`, and the next enemies stay unshared until
one of the 16 dies or leaves.

While something keeps it from sharing, one notice says what. It shows again only when that changes, or in the next
session, and 5 seconds after the last one at the soonest:

| What is missing | Notice |
| --- | --- |
| You play your own save | `Shared enemies need a co-op save, and this is your own save. Quit to the title screen and choose Convert and play co-op (Play co-op once you have co-op copies), then Continue or load the same slot number. The ghost works on any save.` |
| The same, with `auto_coop_save=off` or when the co-op copies cannot be used (`saves=off` or `saves=?`) | `Shared enemies need a co-op save, and this is your own save. With the co-op copies off, only the manual co-op slot counts (see INSTALL.md). The ghost works on any save.` |
| Your friend plays their own save | `Shared enemies wait: <name> plays their own save. They can switch at the title screen with Convert and play co-op (Play co-op once they have co-op copies).` |
| Your friend has shared enemies off | `Shared enemies wait: <name> has them off (co-op menu, Options, Combat).` |
| Shared enemies stopped in your friend's game | `Shared enemies stopped for this run in <name>'s game. Their coop-link.log says why.` |
| You are on different maps | `Shared enemies wait until you and <name> are on the same map.` |

Waiting for a friend, a load or the end of photo mode shows nothing. `Shared enemies on: <n> enemies linked.` shows when
enemies get linked after none (the host counts none until the friend's side is on).
`Shared enemies off. coop-link.log says why.` shows when it stops after it ran or waited, unless you stopped it yourself
(the row, `coop fight off` or `coop off`). `Shared enemies stopped until the game restarts. coop-link.log says why.`
shows when a check of the game's memory turned it off for the run. These notices use the menu's language.

- `coop fight on` asks for it by hand (it needs `shared_enemies=on`) and `coop fight off` stops it until the mod
  reloads or the row is turned off and on again. It waits for a linked friend, a loaded save and a co-op save, and pauses
  while either player is in photo mode (selfies and the pause menu do not pause it). Loading your own save pauses it
  until you load a co-op save again. Setting `shared_enemies=off` in the file and pressing Ctrl+R also stops it (the
  solo test tools below keep running).
- `coop fight status` prints the `fight=` line of `coop status`, for example
  `fight=on mode=on role=host enemies=3 ... her=on`. While a friend is linked, `her=` gives their side: `on`,
  `own-save` (their own save), `off` (shared enemies off), `stopped` (stopped for the run), `waiting` (a load, photo
  mode, `coop off`, or a reason their `coop-link.log` gives) or `?` (nothing heard from their game yet).
- Solo test tools: `coop fight probe` is read only and logs each actor (character id, type, HP, Shield, Stamina) to
  `coop-fight.log`, where you find the ids for `fight_chars`. With no `fight_chars` list, the line of a Monster that
  `auto` leaves out ends with `left_out=charId` (the Gorgon or a turret) or `left_out=MaxHP` (more than 500,000
  maximum HP). Once the log says `fight writes=armed`,
  `coop fight test hp|sh|st <change>` (whole units, never 0) and `coop fight test kill` write to the shared enemy with
  the lowest HP share. `coop fight record` keeps the host's side in `coop-fight-record.txt` until `coop fight off`;
  `coop fight replay` plays that file into the guest's side.
- The solo test tools stop on another slot with
  `STOP: coop fight runs only on a co-op save (INSTALL.md: Co-op saves); now <the slot line>`.

### `coop off`

`coop off` stops the following until the game restarts, even across a Lua reload: the ghost, EVE's capture, the
loopback, a recording (which is written), a replay, engine reads, the Steam link, the screen notices, the co-op menu,
the chat box, the feed and the partner HUD (the game gets its keys back), the chat history (cleared), the Night
Operation poller, a recruiter (despawned if one was requested, in Xion) and the photo pause (released; the native tick
keeps running for this alone). Afterwards only `coop status` and `coop report` answer. Every other command answers
`STOP: coop off is active until the game restarts`, and so do the menu, host and leave keys.

## coop-settings.txt

The mod writes `Mods/StellarCoop/coop-settings.txt` with the defaults when the file is missing. After that, only the
[co-op menu](#co-op-menu) changes it, one line at a time, and keeps the file as it was before its first change since
the mod loaded as `coop-settings.old.txt`. The release zip does not include the file, and an install neither adds nor
removes it (`tools/install.py --uninstall` backs it up with the folder, then removes it). The file is read when the mod
loads (game start, or Ctrl+R). Delete it to get the defaults back.

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
# Who can join a session you host: friends (your Steam friends can join from their friends list), code (anyone you
# give your join code to; the co-op menu shows and copies it) or private (only the friends you invite). A player who
# is not your Steam friend waits until you accept or deny them.
who_can_join=friends
# Co-op saves, the co-op copies of your saves (StellarBladeCoop00.sav to 04.sav): ask (a question on the title
# screen), always (the copies at every title, no question) or off (no copies; the manual co-op slot that
# StellarCoopSlot.txt names is then the only co-op save).
auto_coop_save=ask
# Your friend's Steam name above her ghost: on or off.
name_tag=on
# Poses sent to your friend a second: 10 to 30.
send_rate=20
# What the ghost shows, each on or off (off unless set here): cloth (her ponytail swings), dyes (hair colours and
# material variants), effects (her attack and skill effects). dyes and effects off also stop sending yours.
# For example: cloth=on
# Shared enemies, experimental: on or off. On, the enemies you and your friend both fight share one HP bar and one
# death, while both of you play a co-op save. fight_chars: auto (every common enemy; bosses and Alpha Naytibas are not
# shared yet) or the enemy character ids to share instead, separated by spaces (coop fight probe logs them), for
# example fight_chars=15011001.
shared_enemies=on
fight_chars=auto
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
| `host_key` | same, or `none`: a key that hosts at once, without the menu | `none` |
| `status_key` | same as `menu_key` | `F6` |
| `leave_key` | same as `menu_key` | `F8` |
| `who_can_join` | `friends`, `code` or `private`: who can join a session you host (`code`: anyone with your [join code](#join-codes); `private`: only the friends you invite) | `friends` |
| `auto_coop_save` | `ask`, `always` or `off`: the [co-op saves](#co-op-saves) at the title | `ask` |
| `name_tag` | `on` or `off`: your friend's Steam name above their ghost | `on` |
| `send_rate` | `10` to `30` poses sent a second | `20` |
| `cloth` | `on` or `off` | `off` |
| `dyes` | `on` or `off` | `off` |
| `effects` | `on` or `off` | `off` |
| `shared_enemies` | `on` or `off`: [shared enemies](#shared-enemies-experimental), experimental | `on` |
| `fight_chars` | `auto` (every common enemy), or at most 16 enemy character ids, whole numbers separated by spaces | `auto` |
| `photo_sync` | `both`, `notice` or `off`: the [synced photo mode](#synced-photo-mode); a pause needs `both` on both PCs | `both` |
| `photo_freeze_max` | `0` (no limit) or `30` to `3600`: the longest pause your friend's photo mode holds your game in, in seconds | `600` |
| `photo_ghost` | `on` or `off`: your friend's ghost in your own photos | `on` |
| `photo_name_tag` | `on` or `off`: its name tag in your own photos | `off` |
| `ui_scale` | `75` to `150`: the size of the menu, the chat and the partner HUD, in percent | `100` |
| `ui_sounds` | `on` or `off`: the game's UI sounds in the menu, the chat and the partner HUD | `on` |
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
- A refused value keeps its default, and `UE4SS.log` gives the reason in a `[StellarCoop] settings:` line. An unknown
  setting is ignored with a note.
- If two actions share one key, all four keys go back to their defaults: `F5` for the menu, `none` to host, `F6` and
  `F8`.
- A file with no `menu_key` line (one written before the menu existed): the menu takes `host_key`'s key, and
  `host_key` counts as `none`. The first `menu_key` that the menu writes into such a file also writes `host_key=none`.
- The `[StellarCoop] keys:` line gives the keys in use, the name tag and the send rate, for example
  `keys: menu=F5 host=none status=F6 leave=F8, name tag on, 20 poses a second`. Another line says when a mod loaded
  earlier binds the same key; both actions then run. The `[StellarCoop] photo sync:` line gives the photo settings in
  use.

## Looks

Three looks change what the ghost shows. Each is `on` or `off` in `coop-settings.txt` and off by default. The file
names them in a comment only, so add a line such as `cloth=on`, or change them in the menu's Options > Ghost.
`coop look` changes one until the mod reloads. With one on, the `Ghost ... built` log line ends with `; look: ...`.

The three looks have not been tested in game yet. Back up your saves before you turn one on (see [saves.md](saves.md)),
and turn it off again if the game crashes or the ghost looks wrong.

- `cloth`: her ponytail swings as cloth. A follower part whose mesh has clothing assets is drawn as a
  SkeletalMeshComponent whose cloth simulates on its leader's bones. If that fails, it is a plain part, with a note in
  the log. Off, the ponytail stays rigid. Only the viewer's setting counts.
- `dyes`: her hair colour and other material variants. Her capture also names each part's overridden materials (a
  material made at run time is sent as the asset it was made from), and the ghost puts on each one your PC has, by the
  same path rule as the meshes. Dyes do not apply to a fallback mesh. Off, each part has its mesh's own colours.
- `effects`: her attack and skill effects. The native part reads which of 19 known effects (Niagara systems) are
  playing on her, at most 4, into four effect slots of each pose (an index into a fixed list, never a path). The ghost
  starts each effect on the part it hangs on, moves it with the slot and stops it when the slot changes, at most 8
  starts a second. A fault in the native effect read or write turns effects off until the game restarts
  (`effects off: fault ...`), and the ghost stays without them. Every 60 s with any effect activity, an
  `effects, last 60 s:` line counts those started, those over 4, unlisted reads and boxes written.
- `dyes=off` and `effects=off` also stop sending yours, so your friend's ghost of you lacks them too.

## Notices

Each session event shows in the feed at the top left of the screen, in grey with the time, for 8 s (see
[Session chat](#session-chat)). `UE4SS.log` gets each one once as `[StellarCoop] link: notice=<n> <text>`. On the
title screen they show in the feed too, once the on-screen UI has loaded.

While the on-screen UI is not up (in the first seconds after a load or a map change, during your own photo mode, or
after an engine error), a notice shows instead as a line of text about 30 cm above your EVE, turned to the camera, for
4 s, one after another. At most 4 wait; when more arrive, the oldest is dropped. If the engine refuses that line too,
it stays off until the next Lua load (`Screen notices off: <why>; notices stay in UE4SS.log.`).

| Event | Notice |
| --- | --- |
| Hosting | `Hosting: invite a friend from the Steam overlay (Shift+Tab).` |
| Hosting with a join code | `Hosting. Your join code is <code>.` |
| Join code copied | `Join code <code> copied.`, `Could not copy the join code <code>.` or `No join code to copy.` |
| Could not host | `Could not host: Steam refused.` or `Could not host: Steam result <n>.` |
| Host asked as a guest | `You are in <host>'s game: leave it first.` |
| Joined | `Joined <host>'s game.`, with ` Waiting to be let in.` when the host is not your Steam friend |
| A wrong join code | `That is not a join code: check its 7 characters.` or `Could not join: that is not a StellarCoop game.` |
| A player who is not your Steam friend asks to join | `A player who is not your Steam friend is asking to join.` |
| Your answer | `<name> was let in.`, `<name> was not let in.`, `<name> was not let in: no answer within 60 s.` or `<name> was removed.` |
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
| Co-op saves switched on | `Co-op saves on: you play co-op copies of your saves. Your own saves are not changed.` |
| Co-op saves not switched on (`auto_coop_save=always`, or the title screen left while the copies were made) | `Co-op saves off for this load: <why>. You play your own saves.` |
| Shared enemies started, stopped, or waiting for something | See [Shared enemies](#shared-enemies-experimental) |

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

- Steam: `mod=<version> proto=8 steam=<waiting|ready>`, then the Steam ID, app id, game build, overlay, relay
  availability and callback counts.
- Link: `link=<none|host|guest> lobby=<id>`, with `pending=1` while a lobby call runs, `held=<lobby>` for an invite
  held and `rejoin=<n>/3` while rejoining. While you host, a `code=<join code|none> refused=<n>` line follows: the
  join code (`none` unless the lobby was made with `host code`) and the number of players refused for the rest of this
  lobby; then a `pending=<SteamID> <name>` line for a player who is not your Steam friend and waits for your answer.
  Then a `peer=...` line per lobby member (handshake, lost flag, RTT), a
  `friend=<linked 0|1> <lost 0|1> <name>` line, a `mate=<12 numbers>` line with your friend's HP, shield, Beta, Burst
  and Tachy for the partner card (while their last reading is under 3 s old; your own during `coop loopback`), and the
  last 8 notices as `notice=<n> <text>`.
- Pose path: `engine=on` (then `loopback=on <delay> <jitter> <loss>` or `loopback=waiting` until EVE's capture comes,
  `record=on`, `replay=on`, `remote=<generation> <count> <loopback|replay|peer>`), or `engine=off reason=<why>`; then
  `nightop=on` or `nightop=rule` while the probe's poller runs.
- Save slot: `slot=<coop|main|none|unknown> index=<n|?> marker=<n|none|bad|?> saves=<coop|main|off|?>` (see
  [saves.md](saves.md#co-op-saves)). `saves=` names the save files the game uses: `main` for your own,
  `coop` for the co-op copies (`StellarBladeCoop00.sav` to `04`), `off` when the mod cannot read the file name (another
  game build, or a check failed), and `?` before the first read or once the name moved in the game's memory (no switch
  until the game restarts). `coop-link.log` logs each change as `save name: saves=<value>`, with the reason for `off`
  and `?`. After `coop off` it keeps the last value read, since the game keeps that file name until it exits.
- Co-op save copies: `convert=<idle|busy <done>/<jobs>|done|error:<why>>`, the last copy pass (`idle` before any).
- Shared enemies: `fight=on mode=<on|probe|record|replay> ...` with its counts, `fight=waiting mode=<mode> why=<what it
  waits for>`, `fight=stopped why=<why>` or `fight=off`, with `her=<state>` while a friend is linked (see
  [Shared enemies](#shared-enemies-experimental)).
- Photo mode: `photo=<0|1|s> peer_photo=<0|1|s> frozen=<0|1> sync=<both|notice|off>`: yours and your friend's
  (`s` for selfie mode), whether your game holds the photo pause (`coop freeze` holds it too), and the `photo_sync`
  your friend gets (`notice` when your game cannot pause).
- Last event: `last=<the last coop-link.log event>`.
- Ghost: `ghost=on parts=<n> leaders=<n> basesuit=<0|1> left_out=<n> table=<generation> source=<source>`,
  `ghost=waiting`, `ghost=hidden map` or `ghost=off`, plus `stray_parts=<n>` if ghost parts that are not this load's
  ghost stand in the world.

Each changed status line, except the per-peer ones, the `fight=` line and the `mate=` line, also goes to `UE4SS.log`
as `[StellarCoop] link: ...`. Each load logs the save slot as `link: slot=...`.

## Files in the mod folder

Everything the mod writes stays in `Mods/StellarCoop/`. An install never removes these files, and
`tools/install.py --uninstall` backs them up before it removes the folder.

| File | Written by | What it is |
| --- | --- | --- |
| `coop-settings.txt` | Lua, once, then the co-op menu | Your settings (see above) |
| `coop-settings.old.txt` | Lua, at the menu's first change since the mod loaded | `coop-settings.txt` as it was before that change |
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
| `coop-state.txt` | Lua | Whether a save is loaded or the title screen is shown, the send rate, your photo mode and the photo settings |
| `coop-puppet.txt` | Lua | The ghost's object path, so the next Lua load can remove a ghost left standing |
| `coop-ui.txt` | Lua | The co-op UI's on-screen root, so the next Lua load (Ctrl+R) can remove it and, if the menu was open, give the game its keys back |
| `coop-say.txt` | Lua | A chat line you typed, for a moment: the native part takes and deletes it at its next pass |
| `coop-chat.txt` | native | Your friend's chat lines, for a moment: Lua takes and deletes the file within 250 ms |

Each file shared between Lua and the native part is written in full to a `.tmp` file beside it and then renamed over
it, so neither side reads a half-written file. When the native part starts, it deletes the capture, remote, display,
state and chat files, and any stale request or report. The chat files are also deleted when a session ends and when
the game exits. A run without `coop no` writes no probe file, so `nightop-probe.old.txt` can be older than the
previous run.

An install and the release zip both add `Scripts/version.lua`. An install also writes `install-manifest.txt`; the
release zip adds `INSTALL.md`, `CHANGELOG.md` and `SHA256SUMS.txt`.
