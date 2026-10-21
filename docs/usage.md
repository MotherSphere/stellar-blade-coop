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
looks and the send rate), Session (who can join a session you host), Saves (the [co-op saves](#co-op-saves) at the title
and [shared quests](#shared-quests-experimental)), Combat (shared enemies, same place, who same-place enemies attack,
same spawns, extra enemies, shared bosses, the host's enemy and boss scaling and your kill rewards), Display (the
[status line](#status-line-above-the-card) above the partner card, and the size, sounds and language of the menu, the
chat and the partner HUD) and Chat.

Left and right change a value, and Enter does the same as right. Each change rewrites only that setting's line in
`coop-settings.txt`; comments and other lines stay as they are. The first change since the mod loaded keeps the file as
it was as `coop-settings.old.txt`. A change applies at once, except for the name tag, which says `Saved. It takes effect
when the mod reloads (game start or Ctrl+R).`, and the Enemies attack, Same spawns, Extra enemies, Shared bosses,
scaling and kill reward rows, which
count from the next time shared enemies start (turn the Shared enemies row off and on again, or restart the game). The
Same place row applies at once while shared enemies wait or run, and otherwise from their next start (as guest, only
while they wait or run, and only on your screen).

To change a key, select its row, then press the new key: `F1` to `F12` except `F10`, alone or with Shift, Ctrl or Alt.
A key that another action already holds is refused, and the menu names that action. Esc stops waiting. The new key
works at once.

The menu, the chat, the partner HUD, the code box, the host's question, the co-op saves' question and notices, the
shared enemies', same place, same spawns and shared quests notices, and Night Operation's card, result panel and notices
use the game's text language, any of the 23 that the game ships. So do the status line (under the menu and on F6) and
the ghost's notices. `ui_language=english` keeps them all in English. The notices of the Steam link (a friend joined or
left, your join code) and `UE4SS.log` stay in English, and so do the error messages from the coop commands, shown in the
menu or the code box.

If the menu or the chat box ever leaves the game without its own keys, open the console (F10 or `~`) and type
`coop ui reset`: the menu and the boxes close, an open [host's question](#join-codes) is answered with Deny, and the
game gets its keys back. `coop ui off` removes the co-op menu, the chat box, the code box, the host's question, the
feed, the partner HUD, Night Operation's card and result panel and the co-op saves' question until the mod reloads (game
start or Ctrl+R). Notices then go back to the line above your EVE, and your friend's name back to the name tag above
their ghost. With the UI off, `auto_coop_save=ask` plays your own saves and `always` still switches to the copies.

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
  on-screen UI stopped, the name tag is back (`name_tag`). The tag draws only Latin-1 letters: others show as `?`,
  and a name that would lose more than half of them reads `Partner` (in your language when the tag can draw it).
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

### Status line above the card

Options > Display > Status line (`status_overlay`) adds a strip above the card: Off (the default), Compact or
Detailed. Each player's setting is their own, and a change shows at once. The strip shows whenever the
[status line](#the-status-key-f6) says something other than `not in a session` or `waiting for Steam`: while you host
(alone too), while a friend connects or you play in their game, while an invite is held or you rejoin, and after the
Steam link stopped.

- Compact: the status line without its `Co-op:` start, and the ping at the right end, for example `hosting Alex.` and
  `118 ms`. `connection lost` (in red) and `paused` (while your friend's photo mode pauses your game) come first, and
  a lost link shows no ping.
- Detailed: the same, and a second row with what is shared now: `Enemies <n>` while shared enemies run (the `enemies=`
  count of `coop fight status` as host, `pairs=` as guest), `Same place <n>` while same place moves enemies
  (`piloted=`), `Quests on` while shared quests run, and the poses you send a second. For example
  `Enemies 3 · Same place 2 · Quests on · 60/s`.

A row too long for the strip ends with `…`. The strip uses the menu's language. It grows with `ui_scale` up to 100 %
only, so it never covers the card, and it hides when the card does: while the game is paused or shows one of its own
screens, and in your own photo mode.

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
- Both players need the same protocol (11) and game build. A mismatch shows a notice on screen (see [Notices](#notices)).

The ghost is display only. Items, unlocks and progress are not copied between your two games. The experimental
[shared enemies](#shared-enemies-experimental) are on by default and run on [co-op saves](#co-op-saves) only.

Achievements follow one rule: a shared enemy you fight together counts for both of you, and nothing done without you
reaches your save. The mod never unlocks an achievement itself. Your game unlocks them from what happens in your own
world, and a shared enemy dies there only if you took part in its fight (`kill_credit` under
[shared enemies](#shared-enemies-experimental)). An enemy or a boss your friend kills in a fight you were not in does
not die in your game, so it gives you no kill, rewards, drops, quest progress or trophy.

### Your world and your friend's

Each of you plays in your own world, from your own save. Supply boxes, collectibles, passcode doors and camps are each
player's own: a box you open stays closed and full in your friend's world until they open it there, and what is in it
goes to you only. Levers, lifts, doors and puzzles move only in the world of the player who uses them, so your friend's
EVE may ride a lift that stays down on your screen. Vendors, the request board and quest givers work for both players;
[shared quests](#shared-quests-experimental) says which quest steps are shared. Nothing one player opens, buys or picks
up is copied into the other player's game.

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

A friend's invite accepted on the title screen waits until a save loads (`Invite held: joining once your save has
loaded.`). The question then starts with `Your friend's invite waits until your save loads.` If you already answered
Play solo normally or Decide later on that title screen, it asks once more when the invite comes.

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

### Photo mode pause (experimental)

Options > Photo mode > Photo mode pause (experimental), or `photo_pause` in `coop-settings.txt`, changes how your own
photo mode stops your game:

- Full (`full`, the default): the game's own pause. Nothing moves while you take photos, as without the mod.
- Scenery live (`scenery`): the game's own experimental photo method, which the game ships but does not use. The world
  stops only while photo mode opens. Then animations, physics, cloth, hair, effects and sounds go on moving, while
  enemies, combat, events and shared enemies stay stopped. Your friend's ghost moves only while their game runs: with
  `photo_sync=both` on both PCs, your photo mode pauses their game, so the ghost holds its pose. Moving things may
  smear a little, and enemies may slide when photo mode ends. This has not been tested in game yet.

The mod sets the game's console variable `SB.PhotoMode.PauseMethod` (0 for Full, 1 for Scenery live), and only when it
differs from the setting. The game reads it each time photo mode opens, so a change applies from your next photo mode.
`coop off` sets it back to 0 when it can: during a load there is no player controller to set it with, and the log then
says `photo pause: no player controller at coop off`. Whether the game keeps the value after it exits has not been
checked, so choose Full before you remove the mod. The setting does not change your friend's game, and the synced photo
pause above works the same with both values.

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
| `coop mark [text]` | Write a numbered line in your logs and your friend's, to line up the steps of a [test played together](#coop-mark) |
| `coop where` | Print one line of positions to compare between two PCs |
| `coop puppet` | Turn the ghost on or off by hand |
| `coop basesuit` | Draw the ghost's body and hair on the base suit, or back on her own meshes |
| `coop look` | Show which looks are on |
| `coop look <cloth\|dyes\|effects> <on\|off>` | Turn one look on or off until the mod reloads |
| `coop loopback <delay ms> <jitter ms> <loss %>` | Run your own ghost through a simulated network on one PC |
| `coop loopback off` | Stop the loopback |
| `coop record` / `coop record off` | Record what you send (table and poses) to `coop-record.bin` |
| `coop replay` / `coop replay off` | Play `coop-record.bin` back as a ghost, in a loop |
| `coop nightop [start [noaggro\|nomove]\|stop]` | [Night Operation's solo run](night-operation.md#the-solo-run-coop-nightop) (untested in game, co-op save only; `stop` on any save) |
| `coop no [heal\|rule\|spawnpt\|actor]` | Night Operation probe (research preview, co-op save only) |
| `coop recruiter [off]` | Night Operation recruiter (research preview, co-op save only) |
| `coop fight on\|off\|status` | Shared enemies (experimental, on by default, co-op save only) |
| `coop fight probe\|record\|replay`, `coop fight test hp\|sh\|st <change>`, `coop fight test kill` | Shared enemies' solo test tools (experimental, co-op save only) |
| `coop fight pilot status\|probe\|on\|off`, `coop fight pilot test freeze\|cmc\|drive\|replay\|target\|exec` | [Same place](#same-place-experimental) (experimental, on by default) and its solo test steps |
| `coop fight pilot test bstart\|phase\|finish\|summon` | Solo tests of [shared bosses](#shared-bosses-experimental) on the boss copy of a replay (experimental) |
| `coop fight spawn probe` | Solo probe of [same spawns](#same-spawns-experimental) (experimental, co-op save only) |
| `coop quests on\|off\|status` | [Shared quests](#shared-quests-experimental) (experimental, off by default, co-op save only) |
| `coop quests probe\|record\|replay` | Shared quests' solo test tools (experimental, co-op save only) |
| `coop quests force <number>` | As the guest, make the step that quest holds for your own kill, or for a place the game's tables cannot give, where you stand; type it twice within 10 s |
| `coop freeze <seconds>` / `coop freeze off` | Hold the [synced photo mode](#synced-photo-mode)'s pause alone, 1 to 3600 s |
| `coop ui reset` | Close the co-op menu and the chat box, and give the game its keys back at once |
| `coop ui off` | Remove the co-op menu, the chat box, the feed, the partner HUD, Night Operation's card and result panel and the co-op saves' question until the mod reloads |
| `coop saves probe` | Log what the mod reads of the save file name and the plan of the next copy pass; writes nothing |
| `coop saves convert` / `coop saves coop` | At the title: make the [co-op copies](#co-op-saves); `coop` then switches the game to them |
| `coop saves main` | At the title: switch back to your own saves, while no co-op save has been loaded since the game started |
| `coop saves refresh <0-4>` | At the title, while the game uses your own saves: replace that slot's co-op copy, even one played in co-op, with a new copy of your save. Type it twice within 10 s; the old copy goes to `StellarCoopBackups` first |
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
  `look: cloth=on dyes=off effects=off`. `coop look <cloth|dyes|effects> <on|off>` changes one look until the mod
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

### `coop mark`

`coop mark` and `coop mark <text>` put one numbered line in your `coop-link.log` and `UE4SS.log`, and in your friend's.
Type it before each step of a test you play together, so that the steps line up in the four logs you send.

- Your game numbers your marks from 1. The count goes on after Ctrl+R and starts again at 1 when the game restarts.
  Your friend's game numbers their own marks.
- The text is cleaned like a chat line and cut to 100 bytes. Unlike a chat line, it goes into both players' logs,
  `coop status` and `coop report`, so type only what you would put in a bug report. A mark with no text ends at its
  number (`mark 3`, `mark=3 ours`).
- With `coop mark boss start` as your third mark, your `coop-link.log` gets `mark 3: boss start` and your `UE4SS.log`
  gets `[StellarCoop] OK: asked the native part: mark boss start`, then `[StellarCoop] link: mark=3 ours: boss start`.
  Once you are linked, your friend's `coop-link.log` gets `mark 3 from <your Steam name>: boss start`, and their
  `UE4SS.log` gets `[StellarCoop] link: mark=3 from <your Steam name>: boss start`.
- The `mark=` line of `coop status` keeps the last mark, yours or your friend's, until the game exits. `UE4SS.log`
  copies that line when it changes, so two marks less than a quarter of a second apart can show there as one line.
  `coop-link.log` has every mark.
- Without a linked friend, the mark goes to your own logs only. A mark Steam does not send logs
  `mark <n> not sent to <name>`. Your friend's game takes at most 10 chat lines and marks a second from you and drops
  the rest, with one line a minute in their `coop-link.log`: `dropped marks from <name>: over the rate limit`.
- It needs the native part (`coop mark needs the Steam link` without it), and `coop off` refuses it.

### Solo testing: loopback, record, replay

These three commands run the ghost pipeline on one PC. They need the native tick and the ghost on (`coop puppet`).

- `coop loopback <delay ms> <jitter ms> <loss %>` (0 to 1000, 0 to 500, 0 to 100) sends your own EVE through an
  in-process network: that one-way delay, plus or minus the jitter, with each 1200-byte segment of a pose lost at that
  rate. The table is never lost. The ghost is yours, so it walks 2 m to your right. It keeps that side while it shows,
  so it does not circle you when you turn. `coop loopback 0 0 0` shows it with no delay. New settings drop what is in
  flight and send the table again. `coop loopback off` removes the ghost.
- `coop record` records what is sent (the table and your poses), with or without the loopback or a linked friend, for
  up to 120 s or 25 MiB, or until `coop record off`. The recording is kept in memory. When it stops, it is written to
  `coop-record.bin` in the mod folder if it holds a pose. The name is fixed, so a new recording replaces the last one.
  Rename the file by hand to keep it.
- `coop replay` checks the whole of `coop-record.bin` before anything plays and refuses a file that fails, with the
  reason (`protocol` for a file made under another protocol, which includes every file made before protocol 12). It
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

`coop nightop`, Night Operation's solo run, runs only on a co-op save too, with the same `STOP:` line under its own
name, except `coop nightop stop`, which works on any save. See
[night-operation.md](night-operation.md#the-solo-run-coop-nightop).

The ghost, the link and every other command except `coop fight` (below) run on any save. `coop fight pilot` runs on
any save too, since same place only moves enemies while shared enemies run.

### Shared enemies (experimental)

`coop fight` is the first stage of shared enemies. It has not been tested in game yet. With a friend linked, each
enemy that both games spawned at the same spawn point, with the same character id and maximum HP, shares one HP bar,
balance gauge and death, decided by the host. Each player who took part in its fight gets the kill and the loot in
their own game (`kill_credit` below). Each screen's enemy still fights only its own EVE, and positions are not shared
unless [same place](#same-place-experimental) is on.
It changes enemy stats through the game's own code, so it shares enemies only on a co-op save, and kills count in the
co-op save. Back up your saves first (see [saves.md](saves.md)). When an enemy becomes shared, or shared again after a
death, a load or photo mode, the guest's copy takes the host's HP without a damage number; later drops from the host's
hits show one.

When a hit knocks a shared enemy down (face up or face down), launches it or slams it into a wall on one screen, the
other game starts the same effect on its copy, as if its own EVE had landed that hit. A copy that is already down, in
the air or groggy finishes that first and skips it, and a copy the game holds immune to it stays up. Groggy needs
nothing of this: each copy goes groggy when the shared balance gauge empties.

When you are the guest and your hit kills a shared enemy, `guest_kills=at_once` (the default) kills it on your screen
at once. If the host's copy had more HP left (more than 10 % of the enemy's maximum HP above what yours had), the
host's game refuses that kill: the enemy lives on in the host's game and stays dead in yours, and `coop-link.log` says
`desync guest-dead`. With `guest_kills=confirmed`, your copies keep at least 1 HP until the host's game kills its own,
so the enemy dies on your screen about one ping later, and a refused kill leaves it alive at the host's HP. Only the
guest's setting counts. The mod holds that 1 HP through the game's MinimumHP stat and sets the stat back when the
enemy dies or stops being shared, and when shared enemies stop. After a fault inside the game's own code it leaves the
stat as it is: the fault's line in `coop-link.log` then says how many of these changes stay until their enemies leave
the map.

A kill decided in the other game waits while your copy of the enemy holds the game's NoDamageNoHit state (it grabs
your EVE, burrows or warps in), because the game never kills an enemy in the middle of a grab. Your copy dies when the
state ends, or after 6 seconds anyway. When the guest's hit is the kill, the host's copy waits at 1 HP.
`coop-link.log` says `fight kill held <key>`, then `fight held-expired <key>` when the 6 seconds ran out.

Shared enemies get more HP and balance, since two players hit them. The host's `enemy_hp_scale` (default `1.35`)
multiplies a shared enemy's maximum HP, and `enemy_balance_scale` (default `1.15`) its balance gauge, each from `1.0`
(no change) to `4.0`. Both games use the host's values for the whole session; the guest's are not used, and the
guest's `coop-link.log` says so once a run when they are not both `1.0`. An enemy gets
them when it becomes shared, and its HP and balance rise in the same proportion, so an enemy at half HP stays at half.
When it stops being shared, or shared enemies stop, it gets its own maximums back and keeps the same share of HP and
balance. On the host's side an enemy gets them once the guest's side is on, and keeps them until it dies or leaves the
16 shared places, even while the guest pauses. That covers every enemy in the 16 places, also one the guest's game
never links (it is in another part of the map, or its copy does not match), which the host then fights alone at the
higher values. The mod changes the game's MaxHPValue and MaxStamina stats through the game's own code. An enemy whose
maximum HP the game has changed in another way keeps its own (the stats line of `coop-fight.log` counts it as
unscaled). The `Shared enemies on` notice names the values when they are not both 1.0,
for example `Shared enemies on: 3 enemies linked. Enemy HP 135 %, balance 115 % (the host's setting).`, and the
`fight=` line of `coop status` has `scale=135/115`.

`kill_credit` is each player's own and decides when you took part in a shared enemy's fight. With `together`, the
default, you took part when your EVE hit it, when it targeted your EVE, or when your EVE stands within 30 m of it as it
dies. With `fought`, the distance does not count. Whether it targeted you or your hit landed comes from the game's
record of the last player an enemy fought, the record the game itself uses to credit a kill. An enemy that your own hit
kills always gives you the kill. When the other player kills a shared enemy you took no part in, your copy does not die:
it stops being shared and stays alive in your game, back at full HP, so its kill rewards, drops, quest kills and
achievements never reach your save, and one hit of yours later does not finish what the other player's hits did. A boss
copy goes back to full HP the same way. Whether you can then beat that boss alone before the area reloads has not been
tested in game. The guest's `coop-link.log` then says `fight dead-unshared <key> hguid=<n> not taken part`, the host's
says `fight kill-unshared <key> hguid=<n> not taken part`, and the host's game does not share that enemy again in this
session. Damage dealt before an enemy became shared does not count as yours, since the other player may have dealt it.
When a knockdown the other player started, mirrored on your copy, makes the game record your EVE as that enemy's last
player, the log says `fight last player <key> set by a mirrored crowd control` and that record no longer counts for
this enemy: your hit or the 30 m still do.
`kill_credit=all` from 0.4.0-beta.1, which gave you every shared kill wherever you stood, is gone (see
[coop-settings.txt](#coop-settingstxt)).

Slow motion is not shared: each game slows down on its own, as in solo. With [same place](#same-place-experimental)
on, a shared enemy runs in the game of the player it fights, and the other screen draws it from that game. So when
that player's perfect dodge slows the enemy down, it slows down on both screens, and an enemy that your friend's game
runs keeps its speed on your screen while your own perfect dodge slows your game down. The stats line in
`coop-fight.log` counts slow motion as `slow motion <n> times (<t> turns, lowest <p> %)`: how often your EVE or an
enemy of the shared fight began to run below normal speed, the turns that lasted, and the lowest speed in percent.
How the two screens compare during slow motion has not been tested in game yet.

It is on by default. Options > Combat > Shared enemies (experimental) in the [co-op menu](#options) shows On, and a
new [coop-settings.txt](#coop-settingstxt) has `shared_enemies=on`; a file with no `shared_enemies` line counts as on
too. A file from version 0.2 says `shared_enemies=off` and keeps it off until you turn the row on. It starts by itself
once you are linked and both play a [co-op save](#co-op-saves), and changes no enemy on your own save. Enemies get
linked only while you are on the same map. Turning the row off (`shared_enemies=off`) stops it at once, but not the
solo test tools below.

`fight_chars=auto`, the default, shares every common enemy (the game's Monster type). Bosses and Alpha Naytibas (the
game's BossMonster type) are shared only with the host's `bosses=on` ([shared bosses](#shared-bosses-experimental)).
`auto` also leaves out a few Monster-type enemies that are not common
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
| You play your own save | `Shared enemies need a co-op save, not your own. Quit to the title screen, choose Convert and play co-op (or Play co-op), then Continue or load the same slot.` |
| The same, with `auto_coop_save=off` or when the co-op copies cannot be used (`saves=off` or `saves=?`) | `Shared enemies need a co-op save, not your own. With the co-op copies off, only the manual co-op slot counts (see INSTALL.md).` |
| Your friend plays their own save | `Shared enemies wait: <name> plays their own save. They can switch at the title screen with Convert and play co-op (or Play co-op).` |
| Your friend has shared enemies off | `Shared enemies wait: <name> has them off (co-op menu, Options, Combat).` |
| Shared enemies stopped in your friend's game | `Shared enemies stopped for this run in <name>'s game. Their coop-link.log says why.` |
| You are on different maps | `Shared enemies wait until you and <name> are on the same map.` |

Waiting for a friend, a load or the end of photo mode shows nothing. `Shared enemies on: <n> enemies linked.` shows when
enemies get linked after none (the host counts none until the friend's side is on).
`Shared enemies off. coop-link.log says why.` shows when it stops after it ran or waited, unless you stopped it yourself
(the row, `coop fight off` or `coop off`). `Shared enemies stopped until the game restarts. coop-link.log says why.`
shows when a check of the game's memory turned it off for the run. These notices use the menu's language.

When your friend's game loads other `.pak` mods than yours, a notice says so once a session, for example
`Kaanta loads other .pak mods than you (1 there, 2 here). Enemies that differ stay unshared.` The mod compares the
`.pak` files beside the base game's in `SB/Content/Paks` and its folders (`~mods`, `LogicMods`), by name and size;
`coop-link.log` lists yours at its start. It is a warning only.

The guest also sees two notices while enemies are shared. `Shared enemies: some enemies have another max HP in <name>'s
game (another difficulty or New Game+). They stay unshared.` shows once, until shared enemies stop or the friend
leaves, when an enemy of the host's cannot be paired because its maximum HP differs (by more than 0.5, before any
scaling). `Shared enemies: <name> is down. Once they respawn, the enemies you share go back to full health.` shows each
time the host goes down while enemies are linked: the host's respawn resets the enemies in the host's game, and your
copies follow them back to full health. A respawn on another map leaves your copies unshared, with the HP they had.

- `coop fight on` asks for it by hand (it needs `shared_enemies=on`) and `coop fight off` stops it until the mod
  reloads or the row is turned off and on again. It waits for a linked friend, a loaded save and a co-op save, and pauses
  while either player is in photo mode (selfies and the pause menu do not pause it). Loading your own save pauses it
  until you load a co-op save again. Setting `shared_enemies=off` in the file and pressing Ctrl+R also stops it (the
  solo test tools below keep running).
- `coop fight status` prints the `fight=` line of `coop status`, for example
  `fight=on mode=on role=host enemies=3 ... her=on`. The guest's line has `unpaired=<n>` (the host's enemies it could
  not pair) and `maxhp=<n>` (those of them with another maximum HP), and the answer then lists up to 8 of them by spawn
  key and reason (`charId`, `maxhp` or `duplicate`), for example
  `; unpaired: 5003:0 charId, 5005:1 maxhp; 3 of ours not on the host's list`. The last count is the guest's own
  enemies that the host's list lacked since the host's last world change. While a friend is linked, `her=` gives
  their side: `on`, `own-save` (their own save), `off` (shared enemies off), `stopped` (stopped for the run),
  `waiting` (a load, photo mode, `coop off`, or a reason their `coop-link.log` gives) or `?` (nothing heard from their
  game yet).
- Solo test tools: `coop fight probe` is read only and logs each actor (character id, type, HP, Shield, Stamina) to
  `coop-fight.log`, where you find the ids for `fight_chars`. With no `fight_chars` list, the line of a Monster that
  `auto` leaves out has `left_out=charId` (the Gorgon or a turret) or `left_out=MaxHP` (more than 500,000
  maximum HP). A line adds `states=` when the actor holds one of the game states the mod reads: 3
  (NoDamageNoHit, during a grab), 4 (NoDamage), 6 (Down), 7 (Groggy), 8 (Airborne) or 27 (Immortal). A `cc=` part
  follows when a knockdown or launch effect the mod mirrors runs on it: 9900001 (Airborne), 3000300 (Down), 3000301
  (DownFaceUp), 3000303 (DownFaceDown) or 3000401 (WallHit). Once the log says `fight writes=armed`,
  `coop fight test hp|sh|st <change>` (whole units, never 0) and `coop fight test kill` write to the shared enemy with
  the lowest HP share. `coop fight record` keeps the host's side in `coop-fight-record.txt` until `coop fight off`;
  `coop fight replay` plays that file into the guest's side. Both change enemies (record through the host's scaling,
  when it is above 1.0), so the mod refuses them until the log says `fight writes=armed`.
- The test tools are typed on purpose. `coop fight test kill` kills only an enemy your EVE took part in, as for a
  shared kill (you hit it, it targeted you, or it stands within 30 m of your EVE); its kill rewards and achievements
  then count in your save as if your EVE had killed it. Any other enemy is refused with
  `fight test <key> refused: not taken part`. A `test hp` drop larger than the enemy's HP kills it too, with no killer:
  your game skips its kill rewards, but its drops and the game's other death events still happen, and the kill still
  counts toward the kill achievements when your EVE hit it or it targeted your EVE. A replay kills your copies on the
  recorded deaths with the `kill_credit` rule of a live fight, so with `together` one within 30 m of your EVE dies with
  your EVE as its killer.
- The solo test tools stop on another slot with
  `STOP: coop fight runs only on a co-op save (INSTALL.md: Co-op saves); now <the slot line>`.

### Same place (experimental)

With `same_place=on` in the host's game, each shared enemy stands in the same place on both screens. One game runs the
enemy's AI, so the enemy moves there and attacks that game's EVE. In the other game the copy follows it about 200 ms
late, the same delay as the ghost, and plays its attacks, reactions, sounds and effects with the game's own animation
files. Hits land on either copy and count through shared enemies as before, and HP and death stay with the host's
game.

The host's `aggro` setting decides which game runs an enemy's AI. With `aggro=game`, the default, an enemy goes to the
player who hit it last. After 10 s without a hit, it goes to the other player once that player's EVE has stood at least
3 m nearer to it, and within 30 m of it, for 2 s. An enemy changes hands at most once in 4 s, and never during one of
its attacks, while it is down, groggy, in the air or in a takedown, or while it dies. An enemy the guest's game refuses
or gives back stays with the host's game for 30 s. With `aggro=host`, every enemy stays with the host's game and never
attacks the guest. Same place is on by default and has not been tested in game yet.

A takedown moves the enemy at once. When either player starts a takedown on a groggy enemy, that player's game takes
the enemy for it, without the 4 s wait, and the other game shows the takedown from its stream, on the same timeline as
the ghost. The host's game applies the guest's killing hit only once her takedown ends, or after 6 s. If the host kills
the enemy during her takedown, her game gets that death only then too. An enemy that lives through a takedown stays
with the player who did it for 10 s, or until the other player hits it. With `aggro=host`, the guest's takedown plays
only on her screen, and the host's still shows on hers. The host's game refuses the guest's takedown of a boss or an
Alpha Naytiba, shared through `bosses=on` or named in `fight_chars`. A boss in its Finish stance (GorillaB, Tachy or
SkullJuggernaut at 1 HP, for example) ends only by the host's finisher: her killing hit leaves the host's boss at 1 HP,
and her game takes the finisher's state off her copy. A boss without a Finish stance dies of her killing hit as a
common enemy does, unless its own thresholds or Immortal hold it.

In the game that draws an enemy, the mod puts the game's own BlockAI effect on the copy, takes its movement component
out of the game's movement manager, writes its position every frame from the other game's stream and replays that
game's Shows (the game's animation sequences) on it. A copy that is knocked down, groggy or in the air moves by the
game's own rules until that ends. When an enemy changes hands, the game that takes it removes BlockAI, puts the movement
component back and points the enemy at its own EVE with the game's force target function.
[how-it-works.md](how-it-works.md#same-place-enemies) has the details.

- It needs shared enemies running, and only the host's value counts, as with the scaling: Options > Combat > Same
  place (experimental) in the host's co-op menu, or `same_place=on` in its [coop-settings.txt](#coop-settingstxt).
- `aggro` is the host's too, and counts from the next start of shared enemies: Options > Combat > Enemies attack
  (host's), Both players (`aggro=game`) or The host only (`aggro=host`).
- While shared enemies wait or run, turning the row off stops same place at once on your side (as host, on both
  screens), and turning it on starts it again. Otherwise, as host, the next start of shared enemies takes the row's
  value. As guest, the host's value decides at every start.
- `coop fight pilot off` stops it on your side until the next `coop fight on`. As host, the guest's copies go back
  too. `coop fight pilot on` starts it again (it needs `same_place=on`). `coop fight off`, `shared_enemies=off` and
  `coop off` stop it with shared enemies. As host, a reload (Ctrl+R) with `same_place=off` in coop-settings.txt stops
  it too while shared enemies run or wait. Each copy goes back to the game within a second and fights its own EVE
  again.
- `coop fight pilot status` prints the `pilot=` line of `coop status`: `pilot=on piloted=<n> owned=<n> drawn=<n>`
  (piloted: the enemies this game moves as host, or the copies it moves as guest; owned: the enemies whose AI runs in
  this game; drawn: the copies it draws from the other game), `pilot=off why=<why>`, `pilot=stopped` (an error
  stopped it until the game restarts) or `pilot=refused why=<why>` (another game build, or `coop off`), with
  `probe=on` and `test=<step>` while those run. `why=` is `fight` (shared enemies are not running), `setting` (the
  host's `same_place` is off), `host` (as guest: the host's game has it off) or `asked` (`coop fight pilot off`).
- Notices, in the menu's language: `Same place: <n> enemies piloted.` when enemies start to be moved after none,
  `Same place off: <name>'s game turned it off.` on the guest's screen when the host's game stops it, and
  `Same place off: stopped by an error until the game restarts. coop-link.log says why.` Your own
  `coop fight pilot off` and the row show nothing.
- While it runs, `coop-fight.log` gets a `pilot stats:` line each second (the `pilot=` line, the host's reads of its
  enemies and their cost, the show lines sent, and the bytes both ways with the rate a second, `-` on the first line
  after a pause) and a `pilot drawn:` line when the guest's side changed (copies moved, movement components taken out,
  releases, snaps, drift, Shows replayed, late or missing, those not replayed because the copy already plays them, and
  the game thread's time a frame while it holds copies).
  `coop fight pilot probe` adds each `SBE` message and show line sent and received, until `coop fight pilot off`. The
  `SBE` messages take about 13 KB/s with 16 enemies.
- The drawing game's `coop-link.log` gets a line for each copy released (`pilot released hguid=<n>`), back on the
  stream (`pilot converged hguid=<n>`) or moved in one jump (`pilot snapped hguid=<n>`).
- Each change of hands is logged: on the host, `fight own <key> hguid=<n> to her` or `back`, and
  `fight own-no hguid=<n> <why>` when the guest refuses one or gives one back; on the guest, `fight own <key> hguid=<n>
  taken` and `fight own-no hguid=<n> <why>`. The game that takes an enemy logs `pilot taken hguid=<n> oe=<epoch>:
  target our EVE`, or `pilot take-over refused hguid=<n> oe=<epoch>: <why>` when its force target cannot run: `not
  net mode 0`, `a logic task in flight` or `copy not found` after 250 ms, `a game singleton not made yet`, `no EVE of
  ours` or `no AI on the copy`. The guest then gives the enemy back (`own-no target`). The `pilot stats:` line counts
  these take-overs.
- Takedowns are logged in `coop-link.log`. On the guest: `fight exec <key> hguid=<n> our takedown begins` and `our
  takedown ends` (without the key once the copy is gone). On the host: `fight exec <key> hguid=<n> her takedown begins`,
  `her takedown ended` or `her takedown timed out` (no end within 6 s), `fight exec refused <key> hguid=<n> <why>` (`no
  Groggy or takedown on our copy`, or `one runs already`; one within 2 s of her last one for that enemy is counted with
  no line), `fight kill held <key> hguid=<n> her takedown` and `fight dead held <key> hguid=<n> her takedown` while the
  host waits, and `fight held-expired <key> hguid=<n>` when 6 s passed first. The `fight stats:` lines count `takedowns
  of hers (<n> refused)` on the host and `takedowns told` on the guest.
- After an error in the game's own code, copies the mod already moved can keep their movement component out of the
  manager and stand still until they leave the map or you rest at a camp. The error's line in `coop-link.log` says
  so.

To test it alone, record the host's side once, then play it into the guest's side after a camp
rest:

1. With `same_place=on`: `coop puppet`, then `coop fight probe` until `coop-link.log` says `fight writes=armed`, then
   `coop fight off`.
2. `coop record` and `coop fight record`, fight one enemy (a few hits from different sides and a skill or two), then
   `coop fight off` and `coop record off`.
3. Rest at a camp, so the enemy is back where it started.
4. `coop fight pilot test <step>`, then `coop replay` and `coop fight replay`. Watch the enemy, then `coop fight off`
   and `coop replay off`.

The step says how far the guest's side goes: `freeze` (the BlockAI effect only: the enemy stands and plays its own
animations), `cmc` (its movement component out of the game's manager too, nothing written: the `pilot drawn:` line's
drift says how far the game still moves it), `drive` (its position, speed and velocity from the recording too, no Show
replayed) or `replay` (all of it). It holds until the next `coop fight pilot test` or `coop fight on`.

`coop fight pilot test target` tests the force target alone, during step 2 (as host, every shared enemy runs in your
game). At the next frame it points the first of them at your EVE. `coop-link.log` says
`pilot target test hguid=<n>: forced` or `pilot target test hguid=<n> refused: <why>`, then
`pilot target test hguid=<n> +<ms> ms: target <our EVE|another actor|none>, aggro level <n>, detect result <n>` each
time one of the three changes during the next second.

`coop fight pilot test exec` tests a takedown, during step 4 with `replay`. At the shared fight's next turn it empties
the balance of the first frozen copy, so the copy goes groggy; take it down before that ends. `coop-link.log` says
`fight pilot test exec <key> hguid=<n> balance emptied: take it down`, or why not (`refused: no frozen copy drawn`,
`refused: gone or dying`, `its balance is empty already`). Then come `pilot released hguid=<n>` as the copy goes
groggy, `fight exec <key> hguid=<n> our takedown begins` and `our takedown ends` around the takedown, and
`pilot converged hguid=<n>` (or `pilot snapped hguid=<n>`) once the copy lives on after it.

### Same spawns (experimental)

With `same_spawns=on` in the host's coop-settings.txt, the guest's game holds the same common enemies as the host's
game wherever both players stand within 100 m of each other in one zone. The guest's game creates the enemies it lacks
where the host's stand, and removes the ones the host's game lacks without killing them, so they give no rewards.
Bosses, Alpha Naytibas, quest and event enemies, and the enemies a save records (Save rows, and rows kept through a
zone reset) stay as they are in both games. Same spawns is on by default and has not been tested in game yet.

The guest's game calls its own spawn function for each enemy it lacks (the one the game calls when a zone's enemies
spawn) and its own despawn job for each enemy the host's game lacks (the one zone events send). No code of the game is
changed. When she enters a zone, her game spawns its own enemies first, so an enemy can appear there and vanish again
a few seconds later.

- It needs shared enemies running. Only the host's value counts, from the next `coop fight on`: Options > Combat >
  Same spawns (experimental) in the host's co-op menu, or `same_spawns=on` in its
  [coop-settings.txt](#coop-settingstxt). Record, replay and the probe never use it.
- A zone counts as shared from 3 s after either game entered it or reset its enemies (a camp rest, a death), so the
  game's own spawns come in first. Where the other player stands comes from the same-place code, so after its error
  on either PC (`pilot=stopped`) same spawns stop in both games until that PC's game restarts.
- The guest's game sends its list of enemies there at once, then every 5 s while the zone is shared. The host's game
  answers with up to 16 enemies to create and 16 to remove each time. It asks for an enemy more than 1 km from the
  guest only once she comes nearer.
- `coop-link.log` names each change by spawn key. On the guest: `fight spawned <key>`, `fight despawned <key>`, `fight
  spawn refused <key> <why>` and `fight drop refused <key> <why>`, where why is `too far` (more than 1 km from your
  EVE), `no row`, `save-row`, `keep-row`, `event-row` or `another zone` (as your game's tables have it), `no spawn
  manager`, `not shared` (an enemy shared enemies leave out: no common enemy, or one `fight_chars` does not name),
  `full` (240 enemies already handled since either game's last `fight spawns epoch`, or 48 extras), `row taken`, `no
  such enemy` and `not made` (for an extra, below), `gone` or `busy` (you are fighting that enemy or taking it down: it
  is removed once you are done, if the host's game still lacks it); and `fight spawn
  undone <key> <why>` when an enemy it created turns out to be one shared enemies leave out (`not shared`) or another
  character than the host's (`charId`), or `fight spawn kept <key> <why>` when that enemy could not be removed (it was
  dying, for one). On the host: `fight spawn sent <key>` and `fight drop sent <key>`. Both log `fight spawns epoch
  <why>` when their zone changes (`zone`), its enemies reset (`reset`), or 3 or more of them come back at once
  (`guids`). `fight spawns leave <spawnId>:0 save-row` (or `keep-row`) comes once a session for a row of a shared enemy
  that same spawns leave as it is. A game keeps the first 512 rows it reads, and rows past those are not logged.
- The `fight=` line of `coop status` (and `coop fight status`) says `spawns=off`, `spawns=on` or `spawns=stopped` (the
  error of same place stopped them too), and on the guest's side `spawned=<n> despawned=<n> spawns_differ=<n>`: the
  enemies her game created and removed, and the refusals that show the two games differ (`no row`, `save-row`,
  `keep-row`, `event-row`, `another zone`, `row taken` and `not shared`, and enemies undone or kept).
- Notices, in the menu's language, once a session each: `Same spawns on: where you and <name> stand within 100 m of
  each other in one zone, their game holds the same common enemies as yours.` (on the guest's screen: `your game
  holds the same common enemies as theirs.`), `Same spawns stopped by an error until the game restarts.
  coop-link.log says why.`, and on the guest's screen `Same spawns: some enemies differ between your game and
  <name>'s (other .pak mods or fight_chars) and stay as they are. coop-link.log names them.`
- The `fight stats:` lines in `coop-fight.log` add `same spawns <on|off>, epoch <n> (ours moved <n> times), <n> rounds
  <answered|sent>, <n> spawn and <n> drop lines, <n> spawned, <n> despawned (<n> undone), <n> refused, <n> differ,
  <n> stale, <n> over the rates`. `differ` is the count `spawns_differ=` shows, so it can exceed `refused`.

`coop fight spawn probe` checks the reads of same spawns on one PC, with no friend: it runs on a co-op save, as
`coop fight probe` does, whatever `same_spawns` says. At each probe census, `coop-link.log` gets `fight spawns epoch
<why>` when the zone changes or its enemies reset (rest at a camp to see `reset`, or `guids` when the reset fell
between two probe censuses, which come once a second), and once an epoch for each shared enemy, 32 a census at most,
`fight spawns probe <key> <how>`: `takes part` (same spawns would create or remove it), `save-row`, `keep-row`,
`event-row`, `another zone` or `no row`. `fight spawns probe no zone` means the current zone has no ZoneTable ID. The
probe reads two game tables and calls neither the spawn function nor the despawn job. The `fight=` line says
`spawns=probe` while it runs; `coop fight off` ends it.

### Extra enemies (experimental)

With `enemy_extra` at 1, 2 or 3 in the host's coop-settings.txt and same spawns on, each common enemy where both players
stand within 100 m of each other in one zone gets that many more next to it, 2 to 4 m away, in both games. Bosses, Alpha
Naytibas, Elites (the game ranks M_RoyalGuardFemale and its two variants Elite), quest and event enemies, and the
enemies a save records get none, and so does an enemy more than 116 m from both players. No more extras come while 16
common enemies stand within 120 m of either player, counting the extras: shared enemies pair 16 at most. An extra goes
once both players are more than 120 m from it, and every extra goes when shared enemies stop on either PC. Extras have
not been tested in game yet, and the default is 0.

- Only the host's value counts, from the next `coop fight on`, and only with `same_spawns=on`: Options > Combat >
  Extra enemies (host's) in the host's co-op menu, or `enemy_extra` in its [coop-settings.txt](#coop-settingstxt).
- `coop-link.log` names each extra by its key: `3758096641:1` is the first enemy's first extra. In both games: `fight
  extra made <key>` and, at the end, `fight extra despawned <key> end`. On the host: `fight extra refused <key> <why>`
  (`full`: 48 extras already; `not made`: the game made none), `fight extra despawned <key> far` (both players more than
  120 m away), and `fight extras off <key> key range taken` when the host's tables use the extras' first key, so no
  extras this session. `fight extra kept <key> <why>` means the despawn job could not be sent, or with `guid unread`
  that the game made the extra but its GUID could not be read: shared enemies stop until the game restarts, and that
  extra stays until it leaves the map. On the guest an extra arrives as any same spawns key (`fight spawned <key>`).
  `fight spawn refused <key> row taken` means her game's tables hold a row at that key. `fight spawn refused <key> no
  such enemy` means none of her common enemies has the extra's charId yet: the host's game sends that extra again, and
  it comes once the enemy it stands next to is in her game. `full` there means her game holds 48 extras, and `not made`
  that her game made none. None of these three counts in `spawns_differ=`.
- The `fight stats:` lines in `coop-fight.log` add `extras <n> an enemy, <n> made, <n> despawned`.

### Shared bosses (experimental)

With `bosses=on` in the host's coop-settings.txt, shared enemies also share the bosses and Alpha Naytibas (the game's
BossMonster type) that both games hold: one HP bar, balance gauge and death, as for a common enemy. Shared bosses are on
by default and have not been tested in game yet. With same place on, the guest's copy is frozen like any copy her game
draws, so it never casts its own skills. The host's game tells hers when its boss enters battle mode, which phase
effects it holds and which enemies it summons, and her game applies the same to her copy: the arena events, the phase
changes and the summoned enemies, which are shared like any other. Her copy leaves battle mode up to 10 s after the
host's boss does, not counting time while the host's game is paused, and at once when it stops being shared. Without
same place, each game runs these for its own copy. A boss in its Finish stance ends only by the host's finisher: a
killing hit of the guest's then leaves it at 1 HP, and her game takes the finisher's state off her copy. If the boss
stops being shared first (the link drops, the host's world changes, `coop fight off`), her game removes the Immortal it
put back on her copy, and her own hit ends that boss in her game. A boss without a Finish stance dies of her killing hit
as a common enemy does, unless its own thresholds or Immortal hold it. When the host's boss dies, her copy dies too if
she took part in its fight (`kill_credit` under [shared enemies](#shared-enemies-experimental)), its thresholds taken
off first. Otherwise her copy stays alive in her game, so the boss's trophy and story events come only when she fights
it herself. Her game starts the boss fight on her copy (the arena events) only while her EVE stands within 30 m of it
or has hit it. [How it works](how-it-works.md#shared-bosses) has the details, and
[troubleshooting](troubleshooting.md#a-shared-boss-differs-between-the-two-games) the log lines.

- Only the host's values count, from the next `coop fight on`: Options > Combat > Shared bosses (experimental) and
  Boss HP (host's) in the host's co-op menu, or `bosses` and `boss_hp_scale` in its
  [coop-settings.txt](#coop-settingstxt). `coop fight record` keeps them in its file, and `coop fight replay` uses the
  recorded ones.
- `boss_hp_scale` (default `2.0`, from `1.0` to `4.0`) multiplies a shared boss's maximum HP in place of
  `enemy_hp_scale`, the Alpha Naytibas' too; `enemy_balance_scale` still sets its balance gauge. The mod does not adjust
  a boss's phase thresholds yet. The game sets each one (a minimum HP) as a share of the maximum HP the boss has when
  the threshold starts. The first one starts at spawn, before the scaling: at `2.0`, a boss whose first phase ends at
  60 % can end it at 30 % of its scaled HP (not measured in game yet). Later ones start from the scaled maximum and can
  sit above the HP the boss has left, which then rises to the threshold the next time the boss is hit: at `2.0`,
  Tachy's first threshold leaves it at 75 % of its unscaled maximum, and its second one, 45 % of the scaled maximum, is
  90 %. When the scaling ends during a fight (`coop fight off`, the end of the session), a threshold taken from the
  scaled maximum stays as it was and can be above the boss's own maximum HP.
- A boss takes one of the 16 shared places before any common enemy, even the place of a common enemy in a fight, which
  then stops being shared, unless that enemy's death or takedown is under way. A common enemy never takes a boss's
  place.
- With same place on, a shared boss always fights the host: its AI never moves to the guest's game, whoever hits it.
- A boss that only one save still holds (the other player already killed it, for example) stays unshared. The host's
  game fights its own alone, at `boss_hp_scale` once the guest's side is on, as with common enemies; a boss that only
  the guest's save holds stays as it is in her game. Same spawns never create or remove a boss.
- The `fight=` line of `coop status` carries `bosses=<percent>` (the host's `boss_hp_scale`) or `bosses=off`, on
  both PCs.

To test shared bosses alone, record the host's side of a boss fight as the [same place](#same-place-experimental)
steps do, with `bosses=on`, load the save again so the boss is back, then play the recording into the guest's side
with `coop replay` and `coop fight replay`. A recording keeps no boss start, phase or summon lines, so the guest's side
of a shared boss does not run in a replay by itself. Four commands run it on the frozen boss copy nearest your EVE, at
the shared fight's next turn, one test at a time. They work only while `coop fight replay` runs; otherwise
`coop-link.log` says `pilot test <name> refused: only while coop fight replay runs`. Each test logs `fight pilot test
<name> <key> hguid=<n> ...` lines in `coop-link.log` and ends with a `done` line, or with a `stopped` line when the
copy goes. A test asked while another one runs is refused (`another test runs`).

- `coop fight pilot test bstart` logs the copy's battle mode, first-time latch, on-battle flag, states 30 and 39 and
  whether its AI runs a task (`before: b58=<0|1> 45a=<n> 45b=<n> state30=<0|1> state39=<0|1> ai=<0|1>`), starts the boss
  fight on the copy as the host's game would (`SetBattleMode called`, or `SetBattleMode not called: <why>`, where
  `again` means it already ran on this copy and the copy is still in battle mode), then logs each change of those values
  for 1 s (`after <ms> ms: ...`, then `done: ...`). A replay has no host to repeat the boss start, so the copy leaves
  battle mode 10 s after the call (`fight battle off` in `coop-link.log`), and a test after that calls it again. Once
  the replay has played all its lines, the copy stays in battle mode until `coop fight off`. From the next `coop fight
  replay` until the next `coop fight on`, boss copies get no `BattleMode_5s` from the recording, so a second run after a
  reload shows the boss start alone. The replay that ran the test still gets it on its boss copies, so its other tests
  find the copy as the guest's side would.
- `coop fight pilot test phase` sends the copy the first phase row of its boss that it lacks (5005115 for GorillaB),
  and 5 s later the dispel of its HP threshold, as the host's phase lines would. Each line logs `line: <rows>; floor
  <stat 107>` and `cast: <n> taken, <n> refused`, and at the next turn `next turn: floor <stat 107>; rows <the rows
  it holds>`. `refused: every phase row held` means the copy holds them all already.
- `coop fight pilot test finish` holds the copy at 1 HP for 10 s through the guest's HP correction, so none of the drop
  counts as your hit, then gives it the host's HP back. It logs `start: HP <n>, floor <n>, 2001101=<0|1>
  2001102=<0|1> state27=<0|1> state3=<0|1>` (Passive_DeathReady and Passive_FinishReady on the copy, then its
  Immortal and NoDamageNoHit states), each change as `after <ms> ms: HP <n> ...`, and `done: <n> guard turns, HP <n>;
  the host's HP from the next turn`. Run it after `phase`, so no threshold holds the copy above 1 HP. Back up your
  saves first ([saves.md](saves.md)): a boss that dies here stays dead in that save once the game saves, and its kill,
  trophy and story events count there. Hit the copy once, and only after a line shows `state27=1` (its Immortal): with
  the finish guard working, it stays at 1 HP. If the test stops before its `done` line (`coop fight off`, or the copy
  no longer drawn), the copy gets back the HP it had when the test started.
- `coop fight pilot test summon` makes a DollHead (SE_M_DollHead_02) 3 m in front of your EVE under the first summon
  key, `4026531841:0`, with its summon row's effects (5025010 and 5025013) and the guest's freeze, as her game does
  for a host's summon: `fight summon made 4026531841:0`, then `made 3 m ahead: life <n>, freeze taken`, or `the game
  froze it first` when its row's effects froze it already. For 10 s it logs each change of the DollHead's life state
  and state 39, and freezes it again when the game ends the freeze (`frozen again`). If the game refuses the guest's
  freeze, the mod removes the DollHead at once (`not made: freeze refused` or `stopped: freeze refused`, and `fight
  summon despawned 4026531841:0 freeze refused`). No host enemy pairs with it, so 3 s after its `done` line the mod
  removes it (`fight summon despawned 4026531841:0 unpaired`), or at `coop fight off`. `refused: same place off`
  means same place does not run on this side. A DollHead you kill meanwhile counts in your save (its kill and album
  entry).

### Shared quests (experimental)

Shared quests carry the quest steps that the host and the guest make together into the guest's co-op save. They are
off by default and have not been tested in game yet. Back up your saves before you turn them on (see
[saves.md](saves.md)), and keep Steam Cloud off.

They run while a friend is linked, both players play a co-op save and both have them on: Options > Saves > Shared
quests (experimental) in the co-op menu, or `shared_quests=on` in [coop-settings.txt](#coop-settingstxt). The row asks
`coop quests on` or `coop quests off` at once, and with the setting on the mod asks `coop quests on` by itself once a
load. Only the host's steps count. Four times a second the host's game reads its own quests, and when an Epic, Sub or
Request quest moves (the quest starts, one of its tasks is done, or a group of its tasks ends), it sends that quest's
state to the guest. Her game makes the same step through the game's own quest functions, at most one step every
250 ms, when both of these hold:

- she stood in the same zone as the host when the step came;
- her copy of the quest stood where the host's stood before the step.

Her game then runs the step itself: its scenes and events, the next group of tasks, the quest's completion with its
reward, and the next quest, as in solo play. Each player gets a quest's reward once, in their own game. Through shared
quests, the game can unlock a quest trophy on the guest's account only for a step made together, or for one she
forces.

A step the host makes without her (she stood in another zone, or her quest stood at another point) is never given to
her. She gets one notice, `You are behind <name> on <quest>. Finish it in your own game to share it again.`, and plays
that quest herself; once her quest stands where the host's stands, the next step made together is shared again. The
host's game never takes a step from the guest's. When her quest moves past the host's (she talked to a quest giver
alone, for example), both players see a notice, nothing is undone, and the step stays in her save. Quest givers and
the request board still work for the guest, and so do vendors.

Some steps wait in her game:

- A step whose scenes or events act in another zone waits until she stands in one of the zones they act in:
  `<name>'s step on <quest> waits until you reach <zone>.`
- A kill step waits until her own copy of the task is done: she kills the target, or a shared enemy dies in both games
  (`<quest> waits until you kill its target yourself. coop quests force <number> skips that step.`). A forced kill
  step leaves the target alive in her world.
- A Request the host accepted is accepted on her board too once her board offers it. Its tasks follow the host's, then
  it waits until she hands it in at her own request board, where her game gives her the reward and takes the
  delivered items (`<quest> is ready: hand it in at your request board.`).
- A step that the game's tables cannot place in a zone, and that the host's game did not see happen, waits too. She
  plays it herself or forces it.

`coop quests force <number>` makes, where she stands, the step that quest holds for a kill or for a place the tables
cannot give. The number is the one in the kill notice and in `coop quests status`. The command is sent only when typed
twice for the same quest within 10 s, because the game may then unlock that quest's trophies. A step that waits for its
zone, a Request at her board and a quest the host moved without her cannot be forced.

What is shared: the 103 quests of the game's Epic, Sub and Request types, the hidden ones included. Not shared: the
test, tutorial, collectible and helper quests (names starting with `LV_`, `TQ_`, `SQ_` and `CQ_`), the game's one
Instant quest, and failed quests. The host's `quest_deny` adds quests that are never shared, by name or number, for
example `quest_deny=Quest_Epic_14_1, Quest_Epic_14_2`. Notices and logs name a quest by its table name, such as
`Quest_Sub_017`.

When her side comes on, the host sends the state of every quest it moved while linked with her, and only those: steps
from the host's solo play are not sent. Nothing is undone in either game when the session ends; the steps her game made
stay in her co-op save once the game saves. Each player's saved world (opened doors, supply boxes, enemies killed for
good) stays their own, so an enemy the host killed out of her sight is still alive in her world. Both saves should be
on the same New Game Plus cycle: other cycles have not been tested.

Each co-op slot keeps a record beside it in your save folder, `StellarCoopQuests0N.txt` (N the slot), which notes the
steps shared with each friend, as host and as guest. It is a text file, which Steam Cloud does not sync. Without it,
sharing goes on from where both games stand.

`coop quests status` answers with the `quests=` line and writes the whole status into `UE4SS.log` as
`quests_status=<n> ...` lines: the role, the zone, how many steps her game made and how many the game refused, and for
each quest that waits, why (`waits for its zone <zone>`, `waits for your own kill`, `hand it in at your board`, `not on
your board yet`, `unseen by the host`, `behind the host, not shared`, `ahead of the host`), with the quest's number.
`coop-quests.log` in the mod folder logs each step the host sends, each step her game made, held or refused with the
events it starts, and each snapshot. Its stats line each minute counts the quests tracked, the steps made and refused,
the holds by reason and the quests ahead, with the mean and longest time of a pass in microseconds.

- `quests=off`: not asked, or `coop quests off`.
- `quests=waiting mode=on why=friend`: no friend linked. `why=save`: this game does not play a co-op save (a notice
  says so once one of your own saves is loaded). `why=game`: the game's world or quest data is not loaded yet.
- `quests=on mode=on role=<host|guest> partner=<on|off>`: running; `partner=off` while your friend's side is off.
- `quests=stopped`: stopped for this run after an error; the ghost, the link and shared enemies go on.

To test alone on a co-op save, `coop quests record` writes the host's side of your play to `coop-quests-record.txt` in
the mod folder, at most once a second. Load another co-op save whose quests stand before those steps (the load ends the
recording, and the file keeps it), then `coop quests replay` plays the recording into it as the guest's side: each step
goes once you stand in the zone where it was recorded. Loading another save ends a replay too. `coop quests probe` only
reads: it logs what it finds of your quests in `coop-quests.log` and makes no step. `coop quests off` ends any of them.

### `coop off`

`coop off` stops the following until the game restarts, even across a Lua reload: the ghost, EVE's capture, the
loopback, a recording (which is written), a replay, engine reads, the Steam link, the screen notices, the co-op menu,
the chat box, the feed and the partner HUD (the game gets its keys back), the chat history (cleared), a Night Operation
run (it ends as aborted), the Night Operation poller, a recruiter (despawned if one was requested, in Xion), the shared
quests and the photo pause (released; the native tick keeps running for this alone). Afterwards only `coop status` and
`coop report` answer. Every other command answers `STOP: coop off is active until the game restarts`, and so do the
menu, host and leave keys.

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
# Poses sent to your friend a second: 10 to 60.
send_rate=60
# What the ghost shows, each on or off: cloth (her ponytail swings as in solo; on unless set here, and it sends
# nothing), dyes (hair colours and material variants) and effects (her attack and skill effects), both off unless set
# here. dyes and effects off also stop sending yours.
# For example: dyes=on
# Shared enemies, experimental: on or off. On, the enemies you and your friend both fight share one HP bar and one
# death, while both of you play a co-op save. fight_chars: auto (every common enemy, and with bosses=on the bosses
# and Alpha Naytibas) or the enemy character ids to share instead, separated by spaces (coop fight probe logs them),
# for example fight_chars=15011001.
shared_enemies=on
fight_chars=auto
# guest_kills: when you are the guest, at_once (an enemy your hit kills dies at once on your screen) or confirmed (it
# stays at 1 HP until the host's game agrees, about one ping later, so it never dies on your screen alone).
guest_kills=at_once
# Two-player scaling, the host's values for both games (the guest's are not used): enemy_hp_scale multiplies a shared
# enemy's maximum HP, enemy_balance_scale its balance gauge, each from 1.0 (no change) to 4.0. kill_credit is yours:
# a shared enemy dies in your game, with its rewards, drops and achievements, only if you took part in its fight.
# together: you hit it, it targeted you, or you stood within 30 m when it died. fought: you hit it or it targeted you.
enemy_hp_scale=1.35
enemy_balance_scale=1.15
kill_credit=together
# Same place, experimental, the host's for both games: on or off. As guest, yours decides nothing at a start; the
# co-op menu's row can still stop it on your screen, and start it again, while shared enemies wait or run. On, each
# shared enemy stands in the same place on both screens. aggro, the host's too: game (an enemy fights whoever hit it
# last, or else the nearer player) or host (enemies fight the host only).
same_place=on
aggro=game
# Same spawns, experimental, the host's for both games: on or off. On, while both players stand within 100 m of each
# other in one zone, the guest's game adds the common enemies the host's game has there and removes those it lacks.
# Bosses, quest and event enemies, and the enemies a save records, stay as they are.
same_spawns=on
# Extra enemies, experimental, the host's for both games, used only with same_spawns=on: enemy_extra adds 0 to 3 more
# of each common enemy where both players stand within 100 m of each other in one zone, in both games. Each one stands
# 2 to 4 m from its enemy and goes once both players are more than 120 m from it, or when shared enemies stop. Bosses,
# Alpha Naytibas, Elites, quest and event enemies, and the enemies a save records get none.
enemy_extra=0
# Shared bosses, experimental, the host's for both games: on or off. On, a boss or an Alpha Naytiba that both games
# hold shares one HP bar and one death, as a common enemy does. With same_place=on it fights the host only.
# boss_hp_scale, the host's too, multiplies a shared boss's maximum HP in place of enemy_hp_scale, from 1.0 (no change)
# to 4.0.
bosses=on
boss_hp_scale=2.0
# Shared quests, experimental: on or off, off by default. On, while you and your friend both play a co-op save, a
# quest step the host makes while you stand in the same zone, with that quest at the same point in your game, is made
# in your game too (Epic, Sub and Request quests). A step made without you is never given to you; a kill step waits
# for your own kill, and a Request waits until you hand it in at your own request board. quest_deny, the host's: quests
# never shared, by name or number, separated by spaces or commas (for example quest_deny=Quest_Epic_14_1).
shared_quests=off
quest_deny=
# Synced photo mode: while your friend is in photo mode, your game pauses. both: pause and be paused (both PCs need
# both), notice: a notice only, off: nothing. photo_freeze_max: the longest pause in seconds, 30 to 3600, or 0 for no
# limit. photo_ghost: your friend's ghost in your own photos; photo_name_tag: its name tag in them. photo_pause,
# experimental: full (photo mode stops your whole game, as without the mod) or scenery (the game's own experimental
# method: enemies, combat and shared enemies stay stopped while animations, cloth and effects go on moving), from your
# next photo mode.
photo_sync=both
photo_freeze_max=600
photo_ghost=on
photo_name_tag=off
photo_pause=full
# The co-op menu: ui_scale 75 to 150 (%), ui_sounds on or off, ui_language game (the game's language) or english.
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
# status_overlay, a strip above her card: off, compact (the status line and the ping) or detailed (and what is shared).
status_overlay=off
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
| `send_rate` | `10` to `60` poses sent a second | `60` |
| `cloth` | `on` or `off`: her ponytail as cloth on the ghost you see | `on` |
| `dyes` | `on` or `off` | `off` |
| `effects` | `on` or `off` | `off` |
| `shared_enemies` | `on` or `off`: [shared enemies](#shared-enemies-experimental), experimental | `on` |
| `fight_chars` | `auto` (every common enemy), or at most 16 enemy character ids, whole numbers separated by spaces | `auto` |
| `guest_kills` | `at_once` or `confirmed`: as the guest, whether an enemy your hit kills dies at once on your screen or waits for the host's game (see [shared enemies](#shared-enemies-experimental)) | `at_once` |
| `enemy_hp_scale` | `1.0` to `4.0`: the host's multiplier for a shared enemy's maximum HP, used in both games | `1.35` |
| `enemy_balance_scale` | `1.0` to `4.0`: the host's multiplier for a shared enemy's balance gauge, used in both games | `1.15` |
| `kill_credit` | `together` or `fought`: when a shared enemy dies in your game, with its rewards and achievements: you hit it, it targeted you, or (`together` only) you stood within 30 m when it died (see [shared enemies](#shared-enemies-experimental)) | `together` |
| `same_place` | `on` or `off`: [same place](#same-place-experimental), experimental; the host's value counts for both games | `on` |
| `aggro` | `game` or `host`: with same place, whether each enemy fights the player who hit it last (or else the nearer one) or the host only; the host's value counts for both games | `game` |
| `same_spawns` | `on` or `off`: [same spawns](#same-spawns-experimental), experimental; the host's value counts for both games | `on` |
| `enemy_extra` | `0` to `3`: [extra enemies](#extra-enemies-experimental) for each common enemy, experimental, with same spawns only; the host's value counts for both games | `0` |
| `bosses` | `on` or `off`: [shared bosses](#shared-bosses-experimental), experimental; the host's value counts for both games | `on` |
| `boss_hp_scale` | `1.0` to `4.0`: the host's multiplier for a shared boss's maximum HP, used in both games | `2.0` |
| `shared_quests` | `on` or `off`: [shared quests](#shared-quests-experimental), experimental; both players need it on | `off` |
| `quest_deny` | quest names or numbers separated by spaces or commas, at most 200 characters: quests never shared; the host's value counts | empty |
| `photo_sync` | `both`, `notice` or `off`: the [synced photo mode](#synced-photo-mode); a pause needs `both` on both PCs | `both` |
| `photo_freeze_max` | `0` (no limit) or `30` to `3600`: the longest pause your friend's photo mode holds your game in, in seconds | `600` |
| `photo_ghost` | `on` or `off`: your friend's ghost in your own photos | `on` |
| `photo_name_tag` | `on` or `off`: its name tag in your own photos | `off` |
| `ui_scale` | `75` to `150`: the size of the menu, the chat and the partner HUD, in percent | `100` |
| `ui_sounds` | `on` or `off`: the game's UI sounds in the menu, the chat and the partner HUD | `on` |
| `ui_language` | `game` (the game's text language) or `english` | `game` |
| `chat` | `on` or `off`: the [session chat](#session-chat); off hides your friend's lines and sends none | `on` |
| `partner_bar` | `on` or `off`: the [marker](#partner-hud) over your friend's ghost; on, it carries their name instead of the name tag | `on` |
| `partner_arrow` | `on` or `off`: the arrow toward your friend when they are out of view | `on` |
| `partner_card` | `on` or `off`: your friend's card at the top left | `on` |
| `card_details` | `on` or `off`: the ping and your friend's map on the card | `on` |
| `status_overlay` | `off`, `compact` or `detailed`: the [status line](#status-line-above-the-card) above the card | `off` |

Rules:

- `F10` is refused because it opens the console (as does `~`). Function keys do not depend on the keyboard layout.
- Names and values ignore case, a UTF-8 BOM (Notepad) is accepted, and lines starting with `#` are comments. Only the
  first 8192 bytes are read.
- A refused value keeps its default, and `UE4SS.log` gives the reason in a `[StellarCoop] settings:` line. An unknown
  setting is ignored with a note.
- If two actions share one key, all four keys go back to their defaults: `F5` for the menu, `none` to host, `F6` and
  `F8`.
- A file with no `menu_key` line (one written before the menu existed): the menu takes `host_key`'s key, and
  `host_key` counts as `none`. The first `menu_key` that the menu writes into such a file also writes `host_key=none`.
- A file from a version that sent at most 30 poses a second and still says `send_rate=20`, the old default, reads
  60. The mod writes `send_rate=60` and the new comment into it once, keeps the file as it was as
  `coop-settings.old.txt`, and logs a `[StellarCoop] settings:` line. Any other rate stays.
- A file whose same spawns comment says the setting stays off until it has been tested in game was written by a
  development build before 0.4.0-beta.1, with `same_place`, `same_spawns` and `bosses` off. The mod sets each of the
  three that says `off` to `on` and writes the new comment once, keeps the file as it was as `coop-settings.old.txt`,
  and logs a `[StellarCoop] settings:` line. An `off` set after that stays.
- A file written by 0.4.0-beta.1 (its `kill_credit` comment still names `all`) gets `kill_credit=together` in place of
  `all` and the new comment once, keeps the file as it was as `coop-settings.old.txt`, and logs a
  `[StellarCoop] settings:` line. `kill_credit=fought` stays. A hand-written `kill_credit=all` is refused and reads
  `together`.
- The `[StellarCoop] keys:` line gives the keys in use, the name tag and the send rate, for example
  `keys: menu=F5 host=none status=F6 leave=F8, name tag on, 60 poses a second`. Another line says when a mod loaded
  earlier binds the same key; both actions then run. The `[StellarCoop] photo sync:` line gives the photo settings in
  use.

## Looks

Three looks change what the ghost shows. Each is `on` or `off` in `coop-settings.txt`: `cloth` is on by default,
`dyes` and `effects` are off. The file names them in a comment only, so add a line such as `dyes=on` or `cloth=off`,
or change them in the menu's Options > Ghost. A file that already says `cloth=off` keeps it off. `coop look` changes
one until the mod reloads. With one on, the `Ghost ... built` log line ends with `; look: ...`.

The three looks have not been tested in game yet. Back up your saves before you play with one on (see
[saves.md](saves.md)), and turn it off if the game crashes or the ghost looks wrong.

- `cloth`: her ponytail moves as in solo. In solo, the strands you see are an NvCloth simulation of the ponytail mesh,
  pinned at the scalp; the bones that the poses carry only anchor it. Without cloth, the ghost's ponytail follows those
  bones rigidly and looks like one long block. With cloth on, your game runs the same simulation on the ghost's
  ponytail: a follower part whose mesh has clothing assets is drawn as a SkeletalMeshComponent whose cloth simulates on
  its leader's bones, only while the ghost is on screen. It collides with her outfit as in solo: it takes the outfit's
  ponytail collision asset (`<body mesh>_PonytailPhysicsAsset`). If your PC lacks that asset, the build line says
  `outfit collision not used` and the cloth keeps the clothing asset's own collision. Nothing more goes over the
  network. Each PC simulates the ghost it draws, so only the viewer's setting counts, and the strands follow the same
  rules as on her screen without being the same strands. If the cloth part fails, the ponytail is a plain part, with a
  note in the log.
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
it stays off until the next Lua load (`Screen notices off: <why>; notices stay in UE4SS.log.`). That line uses the
engine's default font, which has the Latin-1 characters only. A notice whose words need other letters (Russian,
Polish, Turkish, Arabic, Thai, Chinese, Japanese, Korean) shows there in English, and any character outside Latin-1 in
a Steam name or a chat line shows as `?`.

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
| Co-op copies on with a manual co-op slot N, once a load | `Co-op now plays StellarBladeCoop0N.sav. With the game closed, you can move StellarCoopSlot.txt out of the save folder, and StellarBladeSave0N.sav unless you played it after that copy was made.` |
| Another game version (a game update), on the title screen with `auto_coop_save=ask` or `always`, once a load | `Co-op saves are off: StellarCoop does not support this version of the game. You play your own saves until StellarCoop is updated.` |
| Shared enemies started, stopped, or waiting for something | See [Shared enemies](#shared-enemies-experimental) |
| Same place moving enemies, or stopped | See [Same place](#same-place-experimental) |
| Shared quests on, off or waiting for a co-op save, and quest steps that wait or that were made apart | See [Shared quests](#shared-quests-experimental) |

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
  `friend=<linked 0|1> <lost 0|1> <name>` line, after a [coop mark](#coop-mark) a `mark=<n> ours: <text>` or
  `mark=<n> from <name>: <text>` line (no `: <text>` for a mark with no text), a `mate=<12 numbers>` line with your
  friend's HP, shield, Beta, Burst and Tachy for the partner card (while their last reading is under 3 s old; your own
  during `coop loopback`), and the last 8 notices as `notice=<n> <text>`.
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
- Same place: `pilot=on piloted=<n>`, `pilot=off why=<why>`, `pilot=stopped` or `pilot=refused why=<why>` (see
  [Same place](#same-place-experimental)).
- Shared quests: `quests=off`, `quests=waiting mode=<mode> why=<friend|save|game>`, `quests=on mode=<mode>
  role=<role> partner=<on|off>` or `quests=stopped` (see [Shared quests](#shared-quests-experimental)), then the last 8
  quest notices as `quest_note=<n> <kind> <number> <name> <zone or ->` and the last `coop quests status` answer as
  `quests_status=<n> <line>` lines.
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

Everything the mod writes stays in `Mods/StellarCoop/`, apart from the save folder files listed in
[saves.md](saves.md#what-the-mod-reads-and-writes). An install never removes these files, and
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
| `coop-quests.log` | native | The shared quests' steps made, held and refused, snapshots and stats lines, capped at 4 MB |
| `coop-quests.old.log` | native | The previous run's `coop-quests.log` |
| `coop-quests-record.txt` | native | The last shared quests recording (`coop quests record`) |
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
