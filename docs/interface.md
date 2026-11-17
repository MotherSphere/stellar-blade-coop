# The co-op menu, chat and HUD

The keys and console commands are in [Keys and commands](usage.md), and the settings file that the Options pages write
is in [Settings](settings.md). How the menu takes the game's input is in
[Architecture](internals/architecture.md#the-co-op-uis-input).

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
| Host a session | Outside a session | Closes the menu and opens the [Create a session screen](#create-a-session-screen), where Start hosts |
| Leave the session | In a session | Runs `coop leave` when you select it a second time within 3 s |
| Invite a friend (Steam) | While you host | Runs `coop invite`. The menu closes first. |
| Copy my code | While you host with a [join code](playing-with-a-friend.md#join-codes) | Shows the code and runs `coop copy`, which puts it on the clipboard |
| Remove <name> | While a player who is not your Steam friend is in the session you host | Runs `coop remove <SteamID>` when you select it a second time within 3 s. The player goes on your [block list](playing-with-a-friend.md#block-list) too. |
| Find a session | Outside a session | Closes the menu and opens the [Sessions screen](#sessions-screen) |
| Join with a code | Outside a session | Closes the menu and opens the [code box](playing-with-a-friend.md#join-codes) |
| Chat | During a session, with chat on | Closes the menu and opens the [chat](#session-chat) box |
| Options | Always | Opens the settings, below |
| Guide | Always | Closes the menu and opens the [guide](#guide) on its first page |
| Write a bug report | Always | Runs `coop report` |
| Close | Always | Closes the menu |

Under the rows, a status line shows the F6 text and, once your friend is linked, their ping. Below it the menu shows its
own messages, such as `Select again within 3 s to leave.`, or, while it covers the [feed](#session-chat), the newest
notice under 8 s old (for example a join that Steam refused). If the session ends or the player leaves in the 3 s
between the two selects of Leave the session or Remove <name>, the second select runs nothing. The menu closes by itself
when the game pauses or shows the mouse cursor for one of its own screens.

### Co-op line

The camp phone booths open a short page of the menu, the co-op line. The booths are the phone booth of every full camp,
Xion's five booths and the warp phones of the Wasteland and the Great Desert. Tetrapods are not booths here. Within 3 m
of a booth, a hint at the bottom centre of the screen shows the menu key's name and `Co-op line`, and the menu key opens
the line instead of the main page. The hint hides while the menu is open or the game is paused or shows the mouse
cursor. It also hides while the chat box, the code box, a [join popup](#join-popups) or the co-op saves' question is
open. The hint and the line use the menu's language.

The line has a CO-OP LINE header, the main page's session rows that fit your session, then Co-op menu and Hang up.
Under them are the status line and a sentence about the line:

| Session | Session rows | Sentence |
| --- | --- | --- |
| None | Host a session, Find a session, Join with a code | `The line is free. Host a session or join a friend.` |
| You host | Invite a friend (Steam), Copy my code and Remove <name> when the main page shows them, Leave the session | `Your session is open. Invite a friend from here.`, or `On the line with <name>.` while your friend is linked |
| You joined | Leave the session | `On the line with <name>.` while you are linked, none while connecting or after a connection loss |
| Steam not ready yet | none | none |

The session rows work as on the main page: Host a session opens the [Create a session screen](#create-a-session-screen)
and Invite a friend closes the line first. Find a session opens the [Sessions screen](#sessions-screen) and Join with a
code opens the code box. Leave the session and Remove <name> run
on a second Select within 3 s. Co-op menu switches to the main page, where Chat, Options and the bug report are. Hang
up, Esc and the menu key close the line. A message of the menu, such as `Select again within 3 s to leave.`, or a notice
under 8 s old shows in place of the sentence.

The booth keeps its own interaction: the game's Fast travel prompt still shows, and using the booth with the game's key
travels and saves as it does without the mod. The line works on any save, as the menu does, and changes nothing in the
game. Away from a booth, the menu key opens the main page as before. Each time the line opens, `UE4SS.log` names the
booth, for example `line: booth Xion_10_EnvS_016 (Env_Camp_TeleportMachine_C) at 1.8 m`.

### Create a session screen

Host a session closes the menu and opens the Create a session screen, drawn with the game's own setting rows, headers
and key hints. `coop host` typed alone opens it too. Nothing is hosted until you select Start.

| Row | Shown | What it sets |
| --- | --- | --- |
| Who can join | Always | Public, Friends only, Invitation or Private (`who_can_join`, see [Settings](settings.md)) |
| Friends join without asking | Under Public and Invitation | On lets your Steam friends in at once. Off makes them wait for your answer like other players (`friends_ask=on`). |
| Shared enemies | Always, under SESSION RULES | [Shared enemies](shared-enemies.md) on or off |
| Same place, Same spawns, Extra enemies, Shared bosses, Enemy HP, Boss HP, Enemies attack | While Shared enemies is On | The same values as on the Options page |
| Shared world, Shared quests, Friend can revive me | Always | On or Off |
| Start | Always | Closes the screen and hosts with the Who can join value shown |
| Back | Always | Closes the screen without hosting |

Each setting row is the Options page's own setting. A change rewrites that setting's line in `coop-settings.txt` and
applies as it does from the Options page, so the screen opens on the values in effect and the Options page shows the
same values. The right pane names the focused row. On Who can join it also says in one sentence who can join with that
value. What each value does once you host is in [Playing with a friend](playing-with-a-friend.md).

If `coop-settings.txt` cannot be read, every setting row shows the game's locked look and the right pane says
`coop-settings.txt cannot be read: this setting cannot change now.` Start still hosts with the values in effect.

| Key | Controller | On the Create a session screen |
| --- | --- | --- |
| Up arrow, W or Z; down arrow or S | D-pad or left stick, up or down | Move |
| Left arrow, A or Q; right arrow or D | D-pad or left stick, left or right | Previous or next value |
| Enter or Space | A | Next value; on Start, host; on Back, close |
| Esc, F5 | B, View held 1 s | Close without hosting |

The row you move the mouse onto takes the focus, a left click on a row does what Enter does and a right click closes
the screen.

The screen opens where the co-op menu would (in a world, the game not paused) and only while you are in no lobby. Where
it cannot open, `coop host` hosts at once with `who_can_join` as before. While you host, it opens the Steam invite
dialog again, or says `Nobody can join a private session.` in a Private one. `coop host public` (or `friends`,
`invitation`, `closed`) and `host_key` always host at once. The screen closes by itself outside a world, when the game
pauses or shows the mouse cursor for one of its own screens, when the UI turns off and once you are in a lobby (after an
invite you accepted, for example). `coop ui reset` and the [focus watchdog](#focus-watchdog) close it too.

If one of the game's widgets cannot be made, the screen draws the same rows, headers and hints with the menu's own
parts. `UE4SS.log` then says `[StellarCoop][UI] create: part <class>: <why>; left out until the mod reloads` once. It
also says `[StellarCoop][UI] create: open`, `create: start <word>` and `create: closed`. Each change logs
`[StellarCoop] menu: <setting>=<value> saved in coop-settings.txt`. Start then logs `[StellarCoop] OK: asked the
native part: host <word>`. The Create a session screen has not been tested in game yet.

### Sessions screen

Find a session closes the menu and opens the Sessions screen, drawn with the game's own setting rows, headers and key
hints. It lists the open online sessions of players on your version of the mod and of the game, in two tabs:

- Public: the sessions hosted with Who can join set to Public.
- Friends (the game's own word, Comrades in English): the sessions your Steam friends host with Public or Friends only.

Sessions hosted with Invitation or Private never show. Full sessions do not show either. Nor do sessions of another
protocol or game build, sessions hosted by a player you blocked on Steam or on your
[block list](playing-with-a-friend.md#block-list), or your own. A tab holds 50 rows at most, sorted by ping, best
first, rows with no ping last.

Each row shows the host's Steam name, then the region, the players (`1/2`) and the ping. Eight rows show at once and
the list scrolls with the focus. The right pane shows the focused row: the host's name, the region, the travel camp
nearest the host, the players and ping, the [session rules](settings.md) the host has on (shared enemies, shared
bosses with the boss HP scale, shared world, shared quests, the revive), `Steam friend` when the host is one, then the
version. The bottom left names your own protocol and game build, which a session must share to show. A region shows
in the game's words for the story regions; another map shows its short name, such as `f01`.

The screen asks Steam for a search when it opens, when you change tabs and on Refresh. One search runs at a time, at
least 5 s after the last one, never by itself. Refresh while a search runs stops it; its key hint then reads Cancel. The
line under the rows says what the search is doing: the game's `Searching for team members`, `No open session.`, `The
search failed. Refresh to try again.`, `Press Refresh to search.` (the other tab was searched last) or `You can search
again in <n> s.`

Select on a row asks to join that session at once and closes the screen. A Steam friend of the host gets in at once,
unless the host set Friends join without asking to Off. Anyone else waits until the host accepts or denies them (see
[Asking to join](playing-with-a-friend.md#asking-to-join)).

| Key | Controller | On the Sessions screen |
| --- | --- | --- |
| Up arrow, W or Z; down arrow or S | D-pad or left stick, up or down | Move |
| Q (A on an AZERTY keyboard), E | LB, RB | Public or Friends tab |
| R | Y | Refresh, or stop the search that runs |
| Enter or Space | A | Ask to join the focused session |
| Esc, F5 | B, View held 1 s | Close |

The row you move the mouse onto takes the focus, a left click on a row asks to join it and a left click on a tab opens
that tab. A right click closes the screen. The screen closes by itself outside a world, when the game pauses or
shows the mouse cursor for one of its own screens, when the UI turns off and once you are in a lobby. `coop ui reset`
and the [focus watchdog](#focus-watchdog) close it too. Its words follow the menu's language; the game's own words
(Comrades, the search line, Cancel, the regions and camps) come from the game in its text language. With
`ui_language=english` the screen shows SBO's English words in their place: Friends only, `Searching…`, Cancel and the
maps' short names, with no camp.

If one of the game's widgets cannot be made, the screen draws the same rows, headers and hints with the menu's own
parts. `UE4SS.log` then says `[StellarCoop][UI] sessions: part <class>: <why>; left out until the mod reloads` once.
It also says `[StellarCoop][UI] sessions: open public` (or `friends`), `sessions: ask to join lobby <id>` and
`sessions: closed`. Each search shows as `[StellarCoop] OK: asked the native part: list public`. The console's
`coop list` and `coop join <row>` read the same list ([Keys and commands](usage.md)). The Sessions screen has not been
tested in game yet.

### Join popups

The host's question (a player asks to join your online session) and the joiner's wait (you joined a host who asks)
show in the game's own popup, the one it uses for its yes or no questions.
[Asking to join](playing-with-a-friend.md#asking-to-join) says who waits for an answer.

| Popup | Title | Text | Buttons |
| --- | --- | --- | --- |
| The host's question | `<name> wants to join` | `They wait for your answer before they enter your game.` `Declined in <n> s if you do not answer.` | The game's Accept and Decline. Decline has the focus. |
| The joiner's wait | `Waiting for <host>'s answer` | `Close cancels your request to join.` `The host has <n> s left to answer.` | The game's Close |

The buttons read the game's own words in its text language (Accept, Deny and Close with `ui_language=english`). The
titles and texts follow the menu's language. The seconds count down while the popup shows. A Steam name is cut to 16
characters and loses any `<` or `>` (the popup would read them as a text style tag). The host's game plays the game's
alert when a player first asks. Each popup then plays the game's own popup sounds: one as it opens, one on Accept or a
let in, one on Decline or Close (none with `ui_sounds=off`).

The Up and Down arrows move between Accept and Decline, Enter answers and Esc declines. On the joiner's wait, Enter or
Esc closes the popup and leaves the host's lobby. For 1 s after a popup shows, every key does nothing. A popup takes no
mouse click and no controller input. It opens in a world only and closes the co-op menu as it opens. It waits while the
game is paused or the chat box is open.

If the game's popup cannot be made, a panel of the mod in the middle of the screen shows the same words with Accept
and Deny rows (one Close row on the joiner's wait). `UE4SS.log` then says
`[StellarCoop][UI] join: part WB_Common_Popup_C: <why>; left out until the mod reloads` once. A call the popup refuses
is logged once as `[StellarCoop][UI] join: popup <what> refused: <why>`. The join popups have not been tested in game
yet.

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
- While a key row waits for a key, only A and B act: A puts back that key's default and B stops the wait. A new key
  has to come from the keyboard.
- B closes the [chat](#session-chat) box and the [code box](playing-with-a-friend.md#join-codes) as Esc does: nothing is typed or sent. A
  controller cannot type in them.
- The [join popups](#join-popups) take no controller input. A is Jump and the D-pad uses heal and utility items in a
  fight, so a press meant for the game must never let a stranger in. Answer the host's question with the keyboard;
  with no answer, the player is refused after 60 s. The joiner's wait ends with the host's answer or that refusal.
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
mouse, as Enter does: Leave the session, Remove <name> and Reset all keys still need a second click within 3 s. A right click goes
back, then closes the menu. A click on a heading or on no row does nothing. On the Options page, the mouse on the first
or last row shown scrolls the page by one row. While a key row waits for a key, the mouse moves nothing. The mouse in
the menu has not been tested in game yet.

The cursor goes when the menu closes, and also after `coop ui reset`, `coop off` and a Ctrl+R with the menu open. While
the menu is closed, the mouse buttons are the game's. The middle and side buttons stay the game's even with the menu
open; a click with one of them can take the focus from the menu, which the [focus watchdog](#focus-watchdog) then
closes.

### Options

Each row of the Options page is a setting of [coop-settings.txt](settings.md#coop-settingstxt), except Reset all keys.
The rows are in groups: Controls (the menu, status, leave, travel and race checkpoint keys, then Reset all keys), Photo
mode, Partner (the name tag and the [partner HUD](#partner-hud)), Ghost (the looks, the
[solid partner](ghost.md#solid-partner-experimental) and the send rate), Session (who can join a session you host and
whether your Steam friends join without asking, the
[revive](playing-with-a-friend.md#revive-by-your-friend-experimental), the
[cutscene wait](playing-with-a-friend.md#cutscene-wait),
[following the host](playing-with-a-friend.md#following-the-host) and the [shared world](shared-world.md)), Saves (the
[co-op saves](playing-with-a-friend.md#co-op-saves) at the title and
[shared quests](playing-with-a-friend.md#shared-quests-experimental)), Combat (shared enemies, same place, who
same-place enemies attack, same spawns, extra enemies, shared bosses, the host's enemy and boss scaling and your kill
rewards), Display (the [status strip](#status-strip-above-the-card) above the partner card; the size, sounds and
language of the menu, the chat and the partner HUD) and Chat.

Left and right change a value, and Enter does the same as right. Each change rewrites only that setting's line in
`coop-settings.txt`; comments and other lines stay as they are. Reset all keys rewrites the line of every key setting
(`host_key` included) and adds those the file lacks. The first change since the mod loaded keeps the file as
it was as `coop-settings.old.txt`. A change applies at once, except for the name tag, which says `Saved. It takes effect
when the mod reloads (game start or Ctrl+R).`, and the Enemies attack, Same spawns, Extra enemies, Shared bosses,
scaling and kill reward rows, which
count from the next time shared enemies start (turn the Shared enemies row off and on again, or restart the game). The
Same place row applies at once while shared enemies wait or run, and otherwise from their next start (as guest, only
while they wait or run, and only on your screen).

To change a key, select its row, then press the new key: `F1` to `F12` except `F10`, alone or with Shift, Ctrl or Alt.
A key that another action already holds is refused: the menu names that action. Esc stops waiting. Enter (or Space)
puts back that key's default; while the row waits, the Enter key hint reads Default. The default is refused the same
way when another action holds it. Reset all keys, the last row of Controls, puts every key back to its default on a
second Select within 3 s: `F5` for the menu, `F6` for the status, `F8` to leave, `F7` to travel, `F9` for race
checkpoints and `none` for `host_key`, which has no row. The new keys work at once. The console command
`coop keys reset` does the same.

The menu, the Sessions and Create a session screens, the guide, the chat, the partner HUD, the code box, the join
popups, the co-op saves' question and notices, the shared enemies', same place, same spawns and shared quests notices,
Night Operation's card, result panel and notices as well as the Doro race's panel, banners, results and notices use the
game's text language, any of the 23 that the game ships. So do the status line (under the menu and on F6), the ghost's
notices and the notices of a join Steam refused (`Could not join: ...`). `ui_language=english` keeps them all in
English. Without it, a player who joined or left shows in the feed in the game's own words
(`<name> has joined the game.`, `<name> has left the game.`). The other notices of the Steam link (your join code, for
example) and `UE4SS.log` stay in English. So do the error messages from the coop commands, shown in the menu or the code
box.

If the menu or the chat box ever leaves the game without its own keys, open the console (F10 or `~`) and type
`coop ui reset`: the menu, the Sessions and Create a session screens and the boxes close, an open
[host's question](playing-with-a-friend.md#asking-to-join) is answered with Deny, a joiner's wait popup hides (the
player still waits in the lobby) and the game gets its keys back. `coop ui off` removes the co-op menu, the Sessions and
Create a session screens, the chat box, the code box, the join popups, the feed, the partner HUD, Night Operation's card
and result panel and the co-op saves' question until the mod reloads (game start or Ctrl+R). Notices then go back to the
line above your EVE. Your friend's name goes back to the name tag above their ghost. With the UI off,
`auto_coop_save=ask` plays your own saves and `always` still switches to the copies.

### Focus watchdog

While the menu, the Sessions or Create a session screen, the chat box, the code box, a join popup or the co-op saves'
question holds the game's keys, the mod checks every 250 ms that the keyboard focus is still on its UI. When something
else has kept the focus for 1 s (one of the game's screens, another mod, a window switch that does not give the focus
back), the mod does what `coop ui reset` does: the menu, the screens and the boxes close, an open host's question is
answered with Deny, a joiner's wait popup hides, the co-op saves' question closes as Decide later and the mouse cursor
goes. The game gets its keys back at once. One difference: if you already chose co-op and the copies are being made,
that choice stays. The result shows as a notice when the copy ends. Nothing else shows on screen.
`UE4SS.log` says `[StellarCoop] focus watchdog: <who> lost the focus for 1 s: co-op UI closed, the game has its input
back`, where who is `menu`, `sessions` (the Sessions screen), `create` (the Create a session screen), `chat`, `code`,
`ask` (a join popup) or `saves`.
The line before it, `focus watchdog: focus on <widgets>; game paused or its cursor shown: <true or false>; <time since
the last mouse button>`, names the game's widgets that held the focus, or `none` when the game's view, a widget the
mod cannot list or another window had it. `coop-link.log` says `window: another window is in front` and
`window: the game is in front` each time the game's window loses or gets back the foreground (alt-tab, a screenshot
tool).
The watchdog has not been tested in game yet.

- The Steam overlay (Shift+Tab) should leave the focus where it was and then not trip the watchdog (not tested in
  game yet).
- A left or right click on none of the mod's widgets moves the focus to the game. The mod puts it back 50 ms later and
  starts the second over, so such a click closes nothing.
- The watchdog starts once it has seen the focus on the mod's UI. If that has not happened 2 s after the UI took the
  keys, `focus watchdog: our root never took the focus` shows once until the mod reloads, and nothing closes by itself.
  `focus watchdog off: the UI root refused bIsFocusable (<why>)` means it is off until the mod reloads.

## Session chat

During a session, in the PvP lobby (Xion's training room or a hall lobby) or with `coop loopback`, Enter opens a text
box at the top left of the screen, under the feed. It opens in a world only, and not while the game is paused or shows
the mouse cursor for one of its own screens. In a hall lobby it does not open while EVE sits on one of the game's
chairs: Enter there picks the game's Get up. While the box is open, the game ignores its own keys, so EVE stands still,
and the mod's keys (F5, F6, F8) do nothing. If the game pauses or shows the mouse cursor while the box is open (EVE
dies, or your friend's photo mode pauses your game), the box closes and what you typed is lost. Alt+Enter never opens
it.

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
- In the PvP lobby, your lines go to every player of your match lobby who has finished connecting. With nobody
  connected, they stay on your screen only, and the first one adds a grey notice:
  `No other player is connected yet: your messages stay on your screen.` The notice comes back each time you are alone
  again, after a connected player left or after you come back to the lobby. A player who connects later does not get
  the lines typed before. With nobody connected, leaving the lobby world clears the history as the end of a session
  does, and a warp to another hall, the hop to an arena or the return to Xion each leave it.
- Outside a session and the PvP lobby, Enter shows `Chat needs a session or the PvP lobby.`, at most once every 10 s.
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

Options > Display > Status line (`status_overlay`) adds a status strip above the card: Off, Compact (the default) or
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

- `coop-link.log`: `region tabs on: 0x145c44978 swapped from the Region logic's init to our hook` at start, and
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
| Your answer | `<name> was let in.` (in the feed as the game's `<name> has joined the game.`), `<name> was not let in.`, `<name> was not let in: no answer within 60 s.` or `<name> was removed and blocked.` |
| Your [block list](playing-with-a-friend.md#block-list) | `A player on your block list tried to join and was refused.`, `<name> is on your block list and was removed.` (a match lobby that came to you), `Left the match: a player on your block list is in it. Searching again.` (quick match), `Player blocked.`, `Player unblocked.`, `That player is not on your block list.`, `Block list emptied.`, `Could not save the block list: it holds until the game closes.` or `Could not read the whole block list: changes to it are not saved until the game restarts.` |
| Could not join | `Could not join: <reason>` for each answer Steam documents (listed in [Troubleshooting](troubleshooting.md#my-friend-cannot-join)), or `Could not join: Steam response <n>.` for any other |
| A friend joined, left, came back | `<name> joined.`, `<name> left.`, `<name> is back.` In the feed, the first two show in the game's own words: `<name> has joined the game.` and `<name> has left the game.` |
| Connection lost | `<name>: connection lost.` |
| Version mismatch | `Version mismatch: that game runs protocol ..., build ...; yours runs ...` (on joining) or `Version mismatch with <name>: ...` |
| Refused link | `<name> refused the link: <reason>` |
| Invite held | `Invite held: joining once your save has loaded.` |
| Rejoin | `Lost <host>'s game: rejoining.`, then `Rejoined <host>'s game.` |
| Session ended | `Session ended: <host> left.`, `Session ended: <host>'s game is gone.` or `Session ended: could not rejoin <host>'s game.` |
| Too many players | `Left: the lobby has more than 2 players.`, or `... 8 players.` in a match lobby |
| Leaving | `Left the session.`, `Not in a session.` or `Held invite dropped.` |
| `coop match search` or `create` with a mode this version does not have | `No such mode: <mode>. Modes: <modes>.` |
| `coop match search` or `create` while you are in a lobby | `Leave this game first.` |
| Steam refused the match search | `Could not search: Steam refused.` |
| Quick match found no open lobby of that mode | `No <mode> match found (SBO protocol <n>, build <n>): hosting one.` |
| Hosting a public match lobby | `Hosting a <mode> match: waiting for players.` |
| Hosting a private match lobby | `Hosting a private <mode> match. Your join code is <code>.` |
| Joining a match lobby whose mode this version does not have | `Could not join: unknown match mode <mode>.` |
| The host started a round without you (your link to the host was not ready when the countdown ended); you stay in the lobby | `A round started without you.` |
| The match lobby has a new host (a round in play ends) | `<name> hosts the match now.` |
| The match host was silent for 10 s during a round | `Round ended: the host stopped answering.` |
| Your game is no longer in the match lobby's member list | `Left the match: lost the lobby.` |
| The match lobby's owner cleared or changed its mode while you were in it | `Left the match: the lobby changed its mode.` |
| In the SBO lobby, you joined a match lobby on a hall lobby map you do not have, or on another build of the hall lobby pak | `Left the match: its lobby map is missing or a different version here.` |
| `coop mute`, `coop unmute` | `Muted <name>.` or `Unmuted <name>.` |
| A player on another protocol or game build joins the match lobby you host | `<name> runs another version and was refused.` |
| A player in your match lobby stays over a channel's rate limit for 5 s; you keep the lobby | `<name> sent too many messages and was refused.` |
| Steam refused relay only 3 times, 1 s apart (needed in a match and with a player who is not your Steam friend) | `<name> was refused: Steam would not set relay only.` (co-op host), `Left <host>'s game: Steam would not set relay only.` (co-op guest) or `Left the match: Steam would not set relay only.` |
| The match host stays over a channel's rate limit for 5 s; you leave | `Left the match: <name> sent too many messages.` |
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
| Your friend's installed DLCs differ from yours, once a session | `<name> has DLCs you don't have: <DLCs>. You have DLCs <name> doesn't have: <DLCs>.`, either part alone when the other list is empty; see [The Steam link](internals/steam-link.md#the-dlc-and-dlcs-lines) |
| Your friend's `.pak` mods differ from yours, once a session | `<name> uses mods you don't have: <mods>. ...`, `<name> uses other versions of mods you have: <mods>. ...` or `<name> loads other .pak mods than you (<n> there, <n> here). ...`; see [Shared enemies](shared-enemies.md#shared-enemies-experimental) |
| Shared enemies started, stopped, or waiting for something | See [Shared enemies](shared-enemies.md#shared-enemies-experimental) |
| Same place moving enemies, or stopped | See [Same place](shared-enemies.md#same-place-experimental) |
| Shared quests on, off or waiting for a co-op save, and quest steps that wait or that were made apart | See [Shared quests](playing-with-a-friend.md#shared-quests-experimental) |
| Shared world on with your friend, or stopped after an error | `Shared world on with <name>.` or `Shared world stopped until the game restarts. coop-link.log says why.` ([shared world](shared-world.md)) |
| Night Operation: a partner's run starting, a partner who cannot join, the points a run gave | See [night-operation.md](night-operation.md#the-co-op-run) and [the reward shop](night-operation-shop.md) |
