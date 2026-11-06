# The co-op menu, chat and HUD

This page describes what the mod adds to the screen and how you use it. The co-op menu opens with F5; its section also
covers the co-op line at camp phone booths, the controller and the mouse, and the Options pages. The other parts are the
session chat, your friend's card on the HUD, the guide that opens at the mod's first run, the extra tabs of the teleport
screen and the notices. The keys and console commands are in [usage.md](usage.md), and the settings file that the
Options pages write is in [settings.md](settings.md). How the menu takes the game's input is in
[internals/architecture.md](internals/architecture.md#the-co-op-uis-input).

## Co-op menu

F5 opens the co-op menu on the left of the screen, and so does View held for 1 s on a [controller](#controller). It
opens in a world only: not on the title screen, not while the game is paused or shows the mouse cursor for one of its
own screens, and not during your own photo mode. While the menu is open, the game ignores its own keys and controller
buttons, so EVE stands still.

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
| Copy my code | While you host with a [join code](playing-with-a-friend.md#join-codes) | Shows the code and runs `coop copy`, which puts it on the clipboard |
| Remove <name> | While a player who is not your Steam friend is in the session you host | Runs `coop remove <SteamID>` when you select it a second time within 3 s |
| Join a friend | Outside a session | Runs `coop join` |
| Join with a code | Outside a session | Closes the menu and opens the [code box](playing-with-a-friend.md#join-codes) |
| Chat | During a session, with chat on | Closes the menu and opens the [chat](#session-chat) box |
| Options | Always | Opens the settings, below |
| Guide | Always | Closes the menu and opens the [guide](#guide) on its first page |
| Write a bug report | Always | Runs `coop report` |
| Close | Always | Closes the menu |

Under the rows, a status line shows the F6 text and, once your friend is linked, their ping. Below it the menu shows its
own messages, such as `Select again within 3 s to leave.`, or, while it covers the [feed](#session-chat), the newest
notice under 8 s old (for example the result of Join a friend). If the session ends or the player leaves in the 3 s
between the two selects of Leave the session or Remove <name>, the second select runs nothing. The menu closes by itself
when the game pauses or shows the mouse cursor for one of its own screens.

### Co-op line

The camp phone booths open a short page of the menu, the co-op line. The booths are the phone booth of every full camp,
Xion's five booths and the warp phones of the Wasteland and the Great Desert. Tetrapods are not booths here. Within 3 m
of a booth, a hint at the bottom centre of the screen shows the menu key's name and `Co-op line`, and the menu key opens
the line instead of the main page. The hint hides while the menu is open, while the game is paused or shows the mouse
cursor, and while the chat box, the code box, the host's question or the co-op saves' question is open. The hint and the
line use the menu's language.

The line has a CO-OP LINE header, the main page's session rows that fit your session, then Co-op menu and Hang up.
Under them are the status line and a sentence about the line:

| Session | Session rows | Sentence |
| --- | --- | --- |
| None | Host a session, Join a friend, Join with a code | `The line is free. Host a session or join a friend.` |
| You host | Invite a friend (Steam), Copy my code and Remove <name> when the main page shows them, Leave the session | `Your session is open. Invite a friend from here.`, or `On the line with <name>.` while your friend is linked |
| You joined | Leave the session | `On the line with <name>.` while you are linked, none while connecting or after a connection loss |
| Steam not ready yet | none | none |

The session rows work as on the main page: Host a session and Invite a friend close the line first, Join with a code
opens the code box, and Leave the session and Remove <name> run on a second Select within 3 s. Co-op menu switches to
the main page, where Chat, Options and the bug report are. Hang up, Esc and the menu key close the line. A message of
the menu, such as `Select again within 3 s to leave.`, or a notice under 8 s old shows in place of the sentence.

The booth keeps its own interaction: the game's Fast travel prompt still shows, and using the booth with the game's key
travels and saves as it does without the mod. The line works on any save, as the menu does, and changes nothing in the
game. Away from a booth, the menu key opens the main page as before. Each time the line opens, `UE4SS.log` names the
booth, for example `line: booth Xion_10_EnvS_016 (Env_Camp_TeleportMachine_C) at 1.8 m`.

### Controller

A controller drives the co-op menu and the [co-op saves' question](playing-with-a-friend.md#co-op-saves). Hold View (Back on an Xbox 360
pad) for 1 s to open the menu, in a world with the game's HUD shown, and hold it again to close the menu. View is also
the game's Scan button, and the game still gets the press that opens the menu. The controller in the menu has not been
tested in game yet.

| Button | In the menu |
| --- | --- |
| D-pad or left stick, up or down | Up or down; held, it repeats after 0.4 s, then every 0.12 s |
| D-pad or left stick, left or right | Previous or next value of a setting, once a press |
| A | Select |
| B | Back, then close |
| View held 1 s | Close |

- A D-pad diagonal counts as up or down. The stick counts along the axis it is pushed further on (up or down when both
  are equal), as pressed past half of its range and as released under 30 %. Once an axis counts, it keeps counting
  until the other one is pushed more than 10 % further.
- The mod reads the controller only while the game's window is in front.
- While a key row waits for a key, only B acts: it stops the wait. A new key has to come from the keyboard.
- B closes the [chat](#session-chat) box and the [code box](playing-with-a-friend.md#join-codes) as Esc does: nothing is typed or sent. A
  controller cannot type in them.
- The host's question (`<name> wants to join`) takes no controller input. A is Jump and the D-pad uses heal and
  utility items in a fight, so a press meant for the game must never let a stranger in. Answer it with the keyboard;
  with no answer, the player is refused after 60 s.
- The key hints at the bottom of the menu show the keyboard keys.

The native part reads XInput: Xbox controllers, the Steam Deck, and any controller under Steam Input. A DualSense
that the game reads through its own PlayStation support is not an XInput controller, so the mod does not see it. Turn
Steam Input on for Stellar Blade (Steam, right-click the game, Properties, Controller) to use it in the menu.
`coop-link.log` says at start and at each change which controllers it sees: `pad: XInput pads connected: 0` (the
slots, 0 to 3), `pad: no XInput pad`, or `pad: no XInput in System32: no controller in the co-op menu`. `UE4SS.log`
says `[StellarCoop] pad: menu` each time a View hold asks to open or close the menu. With an older `StellarCoop.dll`
it says `Native pad unavailable (no controller in the co-op menu): <why>` once, and the keyboard works as before.

### Mouse

While the menu is open, it shows the mouse cursor. The row you move the mouse onto takes the focus (the mouse is read
every 100 ms, and a mouse at rest never takes the focus back from the keys). A left click selects the row under the
mouse, as Enter does: Leave the session and Remove <name> still need a second click within 3 s. A right click goes
back, then closes the menu. A click on a heading or on no row does nothing. On the Options page, the mouse on the first
or last row shown scrolls the page by one row. While a key row waits for a key, the mouse moves nothing. The mouse in
the menu has not been tested in game yet.

The cursor goes when the menu closes, and also after `coop ui reset`, `coop off` and a Ctrl+R with the menu open. While
the menu is closed, the mouse buttons are the game's. The middle and side buttons stay the game's even with the menu
open; a click with one of them can take the focus from the menu, which the [focus watchdog](#focus-watchdog) then
closes.

### Options

Each row of the Options page is a setting of [coop-settings.txt](settings.md#coop-settingstxt). The rows are in groups: Controls
(the menu, status, leave, travel and race checkpoint keys), Photo mode, Partner (the name tag and the
[partner HUD](#partner-hud)), Ghost (the looks, the [solid partner](ghost.md#solid-partner-experimental) and the send rate),
Session (who can join a session you host, the [revive](playing-with-a-friend.md#revive-by-your-friend-experimental), the
[cutscene wait](playing-with-a-friend.md#cutscene-wait) and [following the host](playing-with-a-friend.md#following-the-host)), Saves (the [co-op saves](playing-with-a-friend.md#co-op-saves)
at the title and [shared quests](playing-with-a-friend.md#shared-quests-experimental)), Combat (shared enemies, same place, who same-place
enemies attack, same spawns, extra enemies, shared bosses, the host's enemy and boss scaling and your kill rewards),
Display (the [status strip](#status-strip-above-the-card) above the partner card, and the size, sounds and language of
the menu, the chat and the partner HUD) and Chat.

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

The menu, the guide, the chat, the partner HUD, the code box, the host's question, the co-op saves' question and
notices, the shared enemies', same place, same spawns and shared quests notices, Night Operation's card, result panel
and notices, and the Doro race's panel, banners, results and notices use the game's text language, any of the 23 that
the game ships. So do the status line (under the menu and on F6) and the ghost's notices. `ui_language=english` keeps
them all in English. The notices of the Steam link (a friend joined or left, your join code) and `UE4SS.log` stay in
English, and so do the error messages from the coop commands, shown in the menu or the code box.

If the menu or the chat box ever leaves the game without its own keys, open the console (F10 or `~`) and type
`coop ui reset`: the menu and the boxes close, an open [host's question](playing-with-a-friend.md#join-codes) is answered with Deny, and the
game gets its keys back. `coop ui off` removes the co-op menu, the chat box, the code box, the host's question, the
feed, the partner HUD, Night Operation's card and result panel and the co-op saves' question until the mod reloads (game
start or Ctrl+R). Notices then go back to the line above your EVE, and your friend's name back to the name tag above
their ghost. With the UI off, `auto_coop_save=ask` plays your own saves and `always` still switches to the copies.

### Focus watchdog

While the menu, the chat box, the code box, the host's question or the co-op saves' question holds the game's keys,
the mod checks every 250 ms that the keyboard focus is still on its UI. When something else has kept the focus for 1 s
(one of the game's screens, another mod, a window switch that does not give the focus back), the mod does what
`coop ui reset` does: the menu and the boxes close, an open host's question is answered with Deny, the co-op saves'
question closes as Decide later, the mouse cursor goes, and the game gets its keys back at once. One difference: if you
already chose co-op and the copies are being made, that choice stays, and the result shows as a notice when the copy
ends. Nothing else shows on screen. `UE4SS.log` says `[StellarCoop] focus watchdog: <who> lost the focus for 1 s: co-op
UI closed, the game has its input back`, where who is `menu`, `chat`, `code`, `ask` (the host's question) or `saves`.
The watchdog has not been tested in game yet.

- The Steam overlay (Shift+Tab) should leave the focus where it was and then not trip the watchdog (not tested in
  game yet).
- A left or right click on none of the mod's widgets moves the focus to the game. The mod puts it back 50 ms later and
  starts the second over, so such a click closes nothing.
- The watchdog starts once it has seen the focus on the mod's UI. If that has not happened 2 s after the UI took the
  keys, `focus watchdog: our root never took the focus` shows once until the mod reloads, and nothing closes by itself.
  `focus watchdog off: the UI root refused bIsFocusable (<why>)` means it is off until the mod reloads.

## Session chat

During a session (or `coop loopback`), Enter opens a text box at the top left of the screen, under the feed. It opens
in a world only, and not while the game is paused or shows the mouse cursor for one of its own screens. While the box
is open, the game ignores its own keys, so EVE stands still, and the mod's keys (F5, F6, F8) do nothing. If the game
pauses or shows the mouse cursor while the box is open (EVE dies, or your friend's photo mode pauses your game), the
box closes and what you typed is lost. Alt+Enter never opens it.

| Key | In the chat box |
| --- | --- |
| Enter | Send the line; on an empty line, close the box |
| Esc, or B on a [controller](#controller) | Close the box; what you typed is lost |

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
- `chat=off` in [coop-settings.txt](settings.md#coop-settingstxt), or Options > Chat, hides your friend's lines and sends none.
  Enter then shows `Chat is off (Options > Chat).`
- The history is kept in memory only, 50 lines at most. It is cleared when the session ends, at `coop off` and when
  the mod reloads (game start or Ctrl+R). Chat text never goes into a log, a report or the console, and its two files
  exist for a moment only (see [Files in the mod folder](settings.md#files-in-the-mod-folder)). A crash or a forced kill can leave
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

### Status strip above the card

Options > Display > Status line (`status_overlay`) adds a status strip above the card: Off (the default), Compact or
Detailed. Each player's setting is their own, and a change shows at once. The strip shows whenever the
[status line](usage.md#the-status-key-f6) says something other than `not in a session` or `waiting for Steam`: while you host
(alone too), while a friend connects or you play in their game, while an invite is held or you rejoin, and after the
Steam link stopped.

- Compact: the status line without its `Co-op:` start, and the ping at the right end, for example `hosting Alex.` and
  `118 ms`. While the link is lost, the row starts with `connection lost`, turns red and shows no ping.
- Detailed: the same, and a second row with what is shared now: `Enemies <n>` while shared enemies run (the `enemies=`
  count of `coop fight status` as host, `pairs=` as guest), `Same place <n>` while same place runs (`piloted=`),
  `Quests on` while shared quests run, and the poses you send a second. For example
  `Enemies 3 · Same place 2 · Quests on · 60/s`.

A row too long for the strip ends with `…`. The strip uses the menu's language. It grows with `ui_scale` up to 100 %
only, so it never covers the card, and it hides when the card does: while the game is paused (your friend's photo mode
included) or shows one of its own screens, and in your own photo mode.

## Guide

The guide has nine pages on what the mod adds, with the Mother Sphere art by timediffer24 on the left. At the mod's
first run it opens on the title screen once the on-screen UI has loaded, and the [co-op saves](playing-with-a-friend.md#co-op-saves) question
waits until it closes. You can open it again from the co-op menu's Guide row or with `coop guide`, on the title screen
or in the world, but not while the game is paused or shows one of its own screens, and not while the co-op saves'
question, the host's question, the chat box or the code box is open.

| Key | In the guide |
| --- | --- |
| Left arrow, A or Q | Previous page |
| Right arrow or D | Next page |
| Up arrow, W or Z; D-pad or left stick up | Up |
| Down arrow or S; D-pad or left stick down | Down |
| Enter or Space; A | Select |
| Esc; B | Close |
| Mouse | The row under the mouse takes the focus; a left click selects it |

The rows are Next, Back, Don't show again and Close. For 1 s after the guide opens, Enter, Space, A and a click do
nothing. Don't show again, or a close on the last page, writes `coop-guide.txt` in the mod folder, and while that file
exists the guide does not open by itself. Delete it to see the guide at the next start. With no key for 3 minutes the
guide closes, so a controller the mod cannot read does not keep you on it. If the art does not load, `UE4SS.log` says
why and the guide shows without it.

## Teleport screen

The game's between-regions teleport screen has 7 tabs and drops every active Tetrapod past the 7th. The mod adds up to 2
more tabs, so it shows up to 9 regions, in the game's own order. Holding on a tab travels as on the game's own tabs, with
the mouse, the keyboard or a gamepad. Tabs without a region stay hidden.

8 tabs fit on the screen. With 9, a horizontal bar appears under the row: drag it with the mouse or use the wheel. With
the keyboard or a gamepad, moving left and right should follow the focus. A region past the 9th still does not show.
Added tabs appear at once, without the game's fade-in.

The screen writes nothing to your save and unlocks no trophy. After `coop off`, or if a check fails, the screen goes back to the game's 7
tabs. Screens already open keep their tabs until they close. These lines tell you what happened:

- `coop-link.log`: `region tabs on: 0x145c3eb38 swapped from the Region logic's init to our hook` at start, and
  `region tabs: <n> records added, <n> in the list, <n> tabs in the Region logic` once, for the first screen opened. With
  0 records added on a screen that opened with the mod's hooks on, the screen was built in another order than expected.
- `coop-link.log`: `region tabs refused: ...` means another mod holds that pointer or its page would not change.
  `region tabs fault ...: off for this run` means a fault in the mod's hook. The screen keeps its 7 tabs in both cases.
- `UE4SS.log`: `[RT] hooks on: ...` once a Lua load, or `[RT] STOP: <why>; the teleport screen keeps its 7 tabs until the
  mod reloads`.

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
| [Following the host](playing-with-a-friend.md#following-the-host) (guest) | `<host> is in <map>. Press F7 to travel to the camp nearest them.`, `Following <host> in 5 s. Press F7 to stay.`, `Travelling to <host>.`, `No camp you have found is near <host>.`, `You cannot travel now. Try again in a moment.` or `The travel did not start. UE4SS.log says why.` |
| Your friend down | `<name> is down. Stand next to them for 3 s to revive them.`, then `You revived <name>.` when they get up next to you |
| You down, with your friend alive on your map | `<name> can revive you: wait, or respawn at a camp.`, then `Revived by <name>.` ([revive](playing-with-a-friend.md#revive-by-your-friend-experimental)) |
| A camp rest in a shared area (guest) | `Enemies are back: the area reset in <host>'s game.` or `Shared area: only <host>'s camp rest brings its enemies back.` |
| The host's cutscene (guest) | `<host> is watching a cutscene. Your game waits until it ends.` |
| Ghost failed 3 times on one table | `Ghost failed 3 times: the reason is in UE4SS.log.` |
| Your friend's photo mode pauses you | `<name> is taking photos: game paused. Esc > Photo Mode to join in.`, then `Game resumed.` or `Paused for <n> min: game resumed.` (`photo_freeze_max`) |
| Your friend's photo mode, no pause | `<name> is taking photos.` (your `photo_sync=notice`), `<name> is taking photos (their photo sync gives notices only).` or `<name> is taking a selfie.` |
| Your photo mode | Once a session, `<name>'s game does not pause for photos.` (shown when you leave photo mode) |
| The photo pause failed | `Photo sync can no longer pause this game: notices only until the game restarts.` |
| Co-op saves switched on | `Co-op saves on: you play co-op copies of your saves. Your own saves are not changed.` |
| Co-op saves not switched on (`auto_coop_save=always`, or the title screen left while the copies were made) | `Co-op saves off for this load: <why>. You play your own saves.` |
| Co-op copies on with a manual co-op slot N, once a load | `Co-op now plays StellarBladeCoop0N.sav. With the game closed, you can move StellarCoopSlot.txt out of the save folder, and StellarBladeSave0N.sav unless you played it after that copy was made.` |
| Another game version (a game update), on the title screen with `auto_coop_save=ask` or `always`, once a load | `Co-op saves are off: StellarCoop does not support this version of the game. You play your own saves until StellarCoop is updated.` |
| Your friend's `.pak` mods differ from yours, once a session | `<name> uses mods you don't have: <mods>. ...`, `<name> uses other versions of mods you have: <mods>. ...` or `<name> loads other .pak mods than you (<n> there, <n> here). ...`; see [Shared enemies](shared-enemies.md#shared-enemies-experimental) |
| Shared enemies started, stopped, or waiting for something | See [Shared enemies](shared-enemies.md#shared-enemies-experimental) |
| Same place moving enemies, or stopped | See [Same place](shared-enemies.md#same-place-experimental) |
| Shared quests on, off or waiting for a co-op save, and quest steps that wait or that were made apart | See [Shared quests](playing-with-a-friend.md#shared-quests-experimental) |
| Night Operation: a partner's run starting, a partner who cannot join, the points a run gave | See [night-operation.md](night-operation.md#the-co-op-run) and [the reward shop](night-operation-shop.md) |
